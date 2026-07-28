---
name: jira-integration
description: Patterns for Jira integration: creating epics/stories/tasks, transitioning states, linking commits, and auto-closing tickets on merge. Use when ticket-orchestrator generates a hierarchy or when auto-jira.js needs to talk to Jira.
argument-hint: --epic "Epic name" --project PROJ
tools: [Bash, Read]
tier: core
---

# Jira Integration Patterns

## Ticket hierarchy
```
Epic (PROJ-120)
├─ Story (PROJ-121): API Endpoint
│  ├─ Task (PROJ-121a): Define the contract
│  ├─ Task (PROJ-121b): Implement
│  └─ Task (PROJ-121c): Tests + docs
└─ Story (PROJ-122): UI Component
   ├─ Task (PROJ-122a): Approved wireframe
   ├─ Task (PROJ-122b): Implement the component
   └─ Task (PROJ-122c): Accessibility tests
```

## Creating via MCP (Claude Code)
```
Use the Jira MCP to:
- Create an Epic with title, description, and sprint
- Create Stories under the Epic with acceptance criteria
- Create Tasks under each Story with estimates
```

## State transitions
- `To Do` → `In Progress` (when work starts)
- `In Progress` → `In Review` (when the PR opens)
- `In Review` → `Done` (when the PR merges)

## Linking commits to Jira
Include the ticket in the commit message:
```
feat(api): add date filter [PROJ-123]
```
The `prepare-commit-msg` hook automatically extracts the number from the branch name.

## Auto-close on merge
The `on-merge.yml` workflow transitions the ticket to Done when it detects `[PROJ-XXX]` in the PR title.

## Rules
- One Story = one deliverable unit of value
- One Task = max 2-4 hours of work
- Epic = no more than 2 weeks of work
