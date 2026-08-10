/*
    Apex Script: LimpiarDuplicadosTask.apex
    Descripción:
    - Elimina duplicados en Task bajo las condiciones:
    OwnerId = '0051U000001MRFeQAO'
    RecordTypeId = '0121U00000085XiQAI'
    Duplicado si comparten: Description + WhatId + Subject
    - Conserva el más antiguo (por CreatedDate) y elimina el resto
    - Respeta buenas prácticas: bulkificación, sin DML/SOQL en bucles, manejo de resultados

    Parámetros configurables:
    - DRY_RUN: cuando true, no elimina; solo muestra (via resultados) qué se eliminaría.
    - BATCH_SIZE: controla cuántos registros analizar por lote para evitar límites.
    - MAX_GROUPS: limita cuántos grupos de duplicados procesar en un solo run (seguridad).

    Notas:
    - Evita hardcodear OwnerId/RecordTypeId en productivo. Aquí se dejan según solicitud para el script puntual.
    - Si deseas hacer esto invocable desde Flow, convertir a clase invocable con inputs y retorno.

    Uso:
    - Abrir Developer Console > Debug > Open Execute Anonymous Window
    - Pegar el contenido del bloque “// EJECUCIÓN” con los parámetros deseados y ejecutar
*/

/** Configuración */
Boolean DRY_RUN = false; // true = simulación (no elimina), false = elimina
Integer BATCH_SIZE = 1000; // número de Tasks a considerar por consulta
Integer MAX_GROUPS = 1000; // límite de grupos a procesar por ejecución (seguridad)
Id OWNER_ID = '0051U000001MRFeQAO';
Id RECORD_TYPE_ID = '0121U00000085XiQAI';
date FECHA_CORTE = Date.today().addMonths(-3); // opcional: filtrar por fecha para reducir volumen

/** Estructuras auxiliares */
public class TaskKey {
    public String description;
    public Id whatId;
    public String subject;
    public Date ActivityDate;

    public TaskKey(String description, Id whatId, String subject, Date ActivityDate) {
        this.description = description == null ? '' : description.trim();
        this.whatId = whatId;
        this.subject = subject == null ? '' : subject.trim();
        this.ActivityDate = ActivityDate;
    }
    public Integer hashCode() {
        return (String.valueOf(description) + '🔸' + String.valueOf(whatId) + '🔸' + String.valueOf(subject) + '🔸' + String.valueOf(ActivityDate)).hashCode();
    }
    public Boolean equals(Object o) {
        if (o == null || !(o instanceof TaskKey)) return false;
        TaskKey other = (TaskKey)o;
        return description == other.description
            && whatId == other.whatId
            && subject == other.subject
            && ActivityDate == other.ActivityDate;
    }
    public override String toString() {
        return '(Desc=' + description + ', WhatId=' + String.valueOf(whatId) + ', Subject=' + subject + ', ActivityDate=' + ActivityDate + ')';
    }
}

/** Resultado por grupo */
public class GroupResult {
    public TaskKey key;
    public Id keptId;
    public List<Id> deletedIds = new List<Id>();
    public Integer groupSize;
    public String note;
}

/** Contenedores de salida */
List<GroupResult> results = new List<GroupResult>();
Integer totalEvaluated = 0;
Integer totalGroups = 0;
Integer totalToDelete = 0;

/*
Consulta base: solo Tasks que cumplan Owner y RecordType.
Se recomienda ejecutar por ventanas si tienes muchísimos registros (agregar filtros por fechas).
*/
List<Task> tasks = [
    SELECT Id, Subject, Description, WhatId, OwnerId, RecordTypeId, CreatedDate, ActivityDate
    FROM Task
    WHERE OwnerId = :OWNER_ID
      AND RecordTypeId = :RECORD_TYPE_ID
      AND CreatedDate > :FECHA_CORTE
    ORDER BY CreatedDate ASC
    LIMIT :BATCH_SIZE
];

totalEvaluated = tasks.size();

/*
Agrupación por clave compuesta (Description + WhatId + Subject).
Se conservará el primer registro por CreatedDate (lista ya ordenada ASC) y el resto se marcará para borrar.
*/
Map<TaskKey, List<Task>> groups = new Map<TaskKey, List<Task>>();
for (Task t : tasks) {
    TaskKey key = new TaskKey(t.Description, t.WhatId, t.Subject, t.ActivityDate);
    if (!groups.containsKey(key)) {
        groups.put(key, new List<Task>());
     //   system.debug(' \u2192 Grupo para Evaluar : ' + key);
    }
    groups.get(key).add(t);
}

