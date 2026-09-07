---
name: collections
description: Especialista en el pipeline de cobranza (ACH Returns, Check Collection, ACH Reportados/Transmission) — estructura de archivos, reglas de negocio, scripts y clases Apex involucradas. Usar cuando se pregunte por payments rechazados/devueltos, reportes de banco, transmisión ACH, late payment fees, o al validar/diagnosticar cualquier archivo bajo COLLECTIONS/.
---

# Collections — especialista del pipeline de cobranza

Este skill resume el sistema real de cobranza de `SCRIPTS_LCS_2025`, verificado línea por línea contra el código (no es un resumen de alto nivel especulativo). Cuando el usuario pregunte sobre un Payment específico, un reporte de banco, una regresión de estado, o quiera validar los CSV de `COLLECTIONS/`, usa este documento como fuente primero y **verifica contra el código actual** antes de asegurar algo como hecho (el código cambia; esto es una fotografía).

Org de Salesforce: siempre **MONEE** (producción) vía `sf` CLI (`sf data query -o MONEE`, `sf apex run -o MONEE`). Ningún script usa usuario/contraseña.

## 1. Los tres sub-pipelines

| Sub-pipeline | Carpeta | Fuente del reporte | Qué reporta |
|---|---|---|---|
| **Check Collection** | `COLLECTIONS/COLLECTIONS/` | PDF "Check Collection Daily/Weekly" (Banco Popular) vía OneDrive | Cheques ACH que el banco aceptó, rechazó o quedan pendientes |
| **ACH Returns** | `COLLECTIONS/RETURNS/` | PDF "ACH Returns/Notification of Change" (Banco Popular) vía OneDrive | Devoluciones ACH (NSF, cuenta inválida, etc.) con código de retorno (R01, R04, R08, R10, R11...) |
| **ACH Reportados / Transmission** | `COLLECTIONS/ACH_REPORTADOS/` | CSV `ACH_YYYYMMDD*.csv` (OneDrive) + `ContentVersion` "ACH%" subidos a Salesforce | Qué payments fueron transmitidos al banco y cuándo (no si se cobraron) |

Cada uno tiene su propio `build_index.py`/parser/`.apex`/`run_*.sh`, orquestados juntos por `COLLECTIONS/run_all_imports.sh` (modo `dryrun` por default, `apply` para aplicar de verdad; un fallo en uno no aborta los otros dos).

## 2. Mapa de archivos e índices

```
COLLECTIONS/
├── build_index.py              # escanea OneDrive, clasifica PDF por contenido (Returns vs Collection), llama a los 2 extractores
├── build_pending_deltas.py     # decide quién "gana" cuando un Payment aparece en Returns Y Collection
├── buscar_payment.py           # diagnóstico: 1 o más PY-xxxxx → estado en vivo (SOQL) + los 3 índices históricos
├── mark_transmitted_accepted.apex   # manual: acepta payments transmitidos 15+ días sin reporte
├── run_all_imports.sh
├── index/
│   ├── collections_index.csv          # histórico completo Check Collection
│   ├── collections_last_run_delta.csv # solo lo nuevo de la corrida más reciente
│   ├── returns_index.csv              # histórico completo ACH Returns
│   └── returns_last_run_delta.csv
├── RETURNS/
│   ├── extract_ach_returns.py   # parser PDF Returns (2 layouts de fila, 2 variantes de reporte)
│   └── update_ach_returns.apex  # aplica el CSV a SM_Payment__c (con guard de regresión, ver sección 4)
├── COLLECTIONS/                 # (sí, carpeta con el mismo nombre que la padre)
│   ├── extract_check_collection.py
│   ├── update_check_collection.apex
│   ├── CheckCollectionImport_R10_ClienteSolicitoDevolucion.csv  # reporte aparte para Comercial (ver sección 3)
│   └── reportes_comercial_R10/
└── ACH_REPORTADOS/
    ├── build_index.py           # combina OneDrive + Salesforce Files (ContentVersion "ACH%")
    ├── extract_ach_transmission.py  # la fecha de transmisión sale del NOMBRE del archivo, no del contenido
    ├── fetch_salesforce_files.py     # descarga ContentVersion vía REST directo (API v60.0 — desactualizado, housekeeping pendiente)
    ├── split_index_for_backfill.py   # parte en bloques <10k filas por el límite DML
    ├── index/
    │   ├── transmission_index.csv     # 1 fila por Payment, fecha MÁS RECIENTE (deduplicado)
    │   ├── transmission_raw_log.csv   # log crudo, todas las apariciones
    │   └── last_run_delta.csv
    └── sf_files/_manifest.csv         # qué ContentVersion ya se descargaron (Title, ContentVersionId, Date, LocalFile, Status)
```

