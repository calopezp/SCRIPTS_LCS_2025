// ┌───────────────────────────────────────────────────────────────┐
// │ Backfill masivo: Crear ACH Orders (AC / Subscription)          │
// │ Julio 2026 :: Carlos Alberto Lopez Prada                       │
// └───────────────────────────────────────────────────────────────┘

// ---------------- CONFIG ----------------
Boolean modoDryRun = true;   // true = simula, false = ejecuta
// ----------------------------------------

// 1️⃣ Query única — contratos ACH candidatos
// (la exclusión de ACH Orders ya existentes se resuelve por tipo más abajo,
//  para permitir que un AC con SM_AC_collected__c = true habilite la Subscription)
List<Contract> contratos = [
/* query AC    SELECT Id, ContractNumber, SM_Payment_methods__c, Status,
                    CB_Subscription__c, Is_Test_Contract__c, Is_VIP_Contract__c,
                    SM_Email_to_send_contract__c, SM_Payment_Method__c,
                    SM_Payment_Method__r.RecordType.Name,
                    SM_AC_start_date__c, SM_Net_AC__c, SM_AC_collected__c,
                    SM_Start_date__c, SM_Net_Monthly_offer__c,
                    SM_Requires_AC_Payment__c, Contract_Type__c, SM_Billing_status__c,
                    RecordType.Name, SM_Customer_Cancellation__c
                FROM Contract
                WHERE
                    Status IN ('Payment Process','Activated') AND SM_Payment_methods__c IN ('ACH') and CreatedDate =THIS_QUARTER 

                    AND Is_Test_Contract__c = FALSE AND Is_VIP_Contract__c = FALSE AND SM_Customer_Cancellation__c = FALSE AND SM_Full_Payment__c = FALSE
                    AND Contract_Type__c NOT IN ('Dependent') AND SM_Billing_status__c NOT IN ('PAYMENT COMPLETED')

                    //AND SM_AC_collected__c = TRUE
                    AND Id NOT IN (SELECT SM_Contract__c FROM SM_ACH_ORDER__c 
                                WHERE SM_Payment_Type__c IN ('SUBSCRIPTION' , 'AC', 'Fee'))
*/

SELECT Id, ContractNumber, SM_Payment_methods__c, Status, CB_Subscription__c, Is_Test_Contract__c, Is_VIP_Contract__c,
       SM_Email_to_send_contract__c, SM_Payment_Method__c, SM_Payment_Method__r.RecordType.Name, SM_AC_start_date__c,
       SM_Net_AC__c, SM_AC_collected__c, SM_Start_date__c, SM_Net_Monthly_offer__c, SM_Requires_AC_Payment__c,
       Contract_Type__c, SM_Billing_status__c, RecordType.Name, SM_Customer_Cancellation__c
FROM Contract
WHERE Status IN ('Payment Process','Activated')
AND SM_Payment_methods__c = 'ACH'
AND CreatedDate = THIS_QUARTER
AND Is_Test_Contract__c = FALSE AND Is_VIP_Contract__c = FALSE AND SM_Customer_Cancellation__c = FALSE
AND SM_Full_Payment__c = FALSE AND Contract_Type__c != 'Dependent' AND SM_Billing_status__c != 'PAYMENT COMPLETED'
AND Id NOT IN (
    SELECT SM_Contract__c
    FROM SM_ACH_ORDER__c
    WHERE SM_Contract__c != NULL
)
 ];

System.debug('\u2192 Contratos detectados: ' + contratos.size());
if (contratos.isEmpty()) {
    System.debug('\u2192 ❌ No hay contratos pendientes');
    return;
}

