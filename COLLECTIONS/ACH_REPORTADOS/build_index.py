"""
Construye/actualiza un índice histórico de los archivos de transmisión ACH,
combinando DOS fuentes, con un registro por Payment_Name -> fecha de
transmisión (SM_Transmission_Date_ACH_File__c) + monto:

  1) La carpeta "ACH Reportados" en OneDrive:
     C:\\OneDrive - LCS\\COMPILADO COLLECTIONS\\ACH Reportados
  2) Archivos "ACH_*.csv" subidos directamente como Files en Salesforce
     (ContentVersion) -- un repositorio paralelo descubierto porque 184
     payments del reporte "Transmission Date ACH" no aparecian en ningun
     archivo de OneDrive pero SI en estos Files. Se sincronizan localmente
     a sf_files/ (ver fetch_salesforce_files.py) antes de indexar.

Un mismo payment puede aparecer en más de un archivo (ej. si se retransmitió
tras un return, o en ambas fuentes); en ese caso se conserva la fecha MÁS
RECIENTE -- así el índice final queda con un solo registro por Payment_Name,
listo para el update en Salesforce.

Archivos excluidos explícitamente (estructura distinta, no son transmisión
de débito estándar): cualquier nombre que contenga "REFUND".

Es incremental: cada archivo ya indexado (por nombre) se salta en corridas
posteriores. Los Files de Salesforce tambien se descargan de forma
incremental (solo los ContentVersion nuevos).

Uso:
    python build_index.py            # actualiza el índice (incremental)
    python build_index.py --rebuild  # borra el índice y reprocesa todo
"""

import argparse
import csv
import importlib.util
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
INDEX_DIR = SCRIPT_DIR / "index"
INDEX_CSV = INDEX_DIR / "transmission_index.csv"
RAW_LOG_CSV = INDEX_DIR / "transmission_raw_log.csv"
DELTA_CSV = INDEX_DIR / "last_run_delta.csv"

SOURCE_DIR = Path(r"C:\OneDrive - LCS\COMPILADO COLLECTIONS\ACH Reportados")
SF_FILES_DIR = SCRIPT_DIR / "sf_files"
EXCLUDE_NAME_CONTAINS = ("REFUND",)

FIELDNAMES = ["Payment_Name", "SM_Transmission_Date_ACH_File__c", "Amount"]
RAW_FIELDNAMES = FIELDNAMES + ["Source_File"]


