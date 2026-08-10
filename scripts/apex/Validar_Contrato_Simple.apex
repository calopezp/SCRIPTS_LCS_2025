// Validación simple del contrato 800UU00000XeCYwYAN
String contractId = '800UU00000XeCYwYAN';

// Consultar contrato
List<Contract> contracts = [
    SELECT Id, ContractNumber, 
           SM_Company_Setting__c,
           SM_Payment_Method__c,
           SM_Requires_AC_Payment__c,
           SM_Way_of_AC_Payment__c,
           SM_Total_AC__c,
           SM_AC_start_date__c,
           SM_Requires_RC_Payment__c,
           SM_Way_of_Contract_Payment__c,
           SM_Frecuency__c,
           SM_Monthly_offer__c,
           SM_Start_date__c,
           SM_Email_to_send_contract__c
    FROM Contract
    WHERE Id = :contractId
];

if(contracts.isEmpty()) {
    System.debug('ERROR: Contrato no encontrado');
    return;
}

Contract ctr = contracts[0];
System.debug('=== CONTRATO: ' + ctr.ContractNumber + ' ===');
System.debug('Company Setting: ' + ctr.SM_Company_Setting__c);
System.debug('Payment Method: ' + ctr.SM_Payment_Method__c);

// Campos AC
System.debug('\n--- AC ---');
System.debug('Requires AC: ' + ctr.SM_Requires_AC_Payment__c);
System.debug('Way AC: ' + ctr.SM_Way_of_AC_Payment__c);
System.debug('Total AC: ' + ctr.SM_Total_AC__c);
System.debug('AC Start: ' + ctr.SM_AC_start_date__c);

// Campos Subscription
System.debug('\n--- SUBSCRIPTION ---');
System.debug('Requires RC: ' + ctr.SM_Requires_RC_Payment__c);
System.debug('Way Payment: ' + ctr.SM_Way_of_Contract_Payment__c);
System.debug('Frecuency: ' + ctr.SM_Frecuency__c);
System.debug('Monthly: ' + ctr.SM_Monthly_offer__c);
System.debug('Start Date: ' + ctr.SM_Start_date__c);
System.debug('Email: ' + ctr.SM_Email_to_send_contract__c);

// Campos requeridos
System.debug('\n=== CAMPOS REQUERIDOS ===');
List<SM_Required_Field_Info__c> reqFields = [
    SELECT SM_Api_Field_Name__c, SM_Process__c
    FROM SM_Required_Field_Info__c
    WHERE SM_Source_Object__c = 'Contract'
    AND SM_Company_Setting__c = :ctr.SM_Company_Setting__c
    AND SM_Process__c IN ('AC', 'Subscription')
];

System.debug('Total campos requeridos: ' + reqFields.size());
for(SM_Required_Field_Info__c rf : reqFields) {
    Object val = ctr.get(rf.SM_Api_Field_Name__c);
    String estado = (val == null) ? 'VACIO' : 'OK';
    System.debug(rf.SM_Process__c + ' - ' + rf.SM_Api_Field_Name__c + ': ' + estado + ' = ' + val);
}

// Payment Method
if(ctr.SM_Payment_Method__c != null) {
    System.debug('\n=== PAYMENT METHOD ===');
    List<SM_Payment_Method__c> pms = [
        SELECT Id, Name, RecordType.DeveloperName,
               SM_ACH_Account_Holder_Name__c,
               SM_ACH_Account_Number__c,
               SM_ACH_Routing_Number__c
        FROM SM_Payment_Method__c
        WHERE Id = :ctr.SM_Payment_Method__c
    ];
    if(!pms.isEmpty()) {
        SM_Payment_Method__c pm = pms[0];
        System.debug('Name: ' + pm.Name);
        System.debug('Type: ' + pm.RecordType.DeveloperName);
        System.debug('Holder: ' + pm.SM_ACH_Account_Holder_Name__c);
        System.debug('Account: ' + pm.SM_ACH_Account_Number__c);
        System.debug('Routing: ' + pm.SM_ACH_Routing_Number__c);
    }
}