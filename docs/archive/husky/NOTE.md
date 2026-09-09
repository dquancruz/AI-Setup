# Archived — Husky git hook templates

Retired in Fase 4.1 of `update-plan-aug-2026.md` (2026-08-26).

These four files (`pre-commit`, `prepare-commit-msg`, `post-merge`, `pre-tag`)
plus `.gitignore` were `setup-repo.sh`'s old `.husky/*` templates. They
required target repos to `npm install --save-dev husky` and run
`npx husky install` before any hook actually fired — a hard Node/npm
dependency for a setup that also targets non-Node stacks (FastAPI, Raspberry
Pi).

Replaced by `registry/templates/githooks/`, installed via
`git config core.hooksPath .githooks` — a plain git feature, no npm install,
no extra binary. `pre-commit`, `prepare-commit-msg`, and `post-merge` moved
over unchanged (they're already portable `sh`, Husky was only ever the
delivery mechanism). `pre-tag` did not move over as-is: **git has no
built-in `pre-tag` hook event**, so this file was silently never invoked by
`git tag` even when Husky was installed — an existing bug, not something
this migration introduced. Its logic (tag format, final tests, clean working
tree) was ported to `pre-push`, the real hook that fires when a tag is
pushed to a remote (see `registry/templates/githooks/pre-push`'s own header
for the stdin contract).

Kept here, unmodified below, as a historical record only — do not copy these
back into `registry/templates/`.
