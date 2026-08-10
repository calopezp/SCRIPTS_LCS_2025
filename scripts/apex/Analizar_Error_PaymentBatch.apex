// Script para analizar el error "Argument Can't be null" en SM_PaymentBatch

System.debug('=====================================');
System.debug('ANÁLISIS ERROR PAYMENT BATCH');
System.debug('=====================================');
System.debug('');

// Causas comunes de "Argument Can't be null":
// 1. Map.get() con null
// 2. oldRecordsMap?.get() cuando oldRecordsMap es null
// 3. String.split() con null
// 4. Campos lookup null
// 5. Parámetros de métodos null

System.debug('POSIBLES CAUSAS DEL ERROR:');
System.debug('');

// Buscar Payments recientes con campos null que podrían causar problemas
System.debug('1. PAYMENTS CON CAMPOS NULL CRÍTICOS:');
System.debug('');

List<SM_Payment__c> paymentsWithNulls = [
    SELECT Id, Name,
           SM_Contract__c,
           SM_ACH_Order__c,
           SM_Chargent_Orders_Transaction__c,
           Payment_Status__c,
           SM_Type__c,
           RecordType.DeveloperName
    FROM SM_Payment__c
    WHERE CreatedDate = LAST_N_DAYS:7
    AND (SM_Contract__c = NULL 
         OR SM_ACH_Order__c = NULL)
    ORDER BY CreatedDate DESC
    LIMIT 10
];

if (paymentsWithNulls.isEmpty()) {
    System.debug('✅ No hay Payments recientes con campos críticos NULL');
} else {
    System.debug('⚠️ Payments con campos NULL:');
    for (SM_Payment__c p : paymentsWithNulls) {
        System.debug('  - Id: ' + p.Id);
        System.debug('    Name: ' + p.Name);
        System.debug('    Contract: ' + p.SM_Contract__c);
        System.debug('    ACH Order: ' + p.SM_ACH_Order__c);
        System.debug('    Transaction: ' + p.SM_Chargent_Orders_Transaction__c);
        System.debug('    Type: ' + p.SM_Type__c);
        System.debug('    Status: ' + p.Payment_Status__c);
        System.debug('');
    }
}

// Buscar ACH Orders con campos null
System.debug('2. ACH ORDERS CON CAMPOS NULL:');
System.debug('');

List<SM_ACH_Order__c> achOrdersWithNulls = [
    SELECT Id, Name,
           SM_Contract__c,
           SM_Payment_Type__c,
           SM_Payment_Method__c,
           SM_Payment_Frequency__c,
           SM_Billing_Email__c
    FROM SM_ACH_Order__c
    WHERE CreatedDate = LAST_N_DAYS:7
    AND (SM_Contract__c = NULL
         OR SM_Payment_Method__c = NULL
         OR SM_Payment_Frequency__c = NULL)
    ORDER BY CreatedDate DESC
    LIMIT 10
];

if (achOrdersWithNulls.isEmpty()) {
    System.debug('✅ No hay ACH Orders recientes con campos críticos NULL');
} else {
    System.debug('⚠️ ACH Orders con campos NULL:');
    for (SM_ACH_Order__c ach : achOrdersWithNulls) {
        System.debug('  - Id: ' + ach.Id);
        System.debug('    Name: ' + ach.Name);
        System.debug('    Contract: ' + ach.SM_Contract__c);
        System.debug('    Payment Type: ' + ach.SM_Payment_Type__c);
        System.debug('    Payment Method: ' + ach.SM_Payment_Method__c);
        System.debug('    Frequency: ' + ach.SM_Payment_Frequency__c);
        System.debug('    Email: ' + ach.SM_Billing_Email__c);
        System.debug('');
    }
}

// Buscar Chargent Orders con campos null
System.debug('3. CHARGENT ORDERS CON CAMPOS NULL:');
System.debug('');

List<ChargentOrders__ChargentOrder__c> chargentOrdersWithNulls = [
    SELECT Id, Name,
           Contract__c,
           SM_Payment_Type__c,
           ChargentOrders__Payment_Frequency__c,
           ChargentOrders__Billing_Email__c
    FROM ChargentOrders__ChargentOrder__c
    WHERE CreatedDate = LAST_N_DAYS:7
    AND (Contract__c = NULL
         OR ChargentOrders__Payment_Frequency__c = NULL)
    ORDER BY CreatedDate DESC
    LIMIT 10
];

