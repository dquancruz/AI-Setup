#!/usr/bin/env bash
# Generates the symlinks that point to the SSOT (AGENTS.md).
# Run from the root of the target repo where AGENTS.md already exists.
set -euo pipefail

[ -f AGENTS.md ] || { echo "❌ AGENTS.md is missing (the SSOT). Create it first from the template."; exit 1; }

# Claude Code
ln -sf AGENTS.md CLAUDE.md
# Gemini CLI
ln -sf AGENTS.md GEMINI.md
# GitHub Copilot
mkdir -p .github
ln -sf ../AGENTS.md .github/copilot-instructions.md
# Cursor (reads AGENTS.md natively + mcp symlink)
mkdir -p .cursor
ln -sf ../.mcp.json .cursor/mcp.json 2>/dev/null || true

echo "✅ Symlinks created:"
echo "   CLAUDE.md → AGENTS.md"
echo "   GEMINI.md → AGENTS.md"
echo "   .github/copilot-instructions.md → ../AGENTS.md"
echo "   .cursor/mcp.json → ../.mcp.json"
echo ""
echo "ℹ️  Cursor and Codex read AGENTS.md directly (no instructions symlink needed)."
