#!/bin/bash
set -e

# ============================================================
# run_daily_catchup.sh
# Reemplaza a run_all_imports.sh cuando hay ATRASO de reportes del banco
# (ej. no llegaron los Check Collection de 2-3 dias): en vez de aplicar
# TODO el Return pendiente y despues TODO el Collection pendiente (orden
# fijo por pipeline, no por fecha real), recorre cada fecha de reporte
# pendiente en orden ASCENDENTE y aplica, para esa fecha, primero Return
# y despues Collection -- igual que un dia normal (paso 1 y 2), solo que
# repetido dia por dia hasta ponerse al dia.
#
# Por que importa el orden: la regla de negocio "gana el reporte mas
# reciente, empate -> Collection" sale SOLA de este orden (Collection del
# mismo dia pisa a Return; un dia mas nuevo pisa a uno mas viejo, sin
# importar de que pipeline venga cada uno) -- ya no hace falta que
# build_pending_deltas.py decida un ganador y descarte al perdedor antes
# de llegar a Salesforce. Como update_ach_returns.apex y
# update_check_collection.apex ya comparan cada fila contra el estado
# ACTUAL del Payment (y ambos escriben SM_Return_code__c /
# SM_Check_Collection_Return_Reason__c), los DOS eventos quedan
# registrados -- Payment History (activado en Payment_Status__c,
# SM_Check_Collection_Status__c y SM_Return_code__c) muestra el paso real
# por RETURN y despues por COLLECTIONS, no solo el estado final.
#
# El paso de "marcar ACCEPTED los ACH TRANSMITTED sin reporte" (hoy
# mark_transmitted_accepted.apex, manual) sigue siendo un paso APARTE,
# a correr una sola vez despues de terminar todo el atraso -- no lo toca
# este script.
#
# Uso:
#   ./run_daily_catchup.sh                  -> escanea todo, DRY RUN dia por dia (SIN corte -- TODAS las fechas pendientes)
#   ./run_daily_catchup.sh apply             -> escanea todo, aplica dia por dia (real) -- SOLO fechas de los ultimos 2 meses
#   ./run_daily_catchup.sh apply 7           -> idem, pero solo mirando los ultimos 7 dias (corrida rapida/parcial)
#   CONFIRM_OLD=1 ./run_daily_catchup.sh apply  -> aplica TAMBIEN las fechas de mas de 2 meses (backlog historico real)
#
# SIN corte de fecha al LISTAR por defecto -- instruccion explicita del
# usuario (2026-09-09): TODO pago reportado en un archivo de RETURN o de
# COLLECTION se debe procesar, sin importar su fecha de transmision/
# SM_Check_Collection_Date__c. Antes el default era 7 dias "porque el
# atraso tipico es de 2-3 dias" -- resulto ser FALSO: el 2026-09-09 se
# detecto que un solo reporte de Check Collection (04-sep-2026) traia
# cheques con fechas de hasta 35 dias atras (Banco Popular reporta con
# atraso variable, no fijo), y esa ventana de 7 dias los estaba
# descartando en silencio -- 15 de 28 pagos de ese reporte nunca se
# aplicaron a Salesforce.
#
# PERO se requiere CONFIRMACION EXPLICITA (CONFIRM_OLD=1) para APLICAR
# fechas de mas de 2 meses de antiguedad -- instruccion explicita del
# usuario, mismo dia: al correr esta corrida sin corte por primera vez
# se detecto pendiente desde 2025-08-27 (mas de un año de indice
# acumulado) y se toco produccion mucho mas atras de lo que se pidio.
# Sin CONFIRM_OLD=1, las fechas de mas de 2 meses se LISTAN (para que se
# vea el alcance real) pero NO se aplican -- solo las de los ultimos 2
# meses se procesan automaticamente. Pasar un numero como segundo
# argumento sigue sirviendo para una corrida rapida/parcial puntual (ej.
# smoke test) dentro de esos mismos 2 meses. Los .apex son idempotentes
# (procesar de mas es inofensivo), procesar de menos pierde pagos reales
# -- por eso el corte de RECENCIA (7 dias) se elimino, pero el corte de
# ALCANCE/CONFIRMACION (2 meses) se agrego aparte.
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

MODE="${1:-dryrun}"
if [ -n "$1" ] && [ "$1" != "apply" ]; then
    echo "Uso: $0 [apply] [dias_atras]"
    exit 1
fi
APPLY_ARG=""
[ "$MODE" = "apply" ] && APPLY_ARG="apply"
DAYS_BACK="${2:-0}"
CONFIRM_OLD="${CONFIRM_OLD:-0}"
CUTOFF_2M="$(date -d '-2 months' +%Y-%m-%d)"

echo "############################################################"
echo "# 1/2 Escaneando Returns + Check Collection (build_index.py)"
echo "############################################################"
python3 "$SCRIPT_DIR/build_index.py"

echo ""
echo "############################################################"
echo "# 2/2 Aplicando dia por dia (modo: $MODE)"
echo "############################################################"


