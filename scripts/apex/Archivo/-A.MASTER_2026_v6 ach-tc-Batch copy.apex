//#region Utilidades ====================== UTILIDADES DE LOG ======================    V 06 MAY

// Línea separadora
String line() {
    return '══════════════════════════════════════════════════════════════';
}

// Imprime un bloque de log formateado
void logBlock(String title, String content) {
    System.debug('\n .→ ' + line() 
                + '\n .→ ' + title 
                + '\n .→ ' + line()
                + '\n .→ ' + content
                 //+ '\n .→ ' + line()
    );
}

// Devuelve un icono si el booleano es true
String boolIcon(Boolean b, String icon) {
    return b ? icon + '\n .→ ' : '';
}

// Determina si un PTP pertenece a meses válidos
Boolean isPTP(String ptp) {
    if (ptp == null) return false;
    return ptp.contains('abril') ||
           ptp.contains('mayo') ||
           ptp.contains('junio') ||
           ptp.contains('julio') ||
           ptp.contains('agosto');
}


//#endregion Utilidades
// ====================== SCRIPT MULTI-CONTRATO OPTIMIZADO ======================
List<String> contractNumbers = new List<String>{
    '00264042','00275989','00303807','00308911','00312988','00314801','00315074','00315834','00316700','00316701','00316708','00317163'

}; 
Boolean confirmarActualizacion = true;
Date hoy = Date.today();

// ====================== LISTAS GLOBALES ======================
List<SM_ACH_Order__c> achToUpdate = new List<SM_ACH_Order__c>();
List<ChargentOrders__ChargentOrder__c> chargentToUpdate = new List<ChargentOrders__ChargentOrder__c>();
String globalCsv = 'ContractNumber,Id,Name,PTP,StatusFinal,FechaHoy\n';

Integer totalProcesados = 0;
Integer totalActualizados = 0;

