/*
 * fix_final_batch_chunk4.apex
 * Lote 5 del fix final combinado (T1 restante + T2 sin Grupo A +
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
    new TargetState('PY-01884594', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01884595', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01884598', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01884601', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01884602', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01884604', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01884608', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01884609', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01884610', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01884611', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01884612', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01884613', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01884614', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01884615', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01884617', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01884619', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01884621', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01884623', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01884624', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01884625', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01884626', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01884627', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01884629', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01884630', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01884631', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01884634', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01884635', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01884638', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01884639', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01884641', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01884642', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01884643', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01884646', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01884647', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01884649', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01884651', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01884653', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01884655', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01884656', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01884657', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01884661', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01884662', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01884663', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01884664', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01884665', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01884666', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01884667', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01884668', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01884669', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01884671', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01884672', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01884673', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01884674', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01884678', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01884679', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01884683', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01884684', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01884685', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01884686', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01884687', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01884688', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01884689', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01884691', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01884695', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01884696', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01884698', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01884699', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01884700', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01884701', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01884704', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01884706', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01884707', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01884709', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01884710', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01884712', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01884715', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01884717', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01884718', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01884725', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01884726', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01884729', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01884739', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01884740', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01885196', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01885197', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01885212', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01885215', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01885218', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01885221', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01885222', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01885223', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01885225', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01885226', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01885227', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01885230', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01885233', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01885972', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01885974', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01885975', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01885976', 'REJECTED', 'NOT_COLLECTED')
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
System.debug(' -> LOTE 5 -> MODO: ' + (DRY_RUN ? 'DRY RUN' : 'EJECUCION REAL'));
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
System.debug(' -> LOTE 5 -> Saltados (no elegible): ' + skippedNotEligible);
System.debug(' -> LOTE 5 -> Saltados (ya coincidian): ' + skippedAlreadyOk);
System.debug(' -> LOTE 5 -> Total a actualizar: ' + toUpdate.size());
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
    System.debug(' -> LOTE 5 -> UPDATE COMPLETADO. Exitosos: ' + okCount + ' / ' + toUpdate.size());
} else {
    System.debug(' -> LOTE 5 -> DRY RUN: no se realizo ningun cambio.');
}
