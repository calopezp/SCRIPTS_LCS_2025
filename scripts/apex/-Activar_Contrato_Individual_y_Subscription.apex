// ============================================================
// Activa UN contrato (ya validado manualmente por ti) y crea su
// Subscription Order. Uso: cambia el ContractNumber abajo y corre.
// ============================================================

String contractNumber = '00318087';

Contract c = [
    SELECT Id, ContractNumber, Status, SM_Net_AC__c, SM_AC_Split_Date__c, SM_Payment_methods__c, SM_AC_collected__c,
           Contract_Type__c, Is_Test_Contract__c, Is_VIP_Contract__c, SM_Full_Payment__c,
           SM_Customer_Cancellation__c, SM_Requires_RC_Payment__c, SM_Billing_status__c,
           CB_Subscription__c, SM_Email_to_send_contract__c, SM_Start_date__c,
           SM_Net_Monthly_offer__c, SM_Payment_Method__c
    FROM Contract
    WHERE ContractNumber = :contractNumber
    LIMIT 1
];

// Marcado de campos / activación
c.Status = 'Activated';
c.SM_Charged_AC_Amount__c = c.SM_Net_AC__c;
c.SM_AC_collected__c = true;
c.SM_Payment_Received__c = true;
// Split (SM_AC_Split_Date__c poblado) = 2 cuotas; si no, 1. Tu ya validaste los pagos.
c.SM_Charged_AC_Fees__c = c.SM_AC_Split_Date__c != null ? 2 : 1;
update c;

// Crear Subscription Order (directo, no depende del disparo automático de CONTRACT_10)
Contract fresh = [
    SELECT Id, Status, SM_Payment_methods__c, SM_AC_collected__c,
           Contract_Type__c, Is_Test_Contract__c, Is_VIP_Contract__c, SM_Full_Payment__c,
           SM_Customer_Cancellation__c, SM_Requires_RC_Payment__c, SM_Billing_status__c,
           CB_Subscription__c, SM_Email_to_send_contract__c, SM_Start_date__c,
           SM_Net_Monthly_offer__c, SM_Payment_Method__c
    FROM Contract WHERE Id = :c.Id
];
Map<String, Object> params = new Map<String, Object>{ 'sf_Contract' => fresh };
Flow.Interview.CONTRACT_Create_ACH_Subscription_Order interview =
    new Flow.Interview.CONTRACT_Create_ACH_Subscription_Order(params);
interview.start();

Integer subCount = [SELECT COUNT() FROM SM_ACH_Order__c WHERE SM_Contract__c = :c.Id AND SM_Payment_Type__c = 'Subscription'];
System.debug('\u2192 ' + contractNumber + ' \uFF5C  Status=' + fresh.Status + ' \uFF5C  AC_collected=' + fresh.SM_AC_collected__c
    + ' \uFF5C  Split=' + (c.SM_AC_Split_Date__c != null) + ' \uFF5C  Fees=' + c.SM_Charged_AC_Fees__c
    + ' \uFF5C  Subscription Orders=' + subCount);