if (chargentOrdersWithNulls.isEmpty()) {
    System.debug('✅ No hay Chargent Orders recientes con campos críticos NULL');
} else {
    System.debug('⚠️ Chargent Orders con campos NULL:');
    for (ChargentOrders__ChargentOrder__c co : chargentOrdersWithNulls) {
        System.debug('  - Id: ' + co.Id);
        System.debug('    Name: ' + co.Name);
        System.debug('    Contract: ' + co.Contract__c);
        System.debug('    Payment Type: ' + co.SM_Payment_Type__c);
        System.debug('    Frequency: ' + co.ChargentOrders__Payment_Frequency__c);
        System.debug('    Email: ' + co.ChargentOrders__Billing_Email__c);
        System.debug('');
    }
}

// Buscar Contracts sin Company Setting
System.debug('4. CONTRACTS SIN COMPANY SETTING:');
System.debug('');

List<Contract> contractsWithoutCS = [
    SELECT Id, ContractNumber,
           AccountId,
           SM_Opportunity__c,
           SM_Opportunity__r.SM_Company_Setting__c
    FROM Contract
    WHERE CreatedDate = LAST_N_DAYS:30
    AND SM_Opportunity__r.SM_Company_Setting__c = NULL
    LIMIT 10
];

if (contractsWithoutCS.isEmpty()) {
    System.debug('✅ No hay Contracts sin Company Setting');
} else {
    System.debug('⚠️ Contracts sin Company Setting:');
    for (Contract c : contractsWithoutCS) {
        System.debug('  - Id: ' + c.Id);
        System.debug('    Number: ' + c.ContractNumber);
        System.debug('    Opportunity: ' + c.SM_Opportunity__c);
        System.debug('');
    }
}

// Verificar Custom Labels
System.debug('5. VERIFICACIÓN CUSTOM LABELS:');
System.debug('');

try {
    String label1 = System.Label.AVAILABLE_PAYMENT_STATUS_TO_SEND_RECEIPT;
    System.debug('✅ AVAILABLE_PAYMENT_STATUS_TO_SEND_RECEIPT: ' + label1);
    
    if (String.isBlank(label1)) {
        System.debug('⚠️ ALERTA: Label está vacío');
    } else {
        List<String> values = label1.split(',');
        System.debug('   Valores: ' + values);
    }
} catch (Exception e) {
    System.debug('❌ ERROR al acceder al label: ' + e.getMessage());
}

System.debug('');
System.debug('=====================================');
System.debug('CÓDIGO PROBLEMÁTICO IDENTIFICADO:');
System.debug('=====================================');
System.debug('');
System.debug('LÍNEAS CRÍTICAS EN SM_PaymentHandler:');
System.debug('');
System.debug('1. updateACHOrderInfo() - Línea ~157:');
System.debug('   achOrderIds.add(payment.SM_ACH_Order__c);');
System.debug('   ⚠️ Si SM_ACH_Order__c es NULL, agrega NULL al Set');
System.debug('');
System.debug('2. updateContractInfo() - Línea ~142:');
System.debug('   contractIds.add(payment.SM_Contract__c);');
System.debug('   ⚠️ Si SM_Contract__c es NULL, agrega NULL al Set');
System.debug('');
System.debug('3. checkPaymentToSendChargentReceipt() - Línea ~47:');
System.debug('   List<String> availablePaymentStatusToSendReceipt = System.label.AVAILABLE_PAYMENT_STATUS_TO_SEND_RECEIPT.split(\',\');');
System.debug('   ⚠️ Si el label es NULL, split() falla con "Argument Can\'t be null"');
System.debug('');

System.debug('=====================================');
System.debug('SOLUCIÓN RECOMENDADA:');
System.debug('=====================================');
System.debug('');
System.debug('1. Verificar que el Custom Label AVAILABLE_PAYMENT_STATUS_TO_SEND_RECEIPT no esté vacío');
System.debug('2. Agregar validaciones null en updateACHOrderInfo() antes de add()');
System.debug('3. Agregar validaciones null en updateContractInfo() antes de add()');
System.debug('4. Revisar Payments sin SM_ACH_Order__c o SM_Contract__c');
System.debug('');
System.debug('=====================================');
System.debug('FIN ANÁLISIS');
System.debug('=====================================');