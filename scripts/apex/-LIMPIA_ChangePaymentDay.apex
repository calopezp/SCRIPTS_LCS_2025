// Valida y actualiza contratos 'Weekend Updated', 'Date Restored (Weekend)'

// 1. Obtener contratos
List<Contract> contratos = [
    SELECT Id, ContractNumber,
           Agreement_Orig_Pay_Day__c, SM_Payment_day__c, SM_Previous_Payment_day__c,
           Reasons_for_change__c, SM_DayReturnOriginalToPaymentDay__c,
           Status, SM_Customer_Cancellation__c
    FROM Contract
    WHERE Reasons_for_change__c IN ('Weekend Updated', 'Date Restored (Weekend)')
      AND SM_Customer_Cancellation__c = false AND Is_VIP_Contract__c = false AND  Is_Test_Contract__c = false
      AND Status IN ('Activated', 'Payment Process', 'Complete information')
      //AND ContractNumber IN ('00316814','00241461')
];

if (contratos.isEmpty()) {
    System.debug(' \u2192 ⚠️ No se encontraron contratos.');
    return;
}

System.debug(' \u2192 ℹ️ Contratos encontrados: ' + contratos.size());

List<Contract> contratosParaActualizar = new List<Contract>();

for (Contract contrato : contratos) {

    
    Boolean huboCambios = false;

    System.debug(' \u2192 ✔ Procesando contrato: ' + contrato.ContractNumber);

    // 1️⃣ Caso: Restaurar fecha original después de 8 días
    if (contrato.Reasons_for_change__c == 'Date Restored (Weekend)' &&
        contrato.SM_DayReturnOriginalToPaymentDay__c < Date.today().addDays(-8)) {

        contrato.SM_Payment_day__c = contrato.Agreement_Orig_Pay_Day__c;
        contrato.SM_Previous_Payment_day__c = null;
        contrato.Reasons_for_change__c = null;
        contrato.SM_DayReturnOriginalToPaymentDay__c = null;

        huboCambios = true;
    }

    // 2️⃣ Caso: Weekend Updated \u2192 convertir a Date Restored (Weekend)
    else if (contrato.Reasons_for_change__c == 'Weekend Updated') {

        contrato.SM_Payment_day__c = contrato.Agreement_Orig_Pay_Day__c;
        contrato.SM_Previous_Payment_day__c = null;
        contrato.Reasons_for_change__c = 'Date Restored (Weekend)';
        contrato.SM_DayReturnOriginalToPaymentDay__c = Date.today();

        huboCambios = true;
    }

    if (huboCambios) {
        contratosParaActualizar.add(contrato);
    }
}

// 3️⃣ Actualizar todos los contratos modificados
if (!contratosParaActualizar.isEmpty()) {
    update contratosParaActualizar;
    System.debug(' \u2192 ✅ Contratos actualizados: ' + contratosParaActualizar.size());
}