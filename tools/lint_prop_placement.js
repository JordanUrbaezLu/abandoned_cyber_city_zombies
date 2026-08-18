#!/usr/bin/env node
// =============================================================================
// lint_prop_placement.js - static prop-placement + clip-safety preflight lint.
//
// THE permanent guard the 2026-08-03 STUCK-ZOMBIE CLUMPS fix promised
// ("TODO carried: port the riser-vs-clip proximity audit into tools/ as a
// preflight lint so the next deco pass can't regress this class" - CHANGELOG).
// Chained by tools/preflight_windows.ps1. Node, zero deps, exit 1 on any FAIL.
//
// Every check is a CONFIRMED failure class from this map's history:
//
//  1. RISER-VS-CLIP (< 45u): riser/dog spawn structs inside/near baked clip
//     footprints strand zombies on carved navmesh slivers (the Bus Station
//     queue-fence pile-ups; "zombies rose inside the taxi" 2026-07-19; the
//     trench-stair riser swallow). Standard: >= 45u from every clip edge,
//     2D rect distance, z-band aware. docs/47 safety rails; memory
//     `riser-clearance-standard-and-verify-method`. Walkable step-up clips
//     (top <= riser floor + 18u, the auto-step) are exempt - zombies walk onto
//     them by design (the L2 fault-pad precedent, add_prop_clips.js).
//  2. CLIP-VS-CLIP overlap: two passes placing solids on the same spot (the bus
//     sink 17u inside the arrivals-TV stand; the taxi move that swallowed the
//     oilrack + barrel 100% - docs/47 "intersection" class). Face-touching and
//     flush grazes <= 2u are legal (M3: "flush junk row - overlapping clip
//     brushes are legal"); anything deeper needs a CITED allow entry below.
//  3. TWIN LOCKSTEP: the baked .map misc_models ARE the live layout; the
//     _acc_surface_deco.gsc spawn tables are the dormant dev twin (deco dvars
//     default 0). Drift means `acc_surface_deco 1` doubles/resurrects props.
//     _acc_abyss_deco is deliberately NOT linted - it already drifted and is
//     TOMBSTONED (see its STALE-LEDGER TOMBSTONE header, 2026-08-03). WARN,
//     not FAIL: drift only bites the dev-iteration path, never normal play.
//  4. ENTITY HYGIENE: the LED-bake post-mortem's two red herrings promoted to
//     rules (CHANGELOG 2026-08-03 Wave 2): every baked misc_model must carry
//     the FULL lightingstate1..4 key set (a 1..3-only append shipped mid-saga)
//     and every guid must be PURE HEX ('ACCW2000' contained W - cod2map
//     tolerates it, Radiant does NOT) and unique file-wide.
//  5. LIGHT-MODEL INSTANCE CAP: a SECOND baked instance of a light-carrying
//     model crashes the Radiant LED bake ("SANITY CHECK FAILURE: Allocator
//     <Gfx::LightingStateInst, 1024> has outstanding allocations",
//     SharedPtrBlockAllocator.h:64) - proven by the Wave-2 4-round bisect on
//     p7_zm_asc_light_cage_warning_red (its single abyss instance bakes fine).
//
// RISER SOURCES: every .map script_struct with script_noteworthy
// riser_location/dog_location (any targetname - covers <zone>_zone_spawners
// AND the surge-only acc_trench_risers), PLUS the GSC-computed eruption spots
// parsed out of _acc_bus_trench.gsc (the Glitch Altar lesson: its Wave-2
// broadside rotation put the clip 17u from two L3 eruption risers that no .map
// grep could see, because those risers exist only as GSC literals):
//   get_trench_risers()   a_extra pit spots        (z -240)
//   get_layer_risers()    6 spots x floors L2..L5  (z -480/-720/-960/-1200)
//   get_paradise_risers() 12 spots                 (z -1200)
// LIMITATION (documented): those are the STATIC literals; at runtime each spot
// is nav-snapped DOWN (radius <= 128) so the live point can differ slightly.
// Placement decisions are made against the literals, so the literals are what
// gets linted. If the GSC is refactored so they stop parsing, this lint
// degrades to a WARN - never silently to nothing.
//
// CLIP SOURCE: tools/add_prop_clips.js PROPS[] parsed by LINE REGEX (never
// eval'd). Deep entries without `brushmodel: true` are SKIPPED exactly like
// the generator skips them (walk-through = no brush = no navmesh carve, no
// overlap). Gable/wedge anti-perch peaks are ignored: boxes are checked at
// [bot,top] (a peak only steepens the top - it never widens a footprint).
//
// ALLOW-LIST POLICY: every allow entry carries a citation (doc/CHANGELOG/
// add_prop_clips.js comment). Grandfathered riser pairs are RATCHET-LOCKED to
// the distance measured at lint introduction - if an edit narrows the gap
// further, the pair FAILS again. Allow rows that stop matching are reported
// stale so the ledgers self-clean.
//
// Usage:  node tools/lint_prop_placement.js      (exit 0 ok/warn, 1 fail,
//         2 parse/internal error)
// =============================================================================