/*
Construimos la lista a eliminar por grupo.
*/
List<Task> toDelete = new List<Task>();
for (TaskKey key : groups.keySet()) {
    List<Task> grp = groups.get(key);
    if (grp.size() <= 1) {
        // No es duplicado, nada que hacer
        continue;
    }
    totalGroups++;
    if (totalGroups >= MAX_GROUPS) {
        // Seguridad: no procesar más de MAX_GROUPS en una ejecución
        GroupResult gr = new GroupResult();
        gr.key = key;
        gr.groupSize = grp.size();
        gr.note = 'Límite de grupos alcanzado; este grupo no se procesó en esta ejecución';
        results.add(gr);
        continue;
    }
    // La lista está ordenada por CreatedDate ASC desde la consulta global
    // Conservamos el más antiguo (primer elemento)
    Task keep = grp[0];
    List<Task> dups = new List<Task>();
    if (grp.size() > 1) {
        for (Integer i = 1; i < grp.size(); i++) {
            dups.add(grp[i]);
        }
    }
    GroupResult gr = new GroupResult();
    gr.key = key;
    gr.keptId = keep.Id;
    gr.groupSize = grp.size();
    gr.note = DRY_RUN ? 'Simulación: no se eliminarán' : 'Se eliminarán duplicados';
    for (Task d : dups) {
        gr.deletedIds.add(d.Id);
        system.debug(' \u2192 Marcado para eliminación: ' + d.whatId + ' - (' + d.ActivityDate + ')' + d.description + ' - ' + d.subject + ' (Id=' + d.Id + ')' );
    }
    results.add(gr);
    toDelete.addAll(dups);
}

totalToDelete = toDelete.size();

/*
Ejecución de borrado controlado (si no es dry-run). Se hace en un único DML bulk.
Para mayor seguridad, se podría trocear en sub-lotes de 200 registros.
*/
List<Database.DeleteResult> delResults = new List<Database.DeleteResult>();
if (!DRY_RUN && !toDelete.isEmpty()) {
    // Nota: en script puntual no podemos usar AccessLevel.USER_MODE. En clase se recomienda Database.delete(toDelete, AccessLevel.USER_MODE).
    delResults = Database.delete(toDelete, false);
}

/*
Salida resumida: construir un reporte legible.
Evitar System.debug en productivo; en script es aceptable para revisar resultados inmediatamente.
*/
String summary = 'RESUMEN LIMPIEZA TASKS' +
    '\n\u2192 - Evaluadas: ' + totalEvaluated +
    '\n\u2192 - Grupos detectados: ' + totalGroups +
    '\n\u2192 - A eliminar: ' + totalToDelete +
    '\n\u2192 - DRY_RUN: ' + String.valueOf(DRY_RUN) +
    '\n\u2192 - BATCH_SIZE: ' + BATCH_SIZE +
    '\n\u2192 - MAX_GROUPS: ' + MAX_GROUPS;

System.debug(' \u2192 ' + summary);

// Detalle por grupo (cuidado: puede ser extenso). Descomenta si necesitas más detalle.
// for (GroupResult gr : results) {
//     System.debug('Grupo ' + gr.key + ' 🔸 size=' + gr.groupSize + ' 🔸 keep=' + gr.keptId + ' 🔸 delete=' + gr.deletedIds + ' 🔸 note=' + gr.note);
// }

// Detalle de resultados de borrado si no es dry-run
if (!DRY_RUN && !delResults.isEmpty()) {
    Integer ok = 0, errs = 0;
    for (Database.DeleteResult dr : delResults) {
        if (dr.isSuccess()) ok++;
        else errs++;
    }
    System.debug(' \u2192 Borrado: éxitos=' + ok + ', errores=' + errs);
}

/*
EJECUCIÓN
- Ajusta DRY_RUN, BATCH_SIZE y MAX_GROUPS en el encabezado del script.
- Ejecuta en Sandbox primero. Valida resultados con DRY_RUN=true.
- Si el volumen es grande, ejecuta por ventanas (e.g., agregando filtros adicionales a la consulta por fecha).
*/