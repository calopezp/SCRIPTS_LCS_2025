// ====== BLOQUE DE EJECUCIÓN ======
// Reemplaza por tus ContractNumbers separados por coma (ej: 'C-0001,C-0002,C-0003')

//*  OPCION 1 :: 'Does not comply with Payments';
String INPUT_CONTRACT_CONCAT = 
//06 Mar
'00289937, 00311887, 00309564, 00312251, 00312270, 00312669, 00312713, 00312868, 00313112, 00313178, 00313229, 00313496, 00313658, 00313857, 00313892, 00314055, 00314074, 00314241, 00314281, 00314289, 00314302, 00314324, 00314329, 00314333, 00314343, 00314346, 00314356, 00314378, 00314405, 00314409, 00314421, 00314423, 00314477, 00314485, 00314488, 00314515, 00314517, 00314540, 00314544, 00314602, 00314609, 00314637, 00314657, 00314685, 00314708, 00314709, 00314710, 00314716, 00314721, 00314728, 00314731, 00314777, 00314788, 00314805, 00314811, 00314886, 00314913, 00314914, 00314924, 00314939, 00314987, 00315020, 00311797, 00310961, 00313513, 00302396, 00259558, 00309104, 00309329, 00310666, 00312728, 00312732, 00312894, 00312814, 00313233, 00313346, 00313120, 00313485, 00313731, 00313775, 00313842, 00314314, 00314361, 00314360, 00314484, 00314585, 00315110, 00314880, 00314843, 00315065, 00315558, 00315587, 00315624, 00315612, 00315788, 00315789, 00315791, 00315795, 00315805, 00315825, 00315639, 00315830, 00315847, 00315856, 00315948, 00315995, 00315738, 00315908, 00315985, 00316098, 00315935, 00315926, 00316147, 00315862, 00316014, 00316037, 00316038, 00316212, 00315852, 00316171'
//23 Mar
+ '00316330, 00316465, 00316308, 00316034, 00316438, 00316357, 00316380, 00316430, 00316344, 00316035, 00315978, 00316343, 00316495, 00316389, 00316321, 00316264, 00316429, 00316265, 00316287'
//06 Jun
+ '00315754,00276428,00269200,00286155,00311944,00312296,00312717,00313476,00313404,00314086,00314010,00314371,00314418,00314646,00314601,00314599,00314642,00314776,00314981,00314982,00314808,00314903,00315006,00315033,00315066,00315103,00314998,00315070,00315165,00315106,00315176,00315303,00315234,00315494,00315250,00315177,00315702,00315803,00315345,00316124,00315751,00315990,00316010,00315703'
//19 jun
+'00317211,00317272,00317357,00317359,00317416,00317457,00317088,00317096,00317197,00317296,00317334,00317338,00317344,00317369,00317103,00317022,00317203,00317361,00316868,00317083,00317199,00317281,00317316,00317350,00317358,00317380,00317402,00317443,00317453,00317465,00317491,00317500'
;

String REASSON_CANCELATION = 'Does not comply with payments';
String TASK_DESCRIPTION = 'Cliente no cumple con los pagos, Solicitado y Autorizado por ELba Mantilla';
//*/

/*  OPCION 2 :: 'Evidence not Complete';
String INPUT_CONTRACT_CONCAT = 
'00315295, 00315317, 00315346, 00315379, 00315430, 00315409, 00315344, 00315450, 00315547, 00315556, 00315581'
;
String REASSON_CANCELATION = 'Evidence not Complete' ;
String TASK_DESCRIPTION = 'Cliente no ha entregado evidencias para poderle trabajar';
//*/

/*  OPCION 3 :: 'Does not comply with the obligations of the Contract';
String INPUT_CONTRACT_CONCAT = 
//Solicitado el 28 Mayof
'00315764,00315743,00315859,00316186,00315386,00315976,00316364,00315999,00316058,00315996,00315882,00316006,00316293,00316071,00316273,00316538,00316320,00316144'
//Solicitado el 15 Jun
+ '00316074,00316078,00316202,00316204,00316313,00316406,00316464,00316537,00316580,00316670'
;
String REASSON_CANCELATION = 'Does not comply with the obligations of the Contract' ;
String TASK_DESCRIPTION = 'PI no firmado';
//*/


