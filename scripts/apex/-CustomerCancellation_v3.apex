// ┌──────────────────────────────────────────────────────────────┐
// │ ORDERS EN STOP DE "CUSTOMER CANCELLATION"                    │
// └──────────────────────────────────────────────────────────────┘

Set<String> estadosCerrados = new Set<String>{
    'NOT_COLLECTED', 'COLLECTED', 'ACCEPTED', 'REFUNDED', 'RETURN AFTER COLLECTED', 'Return_after_collected'
};

RecordTypeInfo rti = Schema.SObjectType.SM_Payment__c
    .getRecordTypeInfosByDeveloperName()
    .get('ACH');

if (rti == null) {
    System.debug(' \u2192 ❌ RecordType ACH_Payment no encontrado');
    return;
}

Id achRecordTypeId = rti.getRecordTypeId();
//'0121U000000KZPsQAO'   

// 1. Listar contratos

List<Contract> contratos = [
    SELECT Id, ContractNumber, Status, SM_Payment_methods__c, 
           Is_Test_Contract__c, Is_VIP_Contract__c, SM_Account_Name__c 
    FROM Contract
    WHERE SM_Customer_Cancellation__c = TRUE
      AND Is_Test_Contract__c = FALSE
      AND Is_VIP_Contract__c = FALSE
      AND (NOT SM_Account_Name__c LIKE '%test%')
      AND (NOT SM_Account_Name__c LIKE '%Test%')
      AND (NOT SM_Account_Name__c LIKE '%TEST%')
      AND Status IN ('Activated', 'Payment Process', 'Cancelled')
      //AND ContractNumber = '00313649'
];

if (contratos.isEmpty()) {
    System.debug(' \u2192 \u2192 ❌ No se encontraron contratos');
    return;
}

System.debug(' \u2192 \u2192 ✔ Contratos encontrados: ' + contratos.size());

Set<Id> contratoIds = new Map<Id, Contract>(contratos).keySet();  // más eficiente

// 2. Listamos Payments EN PROCESO de los Contratos ACH
List<SM_Payment__c> pagos = [
    SELECT Id, Name, Payment_Status__c, SM_Check_Collection_Status__c, SM_Net_Amount__c,
           SM_ACH_Order__c, SM_ACH_Order__r.Name, SM_Contract__c, SM_Contract__r.ContractNumber, 
           SM_Date_ACH_Transmitted__c
    FROM SM_Payment__c 
    WHERE RecordTypeId = :achRecordTypeId
      AND SM_Net_Amount__c > 0
      AND SM_Check_Collection_Status__c != null
      AND SM_Check_Collection_Status__c NOT IN :estadosCerrados 
      AND Payment_Status__c NOT IN ('ACCEPTED', 'CANCELLED', 'REFUNDED')
      AND SM_Contract__c IN :contratoIds 
];

Map<Id, List<SM_Payment__c>> pagosPorContrato = new Map<Id, List<SM_Payment__c>>();
for (SM_Payment__c p : pagos) {
    if (!pagosPorContrato.containsKey(p.SM_Contract__c)) {
        pagosPorContrato.put(p.SM_Contract__c, new List<SM_Payment__c>());
    }
    pagosPorContrato.get(p.SM_Contract__c).add(p);
}

// 3. ACH Orders a actualizar
List<SM_ACH_Order__c> achParaActualizar = [
    SELECT Id, Name, SM_Payment_Status__c, SM_Contract__r.ContractNumber
    FROM SM_ACH_Order__c
    WHERE SM_Payment_Status__c NOT IN ('Completed', 'Canceled')
      AND SM_Contract__c IN :contratoIds
];

if (!pagosPorContrato.isEmpty()) {
    // Filtrar los que SÍ tienen pagos en proceso
    for (Integer i = achParaActualizar.size() - 1; i >= 0; i--) {
        if (pagosPorContrato.containsKey(achParaActualizar[i].SM_Contract__c)) {
            achParaActualizar.remove(i);
        }
    }
}

if (!achParaActualizar.isEmpty()) {
    for (SM_ACH_Order__c ord : achParaActualizar) {
        ord.SM_Payment_Status__c = 'Canceled';
        System.debug(' \u2192 \u2192 ✔ ACH Order a actualizar: ' + ord.Name + ' - ' + ord.SM_Contract__r.ContractNumber);
    }
    update achParaActualizar;
    System.debug(' \u2192 \u2192 ✅ ACH Orders actualizados: ' + achParaActualizar.size());
} else {
    System.debug(' \u2192 \u2192 No hay ACH Orders para actualizar');
}