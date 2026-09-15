"""
Analisis de discrepancias Jun-2026 a la fecha
-----------------------------------------------
SOLO LECTURA. No modifica nada en Salesforce ni en los indices.

Cruza el "ganador" (reporte mas reciente, empate gana Collection sobre
Return -- misma logica que build_pending_deltas.py) de returns_index.csv +
collections_index.csv para cada Payment con SM_Check_Collection_Date__c >=
2026-06-01, contra el estado EN VIVO en Salesforce, y marca discrepancias.

Uso:
    python analisis_discrepancias_jun2026.py
"""
import csv
import json
import re
import subprocess
from datetime import date
from pathlib import Path

CUTOFF = date(2026, 6, 1)
COLLECTIONS_DIR = Path(__file__).resolve().parent.parent / "COLLECTIONS"
OUT_DIR = Path(__file__).resolve().parent
TIMEOUT_TAG = "15D_SIN_REPORTE"

MONTHS = {
    "jan": 1, "january": 1, "enero": 1,
    "feb": 2, "february": 2, "febrero": 2,
    "mar": 3, "march": 3, "marzo": 3, "marh": 3,  # typo real visto en varios PDF ("Marh")
    "apr": 4, "april": 4, "abril": 4,
    "may": 5, "mayo": 5,
    "jun": 6, "june": 6, "junio": 6,
    "jul": 7, "july": 7, "julio": 7,
    "aug": 8, "august": 8, "agosto": 8,
    "sep": 9, "sept": 9, "september": 9, "septiembre": 9,
    "oct": 10, "october": 10, "octubre": 10,
    "nov": 11, "november": 11, "noviembre": 11,
    "dec": 12, "december": 12, "diciembre": 12,
}
DIGIT_DATE_RE = re.compile(r"_(\d{2})(\d{2})(\d{4})")
MONTHNAME_DATE_RE = re.compile(
    r"([A-Za-z]+)\s+(\d{1,2})(?:[a-z](\d{1,2}))?(?:\s+(\d{4}))?"
)
DEFAULT_YEAR = 2026  # varios PDF del rango analizado (Jun 3/4.pdf, May 5-14.pdf) no llevan el ano en el nombre


def parse_report_date(source_file: str):
    """Extrae la fecha REAL del reporte (no de la transaccion) a partir del
    nombre del PDF -- necesario porque build_index.py agrega filas en el
    orden en que escanea los PDF, no en orden cronologico del reporte, asi
    que dos filas del mismo Payment con la misma SM_Check_Collection_Date__c
    (ej. un PENDING de un reporte viejo y un COLLECTED de uno mas nuevo)
    pueden quedar en cualquier orden dentro del CSV -- desempatar por orden
    de aparicion en el archivo es enganoso, hay que desempatar por la fecha
    real del reporte."""
    if not source_file:
        return None
    m = DIGIT_DATE_RE.search(source_file)
    if m:
        mm, dd, yyyy = int(m.group(1)), int(m.group(2)), int(m.group(3))
        try:
            return date(yyyy, mm, dd)
        except ValueError:
            pass
    m = MONTHNAME_DATE_RE.search(source_file)
    if m:
        mon = MONTHS.get(m.group(1).lower())
        if mon:
            day1 = int(m.group(2))
            day2 = int(m.group(3)) if m.group(3) else day1
            yyyy = int(m.group(4)) if m.group(4) else DEFAULT_YEAR
            day = max(day1, day2)  # rango tipo "Jun 12a15" -> se queda con el dia mas reciente
            try:
                return date(yyyy, mon, day)
            except ValueError:
                pass
    return None


def load_rows(index_csv: Path):
    rows = []
    with index_csv.open(newline="", encoding="utf-8") as f:
        for r in csv.DictReader(f):
            name = r.get("Payment_Name", "").strip()
            if not name:
                continue
            raw_date = r.get("SM_Check_Collection_Date__c", "")
            try:
                d = date.fromisoformat(raw_date)
            except ValueError:
                continue
            if d < CUTOFF:
                continue
            report_d = parse_report_date(r.get("Source_File", ""))
            rows.append((d, report_d, name, r))
    return rows


