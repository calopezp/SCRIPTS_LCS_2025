// Valida exclusiones: VIP, Test Contract, Cancelado, Dependent, Full Payment (=> Billing status PAYMENT COMPLETED)
// Cada contrato viola SOLO la condicion que se esta probando; el resto de campos son "elegibles"
Organization org = [SELECT Id, Name, IsSandbox FROM Organization LIMIT 1];
if (!org.IsSandbox) {
    throw new IllegalArgumentException('SOLO SANDBOX. Org actual: ' + org.Name);
}

Id personAccRT = '0121U0000003sLpQAI';
Id achPmRT = '0121U000000KY47QAG';

SM_Bank__c testBank = new SM_Bank__c(Name = 'Test Bank Exclusiones (TEST-CLAUDE)');
insert testBank;

List<Account> accs = new List<Account>{
    new Account(FirstName='ExVIP', LastName='Exclusion VIP (TEST-CLAUDE)', PersonEmail='ex.vip.claude@yopmail.com', RecordTypeId=personAccRT),
    new Account(FirstName='ExTest', LastName='Exclusion TestContract (TEST-CLAUDE)', PersonEmail='ex.test.claude@yopmail.com', RecordTypeId=personAccRT),
    new Account(FirstName='ExCanc', LastName='Exclusion Cancelado (TEST-CLAUDE)', PersonEmail='ex.canc.claude@yopmail.com', RecordTypeId=personAccRT),
    new Account(FirstName='ExDep', LastName='Exclusion Dependent (TEST-CLAUDE)', PersonEmail='ex.dep.claude@yopmail.com', RecordTypeId=personAccRT),
    new Account(FirstName='ExFull', LastName='Exclusion FullPayment (TEST-CLAUDE)', PersonEmail='ex.full.claude@yopmail.com', RecordTypeId=personAccRT)
};
insert accs;

List<SM_Payment_Method__c> pms = new List<SM_Payment_Method__c>();
for (Account a : accs) {
    pms.add(new SM_Payment_Method__c(RecordTypeId = achPmRT, SM_Account__c = a.Id, SM_Active__c = true, SM_Bank__c = testBank.Id));
}
insert pms;

Date acStart = Date.today().addDays(3);

