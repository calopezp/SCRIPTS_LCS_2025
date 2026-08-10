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


// 3. Listar ACH Orders "EN PROCESO DE COBRO" de esos contratos
List<SM_ACH_Order__c> achOrds = [
    SELECT Id, Name, SM_Payment_Status__c, SM_Contract__r.ContractNumber
    FROM   SM_ACH_Order__c
    WHERE  SM_Contract__c IN :contratos
];
system.debug(LoggingLevel.INFO, '→ ACH Or    ders encontrados: ' + achOrds.size());
 
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