public class CancelarContratosPorNumberRunner {
    private final Set<String> ALLOWED_PAYMENT_COLLECTION_STATUS = new Set<String>{
        'NOT_COLLECTED', 'Not_Collected', 'Not_collected', 'ACCEPTED', 'Accepted', 'COLLECTED', 'COLECTED', 'Collected', 'REJECTED'
    };

    private final Set<String> ORDER_STATES_TO_CANCEL = new Set<String>{
        'Pending', 'Iniciated', 'Stopped', 'Recurring', 'X CANCELED'
    };

    public List<ResultRow> run(Set<String> contractNumbers) {
        List<ResultRow> results = new List<ResultRow>();
        if (contractNumbers == null || contractNumbers.isEmpty()) return results;

        // 1) Cargar contratos por ContractNumber
        Map<Id, Contract> contractsById = new Map<Id, Contract>([
            SELECT Id, ContractNumber, Status
            FROM Contract
            WHERE ContractNumber IN :contractNumbers
        ]);
        if (contractsById.isEmpty()) {
            // Reportar números no encontrados
            for (String num : contractNumbers) {
                ResultRow r = new ResultRow();
                r.contractNumber = num;
                r.action = 'NOT_FOUND';
                r.detail = 'No se encontró Contract con ese ContractNumber';
                r.success = false;
                results.add(r);
            }
            return results;
        }

        // Map auxiliar para marcar cuáles numbers sí existen
        Set<String> foundNumbers = new Set<String>();
        for (Contract c : contractsById.values()) foundNumbers.add(c.ContractNumber);

        // Números inexistentes
        for (String num : contractNumbers) {
            if (!foundNumbers.contains(num)) {

                ResultRow r = new ResultRow();
                r.contractNumber = num;
                r.action = 'NOT_FOUND';
                r.detail = 'No se encontró Contract con ese ContractNumber';
                r.success = false;
                results.add(r);
            }
        }

        // 2) Obtener payments por contrato y validar SM_Check_Collection_Status__c SOLO para pagos ACH
        //    Condición ACH proporcionada: RecordTypeId = '0121U000000KZPsQAO'
        Map<Id, List<SM_Payment__c>> paymentsByContract = new Map<Id, List<SM_Payment__c>>();
        for (SM_Payment__c p : [
            SELECT Id, Name, SM_Contract__c, SM_Check_Collection_Status__c, RecordTypeId, SM_Date_ACH_Transmitted__c, SM_Check_Collection_Date__c, Payment_Status__c
            FROM SM_Payment__c
            WHERE  Payment_Status__c = 'REJECTED' AND SM_Contract__c IN :contractsById.keySet()
        ]) {
            List<SM_Payment__c> lst = paymentsByContract.get(p.SM_Contract__c);
            if (lst == null) {
                lst = new List<SM_Payment__c>();
                paymentsByContract.put(p.SM_Contract__c, lst);
            }
            lst.add(p);
        }

        final String ACH_PAYMENT_RECORDTYPE_ID = '0121U000000KZPsQAO';

        Set<Id> cancelableContracts = new Set<Id>();
        for (Contract c : contractsById.values()) {
            List<SM_Payment__c> related = paymentsByContract.get(c.Id);
            Boolean canCancel = true;

            if (related != null && !related.isEmpty()) {
                // Determinar si el contrato tiene al menos un Payment ACH
                Boolean hasAchPayment = false;
                for (SM_Payment__c p : related) {
                    if (p.RecordTypeId == ACH_PAYMENT_RECORDTYPE_ID) {
                        hasAchPayment = true;
                        break;
                    }
                }

                // Solo si hay Payments ACH se valida SM_Check_Collection_Status__c contra ALLOWED_PAYMENT_COLLECTION_STATUS
                if (hasAchPayment) {
                    for (SM_Payment__c p : related) {
                        if (p.RecordTypeId == ACH_PAYMENT_RECORDTYPE_ID) {
                            String st = p.SM_Check_Collection_Status__c;
                            st.toUpperCase();
                            //system.debug(' → Payment ACH Status : ' + p.SM_Check_Collection_Status__c);
                            if (!ALLOWED_PAYMENT_COLLECTION_STATUS.contains(st)) {    ///   st == null || 
                                canCancel = false;
                              //  system.debug(' → Payment ACH canCancel ? : ' + canCancel + ' Status : ' + p.SM_Check_Collection_Status__c);
                                break;
                            }
                        }
                    }
                }
            }

            if (canCancel) {
                cancelableContracts.add(c.Id);
                system.debug(' → ✔ Cancelable Contract : ' + c.Id);
            } else {
                ResultRow row = new ResultRow();
                row.contractId = c.Id;
                row.contractNumber = c.ContractNumber;
                row.action = 'SKIP';
                
                // Construir mensaje detallado con datos de payments bloqueantes
                String detailMsg = 'Payment ACH con estado bloqueante para cancelación: ';
                if (related != null && !related.isEmpty()) {
                    List<String> paymentDetails = new List<String>();
                    for (SM_Payment__c p : related) {
                        if (p.RecordTypeId == ACH_PAYMENT_RECORDTYPE_ID) {
                            String status = p.SM_Check_Collection_Status__c != null ? p.SM_Check_Collection_Status__c : 'NULL';
                            String transmittedDate = p.SM_Date_ACH_Transmitted__c != null ? String.valueOf(p.SM_Date_ACH_Transmitted__c) : 'NULL';
                            String collectionDate = p.SM_Check_Collection_Date__c != null ? String.valueOf(p.SM_Check_Collection_Date__c) : 'NULL';
                            paymentDetails.add('ID:' + p.Id + '(' + p.Name + ') 🔸 Status:' + status + '🔸 Collection Date :' + collectionDate + ' 🔸 Transmitted:' + transmittedDate);
                        }
                    }
                    detailMsg += String.join(paymentDetails, ' 🔸 ');
                } else {
                    detailMsg += 'Sin payments ACH';
                }
                row.detail = detailMsg;
                row.success = false;
                results.add(row);
            }
        }

        if (cancelableContracts.isEmpty()) return results;

        // 3) Cargar y preparar actualización de órdenes
        // Para contratos cancelados: cambiar a 'Canceled'
        List<SM_ACH_Order__c> achOrdersToUpdate = [
            SELECT Id, SM_Payment_Status__c, SM_Contract__c
            FROM SM_ACH_Order__c
            WHERE SM_Contract__c IN :cancelableContracts
              AND SM_Payment_Status__c IN :ORDER_STATES_TO_CANCEL
        ];
        for (SM_ACH_Order__c o : achOrdersToUpdate) {
            o.SM_Payment_Status__c = 'Canceled';
        }

        List<ChargentOrders__ChargentOrder__c> chargentOrdersToUpdate = [
            SELECT Id, ChargentOrders__Payment_Status__c, Contract__c
            FROM ChargentOrders__ChargentOrder__c
            WHERE Contract__c IN :cancelableContracts
              AND ChargentOrders__Payment_Status__c IN :ORDER_STATES_TO_CANCEL
        ];
        for (ChargentOrders__ChargentOrder__c co : chargentOrdersToUpdate) {
            co.ChargentOrders__Payment_Status__c = 'Canceled';
        }

        // Para contratos NO cancelados (pero que tienen ACH Orders): dejarlos como 'Stopped'
        // Cargar todos los ACH Orders asociados a contratos procesados (incluso los que no se cancelaron)
        Set<Id> allContractsWithAchOrders = new Set<Id>();
        for (SM_ACH_Order__c o : [
            SELECT SM_Contract__c
            FROM SM_ACH_Order__c
            WHERE SM_Contract__c IN :contractsById.keySet()
              AND SM_Payment_Status__c != 'Canceled'
            LIMIT 10000
        ]) {
            allContractsWithAchOrders.add(o.SM_Contract__c);
        }

        // Solo actualizar aquellos contratos que NO fueron cancelados pero sí tenían ACH Orders
        Set<Id> contractsToStopAchOrders = new Set<Id>();
        for (Id cid : allContractsWithAchOrders) {
            if (!cancelableContracts.contains(cid)) {
                contractsToStopAchOrders.add(cid);
            }
        }

        if (!contractsToStopAchOrders.isEmpty()) {
            List<SM_ACH_Order__c> achOrdersToStop = [
                SELECT Id, SM_Payment_Status__c, SM_Contract__c
                FROM SM_ACH_Order__c
                WHERE SM_Contract__c IN :contractsToStopAchOrders
                  AND SM_Payment_Status__c != 'Stopped'
            ];
            for (SM_ACH_Order__c o : achOrdersToStop) {
                o.SM_Payment_Status__c = 'CANCELED';  //'Stopped';
            }
            // Actualizar órdenes ACH que deben quedar como 'Stopped'
            if (!achOrdersToStop.isEmpty()) {
                Database.SaveResult[] achStopSave = Database.update(achOrdersToStop, false);
                // Puedes manejar errores aquí si es necesario
            }
        }

        // 4) Preparar contratos a 'Cancelled'
        List<Contract> contractsToUpdate = new List<Contract>();
        for (Id cid : cancelableContracts) {
            Contract c = contractsById.get(cid);
            if (c != null && c.Status != 'Cancelled') {
                c.Status = 'Cancelled';
                c.SM_Reason_for_cancellation__c = REASSON_CANCELATION;  //'Does not comply with payments';
                c.SM_Cancellation_Date__c = Date.today();
                contractsToUpdate.add(c);
            }
        }

        // 5) DML
        Database.SaveResult[] achOrderSave = new List<Database.SaveResult>();
        if (!achOrdersToUpdate.isEmpty()) {
            achOrderSave = Database.update(achOrdersToUpdate, false);
        }
        Database.SaveResult[] chargentOrderSave = new List<Database.SaveResult>();
        if (!chargentOrdersToUpdate.isEmpty()) {
            chargentOrderSave = Database.update(chargentOrdersToUpdate, false);
        }
        Database.SaveResult[] contractSave = new List<Database.SaveResult>();
        if (!contractsToUpdate.isEmpty()) {
            contractSave = Database.update(contractsToUpdate, false);
        }

        // 6) Resultados
        Map<Id, String> achOrderErrorsByContract = new Map<Id, String>();
        for (Integer i = 0; i < achOrdersToUpdate.size(); i++) {
            if (!achOrderSave[i].isSuccess()) {
                SM_ACH_Order__c rec = achOrdersToUpdate[i];
                achOrderErrorsByContract.put(rec.SM_Contract__c, this.collectErrors(achOrderSave[i]));
            }
        }
        Map<Id, String> chargentOrderErrorsByContract = new Map<Id, String>();
        for (Integer i = 0; i < chargentOrdersToUpdate.size(); i++) {
            if (!chargentOrderSave[i].isSuccess()) {
                ChargentOrders__ChargentOrder__c rec = chargentOrdersToUpdate[i];
                chargentOrderErrorsByContract.put(rec.Contract__c, this.collectErrors(chargentOrderSave[i]));
            }
        }
        Map<Id, Contract> cancelablesMap = new Map<Id, Contract>();
        for (Contract c : contractsToUpdate) cancelablesMap.put(c.Id, c);

        Map<Id, String> contractErrors = new Map<Id, String>();
        for (Integer i = 0; i < contractsToUpdate.size(); i++) {
            if (!contractSave[i].isSuccess()) {
                Contract rec = contractsToUpdate[i];
                contractErrors.put(rec.Id, this.collectErrors(contractSave[i]));
            }
        }

        // 7) Crear Tasks para contratos cancelados exitosamente
        // Configuración solicitada:
        // Subject = "Customer Service-Effective Cancellation"
        // WhatId = ContractId
        // Description = "Se cancela por falta de pago"
        // OwnerId = '0051U000001MRFeQAO'
        // RecordTypeId = '0121U00000085XiQAI'
        // ActivityDate = Date.today()
        // AccountId = Contract.AccountId
        // Nota: para obtener AccountId necesitamos consultarlo de Contract
        Map<Id, Contract> contractsForAccount = new Map<Id, Contract>([
            SELECT Id, AccountId
            FROM Contract
            WHERE Id IN :cancelableContracts
        ]);

        List<Task> tasksToInsert = new List<Task>();
        // Guardaremos los índices de outcome para marcar errores de Task si ocurren
        List<Integer> resultIndexForContract = new List<Integer>();

        for (Contract c : contractsById.values()) {
            if (!cancelableContracts.contains(c.Id)) continue;
            ResultRow row = new ResultRow();
            row.contractId = c.Id;
            row.contractNumber = c.ContractNumber;

            String err = null;
            if (contractErrors.containsKey(c.Id)) {
                err = 'Contract update error: ' + contractErrors.get(c.Id);
            }
            if (achOrderErrorsByContract.containsKey(c.Id)) {
                err = (err == null ? '' : err + ' 🔸 ') + 'ACH Orders error: ' + achOrderErrorsByContract.get(c.Id);
            }
            if (chargentOrderErrorsByContract.containsKey(c.Id)) {
                err = (err == null ? '' : err + ' 🔸 ') + 'Chargent Orders error: ' + chargentOrderErrorsByContract.get(c.Id);
            }

            if (err == null) {
                // Preparar creación de la Task
                Task t = new Task();
                t.Subject = 'Customer Service-Effective Cancellation';
                t.WhatId = c.Id;
                t.Description = TASK_DESCRIPTION; // 'Se cancela por falta de pago, Solicitado y Autorizado por ELba Mantilla';
                t.OwnerId = '0051U000001MRFeQAO';
                t.RecordTypeId = '0121U00000085XiQAI';
                t.ActivityDate = Date.today();
                Contract cAcc = contractsForAccount.get(c.Id);
                tasksToInsert.add(t);

                row.action = 'CANCELLED';
                row.detail = 'Contrato y órdenes actualizados. Task pendiente de inserción.';
                row.success = true;
            } else {
                row.action = 'PARTIAL/ERROR';
                row.detail = err;
                row.success = false;
            }
            // Añadimos provisionalmente; luego actualizaremos detalles si falla la inserción de Task
            results.add(row);
            resultIndexForContract.add(results.size() - 1);
        }

        // Insertar Tasks en bloque y actualizar resultados si hay errores
        if (!tasksToInsert.isEmpty()) {
            Database.SaveResult[] taskSave = Database.insert(tasksToInsert, false);
            for (Integer i = 0; i < taskSave.size(); i++) {
                if (!taskSave[i].isSuccess()) {
                    Integer idx = resultIndexForContract[i];
                    ResultRow rr = results[idx];
                    String tErr = this.collectErrors(taskSave[i]);
                    // Si la fila estaba marcada como success, convertir a PARTIAL/ERROR
                    if (rr != null) {
                        rr.action = (rr.success == true ? 'PARTIAL/ERROR' : rr.action);
                        rr.success = false;
                        rr.detail = (String.isBlank(rr.detail) ? '' : rr.detail + ' 🔸 ') + 'Task creation error: ' + tErr;
                        results[idx] = rr;
                    }
                } else {
                    Integer idx = resultIndexForContract[i];
                    ResultRow rr = results[idx];
                    if (rr != null && rr.success == true) {
                        rr.detail = rr.detail + ' 🔸 Task creada';
                        results[idx] = rr;
                    }
                }
            }
        }

        // 8) Construir logs TXT (cancelados y skipped/errores)
        String cancelledLog = 'ContractNumber;ContractId;Detail\n';
        String skippedLog = 'ContractNumber;ContractId;Payment Name;Payment Status;Check Collection Status;ACH Transmitted;Check Collection Date\n';

        // Para el log de skipped, vamos a reutilizar la lógica exacta de identificación de payments bloqueantes
        // que se usó en la sección de SKIP, pero con una pequeña modificación para construir el log
        for (ResultRow r : results) {
            if (r == null) continue;
            String num = r.contractNumber != null ? r.contractNumber : '';
            String cid = (r.contractId != null ? String.valueOf(r.contractId) : '');
            String det = r.detail != null ? r.detail.replace('\n',' ').replace('\r',' ') : '';

            if (r.success == true && r.action == 'CANCELLED') {
                cancelledLog += num + ';' + cid + ';' + det + '\n';
            } else if (r.action == 'SKIP' || r.action == 'PARTIAL/ERROR' || r.success == false) {
                // Para el log de skipped, mostrar solo los payments ACH que generan bloqueo
                // Usamos la misma lógica que en la sección de SKIP para identificar los bloqueantes
                String formattedDetail = '';
                List<SM_Payment__c> related = paymentsByContract.get(r.contractId);
                if (related != null && !related.isEmpty()) {
                    List<String> paymentDetails = new List<String>();
                    for (SM_Payment__c p : related) {
                        if (p.RecordTypeId == ACH_PAYMENT_RECORDTYPE_ID) {
                            // Solo incluir payments con estado bloqueante
                            // Esta es la lógica exacta de la sección de SKIP:
                            // if (st == null || !ALLOWED_PAYMENT_COLLECTION_STATUS.contains(st))
                            if (p.Payment_Status__c == 'REJECTED'
                                && !ALLOWED_PAYMENT_COLLECTION_STATUS.contains(p.SM_Check_Collection_Status__c)
                                 ) {
                                String paymentName = p.Name != null ? p.Name : '';
                                String paymentStatus = p.Payment_Status__c != null ? p.Payment_Status__c : '';
                                String checkCollectionStatus = p.SM_Check_Collection_Status__c != null ? p.SM_Check_Collection_Status__c : '';
                                String dateAchTransmitted = p.SM_Date_ACH_Transmitted__c != null ? String.valueOf(p.SM_Date_ACH_Transmitted__c) : '';
                                String checkCollectionDate = p.SM_Check_Collection_Date__c != null ? String.valueOf(p.SM_Check_Collection_Date__c) : '';
                                paymentDetails.add(paymentName + ';' + paymentStatus + ';' + checkCollectionStatus + ';' + dateAchTransmitted + ';' + checkCollectionDate + '\n');
                            }
                        }
                    }
                    formattedDetail = String.join(paymentDetails, ';');
                } else {
                    formattedDetail = 'Sin payments ACH';
                }
                
                // Asegurarse de que no haya caracteres especiales que puedan causar problemas
                //formattedDetail = formattedDetail.replace('\n', ' ').replace('\r', ' ');
                skippedLog += num + ';' + cid + ';' + formattedDetail + '\n';
            }
        }

    /*
       // Imprimir en logs de depuración para fácil copia a TXT
        System.debug('=== CANCELLED_LOG_TXT_BEGIN ===');
        System.debug(cancelledLog);
        System.debug('=== CANCELLED_LOG_TXT_END ===');
*/

        System.debug(' → === SKIPPED_LOG_TXT_BEGIN ===');
        System.debug(skippedLog);
        System.debug(' → === SKIPPED_LOG_TXT_END ===');

        return results;
    }