'use strict';
const fs = require('fs');
const path = require('path');

const repo = path.join(__dirname, '..');
const mapPath = path.join(repo, 'map_source', 'zm', 'zm_abandoned_cyber_city.map');
const clipsPath = path.join(repo, 'tools', 'add_prop_clips.js');
const surfacePath = path.join(repo, 'scripts', 'zm', 'zm_abandoned_cyber_city', '_acc_surface_deco.gsc');
const trenchPath = path.join(repo, 'scripts', 'zm', 'zm_abandoned_cyber_city', '_acc_bus_trench.gsc');

const RISER_CLEARANCE = 45; // the 2026-08-03 standard (docs/47 safety rails)
const STEP_HEIGHT = 18;     // clip top within auto-step of the riser floor = walkable, exempt (L2 fault-pad precedent)
const GRAZE_TOL = 2;        // <= 2u penetration = legal flush graze (M3 junk-row rule)
const RISE_BAND_UP = 72;    // a rising zombie occupies riser z .. z + ~72 (capsule height)
const RISE_BAND_DOWN = 8;

// -----------------------------------------------------------------------------
// ALLOW LEDGERS - add entries ONLY with a citation. An uncited entry is a
// regression waiting to be grandfathered.
// -----------------------------------------------------------------------------

// Riser/clip pairs measured under 45u that PRE-DATE this lint (grandfathered at
// introduction, 2026-08-03 calibration run). Format: [key, ratchetDist] - the
// pair stays allowed only while its measured distance is >= ratchetDist - 0.5;
// getting WORSE re-fails it. These are watch-list debt, not licence: if a spot
// ever piles up live, fix it and DELETE its row. Key =
// "<targetname|gsc:src>:<riser|dog>:<x>,<y>,<z>|<clipLabel>".
const RISER_ALLOW = [
  ['start_zone_spawners:riser:150,185,0|plaza_cache_2', 40],     // 40.2u - plaza cache crate #2 vs the 2026-06-18 added riser; docs/47 item 5 kept origins ("all four keep >45u" was center-based; edge distance is 40)
  ['start_zone_spawners:riser:-400,420,0|plaza_cache_4', 11],    // 11.3u - cache_4's 2026-07-12 barricade-clearing move (-300->-360) closed on this riser; TOP FIX CANDIDATE (move riser or crate, then delete row)
  ['acc_trench_risers:riser:-320,1950,-240|pit_cache_w', 7.5],   // 8.0u - surge-only pit riser beside the gabled W cache crate (pre-2026-07 layout, no live pile-up reported; pit erupts only when players drop in)
  ['acc_trench_risers:riser:320,1950,-240|pit_cache_e', 7.5],    // 8.0u - E twin of the above
  ['gsc:L3:400,2046,-720|pillar_l3_rock_e', 35],                 // 35.2u - L3 slalom spore rock (approved 2026-07-12) vs the 2026-06-22 layer-riser grid
  ['gsc:L5:400,2046,-1200|l5_column', 27],                       // 27.2u - snake column (moved onto 470 for the D4 landing, 2026-07-13) vs the layer-riser grid
  ['gsc:L5:-250,1770,-1200|l5_egg_nest_s', 0],                   // 0.0u - the 2026-08-01 scare-pass mid-band spot lands INSIDE the L5 S-wall egg-nest clip; TOP FIX CANDIDATE (shift the L5 spot or the nest, then delete row)
  ['gsc:L5:-250,1770,-1200|inf_l5_niche_egg', 39.5],             // 40.0u - same scare-pass spot vs the W-niche anchor egg
];

