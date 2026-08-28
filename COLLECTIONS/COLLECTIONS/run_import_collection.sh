#!/bin/bash
set -e

# ============================================================
# run_import_collection.sh
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
#   ./run_import_collection.sh                      -> escanea, DRY RUN de todo lo nuevo
#   ./run_import_collection.sh apply                -> escanea, aplica todo lo nuevo (real)
#   ./run_import_collection.sh <ruta_al_pdf>         -> procesa SOLO ese PDF, DRY RUN
#   ./run_import_collection.sh <ruta_al_pdf> apply   -> procesa SOLO ese PDF (real)
#
# SKIP_SCAN=1 ./run_import_collection.sh apply  -> omite el build_index.py y usa
#   el delta ya generado (lo usa run_all_imports.sh, que comparte el mismo
#   build_index.py con run_import_return.sh y solo lo corre una vez).
# ============================================================

ORG_ALIAS="MONEE"
PROJECT_DIR="C:/SALESFORCE/LCS/SCRIPTS_LCS_2025"

STATIC_RESOURCE_DIR="$PROJECT_DIR/force-app/main/default/staticresources"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APEX_TEMPLATE="$SCRIPT_DIR/update_check_collection.apex"
EXTRACT_SCRIPT="$SCRIPT_DIR/extract_check_collection.py"
DELTA_CSV="$SCRIPT_DIR/../index/collections_last_run_delta.csv"
STATIC_RESOURCE_NAME="CheckCollectionImport"
R10_DIR="$SCRIPT_DIR/reportes_comercial_R10"

FILE_ARG=""
if [ -n "$1" ] && [ "$1" != "apply" ]; then
    FILE_ARG="$1"
    MODE="${2:-dryrun}"
else
    MODE="${1:-dryrun}"
fi

CSV_OUT="$SCRIPT_DIR/CheckCollectionImport.csv"

if [ -n "$FILE_ARG" ]; then
    echo "== 1) Procesando PDF especifico: $FILE_ARG =="
    python3 "$EXTRACT_SCRIPT" "$FILE_ARG" "$CSV_OUT"

    PDF_BASENAME="$(basename "$FILE_ARG" .pdf)"
    R10_OUT="$SCRIPT_DIR/CheckCollectionImport_R10_ClienteSolicitoDevolucion.csv"
    # El reporte R10 (clientes que pidieron la devolución directo al banco) se
    # sobreescribiría en cada corrida si se deja con nombre fijo; lo copiamos
    # aparte con el nombre del PDF de origen para no perder el de días anteriores.
    if [ -s "$R10_OUT" ] && [ "$(tail -n +2 "$R10_OUT" | wc -l)" -gt 0 ]; then
        mkdir -p "$R10_DIR"
        cp "$R10_OUT" "$R10_DIR/${PDF_BASENAME}_R10.csv"
        echo "Reporte para Comercial guardado en: $R10_DIR/${PDF_BASENAME}_R10.csv"
    fi
else
    if [ "$SKIP_SCAN" = "1" ]; then
        echo "== 1) Scan omitido (SKIP_SCAN=1) -- usando el delta ya generado =="
    else
        echo "== 1) Escaneando carpetas de OneDrive por PDFs nuevos =="
        python3 "$SCRIPT_DIR/../build_index.py"
    fi
    if [ ! -s "$DELTA_CSV" ] || [ "$(tail -n +2 "$DELTA_CSV" | wc -l)" -eq 0 ]; then
        echo ""
        echo "== Nada nuevo que aplicar hoy en Check Collection. =="
        exit 0
    fi
    cp "$DELTA_CSV" "$CSV_OUT"

    # Filtrar filas R10 del delta del dia para el reporte de Comercial.
    TODAY="$(date +%Y%m%d)"
    R10_OUT="$SCRIPT_DIR/CheckCollectionImport_R10_ClienteSolicitoDevolucion.csv"
    python3 - "$CSV_OUT" "$R10_OUT" << 'PYEOF'
import csv, sys
src, dst = sys.argv[1], sys.argv[2]
with open(src, newline='', encoding='utf-8') as f:
    rows = [r for r in csv.DictReader(f) if r.get('Reason', '').strip().upper().startswith('R10')]
if rows:
    with open(dst, 'w', newline='', encoding='utf-8') as f:
        w = csv.DictWriter(f, fieldnames=list(rows[0].keys()))
        w.writeheader()
        w.writerows(rows)
    print(f"{len(rows)} registro(s) R10 encontrados")
else:
    print("Sin registros R10 en el delta de hoy")
PYEOF
    if [ -s "$R10_OUT" ] && [ "$(tail -n +2 "$R10_OUT" | wc -l)" -gt 0 ]; then
        mkdir -p "$R10_DIR"
        cp "$R10_OUT" "$R10_DIR/delta_${TODAY}_R10.csv"
        echo "Reporte para Comercial guardado en: $R10_DIR/delta_${TODAY}_R10.csv"
    fi
fi

echo ""
echo "== 2) Copiando CSV al proyecto SFDX =="
mkdir -p "$STATIC_RESOURCE_DIR"
cp "$CSV_OUT" "$STATIC_RESOURCE_DIR/${STATIC_RESOURCE_NAME}.csv"

if [ ! -f "$STATIC_RESOURCE_DIR/${STATIC_RESOURCE_NAME}.resource-meta.xml" ]; then
    cat > "$STATIC_RESOURCE_DIR/${STATIC_RESOURCE_NAME}.resource-meta.xml" << EOF
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
sf project deploy start -m "StaticResource:${STATIC_RESOURCE_NAME}" -o "$ORG_ALIAS"
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
TMP_APEX="$(mktemp /tmp/checkcol_apex_XXXXXX).apex"
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
