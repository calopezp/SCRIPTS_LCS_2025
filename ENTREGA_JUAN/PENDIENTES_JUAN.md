# Pendientes para Juan — traspaso del proceso

Estado al 2026-10-06. Esta es la lista que acompaña la entrega. Lo que no está acá es decisión
de Carlos o de Comercial.

## Antes de la entrega (viernes 9-oct)

- **Traspaso de cuentas:** repositorio, carpeta de OneDrive, correos y OwnerId fijos a cuentas de la empresa.
- **Job `ACH Payment 14:50 PR.`:** activo, dueño `Legal Credit Solutions`, paquete Rollup Helper (`rh2`). El propósito no está confirmado. No pausar ni eliminar sin confirmarlo. Ver `JOBS_PROGRAMADOS.md`.
- **Job con nombre GUID** (tipo A, diario 12:00): identificarlo en Setup > Tareas programadas.
- **`DataExport`** (jueves): recrear desde Setup > Exportar datos, con la hora de referencia 07:00 PR.
- **`RPT- ACH Payment`:** reprogramar a 07:00 PR, bajo `Legal Credit Solutions`, **después** de que corra `ACH Payment 14:50 PR.`. Al reprogramarlo queda activo, así que confirmarlo antes. Ver `TRASPASO_JOBS_CARLOS.txt`, 1.7.

## Después de la entrega (cuando Juan lo retome)

- **7 contratos con agosto huérfano** (`00309371`, `00315074`, `00315279`, `00316426`, `00313308`, `00315899`, `00315916`): hay que activar la orden LPF de agosto que ya existe, o crearla en los que no existe. Esperar a que la cuota de septiembre en tránsito se resuelva, y revalidar con `activar_ach_chronic_unpaid.apex` en dry-run. No cambiar fechas de Subscription a mano: eso fue lo que generó los meses huérfanos.
- **R11 `CHECK TRUNC E` en `00316463`** (`PY-01888804`, `PY-01888827`): el paso diario los dejó para revisión manual. Decidir si son contracargo o un tema de check truncation. No se aplicó nada.
- **`643` (`PY-01907643`) y `645` (`PY-01907645`)**: lote 22/23-sep. Sin reporte ni confirmación. Cuando llegue un reporte o la confirmación de Elba, tratarlos según el criterio de duplicados.
- **Contratos ACH crónicos sin cobrar:** `activar_ach_chronic_unpaid.apex` corre a diario. Revisar la sección "REVISAR MANUAL" del correo.
- **Conversión Chargebee → ACH:** no hay script confiable. Hoy se hace a medias y a mano. Validar antes de automatizar.
- **Paso diario de contracargo R10/R11:** corre dentro de `run_daily_new_files.sh`, solo sobre casos nuevos. Revisar el correo y los Tasks que crea.

## Técnico (código)

- **`SM_PaymentHandler.cls`:** `updateRelatedRecordsByPaymentStatusUpdates()` usa `Database.update` sin `allOrNone=false`, y un pago ACCEPTED en contrato Cancelled manda la orden a `Canceled` en vez de `Completed`. Corregir antes de que se repita.
- **`SM_PaymentHandler`:** cuando un pago AC de una orden `Once` pasa a REJECTED y el contrato está en Payment Process o Activated, la orden queda en `Completed`. Falta esa rama.
- **`SM_ACPaymentActivationHandler`:** no tiene las mismas exclusiones que el flow de ACH (test, VIP, cancelación, dependiente).
- **`Flow:01IUU000005TicS`** (debug "servicio disputas"): no está retraído al repo. Retraerlo e investigar si falla con más de un contrato.
- **Guard de regresión** en `update_check_collection.apex` y `update_ach_returns.apex`: decidir si se amplían los tags de aceptación no bancaria que reconoce.
- **Remitente de correos:** los correos de Apex ya salen desde `noreply@legal-credit.com`. Los recibos de pago a clientes (`SM_PaymentHelper`) siguen con el remitente anterior, a la espera de decidir si el cliente puede responder.

## Correo y destinatarios

- **Comercial:** dos reportes (`sendWeeklyComercialDigest` y el correo de timeout) siguen mandando solo a Carlos. Falta la lista real de destinatarios de Comercial.
- **Winter '27, "Adopt Authorized Email Domains":** confirmar con la empresa si se pidió a Salesforce desactivar la verificación de email.

## Sin tocar

- **Migración de Chargent** (`SM_ContractHandler`, `SM_ContractHandlerTest`): no modificar ni desplegar sin confirmación expresa. Ver `CLAUDE.md`, sección 3.
- **Los 31 R10/R11 de 2026 sin REFUND:** cerrado como check. No se trabajan.
