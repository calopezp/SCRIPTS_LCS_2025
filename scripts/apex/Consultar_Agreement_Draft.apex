DateTime dayStart = System.now().addHours(-24);
DateTime dayEnd = System.now();
//WHERE CreatedDate >= :dayStart AND CreatedDate <= :dayEnd
//Date today = Date.today();

// Paso 1: Obtener contratos creados hoy
List<Contract> contracts = [
    SELECT Id, Name
    FROM Contract
    WHERE CreatedDate >= :dayStart AND CreatedDate <= :dayEnd
    AND Status in ('Complete Information', 'Payment Process', 'Activated')
];

// Paso 2: Obtener acuerdos relacionados solo con esos contratos
Set<Id> contractIds = new Set<Id>();
for (Contract c : contracts) {
    contractIds.add(c.Id);
}

Set<Id> contractsWithAgreements = new Set<Id>();
if (!contractIds.isEmpty()) {
    List<echosign_dev1__SIGN_Agreement__c> agreements = [
        SELECT Id, echosign_dev1__Contract__c
        FROM echosign_dev1__SIGN_Agreement__c
        WHERE echosign_dev1__Contract__c IN :contractIds
    ];
    for (echosign_dev1__SIGN_Agreement__c a : agreements) {
        contractsWithAgreements.add(a.echosign_dev1__Contract__c);
    }
}

// Paso 3: Filtrar contratos sin acuerdos
List<Contract> contractsWithoutAgreements = new List<Contract>();
for (Contract c : contracts) {
    if (!contractsWithAgreements.contains(c.Id)) {
        contractsWithoutAgreements.add(c);
    }
}

// Paso 4: Mostrar resultados
if (contractsWithoutAgreements.isEmpty()) {
    System.debug('→✅ Todos los contratos creados hoy tienen al menos un acuerdo.');
} else {
    System.debug('→ 🔍 Contratos creados hoy sin acuerdos:');
    for (Contract c : contractsWithoutAgreements) {
        System.debug('→ Id: ' + c.Id + ' | Name: ' + c.Name);
    }
}
