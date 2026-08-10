/**
* @description       :
* @author            : diego.jacanamijoy@gmail.com
* @group             :
* @last modified on  : 27/10/2022
* @last modified by  : Diego Jacanamijoy -> djacanamijoy@legal-credit.com
* Modifications Log  : Related oppLineItem to Asset
* Ver   Date         Author                        Modification
* 1.0   02-04-2021   diego.jacanamijoy@gmail.com   Initial Version
**/
public with sharing class SM_GenerateContractController {

    private Map<String,Opportunity> idsByOppValids;
    private static Set<String> accountIds;
    private static Map<String, Contract> masterContractByMasterProdLitem;

    /**Constructor */
    public SM_GenerateContractController(Map<String,Opportunity> idsByOppValids){
        this.idsByOppValids = idsByOppValids;
        generateContracts();
    }

    /**
    * @description Main method to generate contract
    * @author diego.jacanamijoy@gmail.com | 02-04-2021
    **/
    public void generateContracts(){
        try {
            validateOpportunityLineItems(getOpportunities(),this.idsByOppValids);
        } catch (Exception e) {
            throw new SM_CustomException('An error occurred creating contracts '+ e.getTypeName() + ' ' + e.getMessage() + ' ' +e.getStackTraceString());
        }
    }

    /**
    * @description This method get opportunities
    * @author diego.jacanamijoy@gmail.com | 02-04-2021
    * @return List<Opportunity>
    **/
    public List<Opportunity> getOpportunities(){
        String idsFormated = '(\'';
        List<String> oppsIds = new List<String>(idsByOppValids.keySet());
        idsFormated += String.join(oppsIds, '\',\'');
        idsFormated += '\')';
        
        String query = 'SELECT AccountId,Account.PersonEmail, SM_Opportunity_Disposition__c, SM_Company_Setting__r.SM_IVU_State_Amount__c, SM_Company_Setting__r.SM_IVU_Municipal_Amount__c, ';
        query += ' SM_MeetsUpgradeConditions__c,SM_ContractToBeUpgraded__c,SM_ContractToBeUpgraded__r.Contract_Type__c,SM_ContractToBeUpgraded__r.SM_Process_automation_by_product_family__c,SM_ContractToBeUpgraded__r.SM_Payment_day__c,SM_ContractToBeUpgraded__r.SM_Physical_address__c,SM_ContractToBeUpgraded__r.SM_Postal_address__c,SM_ContractToBeUpgraded__r.SM_Billing_Address__c,SM_ContractToBeUpgraded__r.SM_Payment_Method__c,SM_ContractToBeUpgraded__r.SM_Payment_methods__c, ';
        query += ' (SELECT OpportunityId, SM_Total_AC__c, UnitPrice, Is_master__c, Product_Type__c, Principal_Opportunity_Product__c, Product2.SM_Way_to_pay__c, Product2.SM_Plan_Months__c, Product2.Id, Product2Id, Product2.Name, Product2.SM_Requires_AC__c,Product2.SM_Requires_RC__c,Product2.SM_Full_Payment__c,Product2.SM_Monthly_Offer__c, Product2.SM_AC_value__c, Product2.SM_RC_value__c, ';
        query += ' Product2.Process_automation_by_product_family__c, Product2.Process_automation_by_product_family__r.SM_Generates_dispute__c, Product2.Process_automation_by_product_family__r.SM_Type_of_contract__c, Product2.Process_automation_by_product_family__r.Contract_activation_form__c, Product2.Process_automation_by_product_family__r.Start_assets_in_fee_number__c, ';
        query += ' Product2.Process_automation_by_product_family__r.SM_IVUStateAmount__c,Product2.Process_automation_by_product_family__r.SM_IVUMunicipalAmount__c ';
        query += ' FROM OpportunityLineItems ORDER BY Is_master__c desc) FROM Opportunity WHERE Id In ' + idsFormated;
        return SM_OpportunityHelper.getOpportunitiesByDinamicQuery(query);
    }

    /**
    * @description This method build maps to create records
    * @author diego.jacanamijoy@gmail.com | 11/02/2021
    * @param opps
    **/
    public static void validateOpportunityLineItems(List<Opportunity> opps,Map<String,Opportunity> idsByOppValids){

        Map<String, Contract> contractByOppAndProccessAut = new Map<String, Contract>();
        Map<String, List<Asset>> assetsByOppAndProccessAut = new Map<String, List<Asset>>();
        masterContractByMasterProdLitem = new Map<String, Contract>();
        accountIds = new Set<String>();
        Set<String> procesByProductIds = new Set<String>();
        Map<String, Map<String,String>> idsOriginFamilyBYfamiliesUpgrade = new Map<String, Map<String,String>>();
        //SMMCI-50 CJ 11-10-2022 
        for(Opportunity opp: opps){
            if(opp.SM_ContractToBeUpgraded__r?.SM_Process_automation_by_product_family__c != null)
               procesByProductIds.add(opp.SM_ContractToBeUpgraded__r?.SM_Process_automation_by_product_family__c);
        }
        if(!procesByProductIds.isEmpty()){
           for(SM_Families_Upgrade__c familiesUpgrade : [SELECT ID,SM_ProcessAutomationProductFamilyOrigin__c,SM_ProcessAutomationProductFamilyUpgrade__c,SM_Type__c
                                                         FROM SM_Families_Upgrade__c 
                                                         WHERE SM_ProcessAutomationProductFamilyOrigin__c =: procesByProductIds ]){
             if(!idsOriginFamilyBYfamiliesUpgrade.containsKey(familiesUpgrade.SM_ProcessAutomationProductFamilyOrigin__c)){
                 Map<String,String> idsUpgradeFamily = new Map<String,String>();
                 idsUpgradeFamily.put(familiesUpgrade.SM_ProcessAutomationProductFamilyUpgrade__c,familiesUpgrade.SM_ProcessAutomationProductFamilyUpgrade__c);
                 idsOriginFamilyBYfamiliesUpgrade.put(familiesUpgrade.SM_ProcessAutomationProductFamilyOrigin__c,idsUpgradeFamily);
                }else{
                    idsOriginFamilyBYfamiliesUpgrade.get(familiesUpgrade.SM_ProcessAutomationProductFamilyOrigin__c).put(familiesUpgrade.SM_ProcessAutomationProductFamilyUpgrade__c,
                                                                                                                         familiesUpgrade.SM_ProcessAutomationProductFamilyUpgrade__c);
                }
            }
        }
        /**Iterate opps */
        for(Opportunity opp: opps){
            // SFDCMP-201 - JSPA
            accountIds.add(opp.AccountId);
            /**Map of assets by proccess automation */
            Map<String, List<Asset>> assetsByAutomation = new Map<String, List<Asset>>();
            /** Iterate oppItems */
            for(OpportunityLineItem oppItem: opp.OpportunityLineItems){
                /**Key for maps  oppId + ProccessAutomId */
                String key = oppItem.OpportunityId + '-' + oppItem.Product2.Process_automation_by_product_family__c;
                /**Validate keys of maps */

                if(!contractByOppAndProccessAut.containsKey(key)){

                    /**New contract */
                    String wayOfACPayment = '';
                    String acFrequency = '';
                    Integer numberOfACFees = 0;
                    Boolean isContractToBeUpgraded = false;
                    if (opp.SM_Opportunity_Disposition__c == SM_OpportunityHelper.dispositions.sale) {
                        wayOfACPayment = SM_ContractHelper.wayOfACPayment.ONE_PAYMENT;
                        numberOfACFees = Integer.valueOf(System.label.NUMBER_OF_AC_FEES_BY_SALE);
                        isContractToBeUpgraded = true;
                    } else if (opp.SM_Opportunity_Disposition__c == SM_OpportunityHelper.dispositions.salePtp) {
                        wayOfACPayment = SM_ContractHelper.wayOfACPayment.FEES;
                        acFrequency = SM_ContractHelper.acFrequency.MONTHLY;
                        numberOfACFees = Integer.valueOf(System.label.NUMBER_OF_AC_FEES_BY_SALE_PTP);
                        isContractToBeUpgraded = true;
                    }
                    if(opp.SM_ContractToBeUpgraded__r.Contract_Type__c == SM_ContractHelper.contractType.DEPENDENT || opp.SM_ContractToBeUpgraded__r.Contract_Type__c == SM_ContractHelper.contractType.MASTER)
                       isContractToBeUpgraded = false;
                    acFrequency = opp.SM_Opportunity_Disposition__c == SM_OpportunityHelper.dispositions.salePtp ? SM_ContractHelper.acFrequency.MONTHLY : '';
                    //  SFDCMP-303 - JSPA
                    //  SFDCMP-325 - JSPA - Added SM_IVU_State__c & SM_IVU_Municipal__c fields to the creation of contract
                    String recordTypeIdStr = SM_Utils.getRecordTypeIdByDeveloperName('Contract', oppItem.Product2.Process_automation_by_product_family__r.SM_Type_of_contract__c);
                    //SMMCI-45 CJ 16-09-2022
                    Contract contract = new Contract(AccountId = opp.AccountId,
                                                     SM_Opportunity__c = opp.Id,
                                                     SM_Email_to_send_contract__c = opp.Account.PersonEmail,
                                                     SM_Process_automation_by_product_family__c = oppItem.Product2.Process_automation_by_product_family__c,
                                                     SM_Generates_dispute__c = oppItem.Product2.Process_automation_by_product_family__r.SM_Generates_dispute__c,
                                                     Contract_activation_form__c = oppItem.Product2.Process_automation_by_product_family__r.Contract_activation_form__c,
                                                     Start_assets_in_fee_number__c = oppItem.Product2.Process_automation_by_product_family__r.Start_assets_in_fee_number__c,
                                                     RecordTypeId = recordTypeIdStr,
                                                     //Don´t set value in field by system
                                                     //SM_Way_of_AC_Payment__c = wayOfACPayment,
                                                     SM_Number_of_AC_Fees__c = numberOfACFees,
                                                     SM_IVU_State__c = oppItem.Product2.Process_automation_by_product_family__r.SM_IVUStateAmount__c,
                                                     SM_IVU_Municipal__c = oppItem.Product2.Process_automation_by_product_family__r.SM_IVUMunicipalAmount__c,
                                                     Contract_Type__c = SM_ContractHelper.contractType.UNIQUE);
                    
                    //Build map of master contracts by master product line item
                    if(isMaster(oppItem)){

                        //Check if is master
                        contract.Contract_Type__c = SM_ContractHelper.contractType.MASTER;
                        masterContractByMasterProdLitem.put(oppItem.Id, contract);

                    } else if(isDependent(oppItem)){

                        //Check if is dependent
                        contract.Contract_Type__c = SM_ContractHelper.contractType.DEPENDENT;
                        contract.Principal_Contract__r = masterContractByMasterProdLitem.get(oppItem.Principal_Opportunity_Product__c);
                       //SMMCI-50 CJ 20-09-2022 
                    }
                    if(opp.SM_ContractToBeUpgraded__c != null && isContractToBeUpgraded){
                            if(opp.SM_ContractToBeUpgraded__r?.SM_Process_automation_by_product_family__c != null && opp.SM_MeetsUpgradeConditions__c == SM_OpportunityHelper.meetsUpgradeConditions.CAN_UPGRADE &&
                               !idsOriginFamilyBYfamiliesUpgrade.isEmpty()){ 
                                    Map<String,String> idsUpgradeFamily = idsOriginFamilyBYfamiliesUpgrade.containsKey(opp.SM_ContractToBeUpgraded__r.SM_Process_automation_by_product_family__c) ? 
                                                                          idsOriginFamilyBYfamiliesUpgrade.get(opp.SM_ContractToBeUpgraded__r.SM_Process_automation_by_product_family__c) : null;   
                                    if(idsUpgradeFamily != null && idsUpgradeFamily.containsKey(oppItem.Product2.Process_automation_by_product_family__c)){
                                        contract.SM_UpgradedContract__c = opp.SM_ContractToBeUpgraded__c;
                                        contract.SM_Payment_day__c = opp.SM_ContractToBeUpgraded__r.SM_Payment_day__c;
                                        contract.SM_Physical_address__c = opp.SM_ContractToBeUpgraded__r.SM_Physical_address__c;
                                        contract.SM_Postal_address__c = opp.SM_ContractToBeUpgraded__r.SM_Postal_address__c;
                                        contract.SM_Billing_Address__c = opp.SM_ContractToBeUpgraded__r.SM_Billing_Address__c;
                                        contract.SM_Payment_Method__c = opp.SM_ContractToBeUpgraded__r.SM_Payment_Method__c;
                                        contract.SM_Payment_methods__c = opp.SM_ContractToBeUpgraded__r.SM_Payment_methods__c;
                                    }
                            }else {
                                if(opp.SM_MeetsUpgradeConditions__c != SM_OpportunityHelper.meetsUpgradeConditions.CAN_UPGRADE){
                                    idsByOppValids.get(opp.id).addError(Label.SM_CONTRACT_UPGRADE_ERROR);
                                    break;
                                }  
                                if(idsOriginFamilyBYfamiliesUpgrade.isEmpty()){
                                    idsByOppValids.get(opp.id).addError(Label.SM_CONTRACT_UPGRADE_PROCESS_ERROR);
                                    break;
                                } 
                            }   
                    }
                    /**Instance of map */
                    contractByOppAndProccessAut.put(key, contract);
                } else {

                    //Check if is dependent
                    if(contractByOppAndProccessAut.get(key).Contract_Type__c == SM_ContractHelper.contractType.UNIQUE && isDependent(oppItem)){
                        contractByOppAndProccessAut.get(key).Contract_Type__c = SM_ContractHelper.contractType.DEPENDENT;
                        contractByOppAndProccessAut.get(key).Principal_Contract__r = masterContractByMasterProdLitem.get(oppItem.Principal_Opportunity_Product__c);
                    }
                }

                /**Create Asset by OpportunityLineItem */
                Asset asset = new Asset(AccountId = opp.AccountId, Product2 = oppItem.Product2, Product2Id = oppItem.Product2Id, Status = 'New', Name = oppItem.Product2.Name, 
                                        Price = oppItem.UnitPrice, Opportunity_Product__c = oppItem.Id, AC_Price__c = oppItem.SM_Total_AC__c);
                
                if(!assetsByOppAndProccessAut.containsKey(key)){
                    assetsByOppAndProccessAut.put(key, new List<Asset>{asset});
                }else{
                    assetsByOppAndProccessAut.get(key).add(asset);
                }
            }
        }
        /**Cal method to create records */
        buildDataToCreate(contractByOppAndProccessAut, assetsByOppAndProccessAut);
    }

    /**
    * @description This method check if product is master
    * @author Diego Jacanamijoy -> djacanamijoy@legal-credit.com | 08/07/2022 
    * @param oppLine 
    * @return Boolean 
    **/
    private static Boolean isMaster(OpportunityLineItem oppLine){
        return oppLine.Is_master__c && oppLine.Product_Type__c == SM_ContractHelper.contractType.MASTER;
    }

    /**
    * @description This method check if product is dependent
    * @author Diego Jacanamijoy -> djacanamijoy@legal-credit.com | 08/07/2022 
    * @param oppLine 
    * @return Boolean 
    **/
    private static Boolean isDependent(OpportunityLineItem oppLine){
        return oppLine.Product_Type__c == SM_OpportunityHelper.contractType.DEPENDENT && 
                                        masterContractByMasterProdLitem.containsKey(oppLine.Principal_Opportunity_Product__c);
    }

    /**
    * @description This methos buikd data to create
    * @author diego.jacanamijoy@gmail.com | 11/02/2021
    * @param contractByOppAndProccessAut
    * @param assetsByOppAndProccessAut
    **/
    public static void buildDataToCreate(Map<String, Contract> contractByOppAndProccessAut, Map<String, List<Asset>> assetsByOppAndProccessAut){
        // SFDCMP-201 - JSPA

        List<Contract> mastersToInsert = new List<Contract>();
        List<Contract> dependentsToInsert = new List<Contract>();         

        Map<String, String> addressIdByKeys;
        if (!accountIds.isEmpty()) {
            addressIdByKeys = getAccountAddresses();
        }
        /**Iterate map by keys => oppId + ProccAut Id*/
        for(String key: contractByOppAndProccessAut.keySet()){
            Decimal monOffer = 0;
            Decimal acValue = 0;
            Boolean isAc = false;
            Boolean isRc = false;
            String wayOfContract = '';
            Decimal planMonths = 0;
            Decimal totalACPrices = 0;

            // SFDCMP-211
            // Boolean isfP = false;
            /**Iterate map assets by automations*/
            for(Asset asset: assetsByOppAndProccessAut.get(key)){
                acValue = asset.AC_Price__c <> null ? acValue += asset.AC_Price__c : acValue;
                monOffer = asset.Price <> null ? monOffer += asset.Price : monOffer;
                isAc = asset.Product2.SM_Requires_AC__c ? asset.Product2.SM_Requires_AC__c : isAc;
                isRc = asset.Product2.SM_Requires_RC__c ? asset.Product2.SM_Requires_RC__c : isRc;
                // SFDCMP-211
                wayOfContract = asset.Product2.SM_Way_to_pay__c;
                planMonths = asset.Product2.SM_Plan_Months__c > planMonths ? asset.Product2.SM_Plan_Months__c : planMonths;

                // SFDCMP-211
                // isfP = asset.Product2.SM_Requires_RC__c ? asset.Product2.SM_Full_Payment__c : isfP;
            }

            /**Updater data in contract */
            Contract contract = contractByOppAndProccessAut.get(key);
            // SFDCMP-201 - JSPA
            String postalAddressKey = contract.AccountId + ' - ' + SM_ContactPointAddressHelper.type.POSTAL_ADDRESS;
            String physicalAddressKey = contract.AccountId + ' - ' + SM_ContactPointAddressHelper.type.PHYSICAL_ADDRESS;
            String otherBillingAddressKey = contract.AccountId + ' - ' + SM_ContactPointAddressHelper.type.BILLING_ADDRESS;
             //SMMCI-50 CJ 15-10-2022 
            if(contract.SM_UpgradedContract__c == null){
                contract.SM_Postal_address__c = addressIdByKeys.containsKey(postalAddressKey) ? addressIdByKeys.get(postalAddressKey) : null;
                contract.SM_Physical_address__c = addressIdByKeys.containsKey(physicalAddressKey) ? addressIdByKeys.get(physicalAddressKey) : null;
                contract.SM_Billing_Address__c = addressIdByKeys.containsKey(otherBillingAddressKey) ? addressIdByKeys.get(otherBillingAddressKey) : null;
            }
            contract.SM_Way_of_Contract_Payment__c = wayOfContract;
            contract.SM_Requires_AC_Payment__c = isAc;
            contract.SM_Requires_RC_Payment__c = isRc;
            // SFDCMP-211
            // contract.SM_Full_Payment__c = isfP;
            contract.SM_Total_ac__c = acValue;
            contract.SM_Monthly_Offer__c = monOffer;
            // contract.SM_Way_of_Contract_Payment__c= isRc && !isfP ? SM_ContractHelper.wayOfContract.SUSCRIPTION : isRc && isfP ? SM_ContractHelper.wayOfContract.FEES : SM_ContractHelper.wayOfContract.NA;
            // contract.SM_Plan_Months__c=contract.SM_Way_of_Contract_Payment__c == SM_ContractHelper.wayOfContract.FEES ? 1 : NULL;
            contract.SM_Plan_Months__c = planMonths;
            contractByOppAndProccessAut.put(key, contract);
            //Check master or dependent 
            if(contract.Contract_type__c == SM_ContractHelper.contractType.MASTER){
                mastersToInsert.add(contract);
            }else {
                dependentsToInsert.add(contract);
            }
        }

        /**Create contracts first masters*/
        if(!mastersToInsert.isEmpty()){
            insert mastersToInsert;
        }

        if(!dependentsToInsert.isEmpty()){
            //Relate master ids
            for (Contract depend : dependentsToInsert) {
                if(depend.Principal_Contract__r <> null){
                    depend.Principal_Contract__c = depend.Principal_Contract__r.Id;
                }
            }
            insert dependentsToInsert;
        }

        /**Iterate assets map for related contractId */
        List<Asset> assetsToInsert = new List<Asset>();
        for(String key: assetsByOppAndProccessAut.keySet()){
            for(Asset asset: assetsByOppAndProccessAut.get(key)){
                Contract contractAux = contractByOppAndProccessAut.get(key);
                asset.SM_Contract__c = contractAux.Id;
                // JSPA - SFDCMP-239
                asset.SM_Email_to_send_contract__c = contractAux.SM_Email_to_send_contract__c;
                asset.Principal_Contract__c = contractAux.Principal_Contract__r?.Id;
                asset.Contract_activation_form__c = contractAux.Contract_activation_form__c;
                asset.Start_assets_in_fee_number__c = contractAux.Start_assets_in_fee_number__c;
                assetsToInsert.add(asset);
            }
        }
        /**Create assets */
        insert assetsToInsert;
        // SFDCMP-294 - JSPA - Move this code to SM_ACHOrderHandler
        // List<SM_Asset_Fee__c> assetsFeeToInsert = new List<SM_Asset_Fee__c>();
        // SM_Asset_Fee__c assetFee;
        // for (Asset asset : assetsToInsert) {
        //     Decimal qtyOfAssetsFeeToCreate = 0;
        //     String assetFeeType = '';
        //     if (asset.Product2.SM_Way_to_pay__c == 'Subscription') {
        //         qtyOfAssetsFeeToCreate = 1;
        //         assetFeeType = 'Subscription';
        //     }
        //     if (asset.Product2.SM_Way_to_pay__c == 'Fix Term') {
        //         qtyOfAssetsFeeToCreate = asset.Product2.SM_Plan_Months__c;
        //         assetFeeType = 'Fee';
        //     }
        //     for (Decimal i = 0; i < qtyOfAssetsFeeToCreate; i++) {
        //         assetFee = new SM_Asset_Fee__c(
        //             SM_Asset__c = asset.Id,
        //             SM_Position__c = i + 1,
        //             SM_Type__c = assetFeeType,
        //             SM_Amount__c = asset.Product2.SM_Monthly_Offer__c,
        //             SM_Contract__c = asset.SM_Contract__c,
        //             SM_Status__c = 'Scheduled',
        //             Name = assetFeeType + '-' + (i + 1)
        //         );
        //         assetsFeeToInsert.add(assetFee);
        //     }
        // }
        // if (!assetsFeeToInsert.isEmpty()) {
        //     List<Database.SaveResult> sr = Database.insert(assetsFeeToInsert);
        // }
    }

    /**
    * @description Method to get contact point addresses related to contract account
    * @author jpachon@legal-credit.com | 03-11-2021
    * @return addressIdByKeys | Map<String, String>
    **/
    public static Map<String, String> getAccountAddresses(){
        // Key => Account Id + AddressType
        Map<String, String> addressIdByKeys = new Map<String, String>();
        List<ContactPointAddress> accountAddresses = SM_ContactPointAddressHelper.getAddressesByParentIds(accountIds);
        if (!accountAddresses.isEmpty()) {
            for (ContactPointAddress cpa : accountAddresses) {
                String key = cpa.ParentId + ' - ' + cpa.SM_Type__c;
                if (!addressIdByKeys.containsKey(key)) {
                    addressIdByKeys.put(key, cpa.Id);
                }
            }
        }
        return addressIdByKeys;
    }
}