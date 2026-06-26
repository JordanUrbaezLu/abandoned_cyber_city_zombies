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
While anywhere underground you get **amped zombies** (faster + hit harder + tankier, scaling **+5% move / +50% health / +10 HP melee per layer** the deeper you go), a **−20% move slow**, a
**spawn surge that erupts at YOUR current layer** (on entry, on descending to a new layer, and a continuous drip while you stay down — so the deeper layers populate as you reach them, not just the pit), and a small **fall tax** if you dive in. The reward has to be worth it —
that's everything below.

> Per-layer numbers (N = layer 1–5): move **+5%·N**, health **+50%·N** (on top of round HP), melee **+10·N flat HP** (base 45 → 55/65/75/85/95). Dvars: `acc_trench_layer_speed_pct` (5), `acc_trench_layer_hp_pct` (50), `acc_trench_layer_dmg_add` (10). Spawning: `spawn_corp_surge` reads each underground player's layer (`get_layer_risers`: L1 = map pit risers, L2–L5 = computed floor risers) and erupts there.

## The things in the trench

**Economy is small on purpose (user 2026-06-19): 1 shard matters.** Shard cap = **50** (raised from 30 so the
deepest single purchase fits — Exo Suit T5 = 25, gun Overclock T5 = 24; see [docs/47](47_exo_suit_plan.md)).
All numbers are tight and even.

