// Codigo para cambio de TC a ACh cuando genera error
STRING contractNumber = '00315328';
STRING paymentMethod = 'PM-00000';

// 1. Validamos los datos del contrato

List <Contract__c> contracts = [SELECT Id, ContractNumber, Status, SM_Payment_Method__c, SM_Payment_methods__c, SM_Customer_Cancellation__c, Is_Test_Contract__c, Is_VIP_Contract__c, SM_Full_Payment__c FROM Contract__c WHERE ContractNumber = :contractNumber];

if (contracts.isEmpty()) {
    System.debug(' → No se encontró el contrato con el número: ' + contractNumber);
    return;
}

// Validaciones del contrato

if (contracts.Status != 'Active' or contracts.Status != 'Payment Process') {
    System.debug(' → El contrato no tiene el estado correcto. Estado actual: ' + contracts.Status);
    return;
}

if (contracts.SM_Customer_Cancellation__c == true) {
    System.debug(' → El contrato está marcado como cancelado por el cliente.');
    return;
}

if (contracts.Is_Test_Contract__c == true) {
    System.debug(' → El contrato está marcado como contrato de prueba.');
    return;
}

if (contracts.Is_VIP_Contract__c == true) {
    System.debug(' → El contrato está marcado como contrato VIP.');
    return;
}

if (contracts.SM_Full_Payment__c == true) {
    System.debug(' → El contrato está marcado como FULL PAYMENT.');
    return;
}

// 2. Validamos el método de pago

List <Payment_Method__c> paymentMethods = [SELECT Id, Name FROM Payment_Method__c WHERE Name = :paymentMethod];

if (paymentMethods.isEmpty()) {
    System.debug(' → No se encontró el método de pago con el nombre: ' + paymentMethod);
    return;
}