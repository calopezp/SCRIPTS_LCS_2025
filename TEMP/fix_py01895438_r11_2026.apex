/*
 * fix_py01895438_r11_2026.apex
 * -----------------------------
 * PY-01895438 (contrato 00317809, Activated): llego a ACCEPTED/COLLECTED
 * genuino el 2026-09-21, pero el mismo dia aparece tambien en
 * ACHReturnsReport_09212026.pdf con codigo R11 (ENTRY NOT PER
 * AUTHORIZATION TERMS -- misma familia de disputa del cliente que R10).
 *
 * Confirmado por Carlos 2026-09-23: R10/R11 siempre ganan, sin importar
 * el estado anterior -- se revierte a NOT_COLLECTED y se reporta. Mismo
 * tratamiento aplicado antes a PY-01895410 (R10).
 *
 * Sin triggers/handlers (SM_TriggerHandler.avoidAllHandlerExcecution).
 * PAYMENT_Accumulate_AC_On_Contract (Flow nativo) no aplica aqui -- solo
 * dispara cuando el NUEVO valor es ACCEPTED, y aqui vamos en direccion
 * contraria.
 */

Boolean DRY_RUN = false; // Autorizado 2026-09-23: "aplica el cambio al py-01895438" -- preview validado

SM_Payment__c p = [
    SELECT Id, Name, Payment_Status__c, SM_Check_Collection__c, SM_Check_Collection_Date__c,
           SM_Check_Collection_Status__c, SM_Return_code__c, SM_Historical_Collection_Status__c,
           SM_Contract__r.ContractNumber, SM_Contract__r.Status, SM_Contract__r.Is_Test_Contract__c,
           SM_Contract__r.Is_VIP_Contract__c
    FROM SM_Payment__c
    WHERE Name = 'PY-01895438'
    LIMIT 1
];

System.debug('=======================================================');
System.debug(' -> MODO: ' + (DRY_RUN ? 'DRY RUN (solo preview, sin cambios)' : 'EJECUCION REAL'));
System.debug(' -> Estado actual: ' + p.Payment_Status__c + '/' + p.SM_Check_Collection_Status__c +
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
        ' | Return code -> R11 | Fecha coleccion -> 2026-09-21' +
        ' | Historico -> [' + newHistorical + ']'
    );

    if (!DRY_RUN) {
        SM_TriggerHandler.avoidAllHandlerExcecution = true;
        p.Payment_Status__c = 'REJECTED';
        p.SM_Check_Collection_Status__c = 'NOT_COLLECTED';
        p.SM_Check_Collection__c = true;
        p.SM_Check_Collection_Date__c = Date.newInstance(2026, 9, 21);
        p.SM_Return_code__c = 'R11';
        p.SM_Historical_Collection_Status__c = newHistorical;
        update p;
        SM_TriggerHandler.avoidAllHandlerExcecution = false;
        System.debug(' -> UPDATE COMPLETADO.');
    } else {
        System.debug(' -> DRY RUN: no se realizo ningun cambio. Cambiar DRY_RUN a false para aplicar.');
    }
}
