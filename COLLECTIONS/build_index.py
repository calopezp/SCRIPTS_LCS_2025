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

Corte de 1 semana por archivo NUEVO (instruccion explicita del usuario,
2026-09-09): el uso diario de este pipeline (run_daily_new_files.sh) NUNCA
debe aplicar solo un archivo que alguien acaba de dejar en OneDrive pero
que en realidad es un reporte VIEJO (ej. un historico que mandan manual).
Se mide por la FECHA QUE TRAE EL NOMBRE DEL ARCHIVO (no por cuando se guardo
en disco -- instruccion explicita del usuario: "basado en el nombre del
archivo, el nombre del archivo tiene la fecha"). Ver parse_date_from_filename()
para los patrones soportados (el formato nuevo "..._MMDDYYYY.pdf" /
"..._MM_DD_YYYY.pdf" y el formato viejo "<Mes> <Dia>[-<Dia2>] [<Año>].pdf").
Si el nombre no trae ninguna fecha reconocible (ej. "ResumenOctNovDec2025.pdf",
"Reporte 1 semanal Febrero.pdf"), se trata como VIEJO por seguridad -- no se
puede confirmar que sea reciente, así que no se aplica solo.

Los PDFs de mas de 7 dias de antiguedad (o sin fecha parseable) SI se
indexan (quedan marcados como "vistos", no se re-escanean para siempre)
pero sus filas NO entran al delta del dia -- quedan reportados en
ARCHIVOS_VIEJOS_CSV para que el usuario decida procesarlos manualmente
(run_import_return.sh "<ruta>" apply / run_import_collection.sh "<ruta>"
apply, el modo de un solo archivo, que no filtra por fecha).

Uso:
    python build_index.py            # actualiza ambos indices (incremental)
    python build_index.py --rebuild  # borra los indices y reprocesa todo
"""

import argparse
import csv
import importlib.util
import re
from datetime import date
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
ARCHIVOS_VIEJOS_CSV = INDEX_DIR / "archivos_viejos_pendientes_confirmacion.csv"
NEW_FILE_MAX_AGE_DAYS = 7

# Año por defecto cuando el nombre trae mes+dia pero no año (la mayoria de
# los archivos viejos) -- coincide con las carpetas fuente ("...\2026"),
# ajustar aqui junto con RETURNS_SOURCE_DIR/COLLECTIONS_SOURCE_DIR cuando
# cambie el año.
DEFAULT_FILENAME_YEAR = 2026

MONTH_NAMES = {
    "jan": 1, "january": 1, "enero": 1,
    "feb": 2, "february": 2, "febrero": 2,
    "mar": 3, "march": 3, "marh": 3, "marzo": 3,
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
_MONTH_PATTERN = "|".join(sorted(MONTH_NAMES, key=len, reverse=True))
# Formato nuevo: "..._MMDDYYYY.pdf" (CheckCollectionDailyReport_09042026.pdf,
# ACHReturnsReport_09012026.pdf).
_RE_MMDDYYYY = re.compile(r"_(\d{2})(\d{2})(\d{4})\.pdf$", re.IGNORECASE)
# Formato nuevo variante: "..._MM_DD_YYYY.pdf" (Check Collection Daily
# Report_09_01_2026.pdf, ACH Returns Report_09_04_2026.pdf).
_RE_MM_DD_YYYY = re.compile(r"_(\d{2})_(\d{2})_(\d{4})\.pdf$", re.IGNORECASE)
# Formato viejo: "<Mes> <Dia>[-<Dia2>|a<Dia2>] [<Año>]" en cualquier parte
# del nombre (ej. "Check Collections April 17 2026.pdf", "ACH Returns Jun
# 12a15 2026.pdf", "Check Collections March 20 Weekly.pdf" -- año opcional).
_RE_MONTH_DAY_YEAR = re.compile(
    rf"({_MONTH_PATTERN})\.?\s+(\d{{1,2}})(?:[-a/]\d{{1,2}})?(?:\s+(\d{{4}}))?",
    re.IGNORECASE,
)


def parse_date_from_filename(name: str):
    """Extrae la fecha del reporte a partir del NOMBRE del archivo (no de su
    contenido ni de su fecha de modificacion en disco). Devuelve un date o
    None si el nombre no trae ninguna fecha reconocible."""
    m = _RE_MMDDYYYY.search(name)
    if m:
        mm, dd, yyyy = m.groups()
        try:
            return date(int(yyyy), int(mm), int(dd))
        except ValueError:
            pass

    m = _RE_MM_DD_YYYY.search(name)
    if m:
        mm, dd, yyyy = m.groups()
        try:
            return date(int(yyyy), int(mm), int(dd))
        except ValueError:
            pass

    m = _RE_MONTH_DAY_YEAR.search(name)
    if m:
        month_name, day, year = m.groups()
        month = MONTH_NAMES[month_name.lower()]
        year = int(year) if year else DEFAULT_FILENAME_YEAR
        try:
            return date(year, month, int(day))
        except ValueError:
            pass

    return None

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

    # Cada PDF solo puede pertenecer a UNO de los dos indices (segun su
    # contenido), nunca a ambos -- asi que "ya procesado" es estar en
    # cualquiera de los dos sets, no en los dos a la vez. Comparar contra
    # returns_seen y collections_seen por separado dejaba a los PDFs de
    # returns atrapados como "pendientes" para siempre (nunca entran a
    # collections_seen), lo que vaciaba el delta en la corrida siguiente
    # aunque el PDF ya estuviera indexado.
    already_seen = returns_seen | collections_seen
    pending = [p for name, p in all_pdfs.items() if name not in already_seen]

    if not pending:
        if not quiet:
            print(f"  Nada nuevo que indexar ({len(all_pdfs)} PDF(s) ya indexados).")
        # No tocar los deltas existentes: representan la corrida anterior y
        # pueden seguir pendientes de que run_import_return.sh/
        # run_import_collection.sh los aplique y genere el reporte R10 de
        # Comercial. Una corrida sin PDFs nuevos (ej. buscar_payment.py) no
        # debe borrar el trabajo pendiente del proceso diario de collections.
        return

    returns_rows = []
    collections_rows = []
    unclassified = []
    old_files = []  # (filename, type, age_days_or_None, row_count) -- para ARCHIVOS_VIEJOS_CSV

    today = date.today()

    for pdf_path in sorted(pending, key=lambda p: p.name):
        report_type = detect_report_type(pdf_path)
        filename_date = parse_date_from_filename(pdf_path.name)
        # Sin fecha reconocible en el nombre: se trata como VIEJO por
        # seguridad (age_days=None) -- no se puede confirmar que sea
        # reciente, asi que no entra al delta de hoy.
        age_days = (today - filename_date).days if filename_date else None
        if report_type == "returns" and pdf_path.name not in returns_seen:
            try:
                records = returns_extractor.extract_records(str(pdf_path))
            except Exception as exc:
                print(f"  ERROR procesando {pdf_path.name} (returns): {exc}")
                continue
            returns_rows.append((pdf_path.name, records, age_days))
            if age_days is None or age_days > NEW_FILE_MAX_AGE_DAYS:
                old_files.append((pdf_path.name, "returns", age_days, len(records)))
        elif report_type == "collections" and pdf_path.name not in collections_seen:
            try:
                records = collections_extractor.extract_records(str(pdf_path))
            except Exception as exc:
                print(f"  ERROR procesando {pdf_path.name} (collections): {exc}")
                continue
            collections_rows.append((pdf_path.name, records, age_days))
            if age_days is None or age_days > NEW_FILE_MAX_AGE_DAYS:
                old_files.append((pdf_path.name, "collections", age_days, len(records)))
        elif report_type is None:
            unclassified.append(pdf_path.name)

    # _append_records indexa TODO (recientes + viejos) -- un archivo viejo
    # tambien debe quedar marcado como "visto" para no reprocesarlo cada dia,
    # solo que sus filas no entran al delta de hoy (ver mas abajo).
    returns_all = [(name, recs) for name, recs, _age in returns_rows]
    collections_all = [(name, recs) for name, recs, _age in collections_rows]
    returns_recent = [(name, recs) for name, recs, age in returns_rows if age is not None and age <= NEW_FILE_MAX_AGE_DAYS]
    collections_recent = [(name, recs) for name, recs, age in collections_rows if age is not None and age <= NEW_FILE_MAX_AGE_DAYS]

    if not quiet:
        print("== ACH Returns ==")
    _append_records(RETURNS_INDEX_CSV, returns_extractor.FIELDNAMES, returns_all, quiet)
    total_returns = sum(len(r) for _, r in returns_all)
    print(f"  [{RETURNS_INDEX_CSV.name}] {len(returns_all)} PDF(s) nuevo(s) -> {total_returns} registro(s) agregados.")
    _write_delta(RETURNS_DELTA_CSV, returns_extractor.FIELDNAMES, returns_recent, quiet)

    if not quiet:
        print("== Check Collection ==")
    _append_records(COLLECTIONS_INDEX_CSV, collections_extractor.FIELDNAMES, collections_all, quiet)
    total_collections = sum(len(r) for _, r in collections_all)
    print(f"  [{COLLECTIONS_INDEX_CSV.name}] {len(collections_all)} PDF(s) nuevo(s) -> {total_collections} registro(s) agregados.")
    _write_delta(COLLECTIONS_DELTA_CSV, collections_extractor.FIELDNAMES, collections_recent, quiet)

    _write_old_files_report(old_files, quiet)

    if unclassified:
        print(f"  AVISO: {len(unclassified)} PDF(s) sin clasificar (no matchean ningun formato conocido):")
        for name in unclassified:
            print(f"    - {name}")


def _write_old_files_report(old_files, quiet):
    """Archivos nuevos (nunca antes indexados) cuya fecha (segun el NOMBRE
    del archivo) tiene mas de NEW_FILE_MAX_AGE_DAYS dias, o cuyo nombre no
    trae ninguna fecha reconocible (Antiguedad_Dias queda vacio en ese
    caso -- se trata como viejo por seguridad). Ya quedaron indexados
    (arriba), pero sus payments NO entraron al delta de hoy. Se
    sobreescribe cada corrida (refleja solo lo encontrado en ESTA corrida,
    igual que los *_last_run_delta.csv)."""
    if ARCHIVOS_VIEJOS_CSV.exists():
        ARCHIVOS_VIEJOS_CSV.unlink()
    if not old_files:
        return
    with ARCHIVOS_VIEJOS_CSV.open("w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(["Source_File", "Tipo", "Antiguedad_Dias", "Filas"])
        for name, tipo, age_days, count in old_files:
            writer.writerow([name, tipo, age_days if age_days is not None else "", count])
    if not quiet:
        print(f"  AVISO: {len(old_files)} archivo(s) nuevo(s) pero de MAS DE {NEW_FILE_MAX_AGE_DAYS} DIAS (o sin fecha reconocible en el nombre)")
        print(f"  -> indexados, pero NO incluidos en el delta de hoy -> {ARCHIVOS_VIEJOS_CSV}")
        for name, tipo, age_days, count in old_files:
            age_label = f"{age_days} dias" if age_days is not None else "fecha no reconocida en el nombre"
            print(f"     - {name} ({tipo}, {age_label}, {count} fila(s)) -- procesar manual si corresponde")


def _write_delta(delta_csv: Path, fieldnames, rows, quiet):
    """CSV con SOLO los payments de los PDFs procesados en ESTA corrida --
    esto es lo que run_import_return.sh / run_import_collection.sh deployan
    y aplican en Salesforce cada dia, NO el indice historico completo."""
    if not rows:
        # Sin PDFs nuevos de este tipo en esta corrida: no tocar un delta
        # existente, puede seguir pendiente de aplicar (ver update_indexes).
        return

    if delta_csv.exists():
        delta_csv.unlink()

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
