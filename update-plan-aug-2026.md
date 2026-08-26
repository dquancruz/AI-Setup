# update-plan.md — AI-Setup v3

> **Para el agente:** este documento es la unidad de trabajo. Ejecuta las fases **en orden**.
> Cada tarea tiene criterio de aceptación verificable. No marques una fase como completa
> hasta que todos sus criterios pasen. Actualiza el bloque `Estado` de cada fase conforme
> avances y registra cualquier desviación en `## Bitácora` al final del archivo.
>
> **Reglas de trabajo:**
> - Un commit por tarea, Conventional Commits, en español o inglés según el histórico del repo.
> - Una rama por fase: `feat/v3-fase-N-slug`.
> - No borres nada sin moverlo a `docs/archive/` primero.
> - Si una tarea requiere una decisión de producto que no está resuelta aquí, **detente y pregunta**
>   en lugar de asumir.
> - Antes de empezar, lee `README.md`, `USAGE.md`, `docs/AI-SETUP-PLAN-v2.md`,
>   `tools/*/capabilities.yaml` y `lib/condense.mjs` para tener el estado real.

---

## Fase 0 — Reconocimiento y baseline

**Estado:** completa (2026-08-24, rama `feat/v3-fase-0-baseline`)

Antes de tocar código, produce un baseline. Sin esto no hay forma de saber si el
refactor rompió algo.

### 0.1 Auditoría del estado real

Genera `docs/AUDIT-v3.md` con:

- Inventario de `registry/agents/*.md`: nombre, frontmatter, tamaño en tokens
  aproximados, y si el contenido menciona stacks hardcodeados (NestJS, FastAPI,
  MongoDB, CDK, Raspberry Pi...).
- Inventario de `registry/skills/*/SKILL.md`: nombre, `description` del frontmatter,
  tamaño, y si la descripción cumple las buenas prácticas de triggering
  (tercera persona, condiciones explícitas de cuándo aplica).
- Lista de todo lo que `install.sh` y `setup-repo.sh` escriben, con su destino real
  (verifica contra el README — la tabla puede haber quedado desfasada).
- Cualquier discrepancia entre `tools/*/capabilities.yaml` y la tabla de portabilidad
  del README.

**Aceptación:** `docs/AUDIT-v3.md` existe y la tabla de agentes/skills incluye tamaño
por archivo.

### 0.2 Suite de smoke tests

No hay tests en el repo. Antes de refactorizar, crea la red de seguridad.

- Añade `bats-core` como dependencia de desarrollo (o vendorízalo en `test/lib/`).
- Crea `test/install.bats` y `test/setup-repo.bats` que, contra un `HOME` y un repo
  temporales (`mktemp -d`), verifiquen:
  - `install.sh` crea todos los destinos declarados en la tabla del README.
  - `setup-repo.sh` es idempotente: ejecutarlo dos veces produce el mismo árbol
    (compara con `find | sort` + `sha256sum`).
  - `setup-repo.sh` **no** sobrescribe `.mcp.json`, `.claude/settings.json`,
    `.env.local` ni `.local-docs/` si ya existen (crea versiones con contenido
    marcador y verifica que sobrevivan).
  - El append-only de `AGENTS.md` no reescribe contenido previo.
- Crea `test/lint-frontmatter.mjs`: valida que todo `SKILL.md` tenga `name` y
  `description` en el frontmatter, que el `name` coincida con el nombre de carpeta,
  y que la `description` no exceda el límite del formato.

**Aceptación:** `npm test` (o `bats test/`) corre en verde en local y en CI.

### 0.3 CI del propio repo

`.github/workflows/ci.yml` que en cada push y PR corra: `shellcheck` sobre todos los
`.sh`, `bats test/`, `node test/lint-frontmatter.mjs`, y un job que ejecute
`install.sh` + `setup-repo.sh` sobre un repo de fixture en Ubuntu y macOS.

**Aceptación:** el workflow existe y pasa en ambos runners.

---

## Fase 1 — Cerrar la brecha de portabilidad con Cursor  ⚠️ PRIORIDAD MÁXIMA

**Estado:** completa (2026-08-24, rama `feat/v3-fase-1-cursor-hooks`)

**Contexto:** la tabla de portabilidad marca Hooks como ❌ para Cursor. Eso es
**incorrecto desde Cursor 1.7**. Cursor soporta hooks vía `.cursor/hooks.json`
(proyecto) o `~/.cursor/hooks.json` (usuario), schema `version: 1`, donde cada evento
mapea a un array de entradas con `command`, `matcher`, `failClosed`, `timeout` y
`loop_limit`. Los eventos disponibles cubren `beforeSubmitPrompt`,
`beforeShellExecution` / `afterShellExecution`, `beforeMCPExecution` /
`afterMCPExecution`, `beforeReadFile` / `afterFileEdit`, `sessionStart` / `sessionEnd`,
`stop`, `preCompact` y `subagentStart` / `subagentStop`. Los cloud agents de Cursor
levantan los hooks del repo automáticamente.

Esto significa que la capa de enforcement determinista — la parte más valiosa del
setup — es hoy Claude-only por una suposición desactualizada. Arreglarlo es la mayor
ganancia de portabilidad disponible.

### 1.1 Adaptador de hooks

Crea `tools/cursor/adapt/hook-to-cursor.sh` que traduzca
`registry/hooks/{pre,post}-tool-use/*.sh` a `.cursor/hooks.json`.

Mapeo base (documenta cualquier ajuste en `docs/tool-compatibility.md`):

| Claude Code | Cursor |
|---|---|
| `PreToolUse` (matcher `Bash`) | `beforeShellExecution` |
| `PreToolUse` (matcher MCP) | `beforeMCPExecution` |
| `PostToolUse` (matcher `Edit`/`Write`) | `afterFileEdit` |
| `SessionStart` / `SessionEnd` | `sessionStart` / `sessionEnd` |
| `Stop` | `stop` |
| `PreCompact` | `preCompact` |

**Diferencias de contrato que debes manejar en el wrapper — no las ignores:**

- Cursor comunica por **stdio con JSON**: el hook lee el payload de stdin y escribe
  la respuesta en stdout. Los `console.log`/`echo` de debug van a stderr, no a stdout.
- La respuesta de bloqueo usa `permission: "allow" | "deny"` (más `agentMessage`
  opcional), no el esquema de exit codes de Claude Code.
