Set<String> allCodes = new Set<String>{ 'R02', 'R04', 'R13', 'R10', 'R07', 'R16' };
List<SM_Payment__c> codePayments = [
    SELECT Id, Name, SM_Amount__c, CreatedDate, SM_Return_code__c,
           SM_Contract__c, SM_Contract__r.ContractNumber, SM_Contract__r.Status,
           SM_Contract__r.SM_Customer_Cancellation__c,
           SM_Contract__r.Is_Test_Contract__c, SM_Contract__r.Is_VIP_Contract__c
    FROM SM_Payment__c
    WHERE SM_Return_code__c IN :allCodes
    ORDER BY SM_Contract__r.ContractNumber, CreatedDate
];
Set<Id> contractIds = new Set<Id>();
for (SM_Payment__c p : codePayments) { if (p.SM_Contract__c != null) contractIds.add(p.SM_Contract__c); }
List<SM_Payment__c> acceptedSince = contractIds.isEmpty() ? new List<SM_Payment__c>() : [
    SELECT SM_Contract__c, CreatedDate FROM SM_Payment__c
    WHERE SM_Contract__c IN :contractIds AND Payment_Status__c = 'ACCEPTED'
];
String body = SM_ReturnCodeNotifier.buildWeeklyComercialDigest(codePayments, acceptedSince, Date.today().addDays(-7));
System.debug('===BODY START===');
System.debug(body);
System.debug('===BODY END===');
System.debug('LENGTH: ' + body.length());
