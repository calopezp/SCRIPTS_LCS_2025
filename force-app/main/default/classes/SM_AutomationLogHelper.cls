/**
 * @description Builds the "AUTO: <process> - <action> - <date>" marker written into
 * SM_Id_Salesforce_LCS__c by automated processes (Apex triggers/handlers and Flows) so a
 * change made by automation is distinguishable later from a manual edit or another script -
 * both show up under the same running user identity otherwise (confirmed 2026-09-14: a
 * mystery duplicate SM_ACH_Order__c on contract 00317929 could not be traced to any
 * scheduled job or Carlos's own action because nothing left a marker). Any existing value is
 * preserved, appended after " // ", never overwritten - same convention already used by
 * COLLECTIONS/COLLECTIONS/update_check_collection.apex's "PRC_AUT:" prefix on
 * SM_Historical_Collection_Status__c. Truncated to 200 chars to stay safe across every field
 * this is used on (SM_ACH_Order__c.SM_Id_Salesforce_LCS__c is the shortest at 200; Contract
 * and SM_Payment__c both allow 255).
 * @author Carlos Alberto Lopez Prada
 */
public without sharing class SM_AutomationLogHelper {

    private static final Integer MAX_LENGTH = 200;

    public static String appendNote(String existingValue, String processName, String action) {
        String note = 'AUTO: ' + processName + ' - ' + action + ' - ' + Date.today().format();
        String combined = String.isBlank(existingValue) ? note : note + ' // ' + existingValue;
        return combined.length() > MAX_LENGTH ? combined.substring(0, MAX_LENGTH) : combined;
    }
}
