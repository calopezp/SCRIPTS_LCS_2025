// ┌──────────────────────────────────────────────────────────────┐
// │  ACTIVACIÓN MANUAL DE MÚLTIPLES CONTRATOS                    │
// └──────────────────────────────────────────────────────────────┘

// Lista de ContractNumber a procesar
List<String> contratosAProcesar = new List<String>{
   //'00317405','00317431'   // ⚠️⚠️⚠️⚠️ ejecutar de a un solo contrato... no admite varios contratos a la vez, validar cada uno antes de ejecutar el siguiente
   /*
        SELECT SM_Contract__r.ContractNumber, SM_Contract__r.SM_AC_Split_Date__c, SM_Contract__r.CB_Subscription__c,SM_Contract__r.SM_Payment_methods__c FROM SM_Payment__c WHERE Payment_Status__c ='ACCEPTED' AND SM_Type__c = 'AC' 
                AND SM_Contract__c IN (SELECT Id FROM Contract WHERE Status = 'Payment Process'  AND Is_Test_Contract__c =false AND Is_VIP_Contract__c = false )     
   */
'00318012'


};
// Estados que NO deben procesarse
Set<String> estadosInvalidos = new Set<String>{
    'Finalized', 'Cancelled', 'Canceled', 'Draft', 'Complete information'
};

if (contratosAProcesar.isEmpty()) {
    System.debug(' \u2192 ❌ No se proporcionaron contratos.');
    return;
}

for (String contratoNum : contratosAProcesar) {

    System.debug(' \u2192 Procesando contrato: ' + contratoNum);

    if (String.isBlank(contratoNum)) {
        System.debug(' \u2192 ❌ ContractNumber vacío, se omite.');
        continue;
    }

    // 1️⃣ Consultar contrato
    Contract c;
    try {
        c = [
            SELECT Id, SM_Net_AC__c, SM_Charged_AC_Fees__c, SM_Charged_AC_Amount__c,
                   SM_AC_collected__c, SM_Payment_Received__c, SM_Start_date__c,
                   SM_AC_Split_Date__c, Status, ContractNumber
            FROM Contract
            WHERE ContractNumber = :contratoNum
            LIMIT 1
        ];
    } catch (Exception e) {
        System.debug(' \u2192 ❌ Contrato no encontrado: ' + contratoNum);
        continue;
    }

    // 2️⃣ Validación de estado
   if (c.Status == 'Activated') {
        System.debug(' \u2192 ⚠️ Contrato ' + c.ContractNumber + ' ya está ACTIVATED. No se procesa.');
        continue;
    }

    if (c.SM_AC_Split_Date__c != null) {
        System.debug(' \u2192 Contrato ' + c.ContractNumber + ' con Split Date ' + c.SM_AC_Split_Date__c);
       // continue;
    }

    if (estadosInvalidos.contains(c.Status)) {
        System.debug(' \u2192 ⚠️ Contrato ' + c.ContractNumber + ' en estado inválido (' + c.Status + '). No se procesa.');
        continue;
    }

    // 3️⃣ Consultar pagos del contrato
    List<SM_Payment__c> payments = [
        SELECT Id, Name, Payment_Status__c, SM_Payment_Date__c,
               SM_Net_Amount__c, SM_Original_Type__c, SM_Type__c
        FROM SM_Payment__c
        WHERE SM_Contract__c = :c.Id
        ORDER BY SM_Payment_Date__c DESC
    ];

    // 4️⃣ Validar pagos AC
    Integer countPayments = 0;
    Boolean pagoACValidado = false;

// Los pagos de Chargebee solo son Type AC, por lo general el Lat Paymetn Fee solo cobra Multa $25, pueden existir pagos aceptados de multa, pero no de cuota

    for (SM_Payment__c p : payments) {
        if ((p.SM_Original_Type__c == 'AC' || p.SM_Type__c == 'AC') &&
             p.Payment_Status__c == 'ACCEPTED') {

            pagoACValidado = true;
            countPayments++;

            System.debug(' \u2192 ✔ Pago AC válido: ' + p.Name + ' 🔸 Monto: ' + p.SM_Net_Amount__c + ' 🔸 Payment_Date : ' + p.SM_Payment_Date__c);
        }
    }

    System.debug(' \u2192 Total pagos AC válidos: ' + countPayments);

    // 5️⃣ Reglas de negocio AC
    if (countPayments == 0) {
        System.debug(' \u2192 ❌ No hay pagos AC válidos. Contrato NO activado.');
        continue;
    }

    if (c.SM_AC_Split_Date__c == null && countPayments == 1) {
        c.SM_Charged_AC_Fees__c = 1;
        System.debug(' \u2192 1 solo pago AC, SplitDate NULL. SM_Charged_AC_Fees__c = 1');
    }
    else if (c.SM_AC_Split_Date__c != null && countPayments == 2) {
        c.SM_Charged_AC_Fees__c = 2;
        System.debug(' \u2192 2 pagos AC, SplitDate no NULL. SM_Charged_AC_Fees__c = 2');
    }
    else if (countPayments > 2) {
        System.debug(' \u2192 ⚠️ Hay pagos AC adicionales (' + (countPayments - 2) + ') para el contrato ' + c.ContractNumber + '. Validar REFUND o duplicados.');
        continue;
    }
    else {
        System.debug(' \u2192 ⚠️ Cantidad de pagos AC del contrato ' + c.ContractNumber + ' no coincide con reglas de negocio.');
        continue;
    }

    // 6️⃣ Activación del contrato
    c.Status = 'Activated';
    c.SM_Charged_AC_Amount__c = c.SM_Net_AC__c;
    c.SM_AC_collected__c = true;
    c.SM_Payment_Received__c = true;

    update c;

    System.debug(' \u2192 ──────── > ✅ Contrato ACTIVADO: ' + c.ContractNumber);
}

System.debug(' \u2192 ────────────────────────────────────────────');
System.debug(' \u2192 Proceso finalizado.');
