/**
 * @description Emails a report of contracts with an unresolved ACH return code on file, for
 * NACHA codes where retrying the same payment method is known to be futile (unlike NSF, which
 * legitimately resolves itself on a later attempt). Built 2026-09-14 for R02 (ACCOUNT CLOSED -
 * the bank account no longer exists) while auditing contract 00316708 (6 straight months of
 * failed payments, 3 of them R02) - there was no standing way to notice this pattern except
 * investigating one contract at a time. Extended the same day to R10 (customer told the bank
 * directly they don't authorize the debit - see extract_check_collection.py's separate
 * Comercial-facing R10 CSV report for the customer-service side of this same code), then to
 * R04+R13 (invalid account/routing number - same underlying "bad bank details" problem, one
 * combined report), R07 (customer revoked authorization - a standing revocation, not a
 * one-time dispute like R10/R29), and R16 (account frozen, usually a legal/court order,
 * outside the client's control). R08 (payment stopped) and R01/R09 (NSF/uncollected funds,
 * which legitimately resolve on retry) were deliberately left out - see
 * BITACORA_HALLAZGOS_TECNICOS.md for the full code-by-code breakdown and why. Invoked manually
 * via notify_r02.apex / notify_r10.apex / notify_invalid_account.apex / notify_r07.apex /
 * notify_r16.apex, wired into COLLECTIONS/run_daily_new_files.sh's apply mode so Carlos gets
 * the current lists every time he runs the daily collections pipeline.
 *
 * sendTimeoutReversalReport() (added 2026-09-18) is a different kind of alert: it's not about a
 * NACHA return code, it's about the "accepted by timeout" mechanism itself
 * (mark_transmitted_accepted.apex, tag "PRC_AUT_<N>D_SIN_REPORTE:") turning out to be wrong for a
 * given payment. That mechanism auto-marks a payment ACCEPTED/COLLECTED after N days with no bank
 * report at all - and update_check_collection.apex / update_ach_returns.apex deliberately let a
 * REAL Returns/Collection report overturn that default acceptance later (the regression guard's
 * documented exception, since a timeout default isn't a bank-confirmed collection). That's correct
 * behavior, but it happens silently - nothing surfaced when a "already collected" payment actually
 * turns out to be a Return/Not Collected days or weeks later. Found 2026-09-18 auditing
 * PY-01888808/PY-01888831/PY-01888987 (all tagged D_SIN_REPORTE, all later reported by the bank as
 * something other than collected). Detects this from data already on the record - a payment whose
 * history trail ever carried a D_SIN_REPORTE tag but whose CURRENT status is no longer a success -
 * so no change to update_check_collection.apex/update_ach_returns.apex was needed. Invoked via
 * notify_timeout_reversal.apex, wired into run_daily_new_files.sh the same way as the others.
 * @author Carlos Alberto Lopez Prada
 */
