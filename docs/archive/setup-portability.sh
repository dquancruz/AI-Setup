#!/usr/bin/env bash
# ============================================================================
# ARCHIVED — retired in Fase 2 of update-plan-aug-2026.md (2026-08-24).
# ============================================================================
# This script (and the "Cross-tool portability" manual step it required)
# no longer runs anywhere in this repo. It existed because symlinks are
# fragile on Windows without Developer Mode/admin rights, and the fallback
# below papered over that with silent one-time copies.
#
# The actual fix: both Claude Code and Gemini CLI support `@path` file
# imports natively (verified 2026-08-24 — see docs/tool-compatibility.md's
# verification log). A one-line `CLAUDE.md`/`GEMINI.md` containing exactly
# `@AGENTS.md` works identically on every platform, with no symlink and no
# Windows fallback branch needed at all — better than this script's own
# Windows workaround, not just a replacement for it.
# `.github/copilot-instructions.md` was ALSO wrong here — this script
# symlinked it straight to AGENTS.md, silently bypassing the condensed,
# budget-capped rendering `lib/condense.mjs` / `tools/copilot/enable.sh`
# already existed to produce (found while retiring this script, not
# previously caught). `.cursor/mcp.json` is now a real copy (Cursor doesn't
# read a root `.mcp.json`, confirmed the same session), regenerated on every
# `setup-repo.sh` run instead of symlinked once.
#
# See `registry/templates/CLAUDE.md`, `registry/templates/GEMINI.md`, and
# `setup-repo.sh`'s "2c1"/"2d2"/"2i" steps for what replaced this. Kept here,
# unmodified below this notice, as a historical record only — do not run it,
# do not copy it back into `registry/templates/`.
# ============================================================================
#
# Generates the symlinks that point to the SSOT (AGENTS.md).
# Run from the root of the target repo where AGENTS.md already exists.
set -euo pipefail

[ -f AGENTS.md ] || { echo "❌ AGENTS.md is missing (the SSOT). Create it first from the template."; exit 1; }

# On Windows/MSYS, plain `ln -s` can silently create a regular-file COPY
# instead of a real symlink when the user lacks Developer Mode / admin
# privileges — no error, no warning, just silent drift the moment AGENTS.md
# is next edited. winsymlinks:nativestrict makes `ln -s` attempt a real NTFS
# symlink and fail loudly instead, so the fallback below can detect it and
# warn explicitly rather than pretending it worked.
export MSYS="${MSYS:-}${MSYS:+ }winsymlinks:nativestrict"

FELL_BACK=0

link() {
  local target="$1" linkname="$2"
  rm -f "$linkname"
  if ln -sf "$target" "$linkname" 2>/dev/null && [ -L "$linkname" ]; then
    return 0
  fi
  # Not a real symlink (unsupported platform, or Windows without Developer
  # Mode/admin rights) — fall back to a one-time copy so setup still
  # succeeds, but make it very clear this copy will NOT stay in sync.
  # $target is relative to $linkname's own directory (same convention as
  # `ln -s`), so resolve it from there rather than from the script's cwd.
  rm -f "$linkname"
  cp "$(dirname "$linkname")/$target" "$linkname"
  FELL_BACK=1
}

link AGENTS.md CLAUDE.md
link AGENTS.md GEMINI.md
mkdir -p .github
link ../AGENTS.md .github/copilot-instructions.md
mkdir -p .cursor
if [ -f .mcp.json ]; then
  link ../.mcp.json .cursor/mcp.json
fi

echo "✅ CLAUDE.md, GEMINI.md, .github/copilot-instructions.md → AGENTS.md"
if [ -f .mcp.json ]; then
  echo "✅ .cursor/mcp.json → ../.mcp.json"
fi
echo ""
echo "ℹ️  Cursor and Codex read AGENTS.md directly (no instructions symlink needed)."

if [ "$FELL_BACK" = "1" ]; then
  echo ""
  echo "⚠️  This environment would not create real symlinks (Windows without"
  echo "   Developer Mode or admin rights falls back to this). The files above"
  echo "   are one-time COPIES, not live links — editing AGENTS.md will NOT"
  echo "   update them automatically."
  echo "   Re-run this script after every AGENTS.md edit, OR enable Windows"
  echo "   Developer Mode (Settings → Privacy & security → For developers) and"
  echo "   re-run this script once to upgrade these to real symlinks."
fi
