#!/usr/bin/env node
// paint_plaza_walls.js [--revert] [--dry] - PARADISE PLAZA walls -> BO6 brick (user 2026-07-02
// "replace plaza walls for now"; accepts the docs/29 SS14 custom-face-material techset risk -
// the NEXT FULL build's errorlog is the verdict, --revert if it traps).
//
// Repaints the WALL faces of the Paradise plaza room (the open-air arena at z~-1200) from the
// hex tile (t7_zm_der_tile_hexagon, the 2026-06-28 Lab/Paradise reskin) to the BO6 pilot
// material t10_brick_stone_wall_rough_dark (installed 2026-07-02: source_data\acc_bo6_mat_pilot.gdt
// + texture_assets\_bo6\...; PNG baseImages). NO material, zone line - face tokens pull the
// material from gdtDB at cod2map/linker time regardless (the techset compile fires either way;
// an explicit line would only ALSO force the standalone compile path that already failed for
// the sky material).
//
// Selection = worldspawn brushes with centroid inside the plaza AABB *and* wall-shaped
// (z-extent > thinnest horizontal extent - the paint_region.js test), faces currently on the
// hex token only (floors/ceilings + functional tokens untouched).
// Bounds = the paint_region.js Paradise-plaza region (CHANGELOG 2026-06-28).
//
// Idempotent + reversible: first run backs the .map up to .acc-plazawalls-orig; --revert restores.
// Usage: node tools/paint_plaza_walls.js [--dry|--revert]     (then FULL LED-baked build)
'use strict';
const fs = require('fs');

const MAP = 'map_source/zm/zm_abandoned_cyber_city.map';
const BAK = MAP + '.acc-plazawalls-orig';
const FROM = 't7_zm_der_tile_hexagon';
// 2026-07-02 user feedback: the rough-dark brick read right structurally but wanted "darker and
// cyber themey" -> cyan wall tile (matches the map's teal/magenta palette; carved into the same
// pilot GDT). Fallback if too bright in game: t10_metal_aluminum_composite_wall_paneling_01.
const TO = 't10_brick_wall_tile_01_cyan';
const REGION = { x1: -1030, x2: 1030, y1: -2230, y2: -575, z1: -1220, z2: -180 };   // Paradise plaza (paint_region.js)

const REVERT = process.argv.includes('--revert');
const DRY = process.argv.includes('--dry');

if (REVERT) {
  if (!fs.existsSync(BAK)) { console.error('[plaza-walls] no .acc-plazawalls-orig backup. Nothing done.'); process.exit(1); }
  fs.copyFileSync(BAK, MAP);
  fs.unlinkSync(BAK);
  console.log('[plaza-walls] REVERTED.');
  process.exit(0);
}

const N = '(-?[\\d.]+)';
const FACE_RE = new RegExp('^(\\s*\\(\\s*' + N + '\\s+' + N + '\\s+' + N + '\\s*\\)\\s*\\(\\s*' + N + '\\s+' + N + '\\s+' + N + '\\s*\\)\\s*\\(\\s*' + N + '\\s+' + N + '\\s+' + N + '\\s*\\)\\s+)(\\S+)(\\s.*)$');

const src = fs.readFileSync(MAP, 'utf8');
const lines = src.split(/\r?\n/);
const eol = src.includes('\r\n') ? '\r\n' : '\n';

// pass 1: index worldspawn brushes -> line ranges + point stats
let depth = 0, entIdx = -1, brush = null;
const brushes = [];
for (let i = 0; i < lines.length; i++) {
  const opens = (lines[i].match(/{/g) || []).length, closes = (lines[i].match(/}/g) || []).length;
  for (let o = 0; o < opens; o++) { if (depth === 0) entIdx++; if (depth === 1 && entIdx === 0) brush = { start: i, pts: [], faceLines: [] }; depth++; }
  if (brush) {
    const m = lines[i].match(FACE_RE);
    if (m) {
      brush.pts.push([+m[2], +m[3], +m[4]], [+m[5], +m[6], +m[7]], [+m[8], +m[9], +m[10]]);
      brush.faceLines.push(i);
    }
  }
  for (let c = 0; c < closes; c++) { depth--; if (depth === 1 && brush) { brush.end = i; brushes.push(brush); brush = null; } }
}

let painted = 0, brushHit = 0;
for (const b of brushes) {
  if (!b.pts.length) continue;
  const xs = b.pts.map(p => p[0]), ys = b.pts.map(p => p[1]), zs = b.pts.map(p => p[2]);
  const bb = [Math.min(...xs), Math.max(...xs), Math.min(...ys), Math.max(...ys), Math.min(...zs), Math.max(...zs)];
  const cx = (bb[0] + bb[1]) / 2, cy = (bb[2] + bb[3]) / 2, cz = (bb[4] + bb[5]) / 2;
  if (cx < REGION.x1 || cx > REGION.x2 || cy < REGION.y1 || cy > REGION.y2 || cz < REGION.z1 || cz > REGION.z2) continue;
  const isWall = (bb[5] - bb[4]) > Math.min(bb[1] - bb[0], bb[3] - bb[2]);
  if (!isWall) continue;
  let hit = false;
  for (const li of b.faceLines) {
    const m = lines[li].match(FACE_RE);
    if (!m || m[11] !== FROM) continue;
    lines[li] = m[1] + TO + m[12];
    painted++; hit = true;
  }
  if (hit) brushHit++;
}

console.log(`[plaza-walls] ${DRY ? 'DRY: would repaint' : 'repainted'} ${painted} face(s) across ${brushHit} wall brush(es)  (${FROM} -> ${TO})`);
if (!DRY && painted) {
  if (!fs.existsSync(BAK)) fs.writeFileSync(BAK, src);
  fs.writeFileSync(MAP, lines.join(eol));
  console.log('[plaza-walls] map written; backup at ' + BAK + '. FULL LED-baked build next; --revert if the techset trap fires.');
}
