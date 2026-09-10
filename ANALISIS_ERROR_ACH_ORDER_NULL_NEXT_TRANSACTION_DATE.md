# Análisis: NullPointerException en `SM_ACHOrderHandler.insertNextScheduledPaymentDate`

**Fecha:** 2026-09-09
**Contexto:** Corrida real de `COLLECTIONS/run_daily_new_files.sh apply` (Check Collection, 13 pagos pendientes) — 9 exitosos, 4 fallidos con el mismo error.
**Org:** MONEE (producción)

## Resumen

Al pasar un `SM_Payment__c` a `ACCEPTED`/`COLLECTED`, el Flow **"PAYMENT: Accumulate AC On Contract"** actualiza el `Contract` asociado. Esa actualización dispara **"CONTRACT: 10 - After Save Orchestrator"** (versión 5, activada el 2026-09-09), que intenta **crear** una nueva `SM_ACH_Order__c`. Esa creación falla porque `SM_ACHOrderHandler.insertNextScheduledPaymentDate()` llama `.year()`/`.month()`/`.day()` sobre `SM_Next_Transaction_Date__c` sin comprobar que no sea `null`.

**Antes de hoy esto nunca se disparaba**: la versión anterior del orchestrator (v4) no llamaba a los subflows que crean estas órdenes ACH, así que este bug quedó latente hasta que se activó la v5.

## Pagos afectados en esta corrida

| Payment (Id) | Payment_Name | Contract | Antes / después del intento |
|---|---|---|---|
| a24UU000005EtlNYAS | PY-01887694 | 00318138 | REJECTED/PENDING → intento de ACCEPTED/COLLECTED → **falló, quedó igual** |
| a24UU000005EtleYAC | PY-01887711 | 00318278 | REJECTED/PENDING → intento de ACCEPTED/COLLECTED → **falló, quedó igual** |
| a24UU000005H8T7YAK | PY-01890512 | 00317978 | REJECTED/PENDING → intento de ACCEPTED/COLLECTED → **falló, quedó igual** |
| a24UU000005H8U8YAK | PY-01890575 | 00318365 | REJECTED/PENDING → intento de ACCEPTED/COLLECTED → **falló, quedó igual** |

Ningún dato quedó corrupto — la falla del trigger revierte el `Database.update` de ese registro específico (el batch usa `allOrNone=false`, así que los otros 9 pagos del mismo lote sí se guardaron).

Contratos, para referencia:

| Contrato | Status | SM_Start_date__c | SM_AC_start_date__c | SM_AC_collected__c | SM_Requires_RC_Payment__c |
|---|---|---|---|---|---|
| 00317978 | Payment Process | 2026-09-30 | 2026-08-30 | false | true |
| 00318138 | Payment Process | 2026-09-25 | 2026-08-25 | false | true |
| 00318278 | Payment Process | 2026-09-16 | 2026-08-19 | false | true |
| 00318365 | Payment Process | 2026-09-20 | 2026-08-31 | false | true |

(Ninguno de los dos campos de fecha "fuente" está en `null` — el `null` aparece más adelante en la cadena, en el campo `SM_Next_Transaction_Date__c` del `SM_ACH_Order__c` que el Flow intenta crear. No se determinó con certeza exacta cuál nodo del Flow deja ese campo vacío para este caso puntual; el fix no depende de identificarlo, ver más abajo.)

## Stack trace exacto (idéntico en los 4 casos, mismo Error ID)

```
We can't save this record because the "PAYMENT: Accumulate AC On Contract" process failed.
The flow tried to update these records: <ContractId>.
This error occurred: CANNOT_EXECUTE_FLOW_TRIGGER: We can't save this record because the
"CONTRACT: 10 - After Save Orchestrator" process failed. This error occurred when the flow
tried to create records: CANNOT_INSERT_UPDATE_ACTIVATE_ENTITY: SM_ACHOrderTrigger:
execution of BeforeInsert

caused by: System.NullPointerException: Attempt to de-reference a null object

Class.SM_ACHOrderHandler.insertNextScheduledPaymentDate: line 588, column 1
Class.SM_ACHOrderHandler.beforeInsert: line 22, column 1
Class.SM_TriggerHandler.run: line 61, column 1
Trigger.SM_ACHOrderTrigger: line 14, column 1

Error ID: 738448094-68117 (1147799001)
```

## Código con el bug

`force-app/main/default/classes/SM_ACHOrderHandler.cls` (repo local, línea ~596-604 — el número de línea del stack trace de la org, 588, difiere ligeramente por drift entre repo y org, mismo método):

```apex
private static void insertNextScheduledPaymentDate(List<SM_ACH_Order__c> newRecords){
    BusinessHours bHour = SM_Utils.getBusinessHour('Monee Business Hour');
    for (SM_ACH_Order__c newAch : newRecords) {
         DateTime paymendDate = DateTime.newInstance(
             newAch.SM_Next_Transaction_Date__c.year(),    // <-- NPE si es null
             newAch.SM_Next_Transaction_Date__c.month(),
             newAch.SM_Next_Transaction_Date__c.day()
         );
         ...
```

Comparar con el método hermano (mismo archivo, `beforeUpdate`), que **sí** valida null antes de usar la fecha:

```apex
private static void updateNextScheduledPaymentDate(List<SM_ACH_Order__c> newRecords, Map<Id, SObject> oldRecordsMap){
    ...
    if ( SM_Utils.isChangedField(newAch, oldAch, 'SM_Payment_Start_Date__c') && newAch.SM_Payment_Start_Date__c != null) {
    ...
    if (SM_Utils.isChangedField(newAch, oldAch, 'SM_Next_Transaction_Date__c') && newAch.SM_Next_Transaction_Date__c != null) {
```

## Fix propuesto (no aplicado — pendiente de confirmación del usuario)

Agregar el mismo guard de null en `insertNextScheduledPaymentDate` antes de usar `SM_Next_Transaction_Date__c`, saltando el ajuste de día hábil cuando venga vacío (igual criterio que ya existe en `updateNextScheduledPaymentDate`).

## Impacto si no se corrige

Cualquier `SM_Payment__c` que dispare esta misma cadena (pasar a ACCEPTED/COLLECTED → Flow "PAYMENT: Accumulate AC On Contract" → Contract update → CONTRACT_10 crea una `SM_ACH_Order__c` nueva sin `SM_Next_Transaction_Date__c`) va a fallar igual, todos los días — no es exclusivo de estos 4 pagos ni de esta corrida.

## Pendiente

- Confirmar con el usuario si se aplica el fix (deploy de una clase Apex a producción).
- Una vez corregido, reintentar estos 4 pagos específicos (`PY-01887694`, `PY-01887711`, `PY-01890512`, `PY-01890575`) — actualmente quedaron en `REJECTED/PENDING`, sin cambios.
