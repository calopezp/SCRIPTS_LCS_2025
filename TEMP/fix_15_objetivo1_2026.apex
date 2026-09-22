/*
 * fix_15_objetivo1_2026.apex
 * -----------------------------
 * Corrige los 15 payments identificados en la validacion fresca de ACH
 * 2026 (Objetivo 1): PENDING/RETURN, mas de 26 dias desde la
 * transmision, sin ningun reporte de Check Collection que confirme
 * COLLECTED pendiente de aplicar -> Rule 3 (CLAUDE.md 2.2).
 *
 * Validado antes de este fix (mismo dia): 0 anomalias, todos
 * Activated, ninguno Test/VIP, ninguno cambio desde el reporte. Se
 * verifico ademas la Late Payment Fee asociada (7 de 15 tienen una: 6
 * Stopped, 1 Completed) -- no se toca ninguna orden aqui, solo el
 * payment original.
 *
 * Sin triggers/handlers (SM_TriggerHandler.avoidAllHandlerExcecution).
 * Corre primero con DRY_RUN = true -> solo preview, NO actualiza nada.
 */

Boolean DRY_RUN = false; // Autorizado 2026-09-22: 15 candidatos Objetivo 1, preview validado

Set<String> targetNames = new Set<String>{
    'PY-01804536','PY-01807462','PY-01807474','PY-01807476','PY-01849469',
    'PY-01859726','PY-01865165','PY-01872218','PY-01880352','PY-01880378',
    'PY-01880427','PY-01883331','PY-01884599','PY-01884645','PY-01884692'
};

List<SM_Payment__c> payments = [
    SELECT Id, Name, Payment_Status__c, SM_Check_Collection__c, SM_Check_Collection_Date__c,
           SM_Check_Collection_Status__c, SM_Return_code__c, SM_Historical_Collection_Status__c,
           SM_Contract__r.ContractNumber, SM_Contract__r.Status, SM_Contract__r.Is_Test_Contract__c,
           SM_Contract__r.Is_VIP_Contract__c
    FROM SM_Payment__c
    WHERE Name IN :targetNames
];

System.debug('=======================================================');
System.debug(' -> MODO: ' + (DRY_RUN ? 'DRY RUN (solo preview, sin cambios)' : 'EJECUCION REAL'));
System.debug(' -> Payments encontrados: ' + payments.size() + ' (esperados: ' + targetNames.size() + ')');
System.debug('=======================================================');

List<SM_Payment__c> toUpdate = new List<SM_Payment__c>();

for (SM_Payment__c p : payments) {
    if (p.SM_Contract__r == null || p.SM_Contract__r.Status == 'Cancelled') {
        System.debug(' -> ***** SALTADO (contrato ya Cancelled, revisar aparte): ' + p.Name);
        continue;
    }
    if (p.SM_Contract__r.Is_Test_Contract__c == true || p.SM_Contract__r.Is_VIP_Contract__c == true) {
        System.debug(' -> ***** SALTADO (Test/VIP): ' + p.Name);
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
        ' | Payment_Status__c (sin cambio): ' + p.Payment_Status__c +
        ' | SM_Check_Collection_Status__c: ' + p.SM_Check_Collection_Status__c + ' -> NOT_COLLECTED' +
        ' | Historico -> [' + newHistorical + ']'
    );

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