// 1.5️⃣ ACH Orders existentes por contrato (para saber qué tipos ya se crearon)
Map<Id, List<SM_ACH_Order__c>> ordersPorContrato = new Map<Id, List<SM_ACH_Order__c>>();
for (SM_ACH_Order__c o : [
        SELECT Id, SM_Contract__c, SM_Payment_Type__c
        FROM SM_ACH_Order__c
        WHERE SM_Contract__c IN :contratos
]) {
    if (!ordersPorContrato.containsKey(o.SM_Contract__c)) {
        ordersPorContrato.put(o.SM_Contract__c, new List<SM_ACH_Order__c>());
    }
    ordersPorContrato.get(o.SM_Contract__c).add(o);
}

// Listas bulkificadas
List<SM_ACH_Order__c> nuevosOrders = new List<SM_ACH_Order__c>();
List<Contract> contratosACorregir = new List<Contract>();

// 2️⃣ Procesamiento
for (Contract c : contratos) {

    System.debug('\u2192 ↳ Procesando contrato: ' + c.ContractNumber);

    // Validación: Payment Method debe existir
    if (c.SM_Payment_Method__c == null) {
        System.debug('\u2192    ❌ Sin Payment Method — omitido');
        continue;
    }

    // Validación: relación Payment Method y su RecordType
    if (c.SM_Payment_Method__r == null || c.SM_Payment_Method__r.RecordType == null) {
        System.debug('\u2192    ❌ Payment Method sin RecordType — omitido');
        continue;
    }

    String metodoPM = c.SM_Payment_Method__r.RecordType.Name;

    // Corrección del picklist si está inconsistente
    if (c.SM_Payment_methods__c != metodoPM) {
        System.debug('\u2192    ⚠ Inconsistencia detectada \u2192 se corrige a "' + metodoPM + '"');

        contratosACorregir.add(new Contract(
            Id = c.Id,
            SM_Payment_methods__c = metodoPM
        ));

        c.SM_Payment_methods__c = metodoPM; // usar valor corregido en este run
    }

    // Si tras corrección NO es ACH \u2192 omitir
    if (c.SM_Payment_methods__c != 'ACH') {
        System.debug('\u2192    ⚠ Contrato NO es ACH — omitido');
        continue;
    }

    // Excluir Chargebee
    if (String.isNotBlank(c.CB_Subscription__c)) {
        System.debug('\u2192    ⚠ Contrato Chargebee — omitido');
        continue;
    }

    // ============================================================
    // Crear ACH Order AC o Subscription
    // ============================================================

    List<SM_ACH_Order__c> ordersExistentes = ordersPorContrato.get(c.Id);
    Boolean tieneACOrder = false;
    Boolean tieneSubscriptionOrder = false;

    if (ordersExistentes != null) {
        for (SM_ACH_Order__c o : ordersExistentes) {
            if (o.SM_Payment_Type__c == 'AC') {
                tieneACOrder = true;
            }
            if (o.SM_Payment_Type__c == 'Subscription') {
                tieneSubscriptionOrder = true;
            }
        }
    }

    if (c.SM_Requires_AC_Payment__c == true) {

        if (!tieneACOrder) {

            // Validaciones AC
            if (c.SM_Net_AC__c == null) {
                System.debug('\u2192    ❌ SM_Net_AC__c vacío — omitido');
                continue;
            }
            if (c.SM_AC_start_date__c == null) {
                System.debug('\u2192    ❌ SM_AC_start_date__c vacío — omitido');
                continue;
            }

            nuevosOrders.add(new SM_ACH_Order__c(
                SM_Contract__c              = c.Id,
                SM_Payment_Type__c          = 'AC',
                SM_Payment_Frequency__c     = 'Once',
                SM_Payment_Start_Date__c    = c.SM_AC_start_date__c,
                SM_Payment_End_Date__c      = c.SM_AC_start_date__c,
                SM_Next_Transaction_Date__c = c.SM_AC_start_date__c,
                SM_Payment_Status__c        = 'Pending',
                SM_Payment_Condition__c     = 'Fixed value',
                SM_Billing_Email__c         = c.SM_Email_to_send_contract__c,
                SM_Payment_Count__c         = 1,
                SM_Fee_to_collect__c        = 1,
                SM_Apply_Penalty__c         = false,
                SM_Penalty_Value__c         = 0,
                SM_Payment_Method__c        = c.SM_Payment_Method__c,
                SM_Total__c                 = c.SM_Net_AC__c
            ));

            System.debug('\u2192    ↳ ☑ ACH Order AC preparado');
            continue;
        }

        if (c.SM_AC_collected__c != true) {
            System.debug('\u2192    ⏳ AC existente pero SM_AC_collected__c no es true aún — omitido');
            continue;
        }

        if (tieneSubscriptionOrder) {
            System.debug('\u2192    ⚠ Subscription ya existe — omitido');
            continue;
        }

        // AC ya recaudado (SM_AC_collected__c = true) y sin Subscription aún → cae al bloque de Subscription

    } else {
        if (tieneSubscriptionOrder) {
            System.debug('\u2192    ⚠ Subscription ya existe — omitido');
            continue;
        }
    }

    // Subscription
    if (c.SM_Net_Monthly_offer__c == null) {
        System.debug('\u2192    ❌ SM_Net_Monthly_offer__c vacío — omitido');
        continue;
    }
    if (c.SM_Start_date__c == null) {
        System.debug('\u2192    ❌ SM_Start_date__c vacío — omitido');
        continue;
    }

    nuevosOrders.add(new SM_ACH_Order__c(
        SM_Contract__c              = c.Id,
        SM_Payment_Type__c          = 'Subscription',
        SM_Payment_Frequency__c     = 'Monthly',
        SM_Payment_Start_Date__c    = c.SM_Start_date__c,
        SM_Payment_End_Date__c      = null, // optimizado: suscripción abierta
        SM_Next_Transaction_Date__c = c.SM_Start_date__c,
        SM_Payment_Status__c        = 'Pending',
        SM_Payment_Condition__c     = 'Fixed value',
        SM_Billing_Email__c         = c.SM_Email_to_send_contract__c,
        SM_Payment_Count__c         = 1,
        SM_Fee_to_collect__c        = 1,
        SM_Apply_Penalty__c         = false,
        SM_Penalty_Value__c         = 0,
        SM_Payment_Method__c        = c.SM_Payment_Method__c,
        SM_Total__c                 = c.SM_Net_Monthly_offer__c
    ));
    System.debug('\u2192    ↳ ☑ ACH Order Subscription preparado');
}

