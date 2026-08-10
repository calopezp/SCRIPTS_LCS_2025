// Script para validar el contrato 800UU00000XeCYwYAN
// Verificar datos del contrato y campos requeridos

String contractId = '800UU00000XeCYwYAN';

// 1. Consultar el contrato con todos los campos relevantes
Contract ctr = [
    SELECT Id, ContractNumber, Status, Contract_Type__c,
           AccountId, Account.Name,
           SM_Company_Setting__c, SM_Company_Setting__r.Name,
           SM_Payment_Method__c, SM_Payment_Method__r.Name,
           SM_Payment_Method__r.RecordType.DeveloperName,
           
           // Campos de AC (Administration Cost)
           SM_Requires_AC_Payment__c,
           SM_Way_of_AC_Payment__c,
           SM_Total_AC__c,
           SM_AC_start_date__c,
           SM_AC_Split_Date__c,
           
           // Campos de Subscription/Fee
           SM_Requires_RC_Payment__c,
           SM_Way_of_Contract_Payment__c,
           SM_Frecuency__c,
           SM_Monthly_offer__c,
           SM_Start_date__c,
           SM_Plan_Months__c,
           SM_Email_to_send_contract__c,
           
           // Otros campos
           Principal_Contract__c,
           SM_Registered_Card_Token__c,
           
           // ACH Orders existentes
           (SELECT Id, SM_Payment_Type__c, SM_Payment_Status__c, SM_Total__c 
            FROM ACH_Orders__r)
    FROM Contract
    WHERE Id = :contractId
    LIMIT 1
];

System.debug('========================================');
System.debug('DATOS DEL CONTRATO: ' + ctr.ContractNumber);
System.debug('========================================');
System.debug('Status: ' + ctr.Status);
System.debug('Contract Type: ' + ctr.Contract_Type__c);
System.debug('Account: ' + ctr.Account.Name);
System.debug('Company Setting: ' + ctr.SM_Company_Setting__r.Name);
System.debug('Payment Method: ' + ctr.SM_Payment_Method__r.Name);
System.debug('Payment Method Type: ' + ctr.SM_Payment_Method__r.RecordType.DeveloperName);
System.debug('');

System.debug('--- CAMPOS AC (Administration Cost) ---');
System.debug('SM_Requires_AC_Payment__c: ' + ctr.SM_Requires_AC_Payment__c);
System.debug('SM_Way_of_AC_Payment__c: ' + ctr.SM_Way_of_AC_Payment__c);
System.debug('SM_Total_AC__c: ' + ctr.SM_Total_AC__c);
System.debug('SM_AC_start_date__c: ' + ctr.SM_AC_start_date__c);
System.debug('SM_AC_Split_Date__c: ' + ctr.SM_AC_Split_Date__c);
System.debug('');

System.debug('--- CAMPOS SUBSCRIPTION/FEE ---');
System.debug('SM_Requires_RC_Payment__c: ' + ctr.SM_Requires_RC_Payment__c);
System.debug('SM_Way_of_Contract_Payment__c: ' + ctr.SM_Way_of_Contract_Payment__c);
System.debug('SM_Frecuency__c: ' + ctr.SM_Frecuency__c);
System.debug('SM_Monthly_offer__c: ' + ctr.SM_Monthly_offer__c);
System.debug('SM_Start_date__c: ' + ctr.SM_Start_date__c);
System.debug('SM_Plan_Months__c: ' + ctr.SM_Plan_Months__c);
System.debug('SM_Email_to_send_contract__c: ' + ctr.SM_Email_to_send_contract__c);
System.debug('');

System.debug('--- OTROS CAMPOS ---');
System.debug('Principal_Contract__c: ' + ctr.Principal_Contract__c);
System.debug('SM_Registered_Card_Token__c: ' + ctr.SM_Registered_Card_Token__c);
System.debug('');

System.debug('--- ACH ORDERS EXISTENTES ---');
System.debug('Total ACH Orders: ' + ctr.ACH_Orders__r.size());
for(SM_ACH_Order__c order : ctr.ACH_Orders__r) {
    System.debug('  - Type: ' + order.SM_Payment_Type__c + 
                 ', Status: ' + order.SM_Payment_Status__c + 
                 ', Total: ' + order.SM_Total__c);
}
System.debug('');

// 2. Consultar los campos requeridos según SM_Required_Field_Info__c
System.debug('========================================');
System.debug('CAMPOS REQUERIDOS CONFIGURADOS');
System.debug('========================================');

List<SM_Required_Field_Info__c> requiredFields = [
    SELECT Id, Name, SM_Api_Field_Name__c, SM_Process__c, 
           SM_Company_Setting__c, SM_Company_Setting__r.Name
    FROM SM_Required_Field_Info__c
    WHERE SM_Source_Object__c = 'Contract'
    AND SM_Company_Setting__c = :ctr.SM_Company_Setting__c
    AND SM_Process__c IN ('AC', 'Subscription')
    ORDER BY SM_Process__c, SM_Api_Field_Name__c
];

