"""
Paso de validacion previo a intentar cancelar un contrato ACH cuando
check_estado_cancelaciones.py lo clasifica PENDING_ACH_PAYMENT (payment
bancario bloqueante) o REVISAR_MANUAL por una SM_ACH_Order__c activa.

Para cada contrato de Contratos_para_Cancelar_LOG.csv (o los que se pasen
por argumento), hace 2 cosas que check_estado_cancelaciones.py NO hace
(ese solo lee el valor en vivo de Salesforce, no lo interpreta):

  1. PAGOS bloqueantes (SM_Payment__c, ACH, Payment_Status__c REJECTED/
     ACH TRANSMITTED, SM_Check_Collection_Status__c sin resolver):
     - Los cruza contra el indice historico de COLLECTIONS (returns_index.csv
       + collections_index.csv, ver COLLECTIONS/buscar_payment.py) para
       confirmar que el estado que tiene Salesforce en vivo coincide con el
       ULTIMO reporte bancario real -- si hay un reporte mas reciente que
       Salesforce no reflejo, NO se auto-aplica nunca (se marca
       REVISAR_REPORTE_NO_APLICADO con el detalle del reporte encontrado).
       El pipeline diario (run_daily_new_files.sh/run_daily_catchup.sh) NO
       resuelve esto solo si el reporte es historico -- la Rule 2 del
       CLAUDE.md exige confirmacion explicita del usuario para tocar
       cualquier cosa reportada hace mas de 2 meses, nunca un catch-up
       silencioso. Por eso este caso solo se REPORTA (queda en el CSV con
       la fecha/archivo del reporte mas reciente) -- es decision del
       usuario si se aplica, este script nunca lo hace por su cuenta.
     - Si Salesforce ya esta al dia con el historial (o nunca hubo reporte
       posterior a la transmision), aplica la Rule 3 del CLAUDE.md (#2.2):
       PENDING/RETURN con mas de 26 dias desde SM_Transmission_Date_ACH_File__c
       -> NOT_COLLECTED; o de inmediato si el codigo de retorno es uno de
       los 6 "definitivos" (R02/R04/R07/R10/R13/R16 -- R01/R09/R08 NUNCA
       saltan la espera).

  2. ORDENES ACH activas (SM_ACH_Order__c en Pending/Initiated/Recurring --
     las mismas 3 que check_estado_cancelaciones.py agrupa como "raras" en
     WEIRD_ORDER_STATUSES, sin contar Stopped que ya es un estado terminal
     seguro): estas siguen generando cobros futuros mientras el contrato
     sigue activo como candidato a cancelar. Se marcan para pasar a
     'Stopped' (instruccion explicita del usuario, 2026-09-23) -- NO a
     'Canceled', ese es el estado que ya aplica CancelarContratosRunner.cls
     cuando el contrato termina de cancelarse de verdad.

Uso (siempre dry-run por default; "apply" al final escribe en Salesforce):
    python validate_pending_payments.py                    # toda la lista maestra, dry-run
    python validate_pending_payments.py 00317661 00317795  # contratos puntuales, dry-run
    python validate_pending_payments.py apply               # aplica NOT_COLLECTED + Stopped
    python validate_pending_payments.py --no-update apply   # sin refrescar indices primero

Escribe Contratos_para_Cancelar_VALIDACION_PAGOS.csv (se sobreescribe
completo cada corrida, igual que Contratos_para_Cancelar_ESTADO.csv) --
una fila por payment/orden con su accion recomendada y la razon exacta.
"""

import csv
import shutil
import subprocess
import sys
from datetime import date
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
COLLECTIONS_DIR = SCRIPT_DIR.parent
LOG_CSV = SCRIPT_DIR / "Contratos_para_Cancelar_LOG.csv"
VALIDACION_CSV = SCRIPT_DIR / "Contratos_para_Cancelar_VALIDACION_PAGOS.csv"

