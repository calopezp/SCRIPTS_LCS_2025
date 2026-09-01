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
 *   - Si todo esta correcto, cambia DRY_RUN a false y corre de nuevo -> aplica el UPDATE real.
 *
 * Antes de armar el update, compara cada fila del CSV contra el estado
 * ACTUAL del Payment en Salesforce -- si ya coincide en todos los campos,
 * se salta (no se re-aplica). Asi el CSV puede traer el historico completo
 * de un mes (no solo lo nuevo de hoy) sin re-tocar lo que ya quedo bien.
 *
 * Si el CSV trae mas de un cheque para la misma orden ACH (mismo
 * SM_ACH_Order__c), todos se actualizan igual, pero repartidos en OLEADAS
 * (una llamada Database.update() por oleada, 1 registro por orden ACH por
 * oleada) para que SM_PaymentHandler (trigger AfterUpdate) nunca vea la
 * misma orden ACH dos veces en el mismo DML -- eso es lo que dispara
 * "Duplicate id in list" y tumba el batch completo.
 *
 * Cada vez que un Payment SI cambia (no para los que se saltan por ya
 * estar aplicados), se antepone una marca al campo
 * SM_Historical_Collection_Status__c: "PRC_AUT: <STATUS> //" + lo que ya
 * habia (se conserva el historico, nunca se pisa). El campo es Text(150),
 * asi que si no alcanza se trunca desde el final (se pierde el historico
 * mas viejo, se conserva siempre lo mas reciente).
 */

// ============ CONFIGURACION ============
Boolean DRY_RUN = true; // <-- cambiar a false para ejecutar el update real
String STATIC_RESOURCE_NAME = 'CheckCollectionImport';
Integer HISTORICAL_MAX_LENGTH = 150; // Text(150) -- SM_Historical_Collection_Status__c
// ========================================

System.debug(' -> ======================================================');
System.debug(' -> MODO: ' + (DRY_RUN ? 'DRY RUN (solo preview, sin cambios)' : 'EJECUCION REAL (se va a actualizar)'));
System.debug(' -> ======================================================');

// 1) Leer el Static Resource (CSV generado por el script Python)
StaticResource sr = [
    SELECT Body
    FROM StaticResource
    WHERE Name = :STATIC_RESOURCE_NAME
    LIMIT 1
];
String csvBody = sr.Body.toString();

// 2) Parsear el CSV (sin comas dentro de los valores, asi que split simple es seguro)
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
    String newHistorical;
}

List<RowData> rows = new List<RowData>();
Set<String> paymentNames = new Set<String>();
List<String> malformedRows = new List<String>();

for (Integer i = 1; i < lines.size(); i++) {
    if (String.isBlank(lines[i])) { continue; }
    List<String> cols = lines[i].split(',');

    // Una fila con un valor que no parsea (ej. fecha vacia -- caso raro de
    // extraccion en el PDF de origen) no debe tumbar el batch completo: se
    // salta y se reporta, no se aborta la ejecucion.
    try {
        RowData r = new RowData();
        r.paymentName = cols[idxPaymentName].trim();
        r.status      = cols[idxStatus].trim();
        r.collDate    = Date.valueOf(cols[idxCollDate].trim());
        r.coll        = Boolean.valueOf(cols[idxColl].trim());
        r.collStatus  = cols[idxCollStatus].trim();

        rows.add(r);
        paymentNames.add(r.paymentName);
    } catch (Exception ex) {
        String badName = cols.size() > idxPaymentName ? cols[idxPaymentName].trim() : '(fila ' + i + ')';
        malformedRows.add(badName + ' (' + ex.getMessage() + ')');
    }
}

System.debug(' -> Total filas leidas del CSV: ' + rows.size());

// 3) Buscar los registros SM_Payment__c que hagan match por Name (trayendo
// tambien el estado ACTUAL de los campos que vamos a actualizar, para poder
// comparar contra el target del CSV).
Map<String, SM_Payment__c> paymentByName = new Map<String, SM_Payment__c>();
for (SM_Payment__c p : [
    SELECT Id, Name, SM_ACH_Order__c, Payment_Status__c, SM_Check_Collection_Date__c,
           SM_Check_Collection__c, SM_Check_Collection_Status__c, SM_Historical_Collection_Status__c,
           LastModifiedDate
    FROM SM_Payment__c
    WHERE Name IN :paymentNames
]) {
    paymentByName.put(p.Name, p);
}

