List<SM_Payment__c> reversedPayments = [
    SELECT Id, Name, SM_Amount__c, CreatedDate,
           Payment_Status__c, SM_Check_Collection_Status__c, SM_Check_Collection_Date__c,
           SM_Return_code__c, SM_Historical_Collection_Status__c,
           SM_Transmission_Date_ACH_File__c,
           SM_Contract__c, SM_Contract__r.ContractNumber, SM_Contract__r.Status,
           SM_Contract__r.Is_Test_Contract__c, SM_Contract__r.Is_VIP_Contract__c
    FROM SM_Payment__c
    WHERE SM_Historical_Collection_Status__c LIKE '%D_SIN_REPORTE:%'
    AND (
        Payment_Status__c = 'REJECTED'
        OR SM_Check_Collection_Status__c IN ('RETURN', 'NOT_COLLECTED', 'NOT COLLECTED', 'PENDING')
    )
    ORDER BY SM_Contract__r.ContractNumber, SM_Check_Collection_Date__c
];
List<SM_Payment__c> filteredPayments = new List<SM_Payment__c>();
for (SM_Payment__c p : reversedPayments) {
    if (p.SM_Contract__r != null
        && (p.SM_Contract__r.Is_Test_Contract__c == true || p.SM_Contract__r.Is_VIP_Contract__c == true)) {
        continue;
    }
    filteredPayments.add(p);
}
System.debug('TOTAL EN EL REPORTE: ' + filteredPayments.size());
String body = SM_ReturnCodeNotifier.buildTimeoutReversalReport(filteredPayments);
System.debug('===BODY START===');
System.debug(body);
System.debug('===BODY END===');
