#!/usr/bin/env node
// =============================================================================
// noir_relight_v1.js - THE NOIR RELIGHT (docs/46 Phase 1, marker ACCNR01)
//
// One-shot .map KVP batch that inverts the light rig from "shadowless uniform
// white wash" to the docs/20 SS1 noir formula (85% dark base, colored
// fixture-motivated pools, the map's first real shadows). User-approved
// map-wide 2026-07-29. Root causes attacked: RC1 (white shadowless rig),
// RC4 partial (sourceless pools -> pools re-homed onto fixture props), RC8
// (below-surface probe inversion).
//
// WHAT IT DOES (all KVP edits + appended entities - ZERO new lit worldspawn
// surface, so no new lightmap atlas charts -> near-zero brush.cpp:1860 risk):
//   1. Recolors the ~137 white/utility lights per zone-hue family table
//      (tint 25-40% sat toward the zone's acc_neon hue; grid bake 1.3->0.7;
//      stops varied; sodium amber underground/hub/exchange).
//   2. Raises the 22 acc_neon pools to bake 1.0-1.2 / stops 7.5 and MOVES 15
//      of them onto the nearest same-zone fixture prop (only 4/159 lights sat
//      near a visible source; the eye needs the source->pool relationship).
//   3. Appends 9 small fixture-pair omnis (clones of the proven radius-260
//      under-light template) at neon signs / street lamps / holo screens.
//   4. Appends 11 shadow-casting PRIMARY_SPOT downlights (template = stock
//      zm_giant_light.map entity 34, PRIMARY_NOSHADOWMAP 0 + shadowUpdate
//      Never = BAKED shadows, zero runtime cost; no def/cookie in v1; spots
//      with no angles/target key aim STRAIGHT DOWN - verified stock shape)
//      on the 7 landmarks + 4 story vignettes. NO lights below the trench lip
//      (abyss CTD lockout, memory abyss-horror-enhancement-plan).
//   5. Appends 4 below-surface reflection probes (Exchange/hub/abyss/Paradise,
//      brightnessAdjust -5 / evcomp -5 = the dark-ambient fix for "the abyss
//      won't get dark") and completes the 9 bare surface probes with
//      resolution 8x + ao_range 38 (brightness/evcomp kept 0 to MATCH their
//      7 configured twins - the alien-map -5/-5 on surface probes would seam
//      against the zeroed twins; below-surface only).
//   6. Worldspawn lightingquality 1024 -> 2048 (docs/46 fallback tier; 4096
//      deferred - it taxes every future phase's bake, audition later).
//
// RADII ARE FROZEN (standing ruling - the ledger's <=150-crash claim vs the
// shipped 250-540 green bakes is unresolved): this tool never edits a radius
// and ASSERTS it never does. New omnis use the proven 260 template value.
//
// REVERT (user-taste one-command restore, docs/46 P1 graft):
//   node tools/oneshots/noir_relight_v1.js --revert
//   -> restores map_source/zm/zm_abandoned_cyber_city.map.acc-nr01-orig
//      (the byte-exact pre-apply backup this tool writes on apply).
//
// SAFETY: refuses to re-apply (marker ACCNR01), refuses if the backup exists,
// refuses on guid-prefix collision (ACCB7), and aborts BEFORE writing if any
// light-family count disagrees with the 2026-07-29 audit (159 lights total).
// =============================================================================
'use strict';
const fs = require('fs');
const path = require('path');

const MAP = path.join(__dirname, '..', '..', 'map_source', 'zm', 'zm_abandoned_cyber_city.map');
const BACKUP = MAP + '.acc-nr01-orig';
const MARKER = 'ACCNR01';
const GUID_PREFIX = 'ACCB7'; // hex-only (the abyss one-shot hit a stock collision with ACB4 -> we pre-grep)

// --- zone hue tints (white -> hue at s saturation) --------------------------
// hues = the baked acc_neon canon (docs/46 zone identity table)
const T = {
  corpBlue:   '0.7 0.79 1',      // blue  s.35
  plazaCyan:  '0.7 1 1',         // cyan  s.30
  labPurple:  '0.86 0.72 1',     // purple s.35
  marketMag:  '1 0.65 1',        // magenta s.35
  vaultGreen: '0.745 1 0.775',   // green s.30
  roofOrange: '1 0.8 0.67',      // orange s.35
  alleyRed:   '1 0.68 0.68',     // red   s.35
  underAmber: '1 0.82 0.65',     // sodium s.40 (under-rooms)
  hubAmber:   '1 0.84 0.69',     // sodium s.35 (abyss-descent hub)
  exchAmber:  '1 0.75 0.52',     // sodium s.55 (Exchange - the "amber gloom" room)
  lampSodium: '1 0.72 0.4',
};
// connector tints: stronger (s.40) toward the DESTINATION zone (cluster B -
// every doorway frames the next district's hue)
const C = {
  blue:   '0.66 0.76 1',
  mag:    '1 0.6 1',
  red:    '1 0.632 0.632',
  orange: '1 0.78 0.62',
  purple: '0.84 0.68 1',
  green:  '0.66 1 0.7',
};

