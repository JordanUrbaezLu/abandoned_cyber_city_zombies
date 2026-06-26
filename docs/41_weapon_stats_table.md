# 41 — Weapon Stats Table (base + Pack-a-Punch)

Live stats for every box gun, **base and PaP (`_up`) form**, generated from the deployed GDTs
2026-06-16. This is a snapshot reference — regenerate after any ammo/recoil/damage retune.

## How to read this

- **Reserve** = `clip × mags` (in BO3 GDTs `maxAmmo` is a *magazine* count, so in-game reserve
  rounds = mags × clip).
- **RPM** = `60 / fireTime`. For Single-Shot guns it's the firing *cap*, not sustained.
- **Eff/shot** = raw GDT `damage` × the per-gun balance multiplier (`_acc_damage::acc_weapon_balance_mult`).
  This is the **body-shot** damage the engine actually deals, *before* the layers below.
- **~DPS** = `Eff/shot × RPM/60` (full-auto, body shots). Shown for autos only.
- **Reload** = tactical / empty seconds.

### Layers NOT in the table (applied on top at runtime)
- **Headshot:** ×5 (stock ~1.5 GDT × our +2.0 map bonus, summed) on most guns. **Shotguns
  (Tac-19, Olympia) are headshot-excluded** — flat damage, hence their high per-pellet mults.
- **PaP damage ladder:** PaP adds **+20% → +100%** over tiers L1–L5 *on top of* the `_up` form's
  stats below. Note most guns bump raw `damage` in the `_up` GDT (e.g. AK-47 200→300) **and** get
  the ladder; **Paladin's `_up` raw is unchanged (1000)** so its PaP damage comes only from the ladder.
- **Perks:** Mega Deadshot −50% recoil; Gun Slinger +45% RoF & −50% weapon-swap; Sleight +75% reload; Double Tap
  +33% RoF (base) + 2 bullets/shot; etc.
- **Base recoil:** the 10 twin guns sit at **1.75× vanilla** baseline (skill theme); Mega Deadshot
  brings that to **0.875×**.

---

## Pistols

| Gun / form | Fire | Clip | Reserve | RPM | Reload (t/e) | Raw→min dmg | ×Mult | Eff/shot |
|---|---|---|---|---|---|---|---|---|
| **Five-Seven** (start) | Semi | 14 | 84 | 750 | 1.63 / 1.8 | 200→150 | ×0.30 | **60** |
| Five-Seven — PaP | Semi | 21 | 147 | 750 | 1.63 / 1.8 | 350→320 | ×0.30 | **105** |
| **M1911** | Semi | 6 | 60 | ~940 | 1.5 / 1.85 | 20 | ×4.375 | **~88** |
| M1911 — PaP *(akimbo, explosive)* | Semi | 8 | 80 | 600 | 1.5 / 1.5 | 7000 *(direct + splash)* | ×0.50 | **3500** |

## SMGs

| Gun / form | Fire | Clip | Reserve | RPM | Reload (t/e) | Pen | Raw→min | ×Mult | Eff/shot | ~DPS |
|---|---|---|---|---|---|---|---|---|---|---|
| **ASM1** | Auto | 22 | 132 | 674 | 1.8 / 2.1 | medium | 170→140 | ×0.21 | 35.7 | **~401** |
| ASM1 — PaP | Auto | 36 | 288 | 870 | 1.8 / 2.1 | medium | 270→240 | ×0.21 | 56.7 | ~822 |
| **AK-74u** | Auto | 20 | 160 | 750 | 2.1 / 2.8 | medium | 180→170 | ×0.225 | 40.5 | **~506** |
| AK-74u — PaP | Auto | 40 | 280 | 750 | 2.1 / 2.8 | medium | 260→250 | ×0.225 | 58.5 | ~731 |
| **PPSH-41** | Auto | 25 | 225 | 952 | 2.5 / 3.5 | medium | 155→140 | ×0.17 | 26.4 | **~418** |
| PPSH-41 — PaP | Auto | 39 | 351 | 1250 | 2.5 / 3.5 | medium | 280→240 | ×0.17 | 47.6 | ~992 |
| **Chicom CQB** *(3-rd burst)* | Burst | 36 | 180 | 1250¹ | 2.1 / 2.7 | medium | 130→110 | ×0.25 | 32.5 | **~497** |
| Chicom CQB — PaP *(4-rd auto-burst)* | Burst | 56 | 448 | 1250¹ | 2.1 / 2.7 | medium | 250→225 | ×0.25 | 62.5 | ~1025 |

> ¹ Chicom RPM is the **within-burst** rate (`60 / 0.048s`). Real sustained fire is lower — the 0.1s inter-burst
> delay is already folded into the **~DPS** (3 rds / 0.196s base, 4 rds / 0.244s PaP). It's the box's **S+ #2 gun**
> (PaP score 8.05, docs/54): strong burst damage + generous **uncut** ammo (clip 36/56), TOP price, ~2.4% rare roll.
| **PDW-57** | Auto | 11 | 132 | 750 | 2.0 / 2.1 | small | 120→90 | ×0.33 | 39.6 | **~495** |
| PDW-57 — PaP *(akimbo)* | Auto | 17 | 306 | 923 | 2.86 | small | 340→290 | ×0.33 | 112.2 | ~1726 *(dual)* |

## Assault Rifles