// Clip pairs allowed to interpenetrate deeper than GRAZE_TOL (order-free).
const OVERLAP_ALLOW = [
  ['bus_table_kitchen_long', 'bus_window_teller'],    // ticket-office booth: teller windows mounted ON the counter (surface_deco S/TICKET OFFICE fixture)
  ['bus_table_kitchen_long', 'bus_window_teller_2'],  // second teller window, same fixture
  ['bus_debris_rubble_02', 'bus_m4_schoolbus_seal'],  // rubble drift under the sealed coach flank (the FB3 2026-07-19 re-park parked the oversize seal over the maintenance-corner rubble)
  ['bus_tv_vintage_on_4', 'bus_x_bench_wood'],        // GRANDFATHERED 2026-08-03: arrivals-TV stand vs pass-3 bench, 11u - not in docs/47's findings (probable audit miss); walkabout candidate
  ['alley_fence_quarantine', 'alley_power_panel'],    // leaning quarantine fence's 2u-thin plane grazes the panel 4u - wall junk row (2026-07-16 pass 2)
  ['lab_apd_turbine', 'lab_aether_canister_on'],      // canister tucked into the turbine flank when both flushed onto the new N wall (2026-08-02 lab compression relayout)
  ['roof_c_debris_rubble', 'roof_m4_bomber_wall_e_n'],// "crash rubble flush with the M4 bomber shell (intentional graze - overlap legal)" (add_prop_clips.js)
  ['m6_l3_egg1', 'm6_l3_egg2'],                       // the fused W-bay 3-egg nest (M6 organics; eggs share a mass)
  ['inf_l3_wnest', 'm6_l3_egg1'],                     // inf_l3_wnest IS the cluster box over "the ORIGINAL M6 3-egg W-bay nest" (add_prop_clips.js) - it contains its member eggs by design
  ['inf_l3_wnest', 'm6_l3_egg2'],
  ['inf_l3_wnest', 'm6_l3_egg3'],
  ['pillar_l3_root_w', 'm6_l3_tent1'],                // the L3 tentacle wall mass engulfs the slalom root - same class as its cited rock_sw wrap
  ['m6_l3_tent1', 'l3_rock_sw'],                      // "wraps the SW spore-rock clip - overlap legal" (add_prop_clips.js)
  ['l4_vessel_s', 'inf_l4_vsw_egg'],                  // "vessel SW-corner egg (flush S)" - egg fused to the vessel (2026-07-29 coverage pass)
  ['l5_monolith_e', 'l5_egg_base_se'],                // E-bay fused set pieces (L5 approved pass 2026-07-13)
  ['l5_monolith_e', 'inf_l5_fbe_egg'],                // "Field B east egg (brute2-fused)" - fused organics vs the monolith
  ['bench_slot1', 'inf_pd_brood_sw'],                 // accepted 2026-08-03 Wave-2 verify: "organic infestation swallowing the bench reads intentionally; flagged for the walkabout"
  ['m6_pd_palm1', 'inf_pd_brood_sw'],                 // Paradise corner-palm trunks engulfed by the 2026-07-29 infestation cluster boxes (broods/satellites/heart placed AROUND the palms)
  ['m6_pd_palm2', 'inf_pd_brood_se'],
  ['m6_pd_palm3', 'inf_pd_brood_ne'],
  ['m6_pd_palm4', 'inf_pd_brood_nw'],
  ['m6_pd_palm5', 'inf_pd_sat_w'],
  ['m6_pd_palm7', 'inf_pd_heart'],
];

// Multi-part single-fixture clip sets: BOTH labels sharing one of these stems =
// one prop's fitted brush assembly (posts+lintel, frame+door, hull+roof) -
// joins overlap by construction (the 2026-07-19 fitted-set reworks).
const ASSEMBLY_PREFIXES = ['lab_decon1_', 'lab_decon2_', 'lab_decon3_', 'bus_vault_bank_', 'roof_m4_bomber_'];

// spawn_prop lines with deliberately NO baked twin.
const GSC_ONLY_ALLOW = [
  'p8_zm_off_elevator_arrow', // docs/47 Vault: "the GSC-only elevator arrow at (1610,3380,120) which never renders (model absent from gdtDB, already documented)"
];

// Baked-only misc_model batches with deliberately NO GSC twin (guid stamp).
// (The map->GSC direction is also scoped to the `// ---- acc_surface_deco::`
// bake sections, so these prefixes are belt-and-suspenders documentation.)
const BAKED_ONLY_GUID_PREFIXES = [
  'ACC02026', // Plaza->Alley connector density-gradient pass (Wave 2 2026-08-03, authored straight into the .map)
  'ACC5C0DE', // Scientist's Office statics (gen_scientist_office.js, 2026-07-26)
  'ACCA9000', // Lab compression/densification NEW_STATICS (gen_compress_lab_paradise.js, 2026-08-02)
];

