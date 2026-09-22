/*
 * fix_final_batch_chunk13.apex
 * Lote 14 del fix final combinado (T1 restante + T2 sin Grupo A +
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
    new TargetState('PY-01890517', 'REJECTED', 'PENDING'),
    new TargetState('PY-01890523', 'REJECTED', 'PENDING'),
    new TargetState('PY-01890524', 'REJECTED', 'PENDING'),
    new TargetState('PY-01890525', 'REJECTED', 'PENDING'),
    new TargetState('PY-01890527', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01890528', 'REJECTED', 'PENDING'),
    new TargetState('PY-01890531', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01890532', 'REJECTED', 'PENDING'),
    new TargetState('PY-01890536', 'REJECTED', 'PENDING'),
    new TargetState('PY-01890541', 'REJECTED', 'PENDING'),
    new TargetState('PY-01890543', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01890558', 'REJECTED', 'PENDING'),
    new TargetState('PY-01890562', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01890563', 'REJECTED', 'PENDING'),
    new TargetState('PY-01892870', 'REJECTED', 'PENDING'),
    new TargetState('PY-01892872', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01892874', 'REJECTED', 'PENDING'),
    new TargetState('PY-01892879', 'REJECTED', 'PENDING'),
    new TargetState('PY-01894033', 'REJECTED', 'PENDING'),
    new TargetState('PY-01894041', 'REJECTED', 'PENDING'),
    new TargetState('PY-01894042', 'REJECTED', 'PENDING'),
    new TargetState('PY-01894590', 'REJECTED', 'PENDING'),
    new TargetState('PY-01894595', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01894597', 'REJECTED', 'PENDING'),
    new TargetState('PY-01894616', 'REJECTED', 'PENDING'),
    new TargetState('PY-01894619', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01894630', 'REJECTED', 'PENDING'),
    new TargetState('PY-01894638', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01894641', 'REJECTED', 'PENDING'),
    new TargetState('PY-01895363', 'REJECTED', 'PENDING'),
    new TargetState('PY-01895365', 'REJECTED', 'PENDING'),
    new TargetState('PY-01895377', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01895380', 'REJECTED', 'PENDING'),
    new TargetState('PY-01895384', 'REJECTED', 'PENDING'),
    new TargetState('PY-01895396', 'REJECTED', 'PENDING'),
    new TargetState('PY-01895397', 'REJECTED', 'PENDING'),
    new TargetState('PY-01895415', 'REJECTED', 'PENDING'),
    new TargetState('PY-01895478', 'REJECTED', 'PENDING'),
    new TargetState('PY-01895479', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01895480', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01895481', 'REJECTED', 'PENDING'),
    new TargetState('PY-01895483', 'REJECTED', 'PENDING'),
    new TargetState('PY-01896064', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01899114', 'REJECTED', 'PENDING'),
    new TargetState('PY-01899121', 'REJECTED', 'PENDING'),
    new TargetState('PY-01899126', 'REJECTED', 'PENDING'),
    new TargetState('PY-01899129', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01899132', 'REJECTED', 'PENDING'),
    new TargetState('PY-01899134', 'REJECTED', 'PENDING'),
    new TargetState('PY-01899135', 'REJECTED', 'PENDING'),
    new TargetState('PY-01899138', 'REJECTED', 'PENDING'),
    new TargetState('PY-01899140', 'REJECTED', 'PENDING'),
    new TargetState('PY-01899143', 'REJECTED', 'PENDING'),
    new TargetState('PY-01899144', 'REJECTED', 'PENDING'),
    new TargetState('PY-01899155', 'REJECTED', 'PENDING'),
    new TargetState('PY-01899163', 'REJECTED', 'PENDING'),
    new TargetState('PY-01899164', 'REJECTED', 'PENDING'),
    new TargetState('PY-01899165', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01899166', 'REJECTED', 'PENDING'),
    new TargetState('PY-01899168', 'REJECTED', 'PENDING'),
    new TargetState('PY-01899169', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01899170', 'REJECTED', 'PENDING'),
    new TargetState('PY-01899171', 'REJECTED', 'PENDING'),
    new TargetState('PY-01899172', 'REJECTED', 'PENDING'),
    new TargetState('PY-01899173', 'REJECTED', 'PENDING'),
    new TargetState('PY-01899174', 'REJECTED', 'PENDING'),
    new TargetState('PY-01899175', 'REJECTED', 'PENDING'),
    new TargetState('PY-01899176', 'REJECTED', 'PENDING'),
    new TargetState('PY-01899177', 'REJECTED', 'PENDING'),
    new TargetState('PY-01899180', 'REJECTED', 'PENDING'),
    new TargetState('PY-01899186', 'REJECTED', 'PENDING'),
    new TargetState('PY-01899188', 'REJECTED', 'PENDING'),
    new TargetState('PY-01899189', 'REJECTED', 'PENDING'),
    new TargetState('PY-01899191', 'REJECTED', 'PENDING'),
    new TargetState('PY-01899192', 'REJECTED', 'PENDING'),
    new TargetState('PY-01899194', 'REJECTED', 'PENDING'),
    new TargetState('PY-01899197', 'REJECTED', 'PENDING'),
    new TargetState('PY-01899200', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01899201', 'REJECTED', 'PENDING'),
    new TargetState('PY-01899202', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01899203', 'REJECTED', 'PENDING'),
    new TargetState('PY-01899204', 'REJECTED', 'PENDING'),
    new TargetState('PY-01899205', 'REJECTED', 'PENDING'),
    new TargetState('PY-01899206', 'REJECTED', 'PENDING'),
    new TargetState('PY-01899208', 'REJECTED', 'PENDING'),
    new TargetState('PY-01899209', 'REJECTED', 'PENDING'),
    new TargetState('PY-01899210', 'REJECTED', 'PENDING'),
    new TargetState('PY-01899211', 'REJECTED', 'PENDING'),
    new TargetState('PY-01899212', 'REJECTED', 'PENDING'),
    new TargetState('PY-01899213', 'REJECTED', 'PENDING'),
    new TargetState('PY-01899214', 'REJECTED', 'PENDING'),
    new TargetState('PY-01899215', 'REJECTED', 'PENDING'),
    new TargetState('PY-01899218', 'REJECTED', 'PENDING'),
    new TargetState('PY-01899228', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01899229', 'REJECTED', 'PENDING'),
    new TargetState('PY-01899230', 'REJECTED', 'PENDING'),
    new TargetState('PY-01899237', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01899238', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01899239', 'REJECTED', 'PENDING'),
    new TargetState('PY-01899240', 'REJECTED', 'NOT_COLLECTED')
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
System.debug(' -> LOTE 14 -> MODO: ' + (DRY_RUN ? 'DRY RUN' : 'EJECUCION REAL'));
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
System.debug(' -> LOTE 14 -> Saltados (no elegible): ' + skippedNotEligible);
System.debug(' -> LOTE 14 -> Saltados (ya coincidian): ' + skippedAlreadyOk);
System.debug(' -> LOTE 14 -> Total a actualizar: ' + toUpdate.size());
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
    System.debug(' -> LOTE 14 -> UPDATE COMPLETADO. Exitosos: ' + okCount + ' / ' + toUpdate.size());
} else {
    System.debug(' -> LOTE 14 -> DRY RUN: no se realizo ningun cambio.');
}
