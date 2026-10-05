/*
 * -CrearPaymentDuplicado_PY01907641.apex
 * ---------------------------------------
 * Correccion PUNTUAL (no recurrente): el contrato 00318012 tuvo un cobro ACH
 * real duplicado -- el banco cobro $99 DOS veces (dos reingresos de NSF
 * distintos, cada uno con su propio Check Number y trace number reales), pero
 * Salesforce solo tiene UN SM_Payment__c (PY-01907641) reflejando ese cobro.
 *
 * Evidencia cruzada contra los indices reales (nunca contra SM_Payment__History,
 * ver CLAUDE.md seccion 2.2):
 *   - RETURNS: 2 RETURN/R01 NSF distintos (24-sep trace batch 0000466,
 *     25-sep trace batch 0000573) -- 2 trace numbers reales en
 *     SM_Bank_Reference_Number__c de PY-01907641: "RTN:021502013519931 |
 *     RTN:021502014195191".
 *   - COLLECTIONS: 2 Check Numbers distintos (00003399177 del 24-sep,
 *     00003462154 del 25-sep) -- el reporte del 1-oct
 *     (CheckCollectionDailyReport_10012026.pdf) confirma AMBOS como COLLECTED,
 *     $99 cada uno, en 2 lineas separadas del mismo PDF.
 *   => $198 cobrados realmente, $99 nunca registrados en Salesforce.
 *
 * Confirmado con el usuario (2026-10-04):
 *   1. El 2do payment SI se vincula al mismo SM_ACH_Order__c (ACH-28189,
 *      a04UU00000HSfG9YAL) -- aunque esa orden es de ajuste puntual
 *      (SM_Payment_Count__c=1, SM_Id_Salesforce_LCS__c anota "AC SPLIT DE
 *      AJUSTE POR ABONO ERRADO 22/23 JUNIO"), ambos $99 vienen del mismo
 *      ciclo/orden -- no se encontro ninguna automatizacion activa que
 *      dependa de ese contador para este contrato (RecordType "Credit
 *      Rectification", NO es Master -- no dispara clonePayments() a
 *      dependientes).
 *   2. SI se hace bypass de triggers (SM_TriggerHandler.avoidAllHandlerExcecution
 *      = true) durante el insert -- es un backfill de un cobro de hace mas de
 *      una semana, no debe disparar efectos pensados para un cobro "nuevo"
 *      en tiempo real (recibo al cliente, recalculo de
 *      SM_Next_Transaction_Date__c de la orden ACH, etc.) -- el insert
 *      siempre cuenta como "changed" para SM_PaymentHandler
 *      (SM_Utils.isChangedField trata oldPayment==null como cambio).
 *
 * SM_Bank_Reference_Number__c: se deja SIN tocar en ambos payments. No hay
 * forma confiable de verificar cual de los 2 trace numbers (que ya estan
 * ambos acumulados en PY-01907641 por el backfill de 3 meses, 2026-10-03)
 * corresponde a cual de los 2 ciclos de cobro -- forzar un split 1 trace por
 * payment seria adivinar. Se prefiere dejar la evidencia intacta (ambos
 * trace numbers en el payment original, que es donde el backfill realmente
 * los encontro) antes que fabricar una atribucion que no se puede probar.
 *
 * Deja nota en SM_Id_Salesforce_LCS__c de AMBOS payments (campo "ANOTACIONES")
 * explicando la correccion, en el mismo espiritu que la regla de marcado de
 * CLAUDE.md seccion 1 (aunque esta no es una automatizacion recurrente, sino
 * una correccion manual puntual) -- para que quede trazable por que este
 * contrato de pronto tiene 2 Fee payments en vez de 1.
 *
 * MODO DE USO:
 *   - Corre primero con DRY_RUN = true -> solo preview, NO escribe nada.
 *   - Si todo esta correcto, cambia DRY_RUN a false y corre de nuevo.
 */

// ============ CONFIGURACION ============
Boolean DRY_RUN = false; // <-- cambiar a false para ejecutar el insert/update real
Id ORIGINAL_PAYMENT_ID = 'a24UU000005T5eAYAS'; // PY-01907641
// ========================================

System.debug(' -> ======================================================');
System.debug(' -> MODO: ' + (DRY_RUN ? 'DRY RUN (solo preview, sin cambios)' : 'EJECUCION REAL (se va a insertar/actualizar)'));
System.debug(' -> ======================================================');

SM_Payment__c original = [
    SELECT Id, Name, SM_Contract__c, SM_ACH_Order__c, RecordTypeId, Payment_Status__c,
           SM_Check_Collection_Status__c, SM_Check_Collection__c, SM_Check_Collection_Return_Reason__c,
           SM_Amount__c, SM_Net_Amount__c, SM_Fee_value__c, SM_Type__c, SM_Original_Type__c,
           SM_Payment_Method__c, SM_Person_Account_Name__c, SM_ACH_Account_Type_Code__c,
           SM_ACH_Account_Number__c, SM_ACH_Account_Routing_Number__c, SM_Routing_Number_Check_Digit__c,
           SM_Individual_Id_Number__c, SM_Recurring__c, SM_Return_code__c, Invoice__c,
           Collection_Result__c, Company_Name__c, SM_Concepto_Pago_Cash__c, Installment_number__c,
           SM_P_IVU_Municipal_Amount__c, SM_P_IVU_State_Amount__c, SM_IVU_Municipal_Amount_Value__c,
           SM_IVU_State_Amount_Value__c, SM_Id_Salesforce_LCS__c
    FROM SM_Payment__c
    WHERE Id = :ORIGINAL_PAYMENT_ID
];