List<Contract> cons = new List<Contract>{
    new Contract( // VIP
        AccountId=accs[0].Id, Status='Draft', StartDate=Date.today(), OwnerId=UserInfo.getUserId(),
        SM_Payment_Method__c=pms[0].Id, SM_Payment_methods__c='ACH', SM_Email_to_send_contract__c='ex.vip.claude@yopmail.com',
        SM_Requires_AC_Payment__c=true, SM_AC_start_date__c=acStart, SM_Total_ac__c=200.00, SM_Requires_RC_Payment__c=false,
        Is_Test_Contract__c=false, Is_VIP_Contract__c=true, SM_Customer_Cancellation__c=false, SM_Full_Payment__c=false,
        Description='TEST-CLAUDE EXCL: VIP=true, NO debe crear AC order'
    ),
    new Contract( // Test Contract
        AccountId=accs[1].Id, Status='Draft', StartDate=Date.today(), OwnerId=UserInfo.getUserId(),
        SM_Payment_Method__c=pms[1].Id, SM_Payment_methods__c='ACH', SM_Email_to_send_contract__c='ex.test.claude@yopmail.com',
        SM_Requires_AC_Payment__c=true, SM_AC_start_date__c=acStart, SM_Total_ac__c=200.00, SM_Requires_RC_Payment__c=false,
        Is_Test_Contract__c=true, Is_VIP_Contract__c=false, SM_Customer_Cancellation__c=false, SM_Full_Payment__c=false,
        Description='TEST-CLAUDE EXCL: Is_Test_Contract=true, NO debe crear AC order'
    ),
    new Contract( // Cancelado
        AccountId=accs[2].Id, Status='Draft', StartDate=Date.today(), OwnerId=UserInfo.getUserId(),
        SM_Payment_Method__c=pms[2].Id, SM_Payment_methods__c='ACH', SM_Email_to_send_contract__c='ex.canc.claude@yopmail.com',
        SM_Requires_AC_Payment__c=true, SM_AC_start_date__c=acStart, SM_Total_ac__c=200.00, SM_Requires_RC_Payment__c=false,
        Is_Test_Contract__c=false, Is_VIP_Contract__c=false, SM_Customer_Cancellation__c=true, SM_Full_Payment__c=false,
        Description='TEST-CLAUDE EXCL: Cancelacion=true, NO debe crear AC order'
    ),
    new Contract( // Dependent
        AccountId=accs[3].Id, Status='Draft', StartDate=Date.today(), OwnerId=UserInfo.getUserId(),
        SM_Payment_Method__c=pms[3].Id, SM_Payment_methods__c='ACH', SM_Email_to_send_contract__c='ex.dep.claude@yopmail.com',
        SM_Requires_AC_Payment__c=true, SM_AC_start_date__c=acStart, SM_Total_ac__c=200.00, SM_Requires_RC_Payment__c=false,
        Is_Test_Contract__c=false, Is_VIP_Contract__c=false, SM_Customer_Cancellation__c=false, SM_Full_Payment__c=false,
        Contract_Type__c='Dependent',
        Description='TEST-CLAUDE EXCL: Contract_Type=Dependent, NO debe crear AC order'
    ),
    new Contract( // Full payment (=> Billing_status = PAYMENT COMPLETED)
        AccountId=accs[4].Id, Status='Draft', StartDate=Date.today(), OwnerId=UserInfo.getUserId(),
        SM_Payment_Method__c=pms[4].Id, SM_Payment_methods__c='ACH', SM_Email_to_send_contract__c='ex.full.claude@yopmail.com',
        SM_Requires_AC_Payment__c=true, SM_AC_start_date__c=acStart, SM_Total_ac__c=200.00, SM_Requires_RC_Payment__c=false,
        Is_Test_Contract__c=false, Is_VIP_Contract__c=false, SM_Customer_Cancellation__c=false, SM_Full_Payment__c=true,
        Description='TEST-CLAUDE EXCL: Full_Payment=true, NO debe crear AC order'
    )
};
insert cons;
System.debug(' -> Contratos exclusion creados (Draft)');

for (Contract c : cons) { c.Status = 'Payment Process'; }
update cons;
System.debug(' -> Contratos exclusion movidos a Payment Process');

Set<Id> conIds = new Set<Id>();
for (Contract c : cons) conIds.add(c.Id);

List<Contract> check = [SELECT Id, ContractNumber, Status, Is_VIP_Contract__c, Is_Test_Contract__c, SM_Customer_Cancellation__c, Contract_Type__c, SM_Full_Payment__c, SM_Billing_status__c FROM Contract WHERE Id IN :conIds];
Map<Id,SM_ACH_Order__c[]> ordersByContract = new Map<Id,SM_ACH_Order__c[]>();
for (SM_ACH_Order__c o : [SELECT Id, SM_Contract__c, SM_Payment_Type__c FROM SM_ACH_Order__c WHERE SM_Contract__c IN :conIds]) {
    if (!ordersByContract.containsKey(o.SM_Contract__c)) ordersByContract.put(o.SM_Contract__c, new List<SM_ACH_Order__c>());
    ordersByContract.get(o.SM_Contract__c).add(o);
}

for (Contract c : check) {
    Integer n = ordersByContract.containsKey(c.Id) ? ordersByContract.get(c.Id).size() : 0;
    System.debug(' -> ' + c.ContractNumber + ' | VIP=' + c.Is_VIP_Contract__c + ' Test=' + c.Is_Test_Contract__c
        + ' Cancel=' + c.SM_Customer_Cancellation__c + ' Type=' + c.Contract_Type__c + ' FullPay=' + c.SM_Full_Payment__c
        + ' BillingStatus=' + c.SM_Billing_status__c + ' || ACH_Orders_creadas=' + n + (n == 0 ? '  [OK excluido]' : '  [FALLO: no debio crear]'));
}
