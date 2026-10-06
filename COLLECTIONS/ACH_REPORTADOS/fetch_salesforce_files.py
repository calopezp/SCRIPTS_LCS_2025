"""
Descarga los archivos "ACH_*.csv" subidos directamente como Files en
Salesforce (ContentVersion) -- un repositorio PARALELO al de OneDrive
"ACH Reportados", con nombres tipo "ACH_7/29/2026.csv" o "ACH_20260629.csv".

Se encontraron payments (ej. PY-01828880) que nunca aparecieron en ningun
archivo de OneDrive pero SI existen en estos Files de Salesforce -- este
script los descarga, normaliza el nombre para que
extract_ach_transmission.date_from_filename() los reconozca, y los guarda
localmente en sf_files/ para poder indexarlos igual que los de OneDrive.

Desde SF_PRIMARY_FROM (2026-10-01) el proceso nuevo de transmision
(scripts/apex/ACH_TRANSMISION/) deja los CSV SOLO en Salesforce -- ya no en
OneDrive. Para que quien revise a mano siga encontrandolos en OneDrive, cada
corrida copia esos archivos a "ACH Reportados\\Desde Salesforce\\" (ver
mirror_to_onedrive). Esa subcarpeta es solo de consulta: build_index.py no
la indexa (lee solo el primer nivel de "ACH Reportados").

Requiere sf CLI autenticado (usa el access token via SF_TEMP_SHOW_SECRETS)
con alias MONEE (o el que diga la variable de entorno SF_ORG_ALIAS).

Uso:
    python fetch_salesforce_files.py
"""

import csv
import importlib.util
import json
import os
import re
import shutil
import subprocess
import sys
import urllib.request
from pathlib import Path

SF_BIN = shutil.which("sf") or "sf"

SCRIPT_DIR = Path(__file__).resolve().parent
DOWNLOAD_DIR = SCRIPT_DIR / "sf_files"
ORG_ALIAS = os.environ.get("SF_ORG_ALIAS", "MONEE")
API_VERSION = "v60.0"
SF_PRIMARY_FROM = "2026-10-01"  # mismo valor que build_index.SF_PRIMARY_FROM
MIRROR_SUBFOLDER = "Desde Salesforce"

TITLE_DATE_RE_SLASH = re.compile(r"ACH_(\d{1,2})/(\d{1,2})/(\d{4})", re.IGNORECASE)
TITLE_DATE_RE_COMPACT = re.compile(r"ACH_(\d{4})(\d{2})(\d{2})", re.IGNORECASE)


def get_org_conn():
    import os
    result = subprocess.run(
        [SF_BIN, "org", "display", "-o", ORG_ALIAS, "--json"],
        capture_output=True, text=True,
        env={**os.environ, "SF_TEMP_SHOW_SECRETS": "true"},
    )
    data = json.loads(result.stdout)
    r = data["result"]
    return r["instanceUrl"], r["accessToken"]


def soql(instance_url, token, query):
    url = f"{instance_url}/services/data/{API_VERSION}/query/?q={urllib.parse.quote(query)}"
    records = []
    while url:
        req = urllib.request.Request(url, headers={"Authorization": f"Bearer {token}"})
        with urllib.request.urlopen(req) as resp:
            data = json.loads(resp.read())
        records.extend(data["records"])
        next_url = data.get("nextRecordsUrl")
        url = f"{instance_url}{next_url}" if next_url else None
    return records


def download_version_data(instance_url, token, content_version_id, dest_path: Path):
    url = f"{instance_url}/services/data/{API_VERSION}/sobjects/ContentVersion/{content_version_id}/VersionData"
    req = urllib.request.Request(url, headers={"Authorization": f"Bearer {token}"})
    with urllib.request.urlopen(req) as resp:
        dest_path.write_bytes(resp.read())


def date_from_title(title: str):
    m = TITLE_DATE_RE_SLASH.search(title)
    if m:
        month, day, year = m.groups()
        return f"{year}-{int(month):02d}-{int(day):02d}"
    m = TITLE_DATE_RE_COMPACT.search(title)
    if m:
        year, month, day = m.groups()
        return f"{year}-{month}-{day}"
    return None


SUFFIX_RE = re.compile(r"ACH_(?:\d{1,2}/\d{1,2}/\d{4}|\d{8})_([A-Za-z0-9]+)\.csv$", re.IGNORECASE)


def suffix_from_title(title: str):
    """'ACH_10/1/2026_LN.csv' -> 'LN'; 'ACH_9/29/2026.csv' -> None."""
    m = SUFFIX_RE.search(title)
    return m.group(1).upper() if m else None


