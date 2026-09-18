List<Id> a = new List<Id>{'a24UU000005EtlhYAC','a24UU000005EtliYAC','a24UU000005FR77YAG','a24UU000005FR7AYAW'};
List<Id> b = new List<Id>{'a24UU000005FR7CYAW','a24UU000005FR7DYAW','a24UU000005GDNsYAO','a24UU000005GDNtYAO'};

void tryUpdate(String label, List<Id> ids) {
    List<SM_Payment__c> toUpdate = new List<SM_Payment__c>();
    for (Id i : ids) {
        toUpdate.add(new SM_Payment__c(
            Id = i, Payment_Status__c = 'ACCEPTED', SM_Check_Collection_Date__c = Date.today(),
            SM_Check_Collection__c = true, SM_Check_Collection_Status__c = 'COLLECTED'
        ));
    }
    Savepoint sp = Database.setSavepoint();
    try {
        update toUpdate;
        System.debug(label + ' -> EXITO (' + ids.size() + ' registros)');
    } catch (Exception e) {
        System.debug(label + ' -> FALLO (' + ids.size() + ' registros)');
    } finally {
        Database.rollback(sp);
    }
}
tryUpdate('A', a);
tryUpdate('B', b);
