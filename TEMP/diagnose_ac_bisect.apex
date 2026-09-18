// SOLO DIAGNOSTICO -- bisecta el lote de 15 en 2 mitades para aislar cual(es)
// registro(s) dispara(n) el NullPointerException. Con rollback, no cambia nada.
List<Id> half1 = new List<Id>{
    'a24UU000005EtlSYAS','a24UU000005EtlTYAS','a24UU000005EtlUYAS','a24UU000005EtlWYAS',
    'a24UU000005EtlZYAS','a24UU000005EtlaYAC','a24UU000005EtlbYAC'
};
List<Id> half2 = new List<Id>{
    'a24UU000005EtlhYAC','a24UU000005EtliYAC','a24UU000005FR77YAG','a24UU000005FR7AYAW',
    'a24UU000005FR7CYAW','a24UU000005FR7DYAW','a24UU000005GDNsYAO','a24UU000005GDNtYAO'
};

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
        System.debug(label + ' -> FALLO (' + ids.size() + ' registros): ' + e.getTypeName() + ' | ' + e.getMessage().left(120));
    } finally {
        Database.rollback(sp);
    }
}

tryUpdate('MITAD 1', half1);
tryUpdate('MITAD 2', half2);
