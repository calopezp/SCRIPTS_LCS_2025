/**
 * @description Batch Apex para procesar pagos ACH en lotes y generar el Nacha + CSV
 * Procesa todos los registros en scope de 180 (configurable en run()).
 * Seguridad: with sharing y operaciones DML en USER_MODE.
 *
 * Notas:
 * - Crea un único SM_Nacha_File__c por corrida (finish) con totales globales.
 * - Inserta SM_TransactionLog__c y actualiza SM_Payment__c por scope.
 * - Genera ContentVersion con el CSV final (incluye encabezado).
 * - Evita SOQL/DML en bucles, usa colecciones y Database.* con AccessLevel.USER_MODE.
 */
public with sharing class SM_ReporteACHFileBatch implements Database.Batchable<SObject>, Database.Stateful {

    // Parámetros de ejecución
    private Id ownerId;
    private Id logRecordTypeId;
    private String fileName;
    private DateTime runDateTime; // 18:00 del día actual
    // Acumuladores globales (Stateful)
    private Integer totalCount = 0;
    private Decimal totalAmount = 0;
    private List<Id> processedPaymentIds = new List<Id>();
    private List<String> csvLines = new List<String>();
    // Referencia al Nacha creado en finish
    private Id nachaId;

    public SM_ReporteACHFileBatch() {
        // Valores por defecto, pueden parametrizarse si es necesario
        this.ownerId = UserInfo.getUserId();
        this.logRecordTypeId = getTransactionLogRecordTypeId();
        this.fileName = 'Cargue Manual scr';
        this.runDateTime = DateTime.newInstance(System.today(), Time.newInstance(18, 0, 0, 0));
        // Encabezado CSV
        csvLines.add('ID,Name,Routing,Account,TypeCode,PersonName,Amount,OrderName,MethodName');
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {
        // Consulta selectiva de pagos pendientes de ACH (refleja la lógica del script original)
        String soql =
            'SELECT Id, Name, Payment_Status__c, SM_Net_Amount__c,' +
            '       SM_ACH_Account_Routing_Number__c,' +
            '       SM_ACH_Account_Type_Code__c,' +
            '       SM_Person_Account_Name__c,' +
            '       SM_ACH_Order__r.Name,' +
            '       SM_Payment_Method__r.Name,' +
            '       SM_Payment_Method__r.SM_ACH_Account_Number__c,' +
            '       SM_Contract__r.SM_Customer_Cancellation__c,' +
            '       SM_Contract__r.SM_Full_Payment__c,' +
            '       SM_Contract__r.Status ' +
            'FROM SM_Payment__c ' +
            'WHERE (Payment_Status__c = \'ACH PENDING\' OR Payment_Status__c = \'ACH PENDING REFUND\') ' +
            '  AND SM_Contract__r.SM_Customer_Cancellation__c = false ' +
            '  AND SM_Contract__r.SM_Full_Payment__c = false ' +
            '  AND (SM_Contract__r.Status = \'Activated\' OR SM_Contract__r.Status = \'Payment Process\') ' +
            'ORDER BY CreatedDate DESC';
        return Database.getQueryLocator(soql);
    }

    public void execute(Database.BatchableContext bc, List<SM_Payment__c> scope) {
        if (scope == null || scope.isEmpty()) {
            return;
        }

        // Acumular totales
        Decimal batchTotal = 0;
        for (SM_Payment__c p : scope) {
            if (p.SM_Net_Amount__c != null) {
                batchTotal += p.SM_Net_Amount__c;
            }
        }
        totalCount += scope.size();
        totalAmount += batchTotal;

        // Preparar logs y actualizaciones
        List<SM_TransactionLog__c> logs = new List<SM_TransactionLog__c>();
        List<SM_Payment__c> updates = new List<SM_Payment__c>();

        String dateStr = runDateTime.format('yyyy-MM-dd');

        for (SM_Payment__c pago : scope) {
            // Log
            SM_TransactionLog__c log = new SM_TransactionLog__c();
            log.OwnerId = ownerId;
            log.RecordTypeId = logRecordTypeId;
            log.SM_StatusCode__c = 200;
            log.SM_Response__c =
                'Global Process: Sender🔸 Get: The payment was collected correctly on ' + dateStr +
                '-  MANUAL CHARGE - ,Status OK, 🔸 Process: Payment was successfully processed in  ' +
                dateStr + '-,Status OK, 🔸 Send: The payment was sent successfully 🔸 SM_Nacha_File__c: ' +
                'PENDING' + ' in ' + dateStr + '-  MANUAL CHARGE - ,Status OK';
            log.Payment__c = pago.Id;
            logs.add(log);

            // Update Payment
            SM_Payment__c upd = new SM_Payment__c();
            upd.Id = pago.Id;
            upd.Payment_Status__c = (pago.Payment_Status__c == 'ACH PENDING REFUND')
                ? 'ACH TRANSMITTED REFUND' : 'ACH TRANSMITTED';
            // SM_Nacha_File__c y fecha se asignan en finish después de crear el Nacha
            updates.add(upd);

            // Construcción de la línea CSV
            String line =
                String.valueOf(pago.SM_ACH_Account_Routing_Number__c) + ',' +
                String.valueOf(pago.SM_Payment_Method__r != null ? pago.SM_Payment_Method__r.SM_ACH_Account_Number__c : null) + ',' +
                tipoLetra(pago) + ',' +
                normalize(pago.SM_Person_Account_Name__c) + ',' +
                pago.Name + ',' +
                (pago.SM_Net_Amount__c != null ? pago.SM_Net_Amount__c.setScale(2) : 0.setScale(2)) + ',' +
                (pago.SM_ACH_Order__r != null ? pago.SM_ACH_Order__r.Name : '') + ',' +
                (pago.SM_Payment_Method__r != null ? pago.SM_Payment_Method__r.Name : '');
            csvLines.add(line);

            processedPaymentIds.add(pago.Id);
        }

        if (!logs.isEmpty()) {
            Database.InsertResult[] lr = Database.insert(logs, AccessLevel.USER_MODE, /*allOrNone*/ false);
        }
        if (!updates.isEmpty()) {
            Database.SaveResult[] ur = Database.update(updates, AccessLevel.USER_MODE, /*allOrNone*/ false);
        }
    }

    public void finish(Database.BatchableContext bc) {
        // Crear Nacha único para la corrida
        SM_Nacha_File__c nacha = new SM_Nacha_File__c(
            OwnerId                        = ownerId,
            SM_Estado__c                   = 'Success',
            SM_Fecha_Transmision__c        = runDateTime,
            SM_Nombre_Archivo__c           = fileName,
            SM_Payments_Transmitidos__c    = totalCount,
            SM_Total_Valor_Transaccione__c = totalAmount,
            SM_Supera_Monto_Diario__c      = false,
            SM_Retransmision__c            = false
        );
        Database.SaveResult[] nsr = Database.insert(new List<SM_Nacha_File__c>{nacha}, AccessLevel.USER_MODE, false);
        if (!nsr.isEmpty() && nsr[0].isSuccess()) {
            nachaId = nsr[0].getId();
        }

        // Reasignar Nacha y fecha a todos los pagos procesados
        if (!processedPaymentIds.isEmpty() && nachaId != null) {
            List<SM_Payment__c> updNacha = new List<SM_Payment__c>();
            for (Id pid : processedPaymentIds) {
                SM_Payment__c u = new SM_Payment__c();
                u.Id = pid;
                u.SM_Nacha_File__c = nachaId;
                u.SM_Date_ACH_Transmitted__c = runDateTime;
                updNacha.add(u);
            }
            Database.SaveResult[] r = Database.update(updNacha, AccessLevel.USER_MODE, false);
        }

        // Actualizar logs con el Nacha creado (opcional: reconsulta de logs creados por Payment)
        // Para evitar una reconsulta pesada, este paso puede omitirse o implementarse con una relación si existe.
        // Si deseas actualizar el texto con el Id real del Nacha, se puede hacer una query a los logs cuyos Payment__c IN processedPaymentIds.

        // Generar CSV y guardar como ContentVersion
        if (!csvLines.isEmpty()) {
            String csvBody = String.join(csvLines, '\n');
            ContentVersion cv = new ContentVersion(
                Title          = 'ACH_' + DateTime.now().format('yyyyMMdd') + '.csv',
                PathOnClient   = 'ACH_' + DateTime.now().format('yyyyMMdd') + '.csv',
                VersionData    = Blob.valueOf(csvBody),
                IsMajorVersion = true
            );
            Database.SaveResult[] cvr = Database.insert(new List<ContentVersion>{cv}, AccessLevel.USER_MODE, false);
        }
    }

    // Utilidades trasladadas del script original

    private static String normalize(String input) {
        if (input == null) return '';
        input = input.toUpperCase();
        Map<String, String> mapa = new Map<String, String>{
            'Á' => 'A', 'É' => 'E', 'Í' => 'I', 'Ó' => 'O', 'Ú' => 'U',
            'À' => 'A', 'È' => 'E', 'Ì' => 'I', 'Ò' => 'O', 'Ù' => 'U',
            'Ä' => 'A', 'Ë' => 'E', 'Ï' => 'I', 'Ö' => 'O', 'Ü' => 'U',
            'Ñ' => 'N'
        };
        for (String key : mapa.keySet()) input = input.replace(key, mapa.get(key));
        return input;
    }

    private static String tipoLetra(SM_Payment__c p) {
        String status = String.valueOf(p.Payment_Status__c);
        String codigo = p.SM_ACH_Account_Type_Code__c;

        if (status != null && status.toUpperCase().contains('REFUND')) {
            return codigo == '22' ? 'C' :
                   codigo == '32' ? 'S' : '';
        } else {
            return codigo == '27' ? 'C' :
                   codigo == '37' ? 'S' : '';
        }
    }

    // Obtiene RecordTypeId para SM_TransactionLog__c según API Name (ajusta si difiere)
    private static Id getTransactionLogRecordTypeId() {
        // Si conoces el DeveloperName exacto, colócalo aquí:
        String devName = 'SM_TransactionLog'; // Placeholder, AJUSTAR si es distinto
        try {
            RecordType rt = [
                SELECT Id FROM RecordType
                WHERE SObjectType = 'SM_TransactionLog__c' AND DeveloperName = :devName
                LIMIT 1
            ];
            return rt != null ? rt.Id : null;
        } catch (Exception e) {
            return null;
        }
    }

    // Método de ejecución con scope configurable (default 180)
    public static void run(Integer scopeSize) {
        Integer sizeToUse = (scopeSize != null && scopeSize > 0 && scopeSize <= 200) ? scopeSize : 180;
        Database.executeBatch(new SM_ReporteACHFileBatch(), sizeToUse);
    }
}