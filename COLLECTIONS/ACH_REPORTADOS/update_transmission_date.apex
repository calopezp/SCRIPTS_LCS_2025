/*
 * update_transmission_date.apex
 * ------------------------------
 * Ejecutar como Anonymous Apex (VS Code + SFDX CLI: "SFDX: Execute Anonymous Apex").
 *
 * PRE-REQUISITO:
 *   1. Generar el CSV con extract_ach_transmission.py (un archivo del día) o
 *      con build_index.py (índice histórico completo, ya deduplicado).
 *   2. Copiarlo a: force-app/main/default/staticresources/ACHTransmissionImport.csv
 *   3. Crear el meta file: force-app/main/default/staticresources/ACHTransmissionImport.resource-meta.xml
 *        <?xml version="1.0" encoding="UTF-8"?>
 *        <StaticResource xmlns="http://soap.sforce.com/2006/04/metadata">
 *            <cacheControl>Private</cacheControl>
 *            <contentType>text/csv</contentType>
 *        </StaticResource>
 *   4. Deploy: sf project deploy start -m StaticResource:ACHTransmissionImport
 *
 * IMPORTANTE -- LÍMITE DE DML (10,000 registros por transacción):
 *   Si el CSV trae más de ~9,000 filas (ej. el índice histórico completo),
 *   este script NO alcanza a procesarlo en una sola corrida. Para el backfill
 *   histórico, partir el CSV en bloques (ver split_index_for_backfill.py) y
 *   correr este script una vez por bloque.
 *
 * MODO DE USO:
 *   - Corre primero con DRY_RUN = true  -> solo imprime el preview, NO actualiza nada.
 *   - Revisa el debug log completo.
 *   - Si todo está correcto, cambia DRY_RUN = false y corre de nuevo -> aplica el UPDATE real.
 */

// ============ CONFIGURACIÓN ============
Boolean DRY_RUN = true; // <-- cambiar a false para ejecutar el update real
String STATIC_RESOURCE_NAME = 'ACHTransmissionImport';
// ========================================

System.debug('======================================================');
System.debug('MODO: ' + (DRY_RUN ? 'DRY RUN (solo preview, sin cambios)' : 'EJECUCIÓN REAL (se va a actualizar)'));
System.debug('======================================================');

// 1) Leer el Static Resource (CSV generado por el script Python)
StaticResource sr = [
    SELECT Body
    FROM StaticResource
    WHERE Name = :STATIC_RESOURCE_NAME
    LIMIT 1
];
String csvBody = sr.Body.toString();

// 2) Parsear el CSV (sin comas dentro de los valores, así que split simple es seguro)
List<String> lines = csvBody.split('\r\n');
if (lines.size() == 1) {
    lines = csvBody.split('\n'); // por si el line ending viene distinto
}

List<String> headers = lines[0].split(',');
Integer idxPaymentName = headers.indexOf('Payment_Name');
Integer idxTransDate   = headers.indexOf('SM_Transmission_Date_ACH_File__c');

class RowData {
    String paymentName;
    Date transDate;
    Id matchedPaymentId;
}

List<RowData> rows = new List<RowData>();
Set<String> paymentNames = new Set<String>();

for (Integer i = 1; i < lines.size(); i++) {
    if (String.isBlank(lines[i])) { continue; }
    List<String> cols = lines[i].split(',');

    RowData r = new RowData();
    r.paymentName = cols[idxPaymentName].trim();
    r.transDate   = Date.valueOf(cols[idxTransDate].trim());

    rows.add(r);
    paymentNames.add(r.paymentName);
}

System.debug('Total filas leídas del CSV: ' + rows.size());

if (rows.size() > 9000) {
    System.debug('======================================================');
    System.debug('ABORTADO: el CSV trae ' + rows.size() + ' filas, por encima del límite');
    System.debug('seguro de DML por transacción (10,000). Partir el archivo en bloques');
    System.debug('más chicos antes de correr este script (ver split_index_for_backfill.py).');
    System.debug('======================================================');
    return;
}

// 3) Buscar los registros SM_Payment__c que hagan match por Name
Map<String, Id> nameToId = new Map<String, Id>();
for (SM_Payment__c p : [
    SELECT Id, Name
    FROM SM_Payment__c
    WHERE Name IN :paymentNames
]) {
    nameToId.put(p.Name, p.Id);
}

// 4) Armar preview + lista de update, separando lo que no matcheó
List<SM_Payment__c> toUpdate = new List<SM_Payment__c>();
List<String> notFound = new List<String>();
Integer previewCount = 0;

for (RowData r : rows) {
    if (!nameToId.containsKey(r.paymentName)) {
        notFound.add(r.paymentName);
        continue;
    }
    r.matchedPaymentId = nameToId.get(r.paymentName);

    if (previewCount < 50) {
        System.debug('PREVIEW -> ' + r.paymentName + ' | SM_Transmission_Date_ACH_File__c: ' + r.transDate);
        previewCount++;
    }

    toUpdate.add(new SM_Payment__c(
        Id = r.matchedPaymentId,
        SM_Transmission_Date_ACH_File__c = r.transDate
    ));
}
if (rows.size() > 50) {
    System.debug('(preview truncado a 50 filas de ' + rows.size() + ' -- el resto se procesa igual)');
}

System.debug('======================================================');
System.debug('Registros con match encontrado (listos para update): ' + toUpdate.size());
System.debug('Registros SIN match (PY-XXXX no existe como Payment): ' + notFound.size());
if (!notFound.isEmpty() && notFound.size() <= 100) {
    System.debug('  -> Nombres no encontrados: ' + notFound);
} else if (!notFound.isEmpty()) {
    System.debug('  -> ' + notFound.size() + ' nombres no encontrados (lista omitida, muy larga).');
}
System.debug('======================================================');

// 5) Ejecutar el update SOLO si DRY_RUN = false
if (!DRY_RUN) {
    if (toUpdate.isEmpty()) {
        System.debug('No hay registros para actualizar.');
    } else {
        List<Database.SaveResult> results = Database.update(toUpdate, false);
        Integer okCount = 0;
        Integer errCount = 0;
        for (Integer i = 0; i < results.size(); i++) {
            Database.SaveResult res = results[i];
            if (res.isSuccess()) {
                okCount++;
            } else {
                errCount++;
                if (errCount <= 20) {
                    System.debug(
                        'ERROR actualizando ' + toUpdate[i].Id + ': ' +
                        res.getErrors()[0].getMessage()
                    );
                }
            }
        }
        System.debug('======================================================');
        System.debug('UPDATE COMPLETADO -> Éxitos: ' + okCount + ' | Errores: ' + errCount);
        System.debug('======================================================');
    }
} else {
    System.debug('DRY RUN activo: no se ejecutó ningún UPDATE. Cambia DRY_RUN a false para aplicar los cambios.');
}
