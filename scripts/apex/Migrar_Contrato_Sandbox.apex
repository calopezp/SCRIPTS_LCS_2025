/*
 * SCRIPT: Migrar Contrato Completo a Sandbox
 * Objetivo: Extraer y crear en sandbox el contrato 00316311 con todos sus datos relacionados
 * Fecha: 2026-05-18
 * Autor: Carlos Lopez
 * 
 * INSTRUCCIONES:
 * 1. Ejecutar PARTE 1 en PRODUCCIÓN para extraer datos
 * 2. Copiar el output generado
 * 3. Ejecutar PARTE 2 en SANDBOX con los datos extraídos
 */

// ============================================================================
// PARTE 1: EJECUTAR EN PRODUCCIÓN - EXTRAER DATOS
// ============================================================================

String contratoNumero = '00316311';

System.debug(' → ========================================');
System.debug(' → INICIANDO EXTRACCIÓN DE DATOS');
System.debug(' → Contrato: ' + contratoNumero);
System.debug(' → ========================================\n');

// 1️⃣ OBTENER CONTRATO
Contract contrato = [
    SELECT Id, 
           // Contract Information 
           Status, ContractNumber, AccountId, Billing_Contact__c, StartDate, OwnerId,
           RecordTypeId, SM_Process_automation_by_product_family__c,
           // Address Information
           BillingCity,
           SM_Billing_Address__c, SM_Physical_address__c, SM_Postal_address__c,
           // Sign Information
           SM_Agreement_Status__c, SM_Email_to_send_contract__c,
           // AC Information
           SM_Requires_AC_Payment__c, SM_Way_of_AC_Payment__c, SM_AC_start_date__c, 
           SM_AC_Split_Date__c, SM_Total_ac__c,
           // RC Information
           SM_Requires_RC_Payment__c, SM_Start_date__c, SM_Payment_day__c, SM_Frecuency__c, 
           SM_Way_of_Contract_Payment__c, SM_Plan_Months__c, SM_Monthly_offer__c,
           // Payment Profile
           SM_Payment_methods__c, SM_Payment_Method__c, SM_Registered_Card_Token__c,
           Gateway__c, GatewayId__c,
           // Additional
           Description, SpecialTerms
    FROM Contract
    WHERE ContractNumber = :contratoNumero
    LIMIT 1
];

System.debug(' → ✅ Contrato encontrado: ' + contrato.Id);

// 2️⃣ OBTENER ACCOUNT (detectar si es Person Account)
Account cuenta = [
    SELECT Id, Name, IsPersonAccount, RecordTypeId,
           FirstName, LastName, PersonEmail, PersonMobilePhone,
           BillingStreet, BillingCity, BillingState,
           BillingPostalCode, BillingCountry, Phone, Type,
           SM_SSN__pc, SM_SSN_Last_4__pc
    FROM Account
    WHERE Id = :contrato.AccountId
    LIMIT 1
];

System.debug(' → ✅ Account encontrada: ' + cuenta.Name + ' (' + cuenta.Id + ')');
System.debug(' →    Tipo: ' + (cuenta.IsPersonAccount ? 'Person Account' : 'Business Account'));

// 2A️⃣ OBTENER BILLING CONTACT
// IMPORTANTE: Billing_Contact__c es un Lookup a CONTACT, no a Account
// Para Person Accounts, el Billing_Contact__c puede no ser accesible o estar vacío
Contact billingContact = null;
if (contrato.Billing_Contact__c != null) {
    List<Contact> contacts = [
        SELECT Id, FirstName, LastName, Email, Phone, AccountId
        FROM Contact
        WHERE Id = :contrato.Billing_Contact__c
        LIMIT 1
    ];
    
    if (!contacts.isEmpty()) {
        billingContact = contacts[0];
        System.debug(' → ✅ Billing Contact encontrado: ' + billingContact.FirstName + ' ' + billingContact.LastName + ' (' + billingContact.Id + ')');
    } else {
        System.debug(' → ⚠️ Billing_Contact__c está configurado pero el Contact no existe o no es accesible: ' + contrato.Billing_Contact__c);
    }
} else {
    System.debug(' → ⚠️ No hay Billing Contact en el contrato');
}

