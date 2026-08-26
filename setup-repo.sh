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

# AI-Setup's own version + commit at the time this ran (Fase 4.3,
# update-plan-aug-2026.md) — recorded into the target repo's
# .ai-setup/version.json so a later --check can tell whether the repo has
# drifted from what setup-repo.sh would produce today.
AI_SETUP_VERSION=$(grep -m1 '"version"' "$SETUP_DIR/package.json" | sed -E 's/.*"version":[[:space:]]*"([^"]+)".*/\1/')
AI_SETUP_COMMIT=$(git -C "$SETUP_DIR" rev-parse HEAD 2>/dev/null || echo "unknown")

# Managed-file inventory, built up as this script runs (Fase 4.3). Split the
# same way the rest of this script already treats files: "unconditional" is
# regenerated/overwritten every run (never hand-edit these in a target
# repo), "once" is created only if missing (safe to customize).
MANAGED_UNCONDITIONAL=()
MANAGED_ONCE=()

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Per-Repository Setup${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo "Setup source: $SETUP_DIR"
echo "Target repo:  $TARGET_DIR"
echo ""

# ----------------------------------------------------------------------------
# --check mode (Fase 4.3): report drift against .ai-setup/version.json
# instead of writing anything. Must come before the "is this a git repo"
# check below only in the sense that both need TARGET_DIR — reuses it.
# ----------------------------------------------------------------------------
if [ "${1:-}" = "--check" ]; then
  VERSION_FILE="$TARGET_DIR/.ai-setup/version.json"
  if [ ! -f "$VERSION_FILE" ]; then
    echo -e "${RED}❌ $VERSION_FILE not found.${NC}"
    echo "   This repo hasn't been set up with setup-repo.sh yet (or was set up"
    echo "   before Fase 4.3 added version tracking). Run setup-repo.sh first."
    exit 1
  fi

  PYTHON_BIN=""
  for candidate in python3 python py; do
    if command -v "$candidate" &>/dev/null; then PYTHON_BIN="$candidate"; break; fi
  done
  if [ -z "$PYTHON_BIN" ]; then
    echo -e "${RED}❌ No python3/python/py found on PATH — cannot parse $VERSION_FILE.${NC}"
    exit 1
  fi

  echo -e "${BLUE}Checking $TARGET_DIR against $VERSION_FILE...${NC}"
  echo ""
  "$PYTHON_BIN" - "$VERSION_FILE" "$TARGET_DIR" "$AI_SETUP_VERSION" "$AI_SETUP_COMMIT" <<'PYEOF'
import json, sys, os

version_file, target_dir, current_version, current_commit = sys.argv[1:5]
with open(version_file) as fh:
    data = json.load(fh)

drift = False

recorded_version = data.get("version")
recorded_commit = data.get("aiSetupCommit")
if recorded_version != current_version:
    print(f"  drift: applied with AI-Setup v{recorded_version}, source is now v{current_version}")
    drift = True
if recorded_commit not in (current_commit, "unknown") and current_commit != "unknown":
    print(f"  drift: applied at AI-Setup commit {recorded_commit}, source is now at {current_commit}")
    drift = True

missing = []
for f in data.get("managedFiles", {}).get("unconditional", []):
    if not os.path.exists(os.path.join(target_dir, f)):
        missing.append(f)
if missing:
    drift = True
    print("  drift: managed files missing from disk (removed after setup?):")
    for f in sorted(missing):
        print(f"    - {f}")

if not drift:
    print("  no drift detected")
sys.exit(1 if drift else 0)
PYEOF
  CHECK_STATUS=$?
  echo ""
  if [ $CHECK_STATUS -eq 0 ]; then
    echo -e "${GREEN}✅ No drift detected${NC}"
  else
    echo -e "${YELLOW}⚠️  Drift detected (see above). Re-run setup-repo.sh (without --check) to refresh.${NC}"
  fi
  exit $CHECK_STATUS
fi

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
for f in "$SETUP_DIR"/registry/scripts/*.js; do
  MANAGED_UNCONDITIONAL+=("scripts/$(basename "$f")")
done
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
MANAGED_UNCONDITIONAL+=(".githooks/pre-commit" ".githooks/prepare-commit-msg" ".githooks/post-merge" ".githooks/pre-push")
echo -e "${GREEN}✅ Hooks copied to .githooks/ and wired via core.hooksPath${NC}"

# ----------------------------------------------------------------------------
# 2b. Copy GitHub Actions workflows
# ----------------------------------------------------------------------------
echo -e "${BLUE}Copying GitHub Actions workflows...${NC}"
mkdir -p "$TARGET_DIR/.github/workflows"
cp "$SETUP_DIR"/registry/templates/github/workflows/pr-validation.yml "$TARGET_DIR/.github/workflows/"
cp "$SETUP_DIR"/registry/templates/github/workflows/on-merge.yml "$TARGET_DIR/.github/workflows/"
MANAGED_UNCONDITIONAL+=(".github/workflows/pr-validation.yml" ".github/workflows/on-merge.yml")
echo -e "${GREEN}✅ Workflows copied to .github/workflows/${NC}"
echo -e "${YELLOW}   ⚠️  Remember to add Jira secrets in GitHub:${NC}"
echo -e "${YELLOW}      Settings → Secrets and variables → Actions${NC}"
echo -e "${YELLOW}      Add: JIRA_HOST, JIRA_EMAIL, JIRA_API_TOKEN${NC}"

# ----------------------------------------------------------------------------
# 3. Ensure .env.local is gitignored — BEFORE writing it (Fase 4.2,
#    update-plan-aug-2026.md: a secrets file must never have even a single
#    moment where it exists un-gitignored in the working tree).
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
# 4. Create .env.local if it doesn't exist
# ----------------------------------------------------------------------------
if [ ! -f "$TARGET_DIR/.env.local" ]; then
  echo -e "${BLUE}Creating .env.local from template...${NC}"
  cp "$SETUP_DIR/.env.example" "$TARGET_DIR/.env.local"
  echo -e "${GREEN}✅ Created .env.local${NC}"
  echo -e "${YELLOW}   ⚠️  EDIT .env.local and fill in your credentials — or better, skip it${NC}"
  echo -e "${YELLOW}   entirely: GITHUB_TOKEN is read from 'gh auth token' automatically if${NC}"
  echo -e "${YELLOW}   unset, and JIRA_API_TOKEN can live in your OS keychain instead (see${NC}"
  echo -e "${YELLOW}   .env.example's comments).${NC}"
else
  echo -e "${YELLOW}⚠️  .env.local already exists — left untouched${NC}"
fi
MANAGED_ONCE+=(".env.local")

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
MANAGED_ONCE+=("AGENTS.md")

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
MANAGED_UNCONDITIONAL+=("CLAUDE.md" "GEMINI.md")
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
for f in "$SETUP_DIR"/registry/templates/local-docs/*.md; do
  MANAGED_ONCE+=(".local-docs/$(basename "$f")")
done

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
MANAGED_ONCE+=(".mcp.json")

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
  MANAGED_UNCONDITIONAL+=(".cursor/mcp.json")
  echo -e "${GREEN}✅ .cursor/mcp.json copied${NC}"
fi

# ----------------------------------------------------------------------------
# 2e. Copy .claude/rules/
# ----------------------------------------------------------------------------
echo -e "${BLUE}Copying .claude/rules/...${NC}"
mkdir -p "$TARGET_DIR/.claude/rules"
cp "$SETUP_DIR"/registry/rules/*.md "$TARGET_DIR/.claude/rules/"
for f in "$SETUP_DIR"/registry/rules/*.md; do
  base="$(basename "$f")"
  MANAGED_UNCONDITIONAL+=(".claude/rules/$base" ".cursor/rules/${base%.md}.mdc")
done
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
MANAGED_UNCONDITIONAL+=(".claude/hooks/pre-tool-use/block-secrets.sh" ".claude/hooks/post-tool-use/lint-after-write.sh")
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
MANAGED_UNCONDITIONAL+=(".cursor/hooks.json" ".cursor/hooks/_bridge.sh")
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
MANAGED_ONCE+=(".claude/settings.json")

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
  MANAGED_UNCONDITIONAL+=(".github/copilot-instructions.md")
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

# ----------------------------------------------------------------------------
# 6. Write .ai-setup/version.json (Fase 4.3, update-plan-aug-2026.md) —
#    records what AI-Setup version/commit applied this run and the full
#    managed-file inventory, so a later `setup-repo.sh --check` can report
#    drift instead of guessing.
# ----------------------------------------------------------------------------
PYTHON_BIN=""
for candidate in python3 python py; do
  if command -v "$candidate" &>/dev/null; then PYTHON_BIN="$candidate"; break; fi
done
if [ -n "$PYTHON_BIN" ]; then
  echo -e "${BLUE}Writing .ai-setup/version.json...${NC}"
  mkdir -p "$TARGET_DIR/.ai-setup"
  UNCONDITIONAL_LIST=$(printf '%s\n' "${MANAGED_UNCONDITIONAL[@]}")
  ONCE_LIST=$(printf '%s\n' "${MANAGED_ONCE[@]}")
  "$PYTHON_BIN" - "$TARGET_DIR/.ai-setup/version.json" "$AI_SETUP_VERSION" "$AI_SETUP_COMMIT" <<PYEOF
import json, sys
from datetime import datetime, timezone
out_path, version, commit = sys.argv[1:4]
unconditional = """$UNCONDITIONAL_LIST""".strip("\n").split("\n")
once = """$ONCE_LIST""".strip("\n").split("\n")
data = {
    "version": version,
    "aiSetupCommit": commit,
    "generatedAt": datetime.now(timezone.utc).isoformat(),
    "managedFiles": {
        "unconditional": sorted(set(f for f in unconditional if f)),
        "onceIfMissing": sorted(set(f for f in once if f)),
    },
}
with open(out_path, "w") as fh:
    json.dump(data, fh, indent=2)
    fh.write("\n")
PYEOF
  echo -e "${GREEN}✅ .ai-setup/version.json written${NC}"
else
  echo -e "${YELLOW}⚠️  No python3/python/py found — skipped .ai-setup/version.json ('setup-repo.sh --check' needs it)${NC}"
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