- El payload de `afterFileEdit` incluye `conversation_id`, `generation_id`,
  `hook_event_name`, `workspace_roots`, `file_path` y `edits` (array de
  `old_string`/`new_string`).
- `failClosed: true` bloquea si el hook falla; úsalo **solo** en hooks de seguridad
  (shell/MCP), nunca en formatters o tests.

**Diseño recomendado:** no dupliques la lógica. Los scripts de `registry/hooks/`
siguen siendo la SSOT; `hook-to-cursor.sh` genera un shim
`.cursor/hooks/_bridge.sh` que normaliza el payload de Cursor al formato que ya
esperan tus scripts y traduce el código de salida a `permission`.

**Aceptación:** en un repo de fixture, tras `setup-repo.sh` existe `.cursor/hooks.json`
válido contra el schema v1; un test alimenta un payload de `beforeShellExecution`
por stdin y verifica que un comando prohibido devuelva `{"permission":"deny"}`.

### 1.2 Revisar el resto de la matriz

La fila de Skills marca Cursor como 🟡 "referenced (path only)". Verifica el estado
actual del soporte de `SKILL.md` en Cursor y en Codex CLI antes de dar la fila por
buena — el formato ha ganado tracción cross-tool y puede que ya no haga falta el
downgrade. Actualiza `tools/cursor/capabilities.yaml` y la tabla del README con lo
que encuentres, citando la fuente y la fecha de verificación en
`docs/tool-compatibility.md`.

**Aceptación:** cada celda de la tabla de portabilidad del README tiene respaldo en
`tools/*/capabilities.yaml` y una fecha de verificación en `tool-compatibility.md`.

---

## Fase 2 — Eliminar los symlinks

**Estado:** completa (2026-08-24, rama `feat/v3-fase-2-drop-symlinks`)

**Contexto:** el fallback de Windows en `setup-portability.sh` existe porque los
symlinks son frágiles (Windows sin Developer Mode, `tar`, zips, algunos checkouts de
git). Hay una salida limpia: Claude Code sigue cargando `CLAUDE.md` en lugar de
`AGENTS.md`, pero soporta imports. Un `CLAUDE.md` de una sola línea con
`@AGENTS.md` funciona en cualquier plataforma, se versiona limpio y elimina toda la
rama de fallback.

### 2.1 Reemplazar la estrategia

- `CLAUDE.md` → archivo real de una línea: `@AGENTS.md`
- `GEMINI.md` → mismo patrón (verifica la sintaxis de import que soporta Gemini CLI;
  si no soporta imports, mantén symlink **solo** para este archivo y documenta por qué).
- `.github/copilot-instructions.md` → sigue siendo generado por condensación
  (`lib/condense.mjs`), no symlink. Ya es la decisión correcta.
- `.cursor/mcp.json` → evalúa si Cursor ya lee `.mcp.json` de la raíz; si no,
  genera un archivo real y añade una tarea de regeneración en `setup-repo.sh`.

### 2.2 Retirar `setup-portability.sh`

Absorbe su lógica en `setup-repo.sh` (deja de ser un paso manual extra) y mueve el
script a `docs/archive/` con una nota. Actualiza `USAGE.md`: desaparece el paso
"Cross-tool portability" y toda la sección de fallback de Windows.

**Aceptación:** ningún `ln -s` queda en el repo salvo el caso de Gemini si se
justificó; el test de idempotencia de la Fase 0 pasa en el runner de Windows del CI.

---

## Fase 3 — Empaquetar como plugin de Claude Code

**Estado:** completa (2026-08-25, rama `feat/v3-fase-3-claude-plugin`)

**Contexto:** `install.sh` copiando a `~/.claude/` con backups timestamped es un
gestor de paquetes hecho a mano, y garantiza drift: si el usuario edita algo en
`~/.claude/`, la siguiente ejecución lo pisa. El formato nativo hoy es el plugin:
un directorio autocontenido con `.claude-plugin/plugin.json` que agrupa skills,
agents, hooks y MCP servers en una unidad versionada, distribuida por un
marketplace (un repo de GitHub que actúa de registro). La conversión es mecánica:
`commands/`, `agents/` y `skills/` se mueven a la carpeta del plugin y los hooks
de `settings.json` migran a `hooks/hooks.json` — el formato de hooks es idéntico
en ambos sitios.

**Ojo (error frecuente):** `commands/`, `agents/`, `skills/` y `hooks/` van **al lado**
de `.claude-plugin/`, nunca dentro.

### 3.1 Packs opt-in en lugar de un monolito de 13 agentes

Instalar `iot-backend-expert`, `immersive-3d` y `cdk-expert` en un proyecto que no
los usa quema presupuesto de contexto sin retorno. Divide en plugins:

| Plugin | Contenido |
|---|---|
| `ai-setup-core` | `agent-orchestrator`, `solutions-expert`, `code-reviewer-pro`, `test-engineer`, `pr-manager`, `documentation-generator`, `reuse-architect` (Fase 5) + skills `auto-commit`, `pr-formatter`, `semantic-versioning`, `local-docs`, `code-reuse` |
| `ai-setup-backend` | `backend-expert` |
| `ai-setup-cloud` | `aws-architect`, `cdk-expert` + `cloud-iac-security` |
| `ai-setup-frontend` | `frontend-expert` + `design-system`, `immersive-3d` |
| `ai-setup-iot` | `iot-backend-expert` + `iot-backend` |
| `ai-setup-security` | `security-expert` + `threat-modeling`, `secure-coding` |
| `ai-setup-jira` | `ticket-orchestrator` + `jira-integration` |

`registry/` sigue siendo la SSOT. Los plugins se **generan** desde `registry/` con un
script (`tools/claude/build-plugins.sh`) que lee un manifiesto
`registry/packs.yaml` con la tabla de arriba. No dupliques archivos a mano.

### 3.2 Marketplace

Añade `.claude-plugin/marketplace.json` en la raíz del repo para que el propio
`dquancruz/AI-Setup` funcione como marketplace instalable:
`/plugin marketplace add dquancruz/AI-Setup`.

### 3.3 Compatibilidad hacia atrás

Mantén `install.sh` durante un ciclo, pero que imprima un aviso de deprecación y
apunte al flujo de plugins. Documenta la migración en `USAGE.md` y `CHANGELOG.md`.

**Aceptación:** `/plugin marketplace add <ruta-local>` seguido de
`/plugin install ai-setup-core` deja los agentes y skills disponibles en sesión, y
`build-plugins.sh` es reproducible (correrlo dos veces no cambia el árbol).

