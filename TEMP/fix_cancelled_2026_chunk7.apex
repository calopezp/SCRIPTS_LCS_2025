/*
 * fix_cancelled_2026_t1_t2_chunk7.apex
 * Lote 8 del fix combinado T1+T2 (solo contratos Cancelled).
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
    new TargetState('PY-01868516', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01868519', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01868520', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01868522', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01868523', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01868524', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01868525', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01868526', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01868528', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01868531', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01868532', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01868536', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01868539', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01869218', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01869220', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01869221', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01869472', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01869473', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01869479', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01869480', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01870676', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01872208', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01872249', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01872260', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01872274', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01872275', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01872276', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01872277', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01872811', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01872871', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01872872', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01872877', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01872911', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01872927', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01872958', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01872960', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01872965', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01872995', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01873015', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01874897', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01877142', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01877944', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01877972', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01877979', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01879519', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01880339', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01880342', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01880402', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01880416', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01881025', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01883327', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01883967', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01884560', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01884579', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01884586', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01884589', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01884597', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01884600', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01884607', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01884616', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01884620', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01884628', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01884632', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01884633', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01884636', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01884637', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01884640', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01884644', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01884648', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01884650', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01884652', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01884654', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01884659', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01884660', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01884670', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01884675', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01884677', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01884680', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01884682', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01884690', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01884693', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01884694', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01884697', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01884702', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01884703', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01884705', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01884711', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01884714', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01884721', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01884722', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01884724', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01884737', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01884738', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01885978', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01887683', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01888275', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01888279', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01888805', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01888816', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01888828', 'REJECTED', 'NOT_COLLECTED')
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
System.debug(' -> LOTE 8 -> MODO: ' + (DRY_RUN ? 'DRY RUN' : 'EJECUCION REAL'));
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
System.debug(' -> LOTE 8 -> Saltados (no Cancelled): ' + skippedNotCancelled);
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
