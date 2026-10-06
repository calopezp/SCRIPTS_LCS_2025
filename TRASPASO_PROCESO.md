# Traspaso del proceso — checklist

Carlos López (`clopez@legal-credit.com`, usuario Salesforce `0051U000007bbx5QAA`) deja la empresa
y el proceso. **Objetivo: que NADA dependa de Carlos, de su cuenta, ni de sus máquinas.** Quien
reciba el proceso es administrador de Salesforce y tiene OneDrive de la empresa, igual que Carlos.

## Regla del destinatario (confirmada por Carlos 2026-10-06)

- El día de la entrega la empresa indicará **qué correo / qué usuario** recibe todo.
- **Si por cualquier razón no queda documentado otro:** todo lo que hoy está registrado con el
  correo o el usuario de Carlos pasa a **Juan Duarte** — correo `jduarte@legal-credit.com`, usuario
  Salesforce `juanduarte@legal-credit.com` (Id `0058W00000CNeHuQAL`, System Administrator, activo).
- Destinatario definitivo: `________________` (llenar el día de la entrega).

## Historial de transmisiones ACH — dónde vive (no depende de ninguna máquina)

Desde el 2026-10-01 el proceso nuevo (`scripts/apex/ACH_TRANSMISION/`, pasos A→D) deja los CSV
`ACH_<fecha>_<SUFIJO>.csv` **solo en Salesforce Files**; ya no se dejan en OneDrive. El histórico
queda disponible en:

1. **Salesforce** — los CSV (Files, buscar `ACH_`) + un `SM_TransactionLog__c` por payment
   transmitido (todo 2026 completo, ~1.5–2.4k/mes) + `SM_Transmission_Date_ACH_File__c` en el payment.
2. **OneDrive** `COMPILADO COLLECTIONS\ACH Reportados` — archivos hasta el 2026-10-01.
3. **El repo** — `COLLECTIONS/ACH_REPORTADOS/index/` (índice) y `sf_files/` (copias locales de los
   Files de Salesforce), versionados en git. `build_index.py` combina ambas fuentes; desde
   `SF_PRIMARY_FROM = 2026-10-01` los Files de Salesforce cuentan como transmisión real.

**Decisión:** NO cargar el histórico de OneDrive a Salesforce Files — los pasos B y C buscan
`ACH_<fecha>%` en ContentVersion y A los usa para no retransmitir; un histórico subido podría
reconfirmarse o meter ruido en ese control.

## Checklist (marcar al completar)

### Antes de la entrega — sin depender del destinatario
- [x] Indexador ACH con Salesforce Files como fuente primaria (commit `9049583`).
- [ ] Ruta de OneDrive autodetectada (`%OneDriveCommercial%`) en vez de `C:\OneDrive - LCS` fijo
      (19 scripts bajo `COLLECTIONS/`).
- [ ] La corrida diaria copia los CSV nuevos de Salesforce a
      `ACH Reportados\Desde Salesforce\` (para quien revise OneDrive a mano).
- [ ] Destinatario de correos centralizado en un solo lugar (Custom Label), para que el día de la
      entrega sea un solo cambio en Setup en vez de editar archivo por archivo.
- [ ] Guía "día 1" para la persona nueva: instalar Git, Git Bash, Python 3, Salesforce CLI, VS Code
      (+ Claude Code); `git clone`; `sf org login web -a MONEE`; orden del proceso diario.

### Lo tiene que hacer Carlos / TI (desde sus cuentas)
- [ ] **Repo GitHub** — hoy en la cuenta personal `calopezp/SCRIPTS_LCS_2025`. Transferir a una
      cuenta/organización de la empresa y dar acceso a la persona nueva.
- [ ] **Carpeta OneDrive `COMPILADO COLLECTIONS`** — hoy en el OneDrive de Carlos. Al desactivar su
      cuenta M365 se borra tras la retención. Mover a un SharePoint/Teams de la empresa (o cambiar
      dueño) y que la persona nueva la sincronice con el mismo nombre en la raíz de su OneDrive.
- [ ] **Salesforce CLI** en la máquina nueva autenticado con alias **`MONEE`** (los scripts lo usan
      fijo) y, si aplica, `clopez@legal-credit.com.preprod` → su propio usuario de PREPROD.

### El día de la entrega — cambiar a <destinatario> (con confirmación, tocan producción)
- [ ] **Jobs programados creados por Carlos** — se detienen al desactivar su usuario. Reprogramar
      con el usuario nuevo (abortar el viejo y volver a programar):
      `SM Contracts Activated Monitor - Daily`, `SM_AgreementSignedDateMonitor_Daily`,
      `SM_TriggerPanelMonitor_Daily` (`scripts/apex/Schedule_Trigger_Panel_Monitor.apex`),
      `SM_WeeklyComercialDigest_Monday`, `DataExport` (Setup → Data Export).
      En pausa (Chargent, no reactivar): `RPT chargent TC`, `RPT- ACH Payment`.
- [ ] **Correo `clopez@legal-credit.com` fijo** en:
  - Apex desplegado: `SM_ACH_Flow_Monitor`, `SM_AgreementSignedDateMonitor`,
    `SM_ReturnCodeNotifier`, `SM_TriggerPanelMonitor` (requiere deploy con `RunSpecifiedTests`).
  - Metadata: `SM_Payment__c.workflow-meta.xml` (alerta de email), carpetas `CollectionsFolder`
    de reports/dashboards (compartidas con Carlos).
  - Scripts del pipeline diario: `COLLECTIONS/notify_*.apex` (7), `activar_ach_chronic_unpaid.apex`,
    `ACH_TRANSMISION/B. Enviar Correo Reporte ACH.apex`.
- [ ] **OwnerId de Carlos fijo (`0051U000007bbx5QAA`)** — no se pueden asignar Tasks a un usuario
      inactivo, el insert fallaría: `CancelarContratosRunner.cls`, `CrearTASK.apex`,
      `-CrearNotasMasivas.apex`, `-CONTRACARGO_ACH_R10_R11_*`, `-CrearTasks_*`, `AgreementMaintenance.apex`
      y otros bajo `scripts/apex/` (`grep -rl 0051U000007bbx5QAA`). Los de `scripts/apex/Archivo/`
      son históricos, no hace falta tocarlos.
- [ ] Flow `ACH_ORDER_Subscription_Stopped_Monitoring` usa `$User` (quien detiene) — no depende de
      Carlos, no requiere cambio.
- [ ] Revisar `CLAUDE.md` y skills: reemplazar referencias a "Carlos"/`clopez` como destinatario
      de reportes por el destinatario nuevo.
