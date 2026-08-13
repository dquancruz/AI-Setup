#!/bin/bash

# ============================================================================
# AI-Setup — Installer
# ============================================================================
# Installs agents and skills globally to ~/.claude/
# Per-repo files (scripts, hooks, .env) are handled separately — see README.
# ============================================================================

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  AI-Setup — Installer${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# ----------------------------------------------------------------------------
# 1. Verify ~/.claude exists
# ----------------------------------------------------------------------------
CLAUDE_DIR="$HOME/.claude"

if [ ! -d "$CLAUDE_DIR" ]; then
  echo -e "${YELLOW}Creating $CLAUDE_DIR ...${NC}"
  mkdir -p "$CLAUDE_DIR"
fi

mkdir -p "$CLAUDE_DIR/agents"
mkdir -p "$CLAUDE_DIR/skills"

# ----------------------------------------------------------------------------
# 2. Backup existing agents/skills (safety)
# ----------------------------------------------------------------------------
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

if [ "$(ls -A $CLAUDE_DIR/agents 2>/dev/null)" ]; then
  echo -e "${YELLOW}Backing up existing agents to agents-backup-$TIMESTAMP ...${NC}"
  cp -r "$CLAUDE_DIR/agents" "$CLAUDE_DIR/agents-backup-$TIMESTAMP"
fi

if [ "$(ls -A $CLAUDE_DIR/skills 2>/dev/null)" ]; then
  echo -e "${YELLOW}Backing up existing skills to skills-backup-$TIMESTAMP ...${NC}"
  cp -r "$CLAUDE_DIR/skills" "$CLAUDE_DIR/skills-backup-$TIMESTAMP"
fi

# ----------------------------------------------------------------------------
# 3. Install agents
# ----------------------------------------------------------------------------
echo ""
echo -e "${BLUE}Installing agents...${NC}"
cp registry/agents/*.md "$CLAUDE_DIR/agents/"
AGENT_COUNT=$(ls registry/agents/*.md | wc -l)
echo -e "${GREEN}✅ Installed $AGENT_COUNT agents${NC}"

# ----------------------------------------------------------------------------
# 4. Install skills (12 — folder structure)
# ----------------------------------------------------------------------------
echo ""
echo -e "${BLUE}Installing skills...${NC}"
mkdir -p "$CLAUDE_DIR/skills"
for SKILL_DIR in registry/skills/*/; do
  if [ -d "$SKILL_DIR" ]; then
    SKILL_NAME=$(basename "$SKILL_DIR")
    mkdir -p "$CLAUDE_DIR/skills/$SKILL_NAME"
    cp "$SKILL_DIR"SKILL.md "$CLAUDE_DIR/skills/$SKILL_NAME/SKILL.md" 2>/dev/null || true
  fi
done
SKILL_COUNT=$(ls -d registry/skills/*/ 2>/dev/null | wc -l)
echo -e "${GREEN}✅ Installed $SKILL_COUNT skills${NC}"

# ----------------------------------------------------------------------------
# Done
# ----------------------------------------------------------------------------
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Global install complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Installed to: $CLAUDE_DIR"
echo "  - $AGENT_COUNT agents"
echo "  - $SKILL_COUNT skills"
echo ""
echo -e "${YELLOW}NEXT — per-repo setup (run in each project):${NC}"
echo "  /path/to/setup-repo.sh    (from the root of your project)"
echo ""
echo -e "${YELLOW}PORTABILITY (in each repo, after setup-repo.sh):${NC}"
echo "  bash setup-portability.sh"
echo "  → Creates CLAUDE.md, GEMINI.md, .github/copilot-instructions.md as symlinks to AGENTS.md"
echo ""
echo -e "${YELLOW}CROSS-TOOL skills:${NC}"
echo "  Skills in ~/.claude/skills/ are readable by Cursor/Gemini/Codex."
echo "  See registry/skills/README.md for per-tool instructions."
echo ""
