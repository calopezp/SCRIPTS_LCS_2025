/*
 * fix_cancelled_2026_t1_t2_chunk6.apex
 * Lote 7 del fix combinado T1+T2 (solo contratos Cancelled).
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
    new TargetState('PY-01842159', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01842160', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01842175', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01842177', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01842179', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01842188', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01842189', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01842217', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01842218', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01842236', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01842239', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01842249', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01842258', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01842276', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01845221', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01845232', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01845252', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01845258', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01845422', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01846490', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01847627', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01847628', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01847629', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01847630', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01847631', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01847634', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01847636', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01847641', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01847642', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01847643', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01847646', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01847648', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01847650', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01848917', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01848920', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01849205', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01849468', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01849473', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01850063', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01850067', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01850083', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01850720', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01852543', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01852624', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01852637', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01852960', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01853253', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01853262', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01853952', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01853956', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01853960', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01853969', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01853997', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01856301', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01856302', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01856501', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01857169', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01859473', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01859498', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01859500', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01859533', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01859538', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01859549', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01859550', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01859565', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01859567', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01859569', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01859578', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01859579', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01859606', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01859607', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01859624', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01859627', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01859635', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01859642', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01859657', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01859659', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01859670', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01859720', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01860322', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01861626', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01861633', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01865129', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01865158', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01866142', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01866150', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01866152', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01866296', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01867060', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01867069', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01867075', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01867078', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01867081', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01867087', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01867091', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01867662', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01867665', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01868510', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01868513', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01868515', 'REJECTED', 'NOT_COLLECTED')
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
System.debug(' -> LOTE 7 -> MODO: ' + (DRY_RUN ? 'DRY RUN' : 'EJECUCION REAL'));
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
System.debug(' -> LOTE 7 -> Saltados (no Cancelled): ' + skippedNotCancelled);
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
