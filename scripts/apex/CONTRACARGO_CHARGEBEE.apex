// SCRIPT CORREGIDO: Crear Payment REFUNDED por contracargo y 
// Crear REQUEST de chargebee para el Late Paymetn Fee
// Autor: CARLOS LOPEZ
// Fecha: AGOSTO 2026    

// ---------------- CONFIG ----------------
Boolean modoDryRun = false;   // true = simula, false = ejecuta
// ----------------------------------------

String AutorizacionCode = '995596';

System.debug(' \u2192 =====================================');
System.debug(' \u2192 INICIO PROCESO CONTRACARGO');
System.debug(' \u2192 Código Autorización: ' + AutorizacionCode);
System.debug(' \u2192 =====================================');

// -----------------------------
// 1)  Buscar Payment original vinculado a esta Transaction
// -----------------------------
List<SM_Payment__c> originalPayments = [
    SELECT Id, Name, 
           SM_Contract__c,
           SM_Amount__c,
           SM_Payment_execution_date__c,
           RecordTypeId,
           SM_Type__c,
           SM_Original_Type__c,
           SM_Penalty_value__c,
           SM_Fee_value__c,
           Payment_Status__c,
           SM_Payment_Due_Date__c,
           SM_Payment_Date__c,
           SM_Authorization_Code__c
    FROM SM_Payment__c
    WHERE  SM_Authorization_Code__c =: AutorizacionCode
    AND Payment_Status__c != 'REFUNDED'
    ORDER BY CreatedDate DESC
];
if (originalPayments.size() > 1) {
    System.debug(' \u2192 ⚠️ ALERTA: Se encontraron ' + originalPayments.size() + ' Payments vinculados a la Transaction.');
    System.debug(' \u2192 Se procesará solo el más reciente (por CreatedDate).');
}

if (originalPayments.isEmpty()) {
    System.debug(' \u2192 ❌ ERROR: No se encontró Payment original vinculado a la Autorizacion.');
    System.debug(' \u2192 AutorizacionCode : ' + AutorizacionCode);
    return;
}

SM_Payment__c originalPayment = originalPayments[0];
System.debug(' \u2192 ✅ Payment original encontrado:');
System.debug(' \u2192   - Id: ' + originalPayment.Id);
System.debug(' \u2192   - Name: ' + originalPayment.Name);
System.debug(' \u2192   - Amount: ' + originalPayment.SM_Amount__c);
System.debug(' \u2192   - Contract: ' + originalPayment.SM_Contract__c);
System.debug(' \u2192   - Status: ' + originalPayment.Payment_Status__c);
System.debug(' \u2192   - Type: ' + originalPayment.SM_Type__c);
System.debug(' \u2192   - Execution Date: ' + originalPayment.SM_Payment_execution_date__c);
System.debug(' \u2192   - Authorization Code : ' + originalPayment.SM_Authorization_Code__c);
System.debug(' \u2192 ');

/*
// -- Adicionar el codigo de autorización al Payment original para referencia
originalPayment.SM_Transaction_Id__c = 'AUTHCODE: ' + AutorizacionCode;
update originalPayment;
System.debug(' \u2192 ✅ Payment original actualizado con Autorización: ' + originalPayment.SM_Transaction_Id__c);
System.debug(' \u2192 ');
*/


// -----------------------------
// 3) Verificar si ya existe Payment REFUNDED para esta transacción
// -----------------------------
String authPattern = '%' + AutorizacionCode + '%';
List<SM_Payment__c> existingRefunds = [
    SELECT Id, Name, SM_Amount__c, Payment_Status__c
    FROM SM_Payment__c
    WHERE SM_Authorization_Code__c LIKE :authPattern
    AND Payment_Status__c = 'REFUNDED'
];

if (existingRefunds.size() > 1) {
    System.debug(' \u2192 ⚠️ ALERTA: Se encontraron ' + existingRefunds.size() + ' Payments REFUNDED con la misma autorización.');
    System.debug(' \u2192 Se considerará que ya existe un REFUNDED para esta autorización.');
}

