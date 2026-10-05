/*
 * -CONTRACARGO_ACH_R10_R11_BATCH_CANCELLED_2026_TASKS.apex
 * ------------------------------------------------------------
 * Crea el Task de seguimiento 'TIADM - REFUND CONTRA CARGO (R10/R11)' para
 * los 25 payments de contratos Cancelled (piloto 2026) ya corregidos por
 * -CONTRACARGO_ACH_R10_R11_BATCH_CANCELLED_2026.apex (Payment ACCEPTED/
 * COLLECTED + Payment REFUNDED + flags en Contract/Account, corrido real
 * 2026-10-05).
 *
 * Pedido explicito del usuario (2026-10-05): el Task SI se genera tambien
 * para estos contratos Cancelled, no solo para los activos como decia el
 * diseno original (ver TAREAS_PENDIENTES.md fila 2026-10-05).
 *
 * Fechas (confirmado por el usuario 2026-10-05):
 *   - ActivityDate (Due Date) = fecha del REPORTE del banco (no hoy) --
 *     parseada a mano del nombre del archivo (Source_File en
 *     RETURNS/returns_index.csv), porque el indice no guarda esa fecha ya
 *     parseada como columna aparte. Reportes que cubren un rango de dias
 *     (ej. "June 12-15 2026") usan el ULTIMO dia del rango.
 *   - CreatedDate = hoy (no se persigue el valor historico real, ver
 *     TAREAS_PENDIENTES.md fila 2026-10-05 -- Apex anonimo no puede setear
 *     CreatedDate aunque el usuario tenga el permiso "Create Audit Fields").
 *   - Description lleva la fecha de rechazo real (SM_Check_Collection_Date__c
 *     de la fila del reporte) + codigo + fecha/archivo del reporte, para que
 *     quede visible aunque CreatedDate diga hoy.
 *
 * MODO DE USO: correr primero con DRY_RUN=true (preview, no escribe nada).
 * Si todo se ve bien, cambiar a false y correr de nuevo.
 */

// ============ CONFIGURACION ============
Boolean DRY_RUN = false; // <-- cambiar a false para ejecutar real
String TASK_SUBJECT = 'TIADM - REFUND CONTRA CARGO (R10/R11)';
Id TASK_RECORD_TYPE_ID = '0121U00000085XiQAI';
Id TASK_OWNER_ID = '0051U000007bbx5QAA'; // Carlos Lopez
// ========================================

// Datos por payment: codigo de retorno, fecha de rechazo (reporte, fila real),
// fecha del reporte (parseada del nombre del archivo), nombre del archivo.
class Seed {
    String returnCode;
    Date rejectionDate;
    Date reportDate;
    String sourceFile;
    Seed(String rc, Date rd, Date repd, String sf) {
        returnCode = rc; rejectionDate = rd; reportDate = repd; sourceFile = sf;
    }
}

Map<String, Seed> seeds = new Map<String, Seed>{
    'PY-01797727' => new Seed('R11', Date.newInstance(2026,2,26),  Date.newInstance(2026,3,3),  'ACH Returns March 3 2026.pdf'),
    'PY-01802627' => new Seed('R11', Date.newInstance(2026,3,10),  Date.newInstance(2026,4,16), 'ACH Returns April 16 2026.pdf'),
    'PY-01810295' => new Seed('R11', Date.newInstance(2026,3,27),  Date.newInstance(2026,4,8),  'ACH Returns April 8 2026.pdf'),
    'PY-01819316' => new Seed('R11', Date.newInstance(2026,4,17),  Date.newInstance(2026,4,28), 'ACH Returns April 28 2026.pdf'),
    'PY-01824479' => new Seed('R10', Date.newInstance(2026,4,28),  Date.newInstance(2026,5,8),  'ACH Returns May 8 2026.pdf'),
    'PY-01824581' => new Seed('R10', Date.newInstance(2026,4,29),  Date.newInstance(2026,5,8),  'ACH Returns May 8 2026.pdf'),
    'PY-01824989' => new Seed('R10', Date.newInstance(2026,4,30),  Date.newInstance(2026,5,8),  'ACH Returns May 8 2026.pdf'),
    'PY-01828949' => new Seed('R11', Date.newInstance(2026,5,5),   Date.newInstance(2026,5,11), 'ACH Returns May 11 2026.pdf'),
    'PY-01838226' => new Seed('R11', Date.newInstance(2026,5,22),  Date.newInstance(2026,6,2),  'ACH Returns June 1-2 2026.pdf'),
    'PY-01847651' => new Seed('R10', Date.newInstance(2026,6,8),   Date.newInstance(2026,6,15), 'ACH Returns June 12-15 2026.pdf'),
    'PY-01847653' => new Seed('R10', Date.newInstance(2026,6,8),   Date.newInstance(2026,6,15), 'ACH Returns June 12-15 2026.pdf'),
    'PY-01849219' => new Seed('R10', Date.newInstance(2026,6,10),  Date.newInstance(2026,6,30), 'ACH Returns June 30 2026.pdf'),
    'PY-01849469' => new Seed('R10', Date.newInstance(2026,6,11),  Date.newInstance(2026,7,23), 'ACHReturnsReport_07232026.pdf'),
    'PY-01861633' => new Seed('R11', Date.newInstance(2026,7,3),   Date.newInstance(2026,7,17), 'ACHReturnsReport_07172026.pdf'),
    'PY-01865165' => new Seed('R10', Date.newInstance(2026,7,10),  Date.newInstance(2026,7,23), 'ACHReturnsReport_07232026.pdf'),
    'PY-01869482' => new Seed('R10', Date.newInstance(2026,7,30),  Date.newInstance(2026,8,19), 'ACHReturnsReport_08192026.pdf'),
    'PY-01872289' => new Seed('R10', Date.newInstance(2026,7,30),  Date.newInstance(2026,8,19), 'ACHReturnsReport_08192026.pdf'),
    'PY-01883327' => new Seed('R11', Date.newInstance(2026,8,18),  Date.newInstance(2026,9,1),  'ACHReturnsReport_09012026.pdf'),
    'PY-01884620' => new Seed('R11', Date.newInstance(2026,8,20),  Date.newInstance(2026,9,3),  'ACHReturnsReport_09032026.pdf'),
    'PY-01884648' => new Seed('R11', Date.newInstance(2026,8,20),  Date.newInstance(2026,9,3),  'ACHReturnsReport_09032026.pdf'),
    'PY-01884676' => new Seed('R10', Date.newInstance(2026,8,20),  Date.newInstance(2026,8,24), 'ACHReturnsReport_08242026.pdf'),
    'PY-01884694' => new Seed('R11', Date.newInstance(2026,8,20),  Date.newInstance(2026,9,3),  'ACHReturnsReport_09032026.pdf'),
    'PY-01888816' => new Seed('R11', Date.newInstance(2026,8,27),  Date.newInstance(2026,9,15), 'ACH Returns Report_09_15_2026.pdf'),
    'PY-01894631' => new Seed('R10', Date.newInstance(2026,9,3),   Date.newInstance(2026,9,17), 'ACH Returns Report_09_17_2026.pdf'),
    'PY-01895410' => new Seed('R10', Date.newInstance(2026,9,4),   Date.newInstance(2026,9,21), 'ACHReturnsReport_09212026.pdf')
};

