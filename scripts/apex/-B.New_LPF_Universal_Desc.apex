// ┌──────────────────────────────────────────────────────────────┐
// │  LPF – TC / ACH  (Anonymous Apex)  –  LISTO PARA EJECUTAR  │
// └──────────────────────────────────────────────────────────────┘

// ------------- CONFIGURAR -------------  :)
String  contratoId          = '00318012';
Date    fechaCobro          = Date.newInstance(2026, 07, 23);
String  PTP_Msg             = ''; //'NO LPF - En Mes'; //''; //  
Boolean penalty             = false;
Boolean withoutTaxes         = true;
String  ordType             = 'AC' ; //'Late Payment fee'; //'Subscription';  // 

// --- PARÁMETROS DE DESCUENTO (opcional) ---
Boolean applyDiscount       = false;                // <<<< cambiar a true si aplica
String  discountType        = applyDiscount ? 'Value' : null;   // Value / Percentage
String  discountReason      = applyDiscount ? 'COBRO DE PENALIDAD EN AC' : null;
Decimal discountPercentage  = (applyDiscount && discountType == 'Percentage') ? 0 : 0;  // %
Decimal discountValue       = (applyDiscount && discountType == 'Value') ? 25 : 0;       // $
String  userReqDiscount     = applyDiscount ? 'Raiza Montiel' : null;
String  userApprDiscount    = applyDiscount ? 'Elba Mantilla' : null;
// ------------------------------------------

if (String.isBlank(contratoId)) {
    System.debug('\u2192 ❌ No se proporcionó ID de contrato.');
    return;
}

// 1️⃣  CONTRATO + CAMPOS EXTRAS (Account.Name para billing)
Contract c;
try {
    c = [
        SELECT Id, AccountId, SM_Monthly_offer__c, SM_Payment_Method__c,SM_Net_AC__c,
               SM_Payment_methods__c, SM_Email_to_send_contract__c,
               GatewayId__c, 
               SM_Start_date__c, SM_AC_start_date__c, SM_AC_Split_Date__c,
               Account.FirstName, Account.LastName,
               ContractNumber, CB_Subscription__c
        FROM Contract
        WHERE ContractNumber = :contratoId
        LIMIT 1
    ];
} catch (QueryException qe) {
    System.debug('\u2192 ❌ Contrato no existe: ' + qe.getMessage());
    return;
}


//x  Consultar si existe el Subscription, y la solicitud es crear subscription
if (ordType == 'Subscription') {
    SM_ACH_Order__c existingACHSub;
    try {
        existingACHSub = [
            SELECT Id, Name
            FROM SM_ACH_Order__c
            WHERE SM_Contract__c = :c.Id
              AND SM_Payment_Type__c = 'Subscription'
            
        ];
    } catch (QueryException qe) {
        System.debug('\u2192 ✅NO existe una suscripción de ACH ' + qe.getMessage());
        //return;
    }

    if (existingACHSub != null) {
        System.debug('\u2192 ❌ Ya existe una suscripción de ACH : ' + existingACHSub.Name + ' CNT: ' + c.ContractNumber);
        return;
    }
}

//x  Consultar si existe el AC, y la solicitud es crear AC
if (ordType == 'AC') {
    SM_ACH_Order__c existingACHAC;
    try {
        existingACHAC = [
            SELECT Id, Name
            FROM SM_ACH_Order__c
            WHERE SM_Contract__c = :c.Id
              AND SM_Payment_Type__c = 'AC'
            
        ];
    } catch (QueryException qe) {
        System.debug('\u2192 ✅NO existe un Order de AC de ACH ' + qe.getMessage());
        //return;
    }

    if (existingACHAC != null) {
        System.debug('\u2192 ❌ ' + c.ContractNumber + ' Ya existe un Order de AC de ACH : ' + existingACHAC.Name + ' CNT: ' + c.ContractNumber);
        return;
    }
}



