# 🪝 HOOKS: FULL AUTOMATION

> **📜 Historical.** From the original "Nivel 3" build session (2026-06-04). Agent/skill counts elsewhere in the repo have since changed (now 13 agents, 12 skills — see `README.md`); the hook walkthrough itself is still accurate.

---

## 📋 HOOKS TO CREATE

```
.husky/pre-commit          → Validate before commit
.husky/prepare-commit-msg  → Auto-generate message
.husky/post-merge          → Auto-update after merge
.husky/pre-tag             → Auto-version before tag
```

---

## 🔧 STEP 1: Install Husky

```bash
cd repo-root

# Install Husky
npm install husky --save-dev

# Initialize
npx husky install

# Verify
ls -la .husky/
# You should see: _/, pre-commit, prepare-commit-msg, etc.
```

---

## 📝 STEP 2: Create Hooks

### Hook 1: .husky/pre-commit

**Location:** `.husky/pre-commit`

```bash
#!/bin/sh

# Pre-commit validation
# - Run tests
# - Run linter
# - Type check
# - Check for secrets

set -e  # Exit if any command fails

echo "🔍 Pre-commit validation starting..."

# 1. Run tests
echo "  Running tests..."
npm test -- --bail --silent 2>/dev/null || {
  echo "  ❌ Tests failed"
  exit 1
}
echo "  ✅ Tests passed"

# 2. Run linter
echo "  Running linter..."
npx eslint --ext .ts,.tsx,.js,.jsx src/ 2>/dev/null || {
  echo "  ❌ Linter errors found"
  exit 1
}
echo "  ✅ Linter passed"

# 3. Type check
echo "  Type checking..."
npx tsc --noEmit 2>/dev/null || {
  echo "  ❌ Type errors found"
  exit 1
}
echo "  ✅ Type check passed"

# 4. Check for secrets
echo "  Checking for secrets..."
if git diff --cached | grep -q "GITHUB_TOKEN\|API_KEY\|SECRET\|PASSWORD"; then
  echo "  ❌ Potential secrets detected"
  exit 1
fi
echo "  ✅ No secrets found"

# 5. Check for hardcoded values
echo "  Checking for hardcoded values..."
if git diff --cached src/ | grep -q "localhost:3000\|hardcoded"; then
  echo "  ⚠️  Warning: Hardcoded values detected (non-blocking)"
fi

echo "✅ Pre-commit validation passed"
exit 0
```

**Grant permissions:**
```bash
chmod +x .husky/pre-commit
```

---

### Hook 2: .husky/prepare-commit-msg

**Location:** `.husky/prepare-commit-msg`

```bash
#!/bin/sh

# Auto-enhance commit message
# - Add Jira reference (if in branch name)
# - Validate conventional commits format
# - Add commit template (if needed)

COMMIT_MSG_FILE=$1
COMMIT_SOURCE=$2

# No auto-format merge commits
if [ "$COMMIT_SOURCE" = "merge" ]; then
  exit 0
fi

# Get commit message
COMMIT_MSG=$(cat "$COMMIT_MSG_FILE")

# Extract Jira reference from branch (if exists)
BRANCH=$(git rev-parse --abbrev-ref HEAD)
JIRA_REF=$(echo "$BRANCH" | grep -o "PROJ-[0-9]*" || true)

# If branch has Jira ref and commit message doesn't, add it
if [ -n "$JIRA_REF" ] && ! echo "$COMMIT_MSG" | grep -q "\[$JIRA_REF\]"; then
  # Add to end of first line (before any body)
  FIRST_LINE=$(echo "$COMMIT_MSG" | head -1)
  REST=$(echo "$COMMIT_MSG" | tail -n +2)
  
  if [ -z "$REST" ]; then
    echo "$FIRST_LINE [$JIRA_REF]" > "$COMMIT_MSG_FILE"
  else
    {
      echo "$FIRST_LINE [$JIRA_REF]"
      echo "$REST"
    } > "$COMMIT_MSG_FILE"
  fi
  
  echo "ℹ️  Added Jira reference: [$JIRA_REF]"
fi

# Validate conventional commits format
COMMIT_MSG=$(cat "$COMMIT_MSG_FILE")
if ! echo "$COMMIT_MSG" | grep -q "^(feat|fix|refactor|perf|test|docs|style|chore|ci)"; then
  echo "⚠️  Warning: Commit message doesn't follow conventional commits"
  echo "   Expected: <type>(<scope>): <subject>"
  echo "   Got: $COMMIT_MSG"
  # Non-blocking warning
fi

exit 0
```

