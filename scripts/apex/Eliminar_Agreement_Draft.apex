DateTime dayStart = System.now().addHours(-24);
DateTime dayEnd = System.now();

// Paso 1: Obtener acuerdos creados en las últimas 24 horas con estado relevante
List<echosign_dev1__SIGN_Agreement__c> agreements = [
    SELECT Id, Name, echosign_dev1__Status__c
    FROM echosign_dev1__SIGN_Agreement__c
    WHERE CreatedDate >= :dayStart AND CreatedDate <= :dayEnd
    AND echosign_dev1__Status__c IN ('DRAFT', 'Out for Signature', 'Signed')
];

// Paso 2: Agrupar por Name
Map<String, List<echosign_dev1__SIGN_Agreement__c>> groupedByName = new Map<String, List<echosign_dev1__SIGN_Agreement__c>>();
for (echosign_dev1__SIGN_Agreement__c a : agreements) {
    String nameKey = a.Name;
    if (!groupedByName.containsKey(nameKey)) {
        groupedByName.put(nameKey, new List<echosign_dev1__SIGN_Agreement__c>());
    }
    groupedByName.get(nameKey).add(a);
}

// Paso 3: Filtrar los DRAFT que tienen respaldo
List<echosign_dev1__SIGN_Agreement__c> draftToDelete = new List<echosign_dev1__SIGN_Agreement__c>();
for (String nameKey : groupedByName.keySet()) {
    Boolean hasRelevantStatus = false;
    for (echosign_dev1__SIGN_Agreement__c a : groupedByName.get(nameKey)) {
        if (a.echosign_dev1__Status__c == 'Out for Signature' || a.echosign_dev1__Status__c == 'Signed') {
            hasRelevantStatus = true;
            break;
        }
    }
    if (hasRelevantStatus) {
        for (echosign_dev1__SIGN_Agreement__c a : groupedByName.get(nameKey)) {
            if (a.echosign_dev1__Status__c == 'DRAFT') {
                draftToDelete.add(a);
            }
        }
    }
}

// Paso 4: Eliminar y mostrar los IDs
if (draftToDelete.isEmpty()) {
    System.debug(' →🔍 No se encontraron acuerdos en DRAFT con respaldo en otro estado.');
} else {
   delete draftToDelete;
    List<Id> deletedIds = new List<Id>();
    for (echosign_dev1__SIGN_Agreement__c a : draftToDelete) {
        deletedIds.add(a.Id);
    }
    System.debug(' →🗑️ Acuerdos eliminados (DRAFT): ' + String.join(deletedIds, ','));
}
