#!/bin/bash
set -e

# ============================================================
# run_import_return.sh
# Uso diario: escanea las carpetas de OneDrive (ACH Returns +
# Check Collection, via ../build_index.py) en busca de PDFs
# nuevos -> arma el CSV a aplicar desde el INDICE HISTORICO
# COMPLETO (no solo los PDFs nuevos de hoy) -> despliega el CSV
# como Static Resource -> corre el Apex (preview o real).
#
# Se manda el historico de los ultimos 45 dias (no solo los PDFs
# nuevos de hoy) porque update_ach_returns.apex compara cada fila
# contra el estado ACTUAL en Salesforce y solo aplica lo que de
# verdad esta pendiente -- asi el proceso diario tambien detecta y
# aplica solo registros de PDFs ya escaneados en corridas anteriores
# cuyo UPDATE nunca llego a aplicarse (ej. por el bug de "Duplicate
# id in list"), sin necesidad de reprocesar manualmente el PDF
# especifico. Se limita a 45 dias (no todo el historico) para no
# reaplicar reportes viejos ya superados por eventos posteriores.
#
# El CSV se arma cruzando el indice de Returns CONTRA el de Check
# Collection (build_pending_deltas.py): si el mismo Payment aparece
# en los dos, manda el reporte mas reciente (empate -> gana
# Collection) -- asi este script nunca revierte un pago a un return
# viejo si Collection ya lo supero despues (o viceversa).
#
# CONFIGURAR UNA SOLA VEZ:
#   - ORG_ALIAS: alias de tu org en sf CLI (ej. MONEE)
#   - PROJECT_DIR: ruta a la raíz de tu proyecto SFDX
#
# Uso:
#   ./run_import_return.sh                      -> escanea, DRY RUN de todo lo nuevo
#   ./run_import_return.sh apply                -> escanea, aplica todo lo nuevo (real)
#   ./run_import_return.sh <ruta_al_pdf>         -> procesa SOLO ese PDF, DRY RUN
#   ./run_import_return.sh <ruta_al_pdf> apply   -> procesa SOLO ese PDF (real)
#
# SKIP_SCAN=1 ./run_import_return.sh apply  -> omite el build_index.py y el
#   cruce de indices, usa los CSV ya generados (lo usa run_all_imports.sh,
#   que corre ambos pasos una sola vez y comparte el resultado con
#   run_import_collection.sh).
# ============================================================

ORG_ALIAS="MONEE"
PROJECT_DIR="C:/SALESFORCE/LCS/SCRIPTS_LCS_2025"

STATIC_RESOURCE_DIR="$PROJECT_DIR/force-app/main/default/staticresources"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APEX_TEMPLATE="$SCRIPT_DIR/update_ach_returns.apex"
EXTRACT_SCRIPT="$SCRIPT_DIR/extract_ach_returns.py"
RETURNS_INDEX_CSV="$SCRIPT_DIR/../index/returns_index.csv"
COLLECTIONS_INDEX_CSV="$SCRIPT_DIR/../index/collections_index.csv"
STATIC_RESOURCE_NAME="ACHReturnsImport"

FILE_ARG=""
if [ -n "$1" ] && [ "$1" != "apply" ]; then
    FILE_ARG="$1"
    MODE="${2:-dryrun}"
else
    MODE="${1:-dryrun}"
fi

CSV_OUT="$SCRIPT_DIR/ACHReturnsImport.csv"

if [ -n "$FILE_ARG" ]; then
    echo "== 1) Procesando PDF especifico: $FILE_ARG =="
    python3 "$EXTRACT_SCRIPT" "$FILE_ARG" "$CSV_OUT"
else
    if [ "$SKIP_SCAN" = "1" ]; then
        echo "== 1) Scan y cruce de indices omitidos (SKIP_SCAN=1) -- usando el CSV ya generado =="
    else
        echo "== 1) Escaneando carpetas de OneDrive por PDFs nuevos =="
        python3 "$SCRIPT_DIR/../build_index.py"
        if [ ! -s "$RETURNS_INDEX_CSV" ]; then
            echo ""
            echo "== Indice de Returns vacio, nada que aplicar. =="
            exit 0
        fi
        echo "== 1b) Cruzando Returns vs Check Collection (gana el mas reciente, empate -> Collection) =="
        python3 "$SCRIPT_DIR/../build_pending_deltas.py" \
            "$RETURNS_INDEX_CSV" "$COLLECTIONS_INDEX_CSV" \
            "$CSV_OUT" "$SCRIPT_DIR/../COLLECTIONS/CheckCollectionImport.csv"
    fi
    if [ ! -s "$CSV_OUT" ] || [ "$(tail -n +2 "$CSV_OUT" | wc -l)" -eq 0 ]; then
        echo ""
        echo "== Nada que aplicar en Returns (todo dentro de la ventana ya esta aplicado o le corresponde a Collection). =="
        exit 0
    fi
fi

echo ""
echo "== 2) Copiando CSV al proyecto SFDX =="
mkdir -p "$STATIC_RESOURCE_DIR"
cp "$CSV_OUT" "$STATIC_RESOURCE_DIR/${STATIC_RESOURCE_NAME}.csv"

