---
name: cancelar-contratos
description: Especialista en el flujo de cancelación masiva de contratos (ACH y Chargebee) — clase Apex desplegada, script de validación de estado, gotchas reales de picklist/callout, y el flujo completo para agregar contratos nuevos o revisar pendientes. Usar cuando se hable de cancelar contratos, "Contratos para Cancelar", CancelarContratosRunner, o al validar/diagnosticar algo bajo COLLECTIONS/CANCELACIONES/.
---

# Cancelar Contratos — cancelación masiva ACH + Chargebee

Este skill resume el flujo real de cancelación de contratos de `SCRIPTS_LCS_2025`, verificado
contra el código (no es un resumen especulativo). Es trabajo **recurrente y manual controlado**:
nunca corre solo — siempre lo dispara el usuario a mano, revisando dry-run antes de real.

Org de Salesforce: siempre **MONEE** (producción) vía `sf` CLI.

## 1. Mapa de archivos

| Pieza | Ruta | Qué hace |
|---|---|---|
| Clase Apex desplegada | `force-app/main/default/classes/CancelarContratosRunner.cls` | Toda la lógica (ACH + Chargebee). Método público único: `CancelarContratosRunner.run(List<CancelRequest>, Boolean modoDryRun)` — un `CancelRequest` por contrato (`contractNumber`, `reason`, `requestDate`). **No es un trigger ni Schedulable — no ejecuta nada por sí sola**, solo corre cuando algo la llama explícitamente. |
| Su test | `force-app/main/default/classes/CancelarContratosRunnerTest.cls` | 8 tests, ~91% cobertura. Usa `HttpCalloutMock` para simular la API de Chargebee (nunca llama a la real en test). |
| Script para correr | `scripts/apex/-CANCELAR_CONTRATOS_FULL.apex` | ~35 líneas: pega el bloque `requests` generado por `generate_run_batch.py`, llama a la clase, imprime el reporte. Esto es lo que se edita y corre cada vez. |
| Script superado | `scripts/apex/-CancelarContratos.apex` | Versión vieja, solo ACH, sin la clase desplegada. No usar para corridas nuevas — se dejó como referencia histórica. |
| Lista maestra | `COLLECTIONS/CANCELACIONES/Contratos_para_Cancelar_LOG.csv` | **3 columnas, tab-separated, sin header:** `ContractNumber`, Fecha de solicitud (formato `d mmm yyyy`, ej. `10 jun 2026`, meses en español abreviado — esta fecha es la que se guarda en `SM_Cancellation_Date__c`, NO se usa `Date.today()`), Motivo (`SM_Reason_for_cancellation__c`). Para agregar un contrato nuevo: agregar una línea con las 3 columnas. |
| Estado recalculado | `COLLECTIONS/CANCELACIONES/Contratos_para_Cancelar_ESTADO.csv` | Se **regenera completo** cada vez que corre `check_estado_cancelaciones.py` — no editar a mano. Esta es la fuente de verdad de "en qué quedó cada contrato", visible en ambas máquinas tras `git pull`. |
| Script de validación | `COLLECTIONS/CANCELACIONES/check_estado_cancelaciones.py` (wrapper `run_check_estado.sh`) | Re-consulta Salesforce en vivo y clasifica cada contrato en una de 5 categorías (ver abajo). Replica la MISMA lógica de bloqueo que `CancelarContratosRunner.cls` — si se cambia una, cambiar la otra. |
| Generador de batch | `COLLECTIONS/CANCELACIONES/generate_run_batch.py` | Lee `Contratos_para_Cancelar_LOG.csv` y arma el bloque `List<CancelarContratosRunner.CancelRequest>` listo para pegar en el script — **nunca se escribe ese bloque a mano**, ni se procesa la lista maestra completa de una corrida (con Fecha+Motivo por fila, rompe el límite de Execute Anonymous). Tope por defecto 50 contratos por batch (`--limite`). Un contrato que no está en el CSV se omite con aviso, salvo que se pasen `--motivo`/`--fecha` (caso puntual/urgente sin tocar la lista maestra — ver sección 4). |
| Validación de pagos/órdenes pendientes | `COLLECTIONS/CANCELACIONES/validate_pending_payments.py` (wrapper `run_validate_pending_payments.sh`) | Paso previo a intentar cancelar un contrato `PENDING_ACH_PAYMENT`/`REVISAR_MANUAL`: cruza cada payment bloqueante contra el índice histórico de COLLECTIONS y aplica la Rule 3 del `CLAUDE.md` (26 días sin resolver, o código de retorno definitivo → `NOT_COLLECTED`); además detecta `SM_ACH_Order__c` activas (`Pending`/`Initiated`/`Recurring`) y las marca para pasar a `Stopped` (no `Canceled` — ese lo aplica `CancelarContratosRunner.cls` cuando el contrato cancela de verdad). Dry-run por default, escribe `Contratos_para_Cancelar_VALIDACION_PAGOS.csv`; `apply` al final del comando aplica los cambios en Salesforce. Ver sección 4.1. |

