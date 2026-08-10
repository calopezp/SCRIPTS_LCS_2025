// crear payment REFUNDED por contracargo a partir de una autorización, y crear LPF si no existe para ese contrato/mes

String AutorizacionCode = '811718';

// -----------------------------
// 0) Buscar Payment REFUNDED por SM_Transaction_Id__c
// -----------------------------
SM_Payment__c refundedPayment = null;
try {
    refundedPayment = [
        SELECT Id, Name, SM_Contract__c, SM_Amount__c, Payment_Status__c,
               SM_Chargent_Orders_Transaction__c, SM_Payment_execution_date__c, SM_Transaction_Id__c,
               SM_Chargent_Orders_Transaction__r.ChargentOrders__Order__c,
               SM_Chargent_Orders_Transaction__r.ChargentOrders__Card_Last_4__c
        FROM SM_Payment__c
        WHERE SM_Transaction_Id__c = :AutorizacionCode
          AND Payment_Status__c = 'REFUNDED'
        LIMIT 1
    ];
} catch (Exception e) {
    refundedPayment = null;
}

if (refundedPayment != null) {
    System.debug('→ PAYMENT REFUNDED EXISTENTE: Id=' + refundedPayment.Id + '▫️ Name=' + refundedPayment.Name + '▫️ Amount=' + refundedPayment.SM_Amount__c + '▫️ Contract=' + refundedPayment.SM_Contract__c + '▫️ TxRef=' + refundedPayment.SM_Chargent_Orders_Transaction__c);
} else {
    System.debug('→ NO existe Payment REFUNDED con SM_Transaction_Id__c = ' + AutorizacionCode);
}

// -----------------------------
// 1) Buscar Chargent Transaction por autorización
// -----------------------------
ChargentOrders__Transaction__c txn = null;
try {
    txn = [
        SELECT Id, Name, ChargentOrders__Authorization__c, ChargentOrders__Order__c, ChargentOrders__Card_Last_4__c, Contract__r.ContractNumber
        FROM ChargentOrders__Transaction__c
        WHERE ChargentOrders__Authorization__c = :AutorizacionCode
    ];
} catch (Exception e) {
    txn = null;
}
if (txn.size() > 1) {
    System.debug('→ ALERTA: Se encontraron múltiples Transactions con la misma autorización. NO SE PROCESA. AutorizacionCode=' + AutorizacionCode);
    Continue;
}

if (txn != null) {
    System.debug('→ TRANSACTION EXISTENTE: Id=' + txn.Id + '▫️ Auth=' + txn.ChargentOrders__Authorization__c + '▫️ OrderRef=' + txn.ChargentOrders__Order__c + '▫️ CardLast4=' + txn.ChargentOrders__Card_Last_4__c + '▫️ Contract=' + txn.Contracts__r.ContractNumber);
} else {
    System.debug('→ NO existe Chargent Transaction con ChargentOrders__Authorization__c = ' + AutorizacionCode);
}

// -----------------------------
// 2) Obtener payment original (si no tenemos refundedPayment)
//    - Buscamos el payment original vinculado a la Transaction con esa autorización
// -----------------------------
SM_Payment__c originalPayment = null;
if (refundedPayment == null) {
    try {
        List<SM_Payment__c> po = [
            SELECT Id, Name, SM_Contract__c, SM_Amount__c, SM_Payment_execution_date__c,
                   SM_Chargent_Orders_Transaction__r.ChargentOrders__Card_Last_4__c,
                   SM_Chargent_Orders_Transaction__r.ChargentOrders__Order__c,
                   RecordTypeId, SM_Type__c, SM_Original_Type__c, SM_Penalty_value__c, SM_Fee_value__c
            FROM SM_Payment__c
            WHERE SM_Chargent_Orders_Transaction__c IN (
                SELECT Id FROM ChargentOrders__Transaction__c
                WHERE ChargentOrders__Authorization__c = :AutorizacionCode
            )
            LIMIT 1
        ];
        if (!po.isEmpty()) originalPayment = po[0];
    } catch (Exception e) {
        originalPayment = null;
    }

    if (originalPayment != null) {
        System.debug('→ PAYMENT ORIGINAL encontrado: Id=' + originalPayment.Id + '▫️ Name=' + originalPayment.Name + '▫️ Amount=' + originalPayment.SM_Amount__c + '▫️ Contract=' + originalPayment.SM_Contract__c);
    } else {
        System.debug('→ NO se encontró Payment original vinculado a la autorización. No se puede crear Payment REFUNDED automáticamente.');
    }
} else {
    originalPayment = refundedPayment; // si ya existe el refunded, lo usamos como base (aunque normalmente base sería el original)
}

