"""
Rutas compartidas del pipeline de COLLECTIONS -- un solo lugar, sin rutas
fijas de ninguna maquina (traspaso del proceso, ver TRASPASO_PROCESO.md).

La carpeta "COMPILADO COLLECTIONS" de OneDrive se resuelve asi, en orden:
  1) variable de entorno LCS_COLLECTIONS_DIR (ruta completa a la carpeta), si
     se quiere forzar otra ubicacion;
  2) %OneDriveCommercial%\\COMPILADO COLLECTIONS -- Windows define
     OneDriveCommercial en cualquier equipo con OneDrive de la empresa
     sincronizado (ej. "C:\\OneDrive - LCS" o "C:\\Users\\<usuario>\\OneDrive - LCS");
  3) C:\\OneDrive - LCS\\COMPILADO COLLECTIONS (ubicacion historica).

Requisito en la maquina nueva: la carpeta debe estar sincronizada (o agregada
como acceso directo desde SharePoint/OneDrive compartido) con el MISMO nombre
"COMPILADO COLLECTIONS" en la raiz del OneDrive de la empresa.
"""

import os
from datetime import date
from pathlib import Path

CARPETA = "COMPILADO COLLECTIONS"

# Primer año con carpeta anual indexada por el pipeline de Returns/Collection
# (los PDFs de años anteriores nunca se indexaron -- no ampliar sin confirmar,
# Rule 2 / regla de los 6 meses en CLAUDE.md).
PRIMER_ANIO_INDEXADO = 2026


def collections_root() -> Path:
    override = os.environ.get("LCS_COLLECTIONS_DIR")
    if override:
        return Path(override)
    onedrive = os.environ.get("OneDriveCommercial")
    if onedrive and (Path(onedrive) / CARPETA).exists():
        return Path(onedrive) / CARPETA
    return Path(r"C:\OneDrive - LCS") / CARPETA


def carpetas_anuales(subcarpeta: str):
    """Carpetas por año ("ACH Returns\\2026", "...\\2027", ...) desde
    PRIMER_ANIO_INDEXADO hasta el año actual -- asi el cambio de año no deja
    los PDFs nuevos fuera del indice."""
    base = collections_root() / subcarpeta
    return [base / str(y) for y in range(PRIMER_ANIO_INDEXADO, date.today().year + 1)]
