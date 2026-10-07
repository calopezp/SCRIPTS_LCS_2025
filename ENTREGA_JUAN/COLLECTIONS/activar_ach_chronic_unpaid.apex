/*
 * activar_ach_chronic_unpaid.apex
 * -----------------------------------
 * Reemplaza a notify_ach_chronic_unpaid.apex (detector de solo-reporte,
 * 2026-10-04) -- hace lo mismo mas la validacion y activacion pedida por
 * el usuario el mismo dia. Corre a diario como parte de run_daily_new_files.sh,
 * no es un script de una sola corrida.
 *
 * Por cada contrato ACH con 3+ CUOTAS mensuales rechazadas y nunca recobradas:
 *
 *   0. AGRUPACION POR CUOTA (fix 2026-10-05): los Fee se agrupan en cuotas --
 *      dos Fee con menos de DIAS_MISMA_CUOTA dias entre si son la MISMA cuota
 *      (reintento/fecha movida a mano), no dos meses distintos. Una cuota es:
 *        PAGADA      -> algun Fee ACCEPTED
 *        EN_TRANSITO -> algun Fee ACH PENDING/ACH TRANSMITTED, o con
 *                       SM_Check_Collection_Status__c PENDING/RETURN
 *        FALLIDA     -> Fee REJECTED/NOT_COLLECTED por el monto mensual exacto
 *        OTRA        -> cualquier otra combinacion (cuenta como generada, no como deuda)
 *      Antes se contaban PAGOS rechazados: un mes con 2 intentos contaba como
 *      2 meses debidos (casos 00317543 y 00317167, LPF de mas cobrados).
 *   1. VALIDACION POR CONTEO: cuotas vencidas a hoy (desde SM_Start_date__c,
 *      con SM_Payment_day__c) deben cuadrar con las cuotas generadas.
 *      Diferencia aceptada: 0, -1 (la proxima cuota ya se genero antes de su
 *      vencimiento), o +1 solo si la ultima cuota vencio hace <= DIAS_GRACIA_CUOTA
 *      dias (todavia no se genera). Cualquier otra cosa -> revision manual, y si
 *      hay un mes sin NINGUNA cuota generada (>45 dias entre cuotas) se indica
 *      cual. Caso real 2026-10-05: 13 contratos sin cuota de agosto 2026 (ej.
 *      00316426, 00315074) -- la tolerancia +-1 anterior los escondia.
 *   2. Se excluyen (solo se reportan, nunca se activan):
 *        - SM_Customer_Cancellation__c = true
 *        - algun Late payment fee EN TRANSITO (ACH PENDING/ACH TRANSMITTED o
 *          Check Collection PENDING/RETURN) -- el banco todavia puede cobrarlo;
 *          reactivar su orden genera un cobro duplicado (caso real 00316366,
 *          2026-10-05: 4 LPF del 23-sep en PENDING + 4 nuevos generados por
 *          este script). Si pasaron mas de 26 dias, se avisa (Rule 3) pero NO
 *          se aplica sola -- es decision del usuario.
 *        - alguna orden Late payment fee ya activa (Pending/Initiated)
 *        - sin orden de cuota (Subscription/Fee) activa -- si la suscripcion
 *          esta Stopped/Canceled alguien la paro a proposito (caso 00317167)
 *   3. Si pasa todo: se activan las SM_ACH_Order__c "Late payment fee"
 *      Stopped (-> 'Pending', SM_Next_Transaction_Date__c = PROXIMO DIA HABIL)
 *      solo si la cantidad de Stopped coincide EXACTO con las cuotas debidas.
 *      Cada orden activada queda marcada en SM_Id_Salesforce_LCS__c.
 *
 * Caso real que lo origino: contrato 00316426, 5 meses sin cobrar, cuenta
 * cerrada (R02), 5 ordenes Late payment fee Stopped que coincidian
 * exactamente con los 5 meses -- ver BITACORA_HALLAZGOS_TECNICOS.md 2026-10-04.
 *
 * MODO DE USO:
 *   - Corre primero con DRY_RUN = true -> solo preview, NO escribe ni envia nada.
 *   - Si todo esta correcto, cambia DRY_RUN a false y corre de nuevo.
 *   (run_daily_new_files.sh apply lo cambia a false en una copia temporal.)
 */

