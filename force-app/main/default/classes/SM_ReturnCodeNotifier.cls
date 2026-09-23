/**
 * @description Emails a report of contracts with an unresolved ACH return code on file, for
 * NACHA codes where retrying the same payment method is known to be futile (unlike NSF, which
 * legitimately resolves itself on a later attempt). Built 2026-09-14 for R02 (ACCOUNT CLOSED -
 * the bank account no longer exists) while auditing contract 00316708 (6 straight months of
 * failed payments, 3 of them R02) - there was no standing way to notice this pattern except
 * investigating one contract at a time. Extended the same day to R10 (customer told the bank
 * directly they don't authorize the debit - see extract_check_collection.py's separate
 * Comercial-facing R10 CSV report for the customer-service side of this same code; extended
 * 2026-09-23 to also cover R11, same dispute family, per explicit user instruction), then to
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

    // calp 2026-09-23 :: R11 (ENTRY NOT PER AUTHORIZATION TERMS) se agrego al mismo reporte que R10
    // por instruccion explicita del usuario -- es la misma familia de disputa/desconocimiento del
    // cargo por parte del cliente, solo que el banco lo codifica distinto. Comparte tambien la regla
    // de "siempre gana sin importar el estado anterior" (ver CLAUDE.md 2.2) -- especifica de
    // R10/R11, no generaliza a los otros codigos definitivos (R02/R04/R07/R13/R16).
    public static void sendR10Report() {
        sendReport(new Set<String>{ 'R10', 'R11' }, 'R10/R11 (CUSTOMER ADVISES NOT AUTHORIZED / ENTRY NOT PER AUTHORIZATION TERMS)', 'el cliente le informo al banco directamente que no autoriza el cobro o que no cumple los terminos autorizados (disputa/desconoce el cargo) - reintentar sin hablar primero con el cliente puede generar otra disputa.');
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
     *
     * calp 2026-09-21 :: tuneado para Comercial (formato en buildTimeoutReversalReport() cambio a
     * texto simple con fecha de transmision, dias del umbral, y fecha del reporte real). Excluye
     * Test/VIP (no le sirven a Comercial) pero deliberadamente NO excluye Cancelled/Finalized --
     * un reverso en un contrato ya cerrado puede seguir generando costo adicional, instruccion
     * explicita del usuario. Por ahora sigue mandando solo a NOTIFY_EMAIL (Carlos) hasta que se
     * defina la lista real de Comercial.
     */
    public static void sendTimeoutReversalReport() {
        List<SM_Payment__c> reversedPayments = [
            SELECT Id, Name, SM_Amount__c, CreatedDate,
                   Payment_Status__c, SM_Check_Collection_Status__c, SM_Check_Collection_Date__c,
                   SM_Return_code__c, SM_Historical_Collection_Status__c,
                   SM_Transmission_Date_ACH_File__c,
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

        // Excluye Test/VIP (null-safe con == true, igual que sendReport()) -- deliberadamente NO
        // excluye Cancelled/Finalized, esos siguen siendo relevantes para Comercial.
        List<SM_Payment__c> filteredPayments = new List<SM_Payment__c>();
        for (SM_Payment__c p : reversedPayments) {
            if (p.SM_Contract__r != null
                && (p.SM_Contract__r.Is_Test_Contract__c == true || p.SM_Contract__r.Is_VIP_Contract__c == true)) {
                continue;
            }
            filteredPayments.add(p);
        }

        String body = buildTimeoutReversalReport(filteredPayments);

        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setToAddresses(new String[]{ NOTIFY_EMAIL });
        mail.setSubject('[ALERTA] Pagos aceptados por timeout y luego revertidos por reporte real - ' + Date.today().format());
        mail.setPlainTextBody(body);
        if (!Test.isRunningTest()) {
            Messaging.sendEmail(new Messaging.SingleEmailMessage[]{ mail });
        }
    }

    private static final Pattern TIMEOUT_DAYS_PATTERN = Pattern.compile('PRC_AUT_(\\d+)D_SIN_REPORTE');
    private static final List<String> MONTH_ABBR_ES = new List<String>{
        'ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'
    };

    /**
     * @description "27 ago 2026" -- dia + mes abreviado en espanol + ano, para el formato de
     * reporte de Comercial (Date.format() de Apex sale como "8/27/2026", numerico, menos legible).
     */
    private static String formatDiaMes(Date d) {
        return String.valueOf(d.day()) + ' ' + MONTH_ABBR_ES[d.month() - 1] + ' ' + String.valueOf(d.year());
    }

    // calp 2026-09-21 :: significado corto de los codigos NACHA que de verdad aparecen en este
    // reporte (Returns) -- Comercial no tiene por que saber de memoria que es un R11. Los 5 codigos
    // que ya tienen su propio reporte (R02/R04/R07/R10/R13/R16) usan la misma idea, mas resumida.
    private static final Map<String, String> RETURN_CODE_MEANINGS = new Map<String, String>{
        'R01' => 'Fondos insuficientes (NSF)',
        'R02' => 'Cuenta cerrada',
        'R03' => 'Cuenta no encontrada / no existe',
        'R04' => 'Numero de cuenta invalido',
        'R07' => 'Autorizacion revocada por el cliente',
        'R08' => 'Pago detenido por el cliente',
        'R09' => 'Fondos no disponibles (uncollected funds)',
        'R10' => 'El cliente le dijo al banco que no autoriza el cobro',
        'R11' => 'El cliente indica que el cargo no cumple los terminos autorizados',
        'R13' => 'Numero de ruta (routing) invalido',
        'R16' => 'Cuenta congelada',
        'R20' => 'Cuenta no transaccional',
        'R29' => 'Cliente corporativo no autoriza el cobro'
    };

    /**
     * @description Separated from sendTimeoutReversalReport() so the report text can be built/
     * tested with in-memory data, same pattern as buildReport().
     *
     * calp 2026-09-21 :: formato tuneado para Comercial, por pedido explicito del usuario -- texto
     * simple en vez del bloque tecnico anterior (que mostraba el tag crudo de
     * SM_Historical_Collection_Status__c). Cada pago: cuando se transmitio, cuantos dias tenia que
     * cumplir para que el timeout lo aceptara (extraido del tag PRC_AUT_<N>D_SIN_REPORTE), y el
     * estado real que un reporte de Returns/Collection reporto despues.
     */
    public static String buildTimeoutReversalReport(List<SM_Payment__c> reversedPayments) {
        if (reversedPayments.isEmpty()) {
            return 'Sin pagos aceptados por timeout que hayan sido revertidos por un reporte real de Returns/Collection.\n';
        }

        String body = 'Pagos que se aceptaron automaticamente por no tener reporte del banco dentro del plazo, '
            + 'y que un reporte real de Returns/Collection llegado DESPUES demostro que en realidad '
            + 'habian sido rechazados -- evidencia de cuanto se esta demorando el banco en reportar.\n\n';

        for (SM_Payment__c p : reversedPayments) {
            String contractLabel = p.SM_Contract__r != null
                ? p.SM_Contract__r.ContractNumber + ' (' + p.SM_Contract__r.Status + ')'
                : '(sin contrato)';
            String transmittedLabel = p.SM_Transmission_Date_ACH_File__c == null
                ? '(sin fecha)' : formatDiaMes(p.SM_Transmission_Date_ACH_File__c);
            Integer daysThreshold = null;
            if (String.isNotBlank(p.SM_Historical_Collection_Status__c)) {
                Matcher m = TIMEOUT_DAYS_PATTERN.matcher(p.SM_Historical_Collection_Status__c);
                if (m.find()) {
                    daysThreshold = Integer.valueOf(m.group(1));
                }
            }
            String daysLabel = daysThreshold == null ? '?' : String.valueOf(daysThreshold);
            // calp 2026-09-21 :: la fecha real en que mark_transmitted_accepted.apex lo marco
            // ACCEPTED no queda guardada en ningun campo -- SM_Check_Collection_Date__c la tenia,
            // pero el reporte real que lo reversa la sobreescribe con SU propia fecha. Se calcula
            // en vez de leerla: transmitido + los dias del umbral (mismo dato que ya se muestra en
            // "cumple N dias a partir de transmitido", solo que como fecha en vez de numero).
            String acceptedDateLabel = (daysThreshold != null && p.SM_Transmission_Date_ACH_File__c != null)
                ? formatDiaMes(p.SM_Transmission_Date_ACH_File__c.addDays(daysThreshold))
                : '(sin fecha)';
            String reportDateLabel = p.SM_Check_Collection_Date__c == null
                ? '(ninguna)' : formatDiaMes(p.SM_Check_Collection_Date__c);
            String returnCodeLabel;
            if (p.SM_Return_code__c == null) {
                returnCodeLabel = '(ninguno)';
            } else if (RETURN_CODE_MEANINGS.containsKey(p.SM_Return_code__c)) {
                returnCodeLabel = p.SM_Return_code__c + ' (' + RETURN_CODE_MEANINGS.get(p.SM_Return_code__c) + ')';
            } else {
                returnCodeLabel = p.SM_Return_code__c;
            }

            body += p.Name + ' - Transmitido el: ' + transmittedLabel + ' - Contrato ' + contractLabel + '\n'
                + 'Pago aceptado por dias el ' + acceptedDateLabel + ', cumple ' + daysLabel + ' dias a partir de transmitido.\n'
                + 'Estado actual: ' + p.Payment_Status__c + ' / ' + p.SM_Check_Collection_Status__c
                + ' (Reportado en Collections del: ' + reportDateLabel + ')'
                + ' -> Return code: ' + returnCodeLabel + '\n\n';
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

    // ===================================================================
    // Compilado semanal para Comercial -- calp 2026-09-22
    // ===================================================================
    // Los 5 reportes de arriba (R02/R10/R04+R13/R07/R16) se disenaron cada uno para su propio
    // correo tecnico. Este metodo los combina en UN solo correo, agrupado por que tiene que HACER
    // Comercial (no por codigo NACHA, que es jerga de banco) -- decision explicita del usuario tras
    // revisar un borrador: R02+R04+R13 comparten la misma accion (el cliente debe actualizar su
    // metodo de pago), R10+R07 comparten otra (hablar con el cliente antes de reintentar), R16
    // queda aparte (fuera del control del cliente). Cada contrato es UNA linea (cantidad de pagos +
    // rango de fechas + $ total), no una linea por pago -- con meses de backlog real (ej. 00316708:
    // 16 pagos R02 desde el 21-may-2026) listar cada pago hacia el correo ilegible. Dentro de cada
    // categoria, separa "nuevo esta semana" (al menos un rechazo con CreatedDate en los ultimos 7
    // dias) del resto del backlog acumulado -- decision explicita del usuario: el primer envio
    // muestra TODO el backlog para que Comercial vea el tamano real del problema de una vez; los
    // envios siguientes deberian mostrar solo lo nuevo + un recordatorio corto del backlog (agregar
    // esa distincion cuando se programe el envio recurrente -- ver TAREAS_PENDIENTES.md).

    private static String pad(String ch, Integer n) {
        String s = '';
        for (Integer i = 0; i < n; i++) {
            s += ch;
        }
        return s;
    }

    private class ContractSummary {
        String contractNumber;
        String status;
        Decimal total = 0;
        Integer cantidad = 0;
        Date primero;
        Date ultimo;
        Boolean resuelto = false;
        Boolean nuevoEstaSemana = false;
    }

    private class ComercialGroup {
        String titulo;
        String accion;
        Set<String> codigos;
        List<SM_Payment__c> payments = new List<SM_Payment__c>();
    }

    public static void sendWeeklyComercialDigest() {
        Set<String> allCodes = new Set<String>{ 'R02', 'R04', 'R13', 'R10', 'R07', 'R16' };
        List<SM_Payment__c> codePayments = [
            SELECT Id, Name, SM_Amount__c, CreatedDate, SM_Return_code__c,
                   SM_Contract__c, SM_Contract__r.ContractNumber, SM_Contract__r.Status,
                   SM_Contract__r.SM_Customer_Cancellation__c,
                   SM_Contract__r.Is_Test_Contract__c, SM_Contract__r.Is_VIP_Contract__c
            FROM SM_Payment__c
            WHERE SM_Return_code__c IN :allCodes
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

        String body = buildWeeklyComercialDigest(codePayments, acceptedSince, Date.today().addDays(-7));

        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setToAddresses(new String[]{ NOTIFY_EMAIL });
        mail.setSubject('[Comercial] Novedades ACH - Semana del ' + Date.today().addDays(-7).format() + ' - ' + Date.today().format());
        mail.setPlainTextBody(body);
        if (!Test.isRunningTest()) {
            Messaging.sendEmail(new Messaging.SingleEmailMessage[]{ mail });
        }
    }

    /**
     * @description Separada de sendWeeklyComercialDigest() para poder probarla con datos en
     * memoria, mismo patron que buildReport()/buildTimeoutReversalReport(). codePayments YA debe
     * venir sin filtrar (Test/VIP/cerrados se excluyen aqui adentro, igual que buildReport()).
     */
    public static String buildWeeklyComercialDigest(List<SM_Payment__c> codePayments, List<SM_Payment__c> acceptedPayments, Date sinceWeek) {
        Map<String, ComercialGroup> grupos = new Map<String, ComercialGroup>();

        ComercialGroup g1 = new ComercialGroup();
        g1.titulo = 'ACTUALIZAR METODO DE PAGO';
        g1.accion = 'el dato bancario del cliente esta mal o ya no existe -- hay que contactarlo para actualizarlo, reintentar con el mismo dato no va a funcionar.';
        g1.codigos = new Set<String>{ 'R02', 'R04', 'R13' };
        grupos.put('metodo', g1);

        ComercialGroup g2 = new ComercialGroup();
        g2.titulo = 'DISPUTA O REVOCACION DEL CLIENTE';
        g2.accion = 'el cliente le dijo al banco que no autoriza o revoco el cobro -- hablar con el cliente antes de reintentar, para no generar otra disputa.';
        g2.codigos = new Set<String>{ 'R10', 'R07' };
        grupos.put('disputa', g2);

        ComercialGroup g3 = new ComercialGroup();
        g3.titulo = 'CUENTA CONGELADA';
        g3.accion = 'usualmente por una orden legal/judicial, fuera del control del cliente -- dar seguimiento aparte antes de reintentar.';
        g3.codigos = new Set<String>{ 'R16' };
        grupos.put('congelada', g3);

        for (SM_Payment__c p : codePayments) {
            if (p.SM_Contract__c == null || p.SM_Contract__r == null) {
                continue;
            }
            if (CLOSED_CONTRACT_STATUSES.contains(p.SM_Contract__r.Status) || p.SM_Contract__r.SM_Customer_Cancellation__c == true
                || p.SM_Contract__r.Is_Test_Contract__c == true || p.SM_Contract__r.Is_VIP_Contract__c == true) {
                continue;
            }
            for (ComercialGroup g : grupos.values()) {
                if (g.codigos.contains(p.SM_Return_code__c)) {
                    g.payments.add(p);
                }
            }
        }

        Map<Id, List<Date>> acceptedDatesByContract = new Map<Id, List<Date>>();
        for (SM_Payment__c p : acceptedPayments) {
            if (!acceptedDatesByContract.containsKey(p.SM_Contract__c)) {
                acceptedDatesByContract.put(p.SM_Contract__c, new List<Date>());
            }
            acceptedDatesByContract.get(p.SM_Contract__c).add(p.CreatedDate.date());
        }

        String resumenLine = '';
        String bodyDetalle = '';
        Decimal granTotal = 0;
        Integer granContratos = 0;

        for (String key : new List<String>{ 'metodo', 'disputa', 'congelada' }) {
            ComercialGroup g = grupos.get(key);
            Map<Id, ContractSummary> porContrato = new Map<Id, ContractSummary>();
            for (SM_Payment__c p : g.payments) {
                Date pd = p.CreatedDate.date();
                if (!porContrato.containsKey(p.SM_Contract__c)) {
                    ContractSummary cr = new ContractSummary();
                    cr.contractNumber = p.SM_Contract__r.ContractNumber;
                    cr.status = p.SM_Contract__r.Status;
                    cr.primero = pd;
                    cr.ultimo = pd;
                    porContrato.put(p.SM_Contract__c, cr);
                }
                ContractSummary cr = porContrato.get(p.SM_Contract__c);
                cr.cantidad++;
                cr.total += (p.SM_Amount__c != null ? p.SM_Amount__c : 0);
                if (pd < cr.primero) {
                    cr.primero = pd;
                }
                if (pd > cr.ultimo) {
                    cr.ultimo = pd;
                }
                if (pd >= sinceWeek) {
                    cr.nuevoEstaSemana = true;
                }
            }
            for (Id cId : porContrato.keySet()) {
                ContractSummary cr = porContrato.get(cId);
                for (Date d : acceptedDatesByContract.containsKey(cId) ? acceptedDatesByContract.get(cId) : new List<Date>()) {
                    if (d > cr.ultimo) {
                        cr.resuelto = true;
                    }
                }
            }

            List<ContractSummary> nuevosSemana = new List<ContractSummary>();
            List<ContractSummary> backlog = new List<ContractSummary>();
            List<ContractSummary> resueltos = new List<ContractSummary>();
            Decimal groupTotal = 0;
            for (ContractSummary cr : porContrato.values()) {
                if (cr.resuelto) {
                    resueltos.add(cr);
                } else if (cr.nuevoEstaSemana) {
                    nuevosSemana.add(cr);
                    groupTotal += cr.total;
                } else {
                    backlog.add(cr);
                    groupTotal += cr.total;
                }
            }

            resumenLine += '  ' + g.titulo + pad(' ', Math.max(1, 35 - g.titulo.length()))
                + (nuevosSemana.size() + backlog.size()) + ' contrato(s)   $' + groupTotal.format()
                + '   (' + nuevosSemana.size() + ' nuevo(s) esta semana)\n';
            granTotal += groupTotal;
            granContratos += nuevosSemana.size() + backlog.size();

            bodyDetalle += '========================================================================\n';
            bodyDetalle += g.titulo + '\n';
            bodyDetalle += g.accion + '\n\n';

            if (nuevosSemana.isEmpty() && backlog.isEmpty()) {
                bodyDetalle += '  Sin contratos pendientes en esta categoria.\n\n';
            } else {
                sortByTotalDesc(nuevosSemana);
                sortByTotalDesc(backlog);

                if (!nuevosSemana.isEmpty()) {
                    bodyDetalle += '  NUEVO ESTA SEMANA (' + nuevosSemana.size() + '):\n';
                    for (ContractSummary cr : nuevosSemana) {
                        bodyDetalle += '  - Contrato ' + cr.contractNumber + ' (' + cr.status + ') - '
                            + cr.cantidad + ' pago(s) rechazado(s), $' + cr.total.format()
                            + ' - ' + cr.primero.format() + ' a ' + cr.ultimo.format() + '\n';
                    }
                    bodyDetalle += '\n';
                }
                if (!backlog.isEmpty()) {
                    bodyDetalle += '  BACKLOG ACUMULADO (' + backlog.size() + ', sin novedad esta semana):\n';
                    for (ContractSummary cr : backlog) {
                        bodyDetalle += '  - Contrato ' + cr.contractNumber + ' (' + cr.status + ') - '
                            + cr.cantidad + ' pago(s) rechazado(s), $' + cr.total.format()
                            + ' - ' + cr.primero.format() + ' a ' + cr.ultimo.format() + '\n';
                    }
                    bodyDetalle += '\n';
                }
            }

            if (!resueltos.isEmpty()) {
                bodyDetalle += '  Ya resueltos (' + resueltos.size() + ', pago aceptado despues del ultimo rechazo -- no requieren accion): ';
                List<String> nums = new List<String>();
                for (ContractSummary cr : resueltos) {
                    nums.add(cr.contractNumber);
                }
                bodyDetalle += String.join(nums, ', ') + '\n\n';
            }
        }

        String header = 'NOVEDADES ACH PARA COMERCIAL - Semana del ' + sinceWeek.format() + ' al ' + Date.today().format() + '\n'
            + '========================================================================\n\n'
            + 'RESUMEN\n' + resumenLine
            + '  ' + pad('-', 50) + '\n'
            + '  TOTAL' + pad(' ', 31) + granContratos + ' contrato(s)   $' + granTotal.format() + '\n\n';

        return header + bodyDetalle;
    }

    private static void sortByTotalDesc(List<ContractSummary> items) {
        for (Integer i = 0; i < items.size(); i++) {
            for (Integer j = i + 1; j < items.size(); j++) {
                if (items[j].total > items[i].total) {
                    ContractSummary tmp = items[i];
                    items[i] = items[j];
                    items[j] = tmp;
                }
            }
        }
    }
}
