/*
******************************************************************************************
*  PASO C — CONFIRMACIÓN DEL CARGUE ACH Y MARCACIÓN DE PAYMENTS
*  Creado 2026-10-02 (contraparte de "A. Generar File Reporte ACH.apex", que SOLO genera
*  el/los CSV y ya no toca Payment/Nacha/Log).
*
*  Cuándo corre: cuando llega la confirmación del banco (normalmente por correo, "ok" del
*  cargue). En el mundo ideal sería unas horas después de transmitido (~2:50pm PR), pero en la
*  práctica el reporte llega al día siguiente, así que esto se corre al día siguiente a primera
*  hora -- por eso dateValue = hoy-1 (la fecha REAL de transmisión que se está confirmando).
*
*  Qué hace, por cada ContentVersion "ACH_<fecha>_<SUFIJO>.csv" encontrado para esa fecha:
*    1. Lee el CSV y extrae los Payment Name reportados.
*    2. Valida contra el estado EN VIVO de esos Payments: si alguno no existe, o ya no está en
*       ACH PENDING/ACH PENDING REFUND, es NOVEDAD -- se reporta y se EXCLUYE, nunca se incluye
*       a la fuerza en la actualización (la fuente de verdad de "qué se actualiza" es el CSV,
*       nunca una query en vivo nueva).
*    3. Para los que sí cuadran: crea 1 SM_Nacha_File__c por archivo, cambia
*       Payment_Status__c a ACH TRANSMITTED/ACH TRANSMITTED REFUND, pone
*       SM_Date_ACH_Transmitted__c y SM_Transmission_Date_ACH_File__c, enlaza el Nacha, y crea
*       un SM_TransactionLog__c por payment.
*    4. CreatedDate del Nacha Y del TransactionLog quedan en la fecha/hora REAL de transmisión
*       (dateValue a las 15:00 PR), NUNCA en la fecha en que corre este script -- instrucción
*       explícita del usuario 2026-10-02.
*
*  DRY_RUN = true por default (patrón de todo el pipeline de Collections): solo valida y
*  reporta en debug, no escribe nada. Cambiar a false para aplicar de verdad.
******************************************************************************************/

Boolean DRY_RUN = true;

Id ownerId         = '0051U000001MRFeQAO';
Id logRecordTypeId = '0121U000000KY48QAG';
String nombreNacha = 'Cargue Manual scr';

// "Ayer" naive (hoy-1) rompe los lunes: el proceso completo (A y C) no
// corre ni sabado ni domingo, asi que un lunes "ayer" cae en domingo (sin
// archivo, nunca confirma el viernes) -- hallazgo del usuario 2026-10-03.
// Se calcula el ULTIMO DIA HABIL anterior a hoy en su lugar: lunes -> viernes
// (retrocede 3), cualquier otro dia -> ayer normal (retrocede 1). No hace
// falta cubrir "hoy es sabado/domingo" porque el pipeline no se invoca esos
// dias. DateTime.newInstanceGMT (no newInstance) para el nombre del dia,
// mismo motivo que fechaTransmision abajo -- independiente del timezone del
// usuario que corre el script.
Date hoy = System.today();
String nombreDiaHoy = DateTime.newInstanceGMT(hoy, Time.newInstance(12, 0, 0, 0)).format('EEEE');
Integer diasAtras = (nombreDiaHoy == 'Monday') ? 3 : 1;
Date dateValue = hoy.addDays(-diasAtras); // Date.valueOf('2026-10-01'); // para forzar una fecha puntual
String dateStr = dateValue.format();
// DateTime.newInstance(Date,Time) usa el timezone del USUARIO que corre el script -- encontrado
// 2026-10-02 corriendo esto como clopez (sesión en Europe/Madrid, GMT+2): "15:00" se guardó como
// 13:00 UTC (9:00 AM Puerto Rico), 6 horas corridas de lo esperado. DateTime.newInstanceGMT fija
// la hora en UTC directo, sin depender de qué usuario/timezone ejecute el script. 18:00 UTC =
// 14:00 PR (AST, UTC-4 todo el año) -- cómodo dentro del día de negocio, lejos de medianoche en
// cualquier dirección, para que nunca ruede al día anterior/siguiente.
DateTime fechaTransmision = DateTime.newInstanceGMT(dateValue, Time.newInstance(18, 0, 0, 0));


