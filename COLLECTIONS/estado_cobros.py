"""
"Reporte de Estado de Cobros" de un contrato -- version rapida/visual
pensada para consulta directa (por Carlos o por un agente), no un dump
completo de datos. Si algo no cuadra o se ve raro, ese es el aviso para
ir a mirar el detalle a mano (Salesforce / Chargebee), no para confiar
ciegamente en este resumen.

Aplica a contratos facturados via Chargebee (Credit Card) -- para el
pipeline de ACH (Returns / Check Collection / ACH Reportados) usar
buscar_payment.py en su lugar, es un mundo distinto.

Combina 4 fuentes, todas contra Salesforce en vivo (MONEE):
  1. Contract              -- datos basicos, proximo cobro regular
                               (CB_Subscription__r.chargebeeapps__Next_billing__c).
  2. chargebeeapps__CB_Invoice__c -- que factura(s) del contrato siguen
                               PAYMENT_DUE ahora mismo.
  3. Dunning_Status__c / Dunning_Next_Retry_Date__c (campos sincronizados
                               desde Chargebee en cada invoice) -- si el
                               cobro de esa factura se va a reintentar
                               solo, o quedo huerfano (sin proximo
                               intento programado, necesita accion
                               manual).
  4. CB_Charge_Request__c  -- objeto propio del org (NO es de Chargebee)
                               para programar un cobro futuro (ej. un PTP)
                               sin tocar la factura ahora -- Request_Status__c
                               Pending/Ready To Collect significa que ya
                               hay un cobro programado a mano, no es algo
                               que el reporte deba marcar como pendiente
                               de decidir. Sin este chequeo, un contrato
                               con un PTP en curso aparecia como "Al dia"
                               sin mencionarlo (hallazgo 2026-09-28,
                               contrato 00317173).
  5. SM_Payment__c (historial ACH) -- SOLO si el subscription de Chargebee
                               sigue en status FUTURE (todavia no arranco):
                               se compara la fecha del ultimo cobro ACH
                               transmitido contra la fecha de arranque de
                               Chargebee. Un contrato genuinamente nuevo
                               (nunca facturo por ACH) con FUTURE es
                               normal -- no se marca nada. Pero si SI tenia
                               historial ACH y el hueco es mayor a 35 dias,
                               es una alerta real: se salto al menos un mes
                               de cobro en la migracion ACH -> Credit Card,
                               sin Invoice ni Charge Request que lo cubra
                               (hallazgo 2026-09-28, contrato 00317356:
                               ultimo ACH 28-ago, Chargebee arranca hasta
                               28-oct -- 61 dias sin ningun intento de
                               cobro para septiembre; validado que es un
                               caso aislado, no un patron -- de 123
                               contratos Credit Card con subscription
                               FUTURE, solo este tenia historial ACH real).
  6. SM_ACH_Order__c       -- SOLO si el contrato ya esta en Credit Card:
                               cualquier orden ACH Pending/Initiated/
                               Recurring/Stopped que haya quedado atras
                               del cambio de metodo de pago. Pending/
                               Initiated/Recurring son [ALERTA] -- deberian
                               cancelarse (no Stopped) si el contrato no
                               tiene ningun payment ACH bloqueante sin
                               resolver, porque su cobro ya se recreo del
                               lado de Chargebee (ver
                               scripts/apex/-CancelarACHOrdersSwitchTC.apex).
                               Stopped se muestra solo como dato/contexto,
                               no es una alerta -- pero vale la pena verlo
                               (hallazgo 2026-09-28, contrato 00317356: 2
                               ordenes activas quedaron huerfanas tras el
                               cambio a Credit Card, mas 1 Stopped sin
                               explicacion clara en su historial).

Cuando una factura necesita accion manual, el reporte imprime el link
directo a esa factura en Chargebee (https://harmoneyllc.chargebee.com/d/invoices/<id>)
para reprogramarla ahi mismo (boton "Pause dunning") -- esa reprogramacion
es EXCLUSIVAMENTE manual, no se puede automatizar desde Salesforce/Apex
(el mecanismo real es un endpoint privado del dashboard de Chargebee,
autenticado con la sesion del usuario -- ver
scripts/apex/-ActivarCobroInmediatoChargebee.apex, deprecado 2026-09-28,
para el detalle completo de por que no se puede).

Tambien valida si el contrato esta en
COLLECTIONS/CANCELACIONES/Contratos_para_Cancelar_LOG.csv -- si SI esta,
se muestra como alerta; si no esta, no se menciona (para no meter ruido).

Formato de salida: compacto, solo alertas -- si todo esta normal (al dia)
se resume en una linea; solo se explaya cuando hay algo pendiente de
decidir.

Requisitos: sf CLI instalado y autenticado contra la org (alias MONEE).

Uso:
    python estado_cobros.py 00316671
    python estado_cobros.py 00316671 00317762   # varios contratos
"""