def sync_files(quiet=False):
    """Descarga los ContentVersion 'ACH%' nuevos que aun no esten localmente
    en sf_files/. Devuelve la lista de rutas (Path) de los archivos
    NUEVOS descargados en esta corrida (no incluye los ya presentes)."""
    import urllib.parse

    instance_url, token = get_org_conn()
    if not quiet:
        print(f"Conectado a {instance_url}")

    query = "SELECT Id, Title, ContentSize, CreatedDate FROM ContentVersion WHERE Title LIKE 'ACH%' AND IsLatest = true ORDER BY CreatedDate"
    records = soql(instance_url, token, query)
    if not quiet:
        print(f"Total ContentVersion 'ACH%' en Salesforce Files: {len(records)}")

    DOWNLOAD_DIR.mkdir(exist_ok=True)

    manifest = []
    skipped = []
    new_paths = []
    for rec in records:
        title = rec["Title"]
        cv_id = rec["Id"]
        date = date_from_title(title)
        if date is None:
            skipped.append((title, cv_id, "no se pudo determinar fecha del titulo"))
            continue
        date_compact = date.replace("-", "")
        # Ya descargado antes (con o sin sufijo en el nombre local) -- no
        # renombrar: build_index.py reconoce lo ya indexado por nombre.
        existentes = list(DOWNLOAD_DIR.glob(f"ACH_*_sf_{cv_id}.csv"))
        if existentes:
            manifest.append((title, cv_id, date, existentes[0].name, "ya descargado"))
            continue
        # Nombre local normalizado: ACH_<YYYYMMDD>[_<SUFIJO>]_sf_<ContentVersionId>.csv
        # (el sufijo _sf_<id> preserva unicidad -- puede haber varios
        # archivos para la misma fecha, como vimos con duplicados). El
        # <SUFIJO> del titulo (LN/CR/CE/REFUNDED, proceso nuevo desde
        # 2026-10-01) se conserva para que build_index.py excluya los
        # archivos de REFUNDED igual que los de OneDrive.
        sufijo = suffix_from_title(title)
        local_name = f"ACH_{date_compact}{'_' + sufijo if sufijo else ''}_sf_{cv_id}.csv"
        dest = DOWNLOAD_DIR / local_name
        try:
            download_version_data(instance_url, token, cv_id, dest)
        except Exception as exc:
            skipped.append((title, cv_id, f"error al descargar: {exc}"))
            continue
        manifest.append((title, cv_id, date, local_name, "descargado"))
        new_paths.append(dest)
        if not quiet:
            print(f"  + {title} ({cv_id}) -> {local_name}")

    if not quiet:
        print(f"Nuevos descargados: {len(new_paths)} (total disponibles localmente: {len(manifest)})")
        if skipped:
            print(f"Omitidos: {len(skipped)}")
            for title, cv_id, reason in skipped:
                print(f"  - {title} ({cv_id}): {reason}")

    with (DOWNLOAD_DIR / "_manifest.csv").open("w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(["Title", "ContentVersionId", "Date", "LocalFile", "Status"])
        w.writerows(manifest)

    mirror_to_onedrive(manifest, quiet=quiet)

    return new_paths


def mirror_to_onedrive(manifest, quiet=False):
    """Copia a OneDrive "ACH Reportados\\Desde Salesforce\\" los Files con fecha
    >= SF_PRIMARY_FROM que todavia no esten ahi, con el nombre legible
    ACH_<YYYYMMDD>[_<SUFIJO>].csv (si ya existe uno distinto con ese nombre,
    se agrega _<ContentVersionId>). Nunca falla la corrida: si OneDrive no
    esta disponible solo avisa."""
    try:
        spec = importlib.util.spec_from_file_location("lcs_paths", SCRIPT_DIR.parent / "lcs_paths.py")
        lcs_paths = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(lcs_paths)
        reportados = lcs_paths.collections_root() / "ACH Reportados"
        if not reportados.exists():
            print(f"AVISO: no existe {reportados} -- no se copian los Files de Salesforce a OneDrive.")
            return
        dest_dir = reportados / MIRROR_SUBFOLDER
        dest_dir.mkdir(exist_ok=True)
        copiados = 0
        for title, cv_id, date, local_name, _status in manifest:
            if date < SF_PRIMARY_FROM:
                continue
            src = DOWNLOAD_DIR / local_name
            if not src.exists():
                continue
            sufijo = suffix_from_title(title)
            base = f"ACH_{date.replace('-', '')}{'_' + sufijo if sufijo else ''}"
            dest = dest_dir / f"{base}.csv"
            if dest.exists() and dest.read_bytes() == src.read_bytes():
                continue
            if dest.exists():
                dest = dest_dir / f"{base}_{cv_id}.csv"
                if dest.exists():
                    continue
            shutil.copyfile(src, dest)
            copiados += 1
            if not quiet:
                print(f"  -> OneDrive: {MIRROR_SUBFOLDER}\\{dest.name}")
        if not quiet:
            print(f"Copia a OneDrive ({dest_dir}): {copiados} archivo(s) nuevo(s).")
    except Exception as exc:
        print(f"AVISO: no se pudo copiar los Files de Salesforce a OneDrive: {exc}")


def main():
    sync_files(quiet=False)


if __name__ == "__main__":
    main()
