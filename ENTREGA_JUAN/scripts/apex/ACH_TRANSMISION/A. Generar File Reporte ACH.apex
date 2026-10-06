/*
******************************************************************************************
*  PASO A — GENERACIÓN DEL ARCHIVO ACH (para envío al banco)
*  Autor: Carlos (versión optimizada)
*  Fecha: Mayo 2026
*  Actualizado 2026-10-02 (parte 1): query y generación de CSV alineadas al Power Query de
*  Excel que hasta esa fecha producía el archivo real que se sube a Salesforce (ver memoria
*  del proyecto) -- agrega filtros de Is_Test_Contract__c/SM_ContractMonitoring__c, excluye
*  Status='Cancelled' explícitamente.
*  Actualizado 2026-10-02 (parte 2): el banco ahora requiere un archivo POR RecordType de
*  Contract (acrónimos CU=Master Bundle, CR=Credit Rectification, LN=Desembolso Prestamo,
*  CE=Credit Elevator Master -- mapeo de negocio, no derivable del RecordType de Salesforce),
*  más un archivo aparte para refunds (sufijo REFUNDED, sin columna RecordTypeId). El sufijo
*  del nombre de archivo se agrega SIEMPRE. Un Contract con un RecordType fuera de los 4
*  conocidos se EXCLUYE y se reporta en debug para revisión manual -- nunca se mete sin
*  clasificar en ningún archivo. Columnas Name,Routing,Account,TypeCode,Amount son las
*  obligatorias para el banco y nunca deben cambiar de orden/estructura; OrderName,
*  ContractNumber,RecordTypeId son de control interno y pueden ajustarse a futuro.
*  Actualizado 2026-10-02 (parte 3, decisión explícita del usuario): ESTE SCRIPT YA NO TOCA
*  Payment_Status__c, NO crea SM_Nacha_File__c, NI SM_TransactionLog__c -- solo genera el/los
*  CSV y los sube como ContentVersion. El payment se queda en 'ACH PENDING' hasta que se
*  confirme el cargue (ver paso "C. Confirmar Cargue Reporte ACH.apex"), que corre al día siguiente
*  cuando llega la confirmación del banco por correo y es quien hace esos 3 cambios.
*
*  Corregido 2026-10-04 (bug real confirmado -- ver CLAUDE.md sección 2.2): como este script
*  nunca cambia Payment_Status__c, si "C" no alcanza a confirmar el cargue de un día antes de
*  que "A" corra de nuevo, el mismo payment seguía 'ACH PENDING' y volvía a salir en el
*  archivo del día siguiente -- el banco trata cada aparición en un archivo como una
*  transmisión real e independiente, así que esto causó un cobro duplicado real
*  (PY-01907641/00318012, cobrado 2 veces; PY-01907642/00318146, disputado por el cliente vía
*  R10 -- lote completo transmitido 22 y 23-sep). Fix: antes de armar el archivo de hoy, se
*  revisan los reportes ACH_*.csv ya subidos (ContentVersion, últimos 60 días) y se excluye
*  cualquier payment que ya haya salido en alguno de ellos y siga 'ACH PENDING' -- en vez de
*  retransmitirlo en silencio, se reporta aparte para revisión manual (ver sección 1.5 abajo).
******************************************************************************************/

// =========================================================================================
// 1️⃣ DATOS FIJOS
// =========================================================================================

// Fecha del archivo = HOY, no ayer -- "A" genera el archivo que se envía el MISMO día
// (~2:50pm PR). El "ayer" quedó en "C" (que confirma al día siguiente el envío de ayer);
// aquí causaba un bug real: nombraba el archivo de hoy con la fecha de ayer, y "C" de mañana
// no lo habría encontrado al buscar por la fecha de hoy. Corregido 2026-10-02.
Date dateValue = System.today(); // Date.valueOf('2026-10-02'); // para forzar una fecha puntual
String dateStr = dateValue.format();

// Acrónimo de archivo por RecordType de Contract -- mapeo de negocio confirmado por el
// usuario 2026-10-02, no se puede derivar del Name/DeveloperName del RecordType en Salesforce.
Map<Id,String> SUFIJOS_POR_RECORDTYPE = new Map<Id,String>{
    Id.valueOf('0128W000000Jw4tQAC') => 'CU', // Master Bundle
    Id.valueOf('0121U00000085thQAA') => 'CR', // Credit Rectification
    Id.valueOf('0128W000000Jw4sQAC') => 'LN', // Desembolso Prestamo
    Id.valueOf('0128W000000Jw4rQAC') => 'CE'  // Credit Elevator Master
};


// =========================================================================================
// 2️⃣ QUERY PRINCIPAL
// Alineado 2026-10-02 con el Power Query de Excel que generaba el archivo real (ver memoria /
// skill de Collections): agrega Is_Test_Contract__c y SM_ContractMonitoring__c (el apex nunca
// los filtraba) y excluye Status='Cancelled' explícitamente -- el Power Query tenía el mismo
// intento pero con un typo ("Cncelled") que lo volvía inofensivo. Se mantiene además el
// whitelist original Activated/Payment Process, más estricto que el Power Query a propósito
// (decisión explícita del usuario, 2026-10-02: no aflojar el filtro de Status).
// =========================================================================================