Boolean DRY_RUN = true; // <-- cambiar a false para activar + enviar correo real
String NOTIFY_EMAIL = 'clopez@legal-credit.com';
Integer MESES_MINIMO = 3;
Integer DIAS_MISMA_CUOTA = 20;
Integer DIAS_GRACIA_CUOTA = 3;
Integer DIAS_RULE3 = 26;
String PROCESO = 'activar_ach_chronic_unpaid';

Date proximoDiaHabil(Date d) {
    DateTime dt = DateTime.newInstanceGMT(d, Time.newInstance(12, 0, 0, 0));
    String nombreDia = dt.format('EEEE');
    Integer diasASumar = 1;
    if (nombreDia == 'Friday') { diasASumar = 3; }
    else if (nombreDia == 'Saturday') { diasASumar = 2; }
    return d.addDays(diasASumar);
}
Date FECHA_ACTIVACION = proximoDiaHabil(Date.today());
Date hoy = Date.today();

Boolean enTransito(SM_Payment__c p) {
    return p.Payment_Status__c == 'ACH PENDING' || p.Payment_Status__c == 'ACH TRANSMITTED'
        || p.SM_Check_Collection_Status__c == 'PENDING' || p.SM_Check_Collection_Status__c == 'RETURN';
}

// =========================================================================
// 1) Candidatos (pre-filtro bruto por PAGOS; el conteo real por cuota va en 3)
// =========================================================================
Set<Id> candidatoIds = new Set<Id>();
for (AggregateResult ar : [
    SELECT SM_Contract__c cId
    FROM SM_Payment__c
    WHERE SM_Type__c = 'Fee'
    AND Payment_Status__c = 'REJECTED'
    AND SM_Check_Collection_Status__c = 'NOT_COLLECTED'
    AND SM_Contract__r.SM_Payment_methods__c = 'ACH'
    AND SM_Contract__r.Status IN ('Activated', 'Payment Process')
    AND SM_Contract__r.Is_Test_Contract__c = false
    AND SM_Contract__r.Is_VIP_Contract__c = false
    GROUP BY SM_Contract__c
    HAVING COUNT(Id) >= :MESES_MINIMO
]) {
    candidatoIds.add((Id) ar.get('cId'));
}

System.debug('→ Candidatos (conteo bruto de pagos >= ' + MESES_MINIMO + '): ' + candidatoIds.size());

if (candidatoIds.isEmpty()) {
    System.debug('→ Sin candidatos -- no se envia correo.');
    return;
}

Map<Id, Contract> contratosById = new Map<Id, Contract>([
    SELECT Id, ContractNumber, Account.Name, SM_Monthly_offer__c,
           SM_Customer_Cancellation__c, SM_Start_date__c, SM_Payment_day__c
    FROM Contract
    WHERE Id IN :candidatoIds
]);

// Todos los Fee que representan un intento real de cuota (sin refunds/cancelados)
Map<Id, List<SM_Payment__c>> feesByContract = new Map<Id, List<SM_Payment__c>>();
for (SM_Payment__c p : [
    SELECT SM_Contract__c, Name, SM_Payment_Date__c, SM_Amount__c,
           Payment_Status__c, SM_Check_Collection_Status__c
    FROM SM_Payment__c
    WHERE SM_Contract__c IN :candidatoIds
    AND SM_Type__c = 'Fee'
    AND Payment_Status__c IN ('ACCEPTED', 'REJECTED', 'ACH PENDING', 'ACH TRANSMITTED')
    AND SM_Payment_Date__c != null
    ORDER BY SM_Contract__c, SM_Payment_Date__c ASC
]) {
    if (!feesByContract.containsKey(p.SM_Contract__c)) {
        feesByContract.put(p.SM_Contract__c, new List<SM_Payment__c>());
    }
    feesByContract.get(p.SM_Contract__c).add(p);
}

