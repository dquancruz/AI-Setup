#!/usr/bin/env bash

# ============================================================================
# tools/cursor/adapt/hook-to-cursor.sh — registry hooks -> .cursor/hooks.json
# ============================================================================
# Fase 1.1, update-plan-aug-2026.md. Cursor has supported project/user hooks
# since 1.7 via .cursor/hooks.json (schema version 1) — verified against
# https://cursor.com/docs/hooks 2026-08-24 (see docs/tool-compatibility.md
# for the full citation and what was checked). This was NOT reflected in
# tools/cursor/capabilities.yaml or the README's portability table before
# this Fase — see docs/AUDIT-v3.md section 4.
#
# Design decisions (documented here, same convention as agent-to-mode.sh's
# header, since some of this isn't 100% pinned by the docs):
#
# 1. MAPS TO CURSOR'S GENERIC preToolUse/postToolUse EVENTS, not the
#    granular beforeShellExecution/afterFileEdit/beforeReadFile ones the
#    plan's own context block originally suggested. Reason: both of this
#    repo's hooks (block-secrets.sh, lint-after-write.sh) match on
#    Write/Edit/str_replace_editor tool calls via tools/claude/settings.json
#    — that's a *tool-type* match, which is exactly what the generic
#    preToolUse/postToolUse events filter on (confirmed: "fires for all
#    tool types (Shell, Read, Write, MCP, Task, etc.)", matcher is the tool
#    name). Critically, there is NO granular "beforeFileEdit"/"beforeWrite"
#    event in Cursor's event list — only beforeReadFile (pre-READ) and
#    afterFileEdit (POST-edit, too late to block a write). The generic
#    preToolUse event is the only Cursor mechanism that can actually block a
#    Write before it lands on disk, which is block-secrets.sh's entire job.
#
# 2. NO PAYLOAD TRANSFORMATION in the bridge (tools/cursor/adapt/hook-bridge.sh)
#    — Cursor's preToolUse/postToolUse payload is documented as `tool_name`
#    + `tool_input`, the same field names registry/hooks/*.sh scripts
#    already parse (they were written to accept Claude Code's real schema).
#    Field names WITHIN tool_input for a Write call specifically (e.g.
#    whether it's `file_path`/`content` or something else) are NOT pinned by
#    Cursor's public docs as of this check — registry/hooks/*.sh already
#    probes multiple plausible field-name variants defensively, which is the
#    best available mitigation without hands-on access to a live Cursor
#    session to confirm. See hook-bridge.sh's header and
#    docs/tool-compatibility.md for the residual verification gap.
#
# 3. TOOL NAME TRANSLATION (Claude matcher -> Cursor matcher): Claude's
#    matcher in tools/claude/settings.json is "Write|Edit|str_replace_editor"
#    (Claude-specific tool names). Cursor's confirmed tool name for file
#    writes is "Write" (its docs list "Shell, Read, Write, Grep, Delete,
#    Task, MCP" — no separate "Edit" or "str_replace_editor" name exists in
#    Cursor). Every Claude tool name in a matcher is translated via
#    CLAUDE_TO_CURSOR_TOOL below and deduplicated; unknown names fall
#    through unchanged (harmless in a pipe-alternation matcher — an unmatched
#    alternative just never matches).
#
# 4. failClosed POLICY (plan: "úsalo SOLO en hooks de seguridad... nunca en
#    formatters o tests"): defaults to true for every registry/hooks/
#    pre-tool-use/*.sh (its whole job is blocking — see 0.2/0.3's audit:
#    block-secrets.sh fails closed by design already) and false for every
#    post-tool-use/*.sh (non-blocking feedback, e.g. lint-after-write.sh).
#    A hook script can override this default with a marker comment anywhere
#    in its own file: `# cursor-fail-closed: true` or `# cursor-fail-closed:
#    false` — read by this script, never hardcoded per filename (the
#    per-filename hardcoding in setup-repo.sh's hook-copy step is a drift
#    risk flagged in docs/AUDIT-v3.md section 3; this script avoids
#    repeating that pattern).
#
# NOT reachable purely in bash/awk/sed like rule-to-mdc.sh / agent-to-mode.sh
# — actually parsing tools/claude/settings.json's JSON needs a real parser.
# Uses python3 (falls back to python/py), same choice registry/hooks/*.sh
# itself already made and already requires — no new dependency introduced.
#
# Usage:
#   hook-to-cursor.sh <ai-setup-root> <target-repo-root>
#
# Example (as called from setup-repo.sh):
#   tools/cursor/adapt/hook-to-cursor.sh "$SETUP_DIR" "$TARGET_DIR"
# ============================================================================

