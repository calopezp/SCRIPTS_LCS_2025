// Script para identificar Payments ACH sin SM_ACH_Order__c

System.debug('=====================================');
System.debug('PAYMENTS ACH CON ERROR');
System.debug('=====================================');
System.debug('');

// Obtener RecordType ACH
Id achRecordTypeId = SM_utils.getRecordTypeIdByDeveloperName('SM_Payment__c', 'ACH');
System.debug('RecordType ACH Id: ' + achRecordTypeId);
System.debug('');

// Buscar Payments ACH sin ACH Order en los últimos 7 días
List<SM_Payment__c> paymentsACH = [
    SELECT Id, Name,
           SM_Contract__c,
           SM_Contract__r.ContractNumber,
           SM_ACH_Order__c,
           SM_Chargent_Orders_Transaction__c,
           Payment_Status__c,
           SM_Type__c,
           SM_Amount__c,
           SM_Payment_execution_date__c,
           CreatedDate,
           CreatedBy.Name,
           RecordType.DeveloperName
    FROM SM_Payment__c
    WHERE RecordTypeId = :achRecordTypeId
    AND SM_ACH_Order__c = NULL
    AND CreatedDate = LAST_N_DAYS:7
    ORDER BY CreatedDate DESC
];

System.debug('========================================');
System.debug('PAYMENTS ACH SIN ACH ORDER');
System.debug('========================================');
System.debug('Total encontrados: ' + paymentsACH.size());
System.debug('');

if (paymentsACH.isEmpty()) {
    System.debug('✅ No hay Payments ACH sin ACH Order en los últimos 7 días');
} else {
    System.debug('⚠️ PAYMENTS ACH PROBLEMÁTICOS:');
    System.debug('');
    
    Integer contador = 1;
    for (SM_Payment__c p : paymentsACH) {
        System.debug('--- PAYMENT #' + contador + ' ---');
        System.debug('Id: ' + p.Id);
        System.debug('Name: ' + p.Name);
        System.debug('RecordType: ' + p.RecordType.DeveloperName);
        System.debug('Contract: ' + p.SM_Contract__r.ContractNumber + ' (' + p.SM_Contract__c + ')');
        System.debug('ACH Order: ' + p.SM_ACH_Order__c);
        System.debug('Transaction: ' + p.SM_Chargent_Orders_Transaction__c);
        System.debug('Type: ' + p.SM_Type__c);
        System.debug('Status: ' + p.Payment_Status__c);
        System.debug('Amount: ' + p.SM_Amount__c);
        System.debug('Execution Date: ' + p.SM_Payment_execution_date__c);
        System.debug('Created Date: ' + p.CreatedDate);
        System.debug('Created By: ' + p.CreatedBy.Name);
        System.debug('');
        contador++;
    }
    
    // Resumen por tipo
    System.debug('========================================');
    System.debug('RESUMEN POR TIPO');
    System.debug('========================================');
    
    Map<String, Integer> countByType = new Map<String, Integer>();
    Map<String, List<String>> idsByType = new Map<String, List<String>>();
    
    for (SM_Payment__c p : paymentsACH) {
        String tipo = p.SM_Type__c != null ? p.SM_Type__c : 'Sin Tipo';
        
        if (!countByType.containsKey(tipo)) {
            countByType.put(tipo, 0);
            idsByType.put(tipo, new List<String>());
        }
        countByType.put(tipo, countByType.get(tipo) + 1);
        idsByType.get(tipo).add(p.Name);
    }
    
    for (String tipo : countByType.keySet()) {
        System.debug('');
        System.debug('Tipo: ' + tipo);
        System.debug('  Cantidad: ' + countByType.get(tipo));
        System.debug('  IDs: ' + String.join(idsByType.get(tipo), ', '));
    }
    
    // Resumen por Status
    System.debug('');
    System.debug('========================================');
    System.debug('RESUMEN POR STATUS');
    System.debug('========================================');
    
    Map<String, Integer> countByStatus = new Map<String, Integer>();
    
    for (SM_Payment__c p : paymentsACH) {
        String status = p.Payment_Status__c != null ? p.Payment_Status__c : 'Sin Status';
        
        if (!countByStatus.containsKey(status)) {
            countByStatus.put(status, 0);
        }
        countByStatus.put(status, countByStatus.get(status) + 1);
    }
    
    for (String status : countByStatus.keySet()) {
        System.debug('Status: ' + status + ' → ' + countByStatus.get(status) + ' payments');
    }
}

// Buscar también Payments ACH recientes con ACH Order (para comparar)
System.debug('');
System.debug('========================================');
System.debug('COMPARACIÓN: PAYMENTS ACH CORRECTOS');
System.debug('========================================');

List<SM_Payment__c> paymentsACHOK = [
    SELECT Id, Name,
           SM_ACH_Order__c,
           SM_Type__c,
           Payment_Status__c,
           CreatedDate
    FROM SM_Payment__c
    WHERE RecordTypeId = :achRecordTypeId
    AND SM_ACH_Order__c != NULL
    AND CreatedDate = LAST_N_DAYS:7
    ORDER BY CreatedDate DESC
    LIMIT 5
];

System.debug('Payments ACH CON ACH Order (últimos 5):');
for (SM_Payment__c p : paymentsACHOK) {
    System.debug('  - ' + p.Name + ' | Type: ' + p.SM_Type__c + ' | ACH Order: ' + p.SM_ACH_Order__c);
}

System.debug('');
System.debug('========================================');
System.debug('ANÁLISIS COMPLETO');
System.debug('========================================');
System.debug('Payments ACH SIN ACH Order: ' + paymentsACH.size());
System.debug('Payments ACH CON ACH Order: ' + paymentsACHOK.size());
System.debug('');

if (!paymentsACH.isEmpty()) {
    System.debug('⚠️ ESTOS PAYMENTS CAUSAN EL ERROR EN EL BATCH');
    System.debug('');
    System.debug('IDs para corregir:');
    List<String> ids = new List<String>();
    for (SM_Payment__c p : paymentsACH) {
        ids.add(p.Id);
    }
    System.debug(String.join(ids, ', '));
}

System.debug('');
System.debug('=====================================');
System.debug('FIN ANÁLISIS');
System.debug('=====================================');