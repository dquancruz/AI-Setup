---
name: pr-formatter
description: Formatea descripciones de pull requests en el estándar propio del proyecto (What/Why/Testing/Related). Usar cuando se va a crear un PR o cuando pr-manager necesite generar la descripción.
argument-hint: --branch feat/add-auth --jira PROJ-123
tools: [Bash, Read]
tier: core
---

# PR Description Formatter

## Formato estándar del proyecto

```
[EMOJI] [TYPE] | [DESCRIPCIÓN] [TICKET]

## What
- Cambio 1
- Cambio 2

## Why
Razón del cambio y problema resuelto.

## Testing
- [ ] Tests unitarios pasan
- [ ] Tests de integración pasan
- [ ] Probado en branch feature (no main)

## Related
- Jira: [PROJ-123](url)
- PR relacionado: #456
```

## Emojis por tipo
- ✨ feat | 🐛 fix | ♻️ refactor | 📚 docs | 🚀 perf | 🧪 test | 🔧 chore

## Reglas
- Título = commit principal del branch
- What = lista de cambios concretos
- Why = problema que resuelve, NO qué hizo
- Testing = checklist ejecutable por el reviewer
- Siempre linkear Jira

## Invocación via pr-manager
```bash
npm run auto-pr -- --branch $(git branch --show-current) --jira PROJ-123
```
