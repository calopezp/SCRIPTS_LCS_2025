/******************************************************************************************
*  SCRIPT COMPLETO – ACH Transmit + CSV + Lotes de 100 + Control de Trigger Panel
*  Autor: Carlos (versión optimizada)
*  Fecha: Mayo 2026
******************************************************************************************/

// =========================================================================================
// 0️⃣ DESACTIVAR TRIGGER para cargas de mas de 100 registros (Process OnAfter Update)
// CNT: https://monee.my.salesforce-setup.com/lightning/setup/CustomMetadata/page?address=%2Fm091U000000hQRF%2Fe%3FretURL%3D%252Fm09%253Fsetupid%253DCustomMetadata%2526appLayout%253Dsetup%2526tour%253D%2526isdtp%253Dp1%2526sfdcIFrameOrigin%253Dhttps%25253A%25252F%25252Fmonee.my.salesforce-setup.com%2526sfdcIFrameHost%253Dweb%2526nonce%253Db1754f7230d38462cd02abb7401fb1862c4cce5a05cc95e65682e8d9374d9386%2526ltn_app_id%253D%2526clc%253D1
// PY : https://monee.my.salesforce-setup.com/lightning/setup/CustomMetadata/page?address=%2Fm091U000000IFR3%2Fe%3FretURL%3D%252Fm091U000000IFR3%253FappLayout%253Dsetup%2526tour%253D%2526sfdcIFrameOrigin%253Dhttps%25253A%25252F%25252Fmonee.my.salesforce-setup.com%2526sfdcIFrameHost%253Dweb%2526nonce%253Db1754f7230d38462cd02abb7401fb1862c4cce5a05cc95e65682e8d9374d9386%2526ltn_app_id%253D%2526clc%253D1%2526isdtp%253Dp1
// =========================================================================================

/*
//#region Trigger_Panel_1
List<SM_Trigger_Panel__mdt> triggerPanel = [
    SELECT Id, SM_ProcessOnAfterUpdate__c
    FROM SM_Trigger_Panel__mdt
    WHERE SM_TriggerName__c = 'SM_PaymentTrigger'
];

Boolean originalState = false;

if (!triggerPanel.isEmpty()) {
    originalState = triggerPanel[0].SM_ProcessOnAfterUpdate__c;
    triggerPanel[0].SM_ProcessOnAfterUpdate__c = false;
    update triggerPanel;
}

System.debug('\u2192  ⚠ Trigger SM_PaymentTrigger DESACTIVADO temporalmente');
//#endregion Trigger_Panel_1
*/

// =========================================================================================
// 1️⃣ DATOS FIJOS
// =========================================================================================

Id ownerId         = '0051U000001MRFeQAO';
Id logRecordTypeId = '0121U000000KY48QAG';
String fileName    = 'Cargue Manual scr';
Date dateValue     = System.today().addDays(-1);
String dateStr     = dateValue.format(); //DateTime.newInstance(System.today(), Time.newInstance(18,0,0,0)).format('yyyy-MM-dd');



// =========================================================================================
// 2️⃣ QUERY PRINCIPAL
// =========================================================================================

List<SM_Payment__c> pagos = [
    SELECT Id, SM_ACH_Account_Routing_Number__c, SM_Payment_Method__r.SM_ACH_Account_Number__c,
           SM_ACH_Account_Type_Code__c, SM_Person_Account_Name__c, Name, SM_Net_Amount__c,
           SM_ACH_Order__r.Name, SM_Payment_Method__r.Name, Payment_Status__c, SM_Contract__r.Name
    FROM   SM_Payment__c
    WHERE  (Payment_Status__c = 'ACH PENDING' OR Payment_Status__c = 'ACH PENDING REFUND')
      AND  SM_Contract__r.SM_Customer_Cancellation__c = false
      AND  SM_Contract__r.SM_Customer_Cancellation__c = false
      AND  SM_Contract__r.SM_Full_Payment__c = false
      AND (SM_Contract__r.Status = 'Activated' OR SM_Contract__r.Status = 'Payment Process')
    ORDER BY CreatedDate DESC
];

system.debug(' \u2192 Payments a procesar : ' + pagos.size());

Integer cantidad = pagos.size();
if (cantidad == 0) {
    System.debug(' \u2192  No hay pagos ACH PENDING para procesar. Script finalizado.');
    return;
}
Decimal total = 0;
for (SM_Payment__c p : pagos) total += p.SM_Net_Amount__c;

//Validar que no hayan ach repetidos






// =========================================================================================
// 3️⃣ CREAR NACHA FILE
// =========================================================================================

SM_Nacha_File__c nacha = new SM_Nacha_File__c(
    OwnerId                         = ownerId,
    SM_Estado__c                    = 'Success',
    SM_Fecha_Transmision__c         = DateTime.newInstance(dateValue, Time.newInstance(18,0,0,0)),
    SM_Nombre_Archivo__c            = fileName,
    SM_Payments_Transmitidos__c     = cantidad,
    SM_Total_Valor_Transaccione__c  = total,
    SM_Supera_Monto_Diario__c       = false,
    SM_Retransmision__c             = false
);
insert nacha;


