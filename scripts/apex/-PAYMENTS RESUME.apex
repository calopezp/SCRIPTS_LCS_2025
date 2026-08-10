// ============================================================
// RESUMEN DE PAGOS
// ============================================================

String contractNumber = '00311753';


Decimal safeDecimal(Object v) {
    if (v == null) return null;
    String s = String.valueOf(v).trim();
    if (s == '') return null;
    return Decimal.valueOf(s);
}

Integer safeInteger(Object v) {
    if (v == null) return null;
    String s = String.valueOf(v).trim();
    if (s == '') return null;
    return Integer.valueOf(s);
}

Boolean safeGreaterThan(Object v, Decimal min) {
    Decimal d = safeDecimal(v);
    return d != null && d > min;
}



// ============================================================
// CONFIG
// ============================================================
String contractId     = '800XXXXXXXXXXXXXXX';

// ============================================================
// 1. LEER CONTRATO
// ============================================================
Contract contract = [
    SELECT Id, SM_Start_date__c, SM_Payment_day__c
    FROM   Contract
    WHERE  ContractNumber = :contractNumber
    LIMIT  1
];

if (contract == null) {
    System.debug('No contract found for ContractNumber: ' + contractNumber);
    return;
}

contractId = contract.Id;

Date    startDate  = contract.SM_Start_date__c;
Integer paymentDay = safeInteger(contract.SM_Payment_day__c) ?? 1;

System.debug(' → Start Date   : ' + startDate);
System.debug(' → Payment Day  : ' + paymentDay);


// ============================================================
// 2. CONSULTA DE PAGOS
// ============================================================
List<SM_Payment__c> payments = [
    SELECT  Id, Name,
            SM_Type__c, SM_Original_Type__c,
            Payment_Status__c, SM_Check_Collection_Status__c,
            SM_Payment_execution_date__c, SM_Date_ACH_Transmitted__c,
            SM_Net_Amount__c, SM_Fee_value__c,
            SM_Failed_payment__c, SM_Failed_payment__r.Name,
            SM_Payments_refunded__c, SM_Payments_refunded__r.Name,
            RecordType.Name,
            SM_Chargent_Orders_Transaction__r.ChargentOrders__Order__r.Discount_Value_Afer_Discount_IVU__c
    FROM    SM_Payment__c
    WHERE   SM_Contract__c = :contractId
      AND   Payment_Status__c != 'Canceled'
    ORDER BY SM_Payment_execution_date__c ASC NULLS LAST
];


// ============================================================
// 3. PROCESAR PAGOS
// ============================================================
Integer cumValid     = 0;
Integer cntRejected  = 0;
Integer cntRefunded  = 0;
Integer cntDescuento = 0;
Date    mesPagoActual = null;

String separator = ''.leftPad(150, '─');

System.debug(' → ' + separator);
System.debug(
    'Name'.rightPad(20) +
    'Type'.rightPad(12) +
    'OrigType'.rightPad(12) +
    'Status'.rightPad(15) +
    'NetAmount'.rightPad(12) +
    'Descuento'.rightPad(12) +
    'EsValido'.rightPad(10) +
    'MesPago'
);
System.debug(' → ' + separator);

