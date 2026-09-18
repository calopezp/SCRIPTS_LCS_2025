// SOLO DIAGNOSTICO -- reproduce el mismo error que ya ocurrio, sin cambiar
// nada nuevo (el update ya fallaba antes tambien). Envuelto en try/catch
// para capturar el stack trace completo y ver la linea exacta.
SM_Payment__c p = [SELECT Id, Name FROM SM_Payment__c WHERE Id = 'a24UU000005EtlSYAS'];
Savepoint sp = Database.setSavepoint();
try {
    update new SM_Payment__c(
        Id = p.Id,
        Payment_Status__c = 'ACCEPTED',
        SM_Check_Collection_Date__c = Date.today(),
        SM_Check_Collection__c = true,
        SM_Check_Collection_Status__c = 'COLLECTED'
    );
    System.debug('EXITO INESPERADO');
} catch (Exception e) {
    System.debug('TIPO: ' + e.getTypeName());
    System.debug('MENSAJE: ' + e.getMessage());
    System.debug('STACK TRACE: ' + e.getStackTraceString());
} finally {
    Database.rollback(sp);
}
