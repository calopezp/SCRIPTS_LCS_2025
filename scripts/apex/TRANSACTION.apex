// CREAR TRANSACTION

STRING GatewayId = '7785353228636255903283';
DATETIME GatewayDate = DateTime.valueOf('2026-05-11 23:35:22');
STRING OrderId = 'a1EUU000001wmZx2AI';
INTEGER ReasonCode = 204;
STRING AuthorizationCode = '';
STRING TokenValue = '407F536C339F2F5EE0631D588D0A015F';
Decimal AmountValue = 79.00;

STRING ReasonText = '';
STRING ResponseDetail = '';
STRING ResponseStatus = '';
STRING ResponseMessage = '';

list <ChargentOrders__Transaction__c> transactionsToUpdate = [
    SELECT Id, Name, ChargentOrders__Authorization__c, ChargentOrders__Gateway_Date__c, ChargentOrders__Reason_Code__c,
            ChargentOrders__Order__r.Name   
    FROM ChargentOrders__Transaction__c
    WHERE ChargentOrders__Gateway_ID__c = :GatewayId
    Limit 1
];

list <ChargentOrders__ChargentOrder__c> ordersConsult = [
    SELECT Id, Name,
            ChargentOrders__Credit_Card_Name__c, ChargentOrders__Card_Last_4__c, ChargentOrders__Charge_Amount__c, ChargentOrders__Currency__c,
            ChargentOrders__Billing_Address__c, ChargentOrders__Billing_City__c, ChargentOrders__Billing_State__c, ChargentOrders__Billing_Zip_Postal__c, ChargentOrders__Billing_Country__c,
            ChargentOrders__Billing_First_Name__c, ChargentOrders__Billing_Last_Name__c, ChargentOrders__Billing_Email__c, ChargentOrders__Card_Type__c
    FROM ChargentOrders__ChargentOrder__c
    WHERE Id = :OrderId
    Limit 1
];

    Boolean shouldCreateTransaction = true;

    if (!transactionsToUpdate.isEmpty()) {
        System.debug(' → Transaction Exists: ' + transactionsToUpdate[0].Name + ' ▫️ ' + transactionsToUpdate[0].ChargentOrders__Order__r.Name);
        shouldCreateTransaction = false;
    } else {
        System.debug(' → Crear Nuevo');
    }

    if (shouldCreateTransaction) {
        if(!ordersConsult.isEmpty()){
            System.debug(' → Order Encontrada: ' + ordersConsult[0].Name
            + ' ▫️ ' + ordersConsult[0].ChargentOrders__Billing_First_Name__c + ' ' + ordersConsult[0].ChargentOrders__Billing_Last_Name__c
            + ' ▫️ ' + ordersConsult[0].ChargentOrders__Billing_Email__c + ' ▫️ ' + ordersConsult[0].ChargentOrders__Billing_Address__c + ' ' + ordersConsult[0].ChargentOrders__Billing_City__c + ' ' + ordersConsult[0].ChargentOrders__Billing_State__c + ' ' + ordersConsult[0].ChargentOrders__Billing_Zip_Postal__c + ' ' + ordersConsult[0].ChargentOrders__Billing_Country__c 
            + ' ▫️ ' + ordersConsult[0].ChargentOrders__Card_Type__c + ' ▫️ ' + ordersConsult[0].ChargentOrders__Card_Last_4__c + ' ▫️ ' + ordersConsult[0].ChargentOrders__Charge_Amount__c + ' ' + ordersConsult[0].ChargentOrders__Currency__c
            );
        } else {
            System.debug(' → Order No Encontrada');
            shouldCreateTransaction = false;
        }
    }

    if (shouldCreateTransaction) {
    // Asignar valores según el Reason Code ANTES de crear el objeto
        switch on ReasonCode {
            when 100 {
                ResponseDetail = 'Transaction was successful.';
            }
            when 101 {
                ResponseDetail = 'Request is missing one or more required fields.';
            }
            when 102 {
                ResponseDetail = 'One or more fields in the request contain invalid data.';
            }
            when 104 {
                ResponseDetail = 'Merchant reference code for this authorization request matches the merchant reference code for another authorization request that you sent within the past 15 minutes.';
            }
            when 105 {
                ResponseDetail = 'Merchant transaction identifier (MTI) sent with this request has already been used in the past 60 days.';
            }
            when 110 {
                ResponseDetail = 'Only a partial amount was approved.';
            }
            when 150 {
                ResponseDetail = 'System error.';
            }
            when 151 {
                ResponseDetail = 'Request was received but a server timeout occurred.';
            }
            when 152 {
                ResponseDetail = 'Request was received but a service did not finish running in time.';
            }
            when 153 {
                ResponseDetail = 'Your account is not enabled for the OCT service. Contact customer support to have your account enabled for this service.';
            }
            when 200 {
                ResponseDetail = 'Authorization request was approved by the issuing bank but declined because the address verification system (AVS) could not verify it.';
            }
            when 201 {
                ResponseDetail = 'Issuing bank has questions. Authorization:  You cannot receive an authorization code programmatically but you might receive one verbally by calling the processor.';
            }
            when 202 {
                ResponseDetail = 'Card is expired. You might also receive this value if the expiration date that you provided does not match the date that the issuing bank has on file.';
            }
            when 203 {
                ResponseDetail = 'Card was declined. No other information was provided by the issuing bank.';
            }
            when 204 {
                ResponseDetail = 'Account does not contain sufficient funds.';
            }
            when 205 {
                ResponseDetail = 'Card is lost or stolen. Review this transaction manually to ensure that you submitted the correct information.';
            }
            when 207 {
                ResponseDetail = 'Issuing bank is unavailable. Wait a few minutes and resend the request.';
            }
            when 208 {
                ResponseDetail = 'Card-Not-Present Transaction:  Card is inactive or not authorized for card-not-present transactions.';
            }
            when 209 {
                ResponseDetail = 'CVN did not match. Request a different card or other form of payment.';
            }
            when 210 {
                ResponseDetail = 'Account reached the credit limit or the transaction amount exceeds the approved limit.';
            }
            when 211 {
                ResponseDetail = 'CVN is invalid. Re-enter the CVN or request a different form of payment.';
            }
            when 212 {
                ResponseDetail = 'EMV transaction was rejected. Resubmit the request with chip and PIN.';
            }
            when 213 {
                ResponseDetail = 'Account is in fraud watch status.';
            }
            when 221 {
                ResponseDetail = '';
            }
            when 230 {
                ResponseDetail = 'Authorization request was approved by the issuing bank but declined because CVN could not be verified.';
            }
            when 231 {
                ResponseDetail = 'Account number is invalid.';
            }
            when 232 {
                ResponseDetail = 'Payment processor does not accept the card type.';
            }
            when 233 {
                ResponseDetail = 'Processor declined the card.';
            }
            when 234 {
                ResponseDetail = 'Information in your account is incorrect. Do not resend the request.';
            }
            when 235 {
                ResponseDetail = 'Capture:  The requested capture amount exceeds the authorized amount. PIN Debit Purchase:  Transaction amount exceeds the approved limit.';
            }
            when 236 {
                ResponseDetail = 'Processor failed. Wait a few minutes and resend the request.';
            }
            when 237 {
                ResponseDetail = 'Transaction was already captured.';
            }
            when 238 {
                ResponseDetail = 'Transaction was already reversed.';
            }
            when 239 {
                ResponseDetail = 'Requested transaction amount does not match the previous transaction amount.';
            }
            when 240 {
                ResponseDetail = 'Card type is invalid or does not correlate with the payment card number.';
            }
            when 241 {
                ResponseDetail = 'PIN Debit: Processor declined the card. Other Payment Method:  Request ID is invalid.';
            }
            when 242 {
                ResponseDetail = 'You requested a capture but there is no corresponding unused authorization.';
            }
            when 243 {
                ResponseDetail = 'Transaction is already settled or reversed.';
            }
            when 244 {
                ResponseDetail = 'Account number did not pass a verification check.';
            }
            when 246 {
                ResponseDetail = 'Capture or credit cannot be voided because the capture or credit information has already been submitted to your processor. You requested a void for a type of transaction that cannot be voided.';
            }
            when 247 {
                ResponseDetail = 'You requested a credit for a capture that was previously voided.';
            }
            when 250 {
                ResponseDetail = 'Request was received but a timeout occurred at the payment processor.';
            }
            when 251 {
                ResponseDetail = 'Customer has exceeded the debit card\'s limit on frequency of use number of PIN entry tries or maximum amount for the day.';
            }
            when 254 {
                ResponseDetail = 'Stand-alone credits are not allowed.';
            }
            when 256 {
                ResponseDetail = 'Credit amount exceeds the maximum allowed for your account.';
            }
            when 257 {
                ResponseDetail = 'Gift card account or prepaid card account is already active.';
            }
            when 259 {
                ResponseDetail = 'Reload limit for the gift card or prepaid card was exceeded.';
            }
            when 260 {
                ResponseDetail = 'Requested amount conflicts with the minimum or maximum amount allowed on the gift card or prepaid card.';
            }
            when 262 {
                ResponseDetail = 'Request is still in progress. Wait for a response from Cybersource.';
            }
            when 263 {
                ResponseDetail = 'Mass transit transaction (MTT) was declined.';
            }
            when 428 {
                ResponseDetail = 'Your request for a strong customer authentication (SCA) exemption was declined.';
            }
            when 478 {
                ResponseDetail = 'Strong customer authentication (SCA) is required for this transaction.';
            }
            when 490 {
                ResponseDetail = 'Your aggregator or acquirer is not accepting transactions from you at this time.';
            }
            when 491 {
                ResponseDetail = 'Your aggregator or acquirer did not accept this transaction.';
            }
            when 520 {
                ResponseDetail = 'Authorization request was approved by the issuing bank but declined based on your Smart Authorization settings.';
            }
            when else {
                ResponseDetail = '';
            }
        }
    
        if (ReasonCode == 100) {
            ResponseStatus = 'Approved';
            ResponseMessage = 'ACCEPT';
            ReasonText = 'ACCEPT';
        } else {
            ResponseStatus = 'Error';
            ResponseMessage = 'REJECT';
            ReasonText = 'REJECT';
        }

        // Crear el objeto Transaction con la sintaxis correcta (comas, no signos de igual)
        ChargentOrders__Transaction__c newTransaction = new ChargentOrders__Transaction__c(
            ChargentOrders__Type__c = 'Charge',
            ChargentOrders__Gateway_Date__c = GatewayDate,
            ChargentOrders__Response_Status__c = ResponseStatus,
            ChargentOrders__Gateway_ID__c = GatewayId,
            ChargentOrders__Response_Message__c = ResponseMessage,
            ChargentOrders__Order__c = OrderId,
            ChargentOrders__Gateway__c = 'a1A1U000003TQL5UAO',   // Cybersource Live
            
            ChargentOrders__Recurring__c = true,
            ChargentOrders__AVS_International__c = 'Y',

            ChargentOrders__Authorization__c = AuthorizationCode,
            ChargentOrders__Reason_Code__c = ReasonCode,
            SM_ResponseDetail__c = ResponseDetail,
            ChargentOrders__Reason_Text__c = ReasonText,

            ChargentOrders__Credit_Card_Name__c = ordersConsult[0].ChargentOrders__Credit_Card_Name__c,
            ChargentOrders__Card_Last_4__c = ordersConsult[0].ChargentOrders__Card_Last_4__c,
            ChargentOrders__Amount__c = ordersConsult[0].ChargentOrders__Charge_Amount__c,
            ChargentOrders__Tokenization__c = TokenValue,
            ChargentOrders__Payment_Method__c = 'Credit Card',
            ChargentOrders__Credit_Card_Type__c = ordersConsult[0].ChargentOrders__Card_Type__c,
            ChargentOrders__Currency__c = 'United States dollar',

            ChargentOrders__Billing_Address__c = ordersConsult[0].ChargentOrders__Billing_Address__c,
            ChargentOrders__Billing_City__c = ordersConsult[0].ChargentOrders__Billing_City__c,
            ChargentOrders__Billing_State__c = ordersConsult[0].ChargentOrders__Billing_State__c,
            ChargentOrders__Billing_Postal_Code__c = ordersConsult[0].ChargentOrders__Billing_Zip_Postal__c,
            ChargentOrders__Billing_Country__c = ordersConsult[0].ChargentOrders__Billing_Country__c,

            ChargentOrders__Billing_First__c = ordersConsult[0].ChargentOrders__Billing_First_Name__c,
            ChargentOrders__Billing_Last__c = ordersConsult[0].ChargentOrders__Billing_Last_Name__c,
            ChargentOrders__Billing_Email__c = ordersConsult[0].ChargentOrders__Billing_Email__c,

            ChargentOrders__Gateway_Response__c = 'MANUAL PANTALLA NARANJA'
        );
    
        // Insertar la transacción
        insert newTransaction;
    
        System.debug(' → Nueva Transacción Creada: ' + newTransaction.Id
            + ' ▫️ Reason Code: ' + newTransaction.ChargentOrders__Reason_Code__c
            + ' ▫️ Status: ' + newTransaction.ChargentOrders__Response_Status__c
            + ' ▫️ Authorization: ' + newTransaction.ChargentOrders__Authorization__c
            + ' ▫️ Gateway Date: ' + newTransaction.ChargentOrders__Gateway_Date__c
            + ' ▫️ Gateway ID: ' + newTransaction.ChargentOrders__Gateway_ID__c
            + ' ▫️ Message: ' + newTransaction.ChargentOrders__Response_Message__c
            + ' ▫️ Recurring: ' + newTransaction.ChargentOrders__Recurring__c
            + ' ▫️ AVS: ' + newTransaction.ChargentOrders__AVS_International__c
            + ' ▫️ Token: ' + newTransaction.ChargentOrders__Tokenization__c
            + ' ▫️ Payment Method: ' + newTransaction.ChargentOrders__Payment_Method__c
        );

        // Modificamos las fechas del Payment asociado
        list <SM_Payment__c> paymentsToUpdate = [
            SELECT Id, Name, SM_Payment_Due_Date__c, SM_Payment_Date__c, SM_Payment_execution_date__c, SM_Is_Migrated__c
            FROM SM_Payment__c
            WHERE SM_Chargent_Orders_Transaction__c = :newTransaction.Id
        ];

        if (!paymentsToUpdate.isEmpty()) {
            for (SM_Payment__c payment : paymentsToUpdate) {
                payment.SM_Payment_Due_Date__c = GatewayDate.date();
                payment.SM_Payment_Date__c = GatewayDate.date();
                payment.SM_Is_Migrated__c = true;
            }
            update paymentsToUpdate;
            System.debug(' → Fechas de Payment Actualizadas: ' + paymentsToUpdate.size());
        } else {
            System.debug(' → No se encontraron Payments asociados para actualizar las fechas.');
        }
    }