// ====================== LOOP PRINCIPAL ======================
for (String contractNumber : contractNumbers) {

    Contract c = [
        SELECT Id, ContractNumber, Status, SM_Payment_methods__c,
               SM_Customer_Cancellation__c, SM_ContractMonitoring__c,
               SM_Start_date__c, SM_AC_start_date__c, SM_AC_Split_Date__c,
               SM_Plan_Months__c, SM_Payment_day__c, SM_Previous_Payment_day__c,
               Reasons_for_change__c, Count_Monthly_Payment_Pending__c,
               SM_Process_automation_by_product_family__r.Name,
               SM_Total_ac__c, SM_Monthly_offer__c,
               CB_Subscription__c,
               Is_VIP_Contract__c, Is_Test_Contract__c
        FROM Contract
        WHERE ContractNumber = :contractNumber
        LIMIT 1
    ];

    // ====================== LOG DEL CONTRATO ======================
    String sb = '';

    String dateAC = c.SM_AC_start_date__c != null ? DateTime.newInstance(c.SM_AC_start_date__c, Time.newInstance(0,0,0,0)).format('dd MMM yyyy') : 'N/A';
    String dateRC = c.SM_Start_date__c != null ? DateTime.newInstance(c.SM_Start_date__c, Time.newInstance(0,0,0,0)).format('dd MMM yyyy') : 'N/A';

    sb += 'Producto: ' + (c.SM_Process_automation_by_product_family__r != null ?
                          c.SM_Process_automation_by_product_family__r.Name : 'N/A') + ' (Plan Month : ' + c.SM_Plan_Months__c + ')\n';


    String paymentMethod =
        c.SM_Payment_methods__c == 'ACH' ? 'ACH 🏦' :
        (c.SM_Payment_methods__c == 'Credit Card' && c.CB_Subscription__c == null ? 'TC 💳' :
        (c.SM_Payment_methods__c == 'Credit Card' && c.CB_Subscription__c != null ? 'Chargebee ♨️' : 'N/A'));

    sb += ' .→ ' + paymentMethod + ' 🧾 ' + c.ContractNumber + ' ▫️ ' + c.Status + '\n';
    sb += ' .→ AC: ' + dateAC + '   RC: ' + dateRC + '\n';

    if (c.Count_Monthly_Payment_Pending__c > 1)
        sb += ' .→ 💰 Cuotas pendientes: ' + c.Count_Monthly_Payment_Pending__c + '\n';

    sb += boolIcon(c.SM_Customer_Cancellation__c, '🚨 Cancelación activa');
    sb += boolIcon(c.SM_ContractMonitoring__c, '⚠️ Monitoring activo');
    sb += boolIcon(c.Is_VIP_Contract__c, '⛔ VIP Contract');
    sb += boolIcon(c.Is_Test_Contract__c, '🤡 Test Contract');

    if (c.SM_AC_Split_Date__c != null && c.SM_AC_Split_Date__c >= hoy)
        sb += ' .→ 🔀 Split AC programado: ' + c.SM_AC_Split_Date__c + '\n';

    if (c.SM_Previous_Payment_day__c != null)
        sb += ' .→ Cambio de fecha de pago: ' + c.SM_Previous_Payment_day__c +
              ' => ' + c.SM_Payment_day__c +
              ' (Razón: ' + c.Reasons_for_change__c + ')\n';

    sb += ' .→ Total AC: $' + c.SM_Total_ac__c + ' ▫️ Total RC: $' + c.SM_Monthly_offer__c;

    logBlock('CONTRATO', sb);

    Boolean contratoElegible =
        (c.Status == 'Activated' || c.Status == 'Payment Process') &&
        !c.SM_Customer_Cancellation__c;

    Integer updatedThisContract = 0;

    //#region PAGOS ====================== PAGOS ======================
    Integer refunded = [
        SELECT COUNT() FROM SM_Payment__c
        WHERE SM_Contract__c = :c.Id
        AND Payment_Status__c IN ('REFUNDED','ACH PENDING REFUND','TRANSMITTED REFUND')
    ];

    Integer acceptedNonAC = [
        SELECT COUNT() FROM SM_Payment__c
        WHERE SM_Contract__c = :c.Id
        AND Payment_Status__c = 'ACCEPTED'
        AND SM_Type__c != 'AC'
        AND SM_Original_Type__c != 'AC'
    ];

    Integer pagosAC = [
        SELECT COUNT() FROM SM_Payment__c
        WHERE SM_Contract__c = :c.Id
        AND Payment_Status__c = 'ACCEPTED'
        AND (SM_Type__c = 'AC' OR SM_Original_Type__c = 'AC')
    ];

    String sp = '';
    sp += 'Pagos ACCEPTED AC: ' + pagosAC + '\n';
    sp += ' .→ Pagos ACCEPTED no AC: ' + acceptedNonAC + '\n';
    sp += refunded > 0 ? ' .→ Pagos REFUND: ' + refunded + '\n' : '';
    
    Integer pagosEnProceso = 0;
    Map<Id, Set<String>> achOrderToPaymentStatuses = new Map<Id, Set<String>>();
    
    //#region PAGOS_PENDIENTES_ACH
        if (c.SM_Payment_methods__c == 'ACH') {
           
            // ✅ Consultar Payments en proceso CON su ACH Order asociado
            List<SM_Payment__c> paymentsEnProceso = [
                SELECT Id, SM_ACH_Order__c, SM_Check_Collection_Status__c, Payment_Status__c
                FROM SM_Payment__c
                WHERE SM_Contract__c = :c.Id
                AND (
                    SM_Check_Collection_Status__c IN ('Pending', 'Return')
                    OR Payment_Status__c = 'ACH TRANSMITTED'
                )
            ];
            
            pagosEnProceso = paymentsEnProceso.size();
            
            // ✅ Mapear cada ACH Order con el Check Collection Status
            for(SM_Payment__c p : paymentsEnProceso) {
                if(p.SM_ACH_Order__c != null) {
                    if(!achOrderToPaymentStatuses.containsKey(p.SM_ACH_Order__c)) {
                        achOrderToPaymentStatuses.put(p.SM_ACH_Order__c, new Set<String>());
                    }
                    // Agregar el SM_Check_Collection_Status__c
                    if(p.SM_Check_Collection_Status__c != null) {
                        achOrderToPaymentStatuses.get(p.SM_ACH_Order__c).add(p.SM_Check_Collection_Status__c);
                    }
                    // Si es ACH TRANSMITTED, también agregarlo
                    if(p.Payment_Status__c == 'ACH TRANSMITTED') {
                        achOrderToPaymentStatuses.get(p.SM_ACH_Order__c).add('Transmitted');
                    }
                }
            }
            
            // Log detallado de pagos en proceso
            if (pagosEnProceso > 0) {
                sp += ' .→ 🔄 Pagos en proceso TOTAL: ' + pagosEnProceso + '\n';
                sp += '    • ACH Orders con Payments en proceso: ' + achOrderToPaymentStatuses.size() + '\n';
                
                Integer countReturn = 0, countPending = 0, countTRX = 0;
                for(SM_Payment__c p : paymentsEnProceso) {
                    if(p.SM_Check_Collection_Status__c == 'Return') countReturn++;
                    if(p.SM_Check_Collection_Status__c == 'Pending') countPending++;
                    if(p.Payment_Status__c == 'ACH TRANSMITTED') countTRX++;
                }
                
                if (countReturn > 0) sp += '    • Return: ' + countReturn + '\n';
                if (countPending > 0) sp += '    • Pending: ' + countPending + '\n';
                if (countTRX > 0) sp += '    • Transmitted: ' + countTRX + '\n';
            }
        }

        //#endregion PAGOS_PENDIENTES_ACH

    logBlock('PAGOS', sp);
    // #endregion PAGOS

        Integer cuotasContadas = acceptedNonAC + pagosEnProceso - Refunded;
        Date fechaSiguienteCobroCalc = c.SM_Start_date__c != null ? c.SM_Start_date__c.addMonths(cuotasContadas) : hoy;
        System.debug(' .→ 📆 Fecha estimada próximo cobro: ' + DateTime.newInstance(fechaSiguienteCobroCalc, Time.newInstance(0,0,0,0)).format('dd MMM yyyy') + ' (Pagos Aceptados + Pagos en Proceso - Pagos Refund)');  


    // #region ACH ====================== ACH ORDERS ======================
    if (c.SM_Payment_methods__c == 'ACH') {

        List<SM_ACH_Order__c> achOrders = [
            SELECT Id, Name, SM_Payment_Type__c, SM_Original_Type__c,
                   SM_Failed_payment__c, SM_Failed_payment__r.SM_Check_Collection_Status__c,
                   SM_Failed_payment__r.SM_Payment_Date__c,
                   SM_PTP_Montly__c, SM_Payment_Status__c,
                   SM_Next_Transaction_Date__c, Total_Amount__c,
                   CreatedDate
            FROM SM_ACH_Order__c
            WHERE SM_Contract__c = :c.Id
            AND SM_Payment_Status__c NOT IN ('Canceled','Completed')
            ORDER BY CreatedDate ASC
        ];

        String sa = '';
        sa += ' .→ ACH activos: ' + achOrders.size() + '\n\n';

        for (SM_ACH_Order__c o : achOrders) {

            sa += '\n .→ • ' + o.Name + ' ▫️ ' + o.SM_Payment_Type__c +
                  ' ▫️ ' + o.SM_Payment_Status__c ;

            Boolean isLateFee = o.SM_Payment_Type__c == 'Late Payment Fee';
            String failedStatus = o.SM_Failed_payment__r != null ?
                                  o.SM_Failed_payment__r.SM_Check_Collection_Status__c : null;

            // Cancelar
            if (isLateFee && (failedStatus == 'Collected' || failedStatus == 'Accepted')) {
                o.SM_Payment_Status__c = 'Canceled';
                o.SM_Next_Transaction_Date__c = null;
                achToUpdate.add(o);
                sa += ' => Canceled'
                        + ' ▫️ ' + o.SM_PTP_Montly__c
                        + ' ▫️ ' + o.SM_Next_Transaction_Date__c 
                        + ' ▫️ $' + o.Total_Amount__c
                        + '\n';
                updatedThisContract++;
                continue;
            }

            // Iniciar
            if (isLateFee && contratoElegible && failedStatus == 'Not_Collected') {
                
                // ✅ VALIDACIÓN: Verificar si ESTE ACH específico tiene Payments en proceso
                Boolean esteACHTienePaymentsEnProceso = achOrderToPaymentStatuses.containsKey(o.Id);
                
                // Solo bloquear si NO está en Initiated Y este ACH tiene Payments en proceso
                if (o.SM_Payment_Status__c != 'Initiated' && esteACHTienePaymentsEnProceso) {
                    Set<String> estadosPayments = achOrderToPaymentStatuses.get(o.Id);
                    sa += ' => ⚠️ BLOQUEADO (Check Collection Status: ' + String.join(new List<String>(estadosPayments), ', ') + ')'
                        + ' ▫️ ' + o.SM_PTP_Montly__c
                        + ' ▫️ ' + (o.SM_Next_Transaction_Date__c != null ? DateTime.newInstance(o.SM_Next_Transaction_Date__c, Time.newInstance(0,0,0,0)).format('dd MMM yyyy') : 'N/A')
                        + ' ▫️ $' + o.Total_Amount__c
                        + '\n';
                    continue;  // NO actualizar
                }
                
                // Si ya está Initiated, no hacer nada (skip sin bloquear)
                if (o.SM_Payment_Status__c == 'Initiated') {
                    sa += ' ▫️ ' + o.SM_PTP_Montly__c
                        + ' ▫️ ' + (o.SM_Next_Transaction_Date__c != null ? DateTime.newInstance(o.SM_Next_Transaction_Date__c, Time.newInstance(0,0,0,0)).format('dd MMM yyyy') : 'N/A')
                        + ' ▫️ $' + o.Total_Amount__c
                        + (esteACHTienePaymentsEnProceso ? ' (Ya Initiated - tiene Payments en proceso)' : ' (Ya Initiated)') + '\n';
                    continue;
                }
                
                o.SM_Payment_Status__c = 'Initiated';
                o.SM_Next_Transaction_Date__c = hoy;
                o.SM_PTP_Montly__c = o.SM_Failed_payment__r.SM_Payment_Date__c != null ?
                    DateTime.newInstance(o.SM_Failed_payment__r.SM_Payment_Date__c, Time.newInstance(0,0,0,0)).format('MMM')
                    : null;

                achToUpdate.add(o);
                    sa += ' => Initiated'
                        + ' ▫️ ' + o.SM_PTP_Montly__c
                        + ' ▫️ ' + DateTime.newInstance(o.SM_Next_Transaction_Date__c, Time.newInstance(0,0,0,0)).format('dd MMM YYYY') 
                        + ' ▫️ $' + o.Total_Amount__c
                        + '\n';  
                updatedThisContract++;
                continue;
            }

            // PTP
            if (o.SM_Failed_payment__c != null && o.SM_Payment_Status__c == 'Stopped') {

                Boolean cobrar = failedStatus == 'Not_Collected' && isPTP(o.SM_PTP_Montly__c);
                Boolean cancelar = (failedStatus == 'Collected' || failedStatus == 'Accepted');

                if (cobrar || cancelar) {
                    String finalStatus = cancelar ? 'Canceled' : 'Initiated';

                    // ✅ VALIDACIÓN: Verificar si ESTE ACH específico tiene Payments en proceso
                    Boolean esteACHTienePaymentsEnProceso = achOrderToPaymentStatuses.containsKey(o.Id);
                    
                    // Solo bloquear cambio de Stopped a Initiated si ESTE ACH tiene Payments en proceso
                    if (finalStatus == 'Initiated' && esteACHTienePaymentsEnProceso) {
                        Set<String> estadosPayments = achOrderToPaymentStatuses.get(o.Id);
                        sa += ' => ⚠️ BLOQUEADO (Check Collection Status: ' + String.join(new List<String>(estadosPayments), ', ') + ')'
                            + ' ▫️ ' + o.SM_PTP_Montly__c
                            + ' ▫️ ' + (o.SM_Next_Transaction_Date__c != null ? DateTime.newInstance(o.SM_Next_Transaction_Date__c, Time.newInstance(0,0,0,0)).format('MMM') : 'N/A')
                            + ' ▫️ $' + o.Total_Amount__c
                            + '\n';
                        continue;  // NO actualizar
                    }

                    o.SM_Payment_Status__c = finalStatus;
                    o.SM_Next_Transaction_Date__c = hoy;

                    achToUpdate.add(o);
                         sa += ' => ' + finalStatus
                        + ' ▫️ ' + o.SM_PTP_Montly__c
                        + ' ▫️ ' + DateTime.newInstance(o.SM_Next_Transaction_Date__c, Time.newInstance(0,0,0,0)).format('MMM') 
                        + ' ▫️ $' + o.Total_Amount__c
                        + '\n';  

                    updatedThisContract++;

                    globalCsv += c.ContractNumber + ',' + o.Id + ',' + o.Name + ',' +
                                 (o.SM_PTP_Montly__c != null ? o.SM_PTP_Montly__c : '') + ',' +
                                 finalStatus + ',' + hoy + '\n';
                }
            }
        }

        logBlock(' .→ ACH ORDERS (UPD)', sa);
    }
    // #endregion ACH
    // #region CHARGENT ====================== CHARGENT ======================
    if (c.SM_Payment_methods__c == 'Credit Card' && c.CB_Subscription__c == null) {

        List<ChargentOrders__ChargentOrder__c> coList = [
            SELECT Id, Name, SM_Payment_Type__c, SM_Failed_payment__c,
                   SM_Failed_payment__r.Payment_Status__c,
                   SM_Failed_payment__r.SM_Check_Collection_Status__c,
                   SM_Failed_payment__r.SM_Payment_Date__c,
                   SM_PTP_Montly__c, ChargentOrders__Payment_Status__c,
                   ChargentOrders__Next_Transaction_Date__c,
                   ChargentOrders__Total__c
            FROM ChargentOrders__ChargentOrder__c
            WHERE Contract__c = :c.Id
            AND ChargentOrders__Payment_Status__c IN ('Recurring','Stopped')
            ORDER BY Name ASC
        ];

        String sc = '';
        sc += 'Chargent activos: ' + coList.size() + '\n\n';

        for (ChargentOrders__ChargentOrder__c co : coList) {

            sc += ' .→ • ' + co.Name + 
                    ' ▫️ ' + (co.SM_PTP_Montly__c != null ? co.SM_PTP_Montly__c : '   ') +
                    ' ▫️ ' + (co.SM_Payment_Type__c == 'Subscription' ? co.SM_Payment_Type__c +  '    ' : co.SM_Payment_Type__c) +
                    ' ▫️ ' + co.ChargentOrders__Payment_Status__c +
                    ' ▫️ ' + (co.ChargentOrders__Next_Transaction_Date__c != null ?  DateTime.newInstance(co.ChargentOrders__Next_Transaction_Date__c, Time.newInstance(0,0,0,0)).format('dd MMM yyyy') : 'N/A') +
                    ' ▫️ $' + co.ChargentOrders__Total__c + '\n';

            Boolean isLateFee = co.SM_Payment_Type__c == 'Late Payment Fee';
            String failedStatus = co.SM_Failed_payment__r != null ?
                                  co.SM_Failed_payment__r.Payment_Status__c : null;

            // Cancelar
            if (isLateFee && (failedStatus == 'Collected' || failedStatus == 'Accepted')) {
                co.ChargentOrders__Payment_Status__c = 'Canceled';
                chargentToUpdate.add(co);
                updatedThisContract++;
                continue;
            }

            // Iniciar
            if (isLateFee && contratoElegible && failedStatus == 'REJECTED') {
                co.ChargentOrders__Payment_Status__c = 'Recurring';
                co.ChargentOrders__Next_Transaction_Date__c = hoy;
                co.SM_PTP_Montly__c = co.SM_Failed_payment__r.SM_Payment_Date__c != null ?
                    DateTime.newInstance(co.SM_Failed_payment__r.SM_Payment_Date__c, Time.newInstance(0,0,0,0)).format('MMM')
                     : null;

                chargentToUpdate.add(co);
                updatedThisContract++;
                continue;
            }

            // PTP
            if (co.SM_Failed_payment__c != null && co.ChargentOrders__Payment_Status__c == 'Stopped') {

                Boolean cobrar = failedStatus == 'REJECTED' && isPTP(co.SM_PTP_Montly__c);
                Boolean cancelar = (failedStatus == 'Collected' || failedStatus == 'Accepted');

                if (cobrar || cancelar) {
                    String finalStatus = cancelar ? 'Canceled' : 'Recurring';

                    co.ChargentOrders__Payment_Status__c = finalStatus;
                    co.ChargentOrders__Next_Transaction_Date__c = hoy;

                    chargentToUpdate.add(co);
                    updatedThisContract++;

                    globalCsv += c.ContractNumber + ',' + co.Id + ',' + co.Name + ',' +
                                 (co.SM_PTP_Montly__c != null ? co.SM_PTP_Montly__c : '') + ',' +
                                 finalStatus + ',' + hoy + '\n';
                }
            }
        }

        logBlock('CHARGENT ORDERS', sc);
    }
    // #endregion CHARGENT
    // #region CHARGEBEE ==================== CHARGEBEE ======================
    if (c.SM_Payment_methods__c == 'Credit Card' && c.CB_Subscription__c != null) {

        List<chargebeeapps__CB_Subscription__c> cbList = [
            SELECT Id, chargebeeapps__Subscription_status__c,
                   chargebeeapps__Next_billing__c,
                   chargebeeapps__Plan_Unit_Price__c,
                   chargebeeapps__Subscription_Plan__r.Name
            FROM chargebeeapps__CB_Subscription__c
            WHERE Contract__c = :c.Id
        ];

        String sbCB = '';
        sbCB += ' .→ Chargebee activos: ' + cbList.size() + '\n\n';

        for (chargebeeapps__CB_Subscription__c cb : cbList) {
            sbCB += ' .→ • ' + cb.Id +
                    ' ▫️ ' + cb.chargebeeapps__Subscription_status__c +
                    ' ▫️ Next: ' + cb.chargebeeapps__Next_billing__c +
                    ' ▫️ $' + cb.chargebeeapps__Plan_Unit_Price__c + '\n';
        }

        logBlock(' .→ CHARGEBEE', sbCB);
    }
    // #endregion CHARGEBEE

    totalProcesados++;
    totalActualizados += updatedThisContract;

    logBlock('RESUMEN CONTRATO', 'Órdenes actualizadas: ' + updatedThisContract);
}

// ====================== DML FINAL ======================
String sf = '';
sf += ' .→ Contratos procesados: ' + totalProcesados + '\n';
sf += ' .→ ACH a actualizar: ' + achToUpdate.size() + '\n';
sf += ' .→ Chargent a actualizar: ' + chargentToUpdate.size() + '\n';
sf += '\n .→ CSV:\n' + globalCsv;

logBlock('RESUMEN FINAL', sf);

if (confirmarActualizacion) {
    update achToUpdate;
    update chargentToUpdate;
    System.debug(' .→ ✔️ Actualización completada.');
} else {
    System.debug(' .→ ⚠️ MODO SEGURO: No se ejecutó ningún update.');
}
