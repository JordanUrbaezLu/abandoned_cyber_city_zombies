// Adapt HB21's _zm_weap_keeper_skull.gsc/.csc for ACC:
//  - toplayer pool is FULL -> move skull_beam_fx / skull_torch_fx to "allplayers"
//    (gsc+csc in lockstep; gsc setters set_to_player->set, get_to_player->get)
//  - drop the thrasher_skull_fire actor CF (no thrashers on this map; saves 1 actor bit)
//  - csc: local-player guard in the two converted 1P callbacks (allplayers callbacks
//    fire for EVERY player ent on every client; viewmodel FX must stay local-only)
const fs = require('fs')
const src = 'C:/Users/jorda/AppData/Local/Temp/claude/c--Users-jorda-Repositories-abandoned-cyber-city-zombies/77576949-870f-4be7-9ebb-a260c8acbb13/scratchpad/staging/hb21/hb21_specialist_weapons_v2.0.0/usermaps - OPEN ME/YOUR_MAP_NAME/scripts/zm'
const dst = 'c:/Users/jorda/Repositories/abandoned_cyber_city_zombies/scripts/zm'

const HDR_GSC = `// ============================================================================
// [acc] VENDORED + ADAPTED from HarryBo21 Hero Weapons v2.0.0 (2026-07-24; game-rip
// pack, CREDITS.md). Skull of Nan Sapwe server logic. ACC adaptations (LOCKSTEP with
// the .csc twin or the map dies with "Clientfield Mismatch"):
//   1. skull_beam_fx / skull_torch_fx moved "toplayer" -> "allplayers": the toplayer
//      CF pool is FULL (memory toplayer-clientfield-pool-full; +4 bits = silent load
//      crash). allplayers had only 2 registrations. Setters converted
//      set_to_player->set / get_to_player->get (fields live on the player ent).
//   2. "thrasher_skull_fire" actor CF registration DELETED (no thrashers on this
//      map; every call site is gated by IS_TRUE(b_is_thrasher) = dead code, and the
//      actor pool is tight - memory actor-clientfield-bit-budget).
// ============================================================================
`
const HDR_CSC = `// ============================================================================
// [acc] VENDORED + ADAPTED from HarryBo21 Hero Weapons v2.0.0 (2026-07-24; CLIENT).
// LOCKSTEP with the .gsc twin: beam/torch CFs moved toplayer -> allplayers (pool
// full), thrasher_skull_fire registration deleted. The two converted 1P callbacks
// got a getLocalPlayer guard - as allplayers fields they now fire for EVERY player
// ent on every client, but playViewModelFx must stay local-shooter-only (mirrors
// the existing "player != self" guards in the 3p callbacks).
// ============================================================================
`

// ---- GSC ----
let g = fs.readFileSync(src + '/_zm_weap_keeper_skull.gsc', 'utf8')
const gOrig = g
g = g.replace('clientfield::register( "toplayer", "skull_beam_fx", VERSION_SHIP, 2, "int" );',
              'clientfield::register( "allplayers", "skull_beam_fx", VERSION_SHIP, 2, "int" );   // [acc] toplayer pool full')
g = g.replace('clientfield::register( "toplayer", "skull_torch_fx", VERSION_SHIP, 2, "int" );',
              'clientfield::register( "allplayers", "skull_torch_fx", VERSION_SHIP, 2, "int" );  // [acc] toplayer pool full')
g = g.replace('\tclientfield::register( "actor", "thrasher_skull_fire", VERSION_SHIP, 1, "int" );\n',
              '\t// [acc] thrasher_skull_fire actor CF deleted (no thrashers; call sites all b_is_thrasher-gated dead code)\n')
let nSet = 0, nGet = 0
g = g.replace(/clientfield::set_to_player\(/g, () => { nSet++; return 'clientfield::set(' })
g = g.replace(/clientfield::get_to_player\(/g, () => { nGet++; return 'clientfield::get(' })
if (g === gOrig) throw new Error('gsc transform made no changes')
fs.writeFileSync(dst + '/_zm_weap_keeper_skull.gsc', HDR_GSC + g)

// ---- CSC ----
let c = fs.readFileSync(src + '/_zm_weap_keeper_skull.csc', 'utf8')
c = c.replace('clientfield::register( "toplayer", "skull_beam_fx", VERSION_SHIP, 2, "int", &skull_beam_fx_cb, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );',
              'clientfield::register( "allplayers", "skull_beam_fx", VERSION_SHIP, 2, "int", &skull_beam_fx_cb, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );   // [acc] lockstep with gsc')
c = c.replace('clientfield::register( "toplayer", "skull_torch_fx", VERSION_SHIP, 2, "int", &skull_torch_fx_cb, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );',
              'clientfield::register( "allplayers", "skull_torch_fx", VERSION_SHIP, 2, "int", &skull_torch_fx_cb, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );  // [acc] lockstep with gsc')
c = c.replace('\tclientfield::register( "actor", "thrasher_skull_fire", VERSION_SHIP, 1, "int", &thrasher_skull_fire_cb, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );\n',
              '\t// [acc] thrasher_skull_fire actor CF deleted (lockstep with gsc)\n')
// local-player guards, inserted right after the isSpectating early-out in the two 1P callbacks
const GUARD = '\n\tif ( self != getLocalPlayer( localclientnum ) )\n\t\treturn;   // [acc] allplayers conversion: 1P viewmodel FX = local shooter only\n'
let guards = 0
c = c.replace(/function skull_torch_fx_cb\( localclientnum, oldval, newval, bnewent, binitialsnap, fieldname, bwastimejump \)\r?\n\{\r?\n\tif \( isSpectating\( localclientnum \) \)\r?\n\t\treturn;\r?\n/,
  m => { guards++; return m + GUARD })
c = c.replace(/function skull_beam_fx_cb\( localclientnum, oldval, newval, bnewent, binitialsnap, fieldname, bwastimejump \)\r?\n\{\r?\n\tif \( isSpectating\( localclientnum \) \)\r?\n\t\treturn;\r?\n\t\r?\n/,
  m => { guards++; return m + GUARD })
if (guards !== 2) throw new Error('expected 2 guards, inserted ' + guards)
fs.writeFileSync(dst + '/_zm_weap_keeper_skull.csc', HDR_CSC + c)

console.log('gsc: set_to_player->set =', nSet, ', get_to_player->get =', nGet, '; csc guards =', guards)
// sanity: no toplayer refs remain for the two fields, registration parity
const g2 = fs.readFileSync(dst + '/_zm_weap_keeper_skull.gsc', 'utf8')
const c2 = fs.readFileSync(dst + '/_zm_weap_keeper_skull.csc', 'utf8')
for (const [n, t] of [['gsc', g2], ['csc', c2]]) {
  if (/"toplayer"/.test(t)) throw new Error(n + ' still has a toplayer registration')
  const regs = (t.match(/clientfield::register\(/g) || []).length
  console.log(n, 'registrations:', regs)
}
