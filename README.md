# AI-Setup

Portable automation setup for Claude Code and compatible tools (Cursor, GitHub Copilot, Gemini CLI, Codex). Includes 13 agents, 12 skills, automation scripts, and git hooks that turn feature descriptions into Jira tickets, commits, PRs, and releases.

## Architecture

`registry/` is the single source of knowledge (SSOT), tool-agnostic. `install.sh` and `setup-repo.sh` distribute it to two different destinations — see the "What goes where" table below.

```
AI-Setup/
├── install.sh                    # Distributes registry/agents + registry/skills → ~/.claude/ (GLOBAL)
├── setup-repo.sh                 # Distributes the rest of registry/ → the target repo (PER-REPO)
├── plan.md                       # Original plan — historical record, see the note at the top of the file
├── registry/                     # SSOT — edited once, no duplication
│   ├── agents/                   # 13 canonical agents             → GLOBAL
│   ├── skills/                   # 12 skills (folder/SKILL.md)     → GLOBAL
│   ├── scripts/                  # auto-commit.js, auto-pr.js, etc → PER-REPO
│   ├── rules/                    # Path-scoped rules by domain     → PER-REPO
│   ├── hooks/                    # pre/post-tool-use (Claude only) → PER-REPO
│   └── templates/                # AGENTS.md, .mcp.json, husky, GitHub Actions, local-docs → PER-REPO
├── tools/                        # One adapter per tool (capabilities.yaml + enable.sh)
│   ├── claude/                   # Wrapper around today's install.sh/setup-repo.sh
│   ├── cursor/                   # registry/rules → .cursor/rules/*.mdc, agents → Custom Modes
│   └── copilot/                  # registry/* condensed → .github/copilot-instructions.md
├── lib/                          # Shared condensation engine (condense.mjs)
├── docs/                         # Reference guides + plans (some historical, marked as such)
├── CHANGELOG.md                  # Repo history
├── README.md
└── USAGE.md                      # Usage and installation guide
```

## What goes where (global vs. per-repo)

Each `registry/` subfolder has a single destination — this is what answers "does this live in `~/.claude/` or in every repo?":

| `registry/` | Destination | Installed by |
|---|---|---|
| `agents/*.md` | `~/.claude/agents/` — **global**, once per machine | `install.sh` |
| `skills/*/SKILL.md` | `~/.claude/skills/<name>/` — **global**, once per machine | `install.sh` |
| `scripts/*.js` | `<repo>/scripts/` — **per-repo** | `setup-repo.sh` |
| `rules/*.md` | `<repo>/.claude/rules/` (native) + `<repo>/.cursor/rules/*.mdc` (generated) — **per-repo** | `setup-repo.sh` + `tools/cursor/adapt/rule-to-mdc.sh` |
| `hooks/{pre,post}-tool-use/*.sh` | `<repo>/.claude/hooks/` — **per-repo**, Claude Code only | `setup-repo.sh` |
| `templates/AGENTS.md` | `<repo>/AGENTS.md` — **per-repo**, only if it doesn't already exist | `setup-repo.sh` |
| `templates/.mcp.json` | `<repo>/.mcp.json` — **per-repo** | `setup-repo.sh` |
| `templates/husky/*`, `templates/github/workflows/*` | `<repo>/.husky/`, `<repo>/.github/workflows/` — **per-repo** | `setup-repo.sh` |
| `templates/local-docs/*` | `<repo>/.local-docs/` — **per-repo**, gitignored, only if it doesn't already exist | `setup-repo.sh` |

Simple rule: **agents and skills are always global** (installed once, serve any project); **everything else in `registry/` is per-repo** (copied or re-rendered into every project that runs `setup-repo.sh`). The full detail of what each AI tool supports lives in `tools/*/capabilities.yaml`; the portability table below is its readable summary.

## Design principle: AGENTS.md as the SSOT

`AGENTS.md` is the **Single Source of Truth** for each project's instructions. Every other instructions file is a **symlink** pointing to it:

```
AGENTS.md          ← edit only here
CLAUDE.md          → symlink to AGENTS.md
GEMINI.md          → symlink to AGENTS.md
.github/copilot-instructions.md → symlink to ../AGENTS.md
.cursor/mcp.json   → symlink to ../.mcp.json
```

An edit to `AGENTS.md` shows up across every tool — where the platform supports real symlinks. On Windows without Developer Mode or admin rights, `setup-portability.sh` falls back to one-time copies instead and warns when it does; see `USAGE.md`'s "Cross-tool portability" section for the fallback behavior and how to upgrade to real symlinks.

## Portability by layer

Source of truth: `tools/*/capabilities.yaml` (one per tool with a real adapter). Gemini CLI and Codex today only get the instructions layer rendered by this repo (they read `AGENTS.md` natively or via the `GEMINI.md` symlink) — there's no `tools/gemini/` or `tools/codex/` yet; adding one is the pending Fase 5 in `docs/AI-SETUP-PLAN-v2.md`. Every cell below has a verification date + source in `docs/tool-compatibility.md`.

