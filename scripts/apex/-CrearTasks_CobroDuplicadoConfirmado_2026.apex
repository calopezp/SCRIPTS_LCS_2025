/*
 * -CrearTasks_CobroDuplicadoConfirmado_2026.apex
 * ---------------------------------------------------
 * Task de seguimiento para casos de COBRO DUPLICADO CONFIRMADO (2 pagos
 * reales por el mismo concepto, ambos ACCEPTED/COLLECTED) -- mismo patron
 * que el Task 'TIADM - REFUND CONTRA CARGO (R10/R11)' ya usado para
 * contracargos, pero esto es un proceso DISTINTO (no hay REFUND, hay un 2do
 * SM_Payment__c real que refleja el cobro adicional). Faltaba -- solo se
 * habia dejado nota en ANOTACIONES del Payment, sin Task visible en el
 * Contract/Account (pregunta del usuario 2026-10-05).
 *
 * Primeros 2 casos (ya corregidos antes de este Task, se crea retroactivo):
 *   - PY-01907641/00318012: 2 trace numbers Returns + 2 Check Numbers
 *     COLLECTED en CheckCollectionDailyReport_10012026.pdf -- 2do payment
 *     PY-01915498 creado 2026-10-04.
 *   - PY-01907644/00318577: sin ningun reporte en 12 dias (umbral estandar
 *     15 dias) -- Aprob. Elba confirma ambos cobros, 2do payment
 *     PY-01916531 creado 2026-10-05, contrato activado + Subscription
 *     ACH-30203 creada.
 *
 * MODO DE USO: correr primero con DRY_RUN=true (preview, no escribe nada).
 */

Boolean DRY_RUN = false; // <-- cambiar a false para ejecutar real
String TASK_SUBJECT = 'TIADM - COBRO DUPLICADO CONFIRMADO';
Id TASK_RECORD_TYPE_ID = '0121U00000085XiQAI';
Id TASK_OWNER_ID = '0051U000007bbx5QAA'; // Carlos Lopez

class Seed {
    String originalPaymentName;
    String evidencia;
    Date activityDate;
    Seed(String o, String e, Date d) { originalPaymentName = o; evidencia = e; activityDate = d; }
}

Map<String, Seed> seeds = new Map<String, Seed>{
    'PY-01907641' => new Seed('PY-01907641',
        '2 trace numbers Returns (021502013519931/021502014195191) + 2 Check Numbers COLLECTED en CheckCollectionDailyReport_10012026.pdf',
        Date.newInstance(2026, 10, 1)),
    'PY-01907644' => new Seed('PY-01907644',
        'Sin reporte en 12 dias (umbral 15), Aprob. Elba. 2do payment AC->Fee, abona 1ra RC oct, Subscription a nov',
        Date.newInstance(2026, 10, 5))
};

List<SM_Payment__c> originals = [
    SELECT Id, Name, SM_Contract__c, SM_Contract__r.ContractNumber
    FROM SM_Payment__c
    WHERE Name IN :seeds.keySet()
];

if (originals.size() != seeds.size()) {
    System.debug(' -> ***** ALERTA: se esperaban ' + seeds.size() + ' payments, se encontraron ' + originals.size());
}

Set<Id> originalIds = new Set<Id>();
for (SM_Payment__c p : originals) { originalIds.add(p.Id); }

// El 2do payment se identifica por su ANOTACIONES ("-- ver <original>"), no
// hay un campo de referencia dedicado para este proceso (a diferencia de
// SM_Payments_refunded__c en el proceso de contracargo).
Set<Id> contractIds = new Set<Id>();
for (SM_Payment__c p : originals) { contractIds.add(p.SM_Contract__c); }

Map<Id, String> dupNameByContract = new Map<Id, String>();
for (SM_Payment__c p : [
    SELECT Name, SM_Contract__c, SM_Id_Salesforce_LCS__c
    FROM SM_Payment__c
    WHERE SM_Contract__c IN :contractIds
    AND SM_Id_Salesforce_LCS__c LIKE '%cobro ACH duplicado real%'
]) {
    if (!originalIds.contains(p.Id)) {
        dupNameByContract.put(p.SM_Contract__c, p.Name);
    }
}
Set<Id> contractsWithTaskAlready = new Set<Id>();
for (Task t : [SELECT WhatId FROM Task WHERE WhatId IN :contractIds AND Subject = :TASK_SUBJECT]) {
    contractsWithTaskAlready.add(t.WhatId);
}

List<Task> tasksToInsert = new List<Task>();
for (SM_Payment__c original : originals) {
    Seed seed = seeds.get(original.Name);

    if (contractsWithTaskAlready.contains(original.SM_Contract__c)) {
        System.debug(' -> ***** OMITIDO (ya existe Task): ' + original.Name + ' / ' + original.SM_Contract__r.ContractNumber);
        continue;
    }

    String dupName = dupNameByContract.containsKey(original.SM_Contract__c) ? dupNameByContract.get(original.SM_Contract__c) : '(no encontrado)';

    String description = 'AUTO: COBRO_DUPLICADO_CONFIRMADO - Payment original ' + original.Name +
        ' (Contrato ' + original.SM_Contract__r.ContractNumber + ') - 2do payment creado: ' + dupName +
        ' - Evidencia: ' + seed.evidencia;
    description = description.left(255);

    System.debug(' -> ' + original.Name + ' | Contrato ' + original.SM_Contract__r.ContractNumber +
        ' | 2do payment: ' + dupName + ' | ActivityDate: ' + seed.activityDate.format());
    System.debug('    Description: ' + description);

    tasksToInsert.add(new Task(
        Subject      = TASK_SUBJECT,
        WhatId       = original.SM_Contract__c,
        OwnerId      = TASK_OWNER_ID,
        RecordTypeId = TASK_RECORD_TYPE_ID,
        ActivityDate = seed.activityDate,
        Description  = description
    ));
}

System.debug(' -> ======================================================');
System.debug(' -> RESUMEN: ' + tasksToInsert.size() + ' Task(s) a crear');
System.debug(' -> ======================================================');

if (!DRY_RUN) {
    if (!tasksToInsert.isEmpty()) {
        List<Database.SaveResult> results = Database.insert(tasksToInsert, false);
        Integer ok = 0; Integer err = 0;
        for (Database.SaveResult r : results) {
            if (r.isSuccess()) { ok++; }
            else { err++; System.debug(' -> ERROR: ' + r.getErrors()[0].getMessage()); }
        }
        System.debug(' -> COMPLETADO -> Exitos: ' + ok + ' | Errores: ' + err);
    }
} else {
    System.debug(' -> DRY RUN activo: no se creo nada. Cambia DRY_RUN a false para aplicar.');
}
