// ====================== SCRIPT CORREGIDO Y OPTIMIZADO ======================  → GROK

String contractNumber = '00315072';
Date hoy = Date.today();

// ====================== CONFIRMACIÓN DE ACTUALIZACIÓN ======================
Boolean confirmarActualizacion = true; 
// ⚠️ Cambia a TRUE solo cuando estés 100% seguro de actualizar en producción

// ====================== CONTRACT ======================
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

if (c == null) {
    System.debug(' → ❌ No se encontró el contrato con el número: ' + contractNumber);
    return;
}

System.debug(' → ==================== ' + c.ContractNumber + '▫️' + c.Status + '▫️' + c.SM_Payment_methods__c + 
             '▫️' + (c.SM_Process_automation_by_product_family__r != null ? c.SM_Process_automation_by_product_family__r.Name : 'N/A') + ' ====================');
System.debug(' → Cliente: ' + c.SM_Client_Id__c + ' ▫️ Cuenta: ' + c.SM_Account_Name__c + ' ▫️ Email: ' + c.SM_Email_to_send_contract__c);

// ====================== VALIDACIONES ======================
System.debug(' →==================== VALIDACIONES ====================');

if (c.Status != 'Activated') {
    System.debug(' → ⚠️ El contrato NO está Activado. Estado actual: ' + c.Status);
}
if (c.SM_Customer_Cancellation__c == true) {
    System.debug(' → 🚨 CONTRATO EN PROCESO DE CANCELACIÓN');
}
if (c.SM_ContractMonitoring__c == true) {
    System.debug(' → 🔍 CONTRATO EN REVISIÓN / MONITORING');
}
if (c.SM_AC_Split_Date__c != null && c.SM_AC_Split_Date__c >= hoy) {
    System.debug(' → 🔀 SPLIT AC programado para: ' + c.SM_AC_Split_Date__c);
}
if (c.SM_Plan_Months__c != 99 && c.SM_Plan_Months__c != null) {
    System.debug(' → 📆 Plan a ' + c.SM_Plan_Months__c + ' meses');
}
if (c.SM_Previous_Payment_day__c != null) {
    System.debug(' → 📅 Cambio de fecha de pago: ' + c.SM_Previous_Payment_day__c + 
                 ' → ' + c.SM_Payment_day__c + 
                 '▫️Razón: ' + c.Reasons_for_change__c);
}

// ====================== CÁLCULOS (solo debug) ======================
Integer acceptedNonAC = [SELECT COUNT() FROM SM_Payment__c WHERE SM_Contract__c = :c.Id AND Payment_Status__c = 'ACCEPTED' AND SM_Type__c != 'AC' AND SM_Original_Type__c != 'AC'];
System.debug(' → ✅ Pagos ACCEPTED (no AC): ' + acceptedNonAC);

Integer pagosEnProceso = [SELECT COUNT() FROM SM_Payment__c WHERE SM_Contract__c = :c.Id AND (SM_Check_Collection_Status__c IN ('Return', 'Pending') OR SM_Check_Collection_Status__c = NULL) AND Payment_Status__c IN ('REJECTED', 'ACH TRANSMITTED')];
System.debug(' → 🔄 Pagos en proceso: ' + pagosEnProceso);

Integer cuotasContadas = acceptedNonAC + pagosEnProceso;
Date fechaSiguienteCobroCalc = c.SM_Start_date__c != null ? c.SM_Start_date__c.addMonths(cuotasContadas) : hoy;
System.debug(' → 📆 Fecha estimada próximo cobro: ' + DateTime.newInstance(fechaSiguienteCobroCalc, Time.newInstance(0,0,0,0)).format('dd MMM yyyy'));

