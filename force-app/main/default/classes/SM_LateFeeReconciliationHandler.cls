/**
 * @description When a Payment that had previously failed (and so already spawned a "Late
 * payment fee" SM_ACH_Order__c, created Stopped by SM_PaymentHandler.processRejectedPayments
 * while awaiting the bank's final verdict) later resolves to SM_Check_Collection_Status__c =
 * 'COLLECTED', the sibling Late Payment Fee is no longer owed and must be canceled - otherwise
 * it sits Stopped indefinitely (excluded from SM_PaymentBatch, so no immediate double-charge
 * risk, but stale/incorrect data). No deployed automation covered this before (confirmed
 * 2026-09-13 while investigating contract 00318138/PY-01887694/ACH-29008): the matching logic
 * existed only inside a manual anonymous-Apex script (scripts/apex/-A.MASTER_2026_v6
 * ach-tc-Batch.apex) that has to be hand-run per contract - a live sweep the same day found 24
 * more Stopped Late Payment Fees org-wide ($2,784) whose original payment was already
 * COLLECTED. This handler only covers that COLLECTED -> Canceled direction; the symmetric
 * NOT_COLLECTED -> reactivate direction (which carries extra PTP/eligibility rules in the
 * manual script) is intentionally out of scope here pending a separate decision.
 * @author Carlos Alberto Lopez Prada
 */
public without sharing class SM_LateFeeReconciliationHandler extends SM_TriggerHandler {

    public SM_LateFeeReconciliationHandler(String triggerName) {
        super(triggerName);
    }

    override public void afterUpdate() {
        cancelResolvedLateFees(Trigger.new, Trigger.oldMap);
    }

    private void cancelResolvedLateFees(List<SM_Payment__c> newRecords, Map<Id, SObject> oldRecordsMap) {
        Set<Id> collectedPaymentIds = new Set<Id>();

        for (SM_Payment__c payment : newRecords) {
            SM_Payment__c oldPayment = (SM_Payment__c) oldRecordsMap.get(payment.Id);
            Boolean becameCollected = SM_Utils.isChangedField(payment, oldPayment, 'SM_Check_Collection_Status__c')
                && payment.SM_Check_Collection_Status__c == 'COLLECTED';
            if (becameCollected) {
                collectedPaymentIds.add(payment.Id);
            }
        }

        if (collectedPaymentIds.isEmpty()) {
            return;
        }

        List<SM_ACH_Order__c> staleLateFees = [
            SELECT Id, SM_Id_Salesforce_LCS__c, SM_Failed_payment__c, SM_Failed_payment__r.Name
            FROM SM_ACH_Order__c
            WHERE SM_Payment_Type__c = 'Late payment fee'
            AND SM_Payment_Status__c = 'Stopped'
            AND SM_Failed_payment__c IN :collectedPaymentIds
        ];

        if (staleLateFees.isEmpty()) {
            return;
        }

        for (SM_ACH_Order__c lateFee : staleLateFees) {
            lateFee.SM_Payment_Status__c = 'Canceled';
            lateFee.SM_Next_Transaction_Date__c = null;
            lateFee.SM_Id_Salesforce_LCS__c = SM_AutomationLogHelper.appendNote(
                lateFee.SM_Id_Salesforce_LCS__c, 'SM_LateFeeReconciliationHandler',
                'Cancelado por pago de Cobro original ' + lateFee.SM_Failed_payment__r.Name + ' COLLECTED'
            );
        }

        SM_BypassManager.disableValidationRules();
        update staleLateFees;
        SM_BypassManager.enableValidationRules();
    }
}
