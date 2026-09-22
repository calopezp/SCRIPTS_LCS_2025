// ============================================================
//  Corre CancelarContratosRunner.cls (desplegada en MONEE) contra
//  un lote de contratos. Ver .claude/skills/cancelar-contratos/SKILL.md
//  para el flujo completo (cómo agregar contratos nuevos, cómo validar
//  estado, gotchas conocidos).
//
//  SIEMPRE correr primero con modoDryRun = true, revisar el reporte,
//  y solo después pasar a false.
// ============================================================

Boolean modoDryRun = true;

CancelarContratosRunner.CancelGroup grupo = new CancelarContratosRunner.CancelGroup(
    'Does not comply with payments',                                              // reason
    'Cliente no cumple con los pagos, Solicitado y Autorizado por ELba Mantilla',  // Task description
    new Set<String>{
        // ← lista de ContractNumber a procesar
        '00317795'
    }
);

List<CancelarContratosRunner.ResultRow> outcome =
    CancelarContratosRunner.run(new List<CancelarContratosRunner.CancelGroup>{ grupo }, modoDryRun);

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
