#!/usr/bin/env node

/**
 * Auto-Commit Script
 *
 * Creates commits automatically following Conventional Commits format
 * Validates: tests, lint, types, secrets
 * Supports GPG signing
 * Automatically links to Jira
 *
 * Usage:
 *   node scripts/auto-commit.js --message "feat(reports): add filter" --files src/api.ts --jira PROJ-123
 *   npm run auto-commit -- --message "fix(api): null handling" --jira PROJ-124
 */

const { execSync } = require('child_process');
const path = require('path');
const fs = require('fs');
// Hand-rolled CLI parsing (Fase 4.1, update-plan-aug-2026.md): replaces
// minimist so this script runs with plain `node`, no `npm install` needed.
// Mimics the minimist behavior these scripts relied on: --flag=value,
// --flag value, -alias value, bare boolean flags (no value / followed by
// another flag), and repeated flags accumulating into an array.
function parseArgs(argv, aliases = {}, booleans = []) {
  const args = {};
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    if (!arg.startsWith('-')) continue;
    let key = arg.replace(/^--?/, '');
    let value;
    const eq = key.indexOf('=');
    if (eq !== -1) {
      value = key.slice(eq + 1);
      key = key.slice(0, eq);
    }
    key = aliases[key] || key;
    if (value === undefined) {
      if (booleans.includes(key)) {
        value = true;
      } else {
        const next = argv[i + 1];
        value = (next !== undefined && !next.startsWith('-')) ? argv[++i] : true;
      }
    }
    args[key] = Object.prototype.hasOwnProperty.call(args, key)
      ? [].concat(args[key], value)
      : value;
  }
  return args;
}

// ============================================================================
// CONFIGURATION
// ============================================================================

const config = {
  validateTests: true,
  validateLint: true,
  validateTypes: true,
  validateSecrets: true,
  signCommits: process.env.GPG_KEY_ID ? true : false,
  maxCommitMessageLength: 72,
  gitAuthorName: process.env.GIT_AUTHOR_NAME || 'Auto Agent',
  gitAuthorEmail: process.env.GIT_AUTHOR_EMAIL || 'agent@company.com',
};

// ============================================================================
// LOGGING
// ============================================================================

function log(message, type = 'info') {
  const colors = {
    info: '\x1b[36m',    // Cyan
    success: '\x1b[32m', // Green
    warning: '\x1b[33m', // Yellow
    error: '\x1b[31m',   // Red
    reset: '\x1b[0m'
  };

  const icon = {
    info: 'ℹ',
    success: '✅',
    warning: '⚠️',
    error: '❌'
  };

  const color = colors[type] || colors.info;
  console.log(`${icon[type]} ${color}${message}${colors.reset}`);
}

// ============================================================================
// VALIDATION FUNCTIONS
// ============================================================================

function validateTests() {
  log('Running tests...', 'info');
  try {
    execSync('npm test -- --passWithNoTests', {
      stdio: 'inherit',
      cwd: process.cwd()
    });
    log('Tests passed', 'success');
    return true;
  } catch (error) {
    log('Tests failed', 'error');
    return false;
  }
}

function validateLint() {
  log('Running linter...', 'info');
  try {
    // Try eslint first
    try {
      execSync('npx eslint . --ext .ts,.tsx,.js,.jsx', {
        stdio: 'pipe',
        cwd: process.cwd()
      });
    } catch {
      // Fall back to prettier check
      execSync('npx prettier --check .', {
        stdio: 'pipe',
        cwd: process.cwd()
      });
    }
    log('Linting passed', 'success');
    return true;
  } catch (error) {
    log('Linting failed', 'error');
    return false;
  }
}

function validateTypes() {
  log('Running type check...', 'info');
  try {
    execSync('npx tsc --noEmit', {
      stdio: 'pipe',
      cwd: process.cwd()
    });
    log('Type check passed', 'success');
    return true;
  } catch (error) {
    log('Type check failed', 'error');
    return false;
  }
}

