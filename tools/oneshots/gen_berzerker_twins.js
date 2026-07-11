#!/usr/bin/env node
// gen_berzerker_twins.js - author the 9 BERZERKER (boss item 11, user 2026-07-11) GDT weapon clones into
// repo source_data/acc_weapon_variants.gdt. Berzerker = +35% melee swing speed on the three melee surfaces
// (regular knife bash / Leviathan Axe / Action Figure), paid for with 5% max HP per melee (GSC side).
//
// WHAT IT WRITES (all ~35% faster = timing fields / 1.35):
//   LEVIATHAN (4) - the axe's berzerker forms, one per PaP tier, mirroring the proven spd-tier twins
//     (tools/oneshots/gen_leviathan_spd_twins.js recipe: scale meleeTime + fireTime; fireTime is inert on a
//     melee weapon but the spd twins scale both, so we stay consistent):
//       leviathan_zm             -> leviathan_acc_brz_zm            (tier 0)
//       leviathan_acc_spd1_zm    -> leviathan_acc_spd1_brz_zm       (tier 1)
//       leviathan_up_acc_spd2_zm -> leviathan_up_acc_spd2_brz_zm    (tier 2)
//       leviathan_up_acc_spd3_zm -> leviathan_up_acc_spd3_brz_zm    (tier 3)
//     (_zm ids: engine strips the mode suffix -> runtime names leviathan_acc_brz etc. - the apex trap.)
//   ACTION FIGURE (4) - berzerker forms of the held figure per PaP tier, mirroring the proven fast-twin
//     recipe (tools/gen_actionfigure_speed_twins.js: scale meleeTime + meleeChargeDelay + meleeChargeTime):
//       t8_melee_figure[_fastN] -> t8_melee_figure[_fastN]_brz   (no _zm - the AF pack family has none)
//   KNIFE (1) - THE EXPERIMENTAL PIECE (user 2026-07-11 "if you cant do the knife thats fine but please
//     try"): acc_berzerker_melee, a MELEE-SLOT weapon (meleeweapon.gdf) cloned from the pack's
//     t8_actionfigure_melee (the only melee-slot GDT in the install - the stock knife def ships in
//     fastfiles ONLY, no public GDT exists; swept T7-GDT-Backup + install + web 2026-07-11). While
//     Berzerker is implanted, _acc_boss_items swaps the player's melee slot to it (the stock Bowie /
//     Widow's-Wine knife recipe: TakeWeapon + GiveWeapon + zm_utility::set_player_melee_weapon).
//     gunModel/worldModel are EMPTIED -> the quick melee reads as a BARE-FIST rage swipe (bare-handed
//     weapons are engine-supported: stock ships weapon,bare_hands_mp). meleeDamage 150 = stock knife
//     parity so the bash kills exactly like the regular knife. NEEDS LIVE QA: (a) does the melee-slot
//     def's timing actually gate the quick melee (all evidence says yes - the AF pack's melee-slot
//     sibling carries its own distinct meleeTime fields), (b) does the empty gunModel look right.
//
// SOURCES (read-only): install _custom\wetegg\leviathanaxe\leviathanaxe.gdt (leviathan base),
//   install source_data\t8_weapons\wpn_t8_melee_actionfigure.gdt (AF base + fast twins + melee-slot),
//   repo source_data/acc_weapon_variants.gdt (leviathan spd twins).
// OUTPUT: repo source_data/acc_weapon_variants.gdt (then tools/deploy_source_data.ps1 push +
//   gdtdb /update + zone weaponfull/weapon lines + rebuild).
// Re-runnable: strips any prior _brz*/acc_berzerker_melee blocks first, then re-clones.
'use strict';
const fs = require('fs');
const path = require('path');

const MULT = 1.35;   // +35% swing speed (user spec) -> every timing field / 1.35

const REPO = path.join(__dirname, '..', '..');
const TOOLS = 'C:\\Program Files (x86)\\Steam\\steamapps\\common\\Call of Duty Black Ops III 455130';
const OUT_GDT = path.join(REPO, 'source_data', 'acc_weapon_variants.gdt');
const LEV_GDT = path.join(TOOLS, '_custom', 'wetegg', 'leviathanaxe', 'leviathanaxe.gdt');
const AF_GDT = path.join(TOOLS, 'source_data', 't8_weapons', 'wpn_t8_melee_actionfigure.gdt');

function readLines(f) { return fs.readFileSync(f, 'utf8').split('\n'); }

function blockEnd(lines, openBraceIdx) {
  let depth = 0;
  for (let j = openBraceIdx; j < lines.length; j++) {
    depth += (lines[j].match(/{/g) || []).length - (lines[j].match(/}/g) || []).length;
    if (depth === 0) return j;
  }
  return -1;
}

