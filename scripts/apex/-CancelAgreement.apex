String contratoId = '00316890';
List<echosign_dev1__SIGN_Agreement__c> quotes = [SELECT Id, echosign_dev1__Status__c, 
echosign_dev1__Cancel_Delete_Reason__c FROM echosign_dev1__SIGN_Agreement__c 
WHERE echosign_dev1__Contract__r.ContractNumber =: contratoId
AND echosign_dev1__Status__c = 'Out for Signature'];
for(echosign_dev1__SIGN_Agreement__c quote : quotes){
	quote.echosign_dev1__Status__c = 'Cancelled/Reenvío';   //'Signed in Office';
	quote.echosign_dev1__Cancel_Delete_Reason__c = 'CAMBIO FECHAS AC/RC'; 
}
update quotes;
List<Contract> cnts = [SELECT Id, SM_Agreement_Status__c FROM Contract
WHERE ContractNumber =: contratoId];
for(Contract cnt : cnts){
	cnt.SM_Agreement_Status__c = 'Signed';
}
update cnts;