## 2. Categorías de `Contratos_para_Cancelar_ESTADO.csv`

- **CANCELLED_OK** — `Contract.Status = Cancelled` y Chargebee/ACH ya consistente. Nada que hacer.
- **STUCK_CONTRACT_STATUS** — Chargebee/ACH ya resuelto (invoices VOIDED/PAID, Subscription
  CANCELLED, u órdenes ACH todas Canceled/Completed) pero el `Contract.Status` no pasó a
  Cancelled. Candidato directo a correr el runner en real — no debería fallar.
- **PENDING_CHARGEBEE** — Subscription todavía `ACTIVE`/`PAUSED`, o invoices sin resolver. Trabajo
  real pendiente (no un bug) — el runner intentará void/cancel vía API cuando se corra.
- **PENDING_ACH_PAYMENT** — Un `SM_Payment__c` bloqueante (`Payment_Status__c` REJECTED/ACH
  TRANSMITTED) con `SM_Check_Collection_Status__c` sin resolver (`PENDING`/`RETURN`/etc.). Regla
  explícita del usuario: **nunca cancelar con un pago bancario sin resolver** — no forzar esto.
- **REVISAR_MANUAL** — Caso raro: `SM_Customer_Cancellation__c = false` (nunca se pidió cancelar
  este contrato), o tiene una `SM_ACH_Order__c` en `Initiated`/`Recurring`/`Pending` (actividad
  reciente que no encaja con "para cancelar"). Investigar antes de tocar. **`Stopped` NO cuenta
  como raro** (cambio 2026-09-23) — es el estado seguro al que `validate_pending_payments.py` (ver
  fila de la tabla de arriba y sección 4.1) manda estas órdenes antes de cancelar; si sigue en
  `Pending`/`Initiated`/`Recurring` es porque ese script todavía no corrió sobre el contrato.

## 3. Gotchas reales encontrados armando esto (2026-09)

1. **Orden callout/DML.** Un callout HTTP después de cualquier DML pendiente en la misma
   transacción tira `System.CalloutException: You have uncommitted work pending`. El runner corre
   en 2 fases estrictas: primero TODOS los callouts de TODOS los contratos (cero DML), después toda
   la DML (Chargebee + ACH).

2. **`SM_Reason_for_cancellation__c` es un picklist dependiente de `Status`.** Cambiar `Status` y
   este campo en la MISMA DML puede rechazarse con `bad value for restricted picklist field`
   incluso cuando el valor es válido para el nuevo Status — confirmado con un caso real dentro de
   esta misma transacción, y NO reproducible aislado (probablemente automatización disparada por
   una DML anterior sobre el mismo registro, ver `SM_ContractTrigger`/rollups de `dlrs`). Fix:
   `Status` se guarda en su propia DML (fase A), `Reason` en una segunda DML separada (fase B), ya
   con el `Status` comprometido en la base.

3. **`SM_Check_Collection_Status__c` es texto libre, no picklist**, y tiene 2 variantes de "no
   cobrado" circulando: `NOT_COLLECTED` (estándar actual) y `NOT COLLECTED` (con espacio, dato
   legado de antes de que `COLLECTIONS/COLLECTIONS/extract_check_collection.py` normalizara al
   escribir — ver su `SECTION_TO_STATUS`). Ambos scripts de cancelación y `check_estado_cancelaciones.py`
   reconocen ambas variantes. Los 212 payments legado con la variante espacio ya se normalizaron
   (`scripts/apex/-NORMALIZE_NotCollected_Status.apex`, `BITACORA_HALLAZGOS_TECNICOS.md` 2026-09-21).

