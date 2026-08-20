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
            SELECT Id, ContractNumber, Status, CB_Subscription__c
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
                    System.debug('⚠️ Error marcando SM_Customer_Cancellation__c en Id: '
                        + allToMarkCancellation[i].Id + ' \u2192 ' + collectSaveErrors(markSaves[i]));
                }
            }
        }

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

        // ── ChargeBee: solo Task ──────────────────────────────
        if (!chargebeeContracts.isEmpty()) {
            System.debug(' \u2192 ═════════════════════════════════════════════════════');
            System.debug(' \u2192 ⚠️  CONTRATOS CHARGEBEE (SM_Customer_Cancellation__c ya marcado, creando Task):');

            List<Task> cbTasksToInsert = new List<Task>();
            List<Id>   cbContractIds   = new List<Id>();

            for (Contract c : chargebeeContracts.values()) {
                if (c.status != 'Cancelled') {
               
                    System.debug('  \u2192 ' + c.ContractNumber + '▫️Id: ' + c.Id + '▫️CB: ' + c.CB_Subscription__c);
                    Task t         = new Task();
                    t.Subject      = TASK_SUBJECT;
                    t.WhatId       = c.Id;
                    t.Description  = numberToTaskDesc.get(c.ContractNumber);
                    t.OwnerId      = TASK_OWNER_ID;
                    t.RecordTypeId = TASK_RT_ID;
                    t.ActivityDate = Date.today();
                    cbTasksToInsert.add(t);
                    cbContractIds.add(c.Id);
                 }
            }

            Database.SaveResult[] cbTaskSaves = Database.insert(cbTasksToInsert, false);
            Map<Id, String> cbTaskErrors      = new Map<Id, String>();
            for (Integer i = 0; i < cbTasksToInsert.size(); i++) {
                if (!cbTaskSaves[i].isSuccess())
                    cbTaskErrors.put(cbContractIds[i], collectSaveErrors(cbTaskSaves[i]));
            }

            for (Contract c : chargebeeContracts.values()) {
                Boolean taskOk = !cbTaskErrors.containsKey(c.Id);
                List<String> details = new List<String>{ 'CB_Subscription__c: ' + c.CB_Subscription__c };
                if (taskOk) details.add('SM_Customer_Cancellation__c = true ▫️ Task creada.');
                else        details.add('Task error: ' + cbTaskErrors.get(c.Id));
                allResults.add(makeRow(
                    c.Id, c.ContractNumber,
                    taskOk ? 'CHARGEBEE_OK' : 'PARTIAL/ERROR',
                    String.join(details, ' 🔸 '),
                    taskOk,
                    numberToReason.get(c.ContractNumber)
                ));
            }
            System.debug(' \u2192 ══════════════════════════════════════════════════════');
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
                        blocking.add(
                            p.Name
                            + '▫️Status: '         + (p.SM_Check_Collection_Status__c != null ? p.SM_Check_Collection_Status__c : 'NULL')
                            + '▫️CollDate: '       + (p.SM_Check_Collection_Date__c   != null ? String.valueOf(p.SM_Check_Collection_Date__c) : 'NULL')
                            + '▫️ACHTransmitted: ' + (p.SM_Date_ACH_Transmitted__c    != null ? String.valueOf(p.SM_Date_ACH_Transmitted__c)  : 'NULL')
                        );
                    }
                }
                allResults.add(makeRow(c.Id, c.ContractNumber, 'SKIP',
                    'Payment ACH bloqueante \u2192 ' + String.join(blocking, ' 🔸 '),
                    false, numberToReason.get(c.ContractNumber)));
            }
        }
        if (cancelableIds.isEmpty()) return allResults;

        // ── 6. ACH Orders => Canceled ─────────────────────────
        List<SM_ACH_Order__c> achOrdersToCancel = [
            SELECT Id, SM_Payment_Status__c, SM_Contract__c
            FROM   SM_ACH_Order__c
            WHERE  SM_Contract__c IN :cancelableIds
              AND  SM_Payment_Status__c IN :ORDER_STATES_TO_CANCEL
        ];
        for (SM_ACH_Order__c o : achOrdersToCancel) o.SM_Payment_Status__c = 'Canceled';

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

        // ── 7. Contratos => Cancelled ─────────────────────────
        List<Contract> contractsToUpdate = new List<Contract>();
        for (Id cid : cancelableIds) {
            Contract c = activeAchContracts.get(cid);
            c.Status                        = 'Cancelled';
            c.SM_Reason_for_cancellation__c = numberToReason.get(c.ContractNumber);
            c.SM_Cancellation_Date__c       = Date.today();
            contractsToUpdate.add(c);
        }

        // ── 8. DML en bloque ─────────────────────────────────
        Map<Id, String> achOrderErrors      = saveAndCollectErrors(achOrdersToCancel);
        Map<Id, String> contractErrors      = saveAndCollectErrors(contractsToUpdate);

        // ── 9. Tasks + ResultRows ─────────────────────────────
        List<Task>    tasksToInsert     = new List<Task>();
        List<Integer> taskResultIndexes = new List<Integer>();

        for (Id cid : cancelableIds) {
            Contract c      = activeAchContracts.get(cid);
            String taskDesc = numberToTaskDesc.get(c.ContractNumber);
            String grp      = numberToReason.get(c.ContractNumber);
            List<String> errors = new List<String>();

            if (contractErrors.containsKey(cid))      errors.add('Contract: '        + contractErrors.get(cid));
            if (achOrderErrors.containsKey(cid))      errors.add('ACH Orders: '      + achOrderErrors.get(cid));

            ResultRow row = makeRow(cid, c.ContractNumber,
                errors.isEmpty() ? 'CANCELLED'    : 'PARTIAL/ERROR',
                errors.isEmpty() ? 'Contrato y órdenes actualizados correctamente.' : String.join(errors, ' 🔸 '),
                errors.isEmpty(), grp
            );
            allResults.add(row);

            if (errors.isEmpty()) {
                Task t         = new Task();
                t.Subject      = TASK_SUBJECT;
                t.WhatId       = cid;
                t.Description  = taskDesc;
                t.OwnerId      = TASK_OWNER_ID;
                t.RecordTypeId = TASK_RT_ID;
                t.ActivityDate = Date.today();
                tasksToInsert.add(t);
                taskResultIndexes.add(allResults.size() - 1);
            }
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
                    rr.action  = 'PARTIAL/ERROR';
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
        if (rec instanceof SM_ACH_Order__c)                  return (Id) rec.get('SM_Contract__c');
        if (rec instanceof ChargentOrders__ChargentOrder__c) return (Id) rec.get('Contract__c');
        if (rec instanceof Contract)                         return (Id) rec.get('Id');
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
        // 19 Jun (31)
        '00317211','00317272','00317357','00317416','00317457','00317088','00317096','00317197','00317296',     // excluir ,'00317359'
        '00317334','00317338','00317344','00317369','00317103','00317022','00317203','00317361','00316868','00317083',
        '00317199','00317281','00317316','00317350','00317358','00317380','00317402','00317443','00317453','00317465',
        '00317491',
        // 10 Jun (44)
        '00315754','00276428','00269200','00286155','00311944','00312296','00312717','00313476','00313404','00314086',
        '00314010','00314371','00314418','00314646','00314601','00314599','00314642','00314776','00314981','00314982',
        '00314808','00314903','00315006','00315033','00315066','00315103','00314998','00315070','00315165','00315106',
        '00315176','00315303','00315234','00315494','00315250','00315177','00315702','00315803','00315345','00316124',
        '00315751','00315990','00316010','00315703'
        // TOTAL: 75
    }
);