**Columnas de `collections_index.csv` / `returns_index.csv`:**
`Payment_Name, Payment_Status__c, SM_Check_Collection_Date__c, SM_Check_Collection__c, SM_Check_Collection_Status__c, SM_Return_code__c*, SM_Return_Change__c*, Section/Batch, Drawee_Name/Individual_Name, Check_Number/Reference_Number, Amount/CR_Amount/DB_Amount, Reason, Source_File`
(*solo en returns_index.csv)

**Columnas de `transmission_index.csv` / `transmission_raw_log.csv`:**
`Payment_Name, SM_Transmission_Date_ACH_File__c, Amount, Source_File`

Los `*_last_run_delta.csv` tienen las mismas columnas que su índice pero sin `Source_File`, y se usan para armar el reporte diario (R10, etc.), no para el update masivo — el update masivo usa 45 días de historia vía `build_pending_deltas.py`.

## 3. Reglas de negocio verificadas en los parsers Python

- **Match de Payment en Check Collection** (`extract_check_collection.py:92-95`): el `CHECK NUMBER` codifica el sufijo del `PY-xxxxx` (quitar ceros, rellenar a 8 dígitos). **Excepción** (líneas 18-26): si `DRAWEE NAME` ya trae un `PY-xxxxx` explícito, se usa ese en vez de derivarlo del check number — hay un caso real donde derivarlo dio un payment totalmente distinto.
- **Mapeo sección → estado** (`extract_check_collection.py:83-87`): `PENDING→(REJECTED,PENDING)`, `COLLECTED→(ACCEPTED,COLLECTED)`, `NOT COLLECTED→(REJECTED,NOT COLLECTED)`.
- **Reporte R10 para Comercial** (`extract_check_collection.py:46-51, 195-223`): si `REASON` empieza con `R10` (cliente pidió la devolución directo al banco), además del update normal se genera `*_R10_ClienteSolicitoDevolucion.csv` — solo seguimiento comercial, no toca Salesforce por separado.
- **`build_pending_deltas.py:8-9`**: cuando el mismo Payment aparece en Returns y en Collection, gana el reporte de fecha más reciente; en empate gana **Collection** sobre Return. Solo mira los últimos 45 días (`--days-back`, default en línea 109) para no reaplicar reportes viejos. Motivo documentado: sin este cruce, un Return viejo podía revertir un pago ya `COLLECTED` (caso real citado en el código: `PY-01867258`; y un bug de empate `>=` vs `>` con `PY-01880982`).
- **`ACH_REPORTADOS/build_index.py`**: si un Payment aparece más de una vez en la transmisión, se queda con la fecha más reciente. Excluye archivos con "REFUND" en el nombre (estructura distinta). Las Salesforce Files (`ContentVersion "ACH%"`) se descubrieron porque 184 payments con `SM_Transmission_Date_ACH_File__c` no aparecían en ningún PDF de OneDrive — son una fuente paralela, no un duplicado.
- **`extract_ach_transmission.py:18-19`**: la fecha de transmisión se toma del **nombre del archivo** (`ACH_YYYYMMDD*.csv`), no del contenido — es la fuente de verdad según el banco.

