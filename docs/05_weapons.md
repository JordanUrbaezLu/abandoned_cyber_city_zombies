# 05 - Weapons

The arsenal, the Overclock system, custom perks, and the wonder weapon candidates. Most of the within-run replayability weight lives here because Overclocks randomize per run.

> **⚠️ ARSENAL = BOX ONLY (user; box list authoritative in `_acc_map_randomizer::register_mystery_box_pool`).**
> No wall buys (all removed at load by `remove_all_wallbuys()`); every gun comes from the Mystery
> Box, which clears `is_in_box` on the whole stock CSV roster and re-enables only the chosen set.
> **Current box (17 guns):** Five-Seven `t6_fiveseven` (also the starting pistol), ASM1 `s1_asm1`,
> Tac-19 `s1_tac19`, AK-47 `t6_ak47`, AE4 `s1_ae4`, Ripper `iw6_ripper_smg`, PPSH-41 `s4_ppsh41_base`,
> AK-74u `t5_ak74u`, PDW-57 `s1_pdw`, Nail Gun `t9_nail_gun`, Paladin HB50 `t8_paladin_hb50`, M1911
> `s2_m1911`, Olympia `t6_olympia`, Galil `t6_galil`, M60 `t6_m60`, RPD `t6_rpd`, and the Wunderwaffe
> DG-2 `tesla_gun` (stock wonder weapon, `is_limited=1`). **See the [Gun Tier List](#gun-tier-list-design-intent)
> below for each gun's tier, stats, ability, and rationale — that's the canonical roster.** Per-gun
> damage balance lives in `_acc_damage::acc_weapon_balance_mult` (tier-tagged return lines). PDW / M1911
> (akimbo PaP), Nail Gun (projectile), the LMGs, and the convertible Ripper have NO perk twins. The
> 16-weapon table further down is the older *aspirational design spec*, not the live box.
>
> **Ammo economy (2026-06-16).** Every box gun runs a global **30% ammo cut** baked by
> `tools/reduce_base_ammo.js` (FACTOR 0.70). In the Skye GDTs `maxAmmo`/`startAmmo` are reserve
> **magazine** counts, so **in-game reserve rounds = `maxAmmo × clipSize`**; cutting `clipSize`
> ×0.70 drops both the mag and the reserve by 30% in one edit. Two special cases: **Olympia**
> (double-barrel, `clipSize 2` floor) takes its 30% off `maxAmmo` instead (clip stays 2); the
> **PDW akimbo-PaP** shipped a broken `maxAmmo 920` (Skye data error, clamped to 18 ≈ 306 reserve).
> Approx live reserves — autos ~130-225 base / ~280-420 PaP; shotguns/snipers/pistols ~26-84 (low
> by design). Tune in that one tool; re-run + `gdtdb /update` + linker.

Enemies are in a separate doc: [11_enemies.md](11_enemies.md).

## Gun Tier List (multi-factor)

**A gun's tier is COMPUTED from all its stats by the scoring formula below — not from DPS alone.** Each gun
gets a 0–10 **composite score** = the weighted sum of six factor scores; the score maps to an S/A/B/C tier.
To move a gun's tier, change the stat(s) that matter (DPS via `acc_weapon_balance_mult`; clip/reserve/reload via
`tools/reduce_base_ammo.js`; recoil via `apply_recoil_overhaul.js`) and recompute. *(Formula v2 + scores last synced
2026-06-21.)*

### Scoring formula (v2 — "sustain" model)

Composite (0–10) = Σ (factor score × weight). Re-weight here if priorities shift, then recompute the table.

