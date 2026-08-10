// SCRIPT CORREGIDO: Crear Payment REFUNDED por contracargo y 
// Crear REQUEST de chargebee para el Late Paymetn Fee
// Autor: CARLOS LOPEZ
// Fecha: AGOSTO 2026    

String AutorizacionCode = '905770';

System.debug(' \u2192 =====================================');
System.debug(' \u2192 INICIO PROCESO CONTRACARGO');
System.debug(' \u2192 Código Autorización: ' + AutorizacionCode);
System.debug(' \u2192 =====================================');

// -----------------------------
// 1) Buscar Chargent Transaction por autorización
// -----------------------------
List<ChargentOrders__Transaction__c> txnList = [
    SELECT Id, Name, 
           ChargentOrders__Authorization__c, 
           ChargentOrders__Order__c, 
           ChargentOrders__Card_Last_4__c,
           ChargentOrders__Order__r.Contract__c,
           ChargentOrders__Order__r.Contract__r.ContractNumber,
           ChargentOrders__Order__r.Contract__r.Status
    FROM ChargentOrders__Transaction__c
    WHERE ChargentOrders__Authorization__c = :AutorizacionCode
];

if (txnList.isEmpty()) {
    System.debug(' \u2192 ❌ ERROR: No se encontró Transaction con autorización: ' + AutorizacionCode);
    return;
}

if (txnList.size() > 1) {
    System.debug(' \u2192 ⚠️ ALERTA: Se encontraron ' + txnList.size() + ' Transactions con la misma autorización.');
    System.debug(' \u2192 Se procesará solo la primera.');
}

ChargentOrders__Transaction__c txn = txnList[0];
System.debug(' \u2192 ✅ Transaction encontrada:');
System.debug(' \u2192   - Id: ' + txn.Id);
System.debug(' \u2192   - Name: ' + txn.Name);
System.debug(' \u2192                             => Authorization : ' + txn.ChargentOrders__Authorization__c);
System.debug(' \u2192                             => Card Last 4   : ' + txn.ChargentOrders__Card_Last_4__c);
System.debug(' \u2192   - Order: ' + txn.ChargentOrders__Order__c);
System.debug(' \u2192   - Contract: ' + txn.ChargentOrders__Order__r.Contract__r.ContractNumber);
System.debug(' \u2192   - Contract Status: ' + txn.ChargentOrders__Order__r.Contract__r.Status);
System.debug(' \u2192 ');

// -----------------------------
// 2) Buscar Payment original vinculado a esta Transaction
// -----------------------------
List<SM_Payment__c> originalPayments = [
    SELECT Id, Name, 
           SM_Contract__c,
           SM_Amount__c,
           SM_Payment_execution_date__c,
           SM_Chargent_Orders_Transaction__c,
           RecordTypeId,
           SM_Type__c,
           SM_Original_Type__c,
           SM_Penalty_value__c,
           SM_Fee_value__c,
           Payment_Status__c,
           SM_Payment_Due_Date__c,
           SM_Payment_Date__c
    FROM SM_Payment__c
    WHERE SM_Chargent_Orders_Transaction__c = :txn.Id
    AND Payment_Status__c != 'REFUNDED'
    ORDER BY CreatedDate DESC
];
if (originalPayments.size() > 1) {
    System.debug(' \u2192 ⚠️ ALERTA: Se encontraron ' + originalPayments.size() + ' Payments vinculados a la Transaction.');
    System.debug(' \u2192 Se procesará solo el más reciente (por CreatedDate).');
}

