#!/usr/bin/env bats

# ============================================================================
# test/setup-repo.bats — smoke test for setup-repo.sh (Fase 0.2)
# ============================================================================
# setup-repo.sh locates its own source tree via BASH_SOURCE, so it can be
# invoked by absolute path from anywhere. Each test builds a throwaway git
# repo under a temp dir and runs the real setup-repo.sh against it — nothing
# here touches the AI-Setup repo itself.
# ============================================================================

setup() {
  AI_SETUP_ROOT="$(cd "$(dirname "$BATS_TEST_DIRNAME")" && pwd)"
  SETUP_REPO_SH="$AI_SETUP_ROOT/setup-repo.sh"
  TARGET_DIR="$(mktemp -d)"
  cd "$TARGET_DIR"
  git init -q
  # setup-repo.sh's Node-detection branch only changes echoed instructions,
  # not files written — no package.json needed for these tests.
}

teardown() {
  cd "$AI_SETUP_ROOT"
  rm -rf "$TARGET_DIR"
}

tree_hash() {
  # Content + path hash, excluding .git — same recipe update-plan-aug-2026.md
  # 0.2 specifies (find | sort + sha256sum).
  find "$TARGET_DIR" -type f -not -path '*/.git/*' | sort | xargs sha256sum | sha256sum
}

@test "setup-repo.sh refuses to run outside a git repo" {
  non_git_dir="$(mktemp -d)"
  cd "$non_git_dir"
  run bash "$SETUP_REPO_SH"
  [ "$status" -ne 0 ]
  rm -rf "$non_git_dir"
}

@test "setup-repo.sh creates every destination the README's 'What goes where' table declares" {
  bash "$SETUP_REPO_SH" >/dev/null

  [ -d "$TARGET_DIR/scripts" ]
  for f in "$AI_SETUP_ROOT"/registry/scripts/*.js; do
    [ -f "$TARGET_DIR/scripts/$(basename "$f")" ]
  done

  [ -f "$TARGET_DIR/.husky/pre-commit" ]
  [ -f "$TARGET_DIR/.husky/prepare-commit-msg" ]
  [ -f "$TARGET_DIR/.husky/post-merge" ]
  [ -f "$TARGET_DIR/.husky/pre-tag" ]

  [ -f "$TARGET_DIR/.github/workflows/pr-validation.yml" ]
  [ -f "$TARGET_DIR/.github/workflows/on-merge.yml" ]

  [ -f "$TARGET_DIR/AGENTS.md" ]
  [ -f "$TARGET_DIR/.mcp.json" ]
  [ -f "$TARGET_DIR/.env.local" ]
  [ -f "$TARGET_DIR/setup-portability.sh" ]

  [ -d "$TARGET_DIR/.local-docs" ]
  [ -f "$TARGET_DIR/.local-docs/plan.md" ]
  [ -f "$TARGET_DIR/.local-docs/architecture.md" ]
  [ -f "$TARGET_DIR/.local-docs/security-gaps.md" ]
  [ -f "$TARGET_DIR/.local-docs/decisions.md" ]

  for f in "$AI_SETUP_ROOT"/registry/rules/*.md; do
    [ -f "$TARGET_DIR/.claude/rules/$(basename "$f")" ]
    [ -f "$TARGET_DIR/.cursor/rules/$(basename "$f" .md).mdc" ]
  done

  [ -f "$TARGET_DIR/.claude/hooks/pre-tool-use/block-secrets.sh" ]
  [ -f "$TARGET_DIR/.claude/hooks/post-tool-use/lint-after-write.sh" ]
  [ -f "$TARGET_DIR/.claude/settings.json" ]

  grep -q "^\.env\.local$" "$TARGET_DIR/.gitignore"
  grep -q "^\.local-docs/$" "$TARGET_DIR/.gitignore"
}

@test "setup-repo.sh is idempotent: running it twice produces the same tree" {
  bash "$SETUP_REPO_SH" >/dev/null
  hash1=$(tree_hash)

  bash "$SETUP_REPO_SH" >/dev/null
  hash2=$(tree_hash)

  [ "$hash1" = "$hash2" ]
}

@test "setup-repo.sh does not overwrite an existing .mcp.json" {
  echo '{"marker":"do-not-touch"}' > "$TARGET_DIR/.mcp.json"
  bash "$SETUP_REPO_SH" >/dev/null
  grep -q "do-not-touch" "$TARGET_DIR/.mcp.json"
}

@test "setup-repo.sh does not overwrite an existing .claude/settings.json" {
  mkdir -p "$TARGET_DIR/.claude"
  echo '{"marker":"do-not-touch"}' > "$TARGET_DIR/.claude/settings.json"
  bash "$SETUP_REPO_SH" >/dev/null
  grep -q "do-not-touch" "$TARGET_DIR/.claude/settings.json"
}

@test "setup-repo.sh does not overwrite an existing .env.local" {
  echo "MARKER=do-not-touch" > "$TARGET_DIR/.env.local"
  bash "$SETUP_REPO_SH" >/dev/null
  grep -q "do-not-touch" "$TARGET_DIR/.env.local"
}

@test "setup-repo.sh does not overwrite an existing .local-docs/" {
  mkdir -p "$TARGET_DIR/.local-docs"
  echo "do-not-touch" > "$TARGET_DIR/.local-docs/plan.md"
  bash "$SETUP_REPO_SH" >/dev/null
  grep -q "do-not-touch" "$TARGET_DIR/.local-docs/plan.md"
  # And no sibling starter file (e.g. architecture.md) was added into an
  # existing .local-docs/ either — the whole folder is left alone, not
  # merged file-by-file.
  [ ! -f "$TARGET_DIR/.local-docs/architecture.md" ]
}

@test "setup-repo.sh appends missing lines to an existing AGENTS.md without rewriting prior content" {
  cat > "$TARGET_DIR/AGENTS.md" <<'EOF'
# My Project

Custom project-specific content that must survive untouched.
EOF

  bash "$SETUP_REPO_SH" >/dev/null

  grep -q "Custom project-specific content that must survive untouched." "$TARGET_DIR/AGENTS.md"
  grep -q "Commit/PR style:" "$TARGET_DIR/AGENTS.md"
  grep -q "\.local-docs/" "$TARGET_DIR/AGENTS.md"

  # First line of the original content is still the first line of the file —
  # "append-only" means nothing was inserted before it.
  first_line=$(head -1 "$TARGET_DIR/AGENTS.md")
  [ "$first_line" = "# My Project" ]
}

@test "setup-repo.sh does not double-append AGENTS.md lines on a second run" {
  cat > "$TARGET_DIR/AGENTS.md" <<'EOF'
# My Project
EOF
  bash "$SETUP_REPO_SH" >/dev/null
  bash "$SETUP_REPO_SH" >/dev/null

  count=$(grep -c "Commit/PR style:" "$TARGET_DIR/AGENTS.md")
  [ "$count" -eq 1 ]
}
