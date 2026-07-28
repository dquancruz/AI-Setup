# Cross-Tool Compatibility

This repo is designed so that **Claude Code, Cursor, GitHub Copilot, Antigravity, and Codex** can all work on the same project with the same context. But not every layer "activates" the same way in every tool — this document explains exactly what each one gets when you clone the repo and run `setup-repo.sh`.

**General rule:** anything that lives in standard files (instructions, MCP, skills, rules) is portable. Anything that's an *internal mechanism* of Claude Code (hooks, subagents) has no 1:1 equivalent in the others — its knowledge does travel (via AGENTS.md/skills), but the orchestrator doesn't.

---

## Compatibility table

| Layer | File | Cursor | Codex | Antigravity | GitHub Copilot | Claude Code |
|---|---|:---:|:---:|:---:|:---:|:---:|
| Project instructions | `AGENTS.md` | ✅ native | ✅ native | ✅ native | ✅ (symlink) | ✅ (symlink) |
| MCP servers | `.mcp.json` | ✅ native (`.cursor/mcp.json`) | ✅ native | ✅ native | 🟡 partial | ✅ native |
| Skills (knowledge) | `SKILL.md` | 🟡 if referenced | 🟡 if referenced | 🟡 if referenced | ❌ | ✅ auto-discovery |
| Path-scoped rules | `.claude/rules` / `.cursor/rules` | ✅ (`.mdc`) | 🟡 via AGENTS.md | 🟡 via AGENTS.md | ❌ | ✅ native |
| Hooks (Pre/PostToolUse) | `.claude/hooks` | ❌ | ❌ | ❌ | ❌ | ✅ native |
| Git hooks (Husky) | `.husky/` | ✅ | ✅ | ✅ | ✅ | ✅ |
| Subagents (the 13 specialists) | `~/.claude/agents` | ❌ different concept | ❌ | ❌ own system | ❌ | ✅ native |

✅ works the same · 🟡 works with friction or needs manual referencing · ❌ no equivalent

---

## What this means in practice

### If someone clones the repo and opens **Cursor**
It reads `AGENTS.md` automatically (same conventions, commands, architecture). It connects the same MCP servers via `.cursor/mcp.json`. Its `.cursor/rules/*.mdc` activate by path just like in Claude Code. The skills (`design-system`, `secure-coding`, etc.) **don't auto-trigger** — they need to be mentioned, or Cursor's active mode needs to reference them explicitly. It doesn't have the 13 subagents; the equivalent work is done by a single Cursor session reading the same context.

### If someone uses **Codex** or **Antigravity**
Same treatment: instructions and MCP work natively. Rules and skills work if the tool reads them as additional context (via AGENTS.md or a manual reference), but without Claude Code's automatic progressive disclosure.

### If someone uses **GitHub Copilot**
The most limited of the five: it reads `copilot-instructions.md` (a symlink to AGENTS.md), and MCP only partially depending on the client (VS Code vs. others). It has no concept of skills or rules — anything it needs must be summarized inside AGENTS.md.

### What's exclusive to **Claude Code**
- **Hooks** `PreToolUse`/`PostToolUse` (e.g. blocking secrets before they're written to disk).
- **The 13 subagents** working in parallel with isolated context each (`solutions-expert`, `backend-expert`, `security-expert`, etc.) and skill auto-discovery via progressive disclosure.

This is intentional: Claude Code remains this setup's "full" tool. The others get the project's **context and knowledge** (which is 80% of the value), but not the **orchestrator**.

---

## Practical implication for the team

- **Real parallel/multi-agent work** → use Claude Code.
- **Fast editing with the same project context** → Cursor, Codex, or Antigravity work well; the repo already gives them AGENTS.md + MCP + rules.
- **Copilot** → treat it as the minimum-viable case; if a convention is critical, it must be explicit in AGENTS.md, not assumed from a skill or a hook.
- If a skill turns out to be critical for **any** tool to follow (not just Claude Code), consider promoting it to a short section inside `AGENTS.md` instead of leaving it as a skill only — that way it doesn't depend on auto-discovery.
