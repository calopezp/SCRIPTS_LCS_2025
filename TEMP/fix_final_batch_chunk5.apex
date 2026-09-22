/*
 * fix_final_batch_chunk5.apex
 * Lote 6 del fix final combinado (T1 restante + T2 sin Grupo A +
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
    new TargetState('PY-01885977', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01885980', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01885981', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01887667', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01887671', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01887672', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01887681', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01887689', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01887704', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01887710', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01888265', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01888272', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01888273', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01888276', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01888281', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01888793', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01888802', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01888803', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01888806', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01888808', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01888825', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01888826', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01888829', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01888831', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01773990', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01774862', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01776676', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01776677', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01776772', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01778049', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01778122', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01780216', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01780265', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01781565', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01784733', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01785851', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01785855', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01785903', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01785936', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01785968', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01786002', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01786011', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01786054', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01786068', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01787493', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01789005', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01789012', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01791983', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01791985', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01791988', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01791990', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01791997', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01791998', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01792003', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01792788', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01792798', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01792801', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01792807', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01792813', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01792816', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01792840', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01792843', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01792878', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01792879', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01792882', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01792901', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01792905', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01792909', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01793841', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01793842', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01793851', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01793853', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01793861', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01794702', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01794704', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01794706', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01794709', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01794972', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01795676', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01795683', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01795699', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01796677', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01797723', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01798385', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01798416', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01798427', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01798433', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01798436', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01798445', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01798449', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01798492', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01798531', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01798535', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01798570', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01798580', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01798597', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01798598', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01798603', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01798608', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01798631', 'ACCEPTED', 'COLLECTED')
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
System.debug(' -> LOTE 6 -> MODO: ' + (DRY_RUN ? 'DRY RUN' : 'EJECUCION REAL'));
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
System.debug(' -> LOTE 6 -> Saltados (no elegible): ' + skippedNotEligible);
System.debug(' -> LOTE 6 -> Saltados (ya coincidian): ' + skippedAlreadyOk);
System.debug(' -> LOTE 6 -> Total a actualizar: ' + toUpdate.size());
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
    System.debug(' -> LOTE 6 -> UPDATE COMPLETADO. Exitosos: ' + okCount + ' / ' + toUpdate.size());
} else {
    System.debug(' -> LOTE 6 -> DRY RUN: no se realizo ningun cambio.');
}
