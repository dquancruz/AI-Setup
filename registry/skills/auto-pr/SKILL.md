---
name: auto-pr
description: Guía para crear PRs automáticamente via script. Usar cuando los commits están en un feature branch, los tests pasan en CI, y es momento de abrir el PR en GitHub.
argument-hint: --branch feat/add-auth --jira PROJ-123 --draft
tools: [Bash]
tier: core
---

# Auto-PR Creation Guide

## Prerequisitos antes de crear el PR
- [ ] Feature branch (NUNCA crear PR desde main)
- [ ] Todos los tests pasan en CI
- [ ] Cobertura de tests validada (test-engineer)
- [ ] Code review completado (code-reviewer-pro)
- [ ] Sin secretos hardcodeados

## Comando
```bash
npm run auto-pr -- \
  --branch $(git branch --show-current) \
  --jira PROJ-123 \
  --title "feat(api): add date filter [PROJ-123]"
```

## Lo que hace el script
1. Verifica que el branch NO es main
2. Hace push del branch si no existe en origin
3. Crea el PR via GitHub API con la descripción formateada (ver skill `pr-formatter`)
4. Asigna reviewers (test-engineer, code-reviewer-pro)
5. Linkea el ticket Jira

## Título del PR
Idéntico al commit principal del branch:
```
✨ Feature | Add date filter [PROJ-123]
```

## Labels automáticos
- `feature` para feat:
- `bug` para fix:
- `refactor` para refactor:
- `wip` si se crea como draft

## Reglas
- NUNCA push directo a main — siempre por PR
- Draft PR si el trabajo no está completo
- Asignar al menos un reviewer