4. **IDs reales de Chargebee usados en la API** (invoice y subscription) son el campo **`Name`**
   del registro en Salesforce — NO `chargebeeapps__CB_Id__c`, que parece el candidato obvio pero es
   un Id interno del conector, distinto. Confirmado con datos reales (`Name` = `6012` coincide con
   `/d/invoices/6012` en la URL de Chargebee).

5. **Named Credential:** `Chargebee_API` (Setup → Named Credentials) — confirmado funcionando
   end-to-end con un void real.

6. **`SM_Cancellation_Date__c` es la fecha de solicitud, no la fecha en que se corre el script.**
   Antes se usaba `Date.today()`; ahora viene de la columna 2 de `Contratos_para_Cancelar_LOG.csv`
   por contrato. Si un contrato no está en ese archivo, `generate_run_batch.py` lo omite del batch
   con un aviso — no inventa una fecha.

7. **`Stopped` vs `Canceled` en `SM_ACH_Order__c.SM_Payment_Status__c` son dos cosas distintas,
   no sinónimos** (aclarado 2026-09-23). `Stopped` = "se detuvo para que no siga generando cobros
   mientras el contrato todavía no está cancelado de verdad" (lo que hace
   `validate_pending_payments.py`, sección 4.1). `Canceled` = el estado final que aplica
   `CancelarContratosRunner.cls` (`ORDER_STATES_TO_CANCEL`) cuando el `Contract.Status` sí pasa a
   `Cancelled`. Por eso `check_estado_cancelaciones.py` ya no trata `Stopped` como "raro" (antes sí,
   ver sección 2) — es un paso intermedio esperado, no una señal de actividad viva.

## 4. Flujo completo

**Agregar contratos nuevos al lote:**
1. Agregar una línea a `COLLECTIONS/CANCELACIONES/Contratos_para_Cancelar_LOG.csv` con las 3
   columnas tab-separated: `ContractNumber<TAB>d mmm yyyy<TAB>Motivo` (ej.
   `00318500	21 sep 2026	Does not comply with payments`).
2. Correr `./run_check_estado.sh` para ver en qué categoría cae cada uno.

**Validar qué quedó pendiente (de cualquier sesión anterior, en cualquier máquina):**
```bash
cd COLLECTIONS/CANCELACIONES
./run_check_estado.sh                 # toda la lista maestra
./run_check_estado.sh 00317661 00317795   # solo contratos puntuales
```
Lee `Contratos_para_Cancelar_ESTADO.csv` después — no hace falta recalcular nada a mano en el chat.

### 4.1 Validar pagos/órdenes pendientes antes de intentar cancelar (2026-09-23)

Para cualquier contrato que `run_check_estado.sh` deje en `PENDING_ACH_PAYMENT` (o en
`REVISAR_MANUAL` por una orden activa), correr este paso **antes** de generar el batch de
cancelación — resuelve automáticamente lo que sí se puede resolver, así el batch real solo incluye
contratos genuinamente listos:

```bash
cd COLLECTIONS/CANCELACIONES
./run_validate_pending_payments.sh                    # dry-run, toda la lista maestra
./run_validate_pending_payments.sh 00317661 00317795  # dry-run, solo estos contratos
./run_validate_pending_payments.sh apply               # aplica en real (SIEMPRE dry-run primero)
```

Qué hace, por cada payment bloqueante (`SM_Payment__c` ACH en `REJECTED`/`ACH TRANSMITTED` sin
`SM_Check_Collection_Status__c` resuelto):

1. **Lo cruza contra el índice histórico de COLLECTIONS** (`returns_index.csv` +
   `collections_index.csv`, mismo mecanismo que `COLLECTIONS/buscar_payment.py`) para confirmar
   que el valor en vivo de Salesforce coincide con el **último** reporte bancario real. Si hay un
   reporte más reciente que Salesforce no refleja, **nunca se auto-aplica** — se marca
   `REVISAR_REPORTE_NO_APLICADO` con el estado/fecha/archivo de ese reporte. **El pipeline diario
   NO resuelve esto solo si el reporte es histórico** (Rule 2, `CLAUDE.md` §2.2: cualquier cosa
   reportada hace más de 2 meses exige confirmación explícita del usuario, nunca un catch-up
   silencioso) — así que este caso queda **solo reportado** en el CSV, es decisión del usuario si
   se actualiza y con qué dato (el que diga el reporte, no necesariamente `NOT_COLLECTED`).
