Savepoint sp = Database.setSavepoint();
try {
    update new SM_Payment__c(
        Id = 'a24UU000005GDNsYAO', Payment_Status__c = 'ACCEPTED', SM_Check_Collection_Date__c = Date.today(),
        SM_Check_Collection__c = true, SM_Check_Collection_Status__c = 'COLLECTED'
    );
    System.debug('EXITO INESPERADO');
} catch (Exception e) {
    System.debug('TIPO: ' + e.getTypeName());
    System.debug('MENSAJE COMPLETO: ' + e.getMessage());
    System.debug('STACK: ' + e.getStackTraceString());
} finally {
    Database.rollback(sp);
}
