DateTime dayStart = System.now().addHours(-124);
DateTime dayEnd = System.now();

// Paso 1: Obtener acuerdos creados en el periodo con su contrato relacionado
List<echosign_dev1__SIGN_Agreement__c> agreements = [
    SELECT Id, OwnerId, echosign_dev1__Contract__c
    FROM echosign_dev1__SIGN_Agreement__c
    WHERE CreatedDate >= :dayStart AND CreatedDate <= :dayEnd
    AND echosign_dev1__Contract__c != null
];

// Paso 2: Obtener los contratos relacionados con sus OwnerId
Set<Id> contractIds = new Set<Id>();
for (echosign_dev1__SIGN_Agreement__c a : agreements) {
    contractIds.add(a.echosign_dev1__Contract__c);
}

Map<Id, Contract> contractMap = new Map<Id, Contract>();
if (!contractIds.isEmpty()) {
    for (Contract c : [
        SELECT Id, OwnerId
        FROM Contract
        WHERE Id IN :contractIds
    ]) {
        contractMap.put(c.Id, c);
    }
}

// Paso 3: Actualizar OwnerId de los acuerdos
List<echosign_dev1__SIGN_Agreement__c> agreementsToUpdate = new List<echosign_dev1__SIGN_Agreement__c>();
for (echosign_dev1__SIGN_Agreement__c a : agreements) {
    Id contractId = a.echosign_dev1__Contract__c;
    if (contractMap.containsKey(contractId)) {
        Id contractOwner = contractMap.get(contractId).OwnerId;
        if (a.OwnerId != contractOwner) {
            a.OwnerId = contractOwner;
            agreementsToUpdate.add(a);
        }
    }
}

// Paso 4: Guardar cambios
if (!agreementsToUpdate.isEmpty()) {
    update agreementsToUpdate;
    System.debug('→ ✅ Se actualizaron los siguientes acuerdos con nuevo Owner:');
    for (echosign_dev1__SIGN_Agreement__c a : agreementsToUpdate) {
        System.debug('→ ✅ Agreement Id: ' + a.Id + ' → Nuevo OwnerId: ' + a.OwnerId);
    }
} else {
    System.debug('→ ℹ️ No se encontraron acuerdos que requieran cambio de Owner.');
}