// Resumen
System.debug('\u2192 ========================================');
System.debug('\u2192 Total ACH Orders a crear: ' + nuevosOrders.size());
System.debug('\u2192 Total Contratos a corregir: ' + contratosACorregir.size());
System.debug('\u2192 ========================================');

// 3️⃣ DML (solo si no es dry run)
if (!modoDryRun) {

    // Correcciones de contratos
    if (!contratosACorregir.isEmpty()) {
        Database.SaveResult[] rc = Database.update(contratosACorregir, false);
        Integer ok = 0;
        for (Integer i = 0; i < rc.size(); i++) {
            if (rc[i].isSuccess()) ok++;
            else System.debug('\u2192    ❌ Error corrigiendo ' + contratosACorregir[i].Id + ': ' +
                              rc[i].getErrors()[0].getMessage());
        }
        System.debug('\u2192 ☑ Contratos corregidos: ' + ok + '/' + contratosACorregir.size());
    }

    // Creación de ACH Orders
    if (!nuevosOrders.isEmpty()) {
        Database.SaveResult[] ro = Database.insert(nuevosOrders, false);
        Integer ok = 0;
        for (Integer i = 0; i < ro.size(); i++) {
            if (ro[i].isSuccess()) ok++;
            else System.debug('\u2192    ❌ Error creando ACH Order para ' + nuevosOrders[i].SM_Contract__c + ': ' +
                              ro[i].getErrors()[0].getMessage());
        }
        System.debug('\u2192 ☑ ACH Orders creados: ' + ok + '/' + nuevosOrders.size());
    }

} else {
    System.debug('\u2192 MODO DRY RUN: no se insertó/actualizó nada.');
}