## 4. Reglas de negocio en los `.apex` (Anonymous Apex)

Todos: `DRY_RUN=true` por default, comparan contra el estado ACTUAL de `SM_Payment__c` (solo tocan lo que cambió), y agrupan updates por `SM_ACH_Order__c` en oleadas porque `SM_PaymentHandler` (`afterUpdate`) no tolera la misma orden ACH dos veces en el mismo DML.

- **Guard de regresión** (`update_ach_returns.apex` y `update_check_collection.apex`, líneas 160-181 en ambos) — **la regla más importante del pipeline**: un Payment ya `COLLECTED`/`ACCEPTED` **nunca se revierte automáticamente** a `RETURN`/`NOT COLLECTED`, sin importar fechas — se bloquea para revisión manual y se loguea una `ALERTA` en `regresiones_manual_review.log` (hoy vacío/no existe — nunca se ha disparado).
  - **Excepción a la excepción**: si ese `COLLECTED`/`ACCEPTED` viene de `mark_transmitted_accepted.apex` (se detecta por el tag `"...D_SIN_REPORTE:"` en el historial), no es un cobro confirmado por el banco sino una aceptación por timeout — en ese caso el reporte oficial SÍ puede corregirlo.
  - Cada cambio real deja rastro en `SM_Historical_Collection_Status__c` con prefijo `"PRC_AUT: <STATUS> //"` (Text(150), se trunca desde el final si no cabe).
- **`mark_transmitted_accepted.apex`**: marca `ACCEPTED`/`COLLECTED` los payments en `Payment_Status__c='ACH TRANSMITTED'` con `SM_Transmission_Date_ACH_File__c` de 15+ días (`DAYS_SINCE_TRANSMITTED`) y sin ningún reporte (`SM_Check_Collection_Status__c = null`). Historial: `"PRC_AUT_15D_SIN_REPORTE: ACCEPTED //"`. **Es manual y deliberadamente NO está en `run_all_imports.sh`** (decisión explícita documentada en el propio script) — requiere correr antes el import diario de Returns/Collection.
- **`update_transmission_date.apex`**: solo llena `SM_Transmission_Date_ACH_File__c` por `Payment_Name`, sin comparar estado. Aborta si el CSV trae >9000 filas.

## 5. Clases Apex de negocio relacionadas (fuera de `COLLECTIONS/`)

- **`SM_PaymentHandler.cls`** — máquina de estados de `SM_Payment__c`. `paymentStatusUpdates()` setea fechas por transición de estado. `processRejectedPayments()`: al pasar un Payment ACH a `REJECTED`, crea automáticamente una `SM_ACH_Order__c` tipo **`Late payment fee`** — salvo contrato `CANCELED`/`FINALIZED`, orden/payment relacionado ya existente, o (regla **SMPII-57**) ya exista una `Late payment fee` `Completed`/`Once` sobre contrato `Payment Process`/`Activated` (ahí solo se pone `Stopped`, no se duplica). Monto de penalidad y días de gracia vienen de `SM_Company_Setting__c` (configuración por compañía, no hardcodeada).
  - ⚠️ **Bug conocido, NO corregido**: `updateACHOrderInfo()` agrega el `SM_ACH_Order__c` de TODOS los payments nuevos a un `Set` sin filtrar null/RecordType → "Argument cannot be null" cuando el payment es Credit Card/Chargent sin `SM_ACH_Order__c`. Documentado en `SOLUCION_ERROR_PAYMENT_BATCH_ACH.md` y `ANALISIS_FINAL_ERROR_PAYMENT_BATCH.md`; el fix propuesto en esos `.md` **nunca se aplicó** al código.
  - `hasChargentObjectAccess()` está hard-disabled a `false` desde agosto 2026 (Chargent revocado); `processRejectedPaymentsChargentOrder()` es no-op permanente.
