/*
 * fix_cancelled_2026_t1_t2_chunk2.apex
 * Lote 3 del fix combinado T1+T2 (solo contratos Cancelled).
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
    new TargetState('PY-01798394', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01798396', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01798397', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01798404', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01798407', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01798415', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01798429', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01798453', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01798465', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01798494', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01798496', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01798507', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01798508', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01798520', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01798526', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01798528', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01798530', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01798540', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01798541', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01798550', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01798575', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01798581', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01798582', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01798587', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01798590', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01798591', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01798593', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01798595', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01798596', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01798613', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01798619', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01798634', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01800758', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01800769', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01800771', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01800772', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01800889', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01800893', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01801071', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01801072', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01801795', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01801798', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01801799', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01801800', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01801801', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01801807', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01804548', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01804565', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01804568', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01804575', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01804585', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01805541', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01805542', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01805543', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01805544', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01805545', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01805547', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01805548', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01805549', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01805550', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01805551', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01805553', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01805554', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01805555', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01806514', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01806522', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01806530', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01806540', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01806543', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01806545', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01806550', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01807437', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01807442', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01807447', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01807461', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01807467', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01807469', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01807473', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01809193', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01809194', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01809195', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01809200', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01809203', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01809207', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01809217', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01810007', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01810033', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01810035', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01810044', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01810075', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01810077', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01810088', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01810089', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01810099', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01810106', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01810108', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01810110', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01810120', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01810121', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01810126', 'REJECTED', 'NOT_COLLECTED')
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
System.debug(' -> LOTE 3 -> MODO: ' + (DRY_RUN ? 'DRY RUN' : 'EJECUCION REAL'));
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
System.debug(' -> LOTE 3 -> Saltados (no Cancelled): ' + skippedNotCancelled);
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
