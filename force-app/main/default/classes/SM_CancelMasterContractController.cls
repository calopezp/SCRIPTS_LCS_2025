/**
 * @description       : 
 * @author            : Diego Jacanamijoy -> djacanamijoy@legal-credit.com
 * @group             : 
 * @last modified on  : 07/10/2022
 * @last modified by  : Diego Jacanamijoy -> djacanamijoy@legal-credit.com
**/
public with sharing class SM_CancelMasterContractController implements Queueable {

    private Set<String> masterContractIds = new Set<String>();
    private List<Contract> masterContracts;

    public SM_CancelMasterContractController(Set<Id> masterContractIds) {

        validatePaymentsByContract(masterContractIds);
    }

    public void execute(QueueableContext qc){

        try {
            
            SM_CancelContractHelper cancelHelper = new SM_CancelContractHelper();

            this.masterContracts = cancelHelper.getContractsData(this.masterContractIds);

            /** Send records to cancel */
            cancelHelper.cancelRecords(this.masterContracts, false);

            /** Send depemndnet records to cancel */
            cancelHelper.cancelDependentContracts(this.masterContractIds);

            /** Update records */
            cancelHelper.updateRecords();


        } catch (Exception ex) {

            System.debug(ex.getStackTraceString() +'<br/>' + ex.getMessage() + '<br/>' + ex.getCause() +' <br/>'+ ex.getTypeName());
            String description = ex.getStackTraceString() +'<br/>' + ex.getMessage() + '<br/>' + ex.getCause() +' <br/>'+ ex.getTypeName();
            TransactionLogHandler.doHandleException(description, 'CancelUpgradedContract', null);
            SM_TaskHelper.createTaskToValidateErrorInUpgradedContract(description);
        }
    }

    /**
    * @description Validate payment data to don´t cancel Contracts
    * @author Diego Jacanamijoy -> djacanamijoy@legal-credit.com | 07/10/2022 
    * @param masterContractIds 
    **/
    public void validatePaymentsByContract(Set<Id> masterContractIds) {

        for (Contract master : [SELECT Id,
                                    (SELECT Id FROM Payment_Data__r WHERE Payment_Status__c IN ('ACH PENDING', 'ACH TRANSMITTED'))
                                FROM Contract
                                WHERE Id IN: masterContractIds])
        {
        
            /** If contracts has payments with status ACH PENDING OR ACH TRANSMITTED can´t change to Canceled */
            if (master.Payment_Data__r.size() > 0) {

                SObject so = Trigger.newMap.get(master.Id);
                so.addError('Don´t change status to Canceled with payments in status ACH PENDING OR ACH TRANSMITTED');
            } else {

                this.masterContractIds.add(master.Id);
            }
        }
    }
}