// Late payment fee: cobrados (recuperan una cuota) y en transito (bloquean)
Map<Id, Integer> recoveredByContract = new Map<Id, Integer>();
Map<Id, List<String>> lpfTransitoByContract = new Map<Id, List<String>>();
for (SM_Payment__c p : [
    SELECT SM_Contract__c, Name, SM_Amount__c, Payment_Status__c, SM_Check_Collection_Status__c,
           SM_Transmission_Date_ACH_File__c, SM_ACH_Order__r.Name
    FROM SM_Payment__c
    WHERE SM_Contract__c IN :candidatoIds
    AND SM_Type__c = 'Late payment fee'
    AND (Payment_Status__c IN ('ACCEPTED', 'ACH PENDING', 'ACH TRANSMITTED')
         OR SM_Check_Collection_Status__c IN ('PENDING', 'RETURN'))
]) {
    if (p.Payment_Status__c == 'ACCEPTED') {
        Integer n = recoveredByContract.containsKey(p.SM_Contract__c) ? recoveredByContract.get(p.SM_Contract__c) : 0;
        recoveredByContract.put(p.SM_Contract__c, n + 1);
        continue;
    }
    if (!enTransito(p)) { continue; }
    Integer dias = p.SM_Transmission_Date_ACH_File__c == null ? null : p.SM_Transmission_Date_ACH_File__c.daysBetween(hoy);
    String estado = p.Payment_Status__c + (p.SM_Check_Collection_Status__c == null ? '' : '/' + p.SM_Check_Collection_Status__c);
    String det = p.Name + ' (' + (p.SM_ACH_Order__r == null ? '?' : p.SM_ACH_Order__r.Name) + ', $' + p.SM_Amount__c +
        ', ' + estado + ', ' + (dias == null ? 'sin transmitir' : dias + ' dias desde transmision') +
        (dias != null && dias > DIAS_RULE3 ? ' -- >26 dias, Rule 3: revisar si ya es NOT_COLLECTED' : '') + ')';
    if (!lpfTransitoByContract.containsKey(p.SM_Contract__c)) {
        lpfTransitoByContract.put(p.SM_Contract__c, new List<String>());
    }
    lpfTransitoByContract.get(p.SM_Contract__c).add(det);
}

Map<Id, List<SM_ACH_Order__c>> lpfOrdersByContract = new Map<Id, List<SM_ACH_Order__c>>();
Set<Id> conOrdenCuotaActiva = new Set<Id>();
Map<Id, List<String>> ordenesCuotaByContract = new Map<Id, List<String>>();
for (SM_ACH_Order__c o : [
    SELECT Id, Name, SM_Contract__c, SM_Payment_Type__c, SM_Payment_Status__c, SM_Total__c,
           SM_Id_Salesforce_LCS__c, CreatedDate
    FROM SM_ACH_Order__c
    WHERE SM_Contract__c IN :candidatoIds
    AND SM_Payment_Type__c IN ('Late payment fee', 'Subscription', 'Fee')
    ORDER BY CreatedDate ASC
]) {
    if (o.SM_Payment_Type__c == 'Late payment fee') {
        if (!lpfOrdersByContract.containsKey(o.SM_Contract__c)) {
            lpfOrdersByContract.put(o.SM_Contract__c, new List<SM_ACH_Order__c>());
        }
        lpfOrdersByContract.get(o.SM_Contract__c).add(o);
    } else {
        if (o.SM_Payment_Status__c == 'Pending' || o.SM_Payment_Status__c == 'Initiated') {
            conOrdenCuotaActiva.add(o.SM_Contract__c);
        }
        if (!ordenesCuotaByContract.containsKey(o.SM_Contract__c)) {
            ordenesCuotaByContract.put(o.SM_Contract__c, new List<String>());
        }
        ordenesCuotaByContract.get(o.SM_Contract__c).add(o.Name + ' ' + o.SM_Payment_Type__c + ' ' + o.SM_Payment_Status__c);
    }
}

// =========================================================================
// 2) Cuotas vencidas a hoy (fechas exactas, no "meses transcurridos")
// =========================================================================
Date fechaCuota(Integer anio, Integer mes, Integer dia) {
    Integer maxDia = Date.daysInMonth(anio, mes);
    return Date.newInstance(anio, mes, dia > maxDia ? maxDia : dia);
}

// =========================================================================
// 3) Clasificar cada candidato
// =========================================================================
List<String> aActivar = new List<String>();
List<String> excluidosCancelacion = new List<String>();
List<String> excluidosLpfTransito = new List<String>();
List<String> excluidosOtros = new List<String>();
List<String> revisarManualConteo = new List<String>();
List<String> revisarManualOrdenes = new List<String>();
Map<Id, List<SM_ACH_Order__c>> ordenesAActivarPorContrato = new Map<Id, List<SM_ACH_Order__c>>();
Integer descartadosPorAgrupacion = 0;

