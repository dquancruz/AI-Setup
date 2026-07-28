# Guía de Uso

## Instalación inicial (una vez)

```bash
git clone <tu-repo-url> claude-automation-setup
cd claude-automation-setup
chmod +x install.sh setup-repo.sh per-repo/setup-portability.sh
./install.sh
```

`install.sh` copia a `~/.claude/`:
- `global/agents/*` → `~/.claude/agents/` (13 agentes)
- `global/skills/*/` → `~/.claude/skills/` (12 skills en formato carpeta)

## Setup por proyecto (en cada repo)

Desde la raíz del repo destino:

```bash
/path/to/claude-automation-setup/setup-repo.sh
```

Esto copia al repo:
- `per-repo/scripts/` → `<repo>/scripts/`
- `per-repo/.husky/` → `<repo>/.husky/`
- `per-repo/.github/workflows/` → `<repo>/.github/workflows/`
- `per-repo/AGENTS.md` → `<repo>/AGENTS.md` (template — editar)
- `per-repo/.mcp.json` → `<repo>/.mcp.json`
- `per-repo/.claude/rules/` → `<repo>/.claude/rules/`
- `per-repo/.cursor/rules/` → `<repo>/.cursor/rules/`
- `per-repo/.claude/hooks/` → `<repo>/.claude/hooks/`
- `per-repo/.claude/settings.json` → `<repo>/.claude/settings.json`
- `.env.example` → `<repo>/.env.local` (luego rellenar)

## Portabilidad cross-tool

Desde la raíz del repo recién configurado:

```bash
bash setup-portability.sh
```

Crea:
- `CLAUDE.md` → symlink a `AGENTS.md`
- `GEMINI.md` → symlink a `AGENTS.md`
- `.github/copilot-instructions.md` → symlink a `../AGENTS.md`
- `.cursor/mcp.json` → symlink a `../.mcp.json`

**Regla:** Editar siempre `AGENTS.md`. Los symlinks se actualizan solos.

## Configurar el repo destino

### 1. Editar AGENTS.md
Rellenar: nombre del proyecto, tech stack, comandos reales, rutas de arquitectura.

### 2. Rellenar credenciales
```bash
# Editar .env.local
```
Variables requeridas:
```
GITHUB_TOKEN=ghp_...
JIRA_URL=https://tu-org.atlassian.net
JIRA_TOKEN=...
JIRA_EMAIL=tu@email.com
```

### 3. Configurar el preset de diseño (proyectos con UI)
En `.claude/rules/design.md`, cambiar la línea:
```
Design preset: velocity  # o vice | quiet
```

### 4. Node.js: finish setup
```bash
npm install --save-dev minimist husky
npx husky install
```
Añadir a `package.json`:
```json
{
  "scripts": {
    "prepare":     "husky install",
    "auto-commit": "node scripts/auto-commit.js",
    "auto-pr":     "node scripts/auto-pr.js",
    "auto-jira":   "node scripts/auto-jira.js",
    "dashboard":   "node scripts/dashboard.js"
  }
}
```

### 5. Activar GitHub Actions secrets
En GitHub: Settings → Secrets → Actions → Añadir:
- `JIRA_HOST`
- `JIRA_EMAIL`
- `JIRA_API_TOKEN`

### 6. Test
```bash
npm run auto-commit -- --help
```

## MCPs (Model Context Protocol)

Los MCP servidores se configuran en `.mcp.json` del repo. Claude Code los detecta automáticamente al abrir el proyecto.

Ver `docs/MCPS-configuracion-completa.md` para instalación detallada de cada servidor.

## Estructura de reglas (rules)

Las rules en `.claude/rules/` se cargan automáticamente según el archivo en edición:

| Rule | Paths que la activan |
|------|---------------------|
| `backend.md` | `src/api/**`, `src/services/**` |
| `frontend.md` | `src/components/**`, `src/app/**` |
| `testing.md` | `src/**/*.test.*`, `tests/**` |
| `design.md` | `src/components/**`, `src/styles/**` |
| `security.md` | `src/auth/**`, `infra/**` |

Para Cursor: equivalentes en `.cursor/rules/*.mdc`.

## Agentes disponibles

Ver `AGENTS.md` del repo para el árbol de decisión completo.

| Agente | Uso principal |
|--------|---------------|
| `agent-orchestrator` | Punto de entrada para features completas |
| `solutions-expert` | Arquitectura y diseño de soluciones |
| `ticket-orchestrator` | Generar jerarquía Jira |
| `backend-expert` | APIs NestJS/FastAPI/MongoDB |
| `iot-backend-expert` | Raspberry Pi/GPIO/edge |
| `frontend-expert` | React/Next.js/Astro + a11y + diseño |
| `aws-architect` | Arquitectura AWS |
| `cdk-expert` | CDK / IaC |
| `test-engineer` | Tests unitarios + calidad de cobertura (antes del review general) |
| `pr-manager` | Crear PRs con el formato estándar del proyecto |
| `code-reviewer-pro` | Review general (siempre antes de PR) |
| `security-expert` | AppSec profundo (auth/crypto/IAM) |
| `documentation-generator` | Docs + versioning + releases |

## Skills disponibles

| Skill | Cuándo se usa |
|-------|---------------|
| `auto-commit` | Commitear con Conventional Commits |
| `pr-formatter` | Formatear descripciones de PR |
| `semantic-versioning` | Bumps de versión y releases |
| `iot-backend` | Código de hardware/GPIO/edge |
| `auto-pr` | Crear PRs automáticamente |
| `jira-integration` | Interactuar con Jira |
| `design-system` | Presets de diseño (UI/frontend) |
| `immersive-3d` | WebGL/3D para presets velocity/vice |
| `threat-modeling` | Modelado de amenazas (diseño) |
| `secure-coding` | OWASP Top 10 por stack |
| `dependency-and-secrets-audit` | Auditoría de deps y secretos |
| `cloud-iac-security` | Seguridad en CDK/AWS |

## Proyectos Python (FastAPI)

Los scripts `.js` y Husky asumen Node.js. Para Python:
- Usar `pre-commit` framework en lugar de Husky
- Llamar `node scripts/auto-commit.js` directamente desde el pre-commit hook
- Ver `docs/SETUP-COMPLETO-NIVEL-3.md` para la adaptación completa

## Referencia rápida de comandos

```bash
# Instalar globalmente (una vez)
./install.sh

# Setup de repo (desde la raíz del proyecto destino)
/path/to/claude-automation-setup/setup-repo.sh

# Generar symlinks de portabilidad (desde la raíz del proyecto)
bash setup-portability.sh

# Comandos del proyecto (una vez configurado)
npm run auto-commit -- --help
npm run auto-pr -- --help
npm run auto-jira -- --help
npm run dashboard
```
