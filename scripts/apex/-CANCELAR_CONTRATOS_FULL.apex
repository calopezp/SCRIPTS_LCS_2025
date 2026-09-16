// ===============
//  CANCELAR_CONTRATOS_FULL
// #region titulo
//  Autor: Carlos Lopez / Claude Code — SEPTIEMBRE 2026
// ===============
// #endregion titulo

// ---------------- CONFIG ----------------
Boolean modoDryRun         = false;    // true = no llama a Chargebee ni actualiza nada, solo reporta qué haría
String  NAMED_CRED         = 'Chargebee_API';
String  VOID_COMMENT       = 'CONTRACT CANCELLED';
Set<String> ESTADOS_A_OMITIR_INVOICE = new Set<String>{ 'VOIDED', 'PAID' }; //, 'NOT_PAID' //  mismo criterio manual de siempre
// -----------------------------------------
//#region CUERPO

//  DTOs ===============
public class CancelGroup {
    public String      reason;
    public String      taskDescription;
    public Set<String> contractNumbers;
    public CancelGroup(String r, String td, Set<String> nums) {
        reason = r; taskDescription = td; contractNumbers = nums;
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

public class CalloutResult {
    public Boolean success;
    public String  detail;
}

public class ChargebeeOutcome {
    public Id      contractId;
    public String  contractNumber;
    public Boolean fullCancel;
    public List<String> stepDetails;
    public List<chargebeeapps__CB_Invoice__c> invoicesToUpdate;
}


//  CLASE PRINCIPAL ===============
public class CancelarContratosFullRunner {

    private final String  ACH_RT_ID     = '0121U000000KZPsQAO';
    private final String  TASK_OWNER_ID = '0051U000001MRFeQAO';  //Legal Credit Solutions
    private final String  TASK_RT_ID    = '0121U00000085XiQAI';
    private final String  TASK_SUBJECT  = 'Customer Service-Effective Cancellation';

    private final Set<String> ALLOWED_ACH_STATUSES = new Set<String>{
        'NOT_COLLECTED','Not_Collected','Not_collected',
        'ACCEPTED','Accepted',
        'COLLECTED','COLECTED','Collected',
        'REJECTED'
    };
    private final Set<String> BLOCKING_PAYMENT_STATUSES = new Set<String>{
        'REJECTED', 'ACH TRANSMITTED'
    };
    private final Set<String> ORDER_STATES_TO_CANCEL = new Set<String>{
        'Pending','Iniciated','Stopped','Recurring','X CANCELED'
    };

    private final Boolean modoDryRun;
    private final String  namedCredential;
    private final String  voidComment;
    private final Set<String> estadosAOmitirInvoice;

    public CancelarContratosFullRunner(Boolean dryRun, String namedCred, String voidCmt, Set<String> estadosOmitir) {
        modoDryRun            = dryRun;
        namedCredential       = namedCred;
        voidComment           = voidCmt;
        estadosAOmitirInvoice = estadosOmitir;
    }

    public List<ResultRow> runAll(List<CancelGroup> grupos) {
        List<ResultRow> allResults = new List<ResultRow>();

        Map<String, String> numberToReason   = new Map<String, String>();
        Map<String, String> numberToTaskDesc = new Map<String, String>();
        for (CancelGroup g : grupos) {
            for (String num : g.contractNumbers) {
                numberToReason.put(num, g.reason);
                numberToTaskDesc.put(num, g.taskDescription);
            }
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

        // ═══════════════
        //  FASE 1 — SOLO callouts a Chargebee (void invoices + cancel subscription). CERO DML en esta fase.
        List<ChargebeeOutcome> cbOutcomes = chargebeeContracts.isEmpty()
            ? new List<ChargebeeOutcome>()
            : runChargebeeCallouts(chargebeeContracts);

        // ═══════════════
        //  FASE 2 — ya no quedan callouts pendientes: de aquí en  adelante toda la DML (Chargebee + ACH) puede correr.

        // ── 2.1. SM_Customer_Cancellation__c = true en TODOS ─
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
                    System.debug('\u2192 Error marcando SM_Customer_Cancellation__c en Id: '
                        + allToMarkCancellation[i].Id + ' -> ' + collectSaveErrors(markSaves[i]));
                }
            }
        }

        // ── 2.2. Tasks ya existentes (evitar duplicados en reruns) ──
        Map<Id, Set<String>> existingTaskDescByContract =
            loadExistingTaskDescriptions(contractsById.keySet());

        if (!cbOutcomes.isEmpty()) {
            allResults.addAll(finalizeChargebee(
                cbOutcomes, numberToReason, numberToTaskDesc, existingTaskDescByContract));
        }

                //  RAMA ACH — idéntica a -CancelarContratos.apex ═══════════════
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

        // FASE A: Status solo. SM_Reason_for_cancellation__c es un picklist
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

        // FASE B: con Status ya en 'Cancelled'
        List<Contract> reasonUpdates = new List<Contract>();
        for (Id cid : cancelableIds) {
            if (achOrderErrors.containsKey(cid) || statusErrors.containsKey(cid)) continue;
            Contract c = activeAchContracts.get(cid);
            reasonUpdates.add(new Contract(
                Id                             = cid,
                SM_Reason_for_cancellation__c  = numberToReason.get(c.ContractNumber),
                CANCELAR_CONTRATO__c           = numberToReason.get(c.ContractNumber),
                SM_Cancellation_Date__c        = Date.today()
            ));
        }
        Map<Id, String> reasonErrors = modoDryRun
            ? new Map<Id, String>()
            : saveAndCollectErrors(reasonUpdates);

        for (Id cid : cancelableIds) {
            Contract c = activeAchContracts.get(cid);
            List<String> errors = new List<String>();

            if (achOrderErrors.containsKey(cid)) errors.add('\u2192 ACH Orders: ' + achOrderErrors.get(cid));
            if (statusErrors.containsKey(cid))   errors.add('\u2192 Contract (Status): ' + statusErrors.get(cid));
            if (reasonErrors.containsKey(cid))   errors.add('\u2192 Contract (Reason): ' + reasonErrors.get(cid));

            ResultRow row = makeRow(cid, c.ContractNumber,
                modoDryRun ? '\u2192 DRY_RUN_ACH' : (errors.isEmpty() ? 'CANCELLED' : 'PARTIAL/ERROR'),
                modoDryRun ? '\u2192 Se cancelaría (ACH) — Contract + ACH Orders.'
                    : (errors.isEmpty() ? 'Contrato y órdenes actualizados correctamente.' : String.join(errors, ' \uFF5C ')),
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
                    rrDup.detail += ' \uFF5C Task ya existente (no duplicada).';
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
                    rr.detail += ' \uFF5C Task creada.';
                } else {
                    rr.success = false;
                    rr.detail += ' \uFF5C Task error: ' + collectSaveErrors(taskSave[i]);
                }
                allResults[idx] = rr;
            }
        }

