/*
 * update_check_collection.apex
 * -----------------------------
 * Ejecutar como Anonymous Apex (VS Code + SFDX CLI: "SFDX: Execute Anonymous Apex").
 *
 * PRE-REQUISITO:
 *   1. Generar el CSV con extract_check_collection.py
 *   2. Copiarlo a: force-app/main/default/staticresources/CheckCollectionImport.csv
 *   3. Crear el meta file: force-app/main/default/staticresources/CheckCollectionImport.resource-meta.xml
 *        <?xml version="1.0" encoding="UTF-8"?>
 *        <StaticResource xmlns="http://soap.sforce.com/2006/04/metadata">
 *            <cacheControl>Private</cacheControl>
 *            <contentType>text/csv</contentType>
 *        </StaticResource>
 *   4. Deploy: sf project deploy start -m StaticResource:CheckCollectionImport
 *
 * MODO DE USO:
 *   - Corre primero con DRY_RUN = true  -> solo imprime el preview, NO actualiza nada.
 *   - Revisa el debug log completo.
 *   - Si todo está correcto, cambia DRY_RUN = false y corre de nuevo -> aplica el UPDATE real.
 *
 * NOTA: si el CSV trae mas de un cheque para la misma orden ACH (mismo
 * SM_ACH_Order__c), solo se actualiza el mas reciente por
 * SM_Check_Collection_Date__c; los demas quedan pendientes para la
 * siguiente corrida (ver "Registros superados" en el debug log).
 */

// ============ CONFIGURACIÓN ============
Boolean DRY_RUN = true; // <-- cambiar a false para ejecutar el update real
String STATIC_RESOURCE_NAME = 'CheckCollectionImport';
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
Integer idxPaymentName = headers.indexOf('Payment_Name');
Integer idxStatus      = headers.indexOf('Payment_Status__c');
Integer idxCollDate    = headers.indexOf('SM_Check_Collection_Date__c');
Integer idxColl        = headers.indexOf('SM_Check_Collection__c');
Integer idxCollStatus  = headers.indexOf('SM_Check_Collection_Status__c');

// Wrapper para llevar la data parseada + el resultado del match
class RowData {
    String paymentName;
    String status;
    Date collDate;
    Boolean coll;
    String collStatus;
    Id matchedPaymentId;
    Id achOrderId;
}

List<RowData> rows = new List<RowData>();
Set<String> paymentNames = new Set<String>();

for (Integer i = 1; i < lines.size(); i++) {
    if (String.isBlank(lines[i])) { continue; }
    List<String> cols = lines[i].split(',');

    RowData r = new RowData();
    r.paymentName = cols[idxPaymentName].trim();
    r.status      = cols[idxStatus].trim();
    r.collDate    = Date.valueOf(cols[idxCollDate].trim());
    r.coll        = Boolean.valueOf(cols[idxColl].trim());
    r.collStatus  = cols[idxCollStatus].trim();

    rows.add(r);
    paymentNames.add(r.paymentName);
}

System.debug(' \u2192 Total filas leídas del CSV: ' + rows.size());

// 3) Buscar los registros SM_Payment__c que hagan match por Name
Map<String, SM_Payment__c> paymentByName = new Map<String, SM_Payment__c>();
for (SM_Payment__c p : [
    SELECT Id, Name, SM_ACH_Order__c
    FROM SM_Payment__c
    WHERE Name IN :paymentNames
]) {
    paymentByName.put(p.Name, p);
}

// 4) Separar lo que matcheo de lo que no
List<RowData> matchedRows = new List<RowData>();
List<String> notFound = new List<String>();

for (RowData r : rows) {
    SM_Payment__c match = paymentByName.get(r.paymentName);
    if (match == null) {
        notFound.add(r.paymentName);
        continue;
    }
    r.matchedPaymentId = match.Id;
    r.achOrderId = match.SM_ACH_Order__c;
    matchedRows.add(r);
}

// 4b) Dedupe por SM_ACH_Order__c: si varios cheques del mismo archivo
// pertenecen a la misma orden ACH, actualizarlos todos en el mismo DML
// hace que SM_PaymentHandler (trigger AfterUpdate) intente actualizar esa
// misma orden ACH dos veces en la misma lista y falle con
// "Duplicate id in list". Por eso aca, antes de tocar Salesforce, solo se
// deja pasar el registro mas reciente (por SM_Check_Collection_Date__c) de
// cada orden ACH repetida; los demas quedan para la siguiente corrida,
// donde ya no habra colision.
Map<Id, RowData> winnerByAchOrder = new Map<Id, RowData>();
List<RowData> supersededRows = new List<RowData>();
List<RowData> toApply = new List<RowData>();

for (RowData r : matchedRows) {
    if (r.achOrderId == null) {
        toApply.add(r);
        continue;
    }
    RowData current = winnerByAchOrder.get(r.achOrderId);
    if (current == null) {
        winnerByAchOrder.put(r.achOrderId, r);
    } else if (r.collDate > current.collDate) {
        supersededRows.add(current);
        winnerByAchOrder.put(r.achOrderId, r);
    } else {
        supersededRows.add(r);
    }
}
toApply.addAll(winnerByAchOrder.values());

// 5) Armar preview + lista de update final
List<SM_Payment__c> toUpdate = new List<SM_Payment__c>();

for (RowData r : toApply) {
    System.debug(
        'PREVIEW -> ' + r.paymentName +
        ' | Payment_Status__c: ' + r.status +
        ' | SM_Check_Collection_Date__c: ' + r.collDate +
        ' | SM_Check_Collection__c: ' + r.coll +
        ' | SM_Check_Collection_Status__c: ' + r.collStatus
    );

    toUpdate.add(new SM_Payment__c(
        Id = r.matchedPaymentId,
        Payment_Status__c = r.status,
        SM_Check_Collection_Date__c = r.collDate,
        SM_Check_Collection__c = r.coll,
        SM_Check_Collection_Status__c = r.collStatus
    ));
}

System.debug(' \u2192 ======================================================');
System.debug(' \u2192 Registros con match encontrado: ' + matchedRows.size());
System.debug(' \u2192 Registros SIN match (PY-XXXX no existe como Payment): ' + notFound.size());
if (!notFound.isEmpty()) {
    System.debug(' \u2192   -> Nombres no encontrados: ' + notFound);
}
System.debug(' \u2192 Registros superados por otro pago mas reciente de la misma orden ACH (quedan para la siguiente corrida): ' + supersededRows.size());
if (!supersededRows.isEmpty()) {
    List<String> supersededNames = new List<String>();
    for (RowData r : supersededRows) { supersededNames.add(r.paymentName); }
    System.debug(' \u2192   -> Nombres pospuestos: ' + supersededNames);
}
System.debug(' \u2192 Registros a actualizar en esta corrida: ' + toUpdate.size());
System.debug(' \u2192 ======================================================');

// 6) Ejecutar el update SOLO si DRY_RUN = false
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
