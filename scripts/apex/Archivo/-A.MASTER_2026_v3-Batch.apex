// ====================== SCRIPT MULTI-CONTRATO - PROCESAR VARIOS ACH ORDERS ======================
// Versión Grok - Procesamiento en lote

List<String> contractNumbers = new List<String>{
    '00312852'
};

Boolean confirmarActualizacion = false; 
// ⚠️ Cambia a TRUE solo cuando estés 100% seguro de actualizar en producción

Date hoy = Date.today();

// ====================== LISTAS GLOBALES PARA UPDATE ======================
List<SM_ACH_Order__c> allOrdersToUpdate = new List<SM_ACH_Order__c>();
String globalCsv = 'ContractNumber,Id,Name,SM_PTP_Montly__c,StatusFinal,FechaHoy\n';

Integer totalProcesados = 0;
Integer totalActualizados = 0;

// ====================== PROCESAMIENTO POR CONTRATO ======================
for (String contractNumber : contractNumbers) {

    // ====================== CONSULTA DEL CONTRATO ======================
    Contract c = [
        SELECT 
            SM_Client_Id__c, Status, SM_AC_start_date__c, SM_AC_Split_Date__c, 
            SM_Start_date__c, SM_Total_ac__c, SM_Monthly_offer__c,
            SM_Plan_Months__c, SM_Payment_day__c, SM_Previous_Payment_day__c, 
            Reasons_for_change__c, SM_Number_of_Refund__c, Outstanding_installments__c,
            Count_Monthly_Payment_Pending__c, SM_Payment_methods__c, 
            SM_Registered_Card_Token__c, GatewayId__c, SM_Customer_Cancellation__c,
            SM_ContractMonitoring__c, SM_Payment_Method__c, 
            SM_Process_automation_by_product_family__r.Name, 
            SM_Email_to_send_contract__c, SM_Account_Name__c, Id, AccountId, RecordTypeId, ContractNumber
        FROM Contract 
        WHERE ContractNumber = :contractNumber 
        LIMIT 1
    ];

    String dateAC = DateTime.newInstance(c.SM_AC_start_date__c, Time.newInstance(0,0,0,0)).format('dd MMM yyyy');
    String dateRC = DateTime.newInstance(c.SM_Start_date__c, Time.newInstance(0,0,0,0)).format('dd MMM yyyy');

    System.debug('  →  ');
    System.debug('  → ════════════════════════════════════════════════════════════════════');
    System.debug('  → 🚀 PROCESANDO CONTRATO: '  + c.ContractNumber + '▫️' + c.Status + ' 📆 AC : ' + dateAC + ' 📆 RC : ' + dateRC +

                (c.Count_Monthly_Payment_Pending__c > 1 ? ' 💰' + c.Count_Monthly_Payment_Pending__c : '') +
                 '▫️' + c.SM_Payment_methods__c + 
                 '▫️' + (c.SM_Process_automation_by_product_family__r != null ? c.SM_Process_automation_by_product_family__r.Name : 'N/A') + 
                 (c.SM_Customer_Cancellation__c == true ? '🚨 Cancelación: ' + c.SM_Customer_Cancellation__c : '') +
                 (c.SM_ContractMonitoring__c == true ? '⚠️ Monitoring: ' + c.SM_ContractMonitoring__c : '')
                 );
    System.debug('  → ════════════════════════════════════════════════════════════════════');

    if (c == null) {
        System.debug('  →  ❌ No se encontró el contrato: ' + contractNumber);
        continue;
    }

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
            System.debug('  → 🚨 Pagos REFUND : ' + Refunded);
        } 

        Integer acceptedNonAC = [SELECT COUNT() FROM SM_Payment__c WHERE SM_Contract__c = :c.Id AND Payment_Status__c = 'ACCEPTED' AND SM_Type__c != 'AC' AND SM_Original_Type__c != 'AC'];
        String msgAccepted = acceptedNonAC > 0 ? '📆 Pagos ACCEPTED (no AC): ' + (acceptedNonAC - Refunded) + ' Abono Cuota de : ' + DateTime.newInstance(c.SM_Start_date__c.addMonths(acceptedNonAC - Refunded-1), Time.newInstance(0,0,0,0)).format('MMMM yyyy') : 'No hay pagos RC - SOLO PAGO AC';
        System.debug(' → ' + msgAccepted); 

        Integer pagosEnProceso = [SELECT COUNT() FROM SM_Payment__c WHERE SM_Contract__c = :c.Id AND SM_Check_Collection_Status__c IN ('Return', 'Pending') AND Payment_Status__c IN ('REJECTED', 'ACH TRANSMITTED')];
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

        Integer cuotasContadas = acceptedNonAC + pagosEnProceso - Refunded;
        Date fechaSiguienteCobroCalc = c.SM_Start_date__c != null ? c.SM_Start_date__c.addMonths(cuotasContadas) : hoy;
        System.debug(' → 📆 Fecha estimada próximo cobro: ' + DateTime.newInstance(fechaSiguienteCobroCalc, Time.newInstance(0,0,0,0)).format('dd MMM yyyy') + ' (Pagos Aceptados + Pagos en Proceso - Pagos Refund)');

    // #region ACH ====================== ACH ORDERS ======================
    if (c.SM_Payment_methods__c != 'ACH') {
        System.debug(' →  Este contrato no usa ACH. Se omite.');
        continue;
    }

    List<SM_ACH_Order__c> achOrders = [
        SELECT 
            Id, Name, SM_Payment_Type__c, SM_Original_Type__c,
            SM_Failed_payment__c, SM_Failed_payment__r.Name,
            SM_Failed_payment__r.Payment_Status__c,
            SM_Failed_payment__r.SM_Check_Collection_Status__c,
            SM_PTP_Montly__c, SM_Payment_Status__c,
            SM_Next_Transaction_Date__c, SM_Total__c, Total_Amount__c, CreatedDate, SM_Contract__r.SM_Payment_day__c, SM_Failed_payment__r.SM_Payment_Date__c
        FROM SM_ACH_Order__c
        WHERE SM_Contract__c = :c.Id 
          AND SM_Payment_Status__c NOT IN ('Canceled', 'Completed')
        ORDER BY CreatedDate ASC
    ];
    System.debug(' →');
    System.debug(' →  ACH Orders en Proceso (Activos) : ' + achOrders.size());

    if (achOrders.isEmpty()) {
        System.debug(' →  No hay órdenes ACH pendientes para actualizar.');
        continue;
    }

    // ====================== PROCESAMIENTO DE ÓRDENES ACH ======================
    Integer updatedThisContract = 0;

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
            allOrdersToUpdate.add(o);
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
            allOrdersToUpdate.add(o);
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
            allOrdersToUpdate.add(o);
            updatedThisContract++;

            System.debug(' →  PTP ' + statusFinal);
        }
    }
// #endregion ACH ===================== FIN PROCESAMIENTO DE ÓRDENES ACH ======================

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
System.debug(' → Total ACH Orders a actualizar: ' + allOrdersToUpdate.size());

System.debug(' → === CSV GLOBAL PARA COPIAR ===\n' + globalCsv);

if (confirmarActualizacion) {
    if (!allOrdersToUpdate.isEmpty()) {
        update allOrdersToUpdate;
        System.debug(' → ✅ ÉXITO FINAL: ' + allOrdersToUpdate.size() + ' ACH Orders actualizados en total.');
    } else {
        System.debug(' → No había órdenes para actualizar.');
    }
} else {
    System.debug(' → ⚠️ MODO SEGURO ACTIVADO - No se realizó ninguna actualización.');
}