// 3️⃣ OBTENER BILLING ADDRESS
ContactPointAddress billingAddr = null;
if (contrato.SM_Billing_Address__c != null) {
    billingAddr = [
        SELECT Id, Name, Street, SM_Street_Line_2__c, City, State,
               PostalCode, Country, ParentId
        FROM ContactPointAddress
        WHERE Id = :contrato.SM_Billing_Address__c
        LIMIT 1
    ];
    System.debug(' → ✅ Billing Address encontrada: ' + billingAddr.Name);
}

// 4️⃣ OBTENER PAYMENT METHODS
List<SM_Payment_Method__c> paymentMethods = [
    SELECT Id, Name, SM_Active__c, RecordTypeId, SM_Account__c,
           SM_Card_Token__c, SM_Credit_Card_Number__c,
           SM_Credit_Card_expiration_month__c, SM_Credit_Card_expiration_year__c,
           CreatedDate
    FROM SM_Payment_Method__c
    WHERE SM_Account__c = :cuenta.Id
    ORDER BY CreatedDate DESC
];

System.debug(' → ✅ Payment Methods encontrados: ' + paymentMethods.size());

// 5️⃣ OBTENER CHARGENT ORDERS
List<ChargentOrders__ChargentOrder__c> chargentOrders = [
    SELECT Id, Name, Contract__c, ChargentOrders__Payment_Start_Date__c, ChargentOrders__Charge_Date__c, ChargentOrders__Payment_Method__c,
           ChargentOrders__Payment_Status__c, ChargentOrders__Billing_Country__c,
           ChargentOrders__Tokenization__c, ChargentOrders__Card_Last_4__c,
           ChargentOrders__Card_Expiration_Month__c, ChargentOrders__Card_Expiration_Year__c,
           ChargentOrders__Card_Number__c, ChargentOrders__Card_Month_Indicator__c,
           ChargentOrders__Card_Year_Indicator__c, ChargentOrders__Charge_Amount__c
    FROM ChargentOrders__ChargentOrder__c
    WHERE Contract__c = :contrato.Id
    AND (ChargentOrders__Payment_Status__c = 'Recurring' OR ChargentOrders__Payment_Status__c = 'Stopped')
    ORDER BY CreatedDate
];

System.debug(' → ✅ Chargent Orders encontrados: ' + chargentOrders.size());

// 6️⃣ GENERAR SCRIPT DE CREACIÓN PARA SANDBOX
System.debug(' → \n========================================');
System.debug(' → SCRIPT PARA EJECUTAR EN SANDBOX');
System.debug(' → ========================================\n');

// IMPORTANTE: Los campos encriptados NO se pueden extraer directamente
// Solo podemos crear records con valores de prueba

String sandboxScript = '';

// Account - Diferentes flujos para Person Account vs Business Account
sandboxScript += '\n\n';
sandboxScript += '// ⚠️ VALIDACIÓN DE SEGURIDAD: VERIFICAR QUE ESTAMOS EN SANDBOX\n';
sandboxScript += 'Organization org = [SELECT Id, Name, IsSandbox, InstanceName FROM Organization LIMIT 1];\n';
sandboxScript += 'if (!org.IsSandbox) {\n';
sandboxScript += '    throw new IllegalArgumentException(\n';
sandboxScript += '        \'🚨 ERROR DE SEGURIDAD: Este script solo puede ejecutarse en SANDBOX.\\n\' +\n';
sandboxScript += '        \'Org actual: \' + org.Name + \' (Producción)\\n\' +\n';
sandboxScript += '        \'Por favor ejecuta este script únicamente en un entorno sandbox.\'\n';
sandboxScript += '    );\n';
sandboxScript += '}\n';
sandboxScript += 'System.debug(\' → ✅ Validación exitosa: Ejecutando en SANDBOX (\' + org.InstanceName + \')\');\n';
sandboxScript += 'System.debug(\' → Org: \' + org.Name);\n\n';

