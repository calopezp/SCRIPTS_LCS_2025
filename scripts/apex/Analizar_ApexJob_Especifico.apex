// Análisis del ApexJob específico: 707UU00001tkQdu

System.debug(' → =====================================');
System.debug(' → ANÁLISIS DE APEX JOB ESPECÍFICO');
System.debug(' → =====================================');
System.debug(' → ');

String jobId = '707UU00001tkQdu';

// Consultar información del job
List<AsyncApexJob> jobs = [
    SELECT Id,
           ApexClass.Name,
           ApexClass.Id,
           Status,
           JobType,
           MethodName,
           NumberOfErrors,
           JobItemsProcessed,
           TotalJobItems,
           CreatedDate,
           CreatedBy.Name,
           CompletedDate,
           ExtendedStatus
    FROM AsyncApexJob
    WHERE Id = :jobId
];

if (jobs.isEmpty()) {
    System.debug(' → ❌ No se encontró el ApexJob con Id: ' + jobId);
} else {
    AsyncApexJob job = jobs[0];
    
    System.debug(' → ========================================');
    System.debug(' → INFORMACIÓN DEL JOB');
    System.debug(' → ========================================');
    System.debug(' → Job Id: ' + job.Id);
    System.debug(' → Clase: ' + job.ApexClass.Name);
    System.debug(' → ApexClass Id: ' + job.ApexClass.Id);
    System.debug(' → Tipo: ' + job.JobType);
    System.debug(' → Método: ' + job.MethodName);
    System.debug(' → Estado: ' + job.Status);
    System.debug(' → Errores: ' + job.NumberOfErrors);
    System.debug(' → Items Procesados: ' + job.JobItemsProcessed + '/' + job.TotalJobItems);
    System.debug(' → Creado por: ' + job.CreatedBy.Name);
    System.debug(' → Fecha Creación: ' + job.CreatedDate);
    System.debug(' → Fecha Completado: ' + job.CompletedDate);
    System.debug(' → ');
    System.debug(' → ========================================');
    System.debug(' → EXTENDED STATUS (ERROR DETALLADO)');
    System.debug(' → ========================================');
    System.debug(job.ExtendedStatus);
    System.debug(' → ');
    
    // Calcular duración
    if (job.CompletedDate != null) {
        Long duration = job.CompletedDate.getTime() - job.CreatedDate.getTime();
        Long seconds = duration / 1000;
        System.debug(' → Duración: ' + seconds + ' segundos');
        System.debug(' → ');
    }
    
    // Buscar logs relacionados en el rango de tiempo
    DateTime startTime = job.CreatedDate.addMinutes(-2);
    DateTime endTime = job.CompletedDate != null ? job.CompletedDate.addMinutes(2) : DateTime.now();
    
    System.debug(' → ========================================');
    System.debug(' → BUSCANDO LOGS RELACIONADOS');
    System.debug(' → ========================================');
    System.debug(' → Rango: ' + startTime + ' a ' + endTime);
    System.debug(' → ');
    
    List<ApexLog> relatedLogs = [
        SELECT Id,
               Application,
               DurationMilliseconds,
               Location,
               LogLength,
               Operation,
               Request,
               StartTime,
               Status
        FROM ApexLog
        WHERE StartTime >= :startTime
        AND StartTime <= :endTime
        ORDER BY StartTime DESC
        LIMIT 10
    ];
    
    System.debug(' → Logs encontrados: ' + relatedLogs.size());
    System.debug(' → ');
    
    if (!relatedLogs.isEmpty()) {
        Integer contador = 1;
        for (ApexLog log : relatedLogs) {
            System.debug(' → --- LOG #' + contador + ' ---');
            System.debug(' →   Log Id: ' + log.Id);
            System.debug(' →   Operation: ' + log.Operation);
            System.debug(' →   Status: ' + log.Status);
            System.debug(' →   Start Time: ' + log.StartTime);
            System.debug(' →   Duration: ' + log.DurationMilliseconds + ' ms');
            System.debug(' →   Location: ' + log.Location);
            System.debug(' → ');
            contador++;
        }
    }
    
    // Analizar el error Extended Status
    System.debug(' → ========================================');
    System.debug(' → ANÁLISIS DEL ERROR');
    System.debug(' → ========================================');
    
    if (job.ExtendedStatus != null) {
        String errorMsg = job.ExtendedStatus.toLowerCase();
        
        if (errorMsg.contains('argument cannot be null')) {
            System.debug(' → ⚠️ ERROR IDENTIFICADO: Argument cannot be null');
            System.debug(' → ');
            System.debug(' → CAUSA MÁS PROBABLE:');
            System.debug(' → 1. Un Set o List contiene valores NULL');
            System.debug(' → 2. Se pasó ese Set/List a una query SOQL');
            System.debug(' → 3. SOQL no puede comparar con NULL usando IN o =');
            System.debug(' → ');
            System.debug(' → EN ESTE CASO:');
            System.debug(' → - Clase: ' + job.ApexClass.Name);
            
            if (job.ApexClass.Name.contains('Payment')) {
                System.debug(' → - Contexto: Payment Handler o Batch');
                System.debug(' → - Método problemático probable: updateACHOrderInfo()');
                System.debug(' → - Línea problemática: achOrderIds.add(payment.SM_ACH_Order__c)');
                System.debug(' → - Payments Credit Card tienen SM_ACH_Order__c = NULL');
                System.debug(' → - NULL se agrega al Set sin validación');
                System.debug(' → - Query WHERE Id IN :achOrderIds falla con NULL');
            }
        }
        
        if (errorMsg.contains('list has no rows')) {
            System.debug(' → ⚠️ ERROR: List has no rows for assignment');
        }
        
        if (errorMsg.contains('duplicate')) {
            System.debug(' → ⚠️ ERROR: Duplicate record detected');
        }
    }
    
    // Buscar Payments procesados en el rango de tiempo
    System.debug(' → ');
    System.debug(' → ========================================');
    System.debug(' → PAYMENTS EN EL RANGO DE TIEMPO');
    System.debug(' → ========================================');
    
    List<SM_Payment__c> paymentsInRange = [
        SELECT Id, Name,
               RecordType.DeveloperName,
               SM_ACH_Order__c,
               Payment_Status__c,
               SM_Type__c,
               CreatedDate
        FROM SM_Payment__c
        WHERE CreatedDate >= :startTime
        AND CreatedDate <= :endTime
        ORDER BY CreatedDate DESC
        LIMIT 20
    ];
    
    System.debug(' → Payments encontrados: ' + paymentsInRange.size());
    System.debug(' → ');
    
    if (!paymentsInRange.isEmpty()) {
        // Contar por tipo
        Map<String, Integer> countByType = new Map<String, Integer>();
        Integer withNull = 0;
        Integer withACHOrder = 0;
        
        for (SM_Payment__c p : paymentsInRange) {
            String rt = p.RecordType.DeveloperName;
            countByType.put(rt, countByType.containsKey(rt) ? countByType.get(rt) + 1 : 1);
            
            if (p.SM_ACH_Order__c == null) {
                withNull++;
            } else {
                withACHOrder++;
            }
        }
        
        System.debug(' → Resumen:');
        System.debug(' →   - Con SM_ACH_Order__c = NULL: ' + withNull);
        System.debug(' →   - Con SM_ACH_Order__c válido: ' + withACHOrder);
        System.debug(' → ');
        System.debug(' → Por RecordType:');
        for (String rt : countByType.keySet()) {
            System.debug(' →   - ' + rt + ': ' + countByType.get(rt));
        }
        System.debug(' → ');
        
        // Mostrar los primeros 5
        System.debug(' → Primeros 5 Payments:');
        Integer count = 0;
        for (SM_Payment__c p : paymentsInRange) {
            if (count >= 5) break;
            System.debug(' →   ' + (count+1) + '. ' + p.Name + 
                        ' | RT: ' + p.RecordType.DeveloperName + 
                        ' | ACH Order: ' + (p.SM_ACH_Order__c != null ? 'Sí' : 'NULL') +
                        ' | Type: ' + p.SM_Type__c);
            count++;
        }
    }
}

System.debug(' → ');
System.debug(' → =====================================');
System.debug(' → FIN ANÁLISIS');
System.debug(' → =====================================');