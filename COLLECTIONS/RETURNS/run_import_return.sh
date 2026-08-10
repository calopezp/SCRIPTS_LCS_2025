#!/bin/bash
set -e

# ============================================================
# run_import_return.sh
# Uso diario: escanea las carpetas de OneDrive (ACH Returns +
# Check Collection, via ../build_index.py) en busca de PDFs
# nuevos -> arma el delta del dia -> despliega el CSV como
# Static Resource -> corre el Apex (preview o real).
#
# Solo se aplica el DELTA de esta corrida (los payments de los
# PDFs nuevos), no el indice historico completo.
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
# ============================================================

ORG_ALIAS="MONEE"
PROJECT_DIR="C:/SALESFORCE/LCS/SCRIPTS_LCS_2025"

STATIC_RESOURCE_DIR="$PROJECT_DIR/force-app/main/default/staticresources"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APEX_TEMPLATE="$SCRIPT_DIR/update_ach_returns.apex"
EXTRACT_SCRIPT="$SCRIPT_DIR/extract_ach_returns.py"
DELTA_CSV="$SCRIPT_DIR/../index/returns_last_run_delta.csv"
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
    echo "== 1) Escaneando carpetas de OneDrive por PDFs nuevos =="
    python3 "$SCRIPT_DIR/../build_index.py"
    if [ ! -s "$DELTA_CSV" ] || [ "$(tail -n +2 "$DELTA_CSV" | wc -l)" -eq 0 ]; then
        echo ""
        echo "== Nada nuevo que aplicar hoy en Returns. =="
        exit 0
    fi
    cp "$DELTA_CSV" "$CSV_OUT"
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
    if sf project deploy report -o "$ORG_ALIAS" --use-most-recent | grep -qi "status.*succeeded"; then
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
sf apex run --file "$TMP_APEX" -o "$ORG_ALIAS"
APEX_EXIT=$?
set -e

rm -f "$TMP_APEX"

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
