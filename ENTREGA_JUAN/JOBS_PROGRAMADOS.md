# Jobs programados en MONEE — qué hacen y cuándo corren

Horario de referencia: **Puerto Rico**. Estado al 2026-10-06.

## Activos

| Job | Cuándo corre | Qué hace | Dueño |
|---|---|---|---|
| SM Contracts Activated Monitor - Daily PR | Todos los días, 07:00 PR | Revisa los contratos activados en las últimas 24 h que no tengan su orden AC/Subscription creada. Solo reporta por correo, no corrige nada. | Legal Credit Solutions |
| SM_AgreementSignedDateMonitor_Daily PR | Todos los días, 07:15 PR | Detecta acuerdos de firma electrónica sin fecha de firma. Solo reporta por correo. | Legal Credit Solutions |
| SM_TriggerPanelMonitor_Daily PR | Todos los días, 07:20 PR | Verifica que la configuración del panel de triggers no haya cambiado respecto a la línea base. Manda `[OK]` o `[REVISAR]` por correo. | Legal Credit Solutions |
| SM_WeeklyComercialDigest_Monday PR | Lunes, 07:00 PR | Resumen semanal de códigos de devolución para Comercial, por correo. | Legal Credit Solutions |
| ACH Payment 14:50 PR. | Lunes a viernes, 14:50 PR | Job del paquete **Rollup Helper** (de terceros). Recalcula campos de resumen. El nombre no corresponde a la transmisión ACH: la transmisión la hacen los scripts de `ACH_TRANSMISION`, no este job. | Legal Credit Solutions |

## Pausados

| Job | Qué hace | Estado |
|---|---|---|
| RPT- ACH Payment | Ejecuta `SM_PaymentSchedule`, que dispara el batch `SM_PaymentBatch` (procesamiento de pagos). | Pausado. Se reprograma a 07:00 PR **después** de que corra ACH Payment 14:50 PR. |
| RPT chargent TC | Legado de Chargent. | Pausado. No reactivar. |

## Del paquete Rollup Helper (no son de este proyecto)

Hay otros jobs del mismo paquete a nombre de Legal Credit Solutions: Rollup Batch Agent - Hourly, Rollup Helper Exception Monitor (cada hora), Rollup Helper Health Check (semanal), Rollup Helper Record Scope Monitor y Rollup Helper Retry (diarios). Se dejan como están.

## Del usuario de Juan (informativo)

- Chargebee_8_1_schedule_Set_Invoice_to_Payments-1: diario 20:30 (zona de Juan, Nueva York).
- Loan_Daily_Balance_and_Payments_Calculation-4: diario 05:00 (zona de Juan, Nueva York).

## Pendientes de identificar

- Un job con nombre GUID (tipo A, todos los días 12:00) cuyo propósito no está confirmado.
- DataExport (exportación semanal de datos, jueves): se recrea solo desde Setup.