sandboxScript += '// 1️⃣ CREAR ACCOUNT\n';

if (cuenta.IsPersonAccount) {
    // PERSON ACCOUNT - Usar RecordType y campos estándar de Person
    sandboxScript += '// ⚠️ PERSON ACCOUNT detectada - Usando campos FirstName/LastName\n';
    sandboxScript += '// IMPORTANTE: Debes tener el RecordType de Person Account habilitado en tu sandbox\n\n';
    
    String firstName = cuenta.FirstName != null ? String.escapeSingleQuotes(cuenta.FirstName) : 'Test';
    String lastName = cuenta.LastName != null ? String.escapeSingleQuotes(cuenta.LastName) : 'Sandbox';
    
    sandboxScript += 'Account acc = new Account(\n';
    sandboxScript += '    FirstName = \'' + firstName + '\',\n';
    sandboxScript += '    LastName = \'' + lastName + ' (SANDBOX)\',\n';
    sandboxScript += '    PersonEmail  = \'testsandbox@yopmail.com\',\n';
    
    if (cuenta.PersonMobilePhone != null) {
        sandboxScript += '    PersonMobilePhone = \'' + cuenta.PersonMobilePhone + '\',\n';
    }
    
    sandboxScript += '    BillingStreet = \'' + String.escapeSingleQuotes(cuenta.BillingStreet != null ? cuenta.BillingStreet : '') + '\',\n';
    sandboxScript += '    BillingCity = \'' + String.escapeSingleQuotes(cuenta.BillingCity != null ? cuenta.BillingCity : '') + '\',\n';
    sandboxScript += '    BillingState = \'' + String.escapeSingleQuotes(cuenta.BillingState != null ? cuenta.BillingState : '') + '\',\n';
    sandboxScript += '    BillingPostalCode = \'' + (cuenta.BillingPostalCode != null ? cuenta.BillingPostalCode : '') + '\',\n';
    sandboxScript += '    BillingCountry = \'' + (cuenta.BillingCountry != null ? cuenta.BillingCountry : '') + '\'\n';
    sandboxScript += ');\n';
    sandboxScript += 'insert acc;\n';
    sandboxScript += 'System.debug(\' → ✅ Person Account creada: \' + acc.Id);\n\n';
    
    // Actualizar campos Person Account personalizados DESPUÉS del insert
    if (cuenta.SM_SSN__pc != null || cuenta.SM_SSN_Last_4__pc != null) {
        sandboxScript += '// Actualizar campos personalizados de Person Account\n';
        sandboxScript += 'acc = [SELECT Id FROM Account WHERE Id = :acc.Id];\n';
        if (cuenta.SM_SSN__pc != null) {
            sandboxScript += 'acc.SM_SSN__pc = \'' + cuenta.SM_SSN__pc + '\';\n';
        }
        if (cuenta.SM_SSN_Last_4__pc != null) {
            sandboxScript += 'acc.SM_SSN_Last_4__pc = \'' + cuenta.SM_SSN_Last_4__pc + '\';\n';
        }
        sandboxScript += 'update acc;\n';
        sandboxScript += 'System.debug(\' → ✅ Campos personalizados Person Account actualizados\');\n\n';
    }
    
} else {
    // BUSINESS ACCOUNT - Flujo estándar
    sandboxScript += '// Business Account\n';
    sandboxScript += 'Account acc = new Account(\n';
    sandboxScript += '    Name = \'' + cuenta.Name + ' (SANDBOX)\',\n';
    sandboxScript += '    BillingStreet = \'' + String.escapeSingleQuotes(cuenta.BillingStreet != null ? cuenta.BillingStreet : '') + '\',\n';
    sandboxScript += '    BillingCity = \'' + String.escapeSingleQuotes(cuenta.BillingCity != null ? cuenta.BillingCity : '') + '\',\n';
    sandboxScript += '    BillingState = \'' + String.escapeSingleQuotes(cuenta.BillingState != null ? cuenta.BillingState : '') + '\',\n';
    sandboxScript += '    BillingPostalCode = \'' + (cuenta.BillingPostalCode != null ? cuenta.BillingPostalCode : '') + '\',\n';
    sandboxScript += '    BillingCountry = \'' + (cuenta.BillingCountry != null ? cuenta.BillingCountry : '') + '\',\n';
    sandboxScript += '    Phone = \'' + (cuenta.Phone != null ? cuenta.Phone : '') + '\',\n';
    sandboxScript += '    Type = \'' + (cuenta.Type != null ? cuenta.Type : 'Other') + '\'\n';
    sandboxScript += ');\n';
    sandboxScript += 'insert acc;\n';
    sandboxScript += 'System.debug(\' → ✅ Business Account creada: \' + acc.Id);\n\n';
}

