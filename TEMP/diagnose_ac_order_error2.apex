// SOLO DIAGNOSTICO -- reproduce el batch completo que fallo, con rollback,
// para capturar el stack trace real.
Set<Id> ids = new Set<Id>{
    'a24UU000005EtlSYAS','a24UU000005EtlTYAS','a24UU000005EtlUYAS','a24UU000005EtlWYAS',
    'a24UU000005EtlZYAS','a24UU000005EtlaYAC','a24UU000005EtlbYAC','a24UU000005EtlhYAC',
    'a24UU000005EtliYAC','a24UU000005FR77YAG','a24UU000005FR7AYAW','a24UU000005FR7CYAW',
    'a24UU000005FR7DYAW','a24UU000005GDNsYAO','a24UU000005GDNtYAO'
};
List<SM_Payment__c> toUpdate = new List<SM_Payment__c>();
for (Id i : ids) {
    toUpdate.add(new SM_Payment__c(
        Id = i,
        Payment_Status__c = 'ACCEPTED',
        SM_Check_Collection_Date__c = Date.today(),
        SM_Check_Collection__c = true,
        SM_Check_Collection_Status__c = 'COLLECTED'
    ));
}
Savepoint sp = Database.setSavepoint();
try {
    update toUpdate;
    System.debug('EXITO INESPERADO - todo el batch paso');
} catch (Exception e) {
    System.debug('TIPO: ' + e.getTypeName());
    System.debug('MENSAJE: ' + e.getMessage());
    System.debug('STACK TRACE: ' + e.getStackTraceString());
} finally {
    Database.rollback(sp);
}