import calendar
import csv
import json
import shutil
import subprocess
import sys
from datetime import date, timedelta
from pathlib import Path
from urllib.parse import quote

ORG_ALIAS = "MONEE"
SCRIPT_DIR = Path(__file__).resolve().parent
CANCEL_LOG_CSV = SCRIPT_DIR / "CANCELACIONES" / "Contratos_para_Cancelar_LOG.csv"
CHARGEBEE_INVOICE_URL = "https://harmoneyllc.chargebee.com/d/invoices/{cb_invoice_id}"
EDIT_START_DATE_URL = "https://monee.lightning.force.com/apex/chargebeeapps__CBRouter?action=Edit_Start_Date&id={subscription_id}"
NEW_CHARGE_REQUEST_URL = "https://monee.lightning.force.com/lightning/o/CB_Charge_Request__c/new?defaultFieldValues={fields}"


def new_charge_request_link(contract_number: str, amount, notes: str,
                             invoice_date: str, subscription_id: str, product_id: str) -> str:
    # CB_Item_Price__c (Late Payment Fee especifico) queda para completar a mano -- no hay
    # forma segura de adivinar ese Item Price por URL. Nunca se sugiere write-off, ver
    # feedback_never_suggest_writeoff -- esta es la unica accion que se ofrece para un monto
    # sin cobrar: como recuperarlo, no como darlo de baja.
    charge_date = date.today() + timedelta(days=1)
    fields = (
        f"Contract_Number__c={contract_number},"
        f"Charge_Amount__c={amount},"
        f"Request_Status__c=Pending,"
        f"Request_Date__c={invoice_date}T10%3A00%3A00,"
        f"Charge_Date__c={charge_date.isoformat()},"
        f"CB_Subscription__c={subscription_id},"
        f"Product__c={product_id},"
        f"Notes__c={quote(notes, safe='')}"
    )
    return NEW_CHARGE_REQUEST_URL.format(fields=fields)

SF_BIN = shutil.which("sf") or "sf"


def sf_query(soql: str):
    result = subprocess.run(
        [SF_BIN, "data", "query", "-o", ORG_ALIAS, "--query", soql, "--json"],
        capture_output=True, text=True,
    )
    if result.returncode != 0:
        print(f"ERROR sf data query: {(result.stderr or result.stdout).strip()}", file=sys.stderr)
        sys.exit(1)
    return json.loads(result.stdout)["result"]["records"]


def add_months(d: date, months: int, day: int = None) -> date:
    total_month = d.month - 1 + months
    year = d.year + total_month // 12
    month = total_month % 12 + 1
    if day is None:
        day = d.day
    day = min(day, calendar.monthrange(year, month)[1])
    return date(year, month, day)


def contratos_para_cancelar() -> set:
    if not CANCEL_LOG_CSV.exists():
        return set()
    with CANCEL_LOG_CSV.open(newline="", encoding="utf-8") as f:
        return {row[0].strip() for row in csv.reader(f) if row and row[0].strip()}


