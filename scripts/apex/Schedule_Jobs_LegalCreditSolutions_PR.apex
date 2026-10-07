/*
 * Schedule_Jobs_LegalCreditSolutions_PR.apex
 * -------------------------------------------
 * Programa los jobs de monitoreo a 07:00 hora de Puerto Rico.
 * EJECUTAR LOGUEADO COMO "Legal Credit Solutions" (salesforceadmin-qkv6@force.com),
 * cuya zona horaria ya es America/Puerto_Rico. No modifica usuarios ni clases.
 * Ver TRASPASO_JOBS_CARLOS.txt.
 *
 * Los jobs que quedan con dueno Carlos se dan de baja DESPUES, a mano, cuando se
 * verifique que estos quedaron bien (ver bloque final, comentado).
 */

String j1 = System.schedule('SM Contracts Activated Monitor - Daily', '0 0 7 * * ?', new SM_ACH_Flow_Monitor());
String j2 = System.schedule('SM_AgreementSignedDateMonitor_Daily', '0 15 7 * * ?', new SM_AgreementSignedDateMonitor());
String j3 = System.schedule('SM_TriggerPanelMonitor_Daily', '0 20 7 * * ?', new SM_TriggerPanelMonitor());
String j4 = System.schedule('SM_WeeklyComercialDigest_Monday', '0 0 7 ? * MON', new SM_WeeklyComercialDigestScheduler());

System.debug('Programados: ' + j1 + ' | ' + j2 + ' | ' + j3 + ' | ' + j4);

// Dar de baja los viejos (dueno Carlos) SOLO despues de verificar los nuevos:
// System.abortJob('08eUU00000iXt6YYAS');  // SM Contracts Activated Monitor - Daily (viejo)
// System.abortJob('08eUU00000iaKS1YAM');  // SM_AgreementSignedDateMonitor_Daily (viejo)
// System.abortJob('08eUU00000imCX8YAM');  // SM_TriggerPanelMonitor_Daily (viejo)
// System.abortJob('08eUU00000j0GHOYA2');  // SM_WeeklyComercialDigest_Monday (viejo)