// Billing Address
if (billingAddr != null) {
    sandboxScript += '// 2️⃣ CREAR BILLING ADDRESS\n';
    sandboxScript += 'ContactPointAddress billAddr = new ContactPointAddress(\n';
    sandboxScript += '    Name = \'' + String.escapeSingleQuotes(billingAddr.Name) + '\',\n';
    sandboxScript += '    ParentId = acc.Id,\n';
    sandboxScript += '    SM_Type__c = \'Billing Address\',\n';
    sandboxScript += '    Street = \'' + String.escapeSingleQuotes(billingAddr.Street != null ? billingAddr.Street : '') + '\',\n';
    sandboxScript += '    City = \'' + String.escapeSingleQuotes(billingAddr.City != null ? billingAddr.City : '') + '\',\n';
    sandboxScript += '    State = \'' + String.escapeSingleQuotes(billingAddr.State != null ? billingAddr.State : '') + '\',\n';
    sandboxScript += '    PostalCode = \'' + (billingAddr.PostalCode != null ? billingAddr.PostalCode : '') + '\',\n';
    sandboxScript += '    Country = \'' + (billingAddr.Country != null ? billingAddr.Country : '') + '\'\n';
    sandboxScript += ');\n';
    sandboxScript += 'insert billAddr;\n';
    sandboxScript += 'System.debug(\' → ✅ Billing Address creada: \' + billAddr.Id);\n\n';
}

// Physical Address
if (billingAddr != null) {
    sandboxScript += '// 2️⃣ CREAR PHYSICAL ADDRESS\n';
    sandboxScript += 'ContactPointAddress physicalAddr = new ContactPointAddress(\n';
    sandboxScript += '    Name = \'' + String.escapeSingleQuotes(billingAddr.Name) + '\',\n';
    sandboxScript += '    ParentId = acc.Id,\n';
    sandboxScript += '    SM_Type__c = \'Physical Address\',\n';
    sandboxScript += '    Street = \'' + String.escapeSingleQuotes(billingAddr.Street != null ? billingAddr.Street : '') + '\',\n';
    sandboxScript += '    City = \'' + String.escapeSingleQuotes(billingAddr.City != null ? billingAddr.City : '') + '\',\n';
    sandboxScript += '    State = \'' + String.escapeSingleQuotes(billingAddr.State != null ? billingAddr.State : '') + '\',\n';
    sandboxScript += '    PostalCode = \'' + (billingAddr.PostalCode != null ? billingAddr.PostalCode : '') + '\',\n';
    sandboxScript += '    Country = \'' + (billingAddr.Country != null ? billingAddr.Country : '') + '\'\n';
    sandboxScript += ');\n';
    sandboxScript += 'insert physicalAddr;\n';
    sandboxScript += 'System.debug(\' → ✅ Physical Address creada: \' + physicalAddr.Id);\n\n';
}

