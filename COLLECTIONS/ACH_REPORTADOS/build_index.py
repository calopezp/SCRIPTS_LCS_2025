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

Corte de 4 meses / año anterior por archivo NUEVO (instrucción explícita del
usuario, 2026-09-15 -- mismo criterio que ya existía para Returns/Collection
en build_index.py de COLLECTIONS/, ver NEW_FILE_MAX_AGE_DAYS ahí): un archivo
nunca antes visto pero cuyo NOMBRE trae una fecha de más de
NEW_FILE_MAX_AGE_DAYS días, o de un año anterior al actual, NO entra al
delta de hoy (no se aplica solo en Salesforce) -- queda reportado en
ARCHIVOS_VIEJOS_CSV para que el usuario decida aplicarlo manualmente
(./run_transmission_import.sh "<ruta al csv>" apply, el modo de un solo
archivo, que no filtra por fecha). Sí queda indexado en transmission_index.csv
(no se pierde del histórico), solo no se transmite a Salesforce automático.

Todo archivo nuevo examinado en la corrida (con registros, vacío, con error,
o sin fecha reconocible en el nombre) se marca como "visto" en SCANNED_LOG_CSV
para que nunca se vuelva a reportar cada día -- antes, un archivo vacío o sin
fecha parseable no dejaba ningún rastro (no escribía fila en
transmission_raw_log.csv) y por lo tanto se re-escaneaba y reportaba en la
consola en TODAS las corridas futuras, para siempre.

Uso:
    python build_index.py            # actualiza el índice (incremental)
    python build_index.py --rebuild  # borra el índice y reprocesa todo
