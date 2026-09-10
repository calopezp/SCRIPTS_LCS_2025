# Bitácora de hallazgos técnicos — SCRIPTS_LCS_2025

## Cómo usar este archivo

Registro acumulativo de bugs/errores reales encontrados en MONEE (o PREPROD) a lo largo de las
sesiones — no de decisiones de negocio ni de tareas operativas del día a día (esas van en
`CLAUDE.md` o en los handoffs de `COLLECTIONS/`). Pensado para consulta rápida y copiar/pegar
directo a un reporte gerencial cuando haga falta explicar un hallazgo técnico con fecha,
consecuencia, solución y estado actual.

**Se sigue llenando en cada sesión donde aparezca un hallazgo técnico nuevo** (bug real, no un
ajuste de datos puntual) — agregar una fila nueva a la tabla, más abajo el detalle si hace falta
contexto extra. No borrar filas viejas aunque ya estén resueltas — es historial.

---

## Tabla resumen

| Fecha | FIX / ERROR | Consecuencias | Solución | Estado |
|---|---|---|---|---|
| 2026-09-10 | Campo `SM_Chargent_Orders_Transaction__c` eliminado del org, pero todavía referenciado en `SM_FeePaymentToDependentContract.cls` y `SM_AcPaymentToDependentContract.cls` | Cualquier pago Fee/AC/Late Payment Fee que pasa a `ACCEPTED` en un contrato Master con dependientes tumba **todo el lote bulkificado** de la transacción (no solo el registro que lo dispara). Barrido del org: 1,764 pagos ($215,034.21) en 47 contratos Master en riesgo latente | Línea comentada en ambas clases (nota `// PARTE APP DE CHARGENT. ELIMINADA JUL 2026`), ajuste de tests (`SM_FeePaymentToDependentContractTest`), deploy con `RunSpecifiedTests` | **Desplegado y validado en producción** — `PY-01786030` aplicado con éxito post-fix, clonado a contrato dependiente confirmado (`PY-01900409`) |
| 2026-09-07 (encontrado) / 2026-09-10 (resuelto) | `update_check_collection.apex`: aplicar un pago sobre un contrato **Cancelado** cuyo `Payment_Status__c` cambia dispara un intento de cancelar su ACH Order; si esa orden tiene otro Payment `ACH TRANSMITTED`, una validation rule tumba **toda la oleada** del día (caso real: `ACH-27553`/00317537 tumbó 161 pagos de una corrida) | Bloqueaba la sincronización normal del backlog de Check Collection cada vez que aparecía un contrato Cancelado en el lote | Guard que detecta el caso ANTES del DML y lo separa para revisión manual/aislada (ya en el script); los 2 casos concretos (`PY-01876062`, `PY-01810250`) se procesaron uno por uno, aislados | **Resuelto para los 2 casos conocidos** — el guard en el script sigue vigente para cualquier caso futuro |
| 2026-09-10 | Informe ejecutivo general (Caso 01) afirmaba "37 de 39 ya cobraron con éxito" sin verificación en vivo — en realidad ninguno tenía confirmación bancaria, solo la orden interna marcada `Completed` (no equivale a cobro confirmado) | Cifra incorrecta a punto de presentarse a gerencia | Reverificación en vivo de los 39 uno por uno, corrección del texto del informe y el pill de estado (`Resuelto` → `En espera del banco`) | **Corregido en el informe**, publicado |
| 2026-09-10 | Contrato 00318139: única orden (AC, $99) en `Pending`, sin `SM_Next_Transaction_Date__c` — nunca se transmitió al banco, contrato detenido >1 mes | Cliente sin ningún intento de cobro, ni exitoso ni fallido | Se le asignó fecha de próxima transacción (15-ago) para que el batch diario lo recoja | **En cola** — pendiente confirmar que el batch efectivamente lo transmita |
| 2026-09-10 | Backlog de 50 pagos ($4,331.50, 29 contratos) con reporte del banco ya recibido y guardado en `index/collections_index.csv`, pero nunca sincronizado a Salesforce (retenido por la Regla 2 — >2 meses sin confirmación explícita) | Dinero ya cobrado por el banco, sin reflejar en Salesforce | Confirmación explícita de Carlos + CSV scoped a esos 50 + `update_check_collection.apex`/`update_check_collection_isolated.apex` | **50/50 aplicados** (incluye el que estaba bloqueado por el bug de Chargent, arriba) |
| 2026-08-14 (evento) / 2026-09-09 (encontrado y corregido) | Update masivo marcó 12 órdenes AC como `Completed` y les borró la fecha de próximo cobro, sin haber generado nunca el pago — el batch diario las ignoraba por verlas "ya resueltas" | 12 contratos activos congelados indefinidamente — nunca iban a cobrar su AC ni activar su suscripción | Revertidas a `Initiated` con su fecha de AC original | **Resuelto** — las 12 ya cobraron con éxito, $1,348 recuperados |
| 2026-08-14 (evento) / 2026-09-09 (encontrado) | Proceso masivo `ADJ_AC_ERR_12AGO` generó 90 órdenes de AC con montos erróneos (mezcló valor de AC con mensualidad) | 61 contratos ya cobraron de más ($4,382.47 total), 1 cobró de menos ($74) | Analizado a fondo (`ADJ_AC_ERR_12AGO_Analisis_Pagos_61.csv`), mecanismo de reembolso sin decidir todavía | **Analizado, pendiente decisión de negocio** (Caso 06 del informe general) |
| ~2026-08 (evento) / 2026-09-08/09 (encontrado) | El paso automático que reactiva una Late Payment Fee tras confirmación de rechazo del banco falla intermitentemente — la multa se queda `Stopped` para siempre sin que nadie lo note | 88 contratos con cuotas legítimamente vencidas (algunas desde abril) nunca se reintentaron | 100 órdenes reactivadas manualmente (97 vía script + 3 por Gerencia) | **Resuelto** — 96 de 97 cobraron con éxito, ≈$12,046 recuperados |
| ~2026-08 (root cause) / 2026-09-06 (encontrado) | Al retirar la app Chargent se deshabilitó por error el trigger `SM_ChargentTransactionTGR` (mal nombrado — sin relación real con Chargent), la única pieza que sumaba el pago de AC al contrato | 24 contratos con AC ya pagado (julio) nunca se activaron ni empezaron a facturar suscripción — ingreso recurrente bloqueado semanas | Flow permanente `PAYMENT_Accumulate_AC_On_Contract` desplegado 2026-09-02, reemplaza la pieza rota; los 24 contratos activados manualmente | **Resuelto** — sin contratos huérfanos nuevos desde el despliegue |
| 2026-09-06 | `SM_ContractHandler` en MONEE (producción) es una **cáscara vacía** (12 métodos no-op) desde 2026-07-09 — la lógica real completa solo existe en PREPROD; `SM_ContractHandlerTest` en MONEE es la versión 2022 (pre-Chargent), no asigna Banco a Payment Methods ACH → falla PM003 | Toda la lógica del trigger de Contract (activación de assets, status maestro/dependiente) corre como no-op en producción; además bloquea cualquier deploy que dispare `RunLocalTests` | Carlos está sincronizando manualmente MONEE/PREPROD/repo — **NO TOCAR sin confirmar con él primero** (ver `CLAUDE.md` sección 3) | **Abierto, trabajo en curso del propio Carlos** |

---

## Reglas de negocio aprendidas en el camino (para no repetir el mismo error de análisis)

Estas no son bugs — son interpretaciones correctas de estados que a simple vista parecen rotos
pero no lo están. Ver también memoria local de Claude Code (`feedback_*.md`) para el detalle
completo de cada una.

- **`SM_Check_Collection_Status__c = PENDING` o `RETURN`** = el banco todavía está
  procesando/reintentando por su cuenta — no es un rechazo final, no se puede tocar hasta que
  llegue un veredicto (`ACCEPTED`/`COLLECTED` o `NOT_COLLECTED`).
- **Orden `Completed` + Payment en `ACH TRANSMITTED`** = normal, se marcará `ACCEPTED` en cuanto
  llegue el reporte, mientras no venga rechazado.
- **Orden `Canceled` + cero Payments** = puede ser legítimo (se canceló antes de la corrida diaria
  de creación de Payments a las 2:50, no aplicaba para cobro, o error/duplicidad) — no asumir bug.
- **`SM_Id_Salesforce_LCS__c` poblado + `SM_Is_Migrated__c = true`** = el registro llegó así desde
  una migración de datos, no es una brecha operativa del pipeline en vivo.