// Postal Address
if (billingAddr != null) {
    sandboxScript += '// 2️⃣ CREAR POSTAL ADDRESS\n';
    sandboxScript += 'ContactPointAddress postalAddr = new ContactPointAddress(\n';
    sandboxScript += '    Name = \'' + String.escapeSingleQuotes(billingAddr.Name) + '\',\n';
    sandboxScript += '    ParentId = acc.Id,\n';
    sandboxScript += '    SM_Type__c = \'Postal Address\',\n';
    sandboxScript += '    Street = \'' + String.escapeSingleQuotes(billingAddr.Street != null ? billingAddr.Street : '') + '\',\n';
    sandboxScript += '    City = \'' + String.escapeSingleQuotes(billingAddr.City != null ? billingAddr.City : '') + '\',\n';
    sandboxScript += '    State = \'' + String.escapeSingleQuotes(billingAddr.State != null ? billingAddr.State : '') + '\',\n';
    sandboxScript += '    PostalCode = \'' + (billingAddr.PostalCode != null ? billingAddr.PostalCode : '') + '\',\n';
    sandboxScript += '    Country = \'' + (billingAddr.Country != null ? billingAddr.Country : '') + '\'\n';
    sandboxScript += ');\n';
    sandboxScript += 'insert postalAddr;\n';
    sandboxScript += 'System.debug(\' → ✅ Postal Address creada: \' + postalAddr.Id);\n\n';
}

// Billing Contact (crear SOLO para Business Accounts, NO para Person Accounts)
// IMPORTANTE: Person Accounts NO permiten Contacts separados
if (!cuenta.IsPersonAccount && (billingContact != null || true)) {
    sandboxScript += '// 2A️⃣ CREAR BILLING CONTACT\n';
    sandboxScript += '// IMPORTANTE: Solo para Business Accounts (Person Accounts no permiten Contacts)\n';
    sandboxScript += 'Contact billingCon = new Contact(\n';
    
    if (billingContact != null) {
        sandboxScript += '    FirstName = \'' + String.escapeSingleQuotes(billingContact.FirstName != null ? billingContact.FirstName : 'Billing') + '\',\n';
        sandboxScript += '    LastName = \'' + String.escapeSingleQuotes(billingContact.LastName != null ? billingContact.LastName : 'Contact') + ' (SANDBOX)\',\n';
        sandboxScript += '    Email = \'billing.sandbox@yopmail.com\',\n';
        if (billingContact.Phone != null) {
            sandboxScript += '    Phone = \'' + billingContact.Phone + '\',\n';
        }
    } else {
        sandboxScript += '    FirstName = \'Billing\',\n';
        sandboxScript += '    LastName = \'Contact (SANDBOX)\',\n';
        sandboxScript += '    Email = \'billing.sandbox@yopmail.com\',\n';
    }
    
    sandboxScript += '    AccountId = acc.Id\n';
    sandboxScript += ');\n';
    sandboxScript += 'insert billingCon;\n';
    sandboxScript += 'System.debug(\' → ✅ Billing Contact creado: \' + billingCon.Id);\n\n';
}

// Payment Methods (con datos de prueba)
sandboxScript += '// 3️⃣ CREAR PAYMENT METHODS\n';
sandboxScript += 'List<SM_Payment_Method__c> pms = new List<SM_Payment_Method__c>();\n\n';

Integer pmCount = 0;
for (SM_Payment_Method__c pm : paymentMethods) {
    pmCount++;
    String last4 = pm.SM_Credit_Card_Number__c != null ? pm.SM_Credit_Card_Number__c.right(4) : '9999';
    
    sandboxScript += '// PM ' + pmCount + ': ' + pm.Name + '\n';
    sandboxScript += 'SM_Payment_Method__c pm' + pmCount + ' = new SM_Payment_Method__c(\n';
    sandboxScript += '    RecordTypeId = \'' + pm.RecordTypeId + '\',\n';
    sandboxScript += '    SM_Account__c = acc.Id,\n';
    sandboxScript += '    SM_Active__c = ' + pm.SM_Active__c + ',\n';
    sandboxScript += '    SM_Card_Token__c = \'tok_sandbox_' + pmCount + '_' + last4 + '\',\n';
    sandboxScript += '    SM_Credit_Card_Number__c = \'****' + last4 + '\',\n';
    sandboxScript += '    SM_Credit_Card_expiration_month__c = \'' + (pm.SM_Credit_Card_expiration_month__c != null ? pm.SM_Credit_Card_expiration_month__c : '12') + '\',\n';
    sandboxScript += '    SM_Credit_Card_expiration_year__c = \'' + (pm.SM_Credit_Card_expiration_year__c != null ? pm.SM_Credit_Card_expiration_year__c : '2027') + '\'\n';
    sandboxScript += ');\n';
    sandboxScript += 'pms.add(pm' + pmCount + ');\n\n';
}

