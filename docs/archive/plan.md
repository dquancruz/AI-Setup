# PLAN.md — Migration to a Portable Multi-Tool Setup

> **📜 Superseded.** This plan has already been executed (Fases 1-4, see commits `090861a`..`420809b`) and was replaced by [`docs/AI-SETUP-PLAN-v2.md`](docs/AI-SETUP-PLAN-v2.md), which picks up the multi-tool architecture with the `registry/` + `tools/*/capabilities.yaml` design actually implemented. This file is kept unedited as a historical record of the original decision — for the current state and roadmap, see `docs/AI-SETUP-PLAN-v2.md` and `README.md`.

> **For:** Claude Code
> **Repo:** `claude-automation-setup`
> **Objective:** Evolve the current setup (11 agents + 6 skills + scripts + hooks) toward the 2026 standard architecture — **without losing portability** across Claude Code, Cursor, GitHub Copilot, Gemini CLI, and Codex — and add two new capabilities: **design with presets** (Fase 9) and **security / AppSec** (Fase 10). The 11 agents **stay separate** (Fase 5), growing to 12 with the security one.

---

## 0. Context and guiding principle

The current setup is solid on agents/skills/scripts, but it's missing the **persistent context** layer and is coupled to Claude Code. The goal is NOT to tie it more to Claude Code, but the opposite: build a setup so portable that if you switch tools tomorrow (or work with teammates using Cursor or Copilot), everything travels with you.

**Guiding principle:** `AGENTS.md` is the **Single Source of Truth (SSOT)**. All other tool-specific instruction files are **symlinks** pointing to it. You write the rules once, every tool reads them.

### Portability ranking by layer (most to least portable)

| Layer | Standard / format | Portability | Strategy |
|------|--------------------|--------------|------------|
| Instructions | `AGENTS.md` | ✅ Universal | SSOT + symlinks |
| Skills | `SKILL.md` (Agent Skills) | ✅ High | Portable folder + frontmatter |
| MCP servers | `.mcp.json` | ✅ High | Standard schema, env vars |
| Rules (path-scoped) | varies by tool | 🟡 Medium | `.claude/rules/` + `.cursor/rules/` |
| Hooks | varies by tool | 🟠 Low | Keep Claude-specific |
| Subagents | a Claude Code concept | 🟠 Low | Document the workflow in AGENTS.md |

> The portable layers (instructions, skills, MCP) carry 80% of the value and work across every tool. The non-portable ones (hooks, subagents) stay specific to Claude Code but are documented in AGENTS.md as the "expected workflow" so another tool can replicate it by hand.

---

## 1. Target repository structure

By the end of the plan, the `per-repo/` structure (what gets copied into each project) should look like this:

```
<project>/
├── AGENTS.md                      # ⭐ SSOT — project instructions
├── CLAUDE.md                      # → symlink to AGENTS.md
├── GEMINI.md                      # → symlink to AGENTS.md
├── .github/
│   └── copilot-instructions.md    # → symlink to ../AGENTS.md
├── .mcp.json                      # MCP servers (Claude Code, standard schema)
├── .cursor/
│   ├── mcp.json                   # → symlink to ../.mcp.json (same schema)
│   └── rules/                     # Rules in Cursor format (.mdc)
├── .claude/
│   ├── rules/                     # Path-scoped rules (Claude Code)
│   │   ├── backend.md
│   │   ├── frontend.md
│   │   ├── testing.md
│   │   ├── design.md              # client's design preset (Fase 9)
│   │   └── security.md            # path-scoped security rules (Fase 10)
│   └── hooks/                     # Claude-Code-specific hooks
│       ├── pre-tool-use/
│       └── post-tool-use/
├── .husky/                        # Git hooks (already exists)
├── scripts/                       # Automation scripts (already exists)
└── .env.local                     # Secrets (gitignored, already exists)
```

And the `global/` folder (what gets installed to `~/.claude/`) stays, but the skills are updated to the portable format.

---

## 2. FASE 1 — Create `AGENTS.md` as the SSOT + cross-tool symlinks

**This is the most important phase. It makes everything else portable.**

### Tasks

- [ ] Create `per-repo/AGENTS.md` with the template below.
- [ ] Create the `per-repo/setup-portability.sh` script that generates the symlinks.
- [ ] Keep it **under ~150 lines** (context budget; models track ~150-200 instructions and the system prompt already uses ~50).