for (SM_Payment__c p : payments) {

    Decimal discountValue = safeDecimal(
        p.SM_Chargent_Orders_Transaction__r
         ?.ChargentOrders__Order__r
         ?.Discount_Value_Afer_Discount_IVU__c
    ) ?? 0;

    Boolean tieneDescuento = discountValue > 0;

    if (p.Payment_Status__c == 'REJECTED') cntRejected++;

    if (p.Payment_Status__c == 'refunded') {
        cntRefunded++;
        if (cumValid > 0) cumValid--;
    }

    if (tieneDescuento && p.Payment_Status__c == 'ACCEPTED') {
        cntDescuento++;
    }

    Decimal netAmount = safeDecimal(p.SM_Net_Amount__c);

    // ============================================================
    // MANEJO SEGURO DE REFUNDS (evita Invalid id:)
    // ============================================================
    String refundedIds = p.SM_Payments_refunded__c == null
                         ? ''
                         : String.valueOf(p.SM_Payments_refunded__c).toLowerCase();

    String paymentId = String.valueOf(p.Id).toLowerCase();

    Boolean estaRefundado =
        refundedIds != '' &&
        refundedIds.contains(paymentId);

    // ============================================================
    // LÓGICA DE VALIDACIÓN
    // ============================================================
    Boolean esValido =
        p.SM_Original_Type__c != 'AC' &&
        p.SM_Type__c          != 'AC' &&
        p.Payment_Status__c   == 'ACCEPTED' &&
        netAmount             != null &&
        (tieneDescuento || netAmount >= 28) &&
        !estaRefundado;

    if (esValido) {
        cumValid++;
        if (startDate != null) {
            mesPagoActual = startDate.toStartOfMonth().addMonths(cumValid - 1);
        }
    }

    System.debug(
        String.valueOf(p.Name != null ? p.Name : '—').rightPad(20) +
        String.valueOf(p.SM_Type__c != null ? p.SM_Type__c : '—').rightPad(12) +
        String.valueOf(p.SM_Original_Type__c != null ? p.SM_Original_Type__c : '—').rightPad(12) +
        String.valueOf(p.Payment_Status__c != null ? p.Payment_Status__c : '—').rightPad(15) +
        String.valueOf(netAmount != null ? String.valueOf(netAmount) : '—').rightPad(12) +
        (tieneDescuento ? String.valueOf(discountValue) : '—').rightPad(12) +
        String.valueOf(esValido).rightPad(10) +
        (mesPagoActual != null ? String.valueOf(mesPagoActual) : '—')
    );
}


// ============================================================
// 4. RECALCULAR MES ABONADO TRAS REFUNDS
// ============================================================
mesPagoActual = (cumValid > 0 && startDate != null)
    ? startDate.toStartOfMonth().addMonths(cumValid - 1)
    : null;


// ============================================================
// 5. CALCULAR PRÓXIMO PAGO
// ============================================================
Date mesAbonado   = mesPagoActual;
Date mesSiguiente = mesAbonado != null
                    ? mesAbonado.addMonths(1)
                    : (startDate != null ? startDate.toStartOfMonth() : null);

Date proximoPago;
if (mesSiguiente != null) {
    Integer anioSig  = mesSiguiente.year();
    Integer mesSig   = mesSiguiente.month();
    Integer diaReal  = Math.min(paymentDay, Date.daysInMonth(anioSig, mesSig));
    proximoPago = Date.newInstance(anioSig, mesSig, diaReal);
} else {
    proximoPago = null;
}


// ============================================================
// 6. RESUMEN EJECUTIVO (CORREGIDO: sin NullPointer)
// ============================================================
System.debug(' → ');
System.debug(' → ══════════════════════════════════════════════════');
System.debug(' →   RESUMEN DEL CONTRATO');
System.debug(' → ══════════════════════════════════════════════════');
System.debug(' →   Primer cobro (Start Date) : ' + startDate);
System.debug(' →   Pagos ACCEPTED válidos    : ' + cumValid);
System.debug(' →   Pagos con descuento       : ' + cntDescuento);
System.debug(' →   Pagos REJECTED            : ' + cntRejected);
System.debug(' →   Pagos REFUNDED            : ' + cntRefunded + ' (-' + cntRefunded + ' mes/es)');

String abonadoHasta = (mesAbonado != null)
    ? Datetime.newInstance(mesAbonado, Time.newInstance(0, 0, 0, 0)).format('MMMM yyyy', UserInfo.getLocale())
    : 'Sin pagos válidos';

System.debug(' →   Cliente abonado hasta     : ' + abonadoHasta);
System.debug(' →   Próximo pago              : ' + proximoPago);
System.debug(' → ══════════════════════════════════════════════════');
