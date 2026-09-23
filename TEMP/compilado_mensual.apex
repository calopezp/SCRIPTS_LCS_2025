// SOLO LECTURA hasta el envio final -- compila los 6 reportes existentes en un solo correo.
String body = 'COMPILADO MENSUAL - Codigos de Retorno ACH y Reversos por Timeout\n'
    + 'Estado al corte del ' + Date.today().format() + '\n'
    + '========================================================================\n\n';

// --- R02 ---
List<SM_Payment__c> r02Payments = [
    SELECT Id, Name, SM_Amount__c, CreatedDate,
           SM_Contract__c, SM_Contract__r.ContractNumber, SM_Contract__r.Status,
           SM_Contract__r.SM_Customer_Cancellation__c,
           SM_Contract__r.Is_Test_Contract__c, SM_Contract__r.Is_VIP_Contract__c
    FROM SM_Payment__c WHERE SM_Return_code__c IN ('R02')
    ORDER BY SM_Contract__r.ContractNumber, CreatedDate
];
Set<Id> r02ContractIds = new Set<Id>();
for (SM_Payment__c p : r02Payments) { if (p.SM_Contract__c != null) r02ContractIds.add(p.SM_Contract__c); }
List<SM_Payment__c> r02Accepted = r02ContractIds.isEmpty() ? new List<SM_Payment__c>() : [
    SELECT SM_Contract__c, CreatedDate FROM SM_Payment__c WHERE SM_Contract__c IN :r02ContractIds AND Payment_Status__c = 'ACCEPTED'
];
body += '### 1) R02 - CUENTA CERRADA\n';
body += SM_ReturnCodeNotifier.buildReport(r02Payments, r02Accepted, 'R02 (ACCOUNT CLOSED)', 'la cuenta bancaria del metodo de pago ya no existe, reintentar no va a funcionar, hace falta que el cliente actualice su metodo de pago.');
body += '\n';

// --- R10 ---
List<SM_Payment__c> r10Payments = [
    SELECT Id, Name, SM_Amount__c, CreatedDate,
           SM_Contract__c, SM_Contract__r.ContractNumber, SM_Contract__r.Status,
           SM_Contract__r.SM_Customer_Cancellation__c,
           SM_Contract__r.Is_Test_Contract__c, SM_Contract__r.Is_VIP_Contract__c
    FROM SM_Payment__c WHERE SM_Return_code__c IN ('R10')
    ORDER BY SM_Contract__r.ContractNumber, CreatedDate
];
Set<Id> r10ContractIds = new Set<Id>();
for (SM_Payment__c p : r10Payments) { if (p.SM_Contract__c != null) r10ContractIds.add(p.SM_Contract__c); }
List<SM_Payment__c> r10Accepted = r10ContractIds.isEmpty() ? new List<SM_Payment__c>() : [
    SELECT SM_Contract__c, CreatedDate FROM SM_Payment__c WHERE SM_Contract__c IN :r10ContractIds AND Payment_Status__c = 'ACCEPTED'
];
body += '### 2) R10 - CLIENTE NO AUTORIZA\n';
body += SM_ReturnCodeNotifier.buildReport(r10Payments, r10Accepted, 'R10 (CUSTOMER ADVISES NOT AUTHORIZED)', 'el cliente le informo al banco directamente que no autoriza el cobro (disputa/desconoce el cargo) - reintentar sin hablar primero con el cliente puede generar otra disputa.');
body += '\n';

// --- R04/R13 ---
List<SM_Payment__c> r0413Payments = [
    SELECT Id, Name, SM_Amount__c, CreatedDate,
           SM_Contract__c, SM_Contract__r.ContractNumber, SM_Contract__r.Status,
           SM_Contract__r.SM_Customer_Cancellation__c,
           SM_Contract__r.Is_Test_Contract__c, SM_Contract__r.Is_VIP_Contract__c
    FROM SM_Payment__c WHERE SM_Return_code__c IN ('R04','R13')
    ORDER BY SM_Contract__r.ContractNumber, CreatedDate
];
Set<Id> r0413ContractIds = new Set<Id>();
for (SM_Payment__c p : r0413Payments) { if (p.SM_Contract__c != null) r0413ContractIds.add(p.SM_Contract__c); }
List<SM_Payment__c> r0413Accepted = r0413ContractIds.isEmpty() ? new List<SM_Payment__c>() : [
    SELECT SM_Contract__c, CreatedDate FROM SM_Payment__c WHERE SM_Contract__c IN :r0413ContractIds AND Payment_Status__c = 'ACCEPTED'
];
body += '### 3) R04/R13 - CUENTA O ROUTING INVALIDO\n';
body += SM_ReturnCodeNotifier.buildReport(r0413Payments, r0413Accepted, 'R04/R13 (NUMERO DE CUENTA O ROUTING INVALIDO)', 'el numero de cuenta o de routing del metodo de pago esta mal capturado - reintentar con el mismo dato nunca va a funcionar, hace falta corregirlo con el cliente.');
body += '\n';

