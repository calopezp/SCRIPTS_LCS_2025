#!/bin/bash
set -e

# ============================================================
# run_transmission_import.sh
# Uso diario: escanea DOS fuentes en busca de archivos nuevos --
# 1) la carpeta "ACH Reportados" en OneDrive y 2) los archivos
# "ACH_*.csv" subidos como Files en Salesforce (se sincronizan
# solos, ver fetch_salesforce_files.py) -- arma el delta del dia,
# despliega el CSV como Static Resource, y corre el Apex (preview
# o real).
#
# Solo se aplica el DELTA de esta corrida (los payments de los
# archivos nuevos), no el indice historico completo -- asi no se
# repite el limite de gobernanza (Too many query rows) que salio
# al aplicar los 5,730 payments de 2026 de una sola vez.
#
# CONFIGURAR UNA SOLA VEZ:
#   - ORG_ALIAS: alias de tu org en sf CLI (ej. MONEE)
#
# Uso:
#   ./run_transmission_import.sh                      -> escanea la carpeta, DRY RUN de todo lo nuevo
#   ./run_transmission_import.sh apply                -> escanea la carpeta, aplica todo lo nuevo (real)
#   ./run_transmission_import.sh <ruta_al_csv>         -> procesa SOLO ese archivo, DRY RUN
#   ./run_transmission_import.sh <ruta_al_csv> apply   -> procesa SOLO ese archivo (real)
# ============================================================

ORG_ALIAS="MONEE"
PROJECT_DIR="C:/SALESFORCE/LCS/SCRIPTS_LCS_2025"

STATIC_RESOURCE_DIR="$PROJECT_DIR/force-app/main/default/staticresources"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APEX_TEMPLATE="$SCRIPT_DIR/update_transmission_date.apex"
DELTA_CSV="$SCRIPT_DIR/index/last_run_delta.csv"
STATIC_RESOURCE_NAME="ACHTransmissionImport"

FILE_ARG=""
if [ -n "$1" ] && [ "$1" != "apply" ]; then
    FILE_ARG="$1"
    MODE="${2:-dryrun}"
else
    MODE="${1:-dryrun}"
fi

if [ -n "$FILE_ARG" ]; then
    echo "== 1) Procesando archivo especifico: $FILE_ARG =="
    python3 "$SCRIPT_DIR/extract_ach_transmission.py" "$FILE_ARG" "$DELTA_CSV"
else
    echo "== 1) Escaneando 'ACH Reportados' por archivos nuevos =="
    python3 "$SCRIPT_DIR/build_index.py"
fi

if [ ! -s "$DELTA_CSV" ] || [ "$(tail -n +2 "$DELTA_CSV" | wc -l)" -eq 0 ]; then
    echo ""
    echo "== Nada nuevo que transmitir. No hay CSV que aplicar. =="
    exit 0
fi

echo ""
echo "== 2) Copiando delta al proyecto SFDX =="
mkdir -p "$STATIC_RESOURCE_DIR"
cp "$DELTA_CSV" "$STATIC_RESOURCE_DIR/${STATIC_RESOURCE_NAME}.csv"

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
# confiamos ciegamente en $? aqui: si el exit code es distinto de 0,
# verificamos el resultado real del deploy antes de decidir abortar.
set +e
sf project deploy start -m StaticResource:${STATIC_RESOURCE_NAME} -o "$ORG_ALIAS"
DEPLOY_EXIT=$?
set -e

if [ $DEPLOY_EXIT -ne 0 ]; then
    echo ""
    echo "AVISO: 'sf project deploy start' devolvio codigo $DEPLOY_EXIT."
    echo "Verificando si el deploy realmente fallo o fue un falso positivo del CLI..."
    if sf project deploy report -o "$ORG_ALIAS" --use-most-recent | grep -qi "status.*succeeded"; then
        echo "Deploy confirmado como EXITOSO pese al codigo de salida. Continuando..."
    else
        echo "ERROR: el deploy del Static Resource fallo de verdad. Abortando."
        exit 1
    fi
fi

echo "== 4) Preparando script Apex (modo: $MODE) =="
TMP_APEX="$(mktemp /tmp/transmission_apex_XXXXXX).apex"
cp "$APEX_TEMPLATE" "$TMP_APEX"

if [ "$MODE" = "apply" ]; then
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
    echo "AVISO: 'sf apex run' devolvio codigo $APEX_EXIT (puede ser el mismo falso"
    echo "positivo del CLI que en el deploy). Revisa el debug log de arriba: si ves"
    echo "'UPDATE COMPLETADO -> Exitos: ...' el Apex si corrio correctamente."
fi

echo ""
echo "== Listo. Revisa el debug log arriba. =="
if [ "$MODE" != "apply" ]; then
    echo "Si todo se ve bien: ./run_transmission_import.sh apply"
fi
