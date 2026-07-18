#!/usr/bin/env node
// paint_region.js [--dry] [--entities] [in.map] [out.map]
// Per-ZONE art pass: repaint each zone's brushes FROM the global asphalt to its own WALL / FLOOR / CEIL material,
// selected by brush CENTROID inside a region AABB + orientation (vertical = wall; flat-low = floor; flat-high =
// ceil, default = wall). After the global paint every face shares one token, so zones are carved out by bounds.
// Only worldspawn brushes unless --entities (e.g. Lab perk doors). Geometry is unchanged (material token only) so
// it is LED-bake-safe (no brush.cpp:1860) but BSP-baked -> needs a FULL build. Bounds from tools/find_region.js +
// tools/list_zones.js (player_volume footprints). Regions are ORDERED: first match wins, so the peripheral zones
// precede the central CORP (they own the shared border walls; CORP takes the centre). Already-hex regions (Lab/
// Paradise) are inert here (no longer FROM=asphalt). KEEP zone bounds in sync with the geometry generators.
'use strict';
const fs = require('fs');

const FROM = 't7_asphalt_damaged_dark_wet';   // global material every zone repaints FROM

// --- confirmed-shipping stock materials (harvested from Treyarch prefabs / docs/29) ---
const CONCRETE_WEATH = 't7_concrete_wall_weathered_01_wet';        // grimed wet concrete
const CONCRETE_CRACK = 't7_concrete_floor_garage_cracked_wet_nw';  // cracked wet pavement
const CONCRETE_THICK = 't7_concrete_wall_poured_thick_01_wet';     // thick poured concrete
const METAL_GRAPHITE = 't7_metal_bare_graphite_matte';             // sleek dark metal
const MARBLE_DARK    = 't7_stone_marble_dark_01';                  // dark polished tile
const METAL_DIRTY    = 't7_metal_painted_wall_dirty_black';        // dirty black metal (ducting)
const METAL_RUST     = 't7_metal_paint_rust_brown';               // rusted metal
const TILE_WET       = 't7_concrete_tiles_2x2_dirty_01_wet';       // wet dirty tile
const METAL_STEEL    = 't7_metal_panel_2x1_stainless_steel_brushed'; // brushed server panels
const METAL_DIAMOND  = 't7_metal_diamond_plate_worn_wet';          // diamond-plate grating
const METAL_IRON     = 't7_metal_worn_iron_dark';                  // gritty industrial iron

// REGIONS: each repaints wall/floor/ceil (ceil defaults to wall; undefined surface = left as FROM). Peripherals
// first, central CORP + underground TRENCH last. z is surface (-30..300) except TRENCH (the under-level).
const REGIONS = [
  { name:'BRIDGE', x1:-120, x2: 160, y1:1715, y2:2180, z1: 38,  z2: 66, wall:METAL_DIAMOND,  floor:METAL_DIAMOND  }, // corp-trench bridge slab @ z+58 - FIRST so the CORP floor can't grab it as dark marble (it's flat, blended into the trench: user 2026-06-28). Diamond-plate walkway.
  { name:'PLAZA',  x1:-1050,x2:1090, y1:-560, y2: 760, z1:-30,  z2:300, wall:CONCRETE_WEATH, floor:CONCRETE_CRACK }, // dead transit plaza
  { name:'ALLEY',  x1: 815, x2:2255, y1: 355, y2:1565, z1:-30,  z2:300, wall:METAL_DIRTY                          }, // wet utility corridor (floor stays wet asphalt)
  { name:'MARKET', x1:-2165,x2:-785, y1: 355, y2:1565, z1:-30,  z2:300, wall:METAL_RUST,     floor:TILE_WET       }, // drowned neon bazaar
  { name:'ROOF',   x1:-1945,x2:-785, y1:2255, y2:3465, z1:-30,  z2:300, wall:CONCRETE_THICK, floor:CONCRETE_WEATH }, // exposed wet helipad
  { name:'VAULT',  x1: 815, x2:1945, y1:2255, y2:3465, z1:-30,  z2:300, wall:METAL_STEEL,    floor:METAL_DIAMOND  }, // cold data-fortress
  { name:'CORP',   x1:-1100,x2:1100, y1:1140, y2:2755, z1:-30,  z2:300, wall:METAL_GRAPHITE, floor:MARBLE_DARK    }, // fallen megacorp lobby (central; LAST so peripherals win borders)
  { name:'TRENCH', x1:-820, x2: 860, y1:1140, y2:2760, z1:-260, z2:-25, wall:METAL_IRON,     floor:METAL_IRON     }, // gritty industrial under-level (z2=-25 closes the gap to CORP z1=-30 without catching the corp floor @ -8; run with --entities for the trench doors)
];
const isWall = (b) => (b[5]-b[4]) > Math.min(b[1]-b[0], b[3]-b[2]);   // z-extent > thinnest horizontal => vertical
function pick(r, b, cz) { if (isWall(b)) return r.wall; return (cz < (r.z1+r.z2)/2) ? r.floor : (r.ceil || r.wall); }