CancelGroup GRUP02 = new CancelGroup(
    'Does not comply with payments',
    'Cliente no cumple con los pagos, Solicitado y Autorizado por ELba Mantilla',
    new Set<String>{
        // 23 Mar (19)
        '00316330','00316465','00316308','00316034','00316438','00316357','00316380','00316430','00316344','00316035',
        '00315978','00316343','00316495','00316389','00316321','00316264','00316429','00316265','00316287',
        // 06 Mar (60)
        '00259558','00302396','00309104','00309329','00310666',
        '00312728','00312732','00312814','00312894','00313120','00313233','00313346','00313485','00313731','00313775',
        '00313842','00314314','00314360','00314361','00314484','00314585','00314843','00314880','00315065','00315110',
        '00315558','00315587','00315612','00315624','00315639','00315738','00315788','00315789','00315791','00315795',
        '00315805','00315825','00315830','00315847','00315852','00315856','00315862','00315908','00315926','00315935',
        '00315948','00315985','00315995','00316014','00316037','00316038','00316098','00316147','00316171','00316212'
        // TOTAL: 79
    }
);

CancelGroup GRUP03 = new CancelGroup(
    'Does not comply with payments',
    'Cliente no cumple con los pagos, Solicitado y Autorizado por ELba Mantilla',
    new Set<String>{
        // 09 Feb — primera mitad (83)
        '00309408','00274381','00241829','00315338','00314751','00315322','00313173','00313274','00313535','00314497',
        '00315223','00315047','00314881','00315096','00314389','00315284','00310241','00309545','00313121','00314438',
        '00315195','00314091','00313203','00314764','00313425','00315089','00310489','00315002','00314714','00311956',
        '00314499','00314479','00312116','00312182','00315173','00311391','00313908','00312290','00315194','00313828',
        '00314064','00314759','00314938','00314727','00314161','00314831','00314020','00314373','00314413','00314812',
        '00314111','00314979','00314403','00315049','00314896','00313326','00314679','00315297','00315247','00315060',
        '00314616','00314758','00314451','00313225','00314651','00314052','00314628','00314617','00313283','00315021',
        '00313619','00313224','00313430','00314899','00315157','00315262','00314687','00315084','00314703','00314907',
        '00314217','00314205','00314327'
        // TOTAL: 83
    }
);

