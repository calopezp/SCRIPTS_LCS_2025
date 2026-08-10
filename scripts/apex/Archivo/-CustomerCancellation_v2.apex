// ┌──────────────────────────────────────────────────────────────┐
// │ ORDERS EN STOP DE "CUSTOMER CANCELLATION"                    │
// └──────────────────────────────────────────────────────────────┘

// 1. Listar contratos
List<Contract> contratos = [
    SELECT Id, ContractNumber
    FROM Contract
    WHERE SM_Customer_Cancellation__c = TRUE
    AND Status IN ('Activated', 'Payment Process', 'Cancelled')
   // AND ContractNumber = '00314090'
];

if (contratos.isEmpty()) {
    System.debug('→❌ No se encontraron contratos');
    return;
}

System.debug('→ ✔ Contratos encontrados: ' + contratos.size());

Set<Id> contratoIds = new Set<Id>();
for (Contract c : contratos) contratoIds.add(c.Id);


// 2. ACH Orders
List<SM_ACH_Order__c> achOrds = [
    SELECT Id, Name, SM_Payment_Status__c, SM_Contract__r.ContractNumber
    FROM SM_ACH_Order__c
    WHERE SM_Contract__c IN :contratoIds
];

System.debug('→ ACH Orders encontrados: ' + achOrds.size());

// 3. Pagos
Set<String> estadosCerrados = new Set<String>{
    'NOT_COLLECTED', 'COLLECTED', 'ACCEPTED', 'REFUNDED'
};

List<SM_Payment__c> pagos = [
    SELECT Id, Name, Payment_Status__c, SM_Check_Collection_Status__c,
           SM_ACH_Order__c, SM_ACH_Order__r.Name
    FROM SM_Payment__c
    WHERE SM_ACH_Order__c IN :achOrds
];

Map<Id, List<SM_Payment__c>> pagosPorOrder = new Map<Id, List<SM_Payment__c>>();

for (SM_Payment__c p : pagos) {
    if (!pagosPorOrder.containsKey(p.SM_ACH_Order__c)) {
    pagosPorOrder.put(p.SM_ACH_Order__c, new List<SM_Payment__c>());
    }
    pagosPorOrder.get(p.SM_ACH_Order__c).add(p);
}

// 4. Procesar ACH Orders
List<SM_ACH_Order__c> achParaActualizar = new List<SM_ACH_Order__c>();

for (SM_ACH_Order__c ord : achOrds) {

    List<SM_Payment__c> pagosDeEsteOrder = pagosPorOrder.get(ord.Id);
    Boolean tienePagosEnProceso = false;

    if (pagosDeEsteOrder != null) {
        for (SM_Payment__c pago : pagosDeEsteOrder) {
            if (!estadosCerrados.contains(pago.SM_Check_Collection_Status__c)) {
                tienePagosEnProceso = true;
                break;
            }
        }
    }

    // X CANCELED
    if (tienePagosEnProceso &&
        !(
            ord.SM_Payment_Status__c == 'cancelled' ||
            ord.SM_Payment_Status__c == 'Canceled'  ||
            ord.SM_Payment_Status__c == 'Complete'  ||
            ord.SM_Payment_Status__c == 'X CANCELED'
        )
    ) {
        ord.SM_Payment_Status__c = 'X CANCELED';
        achParaActualizar.add(ord);
        continue;
    }

    // Canceled
    if (!tienePagosEnProceso &&
        (
            ord.SM_Payment_Status__c == 'Stopped'   ||
            ord.SM_Payment_Status__c == 'recurring' ||
            ord.SM_Payment_Status__c == 'Initiated' ||
            ord.SM_Payment_Status__c == 'pending'
        )
    ) {
        ord.SM_Payment_Status__c = 'Canceled';
        achParaActualizar.add(ord);
    }
}

if (!achParaActualizar.isEmpty()) {
    update achParaActualizar;
    System.debug('→ ACH Orders actualizados: ' + achParaActualizar.size());
}

// 5. TC Orders
List<ChargentOrders__ChargentOrder__c> tcOrds = [
    SELECT Id, Name, ChargentOrders__Payment_Status__c
    FROM ChargentOrders__ChargentOrder__c
    WHERE Contract__c IN :contratoIds
    AND (ChargentOrders__Payment_Status__c = null
         OR ChargentOrders__Payment_Status__c NOT IN ('cancelled','Canceled','Complete','X CANCELED'))
];

if (!tcOrds.isEmpty()) {
    for (ChargentOrders__ChargentOrder__c tc : tcOrds) {
        tc.ChargentOrders__Payment_Status__c = 'X CANCELED';
    }
    update tcOrds;
    System.debug('→ TC Orders actualizados: ' + tcOrds.size());
}
