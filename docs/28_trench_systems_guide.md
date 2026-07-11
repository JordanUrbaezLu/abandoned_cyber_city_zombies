# 28 — The Trench: what each thing does (high level)

**The one-liner:** the underground trench is the dangerous place where **Data Shards** are both
**earned** and **spent**. You descend, brave the amped horde, grab shards, and turn them into
permanent power. Points keep you alive *this* round; shards are how you get strong enough to
survive the next twenty.

> Scope note: this is the **systems** view (what each interactable does). The underground
> **geometry/layout** (the vertical **Abyss Descent** — L2/L3/L5 layers down to the Paradise
> plaza) lives in [docs/30](30_abyss_descent.md). Economy detail is in
> [docs/05](05_mechanics.md); perks in [docs/10](10_perks.md).

## How you get down there
- Buy into the **Bus Station** (corp zone) — two doors, 1000 each, no power needed.
- **Drop into the open pit** (stairs on each side, or just jump in). The pit is the exposed
  danger zone. The **Foundry room** opens off the pit through a buyable door (1500).

## The danger (why it's a risk)
While anywhere underground you get **amped zombies** (faster + hit harder + tankier, scaling **+4% move / +30% health / +6 HP melee per layer** the deeper you go), a **−20% move slow**, a
**spawn surge that erupts at YOUR current layer** (on entry, on descending to a new layer, and a continuous drip while you stay down — so the deeper layers populate as you reach them, not just the pit), and a small **fall tax** if you dive in. The reward has to be worth it —
that's everything below.

> Per-layer numbers (N = layer 1–5): move **+4%·N**, health **+30%·N** (**stacks on top of** round + co-op HP, so final = (round curve × player-count mult) × (1 + 0.30·N) — both scale, user 2026-07-04), melee **+6·N flat HP** (base 45 → 51/57/63/69/75). Dvars: `acc_trench_layer_speed_pct` (4), `acc_trench_layer_hp_pct` (30), `acc_trench_layer_dmg_add` (6). Spawning: `spawn_corp_surge` reads each underground player's layer (`get_layer_risers`: L1 = map pit risers, L2–L5 = computed floor risers) and erupts there.

## The things in the trench

**Economy is small on purpose (user 2026-06-19): 1 shard matters.** Shard cap = **500** (raised from 30 so the
deepest single purchase fits many times over — Exo Suit T10 = 40, gun Overclock T10 = 40; see [docs/29](29_exo_suit_plan.md)).
All numbers are tight and even.

| Thing | Where | What it does | Shards |
|---|---|---|---|
| **Data Caches** ×2 | Exposed pit | Main shard **source** — **+3 each** (user 2026-06-25: 2→3), once per round, to whoever loots it first (re-arms each round). **CO-OP anti-hog (user 2026-06-25; per-group since 2026-07-11): a player can loot only ONE of the two TRENCH caches per round — grab one and the other must go to a teammate — but this cap is separate from the plaza crates (looting a plaza cache does NOT lock you out of a trench cache, and vice-versa)** (`acc_cache_one_per_player`; **solo is exempt** so the 2nd cache isn't wasted). A **dim white glow** on each crate = "shards available this round"; it **switches off the instant the cache is looted** and **comes back when it re-arms at round start** — an at-a-glance indicator (user 2026-06-24). | **+3** each |
| **Trench Warden** (Brutus) | Near the trench | The signature mini-boss; killing him grants the **unified boss reward** (identical for every boss, user 2026-07-05) to **every player**: **int(round ÷ 3) shards** + **round × 180 points** + **1 guaranteed boss item** (dupes convert to shards at pickup) + **1 Mega Bottle**. Round-scaling, so the debut kill pays more the later it lands (e.g. round 9 → 3 shards + 1,620 pts). (`acc_boss::grant_unified_boss_reward`; tunables `acc_boss_shards_round_div` = 3, `acc_boss_score_per_round` = 180.) | **int(rnd/3)** all |
| **Reactor Plinth** | Pit (north) | The climax: **activate** (free), then a **~3-round cooldown** → **survive a fast, scary 5-wave surge** (13 zombies/wave ~2.1s apart, **+3 Shielded elites & 1 Glitch Stalker per wave** — user 2026-06-25 scary pass: 5 waves + ~30% more aggressive + more armor) → **everyone +5 shards + a shared Fire Sale** (user 2026-06-27, was an Insta-Kill). The Shielded/Glitch spawns give **no shards** (a threat, not a farm — same as the glitch purge). Re-arm is a self-healing round-number cooldown (`acc_reactor_cooldown`), so it can't lock. | **+5** all |
| **Neural Expansion Bay** | Pit (west) | The marquee buy: **+1 perk slot** (start at 4, up to 10 — so 6 buyable slots). | spend (4/6/8/10/12/14) |
| **Glitch Altar** | Abyss **floor 3** (west) | **Gamble 2 shards/spin** for a weighted result: usually a boon (Max Ammo / Insta-Kill / Double Points / free perk / +4 shard jackpot / rare ~2% Mega Win = Free Perk + Insta-Kill), sometimes a curse (surge / −2 drain / dud). ~65% boon / ~35% curse; net-negative, can't be farmed. | spend (2/spin) |
| **Cyberware Weapon Overclock** | Abyss **floor 2** (west) | **Upgrade the gun you're holding** (per-gun) across 10 tiers. Each tier gives a **small boost to 4 effects at once** — flat damage, glitch piercing (vs glitch zombies), headshot ammo-refund, and shield piercing (vs the Riot's front armor) — minimal at T1, full at T10. | spend (4/8/12/16/20/24/28/32/36/40) |
| **Ammo Crate** ×2 | Abyss **floor 2** (east, by the OC) & **floor 5** (bottom, before Paradise) | Refills the **held weapon's reserve** (personal Max Ammo). Costs **points** by PaP state: **1000** base / **5000** Pack-a-Punched / **10000 flat for wonder weapons** (Thundergun / Fire Bow / Blast-O-Matic, regardless of PaP; user 2026-07-08). Melee / no-PaP specials (incl. the **Action Figure** and the ammo-less **Leviathan Axe**) can't be refilled here — charges nothing. | **points** (1000/5000/10000) |
| **Exo Suit** | Pit (east) | **Per-player**, 10 tiers. Each tier lets you walk **normal speed one trench layer deeper** (the trench slows you more each layer down — the Exo Suit is the only thing that cancels it). The key to reaching the deep layers. | spend (4/8/12/16/20/24/28/32/36/40) |