if (!existingRefunds.isEmpty()) {
    System.debug(' \u2192 ⚠️ ALERTA: Ya existe Payment REFUNDED para esta autorización:');
    System.debug(' \u2192   - Id: ' + existingRefunds[0].Id);
    System.debug(' \u2192   - Name: ' + existingRefunds[0].Name);
    System.debug(' \u2192   - Amount: ' + existingRefunds[0].SM_Amount__c);
    System.debug(' \u2192 ');
    System.debug(' \u2192 No se creará otro Payment REFUNDED.');
    System.debug(' \u2192 Continuando con validación de Late Payment Fee...');
    System.debug(' \u2192 ');
} else {

    // -----------------------------
    // 4) Crear Payment REFUNDED
    // -----------------------------
    System.debug(' \u2192 📝 Creando Payment REFUNDED...');
    
    SM_Payment__c newRefundPayment = new SM_Payment__c();
    
    // Campos obligatorios y claves
    newRefundPayment.RecordTypeId = originalPayment.RecordTypeId;
    newRefundPayment.Payment_Status__c = 'REFUNDED';
    newRefundPayment.SM_Reason_for_refund__c = 'CONTRA CARGO';
    newRefundPayment.SM_Contract__c = originalPayment.SM_Contract__c;
    
    // Montos en NEGATIVO
    newRefundPayment.SM_Amount__c = (originalPayment.SM_Amount__c != null) 
        ? (originalPayment.SM_Amount__c * -1) 
        : null;
    
    newRefundPayment.SM_Penalty_value__c = (originalPayment.SM_Penalty_value__c != null) 
        ? (originalPayment.SM_Penalty_value__c * -1) 
        : null;
    
    newRefundPayment.SM_Fee_value__c = (originalPayment.SM_Fee_value__c != null) 
        ? (originalPayment.SM_Fee_value__c * -1) 
        : null;
    
    // Referencia al Payment original
    newRefundPayment.SM_Payments_refunded__c = originalPayment.Id;
    
    // Tipos
    newRefundPayment.SM_Type__c = originalPayment.SM_Type__c;
    newRefundPayment.SM_Original_Type__c = originalPayment.SM_Original_Type__c;
    
    // Fechas
    if (originalPayment.SM_Payment_execution_date__c != null) {
        newRefundPayment.SM_Payment_Due_Date__c = originalPayment.SM_Payment_execution_date__c.date();
        newRefundPayment.SM_Payment_Date__c = originalPayment.SM_Payment_execution_date__c.date();
    } else if (originalPayment.SM_Payment_Date__c != null) {
        newRefundPayment.SM_Payment_Due_Date__c = originalPayment.SM_Payment_Date__c;
        newRefundPayment.SM_Payment_Date__c = originalPayment.SM_Payment_Date__c;
    } else {
        newRefundPayment.SM_Payment_Due_Date__c = Date.today();
        newRefundPayment.SM_Payment_Date__c = Date.today();
    }
    
    // Campos adicionales
    newRefundPayment.SM_Authorization_Code__c = AutorizacionCode;
if (!modoDryRun) {    
        try {
            insert newRefundPayment;
            
            // Recargar para obtener datos calculados
            SM_Payment__c insertedPayment = [
                SELECT Id, Name, SM_Amount__c, Payment_Status__c
                FROM SM_Payment__c
                WHERE Id = :newRefundPayment.Id
            ];
            
            System.debug(' \u2192 ✅ Payment REFUNDED creado exitosamente:');
            System.debug(' \u2192   - Id: ' + insertedPayment.Id);
            System.debug(' \u2192   - Name: ' + insertedPayment.Name);
            System.debug(' \u2192   - Amount: ' + insertedPayment.SM_Amount__c);
            System.debug(' \u2192   - Status: ' + insertedPayment.Payment_Status__c);
            System.debug(' \u2192   - Referencias Payment Original: ' + originalPayment.Id);
            System.debug(' \u2192 ');
            
        } catch (Exception e) {
            System.debug(' \u2192 ❌ ERROR creando Payment REFUNDED:');
            System.debug(' \u2192   - Mensaje: ' + e.getMessage());
            System.debug(' \u2192   - Stack Trace: ' + e.getStackTraceString());
            System.debug(' \u2192   - Línea: ' + e.getLineNumber());
            return;
        }
    } 
}

// -----------------------------
// 5) Validar si el contrato está activo para crear Late Payment Fee
// -----------------------------
Id contractId = originalPayment.SM_Contract__c;

if (contractId == null) {
    System.debug(' \u2192 ❌ ERROR: No se pudo obtener el Contract Id del Payment.');
    return;
}

Contract cont = [
    SELECT Id, Status, ContractNumber,
           AccountId, 
           SM_Payment_Method__c, SM_Payment_Method__r.SM_Credit_Card_expiration_month__c, SM_Payment_Method__r.SM_Credit_Card_expiration_year__c, SM_Payment_Method__r.SM_Card_Token__c,
           SM_Email_to_send_contract__c,
           GatewayId__c,
           Account.FirstName, 
           Account.LastName, 
           Account.BillingCountry
    FROM Contract
    WHERE Id = :contractId
];

System.debug(' \u2192 📋 Datos del Contrato:');
System.debug(' \u2192   - Number: ' + cont.ContractNumber);
System.debug(' \u2192   - Status: ' + cont.Status);
System.debug(' \u2192   - Account: ' + cont.AccountId);
System.debug(' \u2192   - Payment Method: ' + cont.SM_Payment_Method__c);
System.debug(' \u2192 ');

if (!modoDryRun) {
    //Actualizamos el campo Historical_Claim_On_Record__c del contrato a true para indicar que ya se ha generado un contracargo
    cont.Historical_Claim_On_Record__c = true;
    update cont;
    System.debug(' \u2192 ✅ Campo Historical_Claim_On_Record__c del contrato ' + cont.ContractNumber + ' actualizado a true.');

    //Actualizamos el campo Historical_Claim_On_Record__c de la cuenta a true para indicar que ya se ha generado un contracargo
    Account acc = [SELECT Id, Historical_Claim_On_Record__c,Has_Refund_History__c FROM Account WHERE Id = :cont.AccountId];
    acc.Historical_Claim_On_Record__c = true;
    acc.Has_Refund_History__c = true;
    update acc;
    System.debug(' \u2192 ✅ Campo Historical_Claim_On_Record__c de la cuenta ' + acc.Id + ' actualizado a true.');
}


if (cont.Status != 'Activated') {
    System.debug(' \u2192 ⚠️ ALERTA: Contrato NO está Activated (Status: ' + cont.Status + ')');
    System.debug(' \u2192 No se creará Late Payment Fee automáticamente.');
    System.debug(' \u2192 ');
    System.debug(' \u2192 =====================================');
    System.debug(' \u2192 PROCESO FINALIZADO');
    System.debug(' \u2192 =====================================');
    return;
}

        // -----------------------------
        // 6) Verificar si ya existe UN  REQUEST o INVOICE para este contrato con CONTRA CARGO
        // -----------------------------
       
System.debug(' \u2192 =====================================');
System.debug(' \u2192 PROCESO FINALIZADO EXITOSAMENTE');
System.debug(' \u2192 =====================================');