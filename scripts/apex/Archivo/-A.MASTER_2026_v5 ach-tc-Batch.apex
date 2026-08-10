// ====================== SCRIPT MULTI-CONTRATO - PROCESAR VARIOS ACH ORDERS ======================  // Versión Grok - Procesamiento en lote

List<String> contractNumbers = new List<String>{
    '00315354'
};

Boolean confirmarActualizacion = false; 
// ⚠️ Cambia a TRUE solo cuando estés 100% seguro de actualizar en producción

Date hoy = Date.today();

// ====================== LISTAS GLOBALES PARA UPDATE ======================
List<SM_ACH_Order__c> allACHToUpdate = new List<SM_ACH_Order__c>();
List<ChargentOrders__ChargentOrder__c> allCHARGENTToUpdate = new List<ChargentOrders__ChargentOrder__c>();
List<chargebeeapps__CB_Subscription__c> allCHARGEBEEToUpdate = new List<chargebeeapps__CB_Subscription__c>();
String globalCsv = 'ContractNumber,Id,Name,SM_PTP_Montly__c,StatusFinal,FechaHoy\n';

Integer totalProcesados = 0;
Integer totalActualizados = 0;

// ====================== PROCESAMIENTO POR CONTRATO ======================
for (String contractNumber : contractNumbers) {

    // ====================== CONSULTA DEL CONTRATO ======================
    List<Contract> contracts = [
        SELECT 
            SM_Client_Id__c, Status, SM_AC_start_date__c, SM_AC_Split_Date__c, 
            SM_Start_date__c, SM_Total_ac__c, SM_Monthly_offer__c,
            SM_Plan_Months__c, SM_Payment_day__c, SM_Previous_Payment_day__c, 
            Reasons_for_change__c, SM_Number_of_Refund__c, Outstanding_installments__c,
            Count_Monthly_Payment_Pending__c, SM_Payment_methods__c, 
            SM_Registered_Card_Token__c, GatewayId__c, SM_Customer_Cancellation__c,
            SM_ContractMonitoring__c, SM_Payment_Method__c, 
            SM_Process_automation_by_product_family__r.Name, 
            SM_Email_to_send_contract__c, SM_Account_Name__c, Id, AccountId, RecordTypeId, ContractNumber, CB_Subscription__c
        FROM Contract 
        WHERE ContractNumber = :contractNumber 
        LIMIT 1
    ];

    if (contracts.isEmpty()) {
        System.debug('  →  ❌ No se encontró el contrato: ' + contractNumber);
        continue;
    }
    
    Contract c = contracts[0];

    String dateAC = DateTime.newInstance(c.SM_AC_start_date__c, Time.newInstance(0,0,0,0)).format('dd MMM yyyy');
    String dateRC = DateTime.newInstance(c.SM_Start_date__c, Time.newInstance(0,0,0,0)).format('dd MMM yyyy');
 
    String PaymentMethods = '';
    if (c.SM_Payment_methods__c == 'ACH') {
        PaymentMethods = 'ACH 🏦';
    } else if (c.SM_Payment_methods__c == 'Credit Card' &&  c.CB_Subscription__c == null) {
        PaymentMethods = 'TC 💳';
    } else if (c.SM_Payment_methods__c == 'Credit Card' &&  c.CB_Subscription__c != null) {
        PaymentMethods = 'Chargebee ♨️';
    }
    

    System.debug('  →  ');
    System.debug('  → ════════════════════════════════════════════════════════════════════');
    System.debug('  → ' + PaymentMethods + ' 🧾 '  + c.ContractNumber + '▫️' + c.Status + ' 📆 AC : ' + dateAC + ' 📆 RC : ' + dateRC +
                (c.Count_Monthly_Payment_Pending__c > 1 ? ' 💰' + c.Count_Monthly_Payment_Pending__c : '') +
                 '▫️' + (c.SM_Process_automation_by_product_family__r != null ? c.SM_Process_automation_by_product_family__r.Name : 'N/A') + 
                 (c.SM_Customer_Cancellation__c == true ? '🚨 Cancelación: ' + c.SM_Customer_Cancellation__c : '') +
                 (c.SM_ContractMonitoring__c == true ? '⚠️ Monitoring: ' + c.SM_ContractMonitoring__c : '')
                 );
    System.debug('  → Total AC: $' + c.SM_Total_ac__c + '▫️Total RC: $' + c.SM_Monthly_offer__c);
    System.debug('  → ════════════════════════════════════════════════════════════════════');

    // ====================== VALIDACIONES ======================
    Boolean contratoElegible = (c.Status == 'Activated' || c.Status == 'Payment Process') 
                               && c.SM_Customer_Cancellation__c == false;

    if (!contratoElegible) {
        System.debug('  →  ⚠️ Contrato NO elegible para cambiar a INITIATED (Estado: ' + c.Status + 
                     '▫️Cancelación: ' + c.SM_Customer_Cancellation__c + ')');
    }

    if (c.SM_Customer_Cancellation__c == true) {
        System.debug('  →  🚨 CONTRATO EN PROCESO DE CANCELACIÓN');
    }
    
    if (c.SM_ContractMonitoring__c == true) {
        System.debug('  →  🔍 CONTRATO EN REVISIÓN / MONITORING');
    }

    if (c.Is_VIP_Contract__c == true) {
        System.debug('  →  ⛔ VIP - NO PROCESAR');
    }

    if (c.Is_Test_Contract__c == true) {
        System.debug('  →  🤡 CONTRATO DE TEST - NO PROCESAR');
    }

    if (c.SM_AC_Split_Date__c != null && c.SM_AC_Split_Date__c >= hoy) {
        System.debug('  → 🔀 SPLIT AC programado para: ' + c.SM_AC_Split_Date__c);
    }
    
    if (c.SM_Plan_Months__c != 99 && c.SM_Plan_Months__c != null) {
        System.debug('  → 📆 Plan a ' + c.SM_Plan_Months__c + ' meses');
    }
    
    if (c.SM_Previous_Payment_day__c != null) {
        System.debug('  → 📅 Cambio de fecha de pago: ' + c.SM_Previous_Payment_day__c + 
                    ' => ' + c.SM_Payment_day__c + 
                    '▫️Razón: ' + c.Reasons_for_change__c);
    }

    // ====================== CÁLCULOS (solo debug) ======================

        Integer Refunded = [SELECT COUNT() FROM SM_Payment__c WHERE SM_Contract__c = :c.Id AND Payment_Status__c IN ('REFUNDED','ACH PENDING REFUND','TRANSMITTED REFUND')];
        if (Refunded > 0) {
            System.debug(' → 🚨 Pagos REFUND : ' + Refunded);
        } 

        Integer acceptedNonAC = [SELECT COUNT() FROM SM_Payment__c WHERE SM_Contract__c = :c.Id AND Payment_Status__c = 'ACCEPTED' AND SM_Type__c != 'AC' AND SM_Original_Type__c != 'AC'];
        String msgAccepted = acceptedNonAC > 0 ? '📆 Pagos ACCEPTED (no AC): ' + (acceptedNonAC - Refunded) + ' Abono Cuota de : ' + DateTime.newInstance(c.SM_Start_date__c.addMonths(acceptedNonAC - Refunded-1), Time.newInstance(0,0,0,0)).format('MMMM yyyy') : 'No hay pagos RC - SOLO PAGO AC';
        System.debug(' → ' + msgAccepted); 

        Integer pagosAC = [SELECT COUNT() FROM SM_Payment__c WHERE SM_Contract__c = :c.Id AND Payment_Status__c = 'ACCEPTED' AND (SM_Type__c = 'AC' OR SM_Original_Type__c = 'AC')];
            if (pagosAC > 0) {
                System.debug(' → ✅ Pagos ACCEPTED AC: ' + pagosAC);
            }

        if (c.SM_Payment_methods__c == 'ACH') {
            Integer pagosEnProceso = 0;
            Integer pagosReturn = [SELECT COUNT() FROM SM_Payment__c WHERE SM_Contract__c = :c.Id AND SM_Check_Collection_Status__c IN ('Return')];
            if (pagosEnProceso > 0) {
                System.debug(' → 🔄 Pagos en proceso: ' + pagosEnProceso);
            }

            Integer pagosEnPending = [SELECT COUNT() FROM SM_Payment__c WHERE SM_Contract__c = :c.Id AND SM_Check_Collection_Status__c IN ('Pending')];
            if (pagosEnPending > 0) {
                System.debug(' →      🚩 Pagos en Pending: ' + pagosEnPending);
            }

            Integer pagosEnTRX = [SELECT COUNT() FROM SM_Payment__c WHERE SM_Contract__c = :c.Id AND Payment_Status__c = 'ACH TRANSMITTED'];
            if (pagosEnTRX > 0) {
                System.debug(' →      🚧 Pagos en Transmitted: ' + pagosEnTRX);
            }
            pagosEnProceso = pagosReturn + pagosEnPending + pagosEnTRX;
        }


        Integer cuotasContadas = acceptedNonAC + pagosEnProceso - Refunded;
        Date fechaSiguienteCobroCalc = c.SM_Start_date__c != null ? c.SM_Start_date__c.addMonths(cuotasContadas) : hoy;
        System.debug(' → 📆 Fecha estimada próximo cobro: ' + DateTime.newInstance(fechaSiguienteCobroCalc, Time.newInstance(0,0,0,0)).format('dd MMM yyyy') + ' (Pagos Aceptados + Pagos en Proceso - Pagos Refund)');

    Integer updatedThisContract = 0;   // ← Corregido: ahora está fuera del IF

        // #region ACH ====================== ACH ORDERS ======================
    if (c.SM_Payment_methods__c == 'ACH') {
        List<SM_ACH_Order__c> achOrders = [
            SELECT 
                Id, Name, SM_Payment_Type__c, SM_Original_Type__c,
                SM_Failed_payment__c, SM_Failed_payment__r.Name,
                SM_Failed_payment__r.Payment_Status__c,
                SM_Failed_payment__r.SM_Check_Collection_Status__c,
                SM_PTP_Montly__c, SM_Payment_Status__c,
                SM_Next_Transaction_Date__c, SM_Total__c, SM_Penalty_Value__c, 
                Total_Amount__c, CreatedDate, SM_Contract__r.SM_Payment_day__c, SM_Failed_payment__r.SM_Payment_Date__c
            FROM SM_ACH_Order__c
            WHERE SM_Contract__c = :c.Id 
            AND SM_Payment_Status__c NOT IN ('Canceled', 'Completed')
            ORDER BY CreatedDate ASC
        ];
        System.debug(' →');
        System.debug(' →  ACH Orders en Proceso (Activos) : ' + achOrders.size());

        if (achOrders.isEmpty()) {
            System.debug(' →  No hay órdenes ACH pendientes para actualizar.');
        } else {

            // ====================== PROCESAMIENTO DE ÓRDENES ACH ======================
            for (SM_ACH_Order__c o : achOrders) {

                // Debug detallado
                String createdFmt = DateTime.newInstance(o.CreatedDate.date(), Time.newInstance(0,0,0,0)).format('dd MMM yyyy');
                String nextTx = o.SM_Next_Transaction_Date__c != null 
                    ? DateTime.newInstance(o.SM_Next_Transaction_Date__c, Time.newInstance(0,0,0,0)).format('dd MMM yyyy') 
                    : 'N/A';

                String line = '     • ' + o.Name + '▫️';
                if (o.SM_Payment_Type__c == 'Late Payment Fee') line += 'LatPayFe';
                else line += (o.SM_Payment_Type__c != null ? o.SM_Payment_Type__c : 'N/A');
                
                if (o.SM_Original_Type__c != null) line += '/' + o.SM_Original_Type__c;
                if (o.SM_Payment_Status__c != null) line += '▫️' + o.SM_Payment_Status__c;
                
                if (o.SM_Payment_Type__c == 'Subscription') line += '▫️ PayDay : ' + o.SM_Contract__r.SM_Payment_day__c; 
                
                line += '▫️nextTx: ' + nextTx;
                if (o.SM_PTP_Montly__c != null) line += '▫️PTP: ' + o.SM_PTP_Montly__c;
                if (o.Total_Amount__c != null) line += '▫️$' + o.Total_Amount__c;
                if (o.SM_Failed_payment__c != null) 
                    line += '▫️Failed: ' + o.SM_Failed_payment__r.Name + 
                            ' (' + o.SM_Failed_payment__r.SM_Check_Collection_Status__c + ')';
                line += '▫️Created: ' + createdFmt;

                System.debug(' → ' + line);

                // ====================== 1. LATE PAYMENT FEE - CANCELED ======================
                if (o.SM_Payment_Type__c == 'Late Payment Fee' &&
                    o.SM_Failed_payment__c != null &&
                    o.SM_Payment_Status__c != 'Canceled' && 
                    (o.SM_Failed_payment__r.SM_Check_Collection_Status__c == 'Collected' ||
                    o.SM_Failed_payment__r.SM_Check_Collection_Status__c == 'Accepted')) {

                    o.SM_Payment_Status__c = 'Canceled';
                    allACHToUpdate.add(o);
                    updatedThisContract++;

                    System.debug(' →  CANCELED (Collected/Accepted)');
                }
                
                // ====================== 2. LATE PAYMENT FEE - INITIATED (solo contratos elegibles) ======================
                else if (o.SM_Payment_Type__c == 'Late Payment Fee' &&
                        o.SM_Failed_payment__c != null &&
                        contratoElegible &&
                        o.SM_Payment_Status__c != 'Initiated' && 
                        o.SM_Failed_payment__r.SM_Check_Collection_Status__c == 'Not_Collected') {

                    o.SM_Payment_Status__c = 'Initiated';
                    o.SM_Next_Transaction_Date__c = hoy;
                    o.SM_PTP_Montly__c =  o.SM_Failed_payment__r.SM_Payment_Date__c != null 
                                            ? DateTime.newInstance(o.SM_Failed_payment__r.SM_Payment_Date__c, Time.newInstance(0,0,0,0)).format('MMM')  
                                            : null;
                    allACHToUpdate.add(o);
                    updatedThisContract++;

                    System.debug(' →  X Procesar : ' + o.Name + '▫️' + o.SM_Payment_Status__c + ' (' + o.SM_PTP_Montly__c + ') ▫️' + o.SM_Next_Transaction_Date__c);
                }

                // ====================== 3. LÓGICA PTP (Stopped) ======================
                Boolean incluirXCobrar = (o.SM_Failed_payment__c != null &&
                                        o.SM_Failed_payment__r.SM_Check_Collection_Status__c == 'Not_Collected' &&
                                        o.SM_Payment_Status__c == 'Stopped' &&
                                        (o.SM_PTP_Montly__c == 'abril PTP' || 
                                        o.SM_PTP_Montly__c == 'mayo PTP' || 
                                        o.SM_PTP_Montly__c == 'junio PTP' || 
                                        o.SM_PTP_Montly__c == 'julio PTP' || 
                                        o.SM_PTP_Montly__c == 'agosto PTP'));

                Boolean incluirXCancelar = (o.SM_Failed_payment__c != null &&
                                            o.SM_Payment_Status__c == 'Stopped' &&
                                            (o.SM_Failed_payment__r.SM_Check_Collection_Status__c == 'Collected' || 
                                            o.SM_Failed_payment__r.SM_Check_Collection_Status__c == 'Accepted'
                                            ));

                if (incluirXCobrar || incluirXCancelar) {
                    String statusFinal = incluirXCancelar ? 'Canceled' : 'Initiated';

                    globalCsv += c.ContractNumber + ',' + o.Id + ',' + o.Name + ',' + 
                                (o.SM_PTP_Montly__c != null ? o.SM_PTP_Montly__c : '') + ',' + 
                                statusFinal + ',' + String.valueOf(hoy) + '\n';

                    o.SM_Payment_Status__c = statusFinal;
                    o.SM_Next_Transaction_Date__c = hoy;
                    allACHToUpdate.add(o);
                    updatedThisContract++;

                    System.debug(' →  PTP ' + statusFinal);
                }
            }
        }
    }
    // #endregion ACH ===================== FIN PROCESAMIENTO DE ÓRDENES ACH ======================
   
    // #region Chargent  ====================== Chargent TC ORDERS ======================
    if (c.SM_Payment_methods__c == 'Credit Card' &&  c.CB_Subscription__c == null) {
        List<ChargentOrders__ChargentOrder__c> chargentOrders = [
            SELECT 
                Name, SM_Payment_Type__c, Type_Failed_Payment__c,
                ChargentOrders__Charge_Date__c, SM_Apply_Penalty__c, SM_Apply_Discount__c,ChargentOrders__Billing_Country__c,
                Id, SM_PTP_Montly__c, ChargentOrders__Payment_Status__c,ChargentOrders__Payment_Start_Date__c, ChargentOrders__Next_Transaction_Date__c,
                CreatedDate, ChargentOrders__Subtotal__c, ChargentOrders__Total__c, SM_Penalty_Value__c,
                ChargentOrders__Charge_Amount__c, ChargentOrders__Tax__c, SM_P_IVU_State_Amount__c,
                SM_P_IVU_Municipal_Amount__c, SM_IVU_State_Amount__c, SM_IVU_Municipal_Amount__c,
                ChargentOrders__Gateway__c, ChargentOrders__Tokenization__c,
                ChargentOrders__Card_Last_4__c, ChargentOrders__Card_Expiration_Month__c,
                ChargentOrders__Card_Expiration_Year__c, ChargentOrders__Card_Number__c,
                ChargentOrders__Card_Month_Indicator__c, ChargentOrders__Card_Year_Indicator__c,
                Contract__c, SM_Failed_Payment__c,
                SM_Failed_payment__r.Payment_Status__c, Contract__r.SM_Payment_day__c
            FROM ChargentOrders__ChargentOrder__c
            WHERE Contract__c = :c.Id 
            AND ChargentOrders__Payment_Status__c IN ('Recurring', 'Stopped')
            ORDER BY CreatedDate ASC
        ]; 
        System.debug(' →');
        System.debug(' →  💳 TC Orders en Proceso (Activos) : ' + chargentOrders.size());
        System.debug(' →  💡 Contract PayDay : ' + c.SM_Payment_day__c);

        if (chargentOrders.isEmpty()) {
            System.debug(' →  No hay CHARGENTS pendientes para actualizar.');
        } else {

            // ====================== PROCESAMIENTO DE CHARGENT ÓRDENES ======================
            for (ChargentOrders__ChargentOrder__c co : chargentOrders) {

                // Debug detallado
                String createdFmt = DateTime.newInstance(co.CreatedDate.date(), Time.newInstance(0,0,0,0)).format('dd MMM yyyy');
                String nextTx = co.ChargentOrders__Next_Transaction_Date__c != null 
                    ? DateTime.newInstance(co.ChargentOrders__Next_Transaction_Date__c, Time.newInstance(0,0,0,0)).format('dd MMM yyyy') 
                    : 'N/A';

                String line = '     • ' + co.Name + '▫️';
                if (co.SM_Payment_Type__c == 'Late Payment Fee') line += 'LatePaymentFee';
                else line += (co.SM_Payment_Type__c != null ? co.SM_Payment_Type__c + '  ' : 'N/A');
                
                line += '▫️' + co.ChargentOrders__Payment_Status__c;
                
                line += '▫️nextTx: ' + nextTx;
                if (co.SM_PTP_Montly__c != null) line += '▫️PTP: ' + co.SM_PTP_Montly__c;
                line += '▫️$' + co.ChargentOrders__Total__c;
                if (co.SM_Penalty_Value__c > 0 ) line += '+ ' + co.SM_Penalty_Value__c;   //penalty 

                if (co.SM_Failed_payment__c != null) 
                    line += '▫️Failed: ' + co.SM_Failed_payment__r.Name + 
                            ' (' + co.SM_Failed_payment__r.SM_Check_Collection_Status__c + ')';
                line += '▫️Created: ' + createdFmt;

                System.debug(' → ' + line);

                // ====================== 1. LATE PAYMENT FEE - CANCELED ======================
                if (co.SM_Payment_Type__c == 'Late Payment Fee' &&
                    co.SM_Failed_payment__c != null &&
                    co.ChargentOrders__Payment_Status__c != 'Canceled' && 
                    (co.SM_Failed_payment__r.SM_Check_Collection_Status__c == 'Collected' ||
                    co.SM_Failed_payment__r.SM_Check_Collection_Status__c == 'Accepted')) {

                    co.ChargentOrders__Payment_Status__c = 'Canceled';
                    allCHARGENTToUpdate.add(co);
                    updatedThisContract++;

                    System.debug(' →  CANCELED (Collected/Accepted)');
                }
                
                // ====================== 2. LATE PAYMENT FEE - INITIATED (solo contratos elegibles) ======================
                else if (co.SM_Payment_Type__c == 'Late Payment Fee' &&
                        co.SM_Failed_payment__c != null &&
                        contratoElegible &&
                        co.ChargentOrders__Payment_Status__c != 'Recurring' && 
                        co.SM_Failed_payment__r.Payment_Status__c == 'REJECTED') {

                    co.ChargentOrders__Payment_Status__c = 'Recurring';
                    co.ChargentOrders__Next_Transaction_Date__c = hoy;
                    co.SM_PTP_Montly__c =  co.SM_Failed_payment__r.SM_Payment_Date__c != null 
                                            ? DateTime.newInstance(co.SM_Failed_payment__r.SM_Payment_Date__c, Time.newInstance(0,0,0,0)).format('MMM')  
                                            : null;
                    allCHARGENTToUpdate.add(co);
                    updatedThisContract++;

                    System.debug(' →  X Procesar : ' + co.Name + '▫️' + co.ChargentOrders__Payment_Status__c + ' (' + co.SM_PTP_Montly__c + ') ▫️' + co.ChargentOrders__Next_Transaction_Date__c);
                }

                // ====================== 3. LÓGICA PTP (Stopped) ======================
                Boolean incluirXCobrar = (co.SM_Failed_payment__c != null &&
                                        co.SM_Failed_payment__r.Payment_Status__c == 'REJECTED' &&
                                        co.ChargentOrders__Payment_Status__c == 'Stopped' &&
                                        (co.SM_PTP_Montly__c == 'abril PTP' || 
                                        co.SM_PTP_Montly__c == 'mayo PTP' || 
                                        co.SM_PTP_Montly__c == 'junio PTP' || 
                                        co.SM_PTP_Montly__c == 'julio PTP' || 
                                        co.SM_PTP_Montly__c == 'agosto PTP'));

                Boolean incluirXCancelar = (co.SM_Failed_payment__c != null &&
                                            co.ChargentOrders__Payment_Status__c == 'Stopped' &&
                                            (co.SM_Failed_payment__r.Payment_Status__c == 'Collected' || 
                                            co.SM_Failed_payment__r.Payment_Status__c == 'Accepted'
                                            ));

                if (incluirXCobrar || incluirXCancelar) {
                    String statusFinal = incluirXCancelar ? 'Canceled' : 'Recurring';

                    globalCsv += c.ContractNumber + ',' + co.Id + ',' + co.Name + ',' + 
                                (co.SM_PTP_Montly__c != null ? co.SM_PTP_Montly__c : '') + ',' + 
                                statusFinal + ',' + String.valueOf(hoy) + '\n';

                    co.ChargentOrders__Payment_Status__c = statusFinal;
                    co.ChargentOrders__Payment_Start_Date__c = hoy;   // ChargentOrders__Next_Transaction_Date__c
                    allCHARGENTToUpdate.add(co);
                    updatedThisContract++;

                    System.debug(' →  PTP ' + statusFinal);
                }
            }
        }

    }
    // #endregion Chargent  ====================== FIN Chargent TC ORDERS ======================


    // #region ChargeBee  ====================== ChargeBee TC ORDERS ======================
    if (c.SM_Payment_methods__c == 'Credit Card' &&  c.CB_Subscription__c != null) { 
        List<chargebeeapps__CB_Subscription__c> chargebeeOrders = [
            SELECT Id, chargebeeapps__Subscription_status__c,chargebeeapps__Subscription_Start_Date__c,                
                    chargebeeapps__Next_billing__c,chargebeeapps__Plan_Unit_Price__c,
                    chargebeeapps__Subscription_Plan__r.Name,
                    chargebeeapps__CB_Item_Price__r.Name,
                    Payment_Method__c,Payment_Method__r.Name,
                    Contract__c,Contract__r.ContractNumber
            FROM chargebeeapps__CB_Subscription__c
            WHERE Contract__c = :c.Id 
        ]; 
        System.debug(' →');
        System.debug(' →  ♨️ CB Orders en Proceso (Activos) : ' + chargebeeOrders.size());
    }
    // #endregion ChargeBee  ====================== FIN ChargeBee TC ORDERS ======================


    totalProcesados++;
    totalActualizados += updatedThisContract;
    
    System.debug(' →  ');
    if (updatedThisContract > 0) {
        System.debug(' →  ✅ ' + updatedThisContract + ' órdenes procesadas en este contrato.');
    } else {
        System.debug(' →  No se realizaron cambios en este contrato.');
    }
}

// ====================== UPDATE FINAL (UNA SOLA DML) ======================
System.debug(' →  ');
System.debug(' → ════════════════════════════════════════════════════════════════════');
System.debug(' → 🏁 PROCESAMIENTO FINALIZADO');
System.debug(' → ════════════════════════════════════════════════════════════════════');
System.debug(' → Total contratos procesados: ' + totalProcesados);
System.debug(' → Total ACH Orders a actualizar: ' + allACHToUpdate.size());

System.debug(' → === CSV GLOBAL PARA COPIAR ===\n' + globalCsv);

if (confirmarActualizacion) {
    if (!allACHToUpdate.isEmpty()) {
        update allACHToUpdate;
        System.debug(' → ✅ ÉXITO FINAL: ' + allACHToUpdate.size() + ' ACH Orders actualizados en total.');
    } else {
        System.debug(' → No había órdenes para actualizar.');
    }
} else {
    System.debug(' → ⚠️ MODO SEGURO ACTIVADO - No se realizó ninguna actualización.');
}