### Template: `per-repo/AGENTS.md`

```markdown
# <Project Name>

> One line: what this repo is.

## Tech Stack
- Runtime: <Node.js 20 / Python 3.12>
- Framework: <Next.js 15 / FastAPI>
- Database: <MongoDB / PostgreSQL>
- Testing: <Jest / pytest>
- Infra: <AWS + CDK>

## Commands (exact invocations)
- Build:  `npm run build`
- Test:   `npm test`        # prefer individual tests: `npm test -- <file>`
- Lint:   `npm run lint`
- Deploy: `npm run deploy`
- Auto-commit: `npm run auto-commit -- --help`

## Architecture (point to files, don't describe in prose)
- `src/api/`        → endpoints and backend logic
- `src/components/` → UI components
- `scripts/`        → automation (commit, PR, release)
- See `docs/` for detailed architecture.

## Project conventions
- <Server components by default; 'use client' only when necessary>
- <Soft deletes on table X — never delete physically>
- Commits: Conventional Commits (see the semantic-versioning skill).

## Agent workflow (Claude Code)
These subagents live in `~/.claude/agents/`. On other tools,
replicate the flow manually:
- Architecture/design  → `solutions-expert`
- Backend (API)        → `backend-expert`
- Frontend             → `frontend-expert`
- Infra (AWS/CDK)      → `infrastructure-expert`
- PRs                  → `pr-manager`
- Review + security    → `code-reviewer`

Typical pipeline: solutions-expert → (backend|frontend) → code-reviewer → pr-manager.

## Critical rules (YOU MUST)
- NEVER push directly to `main`.
- NEVER commit `.env.local` or secrets.
- ALWAYS run lint + tests before a PR.
- Bounded scope: don't read hundreds of files; use a research subagent.
```

> **Why this format:** it leads with commands (the highest-ROI section), points to files instead of describing them, and includes the "why" behind non-obvious rules. It doesn't duplicate what the linter already does.

### Script: `per-repo/setup-portability.sh`

```bash
#!/usr/bin/env bash
# Generates the symlinks that point to the SSOT (AGENTS.md).
# Run from the root of the target repo.
set -euo pipefail

[ -f AGENTS.md ] || { echo "❌ AGENTS.md is missing (the SSOT). Create it first."; exit 1; }

# Claude Code
ln -sf AGENTS.md CLAUDE.md
# Gemini CLI
ln -sf AGENTS.md GEMINI.md
# GitHub Copilot (looks in .github/)
mkdir -p .github
ln -sf ../AGENTS.md .github/copilot-instructions.md
# Cursor reads AGENTS.md natively — no instructions symlink needed.

echo "✅ Symlinks created: CLAUDE.md, GEMINI.md, .github/copilot-instructions.md → AGENTS.md"
echo "ℹ️  Cursor and Codex read AGENTS.md directly."
```

### Fase 1 verification
- [ ] `cat CLAUDE.md` shows AGENTS.md's content.
- [ ] `ls -la` shows the symlinks (`->`) and not copies.
- [ ] Editing AGENTS.md → the change shows up in every symlink.

---

## 3. FASE 2 — Portable MCP (`.mcp.json`)

Today the MCPs (Jira, Git, GitHub) are configured by hand in Claude. Centralizing them in `.mcp.json` (a standard schema) makes them versionable and reusable by Cursor.

### Tasks
- [ ] Create `per-repo/.mcp.json` (template below).
- [ ] Create the `.cursor/mcp.json` → `../.mcp.json` symlink (Cursor uses the same schema).
- [ ] Use **environment variable interpolation** for secrets (never tokens in plaintext).
- [ ] Confirm the exact packages/URLs against `docs/MCPS-configuracion-completa.md`.

### Template: `per-repo/.mcp.json`

```json
{
  "mcpServers": {
    "github": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-github"],
      "env": { "GITHUB_TOKEN": "${GITHUB_TOKEN}" }
    },
    "git": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-git", "--repository", "."]
    },
    "jira": {
      "command": "npx",
      "args": ["-y", "<mcp-jira-package-from-your-docs>"],
      "env": {
        "JIRA_URL": "${JIRA_URL}",
        "JIRA_TOKEN": "${JIRA_TOKEN}"
      }
    }
  }
}
```