// 4) Separar: sin match / ya aplicado (no necesita cambios) / bloqueado por
// regresion (COLLECTED/ACCEPTED -> NOT COLLECTED, nunca automatico) /
// superado por un evento mas reciente (se salta) / pendiente de aplicar
List<RowData> matchedRows = new List<RowData>();
List<RowData> alreadyAppliedRows = new List<RowData>();
List<RowData> supersededRows = new List<RowData>();
List<RowData> regressionBlockedRows = new List<RowData>();
List<String> notFound = new List<String>();

for (RowData r : rows) {
    SM_Payment__c match = paymentByName.get(r.paymentName);
    if (match == null) {
        notFound.add(r.paymentName);
        continue;
    }
    r.matchedPaymentId = match.Id;
    r.achOrderId = match.SM_ACH_Order__c;

    Boolean alreadyApplied =
        match.Payment_Status__c == r.status &&
        match.SM_Check_Collection_Date__c == r.collDate &&
        match.SM_Check_Collection__c == r.coll &&
        match.SM_Check_Collection_Status__c == r.collStatus;

    if (alreadyApplied) {
        alreadyAppliedRows.add(r);
        continue;
    }

    // Un pago que ya esta COLLECTED/ACCEPTED nunca se revierte
    // automaticamente a RETURN/NOT COLLECTED -- sin importar fechas, eso
    // siempre queda para revision manual (regla de negocio explicita).
    // EXCEPCION: si ese COLLECTED/ACCEPTED viene de
    // mark_transmitted_accepted.apex (marca "...D_SIN_REPORTE:" al frente
    // del historico -- ver ese script), no es un cobro confirmado por el
    // banco, es solo una aceptacion por defecto tras N dias sin reporte.
    // Los reportes de Returns/Collection SIEMPRE priman sobre esa
    // aceptacion por defecto, asi que en ese caso SI se deja corregir.
    String latestHistoricalTag = match.SM_Historical_Collection_Status__c == null
        ? '' : match.SM_Historical_Collection_Status__c.split('//', 2)[0];
    Boolean acceptedByTimeoutRoutine = latestHistoricalTag.contains('D_SIN_REPORTE:');

    Boolean isCurrentlySuccess =
        (match.Payment_Status__c == 'ACCEPTED' || match.SM_Check_Collection_Status__c == 'COLLECTED')
        && !acceptedByTimeoutRoutine;
    Boolean isTargetRegression = r.collStatus == 'RETURN' || r.collStatus == 'NOT COLLECTED';

    if (isCurrentlySuccess && isTargetRegression) {
        regressionBlockedRows.add(r);
        continue;
    }

    // Si Salesforce se modifico DESPUES de la fecha de este reporte, es muy
    // probable que haya un evento mas reciente (ej. otro Check Collection o
    // un Return posterior) -- no se revierte, se salta para revision
    // manual en vez de pisar el estado actual a ciegas.
    Boolean supersededByNewerEvent =
        match.LastModifiedDate != null && match.LastModifiedDate.date() > r.collDate;

    if (supersededByNewerEvent) {
        supersededRows.add(r);
    } else {
        String tag = 'PRC_AUT: ' + r.collStatus.replace(' ', '_') + ' //';
        String previousHistorical = match.SM_Historical_Collection_Status__c == null ? '' : match.SM_Historical_Collection_Status__c;
        String newHistorical = tag + previousHistorical;
        if (newHistorical.length() > HISTORICAL_MAX_LENGTH) {
            newHistorical = newHistorical.substring(0, HISTORICAL_MAX_LENGTH);
        }
        r.newHistorical = newHistorical;
        matchedRows.add(r);
    }
}

// 4b) Agrupar en OLEADAS por SM_ACH_Order__c (ver nota al inicio del archivo).
Map<Id, Integer> waveByAchOrder = new Map<Id, Integer>();
Map<Integer, List<RowData>> waves = new Map<Integer, List<RowData>>();
Integer maxWave = 0;

for (RowData r : matchedRows) {
    Integer wave = 0;
    if (r.achOrderId != null) {
        wave = waveByAchOrder.containsKey(r.achOrderId) ? waveByAchOrder.get(r.achOrderId) + 1 : 0;
        waveByAchOrder.put(r.achOrderId, wave);
    }
    if (wave > maxWave) { maxWave = wave; }
    if (!waves.containsKey(wave)) { waves.put(wave, new List<RowData>()); }
    waves.get(wave).add(r);
}

// 5) Preview (solo lo que realmente se va a tocar, en el orden original del CSV)
for (RowData r : matchedRows) {
    System.debug(
        'PREVIEW -> ' + r.paymentName +
        ' | Payment_Status__c: ' + r.status +
        ' | SM_Check_Collection_Date__c: ' + r.collDate +
        ' | SM_Check_Collection__c: ' + r.coll +
        ' | SM_Check_Collection_Status__c: ' + r.collStatus +
        ' | SM_Historical_Collection_Status__c -> [' + r.newHistorical + ']'
    );
}

