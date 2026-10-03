/*
*  Puntual 2026-10-02: 8 SM_ACH_Order__c activas (Pending/Initiated) en contratos ya Cancelled
*  o marcados SM_Customer_Cancellation__c=true -- se detienen (Stopped), no se cancelan, por
*  la regla ya documentada en CLAUDE.md (confirmado por el usuario 2026-09-23). Encontradas
*  validando el estimado de transmisión ACH del dia antes de correr -A.
*/

Boolean DRY_RUN = false;

List<String> nombresAProteger = new List<String>{
    'ACH-25749','ACH-25905','ACH-26083','ACH-29074','ACH-29877', // contrato ya Cancelled
    'ACH-16049','ACH-16818','ACH-29218'                          // SM_Customer_Cancellation__c=true, en proceso
};

List<SM_ACH_Order__c> ordenes = [
    SELECT Id, Name, SM_Payment_Status__c, SM_Id_Salesforce_LCS__c,
           SM_Contract__r.ContractNumber, SM_Contract__r.Status
    FROM   SM_ACH_Order__c
    WHERE  Name IN :nombresAProteger
];

System.debug('→ Encontradas: ' + ordenes.size() + ' / ' + nombresAProteger.size() + ' esperadas');
for (SM_ACH_Order__c o : ordenes) {
    System.debug('   ' + o.Name + ' status=' + o.SM_Payment_Status__c + ' contrato=' + o.SM_Contract__r.ContractNumber + ' (' + o.SM_Contract__r.Status + ')');
}

if (DRY_RUN) {
    System.debug('(DRY RUN) No se escribió nada.');
} else {
    List<SM_ACH_Order__c> updBatch = new List<SM_ACH_Order__c>();
    for (SM_ACH_Order__c o : ordenes) {
        updBatch.add(new SM_ACH_Order__c(
            Id                       = o.Id,
            SM_Payment_Status__c     = 'Stopped',
            SM_Id_Salesforce_LCS__c  = SM_AutomationLogHelper.appendNote(
                                            o.SM_Id_Salesforce_LCS__c,
                                            'StopActiveOrders_CancelledContracts',
                                            'Detenida (Stopped) -- contrato ' + o.SM_Contract__r.ContractNumber + ' Cancelled/en proceso de cancelación'
                                        )
        ));
    }
    update updBatch;
    System.debug('→ ' + updBatch.size() + ' orden(es) pasadas a Stopped.');
}
