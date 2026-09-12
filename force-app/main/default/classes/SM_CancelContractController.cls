/**
 * @description       :
 * @author            : Diego Jacanamijoy -> djacanamijoy@legal-credit.com
 * @group             : LCS
 * @last modified on  : 07/10/2022
 * @last modified by  : Diego Jacanamijoy -> djacanamijoy@legal-credit.com
**/
public class SM_CancelContractController implements Queueable{

    // private List<Contract> contracts;
    private List<Contract> upgradedContracts;
    private Set<String> availableContractToUpgradeIds;
    private Map<String,String> opportunityIdsByContractId;
    private Map<String,String> newContractByUpgraded;

    public SM_CancelContractController(Map<String,String> opportunityIdsByContractId, Map<String,String> newContractByUpgraded) {
        this.opportunityIdsByContractId = opportunityIdsByContractId;
        this.newContractByUpgraded = newContractByUpgraded;
    }

    public void execute(QueueableContext qc){
        try {
            //TODO Validate contracts with Jonathan method
            // Send Map<String,String> opportunityIdsByContractId
            // Key: Contract Id to be Upgraded - Value: Opportunity of the new Contract
            Map<String,Opportunity> updatedOpportunityByContractIds = SM_OpportunityHandler.processRecordsToValidateUpgrade(opportunityIdsByContractId);
            // if (updatedOpportunityByContractIds.isEmpty()) return;

            SM_CancelContractHelper cancelHelper = new SM_CancelContractHelper();

            this.availableContractToUpgradeIds = cancelHelper.getAvailableContractsToUpgrade(opportunityIdsByContractId, updatedOpportunityByContractIds);
            this.upgradedContracts = cancelHelper.getContractsData(availableContractToUpgradeIds);

            /** Send records to cancel */
            cancelHelper.cancelRecords(this.upgradedContracts, true);

            /** Update records */
            cancelHelper.updateRecords();

            /** Send records to clone data */
            cancelHelper.cloneRecords(this.upgradedContracts, newContractByUpgraded);

            /** Insert Records */
            cancelHelper.insertRecords();

        } catch (Exception ex) {
            System.debug(ex.getStackTraceString() +'<br/>' + ex.getMessage() + '<br/>' + ex.getCause() +' <br/>'+ ex.getTypeName());
            String description = ex.getStackTraceString() +'<br/>' + ex.getMessage() + '<br/>' + ex.getCause() +' <br/>'+ ex.getTypeName();
            TransactionLogHandler.doHandleException(description, 'CancelUpgradedContract', null);
            SM_TaskHelper.createTaskToValidateErrorInUpgradedContract(description);
        }
    }
}