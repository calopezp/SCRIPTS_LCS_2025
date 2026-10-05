/*
 * activar_ach_chronic_unpaid.apex
 * -----------------------------------
 * Reemplaza a notify_ach_chronic_unpaid.apex (detector de solo-reporte,
 * 2026-10-04) -- hace lo mismo mas la validacion y activacion pedida por
 * el usuario el mismo dia. Corre a diario como parte de run_daily_new_files.sh,
 * no es un script de una sola corrida.
 *
 * Por cada contrato ACH con 3+ meses de Fee mensual rechazado y nunca
 * recobrado (misma deteccion bulkificada de notify_ach_chronic_unpaid.apex):
 *
 *   1. VALIDACION POR CONTEO: meses transcurridos desde SM_Start_date__c
 *      (usando SM_Payment_day__c) deben cuadrar (+-1 mes de tolerancia) con
 *      (Fee ACCEPTED + Fee fallidos). Si no cuadra, el numero de "meses sin
 *      cobrar" no es confiable para ese contrato -- se reporta aparte para
 *      revision manual, NUNCA se activa a ciegas.
 *   2. Si SM_Customer_Cancellation__c = true, se excluye (solo se reporta,
 *      no se activa) -- un contrato en camino a cancelarse no debe recibir
 *      un nuevo intento de cobro.
 *   3. Si pasa ambos filtros: se activan las SM_ACH_Order__c "Late payment
 *      fee" que esten Stopped, cambiando SM_Payment_Status__c a 'Pending' y
 *      SM_Next_Transaction_Date__c al PROXIMO DIA HABIL (si hoy es viernes,
 *      el lunes -- el pipeline de ACH no corre sabado/domingo, mismo criterio
 *      que el fix de -B.ConfirmarCargueACH.apex del 2026-10-03). Si el numero
 *      de ordenes Stopped no coincide exactamente con los meses que
 *      realmente faltan, tambien se reporta para revision manual en vez de
 *      adivinar (crear una orden nueva, o activar solo algunas).
 *
 * Caso real que lo origino: contrato 00316426, 5 meses sin cobrar, cuenta
 * cerrada (R02), 5 ordenes Late payment fee Stopped que coincidian
 * exactamente con los 5 meses -- ver BITACORA_HALLAZGOS_TECNICOS.md 2026-10-04.
 * Primera corrida real (dry-run, mismo dia): 101 candidatos brutos -> 36
 * confirmados tras conteo preciso, $13,207 total, todos sin orden activa.
 *
 * MODO DE USO:
 *   - Corre primero con DRY_RUN = true -> solo preview, NO escribe ni envia nada.
 *   - Si todo esta correcto, cambia DRY_RUN a false y corre de nuevo.
 */

Boolean DRY_RUN = true; // <-- cambiar a false para activar + enviar correo real
String NOTIFY_EMAIL = 'clopez@legal-credit.com';
Integer MESES_MINIMO = 3;

Date proximoDiaHabil(Date d) {
    DateTime dt = DateTime.newInstanceGMT(d, Time.newInstance(12, 0, 0, 0));
    String nombreDia = dt.format('EEEE');
    Integer diasASumar = 1;
    if (nombreDia == 'Friday') { diasASumar = 3; }
    else if (nombreDia == 'Saturday') { diasASumar = 2; }
    return d.addDays(diasASumar);
}
Date FECHA_ACTIVACION = proximoDiaHabil(Date.today());

// =========================================================================
// 1) Candidatos (deteccion bulkificada, igual que notify_ach_chronic_unpaid.apex)
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

System.debug('→ Candidatos (conteo bruto >= ' + MESES_MINIMO + '): ' + candidatoIds.size());

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

Map<Id, List<SM_Payment__c>> missedByContract = new Map<Id, List<SM_Payment__c>>();
for (SM_Payment__c p : [
    SELECT SM_Contract__c, Name, SM_Payment_Date__c, SM_Amount__c
    FROM SM_Payment__c
    WHERE SM_Contract__c IN :candidatoIds
    AND SM_Type__c = 'Fee'
    AND Payment_Status__c = 'REJECTED'
    AND SM_Check_Collection_Status__c = 'NOT_COLLECTED'
]) {
    if (!missedByContract.containsKey(p.SM_Contract__c)) {
        missedByContract.put(p.SM_Contract__c, new List<SM_Payment__c>());
    }
    missedByContract.get(p.SM_Contract__c).add(p);
}

