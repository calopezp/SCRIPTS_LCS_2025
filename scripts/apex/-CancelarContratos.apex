// ============================================================
//  DTOs
// ============================================================
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

// ============================================================
//  CLASE PRINCIPAL
// ============================================================
public class CancelarContratosPorNumberRunner {

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

        // ── 1. Cargar contratos ───────────────────────────────
        Map<Id, Contract> contractsById = new Map<Id, Contract>([
            SELECT Id, ContractNumber, Status, CB_Subscription__c, CB_Subscription__r.chargebeeapps__Subscription_status__c
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

        // ── 1.5. SM_Customer_Cancellation__c = true en TODOS ─
        List<Contract> allToMarkCancellation = new List<Contract>();
        for (Contract c : contractsById.values()) {
            allToMarkCancellation.add(new Contract(
                Id                          = c.Id,
                SM_Customer_Cancellation__c = true
                
            ));
        }
        if (!allToMarkCancellation.isEmpty()) {
            Database.SaveResult[] markSaves = Database.update(allToMarkCancellation, false);
            for (Integer i = 0; i < allToMarkCancellation.size(); i++) {
                if (!markSaves[i].isSuccess()) {
                    System.debug('\u2192 ⚠️ Error marcando SM_Customer_Cancellation__c en Id: '
                        + allToMarkCancellation[i].Id + ' \u2192 ' + collectSaveErrors(markSaves[i]));
                }
            }
        }

        // ── 1.6. Tasks ya existentes (evitar duplicados en reruns) ──
        // Mismo criterio que al crear la Task (Subject/OwnerId/RecordTypeId/Description),
        // sin considerar ActivityDate porque cambia en cada corrida.
        Map<Id, Set<String>> existingTaskDescByContract =
            loadExistingTaskDescriptions(contractsById.keySet());

        // ── 2. Separar ChargeBee vs ACH ──────────────────────
        Map<Id, Contract> chargebeeContracts = new Map<Id, Contract>();
        Map<Id, Contract> achContracts       = new Map<Id, Contract>();
        for (Contract c : contractsById.values()) {
            if (String.isNotBlank(c.CB_Subscription__c)) {
                chargebeeContracts.put(c.Id, c);
            } else {
                achContracts.put(c.Id, c);
            }
        }

        // ── ChargeBee: revisión de INVOICEs / Subscription, Contract + Task ──
        if (!chargebeeContracts.isEmpty()) {
            String cbLogLinea = '';
            List<String> cbLogLines = new List<String>();
            cbLogLines.add('\u2192 ══════════════════════════════════════════════════════');
            cbLogLines.add('\u2192 ⚠️  CONTRATOS CHARGEBEE (revision de INVOICEs / Subscription):');

            // Invoices asociados a los contratos ChargeBee de este lote
            Map<Id, List<chargebeeapps__CB_Invoice__c>> invoicesByContract =
                new Map<Id, List<chargebeeapps__CB_Invoice__c>>();
            for (chargebeeapps__CB_Invoice__c inv : [
                SELECT Id, Name, chargebeeapps__Status__c, Contract__c
                FROM   chargebeeapps__CB_Invoice__c
                WHERE  Contract__c IN :chargebeeContracts.keySet()
            ]) {
                if (!invoicesByContract.containsKey(inv.Contract__c))
                    invoicesByContract.put(inv.Contract__c, new List<chargebeeapps__CB_Invoice__c>());
                invoicesByContract.get(inv.Contract__c).add(inv);
            }

            List<Task>       cbTasksToInsert      = new List<Task>();
            List<Id>         cbContractIds        = new List<Id>();
            List<Contract>   cbContractsToUpdate  = new List<Contract>();
            Map<Id, String>  cbActionLabelById    = new Map<Id, String>();
            Map<Id, String>  cbInvoiceSummaryById = new Map<Id, String>();
            Set<Id>          cbTaskSkippedDup     = new Set<Id>();

            for (Contract c : chargebeeContracts.values()) {
                if (c.status != 'Cancelled') {
                    String subStatus = c.CB_Subscription__r.chargebeeapps__Subscription_status__c;
                    cbLogLines.add('\u2192 ' + c.ContractNumber + '\u25AB Id: ' + c.Id + '\u25AB CB: ' + c.CB_Subscription__c + ' - ' + subStatus);

                    List<chargebeeapps__CB_Invoice__c> invs = invoicesByContract.get(c.Id);
                    Boolean allResolved = true;
                    List<String> invLines = new List<String>();
                    if (invs == null || invs.isEmpty()) {
                        cbLogLines.add('\u2192     Invoices: (ninguno)');
                        invLines.add('(ninguno)');
                    } else {
                        for (chargebeeapps__CB_Invoice__c inv : invs) {
                            cbLogLines.add('\u2192                    Invoice: ' + inv.Name + ' \u25AB Status: ' + inv.chargebeeapps__Status__c);
                            invLines.add(inv.Name + ' (' + inv.chargebeeapps__Status__c + ')');
                            if (inv.chargebeeapps__Status__c != 'VOIDED' && inv.chargebeeapps__Status__c != 'PAID') allResolved = false;
                        }
                    }
                    cbInvoiceSummaryById.put(c.Id, String.join(invLines, ', '));

                    Boolean fullCancel  = allResolved && subStatus == 'CANCELLED';
                    String  actionLabel = fullCancel ? 'CHARGEBEE CANCELADO FULL'
                                        : (allResolved ? 'CANCELAR SUBSC' : 'CANCELAR INVOICES');
                    cbActionLabelById.put(c.Id, actionLabel);
                    cbLogLines.add('\u2192     Accion: ' + actionLabel);

                    if (!fullCancel) {
                        cbLogLinea = cbLogLinea + '\'' + c.ContractNumber + '\',';
                    }

                    String taskDesc = numberToTaskDesc.get(c.ContractNumber);
                    Boolean taskAlreadyExists =
                        existingTaskDescByContract.containsKey(c.Id) &&
                        existingTaskDescByContract.get(c.Id).contains(taskDesc);

                    if (!taskAlreadyExists) {
                        Task t         = new Task();
                        t.Subject      = TASK_SUBJECT;
                        t.WhatId       = c.Id;
                        t.Description  = taskDesc;
                        t.OwnerId      = TASK_OWNER_ID;
                        t.RecordTypeId = TASK_RT_ID;
                        t.ActivityDate = Date.today();
                        cbTasksToInsert.add(t);
                        cbContractIds.add(c.Id);
                    } else {
                        cbTaskSkippedDup.add(c.Id);
                    }

                    Contract upd = new Contract(
                        Id                          = c.Id,
                        SM_Customer_Cancellation__c = true,
                        CANCELAR_CONTRATO__c        = numberToReason.get(c.ContractNumber)
                    );
                    if (fullCancel) {
                        upd.Status                        = 'Cancelled';
                        upd.SM_Reason_for_cancellation__c = numberToReason.get(c.ContractNumber);
                        upd.SM_Cancellation_Date__c       = Date.today();
                    }
                    cbContractsToUpdate.add(upd);
                 }
            }

            cbLogLines.add('\u2192 ══════════════════════════════════════════════════════');
            System.debug('\u2192 \n' + String.join(cbLogLines, '\n'));
            System.debug('\u2192 PENDIENTES DE CHARGEBEE : \n \u2192' + cbLogLinea + '\n');

            Map<Id, String> cbContractErrors = saveAndCollectErrors(cbContractsToUpdate);

            Database.SaveResult[] cbTaskSaves = Database.insert(cbTasksToInsert, false);
            Map<Id, String> cbTaskErrors      = new Map<Id, String>();
            for (Integer i = 0; i < cbTasksToInsert.size(); i++) {
                if (!cbTaskSaves[i].isSuccess())
                    cbTaskErrors.put(cbContractIds[i], collectSaveErrors(cbTaskSaves[i]));
            }

            for (Contract c : chargebeeContracts.values()) {
                if (c.status == 'Cancelled') continue;
                Boolean taskOk     = !cbTaskErrors.containsKey(c.Id);
                Boolean contractOk = !cbContractErrors.containsKey(c.Id);
                List<String> details = new List<String>{
                    'CB_Subscription__c: ' + c.CB_Subscription__c,
                    'Invoices: ' + cbInvoiceSummaryById.get(c.Id),
                    'Accion: ' + cbActionLabelById.get(c.Id)
                };
                if (contractOk) details.add('SM_Customer_Cancellation__c = true - CANCELAR_CONTRATO__c actualizado.'
                    + (cbActionLabelById.get(c.Id) == 'CHARGEBEE CANCELADO FULL' ? ' - Status = Cancelled.' : ''));
                else            details.add('Contract error: ' + cbContractErrors.get(c.Id));
                if (cbTaskSkippedDup.contains(c.Id)) details.add('Task ya existente (no duplicada).');
                else if (taskOk)                     details.add('Task creada.');
                else                                  details.add('Task error: ' + cbTaskErrors.get(c.Id));
                allResults.add(makeRow(
                    c.Id, c.ContractNumber,
                    (taskOk && contractOk) ? 'CHARGEBEE_OK' : 'PARTIAL/ERROR',
                    String.join(details, ' - '),
                    taskOk && contractOk,
                    numberToReason.get(c.ContractNumber)
                ));
            }
        }
        if (achContracts.isEmpty()) return allResults;

        // ── 3. Omitir ya cancelados ───────────────────────────
        Map<Id, Contract> activeAchContracts = new Map<Id, Contract>();
        for (Contract c : achContracts.values()) {
            if (c.Status != 'Cancelled') activeAchContracts.put(c.Id, c);
        }
        if (activeAchContracts.isEmpty()) return allResults;

        // ── 4. Pagos REJECTED / ACH TRANSMITTED ───────────────
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

        // ── 5. Clasificar cancelable vs bloqueado ─────────────
        Set<Id> cancelableIds = new Set<Id>();
        Map<Id, Integer> resultRowIndexByContract = new Map<Id, Integer>();
        String achLogLinea = '';

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
                achLogLinea = achLogLinea + '\'' + c.ContractNumber + '\',';
            }
        }
        System.debug('\u2192 PENDIENTES DE ACH (pendientes, bloqueados) : \n\n \u2192' + achLogLinea + '\n\n');

