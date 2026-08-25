# Changelog

History of `AI-Setup` itself (formerly `claude-automation-setup`) — how this tooling repo evolved. This is not the per-repo `CHANGELOG.md` that `semantic-versioning` generates for projects that *use* this setup; it's the story of the setup itself.

No version tags exist yet (this repo isn't published/versioned independently), so entries are grouped by milestone rather than SemVer release.

## 2026-08-24 — Fase 0 of `update-plan-aug-2026.md`: baseline (audit, smoke tests, CI)

- Added `docs/AUDIT-v3.md`: full inventory of the 13 agents / 12 skills (size, tier/Essence completeness, stack-coupling per agent, triggering-convention check per skill), a script-vs-README destination audit, and a `capabilities.yaml`-vs-README consistency check (internally consistent; flags the Cursor-hooks claim as likely stale, to be fixed with a live source check in Fase 1).
- Added a real smoke-test net where there was none: `test/install.bats` (4 tests) and `test/setup-repo.bats` (9 tests) run `install.sh`/`setup-repo.sh` against throwaway `HOME`/target-repo fixtures and assert every README-declared destination, idempotency (double-run produces an identical tree hash), and non-overwrite of `.mcp.json`/`.claude/settings.json`/`.env.local`/`.local-docs/` plus `AGENTS.md`'s append-only patch behavior. `test/lint-frontmatter.mjs` validates every `SKILL.md`'s `name`/`description` frontmatter. `bats` added as an npm devDependency (`package.json`, new — dev-only, doesn't affect what `install.sh`/`setup-repo.sh` put in target repos).
- Added `.github/workflows/ci.yml` — this repo's own CI (distinct from `registry/templates/github/workflows/*`, which render into target repos): `shellcheck` over every `.sh`, `npm test`, and an `install.sh` + `setup-repo.sh` fixture run matrixed on `ubuntu-latest`/`macos-latest` with an idempotency re-check.
- Fixed the shellcheck findings that surfaced from actually running it (SC2086 unquoted var, SC2012 `ls | wc -l`, SC2129 repeated redirects, SC2088 literal `~` in doc-text echoes — all style/info, no behavior change) in `install.sh`, `setup-repo.sh`, `tools/cursor/enable.sh`.
- Added `.gitattributes` forcing LF on `.sh`/`.bats`/`.mjs`/`.js` — the stored blobs were already LF-only, but `core.autocrlf=true` on Windows checkouts was rendering them as CRLF on disk, which both breaks a script's shebang if ever re-saved that way and makes `shellcheck` flag every line with a spurious `SC1017`.

## 2026-08-13 — Renamed to AI-Setup; local docs, plain commit/PR convention, descriptive CHANGELOG

- Renamed the repo (local folder, GitHub remote, and every internal reference) from `claude-automation-setup` to `AI-Setup`. Historical/point-in-time docs (`plan.md`, the "Nivel 3" docs, restructure analysis) were deliberately left referencing the old name — they're a record of what was true when written.
- Commit/PR convention: PR titles are now plain by default (no emoji) — matches the convention commits already followed. Emoji is an explicit opt-in exception for a project's initial bootstrap phase only, toggled via a new `Commit/PR style:` line in `AGENTS.md`. Updated `pr-formatter`, `auto-pr`, `pr-manager`, and `auto-pr.js`'s examples accordingly.
- Added `.local-docs/`: a new gitignored, per-repo folder for human-context notes that must never reach the remote — `plan.md` (the living working plan, phases/tasks/status), `architecture.md`, `security-gaps.md`, and `decisions.md`. Backed by a new `local-docs` skill (agent count unchanged at 13; skill roster now includes `local-docs` and drops the never-implemented `dependency-and-secrets-audit` phantom entry, real skill count still 12). `security-expert`, `solutions-expert`, and `agent-orchestrator` are wired to keep it current — e.g. a fixed security gap gets marked `Done` with the approach taken, not left stale. `setup-repo.sh` scaffolds it (create-if-missing) and gitignores it.
- CHANGELOG generation moved to a Keep-a-Changelog `[Unreleased]` scaffold with entries sourced from the merged PR's own title + `## Why` section (description, PR link, Jira keys) instead of a raw commit-message dump — see `on-merge.yml`, `documentation-generator`, and `semantic-versioning`.
- Upgrade path for repos already running this setup: re-running `setup-repo.sh` now patches an existing `AGENTS.md` with any new required lines (append-only, existing content untouched) instead of only skipping it — documented in `USAGE.md`'s new "Upgrading an existing repo" section.

## 2026-07-28 — Test engineer agent, PR format de-branded

- Added `test-engineer`: writes/strengthens unit tests and reviews backend/frontend/iot-backend-expert output for coverage and test quality, running right after implementation and before `code-reviewer-pro`. Wired into the orchestrator pipeline and added as a default PR reviewer. Agent count: 12 → 13.
- Replaced the TELUS-branded PR format naming (`pr-manager`, `pr-formatter` skill) with this project's own standard — same What/Why/Testing/Related structure, no external branding.
- Documentation cleanup: fixed the README architecture diagram and `USAGE.md` (both still described the pre-`registry/` `global/`/`per-repo/` layout), added a "what goes where" table mapping each `registry/` folder to its install destination (global `~/.claude/` vs. per-repo), corrected the tool-portability table against the real `tools/*/capabilities.yaml` contracts, and added the missing "superseded" banner to `plan.md` that other docs had referenced but never actually existed.
- Marked the original "Nivel 3" docs (`HOOKS-husky-complete.md`, `INDICE-FINAL-NIVEL-3.md`, `SETUP-COMPLETO-NIVEL-3.md`, `MCPS-configuracion-completa.md`) and the restructure analysis docs as historical, in place — content kept, not deleted or moved.
- Normalized all repo content (docs, agents, skills, scripts, comments) from mixed Spanish/English to English only.

## 2026-07-01 — Multi-tool architecture: `registry/` + tool adapters (AI-SETUP-PLAN-v2, Fases 1-4)

- **Fase 1** (`25476d0`): reorganized the original `global/`/`per-repo/` split into `registry/` as a single tool-agnostic source of truth for agents, skills, rules, hooks, scripts, and templates. `install.sh`/`setup-repo.sh` updated to the new paths with no functional change.
- **Fase 2** (`1f271f9`): added `tools/claude/capabilities.yaml` + `enable.sh` — an explicit contract documenting what Claude Code already did, as a thin wrapper around the existing install scripts.
- **Fase 3** (`1f271f9`): added a real Cursor adapter — `tools/cursor/adapt/rule-to-mdc.sh` (rules rendered fresh into `.cursor/rules/*.mdc`, never committed) and `agent-to-mode.sh` (agents rendered as Cursor Custom Modes, one file per agent).
- **Fase 4** (`f049a32`, `aef123b`): added `tier: core|extended` frontmatter to every agent/skill and built `lib/condense.mjs`, a deterministic condensation engine, plus a GitHub Copilot adapter that renders a budget-capped `copilot-instructions.md`.
- This work superseded an earlier, evaluated-and-rejected restructuring attempt (`shared/` + `tools/claude/` with committed codegen) — see `docs/RESTRUCTURE-2026-06.md` and `docs/PLAN-VS-REALIDAD-2026-07.md`, both kept as historical record of that decision.
- **Fases 5-6 (generalize `enable-repo.sh`/`install-global.sh` into a generic loop over `tools/*/capabilities.yaml`, and the doc regeneration that depends on it) remain pending** — tracked in `docs/AI-SETUP-PLAN-v2.md`.

## 2026-06-29..06-30 — Security layer and tool-compatibility docs

- Added the `security-expert` agent as a deep-AppSec escalation path, distinct from `code-reviewer-pro`'s always-on general review, plus its four skills (`threat-modeling`, `secure-coding`, `dependency-and-secrets-audit`, `cloud-iac-security`).
- Added `docs/tool-compatibility.md` documenting exactly what each supported AI tool gets from this repo.

## 2026-06-04..06-05 — Initial setup ("Nivel 3": full automation)

- First working version: 5 agents, 6 skills, 4 automation scripts (`auto-commit`, `auto-pr`, `auto-jira`, `dashboard`), Husky hooks, and GitHub Actions workflows (`pr-validation`, `on-merge`).
- Established the core automation loop this repo still follows: feature description → Jira Epic/Stories → implementation → auto-commit → auto-PR → merge → auto-version/release.
- Documented in the original `docs/SETUP-COMPLETO-NIVEL-3.md`, `docs/INDICE-FINAL-NIVEL-3.md`, `docs/HOOKS-husky-complete.md`, and `docs/MCPS-configuracion-completa.md` — all now marked historical but kept for their walkthrough content.