Map<Id, Integer> recoveredByContract = new Map<Id, Integer>();
for (AggregateResult ar : [
    SELECT SM_Contract__c cId, COUNT(Id) cnt
    FROM SM_Payment__c
    WHERE SM_Contract__c IN :candidatoIds
    AND SM_Type__c = 'Late payment fee'
    AND Payment_Status__c = 'ACCEPTED'
    GROUP BY SM_Contract__c
]) {
    recoveredByContract.put((Id) ar.get('cId'), (Integer) ar.get('cnt'));
}

Map<Id, Integer> acceptedFeeByContract = new Map<Id, Integer>();
for (AggregateResult ar : [
    SELECT SM_Contract__c cId, COUNT(Id) cnt
    FROM SM_Payment__c
    WHERE SM_Contract__c IN :candidatoIds
    AND SM_Type__c = 'Fee'
    AND Payment_Status__c = 'ACCEPTED'
    GROUP BY SM_Contract__c
]) {
    acceptedFeeByContract.put((Id) ar.get('cId'), (Integer) ar.get('cnt'));
}

Map<Id, List<SM_ACH_Order__c>> lpfOrdersByContract = new Map<Id, List<SM_ACH_Order__c>>();
for (SM_ACH_Order__c o : [
    SELECT Id, Name, SM_Contract__c, SM_Payment_Status__c, SM_Total__c, CreatedDate
    FROM SM_ACH_Order__c
    WHERE SM_Contract__c IN :candidatoIds
    AND SM_Payment_Type__c = 'Late payment fee'
    ORDER BY CreatedDate ASC
]) {
    if (!lpfOrdersByContract.containsKey(o.SM_Contract__c)) {
        lpfOrdersByContract.put(o.SM_Contract__c, new List<SM_ACH_Order__c>());
    }
    lpfOrdersByContract.get(o.SM_Contract__c).add(o);
}

// =========================================================================
// 2) Meses transcurridos desde SM_Start_date__c hasta hoy (ciclos cumplidos)
// =========================================================================
Integer mesesTranscurridos(Date inicio, Date hoy) {
    Integer meses = (hoy.year() - inicio.year()) * 12 + (hoy.month() - inicio.month());
    if (hoy.day() < inicio.day()) {
        meses -= 1;
    }
    return meses < 0 ? 0 : meses;
}

// =========================================================================
// 3) Clasificar cada candidato
// =========================================================================
List<String> aActivar = new List<String>();
List<String> excluidosCancelacion = new List<String>();
List<String> revisarManualConteo = new List<String>();
List<String> revisarManualOrdenes = new List<String>();
Map<Id, List<SM_ACH_Order__c>> ordenesAActivarPorContrato = new Map<Id, List<SM_ACH_Order__c>>();

Date hoy = Date.today();
for (Id contractId : candidatoIds) {
    Contract cont = contratosById.get(contractId);
    Decimal monthlyOffer = cont.SM_Monthly_offer__c;
    if (monthlyOffer == null || cont.SM_Start_date__c == null) {
        revisarManualConteo.add(cont.ContractNumber + ' -- falta SM_Monthly_offer__c o SM_Start_date__c');
        continue;
    }

    Integer missedCnt = 0;
    for (SM_Payment__c p : missedByContract.get(contractId)) {
        if (p.SM_Amount__c == monthlyOffer) { missedCnt++; }
    }
    if (missedCnt < MESES_MINIMO) { continue; }

    Integer recoveredCnt = recoveredByContract.containsKey(contractId) ? recoveredByContract.get(contractId) : 0;
    Integer stillOwed = missedCnt - recoveredCnt;
    if (stillOwed < MESES_MINIMO) { continue; }

    Integer aceptados = acceptedFeeByContract.containsKey(contractId) ? acceptedFeeByContract.get(contractId) : 0;
    Integer transcurridos = mesesTranscurridos(cont.SM_Start_date__c, hoy);
    Integer esperado = aceptados + missedCnt;
    Integer diferencia = transcurridos - esperado;

    String etiquetaConteo = cont.ContractNumber + ' (' + cont.Account.Name + ') -- transcurridos:' + transcurridos +
        ' aceptados:' + aceptados + ' fallidos:' + missedCnt + ' debe:' + stillOwed +
        ' recobrados:' + recoveredCnt + ' dif:' + diferencia;

    if (diferencia < -1 || diferencia > 1) {
        revisarManualConteo.add(etiquetaConteo);
        continue;
    }

    if (cont.SM_Customer_Cancellation__c == true) {
        excluidosCancelacion.add(cont.ContractNumber + ' (' + cont.Account.Name + ') -- debe ' + stillOwed +
            ' mes(es), SM_Customer_Cancellation__c=true, NO se activa');
        continue;
    }

    List<SM_ACH_Order__c> ordenesStopped = new List<SM_ACH_Order__c>();
    List<SM_ACH_Order__c> todasLasOrdenes = lpfOrdersByContract.containsKey(contractId)
        ? lpfOrdersByContract.get(contractId) : new List<SM_ACH_Order__c>();
    for (SM_ACH_Order__c o : todasLasOrdenes) {
        if (o.SM_Payment_Status__c == 'Stopped') {
            ordenesStopped.add(o);
        }
    }

    if (ordenesStopped.size() != stillOwed) {
        revisarManualOrdenes.add(cont.ContractNumber + ' (' + cont.Account.Name + ') -- debe ' + stillOwed +
            ' mes(es), pero tiene ' + ordenesStopped.size() + ' orden(es) Stopped (' +
            todasLasOrdenes.size() + ' Late payment fee en total de cualquier estado)');
        continue;
    }

    ordenesAActivarPorContrato.put(contractId, ordenesStopped);
    aActivar.add(cont.ContractNumber + ' (' + cont.Account.Name + ') -- ' + ordenesStopped.size() +
        ' orden(es) Stopped -> Pending, proxima transaccion ' + FECHA_ACTIVACION.format() +
        ' ($' + (stillOwed * monthlyOffer).setScale(0) + ' total)');
}

