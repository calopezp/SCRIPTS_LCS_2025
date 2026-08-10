String accountId = '00148790';
String contratoId = '00315695';

// Query Account(s) by customer number
List<Account> accData = [
    SELECT Id,
           SM_Customer_Number__pc,
           FirstName,
           LastName,
           Suffix,
           SM_SSN__pc,
           SM_Other_Document_Number__pc,
           Phone,
           PersonBirthdate,
           SM_birth_place__c,
           SM_Age_Group__pc,
           SM_Occupation__pc,
           SM_Gender__pc,
           SM_Marital_Status__pc,
           SM_Other_Document_Type__pc,
           AnnualRevenue,
           SM_Collection_Period__c,
           SM_Income_Payment_Days__c,
           SM_Weight__c,
           SM_Height__c,
           SM_monitored_your_accounts__pc,
           SM_know_your_credit_score__pc,
           SM_Income_Range__pc,
           SM_Damaged_Credit_Reason__c,
           SM_Reasons_to_Buy__c,
           Contact_times__c,
           SM_Active__c
    FROM Account
    WHERE SM_Customer_Number__pc = :accountId
];

if (accData.isEmpty()) {
    System.debug('No Account found for customer number: ' + accountId);
} else {
    for (Account data : accData) {
        data.SM_SSN__pc = 'SN' + accountId;
        data.SM_Other_Document_Number__pc = 'DRV' + accountId;
        data.Phone = '000' + accountId;
        data.PersonBirthdate = Date.newInstance(1975, 11, 17);
        data.SM_birth_place__c = 'Puerto Rico';
        data.SM_Age_Group__pc = '40 - 49';
        data.SM_Occupation__pc = 'Analyst Programmer';
        data.SM_Gender__pc = 'Male';
        data.SM_Marital_Status__pc = 'Married';
        data.SM_Other_Document_Type__pc = 'Driverss License';
        data.AnnualRevenue = 12000;
        data.SM_Collection_Period__c = 'Monthly';
        data.SM_Income_Payment_Days__c = '13';
        data.SM_Weight__c = 64;
        data.SM_Height__c = 1.75;
        data.SM_monitored_your_accounts__pc = 'No Information Supplied';
        data.SM_know_your_credit_score__pc = 'No Information Supplied';
        data.SM_Income_Range__pc = 'No Information Supplied';
        data.SM_Damaged_Credit_Reason__c = 'No Information Supplied';
        data.SM_Reasons_to_Buy__c = 'Bankruptcy';
        data.Contact_times__c = '08:00 a. m.';
        data.SM_Active__c = true;
    }
    update accData;
    System.debug('Account Update: ' + accData[0].Id);
}

// Declaramos las variables FUERA del try para que estén disponibles después
ContactPointAddress addrBilling;
ContactPointAddress addrPostal;
ContactPointAddress addrPhysical;

try {
    // Crear direcciones
    addrBilling = new ContactPointAddress();
    addrBilling.ParentId = accData[0].Id;
    addrBilling.SM_Type__c = 'Billing Address';
    addrBilling.Street = 'Test Bill - 525 Avenida Franklin Delano Roosevelt 218';
    addrBilling.PostalCode = '00918';
    addrBilling.State = 'Puerto Rico';
    addrBilling.City = 'San Juan';
    addrBilling.Country = 'PR';
    insert addrBilling;
    System.debug('Billing Address inserted successfully. Id: ' + addrBilling.Id);

    addrPostal = new ContactPointAddress();
    addrPostal.ParentId = accData[0].Id;
    addrPostal.SM_Type__c = 'Postal Address';
    addrPostal.Street = 'Test Bill - 525 Avenida Franklin Delano Roosevelt 218';
    addrPostal.PostalCode = '00918';
    addrPostal.State = 'Puerto Rico';
    addrPostal.City = 'San Juan';
    addrPostal.Country = 'PR';
    insert addrPostal;
    System.debug('Postal Address inserted successfully. Id: ' + addrPostal.Id);

    addrPhysical = new ContactPointAddress();
    addrPhysical.ParentId = accData[0].Id;
    addrPhysical.SM_Type__c = 'Physical Address';
    addrPhysical.Street = 'Test Bill - 525 Avenida Franklin Delano Roosevelt 218';
    addrPhysical.PostalCode = '00918';
    addrPhysical.State = 'Puerto Rico';
    addrPhysical.City = 'San Juan';
    addrPhysical.Country = 'PR';
    insert addrPhysical;
    System.debug('Physical Address inserted successfully. Id: ' + addrPhysical.Id);

} catch (DmlException e) {
    System.debug('Error inserting Address: ' + e.getMessage());
}

// Update Contracts related to the first account
List<Contract> cnts = [
    SELECT Id,
           StartDate,
           SM_AC_start_date__c,
           SM_Start_date__c,
           SM_Physical_address__c,
           SM_Postal_address__c,
           SM_Billing_Address__c,
           SM_Way_of_AC_Payment__c,
           SM_Payment_day__c
    FROM Contract
    WHERE AccountId = :accData[0].Id
];

for (Contract cnt : cnts) {
    cnt.StartDate = Date.today();
    cnt.SM_AC_start_date__c = Date.today();
    cnt.SM_Start_date__c = Date.today().addDays(30);
    if (addrPhysical != null) cnt.SM_Physical_address__c = addrPhysical.Id;
    if (addrPostal != null) cnt.SM_Postal_address__c = addrPostal.Id;
    if (addrBilling != null) cnt.SM_Billing_address__c = addrBilling.Id;
    cnt.SM_Way_of_AC_Payment__c = 'One payment';
    cnt.SM_Payment_day__c = 13;
}

if (!cnts.isEmpty()) {
    update cnts;
    System.debug('Contracts updated: ' + cnts.size());
} else {
    System.debug('No Contracts found for Account: ' + accData[0].Id);
}