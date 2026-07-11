# 54 - Pack-a-Punch Pricing & Mystery-Box Odds

> **GENERATED FILE - do NOT hand-edit.** Regenerate with `node tools/gen_box_dynamic.js`
> after adding/removing/retuning any gun (it prints the two GSC functions to paste AND
> rewrites this doc). Source of truth: [tools/gen_box_dynamic.js](../tools/gen_box_dynamic.js)
> (supersedes `compute_gun_tiers.js` for pricing/odds since 2026-07-05).
> Consumers: `_acc_pap_levels.gsc` (`pap_price_bucket`/`tier_cost`) + `_acc_map_randomizer.gsc` (`acc_box_weight`).

## The rule

Every box entry sits on a hand-curated power RANKING (best -> worst). A gun's PaP cost and its
box rarity both scale with that rank - you pay more to upgrade a stronger gun, and you roll it
less often.

- **Rare specials are FIXED per-open % targets** (user 2026-07-09): the 4 wonder weapons
  (Thundergun / Blast-O-Matic / Fire Bow / Leviathan Axe) pin at **0.3%**, the Action Figure at
  **0.8%**, the Havoc at **1.2%**. Their weights are solved against the gun-curve total.
- **Guns ride a geometric curve**: 11%/step from the best (rank 6, rarest) to the worst (commonest).
- **PaP price tier by rank band** (+ per-gun user overrides, carried in the RANK table).
- The box draw first runs the FIXED tactical pre-roll (**Monkey Bomb 1.0% + Li'l Arnie 0.5%**);
  the remaining 98.5% is the weighted gun pick, so per-open % = weight/total x 0.985.
- The box never repeats a gun you own -> live odds re-normalize as you collect.

| Price tier | PaP cost T1 / T2 / T3 | Cumulative |
|---|---|--:|
| **WONDER** | 10000 / 15000 / 20000 | 45,000 |
| **TOP** | 5000 / 7500 / 10000 | 22,500 |
| **MID** | 4000 / 6000 / 8000 | 18,000 |
| **BOT** | 3000 / 4500 / 6000 | 13,500 |

## Current ranking (29 box entries, pool total weight 4901)

| Rank | Weapon | Price tier | PaP cost T1/T2/T3 | Box weight | Per-open % |
|--:|---|:--:|---|--:|--:|
| 1 | **Thundergun** (special) | **WONDER** | 10000 / 15000 / 20000 | 15 | 0.30% |
| 2 | **Blast-O-Matic** (special) | **WONDER** | 10000 / 15000 / 20000 | 15 | 0.30% |
| 3 | **Fire Bow** (special) | **WONDER** | 10000 / 15000 / 20000 | 15 | 0.30% |
| 4 | **Leviathan Axe** (special) | **WONDER** | 10000 / 15000 / 20000 | 15 | 0.30% |
| 5 | **Action Figure** (special) | **TOP** | 5000 / 7500 / 10000 | 40 | 0.80% |
| 6 | **XM4** | **TOP** | 5000 / 7500 / 10000 | 52 | 1.05% |
| 7 | **Peacekeeper** | **TOP** | 5000 / 7500 / 10000 | 58 | 1.17% |
| 8 | **AK-47** | **TOP** | 5000 / 7500 / 10000 | 64 | 1.29% |
| 9 | **M60** | **TOP** | 5000 / 7500 / 10000 | 71 | 1.43% |
| 10 | **PPSH-41** | **TOP** | 5000 / 7500 / 10000 | 79 | 1.59% |
| 11 | **Havoc** (special) | **TOP** | 5000 / 7500 / 10000 | 60 | 1.21% |
| 12 | **Mahem** (special) | **TOP** | 5000 / 7500 / 10000 | 88 | 1.77% |
| 13 | **War Machine** (special) | **TOP** | 5000 / 7500 / 10000 | 97 | 1.95% |
| 14 | **MORS** | **TOP** | 5000 / 7500 / 10000 | 108 | 2.17% |
| 15 | **Alternator** | **BOT** | 3000 / 4500 / 6000 | 120 | 2.41% |
| 16 | **AE4** | **MID** | 4000 / 6000 / 8000 | 133 | 2.67% |
| 17 | **RW1** | **MID** | 4000 / 6000 / 8000 | 148 | 2.97% |
| 18 | **CEL-3** | **TOP** | 5000 / 7500 / 10000 | 164 | 3.30% |
| 19 | **M16** | **MID** | 4000 / 6000 / 8000 | 182 | 3.66% |
| 20 | **MK14** | **MID** | 4000 / 6000 / 8000 | 202 | 4.06% |
| 21 | **Tac-19** | **MID** | 4000 / 6000 / 8000 | 224 | 4.50% |
| 22 | **AK-74u** | **MID** | 4000 / 6000 / 8000 | 249 | 5.00% |
| 23 | **Prowler** | **BOT** | 3000 / 4500 / 6000 | 276 | 5.55% |
| 24 | **Streetsweeper** | **BOT** | 3000 / 4500 / 6000 | 307 | 6.17% |
| 25 | **HAMR** | **MID** | 4000 / 6000 / 8000 | 340 | 6.83% |
| 26 | **RPD** | **MID** | 4000 / 6000 / 8000 | 378 | 7.60% |
| 27 | **Olympia** | **BOT** | 3000 / 4500 / 6000 | 419 | 8.42% |
| 28 | **Grav** | **BOT** | 3000 / 4500 / 6000 | 465 | 9.35% |
| 29 | **Five-Seven** | **BOT** | 3000 / 4500 / 6000 | 517 | 10.39% |
| - | Monkey Bomb (tactical pre-roll) | - | - | - | 1.00% |
| - | Li'l Arnie (tactical pre-roll) | - | - | - | 0.50% |

Lucky Horseshoe (Clover) box luck layers OVER these weights at draw time
(`acc_box_clover_weight`: rares +16 weight ~= +0.4%/open each, funded from the commons).

