# GitHub Actions Setup

Two workflows automate validation and release:

- **pr-validation.yml** — runs on every PR (tests, lint, type-check, code review)
- **on-merge.yml** — runs when a PR merges to main (version bump, release, Jira)

## Why Actions instead of local hooks

Local Husky hooks only run on YOUR machine and only for LOCAL git commands.
When you merge a PR using the GitHub web UI, the merge happens on GitHub's
servers, so local hooks never fire. GitHub Actions run on GitHub's servers, so
they fire no matter how or where the merge happens. That's why versioning,
releases, and Jira updates live in Actions, not in the local hooks.

| | Local hooks (.husky) | GitHub Actions |
|---|---|---|
| Where it runs | Your machine | GitHub servers |
| Merge via web UI | Does NOT fire | Fires |
| Merge via terminal | Fires | Fires |
| Needs your machine on | Yes | No |

Keep the local hooks for fast feedback while you work (pre-commit validation),
and let Actions handle anything that must happen on merge.

## Installation

Copy the workflows into your repo:

```bash
mkdir -p .github/workflows
cp /path/to/AI-Setup/per-repo/.github/workflows/*.yml .github/workflows/
git add .github/workflows/
git commit -m "ci: add PR validation and release workflows"
git push
```

## Required Secrets

Actions can't read your local `.env.local` — secrets must be added to GitHub.

Go to: **your repo → Settings → Secrets and variables → Actions → New repository secret**

Add these:

| Secret | Value | Used for |
|--------|-------|----------|
| `JIRA_HOST` | yourname.atlassian.net | Jira API calls |
| `JIRA_EMAIL` | your-email@example.com | Jira auth |
| `JIRA_API_TOKEN` | your Jira token | Jira auth |

You do NOT need to add `GITHUB_TOKEN` — GitHub provides it automatically to
every workflow run.

## What pr-validation.yml does

On every PR to main:

1. **validate job** — installs deps, runs `npm test`, `npm run lint`,
   `npm run type-check`
2. **code-review job** (only if validate passed) — scans the diff for
   hardcoded secrets and leftover debug code

If any required check fails, the PR shows a red X and (with branch protection)
can't be merged.

## What on-merge.yml does

When a PR is actually merged (not just closed) to main:

1. Runs tests once more on main
2. Detects the version bump from commit messages:
   - `feat:` → minor
   - `fix:` → patch
   - `BREAKING CHANGE` or `!:` → major
3. Calculates the new version from the last tag
4. Updates `package.json`
5. Generates a CHANGELOG entry
6. Commits the bump (`chore(release): vX.Y.Z [skip ci]`)
7. Creates a git tag and a GitHub Release
8. For each Jira key found in the PR title/branch (e.g. PROJ-123):
   - Adds a comment ("Merged in PR #N and released in vX.Y.Z")
   - Transitions the ticket to Done

## Required npm scripts

The workflows call these — make sure they exist in package.json:

```json
{
  "scripts": {
    "test": "your test command",
    "lint": "your lint command",
    "type-check": "tsc --noEmit"
  }
}
```

If a script doesn't apply to your project, remove that step from the workflow
or make it a no-op (e.g. `"lint": "echo skip"`).

## Branch Protection (makes validation a real gate)

For the PR checks to actually block merging:

**Settings → Branches → Add branch protection rule**

- Branch name pattern: `main`
- ☑ Require a pull request before merging
- ☑ Require status checks to pass before merging
  - Select: `Validate PR` and `Automated Code Review`
- (Optional, team only) ☑ Require approvals: 1

Note: in a personal repo you can't approve your own PR, so leave "Require
approvals" off until you have collaborators. The status checks still work and
still block on failing tests.

## How the Jira "Done" transition works

The workflow looks for a transition literally named "Done" on the issue. If
your Jira workflow uses a different name (e.g. "Closed", "Resolved"), edit the
grep in the "Update Jira tickets" step of on-merge.yml to match your status
name.

## Testing the workflows

1. Create a branch with a Jira key: `git checkout -b feat/PROJ-1-test`
2. Make a small change, commit with `feat: test actions`
3. Push and open a PR → watch **pr-validation** run in the Actions tab
4. Merge the PR → watch **on-merge** run: new tag, release, and Jira update

If something fails, the Actions tab shows the full log of which step broke.