### Cursor symlink
```bash
mkdir -p .cursor
ln -sf ../.mcp.json .cursor/mcp.json
```

### Fase 2 verification
- [ ] `.mcp.json` contains no plaintext secrets (only `${VAR}`).
- [ ] The variables (`GITHUB_TOKEN`, `JIRA_URL`, etc.) are in `.env.example` and `.env.local`.
- [ ] Claude Code detects all 3 MCPs on startup in a test repo.

---

## 4. FASE 3 — Portable skills (Agent Skills format)

The 6 current skills need to migrate to the `SKILL.md` standard with frontmatter so that: (a) Claude auto-discovers them via progressive disclosure, and (b) Cursor/Codex/Gemini can read them by pointing at the folder.

### Tasks
- [ ] For each skill in `global/skills/`, create a `<name>/SKILL.md` structure.
- [ ] Add frontmatter (`name`, `description`, `argument-hint`, `tools`) to each.
- [ ] The `description` must be specific — it's what triggers the skill to load.
- [ ] (Optional) Create `global/skills/README.md` documenting how to point Cursor/Gemini at this folder for portability.

### Format of each `SKILL.md`

```markdown
---
name: auto-commit
description: Generates semantic commit messages (Conventional Commits). Use
  when the user wants to commit changes or asks for "auto-commit". Triggers
  with staged changes ready to commit.
argument-hint: --message "feat: add auth" --scope api
tools: [git, bash]
---

# Auto-Commit Best Practices

1. Analyze `git diff --staged`.
2. Determine the type: feat | fix | chore | docs | refactor | test.
3. Generate the message in Conventional Commits format.
4. ...
```

Mapping of the 6 current skills:
- [ ] `iot-backend/SKILL.md` ← IoT Backend Best Practices
- [ ] `pr-formatter/SKILL.md` ← PR Description Formatter
- [ ] `semantic-versioning/SKILL.md` ← Semantic Versioning Control
- [ ] `auto-commit/SKILL.md` ← Auto-Commit Best Practices
- [ ] `auto-pr/SKILL.md` ← Auto-PR Creation Guide
- [ ] `jira-integration/SKILL.md` ← Jira Integration Patterns

### Fase 3 verification
- [ ] Every skill has valid frontmatter with `name` and `description`.
- [ ] The descriptions are actionable (they say *when* to use the skill).
- [ ] `README.md` explains the command for Cursor/Gemini to read the folder.

---

## 5. FASE 4 — Path-scoped rules

Rules load **only** when Claude is working in directories that match, keeping context clean. Replicate for Cursor with `.cursor/rules/*.mdc`.

### Tasks
- [ ] Create `per-repo/.claude/rules/` with per-domain files + `paths` frontmatter.
- [ ] Create the Cursor equivalent in `per-repo/.cursor/rules/` (`.mdc` format with `globs`).

### Claude example: `.claude/rules/backend.md`
```markdown
---
paths: ["src/api/**", "src/services/**"]
---
# Backend Conventions
- Validate input with <Zod / Pydantic> on every endpoint.
- Typed errors, never a generic `throw`.
- ...
```

### Cursor example: `.cursor/rules/backend.mdc`
```markdown
---
description: Backend conventions
globs: ["src/api/**", "src/services/**"]
alwaysApply: false
---
- Validate input with <Zod / Pydantic> on every endpoint.
- ...
```

Create at least: `backend`, `frontend`, `testing`.

### Fase 4 verification
- [ ] Editing a file in `src/api/` activates `backend` and NOT `frontend`.
- [ ] The rules' content does NOT duplicate what's already in AGENTS.md (avoid context redundancy).

---

## 6. FASE 5 — Keep the 11 agents separate (+ decision tree)

**Decision made:** the 11 agents are kept as **separate** entities, so they can work in parallel on different tasks without stepping on each other. **They are NOT consolidated.** With the security agent (Fase 10), the set grows to **12**.

The only risk of having many agents is context (confusion about which one to use). It's mitigated with a **clear decision tree**, not by merging them.

