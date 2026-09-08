---
name: auto-pr
description: Guide for creating PRs automatically via script. Use when commits are on a feature branch, tests pass in CI, and it's time to open the PR on GitHub.
argument-hint: --branch feat/add-auth --jira PROJ-123 --draft
tools: [Bash]
tier: core
---

# Auto-PR Creation Guide

## Prerequisites before creating the PR

These mirror the `pr-review-gate` skill — see it for the full rationale
(this project's PRs get a second, external AI review, and this gate exists
so they pass it on the first pass instead of round-tripping):

- [ ] Feature branch (NEVER create a PR from main)
- [ ] All tests pass in CI
- [ ] Test coverage validated (test-engineer) — **zero** open missing-coverage
      findings on critical paths, not just "was reviewed"
- [ ] Code review completed (code-reviewer-pro) — **zero** open BLOCKER
      findings, not just "was reviewed"
- [ ] security-expert has signed off, if the diff touched auth, secrets,
      crypto, network surface, or IaC
- [ ] No hardcoded secrets

If any box isn't a clean pass, send the diff back to the owning agent —
don't open a draft PR "to get a head start" on the external review; that's
the ping-pong pattern this gate exists to prevent.

## Command
```bash
npm run auto-pr -- \
  --branch $(git branch --show-current) \
  --jira PROJ-123 \
  --title "feat(api): add date filter [PROJ-123]"
```

## What the script does
1. Verifies the branch is NOT main
2. Pushes the branch if it doesn't exist on origin
3. Creates the PR via the GitHub API with the formatted description (see the `pr-formatter` skill)
4. Assigns reviewers (test-engineer, code-reviewer-pro)
5. Links the Jira ticket

## PR title
Identical to the branch's main commit, plain by default (no emoji — see `Commit/PR style` in `AGENTS.md`; emoji is an opt-in exception for a project's initial bootstrap phase only):
```
Feature | Add date filter [PROJ-123]
```

## Automatic labels
- `feature` for feat:
- `bug` for fix:
- `refactor` for refactor:
- `wip` if created as a draft

## Rules
- NEVER push directly to main — always via PR
- Draft PR if the work isn't complete
- Assign at least one reviewer
