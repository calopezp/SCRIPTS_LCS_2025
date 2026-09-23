// ============================================================
//  Corre CancelarContratosRunner.cls (desplegada en MONEE) contra un
//  lote de contratos. Ver .claude/skills/cancelar-contratos/SKILL.md
//  para el flujo completo.
//
//  El bloque "requests" de abajo NO se escribe a mano — se genera con:
//
//    cd COLLECTIONS/CANCELACIONES
//    python generate_run_batch.py --categoria STUCK_CONTRACT_STATUS
//    python generate_run_batch.py 00317661 00317795
//
//  ...y se pega el resultado reemplazando el bloque de ejemplo de abajo.
//  Motivo y Fecha de solicitud (-> SM_Cancellation_Date__c) salen de
//  Contratos_para_Cancelar_LOG.csv, no se inventan acá.
//
//  SIEMPRE correr primero con modoDryRun = true, revisar el reporte, y
//  solo después pasar a false.
// ============================================================

Boolean modoDryRun = false;

// ← pegar acá el bloque generado por generate_run_batch.py
List<CancelarContratosRunner.CancelRequest> requests = new List<CancelarContratosRunner.CancelRequest>{
    new CancelarContratosRunner.CancelRequest('00317661', 'Does not comply with Payments', Date.newInstance(2026, 9, 11)),
    new CancelarContratosRunner.CancelRequest('00317788', 'Does not comply with Payments', Date.newInstance(2026, 9, 11)),
    new CancelarContratosRunner.CancelRequest('00317858', 'Does not comply with Payments', Date.newInstance(2026, 9, 11)),
    new CancelarContratosRunner.CancelRequest('00317861', 'Does not comply with Payments', Date.newInstance(2026, 9, 11)),
    new CancelarContratosRunner.CancelRequest('00317863', 'Does not comply with Payments', Date.newInstance(2026, 9, 11)),
    new CancelarContratosRunner.CancelRequest('00317876', 'Does not comply with Payments', Date.newInstance(2026, 9, 11)),
    new CancelarContratosRunner.CancelRequest('00317916', 'Does not comply with Payments', Date.newInstance(2026, 9, 11)),
    new CancelarContratosRunner.CancelRequest('00317918', 'Does not comply with Payments', Date.newInstance(2026, 9, 11)),
    new CancelarContratosRunner.CancelRequest('00317927', 'Does not comply with Payments', Date.newInstance(2026, 9, 11)),
    new CancelarContratosRunner.CancelRequest('00317957', 'Does not comply with Payments', Date.newInstance(2026, 9, 11)),
    new CancelarContratosRunner.CancelRequest('00318054', 'Does not comply with Payments', Date.newInstance(2026, 9, 11)),
    new CancelarContratosRunner.CancelRequest('00318109', 'Does not comply with Payments', Date.newInstance(2026, 9, 11))
};

List<CancelarContratosRunner.ResultRow> outcome = CancelarContratosRunner.run(requests, modoDryRun);

Integer ok = 0, fail = 0;
List<String> reportLines = new List<String>();
reportLines.add('==========================================================');
reportLines.add('REPORTE CANCELAR_CONTRATOS ' + (modoDryRun ? '(DRY RUN)' : '(EJECUCIÓN REAL)'));
reportLines.add('==========================================================');
for (CancelarContratosRunner.ResultRow r : outcome) {
    reportLines.add(
        (r.success ? '[OK] ' : '[FAIL] ') + '[' + r.action + '] '
        + r.contractNumber + ' - ' + r.detail
    );
    if (r.success) ok++; else fail++;
}
reportLines.add('==========================================================');
reportLines.add('OK: ' + ok + '   Fallidos/Pendientes: ' + fail);
reportLines.add('==========================================================');
System.debug('\n' + String.join(reportLines, '\n'));
