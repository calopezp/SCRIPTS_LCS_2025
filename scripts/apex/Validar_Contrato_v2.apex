// Validación del contrato 800UU00000XeCYwYAN
String contractId = '800UU00000XeCYwYAN';

// 1. Consultar contrato
List<Contract> contracts = [
    SELECT Id, ContractNumber, Status,
           SM_Company_Setting__c,
           SM_Payment_Method__c,
           SM_Requires_AC_Payment__c,
           SM_Way_of_AC_Payment__c,
           SM_Total_AC__c,
           SM_AC_start_date__c,
           SM_AC_Split_Date__c,
           SM_Requires_RC_Payment__c,
           SM_Way_of_Contract_Payment__c,
           SM_Frecuency__c,
           SM_Monthly_offer__c,
           SM_Start_date__c,
           SM_Plan_Months__c,
           SM_Email_to_send_contract__c,
           Contract_Type__c,
           Principal_Contract__c
    FROM Contract
    WHERE Id = :contractId
];

if(contracts.isEmpty()) {
    System.debug('ERROR: Contrato no encontrado');
    return;
}

Contract ctr = contracts[0];
System.debug('======== CONTRATO ========');
System.debug('Number: ' + ctr.ContractNumber);
System.debug('Status: ' + ctr.Status);
System.debug('Type: ' + ctr.Contract_Type__c);
System.debug('Company Setting: ' + ctr.SM_Company_Setting__c);
System.debug('Payment Method: ' + ctr.SM_Payment_Method__c);
System.debug('');

System.debug('--- AC FIELDS ---');
System.debug('Requires AC: ' + ctr.SM_Requires_AC_Payment__c);
System.debug('Way AC: ' + ctr.SM_Way_of_AC_Payment__c);
System.debug('Total AC: ' + ctr.SM_Total_AC__c);
System.debug('AC Start: ' + ctr.SM_AC_start_date__c);
System.debug('AC Split: ' + ctr.SM_AC_Split_Date__c);
System.debug('');

System.debug('--- SUBSCRIPTION FIELDS ---');
System.debug('Requires RC: ' + ctr.SM_Requires_RC_Payment__c);
System.debug('Way Payment: ' + ctr.SM_Way_of_Contract_Payment__c);
System.debug('Frequency: ' + ctr.SM_Frecuency__c);
System.debug('Monthly: ' + ctr.SM_Monthly_offer__c);
System.debug('Start Date: ' + ctr.SM_Start_date__c);
System.debug('Plan Months: ' + ctr.SM_Plan_Months__c);
System.debug('Email: ' + ctr.SM_Email_to_send_contract__c);
System.debug('');

// 2. Campos requeridos
System.debug('======== REQUIRED FIELDS CONFIG ========');
List<SM_Required_Field_Info__c> reqFields = [
    SELECT Id, Name, SM_Api_Field_Name__c, SM_Process__c
    FROM SM_Required_Field_Info__c
    WHERE SM_Source_Object__c = 'Contract'
    AND SM_Company_Setting__c = :ctr.SM_Company_Setting__c
    AND SM_Process__c IN ('AC', 'Subscription')
    ORDER BY SM_Process__c, SM_Api_Field_Name__c
];

System.debug('Total required fields: ' + reqFields.size());

if(reqFields.isEmpty()) {
    System.debug('WARNING: No required fields configured');
} else {
    System.debug('');
    Integer emptyCount = 0;
    for(SM_Required_Field_Info__c rf : reqFields) {
        Object val = ctr.get(rf.SM_Api_Field_Name__c);
        Boolean isEmpty = (val == null);
        String status = isEmpty ? 'EMPTY' : 'OK';
        System.debug('[' + status + '] ' + rf.SM_Process__c + ' - ' + rf.SM_Api_Field_Name__c + ' = ' + val);
        if(isEmpty) emptyCount++;
    }
    System.debug('');
    System.debug('======== SUMMARY ========');
    System.debug('Total required: ' + reqFields.size());
    System.debug('Empty fields: ' + emptyCount);
    if(emptyCount > 0) {
        System.debug('STATUS: VALIDATION WILL FAIL');
    } else {
        System.debug('STATUS: VALIDATION SHOULD PASS');
    }
}

// 3. ACH Orders
System.debug('');
System.debug('======== ACH ORDERS ========');
List<SM_ACH_Order__c> orders = [
    SELECT Id, SM_Payment_Type__c, SM_Payment_Status__c
    FROM SM_ACH_Order__c
    WHERE SM_Contract__c = :contractId
];
System.debug('Total ACH Orders: ' + orders.size());
for(SM_ACH_Order__c ord : orders) {
    System.debug('  Type: ' + ord.SM_Payment_Type__c + ', Status: ' + ord.SM_Payment_Status__c);
}

// 4. Payment Method (campos básicos)
System.debug('');
System.debug('======== PAYMENT METHOD ========');
if(ctr.SM_Payment_Method__c != null) {
    List<SM_Payment_Method__c> pms = [
        SELECT Id, Name
        FROM SM_Payment_Method__c
        WHERE Id = :ctr.SM_Payment_Method__c
    ];
    if(!pms.isEmpty()) {
        System.debug('PM Found: ' + pms[0].Name);
    }
} else {
    System.debug('WARNING: Payment Method is NULL');
}

System.debug('');
System.debug('======== END ========');