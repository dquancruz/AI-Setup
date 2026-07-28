# Context Management — Budget Guide

## Budget per session (approximate)

| Element | Tokens | When it loads |
|----------|--------|-----------------|
| AGENTS.md | ~100 | Always |
| Rules (path-scoped) | ~200 | Only if the path matches |
| Active skill | ~50-150 each | On demand |
| MCP definition | ~500+ | When connecting an MCP |
| Claude's system prompt | ~2000 | Always |
| **Remaining usable budget** | **~1.5-2k** | For real work |

## Practices

### One task per conversation
- `/clear` between unrelated tasks
- Don't chain "now do X, then Y, then Z" if they're distinct features

### Large investigations → subagent
- Exploring >30 files → spawn a subagent (`Explore` or fork)
- Keeps the main context clean for the real work

### When the model gets it wrong twice in a row
- `/clear` and restart with a more specific prompt
- Don't spend context trying to "correct" the model in the same thread

### Never dump the whole repo into context
- Use `Glob` and `Grep` for targeted searches
- A research subagent for broad code analysis

## Context anti-patterns

| Anti-pattern | Impact | Alternative |
|-------------|---------|-------------|
| "Read all of src/" | Exhausts context before starting | Ask the agent to explore only what it needs |
| Same session for 3 features | Cross-contaminated context → errors | `/clear` between features |
| 500-line AGENTS.md | Eats the whole budget | Keep it under ~150 lines, point to files |
| Redundant skills always loaded | +50-150 tokens per unnecessary skill | Only load the skill when it applies |

## Path-scoped rules: why they matter

Rules load ONLY when the file being edited matches the frontmatter's `path`. This means:
- Editing `src/api/routes.ts` → loads `backend.md`, NOT `frontend.md`
- Editing `src/components/Button.tsx` → loads `frontend.md` and `design.md`, NOT `backend.md`

Result: ~200 tokens of rules, not 1000 tokens from all rules concatenated.
