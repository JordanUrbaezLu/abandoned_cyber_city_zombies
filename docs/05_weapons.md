# 05 - Weapons

The arsenal, the Overclock system, custom perks, and the wonder weapon candidates. Most of the within-run replayability weight lives here because Overclocks randomize per run.

> **⚠️ ARSENAL = BOX ONLY (user; box list authoritative in `_acc_map_randomizer::register_mystery_box_pool`).**
> No wall buys (all removed at load by `remove_all_wallbuys()`); every gun comes from the Mystery
> Box, which clears `is_in_box` on the whole stock CSV roster and re-enables only the chosen set.
> **Current box (16 conventional guns + Mahem launcher + the Action Figure melee):** Five-Seven `t6_fiveseven`
> (also the starting pistol), RW1 `s1_rw1`, ASM1 `s1_asm1`, Tac-19 `s1_tac19`, AK-47 `t9_ak47`, AE4 `s1_ae4`,
> PPSH-41 `s4_ppsh41_base`, AK-74u `t9_ak74u`, **Chicom CQB `t6_chicom_cqb`** (BO2 3-round-burst SMG, **S+ #2**,
> user 2026-06-25), Paladin HB50 `t8_paladin_hb50`, MORS `s1_mors`, Olympia `t6_olympia`, Galil `t6_galil`,
> MK14 `s1_mk14`, M60 `t9_m60`, RPD `t9_rpd`, the Mahem `s1_mahem` (molten-metal launcher),
> and the Thundergun `thundergun` (stock wonder weapon, wind-blast knockback, `is_limited=1`; SWAPPED
> from the Wunderwaffe DG-2, user 2026-06-23). Plus the **Action Figure** `t8_melee_figure` — a fun
> handheld MELEE (BO4 `t8` port by T0nic; swing it like a bat), **box weight S-tier** (user 2026-06-23).
> It's a gitignored rip-port external asset (TEST-ONLY until IP review — CREDITS + `tools/external_assets_manifest.ps1`;
> linker-patched by `tools/fix_actionfigure_port.js`). Class `special` (not Overclock-tiered). **QUIRK:
> it ALWAYS one-knifes a SINGLE regular zombie (every swing, any round); bosses/elites are exempt (normal melee, no
> one-knife). **PaP scales SWING SPEED, not targets (user 2026-06-27):** each PaP tier swaps in a faster "speed twin" —
> **+100% / +200% / +300%** swing rate at tiers 1/2/3 (`fireTime ×0.5 / ×0.33 / ×0.25`). It PaPs IN PLACE (no `_up`
> form, TOP-bucket price 5000/7500/10000). Logic in `_acc_damage` (`is_action_figure_weapon` one-knife gate) +
> `_acc_pap_levels::acc_pap_actionfigure`. *(The old per-tier CLEAVE / multi-hit + `acc_af_cleave_radius` were removed
> 2026-06-27; the speed twins are WIP — the base figure is currently set to the max test speed for feel-testing.)** **Overclock eligibility (user 2026-06-22):
> EVERY gun overclocks — all box guns AND the starting Five-Seven — EXCEPT the Thundergun,
> which keeps its intrinsic wonder-weapon power and is not terminal-tiered. (Classified in
> `_acc_overclocks::weapon_name_to_family`; pistols return the `pistol` family, `thundergun` returns `none`.)**
> **See the [Gun Tier List](#gun-tier-list-design-intent)
> below for each gun's tier, stats, ability, and rationale — that's the canonical roster.** Per-gun
> damage balance lives in `_acc_damage::acc_weapon_balance_mult` (tier-tagged return lines).
> **EVERY conventional box gun is FULLY twinned (benefits from the Mega-perk recoil/fire/reload buffs);
> only the Thundergun (WW) is exempt. REMOVED 2026-06-23 (user "remove any gun that can't be fully twinned"):
> Ripper (convertible altWeapon), Nail Gun (projectile), PDW-57 + M1911 (akimbo PaP) — none could be twinned.**
> The 16-weapon table + the tier tables further down still list the removed guns (historical, aspirational
> spec); the live box is the 13 above.
>
> **Global gun buff (user 2026-06-23):** all player damage is lifted by a single across-the-board
> scalar `acc_global_dmg_mult` (default **3.25 = +225%**; user 2026-06-23 bumped 1.20 → 1.32 → 1.50; user 2026-06-24 bumped 1.50 → 2.50; user 2026-06-25 bumped 2.50 → 3.0 → 2.75; user 2026-06-29 → 3.25), applied in `on_ai_damage` OUTSIDE the per-gun
> table — so it buffs every gun *uniformly* and the relative `acc_weapon_balance_mult` tiers above still
> hold. To make guns stronger overall, raise this one dvar rather than re-touching every per-gun line.
>
> **Wall-buys (user 2026-06-23; chalk + placement fixed 2026-06-24; AK-47 added 2026-06-26):** the map is
> box-first but has **4 fixed wall-buys** — **Five-Seven @ Lab** (500), **Olympia @ Bus Station** (500),
> **frag grenade @ Spawn** (100), and the **AK-47 @ Abyss Layer 4** (1500) — an S-tier wall-buy planted on the
> "4th floor" trench (z=-960) to pull players down into the pit.
> Each is the proven early recipe (commit `0044a16`): an inline worldspawn **chalk outline mesh** on the wall
> face + a `weapon_upgrade` trigger + a model struct, all co-located ON the wall (2u proud) and angled into the
> room. Costs in [zm_levelcommon_weapons.csv](../gamedata/weapons/zm/zm_levelcommon_weapons.csv). The hint text
> and weapon/nade granted come from `zombie_weapon_upgrade` + the CSV (not the chalk), so the chalk shape is
> cosmetic/generic. **Chalk only (user 2026-06-24):** the redundant server-spawned 3D gun/monkey-bomb model
> (`spawn_acc_wallbuy_models()`) is **disabled**, so each spot shows just the chalk outline. Owning the gun
> switches the prompt to **buy ammo** (PaP'd → 4500, else
> ~half cost). Re-enabled past the box-only `remove_all_wallbuys()` by whitelisting those 4 weapon names — see
> [07_replayability.md](07_replayability.md). _(The prior pass wrongly claimed the chalk material "won't
> compile" and used floating 3D models instead — both fixed: the chalk tokens are plain colorMap `material.gdf`
> assets, verified on disk.)_
>
> **Ammo economy (2026-06-16).** Every box gun runs a global **30% ammo cut** baked by
> `tools/reduce_base_ammo.js` (FACTOR 0.70). In the Skye GDTs `maxAmmo`/`startAmmo` are reserve
> **magazine** counts, so **in-game reserve rounds = `maxAmmo × clipSize`**; cutting `clipSize`
> ×0.70 drops both the mag and the reserve by 30% in one edit. Two special cases: **Olympia**
> (double-barrel, `clipSize 2` floor) takes its 30% off `maxAmmo` instead (clip stays 2); the
> **PDW akimbo-PaP** shipped a broken `maxAmmo 920` (Skye data error, clamped to 18 ≈ 306 reserve).
> Approx live reserves — autos ~130-225 base / ~280-420 PaP; shotguns/snipers/pistols ~26-84 (low
> by design). Tune in that one tool; re-run + `gdtdb /update` + linker.
>
> **Mahem launcher (special) is hand-tuned on its own GDT — NOT in `reduce_base_ammo.js`'s list
> (left uncut by design).** Base `s1_mahem`: `clipSize 1`, `maxAmmo/startAmmo 20` → 20 reserve.
> PaP `s1_mahem_up`: `clipSize 10`, `maxAmmo/startAmmo 3` → **30 reserve** (user 2026-06-24, was
> `4` = 40 reserve, "too much"). Edit `skye_s1_mahem.gdt` directly, then `gdtdb /update` + linker.
> Because this GDT is install-side and untouched by either ammo tool, a fresh asset re-install
> reverts it to the Skye default (40) — re-apply this value if you ever reinstall the pack.
>
> **PaP 3-tier (Mahem "only packs twice" — REAL fix, user 2026-06-26):** the Mahem now upgrades through all
> **three** PaP tiers like every other gun. **Root cause** (traced through stock `_zm_pack_a_punch.gsc` +
> `aat_shared.gsc` + `_zm_weapons.gsc`, after several wrong fixes): after the tier-2 transform you hold
> `s1_mahem_up`, and the stock machine's visibility gate `player_use_can_pack_now()` shows the machine only if
> `can_pack_weapon(held) || weapon_supports_aat(held)`. For **any** `_up` gun `can_pack_weapon` is false
> (stock registers only the BASE in `level.zombie_weapons`), so every gun depends on **`weapon_supports_aat(_up)`**
> for the tier-2→3 visibility — and that needs the gun to NOT be AAT-exempt. The Mahem's CSV row sets
> **`AAT_EXEMPT` (col 17) = TRUE** (it's a launcher), so `register_aat_exemption(s1_mahem_up)` runs →
> `weapon_supports_aat` returns false → the machine **hides after pack 2**. (`is_weapon_upgraded(s1_mahem_up)`
> was *always* true via stock `add_zombie_weapon`, so the upgrade-table fixes prior agents tried were no-ops.)
> **Fix:** `_acc_pap_levels::make_mahem_pap_visible_to_tier3()` drops `s1_mahem_up` from
> `level.aat_exemptions`. AAT is globally OFF (`level.aat_in_use=false`), so this grants no alt-ammo — it only
> restores machine visibility so `acc_pap_validate` runs the in-place tier-3 pack. Verify with `+set acc_dev 1`
> → the dev log prints `was_aat_exempt=1 is_weapon_upgraded=1`, and the 3rd pack reaches **tier 3/3**.

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
- **Snipers are scored on single-target DPS, not chaff** (a one-shot boss-killer's "DPS" is its single-target output). That's why MORS can reach S despite a 1-round charge clip — its single-target power is elite (and why a damage-only buff can't get it there: the clip-1 sustain floor means S also needs the reserve lift). Without single-target scoring, the horde-weighted formula would bury all snipers in B.
- **Pellet shotguns (Tac-19, Olympia) take a separate BOSS-damage cut** (`ACC_SHOTGUN_BOSS_MULT` in `_acc_damage.gsc`, default ×0.25). Their 8 pellets all land on a boss's single hitbox → ~8× stacked damage. This cut only applies *vs bosses/mini-bosses* — it doesn't change their chaff tier (Tac-19 stays the chaff king) but stops the boss-nuke. **This is a damage rule, not a tier-score factor.**

#### Boss-nuke audit (user 2026-06-24 — "one-shot / explosive guns nuking bosses")

The "Thundergun does ~200k to a boss" report is a **systemic** issue: any **multi-hit / explosive** weapon that lands several damage events on a boss's single hitbox stacks into a nuke, amplified by the **×3.25 global player-damage buff** (`ACC_GLOBAL_DMG_MULT`). The only weapons currently protected against this are pellet shotguns (above). Audit of every acquirable damage weapon:

| Weapon | balance mult | boss-damage cut? | verdict |
|---|---|---|---|
| **Thundergun** (WW) | was **1.0 (UNLISTED!)** → **0.70** (−30%, user 2026-06-24) | **none** | **Root cause.** No balance entry at all → zero cut, while every other gun is cut to 0.10–0.70. Wind-blast cone multi-traces a boss → ~200k. The −30% helps everywhere but it **still nukes** (~140k) — needs a boss cut. |
| **Mahem** (launcher) | **0.29** (0.315 → 0.40 buff → **0.29** −27.5% nerf, user 2026-06-29 vs the 3.25 global) | **none** | Explosive direct + splash both hit one boss hitbox. Ammo-limited so it self-balances somewhat, but no boss cut. |
| **Paladin HB50** (sniper) | 0.3565 | **yes ×0.50** (user 2026-06-24) | One-shot single-target boss-killer; bosses negate the headshot mult (`ACC_BOSS_HEADSHOT_MULT 1.0`) and it's RoF/ammo-limited → not a burst nuke, but reined in vs bosses on user request (`acc_paladin_boss_mult`). |
| Tac-19 / Olympia | 0.68 / 0.9775 | **yes ×0.25** | Handled (pellet cut). |
| All other guns | 0.10–0.31 | n/a | Single-trace, deeply cut → fine. |
| Frag / Octobomb / Cymbal Monkey | 1.0 (no entry) | none | Explosive, no boss cut — but quantity-limited tacticals, minor. |

**Systemic fix (IMPLEMENTED, user 2026-06-24):** the boss-damage cut is generalized beyond pellet shotguns. `_acc_damage.gsc::boss_nuke_mult()` applies a boss-only REDUCTION (gated on `acc_is_boss`/`acc_is_mini_boss`, stacks on top of `acc_weapon_balance_mult`):
- **Thundergun** ×`acc_thundergun_boss_mult` (default **0.20**) → ~140k (post −30%) drops to **~28k/blast** vs a boss — a strong boss tool, not a one-shot. Chaff power on regular zombies is untouched.
- **Mahem** ×`acc_launcher_boss_mult` (default **0.50**) → ~6,600 direct (0.29 balance × 3.25 global) drops to **~3,300/rocket** + splash; gentler because it's ammo-limited.
- **Paladin HB50** ×`acc_paladin_boss_mult` (default **0.50**, user 2026-06-24) → ~half its per-shot boss damage. It's a single-shot sniper (not a multi-hit nuke), but reined in vs bosses on request. NOTE: the Paladin's design niche IS single-target boss-killing (it's tier-scored on single-target DPS) — a strong boss cut eats into that niche, so dial `acc_paladin_boss_mult` up toward 1.0 if it feels too weak vs bosses.

Both are live dvars — dial the exact boss damage without a rebuild. To protect a future multi-hit special, add its root name to `boss_nuke_mult()`.

#### Deeper audit (2026-06-24, adversarial workflow) — the name-keyed cut is NOT enough; a hard cap is

An adversarial 19-agent audit found the weapon-name boss cuts above are **structurally defeated** in several ways, so they were backstopped with a **final per-hit boss-damage cap** (`ACC_BOSS_PER_HIT_CAP_PCT`, dvar `acc_boss_per_hit_cap_pct`, default **0.10** = a single player hit deals at most 10 % of a boss's maxhealth → ≥10 hits to kill). It clamps `final_damage` **after every multiplier** (global ×2.5 **and** insta-kill ×6), so it survives every bypass below. Applies to the **heavyweight bosses only** (Brutus / Phantom / Subroutine Core) — the Glitch Stalker (`acc_is_glitch_zombie`) is excluded so it still dies fast.

Why the name-keyed cut alone failed (all confirmed in code):
1. **The Thundergun one-shot is a WEAPONLESS DoDamage.** The real ~200k is the stock `thundergun_fling_zombie` → `DoDamage(self.health + 666)` with **no weapon** — so `acc_weapon_balance_mult` (gated on `isdefined(weapon)`) and `boss_nuke_mult` (returns 1.0 for undefined weapon) **never fire**. `int(80666 × 2.5) = ~201,665` = the exact report. The −30% nerf + ×0.20 cut did nothing to it. The hard cap catches it.
2. **Octobomb** (granted by the Li'l Arnie boss item) does `DoDamage(target.health)` (full-HP pull) — same weaponless bypass, one-shots any boss. Capped now.
3. **Insta-Kill ×6** is applied *after* the boss cut + global, re-inflating a cut weapon past the one-shot line during the powerup window. Capped now.
4. **Investment stacking** (PaP T3 + Cyberware Amplifier + Overclock T10) lives in the *bonus_sum* bucket, a different bucket than the cut's *reduction* — so a fully-kitted weapon multiplies right past the cut (~130k/blast even at ×0.20). The advertised "~28k/blast" only held for a zero-investment gun. Capped now.
5. **Ability auto-crit** (Precision Mode +4.0 / Focus Fire / Slug +3.0) adds a flat bonus on bosses that the headshot-negation (`ACC_BOSS_HEADSHOT_MULT 1.0`) does **not** cover — biggest on the uncut snipers **MORS (`s1_mors`)** and **MK14 (`s1_mk14`)**. Capped now.
6. **Melee** (Action Figure, Bowie) has no balance entry and scales with the Exo melee layer (now +30 %/tier to T10) → ~10k/swing maxed; single-target/point-blank, low severity, but also capped now.

The `boss_nuke_mult` cuts (Thundergun/Mahem/Paladin) are **kept** — they shape the baseline feel *below* the cap. The cap only removes the one-shot ceiling-break. `acc_boss_per_hit_cap_pct 0` disables it.

> **Model + curation history (user, 2026-06-21):** the formula is "v2 sustain" — clip is rewarded *through* reload
> (a big clip = you reload rarely), reserve is log-scaled. On top, the user hand-set several sub-tiers and the stats
> were tuned to match: M60 **S** (DPS↓, clip 100/reserve 400), MORS **S** / Paladin **B** (sniper swap 2026-06-24: MORS DPS↑ + reserve 120/180, Paladin DPS↓ 0.70→0.49),
> PPSH **S** (user 2026-06-24 all-around buff: +20% dmg + clip 30/44→40/54), Galil **B+**, Five-Seven **C**, AE4/AK-47 **A**, Olympia **C**. Tac-19 got the boss-damage cut.

### Tier ranking — BASE guns (out of the box, no PaP)

How good the gun is *when you roll it* — the box-roll quality.

| Tier | Score | Gun | Class | Eff DPS | Clip | Reserve | Reload | Move | Pen | Key drivers |
|---|--:|---|---|--:|--:|--:|--:|--:|---|---|
| **S** | 7.9 | Nail Gun | AR (proj) | ~589 | 40 | 280 | 2.0s | 1.0 | none | Best sustain in the game (fast reload + 40 clip). |
| **S** | 7.9 | M60 | LMG | ~580 | **100** | **400** | 9.7s | 0.8 | large | DPS traded down for a 100-clip + 400 reserve; the huge mag makes the 9.7s reload trivial. |
| **S** | 7.7 | MORS | Sniper | ~429/shot | 1 | **41** | 1.2s | 1.0 | large | **Moved B → S** (user 2026-06-24): the premier boss-killer. **−35% dmg** (×0.66→0.429) + **reserve −15%** (→41), user 2026-06-27 — **tier/score kept** (damage-only tweak, docs/54 not regenerated). |
| **B** | 6.1 | Paladin HB50 | Sniper | ~357/shot | 8 | 80 | 4.1s | 1.0 | large | **Moved low-S → B** (user 2026-06-24). **−25% dmg** (×0.4753→0.3565) + **reserve −15%** (96→80), user 2026-06-27 — **tier/score kept**. One-shots early, then falls off. |
| **S** | — | Wunderwaffe DG-2 | Wonder | chain lightning | — | recharge | — | — | — | Outside the formula; `is_limited=1`. |
| **A+** | 7.5 | Tac-19 | Shotgun | crowd king | **3** | **27** | **0.47s** | 1.0 | large | **Nerfed** (user 2026-06-21): damage −9% + clip 4→3 + reserve →27 → dropped out of S to A+. Still chaff-strong; **boss damage also cut** (see below). |
| **S** | ~7.9 | PPSH-41 | SMG | ~590 | 40 | 360 | 3.5s | 1.0 | med | All-around buff (user 2026-06-24): +20% dmg + clip 30→40; massive clip + RoF + DPS = back to S. |
| **A** | 7.7 | AK-47 | AR | ~585 | 21 | 168 | 3.25s | 0.95 | med | Strong DPS — +3% spread buff + swapped to TOP/S tier (2026-06-26). |
| **A** | 7.1 | Ripper | SMG⇄AR | ~AK band | 22 | 220 | ~2.5s | 1.0 | med | Convertible flexibility + good reserve. |
| **A-** | 6.8 | AE4 | AR (energy) | ~413 | 25 | 200 | 2.0s | 1.0 | med | Mid DPS, but fast reload + pierce + clip + reserve = A-grade kit. |
| **B** | 6.5 | AK-74u | SMG | ~414 | 20 | 160 | 2.8s | 1.0 | med | Fast, mobile; DPS cut — swapped to MID tier with AK-47 (2026-06-26). |
| **B+** | 6.5 | ASM1 | SMG | ~401 | 22 | 132 | 2.1s | 1.0 | med | Low DPS saved by fast reload + clip + pierce. |
| **B+** | 6.5 | Galil | AR | ~412 | 25 | 225 | 2.9s | 0.95 | med | DPS cut from A to the top of B. |
| **B** | 5.9 | MK14 | DMR | ~81/shot | 14 | 168 | 2.0s | 0.95 | med | Semi-auto marksman (AW): hard per-shot, ~3× headshot, **curated** single-target DPS. **−10% dmg** (×0.291→0.2619), user 2026-06-27 — tier kept. |
| **C** | 5.5 | RPD | LMG | ~421 | 60 | 240 | 7.5s | 0.8 | large | +25% damage buff (user 2026-06-25, mult 0.10→0.125, ~337→~421); tier/PaP-price/box-odds NOT recomputed. Big clip, slow move. |
| **C** | 5.5 | Five-Seven | Pistol (start) | ~52/shot | 14 | **56** | 1.8s | 1.0 | small | Weak starter; reserve cut to land it at C. |
| **C** | 5.2 | M1911 | Pistol | ~70/shot | 6 | 60 | 1.85s | 1.0 | small | Weak base — its value is the **PaP** (see the PaP list). |
| **C** | 5.2 | PDW-57 | SMG | ~330 | 11 | 132 | 2.1s | 1.0 | small | Hard DPS cut + small clip/pierce. |
| **C** | 4.8 | Olympia | Shotgun | 110×8 | 2 | 26 | 3.9s | 1.0 | small | 2-round clip = worst sustain in the game. Headshot-excluded. |

### Mystery box roll odds — tier-weighted (user 2026-06-22)

The box is **NOT uniform** — the better the tier, the rarer the roll. Per-gun **weights** in
`_acc_map_randomizer::acc_box_weight`, applied via the `treasure_chest_ChooseWeightedRandomWeapon` hook
(`acc_box_only_weapon_keys` does the weighted pick and returns it first; stock takes the first eligible key):

Box weight is now driven by the **PaP price tier** (docs/54; ranked on PaP-form power) — the same ranking that
sets PaP cost. Best packed guns are both the priciest to pack AND the rarest roll. Generated into
`acc_box_weight` by `tools/compute_gun_tiers.js`; **canonical odds live in [docs/54_pap_pricing_tiers.md](54_pap_pricing_tiers.md).**

| Price tier | Box weight | ~Chance/gun | Guns |
|---|--:|--:|---|
| **WW** | 3 | ~0.6% | Thundergun |
| **TOP** | 8 / 12 | ~1.7% / ~2.6% | **S-tier (Chicom CQB, M60, AK-47, PPSH-41, Tac-19) = wt 8, ~1.7% (rarest)**; MORS = wt 12, ~2.6% · + Action Figure wt 5, ~1.1% |
| **MID** | 29 | ~6.3% | AE4, RW1, AK-74u, ASM1, Galil (+ Mahem) |
| **BOT** | 29–50 | ~6.3–10.8% | Paladin HB50, RPD, Five-Seven, Olympia (wt 50); MK14 is pinned to wt 29 (~6.3%) |

Box pool = **19 weapons, total weight 463** (S-tier guns set to wt 8 = ~1.7% each, user 2026-06-26), so the actual draw = weight ÷ 463 (Thundergun **~0.6%**, S-tier ~1.7%, MORS ~2.6%,
MID ~6.3%, BOT up to **~10.8%** — the worst gun is ~17× more likely than the wonder weapon). The box never repeats a
gun you already own, so live odds re-normalize as you collect. To retune, edit the roster in
`tools/compute_gun_tiers.js` and re-run (regenerates the doc + both GSC functions) — do not hand-edit `acc_box_weight`.

### Tier ranking — FULLY PACK-A-PUNCHED (T3)

How good the gun is *at its ceiling*, after full PaP — which guns are worth maxing. PaP scales DPS ~×2.0
uniformly at T3 (so the DPS order barely moves); the reshuffle vs base comes from **bigger PaP clips/reserves**
(better sustain) and the **transform guns leaping up** — M1911 → explosive akimbo, PDW / Five-Seven → akimbo.

| Tier | Score | Gun | PaP clip | PaP reserve | What PaP does |
|---|--:|---|--:|--:|---|
| **S** | 8.1 | Tac-19 | **6** | **54** | Chaff ceiling (nerf dropped it S+→S; boss damage still cut). |
| **S** | 8.1 | Nail Gun | 50 | 400 | Bigger nail + huge sustain. |
| **S** | 7.9 | MORS | 1 | **61** | **Moved B → S** (user 2026-06-24): charge railgun one-shot. **Reserve −15%** (→61) + **dmg −35%**, user 2026-06-27 — tier kept. |
| **low S** | 8.0 | M60 | 120 | 480 | 120-clip belt — never stops firing. |
| **low S** | 7.9 | AK-47 | 31 | 279 | Swapped to TOP tier with AK-74u (2026-06-26). |
| **S** | ~8.1 | PPSH-41 | 54 | 486 | All-around buff (user 2026-06-24): +20% dmg + PaP clip 44→54. |
| **low S** | 7.7 | **PDW-57** | 17 | 306 | **→ akimbo + separate higher mult** (user 2026-06-21): base C → **bottom S** packed. |
| **A+** | 7.5 | Ripper | 34 | 340 | Both modes packed. |
| **A** | 7.2 | AE4 | 38 | 304 | — |
| **A** | 7.1 | **M1911** | 8 | 80 | **→ akimbo EXPLOSIVE nuke** (base C → A). The biggest PaP jump. |
| **A** | 7.0 | AK-74u | 40 | 280 | Swapped to MID tier with AK-47 (2026-06-26). |
| **A** | 7.0 | **Five-Seven** | 21 | 462 | **→ akimbo** (base C → A). |
| **A** | 7.0 | ASM1 | 36 | 288 | — |
| **A-** | 6.9 | Galil | 35 | 420 | — |
| **B** | 6.4 | Paladin HB50 | 11 | 110 | **Moved S → B** (user 2026-06-24). **Reserve −15%** (132→110) + **dmg −25%**, user 2026-06-27 — tier kept; 11-round one-shot, mid-tier. |
| **B** | 6.0 | RPD | 100 | 400 | Big belt, but low DPS ceiling. |
| **B** | 6.0 | MK14 | 12 | 240 | Per-shot doubles (79→158 body) + more reserve; stays a precise marksman, not a sprayer. **−10% dmg** user 2026-06-27 — tier kept. |
| **C** | 5.2 | Olympia | 2 | 42 | 2-round clip — PaP can't fix the sustain. |

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

### Hip-fire spread by class (skill gate, user 2026-06-29)

Hip-fire accuracy is class-gated so every gun rewards ADS. `tools/scale_hipspread_by_class.js` (the single source of truth) scales the 8 `hipSpread` **pattern** fields (Stand/Ducked/Prone/Slide Min+Max — the cone size only; **ADS is untouched**, and the `*Add` per-shot bloom / `*Decay` recovery are left at stock) across **base + PaP + all 14 twins + the `.acc-orig` recoil baselines**, from a pristine `.acc-hipspread-orig` backup (idempotent; `--revert` resets to vanilla). Per class: **Sniper ×2.5** (MORS, Paladin), **Marksman ×1.50** (MK14), **AR ×1.25** (AE4, Galil, AK-47), **LMG ×1.20** (M60, RPD), **SMG ×1.10** (ASM1, PPSh-41, Chicom, AK-74u). **Pistols + shotguns stay ×1** (`weaponClass` `pistol`/`spread`). Buckets come from the GDT `weaponClass`, with the `"rifle"` class hand-split into AR vs MK14 vs sniper. Re-run it after any `reduce_base_ammo.js` / balance-tool pass (those rewrite from their own `.acc-*-orig` baselines, which don't carry the spread change).

### Category coverage: no SMG, no LMG

v1.0 intentionally ships with only **shotgun, AR full-auto, semi-auto AR, sniper** primary categories. Skipped:

- **SMG** - Reflex archetype leans on shotgun + Phase Step instead. Kuda-class SMGs are a post-1.0 add.
- **LMG** - **M60 (`t9_m60`) + RPD (`t9_rpd`)** (added 2026-06-19 as Skye BO2 ports; **SWAPPED 2026-06-26 to
  Cold War (BOCW, `t9`) models** — same gun, stats grafted from the BO2 originals via `graft_cw_weapon_stats.js`;
  the old Skye-LMG uncompiled-model caveat no longer applies — the `t9` models compile clean).
  Box-only, twin-less. Balanced **M60 0.20 (~580, S) / RPD 0.125 (~421, C)** in `_acc_damage` (per the 2026-06-21
  tier-curation pass: M60 → S, RPD → C "the bad LMG"; RPD given a **+25% damage buff** user 2026-06-25, 0.10→0.125 — its
  PaP-price/box-odds scoring in docs/54 still uses the pre-buff ~337 DPS and was deliberately not recomputed; see CHANGELOG and the tier table above). **Ammo cut hard** (user 2026-06-19, was wildly over): clip 60 / reserve
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

**7. AK-47 (strong, box) — ✅ LIVE** (Skye **BO2 `t6_ak47`**, added 2026-06-14, see docs/33). Full-auto AR, the AR jackpot. Balance **×0.227** (raw 200 dmg @ 750 RPM — highest in the box pool; **swapped to the TOP tier with the AK-74u, 2026-06-26** → ~568 effDPS, now the #3 gun by PaP score). Ability: **Focus Fire** (next 6 shots auto-crit 4×, 25s cd). Overclock family: **ar** (Burst Coil / Overpressure / Piercing / Adaptive / Overheat / Subcritical). PaP placeholder: **"Reznov's Revenge"** (homage to the BO1 easter egg). _Import notes: most-ported weapon in CoD history; we used TheSkyeLord's BO2 port._

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

Both tracks apply independently. A weapon at **PaP T3 + Tier 5** has +100% PaP damage (×2.0, double), the upgraded "_up" form, 5 active Overclocks, and its ability is available from round 1 on cooldown.

### Pack-a-Punch Tiers (money) — 3-tier system (revamp 2026-06-16; per-gun pricing 2026-06-23)

Three tiers — **linear: each pack adds +33.33% of base** (×1.3333 / ×1.66666 / ×1.999999 = +33% / +67% / +100%
over base; T3 MAX = double damage). **The actual
PaP transform (the upgraded "_up" form — explosive, akimbo, etc.) is DEFERRED to tier 2:** tier 1
is a pure **damage** pack that keeps the base gun's appearance/behavior, so the transform is a
deliberate second investment. (Gold PaP camo removed 2026-06-27 — no longer a feature.)

**Cost is PER-GUN by PRICE TIER (user 2026-06-23).** Each gun is ranked by how good it is *at its
fully-packed ceiling* (the docs/05 score computed on its **PaP-form** stats), and the ranking is
split into thirds — **TOP / MID / BOT** — so the better the packed gun, the more it costs to pack.
The price tier per gun, the ranking, and the generator are in **[docs/54_pap_pricing_tiers.md](54_pap_pricing_tiers.md)**
(regenerate with `node tools/compute_gun_tiers.js`; it emits the GSC `pap_price_bucket()` /
`tier_cost()` pasted into `_acc_pap_levels.gsc`). The 10% Armory discount applies to every tier.

| Price tier (rank third) | T1 (+33%) | T2 (+67%, transform) | T3 (+100%, MAX) | Cumulative |
|---|--:|--:|--:|--:|
| **TOP** (Tac-19, M60, MORS, AK-47, PPSH-41, Thundergun) | 5,000 | 7,500 | 10,000 | **22,500** |
| **MID** (AE4, RW1, AK-74u, ASM1, Galil, Mahem) | 4,000 | 6,000 | 8,000 | **18,000** |
| **BOT** (Paladin HB50, Five-Seven, RPD, MK14, Olympia) | 3,000 | 4,500 | 6,000 | **13,500** |

> Action Figure (melee) has no `_up` form but **PaPs IN PLACE** at the TOP-bucket tier price (5000/7500/10000) — each PaP tier scales **SWING SPEED** (+100/200/300%, speed twins WIP), not targets (the old cleave was removed 2026-06-27).

- **"% is the only damage lever":** `acc_weapon_balance_mult` (`_acc_damage.gsc`) normalizes every
  form (base / `_up` / perk-twin) per gun by substring match, so the `_up` form's own higher raw
  damage doesn't double-count — the +33/67/100% ladder (linear, +1/3 base per pack) IS the PaP damage progression. The `_up`
  transform's *functional* identity (explosive splash, akimbo, etc.) still applies on top.
- All tiers applied at the Pack-a-Punch machine in the Lab — one machine, three interactions.
- Buying T2 requires T1, T3 requires T2. A weapon cannot skip tiers.
- **Packing is instant + in-place on every tier** — no gun-into-machine float/animation (user
  2026-06-14). Holding Use packs the held gun right there: T1 just adds damage, T2 swaps to the `_up`
  form, T3 bumps damage. Every tier replays the first-pack in-hand draw. The gun **only ever
  changes when you actually pack** — walking near the machine never swaps it.
- **Perk weapon-variant twins + PaP (twins follow tiers):** if you're holding a perk twin
  (Deadshot recoil, Gun Slinger fire+swap, Speed Cola reload), tier 1 keeps you on the **base-form**
  twin; tier 2 transforms you to the matching **packed `_up` twin** in one step, keeping
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
| Sniper | Paladin HB50, MORS, MK14 | **Precision Mode** | 30s | Next **3** shots auto-crit (4×, ignore hit-loc) |
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

- **Deadshot** (3,500): +1.3 headshot damage bonus (American Sniper Mega: +1.5) + auto-aim to head on ADS. **Added** (not multiplied) into the crit/headshot bonus pool, which is then scaled by the map headshot temper (`locHead × 0.5` trash / `× 0.6` boss = ×2.5/×3 on a locHead-5.0 gun). Keystone for precision builds (MORS, Paladin HB50, MK14).
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
