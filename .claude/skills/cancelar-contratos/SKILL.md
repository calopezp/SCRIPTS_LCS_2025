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
| Clase Apex desplegada | `force-app/main/default/classes/CancelarContratosRunner.cls` | Toda la lógica (ACH + Chargebee). Método público único: `CancelarContratosRunner.run(List<CancelGroup>, Boolean modoDryRun)`. **No es un trigger ni Schedulable — no ejecuta nada por sí sola**, solo corre cuando algo la llama explícitamente. |
| Su test | `force-app/main/default/classes/CancelarContratosRunnerTest.cls` | 7 tests, ~89% cobertura. Usa `HttpCalloutMock` para simular la API de Chargebee (nunca llama a la real en test). |
| Script para correr | `scripts/apex/-CANCELAR_CONTRATOS_FULL.apex` | ~35 líneas: arma un `CancelGroup` con la lista de contratos + motivo, llama a la clase, imprime el reporte. Esto es lo que se edita y corre cada vez. |
| Script superado | `scripts/apex/-CancelarContratos.apex` | Versión vieja, solo ACH, sin la clase desplegada. No usar para corridas nuevas — se dejó como referencia histórica. |
| Lista maestra | `COLLECTIONS/CANCELACIONES/Contratos_para_Cancelar_LOG.csv` | Un `ContractNumber` por línea, sin header. Para agregar un contrato nuevo al lote: agregar una línea acá. |
| Estado recalculado | `COLLECTIONS/CANCELACIONES/Contratos_para_Cancelar_ESTADO.csv` | Se **regenera completo** cada vez que corre `check_estado_cancelaciones.py` — no editar a mano. Esta es la fuente de verdad de "en qué quedó cada contrato", visible en ambas máquinas tras `git pull`. |
| Script de validación | `COLLECTIONS/CANCELACIONES/check_estado_cancelaciones.py` (wrapper `run_check_estado.sh`) | Re-consulta Salesforce en vivo y clasifica cada contrato en una de 5 categorías (ver abajo). Replica la MISMA lógica de bloqueo que `CancelarContratosRunner.cls` — si se cambia una, cambiar la otra. |

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
  este contrato), o tiene una `SM_ACH_Order__c` en `Initiated`/`Stopped`/`Recurring`/`Pending`
  (actividad reciente que no encaja con "para cancelar"). Investigar antes de tocar.

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

## 4. Flujo completo

**Agregar contratos nuevos al lote:**
1. Agregar el/los `ContractNumber` a `COLLECTIONS/CANCELACIONES/Contratos_para_Cancelar_LOG.csv`
   (uno por línea, con los ceros a la izquierda, ej. `00318500`).
2. Correr `./run_check_estado.sh` para ver en qué categoría cae cada uno.

**Validar qué quedó pendiente (de cualquier sesión anterior, en cualquier máquina):**
```bash
cd COLLECTIONS/CANCELACIONES
./run_check_estado.sh                 # toda la lista maestra
./run_check_estado.sh 00317661 00317795   # solo contratos puntuales
```
Lee `Contratos_para_Cancelar_ESTADO.csv` después — no hace falta recalcular nada a mano en el chat.

**Correr una cancelación real:**
1. Editar `scripts/apex/-CANCELAR_CONTRATOS_FULL.apex`: poner el motivo, la descripción de la Task,
   y el `Set<String>` de `ContractNumber` a procesar (normalmente los `STUCK_CONTRACT_STATUS` y
   `PENDING_CHARGEBEE` de la última corrida de `check_estado_cancelaciones.py`).
2. Correr con `modoDryRun = true` primero (`sf apex run -o MONEE -f scripts/apex/-CANCELAR_CONTRATOS_FULL.apex`).
3. Revisar el reporte. Si se ve bien, cambiar a `modoDryRun = false` y correr de nuevo.
4. Correr `./run_check_estado.sh` de nuevo para confirmar el resultado y refrescar el CSV de estado.

**Modificar la lógica de negocio** (nuevo estado permitido, nueva regla de bloqueo, etc.): editar
`CancelarContratosRunner.cls` **y** replicar el mismo cambio en `check_estado_cancelaciones.py` —
si se desalinean, el CSV de estado deja de predecir correctamente lo que el runner haría.
Deploy con `--test-level RunSpecifiedTests --tests CancelarContratosRunnerTest` (regla del
`CLAUDE.md`) — correr primero `--dry-run` (checkonly) para no arriesgar nada.

## 5. Pendiente conocido (2026-09-21)

Ver `TAREAS_PENDIENTES.md` para el detalle de los `PENDING_CHARGEBEE`/`REVISAR_MANUAL` abiertos al
momento de escribir esto — esa lista cambia con cada corrida de `check_estado_cancelaciones.py`, así
que no se duplica aquí.
