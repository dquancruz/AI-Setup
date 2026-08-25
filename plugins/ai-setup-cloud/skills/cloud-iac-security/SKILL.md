---
name: cloud-iac-security
description: Security for IaC (AWS CDK) and cloud services. Use when security-expert or cdk-expert review CDK stacks, IAM configuration, S3, Lambda, or any cloud resource. Applies least privilege, encryption, and segmentation by default.
argument-hint: --focus iam|s3|lambda|vpc|secrets
tools: [Read, Grep, Edit]
tier: extended
---

# Cloud & IaC Security

## Principle: Defense in Depth + Least Privilege

## IAM — Never wildcards
```typescript
// ❌ Too permissive
new iam.PolicyStatement({ actions: ['*'], resources: ['*'] })

// ✅ Least privilege
new iam.PolicyStatement({
  actions: ['s3:GetObject', 's3:PutObject'],
  resources: [`${bucket.bucketArn}/uploads/*`],
})
```

### Lambda roles
- Create a specific role per Lambda, never share
- Only the permissions that Lambda actually needs

## S3 — No public access by default
```typescript
const bucket = new s3.Bucket(this, 'DataBucket', {
  blockPublicAccess: s3.BlockPublicAccess.BLOCK_ALL,
  encryption: s3.BucketEncryption.S3_MANAGED,
  enforceSSL: true,
  versioned: true,
})
```

## Encryption
- **At rest:** S3 (SSE-S3 minimum, SSE-KMS for sensitive data), RDS, EBS
- **In transit:** TLS 1.2+, `enforceSSL: true` on S3, HTTPS on API Gateway

## Secrets — Secrets Manager, not process env
```typescript
// ❌ Secret in Lambda env
environment: { DB_PASSWORD: 'my-secret-password' }

// ✅ Secrets Manager
const secret = secretsmanager.Secret.fromSecretNameV2(this, 'DBSecret', 'prod/db/password')
secret.grantRead(lambdaFn)
```

## VPC and networking
- Lambdas that access a DB → inside a private VPC
- Security Groups: only necessary ports, never `0.0.0.0/0` on inbound
- RDS: private subnet group, no public access

## CloudTrail — Logging
```typescript
new cloudtrail.Trail(this, 'AuditTrail', {
  sendToCloudWatchLogs: true,
  includeGlobalServiceEvents: true,
  isMultiRegionTrail: true,
})
```

## cdk-nag — Automated checks
```typescript
import { AwsSolutionsChecks } from 'cdk-nag'
Aspects.of(app).add(new AwsSolutionsChecks({ verbose: true }))
```
Integrate into CI: if cdk-nag fails → the deploy fails.

## Pre-deploy checklist
- [ ] IAM with no wildcards
- [ ] S3 with `BLOCK_ALL` public access
- [ ] Encryption at rest on every store
- [ ] Secrets in Secrets Manager / SSM
- [ ] Restrictive Security Groups
- [ ] CloudTrail active
- [ ] cdk-nag with no errors