System.debug(' -> ======================================================');
System.debug(' -> MODO: ' + (DRY_RUN ? 'DRY RUN (solo preview, sin cambios)' : 'EJECUCION REAL'));
System.debug(' -> Payments en el lote: ' + seeds.size());
System.debug(' -> ======================================================');

List<SM_Payment__c> originals = [
    SELECT Id, Name, SM_Contract__c, SM_Contract__r.ContractNumber, Payment_Status__c, SM_Check_Collection_Status__c
    FROM SM_Payment__c
    WHERE Name IN :seeds.keySet()
];

if (originals.size() != seeds.size()) {
    System.debug(' -> ***** ALERTA: se esperaban ' + seeds.size() + ' payments, se encontraron ' + originals.size() + '. Revisar antes de seguir.');
}

Set<Id> originalIds = new Set<Id>();
for (SM_Payment__c p : originals) { originalIds.add(p.Id); }

Map<Id, String> refundNameByOriginalId = new Map<Id, String>();
for (SM_Payment__c r : [SELECT Name, SM_Payments_refunded__c FROM SM_Payment__c WHERE SM_Payments_refunded__c IN :originalIds AND Payment_Status__c = 'REFUNDED']) {
    refundNameByOriginalId.put(r.SM_Payments_refunded__c, r.Name);
}

Set<Id> contractIds = new Set<Id>();
for (SM_Payment__c p : originals) { contractIds.add(p.SM_Contract__c); }
Set<Id> contractsWithTaskAlready = new Set<Id>();
for (Task t : [SELECT WhatId FROM Task WHERE WhatId IN :contractIds AND Subject = :TASK_SUBJECT]) {
    contractsWithTaskAlready.add(t.WhatId);
}

List<Task> tasksToInsert = new List<Task>();

for (SM_Payment__c original : originals) {
    Seed seed = seeds.get(original.Name);

    if (contractsWithTaskAlready.contains(original.SM_Contract__c)) {
        System.debug(' -> ***** OMITIDO (ya existe un Task de este tipo en el contrato): ' + original.Name + ' / ' + original.SM_Contract__r.ContractNumber);
        continue;
    }

    String refundName = refundNameByOriginalId.get(original.Id);
    if (refundName == null) {
        System.debug(' -> ***** ALERTA: ' + original.Name + ' no tiene un Payment REFUNDED asociado todavia -- revisar antes de crear el Task.');
        refundName = '(sin REFUND encontrado)';
    }

    String description = 'AUTO: CONTRACARGO_ACH_R10_R11 - Payment ' + original.Name +
        ' (Contrato ' + original.SM_Contract__r.ContractNumber + ') - Codigo ' + seed.returnCode +
        ' - Fecha de rechazo (reporte banco): ' + seed.rejectionDate.format() +
        ' - Reporte: ' + seed.reportDate.format() + ' (' + seed.sourceFile + ')' +
        ' - Refund creado: ' + refundName;
    description = description.left(255);

    System.debug(' -> ' + original.Name + ' | Contrato ' + original.SM_Contract__r.ContractNumber +
        ' | ActivityDate: ' + seed.reportDate.format() + ' | ' + description);

    tasksToInsert.add(new Task(
        Subject        = TASK_SUBJECT,
        WhatId         = original.SM_Contract__c,
        OwnerId        = TASK_OWNER_ID,
        RecordTypeId   = TASK_RECORD_TYPE_ID,
        ActivityDate   = seed.reportDate,
        Description    = description
    ));
}

System.debug(' -> ======================================================');
System.debug(' -> RESUMEN: ' + tasksToInsert.size() + ' Tasks a crear');
System.debug(' -> ======================================================');

if (!DRY_RUN) {
    if (!tasksToInsert.isEmpty()) {
        Database.insert(tasksToInsert, false);
    }
    System.debug(' -> COMPLETADO.');
} else {
    System.debug(' -> DRY RUN activo: no se escribio nada. Cambiar DRY_RUN a false para aplicar.');
}