// Models that may appear AT MOST ONCE as a baked misc_model (the LED
// LightingStateInst crash class). Grow this whenever a bisect convicts another
// light-carrying model - never shrink it on a hunch.
const SINGLE_INSTANCE_MODELS = [
  'p7_zm_asc_light_cage_warning_red', // PROVEN: a 2nd baked instance crashes the LED bake (Wave-2 bisect, CHANGELOG 2026-08-03)
];

// -----------------------------------------------------------------------------
// parsers
// -----------------------------------------------------------------------------
function abort(msg) { console.log('prop-placement ERROR: ' + msg); process.exit(2); }
function vec3(s) { const p = (s || '').trim().split(/\s+/).map(Number); return (p.length === 3 && p.every(n => !isNaN(n))) ? p : null; }

function parseMap(text) {
  const lines = text.split('\n');
  const ents = []; const allGuids = []; const surfaceSections = [];
  let secStart = -1;
  for (let i = 0; i < lines.length; i++) {           // bake-section markers (comments)
    if (/^\/\/ ---- acc_surface_deco::/.test(lines[i])) { if (secStart >= 0) surfaceSections.push([secStart, i]); secStart = i + 1; }
    else if (/^\/\/ ---- /.test(lines[i]) && secStart >= 0) { surfaceSections.push([secStart, i]); secStart = -1; }
  }
  if (secStart >= 0) surfaceSections.push([secStart, lines.length]);
  let depth = 0, cur = null;
  for (let i = 0; i < lines.length; i++) {
    const l = lines[i];
    if (/^\s*\/\//.test(l)) continue;   // comment lines never carry entity braces/keys - skip so a brace in prose can't corrupt the walk
    const opens = (l.match(/{/g) || []).length, closes = (l.match(/}/g) || []).length;
    if (depth === 0 && opens > 0) cur = { line: i + 1, kv: {}, guid: null };
    if (cur) {
      const g = l.match(/^\s*guid\s+"\{([^}]*)\}"/);
      if (g) { allGuids.push({ v: g[1], line: i + 1 }); if (depth <= 1 && cur.guid === null) cur.guid = g[1]; }
      if (depth <= 1) {
        const m = l.match(/^\s*"([^"]+)"\s+"([^"]*)"/);
        if (m && cur.kv[m[1]] === undefined) cur.kv[m[1]] = m[2];
      }
    }
    depth += opens - closes;
    if (depth < 0) abort('.map brace underflow at line ' + (i + 1));
    if (depth === 0 && cur) { ents.push(cur); cur = null; }
  }
  if (depth !== 0) abort('.map brace imbalance (depth ' + depth + ' at EOF)');
  return { ents, allGuids, surfaceSections };
}

function parseClips(text) {
  const constM = text.match(/const CLIP_BOT\s*=\s*(-?\d+(?:\.\d+)?)\s*,\s*CLIP_TOP\s*=\s*(-?\d+(?:\.\d+)?)/);
  if (!constM) abort('add_prop_clips.js: CLIP_BOT/CLIP_TOP consts not found (format changed? update this parser)');
  const DEF_BOT = Number(constM[1]), DEF_TOP = Number(constM[2]);
  const clips = [];
  const re = /^\s*\{\s*x:\s*(-?[\d.]+)\s*,\s*y:\s*(-?[\d.]+)\s*,\s*hx:\s*(-?[\d.]+)\s*,\s*hy:\s*(-?[\d.]+)\s*,(.*?)label:\s*'([^']+)'/;
  const lines = text.split('\n');
  for (let i = 0; i < lines.length; i++) {
    const m = lines[i].match(re);
    if (!m) continue;
    const rest = m[5];
    const bot = (rest.match(/bot:\s*(-?[\d.]+)/) || [])[1];
    const top = (rest.match(/top:\s*(-?[\d.]+)/) || [])[1];
    clips.push({
      x: Number(m[1]), y: Number(m[2]), hx: Number(m[3]), hy: Number(m[4]),
      bot: bot !== undefined ? Number(bot) : DEF_BOT,
      top: top !== undefined ? Number(top) : DEF_TOP,
      deepSkipped: bot !== undefined && Number(bot) < DEF_BOT && !/brushmodel:\s*true/.test(rest),
      label: m[6], line: i + 1,
    });
  }
  return { emitted: clips.filter(c => !c.deepSkipped), total: clips.length };
}