set -e

usage() {
  echo "Usage: hook-to-cursor.sh <ai-setup-root> <target-repo-root>" >&2
  exit 1
}

[ $# -eq 2 ] || usage

SETUP_DIR="$1"
TARGET_DIR="$2"

SETTINGS_JSON="$SETUP_DIR/tools/claude/settings.json"
HOOKS_DIR="$SETUP_DIR/registry/hooks"
BRIDGE_SRC="$SETUP_DIR/tools/cursor/adapt/hook-bridge.sh"

[ -f "$SETTINGS_JSON" ] || { echo "hook-to-cursor.sh: not found: $SETTINGS_JSON" >&2; exit 1; }
[ -f "$BRIDGE_SRC" ] || { echo "hook-to-cursor.sh: not found: $BRIDGE_SRC" >&2; exit 1; }

PYTHON_BIN=""
for candidate in python3 python py; do
  if command -v "$candidate" &>/dev/null; then
    PYTHON_BIN="$candidate"
    break
  fi
done
if [ -z "$PYTHON_BIN" ]; then
  echo "hook-to-cursor.sh: no python3/python/py found in PATH — cannot parse settings.json." >&2
  exit 1
fi

mkdir -p "$TARGET_DIR/.cursor/hooks"
cp "$BRIDGE_SRC" "$TARGET_DIR/.cursor/hooks/_bridge.sh"
chmod +x "$TARGET_DIR/.cursor/hooks/_bridge.sh" 2>/dev/null || true

# --- Build the file list this run needs to cover -----------------------
PRE_FILES=()
if [ -d "$HOOKS_DIR/pre-tool-use" ]; then
  for f in "$HOOKS_DIR"/pre-tool-use/*.sh; do
    [ -f "$f" ] && PRE_FILES+=("$(basename "$f")")
  done
fi
POST_FILES=()
if [ -d "$HOOKS_DIR/post-tool-use" ]; then
  for f in "$HOOKS_DIR"/post-tool-use/*.sh; do
    [ -f "$f" ] && POST_FILES+=("$(basename "$f")")
  done
fi

if [ ${#PRE_FILES[@]} -eq 0 ] && [ ${#POST_FILES[@]} -eq 0 ]; then
  echo "hook-to-cursor.sh: no hook scripts found under $HOOKS_DIR — nothing to render." >&2
  exit 0
fi

# failClosed marker lookup: "# cursor-fail-closed: true|false" anywhere in
# the hook script; empty string if no marker present (caller applies the
# directory-based default in that case).
fail_closed_marker() {
  grep -m1 -oE '# *cursor-fail-closed: *(true|false)' "$1" 2>/dev/null \
    | grep -oE 'true|false' || true
}

# --- Delegate the actual JSON assembly to python -------------------------
# Passed as: event_name matcher_source_json_path pre/post file list, via
# env vars (simpler than escaping through argv for a small embedded script).
export SETTINGS_JSON
PRE_FILES_CSV="$(IFS=,; echo "${PRE_FILES[*]:-}")"
export PRE_FILES_CSV
POST_FILES_CSV="$(IFS=,; echo "${POST_FILES[*]:-}")"
export POST_FILES_CSV

# Per-file failClosed overrides, passed as "name=true,name=false,..."
build_overrides_csv() {
  local dir="$1"; shift
  local out=()
  for name in "$@"; do
    local marker
    marker="$(fail_closed_marker "$dir/$name")"
    [ -n "$marker" ] && out+=("$name=$marker")
  done
  local IFS=,
  echo "${out[*]:-}"
}
PRE_OVERRIDES_CSV="$(build_overrides_csv "$HOOKS_DIR/pre-tool-use" "${PRE_FILES[@]:-}")"
export PRE_OVERRIDES_CSV
POST_OVERRIDES_CSV="$(build_overrides_csv "$HOOKS_DIR/post-tool-use" "${POST_FILES[@]:-}")"
export POST_OVERRIDES_CSV

"$PYTHON_BIN" - "$TARGET_DIR/.cursor/hooks.json" <<'PYEOF'
import json, os, sys

settings_path = os.environ["SETTINGS_JSON"]
pre_files = [f for f in os.environ.get("PRE_FILES_CSV", "").split(",") if f]
post_files = [f for f in os.environ.get("POST_FILES_CSV", "").split(",") if f]

def parse_overrides(csv):
    out = {}
    for pair in csv.split(","):
        if not pair or "=" not in pair:
            continue
        name, val = pair.split("=", 1)
        out[name] = (val == "true")
    return out

pre_overrides = parse_overrides(os.environ.get("PRE_OVERRIDES_CSV", ""))
post_overrides = parse_overrides(os.environ.get("POST_OVERRIDES_CSV", ""))

with open(settings_path, "r", encoding="utf-8") as fh:
    settings = json.load(fh)

# Claude Code tool name -> Cursor tool name. Unknown names pass through
# unchanged (harmless in a pipe-alternation matcher).
CLAUDE_TO_CURSOR_TOOL = {
    "Write": "Write",
    "Edit": "Write",
    "str_replace_editor": "Write",
    "Bash": "Shell",
    "Read": "Read",
}

def translate_matcher(claude_matcher):
    if not claude_matcher:
        return None
    names = claude_matcher.split("|")
    translated = []
    for n in names:
        n = n.strip()
        if not n:
            continue
        cursor_name = CLAUDE_TO_CURSOR_TOOL.get(n, n)
        if cursor_name not in translated:
            translated.append(cursor_name)
    return "|".join(translated) if translated else None

def matcher_for(basename_to_find, claude_event_key):
    """Find the matcher in settings.json's PreToolUse/PostToolUse array
    whose 'hooks[].command' references basename_to_find."""
    for entry in settings.get("hooks", {}).get(claude_event_key, []):
        matcher = entry.get("matcher", "")
        for h in entry.get("hooks", []):
            command = h.get("command", "")
            if basename_to_find in command:
                return translate_matcher(matcher)
    return None

def build_events(files, claude_event_key, subdir, default_fail_closed, overrides):
    events = []
    for name in files:
        matcher = matcher_for(name, claude_event_key)
        if matcher is None:
            print(
                f"hook-to-cursor.sh: WARNING — {subdir}/{name} has no matcher "
                f"registered in {settings_path} ({claude_event_key}); this hook "
                f"exists in registry/hooks/ but is not wired up for Claude Code "
                f"either (see docs/AUDIT-v3.md section 3's drift-risk finding). "
                f"Skipping it for Cursor too rather than guessing a matcher.",
                file=sys.stderr,
            )
            continue
        fail_closed = overrides.get(name, default_fail_closed)
        events.append({
            "command": f"bash .cursor/hooks/_bridge.sh .claude/hooks/{subdir}/{name}",
            "matcher": matcher,
            "failClosed": fail_closed,
        })
    return events

pre_events = build_events(pre_files, "PreToolUse", "pre-tool-use", True, pre_overrides)
post_events = build_events(post_files, "PostToolUse", "post-tool-use", False, post_overrides)

out = {"version": 1, "hooks": {}}
if pre_events:
    out["hooks"]["preToolUse"] = pre_events
if post_events:
    out["hooks"]["postToolUse"] = post_events

out_path = sys.argv[1]
with open(out_path, "w", encoding="utf-8") as fh:
    json.dump(out, fh, indent=2)
    fh.write("\n")

print(f"hook-to-cursor.sh: wrote {out_path} "
      f"({len(pre_events)} preToolUse, {len(post_events)} postToolUse)")
PYEOF
