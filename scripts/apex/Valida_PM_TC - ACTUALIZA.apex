// ======================================================================
// CORREGIR TODOS LOS ORDERS ACTIVOS DE CONTRATOS CON INCONSISTENCIAS
// Y GENERAR ARCHIVO CSV CON EL LOG
// ======================================================================

// Fecha límite: hoy + 5 días
Date fechaLimite = Date.today().addDays(5);

// 1️⃣ Traer solo Orders relevantes (NextTxDate <= hoy+5)
List<ChargentOrders__ChargentOrder__c> ordersFiltrados = [
    SELECT Id, Name, Contract__c,
           ChargentOrders__Next_Transaction_Date__c, 

           ChargentOrders__Billing_Country__c,
           ChargentOrders__Tokenization__c,

           ChargentOrders__Card_Last_4__c,
           ChargentOrders__Card_Expiration_Month__c,
           ChargentOrders__Card_Expiration_Year__c,

           ChargentOrders__Card_Number__c,
           ChargentOrders__Card_Month_Indicator__c, 
           ChargentOrders__Card_Year_Indicator__c

    FROM ChargentOrders__ChargentOrder__c
    WHERE ChargentOrders__Next_Transaction_Date__c <= :fechaLimite
      AND ChargentOrders__Payment_Status__c = 'Recurring'
      AND Contract__c != NULL
      //AND Contract__r.ContractNumber = '00310680'
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

// 4️⃣ Corrección + Log CSV
List<ChargentOrders__ChargentOrder__c> ordersParaActualizar = new List<ChargentOrders__ChargentOrder__c>();
String csv = 'ContractNumber,ContractId,OrderId,OrderName,NextTxDate,Campo,ValorAnterior,ValorNuevo\n';

// Para detectar contratos con inconsistencias
Set<Id> contratosConProblemas = new Set<Id>();

// 4A️⃣ Detectar inconsistencias usando solo Orders próximos
for (Contract c : contratos) {

    if (!pmMap.containsKey(c.SM_Payment_Method__c)) continue;

    SM_Payment_Method__c pm = pmMap.get(c.SM_Payment_Method__c);
    if (pm.SM_Account__c != c.AccountId) continue;

    String pmToken   = pm.SM_Card_Token__c;
    String pmLast4   = pm.SM_Credit_Card_Number__c != null ? pm.SM_Credit_Card_Number__c.right(4) : null;
    String pmMonth   = pm.SM_Credit_Card_expiration_month__c;
    String pmYear    = pm.SM_Credit_Card_expiration_year__c;
    String pmCountry = (c.SM_Billing_Address__r.State == 'Puerto Rico') ? 'PR' : c.SM_Billing_Address__r.Country;
  
    List<ChargentOrders__ChargentOrder__c> ords = ordersPorContrato.get(c.Id);

    for (ChargentOrders__ChargentOrder__c o : ords) {

        Boolean mismatch =
            (o.ChargentOrders__Tokenization__c != pmToken) ||

            (o.ChargentOrders__Card_Last_4__c != pmLast4) ||
            (o.ChargentOrders__Card_Expiration_Month__c != pmMonth) ||
            (o.ChargentOrders__Card_Expiration_Year__c != pmYear) ||
            (o.ChargentOrders__Billing_Country__c != pmCountry) ||

            (o.ChargentOrders__Card_Number__c != pmLast4) ||
            (o.ChargentOrders__Card_Month_Indicator__c != pmMonth) ||
            (o.ChargentOrders__Card_Year_Indicator__c != pmYear);

        if (mismatch) {
            contratosConProblemas.add(c.Id);
            break;
        }
    }
}

// 4B️⃣ Si un contrato tiene inconsistencias → actualizar TODOS sus Orders activos
if (!contratosConProblemas.isEmpty()) {

    // Traer todos los Orders activos de esos contratos
    List<ChargentOrders__ChargentOrder__c> allOrders = [
        SELECT Id, Name, Contract__c,
           ChargentOrders__Next_Transaction_Date__c, 

           ChargentOrders__Billing_Country__c,
           ChargentOrders__Tokenization__c,

           ChargentOrders__Card_Last_4__c,
           ChargentOrders__Card_Expiration_Month__c,
           ChargentOrders__Card_Expiration_Year__c,

           ChargentOrders__Card_Number__c,
           ChargentOrders__Card_Month_Indicator__c, 
           ChargentOrders__Card_Year_Indicator__c

           FROM ChargentOrders__ChargentOrder__c
        WHERE Contract__c IN :contratosConProblemas
          AND ChargentOrders__Payment_Status__c IN ('Recurring','Stopped')
    ];

    // Agrupar Orders completos por contrato
    Map<Id, List<ChargentOrders__ChargentOrder__c>> allOrdersMap = new Map<Id, List<ChargentOrders__ChargentOrder__c>>();
    for (ChargentOrders__ChargentOrder__c o : allOrders) {
        if (!allOrdersMap.containsKey(o.Contract__c)) {
            allOrdersMap.put(o.Contract__c, new List<ChargentOrders__ChargentOrder__c>());
        }
        allOrdersMap.get(o.Contract__c).add(o);
    }

    // Actualizar todos los Orders de contratos con inconsistencias
    for (Contract c : contratos) {

        if (!contratosConProblemas.contains(c.Id)) continue;

        SM_Payment_Method__c pm = pmMap.get(c.SM_Payment_Method__c);

        String pmToken   = pm.SM_Card_Token__c;
        String pmLast4   = pm.SM_Credit_Card_Number__c != null ? pm.SM_Credit_Card_Number__c.right(4) : null;
        String pmMonth   = pm.SM_Credit_Card_expiration_month__c;
        String pmYear    = pm.SM_Credit_Card_expiration_year__c;
        String pmCountry = (c.SM_Billing_Address__r.State == 'Puerto Rico') ? 'PR' : c.SM_Billing_Address__r.Country;

        List<ChargentOrders__ChargentOrder__c> ords = allOrdersMap.get(c.Id);

        for (ChargentOrders__ChargentOrder__c o : ords) {

            // TOKEN
            if (o.ChargentOrders__Tokenization__c != pmToken) {
                csv += c.ContractNumber + ',' + c.Id + ',' + o.Id + ',' + o.Name + ',' +
                       o.ChargentOrders__Next_Transaction_Date__c + ',Token,' +
                       o.ChargentOrders__Tokenization__c + ',' + pmToken + '\n';
                o.ChargentOrders__Tokenization__c = pmToken;
            }

            // LAST 4
            if (o.ChargentOrders__Card_Last_4__c != pmLast4 || o.ChargentOrders__Card_Number__c != pmLast4) {
                csv += c.ContractNumber + ',' + c.Id + ',' + o.Id + ',' + o.Name + ',' +
                       o.ChargentOrders__Next_Transaction_Date__c + ',Last4,' +
                       o.ChargentOrders__Card_Last_4__c + ',' + pmLast4 + 
                       o.ChargentOrders__Card_Number__c + ',' + pmLast4 + '\n';
                o.ChargentOrders__Card_Last_4__c = pmLast4;
                o.ChargentOrders__Card_Number__c = pmLast4;
            }

            // MONTH
            if (o.ChargentOrders__Card_Expiration_Month__c != pmMonth || o.ChargentOrders__Card_Month_Indicator__c != pmMonth) {
                csv += c.ContractNumber + ',' + c.Id + ',' + o.Id + ',' + o.Name + ',' +
                       o.ChargentOrders__Next_Transaction_Date__c + ',Month,' +
                       o.ChargentOrders__Card_Expiration_Month__c + ',' + pmMonth +
                       o.ChargentOrders__Card_Month_Indicator__c + ',' + pmMonth + '\n';
                o.ChargentOrders__Card_Expiration_Month__c = pmMonth;
                o.ChargentOrders__Card_Month_Indicator__c = pmMonth;
            }

            // YEAR
            if (o.ChargentOrders__Card_Expiration_Year__c != pmYear || o.ChargentOrders__Card_Year_Indicator__c != pmYear) {
                csv += c.ContractNumber + ',' + c.Id + ',' + o.Id + ',' + o.Name + ',' +
                       o.ChargentOrders__Next_Transaction_Date__c + ',Year,' +
                       o.ChargentOrders__Card_Expiration_Year__c + ',' + pmYear +
                       o.ChargentOrders__Card_Year_Indicator__c + ',' + pmYear + '\n';
                o.ChargentOrders__Card_Expiration_Year__c = pmYear;                
                o.ChargentOrders__Card_Year_Indicator__c = pmYear;
            }

            // COUNTRY
            if (o.ChargentOrders__Billing_Country__c != pmCountry) {
                csv += c.ContractNumber + ',' + c.Id + ',' + o.Id + ',' + o.Name + ',' +
                       o.ChargentOrders__Next_Transaction_Date__c + ',Country,' +
                       o.ChargentOrders__Billing_Country__c + ',' + pmCountry + '\n';
                o.ChargentOrders__Billing_Country__c = pmCountry;
            }

            ordersParaActualizar.add(o);
        }
    }
}

// 5️⃣ Guardar cambios
if (!ordersParaActualizar.isEmpty()) {
    update ordersParaActualizar;
    System.debug('→ ✔ Orders actualizados: ' + ordersParaActualizar.size());
} else {
    System.debug('→ No se encontraron Orders para corregir.');
}

// 6️⃣ Generar archivo CSV en Base64
Blob csvBlob = Blob.valueOf(csv);
String base64Csv = EncodingUtil.base64Encode(csvBlob);

System.debug('→ === ARCHIVO CSV (COPIAR Y PEGAR EN UN DECODIFICADOR BASE64) ===');
System.debug('→' + base64Csv);
