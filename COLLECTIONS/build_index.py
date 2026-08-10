"""
Construye/actualiza un indice historico de todos los PDFs de ACH Returns
y Check Collection archivados en OneDrive, para que buscar_payment.py
pueda encontrar un payment sin importar el mes en que fue reportado.

Carpetas fuente (ajustar aqui si cambia la ruta de OneDrive):
    ACH Returns:      C:\\OneDrive - LCS\\COMPILADO COLLECTIONS\\ACH Returns\\2026
    Check Collection: C:\\OneDrive - LCS\\COMPILADO COLLECTIONS\\Check Collection\\2026

El tipo de reporte de cada PDF se detecta por su CONTENIDO (no por la
carpeta en la que esta guardado): se encontraron PDFs archivados en la
carpeta equivocada (ej. "Check Collections Jun 18 2026.pdf" contiene en
realidad un reporte de ACH Returns), asi que ambas carpetas se escanean
juntas y cada PDF se enruta al indice que le corresponde segun su texto.

Es incremental: cada PDF ya indexado (por nombre de archivo) se salta en
corridas posteriores, asi que solo se procesan los PDFs nuevos del dia.
buscar_payment.py llama esto automaticamente antes de cada busqueda.

Uso:
    python build_index.py            # actualiza ambos indices (incremental)
    python build_index.py --rebuild  # borra los indices y reprocesa todo
"""

import argparse
import csv
import importlib.util
from pathlib import Path

import pdfplumber

SCRIPT_DIR = Path(__file__).resolve().parent
INDEX_DIR = SCRIPT_DIR / "index"

RETURNS_SOURCE_DIR = Path(r"C:\OneDrive - LCS\COMPILADO COLLECTIONS\ACH Returns\2026")
COLLECTIONS_SOURCE_DIR = Path(r"C:\OneDrive - LCS\COMPILADO COLLECTIONS\Check Collection\2026")

RETURNS_INDEX_CSV = INDEX_DIR / "returns_index.csv"
COLLECTIONS_INDEX_CSV = INDEX_DIR / "collections_index.csv"
RETURNS_DELTA_CSV = INDEX_DIR / "returns_last_run_delta.csv"
COLLECTIONS_DELTA_CSV = INDEX_DIR / "collections_last_run_delta.csv"

# Marcadores de texto para detectar el tipo real de reporte, sin importar
# en que carpeta este guardado el PDF.
RETURNS_MARKER = "ACH RETURNS/NOTIFICATION OF CHANGE"
COLLECTIONS_MARKERS = ("COLLECTION SERVICES", "CHECK COLLECTION DAILY", "CHECK COLLECTION WEEKLY")


