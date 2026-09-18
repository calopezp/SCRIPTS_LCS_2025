String jobId = System.schedule('SM_TriggerPanelMonitor_Daily', '0 20 8 * * ?', new SM_TriggerPanelMonitor());
System.debug(' -> Job programado: ' + jobId);

CronTrigger ct = [SELECT Id, CronExpression, NextFireTime, State FROM CronTrigger WHERE Id = :jobId];
System.debug(' -> Estado: ' + ct.State + ' | Proxima ejecucion: ' + ct.NextFireTime + ' | Cron: ' + ct.CronExpression);
