// Script para recuperar el cuerpo completo del LOG del batch SM_PaymentBatch con error

System.debug('=====================================');
System.debug('RECUPERAR LOG COMPLETO DEL BATCH');
System.debug('=====================================');
System.debug('');

// 1. Buscar el AsyncApexJob más reciente con error
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
    LIMIT 1
];

if (failedJobs.isEmpty()) {
    System.debug('❌ No se encontraron ejecuciones fallidas del batch SM_PaymentBatch');
} else {
    AsyncApexJob job = failedJobs[0];
    
    System.debug('JOB ENCONTRADO:');
    System.debug('Job Id: ' + job.Id);
    System.debug('Class: ' + job.ApexClass.Name);
    System.debug('Status: ' + job.Status);
    System.debug('Errors: ' + job.NumberOfErrors);
    System.debug('Items Processed: ' + job.JobItemsProcessed + '/' + job.TotalJobItems);
    System.debug('Created Date: ' + job.CreatedDate);
    System.debug('Completed Date: ' + job.CompletedDate);
    System.debug('Extended Status: ' + job.ExtendedStatus);
    System.debug('');
    
    // 2. Buscar los ApexLog relacionados con esta ejecución
    // Los logs se crean durante la ejecución del batch
    System.debug('========================================');
    System.debug('BUSCANDO LOGS RELACIONADOS');
    System.debug('========================================');
    
    // Buscar logs en el rango de tiempo de ejecución del batch
    DateTime startTime = job.CreatedDate.addMinutes(-5);
    DateTime endTime = job.CompletedDate != null ? job.CompletedDate.addMinutes(5) : DateTime.now();
    
    List<ApexLog> relatedLogs = [
        SELECT Id,
               Application,
               DurationMilliseconds,
               Location,
               LogLength,
               LogUserId,
               Operation,
               Request,
               StartTime,
               Status
        FROM ApexLog
        WHERE StartTime >= :startTime
        AND StartTime <= :endTime
        AND (Operation LIKE '%Batch%' OR Operation LIKE '%SM_Payment%')
        ORDER BY StartTime DESC
    ];
    
    System.debug('Logs encontrados en el rango de tiempo: ' + relatedLogs.size());
    System.debug('');
    
    if (relatedLogs.isEmpty()) {
        System.debug('⚠️ No se encontraron logs en el rango de tiempo del batch');
        System.debug('Esto puede ocurrir si los logs ya fueron eliminados por retención de datos');
    } else {
        System.debug('LOGS DISPONIBLES:');
        System.debug('');
        
        Integer contador = 1;
        for (ApexLog log : relatedLogs) {
            System.debug('--- LOG #' + contador + ' ---');
            System.debug('Log Id: ' + log.Id);
            System.debug('Operation: ' + log.Operation);
            System.debug('Status: ' + log.Status);
            System.debug('Application: ' + log.Application);
            System.debug('Location: ' + log.Location);
            System.debug('Duration: ' + log.DurationMilliseconds + ' ms');
            System.debug('Log Length: ' + log.LogLength + ' bytes');
            System.debug('Start Time: ' + log.StartTime);
            System.debug('Request: ' + log.Request);
            System.debug('');
            contador++;
        }
        
        System.debug('========================================');
        System.debug('NOTA IMPORTANTE');
        System.debug('========================================');
        System.debug('El campo Body del ApexLog no está disponible vía SOQL por limitaciones de Salesforce.');
        System.debug('Para ver el contenido completo del log, debes:');
        System.debug('');
        System.debug('1. Ir a Setup → Debug Logs');
        System.debug('2. Buscar el log con Id: ' + relatedLogs[0].Id);
        System.debug('3. O usar Tooling API para recuperar el Body field');
        System.debug('');
        System.debug('Alternativamente, puedes usar esta query en Workbench o VS Code:');
        System.debug('');
        System.debug('TOOLING API QUERY:');
        System.debug('SELECT Id, Application, DurationMilliseconds, Location, LogLength,');
        System.debug('       LogUser.Name, Operation, Request, StartTime, Status');
        System.debug('FROM ApexLog');
        System.debug('WHERE Id = \'' + relatedLogs[0].Id + '\'');
        System.debug('');
        System.debug('Para obtener el Body, necesitas hacer una petición REST a:');
        System.debug('/services/data/v60.0/tooling/sobjects/ApexLog/' + relatedLogs[0].Id + '/Body');
    }
}

System.debug('');
System.debug('========================================');
System.debug('ANÁLISIS DEL EXTENDED STATUS');
System.debug('========================================');

if (!failedJobs.isEmpty()) {
    String extendedStatus = failedJobs[0].ExtendedStatus;
    System.debug('');
    System.debug('Extended Status completo:');
    System.debug(extendedStatus);
    System.debug('');
    
    // Analizar el mensaje de error
    if (extendedStatus != null && extendedStatus.contains('Argument cannot be null')) {
        System.debug('⚠️ ERROR IDENTIFICADO: Argument cannot be null');
        System.debug('');
        System.debug('Este error típicamente ocurre cuando:');
        System.debug('1. Se pasa un Set/List con valores NULL a un método de Helper');
        System.debug('2. Un SOQL query recibe una colección con NULLs en el WHERE clause');
        System.debug('3. Un parámetro requerido es NULL en una llamada de método');
        System.debug('');
        System.debug('ANÁLISIS BASADO EN EL CÓDIGO:');
        System.debug('');
        System.debug('En SM_PaymentHandler.updateACHOrderInfo():');
        System.debug('  - Línea ~152-155: Se agregan IDs al Set sin validar NULL');
        System.debug('  - achOrderIds.add(payment.SM_ACH_Order__c);');
        System.debug('  - Si payment.SM_ACH_Order__c es NULL, se agrega NULL al Set');
        System.debug('  - Luego SM_ACHOrderHelper.getACHOrdersByIds(achOrderIds) recibe NULLs');
        System.debug('  - El Helper hace una query WHERE Id IN :achOrderIds');
        System.debug('  - SOQL falla porque no puede comparar Id con NULL');
        System.debug('');
        System.debug('SOLUCIÓN PROPUESTA:');
        System.debug('Agregar validación en línea 154:');
        System.debug('if (payment.SM_ACH_Order__c != null) {');
        System.debug('    achOrderIds.add(payment.SM_ACH_Order__c);');
        System.debug('}');
    }
}

System.debug('');
System.debug('=====================================');
System.debug('FIN ANÁLISIS');
System.debug('=====================================');