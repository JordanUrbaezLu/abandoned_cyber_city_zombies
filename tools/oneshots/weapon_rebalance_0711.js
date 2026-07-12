#!/usr/bin/env node
// =============================================================================
// weapon_rebalance_0711.js - user weapon-balance pass (2026-07-11). Applies the GDT-side
// half of a 6-item retune across EVERY version of each gun (base + _up + all perk twins +
// legend/berzerker/speed variants), the damage half lives in _acc_damage.gsc.
//
//   1. HAMR move speed -> 0.86 (match the M60/RPD LMG standard; was 0.8).            [SET moveSpeedScale]
//   2. SMGs (PPSH-41, AK-74u, Prowler) reload +10% FASTER (x0.9).  Alternator excluded. [scale RELOAD_KEYS]
//   3. Streetsweeper reload +25% FASTER (x0.75).                                      [scale RELOAD_KEYS]
//   4. CEL-3 reload +25% SLOWER  (x1.25, a nerf - "increase reload TIME").            [scale RELOAD_KEYS]
//   5. Prowler clip + reserve +10% (x1.1, INT-rounded): clipSize/maxAmmo/startAmmo.   [scale AMMO_KEYS]
//   6. Action Figure swing 10% SLOWER (x1.1) - melee timing (fireType Melee ignores   [scale MELEE_KEYS]
//      fireTime; the engine gates on meleeTime/meleeChargeDelay/meleeChargeTime).
//
// Mirrors gen_weapon_variant_gdt.js RELOAD_KEYS/AMMO_KEYS + gen_actionfigure_speed_twins.js MELEE
// fields. Stem match is startsWith, so a gun's every variant is caught; disjoint stems mean a block
// is only ever touched by its own op (apex_prowler gets BOTH the reload and the ammo op - different
// keys, no overlap). Damage half (bal mults + acc_af_boss_hits): _acc_damage.gsc.
//
// TARGETS: the DEPLOYED GDTs (source_data + _custom - what gdtdb/linker compile) AND the repo-tracked
// source_data/acc_weapon_variants.gdt (so the committed twin balance stays in sync; the skye_*/apex/AF
// pack GDTs are external + gitignored, deployed-only). Zero-valued fields stay zero.
//
// NON-IDEMPOTENT (scales in place). Per-file .acc-rebal0711-orig backup; the run ABORTS if ANY target
// backup already exists (prevents a double-apply). To redo: restore every .acc-rebal0711-orig first.
// After running: `gdtdb.exe /update`, then a linker relink (build_map.ps1 -GscOnly - no geometry touched).
//
// USAGE:  node tools/oneshots/weapon_rebalance_0711.js [--dry]
// =============================================================================
'use strict';
const fs = require('fs');
const path = require('path');

const DRY = process.argv.includes('--dry');
const TOOLS = process.env.TA_TOOLS_PATH || 'C:/Program Files (x86)/Steam/steamapps/common/Call of Duty Black Ops III 455130';
const REPO = path.resolve(__dirname, '..', '..');
const BAK_SUFFIX = '.acc-rebal0711-orig';

const RELOAD_KEYS = [
  'reloadTime', 'reloadEmptyTime', 'reloadAddTime', 'reloadEmptyAddTime',
  'reloadStartTime', 'reloadStartAddTime', 'reloadEndTime',
  'reloadQuickTime', 'reloadQuickEmptyTime', 'reloadQuickAddTime', 'reloadQuickEmptyAddTime',
];
const AMMO_KEYS  = ['clipSize', 'maxAmmo', 'startAmmo'];
const MELEE_KEYS = ['meleeTime', 'meleeChargeDelay', 'meleeChargeTime'];

// mode 'set' -> assign each field to the literal; mode 'scale' -> multiply the listed keys by factor
// (int:true rounds - clipSize/maxAmmo are INT-typed GDF fields, a decimal makes the engine read 0).
const OPS = [
  { tag: 'HAMR move->0.86',        stems: ['t6_hamr'],          mode: 'set',   fields: { moveSpeedScale: '0.86' } },
  { tag: 'SMG reload x0.9',        stems: ['s4_ppsh41_base', 't9_ak74u', 'apex_prowler'], mode: 'scale', keys: RELOAD_KEYS, factor: 0.9 },
  { tag: 'Streetsweeper reload x0.75', stems: ['t9_streetsweeper'], mode: 'scale', keys: RELOAD_KEYS, factor: 0.75 },
  { tag: 'CEL-3 reload x1.25',     stems: ['s1_cel3'],          mode: 'scale', keys: RELOAD_KEYS, factor: 1.25 },
  { tag: 'Prowler ammo x1.1',      stems: ['apex_prowler'],     mode: 'scale', keys: AMMO_KEYS, factor: 1.1, int: true },
  { tag: 'Action Figure swing x1.1', stems: ['t8_melee_figure'], mode: 'scale', keys: MELEE_KEYS, factor: 1.1 },
];
const ALL_STEMS = [...new Set(OPS.flatMap(o => o.stems))];

const fmt = (n, isInt) => isInt ? String(Math.round(n)) : String(Math.round(n * 1e4) / 1e4);

