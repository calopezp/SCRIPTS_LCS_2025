/*
 * update_ach_returns.apex
 * -----------------------
 * Ejecutar como Anonymous Apex (VS Code + SFDX CLI: "SFDX: Execute Anonymous Apex").
 *
 * PRE-REQUISITO:
 *   1. Generar el CSV con extract_ach_returns.py
 *   2. Copiarlo a: force-app/main/default/staticresources/ACHReturnsImport.csv
 *   3. Crear el meta file: force-app/main/default/staticresources/ACHReturnsImport.resource-meta.xml
 *        <?xml version="1.0" encoding="UTF-8"?>
 *        <StaticResource xmlns="http://soap.sforce.com/2006/04/metadata">
 *            <cacheControl>Private</cacheControl>
 *            <contentType>text/csv</contentType>
 *        </StaticResource>
 *   4. Deploy: sf project deploy start -m StaticResource:ACHReturnsImport
 *
 * MODO DE USO:
 *   - Corre primero con DRY_RUN = true  -> solo imprime el preview, NO actualiza nada.
 *   - Revisa el debug log completo.
 *   - Si todo está correcto, cambia DRY_RUN = false y corre de nuevo -> aplica el UPDATE real.
 */

// ============ CONFIGURACIÓN ============
Boolean DRY_RUN = true; // <-- cambiar a false para ejecutar el update real
String STATIC_RESOURCE_NAME = 'ACHReturnsImport';
// ========================================

System.debug(' \u2192 ======================================================');
System.debug(' \u2192 MODO: ' + (DRY_RUN ? 'DRY RUN (solo preview, sin cambios)' : 'EJECUCIÓN REAL (se va a actualizar)'));
System.debug(' \u2192 ======================================================');

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
Integer idxPaymentName   = headers.indexOf('Payment_Name');
Integer idxStatus        = headers.indexOf('Payment_Status__c');
Integer idxCollDate      = headers.indexOf('SM_Check_Collection_Date__c');
Integer idxColl          = headers.indexOf('SM_Check_Collection__c');
Integer idxCollStatus    = headers.indexOf('SM_Check_Collection_Status__c');
Integer idxReturnCode    = headers.indexOf('SM_Return_code__c');
Integer idxReturnChange  = headers.indexOf('SM_Return_Change__c');

// Wrapper para llevar la data parseada + el resultado del match
class RowData {
    String paymentName;
    String status;
    Date collDate;
    Boolean coll;
    String collStatus;
    String returnCode;
    String returnChange;
    Id matchedPaymentId;
}

List<RowData> rows = new List<RowData>();
Set<String> paymentNames = new Set<String>();

for (Integer i = 1; i < lines.size(); i++) {
    if (String.isBlank(lines[i])) { continue; }
    List<String> cols = lines[i].split(',');

    RowData r = new RowData();
    r.paymentName  = cols[idxPaymentName].trim();
    r.status       = cols[idxStatus].trim();
    r.collDate     = Date.valueOf(cols[idxCollDate].trim());
    r.coll         = Boolean.valueOf(cols[idxColl].trim());
    r.collStatus   = cols[idxCollStatus].trim();
    r.returnCode   = cols[idxReturnCode].trim();
    r.returnChange = idxReturnChange < cols.size() ? cols[idxReturnChange].trim() : '';

    rows.add(r);
    paymentNames.add(r.paymentName);
}

System.debug(' \u2192 Total filas leídas del CSV: ' + rows.size());

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

for (RowData r : rows) {
    if (!nameToId.containsKey(r.paymentName)) {
        notFound.add(r.paymentName);
        continue;
    }
    r.matchedPaymentId = nameToId.get(r.paymentName);

    System.debug(
        'PREVIEW -> ' + r.paymentName +
        ' | Payment_Status__c: ' + r.status +
        ' | SM_Check_Collection_Date__c: ' + r.collDate +
        ' | SM_Check_Collection__c: ' + r.coll +
        ' | SM_Check_Collection_Status__c: ' + r.collStatus +
        ' | SM_Return_code__c: ' + r.returnCode +
        ' | SM_Return_Change__c: ' + (String.isBlank(r.returnChange) ? '(vacío)' : r.returnChange)
    );

    toUpdate.add(new SM_Payment__c(
        Id = r.matchedPaymentId,
        Payment_Status__c = r.status,
        SM_Check_Collection_Date__c = r.collDate,
        SM_Check_Collection__c = r.coll,
        SM_Check_Collection_Status__c = r.collStatus,
        SM_Return_code__c = r.returnCode,
        SM_Return_Change__c = r.returnChange
    ));
}

System.debug(' \u2192 ======================================================');
System.debug(' \u2192 Registros con match encontrado (listos para update): ' + toUpdate.size());
System.debug(' \u2192 Registros SIN match (PY-XXXX no existe como Payment): ' + notFound.size());
if (!notFound.isEmpty()) {
    System.debug(' \u2192   -> Nombres no encontrados: ' + notFound);
}
System.debug(' \u2192 ======================================================');

// 5) Ejecutar el update SOLO si DRY_RUN = false
if (!DRY_RUN) {
    if (toUpdate.isEmpty()) {
        System.debug(' \u2192 No hay registros para actualizar.');
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
                System.debug(
                    'ERROR actualizando ' + toUpdate[i].Id + ': ' +
                    res.getErrors()[0].getMessage()
                );
            }
        }
        System.debug(' \u2192 ======================================================');
        System.debug(' \u2192 UPDATE COMPLETADO -> Éxitos: ' + okCount + ' | Errores: ' + errCount);
        System.debug(' \u2192 ======================================================');
    }
} else {
    System.debug(' \u2192 DRY RUN activo: no se ejecutó ningún UPDATE. Cambia DRY_RUN a false para aplicar los cambios.');
}
