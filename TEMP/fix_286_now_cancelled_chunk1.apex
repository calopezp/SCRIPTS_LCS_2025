/*
 * fix_286_now_cancelled_chunk1.apex
 * Lote 2: re-aplica el fix (T5/T8) a payments cuyo contrato paso
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
    new TargetState('PY-01810153', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01810158', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01810159', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01810168', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01810179', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01810190', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01810201', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01810209', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01810225', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01810237', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01810280', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01812401', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01812411', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01813487', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01813509', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01813519', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01813520', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01815190', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01815238', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01815304', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01815305', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01816079', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01816081', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01816084', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01816085', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01816087', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01816097', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01816102', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01816106', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01817966', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01817977', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01817988', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01817993', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01817994', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01817996', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01818011', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01818019', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01818456', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01818469', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01818490', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01818500', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01818587', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01818602', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01818604', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01820255', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01821306', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01822376', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01823363', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01824451', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01824454', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01824466', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01824474', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01824676', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01824776', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01824793', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01824801', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01824807', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01824808', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01824816', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01824821', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01824833', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01824843', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01824847', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01824848', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01824850', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01824854', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01824865', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01824871', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01824877', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01824879', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01824884', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01824898', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01824916', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01824923', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01824924', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01824926', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01824959', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01824961', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01824985', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01828930', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01828937', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01829095', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01829101', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01829240', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01830295', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01830296', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01830297', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01830298', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01830299', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01830304', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01830306', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01830308', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01830311', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01832754', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01832760', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01832784', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01832785', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01832952', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01834031', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01834086', 'REJECTED', 'NOT_COLLECTED')
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
System.debug(' -> LOTE 2 -> MODO: ' + (DRY_RUN ? 'DRY RUN' : 'EJECUCION REAL'));
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
System.debug(' -> LOTE 2 -> Saltados (no elegible): ' + skippedNotEligible);
System.debug(' -> LOTE 2 -> Saltados (ya coincidian): ' + skippedAlreadyOk);
System.debug(' -> LOTE 2 -> Total a actualizar: ' + toUpdate.size());
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
    System.debug(' -> LOTE 2 -> UPDATE COMPLETADO. Exitosos: ' + okCount + ' / ' + toUpdate.size());
} else {
    System.debug(' -> LOTE 2 -> DRY RUN: no se realizo ningun cambio.');
}
