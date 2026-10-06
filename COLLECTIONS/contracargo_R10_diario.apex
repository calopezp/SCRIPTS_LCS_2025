/*
 * contracargo_R10_diario.apex
 * ----------------------------
 * Paso diario de run_daily_new_files.sh: aplica la regla de contracargo R10/R11
 * (CLAUDE.md seccion 2.2, regla vigente 2026-10-04) a los R10/R11 NUEVOS.
 *
 * Solo toma payments que:
 *   - tienen SM_Return_code__c R10 o R11,
 *   - quedaron en REJECTED con RETURN/PENDING y fueron tocados HOY por la corrida
 *     (LastModifiedDate = TODAY), es decir, llegaron en el reporte de esta corrida,
 *   - se transmitieron en los ultimos 60 dias (no toca el backlog pre-2026),
 *   - no tienen ya un Payment REFUNDED,
 *   - no son de contratos Test/VIP.
 *
 * Tratamiento (igual que -CONTRACARGO_ACH_R10_R11.apex, sin recobro):
 *   - original -> ACCEPTED / COLLECTED, historico PRC_AUT_CONTRACARGO_<code>, nota AUTO,
 *   - Payment REFUNDED en negativo, SM_Payments_refunded__c, motivo CONTRA CARGO (R10/R11).
 *
 * Sin triggers (SM_TriggerHandler.avoidAllHandlerExcecution), como el script manual.
 * Un Task por contrato tratado, con el dueno por defecto de quien corre el script (no fijo).
 * NO se aplica si el payment aparece en dos transmisiones ACH: esa verificacion es
 * manual (ver TAREAS_PENDIENTES.md). El .apex del repo queda en DRY_RUN=true; el
 * script de la corrida diaria copia a un temporal y lo pone en false solo en modo apply.
 */

Boolean DRY_RUN = true; // <-- el paso diario cambia esto solo en el temporal (modo apply)

List<SM_Payment__c> candidatos = [
    SELECT Id, Name, RecordTypeId, SM_Contract__c, SM_ACH_Order__c, Payment_Status__c,
           SM_Check_Collection_Status__c, SM_Check_Collection__c, SM_Amount__c, SM_Fee_value__c,
           SM_Penalty_value__c, SM_Type__c, SM_Original_Type__c, SM_Payment_Method__c,
           SM_ACH_Account_Number__c, SM_ACH_Account_Routing_Number__c, SM_Routing_Number_Check_Digit__c,
           SM_Recurring__c, Invoice__c, SM_Concepto_Pago_Cash__c, Installment_number__c,
           SM_P_IVU_Municipal_Amount__c, SM_P_IVU_State_Amount__c, SM_Payment_Date__c,
           SM_Historical_Collection_Status__c, SM_Id_Salesforce_LCS__c, SM_Return_code__c,
           SM_Contract__r.ContractNumber, SM_Contract__r.Is_Test_Contract__c, SM_Contract__r.Is_VIP_Contract__c
    FROM SM_Payment__c
    WHERE SM_Return_code__c IN ('R10', 'R11')
      AND Payment_Status__c = 'REJECTED'
      AND SM_Check_Collection_Status__c IN ('PENDING', 'RETURN')
      AND LastModifiedDate = TODAY
      AND SM_Transmission_Date_ACH_File__c = LAST_N_DAYS:60
      AND SM_Payments_refunded__c = null
    LIMIT 200
];

Map<Id, Integer> porContrato = new Map<Id, Integer>();
for (SM_Payment__c c : candidatos) {
    porContrato.put(c.SM_Contract__c, porContrato.containsKey(c.SM_Contract__c) ? porContrato.get(c.SM_Contract__c) + 1 : 1);
}

Set<Id> conRefund = new Set<Id>();
for (SM_Payment__c r : [SELECT SM_Payments_refunded__c FROM SM_Payment__c
                        WHERE SM_Payments_refunded__c IN :candidatos AND Payment_Status__c = 'REFUNDED']) {
    conRefund.add(r.SM_Payments_refunded__c);
}

List<SM_Payment__c> originalesAUpdate = new List<SM_Payment__c>();
List<SM_Payment__c> refundsAInsertar = new List<SM_Payment__c>();
Integer omitidos = 0;