function parseSurfaceSpawns(text) {
  const spawns = [];
  const re = /spawn_prop\(\s*"([^"]+)"\s*,\s*\(\s*(-?[\d.]+)\s*,\s*(-?[\d.]+)\s*,\s*(-?[\d.]+)\s*\)\s*,\s*\(\s*(-?[\d.]+)\s*,\s*(-?[\d.]+)\s*,\s*(-?[\d.]+)\s*\)\s*\)/;
  const lines = text.split('\n');
  for (let i = 0; i < lines.length; i++) {
    const m = lines[i].replace(/\/\/.*$/, '').match(re);   // commented-out spawns don't count
    if (m) spawns.push({ model: m[1], o: [Number(m[2]), Number(m[3]), Number(m[4])],
      a: [Number(m[5]), Number(m[6]), Number(m[7])], line: i + 1 });
  }
  return spawns;
}

// GSC-computed eruption spots (see header LIMITATION).
function parseSyntheticRisers(text) {
  function body(fnName) {
    const idx = text.indexOf('function ' + fnName);
    if (idx < 0) return null;
    const open = text.indexOf('{', idx);
    if (open < 0) return null;
    let d = 0;
    for (let j = open; j < text.length; j++) {
      if (text[j] === '{') d++;
      else if (text[j] === '}') { d--; if (d === 0) return text.slice(open, j + 1); }
    }
    return null;
  }
  function spots(b) {
    const s = []; let m;
    const re = /\[\s*(?:\d+|\w+\.size)\s*\]\s*=\s*\(\s*(-?[\d.]+)\s*,\s*(-?[\d.]+)\s*,\s*(?:-?[\d.]+|fz|pz)\s*\)\s*;/g;
    while ((m = re.exec(b))) s.push([Number(m[1]), Number(m[2])]);
    return s;
  }
  const out = [];
  const pit = body('get_trench_risers');
  if (pit) for (const s of spots(pit)) out.push({ x: s[0], y: s[1], z: -240, src: 'gsc:pit_extra' });
  const layer = body('get_layer_risers');
  if (layer) {
    const raw = spots(layer);
    for (let L = 2; L <= 5; L++) {
      const fz = -240 - (L - 1) * 240;               // mirrors get_layer_risers' floor formula
      for (const s of raw) out.push({ x: s[0], y: s[1], z: fz, src: 'gsc:L' + L });
    }
  }
  const pd = body('get_paradise_risers');
  if (pd) for (const s of spots(pd)) out.push({ x: s[0], y: s[1], z: -1200, src: 'gsc:paradise' });
  return { out, sawPit: !!pit, sawLayer: !!layer, sawPd: !!pd };
}

// -----------------------------------------------------------------------------
// geometry
// -----------------------------------------------------------------------------
function rectDist2D(px, py, c) {
  const dx = Math.max(c.x - c.hx - px, 0, px - (c.x + c.hx));
  const dy = Math.max(c.y - c.hy - py, 0, py - (c.y + c.hy));
  return Math.sqrt(dx * dx + dy * dy);
}

// -----------------------------------------------------------------------------
// load
// -----------------------------------------------------------------------------
for (const p of [mapPath, clipsPath, surfacePath, trenchPath])
  if (!fs.existsSync(p)) abort('missing input file: ' + p);

const map = parseMap(fs.readFileSync(mapPath, 'utf8'));
const clipData = parseClips(fs.readFileSync(clipsPath, 'utf8'));
const clips = clipData.emitted;
const surfaceSpawns = parseSurfaceSpawns(fs.readFileSync(surfacePath, 'utf8'));
const synth = parseSyntheticRisers(fs.readFileSync(trenchPath, 'utf8'));

// Parse-degradation canaries: these counts only ever grow. A collapse means a
// regex went stale against a format change - that must never pass silently.
if (clipData.total < 350) abort('only ' + clipData.total + ' PROPS entries parsed from add_prop_clips.js (413 at 2026-08-03; regex stale?)');
if (surfaceSpawns.length < 350) abort('only ' + surfaceSpawns.length + ' spawn_prop calls parsed from _acc_surface_deco.gsc (426 at 2026-08-03; regex stale?)');

