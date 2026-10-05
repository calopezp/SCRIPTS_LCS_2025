/*
 * -CrearPaymentDuplicado_PY01907644_y_Activar00318577.apex
 * -----------------------------------------------------------
 * Contrato 00318577 / PY-01907644 -- mismo lote de doble transmision
 * 22/23-sep (bug real de A. Generar File Reporte ACH.apex, ver CLAUDE.md 2.2) que ya
 * resolvimos para PY-01907641/00318012. A diferencia de ese caso, aqui
 * nunca llego NINGUN reporte de Returns/Collection (12 dias de silencio
 * total al momento de este script, por debajo del umbral estandar de 15
 * dias de mark_transmitted_accepted.apex -- PY-01907644 esta en su
 * EXCLUSION_NAMES a proposito, ver UTILITARIOS/mark_transmitted_accepted.apex).
 *
 * Confirmado por el usuario (2026-10-05): procesar ya, sin esperar los 3
 * dias restantes al umbral de 15 -- "Aprob. Elba" (ella confirma que el
 * banco SI cobro las 2 transmisiones) queda registrado como texto en
 * SM_Id_Salesforce_LCS__c (ANOTACIONES) en ambos payments, mismo patron de
 * trazabilidad que el resto del proceso -- no hay campo dedicado en
 * Salesforce para esto todavia.
 *
 * Como es tipo AC (no Fee), el proceso tiene un paso extra que
 * PY-01907641 no necesito: activar el contrato (Status='Activated',
 * SM_AC_collected__c=true) y crear su Subscription Order -- mismo patron
 * que scripts/apex/-Activar_Contrato_Individual_y_Subscription.apex
 * (TAREAS_OCASIONALES.md seccion 1), hecho explicito aqui en vez de
 * depender de que el trigger/flow automatico dispare solo con 2 payments
 * ACCEPTED insertados en la misma corrida.
 *
 * MODO DE USO:
 *   - Corre primero con DRY_RUN = true -> solo preview, NO escribe nada.
 *   - Si todo esta correcto, cambia DRY_RUN a false y corre de nuevo.
 */

// ============ CONFIGURACION ============
Boolean DRY_RUN = true; // <-- cambiar a false para ejecutar real
Id ORIGINAL_PAYMENT_ID = 'a24UU000005T5eDYAS'; // PY-01907644
String CONTRACT_NUMBER = '00318577';
// ========================================

System.debug(' -> MODO: ' + (DRY_RUN ? 'DRY RUN' : 'EJECUCION REAL'));

SM_Payment__c original = [
    SELECT Id, Name, SM_Contract__c, SM_ACH_Order__c, RecordTypeId, Payment_Status__c,
           SM_Check_Collection_Status__c, SM_Check_Collection__c, SM_Amount__c, SM_Fee_value__c,
           SM_Type__c, SM_Original_Type__c, SM_Payment_Method__c, SM_ACH_Account_Number__c,
           SM_ACH_Account_Routing_Number__c, SM_Routing_Number_Check_Digit__c, SM_Recurring__c,
           Invoice__c, SM_Concepto_Pago_Cash__c, Installment_number__c,
           SM_P_IVU_Municipal_Amount__c, SM_P_IVU_State_Amount__c, SM_Payment_Date__c,
           SM_Id_Salesforce_LCS__c
    FROM SM_Payment__c
    WHERE Id = :ORIGINAL_PAYMENT_ID
];

String notaComun = 'MANUAL: Backfill cobro ACH duplicado real (transmitido 2 veces, 22/23-sep, sin reporte en 12 dias) -- Aprob. Elba - ' + Date.today().format();

SM_Payment__c dup = new SM_Payment__c(
    SM_Contract__c                = original.SM_Contract__c,
    SM_ACH_Order__c               = original.SM_ACH_Order__c,
    RecordTypeId                  = original.RecordTypeId,
    Payment_Status__c             = 'ACCEPTED',
    SM_Check_Collection_Status__c = 'COLLECTED',
    SM_Check_Collection__c        = true,
    SM_Amount__c                  = original.SM_Amount__c,
    SM_Fee_value__c               = original.SM_Fee_value__c,
    SM_Type__c                    = original.SM_Type__c,
    SM_Original_Type__c           = original.SM_Original_Type__c,
    SM_Payment_Method__c          = original.SM_Payment_Method__c,
    SM_ACH_Account_Number__c      = original.SM_ACH_Account_Number__c,
    SM_ACH_Account_Routing_Number__c = original.SM_ACH_Account_Routing_Number__c,
    SM_Routing_Number_Check_Digit__c = original.SM_Routing_Number_Check_Digit__c,
    SM_Recurring__c               = original.SM_Recurring__c,
    Invoice__c                    = original.Invoice__c,
    SM_Concepto_Pago_Cash__c      = original.SM_Concepto_Pago_Cash__c,
    Installment_number__c         = original.Installment_number__c,
    SM_P_IVU_Municipal_Amount__c  = original.SM_P_IVU_Municipal_Amount__c,
    SM_P_IVU_State_Amount__c      = original.SM_P_IVU_State_Amount__c,
    SM_Payment_Date__c            = original.SM_Payment_Date__c,
    SM_Id_Salesforce_LCS__c       = notaComun + ' -- ver ' + original.Name
);

