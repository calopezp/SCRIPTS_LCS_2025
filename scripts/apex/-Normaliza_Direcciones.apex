// ┌──────────────────────────────────────────────────────────────┐
// │ NORMALIZACIÓN DE DIRECCIONES (Contact + ContactPointAddress) │
// └──────────────────────────────────────────────────────────────┘


// ===============================
// 1️⃣ CONTACT
// ===============================

List<Contact> cons = [
    SELECT Id, MailingStreet, MailingCity, MailingCountry
    FROM Contact
    WHERE 
    (
        MailingStreet LIKE '%\n%'
        OR MailingStreet LIKE '%\r%'
        OR MailingStreet LIKE '%\r\n%'
        OR MailingStreet LIKE '%\t%'
        OR MailingStreet LIKE '%\u000B%'
        OR MailingStreet LIKE '%\u000C%'
        OR MailingStreet LIKE '%\u0085%'

        OR (MailingCity = 'San Juan' AND (MailingCountry != 'PR' OR MailingCountry = null))
        OR (MailingCity = 'SAN JUAN' AND (MailingCountry != 'PR' OR MailingCountry = null))
        OR (MailingCity = 'Puerto Rico' AND (MailingCountry != 'PR' OR MailingCountry = null))
        OR (MailingCity = 'PUERTO RICO' AND (MailingCountry != 'PR' OR MailingCountry = null))
    )
   
   
];

system.debug(LoggingLevel.INFO, '\u2192 Contactos encontrados: ' + cons.size());
List<Contact> updCons = new List<Contact>();

for (Contact c : cons) {

    Boolean changed = false;

    // LIMPIAR STREET
    if (c.MailingStreet != null) {

        String cleaned = c.MailingStreet;

        cleaned = cleaned.replace('\n', ' ');
        cleaned = cleaned.replace('\r', ' ');
        cleaned = cleaned.replace('\r\n', ' ');
        cleaned = cleaned.replace('\t', ' ');
        cleaned = cleaned.replaceAll('[\\u000B\\u000C\\u0085]', ' ');

        cleaned = cleaned.trim().toUpperCase();

        if (cleaned != c.MailingStreet) {
            c.MailingStreet = cleaned;
            changed = true;
        }
    }

    // NORMALIZAR CITY
    if (c.MailingCity != null) {
        String cleanedCity = c.MailingCity.trim().toUpperCase();
        if (cleanedCity != c.MailingCity) {
            c.MailingCity = cleanedCity;
            changed = true;
        }
    }

    // NORMALIZAR COUNTRY
    if (c.MailingCountry != null && c.MailingCountry != 'PR') {
        c.MailingCountry = 'PR';
        changed = true;
    }

    if (changed) updCons.add(c);
}

if (!updCons.isEmpty()) {
    update updCons;
    System.debug(LoggingLevel.INFO,' \u2192 Contactos actualizados: ' + updCons.size());
}



// ===============================
// 2️⃣ CONTACT POINT ADDRESS
// ===============================

List<ContactPointAddress> cpas = [
    SELECT Id, Street, City, Country
    FROM ContactPointAddress
    WHERE 
        Street LIKE '%\n%' 
        OR Street LIKE '%\r%'
        OR Street LIKE '%\r\n%'
        OR Street LIKE '%\t%'
        OR Street LIKE '%\u000B%'
        OR Street LIKE '%\u000C%'
        OR Street LIKE '%\u0085%'

        OR (City = 'San Juan' AND (Country != 'PR' OR Country = null))
        OR (City = 'SAN JUAN' AND (Country != 'PR' OR Country = null))
        OR (City = 'Puerto Rico' AND (Country != 'PR' OR Country = null))
        OR (City = 'PUERTO RICO' AND (Country != 'PR' OR Country = null))

    
];

System.debug(LoggingLevel.INFO,' \u2192 Contact Point Addresses encontrados: ' + cpas.size());

List<ContactPointAddress> updCpas = new List<ContactPointAddress>();

