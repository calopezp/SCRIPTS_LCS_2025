/*
 * fix_286_now_cancelled_chunk2.apex
 * Lote 3: re-aplica el fix (T5/T8) a payments cuyo contrato paso
 * a Cancelled durante el dia (2026-09-22) -- ya validados antes, solo
 * se habian saltado por el chequeo de seguridad de contrato Cancelled.
 * Aqui SI se permite Cancelled a proposito.
 *
 * Corre primero con DRY_RUN = true -> solo preview, NO actualiza nada.
 */

Boolean DRY_RUN = false; // Autorizado 2026-09-22: re-aplicar a contratos ya Cancelled

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
    new TargetState('PY-01834107', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01834110', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01834114', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01834130', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01834132', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01834154', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01834155', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01834164', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01834171', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01834177', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01834182', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01834183', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01834187', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01834196', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01834198', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01834200', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01834204', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01834207', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01834210', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01834212', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01834213', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01834214', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01834215', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01834216', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01834229', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01835545', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01836989', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01838209', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01838220', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01838227', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01839299', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01840496', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01840620', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01840713', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01841621', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01841654', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01841668', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01841675', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01841676', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01842098', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01842143', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01842174', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01842180', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01842227', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01842231', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01842251', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01845219', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01845410', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01845425', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01846494', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01847652', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01849471', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01850076', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01850088', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01850098', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01852568', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01852587', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01852600', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01852622', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01852635', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01852954', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01852968', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01853261', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01853958', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01855217', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01855950', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01855953', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01856508', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01857157', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01857179', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01857192', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01859562', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01859564', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01859605', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01859619', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01859683', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01859713', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01859715', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01860309', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01863791', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01863792', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01899134', 'REJECTED', 'PENDING'),
    new TargetState('PY-01899192', 'REJECTED', 'PENDING'),
    new TargetState('PY-01900438', 'REJECTED', 'PENDING'),
    new TargetState('PY-01900439', 'REJECTED', 'PENDING'),
    new TargetState('PY-01903619', 'REJECTED', 'PENDING')
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
    if (p.SM_Contract__r == null) {
        System.debug(' -> ***** SALTADO (sin contrato): ' + p.Name);
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
        'PREVIEW -> ' + p.Name + ' (Contrato ' + p.SM_Contract__r.ContractNumber + ', Status ' + p.SM_Contract__r.Status + ')' +
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
