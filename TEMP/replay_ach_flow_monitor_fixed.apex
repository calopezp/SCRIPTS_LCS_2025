DateTime since = DateTime.now().addHours(-24);

List<Contract> activatedToday = [
    SELECT Id, ContractNumber, Status, SM_Payment_methods__c, CB_Subscription__c,
           SM_AC_collected__c, SM_Net_AC__c, SM_Net_Monthly_offer__c, StartDate,
           (SELECT Id, SM_Payment_Type__c FROM ACH_Orders__r WHERE SM_Payment_Type__c = 'Subscription')
    FROM Contract
    WHERE Status = 'Activated' AND StartDate = TODAY
];

List<Contract> recentContracts = [
    SELECT Id, ContractNumber, Status, SM_Requires_AC_Payment__c, SM_Requires_RC_Payment__c,
           SM_AC_collected__c, SM_Payment_methods__c, CB_Subscription__c,
           Is_Test_Contract__c, Is_VIP_Contract__c, SM_Customer_Cancellation__c,
           Contract_Type__c, SM_Full_Payment__c, SM_Total_ac__c, SM_AC_start_date__c,
           SM_AC_Split_Date__c
    FROM Contract
    WHERE SM_Payment_methods__c = 'ACH'
      AND Status IN ('Payment Process', 'Activated')
      AND (LastModifiedDate >= :since OR CreatedDate >= :since)
];

Set<Id> contractIds = new Set<Id>();
for (Contract c : recentContracts) { contractIds.add(c.Id); }

Integer newOrdersCount = [SELECT COUNT() FROM SM_ACH_Order__c WHERE CreatedDate >= :since];

List<SM_ACH_Order__c> activeOrders = contractIds.isEmpty() ? new List<SM_ACH_Order__c>() : [
    SELECT Id, SM_Contract__c, SM_Payment_Type__c
    FROM SM_ACH_Order__c
    WHERE SM_Contract__c IN :contractIds
    AND SM_Payment_Status__c NOT IN ('Completed', 'Canceled')
];

Set<Id> contractsWithAnyAcOrder = new Set<Id>();
if (!contractIds.isEmpty()) {
    for (SM_ACH_Order__c o : [SELECT SM_Contract__c FROM SM_ACH_Order__c WHERE SM_Contract__c IN :contractIds AND SM_Payment_Type__c = 'AC']) {
        contractsWithAnyAcOrder.add(o.SM_Contract__c);
    }
}

List<String> anomalies = SM_ACH_Flow_Monitor.buildAnomalies(recentContracts, activeOrders, contractsWithAnyAcOrder);
for (Contract c : activatedToday) {
    if (c.SM_Payment_methods__c == 'ACH' && c.ACH_Orders__r.isEmpty()) {
        anomalies.add('ALERTA: Contrato ' + c.ContractNumber + ' se activo por ACH pero no tiene Subscription Order');
    }
}

System.debug('=======================================================');
System.debug('ANOMALIAS CON EL FIX (' + anomalies.size() + '):');
for (String a : anomalies) {
    System.debug('  - ' + a);
}
System.debug('=======================================================');
