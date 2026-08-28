// Valida: si el AC NO esta pagado completamente, NO debe crearse la orden Subscription
Organization org = [SELECT Id, Name, IsSandbox FROM Organization LIMIT 1];
if (!org.IsSandbox) {
    throw new IllegalArgumentException('Este script solo puede ejecutarse en SANDBOX. Org actual: ' + org.Name);
}

Id personAccRT = '0121U0000003sLpQAI';
Id achPmRT = '0121U000000KY47QAG';

SM_Bank__c testBank = new SM_Bank__c(Name = 'Test Bank 4 (TEST-CLAUDE)');
insert testBank;

Account acc = new Account(FirstName='Test4', LastName='AC Parcial (TEST-CLAUDE)', PersonEmail='test4.ach.claude@yopmail.com', RecordTypeId=personAccRT);
insert acc;

SM_Payment_Method__c pm = new SM_Payment_Method__c(
    RecordTypeId = achPmRT,
    SM_Account__c = acc.Id,
    SM_Active__c = true,
    SM_Bank__c = testBank.Id
);
insert pm;

Date acStart = Date.today().addDays(3);
Date rcStart = Date.today().addDays(30);

Contract c4 = new Contract(
    AccountId = acc.Id,
    Status = 'Draft',
    StartDate = Date.today(),
    OwnerId = UserInfo.getUserId(),
    SM_Payment_Method__c = pm.Id,
    SM_Payment_methods__c = 'ACH',
    SM_Email_to_send_contract__c = 'test4.ach.claude@yopmail.com',
    SM_Requires_AC_Payment__c = true,
    SM_AC_start_date__c = acStart,
    SM_Total_ac__c = 100.00,
    SM_Requires_RC_Payment__c = true,
    SM_Start_date__c = rcStart,
    SM_Monthly_offer__c = 75.00,
    Is_Test_Contract__c = false,
    Is_VIP_Contract__c = false,
    SM_Customer_Cancellation__c = false,
    SM_Full_Payment__c = false,
    Description = 'TEST-CLAUDE 4: AC pago PARCIAL - NO debe crear Subscription'
);
insert c4;
System.debug(' -> Contrato 4 creado (Draft): ' + c4.Id);

c4.Status = 'Payment Process';
update c4;
System.debug(' -> Contrato 4 movido a Payment Process');

// Simular pago PARCIAL del AC (60 de 100, NO igual al total)
c4.SM_Charged_AC_Amount__c = 60.00;
update c4;
System.debug(' -> Contrato 4: pago parcial simulado (60.00 de 100.00)');

Contract check = [SELECT Id, ContractNumber, Status, SM_AC_collected__c, SM_Charged_AC_Amount__c, SM_Total_ac__c FROM Contract WHERE Id = :c4.Id];
System.debug(' -> RESULTADO: Status=' + check.Status + ' AC_collected=' + check.SM_AC_collected__c
    + ' Charged=' + check.SM_Charged_AC_Amount__c + ' Total=' + check.SM_Total_ac__c);

List<SM_ACH_Order__c> orders = [SELECT Id, SM_Payment_Type__c, SM_Total__c, SM_Payment_Status__c FROM SM_ACH_Order__c WHERE SM_Contract__c = :c4.Id];
System.debug(' -> ACH Orders para C4: ' + orders.size());
for (SM_ACH_Order__c o : orders) {
    System.debug('    ' + o.SM_Payment_Type__c + ' | Total=' + o.SM_Total__c + ' | Status=' + o.SM_Payment_Status__c);
}
System.debug(' -> ContractNumber C4: ' + check.ContractNumber);