// --- family edit table (matched IN ORDER; first hit wins) --------------------
// fields: color/bake/stops = set if present; undefined = leave untouched.
const FAMILIES = [
  { name: 'connector', re: /^acc_roof_light_c_(mkt_corp|al_corp)_?\d*$/,  color: C.blue,   bake: '0.75', stops: '5.5', expect: 2 },
  { name: 'conn_mag',  re: /^acc_roof_light_c_sp_mkt_?\d*$/,             color: C.mag,    bake: '0.75', stops: '5.5', expect: 1 },
  { name: 'conn_red',  re: /^acc_roof_light_c_sp_al_?\d*$/,              color: C.red,    bake: '0.75', stops: '5.5', expect: 1 },
  { name: 'conn_org',  re: /^acc_roof_light_c_corp_roof_?\d*$/,          color: C.orange, bake: '0.75', stops: '5.5', expect: 1 },
  { name: 'conn_pur',  re: /^acc_roof_light_c_(vlt_lab|roof_lab)_?\d*$/, color: C.purple, bake: '0.75', stops: '5.5', expect: 2 },
  { name: 'conn_grn',  re: /^acc_roof_light_c_corp_vlt_?\d*$/,           color: C.green,  bake: '0.75', stops: '5.5', expect: 1 },
  { name: 'corp',      re: /^acc_roof_light_corp_\d+$/,   color: T.corpBlue,   bake: '0.7', stops: '5', expect: 16 },
  { name: 'plaza',     re: /^acc_roof_light_plaza_\d+$/,  color: T.plazaCyan,  bake: '0.5', stops: '5', expect: 15 },
  { name: 'lab',       re: /^acc_roof_light_lab_\d+$/,    color: T.labPurple,  bake: '0.7', stops: '5', expect: 12 },
  { name: 'market',    re: /^acc_roof_light_market_\d+$/, color: T.marketMag,  bake: '0.7', stops: '5', expect: 6 },
  { name: 'vault',     re: /^acc_roof_light_vault_\d+$/,  color: T.vaultGreen, bake: '0.7', stops: '5', expect: 6 },
  { name: 'roof',      re: /^acc_roof_light_roof_\d+$/,   color: T.roofOrange, bake: '0.7', stops: '5', expect: 6 },
  { name: 'alley',     re: /^acc_roof_light_alley_\d+$/,  color: T.alleyRed,   bake: '0.7', stops: '5', expect: 6 },
  { name: 'spine',     re: /^acc_roof_light_(spine_\d+|east_strip_\d+)$/, color: T.corpBlue, bake: '0.7', stops: '5', expect: 3 },
  { name: 'under',     re: /^acc_under_light_\w+_\d+$/,   color: T.underAmber, stops: '5', expect: 41 },  // bake untouched (0.25-0.35 dim variance preserved)
  { name: 'hub',       re: /^acc_hub_(plaza|hall)_light_\d+$/, color: T.hubAmber, stops: '5', expect: 8 }, // bake untouched
  { name: 'exchange',  re: /^acc_exchange_light_\w+$/,    color: T.exchAmber,  bake: '0.8', stops: '6', expect: 4 }, // retires the map's 4 brightest whites (1.4-1.5)
  { name: 'armory',    re: /^acc_armory_light_\d+$/,      bake: '0.75', stops: '5.5', expect: 4 },
  { name: 'sci',       re: /^acc_sci_light_\d+$/,         expect: 2 },  // already pale-blue + dim: untouched
  { name: 'neonTrench',re: /^acc_neon_(20|21)$/,          bake: '1.0', stops: '7.5', expect: 2 },  // canon yellow stays, lifted
  { name: 'neon',      re: /^acc_neon_\d+$/,              bake: '1.2', stops: '7.5', expect: 20 },
];
const EXPECT_TOTAL = 159;

