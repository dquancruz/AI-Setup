# 🚀 FULL SETUP: NIVEL 3 TOTAL AUTOMATION

> **📜 Historical.** From the original "Nivel 3" build session (2026-06-04). Counts and paths are outdated (the repo now has 13 agents, 12 skills, and lives under `registry/` — see `README.md`); the step-by-step setup logic is still largely valid.

---

## 📋 SUMMARY OF FILES TO INSTALL

```
SKILLS (6 .md files) → ~/.claude/skills/
SCRIPTS (4 .js files) → repo/scripts/
AGENTS (5 .md files) → ~/.claude/agents/
MCPs (configuration) → claude_desktop_config.json
HOOKS (4 scripts) → .husky/
CONFIGURATION (3 files) → repo root
```

---

## 🔧 STEP-BY-STEP INSTALLATION

### PHASE 1: SKILLS (10 minutes)

```bash
# 1. Copy skills to ~/.claude/skills/
cp 01-IoT-Backend-Best-Practices.md ~/.claude/skills/
cp 02-PR-Description-Formatter.md ~/.claude/skills/
cp 03-Semantic-Versioning-Control.md ~/.claude/skills/
cp 04-Auto-Commit-Best-Practices.md ~/.claude/skills/
cp 05-Auto-PR-Creation-Guide.md ~/.claude/skills/
cp 06-Jira-Integration-Patterns.md ~/.claude/skills/

# 2. Verify
ls -la ~/.claude/skills/
# You should see 6 .md files
```

---

### PHASE 2: AGENTS (15 minutes)

```bash
# 1. Rename and copy
cp AGENTE-1-agent-orchestrator.md ~/.claude/agents/agent-orchestrator.md
# (The other 4 are in AGENTES-2-5-modificados.md, create individual files)

# For the other 4 agents:
# - Extract the code from AGENTES-2-5-modificados.md
# - Create individual files:
#   ~/.claude/agents/backend-expert.md (MODIFIED)
#   ~/.claude/agents/frontend-expert.md (MODIFIED)
#   ~/.claude/agents/pr-manager.md (MODIFIED)
#   ~/.claude/agents/documentation-generator.md (MODIFIED)

# 2. Verify
ls -la ~/.claude/agents/
# You should see: agent-orchestrator.md + 4 more (if they already existed)
```

---

### PHASE 3: SCRIPTS (15 minutes)

```bash
cd ~/my-repo

# 1. Rename scripts
# (In the outputs, files have a "scripts-" prefix to avoid conflicts)
cp ~/outputs/scripts-auto-commit.js scripts/auto-commit.js
cp ~/outputs/scripts-auto-pr.js scripts/auto-pr.js
cp ~/outputs/scripts-auto-jira.js scripts/auto-jira.js
cp ~/outputs/scripts-dashboard.js scripts/dashboard.js

# 2. Grant permissions
chmod +x scripts/*.js

# 3. Install dependency
npm install --save-dev minimist

# 4. Add scripts to package.json
# Edit package.json and add:
cat >> package.json << 'EOF'
{
  "scripts": {
    "auto-commit": "node scripts/auto-commit.js",
    "auto-pr": "node scripts/auto-pr.js",
    "auto-jira": "node scripts/auto-jira.js",
    "dashboard": "node scripts/dashboard.js"
  }
}
EOF

# 5. Verify
ls -la scripts/
npm run auto-commit -- --help
```

---

### PHASE 4: CONFIGURATION (20 minutes)

```bash
cd ~/my-repo

# 1. Create .env.local (NEVER COMMIT)
cat > .env.local << 'EOF'
# Jira
JIRA_HOST=yourcompany.atlassian.net
JIRA_EMAIL=your-email@company.com
JIRA_API_TOKEN=<paste from https://id.atlassian.com/manage-profile/security/api-tokens>
JIRA_PROJECT_KEY=PROJ

# GitHub
GITHUB_TOKEN=ghp_<paste from https://github.com/settings/tokens>
GITHUB_OWNER=your-org
GITHUB_REPO=your-repo

# Git
GIT_AUTHOR_NAME=Your Name
GIT_AUTHOR_EMAIL=your-email@company.com
GPG_KEY_ID=<optional, get from gpg --list-keys>
EOF

# 2. Add .env.local to .gitignore
echo ".env.local" >> .gitignore
echo ".env.*.local" >> .gitignore

# 3. Verify
ls -la .env.local
grep ".env.local" .gitignore
```

---

### PHASE 5: MCPs (25 minutes)

#### 5A. Jira MCP

```bash
# Option A: If available on npm (recommended)
npm install -g @atlassian/mcp-server-jira

# Option B: If not, build a custom one (see MCPS-configuracion-completa.md)
# mkdir -p ~/.claude/mcp-servers/jira-mcp
# cd ~/.claude/mcp-servers/jira-mcp
# npm init -y
# npm install @modelcontextprotocol/sdk
# (Copy the code from the file)
```

