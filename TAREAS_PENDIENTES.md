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
| 2026-09-13 | Re-auditar el resto de los pagos `PENDING` de los **últimos 6 meses** (marzo-septiembre 2026, no incluye 2025) con la lógica de fecha corregida (parser de nombre de archivo, no orden de fila del CSV) | El cruce original puede tener más huecos como los 15 nuevos que aparecieron solo en el Grupo B — alcance real del backlog desconocido hasta re-correrlo | Carlos dijo que lo puede pedir después — no es urgente, pendiente que lo confirme |
| 2026-09-13 | Horario del job "SM Contracts Activated Monitor - Daily" | Reprogramar el cron de `0 0 14 * * ?` a `0 0 13 * * ?` (sigue interpretándose en Europe/Madrid, el timezone personal de Carlos) cuando Madrid salga de horario de verano (~fin de octubre 2026) — si no, la corrida se corre 1 hora y deja de caer a las 8:00 AM Puerto Rico (PR no tiene DST) | Esperando la fecha del cambio de horario en España |
| 2026-09-10 | Contrato 00318139 | Confirmar que el batch diario efectivamente transmitió el AC (se le asignó fecha de próxima transacción el 15-ago, pero al cierre de la sesión seguía sin ningún Payment creado) | Nada — solo falta revisar en la próxima sesión |
| 2026-09-09 | Caso 06 informe general — lote `ADJ_AC_ERR_12AGO` | Decidir el mecanismo de reembolso de $4,382.47 (61 contratos cobrados de más) — reembolso directo, crédito al próximo ciclo, o ajuste contra próxima cuota | Decisión de negocio de Carlos |
| 2026-09-05 | Caso 05 informe general — doble cobro 29-jul/24-26-ago | 6 órdenes ($544) siguen sin veredicto final del banco, 15+ días — candidato a escalar con el banco/procesador | Esperando al banco — no se puede tocar hasta veredicto (`ACCEPTED` o `NOT_COLLECTED`) |
| 2026-09-10 | Caso 01 informe general | 2 cuotas de agosto (00316731, 00316732) con primer rechazo, el banco las sigue reintentando | Esperando al banco — no tocar |
| 2026-09-10 | 4 contratos flagueados en la reconciliación del backlog | `00270432` (5 meses seguidos sin cobrar), `00275989` (5 fallos confirmados), `00316097` (6 de 7 meses fallidos), `00315643` (3 de 9 meses fallidos) — candidatos a revisión de cobranza/cancelación | Carlos pidió dejarlo en espera, no investigar todavía |
| 2026-09-06 | Migración de Chargent — `SM_ContractHandler`/`SM_ContractHandlerTest` | Sincronizar manualmente MONEE/PREPROD/repo (MONEE tiene la cáscara vacía de `SM_ContractHandler`; PREPROD tiene la lógica real) | Carlos lo está validando y sincronizando él mismo — **NO TOCAR sin confirmar primero** (ver `CLAUDE.md` sección 3) |
| 2026-09-06 | Winter '27 (aplica a MONEE 10-oct-2026) — "Enable Profile Filtering" | Correr el Test Run / *login-as* no-admin para confirmar que `SM_TestSmartDataFactory` y los tests de `SM_ContractHandlerTest` siguen pasando bajo el nuevo enforcement | Antes del 10-oct-2026; toca clases de la migración de Chargent, coordinar con Carlos |
| 2026-09-06 | Winter '27 — "Adopt Authorized Email Domains" | Confirmar con Carlos si alguna vez se pidió a Salesforce Support desactivar la verificación de cambio de email para MONEE | Requiere que Carlos lo confirme, no es verificable desde el código |
| — | Informe general — Caso 03 / "Otros ajustes" | Lista de contratos original nunca se guardó; se intentó reconstruir (2026-09-10) sin éxito | **Cerrado por ahora** (ver `BITACORA_HALLAZGOS_TECNICOS.md` y handoff sección 2) — no reintentar sin una pista nueva |
| 2026-09-12 | `SM_ACPaymentActivationHandler` no tiene la misma paridad de exclusiones que el flow de ACH (`CONTRACT_Create_ACH_Subscription_Order`/`PAYMENT_Accumulate_AC_On_Contract`) — no chequea `Is_Test_Contract__c`, `Is_VIP_Contract__c`, `SM_Customer_Cancellation__c` ni `Contract_Type__c='Dependent'`, solo status cerrados y `SM_Requires_AC_Payment__c` | En la práctica no debería importar (test/VIP no deberían tener pagos ChargeBee reales; dependientes no suelen tener `SM_Requires_AC_Payment__c=true`), pero no está garantizado por código | Pendiente decidir si se agregan esos mismos guards al handler para paridad total, o se deja así — no se tocó en esta sesión |
| 2026-09-12 | 15 contratos con Fee/Late payment fee `ACCEPTED` sin que el AC se haya pagado nunca (`00317665, 00317717, 00317745, 00317772, 00317795, 00317826, 00317881, 00317948, 00317970, 00318036, 00318040, 00318101, 00318141, 00318153, 00318175`) | Sugiere que el cobro de Fee/Subscription no está esperando a que el AC se complete — posible brecha de negocio separada, no investigada | No investigado — detectado como efecto colateral de validar la lista de 26 candidatos ChargeBee, fuera del alcance pedido |
| 2026-09-13 | **3 órdenes AC duplicadas** creadas por el bug de `CONTRACT_Create_ACH_AC_Order` (ya corregido) al activar `00318054`, `00317976`, `00317929`: `ACH-29449` ($139), `ACH-29448` ($129), `ACH-29452` ($139) — todas `Pending` con fecha de transacción vencida | Decidir si se cancelan (`SM_Payment_Status__c = 'Canceled'`) antes de que el batch diario de cobro (corre Lun-Vie) las recoja e intente cobrar el AC por segunda vez a estos 3 clientes | **Urgente** — esperando confirmación explícita de Carlos (pidió "solo el fix" el 2026-09-13, no autorizó todavía cancelar las 3 órdenes) |
| 2026-09-13 | 5 contratos ACH restantes con AC pagado completo (validado por Payments) pero no activados: `00317934` ($119), `00317935` ($119), `00317965` ($99), `00318211` ($99), `00318375` ($129) | Mismo backfill que `00317929` (ya hecho) — activar + Subscription Order, ahora que el bug de duplicado AC está corregido | Esperando confirmación de Carlos para continuar el backfill |
| 2026-09-13 | Contrato `00317786`: AC pagado **doble** ($198 en vez de $99) — 2 órdenes AC `Completed` separadas (`ACH-27588`, `ACH-28190`) | Decidir mecanismo (reembolso, crédito, ajuste) antes de activar — no es un simple backfill | Decisión de negocio de Carlos |
| 2026-09-13 | Contrato `00317534`: AC partido en 2, solo la mitad ($59.5 de $119) `ACCEPTED`, la otra mitad `REJECTED` sin orden asociada | No cumple "AC completo" — necesita gestión de cobranza (reintentar la mitad rechazada), no activación automática | Tema de cobranza, no de automatización |
| 2026-09-13 | Contrato `00318313`: Credit Card, no migrado, sin `CB_Subscription__c` NI ninguna `SM_ACH_Order__c` — ningún mecanismo de cobro configurado en absoluto | Investigar por qué nunca se le vinculó una suscripción de ChargeBee ni se generó una orden ACH — parece que este contrato nunca fue realmente onboardeado para cobro | No investigado todavía |

