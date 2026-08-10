// Script para identificar los Payments/ACH Orders específicos que causaron el error en el batch

System.debug('=====================================');
System.debug('IDENTIFICAR REGISTROS CON ERROR');
System.debug('=====================================');
System.debug('');

// 1. Buscar el batch fallido más reciente
List<AsyncApexJob> failedJobs = [
    SELECT Id, 
           ApexClass.Name,
           Status,
           NumberOfErrors,
           JobItemsProcessed,
           TotalJobItems,
           CreatedDate,
           CompletedDate,
           ExtendedStatus
    FROM AsyncApexJob
    WHERE ApexClass.Name = 'SM_PaymentBatch'
    AND Status = 'Failed'
    ORDER BY CreatedDate DESC
    LIMIT 5
];

System.debug('Batches fallidos encontrados: ' + failedJobs.size());
System.debug('');

if (failedJobs.isEmpty()) {
    System.debug('⚠️ No hay batches fallidos. Buscando batches completados con errores...');
    System.debug('');
    
    // Buscar batches que completaron pero tuvieron errores
    List<AsyncApexJob> jobsWithErrors = [
        SELECT Id, 
               ApexClass.Name,
               Status,
               NumberOfErrors,
               JobItemsProcessed,
               TotalJobItems,
               CreatedDate,
               CompletedDate,
               ExtendedStatus
        FROM AsyncApexJob
        WHERE ApexClass.Name = 'SM_PaymentBatch'
        AND NumberOfErrors > 0
        ORDER BY CreatedDate DESC
        LIMIT 5
    ];
    
    System.debug('Batches con errores encontrados: ' + jobsWithErrors.size());
    System.debug('');
    
    if (!jobsWithErrors.isEmpty()) {
        for (AsyncApexJob job : jobsWithErrors) {
            System.debug('--- JOB ---');
            System.debug('Job Id: ' + job.Id);
            System.debug('Status: ' + job.Status);
            System.debug('Errors: ' + job.NumberOfErrors);
            System.debug('Created: ' + job.CreatedDate);
            System.debug('Extended Status: ' + job.ExtendedStatus);
            System.debug('');
        }
        
        // Usar el más reciente con error
        failedJobs = new List<AsyncApexJob>{jobsWithErrors[0]};
    }
}

