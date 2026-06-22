# docs/46 — The Trench: what each thing does (high level)

**The one-liner:** the underground trench is the dangerous place where **Data Shards** are both
**earned** and **spent**. You descend, brave the amped horde, grab shards, and turn them into
permanent power. Points keep you alive *this* round; shards are how you get strong enough to
survive the next twenty.

> Scope note: this is the **systems** view (what each interactable does). The underground
> **geometry/layout** (rooms, lighting, the "Black Market" rework) lives in
> [docs/45](45_underground_blackmarket_design.md). Economy detail is in
> [docs/06](06_mechanics.md); perks in [docs/13](13_perks.md).

## How you get down there
- Buy into the **Bus Station** (corp zone) — two doors, 1000 each, no power needed.
- **Drop into the open pit** (stairs on each side, or just jump in). The pit is the exposed
  danger zone. The **Foundry room** opens off the pit through a buyable door (1500).

## The danger (why it's a risk)
While anywhere underground you get **amped zombies** (faster + hit harder + tankier, scaling **+5% move / +25% health / +10 HP melee per layer** the deeper you go), a **−20% move slow**, a
**spawn surge on entry**, and a small **fall tax** if you dive in. The reward has to be worth it —
that's everything below.

## The things in the trench

**Economy is small on purpose (user 2026-06-19): 1 shard matters.** Shard cap = **50** (raised from 30 so the
deepest single purchase fits — Exo Suit T5 = 25, gun Overclock T5 = 24; see [docs/47](47_exo_suit_plan.md)).
All numbers are tight and even.

| Thing | Where | What it does | Shards |
|---|---|---|---|
| **Data Caches** ×2 | Exposed pit | Main shard **source** — **1 shard each**, once per round, to whoever loots it first (re-arms each round). | **+1** each |
| **Trench Warden** (Brutus) | Near the trench | The signature boss; killing him gives **everyone +2 shards**. | **+2** all |
| **Reactor Plinth** | Pit (north) | The climax: **activate once per round** (free) → **survive a zombie surge** → **everyone +3 shards + a shared Insta-Kill**. | **+3** all |
| **Neural Expansion Bay** | Pit (west) | The marquee buy: **+1 perk slot** (start at 4, up to 9). | spend (4/6/8/10/12) |
| **Glitch Altar** | Foundry room | **Gamble 2 shards/spin** for a weighted result: usually a boon (free perk / Insta-Kill / Max Ammo / Double Points / +3 jackpot / rare ~1% Mega Win), sometimes a curse (surge / −2 drain / dud). Net-negative, can't be farmed. | spend (2/spin) |
| **Cyberware Weapon Overclock** | Foundry room | **Upgrade the gun you're holding** (per-gun) across 5 tiers. Each tier gives a **small boost to 3 effects at once** — flat damage, glitch piercing (vs glitch zombies), headshot ammo-refund — minimal at T1, full at T5. *(Replaced the old Cyberware tree.)* | spend (2/4/8/16/24) |
| **Exo Suit** | Pit (east) | **Per-player**, 5 tiers. Each tier lets you walk **normal speed one trench layer deeper** (the trench slows you more each layer down — the Exo Suit is the only thing that cancels it). The key to reaching the deep layers. | spend (5/10/15/20/25) |

## Cyberware Weapon Overclock — exact effects

**Per-gun** (the weapon you're holding; carries through Pack-a-Punch). **5 tiers**, cost
**2 / 4 / 8 / 16 / 24** shards (54 to max one gun). Each tier raises **all three effects a little** —
minimal at T1, full at T5. Every number below is a live dvar.

### 1. Flat Damage (`acc_oc_dmg_per_tier`, default 0.05)
More damage **all the time** — hipfire and ADS (gun hits, not melee). Stacks additively on top of headshots / PaP.

| Tier | T1 | T2 | T3 | T4 | T5 |
|---|---|---|---|---|---|
| Damage | +5% | +10% | +15% | +20% | **+25%** |

### 2. Glitch Piercing (`acc_oc_glitch_per_tier`, default 0.25)
Bonus damage against **glitch zombies** — the **Glitch Stalker** + the **lockdown-challenge glitch zombies**
(tanky, so this melts them). Normal zombies unaffected.

| Tier | T1 | T2 | T3 | T4 | T5 |
|---|---|---|---|---|---|
| Bonus dmg vs glitch zombies | +25% | +50% | +75% | +100% | **+125%** |

### 3. Ammo Refund (`acc_oc_adaptive_per_tier`, default 0.10)
Every **headshot KILL** has a chance to **return 1 round to your magazine** (capped at mag size). *(user 2026-06-21: gated to headshot KILLS, not just headshot hits — you have to drop the zombie with the head hit.)*

| Tier | T1 | T2 | T3 | T4 | T5 |
|---|---|---|---|---|---|
| Refund chance per headshot **kill** | 10% | 20% | 30% | 40% | **50%** |

> **Not adjustable at runtime:** fire rate, reload, mobility are baked weapon stats — the overclock works on
> **damage and on-hit behavior**.

## Exo Suit — the trench depth gate (docs/47)

**Per-player**, **5 tiers** (cost **5 / 10 / 15 / 20 / 25** Data Shards), bought at the Exo Station in the pit.
The trench descends in **5 layers**, each slower than the last. Your exo tier cancels the slow **down to that
layer**: tier T = normal speed in layers 1..T; below that, **−20% at the first uncovered layer, then −10% per
layer deeper**. So you buy exo tiers to reach — and actually fight in — the deeper, richer layers.

| Your tier ↓ / layer → | L1 (Bus Stn) | L2 | L3 | L4 | L5 |
|---|---|---|---|---|---|
| **0** | −20% | −30% | −40% | −50% | −60% |
| **1** | 0 | −20% | −30% | −40% | −50% |
| **2** | 0 | 0 | −20% | −30% | −40% |
| **3** | 0 | 0 | 0 | −20% | −30% |
| **4** | 0 | 0 | 0 | 0 | −20% |
| **5** | 0 | 0 | 0 | 0 | 0 |

*Layer 1 = the Bus Station trench today; layers 2–5 light up as the geometry is built. Boots give +8% move but
no longer cancel the slow — only the Exo Suit does.*

## The loop
**Descend → loot the pit caches → spend at the Foundry (cyberware, overclocks, gamble) and the Bay
(perk slots) → arm the Reactor for the big score → come back stronger and do it again at a higher
tier.** Every shard is earned and spent underground — that's the pull into the trench.

## Tuning (for testing)
- Real economy (not the dev firehose): `acc_dev_shards 0`, `acc_dev_perks 0`.
- All trench feedback text height: `acc_msg_y` (smaller = higher), `acc_msg_sec` = how long it holds.
- Per-thing knobs live in each module (`acc_cache_*`, `acc_altar_*`, `acc_perk_slot_*`, `acc_reactor_*`,
  `acc_warden_shard_reward`); see the module headers.
