/*
 * -Backfill_Subscription_Prestamos_2026.apex
 * ---------------------------------------------------
 * Crea la SM_ACH_Order__c tipo Subscription de los contratos de prestamo
 * (RecordType 'Desembolso Prestamo') que se activaron sin ninguna orden ACH.
 *
 * Causa (2026-10-07): CONTRACT_Create_ACH_Subscription_Order (v3) exigia
 * SM_AC_collected__c = true, y los prestamos no llevan AC
 * (SM_Requires_AC_Payment__c = false) -> el flow los descartaba en silencio.
 * Corregido en v4 del flow: entra tambien si SM_Requires_AC_Payment__c = false.
 * Este script cubre los 6 que ya estaban activados antes del fix.
 *
 * Inserta la orden con los MISMOS campos que el flow (no lo invoca, para no
 * depender de que la v4 este activa), triggers normales encendidos (igual que
 * cuando la crea el flow). Revalida en vivo cada contrato antes de crear:
 * ACH, Activated, sin Subscription viva, no cancelado, etc.
 * Sin Task en el Contract: el usuario indico no generarlo para este backfill (2026-10-07).
 *
 * MODO DE USO: correr primero con DRY_RUN=true (preview, no escribe nada).
 */

Boolean DRY_RUN = false; // <-- cambiar a false para ejecutar real
String NOTE = 'AUTO: Backfill_Subscription_Prestamos - Subscription Order creada (prestamo sin AC, flow v3 lo excluia) - ' + String.valueOf(Date.today());

Set<String> contractNumbers = new Set<String>{
    '00318601', '00318620', '00318628', '00318654', '00318667', '00318710'
};

List<Contract> contratos = [
    SELECT Id, ContractNumber, Status, RecordType.Name, SM_Payment_methods__c,
           SM_Requires_AC_Payment__c, SM_Requires_RC_Payment__c, Contract_Type__c,
           Is_Test_Contract__c, Is_VIP_Contract__c, SM_Full_Payment__c,
           SM_Customer_Cancellation__c, SM_Billing_status__c, CB_Subscription__c,
           SM_Email_to_send_contract__c, SM_Start_date__c, SM_Net_Monthly_offer__c,
           SM_Payment_Method__c,
           (SELECT Name, SM_Payment_Status__c FROM ACH_Orders__r
            WHERE SM_Payment_Type__c = 'Subscription'
              AND SM_Payment_Status__c NOT IN ('Completed', 'Canceled'))
    FROM Contract
    WHERE ContractNumber IN :contractNumbers
    ORDER BY ContractNumber
];

if (contratos.size() != contractNumbers.size()) {
    System.debug(' -> ***** ALERTA: se esperaban ' + contractNumbers.size() + ' contratos, se encontraron ' + contratos.size());
}

List<SM_ACH_Order__c> ordersToInsert = new List<SM_ACH_Order__c>();
List<Contract> okContracts = new List<Contract>();

for (Contract c : contratos) {
    List<String> motivos = new List<String>();
    if (c.RecordType.Name != 'Desembolso Prestamo') motivos.add('RecordType=' + c.RecordType.Name);
    if (c.SM_Payment_methods__c != 'ACH') motivos.add('Metodo=' + c.SM_Payment_methods__c);
    if (c.Status != 'Activated') motivos.add('Status=' + c.Status);
    if (c.SM_Requires_AC_Payment__c) motivos.add('Requires AC=true');
    if (!c.SM_Requires_RC_Payment__c) motivos.add('Requires RC=false');
    if (c.Contract_Type__c == 'Dependent') motivos.add('Dependent');
    if (c.Is_Test_Contract__c || c.Is_VIP_Contract__c) motivos.add('Test/VIP');
    if (c.SM_Full_Payment__c) motivos.add('Full Payment');
    if (c.SM_Customer_Cancellation__c) motivos.add('Customer Cancellation');
    if (c.SM_Billing_status__c == 'PAYMENT COMPLETED') motivos.add('PAYMENT COMPLETED');
    if (c.CB_Subscription__c != null) motivos.add('Tiene CB_Subscription');
    if (!c.ACH_Orders__r.isEmpty()) motivos.add('Ya tiene Subscription viva ' + c.ACH_Orders__r[0].Name);
    if (c.SM_Start_date__c == null || c.SM_Net_Monthly_offer__c == null || c.SM_Payment_Method__c == null) motivos.add('Falta Start date / Monthly / Payment Method');

    if (!motivos.isEmpty()) {
        System.debug(' -> SALTADO ' + c.ContractNumber + ' | ' + String.join(motivos, ', '));
        continue;
    }

    okContracts.add(c);
    ordersToInsert.add(new SM_ACH_Order__c(
        SM_Contract__c              = c.Id,
        SM_Payment_Type__c          = 'Subscription',
        SM_Payment_Status__c        = 'Pending',
        SM_Payment_Condition__c     = 'Fixed value',
        SM_Payment_Frequency__c     = 'Monthly',
        SM_Payment_Count__c         = 1,
        SM_Fee_to_collect__c        = 1,
        SM_Apply_penalty__c         = false,
        SM_Penalty_value__c         = 0,
        SM_Payment_Method__c        = c.SM_Payment_Method__c,
        SM_Billing_Email__c         = c.SM_Email_to_send_contract__c,
        SM_Payment_Start_Date__c    = c.SM_Start_date__c,
        SM_Next_Transaction_Date__c = c.SM_Start_date__c,
        SM_Total__c                 = c.SM_Net_Monthly_offer__c,
        SM_Id_Salesforce_LCS__c     = NOTE.left(200)
    ));
    System.debug(' -> CREAR ' + c.ContractNumber + ' | Start=' + c.SM_Start_date__c
        + ' | Monto=' + c.SM_Net_Monthly_offer__c + ' | PM=' + c.SM_Payment_Method__c);
}

System.debug(' -> ======================================================');
System.debug(' -> RESUMEN: ' + ordersToInsert.size() + ' Subscription(s) a crear de ' + contratos.size());
System.debug(' -> ======================================================');

if (!DRY_RUN && !ordersToInsert.isEmpty()) {
    insert ordersToInsert;

    Map<Id, SM_ACH_Order__c> created = new Map<Id, SM_ACH_Order__c>([
        SELECT Id, Name, SM_Contract__c, SM_Payment_Status__c, SM_Next_Transaction_Date__c
        FROM SM_ACH_Order__c WHERE Id IN :ordersToInsert
    ]);
    Map<Id, SM_ACH_Order__c> byContract = new Map<Id, SM_ACH_Order__c>();
    for (SM_ACH_Order__c o : created.values()) byContract.put(o.SM_Contract__c, o);

    for (Contract c : okContracts) {
        SM_ACH_Order__c o = byContract.get(c.Id);
        System.debug(' -> CREADA ' + c.ContractNumber + ' | ' + o.Name + ' | Status=' + o.SM_Payment_Status__c
            + ' | Next=' + o.SM_Next_Transaction_Date__c);
    }
} else {
    System.debug(' -> DRY RUN: no se escribio nada.');
}
