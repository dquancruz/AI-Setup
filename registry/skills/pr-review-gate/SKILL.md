---
name: pr-review-gate
description: Pre-PR quality gate that mirrors the external AI PR reviewer's exact rubric (coherence, scalability, reusability, security, testing), so a PR is expected to pass on its first external review instead of bouncing back and forth. Use before pr-manager opens a PR, and after it — to batch-fix every comment from the external reviewer in one round instead of trickling fixes.
tools: [Read, Grep, Bash]
tier: core
---

# PR Review Gate

## Why this exists

This project's PRs get a second, external review from an AI reviewer (configured
outside this repo, e.g. in Cursor/GitHub) running a fixed rubric. Left
unmanaged, that produces a "ping-pong" pattern: a PR opens, the external
reviewer leaves several rounds of comments, an agent fixes one at a time,
each fix re-triggers another review pass, and the PR takes many round trips
to land.

The fix isn't to argue with the external reviewer — it's to make sure
nothing it would flag ever reaches it. This skill is the internal rubric,
kept word-for-word aligned with the external one, that **code-reviewer-pro**,
**test-engineer**, and (when escalated) **security-expert** must all clear
before **pr-manager** is allowed to open the PR. If the external reviewer
still leaves comments after that, they get fixed as one batch, not one
comment per commit.

## The mirrored rubric

These five categories are the external reviewer's exact criteria. Each maps
to an owner on our side:

| # | External reviewer criterion | Internal owner | Local review section |
|---|---|---|---|
| 1 | Code Coherence & Readability | code-reviewer-pro | Quality |
| 2 | Scalability & Performance | code-reviewer-pro | Performance |
| 3 | Code Reusability | code-reviewer-pro | Quality → Reusability |
| 4 | Security & Best Practices | code-reviewer-pro (light scan, always) → security-expert (deep, when escalated — see [[security-expert]]'s escalation triggers) | Security |
| 5 | Testing | test-engineer | full report |

If a finding under any of these five would read, verbatim, like something
the external prompt asks for ("ensure the author is reusing existing
utilities...", "ensure appropriate unit/integration tests are included..."),
treat it as BLOCKER severity regardless of how it'd normally be scored — the
external reviewer will not approve past it, so neither do we.

## The gate (before pr-manager opens the PR)

A PR is only opened once ALL of the following hold:

- [ ] code-reviewer-pro has run on the full diff and reports **zero
      BLOCKER findings** in Security, Quality, or Performance
- [ ] test-engineer has run and reports **zero missing coverage on
      critical paths** — every criterion #5 (Testing) gap is closed
- [ ] If the diff touches auth, secrets, crypto, network surface, or IaC —
      security-expert has reviewed and signed off (escalation per its own
      "When I'm invoked" triggers)
- [ ] No unresolved duplication that visibly reinvents an existing
      util/component/function (criterion #3) — check before writing new
      logic, not just before opening the PR: grep for an existing
      implementation first

This is a hard gate, not a checklist to eyeball. `pr-manager` refuses to run
`auto-pr` while any box above is unchecked, and reports back which agent
still owes a clean pass — it does not open the PR "to see what the external
reviewer says."

## After the PR is open: handling external reviewer comments

If the external reviewer still leaves comments (it will occasionally catch
something genuinely new — that's fine):

1. **Wait for the full review to land**, don't react to the first comment
   that appears — external reviewers often post several comments across one
   pass.
2. **Triage all comments at once** and route each to its owner using the
   table above (readability/reuse/performance → code-reviewer-pro, security
   → security-expert, testing → test-engineer).
3. **Fix everything in a single commit** (or a tight, reviewed batch),
   covering every open comment — never push a one-line fix per comment.
4. **Push once, then stop** — let the external reviewer re-run on the batch
   rather than re-requesting review after each incremental push.
5. If the same category of comment shows up on two different PRs, that's a
   signal this rubric or the relevant agent's checklist is missing
   something — update the mirrored rubric above (or the owning agent's
   review categories) so it's caught locally next time, not just fixed
   reactively.

## Rules

- **The five categories above are not optional extras** — they are the
  actual pass/fail criteria a human-invisible reviewer will apply. Treat
  drift between this table and the external prompt as a bug in this skill.
- **Never open a PR to "see what happens."** The gate exists specifically so
  that doesn't happen — it's the behavior that causes the ping-pong.
- **Batch, don't trickle.** One fix commit addressing every open comment
  beats N commits addressing one comment each — both for the external
  reviewer's round count and for keeping the diff reviewable.
- If the external reviewer's prompt changes, update this file first — every
  agent that consults it stays in sync automatically.