// ====================== ACH ORDERS (SOLO ACH) ======================
if (c.SM_Payment_methods__c == 'ACH') {

    List<SM_ACH_Order__c> achOrders = [
        SELECT 
            Id, Name, SM_Payment_Type__c, SM_Original_Type__c,
            SM_Failed_payment__c, SM_Failed_payment__r.Name,
            SM_Failed_payment__r.Payment_Status__c,
            SM_Failed_payment__r.SM_Check_Collection_Status__c,
            SM_PTP_Montly__c, SM_FinalStatus__c, SM_Payment_Status__c,
            SM_Next_Transaction_Date__c, SM_Total__c, Total_Amount__c, CreatedDate
        FROM SM_ACH_Order__c
        WHERE SM_Contract__c = :c.Id 
          AND SM_Payment_Status__c NOT IN ('Canceled', 'Completed')
        ORDER BY CreatedDate ASC
    ];

    System.debug(' → ACH Orders encontrados: ' + achOrders.size());

    // ====================== PREPARACIÓN ======================
    List<SM_ACH_Order__c> ordersToUpdate = new List<SM_ACH_Order__c>();
    String csv = 'Id,Name,SM_PTP_Montly__c,StatusFinal,FechaHoy\n';

    Boolean contratoElegible = (c.Status == 'Activated' || c.Status == 'Payment Process') 
                               && c.SM_Customer_Cancellation__c == false;

    // ====================== LOOP ÚNICO: Debug + Lógica (optimizado) ======================
    for (SM_ACH_Order__c o : achOrders) {

        // --- Debug / Presentación (se mantiene igual) ---
        Datetime createdDT = DateTime.newInstance(o.CreatedDate.date(), Time.newInstance(0,0,0,0));
        String createdFmt = createdDT.format('dd MMM yyyy');

        String nextTx = o.SM_Next_Transaction_Date__c != null 
            ? DateTime.newInstance(o.SM_Next_Transaction_Date__c, Time.newInstance(0,0,0,0)).format('dd MMM yyyy')
            : 'N/A';

        String line = '• ' + o.Name + '▫️';
        if (o.SM_Payment_Type__c == 'Late Payment Fee') {
            line += 'LPF';
        } else {
            line += o.SM_Payment_Type__c  != null ? o.SM_Payment_Type__c : 'N/A';
        }
        if (o.SM_Original_Type__c != null) line += '/' + o.SM_Original_Type__c;
        if (o.SM_Payment_Status__c != null) line += ' ▫️' + o.SM_Payment_Status__c;
        if (nextTx != null) line += ' ▫️NextTx: ' + nextTx;
        if (o.SM_PTP_Montly__c != null) line += ' ▫️PTP: ' + o.SM_PTP_Montly__c;
        if (o.Total_Amount__c != null) line += ' ▫️$' + o.Total_Amount__c;
        if (o.SM_Failed_payment__c != null) 
            line += ' ▫️FailedPayment: ' + o.SM_Failed_payment__r.Name + 
                    ' (' + o.SM_Failed_payment__r.SM_Check_Collection_Status__c + ')';
        line += ' ▫️Created: ' + createdFmt;

        System.debug(' → ' + line);

        // ====================== 1. LÓGICA LATE PAYMENT FEE (tus condiciones exactas) ======================
        if (o.SM_Payment_Type__c == 'Late Payment Fee' &&
            o.SM_Failed_payment__c != null &&
            o.SM_Payment_Status__c != 'Canceled' && 
            (o.SM_Failed_payment__r.SM_Check_Collection_Status__c == 'Collected' ||
             o.SM_Failed_payment__r.SM_Check_Collection_Status__c == 'Accepted')) {

            o.SM_Payment_Status__c = 'Canceled';
            ordersToUpdate.add(o);

            System.debug(' → AUDITORÍA: ACH Order ' + o.Id + ' (' + o.Name + ') → CANCELED (Failed Payment: ' + 
                         o.SM_Failed_payment__r.SM_Check_Collection_Status__c + ')');
        }
        else if (o.SM_Payment_Type__c == 'Late Payment Fee' &&
                 o.SM_Failed_payment__c != null &&
                 contratoElegible &&
                 o.SM_Payment_Status__c != 'Initiated' && 
                 o.SM_Failed_payment__r.SM_Check_Collection_Status__c == 'Not_Collected') {

            o.SM_Payment_Status__c = 'Initiated';
            ordersToUpdate.add(o);

            System.debug(' → LATE FEE PENDIENTE: ACH Order ' + o.Id + ' (' + o.Name + 
                         ') → INITIATED (Failed Payment: Not_Collected▫️Contrato elegible)');
        }

        // ====================== 2. LÓGICA PTP (Stopped) - mantenida y corregida ======================
        Boolean incluirXCobrar = false;
        Boolean incluirXCancelar = false;

        if (o.SM_Failed_payment__c != null &&
            o.SM_Failed_payment__r.SM_Check_Collection_Status__c == 'Not_Collected' &&
            o.SM_Payment_Status__c == 'Stopped' &&
            (o.SM_PTP_Montly__c == 'abril PTP' || 
             o.SM_PTP_Montly__c == 'mayo PTP' || 
             o.SM_PTP_Montly__c == 'junio PTP' || 
             o.SM_PTP_Montly__c == 'julio PTP' || 
             o.SM_PTP_Montly__c == 'agosto PTP')) {

            incluirXCobrar = true;
        }

        if (o.SM_Failed_payment__c != null &&
            o.SM_Payment_Status__c == 'Stopped' &&
            o.SM_Failed_payment__r.SM_Check_Collection_Status__c == 'Collected') {

            incluirXCancelar = true;
        }

        if (incluirXCobrar || incluirXCancelar) {
            String statusFinal = incluirXCancelar ? 'Canceled' : 'Initiated';
            String fechaFinal = String.valueOf(hoy);

            csv += o.Id + ',' + o.Name + ',' + 
                   (o.SM_PTP_Montly__c != null ? o.SM_PTP_Montly__c : '') + ',' + 
                   statusFinal + ',' + fechaFinal + '\n';

            o.SM_Payment_Status__c = statusFinal;
            o.SM_Next_Transaction_Date__c = hoy;
            ordersToUpdate.add(o);
        }
    }

    // ====================== UPDATE FINAL ======================
    System.debug(' → ==================== ACH ORDERS PARA CSV ====================');
    System.debug('=== CSV PARA COPIAR ===\n' + csv);

    if (confirmarActualizacion) {
        if (!ordersToUpdate.isEmpty()) {
            update ordersToUpdate;
            System.debug(' → ✅ ÉXITO: ' + ordersToUpdate.size() + ' ACH Orders actualizados (Late Fee + PTP).');
        } else {
            System.debug(' → No se encontraron órdenes para actualizar.');
        }
    } else {
        System.debug(' → ⚠️ MODO SEGURO: No se actualizó nada. Cambia confirmarActualizacion = true para ejecutar.');
    }
} else {
    System.debug(' → Este contrato no usa ACH. No se procesaron órdenes.');
}