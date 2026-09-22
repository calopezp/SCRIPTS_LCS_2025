/*
 * fix_final_batch_chunk12.apex
 * Lote 13 del fix final combinado (T1 restante + T2 sin Grupo A +
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
    new TargetState('PY-01867088', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01867270', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01867680', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01867684', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01867688', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01868511', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01868514', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01868538', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01870659', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01870688', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01870708', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01870712', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01870716', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01870742', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01871233', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01871235', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01871242', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01871243', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01872270', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01874902', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01874904', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01874908', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01874913', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01874917', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01874919', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01876054', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01876055', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01876062', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01880925', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01880957', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01880961', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01880962', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01880969', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01880971', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01880975', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01880983', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01880984', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01880987', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01881013', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01881017', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01881039', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01881045', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01881046', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01881047', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01887688', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01888263', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01888280', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01888795', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01888810', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01888812', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01888833', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01888835', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01888987', 'REJECTED', 'PENDING'),
    new TargetState('PY-01889019', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01889023', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01889026', 'REJECTED', 'PENDING'),
    new TargetState('PY-01889028', 'REJECTED', 'PENDING'),
    new TargetState('PY-01889034', 'REJECTED', 'PENDING'),
    new TargetState('PY-01889046', 'REJECTED', 'PENDING'),
    new TargetState('PY-01889050', 'REJECTED', 'PENDING'),
    new TargetState('PY-01889057', 'REJECTED', 'PENDING'),
    new TargetState('PY-01889058', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01889059', 'REJECTED', 'PENDING'),
    new TargetState('PY-01889077', 'REJECTED', 'PENDING'),
    new TargetState('PY-01889087', 'REJECTED', 'PENDING'),
    new TargetState('PY-01889098', 'REJECTED', 'PENDING'),
    new TargetState('PY-01889111', 'REJECTED', 'PENDING'),
    new TargetState('PY-01889113', 'REJECTED', 'PENDING'),
    new TargetState('PY-01889120', 'REJECTED', 'PENDING'),
    new TargetState('PY-01889145', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01889152', 'REJECTED', 'PENDING'),
    new TargetState('PY-01889156', 'REJECTED', 'PENDING'),
    new TargetState('PY-01889157', 'REJECTED', 'PENDING'),
    new TargetState('PY-01889162', 'REJECTED', 'PENDING'),
    new TargetState('PY-01889167', 'REJECTED', 'PENDING'),
    new TargetState('PY-01889182', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01889184', 'REJECTED', 'PENDING'),
    new TargetState('PY-01889185', 'REJECTED', 'PENDING'),
    new TargetState('PY-01889186', 'REJECTED', 'PENDING'),
    new TargetState('PY-01889188', 'REJECTED', 'PENDING'),
    new TargetState('PY-01889192', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01889208', 'REJECTED', 'PENDING'),
    new TargetState('PY-01889211', 'REJECTED', 'PENDING'),
    new TargetState('PY-01889233', 'REJECTED', 'PENDING'),
    new TargetState('PY-01889235', 'REJECTED', 'PENDING'),
    new TargetState('PY-01889249', 'REJECTED', 'PENDING'),
    new TargetState('PY-01889253', 'REJECTED', 'PENDING'),
    new TargetState('PY-01889257', 'REJECTED', 'PENDING'),
    new TargetState('PY-01889258', 'REJECTED', 'PENDING'),
    new TargetState('PY-01889259', 'REJECTED', 'PENDING'),
    new TargetState('PY-01889260', 'REJECTED', 'PENDING'),
    new TargetState('PY-01889261', 'REJECTED', 'PENDING'),
    new TargetState('PY-01889262', 'REJECTED', 'PENDING'),
    new TargetState('PY-01890501', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01890502', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01890504', 'REJECTED', 'PENDING'),
    new TargetState('PY-01890505', 'REJECTED', 'PENDING'),
    new TargetState('PY-01890513', 'REJECTED', 'PENDING'),
    new TargetState('PY-01890515', 'REJECTED', 'PENDING'),
    new TargetState('PY-01890516', 'REJECTED', 'PENDING')
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
System.debug(' -> LOTE 13 -> MODO: ' + (DRY_RUN ? 'DRY RUN' : 'EJECUCION REAL'));
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
System.debug(' -> LOTE 13 -> Saltados (no elegible): ' + skippedNotEligible);
System.debug(' -> LOTE 13 -> Saltados (ya coincidian): ' + skippedAlreadyOk);
System.debug(' -> LOTE 13 -> Total a actualizar: ' + toUpdate.size());
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
    System.debug(' -> LOTE 13 -> UPDATE COMPLETADO. Exitosos: ' + okCount + ' / ' + toUpdate.size());
} else {
    System.debug(' -> LOTE 13 -> DRY RUN: no se realizo ningun cambio.');
}
