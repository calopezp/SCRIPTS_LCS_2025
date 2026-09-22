/*
 * fix_cancelled_2026_t1_t2_chunk1.apex
 * Lote 2 del fix combinado T1+T2 (solo contratos Cancelled).
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
    new TargetState('PY-01785946', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01785949', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01785951', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01785953', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01785964', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01785965', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01785972', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01785973', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01785989', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01786025', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01786031', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01786072', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01786076', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01786084', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01787479', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01787481', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01787486', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01787489', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01787491', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01788724', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01788726', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01788731', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01788733', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01788734', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01788736', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01788738', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01788844', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01788851', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01788855', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01791981', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01791999', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01792181', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01792182', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01792183', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01792184', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01792185', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01792186', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01792187', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01792188', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01792189', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01792192', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01792193', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01792195', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01792196', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01792198', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01792200', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01792202', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01792203', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01792204', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01792210', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01792212', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01792862', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01792866', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01792867', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01792871', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01792876', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01792884', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01792891', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01792910', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01792911', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01793836', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01793838', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01793844', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01793850', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01793856', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01794926', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01794927', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01794928', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01794929', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01794931', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01794932', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01794933', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01794934', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01794935', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01794936', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01795670', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01795675', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01795680', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01795685', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01795692', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01795695', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01795696', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01795697', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01795698', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01795710', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01797602', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01797605', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01797606', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01797715', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01797716', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01797717', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01797724', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01797727', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01797728', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01797729', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01798387', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01798388', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01798390', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01798391', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01798393', 'REJECTED', 'NOT_COLLECTED')
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
System.debug(' -> LOTE 2 -> MODO: ' + (DRY_RUN ? 'DRY RUN' : 'EJECUCION REAL'));
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
System.debug(' -> LOTE 2 -> Saltados (no Cancelled): ' + skippedNotCancelled);
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