def _load_module(name: str, path: Path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


returns_extractor = _load_module("extract_ach_returns", SCRIPT_DIR / "RETURNS" / "extract_ach_returns.py")
collections_extractor = _load_module("extract_check_collection", SCRIPT_DIR / "COLLECTIONS" / "extract_check_collection.py")


def detect_report_type(pdf_path: Path):
    """Determina si un PDF es 'returns' o 'collections' leyendo su contenido
    (primeras 2 paginas), sin confiar en la carpeta donde este guardado."""
    try:
        with pdfplumber.open(pdf_path) as pdf:
            text = "\n".join((p.extract_text() or "") for p in pdf.pages[:2]).upper()
    except Exception:
        return None
    if RETURNS_MARKER in text:
        return "returns"
    if any(marker in text for marker in COLLECTIONS_MARKERS):
        return "collections"
    return None


def _already_indexed(index_csv: Path) -> set:
    if not index_csv.exists():
        return set()
    with index_csv.open(newline="", encoding="utf-8") as f:
        return {row["Source_File"] for row in csv.DictReader(f)}


def _find_pdfs(source_dir: Path):
    if not source_dir.exists():
        print(f"  AVISO: no existe la carpeta {source_dir}")
        return []
    return sorted(source_dir.rglob("*.pdf"))


def _append_records(index_csv: Path, fieldnames, rows, quiet):
    if not rows:
        return
    write_header = not index_csv.exists() or index_csv.stat().st_size == 0
    with index_csv.open("a", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames + ["Source_File"])
        if write_header:
            writer.writeheader()
        for source_name, records in rows:
            for r in records:
                r["Source_File"] = source_name
                writer.writerow(r)
            if not quiet:
                print(f"  + {source_name}: {len(records)} registro(s)")


def update_indexes(rebuild=False, quiet=False):
    INDEX_DIR.mkdir(exist_ok=True)
    if rebuild:
        for csv_path in (RETURNS_INDEX_CSV, COLLECTIONS_INDEX_CSV, RETURNS_DELTA_CSV, COLLECTIONS_DELTA_CSV):
            if csv_path.exists():
                csv_path.unlink()

    returns_seen = _already_indexed(RETURNS_INDEX_CSV)
    collections_seen = _already_indexed(COLLECTIONS_INDEX_CSV)

    # Union de ambas carpetas: un PDF puede estar guardado en la carpeta
    # equivocada, asi que no asumimos su tipo por donde vive.
    all_pdfs = {}
    for p in _find_pdfs(RETURNS_SOURCE_DIR) + _find_pdfs(COLLECTIONS_SOURCE_DIR):
        all_pdfs[p.name] = p

    pending = [
        p for name, p in all_pdfs.items()
        if name not in returns_seen or name not in collections_seen
    ]
    # Un PDF ya indexado en AMBOS (o en el que le corresponde) no hace falta
    # volver a abrirlo; solo reprocesamos los que faltan en su indice.
    pending = [p for p in pending if not (p.name in returns_seen and p.name in collections_seen)]

    if not pending:
        if not quiet:
            print(f"  Nada nuevo que indexar ({len(all_pdfs)} PDF(s) ya indexados).")
        for delta_csv in (RETURNS_DELTA_CSV, COLLECTIONS_DELTA_CSV):
            if delta_csv.exists():
                delta_csv.unlink()
        return

    returns_rows = []
    collections_rows = []
    unclassified = []

    for pdf_path in sorted(pending, key=lambda p: p.name):
        report_type = detect_report_type(pdf_path)
        if report_type == "returns" and pdf_path.name not in returns_seen:
            try:
                records = returns_extractor.extract_records(str(pdf_path))
            except Exception as exc:
                print(f"  ERROR procesando {pdf_path.name} (returns): {exc}")
                continue
            returns_rows.append((pdf_path.name, records))
        elif report_type == "collections" and pdf_path.name not in collections_seen:
            try:
                records = collections_extractor.extract_records(str(pdf_path))
            except Exception as exc:
                print(f"  ERROR procesando {pdf_path.name} (collections): {exc}")
                continue
            collections_rows.append((pdf_path.name, records))
        elif report_type is None:
            unclassified.append(pdf_path.name)

    if not quiet:
        print("== ACH Returns ==")
    _append_records(RETURNS_INDEX_CSV, returns_extractor.FIELDNAMES, returns_rows, quiet)
    total_returns = sum(len(r) for _, r in returns_rows)
    print(f"  [{RETURNS_INDEX_CSV.name}] {len(returns_rows)} PDF(s) nuevo(s) -> {total_returns} registro(s) agregados.")
    _write_delta(RETURNS_DELTA_CSV, returns_extractor.FIELDNAMES, returns_rows, quiet)

    if not quiet:
        print("== Check Collection ==")
    _append_records(COLLECTIONS_INDEX_CSV, collections_extractor.FIELDNAMES, collections_rows, quiet)
    total_collections = sum(len(r) for _, r in collections_rows)
    print(f"  [{COLLECTIONS_INDEX_CSV.name}] {len(collections_rows)} PDF(s) nuevo(s) -> {total_collections} registro(s) agregados.")
    _write_delta(COLLECTIONS_DELTA_CSV, collections_extractor.FIELDNAMES, collections_rows, quiet)

    if unclassified:
        print(f"  AVISO: {len(unclassified)} PDF(s) sin clasificar (no matchean ningun formato conocido):")
        for name in unclassified:
            print(f"    - {name}")


def _write_delta(delta_csv: Path, fieldnames, rows, quiet):
    """CSV con SOLO los payments de los PDFs procesados en ESTA corrida --
    esto es lo que run_import_return.sh / run_import_collection.sh deployan
    y aplican en Salesforce cada dia, NO el indice historico completo."""
    if delta_csv.exists():
        delta_csv.unlink()
    if not rows:
        return

    # Deduplicar por Payment_Name (si el mismo payment aparece en mas de un
    # PDF nuevo de esta corrida, se queda con la ultima ocurrencia).
    best = {}
    for _source_name, records in rows:
        for r in records:
            best[r["Payment_Name"]] = r

    with delta_csv.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames, extrasaction="ignore")
        writer.writeheader()
        for name in sorted(best):
            writer.writerow(best[name])

    if not quiet:
        print(f"  Delta de esta corrida (para aplicar hoy): {len(best)} payment(s) -> {delta_csv}")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--rebuild", action="store_true", help="Borra los indices y reprocesa todos los PDFs desde cero.")
    args = parser.parse_args()
    update_indexes(rebuild=args.rebuild, quiet=False)


if __name__ == "__main__":
    main()