// 2️⃣  PAYMENT METHOD
SM_Payment_Method__c pm;
try {
    pm = [
        SELECT Id, SM_Credit_Card_Number__c, SM_Credit_Card_expiration_month__c,
               SM_Credit_Card_expiration_year__c, SM_Credit_Card_Franchise__c,
               SM_Card_Token__c, SM_Bank__c, SM_ACH_Account_Number__c
        FROM SM_Payment_Method__c
        WHERE Id = :c.SM_Payment_Method__c
        LIMIT 1
    ];
} catch (QueryException qe) {
    System.debug('\u2192 ❌ Payment Method no encontrado: ' + qe.getMessage());
    return;
}

// 3️⃣  BILLING ADDRESS
ContactPointAddress billAddr;
try {
    billAddr = [
        SELECT Street, City, State, PostalCode, Country
        FROM ContactPointAddress
        WHERE ParentId = :c.AccountId
          AND SM_Type__c = 'Billing Address'
        LIMIT 1
    ];
} catch (QueryException qe) {
    System.debug('\u2192 ❌ Billing Address no encontrado: se usarán valores del contrato.');
}

// 4️⃣  CÁLCULO DE MONTOS
Decimal base         = c.SM_Monthly_offer__c.setScale(2);
System.debug('\u2192 ANTES:: ordertype & penalty : ' + ordType + ' - ' + penalty + ' : ' + base);
if (ordType == 'Subscription') {
    penalty = false;
    PTP_Msg = '';
    System.debug('\u2192 DENTRO:: ordertype & penalty : ' + ordType + ' - ' + penalty + ' : ' + base);
}
System.debug('\u2192 DESPUES:: ordertype & penalty : ' + ordType + ' - ' + penalty + ' : ' + base);
Decimal penaltyValue = penalty ? 25.00 : 0;
base += penaltyValue;

Decimal subtotal     = withoutTaxes ? (base).setScale(2) : (base / 1.115).setScale(2);
Decimal tax          = withoutTaxes ? 0 : (base * 0.115).setScale(2);
Decimal total        = withoutTaxes ? (base).setScale(2) : (base + tax).setScale(2);

System.debug('\u2192 \u2192 Base: ' + base + ' 🔸 Tax: ' + tax + ' 🔸 Total: ' + total);

// 5️⃣  FUNCIONES AUXILIARES
/*
String cleanCard(String src){
    return String.isBlank(src) ? '' : src.replaceAll('\\s+','');
}
String cardClean = cleanCard(pm.SM_Credit_Card_Number__c);
*/
// 6️⃣  DISCOUNT BUILDER (devuelve Map para reutilizar)
Map<String, Decimal> applyDiscLogic(){
    Map<String, Decimal> m = new Map<String, Decimal>();
    if (!applyDiscount) {
        m.put('subtotal', base);
        m.put('tax',      tax);
        m.put('total',    total);
        return m;
    }
    Decimal subDisc;
    if (discountType == 'Value') {
        subDisc = base - discountValue;
    } else { // Percentage
        subDisc = base * (1 - discountPercentage/100);
    }
    subDisc = subDisc.setScale(2);
    Decimal taxDisc = withoutTaxes ? 0 : subDisc * 0.115;
    m.put('subtotal', subDisc);
    m.put('tax',      taxDisc.setScale(2));
    m.put('total',    (subDisc + taxDisc).setScale(2));
    return m;
}
Map<String, Decimal> discMap = applyDiscLogic();

SM_ACH_Order__c newACH = null;

// 8️⃣  RAMA – ACH

