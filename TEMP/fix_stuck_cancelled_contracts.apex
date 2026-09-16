/*
 * fix_stuck_cancelled_contracts.apex
 * ------------------------------------
 * Hallazgo 2026-09-16: al correr mark_transmitted_accepted.apex, 200/227
 * pagos fallaron en una sola oleada -- pero la causa real es UNA orden ACH
 * (ACH-28209) cuyo contrato ya esta Cancelled. Cuando un pago de esa orden
 * pasa a ACCEPTED, SM_PaymentHandler.updateRelatedRecordsByPaymentStatusUpdates()
 * (linea 269) intenta forzar la orden a 'Canceled', pero
 * SM_ACHOrderHandler.validateCanceledStatus() (linea 530) bloquea con
 * addError() porque la orden todavia tiene un pago hermano en
 * ACH_PENDING/ACH_TRANSMITTED -- y como SM_PaymentHandler usa
 * Database.update(achOrdersToUpdate) SIN allOrNone=false (linea 294), UNA
 * orden bloqueada tumba TODO el batch de ordenes de esa transaccion, lo que
 * arrastra como fallidos a los demas 199 pagos de la misma oleada (aunque
 * no tengan nada que ver).
 *
 * Barrido completo del org (2026-09-16): exactamente 11 pagos en 10 ordenes
 * ACH distintas, todos en contratos ya Cancelled, siguen en ACH TRANSMITTED
 * sin ningun reporte -- son el 100% de los pagos "atascados" de este tipo
 * en todo el org (no solo del batch que fallo hoy).
 *
 * SOLUCION EN 2 PASOS (instruccion explicita del usuario 2026-09-16):
 *   Paso A: marcar los 11 pagos como ACCEPTED/COLLECTED (misma regla de 15
 *           dias que el resto), con SM_TriggerHandler.avoidAllHandlerExcecution
 *           = true para que NO dispare el intento de cancelar la orden
 *           dentro de esta misma transaccion (evita el choque).
 *   Paso B: con los handlers YA reactivados (bypass = false), actualizar
 *           las 10 ordenes ACH a SM_Payment_Status__c = 'Completed' -- una
 *           vez que ningun pago hermano sigue ACH_PENDING/ACH_TRANSMITTED
 *           (verificado antes de escribir), la validacion de
 *           validateCanceledStatus() ni siquiera aplica (esa solo bloquea el
 *           cambio a 'Canceled', no a 'Completed'), asi que el resto de la
 *           automatizacion normal de la orden corre igual que cualquier
 *           actualizacion real.
 *
 *           NOTA -- correccion del usuario 2026-09-16: el codigo actual de
 *           SM_PaymentHandler.cls (lineas 264-289) manda la orden a
 *           'Canceled' tanto si el ultimo pago fue ACCEPTED como REJECTED,
 *           con tal de que el contrato este Cancelled -- no distingue. Eso
 *           es inconsistente: si el pago SI se cobro (ACCEPTED), la orden
 *           cumplio su proposito y deberia quedar 'Completed' (igual que
 *           pasa con un contrato Finalized), no 'Canceled'. 'Canceled' tiene
 *           sentido solo si el pago fallo (REJECTED) con el contrato ya
 *           cancelado. Este script sigue la logica corregida; el bug en
 *           SM_PaymentHandler.cls en si no se toca aqui.
 *
 * Corre primero con DRY_RUN = true -> solo preview, NO actualiza nada.
 */

Boolean DRY_RUN = false; // Autorizado por el usuario 2026-09-16 tras revisar el preview

Set<String> paymentNames = new Set<String>{
    'PY-01889016', 'PY-01888782', 'PY-01889163', 'PY-01895389',
    'PY-01888832', 'PY-01888809', 'PY-01888816', 'PY-01895410',
    'PY-01895456', 'PY-01895464', 'PY-01895482'
};

List<SM_Payment__c> payments = [
    SELECT Id, Name, Payment_Status__c, SM_Check_Collection_Status__c,
           SM_Historical_Collection_Status__c, SM_ACH_Order__c,
           SM_ACH_Order__r.Name, SM_ACH_Order__r.SM_Payment_Status__c,
           SM_Contract__r.ContractNumber, SM_Contract__r.Status
    FROM SM_Payment__c
    WHERE Name IN :paymentNames
];

System.debug('=======================================================');
System.debug(' -> MODO: ' + (DRY_RUN ? 'DRY RUN (solo preview, sin cambios)' : 'EJECUCION REAL'));
System.debug(' -> Pagos encontrados: ' + payments.size() + ' / ' + paymentNames.size());
System.debug('=======================================================');

Set<Id> achOrderIds = new Set<Id>();
Date today = Date.today();
List<SM_Payment__c> paymentUpdates = new List<SM_Payment__c>();