sandboxScript += 'insert pms;\n';
sandboxScript += 'System.debug(\' → ✅ Payment Methods creados: \' + pms.size());\n\n';

// Contract Information
sandboxScript += '// 4️⃣ CREAR CONTRATO\n';
sandboxScript += 'Contract con = new Contract(\n';

sandboxScript += '    Status = \'Draft\',\n';
sandboxScript += '    AccountId = acc.Id,\n';

// Billing_Contact__c SOLO para Business Accounts (Person Accounts NO usan este campo)
if (!cuenta.IsPersonAccount) {
    sandboxScript += '    Billing_Contact__c = billingCon.Id,\n';
}

sandboxScript += '    StartDate = Date.valueOf(\'' + String.valueOf(contrato.StartDate) + '\'),\n';           //Date.today(),\n';
sandboxScript += '    OwnerId = UserInfo.getUserId(),\n';

// RecordType si existe
if (contrato.RecordTypeId != null) {
    sandboxScript += '    RecordTypeId = \'' + contrato.RecordTypeId + '\',\n';
}

// Process Automation si existe
// ⚠️ COMENTADO: Este campo puede no existir o no ser accesible en sandbox
// if (contrato.SM_Process_automation_by_product_family__c != null) {
//     sandboxScript += '    SM_Process_automation_by_product_family__c = \'' + contrato.SM_Process_automation_by_product_family__c + '\',\n';
// }

// Address fields
if (billingAddr != null) {
    sandboxScript += '    BillingCity = billAddr.City,\n';
    sandboxScript += '    SM_Billing_Address__c = billAddr.Id,\n';
    sandboxScript += '    SM_Physical_address__c = billAddr.Id,\n';
    sandboxScript += '    SM_Postal_address__c = billAddr.Id,\n';
}

// Payment fields
if (contrato.SM_Payment_Method__c != null) {
    sandboxScript += '    SM_Payment_Method__c = pms[0].Id,\n';
}
if (contrato.SM_Payment_methods__c != null) {
    sandboxScript += '    SM_Payment_methods__c = \'' + contrato.SM_Payment_methods__c + '\',\n';
}
sandboxScript += '    SM_Registered_Card_Token__c = pms[0].SM_Card_Token__c,\n';

if (contrato.Gateway__c != null) {
    sandboxScript += '    Gateway__c = \'' + contrato.Gateway__c + '\',\n';
}

// AC Payment fields
if (contrato.SM_Requires_AC_Payment__c != null) {
    sandboxScript += '    SM_Requires_AC_Payment__c = ' + contrato.SM_Requires_AC_Payment__c + ',\n';
}
if (contrato.SM_Way_of_AC_Payment__c != null) {
    sandboxScript += '    SM_Way_of_AC_Payment__c = \'' + contrato.SM_Way_of_AC_Payment__c + '\',\n';
}
if (contrato.SM_AC_start_date__c != null) {
    sandboxScript += '    SM_AC_start_date__c = Date.valueOf(\'' + String.valueOf(contrato.SM_AC_start_date__c) + '\'),\n';
}
if (contrato.SM_Total_ac__c != null) {
    sandboxScript += '    SM_Total_ac__c = ' + contrato.SM_Total_ac__c + ',\n';
}

