
// ⚠️ VALIDACIÓN DE SEGURIDAD: VERIFICAR QUE ESTAMOS EN SANDBOX
Organization org = [SELECT Id, Name, IsSandbox, InstanceName FROM Organization LIMIT 1];
if (!org.IsSandbox) {
    throw new IllegalArgumentException(
        '🚨 ERROR DE SEGURIDAD: Este script solo puede ejecutarse en SANDBOX.\n' +
        'Org actual: ' + org.Name + ' (Producción)\n' +
        'Por favor ejecuta este script únicamente en un entorno sandbox.'
    );
}
System.debug(' → ✅ Validación exitosa: Ejecutando en SANDBOX (' + org.InstanceName + ')');
System.debug(' → Org: ' + org.Name);

// 1️⃣ CREAR ACCOUNT
// ⚠️ PERSON ACCOUNT detectada - Usando campos FirstName/LastName
// IMPORTANTE: Debes tener el RecordType de Person Account habilitado en tu sandbox

Account acc = new Account(
    FirstName = 'Roberto',
    LastName = 'Concepcion (SANDBOX)',
    PersonEmail  = 'testsandbox@yopmail.com',
    BillingStreet = '',
    BillingCity = '',
    BillingState = '',
    BillingPostalCode = '',
    BillingCountry = ''
);
insert acc;
System.debug(' → ✅ Person Account creada: ' + acc.Id);

// Actualizar campos personalizados de Person Account
acc = [SELECT Id FROM Account WHERE Id = :acc.Id];
acc.SM_SSN__pc = '583458017';
acc.SM_SSN_Last_4__pc = '8017';
update acc;
System.debug(' → ✅ Campos personalizados Person Account actualizados');

// 2️⃣ CREAR BILLING ADDRESS
ContactPointAddress billAddr = new ContactPointAddress(
    Name = 'CALLE DEL BREY 276 VILLA PALMERA SAN JUAN, PR 00912 PR',
    ParentId = acc.Id,
    SM_Type__c = 'Billing Address',
    Street = 'CALLE DEL BREY 276 VILLA PALMERA',
    City = 'SAN JUAN',
    State = 'PR',
    PostalCode = '00912',
    Country = 'PR'
);
insert billAddr;
System.debug(' → ✅ Billing Address creada: ' + billAddr.Id);

// 2️⃣ CREAR PHYSICAL ADDRESS
ContactPointAddress physicalAddr = new ContactPointAddress(
    Name = 'CALLE DEL BREY 276 VILLA PALMERA SAN JUAN, PR 00912 PR',
    ParentId = acc.Id,
    SM_Type__c = 'Physical Address',
    Street = 'CALLE DEL BREY 276 VILLA PALMERA',
    City = 'SAN JUAN',
    State = 'PR',
    PostalCode = '00912',
    Country = 'PR'
);
insert physicalAddr;
System.debug(' → ✅ Physical Address creada: ' + physicalAddr.Id);

// 2️⃣ CREAR POSTAL ADDRESS
ContactPointAddress postalAddr = new ContactPointAddress(
    Name = 'CALLE DEL BREY 276 VILLA PALMERA SAN JUAN, PR 00912 PR',
    ParentId = acc.Id,
    SM_Type__c = 'Postal Address',
    Street = 'CALLE DEL BREY 276 VILLA PALMERA',
    City = 'SAN JUAN',
    State = 'PR',
    PostalCode = '00912',
    Country = 'PR'
);
insert postalAddr;
System.debug(' → ✅ Postal Address creada: ' + postalAddr.Id);

// 3️⃣ CREAR PAYMENT METHODS
List<SM_Payment_Method__c> pms = new List<SM_Payment_Method__c>();

// PM 1: PM-204968
SM_Payment_Method__c pm1 = new SM_Payment_Method__c(
    RecordTypeId = '0121U000000KY46QAG',
    SM_Account__c = acc.Id,
    SM_Active__c = true,
    SM_Card_Token__c = 'tok_sandbox_1_1034',
    SM_Credit_Card_Number__c = '****1034',
    SM_Credit_Card_expiration_month__c = '10',
    SM_Credit_Card_expiration_year__c = '2028'
);
pms.add(pm1);

