/*
 * -CONTRACARGO_ACH_R10_R11.apex
 * -------------------------------
 * Proceso para tratar un retorno R10 (cliente no autoriza el cobro) o R11
 * (entry not per authorization terms) como lo que realmente es: un
 * CONTRACARGO, no una reversion del cobro.
 *
 * REGLA ACTUALIZADA (confirmada por el usuario 2026-10-04, reemplaza la regla
 * anterior documentada en CLAUDE.md seccion 2.2 "Regla R10"):
 *   - El payment ORIGINAL se deja/marca como cobrado de verdad
 *     (Payment_Status__c='ACCEPTED', SM_Check_Collection_Status__c='COLLECTED'
 *     -- mismo par que usa el pipeline real de Check Collection, ver
 *     update_check_collection.apex linea 316) -- YA NO se revierte a
 *     NOT_COLLECTED como se hacia antes (ver TEMP/fix_py01895438_r11_2026.apex,
 *     TEMP/fix_py01904884_r11_2026.apex -- ambos aplicaron la regla vieja y
 *     quedan pendientes de revision aparte).
 *   - Se crea un SEGUNDO SM_Payment__c con Payment_Status__c='REFUNDED',
 *     montos en NEGATIVO, SM_Payments_refunded__c apuntando al original,
 *     SM_Reason_for_refund__c = 'CONTRA CARGO (R10/R11)' (valor de picklist
 *     dedicado que ya existia en el campo pero que el script generico de
 *     Chargebee -CONTRACARGO_CHARGEBEE.apex no usaba -- ese usa el generico
 *     'CONTRA CARGO').
 *   - Confirmado explicitamente por el usuario: esto aplica SIEMPRE que haya
 *     un R10/R11, incluso si el payment nunca llego a ACCEPTED/COLLECTED de
 *     verdad antes del retorno (a diferencia de un contracargo "tipico" de
 *     tarjeta, que por definicion solo existe sobre una transaccion ya
 *     capturada) -- no se intento mantener la distincion "solo si hubo cobro
 *     real primero".
 *   - El RE-COBRO automatico (Late Payment Fee ACH / Charge Request TC) que
 *     -CONTRACARGO_CHARGEBEE.apex si ejecuta siempre, aqui es OPCIONAL
 *     (ver CREAR_RECOBRO mas abajo) -- debe evaluarse caso por caso. Ejemplo
 *     real donde NO aplica: PY-01907642/00318146, parte de un lote de 5
 *     payments transmitidos 2 veces por un bug real de -A.ReporteACHFile (no
 *     excluye payments aun ACH PENDING de la siguiente corrida) -- el R10 ahi
 *     es casi seguro el cliente disputando el COBRO DUPLICADO (error de LCS),
 *     y volver a cobrarle con un Late Payment Fee seria cobrarle de nuevo por
 *     nuestro propio error.
 *
 * Adaptado de -CONTRACARGO_CHARGEBEE.apex (Agosto 2026, Carlos Lopez): mismo
 * patron de creacion del Payment REFUNDED y del recobro, pero la busqueda del
 * payment original aqui es por Name (se identifica cruzando el reporte real
 * de ACH Returns, SM_Return_code__c='R10'/'R11'), no por
 * SM_Authorization_Code__c (ese campo es para contracargos de Chargebee/TC
 * reportados con codigo de autorizacion, no aplica a retornos ACH).
 *
 * MODO DE USO:
 *   - Completar PAYMENT_NAME, RETURN_CODE, CREAR_RECOBRO abajo.
 *   - Corre primero con DRY_RUN = true -> solo preview, NO escribe nada.
 *   - Si todo esta correcto, cambia DRY_RUN a false y corre de nuevo.
 */

// ============ CONFIGURACION ============
Boolean DRY_RUN = true;              // <-- cambiar a false para ejecutar real
String PAYMENT_NAME = 'PY-01907642'; // <-- payment con el R10/R11 real
String RETURN_CODE = 'R10';          // <-- 'R10' o 'R11', segun el reporte real
Boolean CREAR_RECOBRO = false;       // <-- true = tambien crea Late Payment Fee/Charge Request para recobrar
// ========================================

if (RETURN_CODE != 'R10' && RETURN_CODE != 'R11') {
    System.debug(' -> ERROR: RETURN_CODE debe ser R10 o R11. Abortando.');
    return;
}

