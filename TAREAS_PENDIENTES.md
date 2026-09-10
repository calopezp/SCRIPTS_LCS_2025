# Tareas pendientes — SCRIPTS_LCS_2025

## Cómo usar este archivo

Lista acumulativa de temas que quedaron **abiertos, en espera, o deliberadamente pausados** — no
importa el motivo (falta una decisión de Carlos, está bloqueado por otra cosa, se dejó para después
a propósito, o simplemente no se ha retomado). Cuando Carlos pregunte "¿qué tenemos pendiente?" en
cualquier sesión, **leer este archivo primero** en vez de reconstruir la respuesta desde cero.

**Reglas de mantenimiento:**
- Agregar una fila cada vez que algo quede abierto/pausado, con suficiente contexto para retomarlo
  sin tener que releer toda la conversación original.
- Cuando algo se resuelve, **mover la fila a la sección "Cerrado recientemente"** (no borrarla del
  todo enseguida — sirve de confirmación si Carlos pregunta "¿ya se resolvió tal cosa?"). Después de
  un tiempo prudente se puede limpiar del todo.
- Si algo pendiente resulta ser en realidad un bug/hallazgo técnico real (no una decisión de
  negocio ni una tarea operativa), también anotarlo en `BITACORA_HALLAZGOS_TECNICOS.md`.

---

## Pendientes abiertos

| Desde | Tema | Qué falta | Bloqueado por / contexto |
|---|---|---|---|
| 2026-09-10 | Contrato 00318139 | Confirmar que el batch diario efectivamente transmitió el AC (se le asignó fecha de próxima transacción el 15-ago, pero al cierre de la sesión seguía sin ningún Payment creado) | Nada — solo falta revisar en la próxima sesión |
| 2026-09-09 | Caso 06 informe general — lote `ADJ_AC_ERR_12AGO` | Decidir el mecanismo de reembolso de $4,382.47 (61 contratos cobrados de más) — reembolso directo, crédito al próximo ciclo, o ajuste contra próxima cuota | Decisión de negocio de Carlos |
| 2026-09-05 | Caso 05 informe general — doble cobro 29-jul/24-26-ago | 6 órdenes ($544) siguen sin veredicto final del banco, 15+ días — candidato a escalar con el banco/procesador | Esperando al banco — no se puede tocar hasta veredicto (`ACCEPTED` o `NOT_COLLECTED`) |
| 2026-09-10 | Caso 01 informe general | 2 cuotas de agosto (00316731, 00316732) con primer rechazo, el banco las sigue reintentando | Esperando al banco — no tocar |
| 2026-09-10 | 4 contratos flagueados en la reconciliación del backlog | `00270432` (5 meses seguidos sin cobrar), `00275989` (5 fallos confirmados), `00316097` (6 de 7 meses fallidos), `00315643` (3 de 9 meses fallidos) — candidatos a revisión de cobranza/cancelación | Carlos pidió dejarlo en espera, no investigar todavía |
| 2026-09-06 | Migración de Chargent — `SM_ContractHandler`/`SM_ContractHandlerTest` | Sincronizar manualmente MONEE/PREPROD/repo (MONEE tiene la cáscara vacía de `SM_ContractHandler`; PREPROD tiene la lógica real) | Carlos lo está validando y sincronizando él mismo — **NO TOCAR sin confirmar primero** (ver `CLAUDE.md` sección 3) |
| 2026-09-06 | Winter '27 (aplica a MONEE 10-oct-2026) — "Enable Profile Filtering" | Correr el Test Run / *login-as* no-admin para confirmar que `SM_TestSmartDataFactory` y los tests de `SM_ContractHandlerTest` siguen pasando bajo el nuevo enforcement | Antes del 10-oct-2026; toca clases de la migración de Chargent, coordinar con Carlos |
| 2026-09-06 | Winter '27 — "Adopt Authorized Email Domains" | Confirmar con Carlos si alguna vez se pidió a Salesforce Support desactivar la verificación de cambio de email para MONEE | Requiere que Carlos lo confirme, no es verificable desde el código |
| 2026-09-06 | Conector "Salesforce - Beta" | Sigue sin poder autorizar (error `ofid_d0347292fb8fe49c`) | Mientras tanto, `sf` CLI cubre las consultas de solo lectura necesarias |
| — | Informe general — Caso 03 / "Otros ajustes" | Lista de contratos original nunca se guardó; se intentó reconstruir (2026-09-10) sin éxito | **Cerrado por ahora** (ver `BITACORA_HALLAZGOS_TECNICOS.md` y handoff sección 2) — no reintentar sin una pista nueva |

---

## Cerrado recientemente

| Fecha de cierre | Tema | Resultado |
|---|---|---|
| 2026-09-10 | Bug `SM_Chargent_Orders_Transaction__c` | Corregido, desplegado a producción, validado con un caso real |
| 2026-09-10 | Backlog $4,331.50 (50 pagos) | 50/50 aplicados |
| 2026-09-10 | `PY-01876062` y `PY-01810250` (bug contrato Cancelado) | Ambos resueltos, aplicados manualmente |
| 2026-09-10 | Script `SM_PaymentTrigger` toggle | Descartado por Carlos, eliminado del repo |
| 2026-09-10 | 1,557 pagos "ruido histórico" | Omitido por decisión explícita de Carlos, no se investiga |
