/*
 * fix_final_batch_chunk6.apex
 * Lote 7 del fix final combinado (T1 restante + T2 sin Grupo A +
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
    new TargetState('PY-01798638', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01798667', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01800759', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01800783', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01801790', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01804503', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01804520', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01804531', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01804543', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01804546', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01804550', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01804558', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01804561', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01804569', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01804571', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01804583', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01806512', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01806531', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01806544', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01806546', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01806746', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01807443', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01807463', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01807464', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01807470', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01807481', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01807482', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01807484', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01807485', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01807486', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01807492', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01809138', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01809188', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01809191', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01809192', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01809196', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01809201', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01809204', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01809206', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01810014', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01810027', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01810042', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01810057', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01810069', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01810073', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01810087', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01810105', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01810115', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01810153', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01810158', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01810159', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01810168', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01810179', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01810190', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01810199', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01810201', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01810209', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01810225', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01810237', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01810243', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01810252', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01810264', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01810269', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01810280', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01810291', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01810292', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01812401', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01812411', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01812653', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01813487', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01813508', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01813509', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01813519', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01813520', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01813521', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01813522', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01815188', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01815189', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01815190', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01815238', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01815303', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01815304', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01815305', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01815306', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01816053', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01816055', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01816058', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01816075', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01816079', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01816081', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01816084', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01816085', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01816087', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01816096', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01816097', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01816098', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01816102', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01816105', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01816106', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01816107', 'ACCEPTED', 'COLLECTED')
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
System.debug(' -> LOTE 7 -> MODO: ' + (DRY_RUN ? 'DRY RUN' : 'EJECUCION REAL'));
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
System.debug(' -> LOTE 7 -> Saltados (no elegible): ' + skippedNotEligible);
System.debug(' -> LOTE 7 -> Saltados (ya coincidian): ' + skippedAlreadyOk);
System.debug(' -> LOTE 7 -> Total a actualizar: ' + toUpdate.size());
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
    System.debug(' -> LOTE 7 -> UPDATE COMPLETADO. Exitosos: ' + okCount + ' / ' + toUpdate.size());
} else {
    System.debug(' -> LOTE 7 -> DRY RUN: no se realizo ningun cambio.');
}
