// Validación del contrato 800UU00000XeCYwYAN
String contractId = '800UU00000XeCYwYAN';

// 1. Consultar contrato básico primero
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
    System.debug('❌ ERROR: Contrato no encontrado');
    return;
}

Contract ctr = contracts[0];
System.debug('========================================');
System.debug('CONTRATO: ' + ctr.ContractNumber + ' (' + ctr.Id + ')');
System.debug('========================================');
System.debug('Status: ' + ctr.Status);
System.debug('Contract Type: ' + ctr.Contract_Type__c);
System.debug('Company Setting ID: ' + ctr.SM_Company_Setting__c);
System.debug('Payment Method ID: ' + ctr.SM_Payment_Method__c);
System.debug('Principal Contract: ' + ctr.Principal_Contract__c);
System.debug('');

System.debug('--- CAMPOS AC (Administration Cost) ---');
System.debug('SM_Requires_AC_Payment__c: ' + ctr.SM_Requires_AC_Payment__c);
System.debug('SM_Way_of_AC_Payment__c: ' + ctr.SM_Way_of_AC_Payment__c);
System.debug('SM_Total_AC__c: ' + ctr.SM_Total_AC__c);
System.debug('SM_AC_start_date__c: ' + ctr.SM_AC_start_date__c);
System.debug('SM_AC_Split_Date__c: ' + ctr.SM_AC_Split_Date__c);
System.debug('');

System.debug('--- CAMPOS SUBSCRIPTION ---');
System.debug('SM_Requires_RC_Payment__c: ' + ctr.SM_Requires_RC_Payment__c);
System.debug('SM_Way_of_Contract_Payment__c: ' + ctr.SM_Way_of_Contract_Payment__c);
System.debug('SM_Frecuency__c: ' + ctr.SM_Frecuency__c);
System.debug('SM_Monthly_offer__c: ' + ctr.SM_Monthly_offer__c);
System.debug('SM_Start_date__c: ' + ctr.SM_Start_date__c);
System.debug('SM_Plan_Months__c: ' + ctr.SM_Plan_Months__c);
System.debug('SM_Email_to_send_contract__c: ' + ctr.SM_Email_to_send_contract__c);
System.debug('');

// 2. ACH Orders existentes
System.debug('========================================');
System.debug('ACH ORDERS EXISTENTES');
System.debug('========================================');
List<SM_ACH_Order__c> achOrders = [
    SELECT Id, SM_Payment_Type__c, SM_Payment_Status__c, SM_Total__c
    FROM SM_ACH_Order__c
    WHERE SM_Contract__c = :contractId
];
System.debug('Total: ' + achOrders.size());
for(SM_ACH_Order__c order : achOrders) {
    System.debug('  - Type: ' + order.SM_Payment_Type__c + 
                 ', Status: ' + order.SM_Payment_Status__c + 
                 ', Total: ' + order.SM_Total__c);
}
System.debug('');

// 3. Campos requeridos configurados
System.debug('========================================');
System.debug('CAMPOS REQUERIDOS (SM_Required_Field_Info__c)');
System.debug('========================================');

List<SM_Required_Field_Info__c> reqFields = [
    SELECT Id, Name, SM_Api_Field_Name__c, SM_Process__c, SM_Company_Setting__c
    FROM SM_Required_Field_Info__c
    WHERE SM_Source_Object__c = 'Contract'
    AND SM_Company_Setting__c = :ctr.SM_Company_Setting__c
    AND SM_Process__c IN ('AC', 'Subscription')
    ORDER BY SM_Process__c, SM_Api_Field_Name__c
];

System.debug('Total campos requeridos configurados: ' + reqFields.size());

