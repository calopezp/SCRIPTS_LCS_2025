DateTime since = DateTime.now().addHours(-24);
List<Contract> recentContracts = [
    SELECT Id, ContractNumber FROM Contract
    WHERE SM_Payment_methods__c = 'ACH' AND Status IN ('Payment Process', 'Activated')
      AND CreatedDate >= :since
];
System.debug('Contratos ACH CREADOS en las ultimas 24h: ' + recentContracts.size());
for (Contract c : recentContracts) {
    System.debug('  - ' + c.ContractNumber);
}
