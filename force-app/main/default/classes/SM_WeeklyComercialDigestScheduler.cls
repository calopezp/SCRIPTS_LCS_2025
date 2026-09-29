/**
 * @description Dispara el compilado semanal de return codes para Comercial
 * (SM_ReturnCodeNotifier.sendWeeklyComercialDigest()) todos los lunes. Usa el modo reducido
 * (fullBacklog=false) -- el backlog acumulado se colapsa a una linea por categoria en vez de
 * listar cada contrato, para no repetir el mismo listado completo cada semana (decision
 * explicita del usuario, 2026-09-24; el envio manual/bajo demanda sigue mostrando el backlog
 * completo, ver sendWeeklyComercialDigest() sin argumentos). Programado con
 * scripts/apex/Schedule_Weekly_Comercial_Digest.apex, mismo patron que
 * SM_TriggerPanelMonitor/scripts/apex/Schedule_Trigger_Panel_Monitor.apex.
 * @author Carlos Alberto Lopez Prada
 */
public class SM_WeeklyComercialDigestScheduler implements Schedulable {
    public void execute(SchedulableContext ctx) {
        SM_ReturnCodeNotifier.sendWeeklyComercialDigest(false);
    }
}