const miscModels = map.ents.filter(e => e.kv.classname === 'misc_model');
const mapRisers = map.ents
  .filter(e => e.kv.classname === 'script_struct' &&
    (e.kv.script_noteworthy === 'riser_location' || e.kv.script_noteworthy === 'dog_location'))
  .map(e => {
    const o = vec3(e.kv.origin) || [0, 0, 0];
    return { x: o[0], y: o[1], z: o[2], line: e.line,
      src: (e.kv.targetname || '?') + ':' + (e.kv.script_noteworthy === 'dog_location' ? 'dog' : 'riser') };
  });
const risers = mapRisers.concat(synth.out.map(s => ({ x: s.x, y: s.y, z: s.z, line: 0, src: s.src })));

const problems = [];   // FAIL lines -> exit 1
const warns = [];      // WARN lines -> exit 0
const passLines = [];

// -----------------------------------------------------------------------------
// CHECK 1: riser-vs-clip clearance (>= 45u, z-band aware, step-exempt)
// -----------------------------------------------------------------------------
{
  const bad = [];
  const allowHit = new Set();
  const allowMap = new Map(RISER_ALLOW.map(r => [r[0], r[1]]));
  let minSeen = Infinity, minPair = '';
  for (const r of risers) {
    for (const c of clips) {
      if (!(r.z - RISE_BAND_DOWN <= c.top && c.bot <= r.z + RISE_BAND_UP)) continue; // clip not in the rise band
      if (c.top - r.z <= STEP_HEIGHT) continue;                                      // walkable step-up plate
      const d = rectDist2D(r.x, r.y, c);
      if (d < minSeen && d >= RISER_CLEARANCE) { minSeen = d; minPair = r.src + '(' + r.x + ',' + r.y + ') vs ' + c.label; }
      if (d >= RISER_CLEARANCE) continue;
      const key = r.src + ':' + r.x + ',' + r.y + ',' + r.z + '|' + c.label;
      if (allowMap.has(key)) {
        allowHit.add(key);
        if (d >= allowMap.get(key) - 0.5) continue;  // ratchet holds
        bad.push('  GRANDFATHERED PAIR GOT WORSE: ' + key + ' now ' + d.toFixed(1) + 'u (ratchet ' + allowMap.get(key) + 'u)');
        continue;
      }
      bad.push('  riser ' + r.src + ' (' + r.x + ',' + r.y + ',' + r.z + ')' + (r.line ? ' [.map:' + r.line + ']' : '') +
        ' is ' + d.toFixed(1) + 'u from clip \'' + c.label + '\' (add_prop_clips.js:' + c.line + ') - standard is >= ' + RISER_CLEARANCE + 'u');
    }
  }
  for (const [key] of allowMap) if (!allowHit.has(key))
    warns.push('[WARN] stale RISER_ALLOW row (pair no longer under ' + RISER_CLEARANCE + 'u or renamed) - delete it: ' + key);
  if (bad.length) problems.push('[FAIL] riser-vs-clip clearance: ' + bad.length + ' pair(s) under ' + RISER_CLEARANCE + 'u:', ...bad);
  else passLines.push('[PASS] riser-vs-clip clearance: ' + risers.length + ' spots (' + mapRisers.length + ' .map + ' +
    synth.out.length + ' GSC-computed) vs ' + clips.length + ' emitted clips, all >= ' + RISER_CLEARANCE + 'u' +
    (RISER_ALLOW.length ? ' (' + allowHit.size + ' grandfathered pair(s) ratchet-locked)' : '') +
    (minPair ? '; tightest clean pair ' + minSeen.toFixed(1) + 'u: ' + minPair : ''));
  if (!synth.sawPit || !synth.sawLayer || !synth.sawPd)
    warns.push('[WARN] synthetic-riser parse incomplete (pit=' + synth.sawPit + ' layers=' + synth.sawLayer + ' paradise=' + synth.sawPd +
      ') - _acc_bus_trench.gsc refactored? Update parseSyntheticRisers or the eruption spots go unguarded.');
}