// RC Payment fields
if (contrato.SM_Requires_RC_Payment__c != null) {
    sandboxScript += '    SM_Requires_RC_Payment__c = ' + contrato.SM_Requires_RC_Payment__c + ',\n';
}
if (contrato.SM_Way_of_Contract_Payment__c != null) {
    sandboxScript += '    SM_Way_of_Contract_Payment__c = \'' + contrato.SM_Way_of_Contract_Payment__c + '\',\n';
}
if (contrato.SM_Start_date__c != null) {
    sandboxScript += '    SM_Start_date__c = Date.valueOf(\'' + String.valueOf(contrato.SM_Start_date__c) + '\'),\n';
}
if (contrato.SM_Payment_day__c != null) {
    sandboxScript += '    SM_Payment_day__c = ' + contrato.SM_Payment_day__c + ',\n';
}
if (contrato.SM_Frecuency__c != null) {
    sandboxScript += '    SM_Frecuency__c = \'' + contrato.SM_Frecuency__c + '\',\n';
}
if (contrato.SM_Plan_Months__c != null) {
    sandboxScript += '    SM_Plan_Months__c = ' + contrato.SM_Plan_Months__c + ',\n';
}
if (contrato.SM_Monthly_offer__c != null) {
    sandboxScript += '    SM_Monthly_offer__c = ' + contrato.SM_Monthly_offer__c + ',\n';
}

/*  ⛔ este campo no esta diligenciado en el sandbox, revisar si es necesario mapearlo o dejarlo fuera
// Other fields
if (contrato.SM_Process_automation_by_product_family__c != null) {
    sandboxScript += '    SM_Process_automation_by_product_family__c = ' + contrato.SM_Process_automation_by_product_family__c + ',\n';
}
*/

sandboxScript += '    Description = \'Contrato de prueba - Migrado de PROD ' + contratoNumero + '\'\n';
sandboxScript += ');\n';
sandboxScript += 'insert con;\n';
sandboxScript += 'System.debug(\' → ✅ Contrato creado: \' + con.Id);\n\n';

// Activar contrato
sandboxScript += '// Activar contrato\n';
sandboxScript += 'con.Status = \'Activated\';';
sandboxScript += '\nupdate con;\n';
sandboxScript += 'System.debug(\' → ✅ Contrato activado\');\n\n';

// Chargent Orders
if (chargentOrders.size() > 0) {
    sandboxScript += '// 5️⃣ CREAR CHARGENT ORDERS\n';
    sandboxScript += 'List<ChargentOrders__ChargentOrder__c> orders = new List<ChargentOrders__ChargentOrder__c>();\n\n';
    
    Integer orderCount = 0;
    for (ChargentOrders__ChargentOrder__c order : chargentOrders) {
        orderCount++;
        
        sandboxScript += '// Order ' + orderCount + '\n';
        sandboxScript += 'ChargentOrders__ChargentOrder__c ord' + orderCount + ' = new ChargentOrders__ChargentOrder__c(\n';
        sandboxScript += '    Contract__c = con.Id,\n';
        sandboxScript += '    ChargentOrders__Payment_Method__c = pms[0].Id,\n';
        sandboxScript += '    ChargentOrders__Payment_Status__c = \'' + (order.ChargentOrders__Payment_Status__c != null ? order.ChargentOrders__Payment_Status__c : 'Recurring') + '\',\n';
        sandboxScript += '    ChargentOrders__Billing_Country__c = \'' + (order.ChargentOrders__Billing_Country__c != null ? order.ChargentOrders__Billing_Country__c : 'US') + '\',\n';
        sandboxScript += '    ChargentOrders__Tokenization__c = pms[0].SM_Card_Token__c,\n';
        
        String last4 = order.ChargentOrders__Card_Last_4__c != null ? order.ChargentOrders__Card_Last_4__c : '9999';
        sandboxScript += '    ChargentOrders__Card_Last_4__c = \'' + last4 + '\',\n';
        sandboxScript += '    ChargentOrders__Card_Number__c = \'' + last4 + '\',\n';
        
        String expMonth = order.ChargentOrders__Card_Expiration_Month__c != null ? order.ChargentOrders__Card_Expiration_Month__c : '12';
        String expYear = order.ChargentOrders__Card_Expiration_Year__c != null ? order.ChargentOrders__Card_Expiration_Year__c : '2027';
        
        sandboxScript += '    ChargentOrders__Card_Expiration_Month__c = \'' + expMonth + '\',\n';
        sandboxScript += '    ChargentOrders__Card_Expiration_Year__c = \'' + expYear + '\',\n';
        sandboxScript += '    ChargentOrders__Card_Month_Indicator__c = \'' + expMonth + '\',\n';
        sandboxScript += '    ChargentOrders__Card_Year_Indicator__c = \'' + expYear + '\',\n';
        
        if (order.ChargentOrders__Charge_Amount__c != null) {
            sandboxScript += '    ChargentOrders__Charge_Amount__c = ' + order.ChargentOrders__Charge_Amount__c + ',\n';
        }
        
        sandboxScript += '    ChargentOrders__Payment_Start_Date__c = Date.valueOf(\'' + String.valueOf(order.ChargentOrders__Payment_Start_Date__c) + '\'),\n';
        sandboxScript += '    ChargentOrders__Charge_Date__c = \'' + order.ChargentOrders__Charge_Date__c + '\'\n';
       

        sandboxScript += ');\n';
        sandboxScript += 'orders.add(ord' + orderCount + ');\n\n';
    }
    
    sandboxScript += 'insert orders;\n';
    sandboxScript += 'System.debug(\' → ✅ Chargent Orders creados: \' + orders.size());\n\n';
}

