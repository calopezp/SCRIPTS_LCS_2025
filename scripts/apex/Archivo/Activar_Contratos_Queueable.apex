List<String> contratos = new List<String>{
    '00316809',
    '00316832',
    '00316833',
    '00316839'
};

for (String c : contratos) {
    System.enqueueJob(new ActivateContractFullQueueable(c));
}