"""

import argparse
import csv
import importlib.util
from datetime import date
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
INDEX_DIR = SCRIPT_DIR / "index"
INDEX_CSV = INDEX_DIR / "transmission_index.csv"
RAW_LOG_CSV = INDEX_DIR / "transmission_raw_log.csv"
DELTA_CSV = INDEX_DIR / "last_run_delta.csv"
SCANNED_LOG_CSV = INDEX_DIR / "scanned_files_log.csv"
ARCHIVOS_VIEJOS_CSV = INDEX_DIR / "archivos_viejos_pendientes_confirmacion.csv"
NEW_FILE_MAX_AGE_DAYS = 120  # ~4 meses

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


def _already_indexed() -> set:
    """Union de RAW_LOG_CSV (archivos con registros reales ya aplicados) y
    SCANNED_LOG_CSV (archivos ya examinados sin importar el resultado -- vacíos,
    con error, sin fecha reconocible, o viejos) -- cualquiera de los dos cuenta
    como "ya visto", así ningún archivo se re-escanea para siempre."""
    seen = set()
    for log_csv in (RAW_LOG_CSV, SCANNED_LOG_CSV):
        if not log_csv.exists():
            continue
        with log_csv.open(newline="", encoding="utf-8") as f:
            seen |= {row["Source_File"] for row in csv.DictReader(f)}
    return seen


def _mark_scanned(entries, quiet=False):
    """Registra archivos examinados en esta corrida que NO dejaron fila en
    RAW_LOG_CSV (vacíos, con error, o sin fecha reconocible) -- sin esto,
    _already_indexed() nunca los ve como "vistos" y se re-escanean cada día."""
    if not entries:
        return
    write_header = not SCANNED_LOG_CSV.exists() or SCANNED_LOG_CSV.stat().st_size == 0
    with SCANNED_LOG_CSV.open("a", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=["Source_File", "Scanned_Date", "Reason"])
        if write_header:
            writer.writeheader()
        for name, reason in entries:
            writer.writerow({"Source_File": name, "Scanned_Date": date.today().isoformat(), "Reason": reason})


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
        for p in (INDEX_CSV, RAW_LOG_CSV, DELTA_CSV, SCANNED_LOG_CSV, ARCHIVOS_VIEJOS_CSV):
            if p.exists():
                p.unlink()

    _sync_salesforce_files(quiet=quiet)

    seen = _already_indexed()
    files = _find_files()
    new_files = [f for f in files if f.name not in seen]

    if not new_files:
        if not quiet:
            print(f"Nada nuevo que indexar ({len(files)} archivo(s) ya indexados).")
        # No borrar un delta existente: puede seguir pendiente de aplicar
        # en Salesforce por el proceso diario (ver build_index.py de
        # Returns/Collection, mismo criterio).
        return

    write_header = not RAW_LOG_CSV.exists() or RAW_LOG_CSV.stat().st_size == 0
    total_new_rows = 0
    skipped_files = []  # (name, reason) -- 0 registros, error, o sin fecha -- se marcan como vistos igual
    old_files = []  # (name, age_days, row_count) -- vistos + indexados, pero NO entran al delta de hoy
    delta_rows = []
    today = date.today()

    with RAW_LOG_CSV.open("a", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=RAW_FIELDNAMES)
        if write_header:
            writer.writeheader()
        for fp in new_files:
            date_str = extractor.date_from_filename(fp)
            if date_str is None:
                skipped_files.append((fp.name, "no se pudo determinar la fecha del nombre del archivo"))
                continue
            try:
                records = extractor.extract_records(str(fp), transmission_date=date_str)
            except Exception as exc:
                skipped_files.append((fp.name, f"error al leer: {exc}"))
                continue
            if not records:
                skipped_files.append((fp.name, "0 registros (vacío, feriado, o estructura distinta)"))
                continue

            file_date = date.fromisoformat(date_str)
            age_days = (today - file_date).days
            is_old = age_days > NEW_FILE_MAX_AGE_DAYS or file_date.year < today.year

            for r in records:
                r["Source_File"] = fp.name
                writer.writerow(r)
                if not is_old:
                    delta_rows.append(dict(r))
            total_new_rows += len(records)
            if not quiet:
                print(f"  + {fp.name}: {len(records)} registro(s)")

            if is_old:
                old_files.append((fp.name, age_days, len(records)))

    if not quiet:
        print(f"Archivos nuevos procesados: {len(new_files)} -> {total_new_rows} fila(s) agregadas al log crudo.")
        if skipped_files:
            print(f"  {len(skipped_files)} archivo(s) sin datos utilizables:")
            for name, reason in skipped_files:
                print(f"    - {name}: {reason}")

    _mark_scanned(skipped_files, quiet=quiet)
    _write_old_files_report(old_files, quiet=quiet)
    _write_delta(delta_rows, quiet=quiet)
    _rebuild_deduped_index(quiet=quiet)


def _write_old_files_report(old_files, quiet=False):
    """Archivos nuevos (nunca antes indexados) con más de NEW_FILE_MAX_AGE_DAYS
    días de antigüedad (o de un año anterior) según la fecha que trae el
    NOMBRE del archivo. Ya quedaron indexados en RAW_LOG_CSV/INDEX_CSV (no se
    pierden del histórico), pero sus payments NO entraron al delta de hoy --
    se sobreescribe cada corrida (refleja solo lo encontrado en ESTA corrida,
    igual que DELTA_CSV)."""
    if ARCHIVOS_VIEJOS_CSV.exists():
        ARCHIVOS_VIEJOS_CSV.unlink()
    if not old_files:
        return
    with ARCHIVOS_VIEJOS_CSV.open("w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(["Source_File", "Antiguedad_Dias", "Filas"])
        for name, age_days, count in old_files:
            writer.writerow([name, age_days, count])
    if not quiet:
        print(f"  AVISO: {len(old_files)} archivo(s) nuevo(s) pero de MAS DE {NEW_FILE_MAX_AGE_DAYS} DIAS (o de un año anterior)")
        print(f"  -> indexados, pero NO incluidos en el delta de hoy -> {ARCHIVOS_VIEJOS_CSV}")
        for name, age_days, count in old_files:
            print(f"     - {name} ({age_days} dias, {count} fila(s)) -- procesar manual si corresponde: ./run_transmission_import.sh \"<ruta>\" apply")


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
