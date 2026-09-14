public class SM_AgreementSignedDateMonitor implements Schedulable {

    public static final String NOTIFY_EMAIL = 'clopez@legal-credit.com';

    public void execute(SchedulableContext ctx) {
        runDailyCheck();
    }

    // calp 2026-09-15 :: Status='Signed' viene de la sincronizacion de Adobe Sign; si el
    // callback de Adobe no entrega DateSigned (o llega en un orden distinto al esperado), el
    // registro puede quedar marcado Signed sin fecha de firma. Solo reporta - no corrige el
    // Status automaticamente (ver BITACORA_HALLAZGOS_TECNICOS.md 2026-09-14: forzar el Status
    // de un Agreement manualmente arriesga re-disparar un envio a un cliente que ya firmo).
    public static void runDailyCheck() {
        List<echosign_dev1__SIGN_Agreement__c> orphans = [
            SELECT Id, Name, echosign_dev1__Contract__r.ContractNumber, Owner.Alias,
                   CreatedDate, echosign_dev1__DateSent__c
            FROM echosign_dev1__SIGN_Agreement__c
            WHERE echosign_dev1__Status__c = 'Signed'
              AND echosign_dev1__DateSigned__c = null
            ORDER BY CreatedDate DESC
        ];

        sendEmail(orphans);
    }

    public static String buildBody(List<echosign_dev1__SIGN_Agreement__c> orphans) {
        if (orphans.isEmpty()) {
            return 'Sin anomalias detectadas. Todos los Agreements en Status = Signed tienen Date Signed poblado.\n';
        }

        String body = 'ANOMALIAS DETECTADAS (' + orphans.size() + '):\n'
            + 'Agreements con Status = Signed pero sin Date Signed (echosign_dev1__DateSigned__c) - '
            + 'no se modifico ningun registro, solo diagnostico.\n\n';

        for (echosign_dev1__SIGN_Agreement__c a : orphans) {
            String contractNum = a.echosign_dev1__Contract__r != null ? a.echosign_dev1__Contract__r.ContractNumber : '(sin contrato)';
            String ownerAlias = a.Owner != null ? a.Owner.Alias : '?';
            body += '- ' + a.Name + ' | Contrato ' + contractNum + ' | Owner ' + ownerAlias
                + ' | Creado ' + a.CreatedDate.format() + ' | Enviado '
                + (a.echosign_dev1__DateSent__c != null ? a.echosign_dev1__DateSent__c.format() : 'nunca')
                + ' | ' + a.Id + '\n';
        }
        return body;
    }

    private static void sendEmail(List<echosign_dev1__SIGN_Agreement__c> orphans) {
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setToAddresses(new String[]{ NOTIFY_EMAIL });
        mail.setSubject((orphans.isEmpty() ? '[OK] ' : '[REVISAR] ') + 'Monitoreo Agreements Signed sin fecha - ' + Date.today().format());
        mail.setPlainTextBody(buildBody(orphans));
        if (!Test.isRunningTest()) {
            Messaging.sendEmail(new Messaging.SingleEmailMessage[]{ mail });
        }
    }
}
