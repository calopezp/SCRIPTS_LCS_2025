// Diagnóstico aislado: confirma si Salesforce acepta Status + Reason
// juntos en una misma DML, o si hace falta partirlo en 2 (el fix ya
// aplicado en -CANCELAR_CONTRATOS_FULL.apex). No toca Chargebee.
//
// modoDryRun = true: usa un Savepoint y hace ROLLBACK al final, así
// las DML SÍ corren (para que la validación de Salesforce sea real)
// pero ningún cambio queda guardado — no vuelve a pasar lo de la
// corrida anterior, donde un "diagnóstico" terminó cancelando de
// verdad el contrato 00317762 sin tocar Chargebee.

// ---------------- CONFIG ----------------
Boolean modoDryRun = true;   // true = corre las DML pero hace rollback al final (no deja nada guardado)
Id contractId = '800UU00000i83NjYAI'; // contrato 00317762
// -----------------------------------------

Savepoint sp = modoDryRun ? Database.setSavepoint() : null;

Contract c = [SELECT Id, Status, RecordTypeId, RecordType.Name, SM_Reason_for_cancellation__c
              FROM Contract WHERE Id = :contractId];
System.debug('ANTES -> Status=[' + c.Status + '] RecordType=[' + c.RecordType.Name
    + '] Reason=[' + c.SM_Reason_for_cancellation__c + ']');

String reason = 'Does not comply with payments';

// Intento 1: Status + Reason en la MISMA DML.
Contract badAttempt = new Contract(
    Id                             = contractId,
    Status                         = 'Cancelled',
    SM_Reason_for_cancellation__c  = reason
);
try {
    Database.SaveResult sr1 = Database.update(badAttempt, false);
    System.debug('INTENTO 1 (mismo DML) -> ' + (sr1.isSuccess() ? 'OK' : 'ERROR: ' + sr1.getErrors()));
} catch (Exception e) {
    System.debug('INTENTO 1 (mismo DML) -> EXCEPTION: ' + e.getMessage());
}

// Re-leer estado actual antes del intento 2 (por si el 1 sí aplicó el Status)
c = [SELECT Id, Status, SM_Reason_for_cancellation__c FROM Contract WHERE Id = :contractId];
System.debug('DESPUES DEL INTENTO 1 -> Status=[' + c.Status + '] Reason=[' + c.SM_Reason_for_cancellation__c + ']');

// Intento 2 (fix): Status solo, luego Reason en una 2da DML separada.
Database.SaveResult sr2a = Database.update(new Contract(Id = contractId, Status = 'Cancelled'), false);
System.debug('INTENTO 2a (solo Status) -> ' + (sr2a.isSuccess() ? 'OK' : 'ERROR: ' + sr2a.getErrors()));

if (sr2a.isSuccess()) {
    Database.SaveResult sr2b = Database.update(new Contract(Id = contractId, SM_Reason_for_cancellation__c = reason), false);
    System.debug('INTENTO 2b (Reason, ya con Status comprometido) -> ' + (sr2b.isSuccess() ? 'OK' : 'ERROR: ' + sr2b.getErrors()));
}

if (modoDryRun) {
    Database.rollback(sp);
    Contract after = [SELECT Id, Status, SM_Reason_for_cancellation__c FROM Contract WHERE Id = :contractId];
    System.debug('ROLLBACK HECHO -> Status=[' + after.Status + '] Reason=[' + after.SM_Reason_for_cancellation__c
        + '] (debe verse igual que ANTES)');
}
