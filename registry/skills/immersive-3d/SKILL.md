---
name: immersive-3d
description: 3D/WebGL techniques for immersive frontend experiences. Load when the active preset is velocity or vice, or when the user asks for 3D effects, WebGL, animated canvas, or immersive experiences.
argument-hint: --preset velocity|vice --component hero|background|product
tools: [Read, Edit, Write]
tier: extended
---

# Immersive 3D — WebGL on the Frontend

## Recommended stack
- **R3F (React Three Fiber)** — declarative 3D in React
- **@react-three/drei** — helpers (Environment, Float, Text3D, etc.)
- **three.js** — underlying base
- **Lenis + GSAP** — smooth scroll + camera animations
- **@react-three/postprocessing** — effects (bloom, DOF, noise)
- **Rive** — lightweight 2.5D alternative for interactive animation without heavy WebGL

## 3D by preset

### velocity
```
Real-time interactive 3D object in the hero.
Reacts to scroll (camera dolly) or mouse (rotation).
Post-processing: subtle edge bloom.
Performance: max 60fps on desktop, degrade on mobile.
```

### vice
```
Cinematic atmosphere with background video + ambient WebGL effects.
Noise shader, dramatic bloom, vignette.
Parallax on scroll — depth layers.
Optional audio (only with explicit user consent).
```

### quiet
```
No 3D — don't use this skill with the quiet preset.
Alternative: pure CSS micro-animations if subtle motion is requested.
```

## Critical asset caveat
The agent **integrates** 3D models (GLTF/GLB) — it does **NOT** generate them.
Alternatives when there are no assets:
- Procedural geometry (BoxGeometry, SphereGeometry, TorusKnot)
- Custom shaders (noise, gradient, plasma)
- Rive for 2.5D without a model

## Performance and fallbacks

```jsx
// Lazy-load the canvas
const Scene = dynamic(() => import('./Scene'), {
  ssr: false,
  loading: () => <StaticHeroFallback />
})

// Respect prefers-reduced-motion
const prefersReduced = window.matchMedia('(prefers-reduced-motion: reduce)').matches
if (prefersReduced) return <StaticVersion />
```

## Performance budget
- < 2MB total 3D assets (compressed with draco/meshopt)
- < 150 draw calls per scene
- 60fps on mid-range GPU (GTX 1060 / M1)
- Degrade to a static image on old integrated GPUs

## Rules
- ALWAYS lazy-load the canvas (don't block LCP)
- ALWAYS provide a static fallback for `prefers-reduced-motion`
- ALWAYS degrade gracefully on mobile (image or simplified version)
- NEVER autoplay audio without user interaction
