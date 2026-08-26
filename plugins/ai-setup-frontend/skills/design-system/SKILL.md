---
name: design-system
description: Registry of design presets and UI principles. ALWAYS load when doing frontend/UI work. Defines the velocity/vice/quiet presets with their tokens (color, typography, scale, motion) and the universal anti-patterns.
argument-hint: --preset velocity|vice|quiet
tools: [Read, Edit]
tier: core
---

# Design System — Presets

## How to activate a preset
1. Named in the prompt: "use the vice preset"
2. Declared in `.claude/rules/design.md`: `Design preset: velocity`
3. Default: `quiet` (tell the user)

Presets are a **starting point, not law**: hex/fonts/scales are adaptable;
anti-patterns and accessibility are firm.

---

## Preset: `velocity`
> Energy, speed, action. For SaaS apps, dashboards, tools.

```
Color:      Contrasting palette with an electric accent (electric blue / neon green)
Typography: Heavy geometric sans-serif (Geist, Inter, Space Grotesk)
Scale:      1.333 (Perfect Fourth) — clear hierarchy
Motion:     Fast transitions (150ms), micro-animations on hover
Signature:  Real-time 3D object or data animation in the hero
```

## Preset: `vice`
> Atmosphere, drama, luxury. For premium brands, landing pages, portfolios.

```
Color:      Dark palette with neon gradients (magenta/cyan/violet)
Typography: Editorial serif or dramatic display (Playfair, Bodoni, custom)
Scale:      1.618 (Golden Ratio) — extreme weights
Motion:     Cinematic (600ms+), parallax, reveal on scroll
Signature:  Background video + ambient WebGL effects (noise, bloom)
```

## Preset: `quiet`
> Clarity, breathing room, trust. For docs, B2B SaaS, enterprise tools.

```
Color:      Neutrals with a single accent (no more than 2 colors)
Typography: Legible neutral sans-serif (Inter, IBM Plex, Sora)
Scale:      1.250 (Major Third) — restrained
Motion:     Minimal or none (functional feedback only)
Signature:  Typography with personality — the text IS the design
```

---

## Universal principles

### Hero as thesis
The hero isn't a welcome message — it's the value proposition. The user should understand in 3 seconds what the product does and why they should care.

### Typography with personality
Use weight and size to create drama. Mix extreme weights (900 + 300) within the same font.

### Spend the boldness on the signature
One bold signature element (3D, video, dramatic animation) + everything else calm. Don't compete everywhere.

---

## Anti-patterns (firm — never do)
- ❌ Generic stock photos or personality-free flat illustrations
- ❌ More than 3 primary colors
- ❌ Animation without purpose (movement for movement's sake)
- ❌ Illegible text over an image with no overlay
- ❌ Ignoring `prefers-reduced-motion`
- ❌ Mobile as an afterthought

## Quality floor (always)
- WCAG AA text contrast
- Visible focus for keyboard navigation
- Respect `prefers-reduced-motion`
- Functional without JavaScript (enhanced, not dependent)
