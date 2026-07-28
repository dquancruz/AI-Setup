---
name: auto-commit
description: Generates semantic commit messages following Conventional Commits. Use when the user wants to commit changes, asks for "auto-commit", or when backend-expert/frontend-expert have validated code ready to commit.
argument-hint: --message "feat: add auth" --scope api --jira PROJ-123
tools: [Bash, Read]
tier: core
---

# Auto-Commit Best Practices

## Format: Conventional Commits

```
<type>(<scope>): <subject> [<ticket>]

<optional body>

<optional footer>
```

## Types
- `feat` — new functionality
- `fix` — bug fix
- `refactor` — neither a feature nor a fix
- `perf` — performance improvement
- `test` — tests
- `docs` — documentation only
- `style` — formatting (no logic change)
- `chore` — deps, build, CI

## Subject rules
- Imperative: "add", not "adds" or "added"
- No leading capital, no trailing period
- Max 50 characters

## Pre-commit validations (ALWAYS)
1. `npm test` — all tests must pass
2. `npx tsc --noEmit` — no type errors
3. `npm run lint` — no lint errors
4. No `console.log`, `.only()`, `.skip()`, hardcoded secrets

## Command
```bash
npm run auto-commit -- \
  --message "feat(api): add date filter [PROJ-123]" \
  --files src/api/reports.ts \
  --push
```

## Anti-patterns
- ❌ `git commit -m "fix stuff"` → ✅ `fix(api): handle null dates`
- ❌ Subject in past tense → ✅ imperative
- ❌ No ticket on features → ✅ `[PROJ-123]`