System.debug(' -> ======================================================');
System.debug(' -> Total filas del CSV: ' + (rows.size() + malformedRows.size()));
if (!malformedRows.isEmpty()) {
    System.debug(' -> Filas MALFORMADAS (se saltan, revisar el PDF de origen): ' + malformedRows.size());
    System.debug(' ->   -> ' + malformedRows);
}
System.debug(' -> Registros SIN match (PY-XXXX no existe como Payment): ' + notFound.size());
if (!notFound.isEmpty()) {
    System.debug(' ->   -> Nombres no encontrados: ' + notFound);
}
System.debug(' -> Ya aplicados anteriormente (sin cambios, se omiten): ' + alreadyAppliedRows.size());
if (!regressionBlockedRows.isEmpty()) {
    List<String> regressionNames = new List<String>();
    for (RowData r : regressionBlockedRows) { regressionNames.add(r.paymentName); }
    System.debug(' -> ***** ALERTA: ' + regressionBlockedRows.size() + ' pago(s) ya COLLECTED/ACCEPTED que este reporte queria pasar a RETURN/NOT COLLECTED -- NO SE APLICARON, ANALIZAR MANUALMENTE *****');
    System.debug(' ->   -> Nombres bloqueados por regresion: ' + regressionNames);
} else {
    System.debug(' -> Bloqueados por regresion (COLLECTED/ACCEPTED -> RETURN/NOT COLLECTED, nunca automatico): 0');
}
System.debug(' -> Superados por un evento mas reciente en Salesforce (se saltan, revisar manualmente): ' + supersededRows.size());
if (!supersededRows.isEmpty()) {
    List<String> supersededNames = new List<String>();
    for (RowData r : supersededRows) { supersededNames.add(r.paymentName); }
    System.debug(' ->   -> Nombres saltados: ' + supersededNames);
}
System.debug(' -> Pendientes de aplicar en esta corrida: ' + matchedRows.size());
System.debug(' -> Oleadas necesarias por colisiones de orden ACH repetida: ' + (matchedRows.isEmpty() ? 0 : (maxWave + 1)));
for (Integer w = 0; w <= maxWave && !matchedRows.isEmpty(); w++) {
    System.debug(' ->   -> Oleada ' + (w + 1) + ': ' + waves.get(w).size() + ' registro(s)');
}
System.debug(' -> ======================================================');

// 6) Ejecutar el update SOLO si DRY_RUN = false -- una oleada a la vez
if (!DRY_RUN) {
    if (matchedRows.isEmpty()) {
        System.debug(' -> No hay registros pendientes de aplicar.');
    } else {
        Integer totalOk = 0;
        Integer totalErr = 0;
        for (Integer w = 0; w <= maxWave; w++) {
            List<RowData> waveRows = waves.get(w);
            List<SM_Payment__c> waveUpdate = new List<SM_Payment__c>();
            for (RowData r : waveRows) {
                waveUpdate.add(new SM_Payment__c(
                    Id = r.matchedPaymentId,
                    Payment_Status__c = r.status,
                    SM_Check_Collection_Date__c = r.collDate,
                    SM_Check_Collection__c = r.coll,
                    SM_Check_Collection_Status__c = r.collStatus,
                    SM_Historical_Collection_Status__c = r.newHistorical
                ));
            }
            List<Database.SaveResult> results = Database.update(waveUpdate, false);
            Integer okCount = 0;
            Integer errCount = 0;
            for (Integer i = 0; i < results.size(); i++) {
                Database.SaveResult res = results[i];
                if (res.isSuccess()) {
                    okCount++;
                } else {
                    errCount++;
                    System.debug(
                        'ERROR actualizando ' + waveUpdate[i].Id + ': ' +
                        res.getErrors()[0].getMessage()
                    );
                }
            }
            System.debug(' ->   -> Oleada ' + (w + 1) + ' completada -> Exitos: ' + okCount + ' | Errores: ' + errCount);
            totalOk += okCount;
            totalErr += errCount;
        }
        System.debug(' -> ======================================================');
        System.debug(' -> UPDATE COMPLETADO -> Exitos: ' + totalOk + ' | Errores: ' + totalErr);
        System.debug(' -> ======================================================');
    }
} else {
    System.debug(' -> DRY RUN activo: no se ejecuto ningun UPDATE. Cambia DRY_RUN a false para aplicar los cambios.');
}