- **`SM_ACHOrderHandler.cls` / `SM_ACHOrderHelper.cls`** — enums de negocio (`PaymentTypeEnum`: Subscription/AC/Fee/Late payment fee; `PaymentStatusEnum`: Completed/Canceled/Initiated/Stopped/Pending/Created). Calcula `SM_Next_Transaction_Date__c` (mensual, ajustado a business day), aplica/retira penalidades sobre `SM_Total__c`, bloquea cancelar una orden con Payments en `ACH_PENDING`/`ACH_TRANSMITTED`.
- **`SM_ReporteACHFileBatch.cls`** — batch que genera el archivo/CSV que se manda al banco: toma `SM_Payment__c` en `'ACH PENDING'`/`'ACH PENDING REFUND'`, los pasa a `'ACH TRANSMITTED'`/`'ACH TRANSMITTED REFUND'`, y crea el `ContentVersion` (`Title = 'ACH_' + fecha + '.csv'`) que luego `fetch_salesforce_files.py` descarga como fuente paralela a OneDrive.
- **`SM_CustomerCancellationActionController.cls`** — al cancelar un contrato por el cliente: pasa `SM_ACH_Order__c` en `Initiated`/`Pending`/`Created` a `Stopped`; solo si el usuario es `System Administrator` borra los `SM_Payment__c` en `ACH PENDING` asociados.
- **`SM_AcPaymentToDependentContract.cls` / `SM_FeePaymentToDependentContract.cls`** — cuando un Payment `AC`/`Fee`/`Late payment fee` de un contrato Master pasa a `ACCEPTED`, clonan y reparten (prorrateado) entre contratos dependientes listos para colección.
- **Flow `SM_Update_original_type_in_late_payment_fee`** (no es clase Apex) — al crear un Payment `Late payment fee`, copia `SM_Original_Type__c` del payment fallido relacionado. Es uno de los 3 Process Builder/Flow de cobro documentados en `CLAUDE.md` (junto a `ContractPaymentActions` y `ChargentOrderPB` — este último parte de la migración Chargent, **no tocar**, ver sección de Chargent en `CLAUDE.md`).

## 6. Cómo diagnosticar un Payment específico

1. `python COLLECTIONS/buscar_payment.py PY-xxxxx` (o solo el número) — consulta en vivo `SM_Payment__c` en MONEE (`Payment_Status__c, SM_Amount__c, SM_Check_Collection__c/Status/Date, SM_Return_code__c/Change__c, SM_Date_ACH_Transmitted__c, SM_Transmission_Date_ACH_File__c`, etc.) y busca en los 3 índices históricos (returns, collections, transmission) a la vez. Actualiza los índices antes de buscar salvo `--no-update`.
2. Si algo no cuadra entre el estado en vivo y el histórico, mirar primero si el Payment tiene el tag `PRC_AUT_15D_SIN_REPORTE` en `SM_Historical_Collection_Status__c` (aceptado por timeout, no por reporte real).
3. Si parece una regresión bloqueada, buscar en `regresiones_manual_review.log` (generado por los `.sh`, hoy vacío).

## 7. Cosas pendientes / conocidas al momento de escribir este skill (2026-09-07)

- El bug de `SM_PaymentHandler.updateACHOrderInfo()` (sección 5) sigue sin corregir.
- `fetch_salesforce_files.py` usa API v60.0, desactualizado respecto al resto del proyecto (v64.0/v67.0) — housekeeping menor, ya señalado en `CLAUDE.md`.
- No existe un `.md` dedicado al pipeline de Collections aparte de este skill — el resto de la documentación vive como comentarios extensos dentro de los propios scripts.
- Antes de asumir que algo de aquí sigue vigente, relee el script/clase citado — este documento es una fotografía, no una fuente en vivo.
