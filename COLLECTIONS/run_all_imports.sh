#!/bin/bash
set -e

# ============================================================
# run_all_imports.sh
# Corre en un solo comando los 3 imports diarios:
#   1) ACH Returns          (RETURNS/run_import_return.sh)
#   2) Check Collection     (COLLECTIONS/run_import_collection.sh)
#   3) ACH Reportados       (ACH_REPORTADOS/run_transmission_import.sh)
#
# Returns y Check Collection comparten el mismo build_index.py
# (escanea ambas carpetas de OneDrive en una sola pasada), asi que
# aqui se corre UNA sola vez y los dos scripts hijos se llaman con
# SKIP_SCAN=1 para que reusen el delta ya generado en vez de
# volver a escanear -- reescanear a mitad de camino encuentra "0
# nuevos" (porque el primer scan ya los indexo) y eso hace que el
# script borre el delta del segundo antes de poder aplicarlo (el
# mismo bug que dejo sin aplicar el ACH Returns Report del
# 2026-08-20).
#
# ACH Reportados usa su propio indice independiente
# (ACH_REPORTADOS/build_index.py), asi que ese corre su scan normal.
#
# Un fallo en un import NO aborta los otros dos -- se corren los
# 3 y al final se muestra un resumen con el resultado de cada uno.
#
# Uso:
#   ./run_all_imports.sh          -> escanea todo, DRY RUN de todo lo nuevo
#   ./run_all_imports.sh apply    -> escanea todo, aplica todo lo nuevo (real)
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

MODE="${1:-dryrun}"
if [ -n "$1" ] && [ "$1" != "apply" ]; then
    echo "Uso: $0 [apply]"
    exit 1
fi

if [ "$MODE" = "apply" ]; then
    APPLY_ARGS=(apply)
else
    APPLY_ARGS=()
fi

echo "############################################################"
echo "# 1/4 Escaneando Returns + Check Collection (build_index.py compartido)"
echo "############################################################"
set +e
python3 "$SCRIPT_DIR/build_index.py"
SCAN_EXIT=$?
set -e
if [ $SCAN_EXIT -ne 0 ]; then
    echo "ERROR: build_index.py (Returns/Check Collection) fallo con codigo $SCAN_EXIT."
    echo "Se omiten los imports de Returns y Check Collection; se intenta ACH Reportados igual."
fi

echo ""
echo "############################################################"
echo "# 2/4 ACH Returns (modo: $MODE)"
echo "############################################################"
if [ $SCAN_EXIT -eq 0 ]; then
    set +e
    SKIP_SCAN=1 bash "$SCRIPT_DIR/RETURNS/run_import_return.sh" "${APPLY_ARGS[@]}"
    RETURNS_EXIT=$?
    set -e
else
    RETURNS_EXIT=$SCAN_EXIT
fi

echo ""
echo "############################################################"
echo "# 3/4 Check Collection (modo: $MODE)"
echo "############################################################"
if [ $SCAN_EXIT -eq 0 ]; then
    set +e
    SKIP_SCAN=1 bash "$SCRIPT_DIR/COLLECTIONS/run_import_collection.sh" "${APPLY_ARGS[@]}"
    COLLECTIONS_EXIT=$?
    set -e
else
    COLLECTIONS_EXIT=$SCAN_EXIT
fi

echo ""
echo "############################################################"
echo "# 4/4 ACH Reportados / Transmission (modo: $MODE)"
echo "############################################################"
set +e
bash "$SCRIPT_DIR/ACH_REPORTADOS/run_transmission_import.sh" "${APPLY_ARGS[@]}"
TRANSMISSION_EXIT=$?
set -e

echo ""
echo "============================================================"
echo "  RESUMEN (modo: $MODE)"
echo "============================================================"
printf "  %-20s exit %s\n" "ACH Returns:" "$RETURNS_EXIT"
printf "  %-20s exit %s\n" "Check Collection:" "$COLLECTIONS_EXIT"
printf "  %-20s exit %s\n" "ACH Reportados:" "$TRANSMISSION_EXIT"

if [ "$MODE" != "apply" ]; then
    echo ""
    echo "Si todo se ve bien, agrega 'apply' al final del mismo comando."
fi

if [ $RETURNS_EXIT -ne 0 ] || [ $COLLECTIONS_EXIT -ne 0 ] || [ $TRANSMISSION_EXIT -ne 0 ]; then
    exit 1
fi
exit 0
