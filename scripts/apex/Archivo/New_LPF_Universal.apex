// CREAR LPF ACH/TC + PARÁMETROS
//
// ------------- CONFIGURAR -------------  :)
String contratoId = '00314597';
Date fechaCobro = Date.newInstance(2025, 11, 04);
String OrdType = 'Late Payment fee'; //  'Subscription';
String PTP_Msg = 'nov';
Boolean penalty = FALSE;
// --------------------------------------

if (String.isNotBlank(contratoId)) {
    Contract contrato;
    try {
        contrato = [
        SELECT Id, Name, AccountId, SM_Monthly_offer__c, SM_Net_Monthly_offer__c, SM_Payment_Method__c, SM_Payment_methods__c,
        SM_Email_to_send_contract__c, GatewayId__c
        FROM Contract WHERE ContractNumber = :contratoId LIMIT 1
        ];
    } catch (QueryException e) {
        System.debug('❌ Contrato no encontrado: ' + e.getMessage());
        return;
    }
    
    if (contrato == null) {
        System.debug('❌ Contrato no encontrado.');
        return;
    }
    
    SM_Payment_Method__c pm;
    try {
        pm = [
        SELECT Id, Name, CreatedDate, SM_Active__c, SM_Third_Person__c, SM_Account__c,
        SM_Card_Token__c, SM_Credit_Card_Number__c, SM_Credit_Card_expiration_month__c, SM_Credit_Card_expiration_year__c, SM_Credit_Card_Franchise__c,
        SM_Bank__c, SM_Routing_Number__c, SM_ACH_Account_Number__c, SM_Routing_Number_Check_Digit__c, ACH_Bank_Name__c, SM_ACH_Account_Routing_Number__c
        FROM SM_Payment_Method__c 
        WHERE Id = :contrato.SM_Payment_Method__c LIMIT 1
        ];
    } catch (QueryException e) {
        System.debug('❌ Payment Method no encontrado: ' + e.getMessage());
        return;
    }
    
    if (pm == null) {
        System.debug('❌ Payment Method no encontrado.');
        return;
    }
    
    // Datos de Billing Address
    ContactPointAddress billingAddress;
    try {
        billingAddress = [
            SELECT Address, Street, State, City, Country, PostalCode
            FROM ContactPointAddress
            WHERE ParentId = :contrato.AccountId AND SM_Type__c = 'Billing Address'
            LIMIT 1
        ];
    } catch (QueryException e) {
        System.debug('❌ Billing Address No encontrado: ' + e.getMessage());
        return;
    }

    if (billingAddress == null) {
        System.debug('❌ Billing Address no encontrado.');
        return;
    }

    // Montos
    Decimal base = contrato.SM_Monthly_offer__c.setScale(2);
    Decimal penaltyValue = penalty ? 25.00 : 0.00;
    base += penaltyValue;
    
    Decimal subtotal = (base / 1.115).setScale(2);
    Decimal total = (base * 1.115).setScale(2);
    Decimal municipal = (base * 0.01).setScale(2);
    Decimal estatal = (base * 0.105).setScale(2);
    Decimal tax = municipal + estatal;
    
    System.debug('→ Decimal base      = ' + base);
    System.debug('→ Decimal subtotal  = ' + subtotal);
    System.debug('→ Decimal total     = ' + total);
    
    // Limpiar número de tarjeta
    String cardClean = pm.SM_Credit_Card_Number__c?.replaceAll(' ', '');
    
    System.debug('→ Payment Cnt Methods: ' + contrato.SM_Payment_Methods__c);
    
    // if para seleccionar order de acuerdo al refcordtype del payumetn method.. si es TC o es ACH
    if (contrato.SM_Payment_methods__c == 'Credit Card') {
        System.debug('→→ Entra a TC ORDER' + contrato.SM_Payment_Methods__c);
        
        ChargentOrders__ChargentOrder__c orderTCSub;
        try {
            orderTCSub = [
            SELECT ChargentOrders__Billing_Address__c, ChargentOrders__Billing_City__c,
            ChargentOrders__Billing_Country__c, ChargentOrders__Billing_Email__c,
            ChargentOrders__Billing_First_Name__c, ChargentOrders__Billing_Last_Name__c,
            ChargentOrders__Billing_State__c, ChargentOrders__Billing_Zip_Postal__c
            FROM ChargentOrders__ChargentOrder__c
            WHERE Contract__c = :contrato.Id AND SM_Payment_Type__c = 'Subscription'
            LIMIT 1
            ];
        } catch (QueryException e) {
            System.debug('❌ Subscription TC Order no encontrado: ' + e.getMessage());
            return;
        }
        
        if (orderTCSub == null) {
            System.debug('❌ Subscription TC Order no encontrado.');
            return;
        }
        
        // Crear orden LPF TC
        ChargentOrders__ChargentOrder__c newLPFTC = new ChargentOrders__ChargentOrder__c(
        Contract__c = contrato.Id,
        SM_PTP_Montly__c = PTP_Msg,
        ChargentOrders__Account__c = contrato.AccountId,
        SM_Payment_Type__c = 'Late payment fee',
        ChargentOrders__Payment_Method__c = 'Credit Card',
        SM_Purpose_of_Payment__c = 'Contract fee',
        SM_Fee_to_collect__c = 1,
        ChargentOrders__Payment_Frequency__c = 'Once',
        ChargentOrders__Payment_Status__c = 'Recurring',
        ChargentOrders__Payment_Stop__c = 'Count',
        ChargentOrders__Payment_Count__c = 1,
        SM_IsApplyingDaysCollectedPenalty__c = true,
        SM_Apply_Penalty__c = penalty,
        SM_Penalty_Value__c = penaltyValue,
        ChargentOrders__Subtotal__c = base,
        SM_P_IVU_Municipal_Amount__c = 1,
        SM_P_IVU_State_Amount__c = 10.5,
        ChargentOrders__Tax__c = tax,
        ChargentOrders__Charge_Amount__c = total,
        ChargentOrders__Payment_Start_Date__c = fechaCobro,
        ChargentOrders__Payment_End_Date__c = fechaCobro,
        ChargentOrders__Next_Transaction_Date__c = fechaCobro,
        ChargentOrders__Card_Last_4__c = cardClean?.left(4),
        ChargentOrders__Card_Number__c = cardClean,
        ChargentOrders__Card_Expiration_Month__c = pm.SM_Credit_Card_expiration_month__c,
        ChargentOrders__Card_Expiration_Year__c = pm.SM_Credit_Card_expiration_year__c,
        ChargentOrders__Card_Type__c = pm.SM_Credit_Card_Franchise__c,
        ChargentOrders__Gateway__c = contrato.GatewayId__c,
        SM_Migrated__c = false,
        SM_Id_Salesforce_LCS__c = 'Manual_lpf_' + Date.today().format(),
        
        ChargentOrders__Billing_First_Name__c = contrato?.Account.FirstName,
        ChargentOrders__Billing_Last_Name__c = contrato?.Account.LastName,
        ChargentOrders__Billing_Email__c = contrato?.SM_Email_to_send_contract__c,

        ChargentOrders__Billing_Address__c = billingAddress?.Street,
        ChargentOrders__Billing_City__c = billingAddress?.City,
        ChargentOrders__Billing_State__c = billingAddress?.State,
        ChargentOrders__Billing_Zip_Postal__c = billingAddress?.PostalCode,
        ChargentOrders__Billing_Country__c = (billingAddress?.State == 'Puerto Rico' ? 'PR' : billingAddress?.Country),

        ChargentOrders__Tokenization__c = pm.SM_Card_Token__c,
        SM_IsRegisterToken__c = false
        );
        
        try {
            insert newLPFTC;
            System.debug('✅ LPF TC Order creado: ' + newLPFTC.Id);
        } catch (Exception e) {
            System.debug('❌ Error al crear el Order TC: ' + e.getMessage());
        }
    } else if (contrato.SM_Payment_methods__c == 'ACH') {
        System.debug('→→ Entra a ACH ORDER' + contrato.SM_Payment_Methods__c);
        SM_ACH_Order__c orderACHSub;
        try {
            orderACHSub = [
            SELECT Id, SM_Contract__c, SM_Billing_Email__c, SM_Payment_Type__c, SM_Payment_Frequency__c, SM_Payment_Status__c, SM_Payment_Count__c,
            SM_Fee_to_collect__c, SM_Payment_Condition__c, SM_Total__c, IVU_State_Amount__c, SM_IVU_Municipal_Amount__c, SM_Payment_Start_Date__c,
            SM_Payment_End_Date__c, SM_Next_Transaction_Date__c, SM_Apply_penalty__c, SM_Penalty_value__c, SM_Payment_Method__c,
            SM_Id_Salesforce_LCS__c, CreatedDate, SM_Bank__c
            FROM SM_ACH_Order__c
            WHERE SM_Contract__c = :contrato.Id AND SM_Payment_Type__c = 'Subscription'
            LIMIT 1
            ];
        } catch (QueryException e) {
            System.debug('❌ Subscription ACH Order no encontrado: ' + e.getMessage());
            return;
        }
        
        if (orderACHSub == null) {
            System.debug('❌ Subscription ACH Order no encontrado.');
            return;
        }
        
        // Crear orden LPF ACH
        SM_ACH_Order__c newLPFACH = new SM_ACH_Order__c(
        SM_Contract__c = contrato.Id,
        SM_Payment_Type__c = 'Late Payment fee',
        SM_Payment_Frequency__c = 'Once',
        SM_Payment_Status__c = 'Pending',
        SM_Payment_Condition__c = 'Fixed value',
        SM_Billing_Email__c = contrato.SM_Email_to_send_contract__c,
        SM_Payment_Count__c = 1,
        SM_Fee_to_collect__c = 1,
        SM_Apply_Penalty__c = penalty,
        SM_Penalty_Value__c = penaltyValue,
        SM_Payment_Start_Date__c = fechaCobro,
        SM_Payment_End_Date__c = fechaCobro,
        SM_Next_Transaction_Date__c = fechaCobro,
        SM_Payment_Method__c = contrato.SM_Payment_Method__c,
        SM_Total__c = base
        );
        
        try {
            insert newLPFACH;
            System.debug('✅ LPF ACH Order creado: ' + newLPFACH.Id);
        } catch (Exception e) {
            System.debug('❌ Error al crear el Order ACH: ' + e.getMessage());
        }
    } else {
        System.debug('❌ Tipo de pago no soportado.');
    }
    
} else {
    System.debug('❌ No se proporcionó una ID válida de contrato.');
}