if (c.SM_Payment_methods__c == 'ACH') {
        // 🔥 Preparar fechas ANTES del constructor
        Date startDate;
        Date endDate;
        Date nextDate;
        String frequency;

        // Regla: si es AC → todas las fechas = SM_AC_start_date__c
        if (ordType == 'AC') {
            startDate = c.SM_AC_start_date__c;
            endDate   = c.SM_AC_start_date__c;
            nextDate  = c.SM_AC_start_date__c;
            frequency = 'Once';
        } else {
            // Subscription o cualquier otro tipo
            Boolean isSub = (ordType == 'Subscription');

            frequency = isSub ? 'Monthly' : 'Once';
            startDate = isSub ? c.SM_Start_date__c : fechaCobro;
            endDate   = isSub ? c.SM_Start_date__c : fechaCobro;
            nextDate  = isSub ? c.SM_Start_date__c : fechaCobro;
        }

        // ✅ Constructor limpio y válido
        newACH = new SM_ACH_Order__c(
            SM_Contract__c            = c.Id,
            SM_Payment_Type__c        = ordType,
            SM_Payment_Frequency__c   = frequency,
            SM_Payment_Start_Date__c  = startDate,
            SM_Payment_End_Date__c    = endDate,
            SM_Next_Transaction_Date__c = nextDate,

            SM_Payment_Status__c      = 'Pending',
            SM_Payment_Condition__c   = 'Fixed value',
            SM_Billing_Email__c       = c.SM_Email_to_send_contract__c,
            SM_Payment_Count__c       = 1,
            SM_Fee_to_collect__c      = 1,
            SM_Apply_Penalty__c       = penalty,
            SM_Penalty_Value__c       = penaltyValue,
            SM_Payment_Method__c      = c.SM_Payment_Method__c,
            SM_Total__c               = discMap.get('subtotal')
        );


    // ✅ Asignar descuento FUERA del constructor
    if (applyDiscount) {
        newACH.SM_Discount_Status__c           = 'Accepted';
        newACH.SM_Discount_Reason__c           = discountReason;
        newACH.Discount_Original_Subtotal__c   = c.SM_Monthly_offer__c + penaltyValue;
        newACH.Discount_Original_Total__c      = discMap.get('total');
        newACH.SM_Discount_Type__c             = discountType;
        newACH.SM_Discount_Percentage__c       = discountPercentage;
        newACH.SM_Discount_Value__c            = discountValue;
        newACH.SM_User_Who_Request_Discount__c = userReqDiscount;
        newACH.User_Who_Approve_Discount__c    = userApprDiscount;
        newACH.SM_Apply_Discount__c            = false;
    }

    try {
        insert newACH;
        System.debug('\u2192 ✅ ' + c.ContractNumber + '\u2502' + newACH.SM_Payment_Type__c + ' de ACH creado: ' + newACH.Id + ' ( ' + newACH.Name + ' ) ');
    } catch (Exception e) {
        System.debug('\u2192 ❌ Error insertando ' + newACH.SM_Payment_Type__c + ' de ACH: ' + e.getMessage());
    }

    //  solo aplica para los subscription de ACH y marcar el cotnrato como Activated
    if (ordType == 'Subscription'){
        c.Status = 'Activated';

        // Verificar si el campo SM_AC_Split_Date__c es null y aplicar los cambios correspondientes
        if (c.SM_AC_Split_Date__c == null) {
                c.SM_Charged_AC_Fees__c = 1;  // Asignar el valor 1 al campo de tarifas
            }else
			{
				c.SM_Charged_AC_Fees__c = 2;
				}	
            c.SM_Charged_AC_Amount__c = c.SM_Net_AC__c;
			c.SM_AC_collected__c = true ;
			c.SM_Payment_Received__c = true;
            if (c.SM_Charged_AC_Fees__c > 0){
                update c;
                System.debug('\u2192 Contrato actualizado: ' + c.ContractNumber);
            }
            else {
                System.debug('\u2192 Contrato ' + c.ContractNumber + ' NO Actualizado, Validar pagos de AC');
            }
            
    }

} else {
    System.debug('\u2192 ❌ Tipo de pago no soportado: ' + c.SM_Payment_methods__c);
}

// 9️⃣  ACTUALIZAMOS SM_Apply_Discount__c = TRUE **DESPUÉS** de todo el proceso (solo en el Order)
if (applyDiscount) {

    if (c.SM_Payment_methods__c == 'Credit Card' 
          //&& newLPF != null
          ) {
        //newLPF.SM_Apply_Discount__c = true;
        //update newLPF;
        System.debug('\u2192 ✅ Campo SM_Apply_Discount__c actualizado a TRUE en Order TC después de todo el proceso.');
    } else if (c.SM_Payment_methods__c == 'ACH' && newACH != null) {
        newACH.SM_Apply_Discount__c = true;
        update newACH;
        System.debug('\u2192 ✅ Campo SM_Apply_Discount__c actualizado a TRUE en Order ACH después de todo el proceso.');
    }
} else {
    System.debug('\u2192 ✅ Sin descuento. Campo SM_Apply_Discount__c no se actualiza en el Order.');
}
