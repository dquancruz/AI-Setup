#!/usr/bin/env bash
# PreToolUse hook: blocks writes that contain secret patterns or that
# target a real .env file (not .env.example/.sample/.template templates).
# Also blocks Read of a real .env file outright — Fase 4.2,
# update-plan-aug-2026.md: reading .env.local into the conversation would
# send its secrets to the model, which is exactly what this hook exists to
# prevent on the write side already.
# Blocking: exit 2 stops the tool call and returns the stderr message to Claude.
# Must not block writes mid-way through a multi-step plan due to false positives —
# the patterns are deliberately conservative (see plan.md Fase 6).

set -uo pipefail

# Detects the available Python interpreter: some environments (e.g. Git Bash on
# Windows) only have `python`, not `python3`. If neither exists, fail closed
# (fail-safe) instead of silently letting everything through — a security hook
# that fails open without warning is worse than not having one.
PYTHON_BIN=""
for candidate in python3 python py; do
  if command -v "$candidate" &>/dev/null; then
    PYTHON_BIN="$candidate"
    break
  fi
done

if [ -z "$PYTHON_BIN" ]; then
  echo "block-secrets.sh: no python3/python/py found in PATH — cannot verify secrets. Blocking for safety." >&2
  exit 2
fi

INPUT=$(cat)

# Accepts Claude Code's real schema (nested tool_input.file_path/content)
# and flat schemas (file_path/path, content/new_string at the root), so the
# same logic works for any tool that fires this hook, not just Claude Code.
TOOL=$(echo "$INPUT" | "$PYTHON_BIN" -c "
import sys, json
d = json.load(sys.stdin)
print(d.get('tool_name', '') or d.get('tool', ''))
" 2>/dev/null || true)

if [[ "$TOOL" != "Write" && "$TOOL" != "Edit" && "$TOOL" != "str_replace_editor" && "$TOOL" != "Read" ]]; then
  exit 0
fi

FILE=$(echo "$INPUT" | "$PYTHON_BIN" -c "
import sys, json
d = json.load(sys.stdin)
ti = d.get('tool_input', {}) or {}
print(ti.get('file_path', '') or ti.get('path', '') or d.get('file_path', '') or d.get('path', ''))
" 2>/dev/null || true)

if [ -z "$FILE" ]; then exit 0; fi

BASENAME=$(basename -- "$FILE")

# Real .env file (not a template) — block without needing to inspect content.
# Applies to reads too: a Read that succeeds puts the file's secrets into
# the conversation sent to the model, same exposure as a leaked write.
if [[ "$BASENAME" =~ ^\.env(\..+)?$ ]] && [[ ! "$BASENAME" =~ \.(example|sample|template)$ ]]; then
  if [[ "$TOOL" == "Read" ]]; then
    echo "Blocked: attempt to read a real .env file ($FILE) — its contents would be sent to the model." >&2
  else
    echo "Blocked: attempt to write to a real .env file ($FILE)." >&2
  fi
  echo "If you need to document environment variables, use .env.example with placeholder values." >&2
  exit 2
fi

# Read never has content/new_string to scan for secret patterns below.
if [[ "$TOOL" == "Read" ]]; then
  exit 0
fi

CONTENT=$(echo "$INPUT" | "$PYTHON_BIN" -c "
import sys, json
d = json.load(sys.stdin)
ti = d.get('tool_input', {}) or {}
print(ti.get('content', '') or ti.get('new_string', '') or d.get('content', '') or d.get('new_string', ''))
" 2>/dev/null || true)

if [ -z "$CONTENT" ]; then exit 0; fi

# Common secret patterns. Deliberately conservative (provider-specific
# prefixes/formats) instead of generic entropy heuristics, to minimize false
# positives that would interrupt an in-progress multi-step plan.
PATTERNS=(
  'AKIA[0-9A-Z]{16}'                       # AWS access key id
  '-----BEGIN [A-Z ]*PRIVATE KEY-----'     # private key (RSA/EC/PGP/etc.)
  'ghp_[A-Za-z0-9]{36}'                    # GitHub personal access token
  'gh[oprsu]_[A-Za-z0-9]{36}'              # other GitHub tokens (oauth/app/refresh/user)
  'xox[baprs]-[A-Za-z0-9-]{10,}'           # Slack token
  'sk-(live|proj)?[A-Za-z0-9]{20,}'        # OpenAI/Stripe-style secret key
)

for PATTERN in "${PATTERNS[@]}"; do
  if echo "$CONTENT" | grep -Eq "$PATTERN" 2>/dev/null; then
    echo "Blocked: the content written to $FILE appears to contain a secret (pattern matched: $PATTERN)." >&2
    echo "If this is a false positive, use a placeholder or review manually before continuing." >&2
    exit 2
  fi
done

exit 0