if(requiredFields.isEmpty()) {
    System.debug('⚠️ NO HAY CAMPOS REQUERIDOS CONFIGURADOS para este Company Setting');
} else {
    Map<String, List<String>> fieldsByProcess = new Map<String, List<String>>();
    
    for(SM_Required_Field_Info__c rf : requiredFields) {
        if(!fieldsByProcess.containsKey(rf.SM_Process__c)) {
            fieldsByProcess.put(rf.SM_Process__c, new List<String>());
        }
        fieldsByProcess.get(rf.SM_Process__c).add(rf.SM_Api_Field_Name__c);
    }
    
    for(String processType : fieldsByProcess.keySet()) {
        System.debug('');
        System.debug('--- PROCESO: ' + processType + ' ---');
        
        for(String fieldName : fieldsByProcess.get(processType)) {
            Object fieldValue = ctr.get(fieldName);
            String status = (fieldValue == null) ? '❌ VACÍO' : '✅ OK';
            System.debug(status + ' ' + fieldName + ' = ' + fieldValue);
        }
    }
}

// 3. Consultar datos del Payment Method si existe
if(ctr.SM_Payment_Method__c != null) {
    System.debug('');
    System.debug('========================================');
    System.debug('DATOS DEL PAYMENT METHOD (ACH)');
    System.debug('========================================');
    
    SM_Payment_Method__c pm = [
        SELECT Id, Name, RecordType.DeveloperName,
               SM_Account__c, SM_Account__r.Name,
               SM_Chargent_Order__c,
               SM_Credit_Card_Franchise__c,
               SM_Credit_Card_Name__c,
               SM_Credit_Card_Number__c,
               SM_Credit_Card_expiration_month__c,
               SM_Credit_Card_expiration_year__c,
               SM_Card_Token__c,
               
               // Campos ACH específicos (si existen)
               SM_ACH_Account_Holder_Name__c,
               SM_ACH_Account_Number__c,
               SM_ACH_Routing_Number__c,
               SM_ACH_Account_Type__c,
               SM_Bank_Name__c
        FROM SM_Payment_Method__c
        WHERE Id = :ctr.SM_Payment_Method__c
        LIMIT 1
    ];
    
    System.debug('Payment Method Name: ' + pm.Name);
    System.debug('Record Type: ' + pm.RecordType.DeveloperName);
    System.debug('Account: ' + pm.SM_Account__r.Name);
    System.debug('Chargent Order: ' + pm.SM_Chargent_Order__c);
    System.debug('');
    
    if(pm.RecordType.DeveloperName == 'ACH') {
        System.debug('--- CAMPOS ACH ---');
        System.debug('SM_ACH_Account_Holder_Name__c: ' + pm.SM_ACH_Account_Holder_Name__c);
        System.debug('SM_ACH_Account_Number__c: ' + pm.SM_ACH_Account_Number__c);
        System.debug('SM_ACH_Routing_Number__c: ' + pm.SM_ACH_Routing_Number__c);
        System.debug('SM_ACH_Account_Type__c: ' + pm.SM_ACH_Account_Type__c);
        System.debug('SM_Bank_Name__c: ' + pm.SM_Bank_Name__c);
        
        // Validar campos ACH vacíos
        List<String> emptyACHFields = new List<String>();
        if(pm.SM_ACH_Account_Holder_Name__c == null) emptyACHFields.add('SM_ACH_Account_Holder_Name__c');
        if(pm.SM_ACH_Account_Number__c == null) emptyACHFields.add('SM_ACH_Account_Number__c');
        if(pm.SM_ACH_Routing_Number__c == null) emptyACHFields.add('SM_ACH_Routing_Number__c');
        if(pm.SM_ACH_Account_Type__c == null) emptyACHFields.add('SM_ACH_Account_Type__c');
        
        if(!emptyACHFields.isEmpty()) {
            System.debug('');
            System.debug('❌ CAMPOS ACH VACÍOS: ' + String.join(emptyACHFields, ', '));
        } else {
            System.debug('');
            System.debug('✅ Todos los campos ACH están completos');
        }
    } else if(pm.RecordType.DeveloperName == 'Credit_Card') {
        System.debug('--- CAMPOS TARJETA DE CRÉDITO ---');
        System.debug('SM_Credit_Card_Franchise__c: ' + pm.SM_Credit_Card_Franchise__c);
        System.debug('SM_Credit_Card_Name__c: ' + pm.SM_Credit_Card_Name__c);
        System.debug('SM_Credit_Card_Number__c: ' + pm.SM_Credit_Card_Number__c);
        System.debug('SM_Credit_Card_expiration_month__c: ' + pm.SM_Credit_Card_expiration_month__c);
        System.debug('SM_Credit_Card_expiration_year__c: ' + pm.SM_Credit_Card_expiration_year__c);
        System.debug('SM_Card_Token__c: ' + pm.SM_Card_Token__c);
    }
}

System.debug('');
System.debug('========================================');
System.debug('FIN DEL ANÁLISIS');
System.debug('========================================');