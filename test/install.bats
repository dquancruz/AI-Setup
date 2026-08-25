#!/usr/bin/env bats

# ============================================================================
# test/install.bats — smoke test for install.sh (Fase 0.2)
# ============================================================================
# install.sh assumes CWD = the AI-Setup repo root (its cp targets are
# relative: `registry/agents/*.md`, not $SETUP_DIR-derived) — so every run
# below stays cd'd into the real repo root and only redirects $HOME to a
# throwaway directory. Never touches the real ~/.claude.
# ============================================================================

setup() {
  AI_SETUP_ROOT="$(cd "$(dirname "$BATS_TEST_DIRNAME")" && pwd)"
  TEST_HOME="$(mktemp -d)"
}

teardown() {
  rm -rf "$TEST_HOME"
}

@test "install.sh creates ~/.claude/agents with one .md per registry/agents/*.md" {
  cd "$AI_SETUP_ROOT"
  HOME="$TEST_HOME" bash install.sh

  expected_count=$(ls registry/agents/*.md | wc -l)
  actual_count=$(ls "$TEST_HOME/.claude/agents"/*.md | wc -l)
  [ "$actual_count" -eq "$expected_count" ]

  for f in registry/agents/*.md; do
    name="$(basename "$f")"
    [ -f "$TEST_HOME/.claude/agents/$name" ]
  done
}

@test "install.sh creates ~/.claude/skills/<name>/SKILL.md for every registry/skills/*/" {
  cd "$AI_SETUP_ROOT"
  HOME="$TEST_HOME" bash install.sh

  for d in registry/skills/*/; do
    name="$(basename "$d")"
    [ -f "$TEST_HOME/.claude/skills/$name/SKILL.md" ]
    diff "$d/SKILL.md" "$TEST_HOME/.claude/skills/$name/SKILL.md"
  done
}

@test "install.sh backs up an existing ~/.claude/agents instead of silently overwriting" {
  mkdir -p "$TEST_HOME/.claude/agents"
  echo "pre-existing-marker" > "$TEST_HOME/.claude/agents/stale-agent.md"

  cd "$AI_SETUP_ROOT"
  HOME="$TEST_HOME" bash install.sh

  # A timestamped backup dir must exist and must contain the marker file.
  backup_dir=$(ls -d "$TEST_HOME/.claude/agents-backup-"* 2>/dev/null | head -1)
  [ -n "$backup_dir" ]
  [ -f "$backup_dir/stale-agent.md" ]
  grep -q "pre-existing-marker" "$backup_dir/stale-agent.md"
}

@test "install.sh is idempotent: running it twice produces the same agents/skills tree" {
  cd "$AI_SETUP_ROOT"
  HOME="$TEST_HOME" bash install.sh >/dev/null

  hash1=$(find "$TEST_HOME/.claude/agents" "$TEST_HOME/.claude/skills" -type f | sort | xargs sha256sum | sha256sum)

  # Second run backs up the first run's output into a new timestamped dir —
  # that backup dir must not be part of what we compare, so we hash only
  # agents/ and skills/ (not agents-backup-*/skills-backup-*).
  HOME="$TEST_HOME" bash install.sh >/dev/null
  hash2=$(find "$TEST_HOME/.claude/agents" "$TEST_HOME/.claude/skills" -type f | sort | xargs sha256sum | sha256sum)

  [ "$hash1" = "$hash2" ]
}
