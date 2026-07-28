# Skills — Portability Guide

Skills are in `<name>/SKILL.md` format with standard (Agent Skills) frontmatter.

## Structure

```
registry/skills/
├── auto-commit/SKILL.md
├── pr-formatter/SKILL.md
├── semantic-versioning/SKILL.md
├── iot-backend/SKILL.md
├── auto-pr/SKILL.md
├── jira-integration/SKILL.md
├── design-system/SKILL.md
├── immersive-3d/SKILL.md
├── threat-modeling/SKILL.md
├── secure-coding/SKILL.md
├── dependency-and-secrets-audit/SKILL.md
└── cloud-iac-security/SKILL.md
```

## Installation (Claude Code)
```bash
./install.sh
# Copies registry/skills/*/ → ~/.claude/skills/
```

## Cross-tool portability

### Cursor
In Cursor's system prompt, point to `~/.claude/skills/`:
```
Refer to the skill files in ~/.claude/skills/ for domain-specific conventions.
```

### Gemini CLI
Skills are referenced by name in the agent workflow documented in `AGENTS.md` (symlinked as `GEMINI.md`).

### GitHub Copilot
Copy the relevant skill content into `.github/copilot-instructions.md` for the most critical context.

### Codex
Point the system prompt at `~/.claude/skills/` as additional context.
