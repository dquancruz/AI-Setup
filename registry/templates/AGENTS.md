# <Project Name>

> One line: what this repo is.

## Tech Stack
- Runtime: <Node.js 20 / Python 3.12>
- Framework: <Next.js 15 / FastAPI>
- Database: <MongoDB / PostgreSQL>
- Testing: <Jest / pytest>
- Infra: <AWS + CDK>

## Commands
- Build:  `npm run build`
- Test:   `npm test`
- Lint:   `npm run lint`
- Deploy: `npm run deploy`
- Auto-commit: `npm run auto-commit -- --help`

## Architecture
- `src/api/`        → endpoints and backend logic
- `src/components/` → UI components
- `scripts/`        → automation (auto-commit, auto-pr, auto-jira)
- See `docs/` for detailed architecture.

## Conventions
- Detailed conventions per domain (backend, frontend, testing, security, design) live in `.claude/rules/*.md` — they load automatically by path, not repeated here.
- <Project-specific convention not covered by the rules, if any>
- Commits: Conventional Commits (see the `semantic-versioning` skill).
- Commit/PR style: plain   <!-- plain | emoji — plain is the default (professional, no emoji in commits or PR titles). Set to `emoji` only if you explicitly want emoji during this project's initial bootstrap phase; switch back to `plain` once the project stabilizes. -->
- Local context: see `.local-docs/` (gitignored — plan, architecture, security gaps, decisions). Keep it current: when something it documents changes, update that entry in place instead of leaving it stale. See the `local-docs` skill.

## Agent workflow (Claude Code)
Subagents live in `~/.claude/agents/`. On other tools, replicate the flow manually following the decision tree below.

### Decision tree: which agent to use
```
What do you need?
- Design architecture / decide the approach      → solutions-expert
- Generate a Jira ticket hierarchy               → ticket-orchestrator
- Backend API (NestJS/FastAPI/Mongo)              → backend-expert
- IoT backend (Raspberry Pi/GPIO/edge)            → iot-backend-expert
- Frontend (React/Next/Astro + a11y)              → frontend-expert
- AWS architecture                                → aws-architect
- Infra as Code (CDK)                             → cdk-expert
- Write/strengthen unit tests                     → test-engineer
- Create a PR (project's standard format)         → pr-manager
- General review + light scanning                 → code-reviewer-pro
- Deep security (auth/crypto/IAM)                 → security-expert
- Docs + versioning + releases                    → documentation-generator
- Orchestrate several of the above                → agent-orchestrator
```

Typical pipeline: solutions-expert → (backend|frontend) → test-engineer → code-reviewer-pro → pr-manager.

> `test-engineer` = coverage and test quality for the code backend/frontend/iot-backend-expert just wrote (always, before general review).
> `code-reviewer-pro` = general review with light scanning (always).
> `security-expert` = deep escalation: only when it touches auth, sensitive data, crypto, secrets, network, or IaC.

## Critical rules
- NEVER push directly to `main`.
- NEVER commit `.env.local` or secrets.
- ALWAYS run lint + tests before a PR.
- Bounded scope: investigations >50 files → spawn a subagent, don't do it in the main context.
