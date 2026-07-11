#!/usr/bin/env node
// =============================================================================
// fix_reserve_cliprel_0710.js - REVERT the two misdiagnosed 2026-07-09 "rounds-vs-mags"
// ammo oneshots that collapsed the Blast-O-Matic PaP + Thundergun reserves to a literal 6.
//
// ROOT CAUSE (user report 2026-07-10: "Blast-O-Matic PaP tier 2 only has 6 reserve"):
//   blasto_ammo_mors_ft_0709.js and thundergun_ammo_0709.js both assumed EVERY weapon counts
//   reserve in MAGAZINES (reserve = maxAmmo x clipSize) and cut maxAmmo/startAmmo down to a
//   small "magazine" number. But these WONDER weapons' packed/upgraded blocks are authored
//   `ammoCountClipRelative "0"` = maxAmmo/startAmmo are ABSOLUTE ROUNDS. So:
//     - Blast-O-Matic  t9_semiauto_cosplay_up : 110 rounds -> "6"  => in-game reserve 6 (BUG)
//     - Thundergun     thundergun_zm          :  12 rounds -> "6"  => in-game reserve 6 (BUG)
//     - Thundergun     thundergun_upgraded_zm :  24 rounds -> "6"  => in-game reserve 6 (BUG)
//   The base Blast-O-Matic (t9_semiauto_cosplay) is ammoCountClipRelative "1" (60 = 12 mag x 5),
//   which is why only the PaP (_up) form looked wrong. Full audit (tools scratchpad
//   audit_reserve.js): these two wonder weapons are the ONLY clipRel=0 forms with a broken
//   reserve; bows / Leviathan / Action Figure (clipRel=0, reserve 0) are correct melee/specials,
//   PDW/M1911 akimbos are REMOVED, everything else is clipRel=1 and fine.
//
// FIX: restore the porters'/stock ROUND counts on the packed + upgraded blocks AND their perk
//   twins (ammoCountClipRelative stays 0 - these are genuinely rounds-mode wonder weapons):
//     Blast-O-Matic _up + 3 twins  -> 110
//     Thundergun base + fastreload twin      -> 12
//     Thundergun upgraded + upgraded twin    -> 24
//
// Edits BOTH the repo copy (source_data/acc_weapon_variants.gdt, git-tracked) AND the install
// copies surgically (no wholesale copy, so install-only edits like the MORS fireTime are safe).
// House pattern: one-shot .acc-<tag>-orig backup per file before editing; then gdtdb /update.
// Build after: .\tools\build_map.ps1 -GscOnly
// =============================================================================
'use strict';
const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');

const REPO = path.join(__dirname, '..', '..');
const REPO_TWINS = path.join(REPO, 'source_data', 'acc_weapon_variants.gdt');

function findSD() {
  const roots = ['C:\\Program Files (x86)\\Steam\\steamapps\\common', 'D:\\SteamLibrary\\steamapps\\common', 'E:\\SteamLibrary\\steamapps\\common'];
  for (const r of roots) { if (!fs.existsSync(r)) continue; for (const d of fs.readdirSync(r)) if (fs.existsSync(path.join(r, d, 'bin', 'modlauncher.exe'))) return path.join(r, d, 'source_data'); }
  throw new Error('install source_data not found');
}
const SD = findSD();

// blasto _up + its 3 perk twins -> 110 rounds ; thundergun base/up + twins -> 12 / 24 rounds
const BLASTO_TWINS = { 't9_semiauto_cosplay_up_acc_recoil50': 110, 't9_semiauto_cosplay_up_acc_fastreload': 110, 't9_semiauto_cosplay_up_acc_recoil50_fastreload': 110 };
const TG_TWINS = { 'thundergun_acc_fastreload_zm': 12, 'thundergun_upgraded_acc_fastreload_zm': 24 };

// file -> { block: roundValue }  (each block gets maxAmmo AND startAmmo set to roundValue)
const JOBS = [
  { file: path.join(SD, 'owens_weapons', 'bocw', 'wpn_t9_shotgun_semiauto_cb_cosplay.gdt'), blocks: { 't9_semiauto_cosplay_up': 110 } },
  { file: path.join(SD, 'night_t5_thundergun.gdt'), blocks: { 'thundergun_zm': 12, 'thundergun_upgraded_zm': 24 } },
  { file: path.join(SD, 'acc_weapon_variants.gdt'), blocks: Object.assign({}, BLASTO_TWINS, TG_TWINS) },
  { file: REPO_TWINS, blocks: Object.assign({}, BLASTO_TWINS, TG_TWINS) },
];

const TAG = 'reserve-cliprel-0710';
let failed = false;

for (const job of JOBS) {
  if (!fs.existsSync(job.file)) { console.error('MISSING FILE: ' + job.file); failed = true; continue; }
  const bak = job.file + '.acc-' + TAG + '-orig';
  if (!fs.existsSync(bak)) fs.copyFileSync(job.file, bak);
  let txt = fs.readFileSync(job.file, 'utf8');
  for (const [name, val] of Object.entries(job.blocks)) {
    const esc = name.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    const m = new RegExp('(^|\\n)\\t"' + esc + '"\\s*\\(\\s*"[^"]+"\\s*\\)').exec(txt);
    if (!m) { console.error('BLOCK NOT FOUND: ' + name + ' in ' + job.file); failed = true; continue; }
    const start = m.index;
    const end = txt.indexOf('\n\t}', start);
    let body = txt.substring(start, end);
    let n = 0;
    for (const k of ['maxAmmo', 'startAmmo']) {
      body = body.replace(new RegExp('("' + k + '"\\s+")([^"]*)(")'), (a, pre, old, post) => { n++; console.log(path.basename(job.file) + ' :: ' + name + ' :: ' + k + ' ' + old + ' -> ' + val); return pre + val + post; });
    }
    if (n !== 2) { console.error('EXPECTED 2 fields on ' + name + ', got ' + n + ' (' + job.file + ')'); failed = true; }
    txt = txt.substring(0, start) + body + txt.substring(end);
  }
  fs.writeFileSync(job.file, txt);
}

if (failed) { console.error('\nONE OR MORE EDITS FAILED - inspect above. gdtdb NOT run.'); process.exit(1); }

console.log('\ngdtdb /update:');
const gdtdb = path.join(path.dirname(SD), 'gdtdb', 'gdtdb.exe');
if (fs.existsSync(gdtdb)) { try { execFileSync(gdtdb, ['/update'], { cwd: path.dirname(gdtdb), stdio: 'inherit' }); } catch (e) { console.log('  WARN gdtdb: ' + e.message); } }
else console.log('  gdtdb.exe not found at ' + gdtdb + ' - run it manually.');

console.log('\nDONE. Build: .\\tools\\build_map.ps1 -GscOnly');
