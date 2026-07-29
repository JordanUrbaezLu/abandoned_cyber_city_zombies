# 25 - Weapon Stats Table (Pack-a-Punch form)

> **GENERATED FILE - do NOT hand-edit.** Regenerate with `node tools/gen_weapon_stats.js`
> after ANY gun retune (GDT ammo/damage, bal mult, box weight, PaP price tier, or claim cap).
> **Everything is parsed from code** (cannot drift): DEPLOYED GDT `_up` entries (raw/clip/ammo/
> locHead/fireTime) + `_acc_damage.gsc` (bal / global / headshot) + `_acc_pap_levels.gsc` (PaP tier
> ladder `pap_tier_mult` + per-gun price `pap_price_bucket`) + `_acc_map_randomizer.gsc`
> (`acc_box_weight` box odds + `acc_box_tactical_preroll` share + `wonder_cap_limit` claim caps).
> The generator self-checks (aborts on any unresolved GDT entry or a roster/code price mismatch).
> Base-form + full max-scale numbers: `node tools/audit_gun_damage.js`.

## Formula (verified from `_acc_damage.gsc::on_ai_damage`, 2026-07-27)

```
held-weapon raw damage  x  bal(acc_weapon_balance_mult)  x  global(3.25)  x  papMult(tier)  x  headTemper
PaP BODY (tier T) = round( rawDamage(_up)  x  bal  x  3.25  x  papMult(T) )
HEADSHOT (tier T) = round( BODY  x  locHead x 0.5 )      (locHead 5 -> x2.5;  Mahem locHead 4 -> x2.0;  shotguns headshot-EXCLUDED)
RESERVE (rounds)  = ammoCountClipRelative ? clipSize x maxAmmo : maxAmmo  (clipRel 1: maxAmmo = MAGAZINE count; clipRel 0: maxAmmo = ABSOLUTE ROUNDS - the wonder weapons Blast-O-Matic _up / Thundergun)
PaP tier ladder papMult:  T1 x1.333   T2 x1.667   T3 x2.000  (+33% / +67% / +100%)
```