// --- pool re-homes: acc_neon_N -> nearest same-zone fixture prop (x y z) -----
// (fixture origins grep-verified from the .map 2026-07-29; z = pool's original)
const POOL_MOVES = {
  acc_neon_0:  '-40 130 150',     // Plaza -> memorial fountain angel
  acc_neon_1:  '-469 340 150',    // Plaza -> LED bar (W pair)
  acc_neon_2:  '212 150 150',     // Plaza -> LED bar (E pair)
  acc_neon_3:  '0 1360 175',      // corp  -> ceiling cage light S
  acc_neon_4:  '0 2280 175',      // corp  -> ceiling cage light N
  acc_neon_5:  '-560 1690 175',   // corp  -> street lamp W
  acc_neon_6:  '795 2100 175',    // corp  -> sconce E
  acc_neon_7:  '-1720 700 150',   // Market -> cage light S
  acc_neon_8:  '-2120 1130 150',  // Market -> videostore label wall
  acc_neon_9:  '-1305 528 150',   // Market -> videostore billboard
  acc_neon_10: '1610 995 150',    // Alley -> the (now burning) barrel
  acc_neon_12: '-1500 2600 150',  // Helipad -> cage light S
  acc_neon_13: '-1500 3050 150',  // Helipad -> cage light N
  acc_neon_15: '1650 3050 150',   // Vault -> cage light N
  acc_neon_16: '1400 2700 150',   // Vault -> cage light mid
};

// --- new fixture-pair omnis (cloned from the proven radius-260 template) -----
const NEW_OMNIS = [
  { tn: 'acc_nr_fix_0', origin: '-1560 1420 150', color: '1 0 1',        bake: '0.9', stops: '6.5' }, // Market diner neon sign (N wall)
  { tn: 'acc_nr_fix_1', origin: '-2114 900 120',  color: '1 0 1',        bake: '0.8', stops: '6.5' }, // Market neon bunny (W wall)
  { tn: 'acc_nr_fix_2', origin: '0 1160 176',     color: '0.15 0.4 1',   bake: '0.85', stops: '6.5' }, // corp neon bar sign
  { tn: 'acc_nr_fix_3', origin: '-660 2400 120',  color: T.lampSodium,   bake: '0.8', stops: '6' },   // corp street lamp
  { tn: 'acc_nr_fix_4', origin: '-1895 2400 120', color: T.lampSodium,   bake: '0.8', stops: '6' },   // Helipad street lamp
  { tn: 'acc_nr_fix_5', origin: '776 3430 160',   color: '0.6 0.2 1',    bake: '0.8', stops: '6.5' }, // Lab holo screen
  { tn: 'acc_nr_fix_6', origin: '0 1210 80',      color: '0.7 0.85 1',   bake: '0.6', stops: '6' },   // corp TV wall glow
  { tn: 'acc_nr_fix_7', origin: '-300 -380 -80',  color: '0 1 1',        bake: '0.7', stops: '6.5' }, // Exchange floating holo (cyan accent in the amber room)
  { tn: 'acc_nr_fix_8', origin: '0 698 150',      color: '0 1 1',        bake: '0.8', stops: '6.5' }, // Plaza white-neon 3d text sign
];

// --- new shadow-casting PRIMARY_SPOT downlights (zm_giant entity-34 shape) ---
// No angles/target key = aims straight down (stock-verified). shadowUpdate
// Never = shadows BAKED by the LED pass, zero runtime cost (Giant ships 353).
const NEW_SPOTS = [
  { tn: 'acc_nr_spot_0',  origin: '-40 130 246',     color: '0 1 1',         note: 'Plaza fountain angel - the maps first silhouette' },
  { tn: 'acc_nr_spot_1',  origin: '-2100 710 246',   color: '1 0.7 1',       note: 'Market crashed taxi' },
  { tn: 'acc_nr_spot_2',  origin: '0 1290 250',      color: '0.75 0.87 1',   note: 'corp holo departure board + queue' },
  { tn: 'acc_nr_spot_3',  origin: '-25 2658 250',    color: '0.6 0.75 1',    note: 'corp sealed schoolbus rim' },
  { tn: 'acc_nr_spot_4',  origin: '1740 2340 246',   color: '0.3 1 0.4',     note: 'Vault BO6 circular door - green rake' },
  { tn: 'acc_nr_spot_5',  origin: '1136 2880 246',   color: '1 0.15 0.15',   note: 'Vault security desk - red alert vignette' },
  { tn: 'acc_nr_spot_6',  origin: '-1524 2845 250',  color: '1 0.6 0.25',    note: 'Helipad crashed bomber - amber rake' },
  { tn: 'acc_nr_spot_7',  origin: '150 3450 246',    color: '0.6 0.2 1',     note: 'Lab teleporter pad' },
  { tn: 'acc_nr_spot_8',  origin: '760 3450 246',    color: '0.8 0.6 1',     note: 'Lab medical/morgue row (pairs with the P0 motes)' },
  { tn: 'acc_nr_spot_9',  origin: '2040 1060 246',   color: '1 0.2 0.2',     note: 'Alley scaffold - red silhouette' },
  { tn: 'acc_nr_spot_10', origin: '-500 1206 246',   color: '1 0.9 0.72',    note: 'corp barricaded ticket office (vault_bank door)' },
];

