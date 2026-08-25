#!/usr/bin/env bats

# ============================================================================
# test/cursor-hooks.bats — Fase 1.1 acceptance test (update-plan-aug-2026.md)
# ============================================================================
# The plan's acceptance criterion names "beforeShellExecution" as the event
# to test — written before this Fase's own research (see
# tools/cursor/adapt/hook-to-cursor.sh's header, point 1) found that neither
# of this repo's actual hooks matches Shell commands: both match Write/Edit,
# and Cursor's only event that can BLOCK a write before it happens is the
# generic `preToolUse` (matcher: tool name), not a granular
# beforeShellExecution/beforeFileEdit. This suite tests the real wiring
# (preToolUse + Write) instead of the literal event name from the plan's
# context block — see the Fase 1 Bitácora entry for the full reasoning.
# ============================================================================

setup() {
  AI_SETUP_ROOT="$(cd "$(dirname "$BATS_TEST_DIRNAME")" && pwd)"
  TARGET_DIR="$(mktemp -d)"
  cd "$TARGET_DIR"
  git init -q
  bash "$AI_SETUP_ROOT/setup-repo.sh" >/dev/null
}

teardown() {
  cd "$AI_SETUP_ROOT"
  rm -rf "$TARGET_DIR"
}

find_python() {
  for candidate in python3 python py; do
    if command -v "$candidate" &>/dev/null; then
      echo "$candidate"
      return 0
    fi
  done
  return 1
}

@test "setup-repo.sh generates a structurally valid .cursor/hooks.json (schema v1)" {
  [ -f "$TARGET_DIR/.cursor/hooks.json" ]
  [ -f "$TARGET_DIR/.cursor/hooks/_bridge.sh" ]

  PY="$(find_python)"
  "$PY" - "$TARGET_DIR/.cursor/hooks.json" <<'PYEOF'
import json, sys
with open(sys.argv[1]) as fh:
    data = json.load(fh)
assert data["version"] == 1, "version must be 1"
assert "hooks" in data and isinstance(data["hooks"], dict)
for event_key, entries in data["hooks"].items():
    assert isinstance(entries, list) and len(entries) > 0, f"{event_key} must be a non-empty array"
    for entry in entries:
        for required in ("command", "matcher", "failClosed"):
            assert required in entry, f"{event_key} entry missing '{required}': {entry}"
        assert isinstance(entry["failClosed"], bool)
        assert entry["command"].startswith("bash .cursor/hooks/_bridge.sh ")
print("schema OK")
PYEOF
}

@test "preToolUse entry has failClosed=true (security hook) and postToolUse has failClosed=false" {
  PY="$(find_python)"
  "$PY" - "$TARGET_DIR/.cursor/hooks.json" <<'PYEOF'
import json, sys
with open(sys.argv[1]) as fh:
    data = json.load(fh)
pre = data["hooks"]["preToolUse"][0]
post = data["hooks"]["postToolUse"][0]
assert pre["failClosed"] is True, "block-secrets.sh (pre-tool-use) must fail closed"
assert post["failClosed"] is False, "lint-after-write.sh (post-tool-use, non-blocking) must not fail closed"
assert pre["matcher"] == "Write"
assert post["matcher"] == "Write"
PYEOF
}

@test "the bridge denies a Write containing a secret pattern (permission:deny, exit 2)" {
  cd "$TARGET_DIR"
  payload='{"tool_name":"Write","tool_input":{"file_path":"config.py","content":"AKIAABCDEFGHIJKLMNOP"}}'
  run bash -c "echo '$payload' | bash .cursor/hooks/_bridge.sh .claude/hooks/pre-tool-use/block-secrets.sh"

  [ "$status" -eq 2 ]
  [[ "$output" == *'"permission":"deny"'* ]]
}

@test "the bridge denies a Write targeting a real .env file (permission:deny, exit 2)" {
  cd "$TARGET_DIR"
  payload='{"tool_name":"Write","tool_input":{"file_path":".env","content":"FOO=bar"}}'
  run bash -c "echo '$payload' | bash .cursor/hooks/_bridge.sh .claude/hooks/pre-tool-use/block-secrets.sh"

  [ "$status" -eq 2 ]
  [[ "$output" == *'"permission":"deny"'* ]]
}

@test "the bridge allows a clean Write (permission:allow, exit 0, stdout has no debug text)" {
  cd "$TARGET_DIR"
  payload='{"tool_name":"Write","tool_input":{"file_path":"app.py","content":"print(1)"}}'
  run bash -c "echo '$payload' | bash .cursor/hooks/_bridge.sh .claude/hooks/pre-tool-use/block-secrets.sh 2>/dev/null"

  [ "$status" -eq 0 ]
  [ "$output" = '{"permission":"allow"}' ]
}

@test "the bridge allows a non-matched tool (Read) without touching the underlying hook's file logic" {
  cd "$TARGET_DIR"
  payload='{"tool_name":"Read","tool_input":{"file_path":"config.py"}}'
  run bash -c "echo '$payload' | bash .cursor/hooks/_bridge.sh .claude/hooks/pre-tool-use/block-secrets.sh 2>/dev/null"

  [ "$status" -eq 0 ]
  [ "$output" = '{"permission":"allow"}' ]
}

@test "the postToolUse bridge (lint-after-write.sh) always allows and keeps stdout to clean JSON" {
  cd "$TARGET_DIR"
  payload='{"tool_name":"Write","tool_input":{"file_path":"app.py","content":"print(1)"}}'
  run bash -c "echo '$payload' | bash .cursor/hooks/_bridge.sh .claude/hooks/post-tool-use/lint-after-write.sh 2>/dev/null"

  [ "$status" -eq 0 ]
  [ "$output" = '{"permission":"allow"}' ]
}
