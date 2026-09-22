/*
 * fix_final_batch_chunk9.apex
 * Lote 10 del fix final combinado (T1 restante + T2 sin Grupo A +
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
    new TargetState('PY-01834196', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01834198', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01834200', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01834204', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01834207', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01834210', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01834212', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01834213', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01834214', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01834215', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01834216', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01834218', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01834220', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01834223', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01834229', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01835545', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01836828', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01836835', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01836989', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01837000', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01837007', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01837009', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01837010', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01837205', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01837209', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01838197', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01838199', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01838202', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01838209', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01838217', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01838219', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01838220', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01838221', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01838227', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01838233', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01838243', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01839299', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01839305', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01840483', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01840493', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01840494', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01840496', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01840611', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01840616', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01840620', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01840713', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01840722', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01840724', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01841617', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01841621', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01841624', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01841627', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01841630', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01841648', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01841654', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01841655', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01841658', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01841666', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01841668', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01841675', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01841676', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01842081', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01842089', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01842090', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01842098', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01842104', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01842128', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01842132', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01842143', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01842146', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01842147', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01842151', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01842157', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01842161', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01842174', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01842180', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01842181', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01842185', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01842186', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01842190', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01842191', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01842195', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01842207', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01842208', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01842222', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01842227', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01842230', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01842231', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01842242', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01842251', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01842254', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01842268', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01843598', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01843601', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01843605', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01845219', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01845228', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01845230', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01845231', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01845235', 'ACCEPTED', 'COLLECTED')
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
System.debug(' -> LOTE 10 -> MODO: ' + (DRY_RUN ? 'DRY RUN' : 'EJECUCION REAL'));
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
System.debug(' -> LOTE 10 -> Saltados (no elegible): ' + skippedNotEligible);
System.debug(' -> LOTE 10 -> Saltados (ya coincidian): ' + skippedAlreadyOk);
System.debug(' -> LOTE 10 -> Total a actualizar: ' + toUpdate.size());
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
    System.debug(' -> LOTE 10 -> UPDATE COMPLETADO. Exitosos: ' + okCount + ' / ' + toUpdate.size());
} else {
    System.debug(' -> LOTE 10 -> DRY RUN: no se realizo ningun cambio.');
}