// Si no hay originalPayment y no hay refundedPayment, abortamos
if (originalPayment == null && refundedPayment == null) {
    System.debug('→ ERROR: No hay Payment original ni Payment REFUNDED para usar como base. Proceso detenido.');
    return;
}

// -----------------------------
// 3) Si no existe el Payment REFUNDED, crearlo
// -----------------------------
SM_Payment__c paymentToUse = refundedPayment;
if (refundedPayment == null) {
    // Crear Payment REFUNDED (contracargo) basado en originalPayment
    SM_Payment__c newPayment = new SM_Payment__c();
    // Asignaciones basadas en campos que nos diste
    newPayment.RecordTypeId = originalPayment.RecordTypeId;
    newPayment.Payment_Status__c = 'REFUNDED';
    newPayment.SM_Reason_for_refund__c = 'CONTRA CARGO';
    newPayment.SM_Contract__c = originalPayment.SM_Contract__c;
    newPayment.SM_Amount__c = (originalPayment.SM_Amount__c != null) ? originalPayment.SM_Amount__c * -1 : null;
    newPayment.SM_Payments_refunded__c = originalPayment.Id;
    newPayment.SM_Type__c = originalPayment.SM_Type__c;
    newPayment.SM_Original_Type__c = originalPayment.SM_Original_Type__c;
    newPayment.SM_Penalty_value__c = (originalPayment.SM_Penalty_value__c != null) ? originalPayment.SM_Penalty_value__c * -1 : null;
    newPayment.SM_Fee_value__c = (originalPayment.SM_Fee_value__c != null) ? originalPayment.SM_Fee_value__c * -1 : null;
    // SM_Payment_execution_date__c es Datetime en tu org; asignamos Date fields con .date()
    if (originalPayment.SM_Payment_execution_date__c != null) {
        newPayment.SM_Payment_Due_Date__c = originalPayment.SM_Payment_execution_date__c.date();
        newPayment.SM_Payment_Date__c = originalPayment.SM_Payment_execution_date__c.date();
    }
    newPayment.SM_Is_Migrated__c = true;
    newPayment.SM_Transaction_Id__c = AutorizacionCode;

    try {
        insert newPayment;
        paymentToUse = [
            SELECT Id, Name, SM_Contract__c, SM_Amount__c, SM_Payment_execution_date__c, SM_Chargent_Orders_Transaction__c
            FROM SM_Payment__c
            WHERE Id = :newPayment.Id
            LIMIT 1
        ];
        System.debug('→ NUEVO PAYMENT REFUNDED creado: Id=' + paymentToUse.Id + '▫️ Name=' + paymentToUse.Name + '▫️ Amount=' + paymentToUse.SM_Amount__c + '▫️ Contract=' + paymentToUse.SM_Contract__c);
    } catch (Exception e) {
        System.debug('→ ERROR creando Payment REFUNDED: ' + e.getMessage());
        return;
    }
} else {
    System.debug('→ Usando Payment REFUNDED existente: Id=' + paymentToUse.Id + '▫️ Name=' + paymentToUse.Name);
}

