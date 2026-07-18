#!/usr/bin/env node
// =============================================================================
// apply_room_shrink.js - shrink one or more ACC zone rooms in the .map,
// deterministically, from a per-room old->new footprint. docs/36 Stage 2+.
//
// WHY: market (Stage 1) was hand-edited and playtested-good. Scaling that to all
// 7 rooms by hand = ~120 edits with mirror-room plane collisions. This tool does
// the same transformation by GUID/geometry, so it can't fat-finger a placeholder.
//
// WHAT IT DOES, per room, scoped to brushes/entities inside the OLD footprint:
//   - FLOOR (script_floor_ceiling z[-16,0]) + PERIMETER WALLS (script_wall z[0,256]):
//       value-remap each plane's constant-axis bound: old room edge (outer ox,
//       inner ox+/-T) -> matching new edge. Gap coords (mid-wall) are NOT edges,
//       so they stay -> corridor mouths keep their fixed Y/X. FIXED walls (new
//       edge == old edge) remap to themselves = no-op. (This is exactly the market
//       hand-edit, generalized.)
//   - info_volume room-box brush (the zone's player_volume brush matching the old
//       footprint): same value-remap. Corridor-half volume brushes (extend past the
//       wall) are left alone.
//   - INTERIOR OBSTACLES (script_wall z-top<256), TRIGGER volumes, and POINT
//       entities (risers/dog/box/perks/power/probe/...): proportional move so they
//       keep their relative position in the room, then clamped >= margin off the new
//       inner walls so nothing ends up buried or floating outside.
//   - gen_rooms double-shell brushes (guids in `deleteGuids`): removed (vault/roof).
//   All edits are SURGICAL (only coordinate numbers in plane/origin lines change),
//   so per-brush UV, winding, GUIDs, and materials are preserved.
//
// Corridors + door slabs/triggers sit OUTSIDE every room footprint -> never touched.
//
// Usage:
//   node tools/apply_room_shrink.js                 # apply ROOMS config to the .map
//   node tools/apply_room_shrink.js --dry           # report only, no write
//   node tools/apply_room_shrink.js --verify-market <backup.map>
//                                                   # regression: run market old->new
//                                                   # on the backup, diff floor/wall
//                                                   # geometry vs the live .map
// =============================================================================

'use strict';
const fs = require('fs');
const path = require('path');

const MAP = path.join(__dirname, '..', 'map_source', 'zm', 'zm_abandoned_cyber_city.map');
const T = 20;            // perimeter wall thickness
const WALL_Z = 256;      // full-height wall top
const FLOOR_Z0 = -16, FLOOR_Z1 = 0;
const EPS = 0.25;
const SPAWN_MARGIN = 80; // riser/dog clearance from new inner walls
const BOX_MARGIN = 96;   // free-standing box clearance
const ENT_MARGIN = 40;   // everything else (wall-mounted machines etc.)

// ---- ROOM CONFIG: old + new OUTER footprints (floor-slab extents) -----------
// `old` MUST equal the CURRENT baked .map footprint; `new` is the target. new==old
// for an axis = that wall is FIXED (carries a corridor gap) or held this pass.
// STAGE 3 (2026-06-15): a further ~25% squeeze on the 4 free-wall rooms (market/alley
// shrink in X; vault/roof shrink in X — Y is gap-locked). start/lab/corp held (start
// is spawn/gap-constrained, gets obstacles via ADD instead; lab/corp pending). The
// gen_rooms shells were already deleted in Stage 2, so no deleteGuids here.
const ROOMS = {
  market_zone: { old: { x1: -2161, x2: -1281, y1: 360, y2: 1496 }, new: { x1: -1951, x2: -1281, y1: 360, y2: 1496 } },
  alley_zone:  { old: { x1: 1319.5, x2: 2199.5, y1: 360, y2: 1496 }, new: { x1: 1319.5, x2: 1989.5, y1: 360, y2: 1496 } },
  vault_zone:  { old: { x1: 1119, x2: 1939, y1: 2260, y2: 3400 }, new: { x1: 1119, x2: 1744, y1: 2260, y2: 3400 } },
  roof_zone:   { old: { x1: -1939, x2: -1119, y1: 2260, y2: 3400 }, new: { x1: -1744, x2: -1119, y1: 2260, y2: 3400 } },
  start_zone:  { old: { x1: -1056, x2: 1094.5, y1: -560, y2: 740 }, new: { x1: -1056, x2: 1094.5, y1: -560, y2: 740 } },
  lab_zone:    { old: { x1: -781, x2: 819, y1: 3048, y2: 4248 }, new: { x1: -781, x2: 819, y1: 3048, y2: 4248 } },
  corp_zone:   { old: { x1: -781, x2: 819, y1: 1148, y2: 2748 }, new: { x1: -781, x2: 819, y1: 1148, y2: 2748 } },
};

