#!/bin/bash

# ============================================================================
# Per-Repository Setup
# ============================================================================
# Run this FROM the root of the repo you want to set up.
# Usage:
#   /path/to/AI-Setup/setup-repo.sh
# ============================================================================

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

# Directory where this script lives (the setup repo)
SETUP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Current directory (the target repo)
TARGET_DIR="$(pwd)"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Per-Repository Setup${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo "Setup source: $SETUP_DIR"
echo "Target repo:  $TARGET_DIR"
echo ""

# ----------------------------------------------------------------------------
# Safety check — is this a git repo?
# ----------------------------------------------------------------------------
if [ ! -d "$TARGET_DIR/.git" ]; then
  echo -e "${RED}❌ Current directory is not a git repository.${NC}"
  echo "   Run this from the root of your repo."
  exit 1
fi

# ----------------------------------------------------------------------------
# Detect project type
# ----------------------------------------------------------------------------
if [ -f "$TARGET_DIR/package.json" ]; then
  echo -e "${GREEN}✅ Detected Node.js project (package.json found)${NC}"
  IS_NODE=true
else
  echo -e "${YELLOW}⚠️  No package.json found — this looks like a non-Node project.${NC}"
  echo "   The .js scripts under scripts/ assume Node (run with plain 'node',"
  echo "   no npm install needed — see USAGE.md). The git hooks in .githooks/"
  echo "   work regardless of language. Continuing with file copy only."
  IS_NODE=false
fi
echo ""

# ----------------------------------------------------------------------------
# 1. Copy scripts
# ----------------------------------------------------------------------------
echo -e "${BLUE}Copying scripts...${NC}"
mkdir -p "$TARGET_DIR/scripts"
cp "$SETUP_DIR"/registry/scripts/*.js "$TARGET_DIR/scripts/"
echo -e "${GREEN}✅ Scripts copied to scripts/${NC}"

# ----------------------------------------------------------------------------
# 2. Copy git hooks (native, via core.hooksPath — Fase 4.1,
#    update-plan-aug-2026.md; replaces Husky, retired to docs/archive/husky/)
# ----------------------------------------------------------------------------
# No npm install / npx husky install step needed: core.hooksPath is a plain
# git feature, so this works identically for Node and non-Node repos alike.
echo -e "${BLUE}Copying git hooks (.githooks/, via core.hooksPath)...${NC}"
mkdir -p "$TARGET_DIR/.githooks"
cp "$SETUP_DIR"/registry/templates/githooks/pre-commit "$TARGET_DIR/.githooks/"
cp "$SETUP_DIR"/registry/templates/githooks/prepare-commit-msg "$TARGET_DIR/.githooks/"
cp "$SETUP_DIR"/registry/templates/githooks/post-merge "$TARGET_DIR/.githooks/"
cp "$SETUP_DIR"/registry/templates/githooks/pre-push "$TARGET_DIR/.githooks/"
chmod +x "$TARGET_DIR"/.githooks/pre-commit
chmod +x "$TARGET_DIR"/.githooks/prepare-commit-msg
chmod +x "$TARGET_DIR"/.githooks/post-merge
chmod +x "$TARGET_DIR"/.githooks/pre-push
git -C "$TARGET_DIR" config core.hooksPath .githooks
echo -e "${GREEN}✅ Hooks copied to .githooks/ and wired via core.hooksPath${NC}"

# ----------------------------------------------------------------------------
# 2b. Copy GitHub Actions workflows
# ----------------------------------------------------------------------------
echo -e "${BLUE}Copying GitHub Actions workflows...${NC}"
mkdir -p "$TARGET_DIR/.github/workflows"
cp "$SETUP_DIR"/registry/templates/github/workflows/pr-validation.yml "$TARGET_DIR/.github/workflows/"
cp "$SETUP_DIR"/registry/templates/github/workflows/on-merge.yml "$TARGET_DIR/.github/workflows/"
echo -e "${GREEN}✅ Workflows copied to .github/workflows/${NC}"
echo -e "${YELLOW}   ⚠️  Remember to add Jira secrets in GitHub:${NC}"
echo -e "${YELLOW}      Settings → Secrets and variables → Actions${NC}"
echo -e "${YELLOW}      Add: JIRA_HOST, JIRA_EMAIL, JIRA_API_TOKEN${NC}"

# ----------------------------------------------------------------------------
# 3. Create .env.local if it doesn't exist
# ----------------------------------------------------------------------------
if [ ! -f "$TARGET_DIR/.env.local" ]; then
  echo -e "${BLUE}Creating .env.local from template...${NC}"
  cp "$SETUP_DIR/.env.example" "$TARGET_DIR/.env.local"
  echo -e "${GREEN}✅ Created .env.local${NC}"
  echo -e "${YELLOW}   ⚠️  EDIT .env.local and fill in your credentials!${NC}"
else
  echo -e "${YELLOW}⚠️  .env.local already exists — left untouched${NC}"
fi

# ----------------------------------------------------------------------------
# 4. Ensure .env.local is gitignored
# ----------------------------------------------------------------------------
if [ ! -f "$TARGET_DIR/.gitignore" ] || ! grep -q ".env.local" "$TARGET_DIR/.gitignore"; then
  echo -e "${BLUE}Adding .env.local to .gitignore...${NC}"
  {
    echo ""
    echo "# Claude automation secrets"
    echo ".env.local"
  } >> "$TARGET_DIR/.gitignore"
  echo -e "${GREEN}✅ .gitignore updated${NC}"
fi

# ----------------------------------------------------------------------------
# 2c. Copy AGENTS.md template (SSOT) — or patch an existing one (upgrade path)
# ----------------------------------------------------------------------------
# AGENTS.md holds per-project customization (tech stack, commands,
# architecture), so re-runs never overwrite an existing one. But when a new
# AI-Setup release adds a required line to the template (e.g. the
# Commit/PR-style toggle, the .local-docs/ pointer), an already-customized
# AGENTS.md would never see it. Patch: append only the lines that are
# missing, leaving all existing content untouched.
if [ ! -f "$TARGET_DIR/AGENTS.md" ]; then
  echo -e "${BLUE}Copying AGENTS.md template (SSOT)...${NC}"
  cp "$SETUP_DIR/registry/templates/AGENTS.md" "$TARGET_DIR/AGENTS.md"
  echo -e "${GREEN}✅ AGENTS.md copied (edit it for this project)${NC}"
else
  PATCHED=false
  if ! grep -q "Commit/PR style:" "$TARGET_DIR/AGENTS.md"; then
    {
      echo ""
      echo "<!-- added by setup-repo.sh — see AI-Setup CHANGELOG -->"
      echo "- Commit/PR style: plain   <!-- plain | emoji, see registry/templates/AGENTS.md for the full comment -->"
    } >> "$TARGET_DIR/AGENTS.md"
    PATCHED=true
  fi
  if ! grep -q "\.local-docs/" "$TARGET_DIR/AGENTS.md"; then
    echo "- Local context: see \`.local-docs/\` (gitignored — plan, architecture, security gaps, decisions; keep entries current)" >> "$TARGET_DIR/AGENTS.md"
    PATCHED=true
  fi
  if [ "$PATCHED" = true ]; then
    echo -e "${GREEN}✅ AGENTS.md patched with new required lines (existing content untouched)${NC}"
  else
    echo -e "${YELLOW}⚠️  AGENTS.md already exists and is up to date — left untouched${NC}"
  fi
fi

# ----------------------------------------------------------------------------
# 2c1. Copy CLAUDE.md + GEMINI.md (real files, `@AGENTS.md` import — no
#      symlinks; replaces the old setup-portability.sh symlink step, retired
#      in Fase 2 of update-plan-aug-2026.md — see docs/archive/ for why)
# ----------------------------------------------------------------------------
# Both Claude Code and Gemini CLI support `@path` file imports natively
# (verified 2026-08-24 — see docs/tool-compatibility.md's verification log):
# a one-line `@AGENTS.md` file works on every platform, including Windows
# without Developer Mode, with no fallback branch needed. Content is never
# project-specific (it's always exactly `@AGENTS.md`), so — like
# .cursor/rules/*.mdc — these are refreshed unconditionally on every run
# rather than only-if-missing.
echo -e "${BLUE}Copying CLAUDE.md + GEMINI.md (@AGENTS.md import)...${NC}"
cp "$SETUP_DIR/registry/templates/CLAUDE.md" "$TARGET_DIR/CLAUDE.md"
cp "$SETUP_DIR/registry/templates/GEMINI.md" "$TARGET_DIR/GEMINI.md"
echo -e "${GREEN}✅ CLAUDE.md + GEMINI.md copied${NC}"

# ----------------------------------------------------------------------------
# 2c2. Create .local-docs/ (gitignored, local-only human-context docs)
# ----------------------------------------------------------------------------
if [ ! -d "$TARGET_DIR/.local-docs" ]; then
  echo -e "${BLUE}Creating .local-docs/ (plan, architecture, security gaps, decisions)...${NC}"
  mkdir -p "$TARGET_DIR/.local-docs"
  cp "$SETUP_DIR"/registry/templates/local-docs/*.md "$TARGET_DIR/.local-docs/"
  echo -e "${GREEN}✅ .local-docs/ created${NC}"
else
  echo -e "${YELLOW}⚠️  .local-docs/ already exists — left untouched${NC}"
fi

if [ ! -f "$TARGET_DIR/.gitignore" ] || ! grep -q "^\.local-docs/$" "$TARGET_DIR/.gitignore"; then
  echo -e "${BLUE}Adding .local-docs/ to .gitignore...${NC}"
  {
    echo ""
    echo "# Local-only human-context docs (never pushed)"
    echo ".local-docs/"
  } >> "$TARGET_DIR/.gitignore"
  echo -e "${GREEN}✅ .gitignore updated${NC}"
fi

# ----------------------------------------------------------------------------
# 2d. Copy .mcp.json
# ----------------------------------------------------------------------------
if [ ! -f "$TARGET_DIR/.mcp.json" ]; then
  echo -e "${BLUE}Copying .mcp.json...${NC}"
  cp "$SETUP_DIR/registry/templates/.mcp.json" "$TARGET_DIR/.mcp.json"
  echo -e "${GREEN}✅ .mcp.json copied${NC}"
else
  echo -e "${YELLOW}⚠️  .mcp.json already exists — left untouched${NC}"
fi

# ----------------------------------------------------------------------------
# 2d2. Copy .cursor/mcp.json (real file, not a symlink — Cursor reads
#      .cursor/mcp.json specifically, it does NOT read a root .mcp.json;
#      verified 2026-08-24, see docs/tool-compatibility.md)
# ----------------------------------------------------------------------------
# Regenerated unconditionally on every run so it can never drift from the
# root .mcp.json it mirrors — same reasoning as .cursor/rules/*.mdc above.
# Skipped entirely if there's no root .mcp.json yet (nothing to mirror).
if [ -f "$TARGET_DIR/.mcp.json" ]; then
  echo -e "${BLUE}Copying .cursor/mcp.json (mirrors .mcp.json)...${NC}"
  mkdir -p "$TARGET_DIR/.cursor"
  cp "$TARGET_DIR/.mcp.json" "$TARGET_DIR/.cursor/mcp.json"
  echo -e "${GREEN}✅ .cursor/mcp.json copied${NC}"
fi

# ----------------------------------------------------------------------------
# 2e. Copy .claude/rules/
# ----------------------------------------------------------------------------
echo -e "${BLUE}Copying .claude/rules/...${NC}"
mkdir -p "$TARGET_DIR/.claude/rules"
cp "$SETUP_DIR"/registry/rules/*.md "$TARGET_DIR/.claude/rules/"
echo -e "${GREEN}✅ Rules copied to .claude/rules/${NC}"

# ----------------------------------------------------------------------------
# 2f. Generate .cursor/rules/ (Cursor adapter — tools/cursor/adapt/rule-to-mdc.sh)
# ----------------------------------------------------------------------------
# registry/rules/*.md is the only source of truth — the .mdc files are
# rendered fresh on every run, never hand-maintained, so they cannot drift
# from registry/rules/ the way the old per-repo/.cursor/rules/*.mdc did
# (see docs/RESTRUCTURE-2026-06.md).
echo -e "${BLUE}Generating .cursor/rules/ from registry/rules/...${NC}"
mkdir -p "$TARGET_DIR/.cursor/rules"
bash "$SETUP_DIR/tools/cursor/adapt/rule-to-mdc.sh" "$SETUP_DIR/registry/rules" "$TARGET_DIR/.cursor/rules"
echo -e "${GREEN}✅ Rules generated in .cursor/rules/${NC}"

# ----------------------------------------------------------------------------
# 2g. Copy .claude/hooks/
# ----------------------------------------------------------------------------
echo -e "${BLUE}Copying .claude/hooks/...${NC}"
mkdir -p "$TARGET_DIR/.claude/hooks/pre-tool-use"
mkdir -p "$TARGET_DIR/.claude/hooks/post-tool-use"
cp "$SETUP_DIR/registry/hooks/pre-tool-use/block-secrets.sh" "$TARGET_DIR/.claude/hooks/pre-tool-use/"
cp "$SETUP_DIR/registry/hooks/post-tool-use/lint-after-write.sh" "$TARGET_DIR/.claude/hooks/post-tool-use/"
chmod +x "$TARGET_DIR/.claude/hooks/pre-tool-use/block-secrets.sh"
chmod +x "$TARGET_DIR/.claude/hooks/post-tool-use/lint-after-write.sh"
echo -e "${GREEN}✅ Hooks copied to .claude/hooks/${NC}"

# ----------------------------------------------------------------------------
# 2g2. Generate .cursor/hooks.json (Cursor adapter — tools/cursor/adapt/hook-to-cursor.sh)
# ----------------------------------------------------------------------------
# Cursor has supported project hooks since 1.7 (verified 2026-08-24, see
# docs/tool-compatibility.md) — this bridges the .claude/hooks/ scripts just
# copied above, it doesn't duplicate their logic. Matcher info is read from
# tools/claude/settings.json (SSOT), same as the hooks it's bridging to.
echo -e "${BLUE}Generating .cursor/hooks.json from registry/hooks/...${NC}"
bash "$SETUP_DIR/tools/cursor/adapt/hook-to-cursor.sh" "$SETUP_DIR" "$TARGET_DIR"
echo -e "${GREEN}✅ .cursor/hooks.json + .cursor/hooks/_bridge.sh generated${NC}"

# ----------------------------------------------------------------------------
# 2h. Copy .claude/settings.json (hook registrations)
# ----------------------------------------------------------------------------
if [ ! -f "$TARGET_DIR/.claude/settings.json" ]; then
  echo -e "${BLUE}Copying .claude/settings.json...${NC}"
  cp "$SETUP_DIR/tools/claude/settings.json" "$TARGET_DIR/.claude/settings.json"
  echo -e "${GREEN}✅ .claude/settings.json copied${NC}"
else
  echo -e "${YELLOW}⚠️  .claude/settings.json already exists — left untouched${NC}"
fi

# ----------------------------------------------------------------------------
# 2i. Generate .github/copilot-instructions.md (Copilot adapter —
#     tools/copilot/enable.sh, condensed via lib/condense.mjs)
# ----------------------------------------------------------------------------
# NOT a symlink/copy of AGENTS.md — that was setup-portability.sh's old
# behavior and directly contradicted this file's own condensed design
# (docs/AUDIT-v3.md Fase 0 didn't catch it; found while retiring
# setup-portability.sh in Fase 2, see update-plan-aug-2026.md Bitácora).
# Regenerated unconditionally every run, same as .cursor/rules/.cursor/hooks.json
# — never hand-edited in a target repo. Needs `node`; degrades to a warning
# (not a hard failure) if node isn't on PATH, since setup-repo.sh must keep
# working for repos/machines that don't have it.
if command -v node &>/dev/null; then
  echo -e "${BLUE}Generating .github/copilot-instructions.md (condensed via lib/condense.mjs)...${NC}"
  bash "$SETUP_DIR/tools/copilot/enable.sh" --scope=repo
  echo -e "${GREEN}✅ .github/copilot-instructions.md generated${NC}"
else
  echo -e "${YELLOW}⚠️  node not found on PATH — skipped .github/copilot-instructions.md (needs lib/condense.mjs)${NC}"
fi

# ----------------------------------------------------------------------------
# 5. Node-specific setup
# ----------------------------------------------------------------------------
if [ "$IS_NODE" = true ]; then
  echo ""
  echo -e "${BLUE}Node setup...${NC}"
  echo -e "${YELLOW}No install step needed for scripts/ or the git hooks —${NC}"
  echo -e "${YELLOW}they run with plain 'node' / plain git, no dependencies.${NC}"
  echo ""
  echo -e "${YELLOW}Add to package.json scripts (optional, for npm run ... ):${NC}"
  echo '  "test":       "your test command",'
  echo '  "lint":       "your lint command",'
  echo '  "type-check": "tsc --noEmit",'
  echo '  "auto-commit": "node scripts/auto-commit.js",'
  echo '  "auto-pr":    "node scripts/auto-pr.js",'
  echo '  "auto-jira":  "node scripts/auto-jira.js",'
  echo '  "dashboard":  "node scripts/dashboard.js"'
fi

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Repo setup complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${YELLOW}DON'T FORGET:${NC}"
echo "  1. Edit AGENTS.md for this project (tech stack, commands, architecture)"
echo "     (CLAUDE.md, GEMINI.md, .cursor/mcp.json, .github/copilot-instructions.md"
echo "     are all generated for you — nothing left to run manually for portability)"
echo "  2. Edit .env.local with your real credentials"
echo "  3. Edit .claude/rules/design.md — set 'Design preset: velocity|vice|quiet'"
echo "  4. Add GitHub secrets: JIRA_HOST, JIRA_EMAIL, JIRA_API_TOKEN"
echo "  5. Push .github/workflows/ to activate GitHub Actions"
echo "  6. Fill in .local-docs/plan.md with this project's phases (gitignored, never pushed)"
echo ""
