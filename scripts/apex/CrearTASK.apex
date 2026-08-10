// Lista de ContractNumber que quieres procesar
List<String> contractNumbers = new List<String>{
    '00289937','00311887','00309564','00312251','00312270','00312669','00312713','00312868','00313112','00313178','00313229','00313496','00313658','00313857','00313892','00314055','00314074','00314241','00314281','00314289','00314302','00314324','00314329','00314333','00314343','00314346','00314356','00314378','00314405','00314409','00314421','00314423','00314477','00314488','00314515','00314517','00314540','00314544','00314602','00314609','00314637','00314657','00314685','00314708','00314709','00314710','00314716','00314721','00314728','00314731','00314777','00314788','00314805','00314811','00314886','00314913','00314914','00314924','00314939','00314987','00315020','00311797','00310961','00313513'

    // agrega más aquí
};
 
// Consultar los contratos por ContractNumber
List<Contract> contracts = [
    SELECT Id, ContractNumber, SM_Customer_Cancellation__c
    FROM Contract
    WHERE ContractNumber IN :contractNumbers
];
 
// Preparar lista de Tasks
List<Task> tasksToInsert = new List<Task>();
List<Contract> contractToUpdate = new List<Contract>();
 
for (Contract c : contracts) {
    Task t = new Task();
    t.Subject = 'Customer Service-Effective Cancellation';
    t.WhatId = c.Id; // Aquí se asigna el contrato encontrado
    t.Description = 'Se cancela por falta de pago, Solicitado y Autorizado por Elba Mantilla';
    t.OwnerId = '0051U000001MRFeQAO';
    t.RecordTypeId = '0121U00000085XiQAI';
    t.ActivityDate = Date.today();
    tasksToInsert.add(t);

    // Marcamos el contrato en SM_Customer_Cancellation__c = True
    c.SM_Customer_Cancellation__c = true;
    contractToUpdate.add(c);
}
 
// Insertar todas las tasks
if (!tasksToInsert.isEmpty()) insert tasksToInsert;
if (!contractToUpdate.isEmpty()) update contractToUpdate;
 
System.debug('Tasks creadas: ' + tasksToInsert.size());
 