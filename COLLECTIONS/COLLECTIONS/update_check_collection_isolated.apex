/*
 * update_check_collection_isolated.apex
 * --------------------------------------
 * Variante de update_check_collection.apex para AISLAR el bug de
 * SM_FeePaymentToDependentContract.cls (campo SM_Chargent_Orders_Transaction__c
 * ya no existe -- ver HANDOFF_91_CONTRATOS_AGOSTO.md seccion 7A, 2026-09-10).
 *
 * Diferencia con el original: en vez de agrupar en oleadas por
 * SM_ACH_Order__c (varios registros por Database.update()), aca CADA
 * Payment se actualiza en su PROPIO Database.update() de 1 solo registro.
 * Asi, si el trigger AfterUpdate truena para uno (el que dispara el bug de
 * Chargent), SOLO ese Database.update() falla -- no arrastra a los demas
 * como paso con las oleadas de 36 registros.
 *
 * Usa el mismo StaticResource ya desplegado (CheckCollectionImport, 50
 * filas -- 14 ya aplicadas se van a saltar solas por el chequeo
 * "alreadyApplied", asi que esto solo toca las 36 pendientes).
 *
 * MODO DE USO: igual que el original -- DRY_RUN = true primero, revisar,
 * luego false para aplicar.
 */

// ============ CONFIGURACION ============
Boolean DRY_RUN = true; // <-- cambiar a false para ejecutar el update real
String STATIC_RESOURCE_NAME = 'CheckCollectionImport';
Integer HISTORICAL_MAX_LENGTH = 150;
// El limite de gobernador (100 SOQL queries por ejecucion) es acumulativo
// para TODO el script, no por Database.update() -- con ~3 queries por
// registro (via el trigger AfterUpdate), 36 en una sola corrida lo supera
// ("Too many SOQL queries: 101", confirmado 2026-09-10 -- rollback limpio,
// nada quedo a medias). Procesar en lotes chicos: correr el script varias
// veces seguidas: los ya aplicados se saltan solos (already applied), asi
// que cada corrida avanza sobre lo que falte.
Integer MAX_TO_PROCESS = 12;
// ========================================

System.debug(' -> ======================================================');
System.debug(' -> MODO: ' + (DRY_RUN ? 'DRY RUN (solo preview, sin cambios)' : 'EJECUCION REAL AISLADA (1 registro por DML)'));
System.debug(' -> ======================================================');

StaticResource sr = [SELECT Body FROM StaticResource WHERE Name = :STATIC_RESOURCE_NAME LIMIT 1];
String csvBody = sr.Body.toString();

List<String> lines = csvBody.split('\r\n');
if (lines.size() == 1) {
    lines = csvBody.split('\n');
}

List<String> headers = lines[0].split(',');
Integer idxPaymentName = headers.indexOf('Payment_Name');
Integer idxStatus      = headers.indexOf('Payment_Status__c');
Integer idxCollDate    = headers.indexOf('SM_Check_Collection_Date__c');
Integer idxColl        = headers.indexOf('SM_Check_Collection__c');
Integer idxCollStatus  = headers.indexOf('SM_Check_Collection_Status__c');
Integer idxReason      = headers.indexOf('Reason');

Set<String> VALID_RETURN_CODES = new Set<String>{
    'R01','R02','R03','R04','R05','R06','R07','R08','R09','R10','R11','R12','R13','R14',
    'R15','R16','R17','R20','R21','R22','R23','R24','R29','R31',
    'N01','N02','N03','N04','N05','N06','N07','N08','N09','N10','N11','N12','N13','N14','N15','N16','N17',
    'C01','C02','C03','C04','C05','C06','C07','C09','C10','C11','C12'
};

class RowData {
    String paymentName;
    String status;
    Date collDate;
    Boolean coll;
    String collStatus;
    String reasonShort;
    String returnCode;
    Id matchedPaymentId;
    String contractNumber;
    String newHistorical;
}

List<RowData> rows = new List<RowData>();
Set<String> paymentNames = new Set<String>();

for (Integer i = 1; i < lines.size(); i++) {
    if (String.isBlank(lines[i])) { continue; }
    List<String> cols = lines[i].split(',');
    try {
        RowData r = new RowData();
        r.paymentName = cols[idxPaymentName].trim();
        r.status      = cols[idxStatus].trim();
        r.collDate    = Date.valueOf(cols[idxCollDate].trim());
        r.coll        = Boolean.valueOf(cols[idxColl].trim());
        r.collStatus  = cols[idxCollStatus].trim();
        String rawReason = (idxReason >= 0 && cols.size() > idxReason) ? cols[idxReason].trim() : '';
        String firstToken = rawReason.split(' ')[0];
        Boolean looksLikeCode = Pattern.matches('^[A-Z]\\d{2}$', firstToken);
        r.reasonShort = looksLikeCode ? firstToken : rawReason;
        r.returnCode = (looksLikeCode && VALID_RETURN_CODES.contains(firstToken)) ? firstToken : null;
        rows.add(r);
        paymentNames.add(r.paymentName);
    } catch (Exception ex) {
        // fila malformada -- se salta, no aborta el resto
    }
}

System.debug(' -> Total filas leidas del CSV: ' + rows.size());

