//VALIDAR PAGOS TRANSMITTED  (2:00 PM)
// Proceso para enviar generar el archivo de envios ACH
//agosto 2025
//
// 1- Get payemnts pending a procesar
//Objeto :: SM_Payment__c
//

List<SM_Payment__c> payments = [
    SELECT Id, Name, CreatedDate, Payment_Status__c, SM_ACH_Account_Number__c,
           SM_Date_ACH_Transmitted__c, SM_Person_Account_Name__c, SM_Type__c,
           SM_Net_Amount__c, SM_Original_Type__c, SM_Check_Collection_Status__c,
           SM_Penalty_value__c, SM_ACH_Order__r.Name, SM_ACH_Order__r.SM_Next_Transaction_Date__c,
           SM_Contract__r.ContractNumber, SM_Contract__r.SM_Payment_day__c, SM_Contract__r.Status,
           SM_Contract__r.SM_Customer_Cancellation__c, SM_Contract__r.SM_ContractMonitoring__c,
           SM_Contract__r.SM_Full_Payment__c, SM_Contract__r.SM_Net_AC__c,
           SM_Contract__r.SM_Net_Monthly_offer__c, SM_Contract__r.Count_Monthly_Payment_Pending__c,
           SM_Payment_Method__r.Id, SM_Payment_Method__r.Name, SM_Payment_Method__r.SM_ACH_Account_Number__c
    FROM SM_Payment__c
    WHERE Payment_Status__c = 'ACH PENDING'
];

// 2 - Validamos que este correcto el numero de cuenta comparandolo con el numero de cuenta del metodo de pago

for (SM_Payment__c payment : payments) {
    // Validate Account Number
    Boolean valAccount = payment.SM_Payment_Method__r.SM_ACH_Account_Number__c == payment.SM_ACH_Account_Number__c;
}

//3 - comparar si el payment se encuentra en los archivos ya reportados