if (failedJobs.isEmpty()) {
    System.debug('❌ No se encontraron ejecuciones con error del batch SM_PaymentBatch');
    System.debug('');
    System.debug('Mostrando Payments recientes que podrían causar el error:');
    System.debug('(Payments con SM_ACH_Order__c = NULL creados en las últimas 24 horas)');
    System.debug('');
    
    // Buscar Payments problemáticos recientes
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
               CreatedBy.Name
        FROM SM_Payment__c
        WHERE SM_ACH_Order__c = NULL
        AND CreatedDate = LAST_N_DAYS:1
        ORDER BY CreatedDate DESC
        LIMIT 20
    ];
    
    System.debug('Total Payments con SM_ACH_Order__c = NULL (últimas 24h): ' + problematicPayments.size());
    System.debug('');
    
    if (!problematicPayments.isEmpty()) {
        Integer contador = 1;
        for (SM_Payment__c p : problematicPayments) {
            System.debug('--- PAYMENT #' + contador + ' ---');
            System.debug('Id: ' + p.Id);
            System.debug('Name: ' + p.Name);
            System.debug('RecordType: ' + p.RecordType.DeveloperName);
            System.debug('Contract: ' + p.SM_Contract__r.ContractNumber);
            System.debug('ACH Order: ' + p.SM_ACH_Order__c);
            System.debug('Type: ' + p.SM_Type__c);
            System.debug('Status: ' + p.Payment_Status__c);
            System.debug('Created: ' + p.CreatedDate);
            System.debug('');
            contador++;
        }
    }
    
} else {
    AsyncApexJob failedJob = failedJobs[0];
    
    System.debug('========================================');
    System.debug('BATCH FALLIDO ENCONTRADO');
    System.debug('========================================');
    System.debug('Job Id: ' + failedJob.Id);
    System.debug('Status: ' + failedJob.Status);
    System.debug('Errors: ' + failedJob.NumberOfErrors);
    System.debug('Items Processed: ' + failedJob.JobItemsProcessed + '/' + failedJob.TotalJobItems);
    System.debug('Created Date: ' + failedJob.CreatedDate);
    System.debug('Completed Date: ' + failedJob.CompletedDate);
    System.debug('Extended Status: ' + failedJob.ExtendedStatus);
    System.debug('');
    
    // Calcular ventana de tiempo del batch
    DateTime batchStart = failedJob.CreatedDate;
    DateTime batchEnd = failedJob.CompletedDate != null ? failedJob.CompletedDate : DateTime.now();
    
    System.debug('========================================');
    System.debug('BUSCAR PAYMENTS PROCESADOS EN EL BATCH');
    System.debug('========================================');
    System.debug('Ventana de tiempo: ' + batchStart + ' a ' + batchEnd);
    System.debug('');
    
    // El batch procesa Payments creados o modificados en ese período
    // Buscamos Payments que podrían haber causado el error
    List<SM_Payment__c> processedPayments = [
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
        WHERE (CreatedDate >= :batchStart AND CreatedDate <= :batchEnd)
        OR (LastModifiedDate >= :batchStart AND LastModifiedDate <= :batchEnd)
        ORDER BY CreatedDate DESC
    ];
    
    System.debug('Total Payments en ventana de tiempo: ' + processedPayments.size());
    System.debug('');
    
    // Filtrar los problemáticos (con SM_ACH_Order__c = NULL)
    List<SM_Payment__c> problematicPayments = new List<SM_Payment__c>();
    for (SM_Payment__c p : processedPayments) {
        if (p.SM_ACH_Order__c == null) {
            problematicPayments.add(p);
        }
    }
    
    System.debug('========================================');
    System.debug('PAYMENTS PROBLEMÁTICOS (SM_ACH_Order__c = NULL)');
    System.debug('========================================');
    System.debug('Total: ' + problematicPayments.size());
    System.debug('');
    
    if (problematicPayments.isEmpty()) {
        System.debug('✅ No se encontraron Payments con SM_ACH_Order__c = NULL en la ventana de tiempo');
        System.debug('');
        System.debug('Mostrando todos los Payments procesados:');
        System.debug('');
        
        Integer contador = 1;
        for (SM_Payment__c p : processedPayments) {
            System.debug('--- PAYMENT #' + contador + ' ---');
            System.debug('Id: ' + p.Id);
            System.debug('Name: ' + p.Name);
            System.debug('RecordType: ' + p.RecordType.DeveloperName);
            System.debug('Contract: ' + (p.SM_Contract__r != null ? p.SM_Contract__r.ContractNumber : 'N/A'));
            System.debug('ACH Order: ' + p.SM_ACH_Order__c);
            System.debug('Type: ' + p.SM_Type__c);
            System.debug('Status: ' + p.Payment_Status__c);
            System.debug('Created: ' + p.CreatedDate);
            System.debug('Modified: ' + p.LastModifiedDate);
            System.debug('');
            contador++;
            if (contador > 10) break; // Limitar output
        }
    } else {
        System.debug('⚠️ ESTOS PAYMENTS CAUSARON EL ERROR:');
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
            System.debug('--- RecordType: ' + recordType + ' (' + payments.size() + ') ---');
            System.debug('');
            
            Integer contador = 1;
            for (SM_Payment__c p : payments) {
                System.debug('  #' + contador + '. Payment: ' + p.Name + ' (Id: ' + p.Id + ')');
                System.debug('     Contract: ' + (p.SM_Contract__r != null ? p.SM_Contract__r.ContractNumber : 'N/A'));
                System.debug('     Type: ' + p.SM_Type__c);
                System.debug('     Status: ' + p.Payment_Status__c);
                System.debug('     Amount: ' + p.SM_Amount__c);
                System.debug('     Created: ' + p.CreatedDate);
                System.debug('     Created By: ' + p.CreatedBy.Name);
                System.debug('');
                contador++;
            }
        }
        
        System.debug('========================================');
        System.debug('IDs DE PAYMENTS CON ERROR');
        System.debug('========================================');
        List<String> paymentIds = new List<String>();
        for (SM_Payment__c p : problematicPayments) {
            paymentIds.add(p.Id);
        }
        System.debug(String.join(paymentIds, ','));
        System.debug('');
        
        System.debug('========================================');
        System.debug('NOMBRES DE PAYMENTS CON ERROR');
        System.debug('========================================');
        List<String> paymentNames = new List<String>();
        for (SM_Payment__c p : problematicPayments) {
            paymentNames.add(p.Name);
        }
        System.debug(String.join(paymentNames, ', '));
    }
}

System.debug('');
System.debug('=====================================');
System.debug('FIN ANÁLISIS');
System.debug('=====================================');