// Recursively collect every editable *.gdt under the given roots (skip *orig* backups).
function walk(dir, out) {
  for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, e.name);
    if (e.isDirectory()) walk(p, out);
    else if (e.name.endsWith('.gdt') && !e.name.includes('orig')) out.push(p);
  }
}
const ROOTS = [
  path.join(TOOLS, 'source_data'),
  path.join(TOOLS, '_custom'),
  path.join(REPO, 'source_data'),   // repo-tracked acc_weapon_variants.gdt (others here won't match a stem)
].filter(fs.existsSync);
const FILES = [];
for (const r of ROOTS) walk(r, FILES);

// Enumerate weapon blocks in a file: [{ name, start, end }] where [start,end) spans header..close brace.
function blocks(txt) {
  const out = [];
  const re = /(^|\n)[ \t]*"([^"]+)"\s*\(\s*"[^"]*weapon[^"]*\.gdf"\s*\)/g;
  let m;
  while ((m = re.exec(txt)) !== null) {
    const hdr = m.index + (m[1] ? m[1].length : 0);
    const open = txt.indexOf('{', re.lastIndex);
    if (open < 0) continue;
    let depth = 0, end = -1;
    for (let i = open; i < txt.length; i++) {
      if (txt[i] === '{') depth++;
      else if (txt[i] === '}') { depth--; if (depth === 0) { end = i + 1; break; } }
    }
    if (end < 0) continue;
    out.push({ name: m[2], start: hdr, end });
  }
  return out;
}

function applyOpToBody(body, op, log) {
  let changed = false;
  if (op.mode === 'set') {
    for (const [k, v] of Object.entries(op.fields)) {
      const re = new RegExp('("' + k + '"\\s+")(-?[0-9.]+)(")');
      if (!re.test(body)) { log.missing.push(k); continue; }
      body = body.replace(re, (a, pre, old, post) => {
        if (old !== v) { changed = true; log.sets.push(`${k} ${old}->${v}`); }
        return pre + v + post;
      });
    }
  } else {
    for (const k of op.keys) {
      const re = new RegExp('("' + k + '"\\s+")(-?[0-9.]+)(")');
      body = body.replace(re, (a, pre, old, post) => {
        const ov = parseFloat(old);
        if (ov === 0) return a;                    // 0 stays 0
        const nv = fmt(ov * op.factor, op.int);
        if (nv !== old) { changed = true; log.sets.push(`${k} ${old}->${nv}`); }
        return pre + nv + post;
      });
    }
  }
  return { body, changed };
}

// ---- pre-flight: refuse to double-apply -------------------------------------
const wouldEdit = FILES.filter(f => {
  const txt = fs.readFileSync(f, 'utf8');
  return blocks(txt).some(b => ALL_STEMS.some(s => b.name.startsWith(s)));
});
if (!DRY) {
  const dirty = wouldEdit.filter(f => fs.existsSync(f + BAK_SUFFIX));
  if (dirty.length) {
    console.error('ABORT: ' + BAK_SUFFIX + ' already exists for:\n  ' + dirty.map(f => path.basename(f)).join('\n  ') +
      '\nThis pass was already applied. Restore the backups before re-running.');
    process.exit(1);
  }
}

// ---- apply ------------------------------------------------------------------
let totalBlocks = 0, totalFields = 0, filesTouched = 0;
const perGun = {};   // display sample for a couple of anchor blocks
for (const f of wouldEdit) {
  let txt = fs.readFileSync(f, 'utf8');
  const bl = blocks(txt);
  let fileChanged = false;
  // edit right-to-left so earlier offsets stay valid
  for (let i = bl.length - 1; i >= 0; i--) {
    const b = bl[i];
    const ops = OPS.filter(o => o.stems.some(s => b.name.startsWith(s)));
    if (!ops.length) continue;
    let body = txt.slice(b.start, b.end);
    const log = { sets: [], missing: [] };
    for (const op of ops) { const r = applyOpToBody(body, op, log); body = r.body; if (r.changed) fileChanged = true; }
    if (log.sets.length) {
      txt = txt.slice(0, b.start) + body + txt.slice(b.end);
      totalBlocks++; totalFields += log.sets.length;
      // capture a few anchor samples for the summary
      if (/^(t6_hamr|t6_hamr_up|s4_ppsh41_base_up|t9_ak74u_up|t9_streetsweeper_up|s1_cel3_up|apex_prowler_up_zm|t8_melee_figure|t8_melee_figure_fast3)$/.test(b.name) && !perGun[b.name])
        perGun[b.name] = { file: path.basename(f), sets: log.sets };
    }
    if (log.missing.length && op_set_stem(b.name)) console.warn(`  ! ${b.name}: missing ${log.missing.join(',')}`);
  }
  if (fileChanged) {
    filesTouched++;
    if (!DRY) { if (!fs.existsSync(f + BAK_SUFFIX)) fs.copyFileSync(f, f + BAK_SUFFIX); fs.writeFileSync(f, txt); }
    console.log(`${DRY ? '[dry] ' : ''}${path.relative(TOOLS, f) || path.basename(f)} : edited`);
  }
}

function op_set_stem(name) { return name.startsWith('t6_hamr'); }   // only warn missing moveSpeedScale on HAMR

console.log('\n---- anchor samples ----');
for (const [name, s] of Object.entries(perGun)) console.log(`  ${name.padEnd(24)} [${s.file}]  ${s.sets.join('  ')}`);
console.log(`\n${DRY ? 'DRY-RUN ' : 'DONE'}: ${totalBlocks} blocks, ${totalFields} fields across ${filesTouched} files (of ${FILES.length} scanned).`);