// --- R07 ---
List<SM_Payment__c> r07Payments = [
    SELECT Id, Name, SM_Amount__c, CreatedDate,
           SM_Contract__c, SM_Contract__r.ContractNumber, SM_Contract__r.Status,
           SM_Contract__r.SM_Customer_Cancellation__c,
           SM_Contract__r.Is_Test_Contract__c, SM_Contract__r.Is_VIP_Contract__c
    FROM SM_Payment__c WHERE SM_Return_code__c IN ('R07')
    ORDER BY SM_Contract__r.ContractNumber, CreatedDate
];
Set<Id> r07ContractIds = new Set<Id>();
for (SM_Payment__c p : r07Payments) { if (p.SM_Contract__c != null) r07ContractIds.add(p.SM_Contract__c); }
List<SM_Payment__c> r07Accepted = r07ContractIds.isEmpty() ? new List<SM_Payment__c>() : [
    SELECT SM_Contract__c, CreatedDate FROM SM_Payment__c WHERE SM_Contract__c IN :r07ContractIds AND Payment_Status__c = 'ACCEPTED'
];
body += '### 4) R07 - AUTORIZACION REVOCADA\n';
body += SM_ReturnCodeNotifier.buildReport(r07Payments, r07Accepted, 'R07 (AUTORIZACION REVOCADA)', 'el cliente revoco formalmente la autorizacion de cobro (no es un cargo puntual disputado como R10 - es una revocacion permanente) - hace falta una autorizacion nueva antes de volver a cobrar.');
body += '\n';

// --- R16 ---
List<SM_Payment__c> r16Payments = [
    SELECT Id, Name, SM_Amount__c, CreatedDate,
           SM_Contract__c, SM_Contract__r.ContractNumber, SM_Contract__r.Status,
           SM_Contract__r.SM_Customer_Cancellation__c,
           SM_Contract__r.Is_Test_Contract__c, SM_Contract__r.Is_VIP_Contract__c
    FROM SM_Payment__c WHERE SM_Return_code__c IN ('R16')
    ORDER BY SM_Contract__r.ContractNumber, CreatedDate
];
Set<Id> r16ContractIds = new Set<Id>();
for (SM_Payment__c p : r16Payments) { if (p.SM_Contract__c != null) r16ContractIds.add(p.SM_Contract__c); }
List<SM_Payment__c> r16Accepted = r16ContractIds.isEmpty() ? new List<SM_Payment__c>() : [
    SELECT SM_Contract__c, CreatedDate FROM SM_Payment__c WHERE SM_Contract__c IN :r16ContractIds AND Payment_Status__c = 'ACCEPTED'
];
body += '### 5) R16 - CUENTA CONGELADA\n';
body += SM_ReturnCodeNotifier.buildReport(r16Payments, r16Accepted, 'R16 (CUENTA CONGELADA)', 'la cuenta esta congelada (usualmente por una orden legal/judicial) - fuera del control del cliente, dar seguimiento aparte antes de reintentar.');
body += '\n';

// --- Timeout reversal ---
List<SM_Payment__c> reversedPayments = [
    SELECT Id, Name, SM_Amount__c, CreatedDate,
           Payment_Status__c, SM_Check_Collection_Status__c, SM_Check_Collection_Date__c,
           SM_Return_code__c, SM_Historical_Collection_Status__c,
           SM_Transmission_Date_ACH_File__c,
           SM_Contract__c, SM_Contract__r.ContractNumber, SM_Contract__r.Status,
           SM_Contract__r.Is_Test_Contract__c, SM_Contract__r.Is_VIP_Contract__c
    FROM SM_Payment__c
    WHERE SM_Historical_Collection_Status__c LIKE '%D_SIN_REPORTE:%'
    AND (Payment_Status__c = 'REJECTED' OR SM_Check_Collection_Status__c IN ('RETURN', 'NOT_COLLECTED', 'NOT COLLECTED', 'PENDING'))
    ORDER BY SM_Contract__r.ContractNumber, SM_Check_Collection_Date__c
];
List<SM_Payment__c> filteredReversed = new List<SM_Payment__c>();
for (SM_Payment__c p : reversedPayments) {
    if (p.SM_Contract__r != null && (p.SM_Contract__r.Is_Test_Contract__c == true || p.SM_Contract__r.Is_VIP_Contract__c == true)) continue;
    filteredReversed.add(p);
}
body += '### 6) PAGOS ACEPTADOS POR TIMEOUT Y LUEGO REVERTIDOS\n';
body += SM_ReturnCodeNotifier.buildTimeoutReversalReport(filteredReversed);

System.debug('===BODY START===');
System.debug(body);
System.debug('===BODY END===');
System.debug('LENGTH: ' + body.length());