// Final
sandboxScript += '// ✅ MIGRACIÓN COMPLETADA\n';
sandboxScript += '// Re-consultar Account para obtener Name\n';
sandboxScript += 'acc = [SELECT Id, Name FROM Account WHERE Id = :acc.Id];\n';
sandboxScript += 'con = [SELECT Id, ContractNumber FROM Contract WHERE Id = :con.Id];\n\n';
sandboxScript += 'System.debug(\' → \\n========================================\');\n';
sandboxScript += 'System.debug(\' → MIGRACIÓN COMPLETADA EXITOSAMENTE\');\n';
sandboxScript += 'System.debug(\' → Account: \' + acc.Id + \' - \' + acc.Name);\n';
sandboxScript += 'System.debug(\' → Contrato: \' + con.Id + \' - Número: \' + con.ContractNumber);\n';
sandboxScript += 'System.debug(\' → Payment Methods: \' + pms.size());\n';
if (chargentOrders.size() > 0) {
    sandboxScript += 'System.debug(\' → Chargent Orders: \' + orders.size());\n';
}
sandboxScript += 'System.debug(\' → ========================================\');\n';

// Mostrar script completo
System.debug(sandboxScript);

System.debug(' → \n========================================');
System.debug(' → RESUMEN DE EXTRACCIÓN');
System.debug(' → ========================================');
System.debug(' → Account: ' + cuenta.Name + ' (' + (cuenta.IsPersonAccount ? 'Person Account' : 'Business Account') + ')');
System.debug(' → Billing Contact: ' + (billingContact != null ? billingContact.FirstName + ' ' + billingContact.LastName + ' (Contact ID: ' + billingContact.Id + ')' : 'No configurado'));
System.debug(' → Contrato: ' + contrato.ContractNumber);
System.debug(' → Payment Methods: ' + paymentMethods.size());
System.debug(' → Chargent Orders: ' + chargentOrders.size());
System.debug(' → Billing Address: ' + (billingAddr != null ? 'Sí' : 'No'));
System.debug(' → ========================================');
System.debug(' → \n⚠️ IMPORTANTE:');
System.debug(' → 1. Copia el script generado arriba');
System.debug(' → 2. Ejecuta en tu SANDBOX');
System.debug(' → 3. Los datos encriptados se crean con valores de prueba');
System.debug(' → 4. Las últimas 4 dígitos se preservan para testing');
System.debug(' → ========================================\n');