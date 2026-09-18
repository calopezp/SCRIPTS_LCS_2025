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
#   4. Corre UTILITARIOS/mark_transmitted_accepted.apex (automatizado aqui
#      2026-09-18): marca ACCEPTED/COLLECTED los payments ACH TRANSMITTED
#      hace 15/20+ dias (DAYS_SINCE_TRANSMITTED) sin NINGUN reporte de
#      Returns/Collection -- corre a proposito DESPUES de los pasos 1-3 de
#      arriba, para que un reporte real que si llego hoy tenga prioridad.
#      Respeta el modo DRY RUN/apply igual que el resto del script.
#   5. En modo apply, manda 6 correos (notify_r02.apex, notify_r10.apex,
#      notify_invalid_account.apex, notify_r07.apex, notify_r16.apex,
#      notify_timeout_reversal.apex -- todos via SM_ReturnCodeNotifier.cls) con la
#      lista actual de contratos con un ACH Return R02 (cuenta cerrada), R10 (cliente
#      no autoriza), R04/R13 (cuenta/routing invalido), R07 (autorizacion revocada),
#      R16 (cuenta congelada) sin resolver, o un pago aceptado por timeout que un
#      reporte real luego contradijo -- ninguno se arregla reintentando el mismo
#      metodo de pago.
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
echo "# 1/4 Escaneando Returns + Check Collection por archivos NUEVOS"
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
    echo "# 2/4 Aplicando SOLO los archivos nuevos (modo: $MODE)"
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
echo "# 3/4 ACH Reportados (transmission)"
echo "############################################################"
set +e
bash "$SCRIPT_DIR/ACH_REPORTADOS/run_transmission_import.sh" $APPLY_ARG
TRANSMISSION_EXIT=$?
set -e
[ $TRANSMISSION_EXIT -ne 0 ] && echo "AVISO: ACH Reportados termino con codigo $TRANSMISSION_EXIT (revisar arriba)."

echo ""
echo "############################################################"
echo "# 4/4 Marcar ACCEPTED por timeout (sin reporte tras N dias)"
echo "############################################################"
# Corre DESPUES de los 3 pipelines de arriba a proposito -- asi cualquier
# reporte real que SI llego hoy ya quedo aplicado antes de asumir "sin
# reporte = aceptado" (ver UTILITARIOS/mark_transmitted_accepted.apex).
# Mismo patron seguro que usan RETURNS/run_import_return.sh y
# COLLECTIONS/run_import_collection.sh: el .apex en el repo SIEMPRE queda
# en DRY_RUN=true, este script copia a un temporal y solo ahi cambia a
# false en modo apply -- nunca se edita el archivo del repo.
TIMEOUT_APEX_TEMPLATE="$SCRIPT_DIR/UTILITARIOS/mark_transmitted_accepted.apex"
TMP_TIMEOUT_APEX="$(mktemp -u /tmp/mark_accepted_apex_XXXXXX.apex)"
cp "$TIMEOUT_APEX_TEMPLATE" "$TMP_TIMEOUT_APEX"
if [ "$MODE" = "apply" ]; then
    if sed --version >/dev/null 2>&1; then
        sed -i 's/Boolean DRY_RUN = true;/Boolean DRY_RUN = false;/' "$TMP_TIMEOUT_APEX"
    else
        sed -i '' 's/Boolean DRY_RUN = true;/Boolean DRY_RUN = false;/' "$TMP_TIMEOUT_APEX"
    fi
fi
set +e
sf apex run -o MONEE -f "$TMP_TIMEOUT_APEX"
TIMEOUT_EXIT=$?
set -e
rm -f "$TMP_TIMEOUT_APEX"
[ $TIMEOUT_EXIT -ne 0 ] && echo "AVISO: mark_transmitted_accepted.apex termino con codigo $TIMEOUT_EXIT (revisar arriba)."

if [ "$MODE" = "apply" ]; then
    echo ""
    echo "############################################################"
    echo "# Notificacion: contratos con ACH Return R02 (cuenta cerrada)"
    echo "############################################################"
    set +e
    sf apex run -o MONEE -f "$SCRIPT_DIR/notify_r02.apex"
    R02_EXIT=$?
    set -e
    [ $R02_EXIT -ne 0 ] && echo "AVISO: notify_r02.apex termino con codigo $R02_EXIT (revisar arriba)."

    echo ""
    echo "############################################################"
    echo "# Notificacion: contratos con ACH Return R10 (cliente no autoriza)"
    echo "############################################################"
    set +e
    sf apex run -o MONEE -f "$SCRIPT_DIR/notify_r10.apex"
    R10_EXIT=$?
    set -e
    [ $R10_EXIT -ne 0 ] && echo "AVISO: notify_r10.apex termino con codigo $R10_EXIT (revisar arriba)."

    echo ""
    echo "############################################################"
    echo "# Notificacion: contratos con ACH Return R04/R13 (cuenta/routing invalido)"
    echo "############################################################"
    set +e
    sf apex run -o MONEE -f "$SCRIPT_DIR/notify_invalid_account.apex"
    INVALID_ACCT_EXIT=$?
    set -e
    [ $INVALID_ACCT_EXIT -ne 0 ] && echo "AVISO: notify_invalid_account.apex termino con codigo $INVALID_ACCT_EXIT (revisar arriba)."

    echo ""
    echo "############################################################"
    echo "# Notificacion: contratos con ACH Return R07 (autorizacion revocada)"
    echo "############################################################"
    set +e
    sf apex run -o MONEE -f "$SCRIPT_DIR/notify_r07.apex"
    R07_EXIT=$?
    set -e
    [ $R07_EXIT -ne 0 ] && echo "AVISO: notify_r07.apex termino con codigo $R07_EXIT (revisar arriba)."

    echo ""
    echo "############################################################"
    echo "# Notificacion: contratos con ACH Return R16 (cuenta congelada)"
    echo "############################################################"
    set +e
    sf apex run -o MONEE -f "$SCRIPT_DIR/notify_r16.apex"
    R16_EXIT=$?
    set -e
    [ $R16_EXIT -ne 0 ] && echo "AVISO: notify_r16.apex termino con codigo $R16_EXIT (revisar arriba)."

    echo ""
    echo "############################################################"
    echo "# Notificacion: pagos aceptados por timeout y luego revertidos por reporte real"
    echo "############################################################"
    set +e
    sf apex run -o MONEE -f "$SCRIPT_DIR/notify_timeout_reversal.apex"
    TIMEOUT_REVERSAL_EXIT=$?
    set -e
    [ $TIMEOUT_REVERSAL_EXIT -ne 0 ] && echo "AVISO: notify_timeout_reversal.apex termino con codigo $TIMEOUT_REVERSAL_EXIT (revisar arriba)."
fi

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
