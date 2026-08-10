"""
Extractor de reporte Check Collection Daily (TCA) (Banco Popular)
-> CSV listo para actualizar SM_Payment__c en Salesforce.

Requisitos:
    pip install pdfplumber

Uso:
    python extract_check_collection.py CheckCollectionDailyReport_07202026.pdf salida.csv

Match de registros:
    El reporte no trae el Payment Name (PY-xxxxx) directamente, pero el
    CHECK NUMBER sí lo codifica: quitando los ceros a la izquierda y
    dejando 8 dígitos se obtiene el sufijo del Payment Name.
    Verificado contra el org (6/6, nombre y monto exactos):
        CHECK NUMBER 00001867071 -> PY-01867071 (KATHERINE CORREA, $79.00)

    EXCEPCIÓN (verificada en CheckCollectionDailyReport_07242026.pdf): en
    algunas filas el campo DRAWEE NAME no trae el nombre del cliente sino
    directamente un PY-xxxxx. En esos casos el CHECK NUMBER de esa fila NO
    corresponde al pago real (ej. fila con DRAWEE NAME='PY-01868814' y
    CHECK NUMBER='00001539023' -> derivar del check number da 'PY-01539023',
    que es un pago totalmente distinto -DAVID TAYLOR, $94.00- mientras que
    PY-01868814 es CARMEN RODRIGUEZ, $69.00, el monto que sí coincide con la
    fila). Por eso: si DRAWEE NAME ya es un PY-xxxxx, se usa tal cual; solo
    se deriva del CHECK NUMBER cuando DRAWEE NAME es un nombre real.

Secciones del reporte -> campos de salida:
    TRANSACTIONS: COLLECTED     -> Payment_Status__c = ACCEPTED,
                                    SM_Check_Collection_Status__c = COLLECTED
    TRANSACTIONS: PENDING       -> Payment_Status__c = REJECTED,
                                    SM_Check_Collection_Status__c = PENDING
    TRANSACTIONS: NOT COLLECTED -> Payment_Status__c = REJECTED,
                                    SM_Check_Collection_Status__c = NOT COLLECTED
    (en los 3 casos SM_Check_Collection__c = TRUE)

    SM_Check_Collection_Date__c viene del TRAN DATE de cada fila (mm-dd),
    combinado con el año del "As of date" del reporte (si el mes de la
    transacción es mayor al mes del "As of date", se asume año anterior,
    para el caso de reportes de inicio de año referenciando diciembre).

    Se incluyen columnas de contexto (no van al update, son para
    auditoría/verificación): Section, Drawee_Name, Check_Number,
    Reference_Number, Amount, Reason

Reporte aparte para Comercial (REASON = R10):
    R10 ("CUST ADV NOT...") significa que el cliente solicitó la devolución
    directamente al banco. Esos registros se actualizan en Salesforce igual
    que cualquier otro (mismo Payment_Status__c/SM_Check_Collection_*), pero
    además se genera un CSV aparte (<salida>_R10_ClienteSolicitoDevolucion.csv)
    para que Comercial se comunique con esos clientes.
"""

import csv
import os
import re
import sys
from datetime import datetime

import pdfplumber

# Reporte "nuevo" (CheckCollectionDailyReport_*.pdf): "As of date: MM/DD/YYYY".
AS_OF_DATE_RE = re.compile(r"As of date:\s*(\d{2})/(\d{2})/(\d{4})")
# Reporte "viejo" (nombre manual en el archivo historico de OneDrive, ej.
# "Check Collections Jun 10 2026.pdf", via webcmpr.bancopopular.com):
# la fecha viene como "As of YYYY-MM-DD" (sin "date:").
AS_OF_DATE_LEGACY_RE = re.compile(r"^As of (\d{4})-(\d{2})-(\d{2})$")
SECTION_RE = re.compile(r"^TRANSACTIONS:\s*(PENDING|COLLECTED|NOT COLLECTED)\s*$")
# DRAWEE ACCOUNT viene vacío en todos los reportes observados, por lo que
# no aparece como columna independiente en el texto extraído.
# El reporte viejo no siempre trae el signo "$" antes del monto, ni el
# código D/L final (a veces la fila termina justo despues del REASON), asi
# que ambos son opcionales para soportar los dos formatos. La variante
# "Weekly" (ej. "Check Collections Jun 26 2026 Weekly.pdf") ademas escribe
# la fecha como "MMDD" sin guion (vs "MM-DD" en Daily) y el D/L como un
# contador de ancho variable (2, 3, 10, 14...) en vez de siempre 2 digitos.
ROW_RE = re.compile(
    r"^(?P<tran_date>\d{2}-?\d{2})\s+(?P<ref_number>\d+)\s+(?P<drawee_name>.+?)\s+"
    r"(?P<check_number>\d+)\s+\$?(?P<amount>[\d.,]+)\s+(?P<bank_aba>\d+)\s+"
    r"(?P<reason>.*?)(?:\s+(?P<dl>\d{1,3}))?$"
)

