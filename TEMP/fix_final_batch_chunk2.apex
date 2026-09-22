/*
 * fix_final_batch_chunk2.apex
 * Lote 3 del fix final combinado (T1 restante + T2 sin Grupo A +
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
    new TargetState('PY-01872217', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01872219', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01872220', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01872223', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01872225', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01872226', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01872227', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01872228', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01872230', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01872231', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01872232', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01872233', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01872235', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01872245', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01872271', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01872278', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01872783', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01872793', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01872794', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01872802', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01872803', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01872805', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01872816', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01872832', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01872838', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01872841', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01872846', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01872847', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01872856', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01872860', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01872865', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01872866', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01872869', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01872873', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01872875', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01872878', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01872880', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01872882', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01872889', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01872891', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01872892', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01872893', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01872895', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01872897', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01872903', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01872907', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01872915', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01872916', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01872922', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01872924', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01872929', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01872933', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01872937', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01872939', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01872940', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01872953', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01872956', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01872961', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01872963', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01872964', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01873013', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01874735', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01874911', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01875555', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01876051', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01876058', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01876063', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01876065', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01876637', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01876639', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01876640', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01876645', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01877137', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01877138', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01877139', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01877144', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01877145', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01877147', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01877150', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01877151', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01877949', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01877952', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01877953', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01877955', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01877956', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01877966', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01877969', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01877970', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01877978', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01877980', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01877982', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01877983', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01877984', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01877985', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01877986', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01877987', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01877989', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01877990', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01877994', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01879511', 'REJECTED', 'NOT_COLLECTED')
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
System.debug(' -> LOTE 3 -> MODO: ' + (DRY_RUN ? 'DRY RUN' : 'EJECUCION REAL'));
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
System.debug(' -> LOTE 3 -> Saltados (no elegible): ' + skippedNotEligible);
System.debug(' -> LOTE 3 -> Saltados (ya coincidian): ' + skippedAlreadyOk);
System.debug(' -> LOTE 3 -> Total a actualizar: ' + toUpdate.size());
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
    System.debug(' -> LOTE 3 -> UPDATE COMPLETADO. Exitosos: ' + okCount + ' / ' + toUpdate.size());
} else {
    System.debug(' -> LOTE 3 -> DRY RUN: no se realizo ningun cambio.');
}
