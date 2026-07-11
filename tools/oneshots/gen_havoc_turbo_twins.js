// Generate the 8 Havoc TURBO twin GDT blocks (sprintOutTime 0.2) by cloning existing forms.
// Turbo token is LAST in canonical axis order (recoil50, fastreload, turbo) so non-Havoc guns
// degrade to their other twins via desired_weapon()'s trailing-token drop.
const fs = require('fs');

const TOOLS = 'C:/Program Files (x86)/Steam/steamapps/common/Call of Duty Black Ops III 455130/source_data';
const FILES = {
  base: TOOLS + '/zeroy/APEX_BO3.gdt',
  up: TOOLS + '/acc_apex_up.gdt',
  twins: TOOLS + '/acc_weapon_variants.gdt',
};

// clone source block name -> new turbo twin name
const MAP = [
  ['base', 'apex_beam_rifle_zm', 'apex_beam_rifle_acc_turbo_zm'],
  ['twins', 'apex_beam_rifle_acc_recoil50_zm', 'apex_beam_rifle_acc_recoil50_turbo_zm'],
  ['twins', 'apex_beam_rifle_acc_fastreload_zm', 'apex_beam_rifle_acc_fastreload_turbo_zm'],
  ['twins', 'apex_beam_rifle_acc_recoil50_fastreload_zm', 'apex_beam_rifle_acc_recoil50_fastreload_turbo_zm'],
  ['up', 'apex_beam_rifle_up_zm', 'apex_beam_rifle_up_acc_turbo_zm'],
  ['twins', 'apex_beam_rifle_up_acc_recoil50_zm', 'apex_beam_rifle_up_acc_recoil50_turbo_zm'],
  ['twins', 'apex_beam_rifle_up_acc_fastreload_zm', 'apex_beam_rifle_up_acc_fastreload_turbo_zm'],
  ['twins', 'apex_beam_rifle_up_acc_recoil50_fastreload_zm', 'apex_beam_rifle_up_acc_recoil50_fastreload_turbo_zm'],
];

const srcs = {};
for (const k of Object.keys(FILES)) srcs[k] = fs.readFileSync(FILES[k], 'latin1');

// Extract a top-level block: header line `\t"<name>" ( "..." )` then its braces to the matching close.
function extractBlock(text, name) {
  const hdrRe = new RegExp('^\\t"' + name.replace(/[.*+?^${}()|[\]\\]/g, '\\$&') + '"\\s*\\(', 'm');
  const m = text.match(hdrRe);
  if (!m) throw new Error('block not found: ' + name);
  const start = m.index;
  // find the opening brace after the header, then match to its close (blocks don't nest braces in values)
  let i = text.indexOf('{', start);
  if (i < 0) throw new Error('no open brace: ' + name);
  let depth = 0, end = -1;
  for (; i < text.length; i++) {
    const c = text[i];
    if (c === '{') depth++;
    else if (c === '}') { depth--; if (depth === 0) { end = i; break; } }
  }
  if (end < 0) throw new Error('no close brace: ' + name);
  // include through end-of-line after the close
  let lineEnd = text.indexOf('\n', end);
  if (lineEnd < 0) lineEnd = text.length; else lineEnd += 1;
  return text.slice(start, lineEnd);
}

let out = '';
for (const [srcKey, srcName, newName] of MAP) {
  let block = extractBlock(srcs[srcKey], srcName);
  // the source name must appear EXACTLY once (the header) - abort if the block self-references elsewhere
  const occ = block.split('"' + srcName + '"').length - 1;
  if (occ !== 1) throw new Error(srcName + ' appears ' + occ + ' times in its block (expected 1)');
  block = block.replace('"' + srcName + '"', '"' + newName + '"');
  // sprintOutTime -> 0.2 (exactly one occurrence expected)
  const so = block.match(/"sprintOutTime" "([^"]+)"/);
  if (!so) throw new Error('no sprintOutTime in ' + srcName);
  block = block.replace(/"sprintOutTime" "[^"]+"/, '"sprintOutTime" "0.2"');
  const n2 = (block.match(/"sprintOutTime"/g) || []).length;
  if (n2 !== 1) throw new Error('sprintOutTime x' + n2 + ' in ' + srcName);
  console.error(newName, '<-', srcName, '(sprintOutTime', so[1], '-> 0.2,', block.length, 'chars)');
  out += block;
}

// Append inside the twins file's outer braces: file ends with "}\r\n" or "}" - insert before the final }
let twins = srcs.twins;
const lastBrace = twins.lastIndexOf('}');
// sanity: the char before should close the previous block (a "\t}" line)
twins = twins.slice(0, lastBrace) + out + twins.slice(lastBrace);
fs.writeFileSync(FILES.twins, twins, 'latin1');
console.error('appended 8 turbo twin blocks to acc_weapon_variants.gdt');