sys.path.insert(0, str(SCRIPT_DIR))
sys.path.insert(0, str(COLLECTIONS_DIR))
import check_estado_cancelaciones as estado_mod  # noqa: E402  (reusa sf_query_in/BLOCKING/ALLOWED -- una sola fuente de verdad)
import build_index  # noqa: E402
import ACH_REPORTADOS.build_index as transmission_build_index  # noqa: E402
from buscar_payment import search_index, RETURNS_INDEX_CSV, COLLECTIONS_INDEX_CSV  # noqa: E402

ORG_ALIAS = "MONEE"
SF_BIN = shutil.which("sf") or "sf"

# Rule 3, CLAUDE.md #2.2 -- 26 dias exactos NO califica, tiene que ser MAS de 26.
RULE3_DAYS_THRESHOLD = 26
# Los 5 reportes dedicados de SM_ReturnCodeNotifier ("nunca se resuelve
# reintentando el mismo metodo de pago") + R10 (Regla R10 documentada aparte,
# pero para efectos de saltar la espera de 26 dias entra en el mismo grupo).
# R01/R09 (NSF) y R08 (pago detenido) NUNCA califican para la excepcion.
DEFINITIVE_RETURN_CODES = {"R02", "R04", "R07", "R10", "R13", "R16"}

# Ordenes ACH activas que siguen generando cobros -- 'Stopped' queda fuera
# a proposito (ya es el estado terminal seguro al que este script las manda).
ACTIVE_ORDER_STATUSES = {"Pending", "Initiated", "Recurring"}

PROCESS_NAME = "Validate_Pending_Payments_CancelCandidates"


def refresh_indices(quiet=True):
    build_index.update_indexes(quiet=quiet)
    try:
        transmission_build_index.update_index(quiet=quiet)
    except Exception as exc:
        print(f"  AVISO: no se pudo actualizar el indice de ACH Reportados: {exc}", file=sys.stderr)


def days_since(iso_date: str):
    if not iso_date:
        return None
    try:
        y, m, d = (int(x) for x in iso_date[:10].split("-"))
    except ValueError:
        return None
    return (date.today() - date(y, m, d)).days


def latest_bank_report(payment_name: str):
    """Ultima fila (por fecha) entre returns_index + collections_index para
    este payment, o None si nunca aparecio en ningun reporte indexado."""
    rows = search_index(RETURNS_INDEX_CSV, payment_name) + search_index(COLLECTIONS_INDEX_CSV, payment_name)
    dated = []
    for r in rows:
        d = r.get("SM_Check_Collection_Date__c")
        if d:
            dated.append((d, r))
    if not dated:
        return None
    dated.sort(key=lambda x: x[0])
    return dated[-1][1]