public without sharing class SM_ReturnCodeNotifier {

    public static final String NOTIFY_EMAIL = 'clopez@legal-credit.com';
    private static final Set<String> CLOSED_CONTRACT_STATUSES = new Set<String>{ 'Cancelled', 'Canceled', 'Finalized' };

    public static void sendR02Report() {
        sendReport(new Set<String>{ 'R02' }, 'R02 (ACCOUNT CLOSED)', 'la cuenta bancaria del metodo de pago ya no existe, reintentar no va a funcionar, hace falta que el cliente actualice su metodo de pago.');
    }

    public static void sendR10Report() {
        sendReport(new Set<String>{ 'R10' }, 'R10 (CUSTOMER ADVISES NOT AUTHORIZED)', 'el cliente le informo al banco directamente que no autoriza el cobro (disputa/desconoce el cargo) - reintentar sin hablar primero con el cliente puede generar otra disputa.');
    }

    public static void sendInvalidAccountReport() {
        sendReport(new Set<String>{ 'R04', 'R13' }, 'R04/R13 (NUMERO DE CUENTA O ROUTING INVALIDO)', 'el numero de cuenta o de routing del metodo de pago esta mal capturado - reintentar con el mismo dato nunca va a funcionar, hace falta corregirlo con el cliente.');
    }

    public static void sendR07Report() {
        sendReport(new Set<String>{ 'R07' }, 'R07 (AUTORIZACION REVOCADA)', 'el cliente revoco formalmente la autorizacion de cobro (no es un cargo puntual disputado como R10 - es una revocacion permanente) - hace falta una autorizacion nueva antes de volver a cobrar.');
    }

    public static void sendR16Report() {
        sendReport(new Set<String>{ 'R16' }, 'R16 (CUENTA CONGELADA)', 'la cuenta esta congelada (usualmente por una orden legal/judicial) - fuera del control del cliente, dar seguimiento aparte antes de reintentar.');
    }

    /**
     * @description Payments that mark_transmitted_accepted.apex once auto-accepted by timeout
     * (no bank report within N days) but whose CURRENT status shows a real Returns/Collection
     * report later contradicted that default (Payment_Status__c = REJECTED, or
     * SM_Check_Collection_Status__c = RETURN/NOT COLLECTED). Detected from
     * SM_Historical_Collection_Status__c still carrying a "D_SIN_REPORTE:" tag - see the class doc.
     */
    public static void sendTimeoutReversalReport() {
        List<SM_Payment__c> reversedPayments = [
            SELECT Id, Name, SM_Amount__c, CreatedDate,
                   Payment_Status__c, SM_Check_Collection_Status__c, SM_Check_Collection_Date__c,
                   SM_Return_code__c, SM_Historical_Collection_Status__c,
                   SM_Contract__c, SM_Contract__r.ContractNumber, SM_Contract__r.Status,
                   SM_Contract__r.Is_Test_Contract__c, SM_Contract__r.Is_VIP_Contract__c
            FROM SM_Payment__c
            // Note: NOT escaped with \_ -- inline SOQL in Apex does not unescape "\_" the way
            // Database.query()/the API does, so the literal backslash reaches the server and
            // never matches (verified 2026-09-18: escaped version returns 0 rows against live
            // data that should match). The unescaped "_" wildcard is safe here -- it just also
            // matches non-underscore filler chars, which never occurs in this tag's fixed text.
            WHERE SM_Historical_Collection_Status__c LIKE '%D_SIN_REPORTE:%'
            AND (
                Payment_Status__c = 'REJECTED'
                OR SM_Check_Collection_Status__c IN ('RETURN', 'NOT_COLLECTED', 'NOT COLLECTED', 'PENDING')
            )
            ORDER BY SM_Contract__r.ContractNumber, SM_Check_Collection_Date__c
        ];

        String body = buildTimeoutReversalReport(reversedPayments);

        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setToAddresses(new String[]{ NOTIFY_EMAIL });
        mail.setSubject('[ALERTA] Pagos aceptados por timeout y luego revertidos por reporte real - ' + Date.today().format());
        mail.setPlainTextBody(body);
        if (!Test.isRunningTest()) {
            Messaging.sendEmail(new Messaging.SingleEmailMessage[]{ mail });
        }
    }

    /**
     * @description Separated from sendTimeoutReversalReport() so the report text can be built/
     * tested with in-memory data, same pattern as buildReport(). Unlike buildReport(), Test/VIP
     * and closed contracts are NOT excluded here - a timeout-vs-reality mismatch on any contract,
     * even a closed one, is still evidence the 15/20-day default is over-eager and worth seeing.
     */
    public static String buildTimeoutReversalReport(List<SM_Payment__c> reversedPayments) {
        if (reversedPayments.isEmpty()) {
            return 'Sin pagos aceptados por timeout que hayan sido revertidos por un reporte real de Returns/Collection.\n';
        }

        String body = 'Pagos que mark_transmitted_accepted.apex marco ACCEPTED/COLLECTED por timeout '
            + '(sin reporte del banco en 15/20 dias) y que un reporte real de Returns/Collection '
            + 'llegado DESPUES contradijo -- revisar si el timeout esta siendo demasiado agresivo.\n\n';

        for (SM_Payment__c p : reversedPayments) {
            String contractLabel = p.SM_Contract__r != null
                ? p.SM_Contract__r.ContractNumber + ' (' + p.SM_Contract__r.Status + ')'
                : '(sin contrato)';
            body += '- ' + p.Name + ' - Contrato ' + contractLabel + '\n'
                + '    Estado actual -> Payment_Status: ' + p.Payment_Status__c
                + ' | Check_Collection_Status: ' + p.SM_Check_Collection_Status__c
                + ' | Return_code: ' + (p.SM_Return_code__c == null ? '(ninguno)' : p.SM_Return_code__c)
                + ' | Fecha reporte: ' + (p.SM_Check_Collection_Date__c == null ? '(ninguna)' : p.SM_Check_Collection_Date__c.format()) + '\n'
                + '    Historial -> ' + p.SM_Historical_Collection_Status__c + '\n';
        }

        return body;
    }

    private static void sendReport(Set<String> returnCodes, String codeLabel, String explanation) {
        List<SM_Payment__c> codePayments = [
            SELECT Id, Name, SM_Amount__c, CreatedDate,
                   SM_Contract__c, SM_Contract__r.ContractNumber, SM_Contract__r.Status,
                   SM_Contract__r.SM_Customer_Cancellation__c,
                   SM_Contract__r.Is_Test_Contract__c, SM_Contract__r.Is_VIP_Contract__c
            FROM SM_Payment__c
            WHERE SM_Return_code__c IN :returnCodes
            ORDER BY SM_Contract__r.ContractNumber, CreatedDate
        ];

        Set<Id> contractIds = new Set<Id>();
        for (SM_Payment__c p : codePayments) {
            if (p.SM_Contract__c != null) {
                contractIds.add(p.SM_Contract__c);
            }
        }

        List<SM_Payment__c> acceptedSince = contractIds.isEmpty() ? new List<SM_Payment__c>() : [
            SELECT SM_Contract__c, CreatedDate
            FROM SM_Payment__c
            WHERE SM_Contract__c IN :contractIds
            AND Payment_Status__c = 'ACCEPTED'
        ];

        String body = buildReport(codePayments, acceptedSince, codeLabel, explanation);

        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setToAddresses(new String[]{ NOTIFY_EMAIL });
        mail.setSubject('Contratos con ACH Return ' + codeLabel + ' - ' + Date.today().format());
        mail.setPlainTextBody(body);
        if (!Test.isRunningTest()) {
            Messaging.sendEmail(new Messaging.SingleEmailMessage[]{ mail });
        }
    }

    /**
     * @description Separated from sendReport() so the report text can be built/tested with
     * in-memory data, same pattern as SM_ACH_Flow_Monitor.buildActivatedContractsSection().
     * acceptedPayments only needs SM_Contract__c and CreatedDate populated.
     */
    public static String buildReport(List<SM_Payment__c> codePayments, List<SM_Payment__c> acceptedPayments, String codeLabel, String explanation) {
        Map<Id, List<Date>> acceptedDatesByContract = new Map<Id, List<Date>>();
        for (SM_Payment__c p : acceptedPayments) {
            if (!acceptedDatesByContract.containsKey(p.SM_Contract__c)) {
                acceptedDatesByContract.put(p.SM_Contract__c, new List<Date>());
            }
            acceptedDatesByContract.get(p.SM_Contract__c).add(p.CreatedDate.date());
        }

        Map<Id, List<SM_Payment__c>> paymentsByContract = new Map<Id, List<SM_Payment__c>>();
        Map<Id, Contract> contractsById = new Map<Id, Contract>();

        for (SM_Payment__c p : codePayments) {
            if (p.SM_Contract__c == null || p.SM_Contract__r == null) {
                continue;
            }
            if (CLOSED_CONTRACT_STATUSES.contains(p.SM_Contract__r.Status) || p.SM_Contract__r.SM_Customer_Cancellation__c == true
                || p.SM_Contract__r.Is_Test_Contract__c == true || p.SM_Contract__r.Is_VIP_Contract__c == true) {
                continue;
            }
            contractsById.put(p.SM_Contract__c, p.SM_Contract__r);
            if (!paymentsByContract.containsKey(p.SM_Contract__c)) {
                paymentsByContract.put(p.SM_Contract__c, new List<SM_Payment__c>());
            }
            paymentsByContract.get(p.SM_Contract__c).add(p);
        }

        if (paymentsByContract.isEmpty()) {
            return 'Sin contratos con ACH Return ' + codeLabel + ' sin resolver.\n';
        }

        List<Id> contractIds = new List<Id>(paymentsByContract.keySet());
        contractIds.sort();

        String body = 'Contratos con al menos un ACH Return ' + codeLabel + ' en un Payment - ' + explanation + '\n\n';

        for (Id contractId : contractIds) {
            Contract c = contractsById.get(contractId);
            List<SM_Payment__c> codePays = paymentsByContract.get(contractId);

            Date latestCodeDate = codePays[0].CreatedDate.date();
            for (SM_Payment__c p : codePays) {
                if (p.CreatedDate.date() > latestCodeDate) {
                    latestCodeDate = p.CreatedDate.date();
                }
            }

            Boolean recoveredSince = false;
            for (Date d : acceptedDatesByContract.containsKey(contractId) ? acceptedDatesByContract.get(contractId) : new List<Date>()) {
                if (d > latestCodeDate) {
                    recoveredSince = true;
                }
            }

            body += '- Contrato ' + c.ContractNumber + ' (' + c.Status + ')'
                + (recoveredSince ? ' - OJO: tiene un pago ACCEPTED despues del ultimo return, revisar si ya se resolvio' : '') + '\n';
            for (SM_Payment__c p : codePays) {
                body += '    ' + p.Name + ' - $' + (p.SM_Amount__c != null ? p.SM_Amount__c.format() : '?') + ' - ' + p.CreatedDate.date().format() + '\n';
            }
        }

        return body;
    }
}
