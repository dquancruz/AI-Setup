#!/usr/bin/env bash
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
