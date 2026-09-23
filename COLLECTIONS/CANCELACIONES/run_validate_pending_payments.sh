#!/bin/bash
set -e

# ============================================================
# run_validate_pending_payments.sh
# Valida (y opcionalmente resuelve) los payments/ordenes ACH bloqueantes
# de los contratos "candidatos a cancelar" -- ver validate_pending_payments.py
# para el detalle completo de la logica (cruce contra COLLECTIONS + Rule 3
# + ordenes activas -> Stopped).
#
# Uso:
#   ./run_validate_pending_payments.sh                    # dry-run, toda la lista maestra
#   ./run_validate_pending_payments.sh 00317661 00317795  # dry-run, solo estos
#   ./run_validate_pending_payments.sh apply               # aplica en real
#   ./run_validate_pending_payments.sh --no-update apply   # sin refrescar indices primero
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
python3 "$SCRIPT_DIR/validate_pending_payments.py" "$@"