| Layer | Claude Code | Cursor | Copilot | Gemini CLI | Codex |
|------|:-----------:|:------:|:-------:|:----------:|:-----:|
| Instructions | ✅ symlink `CLAUDE.md` | ✅ native `AGENTS.md` | ✅ condensed → `copilot-instructions.md` | ✅ symlink `GEMINI.md` | ✅ native `AGENTS.md` |
| Agents | ✅ native (real subagents) | ✅ Custom Mode (1 file per agent) | ✅ condensed (roster in instructions) | ❌ no adapter | ❌ no adapter |
| Skills | ✅ auto-discovery | ✅ native auto-discovery (`.cursor/skills/`; also reads `~/.claude/skills/` directly, no adapter needed) | ✅ condensed | ❌ no adapter | 🟡 native `SKILL.md` support exists (since ~Dec 2025) but this repo doesn't render into it yet — no `tools/codex/` adapter |
| Rules | ✅ native `.claude/rules` | ✅ generated `.mdc` (`rule-to-mdc.sh`) | ✅ condensed | ❌ no adapter | ❌ no adapter |
| Hooks | ✅ native (`PreToolUse`/`PostToolUse`) | ✅ bridged (`.cursor/hooks.json` + `hook-to-cursor.sh`, since Cursor 1.7) | ❌ no equivalent | ❌ no equivalent | ❌ no equivalent |
| MCP | ✅ native `.mcp.json` | ✅ native `.cursor/mcp.json` | 🟡 partial (varies by surface) | ❌ no adapter | ❌ no adapter |

## The 13 Agents

| Agent | Specialization |
|--------|----------------|
| `agent-orchestrator` | Master orchestrator — entry point for full features |
| `solutions-expert` | System architecture and design |
| `ticket-orchestrator` | Jira hierarchy (Epic → Story → Task) |
| `backend-expert` | NestJS / FastAPI / MongoDB |
| `iot-backend-expert` | Raspberry Pi / GPIO / edge computing |
| `frontend-expert` | React / Next.js / Astro + a11y + design |
| `aws-architect` | AWS cloud architecture |
| `cdk-expert` | Infrastructure as Code (CDK) |
| `test-engineer` | Unit tests + coverage quality |
| `pr-manager` | Pull requests with the project's standard format |
| `code-reviewer-pro` | General review + light security scanning |
| `security-expert` | Deep AppSec (auth, crypto, IAM, secrets) |
| `documentation-generator` | Docs + semantic versioning + GitHub Releases |

## The 12 Skills

| Skill | Domain |
|-------|---------|
| `auto-commit` | Conventional Commits |
| `pr-formatter` | PR format (the project's own standard) |
| `semantic-versioning` | SemVer + CHANGELOG + releases |
| `iot-backend` | IoT / Raspberry Pi |
| `auto-pr` | Automatic PR creation |
| `jira-integration` | Jira integration |
| `design-system` | Design presets (velocity / vice / quiet) |
| `immersive-3d` | WebGL / R3F / immersive experiences |
| `threat-modeling` | STRIDE threat modeling |
| `secure-coding` | OWASP Top 10 by stack |
| `cloud-iac-security` | CDK / AWS security |
| `local-docs` | `.local-docs/` format + update rules (plan, architecture, security gaps, decisions) |

## Documentation

- **Usage and installation guide** → [`USAGE.md`](USAGE.md)
- **Repo change history** → [`CHANGELOG.md`](CHANGELOG.md)
- **Active roadmap (multi-tool architecture)** → [`docs/AI-SETUP-PLAN-v2.md`](docs/AI-SETUP-PLAN-v2.md) — Fases 1-4 done, 5-6 pending
- **Cross-tool compatibility** → [`docs/tool-compatibility.md`](docs/tool-compatibility.md)
- **Context budget** → [`docs/context-budget.md`](docs/context-budget.md)
- **GitHub Actions** → [`docs/GITHUB-ACTIONS-SETUP.md`](docs/GITHUB-ACTIONS-SETUP.md)
- **MCP configuration** → [`docs/MCPS-configuracion-completa.md`](docs/MCPS-configuracion-completa.md) _(historical — see the note at the top of the file)_
- **Git Hooks (Husky)** → [`docs/HOOKS-husky-complete.md`](docs/HOOKS-husky-complete.md) _(historical — see the note at the top of the file)_
- **Original Nivel 3 setup** → [`docs/SETUP-COMPLETO-NIVEL-3.md`](docs/SETUP-COMPLETO-NIVEL-3.md) _(historical — see the note at the top of the file)_
- **Original Nivel 3 index** → [`docs/INDICE-FINAL-NIVEL-3.md`](docs/INDICE-FINAL-NIVEL-3.md) _(historical — see the note at the top of the file)_
- **2026-06 restructure** → [`docs/RESTRUCTURE-2026-06.md`](docs/RESTRUCTURE-2026-06.md) _(historical)_
- **2026-07 plan vs. reality** → [`docs/PLAN-VS-REALIDAD-2026-07.md`](docs/PLAN-VS-REALIDAD-2026-07.md) _(historical, a snapshot of a specific moment)_
