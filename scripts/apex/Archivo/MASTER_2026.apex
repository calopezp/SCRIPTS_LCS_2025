String contractNumber = '00316509';
Date hoy = Date.today();

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
    System.debug(' →❌ No se encontró el contrato con el número: ' + contractNumber);
    return;
}

System.debug(' → ==================== ' + c.ContractNumber + '▫️' + c.Status + '▫️' + c.SM_Payment_methods__c + 
             '▫️' + c.SM_Process_automation_by_product_family__r.Name + ' ====================');
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

// ====================== PAYMENTS ======================
List<SM_Payment__c> payments = [
    SELECT Id, Name, SM_Type__c, SM_Original_Type__c, Payment_Status__c, 
           SM_Check_Collection_Status__c, SM_Payment_execution_date__c, 
           SM_Date_ACH_Transmitted__c, SM_Net_Amount__c, SM_Fee_value__c,
           SM_Failed_payment__r.Name, SM_Payments_refunded__r.Name,
           RecordType.Name, CreatedDate
    FROM SM_Payment__c 
    WHERE SM_Contract__c = :c.Id 
    ORDER BY CreatedDate ASC
];

System.debug(' → 📋 Total de Payments Procesados: ' + payments.size());

// ====================== CÁLCULOS: ACCEPTED no AC ======================
Integer acceptedNonAC = [
    SELECT COUNT() 
    FROM SM_Payment__c 
    WHERE SM_Contract__c = :c.Id
      AND Payment_Status__c = 'ACCEPTED'
      AND SM_Type__c != 'AC'
      AND SM_Original_Type__c != 'AC'
];

System.debug(' → ✅ Pagos ACCEPTED (no AC): ' + acceptedNonAC);

// ====================== CÁLCULOS: PAGOS EN PROCESO ======================
Integer pagosEnProceso = [
    SELECT COUNT()
    FROM SM_Payment__c
    WHERE SM_Contract__c = :c.Id
        AND (
        SM_Check_Collection_Status__c IN ('Return', 'Pending')
        OR SM_Check_Collection_Status__c = NULL
      )
  AND Payment_Status__c IN ('REJECTED', 'ACH TRANSMITTED')
];

System.debug(' → 🔄 Pagos en proceso (Return/Pending/Ach transmitted): ' + pagosEnProceso);

// ====================== CUOTAS CONTADAS ======================
Integer cuotasContadas = acceptedNonAC + pagosEnProceso;
System.debug(' → 📊 Total de cuotas contadas (Aceptados + En proceso): ' + cuotasContadas);

// ====================== FECHA ESTIMADA DEL PRÓXIMO COBRO ======================
Date fechaSiguienteCobroCalc;

if (c.SM_Start_date__c != null) {
    fechaSiguienteCobroCalc = c.SM_Start_date__c.addMonths(cuotasContadas);
} else {
    fechaSiguienteCobroCalc = hoy;
}

String fechaSiguienteCobroFmt = String.valueOf(fechaSiguienteCobroCalc); // yyyy-MM-dd

String fechaSiguienteCobroFmtPretty =
    DateTime.newInstance(fechaSiguienteCobroCalc, Time.newInstance(0,0,0,0))
            .format('dd MMM yyyy');

System.debug(' → 📆 Fecha estimada del próximo cobro (calculada): ' + fechaSiguienteCobroFmtPretty);

// ====================== ORDERS (SOLO ACH) ======================
System.debug(' →==================== ACH ORDERS ====================');

