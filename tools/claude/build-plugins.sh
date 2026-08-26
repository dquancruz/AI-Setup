#!/usr/bin/env bash

# ============================================================================
# tools/claude/build-plugins.sh — registry/ -> installable Claude Code plugins
# ============================================================================
# Fase 3, update-plan-aug-2026.md (section 3.1/3.2). Generates one
# self-contained plugin directory per pack listed in registry/packs.yaml
# under plugins/<pack>/, plus .claude-plugin/marketplace.json at the repo
# root so this repo itself is an installable marketplace:
#   /plugin marketplace add dquancruz/AI-Setup
#   /plugin install ai-setup-core@ai-setup
#
# registry/ is still the SSOT — this script only copies existing
# registry/agents/*.md and registry/skills/*/SKILL.md files into per-pack
# directories per the grouping in registry/packs.yaml. No content is
# authored here.
#
# IMPORTANT EXCEPTION to this repo's usual "nothing generated is committed"
# rule (see README.md's design principle section): plugins/ and
# .claude-plugin/marketplace.json ARE committed, unlike every other
# tools/*/enable.sh output. This isn't a style inconsistency — it's forced
# by how Claude Code's GitHub-sourced marketplace plugins actually work
# (verified against code.claude.com/docs/en/plugin-marketplaces and
# code.claude.com/docs/en/plugins, 2026-08-25): `/plugin marketplace add
# owner/repo` reads static files straight out of the repo at a git ref —
# there is no build step in that flow, so the rendered output has to already
# exist in the repo for anyone to install from it. Consequence: run this
# script and commit its output whenever registry/agents, registry/skills,
# or registry/packs.yaml change. CI (.github/workflows/ci.yml) fails the
# build if plugins/ or .claude-plugin/marketplace.json are out of sync with
# what this script would generate, so drift can't merge silently.
#
# Scope note: only agents/ and skills/ are packaged (matches registry/packs.yaml
# and the Fase 3 acceptance criterion, which only tests agents+skills being
# available after `/plugin install`). Hooks and MCP servers are NOT bundled
# into these plugins — they stay exactly as they are today, rendered
# per-repo by setup-repo.sh into .claude/hooks/ and .mcp.json. The plan's own
# task breakdown (3.1-3.3) never assigns hooks/MCP a pack, so folding them in
# here would be scope creep beyond what Fase 3 actually asks for.
#
# Deterministic/reproducible (Fase 3 acceptance: "build-plugins.sh es
# reproducible, correrlo dos veces no cambia el árbol"): plugins/ and
# .claude-plugin/ are fully deleted and regenerated from scratch on every
# run, so a stale file from a since-edited packs.yaml can never linger.
#
# NOT reachable purely in bash/awk/sed like rule-to-mdc.sh / agent-to-mode.sh
# — registry/packs.yaml is real (if restricted) YAML and this needs to write
# valid JSON. Uses python3 (falls back to python/py), same 3-way fallback
# already established by tools/cursor/adapt/hook-to-cursor.sh. packs.yaml's
# schema is intentionally restricted (flat maps + flat string lists only, no
# nesting/anchors/multiline scalars) so a small hand-written parser below is
# enough — no PyYAML or other new dependency introduced.
#
# Usage:
#   build-plugins.sh <ai-setup-root>
#
# Example (as called from CI / manually from repo root):
#   tools/claude/build-plugins.sh "$(pwd)"
# ============================================================================

set -e

usage() {
  echo "Usage: build-plugins.sh <ai-setup-root>" >&2
  exit 1
}

