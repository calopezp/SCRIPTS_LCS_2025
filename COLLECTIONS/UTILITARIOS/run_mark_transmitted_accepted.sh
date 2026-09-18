#!/bin/bash
set -e

# ============================================================
# run_mark_transmitted_accepted.sh
# Rutina MANUAL (no forma parte de run_all_imports.sh todavia):
# marca como ACCEPTED / SM_Check_Collection_Status__c: COLLECTED los
# Payments en 'ACH TRANSMITTED' que llevan 15+ dias transmitidos y
# nunca aparecieron en un reporte de Returns ni de Check Collection.
#
# PRE-REQUISITO: correr primero el import de Returns/Collection del
# dia (ej. run_all_imports.sh apply), para que cualquier reporte real
# que SI llego ya haya sido aplicado antes de asumir "sin reporte =
# aceptado". Este script no escanea PDFs, solo consulta el estado
# ACTUAL en Salesforce.
#
# No necesita CSV ni Static Resource -- corre directo contra Salesforce.
#
# CONFIGURAR UNA SOLA VEZ:
#   - ORG_ALIAS: alias de tu org en sf CLI (ej. MONEE)
#
# Uso:
#   ./run_mark_transmitted_accepted.sh          -> DRY RUN (preview)
#   ./run_mark_transmitted_accepted.sh apply    -> aplica el UPDATE real
# ============================================================

ORG_ALIAS="MONEE"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APEX_TEMPLATE="$SCRIPT_DIR/mark_transmitted_accepted.apex"

MODE="${1:-dryrun}"
if [ -n "$1" ] && [ "$1" != "apply" ]; then
    echo "Uso: $0 [apply]"
    exit 1
fi

echo "== Preparando script Apex (modo: $MODE) =="
TMP_APEX="$(mktemp /tmp/mark_accepted_apex_XXXXXX).apex"
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

echo "== Ejecutando Anonymous Apex en $ORG_ALIAS =="
set +e
sf apex run --file "$TMP_APEX" -o "$ORG_ALIAS"
APEX_EXIT=$?
set -e

rm -f "$TMP_APEX"

if [ $APEX_EXIT -ne 0 ]; then
    echo ""
    echo "AVISO: 'sf apex run' devolvió código $APEX_EXIT (puede ser el mismo falso"
    echo "positivo del CLI que en los otros scripts). Revisa el debug log de arriba:"
    echo "si ves 'UPDATE COMPLETADO -> Éxitos: ...' el Apex sí corrió correctamente."
fi

echo ""
echo "== Listo. Revisa el debug log arriba. =="
if [ "$MODE" != "apply" ]; then
    echo "Si todo se ve bien, agrega 'apply' al final del mismo comando."
fi
