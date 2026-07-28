# <Nombre del Proyecto>

> Una línea: qué es este repo.

## Tech Stack
- Runtime: <Node.js 20 / Python 3.12>
- Framework: <Next.js 15 / FastAPI>
- Base de datos: <MongoDB / PostgreSQL>
- Testing: <Jest / pytest>
- Infra: <AWS + CDK>

## Comandos
- Build:  `npm run build`
- Test:   `npm test`
- Lint:   `npm run lint`
- Deploy: `npm run deploy`
- Auto-commit: `npm run auto-commit -- --help`

## Arquitectura
- `src/api/`        → endpoints y lógica de backend
- `src/components/` → componentes de UI
- `scripts/`        → automatización (auto-commit, auto-pr, auto-jira)
- Ver `docs/` para arquitectura detallada.

## Convenciones
- Convenciones detalladas por dominio (backend, frontend, testing, security, design) viven en `.claude/rules/*.md` — se cargan automáticamente por path, no se repiten aquí.
- <Convención específica de este proyecto no cubierta por las rules, si aplica>
- Commits: Conventional Commits (ver skill `semantic-versioning`).

## Workflow de agentes (Claude Code)
Los subagentes residen en `~/.claude/agents/`. En otras herramientas, replicar el flujo manualmente siguiendo el árbol de decisión abajo.

### Árbol de decisión: cuándo usar cuál agente
```
¿Qué necesitas?
- Diseñar arquitectura / decidir el enfoque   → solutions-expert
- Generar jerarquía de tickets Jira           → ticket-orchestrator
- Backend API (NestJS/FastAPI/Mongo)          → backend-expert
- Backend IoT (Raspberry Pi/GPIO/edge)        → iot-backend-expert
- Frontend (React/Next/Astro + a11y)          → frontend-expert
- Arquitectura AWS                            → aws-architect
- Infra as Code (CDK)                         → cdk-expert
- Escribir/reforzar tests unitarios           → test-engineer
- Crear PR (formato estándar del proyecto)    → pr-manager
- Review general + scanning ligero            → code-reviewer-pro
- Seguridad profunda (auth/crypto/IAM)        → security-expert
- Docs + versionado + releases                → documentation-generator
- Orquestar varios de los anteriores          → agent-orchestrator
```

Pipeline típico: solutions-expert → (backend|frontend) → test-engineer → code-reviewer-pro → pr-manager.

> `test-engineer` = cobertura y calidad de tests del código que acaban de escribir backend/frontend/iot-backend-expert (siempre, antes del review general).
> `code-reviewer-pro` = review general con scanning ligero (siempre).
> `security-expert` = escalamiento profundo: solo cuando toca auth, datos sensibles, cripto, secretos, red o IaC.

## Reglas críticas
- NUNCA hacer push directo a `main`.
- NUNCA commitear `.env.local` ni secretos.
- SIEMPRE correr lint + tests antes de un PR.
- Scope acotado: investigaciones >50 archivos → spawn de subagente, no en el contexto principal.
