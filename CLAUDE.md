# Contexto del repo

## Dos máquinas sincronizadas por git

El usuario (calopezp) trabaja este repo desde dos computadoras, sincronizadas vía GitHub (`origin` = `https://github.com/calopezp/SCRIPTS_LCS_2025.git`, rama `main`):

- **ANTIGUA** — `C:\SALESFORCE\LCS\SCRIPTS_LCS_2025\` (usuario Windows: Carlos Lopez New)
- **NUEVA** — `C:\LCS 2026\SCRIPTS_LCS_2025\`

Este archivo viaja con el repo (se sincroniza en cada `push`/`pull`), a diferencia de la memoria local de Claude Code (`~/.claude/projects/.../memory/`), que vive por separado en cada máquina y **no** se sincroniza automáticamente. Si trabajas desde una sesión nueva en cualquiera de las dos máquinas, este archivo es la fuente de verdad compartida — la memoria local de Claude Code puede tener detalle adicional pero es específica de esa máquina.

## Flujo de trabajo con git (preferencia del usuario)

- Hacer commits locales para preservar historial de versiones; el push a GitHub no es automático — se hace solo cuando el usuario lo pide explícitamente.
- Nunca usar `git add -A`. Agregar archivos específicos por nombre al hacer stage.
- Antes de empezar a trabajar en cualquiera de las dos máquinas: `git pull origin main`.
- Al terminar una sesión de trabajo: commit (y push si el usuario lo confirma) para que la otra máquina pueda traer los cambios.