        return allResults;
    }

    //  RAMA CHARGEBEE — FASE 1: solo callouts, cero DML. ═══════════════
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
                if (!estadosAOmitirInvoice.contains(inv.chargebeeapps__Status__c)) totalCalloutsPlanned++;
            }
        }
        totalCalloutsPlanned += chargebeeContracts.size(); // +1 posible cancel_for_items por contrato
        if (totalCalloutsPlanned > 90) {
            System.debug('\u2192 ALERTA: ~' + totalCalloutsPlanned
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
                    if (estadosAOmitirInvoice.contains(inv.chargebeeapps__Status__c)) continue; // ya resuelto

                    if (String.isBlank(inv.chargebeeapps__CB_Invoice_Id__c)) {
                        allInvoicesResolved = false;
                        outcome.stepDetails.add('\u2192 Invoice ' + inv.Name + ': sin chargebeeapps__CB_Invoice_Id__c, no se puede anular.');
                        continue;
                    }

                    if (modoDryRun) {
                        outcome.stepDetails.add('\u2192 Invoice ' + inv.Name + ': se anularía (status actual ' + inv.chargebeeapps__Status__c + ').');
                        continue; // en dry run no sabemos el resultado real -> no se puede asumir resuelto
                    }

                    CalloutResult voidRes = callChargebee(
                        'invoices/' + EncodingUtil.urlEncode(inv.chargebeeapps__CB_Invoice_Id__c, 'UTF-8') + '/void',
                        'comment=' + EncodingUtil.urlEncode(voidComment, 'UTF-8')
                    );
                    if (voidRes.success) {
                        outcome.stepDetails.add('\u2192 Invoice ' + inv.Name + ': VOIDED.');
                        inv.chargebeeapps__Status__c = 'VOIDED';
                        outcome.invoicesToUpdate.add(inv);
                    } else {
                        allInvoicesResolved = false;
                        outcome.stepDetails.add('\u2192 Invoice ' + inv.Name + ': ERROR void — ' + voidRes.detail);
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
                    outcome.stepDetails.add('\u2192 Subscription: sin Name/Id, no se puede cancelar.');
                } else {
                    CalloutResult cancelRes = callChargebee(
                        'subscriptions/' + EncodingUtil.urlEncode(subId, 'UTF-8') + '/cancel_for_items',
                        'cancel_option=immediately'
                    );
                    if (cancelRes.success) {
                        outcome.stepDetails.add('\u2192 Subscription ' + subId + ': CANCELLED.');
                        subscriptionOk = true;
                    } else {
                        outcome.stepDetails.add('\u2192 Subscription ' + subId + ': ERROR cancel — ' + cancelRes.detail);
                    }
                }
            }

            outcome.fullCancel = !modoDryRun && allInvoicesResolved && subscriptionOk;
            outcomes.add(outcome);
        }

        return outcomes;
    }

    // ═══════════════
    //  RAMA CHARGEBEE — FASE 2: toda la DML, ya sin callouts
    private List<ResultRow> finalizeChargebee(
        List<ChargebeeOutcome> outcomes,
        Map<String, String> numberToReason,
        Map<String, String> numberToTaskDesc,
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
            row.detail         = String.join(outcome.stepDetails, ' \uFF5C ');
            results.add(row);
            resultIndexByContract.put(outcome.contractId, results.size() - 1);

            if (modoDryRun) continue;

            // FASE A: Status solo (+ campos no dependientes). El Reason es
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
                    rr.detail += '\u2192  \uFF5C Contract error (Status): ' + collectSaveErrors(saves[i]);
                    results[idx] = rr;
                }
            }
        }

        // FASE B: Reason + fecha, solo para los que s\u00ed van a Cancelled y
        List<Contract> reasonUpdates   = new List<Contract>();
        List<Id>       reasonUpdateIds = new List<Id>();
        for (Id cid : statusOkIds) {
            if (!wantsFullCancel.get(cid)) continue;
            String contractNumber = results[resultIndexByContract.get(cid)].contractNumber;
            reasonUpdates.add(new Contract(
                Id                             = cid,
                SM_Reason_for_cancellation__c  = numberToReason.get(contractNumber),
                SM_Cancellation_Date__c        = Date.today()
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
                    rr.detail += '\u2192  \uFF5C Contract error (Reason): ' + collectSaveErrors(saves[i]);
                }
                results[idx] = rr;
            }
        }

        // Tasks solo para los contratos que s\u00ed quedaron Cancelled de verdad.
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
                rr.detail += '\u2192  \uFF5C Task ya existente (no duplicada).';
                results[idx] = rr;
            }
        }
        if (!tasksToInsert.isEmpty()) {
            Database.SaveResult[] taskSave = Database.insert(tasksToInsert, false);
            for (Integer i = 0; i < taskSave.size(); i++) {
                Integer idx  = taskResultIndexes[i];
                ResultRow rr = results[idx];
                if (taskSave[i].isSuccess()) {
                    rr.detail += '\u2192  \uFF5C Task creada.';
                } else {
                    rr.success = false;
                    rr.detail += '\u2192  \uFF5C Task error: ' + collectSaveErrors(taskSave[i]);
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
            req.setEndpoint('callout:' + namedCredential + '/api/v2/' + pathAndId);
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
            r.detail  ='\u2192 ' +  e.getMessage() + ' (línea ' + e.getLineNumber() + ')';
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
//#endregion CUERPO

//  GRUPOS ================
CancelGroup GRUP01 = new CancelGroup(
    'Does not comply with payments',
    'Cliente no cumple con los pagos, Solicitado y Autorizado por ELba Mantilla',
    new Set<String>{
        // ← lista de ContractNumber a procesar
        '00317795'
    }
);

//  EJECUCIÓN ===============
List<ResultRow> outcome =
    new CancelarContratosFullRunner(modoDryRun, NAMED_CRED, VOID_COMMENT, ESTADOS_A_OMITIR_INVOICE)
        .runAll(new List<CancelGroup>{ GRUP01 });  // ← cambia aquí el/los grupo(s) a correr

Integer ok = 0, fail = 0;
List<String> reportLines = new List<String>();
reportLines.add('\u2192 ===============');
reportLines.add('\u2192 REPORTE CANCELAR_CONTRATOS_FULL ' + (modoDryRun ? '(DRY RUN)' : '(EJECUCIÓN REAL)'));
reportLines.add('\u2192 ===============');
for (ResultRow r : outcome) {
    reportLines.add(
        (r.success ? '[OK] ' : '[FAIL] ') + '[' + r.action + '] '
        + r.contractNumber + ' - ' + r.detail
    );
    if (r.success) ok++; else fail++;
}
reportLines.add('\u2192 ===============');
reportLines.add('\u2192 OK: ' + ok + '   Fallidos/Pendientes: ' + fail);
reportLines.add('\u2192 ===============');
System.debug('\u2192 \n\u2192' + String.join(reportLines, '\n'));