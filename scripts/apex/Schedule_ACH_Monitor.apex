String jobId = System.schedule('SM_ACH_Flow_Monitor_Daily', '0 0 8 * * ?', new SM_ACH_Flow_Monitor());
System.debug(' -> Job programado: ' + jobId);

CronTrigger ct = [SELECT Id, CronExpression, NextFireTime, State FROM CronTrigger WHERE Id = :jobId];
System.debug(' -> Estado: ' + ct.State + ' | Proxima ejecucion: ' + ct.NextFireTime + ' | Cron: ' + ct.CronExpression);
