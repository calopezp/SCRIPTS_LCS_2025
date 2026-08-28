date fecha = Date.newInstance(2026, 08, 14);
// Tipo de mensaje (1 a 7 según tu tabla)
Integer itemType = 11; // cambia según el caso que quieras usar

// 11 - 'TIADM - CAMBIO DIA PAGO CONTRATO'

// Lista de ContractNumber de prueba
List<String> rawContractNumbers  = new List<String>{
    '00317198'
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
String Owner;    //Owner = '0051U000001MRFeQAO';  //Legal Credit Solutions

// Asignar valores según el tipo
switch on itemType {
    when 1 {
        subject = 'Customer Service-Email Sent- Seguimientos a docs no completos';
        description = 'Mensaje enviado a seguimiento de Evidencias y Docs no completos';
        Owner = '0051U000001MRFeQAO';
    }
    when 2 {
        subject = 'Customer Service-Email Sent- Seguimientos a docs no completos';
        description = 'Envio de email masivo documentos pendientes PI no firmado';
        Owner = '0051U000001MRFeQAO';
    }
    when 3 {
        subject = 'Collection payment reminder';
        description = 'Envió de email masivo por cobros declinados';
        Owner = '0051U000001MRFeQAO';
    }
    when 4 {
        subject = 'Customer service Email Sent- Notifcacion disputa trabajada';
        description = 'Envio de email notifcacion de disputa trabajada esperando Resultados';
        Owner = '0051U000001MRFeQAO';
    }
    when 5 {
        subject = 'TIADM - Subscription Stopped - Validación Payments';
        description = 'Subscription Stopped por validación Payments Transmitted Duplicados';
        Owner = '0051U000001MRFeQAO';
    }
    when 6 {
        subject = 'TIADM - Subscription Stopped - Validación Account ACH';
        description = 'Subscription Stopped por validación NUMERO DE CUENTA EN ACH';
        Owner = '0051U000001MRFeQAO';
    }
    when 7 {
        subject = 'TIADM - Subscription Stopped - PAGOS FUTUROS';
        description = 'Subscription Stopped por Pagos a futuro';
        Owner = '0051U000001MRFeQAO';
    }
    when 8 {
        subject = 'TIADM - Subscription Initiated - PAGOS FUTUROS';
        description = 'Subscription Inittiated por Cumplimiento de cuotas Outstanding';
        Owner = '0051U000001MRFeQAO';
    }
    When 9 {
        subject = 'Customer Service-Email Sent- Seguimientos a docs no completos';
        description = 'Envio de email masivo documentos pendientes PI no firmado';
        Owner = '0051U000001MRFeQAO';
    }
    When 10 {
        subject = 'Customer Service-Case Status – o Status Check';
        description = 'SUSCRIPCION EN HOLD POR FALTA DE DOCS Y PAGANDO (ROSAURA DE JESUS)';
        Owner = '0051U000001MRFeQAO';
    }
    When 11 {
        subject = 'TIADM - CAMBIO DIA PAGO CONTRATO';
        description = 'Solicitud Cambio fecha de cobro Permanente del 16 al 21 Solicitado por Raiza Montiel';
        Owner = '0051U000001MRFeQAO';
    }
    when else {
        subject = 'Registro de Nota';
        description = 'Correo enviado';
        Owner = '0051U000001MRFeQAO';
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
        t.OwnerId = Owner; // Id del usuario propietario
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
    List<String> taskIds = new List<String>();
    for (Task t : tasksToInsert) {
        taskIds.add(t.Id);
    }

    System.debug('\u2192 ✅ Se insertaron ' + tasksToInsert.size() + ' tareas con Subject: ' + subject + ' (' + String.join(taskIds, ', ') + ')');
} else {
    System.debug('\u2192 ⚠️ No se encontraron contratos con correo.');
}
