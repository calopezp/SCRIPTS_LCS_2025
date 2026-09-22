/*
 * fix_t3_cancelled_00315208.apex
 * ---------------------------------
 * Resuelve 4 de los 12 payments de Tier 3 (genuinamente contradictorios)
 * -- todos del contrato 00315208, ya Cancelled. Instruccion explicita
 * del usuario 2026-09-22: en contratos ya Cancelled, aplicar la
 * determinacion del reporte real sin mas analisis (no afecta cobranza
 * activa en este momento).
 *
 * Los 4 estaban ACCEPTED/COLLECTED, pero un reporte real de Check
 * Collection (Check Collections Feb 19 2026.pdf) dice REJECTED/
 * NOT_COLLECTED para cada uno (fechas de transaccion ene-2026).
 *
 * Sin triggers/handlers (SM_TriggerHandler.avoidAllHandlerExcecution).
 * Corre primero con DRY_RUN = true -> solo preview, NO actualiza nada.
 */

Boolean DRY_RUN = false; // Autorizado 2026-09-22: contrato Cancelled, no afecta cobranza activa

Set<String> targetNames = new Set<String>{
    'PY-01776683','PY-01776756','PY-01776774','PY-01782501'
};

List<SM_Payment__c> payments = [
    SELECT Id, Name, Payment_Status__c, SM_Check_Collection__c, SM_Check_Collection_Date__c,
           SM_Check_Collection_Status__c, SM_Return_code__c, SM_Historical_Collection_Status__c,
           SM_Contract__r.ContractNumber, SM_Contract__r.Status
    FROM SM_Payment__c
    WHERE Name IN :targetNames
];

System.debug('=======================================================');
System.debug(' -> MODO: ' + (DRY_RUN ? 'DRY RUN (solo preview, sin cambios)' : 'EJECUCION REAL'));
System.debug(' -> Payments encontrados: ' + payments.size() + ' (esperados: ' + targetNames.size() + ')');
System.debug('=======================================================');

List<SM_Payment__c> toUpdate = new List<SM_Payment__c>();

for (SM_Payment__c p : payments) {
    if (p.SM_Contract__r == null || p.SM_Contract__r.Status != 'Cancelled') {
        System.debug(' -> ***** SALTADO (el contrato ya no esta Cancelled, revisar aparte): ' + p.Name);
        continue;
    }
    if (p.Payment_Status__c.equals('REJECTED') && p.SM_Check_Collection_Status__c.equals('NOT_COLLECTED')) {
        System.debug(' -> ***** SALTADO (ya coincide exactamente): ' + p.Name);
        continue;
    }

    String tag = 'PRC_AUT: NOT_COLLECTED //';
    String previous = p.SM_Historical_Collection_Status__c == null ? '' : p.SM_Historical_Collection_Status__c;
    String newHistorical = tag + previous;
    if (newHistorical.length() > 150) {
        newHistorical = newHistorical.substring(0, 150);
    }

    System.debug(
        'PREVIEW -> ' + p.Name + ' (Contrato ' + p.SM_Contract__r.ContractNumber + ')' +
        ' | Payment_Status__c: ' + p.Payment_Status__c + ' -> REJECTED' +
        ' | SM_Check_Collection_Status__c: ' + p.SM_Check_Collection_Status__c + ' -> NOT_COLLECTED' +
        ' | Historico -> [' + newHistorical + ']'
    );

    p.Payment_Status__c = 'REJECTED';
    p.SM_Check_Collection_Status__c = 'NOT_COLLECTED';
    p.SM_Check_Collection__c = true;
    p.SM_Historical_Collection_Status__c = newHistorical;
    toUpdate.add(p);
}

System.debug('=======================================================');
System.debug(' -> Total a actualizar: ' + toUpdate.size());
System.debug('=======================================================');

if (!DRY_RUN) {
    SM_TriggerHandler.avoidAllHandlerExcecution = true;
    Database.SaveResult[] results = Database.update(toUpdate, false);
    SM_TriggerHandler.avoidAllHandlerExcecution = false;

    Integer okCount = 0;
    for (Integer i = 0; i < results.size(); i++) {
        if (results[i].isSuccess()) {
            okCount++;
        } else {
            System.debug(' -> ***** ERROR actualizando ' + toUpdate[i].Name + ': ' + results[i].getErrors());
        }
    }
    System.debug(' -> UPDATE COMPLETADO. Exitosos: ' + okCount + ' / ' + toUpdate.size());
} else {
    System.debug(' -> DRY RUN: no se realizo ningun cambio. Cambiar DRY_RUN a false para aplicar.');
}
