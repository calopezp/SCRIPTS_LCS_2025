//  SCRIPT COMPLETO – ACH Transmit + CSV sin headers + letra C/S
//  Abril 2026

// 1. Datos fijos
Id   ownerId         = '0051U000001MRFeQAO';
Id   logRecordTypeId = '0121U000000KY48QAG';
String fileName      = 'Cargue Manual scr';
String dateStr       = DateTime.newInstance(System.today(), Time.newInstance(18,0,0,0)).format('yyyy-MM-dd');

// 2. Query pagos ACH PENDING
List<SM_Payment__c> pagos = [
    SELECT Id, SM_ACH_Account_Routing_Number__c, SM_Payment_Method__r.SM_ACH_Account_Number__c,
           SM_ACH_Account_Type_Code__c, SM_Person_Account_Name__c, Name, SM_Net_Amount__c,
           SM_ACH_Order__r.Name, SM_Payment_Method__r.Name, Payment_Status__c
    FROM   SM_Payment__c
    WHERE  (Payment_Status__c = 'ACH PENDING' OR Payment_Status__c = 'ACH PENDING REFUND')
      AND  SM_Contract__r.SM_Customer_Cancellation__c = false
      AND  SM_Contract__r.SM_Full_Payment__c = false
      AND (SM_Contract__r.Status = 'Activated' OR SM_Contract__r.Status = 'Payment Process')
    ORDER BY CreatedDate DESC
];

// 3. Totales
Integer cantidad = pagos.size();
Decimal total    = 0;
for(SM_Payment__c p : pagos) total += p.SM_Net_Amount__c;

// 3. Crear Nacha
SM_Nacha_File__c nacha = new SM_Nacha_File__c(
    OwnerId                         = ownerId,
    SM_Estado__c                    = 'Success',
    SM_Fecha_Transmision__c         = DateTime.newInstance(System.today(), Time.newInstance(18,0,0,0)),
    SM_Nombre_Archivo__c            = fileName,
    SM_Payments_Transmitidos__c     = cantidad,
    SM_Total_Valor_Transaccione__c  = total,
    SM_Supera_Monto_Diario__c       = false,
    SM_Retransmision__c             = false
);
insert nacha;

// 4. Preparar Logs y Updates
List<SM_TransactionLog__c> logs = new List<SM_TransactionLog__c>();
List<SM_Payment__c>        upd  = new List<SM_Payment__c>();

for(SM_Payment__c pago : pagos){
    logs.add(new SM_TransactionLog__c(
        OwnerId        = ownerId,
        RecordTypeId   = logRecordTypeId,
        SM_StatusCode__c = 200,
        SM_Response__c = 'Global Process: Sender🔸 Get: The payment was collected correctly on ' + dateStr +
                         '-  MANUAL CHARGE - ,Status OK, 🔸 Process: Payment was successfully processed in  ' +
                         dateStr + '-,Status OK, 🔸 Send: The payment was sent successfully 🔸 SM_Nacha_File__c: ' +
                         nacha.Id + ' in ' + dateStr + '-  MANUAL CHARGE - ,Status OK',
        Payment__c  = pago.Id
    ));

    upd.add(new SM_Payment__c(
        Id                       = pago.Id,
        Payment_Status__c        = pago.Payment_Status__c == 'ACH PENDING REFUND' ? 'ACH TRANSMITTED REFUND' : 'ACH TRANSMITTED',
        SM_Nacha_File__c         = nacha.Id,
        SM_Date_ACH_Transmitted__c = DateTime.newInstance(System.today(), Time.newInstance(18,0,0,0))
    ));
}

insert logs;
update upd;

// 5. Normaliza (quita tildes y ñ)
String normalize(String input){
    if (input == null) return '';
    input = input.toUpperCase();
    Map<String,String> mapa = new Map<String,String>{
        'Á' => 'A', 'É' => 'E', 'Í' => 'I', 'Ó' => 'O', 'Ú' => 'U',
        'À' => 'A', 'È' => 'E', 'Ì' => 'I', 'Ò' => 'O', 'Ù' => 'U',
        'Ä' => 'A', 'Ë' => 'E', 'Ï' => 'I', 'Ö' => 'O', 'Ü' => 'U',
        'Ñ' => 'N'
    };
    for (String key : mapa.keySet()) input = input.replace(key, mapa.get(key));
    return input;
}

// 6️⃣ TRADUCCIÓN CÓDIGO → LETRA (C/S)
String tipoLetra(SM_Payment__c p){
    String status = String.valueOf(p.Payment_Status__c);
    String codigo = p.SM_ACH_Account_Type_Code__c;

    if (status.containsIgnoreCase('REFUND')) {
        return codigo == '22' ? 'C' :
               codigo == '32' ? 'S' : '';
    } else {
        return codigo == '27' ? 'C' :
               codigo == '37' ? 'S' : '';
    }
}

// 7️⃣ Construye CSV **SIN encabezados**
List<String> lineas = new List<String>();
lineas.add('ID,Name,Routing,Account,TypeCode,PersonName,Amount,OrderName,MethodName'); // encabezado

for (SM_Payment__c p : pagos){
    lineas.add(
        String.valueOf(p.SM_ACH_Account_Routing_Number__c) + ',' +
        String.valueOf(p.SM_Payment_Method__r.SM_ACH_Account_Number__c) + ',' +
        tipoLetra(p) + ',' +                           // ← letra C/S
        normalize(p.SM_Person_Account_Name__c) + ',' +
        p.Name + ',' +
        p.SM_Net_Amount__c.setScale(2) + ',' +
        p.SM_ACH_Order__r.Name + ',' +
        p.SM_Payment_Method__r.Name
    );
}
String csvBody = String.join(lineas, '\n');

// 8️⃣ Guardar File
ContentVersion cv = new ContentVersion(
    Title           = 'ACH_' + DateTime.now().format('yyyyMMdd') + '.csv',
    PathOnClient    = 'ACH_' + DateTime.now().format('yyyyMMdd') + '.csv',
    VersionData     = Blob.valueOf(csvBody),
    IsMajorVersion  = true
);
insert cv;

System.debug(' →  ✅CSV sin headers creado: /lightning/r/ContentVersion/' + cv.Id + '/view');

// 9️⃣ Logs finales
System.debug(' →  ✅ Nacha: ' + nacha.Id + ' - Logs: ' + logs.size() + ' - Pagos upd: ' + upd.size());
System.debug(' →  ✅ Registros   :  ' + cantidad + ' • Total Amount : ' + total.setScale(2));
System.debug(' →  Asunto del correo:\n\n Envío ACH ' + DateTime.newInstance(System.today(), Time.newInstance(0,0,0,0)).format('yyyyMMdd'));
System.debug(' →  Cuerpo del correo:\n\n .\n\nBuenas tardes\n\nAdjunto archivo de ACH para el día de hoy.\n\n• Registros   :  ' + cantidad + '\n• Total Amount : ' + total.setScale(2) + '\n\nFavor confirmar el cargue para poder hacer la marcación en Salesforce\nGracias. \n\n.');
System.debug(' →  Registros   :  ' + cantidad + ' • Total Amount : ' + total.setScale(2));