/*
 * fix_py01904884_r11_2026.apex
 * -----------------------------
 * PY-01904884 (contrato 00317117, Activated): SM_Return_code__c ya tiene
 * R11 aplicado (ACHReturnsReport_09212026.pdf), pero se quedo en el
 * estado transitorio RETURN -- solo 6 dias desde la transmision, ningun
 * proceso automatizado traduce todavia R10/R11 a NOT_COLLECTED de
 * inmediato. Confirmado por Carlos 2026-09-23: R10/R11 siempre ganan,
 * sin esperar los 26 dias -- se aplica NOT_COLLECTED de una vez.
 *
 * Sin triggers/handlers (SM_TriggerHandler.avoidAllHandlerExcecution).
 */

Boolean DRY_RUN = false; // Autorizado 2026-09-23: "aplica el cambio a py-01904884" -- preview validado

SM_Payment__c p = [
    SELECT Id, Name, Payment_Status__c, SM_Check_Collection__c, SM_Check_Collection_Date__c,
           SM_Check_Collection_Status__c, SM_Return_code__c, SM_Historical_Collection_Status__c,
           SM_Contract__r.ContractNumber, SM_Contract__r.Status, SM_Contract__r.Is_Test_Contract__c,
           SM_Contract__r.Is_VIP_Contract__c
    FROM SM_Payment__c
    WHERE Name = 'PY-01904884'
    LIMIT 1
];

System.debug('=======================================================');
System.debug(' -> MODO: ' + (DRY_RUN ? 'DRY RUN (solo preview, sin cambios)' : 'EJECUCION REAL'));
System.debug(' -> Estado actual: ' + p.Payment_Status__c + '/' + p.SM_Check_Collection_Status__c +
    ' | Return code: ' + p.SM_Return_code__c +
    ' | Contrato ' + p.SM_Contract__r.ContractNumber + ' (' + p.SM_Contract__r.Status + ')');
System.debug('=======================================================');

if (p.SM_Contract__r.Is_Test_Contract__c == true || p.SM_Contract__r.Is_VIP_Contract__c == true) {
    System.debug(' -> ***** SALTADO (Test/VIP)');
} else if (p.Payment_Status__c == 'REJECTED' && p.SM_Check_Collection_Status__c == 'NOT_COLLECTED') {
    System.debug(' -> ***** SALTADO (ya coincide exactamente)');
} else {
    String tag = 'PRC_AUT: NOT_COLLECTED //';
    String previous = p.SM_Historical_Collection_Status__c == null ? '' : p.SM_Historical_Collection_Status__c;
    String newHistorical = tag + previous;
    if (newHistorical.length() > 150) {
        newHistorical = newHistorical.substring(0, 150);
    }

    System.debug(
        'PREVIEW -> ' + p.Name +
        ' | ' + p.Payment_Status__c + '/' + p.SM_Check_Collection_Status__c + ' -> REJECTED/NOT_COLLECTED' +
        ' | Historico -> [' + newHistorical + ']'
    );

    if (!DRY_RUN) {
        SM_TriggerHandler.avoidAllHandlerExcecution = true;
        p.SM_Check_Collection_Status__c = 'NOT_COLLECTED';
        p.SM_Check_Collection__c = true;
        p.SM_Historical_Collection_Status__c = newHistorical;
        update p;
        SM_TriggerHandler.avoidAllHandlerExcecution = false;
        System.debug(' -> UPDATE COMPLETADO.');
    } else {
        System.debug(' -> DRY RUN: no se realizo ningun cambio. Cambiar DRY_RUN a false para aplicar.');
    }
}