Map<String, SM_Payment__c> paymentByName = new Map<String, SM_Payment__c>();
for (SM_Payment__c p : [
    SELECT Id, Name, SM_ACH_Order__c, Payment_Status__c, SM_Check_Collection_Date__c,
           SM_Check_Collection__c, SM_Check_Collection_Status__c, SM_Historical_Collection_Status__c,
           SM_Check_Collection_Return_Reason__c, SM_Return_code__c,
           SM_Contract__r.ContractNumber, SM_Contract__r.Status
    FROM SM_Payment__c
    WHERE Name IN :paymentNames
]) {
    paymentByName.put(p.Name, p);
}

List<RowData> matchedRows = new List<RowData>();
Integer alreadyAppliedCount = 0;
Integer notFoundCount = 0;

for (RowData r : rows) {
    SM_Payment__c match = paymentByName.get(r.paymentName);
    if (match == null) {
        notFoundCount++;
        continue;
    }
    r.matchedPaymentId = match.Id;
    r.contractNumber = match.SM_Contract__r != null ? match.SM_Contract__r.ContractNumber : null;

    Boolean alreadyApplied =
        match.Payment_Status__c == r.status &&
        match.SM_Check_Collection_Date__c == r.collDate &&
        match.SM_Check_Collection__c == r.coll &&
        match.SM_Check_Collection_Status__c == r.collStatus &&
        match.SM_Check_Collection_Return_Reason__c == r.reasonShort &&
        match.SM_Return_code__c == r.returnCode;

    if (alreadyApplied) {
        alreadyAppliedCount++;
        continue;
    }

    // Mismos guards que el script original: regresion y contrato Cancelado.
    // No repito el guard de contrato Cancelado con "hermano transmitido"
    // aca porque ya se resolvio en la corrida anterior (0 bloqueados); si
    // reaparece, se detecta como ERROR individual abajo, sin arrastrar a
    // nadie mas (justamente el punto de este script).
    Boolean isCurrentlySuccess = (match.Payment_Status__c == 'ACCEPTED' || match.SM_Check_Collection_Status__c == 'COLLECTED');
    Boolean isTargetRegression = r.collStatus == 'RETURN' || r.collStatus == 'NOT_COLLECTED' || r.collStatus == 'NOT COLLECTED' || r.collStatus == 'PENDING';
    if (isCurrentlySuccess && isTargetRegression) {
        System.debug(' -> SALTADO por guard de regresion: ' + r.paymentName);
        continue;
    }

    String tag = 'PRC_AUT: ' + r.collStatus.replace(' ', '_') + ' //';
    String previousHistorical = match.SM_Historical_Collection_Status__c == null ? '' : match.SM_Historical_Collection_Status__c;
    String newHistorical = tag + previousHistorical;
    if (newHistorical.length() > HISTORICAL_MAX_LENGTH) {
        newHistorical = newHistorical.substring(0, HISTORICAL_MAX_LENGTH);
    }
    r.newHistorical = newHistorical;
    matchedRows.add(r);
}

System.debug(' -> Ya aplicados (se saltan): ' + alreadyAppliedCount);
System.debug(' -> Sin match: ' + notFoundCount);
System.debug(' -> Pendientes de aplicar en total: ' + matchedRows.size());

List<RowData> toProcess = new List<RowData>();
for (Integer i = 0; i < matchedRows.size() && i < MAX_TO_PROCESS; i++) {
    toProcess.add(matchedRows[i]);
}
System.debug(' -> Procesando en esta corrida (MAX_TO_PROCESS=' + MAX_TO_PROCESS + '): ' + toProcess.size());
System.debug(' -> Quedaran para la proxima corrida: ' + (matchedRows.size() - toProcess.size()));

for (RowData r : toProcess) {
    System.debug('PREVIEW -> ' + r.paymentName + ' (' + r.contractNumber + ') | target: ' + r.status + '/' + r.collStatus);
}

if (!DRY_RUN) {
    Integer okCount = 0;
    Integer errCount = 0;
    List<String> failedNames = new List<String>();
    List<String> failedContracts = new List<String>();

    for (RowData r : toProcess) {
        SM_Payment__c toUpdate = new SM_Payment__c(
            Id = r.matchedPaymentId,
            Payment_Status__c = r.status,
            SM_Check_Collection_Date__c = r.collDate,
            SM_Check_Collection__c = r.coll,
            SM_Check_Collection_Status__c = r.collStatus,
            SM_Check_Collection_Return_Reason__c = r.reasonShort,
            SM_Return_code__c = r.returnCode,
            SM_Historical_Collection_Status__c = r.newHistorical
        );
        try {
            Database.SaveResult res = Database.update(toUpdate, false);
            if (res.isSuccess()) {
                okCount++;
            } else {
                errCount++;
                failedNames.add(r.paymentName);
                failedContracts.add(r.contractNumber);
                System.debug(' -> ERROR (SaveResult) ' + r.paymentName + ' (' + r.contractNumber + '): ' + res.getErrors()[0].getMessage());
            }
        } catch (Exception ex) {
            errCount++;
            failedNames.add(r.paymentName);
            failedContracts.add(r.contractNumber);
            System.debug(' -> ERROR (excepcion) ' + r.paymentName + ' (' + r.contractNumber + '): ' + ex.getMessage());
        }
    }

    System.debug(' -> ======================================================');
    System.debug(' -> UPDATE AISLADO COMPLETADO -> Exitos: ' + okCount + ' | Errores: ' + errCount);
    if (!failedNames.isEmpty()) {
        System.debug(' -> Pagos que fallaron individualmente: ' + failedNames);
        System.debug(' -> Contratos de los pagos que fallaron: ' + failedContracts);
    }
    System.debug(' -> ======================================================');
} else {
    System.debug(' -> DRY RUN activo: no se ejecuto ningun UPDATE.');
}