const DRY = process.argv.includes('--dry');
const ENTITIES = process.argv.includes('--entities');
const args = process.argv.slice(2).filter(a => a !== '--dry' && a !== '--entities');
const MAP = 'map_source/zm/zm_abandoned_cyber_city.map';
const inPath = args[0] || MAP, outPath = args[1] || inPath;

const N = '(-?[\\d.]+)';
const FACE_RE = new RegExp('^\\s*\\(\\s*'+N+'\\s+'+N+'\\s+'+N+'\\s*\\)\\s*\\(\\s*'+N+'\\s+'+N+'\\s+'+N+'\\s*\\)\\s*\\(\\s*'+N+'\\s+'+N+'\\s+'+N+'\\s*\\)\\s+(\\S+)');
function boundsOf(faces){if(faces.length!==6)return null;const A=[[],[],[]];for(const[p1,p2,p3]of faces){const u=[p2[0]-p1[0],p2[1]-p1[1],p2[2]-p1[2]],v=[p3[0]-p1[0],p3[1]-p1[1],p3[2]-p1[2]];const n=[u[1]*v[2]-u[2]*v[1],u[2]*v[0]-u[0]*v[2],u[0]*v[1]-u[1]*v[0]];const ab=n.map(Math.abs),mx=Math.max(...ab);if(mx<1e-6)return null;const ax=ab.indexOf(mx);if(ab[(ax+1)%3]+ab[(ax+2)%3]>mx*1e-4)return null;A[ax].push(p1[ax]);}if(A.some(g=>g.length!==2))return null;return[Math.min(...A[0]),Math.max(...A[0]),Math.min(...A[1]),Math.max(...A[1]),Math.min(...A[2]),Math.max(...A[2])];}
const esc = (s) => s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');

const lines = fs.readFileSync(inPath, 'utf8').split('\n');
let depth = 0, entIdx = -1, brush = null;
const ranges = []; const per = {};
for (let i = 0; i < lines.length; i++) {
  const opens = (lines[i].match(/{/g) || []).length, closes = (lines[i].match(/}/g) || []).length;
  for (let o = 0; o < opens; o++) { if (depth === 0) entIdx++; if (depth === 1 && (ENTITIES || entIdx === 0)) brush = { start: i, faces: [], mat: null }; depth++; }
  const m = lines[i].match(FACE_RE);
  if (m && brush) { brush.faces.push([[+m[1],+m[2],+m[3]],[+m[4],+m[5],+m[6]],[+m[7],+m[8],+m[9]]]); if (!brush.mat) brush.mat = m[10]; }
  for (let c = 0; c < closes; c++) { depth--; if (depth === 1 && (ENTITIES || entIdx === 0) && brush) {
    brush.end = i;
    if (brush.faces.length === 6 && brush.mat === FROM) { const b = boundsOf(brush.faces); if (b) {
      const cx=(b[0]+b[1])/2, cy=(b[2]+b[3])/2, cz=(b[4]+b[5])/2;
      for (const r of REGIONS) if (cx>=r.x1&&cx<=r.x2&&cy>=r.y1&&cy<=r.y2&&cz>=r.z1&&cz<=r.z2) {
        const mat = pick(r, b, cz);
        if (!mat) break;                       // this surface left as FROM in this region
        ranges.push([brush.start, brush.end, mat]); per[r.name]=(per[r.name]||0)+1; break;
      }
    }}
    brush = null;
  }}
}
const sel = new Array(lines.length).fill(null);
for (const [s,e,to] of ranges) for (let i=s;i<=e;i++) sel[i]=to;
const re = new RegExp('\\b'+esc(FROM)+'\\b','g');
let painted = 0;
const out = lines.map((ln,i) => sel[i] ? ln.replace(re, () => { painted++; return sel[i]; }) : ln);

console.log(`[paint_region] per-zone art pass (FROM ${FROM})`);
for (const r of REGIONS) console.log(`  ${r.name.padEnd(8)} ${String(per[r.name]||0).padStart(3)} brushes`);
console.log(`  TOTAL: ${ranges.length} brushes / ${painted} faces` + (DRY ? '  (DRY RUN - nothing written)' : ''));
if (!DRY) { fs.writeFileSync(outPath, out.join('\n')); console.log(`  wrote ${outPath}`); }
