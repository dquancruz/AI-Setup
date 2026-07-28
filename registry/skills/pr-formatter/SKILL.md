---
name: pr-formatter
description: Formats pull request descriptions in this project's own standard (What/Why/Testing/Related). Use when a PR is about to be created or when pr-manager needs to generate the description.
argument-hint: --branch feat/add-auth --jira PROJ-123
tools: [Bash, Read]
tier: core
---

# PR Description Formatter

## This project's standard format

```
[EMOJI] [TYPE] | [DESCRIPTION] [TICKET]

## What
- Change 1
- Change 2

## Why
Reason for the change and problem solved.

## Testing
- [ ] Unit tests pass
- [ ] Integration tests pass
- [ ] Tested on the feature branch (not main)

## Related
- Jira: [PROJ-123](url)
- Related PR: #456
```

## Emojis by type
- ✨ feat | 🐛 fix | ♻️ refactor | 📚 docs | 🚀 perf | 🧪 test | 🔧 chore

## Rules
- Title = the branch's main commit
- What = list of concrete changes
- Why = the problem it solves, NOT what was done
- Testing = a checklist the reviewer can execute
- Always link Jira

## Invocation via pr-manager
```bash
npm run auto-pr -- --branch $(git branch --show-current) --jira PROJ-123
```