CancelGroup GRUP04 = new CancelGroup(
    'Does not comply with payments',
    'Cliente no cumple con los pagos, Solicitado y Autorizado por ELba Mantilla',
    new Set<String>{
        // 03 Feb (25)
        '00313321','00307629','00311669','00312542','00312940','00313052','00313109','00313166','00313521','00313654',
        '00314193','00314435','00314791','00314904','00314931','00314993','00315023','00315024','00315025','00315085',
        '00315094','00315145','00313400','00315285','00310961',
        // 13 Ene (9)
        '00313053','00313565','00313876','00313948','00314178','00314179','00314206','00314265','00314485'
        // TOTAL: 34
    }
);

CancelGroup GRUP05 = new CancelGroup(
    'Does not comply with payments',
    'Cliente no cumple con los pagos, Solicitado y Autorizado por ELba Mantilla',
    new Set<String>{
        // 19 Dic 2025 (63)
        '00289937','00311887','00309564','00312251','00312270','00312669','00312713','00312868','00313112','00313178',
        '00313229','00313496','00313658','00313857','00313892','00314055','00314074','00314241','00314281','00314289',
        '00314302','00314324','00314329','00314333','00314343','00314346','00314356','00314378','00314405','00314409',
        '00314421','00314423','00314477','00314488','00314515','00314517','00314540','00314544','00314602','00314609',
        '00314637','00314657','00314685','00314708','00314709','00314710','00314716','00314721','00314728','00314731',
        '00314777','00314788','00314805','00314811','00314886','00314913','00314914','00314924','00314939','00314987',
        '00315020','00311797','00313513'
        // TOTAL: 63
    }
);

CancelGroup GRUP06 = new CancelGroup(
    'Evidence not Complete',
    'Cliente no ha entregado evidencias para poderle trabajar',
    new Set<String>{
        '00315295','00315317','00315346','00315379','00315430',
        '00315409','00315344','00315450','00315547','00315556','00315581'
    }
);

CancelGroup GRUP07 = new CancelGroup(
    'Does not comply with the obligations of the Contract',
    'PI no firmado',
    new Set<String>{
        // 28 May
        '00315764','00315743','00315859','00316186','00315386','00315976','00316364','00315999','00316058','00315996',
        '00315882','00316006','00316293','00316071','00316273','00316538','00316320','00316144',
        // 15 Jun - auth Rosaura por Team
        '00316074','00316078','00316202','00316204','00316313','00316406','00316464','00316537','00316580','00316670'
    }
);

CancelGroup GRUP08 = new CancelGroup(

    'Does not comply with payments',
    'Cliente no cumple con los pagos, Solicitado y Autorizado por ELba Mantilla',
    new Set<String>{
        // 06 Jul (25)
       
        '00315682','00315771','00315943','00261363','00309080','00309290','00313510','00313586','00313656','00314049',
        '00314593','00314743','00314848','00315220','00315302','00315412','00315524','00315817','00315818','00250379',
        '00311899','00312321','00312796','00312806','00312849','00313848','00314625','00314695','00314836','00314946'
        // TOTAL: 30
    }
);

CancelGroup GRUP09 = new CancelGroup(

    'Does not comply with payments',
    'Cliente no cumple con los pagos, Solicitado y Autorizado por ELba Mantilla',
    new Set<String>{
        // 06 Jul (25)
        '00314985','00314986','00315113','00315305','00315411','00315431','00315432','00315469','00315485','00315588',
        '00315600','00315665','00315719','00315758','00315776','00315939','00315947','00316013','00316209','00316258',
        '00316277','00316286','00310680','00312523','00312879','00313985','00314401','00314580','00314856','00315260'
        // TOTAL: 30
    }
);

CancelGroup GRUP10 = new CancelGroup(

    'Does not comply with payments',
    'Cliente no cumple con los pagos, Solicitado y Autorizado por ELba Mantilla',
    new Set<String>{
        // 06 Jul (25)
        
        '00315391','00315652','00315723','00315742','00315988','00315993','00316046','00316073','00316637','00312234',
        '00316059','00316417','00316451','00316461','00316515','00316585'

        // TOTAL: 32
    }
);

