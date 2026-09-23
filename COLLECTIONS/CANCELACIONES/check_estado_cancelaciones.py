"""
Recalcula el estado real (contra Salesforce en vivo) de cada contrato en
Contratos_para_Cancelar_LOG.csv (o de una lista puntual pasada por
argumento) y sobreescribe Contratos_para_Cancelar_ESTADO.csv con el
resultado -- asi el archivo (no una conversacion de chat) es lo que
recuerda en que quedo cada contrato entre sesiones y entre maquinas.

Replica EXACTAMENTE la misma logica de bloqueo que usa
CancelarContratosRunner.cls (fuerza-app/main/default/classes/) para que
la categoria "listo para finalizar" de este script coincida con lo que
el runner real haria -- la primera version de este chequeo (hecho a mano
en una sesion de Claude Code) no revisaba SM_Payment__c y por eso 20 de
21 contratos que parecian "stuck" en realidad seguian bloqueados por un
pago bancario sin resolver.

Categorias:
  CANCELLED_OK          - Status=Cancelled y Chargebee/ACH ya consistente.
  STUCK_CONTRACT_STATUS - Chargebee/ACH ya resuelto, falta correr el
                          runner para finalizar el Contract.
  PENDING_CHARGEBEE     - Subscription todavia ACTIVE/PAUSED o invoices
                          sin resolver.
  PENDING_ACH_PAYMENT   - Un SM_Payment__c bloqueante (Payment_Status__c
                          REJECTED/ACH TRANSMITTED) con
                          SM_Check_Collection_Status__c sin resolver.
  REVISAR_MANUAL        - Caso raro: SM_Customer_Cancellation__c=false, o
                          alguna SM_ACH_Order__c en Initiated/Recurring/
                          Pending (indica actividad reciente, no encaja con
                          "para cancelar"). 'Stopped' NO cuenta como raro --
                          es el estado seguro al que validate_pending_
                          payments.py manda estas ordenes antes de cancelar
                          (ver ese script), CancelarContratosRunner.cls ya
                          las pasa a 'Canceled' cuando el contrato cancela
                          de verdad.
  NOT_FOUND             - El ContractNumber no existe en el org.

Uso:
    python check_estado_cancelaciones.py                  # toda la lista maestra
    python check_estado_cancelaciones.py 00317661 00317795 # solo estos
"""

import csv
import json
import shutil
import subprocess
import sys
from datetime import date
from pathlib import Path

ORG_ALIAS = "MONEE"
SCRIPT_DIR = Path(__file__).resolve().parent
LOG_CSV = SCRIPT_DIR / "Contratos_para_Cancelar_LOG.csv"
ESTADO_CSV = SCRIPT_DIR / "Contratos_para_Cancelar_ESTADO.csv"

SF_BIN = shutil.which("sf") or "sf"

# Mismos criterios que CancelarContratosRunner.cls -- si se cambian ahi,
# cambiar tambien aca.
RESOLVED_INVOICE_STATUSES = {"VOIDED", "PAID"}
BLOCKING_PAYMENT_STATUSES = {"REJECTED", "ACH TRANSMITTED"}
ALLOWED_COLLECTION_STATUSES = {
    "NOT_COLLECTED", "Not_Collected", "Not_collected",
    "NOT COLLECTED", "Not Collected", "Not collected",
    "ACCEPTED", "Accepted",
    "COLLECTED", "COLECTED", "Collected",
    "REJECTED",
}
# 'Stopped' NO esta acá a propósito -- ver docstring del módulo. Es el
# estado seguro/esperado antes de cancelar, no una señal de actividad rara.
WEIRD_ORDER_STATUSES = {"Initiated", "Recurring", "Pending"}


def sf_query(soql: str):
    result = subprocess.run(
        [SF_BIN, "data", "query", "-o", ORG_ALIAS, "--query", soql, "--json"],
        capture_output=True, text=True,
    )
    if result.returncode != 0:
        print(f"ERROR sf data query: {(result.stderr or result.stdout).strip()}", file=sys.stderr)
        sys.exit(1)
    return json.loads(result.stdout)["result"]["records"]


def chunked(items, size=100):
    items = list(items)
    for i in range(0, len(items), size):
        yield items[i:i + size]


def sf_query_in(select_and_from: str, in_field: str, values, extra_where: str = "", chunk_size=100):
    """Corre `select_and_from WHERE in_field IN (...) [AND extra_where]` en
    lotes -- una sola query con cientos de valores choca con el limite de
    largo de linea de comandos en Windows."""
    records = []
    for batch in chunked(values, chunk_size):
        if not batch:
            continue
        values_in = ",".join(f"'{v}'" for v in batch)
        where = f"{in_field} IN ({values_in})"
        if extra_where:
            where += f" AND {extra_where}"
        records.extend(sf_query(f"{select_and_from} WHERE {where}"))
    return records


def load_contract_numbers(argv):
    """Solo la 1ra columna (ContractNumber) -- este script no necesita
    Fecha/Motivo, esos los usa generate_run_batch.py al armar una corrida."""
    if argv:
        return [n.zfill(8) for n in argv]
    with open(LOG_CSV, encoding="utf-8") as f:
        return [line.split("\t")[0].strip() for line in f if line.strip()]