// -----------------------------------------------------------------------------
// CHECK 2: clip-vs-clip 3D AABB overlap
// -----------------------------------------------------------------------------
{
  const bad = [];
  const allow = new Set(OVERLAP_ALLOW.map(p => [...p].sort().join('|')));
  const allowHit = new Set();
  let grazes = 0, assemblies = 0;
  for (let i = 0; i < clips.length; i++) {
    for (let j = i + 1; j < clips.length; j++) {
      const a = clips[i], b = clips[j];
      const ox = Math.min(a.x + a.hx, b.x + b.hx) - Math.max(a.x - a.hx, b.x - b.hx);
      const oy = Math.min(a.y + a.hy, b.y + b.hy) - Math.max(a.y - a.hy, b.y - b.hy);
      const oz = Math.min(a.top, b.top) - Math.max(a.bot, b.bot);
      if (ox <= 0 || oy <= 0 || oz <= 0) continue;             // separate or face-touching = legal
      const pen = Math.min(ox, oy, oz);
      if (pen <= GRAZE_TOL) { grazes++; continue; }            // flush graze (M3 rule)
      if (ASSEMBLY_PREFIXES.some(p => a.label.startsWith(p) && b.label.startsWith(p))) { assemblies++; continue; }
      const key = [a.label, b.label].sort().join('|');
      if (allow.has(key)) { allowHit.add(key); continue; }
      bad.push('  clips \'' + a.label + '\' (L' + a.line + ') + \'' + b.label + '\' (L' + b.line + ') interpenetrate ' +
        ox.toFixed(1) + 'x' + oy.toFixed(1) + 'x' + oz.toFixed(1) + 'u (min ' + pen.toFixed(1) + 'u > graze ' + GRAZE_TOL +
        'u) - move one, or add a CITED OVERLAP_ALLOW entry');
    }
  }
  for (const p of OVERLAP_ALLOW) { const k = [...p].sort().join('|'); if (!allowHit.has(k))
    warns.push('[WARN] stale OVERLAP_ALLOW pair (no longer intersecting or renamed) - delete it: ' + p.join(' + ')); }
  if (bad.length) problems.push('[FAIL] clip-vs-clip overlap: ' + bad.length + ' undocumented interpenetration(s):', ...bad);
  else passLines.push('[PASS] clip-vs-clip overlap: ' + clips.length + ' emitted clips, 0 undocumented interpenetrations (' +
    grazes + ' flush grazes <= ' + GRAZE_TOL + 'u, ' + assemblies + ' fitted-assembly joins, ' + allowHit.size + ' cited allowances)');
}

// -----------------------------------------------------------------------------
// CHECK 3: .map <-> _acc_surface_deco.gsc twin lockstep (WARN on drift)
// -----------------------------------------------------------------------------
{
  const drift = [];
  const byModel = {};
  for (const e of miscModels) (byModel[e.kv.model] = byModel[e.kv.model] || []).push(e);
  const matched = new Set();
  let gscOnlyAllowed = 0;
  const yaw = v => ((v % 360) + 360) % 360;
  for (const s of surfaceSpawns) {
    let hit = null;
    for (const e of (byModel[s.model] || [])) {
      const o = vec3(e.kv.origin);
      if (o && Math.abs(o[0] - s.o[0]) <= 1 && Math.abs(o[1] - s.o[1]) <= 1 && Math.abs(o[2] - s.o[2]) <= 1) { hit = e; break; }
    }
    if (!hit) {
      if (GSC_ONLY_ALLOW.includes(s.model)) gscOnlyAllowed++;
      else drift.push('  GSC-only: spawn_prop ' + s.model + ' @ (' + s.o.join(',') + ') [_acc_surface_deco.gsc:' + s.line + '] has no baked misc_model twin');
      continue;
    }
    matched.add(hit.line);
    const a = vec3(hit.kv.angles) || [0, 0, 0];
    if (Math.abs(a[0] - s.a[0]) > 0.01 || Math.abs(yaw(a[1]) - yaw(s.a[1])) > 0.01 || Math.abs(a[2] - s.a[2]) > 0.01)
      drift.push('  angle drift: ' + s.model + ' @ (' + s.o.join(',') + ') GSC (' + s.a.join(',') + ') vs .map "' + hit.kv.angles +
        '" [gsc:' + s.line + ' map:' + hit.line + ']');
  }
  // map->GSC: only inside the `// ---- acc_surface_deco::` bake sections (the
  // baked twins of this file). Abyss sections = the tombstoned twin, skipped;
  // generator/wave batches outside sections are baked-only by design (see
  // BAKED_ONLY_GUID_PREFIXES).
  const inSurfaceSection = line => map.surfaceSections.some(([s, e]) => line > s && line <= e);
  const mapOnly = [];
  for (const e of miscModels) {
    if (matched.has(e.line) || !inSurfaceSection(e.line)) continue;
    if (BAKED_ONLY_GUID_PREFIXES.some(p => (e.guid || '').toUpperCase().startsWith(p))) continue;
    mapOnly.push('  map-only: misc_model ' + e.kv.model + ' @ (' + e.kv.origin + ') [.map:' + e.line +
      '] sits in an acc_surface_deco bake section but has no spawn_prop twin');
  }
  const all = drift.concat(mapOnly);
  if (all.length) {
    warns.push('[WARN] twin lockstep (surface deco): ' + drift.length + ' GSC-side + ' + mapOnly.length +
      ' map-side drift(s) - acc_surface_deco 1 would double/resurrect these (fix in lockstep; abyss twin NOT linted: tombstoned):');
    warns.push(...all.slice(0, 20));
    if (all.length > 20) warns.push('  ... and ' + (all.length - 20) + ' more');
  } else {
    passLines.push('[PASS] twin lockstep: ' + (surfaceSpawns.length - gscOnlyAllowed) + ' surface spawn_prop calls have exact baked twins (origin+angles)' +
      (gscOnlyAllowed ? ' + ' + gscOnlyAllowed + ' documented GSC-only' : '') + '; no bake-section orphans (abyss twin skipped: tombstoned 2026-08-03)');
  }
}

