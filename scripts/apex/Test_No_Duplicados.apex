// Contrato 1 (00317170) ya tiene 1 orden AC (Payment Process). Lo movemos a Activated
// (dispara AC_Order_from_Update de nuevo) y verificamos que NO se cree una segunda.
Contract c1 = [SELECT Id, ContractNumber, Status FROM Contract WHERE ContractNumber = '00317170' LIMIT 1];
System.debug(' -> Antes: ' + c1.ContractNumber + ' Status=' + c1.Status);

Integer before = [SELECT COUNT() FROM SM_ACH_Order__c WHERE SM_Contract__c = :c1.Id AND SM_Payment_Type__c = 'AC'];
System.debug(' -> Ordenes AC antes: ' + before);

c1.Status = 'Activated';
update c1;

Integer after = [SELECT COUNT() FROM SM_ACH_Order__c WHERE SM_Contract__c = :c1.Id AND SM_Payment_Type__c = 'AC'];
System.debug(' -> Ordenes AC despues de re-disparar (Payment Process -> Activated): ' + after
    + (after == before ? '  [OK no duplico]' : '  [FALLO: duplico]'));
