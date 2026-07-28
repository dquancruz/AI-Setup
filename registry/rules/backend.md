---
paths: ["src/api/**", "src/services/**", "src/modules/**"]
---
# Backend Conventions

- Validate all input with Zod (TS) or Pydantic (Python) — never trust external data without a schema.
- Typed errors, never `throw new Error("generic message")`.
- Don't leak stack traces to the client — use safe error messages.
- Soft deletes by default — no physical `DELETE` except by explicit exception.
- Pagination is mandatory on endpoints that return collections.
- Rate limiting on public routes (auth, registration, contact).
