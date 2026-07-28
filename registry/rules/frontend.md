---
paths: ["src/components/**", "src/pages/**", "src/app/**", "src/ui/**"]
---
# Frontend Conventions

- Server Components by default; `'use client'` only when necessary.
- Accessibility is not optional: WCAG AA minimum, semantic HTML, keyboard navigation.
- No `any` in TypeScript — if something requires `any`, use `unknown` with explicit narrowing.
- No `console.log` in committed code.
- Responsive from mobile-first.
- See the `design-system` skill for active design presets.
