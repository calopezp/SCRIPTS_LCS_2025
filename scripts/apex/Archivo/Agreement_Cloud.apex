String contratoId = '00315017';
List<echosign_dev1__SIGN_Agreement__c> quotes = [SELECT Id, echosign_dev1__Status__c, 
echosign_dev1__Cancel_Delete_Reason__c FROM echosign_dev1__SIGN_Agreement__c 
WHERE echosign_dev1__Contract__r.ContractNumber =: contratoId
AND echosign_dev1__Status__c <> 'Signed'];
for(echosign_dev1__SIGN_Agreement__c quote : quotes){
	quote.echosign_dev1__Status__c = 'Signed';
	quote.echosign_dev1__Cancel_Delete_Reason__c = 'FIRMADO EN FISICO - CLOUD DOCUMENTS';
}
update quotes;

List<Contract> cnts = [SELECT Id, SM_Agreement_Status__c FROM Contract
WHERE ContractNumber =: contratoId];
for(Contract cnt : cnts){
	cnt.SM_Agreement_Status__c = 'Signed';
}
update cnts;