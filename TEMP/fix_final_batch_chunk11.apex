/*
 * fix_final_batch_chunk11.apex
 * Lote 12 del fix final combinado (T1 restante + T2 sin Grupo A +
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
    new TargetState('PY-01857184', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01857186', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01857192', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01857198', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01857955', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01859471', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01859475', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01859478', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01859479', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01859492', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01859494', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01859497', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01859514', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01859526', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01859536', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01859537', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01859546', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01859556', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01859562', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01859564', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01859571', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01859573', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01859576', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01859584', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01859585', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01859586', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01859596', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01859598', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01859605', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01859608', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01859611', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01859614', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01859618', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01859619', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01859621', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01859629', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01859630', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01859631', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01859634', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01859638', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01859639', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01859644', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01859656', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01859660', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01859661', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01859662', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01859667', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01859669', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01859672', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01859673', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01859683', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01859684', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01859685', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01859690', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01859693', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01859697', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01859707', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01859708', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01859713', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01859715', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01859725', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01859727', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01859728', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01859730', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01859733', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01859740', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01860309', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01860329', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01860332', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01860335', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01860336', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01860340', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01860346', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01860349', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01861579', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01861580', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01861590', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01861612', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01861623', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01861628', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01861631', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01863783', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01863787', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01863791', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01863792', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01864190', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01865132', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01865134', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01865176', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01865460', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01866140', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01866304', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01866306', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01866316', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01866318', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01866331', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01866333', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01866365', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01866366', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01866372', 'REJECTED', 'NOT_COLLECTED')
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
System.debug(' -> LOTE 12 -> MODO: ' + (DRY_RUN ? 'DRY RUN' : 'EJECUCION REAL'));
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
System.debug(' -> LOTE 12 -> Saltados (no elegible): ' + skippedNotEligible);
System.debug(' -> LOTE 12 -> Saltados (ya coincidian): ' + skippedAlreadyOk);
System.debug(' -> LOTE 12 -> Total a actualizar: ' + toUpdate.size());
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
    System.debug(' -> LOTE 12 -> UPDATE COMPLETADO. Exitosos: ' + okCount + ' / ' + toUpdate.size());
} else {
    System.debug(' -> LOTE 12 -> DRY RUN: no se realizo ningun cambio.');
}
