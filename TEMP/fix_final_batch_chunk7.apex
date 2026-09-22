/*
 * fix_final_batch_chunk7.apex
 * Lote 8 del fix final combinado (T1 restante + T2 sin Grupo A +
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
    new TargetState('PY-01817856', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01817939', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01817946', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01817951', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01817958', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01817959', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01817966', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01817970', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01817977', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01817985', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01817988', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01817989', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01817993', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01817994', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01817996', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01818003', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01818004', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01818006', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01818007', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01818011', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01818019', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01818023', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01818025', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01818027', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01818028', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01818035', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01818037', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01818038', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01818039', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01818437', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01818439', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01818441', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01818444', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01818449', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01818450', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01818456', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01818469', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01818475', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01818490', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01818500', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01818571', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01818587', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01818591', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01818602', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01818604', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01820252', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01820255', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01820266', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01820267', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01821279', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01821293', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01821299', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01821306', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01821389', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01822361', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01822376', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01823363', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01824413', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01824433', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01824451', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01824454', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01824459', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01824463', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01824466', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01824474', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01824663', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01824666', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01824669', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01824676', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01824679', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01824680', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01824682', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01824722', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01824731', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01824738', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01824746', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01824749', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01824753', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01824757', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01824758', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01824759', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01824768', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01824771', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01824773', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01824776', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01824783', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01824791', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01824793', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01824801', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01824804', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01824807', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01824808', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01824816', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01824821', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01824833', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01824843', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01824847', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01824848', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01824850', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01824854', 'REJECTED', 'NOT_COLLECTED')
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
System.debug(' -> LOTE 8 -> MODO: ' + (DRY_RUN ? 'DRY RUN' : 'EJECUCION REAL'));
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
System.debug(' -> LOTE 8 -> Saltados (no elegible): ' + skippedNotEligible);
System.debug(' -> LOTE 8 -> Saltados (ya coincidian): ' + skippedAlreadyOk);
System.debug(' -> LOTE 8 -> Total a actualizar: ' + toUpdate.size());
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
    System.debug(' -> LOTE 8 -> UPDATE COMPLETADO. Exitosos: ' + okCount + ' / ' + toUpdate.size());
} else {
    System.debug(' -> LOTE 8 -> DRY RUN: no se realizo ningun cambio.');
}
