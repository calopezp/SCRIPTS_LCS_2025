/*
 * fix_final_batch_chunk3.apex
 * Lote 4 del fix final combinado (T1 restante + T2 sin Grupo A +
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
    new TargetState('PY-01879513', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01879514', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01879515', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01879516', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01879521', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01879522', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01879523', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01880293', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01880295', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01880297', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01880298', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01880304', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01880307', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01880311', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01880312', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01880316', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01880322', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01880323', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01880329', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01880333', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01880348', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01880349', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01880353', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01880355', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01880359', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01880360', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01880361', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01880375', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01880377', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01880382', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01880383', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01880386', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01880388', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01880389', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01880390', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01880395', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01880397', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01880400', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01880401', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01880403', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01880404', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01880405', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01880406', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01880407', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01880411', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01880414', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01880415', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01880417', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01880419', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01880420', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01880421', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01880423', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01880426', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01880917', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01880923', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01880928', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01880934', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01880943', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01880948', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01880955', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01880967', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01880972', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01880973', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01880974', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01880978', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01880991', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01880995', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01881015', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01881021', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01881033', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01881040', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01881042', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01883326', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01883328', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01883334', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01883344', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01883947', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01883948', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01883949', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01883950', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01883961', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01884561', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01884564', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01884565', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01884567', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01884568', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01884569', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01884571', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01884573', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01884575', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01884576', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01884577', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01884578', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01884580', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01884582', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01884584', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01884585', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01884591', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01884592', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01884593', 'REJECTED', 'NOT_COLLECTED')
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
System.debug(' -> LOTE 4 -> MODO: ' + (DRY_RUN ? 'DRY RUN' : 'EJECUCION REAL'));
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
System.debug(' -> LOTE 4 -> Saltados (no elegible): ' + skippedNotEligible);
System.debug(' -> LOTE 4 -> Saltados (ya coincidian): ' + skippedAlreadyOk);
System.debug(' -> LOTE 4 -> Total a actualizar: ' + toUpdate.size());
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
    System.debug(' -> LOTE 4 -> UPDATE COMPLETADO. Exitosos: ' + okCount + ' / ' + toUpdate.size());
} else {
    System.debug(' -> LOTE 4 -> DRY RUN: no se realizo ningun cambio.');
}