// ---- ADDED GEOMETRY (new brushes appended to worldspawn) --------------------
// Idempotent: skipped entirely if any "{ACCADD" guid already exists in the .map.
// box = [x1,x2,y1,y2,z1,z2]. Emitted with the proven gen_zone_greybox winding.
//   Ceilings cap the two open-top LAB-APPROACH corridors into enclosed tunnels
//   (raise the risk/cost of reaching PaP/perks). Maze = staggered chicane cover in
//   those tunnels, threaded around the door slabs (X961-977 / X-958..-942) and the
//   PaP blockers (X1040-1056 / X-1056..-1040), leaving >=96u lanes. Start obstacles
//   break the open spawn arena (reduce its "free training" pull) — placed clear of
//   every start spawner (risers 348.5/-803.5 @y243, -227.5@y493, dog -227.5@y119).
// LED-CRASH GOTCHA (verified 2026-06-15): a brush face sitting EXACTLY coplanar
// with another brush's parallel face (back-to-back, same plane, overlapping 2D
// extent) crashes radiant's LED lightmapper (exit 0x80000003, no output). cod2map
// is fine; only the relight dies. So added cover must NOT be flush against a wall
// face: ceilings sit 8u ABOVE the z256 wall tops (z264, also clears the door's
// open-top at z258), and maze blocks sit 8u OFF the corridor side walls. (Bottom-
// on-floor at z0 is fine — proven by the Stage-1/2 stalls.)
// NOTE (2026-06-15): the lab-corridor ceilings (C*) + maze (M*) are DISABLED — they
// crash radiant's LED lightmapper. cod2map/navmesh build fine, but the relight dies
// (exit 0x80000003 / -1, no .led written) on cover + enclosure inside the narrow 216u
// lab corridors — both flush-coplanar AND 8u-off-wall variants fail (thin slivers /
// unlit enclosed volume). Stage-2 geo + the shrink + start cover all LED-relight clean.
// LAB-APPROACH DIFFICULTY IS DEFERRED to a dedicated LED-safe pass: enclosed tunnels
// need an in-corridor `light` entity (no sky light reaches them), and corridor cover
// must leave wide (no-sliver) lanes — or be authored in Radiant where the GUI relight
// handles it. Coords kept here for that follow-up.
const ADD = [
  // { id: 'C0', box: [819, 1119, 3100, 3356, 264, 280], mat: 'script_floor_ceiling' }, // lab_e ceiling — needs in-tunnel light
  // { id: 'C1', box: [-1119, -781, 3100, 3356, 264, 280], mat: 'script_floor_ceiling' }, // lab_w ceiling
  // { id: 'M0', box: [860, 910, 3128, 3230, 0, 160], mat: 'script_wall' },  // lab_e maze S — sliver-vs-wall crashes LED
  // { id: 'M1', box: [995, 1035, 3226, 3328, 0, 160], mat: 'script_wall' }, // lab_e maze N
  // { id: 'M2', box: [-910, -860, 3128, 3230, 0, 160], mat: 'script_wall' },// lab_w maze S
  // { id: 'M3', box: [-1030, -990, 3226, 3328, 0, 160], mat: 'script_wall' },// lab_w maze N
  // 2026-06-16: start cover S0/S1 REMOVED — user wants flat rooms, no free-standing
  // blocking structures (box/PaP/perks/walls/doors stay). Do NOT re-enable.
  // { id: 'S0', label: 'start cover W', box: [-680, -510, -80, 80, 0, 128], mat: 'script_wall' },
  // { id: 'S1', label: 'start cover E', box: [480, 650, 60, 220, 0, 128], mat: 'script_wall' },
];
function addBrush(b, mat, guid) {
  const t = `${mat} 128 128 0 0 0 0 lightmap_gray 16384 16384 0 0 0 0`;
  const [x1, x2, y1, y2, z1, z2] = b;
  return [
    '{', ` guid "${guid}"`,
    ` ( 134.5 459.5 ${z1} ) ( 86.5 459.5 ${z1} ) ( 86.5 419.5 ${z1} ) ${t}`,
    ` ( 94.5 419.5 ${z2} ) ( 94.5 459.5 ${z2} ) ( 142.5 459.5 ${z2} ) ${t}`,
    ` ( 86.5 ${y1} 88 ) ( 134.5 ${y1} 88 ) ( 134.5 ${y1} 0 ) ${t}`,
    ` ( ${x2} 415.5 88 ) ( ${x2} 455.5 88 ) ( ${x2} 455.5 0 ) ${t}`,
    ` ( 138.5 ${y2} 88 ) ( 90.5 ${y2} 88 ) ( 90.5 ${y2} 0 ) ${t}`,
    ` ( ${x1} 459.5 88 ) ( ${x1} 419.5 88 ) ( ${x1} 419.5 0 ) ${t}`,
    '}',
  ].join('\n');
}

