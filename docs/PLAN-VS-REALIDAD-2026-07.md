# Comparison report: Cursor plan vs. real repo state

_Generated: 2026-07-01_

> **📜 Historical snapshot.** This report analyzes the repo's state on the date above (`tools/claude/global/` + `shared/skills/`). That state was replaced that same day by `registry/` (commit `25476d0`, Fase 1 of [`docs/AI-SETUP-PLAN-v2.md`](AI-SETUP-PLAN-v2.md)) — the paths mentioned here no longer exist. Kept as evidence of the evaluation that led to rejecting committed codegen, not as a reference for the current structure.

## 1. Scope of the Cursor plan

The file `claude-cursor_monorepo_split_1b1edd71.plan.md` proposed a restructuring with **explicit codegen** to achieve Claude/Cursor parity:

- **New hierarchy**: `shared/` (tool-agnostic artifacts) + `tools/claude/` (Claude's canonical SSOT) + `tools/cursor/` (**generated and committed**) + `scripts/transformers/`.
- **Stated motivation**: rules already diverged between `.md` (Claude) and `.mdc` (Cursor) due to duplicated manual editing; artifacts were missing (`block-secrets.sh`, `dependency-and-secrets-audit/SKILL.md`); there was no parity for Cursor subagents/skills/hooks.
- **Key steps (Fases A-D)**:
  1. Move `global/` and `per-repo/` to `shared/`/`tools/claude/`.
  2. Build Node transformers (`agent-to-cursor.js`, `rule-to-mdc.js`, `hooks-to-cursor.js`, `index.js` with a `--check` mode).
  3. Generate and **commit** `tools/cursor/` (Cursor agents, `.mdc`, `hooks.json`).
  4. New install scripts (`install-cursor.sh`, `setup-portability.ps1` for Windows) and a root `package.json` with `generate:cursor` / `generate:cursor:check`.
  5. Port the 12 subagents to `~/.cursor/agents/` and add CI that fails if `tools/cursor/` goes "stale".

## 2. Real state — what was done, what wasn't, and what was done differently

**Executed (confirmed with `git status`):**
- Folder migration: `global/agents/*` → `tools/claude/global/agents/*` (12 files), `global/skills/*` → `shared/skills/*` (12 skills + README), `per-repo/.claude/rules/*` → `tools/claude/per-repo/rules/*`, `per-repo/.claude/hooks/*` → `tools/claude/per-repo/hooks/*`, `per-repo/.claude/settings.json` → `tools/claude/per-repo/settings.json`, `per-repo/scripts/*.js` → `shared/scripts/*.js`, `per-repo/.husky/*` → `shared/husky/*`, `per-repo/.github/workflows/*` → `shared/github/workflows/*`, `per-repo/AGENTS.md` → `shared/templates/AGENTS.md`, `per-repo/.mcp.json` → `shared/templates/.mcp.json`, `per-repo/setup-portability.sh` → `shared/templates/setup-portability.sh`.
- `install.sh` and `setup-repo.sh` updated to the new paths (verified by reading both files in full — no broken references to `global/` or `per-repo/` remain).
- Docs updated: `README.md`, `USAGE.md`, `docs/GITHUB-ACTIONS-SETUP.md`, `docs/tool-compatibility.md`, `shared/skills/README.md`, and a "Status: mostly executed" note added at the top of the original `plan.md`.
- Verified directly on disk that `tools/claude/per-repo/hooks/pre-tool-use/block-secrets.sh` and `shared/skills/dependency-and-secrets-audit/SKILL.md` **already existed** before the migration — the Cursor plan's premise that they were missing was **factually incorrect** (confirmed both by a filesystem `find` and by `docs/RESTRUCTURE-2026-06.md`).

**Done DIFFERENTLY than planned (a conscious decision, not an accidental omission):**
- `docs/RESTRUCTURE-2026-06.md` (a new untracked file) explicitly documents that the Cursor plan was **evaluated and rejected in its codegen parts**. The recorded justification: "it contradicted a decision already documented in `docs/tool-compatibility.md`: subagents and hooks stay intentionally exclusive to Claude Code" — and the plan had factual errors about "missing" files.
- **`tools/cursor/` does not exist** (verified: no such folder on disk). Instead of committing a generated tree, `setup-repo.sh` incorporated a `generate_cursor_rule()` bash function (lines 61-75) that generates `.cursor/rules/*.mdc` **on the fly, in the target repo**, every time the script runs (step 2f, lines 169-178) — the `.mdc` is never versioned in this repo.
- **There is no** `scripts/transformers/`, root `package.json`, `install-cursor.sh`, or `setup-portability.ps1`. There's no Node/`gray-matter` dependency for parsing frontmatter; the `paths:`→`globs:` replacement is done with plain `grep`/`sed`/`awk` in `setup-repo.sh`.
- The 12 subagents are **not** ported to `~/.cursor/agents/` or `.cursor/agents/` — they stay exclusive to Claude Code (parity table in `README.md` line 65: "Agents | ✅ | ❌ | ❌ | ❌ | ❌").
- The hooks (`block-secrets.sh`, `lint-after-write.sh`) are **not** registered for Cursor (`.cursor/hooks.json` was never created); they remain Claude-only, consistent with `docs/tool-compatibility.md`.

**What's missing relative to the original plan** (by decision, not pending work): Node transformers, drift-check CI (`generate:cursor:check`), subagent/hook parity in Cursor. None of these appear as "pending" in the repo — `docs/RESTRUCTURE-2026-06.md` lists them in a "What was dropped from the original Cursor plan" table with an explicit reason for each item.

## 3. Risks and loose ends

- **`per-repo/.cursor/rules/*.mdc` deleted with no versioned replacement** (the 5 `D` entries in `git status`: backend, design, frontend, security, testing) — this is **intentional**, not an accidental loss: the replacement is runtime generation via `generate_cursor_rule()` in `setup-repo.sh`. Residual risk: if someone clones the repo expecting to see versioned `.mdc` files (like before), they may be surprised; this is documented in `README.md` line 40 and in `docs/RESTRUCTURE-2026-06.md`, but there's no mention of it in `USAGE.md`.
- **No broken references found**: an exhaustive grep for `global/agents`, `global/skills`, `per-repo/.claude`, `per-repo/.cursor`, `per-repo/scripts`, `per-repo/.husky`, `per-repo/.github` across the whole tree (excluding the two plan files, which are intentional history) only turns up legitimate matches like `tools/claude/global/agents/` (a regex false positive, not a broken path). `install.sh` (lines 56-57) and `setup-repo.sh` (multiple sections) correctly point to `shared/` and `tools/claude/`.
- **`claude-cursor_monorepo_split_1b1edd71.plan.md` sits loose at the repo root, untracked** — it's not in `.gitignore` nor referenced from any doc except this analysis. If it isn't going to be committed as a historical record, it's worth explicitly deciding whether to drop it or move it into `docs/` (alongside `docs/RESTRUCTURE-2026-06.md`, which does reference it by name in its first line).
- **The original `plan.md` keeps ~15 references to old paths** (`global/skills/`, `per-repo/.claude/rules/`, etc., lines 213-416) as part of its historical content — this is intentional per the note added at the top ("kept as a historical record, not rewritten"), but it's worth making explicit for anyone reading it without context.
- **Counts verified correct**: 12 agents (`tools/claude/global/agents/*.md`) and 12 skills (`shared/skills/*/`) match what `README.md` and `USAGE.md` say.

## 4. Recommended next steps

1. Decide the fate of `claude-cursor_monorepo_split_1b1edd71.plan.md`: if it's kept as historical evidence of the architecture decision, move it into `docs/` (e.g. `docs/claude-cursor-plan-original.md`) and link it from `docs/RESTRUCTURE-2026-06.md`; if it adds no future value, it can be dropped without committing.
2. Add a short section to `USAGE.md` (or a link to `docs/RESTRUCTURE-2026-06.md`) explaining the `.cursor/rules/*.mdc` generation mechanism at `setup-repo.sh` runtime, so a new user doesn't go looking for those `.mdc` files as versioned artifacts.
3. Confirm that `docs/RESTRUCTURE-2026-06.md` should be committed as-is (currently untracked) — it is, in fact, the document that best answers the comparison this task asked for; it's worth having it in the commit history, not just the working directory.
4. Run `bash setup-repo.sh` in a test repo (or review manually) to confirm at runtime that `generate_cursor_rule()` produces `.mdc` files identical to the source `.md` (the "verified byte-for-byte" claim in `docs/RESTRUCTURE-2026-06.md` line 48 was not revalidated in this read-only session).
5. No urgent "fix" action is needed — the split is functionally complete and consistent; the "Cursor plan" was an evaluated and consciously simplified proposal, not a plan abandoned halfway.

## Files reviewed

- `claude-cursor_monorepo_split_1b1edd71.plan.md`
- `docs/RESTRUCTURE-2026-06.md`
- `plan.md`
- `install.sh`
- `setup-repo.sh`
- `README.md`
- `USAGE.md`
- `docs/tool-compatibility.md`
- `docs/GITHUB-ACTIONS-SETUP.md`
- `shared/skills/README.md`
- `tools/claude/` (full tree, 12 agents + rules + hooks + settings.json)
- `shared/` (full tree)