def _load_module(name: str, path: Path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


extractor = _load_module("extract_ach_transmission", SCRIPT_DIR / "extract_ach_transmission.py")
sf_fetcher = _load_module("fetch_salesforce_files", SCRIPT_DIR / "fetch_salesforce_files.py")


def _already_indexed(log_csv: Path) -> set:
    if not log_csv.exists():
        return set()
    with log_csv.open(newline="", encoding="utf-8") as f:
        return {row["Source_File"] for row in csv.DictReader(f)}


def _sync_salesforce_files(quiet=False):
    try:
        new_files = sf_fetcher.sync_files(quiet=quiet)
        if not quiet and not new_files:
            print("Salesforce Files: nada nuevo que descargar.")
        return new_files
    except Exception as exc:
        print(f"AVISO: no se pudo sincronizar Salesforce Files (se sigue solo con OneDrive): {exc}")
        return []


def _find_files():
    files = []
    if SOURCE_DIR.exists():
        files += sorted(SOURCE_DIR.glob("ACH_*.csv"))
    else:
        print(f"AVISO: no existe la carpeta {SOURCE_DIR}")
    if SF_FILES_DIR.exists():
        files += sorted(SF_FILES_DIR.glob("ACH_*.csv"))
    return [f for f in files if not any(x.upper() in f.name.upper() for x in EXCLUDE_NAME_CONTAINS)]


def update_index(rebuild=False, quiet=False):
    INDEX_DIR.mkdir(exist_ok=True)
    if rebuild:
        for p in (INDEX_CSV, RAW_LOG_CSV, DELTA_CSV):
            if p.exists():
                p.unlink()

    _sync_salesforce_files(quiet=quiet)

    seen = _already_indexed(RAW_LOG_CSV)
    files = _find_files()
    new_files = [f for f in files if f.name not in seen]

    if not new_files:
        if not quiet:
            print(f"Nada nuevo que indexar ({len(files)} archivo(s) ya indexados).")
        if DELTA_CSV.exists():
            DELTA_CSV.unlink()
        return

    write_header = not RAW_LOG_CSV.exists() or RAW_LOG_CSV.stat().st_size == 0
    total_new_rows = 0
    skipped_files = []
    delta_rows = []

    with RAW_LOG_CSV.open("a", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=RAW_FIELDNAMES)
        if write_header:
            writer.writeheader()
        for fp in new_files:
            date = extractor.date_from_filename(fp)
            if date is None:
                skipped_files.append((fp.name, "no se pudo determinar la fecha del nombre del archivo"))
                continue
            try:
                records = extractor.extract_records(str(fp), transmission_date=date)
            except Exception as exc:
                skipped_files.append((fp.name, f"error al leer: {exc}"))
                continue
            if not records:
                skipped_files.append((fp.name, "0 registros (vacío, feriado, o estructura distinta)"))
                continue
            for r in records:
                r["Source_File"] = fp.name
                writer.writerow(r)
                delta_rows.append(dict(r))
            total_new_rows += len(records)
            if not quiet:
                print(f"  + {fp.name}: {len(records)} registro(s)")

    if not quiet:
        print(f"Archivos nuevos procesados: {len(new_files)} -> {total_new_rows} fila(s) agregadas al log crudo.")
        if skipped_files:
            print(f"  {len(skipped_files)} archivo(s) sin datos utilizables:")
            for name, reason in skipped_files:
                print(f"    - {name}: {reason}")

    _write_delta(delta_rows, quiet=quiet)
    _rebuild_deduped_index(quiet=quiet)


def _write_delta(delta_rows, quiet=False):
    """CSV con SOLO lo procesado en ESTA corrida (deduplicado por si un mismo
    payment aparece en más de un archivo nuevo el mismo día) -- esto es lo
    que se debe deployar y aplicar en Salesforce cada día, NO el índice
    completo (que ya tiene miles de payments ya aplicados)."""
    best = {}
    for row in delta_rows:
        name = row["Payment_Name"]
        current = best.get(name)
        if current is None or row["SM_Transmission_Date_ACH_File__c"] > current["SM_Transmission_Date_ACH_File__c"]:
            best[name] = row

    with DELTA_CSV.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=FIELDNAMES, extrasaction="ignore")
        writer.writeheader()
        for name in sorted(best):
            writer.writerow(best[name])

    if not quiet:
        print(f"Delta de esta corrida (para aplicar hoy): {len(best)} payment(s) -> {DELTA_CSV}")


def _rebuild_deduped_index(quiet=False):
    """Colapsa transmission_raw_log.csv a un registro por Payment_Name,
    quedándose con la fecha de transmisión MÁS RECIENTE."""
    if not RAW_LOG_CSV.exists():
        return

    best = {}
    with RAW_LOG_CSV.open(newline="", encoding="utf-8") as f:
        for row in csv.DictReader(f):
            name = row["Payment_Name"]
            date = row["SM_Transmission_Date_ACH_File__c"]
            current = best.get(name)
            if current is None or date > current["SM_Transmission_Date_ACH_File__c"]:
                best[name] = row

    with INDEX_CSV.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=RAW_FIELDNAMES)
        writer.writeheader()
        for name in sorted(best):
            writer.writerow(best[name])

    if not quiet:
        print(f"Índice final (deduplicado, fecha más reciente por payment): {len(best)} payment(s) -> {INDEX_CSV}")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--rebuild", action="store_true", help="Borra el índice y reprocesa todos los archivos desde cero.")
    args = parser.parse_args()
    update_index(rebuild=args.rebuild, quiet=False)


if __name__ == "__main__":
    main()