// =============================================================================
// .map parse helpers
// =============================================================================
function splitPoints(planeLine) {
  // returns { pts: [[x,y,z],...], suffix: "<material> <uv...>" } or null
  const m = planeLine.match(/^(\s*)\(\s*([^)]+?)\s*\)\s*\(\s*([^)]+?)\s*\)\s*\(\s*([^)]+?)\s*\)\s+(.*)$/);
  if (!m) return null;
  const pts = [m[2], m[3], m[4]].map(s => s.trim().split(/\s+/).map(Number));
  if (pts.some(p => p.length < 3 || p.some(Number.isNaN))) return null;
  return { indent: m[1], pts, suffix: m[5] };
}
function fmtPlane(indent, pts, suffix) {
  const g = n => (Number.isInteger(n) ? String(n) : String(n));
  return `${indent}( ${g(pts[0][0])} ${g(pts[0][1])} ${g(pts[0][2])} ) ( ${g(pts[1][0])} ${g(pts[1][1])} ${g(pts[1][2])} ) ( ${g(pts[2][0])} ${g(pts[2][1])} ${g(pts[2][2])} ) ${suffix}`;
}
function planeConstAxis(pts) {
  for (const ax of [0, 1, 2]) {
    if (Math.abs(pts[0][ax] - pts[1][ax]) < 1e-6 && Math.abs(pts[1][ax] - pts[2][ax]) < 1e-6) return ax;
  }
  return -1;
}
// Parse the whole file into entities[] with their brushes (line ranges).
function parseEntities(lines) {
  const ents = [];
  let depth = 0, cur = null, brush = null;
  for (let i = 0; i < lines.length; i++) {
    const t = lines[i].trim();
    if (t === '{') {
      depth++;
      if (depth === 1) cur = { open: i, kv: {}, originLine: -1, brushes: [] };
      else if (depth === 2 && cur) brush = { open: i, planeLines: [] };
      continue;
    }
    if (t === '}') {
      if (depth === 2 && cur && brush) { brush.close = i; cur.brushes.push(brush); brush = null; }
      else if (depth === 1 && cur) { cur.close = i; ents.push(cur); cur = null; }
      depth--;
      continue;
    }
    if (depth === 1 && cur) {
      const kv = t.match(/^"([^"]+)" "([^"]*)"$/);
      if (kv) { cur.kv[kv[1]] = kv[2]; if (kv[1] === 'origin') cur.originLine = i; }
    } else if (depth === 2 && brush && t.startsWith('(')) {
      brush.planeLines.push(i);
    }
  }
  return ents;
}
function brushAABB(lines, brush) {
  const xs = [], ys = [], zs = [];
  let material = '';
  for (const li of brush.planeLines) {
    const p = splitPoints(lines[li]);
    if (!p) continue;
    if (!material) material = p.suffix.split(/\s+/)[0];
    const ax = planeConstAxis(p.pts);
    if (ax === 0) xs.push(p.pts[0][0]);
    else if (ax === 1) ys.push(p.pts[0][1]);
    else if (ax === 2) zs.push(p.pts[0][2]);
  }
  if (!xs.length || !ys.length || !zs.length) return null;
  return { x1: Math.min(...xs), x2: Math.max(...xs), y1: Math.min(...ys), y2: Math.max(...ys),
           z1: Math.min(...zs), z2: Math.max(...zs), material };
}
const within = (aabb, f) => aabb && aabb.x1 >= f.x1 - T - 1 && aabb.x2 <= f.x2 + T + 1 &&
                            aabb.y1 >= f.y1 - T - 1 && aabb.y2 <= f.y2 + T + 1;