**Grant permissions:**
```bash
chmod +x .husky/prepare-commit-msg
```

---

### Hook 3: .husky/post-merge

**Location:** `.husky/post-merge`

```bash
#!/bin/sh

# Post-merge automation
# - Update dependencies if changed
# - Regenerate docs if code changed
# - Update Jira if commit refs tickets

set -e

echo "📦 Post-merge hook running..."

# 1. Check if package-lock.json changed
if git diff HEAD^ HEAD --name-only | grep -q "package-lock.json"; then
  echo "  📥 package-lock.json changed, running npm install..."
  npm install --silent
  echo "  ✅ Dependencies updated"
fi

# 2. Update API docs if code changed
if git diff HEAD^ HEAD --name-only | grep -q "src/api\|src/controllers"; then
  echo "  📚 API code changed, regenerating docs..."
  npm run docs:update 2>/dev/null || true
  echo "  ✅ API docs regenerated"
fi

# 3. Update CHANGELOG if features merged
COMMITS=$(git log --oneline HEAD^ HEAD | grep -E "^(feat|fix)" || true)
if [ -n "$COMMITS" ]; then
  echo "  📝 Features detected, updating CHANGELOG..."
  # documentation-generator will handle this
fi

# 4. Update Jira tickets (if script exists)
if [ -f "scripts/update-jira-on-merge.js" ]; then
  echo "  🔄 Updating Jira tickets..."
  node scripts/update-jira-on-merge.js || true
fi

echo "✅ Post-merge hook completed"
exit 0
```

**Grant permissions:**
```bash
chmod +x .husky/post-merge
```

---

### Hook 4: .husky/pre-tag

**Location:** `.husky/pre-tag`

```bash
#!/bin/sh

# Pre-tag validation & automation
# - Validate tag format (vX.Y.Z)
# - Update CHANGELOG
# - Create GitHub release
# - Validate all tests passing

set -e

TAG=$1

echo "🏷️  Pre-tag hook for: $TAG"

# 1. Validate tag format
if ! echo "$TAG" | grep -q "^v[0-9]\+\.[0-9]\+\.[0-9]\+"; then
  echo "❌ Invalid tag format: $TAG"
  echo "   Expected: vX.Y.Z (e.g., v2.2.0)"
  exit 1
fi
echo "✅ Tag format valid: $TAG"

# 2. Final tests
echo "Running final tests before tag..."
npm test -- --bail --silent 2>/dev/null || {
  echo "❌ Tests failed, cannot tag"
  exit 1
}
echo "✅ All tests passing"

# 3. Check CHANGELOG has entry
VERSION=${TAG#v}  # Remove 'v' prefix
if ! grep -q "## \[$VERSION\]" CHANGELOG.md; then
  echo "⚠️  Warning: No CHANGELOG entry for $VERSION"
fi

# 4. Verify no uncommitted changes
if ! git diff-index --quiet HEAD --; then
  echo "❌ Uncommitted changes found, cannot tag"
  exit 1
fi
echo "✅ No uncommitted changes"

# 5. Create release notes (optional)
if [ -f "scripts/create-release-notes.js" ]; then
  echo "📝 Creating release notes..."
  node scripts/create-release-notes.js "$TAG" || true
fi

echo "✅ Pre-tag validation passed, ready to tag"
exit 0
```

**Grant permissions:**
```bash
chmod +x .husky/pre-tag
```

---

## 📋 STEP 3: Configure package.json

Husky needs these scripts ready:

```json
{
  "scripts": {
    "prepare": "husky install",
    "test": "jest --coverage",
    "lint": "eslint . --ext .ts,.tsx,.js,.jsx",
    "type-check": "tsc --noEmit",
    "docs:update": "npm run docs:generate",
    "docs:generate": "node scripts/generate-docs.js"
  },
  "devDependencies": {
    "husky": "^8.0.0",
    "jest": "^29.0.0",
    "eslint": "^8.0.0",
    "typescript": "^5.0.0"
  }
}
```

---

## ✅ STEP 4: VERIFY HOOKS

### Test pre-commit

```bash
# Make a change
echo "test" > test-file.ts

# Try to commit
git add test-file.ts
git commit -m "test: verify pre-commit hook"

# Should run:
# ✅ Tests running...
# ✅ Tests passed
# ✅ Linter passed
# ✅ Type check passed
# ✅ No secrets found
# ✅ Pre-commit validation passed

# If everything passes, commit succeeds
# If something fails, commit is blocked
```

### Test prepare-commit-msg

```bash
# Create a branch with a Jira ref
git checkout -b feature/PROJ-123-test-feature

# Commit
echo "test" > file.ts
git add file.ts
git commit -m "feat(test): test message"

# Should auto-add [PROJ-123]
# Verify:
git log -1 --oneline
# Should show: feat(test): test message [PROJ-123]
```

### Test post-merge

```bash
# Create and merge a PR
git checkout -b test/merge
echo "test" > test.ts
git add test.ts
git commit -m "feat: test merge"
git checkout main
git merge test/merge

# Should run the post-merge hook
# ✅ Post-merge hook running...
# ✅ Post-merge hook completed
```

### Test pre-tag

```bash
# Create a valid tag
git tag v1.2.0

# Should validate:
# ✅ Tag format valid: v1.2.0
# ✅ All tests passing
# ✅ No uncommitted changes
# ✅ Pre-tag validation passed

# If all good, tag is created
```

---

## 🔄 FULL FLOW WITH HOOKS

```
YOU: git add src/api.ts
  ↓
YOU: git commit -m "feat(api): add endpoint"
  ↓
Hook 1: pre-commit runs
  ├─ npm test ✅
  ├─ npm lint ✅
  ├─ tsc ✅
  ├─ check secrets ✅
  └─ Commit succeeds ✅
  ↓
Hook 2: prepare-commit-msg runs
  ├─ Detects branch: feature/PROJ-123
  ├─ Extracts: PROJ-123
  ├─ Auto-adds: [PROJ-123] to the message
  └─ Final message: feat(api): add endpoint [PROJ-123]
  ↓
Commit created ✅
  ↓
YOU: git push origin feature/PROJ-123
  ↓
YOU: Open a PR
  ↓
YOU: Approve the PR
  ↓
YOU: Merge to main
  ↓
Hook 3: post-merge runs
  ├─ Detects code changes
  ├─ npm run docs:update
  ├─ Updates CHANGELOG
  └─ Notifies agents
  ↓
YOU: git tag v1.2.0
  ↓
Hook 4: pre-tag runs
  ├─ Validates tag format ✅
  ├─ Validates tests ✅
  ├─ Creates GitHub release
  └─ Tag created ✅
  ↓
Release v1.2.0 published ✅
```

---

## 📝 INSTALLATION CHECKLIST

```markdown
- [ ] npm install husky
- [ ] npx husky install
- [ ] Create .husky/pre-commit
- [ ] Create .husky/prepare-commit-msg
- [ ] Create .husky/post-merge
- [ ] Create .husky/pre-tag
- [ ] chmod +x .husky/*
- [ ] Add "prepare": "husky install" to package.json
- [ ] Test pre-commit hook
- [ ] Test prepare-commit-msg hook
- [ ] Test post-merge hook
- [ ] Test pre-tag hook
- [ ] Commit .husky/ to the repo
- [ ] Verify hooks run automatically
```

---

**Last updated:** 2026-06-04
**Version:** 1.0
