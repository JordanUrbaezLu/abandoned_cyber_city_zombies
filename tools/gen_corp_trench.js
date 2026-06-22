#!/usr/bin/env node
// =============================================================================
// gen_corp_trench.js - one-shot generator for the BUS STATION (corp_zone)
// cross-room trench. Emits .map brush fragments to stdout; paste them into
// map_source/zm/zm_abandoned_cyber_city.map by hand/Edit. The .map stays the
// authoritative source - this is a scaffolding/reference tool, NOT a build step.
// Re-running it does NOT touch the .map. (Mirrors tools/gen_zone_greybox.js.)
//
// FEATURE (user request 2026-06-16): a horizontal (east-west) trench cutting
// dead-centre across the Bus Station. To get from the south half to the north
// half you must drop into the trench and climb the far side. A very thin
// (96u-wide) stair walkway crosses the trench so you CAN walk down and back up;
// or just jump in (the preferred, faster route) - jumping in costs a small
// scripted fall tax (~25, PhD-negated) handled by _acc_bus_trench.gsc.
//
// Geometry (verified vs source_data/rooms.json corp outer x[-781,819]
// y[1148,2748], floor z[-16,0]; docs/36 units: +X east, +Y north, +Z up):
//   trench band   y[TRENCH_Y1,TRENCH_Y2] = [1723,2173]  (450u gap; > a sprint
//                 jump so you cannot leap across the top - you must go down)
//   trench floor  top z=TRENCH_FLOOR (-288), 16u slab -> bottom z=SLAB_BOT(-304)
//   ground slabs  south + north halves THICKENED to z[SLAB_BOT,0] so their
//                 inner faces at y=1723 / y=2173 form the trench retaining
//                 walls automatically (no separate wall brushes, no under-floor
//                 leak). The rest of the room floor is untouched (still z[-16,0]).
//   end walls     the perimeter E/W walls only span z[0,256]; the trench drops
//                 below that, so two script_wall brushes seal the trench's east +
//                 west ENDS (x[X1,X1+20] / x[X2-20,X2], z[FLOOR,0]) - else a
//                 player/zombie walks off the open end (off the map).
//   walkways      ONE staircase per side, HUGGING the E/W side walls (user
//                 2026-06-16) so they don't eat the open trench floor: a 96u stair
//                 on the WEST wall (SOUTH lip) + one on the EAST wall (NORTH lip),
//                 joined by the flat central floor. You cross by going DOWN one wall
//                 and UP the other (diagonal: SW down -> open pit -> NE up). Each:
//                 17 steps (16 tall / 16 deep), treads -16..-272, floor -288 (clean
//                 288 = 18*16, lowest step a full 16u). 16/16 = stock stair pitch -> the
//                 navmesh links across it. The vertical trench walls block any
//                 OTHER crossing, so you still must use a stair (or jump in).
//
// This REPLACES the single corp floor brush (the z[-16,0] slab spanning the
// whole room). See source_data/rooms.json "trenches" + tools/validate_rooms.js
// for the SoT record / cross-check.
// =============================================================================

'use strict';

// --- corp_zone footprint (SoT: source_data/rooms.json rooms.corp_zone.outer) -
const X1 = -781, X2 = 819;          // room east-west extent (full width)
const ROOM_Y1 = 1148, ROOM_Y2 = 2748;
const WALL_TH = 20;                 // perimeter wall thickness (matches gen_zone_greybox)

// --- trench dimensions (1.2x, then 1.3x, then floor lowered another 1.2x; user 2026-06-16)
const TRENCH_Y1 = 1723, TRENCH_Y2 = 2173;   // 450u gap, centred on y=1948 (width unchanged this pass)
const TRENCH_FLOOR = -240;                   // walkable trench-floor top (user 2026-06-18: deep pit, -240). The old -288 wasn't lethal because of depth/fall - it was the stock OUT-OF-PLAYABLE-AREA kill (corp_zone player_volume only spans z[-16,400], so a player below it is "out of the map" and hard-killed). That's now VETOED for trench players in _acc_bus_trench::init (player_out_of_playable_area_monitor_callback), so depth is free. -240 (still < 256 native-falldmg, and we disable native fall dmg anyway).
const SLAB_BOT = -256;                        // bottom of every corp floor slab (16u under the floor)
const FLOOR_TOP = 0;

// --- thin stair walkways crossing the trench ---------------------------------
// ONE stair per side, HUGGING the E/W side walls (user 2026-06-16) so they don't
// eat the open trench floor: the WEST-wall stair serves the SOUTH lip (down/up
// the south), the EAST-wall stair serves the NORTH lip. They share the one flat
// trench floor, so you cross by going DOWN one wall and UP the other (a diagonal:
// SW down -> across the open pit -> NE up). Each channel sits just inside its end
// wall (west end wall x[-781,-761] -> stair x[-761,-665]; east end wall x[799,819]
// -> stair x[703,799]). `side` = which lip it descends from. Keep in sync with
// source_data/rooms.json "trenches".corp.stairChannels.
const STAIR_CHANNELS = [
  { x1: -761, x2: -665, side: 'south', name: 'W', wall: 'west' },   // against the WEST wall, SOUTH lip
  { x1: 703, x2: 799, side: 'north', name: 'E', wall: 'east' },     // against the EAST wall, NORTH lip
];
const GUARD_TH = 16;                         // guard-rail thickness (sealed open side of each stair)
const STEP = 16;                             // 16 tall / 16 deep (stock pitch)
const N_STEPS = 14;                           // 14 * 16 = 224u run; treads -16..-224, then a clean 16u
                                             // step down to the -240 floor. (NOT 15: 15*16=240=floor -> a
                                             // ZERO-height bottom step = degenerate brush. 14 is the max.)

