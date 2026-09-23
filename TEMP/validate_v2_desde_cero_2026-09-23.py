import csv
import json
import re
from collections import defaultdict, Counter
from datetime import date
from pathlib import Path

REPO = Path(r"C:\SALESFORCE\LCS\SCRIPTS_LCS_2025")
TEMP = REPO / "TEMP"
COLLECTIONS_DIR = REPO / "COLLECTIONS"
TODAY = date(2026, 9, 23)

UNRESOLVED = {"PENDING", "RETURN", "Pending", "Return"}
DEFINITIVE_CODES = {"R02", "R04", "R07", "R10", "R13", "R16"}

MONTH_NAMES = {
    "January": 1, "February": 2, "March": 3, "April": 4, "May": 5, "June": 6,
    "July": 7, "August": 8, "September": 9, "October": 10, "November": 11, "December": 12,
    "Jan": 1, "Feb": 2, "Mar": 3, "Apr": 4, "Jun": 6, "Jul": 7, "Aug": 8,
    "Sep": 9, "Sept": 9, "Oct": 10, "Nov": 11, "Dec": 12,
    "Marh": 3,
}
_MONTH_PATTERN = "|".join(sorted(MONTH_NAMES, key=len, reverse=True))


def parse_date_from_filename(name: str):
    stem = name[:-4] if name.lower().endswith(".pdf") else name
    m = re.search(r"(\d{2})_(\d{2})_(\d{4})", stem)
    if m:
        mm, dd, yyyy = m.groups()
        try:
            return date(int(yyyy), int(mm), int(dd))
        except ValueError:
            pass
    m = re.search(r"(\d{8})$", stem)
    if m:
        mmddyyyy = m.group(1)
        try:
            return date(int(mmddyyyy[4:8]), int(mmddyyyy[0:2]), int(mmddyyyy[2:4]))
        except ValueError:
            pass
    m = re.search(rf"({_MONTH_PATTERN})\s+(\d{{1,2}})(?:-(\d{{1,2}}))?\s*,?\s*(\d{{4}})?", stem)
    if m:
        month_name, d1, _d2, yyyy = m.groups()
        month = MONTH_NAMES[month_name]
        year = int(yyyy) if yyyy else None
        if year:
            try:
                return date(year, month, int(d1))
            except ValueError:
                return None
    return None


