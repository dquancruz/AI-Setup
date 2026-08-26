---
name: secure-coding
description: Secure coding guide based on OWASP Top 10, mapped to this project's stack (NestJS, FastAPI, Next.js, MongoDB). Load when security-expert reviews code or when sensitive areas (auth, input handling, crypto, public APIs) are being implemented.
argument-hint: --focus injection|auth|crypto|headers
tools: [Read, Grep, Edit]
tier: extended
---

# Secure Coding — OWASP Top 10

## A01: Broken Access Control
- Verify authorization on EVERY endpoint, not just the frontend
- RBAC: validate role in middleware, not in the handler
- IDOR: always scope queries to the authenticated user
  ```typescript
  // ❌ IDOR
  const item = await db.findById(req.params.id)
  // ✅ Scoped to the user
  const item = await db.findOne({ _id: req.params.id, userId: req.user.id })
  ```

## A02: Cryptographic Failures
- Passwords: `argon2id` (preferred) or `bcrypt` (min rounds: 12). NEVER MD5/SHA1/SHA256
- Sensitive data at rest: encrypt before saving to the DB
- TLS 1.2+ mandatory; never HTTP in production
- Secrets: in Secrets Manager/SSM, never in code or process env

## A03: Injection
```typescript
// ❌ MongoDB — direct interpolation (if name = {$gt: ""} → matches everything)
db.users.find({ name: req.body.name })

// ✅ Validate with a schema first
const { name } = UserSchema.parse(req.body)
db.users.find({ name })
```
- Command injection: never `exec()` with user input; use args as an array

## A05: Security Misconfiguration
- Remove debug endpoints in production
- Headers: CSP, HSTS, X-Frame-Options, X-Content-Type-Options
  ```typescript
  app.use(helmet())  // NestJS
  ```

## A06: Vulnerable Components
- `npm audit --audit-level=high` before every release
- Dependabot/Renovate for automatic updates
- Pin versions in the lockfile

## A07: Auth Failures
- JWT: validate signature, `exp`, `aud`, `iss` on EVERY request
- Sessions: `httpOnly`, `secure`, `SameSite=Strict`
- Rate limiting on auth endpoints (login, register, reset-password)
- Lockout after N failed attempts (5-10 with exponential backoff)

## A09: Logging Failures
- Log: auth events, access to sensitive data, errors
- DO NOT log: passwords, tokens, PII, card data
- Structured logs (JSON)

## A10: SSRF
- Validate URLs before making requests from the server
- Domain whitelist; block private IPs (169.254.x.x, 10.x.x.x)

## Notes by framework

**NestJS:** global `ValidationPipe({ whitelist: true, forbidNonWhitelisted: true })`, Guards for auth/authz.

**FastAPI:** Pydantic models for all input, `Depends()` for auth, `HTTPException` for safe errors.

**Next.js:** don't expose secrets in `NEXT_PUBLIC_*`, validate in Server Actions.