# tr -d '\r' es necesario: python en Windows imprime con \r\n, y el "for d in
# $DATES" de bash mas abajo solo separa por espacio/tab/salto de linea (no
# por \r) -- sin esto, cada fecha (menos la ultima) llega con un \r pegado al
# final ("2026-08-31\r") y --date nunca hace match con nada en el CSV,
# dejando el catch-up entero como no-op silencioso.
DATES=$(python3 "$SCRIPT_DIR/build_daily_apply_plan.py" --list-dates --days-back "$DAYS_BACK" | tr -d '\r')
if [ -z "$DATES" ]; then
    if [ "$DAYS_BACK" = "0" ]; then
        echo "Nada pendiente (sin corte de fecha -- se revisaron todas las fechas en los indices)."
    else
        echo "Nada pendiente dentro de la ventana de $DAYS_BACK dias."
    fi
    exit 0
fi

TOTAL_DAYS=$(echo "$DATES" | wc -l)
echo "Fechas pendientes (ascendente): $TOTAL_DAYS"
echo "$DATES"

# Separar RECIENTE (<= 2 meses, se procesa siempre) de VIEJO (> 2 meses,
# requiere CONFIRM_OLD=1 explicito -- ver header).
RECENT_DATES=""
OLD_DATES=""
for d in $DATES; do
    if [[ "$d" < "$CUTOFF_2M" ]]; then
        OLD_DATES="$OLD_DATES$d"$'\n'
    else
        RECENT_DATES="$RECENT_DATES$d"$'\n'
    fi
done
RECENT_DATES=$(echo -n "$RECENT_DATES" | sed '/^$/d')
OLD_DATES=$(echo -n "$OLD_DATES" | sed '/^$/d')

if [ -n "$OLD_DATES" ]; then
    OLD_COUNT=$(echo "$OLD_DATES" | wc -l)
    echo ""
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    echo "!!! $OLD_COUNT fecha(s) de MAS DE 2 MESES (antes de $CUTOFF_2M) pendientes:"
    echo "!!! $OLD_DATES"
    if [ "$MODE" != "apply" ]; then
        echo "!!! DRY RUN: se incluyen igual en el preview de abajo (no se escribe nada)."
        echo "!!! Para APLICARLAS de verdad hace falta: CONFIRM_OLD=1 $0 apply $2"
    elif [ "$CONFIRM_OLD" = "1" ]; then
        echo "!!! CONFIRM_OLD=1 -- se van a procesar TAMBIEN estas fechas viejas."
    else
        echo "!!! NO se van a procesar en esta corrida (falta confirmacion explicita)."
        echo "!!! Para procesarlas: CONFIRM_OLD=1 $0 $MODE $2"
    fi
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
fi

if [ "$MODE" != "apply" ] || [ "$CONFIRM_OLD" = "1" ]; then
    # DRY RUN siempre puede previsualizar todo (no escribe nada); en apply
    # real, solo si se confirmo explicitamente.
    DATES_TO_RUN="$DATES"
else
    DATES_TO_RUN="$RECENT_DATES"
fi

if [ -z "$DATES_TO_RUN" ]; then
    echo ""
    echo "Nada que procesar en esta corrida (todo lo pendiente es de mas de 2 meses -- usa CONFIRM_OLD=1 para incluirlo)."
    exit 0
fi

TOTAL_DAYS=$(echo "$DATES_TO_RUN" | wc -l)
echo ""
echo "Fechas a procesar en esta corrida: $TOTAL_DAYS"

RETURNS_CSV="$SCRIPT_DIR/RETURNS/ACHReturnsImport.csv"
COLLECTIONS_CSV="$SCRIPT_DIR/COLLECTIONS/CheckCollectionImport.csv"

for d in $DATES_TO_RUN; do
    echo ""
    echo "============================================================"
    echo " Fecha de reporte: $d"
    echo "============================================================"

    echo "-- Return $d --"
    python3 "$SCRIPT_DIR/build_daily_apply_plan.py" --date "$d" --side returns --out "$RETURNS_CSV"
    set +e
    SKIP_SCAN=1 bash "$SCRIPT_DIR/RETURNS/run_import_return.sh" $APPLY_ARG
    RETURNS_EXIT=$?
    set -e
    if [ $RETURNS_EXIT -ne 0 ]; then
        echo "AVISO: Returns del $d termino con codigo $RETURNS_EXIT (revisar arriba)."
    fi

    echo ""
    echo "-- Check Collection $d --"
    python3 "$SCRIPT_DIR/build_daily_apply_plan.py" --date "$d" --side collections --out "$COLLECTIONS_CSV"
    set +e
    SKIP_SCAN=1 bash "$SCRIPT_DIR/COLLECTIONS/run_import_collection.sh" $APPLY_ARG
    COLLECTIONS_EXIT=$?
    set -e
    if [ $COLLECTIONS_EXIT -ne 0 ]; then
        echo "AVISO: Check Collection del $d termino con codigo $COLLECTIONS_EXIT (revisar arriba)."
    fi
done

echo ""
echo "============================================================"
echo " Catch-up completado ($TOTAL_DAYS fecha(s) procesadas)."
echo " Pendiente aparte: correr mark_transmitted_accepted.apex una vez"
echo " que el atraso este al dia (paso 3, ACH TRANSMITTED sin reporte)."
echo "============================================================"
