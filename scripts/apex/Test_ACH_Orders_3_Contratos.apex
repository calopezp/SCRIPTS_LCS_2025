// Script de prueba: 3 contratos para validar CONTRACT_10 / CONTRACT_Create_ACH_AC_Order / CONTRACT_Create_ACH_Subscription_Order
// 1) AC simple (sin split)  2) AC con split  3) Subscription (via cobro simulado de AC)

Organization org = [SELECT Id, Name, IsSandbox FROM Organization LIMIT 1];
if (!org.IsSandbox) {
    throw new IllegalArgumentException('Este script solo puede ejecutarse en SANDBOX. Org actual: ' + org.Name);
}

Id personAccRT = '0121U0000003sLpQAI';
Id achPmRT = '0121U000000KY47QAG';
Id contractRT = '0128W000000Jw4tQAC'; // SM_MASTER

SM_Bank__c testBank = new SM_Bank__c(Name = 'Test Bank (TEST-CLAUDE)');
insert testBank;
System.debug(' -> Bank creado: ' + testBank.Id);

List<Account> accs = new List<Account>{
    new Account(FirstName='Test1', LastName='ACH Simple (TEST-CLAUDE)', PersonEmail='test1.ach.claude@yopmail.com', RecordTypeId=personAccRT),
    new Account(FirstName='Test2', LastName='ACH Split (TEST-CLAUDE)', PersonEmail='test2.ach.claude@yopmail.com', RecordTypeId=personAccRT),
    new Account(FirstName='Test3', LastName='Subscription (TEST-CLAUDE)', PersonEmail='test3.ach.claude@yopmail.com', RecordTypeId=personAccRT)
};
insert accs;
System.debug(' -> Accounts creadas: ' + accs[0].Id + ', ' + accs[1].Id + ', ' + accs[2].Id);

List<SM_Payment_Method__c> pms = new List<SM_Payment_Method__c>();
for (Account a : accs) {
    pms.add(new SM_Payment_Method__c(
        RecordTypeId = achPmRT,
        SM_Account__c = a.Id,
        SM_Active__c = true,
        SM_Bank__c = testBank.Id
    ));
}
insert pms;
System.debug(' -> Payment Methods ACH creados: ' + pms[0].Id + ', ' + pms[1].Id + ', ' + pms[2].Id);

Date acStart = Date.today().addDays(3);
Date splitDate = acStart.addDays(15);
Date rcStart = Date.today().addDays(30);

// ===== Contrato 1: Probar AC (sin split) =====
Contract c1 = new Contract(
    AccountId = accs[0].Id,
    Status = 'Draft',
    StartDate = Date.today(),
    OwnerId = UserInfo.getUserId(),
    SM_Payment_Method__c = pms[0].Id,
    SM_Payment_methods__c = 'ACH',
    SM_Email_to_send_contract__c = 'test1.ach.claude@yopmail.com',
    SM_Requires_AC_Payment__c = true,
    SM_AC_start_date__c = acStart,
    SM_Total_ac__c = 200.00,
    SM_Requires_RC_Payment__c = false,
    Is_Test_Contract__c = false,
    Is_VIP_Contract__c = false,
    SM_Customer_Cancellation__c = false,
    SM_Full_Payment__c = false,
    Description = 'TEST-CLAUDE 1: Probar AC sin split'
);

// ===== Contrato 2: Probar AC con split =====
Contract c2 = new Contract(
    AccountId = accs[1].Id,
    Status = 'Draft',
    StartDate = Date.today(),
    OwnerId = UserInfo.getUserId(),
    SM_Payment_Method__c = pms[1].Id,
    SM_Payment_methods__c = 'ACH',
    SM_Email_to_send_contract__c = 'test2.ach.claude@yopmail.com',
    SM_Requires_AC_Payment__c = true,
    SM_AC_start_date__c = acStart,
    SM_AC_Split_Date__c = splitDate,
    SM_Total_ac__c = 200.00,
    SM_Requires_RC_Payment__c = false,
    Is_Test_Contract__c = false,
    Is_VIP_Contract__c = false,
    SM_Customer_Cancellation__c = false,
    SM_Full_Payment__c = false,
    Description = 'TEST-CLAUDE 2: Probar AC con split'
);

// ===== Contrato 3: Crear Subscription (via AC cobrado) =====
Contract c3 = new Contract(
    AccountId = accs[2].Id,
    Status = 'Draft',
    StartDate = Date.today(),
    OwnerId = UserInfo.getUserId(),
    SM_Payment_Method__c = pms[2].Id,
    SM_Payment_methods__c = 'ACH',
    SM_Email_to_send_contract__c = 'test3.ach.claude@yopmail.com',
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
    Description = 'TEST-CLAUDE 3: Crear Subscription'
);

insert new List<Contract>{c1, c2, c3};
System.debug(' -> Contratos creados (Draft): C1=' + c1.Id + ' C2=' + c2.Id + ' C3=' + c3.Id);

// Mover a Payment Process (dispara CONTRACT_10 -> Contract_Updated_Status -> AC_Order_from_Update)
c1.Status = 'Payment Process';
c2.Status = 'Payment Process';
c3.Status = 'Payment Process';
update new List<Contract>{c1, c2, c3};
System.debug(' -> Contratos movidos a Payment Process');

// Simular que el AC de c3 fue cobrado (dispara CONTRACT_05 -> AC_collected=true + Status=Activated -> CONTRACT_10 -> Subscription order)
c3.SM_Charged_AC_Amount__c = c3.SM_Total_ac__c;
update c3;
System.debug(' -> C3 actualizado con SM_Charged_AC_Amount__c = SM_Total_ac__c (simula cobro)');

System.debug(' -> ========================================');
System.debug(' -> IDs para verificacion:');
System.debug(' -> Contrato 1 (AC simple):   ' + c1.Id);
System.debug(' -> Contrato 2 (AC split):    ' + c2.Id);
System.debug(' -> Contrato 3 (Subscription):' + c3.Id);
System.debug(' -> ========================================');
