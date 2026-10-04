/*
******************************************************************************************
*  PARTE 3 (EXCEPCIÓN MUY ESPECIAL) — REVERTIR UN CARGUE ACH YA CONFIRMADO
*  Creado 2026-10-02.
*
*  Cuándo usarlo: solo cuando "-B.ConfirmarCargueACH.apex" ya marcó un lote como
*  ACH TRANSMITTED (creó su SM_Nacha_File__c + SM_TransactionLog__c) pero después se descubre
*  que el archivo en realidad NUNCA llegó al banco (error humano -- se olvidó enviar -- o
*  técnico). Esto NO es parte del flujo normal, es la excepción que revierte un "se asumió
*  transmitido pero no fue así".
*
*  Qué hace, para TODOS los Payments ligados a un SM_Nacha_File__c dado:
*    1. Revierte Payment_Status__c a ACH PENDING / ACH PENDING REFUND (según corresponda).
*    2. Limpia SM_Nacha_File__c, SM_Date_ACH_Transmitted__c, SM_Transmission_Date_ACH_File__c
*       y SM_Payment_Date__c (los mismos campos que "-B" puso).
*    3. Anota en SM_Id_Salesforce_LCS__c vía SM_AutomationLogHelper.appendNote() -- mismo
*       patrón que ya usa el resto del proyecto (CLAUDE.md sección 1), nunca pisa el valor
*       anterior.
*    4. Crea un SM_TransactionLog__c NUEVO por payment (SM_Response__c empieza con
*       "REVERTIDO -- ", SM_StatusCode__c=0, Error_Log__c=<causa>) -- el TransactionLog
*       original que creó "-B" NO se borra, queda como rastro de que sí se intentó confirmar.
*       (Status__c y SM_Success__c son campos fórmula, no escribibles -- probablemente
*       derivados de SM_StatusCode__c=200, por eso se usa SM_Response__c como marcador legible.)
*    5. El SM_Nacha_File__c NO se toca -- decisión explícita del usuario 2026-10-02: ese objeto
*       va a migrar a otro sistema/proceso a futuro, no vale la pena invertir en su schema
*       (SM_Estado__c es picklist restringido Success/Fail, sin valor "Revertido" ni campo de
*       notas libres).
*
*  DRY_RUN = true por default. Llenar NACHA_ID_A_REVERTIR y CAUSA abajo antes de correr.
******************************************************************************************/

Boolean DRY_RUN = true;

String nachaIdARevertir = 'PEGAR_AQUI_EL_NACHA_ID'; // ej: 'a2HUU000003GK5t2AG' -- String, no Id, para poder dejar el placeholder sin que explote antes del guard de abajo
String causa = 'PEGAR_AQUI_LA_CAUSA'; // ej: 'Archivo nunca se transmitio al banco -- error humano, nadie lo envio'

Id ownerId         = '0051U000001MRFeQAO';
Id logRecordTypeId = '0121U000000KY48QAG';
String processName = 'ConfirmarCargueACH_Rollback';

if (String.isBlank(nachaIdARevertir) || nachaIdARevertir == 'PEGAR_AQUI_EL_NACHA_ID') {
    System.debug('→ Falta poner el Nacha Id a revertir (NACHA_ID_A_REVERTIR). Script detenido.');
    return;
}
if (String.isBlank(causa) || causa == 'PEGAR_AQUI_LA_CAUSA') {
    System.debug('→ Falta poner la causa de la reversión (CAUSA). Script detenido.');
    return;
}


// =========================================================================================
// 1️⃣ BUSCAR TODOS LOS PAYMENTS LIGADOS A ESE NACHA
// =========================================================================================

List<SM_Payment__c> pagos = [
    SELECT Id, Name, Payment_Status__c, SM_Id_Salesforce_LCS__c
    FROM   SM_Payment__c
    WHERE  SM_Nacha_File__c = :nachaIdARevertir
];

if (pagos.isEmpty()) {
    System.debug('→ No se encontraron payments ligados al Nacha ' + nachaIdARevertir + '. Nada que revertir.');
    return;
}

System.debug('→ ' + pagos.size() + ' payment(s) ligados a Nacha ' + nachaIdARevertir + ' -- causa: ' + causa);
for (SM_Payment__c p : pagos) {
    System.debug('   ' + p.Name + ' (status actual: ' + p.Payment_Status__c + ')');
}

if (DRY_RUN) {
    System.debug('(DRY RUN) No se escribió nada. Cambiar DRY_RUN a false para aplicar de verdad.');
    return;
}


// =========================================================================================
// 2️⃣ REVERTIR: Payment a ACH PENDING/REFUND + limpiar campos de transmisión + anotar +
// TransactionLog nuevo marcado REVERTIDO (no se toca el Nacha ni se borra el log original)
// =========================================================================================

List<SM_TransactionLog__c> logsBatch = new List<SM_TransactionLog__c>();
List<SM_Payment__c> updBatch        = new List<SM_Payment__c>();

for (Integer i = 0; i < pagos.size(); i++) {

    SM_Payment__c p = pagos[i];
    Boolean esRefund = p.Payment_Status__c != null && p.Payment_Status__c.containsIgnoreCase('REFUND');

    updBatch.add(new SM_Payment__c(
        Id                                = p.Id,
        Payment_Status__c                 = esRefund ? 'ACH PENDING REFUND' : 'ACH PENDING',
        SM_Nacha_File__c                  = null,
        SM_Date_ACH_Transmitted__c        = null,
        SM_Transmission_Date_ACH_File__c  = null,
        SM_Payment_Date__c                = null,
        SM_Id_Salesforce_LCS__c           = SM_AutomationLogHelper.appendNote(
                                                 p.SM_Id_Salesforce_LCS__c,
                                                 processName,
                                                 'Revertido a ACH PENDING (' + causa + ')'
                                             )
    ));

    logsBatch.add(new SM_TransactionLog__c(
        OwnerId          = ownerId,
        RecordTypeId     = logRecordTypeId,
        SM_StatusCode__c = 0,
        Error_Log__c     = causa,
        Process_Name__c  = processName,
        SM_Response__c   = 'REVERTIDO -- ' + causa,
        Payment__c       = p.Id
    ));

    if (logsBatch.size() == 100 || i == pagos.size() - 1) {
        update updBatch;
        insert logsBatch;
        updBatch.clear();
        logsBatch.clear();
    }
}

System.debug('→ Revertido: ' + pagos.size() + ' payment(s) vueltos a ACH PENDING/REFUND. Nacha ' +
             nachaIdARevertir + ' sin tocar (queda como rastro de que sí se intentó transmitir).');
