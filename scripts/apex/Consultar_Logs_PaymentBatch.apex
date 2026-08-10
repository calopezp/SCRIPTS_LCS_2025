// Script para consultar los últimos logs del batch SM_PaymentBatch

System.debug('=====================================');
System.debug('CONSULTANDO LOGS DE SM_PaymentBatch');
System.debug('=====================================');
System.debug('');

// 1. Buscar los últimos Apex Jobs del batch SM_PaymentBatch
List<AsyncApexJob> batchJobs = [
    SELECT Id, 
           Status, 
           NumberOfErrors, 
           JobItemsProcessed,
           TotalJobItems,
           CreatedDate,
           CompletedDate,
           ApexClass.Name,
           ExtendedStatus,
           MethodName
    FROM AsyncApexJob
    WHERE ApexClass.Name LIKE '%PaymentBatch%'
    OR ApexClass.Name LIKE '%Payment%Batch%'
    ORDER BY CreatedDate DESC
    LIMIT 10
];

if (batchJobs.isEmpty()) {
    System.debug('❌ No se encontraron ejecuciones del batch PaymentBatch');
    System.debug('');
    System.debug('Buscando todos los batches recientes...');
    
    // Buscar cualquier batch
    List<AsyncApexJob> allJobs = [
        SELECT Id, 
               Status, 
               ApexClass.Name,
               CreatedDate,
               NumberOfErrors
        FROM AsyncApexJob
        WHERE JobType = 'BatchApex'
        ORDER BY CreatedDate DESC
        LIMIT 20
    ];
    
    System.debug('');
    System.debug('BATCHES RECIENTES:');
    for (AsyncApexJob job : allJobs) {
        System.debug('  - ' + job.ApexClass.Name + ' | Status: ' + job.Status + 
                     ' | Errors: ' + job.NumberOfErrors + ' | Date: ' + job.CreatedDate);
    }
} else {
    System.debug('✅ Se encontraron ' + batchJobs.size() + ' ejecuciones del batch');
    System.debug('');
    
    for (AsyncApexJob job : batchJobs) {
        System.debug('========================================');
        System.debug('JOB: ' + job.ApexClass.Name);
        System.debug('========================================');
        System.debug('Job Id: ' + job.Id);
        System.debug('Status: ' + job.Status);
        System.debug('Created: ' + job.CreatedDate);
        System.debug('Completed: ' + job.CompletedDate);
        System.debug('Total Items: ' + job.TotalJobItems);
        System.debug('Processed: ' + job.JobItemsProcessed);
        System.debug('Errors: ' + job.NumberOfErrors);
        System.debug('Extended Status: ' + job.ExtendedStatus);
        System.debug('Method: ' + job.MethodName);
        System.debug('');
    }
    
    // 2. Buscar el último job con errores
    AsyncApexJob jobWithErrors = null;
    for (AsyncApexJob job : batchJobs) {
        if (job.NumberOfErrors > 0) {
            jobWithErrors = job;
            break;
        }
    }
    
    if (jobWithErrors != null) {
        System.debug('========================================');
        System.debug('ÚLTIMO JOB CON ERRORES');
        System.debug('========================================');
        System.debug('Job Id: ' + jobWithErrors.Id);
        System.debug('Errors: ' + jobWithErrors.NumberOfErrors);
        System.debug('Extended Status: ' + jobWithErrors.ExtendedStatus);
        System.debug('');
        
        // 3. Buscar BatchApexErrorEvent para este job
        System.debug('Buscando detalles del error...');
        System.debug('');
        
        // Nota: BatchApexErrorEvent solo está disponible si está habilitado en la org
        // Alternativa: buscar en ApexLog
    }
}

// 4. Buscar ApexLog más reciente relacionado con Payment
System.debug('========================================');
System.debug('BUSCANDO APEX LOGS RECIENTES');
System.debug('========================================');

List<ApexLog> logs = [
    SELECT Id, 
           Operation, 
           Status,
           DurationMilliseconds,
           StartTime,
           LogLength
    FROM ApexLog
    WHERE Operation LIKE '%Payment%'
    OR Operation LIKE '%Batch%'
    ORDER BY StartTime DESC
    LIMIT 10
];

if (logs.isEmpty()) {
    System.debug('No se encontraron logs relacionados con Payment');
} else {
    System.debug('Se encontraron ' + logs.size() + ' logs recientes:');
    System.debug('');
    
    for (ApexLog log : logs) {
        System.debug('LOG:');
        System.debug('  - Id: ' + log.Id);
        System.debug('  - Operation: ' + log.Operation);
        System.debug('  - Status: ' + log.Status);
        System.debug('  - Duration: ' + log.DurationMilliseconds + ' ms');
        System.debug('  - Start: ' + log.StartTime);
        System.debug('  - Length: ' + log.LogLength + ' bytes');
        System.debug('');
    }
    
    System.debug('');
    System.debug('Para ver el contenido completo del log, ejecuta:');
    System.debug('');
    System.debug('String logBody = [SELECT Body FROM ApexLog WHERE Id = \'' + logs[0].Id + '\'].Body;');
    System.debug('System.debug(logBody);');
}

// 5. Buscar clases Apex relacionadas con Payment Batch
System.debug('');
System.debug('========================================');
System.debug('CLASES APEX CON "PAYMENT" Y "BATCH"');
System.debug('========================================');

List<ApexClass> apexClasses = [
    SELECT Id, Name, ApiVersion, Status
    FROM ApexClass
    WHERE (Name LIKE '%Payment%' AND Name LIKE '%Batch%')
    OR Name = 'SM_PaymentBatch'
    ORDER BY Name
];

if (apexClasses.isEmpty()) {
    System.debug('No se encontraron clases con "Payment" y "Batch" en el nombre');
} else {
    System.debug('Clases encontradas:');
    for (ApexClass cls : apexClasses) {
        System.debug('  - ' + cls.Name + ' (API: ' + cls.ApiVersion + ', Status: ' + cls.Status + ')');
    }
}

System.debug('');
System.debug('=====================================');
System.debug('FIN CONSULTA');
System.debug('=====================================');