def main():
    numbers = load_contract_numbers(sys.argv[1:])
    print(f"-> Revisando {len(numbers)} contrato(s)...")

    contracts = sf_query_in(
        "SELECT Id, ContractNumber, Status, SM_Customer_Cancellation__c, CB_Subscription__c, "
        "CB_Subscription__r.Name, CB_Subscription__r.chargebeeapps__Subscription_status__c "
        "FROM Contract",
        "ContractNumber", numbers,
    )
    by_number = {c["ContractNumber"]: c for c in contracts}
    ids = [c["Id"] for c in contracts]

    ach_orders = sf_query_in(
        "SELECT Id, Name, SM_Contract__c, SM_Payment_Status__c FROM SM_ACH_Order__c",
        "SM_Contract__c", ids,
    )
    ach_by_contract = {}
    for o in ach_orders:
        ach_by_contract.setdefault(o["SM_Contract__c"], []).append(o)

    invoices = sf_query_in(
        "SELECT Id, Name, chargebeeapps__Status__c, Contract__c FROM chargebeeapps__CB_Invoice__c",
        "Contract__c", ids,
    )
    inv_by_contract = {}
    for i in invoices:
        inv_by_contract.setdefault(i["Contract__c"], []).append(i)

    blocking_statuses_in = ",".join(f"'{s}'" for s in BLOCKING_PAYMENT_STATUSES)
    payments = sf_query_in(
        "SELECT Id, Name, SM_Contract__c, RecordType.DeveloperName, Payment_Status__c, "
        "SM_Check_Collection_Status__c FROM SM_Payment__c",
        "SM_Contract__c", ids,
        extra_where=f"Payment_Status__c IN ({blocking_statuses_in})",
    )
    payments_by_contract = {}
    for p in payments:
        payments_by_contract.setdefault(p["SM_Contract__c"], []).append(p)

    rows = []
    today = date.today().isoformat()

    for num in numbers:
        c = by_number.get(num)
        if c is None:
            rows.append((num, "NOT_FOUND", today, "No se encontro Contract con ese ContractNumber"))
            continue

        cid = c["Id"]
        status = c["Status"]
        cust_cancel = c["SM_Customer_Cancellation__c"]
        is_cb = bool(c.get("CB_Subscription__c"))

        if is_cb:
            sub = c.get("CB_Subscription__r") or {}
            sub_status = sub.get("chargebeeapps__Subscription_status__c")
            invs = inv_by_contract.get(cid, [])
            all_inv_resolved = all(i["chargebeeapps__Status__c"] in RESOLVED_INVOICE_STATUSES for i in invs)
            cb_resolved = all_inv_resolved and sub_status == "CANCELLED"

            if status == "Cancelled" and cb_resolved:
                rows.append((num, "CANCELLED_OK", today, f"Sub={sub.get('Name')} ({sub_status})"))
            elif cb_resolved:
                rows.append((num, "STUCK_CONTRACT_STATUS", today,
                             f"Chargebee ya resuelto (Sub {sub_status}, invoices OK), falta finalizar Contract.Status"))
            else:
                inv_summary = ", ".join(f"{i['Name']}({i['chargebeeapps__Status__c']})" for i in invs) or "(ninguno)"
                rows.append((num, "PENDING_CHARGEBEE", today, f"Sub={sub_status} | Invoices: {inv_summary}"))
            continue

        # Rama ACH
        orders = ach_by_contract.get(cid, [])
        weird_orders = [o for o in orders if o["SM_Payment_Status__c"] in WEIRD_ORDER_STATUSES]
        if cust_cancel is False or weird_orders:
            detail = f"SM_Customer_Cancellation__c={cust_cancel}"
            if weird_orders:
                detail += " | Ordenes: " + ", ".join(f"{o['Name']}({o['SM_Payment_Status__c']})" for o in weird_orders)
            rows.append((num, "REVISAR_MANUAL", today, detail))
            continue

        blocking = [
            p for p in payments_by_contract.get(cid, [])
            if (p.get("RecordType") or {}).get("DeveloperName") == "ACH"
            and (p["SM_Check_Collection_Status__c"] or "") not in ALLOWED_COLLECTION_STATUSES
        ]
        if blocking:
            detail = "; ".join(f"{p['Name']} en {p['SM_Check_Collection_Status__c'] or p['Payment_Status__c']}" for p in blocking)
            rows.append((num, "PENDING_ACH_PAYMENT", today, detail))
        elif status == "Cancelled":
            rows.append((num, "CANCELLED_OK", today, "ACH ya resuelto"))
        else:
            rows.append((num, "STUCK_CONTRACT_STATUS", today, "ACH ya resuelto, falta finalizar Contract.Status"))

    with open(ESTADO_CSV, "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(["ContractNumber", "Estado", "FechaUltimaRevision", "Detalle"])
        writer.writerows(rows)

    counts = {}
    for _, estado, _, _ in rows:
        counts[estado] = counts.get(estado, 0) + 1
    print(f"-> Escrito {ESTADO_CSV.relative_to(SCRIPT_DIR.parent.parent)}")
    for estado, n in sorted(counts.items(), key=lambda kv: -kv[1]):
        print(f"   {estado}: {n}")


if __name__ == "__main__":
    main()
