"""
Extractor de reporte ACH Returns/Notification of Change (Banco Popular)
-> CSV listo para actualizar SM_Payment__c en Salesforce.

Requisitos:
    pip install pdfplumber

Uso:
    python extract_ach_returns.py ACHReturnsReport_07202026.pdf salida.csv

Salida (columnas):
    Payment_Name              -> Name del registro SM_Payment__c (match, ej. PY-01867675)
    Payment_Status__c         -> 'REJECTED' (constante)
    SM_Check_Collection_Date__c -> EFF ENTRY DATE convertida a YYYY-MM-DD
    SM_Check_Collection__c    -> 'TRUE' (constante)
    SM_Check_Collection_Status__c -> 'RETURN' (constante)
    SM_Return_code__c         -> Código de REASON (ej. R08)
    SM_Return_Change__c       -> Texto tras 'RETN/CHNG INFO:' (puede venir vacío)

    Se incluyen también columnas de contexto (no van al update, son para
    auditoría/verificación): Batch, Individual_Name, Reason_Description,
    DB_Amount (positivo), CR_Amount (negativo)

    El reporte del banco trae dos variantes de layout para cada entry (ver
    ENTRY_ID_RE / ENTRY_ID_NO_AMOUNTS_RE / AMOUNTS_ONLY_RE más abajo); ambas
    son soportadas.
"""

import csv
import re
import sys
from datetime import datetime

import pdfplumber

# --- Patrones de la estructura fija del reporte ---
# El reporte del banco viene en pares de líneas por cada entry, pero el orden
# de las columnas varía según si el batch trae el NOMBRE del cliente en el
# campo "INDIVIDUAL NAME / ID" (formato A) o si ese campo viene con el propio
# Payment Name en su lugar (formato B, sin nombre disponible):
#
#   Formato A:
#     <RETN.TRACE> <NOMBRE CLIENTE>            <CODE> <ABA> <ACCOUNT>
#     <ORIG.TRACE> <PY-xxxxx> CR: $.. DB: $..
#
#   Formato B:
#     <ORIG.TRACE> <PY-xxxxx>                  <CODE> <ABA> <ACCOUNT>
#     <RETN.TRACE> <IND.TRAN ID> CR: $.. DB: $..
#
# Además del reporte "nuevo" (ACHReturnsReport_*.pdf, header de batch en una
# sola línea "RECVD BATCH # ..." y "DB:" para el débito), existen en el
# archivo historico de OneDrive reportes "viejos" (nombre manual, ej. "ACH
# Returns June 10 2026.pdf", via webcmpr.bancopopular.com) con la misma
# estructura de entries pero: el header de batch viene partido en dos líneas
# ("RECVD ACH EFF ENTRY STTLE. ENTRY COMPANY" / "BATCH # TYPE DATE DATE
# DESCRIPTION NAME"), y el débito se etiqueta "DR:" en vez de "DB:". Los
# patrones de abajo aceptan ambas variantes.
BATCH_HEADER_MARK = "RECVD BATCH #"
BATCH_DATA_RE = re.compile(
    r"^(?P<batch>\d{7})\s+(?P<ach_type>\S+)\s+(?P<eff_date>\d{6})\s+(?P<settle_date>\d+)\s+(?P<description>.*)$"
)
# Formato A, segunda línea: PY- + montos juntos.
ENTRY_ID_RE = re.compile(
    r"^(?P<orig_trace>\d+)\s+(?P<payment_name>PY-\d+)\s+CR:\s+\$(?P<cr>[\d.,]+)\s+(?:DB|DR):\s+\$(?P<db>[\d.,]+)"
)
# Formato B, primera línea: PY- sin montos (seguido de code/aba/account).
ENTRY_ID_NO_AMOUNTS_RE = re.compile(
    r"^(?P<orig_trace>\d+)\s+(?P<payment_name>PY-\d+)\s+\d+\s+\S+\s+\S+$"
)
# Formato B, segunda línea: montos sin PY- (trace + id transaccional + CR/DB).
AMOUNTS_ONLY_RE = re.compile(
    r"^(?P<retn_trace>\d+)\s+\d+\s+CR:\s+\$(?P<cr>[\d.,]+)\s+(?:DB|DR):\s+\$(?P<db>[\d.,]+)"
)
REASON_RE = re.compile(r"^REASON:\s+(?P<code>\S+)\s+(?P<desc>.*)$")
RETN_CHNG_RE = re.compile(r"^RETN/CHNG INFO:\s*(?P<info>.*)$")
NAME_LINE_RE = re.compile(
    r"^(?P<retn_trace>\d+)\s+(?P<name>.+?)\s+\d+\s+\d+\s+\d+$"
)


