# Usage Guide

## Initial installation (once)

```bash
git clone <your-repo-url> AI-Setup
cd AI-Setup
chmod +x install.sh setup-repo.sh
./install.sh
```

`install.sh` copies to `~/.claude/` (**global** scope — once per machine, serves any project):
- `registry/agents/*` → `~/.claude/agents/` (13 agents)
- `registry/skills/*/` → `~/.claude/skills/` (12 skills in folder format)

See the "What goes where" table in [`README.md`](README.md) for the full mapping of each `registry/` folder.

## Per-project setup (in each repo)

From the root of the target repo:

```bash
/path/to/AI-Setup/setup-repo.sh
```

This copies into the repo (**per-repo** scope — repeated for every project):
- `registry/scripts/*.js` → `<repo>/scripts/`
- `registry/templates/husky/*` → `<repo>/.husky/`
- `registry/templates/github/workflows/*` → `<repo>/.github/workflows/`
- `registry/templates/AGENTS.md` → `<repo>/AGENTS.md` (template — edit it; if it already exists, missing required lines are patched in instead — see "Upgrading an existing repo" below)
- `registry/templates/CLAUDE.md`, `registry/templates/GEMINI.md` → `<repo>/CLAUDE.md`, `<repo>/GEMINI.md` (real one-line files, `@AGENTS.md` — Claude Code's and Gemini CLI's native import syntax, not a symlink; refreshed every run since their content never changes)
- `registry/templates/.mcp.json` → `<repo>/.mcp.json` (only if it doesn't already exist)
- `<repo>/.mcp.json` → `<repo>/.cursor/mcp.json` (real copy, not a symlink — Cursor reads this exact path; refreshed every run so it can't drift from `.mcp.json`)
- `registry/templates/local-docs/*.md` → `<repo>/.local-docs/` (gitignored, only if it doesn't already exist — see below)
- `registry/rules/*.md` → `<repo>/.claude/rules/`
- `registry/rules/*.md` (generated via `tools/cursor/adapt/rule-to-mdc.sh`) → `<repo>/.cursor/rules/*.mdc`
- `registry/hooks/{pre,post}-tool-use/*.sh` → `<repo>/.claude/hooks/{pre,post}-tool-use/`
- `registry/hooks/*` (bridged via `tools/cursor/adapt/hook-to-cursor.sh`) → `<repo>/.cursor/hooks.json` + `<repo>/.cursor/hooks/_bridge.sh`
- `tools/claude/settings.json` → `<repo>/.claude/settings.json` (only if it doesn't already exist)
- `registry/` (condensed via `lib/condense.mjs`, needs `node` on PATH) → `<repo>/.github/copilot-instructions.md` — regenerated every run; skipped with a warning if `node` isn't available
- `.env.example` → `<repo>/.env.local` (fill in afterward)

### `.local-docs/` — local-only human context

`setup-repo.sh` also creates `<repo>/.local-docs/` (gitignored, never pushed)
with starter files: `plan.md` (the project's living working plan — phases,
tasks, status), `architecture.md`, `security-gaps.md`, and `decisions.md`.
Agents keep these current as work happens — see the `local-docs` skill and
the folder's own `README.md` for the update rules.

## Upgrading an existing repo

Repos already set up with an earlier version of this tooling can safely pick
up new agents, skills, hooks, and workflows — nothing here overwrites
project-specific customization:

```bash
# 1. Refresh agents + skills globally (backs up the previous ones with a timestamp)
./install.sh

# 2. Refresh this repo's per-repo files
cd /path/to/your-repo
/path/to/AI-Setup/setup-repo.sh
```

Re-running `setup-repo.sh` is always safe:
- Files with no per-repo customization (`.husky/*`, `.github/workflows/*`, `scripts/*.js`, `.claude/rules/*`, `.cursor/rules/*`, `.claude/hooks/*`, `CLAUDE.md`, `GEMINI.md`, `.cursor/mcp.json`, `.cursor/hooks.json`, `.github/copilot-instructions.md`) are refreshed unconditionally.
- Files meant to hold your own customization (`.mcp.json`, `.claude/settings.json`, `.env.local`) are left untouched if they already exist.
- `AGENTS.md` is a hybrid: if it doesn't exist yet, it's copied from the template; if it already exists, only the new lines it's missing (e.g. a new convention added by a later AI-Setup release) are appended at the end — your existing content is never rewritten.
- `.local-docs/` is created only if missing — an existing one (with real tracked plan/architecture/security-gap content) is always left alone.

## Cross-tool portability

Nothing to run manually — `setup-repo.sh` does all of it in one pass. `AGENTS.md` is the only file you ever edit; every other tool's instructions file follows automatically:

- **Claude Code / Gemini CLI**: `CLAUDE.md` / `GEMINI.md` are real one-line files containing `@AGENTS.md` — both tools support this import syntax natively (Claude Code resolves imports up to 5 hops deep; the first time a project uses external imports, Claude Code shows a one-time approval prompt). No symlink, so this works identically on every platform, including Windows with no Developer Mode or admin rights.
- **Cursor**: reads `AGENTS.md` directly (no file needed), and `.cursor/mcp.json` (a real copy of `.mcp.json`, regenerated every `setup-repo.sh` run — Cursor reads this exact path, not a root `.mcp.json`).
- **GitHub Copilot**: `.github/copilot-instructions.md` is a condensed rendering of the whole `registry/` (agents, skills, rules — not a copy of `AGENTS.md`), regenerated every run via `lib/condense.mjs`. Requires `node` on the machine running `setup-repo.sh`; skipped with a warning if it's missing.

This replaced a manual `bash setup-portability.sh` step (retired in Fase 2 of `update-plan-aug-2026.md`, 2026-08-24 — see `docs/archive/setup-portability.sh`) that symlinked these files instead, with a Windows fallback for when real symlinks weren't available. That whole fallback branch no longer exists — it isn't needed.

## Configuring the target repo

### 1. Edit AGENTS.md
Fill in: project name, tech stack, real commands, architecture paths.

### 2. Fill in credentials
```bash
# Edit .env.local
```
Required variables:
```
GITHUB_TOKEN=ghp_...
JIRA_URL=https://your-org.atlassian.net
JIRA_TOKEN=...
JIRA_EMAIL=you@email.com
```

### 3. Configure the design preset (projects with a UI)
In `.claude/rules/design.md`, change the line:
```
Design preset: velocity  # or vice | quiet
```

### 4. Node.js: finish setup
```bash
npm install --save-dev minimist husky
npx husky install
```
Add to `package.json`:
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

### 5. Activate GitHub Actions secrets
In GitHub: Settings → Secrets → Actions → Add:
- `JIRA_HOST`
- `JIRA_EMAIL`
- `JIRA_API_TOKEN`

### 6. Test
```bash
npm run auto-commit -- --help
```

## MCPs (Model Context Protocol)

MCP servers are configured in the repo's `.mcp.json`. Claude Code detects them automatically when opening the project.

See `docs/MCPS-configuracion-completa.md` for detailed installation of each server.

## Rules structure

Rules in `.claude/rules/` load automatically based on the file being edited:

| Rule | Paths that trigger it |
|------|---------------------|
| `backend.md` | `src/api/**`, `src/services/**` |
| `frontend.md` | `src/components/**`, `src/app/**` |
| `testing.md` | `src/**/*.test.*`, `tests/**` |
| `design.md` | `src/components/**`, `src/styles/**` |
| `security.md` | `src/auth/**`, `infra/**` |

For Cursor: equivalents in `.cursor/rules/*.mdc`.

## Available agents

See the repo's `AGENTS.md` for the full decision tree.

| Agent | Main use |
|--------|---------------|
| `agent-orchestrator` | Entry point for full features |
| `solutions-expert` | Solution architecture and design |
| `ticket-orchestrator` | Generate Jira hierarchy |
| `backend-expert` | NestJS/FastAPI/MongoDB APIs |
| `iot-backend-expert` | Raspberry Pi/GPIO/edge |
| `frontend-expert` | React/Next.js/Astro + a11y + design |
| `aws-architect` | AWS architecture |
| `cdk-expert` | CDK / IaC |
| `test-engineer` | Unit tests + coverage quality (before general review) |
| `pr-manager` | Create PRs with the project's standard format |
| `code-reviewer-pro` | General review (always before a PR) |
| `security-expert` | Deep AppSec (auth/crypto/IAM) |
| `documentation-generator` | Docs + versioning + releases |

## Available skills

| Skill | When it's used |
|-------|---------------|
| `auto-commit` | Committing with Conventional Commits |
| `pr-formatter` | Formatting PR descriptions |
| `semantic-versioning` | Version bumps and releases |
| `iot-backend` | Hardware/GPIO/edge code |
| `auto-pr` | Creating PRs automatically |
| `jira-integration` | Interacting with Jira |
| `design-system` | Design presets (UI/frontend) |
| `immersive-3d` | WebGL/3D for velocity/vice presets |
| `threat-modeling` | Threat modeling (design) |
| `secure-coding` | OWASP Top 10 by stack |
| `cloud-iac-security` | Security in CDK/AWS |
| `local-docs` | `.local-docs/` format + update rules |

## Python projects (FastAPI)

The `.js` scripts and Husky assume Node.js. For Python:
- Use the `pre-commit` framework instead of Husky
- Call `node scripts/auto-commit.js` directly from the pre-commit hook
- See `docs/SETUP-COMPLETO-NIVEL-3.md` for the full adaptation

## Quick command reference

```bash
# Install globally (once)
./install.sh

# Repo setup (from the root of the target project) — also handles
# cross-tool portability (CLAUDE.md, GEMINI.md, .cursor/mcp.json,
# .github/copilot-instructions.md); no separate step needed
/path/to/AI-Setup/setup-repo.sh

# Project commands (once configured)
npm run auto-commit -- --help
npm run auto-pr -- --help
npm run auto-jira -- --help
npm run dashboard
```