if [ ! -f "$STATIC_RESOURCE_DIR/${STATIC_RESOURCE_NAME}.resource-meta.xml" ]; then
    cat > "$STATIC_RESOURCE_DIR/${STATIC_RESOURCE_NAME}.resource-meta.xml" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<StaticResource xmlns="http://soap.sforce.com/2006/04/metadata">
    <cacheControl>Private</cacheControl>
    <contentType>text/csv</contentType>
</StaticResource>
EOF
fi

echo "== 3) Deploy del Static Resource a $ORG_ALIAS =="
# NOTA: el CLI de sf a veces devuelve exit code 1 aunque el deploy haya sido
# exitoso (bug conocido del chequeo de "update available"). Por eso no
# confiamos ciegamente en $? aquí: si el exit code es distinto de 0,
# verificamos el resultado real del deploy antes de decidir abortar.
set +e
sf project deploy start -m StaticResource:${STATIC_RESOURCE_NAME} -o "$ORG_ALIAS"
DEPLOY_EXIT=$?
set -e

if [ $DEPLOY_EXIT -ne 0 ]; then
    echo ""
    echo "AVISO: 'sf project deploy start' devolvió código $DEPLOY_EXIT."
    echo "Verificando si el deploy realmente falló o fue un falso positivo del CLI..."
    # El deploy puede seguir "In Progress" un momento despues de que el CLI
    # devuelve el control -- un solo chequeo inmediato puede pescarlo a
    # mitad de camino y reportar falla cuando en realidad solo falta
    # esperar. Se reintenta unas cuantas veces antes de rendirse.
    set +e
    DEPLOY_OK=0
    for i in 1 2 3 4 5 6; do
        REPORT="$(sf project deploy report -o "$ORG_ALIAS" --use-most-recent 2>&1)"
        if echo "$REPORT" | grep -qi "status.*succeeded"; then
            DEPLOY_OK=1
            break
        fi
        if echo "$REPORT" | grep -qi "status.*failed"; then
            break
        fi
        sleep 5
    done
    set -e
    if [ $DEPLOY_OK -eq 1 ]; then
        echo "Deploy confirmado como EXITOSO pese al código de salida. Continuando..."
    else
        echo "ERROR: el deploy del Static Resource falló de verdad. Abortando."
        exit 1
    fi
fi

echo "== 4) Preparando script Apex (modo: $MODE) =="
TMP_APEX="$(mktemp /tmp/ach_apex_XXXXXX).apex"
cp "$APEX_TEMPLATE" "$TMP_APEX"

if [ "$MODE" = "apply" ]; then
    # Compatibilidad Linux (GNU sed) y macOS (BSD sed)
    if sed --version >/dev/null 2>&1; then
        sed -i 's/Boolean DRY_RUN = true;/Boolean DRY_RUN = false;/' "$TMP_APEX"
    else
        sed -i '' 's/Boolean DRY_RUN = true;/Boolean DRY_RUN = false;/' "$TMP_APEX"
    fi
    echo ">>> MODO APPLY: se va a ejecutar el UPDATE real <<<"
else
    echo ">>> MODO DRY RUN: solo preview, no se actualiza nada <<<"
fi

echo "== 5) Ejecutando Anonymous Apex en $ORG_ALIAS =="
set +e
APEX_OUTPUT="$(sf apex run --file "$TMP_APEX" -o "$ORG_ALIAS" 2>&1)"
APEX_EXIT=$?
set -e
echo "$APEX_OUTPUT"

rm -f "$TMP_APEX"

# Pagos ya COLLECTED/ACCEPTED que este reporte queria revertir a RETURN --
# nunca se aplican solos, se avisan aca (ademas del debug log) y quedan
# guardados en un log aparte para no perderse entre corridas.
if echo "$APEX_OUTPUT" | grep "USER_DEBUG" | grep -q "ALERTA:"; then
    REGRESSION_LOG="$SCRIPT_DIR/../regresiones_manual_review.log"
    ALERT_LINE="$(echo "$APEX_OUTPUT" | grep "USER_DEBUG" | grep "ALERTA:" | sed -E 's/^.*DEBUG\|//' | head -1)"
    NAMES_LINE="$(echo "$APEX_OUTPUT" | grep "USER_DEBUG" | grep "Nombres bloqueados por regresion" | sed -E 's/^.*DEBUG\|//' | head -1)"
    echo ""
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    echo "!!! $ALERT_LINE"
    echo "!!! $NAMES_LINE"
    echo "!!! Guardado en: $REGRESSION_LOG -- revisar manualmente"
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    {
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] ($STATIC_RESOURCE_NAME)"
        echo "  $ALERT_LINE"
        echo "  $NAMES_LINE"
        echo ""
    } >> "$REGRESSION_LOG"
fi

if [ $APEX_EXIT -ne 0 ]; then
    echo ""
    echo "AVISO: 'sf apex run' devolvió código $APEX_EXIT (puede ser el mismo falso"
    echo "positivo del CLI que en el deploy). Revisa el debug log de arriba: si ves"
    echo "'UPDATE COMPLETADO -> Éxitos: ...' el Apex sí corrió correctamente."
fi

echo ""
echo "== Listo. Revisa el debug log arriba. =="
if [ "$MODE" != "apply" ]; then
    echo "Si todo se ve bien, agrega 'apply' al final del mismo comando."
fi