for (Id contractId : candidatoIds) {
    Contract cont = contratosById.get(contractId);
    String etiqueta = cont.ContractNumber + ' (' + cont.Account.Name + ')';
    Decimal monthlyOffer = cont.SM_Monthly_offer__c;
    if (monthlyOffer == null || cont.SM_Start_date__c == null) {
        revisarManualConteo.add(etiqueta + ' -- falta SM_Monthly_offer__c o SM_Start_date__c');
        continue;
    }

    // --- 3a) Agrupar Fee en cuotas ---
    Integer pagadas = 0, fallidas = 0, transito = 0, otras = 0, intentosDuplicados = 0;
    List<SM_Payment__c> fees = feesByContract.containsKey(contractId) ? feesByContract.get(contractId) : new List<SM_Payment__c>();
    List<String> huecos = new List<String>();
    Date anclaAnterior = null;
    Integer i = 0;
    while (i < fees.size()) {
        Date ancla = fees[i].SM_Payment_Date__c;
        // Hueco: mas de ~1.5 meses entre dos cuotas seguidas = un mes sin ninguna cuota generada
        if (anclaAnterior != null && anclaAnterior.daysBetween(ancla) > 45) {
            huecos.add('sin cuota generada entre ' + anclaAnterior.format() + ' y ' + ancla.format());
        }
        anclaAnterior = ancla;
        Boolean hayPagado = false, hayTransito = false, hayFallido = false;
        Integer j = i;
        while (j < fees.size() && ancla.daysBetween(fees[j].SM_Payment_Date__c) < DIAS_MISMA_CUOTA) {
            SM_Payment__c p = fees[j];
            if (p.Payment_Status__c == 'ACCEPTED') { hayPagado = true; }
            else if (enTransito(p)) { hayTransito = true; }
            else if (p.Payment_Status__c == 'REJECTED' && p.SM_Check_Collection_Status__c == 'NOT_COLLECTED'
                     && p.SM_Amount__c == monthlyOffer) { hayFallido = true; }
            j++;
        }
        intentosDuplicados += (j - i - 1);
        if (hayPagado) { pagadas++; }
        else if (hayTransito) { transito++; }
        else if (hayFallido) { fallidas++; }
        else { otras++; }
        i = j;
    }

    Integer recoveredCnt = recoveredByContract.containsKey(contractId) ? recoveredByContract.get(contractId) : 0;
    Integer stillOwed = fallidas - recoveredCnt;
    if (stillOwed < MESES_MINIMO) {
        descartadosPorAgrupacion++;
        System.debug('DESCARTADO -> ' + etiqueta + ' -- cuotas fallidas:' + fallidas + ' recobradas:' + recoveredCnt +
            ' intentos duplicados agrupados:' + intentosDuplicados + ' (debe < ' + MESES_MINIMO + ')');
        continue;
    }

    // --- 3b) Cuotas vencidas vs generadas ---
    Integer diaPago = cont.SM_Payment_day__c != null ? Integer.valueOf(cont.SM_Payment_day__c) : cont.SM_Start_date__c.day();
    Integer vencidas = 0;
    Date ultimaVencida = null;
    Date d = fechaCuota(cont.SM_Start_date__c.year(), cont.SM_Start_date__c.month(), diaPago);
    if (d < cont.SM_Start_date__c) {
        Date sig = cont.SM_Start_date__c.addMonths(1);
        d = fechaCuota(sig.year(), sig.month(), diaPago);
    }
    while (d <= hoy) {
        vencidas++;
        ultimaVencida = d;
        Date sig = Date.newInstance(d.year(), d.month(), 1).addMonths(1);
        d = fechaCuota(sig.year(), sig.month(), diaPago);
    }
    Integer generadas = pagadas + fallidas + transito + otras;
    Integer diferencia = vencidas - generadas;

    String etiquetaConteo = etiqueta + ' -- cuotas vencidas:' + vencidas + ' generadas:' + generadas +
        ' (pagadas:' + pagadas + ' fallidas:' + fallidas + ' en transito:' + transito + ' otras:' + otras +
        ') recobradas por LPF:' + recoveredCnt + ' debe:' + stillOwed +
        (intentosDuplicados > 0 ? ' [' + intentosDuplicados + ' intento(s) duplicado(s) agrupado(s)]' : '');

    Boolean conteoOk = diferencia == 0 || diferencia == -1
        || (diferencia == 1 && ultimaVencida != null && ultimaVencida.daysBetween(hoy) <= DIAS_GRACIA_CUOTA);
    if (!conteoOk) {
        revisarManualConteo.add(etiquetaConteo + ' dif:' + diferencia +
            (huecos.isEmpty() ? '' : ' -- HUECO: ' + String.join(huecos, '; ')));
        continue;
    }

    // --- 3c) Exclusiones ---
    if (cont.SM_Customer_Cancellation__c == true) {
        excluidosCancelacion.add(etiqueta + ' -- debe ' + stillOwed +
            ' cuota(s), SM_Customer_Cancellation__c=true, NO se activa');
        continue;
    }
    if (lpfTransitoByContract.containsKey(contractId)) {
        excluidosLpfTransito.add(etiqueta + ' -- debe ' + stillOwed + ' cuota(s), NO se activa: LPF en transito: ' +
            String.join(lpfTransitoByContract.get(contractId), '; '));
        continue;
    }
    List<SM_ACH_Order__c> todasLasOrdenes = lpfOrdersByContract.containsKey(contractId)
        ? lpfOrdersByContract.get(contractId) : new List<SM_ACH_Order__c>();
    List<SM_ACH_Order__c> ordenesStopped = new List<SM_ACH_Order__c>();
    List<String> ordenesActivas = new List<String>();
    for (SM_ACH_Order__c o : todasLasOrdenes) {
        if (o.SM_Payment_Status__c == 'Stopped') { ordenesStopped.add(o); }
        else if (o.SM_Payment_Status__c == 'Pending' || o.SM_Payment_Status__c == 'Initiated') {
            ordenesActivas.add(o.Name + ' ' + o.SM_Payment_Status__c);
        }
    }
    if (!ordenesActivas.isEmpty()) {
        excluidosOtros.add(etiqueta + ' -- ya hay Late payment fee activa(s): ' + String.join(ordenesActivas, ', '));
        continue;
    }
    if (!conOrdenCuotaActiva.contains(contractId)) {
        excluidosOtros.add(etiqueta + ' -- sin orden de cuota activa (' +
            (ordenesCuotaByContract.containsKey(contractId) ? String.join(ordenesCuotaByContract.get(contractId), ', ') : 'ninguna') +
            '), alguien la paro -- revisar antes de recobrar');
        continue;
    }

    // --- 3d) Ordenes Stopped deben coincidir exacto con cuotas debidas ---
    if (ordenesStopped.size() != stillOwed) {
        revisarManualOrdenes.add(etiquetaConteo + ' -- pero tiene ' + ordenesStopped.size() + ' orden(es) Stopped (' +
            todasLasOrdenes.size() + ' Late payment fee en total de cualquier estado)');
        continue;
    }

    ordenesAActivarPorContrato.put(contractId, ordenesStopped);
    List<String> nombres = new List<String>();
    Decimal total = 0;
    for (SM_ACH_Order__c o : ordenesStopped) {
        nombres.add(o.Name);
        total += o.SM_Total__c == null ? 0 : o.SM_Total__c;
    }
    aActivar.add(etiquetaConteo + ' -- ' + ordenesStopped.size() + ' orden(es) Stopped -> Pending (' +
        String.join(nombres, ', ') + '), proxima transaccion ' + FECHA_ACTIVACION.format() + ' ($' + total.setScale(0) + ' total)');
}