def classify_payment(payment: dict) -> dict:
    """payment trae: Name, SM_Check_Collection_Status__c, SM_Check_Collection_Date__c,
    SM_Transmission_Date_ACH_File__c, SM_Return_code__c (todas del SOQL en vivo)."""
    name = payment["Name"]
    sf_status = (payment.get("SM_Check_Collection_Status__c") or "").strip()
    sf_date = payment.get("SM_Check_Collection_Date__c")
    code = (payment.get("SM_Return_code__c") or "").strip()
    transm_date = payment.get("SM_Transmission_Date_ACH_File__c")
    days = days_since(transm_date)

    latest = latest_bank_report(name)
    if latest and sf_date and latest["SM_Check_Collection_Date__c"] > sf_date:
        reported_status = latest.get("SM_Check_Collection_Status__c") or latest.get("Payment_Status__c") or "(sin estado en la fila del indice)"
        return {
            "accion": "REVISAR_REPORTE_NO_APLICADO",
            "razon": (
                f"Reporte mas reciente en el indice COLLECTIONS ({latest['SM_Check_Collection_Date__c']}, "
                f"archivo {latest.get('Source_File')}) dice '{reported_status}', pero Salesforce sigue en "
                f"'{sf_status}' desde {sf_date}. El pipeline diario NO lo aplica solo si es historico "
                f"(Rule 2, CLAUDE.md) -- SOLO SE REPORTA, no se auto-aplica ninguna regla; decision del usuario "
                f"si se actualiza (y con que dato: el del reporte, no necesariamente NOT_COLLECTED)."
            ),
            "ultimo_reporte": f"{latest['SM_Check_Collection_Date__c']} | {reported_status} | {latest.get('Source_File')}",
            "dias_transmitido": days,
        }

    ultimo_reporte = f"{latest['SM_Check_Collection_Date__c']} | {latest.get('Source_File')}" if latest else "(sin reporte en indice, solo transmision)"

    if days is not None and days > RULE3_DAYS_THRESHOLD:
        return {
            "accion": "NOT_COLLECTED",
            "razon": f"Rule 3: {days} dias transmitido (> {RULE3_DAYS_THRESHOLD}) sin resolver, Salesforce ya coincide con el ultimo reporte.",
            "ultimo_reporte": ultimo_reporte,
            "dias_transmitido": days,
        }
    if code in DEFINITIVE_RETURN_CODES:
        return {
            "accion": "NOT_COLLECTED",
            "razon": f"Rule 3, excepcion codigo definitivo {code} (no requiere esperar los {RULE3_DAYS_THRESHOLD} dias).",
            "ultimo_reporte": ultimo_reporte,
            "dias_transmitido": days,
        }
    return {
        "accion": "EN_ESPERA",
        "razon": f"{days if days is not None else '?'} dias transmitido (<= {RULE3_DAYS_THRESHOLD}), codigo {code or '(ninguno)'} no es definitivo -- sigue esperando.",
        "ultimo_reporte": ultimo_reporte,
        "dias_transmitido": days,
    }


def query_blocking_payments(contract_ids):
    blocking_in = ",".join(f"'{s}'" for s in estado_mod.BLOCKING_PAYMENT_STATUSES)
    records = estado_mod.sf_query_in(
        "SELECT Id, Name, SM_Contract__c, RecordType.DeveloperName, Payment_Status__c, "
        "SM_Check_Collection_Status__c, SM_Check_Collection_Date__c, "
        "SM_Transmission_Date_ACH_File__c, SM_Return_code__c FROM SM_Payment__c",
        "SM_Contract__c", contract_ids,
        extra_where=f"Payment_Status__c IN ({blocking_in})",
    )
    by_contract = {}
    for p in records:
        if (p.get("RecordType") or {}).get("DeveloperName") != "ACH":
            continue
        if (p.get("SM_Check_Collection_Status__c") or "") in estado_mod.ALLOWED_COLLECTION_STATUSES:
            continue
        by_contract.setdefault(p["SM_Contract__c"], []).append(p)
    return by_contract


def query_active_orders(contract_ids):
    active_in = ",".join(f"'{s}'" for s in ACTIVE_ORDER_STATUSES)
    records = estado_mod.sf_query_in(
        "SELECT Id, Name, SM_Contract__c, SM_Payment_Status__c FROM SM_ACH_Order__c",
        "SM_Contract__c", contract_ids,
        extra_where=f"SM_Payment_Status__c IN ({active_in})",
    )
    by_contract = {}
    for o in records:
        by_contract.setdefault(o["SM_Contract__c"], []).append(o)
    return by_contract


