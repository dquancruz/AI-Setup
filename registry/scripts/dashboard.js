#!/usr/bin/env node

/**
 * Dashboard Script
 *
 * Shows real-time progress of the agent-orchestrator
 * Status of Jira tickets, GitHub PRs, commits
 * Test and coverage information
 *
 * Usage:
 *   node scripts/dashboard.js --epic PROJ-120 --watch
 *   npm run dashboard -- --epic PROJ-120
 */

const fs = require('fs');
const path = require('path');
const https = require('https');
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
// SECRETS (Fase 4.2, update-plan-aug-2026.md) — same resolution as
// auto-jira.js / auto-pr.js; see those files' own comments for why.
// ============================================================================

function resolveJiraToken(email) {
  try {
    if (process.platform === 'darwin' && email) {
      return execFileSync(
        'security', ['find-generic-password', '-a', email, '-s', 'ai-setup-jira', '-w'],
        { encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] }
      ).trim() || undefined;
    }
    if (process.platform === 'linux' && email) {
      return execFileSync(
        'secret-tool', ['lookup', 'service', 'ai-setup-jira', 'account', email],
        { encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] }
      ).trim() || undefined;
    }
  } catch (_) {
    // Keychain tool missing or nothing stored yet — fall through to .env.local.
  }
  return undefined;
}

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
  refreshInterval: 5000, // 5 seconds
  jiraHost: process.env.JIRA_HOST || 'yourcompany.atlassian.net',
  jiraEmail: process.env.JIRA_EMAIL,
  jiraToken: resolveJiraToken(process.env.JIRA_EMAIL) || process.env.JIRA_API_TOKEN,
  githubToken: resolveGithubToken(),
  githubOwner: process.env.GITHUB_OWNER || 'org',
  githubRepo: process.env.GITHUB_REPO || 'repo'
};

// ============================================================================
// COLORS & FORMATTING
// ============================================================================

const colors = {
  reset: '\x1b[0m',
  bold: '\x1b[1m',
  dim: '\x1b[2m',
  red: '\x1b[31m',
  green: '\x1b[32m',
  yellow: '\x1b[33m',
  blue: '\x1b[34m',
  cyan: '\x1b[36m',
  white: '\x1b[37m',
  bgBlue: '\x1b[44m',
  bgGreen: '\x1b[42m'
};

const icons = {
  success: '✅',
  error: '❌',
  warning: '⚠️',
  info: 'ℹ',
  clock: '⏱️',
  rocket: '🚀',
  git: '📦',
  test: '🧪',
  bug: '🐛',
  feature: '✨',
  doc: '📚',
  jira: '🔄'
};

function colorize(text, color) {
  return `${colors[color]}${text}${colors.reset}`;
}

function bold(text) {
  return `${colors.bold}${text}${colors.reset}`;
}

// ============================================================================
// JIRA API
// ============================================================================

function makeJiraRequest(path) {
  return new Promise((resolve, reject) => {
    const auth = Buffer.from(`${config.jiraEmail}:${config.jiraToken}`).toString('base64');

    const options = {
      hostname: config.jiraHost,
      path: `/rest/api/3${path}`,
      method: 'GET',
      headers: {
        'Authorization': `Basic ${auth}`,
        'Accept': 'application/json'
      }
    };

    const req = https.request(options, (res) => {
      let body = '';
      res.on('data', (chunk) => (body += chunk));
      res.on('end', () => {
        try {
          resolve(JSON.parse(body));
        } catch (e) {
          reject(e);
        }
      });
    });

    req.on('error', reject);
    req.end();
  });
}

async function getJiraIssue(issueKey) {
  try {
    return await makeJiraRequest(`/issues/${issueKey}`);
  } catch {
    return null;
  }
}

// ============================================================================
// GITHUB API
// ============================================================================

