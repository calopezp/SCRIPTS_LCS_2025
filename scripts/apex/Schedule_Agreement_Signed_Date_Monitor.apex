String jobId = System.schedule('SM_AgreementSignedDateMonitor_Daily', '0 15 8 * * ?', new SM_AgreementSignedDateMonitor());
System.debug(' -> Job programado: ' + jobId);

CronTrigger ct = [SELECT Id, CronExpression, NextFireTime, State FROM CronTrigger WHERE Id = :jobId];
System.debug(' -> Estado: ' + ct.State + ' | Proxima ejecucion: ' + ct.NextFireTime + ' | Cron: ' + ct.CronExpression);