2. Si Salesforce ya está al día, aplica la **Rule 3** (`CLAUDE.md` §2.2): más de 26 días desde
   `SM_Transmission_Date_ACH_File__c` sin resolver, o código de retorno definitivo
   (`R02`/`R04`/`R07`/`R10`/`R13`/`R16` — `R01`/`R09`/`R08` nunca saltan la espera) → marca
   `NOT_COLLECTED` con la razón exacta. Si todavía no califica → `EN_ESPERA`.

Y por cada `SM_ACH_Order__c` del contrato en `Pending`/`Initiated`/`Recurring` (sigue generando
cobros futuros mientras el contrato es candidato a cancelar): marca `STOPPED` — pasa
`SM_Payment_Status__c` a `Stopped` (no `Canceled`; ese último lo aplica
`CancelarContratosRunner.cls` cuando el contrato termina de cancelarse de verdad).

En modo `apply`, escribe ambos cambios en Salesforce vía Apex anónimo, dejando la marca `AUTO:
Validate_Pending_Payments_CancelCandidates - <razón> - <fecha>` en `SM_Id_Salesforce_LCS__c` de
cada registro tocado (regla del `CLAUDE.md` §1 sobre anotaciones de automatización — usa
`SM_AutomationLogHelper.appendNote`, preserva cualquier nota previa).

Después de un `apply`, correr `./run_check_estado.sh` de nuevo — los contratos que quedaron
completamente resueltos (todos sus payments bloqueantes pasaron a `NOT_COLLECTED`/`ACCEPTED`/etc.,
sin órdenes activas) van a aparecer en `STUCK_CONTRACT_STATUS` (o directo `CANCELLED_OK` si el
`Contract.Status` ya era `Cancelled` de antes y solo faltaba limpiar el payment) — listos para el
flujo normal de cancelación de abajo. Los que sigan en `EN_ESPERA` o `REVISAR_REPORTE_NO_APLICADO`
quedan documentados en `Contratos_para_Cancelar_VALIDACION_PAGOS.csv` con la razón exacta — no se
fuerzan.

**Correr una cancelación real:**
1. Generar el batch (Motivo y Fecha salen del CSV, no se escriben a mano):
   ```bash
   cd COLLECTIONS/CANCELACIONES
   python generate_run_batch.py --categoria STUCK_CONTRACT_STATUS   # o PENDING_CHARGEBEE, o contratos puntuales
   ```
   Un contrato puntual que **todavía no está** en `Contratos_para_Cancelar_LOG.csv` (caso urgente,
   sin agregarlo a la lista maestra):
   ```bash
   python generate_run_batch.py 00319999 --motivo "Does not comply with Payments" --fecha "22 sep 2026"
   ```
2. Pegar el bloque `requests` impreso en `scripts/apex/-CANCELAR_CONTRATOS_FULL.apex`, reemplazando
   el de ejemplo.
3. Correr con `modoDryRun = true` primero (`sf apex run -o MONEE -f scripts/apex/-CANCELAR_CONTRATOS_FULL.apex`).
4. Revisar el reporte. Si se ve bien, cambiar a `modoDryRun = false` y correr de nuevo.
5. Correr `./run_check_estado.sh` de nuevo para confirmar el resultado y refrescar el CSV de estado.

**Modificar la lógica de negocio** (nuevo estado permitido, nueva regla de bloqueo, etc.): editar
`CancelarContratosRunner.cls` **y** replicar el mismo cambio en `check_estado_cancelaciones.py` —
si se desalinean, el CSV de estado deja de predecir correctamente lo que el runner haría.
Deploy con `--test-level RunSpecifiedTests --tests CancelarContratosRunnerTest` (regla del
`CLAUDE.md`) — correr primero `--dry-run` (checkonly) para no arriesgar nada.

## 5. Pendiente conocido (2026-09-21)

Ver `TAREAS_PENDIENTES.md` para el detalle de los `PENDING_CHARGEBEE`/`REVISAR_MANUAL` abiertos al
momento de escribir esto — esa lista cambia con cada corrida de `check_estado_cancelaciones.py`, así
que no se duplica aquí.
