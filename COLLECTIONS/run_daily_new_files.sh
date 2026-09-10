#!/bin/bash
set -e

# ============================================================
# run_daily_new_files.sh
# Comando de uso DIARIO (requerimiento explicito del usuario, 2026-09-09):
#   1. Busca archivos de RETURN y de COLLECTION que NUNCA hayan estado en
#      el indice (build_index.py).
#   2. Procesa SOLO los payments reportados en esos archivos nuevos --
#      Return primero, despues Collection, sin importar la fecha interna
#      de cada fila (Rule 1: un archivo nuevo se procesa completo).
#   3. Despues corre ACH Reportados (run_transmission_import.sh).
#
# Corte de 1 semana por archivo (no por fecha interna de la fila): un
# archivo NUNCA antes visto pero con mas de 7 dias de antiguedad en disco
# (ej. alguien deja caer un historico manual en la carpeta de OneDrive) NO
# se aplica solo -- build_index.py ya lo deja fuera del delta de hoy y lo
# reporta en index/archivos_viejos_pendientes_confirmacion.csv. Para
# procesar ESE archivo especifico hay que decirlo explicitamente:
#   ./RETURNS/run_import_return.sh "<ruta al pdf>" apply
#   ./COLLECTIONS/run_import_collection.sh "<ruta al pdf>" apply
#
# Este script es DISTINTO de run_daily_catchup.sh (ese es para reprocesar
# a proposito un rango de fechas del historico ya indexado, con su propio
# gate de confirmacion a los 2 meses -- CONFIRM_OLD=1). Este script solo
# mira archivos NUEVOS, nunca reprocesa el indice historico.
#
# Uso:
#   ./run_daily_new_files.sh          -> DRY RUN (preview, no escribe nada)
#   ./run_daily_new_files.sh apply    -> aplica de verdad
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

MODE="${1:-dryrun}"
if [ -n "$1" ] && [ "$1" != "apply" ]; then
    echo "Uso: $0 [apply]"
    exit 1
fi
APPLY_ARG=""
[ "$MODE" = "apply" ] && APPLY_ARG="apply"

RETURNS_DELTA_CSV="$SCRIPT_DIR/index/returns_last_run_delta.csv"
COLLECTIONS_DELTA_CSV="$SCRIPT_DIR/index/collections_last_run_delta.csv"
ARCHIVOS_VIEJOS_CSV="$SCRIPT_DIR/index/archivos_viejos_pendientes_confirmacion.csv"
RETURNS_CSV_OUT="$SCRIPT_DIR/RETURNS/ACHReturnsImport.csv"
COLLECTIONS_CSV_OUT="$SCRIPT_DIR/COLLECTIONS/CheckCollectionImport.csv"

echo "############################################################"
echo "# 1/3 Escaneando Returns + Check Collection por archivos NUEVOS"
echo "############################################################"
python3 "$SCRIPT_DIR/build_index.py"

RETURNS_PENDING=0
COLLECTIONS_PENDING=0
[ -s "$RETURNS_DELTA_CSV" ] && [ "$(tail -n +2 "$RETURNS_DELTA_CSV" | wc -l)" -gt 0 ] && RETURNS_PENDING=1
[ -s "$COLLECTIONS_DELTA_CSV" ] && [ "$(tail -n +2 "$COLLECTIONS_DELTA_CSV" | wc -l)" -gt 0 ] && COLLECTIONS_PENDING=1

if [ "$RETURNS_PENDING" = "0" ] && [ "$COLLECTIONS_PENDING" = "0" ]; then
    echo ""
    echo "Nada nuevo (dentro de los ultimos 7 dias) que aplicar en Returns/Collection."
else
    echo ""
    echo "############################################################"
    echo "# 2/3 Aplicando SOLO los archivos nuevos (modo: $MODE)"
    echo "############################################################"

    if [ "$RETURNS_PENDING" = "1" ]; then
        echo ""
        echo "-- Returns (archivos nuevos) --"
        cp "$RETURNS_DELTA_CSV" "$RETURNS_CSV_OUT"
        set +e
        SKIP_SCAN=1 bash "$SCRIPT_DIR/RETURNS/run_import_return.sh" $APPLY_ARG
        RETURNS_EXIT=$?
        set -e
        [ $RETURNS_EXIT -ne 0 ] && echo "AVISO: Returns termino con codigo $RETURNS_EXIT (revisar arriba)."
    else
        echo "-- Returns: sin archivos nuevos recientes, nada que aplicar --"
    fi

    if [ "$COLLECTIONS_PENDING" = "1" ]; then
        echo ""
        echo "-- Check Collection (archivos nuevos) --"
        cp "$COLLECTIONS_DELTA_CSV" "$COLLECTIONS_CSV_OUT"
        set +e
        SKIP_SCAN=1 bash "$SCRIPT_DIR/COLLECTIONS/run_import_collection.sh" $APPLY_ARG
        COLLECTIONS_EXIT=$?
        set -e
        [ $COLLECTIONS_EXIT -ne 0 ] && echo "AVISO: Check Collection termino con codigo $COLLECTIONS_EXIT (revisar arriba)."
    else
        echo "-- Check Collection: sin archivos nuevos recientes, nada que aplicar --"
    fi
fi

echo ""
echo "############################################################"
echo "# 3/3 ACH Reportados (transmission)"
echo "############################################################"
set +e
bash "$SCRIPT_DIR/ACH_REPORTADOS/run_transmission_import.sh" $APPLY_ARG
TRANSMISSION_EXIT=$?
set -e
[ $TRANSMISSION_EXIT -ne 0 ] && echo "AVISO: ACH Reportados termino con codigo $TRANSMISSION_EXIT (revisar arriba)."

if [ -s "$ARCHIVOS_VIEJOS_CSV" ]; then
    echo ""
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    echo "!!! Archivos NUEVOS pero de mas de 7 dias de antiguedad -- NO se aplicaron:"
    cat "$ARCHIVOS_VIEJOS_CSV"
    echo "!!! Para procesar alguno, indicalo explicitamente con el modo de un solo archivo:"
    echo "!!!   RETURNS/run_import_return.sh \"<ruta al pdf>\" apply"
    echo "!!!   COLLECTIONS/run_import_collection.sh \"<ruta al pdf>\" apply"
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
fi

echo ""
echo "============================================================"
echo " Corrida diaria completada (modo: $MODE)."
echo "============================================================"
