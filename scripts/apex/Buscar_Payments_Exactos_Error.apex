// Script para buscar los Payments exactos que causaron los errores en los batches

System.debug('=====================================');
System.debug('BUSCAR PAYMENTS QUE CAUSARON ERROR');
System.debug('=====================================');
System.debug('');

// Los batches con error fueron:
// 1. Job Id: 707UU00001tjssEYAQ - Created: 2026-05-04 19:25:00 - Extended Status: First error: Argument cannot be null
// 2. Job Id: 707UU00001tjr3iYAA - Created: 2026-05-04 19:24:24 - Extended Status: First error: Argument cannot be null
// 3. Job Id: 707UU00001tjclrYAA - Created: 2026-05-04 18:50:00 - Extended Status: First error: Argument cannot be null

// Buscar Payments creados ANTES de la ejecución del batch más reciente
// El batch procesa Payments existentes, no solo los recién creados

// Ventana: desde las 18:00 hasta las 19:30 del 2026-05-04
DateTime searchStart = DateTime.newInstance(2026, 5, 4, 18, 0, 0);
DateTime searchEnd = DateTime.newInstance(2026, 5, 4, 19, 30, 0);

System.debug('Buscando Payments con SM_ACH_Order__c = NULL');
System.debug('Ventana: ' + searchStart + ' a ' + searchEnd);
System.debug('');

List<SM_Payment__c> problematicPayments = [
    SELECT Id, Name,
           RecordType.DeveloperName,
           SM_Contract__c,
           SM_Contract__r.ContractNumber,
           SM_ACH_Order__c,
           SM_Chargent_Orders_Transaction__c,
           Payment_Status__c,
           SM_Type__c,
           SM_Amount__c,
           CreatedDate,
           LastModifiedDate,
           CreatedBy.Name
    FROM SM_Payment__c
    WHERE SM_ACH_Order__c = NULL
    AND (CreatedDate >= :searchStart AND CreatedDate <= :searchEnd)
    ORDER BY CreatedDate DESC
];

System.debug('========================================');
System.debug('RESULTADO DE BÚSQUEDA');
System.debug('========================================');
System.debug('Total Payments encontrados: ' + problematicPayments.size());
System.debug('');

if (problematicPayments.isEmpty()) {
    System.debug('❌ No se encontraron Payments con SM_ACH_Order__c = NULL en esa ventana');
    System.debug('');
    System.debug('Ampliando búsqueda al día completo...');
    System.debug('');
    
    // Buscar en todo el día
    Date targetDate = Date.newInstance(2026, 5, 4);
    List<SM_Payment__c> allDayPayments = [
        SELECT Id, Name,
               RecordType.DeveloperName,
               SM_Contract__c,
               SM_Contract__r.ContractNumber,
               SM_ACH_Order__c,
               Payment_Status__c,
               SM_Type__c,
               SM_Amount__c,
               CreatedDate,
               CreatedBy.Name
        FROM SM_Payment__c
        WHERE SM_ACH_Order__c = NULL
        AND DAY_ONLY(CreatedDate) = :targetDate
        ORDER BY CreatedDate DESC
        LIMIT 50
    ];
    
    System.debug('Payments del día 2026-05-04 con SM_ACH_Order__c = NULL: ' + allDayPayments.size());
    System.debug('');
    
    if (!allDayPayments.isEmpty()) {
        // Agrupar por RecordType
        Map<String, Integer> countByType = new Map<String, Integer>();
        for (SM_Payment__c p : allDayPayments) {
            String rt = p.RecordType.DeveloperName;
            countByType.put(rt, countByType.containsKey(rt) ? countByType.get(rt) + 1 : 1);
        }
        
        System.debug('Resumen por RecordType:');
        for (String rt : countByType.keySet()) {
            System.debug('  - ' + rt + ': ' + countByType.get(rt));
        }
        System.debug('');
        
        System.debug('Primeros 10 Payments:');
        Integer contador = 1;
        for (SM_Payment__c p : allDayPayments) {
            if (contador > 10) break;
            System.debug('');
            System.debug('#' + contador + '. ' + p.Name + ' (Id: ' + p.Id + ')');
            System.debug('   RecordType: ' + p.RecordType.DeveloperName);
            System.debug('   Type: ' + p.SM_Type__c);
            System.debug('   Status: ' + p.Payment_Status__c);
            System.debug('   Created: ' + p.CreatedDate);
            System.debug('   Contract: ' + (p.SM_Contract__r != null ? p.SM_Contract__r.ContractNumber : 'N/A'));
            contador++;
        }
    }
    
} else {
    System.debug('⚠️ PAYMENTS QUE CAUSARON EL ERROR:');
    System.debug('');
    
    // Agrupar por RecordType
    Map<String, List<SM_Payment__c>> paymentsByType = new Map<String, List<SM_Payment__c>>();
    for (SM_Payment__c p : problematicPayments) {
        String recordType = p.RecordType.DeveloperName;
        if (!paymentsByType.containsKey(recordType)) {
            paymentsByType.put(recordType, new List<SM_Payment__c>());
        }
        paymentsByType.get(recordType).add(p);
    }
    
    for (String recordType : paymentsByType.keySet()) {
        List<SM_Payment__c> payments = paymentsByType.get(recordType);
        System.debug('========================================');
        System.debug('RecordType: ' + recordType + ' (' + payments.size() + ' payments)');
        System.debug('========================================');
        System.debug('');
        
        Integer contador = 1;
        for (SM_Payment__c p : payments) {
            System.debug('#' + contador + '. Payment: ' + p.Name);
            System.debug('   Id: ' + p.Id);
            System.debug('   Contract: ' + (p.SM_Contract__r != null ? p.SM_Contract__r.ContractNumber : 'N/A'));
            System.debug('   Type: ' + p.SM_Type__c);
            System.debug('   Status: ' + p.Payment_Status__c);
            System.debug('   Amount: ' + p.SM_Amount__c);
            System.debug('   Created: ' + p.CreatedDate);
            System.debug('   Modified: ' + p.LastModifiedDate);
            System.debug('   Created By: ' + p.CreatedBy.Name);
            System.debug('');
            contador++;
        }
    }
    
    System.debug('========================================');
    System.debug('LISTA DE IDs');
    System.debug('========================================');
    List<String> paymentIds = new List<String>();
    for (SM_Payment__c p : problematicPayments) {
        paymentIds.add(p.Id);
    }
    System.debug(String.join(paymentIds, ','));
    System.debug('');
    
    System.debug('========================================');
    System.debug('LISTA DE NOMBRES');
    System.debug('========================================');
    List<String> paymentNames = new List<String>();
    for (SM_Payment__c p : problematicPayments) {
        paymentNames.add(p.Name);
    }
    System.debug(String.join(paymentNames, ', '));
    System.debug('');
    
    // Resumen por Status
    System.debug('========================================');
    System.debug('RESUMEN POR STATUS');
    System.debug('========================================');
    Map<String, Integer> countByStatus = new Map<String, Integer>();
    for (SM_Payment__c p : problematicPayments) {
        String status = p.Payment_Status__c != null ? p.Payment_Status__c : 'Sin Status';
        countByStatus.put(status, countByStatus.containsKey(status) ? countByStatus.get(status) + 1 : 1);
    }
    
    for (String status : countByStatus.keySet()) {
        System.debug('  ' + status + ': ' + countByStatus.get(status));
    }
}

System.debug('');
System.debug('=====================================');
System.debug('FIN ANÁLISIS');
System.debug('=====================================');