let guidCounter = 0x300;
function guid() {
  guidCounter++;
  const c = guidCounter.toString(16).toUpperCase().padStart(12, '0');
  return `{7A2B9F00-ACC3-4E0C-8A3F-${c}}`;
}

// Six-plane axis-aligned box. Only x1/x2/y1/y2/z1/z2 matter; the other point
// coords are fixed template noise (proven parse-clean - identical pattern to
// tools/gen_zone_greybox.js box(), which produced the shipped corp floor).
function box(x1, x2, y1, y2, z1, z2, tex) {
  const t = `${tex} 128 128 0 0 0 0 lightmap_gray 16384 16384 0 0 0 0`;
  return [
    '{',
    ` guid "${guid()}"`,
    ` ( 134.5 459.5 ${z1} ) ( 86.5 459.5 ${z1} ) ( 86.5 419.5 ${z1} ) ${t}`,
    ` ( 94.5 419.5 ${z2} ) ( 94.5 459.5 ${z2} ) ( 142.5 459.5 ${z2} ) ${t}`,
    ` ( 86.5 ${y1} 88 ) ( 134.5 ${y1} 88 ) ( 134.5 ${y1} 0 ) ${t}`,
    ` ( ${x2} 415.5 88 ) ( ${x2} 455.5 88 ) ( ${x2} 455.5 0 ) ${t}`,
    ` ( 138.5 ${y2} 88 ) ( 90.5 ${y2} 88 ) ( 90.5 ${y2} 0 ) ${t}`,
    ` ( ${x1} 459.5 88 ) ( ${x1} 419.5 88 ) ( ${x1} 419.5 0 ) ${t}`,
    '}',
  ].join('\n');
}

const out = [];
const manifest = [];
function emit(label, text) {
  manifest.push(label);
  out.push(`// ${label}`);
  out.push(text);
}

// --- ground slabs (thick -> inner faces are the trench retaining walls) -------
emit('corp south ground slab (replaces corp floor)',
  box(X1, X2, ROOM_Y1, TRENCH_Y1, SLAB_BOT, FLOOR_TOP, 'script_floor_ceiling'));
emit('corp north ground slab',
  box(X1, X2, TRENCH_Y2, ROOM_Y2, SLAB_BOT, FLOOR_TOP, 'script_floor_ceiling'));

// --- trench floor ------------------------------------------------------------
emit('corp trench floor',
  box(X1, X2, TRENCH_Y1, TRENCH_Y2, SLAB_BOT, TRENCH_FLOOR, 'script_floor_ceiling'));

// --- trench END walls (E/W) --------------------------------------------------
// The room's perimeter E/W walls only span z[0,256]; the trench drops the floor
// far below that, so without these the trench's east/west ENDS are open under the
// wall and a player (or zombie) can walk off the edge of the map. Seal each end
// with a wall from the trench floor up to z=0, directly beneath the perimeter
// wall (x[X1,X1+20] / x[X2-20,X2]), spanning the trench Y band (which sits in the
// SOLID part of the E/W walls - the corridor door-gaps are well outside it).
emit('corp trench west end wall',
  box(X1, X1 + WALL_TH, TRENCH_Y1, TRENCH_Y2, TRENCH_FLOOR, FLOOR_TOP, 'script_wall'));
emit('corp trench east end wall',
  box(X2 - WALL_TH, X2, TRENCH_Y1, TRENCH_Y2, TRENCH_FLOOR, FLOOR_TOP, 'script_wall'));

// --- stair walkways: ONE staircase per channel, on its assigned lip ----------
// Each step rests on the trench floor (bottom z=TRENCH_FLOOR) and rises to its
// tread top. A 'south' channel descends from the south lip (treads march north);
// a 'north' channel ascends to the north lip (treads march south). Both land on
// the single flat trench floor, so the two stairs are joined by the floor.
for (const ch of STAIR_CHANNELS) {
  for (let k = 1; k <= N_STEPS; k++) {
    const top = -STEP * k;
    let yA;
    let yB;
    let lip;
    if (ch.side === 'south') {
      yA = TRENCH_Y1 + STEP * (k - 1);
      yB = TRENCH_Y1 + STEP * k;
      lip = 'S';
    } else {
      yB = TRENCH_Y2 - STEP * (k - 1);
      yA = TRENCH_Y2 - STEP * k;
      lip = 'N';
    }
    emit(`corp trench ${ch.name} stair ${lip}${k} (tread z=${top})`,
      box(ch.x1, ch.x2, yA, yB, TRENCH_FLOOR, top, 'script_floor_ceiling'));
  }
}

// --- stair GUARD RAILS -------------------------------------------------------
// Each stair hugs an end wall on one long side; its OTHER long side is open to
// the 288u pit (step off it and you fall in). Seal that open side with a rail
// from the floor up to z=0, running the stair's full length but stopping at the
// stair BOTTOM so the stair still spills onto the floor (the cross route).
// GUARD RAILS REMOVED (user, 2026-06-18): the stairs are intentionally open on
// their pit-facing side now (the trench is a fall risk on foot). Do NOT re-emit
// the rails on a regen, or tools/remove_guard_rails.js has to strip them again.
// (Kept the GUARD_TH/runY context above for reference if ever re-enabled.)
void GUARD_TH;

out.push('===== MANIFEST (' + manifest.length + ' brushes) =====');
out.push(manifest.map((m, i) => `  ${i + 1}. ${m}`).join('\n'));
console.log(out.join('\n'));
