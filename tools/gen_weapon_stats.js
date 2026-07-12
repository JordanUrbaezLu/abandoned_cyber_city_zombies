#!/usr/bin/env node
// =============================================================================
// gen_weapon_stats.js - GENERATE docs/41_weapon_stats_table.md from GROUND TRUTH.
//
// WHY THIS EXISTS (user 2026-07-04): the weapon stats doc kept drifting because it
// was hand-maintained and cross-referenced 4 conflicting sources (live GDT, the
// pricing tool, stale code comments, old doc snapshots). This tool reads ONLY the
// two sources of truth and EMITS the doc, so it can never silently go wrong:
//   1. The DEPLOYED GDT `_up` (Pack-a-Punch) entries  -> raw damage / clipSize /
//      maxAmmo / locHead  (per-gun entry name is pinned in ROSTER below - these were
//      each hand-verified against the live GDT one-by-one, workflow pap-gun-stats-verify).
//   2. scripts/.../_acc_damage.gsc  -> per-gun balance mult (acc_weapon_balance_mult),
//      the global damage mult, the headshot mult; and _acc_pap_levels.gsc -> the PaP
//      tier ladder (pap_tier_mult). All parsed live, never hardcoded.
//
// THE FORMULA (verified from _acc_damage.gsc on_ai_damage, 2026-07-04):
//   final = rawDamage(held weapon) x bal x global x bonus_factor x headTemper
//   PaP BODY (tier T) = round( rawDamage(_up) x bal x global x papMult(T) )
//   HEADSHOT          = round( BODY x (locHead x headMult) )   [locHead 5 -> 2.5x;
//                       Mahem locHead 4 -> 2.0x; shotguns locHead 1 = headshot-excluded]
//   RESERVE (rounds)  = ammoCountClipRelative ? clipSize x maxAmmo : maxAmmo
//                       (clipRel 1 = maxAmmo is a MAGAZINE count; clipRel 0 = maxAmmo is
//                        ABSOLUTE ROUNDS - the wonder weapons Blast-O-Matic _up / Thundergun.
//                        Reading maxAmmo as mags for a clipRel-0 gun is the 2026-07-09 bug that
//                        collapsed the Blast-O-Matic PaP reserve to 6 - see CHANGELOG 2026-07-10.)
//
// SELF-CHECK: every ROSTER gun MUST resolve a real _up GDT entry with non-zero
// damage/clipSize/maxAmmo AND a bal mult, or the script ABORTS (never emits a
// half-wrong doc). Re-derives body two ways and asserts they match.
//
// USAGE:  node tools/gen_weapon_stats.js          (writes docs/41)
//         node tools/gen_weapon_stats.js --check  (verify only, no write; exit 1 on any gap)
//
// REGENERATE after ANY gun retune (GDT ammo/damage OR a bal mult change). Needs the
// deployed GDTs (external, dev box only) - on a fresh box the last-committed doc stands.
// =============================================================================

const fs = require('fs');
const path = require('path');

const TOOLS = process.env.TA_TOOLS_PATH ||
  'C:/Program Files (x86)/Steam/steamapps/common/Call of Duty Black Ops III 455130';
const SRC = path.join(TOOLS, 'source_data');
const REPO = path.resolve(__dirname, '..');
const DMG_GSC = path.join(REPO, 'scripts/zm/zm_abandoned_cyber_city/_acc_damage.gsc');
const PAP_GSC = path.join(REPO, 'scripts/zm/zm_abandoned_cyber_city/_acc_pap_levels.gsc');
const MAP_GSC = path.join(REPO, 'scripts/zm/zm_abandoned_cyber_city/_acc_map_randomizer.gsc');
const OUT = path.join(REPO, 'docs/25_weapon_stats_table.md');   // renumbered 41->25 (docs_renumber_2026_07_10); keep OUT in sync

const CHECK_ONLY = process.argv.includes('--check');

// -----------------------------------------------------------------------------
// ROSTER - the LIVE box guns. Each gun's PaP `_up` GDT entry NAME + FILE is pinned
// (hand-verified 1:1 vs the live GDT). balKey = the IsSubStr key acc_weapon_balance_mult
// matches. tier/score/priceTier come from docs/54 (compute_gun_tiers.js). class + notes.
// ASM1 is RETIRED (removed from box/pools) -> intentionally excluded.
// Thundergun (WW, GDT damage 0) + Action Figure (melee, no _up) are specials, listed
// separately with no standard PaP single-shot.
// -----------------------------------------------------------------------------
// `sec` = the doc section the gun is grouped under (user 2026-07-09: sections by gun type, rows
// ordered by box rarity within each). Section order itself = SECTION_ORDER below.
const ROSTER = [
  { d: 'Peacekeeper', cls: 'Shotgun', sec: 'Shotgun',     balKey: 'apex_peacekeeper', gdt: 'acc_apex_up.gdt',       up: 'apex_peacekeeper_up_zm', tier: 'S', price: 'TOP', score: 7.73, pellet: true },   // Apex - top shotgun, power-first (user 2026-07-06)
  { d: 'M60',         cls: 'LMG',     sec: 'LMG',         balKey: 't9_m60',         gdt: 'skye_t9_m60.gdt',         up: 't9_m60_up',         tier: 'S',  price: 'TOP', score: 8.11 },
  { d: 'AK-47',       cls: 'AR',      sec: 'AR',          balKey: 't9_ak47',        gdt: 'skye_t9_ak-47.gdt',       up: 't9_ak47_up',        tier: 'S',  price: 'TOP', score: 8.04 },
  { d: 'PPSH-41',     cls: 'SMG',     sec: 'SMG',         balKey: 's4_ppsh41',      gdt: 'skye_s4_ppsh-41.gdt',     up: 's4_ppsh41_base_up', tier: 'S',  price: 'TOP', score: 8.04, box: 's4_ppsh41_base' },
  { d: 'XM4',         cls: 'AR',      sec: 'AR',          balKey: 't9_xm4',         gdt: 'skye_t9_xm4.gdt',         up: 't9_xm4_up',         tier: 'S',  price: 'TOP', score: 7.86 },
  { d: 'Tac-19',      cls: 'Shotgun', sec: 'Shotgun',     balKey: 's1_tac19',       gdt: 'skye_s1_tac-19.gdt',      up: 's1_tac19_up',       tier: 'A-', price: 'MID', score: 6.80, pellet: true },
  { d: 'MORS',        cls: 'Sniper',  sec: 'Marksman & Sniper', balKey: 's1_mors',  gdt: 'skye_s1_mors.gdt',        up: 's1_mors_up',        tier: 'A',  price: 'TOP', score: 7.50 },
  { d: 'AE4',         cls: 'AR',      sec: 'AR',          balKey: 's1_ae4',         gdt: 'skye_s1_ae4.gdt',         up: 's1_ae4_up',         tier: 'B',  price: 'MID', score: 7.19 },
  { d: 'RW1',         cls: 'Pistol',  sec: 'Pistol',      balKey: 's1_rw1',         gdt: 'skye_s1_rw1.gdt',         up: 's1_rw1_up',         tier: 'A+', price: 'MID', score: 7.15 },
  { d: 'AK-74u',      cls: 'SMG',     sec: 'SMG',         balKey: 't9_ak74u',       gdt: 'skye_t9_ak-74u.gdt',      up: 't9_ak74u_up',       tier: 'A',  price: 'MID', score: 7.03 },
  { d: 'Streetsweeper', cls: 'Shotgun', sec: 'Shotgun',   balKey: 't9_streetsweeper', gdt: 'skye_t9_streetsweeper.gdt', up: 't9_streetsweeper_up', tier: 'B', price: 'BOT', score: 6.20, pellet: true },
  { d: 'CEL-3',       cls: 'Shotgun', sec: 'Shotgun',     balKey: 's1_cel3',        gdt: 'skye_s1_cel-3_cauterizer.gdt', up: 's1_cel3_up',      tier: 'B',  price: 'TOP', score: 6.22, pellet: true },
  { d: 'Grav',        cls: 'AR',      sec: 'AR',          balKey: 't9_grav',        gdt: 'skye_t9_grav.gdt',        up: 't9_grav_up',        tier: 'B+', price: 'BOT', score: 6.85 },
  { d: 'Prowler',     cls: 'SMG',     sec: 'SMG',         balKey: 'apex_prowler',   gdt: 'acc_apex_up.gdt',         up: 'apex_prowler_up_zm', tier: 'B',  price: 'BOT', score: 6.43 },   // Apex burst PDW (full-auto here), user 2026-07-06
  { d: 'RPD',         cls: 'LMG',     sec: 'LMG',         balKey: 't9_rpd',         gdt: 'skye_t9_rpd.gdt',         up: 't9_rpd_up',         tier: 'C',  price: 'MID', score: 6.10 },
  { d: 'HAMR',        cls: 'LMG',     sec: 'LMG',         balKey: 't6_hamr',        gdt: 'skye_t6_hamr.gdt',        up: 't6_hamr_up',        tier: 'B',  price: 'MID', score: 6.27 },   // BO2 LMG (user 2026-07-10): between M60 (S) and RPD (C). Loc + ammo normalized install-side (tools/prep_hamr_gdt.js).
  { d: 'Five-Seven',  cls: 'Pistol (start)', sec: 'Pistol', balKey: 't6_fiveseven', gdt: 'skye_t6_fiveseven.gdt',  up: 't6_fiveseven_up',   tier: 'C-', price: 'BOT', score: 5.99 },
  { d: 'MK14',        cls: 'DMR',     sec: 'Marksman & Sniper', balKey: 's1_mk14',  gdt: 'skye_s1_mk14.gdt',        up: 's1_mk14_up',        tier: 'B-', price: 'BOT', score: 5.89 },   // PaP price BOT (user 2026-07-11: 3000/4500/6000, down from MID)
  { d: 'Olympia',     cls: 'Shotgun', sec: 'Shotgun',     balKey: 't6_olympia',     gdt: 'skye_t6_olympia.gdt',     up: 't6_olympia_up',     tier: 'C',  price: 'BOT', score: 4.27, pellet: true },
  // M16 RETIRED 2026-07-11 (user): replaced by the Apex Triple Take (below) in the same #19/MID marksman slot.
  { d: 'Triple Take', cls: 'Sniper (3-bolt energy, no falloff)', sec: 'Marksman & Sniper', balKey: 'apex_tripletake', gdt: 'acc_apex_up.gdt', up: 'apex_tripletake_up_zm', tier: 'A-', price: 'MID', score: 7.47, shots: 3 },   // Apex tri-bolt ENERGY sniper (user 2026-07-11): shotCount 3 = 3 bullets/trigger (headshots APPLY, unlike pellet shotguns). Same-day user +25% dmg (bal 0.281875) + 25% RoF (fireTime 0.288) -> B 6.39 became A- 7.47, price PINNED MID (the deliberately-good-deal roll). Nuclear Energy +15% lands its per-trigger clearly above the MORS per-shot. Energy muzzle/tracers/sfx + locs normalized install-side (prep_apex_tripletake_gdt.js).
  { d: 'Alternator',  cls: 'SMG (PaP power)', sec: 'SMG', balKey: 'apex_alternator_up', gdt: 'acc_apex_up.gdt', up: 'apex_alternator_up_zm', tier: 'A', price: 'BOT', score: 7.20, box: 'apex_alternator' },   // Apex - trash base, A+ PaP (user 2026-07-06); balKey = the _up bal line (RUNTIME name, no _zm); up = GDT BLOCK id; box = acc_box_weight key (no _up)
  { d: 'Mahem',       cls: 'Launcher', sec: 'Launcher', balKey: 's1_mahem', gdt: 'skye_s1_mahem.gdt',      up: 's1_mahem_up',       tier: '-',  price: 'TOP', score: null, special: 'explosive (direct + splash)' },
  { d: 'War Machine', cls: 'Launcher', sec: 'Launcher', balKey: 't6_war_machine', gdt: 'skye_t6_war_machine.gdt', up: 't6_war_machine_up', tier: 'A',  price: 'TOP', score: null, special: 'explosive drum GL (impact detonation; PaP = 12-rd full-auto)' },   // user 2026-07-09
  { d: 'Havoc',  cls: 'AR (energy, full-auto)', sec: 'AR', balKey: 'apex_beam_rifle', gdt: 'acc_apex_up.gdt', up: 'apex_beam_rifle_up_zm', tier: 'A', price: 'TOP', score: null, special: 'Apex energy projectile rifle (full-auto)' },   // user 2026-07-09: "technically an AR" - filed under AR, Launcher its own section
];

