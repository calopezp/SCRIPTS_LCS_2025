/**
 * Cancela contratos en lote (ACH y Chargebee) como parte del flujo recurrente
 * "Contratos para Cancelar" — ver .claude/skills/cancelar-contratos/SKILL.md
 * para el flujo completo (cómo agregar contratos nuevos, cómo validar estado,
 * cómo correr en real).
 *
 * Rama ACH: cancela el Contract + sus SM_ACH_Order__c, salvo que algún
 * SM_Payment__c bloqueante (Payment_Status__c REJECTED/ACH TRANSMITTED) no
 * tenga un SM_Check_Collection_Status__c resuelto (regla explícita del
 * usuario: nunca cancelar con un pago bancario sin resolver).
 *
 * Rama Chargebee: anula cada chargebeeapps__CB_Invoice__c pendiente y, si
 * todos quedan resueltos, cancela la CB_Subscription__c — ambos vía la API
 * REST de Chargebee (Named Credential "Chargebee_API"), no hay endpoint de
 * bulk void/cancel, se itera uno por uno. Solo si ambos pasos salen bien el
 * Contract pasa a Cancelled.
 *
 * Dos gotchas reales encontrados armando esto (2026-09), documentados acá
 * porque no son obvios releyendo el código:
 *
 * 1. Orden callout/DML: un callout HTTP después de cualquier DML pendiente
 *    en la misma transacción tira "System.CalloutException: You have
 *    uncommitted work pending". Por eso corre en 2 fases estrictas:
 *    runChargebeeCallouts() (fase 1, cero DML) y todo lo demás (fase 2,
 *    ya sin callouts pendientes).
 *
 * 2. SM_Reason_for_cancellation__c es un picklist dependiente de Status.
 *    Cambiar Status y este campo en la MISMA DML puede rechazarse con
 *    "bad value for restricted picklist field" incluso cuando el valor es
 *    válido para el nuevo Status (confirmado con Salesforce: pasó en un
 *    contrato real dentro de esta misma transacción, y NO se pudo
 *    reproducir aislado — probablemente por automatización disparada por
 *    una DML anterior sobre el mismo registro). Fix: Status se guarda en su
 *    propia DML (fase A) y el Reason en una segunda DML separada (fase B),
 *    ya con el Status comprometido en la base.
 *
 * El ID real de Chargebee usado en la API (invoice y subscription) es el
 * campo Name del registro — NO chargebeeapps__CB_Id__c, que parece el
 * candidato obvio pero es un Id interno distinto del conector.
 *
 * @author Carlos Alberto Lopez Prada
 */
