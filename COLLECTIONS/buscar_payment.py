"""
Busqueda rapida de un Payment (PY-xxxxx): valida si fue reportado en
Returns (ACH), Collections (Check Collection Daily) o ACH Reportados
(transmission), y trae estados y fechas -- combinando:

  1) Salesforce en vivo (SM_Payment__c, fuente de verdad): los campos
     SM_Check_Collection_Status__c / SM_Return_code__c / etc. quedan
     guardados ahi tras cada import, asi que reflejan el ULTIMO evento
     (Returns o Collections) que toco ese payment.
  2) El indice historico de TODOS los PDFs archivados en OneDrive
     (COMPILADO COLLECTIONS/ACH Returns y /Check Collection, ver
     build_index.py), asi que encuentra el payment sin importar el mes
     en que fue reportado -- no solo el ultimo import del dia.
  3) El indice historico de transmision ACH (COMPILADO COLLECTIONS/ACH
     Reportados + Files de Salesforce, ver ACH_REPORTADOS/build_index.py),
     que registra cuando un payment fue transmitido (no si fue
     retornado/cobrado).

El indice se actualiza automaticamente (de forma incremental, solo
archivos nuevos) antes de cada busqueda. Usa --no-update para saltar ese
paso.

Requisitos: sf CLI instalado y autenticado contra la org (alias MONEE).

Uso:
    python buscar_payment.py PY-01868511
    python buscar_payment.py 01868511 01867675 PY-01861633
    python buscar_payment.py --no-update PY-01868511
"""

import csv
import json
import re
import shutil
import subprocess
import sys
from pathlib import Path

import build_index
import ACH_REPORTADOS.build_index as transmission_build_index

ORG_ALIAS = "MONEE"
SCRIPT_DIR = Path(__file__).resolve().parent
RETURNS_INDEX_CSV = build_index.RETURNS_INDEX_CSV
COLLECTIONS_INDEX_CSV = build_index.COLLECTIONS_INDEX_CSV
TRANSMISSION_INDEX_CSV = transmission_build_index.INDEX_CSV

SOQL_FIELDS = [
    "Id", "Name", "Payment_Status__c", "SM_Amount__c",
    "SM_Contract__r.ContractNumber",
    "SM_Check_Collection__c", "SM_Check_Collection_Status__c",
    "SM_Check_Collection_Date__c", "SM_Return_code__c",
    "SM_Return_Change__c", "LastModifiedDate", "CreatedDate", "SM_Date_ACH_Transmitted__c", "SM_Transmission_Date_ACH_File__c"
]

RETURN_STATUSES = {"RETURN"}
COLLECTION_STATUSES = {"COLLECTED", "PENDING", "NOT COLLECTED"}

SF_BIN = shutil.which("sf") or "sf"


def normalize_payment_name(raw: str) -> str:
    """'01868511' / 'py-1868511' / 'PY-01868511' -> 'PY-01868511'."""
    digits = re.sub(r"(?i)^py-?", "", raw.strip())
    digits = digits.lstrip("0") or "0"
    return "PY-" + digits.zfill(8)


def query_salesforce(payment_name: str):
    query = f"SELECT {', '.join(SOQL_FIELDS)} FROM SM_Payment__c WHERE Name = '{payment_name}'"
    try:
        result = subprocess.run(
            [SF_BIN, "data", "query", "-o", ORG_ALIAS, "--query", query, "--json"],
            capture_output=True, text=True,
        )
    except FileNotFoundError:
        return None, "No se encontro el sf CLI en el PATH."

    if result.returncode != 0:
        return None, (result.stderr or result.stdout).strip()
    try:
        payload = json.loads(result.stdout)
    except json.JSONDecodeError:
        return None, "No se pudo interpretar la respuesta del sf CLI."
    return payload.get("result", {}).get("records", []), None


def search_index(csv_path: Path, payment_name: str):
    """Devuelve TODAS las filas del indice que hagan match (un payment puede
    aparecer mas de una vez a lo largo de los meses, ej. pending y luego
    collected en dias distintos)."""
    if not csv_path.exists():
        return []
    with csv_path.open(newline="", encoding="utf-8") as f:
        return [row for row in csv.DictReader(f) if row.get("Payment_Name") == payment_name]


def classify(status: str) -> str:
    # El picklist en Salesforce usa guion bajo (ej. 'NOT_COLLECTED') mientras
    # que el CSV extraido del PDF usa espacio ('NOT COLLECTED'); normalizamos
    # antes de comparar para que ambos calcen contra el mismo set.
    normalized = status.replace("_", " ")
    if normalized in RETURN_STATUSES:
        return "RETURNS (ACH)"
    if normalized in COLLECTION_STATUSES:
        return "COLLECTIONS (Check Collection)"
    return "sin clasificar"


