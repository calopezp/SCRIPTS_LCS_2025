//Actualiza ChargeBee
//1. CAMBIAR EL TYPE DEL PAYMENT AC QUE ESTE EN NULL
list<SM_Payment__c> lstPayment = [
    SELECT Id, SM_Type__c
    FROM SM_Payment__c 
    WHERE SM_Type__c =  null 
    AND CB_Transaction__r.CB_Product_ID__c LIKE  '%01tUU000009nHP7YAM%'
    // 01tUU000009nHP7YAM = Credit Analysis (AC) - Credit Up
];
system.debug(' → lstPayment: ' + lstPayment.size());

for(SM_Payment__c pay : lstPayment){
    pay.SM_Type__c = 'AC';
}
update lstPayment;

// *****************  EN DESARROLLO .. CONTINUAR DESDE AQUI  *****************
return;


system.debug(' → Payments Marcados como AC: ' + lstPayment.size());

/// Invoice Rechazados que no tienen activado el Next Retry
list<CB_Invoice__c> lstInvoiceRetry = [
SELECT Id, Name, FORMAT(chargebeeapps__Invoice_Date__c), FORMAT(chargebeeapps__DueDate__c), chargebeeapps__Status__c, chargebeeapps__Next_Retry__c,
       (SELECT Id, Payment_Status__c, CB_Transaction__r.Transaction_Status__c  FROM Payments__r)
FROM chargebeeapps__CB_Invoice__c
WHERE Subscription_Status__c = 'Active'
  AND chargebeeapps__Status__c = 'PAYMENT_DUE'
  AND chargebeeapps__Next_Retry__c = NULL
 // AND Id NOT IN ( SELECT CB_Invoice__c FROM SM_Payment__c WHERE Payment_Status__c != 'Rejected')
AND Contract__r.ContractNumber =  '00316852'
];

system.debug(' → lstInvoiceRetry: ' + lstInvoiceRetry.size());

for(CB_Invoice__c inv : lstInvoiceRetry){
    inv.chargebeeapps__Next_Retry__c = Date.today().addDays(1);
}
//update lstInvoiceRetry;
system.debug(' → Invoices con Next Retry actualizado: ' + lstInvoiceRetry.size());
