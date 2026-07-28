# Usage Guide

## Initial installation (once)

```bash
git clone <your-repo-url> claude-automation-setup
cd claude-automation-setup
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
/path/to/claude-automation-setup/setup-repo.sh
```

This copies into the repo (**per-repo** scope — repeated for every project):
- `registry/scripts/*.js` → `<repo>/scripts/`
- `registry/templates/husky/*` → `<repo>/.husky/`
- `registry/templates/github/workflows/*` → `<repo>/.github/workflows/`
- `registry/templates/AGENTS.md` → `<repo>/AGENTS.md` (template — edit it; only if it doesn't already exist)
- `registry/templates/setup-portability.sh` → `<repo>/setup-portability.sh`
- `registry/templates/.mcp.json` → `<repo>/.mcp.json` (only if it doesn't already exist)
- `registry/rules/*.md` → `<repo>/.claude/rules/`
- `registry/rules/*.md` (generated via `tools/cursor/adapt/rule-to-mdc.sh`) → `<repo>/.cursor/rules/*.mdc`
- `registry/hooks/{pre,post}-tool-use/*.sh` → `<repo>/.claude/hooks/{pre,post}-tool-use/`
- `tools/claude/settings.json` → `<repo>/.claude/settings.json` (only if it doesn't already exist)
- `.env.example` → `<repo>/.env.local` (fill in afterward)

## Cross-tool portability

From the root of the newly configured repo:

```bash
bash setup-portability.sh
```

Creates:
- `CLAUDE.md` → symlink to `AGENTS.md`
- `GEMINI.md` → symlink to `AGENTS.md`
- `.github/copilot-instructions.md` → symlink to `../AGENTS.md`
- `.cursor/mcp.json` → symlink to `../.mcp.json`

**Rule:** Always edit `AGENTS.md`. The symlinks update themselves — **on platforms that support real symlinks.** On Windows without Developer Mode or admin rights, `ln -s` can't create a real symlink; `setup-portability.sh` detects this and falls back to a one-time copy instead, printing a warning when it does. In that case the files above are snapshots, not live links — either re-run `bash setup-portability.sh` after every `AGENTS.md` edit, or enable Developer Mode (Settings → Privacy & security → For developers) and re-run the script once to upgrade them to real symlinks.

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
| `dependency-and-secrets-audit` | Dependency and secrets audit |
| `cloud-iac-security` | Security in CDK/AWS |

## Python projects (FastAPI)

The `.js` scripts and Husky assume Node.js. For Python:
- Use the `pre-commit` framework instead of Husky
- Call `node scripts/auto-commit.js` directly from the pre-commit hook
- See `docs/SETUP-COMPLETO-NIVEL-3.md` for the full adaptation

## Quick command reference

```bash
# Install globally (once)
./install.sh

# Repo setup (from the root of the target project)
/path/to/claude-automation-setup/setup-repo.sh

# Generate portability symlinks (from the project root)
bash setup-portability.sh

# Project commands (once configured)
npm run auto-commit -- --help
npm run auto-pr -- --help
npm run auto-jira -- --help
npm run dashboard
```
