// Programa SM_WeeklyComercialDigestScheduler para correr todos los LUNES a las 8:00 AM
// (hora de la org). Manda el compilado semanal de return codes para Comercial en modo
// reducido (backlog colapsado a una linea por categoria) -- ver SM_ReturnCodeNotifier.cls
// y SM_WeeklyComercialDigestScheduler.cls.
String jobId = System.schedule('SM_WeeklyComercialDigest_Monday', '0 0 8 ? * MON', new SM_WeeklyComercialDigestScheduler());
System.debug(' -> Job programado: ' + jobId);

CronTrigger ct = [SELECT Id, CronExpression, NextFireTime, State FROM CronTrigger WHERE Id = :jobId];
System.debug(' -> Estado: ' + ct.State + ' | Proxima ejecucion: ' + ct.NextFireTime + ' | Cron: ' + ct.CronExpression);
