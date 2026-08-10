// ┌──────────────────────────────────────────────────────────────┐
// │ ORDERS EN STOP DE "CUSTOMER CANCELLATON                      │
// └──────────────────────────────────────────────────────────────┘

// 1. Listar Chargent Orders X CANCELED de contratos Cancelado
List<ChargentOrders__ChargentOrder__c> chargents = [
    SELECT Id, Name, ChargentOrders__Payment_Status__c
    FROM ChargentOrders__ChargentOrder__c
    WHERE ChargentOrders__Payment_Status__c = 'X CANCELED'
        AND Contract__r.Status = 'Cancelled'
];

if (chargents.isEmpty()) {
    System.debug(' →❌ No se encontraron Chargent Orders X CANCELED');
} else {
    for (ChargentOrders__ChargentOrder__c chargent : chargents) {
        chargent.ChargentOrders__Payment_Status__c = 'Canceled';
    }
    update chargents;
    System.debug(' → Orders TC encontrados y Actualizados: ' + chargents.size());
    System.debug(' → chargent: ' + chargents);
}

// 2. Listar ACH Orders X CANCELED de contratos Cancelado
List<SM_ACH_Order__c> achOrds = [
    SELECT Id, Name, SM_Payment_Status__c, SM_Contract__r.ContractNumber
    FROM   SM_ACH_Order__c
    WHERE  SM_Payment_Status__c = 'X CANCELED'
        AND SM_Contract__r.Status = 'Cancelled'
];

// Listamos si esos contratos tienen Payment en proceso antes de cancelar el Order
List<SM_Payment__c> payments = [ 
    SELECT Id, Name, Payment_Status__c, SM_Contract__r.ContractNumber, SM_ach_Order__c
    FROM SM_Payment__c
    WHERE Payment_Status__c NOT IN ('ACCEPTED', 'REJECTED', 'CANCELED')
        AND SM_ach_Order__c IN :achOrds
];

// Si hay pagos en proceso, no cancelamos el Order y hacemos debug para revisar caso por caso
if (payments.isEmpty()) {
    for (SM_ACH_Order__c achOrd : achOrds) {
        achOrd.SM_Payment_Status__c = 'Canceled';
        System.debug(' → ACHOrd Actualizado ' + 
            achOrd.Id + ' - ' + achOrd.Name + ' - ' + achOrd.SM_Contract__r.ContractNumber);
    }
    update achOrds;
    System.debug(' → Orders ACH encontrados y Actualizados: ' + achOrds.size());
    System.debug(' → achOrds: ' + achOrds);
} else {
    System.debug(' →❌ No se cancelaron Orders ACH porque se encontraron pagos en proceso relacionados. Revisar detalles:');
    for (SM_Payment__c pago : payments) {
        System.debug(' → Pago en proceso: ' + pago.Id + ' - ' + pago.Name + ' - Contrato: ' + pago.SM_Contract__r.ContractNumber);
    }
}