public without sharing class CancelarContratosRunner {

    private static final String NAMED_CRED   = 'Chargebee_API';
    private static final String VOID_COMMENT = 'CONTRACT CANCELLED';
    private static final Set<String> ESTADOS_A_OMITIR_INVOICE = new Set<String>{ 'VOIDED', 'PAID' };

    private static final String ACH_RT_ID     = '0121U000000KZPsQAO';
    private static final String TASK_OWNER_ID = '0051U000001MRFeQAO';  // Legal Credit Solutions
    private static final String TASK_RT_ID    = '0121U00000085XiQAI';
    private static final String TASK_SUBJECT  = 'Customer Service-Effective Cancellation';

    private static final Set<String> ALLOWED_ACH_STATUSES = new Set<String>{
        'NOT_COLLECTED','Not_Collected','Not_collected',
        'NOT COLLECTED','Not Collected','Not collected',
        'ACCEPTED','Accepted',
        'COLLECTED','COLECTED','Collected',
        'REJECTED'
    };
    private static final Set<String> BLOCKING_PAYMENT_STATUSES = new Set<String>{
        'REJECTED', 'ACH TRANSMITTED'
    };
    private static final Set<String> ORDER_STATES_TO_CANCEL = new Set<String>{
        'Pending','Iniciated','Stopped','Recurring','X CANCELED'
    };

    // Texto de Task histórico por motivo (mismos 2 que ya se usaban antes de
    // que el motivo viniera del CSV). Si aparece un motivo nuevo que no
    // matchea ninguno de estos, se cae al fallback genérico en
    // taskDescriptionFor() — no falla, pero conviene revisar si vale la
    // pena agregarlo acá.
    private static final Map<String, String> TASK_DESC_BY_REASON = new Map<String, String>{
        'does not comply with payments' => 'Cliente no cumple con los pagos, Solicitado y Autorizado por ELba Mantilla',
        'does not comply with the obligations of the contract' => 'Cliente no ha entregado evidencias/documentación para poderle trabajar, Solicitado Rosaura'
    };

    // ============================================================
    //  DTOs
    // ============================================================
    // Una fila por contrato -- Motivo y Fecha de solicitud (-> Contract.
    // SM_Cancellation_Date__c) vienen del CSV, ya NO se asume Date.today()
    // ni un motivo único para todo un lote (ver
    // COLLECTIONS/CANCELACIONES/Contratos_para_Cancelar_LOG.csv, 3
    // columnas: ContractNumber, Fecha, Motivo).
    public class CancelRequest {
        public String contractNumber;
        public String reason;
        public Date   requestDate;
        public CancelRequest(String num, String r, Date d) {
            contractNumber = num; reason = r; requestDate = d;
        }
    }

    public class ResultRow {
        public Id      contractId;
        public String  contractNumber;
        public String  action;
        public String  detail;
        public Boolean success;
        public String  groupName;
    }

    private class CalloutResult {
        public Boolean success;
        public String  detail;
    }

    private class ChargebeeOutcome {
        public Id      contractId;
        public String  contractNumber;
        public Boolean fullCancel;
        public List<String> stepDetails;
        public List<chargebeeapps__CB_Invoice__c> invoicesToUpdate;
    }

    // ============================================================
    //  API pública
    // ============================================================
    public static List<ResultRow> run(List<CancelRequest> requests, Boolean modoDryRun) {
        return new CancelarContratosRunner(modoDryRun).runAll(requests);
    }

    private static String taskDescriptionFor(String reason) {
        String key = reason == null ? '' : reason.trim().toLowerCase();
        if (TASK_DESC_BY_REASON.containsKey(key)) return TASK_DESC_BY_REASON.get(key);
        return 'Cancelación solicitada — ' + reason;
    }

    // ============================================================
    //  Implementación
    // ============================================================
    private final Boolean modoDryRun;

    private CancelarContratosRunner(Boolean dryRun) {
        modoDryRun = dryRun;
    }

    private List<ResultRow> runAll(List<CancelRequest> requests) {
        List<ResultRow> allResults = new List<ResultRow>();

        Map<String, String> numberToReason      = new Map<String, String>();
        Map<String, String> numberToTaskDesc    = new Map<String, String>();
        Map<String, Date>   numberToRequestDate = new Map<String, Date>();
        for (CancelRequest req : requests) {
            numberToReason.put(req.contractNumber, req.reason);
            numberToTaskDesc.put(req.contractNumber, taskDescriptionFor(req.reason));
            numberToRequestDate.put(req.contractNumber, req.requestDate);
        }
        Set<String> allNumbers = numberToReason.keySet();

        // ── 1. Cargar contratos (sin DML todavía) ─────────────
        Map<Id, Contract> contractsById = new Map<Id, Contract>([
            SELECT Id, ContractNumber, Status, CB_Subscription__c,
                   CB_Subscription__r.Name,
                   CB_Subscription__r.chargebeeapps__Subscription_status__c
            FROM   Contract
            WHERE  ContractNumber IN :allNumbers
        ]);

        Set<String> foundNumbers = new Set<String>();
        for (Contract c : contractsById.values()) foundNumbers.add(c.ContractNumber);
        for (String num : allNumbers) {
            if (!foundNumbers.contains(num)) {
                allResults.add(makeRow(null, num, 'NOT_FOUND',
                    'No se encontró Contract con ese ContractNumber',
                    false, numberToReason.get(num)));
            }
        }
        if (contractsById.isEmpty()) return allResults;

        // ── 2. Separar ChargeBee vs ACH (todavía sin DML) ────
        Map<Id, Contract> chargebeeContracts = new Map<Id, Contract>();
        Map<Id, Contract> achContracts       = new Map<Id, Contract>();
        for (Contract c : contractsById.values()) {
            if (String.isNotBlank(c.CB_Subscription__c)) {
                chargebeeContracts.put(c.Id, c);
            } else {
                achContracts.put(c.Id, c);
            }
        }

        // FASE 1 — SOLO callouts a Chargebee. CERO DML en esta fase.
        List<ChargebeeOutcome> cbOutcomes = chargebeeContracts.isEmpty()
            ? new List<ChargebeeOutcome>()
            : runChargebeeCallouts(chargebeeContracts);

        // FASE 2 — ya no quedan callouts pendientes: toda la DML puede correr.

        List<Contract> allToMarkCancellation = new List<Contract>();
        for (Contract c : contractsById.values()) {
            allToMarkCancellation.add(new Contract(
                Id                          = c.Id,
                SM_Customer_Cancellation__c = true
            ));
        }
        if (!allToMarkCancellation.isEmpty() && !modoDryRun) {
            Database.SaveResult[] markSaves = Database.update(allToMarkCancellation, false);
            for (Integer i = 0; i < allToMarkCancellation.size(); i++) {
                if (!markSaves[i].isSuccess()) {
                    System.debug('Error marcando SM_Customer_Cancellation__c en Id: '
                        + allToMarkCancellation[i].Id + ' -> ' + collectSaveErrors(markSaves[i]));
                }
            }
        }

        Map<Id, Set<String>> existingTaskDescByContract =
            loadExistingTaskDescriptions(contractsById.keySet());

        if (!cbOutcomes.isEmpty()) {
            allResults.addAll(finalizeChargebee(
                cbOutcomes, numberToReason, numberToTaskDesc, numberToRequestDate, existingTaskDescByContract));
        }

        // RAMA ACH
        if (achContracts.isEmpty()) return allResults;

        Map<Id, Contract> activeAchContracts = new Map<Id, Contract>();
        for (Contract c : achContracts.values()) {
            if (c.Status != 'Cancelled') activeAchContracts.put(c.Id, c);
        }
        if (activeAchContracts.isEmpty()) return allResults;

        Map<Id, List<SM_Payment__c>> paymentsByContract = new Map<Id, List<SM_Payment__c>>();
        for (SM_Payment__c p : [
            SELECT Id, Name, SM_Contract__c, SM_Check_Collection_Status__c,
                   RecordTypeId, SM_Date_ACH_Transmitted__c, SM_Check_Collection_Date__c, Payment_Status__c
            FROM   SM_Payment__c
            WHERE  Payment_Status__c IN :BLOCKING_PAYMENT_STATUSES
              AND  SM_Contract__c IN :activeAchContracts.keySet()
        ]) {
            if (!paymentsByContract.containsKey(p.SM_Contract__c))
                paymentsByContract.put(p.SM_Contract__c, new List<SM_Payment__c>());
            paymentsByContract.get(p.SM_Contract__c).add(p);
        }

        Set<Id> cancelableIds = new Set<Id>();
        Map<Id, Integer> resultRowIndexByContract = new Map<Id, Integer>();

        for (Contract c : activeAchContracts.values()) {
            List<SM_Payment__c> related = paymentsByContract.get(c.Id);
            Boolean canCancel = true;

            if (related != null && !related.isEmpty()) {
                Boolean hasAch = false;
                for (SM_Payment__c p : related) {
                    if (p.RecordTypeId == ACH_RT_ID) { hasAch = true; break; }
                }
                if (hasAch) {
                    for (SM_Payment__c p : related) {
                        if (p.RecordTypeId == ACH_RT_ID
                            && !ALLOWED_ACH_STATUSES.contains(p.SM_Check_Collection_Status__c)) {
                            canCancel = false; break;
                        }
                    }
                }
            }

            if (canCancel) {
                cancelableIds.add(c.Id);
            } else {
                List<String> blocking = new List<String>();
                for (SM_Payment__c p : related) {
                    if (p.RecordTypeId == ACH_RT_ID
                        && !ALLOWED_ACH_STATUSES.contains(p.SM_Check_Collection_Status__c)) {
                        String statusLabel = String.isNotBlank(p.SM_Check_Collection_Status__c)
                            ? p.SM_Check_Collection_Status__c
                            : p.Payment_Status__c;
                        blocking.add(p.Name + ' en ' + statusLabel);
                    }
                }
                allResults.add(makeRow(c.Id, c.ContractNumber, 'SKIP',
                    String.join(blocking, '; '),
                    false, numberToReason.get(c.ContractNumber)));
                resultRowIndexByContract.put(c.Id, allResults.size() - 1);
            }
        }

        Map<Id, String> achOrderErrors = new Map<Id, String>();
        if (!cancelableIds.isEmpty() && !modoDryRun) {
            List<SM_ACH_Order__c> achOrdersToCancel = [
                SELECT Id, SM_Payment_Status__c, SM_Contract__c
                FROM   SM_ACH_Order__c
                WHERE  SM_Contract__c IN :cancelableIds
                  AND  SM_Payment_Status__c IN :ORDER_STATES_TO_CANCEL
            ];
            for (SM_ACH_Order__c o : achOrdersToCancel) o.SM_Payment_Status__c = 'Canceled';
            achOrderErrors = saveAndCollectErrors(achOrdersToCancel);
        }

        Set<Id> nonCancelableIds = new Set<Id>(activeAchContracts.keySet());
        nonCancelableIds.removeAll(cancelableIds);
        if (!nonCancelableIds.isEmpty() && !modoDryRun) {
            List<SM_ACH_Order__c> achOrdersToStop = [
                SELECT Id, SM_Payment_Status__c
                FROM   SM_ACH_Order__c
                WHERE  SM_Contract__c IN :nonCancelableIds
                  AND  SM_Payment_Status__c != 'Canceled'
            ];
            for (SM_ACH_Order__c o : achOrdersToStop) o.SM_Payment_Status__c = 'CANCELED';
            if (!achOrdersToStop.isEmpty()) Database.update(achOrdersToStop, false);
        }

        // FASE A: Status solo (ver nota de clase sobre el picklist dependiente).
        List<Contract> statusUpdates = new List<Contract>();
        for (Id cid : cancelableIds) {
            if (achOrderErrors.containsKey(cid)) continue;
            statusUpdates.add(new Contract(
                Id     = cid,
                Status = 'Cancelled'
            ));
        }
        Map<Id, String> statusErrors = modoDryRun
            ? new Map<Id, String>()
            : saveAndCollectErrors(statusUpdates);

        // FASE B: Reason, ya con el Status comprometido en la base.
        List<Contract> reasonUpdates = new List<Contract>();
        for (Id cid : cancelableIds) {
            if (achOrderErrors.containsKey(cid) || statusErrors.containsKey(cid)) continue;
            Contract c = activeAchContracts.get(cid);
            reasonUpdates.add(new Contract(
                Id                             = cid,
                SM_Reason_for_cancellation__c  = numberToReason.get(c.ContractNumber),
                CANCELAR_CONTRATO__c           = numberToReason.get(c.ContractNumber),
                SM_Cancellation_Date__c        = numberToRequestDate.get(c.ContractNumber)
            ));
        }
        Map<Id, String> reasonErrors = modoDryRun
            ? new Map<Id, String>()
            : saveAndCollectErrors(reasonUpdates);

        for (Id cid : cancelableIds) {
            Contract c = activeAchContracts.get(cid);
            List<String> errors = new List<String>();

            if (achOrderErrors.containsKey(cid)) errors.add('ACH Orders: ' + achOrderErrors.get(cid));
            if (statusErrors.containsKey(cid))   errors.add('Contract (Status): ' + statusErrors.get(cid));
            if (reasonErrors.containsKey(cid))   errors.add('Contract (Reason): ' + reasonErrors.get(cid));

            ResultRow row = makeRow(cid, c.ContractNumber,
                modoDryRun ? 'DRY_RUN_ACH' : (errors.isEmpty() ? 'CANCELLED' : 'PARTIAL/ERROR'),
                modoDryRun ? 'Se cancelaría (ACH) — Contract + ACH Orders.'
                    : (errors.isEmpty() ? 'Contrato y órdenes actualizados correctamente.' : String.join(errors, ' | ')),
                modoDryRun ? true : errors.isEmpty(), numberToReason.get(c.ContractNumber)
            );
            allResults.add(row);
            resultRowIndexByContract.put(cid, allResults.size() - 1);
        }

        List<Task>    tasksToInsert     = new List<Task>();
        List<Integer> taskResultIndexes = new List<Integer>();

        for (Contract c : activeAchContracts.values()) {
            String taskDesc = numberToTaskDesc.get(c.ContractNumber);
            Boolean taskAlreadyExists =
                existingTaskDescByContract.containsKey(c.Id) &&
                existingTaskDescByContract.get(c.Id).contains(taskDesc);

            if (taskAlreadyExists) {
                Integer idxDup = resultRowIndexByContract.get(c.Id);
                if (idxDup != null) {
                    ResultRow rrDup = allResults[idxDup];
                    rrDup.detail += ' | Task ya existente (no duplicada).';
                    allResults[idxDup] = rrDup;
                }
                continue;
            }

            Task t         = new Task();
            t.Subject      = TASK_SUBJECT;
            t.WhatId       = c.Id;
            t.Description  = taskDesc;
            t.OwnerId      = TASK_OWNER_ID;
            t.RecordTypeId = TASK_RT_ID;
            t.ActivityDate = Date.today();
            tasksToInsert.add(t);
            taskResultIndexes.add(resultRowIndexByContract.get(c.Id));
        }

        if (!tasksToInsert.isEmpty() && !modoDryRun) {
            Database.SaveResult[] taskSave = Database.insert(tasksToInsert, false);
            for (Integer i = 0; i < taskSave.size(); i++) {
                Integer idx  = taskResultIndexes[i];
                ResultRow rr = allResults[idx];
                if (taskSave[i].isSuccess()) {
                    rr.detail += ' | Task creada.';
                } else {
                    rr.success = false;
                    rr.detail += ' | Task error: ' + collectSaveErrors(taskSave[i]);
                }
                allResults[idx] = rr;
            }
        }

        return allResults;
    }

    // ============================================================
    //  Rama Chargebee — FASE 1: solo callouts, cero DML.
    // ============================================================
    private List<ChargebeeOutcome> runChargebeeCallouts(Map<Id, Contract> chargebeeContracts) {
        List<ChargebeeOutcome> outcomes = new List<ChargebeeOutcome>();

        Map<Id, List<chargebeeapps__CB_Invoice__c>> invoicesByContract =
            new Map<Id, List<chargebeeapps__CB_Invoice__c>>();
        for (chargebeeapps__CB_Invoice__c inv : [
            SELECT Id, Name, chargebeeapps__CB_Invoice_Id__c, chargebeeapps__Status__c, Contract__c
            FROM   chargebeeapps__CB_Invoice__c
            WHERE  Contract__c IN :chargebeeContracts.keySet()
        ]) {
            if (!invoicesByContract.containsKey(inv.Contract__c))
                invoicesByContract.put(inv.Contract__c, new List<chargebeeapps__CB_Invoice__c>());
            invoicesByContract.get(inv.Contract__c).add(inv);
        }

        Integer totalCalloutsPlanned = 0;
        for (List<chargebeeapps__CB_Invoice__c> invs : invoicesByContract.values()) {
            for (chargebeeapps__CB_Invoice__c inv : invs) {
                if (!ESTADOS_A_OMITIR_INVOICE.contains(inv.chargebeeapps__Status__c)) totalCalloutsPlanned++;
            }
        }
        totalCalloutsPlanned += chargebeeContracts.size(); // +1 posible cancel_for_items por contrato
        if (totalCalloutsPlanned > 90) {
            System.debug('ALERTA: ~' + totalCalloutsPlanned
                + ' callouts estimados en este run. Límite Salesforce: 100/transacción, 120s totales '
                + '— dividir el lote de contractNumbers si esto se acerca al límite.');
        }

        for (Contract c : chargebeeContracts.values()) {
            if (c.Status == 'Cancelled') continue;

            ChargebeeOutcome outcome = new ChargebeeOutcome();
            outcome.contractId       = c.Id;
            outcome.contractNumber   = c.ContractNumber;
            outcome.stepDetails      = new List<String>();
            outcome.invoicesToUpdate = new List<chargebeeapps__CB_Invoice__c>();

            List<chargebeeapps__CB_Invoice__c> invs = invoicesByContract.get(c.Id);
            Boolean allInvoicesResolved = true;

            if (invs != null) {
                for (chargebeeapps__CB_Invoice__c inv : invs) {
                    if (ESTADOS_A_OMITIR_INVOICE.contains(inv.chargebeeapps__Status__c)) continue; // ya resuelto

                    if (String.isBlank(inv.chargebeeapps__CB_Invoice_Id__c)) {
                        allInvoicesResolved = false;
                        outcome.stepDetails.add('Invoice ' + inv.Name + ': sin chargebeeapps__CB_Invoice_Id__c, no se puede anular.');
                        continue;
                    }

                    if (modoDryRun) {
                        outcome.stepDetails.add('Invoice ' + inv.Name + ': se anularía (status actual ' + inv.chargebeeapps__Status__c + ').');
                        continue; // en dry run no sabemos el resultado real -> no se puede asumir resuelto
                    }

                    CalloutResult voidRes = callChargebee(
                        'invoices/' + EncodingUtil.urlEncode(inv.chargebeeapps__CB_Invoice_Id__c, 'UTF-8') + '/void',
                        'comment=' + EncodingUtil.urlEncode(VOID_COMMENT, 'UTF-8')
                    );
                    if (voidRes.success) {
                        outcome.stepDetails.add('Invoice ' + inv.Name + ': VOIDED.');
                        inv.chargebeeapps__Status__c = 'VOIDED';
                        outcome.invoicesToUpdate.add(inv);
                    } else {
                        allInvoicesResolved = false;
                        outcome.stepDetails.add('Invoice ' + inv.Name + ': ERROR void — ' + voidRes.detail);
                    }
                }
            }

            String subStatus = c.CB_Subscription__r != null
                ? c.CB_Subscription__r.chargebeeapps__Subscription_status__c : null;
            Boolean subscriptionOk = (subStatus == 'CANCELLED' || subStatus == 'cancelled');

            if (modoDryRun) {
                outcome.stepDetails.add(subscriptionOk
                    ? 'Subscription ya CANCELLED.'
                    : 'Se cancelaría la Subscription (' + (c.CB_Subscription__r != null ? c.CB_Subscription__r.Name : null) + ').');
            } else if (allInvoicesResolved && !subscriptionOk) {
                String subId = c.CB_Subscription__r != null ? c.CB_Subscription__r.Name : null;
                if (String.isBlank(subId)) {
                    outcome.stepDetails.add('Subscription: sin Name/Id, no se puede cancelar.');
                } else {
                    CalloutResult cancelRes = callChargebee(
                        'subscriptions/' + EncodingUtil.urlEncode(subId, 'UTF-8') + '/cancel_for_items',
                        'cancel_option=immediately'
                    );
                    if (cancelRes.success) {
                        outcome.stepDetails.add('Subscription ' + subId + ': CANCELLED.');
                        subscriptionOk = true;
                    } else {
                        outcome.stepDetails.add('Subscription ' + subId + ': ERROR cancel — ' + cancelRes.detail);
                    }
                }
            }

            outcome.fullCancel = !modoDryRun && allInvoicesResolved && subscriptionOk;
            outcomes.add(outcome);
        }

        return outcomes;
    }

    // ============================================================
    //  Rama Chargebee — FASE 2: toda la DML, ya sin callouts pendientes.
    // ============================================================
    private List<ResultRow> finalizeChargebee(
        List<ChargebeeOutcome> outcomes,
        Map<String, String> numberToReason,
        Map<String, String> numberToTaskDesc,
        Map<String, Date> numberToRequestDate,
        Map<Id, Set<String>> existingTaskDescByContract
    ) {
        List<ResultRow> results = new List<ResultRow>();
        Map<Id, Integer> resultIndexByContract = new Map<Id, Integer>();

        List<chargebeeapps__CB_Invoice__c> allInvoicesToUpdate = new List<chargebeeapps__CB_Invoice__c>();
        List<Contract>   statusUpdates   = new List<Contract>();
        List<Id>         statusUpdateIds = new List<Id>();
        Map<Id, Boolean> wantsFullCancel = new Map<Id, Boolean>();

        for (ChargebeeOutcome outcome : outcomes) {
            allInvoicesToUpdate.addAll(outcome.invoicesToUpdate);

            ResultRow row      = new ResultRow();
            row.contractId     = outcome.contractId;
            row.contractNumber = outcome.contractNumber;
            row.groupName      = numberToReason.get(outcome.contractNumber);
            row.action         = modoDryRun ? 'DRY_RUN_CB' : (outcome.fullCancel ? 'CHARGEBEE_CANCELLED' : 'PARTIAL/PENDING');
            row.success        = modoDryRun ? true : outcome.fullCancel;
            row.detail         = String.join(outcome.stepDetails, ' | ');
            results.add(row);
            resultIndexByContract.put(outcome.contractId, results.size() - 1);

            if (modoDryRun) continue;

            // FASE A: Status solo (+ campos no dependientes).
            Contract updA = new Contract(
                Id                          = outcome.contractId,
                SM_Customer_Cancellation__c = true,
                CANCELAR_CONTRATO__c        = numberToReason.get(outcome.contractNumber)
            );
            if (outcome.fullCancel) {
                updA.Status = 'Cancelled';
            }
            statusUpdates.add(updA);
            statusUpdateIds.add(outcome.contractId);
            wantsFullCancel.put(outcome.contractId, outcome.fullCancel);
        }

        if (!allInvoicesToUpdate.isEmpty()) {
            Database.update(allInvoicesToUpdate, false);
        }

        Set<Id> statusOkIds = new Set<Id>();
        if (!statusUpdates.isEmpty()) {
            Database.SaveResult[] saves = Database.update(statusUpdates, false);
            for (Integer i = 0; i < saves.size(); i++) {
                Id cid = statusUpdateIds[i];
                Integer idx = resultIndexByContract.get(cid);
                if (saves[i].isSuccess()) {
                    statusOkIds.add(cid);
                } else {
                    ResultRow rr = results[idx];
                    rr.success = false;
                    rr.detail += ' | Contract error (Status): ' + collectSaveErrors(saves[i]);
                    results[idx] = rr;
                }
            }
        }

        // FASE B: Reason + fecha, solo para los que sí van a Cancelled y
        // cuyo Status ya se guardó bien en la Fase A.
        List<Contract> reasonUpdates   = new List<Contract>();
        List<Id>       reasonUpdateIds = new List<Id>();
        for (Id cid : statusOkIds) {
            if (!wantsFullCancel.get(cid)) continue;
            String contractNumber = results[resultIndexByContract.get(cid)].contractNumber;
            reasonUpdates.add(new Contract(
                Id                             = cid,
                SM_Reason_for_cancellation__c  = numberToReason.get(contractNumber),
                SM_Cancellation_Date__c        = numberToRequestDate.get(contractNumber)
            ));
            reasonUpdateIds.add(cid);
        }
        if (!reasonUpdates.isEmpty()) {
            Database.SaveResult[] saves = Database.update(reasonUpdates, false);
            for (Integer i = 0; i < saves.size(); i++) {
                Id cid = reasonUpdateIds[i];
                Integer idx = resultIndexByContract.get(cid);
                ResultRow rr = results[idx];
                if (!saves[i].isSuccess()) {
                    rr.success = false;
                    rr.detail += ' | Contract error (Reason): ' + collectSaveErrors(saves[i]);
                }
                results[idx] = rr;
            }
        }

        // Tasks solo para los contratos que sí quedaron Cancelled de verdad.
        List<Task>    tasksToInsert     = new List<Task>();
        List<Integer> taskResultIndexes = new List<Integer>();
        for (Id cid : statusOkIds) {
            if (!wantsFullCancel.get(cid)) continue;
            Integer idx = resultIndexByContract.get(cid);
            String contractNumber = results[idx].contractNumber;
            String taskDesc = numberToTaskDesc.get(contractNumber);
            Boolean taskAlreadyExists =
                existingTaskDescByContract.containsKey(cid) &&
                existingTaskDescByContract.get(cid).contains(taskDesc);

            if (!taskAlreadyExists) {
                Task t         = new Task();
                t.Subject      = TASK_SUBJECT;
                t.WhatId       = cid;
                t.Description  = taskDesc;
                t.OwnerId      = TASK_OWNER_ID;
                t.RecordTypeId = TASK_RT_ID;
                t.ActivityDate = Date.today();
                tasksToInsert.add(t);
                taskResultIndexes.add(idx);
            } else {
                ResultRow rr = results[idx];
                rr.detail += ' | Task ya existente (no duplicada).';
                results[idx] = rr;
            }
        }
        if (!tasksToInsert.isEmpty()) {
            Database.SaveResult[] taskSave = Database.insert(tasksToInsert, false);
            for (Integer i = 0; i < taskSave.size(); i++) {
                Integer idx  = taskResultIndexes[i];
                ResultRow rr = results[idx];
                if (taskSave[i].isSuccess()) {
                    rr.detail += ' | Task creada.';
                } else {
                    rr.success = false;
                    rr.detail += ' | Task error: ' + collectSaveErrors(taskSave[i]);
                }
                results[idx] = rr;
            }
        }

        return results;
    }

    private CalloutResult callChargebee(String pathAndId, String formBody) {
        CalloutResult r = new CalloutResult();
        try {
            HttpRequest req = new HttpRequest();
            req.setEndpoint('callout:' + NAMED_CRED + '/api/v2/' + pathAndId);
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
            req.setBody(formBody);
            req.setTimeout(60000);

            Http http = new Http();
            HttpResponse res = http.send(req);

            if (res.getStatusCode() == 200) {
                r.success = true;
                r.detail  = 'OK';
            } else {
                r.success = false;
                r.detail  = 'HTTP ' + res.getStatusCode() + ' — ' + res.getBody();
            }
        } catch (Exception e) {
            r.success = false;
            r.detail  = e.getMessage() + ' (línea ' + e.getLineNumber() + ')';
        }
        return r;
    }

    private ResultRow makeRow(Id cid, String num, String action, String detail, Boolean success, String grp) {
        ResultRow r      = new ResultRow();
        r.contractId     = cid;
        r.contractNumber = num;
        r.action         = action;
        r.detail         = detail;
        r.success        = success;
        r.groupName      = grp;
        return r;
    }

    private Map<Id, Set<String>> loadExistingTaskDescriptions(Set<Id> contractIds) {
        Map<Id, Set<String>> result = new Map<Id, Set<String>>();
        if (contractIds == null || contractIds.isEmpty()) return result;
        for (Task t : [
            SELECT WhatId, Description
            FROM   Task
            WHERE  WhatId IN :contractIds
              AND  Subject      = :TASK_SUBJECT
              AND  OwnerId      = :TASK_OWNER_ID
              AND  RecordTypeId = :TASK_RT_ID
        ]) {
            if (!result.containsKey(t.WhatId)) result.put(t.WhatId, new Set<String>());
            result.get(t.WhatId).add(t.Description);
        }
        return result;
    }

    private Map<Id, String> saveAndCollectErrors(List<SObject> records) {
        Map<Id, String> errorMap = new Map<Id, String>();
        if (records == null || records.isEmpty()) return errorMap;
        Database.SaveResult[] saves = Database.update(records, false);
        for (Integer i = 0; i < records.size(); i++) {
            if (!saves[i].isSuccess()) {
                Id ref = getContractRef(records[i]);
                if (ref != null) errorMap.put(ref, collectSaveErrors(saves[i]));
            }
        }
        return errorMap;
    }

    private Id getContractRef(SObject rec) {
        if (rec instanceof SM_ACH_Order__c) return (Id) rec.get('SM_Contract__c');
        if (rec instanceof Contract)        return (Id) rec.get('Id');
        return null;
    }

    private String collectSaveErrors(Database.SaveResult sr) {
        List<String> msgs = new List<String>();
        for (Database.Error e : sr.getErrors()) msgs.add(e.getMessage());
        return String.join(msgs, '; ');
    }
}
