# claude-automation-setup

Setup portable de automatización para Claude Code y herramientas compatibles (Cursor, GitHub Copilot, Gemini CLI, Codex). Incluye 13 agentes, 12 skills, scripts de automatización y hooks git que convierten descripciones de features en tickets Jira, commits, PRs y releases.

## Arquitectura

```
claude-automation-setup/
├── install.sh                    # Instala agentes y skills en ~/.claude/
├── setup-repo.sh                 # Configura un repo destino con todos los archivos
├── USAGE.md                      # Guía de uso e instalación
├── .env.example                  # Template de credenciales
├── global/                       # Configuración global (va a ~/.claude/)
│   ├── agents/                   # 12 agentes especializados
│   └── skills/                   # 12 skills en formato portable (carpeta/SKILL.md)
├── per-repo/                     # Archivos que van en cada proyecto
│   ├── AGENTS.md                 # Template SSOT — instrucciones del proyecto
│   ├── setup-portability.sh      # Genera symlinks cross-tool (CLAUDE.md, GEMINI.md, etc.)
│   ├── .mcp.json                 # MCP servers (GitHub, Git, Jira)
│   ├── .claude/
│   │   ├── rules/                # Rules path-scoped (backend, frontend, testing, design, security)
│   │   ├── hooks/                # Hooks Claude Code (block-secrets, lint-after-write)
│   │   └── settings.json         # Registro de hooks
│   ├── .cursor/
│   │   └── rules/                # Equivalentes Cursor (.mdc)
│   ├── .github/workflows/        # GitHub Actions (pr-validation, on-merge)
│   ├── .husky/                   # Git hooks (pre-commit, prepare-commit-msg, etc.)
│   └── scripts/                  # Scripts de automatización (auto-commit, auto-pr, etc.)
└── docs/                         # Documentación de referencia
    ├── context-budget.md
    ├── MCPS-configuracion-completa.md
    ├── GITHUB-ACTIONS-SETUP.md
    ├── HOOKS-husky-complete.md
    └── SETUP-COMPLETO-NIVEL-3.md
```

## Principio de diseño: AGENTS.md como SSOT

`AGENTS.md` es el **Single Source of Truth** de instrucciones de cada proyecto. Los demás archivos de instrucciones son **symlinks** que apuntan a él:

```
AGENTS.md          ← editar solo aquí
CLAUDE.md          → symlink a AGENTS.md
GEMINI.md          → symlink a AGENTS.md
.github/copilot-instructions.md → symlink a ../AGENTS.md
.cursor/mcp.json   → symlink a ../.mcp.json
```

Una edición en `AGENTS.md` se refleja en todas las herramientas.

## Portabilidad por capa

| Elemento | Archivo | Claude Code | Cursor | Copilot | Gemini | Codex |
|----------|---------|:-----------:|:------:|:-------:|:------:|:-----:|
| Instrucciones | `AGENTS.md` | ✅ symlink | ✅ nativo | ✅ symlink | ✅ symlink | ✅ nativo |
| Skills | `SKILL.md` | ✅ | ✅ apuntando | 🟡 | ✅ apuntando | ✅ |
| MCP | `.mcp.json` | ✅ | ✅ symlink | 🟡 | 🟡 | 🟡 |
| Rules | `.claude/rules` + `.cursor/rules` | ✅ | ✅ `.mdc` | 🟡 | 🟡 | 🟡 |
| Hooks | `.claude/hooks` | ✅ | ❌ | ❌ | ❌ | ❌ |
| Agentes | `~/.claude/agents` | ✅ | ❌ | ❌ | ❌ | ❌ |

## Los 13 Agentes

| Agente | Especialización |
|--------|----------------|
| `agent-orchestrator` | Orquestador maestro — punto de entrada para features completas |
| `solutions-expert` | Arquitectura y diseño de sistemas |
| `ticket-orchestrator` | Jerarquía Jira (Epic → Story → Task) |
| `backend-expert` | NestJS / FastAPI / MongoDB |
| `iot-backend-expert` | Raspberry Pi / GPIO / edge computing |
| `frontend-expert` | React / Next.js / Astro + a11y + diseño |
| `aws-architect` | Arquitectura cloud AWS |
| `cdk-expert` | Infrastructure as Code (CDK) |
| `test-engineer` | Tests unitarios + calidad de cobertura |
| `pr-manager` | Pull requests con el formato estándar del proyecto |
| `code-reviewer-pro` | Review general + scanning de seguridad ligero |
| `security-expert` | AppSec profundo (auth, crypto, IAM, secretos) |
| `documentation-generator` | Docs + versionado semántico + GitHub Releases |

## Las 12 Skills

| Skill | Dominio |
|-------|---------|
| `auto-commit` | Conventional Commits |
| `pr-formatter` | Formato de PRs (estándar propio del proyecto) |
| `semantic-versioning` | SemVer + CHANGELOG + releases |
| `iot-backend` | IoT / Raspberry Pi |
| `auto-pr` | Creación automática de PRs |
| `jira-integration` | Integración con Jira |
| `design-system` | Presets de diseño (velocity / vice / quiet) |
| `immersive-3d` | WebGL / R3F / experiencias inmersivas |
| `threat-modeling` | Modelado de amenazas STRIDE |
| `secure-coding` | OWASP Top 10 por stack |
| `dependency-and-secrets-audit` | SCA + escaneo de secretos + SBOM |
| `cloud-iac-security` | Seguridad en CDK / AWS |

## Documentación

- **Guía de uso e instalación** → [`USAGE.md`](USAGE.md)
- **Presupuesto de contexto** → [`docs/context-budget.md`](docs/context-budget.md)
- **Configuración de MCPs** → [`docs/MCPS-configuracion-completa.md`](docs/MCPS-configuracion-completa.md)
- **GitHub Actions** → [`docs/GITHUB-ACTIONS-SETUP.md`](docs/GITHUB-ACTIONS-SETUP.md)
- **Git Hooks (Husky)** → [`docs/HOOKS-husky-complete.md`](docs/HOOKS-husky-complete.md)
- **Setup completo Nivel 3** → [`docs/SETUP-COMPLETO-NIVEL-3.md`](docs/SETUP-COMPLETO-NIVEL-3.md)