for (SM_Payment__c p : payments) {
    achOrderIds.add(p.SM_ACH_Order__c);

    String tag = 'PRC_AUT_FIX_CANCELLED_CONTRACT_ORDER: ACCEPTED //';
    String previous = p.SM_Historical_Collection_Status__c == null ? '' : p.SM_Historical_Collection_Status__c;
    String newHistorical = tag + previous;
    if (newHistorical.length() > 150) {
        newHistorical = newHistorical.substring(0, 150);
    }

    System.debug('---------------------------------------------------------');
    System.debug(p.Name + '  (Orden ' + p.SM_ACH_Order__r.Name + ', Contrato ' +
            p.SM_Contract__r.ContractNumber + ' / ' + p.SM_Contract__r.Status + ')');
    System.debug('  PAGO ACTUAL -> Payment_Status=' + p.Payment_Status__c +
            ' | Collection_Status=' + p.SM_Check_Collection_Status__c);
    System.debug('  PAGO NUEVO  -> Payment_Status=ACCEPTED | Collection_Status=COLLECTED');
    System.debug('  Historico nuevo -> ' + newHistorical);

    paymentUpdates.add(new SM_Payment__c(
            Id = p.Id,
            Payment_Status__c = 'ACCEPTED',
            SM_Check_Collection_Date__c = today,
            SM_Check_Collection__c = true,
            SM_Check_Collection_Status__c = 'COLLECTED',
            SM_Historical_Collection_Status__c = newHistorical
    ));
}

List<SM_ACH_Order__c> orders = [
    SELECT Id, Name, SM_Payment_Status__c
    FROM SM_ACH_Order__c
    WHERE Id IN :achOrderIds
];

System.debug('=======================================================');
System.debug(' -> Ordenes ACH involucradas: ' + orders.size());
for (SM_ACH_Order__c o : orders) {
    System.debug('  ' + o.Name + ' -> ACTUAL: ' + o.SM_Payment_Status__c + ' | NUEVO: Completed');
}
System.debug('=======================================================');

if (!DRY_RUN) {
    // Paso A: pagos, CON bypass de handlers (evita el choque en la misma transaccion)
    SM_TriggerHandler.avoidAllHandlerExcecution = true;
    Database.SaveResult[] paymentResults = Database.update(paymentUpdates, false);
    Integer okP = 0, errP = 0;
    for (Database.SaveResult sr : paymentResults) {
        if (sr.isSuccess()) {
            okP++;
        } else {
            errP++;
            System.debug(' -> ERROR actualizando pago ' + sr.getId() + ': ' + sr.getErrors());
        }
    }
    System.debug(' -> Paso A (pagos) -> Exitos: ' + okP + ' | Errores: ' + errP);
    SM_TriggerHandler.avoidAllHandlerExcecution = false;

    // Paso B: verificar que ya no queda ningun pago hermano pendiente, y
    // SOLO entonces cancelar la orden -- SIN bypass, para que corra la
    // automatizacion normal de una cancelacion real.
    Map<Id, Integer> pendingSiblingsByOrder = new Map<Id, Integer>();
    for (SM_Payment__c sib : [
            SELECT SM_ACH_Order__c
            FROM SM_Payment__c
            WHERE SM_ACH_Order__c IN :achOrderIds
              AND Payment_Status__c IN ('ACH PENDING', 'ACH TRANSMITTED')
    ]) {
        Integer c = pendingSiblingsByOrder.containsKey(sib.SM_ACH_Order__c) ? pendingSiblingsByOrder.get(sib.SM_ACH_Order__c) : 0;
        pendingSiblingsByOrder.put(sib.SM_ACH_Order__c, c + 1);
    }

    List<SM_ACH_Order__c> orderUpdates = new List<SM_ACH_Order__c>();
    for (SM_ACH_Order__c o : orders) {
        if (pendingSiblingsByOrder.containsKey(o.Id)) {
            System.debug(' -> SALTANDO ' + o.Name + ': todavia tiene ' + pendingSiblingsByOrder.get(o.Id) + ' pago(s) pendiente(s) -- no se actualiza.');
            continue;
        }
        if (o.SM_Payment_Status__c == 'Completed') {
            System.debug(' -> SALTANDO ' + o.Name + ': ya esta Completed, no hace falta tocarla.');
            continue;
        }
        orderUpdates.add(new SM_ACH_Order__c(Id = o.Id, SM_Payment_Status__c = 'Completed'));
    }

    Integer okO = 0, errO = 0;
    if (!orderUpdates.isEmpty()) {
        Database.SaveResult[] orderResults = Database.update(orderUpdates, false);
        for (Database.SaveResult sr : orderResults) {
            if (sr.isSuccess()) {
                okO++;
            } else {
                errO++;
                System.debug(' -> ERROR actualizando orden ' + sr.getId() + ': ' + sr.getErrors());
            }
        }
    }
    System.debug(' -> Paso B (ordenes) -> Exitos: ' + okO + ' | Errores: ' + errO + ' | Saltadas: ' + (orders.size() - orderUpdates.size()));
} else {
    System.debug(' -> DRY RUN: no se realizo ningun cambio. Cambiar DRY_RUN a false para ejecutar.');
}