def resolve_winners(returns_rows, collections_rows):
    """best[name] = (fecha_transaccion, fecha_reporte_o_None, origen, fila).
    Empate primero por fecha de transaccion (>=, Collections gana empate
    contra Returns via el orden de procesamiento). DENTRO del mismo origen,
    si ademas empata la fecha de transaccion, se desempata por la fecha
    REAL del reporte (parseada del nombre de archivo) en vez del orden de
    aparicion en el CSV -- ver parse_report_date()."""
    best = {}

    def consider(d, report_d, src, name, r):
        cur = best.get(name)
        if cur is None:
            best[name] = (d, report_d, src, r)
            return
        cur_d, cur_report_d, cur_src, _ = cur
        if d > cur_d:
            best[name] = (d, report_d, src, r)
        elif d == cur_d:
            # mismo origen y misma fecha de transaccion -> desempatar por fecha de reporte real
            if src == cur_src and report_d is not None and cur_report_d is not None:
                if report_d >= cur_report_d:
                    best[name] = (d, report_d, src, r)
            elif d >= cur_d:
                best[name] = (d, report_d, src, r)

    for d, report_d, name, r in returns_rows:
        consider(d, report_d, "returns", name, r)
    for d, report_d, name, r in collections_rows:
        consider(d, report_d, "collections", name, r)
    return best


def norm(v):
    """Normaliza para comparar -- MAYUS/minus y '_' vs ' ' no son discrepancias
    reales, son solo variantes de formato del mismo valor de picklist/texto."""
    return (v or "").strip().upper().replace("_", " ")


def query_sf(names):
    """Chunked SOQL query against MONEE, 300 names per batch."""
    out = {}
    names = sorted(names)
    chunk = 300
    for i in range(0, len(names), chunk):
        batch = names[i:i + chunk]
        in_clause = ",".join(f"'{n}'" for n in batch)
        soql = (
            "SELECT Name, Payment_Status__c, SM_Check_Collection_Status__c, "
            "SM_Return_code__c, SM_Check_Collection_Date__c, SM_Amount__c, "
            "SM_Historical_Collection_Status__c, SM_Contract__r.ContractNumber "
            f"FROM SM_Payment__c WHERE Name IN ({in_clause})"
        )
        cmd = ["sf", "data", "query", "-o", "MONEE", "-q", soql, "--json"]
        res = subprocess.run(cmd, capture_output=True, text=True, shell=True)
        if res.returncode != 0:
            print("ERROR en query batch", i, res.stderr[:500])
            continue
        data = json.loads(res.stdout)
        for rec in data["result"]["records"]:
            out[rec["Name"]] = rec
        print(f"  batch {i}-{i+len(batch)}: {len(data['result']['records'])} registros")
    return out