List<SM_Payment__c> pagosTodos = [
    SELECT Id, SM_ACH_Account_Routing_Number__c, SM_Payment_Method__r.SM_ACH_Account_Number__c,
           SM_ACH_Account_Type_Code__c, Name, SM_Net_Amount__c,
           SM_ACH_Order__r.Name, Payment_Status__c, SM_Contract__r.ContractNumber,
           SM_Contract__r.RecordTypeId
    FROM   SM_Payment__c
    WHERE  (Payment_Status__c = 'ACH PENDING' OR Payment_Status__c = 'ACH PENDING REFUND')
      AND  SM_Contract__r.Is_Test_Contract__c = false
      AND  SM_Contract__r.SM_Customer_Cancellation__c = false
      AND  SM_Contract__r.SM_ContractMonitoring__c = false
      AND  SM_Contract__r.SM_Full_Payment__c = false
      AND  SM_Contract__r.Status != 'Cancelled'
      AND (SM_Contract__r.Status = 'Activated' OR SM_Contract__r.Status = 'Payment Process')
    ORDER BY Name ASC
];

system.debug(' → Payments ACH PENDING (antes de excluir ya reportados): ' + pagosTodos.size());

if (pagosTodos.isEmpty()) {
    System.debug(' →  No hay pagos ACH PENDING para procesar. Script finalizado.');
    return;
}

// =========================================================================================
// 1.5️⃣ EXCLUIR PAYMENTS QUE YA SALIERON EN UN REPORTE ANTERIOR SIN CONFIRMAR
// Ver nota de "Corregido 2026-10-04" en el encabezado -- esto es lo que evita que un payment
// se transmita 2 veces de verdad cuando "C" se atrasa un día. Se leen los reportes ACH_*.csv
// ya subidos (ContentVersion, últimos LOOKBACK_DIAS_REPORTES días) y se arma el set de
// payments ya reportados; cualquiera que siga ACH PENDING y ya este en ese set se EXCLUYE del
// archivo de hoy (no se transmite de nuevo) y se reporta aparte para revisión manual -- no se
// toca Payment_Status__c ni ningún otro campo, es solo un filtro sobre qué se incluye hoy.
// =========================================================================================

Integer LOOKBACK_DIAS_REPORTES = 60;
DateTime cutoffReportes = DateTime.now().addDays(-LOOKBACK_DIAS_REPORTES);

Set<String> yaReportados = new Set<String>();
for (ContentVersion cvPrevio : [
    SELECT Title, VersionData
    FROM ContentVersion
    WHERE Title LIKE 'ACH%.csv'
    AND CreatedDate >= :cutoffReportes
]) {
    String texto = cvPrevio.VersionData != null ? cvPrevio.VersionData.toString() : '';
    for (String linea : texto.split('\n')) {
        linea = linea.trim();
        if (String.isBlank(linea)) { continue; }
        Integer comaIdx = linea.indexOf(',');
        String nombrePago = (comaIdx > 0 ? linea.substring(0, comaIdx) : linea).trim();
        if (String.isNotBlank(nombrePago)) {
            yaReportados.add(nombrePago);
        }
    }
}
System.debug(' → Payments distintos en reportes de los últimos ' + LOOKBACK_DIAS_REPORTES + ' días: ' + yaReportados.size());

List<SM_Payment__c> pagos = new List<SM_Payment__c>();
List<SM_Payment__c> excluidosPorReporteAnterior = new List<SM_Payment__c>();
for (SM_Payment__c p : pagosTodos) {
    if (yaReportados.contains(p.Name)) {
        excluidosPorReporteAnterior.add(p);
    } else {
        pagos.add(p);
    }
}

if (!excluidosPorReporteAnterior.isEmpty()) {
    System.debug(' → ⚠ ' + excluidosPorReporteAnterior.size() +
        ' payment(s) EXCLUIDOS del archivo de hoy -- ya salieron en un reporte anterior y siguen ACH PENDING ' +
        '(revisar por qué "C. Confirmar Cargue Reporte ACH.apex" no los confirmó, antes de decidir si se re-incluyen a mano):');
    for (SM_Payment__c p : excluidosPorReporteAnterior) {
        System.debug('   ' + p.Name + ' (Contrato ' + p.SM_Contract__r.ContractNumber + ')');
    }
}

system.debug(' → Payments a procesar hoy (después de excluir ya reportados): ' + pagos.size());

if (pagos.isEmpty()) {
    System.debug(' →  No hay pagos nuevos para procesar hoy (todos ya reportados antes, o no había ninguno). Script finalizado.');
    return;
}


