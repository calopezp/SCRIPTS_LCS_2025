String contratoNumber = '00316548';

// 1. Obtener el contrato por ContractNumber
List<Contract> contratos = [
    SELECT Id, ContractNumber, AccountId,
           SM_Billing_Address__c,
           SM_Physical_Address__c,
           SM_Postal_Address__c
    FROM Contract
    WHERE ContractNumber = :contratoNumber
    LIMIT 1
];

if (contratos.isEmpty()) {
    System.debug('No se encontró el contrato con número: ' + contratoNumber);
    return;
}

Contract c = contratos[0];

// Validación de AccountId
if (c.AccountId == null) {
    System.debug('El contrato no tiene AccountId asociado');
    return;
}

// 2. Obtener los ContactPointAddress del Account del contrato
List<ContactPointAddress> cpas = [
    SELECT Id, Name, SM_Type__c, LastModifiedDate
    FROM ContactPointAddress
    WHERE ParentId = :c.AccountId
    ORDER BY LastModifiedDate DESC
];

if (cpas.isEmpty()) {
    System.debug('No existen ContactPointAddress para el Account del contrato');
    return;
}

// Variables para almacenar el último registro por tipo
ContactPointAddress lastBilling;
ContactPointAddress lastPhysical;
ContactPointAddress lastPostal;

// 3. Clasificar por tipo, tomando el último modificado
for (ContactPointAddress cpa : cpas) {
    String tipo = cpa.SM_Type__c != null ? cpa.SM_Type__c.trim() : '';

    if (tipo.equalsIgnoreCase('Billing Address') && lastBilling == null) {
        lastBilling = cpa;
    }
    else if (tipo.equalsIgnoreCase('Physical Address') && lastPhysical == null) {
        lastPhysical = cpa;
    }
    else if (tipo.equalsIgnoreCase('Postal Address') && lastPostal == null) {
        lastPostal = cpa;
    }

    // Si ya tenemos los 3, no seguimos iterando
    if (lastBilling != null && lastPhysical != null && lastPostal != null) {
        break;
    }
}

// 4. Actualizar el contrato con los valores encontrados
Boolean huboCambios = false;

if (lastBilling != null && c.SM_Billing_Address__c != lastBilling.Id) {
    c.SM_Billing_Address__c = lastBilling.Id;
    huboCambios = true;
}

if (lastPhysical != null && c.SM_Physical_Address__c != lastPhysical.Id) {
    c.SM_Physical_Address__c = lastPhysical.Id;
    huboCambios = true;
}

if (lastPostal != null && c.SM_Postal_Address__c != lastPostal.Id) {
    c.SM_Postal_Address__c = lastPostal.Id;
    huboCambios = true;
}

// 5. Guardar cambios solo si hubo modificaciones
if (huboCambios) {
    update c;
    System.debug('Contrato actualizado correctamente: ' + c.Id);
} else {
    System.debug('No hubo cambios que actualizar en el contrato.');
}