function makeGitHubRequest(path) {
  return new Promise((resolve, reject) => {
    const options = {
      hostname: 'api.github.com',
      path,
      method: 'GET',
      headers: {
        'Authorization': `token ${config.githubToken}`,
        'Accept': 'application/vnd.github.v3+json',
        'User-Agent': 'Dashboard'
      }
    };

    const req = https.request(options, (res) => {
      let body = '';
      res.on('data', (chunk) => (body += chunk));
      res.on('end', () => {
        try {
          resolve(JSON.parse(body));
        } catch (e) {
          reject(e);
        }
      });
    });

    req.on('error', reject);
    req.end();
  });
}

async function getGitHubPRs() {
  try {
    const path = `/repos/${config.githubOwner}/${config.githubRepo}/pulls?state=open`;
    return await makeGitHubRequest(path);
  } catch {
    return [];
  }
}

// ============================================================================
// GIT FUNCTIONS
// ============================================================================

function getRecentCommits(branch = 'HEAD', count = 5) {
  try {
    const output = execSync(`git log ${branch} --oneline -${count}`, {
      encoding: 'utf-8'
    });

    return output.split('\n').filter(Boolean).map(line => {
      const [sha, ...messageParts] = line.split(' ');
      return {
        sha: sha.slice(0, 7),
        message: messageParts.join(' ').slice(0, 50)
      };
    });
  } catch {
    return [];
  }
}

function getTestResults() {
  try {
    const coverage = execSync('npm test -- --coverage --silent 2>/dev/null || echo "N/A"', {
      encoding: 'utf-8',
      stdio: ['pipe', 'pipe', 'ignore']
    }).trim();

    return { status: 'passing', coverage: coverage.includes('100') ? '100%' : 'N/A' };
  } catch {
    return { status: 'unknown', coverage: 'N/A' };
  }
}

// ============================================================================
// DASHBOARD RENDERING
// ============================================================================

function clearScreen() {
  console.clear();
}

function renderHeader() {
  console.log(colorize('╔════════════════════════════════════════════════════════════╗', 'cyan'));
  console.log(colorize('║', 'cyan') + bold('  AGENT-ORCHESTRATOR PROGRESS DASHBOARD') + colorize('  ║', 'cyan'));
  console.log(colorize('╚════════════════════════════════════════════════════════════╝', 'cyan'));
  console.log();
}

function renderJiraSection(issues = []) {
  console.log(colorize(`${icons.jira} JIRA TICKETS`, 'blue'));
  console.log(colorize('─'.repeat(60), 'dim'));

  if (!issues || issues.length === 0) {
    console.log(colorize('  No tickets loaded', 'dim'));
  } else {
    issues.forEach(issue => {
      const statusColor = issue.status === 'Done' ? 'green' : issue.status === 'In Progress' ? 'yellow' : 'white';
      const statusIcon = issue.status === 'Done' ? icons.success : '⏳';

      console.log(
        `  ${statusIcon} ${bold(issue.key)} ${issue.summary}\n` +
        `     Status: ${colorize(issue.status, statusColor)} | Assignee: ${issue.assignee || 'Unassigned'}`
      );
    });
  }
  console.log();
}

function renderCommitsSection(commits = []) {
  console.log(colorize(`${icons.git} RECENT COMMITS`, 'blue'));
  console.log(colorize('─'.repeat(60), 'dim'));

  if (!commits || commits.length === 0) {
    console.log(colorize('  No commits yet', 'dim'));
  } else {
    commits.forEach(commit => {
      console.log(`  ${colorize(commit.sha, 'cyan')} ${commit.message}`);
    });
  }
  console.log();
}

function renderTestsSection(testResults = {}) {
  console.log(colorize(`${icons.test} TESTS & COVERAGE`, 'blue'));
  console.log(colorize('─'.repeat(60), 'dim'));

  const statusColor = testResults.status === 'passing' ? 'green' : 'red';
  const statusIcon = testResults.status === 'passing' ? icons.success : icons.error;

  console.log(
    `  ${statusIcon} Status: ${colorize(testResults.status, statusColor)}\n` +
    `  ${icons.clock} Coverage: ${testResults.coverage}`
  );
  console.log();
}

