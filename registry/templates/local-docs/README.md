# Local Docs

Human-context notes for this repo: why things are built the way they are, what's
known to be broken or risky, decisions made along the way, and the working plan.
This is **not** shipped documentation — it's gitignored (see the `.local-docs/`
entry added to `.gitignore` by `setup-repo.sh`) and never reaches the remote.

## Files

- `plan.md` — the living working plan: phases/milestones, task status. Read this first when picking up work on the project.
- `architecture.md` — architecture rationale, data flow, key decisions, known trade-offs.
- `security-gaps.md` — tracked security gaps: status, description, approach/resolution.
- `decisions.md` — lightweight decision log (what was decided, why, and the outcome).

## The one rule that matters

**Keep entries current.** When something documented here changes — a security
gap gets fixed, a decision gets revisited, a plan phase completes — update
that entry *in place*: change its status, add the date, and describe the
approach actually taken. Don't leave it stale, and don't just delete it —
the resolved/superseded state is itself useful history for whoever reads
this next (including future-you).

See the `local-docs` skill for the exact format each file uses.