        // ── 6. ACH Orders => Canceled (solo contratos cancelables) ──
        Map<Id, String> achOrderErrors = new Map<Id, String>();
        if (!cancelableIds.isEmpty()) {
            List<SM_ACH_Order__c> achOrdersToCancel = [
                SELECT Id, SM_Payment_Status__c, SM_Contract__c
                FROM   SM_ACH_Order__c
                WHERE  SM_Contract__c IN :cancelableIds
                  AND  SM_Payment_Status__c IN :ORDER_STATES_TO_CANCEL
            ];
            for (SM_ACH_Order__c o : achOrdersToCancel) o.SM_Payment_Status__c = 'Canceled';
            achOrderErrors = saveAndCollectErrors(achOrdersToCancel);
        }

        // NOTA: Chargent App fue retirada/deshabilitada en este org.
        // ChargentOrders__ChargentOrder__c ya no es consultable via SOQL, se omite.

        Set<Id> nonCancelableIds = new Set<Id>(activeAchContracts.keySet());
        nonCancelableIds.removeAll(cancelableIds);
        if (!nonCancelableIds.isEmpty()) {
            List<SM_ACH_Order__c> achOrdersToStop = [
                SELECT Id, SM_Payment_Status__c
                FROM   SM_ACH_Order__c
                WHERE  SM_Contract__c IN :nonCancelableIds
                  AND  SM_Payment_Status__c != 'Canceled'
            ];
            for (SM_ACH_Order__c o : achOrdersToStop) o.SM_Payment_Status__c = 'CANCELED';
            if (!achOrdersToStop.isEmpty()) Database.update(achOrdersToStop, false);
        }