// =========================================================================================
// 1️⃣ BUSCAR LOS ARCHIVOS GENERADOS PARA ESA FECHA
// NOTA: el '_' de LIKE NO se escapa a propósito -- en SOQL inline/estático dentro de Apex,
// escaparlo como '\_' devuelve 0 filas (gotcha real, ver BITACORA_HALLAZGOS_TECNICOS.md fila
// 2026-09-18). Sin escapar funciona como wildcard de 1 caracter, inofensivo aquí porque todos
// los títulos reales empiezan literal con "ACH_".
// =========================================================================================

String patronTitulo = 'ACH_' + dateStr + '%';
List<ContentVersion> archivos = [
    SELECT Id, Title, VersionData
    FROM   ContentVersion
    WHERE  Title LIKE :patronTitulo
    ORDER BY Title ASC
];

if (archivos.isEmpty()) {
    System.debug('→ No se encontraron archivos ACH_' + dateStr + '* en ContentVersion. Nada que confirmar.');
    return;
}

System.debug('→ Archivos encontrados para ' + dateStr + ': ' + archivos.size());
for (ContentVersion cv : archivos) System.debug('   ' + cv.Title + ' (' + cv.Id + ')');


// =========================================================================================
// 2️⃣ PARSEAR CADA ARCHIVO -> LISTA DE PAYMENT NAME POR ARCHIVO
// =========================================================================================

Map<Id, List<String>> nombresPorArchivo = new Map<Id, List<String>>();
Set<String> todosLosNombres = new Set<String>();

for (ContentVersion cv : archivos) {
    List<String> nombres = new List<String>();
    String contenido = cv.VersionData.toString();
    for (String linea : contenido.split('\n')) {
        linea = linea.trim();
        if (String.isBlank(linea)) continue;
        List<String> campos = linea.split(',');
        String primerCampo = campos[0].trim();
        if (primerCampo == 'Name') continue; // header, si el archivo lo trae
        nombres.add(primerCampo);
        todosLosNombres.add(primerCampo);
    }
    nombresPorArchivo.put(cv.Id, nombres);
}


// =========================================================================================
// 3️⃣ TRAER EL ESTADO EN VIVO DE ESOS PAYMENTS (una sola query para todos los archivos)
// =========================================================================================

Map<String, SM_Payment__c> pagoPorNombre = new Map<String, SM_Payment__c>();
for (SM_Payment__c p : [
        SELECT Id, Name, Payment_Status__c, SM_Net_Amount__c
        FROM   SM_Payment__c
        WHERE  Name IN :todosLosNombres
]) {
    pagoPorNombre.put(p.Name, p);
}


// =========================================================================================
// 4️⃣ PROCESAR CADA ARCHIVO: VALIDAR NOVEDADES Y (SI NO ES DRY RUN) CONFIRMAR
// =========================================================================================

Integer totalConfirmados = 0;
Integer totalNovedades = 0;

