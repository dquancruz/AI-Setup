#!/usr/bin/env node

/**
 * Auto-Jira Script
 *
 * Creates Epics, Stories, and Tasks automatically in Jira
 * Links commits and PRs
 * Transitions states automatically
 *
 * Usage:
 *   node scripts/auto-jira.js --epic "Add date filtering" --stories "API Endpoint,UI Component"
 *   npm run auto-jira -- --epic "Feature name" --assignees "backend-expert,frontend-expert"
 */

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
// SECRETS (Fase 4.2, update-plan-aug-2026.md)
// ============================================================================

// Prefers the OS keychain over .env.local, which never expires and stays in
// the clear on disk. Store the token once with:
//   macOS:  security add-generic-password -a "$JIRA_EMAIL" -s ai-setup-jira -w "$JIRA_API_TOKEN"
//   Linux:  echo -n "$JIRA_API_TOKEN" | secret-tool store --label="AI-Setup Jira" service ai-setup-jira account "$JIRA_EMAIL"
// No native CLI keychain reader exists on Windows without an extra
// dependency this repo doesn't want to introduce — falls back to
// .env.local's JIRA_API_TOKEN there, and anywhere the lookup above isn't
// available or comes up empty (e.g. not yet stored, tool missing).
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

// ============================================================================
// CONFIGURATION
// ============================================================================

const config = {
  jiraHost: process.env.JIRA_HOST || 'yourcompany.atlassian.net',
  jiraEmail: process.env.JIRA_EMAIL,
  jiraToken: resolveJiraToken(process.env.JIRA_EMAIL) || process.env.JIRA_API_TOKEN,
  jiraProjectKey: process.env.JIRA_PROJECT_KEY || 'PROJ',
  storyPoints: 5
};

