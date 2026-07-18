// =============================================================================
// add_avogadro_spawn.js  (ONE-SHOT, idempotent)
//
// Inlines the Avogadro AI's spawn entities into the .map so _zm_ai_avogadro can
// spawn it (its init() reads GetEntArray("avogadro_spawner") + choose_a_spawn()
// reads struct::get_array("avogadro_spawn_loc")). From the pack's prefabs
// (zm_avo_aitype.map = the actor_spawner; zm_avo_spawnloc.map = the spawn structs):
//   - ONE actor_spawner_zm_avogadro (script_noteworthy "avogadro_spawner") = the
//     archetype source for zombie_utility::spawn_zombie.
//   - TWO avogadro_spawn_loc script_structs = candidate appear-points (choose_a_spawn
//     picks the in-enabled-zone one closest to a player).
// Placed at PLAZA (start_zone) riser-location coords (navmesh-valid, z=0) so the
// round-1 test spawn lands near the players.
//
// Point entities only (no brushes) => the LED bake is unaffected, but it IS a .map
// change so cod2map must re-bake the entity list => run the FULL build (build_map.ps1).
//
// Idempotent: refuses to re-run if "avogadro_spawner" already present.
// =============================================================================
const fs = require('fs');
const path = require('path');

const MAP = path.join(__dirname, '..', 'map_source', 'zm', 'zm_abandoned_cyber_city.map');

let gc = 0;
function guid(tag) {
  gc++;
  const h = ('avo' + tag + gc).split('').reduce((a, c) => (a * 33 + c.charCodeAt(0)) >>> 0, 5381);
  const hx = h.toString(16).toUpperCase().padStart(8, '0').slice(0, 8);
  return `{${hx}-AVO0-4E0D-8A3F-${String(gc).padStart(12, '0')}}`;
}

function spawnerEntity(x, y, z) {
  return [
    '// entity (acc avogadro spawner — tools/add_avogadro_spawn.js)',
    '{',
    `guid "${guid('spawner')}"`,
    '"classname" "actor_spawner_zm_avogadro"',
    '"ALERTONSPAWN" "0"',
    '"MAKEROOM" "1"',
    '"SCRIPT_FORCESPAWN" "1"',
    '"count" "999"',
    '"export" "3"',
    '"script_disable_bleeder" "1"',
    '"script_forcespawn" "1"',
    '"script_noteworthy" "avogadro_spawner"',
    '"SPAWNER" "1"',
    '"_color" "1 0.25 0"',
    '"engageMaxDist" "700"',
    '"engageMinDist" "250"',
    // NO "model" KVP: it is Radiant DISPLAY only, and the custom character model
    // c_zom_t7_avogadro makes the Radiant LIGHTMAPPER crash (it can't resolve the
    // gdtdb-only model as a shadow caster) -> the LED bake CRASHED with it (user 2026-06-25).
    // The runtime spawn uses the aitype's own model, so the spawner needs none.
    '"script_dropammo" "1"',
    '"sm_active_count_max" "3"',
    '"sm_active_count_min" "3"',
    '"spawnflags" "19"',
    `"origin" "${x} ${y} ${z}"`,
    '}',
  ].join('\n');
}

function spawnLocStruct(x, y, z) {
  return [
    '{',
    `guid "${guid('loc')}"`,
    '"classname" "script_struct"',
    '"script_noteworthy" "avogadro_spawn_loc"',
    `"origin" "${x} ${y} ${z}"`,
    '}',
  ].join('\n');
}

let lines = fs.readFileSync(MAP, 'utf8').split(/\r?\n/);
const NL = fs.readFileSync(MAP, 'utf8').includes('\r\n') ? '\r\n' : '\n';

if (lines.some(l => l.includes('avogadro_spawner'))) {
  console.error('add_avogadro_spawn: avogadro_spawner already present — refusing to re-run.');
  process.exit(0);
}

// Insert as top-level entities right after the worldspawn closing brace (first time
// brace depth returns to 0). Same anchor tools/respace used for the partition block.
function worldspawnCloseIdx() {
  let depth = 0;
  for (let i = 0; i < lines.length; i++) {
    const t = lines[i].trim();
    if (t === '{') depth++;
    else if (t === '}') { depth--; if (depth === 0) return i; }
  }
  return -1;
}
const wclose = worldspawnCloseIdx();
if (wclose < 0) { console.error('could not find worldspawn close brace'); process.exit(1); }

// PLAZA riser-location coords (navmesh-valid, z=0): spawner at (0,243.45,0); two
// spawn-locs spread across the start zone so choose_a_spawn has options near players.
const block = [
  '// ===== ACC Avogadro spawn entities (tools/add_avogadro_spawn.js) =====',
  spawnerEntity('0', '243.45', '0'),
  spawnLocStruct('348.5', '243.45', '0'),
  spawnLocStruct('-250', '243.45', '0'),
];
lines.splice(wclose + 1, 0, ...block);

fs.writeFileSync(MAP, lines.join(NL));
console.log('add_avogadro_spawn: inserted 1 avogadro_spawner + 2 avogadro_spawn_loc (Plaza). FULL build required.');