// A brush is FLOOR/PERIMETER-WALL (value-remap) iff one of its X bounds sits on an
// X room-edge or one of its Y bounds sits on a Y room-edge. Interior obstacles/walls
// (start's template cover) touch no edge -> proportional translate instead.
function touchesEdge(aabb, f) {
  const xE = [f.x1, f.x1 + T, f.x2, f.x2 - T], yE = [f.y1, f.y1 + T, f.y2, f.y2 - T];
  const nx = v => xE.some(e => Math.abs(v - e) < EPS), ny = v => yE.some(e => Math.abs(v - e) < EPS);
  return nx(aabb.x1) || nx(aabb.x2) || ny(aabb.y1) || ny(aabb.y2);
}
const centerInside = (aabb, f) => { const cx = (aabb.x1 + aabb.x2) / 2, cy = (aabb.y1 + aabb.y2) / 2;
  return cx > f.x1 && cx < f.x2 && cy > f.y1 && cy < f.y2; };

// value remap for one axis: maps old outer/inner edges -> new outer/inner edges
function makeAxisRemap(o1, o2, n1, n2) {
  const pairs = [[o1, n1], [o1 + T, n1 + T], [o2, n2], [o2 - T, n2 - T]];
  return v => { for (const [ov, nv] of pairs) if (Math.abs(v - ov) < EPS) return nv; return v; };
}
// proportional position in old footprint -> new footprint, clamped >= margin from inner walls
function propClamp(v, o1, o2, n1, n2, margin) {
  const f = (o2 - o1) === 0 ? 0.5 : (v - o1) / (o2 - o1);
  let nv = n1 + f * (n2 - n1);
  const lo = n1 + T + margin, hi = n2 - T - margin;
  if (lo <= hi) nv = Math.min(Math.max(nv, lo), hi);
  return Math.round(nv * 100) / 100;
}