// PM 2: PM-203626
SM_Payment_Method__c pm2 = new SM_Payment_Method__c(
    RecordTypeId = '0121U000000KY46QAG',
    SM_Account__c = acc.Id,
    SM_Active__c = true,
    SM_Card_Token__c = 'tok_sandbox_2_7435',
    SM_Credit_Card_Number__c = '****7435',
    SM_Credit_Card_expiration_month__c = '11',
    SM_Credit_Card_expiration_year__c = '2030'
);
pms.add(pm2);

insert pms;
System.debug(' → ✅ Payment Methods creados: ' + pms.size());

// 4️⃣ CREAR CONTRATO
Contract con = new Contract(
    Status = 'Draft',
    AccountId = acc.Id,
    StartDate = Date.valueOf('2026-01-09'),
    OwnerId = UserInfo.getUserId(),
    RecordTypeId = '0121U00000085thQAA',
    BillingCity = billAddr.City,
    SM_Billing_Address__c = billAddr.Id,
    SM_Physical_address__c = billAddr.Id,
    SM_Postal_address__c = billAddr.Id,
    SM_Payment_Method__c = pms[0].Id,
    SM_Payment_methods__c = 'Credit Card',
    SM_Registered_Card_Token__c = pms[0].SM_Card_Token__c,
    SM_Requires_AC_Payment__c = true,
    SM_Way_of_AC_Payment__c = 'One payment',
    SM_AC_start_date__c = Date.valueOf('2026-01-09'),
    SM_Total_ac__c = 119.00,
    SM_Requires_RC_Payment__c = true,
    SM_Way_of_Contract_Payment__c = 'Subscription',
    SM_Start_date__c = Date.valueOf('2026-02-14'),
    SM_Payment_day__c = 14,
    SM_Frecuency__c = 'Monthly',
    SM_Plan_Months__c = 75,
    SM_Monthly_offer__c = 75.00,
    Description = 'Contrato de prueba - Migrado de PROD 00316311'
);
insert con;
System.debug(' → ✅ Contrato creado: ' + con.Id);

// Activar contrato
con.Status = 'Activated';
update con;
System.debug(' → ✅ Contrato activado');

// 5️⃣ CREAR CHARGENT ORDERS
List<ChargentOrders__ChargentOrder__c> orders = new List<ChargentOrders__ChargentOrder__c>();

// Order 1
ChargentOrders__ChargentOrder__c ord1 = new ChargentOrders__ChargentOrder__c(
    Contract__c = con.Id,
    ChargentOrders__Payment_Method__c = pms[0].Id,
    ChargentOrders__Payment_Status__c = 'Recurring',
    ChargentOrders__Billing_Country__c = 'PR',
    ChargentOrders__Tokenization__c = pms[0].SM_Card_Token__c,
    ChargentOrders__Card_Last_4__c = '1034',
    ChargentOrders__Card_Number__c = '1034',
    ChargentOrders__Card_Expiration_Month__c = '10',
    ChargentOrders__Card_Expiration_Year__c = '2028',
    ChargentOrders__Card_Month_Indicator__c = '10',
    ChargentOrders__Card_Year_Indicator__c = '2028',
    ChargentOrders__Charge_Amount__c = 75.00,
    ChargentOrders__Payment_Start_Date__c = Date.valueOf('2026-06-12'),
    ChargentOrders__Charge_Date__c = '12'
);
orders.add(ord1);

insert orders;
System.debug(' → ✅ Chargent Orders creados: ' + orders.size());

// ✅ MIGRACIÓN COMPLETADA
// Re-consultar Account para obtener Name
acc = [SELECT Id, Name FROM Account WHERE Id = :acc.Id];
con = [SELECT Id, ContractNumber FROM Contract WHERE Id = :con.Id];

System.debug(' → \n========================================');
System.debug(' → MIGRACIÓN COMPLETADA EXITOSAMENTE');
System.debug(' → Account: ' + acc.Id + ' - ' + acc.Name);
System.debug(' → Contrato: ' + con.Id + ' - Número: ' + con.ContractNumber);
System.debug(' → Payment Methods: ' + pms.size());
System.debug(' → Chargent Orders: ' + orders.size());
System.debug(' → ========================================');
