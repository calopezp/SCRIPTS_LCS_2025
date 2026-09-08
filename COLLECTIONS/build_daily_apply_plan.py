"""
build_daily_apply_plan.py
--------------------------
Reemplaza el rol de "elegir un ganador y descartar al perdedor" de
build_pending_deltas.py cuando hay ATRASO de varios dias de reportes del
banco (ej. no llegaron los Check Collection de 2-3 dias).

Motivo: si se aplica TODO el Return pendiente y despues TODO el Collection
pendiente (como hace run_all_imports.sh hoy), el orden de aplicacion queda
fijo por pipeline, no por fecha real del reporte -- eso puede hacer que un
reporte mas viejo quede aplicado DESPUES de uno mas nuevo solo por venir del
otro pipeline, y ademas nunca deja rastro en Salesforce del evento que
"pierde" (build_pending_deltas.py lo descarta antes de llegar a Salesforce).

Este script en cambio expone el pendiente AGRUPADO POR FECha DE REPORTE
(SM_Check_Collection_Date__c), para que el orquestador (run_daily_catchup.sh)
aplique dia por dia, en orden ascendente, Return antes que Collection del
MISMO dia -- asi:
  - El estado final por Payment converge al mismo resultado que la regla
    "gana el mas reciente, empate -> Collection" (es una consecuencia
    natural del orden, no algo que este script decida).
  - Los DOS eventos quedan escritos en Salesforce (aunque el segundo
    pise al primero), asi Payment History (activado en
    Payment_Status__c, SM_Check_Collection_Status__c y SM_Return_code__c)
    muestra el paso real por RETURN y despues por COLLECTIONS.

Los scripts .apex (update_ach_returns.apex / update_check_collection.apex)
NO cambian: ya comparan cada fila contra el estado actual y son
idempotentes, asi que aplicar de mas (una fecha ya aplicada) es inofensivo.

Uso:
    python build_daily_apply_plan.py --list-dates [--days-back 45]
        -> imprime las fechas (YYYY-MM-DD) con al menos 1 fila pendiente
           en returns_index.csv o collections_index.csv, ascendente,
           una por linea.

    python build_daily_apply_plan.py --date 2026-09-05 --side returns --out RETURNS/ACHReturnsImport.csv
    python build_daily_apply_plan.py --date 2026-09-05 --side collections --out COLLECTIONS/CheckCollectionImport.csv
        -> escribe SOLO las filas de esa fecha (deduplicadas por
           Payment_Name, se queda con la ultima si el mismo Payment
           aparece 2 veces el mismo dia) al CSV indicado, sin la columna
           Source_File -- mismo formato que ya esperan los .apex.
           Si no hay filas para esa fecha/lado, escribe igual el CSV con
           solo el encabezado (los .sh ya detectan "0 filas" y salen).
"""

import argparse
import csv
from datetime import datetime, timedelta
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
INDEX_DIR = SCRIPT_DIR / "index"
RETURNS_INDEX_CSV = INDEX_DIR / "returns_index.csv"
COLLECTIONS_INDEX_CSV = INDEX_DIR / "collections_index.csv"

DATE_FIELD = "SM_Check_Collection_Date__c"


def _read_index(csv_path: Path):
    if not csv_path.exists():
        return [], []
    with csv_path.open(newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        fieldnames = [fn for fn in reader.fieldnames if fn != "Source_File"]
        return list(reader), fieldnames


def _cutoff_date(days_back: int) -> str:
    return (datetime.today() - timedelta(days=days_back)).strftime("%Y-%m-%d")


def list_dates(days_back: int):
    cutoff = _cutoff_date(days_back)
    dates = set()
    for csv_path in (RETURNS_INDEX_CSV, COLLECTIONS_INDEX_CSV):
        rows, _ = _read_index(csv_path)
        for r in rows:
            d = r.get(DATE_FIELD, "")
            if d and d >= cutoff:
                dates.add(d)
    for d in sorted(dates):
        print(d)


def write_date_csv(side: str, date: str, out_path: Path):
    csv_path = RETURNS_INDEX_CSV if side == "returns" else COLLECTIONS_INDEX_CSV
    rows, fieldnames = _read_index(csv_path)

    # Deduplicar por Payment_Name (si el mismo payment aparece 2 veces el
    # mismo dia -- ej. 2 PDFs distintos del mismo dia -- se queda con la
    # ultima ocurrencia leida).
    best = {}
    for r in rows:
        if r.get(DATE_FIELD) != date:
            continue
        best[r["Payment_Name"]] = {k: v for k, v in r.items() if k != "Source_File"}

    out_path.parent.mkdir(parents=True, exist_ok=True)
    with out_path.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames, extrasaction="ignore")
        writer.writeheader()
        for name in sorted(best):
            writer.writerow(best[name])

    print(f"{side} {date}: {len(best)} payment(s) -> {out_path}")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--list-dates", action="store_true")
    parser.add_argument("--days-back", type=int, default=45)
    parser.add_argument("--date")
    parser.add_argument("--side", choices=["returns", "collections"])
    parser.add_argument("--out")
    args = parser.parse_args()

    if args.list_dates:
        list_dates(args.days_back)
        return

    if not (args.date and args.side and args.out):
        parser.error("--date, --side y --out son requeridos (o usa --list-dates)")

    write_date_csv(args.side, args.date, Path(args.out))


if __name__ == "__main__":
    main()