System.debug('→ Activar: ' + aActivar.size() + ' | Excluidos (Cancellation): ' + excluidosCancelacion.size() +
    ' | Excluidos (LPF en transito): ' + excluidosLpfTransito.size() + ' | Excluidos (otros): ' + excluidosOtros.size() +
    ' | Revisar (conteo): ' + revisarManualConteo.size() + ' | Revisar (ordenes): ' + revisarManualOrdenes.size() +
    ' | Descartados (< ' + MESES_MINIMO + ' cuotas al agrupar): ' + descartadosPorAgrupacion);
for (String s : aActivar) { System.debug('ACTIVAR -> ' + s); }
for (String s : excluidosCancelacion) { System.debug('EXCLUIDO_CANCEL -> ' + s); }
for (String s : excluidosLpfTransito) { System.debug('EXCLUIDO_LPF_TRANSITO -> ' + s); }
for (String s : excluidosOtros) { System.debug('EXCLUIDO_OTRO -> ' + s); }
for (String s : revisarManualConteo) { System.debug('REVISAR_CONTEO -> ' + s); }
for (String s : revisarManualOrdenes) { System.debug('REVISAR_ORDENES -> ' + s); }

// =========================================================================
// 4) Ejecutar + enviar correo (solo si DRY_RUN = false)
// =========================================================================
if (!DRY_RUN) {
    List<SM_ACH_Order__c> toUpdate = new List<SM_ACH_Order__c>();
    for (Id contractId : ordenesAActivarPorContrato.keySet()) {
        for (SM_ACH_Order__c o : ordenesAActivarPorContrato.get(contractId)) {
            toUpdate.add(new SM_ACH_Order__c(
                Id = o.Id,
                SM_Payment_Status__c = 'Pending',
                SM_Next_Transaction_Date__c = FECHA_ACTIVACION,
                SM_Id_Salesforce_LCS__c = SM_AutomationLogHelper.appendNote(o.SM_Id_Salesforce_LCS__c, PROCESO,
                    'Stopped->Pending recobro cronico ' + FECHA_ACTIVACION.format())
            ));
        }
    }
    Integer ok = 0; Integer err = 0;
    if (!toUpdate.isEmpty()) {
        List<Database.SaveResult> results = Database.update(toUpdate, false);
        for (Integer k = 0; k < results.size(); k++) {
            if (results[k].isSuccess()) { ok++; }
            else {
                err++;
                System.debug('ERROR actualizando ' + toUpdate[k].Id + ': ' + results[k].getErrors()[0].getMessage());
            }
        }
    }
    System.debug('→ UPDATE COMPLETADO -> Exitos: ' + ok + ' | Errores: ' + err);

    if (!aActivar.isEmpty() || !excluidosCancelacion.isEmpty() || !excluidosLpfTransito.isEmpty() ||
        !excluidosOtros.isEmpty() || !revisarManualConteo.isEmpty() || !revisarManualOrdenes.isEmpty()) {
        String body = 'Contratos ACH con ' + MESES_MINIMO + '+ cuotas mensuales rechazadas y nunca recobradas -- ' +
            'revision automatica de hoy (intentos del mismo mes agrupados como 1 cuota):\n\n';
        body += '=== ACTIVADOS para ' + FECHA_ACTIVACION.format() + ' (' + aActivar.size() + ') ===\n' +
            (aActivar.isEmpty() ? '(ninguno)\n' : String.join(aActivar, '\n') + '\n');
        body += '\n=== EXCLUIDOS -- Late payment fee todavia en transito en el banco, reactivar = posible cobro doble (' +
            excluidosLpfTransito.size() + ') ===\n' +
            (excluidosLpfTransito.isEmpty() ? '(ninguno)\n' : String.join(excluidosLpfTransito, '\n') + '\n');
        body += '\n=== EXCLUIDOS -- Customer Cancellation activo, no se tocaron (' + excluidosCancelacion.size() + ') ===\n' +
            (excluidosCancelacion.isEmpty() ? '(ninguno)\n' : String.join(excluidosCancelacion, '\n') + '\n');
        body += '\n=== EXCLUIDOS -- LPF ya activa o suscripcion parada (' + excluidosOtros.size() + ') ===\n' +
            (excluidosOtros.isEmpty() ? '(ninguno)\n' : String.join(excluidosOtros, '\n') + '\n');
        body += '\n=== REVISAR MANUAL -- cuotas vencidas no cuadran con las generadas, no se activo (' + revisarManualConteo.size() + ') ===\n' +
            (revisarManualConteo.isEmpty() ? '(ninguno)\n' : String.join(revisarManualConteo, '\n') + '\n');
        body += '\n=== REVISAR MANUAL -- numero de ordenes Stopped no coincide con cuotas debidas (' + revisarManualOrdenes.size() + ') ===\n' +
            (revisarManualOrdenes.isEmpty() ? '(ninguno)\n' : String.join(revisarManualOrdenes, '\n') + '\n');
        body += '\nDetalle completo de cualquier contrato: python COLLECTIONS/estado_cobros.py <ContractNumber>';

        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setToAddresses(new String[]{ NOTIFY_EMAIL });
        mail.setSubject('[ACH] Contratos cronicos sin cobrar - ' + aActivar.size() + ' activados, ' +
            (revisarManualConteo.size() + revisarManualOrdenes.size() + excluidosLpfTransito.size()) +
            ' para revisar - ' + Date.today().format());
        mail.setPlainTextBody(body);
        if (!Test.isRunningTest()) {
            Messaging.sendEmail(new Messaging.SingleEmailMessage[]{ mail });
        }
        System.debug('→ Correo enviado a ' + NOTIFY_EMAIL);
    }
} else {
    System.debug('→ DRY RUN activo: no se activo ni envio nada. Cambia DRY_RUN a false para aplicar.');
}
