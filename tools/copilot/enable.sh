#!/bin/bash

# ============================================================================
# tools/copilot/enable.sh — GitHub Copilot adapter (Fase 4, AI-SETUP-PLAN-v2.md)
# ============================================================================
# Same thin-wrapper style as tools/claude/enable.sh and tools/cursor/enable.sh,
# but Copilot is tier C (docs/AI-SETUP-PLAN-v2.md section 2.2): there is no
# native agent/skill/rule concept, just one always-loaded instructions file.
# All the rendering logic lives in lib/condense.mjs (the shared, generic
# engine — see AI-SETUP-PLAN-v2.md section 6); this script is just the
# calling convention + target-path wiring for Copilot specifically, per
# tools/copilot/capabilities.yaml.
#
# What "enabling Copilot" means today, per tools/copilot/capabilities.yaml:
#
#   --scope=global -> nothing real to install. Copilot has no
#                     ~/.github/copilot-instructions.md equivalent (Copilot's
#                     personal-instructions feature lives in GitHub account
#                     Settings, not a file this setup can write) — same
#                     "not automated" shape as Cursor's global_scope:
#                     manual-only User Rules (section 5.3). Not implemented
#                     here to avoid inventing an unverified mechanism.
#
#   --scope=repo   -> runs lib/condense.mjs against this setup's registry/
#                     and writes the condensed result to
#                     .github/copilot-instructions.md in the CURRENT
#                     directory (must be run FROM the target repo — same
#                     convention as setup-repo.sh / tools/claude/enable.sh /
#                     tools/cursor/enable.sh, no path argument).
#
# Usage:
#   tools/copilot/enable.sh --scope=global
#   cd /path/to/target-repo && /path/to/AI-Setup/tools/copilot/enable.sh --scope=repo
#   tools/copilot/enable.sh                 # defaults to --scope=repo
# ============================================================================

set -e

SCOPE="repo"
for arg in "$@"; do
  case "$arg" in
    --scope=global) SCOPE="global" ;;
    --scope=repo) SCOPE="repo" ;;
    -h|--help)
      echo "Usage: tools/copilot/enable.sh [--scope=global|--scope=repo]"
      echo "  --scope=global  No-op: no global scope for Copilot instructions (see capabilities.yaml)"
      echo "  --scope=repo    Render registry/ -> .github/copilot-instructions.md in the current repo [default]"
      exit 0
      ;;
    *)
      echo "tools/copilot/enable.sh: unknown argument '$arg'" >&2
      echo "Usage: tools/copilot/enable.sh [--scope=global|--scope=repo]" >&2
      exit 1
      ;;
  esac
done

# This adapter lives two levels below the setup root (tools/copilot/enable.sh),
# so the setup root is always two directories up from this script's location —
# regardless of the caller's current working directory.
ADAPTER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SETUP_ROOT="$(cd "$ADAPTER_DIR/../.." && pwd)"

if [ "$SCOPE" = "global" ]; then
  echo "tools/copilot/enable.sh: scope=global -> nothing to install."
  echo ""
  echo "Per tools/copilot/capabilities.yaml, instructions have no global scope"
  echo "for Copilot — there is no ~/.github/copilot-instructions.md equivalent."
  echo "Copilot's own personal-instructions feature lives in GitHub account"
  echo "Settings (github.com), not a file this setup can automate."
  echo "The 12 agents + skills + rules only reach a Copilot-enabled repo when"
  echo "'tools/copilot/enable.sh --scope=repo' runs against THAT repo."
  exit 0
fi

TARGET_DIR="$(pwd)"
OUT_FILE="$TARGET_DIR/.github/copilot-instructions.md"

# Read max_instructions_lines from tools/copilot/capabilities.yaml so this
# script never hardcodes a budget that could drift from the declared contract
# (same principle as capabilities.yaml being the single source of truth for
# what each tool supports — section 5.1).
CAPS_FILE="$ADAPTER_DIR/capabilities.yaml"
MAX_LINES="$(grep -E '^max_instructions_lines:' "$CAPS_FILE" | sed 's/^max_instructions_lines:[[:space:]]*//' | sed 's/[[:space:]]*#.*//' | tr -d '[:space:]')"

if [ -z "$MAX_LINES" ]; then
  echo "tools/copilot/enable.sh: could not read max_instructions_lines from $CAPS_FILE" >&2
  exit 1
fi

echo "tools/copilot/enable.sh: scope=repo -> rendering condensed instructions into $OUT_FILE"
echo "(max_instructions_lines=$MAX_LINES, see tools/copilot/capabilities.yaml)"
echo ""

node "$SETUP_ROOT/lib/condense.mjs" \
  --root "$SETUP_ROOT" \
  --max-lines "$MAX_LINES" \
  --tool-name "GitHub Copilot" \
  --out "$OUT_FILE"

echo ""
echo "tools/copilot/enable.sh: done."
