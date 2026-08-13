#!/usr/bin/env node

// ============================================================================
// lib/condense.mjs — deterministic tier-C condensation engine
// (Fase 4, docs/AI-SETUP-PLAN-v2.md section 6 + section 8)
// ============================================================================
//
// Collapses registry/agents/*.md, registry/skills/*/SKILL.md and
// registry/rules/*.md into a single always-loaded instructions file for
// tools that have NO progressive disclosure (tier C — GitHub Copilot today,
// any future single-file tool tomorrow). No LLM summarization — every step
// below is pure string/regex parsing so the output is 100% reproducible from
// the same registry/ contents (section 6: "deterministic, doesn't depend on
// an LLM summarizing").
//
// No external dependencies (section 3 explicitly rejects gray-matter/similar
// for files this small; same standard already used by
// tools/cursor/adapt/rule-to-mdc.sh and agent-to-mode.sh, which parse
// frontmatter with plain awk/sed). This script uses plain regex against the
// frontmatter block. A separate lib/frontmatter.sh was considered (per
// section 1's tree) but NOT created: every existing shell adapter already
// does its own minimal inline frontmatter parsing (see rule-to-mdc.sh /
// agent-to-mode.sh), and this script is Node, not shell, so a shared
// frontmatter.sh would have no caller and would violate the "don't create
// unused files" instruction. If a second shell adapter ever needs frontmatter
// parsing, THEN it's worth factoring out.
//
// Algorithm (docs/AI-SETUP-PLAN-v2.md section 6, verbatim):
//   1. Sort by tier: core before extended (frontmatter on agents/skills).
//   2. For each item: name + first sentence of description + (if an agent)
//      the ## Essence bullets.
//   3. If the total exceeds max_instructions_lines, trim extended items
//      first, leaving a summary item ("also available: X, Y — see
//      `registry/agents/`").
//   4. Never omit the critical rules (YOU MUST) — fixed priority over
//      roster/skills when trimming.
//
// Rule 4's source in this repo: registry/templates/AGENTS.md's own
// "## Critical rules" section (NEVER/ALWAYS-style imperatives, the
// tool-agnostic equivalent of "YOU MUST"). That section is copied VERBATIM
// into the output and is never touched by any trim step below.
//
// Section 2.2's explicit rule is also honored: "the roster (the 12 names +
// their specialty) is identical across all three tiers" — when extended
// items are collapsed under budget pressure, their NAMES are always
// preserved in the summary line; only the depth of detail (Essence bullets,
// full sentence) is what gets dropped.
//
// Usage:
//   node lib/condense.mjs --root <setup-root> --max-lines <n> --out <file>
//   node lib/condense.mjs --root .. --max-lines 200                # prints to stdout
//
// Called by tools/copilot/enable.sh — see that script for the target-repo
// wiring (this script only reads from --root/registry and writes the
// rendered file; it has no opinion on WHERE in the target repo it lands).
// ============================================================================

import { readFileSync, readdirSync, statSync, writeFileSync, mkdirSync } from 'node:fs';
import { join, basename, dirname } from 'node:path';

// ----------------------------------------------------------------------------
// Minimal frontmatter parsing (no deps — see header comment above)
// ----------------------------------------------------------------------------

/**
 * Splits a registry .md file into { frontmatter: {key: value}, body: string }.
 * Only handles simple scalar "key: value" lines inside the leading
 * "---\n...\n---" block — good enough for name/description/tier, which is
 * all this script needs. Array/object frontmatter values (e.g. `skills: [a,
 * b]`) are left as their raw string form and unused here.
 */
function parseFrontmatter(raw) {
  const lines = raw.split(/\r?\n/);
  if (lines[0]?.trim() !== '---') {
    return { frontmatter: {}, body: raw };
  }
  let end = -1;
  for (let i = 1; i < lines.length; i++) {
    if (lines[i].trim() === '---') {
      end = i;
      break;
    }
  }
  if (end === -1) {
    return { frontmatter: {}, body: raw };
  }
  const frontmatter = {};
  for (const line of lines.slice(1, end)) {
    const m = line.match(/^([A-Za-z_][\w-]*):\s*(.*)$/);
    if (m) frontmatter[m[1]] = m[2].trim();
  }
  const body = lines.slice(end + 1).join('\n');
  return { frontmatter, body };
}

