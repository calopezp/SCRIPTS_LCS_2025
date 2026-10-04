# Tareas ocasionales — SCRIPTS_LCS_2025

## Qué es esto

Scripts/acciones que **no están colgados de ningún proceso recurrente** (no corren en un cron, no
los dispara `run_daily_new_files.sh` ni ningún otro pipeline) — se ejecutan manualmente, de vez en
cuando, cuando aparece un requerimiento puntual (Comercial pide activar un contrato a mano, hay que
registrar un contracargo, hay que migrar un contrato de ACH a Chargebee, etc.). A diferencia de
Collections/ACH Transmisión/Cancelar Contratos (ver `MANUAL_TRASPASO.md` sección 4), nadie espera
que corran todos los días.

**Convención de todos los `.apex` de esta lista:** son Execute Anonymous (se corren con
`sf apex run -o MONEE -f "<archivo>"` o pegando el contenido en VS Code/Workbench). Varios tienen
una bandera `Boolean modoDryRun` / `confirmarActualizacion` / `DRY_RUN` al principio — **siempre
dejarla en `true`/preview la primera pasada** antes de poner `false`/`apply`. Los que no tienen esa
bandera (notados abajo) ejecutan directo apenas los corres — revisar los parámetros con cuidado
antes de darle a "Run".

---

## 1. Activar Contratos

Activación manual de un contrato que quedó en `Payment Process` con el AC ya cobrado, pero que por
algún motivo no se activó solo (el flujo normal es automático vía
`CONTRACT_10_After_Save_Orchestrator`).

| Script | Qué hace | Notas |
|---|---|---|
| `scripts/apex/-Activar_Contrato_Individual_y_Subscription.apex` | Activa UN contrato (marca `Status='Activated'`, `SM_AC_collected__c=true`, etc.) y crea su Subscription Order llamando directo al Flow `CONTRACT_Create_ACH_Subscription_Order` — no depende de que el trigger orquestador lo dispare | Cambiar el `ContractNumber` arriba del archivo y correr. Úsalo cuando ya validaste a mano que el AC está pagado. |
| `scripts/apex/-Activar_Contratos_BATCH.apex` | Misma idea pero con una lista de `ContractNumber` | **Advertencia del propio script: ejecutar de a un contrato a la vez, no varios juntos** — validar cada uno antes de pasar al siguiente |
| `scripts/apex/Subscription_ACH_Active_Contract.apex` | Versión más vieja (2026-08-11) — crea el `SM_ACH_Order__c` tipo Subscription a mano y marca el contrato activado, con `SM_Id_Salesforce_LCS__c` tipo `Manual_<fecha>` | No está claro si sigue vigente o si quedó reemplazada por los dos de arriba — **confirmar con Carlos cuál usar** antes de correrla si tienes duda |

**NO USAR:** `scripts/apex/-ActivarCobroInmediatoChargebee.apex` — está marcado
`DEPRECADO 2026-09-28` en el propio archivo. Dispara un cobro real e inmediato contra la tarjeta
(no es un "activar" pasivo); "programar" una fecha de cobro es una acción exclusivamente manual
desde el dashboard de Chargebee (ver memoria `feedback_chargebee_activar_vs_cobrar`).

---

## 2. Crear Late Payment Fee (u otra orden manual AC/Subscription)

`scripts/apex/-B.New_LPF_Universal_Desc.apex` — un único script "universal" para ACH y Chargebee
(TC). Configurar arriba del archivo:
- `contratoId`, `fechaCobro`
- `ordType`: `'AC'`, `'Late Payment fee'` o `'Subscription'`
- Descuento opcional (`applyDiscount`, con quién lo pidió/aprobó — `userReqDiscount`/`userApprDiscount`)

**No tiene bandera de dry-run** — crea la orden apenas lo corres. Revisar bien los parámetros
(sobre todo `ordType` y `fechaCobro`) antes de ejecutar; no hay preview.

---

## 3. Contracargo (chargeback)

Dos scripts, uno por canal — **detalle completo de la regla de negocio (contracargo = NO es una
reversión, es un segundo payment `REFUNDED`) en `CLAUDE.md` sección 2.2, "Regla R10/R11 vigente"**:

