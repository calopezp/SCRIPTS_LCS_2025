Set<Id> contractIds = new Set<Id>{
    '800VB00000hncRZYAY', // C1 AC simple
    '800VB00000hncRaYAI', // C2 AC split
    '800VB00000hncRbYAI'  // C3 Subscription
};

List<Contract> cons = [
    SELECT Id, ContractNumber, Status, SM_AC_collected__c, SM_Charged_AC_Amount__c,
           SM_Total_ac__c, SM_Net_AC__c, SM_AC_start_date__c, SM_AC_Split_Date__c,
           SM_Way_of_AC_Payment__c, SM_Payment_methods__c
    FROM Contract
    WHERE Id IN :contractIds
];
for (Contract c : cons) {
    System.debug(' === CONTRATO ' + c.Id + ' ===');
    System.debug('   Status=' + c.Status + ' AC_collected=' + c.SM_AC_collected__c
        + ' ChargedAC=' + c.SM_Charged_AC_Amount__c + ' TotalAC=' + c.SM_Total_ac__c
        + ' NetAC=' + c.SM_Net_AC__c + ' WayOfAC=' + c.SM_Way_of_AC_Payment__c
        + ' PaymentMethods=' + c.SM_Payment_methods__c);
}

List<SM_ACH_Order__c> orders = [
    SELECT Id, SM_Contract__c, SM_Payment_Type__c, SM_Total__c, SM_Payment_Status__c,
           SM_Payment_Start_Date__c, SM_Payment_End_Date__c, SM_Next_Transaction_Date__c,
           SM_Payment_Frequency__c, CreatedDate
    FROM SM_ACH_Order__c
    WHERE SM_Contract__c IN :contractIds
    ORDER BY SM_Contract__c, CreatedDate
];
System.debug(' -> Total ACH Orders encontradas: ' + orders.size());
for (SM_ACH_Order__c o : orders) {
    System.debug(' ORDER ' + o.Id + ' Contract=' + o.SM_Contract__c
        + ' Type=' + o.SM_Payment_Type__c + ' Total=' + o.SM_Total__c
        + ' Status=' + o.SM_Payment_Status__c + ' Start=' + o.SM_Payment_Start_Date__c
        + ' End=' + o.SM_Payment_End_Date__c + ' NextTx=' + o.SM_Next_Transaction_Date__c
        + ' Freq=' + o.SM_Payment_Frequency__c);
}