    private String collectErrors(Database.SaveResult sr) {
        List<String> msgs = new List<String>();
        for (Database.Error e : sr.getErrors()) {
            msgs.add(e.getMessage());
        }
        return String.join(msgs, '; ');
    }
}
// Clase auxiliar movida a nivel superior para evitar "Inner types are not allowed to have inner types"
public class ResultRow {
    public Id contractId;
    public String contractNumber;
    public String action;
    public String detail;
    public Boolean success;
}


Set<String> inputNumbers = new Set<String>();
for (String s : INPUT_CONTRACT_CONCAT.split(',')) {
    String t = s != null ? s.trim() : null;
    if (String.isNotBlank(t)) {
        inputNumbers.add(t);
    }
}

List<ResultRow> outcome =
    new CancelarContratosPorNumberRunner().run(inputNumbers);

// Reporte simple a logs
Integer ok = 0, fail = 0;
for (ResultRow r : outcome) {
    System.debug(' → Action=' + r.action + ' ContractNum=' + r.contractNumber + ' ContractId=' + r.contractId + ' Success=' + r.success + ' Detail=' + r.detail);
    if (r.success) ok++; else fail++;
}
System.debug(' → Resumen -> Success: ' + ok + ', Fail/Skipped: ' + fail);

// Instrucciones para exportar los logs como TXT:
// 1) Abre el Log generado por la ejecución anónima.
// 2) Copia el contenido entre las marcas === CANCELLED_LOG_TXT_BEGIN/END === a un archivo local .txt (ej. cancelled_contracts.txt).
// 3) Copia el contenido entre las marcas === SKIPPED_LOG_TXT_BEGIN/END === a un archivo local .txt (ej. skipped_contracts.txt).
// Ambos archivos quedan en formato CSV-simple con separador ';' y encabezados.