if (c.SM_Payment_methods__c == 'ACH') {

    List<SM_ACH_Order__c> achOrders = [
        SELECT 
            Id,
            Name,
            SM_Payment_Type__c,
            SM_Original_Type__c,
            SM_Failed_payment__c,
            SM_Failed_payment__r.Name,
            SM_Failed_payment__r.Payment_Status__c,
            SM_Failed_payment__r.SM_Check_Collection_Status__c,
            SM_PTP_Montly__c,
            SM_FinalStatus__c,
            SM_Payment_Status__c,
            SM_Next_Transaction_Date__c,
            SM_Total__c,
            Total_Amount__c,
            CreatedDate
        FROM SM_ACH_Order__c
        WHERE SM_Contract__c = :c.Id 
          AND SM_Payment_Status__c NOT IN ('Canceled', 'Completed')
        ORDER BY CreatedDate ASC
    ];

    System.debug(' → ACH Orders encontrados: ' + achOrders.size());

    // ====================== LISTA PARA UPDATE ======================
    List<SM_ACH_Order__c> ordersToUpdate = new List<SM_ACH_Order__c>();

    // ====================== PRESENTACIÓN DE ORDERS ACTIVOS ======================
    for (SM_ACH_Order__c o : achOrders) {

        Datetime createdDT = DateTime.newInstance(
            o.CreatedDate.date(),
            Time.newInstance(0,0,0,0)
        );
        String createdFmt = createdDT.format('dd MMM yyyy');

        String nextTx = o.SM_Next_Transaction_Date__c != null ?
            DateTime.newInstance(o.SM_Next_Transaction_Date__c, Time.newInstance(0,0,0,0))
                    .format('dd MMM yyyy')
            : null;

        String line = '• ' + o.Name + '▫️' + o.SM_Payment_Type__c;

        if (o.SM_Original_Type__c != null)
            line += '/' + o.SM_Original_Type__c;

        if (o.SM_Payment_Status__c != null)
            line += ' ▫️' + o.SM_Payment_Status__c;

        if (o.SM_PTP_Montly__c != null)
            line += ' ▫️PTP: ' + o.SM_PTP_Montly__c;

        if (nextTx != null)
            line += ' ▫️NextTx: ' + nextTx;

        if (o.Total_Amount__c != null)
            line += ' ▫️$' + o.Total_Amount__c;

        if (o.SM_Failed_payment__c != null)
            line += ' ▫️FailedPayment: ' + o.SM_Failed_payment__r.Name +
                    ' (' 
                    //+ o.SM_Failed_payment__r.Payment_Status__c + '/'
                     + o.SM_Failed_payment__r.SM_Check_Collection_Status__c + ')';

        line += ' ▫️Created: ' + createdFmt;

        System.debug(' → ' + line);

        // ====================== LÓGICA DE ACTUALIZACIÓN (Late Payment Fee) ======================
        if (
            o.SM_Payment_Type__c == 'Late Payment Fee' &&
            o.SM_Failed_payment__c != null &&
            (
                o.SM_Failed_payment__r.SM_Check_Collection_Status__c == 'Collected' ||
                o.SM_Failed_payment__r.SM_Check_Collection_Status__c == 'Accepted'
            )
        ) {
            String oldStatus = o.SM_Payment_Status__c;
            o.SM_Payment_Status__c = 'Canceled';
            ordersToUpdate.add(o);

            System.debug(
                ' → AUDITORÍA: ACH Order ' + o.Id + 
                ' (' + o.Name + ') cambiado de ' + oldStatus + ' a CANCELED ' +
                '(Failed Payment Status: ' + o.SM_Failed_payment__r.SM_Check_Collection_Status__c + ')'
            );
        }
    }

    // ====================== UPDATE REAL ======================
    if (!ordersToUpdate.isEmpty()) {
        update ordersToUpdate;
        System.debug(' → AUDITORÍA: ' + ordersToUpdate.size() + ' ACH Orders actualizados en Salesforce.');
    }

    // ====================== CSV SECTION ======================
System.debug(' → ==================== ACH ORDERS PARA CSV ====================');
System.debug(' → Id,_Name,SM_PTP_Montly__c,SM_Payment_Status__c,SM_Next_Transaction_Date__c');

for (SM_ACH_Order__c o : achOrders) {

    Boolean incluirXCobrar = false;
    Boolean incluirXCancelar = false;

    if (o.SM_Failed_payment__c != null &&
        o.SM_Failed_payment__r.SM_Check_Collection_Status__c == 'NOT_COLLECTED' &&
        o.SM_Payment_Status__c == 'Stopped') {

        incluirXCobrar = true;
    }

    if (o.SM_Failed_payment__c != null &&
        o.SM_Payment_Status__c == 'Stopped' &&
        o.SM_Failed_payment__r.SM_Check_Collection_Status__c == 'COLLECTED') {

        incluirXCancelar = true;
    }

    // CORRECCIÓN: permitir cualquiera de los dos
    if (!(incluirXCobrar || incluirXCancelar)) continue;

    String statusFinal = incluirXCancelar ? 'CANCELED' : 'INITIATED';
    String fechaFinal = String.valueOf(hoy); // yyyy-MM-dd

    System.debug(
        ' → ' + o.Id + ',' +
        o.Name + ',' +
        o.SM_PTP_Montly__c + ',' +
        statusFinal + ',' +
        fechaFinal
    );
}

}
