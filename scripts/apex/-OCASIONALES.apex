// =========================================================
// CONFIGURACIÓN
// =========================================================
Boolean EXECUTE = true; // PREVIEW=false, EXECUTE=true

// =========================================================
// 1) Obtener contratos válidos
// =========================================================
Set<Id> contratoIds = new Set<Id>();

for (SM_Payment__c p : [
    SELECT SM_Contract__c
    FROM SM_Payment__c
    WHERE RecordType.Name = 'ACH'
    AND CreatedDate > 2026-07-22T00:00:00.000+02:00
    AND CreatedDate < 2026-07-24T00:00:00.000+02:00
    AND SM_Contract__c NOT IN (
        '800UU00000jNdmtYAC',
        '800UU00000iFNkaYAG',
        '800UU00000geW17YAE'
    )
]) {
    if (p.SM_Contract__c != null) {
        contratoIds.add(p.SM_Contract__c);
    }
}

System.debug('\u2192 Contratos detectados \uFF5C ' + contratoIds.size());

// =========================================================
// 2) Traer payments ACCEPTED
// =========================================================
List<SM_Payment__c> pagos = [
    SELECT Id, Name, SM_Contract__c, Payment_Status__c,
           CreatedDate, SM_Check_Collection_Status__c,
           SM_Date_ACH_Transmitted__c, SM_Amount__c,
           SM_Payment_Type__c, RecordTypeId,
           SM_Payment_Method__c, SM_Person_Account_Name__c,
           SM_Original_Type__c, SM_ACH_Order__c,
           SM_Type__c, SM_Recurring__c, SM_Payment_Date__c
    FROM SM_Payment__c
    WHERE RecordType.Name = 'ACH'
    AND Payment_Status__c = 'ACCEPTED'
    AND SM_Contract__c IN :contratoIds
    ORDER BY SM_Contract__c, SM_Date_ACH_Transmitted__c DESC
];

System.debug('\u2192 Payments ACCEPTED encontrados \uFF5C ' + pagos.size());

// =========================================================
// 3) Último ACCEPTED por contrato
// =========================================================
Map<Id, SM_Payment__c> ultimoAceptadoPorContrato = new Map<Id, SM_Payment__c>();

for (SM_Payment__c p : pagos) {
    if (!ultimoAceptadoPorContrato.containsKey(p.SM_Contract__c)) {
        ultimoAceptadoPorContrato.put(p.SM_Contract__c, p);
    }
}

System.debug('\u2192 Últimos ACCEPTED por contrato \uFF5C ' + ultimoAceptadoPorContrato.size());

// =========================================================
// 4) Crear REFUNDS
// =========================================================
List<SM_Payment__c> nuevosRefunds = new List<SM_Payment__c>();

Date refundDate = Date.newInstance(2026, 7, 29);
Datetime refundExecution = Datetime.newInstance(2026, 7, 29, 14, 0, 0);

for (Id cid : ultimoAceptadoPorContrato.keySet()) {
    SM_Payment__c original = ultimoAceptadoPorContrato.get(cid);

    SM_Payment__c refund = new SM_Payment__c();

    refund.Payment_Status__c = 'REFUNDED';
    refund.SM_Id_Salesforce_LCS__c = 'REFUND POR AJUSTE DE ABONO CLIENTE 23/24 JULIO';
    refund.SM_Check_Collection__c = true;
    refund.SM_Check_Collection_Status__c = 'REFUNDED';
    refund.SM_Check_Collection_Date__c = refundDate;
    refund.SM_Payments_refunded__c = original.Id;
    refund.SM_Reason_for_refund__c = 'CONTRA CARGO';

    refund.SM_Contract__c = original.SM_Contract__c;
    refund.SM_Payment_Method__c = original.SM_Payment_Method__c;
    refund.SM_Original_Type__c = original.SM_Original_Type__c;
    refund.SM_ACH_Order__c = original.SM_ACH_Order__c;
    refund.SM_Type__c = original.SM_Type__c;
    refund.SM_Amount__c = original.SM_Amount__c * -1;
    refund.SM_Recurring__c = original.SM_Recurring__c;
    refund.SM_Payment_Date__c = original.SM_Payment_Date__c;
    refund.RecordTypeId = original.RecordTypeId;
    refund.SM_Payment_Type__c = original.SM_Payment_Type__c;

    nuevosRefunds.add(refund);

    System.debug('\u2192 REFUND preparado \uFF5C Contrato=' + cid +
                 ' \uFF5C Original=' + original.Id +
                 ' \uFF5C MontoNuevo=' + refund.SM_Amount__c);
}