// =========================================================================================
// 3️⃣ CLASIFICAR POR GRUPO -- refunds aparte, el resto por RecordType del Contract
// =========================================================================================

List<SM_Payment__c> refundPagos = new List<SM_Payment__c>();
Map<String, List<SM_Payment__c>> gruposPorTipo = new Map<String, List<SM_Payment__c>>();
List<SM_Payment__c> sinClasificar = new List<SM_Payment__c>();

for (SM_Payment__c p : pagos) {
    if (p.Payment_Status__c.containsIgnoreCase('REFUND')) {
        refundPagos.add(p);
        continue;
    }
    String suf = SUFIJOS_POR_RECORDTYPE.get(p.SM_Contract__r.RecordTypeId);
    if (suf == null) {
        sinClasificar.add(p);
        continue;
    }
    if (!gruposPorTipo.containsKey(suf)) {
        gruposPorTipo.put(suf, new List<SM_Payment__c>());
    }
    gruposPorTipo.get(suf).add(p);
}

if (!sinClasificar.isEmpty()) {
    System.debug('⚠ ' + sinClasificar.size() + ' payment(s) con RecordType de Contract NO reconocido -- EXCLUIDOS del archivo, requieren revisión manual:');
    for (SM_Payment__c p : sinClasificar) {
        System.debug('   ' + p.Name + ' (Contract RecordTypeId=' + p.SM_Contract__r.RecordTypeId + ')');
    }
}


// =========================================================================================
// 4️⃣ FUNCIONES AUXILIARES
// =========================================================================================

String tipoLetra(SM_Payment__c p){
    String status = p.Payment_Status__c;
    String codigo = p.SM_ACH_Account_Type_Code__c;

    if (status.containsIgnoreCase('REFUND')) {
        return codigo == '22' ? '1' : codigo == '32' ? '2' : '';
    } else {
        return codigo == '27' ? '1' : codigo == '37' ? '2' : '';
    }
}

// Genera el CSV de un grupo (un RecordType, o el grupo de refunds) y lo sube como
// ContentVersion. NO toca Payment_Status__c, NO crea Nacha, NO crea TransactionLog -- eso es
// responsabilidad del paso C (confirmación del cargue, al día siguiente). Las filas
// no-refund llevan un 8vo campo (RecordTypeId del Contract); las de refund se quedan en 7
// campos, igual que los archivos reales "_REFUNDED" en OneDrive.
void generarArchivoGrupo(List<SM_Payment__c> grupoPagos, String sufijoArchivo, Boolean esRefund, String dateStrP){

    if (grupoPagos.isEmpty()) return;

    Decimal totalGrupo = 0;
    for (SM_Payment__c p : grupoPagos) totalGrupo += p.SM_Net_Amount__c;

    // Sin header -- confirmado por el usuario 2026-10-02 contra el script original
    // (Archivo/ReporteACHFile.apex.txt, Sept-2025: "CSV sin headers"). Columnas reales:
    // Name,Routing,Account,TypeCode,Amount,OrderName,ContractNumber[,RecordTypeId si no es refund].
    List<String> lineas = new List<String>();

    for (SM_Payment__c p : grupoPagos) {
        String linea =
            p.Name + ',' +
            p.SM_ACH_Account_Routing_Number__c + ',' +
            p.SM_Payment_Method__r.SM_ACH_Account_Number__c + ',' +
            tipoLetra(p) + ',' +
            p.SM_Net_Amount__c.setScale(2) + ',' +
            p.SM_ACH_Order__r.Name + ',' +
            p.SM_Contract__r.ContractNumber;
        if (!esRefund) {
            linea += ',' + p.SM_Contract__r.RecordTypeId;
        }
        lineas.add(linea);
    }

    String titulo = 'ACH_' + dateStrP + (sufijoArchivo != null ? '_' + sufijoArchivo : '') + '.csv';
    ContentVersion cv = new ContentVersion(
        Title           = titulo,
        PathOnClient    = titulo,
        VersionData     = Blob.valueOf(String.join(lineas, '\n')),
        IsMajorVersion  = true
    );
    insert cv;

    System.debug('→  Archivo generado: ' + titulo +
                 ' | Payments: ' + grupoPagos.size() +
                 ' | Total: ' + totalGrupo.setScale(2) +
                 ' | CSV: /lightning/r/ContentVersion/' + cv.Id + '/view');
}


// =========================================================================================
// 5️⃣ GENERAR UN ARCHIVO POR GRUPO (uno por RecordType presente, + uno de refunds si aplica)
// =========================================================================================

for (String suf : gruposPorTipo.keySet()) {
    generarArchivoGrupo(gruposPorTipo.get(suf), suf, false, dateStr);
}

if (!refundPagos.isEmpty()) {
    generarArchivoGrupo(refundPagos, 'REFUNDED', true, dateStr);
}

System.debug('→  Script finalizado correctamente -- archivo(s) generado(s), payments siguen en ACH PENDING hasta la confirmación (paso C).');
