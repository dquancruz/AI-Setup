---
paths: ["src/components/**", "src/app/**", "src/ui/**", "src/styles/**"]
---
# Design Direction

Design preset: quiet

<!-- Replace "quiet" with the client's preset: velocity | vice | quiet -->
<!-- Or copy the client's real tokens here: -->
<!-- Primary: #hex, Font: "Name", Scale: 1.250 -->

## Preset selection
The frontend-expert agent always loads the `design-system` skill when doing UI work.
Priority order: (1) preset named in the prompt → (2) `Design preset:` in this rule → (3) default `quiet` with a notice.
