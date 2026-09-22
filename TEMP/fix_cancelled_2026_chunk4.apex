/*
 * fix_cancelled_2026_t1_t2_chunk4.apex
 * Lote 5 del fix combinado T1+T2 (solo contratos Cancelled).
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
    new TargetState('PY-01818538', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01818539', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01818540', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01818541', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01818542', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01818543', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01818544', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01818545', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01818550', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01818551', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01818553', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01818556', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01818559', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01818562', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01818563', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01818564', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01818568', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01818569', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01818570', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01818572', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01818573', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01818574', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01818575', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01818578', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01818579', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01818580', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01818581', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01818583', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01818584', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01818586', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01818588', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01818592', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01818593', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01818594', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01818595', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01818597', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01818598', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01818599', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01818600', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01819316', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01819319', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01820258', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01820260', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01821270', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01821273', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01821277', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01821287', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01821289', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01821294', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01821301', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01822363', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01824412', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01824414', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01824415', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01824418', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01824420', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01824421', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01824423', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01824424', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01824428', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01824429', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01824430', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01824434', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01824435', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01824447', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01824449', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01824450', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01824460', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01824464', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01824468', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01824479', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01824581', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01824778', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01824779', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01824810', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01824814', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01824844', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01824851', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01824852', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01824853', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01824869', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01824873', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01824875', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01824880', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01824883', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01824890', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01824901', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01824902', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01824907', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01824908', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01824915', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01824917', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01824920', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01824921', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01824962', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01824963', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01824965', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01824970', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01824981', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01824989', 'REJECTED', 'NOT_COLLECTED')
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
System.debug(' -> LOTE 5 -> MODO: ' + (DRY_RUN ? 'DRY RUN' : 'EJECUCION REAL'));
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
System.debug(' -> LOTE 5 -> Saltados (no Cancelled): ' + skippedNotCancelled);
System.debug(' -> LOTE 5 -> Saltados (ya coincidian): ' + skippedAlreadyOk);
System.debug(' -> LOTE 5 -> Total a actualizar: ' + toUpdate.size());
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
    System.debug(' -> LOTE 5 -> UPDATE COMPLETADO. Exitosos: ' + okCount + ' / ' + toUpdate.size());
} else {
    System.debug(' -> LOTE 5 -> DRY RUN: no se realizo ningun cambio.');
}
