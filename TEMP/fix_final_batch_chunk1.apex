/*
 * fix_final_batch_chunk1.apex
 * Lote 2 del fix final combinado (T1 restante + T2 sin Grupo A +
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
    new TargetState('PY-01841629', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01842115', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01842158', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01842176', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01842192', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01842200', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01842262', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01843592', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01846486', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01847633', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01847638', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01847644', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01847656', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01848919', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01849466', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01849472', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01850055', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01850071', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01850086', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01850087', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01852535', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01852552', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01852563', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01852570', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01852574', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01852599', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01852601', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01853981', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01853983', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01853991', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01854807', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01854810', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01856300', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01857151', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01857160', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01857165', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01857189', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01857190', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01857196', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01857953', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01859481', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01859505', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01859548', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01859558', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01859566', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01859582', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01859590', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01859626', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01859646', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01859663', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01859671', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01859702', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01861578', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01861601', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01865453', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01866151', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01866274', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01866279', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01866286', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01866293', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01866297', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01866322', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01866323', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01866338', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01866371', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01867071', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01867080', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01867082', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01867089', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01867092', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01867096', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01867675', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01868517', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01868518', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01868521', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01868527', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01868540', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01868816', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01869468', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01869470', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01869476', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01869477', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01870667', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01870696', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01870697', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01870701', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01870707', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01872163', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01872166', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01872167', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01872178', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01872181', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01872189', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01872190', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01872196', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01872201', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01872202', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01872205', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01872211', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01872216', 'REJECTED', 'NOT_COLLECTED')
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
System.debug(' -> LOTE 2 -> MODO: ' + (DRY_RUN ? 'DRY RUN' : 'EJECUCION REAL'));
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
System.debug(' -> LOTE 2 -> Saltados (no elegible): ' + skippedNotEligible);
System.debug(' -> LOTE 2 -> Saltados (ya coincidian): ' + skippedAlreadyOk);
System.debug(' -> LOTE 2 -> Total a actualizar: ' + toUpdate.size());
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
    System.debug(' -> LOTE 2 -> UPDATE COMPLETADO. Exitosos: ' + okCount + ' / ' + toUpdate.size());
} else {
    System.debug(' -> LOTE 2 -> DRY RUN: no se realizo ningun cambio.');
}
