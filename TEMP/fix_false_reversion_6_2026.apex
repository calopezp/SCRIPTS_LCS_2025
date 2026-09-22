/*
 * fix_false_reversion_6_2026.apex
 * ----------------------------------
 * Restaura 6 payments a ACCEPTED/COLLECTED. Encontrados al validar,
 * via SM_Payment__History (Field='Payment_Status__c'), una reversion
 * ACCEPTED->REJECTED sin ningun reporte real posterior que la
 * justifique -- el mismo patron confirmado ya para los 15 de Tier 1
 * (catch-up del 2026-09-09, incidente ya documentado en CLAUDE.md
 * seccion 2.2 como origen de la Rule 2), pero estos 6 no aparecian en
 * el indice local de reportes (gap del indice, no de los datos reales
 * de Salesforce) asi que no se detectaron en el analisis original.
 *
 * PY-01779105 (00311264): ACCEPTED/COLLECTED 2026-01-26 -> REJECTED/PENDING 2026-09-09, sin causa
 * PY-01778054 (00309301): idem
 * PY-01776680 (00315429): idem
 * PY-01776759 (00315676): idem
 * PY-01778067 (00312779): idem
 * PY-01804492 (00311449): ACCEPTED/COLLECTED 2026-04-13 (tras un vaiven previo ya resuelto) -> REJECTED/PENDING 2026-09-09, sin causa
 *
 * Verificado: los otros 15 payments con reversion ACCEPTED->REJECTED
 * del mismo cruce NO se tocan -- su ultimo valor real antes de la
 * reversion era NOT_COLLECTED (ya cubierto por Tier 2/Rule 3) o el
 * ACCEPTED que se revirtio venia del timeout de 15 dias sin reporte
 * real (correctamente corregido despues).
 *
 * Corre primero con DRY_RUN = true -> solo preview, NO actualiza nada.
 */

Boolean DRY_RUN = false; // Autorizado por el usuario 2026-09-22: reversion falsa ACCEPTED->REJECTED confirmada via SM_Payment__History (preview 6/6 sin saltos)

Set<String> targetNames = new Set<String>{
    'PY-01779105','PY-01778054','PY-01776680','PY-01776759','PY-01778067','PY-01804492'
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
    if (p.Payment_Status__c.equals('ACCEPTED') && p.SM_Check_Collection_Status__c.equals('COLLECTED')) {
        System.debug(' -> ***** SALTADO (ya coincide exactamente): ' + p.Name);
        continue;
    }

    String tag = 'PRC_AUT: COLLECTED //';
    String previous = p.SM_Historical_Collection_Status__c == null ? '' : p.SM_Historical_Collection_Status__c;
    String newHistorical = tag + previous;
    if (newHistorical.length() > 150) {
        newHistorical = newHistorical.substring(0, 150);
    }

    System.debug(
        'PREVIEW -> ' + p.Name + ' (Contrato ' + p.SM_Contract__r.ContractNumber + ', Status ' + p.SM_Contract__r.Status + ')' +
        ' | Payment_Status__c: ' + p.Payment_Status__c + ' -> ACCEPTED' +
        ' | SM_Check_Collection_Status__c: ' + p.SM_Check_Collection_Status__c + ' -> COLLECTED' +
        ' | SM_Check_Collection_Date__c (sin cambio): ' + p.SM_Check_Collection_Date__c +
        ' | Historico -> [' + newHistorical + ']'
    );

    p.Payment_Status__c = 'ACCEPTED';
    p.SM_Check_Collection_Status__c = 'COLLECTED';
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