System.debug('→ Activar: ' + aActivar.size() + ' | Excluidos (Cancellation): ' + excluidosCancelacion.size() +
    ' | Revisar (conteo): ' + revisarManualConteo.size() + ' | Revisar (ordenes): ' + revisarManualOrdenes.size());
for (String s : aActivar) { System.debug('ACTIVAR -> ' + s); }
for (String s : excluidosCancelacion) { System.debug('EXCLUIDO -> ' + s); }
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
                SM_Next_Transaction_Date__c = FECHA_ACTIVACION
            ));
        }
    }
    Integer ok = 0; Integer err = 0;
    if (!toUpdate.isEmpty()) {
        List<Database.SaveResult> results = Database.update(toUpdate, false);
        for (Integer i = 0; i < results.size(); i++) {
            if (results[i].isSuccess()) { ok++; }
            else {
                err++;
                System.debug('ERROR actualizando ' + toUpdate[i].Id + ': ' + results[i].getErrors()[0].getMessage());
            }
        }
    }
    System.debug('→ UPDATE COMPLETADO -> Exitos: ' + ok + ' | Errores: ' + err);

    if (!aActivar.isEmpty() || !excluidosCancelacion.isEmpty() || !revisarManualConteo.isEmpty() || !revisarManualOrdenes.isEmpty()) {
        String body = 'Contratos ACH con ' + MESES_MINIMO + '+ meses de Fee mensual rechazado y nunca recobrado -- ' +
            'revision automatica de hoy:\n\n';
        body += '=== ACTIVADOS para ' + FECHA_ACTIVACION.format() + ' (' + aActivar.size() + ') ===\n' +
            (aActivar.isEmpty() ? '(ninguno)\n' : String.join(aActivar, '\n') + '\n');
        body += '\n=== EXCLUIDOS -- Customer Cancellation activo, no se tocaron (' + excluidosCancelacion.size() + ') ===\n' +
            (excluidosCancelacion.isEmpty() ? '(ninguno)\n' : String.join(excluidosCancelacion, '\n') + '\n');
        body += '\n=== REVISAR MANUAL -- el conteo de meses no cuadra, no se activo (' + revisarManualConteo.size() + ') ===\n' +
            (revisarManualConteo.isEmpty() ? '(ninguno)\n' : String.join(revisarManualConteo, '\n') + '\n');
        body += '\n=== REVISAR MANUAL -- numero de ordenes Stopped no coincide con meses debidos (' + revisarManualOrdenes.size() + ') ===\n' +
            (revisarManualOrdenes.isEmpty() ? '(ninguno)\n' : String.join(revisarManualOrdenes, '\n') + '\n');
        body += '\nDetalle completo de cualquier contrato: python COLLECTIONS/estado_cobros.py <ContractNumber>';

        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setToAddresses(new String[]{ NOTIFY_EMAIL });
        mail.setSubject('[ACH] Contratos cronicos sin cobrar - ' + aActivar.size() + ' activados, ' +
            (revisarManualConteo.size() + revisarManualOrdenes.size()) + ' para revisar - ' + Date.today().format());
        mail.setPlainTextBody(body);
        if (!Test.isRunningTest()) {
            Messaging.sendEmail(new Messaging.SingleEmailMessage[]{ mail });
        }
        System.debug('→ Correo enviado a ' + NOTIFY_EMAIL);
    }
} else {
    System.debug('→ DRY RUN activo: no se activo ni envio nada. Cambia DRY_RUN a false para aplicar.');
}
