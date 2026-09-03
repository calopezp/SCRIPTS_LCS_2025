// SCRIPT CORREGIDO: Crear Payment REFUNDED por contracargo y 
// Crear REQUEST de chargebee para el Late Paymetn Fee
// Autor: CARLOS LOPEZ
// Fecha: AGOSTO 2026    

// ---------------- CONFIG ----------------
Boolean modoDryRun = true;   // true = simula, false = ejecuta
// ----------------------------------------

String AutorizacionCode = '105758';
String CodigoContracargo = '2653008279';
String authCodeCombined = (CodigoContracargo != null) ? AutorizacionCode + ' / ' + CodigoContracargo : AutorizacionCode;

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
           SM_Net_Amount__c,
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


// -----------------------------
// 3) Verificar si ya existe Payment REFUNDED para esta transacción
// -----------------------------
String authPrefix = AutorizacionCode + '%';
List<SM_Payment__c> existingRefunds = [
    SELECT Id, Name, SM_Amount__c, Payment_Status__c
    FROM SM_Payment__c
    WHERE SM_Authorization_Code__c LIKE :authPrefix
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

    newRefundPayment.SM_Authorization_Code__c = authCodeCombined;
if (!modoDryRun) {
        Savepoint sp = Database.setSavepoint();
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
            Database.rollback(sp);
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
           Historical_Claim_On_Record__c,
           SM_Customer_Cancellation__c,
           SM_Payment_Method__c, SM_Payment_Method__r.SM_Credit_Card_expiration_month__c, SM_Payment_Method__r.SM_Credit_Card_expiration_year__c, SM_Payment_Method__r.SM_Card_Token__c,
           SM_Payment_Method__r.RecordType.DeveloperName,
           CB_Subscription__c, CB_Subscription__r.chargebeeapps__Subscription_Plan__c,
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
    if (cont.Historical_Claim_On_Record__c != true) {
    cont.Historical_Claim_On_Record__c = true;
    if (!modoDryRun) {update cont;}
    }
    System.debug(' \u2192 ✅ Campo Historical_Claim_On_Record__c del contrato ' + cont.ContractNumber + ' actualizado a true.');

    //Actualizamos el campo Historical_Claim_On_Record__c de la cuenta a true para indicar que ya se ha generado un contracargo
    Account acc = [SELECT Id, Historical_Claim_On_Record__c,Has_Refund_History__c FROM Account WHERE Id = :cont.AccountId];
    if (acc.Historical_Claim_On_Record__c != true || acc.Has_Refund_History__c != true) {
    acc.Historical_Claim_On_Record__c = true;
    acc.Has_Refund_History__c = true;
    if (!modoDryRun) {update acc;}
    }
    System.debug(' \u2192 ✅ Campo Historical_Claim_On_Record__c de la cuenta ' + acc.Id + ' actualizado a true.');

    

Boolean contractEligibleForRequest = (cont.Status == 'Activated' || cont.Status == 'Payment Process')
    && cont.SM_Customer_Cancellation__c != true;

if (!contractEligibleForRequest) {
    System.debug(' \u2192 ⚠️ ALERTA: Contrato NO está elegible (Status: ' + cont.Status + ' - Customer Cancellation: ' + cont.SM_Customer_Cancellation__c + ')');
    System.debug(' \u2192 No se creará Late Payment Fee / Charge Request automáticamente.');
    System.debug(' \u2192 ');
    System.debug(' \u2192 =====================================');
    System.debug(' \u2192 PROCESO FINALIZADO');
    System.debug(' \u2192 =====================================');
    return;
}

// -----------------------------
// 6) Determinar método de pago actual del contrato y crear el Request correspondiente
// -----------------------------
String paymentMethodType = (cont.SM_Payment_Method__r != null && cont.SM_Payment_Method__r.RecordType != null)
    ? cont.SM_Payment_Method__r.RecordType.DeveloperName
    : null;

Decimal amountToCharge = (originalPayment.SM_Amount__c != null)
    ? originalPayment.SM_Amount__c.abs()
    : 0;

if (paymentMethodType == 'ACH') {

    // 6.1) ACH: Verificar si ya existe un Late Payment Fee (SM_ACH_Order__c) para este contracargo
    String lpfReferenceKey = 'CONTRACARGO ' + AutorizacionCode + ' ' + originalPayment.Name;

    List<SM_ACH_Order__c> existingLPF = [
        SELECT Id, Name, SM_Total__c
        FROM SM_ACH_Order__c
        WHERE SM_Contract__c = :contractId
        AND SM_Payment_Type__c = 'Late payment fee'
        AND SM_Id_Salesforce_LCS__c = :lpfReferenceKey
    ];

    if (!existingLPF.isEmpty()) {
        System.debug(' \u2192 LPF ya existe para este contracargo - Id: ' + existingLPF[0].Id + ' Name: ' + existingLPF[0].Name + ' Total: ' + existingLPF[0].SM_Total__c);
        System.debug(' \u2192 No se creará otro Late Payment Fee.');
    } else {
        // 6.2) ACH: Crear Late Payment Fee (SM_ACH_Order__c)
        SM_ACH_Order__c newLPF = new SM_ACH_Order__c(
            SM_Contract__c = cont.Id,
            SM_Payment_Type__c = 'Late payment fee',
            SM_Payment_Frequency__c = 'Once',
            SM_Payment_Status__c = 'Pending',
            SM_Payment_Condition__c = 'Fixed value',
            SM_Billing_Email__c = cont.SM_Email_to_send_contract__c,
            SM_Payment_Count__c = 1,
            SM_Fee_to_collect__c = 1,
            SM_Payment_Start_Date__c = originalPayment.SM_Payment_Date__c,
            SM_Payment_End_Date__c = originalPayment.SM_Payment_Date__c,
            SM_Next_Transaction_Date__c = Date.today(),
            SM_Payment_Method__c = cont.SM_Payment_Method__c,
            SM_Total__c = amountToCharge,
            SM_Id_Salesforce_LCS__c = lpfReferenceKey
        );

        if (!modoDryRun) {
            Savepoint spLpf = Database.setSavepoint();
            try {
                insert newLPF;
                System.debug(' \u2192 Late Payment Fee (ACH) creado exitosamente - Id: ' + newLPF.Id + ' Total: ' + amountToCharge);
            } catch (Exception e) {
                Database.rollback(spLpf);
                System.debug(' \u2192 ERROR creando Late Payment Fee ACH - Mensaje: ' + e.getMessage() + ' Linea: ' + e.getLineNumber());
            }
        } else {
            System.debug(' \u2192 [DRY RUN] Se crearia Late Payment Fee ACH por: ' + amountToCharge);
        }
    }

} else if (paymentMethodType == 'Credit_Card') {

    // 6.1) TC: Determinar CB_Item_Price__c según el plan de la suscripción de Chargebee
    String subscriptionPlan = (cont.CB_Subscription__r != null) ? cont.CB_Subscription__r.chargebeeapps__Subscription_Plan__c : null;

    String itemPriceName;
    if (subscriptionPlan != null && subscriptionPlan.containsIgnoreCase('savera')) {
        itemPriceName = 'Late Payment Fee - Savera USD';
    } else if (subscriptionPlan != null && subscriptionPlan.containsIgnoreCase('Credit Up')) {
        itemPriceName = 'Late Payment Fee - CU USD';
    } else if (subscriptionPlan != null && subscriptionPlan.containsIgnoreCase('Credit Elevator')) {
        itemPriceName = 'Late Payment Fee - CE USD';
    } else {
        itemPriceName = 'Late Payment Fee - CR USD';
    }

    if (cont.CB_Subscription__c == null) {
        System.debug(' \u2192 ERROR: El contrato ' + cont.ContractNumber + ' no tiene CB_Subscription__c asignado. No se puede crear el Chargebee Charge Request.');
    } else {
        List<chargebeeapps__CB_Item_Price__c> itemPrices = [
            SELECT Id, Name
            FROM chargebeeapps__CB_Item_Price__c
            WHERE Name = :itemPriceName
            LIMIT 1
        ];

        if (itemPrices.isEmpty()) {
            System.debug(' \u2192 ERROR: No se encontró chargebeeapps__CB_Item_Price__c con Name = ' + itemPriceName);
        } else {
            // 6.2) TC: Verificar si ya existe un CB_Charge_Request__c para este contracargo
            String chargeRequestNotes = 'CONTRACARGO : ' + authCodeCombined;

            List<CB_Charge_Request__c> existingChargeRequest = [
                SELECT Id, Name
                FROM CB_Charge_Request__c
                WHERE CB_Subscription__c = :cont.CB_Subscription__c
                AND Notes__c = :chargeRequestNotes
            ];

            if (!existingChargeRequest.isEmpty()) {
                System.debug(' \u2192 CB_Charge_Request__c ya existe para este contracargo - Id: ' + existingChargeRequest[0].Id);
                System.debug(' \u2192 No se creará otro Chargebee Charge Request.');
            } else {
                // 6.3) TC: Crear Chargebee Charge Request
                CB_Charge_Request__c newChargeRequest = new CB_Charge_Request__c(
                    CB_Subscription__c = cont.CB_Subscription__c,
                    Product__c = subscriptionPlan,
                    CB_Item_Price__c = itemPrices[0].Id,
                    Charge_Date__c = Date.today().addDays(1),
                    Request_Date__c = originalPayment.SM_Payment_Date__c,
                    Request_Status__c = 'Pending',
                    Charge_Amount__c = originalPayment.SM_Net_Amount__c,
                    Notes__c = chargeRequestNotes
                );

                if (!modoDryRun) {
                    Savepoint spCbr = Database.setSavepoint();
                    try {
                        insert newChargeRequest;
                        System.debug(' \u2192 CB_Charge_Request__c creado exitosamente - Id: ' + newChargeRequest.Id + ' ItemPrice: ' + itemPriceName + ' Amount: ' + originalPayment.SM_Net_Amount__c);
                    } catch (Exception e) {
                        Database.rollback(spCbr);
                        System.debug(' \u2192 ERROR creando CB_Charge_Request__c - Mensaje: ' + e.getMessage() + ' Linea: ' + e.getLineNumber());
                    }
                } else {
                    System.debug(' \u2192 [DRY RUN] Se crearia CB_Charge_Request__c con: \n ' +
                    '\u2192 ItemPrice: ' + itemPriceName + '\n' + 
                    ' \u2192 Product: ' + subscriptionPlan + '\n' + 
                    ' \u2192 Amount: ' + originalPayment.SM_Net_Amount__c
                
                );
                }
            }
        }
    }

} else {
    System.debug(' \u2192 ERROR: RecordType del Payment Method del contrato ' + cont.ContractNumber + ' no reconocido (' + paymentMethodType + '). No se creó ningún Request.');
}
       
System.debug(' \u2192 =====================================');
System.debug(' \u2192 PROCESO FINALIZADO EXITOSAMENTE');
System.debug(' \u2192 =====================================');