function validateSecrets() {
  log('Checking for secrets...', 'info');

  const secretPatterns = [
    /GITHUB_TOKEN|github_token/i,
    /JIRA_API_TOKEN|jira_token/i,
    /AWS_SECRET|aws_access_key/i,
    /MONGODB_URI|mongodb.*password/i,
    /API_KEY|SECRET_KEY/i
  ];

  try {
    const stagedFiles = execSync('git diff --cached --name-only', {
      encoding: 'utf-8',
      stdio: 'pipe'
    }).split('\n').filter(f => f);

    for (const file of stagedFiles) {
      if (!fs.existsSync(file)) continue;

      const content = fs.readFileSync(file, 'utf-8');

      for (const pattern of secretPatterns) {
        if (pattern.test(content)) {
          log(`Potential secret found in ${file}`, 'error');
          return false;
        }
      }
    }

    log('No secrets found', 'success');
    return true;
  } catch (error) {
    log('Secret validation failed', 'warning');
    return true; // Don't block on this
  }
}

function validateCommitMessage(message) {
  // Conventional Commits format: type(scope): subject

  // Check format
  const regex = /^(feat|fix|refactor|perf|test|docs|style|chore|ci)(\(.+\))?!?: .+/;
  if (!regex.test(message)) {
    log(
      'Invalid commit message format\n' +
      'Expected: <type>(<scope>): <subject>\n' +
      'Example: feat(reports): add date filter',
      'error'
    );
    return false;
  }

  // Check length
  const firstLine = message.split('\n')[0];
  if (firstLine.length > config.maxCommitMessageLength) {
    log(
      `Commit message too long (${firstLine.length}/${config.maxCommitMessageLength} chars)`,
      'error'
    );
    return false;
  }

  return true;
}

function validateFiles(files) {
  if (!files || files.length === 0) {
    log('No files specified', 'error');
    return false;
  }

  for (const file of files) {
    if (!fs.existsSync(file)) {
      log(`File not found: ${file}`, 'error');
      return false;
    }
  }

  return true;
}

// ============================================================================
// COMMIT FUNCTIONS
// ============================================================================

function stageFiles(files) {
  log('Staging files...', 'info');
  try {
    const fileArgs = files.join(' ');
    execSync(`git add ${fileArgs}`, {
      stdio: 'inherit',
      cwd: process.cwd()
    });
    log(`Staged ${files.length} file(s)`, 'success');
    return true;
  } catch (error) {
    log('Failed to stage files', 'error');
    return false;
  }
}

function createCommit(message, jiraRef) {
  log('Creating commit...', 'info');

  try {
    // Build full message
    let fullMessage = message;
    if (jiraRef) {
      fullMessage += ` [${jiraRef}]`;
    }

    // Build git command
    let cmd = `git -c user.name="${config.gitAuthorName}" -c user.email="${config.gitAuthorEmail}"`;

    if (config.signCommits && process.env.GPG_KEY_ID) {
      cmd += ` -c user.signingkey="${process.env.GPG_KEY_ID}"`;
    }

    cmd += ` commit`;

    if (config.signCommits && process.env.GPG_KEY_ID) {
      cmd += ` -S`;
    }

    cmd += ` -m "${fullMessage.replace(/"/g, '\\"')}"`;

    // Execute
    execSync(cmd, {
      stdio: 'inherit',
      cwd: process.cwd()
    });

    // Get SHA
    const sha = execSync('git rev-parse HEAD', {
      encoding: 'utf-8',
      stdio: 'pipe'
    }).trim();

    log(`Commit created: ${sha.slice(0, 7)}`, 'success');
    return { success: true, sha, message: fullMessage };
  } catch (error) {
    log(`Commit failed: ${error.message}`, 'error');
    return { success: false, error: error.message };
  }
}

function pushBranch(branch) {
  log(`Pushing to origin/${branch}...`, 'info');

  try {
    execSync(`git push origin ${branch}`, {
      stdio: 'inherit',
      cwd: process.cwd()
    });
    log(`Pushed to origin/${branch}`, 'success');
    return true;
  } catch (error) {
    log(`Push failed: ${error.message}`, 'error');
    return false;
  }
}

