#!/usr/bin/env node

// ============================================================================
// test/lint-frontmatter.mjs — SKILL.md frontmatter linter (Fase 0.2)
// ============================================================================
//
// Validates every registry/skills/<name>/SKILL.md against the three rules
// update-plan-aug-2026.md 0.2 asks for:
//   1. Has both `name` and `description` in its frontmatter.
//   2. `name` matches the folder it lives in (registry/skills/<name>/).
//   3. `description` doesn't exceed the format's limit.
//
// "The format's limit" — Claude Code's own SKILL.md frontmatter contract:
// `name` <= 64 chars, `description` <= 1024 chars. Not documented anywhere
// in this repo (checked before writing this script — see docs/AUDIT-v3.md),
// so the limits are hardcoded here with this comment as the citation. If
// Anthropic changes the contract, update NAME_MAX_LEN / DESCRIPTION_MAX_LEN.
//
// No dependencies — same minimal frontmatter parsing approach as
// lib/condense.mjs (this repo's standard for files this small).
//
// Usage: node test/lint-frontmatter.mjs
// Exit code 0 = all skills valid, 1 = one or more violations (printed to stderr).
// ============================================================================

import { readFileSync, readdirSync, statSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const NAME_MAX_LEN = 64;
const DESCRIPTION_MAX_LEN = 1024;

const __dirname = dirname(fileURLToPath(import.meta.url));
const SKILLS_DIR = join(__dirname, '..', 'registry', 'skills');

/** Same minimal frontmatter parser as lib/condense.mjs — only scalar key: value lines. */
function parseFrontmatter(raw) {
  const lines = raw.split(/\r?\n/);
  if (lines[0]?.trim() !== '---') {
    return null; // no frontmatter block at all
  }
  let end = -1;
  for (let i = 1; i < lines.length; i++) {
    if (lines[i].trim() === '---') {
      end = i;
      break;
    }
  }
  if (end === -1) return null;
  const frontmatter = {};
  for (const line of lines.slice(1, end)) {
    const m = line.match(/^([A-Za-z_][\w-]*):\s*(.*)$/);
    if (m) frontmatter[m[1]] = m[2].trim();
  }
  return frontmatter;
}

function lintSkill(dirName) {
  const errors = [];
  const skillPath = join(SKILLS_DIR, dirName, 'SKILL.md');

  let raw;
  try {
    raw = readFileSync(skillPath, 'utf-8');
  } catch {
    return [`missing SKILL.md`];
  }

  const frontmatter = parseFrontmatter(raw);
  if (!frontmatter) {
    return [`no frontmatter block (expected leading "---\\n...\\n---")`];
  }

  if (!frontmatter.name) {
    errors.push('missing `name` in frontmatter');
  } else {
    if (frontmatter.name !== dirName) {
      errors.push(`\`name: ${frontmatter.name}\` does not match folder name \`${dirName}\``);
    }
    if (frontmatter.name.length > NAME_MAX_LEN) {
      errors.push(`\`name\` is ${frontmatter.name.length} chars, exceeds the ${NAME_MAX_LEN}-char limit`);
    }
  }

  if (!frontmatter.description) {
    errors.push('missing `description` in frontmatter');
  } else if (frontmatter.description.length > DESCRIPTION_MAX_LEN) {
    errors.push(
      `\`description\` is ${frontmatter.description.length} chars, exceeds the ${DESCRIPTION_MAX_LEN}-char limit`
    );
  }

  return errors;
}

function main() {
  const entries = readdirSync(SKILLS_DIR).filter((f) => statSync(join(SKILLS_DIR, f)).isDirectory());

  if (entries.length === 0) {
    console.error(`lint-frontmatter: no skill folders found under ${SKILLS_DIR}`);
    process.exit(1);
  }

  let failCount = 0;
  for (const dirName of entries.sort()) {
    const errors = lintSkill(dirName);
    if (errors.length > 0) {
      failCount++;
      console.error(`✗ ${dirName}`);
      for (const e of errors) console.error(`    - ${e}`);
    } else {
      console.log(`✓ ${dirName}`);
    }
  }

  console.log('');
  if (failCount > 0) {
    console.error(`lint-frontmatter: ${failCount}/${entries.length} skill(s) failed.`);
    process.exit(1);
  }
  console.log(`lint-frontmatter: all ${entries.length} skills valid.`);
}

main();