def eff_date_to_iso(eff_date_yymmdd: str) -> str:
    """Convierte '260720' -> '2026-07-20'. Formato del banco: yymmdd, siglo 20xx."""
    dt = datetime.strptime(eff_date_yymmdd, "%y%m%d")
    return dt.strftime("%Y-%m-%d")


def signed_amount(raw: str, negative: bool) -> str:
    """Normaliza un monto de texto ('1,050.00') a string con el signo esperado.
    CR siempre negativo, DB siempre positivo (0 se deja sin signo)."""
    value = float(raw.replace(",", ""))
    if value == 0:
        return "0.00"
    signed = -abs(value) if negative else abs(value)
    return f"{signed:.2f}"


def extract_records(pdf_path: str):
    records = []
    current_batch = None
    current_eff_date_iso = None
    current_individual_name = None
    pending_entry = None  # dict acumulando datos del entry en curso

    with pdfplumber.open(pdf_path) as pdf:
        for page in pdf.pages:
            text = page.extract_text() or ""
            lines = text.split("\n")

            for i, line in enumerate(lines):
                line = line.strip()

                # 1) Detectar header de batch -> la siguiente línea trae los datos
                if line.startswith(BATCH_HEADER_MARK):
                    continue  # los datos vienen en la línea siguiente
                m = BATCH_DATA_RE.match(line)
                if m and current_batch != m.group("batch"):
                    # Confirmamos que es realmente la línea de datos del batch
                    # (evita falsos positivos) revisando las 1-2 líneas
                    # anteriores por "BATCH #": en el reporte nuevo el header
                    # va en una sola línea ("RECVD BATCH # ..."), en el viejo
                    # va partido en dos ("RECVD ACH EFF ..." / "BATCH # TYPE ...").
                    header_context = " ".join(lines[max(0, i - 2):i])
                    if "BATCH #" in header_context:
                        current_batch = m.group("batch")
                        current_eff_date_iso = eff_date_to_iso(m.group("eff_date"))
                        continue

                # 2) Línea con NOMBRE del individuo (formato A, antes de la línea con PY-)
                name_m = NAME_LINE_RE.match(line)
                if name_m and "PY-" not in line:
                    current_individual_name = name_m.group("name").strip()
                    continue

                # 3) Formato A: línea con Payment Name (PY-xxxxx) + montos juntos
                entry_m = ENTRY_ID_RE.match(line)
                if entry_m:
                    pending_entry = {
                        "Batch": current_batch,
                        "Payment_Name": entry_m.group("payment_name"),
                        "Individual_Name": current_individual_name,
                        "CR_Amount": signed_amount(entry_m.group("cr"), negative=True),
                        "DB_Amount": signed_amount(entry_m.group("db"), negative=False),
                        "SM_Check_Collection_Date__c": current_eff_date_iso,
                    }
                    continue

                # 3b) Formato B: línea con Payment Name (PY-xxxxx) SIN montos
                # (el campo NAME/ID trae el PY- en vez del nombre del cliente;
                # los montos llegan en la línea siguiente sin PY-).
                entry_no_amounts_m = ENTRY_ID_NO_AMOUNTS_RE.match(line)
                if entry_no_amounts_m:
                    pending_entry = {
                        "Batch": current_batch,
                        "Payment_Name": entry_no_amounts_m.group("payment_name"),
                        "Individual_Name": None,
                        "CR_Amount": None,
                        "DB_Amount": None,
                        "SM_Check_Collection_Date__c": current_eff_date_iso,
                    }
                    continue

                # 3c) Formato B: línea con montos SIN PY- -> completa el pending_entry
                # abierto en el paso 3b.
                amounts_only_m = AMOUNTS_ONLY_RE.match(line)
                if amounts_only_m and pending_entry is not None and pending_entry.get("CR_Amount") is None:
                    pending_entry["CR_Amount"] = signed_amount(amounts_only_m.group("cr"), negative=True)
                    pending_entry["DB_Amount"] = signed_amount(amounts_only_m.group("db"), negative=False)
                    continue

                # 4) Línea de REASON
                reason_m = REASON_RE.match(line)
                if reason_m and pending_entry is not None:
                    pending_entry["SM_Return_code__c"] = reason_m.group("code")
                    pending_entry["Reason_Description"] = reason_m.group("desc").strip()
                    continue

                # 5) Línea de RETN/CHNG INFO -> cierra el entry
                retn_m = RETN_CHNG_RE.match(line)
                if retn_m and pending_entry is not None:
                    pending_entry["SM_Return_Change__c"] = retn_m.group("info").strip()
                    # Completar campos constantes
                    pending_entry["Payment_Status__c"] = "REJECTED"
                    pending_entry["SM_Check_Collection__c"] = "TRUE"
                    pending_entry["SM_Check_Collection_Status__c"] = "RETURN"
                    records.append(pending_entry)
                    pending_entry = None
                    current_individual_name = None
                    continue

    return records


