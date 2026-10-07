# Mis pendientes — Carlos (no forma parte de la entrega a Juan)

## Caso 06 — lote ADJ_AC_ERR_12AGO: reembolso de $4,382.47 (60 contratos sobrecobrados)

**Estado:** decisión de mecanismo pendiente. Por ahora no se aplica nada.

**Opción elegida como propuesta:** crédito en el próximo ciclo. Reducir `SM_Total__c` de la próxima Subscription en el monto sobrecobrado, con nota `AUTO:` y un Task por contrato. Primero dry-run, después apply.

**Pendientes para retomar:**
- 27 contratos tienen un sobrecobro mayor que su mensualidad. Quedan $1,107.65 que habría que descontar en ciclos siguientes. Falta definir la regla de arrastre.
- 5 contratos no tienen Subscription activa. Falta decidir la vía (devolución directa o aplicar a una LPF).
- No se tocan fechas de Subscription para esto.
- Caso aparte: `00316168` cobró $74 de menos. Decidir si corresponde cobrarle la diferencia.

**Archivos:** `COLLECTIONS/ACH_REPORTADOS/ADJ_AC_ERR_12AGO_Analisis_Pagos_61.csv`, `ADJ_AC_ERR_12AGO_candidatos_refund.csv`, `ADJ_AC_ERR_12AGO_ultimos2cobros.csv`.

## `00316826` — día de pago por fin de semana sin restaurar

**Estado:** por revisar (anotado 2026-10-07).

El contrato tiene `Reasons_for_change__c = 'Date Restored (Weekend)'` desde hace más de 8 días. El utilitario `UTILITARIOS/-LIMPIA_ChangePaymentDay.apex` (en dry-run) le restauraría el día de pago original (30) y limpiaría la marca. Confirmar y correrlo en real, o dejarlo.

## `00317976` — Subscription creada quedó en 14-nov (sábado)

**Estado:** por revisar (anotado 2026-10-07).

El 07-oct se crearon, a pedido de Comercial, las LPF de agosto, septiembre y octubre (ACH-30305, ACH-30306, ACH-30307; $79 sin multa, cobro 07-oct) y la Subscription que faltaba (ACH-30308), con inicio 16-ago y próximo cobro 16-nov. Al insertarla, `SM_ACHOrderHandler` ("suggested business day") recalculó inicio, próximo cobro y fin a **14-nov (sábado)**. Decidir si se corrige a 16-nov a mano. Script: `TEMP/fix_00317976_cuotas_y_subscription_2026-10-07.apex`.

## Entrega final — prompt para el bot de Slack (Claude) que arma Juan

**Estado:** para hacer al final, cuando Carlos indique "entrega final" (anotado 2026-10-07).

Diseñar el prompt para que el bot de Slack tome el pedido de un agente tal como lo escribe (ej. "crea facturas SIN FEE de agosto, sept y oct, cobro INMEDIATO <contrato>") y lo resuelva con los scripts de la entrega:
- **El prompt interpreta, los scripts ejecutan:** traduce el vocabulario de los agentes ("facturas" = LPF en ACH / Charge Request en Chargebee; "sin fee" = sin multa; "inmediato" = próximo día hábil; meses = una cuota por mes) y elige el script y sus parámetros (`-COBRO_A_PEDIDO`, `-CREAR_ORDEN_ACH_MANUAL`).
- **Flujo:** pedido en Slack → dry-run → vista previa en el hilo → aprobación de una persona autorizada → aplicar, con marca `AUTO:` "pedido por <agente> vía Slack".
- **Cuándo se detiene a preguntar:** contrato sin Subscription, cuotas que todavía no vencen, fechas que puedan generar cobro doble, contrato VIP/Test o con Customer Cancellation, y cualquier caso que los scripts no cubran.
- **Antes de diseñarlo, saber del bot de Juan:** qué acceso tiene a Salesforce (¿ejecuta Apex anónimo o solo consulta?), con qué usuario escribe en MONEE, y si ya tiene un paso de aprobación en Slack.
- **Prerrequisito propuesto (no aprobado todavía):** agregar a `-CREAR_ORDEN_ACH_MANUAL` los parámetros opcionales `fechaInicio` y `fechaProximoCobro`, para cubrir con un solo script el caso "contrato sin Subscription: cuotas atrasadas o adelantadas" (hoy se resolvió con un script puntual en `TEMP/`).
- El resultado va como documento para Juan, junto con todo lo trabajado en la entrega.
