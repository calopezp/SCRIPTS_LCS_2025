/*
 * fix_final_batch_chunk8.apex
 * Lote 9 del fix final combinado (T1 restante + T2 sin Grupo A +
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
    new TargetState('PY-01824865', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01824871', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01824877', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01824879', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01824884', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01824898', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01824905', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01824913', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01824916', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01824923', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01824924', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01824926', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01824930', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01824944', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01824947', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01824950', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01824956', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01824959', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01824961', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01824972', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01824985', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01826312', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01826315', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01828901', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01828930', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01828935', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01828937', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01828939', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01828942', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01828945', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01829095', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01829101', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01829237', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01829240', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01830270', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01830272', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01830274', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01830275', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01830282', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01830283', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01830285', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01830294', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01830295', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01830296', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01830297', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01830298', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01830299', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01830304', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01830306', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01830307', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01830308', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01830311', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01832748', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01832754', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01832760', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01832779', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01832784', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01832785', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01832952', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01833152', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01833156', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01833157', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01834031', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01834049', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01834053', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01834055', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01834057', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01834066', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01834070', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01834071', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01834082', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01834085', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01834086', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01834098', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01834103', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01834107', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01834110', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01834114', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01834115', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01834121', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01834124', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01834127', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01834130', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01834131', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01834132', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01834148', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01834149', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01834154', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01834155', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01834159', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01834164', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01834169', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01834171', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01834172', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01834176', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01834177', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01834182', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01834183', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01834187', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01834191', 'ACCEPTED', 'COLLECTED')
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
System.debug(' -> LOTE 9 -> MODO: ' + (DRY_RUN ? 'DRY RUN' : 'EJECUCION REAL'));
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
System.debug(' -> LOTE 9 -> Saltados (no elegible): ' + skippedNotEligible);
System.debug(' -> LOTE 9 -> Saltados (ya coincidian): ' + skippedAlreadyOk);
System.debug(' -> LOTE 9 -> Total a actualizar: ' + toUpdate.size());
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
    System.debug(' -> LOTE 9 -> UPDATE COMPLETADO. Exitosos: ' + okCount + ' / ' + toUpdate.size());
} else {
    System.debug(' -> LOTE 9 -> DRY RUN: no se realizo ningun cambio.');
}
