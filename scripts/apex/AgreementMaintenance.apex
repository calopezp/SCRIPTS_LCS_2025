DateTime dayStart = DateTime.valueOf('2026-07-01 00:00:00'); //System.now().addHours(-96);
DateTime dayEnd = System.now();

// 🔹 TAREA 1: Eliminar acuerdos en Draft si hay respaldo firmado o en proceso, mismo Name y mismo día de creación

List<echosign_dev1__SIGN_Agreement__c> recentAgreements = [
    SELECT Id, Name, echosign_dev1__Status__c, CreatedDate
    FROM echosign_dev1__SIGN_Agreement__c
    WHERE CreatedDate >= :dayStart AND CreatedDate <= :dayEnd
    AND echosign_dev1__Status__c IN ('Draft', 'Out for Signature', 'Signed')
];

Map<String, List<echosign_dev1__SIGN_Agreement__c>> groupedByNameAndDate = new Map<String, List<echosign_dev1__SIGN_Agreement__c>>();
for (echosign_dev1__SIGN_Agreement__c a : recentAgreements) {
    String groupKey = a.Name + '|' + a.CreatedDate.date();
    if (!groupedByNameAndDate.containsKey(groupKey)) {
        groupedByNameAndDate.put(groupKey, new List<echosign_dev1__SIGN_Agreement__c>());
    }
    groupedByNameAndDate.get(groupKey).add(a);
}

List<echosign_dev1__SIGN_Agreement__c> draftToDelete = new List<echosign_dev1__SIGN_Agreement__c>();
for (String groupKey : groupedByNameAndDate.keySet()) {
    Boolean hasRelevantStatus = false;
    for (echosign_dev1__SIGN_Agreement__c a : groupedByNameAndDate.get(groupKey)) {
        if (a.echosign_dev1__Status__c == 'Out for Signature' || a.echosign_dev1__Status__c == 'Signed') {
            hasRelevantStatus = true;
            break;
        }
    }
    if (hasRelevantStatus) {
        for (echosign_dev1__SIGN_Agreement__c a : groupedByNameAndDate.get(groupKey)) {
            if (a.echosign_dev1__Status__c == 'Draft') {
                draftToDelete.add(a);
            }
        }
    }
}

if (!draftToDelete.isEmpty()) {
    delete draftToDelete;
    List<Id> deletedIds = new List<Id>();
    for (echosign_dev1__SIGN_Agreement__c a : draftToDelete) {
        deletedIds.add(a.Id);
    }
    System.debug('\u2192 🗑️ Acuerdos eliminados (Draft): ' + String.join(deletedIds, ','));
} else {
    System.debug('\u2192 🔍 No se encontraron acuerdos en Draft con respaldo (mismo Name y dia) en otro estado.');
}

// 🔹 TAREA 2: Reasignar Owner de acuerdos creados en el periodo si están a nombre de "clopez"

List<echosign_dev1__SIGN_Agreement__c> agreementsToReassign = [
    SELECT Id, OwnerId, echosign_dev1__Contract__c
    FROM echosign_dev1__SIGN_Agreement__c
    WHERE OwnerId = '0051U000007bbx5QAA' // ID de clopez
    //AND CreatedDate >= :dayStart AND CreatedDate <= :dayEnd
];

Set<Id> relatedContractIds = new Set<Id>();
for (echosign_dev1__SIGN_Agreement__c a : agreementsToReassign) {
    relatedContractIds.add(a.echosign_dev1__Contract__c);
}

Map<Id, Contract> contractMap = new Map<Id, Contract>();
if (!relatedContractIds.isEmpty()) {
    for (Contract c : [
        SELECT Id, OwnerId
        FROM Contract
        WHERE Id IN :relatedContractIds
    ]) {
        contractMap.put(c.Id, c);
    }
}

List<echosign_dev1__SIGN_Agreement__c> agreementsToUpdate = new List<echosign_dev1__SIGN_Agreement__c>();
for (echosign_dev1__SIGN_Agreement__c a : agreementsToReassign) {
    Id contractId = a.echosign_dev1__Contract__c;
    if (contractMap.containsKey(contractId)) {
        Id contractOwner = contractMap.get(contractId).OwnerId;
        if (a.OwnerId != contractOwner) {
            a.OwnerId = contractOwner;
            agreementsToUpdate.add(a);
        }
    }
}

if (!agreementsToUpdate.isEmpty()) {
    update agreementsToUpdate;
    System.debug('\u2192 ✅ Se actualizaron los siguientes acuerdos con nuevo Owner:');
    for (echosign_dev1__SIGN_Agreement__c a : agreementsToUpdate) {
        System.debug('Agreement Id: ' + a.Id + ' \u2192 Nuevo OwnerId: ' + a.OwnerId);
    }
} else {
    System.debug('\u2192 ℹ️ No se encontraron acuerdos que requieran cambio de Owner.');
}

// 🔹 TAREA 3: Listar contratos creados en el periodo que no tienen acuerdos

List<Contract> recentContracts = [
    SELECT Id, Name
    FROM Contract
    WHERE Status IN ('Complete Information', 'Payment Process', 'Activated')
    AND CreatedDate >= :dayStart AND CreatedDate <= :dayEnd
];

Set<Id> contractIds = new Set<Id>();
for (Contract c : recentContracts) {
    contractIds.add(c.Id);
}

Set<Id> contractsWithAgreements = new Set<Id>();
if (!contractIds.isEmpty()) {
    List<echosign_dev1__SIGN_Agreement__c> agreementsLinked = [
        SELECT Id, echosign_dev1__Contract__c
        FROM echosign_dev1__SIGN_Agreement__c
        WHERE echosign_dev1__Contract__c IN :contractIds
    ];
    for (echosign_dev1__SIGN_Agreement__c a : agreementsLinked) {
        contractsWithAgreements.add(a.echosign_dev1__Contract__c);
    }
}

List<Contract> contractsWithoutAgreements = new List<Contract>();
for (Contract c : recentContracts) {
    if (!contractsWithAgreements.contains(c.Id)) {
        contractsWithoutAgreements.add(c);
    }
}

if (!contractsWithoutAgreements.isEmpty()) {
    System.debug('\u2192 🔍 Contratos creados en las últimas 24h sin acuerdos:');
    for (Contract c : contractsWithoutAgreements) {
        System.debug('Id: ' + c.Id + ' | Name: ' + c.Name);
    }
} else {
    System.debug('\u2192 ✅ Todos los contratos creados en las últimas 24h tienen al menos un acuerdo.');
}