for (ContactPointAddress a : cpas) {

    Boolean changed = false;

    // LIMPIAR STREET
    if (a.Street != null) {

        String cleaned = a.Street;

        cleaned = cleaned.replace('\n', ' ');
        cleaned = cleaned.replace('\r', ' ');
        cleaned = cleaned.replace('\r\n', ' ');
        cleaned = cleaned.replace('\t', ' ');
        cleaned = cleaned.replaceAll('[\\u000B\\u000C\\u0085]', ' ');

        cleaned = cleaned.trim().toUpperCase();

        if (cleaned != a.Street) {
            a.Street = cleaned;
            changed = true;
        }
    }

    // NORMALIZAR CITY
    if (a.City != null) {
        String cleanedCity = a.City.trim().toUpperCase();
        if (cleanedCity != a.City) {
            a.City = cleanedCity;
            changed = true;
        }
    }

    // NORMALIZAR COUNTRY
    if (a.Country != null && a.Country != 'PR') {
        a.Country = 'PR';
        changed = true;
    }

    if (changed) updCpas.add(a);
}

if (!updCpas.isEmpty()) {
    update updCpas;
    System.debug(LoggingLevel.INFO,' \u2192 CPAs actualizados: ' + updCpas.size());
}

/*
// ===============================
// 3️⃣ CHARGENT ORDER
// ===============================

List<ChargentOrders__ChargentOrder__c> chg = [
    SELECT Id, ChargentOrders__Billing_Address__c, ChargentOrders__Billing_City__c, ChargentOrders__Billing_Country__c
    FROM ChargentOrders__ChargentOrder__c
    WHERE 
        ChargentOrders__Billing_Address__c LIKE '%\n%'
        OR ChargentOrders__Billing_Address__c LIKE '%\r%'
        OR ChargentOrders__Billing_Address__c LIKE '%\r\n%'
        OR ChargentOrders__Billing_Address__c LIKE '%\t%'

        OR (ChargentOrders__Billing_City__c= 'San Juan' AND (ChargentOrders__Billing_Country__c!= 'PR' OR ChargentOrders__Billing_Country__c= null))
        OR (ChargentOrders__Billing_City__c= 'SAN JUAN' AND (ChargentOrders__Billing_Country__c!= 'PR' OR ChargentOrders__Billing_Country__c= null))
        OR (ChargentOrders__Billing_City__c= 'Puerto Rico' AND (ChargentOrders__Billing_Country__c!= 'PR' OR ChargentOrders__Billing_Country__c= null))
        OR (ChargentOrders__Billing_City__c= 'PUERTO RICO' AND (ChargentOrders__Billing_Country__c!= 'PR' OR ChargentOrders__Billing_Country__c= null))

  
];

System.debug(LoggingLevel.INFO,' \u2192 Orders TC encontrados: ' + chg.size());

List<ChargentOrders__ChargentOrder__c> updChg = new List<ChargentOrders__ChargentOrder__c>();

for (ChargentOrders__ChargentOrder__c o : chg) {

    Boolean changed = false;

    if (o.ChargentOrders__Billing_Address__c != null) {
        String cleaned = o.ChargentOrders__Billing_Address__c;
        cleaned = cleaned.replace('\n',' ').replace('\r',' ').replace('\r\n',' ').replace('\t',' ');
        cleaned = cleaned.replaceAll('[\\u000B\\u000C\\u0085]',' ');
        cleaned = cleaned.trim().toUpperCase();
        if (cleaned != o.ChargentOrders__Billing_Address__c) { o.ChargentOrders__Billing_Address__c = cleaned; changed = true; }
    }

    if (o.ChargentOrders__Billing_City__c != null) {
        String cleanedCity = o.ChargentOrders__Billing_City__c.trim().toUpperCase();
        if (cleanedCity != o.ChargentOrders__Billing_City__c) { o.ChargentOrders__Billing_City__c = cleanedCity; changed = true; }
    }

    if (o.ChargentOrders__Billing_Country__c != null && o.ChargentOrders__Billing_Country__c != 'PR') {
        o.ChargentOrders__Billing_Country__c = 'PR';
        changed = true;
    }

    if (changed) updChg.add(o);
}

if (!updChg.isEmpty()) update updChg;
System.debug(LoggingLevel.INFO,' \u2192 Orders TC actualizados: ' + updChg.size());

*/
System.debug(LoggingLevel.INFO,' \u2192 PROCESO COMPLETADO');