// =========================================================================================
// 4️⃣ FUNCIONES AUXILIARES
// =========================================================================================

String normalize(String input){
    if (input == null) return '';
    input = input.toUpperCase();
    Map<String,String> mapa = new Map<String,String>{
        'Á'=>'A','É'=>'E','Í'=>'I','Ó'=>'O','Ú'=>'U',
        'À'=>'A','È'=>'E','Ì'=>'I','Ò'=>'O','Ù'=>'U',
        'Ä'=>'A','Ë'=>'E','Ï'=>'I','Ö'=>'O','Ü'=>'U',
        'Ñ'=>'N'
    };
    for (String key : mapa.keySet()) input = input.replace(key, mapa.get(key));
    return input;
}

String tipoLetra(SM_Payment__c p){
    String status = p.Payment_Status__c;
    String codigo = p.SM_ACH_Account_Type_Code__c;

    if (status.containsIgnoreCase('REFUND')) {
        return codigo == '22' ? '1' : codigo == '32' ? '2' : '';
    } else {
        return codigo == '27' ? '1' : codigo == '37' ? '2' : '';
    }
}


// =========================================================================================
// 5️⃣ PROCESAMIENTO POR LOTES DE 100
// =========================================================================================

List<String> lineas = new List<String>();
lineas.add('ID,Name,Routing,Account,TypeCode,PersonName,Amount,OrderName,MethodName');

List<SM_TransactionLog__c> logsBatch = new List<SM_TransactionLog__c>();
List<SM_Payment__c> updBatch        = new List<SM_Payment__c>();

Integer lote = 1;
Integer procesados = 0;

for (Integer i = 0; i < pagos.size(); i++) {

    SM_Payment__c p = pagos[i];

    // CSV
    lineas.add(
        p.Name + ',' +
        p.SM_ACH_Account_Routing_Number__c + ',' +
        p.SM_Payment_Method__r.SM_ACH_Account_Number__c + ',' +
        tipoLetra(p) + ',' +
        P.SM_Net_Amount__c.setScale(2) + ',' +
        p.SM_ACH_Order__r.Name + ',' +
        p.SM_Contract__r.Name
    );

    // LOG
    logsBatch.add(new SM_TransactionLog__c(
        OwnerId        = ownerId,
        RecordTypeId   = logRecordTypeId,
        SM_StatusCode__c = 200,
        SM_Response__c = 'Global Process: Sender OK - ' + dateStr,
        Payment__c     = p.Id
    ));

    // UPDATE
    updBatch.add(new SM_Payment__c(
        Id                       = p.Id,
        Payment_Status__c        = p.Payment_Status__c.contains('REFUND') ? 'ACH TRANSMITTED REFUND' : 'ACH TRANSMITTED',
        SM_Nacha_File__c         = nacha.Id,
        SM_Date_ACH_Transmitted__c = DateTime.newInstance(dateValue, Time.newInstance(18,0,0,0)) //DateTime.newInstance(System.today(), Time.newInstance(18,0,0,0))
    ));

    procesados++;

    // Ejecutar lote
    if (logsBatch.size() == 100 || i == pagos.size() - 1) {

        insert logsBatch;
        update updBatch;

        System.debug('\u2192  Lote ' + lote + ' procesado (' + logsBatch.size() + ' registros)');

        logsBatch.clear();
        updBatch.clear();
        lote++;
    }
}


// =========================================================================================
// 6️⃣ CREAR CSV
// =========================================================================================

String csvBody = String.join(lineas, '\n');

ContentVersion cv = new ContentVersion(
    Title           = 'ACH_' + dateStr + '.csv', //DateTime.now().format('yyyyMMdd') + '.csv',
    PathOnClient    = 'ACH_' + dateStr + '.csv', //DateTime.now().format('yyyyMMdd') + '.csv',
    VersionData     = Blob.valueOf(csvBody),
    IsMajorVersion  = true
);
insert cv;

// =========================================================================================
// 7️⃣ REACTIVAR TRIGGER
// =========================================================================================
/*
//#region Trigger_Panel_2
triggerPanel[0].SM_ProcessOnAfterUpdate__c = originalState;
update triggerPanel;

System.debug('\u2192  ✔ Trigger SM_PaymentTrigger REACTIVADO');
//#endregion Trigger_Panel_2
*/

// =========================================================================================
// 8️⃣ LOGS FINALES
// =========================================================================================

System.debug('\u2192  CSV creado: /lightning/r/ContentVersion/' + cv.Id + '/view');
System.debug('\u2192  Registros procesados: ' + procesados);
System.debug('\u2192  Total Amount: ' + total.setScale(2));
System.debug('\u2192  Nacha: ' + nacha.Id);
System.debug('\u2192  Script finalizado correctamente');