def build_report(numbers):
    contracts = estado_mod.sf_query_in(
        "SELECT Id, ContractNumber FROM Contract", "ContractNumber", numbers,
    )
    by_number = {c["ContractNumber"]: c for c in contracts}
    ids = [c["Id"] for c in contracts]

    payments_by_contract = query_blocking_payments(ids)
    orders_by_contract = query_active_orders(ids)

    rows = []
    for num in numbers:
        c = by_number.get(num)
        if c is None:
            continue
        cid = c["Id"]
        for p in payments_by_contract.get(cid, []):
            verdict = classify_payment(p)
            rows.append({
                "ContractNumber": num,
                "Tipo": "PAGO",
                "Registro": p["Name"],
                "RecordId": p["Id"],
                "EstadoSF": p.get("SM_Check_Collection_Status__c") or p.get("Payment_Status__c"),
                "CodigoRetorno": p.get("SM_Return_code__c") or "",
                "DiasTransmitido": verdict["dias_transmitido"],
                "UltimoReporteCOLLECTIONS": verdict["ultimo_reporte"],
                "AccionRecomendada": verdict["accion"],
                "Razon": verdict["razon"],
            })
        for o in orders_by_contract.get(cid, []):
            rows.append({
                "ContractNumber": num,
                "Tipo": "ORDEN_ACH",
                "Registro": o["Name"],
                "RecordId": o["Id"],
                "EstadoSF": o.get("SM_Payment_Status__c"),
                "CodigoRetorno": "",
                "DiasTransmitido": "",
                "UltimoReporteCOLLECTIONS": "",
                "AccionRecomendada": "STOPPED",
                "Razon": f"Orden en {o.get('SM_Payment_Status__c')} sigue generando cobros futuros -- se detiene mientras el contrato es candidato a cancelar.",
            })
    return rows


def write_csv(rows):
    fields = ["ContractNumber", "Tipo", "Registro", "RecordId", "EstadoSF", "CodigoRetorno",
              "DiasTransmitido", "UltimoReporteCOLLECTIONS", "AccionRecomendada", "Razon"]
    with open(VALIDACION_CSV, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fields)
        writer.writeheader()
        writer.writerows(rows)
    print(f"-> Escrito {VALIDACION_CSV.relative_to(SCRIPT_DIR.parent.parent)}")
    counts = {}
    for r in rows:
        key = (r["Tipo"], r["AccionRecomendada"])
        counts[key] = counts.get(key, 0) + 1
    for (tipo, accion), n in sorted(counts.items(), key=lambda kv: -kv[1]):
        print(f"   {tipo} -> {accion}: {n}")

    revisar = [r for r in rows if r["AccionRecomendada"] == "REVISAR_REPORTE_NO_APLICADO"]
    if revisar:
        print(f"\n   >>> AVISO: {len(revisar)} payment(s) con un reporte de COLLECTIONS mas reciente que "
              f"Salesforce no refleja -- SOLO SE REPORTAN, este script nunca los aplica solo (ver columna "
              f"Razon en el CSV para el detalle y decidir uno por uno):")
        for r in revisar:
            print(f"       {r['ContractNumber']} | {r['Registro']}: {r['UltimoReporteCOLLECTIONS']}")