| Thing | Where | What it does | Shards |
|---|---|---|---|
| **Data Caches** ×2 | Exposed pit | Main shard **source** — **+3 each** (user 2026-06-25: 2→3), once per round, to whoever loots it first (re-arms each round). **CO-OP anti-hog (user 2026-06-25): a player can loot only ONE of the two per round — grab one and the other must be taken by a teammate** (`acc_cache_one_per_player`; **solo is exempt** so the 2nd cache isn't wasted). A **dim white glow** on each crate = "shards available this round"; it **switches off the instant the cache is looted** and **comes back when it re-arms at round start** — an at-a-glance indicator (user 2026-06-24). | **+3** each |
| **Trench Warden** (Brutus) | Near the trench | The signature boss; killing him gives **everyone +2 shards**. | **+2** all |
| **Reactor Plinth** | Pit (north) | The climax: **activate** (free), then a **~3-round cooldown** → **survive a fast, scary 5-wave surge** (13 zombies/wave ~2.1s apart, **+3 Shielded elites & 1 Glitch Stalker per wave** — user 2026-06-25 scary pass: 5 waves + ~30% more aggressive + more armor) → **everyone +5 shards + a shared Insta-Kill**. The Shielded/Glitch spawns give **no shards** (a threat, not a farm — same as the glitch purge). Re-arm is a self-healing round-number cooldown (`acc_reactor_cooldown`), so it can't lock. | **+5** all |
| **Neural Expansion Bay** | Pit (west) | The marquee buy: **+1 perk slot** (start at 4, up to 9). | spend (4/6/8/10/12) |
| **Glitch Altar** | Foundry room | **Gamble 2 shards/spin** for a weighted result: usually a boon (free perk / Insta-Kill / Max Ammo / Double Points / +3 jackpot / rare ~1% Mega Win), sometimes a curse (surge / −2 drain / dud). Net-negative, can't be farmed. | spend (2/spin) |
| **Cyberware Weapon Overclock** | Foundry room | **Upgrade the gun you're holding** (per-gun) across 5 tiers. Each tier gives a **small boost to 3 effects at once** — flat damage, glitch piercing (vs glitch zombies), headshot ammo-refund — minimal at T1, full at T5. *(Replaced the old Cyberware tree.)* | spend (2/4/8/16/24) |
| **Exo Suit** | Pit (east) | **Per-player**, 5 tiers. Each tier lets you walk **normal speed one trench layer deeper** (the trench slows you more each layer down — the Exo Suit is the only thing that cancels it). The key to reaching the deep layers. | spend (5/10/15/20/25) |

> **Hidden easter egg (dev note — spoiler):** the **NORTH** under-room (opposite the SOUTH "Foundry" room
> that holds the Overclock + Altar) hides a **teddy bear** at `(0, 2430, -240)`. Holding [activate] on it
> plays the easter-egg song **"Cyber Dreams" (Lilex)** 2D for the whole lobby, once per game. Code:
> `_acc_ee_song.gsc` (disable live with `acc_ee_song_on 0`); audio alias `acc_ee_song`. The two under-rooms
> are baked by `add_under_room.js` (SOUTH = Foundry, NORTH = the easter-egg room).

## Cyberware Weapon Overclock — exact effects

**Per-gun** (the weapon you're holding; carries through Pack-a-Punch). **10 tiers** (user 2026-06-24), cost
**4 / 8 / 12 / 16 / 20 / 24 / 28 / 32 / 36 / 40** Data Shards (= **4 × tier**; **220** to max one gun — a
LINEAR ladder SHARED with the Exo Suit). Each tier raises **all four effects a little**. Every number below is
a live dvar; the HUD shows the held gun's tier as **vN** (v1–v10).

| Effect | /tier | T5 | **T10 (max)** |
|---|---|---|---|
| **1. Flat damage** (`acc_oc_dmg_per_tier` 0.10) — all gun hits, hip + ADS, additive on headshots/PaP | +10% | +50% | **+100%** |
| **2. Glitch piercing** (`acc_oc_glitch_per_tier` 0.25) — vs **glitch zombies** only (Stalker + lockdown) | +25% | +125% | **+250%** |
| **3. Ammo refund** (`acc_oc_adaptive_per_tier` 0.10) — chance per **headshot KILL** to return 1 round | +10% | 50% | **100%** |
| **4. Shield piercing** (`acc_oc_pierce_per_tier` 0.05) — vs the Riot's front armor (25% base) | +3.75% dmg-through/tier | 43.75% through | **62.5% through** |

**Shield-pierce is a PARTIAL restore (user 2026-06-25):** the Riot's front takes **25%** base; each OC tier
adds **+0.05 pierce** (`front = 0.25 + 0.75 × 0.05 × tier`), lerping the front damage up the curve
**25% (T0) → 43.75% (T5) → 62.5% (T10)** — it **never** reaches a full bypass, so flanking, grenades/explosives,
and side-melee stay the primary counters. (Was `0.20`/tier = full bypass at T5 + a weak-point past it; the
user cut it to `0.05`/tier on 2026-06-25.)

> **Not adjustable at runtime:** fire rate, reload, mobility are baked weapon stats — the overclock works on
> **damage and on-hit behavior**.

## Exo Suit — the trench depth gate (docs/47)

**Per-player**, **10 tiers** (user 2026-06-24; cost **4 / 8 / 12 / 16 / 20 / 24 / 28 / 32 / 36 / 40** Data
Shards = **4 × tier**, **220** to max — the SAME ladder as the gun Overclock), bought at the Exo Station. The
HUD shows your tier as **EXO SUIT N/10**. Three augments scale with tier:

| Augment | /tier | T5 | **T10 (max)** |
|---|---|---|---|
| **Depth-speed gate** — normal walk speed down to layer = your tier | +1 layer | layers 1–5 | layers 1–5 * |
| **Damage resistance** (`acc_exo_resist_per_tier` 0.05, clamp −80%) | −5% | −25% | **−50%** |
| **Melee damage** (`acc_exo_melee_per_tier` 0.30) | +30% | +150% | **+300%** |

**\* The abyss only has 5 built layers.** The depth gate maxes at **L5**, so tiers 6–10 add **only resist +
melee** until layers 6–10 exist (a geometry + LED-bake job, not GSC). The depth-slow it cancels: at any layer
*deeper* than your tier, **−20% at the first uncovered layer, then −10% per layer below**.

| Your tier ↓ / layer → | L1 (Bus Stn) | L2 | L3 | L4 | L5 |
|---|---|---|---|---|---|
| **0** | −20% | −30% | −40% | −50% | −60% |
| **1** | 0 | −20% | −30% | −40% | −50% |
| **2** | 0 | 0 | −20% | −30% | −40% |
| **3** | 0 | 0 | 0 | −20% | −30% |
| **4** | 0 | 0 | 0 | 0 | −20% |
| **5–10** | 0 | 0 | 0 | 0 | 0 |

*Tiers 6–10 are full-speed across all built layers (L1–5) plus the higher resist/melee. Boots give +8% move but
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