---

## Cerrado recientemente

| Fecha de cierre | Tema | Resultado |
|---|---|---|
| 2026-09-13 | 400 `SM_Payment__c` `PENDING` transmitidos en 2025 (incl. la discrepancia de los 137 con `SM_Id_Salesforce_LCS__c` empezando con "Collected") | Carlos decidió no trabajar pagos del año pasado — descartado, no se retoma. Nada se tocó, todo quedó como estaba |
| 2026-09-13 | Grupo B ampliado — 35 pagos `Fee`/Subscription/Monthly en 21 contratos | 35/35 aplicados a `ACCEPTED`/`COLLECTED` ($2,860 total), órdenes ACH sin tocar (mensuales recurrentes) |
| 2026-09-13 | 6 pagos sin fecha confiable de reporte, solo en `ResumenOctNovDec2025.pdf`: `PY-01746975, PY-01747009, PY-01755001, PY-01756594, PY-01756733, PY-01756787` | Carlos decidió omitirlos — no se persigue más, quedan `PENDING` tal cual |
| 2026-09-13 | `PY-01812404` (contrato `00316911`) — único pago tipo AC de los 28 confirmados `COLLECTED` | Confirmado con el reporte `Check Collections April 10 2026.pdf` (el más reciente de los 3 reportes que tocan este pago) que el veredicto final del banco es `COLLECTED`. La orden ACH ya estaba `Completed` y el contrato ya `Activated`/`SM_AC_collected__c=true` (nadie los desincronizó) — solo el `SM_Payment__c` estaba atrasado. Actualizado `Payment_Status__c='ACCEPTED'`, `SM_Check_Collection_Status__c='COLLECTED'` con `avoidAllHandlerExcecution=true`; verificado 0 DML adicional (sin efectos secundarios) |
| 2026-09-12/13 | Activación de contrato al pagar AC — ChargeBee/Credit Card, ACH, y el Subscription Order de ACH | 4 bugs reales encontrados y corregidos (handler nuevo ChargeBee/CC, flow ACH extendido, versión 2 sin activar de `CONTRACT_Create_ACH_Subscription_Order`, `CONTRACT_Create_ACH_AC_Order` creaba AC duplicada). Backfill: 11 contratos ChargeBee/CC + 3 ACH activados (`00318054`, `00317976`, `00317929`) — **los 3 ACH terminaron con una orden AC duplicada por el 4to bug**, ver fila abajo. Ver `BITACORA_HALLAZGOS_TECNICOS.md` |
| 2026-09-10 | Bug `SM_Chargent_Orders_Transaction__c` | Corregido, desplegado a producción, validado con un caso real |
| 2026-09-10 | Backlog $4,331.50 (50 pagos) | 50/50 aplicados |
| 2026-09-10 | `PY-01876062` y `PY-01810250` (bug contrato Cancelado) | Ambos resueltos, aplicados manualmente |
| 2026-09-10 | Script `SM_PaymentTrigger` toggle | Descartado por Carlos, eliminado del repo |
| 2026-09-10 | 1,557 pagos "ruido histórico" | Omitido por decisión explícita de Carlos, no se investiga |
| 2026-09-10 | Conector "Salesforce - Beta" | Descartado por decisión explícita de Carlos — no se va a seguir intentando autorizar; `sf` CLI cubre las consultas de solo lectura necesarias |