> **Jukebox (dev note):** the **NORTH** under-room (opposite the SOUTH "Foundry" room that holds the
> Overclock + Altar) has a **JUKEBOX machine** (IW `cp_town_jukebox` model, eMoX pack model-only lift) on
> the west side at `(-150, 2240, -240)` (moved 2026-07-10 to spread it away from the reactor plinth; was
> `(-140, 2350)`) — it **replaced the 3 teddy bears** (2026-07-09). Holding [activate]
> charges **2 Data Shards + 1000 points** and plays a **RANDOM song** from the playlist (never the same one
> twice in a row) 2D for the whole lobby, with the same **5-min cooldown** between plays; it is never
> consumed (repeatable all game). A **`NOW PLAYING <title>`** banner shows the song's name to **all
> players**. Launch playlist = the 3 old bear songs: "Cyber Dreams" (Lilex), "Night Groove", "I Want To
> Stay At Your House" (aliases `acc_ee_song`/`_2`/`_3`, all wavs banked). Adding a song = bank the wav +
> one `add_song()` line in `_acc_jukebox.gsc::init()`. Code: `_acc_jukebox.gsc` (disable live with
> `acc_jukebox_on 0`; tunables `acc_jukebox_cost_points/_cost_shards/_cooldown`). The two under-rooms
> are baked by `add_under_room.js` (SOUTH = Foundry, NORTH = the jukebox room).

## Cyberware Weapon Overclock — exact effects

**Per-gun** (the weapon you're holding; carries through Pack-a-Punch). **10 tiers** (user 2026-06-24), cost
**4 / 8 / 12 / 16 / 20 / 24 / 28 / 32 / 36 / 40** Data Shards (= **4 × tier**; **220** to max one gun — a
LINEAR ladder SHARED with the Exo Suit). Each tier raises **all four effects a little**. Every number below is
a live dvar; the HUD shows the held gun's tier as **vN** (v1–v10).

| Effect | /tier | T5 | **T10 (max)** |
|---|---|---|---|
| **1. Flat damage** (`acc_oc_dmg_per_tier` 0.12) — all gun hits, hip + ADS, additive on headshots/PaP | +12% | +60% | **+120%** |
| **2. Glitch piercing** (`acc_oc_glitch_per_tier` 0.15) — vs **glitch zombies** only (Stalker + lockdown) | +15% | +75% | **+150%** |
| **3. Ammo refund** (`acc_oc_adaptive_per_tier` 0.05) — chance per **headshot KILL** to return 1 round | +5% | 25% | **50%** |
| **4. Shield piercing** (`acc_oc_pierce_per_tier` 0.04) — vs the Riot's front armor (25% base) | +3% dmg-through/tier | 40% through | **55% through** |

_Per-tier magnitudes retuned 2026-07-08: flat dmg 0.10→0.12, glitch 0.25→0.15, ammo 0.10→0.05, pierce 0.05→0.04._

**Shield-pierce is a PARTIAL restore (user 2026-06-25):** the Riot's front takes **25%** base; each OC tier
adds **+0.04 pierce** (`front = 0.25 + 0.75 × 0.04 × tier`), lerping the front damage up the curve
**25% (T0) → 40% (T5) → 55% (T10)** — it **never** reaches a full bypass, so flanking, grenades/explosives,
and side-melee stay the primary counters. (Was `0.20`/tier = full bypass at T5 + a weak-point past it; the
user cut it to `0.05`/tier on 2026-06-25, then `0.04`/tier on 2026-07-08.)

> **Not adjustable at runtime:** fire rate, reload, mobility are baked weapon stats — the overclock works on
> **damage and on-hit behavior**.

## Exo Suit — the trench depth gate (docs/29)

**Per-player**, **10 tiers** (user 2026-06-24; cost **4 / 8 / 12 / 16 / 20 / 24 / 28 / 32 / 36 / 40** Data
Shards = **4 × tier**, **220** to max — the SAME ladder as the gun Overclock), bought at the Exo Station. The
HUD shows your tier as **EXO SUIT N/10**. Three augments scale with tier:

| Augment | /tier | T5 | **T10 (max)** |
|---|---|---|---|
| **Depth-speed gate** — normal walk speed down to layer = your tier | +1 layer | layers 1–5 | layers 1–5 * |
| **Damage resistance** (`acc_exo_resist_per_tier` 0.06, clamp −80%; user 2026-07-08: 0.05 → 0.06) | −6% | −30% | **−60%** |
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
- Per-thing knobs live in each module (`acc_cache_*`, `acc_altar_*`, `acc_perk_slot_*`, `acc_reactor_*`;
  the Trench Warden / all-boss reward is `acc_boss_shards_round_div` + `acc_boss_score_per_round` in
  `_acc_boss.gsc`); see the module headers.
