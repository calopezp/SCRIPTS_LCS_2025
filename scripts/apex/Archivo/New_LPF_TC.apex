// CREAR LPF TC + PARÁMETROS
//
// ------------- CONFIGURAR -------------  :)
String contratoId = '00314875';
Date fechaCobro = Date.newInstance(2025, 09, 30);
String ordType = 'Late Payment fee'; //'Subscription'; // 
String PTP_Msg = 'jul';
Boolean penalty = TRUE;
// --------------------------------------

if (String.isNotBlank(contratoId)) {
    Contract contrato;
    try {
        contrato = [
            SELECT Id, AccountId, SM_Monthly_offer__c, SM_Net_Monthly_offer__c, 
            SM_Payment_Method__c, GatewayId__c, SM_Email_to_send_contract__c, 
            Account.FirstName, Account.LastName
            FROM Contract WHERE ContractNumber = : contratoId LIMIT 1
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
            SELECT SM_Credit_Card_Number__c, SM_Credit_Card_expiration_month__c,
                   SM_Credit_Card_expiration_year__c, SM_Credit_Card_Franchise__c,
                   SM_Card_Token__c
            FROM SM_Payment_Method__c WHERE Id = :contrato.SM_Payment_Method__c LIMIT 1
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
    Decimal base = contrato.SM_Monthly_offer__c.setScale(2);   // valor sin impuesto

    // Aplicar penalización si es necesario
    penalty = (ordType == 'Subscription' ? FALSE : penalty);
    Decimal penaltyValue = penalty ? 25.00 : 0.00;
    base += penaltyValue;

    Decimal subtotal = (base).setScale(2);   // (base / 1.115).setScale(2);
    Decimal total = (base * 1.115).setScale(2);
    Decimal municipal = (base * 0.01).setScale(2);
    Decimal estatal = (base * 0.105).setScale(2);
    Decimal tax = municipal + estatal;

    System.debug('→ Decimal base      = ' + base);
    System.debug('→ Decimal subtotal  = ' + subtotal);
    System.debug('→ Decimal total     = ' + total);

    // Limpiar número de tarjeta
    String cardClean = pm.SM_Credit_Card_Number__c?.replaceAll(' ', '');

    // Crear orden
    ChargentOrders__ChargentOrder__c newLPFTC = new ChargentOrders__ChargentOrder__c(
        Contract__c = contrato.Id,
        ChargentOrders__Account__c = contrato.AccountId,
        SM_Payment_Type__c = ordType,
        ChargentOrders__Payment_Frequency__c = (ordType == 'Subscription' ? 'Monthly' : 'Once'),
        ChargentOrders__Payment_Stop__c = (ordType == 'Subscription' ? 'Unending' : 'Count'),
        SM_Apply_Penalty__c = (ordType == 'Subscription' ? FALSE : penalty),
        SM_Penalty_Value__c = (ordType == 'Subscription' ? NULL : penaltyValue),
        SM_PTP_Montly__c = (ordType == 'Subscription' ? NULL : PTP_Msg),
        ChargentOrders__Payment_Method__c = 'CreditCard',
        SM_Purpose_of_Payment__c = 'Contract fee',
        SM_Fee_to_collect__c = 1,
        ChargentOrders__Payment_Status__c = 'Recurring',
        ChargentOrders__Payment_Count__c = 1,
        SM_IsApplyingDaysCollectedPenalty__c = true,
        
        ChargentOrders__Subtotal__c = subtotal,
        SM_P_IVU_Municipal_Amount__c = municipal,
        SM_P_IVU_State_Amount__c = estatal,
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
        System.debug('❌ Error al crear el pedido: ' + e.getMessage());
    }
} else {
    System.debug('❌ No se proporcionó una ID válida de contrato.');
}