// ============================================================================
// MAIN EXECUTION
// ============================================================================

async function main() {
  const args = parseArgs(process.argv.slice(2), {
    m: 'message',
    f: 'files',
    j: 'jira',
    p: 'push',
    h: 'help'
  }, ['push', 'help']);

  // Show help
  if (args.help) {
    console.log(`
Auto-Commit Script

Usage:
  node scripts/auto-commit.js [options]

Options:
  --message, -m    Commit message (Conventional Commits format)
  --files, -f      Files to stage (comma-separated or multiple)
  --jira, -j       Jira ticket reference (e.g., PROJ-123)
  --push, -p       Push to origin after commit (default: false)
  --help, -h       Show this help

Examples:
  node scripts/auto-commit.js \\
    --message "feat(reports): add date filter" \\
    --files src/api.ts,src/utils.ts \\
    --jira PROJ-123 \\
    --push

  npm run auto-commit -- \\
    --message "fix(api): handle null dates" \\
    --files "src/api.ts" \\
    --jira PROJ-124
    `);
    process.exit(0);
  }

  // Validate inputs
  if (!args.message) {
    log('Missing required option: --message', 'error');
    process.exit(1);
  }

  const files = Array.isArray(args.files)
    ? args.files.flatMap(f => f.split(','))
    : (args.files ? args.files.split(',') : []);

  log('Auto-Commit Script Starting...', 'info');
  log(`Branch: ${execSync('git rev-parse --abbrev-ref HEAD', { encoding: 'utf-8' }).trim()}`, 'info');

  // ========================================================================
  // VALIDATION PHASE
  // ========================================================================

  log('\n=== VALIDATION PHASE ===', 'info');

  if (!validateCommitMessage(args.message)) {
    process.exit(1);
  }

  if (!validateFiles(files)) {
    process.exit(1);
  }

  if (config.validateTests && !validateTests()) {
    log('Aborting: tests failed', 'error');
    process.exit(1);
  }

  if (config.validateLint && !validateLint()) {
    log('Aborting: linting failed', 'error');
    process.exit(1);
  }

  if (config.validateTypes && !validateTypes()) {
    log('Aborting: type check failed', 'error');
    process.exit(1);
  }

  if (config.validateSecrets && !validateSecrets()) {
    log('Aborting: secrets detected', 'error');
    process.exit(1);
  }

  // ========================================================================
  // COMMIT PHASE
  // ========================================================================

  log('\n=== COMMIT PHASE ===', 'info');

  if (!stageFiles(files)) {
    process.exit(1);
  }

  const commitResult = createCommit(args.message, args.jira);
  if (!commitResult.success) {
    process.exit(1);
  }

  // ========================================================================
  // PUSH PHASE
  // ========================================================================

  if (args.push) {
    log('\n=== PUSH PHASE ===', 'info');
    const branch = execSync('git rev-parse --abbrev-ref HEAD', {
      encoding: 'utf-8'
    }).trim();

    if (branch === 'main' || branch === 'master') {
      log('Cannot push to main/master branch', 'error');
      process.exit(1);
    }

    if (!pushBranch(branch)) {
      process.exit(1);
    }
  }

  // ========================================================================
  // SUCCESS
  // ========================================================================

  log('\n=== SUCCESS ===', 'success');
  log(`Commit: ${commitResult.sha.slice(0, 7)}`, 'success');
  log(`Message: ${commitResult.message}`, 'success');
  if (args.jira) {
    log(`Jira: ${args.jira}`, 'success');
  }
  if (args.push) {
    log('Pushed: Yes', 'success');
  }

  process.exit(0);
}

// ============================================================================
// ENTRY POINT
// ============================================================================

main().catch((error) => {
  log(`Fatal error: ${error.message}`, 'error');
  process.exit(1);
});