/** First sentence of a description (splits on the first ./!/? followed by whitespace or end). */
function firstSentence(text) {
  if (!text) return '';
  const m = text.match(/^(.*?[.!?])(\s|$)/);
  return (m ? m[1] : text).trim();
}

/** Lines under "## Essence" up to the next "## " heading, stripped of the leading "- ". */
function extractEssence(body) {
  const lines = body.split(/\r?\n/);
  const startIdx = lines.findIndex((l) => l.trim() === '## Essence');
  if (startIdx === -1) return [];
  const bullets = [];
  for (let i = startIdx + 1; i < lines.length; i++) {
    const line = lines[i];
    if (/^## /.test(line)) break;
    const m = line.match(/^-\s+(.*)$/);
    if (m) bullets.push(m[1].trim());
  }
  return bullets;
}

/** Lines under a given "## <heading>" up to the next "## " heading (raw, untrimmed of "- "). */
function extractSection(body, heading) {
  const lines = body.split(/\r?\n/);
  const startIdx = lines.findIndex((l) => l.trim().startsWith(heading));
  if (startIdx === -1) return [];
  const out = [];
  for (let i = startIdx + 1; i < lines.length; i++) {
    const line = lines[i];
    if (/^## /.test(line)) break;
    if (line.trim() !== '') out.push(line);
  }
  return out;
}

// ----------------------------------------------------------------------------
// Loaders
// ----------------------------------------------------------------------------

function loadAgents(agentsDir) {
  const files = readdirSync(agentsDir)
    .filter((f) => f.endsWith('.md'))
    .sort(); // deterministic: alphabetical within a tier
  return files.map((f) => {
    const raw = readFileSync(join(agentsDir, f), 'utf-8');
    const { frontmatter, body } = parseFrontmatter(raw);
    return {
      name: frontmatter.name || basename(f, '.md'),
      description: frontmatter.description || '',
      tier: frontmatter.tier === 'extended' ? 'extended' : 'core', // default core if missing
      essence: extractEssence(body),
    };
  });
}

function loadSkills(skillsDir) {
  const entries = readdirSync(skillsDir).filter((f) => {
    const full = join(skillsDir, f);
    return statSync(full).isDirectory();
  });
  const skills = [];
  for (const dir of entries.sort()) {
    const skillFile = join(skillsDir, dir, 'SKILL.md');
    try {
      const raw = readFileSync(skillFile, 'utf-8');
      const { frontmatter } = parseFrontmatter(raw);
      skills.push({
        name: frontmatter.name || dir,
        description: frontmatter.description || '',
        tier: frontmatter.tier === 'extended' ? 'extended' : 'core',
      });
    } catch {
      // no SKILL.md in this dir (e.g. stray folder) — skip, don't crash the render
    }
  }
  return skills;
}

function loadRules(rulesDir) {
  const files = readdirSync(rulesDir)
    .filter((f) => f.endsWith('.md'))
    .sort();
  return files.map((f) => {
    const raw = readFileSync(join(rulesDir, f), 'utf-8');
    const { frontmatter, body } = parseFrontmatter(raw);
    const area = basename(f, '.md');
    const bodyLines = body.split(/\r?\n/).map((l) => l.trim()).filter(Boolean);
    // First line after frontmatter is normally "# <Title>" — skip it, we key
    // sections by filename (area) rather than the human title.
    const idx = bodyLines[0]?.startsWith('# ') ? 1 : 0;
    // Take the first up-to-2 content lines (bullets or prose) as the summary,
    // per section 6 tier-C row: "summary of conventions per area instead of
    // separate files" — deterministic (first N lines), not LLM-picked.
    const summaryLines = bodyLines
      .slice(idx)
      .filter((l) => !/^```/.test(l))
      .slice(0, 2)
      .map((l) => l.replace(/^-\s+/, ''));
    return {
      area,
      paths: frontmatter.paths || '',
      summary: summaryLines.join(' '),
    };
  });
}

/** registry/templates/AGENTS.md's "## Critical rules" section, verbatim — never trimmed. */
function loadCriticalRules(agentsMdPath) {
  const raw = readFileSync(agentsMdPath, 'utf-8');
  const lines = extractSection(raw, '## Critical rules');
  return lines; // already raw "- ..." lines, unmodified
}

// ----------------------------------------------------------------------------
// Render
// ----------------------------------------------------------------------------

const CORE_FIRST = (a, b) => (a.tier === b.tier ? 0 : a.tier === 'core' ? -1 : 1);

/** Pops trailing empty-string lines in place, so sections never stack up double blank lines. */
function trimTrailingBlank(lines) {
  while (lines.length > 0 && lines[lines.length - 1] === '') lines.pop();
}

/**
 * Builds the full markdown output at a given level-of-detail state.
 * `agentLOD` / `skillLOD` are per-tier LOD tags: 'full' | 'compact' | 'collapsed'.
 * `rulesCollapsed` collapses the rules section to area names only.
 */
function render({ agents, skills, rules, criticalRules, toolName, agentLOD, skillLOD, rulesCollapsed }) {
  const out = [];

  out.push(`# ${toolName} Instructions`);
  out.push('');
  out.push(
    '> Generated by `lib/condense.mjs` (tier C, deterministic — docs/AI-SETUP-PLAN-v2.md section 6). ' +
      'Do not edit by hand: re-run `tools/copilot/enable.sh` to regenerate from `registry/`.'
  );
  out.push('');

  // Critical rules — NEVER trimmed, always rendered in full (section 6 rule 4).
  out.push('## Critical Rules (always enforced — never omitted, never trimmed)');
  out.push('');
  if (criticalRules.length > 0) {
    for (const line of criticalRules) out.push(line);
  } else {
    out.push('- (none found in registry/templates/AGENTS.md — check "## Critical rules")');
  }
  out.push('');

  // Agents — roster identical across tiers (section 2.2): all 12 names always appear.
  out.push('## Agents (roster — no native subagents here; act as the named role manually)');
  out.push('');
  const sorted = [...agents].sort(CORE_FIRST);
  const core = sorted.filter((a) => a.tier === 'core');
  const extended = sorted.filter((a) => a.tier === 'extended');

  for (const a of core) {
    out.push(...renderAgent(a, 'full'));
    out.push('');
  }

  if (extended.length > 0) {
    if (agentLOD === 'collapsed') {
      out.push(
        `- also available (extended): ${extended.map((a) => a.name).join(', ')} — see \`registry/agents/\``
      );
    } else {
      for (const a of extended) {
        out.push(...renderAgent(a, agentLOD));
        if (agentLOD === 'full') out.push('');
      }
    }
  }
  trimTrailingBlank(out);
  out.push('');

  // Skills
  out.push('## Skills (roster)');
  out.push('');
  const sortedSkills = [...skills].sort(CORE_FIRST);
  const coreSkills = sortedSkills.filter((s) => s.tier === 'core');
  const extendedSkills = sortedSkills.filter((s) => s.tier === 'extended');

  for (const s of coreSkills) out.push(...renderSkill(s, 'full'));

  if (extendedSkills.length > 0) {
    if (skillLOD === 'collapsed') {
      out.push(
        `- also available (extended): ${extendedSkills.map((s) => s.name).join(', ')} — see \`registry/skills/\``
      );
    } else {
      for (const s of extendedSkills) out.push(...renderSkill(s, skillLOD));
    }
  }
  out.push('');

  // Rules — always condensed by area (tier C never gets native per-path files).
  out.push('## Rules (condensed by area — full files in `registry/rules/`)');
  out.push('');
  if (rulesCollapsed) {
    out.push(`- areas covered: ${rules.map((r) => r.area).join(', ')} — see \`registry/rules/\``);
  } else {
    for (const r of rules) {
      out.push(`- **${r.area}** (${r.paths || 'no paths declared'}): ${r.summary}`);
    }
  }
  out.push('');

  return out;
}

function renderAgent(agent, lod) {
  const sentence = firstSentence(agent.description);
  if (lod === 'full') {
    const lines = [`### ${agent.name} (${agent.tier})`, sentence];
    for (const b of agent.essence) lines.push(`- ${b}`);
    return lines;
  }
  // compact
  return [`- **${agent.name}** (${agent.tier}) — ${sentence}`];
}

function renderSkill(skill, lod) {
  const sentence = firstSentence(skill.description);
  if (lod === 'full') {
    return [`- **${skill.name}** (${skill.tier}) — ${sentence}`];
  }
  // compact: name only, no description
  return [`- **${skill.name}** (${skill.tier})`];
}

// ----------------------------------------------------------------------------
// Trim cascade (section 6 rule 3: extended first, names never dropped)
// ----------------------------------------------------------------------------

function condense({ agents, skills, rules, criticalRules, toolName, maxLines }) {
  // Cascade of states, each strictly smaller than the previous. Stop at the
  // first one that fits maxLines; if none fit, use the smallest (last) one —
  // never silently drop agent/skill/rule NAMES, even at maximum trim.
  const states = [
    { agentLOD: 'full', skillLOD: 'full', rulesCollapsed: false },
    { agentLOD: 'compact', skillLOD: 'full', rulesCollapsed: false },
    { agentLOD: 'compact', skillLOD: 'compact', rulesCollapsed: false },
    { agentLOD: 'collapsed', skillLOD: 'compact', rulesCollapsed: false },
    { agentLOD: 'collapsed', skillLOD: 'collapsed', rulesCollapsed: false },
    { agentLOD: 'collapsed', skillLOD: 'collapsed', rulesCollapsed: true },
  ];

  let lastLines = null;
  for (const state of states) {
    const lines = render({ agents, skills, rules, criticalRules, toolName, ...state });
    lastLines = lines;
    if (lines.length <= maxLines) {
      return { lines, state, fitsUnderBudget: true };
    }
  }
  return { lines: lastLines, state: states[states.length - 1], fitsUnderBudget: false };
}

// ----------------------------------------------------------------------------
// CLI
// ----------------------------------------------------------------------------

function parseArgs(argv) {
  const args = { root: null, maxLines: null, out: null, toolName: 'GitHub Copilot' };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === '--root') args.root = argv[++i];
    else if (a === '--max-lines') args.maxLines = Number(argv[++i]);
    else if (a === '--out') args.out = argv[++i];
    else if (a === '--tool-name') args.toolName = argv[++i];
    else if (a === '-h' || a === '--help') args.help = true;
  }
  return args;
}

function main() {
  const args = parseArgs(process.argv.slice(2));

  if (args.help || !args.root || !args.maxLines) {
    console.log(`Usage: node lib/condense.mjs --root <setup-root> --max-lines <n> [--out <file>] [--tool-name <name>]

  --root        Path to the AI-Setup checkout (contains registry/).
  --max-lines   Line budget to trim toward (tier C capabilities.yaml's max_instructions_lines).
  --out         Write rendered markdown here instead of stdout.
  --tool-name   Heading label for the generated file (default: "GitHub Copilot").
`);
    process.exit(args.help ? 0 : 1);
  }

  const registryDir = join(args.root, 'registry');
  const agents = loadAgents(join(registryDir, 'agents'));
  const skills = loadSkills(join(registryDir, 'skills'));
  const rules = loadRules(join(registryDir, 'rules'));
  const criticalRules = loadCriticalRules(join(registryDir, 'templates', 'AGENTS.md'));

  const { lines, state, fitsUnderBudget } = condense({
    agents,
    skills,
    rules,
    criticalRules,
    toolName: args.toolName,
    maxLines: args.maxLines,
  });

  const text = lines.join('\n') + '\n';

  if (args.out) {
    mkdirSync(dirname(args.out), { recursive: true });
    writeFileSync(args.out, text, 'utf-8');
    console.error(
      `condense.mjs: wrote ${lines.length} lines to ${args.out} ` +
        `(budget ${args.maxLines}, ${fitsUnderBudget ? 'fits' : 'OVER BUDGET even at max trim'}, ` +
        `state=${JSON.stringify(state)})`
    );
    if (!fitsUnderBudget) process.exitCode = 2;
  } else {
    process.stdout.write(text);
  }
}

main();
