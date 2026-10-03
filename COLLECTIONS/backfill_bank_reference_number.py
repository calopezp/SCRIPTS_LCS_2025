"""
Backfill puntual (NO recurrente) de SM_Bank_Reference_Number__c para los
PDFs de Returns/Collections de los ultimos N meses (regla de los 6 meses,
CLAUDE.md seccion 1 -- este backfill usa 3 por decision explicita del
usuario 2026-10-03).

Reutiliza la MISMA infraestructura de build_index.py (deteccion de tipo de
reporte por contenido, parseo de fecha por nombre de archivo, los 2
extractores) para no duplicar esa logica -- pero esto NO toca
returns_index.csv/collections_index.csv, es un barrido aparte que solo
junta tags RTN:/COL: por Payment_Name y los deja en un CSV listo para
aplicar con -ApplyBankReferenceBackfill.apex (ese apex SOLO actualiza
SM_Bank_Reference_Number__c -- Payment_Status__c y todo lo demas del
Payment queda intacto, confirmado explicitamente por el usuario).

PDFs sin fecha reconocible en el nombre se EXCLUYEN (no se puede confirmar
que esten dentro de la ventana de 3 meses -- mismo criterio conservador
que build_index.py usa para "archivo viejo").

Uso:
    python backfill_bank_reference_number.py           # 3 meses (default)
    python backfill_bank_reference_number.py --months 2
"""

import argparse
import csv
from datetime import date, timedelta
from pathlib import Path

import build_index

SCRIPT_DIR = Path(__file__).resolve().parent
OUT_CSV = SCRIPT_DIR / "index" / "bank_reference_backfill.csv"
MAX_REF_LENGTH = 120

DRAWEE_NAME_IS_PY_RE = build_index.collections_extractor.DRAWEE_NAME_IS_PY_RE


def tags_from_pdf(pdf_path: Path):
    """Devuelve lista de (Payment_Name, tag) para un PDF -- segun su tipo
    detectado por contenido (returns -> RTN:, collections -> COL:, salvo la
    excepcion documentada de Drawee_Name ya siendo un PY-xxxxx)."""
    report_type = build_index.detect_report_type(pdf_path)
    if report_type == "returns":
        records = build_index.returns_extractor.extract_records(str(pdf_path))
        return [
            (r["Payment_Name"], f"RTN:{r['Orig_Trace']}")
            for r in records if r.get("Orig_Trace")
        ]
    if report_type == "collections":
        records = build_index.collections_extractor.extract_records(str(pdf_path))
        out = []
        for r in records:
            drawee = (r.get("Drawee_Name") or "").strip()
            check_number = r.get("Check_Number")
            if check_number and not DRAWEE_NAME_IS_PY_RE.match(drawee):
                out.append((r["Payment_Name"], f"COL:{check_number}"))
        return out
    return []


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--months", type=int, default=3)
    args = parser.parse_args()

    cutoff = date.today() - timedelta(days=args.months * 30)
    print(f"Ventana: desde {cutoff.isoformat()} (ultimos {args.months} meses) -- PDFs sin fecha reconocible se excluyen")

    candidate_pdfs = []
    for source_dir in (build_index.RETURNS_SOURCE_DIR, build_index.COLLECTIONS_SOURCE_DIR):
        for pdf_path in build_index._find_pdfs(source_dir):
            file_date = build_index.parse_date_from_filename(pdf_path.name)
            if file_date and file_date >= cutoff:
                candidate_pdfs.append((file_date, pdf_path))

    # Dedup por nombre de archivo (ACH Returns y Check Collection apuntan a
    # veces al mismo PDF archivado por error en la carpeta equivocada, ver
    # build_index.py) y orden cronologico -- el orden de los tags refleja
    # el orden real en que el banco reporto cada evento.
    seen_files = set()
    ordered_pdfs = []
    for file_date, pdf_path in sorted(candidate_pdfs, key=lambda x: x[0]):
        if pdf_path.name in seen_files:
            continue
        seen_files.add(pdf_path.name)
        ordered_pdfs.append(pdf_path)

    print(f"PDFs en la ventana: {len(ordered_pdfs)}")

    tags_by_payment = {}
    errors = []
    for i, pdf_path in enumerate(ordered_pdfs, 1):
        try:
            for payment_name, tag in tags_from_pdf(pdf_path):
                existing = tags_by_payment.setdefault(payment_name, [])
                if tag not in existing:
                    existing.append(tag)
        except Exception as exc:
            errors.append((pdf_path.name, str(exc)))
        if i % 20 == 0:
            print(f"  ... {i}/{len(ordered_pdfs)} procesados")

    if errors:
        print(f"\n{len(errors)} PDF(s) con error al extraer (se omiten, no tumban el batch):")
        for name, msg in errors:
            print(f"  - {name}: {msg}")

    OUT_CSV.parent.mkdir(exist_ok=True)
    with OUT_CSV.open("w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(["Payment_Name", "SM_Bank_Reference_Number__c"])
        for payment_name in sorted(tags_by_payment):
            combined = " | ".join(tags_by_payment[payment_name])
            if len(combined) > MAX_REF_LENGTH:
                combined = combined[-MAX_REF_LENGTH:]
            writer.writerow([payment_name, combined])

    print(f"\nPayments con al menos 1 tag encontrado: {len(tags_by_payment)} -> {OUT_CSV}")
    print("Siguiente paso: copiar a force-app/main/default/staticresources/BankReferenceBackfill.csv,")
    print("deployar el Static Resource, y correr -ApplyBankReferenceBackfill.apex (dry-run primero).")


if __name__ == "__main__":
    main()