| Gun / form | Fire | Clip | Reserve | RPM | Reload (t/e) | Pen | Raw→min | ×Mult | Eff/shot | ~DPS |
|---|---|---|---|---|---|---|---|---|---|---|
| **Ripper** *(SMG mode)* | Auto | 22 | 220 | 968 | 3.1 / 3.33 | medium | 140→120 | ×0.25 | 35 | **~565** |
| Ripper — PaP | Auto | 34 | 340 | 968 | 3.1 / 3.33 | medium | 250→240 | ×0.25 | 62.5 | ~1008 |
| **AK-47** | Auto | 21 | 168 | 750 | 2.5 / 3.25 | medium | 200→175 | ×0.184 | 36.8 | **~460** |
| AK-47 — PaP | Auto | 31 | 279 | 750 | 2.5 / 3.25 | medium | 300→275 | ×0.184 | 55.2 | ~690 |
| **AE4** | Auto | 25 | 200 | 500 | 2.0 / 2.0 | medium | 160→130 | ×0.38 | 60.8 | **~507** |
| AE4 — PaP | Auto | 38 | 304 | 500 | 2.0 / 2.0 | medium | 290→260 | ×0.38 | 110.2 | ~918 |
| **Galil** | Auto | 25 | 225 | 750 | 2.25 / 2.93 | medium | 220→200 | ×0.1785 | 39.3 | **~491** |
| Galil — PaP | Auto | 35 | 420 | 800 | 2.25 / 2.93 | medium | 340→310 | ×0.1785 | 60.7 | ~809 |
| **Nail Gun** *(projectile)* | Auto | 30 | 210 | 382 | 2.6 / 2.6 | — | 250 | ×0.37 | 92.5 | **~58V9** |
| Nail Gun — PaP | Auto | 40 | 320 | 451 | 2.6 / 2.6 | — | 600 | ×0.37 | 222 | ~1669 |

## Shotguns *(per-pellet; headshot-excluded; multiply Eff/shot × pellets for a full point-blank hit)*

| Gun / form | Fire | Clip | Reserve | RPM | Reload (t/e) | Pellets | Pen | Full / Min range (u) | Raw | ×Mult | Eff/pellet |
|---|---|---|---|---|---|---|---|---|---|---|---|
| **Tac-19** | Single | 4 | 48 | 200 | 0.467 (auto-charge) | 8 | large | 825 / 1350 | 149 | ×0.612 | **91** (~730/shot) |
| Tac-19 — PaP | Single | 7 | 84 | 200 | 0.467 | 12 | large | 825 / 1650 | 217 | ×0.612 | **133** (~1595/shot) |
| **Olympia** | Single | 2 | 26 | 212 | 3.3 / 3.9 | 8 | small | 550 / 900 | 110 | ×0.489 | **54** (~430/shot) |
| Olympia — PaP | Single | 2 | 42 | 212 | 2.0 / 2.5 | 12 | small | 650 / 1000 | 260 | ×0.489 | **127** (~1526/shot) |

> **Shotgun damage nerf (user 2026-06-25, max-scale outlier fix):** Tac-19 ×0.68→**0.612** (−10%), Olympia
> ×0.9775→**0.489** (−50%). At full PaP+Overclock the 12-pellet stack × ×4 bonus had ballooned Olympia to
> ~33k/shot / 100k/head (6–18× every other gun). `node tools/gun_maxscale_table.js` to re-check the ceiling.

## Sniper

| Gun / form | Fire | Clip | Reserve | RPM | Reload (t/e) | Pen | Full / Min range (u) | Raw | ×Mult | Eff/shot |
|---|---|---|---|---|---|---|---|---|---|---|
| **MORS** | Single (charge) | 1 | 120 | — | 1.2 / 1.2 | large | — | 1000 | ×0.66 | **660** |
| MORS — PaP | Single (charge) | 1 | 180 | — | 1.2 / 1.2 | large | — | 2000 | ×0.66 | **1320** + PaP ladder |
| **Paladin HB50** | Single | 8 | 96 | 200 | 3.56 / 4.13 | large | 9000 / 16000 | 1000 | ×0.49 | **490** |
| Paladin HB50 — PaP | Single | 11 | 132 | 200 | 3.56 / 4.13 | large | 9000 / 16000 | 1000 *(ladder only)* | ×0.49 | **490** + PaP ladder |

> *Sniper swap 2026-06-24:* MORS **B → S** (`×0.49 → 0.66`, reserve 60/90 → 120/180); Paladin HB50 **low-S → B** (`×0.70 → 0.49`, clip/reserve unchanged). MORS RPM/range cells left `—` (not re-captured from the GDT). Canonical tiers/odds: docs/05 + docs/54.
>
> *Paladin headshot fix 2026-06-26:* the BO4-port GDT shipped `locHead 1.0`, so headshots dealt **0.5× body** (backwards). Set to `locHead 5.0` (base + `_up` + 14 twins, `tools/fix_paladin_loc.js`) → proper **2.5× body** headshot, matching every other non-shotgun. At full PaP+OC: **13,475/head vs 5,390 body** (was 2,695/head).

---

## Notes
- **Twin guns (perk handling):** all 10 above except Ripper/Nail/PDW/M1911 carry recoil(Mega
  Deadshot)/fire+swap(Gun Slinger)/reload(Sleight) twins. The 4 exceptions use runtime Armory + base
  perks only (structural: altWeapon/projectile/akimbo).
- **M1911 / PDW PaP are akimbo** (two weapons fired together) — their effective output is roughly
  double the single-gun number; M1911's PaP is an explosive (Mustang-&-Sally style).
- **Eff/shot is body damage pre-headshot.** Multiply by ~5 for headshots on non-shotguns. PaP rows
  are pre-ladder (add +20%→+100% for L1–L5).
- Source of truth: GDTs in `<tools>\source_data\skye_*.gdt` (ammo via `tools/reduce_base_ammo.js`,
  recoil/twins via `tools/apply_recoil_overhaul.js`); mults in `_acc_damage::acc_weapon_balance_mult`.
