#!/usr/bin/env bats

# ============================================================================
# test/build-plugins.bats — smoke test for tools/claude/build-plugins.sh (Fase 3)
# ============================================================================
# The "happy path" tests run against the real AI-Setup repo tree, same
# precedent as test/install.bats: build-plugins.sh's whole job is to produce
# plugins/ and .claude-plugin/marketplace.json AS COMMITTED FILES in this
# repo (see build-plugins.sh's header for why that's an intentional
# exception to the usual "nothing generated is committed" rule), so there is
# no throwaway target dir to redirect into — the real output IS the thing
# under test.
#
# The "packs.yaml is out of sync with registry/" error-path tests build a
# small isolated fake root instead, so they can exercise a broken manifest
# without ever touching the real registry/.
# ============================================================================

setup() {
  AI_SETUP_ROOT="$(cd "$(dirname "$BATS_TEST_DIRNAME")" && pwd)"
  BUILD_PLUGINS_SH="$AI_SETUP_ROOT/tools/claude/build-plugins.sh"
  PYTHON_BIN=""
  for candidate in python3 python py; do
    if command -v "$candidate" &>/dev/null; then
      PYTHON_BIN="$candidate"
      break
    fi
  done
}

# --- Fake-root helper for the error-path tests -----------------------------
make_fake_root() {
  local root="$1"
  mkdir -p "$root/registry/agents" "$root/registry/skills/only-skill"
  cat > "$root/registry/agents/only-agent.md" <<'EOF'
---
name: only-agent
description: fixture agent
tools: Read
tier: core
---
fixture
EOF
  cat > "$root/registry/skills/only-skill/SKILL.md" <<'EOF'
---
name: only-skill
description: fixture skill
tier: core
---
fixture
EOF
}

@test "build-plugins.sh generates one plugin dir per pack in registry/packs.yaml" {
  bash "$BUILD_PLUGINS_SH" "$AI_SETUP_ROOT"
  while IFS= read -r pack; do
    [ -f "$AI_SETUP_ROOT/plugins/$pack/.claude-plugin/plugin.json" ]
  done < <(grep -oE '^[a-z0-9_-]+:\s*$' "$AI_SETUP_ROOT/registry/packs.yaml" | sed 's/:.*//')
}

@test "build-plugins.sh generates a valid .claude-plugin/marketplace.json listing every pack" {
  bash "$BUILD_PLUGINS_SH" "$AI_SETUP_ROOT"
  marketplace="$AI_SETUP_ROOT/.claude-plugin/marketplace.json"
  [ -f "$marketplace" ]

  "$PYTHON_BIN" - "$marketplace" "$AI_SETUP_ROOT/registry/packs.yaml" <<'PYEOF'
import json, re, sys
marketplace_path, packs_yaml_path = sys.argv[1], sys.argv[2]
with open(marketplace_path, encoding="utf-8") as fh:
    m = json.load(fh)
assert m["name"] == "ai-setup"
assert "owner" in m and "name" in m["owner"]
listed = {p["name"] for p in m["plugins"]}
for p in m["plugins"]:
    assert p["source"] == f"./plugins/{p['name']}"
with open(packs_yaml_path, encoding="utf-8") as fh:
    expected = set(re.findall(r'^([a-z0-9_-]+):\s*$', fh.read(), re.MULTILINE))
assert listed == expected, f"marketplace lists {listed}, packs.yaml defines {expected}"
PYEOF
}

@test "build-plugins.sh copies every registry agent into exactly one plugin, verbatim" {
  bash "$BUILD_PLUGINS_SH" "$AI_SETUP_ROOT"
  for f in "$AI_SETUP_ROOT"/registry/agents/*.md; do
    name="$(basename "$f")"
    matches=$(find "$AI_SETUP_ROOT/plugins" -path "*/agents/$name")
    count=$(echo "$matches" | grep -c .)
    [ "$count" -eq 1 ]
    diff "$f" "$matches"
  done
}

@test "build-plugins.sh copies every registry skill into exactly one plugin, verbatim" {
  bash "$BUILD_PLUGINS_SH" "$AI_SETUP_ROOT"
  for d in "$AI_SETUP_ROOT"/registry/skills/*/; do
    name="$(basename "$d")"
    [ -f "$d/SKILL.md" ] || continue
    matches=$(find "$AI_SETUP_ROOT/plugins" -path "*/skills/$name/SKILL.md")
    count=$(echo "$matches" | grep -c .)
    [ "$count" -eq 1 ]
    diff "$d/SKILL.md" "$matches"
  done
}

@test "build-plugins.sh is reproducible: running it twice produces the same tree" {
  bash "$BUILD_PLUGINS_SH" "$AI_SETUP_ROOT" >/dev/null
  hash1=$(find "$AI_SETUP_ROOT/plugins" "$AI_SETUP_ROOT/.claude-plugin" -type f | sort | xargs sha256sum | sha256sum)
  bash "$BUILD_PLUGINS_SH" "$AI_SETUP_ROOT" >/dev/null
  hash2=$(find "$AI_SETUP_ROOT/plugins" "$AI_SETUP_ROOT/.claude-plugin" -type f | sort | xargs sha256sum | sha256sum)
  [ "$hash1" = "$hash2" ]
}

@test "build-plugins.sh fails loudly when packs.yaml omits an agent that exists in registry/" {
  fake_root="$(mktemp -d)"
  make_fake_root "$fake_root"
  cat > "$fake_root/registry/packs.yaml" <<'EOF'
some-pack:
  description: "fixture pack, missing only-agent on purpose"
  agents: []
  skills:
    - only-skill
EOF
  run bash "$BUILD_PLUGINS_SH" "$fake_root"
  [ "$status" -ne 0 ]
  [[ "$output" == *"only-agent"* ]]
  rm -rf "$fake_root"
}

@test "build-plugins.sh fails loudly when the same agent is listed in two packs" {
  fake_root="$(mktemp -d)"
  make_fake_root "$fake_root"
  cat > "$fake_root/registry/packs.yaml" <<'EOF'
pack-a:
  description: "fixture pack A"
  agents:
    - only-agent
  skills: []
pack-b:
  description: "fixture pack B, duplicates only-agent on purpose"
  agents:
    - only-agent
  skills:
    - only-skill
EOF
  run bash "$BUILD_PLUGINS_SH" "$fake_root"
  [ "$status" -ne 0 ]
  [[ "$output" == *"only-agent"* ]]
  rm -rf "$fake_root"
}

@test "build-plugins.sh fails loudly when a pack references a skill that doesn't exist in registry/" {
  fake_root="$(mktemp -d)"
  make_fake_root "$fake_root"
  cat > "$fake_root/registry/packs.yaml" <<'EOF'
some-pack:
  description: "fixture pack referencing a nonexistent skill"
  agents:
    - only-agent
  skills:
    - does-not-exist
EOF
  run bash "$BUILD_PLUGINS_SH" "$fake_root"
  [ "$status" -ne 0 ]
  [[ "$output" == *"does-not-exist"* ]]
  rm -rf "$fake_root"
}