// -----------------------------------------------------------------------------
// CHECK 4: misc_model entity hygiene (lightingstate1..4, hex + unique guids)
// -----------------------------------------------------------------------------
{
  const bad = [];
  for (const e of miscModels) {
    const missing = [1, 2, 3, 4].filter(n => e.kv['lightingstate' + n] === undefined);
    if (missing.length) bad.push('  misc_model ' + (e.kv.model || '?') + ' @ (' + (e.kv.origin || '?') + ') [.map:' + e.line +
      '] missing lightingstate' + missing.join('/') + ' (LED post-mortem rule: full 1..4 set)');
    if (!e.guid) bad.push('  misc_model ' + (e.kv.model || '?') + ' [.map:' + e.line + '] has NO guid');
  }
  const seen = {};
  for (const g of map.allGuids) {
    if (!/^[0-9A-Fa-f-]+$/.test(g.v))
      bad.push('  non-hex guid {' + g.v + '} [.map:' + g.line + '] (cod2map tolerates it, Radiant does NOT - LED post-mortem)');
    if (seen[g.v] !== undefined) bad.push('  duplicate guid {' + g.v + '} [.map:' + seen[g.v] + ' and ' + g.line + ']');
    else seen[g.v] = g.line;
  }
  if (bad.length) problems.push('[FAIL] entity hygiene: ' + bad.length + ' problem(s):', ...bad);
  else passLines.push('[PASS] entity hygiene: ' + miscModels.length + ' misc_models all carry lightingstate1..4 + a guid; ' +
    map.allGuids.length + ' guids all pure-hex + unique');
}

// -----------------------------------------------------------------------------
// CHECK 5: single-baked-instance light models (LED LightingStateInst crash)
// -----------------------------------------------------------------------------
{
  const bad = [];
  for (const model of SINGLE_INSTANCE_MODELS) {
    const inst = miscModels.filter(e => e.kv.model === model);
    if (inst.length > 1)
      bad.push('  ' + model + ' baked ' + inst.length + 'x: ' + inst.map(e => '(' + e.kv.origin + ') .map:' + e.line).join(', ') +
        ' - a 2nd baked instance CRASHES the LED bake (LightingStateInst allocator; Wave-2 bisect-proven)');
  }
  if (bad.length) problems.push('[FAIL] light-model instance cap: ' + bad.length + ' violation(s):', ...bad);
  else passLines.push('[PASS] light-model instance cap: ' + SINGLE_INSTANCE_MODELS.length + ' guarded model(s), each <= 1 baked instance');
}

// -----------------------------------------------------------------------------
// report - lint_gsc_xref.js shape: headline first, then detail; exit 1 on FAIL
// -----------------------------------------------------------------------------
const warnGroups = warns.filter(w => w.startsWith('[WARN]')).length;
if (problems.length === 0) {
  console.log('prop-placement OK: risers/overlaps/lockstep/hygiene/light-cap clean' +
    (warnGroups ? ' (' + warnGroups + ' warning(s) below)' : ''));
  passLines.forEach(l => console.log(l));
  warns.forEach(l => console.log(l));
  process.exit(0);
} else {
  console.log('prop-placement FAIL: ' + problems.filter(p => p.startsWith('[FAIL]')).length + ' check(s) red:');
  problems.forEach(l => console.log(l));
  passLines.forEach(l => console.log(l));
  warns.forEach(l => console.log(l));
  process.exit(1);
}
