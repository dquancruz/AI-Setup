# AI-SETUP-PLAN-v2 — Extensible Multi-Tool Architecture

> **Status:** IN PROGRESS — Fases 1-4 of section 8 are already implemented and committed (see per-phase status there). Fases 5-6 pending. The plan is considered approved by the continued execution of its phases in order; this document is no longer purely speculative design.
> **For:** human review → then, if approved, execution by Claude Code in phases (section 8).
> **Replaces in intent (not in file) the:** attempted restructuring into `shared/` + `tools/claude/` + `tools/cursor/` with codegen documented in `docs/RESTRUCTURE-2026-06.md` and evaluated in `docs/PLAN-VS-REALIDAD-2026-07.md`. This plan picks the underlying idea back up (SSOT + adapters) but corrects the concrete reasons it was rejected (see section 7).

---

## 0. Problem summary and guiding principle

Today the setup is **Claude-only functional**: 12 agents + 12 skills + hooks + scripts live in `global/` (→ `~/.claude/`) and `per-repo/` (→ each project). Cursor gets a fraction — `AGENTS.md`, `.mcp.json`, `.cursor/rules/*.mdc` maintained **by hand in parallel** to `.claude/rules/*.md` — and they've already shown real drift (`docs/RESTRUCTURE-2026-06.md`, e.g. `backend.md` vs `backend.mdc`).

The request now is explicit: it's not just about "adding Cursor," but about getting the setup ready so that **adding the next tool (Windsurf, Copilot, Codex CLI, Gemini CLI, whatever)** is a low-cost task, without duplicating content and without redoing the architecture every time.

**Guiding principle: separate KNOWLEDGE from PRESENTATION.**

- The **knowledge** (what each agent does, what each skill knows, what rules govern `src/api/`, what the secret-blocking hook does) is written **once**, in a tool-agnostic format, in a central `registry/`.
- The **presentation** (is the file called `.claude/rules/backend.md` or `.cursor/rules/backend.mdc`? is the agent a real subagent or a condensed paragraph inside `AGENTS.md`?) is the responsibility of a small, isolated **per-tool adapter** that declares its capabilities and renders the knowledge into the format that tool understands — **at the moment a repo is enabled, not before, and never committed as a generated tree in this repo.**