- Every number below is the **PaP (`_up`) form**, read live from the deployed GDT. `raw`/`clip`/`maxAmmo`/`locHead` are exact GDT fields.
- **Tier / Score** = a single composite scored **entirely from the live PaP-form GDT stats + `bal`** (never a hand-typed number — so it can't drift on a retune), then ranked and split into **even thirds: A** (top third) **/ B** (middle) **/ C** (bottom). **DPS-dominant** (~1/3 of the score) with every other GDT stat as a weighted tiebreaker: sustain (reload/clip), reserve, mobility, recoil-control, ADS+swap handling, headshot mult, penetration, hip-accuracy, range. The **second letter is the PaP price tier** (TOP/MID/BOT — a *separate* system, docs/33). Launchers / energy-projectile specials are outside the formula → Tier `—`. Weights + bounds live at the top of `tools/gen_weapon_stats.js` (`SCORE_W`).
- **PaP cost T1/T2/T3** is the per-gun price by its tier (`_acc_pap_levels.gsc::pap_price_bucket` -> `tier_cost`): **WONDER** 10000 / 15000 / 20000  ·  **TOP** 5000 / 7500 / 10000  ·  **MID** 4000 / 6000 / 8000  ·  **BOT** 3000 / 4500 / 6000.
- **Box %** = per-open mystery-box pull chance, parsed from `_acc_map_randomizer.gsc::acc_box_weight` (weight / pool-total 5173 x gun-share 0.985, i.e. after the Monkey Bomb 1.0% + Li'l Arnie 0.5% fixed tactical pre-roll). This is the FRESH-pool chance; it re-normalizes UP live as you collect (owned guns drop out).
- **Body/Head columns** are the tier-ladder result (T1..T3). Shotguns are **per-pellet** (multiply x pellet count for a full point-blank hit) and **headshot-excluded** (`*`).
- **DPS** = max-PaP (T3) body damage per second, averaged over emptying a full clip plus one reload (so big clips and fast reloads both help; shell-loaders use their per-shell reload time, which flatters them slightly).
- **Move** = run speed while holding the gun (GDT `moveSpeedScale`; **×1 = full player speed**, e.g. ×0.95 = 5% slower). Read from the PaP `_up` entry.
- **Recoil (control)** = an at-a-glance rating of ADS **view-kick** severity: **🟢 Very Low → 🔴 Very High** (lower/greener = steadier, easier to control; red = wild). It buckets the total per-shot kick **↑+↔**: ≤60 🟢 Very Low · ≤90 🟢 Low · ≤120 🟡 Medium · ≤160 🟠 High · >160 🔴 Very High. The precise kick follows the dot — **↑** = vertical climb `(pitchMax+pitchMin)/2`, **↔** = horizontal shake `|yawMax−yawMin|/2`, in degrees (GDT `adsViewKick*`). All numbers **include the map's ×1.75 base-recoil "skill theme"** (`apply_recoil_overhaul.js`) and are **halved at runtime by Mega Deadshot** (the `recoil50` twin, ×0.5), which drops most guns ~1–2 tiers. Hip view-kick is ~identical, so ADS stands in for both.
- Layers NOT shown (stack on top at runtime): Cyberware Weapon Overclock (+12%/tier, always-on gun damage), Deadshot crit, Double Tap (NOT a flat bonus - base is fire-rate only: the engine's free extra bullet nets ~1.86x DPS while a x0.7 per-hit cut offsets it; Mega "Gun Slinger" eases the cut to x0.9, ~2.39x DPS), boss per-hit cap 10% maxHP/hit, pellet/launcher/sniper vs-boss cuts.

## Wonders & specials (special damage models - no standard hitscan tier ladder)

- **Raw dmg** = the per-hit damage that matters for that weapon: GDT `meleeDamage` (melee) / `damage` (projectile), OR the script-driven number for wonders whose damage lives in GSC not the GDT — **Winter's Howl** = the freeze-cone `zombie_var` (inner/outer, point-blank→far-edge), **Fire Bow** = the TAP arrow's fixed impact blast (inner/outer). The pure fling (Thundergun) and per-enemy-fraction (Leviathan) models have no flat number (`—`) — see the **vs Boss** column + per-wonder notes.
- **Eff/hit** = the actual on-target damage of one hit where a number applies: raw x bal x global(3.25) for the standard-damage specials (Blast-O-Matic), OR the script value for the freeze cone. **Winter's Howl** shows the cone PaP ladder (T0 base → T3, +50%/tier off the base cone): the cone is a weaponless DoDamage, so it skips the per-gun **bal** reduction — but a player-attributed hit STILL takes the global x3.25 (weapon-agnostic), so the on-target number is ~3.25x the ladder value shown. On top of that: Shielded x3 / Phantom x2 (boss-cap 10%/hit) / Glitch one-hit.
- **vs Boss** = how it behaves against heavyweight bosses (each wonder has its own boss rule, not the plain hitscan cap).

| Gun | Class | Box % | PaP cost T1/T2/T3 | Cap | Raw dmg | bal | Eff/hit | Clip / Reserve | fireTime | Move | vs Boss |
|---|---|--:|--|:--:|--:|--:|--:|--|--:|--:|---|
| **Thundergun** | Wonder (WW) | 0.23% | 10000 / 15000 / 20000 | 1/game | 0 (fling) | 0.45 | — | 4 / 24 | 0.95s | ×0.86 | maxHP-fraction blast (thundergun_boss_blast) |
| **Fire Bow** | Wonder (bow) | 0.23% | 10000 / 15000 / 20000 | 1/game | TAP 2233/1116 blast | 0.585 | HOLD = DoT (see vs Boss) | 75 / regen | 0.45s | ×0.93 | Charged portal = DAMAGE-OVER-TIME zone (2026-07-08): zombies/elites frac×roundHP/s (frac 0.117→0.2925 by tier), BOSSES maxHP/div/s (÷137→÷69 by tier) + chompers. Furies: arrow hit = guaranteed one-shot. |
| **Leviathan Axe** | Wonder (melee) | 0.23% | 10000 / 15000 / 20000 | 1/game | — (per-enemy) | 1 | — | — / — | 0.594s | ×1.07 | hits-to-kill: zombie 1 · glitch 1 · shielded 4→2 · Fury 2→1 (→ = at 2nd PaP+) · **boss 24/20/18/14** (t0/T1/T2/T3) |
| **Blast-O-Matic** | Wonder (energy) | 0.23% | 10000 / 15000 / 20000 | 1/game | 3500 | 0.24 | 2730 | 20 / 110 | 0.16s | ×1 | x0.75 + 10% per-hit cap |
| **Action Figure** | Melee | 0.76% | 5000 / 7500 / 10000 | — | 5000 melee | — | — | — / — | 0.85s | ×1.07 | 1/33 maxHP/hit (~33 hits, acc_af_boss_hits) |
| **Winter's Howl** | Wonder (freeze) | 0.23% | 10000 / 15000 / 20000 | 1/game | 932/466 cone (in/out) | — | T0 932/466 · T3 2330/1165 (×3.25 global on top) | 12 / 108 | 0.08s | ×1.07 | 17.5% MOVE SLOW for 5s per hit (the headline UTILITY use; acc_freeze_boss_slow_rate 0.825 / _sec 5; a re-hit RESETS the timer, never stacks) - NOT a damage boss-killer (modest cone damage, 10% per-hit boss cap still backstops it; no iceover/shatter on bosses). |
| **Ballistic Knife** | Special (throw + stab) | 1.75% | 5000 / 7500 / 10000 | — | 1000 throw / 1000 stab | — | scripted | 1 / 9 | 0.5s | ×1 | capped CHIP only (never a delete): normal chain × throw ×6 / stab ×2 + the Exo melee layer (both attacks), then the 10% maxHP/hit cap (≥10 hits). The one-hit does NOT apply to bosses/mini-bosses/Fury. |
| **D13 Sector** | Wonder (disc) | 0.23% | 10000 / 15000 / 20000 | 1/game | 5000 | — | — | 3 / 30 | 0.3s | ×0.95 | normal multiplier chain (no bal cut) backstopped by the per-hit boss cap — a solid chip weapon, not a boss-deleter. |
| **Skull of Nan Sapwe** | Hero (beam + mesmerize) | 0.38% | — (no PaP) | 1/game | scripted beam (gib-chain ticks) | — | power-limited (gadget meter) | 100 / 30 | 1s | ×1 | beam ticks are target-health-sized weaponless DoDamage on up to 8 look-targets — the per-hit boss cap backstops bosses (VERIFY live); mesmerize (ADS) pacifies regular zombies only. |

**Per-wonder notes:**
- **Thundergun:** GDT damage 0 - kills via the multiplier-immune wind FLING; bosses take a separate maxhealth-fraction blast.
- **Fire Bow:** HB21 Der Eisendrache fire (demon-gate) bow. TWO fire modes (charged portal REDESIGNED 2026-07-08 - DoT zone, not an instant blast):
  - **TAP (uncharged), 1 arrow:** fires one arrow - ~0 direct damage + a FIXED impact blast (GDT explosionInnerDamage 2233 / outer 1116, r96) and spawns 1 roaming chomper. One-shots trash at low/mid rounds, then FALLS OFF (the 2233 is fixed, never scales).
  - **HOLD (charged demon-gate), 5 arrows = the real weapon:** opens a portal that is a **DAMAGE-OVER-TIME zone** while its visual is live (~5s, 1s ticks, shooter-credited): **zombies + elites take `frac × current round zombie HP` per second** - frac **0.117 / 0.1462 / 0.195 / 0.2925** by PaP tier (tier-0 zombie in the void dies in ~5s; max tier ~2s) - and **BOSSES/mini-bosses take `their maxHP ÷ div` per second** - div **137 / 111 / 86 / 69** by tier. Plus auto-hunting **chompers** that instakill normal zombies. (The pack's original instant radiusDamage kill provably lands zero damage on this map - replaced by bow_demongate_portal_dot.)
  So: **normal zombies -> die in the void over seconds** (or instantly to chompers); **Apothicon Furies -> GUARANTEED one-shot on the ARROW hit** (dvar acc_firebow_fury_onehit; the DoT carries no weapon ref); **bosses -> a real DoT drain** (÷137..÷69 of their bar per second by tier) - still not a boss-killer (that's the Leviathan).
  **PaP-scaled (nerfed base):** void **radius 110 / 140 / 170 / 200** (+30/tier; re-defaulted 2026-07-11 from the instant-blast-era 50/65/80/95 - log-proven unreachable for a DoT zone) and **chompers 1 / 1 / 2 / 3** by tier (t0/T1/T2/T3; dvars acc_firebow_aoe_radius_t0..3 / acc_firebow_chompers_t0..3) - the radius is a **HORIZONTAL ring** around the portal with a same-floor height window (acc_firebow_dot_zband, default 160; fixed 2026-07-11 - the old 3D check measured from the portal center ~64u up to zombie FEET, so tier 0/1 could never hit anything); **the void SLOWS normal zombies inside it** (demon-gate pull; ASMSetAnimationRate = the Widow's Wine mechanism, acc_firebow_void_slow_rate default 0.4, bosses exempt, watchdog-restored on exit) and **lives ~7s** (acc_firebow_void_tail_secs default 5.0, ~7 ticks); boss/mechz ticks use the pack's 8-arg MOD_PROJECTILE_SPLASH DoDamage (the bare 3-arg form was eaten by the mechz hitloc wrap); DoT dvars acc_firebow_dot_frac_t0..3 / acc_firebow_dot_boss_div_t0..3; **DoT hits at most 20 enemies per tick** (acc_firebow_dot_max_targets). **Clip 30 -> 50 at 2nd PaP+** (acc_firebow_clip_t0..3). **Charged shot costs 5 arrows** (engine full-charge eats 2, the portal deducts 3 more post-fire - never touch the engine threshold dvar, it breaks full charge). DoT ticks ride the exact-damage side-channel (acc_tg_exact_dmg) so the global ×3.25 buff and the boss cap never rescale the spec fractions. bal 0.585 (direct arrow / TAP hit; the DoT is exact-marked so it is exempt). PaP = upgrade-in-place (CSV upgrade=self).
  **CUSTOM CHARGE DETECTION (2026-07-11, 6th charge fix - script-owned, no longer trusts the engine):** the trigger HOLD TIME is measured in GSC (acc_firebow_hold_tracker/acc_firebow_fire_watcher); a hold >= **acc_firebow_charge_hold_ms** (default 1200) marks the arrow CHARGED and it opens the portal **whatever charge-level def the engine fired** - engine charge resets (the historical killers) can no longer eat the move. If the arrow's projectile_impact event never arrives (direct zombie-body hits), a shadow tracker opens the portal at the arrow's last origin; a 500ms per-shooter gate keeps it to one portal per arrow.
- **Leviathan Axe:** WetEgg God of War melee (2026-07-07). **NO fixed damage number** - each hit deals a FRACTION of the target's max HP, so it kills in a set number of hits **configured per enemy**: normal zombie **1** (a one-hit knife) · glitch **1** · shielded **4** · Apothicon Fury **2** · heavyweight boss **24/20/18/14** by PaP tier (t0/T1/T2/T3). **At 2nd PaP and beyond (tier ≥ 2) the anti-elite counts sharpen: shielded 4→**2** and Apothicon Fury 2→**1** (one-shot).** Live dvars acc_leviathan_hits_{zombie,glitch,shield,shield_pap2,fury,fury_pap2,t0..t3}. Replaces the normal damage formula + boss cap for this weapon. **Swing speed also scales +10% per PaP tier** (user 2026-07-09): the spd twin axis swaps the axe to a faster GDT clone each tier. **All 9 axe defs took a flat -8% swing-speed nerf 2026-07-17** (user; fireTime+meleeTime ×1.08 across base + spd + _brz twins, `tools/oneshots/gdt_leviathan_swing_nerf_0717.js`): meleeTime 0.5616 → 0.5054/0.4547/0.4093, fireTime 0.594 → 0.5378/0.4871/0.4417 (t0 → T1/T2/T3).
- **Blast-O-Matic:** is_wonder_weapon energy blaster; -40% damage nerf (2026-07-03). Direct projectile, no splash.
- **Action Figure:** PaPs IN PLACE (no _up form); each PaP tier scales SWING SPEED (fast1/2/3 twins); the old +1-cleave-target was REMOVED 2026-06-27. bal = default (uncut).
- **Winter's Howl:** GCPeinhardt 1:1 BO1 Winter's Howl port (booris models). A UTILITY wonder weapon - its focus is SLOWING, not damage. Fires a freeze CONE: progressive freeze that walks regular zombies to a crawl -> iceover -> SHATTER (authentic stock Winter's Howl; not a one-hit at higher rounds). ONE-HITS the Glitch Stalker (any freeze-cone hit kills it); SUPER-EFFECTIVE vs the Shielded "Riot" elite (x3, acc_freeze_vs_shielded); x2 vs the Phantom boss (acc_freeze_vs_phantom) - all with a freeze move-slow. BOSSES: 17.5%/5s move slow + capped damage (see vs Boss). Cone damage is a weaponless DoDamage from zombie_vars (BO1 stats: inner 932 / outer 466; upgraded 1398 / 699; use_t8_damage_set swaps to an alt set (1215/608, upgraded 2430/1215)) - NOT scaled by acc_weapon_balance_mult (weaponless), but a player hit STILL takes the global ×3.25 (weapon-agnostic), and the 10% per-hit boss cap still applies to bosses. The AI move-slow mirrors the Fire Bow void slow (a flag + ASMSetAnimationRate, honored by _acc_zombie_speed::under_anim_slow, watchdog restores rate 1.0 on expiry). projectileweapon _zm asset (script/CSV/box use the bare "freezegun"). Claim-capped 1/match (acc_cap_freezegun). PaP scales the freeze cone +50%/TIER (T0 x1 / T1 x1.5 / T2 x2 / T3 x2.5, off base vars 932/466 = point-blank 932->1398->1864->2330; acc_freeze_pap_per_tier) + tier-2 model transform (+ bigger range) + fastreload wonder twins + move 1.07. External rip - assets gitignored via the manifest. Combat logic: _zm_weap_freezegun.gsc [acc] block.
- **Ballistic Knife:** pmr360 pack over the STOCK-cooked t7 loot asset (box-only special, **not** claim-capped, TOP PaP price). Two attacks: a THROWN retrievable blade (stick → glow → walk-over pickup refills a knife; base 4 / PaP 9) AND its OWN melee stab (dedicated meleeAnim). **Damage is 100% SCRIPTED** (`_acc_damage.gsc`), so the GDT damage/meleeDamage only feed the boss-chip fall-through:
  - **glitch zombies (INCLUDING the Glitch Stalker):** guaranteed **one-hit at ANY round**, throw or stab (glitch-first, Leviathan-consistent).
  - **regular zombies:** one-hit only through round **12** (base) / round **24** (PaP) — ROUND-GATED (user 2026-07-12 "shouldn't be doing one hit the whole game", dvars acc_bk_onehit_round / _pap); past the gate the hit falls through to the scaled chain below (throw ×6 / stab ×2 + Exo melee layer).
  - **Shielded / Riot elites:** **0 damage** — the blade deflects with a clang (even a maxed OC shield-pierce never gets through — intended hard wall).
  - **bosses / mini-bosses / Apothicon Fury:** normal multiplier chain with **throw ×6 / stab ×2** (dvars acc_bk_throw_mult / acc_bk_stab_mult) **+ the Exo Suit melee layer on BOTH attacks**, backstopped by the 10% per-hit boss cap = **capped chip** (≥10 hits — NOT a boss-killer).
  - **PaP TIER 2 = the "Krauss Refibrillator":** stick (or land within ~128u of) a **DOWNED teammate** → **instant full revive** (jugg health, weapons restored, shooter credited, unlimited range). Base form never revives; tier 1 = damage bump only. Zero solo value (no revive target) — the CO-OP roll.
  - **Berzerker item:** the stab is a true melee → **BRZ badge** shows, connecting stabs pay the **5% max-HP blood tax**, and the implant grants **+35% stab speed** via the `_acc_brz` twins (`meleeTime` 0.65→0.48; throws untaxed / cadence unchanged).
  GDT ships `isBallisticKnife 0` (primary-slot projectile design) so the **name substring is the only live damage matcher**. Override `scripts/zm/_zm_weap_ballistic_knife.gsc` (needs the install `zm_patch.csv` dedupe). External pack — assets via `tools/external_assets_manifest.ps1`.
- **D13 Sector:** KOENTJE "Disk Gun" v1.0.1 port of the stock T7 loot **D13 Sector** (2026-07-24). Semi-auto launcher firing **ricocheting energy discs** (visible projectile + fx_trail_discgun; projExplosionType none = direct-hit damage, discs keep bouncing wall-to-wall after a hit). 3-disc clip, reserve is ABSOLUTE rounds (ammoCountClipRelative 0 — the Blast-O-Matic/Thundergun class). TRUE `_up` PaP form ships in the pack GDT (WONDER price tier); wonder fastreload twins = follow-up (freezegun generator is the template). Claim-capped 1/match (acc_cap_discgun). Sound CSV rebuilt install-side (16/18 pack wavs never shipped — fire rides an Apex B3 Wingman donor; see the manifest entry). External rip — assets gitignored via the manifest.
- **Skull of Nan Sapwe:** HB21 Hero Weapons v2.0.0 port of the ZNS **Skull of Nan Sapwe** (2026-07-24). HERO weapon: box roll gives it into the hero slot (Dpad), it runs on the **gadget power meter** (100), drains on use, recharges from kills — NO ammo economy, NO PaP, NO twins. **FIRE (hold) = death beam:** look-gated chain on up to 8 targets in 500u — regular zombies scream, head-gib, then explode into pieces (scene `cin_zm_dlc1_zombie_dth_deathray_04`); spiders die instantly; each tick costs power. **ADS (hold) = MESMERIZE torch:** pacifies regular zombies in 500u (they stop and dance the `pacified_by_skullgun` scenes) until the torch drops. [acc] CF surgery: beam/torch 1P fields ride **allplayers** (toplayer pool full) with a local-player guard; thrasher support stripped. Claim-capped 1/match (acc_cap_skullgun). Weapon def links from the tools DLC2 asset db; skull_gun_1 = the polished upgraded form (script-given, not PaP). External rip — assets gitignored via the manifest.

> **Claim cap** = max distinct players who may acquire that wonder per match (`_acc_map_randomizer::wonder_cap_limit`). The 6 wonders (Thundergun / Fire Bow / Leviathan Axe / Blast-O-Matic / Winter's Howl / D13 Sector) use the premium **WONDER** PaP tier (10000 / 15000 / 20000). ASM1 retired 2026-07-03 (removed from box + pools).

## PaP-form gun stats (by type, rarest box pull first)

### AR

| Gun | Class | Tier | Score | Box % | PaP cost T1/T2/T3 | raw | bal | Clip | Reserve | Body T1/T2/T3 | Head T1/T2/T3 | fireTime | reload | Move | Recoil (control) | DPS |
|---|---|:--:|--:|--:|--|--:|--:|--:|--:|---|---|--:|--:|--:|:--|--:|
| **Havoc** | AR (energy, full-auto) | — / TOP | - | 1.14% | 5000 / 7500 / 10000 | 300 | 0.340264 | 40 | 320 | 442 / 553 / 664 | 663 / 830 / 996 | 0.107s | 3.864s | ×0.93 | 🟡 Medium · ↑58 ↔50 | 3261 |
| **XM4** | AR | A / TOP | 6.14 | 1.22% | 5000 / 7500 / 10000 | 360 | 0.2079 | 55 | 550 | 324 / 405 / 486 | 810 / 1013 / 1215 | 0.07s | 3s | ×0.93 | 🔴 Very High · ↑70 ↔105 | 3902 |
| **AK-47** | AR | C / TOP | 5.69 | 1.50% | 5000 / 7500 / 10000 | 300 | 0.266211 | 31 | 341 | 346 / 433 / 519 | 865 / 1083 / 1298 | 0.08s | 3.25s | ×0.93 | 🟠 High · ↑26 ↔105 | 2808 |
| **AE4** | AR | A / MID | 5.87 | 4.46% | 4000 / 6000 / 8000 | 290 | 0.3069 | 38 | 304 | 386 / 482 / 579 | 965 / 1205 / 1448 | 0.12s | 3s | ×0.93 | 🟠 High · ↑26 ↔105 | 2910 |
| **Grav** | AR | B / BOT | 5.72 | 5.83% | 3000 / 4500 / 6000 | 340 | 0.165 | 35 | 420 | 243 / 304 / 365 | 608 / 760 / 913 | 0.075s | 2.925s | ×0.93 | 🟢 Low · ↑16 ↔64 | 2302 |

### Marksman & Sniper

| Gun | Class | Tier | Score | Box % | PaP cost T1/T2/T3 | raw | bal | Clip | Reserve | Body T1/T2/T3 | Head T1/T2/T3 | fireTime | reload | Move | Recoil (control) | DPS |
|---|---|:--:|--:|--:|--|--:|--:|--:|--:|---|---|--:|--:|--:|:--|--:|
| **MORS** | Sniper | C / TOP | 4.67 | 2.53% | 5000 / 7500 / 10000 | 1500 | 0.25688 | 1 | 61 | 1670 / 2087 / 2505 | 4175 / 5218 / 6263 | 0.05s | 1.2s | ×0.93 | 🟢 Low · ↑4 ↔83 | 2004 |
| **Triple Take** | Sniper (3-bolt volley) | A / MID | 7.19 | 4.74% | 4000 / 6000 / 8000 | 500 | 0.356571875 | 15 | 180 | 773 / 966 / 1159/bolt | 1933 / 2415 / 2898 | 0.110592s | 3.4s | ×0.93 | 🟠 High · ↑84 ↔44 | 10310 (×3 bolts) |
| **MK14** | DMR | B / BOT | 6.53 | 4.82% | 3000 / 4500 / 6000 | 600 | 0.28809 | 12 | 240 | 749 / 936 / 1124 | 1873 / 2340 / 2810 | 0.095s | 2s | ×0.93 | 🟡 Medium · ↑22 ↔89 | 4296 |

### Shotgun

| Gun | Class | Tier | Score | Box % | PaP cost T1/T2/T3 | raw | bal | Clip | Reserve | Body T1/T2/T3 | Head T1/T2/T3 | fireTime | reload | Move | Recoil (control) | DPS |
|---|---|:--:|--:|--:|--|--:|--:|--:|--:|---|---|--:|--:|--:|:--|--:|
| **Peacekeeper** | Shotgun | A / TOP | 7.30 | 1.35% | 5000 / 7500 / 10000 | 340 | 0.41624 | 8 | 80 | 613 / 767 / 920/pel | excluded* | 0.16s | 2.5s | ×1 | 🔴 Very High · ↑105 ↔60 | 23365 (×pel) |
| **CEL-3** | Shotgun | C / TOP | 5.87 | 4.65% | 5000 / 7500 / 10000 | 200 | 0.3888 | 12 | 96 | 337 / 421 / 505/pel | excluded* | 0.5s | 3.75s | ×1 | 🟡 Medium · ↑5 ↔95 | 7458 (×pel) |
| **Tac-19** | Shotgun | B / MID | 6.91 | 4.93% | 4000 / 6000 / 8000 | 174 | 0.49929 | 6 | 54 | 376 / 471 / 565/pel | excluded* | 0.3s | 0.467s | ×1 | 🔴 Very High · ↑123 ↔96 | 17944 (×pel) |
| **Streetsweeper** | Shotgun | A / BOT | 8.29 | 5.16% | 3000 / 4500 / 6000 | 610 | 0.106392 | 14 | 126 | 281 / 352 / 422/pel | excluded* | 0.15s | 0.675s | ×1 | 🟢 Very Low · ↑26 ↔0 | 25548 (×pel) |
| **Olympia** | Shotgun | B / BOT | 6.61 | 5.66% | 3000 / 4500 / 6000 | 260 | 0.41734 | 4 | 84 | 470 / 588 / 705/pel | excluded* | 0.283s | 1.75s | ×1 | 🟢 Low · ↑4 ↔83 | 11742 (×pel) |

### SMG

| Gun | Class | Tier | Score | Box % | PaP cost T1/T2/T3 | raw | bal | Clip | Reserve | Body T1/T2/T3 | Head T1/T2/T3 | fireTime | reload | Move | Recoil (control) | DPS |
|---|---|:--:|--:|--:|--|--:|--:|--:|--:|---|---|--:|--:|--:|:--|--:|
| **PPSH-41** | SMG | A / TOP | 7.52 | 1.85% | 5000 / 7500 / 10000 | 280 | 0.269225 | 60 | 540 | 327 / 408 / 490 | 818 / 1020 / 1225 | 0.048s | 1.575s | ×1 | 🟡 Medium · ↑13 ↔79 | 6599 |
| **Alternator** | SMG (PaP power) | C / BOT | 6.27 | 4.38% | 3000 / 4500 / 6000 | 170 | 0.646866 | 30 | 360 | 477 / 596 / 715 | 1193 / 1490 / 1788 | 0.134s | 1.9s | ×1 | 🟠 High · ↑26 ↔105 | 3623 |
| **AK-74u** | SMG | B / MID | 6.37 | 4.87% | 4000 / 6000 / 8000 | 312 | 0.22264 | 40 | 280 | 301 / 376 / 452 | 753 / 940 / 1130 | 0.08s | 1.764s | ×1 | 🟡 Medium · ↑22 ↔89 | 3642 |
| **Prowler** | SMG | A / BOT | 6.47 | 5.03% | 3000 / 4500 / 6000 | 135 | 0.54571 | 31 | 279 | 319 / 399 / 479 | 638 / 798 / 958 | 0.08s | 0.9s | ×1 | 🟢 Low · ↑18 ↔59 | 4393 |

### LMG

| Gun | Class | Tier | Score | Box % | PaP cost T1/T2/T3 | raw | bal | Clip | Reserve | Body T1/T2/T3 | Head T1/T2/T3 | fireTime | reload | Move | Recoil (control) | DPS |
|---|---|:--:|--:|--:|--|--:|--:|--:|--:|---|---|--:|--:|--:|:--|--:|
| **M60** | LMG | A / TOP | 6.61 | 1.66% | 5000 / 7500 / 10000 | 440 | 0.286649 | 120 | 600 | 547 / 683 / 820 | 1368 / 1708 / 2050 | 0.09s | 9.7s | ×0.86 | 🟡 Medium · ↑22 ↔96 | 4800 |
| **HAMR** | LMG | B / MID | 6.46 | 5.33% | 4000 / 6000 / 8000 | 390 | 0.208 | 100 | 500 | 352 / 439 / 527 | 880 / 1098 / 1318 | 0.08s | 6s | ×0.86 | 🟢 Low · ↑4 ↔83 | 3764 |
| **RPD** | LMG | C / MID | 5.72 | 5.48% | 4000 / 6000 / 8000 | 468 | 0.13213 | 125 | 625 | 268 / 335 / 402 | 670 / 838 / 1005 | 0.0696s | 7.5s | ×0.86 | 🟡 Medium · ↑13 ↔88 | 3102 |

### Pistol

| Gun | Class | Tier | Score | Box % | PaP cost T1/T2/T3 | raw | bal | Clip | Reserve | Body T1/T2/T3 | Head T1/T2/T3 | fireTime | reload | Move | Recoil (control) | DPS |
|---|---|:--:|--:|--:|--|--:|--:|--:|--:|---|---|--:|--:|--:|:--|--:|
| **RW1** | Pistol | B / MID | 6.56 | 4.55% | 4000 / 6000 / 8000 | 1000 | 0.15972 | 12 | 96 | 692 / 865 / 1038 | 1730 / 2163 / 2595 | 0.15s | 1.4s | ×1.07 | 🟢 Low · ↑4 ↔83 | 3893 |
| **Five-Seven** | Pistol (start) | A / BOT | 7.27 | 5.94% | 3000 / 4500 / 6000 | 455 | 0.27742 | 27 | 189 | 547 / 684 / 820 | 1368 / 1710 / 2050 | 0.08s | 1.8s | ×1.07 | 🟢 Low · ↑4 ↔83 | 5591 |

### Launcher

| Gun | Class | Tier | Score | Box % | PaP cost T1/T2/T3 | raw | bal | Clip | Reserve | Body T1/T2/T3 | Head T1/T2/T3 | fireTime | reload | Move | Recoil (control) | DPS |
|---|---|:--:|--:|--:|--|--:|--:|--:|--:|---|---|--:|--:|--:|:--|--:|
| **Mahem** | Launcher | — / TOP | - | 2.06% | 5000 / 7500 / 10000 | 7000 | 0.1099 | 8 | 24 | 3334 / 4167 / 5000 | 6668 / 8334 / 10000 | 0.4s | 3.5s | ×0.86 | 🟢 Low · ↑48 ↔25 | 5970 |
| **War Machine** | Launcher | — / TOP | - | 2.28% | 5000 / 7500 / 10000 | 7000 | 0.10636 | 12 | 72 | 3226 / 4033 / 4839 | 6452 / 8066 / 9678 | 0.25s | 3.75s | ×0.86 | 🟢 Low · ↑48 ↔25 | 8603 |
| **EPG-1** | Launcher | — / TOP | - | 2.44% | 5000 / 7500 / 10000 | 900 | 0.68 | 9 | 108 | 2652 / 3315 / 3978 | 5304 / 6630 / 7956 | 0.4s | 0.833s | ×1 | 🟢 Low · ↑48 ↔25 | 8076 |

`*` shotguns (Tac-19, Olympia, etc.): headshot-excluded; Body is **per pellet** (multiply x pellet count for a point-blank hit). GDT `_up` entry per gun: see the roster in `tools/gen_weapon_stats.js`.

> Mahem is a launcher: Body is the **direct** hit; locHead 4 -> headshot x2.0. It (and MORS at max PaP) exceed the **10% boss per-hit cap** - overkill on trash, capped vs bosses.