FIELDNAMES = [
    "Payment_Name",
    "Payment_Status__c",
    "SM_Check_Collection_Date__c",
    "SM_Check_Collection__c",
    "SM_Check_Collection_Status__c",
    "SM_Return_code__c",
    "SM_Return_Change__c",
    # columnas de auditoría / verificación (no forman parte del update)
    "Batch",
    "Individual_Name",
    "Reason_Description",
    "CR_Amount",
    "DB_Amount",
]


def write_csv(records, out_path: str):
    with open(out_path, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=FIELDNAMES)
        writer.writeheader()
        for r in records:
            writer.writerow(r)


def has_extractable_text(pdf_path: str) -> bool:
    """Algunos PDFs del banco no traen texto real: las letras vienen como
    trazos vectoriales (o una imagen), típicamente un PDF 'impreso' con las
    fuentes convertidas a curvas. pdfplumber no puede leer eso -- se
    necesitaría OCR. Esto sirve para distinguir ese caso (0 caracteres en
    todo el documento) de un simple desajuste de formato/regex."""
    with pdfplumber.open(pdf_path) as pdf:
        return any((page.extract_text() or "").strip() for page in pdf.pages)


def main():
    if len(sys.argv) != 3:
        print("Uso: python extract_ach_returns.py <input.pdf> <output.csv>")
        sys.exit(1)

    pdf_path, out_path = sys.argv[1], sys.argv[2]
    records = extract_records(pdf_path)

    if not records:
        print(f"ERROR: no se pudo extraer ningún registro de '{pdf_path}'.")
        if has_extractable_text(pdf_path):
            print("El PDF sí tiene texto, pero no matchea el formato esperado")
            print("(layout distinto, reporte vacío ese día, o un formato nuevo del banco).")
        else:
            print("El PDF no tiene texto extraíble: probablemente las letras vienen")
            print("como trazos vectoriales o una imagen (un PDF 'impreso') en vez de")
            print("texto real. Esto no se puede leer con este extractor -- se necesitaría OCR.")
        print("Revisa el PDF manualmente antes de reintentar. No se genera ningún CSV.")
        sys.exit(1)

    write_csv(records, out_path)
    print(f"Extraídos {len(records)} registros -> {out_path}")


if __name__ == "__main__":
    main()