This is the same lesson `docs/RESTRUCTURE-2026-06.md` already taught (generate `.mdc` on the fly, don't version it) — this plan generalizes it to **every** artifact (agents, skills, rules, hooks, MCP) and to **any** future tool, not just Cursor's rules.

---

## 1. Proposed directory structure

```
AI-Setup/
│
├── registry/                        # SSOT — knowledge, tool-agnostic, edited ONCE
│   ├── agents/                      # 12 canonical agents (see section 2)
│   │   ├── backend-expert.md
│   │   ├── security-expert.md
│   │   └── ...
│   ├── skills/                      # 12 skills — ALREADY portable today, stay the same
│   │   ├── auto-commit/SKILL.md
│   │   └── ...
│   ├── rules/                       # Canonical rules, one file per domain
│   │   ├── backend.md               # frontmatter: paths: [...]
│   │   ├── frontend.md
│   │   ├── testing.md
│   │   ├── design.md
│   │   └── security.md
│   ├── hooks/                       # Hook logic, tool-agnostic (see section 4)
│   │   ├── pre-write/block-secrets.sh
│   │   └── post-write/lint-after-write.sh
│   ├── templates/                   # AGENTS.md template, .mcp.json template, .env.example
│   └── scripts/                     # auto-commit.js, auto-pr.js, auto-jira.js, dashboard.js
│                                     # (already tool-agnostic today — content unchanged, just moved folder)
│
├── tools/                           # One adapter per supported AI tool
│   ├── claude/
│   │   ├── capabilities.yaml        # what it natively supports (see section 5)
│   │   └── enable.sh                # how to install/render for this tool
│   ├── cursor/
│   │   ├── capabilities.yaml
│   │   ├── enable.sh
│   │   └── adapt/
│   │       ├── rule-to-mdc.sh       # generalizes the already-validated generate_cursor_rule()
│   │       └── agent-to-mode.sh     # canonical agent → Cursor Custom Mode
│   ├── copilot/
│   │   ├── capabilities.yaml
│   │   └── enable.sh                # uses lib/condense.mjs (section 6)
│   └── _template/                   # scaffold for adding a new tool
│       ├── capabilities.yaml.example
│       └── enable.sh.example
│
├── lib/                              # Shared render engine — avoids reimplementing per tool
│   ├── frontmatter.sh                # minimal YAML frontmatter parsing (no heavy deps)
│   ├── condense.mjs                  # collapses N agents/skills into a low-budget summary
│   └── render.mjs                    # applies capabilities.yaml + registry/* → per-tool output
│
├── bin/
│   ├── install-global.sh             # replaces install.sh — loops over tools/*/enable.sh --scope=global
│   └── enable-repo.sh                # replaces setup-repo.sh — the "enable a repo" step (section 5)
│
├── docs/
│   ├── tool-compatibility.md         # table derived 1:1 from tools/*/capabilities.yaml
│   ├── context-budget.md             # already exists — extended with a tiers table (section 6)
│   ├── AI-SETUP-PLAN-v2.md           # this document
│   └── RESTRUCTURE-2026-06.md        # kept as a historical record
│
└── plan.md                           # kept as a historical record (already has a "superseded" note)
```

**What does NOT exist in this tree and why:** there is no `tools/cursor/global/agents/` or any other **generated and committed** subtree inside `AI-Setup`. Anything an adapter produces (a `.mdc`, a Cursor Custom Mode, a condensed `AGENTS.md` for Copilot) is written **directly into the target repo** (or into `~/.cursor/`, `~/.claude/`, etc. for global scope) when `enable-repo.sh` / `install-global.sh` runs. There is never a generated artifact living in this repo waiting to go stale. This is exactly the lesson from `docs/RESTRUCTURE-2026-06.md`, generalized.

---

## 2. Agent parity across tools with different capabilities

The same 12 agents exist for every tool — what changes is **how they're materialized**, based on what each tool can actually run. An extended canonical frontmatter is defined, along with three **rendering tiers**:

### 2.1 Canonical format (`registry/agents/<name>.md`)

```markdown
---
name: backend-expert
description: Backend implementation specialist for NestJS, FastAPI, MongoDB...
model: sonnet                 # only relevant for tools with model routing (Claude)
tools: Read, Write, Edit, Bash, Glob, Grep   # only relevant for tools with per-tool permissions
skills: [iot-backend, auto-commit]
tier: core                    # core | extended → priority order when condensing (section 6)
---

## Essence                    # NEW — 3-5 bullets, for tiers that can't load the full body
- Implements NestJS/FastAPI/MongoDB APIs with a TDD-first approach.
- Auto-commits only after validating tests + lint.
- Coordinates shared contracts with frontend-expert.
- Never pushes directly to main.

# Backend Expert
<full body, identical to the current global/agents/backend-expert.md>
```

The only **new** content that needs to be written per agent is the `## Essence` block (3-5 bullets) — the rest is the same body that already exists today in `global/agents/*.md`. This section is the piece that makes condensation possible without duplicating prose: it's written once alongside the agent and reused by any tier-C tool, present or future.

### 2.2 The three rendering tiers

| Tier | What the tool supports | How the agent gets materialized | Example today |
|------|---------------------|-------------------------------|-------------|
| **A — Native subagent** | Isolated context per agent, automatic/parallel invocation | Copied verbatim into the tool's agents folder | Claude Code (`~/.claude/agents/`) |
| **B — Native mode/persona, no context isolation** | The user can define "modes" or "personas" with their own instructions, but with no automatic orchestration or isolated context | `agent-to-mode.sh` renders the full body into **one file per agent** in that tool's native format (e.g. a Cursor Custom Mode) — same content, manual invocation | Cursor (Custom Modes) |
| **C — A single instructions file, no agent concept** | Everything lives in one always-loaded document | `condense.mjs` collapses the 12 agents into a **condensed roster** (name + first sentence of `description` + `## Essence`) inside `AGENTS.md`/`copilot-instructions.md` | GitHub Copilot |

Explicit rule: **the roster (the 12 names + their specialty) is identical across all three tiers.** What's lost going down a tier isn't "which agents exist" but the **invocation mechanics** (automatic and parallel in A, manual in B, "act as X" instructed by the user in C). That loss is documented explicitly in `AGENTS.md` (the "How each agent is invoked depending on your tool" section) — parity is never faked where it doesn't exist, the same standard the rejected Cursor plan already used ("no fake parity"), which was correct on that point.

### 2.3 Why this partially reconsiders `tool-compatibility.md`'s decision

The prior decision said "the 12 subagents are intentionally exclusive to Claude Code." That stays correct for **orchestration** (isolated context + parallelism + automatic selection by `description`) — that remains an internal Claude Code mechanism with no real equivalent. But each agent's **content** (its expertise, its rules, its role) can — and should — travel to any tool via tiers B/C. This wasn't done before because the only alternative considered was "port real subagents to `~/.cursor/agents/`," which, since Cursor doesn't have that exact concept, is a forced analogy. Custom Modes IS a reasonable analogy (persona + its own instructions, manual invocation) — hence reconsidering it for tier B, without touching the conclusion about orchestration.

---

## 3. Avoiding duplication — the concrete mechanism

**One single source of truth per knowledge type**, plus a **generic render engine** instead of one transform function per (artifact × tool) combination:

| Knowledge type | SSOT | Duplicated today because... | How it stops being duplicated |
|---|---|---|---|
| Agents | `registry/agents/*.md` | Condensation didn't exist → the choice was framed as "port" or "don't port," nothing in between | `lib/render.mjs` applies the tier declared in the target tool's `capabilities.yaml` |
| Skills | `registry/skills/*/SKILL.md` | Not duplicated today already (correct) | Stays the same — only the folder changes (`global/skills` → `registry/skills`) |
| Rules | `registry/rules/*.md` | `.claude/rules/*.md` and `.cursor/rules/*.mdc` were maintained by hand in parallel | `tools/cursor/adapt/rule-to-mdc.sh` generates the `.mdc` in the target repo on every `enable-repo.sh` run, never hand-edited or committed here |
| Hooks (logic) | `registry/hooks/*.sh` | N/A today (Claude-only) — but as tools with hooks get added, the risk is rewriting the logic per tool | The scripts read both known stdin schemas (`tool`/`tool_name`, `file_path`/`path`) — the SAME logic serves any tool that fires hooks; only the *registration* file changes (`.claude/settings.json` vs. the new tool's equivalent) |
| MCP | `registry/templates/.mcp.json` | Already centralized today (correct) | Stays the same — each tool symlinks or copies to its expected path |
| Project instructions | `registry/templates/AGENTS.md` | Already centralized today via symlinks (correct) | Stays the same, generalizing the symlink loop to any tool declared in `tools/*/capabilities.yaml` |

**Why does the render engine (`lib/render.mjs` + `lib/condense.mjs`) get justified this time, if codegen was rejected last time?**

Concrete difference from what was rejected in `docs/RESTRUCTURE-2026-06.md`:

1. **It doesn't generate and commit a tree in this repo.** It generates directly in the target repo/machine, on every run of `enable-repo.sh`/`install-global.sh` — nothing can go "stale" because there's no persistent copy being compared against the SSOT; it's always regenerated from scratch (idempotent, overwrites cleanly, same as `generate_cursor_rule()` already does today).
2. **It doesn't add heavy dependencies.** `lib/frontmatter.sh` follows the same standard already used to reject `gray-matter`: frontmatter parsing with `grep`/`sed`/`awk`, or, if using Node, with no external dependencies (simple regex, already the style of `per-repo/scripts/*.js`).
3. **It doesn't add "drift-check" CI.** Not needed: if nothing generated gets committed, drift is impossible by definition — the problem class is eliminated instead of watched for.
4. **It's a single generic engine, not N ad-hoc transformers.** Last time, `agent-to-cursor.js`, `rule-to-mdc.js`, `hooks-to-cursor.js` were proposed as separate scripts that would keep growing per tool×artifact combination. Here `render.mjs` takes `capabilities.yaml` as data — adding a new tool means **declaring capabilities**, not writing a new transformer from scratch (except for genuinely different formats, like `.mdc`, which do stay as small, explicit adapters in `tools/<tool>/adapt/`).

---

## 4. Hooks — shared logic, per-tool registration

Today only Claude Code supports hooks (`PreToolUse`/`PostToolUse`). That may keep being true for the current Copilot/Codex, but no future tool should be assumed to lack hooks — the design must be ready without over-building today.

- `registry/hooks/pre-write/block-secrets.sh` and `registry/hooks/post-write/lint-after-write.sh` contain the pure logic, **agnostic of which tool invokes them**: they read the file path and content from environment variables or JSON stdin, accepting both field-name schemas known as of today (`tool_name`/`tool`, `file_path`/`path`), exactly as the rejected plan had correctly proposed on this specific point.
- The **registration** (which event fires which script, with what matcher) is the only tool-specific part: `tools/claude/enable.sh` writes `.claude/settings.json` pointing at `registry/hooks/...` (copied or symlinked into the target repo). A future tool with hooks contributes its own `tools/<tool>/adapt/hooks-registration.*` without touching the logic in `registry/hooks/`.
- Tools with no hook support (Cursor, Copilot today): `capabilities.yaml` declares `hooks: none` and `enable.sh` simply writes nothing — documented in `docs/tool-compatibility.md` as a real limitation, never simulated.

---

## 5. The per-tool "enable a repo" mechanism

### 5.1 `capabilities.yaml` — the contract that makes all of this extensible

Each tool declares, in a ~15-line file, what it supports:

```yaml
# tools/cursor/capabilities.yaml
name: cursor
instructions:
  mechanism: native            # native | symlink | inline
  filename: AGENTS.md          # Cursor reads AGENTS.md natively, no symlink needed
  global_scope: unsupported    # Cursor has no global AGENTS.md/CLAUDE.md — per-repo only
agents:
  mechanism: custom-mode        # native | custom-mode | condensed | none
  path: ".cursor/modes.json"    # repo-local; see 5.3 — no global equivalent exists
  global_scope: unsupported
skills:
  mechanism: reference          # native-autodiscovery | reference | condensed | none
  path: ".cursor/skills/"
  global_scope: unsupported     # confirmed: Cursor has no personal/global skills directory
rules:
  mechanism: native-mdc         # native | native-mdc | condensed | none
  path: ".cursor/rules/"
  global_scope: manual-only     # "User Rules" exists under Settings → Rules → User, but it
                                 # lives in the app's internal storage, not a plain file a
                                 # script can safely write to in a supported way — not automated
hooks:
  mechanism: none                # native | none
  global_scope: unsupported
mcp:
  mechanism: native
  path: ".cursor/mcp.json"
  global_scope: supported        # ~/.cursor/mcp.json (%USERPROFILE%\.cursor\mcp.json on Windows)
                                  # is a real file — project-level wins on server conflict
context_tier: B                  # A | B | C — used by lib/condense.mjs
max_instructions_lines: 300
```

New per-artifact `global_scope` field (`supported | unsupported | manual-only`): it exists because, unlike Claude Code, **not every Cursor artifact has a machine-level equivalent** — see the full table in 5.3.

### 5.2 `bin/enable-repo.sh` — single entrypoint

```bash
enable-repo.sh --tools claude,cursor,copilot   # default: all
```

For each requested tool:

1. Reads `tools/<tool>/capabilities.yaml`.
2. Installs the **tool-agnostic** parts once per repo, regardless of how many tools get enabled (automation scripts, Husky, GitHub Actions, `.env.local`, base `.mcp.json`) — this is no longer repeated per tool.
3. For what does vary per tool, invokes `lib/render.mjs` with the matching `capabilities.yaml`:
   - `instructions.mechanism` → symlink (`CLAUDE.md`, `GEMINI.md`, `.github/copilot-instructions.md`) or native (Cursor doesn't need a symlink, it already reads `AGENTS.md`).
   - `agents.mechanism` → verbatim copy (native), runs `tools/<tool>/adapt/agent-to-mode.sh` (custom-mode), or condenses into instructions (condensed).
   - `rules.mechanism` → verbatim copy, runs `rule-to-mdc.sh`, or condenses.
   - `skills.mechanism` → copies the full folder, leaves just a reference (name + path), or condenses a summary.
   - `hooks.mechanism` → registers if `native`, skips if `none`.
   - `mcp.mechanism` → symlink/copy to `path`.
4. Prints an explicit summary: what was enabled, what was skipped and why (read straight from `capabilities.yaml`), so the parity gap is visible, not silent.

### 5.3 `bin/install-global.sh` — what "global" means, tool by tool

**This section was under-specified in the plan's previous version** (it assumed "agents and skills go to `~/.claude/`, `~/.cursor/`, etc." as if the mechanism were symmetric across tools). It isn't. Each tool's real behavior was investigated before assuming anything — the same standard `docs/RESTRUCTURE-2026-06.md` already forced ("don't assume artifacts are missing without checking the filesystem first"), now applied to "don't assume a global scope exists without checking the tool first":

| Artifact | Claude Code | Cursor |
|---|---|---|
| **Agents** | `~/.claude/agents/*.md` — a real global directory, already used today by `install.sh`. `tools/claude/enable.sh --scope=global` still does `cp registry/agents/*.md ~/.claude/agents/`, no behavior change. | **No global scope exists.** Cursor's Custom Modes live in `.cursor/modes.json`, a file **per project** — there is no `~/.cursor/modes.json` that applies to every repo. `install-global.sh` **does not install agents for Cursor**; the 12 agents only reach a Cursor repo when `enable-repo.sh` runs on THAT repo. |
| **Skills** | `~/.claude/skills/<name>/SKILL.md` — same, a real global directory, no behavior change. | **Cursor has no personal/global skills directory** (unlike Claude Code) — all Cursor skills are project-scoped, in `.cursor/skills/`. Same situation as agents: `install-global.sh` does nothing for Cursor here; only `enable-repo.sh` per repo. |
| **Rules** | No global scope applies today (rules are already per-repo via path-matching); stays the same. | Cursor does have "User Rules" (Settings → Rules → User) that apply machine-wide — but they live in the app's internal storage (not a plain file documented as stable to write to via script). Marked `global_scope: manual-only`: the plan does **not** try to automate this: instead, `install-global.sh` prints instructions for the user to paste manually into Settings, generated from `registry/rules/*.md`. |
| **MCP** | No change — already centralized today. | `~/.cursor/mcp.json` (`%USERPROFILE%\.cursor\mcp.json` on Windows) is a real, documented file — **supported**. `install-global.sh` can safely write/merge it. If the same server is also defined in the repo's `.cursor/mcp.json`, Cursor prioritizes the project-level one (documented by Cursor, not assumed). |
| **Hooks** | Global doesn't apply (hooks are per-repo today). | Cursor has no hooks — `global_scope: unsupported`, same as at the repo level. |

**Consequence for `install-global.sh`'s design:** it isn't "the same engine applied to a different path" like the previous version said — it's the same engine, but one that **reads `global_scope` from each `capabilities.yaml` and explicitly skips** whatever has no machine-level equivalent, instead of trying to force a path that doesn't exist. For Cursor, the real result of running `install-global.sh --tools cursor` today is: it installs global MCP, prints instructions to manually paste rules into Settings, and explicitly says "Cursor agents and skills have no global scope — they get installed when each repo is enabled with `enable-repo.sh`" — the same as point 4 of `enable-repo.sh` (section 5.2) already does by printing what was skipped and why, just at the global level.

**For a future tool:** the same `global_scope` field in its `capabilities.yaml` is the only thing that needs declaring (`supported`, `unsupported`, or `manual-only` with instructions) — there's no need to touch `install-global.sh`, which already loops over `tools/*/capabilities.yaml` generically (section 5.4).

*Sources used to verify Cursor's real behavior (not assumed): [Cursor Docs — Rules](https://cursor.com/docs/rules), [Cursor Docs — CLI Configuration](https://cursor.com/docs/cli/reference/configuration), [Cursor Docs — Customizing Agents](https://cursor.com/learn/customizing-agents), [Where Cursor Stores Skills](https://www.agensi.io/learn/where-are-cursor-skills-stored), [Cursor Forum — Workspace/profile-scoped config request](https://forum.cursor.com/t/workspace-or-profile-scoped-cursor-config-rules-skills-subagents-mcp/153068).*

### 5.4 Adding a new tool (e.g. Windsurf) — expected cost

1. Copy `tools/_template/` to `tools/windsurf/`.
2. Fill in `capabilities.yaml` (~15 lines, researching what Windsurf currently supports: native instructions? does it have Cascades as an agent concept? its own rules? MCP? hooks?).
3. If a mechanism requires a genuinely different file format (not covered by the generic mechanisms already supported: `native`, `symlink`, `custom-mode`, `condensed`, `native-mdc`, `none`), add the specific adapter in `tools/windsurf/adapt/`. If it fits an existing mechanism, **no new code is written**, only declared.
4. `enable-repo.sh` and `install-global.sh` already recognize it automatically (they loop over `tools/*/` at runtime) — no editing required.

`registry/` isn't reorganized, no other tools are touched, there's no content migration. This is the low cost requirement 1 asks for.

---

## 6. Context/token budget per tool

`docs/context-budget.md` (already existing) is extended with a **render tiers** table, which is what actually controls how much "always loaded" content each tool gets:

| Tier | Tools (today) | What's always loaded | What loads on demand | Ambient budget |
|------|-------------|----------------------|----------------------------|----------------------|
| **A** | Claude Code | `AGENTS.md` (~100 tokens) + path-matched rules (~200) | The full agent only if invoked; the full skill only if auto-discovered | ~300 tokens ambient — the rest is real progressive disclosure |
| **B** | Cursor | Native `AGENTS.md` + glob-matched rules (`.mdc`) | The full Custom Mode only if the user activates it; the full skill only if explicitly referenced | ~300-400 tokens ambient — similar to A, loses skill auto-discovery but not rule path-scoping |
| **C** | Copilot (today) | The whole `copilot-instructions.md` — no conditional loading | Nothing — anything not inline doesn't exist for the tool | `max_instructions_lines` in `capabilities.yaml` (e.g. 300) forces `condense.mjs` to trim: agent roster → name + 1 sentence; skills → name + 1 sentence; rules → a summary of conventions per area instead of separate files |

`condense.mjs` rule for tier C (deterministic, doesn't depend on an LLM summarizing — avoids variability):

1. Sort by `tier: core` before `extended` (frontmatter already defined on agents/skills).
2. For each item: `name` + first sentence of `description` + (if an agent) the `## Essence` bullets.
3. If the total exceeds `max_instructions_lines`, trim the `extended` ones first, leaving a summary item ("also available: X, Y — see `registry/agents/`").
4. Never omit the critical rules (`YOU MUST`) — those have fixed priority over roster/skills when trimming.

This directly answers requirement 5: no tool receives the full content of all 12 skills + 12 agents if it can't take advantage of it via conditional loading — the only one that does receive it in full is the one that actually loads it on demand (A and, mostly, B).

---

## 7. What's explicitly dropped (and why)

Learning from `docs/RESTRUCTURE-2026-06.md`:

| Dropped | Why |
|---|---|
| Committing a per-tool generated tree inside this repo (`tools/cursor/global/agents/`, `tools/cursor/per-repo/rules/*.mdc`, etc.) | This is the root cause of the drift risk found last time. It's generated only at the destination, on every `enable-repo.sh` run. |
| "Drift-check" CI (`generate:cursor:check`) | Unnecessary if there's no committed artifact to compare against — the bug class is eliminated instead of monitored. |
| A root `package.json` + dependencies like `gray-matter` just to parse frontmatter | Over-engineering for files under 100 lines; `grep`/`sed`/`awk` or simple dependency-free regex in Node is enough, as already proven with `generate_cursor_rule()`. |
| Porting the 12 subagents as-is to `~/.cursor/agents/`, assuming 1:1 equivalence with Claude Code | Cursor has no automatic orchestration or per-agent isolated context — forcing that analogy fakes a parity that doesn't exist. Custom Modes (tier B) are used instead, with the difference documented. |
| Creating empty `tools/<tool>/` folders "for symmetry" before there's real content | The same argument already used to avoid creating an empty `tools/cursor/` last time — now applied as a general rule for any future tool: it's created once there's a real `capabilities.yaml` + `enable.sh`. |
| Assuming artifacts are missing without checking the filesystem first | The original Cursor plan wrongly claimed `block-secrets.sh` and `dependency-and-secrets-audit/SKILL.md` were missing when they already existed — any phase of this plan touching those files must first confirm their real on-disk state before "fixing" them. |
| Assuming `install-global.sh` is symmetric across tools ("agents and skills go to `~/.claude/`, `~/.cursor/`, etc.") without checking each tool | Cursor has no global agents directory (Custom Modes live in `.cursor/modes.json` per repo) nor a global skills directory (always project-scoped) — confirmed against Cursor's official docs, not assumed. The `global_scope` field (`supported`/`unsupported`/`manual-only`) in `capabilities.yaml` replaces the assumption with a verified declaration (section 5.3). |
| Rewriting the original `plan.md` | It's kept as a historical record with its "superseded" note, as already decided. |

---

## 8. Phased migration plan (without breaking what works)

Each phase leaves the repo in a functional, verifiable state — the current Claude-only pipeline **never degrades at any intermediate point**.

### Fase 1 — Reorganize into `registry/` (move, don't rewrite)
**Status: ✅ Done** (commit `25476d0`, plus `tier: core|extended` added later in commit `f049a32` for Fase 4 — the tier frontmatter was specified here but implemented alongside `condense.mjs`, its first real consumer).
- Move `global/agents/` → `registry/agents/` (add `## Essence` to each one — the only genuinely new content).
- Move `global/skills/` → `registry/skills/` (no content changes).
- Move the tool-agnostic parts of `per-repo/` (`scripts/`, `.husky/`, `.github/workflows/`, `AGENTS.md`, `.mcp.json`, `setup-portability.sh`) → `registry/templates/` and `registry/scripts/`.
- Move `per-repo/.claude/rules/*.md` → `registry/rules/` (a single copy now, not two).
- Move `per-repo/.claude/hooks/*` → `registry/hooks/` (same content, normalize reading both stdin schemas).
- Update `install.sh`/`setup-repo.sh` to the new paths — identical behavior to today, zero functional change.
- **Verification:** run the updated `setup-repo.sh` on a test repo and confirm the result is identical to today's.

### Fase 2 — Explicit Claude adapter
**Status: ✅ Done** (commit `1f271f9`).
- Create `tools/claude/capabilities.yaml` (documents what Claude Code already does today — doesn't change behavior).
- Create `tools/claude/enable.sh` as a thin wrapper around the logic that currently lives in `install.sh`/`setup-repo.sh`.
- **Verification:** `tools/claude/enable.sh` produces exactly the same tree as `setup-repo.sh` does today.

### Fase 3 — Cursor adapter with real tiers
**Status: ✅ Done** (commit `1f271f9`). End-to-end verified on a test repo: `.cursor/rules/*.mdc` byte-for-byte identical to the source `.md` (frontmatter + body), no `globs` overlap between domains (`src/api/**` doesn't match `frontend`).
- Create `tools/cursor/capabilities.yaml` (agents: custom-mode, rules: native-mdc, skills: reference, hooks: none, mcp: native).
- Create `tools/cursor/adapt/rule-to-mdc.sh` (generalizes the already-validated bash function from the previous attempt — no new dependencies).
- Create `tools/cursor/adapt/agent-to-mode.sh` (full canonical agent body → a Cursor Custom Mode, one file per agent).
- **Verification:** enable a test repo with only `--tools cursor` and confirm `.cursor/rules/*.mdc` matches the source `.md` byte-for-byte (the same verification standard already used in `docs/RESTRUCTURE-2026-06.md`), and that all 12 Custom Modes exist with full content.

### Fase 4 — Condensation engine + first tier-C tool (Copilot)
**Status: ✅ Done** (commits `f049a32` tier frontmatter, `aef123b` engine + adapter). End-to-end verified on a test repo: real output of 119 lines for this repo's `registry/` (under the 200 budget, no trimming needed), all 12 agent names and 11 skill names present, the 4 critical rules from `registry/templates/AGENTS.md` copied byte-for-byte, and correct trim-cascade degradation tested with an artificial 40-line budget (collapses to a summary but never omits a name).
- Implement `lib/condense.mjs` with the deterministic algorithm from section 6.
- Create `tools/copilot/capabilities.yaml` (agents: condensed, skills: condensed, rules: condensed, hooks: none, mcp: partial).
- **Verification:** the generated `copilot-instructions.md` respects `max_instructions_lines`, includes the condensed 12-agent roster, and doesn't omit any `YOU MUST` rule.

### Fase 5 — Generalize `enable-repo.sh` / `install-global.sh`
**Status: ⬜ Pending.**
- Replace any tool-hardcoded logic with a generic loop over `tools/*/capabilities.yaml`.
- Add `tools/_template/` with inline instructions for adding a new tool.
- **Extensibility test:** add one more tool (real or simulated, e.g. Gemini CLI) using only the template, without touching `registry/`, `lib/`, or other adapters, to validate the low cost promised in requirement 1.

### Fase 6 — Documentation and closure
**Status: ⬜ Pending.**
- Regenerate `docs/tool-compatibility.md` so it's 1:1 with `tools/*/capabilities.yaml` (prevents it from drifting from reality again, like happened with `.mdc` vs `.md`).
- Extend `docs/context-budget.md` with the tiers table (section 6).
- Update `README.md`/`USAGE.md` with the new structure and the single `enable-repo.sh` command.
- Mark the original `plan.md` and `docs/RESTRUCTURE-2026-06.md` as historical context, linked from this document (already done).

---

## 9. Final verification checklist

- [x] `registry/` is the single source of knowledge — zero duplicated content between agents/skills/rules/hooks. (One specific duplication was found and fixed in `registry/templates/AGENTS.md` vs. `registry/rules/{frontend,backend}.md` — commit `6b5b847`.)
- [x] No tool-generated artifact is committed in this repo — everything is generated at the destination via `enable-repo.sh`/`install-global.sh`. (Verified: no `.mdc` or `copilot-instructions.md` tracked in git; only `capabilities.yaml`/`enable.sh`/adapters, which are code, not generated output.)
- [x] All 12 agents have `## Essence` and exist in all three forms (verbatim, custom-mode, condensed) depending on the enabled tool. (Verbatim: `tools/claude/enable.sh`. Custom-mode: `tools/cursor/adapt/agent-to-mode.sh`. Condensed: `lib/condense.mjs` via `tools/copilot/enable.sh`.)
- [ ] `docs/tool-compatibility.md` is derived from `tools/*/capabilities.yaml`, not hand-maintained. (Fase 6.)
- [ ] Adding a new tool requires no changes to `registry/`, `lib/`, or other adapters — only `tools/<new>/`. (Fase 5 — `enable-repo.sh` doesn't yet generalize the loop over `tools/*/capabilities.yaml`; today each adapter is invoked separately.)
- [x] The current Claude-only pipeline keeps working the same way at every phase (no regression). (Verified in Fase 3: `.claude/rules/*.md` generated by `setup-repo.sh` identical to before the migration to `registry/`.)
- [ ] `docs/context-budget.md` documents the 3 tiers and the deterministic trimming criteria. (Fase 6.)
- [x] `plan.md` and `docs/RESTRUCTURE-2026-06.md` remain as a historical record, not deleted.