---

## Fase 4 — Desacoplar y limpiar

**Estado:** completa (2026-08-26, rama `feat/v3-fase-4-cleanup`)

### 4.1 Quitar el acoplamiento a Node/Husky

Los `.js` + Husky atan el setup a proyectos JS; el apartado "Python projects" de
`USAGE.md` lo reconoce y ofrece un parche.

- Elimina la dependencia de `minimist`: parsea `process.argv` a mano (son cuatro
  flags) para que los scripts corran con `node` pelado, sin `npm install`.
- Sustituye Husky por `lefthook` (binario único, agnóstico de lenguaje, config en
  un solo YAML) o, como mínimo, genera hooks de git nativos en `.git/hooks/` con un
  `core.hooksPath` apuntando a `.githooks/`.
- Borra la sección "Python projects (FastAPI)" de `USAGE.md` cuando deje de hacer falta.

### 4.2 Secretos

Escribir tokens en `.env.local` desde el instalador invita a filtraciones.

- `GITHUB_TOKEN` → usa `gh auth token` en tiempo de ejecución; no lo persistas.
- Credenciales de Jira → lee del keychain del SO (`security` en macOS,
  `secret-tool` en Linux) con fallback a `.env.local`.
- `setup-repo.sh` debe **verificar** que `.env.local` esté en `.gitignore` y añadirlo
  si falta, antes de escribir nada.
- Añade un hook `beforeReadFile` / `PreToolUse` que impida que el agente lea
  `.env.local` y lo mande al modelo.

### 4.3 Versionado del setup en el repo destino

`setup-repo.sh` escribe `.ai-setup/version.json` con la versión aplicada, el commit
de AI-Setup y la lista de archivos gestionados. Sin esto los upgrades son
adivinanza. Añade un modo `--check` que reporte drift entre lo gestionado y lo que
hay en disco.

### 4.4 Higiene del repo

- `LICENSE` (MIT, salvo que prefieras otra — pregunta si hay duda).
- Mueve a `docs/archive/`: todos los docs marcados *historical*, `plan.md`,
  `claude-cursor_monorepo_split_1b1edd71.plan.md`.
- Añade description y topics en GitHub; crea el primer release `v3.0.0` con notas.
- `CONTRIBUTING.md` corto explicando la regla de oro: **se edita `registry/`, nunca
  la salida generada**.

---

## Fase 5 — Reutilización de código y escalabilidad

**Estado:** pendiente

**Principio rector — no lo violes al implementar:** un agente que "recuerde" aplicar
DRY no funciona. Los LLMs no ven lo que no buscan, y no buscan sin un índice barato
de consultar. **La IA propone; el linter decide.** La duplicación se *mide*, no se
*juzga*. Todo lo que siga debe respetar eso: si una regla no es verificable por una
herramienta, va como guía, no como gate.

> **Pregunta abierta antes de implementar:** el stack asumido aquí es TypeScript/Node.
> Si hay Python (FastAPI aparece en los agentes) confirma el alcance: la Capa 1 y los
> linters cambian (`ruff`, `import-linter`, `vulture`, `jscpd` sí es multi-lenguaje).

### 5.1 Capa 1 — Inventario determinista

`registry/scripts/build-codemap.mjs` genera `.local-docs/codemap.json`:

```jsonc
{
  "generatedAt": "...",
  "packages": [{
    "name": "@app/ui",
    "path": "packages/ui",
    "exports": [{
      "symbol": "useDebounce",
      "kind": "hook",           // function | hook | component | type | endpoint | schema
      "signature": "(value: T, ms: number) => T",
      "file": "src/hooks/useDebounce.ts",
      "usedBy": 7               // fan-in: señal de qué es realmente reutilizable
    }]
  }]
}
```

- Usa `ts-morph` (o `ast-grep` si prefieres algo multi-lenguaje).
- Se regenera en `PostToolUse` / `afterFileEdit` (debounced) y en CI.
- Mantén también `.local-docs/codemap.md`, una vista compacta para inyectar en
  contexto sin quemar tokens: solo símbolo, kind y ruta, agrupado por paquete.
- `codemap.json` va en `.gitignore`; `codemap.md` **no** — sirve de contexto compartido.

**Aceptación:** en un repo de fixture con dos utilidades duplicadas, el codemap las
lista a ambas y `usedBy` refleja los imports reales.

### 5.2 Capa 2 — Skill `code-reuse`

`registry/skills/code-reuse/SKILL.md`. Portable tal cual a Cursor y Codex.
Protocolo obligatorio antes de crear cualquier símbolo nuevo:

1. Consultar `.local-docs/codemap.md` y hacer grep por dominio. **Nunca** escribir una
   función, hook, componente o tipo sin este paso.
2. Si existe algo con ≥70% de solapamiento funcional → extender o parametrizar. No duplicar.
3. **Regla de tres:** la primera repetición se tolera; la segunda se anota en
   `decisions.md`; la tercera se extrae obligatoriamente a compartido.
4. Toda duplicación deliberada se registra en `.local-docs/decisions.md` con su razón.
   Duplicar a veces es correcto — el acoplamiento prematuro cuesta más que copiar, y
   el skill debe decirlo explícitamente para no generar abstracciones basura.
5. Antes de crear un paquete o módulo nuevo, justificar por qué no cabe en uno existente.

La `description` del frontmatter debe disparar en: crear archivo nuevo, crear
función/componente/hook/tipo, refactorizar, y revisar un PR.

### 5.3 Capa 3 — Agente `reuse-architect`

`registry/agents/reuse-architect.md`. Subagente en Claude Code, Custom Mode en Cursor.
Dos momentos de invocación:

- **Pre-implementación** — `agent-orchestrator` lo llama *antes* de
  `backend-expert` / `frontend-expert`. Salida: un *reuse plan* en
  `.local-docs/plan.md` con tres listas — qué se reutiliza (con ruta al símbolo),
  qué se extrae a compartido (con destino propuesto), qué se crea nuevo (con
  justificación de por qué no encajaba nada existente).
- **En review** — junto a `code-reviewer-pro`. Salida: duplicación introducida
  respecto a `main`, violaciones de límites de módulo, abstracciones prematuras
  (parámetros booleanos de configuración, genéricos con un solo uso).

