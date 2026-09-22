/*
 * fix_final_batch_chunk14.apex
 * Lote 15 del fix final combinado (T1 restante + T2 sin Grupo A +
 * T5 solo formato + T8 sub-estado menor), validacion 2026-09-22.
 * Ver TEMP/validacion_payments_2026_2026-09-22.csv para el detalle
 * completo de cada Tier.
 *
 * Corre primero con DRY_RUN = true -> solo preview, NO actualiza nada.
 */

Boolean DRY_RUN = false; // Autorizado por el usuario 2026-09-22 (T1+T2 sin Grupo A+T5+T8, preview validado)

class TargetState {
    String name;
    String paymentStatus;
    String collectionStatus;
    TargetState(String name, String paymentStatus, String collectionStatus) {
        this.name = name;
        this.paymentStatus = paymentStatus;
        this.collectionStatus = collectionStatus;
    }
}

List<TargetState> targets = new List<TargetState>{
    new TargetState('PY-01899241', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01899247', 'REJECTED', 'PENDING'),
    new TargetState('PY-01899250', 'REJECTED', 'PENDING'),
    new TargetState('PY-01899255', 'REJECTED', 'PENDING'),
    new TargetState('PY-01899909', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01899910', 'REJECTED', 'PENDING'),
    new TargetState('PY-01899911', 'REJECTED', 'PENDING'),
    new TargetState('PY-01899914', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01899916', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01899922', 'REJECTED', 'PENDING'),
    new TargetState('PY-01900422', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01900425', 'REJECTED', 'PENDING'),
    new TargetState('PY-01900426', 'REJECTED', 'PENDING'),
    new TargetState('PY-01900427', 'REJECTED', 'PENDING'),
    new TargetState('PY-01900428', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01900430', 'REJECTED', 'PENDING'),
    new TargetState('PY-01900433', 'REJECTED', 'PENDING'),
    new TargetState('PY-01900437', 'REJECTED', 'PENDING'),
    new TargetState('PY-01900438', 'REJECTED', 'PENDING'),
    new TargetState('PY-01900439', 'REJECTED', 'PENDING'),
    new TargetState('PY-01900441', 'REJECTED', 'PENDING'),
    new TargetState('PY-01900442', 'REJECTED', 'PENDING'),
    new TargetState('PY-01900444', 'REJECTED', 'PENDING'),
    new TargetState('PY-01900447', 'REJECTED', 'PENDING'),
    new TargetState('PY-01900452', 'REJECTED', 'PENDING'),
    new TargetState('PY-01900454', 'REJECTED', 'PENDING'),
    new TargetState('PY-01901099', 'REJECTED', 'PENDING'),
    new TargetState('PY-01901100', 'REJECTED', 'PENDING'),
    new TargetState('PY-01901105', 'REJECTED', 'PENDING'),
    new TargetState('PY-01901107', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01901108', 'REJECTED', 'PENDING'),
    new TargetState('PY-01901110', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01901114', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01901115', 'REJECTED', 'PENDING'),
    new TargetState('PY-01901116', 'REJECTED', 'PENDING'),
    new TargetState('PY-01901119', 'REJECTED', 'PENDING'),
    new TargetState('PY-01901123', 'REJECTED', 'PENDING'),
    new TargetState('PY-01901127', 'REJECTED', 'PENDING'),
    new TargetState('PY-01902573', 'REJECTED', 'PENDING'),
    new TargetState('PY-01902575', 'REJECTED', 'PENDING'),
    new TargetState('PY-01902582', 'REJECTED', 'PENDING'),
    new TargetState('PY-01902584', 'REJECTED', 'PENDING'),
    new TargetState('PY-01902586', 'REJECTED', 'PENDING'),
    new TargetState('PY-01902588', 'REJECTED', 'PENDING'),
    new TargetState('PY-01902589', 'REJECTED', 'PENDING'),
    new TargetState('PY-01902590', 'REJECTED', 'PENDING'),
    new TargetState('PY-01902592', 'REJECTED', 'PENDING'),
    new TargetState('PY-01902593', 'REJECTED', 'PENDING'),
    new TargetState('PY-01902594', 'REJECTED', 'PENDING'),
    new TargetState('PY-01902595', 'REJECTED', 'PENDING'),
    new TargetState('PY-01902598', 'REJECTED', 'PENDING'),
    new TargetState('PY-01902602', 'REJECTED', 'PENDING'),
    new TargetState('PY-01902605', 'REJECTED', 'PENDING'),
    new TargetState('PY-01902611', 'REJECTED', 'PENDING'),
    new TargetState('PY-01902613', 'REJECTED', 'PENDING'),
    new TargetState('PY-01902615', 'REJECTED', 'PENDING'),
    new TargetState('PY-01902621', 'REJECTED', 'PENDING'),
    new TargetState('PY-01902623', 'REJECTED', 'PENDING'),
    new TargetState('PY-01902626', 'REJECTED', 'PENDING'),
    new TargetState('PY-01902627', 'REJECTED', 'PENDING'),
    new TargetState('PY-01902628', 'REJECTED', 'PENDING'),
    new TargetState('PY-01902629', 'REJECTED', 'PENDING'),
    new TargetState('PY-01902631', 'REJECTED', 'PENDING'),
    new TargetState('PY-01902633', 'REJECTED', 'PENDING'),
    new TargetState('PY-01902634', 'REJECTED', 'PENDING'),
    new TargetState('PY-01902635', 'REJECTED', 'PENDING'),
    new TargetState('PY-01902637', 'REJECTED', 'PENDING'),
    new TargetState('PY-01902645', 'REJECTED', 'PENDING'),
    new TargetState('PY-01902648', 'REJECTED', 'PENDING'),
    new TargetState('PY-01902651', 'REJECTED', 'PENDING'),
    new TargetState('PY-01902657', 'REJECTED', 'PENDING'),
    new TargetState('PY-01902658', 'REJECTED', 'PENDING'),
    new TargetState('PY-01902659', 'REJECTED', 'PENDING'),
    new TargetState('PY-01902660', 'REJECTED', 'PENDING'),
    new TargetState('PY-01902662', 'REJECTED', 'PENDING'),
    new TargetState('PY-01902664', 'REJECTED', 'PENDING'),
    new TargetState('PY-01902666', 'REJECTED', 'PENDING'),
    new TargetState('PY-01902669', 'REJECTED', 'PENDING'),
    new TargetState('PY-01902670', 'REJECTED', 'PENDING'),
    new TargetState('PY-01902672', 'REJECTED', 'PENDING'),
    new TargetState('PY-01902673', 'REJECTED', 'PENDING'),
    new TargetState('PY-01902674', 'REJECTED', 'PENDING'),
    new TargetState('PY-01902678', 'REJECTED', 'PENDING'),
    new TargetState('PY-01902680', 'REJECTED', 'PENDING'),
    new TargetState('PY-01902681', 'REJECTED', 'PENDING'),
    new TargetState('PY-01902685', 'REJECTED', 'PENDING'),
    new TargetState('PY-01902686', 'REJECTED', 'PENDING'),
    new TargetState('PY-01902687', 'REJECTED', 'PENDING'),
    new TargetState('PY-01902695', 'REJECTED', 'PENDING'),
    new TargetState('PY-01902696', 'REJECTED', 'PENDING'),
    new TargetState('PY-01902699', 'REJECTED', 'PENDING'),
    new TargetState('PY-01902700', 'REJECTED', 'PENDING'),
    new TargetState('PY-01902701', 'REJECTED', 'PENDING'),
    new TargetState('PY-01902702', 'REJECTED', 'PENDING'),
    new TargetState('PY-01902704', 'REJECTED', 'PENDING'),
    new TargetState('PY-01903618', 'REJECTED', 'PENDING'),
    new TargetState('PY-01903619', 'REJECTED', 'PENDING'),
    new TargetState('PY-01903626', 'REJECTED', 'PENDING'),
    new TargetState('PY-01773063', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01773993', 'REJECTED', 'NOT_COLLECTED')
};

Map<String, TargetState> targetByName = new Map<String, TargetState>();
for (TargetState t : targets) {
    targetByName.put(t.name, t);
}

List<SM_Payment__c> payments = [
    SELECT Id, Name, Payment_Status__c, SM_Check_Collection__c, SM_Check_Collection_Date__c,
           SM_Check_Collection_Status__c, SM_Return_code__c, SM_Historical_Collection_Status__c,
           SM_Contract__r.ContractNumber, SM_Contract__r.Status, SM_Contract__r.Is_Test_Contract__c,
           SM_Contract__r.Is_VIP_Contract__c
    FROM SM_Payment__c
    WHERE Name IN :targetByName.keySet()
];

System.debug('=======================================================');
System.debug(' -> LOTE 15 -> MODO: ' + (DRY_RUN ? 'DRY RUN' : 'EJECUCION REAL'));
System.debug(' -> Payments encontrados: ' + payments.size() + ' (esperados: ' + targetByName.size() + ')');
System.debug('=======================================================');

List<SM_Payment__c> toUpdate = new List<SM_Payment__c>();
Integer skippedNotEligible = 0;
Integer skippedAlreadyOk = 0;

for (SM_Payment__c p : payments) {
    TargetState t = targetByName.get(p.Name);
    if (p.SM_Contract__r == null || p.SM_Contract__r.Status == 'Cancelled') {
        System.debug(' -> ***** SALTADO (contrato ya Cancelled, revisar aparte): ' + p.Name);
        skippedNotEligible++;
        continue;
    }
    if (p.SM_Contract__r.Is_Test_Contract__c == true || p.SM_Contract__r.Is_VIP_Contract__c == true) {
        System.debug(' -> ***** SALTADO (Test/VIP): ' + p.Name);
        skippedNotEligible++;
        continue;
    }
    if (p.Payment_Status__c.equals(t.paymentStatus) && p.SM_Check_Collection_Status__c.equals(t.collectionStatus)) {
        System.debug(' -> ***** SALTADO (ya coincide exactamente): ' + p.Name);
        skippedAlreadyOk++;
        continue;
    }

    String tag = 'PRC_AUT: ' + t.collectionStatus + ' //';
    String previous = p.SM_Historical_Collection_Status__c == null ? '' : p.SM_Historical_Collection_Status__c;
    String newHistorical = tag + previous;
    if (newHistorical.length() > 150) {
        newHistorical = newHistorical.substring(0, 150);
    }

    System.debug(
        'PREVIEW -> ' + p.Name + ' (Contrato ' + p.SM_Contract__r.ContractNumber + ')' +
        ' | Payment_Status__c: ' + p.Payment_Status__c + ' -> ' + t.paymentStatus +
        ' | SM_Check_Collection_Status__c: ' + p.SM_Check_Collection_Status__c + ' -> ' + t.collectionStatus +
        ' | Historico -> [' + newHistorical + ']'
    );

    p.Payment_Status__c = t.paymentStatus;
    p.SM_Check_Collection_Status__c = t.collectionStatus;
    p.SM_Check_Collection__c = true;
    p.SM_Historical_Collection_Status__c = newHistorical;
    toUpdate.add(p);
}

System.debug('=======================================================');
System.debug(' -> LOTE 15 -> Saltados (no elegible): ' + skippedNotEligible);
System.debug(' -> LOTE 15 -> Saltados (ya coincidian): ' + skippedAlreadyOk);
System.debug(' -> LOTE 15 -> Total a actualizar: ' + toUpdate.size());
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
    System.debug(' -> LOTE 15 -> UPDATE COMPLETADO. Exitosos: ' + okCount + ' / ' + toUpdate.size());
} else {
    System.debug(' -> LOTE 15 -> DRY RUN: no se realizo ningun cambio.');
}
