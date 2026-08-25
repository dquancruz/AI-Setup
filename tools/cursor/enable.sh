#!/bin/bash

# ============================================================================
# tools/cursor/enable.sh — Cursor adapter (Fase 3, AI-SETUP-PLAN-v2.md)
# ============================================================================
# Same thin-wrapper style as tools/claude/enable.sh, but Cursor's actual
# capabilities are different (see tools/cursor/capabilities.yaml) — per
# AI-SETUP-PLAN-v2.md section 5.3, Cursor has NO global scope for agents or
# skills (Custom Modes and skills are project-scoped only; there is no
# ~/.cursor/ equivalent for them). This script does not invent one.
#
# What "enabling Cursor" means today:
#
#   --scope=global -> nothing real to install for agents/skills (see below).
#                     MCP does have a real global scope (~/.cursor/mcp.json)
#                     but wiring that up is Fase 5's generalized
#                     install-global.sh, not this adapter — not implemented
#                     here to avoid a one-off special case.
#
#   --scope=repo   -> renders registry/rules/*.md  -> .cursor/rules/*.mdc
#                     and registry/agents/*.md     -> .cursor/modes/*.md
#                     into the CURRENT directory (must be run FROM the
#                     target repo — same convention as setup-repo.sh /
#                     tools/claude/enable.sh, no path argument).
#                     AGENTS.md and .mcp.json are tool-agnostic and already
#                     handled by setup-repo.sh — not duplicated here.
#
# Usage:
#   tools/cursor/enable.sh --scope=global
#   cd /path/to/target-repo && /path/to/AI-Setup/tools/cursor/enable.sh --scope=repo
#   tools/cursor/enable.sh                 # defaults to --scope=repo
# ============================================================================

set -e

SCOPE="repo"
for arg in "$@"; do
  case "$arg" in
    --scope=global) SCOPE="global" ;;
    --scope=repo) SCOPE="repo" ;;
    -h|--help)
      echo "Usage: tools/cursor/enable.sh [--scope=global|--scope=repo]"
      echo "  --scope=global  No-op: agents/skills have no global scope in Cursor (see capabilities.yaml)"
      echo "  --scope=repo    Render rules + agent Custom Modes into the current repo [default]"
      exit 0
      ;;
    *)
      echo "tools/cursor/enable.sh: unknown argument '$arg'" >&2
      echo "Usage: tools/cursor/enable.sh [--scope=global|--scope=repo]" >&2
      exit 1
      ;;
  esac
done

# This adapter lives two levels below the setup root (tools/cursor/enable.sh),
# so the setup root is always two directories up from this script's location —
# regardless of the caller's current working directory.
ADAPTER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SETUP_ROOT="$(cd "$ADAPTER_DIR/../.." && pwd)"

if [ "$SCOPE" = "global" ]; then
  echo "tools/cursor/enable.sh: scope=global -> nothing to install."
  echo ""
  echo "Per tools/cursor/capabilities.yaml, agents and skills have no global"
  echo "scope in Cursor — Custom Modes live in a per-project .cursor/modes/"
  echo "and skills live in a per-project .cursor/skills/; there is no"
  # shellcheck disable=SC2088 # literal doc text — "~/.cursor/..." is not meant to expand
  echo "~/.cursor/ equivalent for either. They are installed per-repo via"
  echo "'tools/cursor/enable.sh --scope=repo' (or setup-repo.sh) instead."
  echo ""
  # shellcheck disable=SC2088 # literal doc text — "~/.cursor/mcp.json" is not meant to expand
  echo "MCP does have a real global scope (~/.cursor/mcp.json) but wiring it"
  echo "up is left to Fase 5's generalized install-global.sh, not this script."
  exit 0
fi

TARGET_DIR="$(pwd)"

echo "tools/cursor/enable.sh: scope=repo -> rendering rules + agent Custom Modes into $TARGET_DIR"
echo ""

mkdir -p "$TARGET_DIR/.cursor/rules"
bash "$ADAPTER_DIR/adapt/rule-to-mdc.sh" "$SETUP_ROOT/registry/rules" "$TARGET_DIR/.cursor/rules"

mkdir -p "$TARGET_DIR/.cursor/modes"
bash "$ADAPTER_DIR/adapt/agent-to-mode.sh" "$SETUP_ROOT/registry/agents" "$TARGET_DIR/.cursor/modes"

bash "$ADAPTER_DIR/adapt/hook-to-cursor.sh" "$SETUP_ROOT" "$TARGET_DIR"

echo ""
echo "tools/cursor/enable.sh: done."
