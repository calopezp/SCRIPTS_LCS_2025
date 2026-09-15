"""
r10_backfill_scope.py
----------------------
SOLO LECTURA. Identifica el alcance exacto para el backfill de R10 pedido
por el usuario: pagos de 2026-06-01 a la fecha que aparecen como R10 en
los reportes de RETURN/COLLECTION, y compara contra el estado en vivo en
Salesforce para saber cuales realmente necesitan cambiar.

Reusa la misma logica de "reporte ganador" (mas reciente por fecha REAL
del reporte, parseada del nombre del PDF) validada en
analisis_discrepancias_jun2026.py.

Uso:
    python r10_backfill_scope.py
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

MONTHS = {
    "jan": 1, "january": 1, "feb": 2, "february": 2, "mar": 3, "march": 3, "marh": 3,
    "apr": 4, "april": 4, "may": 5, "jun": 6, "june": 6, "jul": 7, "july": 7,
    "aug": 8, "august": 8, "sep": 9, "sept": 9, "september": 9, "oct": 10, "october": 10,
    "nov": 11, "november": 11, "dec": 12, "december": 12,
}
DIGIT_DATE_RE = re.compile(r"_(\d{2})(\d{2})(\d{4})")
MONTHNAME_DATE_RE = re.compile(r"([A-Za-z]+)\s+(\d{1,2})(?:[a-z](\d{1,2}))?(?:\s+(\d{4}))?")
DEFAULT_YEAR = 2026


def parse_report_date(source_file: str):
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
            day = max(day1, day2)
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


def is_r10(src, row):
    if src == "returns":
        return (row.get("SM_Return_code__c", "") or "").strip().upper() == "R10"
    else:
        reason = (row.get("Reason", "") or "").strip().upper()
        return reason.startswith("R10")


def query_sf(names):
    out = {}
    names = sorted(names)
    chunk = 300
    for i in range(0, len(names), chunk):
        batch = names[i:i + chunk]
        in_clause = ",".join(f"'{n}'" for n in batch)
        soql = (
            "SELECT Id, Name, Payment_Status__c, SM_Check_Collection_Status__c, "
            "SM_Return_code__c, SM_Check_Collection_Return_Reason__c, "
            "SM_Check_Collection_Date__c, SM_Amount__c, SM_Historical_Collection_Status__c, "
            "SM_Contract__r.ContractNumber "
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
    return out


def main():
    returns_rows = load_rows(COLLECTIONS_DIR / "index" / "returns_index.csv")
    collections_rows = load_rows(COLLECTIONS_DIR / "index" / "collections_index.csv")

    winners = resolve_winners(returns_rows, collections_rows)

    r10_winners = {}
    r10_not_winner = []  # payments con alguna fila R10 pero el reporte ganador NO es R10
    r10_all_names = set()

    for d, report_d, name, r in returns_rows:
        if is_r10("returns", r):
            r10_all_names.add(name)
    for d, report_d, name, r in collections_rows:
        if is_r10("collections", r):
            r10_all_names.add(name)

    for name in r10_all_names:
        d, report_d, src, row = winners[name]
        if is_r10(src, row):
            r10_winners[name] = (d, report_d, src, row)
        else:
            r10_not_winner.append((name, d, report_d, src, row))

    print(f"Payments con alguna fila R10 desde 2026-06-01: {len(r10_all_names)}")
    print(f"  -> De esos, el reporte GANADOR (mas reciente) SIGUE siendo R10: {len(r10_winners)}")
    print(f"  -> De esos, el reporte ganador es OTRO (R10 fue superado por un reporte mas nuevo): {len(r10_not_winner)}")

    if r10_not_winner:
        print("\n=== Payments con R10 en algun momento, pero SUPERADOS por un reporte mas reciente (NO se tocan) ===")
        for name, d, report_d, src, row in r10_not_winner:
            print(f"  {name}: reporte ganador = {src} {d} -> Payment_Status={row.get('Payment_Status__c')} "
                  f"Collection_Status={row.get('SM_Check_Collection_Status__c')}")

    sf_data = query_sf(list(r10_winners.keys()))

    print(f"\n=== Detalle de los {len(r10_winners)} payments R10 (ganador) ===\n")

    needs_update = []
    already_ok = []

    for name, (d, report_d, src, row) in sorted(r10_winners.items()):
        sf = sf_data.get(name)
        if sf is None:
            print(f"  {name}: NO ENCONTRADO EN SALESFORCE")
            continue

        reason = row.get("Reason_Description", "") if src == "returns" else row.get("Reason", "")

        target_status = "REJECTED"
        target_coll_status = "NOT_COLLECTED"
        target_code = "R10"
        target_reason = reason

        current_status = sf.get("Payment_Status__c") or ""
        current_coll_status = (sf.get("SM_Check_Collection_Status__c") or "").upper().replace(" ", "_")
        current_code = sf.get("SM_Return_code__c") or ""
        current_reason = sf.get("SM_Check_Collection_Return_Reason__c") or ""

        already_correct = (
            current_status == target_status
            and current_coll_status == target_coll_status
            and current_code == target_code
        )

        rec = {
            "Payment_Name": name,
            "Id": sf.get("Id"),
            "Contrato": (sf.get("SM_Contract__r") or {}).get("ContractNumber", ""),
            "Monto": sf.get("SM_Amount__c"),
            "Reporte_Ganador": src,
            "Fecha_Transaccion": d.isoformat(),
            "Fecha_Reporte_Real": report_d.isoformat() if report_d else "",
            "Motivo_Reporte": reason,
            "Actual_Payment_Status": current_status,
            "Actual_Collection_Status": sf.get("SM_Check_Collection_Status__c") or "",
            "Actual_Return_Code": current_code,
            "Actual_Reason": current_reason,
            "Nuevo_Payment_Status": target_status,
            "Nuevo_Collection_Status": target_coll_status,
            "Nuevo_Return_Code": target_code,
            "Nuevo_Reason": target_reason,
            "Historico_SF": sf.get("SM_Historical_Collection_Status__c") or "",
        }

        if already_correct:
            already_ok.append(rec)
        else:
            needs_update.append(rec)

    print(f"Ya estan correctos (REJECTED/NOT_COLLECTED/R10), no requieren cambio: {len(already_ok)}")
    print(f"Requieren actualizacion: {len(needs_update)}\n")

    for rec in needs_update:
        print("-" * 100)
        print(f"  {rec['Payment_Name']}  (Contrato {rec['Contrato']}, ${rec['Monto']})")
        print(f"    Reporte ganador: {rec['Reporte_Ganador']} | fecha transaccion {rec['Fecha_Transaccion']} | "
              f"fecha reporte real {rec['Fecha_Reporte_Real']} | motivo: {rec['Motivo_Reporte']}")
        print(f"    ACTUAL -> Payment_Status={rec['Actual_Payment_Status']!r} "
              f"Collection_Status={rec['Actual_Collection_Status']!r} "
              f"Return_Code={rec['Actual_Return_Code']!r} Reason={rec['Actual_Reason']!r}")
        print(f"    NUEVO  -> Payment_Status={rec['Nuevo_Payment_Status']!r} "
              f"Collection_Status={rec['Nuevo_Collection_Status']!r} "
              f"Return_Code={rec['Nuevo_Return_Code']!r} Reason={rec['Nuevo_Reason']!r}")

    if needs_update:
        out_csv = OUT_DIR / "r10_backfill_scope.csv"
        fieldnames = list(needs_update[0].keys())
        with out_csv.open("w", newline="", encoding="utf-8") as f:
            w = csv.DictWriter(f, fieldnames=fieldnames)
            w.writeheader()
            for rec in needs_update:
                w.writerow(rec)
        print(f"\nCSV de alcance escrito: {out_csv}")


if __name__ == "__main__":
    main()
