// ======================================================================
// LISTAR CONTRATOS ACTIVOS CUYOS CHARGENT ORDERS (CON NEXT TX DATE <= HOY+5)
// NO COINCIDEN CON LOS DATOS DEL PAYMENT METHOD ACTIVO DEL CONTRATO
// ======================================================================

// Fecha límite: hoy + 5 días
Date fechaLimite = Date.today().addDays(5);

// 1️⃣ Traer solo Orders relevantes (NextTxDate <= hoy+5)
List<ChargentOrders__ChargentOrder__c> ordersFiltrados = [
    SELECT Id, Name, Contract__c,
           ChargentOrders__Billing_Country__c,
           ChargentOrders__Tokenization__c,
           ChargentOrders__Card_Last_4__c,
           ChargentOrders__Card_Expiration_Month__c,
           ChargentOrders__Card_Expiration_Year__c,
           ChargentOrders__Next_Transaction_Date__c
    FROM ChargentOrders__ChargentOrder__c
    WHERE ChargentOrders__Next_Transaction_Date__c <= :fechaLimite
      AND (ChargentOrders__Payment_Status__c = 'Recurring'
           OR ChargentOrders__Payment_Status__c = 'Stopped')
      AND Contract__c != NULL
];

if (ordersFiltrados.isEmpty()) {
    System.debug('→ No hay Orders próximos a procesar.');
    return;
}

// Agrupar Orders por contrato
Map<Id, List<ChargentOrders__ChargentOrder__c>> ordersPorContrato = new Map<Id, List<ChargentOrders__ChargentOrder__c>>();
Set<Id> contractIds = new Set<Id>();

for (ChargentOrders__ChargentOrder__c o : ordersFiltrados) {
    contractIds.add(o.Contract__c);
    if (!ordersPorContrato.containsKey(o.Contract__c)) {
        ordersPorContrato.put(o.Contract__c, new List<ChargentOrders__ChargentOrder__c>());
    }
    ordersPorContrato.get(o.Contract__c).add(o);
}

// 2️⃣ Traer solo los contratos activos que tienen Orders próximos
List<Contract> contratos = [
    SELECT Id, AccountId, ContractNumber, SM_Payment_Method__c,
           SM_Billing_Address__r.State, SM_Billing_Address__r.Country
    FROM Contract
    WHERE Id IN :contractIds
      AND Status NOT IN ('Cancelled', 'Finalized')
      AND SM_Plan_Months__c = 99
      AND SM_Customer_Cancellation__c = false
      AND Is_Test_Contract__c = false
      AND Is_VIP_Contract__c = false
      AND SM_Payment_Method__c != NULL
];

if (contratos.isEmpty()) {
    System.debug('→ No hay contratos activos con Orders próximos.');
    return;
}

// 3️⃣ Traer los Payment Methods activos de esos contratos
Set<Id> pmIds = new Set<Id>();
for (Contract c : contratos) pmIds.add(c.SM_Payment_Method__c);

Map<Id, SM_Payment_Method__c> pmMap = new Map<Id, SM_Payment_Method__c>([
    SELECT Id, SM_Active__c, SM_Account__c,
           SM_Card_Token__c, SM_Credit_Card_Number__c,
           SM_Credit_Card_expiration_month__c, SM_Credit_Card_expiration_year__c
    FROM SM_Payment_Method__c
    WHERE Id IN :pmIds
      AND SM_Active__c = TRUE
]);

// 4️⃣ Evaluar inconsistencias
List<Contract> contratosConProblemas = new List<Contract>();

for (Contract c : contratos) {

    if (!pmMap.containsKey(c.SM_Payment_Method__c)) continue;

    SM_Payment_Method__c pm = pmMap.get(c.SM_Payment_Method__c);

    // Validar que el PM pertenece a la misma cuenta
    if (pm.SM_Account__c != c.AccountId) continue;

    // Datos del PM
    String pmToken   = pm.SM_Card_Token__c;
    String pmLast4   = pm.SM_Credit_Card_Number__c != null ? pm.SM_Credit_Card_Number__c.right(4) : null;
    String pmMonth   = pm.SM_Credit_Card_expiration_month__c;
    String pmYear    = pm.SM_Credit_Card_expiration_year__c;
    String pmCountry = (c.SM_Billing_Address__r.State == 'Puerto Rico') ? 'PR' : c.SM_Billing_Address__r.Country;

    // Orders del contrato dentro del rango
    List<ChargentOrders__ChargentOrder__c> ords = ordersPorContrato.get(c.Id);

    Boolean contratoTieneProblemas = false;

    for (ChargentOrders__ChargentOrder__c o : ords) {

        Boolean mismatch =
            (o.ChargentOrders__Tokenization__c != pmToken) ||
            (o.ChargentOrders__Card_Last_4__c != pmLast4) ||
            (o.ChargentOrders__Card_Expiration_Month__c != pmMonth) ||
            (o.ChargentOrders__Card_Expiration_Year__c != pmYear) ||
            (o.ChargentOrders__Billing_Country__c != pmCountry);

        if (mismatch) {
            contratoTieneProblemas = true;
            System.debug('→❌ Order inconsistente | Contrato: ' + c.ContractNumber +
                         '→ | Order: ' + o.Id + ' (' + o.Name + ')' +
                         '→ | NextTxDate: ' + o.ChargentOrders__Next_Transaction_Date__c);
        }
    }

    if (contratoTieneProblemas) {
        contratosConProblemas.add(c);
    }
}

// 5️⃣ Resultado final
System.debug('→ Total contratos con inconsistencias: ' + contratosConProblemas.size());
for (Contract c : contratosConProblemas) {
    System.debug('→ - Contrato: ' + c.ContractNumber + ' | Id: ' + c.Id);
}