for (SM_Payment__c original : candidatos) {
    if (original.SM_Contract__r.Is_Test_Contract__c == true || original.SM_Contract__r.Is_VIP_Contract__c == true || conRefund.contains(original.Id)) {
        omitidos++;
        System.debug('CONTRACARGO_R10_DIARIO OMITIDO -> ' + original.Name + ' (Test/VIP o ya tiene REFUND)');
        continue;
    }
    if (porContrato.get(original.SM_Contract__c) > 1) {
        omitidos++;
        System.debug('CONTRACARGO_R10_DIARIO REVISAR MANUAL -> ' + original.Name + ' (contrato ' + original.SM_Contract__r.ContractNumber +
            ' con mas de un R10/R11 en la misma corrida, no se trata en automatico)');
        continue;
    }

    String code = original.SM_Return_code__c;
    String histNew = ('PRC_AUT_CONTRACARGO_' + code + ': ACCEPTED/COLLECTED //' +
        (original.SM_Historical_Collection_Status__c == null ? '' : original.SM_Historical_Collection_Status__c));
    if (histNew.length() > 150) { histNew = histNew.substring(0, 150); }

    String nota = 'AUTO: Contracargo ' + code + ' diario - REFUND creado - ' + Date.today().format();
    String notaCombinada = String.isBlank(original.SM_Id_Salesforce_LCS__c) ? nota : nota + ' // ' + original.SM_Id_Salesforce_LCS__c;
    if (notaCombinada.length() > 255) { notaCombinada = notaCombinada.substring(0, 255); }

    System.debug('CONTRACARGO_R10_DIARIO -> ' + original.Name + ' | contrato ' + original.SM_Contract__r.ContractNumber +
        ' | ' + code + ' | $' + original.SM_Amount__c + ' | ' + original.Payment_Status__c + '/' + original.SM_Check_Collection_Status__c +
        ' -> ACCEPTED/COLLECTED + REFUND');

    original.Payment_Status__c = 'ACCEPTED';
    original.SM_Check_Collection_Status__c = 'COLLECTED';
    original.SM_Check_Collection__c = true;
    original.SM_Historical_Collection_Status__c = histNew;
    original.SM_Id_Salesforce_LCS__c = notaCombinada;
    originalesAUpdate.add(original);

    refundsAInsertar.add(new SM_Payment__c(
        RecordTypeId = original.RecordTypeId,
        Payment_Status__c = 'REFUNDED',
        SM_Check_Collection_Status__c = null,
        SM_Reason_for_refund__c = 'CONTRA CARGO (R10/R11)',
        SM_Return_code__c = code,
        SM_Contract__c = original.SM_Contract__c,
        SM_ACH_Order__c = original.SM_ACH_Order__c,
        SM_Amount__c = (original.SM_Amount__c != null) ? original.SM_Amount__c * -1 : null,
        SM_Fee_value__c = (original.SM_Fee_value__c != null) ? original.SM_Fee_value__c * -1 : null,
        SM_Penalty_value__c = (original.SM_Penalty_value__c != null) ? original.SM_Penalty_value__c * -1 : null,
        SM_Payments_refunded__c = original.Id,
        SM_Type__c = original.SM_Type__c,
        SM_Original_Type__c = original.SM_Original_Type__c,
        SM_Payment_Method__c = original.SM_Payment_Method__c,
        SM_ACH_Account_Number__c = original.SM_ACH_Account_Number__c,
        SM_ACH_Account_Routing_Number__c = original.SM_ACH_Account_Routing_Number__c,
        SM_Routing_Number_Check_Digit__c = original.SM_Routing_Number_Check_Digit__c,
        SM_Recurring__c = original.SM_Recurring__c,
        Invoice__c = original.Invoice__c,
        SM_Concepto_Pago_Cash__c = original.SM_Concepto_Pago_Cash__c,
        Installment_number__c = original.Installment_number__c,
        SM_P_IVU_Municipal_Amount__c = original.SM_P_IVU_Municipal_Amount__c,
        SM_P_IVU_State_Amount__c = original.SM_P_IVU_State_Amount__c,
        SM_Payment_Due_Date__c = original.SM_Payment_Date__c,
        SM_Payment_Date__c = original.SM_Payment_Date__c,
        SM_Id_Salesforce_LCS__c = 'AUTO: Contracargo ' + code + ' diario -- ver ' + original.Name + ' - ' + Date.today().format()
    ));
}

System.debug('CONTRACARGO_R10_DIARIO -> candidatos: ' + candidatos.size() + ' | a tratar: ' + originalesAUpdate.size() + ' | omitidos: ' + omitidos);

if (!DRY_RUN && !originalesAUpdate.isEmpty()) {
    SM_TriggerHandler.avoidAllHandlerExcecution = true;
    try {
        update originalesAUpdate;
        insert refundsAInsertar;

        List<Task> tareas = new List<Task>();
        for (SM_Payment__c o : originalesAUpdate) {
            tareas.add(new Task(
                WhatId = o.SM_Contract__c,
                RecordTypeId = '0121U00000085XiQAI',
                Subject = 'TIADM - REFUND CONTRA CARGO (R10/R11)',
                Description = 'Contracargo R10/R11 aplicado automaticamente en la corrida del ' + Date.today().format() +
                    ' (' + o.Name + '): original ACCEPTED/COLLECTED + Payment REFUNDED. Sin recobro.',
                Status = 'Completed',
                ActivityDate = Date.today()
            ));
        }
        insert tareas;

        System.debug('CONTRACARGO_R10_DIARIO -> APLICADO: ' + originalesAUpdate.size() + ' originales, ' + refundsAInsertar.size() + ' REFUND, ' + tareas.size() + ' Tasks');
    } finally {
        SM_TriggerHandler.avoidAllHandlerExcecution = false;
    }
} else if (DRY_RUN) {
    System.debug('CONTRACARGO_R10_DIARIO -> DRY RUN: no se escribio nada.');
}
