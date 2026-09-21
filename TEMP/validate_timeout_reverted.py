"""
validate_timeout_reverted.py
------------------------------
SOLO LECTURA. Valida "Pagos aceptados por timeout y luego revertidos por
reporte real": cruza los payments actualmente ACCEPTED via el mecanismo de
15 dias sin reporte (tag PRC_AUT_..D_SIN_REPORTE en
SM_Historical_Collection_Status__c) contra el indice historico de
Returns/Collection, usando la misma logica de "reporte ganador" (mas
reciente por fecha real del PDF) validada en sesiones anteriores.

Un payment "deberia revertirse" si el reporte ganador dice algo distinto
de ACCEPTED/COLLECTED -- eso confirma que el timeout acerto mal y el banco
si tenia un veredicto real (RETURN/PENDING/NOT_COLLECTED) que nunca se
aplico.

Uso:
    python validate_timeout_reverted.py
"""
import csv
import re
from datetime import date
from pathlib import Path

COLLECTIONS_DIR = Path(__file__).resolve().parent.parent / "COLLECTIONS"
OUT_DIR = Path(__file__).resolve().parent
TIMEOUT_CSV = OUT_DIR / "timeout_accepted_still_accepted.csv"

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


def norm(v):
    return (v or "").strip().upper().replace("_", " ")


def main():
    returns_rows = load_rows(COLLECTIONS_DIR / "index" / "returns_index.csv")
    collections_rows = load_rows(COLLECTIONS_DIR / "index" / "collections_index.csv")
    winners = resolve_winners(returns_rows, collections_rows)
    print(f"Payments con reporte historico (cualquier fecha): {len(winners)}")

    timeout_payments = list(csv.DictReader(TIMEOUT_CSV.open(newline="", encoding="utf-8-sig")))
    print(f"Payments ACCEPTED via timeout (aun no revertidos): {len(timeout_payments)}")

    should_revert = []
    no_report_at_all = 0
    confirms_accepted = 0

    for p in timeout_payments:
        name = p["Name"].strip()
        winner = winners.get(name)
        if winner is None:
            no_report_at_all += 1
            continue
        d, report_d, src, row = winner
        expected_status = row.get("Payment_Status__c", "")
        expected_coll_status = row.get("SM_Check_Collection_Status__c", "")
        if norm(expected_status) == "ACCEPTED" or norm(expected_coll_status) in ("COLLECTED", "ACCEPTED"):
            confirms_accepted += 1
            continue
        reason = row.get("Reason_Description", "") if src == "returns" else row.get("Reason", "")
        return_code = row.get("SM_Return_code__c", "") if src == "returns" else ""
        should_revert.append({
            "Payment_Name": name,
            "Contrato": p.get("SM_Contract__r.ContractNumber", ""),
            "Monto": p.get("SM_Amount__c", ""),
            "Transmitido": p.get("SM_Transmission_Date_ACH_File__c", ""),
            "Actual_Payment_Status": p.get("Payment_Status__c", ""),
            "Actual_Collection_Status": p.get("SM_Check_Collection_Status__c", ""),
            "Reporte_Ganador": src,
            "Fecha_Transaccion": d.isoformat(),
            "Fecha_Reporte_Real": report_d.isoformat() if report_d else "",
            "Motivo_Reporte": reason,
            "Return_Code_Reporte": return_code,
            "Deberia_Ser_Payment_Status": expected_status,
            "Deberia_Ser_Collection_Status": expected_coll_status,
        })

    print(f"Confirmado ACCEPTED por un reporte real (timeout acerto): {confirms_accepted}")
    print(f"Sin ningun reporte todavia (timeout sigue siendo la unica fuente, no revertible aun): {no_report_at_all}")
    print(f"DEBERIAN REVERTIRSE (reporte real contradice el ACCEPTED por timeout): {len(should_revert)}")

    if should_revert:
        out_csv = OUT_DIR / "timeout_deberian_revertirse.csv"
        fieldnames = list(should_revert[0].keys())
        with out_csv.open("w", newline="", encoding="utf-8") as f:
            w = csv.DictWriter(f, fieldnames=fieldnames)
            w.writeheader()
            for row in sorted(should_revert, key=lambda r: r["Fecha_Transaccion"], reverse=True):
                w.writerow(row)
        print(f"\nCSV: {out_csv}")
        print("\n=== Detalle ===")
        for row in should_revert:
            print(f"  {row['Payment_Name']} (Contrato {row['Contrato']}, ${row['Monto']}) "
                  f"| transmitido {row['Transmitido']} | reporte {row['Reporte_Ganador']} "
                  f"{row['Fecha_Transaccion']} (real {row['Fecha_Reporte_Real']}) "
                  f"| deberia ser {row['Deberia_Ser_Payment_Status']}/{row['Deberia_Ser_Collection_Status']} "
                  f"| motivo: {row['Motivo_Reporte']} {row['Return_Code_Reporte']}")


if __name__ == "__main__":
    main()