// =============================================================================
// transform
// =============================================================================
function shrink(lines, opts) {
  const dropLines = new Set();   // line indices to delete (shell brushes)
  let stats = { rooms: 0, floorWall: 0, obstacle: 0, volume: 0, ents: 0, deleted: 0, skipped: 0 };

  const ents = parseEntities(lines);
  const worldspawn = ents[0];

  for (const [zone, cfg] of Object.entries(opts.rooms)) {
    const { old: o, new: n } = cfg;
    if (o.x1 === n.x1 && o.x2 === n.x2 && o.y1 === n.y1 && o.y2 === n.y2 && !cfg.deleteGuids) continue;
    stats.rooms++;
    const rx = makeAxisRemap(o.x1, o.x2, n.x1, n.x2);
    const ry = makeAxisRemap(o.y1, o.y2, n.y1, n.y2);

    // --- delete gen_rooms shell brushes (vault/roof) ---
    // match the FULL guid prefix ("{ACCB0010-), NOT a loose substring: the shell
    // suffixes (e.g. ACCB0021/0022) also appear mid-guid on unrelated start-room
    // walls (7A2B9C08-...-1F00ACCB0021) and must NOT be deleted.
    const isShell = (gl) => cfg.deleteGuids && cfg.deleteGuids.some(g => gl.includes('"{' + g + '-'));
    if (cfg.deleteGuids) {
      for (const b of worldspawn.brushes) {
        const gl = lines[b.open + 1] || '';
        if (isShell(gl)) {
          // drop the brush block + a leading "// ACC room shell" / "// brush" comment line
          let from = b.open;
          if ((lines[from - 1] || '').trim().startsWith('//')) from--;
          if ((lines[from - 1] || '').trim().startsWith('// ACC room shell')) from--;
          for (let i = from; i <= b.close; i++) dropLines.add(i);
          stats.deleted++;
        }
      }
    }

    // --- worldspawn brushes: floor/wall value-remap, obstacle translate ---
    for (const b of worldspawn.brushes) {
      const gl = lines[b.open + 1] || '';
      if (isShell(gl)) continue; // being deleted
      const aabb = brushAABB(lines, b);
      if (!within(aabb, o)) continue;
      // Skip non-axis-aligned / unparseable brushes (start's angled template cover):
      // a degenerate AABB means we can't safely remap or center it -> leave it as-is
      // (it stays inside the shrunk room). Real walls/floor are always 20u+ thick.
      if (aabb.x2 - aabb.x1 < EPS || aabb.y2 - aabb.y1 < EPS) { stats.skipped++; continue; }
      if (touchesEdge(aabb, o)) {
        remapBrush(lines, b, rx, ry);
        stats.floorWall++;
      } else {
        // interior obstacle -> proportional translate (keep size)
        const cx = (aabb.x1 + aabb.x2) / 2, cy = (aabb.y1 + aabb.y2) / 2;
        const dx = propClamp(cx, o.x1, o.x2, n.x1, n.x2, ENT_MARGIN + (aabb.x2 - aabb.x1) / 2) - cx;
        const dy = propClamp(cy, o.y1, o.y2, n.y1, n.y2, ENT_MARGIN + (aabb.y2 - aabb.y1) / 2) - cy;
        if (Math.abs(dx) > EPS || Math.abs(dy) > EPS) { translateBrush(lines, b, dx, dy); stats.obstacle++; }
      }
    }

    // --- other entities ---
    for (let e = 1; e < ents.length; e++) {
      const ent = ents[e];
      // point entity with origin inside the room
      if (ent.originLine >= 0 && ent.kv.origin) {
        const [ox, oy, oz] = ent.kv.origin.split(/\s+/).map(Number);
        if (ox > o.x1 && ox < o.x2 && oy > o.y1 && oy < o.y2) {
          const cls = (ent.kv.classname || '');
          const margin = cls.includes('MagicBox') ? BOX_MARGIN
            : (ent.kv.script_noteworthy === 'riser_location' || ent.kv.script_noteworthy === 'dog_location') ? SPAWN_MARGIN
            : ENT_MARGIN;
          const nx = propClamp(ox, o.x1, o.x2, n.x1, n.x2, margin);
          const ny = propClamp(oy, o.y1, o.y2, n.y1, n.y2, margin);
          lines[ent.originLine] = lines[ent.originLine].replace(/"origin" "[^"]*"/, `"origin" "${nx} ${ny} ${oz}"`);
          stats.ents++;
        }
        continue;
      }
      // brush-entity (info_volume / trigger volumes) with brushes inside the room
      if (ent.brushes.length) {
        for (const b of ent.brushes) {
          const aabb = brushAABB(lines, b);
          if (!aabb) continue;
          const isRoomBox = ent.kv.classname === 'info_volume' &&
            Math.abs(aabb.x1 - o.x1) < EPS && Math.abs(aabb.x2 - o.x2) < EPS &&
            Math.abs(aabb.y1 - o.y1) < EPS && Math.abs(aabb.y2 - o.y2) < EPS;
          if (isRoomBox) { remapBrush(lines, b, rx, ry); stats.volume++; continue; }
          // trigger volume fully inside -> proportional translate
          if (within(aabb, o) && centerInside(aabb, o)) {
            const cx = (aabb.x1 + aabb.x2) / 2, cy = (aabb.y1 + aabb.y2) / 2;
            const dx = propClamp(cx, o.x1, o.x2, n.x1, n.x2, ENT_MARGIN + (aabb.x2 - aabb.x1) / 2) - cx;
            const dy = propClamp(cy, o.y1, o.y2, n.y1, n.y2, ENT_MARGIN + (aabb.y2 - aabb.y1) / 2) - cy;
            if (Math.abs(dx) > EPS || Math.abs(dy) > EPS) { translateBrush(lines, b, dx, dy); stats.obstacle++; }
          }
        }
      }
    }
  }

  const out = lines.filter((_, i) => !dropLines.has(i));
  return { lines: out, stats };
}