#### 5B. Git MCP

```bash
# Create a custom Git MCP
mkdir -p ~/.claude/mcp-servers/git-mcp
cd ~/.claude/mcp-servers/git-mcp

# Initialize
npm init -y
npm install @modelcontextprotocol/sdk

# Copy the code from MCPS-configuracion-completa.md
# (the full index.js file)

# Verify
ls -la index.js
```

#### 5C. GitHub MCP

```bash
# Install the official one
npm install -g @modelcontextprotocol/server-github@latest

# Verify
which mcp-github
# Or if it's local:
npm list @modelcontextprotocol/server-github
```

#### 5D. Configure claude_desktop_config.json

```bash
# Correct location by OS:
# Windows: %USERPROFILE%/AppData/Local/Claude/claude_desktop_config.json
# Mac: ~/Library/Application Support/Claude/claude_desktop_config.json
# Linux: ~/.config/Claude/claude_desktop_config.json

# Copy the content from MCPS-configuracion-completa.md ("Full" section)
# Update the paths to:
# - /path/to/jira-mcp/index.js
# - /path/to/git-mcp/index.js

# Verify valid JSON
cat claude_desktop_config.json | jq .
```

---

### PHASE 6: HOOKS (20 minutes)

```bash
cd ~/my-repo

# 1. Install Husky
npm install husky --save-dev

# 2. Initialize
npx husky install

# 3. Create hooks
# Copy the code from HOOKS-husky-complete.md

cat > .husky/pre-commit << 'EOF'
#!/bin/sh
# (Copy the full content from HOOKS-husky-complete.md)
EOF

cat > .husky/prepare-commit-msg << 'EOF'
#!/bin/sh
# (Copy the content)
EOF

cat > .husky/post-merge << 'EOF'
#!/bin/sh
# (Copy the content)
EOF

cat > .husky/pre-tag << 'EOF'
#!/bin/sh
# (Copy the content)
EOF

# 4. Grant permissions
chmod +x .husky/*

# 5. Add the "prepare" script to package.json
# In the "scripts" section, add:
# "prepare": "husky install"

# 6. Verify
ls -la .husky/
npx husky list
```

---

## ✅ INSTALLATION VERIFICATION

### Step 1: Verify Skills

```bash
ls -la ~/.claude/skills/
# You should see 6 .md files

# Verify agent-orchestrator can read them
# (when using Claude Code, it should show available skills)
```

### Step 2: Verify Agents

```bash
ls -la ~/.claude/agents/
# You should see: agent-orchestrator.md + others

# Verify content
grep "auto-commit" ~/.claude/agents/agent-orchestrator.md
# Should find references to scripts
```

### Step 3: Verify Scripts

```bash
cd ~/my-repo

# Test auto-commit
npm run auto-commit -- --help
# Should show: "Auto-Commit Script"

# Test auto-pr
npm run auto-pr -- --help
# Should show: "Auto-PR Script"

# Test auto-jira
npm run auto-jira -- --help
# Should show: "Auto-Jira Script"

# Test dashboard
npm run dashboard -- --help
# Should show: "Dashboard Script"
```

### Step 4: Verify Configuration

```bash
cd ~/my-repo

# Verify .env.local
[ -f .env.local ] && echo "✅ .env.local exists" || echo "❌ .env.local doesn't exist"

# Verify variables
grep JIRA_HOST .env.local
grep GITHUB_TOKEN .env.local
grep GIT_AUTHOR_NAME .env.local

# Verify .gitignore
grep ".env.local" .gitignore
```

### Step 5: Verify MCPs

```bash
# Verify Jira MCP
which jira-mcp 2>/dev/null || echo "Jira MCP not in PATH (OK if custom)"

# Verify Git MCP
ls -la ~/.claude/mcp-servers/git-mcp/index.js

# Verify GitHub MCP
npm list @modelcontextprotocol/server-github -g

# Verify claude_desktop_config.json
cat claude_desktop_config.json | jq .mcpServers
# Should show jira, git, github, filesystem
```

### Step 6: Verify Hooks

```bash
cd ~/my-repo

# Verify husky is installed
npm list husky

# Verify hooks were created
ls -la .husky/
# You should see: _, pre-commit, prepare-commit-msg, post-merge, pre-tag

# Verify permissions
[ -x .husky/pre-commit ] && echo "✅ pre-commit executable" || echo "❌ Not executable"

# Test the hook (without a real commit)
.husky/pre-commit --dry-run || true
```

---

## 🧪 FINAL TEST: FULL FLOW