// extract entry block (header line + brace block) by asset name, from a lines array
function extractBlock(lines, name, file) {
  const hdr = lines.findIndex(l => l.includes(`"${name}" (`));
  if (hdr < 0) { console.error(`ERROR: entry "${name}" not found in ${file}`); process.exit(2); }
  let bi = hdr + 1; while (lines[bi].trim() !== '{') bi++;
  return lines.slice(hdr, blockEnd(lines, bi) + 1);
}

// scale a numeric field inside a block (in place); returns old -> new for the log
function scaleField(block, field) {
  const re = new RegExp(`"${field}" "([0-9.]+)"`);
  for (let i = 0; i < block.length; i++) {
    const m = block[i].match(re);
    if (m) {
      const nv = (parseFloat(m[1]) / MULT).toFixed(4);
      block[i] = block[i].replace(re, `"${field}" "${nv}"`);
      return `${field} ${m[1]}->${nv}`;
    }
  }
  console.error(`ERROR: field "${field}" not found in block`); process.exit(3);
}

function setField(block, field, value) {
  const re = new RegExp(`"${field}" "[^"]*"`);
  for (let i = 0; i < block.length; i++) {
    if (re.test(block[i])) { block[i] = block[i].replace(re, `"${field}" "${value}"`); return; }
  }
  console.error(`ERROR: field "${field}" not found in block`); process.exit(3);
}

function renameBlock(block, from, to) {
  block[0] = block[0].replace(`"${from}" (`, `"${to}" (`);
}

const levLines = readLines(LEV_GDT);
const afLines = readLines(AF_GDT);
let out = readLines(OUT_GDT);

// -- strip any prior berzerker blocks (clean re-run) --------------------------
const BRZ_HDR = /"(leviathan(_up)?_acc(_spd\d)?_brz_zm|t8_melee_figure(_fast\d)?_brz|acc_berzerker_melee)" \(/;
let stripped = 0;
for (;;) {
  const h = out.findIndex(l => BRZ_HDR.test(l));
  if (h < 0) break;
  let i = h + 1; while (out[i].trim() !== '{') i++;
  out.splice(h, blockEnd(out, i) - h + 1);
  stripped++;
}
if (stripped) console.log(`stripped ${stripped} prior berzerker blocks`);

const clones = [];
function clone(srcLines, srcName, dstName, fields, srcFile, extra) {
  const b = extractBlock(srcLines, srcName, srcFile);
  renameBlock(b, srcName, dstName);
  const log = fields.map(f => scaleField(b, f));
  if (extra) extra(b);
  clones.push(...b);
  console.log(`  ${dstName}: ${log.join('  ')}`);
}

// -- LEVIATHAN (spd-twin recipe: meleeTime + fireTime) -------------------------
clone(levLines, 'leviathan_zm', 'leviathan_acc_brz_zm', ['meleeTime', 'fireTime'], LEV_GDT);
clone(out, 'leviathan_acc_spd1_zm', 'leviathan_acc_spd1_brz_zm', ['meleeTime', 'fireTime'], OUT_GDT);
clone(out, 'leviathan_up_acc_spd2_zm', 'leviathan_up_acc_spd2_brz_zm', ['meleeTime', 'fireTime'], OUT_GDT);
clone(out, 'leviathan_up_acc_spd3_zm', 'leviathan_up_acc_spd3_brz_zm', ['meleeTime', 'fireTime'], OUT_GDT);

// -- ACTION FIGURE (fast-twin recipe: meleeTime + meleeChargeDelay + meleeChargeTime) --
const AF_FIELDS = ['meleeTime', 'meleeChargeDelay', 'meleeChargeTime'];
clone(afLines, 't8_melee_figure', 't8_melee_figure_brz', AF_FIELDS, AF_GDT);
clone(afLines, 't8_melee_figure_fast1', 't8_melee_figure_fast1_brz', AF_FIELDS, AF_GDT);
clone(afLines, 't8_melee_figure_fast2', 't8_melee_figure_fast2_brz', AF_FIELDS, AF_GDT);
clone(afLines, 't8_melee_figure_fast3', 't8_melee_figure_fast3_brz', AF_FIELDS, AF_GDT);

// -- KNIFE (melee-slot clone; bare-fist visuals + stock-knife damage) ----------
clone(afLines, 't8_actionfigure_melee', 'acc_berzerker_melee', AF_FIELDS, AF_GDT, b => {
  setField(b, 'displayName', 'Berzerker');
  setField(b, 'gunModel', '');      // bare-fist swipe (no stock knife viewmodel exists in the tools)
  setField(b, 'worldModel', '');    // 3rd-person: bare hand too
  setField(b, 'meleeDamage', '150');  // stock knife parity (was the AF's 4000 one-knife special)
});

// -- append before the file's final closing brace ------------------------------
let close = out.length - 1; while (close > 0 && out[close].trim() !== '}') close--;
fs.writeFileSync(OUT_GDT, [...out.slice(0, close), ...clones, ...out.slice(close)].join('\n'));
console.log(`wrote ${OUT_GDT} (+9 berzerker blocks). Next: deploy_source_data.ps1 push, gdtdb /update, zone lines, build.`);