// -----------------------------
// 4) Determinar mes del cobro original (SM_PTP_Montly__c) a partir de la fecha de ejecución del pago original
// -----------------------------
Datetime execDt = null;
if (originalPayment != null && originalPayment.SM_Payment_execution_date__c != null) {
    execDt = originalPayment.SM_Payment_execution_date__c;
} else if (paymentToUse != null && paymentToUse.SM_Payment_execution_date__c != null) {
    execDt = paymentToUse.SM_Payment_execution_date__c;
}

String monthStr = null;
if (execDt != null) {
    Integer monthInt = execDt.date().month(); // 1..12
    List<String> monthNames = new List<String>{'ENE','FEB','MAR','ABR','MAY','JUN','JUL','AGO','SEP','OCT','NOV','DIC'};
    if (monthInt >= 1 && monthInt <= 12) monthStr = monthNames[monthInt - 1];
}
System.debug('→ Mes determinado para SM_PTP_Montly__c = ' + monthStr);

// -----------------------------
// 5) Buscar si existe Chargent Order tipo "Late Payment fee" para el mismo contrato y mismo mes
// -----------------------------
ChargentOrders__ChargentOrder__c existingLPF = null;
Id contractId = paymentToUse.SM_Contract__c;
if (contractId != null) {
    try {
        existingLPF = [
            SELECT Id, Name, ChargentOrders__Charge_Amount__c, SM_PTP_Montly__c, SM_Payment_Type__c
            FROM ChargentOrders__ChargentOrder__c
            WHERE Contract__c = :contractId
              AND SM_Payment_Type__c = 'Late Payment fee'
              AND SM_PTP_Montly__c = 'CONTRA CARGO'
            LIMIT 1
        ];
    } catch (Exception e) {
        existingLPF = null;
    }
}

if (existingLPF != null) {
    System.debug('→ EXISTE Late Payment Fee para este contrato y mes: Id=' + existingLPF.Id + '▫️ Name=' + existingLPF.Name + '▫️ Amount=' + existingLPF.ChargentOrders__Charge_Amount__c + '▫️ Mes=' + existingLPF.SM_PTP_Montly__c);
} else {
    System.debug('→ NO existe Late Payment Fee para este contrato y mes (ContractId=' + contractId + '▫️ Mes=' + monthStr + '). Se procederá a crear uno.');
}

// -----------------------------
// 6) Si no existe LPF, crear Chargent Order, luego Transaction y vincular Payment -> Transaction
// -----------------------------
ChargentOrders__ChargentOrder__c orderCreated = null;
ChargentOrders__Transaction__c txnCreated = null;