```bash
cd ~/my-repo

# 1. Create a test branch
git checkout -b test/level3-automation

# 2. Make a change
echo "// Test feature" > src/test-feature.ts

# 3. Try to commit
git add src/test-feature.ts
git commit -m "feat(test): test level 3 automation"

# Should run:
# ✅ Pre-commit hook
#    - Tests running...
#    - Linter running...
#    - Type check...
#    - Secrets check...
# ✅ Prepare-commit-msg hook
#    - Auto-detect branch
#    - Auto-add Jira ref (if applicable)
# ✅ Commit created with [JIRA-XXX] if the branch has one

# Verify
git log -1 --oneline
# Should show: feat(test): test level 3 automation [JIRA-XXX]

# 4. Create a PR (manual test)
npm run auto-pr -- \
  --title "🧪 Test | Level 3 Automation" \
  --branch test/level3-automation \
  --labels "test"

# Should show:
# ✅ PR created: #XXX
# ✅ URL: https://github.com/...

# 5. View the dashboard
npm run dashboard -- --watch

# Should show:
# 📊 Dashboard
# - Recent commits
# - PRs
# - Tests status
# - Coverage
```

---

## 📊 FINAL CHECKLIST

```markdown
## SKILLS
- [ ] 6 skills copied to ~/.claude/skills/
- [ ] agent-orchestrator can access skills
- [ ] Each skill is readable and well-formatted

## AGENTS
- [ ] 5 agents in ~/.claude/agents/
- [ ] agent-orchestrator.md has auto-commit references
- [ ] backend-expert.md has an auto-commit section
- [ ] frontend-expert.md has an auto-commit section
- [ ] pr-manager.md has an auto-pr section
- [ ] documentation-generator.md has a versioning section

## SCRIPTS
- [ ] 4 scripts in repo/scripts/
- [ ] scripts have executable permissions (chmod +x)
- [ ] minimist installed (npm list minimist)
- [ ] npm scripts added to package.json
- [ ] Each script responds to --help

## CONFIGURATION
- [ ] .env.local created with credentials
- [ ] .env.local in .gitignore
- [ ] JIRA_HOST, EMAIL, TOKEN configured
- [ ] GITHUB_TOKEN configured
- [ ] GIT_AUTHOR_NAME, EMAIL configured
- [ ] Variables verifiable in the terminal

## MCPs
- [ ] Jira MCP installed or a custom one built
- [ ] Custom Git MCP built in ~/.claude/mcp-servers/git-mcp
- [ ] GitHub MCP installed
- [ ] claude_desktop_config.json updated
- [ ] All MCPs have correct paths
- [ ] Valid JSON (jq validated)

## HOOKS
- [ ] Husky installed (npm list husky)
- [ ] Husky initialized (npx husky install)
- [ ] 4 hooks created in .husky/
- [ ] All hooks have executable permissions
- [ ] "prepare" script in package.json
- [ ] Pre-commit hook runs with no errors
- [ ] prepare-commit-msg adds Jira refs
- [ ] post-merge hook runs with no errors
- [ ] pre-tag hook validates format

## TESTING
- [ ] npm run auto-commit -- --help works
- [ ] npm run auto-pr -- --help works
- [ ] npm run auto-jira -- --help works
- [ ] npm run dashboard -- --help works
- [ ] Local test commit (test/automation branch)
- [ ] Test pre-commit validations
- [ ] Test prepare-commit-msg auto-reference
- [ ] Test dashboard showing info

## FINAL
- [ ] Everything committed to the repo (except .env.local)
- [ ] README updated with instructions
- [ ] Team notified of the new setup
- [ ] First features tested successfully
- [ ] Dashboard showing progress
```

---

## 🎯 FIRST STEPS TO TRY

Once everything is installed:

```
OPTION 1: Create a feature from scratch
└─ YOU: @agent-orchestrator "Feature: Add X"
   └─ Automatic: Jira epic → commits → PR → merge → release

OPTION 2: Work on an existing ticket
└─ YOU: @agent-orchestrator "Work on PROJ-123"
   └─ Automatic: Fetch ticket → implement → commit → PR → merge

OPTION 3: Verify a feature is implemented
└─ YOU: @agent-orchestrator "Is PROJ-123 done?"
   └─ Automatic: Verifies acceptance criteria

OPTION 4: Watch progress in real time
└─ npm run dashboard -- --epic PROJ-120 --watch
   └─ Dashboard showing everything in real time
```

---

## 🆘 QUICK TROUBLESHOOTING

| Problem | Solution |
|----------|----------|
| JIRA_TOKEN doesn't work | Check https://id.atlassian.com/manage-profile/security/api-tokens |
| GITHUB_TOKEN doesn't work | Verify the token has scopes: repo, workflow, gist |
| Scripts don't run | Check: chmod +x scripts/*.js |
| Hooks don't fire | Check: npx husky list |
| MCPs don't connect | Check: paths in claude_desktop_config.json |
| Pre-commit blocks | Review: tests, lint, types are OK |
| Auto-commit fails | Review: GIT_AUTHOR_NAME/EMAIL configured |
| Auto-PR fails | Check: branch exists, no conflicts with main |

---

**Last updated:** 2026-06-04
**YOU'RE READY TO START! 🚀**
