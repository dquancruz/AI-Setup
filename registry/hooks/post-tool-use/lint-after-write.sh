#!/usr/bin/env bash
# PostToolUse hook: runs the linter after editing TS/JS/Python files.
# Non-blocking feedback — reports but does not fail the tool call.

set -uo pipefail

INPUT=$(cat)
# Accepts both field-name schemas known as of today (tool_name/tool),
# so the same logic works for any tool that fires this hook, not just Claude Code.
TOOL=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_name','') or d.get('tool',''))" 2>/dev/null || true)

if [[ "$TOOL" != "Write" && "$TOOL" != "Edit" && "$TOOL" != "str_replace_editor" ]]; then
  exit 0
fi

# Accepts both field-name schemas known as of today (file_path/path).
FILE=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('file_path','') or d.get('path',''))" 2>/dev/null || true)

if [ -z "$FILE" ]; then exit 0; fi

if [[ "$FILE" =~ \.(ts|tsx|js|jsx|mjs|cjs)$ ]]; then
  if command -v npx &>/dev/null && [ -f "package.json" ]; then
    echo "→ Linting $FILE ..."
    npx eslint "$FILE" --max-warnings 0 2>&1 || echo "⚠️  Lint warnings in $FILE (non-blocking)"
  fi
fi

if [[ "$FILE" =~ \.py$ ]]; then
  if command -v ruff &>/dev/null; then
    echo "→ Linting $FILE ..."
    ruff check "$FILE" 2>&1 || echo "⚠️  Ruff warnings in $FILE (non-blocking)"
  fi
fi

exit 0
