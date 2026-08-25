# AUDIT-v3 — Fase 0 baseline (update-plan-aug-2026.md)

> Generated as part of Fase 0.1. Snapshot taken 2026-08-24 against `main`
> (commit `6d7b6ca`). Re-run the checks below (`npm test`, the greps in this
> file) to see if it's gone stale before trusting it for a later phase.

---

## 1. Agent inventory — `registry/agents/*.md`

13 agents, all with `tier: core` frontmatter and a `## Essence` block (both
required by `lib/condense.mjs`'s tier-C rendering — verified: no agent is
missing either).

| Agent | Words | Chars | Hardcoded stacks mentioned |
|---|---:|---:|---|
| `agent-orchestrator` | 753 | 5,140 | — |
| `aws-architect` | 477 | 3,296 | AWS |
| `backend-expert` | 473 | 3,475 | NestJS, FastAPI, MongoDB, GPIO, Raspberry Pi |
| `cdk-expert` | 434 | 3,132 | AWS, CDK |
| `code-reviewer-pro` | 520 | 3,436 | GPIO |
| `documentation-generator` | 577 | 3,917 | — |
| `frontend-expert` | 612 | 4,482 | React, Next.js, Astro |
| `iot-backend-expert` | 587 | 4,123 | FastAPI, MongoDB, GPIO, Raspberry Pi |
| `pr-manager` | 517 | 3,409 | — |
| `security-expert` | 483 | 3,535 | CDK |
| `solutions-expert` | 456 | 3,237 | — |
| `test-engineer` | 727 | 4,803 | GPIO |
| `ticket-orchestrator` | 507 | 3,500 | — |

