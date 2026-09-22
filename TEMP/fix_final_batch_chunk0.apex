/*
 * fix_final_batch_chunk0.apex
 * Lote 1 del fix final combinado (T1 restante + T2 sin Grupo A +
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
    new TargetState('PY-01773056', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01785857', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01785888', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01785908', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01785911', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01785922', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01785923', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01785967', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01785975', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01785980', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01785995', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01787482', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01788725', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01788728', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01792103', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01773054', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01778003', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01778088', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01788853', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01788854', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01792834', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01792851', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01792890', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01797722', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01797725', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01798400', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01798506', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01798558', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01800886', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01802627', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01804502', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01804515', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01804522', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01804564', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01804598', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01805558', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01807472', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01807475', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01807494', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01809215', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01810107', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01810124', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01810134', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01812393', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01816099', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01817952', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01817964', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01817974', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01817978', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01818014', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01818015', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01818555', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01818557', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01818565', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01821296', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01822384', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01824422', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01824440', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01824465', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01824470', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01824744', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01824754', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01824830', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01824855', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01824857', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01824872', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01824874', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01824876', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01824893', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01824894', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01824896', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01824918', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01824919', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01824927', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01824928', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01824929', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01824973', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01824975', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01824979', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01824980', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01824986', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01824990', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01828898', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01829097', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01829238', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01831479', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01834050', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01834067', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01834080', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01834088', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01834129', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01834133', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01834153', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01834162', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01834184', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01834189', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01834195', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01838211', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01840619', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01841620', 'REJECTED', 'NOT_COLLECTED')
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
System.debug(' -> LOTE 1 -> MODO: ' + (DRY_RUN ? 'DRY RUN' : 'EJECUCION REAL'));
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
System.debug(' -> LOTE 1 -> Saltados (no elegible): ' + skippedNotEligible);
System.debug(' -> LOTE 1 -> Saltados (ya coincidian): ' + skippedAlreadyOk);
System.debug(' -> LOTE 1 -> Total a actualizar: ' + toUpdate.size());
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
    System.debug(' -> LOTE 1 -> UPDATE COMPLETADO. Exitosos: ' + okCount + ' / ' + toUpdate.size());
} else {
    System.debug(' -> LOTE 1 -> DRY RUN: no se realizo ningun cambio.');
}
