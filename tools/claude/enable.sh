#!/bin/bash

# ============================================================================
# tools/claude/enable.sh — Claude Code adapter (Fase 2, AI-SETUP-PLAN-v2.md)
# ============================================================================
# Thin wrapper around the existing install.sh (global scope) and setup-repo.sh
# (per-repo scope) logic. Does NOT reimplement that logic — it delegates to it,
# so this adapter cannot drift from what install.sh/setup-repo.sh actually do.
#
# What "enabling Claude" means today, per tools/claude/capabilities.yaml:
#   --scope=global -> installs the 12 agents + 12 skills to ~/.claude/
#                     (delegates to install.sh)
#   --scope=repo   -> copies scripts, native git hooks (.githooks/), GitHub
#                     Actions workflows,
#                     AGENTS.md, .mcp.json, .claude/rules/, .claude/hooks/,
#                     .claude/settings.json into the CURRENT directory
#                     (delegates to setup-repo.sh — must be run FROM the
#                     target repo, exactly like setup-repo.sh itself)
#
# Usage:
#   tools/claude/enable.sh --scope=global
#   cd /path/to/target-repo && /path/to/AI-Setup/tools/claude/enable.sh --scope=repo
#   tools/claude/enable.sh                 # defaults to --scope=repo
# ============================================================================

set -e

SCOPE="repo"
for arg in "$@"; do
  case "$arg" in
    --scope=global) SCOPE="global" ;;
    --scope=repo) SCOPE="repo" ;;
    -h|--help)
      echo "Usage: tools/claude/enable.sh [--scope=global|--scope=repo]"
      echo "  --scope=global  Install agents+skills to ~/.claude/ (wraps install.sh)"
      echo "  --scope=repo    Set up the current repo (wraps setup-repo.sh) [default]"
      exit 0
      ;;
    *)
      echo "tools/claude/enable.sh: unknown argument '$arg'" >&2
      echo "Usage: tools/claude/enable.sh [--scope=global|--scope=repo]" >&2
      exit 1
      ;;
  esac
done

# This adapter lives two levels below the setup root (tools/claude/enable.sh),
# so the setup root is always two directories up from this script's location —
# regardless of the caller's current working directory.
ADAPTER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SETUP_ROOT="$(cd "$ADAPTER_DIR/../.." && pwd)"

if [ "$SCOPE" = "global" ]; then
  echo "tools/claude/enable.sh: scope=global -> delegating to install.sh"
  echo ""
  bash "$SETUP_ROOT/install.sh"
else
  echo "tools/claude/enable.sh: scope=repo -> delegating to setup-repo.sh"
  echo "(this must run with the TARGET repo as the current directory, same"
  echo " requirement as setup-repo.sh itself — it does not take a path argument)"
  echo ""
  bash "$SETUP_ROOT/setup-repo.sh"
fi