        // ── 7. Contratos => Cancelled ──────────────────────────
        List<Contract> contractsToUpdate = new List<Contract>();
        for (Id cid : cancelableIds) {
            if (achOrderErrors.containsKey(cid)) continue;
            Contract c = activeAchContracts.get(cid);
            c.Status                        = 'Cancelled';
            c.SM_Reason_for_cancellation__c = numberToReason.get(c.ContractNumber);
            c.CANCELAR_CONTRATO__c          = numberToReason.get(c.ContractNumber);
            c.SM_Cancellation_Date__c       = Date.today();
            contractsToUpdate.add(c);
        }
        Map<Id, String> contractErrors = saveAndCollectErrors(contractsToUpdate);

        // ── 8. ResultRows para contratos cancelables ──────────
        for (Id cid : cancelableIds) {
            Contract c = activeAchContracts.get(cid);
            List<String> errors = new List<String>();

            if (achOrderErrors.containsKey(cid)) errors.add('ACH Orders: ' + achOrderErrors.get(cid));
            if (contractErrors.containsKey(cid)) errors.add('Contract: '   + contractErrors.get(cid));

            ResultRow row = makeRow(cid, c.ContractNumber,
                errors.isEmpty() ? 'CANCELLED'    : 'PARTIAL/ERROR',
                errors.isEmpty() ? 'Contrato y órdenes actualizados correctamente.' : String.join(errors, ' 🔸 '),
                errors.isEmpty(), numberToReason.get(c.ContractNumber)
            );
            allResults.add(row);
            resultRowIndexByContract.put(cid, allResults.size() - 1);
        }

