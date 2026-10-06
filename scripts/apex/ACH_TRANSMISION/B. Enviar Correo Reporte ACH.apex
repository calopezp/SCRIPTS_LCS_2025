/*
******************************************************************************************
*  PASO B — CORREO DE ENVÍO ACH (con los archivos adjuntos)
*  Creado 2026-10-02. Pensado para el handoff: automatiza el correo a Yahaire/Elba/Juan que
*  hoy se manda a mano, para que la persona nueva en el puesto no tenga que armarlo ni saber
*  el formato -- solo correr este script después de "A. Generar File Reporte ACH.apex".
*
*  Busca los ContentVersion "ACH_<fecha de hoy>_*" que generó "A", calcula registros/monto
*  por archivo (parseando el propio CSV, columna Amount), y manda UN correo con todos los
*  archivos adjuntos. Formato de asunto/cuerpo tomado del ejemplo real del usuario
*  (2026-10-02): "Envío ACH <YYYYMMDD>" + líneas "Registros <Tipo> / Total Amount".
*
*  Destinatarios reales (confirmados 2026-10-02): TO = ytapia@moneepro.com (Yahaire, publica al
*  banco), emantilla@legal-credit.com (Elba) -- CC = jduarte@legal-credit.com (Juan),
*  clopez@legal-credit.com (Carlos, en copia a petición propia).
*
*  MODO PRUEBA (default): envía SOLO a EMAIL_PRUEBA (ni TO ni CC reales), hasta que se confirme
*  el formato. Cambiar ES_PRUEBA a false para producción -- DESTINATARIOS_REALES/CC_REALES ya
*  están llenos.
******************************************************************************************/

Boolean ES_PRUEBA = true;
String EMAIL_PRUEBA = 'clopez@legal-credit.com';
List<String> DESTINATARIOS_REALES = new List<String>{
    'ytapia@moneepro.com', 'emantilla@legal-credit.com'
};
List<String> CC_REALES = new List<String>{
    'jduarte@legal-credit.com', 'clopez@legal-credit.com'
};

Map<String,String> NOMBRE_POR_SUFIJO = new Map<String,String>{
    'CU'       => 'Master Bundle',
    'CR'       => 'Credit Rectification',
    'LN'       => 'Desembolso Prestamo',
    'CE'       => 'Credit Elevator Master',
    'REFUNDED' => 'Refund'
};

Date dateValue = System.today(); // mismo día que "A" -- el correo es del archivo que se genera y envía hoy
String dateStr = dateValue.format();


// =========================================================================================
// 1️⃣ BUSCAR LOS ARCHIVOS DE HOY (mismo criterio que "A" usa para nombrarlos)
// =========================================================================================

String patronTitulo = 'ACH_' + dateStr + '%';
List<ContentVersion> archivos = [
    SELECT Id, Title, VersionData
    FROM   ContentVersion
    WHERE  Title LIKE :patronTitulo
    ORDER BY Title ASC
];

if (archivos.isEmpty()) {
    System.debug('→ No se encontraron archivos ACH_' + dateStr + '* para hoy. Corre "A" primero.');
    return;
}


// =========================================================================================
// 2️⃣ CALCULAR REGISTROS Y MONTO POR ARCHIVO (parseando el propio CSV, columna Amount = índice 4)
// =========================================================================================

List<Messaging.EmailFileAttachment> adjuntos = new List<Messaging.EmailFileAttachment>();
List<String> lineasResumen = new List<String>();
Integer totalRegistros = 0;
Decimal totalMonto = 0;

// Formato YYYYMMDD limpio para el nombre de archivo del adjunto (el Title real usa M/d/yyyy
// con "/", que no es un nombre de archivo válido para un adjunto de correo)
String yyyymmdd = String.valueOf(dateValue.year())
    + (dateValue.month() < 10 ? '0' : '') + String.valueOf(dateValue.month())
    + (dateValue.day()   < 10 ? '0' : '') + String.valueOf(dateValue.day());

for (ContentVersion cv : archivos) {

    String contenido = cv.VersionData.toString();
    Integer registros = 0;
    Decimal monto = 0;

    for (String linea : contenido.split('\n')) {
        linea = linea.trim();
        if (String.isBlank(linea)) continue;
        List<String> campos = linea.split(',');
        if (campos[0].trim() == 'Name') continue; // header, si lo trae
        registros++;
        if (campos.size() > 4 && String.isNotBlank(campos[4])) {
            monto += Decimal.valueOf(campos[4].trim());
        }
    }

    // Sufijo del archivo = lo que viene después de "ACH_<fecha>_" y antes de ".csv"
    String sufijo = cv.Title.replace('ACH_' + dateStr + '_', '').replace('.csv', '');
    String nombreTipo = NOMBRE_POR_SUFIJO.containsKey(sufijo) ? NOMBRE_POR_SUFIJO.get(sufijo) : sufijo;

    lineasResumen.add('Registros ' + nombreTipo + ' : ' + registros);
    lineasResumen.add('Total Amount : ' + monto.setScale(2));
    lineasResumen.add('');

    totalRegistros += registros;
    totalMonto += monto;

    Messaging.EmailFileAttachment adj = new Messaging.EmailFileAttachment();
    adj.setFileName('ACH_' + yyyymmdd + '_' + sufijo + '.csv');
    adj.setBody(cv.VersionData);
    adjuntos.add(adj);
}


// =========================================================================================
// 3️⃣ ARMAR Y ENVIAR EL CORREO
// =========================================================================================

String asunto = 'Envío ACH ' + yyyymmdd;

String cuerpo = 'Buenas tardes\n\n' +
                'Adjunto archivo' + (archivos.size() > 1 ? 's' : '') + ' de ACH para el día de hoy.\n\n' +
                String.join(lineasResumen, '\n') +
                'Favor confirmar el cargue para poder hacer la marcación en Salesforce\n' +
                'Gracias';

// En modo prueba, NI el TO ni el CC reales reciben nada -- todo colapsa a EMAIL_PRUEBA, para
// que correrlo por error nunca le llegue algo a Yahaire/Elba/Juan.
List<String> destinatarios = ES_PRUEBA ? new List<String>{ EMAIL_PRUEBA } : DESTINATARIOS_REALES;
List<String> copiaA        = ES_PRUEBA ? new List<String>()              : CC_REALES;

if (destinatarios.isEmpty()) {
    System.debug('→ No hay destinatarios configurados (DESTINATARIOS_REALES vacío). Correo NO enviado.');
    return;
}

Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
mail.setToAddresses(destinatarios);
if (!copiaA.isEmpty()) mail.setCcAddresses(copiaA);
mail.setSubject((ES_PRUEBA ? '[PRUEBA] ' : '') + asunto);
mail.setPlainTextBody(cuerpo);
mail.setFileAttachments(adjuntos);
SM_ReturnCodeNotifier.usarRemitenteOrganizacion(mail);

Messaging.SendEmailResult[] resultados = Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ mail });

System.debug('→ Destinatarios (TO): ' + destinatarios);
System.debug('→ Copia (CC): ' + copiaA);
System.debug('→ Asunto: ' + mail.getSubject());
System.debug('→ Cuerpo:\n' + cuerpo);
System.debug('→ Adjuntos: ' + adjuntos.size());
System.debug('→ Enviado: ' + resultados[0].isSuccess() + (resultados[0].isSuccess() ? '' : ' -- ERROR: ' + resultados[0].getErrors()));