**Reading this:** `backend-expert` and `iot-backend-expert` are stack-specific
by design (that's their job). `code-reviewer-pro` and `test-engineer`
mentioning `GPIO` is a lighter coupling — likely an example in a bullet, not
a hard dependency; worth a skim before Fase 3 packs the `core` plugin (which
includes both) as stack-agnostic. `cdk-expert`/`aws-architect` are cloud-pack
material, already scoped correctly per the Fase 3.1 table.

---

## 2. Skill inventory — `registry/skills/*/SKILL.md`

12 skills, all with `tier` frontmatter (verified: no skill missing `tier`).
`test/lint-frontmatter.mjs` (added this phase) now enforces `name` + `description`
presence, `name` == folder name, and length limits on every CI run.

| Skill | Words | Third person? | Explicit trigger conditions? |
|---|---:|---|---|
| `auto-commit` | 220 | ✅ ("Generates...") | ✅ "Use when..." |
| `auto-pr` | 251 | ✅ | ✅ |
| `cloud-iac-security` | 326 | ✅ | ✅ |
| `design-system` | 415 | ✅ | ⚠️ "ALWAYS load" — a standing rule, not a condition; fine given its scope (frontend work) but worth double-checking it doesn't fire on backend-only sessions |
| `immersive-3d` | 350 | ✅ | ✅ (preset-gated) |
| `iot-backend` | 200 | ✅ | ✅ |
| `jira-integration` | 251 | ✅ | ✅ |
| `local-docs` | 430 | ✅ | ✅ |
| `pr-formatter` | 235 | ✅ | ✅ |
| `secure-coding` | 378 | ✅ | ✅ |
| `semantic-versioning` | 291 | ✅ | ✅ |
| `threat-modeling` | 376 | ✅ | ✅ (phase-gated: "DESIGN phase") |

All 12 pass the triggering convention check (third person, explicit "Use
when" / "Load when" condition). No action needed here for Fase 0.

---

## 3. `install.sh` / `setup-repo.sh` — what they actually write vs. the README

Verified two ways: manual read of both scripts, and (now) `test/install.bats`
+ `test/setup-repo.bats` running the real scripts against throwaway
`HOME`/target-repo dirs and asserting every destination in the README's
"What goes where" table. All 13 assertions pass — **no discrepancy found**
between the scripts and the README table as of this commit.

One drift **risk**, not yet a bug, worth flagging for Fase 3+:

- `setup-repo.sh` copies `.claude/hooks/{pre,post}-tool-use/*.sh` by
  **hardcoded filename** (`block-secrets.sh`, `lint-after-write.sh`), not by
  wildcard, even though the README table describes it as
  `hooks/{pre,post}-tool-use/*.sh`. Today there's exactly one file per
  directory, so behavior matches the table. But adding a second hook to
  `registry/hooks/` won't reach target repos until someone remembers to add
  an explicit `cp` line here too — a silent gap, not a loud error. Fase 1's
  `hook-to-cursor.sh` bridge should not repeat this pattern; wildcard-copy
  by default and special-case only where a per-file `failClosed` value is
  needed.
- `registry/templates/local-docs/*.md` includes a `README.md` alongside
  `plan.md`/`architecture.md`/`security-gaps.md`/`decisions.md`. `setup-repo.sh`
  copies all of them (wildcard), so target repos get a `.local-docs/README.md`
  too — correct behavior, but `USAGE.md`'s "starter files" list only names
  the other four. Minor doc gap, not a script bug.

---

## 4. `tools/*/capabilities.yaml` vs. the README portability table

Compared `tools/claude/capabilities.yaml`, `tools/cursor/capabilities.yaml`,
`tools/copilot/capabilities.yaml` line by line against README's "Portability
by layer" table and `docs/tool-compatibility.md`'s "Compatibility table".

**No internal contradiction** — all three sources currently agree with each
other cell by cell (Hooks ❌ for Cursor/Copilot, Skills 🟡 "referenced" for
Cursor, etc.).

**But they agree on something that appears to be wrong about reality**, which
is exactly what Fase 1's context block flags: Cursor has shipped
`beforeShellExecution`/`afterFileEdit`/etc. hooks since 1.7 via
`.cursor/hooks.json`, and none of `capabilities.yaml`, the README table, or
`tool-compatibility.md` reflect that — all three still say Hooks: ❌ for
Cursor. This audit does **not** independently re-verify Cursor's hooks
support (that's Fase 1.1's job, with a live source check); it only confirms
the three internal documents are *consistent with each other* and therefore
this is a single fact to fix in one place (Fase 1), not three files that
have drifted from each other.

**Structural gap, not a content error:** `docs/tool-compatibility.md`'s table
has no "verified" or "date checked" column at all — every cell is asserted
with no citation. Fase 1.2 / the "Orden de ejecución" section both require
citing source + date per claim going forward; today's table gives that
requirement nothing to build on incrementally, so the first pass through
Fase 1 will need to add the column, not just fill in new rows.

---

## 5. Fase 0.2 — smoke tests (delivered this phase)

Added, `npm test` runs green locally (Windows/Git Bash, Node v24, `bats` npm
package v1.13.0 as a devDependency — see `package.json`):

- `test/install.bats` — 4 tests: agent count/content match, skill
  count/content match, existing-agents backup-not-overwrite, idempotent
  double-run (content hash equal).
- `test/setup-repo.bats` — 9 tests: refuses outside a git repo, creates
  every README-declared destination, idempotent double-run, non-overwrite of
  `.mcp.json` / `.claude/settings.json` / `.env.local` / `.local-docs/`
  (marker-content fixtures, per the plan's spec), AGENTS.md append-only
  (first line preserved + new lines present), AGENTS.md no-double-append on
  a second run.
- `test/lint-frontmatter.mjs` — validates all 12 `SKILL.md` files; passes
  clean against the current registry.

Not yet wired to a CI matrix beyond what `.github/workflows/ci.yml` (added
this phase) does — see below.

---

## 6. Fase 0.3 — CI (delivered this phase)

`.github/workflows/ci.yml` (this repo's own CI — distinct from
`registry/templates/github/workflows/*`, which render into *target* repos
and never run here): three jobs — `shellcheck` (Ubuntu), `unit-tests`
(`npm test` on Ubuntu), `fixture-install` (`install.sh` + `setup-repo.sh`
against a throwaway fixture repo, matrixed on `ubuntu-latest` +
`macos-latest`, plus a same-job idempotency re-run).

**Real finding surfaced by actually running shellcheck** (downloaded
v0.10.0 locally to verify before trusting the CI job — see Bitácora): all 10
`.sh` files in the repo checked out with CRLF line endings on this Windows
machine (`core.autocrlf=true`; the git blobs themselves are LF-only — verified
via `git cat-file -p`), which shellcheck flags as `SC1017` on every line.
That's a local-checkout artifact, not a stored-content bug, so it would
**not** have failed the Ubuntu/macOS CI runners either way — but it's a real
landmine for any Windows contributor's editor that respects `core.autocrlf`
and re-saves a script with CRLF, since a CRLF shebang (`#!/bin/bash\r`)
fails to exec on Linux. Fixed by adding `.gitattributes` (`*.sh`/`*.bats`/
`*.mjs`/`*.js` forced to `eol=lf`) — no blob renormalization was needed since
the stored content was already LF-only.

**Genuine (non-CRLF) shellcheck findings, fixed this phase:**

| File | Issue | Fix |
|---|---|---|
| `install.sh` (x2) | SC2086 — unquoted `$CLAUDE_DIR` in `ls -A $CLAUDE_DIR/...` | quoted |
| `install.sh` (x2) | SC2012 — `ls \| wc -l` for counting | switched to `find -maxdepth 1` |
| `setup-repo.sh` (x2) | SC2129 — repeated individual `>>` redirects | grouped into one `{ ...; } >>` block |
| `tools/cursor/enable.sh` (x2) | SC2088 — literal `~/...` inside a doc-text `echo` (not meant to expand) | `# shellcheck disable=SC2088` with a one-line reason, at each site |

All were style/info/warning level, no behavior change. Re-verified clean
(`shellcheck` exit 0) against LF-normalized content before committing.

---

## 7. Open items carried into later phases (not blocking Fase 0 completion)

- Fase 1.1: verify Cursor hooks support against a live source (docs or
  changelog) and date the claim — see section 4 above.
- Fase 1.2: same live-verification treatment for the Skills row, plus add
  the missing "verified" column to `docs/tool-compatibility.md`.
- Fase 5 (pre-existing, from `docs/AI-SETUP-PLAN-v2.md`): `tools/gemini/`
  and `tools/codex/` adapters don't exist yet — README already discloses
  this, no new finding.

---

## Acceptance check (Fase 0.1)

- [x] `docs/AUDIT-v3.md` exists.
- [x] Agent/skill table includes per-file size (words + chars for agents;
      words for skills, chars omitted as redundant at this scale).
- [x] `install.sh`/`setup-repo.sh` destinations verified against the README
      table (now continuously, via `test/setup-repo.bats` + `test/install.bats`
      in CI, not just this one-time read).
- [x] `capabilities.yaml` vs. README discrepancies documented (none found
      internally; one shared-and-likely-stale claim flagged for Fase 1).
