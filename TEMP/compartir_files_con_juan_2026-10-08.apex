/*
 * compartir_files_con_juan_2026-10-08.apex
 * Comparte con Juan (Colaborador) todos los Salesforce Files cuyo dueño es Carlos.
 * Motivo: los ACH_* son privados (solo vinculados a Carlos) y Juan no tiene "Query All Files":
 * desde su sesión, los pasos A/B/C y fetch_salesforce_files.py no los verían. El guard del paso A
 * contra retransmisión (lee los ACH_* de los últimos 60 días) quedaría ciego.
 * Los dos mantienen el acceso; la propiedad pasa a Juan el día del cierre (traspaso_usuario.py).
 * DRY_RUN = true primero.
 *
 * NO EJECUTADO (solo vista previa, 446 a compartir). Lo reemplazó traspaso_usuario.py --apply de
 * Juan, que pasó la propiedad de los 448 Files a Juan (verificado: 0 a nombre de Carlos).
 */
Boolean DRY_RUN = true;
Id CARLOS = '0051U000007bbx5QAA';
Id JUAN   = '0058W00000CNeHuQAL';

Map<Id, ContentDocument> docs = new Map<Id, ContentDocument>(
    [SELECT Id, Title, FileType FROM ContentDocument WHERE OwnerId = :CARLOS]);
Set<Id> yaCompartidos = new Set<Id>();
for (ContentDocumentLink l : [SELECT ContentDocumentId FROM ContentDocumentLink
                              WHERE LinkedEntityId = :JUAN AND ContentDocumentId IN :docs.keySet()]) {
    yaCompartidos.add(l.ContentDocumentId);
}

List<ContentDocumentLink> nuevos = new List<ContentDocumentLink>();
Map<String, Integer> porTipo = new Map<String, Integer>();
Integer ach = 0;
for (ContentDocument d : docs.values()) {
    if (yaCompartidos.contains(d.Id)) continue;
    nuevos.add(new ContentDocumentLink(ContentDocumentId = d.Id, LinkedEntityId = JUAN,
                                       ShareType = 'C', Visibility = 'AllUsers'));
    porTipo.put(d.FileType, (porTipo.containsKey(d.FileType) ? porTipo.get(d.FileType) : 0) + 1);
    if (d.Title.startsWith('ACH')) ach++;
}

System.debug('→ MODO: ' + (DRY_RUN ? 'DRY RUN (solo preview, sin cambios)' : 'EJECUCIÓN REAL'));
System.debug('→ Files de Carlos: ' + docs.size() + ' ▫️ ya compartidos con Juan: ' + yaCompartidos.size()
             + ' ▫️ a compartir: ' + nuevos.size() + ' (ACH_*: ' + ach + ')');
System.debug('→ Por tipo: ' + porTipo);
if (DRY_RUN || nuevos.isEmpty()) { System.debug('→ No se cambió nada.'); return; }

Integer ok = 0;
List<String> errores = new List<String>();
for (Database.SaveResult sr : Database.insert(nuevos, false)) {
    if (sr.isSuccess()) ok++; else errores.add(String.valueOf(sr.getErrors()[0].getMessage()));
}
System.debug('→ ✅ Compartidos: ' + ok + ' ▫️ con error: ' + errores.size());
for (Integer i = 0; i < Math.min(errores.size(), 10); i++) System.debug('→ ❌ ' + errores[i]);
