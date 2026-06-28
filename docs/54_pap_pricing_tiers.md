# 54 - Pack-a-Punch Pricing & Mystery-Box Odds

> **GENERATED FILE - do NOT hand-edit.** Regenerate with `node tools/compute_gun_tiers.js`
> after adding/removing/retuning any gun. Source of truth: [tools/compute_gun_tiers.js](../tools/compute_gun_tiers.js).
> Consumers: `_acc_pap_levels.gsc` (`pap_price_bucket`/`tier_cost`) + `_acc_map_randomizer.gsc` (`acc_box_weight`).

## The rule

A gun's PaP cost **and** its box rarity both scale with how good it is **at its packed
ceiling** - you pay more to upgrade a stronger gun, and you roll it less often.

1. Each scoreable gun is scored by the docs/05 "v2 sustain" formula on its **PaP T3
   form stats** (PaP magazine + reserve; DPS is the uniform-scaled base value).
2. Guns are **ranked best -> worst** and split into **thirds**: top third = **TOP**
   (most expensive PaP, rarest roll), middle = **MID**, bottom = **BOT** (cheapest, commonest).
3. Hand **overrides** pin a gun; non-scoreable **specials** (wonder weapon, launcher) are
   placed by hand; guns with **no PaP form** are excluded from pricing but still get a box weight.

Relative split -> add/remove a gun and the tercile boundaries reshuffle automatically.

| Price tier | PaP cost T1 / T2 / T3 | Cumulative | Box weight (higher = commoner) |
|---|---|--:|---|
| **TOP** | 5000 / 7500 / 10000 | 22,500 | 12 (rare) · WW = 3 |
| **MID** | 4000 / 6000 / 8000 | 18,000 | 29 |
| **BOT** | 3000 / 4500 / 6000 | 13,500 | 50 (common) |

## Current ranking (16 scoreable + 3 special + 0 excluded; box pool 19, total weight 463)

| Rank | Gun | Class | PaP score | Price tier | PaP cost T1/T2/T3 | Box weight (~roll) |
|--:|---|---|--:|:--:|---|---|
| 1 | **Chicom CQB** | SMG | 8.18 | **TOP** | 5000 / 7500 / 10000 | 8 (~1.7%) |
| 2 | **M60** | LMG | 8.11 | **TOP** | 5000 / 7500 / 10000 | 8 (~1.7%) |
| 3 | **AK-47** | AR | 8.04 | **TOP** | 5000 / 7500 / 10000 | 8 (~1.7%) |
| 4 | **PPSH-41** | SMG | 8.00 | **TOP** | 5000 / 7500 / 10000 | 8 (~1.7%) |
| 5 | **Tac-19** | Shotgun | 7.74 | **TOP** | 5000 / 7500 / 10000 | 8 (~1.7%) |
| 6 | **MORS** | Sniper | 7.50 | **TOP** | 5000 / 7500 / 10000 | 12 (~2.6%) |
| 7 | **AE4** | AR | 7.19 | **MID** | 4000 / 6000 / 8000 | 29 (~6.3%) |
| 8 | **RW1** | Pistol | 7.15 | **MID** | 4000 / 6000 / 8000 | 29 (~6.3%) |
| 9 | **AK-74u** | SMG | 7.03 | **MID** | 4000 / 6000 / 8000 | 29 (~6.3%) |
| 10 | **ASM1** | SMG | 7.02 | **MID** | 4000 / 6000 / 8000 | 29 (~6.3%) |
| 11 | **Galil** | AR | 6.85 | **MID** | 4000 / 6000 / 8000 | 29 (~6.3%) |
| 12 | **Paladin HB50** | Sniper | 6.31 | **BOT** | 3000 / 4500 / 6000 | 50 (~10.8%) |
| 13 | **RPD** | LMG | 6.10 | **BOT** | 3000 / 4500 / 6000 | 50 (~10.8%) |
| 14 | **Five-Seven** | Pistol | 5.99 | **BOT** | 3000 / 4500 / 6000 | 50 (~10.8%) |
| 15 | **MK14** | DMR | 5.89 | **BOT** | 3000 / 4500 / 6000 | 29 (~6.3%) |
| 16 | **Olympia** | Shotgun | 3.67 | **BOT** | 3000 / 4500 / 6000 | 50 (~10.8%) |
| — | **Thundergun** | special | — | **TOP** ² | 5000 / 7500 / 10000 | 3 (~0.6%) |
| — | **Mahem** | special | — | **MID** ² | 4000 / 6000 / 8000 | 29 (~6.3%) |
| — | **Action Figure** | special | — | **TOP** ² | 5000 / 7500 / 10000 | 5 (~1.1%) |

¹ hand override (pinned despite rank tercile). ² special (outside the formula, tier set by hand).
³ no `_up` form -> can't be Pack-a-Punched; still rolls from the box at the listed weight.

**Price tiers:** TOP = Chicom CQB, M60, AK-47, PPSH-41, Tac-19, MORS, Thundergun (special), Action Figure (special) · MID = AE4, RW1, AK-74u, ASM1, Galil, Mahem (special) · BOT = Paladin HB50, RPD, Five-Seven, MK14, Olympia


## GSC #1 - paste into `_acc_pap_levels.gsc` (between the BEGIN/END GENERATED markers)

