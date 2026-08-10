/**
 * @description       : Dispute Object OpportunityLineItem
 * @author            : cjimenez@legal-credit.com
 * @group             :
 * @last modified on  : 10-11-2022
 * @last modified by  : Jonathan S. Pachon (JSPA)
 * Modifications Log
 * Ver   Date          Author                        Modification
 * 1.0   11-02-2021   cjimenez@legal-credit.com  Initial Version
**/
public with sharing class SM_OpportunityLineItemHandler extends SM_TriggerHandler {
    public SM_OpportunityLineItemHandler(String triggerName){
        super(triggerName);

    }


    /************* Overwrite DML methods *************/
    override public void beforeInsert() {
        try {
            validateProductsByFamily(Trigger.new);
            updatePrices(Trigger.new);
        } catch (Exception e) {
            System.debug('An error occurred in afterUpdate  OpportunityLineItem '+ e.getTypeName() + ' ' + e.getMessage() + ' ' +e.getStackTraceString());
        }
    }

    /** override after insert method */
    override public void afterInsert() {
        try {
            handleBundleProduct(Trigger.new);//DAJC 01/06/2021
        } catch (Exception e) {
            System.debug('An error occurred in afterInsert  OpportunityLineItem '+ e.getTypeName() + ' ' + e.getMessage() + ' ' +e.getStackTraceString());
        }
    }

    /** override after insert method */
    override public void beforeDelete() {
        // SMMMCI-58
        handleDontAllowProductDeletingInSomeStages(Trigger.oldMap);
        handleOpportunityLineItemsDeleting(Trigger.oldMap);
    }

    /**
    * @description This method process validate Products By Family
    * @author cjimenez@legal-credit.com | 11-02-2021
    * @param newOpportunityLineItems
    **/
    public void validateProductsByFamily(List<OpportunityLineItem> newOpportunityLineItems) {
        Map<String,OpportunityLineItem> productByOppLineItem=new Map<String,OpportunityLineItem>();
        Set<Id> productIds = new Set<Id>();
        List<Opportunity> lstOpportunity=new List<Opportunity>();
        for(OpportunityLineItem oppLineItem: newOpportunityLineItems){
           productByOppLineItem.put(oppLineItem.Product2id,oppLineItem);
           productIds.add(oppLineItem.Product2id);
        }
         validateScreenCapturedProducts(productByOppLineItem);
    }

    /**
    * @description This method validation Products By Family in Capture Screen
    * @author cjimenez@legal-credit.com | 22-02-2021
    * @param productByOppLineItem
    **/
    public void validateScreenCapturedProducts(Map<String,OpportunityLineItem> productByOppLineItem){
        Map<String,Product2> productByOppFam=new Map<String,Product2>();
        Map<String,OpportunityLineItem> oppLineItemByFam=new Map<String,OpportunityLineItem>();
        Boolean catchLimitPerfamily=false;
        String idOpportunity='';
        for (Product2 produc:[SELECT id,Family,SM_Product_type__c
                             FROM Product2
                             WHERE ID IN :productByOppLineItem.Keyset()
                             AND Process_automation_by_product_family__r.Quantity_Products_Pallowed_Custome__c != null]){
        String key = produc.Family;
        Product2 product=productByOppFam.containsKey(key) ? productByOppFam.get(key) : null;
        OpportunityLineItem oppLineItem=productByOppLineItem.containsKey(produc.id) ? productByOppLineItem.get(produc.id) : null;
        oppLineItemByFam.put(key,oppLineItem);
        idOpportunity=oppLineItem.OpportunityId;
        if(product != null || oppLineItem.Quantity > 1){
           showErrorMessage(oppLineItem);
           catchLimitPerfamily=true;
        }
        productByOppFam.put(key,produc);

       }
       if(!catchLimitPerfamily && !productByOppFam.isEmpty())
         validateProductsCapturedByOpportunities(idOpportunity,productByOppFam,oppLineItemByFam);
   }

      /**
    * @description This method validation Products By Family in Opportunitis
    * @author cjimenez@legal-credit.com | 22-02-2021
    * @param productByOppFam,productByOppLineItem
    **/
    public void validateProductsCapturedByOpportunities(String idOpportunity,Map<String,Product2> productByOppFam,Map<String,OpportunityLineItem> productByOppLineItem){
        String idAccount='';

        for(Opportunity opportunity:[SELECT id,StageName,AccountId
                                    ,(SELECT id,Product2Id,Product2.Family FROM OpportunityLineItems)
                                    FROM Opportunity
                                    WHERE id =: idOpportunity ]){

          for(OpportunityLineItem oppLineItem:opportunity.OpportunityLineItems){
                String key = oppLineItem.Product2.Family;
                Product2 product=productByOppFam.containsKey(key) ? productByOppFam.get(key) : null;
                OpportunityLineItem oppLineItemScreen=productByOppLineItem.containsKey(key) ? productByOppLineItem.get(key) : null;
                if(product != null){
                 showErrorMessage(oppLineItemScreen);
                }
           }
            idAccount=opportunity.AccountId;
        }
        for(Account account:[SELECT id
                           ,(SELECT id,Product2Id,Product2.Family FROM Assets WHERE SM_Contract__r.Status not in ('Finalized','Cancelled') )
                            FROM Account
                            WHERE id =: idAccount]){
            for(Asset asset:account.Assets){
                String key = asset.Product2.Family;
                Product2 product=productByOppFam.containsKey(key) ? productByOppFam.get(key) : null;
                OpportunityLineItem oppLineItemScreen=productByOppLineItem.containsKey(key) ? productByOppLineItem.get(key) : null;
                if(product != null){
                 showErrorMessage(oppLineItemScreen);
                }
             }
          }


    }

    /**
    * @description
    * @author Diego Jacanamijoy -> diego.jacanamijoy@gmail.es | 01/06/2021
    * @param newOpportunityLineItems
    **/
    public void handleBundleProduct(List<OpportunityLineItem> newOpportunityLineItems){

        Id recordTypeBundle = SM_Utils.getRecordTypeIdByDeveloperName('Product2', 'Bundle');//RT Bundle
        Set<String> p2Bundles = new Set<String>();
        Set<String> pb2s = new Set<String>();
        List<OpportunityLineItem> oppLntItemsToInsert = new List<OpportunityLineItem>();
        List<OpportunityLineItem> oppLntItemsToUpdate = new List<OpportunityLineItem>();
        Map<String,PricebookEntry> pbEntryByOppAndP2 = new Map<String,PricebookEntry>();

        //validate if is bundle
        newOpportunityLineItems = [SELECT Product2Id, Product2.RecordTypeId, Opportunity.Pricebook2Id,
                                            OpportunityId, SM_AC_Price__c, UnitPrice, SM_Monthly_Offer__c
                                    FROM OpportunityLineItem
                                    WHERE Id IN :newOpportunityLineItems];

        for(OpportunityLineItem oppLnIt: newOpportunityLineItems){
            if(oppLnIt.Product2.RecordTypeId == recordTypeBundle){
                p2Bundles.add(oppLnIt.Product2Id);
                pb2s.add(oppLnIt.Opportunity.Pricebook2Id);
            }
        }

        //get buldles records
        Map<String,Product2> bundlesById = new Map<String,Product2>([SELECT Id,
                                    (SELECT SM_AC_value_in_the_bundle__c, SM_Monthly_Offer_in_the_bundle__c, SM_Product__c, SM_Product__r.SM_Requires_RC__c,SM_Product__r.SM_Requires_AC__c FROM Products_per_bundle__r)
                                    FROM Product2
                                    WHERE Id IN :p2Bundles]);

        //Get pricebookentries
        for(PricebookEntry pbe: [SELECT Product2Id, Pricebook2Id FROM PricebookEntry WHERE Pricebook2Id IN :pb2s]){
            pbEntryByOppAndP2.put(pbe.Product2Id + '-'+ pbe.Pricebook2Id, pbe);
        }
        //Iterate oppLnItems
        for(OpportunityLineItem oppLnIt: newOpportunityLineItems){
            if(bundlesById.containsKey(oppLnIt.Product2Id)){
                //create child bundles
                oppLntItemsToInsert.addAll(createChildBundles(oppLnIt, bundlesById.get(oppLnIt.Product2Id), pbEntryByOppAndP2));
                //Set value to parent bundle
                // CJ 21/07/2022 SMMCI-5
                if(oppLnIt.SM_AC_Price__c <> 0 || oppLnIt.UnitPrice <> 0 || oppLnIt.SM_Monthly_Offer__c <> 0){
                    oppLnIt.SM_AC_Price__c = 0;
                    oppLnIt.UnitPrice = 0;
                    oppLnIt.SM_Monthly_Offer__c = 0;
                    oppLnIt.Product_Type__c = SM_ContractHelper.contractType.MASTER;
                    oppLnIt.Is_master__c = true;
                    oppLntItemsToUpdate.add(oppLnIt);
                }
            }
        }

        //create oppLnItems
        if(!oppLntItemsToInsert.isEmpty()){
            insert oppLntItemsToInsert;
        }

        //update oppLnItems
        if(!oppLntItemsToUpdate.isEmpty()){
            update oppLntItemsToUpdate;
        }
    }

    /**
    * @description
    * @author Diego Jacanamijoy -> diego.jacanamijoy@gmail.es | 01/06/2021
    * @param parent
    * @param parentBundle
    * @return List<OpportunityLineItem>
    **/
    public List<OpportunityLineItem> createChildBundles(OpportunityLineItem parent, Product2 parentBundle, Map<String,PricebookEntry> pbEntryByOppAndP2){
        List<OpportunityLineItem> childsBundles = new List<OpportunityLineItem>();

        //Iterate bundles
        for(SM_Product_per_bundle__c childBundle: parentBundle.Products_per_bundle__r){
            //Create oppLntItems by child bundle
            // CJ 21/07/2022 SMMCI-5
            childsBundles.add(
                new OpportunityLineItem(
                        OpportunityId = parent.OpportunityId,
                        Principal_Opportunity_Product__c = parent.id,
                        PricebookEntryId = pbEntryByOppAndP2.get(childBundle.SM_Product__c + '-' + parent.Opportunity.Pricebook2Id).Id,
                        SM_AC_Price__c = childBundle.SM_AC_value_in_the_bundle__c,
                        SM_Total_AC__c = childBundle.SM_Product__r.SM_Requires_AC__c == true ? childBundle.SM_AC_value_in_the_bundle__c : 0,
                        UnitPrice = childBundle.SM_Product__r.SM_Requires_RC__c == true ? childBundle.SM_Monthly_Offer_in_the_bundle__c : 0,
                        SM_Monthly_Offer__c = childBundle.SM_Monthly_Offer_in_the_bundle__c,
                        Product_Type__c = SM_ContractHelper.contractType.DEPENDENT
                        )
            );
        }
        return childsBundles;
    }

      /**
    * @description update Prices Unit Product
    * @author cjimenez@legal-credit.com | 22-02-2021 SMMCI-5
    * @param oppLineItem
    **/
    public void updatePrices(List<OpportunityLineItem> newOpportunityLineItems){
        Id recordTypeUnitProduct = SM_Utils.getRecordTypeIdByDeveloperName('Product2', 'Unit Product');
        Set<String> productIds = new Set<String>();
        for(OpportunityLineItem oppLnIt: newOpportunityLineItems){
             productIds.add(oppLnIt.Product2Id);
        }
        Map<String,Product2> productById = new Map<String,Product2>([SELECT RecordTypeId,Id,SM_Requires_AC__c,SM_Requires_RC__c,SM_Monthly_Offer__c,SM_AC_value__c,
                                           (SELECT SM_AC_value_in_the_bundle__c, SM_Monthly_Offer_in_the_bundle__c, SM_Product__c FROM Products_per_bundle__r)
                                           FROM Product2
                                           WHERE Id IN :productIds]);

        for(OpportunityLineItem oppLnIt: newOpportunityLineItems){
            Product2 product = productById.get(oppLnIt.Product2Id);
            if(product.RecordTypeId == recordTypeUnitProduct && oppLnIt.Principal_Opportunity_Product__c == null){
                oppLnIt.SM_Total_AC__c = product.SM_Requires_AC__c == true ? product.SM_AC_value__c : 0;
                oppLnIt.UnitPrice = product.SM_Requires_RC__c == true ? product.SM_Monthly_Offer__c : 0;
                oppLnIt.Product_Type__c =SM_ContractHelper.contractType.UNIQUE;
            }
        }
    }
    /**
    * @description This method shows the errors on the screen
    * @author cjimenez@legal-credit.com | 22-02-2021
    * @param oppLineItem
    **/
    public void showErrorMessage(OpportunityLineItem oppLineItem){
        // oppLineItem.addError(LABEL.SM_OPPORTUNITYLINEITEM_MASSAGE);
    }

    // public void handleDeleteChildProductsOfABundle_Old(Map<Id,SObject> opportunityLineItemsToDelete) {
    //     System.debug('opportunityLineItemsToDelete: ' + JSON.serialize(opportunityLineItemsToDelete));
    //     String bundleIdRecordType = SM_Utils.getRecordTypeIdByDeveloperName('Product2', 'Bundle');
    //     String unitProductIdRecordType = SM_Utils.getRecordTypeIdByDeveloperName('Product2', 'Unit Product');
    //     Map<String,String> bundleProductByOpportunityLineItemId = new Map<String,String>();
    //     Map<String,Set<String>> bundleProductOfOLTToDeleteByOpportunityId = new Map<String,Set<String>>();
    //     for (OpportunityLineItem recordToDelete : [SELECT Id, OpportunityId, Product2.RecordTypeId
    //                                                 FROM OpportunityLineItem
    //                                                 WHERE Id IN: opportunityLineItemsToDelete.keySet() AND Product2.RecordTypeId =: bundleIdRecordType]) {
    //         bundleProductByOpportunityLineItemId.put(recordToDelete.Id, recordToDelete.Product2Id);
    //         if (!bundleProductOfOLTToDeleteByOpportunityId.containsKey(recordToDelete.OpportunityId)) {
    //             bundleProductOfOLTToDeleteByOpportunityId.put(recordToDelete.OpportunityId, new Set<String>());
    //         }
    //         bundleProductOfOLTToDeleteByOpportunityId.get(recordToDelete.OpportunityId).add(recordToDelete.Product2Id);
    //     }
    //     if (bundleProductByOpportunityLineItemId.isEmpty()) return;
    //     Map<String,List<String>> childProductsByBundleId = new Map<String,List<String>>();
    //     for (SM_Product_per_bundle__c productPerBundle : [SELECT Id, SM_Bundle__c, SM_Product__c FROM SM_Product_per_bundle__c WHERE SM_Bundle__c IN: bundleProductByOpportunityLineItemId.values()]) {
    //         if (!childProductsByBundleId.containsKey(productPerBundle.SM_Bundle__c)) {
    //             childProductsByBundleId.put(productPerBundle.SM_Bundle__c, new List<String>());
    //         }
    //         childProductsByBundleId.get(productPerBundle.SM_Bundle__c).add(productPerBundle.SM_Product__c);
    //     }
    //     List<OpportunityLineItem> unitOpportunityIdsToDelete = new List<OpportunityLineItem>();
    //     for (OpportunityLineItem unitOpportunityLineItem : [SELECT Id, OpportunityId, Product2Id
    //                                                             FROM OpportunityLineItem
    //                                                             WHERE OpportunityId IN: bundleProductOfOLTToDeleteByOpportunityId.keySet()
    //                                                             AND Product2.RecordTypeId =: unitProductIdRecordType]) {
    //         if (!bundleProductOfOLTToDeleteByOpportunityId.containsKey(unitOpportunityLineItem.OpportunityId)) continue;
    //         for (String bundleProductIdOfAnOLI : bundleProductOfOLTToDeleteByOpportunityId.get(unitOpportunityLineItem.OpportunityId)) {
    //             if (!childProductsByBundleId.containsKey(bundleProductIdOfAnOLI)) continue;
    //             for (String childProductId : childProductsByBundleId.get(bundleProductIdOfAnOLI)) {
    //                 if (unitOpportunityLineItem.Product2Id == childProductId) {
    //                     unitOpportunityIdsToDelete.add(unitOpportunityLineItem);
    //                 }
    //             }
    //         }
    //     }
    //     if (!unitOpportunityIdsToDelete.isEmpty()) {
    //         SM_BypassManager.disableValidationRules();
    //         List<Database.DeleteResult> dr = Database.delete(unitOpportunityIdsToDelete);
    //         SM_BypassManager.enableValidationRules();
    //     }
    // }

        public void handleDontAllowProductDeletingInSomeStages(Map<Id,SObject> opportunityLineItemsToDelete) {
            List<String> opportunityStageToDontAllowProductsDeleting = new List<String>{
                SM_OpportunityHelper.stageName.oriented, SM_OpportunityHelper.stageName.paymentProcess, SM_OpportunityHelper.stageName.closedWon
            };
            Set<String> opportunityIds = new Set<String>();
            for (OpportunityLineItem opportunityLineItem : (List<OpportunityLineItem>)opportunityLineItemsToDelete.values()) {
                opportunityIds.add(opportunityLineItem.OpportunityId);
            }
            for (Opportunity opportunity : [SELECT Id, StageName FROM Opportunity WHERE StageName IN: opportunityStageToDontAllowProductsDeleting]) {
                for (OpportunityLineItem opportunityLineItem : (List<OpportunityLineItem>)opportunityLineItemsToDelete.values()) {
                    if (opportunityLineItem.OpportunityId == opportunity.Id) {
                        opportunityLineItem.addError(System.label.ERROR_MESSAGE_PRODUCT_DELETING);
                    }
                }
            }
        }

    /**
    * @description
    * @author Jonathan S. Pachon (JSPA) | 10-11-2022
    * @param Map<Id SObject> opportunityLineItemsToDelete
    **/
    public void handleOpportunityLineItemsDeleting(Map<Id,SObject> opportunityLineItemsToDelete) {
        System.debug('opportunityLineItemsToDelete: ' + JSON.serialize(opportunityLineItemsToDelete));
        Set<String> bundleOpportunityLineItemIds = new Set<String>();
        Set<String> childBundleOpportunityLineItemIds = new Set<String>();
        for (OpportunityLineItem opportunityLineItem : (List<OpportunityLineItem>)opportunityLineItemsToDelete.values()) {
            if (opportunityLineItem.Product_Type__c == SM_ContractHelper.contractType.MASTER) {
                bundleOpportunityLineItemIds.add(opportunityLineItem.Id);
            }
            if ((opportunityLineItem.Product_Type__c == SM_ContractHelper.contractType.DEPENDENT && opportunityLineItem.Principal_Opportunity_Product__c != null)) {
                opportunityLineItem.addError(System.label.ERROR_MESSAGE_DEPENDENT_PRODUCT_DELETING);
            }
        }
        if (bundleOpportunityLineItemIds.isEmpty()) return;
        List<OpportunityLineItem> unitOpportunityIdsToDelete = new List<OpportunityLineItem>();
        for (OpportunityLineItem childOpportunityLineItem : [SELECT Id
                                                                FROM OpportunityLineItem
                                                                WHERE Product_Type__c =: SM_ContractHelper.contractType.DEPENDENT
                                                                AND Principal_Opportunity_Product__c IN: bundleOpportunityLineItemIds]) {
            unitOpportunityIdsToDelete.add(childOpportunityLineItem);
        }
        if (unitOpportunityIdsToDelete.isEmpty()) return;
        SM_BypassManager.disableValidationRules();
        SM_TriggerHandler.avoidAllHandlerExcecution = true;
        List<Database.DeleteResult> dr = Database.delete(unitOpportunityIdsToDelete);
        SM_TriggerHandler.avoidAllHandlerExcecution = false;
        SM_BypassManager.enableValidationRules();
    }
}