        // ── 9. Tasks: TODOS los contratos ACH activos (cancelados o bloqueados) ──
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
                    rrDup.detail += ' 🔸 Task ya existente (no duplicada).';
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

        // ── 10. Insertar Tasks ────────────────────────────────
        if (!tasksToInsert.isEmpty()) {
            Database.SaveResult[] taskSave = Database.insert(tasksToInsert, false);
            for (Integer i = 0; i < taskSave.size(); i++) {
                Integer idx  = taskResultIndexes[i];
                ResultRow rr = allResults[idx];
                if (taskSave[i].isSuccess()) {
                    rr.detail += ' 🔸 Task creada.';
                } else {
                    rr.success = false;
                    rr.detail += ' 🔸 Task error: ' + collectSaveErrors(taskSave[i]);
                }
                allResults[idx] = rr;
            }
        }

        return allResults;
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


// ============================================================
//  GRUPOS — GRUPO1 partido en 4 bloques de ~88 c/u
// ============================================================
CancelGroup GRUP01 = new CancelGroup(
    'Does not comply with payments',
    'Cliente no cumple con los pagos, Solicitado y Autorizado por ELba Mantilla',
    new Set<String>{
        //PENDIENTES DE CANCELAR POR PAGOS EN PROCESO U OTROS
        
        // ACH
        '00264042','00314267','00317304','00317312','00317315','00317387','00317478','00317634'

        // CHARGEBEEE
        
    }
);

CancelGroup GRUP02 = new CancelGroup(
    'Does not comply with payments',
    'Cliente no cumple con los pagos, Solicitado y Autorizado por ELba Mantilla',
    new Set<String>{
        '00264042','00314267','00317304'
    ,'00317661','00317718','00317788','00317835','00317858','00317861','00317863','00317876','00317915','00317916','00317918','00317927','00317930','00317954','00317957','00317971','00317974','00318018','00318022','00318054','00318092','00318109',
    }
);
CancelGroup GRUP03 = new CancelGroup(
    'Does not comply with the obligations of the Contract',
    'Cliente no ha entregado evidencias/documentación para poderle trabajar, Solicitado Rosaura',
    new Set<String>{
'00317661','00317665','00317703','00317717','00317718','00317745','00317762','00317772','00317788','00317795','00317803','00317807','00317816','00317822','00317823','00317830','00317835','00317851','00317858','00317861','00317863','00317870','00317876','00317881','00317915','00317916','00317918','00317927','00317928','00317930','00317942','00317948','00317954','00317957','00317970','00317971','00317974','00318000','00318018','00318022','00318036','00318054','00318092','00318109'

    }
);

// ============================================================
//  EJECUCIÓN — cambia el grupo según lo que vayas a correr
// ============================================================
List<ResultRow> outcome =
    new CancelarContratosPorNumberRunner().runAll(
        new List<CancelGroup>{ GRUP03 }  // ← cambia aquí
    );

Integer ok = 0, fail = 0;
List<String> reportLines = new List<String>();
reportLines.add('\u2192 ══════════════════════════════════════════════════════');
reportLines.add('\u2192📋  REPORTE DE PROBLEMAS Y RESTRICCIONES');
reportLines.add('\u2192 ══════════════════════════════════════════════════════');
for (ResultRow r : outcome) {
    if (!r.success) {
        reportLines.add(
            '\u2192 ❌ [' + r.action + '] '
            +  r.contractNumber
            + '\u25AB Detalle: ' + r.detail
        );
        fail++;
    } else {
        ok++;
    }
}
reportLines.add('\u2192 ══════════════════════════════════════════════════════');
reportLines.add('\u2192 ✅ Cancelados: ' + ok + '   ❌ Fallidos/Bloqueados: ' + fail);
reportLines.add('\u2192 ══════════════════════════════════════════════════════');
System.debug('\u2192 \n' + String.join(reportLines, '\n'));