Define el contrato de entrada/salida en el frontmatter para que el handoff sea real
y no una sugerencia — hoy ninguno de los 13 agentes tiene contrato explícito, y eso
hace que el orquestador improvise.

### 5.4 Capa 4 — El gate portable (lo que lo hace real)

Un solo script, `registry/scripts/scalability-gate.sh`, invocado desde **cuatro**
sitios. Esa es la unidad portable — no repliques lógica en cada superficie:

1. `PostToolUse` de Claude Code
2. `afterFileEdit` de Cursor (vía el bridge de la Fase 1)
3. `pre-push` de git
4. GitHub Action en PR

Checks:

| Herramienta | Qué detecta | Modo |
|---|---|---|
| `jscpd` | clones copy/paste | falla si el % **sube** respecto a `main`, no contra un absoluto |
| `dependency-cruiser` | ciclos y dependencias entre capas | falla |
| `eslint-plugin-boundaries` | arquitectura por capas | falla |
| `knip` / `ts-prune` | exports muertos (señal directa de mala reutilización) | avisa |
| complejidad + tamaño de archivo | deriva estructural | avisa, falla al doble del umbral |

**Crítico:** en las superficies de agente (1 y 2) el gate corre **fail-open** — un
test que falla no debe bloquear la edición del agente, solo informarle. En pre-push
y CI corre fail-closed. Configura `failClosed: false` en el hook de Cursor
correspondiente.

**Baseline obligatorio:** genera `.ai-setup/duplication-baseline.json` al instalar.
Un repo existente arranca con duplicación; el gate mide el delta, no el absoluto.
Si no haces esto, el gate es inusable en brownfield y el equipo lo desactiva.

### 5.5 Presupuestos explícitos en `AGENTS.md`

"Escribe código escalable" es ruido en el prompt. Añade al template
`registry/templates/AGENTS.md` un bloque con números:

```md
## Presupuestos de escalabilidad
- Máx. líneas por archivo: 300 (avisa) / 600 (bloquea)
- Máx. duplicación introducida por PR: 0% sobre el baseline
- Complejidad ciclomática por función: 10
- Capas y dirección de imports permitida: <definir por proyecto>
- Umbral de extracción a compartido: 3ª repetición
```

El agente debe poder **citar** estos números como criterio objetivo. Sin números,
cada modelo improvisa el suyo — y eso es justo lo que rompe la consistencia al
alternar entre Claude y Cursor.

**Aceptación de la fase:** en un repo de fixture, introducir una función duplicada
hace que (a) `reuse-architect` la señale en review, (b) el gate falle en CI, y
(c) el hook de Cursor y el de Claude Code emitan el mismo mensaje. Los tres deben
funcionar sin tocar el script del gate.

---

## Fase 6 — Posicionamiento (opcional, evaluar después de la 5)

**Estado:** pendiente

El diferenciador de este repo **no** son los agentes — hay marketplaces con cientos
de plugins y miles de skills. El diferenciador es la capa de capacidades declarativa
(`capabilities.yaml` + `condense.mjs`) y la automatización Jira→commit→PR→release.
Apuesta ahí.

Corolario: **no escribas una capa spec-driven propia.** Evalúa integrar GitHub Spec
Kit u OpenSpec como capa opcional que alimente `.local-docs/plan.md`, en vez de
reinventarla. Y considera dos ideas prestadas:

- **Handoff formal por artefacto** (de BMAD): cada agente lee el documento del
  anterior y añade el suyo, creando una cadena trazable. Encaja con 5.3.
- **Recaps automáticos** (de Agent OS): tras cada feature implementada, generar un
  resumen corto en `.local-docs/` referenciable por humanos y por el agente en
  sesiones futuras.

Ambas son baratas de añadir y cierran el hueco de continuidad entre sesiones.

---

## Orden de ejecución y criterio de parada

```
Fase 0  →  Fase 1  →  Fase 2  →  Fase 3  →  Fase 4  →  Fase 5  →  [Fase 6]
```

- Las fases 1 y 5 son las de mayor retorno. Si hay que recortar alcance, recorta la 3
  y la 6, nunca la 0 (sin tests el resto es ciego).
- Al terminar cada fase: actualiza `CHANGELOG.md`, la tabla de portabilidad del
  `README.md` y `USAGE.md` si el flujo de instalación cambió. Un PR por fase.
- Todas las afirmaciones sobre capacidades de herramientas externas (Cursor, Codex,
  Gemini) deben quedar registradas en `docs/tool-compatibility.md` con fuente y fecha.
  Este ecosistema se mueve rápido; sin fecha, la tabla vuelve a mentir en tres meses
  — que es exactamente lo que pasó con los hooks de Cursor.

---

## Bitácora

<!-- El agente añade aquí una entrada por fase completada: fecha, PR, desviaciones
     respecto al plan y decisiones tomadas que no estaban previstas. -->

### Fase 0 — 2026-08-24