if (originalPayments.isEmpty()) {
    System.debug(' \u2192 ❌ ERROR: No se encontró Payment original vinculado a la Transaction.');
    System.debug(' \u2192 Transaction Id: ' + txn.Id);
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
System.debug(' \u2192 ');

// -- Adicionar el codigo de autorización al Payment original para referencia
originalPayment.SM_Transaction_Id__c = 'AUTHCODE: ' + AutorizacionCode;
update originalPayment;
System.debug(' \u2192 ✅ Payment original actualizado con Autorización: ' + originalPayment.SM_Transaction_Id__c);
System.debug(' \u2192 ');
// -----------------------------
// 3) Verificar si ya existe Payment REFUNDED para esta transacción
// -----------------------------
String authPattern = '%' + AutorizacionCode + '%';
List<SM_Payment__c> existingRefunds = [
    SELECT Id, Name, SM_Amount__c, Payment_Status__c
    FROM SM_Payment__c
    WHERE SM_Transaction_Id__c LIKE :authPattern
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
    newRefundPayment.SM_Transaction_Id__c = 'AUTHCODE: ' + AutorizacionCode;
    newRefundPayment.SM_Chargent_Orders_Transaction__c = txn.Id;
    newRefundPayment.SM_Is_Migrated__c = true;
    
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

if (cont.Status != 'Activated') {
    System.debug(' \u2192 ⚠️ ALERTA: Contrato NO está Activated (Status: ' + cont.Status + ')');
    System.debug(' \u2192 No se creará Late Payment Fee automáticamente.');
    System.debug(' \u2192 ');
    System.debug(' \u2192 =====================================');
    System.debug(' \u2192 PROCESO FINALIZADO');
    System.debug(' \u2192 =====================================');
    return;
}

/* rediseñar la creacion del LPF


        // -----------------------------
        // 6) Verificar si ya existe Late Payment Fee para este contrato con CONTRA CARGO
        // -----------------------------
        String authPattern = '%' + AutorizacionCode + '%';
        List<ChargentOrders__ChargentOrder__c> existingLPF = [
            SELECT Id, Name, 
                ChargentOrders__Charge_Amount__c, 
                SM_PTP_Montly__c, 
                SM_Payment_Type__c
            FROM ChargentOrders__ChargentOrder__c
            WHERE Contract__c = :contractId
            AND SM_Payment_Type__c = 'Late Payment fee'
            AND SM_PTP_Montly__c = 'CONTRA CARGO'
            AND SM_Id_Salesforce_LCS__c LIKE :authPattern
        ];

        if (!existingLPF.isEmpty()) {
            System.debug(' \u2192 ⚠️ Ya existe Late Payment Fee tipo CONTRA CARGO:');
            System.debug(' \u2192   - Id: ' + existingLPF[0].Id);
            System.debug(' \u2192   - Name: ' + existingLPF[0].Name);
            System.debug(' \u2192   - Amount: ' + existingLPF[0].ChargentOrders__Charge_Amount__c);
            System.debug(' \u2192   - Mes: ' + existingLPF[0].SM_PTP_Montly__c);
            System.debug(' \u2192 ');
            System.debug(' \u2192 No se creará otro Late Payment Fee.');
            System.debug(' \u2192 ');
            System.debug(' \u2192 =====================================');
            System.debug(' \u2192 PROCESO FINALIZADO');
            System.debug(' \u2192 =====================================');
            return;
        }

        // -----------------------------
        // 7) Crear Late Payment Fee (Chargent Order)
        // -----------------------------
        System.debug(' \u2192 📝 Creando Late Payment Fee...');

        Decimal amountToCharge = (originalPayment.SM_Amount__c != null) 
            ? originalPayment.SM_Amount__c.abs() 
            : 0;

        ChargentOrders__ChargentOrder__c newLPF = new ChargentOrders__ChargentOrder__c();

        // Campos obligatorios
        newLPF.Contract__c = cont.Id;
        newLPF.ChargentOrders__Account__c = cont.AccountId;
        newLPF.SM_PTP_Montly__c = 'CONTRA CARGO';
        newLPF.SM_Payment_Type__c = 'Late Payment fee';
        newLPF.ChargentOrders__Payment_Method__c = 'Credit Card';
        newLPF.SM_Purpose_of_Payment__c = 'Contract fee';

        // Configuración de pago
        newLPF.SM_Fee_to_collect__c = 1;
        newLPF.ChargentOrders__Payment_Frequency__c = 'Once';
        newLPF.ChargentOrders__Payment_Status__c = 'Recurring';
        newLPF.ChargentOrders__Payment_Stop__c = 'Count';
        newLPF.ChargentOrders__Payment_Count__c = 1;

        // Penalty
        newLPF.SM_IsApplyingDaysCollectedPenalty__c = true;
        newLPF.SM_Apply_Penalty__c = true;
        newLPF.SM_Penalty_Value__c = 25;

        // Montos
        newLPF.ChargentOrders__Subtotal__c = amountToCharge;
        newLPF.ChargentOrders__Tax__c = 0;
        newLPF.ChargentOrders__Charge_Amount__c = amountToCharge;

        // Fechas
        newLPF.ChargentOrders__Payment_Start_Date__c = Date.today();
        newLPF.ChargentOrders__Payment_End_Date__c = Date.today();
        newLPF.ChargentOrders__Next_Transaction_Date__c = Date.today();

        // Tarjeta
        newLPF.ChargentOrders__Card_Last_4__c = txn.ChargentOrders__Card_Last_4__c;
        String cardNumber = String.isNotBlank(txn.ChargentOrders__Card_Last_4__c) 
            ? txn.ChargentOrders__Card_Last_4__c.replaceAll('\\s+','') 
            : '';
        newLPF.ChargentOrders__Card_Number__c = cardNumber;
        newLPF.ChargentOrders__Card_Expiration_Month__c = cont.SM_Payment_Method__r.SM_Credit_Card_expiration_month__c;
        newLPF.ChargentOrders__Card_Expiration_Year__c = cont.SM_Payment_Method__r.SM_Credit_Card_expiration_year__c;
        newLPF.ChargentOrders__Card_Month_Indicator__c = cont.SM_Payment_Method__r.SM_Credit_Card_expiration_month__c;
        newLPF.ChargentOrders__Card_Year_Indicator__c = cont.SM_Payment_Method__r.SM_Credit_Card_expiration_year__c;



        // Gateway
        newLPF.ChargentOrders__Gateway__c = cont.GatewayId__c;
        newLPF.ChargentOrders__Tokenization__c = cont.SM_Payment_Method__r.SM_Card_Token__c; //         ***** CONTRACARGO NO TIENE TOKENIZATION, SE DEJA VACÍO *****
        newLPF.ChargentOrders__Billing_Country__c = (cont.Account.BillingCountry == 'Puerto Rico') 
            ? 'PR' 
            : cont.Account.BillingCountry;

        // Campos de facturación
        newLPF.ChargentOrders__Billing_First_Name__c = cont.Account.FirstName;
        newLPF.ChargentOrders__Billing_Last_Name__c = cont.Account.LastName;
        newLPF.ChargentOrders__Billing_Email__c = cont.SM_Email_to_send_contract__c;
        newLPF.ChargentOrders__Billing_Country__c = (cont.Account.BillingCountry == 'Puerto Rico') 
            ? 'PR' 
            : cont.Account.BillingCountry;

        // Campos adicionales
        newLPF.SM_Migrated__c = false;
        newLPF.SM_Id_Salesforce_LCS__c = 'CONTRACARGO ' + AutorizacionCode + ' ' + originalPayment.Name;

        try {
            insert newLPF;
            
            ChargentOrders__ChargentOrder__c insertedLPF = [
                SELECT Id, Name, ChargentOrders__Charge_Amount__c, SM_Payment_Type__c
                FROM ChargentOrders__ChargentOrder__c
                WHERE Id = :newLPF.Id
                LIMIT 1
            ];
            
            System.debug(' \u2192 ✅ Late Payment Fee creado exitosamente:');
            System.debug(' \u2192   - Id: ' + insertedLPF.Id);
            System.debug(' \u2192   - Name: ' + insertedLPF.Name);
            System.debug(' \u2192   - Amount: ' + insertedLPF.ChargentOrders__Charge_Amount__c);
            System.debug(' \u2192   - Type: ' + insertedLPF.SM_Payment_Type__c);
            System.debug(' \u2192 ');
            
        } catch (Exception e) {
            System.debug(' \u2192 ❌ ERROR creando Late Payment Fee:');
            System.debug(' \u2192   - Mensaje: ' + e.getMessage());
            System.debug(' \u2192   - Stack Trace: ' + e.getStackTraceString());
            System.debug(' \u2192   - Línea: ' + e.getLineNumber());
        }
*/
System.debug(' \u2192 =====================================');
System.debug(' \u2192 PROCESO FINALIZADO EXITOSAMENTE');
System.debug(' \u2192 =====================================');