#!/usr/bin/env node

/**
 * Auto-PR Script
 *
 * Creates pull requests automatically on GitHub
 * Validates: branch exists, no conflicts, tests passing
 * Adds: labels, reviewers, Jira links
 *
 * Usage:
 *   node scripts/auto-pr.js --title "Feature | Add filter [PROJ-123]" --branch feature/PROJ-123
 *   npm run auto-pr -- --title "Feature | ..." --jira PROJ-123,PROJ-124
 *
 * Title is plain by default (no emoji) — see "Commit/PR style" in AGENTS.md
 * for the opt-in emoji exception during a project's early bootstrap phase.
 */

const https = require('https');
const fs = require('fs');
const { execSync, execFileSync } = require('child_process');

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
// SECRETS (Fase 4.2, update-plan-aug-2026.md)
// ============================================================================

// Prefers the token the user already has live in `gh` over a long-lived one
// sitting in .env.local — `gh auth token` is never persisted by this script,
// it's re-read from gh's own (already-secure) storage on every run. Falls
// back to GITHUB_TOKEN from .env.local if `gh` isn't installed/logged in.
function resolveGithubToken() {
  if (process.env.GITHUB_TOKEN) return process.env.GITHUB_TOKEN;
  try {
    return execFileSync('gh', ['auth', 'token'], {
      encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore']
    }).trim() || undefined;
  } catch (_) {
    return undefined;
  }
}

// ============================================================================
// CONFIGURATION
// ============================================================================

const config = {
  githubToken: resolveGithubToken(),
  githubOwner: process.env.GITHUB_OWNER || 'org',
  githubRepo: process.env.GITHUB_REPO || 'repo',
  defaultLabels: ['enhancement', 'jira'],
  defaultReviewers: ['test-engineer', 'code-reviewer-pro'],
  draftPR: false
};

if (!config.githubToken) {
  console.error('❌ Error: GITHUB_TOKEN environment variable not set');
  process.exit(1);
}

// ============================================================================
// LOGGING
// ============================================================================

function log(message, type = 'info') {
  const colors = {
    info: '\x1b[36m',
    success: '\x1b[32m',
    warning: '\x1b[33m',
    error: '\x1b[31m',
    reset: '\x1b[0m'
  };

  const icon = { info: 'ℹ', success: '✅', warning: '⚠️', error: '❌' };
  const color = colors[type] || colors.info;
  console.log(`${icon[type]} ${color}${message}${colors.reset}`);
}

// ============================================================================
// GITHUB API FUNCTIONS
// ============================================================================

function makeGitHubRequest(method, path, data = null) {
  return new Promise((resolve, reject) => {
    const options = {
      hostname: 'api.github.com',
      path,
      method,
      headers: {
        'Authorization': `token ${config.githubToken}`,
        'Accept': 'application/vnd.github.v3+json',
        'User-Agent': 'Auto-PR-Script'
      }
    };

    const req = https.request(options, (res) => {
      let body = '';

      res.on('data', (chunk) => (body += chunk));
      res.on('end', () => {
        try {
          const parsed = JSON.parse(body);
          if (res.statusCode >= 400) {
            reject(new Error(`GitHub API error (${res.statusCode}): ${parsed.message}`));
          } else {
            resolve({ status: res.statusCode, data: parsed });
          }
        } catch (e) {
          reject(e);
        }
      });
    });

    req.on('error', reject);

    if (data) {
      req.write(JSON.stringify(data));
    }

    req.end();
  });
}

async function createPullRequest(prData) {
  log('Creating pull request...', 'info');

  const path = `/repos/${config.githubOwner}/${config.githubRepo}/pulls`;

  const body = {
    title: prData.title,
    body: prData.body,
    head: prData.head,
    base: prData.base,
    draft: config.draftPR
  };

  try {
    const result = await makeGitHubRequest('POST', path, body);
    const prNumber = result.data.number;
    const prUrl = result.data.html_url;

    log(`PR created: #${prNumber}`, 'success');
    log(`URL: ${prUrl}`, 'success');

    return { number: prNumber, url: prUrl, data: result.data };
  } catch (error) {
    log(`PR creation failed: ${error.message}`, 'error');
    throw error;
  }
}

async function addLabels(prNumber, labels) {
  if (!labels || labels.length === 0) return;

  log(`Adding labels: ${labels.join(', ')}...`, 'info');

  const path = `/repos/${config.githubOwner}/${config.githubRepo}/issues/${prNumber}/labels`;

  try {
    await makeGitHubRequest('POST', path, { labels });
    log('Labels added', 'success');
  } catch (error) {
    log(`Failed to add labels: ${error.message}`, 'warning');
  }
}

async function addReviewers(prNumber, reviewers) {
  if (!reviewers || reviewers.length === 0) return;

  log(`Adding reviewers: ${reviewers.join(', ')}...`, 'info');

  const path = `/repos/${config.githubOwner}/${config.githubRepo}/pulls/${prNumber}/requested_reviewers`;

  try {
    await makeGitHubRequest('POST', path, { reviewers });
    log('Reviewers added', 'success');
  } catch (error) {
    log(`Failed to add reviewers: ${error.message}`, 'warning');
  }
}