// --- new below-surface probes (sphere probes, dark-tuned) --------------------
const NEW_PROBES = [
  { name: 'acc_probe_exchange', origin: '-210 -44 -80' },
  { name: 'acc_probe_hub',      origin: '-600 -1000 -1040' },
  { name: 'acc_probe_abyss',    origin: '0 1950 -900' },
  { name: 'acc_probe_paradise', origin: '0 1870 -1140' },
];

// =============================================================================
function main() {
  if (process.argv.includes('--revert')) return revert();

  if (!fs.existsSync(MAP)) die('map not found: ' + MAP);
  const src = fs.readFileSync(MAP, 'utf8');
  if (src.includes(MARKER)) die('marker ' + MARKER + ' already present - one-shot refuses to re-apply. Revert first: --revert');
  if (fs.existsSync(BACKUP)) die('backup already exists (' + BACKUP + ') - a previous apply was not cleaned up. Revert or remove it first.');
  if (src.includes(GUID_PREFIX)) die('guid prefix ' + GUID_PREFIX + ' already appears in the map - pick a new prefix.');

  const nl = src.includes('\r\n') ? '\r\n' : '\n';
  const lines = src.split(nl);

  // ---- pass 1: locate entities (depth-tracked; entity = depth0 block) ------
  const ents = [];
  let depth = 0, start = -1;
  for (let i = 0; i < lines.length; i++) {
    const t = lines[i].trim();
    if (t === '{') { if (depth === 0) start = i; depth++; }
    else if (t === '}') { depth--; if (depth === 0 && start >= 0) { ents.push([start, i]); start = -1; } }
  }
  if (depth !== 0) die('brace scan imbalance (' + depth + ') - refusing to touch the map');

  const kv = (s, e, key) => {
    const re = new RegExp('^"' + key + '" "([^"]*)"$');
    for (let i = s; i <= e; i++) { const m = lines[i].trim().match(re); if (m) return { i, v: m[1] }; }
    return null;
  };
  const setKv = (s, e, key, val) => {
    const f = kv(s, e, key);
    if (!f) die('entity at line ' + s + ' missing expected key ' + key);
    lines[f.i] = lines[f.i].replace(/"([^"]*)"$/, '"' + val + '"');
  };

  // ---- pass 2: light-family edits ------------------------------------------
  const famCount = {}; FAMILIES.forEach(f => famCount[f.name] = 0);
  let lightsSeen = 0, poolMoves = 0, templOmni = null, templProbe = null, bareProbes = 0;
  let worldspawnDone = false;

  for (const [s, e] of ents) {
    const cls = kv(s, e, 'classname');
    if (!cls) continue;

    if (cls.v === 'worldspawn') {
      const lq = kv(s, e, 'lightingquality');
      if (lq && lq.v === '1024') { setKv(s, e, 'lightingquality', '2048'); worldspawnDone = true; }
      continue;
    }

    if (cls.v === 'light') {
      const tn = kv(s, e, 'targetname');
      if (!tn) continue;
      lightsSeen++;
      const fam = FAMILIES.find(f => f.re.test(tn.v));
      if (!fam) die('UNEXPECTED light targetname (not in the 2026-07-29 audit): ' + tn.v);
      famCount[fam.name]++;
      if (fam.color) setKv(s, e, '_color', fam.color);
      if (fam.bake)  setKv(s, e, 'bake_intensity_scale', fam.bake);
      if (fam.stops) setKv(s, e, 'stops', fam.stops);
      if (POOL_MOVES[tn.v]) { setKv(s, e, 'origin', POOL_MOVES[tn.v]); poolMoves++; }
      // template capture: first radius-260 under light = the new-omni donor
      if (!templOmni && /^acc_under_light_/.test(tn.v)) templOmni = lines.slice(s, e + 1);
      continue;
    }

    if (cls.v === 'reflection_probe') {
      const res = kv(s, e, 'resolution');
      if (res) { if (!templProbe) templProbe = lines.slice(s, e + 1); continue; }
      // bare probe -> complete it to match its configured twin (res 8x + AO;
      // brightness/evcomp stay 0 so the overlapping pairs don't seam)
      const cn = kv(s, e, 'classname');
      lines[cn.i] += nl + '"resolution" "8x"' + nl + '"ao_range" "38"' + nl + '"ao_strength_double_sided" "1"' + nl + '"brightnessAdjust" "0"' + nl + '"evcomp" "0"';
      bareProbes++;
      continue;
    }
  }

  // ---- audit assertions BEFORE writing --------------------------------------
  if (lightsSeen !== EXPECT_TOTAL) die('light count ' + lightsSeen + ' != audited ' + EXPECT_TOTAL + ' - map drifted, re-audit before relighting');
  for (const f of FAMILIES) if (famCount[f.name] !== f.expect) die('family ' + f.name + ' count ' + famCount[f.name] + ' != expected ' + f.expect);
  if (poolMoves !== Object.keys(POOL_MOVES).length) die('pool moves applied ' + poolMoves + ' != planned ' + Object.keys(POOL_MOVES).length);
  if (!worldspawnDone) die('worldspawn lightingquality 1024 not found');
  if (!templOmni) die('no under-light template captured');
  if (bareProbes !== 9) die('bare probes completed ' + bareProbes + ' != audited 9');
  // the frozen-radius assertion: we never wrote a radius key anywhere
  // (structurally guaranteed - no code path edits "radius"; this grep is the belt)
  // (checked post-join below)

  // ---- pass 3: append new entities ------------------------------------------
  let seq = 0;
  const guid = () => '{' + GUID_PREFIX + pad(++seq, 3) + '-0000-4E0B-8A3F-' + pad(seq, 12) + '}';
  const out = [];
  out.push('// ' + MARKER + ' noir relight v1 (docs/46 Phase 1) applied 2026-07-29 - one-shot tools/oneshots/noir_relight_v1.js');
  out.push('// revert: node tools/oneshots/noir_relight_v1.js --revert  (restores .acc-nr01-orig)');

  for (const o of NEW_OMNIS) {
    const b = templOmni.map(l => l); // clone the proven omni shape
    const block = editBlock(b, { targetname: o.tn, origin: o.origin, _color: o.color, bake_intensity_scale: o.bake, stops: o.stops }, guid());
    out.push('// ' + o.tn);
    out.push(...block);
  }
  for (const sp of NEW_SPOTS) {
    out.push('// ' + sp.tn + ' - ' + sp.note);
    out.push('{');
    out.push('guid "' + guid() + '"'); // stock format: guid "{HEX-...-HEX}" (braces inside the quotes)
    out.push('"classname" "light"');
    out.push('"targetname" "' + sp.tn + '"');
    out.push('"PRIMARY_NOSHADOWMAP" "0"');
    out.push('"PRIMARY_TYPE" "PRIMARY_SPOT"');
    out.push('"_color" "' + sp.color + '"');
    out.push('"animmode" "loop"');
    out.push('"animscale" "1"');
    out.push('"bulbRadius" "0.01"');
    out.push('"culling_cutoff" "200"');
    out.push('"culling_falloff" "300"');
    out.push('"cut_on" "16"');
    out.push('"dirSpan" "100 100 100"');
    out.push('"exploderFade" "1"');
    out.push('"fov_outer" "55"');
    out.push('"origin" "' + sp.origin + '"');
    out.push('"radius" "320"');
    out.push('"roundness" "1"');
    out.push('"shadowUpdate" "Never"');
    out.push('"stops" "7"');
    out.push('"superellipse" "0.1 1 0.1 1"');
    out.push('"volumetric" "1"');
    out.push('"volumetricSampleCount" "1"');
    out.push('"ENABLE_FALLOFF" "1"');
    out.push('"client_server" "ClientSide"');
    out.push('"def_tile" "1 1"');
    out.push('"excludeDedicated" "Off"');
    out.push('"falloffdistance" "12"');
    out.push('"far_edge" "0.949999988079071"');
    out.push('"lightingstate1" "0"');
    out.push('"lightingstate2" "1"');
    out.push('"lightingstate3" "1"');
    out.push('"lightingstate4" "1"');
    out.push('"name" "light"');
    out.push('"penumbraRadius" "3"');
    out.push('"shadowmapScale" "1"');
    out.push('"spawnflags" "68"');
    out.push('}');
  }
  for (const p of NEW_PROBES) {
    out.push('// ' + p.name + ' - below-surface dark probe (RC8 fix; brightness/evcomp -5 = true dark ambient)');
    out.push('{');
    out.push('guid "' + guid() + '"');
    out.push('"classname" "reflection_probe"');
    out.push('"origin" "' + p.origin + '"');
    out.push('"resolution" "8x"');
    out.push('"ao_range" "38"');
    out.push('"ao_strength_double_sided" "1"');
    out.push('"brightnessAdjust" "-5"');
    out.push('"evcomp" "-5"');
    out.push('"name" "' + p.name + '"');
    out.push('}');
  }

  // ---- verify, then write (backup only after ALL assertions pass) ------------
  const result = lines.join(nl) + nl + out.join(nl) + nl;

  // frozen-radius belt-check: the ONLY radius lines allowed to differ from the
  // backup are APPENDED entities (11 spots at 320 + 9 omni clones carrying the
  // template's 260) - zero EDITS to existing radii.
  const oldRadii = (src.match(/"radius" "[^"]*"/g) || []).length;
  const newRadii = (result.match(/"radius" "[^"]*"/g) || []).length;
  const expectAdd = NEW_SPOTS.length + NEW_OMNIS.length;
  if (newRadii !== oldRadii + expectAdd) die('RADIUS INVARIANT VIOLATED: ' + oldRadii + ' -> ' + newRadii + ' (expected +' + expectAdd + ' appended-only)');
  // and every pre-existing radius VALUE histogram must be identical:
  const hist = t => { const h = {}; (t.match(/"radius" "[^"]*"/g) || []).forEach(r => h[r] = (h[r] || 0) + 1); return h; };
  const ho = hist(src), hn = hist(result);
  for (const k of Object.keys(ho)) {
    let expected = ho[k];
    if (k === '"radius" "320"') expected += NEW_SPOTS.length;
    if (k === '"radius" "260"') expected += NEW_OMNIS.length;
    if ((hn[k] || 0) !== expected) die('RADIUS VALUE DRIFT at ' + k + ': ' + ho[k] + ' -> ' + (hn[k] || 0));
  }

  fs.copyFileSync(MAP, BACKUP);
  fs.writeFileSync(MAP, result);
  console.log('[noir_relight_v1] APPLIED ' + MARKER);
  console.log('  lights edited: ' + lightsSeen + ' (families all match the audit)');
  console.log('  pools re-homed onto fixtures: ' + poolMoves);
  console.log('  bare probes completed: ' + bareProbes);
  console.log('  appended: ' + NEW_OMNIS.length + ' fixture omnis, ' + NEW_SPOTS.length + ' shadow spots, ' + NEW_PROBES.length + ' dark probes');
  console.log('  worldspawn lightingquality 1024 -> 2048');
  console.log('  backup: ' + BACKUP);
  console.log('  NEXT: sync_to_modtools -> _bake_test.ps1 (full LED gate) -> build_map.ps1 -GscOnly');
}

function editBlock(block, kvs, g) {
  // block = cloned entity lines incl. braces; replace guid + given keys
  return block.map(l => {
    const t = l.trim();
    if (t.startsWith('guid ')) return 'guid "' + g + '"';
    for (const k of Object.keys(kvs)) {
      if (t.startsWith('"' + k + '" ')) return '"' + k + '" "' + kvs[k] + '"';
    }
    // strip generator comments riding the template clone
    if (t.startsWith('//')) return null;
    return l;
  }).filter(l => l !== null);
}

function revert() {
  if (!fs.existsSync(BACKUP)) die('no backup at ' + BACKUP + ' - nothing to revert');
  fs.copyFileSync(BACKUP, MAP);
  fs.unlinkSync(BACKUP);
  console.log('[noir_relight_v1] REVERTED - map restored from .acc-nr01-orig (backup consumed)');
  console.log('  NOTE: this restores the whole .map to the pre-apply state; any edits made AFTER the apply are gone (single-writer rule).');
}

function pad(n, w) { return String(n).padStart(w, '0'); }
function die(msg) { console.error('[noir_relight_v1] ABORT: ' + msg); process.exit(1); }

main();
