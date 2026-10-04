"""
Parte index/transmission_index.csv (el índice histórico deduplicado) en
bloques de tamaño seguro para DML (<=9,000 filas por transacción de Apex),
para poder correr update_transmission_date.apex varias veces durante el
backfill histórico sin pasarse del límite de 10,000 registros por DML.

Uso:
    python split_index_for_backfill.py            # bloques de 8000 filas
    python split_index_for_backfill.py 5000        # tamaño de bloque custom
"""

import csv
import sys
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
INDEX_CSV = SCRIPT_DIR / "index" / "transmission_index.csv"
CHUNKS_DIR = SCRIPT_DIR / "index" / "backfill_chunks"

FIELDNAMES = ["Payment_Name", "SM_Transmission_Date_ACH_File__c", "Amount"]


def main():
    chunk_size = int(sys.argv[1]) if len(sys.argv) > 1 else 8000

    if not INDEX_CSV.exists():
        print(f"ERROR: no existe {INDEX_CSV}. Corre build_index.py primero.")
        sys.exit(1)

    with INDEX_CSV.open(newline="", encoding="utf-8") as f:
        rows = list(csv.DictReader(f))

    CHUNKS_DIR.mkdir(parents=True, exist_ok=True)
    for old in CHUNKS_DIR.glob("chunk_*.csv"):
        old.unlink()

    total_chunks = (len(rows) + chunk_size - 1) // chunk_size
    for i in range(total_chunks):
        chunk_rows = rows[i * chunk_size:(i + 1) * chunk_size]
        out_path = CHUNKS_DIR / f"chunk_{i + 1:02d}.csv"
        with out_path.open("w", newline="", encoding="utf-8") as f:
            writer = csv.DictWriter(f, fieldnames=FIELDNAMES, extrasaction="ignore")
            writer.writeheader()
            writer.writerows(chunk_rows)
        print(f"{out_path.name}: {len(chunk_rows)} fila(s)")

    print(f"\nTotal: {len(rows)} fila(s) -> {total_chunks} bloque(s) en {CHUNKS_DIR}")
    print("Cada bloque se deploya y procesa por separado con update_transmission_date.apex")
    print("(cambiando STATIC_RESOURCE_NAME o sobreescribiendo el mismo Static Resource entre corridas).")


if __name__ == "__main__":
    main()