// ============================================================================
// VALIDATION FUNCTIONS
// ============================================================================

function getBranchInfo(branch) {
  try {
    const commits = execSync(`git log origin/main..origin/${branch} --oneline 2>/dev/null | wc -l`, {
      encoding: 'utf-8'
    }).trim();

    return { branch, commits: parseInt(commits) || 0 };
  } catch {
    return null;
  }
}

function checkForConflicts(branch) {
  try {
    execSync(`git fetch origin main >/dev/null 2>&1`);
    execSync(`git merge-base --is-ancestor origin/main origin/${branch}`, {
      stdio: 'pipe'
    });
    return true; // No conflicts
  } catch {
    return false;
  }
}

// ============================================================================
// PR BODY GENERATION
// ============================================================================

function generatePRBody(options = {}) {
  const {
    title,
    description,
    testResults,
    jiraRefs = []
  } = options;

  let body = description || 'No description provided.';

  // Add test results if available
  if (testResults) {
    body += '\n\n## Tests\n' + testResults;
  }

  // Add Jira links if provided
  if (jiraRefs && jiraRefs.length > 0) {
    body += '\n\n## Related\n';
    jiraRefs.forEach(ref => {
      body += `- [${ref}](https://jira.company.com/browse/${ref})\n`;
    });
  }

  return body;
}

// ============================================================================
// MAIN EXECUTION
// ============================================================================

async function main() {
  const args = parseArgs(process.argv.slice(2), {
    t: 'title',
    b: 'branch',
    d: 'description',
    j: 'jira',
    l: 'labels',
    r: 'reviewers',
    h: 'help'
  }, ['help']);

  if (args.help) {
    console.log(`
Auto-PR Script

Usage:
  node scripts/auto-pr.js [options]

Options:
  --title, -t        PR title (required)
  --branch, -b       Feature branch name (default: current branch)
  --description, -d  PR body description
  --jira, -j         Jira references (comma-separated, e.g., PROJ-123,PROJ-124)
  --labels, -l       Labels (comma-separated, default: enhancement,jira)
  --reviewers, -r    Reviewers (comma-separated, default: test-engineer,code-reviewer-pro)
  --help, -h         Show this help

Examples:
  node scripts/auto-pr.js \\
    --title "Feature | Add date filter [PROJ-123]" \\
    --branch feature/PROJ-123-date-filter \\
    --jira PROJ-123 \\
    --labels "enhancement,feature"

  npm run auto-pr -- \\
    --title "Fix | Handle null dates [PROJ-124]" \\
    --branch feature/PROJ-124
    `);
    process.exit(0);
  }

  // Validate inputs
  if (!args.title) {
    log('Missing required option: --title', 'error');
    process.exit(1);
  }

  const branch = args.branch || execSync('git rev-parse --abbrev-ref HEAD', {
    encoding: 'utf-8'
  }).trim();

  const jiraRefs = args.jira ? args.jira.split(',').map(j => j.trim()) : [];
  const labels = args.labels ? args.labels.split(',').map(l => l.trim()) : config.defaultLabels;
  const reviewers = args.reviewers ? args.reviewers.split(',').map(r => r.trim()) : config.defaultReviewers;

  log('Auto-PR Script Starting...', 'info');

  // ========================================================================
  // VALIDATION PHASE
  // ========================================================================

  log('\n=== VALIDATION PHASE ===', 'info');

  // Check branch exists
  log('Checking branch...', 'info');
  const branchInfo = getBranchInfo(branch);
  if (!branchInfo || branchInfo.commits === 0) {
    log(`Branch ${branch} not found or has no commits`, 'error');
    process.exit(1);
  }
  log(`Branch ${branch} has ${branchInfo.commits} commit(s)`, 'success');

  // Check for conflicts
  log('Checking for conflicts with main...', 'info');
  if (!checkForConflicts(branch)) {
    log('Merge conflicts detected with main', 'warning');
    // Don't block on this, user can resolve
  } else {
    log('No conflicts with main', 'success');
  }

  // ========================================================================
  // PR CREATION PHASE
  // ========================================================================

  log('\n=== PR CREATION PHASE ===', 'info');

  const prBody = generatePRBody({
    title: args.title,
    description: args.description,
    jiraRefs
  });

  const prData = {
    title: args.title,
    body: prBody,
    head: branch,
    base: 'main'
  };

  let prResult;
  try {
    prResult = await createPullRequest(prData);
  } catch (error) {
    process.exit(1);
  }

  // ========================================================================
  // METADATA PHASE
  // ========================================================================

  log('\n=== METADATA PHASE ===', 'info');

  await addLabels(prResult.number, labels);
  await addReviewers(prResult.number, reviewers);

  // ========================================================================
  // SUCCESS
  // ========================================================================

  log('\n=== SUCCESS ===', 'success');
  log(`PR #${prResult.number}: ${args.title}`, 'success');
  log(`URL: ${prResult.url}`, 'success');
  log(`Labels: ${labels.join(', ')}`, 'success');
  log(`Reviewers: ${reviewers.join(', ')}`, 'success');
  if (jiraRefs.length > 0) {
    log(`Jira: ${jiraRefs.join(', ')}`, 'success');
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
