// ┌──────────────────────────────────────────────────────────────┐
// │ ORDERS EN STOP DE "CUSTOMER CANCELLATON                      │
// └──────────────────────────────────────────────────────────────┘


// 1. Listar contratos con "Customer Cancellation" en TRUE

List<Contract> contratos = [
    SELECT Id, ContractNumber
    FROM Contract
    WHERE SM_Customer_Cancellation__c = TRUE
    AND Status IN ('Activated', 'Payment Process') and ContractNumber = '00313649'
   
];

if (contratos.isEmpty()) {
    System.debug('→❌ No se encontraron contratos');
} else {
    System.debug('→ ✔ Contratos encontrados: ' + contratos.size());
    System.debug(contratos);
}

/* 2. Listar Orders TC de esos contratos

List<ChargentOrders__ChargentOrder__c> tcOrds = [
    SELECT Id, Name, ChargentOrders__Payment_Status__c, Contract__r.ContractNumber
    FROM   ChargentOrders__ChargentOrder__c
    WHERE  Contract__c IN :contratos AND ChargentOrders__Payment_Status__c NOT IN ('cancelled', 'Canceled', 'Complete', 'X CANCELED') AND ChargentOrders__Total__c > 0
];

if (tcOrds.isEmpty()) {
    System.debug('→❌ No se encontraron Orders TC para los contratos listados');
} else {
    for (ChargentOrders__ChargentOrder__c tcOrd : tcOrds) {
        tcOrd.ChargentOrders__Payment_Status__c = 'X CANCELED';
    }
    update tcOrds;
    System.debug('→ Orders TC encontrados y Actualizados: ' + tcOrds.size());
    System.debug('→ tcOrds: ' + tcOrds);
}
*/


// 3. Listar ACH Orders "EN PROCESO DE COBRO" de esos contratos
List<SM_ACH_Order__c> achOrds = [
    SELECT Id, Name, SM_Payment_Status__c, SM_Contract__r.ContractNumber
    FROM   SM_ACH_Order__c
    WHERE  SM_Contract__c IN :contratos
];
system.debug(LoggingLevel.INFO, '→ ACH Or    ders encontrados: ' + achOrds.size());
 /*
if (achOrds.isEmpty()) {
    System.debug('→❌ No se encontraron Orders ACH para los contratos listados');
} else {
    for (SM_ACH_Order__c achOrd : achOrds) {
        if(!(new Set<String>{'cancelled', 'Canceled', 'Complete','X CANCELED'}).contains(achOrd.SM_Payment_Status__c)) {
            achOrd.SM_Payment_Status__c = 'X CANCELED';
            System.debug('→ Orders ACH Actualizados: ' + achOrd.Name + ' - ' + achOrd.SM_Payment_Status__c);
        }
    }
    update achOrds;
    System.debug('→ Orders ACH Activos encontrados y Validados (cancelados o x Cancelar): ' + achOrds.size());
}
*/
// Buscar pagos en proceso en los ACH ORDERS
Set<Id> ordersConPagosEnProceso = new Set<Id>(); 
List<SM_Payment__c> pagosEnProceso = [
    SELECT Id, Name, Payment_Status__c, SM_Check_Collection_Status__c, SM_ACH_Order__c, SM_ACH_Order__r.Name, SM_Contract__r.ContractNumber
    FROM SM_Payment__c
    WHERE SM_Check_Collection_Status__c NOT IN ('NOT_COLLECTED', 'COLLECTED', 'ACCEPTED', 'REFUNDED')
      AND SM_ACH_Order__c IN :achOrds
];

if (pagosEnProceso.isEmpty()) {
    System.debug('→ ✅ No se encontraron pagos en proceso para los ACH Orders listados');
} else {
    System.debug('→ ⚠️ Pagos en proceso encontrados: ' + pagosEnProceso.size());
    for (SM_Payment__c pago : pagosEnProceso) {
        System.debug('→ ⛔ Pago en proceso: ' + pago.Name + ' - ACH Order: ' + pago.SM_ACH_Order__r.Name + ' - Status: ' + pago.Payment_Status__c);
        ordersConPagosEnProceso.add(pago.SM_ACH_Order__c);
    }
}


// Identificar Orders con pagos en proceso
if (!ordersConPagosEnProceso.isEmpty()) {
    System.debug('→ ⛔ ACH Orders con pagos en proceso: ' + ordersConPagosEnProceso.size());

    // Filtrar Orders válidos
    List<SM_ACH_Order__c> achParaActualizar = new List<SM_ACH_Order__c>();

    for (SM_ACH_Order__c ord : achOrds) {

        // Validación: contrato debe estar Cancelled
        if (ord.SM_Contract__r.Status != 'Cancelled') {
            System.debug('→ ⛔ ALERTA CONTRATO NO CANCELADO : ' + ord.Name);
            //continue;
        }

        // Validación: no debe tener pagos en proceso
        if (ordersConPagosEnProceso.contains(ord.Id)) {
            System.debug('→ ⛔ ACH Order con Pagos en proceso : ' + ord.Name);
            ord.SM_Payment_Status__c = 'X CANCELED';
            //continue;
        }

        // Cumple condiciones → actualizar
        ord.SM_Payment_Status__c = 'Canceled';
        achParaActualizar.add(ord);
        System.debug('→ ✔ ACH Order listo para actualizar: ' + ord.Name + ' - Status: ' + ord.SM_Payment_Status__c);
    }

    // Actualizar solo los válidos
    if (!achParaActualizar.isEmpty()) {
        update achParaActualizar;
        System.debug('→ ✅ ACH Orders actualizados: ' + achParaActualizar.size());
    } else {
        System.debug('→ ⚠️ Ningún ACH Order cumplió condiciones para actualizar.');
    }
}

System.debug('────────────────────────────────────────────');
System.debug('→ PROCESO COMPLETADO');