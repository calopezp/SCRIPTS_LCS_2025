DateTime since = DateTime.now().addHours(-24);
List<Contract> recentContracts = [
    SELECT Id, ContractNumber, SM_Requires_AC_Payment__c, SM_AC_collected__c,
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

// TODAS las ordenes AC (cualquier estado), no solo las "activas"
Map<Id, List<String>> allAcOrdersByContract = new Map<Id, List<String>>();
for (SM_ACH_Order__c o : [SELECT SM_Contract__c, SM_Payment_Status__c FROM SM_ACH_Order__c
                          WHERE SM_Contract__c IN :contractIds AND SM_Payment_Type__c = 'AC']) {
    if (!allAcOrdersByContract.containsKey(o.SM_Contract__c)) {
        allAcOrdersByContract.put(o.SM_Contract__c, new List<String>());
    }
    allAcOrdersByContract.get(o.SM_Contract__c).add(o.SM_Payment_Status__c);
}

List<SM_ACH_Order__c> activeOrders = [
    SELECT Id, SM_Contract__c, SM_Payment_Type__c FROM SM_ACH_Order__c
    WHERE SM_Contract__c IN :contractIds AND SM_Payment_Status__c NOT IN ('Completed', 'Canceled')
];
Map<Id, Integer> acCountByContract = new Map<Id, Integer>();
for (SM_ACH_Order__c o : activeOrders) {
    if (o.SM_Payment_Type__c == 'AC') {
        acCountByContract.put(o.SM_Contract__c, (acCountByContract.containsKey(o.SM_Contract__c) ? acCountByContract.get(o.SM_Contract__c) : 0) + 1);
    }
}

Integer falsoPositivoCompleted = 0;
Integer falsoPositivoCollectedTrue = 0;
Integer genuinamenteSinNinguna = 0;
Integer otro = 0;

for (Contract c : recentContracts) {
    Boolean eligibleForAC = c.SM_Requires_AC_Payment__c == true
        && c.Is_Test_Contract__c == false && c.Is_VIP_Contract__c == false
        && c.SM_Customer_Cancellation__c == false && c.SM_Full_Payment__c == false
        && c.Contract_Type__c != 'Dependent' && c.SM_Total_ac__c != null && c.SM_AC_start_date__c != null;
    Integer acCount = acCountByContract.containsKey(c.Id) ? acCountByContract.get(c.Id) : 0;
    if (eligibleForAC && acCount == 0) {
        List<String> allStatuses = allAcOrdersByContract.get(c.Id);
        if (allStatuses == null || allStatuses.isEmpty()) {
            genuinamenteSinNinguna++;
            System.debug('SIN NINGUNA ORDEN: ' + c.ContractNumber + ' (AC_collected=' + c.SM_AC_collected__c + ')');
        } else if (allStatuses.contains('Completed')) {
            falsoPositivoCompleted++;
        } else {
            otro++;
            System.debug('OTRO (ordenes: ' + allStatuses + '): ' + c.ContractNumber);
        }
        if (c.SM_AC_collected__c == true) {
            falsoPositivoCollectedTrue++;
        }
    }
}

System.debug('=======================================================');
System.debug('Falso positivo (tiene orden AC Completed): ' + falsoPositivoCompleted);
System.debug('De esos, SM_AC_collected__c=true (confirmado cobrado): ' + falsoPositivoCollectedTrue);
System.debug('Genuinamente SIN ninguna orden AC: ' + genuinamenteSinNinguna);
System.debug('Otro (solo Canceled u otro estado raro): ' + otro);
