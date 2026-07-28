---
paths: ["src/api/**", "src/auth/**", "src/middleware/**", "infra/**", "cdk/**"]
---
# Security Rules

- Never commit secrets, tokens, or credentials — use `.env.local` (gitignored).
- Auth: use `argon2id` or `bcrypt` for hashing; never MD5/SHA1 for passwords.
- JWT: validate signature, expiration, and audience on every request.
- NoSQL: parameterize queries — never interpolate user input into MongoDB filters.
- IAM: least privilege — no wildcards in actions or resources.
- S3: no public buckets except explicitly public static assets.
- Secrets in AWS Secrets Manager or SSM Parameter Store, never in process env.
- On changes to this area: invoke `security-expert` for a deep review.
