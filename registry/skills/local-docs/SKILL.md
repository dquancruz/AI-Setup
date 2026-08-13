---
name: local-docs
description: Format and update rules for .local-docs/ — the gitignored, local-only human-context folder (plan, architecture, security gaps, decisions). Use whenever you're about to record a finding, decision, or plan status in .local-docs/, or when setup-repo.sh needs to know what to scaffold.
tools: [Read, Write, Edit]
tier: core
---

# Local Docs

## What `.local-docs/` is for

Human-context notes a person (or the next agent) needs to understand this
project, that don't belong in shipped documentation and must never reach the
remote: architecture rationale, tracked security gaps, decisions, and the
project's living working plan. `setup-repo.sh` creates it from these
templates and adds it to `.gitignore` — it is never committed.

## The rule: update in place, don't leave things stale

Whenever something a `.local-docs/` file describes changes, update **that
entry**, immediately, as part of the same piece of work — not as a separate
follow-up:

- A tracked security gap gets fixed → change its `Status` to `Done` in
  `security-gaps.md` and fill in `Approach/Resolution` with what was
  actually done (not what was planned).
- A plan phase/task completes → change its status to `Done` in `plan.md`
  and add a one-line note on the actual approach.
- An architectural decision is revisited or reversed → add a **new** entry
  in `decisions.md` linking back to the old one. Don't rewrite history.
- Architecture actually changes → update `architecture.md`'s relevant
  section directly.

Never delete a resolved/superseded entry — the resolved state is itself
useful history for whoever reads this next.

## File formats

### `plan.md`
Phases with a `Status: Pending | In Progress | Done` line and a task
checklist. On completion, flip the status and append `**Done (YYYY-MM-DD):**
<short note>`.

### `architecture.md`
Free-form sections: Overview, Key decisions, Data flow, Known trade-offs.
Edit sections directly as the system evolves — this file describes current
state, not history.

### `security-gaps.md`
One table, one row per gap:
```
| Status | Description | Discovered | Approach/Resolution |
```
`Status` is `Open`, `In Progress`, or `Done`. Never remove a row — a `Done`
row with a clear resolution is the record that the gap was actually closed
and how.

### `decisions.md`
One entry per decision:
```
## <Decision title>
- **Date:**
- **Context:**
- **Outcome:**
```

## Who maintains this
- `security-expert` records and updates `security-gaps.md`.
- `solutions-expert` records `architecture.md` / `decisions.md`, and sets up `plan.md` when scoping significant work.
- `agent-orchestrator` keeps `plan.md` phase/task statuses current as it sequences and completes work.
- Any agent that resolves a tracked item updates it before moving on — this isn't limited to the three above.