def apply_changes(rows):
    # NOT_COLLECTED/STOPPED son las UNICAS acciones que este script aplica solo --
    # REVISAR_REPORTE_NO_APLICADO y EN_ESPERA quedan siempre fuera, a proposito
    # (decision del usuario, nunca automatica -- ver build_report()/classify_payment()).
    payment_reasons = {r["RecordId"]: r["Razon"] for r in rows if r["Tipo"] == "PAGO" and r["AccionRecomendada"] == "NOT_COLLECTED"}
    order_reasons = {r["RecordId"]: r["Razon"] for r in rows if r["Tipo"] == "ORDEN_ACH" and r["AccionRecomendada"] == "STOPPED"}

    if not payment_reasons and not order_reasons:
        print("-> Nada que aplicar (0 payments califican para NOT_COLLECTED, 0 ordenes activas).")
        return

    def esc(s):
        return s.replace("\\", "\\\\").replace("'", "\\'")

    lines = [
        "// Generado por validate_pending_payments.py -- ver COLLECTIONS/CANCELACIONES/",
        "// Contratos_para_Cancelar_VALIDACION_PAGOS.csv para el detalle completo.",
        "",
    ]

    if payment_reasons:
        lines.append("Map<Id, String> paymentReasons = new Map<Id, String>{")
        lines.append(",\n".join(f"    '{pid}' => '{esc(r)}'" for pid, r in payment_reasons.items()))
        lines.append("};")
        lines.append("List<SM_Payment__c> paymentsToUpdate = [SELECT Id, SM_Id_Salesforce_LCS__c FROM SM_Payment__c WHERE Id IN :paymentReasons.keySet()];")
        lines.append("for (SM_Payment__c p : paymentsToUpdate) {")
        lines.append("    p.SM_Check_Collection_Status__c = 'NOT_COLLECTED';")
        lines.append(f"    p.SM_Id_Salesforce_LCS__c = SM_AutomationLogHelper.appendNote(p.SM_Id_Salesforce_LCS__c, '{PROCESS_NAME}', paymentReasons.get(p.Id));")
        lines.append("}")
        lines.append("update paymentsToUpdate;")
        lines.append("System.debug('Payments actualizados a NOT_COLLECTED: ' + paymentsToUpdate.size());")
        lines.append("")

    if order_reasons:
        lines.append("Map<Id, String> orderReasons = new Map<Id, String>{")
        lines.append(",\n".join(f"    '{oid}' => '{esc(r)}'" for oid, r in order_reasons.items()))
        lines.append("};")
        lines.append("List<SM_ACH_Order__c> ordersToUpdate = [SELECT Id, SM_Id_Salesforce_LCS__c FROM SM_ACH_Order__c WHERE Id IN :orderReasons.keySet()];")
        lines.append("for (SM_ACH_Order__c o : ordersToUpdate) {")
        lines.append("    o.SM_Payment_Status__c = 'Stopped';")
        lines.append(f"    o.SM_Id_Salesforce_LCS__c = SM_AutomationLogHelper.appendNote(o.SM_Id_Salesforce_LCS__c, '{PROCESS_NAME}', orderReasons.get(o.Id));")
        lines.append("}")
        lines.append("update ordersToUpdate;")
        lines.append("System.debug('Ordenes ACH detenidas (Stopped): ' + ordersToUpdate.size());")
        lines.append("")

    apex_path = SCRIPT_DIR / "_validate_pending_payments_apply.apex"
    apex_path.write_text("\n".join(lines), encoding="utf-8")

    print(f"-> Aplicando: {len(payment_reasons)} payment(s) -> NOT_COLLECTED, {len(order_reasons)} orden(es) -> Stopped ...")
    result = subprocess.run([SF_BIN, "apex", "run", "-o", ORG_ALIAS, "-f", str(apex_path)], capture_output=True, text=True)
    print(result.stdout)
    if result.returncode != 0:
        print(result.stderr, file=sys.stderr)
        sys.exit(1)
    apex_path.unlink(missing_ok=True)


def load_contract_numbers(argv):
    if argv:
        return [n.zfill(8) for n in argv]
    with open(LOG_CSV, encoding="utf-8") as f:
        return [line.split("\t")[0].strip() for line in f if line.strip()]


def main():
    args = sys.argv[1:]
    do_apply = "apply" in args
    args = [a for a in args if a != "apply"]
    do_update = "--no-update" not in args
    args = [a for a in args if a != "--no-update"]

    if do_update:
        print("Actualizando indices historicos COLLECTIONS (solo archivos nuevos)...")
        refresh_indices(quiet=True)

    numbers = load_contract_numbers(args)
    print(f"-> Validando pagos/ordenes pendientes de {len(numbers)} contrato(s)...")
    rows = build_report(numbers)
    write_csv(rows)

    if do_apply:
        apply_changes(rows)
    elif rows:
        print("\n-> DRY RUN -- nada se escribio en Salesforce. Correr con 'apply' al final para aplicar.")


if __name__ == "__main__":
    main()
