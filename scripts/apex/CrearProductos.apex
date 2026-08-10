// Variables iniciales
String nombreProduct   = 'Credit Elevator 18 BF Official Day 2025';
String familiaProduct  = 'Credit rectification';
date activeStart             = Date.newInstance(2025, 11, 26);
date activeEnd               = Date.newInstance(2025, 12, 1);
String descripcion     = 'Active From 02 Dec 2025 to 31 Dec 2025';
Boolean IsCE = true;
Decimal ac             = 149;
Decimal rc             = 149;
Integer duracion      =  IsCE ? 12 : 99; //Plan Months

// Nombres de los Pricebooks
String pbLegalCreditName = 'Legal credit solutions';
String pbStandardName    = 'Standard Price Book';
String processAutomation    = IsCE ? 'Credit Elevator (HAR) Without Taxes' : 'Credit Rectification (LCS) Without Taxes';
//Credit Rectification (LCS) Without Taxes
//Credit Elevator (HAR) Without Taxes


// Consultar los Pricebooks dinámicamente
Id pbLegalCreditId = [SELECT Id FROM Pricebook2 WHERE Name = :pbLegalCreditName LIMIT 1].Id;
Id pbStandardId    = [SELECT Id FROM Pricebook2 WHERE Name = :pbStandardName LIMIT 1].Id;

// Consultar los Prodcess Automation
Id processAutomationId    = [SELECT Id FROM Process_automation_by_product_family__c WHERE Name = :processAutomation LIMIT 1].Id;


// Crear producto
Product2 newProd = new Product2(
    Name = nombreProduct,
    Family = familiaProduct,
    Description = descripcion,
    IsActive = true,
    Process_automation_by_product_family__c = processAutomationId,
    RecordTypeId = '0121U000000KY45QAG',   // Unit_Product
    SM_Plan_Months__c = duracion,
    SM_Requires_AC__c = ac > 0 ? true : false,
    SM_Requires_RC__c = rc > 0 ? true : false,
    SM_AC_value__c = ac,
    SM_Monthly_Offer__c = rc,
    SM_Product_type__c = 'Sale',
    SM_Frecuency__c = 'Monthly',
    SM_Way_to_pay__c = 'Subscription',
    SM_Full_Payment__c = IsCE,
    Effective_Date_Init__c = activeStart,
    Effective_Date_End__c = activeEnd 
);

insert newProd;
System.debug('✅ Producto creado: ' + newProd.Id + ' | ' + newProd.Name);

// Actualizar ProductCode con el Id
newProd.ProductCode = newProd.Id;
update newProd;
System.debug('🔄 ProductCode actualizado: ' + newProd.ProductCode);

// Crear PricebookEntries
PricebookEntry standar = new PricebookEntry(
    IsActive = true,
    Pricebook2Id = pbStandardId,
    Product2Id = newProd.Id,
    UnitPrice = newProd.SM_AC_value__c,
    UseStandardPrice = false
);
insert standar;

PricebookEntry lcs = new PricebookEntry(
    IsActive = true,
    Pricebook2Id = pbLegalCreditId,
    Product2Id = newProd.Id,
    UnitPrice = newProd.SM_AC_value__c,
    UseStandardPrice = false
);
insert lcs;

System.debug('📦 PricebookEntries creados: LCS ' + lcs.Id + ' | Standard ' + standar.Id);
System.debug('✅ Producto creado: ' + newProd.Id + ' | ' + newProd.Name);