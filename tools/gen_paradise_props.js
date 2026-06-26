#!/usr/bin/env node
// =============================================================================
// gen_paradise_props.js - the .map (bake-gated) amenities for PARADISE (the open-air plaza hub below
// the abyss; geometry: gen_descent_hub.js). Injects a FULL DUPLICATE perk row (all 10 perks) into the
// plaza (user 2026-06-25: "everything a player needs"). These are POINT entities (misc_prefab /
// script_struct) - NO brushes, so zero winding risk - but they DO ride the .ff, so this needs a FULL
// LED-baked build after running.
//
// All entities are VERBATIM COPIES of the working surface perks (same models/prefabs/specialties/
// script_strings/angles - so zero new-asset risk; stock supports duplicate zm_perk_machine structs
// map-wide), just re-originned onto the Paradise floor (z=-1200) and given fresh GUIDs. Facing is
// forced to yaw 359.999 at runtime by acc_perks::force_perk_machine_facing (so a perk's front faces
// -Y / "south") - the rows are laid out facing into the room from the north.
//
// NO 2nd Pack-a-Punch is injected here anymore (user 2026-06-25). A 2nd stock "zm_pack_a_punch"
// machine FATALS the load (stock renames both zbarriers to "vending_packapunch" then GetEnt-singular's
// it) - that is what broke the SURFACE PaP. The Paradise PaP is now a STANDALONE GSC vendor:
// _acc_pap_levels::spawn_paradise_pap_at, called from _acc_glitch_altar::spawn_paradise() (no .map
// entity, no bake). It reuses the same player-scoped tier path so the tier never resets between
// machines. acc_dedupe_pack_a_punch() still neutralizes any leftover stock Paradise PaP at load.
//
// (The GSC-spawned kiosks - Overclock / Exo / Glitch Altar / bench / perk-slot vendor / box / PaP - are
// placed separately in _acc_glitch_altar::spawn_paradise(), no bake.)
//
// Usage: node tools/gen_paradise_props.js            inject/refresh the perk row
//        node tools/gen_paradise_props.js --revert    remove them
//        node tools/gen_paradise_props.js --out <f>   write elsewhere (dry run)
// =============================================================================
'use strict';
const fs = require('fs'), path = require('path');
const MAP = path.join(__dirname, '..', 'map_source', 'zm', 'zm_abandoned_cyber_city.map');
const outArg = process.argv.indexOf('--out');
const OUT = outArg > 0 ? process.argv[outArg + 1] : MAP;
const REVERT = process.argv.includes('--revert');

const PZ = -1200;          // Paradise floor top (perk machines sit here, like the surface perks sit at z=0)

let gc = 0x10;
function guid() { gc++; const c = gc.toString(16).toUpperCase().padStart(12, '0'); return `{7A2BAF00-ACF0-4E0D-8A3F-${c}}`; }

// A perk via the stock PREFAB (the prefab contains the zm_perk_machine struct + model). `loc` true = carry
// the start-room location tag (matches the surface; marathon/mulekick ship WITHOUT it, so loc=false there).
function perkPrefab(prefab, x, y, loc) {
  return [
    '{',
    ` guid "${guid()}"`,
    ' "classname" "misc_prefab"',
    ' "angles" "0 359.999 0"',
    ` "model" "_prefabs/zm/zm_core/${prefab}"`,
    ` "origin" "${x} ${y} ${PZ}"`,
    ...(loc ? [' "script_string" "zclassic_perks_start_room"'] : []),
    '}',
  ].join('\n');
}

// A perk via an INLINE zm_perk_machine struct (the 3-4 perks the surface authors inline: deadshot/
// widowswine/PhD-nuke/electric-cherry). model + specialty verbatim from the surface.
function perkStruct(model, specialty, x, y) {
  return [
    '{',
    ` guid "${guid()}"`,
    ' "classname" "script_struct"',
    ' "angles" "0 359.999 0"',
    ` "model" "${model}"`,
    ` "origin" "${x} ${y} ${PZ}"`,
    ` "script_noteworthy" "${specialty}"`,
    ' "script_string" "zclassic_perks_start_room"',
    ' "targetname" "zm_perk_machine"',
    ' "_color" "1 0 0"',
  '}',
  ].join('\n');
}

