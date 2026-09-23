import csv
import json
import re
from collections import defaultdict
from datetime import date
from pathlib import Path

REPO = Path(r"C:\SALESFORCE\LCS\SCRIPTS_LCS_2025")
TEMP = REPO / "TEMP"
COLLECTIONS_DIR = REPO / "COLLECTIONS"
TODAY = date(2026, 9, 23)

UNRESOLVED = {"PENDING", "RETURN", "Pending", "Return"}
DEFINITIVE_CODES = {"R02", "R04", "R07", "R10", "R11", "R13", "R16"}

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


def main():
    with (TEMP / "_live86.json").open(encoding="utf-8") as f:
        records = json.load(f)["result"]["records"]

    returns_idx = load_index(COLLECTIONS_DIR / "index" / "returns_index.csv", "returns")
    coll_idx = load_index(COLLECTIONS_DIR / "index" / "collections_index.csv", "collections")
    cancel_list = load_cancel_list()

    rows_out = []
    for rec in records:
        name = rec["Name"]
        ps = rec["Payment_Status__c"]
        ccs = rec.get("SM_Check_Collection_Status__c") or ""
        contract = rec.get("SM_Contract__r") or {}
        cn = contract.get("ContractNumber")
        cstatus = contract.get("Status")
        cancel_flag = "CANCELLED" if cstatus == "Cancelled" else ("EN_COLA_CANCELAR" if cn in cancel_list else "")

        rows = list(returns_idx.get(name, [])) + list(coll_idx.get(name, []))
        winner = pick_winner(rows) if rows else None
        w_file = winner.get("Source_File") if winner else None
        w_file_date = winner.get("_file_date") if winner else None
        w_ps = winner.get("Payment_Status__c") if winner else None
        w_ccs = winner.get("SM_Check_Collection_Status__c") if winner else None
        w_code = winner.get("SM_Return_code__c") if winner else None

        is_march31_winner = w_file == "Check Collections March 31 2026.pdf"

        # Determinar accion final segun instrucciones del usuario:
        # si el estado actual O el que propone el reporte ganador es
        # transitorio (PENDING/RETURN) y no hay un reporte MAS RECIENTE que
        # confirme ACCEPTED/COLLECTED, se resuelve a NOT_COLLECTED.
        if w_ccs and w_ccs.upper() in ("COLLECTED",) or (w_ps == "ACCEPTED"):
            # El ganador real (mas reciente de todo el indice) SI confirma cobro.
            final_action = "MANTENER" if (ps == "ACCEPTED" and ccs.upper() == "COLLECTED") else "CORREGIR_A_COLLECTED"
            final_ps, final_ccs = "ACCEPTED", "COLLECTED"
        elif w_code in ("R10", "R11"):
            final_action = "MANTENER" if (ps == "REJECTED" and ccs == "NOT_COLLECTED") else "CORREGIR_A_NOT_COLLECTED"
            final_ps, final_ccs = "REJECTED", "NOT_COLLECTED"
        else:
            # winner unresolved (PENDING/RETURN) o NOT_COLLECTED directo, o sin ganador --
            # de cualquier forma, sin confirmacion de cobro mas reciente -> NOT_COLLECTED
            final_action = "MANTENER" if (ps == "REJECTED" and ccs == "NOT_COLLECTED") else "CORREGIR_A_NOT_COLLECTED"
            final_ps, final_ccs = "REJECTED", "NOT_COLLECTED"

        rows_out.append({
            "Payment_Name": name,
            "ContractNumber": cn,
            "ContractStatus": cstatus,
            "Cancelacion": cancel_flag,
            "Current_PS": ps,
            "Current_CCS": ccs,
            "Winner_File": w_file,
            "Winner_File_Date": str(w_file_date) if w_file_date else "",
            "Winner_PS": w_ps,
            "Winner_CCS": w_ccs,
            "Winner_Code": w_code,
            "Es_Solo_El_Archivo_Marzo31": is_march31_winner,
            "Final_PS": final_ps,
            "Final_CCS": final_ccs,
            "Accion": final_action,
        })

    fieldnames = list(rows_out[0].keys())
    with open(TEMP / "_march31_batch_analysis.csv", "w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=fieldnames)
        w.writeheader()
        w.writerows(rows_out)

    from collections import Counter
    print("Total:", len(rows_out))
    print("Por accion:", Counter(r["Accion"] for r in rows_out))
    print("Con contrato Cancelled o en cola:", sum(1 for r in rows_out if r["Cancelacion"]))
    print("CSV escrito: TEMP/_march31_batch_analysis.csv")


if __name__ == "__main__":
    main()