def main():
    returns_rows = load_rows(COLLECTIONS_DIR / "index" / "returns_index.csv")
    collections_rows = load_rows(COLLECTIONS_DIR / "index" / "collections_index.csv")
    print(f"Returns rows >=2026-06-01: {len(returns_rows)}")
    print(f"Collections rows >=2026-06-01: {len(collections_rows)}")

    winners = resolve_winners(returns_rows, collections_rows)
    print(f"Payments unicos (ganador resuelto): {len(winners)}")

    sf_data = query_sf(list(winners.keys()))
    print(f"Encontrados en Salesforce: {len(sf_data)}")

    discrepancies = []
    not_found = []

    for name, (d, report_d, src, row) in winners.items():
        sf = sf_data.get(name)
        if sf is None:
            not_found.append(name)
            continue

        expected_status = row.get("Payment_Status__c", "")
        expected_coll_status = row.get("SM_Check_Collection_Status__c", "")
        expected_return_code = row.get("SM_Return_code__c", "") if src == "returns" else ""
        reason = row.get("Reason_Description", "") if src == "returns" else row.get("Reason", "")

        actual_status = sf.get("Payment_Status__c") or ""
        actual_coll_status = sf.get("SM_Check_Collection_Status__c") or ""
        actual_return_code = sf.get("SM_Return_code__c") or ""
        historical = sf.get("SM_Historical_Collection_Status__c") or ""

        problems = []

        if norm(actual_status) != norm(expected_status):
            problems.append(f"Payment_Status__c: SF='{actual_status}' vs esperado='{expected_status}'")

        if norm(actual_coll_status) != norm(expected_coll_status):
            problems.append(
                f"SM_Check_Collection_Status__c: SF='{actual_coll_status}' vs esperado='{expected_coll_status}'"
            )

        if expected_return_code and norm(actual_return_code) != norm(expected_return_code):
            problems.append(
                f"SM_Return_code__c: SF='{actual_return_code}' vs esperado='{expected_return_code}'"
            )

        if not problems:
            continue

        # Caso especial: ya esta ACCEPTED/COLLECTED en SF pero el reporte ganador dice
        # que deberia ser un RETURN/REJECTED -- esto es justo lo que el guard de
        # regresion de los .apex bloquea para revision manual (no revierte solo).
        blocked_by_guard = (
            actual_status == "ACCEPTED"
            and expected_status == "REJECTED"
            and TIMEOUT_TAG not in historical
        )

        accepted_by_timeout = TIMEOUT_TAG in historical

        contract = ""
        cr = sf.get("SM_Contract__r")
        if cr:
            contract = cr.get("ContractNumber", "")

        discrepancies.append({
            "Payment_Name": name,
            "Contrato": contract,
            "Monto": sf.get("SM_Amount__c"),
            "Reporte_Ganador": src,
            "Fecha_Transaccion": d.isoformat(),
            "Fecha_Reporte_Real": report_d.isoformat() if report_d else "",
            "Motivo_Reporte": reason,
            "Esperado_Payment_Status": expected_status,
            "Esperado_Collection_Status": expected_coll_status,
            "Esperado_Return_Code": expected_return_code,
            "Actual_Payment_Status": actual_status,
            "Actual_Collection_Status": actual_coll_status,
            "Actual_Return_Code": actual_return_code,
            "Bloqueado_por_Guard_Regresion": blocked_by_guard,
            "Aceptado_por_Timeout_15D": accepted_by_timeout,
            "Historico_SF": historical,
            "Detalle": " | ".join(problems),
        })

    out_csv = OUT_DIR / "discrepancias_jun2026.csv"
    if discrepancies:
        fieldnames = list(discrepancies[0].keys())
        with out_csv.open("w", newline="", encoding="utf-8") as f:
            w = csv.DictWriter(f, fieldnames=fieldnames)
            w.writeheader()
            for row in sorted(discrepancies, key=lambda r: r["Fecha_Transaccion"], reverse=True):
                w.writerow(row)

    print()
    print(f"=== RESUMEN ===")
    print(f"Total payments analizados: {len(winners)}")
    print(f"No encontrados en Salesforce (posible ID distinto/borrado): {len(not_found)}")
    print(f"Discrepancias encontradas: {len(discrepancies)}")
    print(f"Bloqueados por guard de regresion (ACCEPTED en SF pero reporte dice RETURN, sin tag timeout): "
          f"{sum(1 for d in discrepancies if d['Bloqueado_por_Guard_Regresion'])}")
    print(f"Aceptados por timeout de 15 dias (posible falso positivo si el reporte llego despues): "
          f"{sum(1 for d in discrepancies if d['Aceptado_por_Timeout_15D'])}")
    print(f"CSV: {out_csv}")
    if not_found:
        nf_csv = OUT_DIR / "discrepancias_jun2026_no_encontrados.csv"
        with nf_csv.open("w", encoding="utf-8") as f:
            f.write("Payment_Name\n")
            for n in not_found:
                f.write(n + "\n")
        print(f"No encontrados CSV: {nf_csv}")


if __name__ == "__main__":
    main()