CancelGroup GRUP11 = new CancelGroup(

    'Does not comply with payments',
    'Cliente no cumple con los pagos, Solicitado y Autorizado por ELba Mantilla',
    new Set<String>{
        // 12 Ago (25/50)
        
        '00264042','00300131','00304403','00308741','00308911','00311156','00312102','00312747','00312996','00313051',
        '00313441','00313562','00313840','00313841','00313920','00313963','00314008','00314062','00314267','00314335',
        '00314406','00314501','00314554','00314555','00314559'
        // TOTAL: 50
    }
);
CancelGroup GRUP12 = new CancelGroup(

    'Does not comply with payments',
    'Cliente no cumple con los pagos, Solicitado y Autorizado por ELba Mantilla',
    new Set<String>{
        // 12 Ago (25/50)
        '00314621','00314784','00314888','00314950','00315073',
        '00315142','00315140','00315148','00315183','00315264','00315426','00315452','00315499','00315571','00315574',
        '00315638','00315725','00315870','00316032','00316307','00316338','00316391','00316485','00316735','00313315'

        // TOTAL: 50
    }
);

CancelGroup GRUP13 = new CancelGroup(

    'Does not comply with payments',
    'Cliente no cumple con los pagos, Solicitado y Autorizado por ELba Mantilla',
    new Set<String>{
        // 13 Ago (25/70)
        '00317923','00304403','00264042','00300131','00308741','00308911','00311156','00312102','00312747','00313051',
        '00312996','00313441','00313315','00313562','00313840','00313841','00314062','00313920','00314267','00314335',
        '00314008','00313963','00314406','00314501','00314554'

        // TOTAL: 70
    }
);
CancelGroup GRUP14 = new CancelGroup(

    'Does not comply with payments',
    'Cliente no cumple con los pagos, Solicitado y Autorizado por ELba Mantilla',
    new Set<String>{
        // 13 Ago (25/70)
        '00314559','00314555','00314621','00314784','00315867','00315871','00314888','00315797','00315796','00315073',
        '00315183','00316036','00316206','00315820','00315148','00314950','00315140','00315934','00315142','00315886',
        '00316060','00315499','00316079','00315426','00316032'

        // TOTAL: 70
    }
);

CancelGroup GRUP15 = new CancelGroup(

    'Does not comply with payments',
    'Cliente no cumple con los pagos, Solicitado y Autorizado por ELba Mantilla',
    new Set<String>{
        // 13 Ago (19/69)
        '00315638','00315870','00315452','00315264','00315725','00315574','00316391','00314635','00316616','00316651',
        '00316338','00316722','00316485','00317730','00316735','00315571','00316307','00316967','00310747'
        // TOTAL: 69
    }
);

CancelGroup GRUP16 = new CancelGroup(

    'Does not comply with payments',
    'Cliente no cumple con los pagos, Solicitado y Autorizado por ELba Mantilla',
    new Set<String>{
        // 13 Ago (19/69)
'00264042','00300131','00304403','00308741','00308911','00311156','00312102','00312747','00312996','00313051','00313315','00313441','00313562','00313841','00313920','00313963','00314008','00314267','00314554','00314555','00314784','00314888','00314950','00315140','00315142','00315264','00315452','00315571','00315574','00315867','00315870','00315871','00315886','00316338','00316485','00316722','00317730'

       // TOTAL: 69
    }
);



// ============================================================
//  EJECUCIÓN — cambia el grupo según lo que vayas a correr
// ============================================================
List<ResultRow> outcome =
    new CancelarContratosPorNumberRunner().runAll(
        new List<CancelGroup>{ GRUP16 }  // ← cambia aquí
    );

Integer ok = 0, fail = 0;
System.debug(' \u2192 ══════════════════════════════════════════════════════');
System.debug(' \u2192 📋  REPORTE DE PROBLEMAS Y RESTRICCIONES');
System.debug(' \u2192 ══════════════════════════════════════════════════════');
for (ResultRow r : outcome) {
    if (!r.success) {
        System.debug(
            ' \u2192 ❌ [' + r.action + '] '
            +  r.contractNumber
            + '▫️Id: '      + (r.contractId != null ? String.valueOf(r.contractId) : 'N/A')
            + '▫️Grupo: '   + r.groupName
            + '▫️Detalle: ' + r.detail
        );
        fail++;
    } else {
        ok++;
    }
}
System.debug(' \u2192 ══════════════════════════════════════════════════════');
System.debug(' \u2192 ✅ Cancelados: ' + ok + '   ❌ Fallidos/Bloqueados: ' + fail);
System.debug(' \u2192 ══════════════════════════════════════════════════════');