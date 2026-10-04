"""
Extractor de los archivos "ACH Reportados" (COMPILADO COLLECTIONS/ACH Reportados)
-> lista de (Payment_Name, Amount, fecha de transmisión) para poblar el campo
SM_Transmission_Date_ACH_File__c en SM_Payment__c.

Cada archivo ACH_YYYYMMDD[...].csv es la lista de pagos que se transmitieron
al banco ese día. No trae encabezado (o si trae uno, no coincide con datos
reales y simplemente no matchea ningún patrón). Existen dos estructuras:

    Formato A (PY- en la columna 0):
        PY-xxxxx,ABA,Cuenta,TypeCode,Amount,ACH-ref,PM-ref[,Bool]
        ej: PY-01872783,021502011,755001188,2,79,ACH-6758,00242758,False

    Formato B (PY- en la columna 4, la mayoría de los archivos):
        ABA,Cuenta,C/S,Nombre,PY-xxxxx,Amount[,ACH-ref,PM-ref]
        ej: 021502011,227664523,C,MAGDALENA RODRIGUEZ CO,PY-01860967,99,...

La fecha de transmisión se toma del NOMBRE del archivo (ACH_YYYYMMDD...),
no del contenido -- ahí es donde vive el dato real según el banco.

Archivos con una estructura totalmente distinta (ej. "... - REFUND.csv",
reportes de reembolso con dos columnas PY- por fila) no matchean ninguno de
los dos formatos y quedan excluidos automáticamente (0 registros).

Uso:
    python extract_ach_transmission.py ACH_20260730.csv salida.csv
"""

import csv
import re
import sys
from pathlib import Path

PY_RE = re.compile(r"^PY-\d+$", re.IGNORECASE)
FILENAME_DATE_RE = re.compile(r"ACH_(\d{4})(\d{2})(\d{2})", re.IGNORECASE)

FIELDNAMES = ["Payment_Name", "SM_Transmission_Date_ACH_File__c", "Amount"]


def date_from_filename(path) -> str:
    """'ACH_20260730.csv' / 'ACH_20260729_AJ22jul.csv' -> '2026-07-30'."""
    m = FILENAME_DATE_RE.search(Path(path).name)
    if not m:
        return None
    year, month, day = m.groups()
    return f"{year}-{month}-{day}"


def extract_records(csv_path: str, transmission_date: str = None):
    if transmission_date is None:
        transmission_date = date_from_filename(csv_path)
    if transmission_date is None:
        return []

    records = []
    with open(csv_path, encoding="utf-8", errors="replace", newline="") as f:
        reader = csv.reader(f)
        for row in reader:
            if not row:
                continue
            row = [c.strip().strip('"') for c in row]

            payment_name = None
            amount_raw = None
            if len(row) >= 5 and PY_RE.match(row[0]):
                payment_name = row[0]
                amount_raw = row[4]
            elif len(row) >= 6 and PY_RE.match(row[4]):
                payment_name = row[4]
                amount_raw = row[5]

            if payment_name is None:
                continue

            try:
                amount = f"{float(amount_raw):.2f}"
            except (TypeError, ValueError):
                continue

            records.append({
                "Payment_Name": payment_name.upper(),
                "SM_Transmission_Date_ACH_File__c": transmission_date,
                "Amount": amount,
            })

    return records


def write_csv(records, out_path: str):
    with open(out_path, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=FIELDNAMES)
        writer.writeheader()
        for r in records:
            writer.writerow(r)


def main():
    if len(sys.argv) != 3:
        print("Uso: python extract_ach_transmission.py <input.csv> <output.csv>")
        sys.exit(1)

    in_path, out_path = sys.argv[1], sys.argv[2]

    if date_from_filename(in_path) is None:
        print(f"ERROR: no se pudo determinar la fecha de transmisión desde el nombre '{in_path}'.")
        print("Se espera un nombre tipo ACH_YYYYMMDD....csv. No se genera ningún CSV.")
        sys.exit(1)

    records = extract_records(in_path)

    if not records:
        print(f"ERROR: no se pudo extraer ningún registro de '{in_path}'.")
        print("Puede ser un archivo vacío, un feriado bancario (sin transacciones),")
        print("o una estructura distinta a las dos conocidas (ej. reportes de REFUND).")
        print("Revisa el archivo manualmente. No se genera ningún CSV.")
        sys.exit(1)

    write_csv(records, out_path)
    print(f"Extraídos {len(records)} registros -> {out_path}")


if __name__ == "__main__":
    main()
