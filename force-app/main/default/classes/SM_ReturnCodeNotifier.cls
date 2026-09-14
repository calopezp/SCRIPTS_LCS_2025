/**
 * @description Emails a report of contracts with an unresolved ACH return code on file, for
 * NACHA codes where retrying the same payment method is known to be futile (unlike NSF, which
 * legitimately resolves itself on a later attempt). Built 2026-09-14 for R02 (ACCOUNT CLOSED -
 * the bank account no longer exists) while auditing contract 00316708 (6 straight months of
 * failed payments, 3 of them R02) - there was no standing way to notice this pattern except
 * investigating one contract at a time. Extended the same day to R10 (customer told the bank
 * directly they don't authorize the debit - see extract_check_collection.py's separate
 * Comercial-facing R10 CSV report for the customer-service side of this same code). Invoked
 * manually via notify_r02.apex / notify_r10.apex, wired into
 * COLLECTIONS/run_daily_new_files.sh's apply mode so Carlos gets the current lists every time
 * he runs the daily collections pipeline.
 * @author Carlos Alberto Lopez Prada
 */
public without sharing class SM_ReturnCodeNotifier {

    public static final String NOTIFY_EMAIL = 'clopez@legal-credit.com';
    private static final Set<String> CLOSED_CONTRACT_STATUSES = new Set<String>{ 'Cancelled', 'Canceled', 'Finalized' };

    public static void sendR02Report() {
        sendReport('R02', 'ACCOUNT CLOSED', 'la cuenta bancaria del metodo de pago ya no existe, reintentar no va a funcionar, hace falta que el cliente actualice su metodo de pago.');
    }

    public static void sendR10Report() {
        sendReport('R10', 'CUSTOMER ADVISES NOT AUTHORIZED', 'el cliente le informo al banco directamente que no autoriza el cobro (disputa/desconoce el cargo) - reintentar sin hablar primero con el cliente puede generar otra disputa.');
    }

    private static void sendReport(String returnCode, String codeLabel, String explanation) {
        List<SM_Payment__c> codePayments = [
            SELECT Id, Name, SM_Amount__c, CreatedDate,
                   SM_Contract__c, SM_Contract__r.ContractNumber, SM_Contract__r.Status,
                   SM_Contract__r.SM_Customer_Cancellation__c
            FROM SM_Payment__c
            WHERE SM_Return_code__c = :returnCode
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

        String body = buildReport(codePayments, acceptedSince, returnCode, codeLabel, explanation);

        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setToAddresses(new String[]{ NOTIFY_EMAIL });
        mail.setSubject('Contratos con ACH Return ' + returnCode + ' (' + codeLabel + ') - ' + Date.today().format());
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
    public static String buildReport(List<SM_Payment__c> codePayments, List<SM_Payment__c> acceptedPayments, String returnCode, String codeLabel, String explanation) {
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
            if (CLOSED_CONTRACT_STATUSES.contains(p.SM_Contract__r.Status) || p.SM_Contract__r.SM_Customer_Cancellation__c == true) {
                continue;
            }
            contractsById.put(p.SM_Contract__c, p.SM_Contract__r);
            if (!paymentsByContract.containsKey(p.SM_Contract__c)) {
                paymentsByContract.put(p.SM_Contract__c, new List<SM_Payment__c>());
            }
            paymentsByContract.get(p.SM_Contract__c).add(p);
        }

        if (paymentsByContract.isEmpty()) {
            return 'Sin contratos con ACH Return ' + returnCode + ' (' + codeLabel + ') sin resolver.\n';
        }

        List<Id> contractIds = new List<Id>(paymentsByContract.keySet());
        contractIds.sort();

        String body = 'Contratos con al menos un ACH Return ' + returnCode + ' (' + codeLabel + ') en un Payment - ' + explanation + '\n\n';

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
                + (recoveredSince ? ' - OJO: tiene un pago ACCEPTED despues del ultimo ' + returnCode + ', revisar si ya se resolvio' : '') + '\n';
            for (SM_Payment__c p : codePays) {
                body += '    ' + p.Name + ' - $' + (p.SM_Amount__c != null ? p.SM_Amount__c.format() : '?') + ' - ' + p.CreatedDate.date().format() + '\n';
            }
        }

        return body;
    }
}