def load_index(path: Path, source_label: str):
    rows_by_payment = defaultdict(list)
    if not path.exists():
        return rows_by_payment
    with path.open(newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for i, row in enumerate(reader):
            name = (row.get("Payment_Name") or "").strip()
            if not name:
                continue
            raw_date = row.get("SM_Check_Collection_Date__c") or ""
            try:
                d = date.fromisoformat(raw_date)
            except ValueError:
                continue
            src_file = row.get("Source_File") or ""
            row["_source_label"] = source_label
            row["_txn_date"] = d
            row["_file_date"] = parse_date_from_filename(src_file)
            row["_row_order"] = i
            rows_by_payment[name].append(row)
    return rows_by_payment


def pick_winner(rows):
    def sort_key(r):
        source_rank = 1 if r["_source_label"] == "collections" else 0
        file_date = r["_file_date"] or date.min
        return (file_date, r["_txn_date"], source_rank, r["_row_order"])
    return sorted(rows, key=sort_key)[-1]


def load_cancel_list():
    names = set()
    path = COLLECTIONS_DIR / "CANCELACIONES" / "Contratos_para_Cancelar_LOG.csv"
    with path.open(newline="", encoding="utf-8") as f:
        for line in f:
            parts = line.split("\t")
            if parts and parts[0].strip():
                names.add(parts[0].strip())
    return names


def evaluate(rec, returns_idx, coll_idx):
    """Devuelve (expected_ps, expected_ccs, basis, winner) o (None, None, 'sin_cambio', winner)."""
    name = rec["Name"]
    ps = rec["Payment_Status__c"]
    ccs = rec.get("SM_Check_Collection_Status__c") or ""
    td = rec.get("SM_Transmission_Date_ACH_File__c")
    days = (TODAY - date.fromisoformat(td)).days if td else None

    rows = list(returns_idx.get(name, [])) + list(coll_idx.get(name, []))
    winner = pick_winner(rows) if rows else None

    if winner is not None:
        w_ps = winner.get("Payment_Status__c", "")
        w_ccs = winner.get("SM_Check_Collection_Status__c", "")
        w_code = winner.get("SM_Return_code__c", "")

        # Regla R10/R11: siempre gana, sin importar el estado anterior
        # (confirmado por Carlos 2026-09-23 -- misma familia de disputa del
        # cliente, R11 se agrego al mismo tratamiento que R10 ese dia).
        if w_code in ("R10", "R11"):
            return "REJECTED", "NOT_COLLECTED", "r10_r11_siempre_gana", winner

        # Codigo definitivo (no R10) -> NOT_COLLECTED de inmediato, sin esperar 26 dias.
        if w_code in DEFINITIVE_CODES and w_ccs in UNRESOLVED:
            return "REJECTED", "NOT_COLLECTED", "codigo_definitivo_excepcion", winner

        # Reporte no resuelto (PENDING/RETURN) y ya pasaron 26 dias -> NOT_COLLECTED (Rule 3).
        if w_ccs in UNRESOLVED and days is not None and days > 26:
            return "REJECTED", "NOT_COLLECTED", "rule3_sobre_reporte_no_resuelto", winner

        # Reporte resuelto (COLLECTED/NOT_COLLECTED literal) o aun dentro de ventana -> usar tal cual.
        return w_ps, w_ccs, "reporte_directo", winner

    # Sin ningun reporte en el indice.
    if ps == "ACH TRANSMITTED":
        if days is not None and days > 15:
            return "ACCEPTED", "COLLECTED", "timeout_15d_sin_reporte", None
        return None, None, "sin_cambio_ventana_normal", None

    if ccs in UNRESOLVED:
        if days is not None and days > 26:
            return "REJECTED", "NOT_COLLECTED", "rule3_sin_reporte", None
        return None, None, "sin_cambio_ventana_normal", None

    return None, None, "resuelto_sin_reporte_no_verificable", None


def main():
    with (TEMP / "_fresh_v2_pop.json").open(encoding="utf-8") as f:
        payload = json.load(f)
    records = payload["result"]["records"]
    print(f"Poblacion total (transmitidos 2026): {len(records)}")

    returns_idx = load_index(COLLECTIONS_DIR / "index" / "returns_index.csv", "returns")
    coll_idx = load_index(COLLECTIONS_DIR / "index" / "collections_index.csv", "collections")
    cancel_list = load_cancel_list()
    print(f"Contratos en lista de cancelacion: {len(cancel_list)}")

    def group_of(rec):
        contract = rec.get("SM_Contract__r") or {}
        status = contract.get("Status")
        cn = contract.get("ContractNumber")
        if status == "Cancelled":
            return "G1_CANCELLED"
        if cn in cancel_list:
            return "G2_ACTIVO_EN_COLA_CANCELAR"
        return "G3_ACTIVO"

    all_mismatches = []
    basis_counter = Counter()
    group_counter = Counter()
    skipped_testvip = 0
    skipped_no_contract = 0

    for rec in records:
        contract = rec.get("SM_Contract__r") or {}
        if not contract:
            skipped_no_contract += 1
            continue
        if contract.get("Is_Test_Contract__c") or contract.get("Is_VIP_Contract__c"):
            skipped_testvip += 1
            continue

        g = group_of(rec)
        group_counter[g] += 1

        exp_ps, exp_ccs, basis, winner = evaluate(rec, returns_idx, coll_idx)
        if exp_ps is None:
            continue

        ps = rec["Payment_Status__c"]
        ccs = rec.get("SM_Check_Collection_Status__c") or ""
        if ps.upper() == exp_ps.upper() and ccs.upper() == exp_ccs.upper():
            continue

        td = rec.get("SM_Transmission_Date_ACH_File__c")
        days = (TODAY - date.fromisoformat(td)).days if td else None
        basis_counter[basis] += 1
        all_mismatches.append({
            "Grupo": g,
            "Payment_Name": rec["Name"],
            "ContractNumber": contract.get("ContractNumber"),
            "ContractStatus": contract.get("Status"),
            "Amount": rec.get("SM_Amount__c"),
            "Days": days,
            "Current_Payment_Status": ps,
            "Current_CCS": ccs,
            "Expected_Payment_Status": exp_ps,
            "Expected_CCS": exp_ccs,
            "Basis": basis,
            "Return_code_actual": rec.get("SM_Return_code__c"),
            "Report_File": winner.get("Source_File") if winner else "",
            "Report_Return_code": winner.get("SM_Return_code__c") if winner else "",
        })

    print(f"Saltados (Test/VIP): {skipped_testvip}")
    print(f"Saltados (sin contrato): {skipped_no_contract}")
    print()
    print("Poblacion por grupo:", dict(group_counter))
    print()
    print(f"TOTAL DESAJUSTES: {len(all_mismatches)}")
    print("Por grupo:", Counter(m["Grupo"] for m in all_mismatches))
    print("Por basis:", basis_counter)

    fieldnames = list(all_mismatches[0].keys()) if all_mismatches else []
    with open(TEMP / "_fresh_v2_mismatches.csv", "w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=fieldnames)
        w.writeheader()
        w.writerows(all_mismatches)
    print("\nCSV escrito: TEMP/_fresh_v2_mismatches.csv")


if __name__ == "__main__":
    main()