// Doc section order (user 2026-07-09): Wonders first (the specials table), then gun types.
const SECTION_ORDER = ['AR', 'Marksman & Sniper', 'Shotgun', 'SMG', 'LMG', 'Pistol', 'Launcher'];

// Specials / wonders: no standard hitscan single-shot row (special damage systems / melee). `box` = the
// acc_box_weight pool name so box % is parsed from code like the main table. `cap` = per-match claimant
// cap (_acc_map_randomizer::wonder_cap_limit). Price tier parsed from pap_price_bucket via `box`.
// `up` = the GDT entry read for stats; `kind` = melee|proj|fling|aoe (how it deals damage, decides the Raw
// column source: melee -> meleeDamage, proj -> damage, fling/aoe -> special so Raw = "0 (...)").
const SPECIALS = [
  { d: 'Thundergun',    cls: 'Wonder (WW)',      box: 'thundergun',              cap: 1, up: 'thundergun_upgraded_zm',    kind: 'fling', boss: 'maxHP-fraction blast (thundergun_boss_blast)', note: 'GDT damage 0 - kills via the multiplier-immune wind FLING; bosses take a separate maxhealth-fraction blast.' },
  { d: 'Fire Bow',      cls: 'Wonder (bow)',     box: 'elemental_bow_demongate', cap: 1, up: 'elemental_bow_demongate_zm', kind: 'aoe',
    rawOverride: 'TAP 2233/1116 blast', effOverride: 'HOLD = DoT (see vs Boss)',
    boss: 'Charged portal = DAMAGE-OVER-TIME zone (2026-07-08): zombies/elites frac×roundHP/s (1/5→1/2 by tier), BOSSES maxHP/div/s (÷80→÷40 by tier) + chompers. Furies: arrow hit = guaranteed one-shot.',
    note: 'HB21 Der Eisendrache fire (demon-gate) bow. TWO fire modes (charged portal REDESIGNED 2026-07-08 - DoT zone, not an instant blast):\n' +
          '  - **TAP (uncharged), 1 arrow:** fires one arrow - ~0 direct damage + a FIXED impact blast (GDT explosionInnerDamage 2233 / outer 1116, r96) and spawns 1 roaming chomper. One-shots trash at low/mid rounds, then FALLS OFF (the 2233 is fixed, never scales).\n' +
          '  - **HOLD (charged demon-gate), 3 arrows = the real weapon:** opens a portal that is a **DAMAGE-OVER-TIME zone** while its visual is live (~5s, 1s ticks, shooter-credited): **zombies + elites take `frac × current round zombie HP` per second** - frac **1/5 / 1/4 / 1/3 / 1/2** by PaP tier (tier-0 zombie in the void dies in ~5s; max tier ~2s) - and **BOSSES/mini-bosses take `their maxHP ÷ div` per second** - div **80 / 65 / 50 / 40** by tier. Plus auto-hunting **chompers** that instakill normal zombies. (The pack\'s original instant radiusDamage kill provably lands zero damage on this map - replaced by bow_demongate_portal_dot.)\n' +
          '  So: **normal zombies -> die in the void over seconds** (or instantly to chompers); **Apothicon Furies -> GUARANTEED one-shot on the ARROW hit** (dvar acc_firebow_fury_onehit; the DoT carries no weapon ref); **bosses -> a real DoT drain** (÷80..÷40 of their bar per second by tier) - still not a boss-killer (that\'s the Leviathan).\n' +
          '  **PaP-scaled (nerfed base):** void **radius 110 / 140 / 170 / 200** (+30/tier; re-defaulted 2026-07-11 from the instant-blast-era 50/65/80/95 - log-proven unreachable for a DoT zone) and **chompers 1 / 1 / 2 / 3** by tier (t0/T1/T2/T3; dvars acc_firebow_aoe_radius_t0..3 / acc_firebow_chompers_t0..3) - the radius is a **HORIZONTAL ring** around the portal with a same-floor height window (acc_firebow_dot_zband, default 160; fixed 2026-07-11 - the old 3D check measured from the portal center ~64u up to zombie FEET, so tier 0/1 could never hit anything); **the void SLOWS normal zombies inside it** (demon-gate pull; ASMSetAnimationRate = the Widow\'s Wine mechanism, acc_firebow_void_slow_rate default 0.4, bosses exempt, watchdog-restored on exit) and **lives ~7s** (acc_firebow_void_tail_secs default 5.0, ~7 ticks); boss/mechz ticks use the pack\'s 8-arg MOD_PROJECTILE_SPLASH DoDamage (the bare 3-arg form was eaten by the mechz hitloc wrap); DoT dvars acc_firebow_dot_frac_t0..3 / acc_firebow_dot_boss_div_t0..3; **DoT hits at most 20 enemies per tick** (acc_firebow_dot_max_targets). **Clip 30 -> 50 at 2nd PaP+** (acc_firebow_clip_t0..3). **Charged shot costs 3 arrows** (engine full-charge eats 2, the portal deducts 1 more post-fire - never touch the engine threshold dvar, it breaks full charge). DoT ticks ride the exact-damage side-channel (acc_tg_exact_dmg) so the global ×3.25 buff and the boss cap never rescale the spec fractions. bal 1.0. PaP = upgrade-in-place (CSV upgrade=self).\n' +
          '  **CUSTOM CHARGE DETECTION (2026-07-11, 6th charge fix - script-owned, no longer trusts the engine):** the trigger HOLD TIME is measured in GSC (acc_firebow_hold_tracker/acc_firebow_fire_watcher); a hold >= **acc_firebow_charge_hold_ms** (default 1200) marks the arrow CHARGED and it opens the portal **whatever charge-level def the engine fired** - engine charge resets (the historical killers) can no longer eat the move. If the arrow\'s projectile_impact event never arrives (direct zombie-body hits), a shadow tracker opens the portal at the arrow\'s last origin; a 500ms per-shooter gate keeps it to one portal per arrow.' },
  { d: 'Leviathan Axe', cls: 'Wonder (melee)',   box: 'leviathan',               cap: 1, up: 'leviathan_up_zm',            kind: 'melee', perEnemy: true, boss: '', note: '' },
  { d: 'Blast-O-Matic', cls: 'Wonder (energy)',  box: 't9_semiauto_cosplay',     cap: 1, up: 't9_semiauto_cosplay_up',    kind: 'proj', boss: 'x0.75 + 10% per-hit cap', note: 'is_wonder_weapon energy blaster; -40% damage nerf (2026-07-03). Direct projectile, no splash.' },
  { d: 'Action Figure', cls: 'Melee',            box: 't8_melee_figure',         cap: null, up: 't8_melee_figure',         kind: 'melee', boss: '1/30 maxHP/hit (~30 hits, acc_af_boss_hits)', note: 'PaPs IN PLACE (no _up form); each tier adds +1 cleave target. bal = default (uncut).' },
  { d: "Winter's Howl", cls: 'Wonder (freeze)',  box: 'freezegun',               cap: 1, up: 'freezegun_upgraded_zm',      kind: 'aoe',
    rawOverride: '1000/500 cone (in/out)', effOverride: 'T0 1000/500 · T3 2500/1250',
    boss: '35% MOVE SLOW for 5s per hit (the headline UTILITY use; acc_freeze_boss_slow_rate 0.65 / _sec 5; a re-hit RESETS the timer, never stacks) - NOT a damage boss-killer (modest cone damage, 10% per-hit boss cap still backstops it; no iceover/shatter on bosses).',
    note: 'GCPeinhardt 1:1 BO1 Winter\'s Howl port (booris models). A UTILITY wonder weapon - its focus is SLOWING, not damage. Fires a freeze CONE: progressive freeze that walks regular zombies to a crawl -> iceover -> SHATTER (authentic stock Winter\'s Howl; not a one-hit at higher rounds). ' +
          'ONE-HITS the Glitch Stalker (any freeze-cone hit kills it); SUPER-EFFECTIVE vs the Shielded "Riot" elite (x3, acc_freeze_vs_shielded); x2 vs the Phantom boss (acc_freeze_vs_phantom) - all with a freeze move-slow. BOSSES: 35%/5s move slow + capped damage (see vs Boss). ' +
          'Cone damage is a weaponless DoDamage from zombie_vars (BO1 stats: inner 1000 / outer 500; upgraded 1500 / 750; use_t8_damage_set doubles) - NOT scaled by acc_weapon_balance_mult, but the 10% per-hit boss cap still applies to bosses. The AI move-slow mirrors the Fire Bow void slow (a flag + ASMSetAnimationRate, honored by _acc_zombie_speed::under_anim_slow, watchdog restores rate 1.0 on expiry). ' +
          'projectileweapon _zm asset (script/CSV/box use the bare "freezegun"). Claim-capped 1/match (acc_cap_freezegun). PaP scales the freeze cone +50%/TIER (T0 x1 / T1 x1.5 / T2 x2 / T3 x2.5, off base vars 1000/500 = point-blank 1000->1500->2000->2500; acc_freeze_pap_per_tier) + tier-2 model transform (+ bigger range) + fastreload wonder twins + move 1.07. External rip - assets gitignored via the manifest. Combat logic: _zm_weap_freezegun.gsc [acc] block.' },
  // Ballistic Knife (user 2026-07-11): box-only special, NOT claim-capped, TOP PaP price. Dual attack (thrown
  // retrievable blade + own melee stab), damage 100% SCRIPTED. `knife` kind = show BOTH raw numbers; boss +
  // note filled live in the emit loops from BK_THROW_MULT / BK_STAB_MULT. See docs/04 Per-Weapon Detail.
  { d: 'Ballistic Knife', cls: 'Special (throw + stab)', box: 'knife_ballistic', cap: null, up: 'knife_ballistic_upgraded_zm', kind: 'knife', knife: true, boss: '', note: '' },
];

