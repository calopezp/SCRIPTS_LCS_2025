/*
 * fix_cancelled_2026_t1_t2_chunk0.apex
 * Lote 1 del fix combinado T1+T2 (solo contratos Cancelled).
 * Ver fix_cancelled_2026_t1_t2.apex (version sin chunkear, referencia
 * de contexto completo) -- se dividio en lotes de 100 porque
 * el script completo excedia el limite de tamano de Anonymous Apex
 * ("Script too large").
 *
 * Corre primero con DRY_RUN = true -> solo preview, NO actualiza nada.
 */

Boolean DRY_RUN = false; // Autorizado por el usuario 2026-09-22 tras revisar el preview (800/800 sin saltos)

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
    new TargetState('PY-01773068', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01774868', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01785954', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01786017', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01786039', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01786049', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01786067', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01787487', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01792002', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01773055', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01773059', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01773061', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01773072', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01773073', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01774861', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01774863', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01774864', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01775767', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01775791', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01775794', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01775795', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01775797', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01775798', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01775800', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01775804', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01775807', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01776681', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01776682', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01776755', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01776766', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01776771', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01776778', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01777712', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01777916', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01777932', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01777989', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01777994', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01777997', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01778002', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01778011', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01778014', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01778016', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01778017', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01778018', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01778019', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01778022', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01778023', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01778029', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01778084', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01778090', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01778115', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01779096', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01779101', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01779107', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01779112', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01779119', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01779124', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01780205', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01780218', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01780253', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01780255', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01780260', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01780263', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01780264', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01781314', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01781426', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01781429', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01781554', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01781555', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01781558', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01781560', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01781562', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01782474', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01782476', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01782500', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01783641', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01784731', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01784732', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01784735', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01784848', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01784849', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01785861', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01785867', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01785874', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01785875', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01785891', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01785904', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01785910', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01785912', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01785913', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01785914', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01785919', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01785926', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01785927', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01785928', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01785929', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01785932', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01785938', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01785941', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01785945', 'REJECTED', 'NOT_COLLECTED')
};

Map<String, TargetState> targetByName = new Map<String, TargetState>();
for (TargetState t : targets) {
    targetByName.put(t.name, t);
}

List<SM_Payment__c> payments = [
    SELECT Id, Name, Payment_Status__c, SM_Check_Collection__c, SM_Check_Collection_Date__c,
           SM_Check_Collection_Status__c, SM_Return_code__c, SM_Historical_Collection_Status__c,
           SM_Contract__r.ContractNumber, SM_Contract__r.Status
    FROM SM_Payment__c
    WHERE Name IN :targetByName.keySet()
];

System.debug('=======================================================');
System.debug(' -> LOTE 1 -> MODO: ' + (DRY_RUN ? 'DRY RUN' : 'EJECUCION REAL'));
System.debug(' -> Payments encontrados: ' + payments.size() + ' (esperados: ' + targetByName.size() + ')');
System.debug('=======================================================');

List<SM_Payment__c> toUpdate = new List<SM_Payment__c>();
Integer skippedNotCancelled = 0;
Integer skippedAlreadyOk = 0;

for (SM_Payment__c p : payments) {
    TargetState t = targetByName.get(p.Name);
    if (p.SM_Contract__r == null || p.SM_Contract__r.Status != 'Cancelled') {
        System.debug(' -> ***** SALTADO (el contrato ya no esta Cancelled): ' + p.Name + ' -> ' + (p.SM_Contract__r != null ? p.SM_Contract__r.Status : '(sin contrato)'));
        skippedNotCancelled++;
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
        ' | SM_Check_Collection_Date__c (sin cambio): ' + p.SM_Check_Collection_Date__c +
        ' | Historico -> [' + newHistorical + ']'
    );

    p.Payment_Status__c = t.paymentStatus;
    p.SM_Check_Collection_Status__c = t.collectionStatus;
    p.SM_Check_Collection__c = true;
    p.SM_Historical_Collection_Status__c = newHistorical;
    toUpdate.add(p);
}

System.debug('=======================================================');
System.debug(' -> LOTE 1 -> Saltados (no Cancelled): ' + skippedNotCancelled);
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