// NOTE: the stock-prefab Pack-a-Punch helper (papPrefab) was REMOVED 2026-06-25. A 2nd stock
// "zm_pack_a_punch" machine fatals the load (and broke the surface PaP). The Paradise PaP is now a
// standalone GSC vendor - see _acc_pap_levels::spawn_paradise_pap_at + the entities[] note below.

// Layout: ONE row of all 10 perks along the north, facing -Y (forced) so players use them from the room
// side (south). A center GAP (x[-180,180]) keeps the hallway mouth (x[+-96], y=-600) clear; 5 perks each
// side, 180u apart. Plaza interior x[-1000,1000] y[-2200,-600].
const PERK_Y = -820;
const entities = [
  // Left of the entrance gap:
  perkPrefab('vending_revive_struct.map',                  -900, PERK_Y, true),  // Quick Revive
  perkPrefab('vending_juggernaut_struct.map',              -720, PERK_Y, true),  // Jugger-Nog
  perkPrefab('vending_sleight_struct.map',                 -540, PERK_Y, true),  // Speed Cola
  perkPrefab('vending_doubletap_struct.map',               -360, PERK_Y, true),  // Double Tap
  perkPrefab('vending_marathon_struct.map',                -180, PERK_Y, false), // Stamin-Up (surface has no script_string)
  // Right of the entrance gap:
  perkPrefab('vending_additionalprimaryweapon_struct.map',  180, PERK_Y, false), // Mule Kick (surface has no script_string)
  perkStruct('p7_zm_vending_ads',              'specialty_deadshot',          360, PERK_Y), // Deadshot
  perkStruct('p7_zm_vending_widows_wine',      'specialty_widowswine',        540, PERK_Y), // Widow's Wine
  perkStruct('p7_zm_vending_nuke',             'specialty_electriccherry',    720, PERK_Y), // PhD / nuke machine
  perkStruct('p6_zm_vending_electric_cherry_on','specialty_combat_efficiency', 900, PERK_Y), // Electric Cherry (10th)
  // NO 2nd Pack-a-Punch here anymore (user 2026-06-25). A 2nd stock "zm_pack_a_punch" zbarrier
  // FATALS the load (stock renames both to "vending_packapunch" then GetEnt-singular's it) and
  // that is what broke the SURFACE PaP. The Paradise PaP is now a STANDALONE GSC vendor instead:
  // acc_pap_levels::spawn_paradise_pap_at( (0,-1700,-1200) ), spawned in _acc_glitch_altar::
  // spawn_paradise(). It reuses the same player-scoped tier path, so packing surface->Paradise
  // never resets the tier. Re-running this generator strips the old stock-PaP entity from the
  // .map cleanly; until then acc_dedupe_pack_a_punch() neutralizes any leftover at load.
];

const BEGIN = '// >>> ACC PARADISE PROPS (gen_paradise_props.js) - duplicate perk row + 2nd Pack-a-Punch';
const END = '// <<< ACC PARADISE PROPS';

let src = fs.readFileSync(MAP, 'utf8');

// Strip any prior block (idempotent).
const esc = (s) => s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
const re = new RegExp(`\\n?${esc(BEGIN)}[\\s\\S]*?${esc(END)}\\n?`, 'g');
src = src.replace(re, '\n');

if (!REVERT) {
  const block = `${BEGIN}\n${entities.join('\n')}\n${END}\n`;
  const lastBrace = src.lastIndexOf('}');
  if (lastBrace < 0) { console.error('no closing brace in .map'); process.exit(1); }
  src = src.slice(0, lastBrace + 1) + '\n' + block + src.slice(lastBrace + 1);
}

fs.writeFileSync(OUT, src);
console.log(`${REVERT ? 'reverted' : 'wrote'} Paradise props -> ${OUT}`);
if (!REVERT) console.log(`[paradise-props] 10 perk machines (one row y=${PERK_Y}, center gap) on the z=${PZ} floor. (Paradise PaP is a standalone GSC vendor, not a .map entity.) Needs a FULL LED-baked build.`);