// PaP step costs per price tier - DERIVED from _acc_pap_levels.gsc::tier_cost (user 2026-07-12 "code driven so
// no misinfo"): was a hardcoded literal that could silently diverge from the code on a price retune. Parse each
// bucket's 3 `case N: return M` out of tier_cost so the doc's prices always match the game. Fails loud on drift.
const _papForCost = fs.readFileSync(PAP_GSC, 'utf8');
const _tcBody = (_papForCost.match(/function\s+tier_cost\s*\([^)]*\)\s*\{([\s\S]*?)\n\}/) || [])[1];
if (!_tcBody) { console.error('\n[gen_weapon_stats] ABORT: could not isolate tier_cost() in _acc_pap_levels.gsc\n'); process.exit(1); }
function _bucketCosts(marker) {                        // marker: "WONDER"|"TOP"|"MID"| null (=BOT/else branch)
  const start = marker ? _tcBody.indexOf('"' + marker + '"') : _tcBody.lastIndexOf('else');
  if (start < 0) { console.error('\n[gen_weapon_stats] ABORT: tier_cost has no ' + (marker || 'BOT') + ' branch\n'); process.exit(1); }
  const seg = _tcBody.slice(start, start + 400);       // the switch sits immediately after the bucket marker
  const c = [1, 2, 3].map(t => (seg.match(new RegExp('case ' + t + ':\\s*return\\s+(\\d+)')) || [])[1]);
  if (c.some(x => x == null)) { console.error('\n[gen_weapon_stats] ABORT: could not parse tier_cost costs for ' + (marker || 'BOT') + '\n'); process.exit(1); }
  return c.join(' / ');
}
const PRICE_COST = { WONDER: _bucketCosts('WONDER'), TOP: _bucketCosts('TOP'), MID: _bucketCosts('MID'), BOT: _bucketCosts(null) };

// PaP reload seconds per gun, for the SUSTAINED-DPS math. Values are the curated PaP reload (`prl`) from
// compute_gun_tiers.js (the project's own reload numbers, incl. Tac-19's charge time); Klauser = GDT
// reloadEmptyTime 2.9; Mahem = launcher estimate. Keyed by display name.
const PAP_RELOAD = {
  // 2026-07-09 reload retune (scratchpad reload_balance_0709.js): XM4 x1.5 (2.0->3.0), AE4 x1.5 (2.0->3.0),
  // PPSH x0.5 (3.5->1.75), AK-74u x0.7 (2.8->1.96), Olympia x0.7 (2.5->1.75), Havoc x1.15 (3.36->3.864),
  // Prowler x0.8 (2.0->1.6). Each keeps its prior convention (partial vs empty _up reload).
  'Chicom CQB': 2.1, 'M60': 9.7, 'AK-47': 3.25, 'PPSH-41': 1.575, 'XM4': 3.0, 'Tac-19': 0.467, 'MORS': 1.2,
  'AE4': 3.0, 'RW1': 1.4, 'AK-74u': 1.764, 'Streetsweeper': 0.675, 'Grav': 2.925, 'Paladin HB50': 4.13,
  'RPD': 7.5, 'HAMR': 6.0, 'M16': 3.5, 'Triple Take': 3.4, 'Five-Seven': 1.8, 'MK14': 2.0, 'Olympia': 1.75, 'Klauser': 2.9, 'Mahem': 3.5,
  'War Machine': 3.75,   // GDT reloadTime (drum swap; fastreload twin 3.2138 - user 2026-07-09)
  'CEL-3': 3.75, 'China Lake': 3.5,   // CEL-3 GDT reloadTime user 2026-07-11 3.0->3.75 (+25% SLOWER nerf); China Lake launcher estimate (like Mahem)
  'Peacekeeper': 2.5, 'Prowler': 0.9, 'G7 Scout': 2.4, 'Alternator': 1.9, 'Havoc': 3.864,   // Apex guns (user 2026-07-06; Havoc retuned 2026-07-09; Prowler reloadTime user 2026-07-11 1.0->0.9 (+10% faster SMG buff, weapon_rebalance_0711.js); prior 1.6->1.0)
};

// -----------------------------------------------------------------------------
// Parse the source-of-truth constants from the LIVE GSC.
// -----------------------------------------------------------------------------
function die(msg) { console.error('\n[gen_weapon_stats] ABORT: ' + msg + '\n'); process.exit(1); }

if (!fs.existsSync(SRC)) die('deployed source_data not found at ' + SRC + ' (need the GDTs on this box).');
const dmgSrc = fs.readFileSync(DMG_GSC, 'utf8');
const papSrc = fs.readFileSync(PAP_GSC, 'utf8');