SECTION_TO_STATUS = {
    "PENDING": ("REJECTED", "PENDING"),
    "COLLECTED": ("ACCEPTED", "COLLECTED"),
    "NOT COLLECTED": ("REJECTED", "NOT COLLECTED"),
}

DRAWEE_NAME_IS_PY_RE = re.compile(r"^PY-\d+$")


def payment_name_from_check_number(check_number: str) -> str:
    """CHECK NUMBER -> Payment Name. Verificado: 00001867071 -> PY-01867071."""
    digits = check_number.lstrip("0") or "0"
    return "PY-" + digits.zfill(8)


def resolve_payment_name(drawee_name: str, check_number: str) -> str:
    """Si DRAWEE NAME ya es un PY-xxxxx, se usa directo (el CHECK NUMBER de
    esa fila no es confiable en ese caso). Si no, se deriva del CHECK NUMBER."""
    drawee_name = drawee_name.strip()
    if DRAWEE_NAME_IS_PY_RE.match(drawee_name):
        return drawee_name
    return payment_name_from_check_number(check_number)


def tran_date_to_iso(tran_date_mmdd: str, asof_month: int, asof_year: int) -> str:
    """'07-17' o '0717' + año del 'As of date' -> '2026-07-17'."""
    digits = tran_date_mmdd.replace("-", "")
    month = int(digits[:2])
    day = int(digits[2:])
    year = asof_year - 1 if month > asof_month else asof_year
    dt = datetime(year, month, day)
    return dt.strftime("%Y-%m-%d")


def extract_records(pdf_path: str):
    records = []
    current_section = None
    asof_month = None
    asof_year = None

    with pdfplumber.open(pdf_path) as pdf:
        for page in pdf.pages:
            text = page.extract_text() or ""
            lines = text.split("\n")

            for line in lines:
                line = line.strip()

                asof_m = AS_OF_DATE_RE.search(line)
                if asof_m:
                    asof_month = int(asof_m.group(1))
                    asof_year = int(asof_m.group(3))
                    continue

                asof_legacy_m = AS_OF_DATE_LEGACY_RE.match(line)
                if asof_legacy_m:
                    asof_year = int(asof_legacy_m.group(1))
                    asof_month = int(asof_legacy_m.group(2))
                    continue

                section_m = SECTION_RE.match(line)
                if section_m:
                    current_section = section_m.group(1)
                    continue

                row_m = ROW_RE.match(line)
                if row_m and current_section is not None and asof_year is not None:
                    status, coll_status = SECTION_TO_STATUS[current_section]
                    records.append({
                        "Payment_Name": resolve_payment_name(
                            row_m.group("drawee_name"), row_m.group("check_number")
                        ),
                        "Payment_Status__c": status,
                        "SM_Check_Collection_Date__c": tran_date_to_iso(
                            row_m.group("tran_date"), asof_month, asof_year
                        ),
                        "SM_Check_Collection__c": "TRUE",
                        "SM_Check_Collection_Status__c": coll_status,
                        "Section": current_section,
                        "Drawee_Name": row_m.group("drawee_name").strip(),
                        "Check_Number": row_m.group("check_number"),
                        "Reference_Number": row_m.group("ref_number"),
                        "Amount": row_m.group("amount"),
                        "Reason": row_m.group("reason").strip(),
                    })

    return records


FIELDNAMES = [
    "Payment_Name",
    "Payment_Status__c",
    "SM_Check_Collection_Date__c",
    "SM_Check_Collection__c",
    "SM_Check_Collection_Status__c",
    "Section",
    "Drawee_Name",
    "Check_Number",
    "Reference_Number",
    "Amount",
    "Reason",
]


def write_csv(records, out_path: str):
    with open(out_path, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=FIELDNAMES)
        writer.writeheader()
        for r in records:
            writer.writerow(r)


def r10_report_path(out_path: str) -> str:
    base, ext = os.path.splitext(out_path)
    return f"{base}_R10_ClienteSolicitoDevolucion{ext or '.csv'}"


def write_r10_report(records, out_path: str):
    """CSV aparte para Comercial: solo filas con REASON = R10 (cliente pidió
    la devolución directamente al banco). No se usa para el update a
    Salesforce, es solo para seguimiento comercial."""
    r10_records = [r for r in records if r["Reason"].strip().upper().startswith("R10")]

    fieldnames = [
        "Payment_Name",
        "Drawee_Name",
        "Amount",
        "SM_Check_Collection_Date__c",
        "Section",
        "Reference_Number",
        "Check_Number",
        "Reason",
    ]
    report_path = r10_report_path(out_path)
    with open(report_path, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames, extrasaction="ignore")
        writer.writeheader()
        for r in r10_records:
            writer.writerow(r)

    return report_path, len(r10_records)


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
        print("Uso: python extract_check_collection.py <input.pdf> <output.csv>")
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

    report_path, r10_count = write_r10_report(records, out_path)
    if r10_count:
        print(f"AVISO: {r10_count} registro(s) con REASON R10 (cliente solicitó devolución directo al banco) -> {report_path}")
    else:
        print("Sin registros R10 en este archivo.")


if __name__ == "__main__":
    main()
