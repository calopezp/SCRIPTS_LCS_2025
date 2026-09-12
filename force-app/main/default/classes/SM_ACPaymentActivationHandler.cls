/**
 * @description Activates a Contract's AC once a non-ACH payment for it (ChargeBee, other
 * Credit Card gateways, Cash) reaches ACCEPTED. SM_paymentTGR_Handler and the legacy
 * SM_chargentOrTr_Handler already do this accumulate-until-total accounting for ACH- and
 * Chargent-collected AC payments respectively, keyed off SM_Payment__c.SM_ACH_Order__c /
 * ChargentOrders__Transaction__c. Neither covers a payment that has no SM_ACH_Order__c and
 * was never created as a ChargentOrders__Transaction__c (i.e. ChargeBee/Credit Card/Cash) -
 * SM_paymentTGR_Handler is also fully disabled via SM_Trigger_Panel__mdt regardless. That gap
 * left 26 ChargeBee contracts stuck in 'Payment Process' with their AC already ACCEPTED but
 * SM_AC_collected__c never set and Status never moved to 'Activated' (found 2026-09-12 while
 * diagnosing contract 00318338). This handler is intentionally separate from SM_PaymentHandler
 * so it can be deployed/toggled independently of the in-progress Chargent cleanup there.
 * @author Carlos Alberto Lopez Prada
 */
public without sharing class SM_ACPaymentActivationHandler extends SM_TriggerHandler {

    // Matches ActivateContractFullQueueable.cls's estadosInvalidos - both 'Cancelled' and
    // 'Canceled' show up in real Status data even though the current picklist only defines
    // SM_ContractHelper.status.CANCELED ('Cancelled').
    private static final Set<String> INELIGIBLE_CONTRACT_STATUSES = new Set<String>{
        SM_ContractHelper.status.FINALIZED, SM_ContractHelper.status.CANCELED, 'Canceled',
        SM_ContractHelper.status.DRAFT, SM_ContractHelper.status.COMPLETE_INFORMATION
    };

    public SM_ACPaymentActivationHandler(String triggerName) {
        super(triggerName);
    }

    override public void afterInsert() {
        activateContracts(Trigger.new, null);
    }

    override public void afterUpdate() {
        activateContracts(Trigger.new, Trigger.oldMap);
    }

    /**
     * @description oldRecordsMap is null on insert (every SM_Payment__c is "new"); on update
     * only payments whose Payment_Status__c actually changed to ACCEPTED qualify, so a later
     * unrelated edit to an already-ACCEPTED AC payment never re-runs the accumulation.
     */
    private void activateContracts(List<SM_Payment__c> newRecords, Map<Id, SObject> oldRecordsMap) {
        Set<Id> contractIds = new Set<Id>();
        List<SM_Payment__c> qualifyingPayments = new List<SM_Payment__c>();

        for (SM_Payment__c payment : newRecords) {
            SM_Payment__c oldPayment = oldRecordsMap == null ? null : (SM_Payment__c) oldRecordsMap.get(payment.Id);
            Boolean statusChangedToAccepted = oldRecordsMap == null
                ? payment.Payment_Status__c == SM_PaymentHelper.status.ACCEPTED
                : SM_Utils.isChangedField(payment, oldPayment, 'Payment_Status__c') && payment.Payment_Status__c == SM_PaymentHelper.status.ACCEPTED;

            if (statusChangedToAccepted
                && payment.SM_ACH_Order__c == null
                && payment.SM_Type__c == SM_ACHOrderHelper.paymentType.AC
                && payment.SM_Contract__c != null) {
                qualifyingPayments.add(payment);
                contractIds.add(payment.SM_Contract__c);
            }
        }

        if (qualifyingPayments.isEmpty()) {
            return;
        }

        Map<Id, Contract> contractsById = new Map<Id, Contract>([
            SELECT Id, Status, SM_Requires_AC_Payment__c, SM_AC_collected__c, SM_Total_AC__c,
                   SM_Charged_AC_Amount__c, SM_Charged_AC_Fees__c, SM_Partially_Charged_AC_Fees__c,
                   SM_Failed_AC_Fees__c, SM_Payment_Received__c, StartDate
            FROM Contract
            WHERE Id IN :contractIds
        ]);

        Set<Id> contractsToUpdate = new Set<Id>();

        for (SM_Payment__c payment : qualifyingPayments) {
            Contract contract = contractsById.get(payment.SM_Contract__c);
            if (contract == null
                || contract.SM_AC_collected__c == true
                || contract.SM_Requires_AC_Payment__c != true
                || INELIGIBLE_CONTRACT_STATUSES.contains(contract.Status)) {
                continue;
            }

            // Same accounting SM_paymentTGR_Handler / SM_chargentOrTr_Handler apply for their
            // own AC payments, so split-AC contracts (SM_AC_Split_Date__c != null, 2 payments)
            // accumulate correctly instead of activating on the first partial payment.
            contract.SM_Failed_AC_Fees__c = 0;
            if (contract.SM_Charged_AC_Fees__c == null) {
                contract.Status = SM_ContractHelper.status.PAYMENT_PROCESS;
            }
            contract.SM_Charged_AC_Fees__c = (contract.SM_Charged_AC_Fees__c == null ? 0 : contract.SM_Charged_AC_Fees__c) + 1;
            contract.SM_Partially_Charged_AC_Fees__c = contract.SM_Partially_Charged_AC_Fees__c == null ? 0 : contract.SM_Partially_Charged_AC_Fees__c;
            contract.SM_Charged_AC_Amount__c = contract.SM_Charged_AC_Amount__c == null ? 0 : contract.SM_Charged_AC_Amount__c;
            if (contract.SM_Charged_AC_Amount__c == 0) {
                contract.SM_Payment_Received__c = true;
            }
            contract.SM_Charged_AC_Amount__c += payment.SM_Amount__c == null ? 0 : payment.SM_Amount__c;

            if (contract.SM_Total_AC__c != null && contract.SM_Charged_AC_Amount__c >= contract.SM_Total_AC__c) {
                contract.SM_AC_collected__c = true;
                contract.StartDate = Date.today();
                contract.Status = SM_ContractHelper.status.ACTIVATED;
            }

            contractsToUpdate.add(contract.Id);
        }

        if (!contractsToUpdate.isEmpty()) {
            List<Contract> toUpdate = new List<Contract>();
            for (Id contractId : contractsToUpdate) {
                toUpdate.add(contractsById.get(contractId));
            }
            SM_BypassManager.disableValidationRules();
            update toUpdate;
            SM_BypassManager.enableValidationRules();
        }
    }
}