function remapBrush(lines, brush, rx, ry) {
  for (const li of brush.planeLines) {
    const p = splitPoints(lines[li]);
    if (!p) continue;
    const ax = planeConstAxis(p.pts);
    if (ax === 0) { const nv = rx(p.pts[0][0]); if (nv !== p.pts[0][0]) { p.pts.forEach(pt => pt[0] = nv); lines[li] = fmtPlane(p.indent, p.pts, p.suffix); } }
    else if (ax === 1) { const nv = ry(p.pts[0][1]); if (nv !== p.pts[0][1]) { p.pts.forEach(pt => pt[1] = nv); lines[li] = fmtPlane(p.indent, p.pts, p.suffix); } }
    // z planes never change
  }
}
function translateBrush(lines, brush, dx, dy) {
  for (const li of brush.planeLines) {
    const p = splitPoints(lines[li]);
    if (!p) continue;
    p.pts.forEach(pt => { pt[0] = Math.round((pt[0] + dx) * 100) / 100; pt[1] = Math.round((pt[1] + dy) * 100) / 100; });
    lines[li] = fmtPlane(p.indent, p.pts, p.suffix);
  }
}

// =============================================================================
// main
// =============================================================================
const args = process.argv.slice(2);
if (args[0] === '--verify-market') {
  const backup = args[1];
  if (!backup || !fs.existsSync(backup)) { console.error('need a backup .map path'); process.exit(1); }
  const bl = fs.readFileSync(backup, 'utf8').split(/\r?\n/);
  const { lines: shrunk } = shrink(bl, { rooms: { market_zone: { old: { x1: -2481, x2: -1281, y1: 200, y2: 1600 }, new: { x1: -2161, x2: -1281, y1: 360, y2: 1496 } } } });
  const live = fs.readFileSync(MAP, 'utf8').split(/\r?\n/);
  // compare the 7 market floor/wall brushes (guids ...0101..0107) geometry
  const guids = ['000000000101', '000000000102', '000000000103', '000000000104', '000000000105', '000000000106', '000000000107', '000000000151'];
  const grab = (arr) => {
    const ents = parseEntities(arr); const out = {};
    for (const ent of ents) for (const b of ent.brushes) {
      const gl = arr[b.open + 1] || '';
      for (const g of guids) if (gl.includes(g)) out[g] = JSON.stringify(brushAABB(arr, b));
    }
    return out;
  };
  const a = grab(shrunk), b = grab(live);
  let bad = 0;
  for (const g of guids) { if (a[g] !== b[g]) { bad++; console.log(`MISMATCH ${g}:\n  tool=${a[g]}\n  live=${b[g]}`); } else console.log(`ok ${g} ${a[g]}`); }
  console.log(bad ? `FAIL: ${bad} market brush mismatches` : 'PASS: tool reproduces the hand-edited market geometry exactly');
  process.exit(bad ? 1 : 0);
}

// append ADD brushes to worldspawn (idempotent: skip if any {ACCADD guid present)
function applyAdd(lines) {
  if (lines.some(l => l.includes('{ACCADD'))) return { lines, added: 0 };
  const e1 = lines.indexOf('// entity 1');
  if (e1 < 1 || lines[e1 - 1].trim() !== '}') { console.error('FATAL: cannot locate worldspawn close before // entity 1'); process.exit(1); }
  const block = ['// ACC added geometry (apply_room_shrink ADD): lab-approach ceilings + maze chicane + start cover'];
  for (const a of ADD) block.push(addBrush(a.box, a.mat, `{ACCADD${a.id}-0000-4E0C-8A3F-000000000ADD}`));
  return { lines: lines.slice(0, e1 - 1).concat(block, lines.slice(e1 - 1)), added: ADD.length };
}

const dry = args.includes('--dry');
const src = fs.readFileSync(MAP, 'utf8');
const lines = src.split(/\r?\n/);
const { lines: shrunk, stats } = shrink(lines, { rooms: ROOMS });
const { lines: out, added } = applyAdd(shrunk);
console.log(`rooms touched=${stats.rooms} floor/wall=${stats.floorWall} volume=${stats.volume} obstacle/trigger=${stats.obstacle} entities=${stats.ents} shellBrushesDeleted=${stats.deleted} skippedAngled=${stats.skipped} addedBrushes=${added}`);
if (dry) { console.log('--dry: no write'); process.exit(0); }
fs.writeFileSync(MAP, out.join('\n'));
console.log('wrote ' + MAP);