- Rama: `feat/v3-fase-0-baseline`. PR: [#7](https://github.com/dquancruz/AI-Setup/pull/7).
- 0.1: `docs/AUDIT-v3.md` creado. Único hallazgo real (no solo consistencia interna):
  `install.sh`/`setup-repo.sh` coinciden con la tabla del README (verificado ahora
  de forma continua vía bats, no solo por lectura manual). `capabilities.yaml` es
  internamente consistente entre los tres tools, pero comparte con el README y
  `tool-compatibility.md` la misma afirmación desactualizada sobre hooks en Cursor
  que el contexto de la Fase 1 ya señalaba — no se corrigió aquí (le corresponde a
  la 1.1 con verificación en fuente viva), solo se documentó.
- 0.2: **Desviación del plan** — se usó el paquete npm `bats` (wrapper oficial de
  bats-core, confirmado publicando la misma versión 1.13.0) como devDependency en
  vez de vendorizar el binario en `test/lib/`. Motivo: sin acceso previo confirmado
  a red no quise asumir vendoring a ciegas; una vez confirmado que el registro npm
  era alcanzable, `npm install` es más simple de mantener que vendorizar fuentes
  shell. `package.json` es nuevo en la raíz — dev-only, no toca lo que
  `install.sh`/`setup-repo.sh` escriben en repos destino (la preocupación de la
  Fase 4 sobre acoplamiento a Node es sobre esos scripts *generados*, no sobre las
  herramientas de desarrollo de este propio repo). Las 13 pruebas de `.bats` + el
  linter de frontmatter corren en verde localmente (Windows/Git Bash, Node v24).
- 0.3: `.github/workflows/ci.yml` creado (shellcheck + unit-tests + fixture-install
  matrixed ubuntu/macos). **No verificado en runners reales de GitHub Actions**
  todavía — este entorno no tiene acceso a Actions; sí se verificó cada pieza por
  separado localmente: se descargó shellcheck v0.10.0 a `scratchpad/` (fuera del
  repo) para poder correrlo de verdad antes de confiar en el job, en vez de
  escribir el workflow a ciegas. Encontró 4 findings reales (no ruido) que se
  corrigieron: SC2086, SC2012, SC2129×2, SC2088×2. También encontró que los 10
  `.sh` del repo se ven con CRLF en este checkout de Windows (`core.autocrlf=true`)
  aunque el blob en git es LF puro (confirmado con `git cat-file -p`) — no habría
  roto CI en runners Linux/macOS, pero es una mina real para el próximo commit
  desde Windows que guarde un script con CRLF. Se añadió `.gitattributes` en vez de
  tocar el histórico (no hacía falta renormalizar, el contenido ya era LF).
  **Pendiente de confirmar en el primer PR real:** que el job `fixture-install`
  efectivamente pasa en ambos runners — abrir el PR de esta fase es lo que lo
  valida.
- PR #7 mergeado a `main` (squash) 2026-08-24. CI verde en runners reales
  (ubuntu-latest + macos-latest) tras un segundo push que corrigió un bug en
  el propio `ci.yml` (ruta relativa incorrecta tras `cd ai-setup` en el job
  `fixture-install`) — no un bug de `install.sh`/`setup-repo.sh`.

### Fase 1 — 2026-08-24

- Rama: `feat/v3-fase-1-cursor-hooks`. PR: [#8](https://github.com/dquancruz/AI-Setup/pull/8).
- **Desviación importante de 1.1, documentada aquí porque cambia el mapeo que
  el propio contexto de la Fase proponía:** en vez de mapear a los eventos
  granulares `beforeShellExecution`/`beforeMCPExecution`/`afterFileEdit` que
  sugería la tabla original, `hook-to-cursor.sh` mapea a los eventos
  genéricos `preToolUse`/`postToolUse` de Cursor. Motivo verificado contra
  [cursor.com/docs/hooks](https://cursor.com/docs/hooks) (2026-08-24): los
  dos hooks reales de este repo (`block-secrets.sh`, `lint-after-write.sh`)
  matchean por `Write|Edit|str_replace_editor` en `tools/claude/settings.json`
  — no son hooks de shell ni de MCP. Y Cursor **no tiene** un evento granular
  "antes de escribir/editar un archivo": solo `beforeReadFile` (antes de
  LEER) y `afterFileEdit` (después de editar — ya tarde para bloquear). El
  único mecanismo de Cursor que puede bloquear un `Write` antes de que
  llegue a disco es el evento genérico `preToolUse`, que sí filtra por tipo
  de herramienta (incluye Write) — confirmado con ejemplo de payload en la
  doc oficial. Sin esta verificación en fuente viva, habría implementado un
  bridge que compila pero nunca bloquea nada en la práctica.
- Diseño: `registry/hooks/*.sh` sigue siendo la SSOT — no se duplicó lógica.
  `tools/cursor/adapt/hook-bridge.sh` (shim estático, copiado sin cambios a
  `.cursor/hooks/_bridge.sh` en cada run) invoca el script ya copiado en
  `.claude/hooks/...` sin transformar el payload de entrada (el schema de
  Cursor ya usa `tool_name`/`tool_input`, igual que Claude Code) y traduce
  exit 2 → `{"permission":"deny",...}` / exit 0 → `{"permission":"allow"}`,
  redirigiendo todo el stdout/stderr del script real a stderr propio (Cursor
  espera JSON limpio en stdout cuando exit 0 "usa JSON output" — el eco de
  debug de `lint-after-write.sh` habría contaminado ese canal sin esto).
  `tools/cursor/adapt/hook-to-cursor.sh` genera `.cursor/hooks.json` leyendo
  los matchers reales de `tools/claude/settings.json` (no hardcodeados por
  segunda vez) y traduce nombres de herramienta Claude→Cursor. Política
  `failClosed`: `true` por defecto en `pre-tool-use/*` (hooks de seguridad),
  `false` en `post-tool-use/*` (feedback no bloqueante), con override vía
  comentario `# cursor-fail-closed: true|false` en el propio script si algún
  hook futuro necesita lo contrario — evita repetir el hardcoding-por-archivo
  que la Fase 0 señaló como riesgo de deriva en `setup-repo.sh`.
- **Verificado end-to-end localmente** (no solo leído): `hook-to-cursor.sh`
  corrido contra un fixture real generó `.cursor/hooks.json` con la forma
  esperada; el bridge alimentado con payloads reales por stdin bloqueó un
  secreto AWS y una escritura a `.env` real (`exit 2`,
  `{"permission":"deny"}`), permitió una escritura limpia y una herramienta
  no matcheada (`exit 0`, `{"permission":"allow"}`), y mantuvo stdout como
  JSON válido en el hook de lint no bloqueante. Nuevo `test/cursor-hooks.bats`
  (7 tests) cubre todo esto en CI. **Lo que NO se verificó** — sin superficie
  de automatización de Cursor disponible en este entorno —: que Cursor
  realmente invoque `.cursor/hooks.json` como está documentado dentro de una
  sesión real, y los nombres exactos de campo dentro de `tool_input` para una
  llamada `Write` real (la doc pública no los fija; `block-secrets.sh` ya
  prueba varios nombres plausibles de forma defensiva). Documentado como
  hueco conocido en `tools/cursor/capabilities.yaml` (`hooks.known_gaps`) y
  en `docs/tool-compatibility.md`. Recomendación al usuario: un smoke test
  manual en Cursor real antes de confiar en esto para enforcement de
  seguridad.
- 1.2: verificado contra fuente viva (no solo re-leído el contexto de la
  Fase) que Cursor **ya soporta `SKILL.md` nativo** — auto-discovery,
  progressive disclosure, `.cursor/skills/` (proyecto) + `~/.cursor/skills/`
  (personal/global), Y además lee `.claude/skills/`/`~/.claude/skills/`
  directamente "for compatibility" — es decir, los skills que `install.sh`
  ya escribe en `~/.claude/skills/` ya son visibles hoy en Cursor con
  contenido completo, sin ningún adaptador. La fila de skills del README y
  de `docs/tool-compatibility.md` estaba desactualizada (🟡 "referenced,
  path only") — corregida a ✅. También verificado (con menor confianza —
  fuentes secundarias, no una página oficial de OpenAI fijada de primera
  mano) que Codex CLI ganó soporte nativo de `SKILL.md` hacia diciembre 2025;
  corregida su fila de ❌ a 🟡 (soporte existe, este repo no renderiza a su
  path todavía). Añadido `## Verification log` a `docs/tool-compatibility.md`
  con fecha + fuente por afirmación re-verificada esta Fase — la tabla no
  tenía NINGUNA fecha antes (hallazgo de `docs/AUDIT-v3.md`).
  **Desviación de alcance:** el criterio de aceptación pide fecha de
  verificación en *cada celda* de la tabla; solo se re-verificaron en fuente
  viva las dos afirmaciones que el propio texto de la Fase nombraba (hooks
  y skills de Cursor) más Codex/skills (hallazgo relacionado). El resto de
  la tabla (Antigravity completa, MCP/rules de Codex, "partial" de Copilot)
  queda marcado explícitamente como "no re-verificado esta Fase" en vez de
  fecharlo sin haberlo comprobado — extenderlo es trabajo futuro, no de esta
  Fase.
- `npm test` verde (27 tests: 20 previos + 7 de `cursor-hooks.bats`),
  `shellcheck` limpio sobre los 12 `.sh` del repo (2 nuevos: `hook-bridge.sh`,
  `hook-to-cursor.sh`).

### Fase 2 — 2026-08-24

- Rama: `feat/v3-fase-2-drop-symlinks`. PR: [#9](https://github.com/dquancruz/AI-Setup/pull/9).
- **Mejor resultado del esperado por el propio plan:** el contexto de la Fase
  reservaba la posibilidad de mantener el symlink de `GEMINI.md` "si Gemini
  CLI no soporta imports". Verificado en fuente viva
  ([github.com/google-gemini/gemini-cli](https://github.com/google-gemini/gemini-cli/blob/main/docs/cli/gemini-md.md),
  2026-08-24): Gemini CLI **sí** soporta `@file.md` con el mismo modelo que
  Claude Code (rutas relativas/absolutas, anti-recursión). Resultado: **cero**
  symlinks en todo el repo, no uno — ni siquiera la excepción de Gemini hizo
  falta. Verificado también que Claude Code soporta `@path` con profundidad
  máx. 5 y que la primera vez que un proyecto usa imports externos muestra un
  diálogo de aprobación una sola vez (documentado en `USAGE.md` como nota,
  no bloqueante). Y que Cursor lee específicamente `.cursor/mcp.json`, no un
  `.mcp.json` de raíz — confirma que ahí sí hace falta un archivo real
  (ahora una copia, no symlink), tal como el plan preveía como fallback.
- **Bug real encontrado y corregido al retirar `setup-portability.sh`, no
  previsto por el plan:** ese script symlinkeaba
  `.github/copilot-instructions.md` directamente a `AGENTS.md` — pero
  `tools/copilot/capabilities.yaml` y el propio README ya declaraban que ese
  archivo debía generarse **condensado** vía `lib/condense.mjs` (trabajo de
  una fase anterior). `setup-repo.sh` nunca invocaba
  `tools/copilot/enable.sh`, así que en la práctica cualquier repo que
  siguiera `USAGE.md` tal cual terminaba con un `copilot-instructions.md`
  verbatim (sin budget de líneas, sin condensar), pese a que toda la
  infraestructura de condensación ya existía y funcionaba. Ni la Fase 0 ni
  la Fase 1 lo detectaron. Corregido: `setup-repo.sh` ahora invoca
  `tools/copilot/enable.sh --scope=repo` directamente (degrada a warning, no
  falla, si `node` no está en PATH — mismo patrón que la detección de
  python3/python/py en los hooks).
- Reemplazo implementado: `registry/templates/CLAUDE.md` y
  `registry/templates/GEMINI.md` (archivos reales de una línea,
  `@AGENTS.md`) copiados sin condición en cada `setup-repo.sh` (nunca tienen
  contenido personalizable, igual que `.cursor/rules/*.mdc`).
  `.cursor/mcp.json` ahora es una copia real de `.mcp.json`, regenerada cada
  run. `setup-portability.sh` movido a `docs/archive/` con una nota de
  cabecera explicando la retirada (historia preservada, no ejecutable).
  `setup-repo.sh` ya no lo copia ni lo menciona en su lista final.
- **Desviación de alcance del criterio de aceptación:** pide que "el test de
  idempotencia de la Fase 0 pase en el runner de Windows del CI" — pero el
  CI de la Fase 0 nunca tuvo un runner `windows-latest` (solo
  ubuntu-latest/macos-latest). Añadido a `.github/workflows/ci.yml`
  (`defaults.run.shell: bash`, ya que windows-latest usa PowerShell por
  defecto en pasos `run:`), con aserciones nuevas específicas de esta Fase
  (CLAUDE.md/GEMINI.md/.cursor/mcp.json/.github/copilot-instructions.md
  existen, ninguno es symlink, `find -type l` no encuentra nada). Es la
  primera vez que este repo corre CI en Windows — pendiente de confirmar en
  el PR real que pasa (igual que la Fase 0 con ubuntu/macos).
- Verificado end-to-end localmente antes de escribir tests: `setup-repo.sh`
  corrido contra un fixture real, contenido de `CLAUDE.md`/`GEMINI.md`
  inspeccionado (`@AGENTS.md` exacto), `.cursor/mcp.json` diffed contra
  `.mcp.json` (idéntico), `.github/copilot-instructions.md` confirmado
  condensado (no verbatim), idempotencia re-verificada con hash de árbol.
  `test/setup-repo.bats` ampliado (+4 tests: sin symlinks en el árbol, sin
  `ln -s` en ningún script activo del repo, contenido exacto de
  CLAUDE.md/GEMINI.md, copilot-instructions.md realmente condensado) — total
  22 tests bats + linter, todos en verde. `shellcheck` limpio sobre los 11
  `.sh` activos tras los cambios.
- Actualizada la documentación que describía el mecanismo antiguo:
  `README.md` (sección "AGENTS.md as the SSOT" + tabla de portabilidad),
  `USAGE.md` (sección "Cross-tool portability" reescrita, ya no es un paso
  manual), `install.sh` (texto final), `tools/claude/capabilities.yaml`
  (`instructions.mechanism: symlink` → `import`),
  `tools/cursor/capabilities.yaml` (comentario desactualizado sobre
  CLAUDE.md).

### Fase 3 — 2026-08-25

- Rama: `feat/v3-fase-3-claude-plugin`. PR: [#10](https://github.com/dquancruz/AI-Setup/pull/10).
- Verificado en fuente viva antes de implementar (`code.claude.com/docs/en/plugins`
  y `.../plugin-marketplaces`, 2026-08-25) en vez de asumir el resumen del
  propio plan: confirmado el esquema real de `.claude-plugin/plugin.json`
  (`name`/`description`/`version`/`author`), que `commands/`, `agents/`,
  `skills/`, `hooks/` van al lado de `.claude-plugin/` (nunca dentro, tal
  como ya advertía el plan) y el esquema real de
  `.claude-plugin/marketplace.json` (`name`/`owner`/`plugins[]`, cada entry
  con `source` — una ruta relativa `./plugins/<pack>` resuelta contra la raíz
  del repo, no contra `.claude-plugin/`).
- **Implementado exactamente lo que pide 3.1/3.2/3.3, ni más ni menos:**
  `registry/packs.yaml` (nuevo manifiesto, 7 packs) +
  `tools/claude/build-plugins.sh` (nuevo, genera `plugins/<pack>/` +
  `.claude-plugin/marketplace.json` desde `registry/` sin duplicar
  contenido a mano — usa python3/python/py con el mismo fallback de 3 pasos
  que `hook-to-cursor.sh`, ya que `registry/packs.yaml` es YAML real y hace
  falta parsearlo + emitir JSON válido). Valida que cada agente/skill de
  `registry/` esté en exactamente un pack (falla fuerte, nombrando el
  agente/skill exacto, ante un hueco o una duplicación) y es determinista:
  borra y regenera `plugins/`/`.claude-plugin/` desde cero en cada corrida
  — verificado con diff byte-a-byte tras dos corridas seguidas.
- **Excepción deliberada a la regla habitual de este repo ("nada generado se
  commitea"):** `plugins/` y `.claude-plugin/marketplace.json` SÍ se
  commitean, a diferencia de cualquier otro output de `tools/*/enable.sh`.
  No es una inconsistencia de estilo — lo exige cómo funciona de verdad
  `/plugin marketplace add owner/repo`: lee archivos estáticos del repo en
  un ref de git, no hay paso de build en ese flujo. Documentado en la
  cabecera de `build-plugins.sh` y en `README.md`. Añadido un job de CI
  nuevo, `plugins-in-sync`, que regenera y hace `git diff --exit-code` sobre
  `plugins/` y `.claude-plugin/` en cada push — para que un cambio en
  `registry/` o `registry/packs.yaml` no pueda mergear sin su
  `plugins/` correspondiente.
- **Desviación de la tabla de packs del propio plan:** la tabla lista 5
  skills para `ai-setup-core` (`auto-commit`, `pr-formatter`,
  `semantic-versioning`, `local-docs`, `code-reuse`) pero no menciona el
  skill `auto-pr` en ningún pack — un hueco real en el plan, no una omisión
  intencional (confirmado: los otros 12 agentes/12 skills sí aparecen todos
  exactamente una vez). Colocado `auto-pr` en `ai-setup-core` (misma
  afinidad genérica que `auto-commit`/`pr-formatter`, sin relación con
  backend/frontend/cloud/iot/security/jira) — decisión de ingeniería, no de
  producto, documentada en la cabecera de `registry/packs.yaml`. `code-reuse`
  y el agente `reuse-architect` (Fase 5, aún no existen en `registry/`) no
  aparecen en ningún pack todavía — se añadirán cuando la Fase 5 los cree.
- **Alcance deliberadamente limitado a agentes+skills**, igual que el propio
  desglose 3.1-3.3 del plan y su criterio de aceptación (que solo verifica
  agentes/skills tras `/plugin install`): hooks y MCP servers NO se
  empaquetan en estos plugins — siguen exactamente igual que hoy,
  renderizados por-repo vía `setup-repo.sh` en `.claude/hooks/` y
  `.mcp.json`. El párrafo de contexto del plan menciona hooks/MCP como parte
  de lo que un plugin *puede* contener en general, pero ninguna de las
  tareas 3.1/3.2/3.3 ni el criterio de aceptación piden migrarlos — meterlos
  aquí habría sido alcance no pedido.
- `install.sh` marcado como deprecado (se mantiene funcional este ciclo,
  como pide 3.3): banner de aviso al inicio de su salida, apuntando al flujo
  de plugins. `README.md` y `USAGE.md` reescritos para liderar con
  `/plugin marketplace add`/`/plugin install`, con `install.sh` degradado a
  alternativa documentada (no eliminado).
- `test/build-plugins.bats` (8 tests nuevos): un `plugin.json` válido por
  pack, `marketplace.json` lista cada pack con el `source` correcto, cada
  agente/skill de `registry/` aparece en exactamente un pack y es idéntico
  byte a byte al original, reproducibilidad (hash de árbol en dos corridas),
  y 3 tests de camino de error (agente faltante, agente duplicado entre dos
  packs, skill desconocido referenciado) contra una raíz fixture aislada que
  nunca toca el `registry/` real — total 30 tests bats + linter, todos en
  verde. `shellcheck` limpio sobre `build-plugins.sh` y los 12 `.sh` activos
  restantes.
- **Criterio de aceptación no verificado end-to-end en una sesión real de
  Claude Code** (pide `/plugin marketplace add <ruta-local>` seguido de
  `/plugin install ai-setup-core` dejando agentes/skills disponibles en
  sesión): verificado en su lugar (a) contra el esquema documentado —
  `plugin.json`/`marketplace.json` generados calzan exactamente los campos
  requeridos/opcionales descritos en la doc oficial — y (b) que
  `build-plugins.sh` es reproducible y que cada agente/skill generado es
  contenido verbatim de `registry/`. No hay acceso a una sesión interactiva
  de Claude Code con `/plugin` disponible desde este entorno de ejecución
  para probar el flujo `/plugin marketplace add`/`/plugin install` de punta
  a punta. Recomendado que el usuario haga una prueba manual una vez
  mergeado (mismo patrón que el hueco residual documentado en la Fase 1 para
  los hooks de Cursor).

### Fase 4 — 2026-08-26

- Rama: `feat/v3-fase-4-cleanup`.
- **4.1 (Node/Husky):** `registry/scripts/*.js` reemplazan `minimist` por un
  parser de argv escrito a mano (~25 líneas, replicado en los 4 scripts a
  propósito — el propio plan pide "parsear a mano, son cuatro flags", y una
  única función de shared-lib habría obligado a tocar el glob de copia de
  `setup-repo.sh`). Husky retirado: `registry/templates/githooks/` +
  `git config core.hooksPath .githooks` en `setup-repo.sh` — sin
  `npm install`/`npx husky install`, funciona igual en repos Node y no-Node.
  **Hallazgo real durante la migración, no introducido por ella:** git no
  tiene un hook nativo `pre-tag` — `.husky/pre-tag` nunca se disparaba ni con
  Husky instalado. Su lógica (formato de tag, tests finales, working tree
  limpio) se movió a `pre-push`, el hook real que sí dispara al pushear un
  tag. Plantillas viejas archivadas en `docs/archive/husky/` con
  `NOTE.md` explicando el bug. `test/setup-repo.bats`: +4 tests (no crea
  `.husky/`, `core.hooksPath` correcto, scripts corren con `node` plano sin
  `node_modules`).
- **4.2 (Secretos):** `GITHUB_TOKEN` ahora se resuelve vía `gh auth token` en
  tiempo de ejecución (nunca persistido) en `auto-pr.js`/`dashboard.js`, con
  `.env.local` como fallback si `gh` no está autenticado. Jira: nuevo
  `resolveJiraToken()` en `auto-jira.js`/`dashboard.js` que primero consulta
  el keychain del SO (`security` en macOS, `secret-tool` en Linux, ambos vía
  `execFileSync` para evitar inyección de shell) y cae a
  `JIRA_API_TOKEN`/`.env.local` si el lookup falla o la plataforma es
  Windows — **no hay lector de keychain nativo en Windows sin añadir una
  dependencia nueva**, así que ahí `.env.local` sigue siendo la única vía;
  documentado en `.env.example` y `USAGE.md`, no ocultado. `setup-repo.sh`
  reordenado: el paso de `.gitignore` para `.env.local` ahora corre *antes*
  de crear el archivo (antes era al revés), para que nunca exista un
  instante con el archivo de secretos sin ignorar. `block-secrets.sh`
  extendido para bloquear también `Read` sobre un `.env` real (no solo
  `Write`/`Edit`) — evita que su contenido llegue al modelo por lectura en
  vez de por escritura; el matcher de `tools/claude/settings.json` pasó a
  `Write|Edit|str_replace_editor|Read`, que se propaga solo a
  `.cursor/hooks.json` porque `hook-to-cursor.sh` ya traducía `Read` desde
  antes (Fase 1) sin necesitar cambios. `test/cursor-hooks.bats`: +2 tests
  (deniega Read de `.env.local`, permite Read de `.env.example`), 1 test
  renombrado para reflejar que `Read` ya no es "no-matched".
- **4.3 (Versionado):** `setup-repo.sh` ahora acumula dos arrays bash
  (`MANAGED_UNCONDITIONAL`, `MANAGED_ONCE`) a medida que copia cada archivo,
  y al final escribe `.ai-setup/version.json` (versión + commit de AI-Setup
  + el inventario completo) vía Python (mismo patrón de fallback
  python3/python/py que `block-secrets.sh`/`build-plugins.sh`). Nuevo modo
  `setup-repo.sh --check`: sin flag no toca nada, compara versión/commit
  grabados contra los actuales y reporta archivos gestionados que
  desaparecieron del disco, saliendo con código 1 si hay drift. El test de
  idempotencia de la Fase 0 (`find | sort + sha256sum` en dos corridas)
  tuvo que excluir `.ai-setup/` — `generatedAt` cambia en cada corrida por
  diseño, incluirlo habría hecho el test flaky sin que hubiera ningún bug
  real. `test/setup-repo.bats`: +4 tests (contenido de `version.json`,
  `--check` sin drift, `--check` sin archivo, `--check` detecta archivo
  gestionado borrado).
- **4.4 (Higiene):** `LICENSE` (MIT) añadido — confirmado con el usuario
  antes de elegir licencia y antes de tocar metadata pública de GitHub
  (descripción/topics del repo vía `gh repo edit`, ambos ya aplicados) o
  cortar el release, siguiendo la política de este agente de confirmar
  acciones difíciles de revertir o de cara al exterior. `plan.md` y
  `claude-cursor_monorepo_split_1b1edd71.plan.md` movidos a `docs/archive/`
  (el segundo no tenía nota de "superseded" propia — se le añadió una,
  después del frontmatter YAML para no romperlo, mismo patrón que
  `docs/archive/husky/NOTE.md`). `CONTRIBUTING.md` nuevo con la regla de oro
  del repo (editar `registry/`, nunca la salida generada) y el flujo de
  commit/PR/archivado ya establecido en este mismo plan.
  **Desviación deliberada del orden 4.4 tal como está escrito:** el tag y
  release `v3.0.0` NO se cortó en esta rama — los releases de este repo se
  cortan sobre `main` después de mergear el PR de la fase (mismo patrón que
  las Fases 0-3, cuyas Bitácoras registran "PR #N mergeado a main" como un
  hecho posterior, no parte del trabajo en la rama). Cortar un tag `v3.0.0`
  sobre una rama de feature todavía no revisada habría sido más difícil de
  revertir que abrir el PR. Pendiente tras el merge: ejecutar el skill
  `semantic-versioning` (o `documentation-generator`) sobre `main` para
  generar el CHANGELOG y el release de GitHub.
- 39 tests bats + lint-frontmatter en verde localmente (Windows/Git Bash).
  `shellcheck` no disponible en este entorno de ejecución para una pasada
  local (Fase 0 sí lo descargó puntualmente a `scratchpad/`, fuera del
  repo, en una sesión anterior — no persiste entre sesiones); `bash -n`
  sobre los 6 scripts `.sh` tocados no encontró errores de sintaxis. CI
  (`shellcheck` real) validará en el PR.
- **Pendiente de abrir PR** (esta sesión no hace merge a `main` sin
  revisión, por la misma política de confirmar cambios difíciles de
  revertir) y, tras el merge, cortar `v3.0.0`.