if (!config.jiraEmail || !config.jiraToken) {
  console.error('❌ Error: JIRA_EMAIL and JIRA_API_TOKEN environment variables required');
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
// JIRA API FUNCTIONS
// ============================================================================

function makeJiraRequest(method, path, data = null) {
  return new Promise((resolve, reject) => {
    const auth = Buffer.from(`${config.jiraEmail}:${config.jiraToken}`).toString('base64');

    const options = {
      hostname: config.jiraHost,
      path: `/rest/api/3${path}`,
      method,
      headers: {
        'Authorization': `Basic ${auth}`,
        'Accept': 'application/json',
        'Content-Type': 'application/json'
      }
    };

    const req = https.request(options, (res) => {
      let body = '';

      res.on('data', (chunk) => (body += chunk));
      res.on('end', () => {
        try {
          const parsed = body ? JSON.parse(body) : {};
          if (res.statusCode >= 400) {
            reject(new Error(`Jira API error (${res.statusCode}): ${parsed.errorMessages?.[0] || parsed.message || 'Unknown error'}`));
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

async function createIssue(issueData) {
  const path = '/issues';

  const body = {
    fields: {
      project: { key: config.jiraProjectKey },
      summary: issueData.summary,
      description: issueData.description || '',
      issuetype: { name: issueData.type },
      priority: issueData.priority || { name: 'Medium' },
      labels: issueData.labels || [],
      assignee: issueData.assignee ? { name: issueData.assignee } : undefined,
      parent: issueData.parent ? { key: issueData.parent } : undefined
    }
  };

  // Remove undefined fields
  Object.keys(body.fields).forEach(key => {
    if (body.fields[key] === undefined) delete body.fields[key];
  });

  try {
    const result = await makeJiraRequest('POST', path, body);
    const key = result.data.key;
    log(`Created ${issueData.type}: ${key}`, 'success');
    return key;
  } catch (error) {
    log(`Failed to create ${issueData.type}: ${error.message}`, 'error');
    throw error;
  }
}

async function transitionIssue(issueKey, status) {
  log(`Transitioning ${issueKey} to ${status}...`, 'info');

  try {
    // Get available transitions
    const path = `/issues/${issueKey}/transitions`;
    const result = await makeJiraRequest('GET', path);

    const transition = result.data.transitions.find(
      t => t.to.name.toUpperCase() === status.toUpperCase()
    );

    if (!transition) {
      log(`Status ${status} not available for ${issueKey}`, 'warning');
      return;
    }

    // Execute transition
    await makeJiraRequest('POST', path, { transition: { id: transition.id } });
    log(`${issueKey} transitioned to ${status}`, 'success');
  } catch (error) {
    log(`Failed to transition ${issueKey}: ${error.message}`, 'warning');
  }
}

async function addComment(issueKey, comment) {
  const path = `/issues/${issueKey}/comments`;

  try {
    await makeJiraRequest('POST', path, {
      body: {
        content: [
          {
            type: 'paragraph',
            content: [
              {
                type: 'text',
                text: comment
              }
            ]
          }
        ]
      }
    });
    log(`Added comment to ${issueKey}`, 'success');
  } catch (error) {
    log(`Failed to add comment to ${issueKey}: ${error.message}`, 'warning');
  }
}

async function linkIssues(issueKey1, issueKey2, linkType = 'relates to') {
  const path = '/issueLink';

  try {
    await makeJiraRequest('POST', path, {
      type: { name: linkType },
      inwardIssue: { key: issueKey1 },
      outwardIssue: { key: issueKey2 }
    });
    log(`Linked ${issueKey1} to ${issueKey2}`, 'success');
  } catch (error) {
    log(`Failed to link issues: ${error.message}`, 'warning');
  }
}

// ============================================================================
// FEATURE DECOMPOSITION
// ============================================================================

function parseStoriesFromArgs(storiesArg) {
  if (!storiesArg) return [];

  // Handle both formats:
  // "API,UI,Tests" or "API Endpoint:5,UI Component:3"
  return storiesArg.split(',').map(story => {
    const parts = story.trim().split(':');
    return {
      title: parts[0].trim(),
      points: parts[1] ? parseInt(parts[1]) : config.storyPoints
    };
  });
}

function getDefaultStories() {
  return [
    { title: 'Backend Implementation', points: 5 },
    { title: 'Frontend Implementation', points: 3 },
    { title: 'Testing & Documentation', points: 2 }
  ];
}

// ============================================================================
// MAIN EXECUTION
// ============================================================================

async function main() {
  const args = parseArgs(process.argv.slice(2), {
    e: 'epic',
    s: 'stories',
    a: 'assignees',
    d: 'description',
    h: 'help'
  }, ['help']);

  if (args.help) {
    console.log(`
Auto-Jira Script

Usage:
  node scripts/auto-jira.js [options]

Options:
  --epic, -e         Epic name (required)
  --stories, -s      Stories (comma-separated, optional)
                     Format: "Story 1,Story 2" or "Story 1:5,Story 2:3"
                     (number = story points)
  --assignees, -a    Assignees (comma-separated, optional)
  --description, -d  Epic description
  --help, -h         Show this help

Examples:
  node scripts/auto-jira.js \\
    --epic "Add date filtering to reports" \\
    --stories "API Endpoint:5,UI Component:3,Tests:2" \\
    --assignees "backend-expert,frontend-expert"

  npm run auto-jira -- \\
    --epic "Feature name" \\
    --description "Long description here"
    `);
    process.exit(0);
  }

  // Validate inputs
  if (!args.epic) {
    log('Missing required option: --epic', 'error');
    process.exit(1);
  }

  const epicName = args.epic;
  const stories = parseStoriesFromArgs(args.stories) || getDefaultStories();
  const assignees = args.assignees ? args.assignees.split(',').map(a => a.trim()) : [];
  const description = args.description || `Auto-created feature: ${epicName}`;

  log('Auto-Jira Script Starting...', 'info');
  log(`Project: ${config.jiraProjectKey}`, 'info');

  // ========================================================================
  // CREATE EPIC
  // ========================================================================

  log('\n=== CREATING EPIC ===', 'info');

  let epicKey;
  try {
    epicKey = await createIssue({
      type: 'Epic',
      summary: epicName,
      description,
      labels: ['feature', 'auto-created'],
      priority: 'High'
    });
  } catch (error) {
    log('Failed to create epic', 'error');
    process.exit(1);
  }

  // ========================================================================
  // CREATE STORIES
  // ========================================================================

  log('\n=== CREATING STORIES ===', 'info');

  const storyKeys = [];
  const assigneeIndex = 0;

  for (let i = 0; i < stories.length; i++) {
    const story = stories[i];
    const assignee = assignees.length > 0 ? assignees[i % assignees.length] : null;

    try {
      const storyKey = await createIssue({
        type: 'Story',
        summary: story.title,
        description: `Story for: ${epicName}`,
        parent: epicKey,
        labels: ['auto-created'],
        assignee,
        priority: 'High'
      });

      storyKeys.push(storyKey);
    } catch (error) {
      log(`Failed to create story: ${story.title}`, 'error');
    }
  }

  // ========================================================================
  // LINK ISSUES
  // ========================================================================

  log('\n=== LINKING ISSUES ===', 'info');

  for (const storyKey of storyKeys) {
    await linkIssues(epicKey, storyKey, 'relates to');
  }

  // ========================================================================
  // ADD COMMENTS
  // ========================================================================

  log('\n=== ADDING COMMENTS ===', 'info');

  const commitSha = execSync('git rev-parse HEAD', {
    encoding: 'utf-8'
  }).trim();

  const branch = execSync('git rev-parse --abbrev-ref HEAD', {
    encoding: 'utf-8'
  }).trim();

  const comment = `Auto-created feature epic

Branch: ${branch}
Initial commit: ${commitSha.slice(0, 7)}
Created by: agent-orchestrator

Stories: ${storyKeys.join(', ')}`;

  await addComment(epicKey, comment);

  // ========================================================================
  // SUCCESS
  // ========================================================================

  log('\n=== SUCCESS ===', 'success');
  log(`Epic: ${epicKey}`, 'success');
  log(`Stories: ${storyKeys.join(', ')}`, 'success');
  log(`Total: ${storyKeys.length} story(ies) created`, 'success');

  // Output JSON for other scripts
  const output = {
    epic: epicKey,
    stories: storyKeys,
    branch,
    commit: commitSha.slice(0, 7)
  };

  console.log('\nJSON Output:');
  console.log(JSON.stringify(output, null, 2));

  process.exit(0);
}

// ============================================================================
// ENTRY POINT
// ============================================================================

main().catch((error) => {
  log(`Fatal error: ${error.message}`, 'error');
  process.exit(1);
});
