# 25 - Weapon Stats Table (Pack-a-Punch form)

> **GENERATED FILE - do NOT hand-edit.** Regenerate with `node tools/gen_weapon_stats.js`
> after ANY gun retune (GDT ammo/damage, bal mult, box weight, PaP price tier, or claim cap).
> **Everything is parsed from code** (cannot drift): DEPLOYED GDT `_up` entries (raw/clip/ammo/
> locHead/fireTime) + `_acc_damage.gsc` (bal / global / headshot) + `_acc_pap_levels.gsc` (PaP tier
> ladder `pap_tier_mult` + per-gun price `pap_price_bucket`) + `_acc_map_randomizer.gsc`
> (`acc_box_weight` box odds + `acc_box_tactical_preroll` share + `wonder_cap_limit` claim caps).
> The generator self-checks (aborts on any unresolved GDT entry or a roster/code price mismatch).
> Base-form + full max-scale numbers: `node tools/audit_gun_damage.js`.

## Formula (verified from `_acc_damage.gsc::on_ai_damage`, 2026-07-10)

```
held-weapon raw damage  x  bal(acc_weapon_balance_mult)  x  global(3.25)  x  papMult(tier)  x  headTemper
PaP BODY (tier T) = round( rawDamage(_up)  x  bal  x  3.25  x  papMult(T) )
HEADSHOT (tier T) = round( BODY  x  locHead x 0.5 )      (locHead 5 -> x2.5;  Mahem locHead 4 -> x2.0;  shotguns headshot-EXCLUDED)
RESERVE (rounds)  = clipSize x maxAmmo                                  (BO3 GDT maxAmmo = number of MAGAZINES)
PaP tier ladder papMult:  T1 x1.333   T2 x1.667   T3 x2.000  (+33% / +67% / +100%)
```