### Tasks
- [ ] Do NOT merge agents. Keep the current 11 as-is.
- [ ] In `AGENTS.md`, write a "which one to use" decision tree covering all 12 agents (the 11 + `security-expert`), so the choice is unambiguous.
- [ ] For each agent, explicitly declare in its frontmatter the `skills` and `tools` it can use (subagents **don't automatically inherit skills**).
- [ ] Make sure every agent has an actionable `description` (says WHEN to invoke it) — so Claude Code picks the right one on its own.

### Decision tree (template for AGENTS.md)
```
What do you need?
- Design architecture / decide the approach   → solutions-expert
- Generate a Jira ticket hierarchy            → ticket-orchestrator
- Backend API (NestJS/FastAPI/Mongo)          → backend-expert
- IoT backend (Raspberry Pi/GPIO/edge)        → iot-backend-expert
- Frontend (React/Next/Astro + a11y)          → frontend-expert
- AWS architecture                            → aws-architect
- Infra as Code (CDK)                         → cdk-expert
- Create a PR (TELUS format)                  → pr-manager
- General review + light scanning             → code-reviewer-pro
- Deep security (AppSec)                      → security-expert   [Fase 10]
- Docs + versioning + releases                → documentation-generator
- Orchestrate several of the above            → agent-orchestrator
```

### Fase 5 verification
- [ ] All 12 agents exist in `~/.claude/agents/` with an actionable `description`.
- [ ] Each agent declares its `skills`/`tools` in frontmatter.
- [ ] The decision tree in AGENTS.md covers all 12 with no ambiguity.

---

## 7. FASE 6 — Claude Code hooks (PreToolUse / PostToolUse)

Husky covers git, but Claude's hooks that act **before** writing to disk are still missing. These are Claude-Code-specific (not portable), but their intent is documented in AGENTS.md.

### Tasks
- [ ] Create `per-repo/.claude/hooks/pre-tool-use/block-secrets.sh` (blocks writes containing secret patterns / `.env`).
- [ ] Create `per-repo/.claude/hooks/post-tool-use/lint-after-write.sh` (runs the linter after edits and returns non-blocking feedback).
- [ ] Register the hooks in `.claude/settings.json`.
- [ ] Do **not** block writes in the middle of a multi-step plan (it breaks sequential reasoning).

### Fase 6 verification
- [ ] Attempting to write a token triggers block-secrets.
- [ ] After editing a file, lint runs automatically.

---

## 8. FASE 7 — Document the context budget

### Tasks
- [ ] Create `docs/context-budget.md` with the context-management guide.

### Suggested content
```markdown
# Context Management

## Budget per session (approx.)
- AGENTS.md:        ~100 tokens (always loaded)
- Rules:             ~200 tokens (filtered by path)
- Skills:            ~50 tokens each (on demand)
- MCP definitions:   ~500+ tokens
- Usable budget:     ~1.5-2k tokens before you start working.

## Practices
- One task per conversation. `/clear` between unrelated tasks.
- Investigations >50 files → spawn a subagent, not in the main context.
- If the model gets it wrong twice, `/clear` and restart with a better prompt.
- Never dump the whole repo into context.
```

---

## 9. FASE 8 — Update install scripts

### Tasks
- [ ] `setup-repo.sh`: besides copying scripts/hooks, it must:
  - Copy `AGENTS.md` (template), `.mcp.json`, `.claude/rules/`, `.claude/hooks/`, `.cursor/rules/`.
  - Run `setup-portability.sh` to generate the symlinks.
  - Create the `.cursor/mcp.json` → `../.mcp.json` symlink.
  - Add `.env.local` to `.gitignore` (already done) and verify the symlinks don't break anything.
- [ ] `install.sh`: add a note in the output about how to point Cursor/Gemini/Codex at `~/.claude/skills/` to reuse the skills.
- [ ] Update the repo's `README.md` with the new portable architecture and the "what's portable vs. tool-specific" table.

### Fase 8 verification
- [ ] Running `setup-repo.sh` in a clean repo produces the full structure from section 1.
- [ ] Every symlink resolves correctly.

---

## 10. FASE 9 — Design skills (presets + 3D)

Adds design capability: a **preset registry** invocable by keyword and a **3D** skill, plus design direction in `frontend-expert`. Base content already drafted in `design-system-SKILL.md` and `immersive-3d-SKILL.md` (use as a starting point; adjust to taste).

### Tasks
- [ ] Create `global/skills/design-system/SKILL.md` — the preset registry. Must contain: (a) how a preset is invoked (in the prompt, or via `Design preset:` in the repo's rules), (b) universal principles + anti-patterns + quality floor, (c) the `velocity`, `vice`, `quiet` presets with their tokens (color/type/scale/motion/signature), (d) the framing **"presets are a starting point, not law"** — adaptable: hex/fonts/scales; firm: anti-patterns + accessibility.
- [ ] Create `global/skills/immersive-3d/SKILL.md` — 3D/WebGL technique. Must cover: 3D per preset (`velocity` = real-time object + scroll-camera; `vice` = cinematic atmosphere with video + ambient WebGL; `quiet` = no 3D), the **asset caveat** (the agent integrates models, does NOT generate them; procedural code as an alternative), the stack (R3F + drei + three + Lenis/GSAP + postprocessing; **Rive** as a lightweight 2.5D option), performance budget and fallbacks (lazy-load the canvas, degrade on mobile, respect `reduced-motion`).
- [ ] Edit `global/agents/frontend-expert.md`: add the **"Design direction"** block — philosophy (hero as thesis, typography with personality, spend the boldness on the signature) + **preset selection logic** (1: named in the prompt; 2: `Design preset:` in rules/AGENTS.md; 3: default `quiet` with a notice) + ALWAYS load `design-system` (and `immersive-3d` if there's 3D) before coding.
- [ ] Add the per-project override: in `per-repo/.claude/rules/` create `design.md` with the `Design preset: <keyword>` line + the client's real tokens; Cursor equivalent in `.cursor/rules/design.mdc`.

### Fase 9 verification
- [ ] `frontend-expert` loads `design-system` when doing UI and respects the active preset.
- [ ] Saying "use the `vice` preset" changes the tokens; declaring it in rules locks it in for the whole repo.
- [ ] The skills have valid frontmatter and are readable by Cursor/Codex/Gemini.

---

## 11. FASE 10 — Security layer (AppSec)

Today **there is nothing focused on security**. A deep AppSec specialist agent is added, plus its skills. Base agent content already drafted in `security-expert-agent.md` (use as a starting point).

> **Relationship with `code-reviewer-pro`:** that agent already does general review with light scanning. `security-expert` is the **deep** escalation: invoked when a change touches **auth, sensitive data, cryptography, secrets, network surface, or IaC**. Document this boundary in AGENTS.md so they don't overlap.

### Tasks
- [ ] Create `global/agents/security-expert.md` (the agent). Frontmatter with `model`, an actionable `description`, and the `skills` listed (subagents **don't inherit skills**). Must define: operating modes (threat model / review / dependency audit / cloud review), a **fixed findings format** (severity + what + where + impact + concrete fix), and YOU MUST rules (never weaken security, least privilege, defense in depth, **defensive role** — no exploit generation).
- [ ] Create the 4 skills in `global/skills/`:
  - [ ] `threat-modeling/SKILL.md` — STRIDE, trust boundaries, data flow, attack surface, abuse cases. Runs at **design** time (with `solutions-expert`). Output: a threat model with ranked risks + mitigations. Notes for API, frontend, IoT/edge, and cloud.
  - [ ] `secure-coding/SKILL.md` — OWASP Top 10 mapped to the stack: input validation (Zod/Pydantic), injection (**incl. NoSQL/Mongo**), XSS/encoding, CSRF, SSRF, auth (common JWT mistakes, **argon2id/bcrypt** hashing, sessions), authz (RBAC, **IDOR**), secrets in code, crypto (don't roll your own), safe errors (don't leak stack traces to the client), security headers (CSP/HSTS), rate limiting. Notes per framework: **NestJS** (guards/pipes/`ValidationPipe`), **FastAPI** (Pydantic, dependencies), **Next.js** (`NEXT_PUBLIC_` exposure, server actions, route handlers).
  - [ ] `dependency-and-secrets-audit/SKILL.md` — SCA (`npm/pnpm audit`, `pip-audit`, `osv-scanner`), secret scanning (gitleaks/trufflehog), SBOM (syft/cyclonedx), license checks, pinning + lockfiles, Dependabot/Renovate, CI integration.
  - [ ] `cloud-iac-security/SKILL.md` — **least-privilege** IAM (no wildcards), encryption at rest (S3/RDS/EBS) and in transit (TLS), no public S3 or `0.0.0.0/0` security groups, secrets in **Secrets Manager/SSM** (not in env), VPC segmentation, CloudTrail logging, **`cdk-nag`** for automated checks, least-privilege Lambda roles. Pairs with `aws-architect`/`cdk-expert`.
- [ ] Add `security-expert` to the agent decision tree in AGENTS.md (Fase 5).
- [ ] Create `per-repo/.claude/rules/security.md` with `paths` for sensitive areas (`src/api/**`, `src/auth/**`, `infra/**`) reminding of the critical security rules.
- [ ] Leverage the `block-secrets` hook (Fase 6) as an on-disk reinforcement.

### Fase 10 verification
- [ ] `security-expert` exists with its 4 skills declared in frontmatter.
- [ ] Asking for a "security review" produces findings with **severity + a concrete fix**.
- [ ] AGENTS.md makes clear when to use `code-reviewer-pro` vs. `security-expert`.
- [ ] The 4 skills are readable by Cursor/Codex/Gemini (portable).

---

## 12. Final verification checklist

- [ ] `AGENTS.md` exists and `CLAUDE.md`/`GEMINI.md`/`copilot-instructions.md` are symlinks to it.
- [ ] AGENTS.md is under ~150 lines, leads with commands, points to files.
- [ ] `.mcp.json` exists, no plaintext secrets, with `.cursor/mcp.json` symlinked.
- [ ] The 6 migrated skills + `design-system` + `immersive-3d` + the 4 security ones have valid `name`/`description` frontmatter.
- [ ] There are path-scoped rules for Claude (`.claude/rules/`) and Cursor (`.cursor/rules/`), including `design.md` and `security.md`.
- [ ] All **12 agents** (11 + `security-expert`) are separate, with a decision tree in AGENTS.md and `skills`/`tools` declared in frontmatter.
- [ ] `frontend-expert` loads `design-system` and respects the active preset (`velocity`/`vice`/`quiet`).
- [ ] `security-expert` exists with its 4 skills; AGENTS.md defines the boundary with `code-reviewer-pro`.
- [ ] PreToolUse/PostToolUse hooks registered in `.claude/settings.json`.
- [ ] `docs/context-budget.md` exists.
- [ ] Install scripts updated and tested in a clean repo.
- [ ] `README.md` documents the portable architecture.

---

## 13. Summary: what's portable vs. tool-specific

| Element | File | Claude Code | Cursor | Copilot | Gemini CLI | Codex |
|----------|---------|:-----------:|:------:|:-------:|:----------:|:-----:|
| Instructions | `AGENTS.md` | ✅ (symlink) | ✅ native | ✅ (symlink) | ✅ (symlink) | ✅ native |
| Skills | `SKILL.md` | ✅ | ✅ pointing | 🟡 | ✅ pointing | ✅ |
| MCP | `.mcp.json` | ✅ | ✅ (`.cursor/mcp.json`) | 🟡 | 🟡 | 🟡 |
| Rules | `.claude/rules` + `.cursor/rules` | ✅ | ✅ (`.mdc`) | 🟡 | 🟡 | 🟡 |
| Hooks | `.claude/hooks` | ✅ | ❌ | ❌ | ❌ | ❌ |
| Subagents | `~/.claude/agents` | ✅ | ❌ (different concept) | ❌ | ❌ | ❌ |

**Practical rule:** what travels in the repo (AGENTS.md, .mcp.json, skills, rules) makes **any teammate with any tool** productive on clone. What's Claude-Code-specific (hooks, subagents) is documented as an "expected workflow" in AGENTS.md so it can be replicated by hand.

---

## Recommended execution order

By impact/leverage:

1. **Fase 1** (AGENTS.md + symlinks) — unblocks everything else.
2. **Fase 2** (.mcp.json) — eliminates repeated manual configuration.
3. **Fase 3** (portable skills) — auto-discovery + cross-tool.
4. **Fase 5** (decision tree for the 12 agents) — clarity without merging.
5. **Fase 10** (security layer) — today's most critical gap; agent + AppSec skills.
6. **Fase 9** (design skills) — presets + 3D for `frontend-expert`.
7. **Fase 4** (rules) — context efficiency, includes `design.md` and `security.md`.
8. **Fases 6, 7, 8** (hooks, docs, scripts) — refinement and packaging.

> Treat every config file like code: version it, review it in a PR, and verify in a clean session that the agent's behavior actually changes before merging.