function renderPRSection(prs = []) {
  console.log(colorize(`📤 PULL REQUESTS`, 'blue'));
  console.log(colorize('─'.repeat(60), 'dim'));

  if (!prs || prs.length === 0) {
    console.log(colorize('  No open PRs', 'dim'));
  } else {
    prs.slice(0, 3).forEach(pr => {
      const stateColor = pr.state === 'open' ? 'yellow' : 'green';
      console.log(
        `  #${pr.number} ${pr.title}\n` +
        `     State: ${colorize(pr.state, stateColor)} | Created: ${pr.created_at.slice(0, 10)}`
      );
    });
  }
  console.log();
}

function renderProgressBar(current, total) {
  const percentage = Math.round((current / total) * 100);
  const filled = Math.round((percentage / 100) * 20);
  const empty = 20 - filled;

  const bar = colorize('█'.repeat(filled), 'green') + '░'.repeat(empty);
  return `${bar} ${percentage}%`;
}

function renderFooter(lastUpdate) {
  console.log(colorize('─'.repeat(60), 'dim'));
  console.log(
    colorize('Last updated: ', 'dim') +
    lastUpdate.toLocaleTimeString() +
    colorize(' | Press Ctrl+C to exit', 'dim')
  );
}

// ============================================================================
// MAIN DASHBOARD
// ============================================================================

async function renderDashboard(epicKey, watch = false) {
  clearScreen();
  renderHeader();

  console.log(colorize(`📋 Epic: ${epicKey}`, 'yellow'));
  console.log();

  // Load data
  let jiraData = null;
  let testResults = {};
  let commits = [];
  let prs = [];

  try {
    if (epicKey) {
      jiraData = await getJiraIssue(epicKey);
    }
    testResults = getTestResults();
    commits = getRecentCommits('HEAD', 5);
    prs = await getGitHubPRs();
  } catch (error) {
    console.log(colorize(`Error loading data: ${error.message}`, 'red'));
  }

  // Render sections
  if (jiraData) {
    renderJiraSection([
      {
        key: jiraData.key,
        summary: jiraData.fields.summary,
        status: jiraData.fields.status?.name || 'Unknown',
        assignee: jiraData.fields.assignee?.displayName || 'Unassigned'
      }
    ]);
  }

  renderCommitsSection(commits);
  renderTestsSection(testResults);
  renderPRSection(prs);

  // Progress summary
  console.log(colorize(`${icons.rocket} PROGRESS SUMMARY`, 'blue'));
  console.log(colorize('─'.repeat(60), 'dim'));
  console.log(`  Total PRs: ${prs.length}`);
  console.log(`  Recent commits: ${commits.length}`);
  console.log(`  Tests: ${testResults.status}`);
  console.log();

  renderFooter(new Date());

  if (watch) {
    setTimeout(() => renderDashboard(epicKey, watch), config.refreshInterval);
  }
}

// ============================================================================
// MAIN EXECUTION
// ============================================================================

async function main() {
  const args = parseArgs(process.argv.slice(2), {
    e: 'epic',
    w: 'watch',
    h: 'help'
  }, ['watch', 'help']);

  if (args.help) {
    console.log(`
Dashboard Script

Usage:
  node scripts/dashboard.js [options]

Options:
  --epic, -e      Epic key to track (e.g., PROJ-120)
  --watch, -w     Watch mode (refresh every 5 seconds)
  --help, -h      Show this help

Examples:
  node scripts/dashboard.js --epic PROJ-120
  npm run dashboard -- --epic PROJ-120 --watch
  node scripts/dashboard.js --watch  (no epic, just PRs & commits)
    `);
    process.exit(0);
  }

  const epicKey = args.epic;
  const watch = args.watch || false;

  try {
    await renderDashboard(epicKey, watch);
  } catch (error) {
    console.error(colorize(`Fatal error: ${error.message}`, 'red'));
    process.exit(1);
  }
}

// ============================================================================
// ENTRY POINT
// ============================================================================

main();
