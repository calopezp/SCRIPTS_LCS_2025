"""
build_pending_deltas.py
------------------------
Arma los 2 CSV "para aplicar" (Returns, Collections) cruzando AMBOS
indices historicos juntos, para resolver cual reporte manda cuando el
mismo Payment aparece en los dos:

    1. Gana el reporte de fecha MAS RECIENTE.
    2. Si empatan en fecha, gana Collection sobre Return.

Sin este cruce, cada script corria contra su propio indice sin saber
que el otro reporte (mas reciente) ya habia superado ese pago -- lo que
podia revertir un pago ya cobrado a un estado de return viejo, o
viceversa (confirmado en vivo: PY-01867258 tenia un return del 17-jul
pero ya estaba COLLECTED desde el 11-ago; aplicar el CSV de Returns solo
lo hubiera revertido).

Cada Payment queda asignado a UN SOLO CSV de salida (el del reporte
ganador) -- si Collection gana, ese pago ni siquiera aparece en el CSV
de Returns, y viceversa. Asi cada script apex (update_ach_returns.apex /
update_check_collection.apex) solo ve los pagos que de verdad le
corresponden a el.

Solo se consideran filas dentro de los ultimos --days-back dias (evita
arrastrar reportes viejisimos ya superados por eventos mas alla de la
ventana -- ver detalle en el historial de build_full_csv.py, el
predecesor de este script).

Uso:
    python build_pending_deltas.py <returns_index.csv> <collections_index.csv> \
        <returns_out.csv> <collections_out.csv> [--days-back N]
"""

import argparse
import csv
from datetime import date, timedelta
from pathlib import Path

DATE_FIELD = "SM_Check_Collection_Date__c"


def load_rows(index_csv: Path, cutoff: date):
    if not index_csv.exists() or index_csv.stat().st_size == 0:
        return [], None
    with index_csv.open(newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        fieldnames = [fn for fn in reader.fieldnames if fn != "Source_File"]
        rows = []
        for r in reader:
            raw_date = r.get(DATE_FIELD, "")
            try:
                d = date.fromisoformat(raw_date) if raw_date else None
            except ValueError:
                d = None
            if d is None or d < cutoff:
                continue
            name = r.get("Payment_Name", "").strip()
            if not name:
                continue
            rows.append((d, name, r))
    return rows, fieldnames


def resolve_winners(returns_rows, collections_rows):
    """best[name] = (fecha, 'returns'|'collections', fila). Recorre Returns
    primero y Collections despues; una fila reemplaza a la actual si es
    estrictamente mas reciente, o si empata en fecha y la actual es de
    Returns (Collections gana el empate)."""
    best = {}
    for d, name, r in returns_rows:
        current = best.get(name)
        if current is None or d > current[0]:
            best[name] = (d, "returns", r)
    for d, name, r in collections_rows:
        current = best.get(name)
        if current is None or d > current[0] or (d == current[0] and current[1] == "returns"):
            best[name] = (d, "collections", r)
    return best


def write_csv(out_path: Path, fieldnames, rows):
    with out_path.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames, extrasaction="ignore")
        writer.writeheader()
        for r in sorted(rows, key=lambda r: r["Payment_Name"]):
            writer.writerow(r)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("returns_index")
    parser.add_argument("collections_index")
    parser.add_argument("returns_out")
    parser.add_argument("collections_out")
    parser.add_argument("--days-back", type=int, default=45)
    args = parser.parse_args()

    cutoff = date.today() - timedelta(days=args.days_back)

    returns_rows, returns_fields = load_rows(Path(args.returns_index), cutoff)
    collections_rows, collections_fields = load_rows(Path(args.collections_index), cutoff)

    best = resolve_winners(returns_rows, collections_rows)

    returns_winners = [r for (_, src, r) in best.values() if src == "returns"]
    collections_winners = [r for (_, src, r) in best.values() if src == "collections"]

    if returns_fields is not None:
        write_csv(Path(args.returns_out), returns_fields, returns_winners)
    if collections_fields is not None:
        write_csv(Path(args.collections_out), collections_fields, collections_winners)

    print(f"  Returns: {len(returns_rows)} fila(s) en los ultimos {args.days_back} dia(s) -> {len(returns_winners)} ganan (no superadas por un Collection mas reciente) -> {args.returns_out}")
    print(f"  Collections: {len(collections_rows)} fila(s) en los ultimos {args.days_back} dia(s) -> {len(collections_winners)} ganan -> {args.collections_out}")


if __name__ == "__main__":
    main()
