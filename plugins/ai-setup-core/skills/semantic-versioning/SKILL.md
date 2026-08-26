---
name: semantic-versioning
description: Detects the correct version bump (MAJOR/MINOR/PATCH) from commits, updates package.json, generates the CHANGELOG, creates the git tag, and publishes the GitHub Release. Use when doing a release or when documentation-generator asks for a version bump.
argument-hint: --dry-run
tools: [Bash, Read, Edit]
tier: core
---

# Semantic Versioning Control

## SemVer: MAJOR.MINOR.PATCH

- **MAJOR** — breaking changes (`feat!:`, `BREAKING CHANGE:`)
- **MINOR** — new backward-compatible functionality (`feat:`)
- **PATCH** — bug fixes (`fix:`, `perf:`, `refactor:`)

## Automatic detection from commits
```bash
# See commits since the last tag
git log $(git describe --tags --abbrev=0)..HEAD --oneline

# If there's feat!: or BREAKING CHANGE → MAJOR
# If there's feat: → MINOR
# If there's only fix:/chore:/docs: → PATCH
```

## Release flow
1. `npm version <major|minor|patch>` — bump package.json + tag
2. Update `CHANGELOG.md` with the period's changes
3. `git push && git push --tags`
4. Create a GitHub Release with the CHANGELOG notes

## CHANGELOG format (Keep a Changelog)

An `[Unreleased]` scaffold always sits at the top of the file, categories
empty until something lands. Entries are sourced from the merged PR's title
+ `## Why` section (not raw commit subjects) — description, PR link, Jira
key(s) — and land under the matching category, then get cut into the new
dated version section right below `[Unreleased]`:

```markdown
## [Unreleased]
### Added
### Changed
### Fixed
### Security
### Deprecated

## [1.2.0] - 2026-06-29
### Added
- Feature description ([#101](url), PROJ-101) — why it was needed

### Fixed
- Fix description ([#102](url), PROJ-102) — what was broken
```

## Anti-patterns
- ❌ Never skip versions (from 1.0 to 2.0 with no intermediate 1.x)
- ❌ Never downgrade the version
- ❌ Tag on main without going through a PR