// =========================================================
// 5) Crear ACH Orders Late Payment Fee
// =========================================================
List<SM_ACH_Order__c> nuevosAchOrders = new List<SM_ACH_Order__c>();

for (Id cid : ultimoAceptadoPorContrato.keySet()) {
    SM_Payment__c original = ultimoAceptadoPorContrato.get(cid);

    SM_ACH_Order__c ach = new SM_ACH_Order__c();

    ach.SM_Apply_penalty__c = false;
    ach.SM_Penalty_value__c = null;
    ach.SM_Penalty_date__c = null;
    ach.SM_User_who_applies_the_penalty__c = null;
    ach.SM_Next_Transaction_Date__c = Date.today();
    ach.SM_Id_Salesforce_LCS__c = 'REFUND POR AJUSTE DE ABONO CLIENTE 23/24 JULIO';

    ach.SM_Contract__c = original.SM_Contract__c;
    ach.SM_Payment_Method__c = original.SM_Payment_Method__c;
    ach.SM_Payment_Type__c = original.SM_Type__c;
    ach.SM_Total__c = original.SM_Amount__c;
    ach.SM_Payment_Start_Date__c = original.SM_Payment_Date__c;

    nuevosAchOrders.add(ach);

    System.debug('\u2192 ACH preparado \uFF5C Contrato=' + cid +
                 ' \uFF5C Original=' + original.Id +
                 ' \uFF5C Monto=' + ach.SM_Total__c);
}

// =========================================================
// 6) Generar CSV Excel-friendly extendido
// =========================================================
String csv = 
'"ContractId","ContractNumber","ContractName","PaymentOriginalId","PaymentOriginalName","PaymentOriginalDate","PaymentOriginalAmount",' +
'"RefundId","RefundAmount","ACHOrderId","ACHOrderName","ACHAmount","ACHPaymentDate"\n';

// Obtener ContractNumber y Contract Name
Map<Id, Contract> contratosMap = new Map<Id, Contract>(
    [SELECT Id, ContractNumber, Name FROM Contract WHERE Id IN :contratoIds]
);

// CORRECCIÓN: Construir Set<Id> con los ACH originales
Set<Id> achOriginalIds = new Set<Id>();
for (SM_Payment__c p : ultimoAceptadoPorContrato.values()) {
    if (p.SM_ACH_Order__c != null) {
        achOriginalIds.add(p.SM_ACH_Order__c);
    }
}

// Obtener ACH original (Name)
Map<Id, SM_ACH_Order__c> achOriginalMap = new Map<Id, SM_ACH_Order__c>(
    [SELECT Id, Name FROM SM_ACH_Order__c WHERE Id IN :achOriginalIds]
);

// Construir CSV
for (Integer i = 0; i < nuevosRefunds.size(); i++) {

    SM_Payment__c original = ultimoAceptadoPorContrato.get(nuevosRefunds[i].SM_Contract__c);
    SM_Payment__c r = nuevosRefunds[i];
    SM_ACH_Order__c a = nuevosAchOrders[i];

    Contract c = contratosMap.get(original.SM_Contract__c);
    SM_ACH_Order__c achOriginal = achOriginalMap.get(original.SM_ACH_Order__c);

    csv += '"' + original.SM_Contract__c + '",' +
           '"' + (c != null ? c.ContractNumber : '') + '",' +
           '"' + (c != null ? c.Name : '') + '",' +
           '"' + original.Id + '",' +
           '"' + original.Name + '",' +
           '"' + String.valueOf(original.SM_Payment_Date__c) + '",' +
           '"' + String.valueOf(original.SM_Amount__c) + '",' +
           '"' + r.Id + '",' +
           '"' + String.valueOf(r.SM_Amount__c) + '",' +
           '"' + a.Id + '",' +
           '"' + (achOriginal != null ? achOriginal.Name : '') + '",' +
           '"' + String.valueOf(a.SM_Total__c) + '",' +
           '"' + String.valueOf(a.SM_Payment_Start_Date__c) + '"\n';
}

System.debug('\u2192 CSV generado (Excel-friendly extendido)\n' + csv);

// =========================================================
// 7) PREVIEW / EXECUTE
// =========================================================
if (!EXECUTE) {
    System.debug('\u2192 MODO PREVIEW \uFF5C No se insertará nada');
    System.debug('\u2192 REFUNDS listos \uFF5C ' + nuevosRefunds.size());
    System.debug('\u2192 ACH Orders listos \uFF5C ' + nuevosAchOrders.size());
} else {
    insert nuevosRefunds;
    insert nuevosAchOrders;
    System.debug('\u2192 MODO EXECUTE \uFF5C REFUNDS y ACH Orders creados correctamente');
}