| Factor | Weight | Score scale (→ 1–10) | Notes |
|---|--:|---|---|
| **Effective DPS** | **30%** | per-shot guns judged on horde-kill potential; autos **340 → 1 … 664 → 10** (steeper, so weak-DPS guns can't free-ride on handling) | output — dominant, not everything |
| **Mobility** | **16%** | `moveSpeedScale` 0.80 → 4 … 1.00 → 10 | kiting trains; mainly an LMG penalty (most guns sit at 1.0) |
| **Sustain (uptime)** | **18%** | **effective reload = reloadEmpty ÷ clip**, log-scaled (~0.05 s/round → 10 … ~2.0 → 1) | **THIS is how clip is rewarded** — a big clip means you reload far less often, so it *shrinks* the reload cost. Built-in diminishing returns (doubling clip only halves an already-small per-round cost). Folds the old separate reload + clip factors into one. |
| **Penetration** | **14%** | none 2 · small 4 · medium 7 · large 10 | pierces a zombie *train* |
| **Reserve** | **14%** | **LOG-scaled**: ~26 → 1.5 … ~400 → 10 | rewards an exceptional reserve with diminishing returns |
| **Handling** | **8%** | full-auto / charge 8 · sniper 6 · semi-pistol / single-shotgun 5 | fire-type + range + accuracy |

**Thresholds:** S ≥ 7.7 · A 6.6–7.69 · B 5.6–6.59 · C < 5.6. Sub-tiers (+/−) split each band into thirds.

**Two special rules** layered on top of the score:
- **Snipers are scored on single-target DPS, not chaff** (a one-shot boss-killer's "DPS" is its single-target output). That's why Paladin can reach S despite a small clip — its single-target power is elite. Without this, the horde-weighted formula would bury all snipers in B.
- **Pellet shotguns (Tac-19, Olympia) take a separate BOSS-damage cut** (`ACC_SHOTGUN_BOSS_MULT` in `_acc_damage.gsc`, default ×0.25). Their 8 pellets all land on a boss's single hitbox → ~8× stacked damage. This cut only applies *vs bosses/mini-bosses* — it doesn't change their chaff tier (Tac-19 stays the chaff king) but stops the boss-nuke. **This is a damage rule, not a tier-score factor.**

> **Model + curation history (user, 2026-06-21):** the formula is "v2 sustain" — clip is rewarded *through* reload
> (a big clip = you reload rarely), reserve is log-scaled. On top, the user hand-set several sub-tiers and the stats
> were tuned to match: M60 **S** (DPS↓, clip 100/reserve 400), Paladin **low S** (clip 4→8 + single-target scoring),
> PPSH **A+**, Galil **B+**, Five-Seven **C**, AE4/AK-47 **A**, Olympia **C**. Tac-19 got the boss-damage cut.

### Tier ranking — BASE guns (out of the box, no PaP)

How good the gun is *when you roll it* — the box-roll quality.

| Tier | Score | Gun | Class | Eff DPS | Clip | Reserve | Reload | Move | Pen | Key drivers |
|---|--:|---|---|--:|--:|--:|--:|--:|---|---|
| **S** | 7.9 | Nail Gun | AR (proj) | ~589 | 40 | 280 | 2.0s | 1.0 | none | Best sustain in the game (fast reload + 40 clip). |
| **S** | 7.9 | M60 | LMG | ~580 | **100** | **400** | 9.7s | 0.8 | large | DPS traded down for a 100-clip + 400 reserve; the huge mag makes the 9.7s reload trivial. |
| **low S** | 7.7 | Paladin HB50 | Sniper | ~700/shot | **8** | 96 | 4.1s | 1.0 | large | One-shot boss-killer (scored on single-target DPS) + clip 4→8 + pierce. |
| **S** | — | Wunderwaffe DG-2 | Wonder | chain lightning | — | recharge | — | — | — | Outside the formula; `is_limited=1`. |
| **A+** | 7.5 | Tac-19 | Shotgun | crowd king | **3** | **27** | **0.47s** | 1.0 | large | **Nerfed** (user 2026-06-21): damage −9% + clip 4→3 + reserve →27 → dropped out of S to A+. Still chaff-strong; **boss damage also cut** (see below). |
| **A+** | 7.4 | PPSH-41 | SMG | ~492 | 30 | 270 | 3.5s | 1.0 | med | DPS dropped from S; massive clip + RoF keep it top-A. |
| **A** | 7.4 | AK-74u | SMG | ~518 | 20 | 160 | 2.8s | 1.0 | med | Fast, mobile, good sustain. |
| **A** | 7.1 | Ripper | SMG⇄AR | ~AK band | 22 | 220 | ~2.5s | 1.0 | med | Convertible flexibility + good reserve. |
| **A-** | 6.8 | AE4 | AR (energy) | ~413 | 25 | 200 | 2.0s | 1.0 | med | Mid DPS, but fast reload + pierce + clip + reserve = A-grade kit. |
| **A-** | 6.7 | AK-47 | AR | ~465 | 21 | 168 | 3.25s | 0.95 | med | Solid DPS + decent sustain. |
| **B+** | 6.5 | ASM1 | SMG | ~401 | 22 | 132 | 2.1s | 1.0 | med | Low DPS saved by fast reload + clip + pierce. |
| **B+** | 6.5 | Galil | AR | ~412 | 25 | 225 | 2.9s | 0.95 | med | DPS cut from A to the top of B. |
| **C** | 5.5 | RPD | LMG | ~337 | 60 | 240 | 7.5s | 0.8 | large | Big clip can't save low DPS + slow move. The "bad LMG". |
| **C** | 5.5 | Five-Seven | Pistol (start) | ~52/shot | 14 | **56** | 1.8s | 1.0 | small | Weak starter; reserve cut to land it at C. |
| **C** | 5.2 | M1911 | Pistol | ~70/shot | 6 | 60 | 1.85s | 1.0 | small | Weak base — its value is the **PaP** (see the PaP list). |
| **C** | 5.2 | PDW-57 | SMG | ~330 | 11 | 132 | 2.1s | 1.0 | small | Hard DPS cut + small clip/pierce. |
| **C** | 4.8 | Olympia | Shotgun | 110×8 | 2 | 26 | 3.9s | 1.0 | small | 2-round clip = worst sustain in the game. Headshot-excluded. |

### Tier ranking — FULLY PACK-A-PUNCHED (T3)

How good the gun is *at its ceiling*, after full PaP — which guns are worth maxing. PaP scales DPS ~×2.5
uniformly (so the DPS order barely moves); the reshuffle vs base comes from **bigger PaP clips/reserves**
(better sustain) and the **transform guns leaping up** — M1911 → explosive akimbo, PDW / Five-Seven → akimbo.

| Tier | Score | Gun | PaP clip | PaP reserve | What PaP does |
|---|--:|---|--:|--:|---|
| **S** | 8.1 | Tac-19 | **6** | **54** | Chaff ceiling (nerf dropped it S+→S; boss damage still cut). |
| **S** | 8.1 | Nail Gun | 50 | 400 | Bigger nail + huge sustain. |
| **S** | 8.0 | Paladin HB50 | 11 | 132 | 11-round one-shot sniper. |
| **low S** | 8.0 | M60 | 120 | 480 | 120-clip belt — never stops firing. |
| **low S** | 7.9 | AK-74u | 40 | 280 | — |
| **low S** | 7.8 | PPSH-41 | 44 | 396 | — |
| **low S** | 7.7 | **PDW-57** | 17 | 306 | **→ akimbo + separate higher mult** (user 2026-06-21): base C → **bottom S** packed. |
| **A+** | 7.5 | Ripper | 34 | 340 | Both modes packed. |
| **A** | 7.2 | AE4 | 38 | 304 | — |
| **A** | 7.1 | **M1911** | 8 | 80 | **→ akimbo EXPLOSIVE nuke** (base C → A). The biggest PaP jump. |
| **A** | 7.0 | AK-47 | 31 | 279 | — |
| **A** | 7.0 | **Five-Seven** | 21 | 462 | **→ akimbo** (base C → A). |
| **A** | 7.0 | ASM1 | 36 | 288 | — |
| **A-** | 6.9 | Galil | 35 | 420 | — |
| **B** | 6.0 | RPD | 100 | 400 | Big belt, but low DPS ceiling. |
| **C** | 5.0 | Olympia | 2 | 42 | 2-round clip — PaP can't fix the sustain. |

> **Reading the two lists:** the base list is your *roll quality*; the PaP list is your *investment ceiling*.
> The transform akimbo guns jump hardest when packed — **PDW C → bottom S**, **M1911 C → A** (explosive),
> **Five-Seven C → A** — so they're "bad roll, great if you commit." **Olympia stays C even maxed** (the 2-round
> clip caps it). **Tac-19** was nerfed to **A+ base / S packed**, with its boss damage deliberately cut
> (`ACC_SHOTGUN_BOSS_MULT`, below).

¹ Five-Seven / PDW / M1911 PaP forms are akimbo — PaP reserve shown is the combined `_rdw` form.

**Tier philosophy:** **S** = the roll you celebrate. **A** = strong, very desirable. **B** = reliable mid-tier.
**C** = the "bad roll" / budget fallback. A fully-upgraded C gun can still out-DPS a base A gun — tiers are about
*base feel and roll excitement*, not an absolute power ceiling.

## Roster Structure (v1.0)

Each primary-weapon category has **three tiers**:

- **Normal** - reliable, wallbuy-placed, predictable access.
- **Bad** - box-only, weaker or more awkward than the normal tier; a "bad roll" when you hit the box.
- **Strong** - box-only, iconic / premium; the roll you're hoping for.

Plus: 1 starting pistol, 1 melee upgrade (wallbuy), 1 lethal grenade (starting), 1 tactical grenade (wallbuy).

Four categories x three tiers + four utility slots = **16 weapons** in v1.0.

## The 16-Weapon Roster

| # | Weapon | Category | Tier | Source | Placement |
|---|---|---|---|---|---|
| 1 | **B23R** | Pistol | Starter | Import (MW series) | Spawn loadout |
| 2 | **Haymaker 12** | Shotgun | Normal | Stock BO3 | Wallbuy (Alley) |
| 3 | **Brecci** | Shotgun | Bad | Stock BO3 | Mystery Box only |
| 4 | **Tac-19** | Shotgun | Strong | Import (Advanced Warfare) | Mystery Box only |
| 5 | **ICR-1** | AR full-auto | Normal | Stock BO3 | Wallbuy (Bus Station) |
| 6 | **XR-2** | AR full-auto | Bad | Stock BO3 | Mystery Box only |
| 7 | **AK-47** | AR full-auto | Strong | Import | Mystery Box only |
| 8 | **M14 EBR** | Semi-auto AR | Normal | Import (MW2) | Wallbuy (Bus Station) |
| 9 | **G3** | Semi-auto AR | Bad | Import (WAW) | Mystery Box only |
| 10 | **FN FAL** | Semi-auto AR | Strong | Import (BO1 / BO2) | Mystery Box only |
| 11 | **Intervention** | Sniper | Normal | Import (MW2) | Wallbuy (Helipad) |
| 12 | **Locus** | Sniper | Bad | Stock BO3 | Mystery Box only |
| 13 | **Drakon** | Sniper | Strong | Stock BO3 | Mystery Box only |
| 14 | **Bowie Knife** | Melee upgrade | - | Stock BO3 | Wallbuy (near perk) |
| 15 | **Frag Grenade** | Lethal grenade | Starter | Stock BO3 | Spawn loadout |
| 16 | **EMP Grenade** | Tactical grenade | - | Custom (authored) | Wallbuy (Vault) |

**Import / custom count**: 7 imports + 1 custom = 8 non-stock weapons. The other 8 are stock BO3.

## Design Logic

### Why three tiers per category

- **Normal tier (wallbuy)** gives every category a reliable access point. Skilled players can commit to a specialty (shotgun main, sniper main) without being held hostage by the Mystery Box.
- **Bad tier (box)** creates real "bad roll" moments. If the box lands on a Brecci or XR-2, you either burn another 950 on the box or make it work. This preserves the gamble tension that makes the box fun. Without a "bad" tier, box rolls start to feel samey.
- **Strong tier (box)** is the jackpot. Iconic CoD guns the player *wants* to roll. Finding a FAL or Intervention is a moment.

### Pattern rationale

Shotgun fans always buy Haymaker 12 on wallbuy. They also *hope* the box rolls a Tac-19. They *groan* if it rolls a Brecci. That emotional range across a single category is what a good box does. Three tiers execute that cleanly.

### Category coverage: no SMG, no LMG

v1.0 intentionally ships with only **shotgun, AR full-auto, semi-auto AR, sniper** primary categories. Skipped:

- **SMG** - Reflex archetype leans on shotgun + Phase Step instead. Kuda-class SMGs are a post-1.0 add.
- **LMG** - **ADDED 2026-06-19: M60 (`t6_m60`) + RPD (`t6_rpd`)**, both Skye BO2 ports (the only two Skye LMGs
  with compiled models - Stoner63/HK21/etc. have uncompiled xmodels, see memory `skye-lmg-ports-uncompiled`).
  Box-only, twin-less. Balanced **M60 0.20 (~580, S) / RPD 0.10 (~337, C)** in `_acc_damage` (per the 2026-06-21
  tier-curation pass: M60 → S, RPD → C "the bad LMG"; see CHANGELOG and the tier table above). **Ammo cut hard** (user 2026-06-19, was wildly over): clip 60 / reserve
  **240** base, clip 100 / reserve **400** PaP (reserve bumped 2026-06-21 from 180/300 — user wanted ~25% more;
  reserve = `maxAmmo` mags × clipSize is quantized to whole mags, so 3→4 mags = +33%, the closest step) via
  `reduce_base_ammo.js` `MAXAMMO_FIX` 4 + CLIP_FIX → gdtdb → relink. Diverse: M60 heavy/slow (600 RPM), RPD faster (750 RPM). Sounds
  authored via `gen_box_weapon_sounds.js` (Skye ships the wavs, not the aliases). The dormant LMG Overclock
  family is now ACTIVE (`lmg_list`).
- **SMG** - Reflex archetype leans on shotgun + Phase Step instead. Kuda-class SMGs are a post-1.0 add.
- **WONDER WEAPON** - **ADDED 2026-06-19: Wunderwaffe DG-2 (`tesla_gun`)** in the mystery box at uniform odds
  (user pick from the 4 stock no-download options — see the "Wonder Weapons" section below + CHANGELOG). Chain
  lightning, `is_limited`=1 (one in the world at a time). Stock cooked weapon → no `.zone` line, no model
  compile, no custom sounds/balance; added via a row in our slim weapon-table CSV + one line in the box pool.
  NOTE the BO3 box has no rarity weighting, so it rolls ~1/N like any box gun.

Impact on Overclock pools:
- The **LMG** Overclock family is now active (M60 + RPD). The **SMG** family is still defined in
  `_acc_overclocks.gsc::build_family_pools()` but has no weapons classified into it (dormant, post-1.0).

## Per-Weapon Detail

### Starter Pistol

**1. B23R** - 3-round burst pistol (Beretta 93R-style). Import from MW2 / MW3. Replaces stock M1911 as starting weapon. Burst-fire is a skill weapon in round 1-3 - tap for single bursts, sweep for panic clears. PaP placeholder: **"B23R Triple Threat"**. Import notes: community ports exist from MW2/MW3. Author GDT at `weapons/zm/sp/b23r_zm.gdt` patterned on stock pistol GDTs.

### Shotgun Category

**2. Haymaker 12 (normal, wallbuy)** - stock BO3 automatic shotgun. 1500 wallbuy at Alley. Reliable, forgiving, auto-fire for panic moments. PaP: "Haymaker 12 Hades". Overclock family: shotgun.

**3. Brecci (bad, box)** - stock BO3 semi-auto pump shotgun, lower per-shot damage than Haymaker, awkward cone. "I spent 950 points for THIS?" energy. Exists as a designed bad-roll. PaP: "Fully Brecci'd". Overclock family: shotgun (you'll want Spread Cone if you get it).

**4. Tac-19 (strong, box)** - directed-energy single-shot blast shotgun, import from Advanced Warfare. Auto-charges between shots; each blast is concentrated energy (not buckshot). **The best crowd-control gun in the game** - its role is killing many enemies fast, not burst-damage on single targets. PaP placeholder: **"Tac-19 Overcharge"**. Overclock family: shotgun.

Unique rules for this weapon:
- **No headshot multiplier applies.** Energy blasts dissipate too wide for head-hits to register. Damage is flat across hit location. Coded in `_acc_damage.gsc::is_applicable_weapon()`.
- **Base damage is bumped above stock shotgun values** to compensate for no headshot bonus AND to push it into "best crowd control" territory. Tune at authoring time in `tac19_zm.gdt` (target: one-shot kills chaff through round ~20 base, ~35 at PaP L3, ~45 at PaP L5 + Tier 5).
- **Always-on crowd-control profile (added 2026-06-14).** Mechanically the Skye `s1_tac19` is an 8-pellet `weaponClass spread` hitscan shotgun (`shotCount 8`), so its GDT carries a non-perk-gated profile that leans into crowd control: **small range buff x1.5** (`maxDamageRange` 550→825, `minDamageRange` 900→1350 base / 1100→1650 `_up`), **FMJ over-penetration** (`penetrateType` none→`large`, pellets pierce a line of zombies), **wider blast "girth"** (hip spread x1.25 — `hipSpreadStandMin` 7→8.75, `hipSpreadMax` 10→12.5, etc., so the 8 pellets fan across a wider arc; `adsSpread` stays 0 → ADS is still a precise single-target shot), traded against **−15% per-pellet damage** (x0.85, rounded to int — `damage` 175→149, PaP 255→217; `damage` is an INT-typed GDF field, a decimal value makes the gun do 0 damage in-game). Baked by `tools/apply_recoil_overhaul.js` (`GUNS[tac19].baseline = { range: 1.5, penetrate: "large", damage: 0.85, spread: 1.25 }`) into the base + `_up` + all 11 perk twins; tune every knob in that one config object. The `multishotBaseDamage*` pellet-cap fields stay untouched. Implementation: the weapon-variant twin section in `_acc_weapon_variants.gsc` + `tools/gen_weapon_variant_gdt.js` (`--range` / `--damage` / `--spread` / `--penetrate`).
- **Against bosses it under-performs.** Full boss + mini-boss have too much HP and not enough adjacent chaff for Tac-19's area damage to shine. If you're boss-fighting with a Tac-19 primary, swap to your secondary or hope your teammate has a sniper.

Import notes: pull model/anims/sound from AW community ports; author GDT at `weapons/zm/sp/tac19_zm.gdt`. The damage-curve bump and the no-headshot rule are the two design knobs that define this weapon - they are explicit balance levers, not accidents.

### AR Full-Auto Category

**5. ICR-1 (normal, wallbuy)** - stock BO3 full-auto AR, BO3's SCAR-analog silhouette. Tight recoil, moderate RoF, reliable generalist. 1500 wallbuy at Bus Station. PaP: "ICR Outperformer". Overclock family: ar.

**6. XR-2 (bad, box)** - stock BO3 energy-based AR. Lower effective DPS than ICR-1 at zombie ranges, weird handling. The AR bad-roll. PaP: "XR-2 Ultramax". Overclock family: ar.

**7b. AE4 (strong, box) — ✅ LIVE** (Skye **AW `s1_ae4`**, added 2026-06-14, docs/33). AW **directed-energy AR** — the cyberpunk energy gun. 160 dmg @ 500 RPM but **penetrates** (pierces a zombie train), clip 36, tight spread. Balance **×0.22**. Shares the AR **Focus Fire** ability + AR Overclock pool with the AK-47. (Energy muzzle-flash VFX waived — references an unbundled IW FX; fires/sounds fine.)

**7c. Ripper (strong, box) — ✅ LIVE** (Skye **Ghosts `iw6_ripper`**, added 2026-06-14, docs/33). **Convertible SMG⇄AR** (Evo Pro III) — the map's most mechanically unique gun; weapon-switch toggles SMG mode (190 dmg/674 RPM) ⇄ AR mode (140 dmg/968 RPM) mid-fight. Implemented as 4 `altWeapon`-linked assets. Balance **×0.25** (both modes ~ASM1/AK band). SMG family: **Whirlwind** ability + SMG Overclock pool. NO perk twins (convertible altWeapon conflicts with the twin-swap engine). PaP name: **"R1PJ4W-A2"**.

**7. AK-47 (strong, box) — ✅ LIVE** (Skye **BO2 `t6_ak47`**, added 2026-06-14, see docs/33). Full-auto AR, the AR jackpot. Balance **×0.23** (raw 200 dmg @ 750 RPM — highest in the box pool; lands sustained DPS just above the ASM1). Ability: **Focus Fire** (next 6 shots auto-crit 4×, 25s cd). Overclock family: **ar** (Burst Coil / Overpressure / Piercing / Adaptive / Overheat / Subcritical). PaP placeholder: **"Reznov's Revenge"** (homage to the BO1 easter egg). _Import notes: most-ported weapon in CoD history; we used TheSkyeLord's BO2 port._

### Semi-Auto AR Category

**8. M14 EBR (normal, wallbuy)** - MW2 import. Semi-auto marksman rifle, clean trigger, high per-shot damage. 1500 wallbuy at Bus Station (separate slot from ICR-1). PaP placeholder: **"M14 Enforcer"**. Overclock family: ar (shared with full-auto ARs). Import notes: iconic DMR, community ports exist.

**9. G3 (bad, box)** - World at War import. Semi-auto battle rifle, slower feel, dated silhouette. The semi-auto bad-roll. PaP placeholder: **"G3 Purger"**. Overclock family: ar. Import notes: WAW asset, ports exist but may need animation tuning for BO3 rig.

**10. FN FAL (strong, box)** - BO1/BO2 import. Semi-auto 7.62 battle rifle; trigger-discipline gun. Overload + Meltdown Cyberware capstone turns this into a precision monster. PaP placeholder: **"FAL Overwrite"**. Overclock family: ar. Import notes: multiple mature BO3 community ports exist.

### Sniper Category

**11. Intervention (normal, wallbuy)** - MW2 import. Bolt-action sniper. Clean one-shot baseline, but with a slower rechamber than Drakon and no magazine depth. 3500 wallbuy at Helipad. PaP placeholder: **"Intervention Apex"**. Overclock family: sniper. Import notes: most-loved sniper in CoD history; community ports are thorough and well-tested. **Deployment risk**: because this is a wallbuy, the import has to work cleanly before playable greybox testing is meaningful. Fallback plan: swap to Drakon at wallbuy if the Intervention port is unstable on first compile.

**12. Locus (bad, box)** - stock BO3 bolt-action sniper. Solid gun mechanically - but when the box could roll a Drakon, hitting Locus is disappointing. "Not the one you wanted" energy. PaP: "Locus Lockdown". Overclock family: sniper.

**13. Drakon (strong, box)** - stock BO3 semi-auto sniper. **The best sniper in the game.** Why it's the strong tier and not Intervention: the 2x headshot multiplier (see [06_mechanics.md](06_mechanics.md)) plus a semi-auto trigger means a skilled player out-DPSes any bolt-action. Drakon rewards aim without punishing follow-up - the peak synergy weapon with the Overclock/"Sniper" Cyberware archetype (Overload + Meltdown on a semi-auto = absurd training room cleans). PaP: "Diplomat". Overclock family: sniper. Landing this roll on the box is the jackpot. TODO(acc-tune): may need a small damage-per-shot nerf in playtest if the semi-auto + 2x headshot combo is flat-out broken; first-pass leave stock values.

### Utility Slots

**14. Bowie Knife (melee upgrade, wallbuy)** - stock BO3. 3000 wallbuy near one of the perk machines. One-shot zombies through round ~10 base. Huge round 4-9 spike. Does **not** inherit Cyberware weapon damage buff in v1.0 (different damage hook). Cyber Cleaver visual reskin is a Phase 5 art task - same GDT.

**15. Frag Grenade (starter lethal)** - stock BO3. Spawn with 2, max 4. Meltdown capstone makes grenade kills chain via AoE.

**16. EMP Grenade (custom tactical, wallbuy)** - authored custom grenade. 250 wallbuy re-ammo at Vault. Regular zombies: 2s stun. Shielded elites: shield disabled 4s. Teleporter elites: teleport disabled 8s. EMP elites: no effect. Phase 4 GSC authoring work in a new `_acc_weapon_emp_grenade.gsc`; design sketch below in "Custom Weapon GSC Notes".

## Weapon Progression (dual-track)

Every weapon in the roster progresses on **two parallel tracks** (money and Shards) plus has an **intrinsic ability** (free):

```mermaid
flowchart LR
    Base[Base weapon<br/>includes Ability] --> PaP[PaP L1-5<br/>Money track]
    Base --> Tier[Tier 1-5<br/>Shard track]
    PaP --> MaxPaP[Max PaP L5<br/>+100% damage, +5 reserve mag]
    Tier --> MaxTier[Max Tier 5<br/>5 Overclock slots active]
```

Both tracks apply independently. A weapon at **PaP T3 + Tier 5** has +150% damage, the upgraded "_up" form, 5 active Overclocks, and its ability is available from round 1 on cooldown.

### Pack-a-Punch Tiers (money) — 3-tier system (revamp 2026-06-16)

Three tiers, each a flat damage layer on top of the gun's normalized base damage. **The actual
PaP transform (the upgraded "_up" form — explosive M1911, akimbo PDW, gold-camo'd upgrade, etc.)
is DEFERRED to tier 2:** tier 1 is a "camo + damage" pack that keeps the base gun's
appearance/behavior, so the transform is a deliberate second investment.

| Tier | Damage bonus | Asset | Cost | Cumulative |
|---|---|---|---|---|
| T1 | +50% | base gun + gold PaP camo (no transform) | 5,000 | 5,000 |
| T2 | +100% | **transforms** to the upgraded "_up" form + camo | 7,500 | 12,500 |
| T3 | +150% | upgraded form (MAX) | 10,000 | **22,500** |

- **"% is the only damage lever":** `acc_weapon_balance_mult` (`_acc_damage.gsc`) normalizes every
  form (base / `_up` / perk-twin) per gun by substring match, so the `_up` form's own higher raw
  damage doesn't double-count — the +50/100/150% ladder IS the PaP damage progression. The `_up`
  transform's *functional* identity (explosive splash, akimbo, etc.) still applies on top.
- All tiers applied at the Pack-a-Punch machine in the Lab — one machine, three interactions.
- Buying T2 requires T1, T3 requires T2. A weapon cannot skip tiers.
- **Packing is instant + in-place on every tier** — no gun-into-machine float/animation (user
  2026-06-14). Holding Use packs the held gun right there: T1 applies camo, T2 swaps to the `_up`
  form, T3 bumps damage. Every tier replays the first-pack in-hand draw. The gun **only ever
  changes when you actually pack** — walking near the machine never swaps it.
- **Perk weapon-variant twins + PaP (twins follow tiers):** if you're holding a perk twin
  (Deadshot recoil, Gun Slinger fire, Speed Cola reload), tier 1 keeps you on the **base-form**
  twin (camo'd); tier 2 transforms you to the matching **packed `_up` twin** in one step, keeping
  the perk effect. (`_acc_pap_levels::acc_do_first_pack` / `acc_do_transform` +
  `acc_weapon_variants::packed_form`.)
- **Box guns come out stock:** tier 1 is now a base-form gun (no `is_weapon_upgraded` to lean on),
  so a Mystery-Box copy of a gun you previously packed is reset to tier 0 via
  `box_grab_clear_watcher` (on the stock `user_grabbed_weapon` notify) + `prune_lost_tiers`.

### Tiers (Data Shards)

Each tier unlocks **one Overclock slot** that is **permanently applied** (the Overclock is rolled from the weapon's family pool at tier-up, stays for the run).

| Tier | Overclock slots active | Cost (Shards to advance from previous tier) | Cumulative Shards |
|---|---|---|---|
| Base | 0 | - | 0 |
| T1 | 1 | 1 | 1 |
| T2 | 2 | 2 | 3 |
| T3 | 3 | 3 | 6 |
| T4 | 4 | 4 | 10 |
| T5 | 5 | 5 | **15** |

- Advancing a tier **rolls a new Overclock** from the weapon's family pool and adds it to the active set. You cannot have two identical Overclocks active; if the roll duplicates an existing one, re-roll (no Shard penalty).
- Re-rolling an **existing tier's** Overclock costs 1 Shard. Choose tier, choose new roll.
- Tiers applied at the **Overclock Terminal in the Lab** (same location as before; renamed role).

### Weapon Abilities (intrinsic)

Every weapon **category** has one signature ability, hotkey-triggered with cooldown. Free - no buy, no gate. Available from round 1.

**LIVE table (matches `_acc_weapon_abilities.gsc`, user 2026-06-21 — every box gun now mapped):**

| Category | Live guns | Ability | Cooldown | Effect |
|---|---|---|---|---|
| Pistol | Five-Seven, M1911 | **Precision Mode** | 30s | Next **3** shots auto-crit (4×, ignore hit-loc) |
| SMG | ASM1, Ripper, PPSH-41, AK-74u, PDW-57 | **Whirlwind** | 20s | 360° AoE: insta-kill chaff within 96u (elites take 1000 flat; bosses excluded) |
| Shotgun | Tac-19, Olympia | **Slug Round** | 20s | Next shot **3×** single-target (the 2×-range / tight-cone half is a Phase-4 GDT override) |
| AR | AK-47, AE4, Galil, Nail Gun | **Focus Fire** | 25s | Next **6** shots auto-crit (4×, ignore hit-loc) |
| Sniper | Paladin HB50 | **Precision Mode** | 30s | Next **3** shots auto-crit (4×, ignore hit-loc) |
| LMG | M60, RPD | **Focus Fire** | 25s | Next **6** shots auto-crit (4×, ignore hit-loc) |
| Wonder | Wunderwaffe DG-2 | *(built-in chain lightning)* | — | No ability slot |

> **Stub effects** (defined but NOT wired — no reachable gun / infeasible): Triple Tap (burst-reshape needs a GDT swap), Stabilizer (recoil twins are Deadshot-perk-driven), Thermal Vision (needs LUI/clientfield), Extended Fuse / Overcharge (grenades are never the *current* weapon). The 4 effects above (Precision Mode / Whirlwind / Slug Round / Focus Fire) are the only live ones; sniper reuses Precision Mode and LMG reuses Focus Fire.

Ability activation: **hotkey** (default: hold-then-press on your secondary action button; final bind TBD during Phase 4 LUI / input work).

Cooldowns tick down while the weapon is equipped **and** while holstered (so swapping weapons mid-cooldown doesn't cheese the system).

### Maxed weapon cost

A fully-upgraded weapon costs **50,000 Points + 15 Data Shards**. That's a huge commitment - expect one maybe two maxed weapons in a round-40 run, not your whole arsenal. Forces weapon-choice decisions and rewards sticking with a main weapon.

### Tier vs PaP vs Ability interaction

- **PaP stats multiply into the base damage**, so all Overclocks and abilities benefit from PaP.
- **Overclocks stack with each other** (where they make sense mechanically). Overpressure + Adaptive Aim + Piercing all active = very scary semi-auto headshot rifle.
- **Abilities ignore tier** - a Tier 0 / PaP L0 weapon still has its ability. Useful in emergency.

### A fully upgraded "bad-tier" weapon can still outperform a base "strong"

Example: PaP L5 + T5 Brecci (bad-tier shotgun) vs base Tac-19 (strong-tier shotgun). The Brecci wins on sustained DPS thanks to compounding buffs. This is intentional - investment rewards specialization, the tier system is about **roll excitement**, not an absolute power ranking.

## The Overclock System

Each weapon family has a **pool of 4-6 Overclocks**. Overclocks are unlocked via the **Tier system** above - advancing a weapon's tier from T1 to T5 unlocks 5 total Overclock slots, filled with random draws from that weapon's family pool.

### Pools and Active Weapons

- **AR family** (Burst Coil, Overpressure, Piercing Rounds, Adaptive Aim, Overheat, Subcritical). Active weapons: ICR-1, XR-2, AK-47, M14 EBR, G3, FN FAL.
- **Shotgun family** (Spread Cone, Breach, Concussive, Reflow). Active weapons: Haymaker 12, Brecci, Tac-19.
- **Sniper family** (Thermal Lock, Penetration Round, Reactive Powder, Quick Chamber). Active weapons: Drakon, Locus, Intervention.
- **SMG family** (Swarm, Reflex Fire, Coolant Flow, Shrapnel, Micro-Boost). Active weapons: **none in v1.0** (dormant pool).
- **LMG family** (Sustained Fire, Suppression, Reload Drum). Active weapons: **none in v1.0** (dormant pool).
- **Pistol, Melee, Grenade**: no Overclock pool. Tiers still advance (for stat / slot purposes if we add those later) but no Overclock roll triggers.

### How rolls work

- At each tier-up, the Terminal picks a random Overclock from the weapon's family pool that isn't already active on that weapon.
- If the family pool is exhausted (e.g. shotgun family has 4 Overclocks and you've unlocked T4), further tiers simply don't add new Overclocks - they still cost Shards and unlock the slot, but the slot is empty unless a re-roll elsewhere frees one up.
- Re-rolling a specific tier's Overclock costs **1 Shard**; new roll cannot duplicate an already-active Overclock on the weapon.
- Pools are **NOT re-rolled per run**. All Overclocks in a family pool are draftable each run; the randomization is **per tier-up**, not per run. This reverses my earlier design (previous spec had a random 3-active-per-run per family - that system is replaced by the tier-driven reveal).

### Semi-auto ARs share the AR pool

M14 EBR, G3, and FAL classify as `"ar"` family for Overclock purposes. The AR Overclock list has some options that favor sustained full-auto (Overheat, Subcritical) and others that favor precision semi-auto (Overpressure, Adaptive Aim) - the random roll creates interesting build puzzles regardless of whether you rolled a full-auto or semi-auto AR.

### Replayability via Overclock rolls

- A single weapon with 5 Overclock slots drafted from a 6-Overclock pool = 6 distinct "miss" permutations per fully-maxed weapon.
- Across your 2 main weapons, that's 36+ distinct run-end states for just weapon Overclocks, not counting which weapons you pick or which items you equipped.

## Perks

Full perk roster, costs, effects, and stacking rules live in **[13_perks.md](13_perks.md)**. Perks that are especially weapon-relevant:

- **Deadshot** (3,500): +1.4 headshot damage bonus + auto-aim to head on ADS. **Added** (not multiplied) into the headshot bonus sum alongside our +2/+2 trash/boss headshot bonus (additive stacking, 2026-06-14). Keystone for precision builds (FAL, Intervention, Drakon, M14 EBR).
- **Speed Cola** (3,500): +50% reload, faster perk drinking, faster equipment swap. Best on Tac-19 / AK-47 / Haymaker 12.
- **Double Tap 2.0** (2,000): +33% fire rate + 3% damage. Compounds with PaP L5 + Tier 5 on full-auto ARs.
- **Widow's Wine** (4,000): +50% frag damage + radius, +50% EMP stun duration + radius. Grenade-heavy builds.
- **PhD Flopper** (2,500): immunity to fall damage and your own explosive splash; dive-to-prone triggers a nova explosion that clears nearby zombies (jump → land in a slide → blast), and you explode on going down. Clutch in Overload events and boss add-waves.

Overall: **no perk cap** in this map, 9 perks available, 4 locked out per run. See [13_perks.md](13_perks.md).

## Wonder Weapons

> **SHIPPED TODAY (2026-06-19): the Wunderwaffe DG-2 (`tesla_gun`)** — a stock no-download wonder weapon in the
> mystery box at uniform odds (user pick; recipe in CHANGELOG + the arsenal list above). This is the map's real,
> in-game wonder weapon right now. The two CUSTOM designs below (Signal Staff + Vibro Cleaver) remain **Phase-4
> authoring concepts** — boss-countering craftables that are NOT built. They are not mutually exclusive with the
> Wunderwaffe; if/when authored they'd join it.

### Phase-4 design concept: two boss-counter craftables (NOT built)

Two wonder weapons, each a hard counter to one specific boss. **No counter overlap** - players must pursue both if they want easier boss fights, and missing one means the corresponding boss is noticeably harder.

| Wonder Weapon | Type | Boss Counter | Acquisition Gate |
|---|---|---|---|
| **Signal Staff** | Ranged, AoE data pulses | Subroutine Core (full boss, r30+) | Vault Overload completed + 5 Data Shards |
| **Vibro Cleaver** | Wide-arc energy melee | Juggernaut Host (mini-boss, r10/20) | Hack Terminal completed + 5 Data Shards |

### Signal Staff (ranged wonder weapon)

- **Form**: two-handed staff emitting directed signal pulses. Cyber-adjacent fiction: engineered to disrupt the same corporate-AI network that reanimated the city.
- **Primary fire**: aimed pulse burst - 3-round directed energy AoE cone, medium range, 4-round magazine, slow recharge.
- **Alt fire**: ground-slam shockwave - 360-degree AoE, knocks back all enemies in ~400 unit radius, long cooldown.
- **Ammo**: recharges passively (like stock wonder weapons); no reserve pool.
- **Boss interaction (Subroutine Core)**:
  - Deals **+300% damage** to the Core specifically (the weapon is literally built to disrupt its signal network).
  - Charged pulse can **skip a Core phase transition's debuff window** (power-disable or perk-disable) if fired at the moment of transition. A mechanical reward for timing knowledge.
- **Versus everything else**: an excellent ranged AoE, competitive with Tac-19 for chaff clear but slower tempo.
- **Overclocks (all 3 always active, applied is random per use)**:
  - *Broadcast*: pulse cone widens ~50%.
  - *Interference*: hit enemies take +50% damage from all sources for 3s.
  - *Overflow*: every 5th pulse is a "burst" that deals 3x damage.
- **Acquisition**: craft at the **Lab terminal**. Requires Vault Overload completed this run + 5 Data Shards spent. Without Overload completion, the staff cannot be crafted.
- **Status**: **custom weapon, Phase 4 authoring.** Planned module `scripts/zm/zm_abandoned_cyber_city/_acc_wonder_signal_staff.gsc`.

### Vibro Cleaver (wonder melee)

- **Form**: large one-handed resonance blade - a mono-edge axe-cleaver hybrid. Wide arc on swing. Visibly hums / vibrates in first-person.
- **Primary attack**: wide horizontal swing, hits up to 4 enemies in front 180-degree arc. One-shot kills chaff through round ~30.
- **Heavy attack**: charged overhead strike (0.5s wind-up), deals 3x swing damage, can parry charges.
- **Parry mechanic**: if heavy-attack wind-up completes *while a Juggernaut Host is mid-charge at you*, the strike counters the charge - knocks the Host on its back, staggers for 3 seconds, deals massive damage.
- **Boss interaction (Juggernaut Host)**:
  - Deals **+300% damage** to the Host on any hit.
  - Parry-on-charge is the skill-expression version of the counter: land one and the mini-boss is effectively solo'd by a good player.
- **Versus everything else**: best melee weapon in the game by a mile (replaces Bowie Knife in a maxed build), but short-range obviously.
- **Overclocks (all 3 always active, applied is random per use)**:
  - *Resonance*: kills leave a 2s damage-over-time field that affects remaining enemies in swing arc.
  - *Counterstroke*: parrying a melee attack (zombie lunge or Host charge) refunds the heavy-attack cooldown.
  - *Phase Blade*: swings pass through walls for 0.5s after each use - emergency escape tool.
- **Acquisition**: craft at the **Vault terminal**. Requires Hack Terminal completed this run + 5 Data Shards spent. Without Hack completion, the cleaver cannot be crafted.
- **Status**: **custom weapon, Phase 4 authoring.** Planned module `scripts/zm/zm_abandoned_cyber_city/_acc_wonder_vibro_cleaver.gsc`.

### Design Notes

- **Why craft-gated on side events.** Side events (Hack Terminal, Vault Overload) previously just gave Data Shards and a minor shortcut. Now each also unlocks a wonder weapon. This raises the value of completing them without making them mandatory - you can still beat the map without wonder weapons; the corresponding boss just takes much longer.
- **Why +300% vs specific bosses (and not a generic "anti-boss" buff).** Forces players to pick the *right* tool for the *right* boss. Brings flavor into mechanics: staff for the machine boss, melee for the brute boss. No "wonder weapon = god mode against everything" problem.
- **Why wonder weapons don't route through the Overclock Terminal.** Their Overclocks are intrinsic (all 3 always active, applied is random). Cleaner UX; respects the specialness of the acquisition gate. Classifier (`_acc_overclocks.gsc::weapon_name_to_family`) returns `"none"` for them.
- **Why only two wonder weapons (not three or four).** Two map cleanly onto the two boss archetypes. A third would dilute the counter-weapon identity and ask the player to grind more.
- **Co-op note**: wonder weapons are per-player. In 4-player co-op, if each player crafts both wonder weapons, boss fights become trivial. Intentional: 4-player co-op is supposed to trivialize some content. Solo players who want to beat r30+ must commit to the side event loop.

## Custom Weapon GSC Notes

### EMP Grenade

New module for Phase 4: `scripts/zm/zm_abandoned_cyber_city/_acc_weapon_emp_grenade.gsc`. Responsibilities:

- Register a weapon GDT entry based on a stock grenade (use frag shell, swap effects).
- Hook `grenade_exploded` or equivalent; apply per-enemy-class status in blast radius.

Planned stub:

```gsc
// _acc_weapon_emp_grenade.gsc (planned, Phase 4)
on_emp_grenade_explosion( position, thrower )
{
    zombies = get_zombies_in_radius( position, 300 );
    for ( i = 0; i < zombies.size; i++ )
    {
        z = zombies[ i ];
        if ( isdefined( z.acc_is_elite ) && z.acc_is_elite )
        {
            apply_elite_emp_debuff( z );
        }
        else
        {
            z thread apply_regular_stun( 2.0 );
        }
    }
}
```

### Cyber Cleaver flavor (Bowie reskin)

Phase 5 asset work only. Mechanically identical to Bowie Knife.

## Boss-Drop Items

Bosses drop random passive-buff items on death, Machin[a]-style. 6 items in the pool, 2 equipped slots per player. See [12_boss_items.md](12_boss_items.md) for the full design. Cross-referenced here because item effects interact with weapon progression: Kinetic Battery's 3x next-shot is added (additive bonus stacking, 2026-06-14) with PaP L5 damage and any active Overclocks; Neural Boots' movement buff makes the Slug Round shotgun ability viable at closer ranges; Payroll Ledger feeds +10% Points into every kill so funding 50k-Point PaP L5 across multiple weapons becomes realistic; etc.

## Data Sources (for the code)

- Weapon family lookups: `_acc_overclocks.gsc::weapon_name_to_family()`.
- Wallbuy pool weights (normal-tier weapons): `_acc_map_randomizer.gsc::roll_wallbuy_pool()`.
- Mystery Box pool (bad + strong weapons): `_acc_map_randomizer.gsc::register_mystery_box_pool()`.
- Weapon abilities: `_acc_weapon_abilities.gsc` (Phase 4 implementation; stubbed now).
- Boss-drop items: `_acc_boss_items.gsc` (Phase 4 implementation; stubbed now).
- Zone manifest: `zone_source/zm_abandoned_cyber_city.zone` (stock guns ride in via the `zm_levelcommon_weapons.csv` stringtable; only custom/imported weapons get their own `weaponfull` lines).

All must stay in sync. Changing the roster means updating everything above.

## Out-of-Scope for v1.0

- Additional pistols beyond B23R.
- Tactical rifles, launchers, energy SMGs.
- Additional shotguns, ARs, snipers beyond the 3-tier-per-category structure (expansion is a post-1.0 "content drop" pattern).
- Weapon-inherent Overclocks (all Overclocks applied via Lab terminal).
- Weapon variants (same model, different stats) - too much design surface for v1.0.

## Post-1.0 Weapon Ideas

- SMG category re-add: Kuda (normal stock) + MP5 import (strong) + Weevil (bad stock).
- LMG category re-add: BRM (normal stock) + M60 or RPD import (strong) + Dingo (bad stock).
- Second starter pistol option (M1911 returns as an alternate starter, selectable before map load).
- Wonder weapon expansion: author the two unchosen candidates from the list above.