const GLOBAL = bounded(num(dmgSrc.match(/#define\s+ACC_GLOBAL_DMG_MULT\s+([\d.]+)/), 'ACC_GLOBAL_DMG_MULT'), 1, 10, 'ACC_GLOBAL_DMG_MULT');
const HEAD_MULT = bounded(num(dmgSrc.match(/#define\s+ACC_HEADSHOT_MULT\s+([\d.]+)/), 'ACC_HEADSHOT_MULT'), 0.1, 2, 'ACC_HEADSHOT_MULT'); // 0.5 -> locHead*0.5
// PaP tier ladder: parse the cases ONLY from inside the pap_tier_mult() function body (there are
// other switch statements in the file - tier_cost returns 5000/7500/10000, which would mis-match).
const PAP_BODY = (papSrc.match(/function\s+pap_tier_mult\s*\([^)]*\)\s*\{([\s\S]*?)\n\}/) || [])[1];
if (!PAP_BODY) die('could not isolate pap_tier_mult() body in _acc_pap_levels.gsc');
const PAP = {
  1: bounded(num(PAP_BODY.match(/case 1:\s*return\s+([\d.]+);/), 'pap_tier_mult(1)'), 1, 3, 'papMult T1'),
  2: bounded(num(PAP_BODY.match(/case 2:\s*return\s+([\d.]+);/), 'pap_tier_mult(2)'), 1, 3, 'papMult T2'),
  3: bounded(num(PAP_BODY.match(/case 3:\s*return\s+([\d.]+);/), 'pap_tier_mult(3)'), 1, 3, 'papMult T3'),
};
if (!(PAP[1] < PAP[2] && PAP[2] <= PAP[3])) die('PaP ladder not monotonic (' + PAP[1] + '/' + PAP[2] + '/' + PAP[3] + ') - parse error');
function num(m, what) { if (!m) die('could not parse ' + what + ' from GSC'); return parseFloat(m[1]); }
function bounded(v, lo, hi, what) { if (!(v >= lo && v <= hi)) die('parsed ' + what + ' = ' + v + ' is outside sane range [' + lo + ',' + hi + '] - regex matched the wrong value'); return v; }

// bal mult per balKey: `if ( IsSubStr( weapon_name, "KEY" ) ) return 0.xxxx;`
function balFor(key) {
  const re = new RegExp('IsSubStr\\(\\s*weapon_name,\\s*"' + key.replace(/[-.]/g, '\\$&') + '"\\s*\\)\\s*\\)\\s*return\\s+([\\d.]+)');
  const m = dmgSrc.match(re);
  if (!m) die('no acc_weapon_balance_mult entry for balKey "' + key + '" in _acc_damage.gsc');
  return bounded(parseFloat(m[1]), 0.01, 1.0, 'bal(' + key + ')');   // every gun is a REDUCTION (<1)
}
// soft bal: returns null if the weapon has no acc_weapon_balance_mult entry (e.g. Action Figure = default 1.0)
function balSoft(key) {
  const re = new RegExp('IsSubStr\\(\\s*weapon_name,\\s*"' + key.replace(/[-.]/g, '\\$&') + '"\\s*\\)\\s*\\)\\s*return\\s+([\\d.]+)');
  const m = dmgSrc.match(re);
  return m ? parseFloat(m[1]) : null;
}
// Leviathan is a PER-ENEMY hits-to-kill weapon (no fixed damage number - each hit = target maxHP / hits).
// Boss hits scale by PaP tier (#defines); per-enemy hits are getdvarint defaults, both parsed from _acc_damage.
const LEVI_HITS = [0, 1, 2, 3].map(t => parseInt((dmgSrc.match(new RegExp('#define\\s+ACC_LEVIATHAN_HITS_T' + t + '\\s+(\\d+)')) || [])[1] || '0', 10));
const leviEnemyHits = k => parseInt((dmgSrc.match(new RegExp('acc_leviathan_hits_' + k + '",\\s*(\\d+)')) || [])[1] || '0', 10);
const LEVI_ENEMY = { zombie: leviEnemyHits('zombie'), glitch: leviEnemyHits('glitch'), shield: leviEnemyHits('shield'), fury: leviEnemyHits('fury') };
// Anti-elite hit counts SHARPEN at 2nd PaP and beyond (tier>=2): shielded + Fury each drop to their _pap2 value.
const leviEnemyHitsPap2 = k => parseInt((dmgSrc.match(new RegExp('acc_leviathan_hits_' + k + '_pap2",\\s*(\\d+)')) || [])[1] || '0', 10);
const LEVI_ENEMY_PAP2 = { shield: leviEnemyHitsPap2('shield'), fury: leviEnemyHitsPap2('fury') };
const BOSS_CAP = parseFloat((dmgSrc.match(/#define\s+ACC_BOSS_PER_HIT_CAP_PCT\s+([\d.]+)/) || [])[1] || '0.1');
// Fire Bow vs Apothicon Fury is a GUARANTEED one-hit (deals full max HP), not a multiplier (user 2026-07-07).
const FIREBOW_FURY_ONEHIT = (dmgSrc.match(/acc_firebow_fury_onehit",\s*1/) ? 1 : 0);
// Ballistic Knife per-attack boss-chip multipliers (user 2026-07-12 "stab x2, throw x6") - the getdvarfloat
// defaults in the _acc_damage 0c3 block, parsed live so the doc can't drift on a retune.
const BK_STAB_MULT  = parseFloat((dmgSrc.match(/acc_bk_stab_mult",\s*([\d.]+)/)  || [])[1] || '2');
const BK_THROW_MULT = parseFloat((dmgSrc.match(/acc_bk_throw_mult",\s*([\d.]+)/) || [])[1] || '6');

// -----------------------------------------------------------------------------
// GUN TIER SCORE (user 2026-07-11 redesign). REPLACES the old compute_gun_tiers.js hand table (which
// hard-typed effDPS / reload / move / pen / handling per gun and DRIFTED on every retune - e.g. after the
// 2026-07-11 balance pass its AK-74u reload / Prowler DPS / HAMR move were all stale). This scores each gun
// ENTIRELY from its LIVE PaP `_up` GDT stats + bal, so it can never drift, and it factors EVERY meaningful
// GDT stat (the old formula ignored recoil / accuracy / ADS+swap handling / headshot / range).
//   - DPS-DOMINANT (user choice): sustained PaP-T3 body DPS carries ~1/3 of the score; the rest are the
//     GDT tiebreakers below. Shotgun pellets are capped at PELLET_CAP on a single target (all 12 point-blank
//     over-rates them vs single-target guns).
//   - TIER = EVEN THIRDS of the ranked scoreable guns -> A (top third) / B (middle) / C (bottom). Always an
//     even spread (user choice), no S/A+/B- micro-tiers.
//   - DISPLAY ONLY (user choice): this drives the docs/25 Tier column. PaP PRICE + BOX ODDS stay on their
//     own separate terciles (docs/33, compute_gun_tiers.js) - untouched here.
//   - PaP-form only (user 2026-07-11): base form is never scored. Specials (launchers / energy-projectile /
//     wonders) are OUTSIDE the formula (special damage models) -> Tier '-'.
// Every bound below is a named knob - retune weights/bounds here and re-run; the whole thing is one pass.
// -----------------------------------------------------------------------------
const SCORE_W = { dps: 0.30, power: 0.13, sustain: 0.12, reserve: 0.09, mobility: 0.08, control: 0.09,
                  handling: 0.06, pen: 0.05, accuracy: 0.04, range: 0.04 };   // sums to 1.00; DPS + burst-power dominant
// dps  = sustained PaP-T3 body DPS (reload-inclusive).  power = max single-hit BURST (headshot dmg, or full-pellet
// point-blank for shotguns) - the per-trigger punch, so a hard-hitting sniper/AR isn't tanked purely for low RoF.
// (Burst power SUBSUMES the old flat-locHead "headshot" factor, which was a useless constant 10 for every
//  non-shotgun since all roster guns are locHead 5.0.)
const PELLET_CAP = 6;                                    // shotgun pellets counted on ONE target for the DPS metric
const PEN_SCORE = { none: 2, small: 4, medium: 7, large: 10 };
const sClamp = (x, lo, hi) => Math.max(lo, Math.min(hi, x));
const sLin = (x, a, b) => sClamp(1 + (x - a) / (b - a) * 9, 1, 10);                       // a->1 .. b->10 (higher better)
const sLog = (x, a, b) => sClamp(1 + 9 * (Math.log(Math.max(x, 1e-6)) - Math.log(a)) / (Math.log(b) - Math.log(a)), 1, 10);
const sInv = (x, best, worst) => sClamp(1 + 9 * (worst - x) / (worst - best), 1, 10);      // LOWER better: best->10, worst->1

// -----------------------------------------------------------------------------
// MYSTERY-BOX probability - parsed LIVE from _acc_map_randomizer.gsc::acc_box_weight (per-gun tier
// weight) + acc_box_tactical_preroll (the Monkey/Arnie fixed pre-roll that guns share the rest of).
//   per-open % = weight / poolTotal x gunShare        (gunShare = 1 - tactical fraction, ~0.985)
// Read from code so a rebalance of the box curve is reflected here with no hand-edit.
// -----------------------------------------------------------------------------
const boxSrc = fs.readFileSync(MAP_GSC, 'utf8');
const BOX_BODY = (boxSrc.match(/function\s+acc_box_weight\s*\([^)]*\)\s*\{([\s\S]*?)\n\}/) || [])[1];
if (!BOX_BODY) die('could not isolate acc_box_weight() body in _acc_map_randomizer.gsc');
const BOX_WEIGHTS = {};
for (const m2 of BOX_BODY.matchAll(/if\s*\(\s*n\s*==\s*"([^"]+)"\s*\)\s*return\s+(\d+)\s*;/g)) BOX_WEIGHTS[m2[1]] = parseInt(m2[2], 10);
if (Object.keys(BOX_WEIGHTS).length < 20) die('acc_box_weight parse got only ' + Object.keys(BOX_WEIGHTS).length + ' entries (regex drift?)');
const BOX_TOTAL = Object.values(BOX_WEIGHTS).reduce((a, b) => a + b, 0);
// tactical pre-roll: acc_rand_int( RANGE ); the largest `if ( r < N )` cutoff is the total tactical share.
const PR_BODY = (boxSrc.match(/function\s+acc_box_tactical_preroll\s*\([^)]*\)\s*\{([\s\S]*?)\n\}/) || [])[1] || '';
const PR_RANGE = parseInt((PR_BODY.match(/acc_rand_int\(\s*(\d+)\s*\)/) || [])[1] || '1000', 10);
const PR_CUTS = [...PR_BODY.matchAll(/if\s*\(\s*r\s*<\s*(\d+)\s*\)/g)].map(x => parseInt(x[1], 10));
const TACTICAL_CUT = PR_CUTS.length ? Math.max(...PR_CUTS) : 15;
const GUN_SHARE = (PR_RANGE - TACTICAL_CUT) / PR_RANGE;               // e.g. (1000-15)/1000 = 0.985
if (!(GUN_SHARE > 0.9 && GUN_SHARE <= 1)) die('parsed GUN_SHARE ' + GUN_SHARE + ' outside (0.9,1] - preroll parse wrong');
function boxPct(boxName) {
  const w = BOX_WEIGHTS[boxName];
  if (w == null) die('box weight for "' + boxName + '" not found in acc_box_weight (fix the roster boxName)');
  return (w / BOX_TOTAL) * GUN_SHARE * 100;
}
// per-match wonder CLAIM CAP: wonder_cap_key(name)->key, wonder_cap_limit(key)->default N (both live GSC).
const WCK = [...boxSrc.matchAll(/IsSubStr\(\s*w\.name,\s*"([^"]+)"\s*\)\s*\)\s*return\s+"([^"]+)"/g)].map(x => ({ sub: x[1], key: x[2] }));
const WCL = {};
for (const x of boxSrc.matchAll(/key\s*==\s*"([^"]+)"\s*\)\s*return\s+getdvarint\(\s*"[^"]+",\s*(\d+)\s*\)/g)) WCL[x[1]] = parseInt(x[2], 10);
function capForBox(name) { for (const r of WCK) if (name.indexOf(r.sub) >= 0) return WCL[r.key] != null ? WCL[r.key] : null; return null; }

// -----------------------------------------------------------------------------
// COMPLETENESS AUDIT (user 2026-07-12 "audit nothing is missing"): the doc must cover EXACTLY the live box
// roster - never silently OMIT a live gun, never list a RETIRED one. Parse box_weapons[] from
// _acc_map_randomizer.gsc with LINE COMMENTS STRIPPED FIRST (so a commented-out entry, or a stray ");" inside
// a comment, can't fool the match), drop the tacticals (grenades - handled by acc_box_tactical_preroll /
// is_box_tactical, not gun-table rows), and assert a 1:1 match with ROSTER (box||balKey) + SPECIALS (box).
// ABORTS on any gap either way, so a future roster drift can never ship a half-complete stats table.
// -----------------------------------------------------------------------------
const boxNoComments = boxSrc.replace(/\/\/[^\n]*/g, '');
const BW_BODY = (boxNoComments.match(/box_weapons\s*=\s*array\(([\s\S]*?)\);/) || [])[1];
if (!BW_BODY) die('could not isolate box_weapons array in _acc_map_randomizer.gsc (completeness audit)');
const BOX_LIST = [...BW_BODY.matchAll(/"([^"]+)"/g)].map(m => m[1]);
if (BOX_LIST.length < 25) die('box_weapons parse got only ' + BOX_LIST.length + ' entries (regex drift?) - completeness audit unreliable');
const BOX_TACTICALS = new Set(['cymbal_monkey', 'octobomb']);   // grenades: fixed pre-roll, not gun-table rows
const LIVE_GUNS = BOX_LIST.filter(n => !BOX_TACTICALS.has(n));
const COVERED = new Set([...ROSTER.map(g => g.box || g.balKey), ...SPECIALS.map(s => s.box)]);
const bwMissing = LIVE_GUNS.filter(n => !COVERED.has(n));
const bwStale = [...COVERED].filter(n => !LIVE_GUNS.includes(n));
if (bwMissing.length) die('COMPLETENESS: box_weapons gun(s) with NO stats-table row: ' + bwMissing.join(', ') + '  -> add to ROSTER or SPECIALS in gen_weapon_stats.js');
if (bwStale.length) die('COMPLETENESS: stats-table row(s) NOT in the live box_weapons: ' + bwStale.join(', ') + '  -> remove from ROSTER/SPECIALS (or restore the gun to the box pool)');
console.error('[gen_weapon_stats] completeness OK: ' + LIVE_GUNS.length + ' live box guns, all covered (' + ROSTER.length + ' roster + ' + SPECIALS.length + ' specials).');

// -----------------------------------------------------------------------------
// PaP PRICE TIER per weapon - parsed LIVE from _acc_pap_levels.gsc::pap_price_bucket (first IsSubStr
// match wins, exactly as the engine evaluates it). Gives the per-gun TOP/MID/BOT -> cost via PRICE_COST.
// -----------------------------------------------------------------------------
const PB_BODY = (papSrc.match(/function\s+pap_price_bucket\s*\([^)]*\)\s*\{([\s\S]*?)\n\}/) || [])[1];
if (!PB_BODY) die('could not isolate pap_price_bucket() body in _acc_pap_levels.gsc');
const PB_RULES = [...PB_BODY.matchAll(/IsSubStr\(\s*weapon_name,\s*"([^"]+)"\s*\)\s*\)\s*return\s+"(WONDER|TOP|MID|BOT)"/g)].map(x => ({ key: x[1], tier: x[2] }));
if (PB_RULES.length < 20) die('pap_price_bucket parse got only ' + PB_RULES.length + ' rules (regex drift?)');
function priceTierFor(name) {                                        // replicate runtime first-substring-match
  for (const r of PB_RULES) if (name.indexOf(r.key) >= 0) return r.tier;
  return 'BOT';                                                      // pap_price_bucket's default
}

// -----------------------------------------------------------------------------
// Read a field off a specific GDT entry (deployed, LIVE). GDT format:
//   "entryName" ( "parent.gdf" ) { "field" "value" ... }
// Fields are usually on the entry directly (verified). If missing, we ABORT (no guess).
// -----------------------------------------------------------------------------
// Recursive list of every live *.gdt under source_data AND _custom (specials' GDTs live in subdirs:
// owens_weapons/bocw/, t8_weapons/, _custom/wetegg/leviathanaxe/). Cached; skips .acc-*-orig backups.
let _gdtFiles = null;
function allGdtFiles() {
  if (_gdtFiles) return _gdtFiles;
  const roots = [SRC, path.join(path.dirname(SRC), '_custom')].filter(fs.existsSync);
  const out = [];
  const walk = d => { for (const e of fs.readdirSync(d, { withFileTypes: true })) { const p = path.join(d, e.name); if (e.isDirectory()) walk(p); else if (e.name.endsWith('.gdt')) out.push(p); } };
  for (const r of roots) walk(r);
  _gdtFiles = out;
  return out;
}
function gdtEntry(fileHint, entry) {
  // Locate the file that actually contains "entry" - the hint is tried first, then a recursive scan of
  // every *.gdt under source_data + _custom (so a GDT file RENAME/relocation can never silently break it).
  const needle = '"' + entry + '"';
  let p = fileHint ? path.join(SRC, fileHint) : null;
  let txt = (p && fs.existsSync(p)) ? fs.readFileSync(p, 'utf8') : '';
  if (txt.indexOf(needle) < 0) {
    p = null;
    for (const f of allGdtFiles()) {
      const t = fs.readFileSync(f, 'utf8');
      if (t.indexOf(needle) >= 0) { p = f; txt = t; break; }
    }
    if (!p) die('GDT entry "' + entry + '" not found in any *.gdt under source_data/_custom (hint was ' + fileHint + ')');
  }
  const file = path.basename(p);
  const start = txt.indexOf(needle);
  // grab the { ... } block after the entry header
  const open = txt.indexOf('{', start);
  let depth = 0, i = open, end = -1;
  for (; i < txt.length; i++) { if (txt[i] === '{') depth++; else if (txt[i] === '}') { depth--; if (depth === 0) { end = i; break; } } }
  if (end < 0) die('unbalanced braces for entry "' + entry + '" in ' + file);
  return txt.slice(open, end + 1);
}
function fieldNum(block, field, file, entry) {
  const m = block.match(new RegExp('"' + field + '"\\s+"([\\-\\d.]+)"'));
  if (!m) die('field "' + field + '" missing (inherited?) on GDT entry "' + entry + '" in ' + file + ' - resolve the parent by hand, do not guess.');
  return parseFloat(m[1]);
}
// soft variant: returns null if the field is absent (used for optional fields like numPellets)
function fieldNumSoft(block, field) {
  const m = block.match(new RegExp('"' + field + '"\\s+"([\\-\\d.]+)"'));
  return m ? parseFloat(m[1]) : null;
}

// -----------------------------------------------------------------------------
// Build each row from ground truth + self-check.
// -----------------------------------------------------------------------------
const rows = ROSTER.map(g => {
  const bal = balFor(g.balKey);
  const blk = gdtEntry(g.gdt, g.up);
  const raw = fieldNum(blk, 'damage', g.gdt, g.up);
  const clip = fieldNum(blk, 'clipSize', g.gdt, g.up);
  const mags = fieldNum(blk, 'maxAmmo', g.gdt, g.up);
  const clipRel = fieldNumSoft(blk, 'ammoCountClipRelative');           // 1 = maxAmmo is MAGAZINES; 0 = ABSOLUTE ROUNDS (wonder weapons)
  const locHead = fieldNum(blk, 'locHead', g.gdt, g.up);
  const fireTime = fieldNum(blk, 'fireTime', g.gdt, g.up);              // seconds between shots (PaP _up entry)
  const moveSpeed = fieldNumSoft(blk, 'moveSpeedScale') || 1;           // run speed while holding (1.0 = full speed)
  const pellets = g.pellet ? (fieldNumSoft(blk, 'numPellets') || 12) : (g.shots || 1); // PaP shotguns = 12 pellets (docs/41); `shots` = multi-bullet non-shotgun (Triple Take shotCount 3 - headshots still apply)

  // Extra GDT stats for the tier score (all off the same PaP `_up` block): penetration enum, ADS-in +
  // weapon-raise (handling speed), tightest hip spread (accuracy), damage-falloff range.
  const pen = (blk.match(/"penetrateType"\s+"(\w+)"/) || [])[1] || 'none';
  const adsIn = fieldNumSoft(blk, 'adsTransInTime');
  const raise = fieldNumSoft(blk, 'raiseTime');
  const hipSpread = fieldNumSoft(blk, 'hipSpreadStandMin');
  const range = fieldNumSoft(blk, 'maxDamageRange');

  // Recoil = the ADS VIEW-KICK (the on-screen kick the player feels), read off the `_up` entry. These GDT
  // values ALREADY include the map's x1.75 "skill theme" base scale (apply_recoil_overhaul.js) - Mega Deadshot's
  // recoil50 twin halves them at runtime (-> ~x0.875 vanilla). We reduce the 4 fields to two comparable numbers:
  //   vClimb = mean per-shot VERTICAL kick  (pitchMax+pitchMin)/2       -> net upward climb, deg/shot (order-agnostic)
  //   hShake = per-shot HORIZONTAL amplitude |yawMax-yawMin|/2          -> side-to-side wander, deg/shot
  // The |..| on hShake is load-bearing: some GDT entries ship yaw min/max INVERTED (max < min) - amplitude is a
  // magnitude regardless of ordering, so abs keeps it positive. (hip view-kick is identical on nearly every gun.)
  const rkPMax = fieldNumSoft(blk, 'adsViewKickPitchMax'), rkPMin = fieldNumSoft(blk, 'adsViewKickPitchMin');
  const rkYMax = fieldNumSoft(blk, 'adsViewKickYawMax'),   rkYMin = fieldNumSoft(blk, 'adsViewKickYawMin');
  const recoil = (rkPMax != null && rkPMin != null && rkYMax != null && rkYMin != null)
    ? { vClimb: (rkPMax + rkPMin) / 2, hShake: Math.abs(rkYMax - rkYMin) / 2 } : null;

  // self-check: no zero primitives
  if (!(raw > 0 && clip > 0 && mags > 0 && bal > 0 && fireTime > 0)) die(g.d + ': non-positive primitive (raw ' + raw + ' clip ' + clip + ' mags ' + mags + ' bal ' + bal + ' fireTime ' + fireTime + ')');

  const reserve = (clipRel === 0) ? mags : clip * mags;   // clipRel 0 -> maxAmmo IS the round count (do NOT x clip)
  const papBase = raw * bal * GLOBAL;             // pap_mult 1.0 reference (pre tier-ladder)
  const bodyT = { 1: Math.round(papBase * PAP[1]), 2: Math.round(papBase * PAP[2]), 3: Math.round(papBase * PAP[3]) };
  const headMult = g.pellet ? null : locHead * HEAD_MULT;   // 5*0.5=2.5; Mahem 4*0.5=2.0; shotgun excluded
  const headT = headMult == null ? null : { 1: Math.round(bodyT[1] * headMult), 2: Math.round(bodyT[2] * headMult), 3: Math.round(bodyT[3] * headMult) };

  // cross-check: re-derive T3 body a second way and assert equality (guards a formula typo)
  const t3alt = Math.round(((raw * bal) * GLOBAL) * PAP[3]);
  if (t3alt !== bodyT[3]) die(g.d + ': self-check FAILED (bodyT3 ' + bodyT[3] + ' != alt ' + t3alt + ')');
  // absolute sanity: a single PaP body shot is never in the tens-of-thousands (Mahem ~5000 is the
  // ceiling; MORS ~2070). A value past 20000 means a constant mis-parsed (the tier_cost/global trap).
  if (bodyT[3] > 20000) die(g.d + ': bodyT3 ' + bodyT[3] + ' implausibly large - a parsed constant is wrong (raw ' + raw + ', bal ' + bal + ', global ' + GLOBAL + ', papT3 ' + PAP[3] + ')');

  // PaP SUSTAINED DPS (reload-inclusive) = full-clip damage / (time to empty the clip + reload). Honest
  // across weapon types: a clip-1 charge sniper is reload-dominated (no absurd peak), a full-auto amortises
  // its reload. Pellet guns assume a full point-blank hit (all pellets connect) at max PaP (T3) body.
  const reload = PAP_RELOAD[g.d];
  if (reload == null) die(g.d + ': no PAP_RELOAD entry (add its PaP reload seconds)');
  const dpsT3 = Math.round((clip * bodyT[3] * pellets) / (clip * fireTime + reload));

  // box % + PaP price tier, both parsed from LIVE GSC (boxName defaults to balKey; a few differ -> g.box)
  const boxName = g.box || g.balKey;
  const box_pct = boxPct(boxName);
  const priceTier = priceTierFor(boxName);
  if (priceTier !== g.price) die(g.d + ': roster price "' + g.price + '" != code pap_price_bucket "' + priceTier + '" (boxName ' + boxName + ') - the CODE is authoritative; fix the roster price to match');
  const papCost = PRICE_COST[priceTier];

  return { ...g, bal, raw, clip, mags, reserve, locHead, fireTime, moveSpeed, pellets, recoil, reload, papBase, bodyT, headMult, headT, dpsT3, boxName, box_pct, priceTier, papCost, pen, adsIn, raise, hipSpread, range };
});

// -----------------------------------------------------------------------------
// Compute the live A/B/C display tier (PaP-form). Scoreable = every roster gun EXCEPT the specials
// (launchers / energy-projectile - special damage models, outside the formula). DPS-dominant composite of
// the live GDT sub-scores, ranked, split into even thirds.
// -----------------------------------------------------------------------------
function gunScore(r) {
  // DPS = sustained PaP-T3 body DPS (reload-inclusive); shotgun pellets capped for single-target realism.
  const pel = r.pellet ? Math.min(r.pellets, PELLET_CAP) : (r.shots || 1);
  const dps = (r.clip * r.bodyT[3] * pel) / (r.clip * r.fireTime + r.reload);
  const sc = {
    dps:      sLog(dps, 1500, 13000),
    sustain:  sInv(r.reload / r.clip, 0.03, 1.2),                       // reload seconds per magazine round
    reserve:  sLog(r.reserve, 40, 700),
    mobility: sLin(r.moveSpeed, 0.80, 1.07),
    control:  r.recoil ? sInv(r.recoil.vClimb + r.recoil.hShake, 40, 200) : 5.5,   // ADS view-kick total
    handling: sInv((r.adsIn != null ? r.adsIn : 0.3) + (r.raise != null ? r.raise : 0.7), 0.6, 1.6),
    power:    sLog(r.pellet ? r.bodyT[3] * r.pellets : (r.headT ? r.headT[3] : r.bodyT[3]), 500, 10000),  // max single-hit burst
    pen:      PEN_SCORE[r.pen] != null ? PEN_SCORE[r.pen] : 4,
    accuracy: r.pellet ? 5.5 : (r.hipSpread != null ? sInv(r.hipSpread, 1, 12) : 5.5),  // wide spread is by-design for shotguns
    range:    sLog(r.range != null ? r.range : 500, 300, 6000),
  };
  const total = Object.keys(SCORE_W).reduce((a, k) => a + sc[k] * SCORE_W[k], 0);
  return { total, sc, dps };
}
const scoreable = rows.filter(r => !r.special);
for (const r of scoreable) { const s = gunScore(r); r.score2 = s.total; r.sc = s.sc; r.dpsMetric = s.dps; }
// TIER = ranked thirds WITHIN each gun CATEGORY (sec), NOT across all guns (user 2026-07-11: "keep the
// score within its own category - too hard to make a formula across gun categories"). A shotgun's
// pellet-DPS and a sniper's charge-burst are not comparable on one axis, so each class is ranked against
// ITS OWN members: A = best third of the class, B = middle, C = worst. Score is still the same live
// DPS-dominant composite; only the A/B/C cut is per-class.
const bySec = {};
for (const r of scoreable) (bySec[r.sec] = bySec[r.sec] || []).push(r);
for (const grp of Object.values(bySec)) {
  grp.sort((a, b) => b.score2 - a.score2);
  const N = grp.length;
  grp.forEach((r, i) => { r.tier2 = (i < N / 3) ? 'A' : (i < 2 * N / 3) ? 'B' : 'C'; r.rankPos = i + 1; r.rankOf = N; });
}

// -----------------------------------------------------------------------------
// Emit the doc.
// -----------------------------------------------------------------------------
const stamp = process.env.ACC_GEN_DATE || '(run date not injected)';
function hs(v) { return v == null ? 'excluded*' : String(v); }

let md = '';
md += '# 25 - Weapon Stats Table (Pack-a-Punch form)\n\n';
md += '> **GENERATED FILE - do NOT hand-edit.** Regenerate with `node tools/gen_weapon_stats.js`\n';
md += '> after ANY gun retune (GDT ammo/damage, bal mult, box weight, PaP price tier, or claim cap).\n';
md += '> **Everything is parsed from code** (cannot drift): DEPLOYED GDT `_up` entries (raw/clip/ammo/\n';
md += '> locHead/fireTime) + `_acc_damage.gsc` (bal / global / headshot) + `_acc_pap_levels.gsc` (PaP tier\n';
md += '> ladder `pap_tier_mult` + per-gun price `pap_price_bucket`) + `_acc_map_randomizer.gsc`\n';
md += '> (`acc_box_weight` box odds + `acc_box_tactical_preroll` share + `wonder_cap_limit` claim caps).\n';
md += '> The generator self-checks (aborts on any unresolved GDT entry or a roster/code price mismatch).\n';
md += '> Base-form + full max-scale numbers: `node tools/audit_gun_damage.js`.\n\n';
md += '## Formula (verified from `_acc_damage.gsc::on_ai_damage`, ' + stamp + ')\n\n';
md += '```\n';
md += 'held-weapon raw damage  x  bal(acc_weapon_balance_mult)  x  global(' + GLOBAL + ')  x  papMult(tier)  x  headTemper\n';
md += 'PaP BODY (tier T) = round( rawDamage(_up)  x  bal  x  ' + GLOBAL + '  x  papMult(T) )\n';
md += 'HEADSHOT (tier T) = round( BODY  x  locHead x ' + HEAD_MULT + ' )      (locHead 5 -> x2.5;  Mahem locHead 4 -> x2.0;  shotguns headshot-EXCLUDED)\n';
md += 'RESERVE (rounds)  = ammoCountClipRelative ? clipSize x maxAmmo : maxAmmo  (clipRel 1: maxAmmo = MAGAZINE count; clipRel 0: maxAmmo = ABSOLUTE ROUNDS - the wonder weapons Blast-O-Matic _up / Thundergun)\n';
md += 'PaP tier ladder papMult:  T1 x' + PAP[1].toFixed(3) + '   T2 x' + PAP[2].toFixed(3) + '   T3 x' + PAP[3].toFixed(3) + '  (+33% / +67% / +100%)\n';
md += '```\n\n';
md += '- Every number below is the **PaP (`_up`) form**, read live from the deployed GDT. `raw`/`clip`/`maxAmmo`/`locHead` are exact GDT fields.\n';
md += '- **Tier / Score** = a single composite scored **entirely from the live PaP-form GDT stats + `bal`** (never a hand-typed number — so it can\'t drift on a retune), then ranked and split into **even thirds: A** (top third) **/ B** (middle) **/ C** (bottom). **DPS-dominant** (~1/3 of the score) with every other GDT stat as a weighted tiebreaker: sustain (reload/clip), reserve, mobility, recoil-control, ADS+swap handling, headshot mult, penetration, hip-accuracy, range. The **second letter is the PaP price tier** (TOP/MID/BOT — a *separate* system, docs/33). Launchers / energy-projectile specials are outside the formula → Tier `—`. Weights + bounds live at the top of `tools/gen_weapon_stats.js` (`SCORE_W`).\n';
md += '- **PaP cost T1/T2/T3** is the per-gun price by its tier (`_acc_pap_levels.gsc::pap_price_bucket` -> `tier_cost`): **WONDER** ' + PRICE_COST.WONDER + '  ·  **TOP** ' + PRICE_COST.TOP + '  ·  **MID** ' + PRICE_COST.MID + '  ·  **BOT** ' + PRICE_COST.BOT + '.\n';
const ARNIE_PCT = (100 * Math.min(...PR_CUTS) / PR_RANGE);            // 0.5%
const MONKEY_PCT = (100 * (TACTICAL_CUT - Math.min(...PR_CUTS)) / PR_RANGE);  // 1.0%
md += '- **Box %** = per-open mystery-box pull chance, parsed from `_acc_map_randomizer.gsc::acc_box_weight` (weight / pool-total ' + BOX_TOTAL + ' x gun-share ' + GUN_SHARE.toFixed(3) + ', i.e. after the Monkey Bomb ' + MONKEY_PCT.toFixed(1) + '% + Li\'l Arnie ' + ARNIE_PCT.toFixed(1) + '% fixed tactical pre-roll). This is the FRESH-pool chance; it re-normalizes UP live as you collect (owned guns drop out).\n';
md += '- **Body/Head columns** are the tier-ladder result (T1..T3). Shotguns are **per-pellet** (multiply x pellet count for a full point-blank hit) and **headshot-excluded** (`*`).\n';
md += '- **DPS** = max-PaP (T3) body damage per second, averaged over emptying a full clip plus one reload (so big clips and fast reloads both help; shell-loaders use their per-shell reload time, which flatters them slightly).\n';
md += '- **Move** = run speed while holding the gun (GDT `moveSpeedScale`; **×1 = full player speed**, e.g. ×0.95 = 5% slower). Read from the PaP `_up` entry.\n';
md += '- **Recoil (control)** = an at-a-glance rating of ADS **view-kick** severity: **🟢 Very Low → 🔴 Very High** (lower/greener = steadier, easier to control; red = wild). It buckets the total per-shot kick **↑+↔**: ≤60 🟢 Very Low · ≤90 🟢 Low · ≤120 🟡 Medium · ≤160 🟠 High · >160 🔴 Very High. The precise kick follows the dot — **↑** = vertical climb `(pitchMax+pitchMin)/2`, **↔** = horizontal shake `|yawMax−yawMin|/2`, in degrees (GDT `adsViewKick*`). All numbers **include the map\'s ×1.75 base-recoil "skill theme"** (`apply_recoil_overhaul.js`) and are **halved at runtime by Mega Deadshot** (the `recoil50` twin, ×0.5), which drops most guns ~1–2 tiers. Hip view-kick is ~identical, so ADS stands in for both.\n';
md += '- Layers NOT shown (stack on top at runtime): Cyberware Weapon Overclock (+10%/tier), Deadshot crit, Double Tap, boss per-hit cap ' + Math.round(BOSS_CAP * 100) + '% maxHP/hit, pellet/launcher/sniper vs-boss cuts.\n\n';

// Sectioned emission (user 2026-07-09): Wonders & specials FIRST, then one table per gun type
// (SECTION_ORDER), rows within each section sorted by box rarity (rarest pull first).
md += '## Wonders & specials (special damage models - no standard hitscan tier ladder)\n\n';
md += '- **Raw dmg** = the per-hit damage that matters for that weapon: GDT `meleeDamage` (melee) / `damage` (projectile), OR the script-driven number for wonders whose damage lives in GSC not the GDT — **Winter\'s Howl** = the freeze-cone `zombie_var` (inner/outer, point-blank→far-edge), **Fire Bow** = the TAP arrow\'s fixed impact blast (inner/outer). The pure fling (Thundergun) and per-enemy-fraction (Leviathan) models have no flat number (`—`) — see the **vs Boss** column + per-wonder notes.\n';
md += '- **Eff/hit** = the actual on-target damage of one hit where a number applies: raw x bal x global(' + GLOBAL + ') for the standard-damage specials (Blast-O-Matic), OR the script value for the freeze cone. **Winter\'s Howl** shows the PaP ladder (T0 base → T3, +50%/tier off the base cone; the cone is a weaponless DoDamage so it skips bal/global) — on top of that, Shielded x3 / Phantom x2 (boss-cap 10%/hit) / Glitch one-hit.\n';
md += '- **vs Boss** = how it behaves against heavyweight bosses (each wonder has its own boss rule, not the plain hitscan cap).\n\n';
md += '| Gun | Class | Box % | PaP cost T1/T2/T3 | Cap | Raw dmg | bal | Eff/hit | Clip / Reserve | fireTime | Move | vs Boss |\n';
md += '|---|---|--:|--|:--:|--:|--:|--:|--|--:|--:|---|\n';
for (const s of SPECIALS) {
  const bp = boxPct(s.box);
  const tier = priceTierFor(s.box);
  const cap = capForBox(s.box);
  const blk = gdtEntry(null, s.up);
  const gDmg = fieldNumSoft(blk, 'damage');
  const gMelee = fieldNumSoft(blk, 'meleeDamage');
  const gClip = fieldNumSoft(blk, 'clipSize');
  const gMags = fieldNumSoft(blk, 'maxAmmo');
  const gRel = fieldNumSoft(blk, 'ammoCountClipRelative');   // 0 -> maxAmmo IS rounds (Blast-O-Matic _up / Thundergun)
  const gFt = fieldNumSoft(blk, 'fireTime');
  const bal = balSoft(s.box);
  let rawStr, effStr;
  if (s.rawOverride != null) { rawStr = s.rawOverride; effStr = (s.effOverride != null ? s.effOverride : '—'); }   // script-driven damage the GDT doesn't carry (e.g. the freezegun's zombie_var cone)
  else if (s.perEnemy) { rawStr = '— (per-enemy)'; effStr = '—'; }            // Leviathan: health-fraction, no fixed number
  else if (s.kind === 'melee') { rawStr = (gMelee != null ? gMelee : '?') + ' melee'; effStr = (gMelee != null && bal != null) ? String(Math.round(gMelee * bal * GLOBAL)) : '—'; }
  else if (s.kind === 'proj') { rawStr = (gDmg != null ? String(gDmg) : '?'); effStr = (gDmg != null && bal != null) ? String(Math.round(gDmg * bal * GLOBAL)) : '—'; }
  else if (s.kind === 'knife') { rawStr = (gDmg != null ? gDmg : '?') + ' throw / ' + (gMelee != null ? gMelee : '?') + ' stab'; effStr = 'scripted'; }   // one-hit / deflect / boss-chip (see vs Boss)
  else if (s.kind === 'fling') { rawStr = '0 (fling)'; effStr = '—'; }
  else { rawStr = '0 (AoE)'; effStr = '—'; }
  let clipRes;
  if (gClip == null || gClip === 0) clipRes = '— / —';
  else if (gMags === 0) clipRes = gClip + ' / regen';
  else clipRes = gClip + ' / ' + (gRel === 0 ? gMags : gClip * gMags);   // clipRel 0 -> maxAmmo IS the reserve rounds
  let bossStr = s.boss;
  if (s.perEnemy) bossStr = 'hits-to-kill: zombie ' + LEVI_ENEMY.zombie + ' · glitch ' + LEVI_ENEMY.glitch + ' · shielded ' + LEVI_ENEMY.shield + '→' + LEVI_ENEMY_PAP2.shield + ' · Fury ' + LEVI_ENEMY.fury + '→' + LEVI_ENEMY_PAP2.fury + ' (→ = at 2nd PaP+) · **boss ' + LEVI_HITS.join('/') + '** (t0/T1/T2/T3)';
  if (s.knife) bossStr = 'capped CHIP only (never a delete): normal chain × throw ×' + BK_THROW_MULT + ' / stab ×' + BK_STAB_MULT + ' + the Exo melee layer (both attacks), then the ' + Math.round(BOSS_CAP * 100) + '% maxHP/hit cap (≥' + Math.round(1 / BOSS_CAP) + ' hits). The one-hit does NOT apply to bosses/mini-bosses/Fury.';
  const gMove = fieldNumSoft(blk, 'moveSpeedScale') || 1;
  md += `| **${s.d}** | ${s.cls} | ${bp.toFixed(2)}% | ${PRICE_COST[tier]} | ${cap == null ? '—' : cap + '/game'} | ${rawStr} | ${bal == null ? '—' : bal} | ${effStr} | ${clipRes} | ${gFt != null ? gFt + 's' : '—'} | ×${gMove} | ${bossStr} |\n`;
}
md += '\n**Per-wonder notes:**\n';
for (const s of SPECIALS) {
  let note = s.note;
  if (s.perEnemy) note = "WetEgg God of War melee (2026-07-07). **NO fixed damage number** - each hit deals a FRACTION of the target's max HP, so it kills in a set number of hits **configured per enemy**: normal zombie **" + LEVI_ENEMY.zombie + "** (a one-hit knife) · glitch **" + LEVI_ENEMY.glitch + "** · shielded **" + LEVI_ENEMY.shield + "** · Apothicon Fury **" + LEVI_ENEMY.fury + "** · heavyweight boss **" + LEVI_HITS.join('/') + "** by PaP tier (t0/T1/T2/T3). **At 2nd PaP and beyond (tier ≥ 2) the anti-elite counts sharpen: shielded " + LEVI_ENEMY.shield + "→**" + LEVI_ENEMY_PAP2.shield + "** and Apothicon Fury " + LEVI_ENEMY.fury + "→**" + LEVI_ENEMY_PAP2.fury + "** (one-shot).** Live dvars acc_leviathan_hits_{zombie,glitch,shield,shield_pap2,fury,fury_pap2,t0..t3}. Replaces the normal damage formula + boss cap for this weapon. **Swing speed also scales +10% per PaP tier** (user 2026-07-09): the spd twin axis swaps the axe to a faster GDT clone each tier (meleeTime 0.52 → 0.468/0.421/0.379, fireTime 0.48 → 0.432/0.389/0.35).";
  if (s.knife) note = "pmr360 pack over the STOCK-cooked t7 loot asset (box-only special, **not** claim-capped, TOP PaP price). Two attacks: a THROWN retrievable blade (stick → glow → walk-over pickup refills a knife; base 4 / PaP 9) AND its OWN melee stab (dedicated meleeAnim). **Damage is 100% SCRIPTED** (`_acc_damage.gsc`), so the GDT damage/meleeDamage only feed the boss-chip fall-through:\n" +
        "  - **regular + glitch zombies (INCLUDING the Glitch Stalker):** guaranteed **one-hit**, any round, throw or stab (glitch-first, Leviathan-consistent).\n" +
        "  - **Shielded / Riot elites:** **0 damage** — the blade deflects with a clang (even a maxed OC shield-pierce never gets through — intended hard wall).\n" +
        "  - **bosses / mini-bosses / Apothicon Fury:** normal multiplier chain with **throw ×" + BK_THROW_MULT + " / stab ×" + BK_STAB_MULT + "** (dvars acc_bk_throw_mult / acc_bk_stab_mult) **+ the Exo Suit melee layer on BOTH attacks**, backstopped by the " + Math.round(BOSS_CAP * 100) + "% per-hit boss cap = **capped chip** (≥" + Math.round(1 / BOSS_CAP) + " hits — NOT a boss-killer).\n" +
        "  - **PaP TIER 2 = the \"Krauss Refibrillator\":** stick (or land within ~128u of) a **DOWNED teammate** → **instant full revive** (jugg health, weapons restored, shooter credited, unlimited range). Base form never revives; tier 1 = damage bump only. Zero solo value (no revive target) — the CO-OP roll.\n" +
        "  - **Berzerker item:** the stab is a true melee → **BRZ badge** shows, connecting stabs pay the **5% max-HP blood tax**, and the implant grants **+35% stab speed** via the `_acc_brz` twins (`meleeTime` 0.65→0.48; throws untaxed / cadence unchanged).\n" +
        "  GDT ships `isBallisticKnife 0` (primary-slot projectile design) so the **name substring is the only live damage matcher**. Override `scripts/zm/_zm_weap_ballistic_knife.gsc` (needs the install `zm_patch.csv` dedupe). External pack — assets via `tools/external_assets_manifest.ps1`.";
  md += `- **${s.d}:** ${note}\n`;
}
// DERIVED wonder list (user 2026-07-12 "no misinfo"): the WONDER-tier specials, straight from pap_price_bucket,
// so adding/removing a wonder (Winter's Howl was the 5th) can never leave this count/list stale.
const WONDER_SPECIALS = SPECIALS.filter(s => priceTierFor(s.box) === 'WONDER').map(s => s.d);
md += '\n> **Claim cap** = max distinct players who may acquire that wonder per match (`_acc_map_randomizer::wonder_cap_limit`). The ' + WONDER_SPECIALS.length + ' wonders (' + WONDER_SPECIALS.join(' / ') + ') use the premium **WONDER** PaP tier (' + PRICE_COST.WONDER + '). ASM1 retired 2026-07-03 (removed from box + pools).\n';

// ---- gun sections: one table per type, rows rarest -> commonest -------------------------------
md += '\n## PaP-form gun stats (by type, rarest box pull first)\n\n';
// Readable recoil rating (user 2026-07-10 - "so I know what is bad or what is good"): bucket the total per-shot
// view-kick (vClimb + hShake, deg) into a 5-step control rating with a traffic-light dot, so steady (good) vs wild
// (bad) reads at a glance. Thresholds calibrated to the deployed roster - these degrees INCLUDE the x1.75 base
// scale (Mega Deadshot halves them at runtime, dropping most guns ~1-2 tiers).
const RECOIL_TIERS = [[60, '🟢 Very Low'], [90, '🟢 Low'], [120, '🟡 Medium'], [160, '🟠 High'], [Infinity, '🔴 Very High']];
function recoilCell(rc) {
  if (!rc) return '—';
  const k = rc.vClimb + rc.hShake;                       // total per-shot kick (deg): vertical climb + horizontal shake
  const label = RECOIL_TIERS.find(t => k <= t[0])[1];
  return `${label} · ↑${Math.round(rc.vClimb)} ↔${Math.round(rc.hShake)}`;
}
const GUN_TABLE_HEAD =
  '| Gun | Class | Tier | Score | Box % | PaP cost T1/T2/T3 | raw | bal | Clip | Reserve | Body T1/T2/T3 | Head T1/T2/T3 | fireTime | reload | Move | Recoil (control) | DPS |\n' +
  '|---|---|:--:|--:|--:|--|--:|--:|--:|--:|---|---|--:|--:|--:|:--|--:|\n';
for (const sec of SECTION_ORDER) {
  const secRows = rows.filter(r => r.sec === sec).sort((a, b) => a.box_pct - b.box_pct);
  if (!secRows.length) continue;
  md += '### ' + sec + '\n\n' + GUN_TABLE_HEAD;
  for (const r of secRows) {
    md += `| **${r.d}** | ${r.cls} | ${r.tier2 || '—'} / ${r.priceTier} | ${r.score2 != null ? r.score2.toFixed(2) : '-'} | ${r.box_pct.toFixed(2)}% | ${r.papCost} | ${r.raw} | ${r.bal} | ${r.clip} | ${r.reserve} | ${r.bodyT[1]} / ${r.bodyT[2]} / ${r.bodyT[3]}${r.pellet ? '/pel' : (r.shots ? '/bolt' : '')} | ${r.headT ? `${r.headT[1]} / ${r.headT[2]} / ${r.headT[3]}` : 'excluded*'} | ${r.fireTime}s | ${r.reload}s | ×${r.moveSpeed} | ${recoilCell(r.recoil)} | ${r.dpsT3}${r.pellet ? ' (×pel)' : (r.shots ? ` (×${r.shots} bolts)` : '')} |\n`;
  }
  md += '\n';
}
md += '`*` shotguns (Tac-19, Olympia, etc.): headshot-excluded; Body is **per pellet** (multiply x pellet count for a point-blank hit). GDT `_up` entry per gun: see the roster in `tools/gen_weapon_stats.js`.\n';
md += '\n> Mahem is a launcher: Body is the **direct** hit; locHead 4 -> headshot x2.0. It (and MORS at max PaP) exceed the **' + Math.round(BOSS_CAP * 100) + '% boss per-hit cap** - overkill on trash, capped vs bosses.\n';

// roster/section sanity: every gun must land in exactly one emitted section
const unsectioned = rows.filter(r => !SECTION_ORDER.includes(r.sec));
if (unsectioned.length) die('guns with no/unknown sec: ' + unsectioned.map(r => r.d).join(', '));

if (CHECK_ONLY) { console.log('[gen_weapon_stats] --check OK: all ' + rows.length + ' guns resolved + self-checked (no doc written).'); process.exit(0); }
fs.writeFileSync(OUT, md);
console.log('[gen_weapon_stats] wrote ' + OUT + ' (' + rows.length + ' guns, all GDT-verified + self-checked).');
// console echo for a quick eyeball
for (const r of rows) console.log(`  ${r.d.padEnd(13)} raw ${String(r.raw).padStart(4)}  bal ${r.bal}  clip ${String(r.clip).padStart(3)}/res ${String(r.reserve).padStart(3)}  bodyT3 ${r.bodyT[3]}  headT3 ${hs(r.headT ? r.headT[3] : null)}`);

// ---- TIER RANKING (live A/B/C, PaP-form, DPS-dominant, WITHIN each category) - redesign output ----
console.log('\n  ===== GUN TIER RANKING (PaP-form, live, per-category thirds) =====');
const two = (x) => x.toFixed(1).padStart(4);
for (const sec of SECTION_ORDER) {
  const grp = (bySec[sec] || []).slice().sort((a, b) => b.score2 - a.score2);
  if (!grp.length) continue;
  console.log(`\n  --- ${sec} ---   (rk tier gun / score | dps pwr sus rsv mob ctl hnd pen acc rng)`);
  for (const r of grp) {
    const s = r.sc;
    console.log(`  ${String(r.rankPos)}/${r.rankOf} ${r.tier2}  ${r.d.padEnd(14)} ${r.score2.toFixed(2)}  |${two(s.dps)}${two(s.power)}${two(s.sustain)}${two(s.reserve)}${two(s.mobility)}${two(s.control)}${two(s.handling)}${two(s.pen)}${two(s.accuracy)}${two(s.range)}`);
  }
}
console.log(`\n  (${scoreable.length} scoreable, tiered within category. Specials excluded: ${rows.filter(r=>r.special).map(r=>r.d).join(', ')})`);