System.debug(' -> Payment original: ' + original.Name + ' | Contrato: ' + original.SM_Contract__c + ' | ACH Order: ' + original.SM_ACH_Order__c);

SM_Payment__c dup = new SM_Payment__c(
    SM_Contract__c               = original.SM_Contract__c,
    SM_ACH_Order__c              = original.SM_ACH_Order__c,
    RecordTypeId                 = original.RecordTypeId,
    Payment_Status__c            = 'ACCEPTED',
    SM_Check_Collection_Status__c = 'COLLECTED',
    SM_Check_Collection__c       = true,
    SM_Check_Collection_Return_Reason__c = 'NSF',
    SM_Check_Collection_Date__c  = Date.valueOf('2026-09-24'),
    SM_Amount__c                 = 99,
    SM_Fee_value__c              = 99,
    SM_Type__c                   = original.SM_Type__c,
    SM_Original_Type__c          = original.SM_Original_Type__c,
    SM_Payment_Method__c         = original.SM_Payment_Method__c,
    SM_ACH_Account_Number__c     = original.SM_ACH_Account_Number__c,
    SM_ACH_Account_Routing_Number__c = original.SM_ACH_Account_Routing_Number__c,
    SM_Routing_Number_Check_Digit__c = original.SM_Routing_Number_Check_Digit__c,
    SM_Recurring__c              = original.SM_Recurring__c,
    SM_Return_code__c            = original.SM_Return_code__c,
    SM_Date_ACH_Transmitted__c   = DateTime.newInstanceGMT(2026, 9, 23, 16, 0, 0),
    SM_Payment_Date__c           = Date.valueOf('2026-09-23'),
    SM_Transmission_Date_ACH_File__c = Date.valueOf('2026-09-23'),
    Invoice__c                   = original.Invoice__c,
    SM_Concepto_Pago_Cash__c     = original.SM_Concepto_Pago_Cash__c,
    Installment_number__c        = original.Installment_number__c,
    SM_P_IVU_Municipal_Amount__c = original.SM_P_IVU_Municipal_Amount__c,
    SM_P_IVU_State_Amount__c     = original.SM_P_IVU_State_Amount__c
);

String dupNote = 'MANUAL: Backfill cobro ACH duplicado real (checks 00003399177/00003462154, ambos COLLECTED 1-oct) -- ver ' + original.Name + ' - ' + Date.today().format();
dup.SM_Id_Salesforce_LCS__c = dupNote;

System.debug(' -> ======================================================');
System.debug(' -> PREVIEW nuevo payment a crear:');
System.debug(' ->   Contrato: ' + dup.SM_Contract__c + ' | ACH Order: ' + dup.SM_ACH_Order__c);
System.debug(' ->   Monto: $' + dup.SM_Amount__c + ' | Status: ' + dup.Payment_Status__c + '/' + dup.SM_Check_Collection_Status__c);
System.debug(' ->   Fecha transmision: ' + dup.SM_Transmission_Date_ACH_File__c + ' | Fecha Check Collection: ' + dup.SM_Check_Collection_Date__c);
System.debug(' ->   ANOTACIONES: ' + dup.SM_Id_Salesforce_LCS__c);
System.debug(' -> ======================================================');

String originalNote = 'MANUAL: Se creo payment duplicado para reflejar 2do cobro real (checks 00003399177/00003462154, ambos COLLECTED 1-oct) - ' + Date.today().format();
String originalNoteCombined = String.isBlank(original.SM_Id_Salesforce_LCS__c) ? originalNote : originalNote + ' // ' + original.SM_Id_Salesforce_LCS__c;
if (originalNoteCombined.length() > 255) {
    originalNoteCombined = originalNoteCombined.substring(0, 255);
}
System.debug(' -> PREVIEW nota a agregar en ' + original.Name + '.SM_Id_Salesforce_LCS__c: ' + originalNoteCombined);
System.debug(' -> ======================================================');

if (!DRY_RUN) {
    Boolean prevBypass = SM_TriggerHandler.avoidAllHandlerExcecution;
    SM_TriggerHandler.avoidAllHandlerExcecution = true;
    try {
        insert dup;
        System.debug(' -> Payment creado: ' + dup.Id);

        SM_Payment__c newPaymentQueried = [SELECT Name FROM SM_Payment__c WHERE Id = :dup.Id];
        System.debug(' -> Nombre asignado: ' + newPaymentQueried.Name);

        original.SM_Id_Salesforce_LCS__c = originalNoteCombined;
        update original;
        System.debug(' -> Nota agregada en ' + original.Name);

        System.debug(' -> ======================================================');
        System.debug(' -> COMPLETADO -> nuevo payment: ' + newPaymentQueried.Name + ' (Id ' + dup.Id + ')');
        System.debug(' -> ======================================================');
    } finally {
        SM_TriggerHandler.avoidAllHandlerExcecution = prevBypass;
    }
} else {
    System.debug(' -> DRY RUN activo: no se creo ni actualizo nada. Cambia DRY_RUN a false para aplicar.');
}