System.debug(' -> ======================================================');
System.debug(' -> MODO: ' + (DRY_RUN ? 'DRY RUN (solo preview, sin cambios)' : 'EJECUCION REAL'));
System.debug(' -> Payment: ' + PAYMENT_NAME + ' | Return code: ' + RETURN_CODE + ' | Crear recobro: ' + CREAR_RECOBRO);
System.debug(' -> ======================================================');

SM_Payment__c original = [
    SELECT Id, Name, SM_Contract__c, SM_ACH_Order__c, RecordTypeId, Payment_Status__c,
           SM_Check_Collection_Status__c, SM_Check_Collection__c, SM_Amount__c, SM_Fee_value__c,
           SM_Penalty_value__c, SM_Type__c, SM_Original_Type__c, SM_Payment_Method__c,
           SM_ACH_Account_Number__c, SM_ACH_Account_Routing_Number__c, SM_Routing_Number_Check_Digit__c,
           SM_Recurring__c, Invoice__c, SM_Concepto_Pago_Cash__c, Installment_number__c,
           SM_P_IVU_Municipal_Amount__c, SM_P_IVU_State_Amount__c, SM_Payment_Date__c,
           SM_Historical_Collection_Status__c, SM_Id_Salesforce_LCS__c,
           SM_Contract__r.ContractNumber, SM_Contract__r.Status, SM_Contract__r.Is_Test_Contract__c,
           SM_Contract__r.Is_VIP_Contract__c, SM_Contract__r.SM_Customer_Cancellation__c
    FROM SM_Payment__c
    WHERE Name = :PAYMENT_NAME
    LIMIT 1
];

System.debug(' -> Original: ' + original.Name + ' | Contrato ' + original.SM_Contract__r.ContractNumber +
    ' (' + original.SM_Contract__r.Status + ') | Estado actual: ' + original.Payment_Status__c + '/' + original.SM_Check_Collection_Status__c);

if (original.SM_Contract__r.Is_Test_Contract__c == true || original.SM_Contract__r.Is_VIP_Contract__c == true) {
    System.debug(' -> ***** ABORTADO (Test/VIP) -- revisar manualmente.');
    return;
}

// Evita duplicar el REFUND si ya se corrio este script antes para este payment
List<SM_Payment__c> existingRefunds = [
    SELECT Id, Name FROM SM_Payment__c
    WHERE SM_Payments_refunded__c = :original.Id AND Payment_Status__c = 'REFUNDED'
];
if (!existingRefunds.isEmpty()) {
    System.debug(' -> ***** ABORTADO: ya existe un Payment REFUNDED para ' + original.Name + ' -> ' + existingRefunds[0].Name);
    return;
}

// -----------------------------
// 1) Payment original -> queda como cobrado (ACCEPTED/COLLECTED)
// -----------------------------
String histTag = 'PRC_AUT_CONTRACARGO_' + RETURN_CODE + ': ACCEPTED/COLLECTED //';
String histPrevious = original.SM_Historical_Collection_Status__c == null ? '' : original.SM_Historical_Collection_Status__c;
String histNew = histTag + histPrevious;
if (histNew.length() > 150) {
    histNew = histNew.substring(0, 150);
}

String origNote = 'MANUAL: Contracargo ' + RETURN_CODE + ' -- se creara/creo Payment REFUNDED - ' + Date.today().format();
String origNoteCombined = String.isBlank(original.SM_Id_Salesforce_LCS__c) ? origNote : origNote + ' // ' + original.SM_Id_Salesforce_LCS__c;
if (origNoteCombined.length() > 255) {
    origNoteCombined = origNoteCombined.substring(0, 255);
}

System.debug(' -> PREVIEW original -> Payment_Status__c: ACCEPTED | SM_Check_Collection_Status__c: COLLECTED');
System.debug(' -> PREVIEW original -> Historico: [' + histNew + ']');
System.debug(' -> PREVIEW original -> ANOTACIONES: [' + origNoteCombined + ']');

