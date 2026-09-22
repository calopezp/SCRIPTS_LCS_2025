/*
 * fix_final_batch_chunk10.apex
 * Lote 11 del fix final combinado (T1 restante + T2 sin Grupo A +
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
    new TargetState('PY-01845243', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01845245', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01845247', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01845250', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01845251', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01845254', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01845410', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01845411', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01845420', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01845425', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01845696', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01846484', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01846489', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01846494', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01846497', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01847647', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01847652', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01847654', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01847655', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01847657', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01848916', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01849206', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01849462', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01849463', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01849464', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01849471', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01850054', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01850061', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01850062', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01850072', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01850076', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01850088', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01850093', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01850097', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01850098', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01851032', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01852527', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01852534', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01852537', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01852540', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01852542', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01852544', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01852546', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01852551', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01852554', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01852555', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01852558', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01852561', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01852567', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01852568', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01852571', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01852580', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01852582', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01852587', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01852593', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01852594', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01852595', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01852598', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01852600', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01852606', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01852609', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01852616', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01852617', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01852619', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01852622', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01852626', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01852631', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01852632', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01852635', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01852954', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01852968', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01853256', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01853259', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01853261', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01853947', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01853955', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01853958', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01853961', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01853965', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01853972', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01853978', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01853979', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01853984', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01853987', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01853992', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01853994', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01854804', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01854808', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01854815', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01855217', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01855950', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01855953', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01855955', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01856504', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01856506', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01856508', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01857156', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01857157', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01857179', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01857182', 'ACCEPTED', 'COLLECTED')
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
System.debug(' -> LOTE 11 -> MODO: ' + (DRY_RUN ? 'DRY RUN' : 'EJECUCION REAL'));
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
System.debug(' -> LOTE 11 -> Saltados (no elegible): ' + skippedNotEligible);
System.debug(' -> LOTE 11 -> Saltados (ya coincidian): ' + skippedAlreadyOk);
System.debug(' -> LOTE 11 -> Total a actualizar: ' + toUpdate.size());
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
    System.debug(' -> LOTE 11 -> UPDATE COMPLETADO. Exitosos: ' + okCount + ' / ' + toUpdate.size());
} else {
    System.debug(' -> LOTE 11 -> DRY RUN: no se realizo ningun cambio.');
}
