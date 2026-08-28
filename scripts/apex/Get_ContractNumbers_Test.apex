List<Contract> cons = [
    SELECT Id, ContractNumber, Status
    FROM Contract
    WHERE Id IN ('800VB00000hncRZYAY','800VB00000hncRaYAI','800VB00000hncRbYAI')
];
for (Contract c : cons) {
    System.debug(' -> ' + c.Id + ' | ContractNumber=' + c.ContractNumber + ' | Status=' + c.Status);
}
