date fecha = Date.newInstance(2026, 08, 27);
// Tipo de mensaje (1 a 7 según tu tabla)
Integer itemType = 1; // cambia según el caso que quieras usar

// 1 - 'Mensaje enviado a seguimiento de Evidencias y Docs no completos'
// 11 - 'TIADM - CAMBIO DIA PAGO CONTRATO'

// Lista de ContractNumber de prueba
List<String> rawContractNumbers  = new List<String>{
    '00316623','00316656','00316683','00316432','00316720','00316818','00316839','00316851','00316781','00316878','00316665','00316864','00316686','00316687','00316951','00317011','00316940','00317054','00317012','00317016','00317071','00317079','00316996','00316860','00316916','00316920','00316936','00316938','00316954','00317123','00317128','00316854','00317149','00317157','00316987','00317181','00316932','00317101','00317171','00317177','00317250','00317224','00317158','00317044','00317263','00316812','00317062','00317260','00317285','00317070','00317233','00317335','00316903','00317326','00317176','00317274','00317137','00317168','00317248','00317300','00317359','00317198','00317442','00317448','00317382','00317458','00317328','00317304','00317400','00317497','00317506','00317394','00317436','00317535','00317374','00317383','00317419','00317524','00317545','00317345','00317456','00317511','00317582','00317105','00317482','00317548','00317401','00317519','00317549','00317628','00317599','00317657','00317685','00317711','00317578','00317647','00317650','00317664','00317687','00317662','00317753','00317620','00317299','00317372','00317446','00317489','00317509','00317544','00317601','00317606','00317612','00317626','00317649','00317652','00317656','00317689','00317690','00317695','00317747','00317784','00317648','00317698','00317737','00317764','00317708','00317804','00317725','00317562','00317756','00317823','00317836','00317857','00317775','00317867','00317781','00317768','00317163','00317907','00317796','00317852','00317910','00317959','00317565','00317780','00317949','00317981','00317809','00317936','00317983','00318023','00318028','00318025','00318031','00318045','00318049','00318075','00318074','00318043','00318004','00318047','00318038','00318085','00318110','00318111','00318094','00318167','00317977','00318048','00318065','00318093','00318130','00318222','00318214','00318249','00318232','00318263','00318272','00318280','00318196','00318289','00318296','00318166','00318333','00318323','00318340','00318341','00318353','00318393','00318400','00318401'

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