String origNoteCombined = String.isBlank(original.SM_Id_Salesforce_LCS__c)
    ? notaComun
    : notaComun + ' // ' + original.SM_Id_Salesforce_LCS__c;
if (origNoteCombined.length() > 255) { origNoteCombined = origNoteCombined.substring(0, 255); }

System.debug(' -> PREVIEW original -> ACCEPTED/COLLECTED, ANOTACIONES: ' + origNoteCombined);
System.debug(' -> PREVIEW nuevo payment -> $' + dup.SM_Amount__c + ', ANOTACIONES: ' + dup.SM_Id_Salesforce_LCS__c);

Contract cont = [
    SELECT Id, ContractNumber, Status, SM_Net_AC__c, SM_AC_Split_Date__c, SM_Payment_methods__c,
           SM_AC_collected__c, Contract_Type__c, Is_Test_Contract__c, Is_VIP_Contract__c,
           SM_Full_Payment__c, SM_Customer_Cancellation__c, SM_Requires_RC_Payment__c,
           SM_Billing_status__c, CB_Subscription__c, SM_Email_to_send_contract__c,
           SM_Start_date__c, SM_Net_Monthly_offer__c, SM_Payment_Method__c
    FROM Contract
    WHERE ContractNumber = :CONTRACT_NUMBER
    LIMIT 1
];
Integer subscriptionsExistentes = [
    SELECT COUNT() FROM SM_ACH_Order__c WHERE SM_Contract__c = :cont.Id AND SM_Payment_Type__c = 'Subscription'
];
System.debug(' -> Contrato ' + cont.ContractNumber + ' -> Status actual: ' + cont.Status +
    ' | SM_AC_collected__c: ' + cont.SM_AC_collected__c + ' | Subscription orders existentes: ' + subscriptionsExistentes);

if (subscriptionsExistentes > 0) {
    System.debug(' -> ***** ABORTADO: ya existe una Subscription Order -- revisar manualmente, no correr este script dos veces.');
} else if (!DRY_RUN) {
    SM_TriggerHandler.avoidAllHandlerExcecution = true;
    try {
        original.Payment_Status__c = 'ACCEPTED';
        original.SM_Check_Collection_Status__c = 'COLLECTED';
        original.SM_Check_Collection__c = true;
        original.SM_Id_Salesforce_LCS__c = origNoteCombined;
        update original;
        System.debug(' -> Original actualizado: ' + original.Name);

        insert dup;
        SM_Payment__c dupQueried = [SELECT Name FROM SM_Payment__c WHERE Id = :dup.Id];
        System.debug(' -> Payment creado: ' + dupQueried.Name);
    } finally {
        SM_TriggerHandler.avoidAllHandlerExcecution = false;
    }

    // Activar contrato + crear Subscription Order (mismo patron que
    // -Activar_Contrato_Individual_y_Subscription.apex)
    cont.Status = 'Activated';
    cont.SM_Charged_AC_Amount__c = cont.SM_Net_AC__c;
    cont.SM_AC_collected__c = true;
    cont.SM_Payment_Received__c = true;
    cont.SM_Charged_AC_Fees__c = cont.SM_AC_Split_Date__c != null ? 2 : 1;
    update cont;

    Contract fresh = [
        SELECT Id, Status, SM_Payment_methods__c, SM_AC_collected__c, Contract_Type__c,
               Is_Test_Contract__c, Is_VIP_Contract__c, SM_Full_Payment__c,
               SM_Customer_Cancellation__c, SM_Requires_RC_Payment__c, SM_Billing_status__c,
               CB_Subscription__c, SM_Email_to_send_contract__c, SM_Start_date__c,
               SM_Net_Monthly_offer__c, SM_Payment_Method__c
        FROM Contract WHERE Id = :cont.Id
    ];
    Map<String, Object> params = new Map<String, Object>{ 'sf_Contract' => fresh };
    Flow.Interview.CONTRACT_Create_ACH_Subscription_Order interview =
        new Flow.Interview.CONTRACT_Create_ACH_Subscription_Order(params);
    interview.start();

    Integer subCountFinal = [SELECT COUNT() FROM SM_ACH_Order__c WHERE SM_Contract__c = :cont.Id AND SM_Payment_Type__c = 'Subscription'];
    System.debug(' -> COMPLETADO -> Contrato ' + cont.ContractNumber + ' Status=' + fresh.Status +
        ' AC_collected=' + fresh.SM_AC_collected__c + ' Subscription Orders=' + subCountFinal);
} else {
    System.debug(' -> DRY RUN activo: no se escribio nada. Cambia DRY_RUN a false para aplicar.');
}
