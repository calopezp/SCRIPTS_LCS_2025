/*
 * fix_cancelled_2026_t1_t2_chunk3.apex
 * Lote 4 del fix combinado T1+T2 (solo contratos Cancelled).
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
    new TargetState('PY-01810152', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01810154', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01810182', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01810183', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01810191', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01810200', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01810210', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01810224', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01810227', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01810228', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01810229', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01810245', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01810246', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01810248', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01810268', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01810295', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01811155', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01811161', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01812515', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01812524', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01812526', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01812532', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01813500', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01813514', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01816050', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01816089', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01816090', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01816101', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01817857', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01817860', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01817957', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01818005', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01818018', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01818020', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01818021', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01818022', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01818033', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01818435', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01818443', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01818453', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01818454', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01818458', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01818459', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01818461', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01818462', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01818463', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01818464', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01818466', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01818467', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01818468', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01818470', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01818471', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01818472', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01818473', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01818474', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01818476', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01818477', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01818479', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01818481', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01818482', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01818485', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01818486', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01818487', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01818488', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01818491', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01818493', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01818494', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01818495', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01818496', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01818497', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01818498', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01818499', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01818501', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01818502', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01818503', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01818504', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01818505', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01818506', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01818507', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01818508', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01818509', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01818510', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01818511', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01818512', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01818517', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01818518', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01818519', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01818523', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01818524', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01818527', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01818528', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01818529', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01818530', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01818531', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01818532', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01818533', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01818534', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01818535', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01818536', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01818537', 'REJECTED', 'NOT_COLLECTED')
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
System.debug(' -> LOTE 4 -> MODO: ' + (DRY_RUN ? 'DRY RUN' : 'EJECUCION REAL'));
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
System.debug(' -> LOTE 4 -> Saltados (no Cancelled): ' + skippedNotCancelled);
System.debug(' -> LOTE 4 -> Saltados (ya coincidian): ' + skippedAlreadyOk);
System.debug(' -> LOTE 4 -> Total a actualizar: ' + toUpdate.size());
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
    System.debug(' -> LOTE 4 -> UPDATE COMPLETADO. Exitosos: ' + okCount + ' / ' + toUpdate.size());
} else {
    System.debug(' -> LOTE 4 -> DRY RUN: no se realizo ningun cambio.');
}