if (existingLPF == null) {
    // Recuperar Contract para datos de facturación
    Contract cont = null;
    try {
        cont = [
            SELECT Id, Status, AccountId, SM_Payment_Method__c, SM_Email_to_send_contract__c,
                   Account.FirstName, Account.LastName, GatewayId__c, Account.BillingCountry
            FROM Contract
            WHERE Id = :contractId
            LIMIT 1
        ];
    } catch (Exception e) {
        cont = null;
    }

    if (cont == null) {
        System.debug('→ ERROR: No se pudo recuperar el Contract (Id=' + contractId + '). No se puede crear Chargent Order.');
        return;
    }

    if (cont.Status != 'Activated') {
        System.debug('→ ALERTA: Contract no está Activated (Status=' + cont.Status + '). No se creará automáticamente el Chargent Order. Crear manualmente si procede.');
        return;
    }

    // Preparar valores
    String last4 = (originalPayment != null && originalPayment.SM_Chargent_Orders_Transaction__r != null) ? originalPayment.SM_Chargent_Orders_Transaction__r.ChargentOrders__Card_Last_4__c : null;
    String cardNumber = String.isBlank(last4) ? '' : last4.replaceAll('\\s+','');

    // Construir SM_Id_Salesforce_LCS__c con el nombre del Payment creado/seleccionado
    String paymentNameForLCS = (paymentToUse != null && !String.isBlank(paymentToUse.Name)) ? paymentToUse.Name : '';
    String lcsValue = 'CONTRACARGO ' + AutorizacionCode + ' ' + paymentNameForLCS;

    // Crear Chargent Order
    ChargentOrders__ChargentOrder__c newOrder = new ChargentOrders__ChargentOrder__c();
    newOrder.Contract__c = cont.Id;
    newOrder.ChargentOrders__Account__c = cont.AccountId;
    newOrder.SM_PTP_Montly__c = 'CONTRA CARGO';
    newOrder.SM_Payment_Type__c = 'Late Payment fee';
    newOrder.ChargentOrders__Payment_Method__c = 'Credit Card';
    newOrder.SM_Purpose_of_Payment__c = 'Contract fee';
    newOrder.SM_Fee_to_collect__c = 1;
    newOrder.ChargentOrders__Payment_Frequency__c = 'Once';
    newOrder.ChargentOrders__Payment_Status__c = 'Recurring';
    newOrder.ChargentOrders__Payment_Stop__c = 'Count';
    newOrder.ChargentOrders__Payment_Count__c = 1;
    newOrder.SM_IsApplyingDaysCollectedPenalty__c = true;
    newOrder.SM_Apply_Penalty__c = true;
    newOrder.SM_Penalty_Value__c = 25;
    newOrder.ChargentOrders__Subtotal__c = (originalPayment != null && originalPayment.SM_Amount__c != null) ? (originalPayment.SM_Amount__c * -1).abs() : null;
    newOrder.ChargentOrders__Tax__c = 0;
    newOrder.ChargentOrders__Charge_Amount__c = (originalPayment != null && originalPayment.SM_Amount__c != null) ? (originalPayment.SM_Amount__c * -1).abs() : null;
    newOrder.ChargentOrders__Payment_Start_Date__c = Date.today();
    newOrder.ChargentOrders__Payment_End_Date__c = Date.today();
    newOrder.ChargentOrders__Next_Transaction_Date__c = Date.today();
    newOrder.ChargentOrders__Card_Last_4__c = last4;
    newOrder.ChargentOrders__Card_Number__c = cardNumber;
    newOrder.ChargentOrders__Gateway__c = cont.GatewayId__c;
    newOrder.SM_Migrated__c = false;
    newOrder.SM_Id_Salesforce_LCS__c = lcsValue;
    newOrder.ChargentOrders__Billing_First_Name__c = cont.Account.FirstName;
    newOrder.ChargentOrders__Billing_Last_Name__c = cont.Account.LastName;
    newOrder.ChargentOrders__Billing_Email__c = cont.SM_Email_to_send_contract__c;
    //newOrder.ChargentOrders__Billing_Country__c = cont.Account.BillingCountry;
    newOrder.ChargentOrders__Billing_Country__c    = (cont.Account.BillingCountry== 'Puerto Rico' ? 'PR' : cont.Account.BillingCountry);

    try {
        insert newOrder;
        orderCreated = [
            SELECT Id, Name, ChargentOrders__Charge_Amount__c, SM_PTP_Montly__c
            FROM ChargentOrders__ChargentOrder__c
            WHERE Id = :newOrder.Id
            LIMIT 1
        ];
        System.debug('→ NUEVO Chargent Order creado: Id=' + orderCreated.Id + '▫️ Name=' + orderCreated.Name + '▫️ Amount=' + orderCreated.ChargentOrders__Charge_Amount__c + '▫️ Mes=' + orderCreated.SM_PTP_Montly__c);
    } catch (Exception e) {
        System.debug('→ ERROR insertando Chargent Order: ' + e.getMessage());
        return;
    }

    // Crear Transaction vinculada al Order con la autorización
    ChargentOrders__Transaction__c newTxn = new ChargentOrders__Transaction__c();
    newTxn.ChargentOrders__Order__c = orderCreated.Id;
    newTxn.ChargentOrders__Authorization__c = AutorizacionCode;
    newTxn.ChargentOrders__Card_Last_4__c = last4;

    try {
        insert newTxn;
        txnCreated = [
            SELECT Id, Name, ChargentOrders__Authorization__c
            FROM ChargentOrders__Transaction__c
            WHERE Id = :newTxn.Id
            LIMIT 1
        ];
        System.debug('→ NUEVA Chargent Transaction creada: Id=' + txnCreated.Id + '▫️ Auth=' + txnCreated.ChargentOrders__Authorization__c);
    } catch (Exception e) {
        System.debug('→ ERROR insertando Chargent Transaction: ' + e.getMessage());
        return;
    }

    // Vincular el Payment (nuevo o existente) a la Transaction creada
    try {
        SM_Payment__c updP = new SM_Payment__c(Id = paymentToUse.Id, SM_Chargent_Orders_Transaction__c = txnCreated.Id);
        update updP;
        System.debug('→ Payment vinculado a Transaction nueva: PaymentId=' + paymentToUse.Id + '▫️ TxnId=' + txnCreated.Id);
    } catch (Exception e) {
        System.debug('→ ERROR vinculando Payment a Transaction: ' + e.getMessage());
    }
} else {
    // Si ya existía LPF, mostrar si hay Transaction asociada a ese Order
    System.debug('→ No se creó nuevo LPF porque ya existe uno para este contrato/mes.');
    // Intentar encontrar Transaction asociada al existingLPF (si existe)
    if (existingLPF != null) {
        ChargentOrders__Transaction__c txnForLPF = null;
        try {
            txnForLPF = [
                SELECT Id, Name, ChargentOrders__Order__c, ChargentOrders__Authorization__c
                FROM ChargentOrders__Transaction__c
                WHERE ChargentOrders__Order__c = :existingLPF.Id
                LIMIT 1
            ];
        } catch (Exception e) {
            txnForLPF = null;
        }
        if (txnForLPF != null) {
            System.debug('→ Transaction asociada al LPF existente: TxnId=' + txnForLPF.Id + '▫️ Auth=' + txnForLPF.ChargentOrders__Authorization__c);
            // Vincular payment si no está vinculado
            if (paymentToUse.SM_Chargent_Orders_Transaction__c == null) {
                try {
                    SM_Payment__c updP2 = new SM_Payment__c(Id = paymentToUse.Id, SM_Chargent_Orders_Transaction__c = txnForLPF.Id);
                    update updP2;
                    System.debug('→ Payment vinculado a Transaction del LPF existente: PaymentId=' + paymentToUse.Id + '▫️ TxnId=' + txnForLPF.Id);
                } catch (Exception e) {
                    System.debug('→ ERROR vinculando Payment al Transaction del LPF existente: ' + e.getMessage());
                }
            } else {
                System.debug('→ Payment ya estaba vinculado a Transaction: ' + paymentToUse.SM_Chargent_Orders_Transaction__c);
            }
        } else {
            System.debug('→ ALERTA: Existe LPF pero NO se encontró Transaction asociada al LPF (OrderId=' + existingLPF.Id + '). Debería crearse la Transaction y vincularla manualmente.');
        }
    }
}

// -----------------------------
// 7) Resumen final
// -----------------------------
System.debug('--- RESUMEN FINAL ---');
System.debug('AutorizacionCode = ' + AutorizacionCode);
System.debug('Payment REFUNDED presente = ' + (refundedPayment != null || paymentToUse != null));
System.debug('PaymentId usado = ' + (paymentToUse != null ? paymentToUse.Id : 'N/A'));
System.debug('LPF existente antes = ' + (existingLPF != null));
System.debug('LPF creado ahora = ' + (orderCreated != null));
System.debug('Transaction existente antes = ' + (txn != null));
System.debug('Transaction creada ahora = ' + (txnCreated != null));
System.debug('--- FIN ---');