if(reqFields.isEmpty()) {
    System.debug('⚠️  NO HAY CAMPOS REQUERIDOS configurados para este Company Setting');
    System.debug('    Esto significa que la validación NO debería fallar.');
} else {
    System.debug('');
    Map<String, List<String>> fieldsByProcess = new Map<String, List<String>>();
    
    for(SM_Required_Field_Info__c rf : reqFields) {
        if(!fieldsByProcess.containsKey(rf.SM_Process__c)) {
            fieldsByProcess.put(rf.SM_Process__c, new List<String>());
        }
        fieldsByProcess.get(rf.SM_Process__c).add(rf.SM_Api_Field_Name__c);
    }
    
    // Validar cada campo requerido
    Integer totalVacios = 0;
    List<String> camposVacios = new List<String>();
    
    for(String processType : fieldsByProcess.keySet()) {
        System.debug('--- PROCESO: ' + processType + ' ---');
        
        for(String fieldName : fieldsByProcess.get(processType)) {
            Object fieldValue = ctr.get(fieldName);
            Boolean isNull = (fieldValue == null);
            String status = isNull ? '❌ VACÍO' : '✅ OK';
            
            System.debug(status + ' ' + fieldName + ' = ' + fieldValue);
            
            if(isNull) {
                totalVacios++;
                camposVacios.add(processType + '.' + fieldName);
            }
        }
        System.debug('');
    }
    
    System.debug('========================================');
    System.debug('RESUMEN DE VALIDACIÓN');
    System.debug('========================================');
    System.debug('Total campos requeridos: ' + reqFields.size());
    System.debug('Campos vacíos: ' + totalVacios);
    
    if(totalVacios > 0) {
        System.debug('');
        System.debug('🚨 CAMPOS QUE CAUSAN EL ERROR:');
        for(String campo : camposVacios) {
            System.debug('   - ' + campo);
        }
    } else {
        System.debug('✅ Todos los campos requeridos están completos');
    }
}

// 4. Payment Method
System.debug('');
System.debug('========================================');
System.debug('PAYMENT METHOD');
System.debug('========================================');

if(ctr.SM_Payment_Method__c != null) {
    List<SM_Payment_Method__c> pms = [
        SELECT Id, Name, RecordTypeId,
               SM_ACH_Account_Holder_Name__c,
               SM_ACH_Account_Number__c,
               SM_ACH_Routing_Number__c,
               SM_ACH_Account_Type__c,
               SM_Bank_Name__c,
               SM_Credit_Card_Franchise__c,
               SM_Credit_Card_Name__c,
               SM_Credit_Card_Number__c,
               SM_Chargent_Order__c
        FROM SM_Payment_Method__c
        WHERE Id = :ctr.SM_Payment_Method__c
    ];
    
    if(!pms.isEmpty()) {
        SM_Payment_Method__c pm = pms[0];
        System.debug('Payment Method: ' + pm.Name);
        System.debug('Record Type ID: ' + pm.RecordTypeId);
        
        // Verificar si es ACH
        System.debug('');
        System.debug('Campos ACH:');
        System.debug('  Holder Name: ' + pm.SM_ACH_Account_Holder_Name__c);
        System.debug('  Account Number: ' + pm.SM_ACH_Account_Number__c);
        System.debug('  Routing Number: ' + pm.SM_ACH_Routing_Number__c);
        System.debug('  Account Type: ' + pm.SM_ACH_Account_Type__c);
        System.debug('  Bank Name: ' + pm.SM_Bank_Name__c);
        
        System.debug('');
        System.debug('Campos Credit Card:');
        System.debug('  Franchise: ' + pm.SM_Credit_Card_Franchise__c);
        System.debug('  Name: ' + pm.SM_Credit_Card_Name__c);
        System.debug('  Number: ' + pm.SM_Credit_Card_Number__c);
        System.debug('  Chargent Order: ' + pm.SM_Chargent_Order__c);
    }
} else {
    System.debug('⚠️  Payment Method está VACÍO (NULL)');
}

System.debug('');
System.debug('========================================');
System.debug('FIN DEL ANÁLISIS');
System.debug('========================================');