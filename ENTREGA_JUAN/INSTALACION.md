# Instalación — máquina nueva (Juan)

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

Los scripts que arman el índice (`COLLECTIONS/build_index.py`,
`COLLECTIONS/ACH_REPORTADOS/build_index.py`) leen los reportes del banco directo de una carpeta de
OneDrive sincronizada en el disco local. **Hoy esa ruta está escrita así, literal, en el código:**

```
C:\OneDrive - LCS\COMPILADO COLLECTIONS\ACH Returns\2026
C:\OneDrive - LCS\COMPILADO COLLECTIONS\Check Collection\2026
C:\OneDrive - LCS\COMPILADO COLLECTIONS\ACH Reportados
```

**Antes de correr nada en modo `apply`:**
1. Confirma que tienes acceso a esa librería de OneDrive compartida (pídela si no la ves).
2. Verifica en qué ruta exacta queda montada en TU máquina — el cliente de OneDrive a veces la
   sincroniza bajo `C:\Users\<tu usuario>\OneDrive - LCS\...` en vez de `C:\OneDrive - LCS\...`.
   Si es distinto, hay que actualizar la constante (`SOURCE_DIR` / `RETURNS_SOURCE_DIR` /
   `COLLECTIONS_SOURCE_DIR`) en esos dos archivos para que apunte a tu ruta real.
3. Corre primero en modo preview/dry-run (sin `apply`) y confirma que el script SÍ encuentra
   archivos antes de aplicar nada.

---

## 4. Correos de notificación — a dónde llegan hoy

Los 8 correos de alerta de `run_daily_new_files.sh` (return codes R02/R10/R04-R13/R07/R16,
duplicados, reversión de timeout) **hoy llegan solo a `clopez@legal-credit.com`** (hardcodeado en
`SM_ReturnCodeNotifier.NOTIFY_EMAIL`, clase Apex en `force-app/main/default/classes/`, no en esta
carpeta de entrega — nunca se definió una lista de Comercial separada, ver `TAREAS_PENDIENTES.md`).

**No cambies esto por tu cuenta** — es una decisión de a quién debe llegarle cada alerta
(Comercial, tú, ambos). Si quieres empezar a recibirlos, decide con el equipo la lista final y
actualiza esas direcciones en el código fuente real (no en esta copia) para que el cambio quede
para todos.

---

## 5. Verificación rápida de que todo quedó bien instalado

```bash
cd COLLECTIONS
./run_daily_new_files.sh          # SIN "apply" -- solo preview, no escribe nada en Salesforce
```

Si esto corre sin errores de import de Python ni de conexión a `sf`, y te muestra un preview
(aunque diga "nada nuevo que aplicar"), la instalación quedó correcta.

---

## 6. Lo único que sí requiere pedir algo aparte

| Qué | Por qué no está en el código | A quién pedírselo |
|---|---|---|
| Acceso a la carpeta de OneDrive de los reportes del banco (si todavía no la tienes) | Es una carpeta compartida de Microsoft 365, no algo que viaje con el repo | Administrador de Microsoft 365 / Carlos |
| Alta en el correo `clopez@legal-credit.com` o definir uno nuevo para notificaciones | Ver sección 4 — es una decisión de negocio, no un tema de instalación | Comercial / Carlos |
