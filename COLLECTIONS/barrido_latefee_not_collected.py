"""
Barrido de solo lectura: contratos cuyo pago ACH de tipo Fee se transmitio
hace ~26-40 dias y ya quedo NOT_COLLECTED (ventana real de la Rule 3 --
ver CLAUDE.md seccion 2.2 -- no se usa LastModifiedDate como filtro de
fecha porque un barrido/script nuestro puede tocar miles de registros en
bloque sin que eso refleje cuando el pago se resolvio de verdad).

Para cada contrato encontrado, valida que sea una deuda REAL por conteo de
pagos (mismo criterio que COLLECTIONS/estado_cobros.py: pagos Fee
REJECTED+NOT_COLLECTED del monto mensual, menos los ya recuperados via un
pago ACCEPTED de tipo "Late payment fee" -- si el neto es <= 0 el contrato
NO se reporta, ya esta resuelto aunque haya rechazos en el historial) y
despues revisa si ya existe una SM_ACH_Order__c tipo "Late payment fee"
para cobrarla:
  ACTIVA      -- Pending/Initiated/Recurring, lista para cobrar.
  TRANSMITIDA -- ya tiene SM_Date_ACH_Transmitted__c (se envio al banco).
  FALTA       -- no hay ninguna orden viva cubriendo la deuda -- candidata
                 a generar.

Solo lectura -- no crea ni modifica nada (ver feedback_estado_cobros_readonly,
mismo principio aplica aqui). Si aparece "FALTA", la resolucion es manual.

Uso:
    python barrido_latefee_not_collected.py
"""

import sys
from datetime import date, timedelta
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from estado_cobros import sf_query  # noqa: E402

VENTANA_DESDE = (date.today() - timedelta(days=40)).isoformat()
VENTANA_HASTA = (date.today() - timedelta(days=26)).isoformat()


def contratos_candidatos():
    pagos = sf_query(
        "SELECT Name, SM_Contract__c, SM_Contract__r.ContractNumber, SM_Amount__c, "
        "SM_Transmission_Date_ACH_File__c "
        "FROM SM_Payment__c WHERE SM_Type__c = 'Fee' AND Payment_Status__c = 'REJECTED' "
        "AND SM_Check_Collection_Status__c = 'NOT_COLLECTED' "
        f"AND SM_Transmission_Date_ACH_File__c >= {VENTANA_DESDE} "
        f"AND SM_Transmission_Date_ACH_File__c <= {VENTANA_HASTA} "
        "ORDER BY SM_Transmission_Date_ACH_File__c ASC"
    )
    vistos = {}
    for p in pagos:
        cid = p["SM_Contract__c"]
        if cid not in vistos:
            vistos[cid] = {
                "contract_number": p["SM_Contract__r"]["ContractNumber"],
                "monthly_offer": p["SM_Amount__c"],
                "pagos": [],
            }
        vistos[cid]["pagos"].append((p["Name"], p["SM_Transmission_Date_ACH_File__c"]))
    return vistos


def validar_deuda_real(contract_id: str, monthly_offer) -> int:
    missed = sf_query(
        "SELECT COUNT(Id) cnt FROM SM_Payment__c "
        f"WHERE SM_Contract__c = '{contract_id}' AND SM_Type__c = 'Fee' "
        "AND Payment_Status__c = 'REJECTED' AND SM_Check_Collection_Status__c = 'NOT_COLLECTED' "
        f"AND SM_Amount__c = {monthly_offer}"
    )
    missed_cnt = missed[0].get("cnt", 0) if missed else 0
    recovered = sf_query(
        "SELECT COUNT(Id) cnt FROM SM_Payment__c "
        f"WHERE SM_Contract__c = '{contract_id}' AND SM_Type__c = 'Late payment fee' "
        "AND Payment_Status__c = 'ACCEPTED'"
    )
    recovered_cnt = recovered[0].get("cnt", 0) if recovered else 0
    return missed_cnt - recovered_cnt


def estado_orden_latefee(contract_id: str) -> str:
    ordenes = sf_query(
        "SELECT Name, SM_Payment_Status__c, SM_Date_ACH_Transmitted__c FROM SM_ACH_Order__c "
        f"WHERE SM_Contract__c = '{contract_id}' AND SM_Payment_Type__c = 'Late payment fee' "
        "ORDER BY CreatedDate DESC"
    )
    for o in ordenes:
        if o["SM_Payment_Status__c"] in ("Pending", "Initiated", "Recurring"):
            return f"ACTIVA ({o['Name']})"
        if o.get("SM_Date_ACH_Transmitted__c"):
            return f"TRANSMITIDA ({o['Name']}, {o['SM_Date_ACH_Transmitted__c']})"
    return "FALTA generar"


def main() -> None:
    print(f"Ventana de transmision: {VENTANA_DESDE} a {VENTANA_HASTA} (26-40 dias atras)\n")
    candidatos = contratos_candidatos()
    print(f"Contratos con Fee REJECTED/NOT_COLLECTED transmitido en la ventana: {len(candidatos)}\n")

    reportados = 0
    for contract_id, info in candidatos.items():
        still_owed = validar_deuda_real(contract_id, info["monthly_offer"])
        if still_owed <= 0:
            continue  # ya recuperado por otro lado, no es deuda real
        reportados += 1
        estado = estado_orden_latefee(contract_id)
        etiqueta = "" if estado.startswith(("ACTIVA", "TRANSMITIDA")) else "[ALERTA] "
        pagos_str = ", ".join(f"{n} ({d})" for n, d in info["pagos"])
        print(f"{etiqueta}{info['contract_number']} -- debe {still_owed} mes(es) -- "
              f"Late Payment Fee order: {estado}")
        print(f"    Pagos en la ventana: {pagos_str}")

    print(f"\nTotal contratos con deuda real confirmada: {reportados}")


if __name__ == "__main__":
    main()
