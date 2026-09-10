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
predecesor de este script). El corte es por la fecha de TRANSACCION
(EFF ENTRY DATE / TRAN DATE), no por cuando llego el reporte -- un
reporte que confirma esta semana el resultado de una transaccion de
hace mas de --days-back dias quedaria silenciosamente descartado (bug
real detectado 2026-09-07: 7 pagos de mediados de julio, ~48-53 dias
antes, no se actualizaban con la ventana de 45 dias pese a que el
reporte que los resolvia ya habia llegado esa semana). Por eso el
default subio de 45 a 60 dias -- suficiente margen para reportes
tardios tipicos, sin arrastrar meses de historico viejo cada corrida
(NO usar una ventana enorme o sin limite: eso reprocesa todo el
historial y puede chocar contra pagos ya resueltos por una via que no
quedo en este indice -- ver el guard de regresion en los .apex, que
protege lo COLLECTED/ACCEPTED pero no reemplaza acotar la ventana).

ADEMAS, cualquier fila cuyo Payment_Name aparezca en el delta de la
corrida actual (--returns-delta / --collections-delta -- los PDFs
recien escaneados HOY, generados por build_index.py) se incluye
SIEMPRE, sin importar que tan vieja sea su SM_Check_Collection_Date__c.
Instruccion explicita del usuario (2026-09-09): todo pago reportado en
un archivo de RETURN o de COLLECTION que se esta trabajando se debe
procesar, independiente de su fecha de transmision -- el reporte del
04-sep-2026 traia cheques de hasta 35 dias atras y el corte de dias los
estaba descartando en silencio (ver
[[feedback_collections_process_all_dates]] / commit 461dc21). El
--days-back sigue existiendo como red de seguridad para reintentar
pagos de corridas anteriores que nunca se aplicaron (historico, no del
escaneo de hoy) -- eso si respeta la ventana (ahora de 60 dias).

Uso:
    python build_pending_deltas.py <returns_index.csv> <collections_index.csv> \
        <returns_out.csv> <collections_out.csv> [--days-back N]
        [--returns-delta returns_last_run_delta.csv]
        [--collections-delta collections_last_run_delta.csv]
"""

import argparse
import csv
from datetime import date, timedelta
from pathlib import Path

DATE_FIELD = "SM_Check_Collection_Date__c"


def load_delta_names(delta_csv: Path) -> set:
    if not delta_csv or not delta_csv.exists() or delta_csv.stat().st_size == 0:
        return set()
    with delta_csv.open(newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        return {r.get("Payment_Name", "").strip() for r in reader if r.get("Payment_Name", "").strip()}


def load_rows(index_csv: Path, cutoff: date, always_include: set):
    if not index_csv.exists() or index_csv.stat().st_size == 0:
        return [], None
    with index_csv.open(newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        fieldnames = [fn for fn in reader.fieldnames if fn != "Source_File"]
        rows = []
        for r in reader:
            name = r.get("Payment_Name", "").strip()
            if not name:
                continue
            raw_date = r.get(DATE_FIELD, "")
            try:
                d = date.fromisoformat(raw_date) if raw_date else None
            except ValueError:
                d = None
            if d is None:
                continue
            if d < cutoff and name not in always_include:
                continue
            rows.append((d, name, r))
    return rows, fieldnames


def resolve_winners(returns_rows, collections_rows):
    """best[name] = (fecha, 'returns'|'collections', fila). Recorre Returns
    primero y Collections despues; una fila reemplaza a la actual si es
    mas reciente O EMPATA en fecha (>=, no >).

    El empate no es un caso raro: la fecha que se compara es la del
    campo (EFF ENTRY DATE / TRAN DATE de la transaccion), no la fecha del
    reporte -- el MISMO pago puede aparecer en dos reportes de Collection
    de dias distintos (ej. PENDING el 18-ago, COLLECTED el 31-ago) con
    esa fecha de transaccion identica en ambos. Como build_index.py
    siempre agrega al final del indice en el orden en que escaneo cada
    PDF, "el que aparece despues en la lista" es el reporte mas reciente
    -- por eso >= (no >) dentro del mismo origen dejaba pasar de largo el
    reporte nuevo cuando empataba en fecha con uno viejo (bug real:
    PY-01880982 se quedo en PENDING del 18-ago en vez de pasar a
    COLLECTED del reporte del 31-ago, misma fecha de transaccion 17-ago
    en los dos). Entre Returns y Collections, >= tambien hace que
    Collections gane cualquier empate contra Returns, sin necesitar un
    chequeo aparte."""
    best = {}
    for d, name, r in returns_rows:
        current = best.get(name)
        if current is None or d >= current[0]:
            best[name] = (d, "returns", r)
    for d, name, r in collections_rows:
        current = best.get(name)
        if current is None or d >= current[0]:
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
    parser.add_argument("--days-back", type=int, default=60)
    parser.add_argument("--returns-delta", default=None,
                         help="returns_last_run_delta.csv -- estos Payment_Name se incluyen SIEMPRE, sin importar su fecha")
    parser.add_argument("--collections-delta", default=None,
                         help="collections_last_run_delta.csv -- estos Payment_Name se incluyen SIEMPRE, sin importar su fecha")
    args = parser.parse_args()

    cutoff = date.today() - timedelta(days=args.days_back)

    always_include = set()
    always_include |= load_delta_names(Path(args.returns_delta)) if args.returns_delta else set()
    always_include |= load_delta_names(Path(args.collections_delta)) if args.collections_delta else set()

    returns_rows, returns_fields = load_rows(Path(args.returns_index), cutoff, always_include)
    collections_rows, collections_fields = load_rows(Path(args.collections_index), cutoff, always_include)

    best = resolve_winners(returns_rows, collections_rows)

    returns_winners = [r for (_, src, r) in best.values() if src == "returns"]
    collections_winners = [r for (_, src, r) in best.values() if src == "collections"]

    if returns_fields is not None:
        write_csv(Path(args.returns_out), returns_fields, returns_winners)
    if collections_fields is not None:
        write_csv(Path(args.collections_out), collections_fields, collections_winners)

    extra = f" (+{len(always_include)} del delta de hoy, sin importar su fecha)" if always_include else ""
    print(f"  Returns: {len(returns_rows)} fila(s) en los ultimos {args.days_back} dia(s){extra} -> {len(returns_winners)} ganan (no superadas por un Collection mas reciente) -> {args.returns_out}")
    print(f"  Collections: {len(collections_rows)} fila(s) en los ultimos {args.days_back} dia(s){extra} -> {len(collections_winners)} ganan -> {args.collections_out}")


if __name__ == "__main__":
    main()
