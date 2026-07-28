---
paths: ["src/**/*.test.*", "src/**/*.spec.*", "tests/**", "__tests__/**"]
---
# Testing Conventions

- No `.only()` or `.skip()` in committed tests.
- Minimum coverage: 80% (target: 90%).
- Integration tests do NOT mock the database — they must use a real or test instance.
- One test per business case, not per line of code.
- Test names in the format: `describe("what") → it("does what when condition")`.