- Every number below is the **PaP (`_up`) form**, read live from the deployed GDT. `raw`/`clip`/`maxAmmo`/`locHead` are exact GDT fields.
- **PaP cost T1/T2/T3** is the per-gun price by its tier (`_acc_pap_levels.gsc::pap_price_bucket` -> `tier_cost`): **WONDER** 10000 / 15000 / 20000  ·  **TOP** 5000 / 7500 / 10000  ·  **MID** 4000 / 6000 / 8000  ·  **BOT** 3000 / 4500 / 6000.
- **Box %** = per-open mystery-box pull chance, parsed from `_acc_map_randomizer.gsc::acc_box_weight` (weight / pool-total 4364 x gun-share 0.985, i.e. after the Monkey Bomb 1.0% + Li'l Arnie 0.5% fixed tactical pre-roll). This is the FRESH-pool chance; it re-normalizes UP live as you collect (owned guns drop out).
- **Body/Head columns** are the tier-ladder result (T1..T3). Shotguns are **per-pellet** (multiply x pellet count for a full point-blank hit) and **headshot-excluded** (`*`).
- **DPS** = max-PaP (T3) body damage per second, averaged over emptying a full clip plus one reload (so big clips and fast reloads both help; shell-loaders use their per-shell reload time, which flatters them slightly).
- **Move** = run speed while holding the gun (GDT `moveSpeedScale`; **×1 = full player speed**, e.g. ×0.95 = 5% slower). Read from the PaP `_up` entry.
- Layers NOT shown (stack on top at runtime): Cyberware Weapon Overclock (+10%/tier), Deadshot crit, Double Tap, boss per-hit cap 5000, pellet/launcher/sniper vs-boss cuts.

## Wonders & specials (special damage models - no standard hitscan tier ladder)

- **Raw dmg** = the GDT field that matters for that weapon (melee -> `meleeDamage`, projectile -> `damage`; the fling/AoE wonders have GDT damage 0 and kill via a script effect).
- **Eff/hit** = raw x bal x global(3.25) = the actual on-target damage of one hit (before boss cap / PaP tier), where a standard damage number applies.
- **vs Boss** = how it behaves against heavyweight bosses (each wonder has its own boss rule, not the plain hitscan cap).

| Gun | Class | Box % | PaP cost T1/T2/T3 | Cap | Raw dmg | bal | Eff/hit | Clip / Reserve | fireTime | Move | vs Boss |
|---|---|--:|--|:--:|--:|--:|--:|--|--:|--:|---|
| **Thundergun** | Wonder (WW) | 0.29% | 10000 / 15000 / 20000 | 1/game | 0 (fling) | 0.45 | — | 4 / 24 | 0.95s | ×1 | maxHP-fraction blast (thundergun_boss_blast) |
| **Fire Bow** | Wonder (bow) | 0.29% | 10000 / 15000 / 20000 | 1/game | 0 (AoE) | 1 | — | 75 / regen | 0.45s | ×1 | Charged portal = DAMAGE-OVER-TIME zone (2026-07-08): zombies/elites frac×roundHP/s (1/5→1/2 by tier), BOSSES maxHP/div/s (÷80→÷40 by tier) + chompers. Furies: arrow hit = guaranteed one-shot. |
| **Leviathan Axe** | Wonder (melee) | 0.29% | 10000 / 15000 / 20000 | 1/game | — (per-enemy) | 1 | — | — / — | 0.48s | ×1.05 | hits-to-kill: zombie 1 · glitch 1 · shielded 4→2 · Fury 2→1 (→ = at 2nd PaP+) · **boss 17/14/12/8** (t0/T1/T2/T3) |
| **Blast-O-Matic** | Wonder (energy) | 0.29% | 10000 / 15000 / 20000 | 1/game | 3500 | 0.24 | 2730 | 20 / 120 | 0.16s | ×1 | x0.75 + 10% per-hit cap |
| **Action Figure** | Melee | 0.79% | 5000 / 7500 / 10000 | — | 5000 melee | — | — | — / — | 0.85s | ×1.05 | 1/30 maxHP/hit (~30 hits, acc_af_boss_hits) |

**Per-wonder notes:**
- **Thundergun:** GDT damage 0 - kills via the multiplier-immune wind FLING; bosses take a separate maxhealth-fraction blast.
- **Fire Bow:** HB21 Der Eisendrache fire (demon-gate) bow. TWO fire modes (charged portal REDESIGNED 2026-07-08 - DoT zone, not an instant blast):
  - **TAP (uncharged), 1 arrow:** fires one arrow - ~0 direct damage + a FIXED impact blast (GDT explosionInnerDamage 2233 / outer 1116, r96) and spawns 1 roaming chomper. One-shots trash at low/mid rounds, then FALLS OFF (the 2233 is fixed, never scales).
  - **HOLD (charged demon-gate), 3 arrows = the real weapon:** opens a portal that is a **DAMAGE-OVER-TIME zone** while its visual is live (~5s, 1s ticks, shooter-credited): **zombies + elites take `frac × current round zombie HP` per second** - frac **1/5 / 1/4 / 1/3 / 1/2** by PaP tier (tier-0 zombie in the void dies in ~5s; max tier ~2s) - and **BOSSES/mini-bosses take `their maxHP ÷ div` per second** - div **80 / 65 / 50 / 40** by tier. Plus auto-hunting **chompers** that instakill normal zombies. (The pack's original instant radiusDamage kill provably lands zero damage on this map - replaced by bow_demongate_portal_dot.)
  So: **normal zombies -> die in the void over seconds** (or instantly to chompers); **Apothicon Furies -> GUARANTEED one-shot on the ARROW hit** (dvar acc_firebow_fury_onehit; the DoT carries no weapon ref); **bosses -> a real DoT drain** (÷80..÷40 of their bar per second by tier) - still not a boss-killer (that's the Leviathan).
  **PaP-scaled (nerfed base):** blast **radius 50 / 65 / 80 / 95** (+15/tier) and **chompers 1 / 1 / 2 / 3** by tier (t0/T1/T2/T3; dvars acc_firebow_aoe_radius_t0..3 / acc_firebow_chompers_t0..3); DoT dvars acc_firebow_dot_frac_t0..3 / acc_firebow_dot_boss_div_t0..3; **DoT hits at most 20 enemies per tick** (acc_firebow_dot_max_targets). **Clip 30 -> 50 at 2nd PaP+** (acc_firebow_clip_t0..3). **Charged shot costs 3 arrows** (engine full-charge eats 2, the portal deducts 1 more post-fire - never touch the engine threshold dvar, it breaks full charge). DoT ticks ride the exact-damage side-channel (acc_tg_exact_dmg) so the global ×3.25 buff and the boss cap never rescale the spec fractions. bal 1.0. PaP = upgrade-in-place (CSV upgrade=self).
- **Leviathan Axe:** WetEgg God of War melee (2026-07-07). **NO fixed damage number** - each hit deals a FRACTION of the target's max HP, so it kills in a set number of hits **configured per enemy**: normal zombie **1** (a one-hit knife) · glitch **1** · shielded **4** · Apothicon Fury **2** · heavyweight boss **17/14/12/8** by PaP tier (t0/T1/T2/T3). **At 2nd PaP and beyond (tier ≥ 2) the anti-elite counts sharpen: shielded 4→**2** and Apothicon Fury 2→**1** (one-shot).** Live dvars acc_leviathan_hits_{zombie,glitch,shield,shield_pap2,fury,fury_pap2,t0..t3}. Replaces the normal damage formula + boss cap for this weapon. **Swing speed also scales +10% per PaP tier** (user 2026-07-09): the spd twin axis swaps the axe to a faster GDT clone each tier (meleeTime 0.52 → 0.468/0.421/0.379, fireTime 0.48 → 0.432/0.389/0.35).
- **Blast-O-Matic:** is_wonder_weapon energy blaster; -40% damage nerf (2026-07-03). Direct projectile, no splash.
- **Action Figure:** PaPs IN PLACE (no _up form); each tier adds +1 cleave target. bal = default (uncut).

> **Claim cap** = max distinct players who may acquire that wonder per match (`_acc_map_randomizer::wonder_cap_limit`). The 4 wonders (Thundergun / Fire Bow / Leviathan Axe / Blast-O-Matic) use the premium **WONDER** PaP tier (10000 / 15000 / 20000). ASM1 retired 2026-07-03 (removed from box + pools).

## PaP-form gun stats (by type, rarest box pull first)

### AR

| Gun | Class | Tier | Score | Box % | PaP cost T1/T2/T3 | raw | bal | Clip | Reserve | Body T1/T2/T3 | Head T1/T2/T3 | fireTime | reload | Move | DPS |
|---|---|:--:|--:|--:|--|--:|--:|--:|--:|---|---|--:|--:|--:|--:|
| **XM4** | AR | S / TOP | 7.86 | 1.17% | 5000 / 7500 / 10000 | 360 | 0.231 | 55 | 550 | 360 / 450 / 541 | 900 / 1125 / 1353 | 0.07s | 3s | ×0.95 | 4344 |
| **Havoc** | AR (energy, full-auto) | A / TOP | - | 1.20% | 5000 / 7500 / 10000 | 300 | 0.39797 | 40 | 320 | 517 / 647 / 776 | 776 / 971 / 1164 | 0.107s | 3.864s | ×0.95 | 3811 |
| **AK-47** | AR | S / TOP | 8.04 | 1.44% | 5000 / 7500 / 10000 | 300 | 0.29579 | 31 | 341 | 385 / 481 / 577 | 963 / 1203 / 1443 | 0.08s | 3.25s | ×0.95 | 3122 |
| **AE4** | AR | B / MID | 7.19 | 3.00% | 4000 / 6000 / 8000 | 290 | 0.341 | 38 | 304 | 429 / 536 / 643 | 1073 / 1340 / 1608 | 0.12s | 3s | ×0.95 | 3232 |
| **Grav** | AR | B+ / BOT | 6.85 | 8.53% | 3000 / 4500 / 6000 | 340 | 0.165 | 35 | 420 | 243 / 304 / 365 | 608 / 760 / 913 | 0.075s | 2.925s | ×0.95 | 2302 |

### Marksman & Sniper

| Gun | Class | Tier | Score | Box % | PaP cost T1/T2/T3 | raw | bal | Clip | Reserve | Body T1/T2/T3 | Head T1/T2/T3 | fireTime | reload | Move | DPS |
|---|---|:--:|--:|--:|--|--:|--:|--:|--:|---|---|--:|--:|--:|--:|
| **MORS** | Sniper | A / TOP | 7.50 | 2.44% | 5000 / 7500 / 10000 | 1500 | 0.25688 | 1 | 61 | 1670 / 2087 / 2505 | 4175 / 5218 / 6263 | 0.05s | 1.2s | ×0.95 | 2004 |
| **MK14** | DMR | B- / MID | 5.89 | 4.11% | 4000 / 6000 / 8000 | 600 | 0.28809 | 12 | 240 | 749 / 936 / 1124 | 1873 / 2340 / 2810 | 0.095s | 2s | ×0.95 | 4296 |
| **G7 Scout** | Marksman | C / BOT | 5.30 | 9.46% | 3000 / 4500 / 6000 | 190 | 0.5742 | 20 | 200 | 473 / 591 / 709 | 946 / 1182 / 1418 | 0.215s | 2.4s | ×0.95 | 2116 |

### Shotgun

| Gun | Class | Tier | Score | Box % | PaP cost T1/T2/T3 | raw | bal | Clip | Reserve | Body T1/T2/T3 | Head T1/T2/T3 | fireTime | reload | Move | DPS |
|---|---|:--:|--:|--:|--|--:|--:|--:|--:|---|---|--:|--:|--:|--:|
| **Peacekeeper** | Shotgun | S / TOP | 7.73 | 1.31% | 5000 / 7500 / 10000 | 340 | 0.41624 | 8 | 80 | 613 / 767 / 920/pel | excluded* | 0.16s | 2.5s | ×1 | 23365 (×pel) |
| **CEL-3** | Shotgun | B / TOP | 6.22 | 3.70% | 5000 / 7500 / 10000 | 200 | 0.432 | 12 | 96 | 374 / 468 / 562/pel | excluded* | 0.5s | 3s | ×1 | 8992 (×pel) |
| **Tac-19** | Shotgun | A- / MID | 6.80 | 4.56% | 4000 / 6000 / 8000 | 174 | 0.49929 | 6 | 54 | 376 / 471 / 565/pel | excluded* | 0.3s | 0.467s | ×1 | 17944 (×pel) |
| **Streetsweeper** | Shotgun | B / BOT | 6.20 | 6.23% | 3000 / 4500 / 6000 | 610 | 0.106392 | 14 | 126 | 281 / 352 / 422/pel | excluded* | 0.15s | 0.9s | ×1 | 23632 (×pel) |
| **Olympia** | Shotgun | C / BOT | 4.27 | 7.67% | 3000 / 4500 / 6000 | 260 | 0.41734 | 4 | 84 | 470 / 588 / 705/pel | excluded* | 0.283s | 1.75s | ×1 | 11742 (×pel) |

### SMG

| Gun | Class | Tier | Score | Box % | PaP cost T1/T2/T3 | raw | bal | Clip | Reserve | Body T1/T2/T3 | Head T1/T2/T3 | fireTime | reload | Move | DPS |
|---|---|:--:|--:|--:|--|--:|--:|--:|--:|---|---|--:|--:|--:|--:|
| **PPSH-41** | SMG | S / TOP | 8.04 | 1.78% | 5000 / 7500 / 10000 | 280 | 0.24475 | 60 | 540 | 297 / 371 / 445 | 743 / 928 / 1113 | 0.048s | 1.75s | ×1 | 5767 |
| **Alternator** | SMG (PaP power) | A / BOT | 7.20 | 2.71% | 3000 / 4500 / 6000 | 170 | 0.71874 | 30 | 360 | 529 / 662 / 794 | 1323 / 1655 / 1985 | 0.134s | 1.9s | ×1 | 4024 |
| **Prowler** | SMG | B / BOT | 6.43 | 5.06% | 3000 / 4500 / 6000 | 135 | 0.451 | 28 | 224 | 264 / 330 / 396 | 528 / 660 / 792 | 0.08s | 1.6s | ×1 | 2888 |
| **AK-74u** | SMG | A / MID | 7.03 | 5.62% | 4000 / 6000 / 8000 | 312 | 0.2024 | 40 | 280 | 274 / 342 / 410 | 685 / 855 / 1025 | 0.08s | 1.96s | ×1 | 3178 |

### LMG

| Gun | Class | Tier | Score | Box % | PaP cost T1/T2/T3 | raw | bal | Clip | Reserve | Body T1/T2/T3 | Head T1/T2/T3 | fireTime | reload | Move | DPS |
|---|---|:--:|--:|--:|--|--:|--:|--:|--:|---|---|--:|--:|--:|--:|
| **M60** | LMG | S / TOP | 8.11 | 1.60% | 5000 / 7500 / 10000 | 440 | 0.24926 | 120 | 600 | 475 / 594 / 713 | 1188 / 1485 / 1783 | 0.09s | 9.7s | ×0.9 | 4174 |
| **RPD** | LMG | C / MID | 6.10 | 6.93% | 4000 / 6000 / 8000 | 468 | 0.13213 | 125 | 625 | 268 / 335 / 402 | 670 / 838 / 1005 | 0.0696s | 7.5s | ×0.9 | 3102 |

### Pistol

| Gun | Class | Tier | Score | Box % | PaP cost T1/T2/T3 | raw | bal | Clip | Reserve | Body T1/T2/T3 | Head T1/T2/T3 | fireTime | reload | Move | DPS |
|---|---|:--:|--:|--:|--|--:|--:|--:|--:|---|---|--:|--:|--:|--:|
| **RW1** | Pistol | A+ / MID | 7.15 | 3.34% | 4000 / 6000 / 8000 | 1000 | 0.1452 | 12 | 96 | 629 / 786 / 944 | 1573 / 1965 / 2360 | 0.15s | 1.4s | ×1 | 3540 |
| **Five-Seven** | Pistol (start) | C- / BOT | 5.99 | 10.50% | 3000 / 4500 / 6000 | 455 | 0.27742 | 27 | 189 | 547 / 684 / 820 | 1368 / 1710 / 2050 | 0.08s | 1.8s | ×1 | 5591 |

### Launcher

| Gun | Class | Tier | Score | Box % | PaP cost T1/T2/T3 | raw | bal | Clip | Reserve | Body T1/T2/T3 | Head T1/T2/T3 | fireTime | reload | Move | DPS |
|---|---|:--:|--:|--:|--|--:|--:|--:|--:|---|---|--:|--:|--:|--:|
| **Mahem** | Launcher | - / TOP | - | 1.99% | 5000 / 7500 / 10000 | 7000 | 0.1099 | 10 | 40 | 3334 / 4167 / 5000 | 6668 / 8334 / 10000 | 0.4s | 3.5s | ×0.9 | 6667 |
| **War Machine** | Launcher | A / TOP | - | 2.19% | 5000 / 7500 / 10000 | 7000 | 0.0879 | 12 | 72 | 2666 / 3333 / 3999 | 5332 / 6666 / 7998 | 0.25s | 3.75s | ×0.9 | 7109 |

`*` shotguns (Tac-19, Olympia, etc.): headshot-excluded; Body is **per pellet** (multiply x pellet count for a point-blank hit). GDT `_up` entry per gun: see the roster in `tools/gen_weapon_stats.js`.

> Mahem is a launcher: Body is the **direct** hit; locHead 4 -> headshot x2.0. It (and MORS at max PaP) exceed the **10% boss per-hit cap** - overkill on trash, capped vs bosses.