```gsc
function pap_price_bucket( weapon_name )
{
    if ( !isdefined( weapon_name ) ) return "BOT";

    // TOP  (5000 / 7500 / 10000)
    if ( IsSubStr( weapon_name, "thundergun" ) )        return "TOP";   // Thundergun (special)
    if ( IsSubStr( weapon_name, "t8_melee_figure" ) )   return "TOP";   // Action Figure (special)
    if ( IsSubStr( weapon_name, "t6_chicom_cqb" ) )     return "TOP";   // Chicom CQB (PaP 8.18)
    if ( IsSubStr( weapon_name, "t9_m60" ) )            return "TOP";   // M60 (PaP 8.11)
    if ( IsSubStr( weapon_name, "t9_ak47" ) )           return "TOP";   // AK-47 (PaP 8.04)
    if ( IsSubStr( weapon_name, "s4_ppsh41" ) )         return "TOP";   // PPSH-41 (PaP 8.00)
    if ( IsSubStr( weapon_name, "s1_tac19" ) )          return "TOP";   // Tac-19 (PaP 7.74)
    if ( IsSubStr( weapon_name, "s1_mors" ) )           return "TOP";   // MORS (PaP 7.50)

    // MID  (4000 / 6000 / 8000)
    if ( IsSubStr( weapon_name, "s1_mahem" ) )          return "MID";   // Mahem (special)
    if ( IsSubStr( weapon_name, "s1_ae4" ) )            return "MID";   // AE4 (PaP 7.19)
    if ( IsSubStr( weapon_name, "s1_rw1" ) )            return "MID";   // RW1 (PaP 7.15)
    if ( IsSubStr( weapon_name, "t9_ak74u" ) )          return "MID";   // AK-74u (PaP 7.03)
    if ( IsSubStr( weapon_name, "s1_asm1" ) )           return "MID";   // ASM1 (PaP 7.02)
    if ( IsSubStr( weapon_name, "t6_galil" ) )          return "MID";   // Galil (PaP 6.85)

    // BOT  (3000 / 4500 / 6000)
    if ( IsSubStr( weapon_name, "t8_paladin_hb50" ) )   return "BOT";   // Paladin HB50 (PaP 6.31)
    if ( IsSubStr( weapon_name, "t9_rpd" ) )            return "BOT";   // RPD (PaP 6.10)
    if ( IsSubStr( weapon_name, "t6_fiveseven" ) )      return "BOT";   // Five-Seven (PaP 5.99)
    if ( IsSubStr( weapon_name, "s1_mk14" ) )           return "BOT";   // MK14 (PaP 5.89)
    if ( IsSubStr( weapon_name, "t6_olympia" ) )        return "BOT";   // Olympia (PaP 3.67)

    return "BOT";   // default: cheapest tier (also covers the no-PaP Action Figure)
}

// Per-step PaP cost: price tier x PaP tier (1..3). docs/54.
function tier_cost( bucket, tier )
{
    if ( bucket == "TOP" )
    {
        switch ( tier ) { case 1: return 5000; case 2: return 7500; case 3: return 10000; }
    }
    else if ( bucket == "MID" )
    {
        switch ( tier ) { case 1: return 4000; case 2: return 6000; case 3: return 8000; }
    }
    else   // "BOT" and default
    {
        switch ( tier ) { case 1: return 3000; case 2: return 4500; case 3: return 6000; }
    }
    return 0;
}
```

## GSC #2 - paste into `_acc_map_randomizer.gsc` (between the BEGIN/END GENERATED markers)

Box weight: higher = commoner roll (best guns rarest). Matched by EXACT box-pool name (`==`),
re-normalized live as you collect guns (the box never repeats one you own).

```gsc
function acc_box_weight( wpn )
{
    if ( !isdefined( wpn ) || !isdefined( wpn.name ) ) return 5;
    n = wpn.name;
    if ( n == "thundergun" ) return 3;   // ~0.6% each - Thundergun
    if ( n == "t8_melee_figure" ) return 5;   // ~1.1% each - Action Figure
    if ( n == "t6_chicom_cqb" || n == "t9_m60" || n == "t9_ak47" || n == "s4_ppsh41_base" || n == "s1_tac19" ) return 8;   // ~1.7% each - Chicom CQB, M60, AK-47, PPSH-41, Tac-19
    if ( n == "s1_mors" ) return 12;   // ~2.6% each - MORS
    if ( n == "s1_ae4" || n == "s1_rw1" || n == "t9_ak74u" || n == "s1_asm1" || n == "t6_galil" || n == "s1_mk14" || n == "s1_mahem" ) return 29;   // ~6.3% each - AE4, RW1, AK-74u, ASM1, Galil, MK14, Mahem
    if ( n == "t8_paladin_hb50" || n == "t9_rpd" || n == "t6_fiveseven" || n == "t6_olympia" ) return 50;   // ~10.8% each - Paladin HB50, RPD, Five-Seven, Olympia
    return 5;   // unknown -> mid
}
```

## How to rebalance after a roster change

1. Edit the `GUNS` / `SPECIALS` / `EXCLUDED` tables in
   [tools/compute_gun_tiers.js](../tools/compute_gun_tiers.js). PaP clip/reserve come from
   the gun's Skye GDT `_up` entry: reserve = `maxAmmo` x `clipSize`.
2. Run `node tools/compute_gun_tiers.js` (regenerates THIS doc).
3. Paste **GSC #1** into `_acc_pap_levels.gsc` and **GSC #2** into `_acc_map_randomizer.gsc`
   (each between its `<<< BEGIN/END GENERATED >>>` markers).
4. Rebuild GSC-only: `.\tools\build_map.ps1 -GscOnly`.

## Notes

- **PaP DPS = base value** (PaP scales DPS ~x2.5 *uniformly*; only PaP clip/reserve move).
- **\* curated DPS**: snipers scored single-target, shotguns on crowd (docs/05 special rules).
- **RW1** shipped clipSize 1 (single-shot charge) which scored ~B; hand-tuned to a real magazine
  (clip 8 base / 12 PaP via reduce_base_ammo CLIP_FIX) so it earns A (~7.15).
- PaP-form clip/reserve GDT-verified (workflow `pap-form-gdt-stats`, 2026-06-23).
