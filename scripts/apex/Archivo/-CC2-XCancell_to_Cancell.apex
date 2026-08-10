// ┌──────────────────────────────────────────────────────────────┐
// │   NORMALIZACIÓN DE ORDERS EN STOP POR CUSTOMER CANCELLATION  │
// └──────────────────────────────────────────────────────────────┘


// ==================================================================
// 1️⃣ PROCESAR CHARGENT ORDERS
// ==================================================================

System.debug('────────────────────────────────────────────');
System.debug('→ INICIO: Normalización de Chargent Orders');

List<ChargentOrders__ChargentOrder__c> chargents = [
    SELECT Id, Name, ChargentOrders__Payment_Status__c, Contract__r.Status
    FROM ChargentOrders__ChargentOrder__c
    WHERE ChargentOrders__Payment_Status__c = 'X CANCELED'
      AND Contract__r.Status = 'Cancelled'
];

if (chargents.isEmpty()) {
    System.debug('→❌ No se encontraron Chargent Orders X CANCELED');
} else {

    List<ChargentOrders__ChargentOrder__c> chargentsParaActualizar = new List<ChargentOrders__ChargentOrder__c>();

    for (ChargentOrders__ChargentOrder__c ord : chargents) {

        // Validación: si el contrato no está Cancelled, ignorar
        if (ord.Contract__r.Status != 'Cancelled') {
            System.debug('→ ⛔ Ignorado (Contrato no Cancelled): ' + ord.Name);
            continue;
        }

        // Cumple condiciones → actualizar
        ord.ChargentOrders__Payment_Status__c = 'Canceled';
        chargentsParaActualizar.add(ord);

        System.debug('→ ✔ Chargent Order listo para actualizar: ' + ord.Name);
    }

    if (!chargentsParaActualizar.isEmpty()) {
        update chargentsParaActualizar;
        System.debug('→ ✅ Chargent Orders actualizados: ' + chargentsParaActualizar.size());
    } else {
        System.debug('→ ⚠️ Ningún Chargent Order cumplió condiciones para actualizar.');
    }
}



// ==================================================================
// 2️⃣ PROCESAR ACH ORDERS
// ==================================================================

System.debug('────────────────────────────────────────────');
System.debug('→ INICIO: Normalización de ACH Orders');

List<SM_ACH_Order__c> achOrds = [
    SELECT Id, Name, SM_Payment_Status__c, SM_Contract__r.ContractNumber, SM_Contract__r.Status
    FROM   SM_ACH_Order__c
    WHERE  SM_Payment_Status__c = 'X CANCELED'
      AND  SM_Contract__r.Status = 'Cancelled'
];

if (achOrds.isEmpty()) {
    System.debug('→ ❌ No se encontraron ACH Orders X CANCELED');
    return;
}

// Buscar pagos en proceso SOLO de esos Orders
List<SM_Payment__c> pagosEnProceso = [
    SELECT Id, Name, Payment_Status__c, SM_ACH_Order__c, SM_Contract__r.ContractNumber
    FROM SM_Payment__c
    WHERE Payment_Status__c NOT IN ('ACCEPTED', 'REJECTED', 'CANCELED', 'REFUNDED')
      AND SM_ACH_Order__c IN :achOrds
];

// Identificar Orders con pagos en proceso
Set<Id> ordersConPagosEnProceso = new Set<Id>();
for (SM_Payment__c p : pagosEnProceso) {
    ordersConPagosEnProceso.add(p.SM_ACH_Order__c);
    System.debug('→ ⛔ Pago en proceso detectado: ' + p.Name + ' - Contrato: ' + p.SM_Contract__r.ContractNumber);
}

// Filtrar Orders válidos
List<SM_ACH_Order__c> achParaActualizar = new List<SM_ACH_Order__c>();

for (SM_ACH_Order__c ord : achOrds) {

    // Validación: contrato debe estar Cancelled
    if (ord.SM_Contract__r.Status != 'Cancelled') {
        System.debug('→ ⛔ Ignorado (Contrato no Cancelled): ' + ord.Name);
        continue;
    }

    // Validación: no debe tener pagos en proceso
    if (ordersConPagosEnProceso.contains(ord.Id)) {
        System.debug('→ ⛔ Ignorado (Pagos en proceso): ' + ord.Name);
        continue;
    }

    // Cumple condiciones → actualizar
    ord.SM_Payment_Status__c = 'Canceled';
    achParaActualizar.add(ord);

    System.debug('→ ✔ ACH Order listo para actualizar: ' + ord.Name);
}

// Actualizar solo los válidos
if (!achParaActualizar.isEmpty()) {
    update achParaActualizar;
    System.debug('→ ✅ ACH Orders actualizados: ' + achParaActualizar.size());
} else {
    System.debug('→ ⚠️ Ningún ACH Order cumplió condiciones para actualizar.');
}

System.debug('────────────────────────────────────────────');
System.debug('→ PROCESO COMPLETADO');