for (ContentVersion cv : archivos) {

    Boolean esRefund = cv.Title.contains('_REFUNDED');
    List<String> nombresArchivo = nombresPorArchivo.get(cv.Id);

    List<SM_Payment__c> confirmables = new List<SM_Payment__c>();
    List<String> novedades = new List<String>();

    for (String nombre : nombresArchivo) {
        SM_Payment__c p = pagoPorNombre.get(nombre);
        if (p == null) {
            novedades.add(nombre + ' -- NO EXISTE en Salesforce con ese Name');
            continue;
        }
        if (p.Payment_Status__c != 'ACH PENDING' && p.Payment_Status__c != 'ACH PENDING REFUND') {
            novedades.add(nombre + ' -- status actual es "' + p.Payment_Status__c + '", se esperaba ACH PENDING/REFUND');
            continue;
        }
        confirmables.add(p);
    }

    Decimal totalArchivo = 0;
    for (SM_Payment__c p : confirmables) totalArchivo += p.SM_Net_Amount__c;

    System.debug('→ ' + cv.Title + ': ' + nombresArchivo.size() + ' reportados, ' +
                 confirmables.size() + ' confirmables ($' + totalArchivo.setScale(2) + '), ' +
                 novedades.size() + ' NOVEDAD(ES)');
    for (String n : novedades) System.debug('   ⚠ NOVEDAD: ' + n);

    totalNovedades += novedades.size();

    if (confirmables.isEmpty()) continue;

    if (DRY_RUN) {
        System.debug('   (DRY RUN) Se crearía 1 Nacha + se marcarían ' + confirmables.size() +
                     ' payments como ' + (esRefund ? 'ACH TRANSMITTED REFUND' : 'ACH TRANSMITTED') +
                     ' + se crearían ' + confirmables.size() + ' TransactionLog, todo con fecha ' +
                     fechaTransmision.format('yyyy-MM-dd HH:mm') + ' (PR).');
        totalConfirmados += confirmables.size();
        continue;
    }

    // ---- Aplicar de verdad ----

    SM_Nacha_File__c nacha = new SM_Nacha_File__c(
        OwnerId                         = ownerId,
        SM_Estado__c                    = 'Success',
        SM_Fecha_Transmision__c         = fechaTransmision,
        SM_Nombre_Archivo__c            = nombreNacha,
        SM_Payments_Transmitidos__c     = confirmables.size(),
        SM_Total_Valor_Transaccione__c  = totalArchivo,
        SM_Supera_Monto_Diario__c       = false,
        SM_Retransmision__c             = false,
        CreatedDate                     = fechaTransmision
    );
    insert nacha;

    List<SM_TransactionLog__c> logsBatch = new List<SM_TransactionLog__c>();
    List<SM_Payment__c> updBatch        = new List<SM_Payment__c>();

    for (Integer i = 0; i < confirmables.size(); i++) {

        SM_Payment__c p = confirmables[i];

        logsBatch.add(new SM_TransactionLog__c(
            OwnerId          = ownerId,
            RecordTypeId     = logRecordTypeId,
            SM_StatusCode__c = 200,
            SM_Response__c   = 'Global Process: Sender OK - ' + dateStr,
            Payment__c       = p.Id,
            CreatedDate      = fechaTransmision
        ));

        updBatch.add(new SM_Payment__c(
            Id                                = p.Id,
            Payment_Status__c                 = esRefund ? 'ACH TRANSMITTED REFUND' : 'ACH TRANSMITTED',
            SM_Nacha_File__c                  = nacha.Id,
            SM_Date_ACH_Transmitted__c        = fechaTransmision,
            SM_Transmission_Date_ACH_File__c  = dateValue,
            SM_Payment_Date__c                = dateValue
        ));

        if (logsBatch.size() == 100 || i == confirmables.size() - 1) {
            insert logsBatch;
            update updBatch;
            logsBatch.clear();
            updBatch.clear();
        }
    }

    totalConfirmados += confirmables.size();
    System.debug('   → Confirmado: Nacha ' + nacha.Id + ', ' + confirmables.size() + ' payments marcados.');
}


// =========================================================================================
// 5️⃣ CHEQUEO INFORMATIVO (no bloqueante): algo que hoy sigue ACH PENDING y NO está en
// ninguno de los archivos de esta fecha -- puede ser normal (payment nuevo, posterior al
// corte de ayer) o puede ser algo que se quedó fuera por error. Solo informativo.
// =========================================================================================

List<SM_Payment__c> pendientesHoy = [
    SELECT Name
    FROM   SM_Payment__c
    WHERE  (Payment_Status__c = 'ACH PENDING' OR Payment_Status__c = 'ACH PENDING REFUND')
      AND  SM_Contract__r.Is_Test_Contract__c = false
      AND  SM_Contract__r.SM_Customer_Cancellation__c = false
      AND  SM_Contract__r.SM_ContractMonitoring__c = false
      AND  SM_Contract__r.SM_Full_Payment__c = false
      AND  SM_Contract__r.Status != 'Cancelled'
      AND (SM_Contract__r.Status = 'Activated' OR SM_Contract__r.Status = 'Payment Process')
];

Integer noReportados = 0;
for (SM_Payment__c p : pendientesHoy) {
    if (!todosLosNombres.contains(p.Name)) noReportados++;
}
System.debug('→ FYI: ' + noReportados + ' payment(s) ACH PENDING hoy que NO estaban en los archivos de ' + dateStr +
             ' (normal si son nuevos después del corte de ayer -- no se tocan en esta corrida).');

System.debug('→ RESUMEN: ' + totalConfirmados + ' confirmados, ' + totalNovedades + ' novedades. DRY_RUN=' + DRY_RUN);