def print_result(payment_name: str):
    print("=" * 70)
    print(f"Payment: {payment_name}")
    print("=" * 70)

    records, error = query_salesforce(payment_name)
    if error:
        print(f"  [Salesforce] ERROR consultando la org: {error}")
    elif not records:
        print("  [Salesforce] No existe ningun SM_Payment__c con ese Name.")
    else:
        for rec in records:
            status = (rec.get("SM_Check_Collection_Status__c") or "").strip()
            reported = rec.get("SM_Check_Collection__c")
            contract = (rec.get("SM_Contract__r") or {}).get("ContractNumber")
            print(f"  [Salesforce] Id: {rec.get('Id')}")
            print(f"    Contrato: {contract or '(sin contrato)'}  |  Monto: {rec.get('SM_Amount__c')}")
            print(f"    Payment_Status__c: {rec.get('Payment_Status__c')}")
            if reported:
                print(f"    Reportado como: {classify(status)}")
                print(f"    SM_Check_Collection_Status__c: {status or '(vacio)'}")
                print(f"    SM_Check_Collection_Date__c: {rec.get('SM_Check_Collection_Date__c')}")
                if status in RETURN_STATUSES:
                    print(f"    SM_Return_code__c: {rec.get('SM_Return_code__c') or '(vacio)'}")
                    print(f"    SM_Return_Change__c: {rec.get('SM_Return_Change__c') or '(vacio)'}")
            else:
                print("    No reportado en Returns ni en Collections (SM_Check_Collection__c = false/null).")
            print(f"    LastModifiedDate                     : {rec.get('LastModifiedDate')}")
            print(f"    CreatedDate                          : {rec.get('CreatedDate')}")
            print(f"    SM_Date_ACH_Transmitted__c           : {rec.get('SM_Date_ACH_Transmitted__c')}")
            print(f"    SM_Transmission_Date_ACH_File__c     : {rec.get('SM_Transmission_Date_ACH_File__c')}")



    returns_rows = search_index(RETURNS_INDEX_CSV, payment_name)
    coll_rows = search_index(COLLECTIONS_INDEX_CSV, payment_name)
    transmission_rows = search_index(TRANSMISSION_INDEX_CSV, payment_name)

    if returns_rows:
        print(f"  [Indice historico RETURNS] {len(returns_rows)} coincidencia(s):")
        for row in returns_rows:
            print(f"    - {row.get('SM_Check_Collection_Date__c')}"
                  f"  |  Codigo: {row.get('SM_Return_code__c')}"
                  f"  |  Motivo: {row.get('Reason_Description')}"
                  f"  |  Fuente: {row.get('Source_File')}")
    else:
        print("  [Indice historico RETURNS] no aparece en ningun PDF indexado")

    if coll_rows:
        print(f"  [Indice historico COLLECTIONS] {len(coll_rows)} coincidencia(s):")
        for row in coll_rows:
            print(f"    - {row.get('SM_Check_Collection_Date__c')}"
                  f"  |  Seccion: {row.get('Section')}"
                  f"  |  Razon: {row.get('Reason')}"
                  f"  |  Fuente: {row.get('Source_File')}")
    else:
        print("  [Indice historico COLLECTIONS] no aparece en ningun PDF indexado")

    if transmission_rows:
        print(f"  [Indice historico ACH REPORTADOS (Transmission)] {len(transmission_rows)} coincidencia(s):")
        for row in transmission_rows:
            print(f"    - {row.get('SM_Transmission_Date_ACH_File__c')}"
                  f"  |  Monto: {row.get('Amount')}"
                  f"  |  Fuente: {row.get('Source_File')}")
    else:
        print("  [Indice historico ACH REPORTADOS (Transmission)] no aparece en ningun archivo indexado")

    print()


def main():
    args = sys.argv[1:]
    update = True
    if "--no-update" in args:
        update = False
        args = [a for a in args if a != "--no-update"]

    if not args:
        print("Uso: python buscar_payment.py [--no-update] <PY-xxxxx | numero> [mas...]")
        sys.exit(1)

    if update:
        print("Actualizando indice historico (solo archivos nuevos)...")
        build_index.update_indexes(quiet=True)
        try:
            transmission_build_index.update_index(quiet=True)
        except Exception as exc:
            print(f"  AVISO: no se pudo actualizar el indice de ACH Reportados: {exc}")
        print()

    for raw in args:
        print_result(normalize_payment_name(raw))


if __name__ == "__main__":
    main()
