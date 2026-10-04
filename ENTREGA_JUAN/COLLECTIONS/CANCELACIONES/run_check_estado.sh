#!/bin/bash
set -e

# ============================================================
# run_check_estado.sh
# Recalcula Contratos_para_Cancelar_ESTADO.csv contra Salesforce en
# vivo. Solo lee -- no actualiza nada en Salesforce, así que no tiene
# modo dry-run/apply como el resto de COLLECTIONS/.
#
# Uso:
#   ./run_check_estado.sh                    -> toda la lista maestra
#   ./run_check_estado.sh 00317661 00317795  -> solo estos contratos
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
python3 "$SCRIPT_DIR/check_estado_cancelaciones.py" "$@"
