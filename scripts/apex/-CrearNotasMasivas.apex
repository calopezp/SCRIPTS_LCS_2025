date fecha = Date.newInstance(2026, 04, 10);
// Tipo de mensaje (1 a 7 según tu tabla)
Integer itemType = 9; // cambia según el caso que quieras usar

// Lista de ContractNumber de prueba
List<String> rawContractNumbers  = new List<String>{
    '00315797'
  
};

// Normalizar a 8 dígitos con ceros a la izquierda
List<String> normalizedContractNumbers = new List<String>();
for (String num : rawContractNumbers) {
    if (num != null) {
        String clean = num.trim();
        while (clean.length() < 8) {
            clean = '0' + clean;
        }
        normalizedContractNumbers.add(clean);
    }
}
System.debug('🔎 ContractNumbers normalizados: ' + normalizedContractNumbers); 


// Consultar contratos
List<Contract> contracts = [
    SELECT Id, ContractNumber, SM_Email_to_send_contract__c
    FROM Contract
    WHERE ContractNumber IN :normalizedContractNumbers
];

// Variables para asunto y descripción
String subject;
String description;

// Asignar valores según el tipo
switch on itemType {
    when 1 {
        subject = 'Customer Service-Email Sent- Seguimientos a docs no completos';
        description = 'Mensaje enviado a seguimiento de Evidencias y Docs no completos';
    }
    when 2 {
        subject = 'Customer Service-Email Sent- Seguimientos a docs no completos';
        description = 'Envio de email masivo documentos pendientes PI no firmado';
    }
    when 3 {
        subject = 'Collection payment reminder';
        description = 'Envió de email masivo por cobros declinados';
    }
    when 4 {
        subject = 'Customer service Email Sent- Notifcacion disputa trabajada';
        description = 'Envio de email notifcacion de disputa trabajada esperando Resultados';
    }
    when 5 {
        subject = 'TIADM - Subscription Stopped - Validación Payments';
        description = 'Subscription Stopped por validación Payments Transmitted Duplicados';
    }
    when 6 {
        subject = 'TIADM - Subscription Stopped - PAGOS FUTUROS';
        description = 'Subscription Stopped por Pagos a futuro';
    }
    when 7 {
        subject = 'TIADM - Subscription Initiated - PAGOS FUTUROS';
        description = 'Subscription Inittiated por Cumplimiento de cuotas Outstanding';
    }
    When 8 {
        subject = 'Customer Service-Email Sent- Seguimientos a docs no completos';
        description = 'Envio de email masivo documentos pendientes PI no firmado';
    }
    When 9 {
        subject = 'Customer Service-Case Status – o Status Check';
        description = 'SUSCRIPCION EN HOLD POR FALTA DE DOCS Y PAGANDO (ROSAURA DE JESUS)';
    }
    when else {
        subject = 'Registro de Nota';
        description = 'Correo enviado';
    }
}

// Crear tareas
List<Task> tasksToInsert = new List<Task>();

for (Contract ctr : contracts) {
    if (ctr.SM_Email_to_send_contract__c != null) {
        Task t = new Task();
        t.Status = 'Open';
        t.Priority = 'Normal';
        t.Subject = subject;
        t.Description = description + ' | Correo: ' + ctr.SM_Email_to_send_contract__c;
        t.OwnerId = '0051U000001MRFeQAO'; // Id del usuario propietario
        t.WhatId = ctr.Id;              // Relación con el contrato
        t.ActivityDate = fecha; //Date.today();  // Fecha de actividad = hoy
        t.CreatedDate = fecha; //Date.today();  // Fecha de actividad = hoy
        t.RecordTypeId = '0121U00000085XiQAI'; // Id del tipo de tarea 'Registro de Nota    '
        tasksToInsert.add(t);
    }
}

// Insertar todas las tareas
if (!tasksToInsert.isEmpty()) {
    insert tasksToInsert;
    System.debug('→✅ Se insertaron ' + tasksToInsert.size() + ' tareas con Subject: ' + subject);
} else {
    System.debug('→⚠️ No se encontraron contratos con correo.');
}