def reporte_contrato(contract_number: str, en_lista_cancelar: set) -> None:
    print(f"\n=== Contrato {contract_number} ===")

    contratos = sf_query(
        "SELECT Id, ContractNumber, Status, SM_Payment_methods__c, "
        "Account.Name, CB_Subscription__c, "
        "CB_Subscription__r.chargebeeapps__Next_billing__c, "
        "CB_Subscription__r.chargebeeapps__Subscription_status__c, "
        "CB_Subscription__r.chargebeeapps__Subscription_Plan__c, "
        "SM_Start_date__c, SM_Payment_day__c, SM_Monthly_offer__c "
        f"FROM Contract WHERE ContractNumber = '{contract_number}' LIMIT 1"
    )
    if not contratos:
        print("  NO ENCONTRADO en MONEE.")
        return

    c = contratos[0]
    account_name = (c.get("Account") or {}).get("Name", "?")
    sub = c.get("CB_Subscription__r") or {}
    next_billing = sub.get("chargebeeapps__Next_billing__c")
    sub_status = sub.get("chargebeeapps__Subscription_status__c")

    print(f"  {account_name} | {c['Status']} | {c.get('SM_Payment_methods__c')}")

    hueco_ach = None
    ultimo_ach_pago = None
    if sub_status == "FUTURE" and next_billing:
        ach_hist = sf_query(
            "SELECT Name, SM_Amount__c, Payment_Status__c, SM_Transmission_Date_ACH_File__c "
            f"FROM SM_Payment__c WHERE SM_Contract__c = '{c['Id']}' "
            "AND SM_Transmission_Date_ACH_File__c != null "
            "ORDER BY SM_Transmission_Date_ACH_File__c DESC LIMIT 1"
        )
        if ach_hist:
            ultimo_ach_pago = ach_hist[0]
            ultima_ach = ultimo_ach_pago["SM_Transmission_Date_ACH_File__c"]
            gap_dias = (date.fromisoformat(next_billing[:10]) - date.fromisoformat(ultima_ach)).days
            if gap_dias > 35:
                hueco_ach = (ultima_ach, next_billing[:10], gap_dias)

    meses_sin_cobrar = None
    pendientes_links = []
    monthly_offer = c.get("SM_Monthly_offer__c")
    if monthly_offer:
        missed_records = sf_query(
            "SELECT Name, SM_Payment_Date__c FROM SM_Payment__c "
            f"WHERE SM_Contract__c = '{c['Id']}' AND SM_Type__c = 'Fee' "
            f"AND Payment_Status__c = 'REJECTED' AND SM_Check_Collection_Status__c = 'NOT_COLLECTED' "
            f"AND SM_Amount__c = {monthly_offer} ORDER BY SM_Payment_Date__c ASC"
        )
        missed_cnt = len(missed_records)
        if missed_cnt:
            recovered = sf_query(
                "SELECT COUNT(Id) cnt FROM SM_Payment__c "
                f"WHERE SM_Contract__c = '{c['Id']}' AND SM_Type__c = 'Late payment fee' "
                "AND Payment_Status__c = 'ACCEPTED'"
            )
            recovered_cnt = recovered[0].get("cnt", 0) if recovered else 0
            still_owed = missed_cnt - recovered_cnt
            if still_owed > 0:
                activa = sf_query(
                    "SELECT COUNT(Id) cnt FROM SM_ACH_Order__c "
                    f"WHERE SM_Contract__c = '{c['Id']}' "
                    "AND SM_Payment_Status__c IN ('Pending', 'Initiated', 'Recurring')"
                )
                tiene_activa = bool(activa and activa[0].get("cnt", 0) > 0)
                meses_sin_cobrar = (still_owed, tiene_activa)

                # Links para los meses realmente sin recobrar (se asume que los mas viejos ya
                # se recuperaron via Late Payment Fee, quedan pendientes los mas recientes) --
                # solo si hay subscription Chargebee activa (CB_Subscription__c y no CANCELLED)
                # donde crear el Charge Request. Nunca write-off, ver feedback_never_suggest_writeoff.
                sub_id = c.get("CB_Subscription__c")
                product_id = sub.get("chargebeeapps__Subscription_Plan__c")
                if not tiene_activa and sub_id and sub_status != "CANCELLED" and product_id:
                    for pago in missed_records[recovered_cnt:]:
                        fecha_pago = pago["SM_Payment_Date__c"]
                        notas = f"Late Payment Fee -- {pago['Name']} REJECTED sin recobrar ({fecha_pago})"
                        link = new_charge_request_link(contract_number, monthly_offer, notas,
                                                        fecha_pago, sub_id, product_id)
                        pendientes_links.append((pago["Name"], fecha_pago, link))

    if contract_number in en_lista_cancelar:
        print("  [ALERTA] Este contrato SI esta en Contratos_para_Cancelar_LOG.csv -- validar con ese flujo antes de tocar cobros.")

    if not c.get("CB_Subscription__c"):
        if meses_sin_cobrar:
            debe, tiene_activa = meses_sin_cobrar
            sufijo = "" if tiene_activa else " -- SIN orden activa cobrandolo"
            print(f"  [ALERTA] NO al dia -- debe {debe} mes(es) (${debe * monthly_offer:.0f}){sufijo}")
        else:
            print("  Sin CB_Subscription__c -- no es un contrato Chargebee, este reporte no aplica (revisar a mano).")
        return

    invoices = sf_query(
        "SELECT Name, chargebeeapps__CB_Invoice_Id__c, chargebeeapps__Status__c, "
        "chargebeeapps__Due_Amount__c, chargebeeapps__Invoice_Date__c, "
        "Dunning_Status__c, Dunning_Next_Retry_Date__c, "
        "Has_Late_Fee__c, Parent_CB_Invoice_Number__c "
        f"FROM chargebeeapps__CB_Invoice__c WHERE Contract__c = '{c['Id']}' "
        "AND chargebeeapps__Status__c = 'PAYMENT_DUE' "
        "ORDER BY chargebeeapps__Invoice_Date__c ASC"
    )

    if not invoices:
        if hueco_ach:
            ultima_ach, prox, gap = hueco_ach
            print(f"  [ALERTA] Subscription FUTURE -- hueco {gap}d (ACH {ultima_ach} -> CB {prox})")
            sub_id = c.get("CB_Subscription__c")
            if sub_id:
                print(f"      Fix fecha de arranque: {EDIT_START_DATE_URL.format(subscription_id=sub_id)}")
            if ultimo_ach_pago and ultimo_ach_pago.get("Payment_Status__c") == "REJECTED" and sub_id:
                monto = ultimo_ach_pago.get("SM_Amount__c")
                notas = f"Late Payment Fee -- {ultimo_ach_pago['Name']} REJECTED sin recobrar ({ultima_ach})"
                product_id = sub.get("chargebeeapps__Subscription_Plan__c")
                link = new_charge_request_link(contract_number, monto, notas, ultima_ach, sub_id, product_id)
                print(f"      [ALERTA] {ultimo_ach_pago['Name']} (${monto}) quedo REJECTED sin recobrar")
                print(f"      Crear Charge Request: {link}")
        elif meses_sin_cobrar:
            debe, tiene_activa = meses_sin_cobrar
            sufijo = "" if tiene_activa else " -- SIN orden activa cobrandolo"
            nota_sub = " (subscription Chargebee CANCELLED, sin efecto)" if sub_status == "CANCELLED" else ""
            print(f"  [ALERTA] NO al dia -- debe {debe} mes(es) (${debe * monthly_offer:.0f}){sufijo}{nota_sub}")
            for nombre_pago, fecha_pago, link in pendientes_links:
                print(f"      {nombre_pago} ({fecha_pago}) -- Crear Charge Request: {link}")
        else:
            print("  Al dia -- sin facturas PAYMENT_DUE.")
    else:
        total_due = sum(float(i.get("chargebeeapps__Due_Amount__c") or 0) for i in invoices)
        meses = sorted({(i.get("chargebeeapps__Invoice_Date__c") or "")[:7] for i in invoices})
        print(f"  NO al dia -- ${total_due:.0f} ({', '.join(meses)})")
        for i in invoices:
            next_retry = i.get("Dunning_Next_Retry_Date__c")
            monto = i.get("chargebeeapps__Due_Amount__c")
            if next_retry:
                print(f"    - {i['Name']} ${monto} -- retry {next_retry}")
            else:
                print(f"    [ALERTA] {i['Name']} ${monto} -- dunning detenido, sin retry")
            cb_id = i.get("chargebeeapps__CB_Invoice_Id__c")
            if cb_id:
                print(f"      {CHARGEBEE_INVOICE_URL.format(cb_invoice_id=cb_id)}")

            parent_id = i.get("Parent_CB_Invoice_Number__c")
            if i.get("Has_Late_Fee__c") and parent_id:
                parent = sf_query(
                    "SELECT chargebeeapps__Status__c FROM chargebeeapps__CB_Invoice__c "
                    f"WHERE chargebeeapps__CB_Invoice_Id__c = '{parent_id}' LIMIT 1"
                )
                if parent and parent[0].get("chargebeeapps__Status__c") == "PAID":
                    print(f"      [ALERTA] Candidata a cancelar -- factura padre {parent_id} ya PAID, "
                          f"la multa podria no aplicar")

    if next_billing and sub_status != "CANCELLED":
        print(f"  Proximo cobro regular: {next_billing[:10]}")

    rc_start = c.get("SM_Start_date__c")
    payment_day = c.get("SM_Payment_day__c")
    if rc_start and monthly_offer:
        pagados = sf_query(
            "SELECT COUNT(Id) cnt FROM SM_Payment__c "
            f"WHERE SM_Contract__c = '{c['Id']}' AND SM_Type__c = 'Fee' "
            f"AND Payment_Status__c = 'ACCEPTED' AND SM_Amount__c = {monthly_offer}"
        )
        cnt = pagados[0].get("cnt", 0) if pagados else 0
        dia = int(payment_day) if payment_day else None
        proximo_por_conteo = add_months(date.fromisoformat(rc_start), cnt, dia)
        if next_billing and sub_status != "CANCELLED" and proximo_por_conteo != date.fromisoformat(next_billing[:10]):
            print(f"  [ALERTA] Conteo sugiere {proximo_por_conteo.isoformat()} "
                  f"({cnt} pagos ${monthly_offer:.0f} desde RC {rc_start}) -- ver detalle arriba")

    charge_requests = sf_query(
        "SELECT Name, Request_Status__c, Charge_Date__c, Charge_Amount__c, Notes__c "
        f"FROM CB_Charge_Request__c WHERE Contract_Number__c = '{contract_number}' "
        "AND Request_Status__c IN ('Pending', 'Ready To Collect', 'Error') "
        "ORDER BY Charge_Date__c ASC"
    )
    for cr in charge_requests:
        nota = f" -- {cr['Notes__c']}" if cr.get("Notes__c") else ""
        etiqueta = "[ALERTA] " if cr["Request_Status__c"] == "Error" else ""
        print(f"  {etiqueta}Charge Request {cr['Name']} -- ${cr.get('Charge_Amount__c')} -- "
              f"{cr.get('Charge_Date__c')} ({cr['Request_Status__c']}){nota}")

    if c.get("SM_Payment_methods__c") == "Credit Card":
        ach_orders = sf_query(
            "SELECT Name, SM_Payment_Status__c, SM_Payment_Type__c, SM_Total__c, Is_PTP__c, CreatedDate "
            f"FROM SM_ACH_Order__c WHERE SM_Contract__c = '{c['Id']}' "
            "AND SM_Payment_Status__c IN ('Pending', 'Initiated', 'Recurring', 'Stopped') "
            "ORDER BY CreatedDate DESC"
        )
        ACTIVE_ORDER_STATUSES = {"Pending", "Initiated", "Recurring"}
        for o in ach_orders:
            status = o["SM_Payment_Status__c"]
            if status in ACTIVE_ORDER_STATUSES:
                print(f"  [ALERTA] ACH {o['Name']} {status} ${o.get('SM_Total__c')} -- "
                      f"cancelar (ver -CancelarACHOrdersSwitchTC.apex)")
            else:
                print(f"  ACH {o['Name']} {status} ${o.get('SM_Total__c')} (info)")


def main() -> None:
    contract_numbers = sys.argv[1:]
    if not contract_numbers:
        print("Uso: python estado_cobros.py <ContractNumber> [<ContractNumber> ...]")
        sys.exit(1)

    en_cancelar = contratos_para_cancelar()
    for cn in contract_numbers:
        reporte_contrato(cn, en_cancelar)


if __name__ == "__main__":
    main()