// -----------------------------
// 2) Crear Payment REFUNDED
// -----------------------------
SM_Payment__c refund = new SM_Payment__c(
    RecordTypeId                 = original.RecordTypeId,
    Payment_Status__c            = 'REFUNDED',
    SM_Check_Collection_Status__c = null,
    SM_Reason_for_refund__c      = 'CONTRA CARGO (R10/R11)',
    SM_Return_code__c            = RETURN_CODE,
    SM_Contract__c                = original.SM_Contract__c,
    SM_ACH_Order__c              = original.SM_ACH_Order__c,
    SM_Amount__c                  = (original.SM_Amount__c != null) ? original.SM_Amount__c * -1 : null,
    SM_Fee_value__c                = (original.SM_Fee_value__c != null) ? original.SM_Fee_value__c * -1 : null,
    SM_Penalty_value__c           = (original.SM_Penalty_value__c != null) ? original.SM_Penalty_value__c * -1 : null,
    SM_Payments_refunded__c      = original.Id,
    SM_Type__c                    = original.SM_Type__c,
    SM_Original_Type__c          = original.SM_Original_Type__c,
    SM_Payment_Method__c         = original.SM_Payment_Method__c,
    SM_ACH_Account_Number__c     = original.SM_ACH_Account_Number__c,
    SM_ACH_Account_Routing_Number__c = original.SM_ACH_Account_Routing_Number__c,
    SM_Routing_Number_Check_Digit__c = original.SM_Routing_Number_Check_Digit__c,
    SM_Recurring__c              = original.SM_Recurring__c,
    Invoice__c                    = original.Invoice__c,
    SM_Concepto_Pago_Cash__c     = original.SM_Concepto_Pago_Cash__c,
    Installment_number__c        = original.Installment_number__c,
    SM_P_IVU_Municipal_Amount__c = original.SM_P_IVU_Municipal_Amount__c,
    SM_P_IVU_State_Amount__c     = original.SM_P_IVU_State_Amount__c,
    SM_Payment_Due_Date__c       = original.SM_Payment_Date__c,
    SM_Payment_Date__c           = original.SM_Payment_Date__c,
    SM_Id_Salesforce_LCS__c      = 'MANUAL: Contracargo ' + RETURN_CODE + ' -- ver ' + original.Name + ' - ' + Date.today().format()
);

System.debug(' -> PREVIEW REFUND -> Monto: ' + refund.SM_Amount__c + ' | Contrato: ' + refund.SM_Contract__c +
    ' | ACH Order: ' + refund.SM_ACH_Order__c + ' | Razon: ' + refund.SM_Reason_for_refund__c);
System.debug(' -> PREVIEW REFUND -> ANOTACIONES: ' + refund.SM_Id_Salesforce_LCS__c);

if (!CREAR_RECOBRO) {
    System.debug(' -> Recobro (Late Payment Fee / Charge Request): OMITIDO (CREAR_RECOBRO=false) -- revisar manualmente si corresponde cobrarle de nuevo al cliente.');
}

System.debug(' -> ======================================================');

if (!DRY_RUN) {
    SM_TriggerHandler.avoidAllHandlerExcecution = true;
    try {
        original.Payment_Status__c = 'ACCEPTED';
        original.SM_Check_Collection_Status__c = 'COLLECTED';
        original.SM_Check_Collection__c = true;
        original.SM_Historical_Collection_Status__c = histNew;
        original.SM_Id_Salesforce_LCS__c = origNoteCombined;
        update original;
        System.debug(' -> Original actualizado: ' + original.Name);

        insert refund;
        SM_Payment__c refundQueried = [SELECT Name FROM SM_Payment__c WHERE Id = :refund.Id];
        System.debug(' -> Payment REFUNDED creado: ' + refundQueried.Name + ' (Id ' + refund.Id + ')');

        if (CREAR_RECOBRO) {
            System.debug(' -> CREAR_RECOBRO=true pero este script NO implementa el paso de recobro automaticamente --');
            System.debug(' -> usar -CONTRACARGO_CHARGEBEE.apex (seccion 6 en adelante) como referencia si hace falta, adaptado al contrato/metodo de pago real.');
        }

        System.debug(' -> ======================================================');
        System.debug(' -> COMPLETADO -> original: ' + original.Name + ' (ACCEPTED/COLLECTED) | REFUND: ' + refundQueried.Name);
        System.debug(' -> ======================================================');
    } finally {
        SM_TriggerHandler.avoidAllHandlerExcecution = false;
    }
} else {
    System.debug(' -> DRY RUN activo: no se creo ni actualizo nada. Cambia DRY_RUN a false para aplicar.');
}
