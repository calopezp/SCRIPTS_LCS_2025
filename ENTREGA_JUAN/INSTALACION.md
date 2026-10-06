# Instalación — máquina nueva (Juan) — Collections + ACH Transmisión

Pasos para dejar esta carpeta funcionando en tu equipo. Como ya eres usuario administrador de
MONEE con los mismos accesos que se usaban antes, **no hace falta pedir ninguna credencial nueva**
para lo que cubre esta entrega — solo instalar herramientas y confirmar que algunas rutas/alias
coincidan con tu máquina. Al final hay una sección con lo único que sí depende de pedir algo aparte.

---

## 1. Salesforce CLI (`sf`)

Todo corre contra la org de producción vía Salesforce CLI, nunca usuario/contraseña directo.

```bash
# Instalar (si no lo tienes ya)
npm install --global @salesforce/cli
sf --version
```

Autenticarte contra la org de producción, **usando exactamente el alias `MONEE`** — varios scripts
de Python tienen este alias escrito literal (`ORG_ALIAS = "MONEE"`), si lo autenticas con otro
nombre los scripts no van a encontrar la org:

```bash
sf org login web --alias MONEE
sf org list        # debe mostrar MONEE como "Connected"
```

Opcional (solo si vas a validar algo de la migración de Chargent en curso — ver `CLAUDE.md`
sección 3, no es parte del día a día de cobranza):

```bash
sf org login web --alias PREPROD
```

---

## 2. Python 3

Necesitas Python 3.9+ (cualquier versión reciente sirve). Una sola dependencia externa en todo
este paquete: `pdfplumber` (lee los PDFs que manda el banco).

```bash
pip install -r requirements.txt
```

Prueba rápida de que todo importa bien:

```bash
python COLLECTIONS/buscar_payment.py --help
```

---

## 3. Acceso a OneDrive (los PDFs/CSV que sube el banco)

**Actualizado 2026-10-06 — ya no hay rutas fijas de ninguna máquina.** Los scripts que arman el
índice (`COLLECTIONS/build_index.py`, `COLLECTIONS/ACH_REPORTADOS/build_index.py`) resuelven la
carpeta vía `COLLECTIONS/lcs_paths.py`, en este orden:

1. Variable de entorno `LCS_COLLECTIONS_DIR` (ruta completa), si quieres forzar otra ubicación.
2. `%OneDriveCommercial%\COMPILADO COLLECTIONS` — Windows define `OneDriveCommercial`
   automáticamente en cualquier equipo con el OneDrive de la empresa sincronizado (sea
   `C:\OneDrive - LCS` o `C:\Users\<tu usuario>\OneDrive - LCS`, no importa cuál).
3. `C:\OneDrive - LCS\COMPILADO COLLECTIONS` (ubicación histórica, último recurso).

**Lo único que tienes que hacer:** sincronizar (o agregar como acceso directo desde
SharePoint/OneDrive compartido) la carpeta **`COMPILADO COLLECTIONS`**, con ese nombre exacto, en
la **raíz** de tu OneDrive de empresa — no hace falta tocar ningún archivo de código.

Comprobar que la encuentra (desde la raíz del repo, en Git Bash):

```bash
python3 -c "import sys; sys.path.insert(0,'COLLECTIONS'); import lcs_paths; r=lcs_paths.collections_root(); print(r, r.exists())"
```

Debe imprimir la ruta a `COMPILADO COLLECTIONS` y `True`.

**Si no tienes acceso a `COMPILADO COLLECTIONS` todavía** (hoy vive en el OneDrive de Carlos, ver
`TRASPASO_PROCESO.md`), la fuente original de los reportes del banco está en el OneDrive de Elba
Mantilla (`emantilla@legal-credit.com`), carpeta `Collections Campaign\Reportes de Banca`:
- RETURN: https://legalcredit-my.sharepoint.com/personal/emantilla_legal-credit_com/_layouts/15/onedrive.aspx?id=%2Fpersonal%2Femantilla%5Flegal%2Dcredit%5Fcom%2FDocuments%2FDocumentos%2FCollections%20Campaign%2FReportes%20de%20Banca%2FACH%20Returns&ga=1
- COLLECTION: https://legalcredit-my.sharepoint.com/personal/emantilla_legal-credit_com/_layouts/15/onedrive.aspx?id=%2Fpersonal%2Femantilla%5Flegal%2Dcredit%5Fcom%2FDocuments%2FDocumentos%2FCollections%20Campaign%2FReportes%20de%20Banca%2FCheck%20Collection&ga=1

(Sin confirmar todavía si estas son exactamente el mismo contenido que `COMPILADO COLLECTIONS` o
la fuente a partir de la cual Carlos la arma — revisar con él antes de asumir que sincronizar
estas dos alcanza para reemplazarla.)

---

## 4. Correos de notificación — a dónde llegan hoy

Los 8 correos de alerta de `run_daily_new_files.sh` (return codes R02/R10/R04-R13/R07/R16,
duplicados, reversión de timeout) **hoy llegan solo a `clopez@legal-credit.com`** (hardcodeado en
`SM_ReturnCodeNotifier.NOTIFY_EMAIL`, clase Apex en `force-app/main/default/classes/`, no en esta
carpeta de entrega — nunca se definió una lista de Comercial separada, ver `TAREAS_PENDIENTES.md`).

**`scripts/apex/ACH_TRANSMISION/B. Enviar Correo Reporte ACH.apex` tiene el mismo problema, por
separado:** sigue con `ES_PRUEBA = true` y `EMAIL_PRUEBA = clopez@legal-credit.com` — el correo
real del archivo transmitido todavía solo le llega a Carlos, aunque ya tenga cargados los
destinatarios reales del archivo. Ver `TRASPASO_PROCESO.md` para el cambio pendiente el día de la
entrega (pasar a `false` y quitar a Carlos del CC).

**No cambies ninguno de los dos por tu cuenta** — es una decisión de a quién debe llegarle cada
alerta (Comercial, tú, ambos). Si quieres empezar a recibirlos, decide con el equipo la lista
final y actualiza esas direcciones en el código fuente real (no en esta copia) para que el cambio
quede para todos.

---

## 5. Verificación rápida de que todo quedó bien instalado

```bash
cd COLLECTIONS
./run_daily_new_files.sh          # SIN "apply" -- solo preview, no escribe nada en Salesforce
```

Si esto corre sin errores de import de Python ni de conexión a `sf`, y te muestra un preview
(aunque diga "nada nuevo que aplicar"), la instalación quedó correcta — este mismo comando ya
incluye el paso C de ACH Transmisión (confirmar el cargue de ayer) como respaldo automático.

Para los pasos A/B de ACH Transmisión (no tienen modo preview, son Execute Anonymous normales):

```bash
sf apex run -o MONEE --file "scripts/apex/ACH_TRANSMISION/A. Generar File Reporte ACH.apex"
```

Si corre sin error de conexión/compilación, la instalación de esa parte también quedó correcta
(no hace falta ejecutarlo de verdad fuera de tu rutina diaria real solo para probar).

---

## 6. Lo único que sí requiere pedir algo aparte

| Qué | Por qué no está en el código | A quién pedírselo |
|---|---|---|
| Acceso a la carpeta de OneDrive de los reportes del banco (si todavía no la tienes) | Es una carpeta compartida de Microsoft 365, no algo que viaje con el repo | Administrador de Microsoft 365 / Carlos |
| Alta en el correo `clopez@legal-credit.com` o definir uno nuevo para notificaciones | Ver sección 4 — es una decisión de negocio, no un tema de instalación | Comercial / Carlos |