| Script | Canal | Identifica el contracargo por |
|---|---|---|
| `scripts/apex/-CONTRACARGO_ACH_R10_R11.apex` | ACH | `SM_Return_code__c` (R10/R11) |
| `scripts/apex/-CONTRACARGO_CHARGEBEE.apex` | Chargebee/TC | `SM_Authorization_Code__c` |

Ambos: `DRY_RUN` por defecto, sin triggers (`SM_TriggerHandler.avoidAllHandlerExcecution`). El
re-cobro automático (Late Payment Fee ACH / Charge Request TC) es **opcional, a evaluar caso por
caso** — no aplica si el contracargo es por un error de LCS (ver CLAUDE.md, caso de doble
transmisión real).

---

## 4. Crear Notas Masivas

`scripts/apex/-CrearNotasMasivas.apex` — crea un `Task` (actividad, no el objeto Note) en un lote
de `ContractNumber`, usando una plantilla de asunto/descripción predefinida según `itemType`
(1 a 11 hoy, `when else` cae en una genérica "Registro de Nota"). Ejemplos de plantillas ya
armadas: docs/evidencias pendientes (1, 2, 9), recordatorio de cobro declinado (3), disputa
trabajada (4), Subscription Stopped por validación de duplicados/cuenta ACH/pagos futuros (5-7),
Subscription Initiated por cumplimiento (8), hold por falta de docs (10), cambio de día de pago
(11).

**Antes de usarlo:** el `Owner` de cada plantilla está hardcodeado a un Id de usuario
(`0051U000001MRFeQAO`) — confirmar que ese Id sigue siendo válido/la persona correcta antes de
correr un lote grande. Si necesitas una plantilla nueva, agregar un `when <N>` nuevo siguiendo el
mismo patrón.

---

## 5. Customer Cancellation (contrato en negociación de cancelación)

**El mecanismo real y normal es un botón en Salesforce, no un script:** el Quick Action LWC
`sM_CustomerCancellationLWC` (+ controller `SM_CustomerCancellationActionController.cls`), en el
layout del registro `Contract`. Marca `SM_Customer_Cancellation__c = true`, detiene (`Stopped`) los
`SM_ACH_Order__c` activos del contrato, y muestra un preview de los Payments en `ACH PENDING`
asociados — **solo un usuario con profile System Administrator puede confirmar el borrado de esos
Payments** (requiere autorización porque ya los generó el batch diario).

Scripts de soporte para barridos masivos (cuando hay varios contratos ya marcados que necesitan
limpieza, no uno solo vía el botón):

| Script | Qué hace |
|---|---|
| `scripts/apex/-CustomerCancellation.apex` | Detiene los `SM_ACH_Order__c` activos de **todos** los contratos con `SM_Customer_Cancellation__c=true` — bandera `confirmarActualizacion` (preview/apply). Nota propia del script: el bloqueo real de cobro ya lo hacen `SM_PaymentBatch`/`SM_PaymentHelper.createPayment`; esto es higiene/visibilidad del status, no la barrera de seguridad en sí |
| `scripts/apex/-CustomerCancellation_v3.apex` | Para contratos ya marcados: identifica Payments ACH ya resueltos a un estado cerrado (`NOT_COLLECTED`/`COLLECTED`/`ACCEPTED`/`REFUNDED`/etc.) y las Orders que ya no tienen ningún payment en proceso, para cerrarlas/limpiarlas |

---

## 6. Pasar contratos de ACH a TC y viceversa — **incompleto, confirmado 2026-10-04**

**ACH → Chargebee (TC): sí hay un script maduro.**
`scripts/apex/-CancelarACHOrdersSwitchTC.apex` (2026-09-29) — cancela (no `Stopped`, `Canceled`
directo) los `SM_ACH_Order__c` activos de un contrato que **ya** cambió a
`SM_Payment_methods__c='Credit Card'`, solo si no tiene ningún payment ACH bloqueante sin resolver.
Trae guards de seguridad documentados en el propio archivo y deja nota de auditoría
(`SM_AutomationLogHelper.appendNote`). `DRY_RUN` por defecto.

