// Prueba del Flow ACH_ORDER_Subscription_Stopped_Monitoring. TODO se revierte con la excepcion final.
// Uso: sf apex run -o MONEE -f TEMP/test_flow_subscription_stopped_monitoring.apex
// El resultado sale en el mensaje de la excepcion "ROLLBACK INTENCIONAL" (lineas TESTRESULT separadas por #####).
// Caso A = contrato sin monitoreo (debe asignarse); caso B = contrato con responsable (debe respetarse).
List<SM_ACH_Order__c> a = [SELECT Id, Name, SM_Contract__c, SM_Contract__r.ContractNumber FROM SM_ACH_Order__c
    WHERE SM_Payment_Type__c = 'Subscription' AND SM_Payment_Status__c = 'Initiated'
    AND SM_Contract__r.SM_ContractMonitoring__c = false AND SM_Contract__r.Status = 'Activated' LIMIT 1];
List<SM_ACH_Order__c> b = [SELECT Id, Name, SM_Contract__c, SM_Contract__r.ContractNumber FROM SM_ACH_Order__c
    WHERE SM_Payment_Type__c = 'Subscription' AND SM_Payment_Status__c = 'Initiated'
    AND SM_Contract__r.SM_ContractMonitoring__c = true AND SM_Contract__r.Contract_Monitoring_By__c != null LIMIT 1];
List<SM_ACH_Order__c> all = new List<SM_ACH_Order__c>();
all.addAll(a); all.addAll(b);
String out = '';
Set<Id> cids = new Set<Id>();
for (SM_ACH_Order__c o : all) { o.SM_Payment_Status__c = 'Stopped'; cids.add(o.SM_Contract__c); }
Datetime t0 = System.now().addSeconds(-5);
update all;
for (Contract c : [SELECT ContractNumber, SM_ContractMonitoring__c, Contract_Monitoring_By__r.Name, SM_Id_Salesforce_LCS__c FROM Contract WHERE Id IN :cids]) {
    out += ' ##### ' + ('TESTRESULT CONTRACT ' + c.ContractNumber + ' | monitoring=' + c.SM_ContractMonitoring__c + ' | by=' + c.Contract_Monitoring_By__r.Name + ' | note=' + c.SM_Id_Salesforce_LCS__c);
}
for (Task t : [SELECT What.Name, Subject, Status, Owner.Name, ActivityDate, Description FROM Task WHERE WhatId IN :cids AND CreatedDate >= :t0]) {
    out += ' ##### ' + ('TESTRESULT TASK ' + t.What.Name + ' | ' + t.Subject + ' | ' + t.Status + ' | ' + t.Owner.Name + ' | ' + t.ActivityDate + ' | ' + t.Description.replace('\n', ' \\n '));
}
out += ' ##### ' + ('TESTRESULT orders: ' + (a.isEmpty() ? 'sin caso A' : a[0].Name + '/' + a[0].SM_Contract__r.ContractNumber) + ' ; ' + (b.isEmpty() ? 'sin caso B' : b[0].Name + '/' + b[0].SM_Contract__r.ContractNumber));
throw new IllegalArgumentException('ROLLBACK INTENCIONAL' + out);