[ $# -eq 1 ] || usage

SETUP_DIR="$1"
PACKS_YAML="$SETUP_DIR/registry/packs.yaml"
AGENTS_DIR="$SETUP_DIR/registry/agents"
SKILLS_DIR="$SETUP_DIR/registry/skills"
PLUGINS_OUT="$SETUP_DIR/plugins"
MARKETPLACE_OUT="$SETUP_DIR/.claude-plugin"

[ -f "$PACKS_YAML" ] || { echo "build-plugins.sh: not found: $PACKS_YAML" >&2; exit 1; }
[ -d "$AGENTS_DIR" ] || { echo "build-plugins.sh: not found: $AGENTS_DIR" >&2; exit 1; }
[ -d "$SKILLS_DIR" ] || { echo "build-plugins.sh: not found: $SKILLS_DIR" >&2; exit 1; }

PYTHON_BIN=""
for candidate in python3 python py; do
  if command -v "$candidate" &>/dev/null; then
    PYTHON_BIN="$candidate"
    break
  fi
done
if [ -z "$PYTHON_BIN" ]; then
  echo "build-plugins.sh: no python3/python/py found in PATH — cannot parse packs.yaml." >&2
  exit 1
fi

# Clean regenerate — see header comment on why this must be fully
# deterministic run-to-run.
rm -rf "$PLUGINS_OUT" "$MARKETPLACE_OUT"
mkdir -p "$PLUGINS_OUT" "$MARKETPLACE_OUT"

export PACKS_YAML AGENTS_DIR SKILLS_DIR PLUGINS_OUT MARKETPLACE_OUT

"$PYTHON_BIN" - <<'PYEOF'
import json
import os
import re
import shutil
import sys

packs_yaml = os.environ["PACKS_YAML"]
agents_dir = os.environ["AGENTS_DIR"]
skills_dir = os.environ["SKILLS_DIR"]
plugins_out = os.environ["PLUGINS_OUT"]
marketplace_out = os.environ["MARKETPLACE_OUT"]

# --- Minimal parser for registry/packs.yaml's restricted schema -----------
# Only handles: top-level "name:" keys, "description: \"...\"" scalar,
# "agents:"/"skills:" followed by "  - item" lines, and the empty-list
# shorthand "skills: []". Comments (full-line, starting with optional
# whitespace + '#') and blank lines are skipped. Anything else is a hard
# parse error rather than a silent misparse.
def parse_packs_yaml(path):
    packs = {}
    current_pack = None
    current_list_key = None
    with open(path, "r", encoding="utf-8") as fh:
        lines = fh.readlines()
    for lineno, raw in enumerate(lines, start=1):
        line = raw.rstrip("\n")
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue
        top_level = re.match(r"^([A-Za-z0-9_-]+):\s*$", line)
        if top_level:
            current_pack = top_level.group(1)
            packs[current_pack] = {"description": "", "agents": [], "skills": []}
            current_list_key = None
            continue
        desc_match = re.match(r'^\s{2}description:\s*"(.*)"\s*$', line)
        if desc_match and current_pack:
            packs[current_pack]["description"] = desc_match.group(1)
            current_list_key = None
            continue
        list_key_match = re.match(r"^\s{2}(agents|skills):\s*\[\s*\]\s*$", line)
        if list_key_match and current_pack:
            packs[current_pack][list_key_match.group(1)] = []
            current_list_key = None
            continue
        list_key_match = re.match(r"^\s{2}(agents|skills):\s*$", line)
        if list_key_match and current_pack:
            current_list_key = list_key_match.group(1)
            continue
        item_match = re.match(r"^\s{4}-\s*(\S+)\s*$", line)
        if item_match and current_pack and current_list_key:
            packs[current_pack][current_list_key].append(item_match.group(1))
            continue
        raise ValueError(f"build-plugins.sh: cannot parse {path}:{lineno}: {line!r}")
    return packs

packs = parse_packs_yaml(packs_yaml)
if not packs:
    print(f"build-plugins.sh: {packs_yaml} defines no packs — nothing to build.", file=sys.stderr)
    sys.exit(1)

# --- Validate registry/ is covered exactly once, per pack manifest's own
# contract (registry/packs.yaml's header comment) --------------------------
all_agent_names = sorted(
    fn[:-3] for fn in os.listdir(agents_dir) if fn.endswith(".md")
)
all_skill_names = sorted(
    d for d in os.listdir(skills_dir)
    if os.path.isdir(os.path.join(skills_dir, d)) and os.path.isfile(os.path.join(skills_dir, d, "SKILL.md"))
)

seen_agents = {}
seen_skills = {}
errors = []
for pack_name, pack in packs.items():
    for a in pack["agents"]:
        seen_agents.setdefault(a, []).append(pack_name)
    for s in pack["skills"]:
        seen_skills.setdefault(s, []).append(pack_name)

for name in all_agent_names:
    count = len(seen_agents.get(name, []))
    if count == 0:
        errors.append(f"agent '{name}' exists in {agents_dir} but is not listed in any pack")
    elif count > 1:
        errors.append(f"agent '{name}' is listed in {count} packs: {seen_agents[name]}")
for name in seen_agents:
    if name not in all_agent_names:
        errors.append(f"pack(s) {seen_agents[name]} reference unknown agent '{name}' (no {name}.md in {agents_dir})")

for name in all_skill_names:
    count = len(seen_skills.get(name, []))
    if count == 0:
        errors.append(f"skill '{name}' exists in {skills_dir} but is not listed in any pack")
    elif count > 1:
        errors.append(f"skill '{name}' is listed in {count} packs: {seen_skills[name]}")
for name in seen_skills:
    if name not in all_skill_names:
        errors.append(f"pack(s) {seen_skills[name]} reference unknown skill '{name}' (no {name}/SKILL.md in {skills_dir})")

if errors:
    print("build-plugins.sh: registry/packs.yaml is out of sync with registry/:", file=sys.stderr)
    for e in errors:
        print(f"  - {e}", file=sys.stderr)
    sys.exit(1)

# --- Generate each plugin --------------------------------------------------
PLUGIN_VERSION = "0.1.0"  # first release of these plugins — see packs.yaml header

marketplace_entries = []
for pack_name in sorted(packs.keys()):
    pack = packs[pack_name]
    plugin_root = os.path.join(plugins_out, pack_name)
    claude_plugin_dir = os.path.join(plugin_root, ".claude-plugin")
    os.makedirs(claude_plugin_dir, exist_ok=True)

    plugin_json = {
        "name": pack_name,
        "description": pack["description"],
        "version": PLUGIN_VERSION,
        "author": {"name": "Daniel Quan"},
    }
    with open(os.path.join(claude_plugin_dir, "plugin.json"), "w", encoding="utf-8", newline="\n") as fh:
        json.dump(plugin_json, fh, indent=2, ensure_ascii=False)
        fh.write("\n")

    if pack["agents"]:
        agents_out_dir = os.path.join(plugin_root, "agents")
        os.makedirs(agents_out_dir, exist_ok=True)
        for agent_name in pack["agents"]:
            shutil.copy2(
                os.path.join(agents_dir, f"{agent_name}.md"),
                os.path.join(agents_out_dir, f"{agent_name}.md"),
            )

    if pack["skills"]:
        skills_out_dir = os.path.join(plugin_root, "skills")
        os.makedirs(skills_out_dir, exist_ok=True)
        for skill_name in pack["skills"]:
            dest = os.path.join(skills_out_dir, skill_name)
            os.makedirs(dest, exist_ok=True)
            shutil.copy2(
                os.path.join(skills_dir, skill_name, "SKILL.md"),
                os.path.join(dest, "SKILL.md"),
            )

    marketplace_entries.append({
        "name": pack_name,
        "source": f"./plugins/{pack_name}",
        "description": pack["description"],
        "version": PLUGIN_VERSION,
    })

marketplace_json = {
    "name": "ai-setup",
    "owner": {"name": "Daniel Quan"},
    "plugins": marketplace_entries,
}
with open(os.path.join(marketplace_out, "marketplace.json"), "w", encoding="utf-8", newline="\n") as fh:
    json.dump(marketplace_json, fh, indent=2, ensure_ascii=False)
    fh.write("\n")

print(f"build-plugins.sh: generated {len(packs)} plugins under {plugins_out}")
print(f"build-plugins.sh: generated {os.path.join(marketplace_out, 'marketplace.json')}")
PYEOF
