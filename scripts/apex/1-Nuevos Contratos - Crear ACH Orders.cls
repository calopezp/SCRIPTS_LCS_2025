// ┌───────────────────────────────────────────────────────────────┐
// │ Backfill masivo: Crear ACH Orders (AC / Subscription)          │
// │ Julio 2026 :: Carlos Alberto Lopez Prada                       │
// └───────────────────────────────────────────────────────────────┘

// ---------------- CONFIG ----------------
Boolean modoDryRun = false;   // true = simula, false = ejecuta
// ----------------------------------------

// 1️⃣ Query única — contratos ACH sin ACH Order
List<Contract> contratos = [
    SELECT Id, ContractNumber, SM_Payment_methods__c, Status,
           CB_Subscription__c, Is_Test_Contract__c, Is_VIP_Contract__c,
           SM_Email_to_send_contract__c, SM_Payment_Method__c,
           SM_Payment_Method__r.RecordType.Name,
           SM_AC_start_date__c, SM_Net_AC__c,
           SM_Start_date__c, SM_Net_Monthly_offer__c,
           SM_Requires_AC_Payment__c, Contract_Type__c, SM_Billing_status__c,
           RecordType.Name
    FROM Contract
    WHERE SM_Payment_methods__c = 'ACH'
      AND Status IN ('Payment Process', 'Activated')
      AND Is_Test_Contract__c = FALSE
      AND Is_VIP_Contract__c = FALSE
      AND CB_Subscription__c = null
      AND Contract_Type__c <> 'Dependent'
      AND SM_Billing_status__c <> 'PAYMENT COMPLETED'
      AND RecordType.Name IN ('Credit Rectification')
      AND Id NOT IN (
            SELECT SM_Contract__c
            FROM SM_ACH_Order__c
            WHERE SM_Contract__c != null
      )
];

System.debug('\u2192 Contratos detectados SIN ACH Order: ' + contratos.size());
if (contratos.isEmpty()) {
    System.debug('\u2192 ❌ No hay contratos pendientes');
    return;
}

// Listas bulkificadas
List<SM_ACH_Order__c> nuevosOrders = new List<SM_ACH_Order__c>();
List<Contract> contratosACorregir = new List<Contract>();

// 2️⃣ Procesamiento
for (Contract c : contratos) {

    System.debug('↳ Procesando contrato: ' + c.ContractNumber);

    // Validación: Payment Method debe existir
    if (c.SM_Payment_Method__c == null) {
        System.debug('   ❌ Sin Payment Method — omitido');
        continue;
    }

    // Validación: relación Payment Method y su RecordType
    if (c.SM_Payment_Method__r == null || c.SM_Payment_Method__r.RecordType == null) {
        System.debug('   ❌ Payment Method sin RecordType — omitido');
        continue;
    }

    String metodoPM = c.SM_Payment_Method__r.RecordType.Name;

    // Corrección del picklist si está inconsistente
    if (c.SM_Payment_methods__c != metodoPM) {
        System.debug('   ⚠ Inconsistencia detectada \u2192 se corrige a "' + metodoPM + '"');

        contratosACorregir.add(new Contract(
            Id = c.Id,
            SM_Payment_methods__c = metodoPM
        ));

        c.SM_Payment_methods__c = metodoPM; // usar valor corregido en este run
    }

    // Si tras corrección NO es ACH \u2192 omitir
    if (c.SM_Payment_methods__c != 'ACH') {
        System.debug('   ⚠ Contrato NO es ACH — omitido');
        continue;
    }

    // Excluir Chargebee
    if (String.isNotBlank(c.CB_Subscription__c)) {
        System.debug('   ⚠ Contrato Chargebee — omitido');
        continue;
    }

    // ============================================================
    // Crear ACH Order AC o Subscription
    // ============================================================

    if (c.SM_Requires_AC_Payment__c == true) {

        // Validaciones AC
        if (c.SM_Net_AC__c == null) {
            System.debug('   ❌ SM_Net_AC__c vacío — omitido');
            continue;
        }
        if (c.SM_AC_start_date__c == null) {
            System.debug('   ❌ SM_AC_start_date__c vacío — omitido');
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

        System.debug('   ↳ ☑ ACH Order AC preparado');
        continue;
    }

    // Subscription
    if (c.SM_Net_Monthly_offer__c == null) {
        System.debug('   ❌ SM_Net_Monthly_offer__c vacío — omitido');
        continue;
    }
    if (c.SM_Start_date__c == null) {
        System.debug('   ❌ SM_Start_date__c vacío — omitido');
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

    System.debug('   ↳ ☑ ACH Order Subscription preparado');
}

// Resumen
System.debug('========================================');
System.debug('\u2192 Total ACH Orders a crear: ' + nuevosOrders.size());
System.debug('\u2192 Total Contratos a corregir: ' + contratosACorregir.size());
System.debug('========================================');

// 3️⃣ DML (solo si no es dry run)
if (!modoDryRun) {

    // Correcciones de contratos
    if (!contratosACorregir.isEmpty()) {
        Database.SaveResult[] rc = Database.update(contratosACorregir, false);
        Integer ok = 0;
        for (Integer i = 0; i < rc.size(); i++) {
            if (rc[i].isSuccess()) ok++;
            else System.debug('   ❌ Error corrigiendo ' + contratosACorregir[i].Id + ': ' +
                              rc[i].getErrors()[0].getMessage());
        }
        System.debug('\u2192☑ Contratos corregidos: ' + ok + '/' + contratosACorregir.size());
    }

    // Creación de ACH Orders
    if (!nuevosOrders.isEmpty()) {
        Database.SaveResult[] ro = Database.insert(nuevosOrders, false);
        Integer ok = 0;
        for (Integer i = 0; i < ro.size(); i++) {
            if (ro[i].isSuccess()) ok++;
            else System.debug('   ❌ Error creando ACH Order para ' + nuevosOrders[i].SM_Contract__c + ': ' +
                              ro[i].getErrors()[0].getMessage());
        }
        System.debug('\u2192 ☑ ACH Orders creados: ' + ok + '/' + nuevosOrders.size());
    }

} else {
    System.debug('\u2192 MODO DRY RUN: no se insertó/actualizó nada.');
}
