void tryUpdate(String label, Id i) {
    Savepoint sp = Database.setSavepoint();
    try {
        update new SM_Payment__c(
            Id = i, Payment_Status__c = 'ACCEPTED', SM_Check_Collection_Date__c = Date.today(),
            SM_Check_Collection__c = true, SM_Check_Collection_Status__c = 'COLLECTED'
        );
        System.debug(label + ' -> EXITO');
    } catch (Exception e) {
        System.debug(label + ' -> FALLO: ' + e.getMessage());
    } finally {
        Database.rollback(sp);
    }
}
tryUpdate('S', 'a24UU000005GDNsYAO');
tryUpdate('T', 'a24UU000005GDNtYAO');
