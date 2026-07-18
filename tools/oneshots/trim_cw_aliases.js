#!/usr/bin/env node
// =============================================================================
// trim_cw_aliases.js - drop CW (t9) sound aliases whose TEMPLATE isn't installed.
//
// The BOCW gun packs ship aliases that inherit from a richer CW sound-common than
// the installed Skye template file (template_skye_t9_sounds.csv) provides - the
// main fire/reload/PaP/reverb templates resolve, but the act/flux/cloth tail-layer
// templates are absent -> "missing template alias" + VolumeGroup/DuckGroup parse
// errors. We ship CORE sounds (user 2026-06-26): keep every alias whose template
// EXISTS, drop the rest, and blank any Secondary/Sustain reference left dangling.
//
// Idempotent + roster-agnostic: re-run after adding any gun's aliases.
//
// Usage: node tools/trim_cw_aliases.js [--tools "<modtools root>"]
// =============================================================================

const fs = require('fs');
const path = require('path');

const args = process.argv.slice(2);
const TOOLS = (args.indexOf('--tools') >= 0 ? args[args.indexOf('--tools') + 1]
  : 'C:\\Program Files (x86)\\Steam\\steamapps\\common\\Call of Duty Black Ops III 455130');
const REPO = path.resolve(__dirname, '..');
const CSV = path.join(REPO, 'sound', 'aliases', 'acc_skye_box_weapons.csv');
const TPL = path.join(TOOLS, 'share', 'raw', 'sound', 'templates', 'template_skye_t9_sounds.csv');

// column indices (header: Name,Behavior,Storage,FileSpec,FileSpecSustain,FileSpecRelease,Template,Loadspec,Secondary,SustainAlias,...)
const C_NAME = 0, C_TEMPLATE = 6, C_SECONDARY = 8, C_SUSTAIN = 9;

const available = new Set(
  fs.readFileSync(TPL, 'utf8').split(/\r?\n/)
    .map(l => l.split(',')[0]).filter(n => /^wpn_t9_/.test(n))
);
console.log(`available t9 templates: ${available.size}`);

const lines = fs.readFileSync(CSV, 'utf8').split('\n');
// PASS 1: decide which CW alias rows to drop (t9 alias whose template is missing).
const dropped = new Set();
for (const line of lines) {
  const c = line.split(',');
  if (/^wpn_t9_/.test(c[C_NAME]) && c[C_TEMPLATE] && !available.has(c[C_TEMPLATE])) dropped.add(c[C_NAME]);
}
// PASS 2: rebuild - drop those rows, blank dangling Secondary/Sustain refs in survivors.
let kept = 0, blanked = 0;
const out = [];
for (const line of lines) {
  const c = line.split(',');
  if (dropped.has(c[C_NAME])) continue;            // drop the broken alias row
  if (/^wpn_t9_/.test(c[C_NAME])) {
    for (const ci of [C_SECONDARY, C_SUSTAIN]) {
      if (c[ci] && dropped.has(c[ci])) { c[ci] = ''; blanked++; }
    }
    out.push(c.join(','));
    kept++;
  } else {
    out.push(line);
  }
}
fs.writeFileSync(CSV, out.join('\n'), 'utf8');
console.log(`dropped ${dropped.size} alias(es) with missing templates; kept ${kept} t9 alias(es); blanked ${blanked} dangling ref(s).`);
if (dropped.size) console.log('  dropped: ' + [...dropped].join(', '));
