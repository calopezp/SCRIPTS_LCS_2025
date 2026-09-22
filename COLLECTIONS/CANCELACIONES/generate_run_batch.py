"""
Arma el bloque de Apex ("List<CancelarContratosRunner.CancelRequest>") para
pegar en scripts/apex/-CANCELAR_CONTRATOS_FULL.apex, leyendo Motivo y
Fecha de solicitud por contrato desde Contratos_para_Cancelar_LOG.csv (3
columnas: ContractNumber, Fecha "d mmm yyyy", Motivo).

No se puede meter TODA la lista maestra de una corrida -- ya rompimos el
límite de tamaño de Execute Anonymous (~32 KB) una vez con listas grandes
de puro texto; con Fecha+Motivo por fila pesa mucho más todavía. Por eso
este script solo genera el batch para los contratos que le pases (o para
una categoría de Contratos_para_Cancelar_ESTADO.csv), no para los 500+ de
una sola vez.

Uso:
    python generate_run_batch.py 00317661 00317795
    python generate_run_batch.py --categoria STUCK_CONTRACT_STATUS
    python generate_run_batch.py --categoria STUCK_CONTRACT_STATUS --limite 30

    # Contrato puntual que NO está en Contratos_para_Cancelar_LOG.csv --
    # se usan --motivo/--fecha en vez de saltarlo. No lo agrega al CSV
    # (queda solo en esta corrida) -- si es algo recurrente, mejor
    # agregarlo al CSV directamente para que quede en el historial.
    python generate_run_batch.py 00319999 --motivo "Does not comply with Payments" --fecha "22 sep 2026"
"""

import argparse
import csv
import sys
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
LOG_CSV = SCRIPT_DIR / "Contratos_para_Cancelar_LOG.csv"
ESTADO_CSV = SCRIPT_DIR / "Contratos_para_Cancelar_ESTADO.csv"

MESES_ES = {
    "ene": 1, "feb": 2, "mar": 3, "abr": 4, "may": 5, "jun": 6,
    "jul": 7, "ago": 8, "sep": 9, "oct": 10, "nov": 11, "dic": 12,
}


def parse_fecha_es(raw: str):
    """'10 jun 2026' -> (2026, 6, 10). Lanza ValueError si no matchea."""
    dia, mes_abbr, anio = raw.strip().split()
    mes = MESES_ES.get(mes_abbr.lower())
    if mes is None:
        raise ValueError(f"mes desconocido: {mes_abbr!r} (fecha completa: {raw!r})")
    return int(anio), mes, int(dia)


def load_log():
    """{ContractNumber: (fecha_raw, motivo)}"""
    rows = {}
    with open(LOG_CSV, encoding="utf-8") as f:
        for line in csv.reader(f, delimiter="\t"):
            if not line or not line[0].strip():
                continue
            num, fecha, motivo = (line + ["", ""])[:3]
            rows[num.strip()] = (fecha.strip(), motivo.strip())
    return rows


def load_estado_by_category(categoria):
    if not ESTADO_CSV.exists():
        print(f"ERROR: {ESTADO_CSV.name} no existe -- corre ./run_check_estado.sh primero.", file=sys.stderr)
        sys.exit(1)
    with open(ESTADO_CSV, encoding="utf-8") as f:
        return [r["ContractNumber"] for r in csv.DictReader(f) if r["Estado"] == categoria]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("contratos", nargs="*", help="ContractNumber puntuales")
    parser.add_argument("--categoria", help="Tomar todos los de esta categoria de Contratos_para_Cancelar_ESTADO.csv")
    parser.add_argument("--limite", type=int, default=50, help="Maximo de contratos en el batch (default 50, ver nota de tamano arriba)")
    parser.add_argument("--motivo", help="Motivo a usar para contratos puntuales que NO estan en el CSV (en vez de saltarlos)")
    parser.add_argument("--fecha", help="Fecha 'd mmm yyyy' a usar junto con --motivo para esos mismos contratos")
    args = parser.parse_args()

    if bool(args.motivo) != bool(args.fecha):
        print("ERROR: --motivo y --fecha van juntos (los dos, o ninguno).", file=sys.stderr)
        sys.exit(1)
    fallback = None
    if args.motivo:
        try:
            parse_fecha_es(args.fecha)  # solo para validar el formato temprano
        except ValueError as e:
            print(f"ERROR en --fecha: {e}", file=sys.stderr)
            sys.exit(1)
        fallback = (args.fecha.strip(), args.motivo.strip())

    if args.categoria:
        numeros = load_estado_by_category(args.categoria)
    elif args.contratos:
        numeros = [n.zfill(8) for n in args.contratos]
    else:
        print("Uso: generate_run_batch.py <contrato...> | --categoria <ESTADO>", file=sys.stderr)
        sys.exit(1)

    if len(numeros) > args.limite:
        print(f"-> {len(numeros)} contratos piden batch, recortando a --limite {args.limite} "
              f"(el resto queda para la proxima corrida).", file=sys.stderr)
        numeros = numeros[: args.limite]

    log = load_log()
    entries = []  # una entrada por contrato incluido -- la coma se decide
                  # al unir, nunca por posicion en `numeros` (si un contrato
                  # en el medio se salta, la coma del anterior quedaria mal)
    faltantes = []
    for num in numeros:
        if num not in log:
            if fallback is None:
                faltantes.append(num)
                continue
            fecha_raw, motivo = fallback
        else:
            fecha_raw, motivo = log[num]
        try:
            anio, mes, dia = parse_fecha_es(fecha_raw)
        except ValueError as e:
            print(f"ERROR parseando fecha de {num}: {e}", file=sys.stderr)
            sys.exit(1)
        motivo_escaped = motivo.replace("'", "\\'")
        entries.append(
            f"    new CancelarContratosRunner.CancelRequest('{num}', '{motivo_escaped}', "
            f"Date.newInstance({anio}, {mes}, {dia}))"
        )

    if faltantes:
        print(f"-> AVISO: {len(faltantes)} contrato(s) no estan en {LOG_CSV.name}, se omiten: {faltantes}", file=sys.stderr)

    lines = ["List<CancelarContratosRunner.CancelRequest> requests = new List<CancelarContratosRunner.CancelRequest>{"]
    lines.append(",\n".join(entries))
    lines.append("};")
    print("\n".join(lines))
    print(f"\n-> {len(entries)} contrato(s) en el batch.", file=sys.stderr)


if __name__ == "__main__":
    main()
