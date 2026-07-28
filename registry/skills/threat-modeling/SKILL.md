---
name: threat-modeling
description: Threat modeling with STRIDE, trust boundaries, and attack-surface analysis. Run in the DESIGN phase alongside solutions-expert, before implementing. Produces a threat model with ranked risks and concrete mitigations.
argument-hint: --component auth|api|infra|iot
tools: [Read, Write]
tier: extended
---

# Threat Modeling — STRIDE

## When to run it
During design (with solutions-expert), not during implementation. If the change touches auth, sensitive data, public network surface, or IaC, run this analysis first.

## STRIDE
| Threat | Description | Example |
|---------|-------------|---------|
| **S**poofing | Impersonating identity | Fake JWT, session hijacking |
| **T**ampering | Modifying data | IDOR parameter, body injection |
| **R**epudiation | Denying actions | No audit logs |
| **I**nformation Disclosure | Exposing data | Stack trace to the client, public S3 |
| **D**enial of Service | Disrupting service | No rate limit, memory leak |
| **E**levation of Privilege | Escalating permissions | Poorly implemented RBAC |

## Process (4 steps)

### 1. Map the system
- Diagram the data flow (simple DFD): actors → components → data
- Identify trust boundaries (internet ↔ API, API ↔ DB, user ↔ admin)
- List sensitive data (PII, tokens, credentials, business data)

### 2. Identify threats
For each component, apply STRIDE systematically.

### 3. Rank by risk
```
Risk = Impact × Likelihood
- CRITICAL: high impact + high likelihood → mitigate before launch
- HIGH: high impact + medium likelihood → mitigate in the current sprint
- MEDIUM: mitigate in the priority backlog
- LOW: accept or monitor
```

### 4. Define mitigations
For each CRITICAL/HIGH threat: which technical control mitigates it and who implements it.

## Notes by domain

**REST/GraphQL API:** IDOR in parameters, injection in filters, rate limiting, CORS
**Frontend:** XSS (strict CSP), CSRF (SameSite + token), env var exposure
**IoT/Edge:** Unsigned firmware, traffic without TLS, hardcoded credentials on device
**Cloud (AWS):** IAM wildcards, public S3, secrets in Lambda env

## Expected output
```markdown
## Threat Model — [Component]
### Attack surface
- [list of inputs/outputs]
### Identified threats
| ID | Category | Description | Risk | Mitigation |
|----|-----------|-------------|--------|------------|
| T1 | Spoofing  | ...         | HIGH   | ...        |
### Next steps
- [ ] Implement [control X] — owner: backend-expert
```