**Chargebee (TC) → ACH: NO hay un script confiable todavía.**
`scripts/apex/-TC_to_ACH_Simulacion.apex` (2026-09-29) es justamente eso — una **simulación**: valida
qué falta para completar la migración (cancelar Invoice → Request → Subscription de Chargebee, en
ese orden; crear el ACH Order Subscription; crear un ACH Order Late Payment Fee por cada ciclo sin
pagar en Chargebee) pero no ejecuta el flujo completo de forma automática. Existe también
`scripts/apex/TC_to_ACH.apex` (2026-08-11, sin "Simulacion" en el nombre, más viejo) y
`scripts/apex/-A.MASTER_2026_v6 ach-tc-Batch.apex` (agosto 2026, parece una herramienta de un caso
puntual anterior con filtro de PTP por mes, no el flujo general) — **ninguno de los tres es hoy un
proceso terminado y validado**, confirmar con Carlos antes de usar cualquiera de estos tres en un
caso real; por ahora la conversión TC→ACH se resuelve mitad manual, validando cada paso a mano
contra Chargebee.

→ Agregado a `TAREAS_PENDIENTES.md` para no perderlo de vista.

---

## 7. Consulta de Agreements marcados como Firmados sin fecha de firma

Ya cubierto por el monitor automático diario (ver tabla de Monitoreos abajo,
`SM_AgreementSignedDateMonitor.cls`) — manda correo si encuentra alguno. Si necesitas revisarlo
**en el momento**, sin esperar el correo de las 8:15 AM, el query exacto que usa el monitor es:

```sql
SELECT Id, Name, echosign_dev1__Contract__r.ContractNumber, Owner.Alias,
       echosign_dev1__Status__c, echosign_dev1__DateSigned__c
FROM echosign_dev1__SIGN_Agreement__c
WHERE echosign_dev1__Status__c = 'Signed'
  AND echosign_dev1__DateSigned__c = null
```

(`sf data query -o MONEE -q "..."`). Causa típica (ver `BITACORA_HALLAZGOS_TECNICOS.md`
2026-09-14): el callback de Adobe Sign no entregó `DateSigned` o llegó en un orden distinto al
esperado, y algo más forzó el `Status` a `'Signed'` igual. El monitor solo reporta, no corrige nada
solo.

---

## 8. Monitoreos implementados

Inventario rápido — **la tabla completa y autoritativa (horarios exactos, estado `WAITING`/`PAUSED`
confirmado en vivo) vive en `MANUAL_TRASPASO.md` sección 5.2, no la dupliques de memoria si vas a
tocar algo, ve a esa fuente.**

| Monitor (clase Apex) | Qué vigila | Cuándo corre | Acción si encuentra algo |
|---|---|---|---|
| `SM_TriggerPanelMonitor.cls` | Que `SM_Trigger_Panel__mdt` no se haya desviado del baseline esperado (nadie reactivó Chargent por accidente, nadie apagó un trigger real) | Diario 8:20 AM España | Correo `[OK]` o `[REVISAR]` — nunca corrige solo |
| `SM_AgreementSignedDateMonitor.cls` | Agreements `Status='Signed'` sin `DateSigned` (ver punto 7 arriba) | Diario 8:15 AM España | Solo reporta |
| `SM_ACH_Flow_Monitor.cls` ("SM Contracts Activated Monitor - Daily") | Contratos activados en las últimas 24h sin su orden AC/Subscription creada correctamente (huecos de automatización nuevos, no los 84 legacy de `CLAUDE.md` 2.3) | Diario ~2:00 PM org (pendiente reprogramar cuando España salga de horario de verano, ver `TAREAS_PENDIENTES.md`) | Solo reporta |
| `SM_WeeklyComercialDigestScheduler.cls` → `SM_ReturnCodeNotifier.sendWeeklyComercialDigest()` | Compilado semanal de los 5 return codes definitivos (R02/R04+R13/R07/R10+R11/R16) | Lunes 8:00 AM | Correo resumen para Comercial |

Todos mandan hoy solo a `clopez@legal-credit.com` (`NOTIFY_EMAIL`) — pendiente que se defina la
lista real de destinatarios de Comercial (ver `TAREAS_PENDIENTES.md`).
