# 12 - Co-op Rules

Consolidated rules for 1-4 player multiplayer. If it says "co-op" or "multiplayer" elsewhere in the docs, this is the authoritative behavior.

## Player Count

- **Supported**: 1 - 4 players.
- **Solo**: fully supported; all systems work. No modifier or handicap required.
- **2p / 3p / 4p**: all supported identically. No "duos only" or "squad only" behaviors.
- **5+ players**: unsupported. Stock BO3 caps zombies at 4 (`player_count()` clamps to `ACC_COOP_MAX_PLAYERS` 4 in `_acc_coop_scaling.gsc`).

## Networking Model

- **Host-authoritative**. The map host is the server; clients predict and correct.
- **Split-screen**: supported via stock BO3 split-screen (2-player local co-op). Not thoroughly tested with our custom systems.
- **Listen server**: assumed. Dedicated server is not a BO3 zombies thing.
- **Player proximity / host tethering**: stock BO3 has a ~1500 unit tether distance. We don't change this.

## Per-Player vs. Shared Resources

### Per-player (individual)

Every player has their own copy of these:

- **Points** - personal currency.
- **Data Shards** - personal.
- **Weapons** (weapon tiers, PaP levels, Overclocks slotted).
- **Overclock Terminal upgrades** - independent per player; player A's weapon Overclock tiers don't affect player B. (The old **Cyberware skill tree** is **disabled by default** — `_acc_cyberware.gsc` init only spawns the kiosk / allows node purchase when `acc_cyberware_on` is 1, default 0 — so the Overclock Terminal is the sole live per-player upgrade path.) The kiosk **card** is per-player too, as of 2026-07-15: `SetHintString` is one string on the single shared trigger entity, so `terminal_loop` writing it per interaction **latched the last presser's** private per-gun tier/price onto the team (a teammate holding a Tier-0 gun was told "Tier 10/10 MAX"). `_acc_overclocks::terminal_hint_loop` now owns the card and composes it from the **nearest live player's** held gun — the same nearest-player keeper the Paradise PaP uses (`_acc_pap_levels::paradise_pap_hint_loop`), and the standing rule for any shared trigger showing per-player values (`_acc_perk_info.gsc`: "the shown price can't be per-player on a shared trigger").
- **Perks** - each player buys their own.
- **Boss items** - per-player inventory (3 slots each; `ACC_ITEM_SLOTS_PER_PLAYER` 3 in `_acc_boss_items.gsc`).
- **Weapon abilities** - each player has their own cooldowns.
- **HP / armor** - standard per-player.
- **Ability cooldowns** - independent.

### Shared (team-wide)

- **Round state** - all players progress through rounds together.
- **Power state** - power switch flip affects everyone.
- **PaP, Overclock Terminal, Mystery Box machines** - shared; no lockout per player.
- **Side event state** (Hack Terminal) - one player activates; success/failure state is map-wide (one player can't activate Hack again if another failed it).
- **Map shortcuts unlocked by events** - map-wide.
- **Boss encounter state** - team-wide (shared roster, `level.acc_boss_roster_fn`).

### Awarded per-player (independent of team)

- **Elite Data Shard drops** - go to the killer (direct grant on kill, not a pickup entity).
- **Boss Data Shard drops** - **every player gets the full amount independently** (not split). The payout is round-scaled (`int(round / 3)` Shards to every player, `grant_unified_boss_reward` in `_acc_boss.gsc`), so 4p co-op = 4× the Shards distributed per kill.
- **Boss items** - per-player duplicate detection; one player's copy doesn't block another's pickup.
- **Side event rewards** - the Hack Shard payout is **OFF by default** (`acc_hack_shard_drop` default 0), so the Hack pays **0 Shards** in default play; with that dvar enabled, `ACC_HACK_REWARD_SHARDS` = 2 Shards go to the activating player (plus any contributors via the 70/30 split for kills made during the event).

## HP Scaling

Stock BO3 does **NOT** scale zombie HP per player (HP is purely round-based, `zombie_utility.gsc` `ai_calculate_health`); **every per-player multiplier below is our custom addition**, implemented in `_acc_coop_scaling.gsc`.

| Target | Base HP | 2p mult | 3p mult | 4p mult |
|---|---|---|---|---|
| Regular zombie | 150 (round 1) | 1.20× | 1.40× | 1.60× |
| Shielded elite | 4× a normal zombie's current HP (any player count) | — | — | — |
| **Round / mini bosses** (Brutus, Phantom, Rogue Protector, Avogadro, Panzer) | 65,000 at the round-5 anchor, compounding per round | **1.70×** | **2.30×** | **2.60×** |
| Glitch (special-round boss) | 1.5× the round's normal zombie HP | inherits regular scaling | | |

**Key deltas from stock**:

- **Regular zombies** scale **+20% per extra player** (user 2026-06-24: 1.2 / 1.4 / 1.6×; was +100% = 2/3/4× — too tanky). `ACC_COOP_REGULAR_HP_PER_EXTRA` (0.2), `regular_hp_mult()`. Stock itself adds **zero** per-player HP — this whole multiplier is ours.
- **Shielded elites** are a **flat 4× a normal (already co-op-scaled) zombie's health at any player count** (`promote_to_shielded` in `_acc_elites.gsc`, `base_hp × 4`; user 2026-07-04: 5×→4×). Their per-player scaling therefore comes entirely from the regular zombie's baked-in +20%/extra — they do **not** apply a separate `special_hp_mult()`. Shielded is the only live elite (Teleporter + EMP were removed 2026-06-22; `elite_quota_for_round()`).
- **All roster bosses share one explicit per-count table** (user 2026-07-15): `boss_hp_player_mult()` → **1p 1.00 / 2p 1.70 / 3p 2.30 / 4p 2.60**. Live-tunable via `acc_boss_coop_hp_2p` / `_3p` / `_4p` (defaults `ACC_COOP_BOSS_HP_2P/3P/4P`). Solo has no dvar — it is the 1.0 baseline by definition.
  - **Why a table, not a curve.** This replaced `1 + k·log₂(n)` (k = 0.5 → 1/1.5/1.79/2.0, user 2026-06-24). The requested numbers are **not logarithmic** and no `k` reproduces them: fitting 2p = 1.70 forces k = 0.70, which then yields **2.11** at 3p and **2.40** at 4p, not 2.30/2.60. Since player count clamps to 1..4 there are only three values to state, so a table is the honest shape — a curve would have to lie about at least one count. (The old code already hardcoded a log₂ switch anyway, since GSC has no `log` builtin, so this is *less* indirection, not more.)
  - **The 2026-06-24 rationale still holds.** The original point was that a LINEAR ×N (200k/400k at 4p) was "crazy" tanky. The table stays far under linear (**2.60 vs 4.00** at 4p) and still *decelerates* per added player (+0.70 / +0.60 / +0.30) — it is simply tuned tankier than the old log.

**Boss base-HP model (all roster bosses share it):** solo base **65,000** at the round-5 anchor (`ACC_BOSS_MINI_HP` / `ACC_PHANTOM_HP`, both 65000, user 2026-07-05: 56000→65000), then **compounds per round** by a per-boss exponent, *then* × the co-op table above:

| Boss | Per-round exponent | Solo HP examples |
|---|---|---|
| Brutus (Trench Warden, mini-boss) | 1.12 (tankiest tier) | r5 65k / r10 115k / r20 356k |
| Panzer (mechz) | 1.09 (middle tier, matches Rogue Protector) | — |
| Rogue Protector | 1.09 (middle tier) | — |
| Phantom | 1.06 (softest tier) | r5 65k / r10 87k / r20 156k |
| Avogadro | 1.06 (shares Phantom's) | — |

(Exponents: `ACC_BOSS_MINI_HP_EXP` / `ACC_PHANTOM_HP_EXP` / `ACC_PROTECTOR_HP_EXP` / `acc_panzer_hp_exp` / `acc_avogadro`-via-`scale_phantom_hp`. Anchor `*_HP_ANCHOR` = 5, user 2026-07-08: all boss scaling now starts at round 5; roster bosses first spawn at round 9 = base × exp⁴.) **Glitch** is the exception — its HP is `acc_glitch_hp_mult` × the round's normal zombie health (default 1.5×, `_acc_boss_glitch.gsc`), so it rides regular-zombie co-op scaling, not the boss table.

**Worked example — Panzer HP by round × player count** (exp 1.09; only boss rounds shown, since that is when a Panzer can be dealt). Same shape for any boss — swap the exponent:

| Round | 1p | 2p | 3p | 4p |
|---|---|---|---|---|
| 9 | 91,752 | 155,978 | 211,029 | 238,555 |
| 18 | 199,277 | 338,770 | 458,337 | 518,120 |
| 27 | 432,809 | 735,775 | 995,460 | 1,125,303 |
| 36 | 940,015 | 1,598,025 | 2,162,034 | 2,444,039 |
| 45 | 2,041,612 | 3,470,740 | 4,695,707 | 5,308,191 |

Note the **round axis is the aggressive one** — ×2.17 per boss round (1.09⁹) — while 1p→4p only ever multiplies by 2.60. Late-round difficulty is driven by the exponent, not the lobby size.

Rationale: a single boss takes ~N× the team's fire in 4p, but **not** a clean 4× effective DPS (shared aggro, target overlap, downs), so a flat ×N HP made the fight an HP-sponge slog. A sub-linear, decelerating curve keeps 4p time-to-kill sane while still rewarding more guns. In 4p, boss *density* / spawns scale too (boss rounds land more bosses — see cadence below), so raw boss HP doesn't need to be 4×.

## Boss Cadence & Roster

- **Mini-boss (Brutus / Trench Warden)**: first spawns at **power-on AND round ≥ 5** (`acc_warden_first_round`, default 5, `_acc_boss.gsc:150-151`), on a power-on cadence with respawns. (The `ACC_BOSS_MINI_FIRST_ROUND` 10 define is only read by the now-dead full-boss `compute_shard_reward()` path.)
- **Round bosses**: a boss ROUND lands **every 9 rounds from round 9** (9, 18, 27, …; `ACC_BOSS_FIRST_DEF` 9 in `_acc_civil_protector.gsc`). The **count scales** with the slot — round 9 = 1 boss, 18 = 2, 27 = 3, … (`boss_count()`).
- **Types are dealt from a shuffled 4-type deck WITHOUT replacement** — Phantom / Rogue Protector / Avogadro / Panzer (`boss_roster()`), reshuffled per run only when the deck empties, so a multi-boss round is always all-distinct types (first forced repeat = the 5th boss slot, round 45). The roster is owned by `_acc_civil_protector` and published as `level.acc_boss_roster_fn`; each boss module reads its own count off it.
- **Glitch** runs on its own special-round system (`ACC_GLITCH_INTERVAL_DEF` 2 = every 2nd round from its first), separate from the boss deck.

## Spawn Rate Scaling

**Regular horde spawn count scales +30% per extra player, measured vs the SOLO count** (user 2026-06-24). Stock BO3 already scales count per player on its own curve, so `acc_coop_max_zombie_override` **inverts stock's per-player term back to the solo number**, then applies our flat per-player multiplier — making the per-player scaling exactly the table below regardless of stock's curve. The stock **early-round ramp** (R1 ×0.25 / R2 ×0.30 / R3 ×0.50 / R4 ×0.70 / R5 ×0.90 / R6+ full) still applies (run on the solo-equivalent input). Live-tunable: `ACC_COOP_SPAWN_PER_EXTRA` (0.3).

| Player count | Regular zombie spawn count (vs solo) |
|---|---|
| 1 | 1.0× (solo baseline) |
| 2 | 1.3× |
| 3 | 1.6× |
| 4 | 1.9× |

The only enemies that spawn *on top of* the stock horde are our custom additions, each on its **own** spawn path (NOT a global multiplier on the horde count):

- **Shielded elites** — round-based, **identical solo & co-op**: a shield round every 4th round from r4 (r4, r8, r12, …), count = `round / 2`. See `elite_quota_for_round()` in `_acc_elites.gsc`. (Their *HP* rides the regular co-op scaling via the flat 4×; their *count* does not scale with player count.)
- **Glitch zombie rounds** — special-round system (`_acc_boss_glitch.gsc`).
- **Trench surges** — `_acc_bus_trench.gsc`.

(History: briefly +30%, then +50%/extra player; **removed** 2026-06-24 to follow base game; **re-added the same day at +30%/extra vs solo** per user. The HP side was simultaneously cut from +100% to +20%/extra.)

## Downed / Revive Rules

- **Down state**: player HP reaches 0 from zombie damage → drop into down state (crawl with pistol).
- **Bleed-out timer**: **30 seconds** base.
  - Halved by **Bleed Out** modifier: 15 seconds.
  - (The old **Subroutine Tier 2 Caching** Cyberware would double this to 60s, but the Cyberware skill tree is **disabled by default** (`acc_cyberware_on` 0), so that extension is **not live**.)
- **Revive action**: stand over downed teammate, hold [use] for **3 seconds** base (stock no-perk time; `_acc_perks.gsc` replaces only the perk-driven times).
  - Reduced by **Quick Revive** to **2 seconds** (`ACC_QR_BASE_REVIVE_TIME` 2.0), and by **Savior** (Mega QR) to **1 second** (`ACC_SAVIOR_REVIVE_TIME` 1.0).
- **Revive points**: 100 for the reviver (stock BO3 behavior).
- **Self-revive (solo)**: Quick Revive grants 1 self-revive per run in solo; cannot self-revive in co-op.
- **Self-revive (co-op)**: **available only via purchased self-revive** (see [05_mechanics.md](05_mechanics.md#downed--revive-mechanics)). (The Subroutine Caching Cyberware's Shard-cost discount is **not live** — the Cyberware skill tree is disabled by default, `acc_cyberware_on` 0.)
- **Dying**: if bleed-out expires without revive, player dies. They respawn at the start of the next round.
- **Respawn consequences**:
  - Lose all perks.
  - Keep all weapons (with their tiers + Overclocks).
  - Keep all boss items.
  - Keep Data Shards.
  - **Points are SET to exactly 500 × round** on respawn (comeback bonus; `comeback_set_score` in `_acc_points.gsc:185-197` does a `take_all` then awards `ACC_COMEBACK_PER_ROUND` (500) × round). Stock BO3's "lose all points" is replaced by this comeback formula — a poor player is floored up to 500 × round, but a rich player is reduced down to it. Points are NOT kept intact through a full bleed-out death.

## Friendly Fire

- **OFF by default** (zombies convention). Players cannot damage teammates with bullets / melee / grenades.
- **Exceptions**: stock BO3 has some edge cases where splash damage still applies (e.g. explosive weapons); we inherit stock behavior without custom overrides.
- **Reviving** does not count as friendly interaction in any damage sense.

## Point Economy in Co-op

See [05_mechanics.md](05_mechanics.md#co-op-kill-point-split-70--30) for full detail. Summary:

- **Regular kill**: 70 pts total. Killer gets 70% (49), non-killer damage contributors split 30% (21 total).
- **Headshot kill**: 110 pts total (killer 70% ≈ 77, others split 30% ≈ 33). **Knife kill**: 100 pts total (killer 70%, others split 30%).
- **Solo kill (no other contributors)**: killer gets 100%.
- **Minimum contribution threshold**: 5% of zombie maxhealth to qualify for a share.
- **Anti-exploit rules**: documented in `_acc_points.gsc` and [05_mechanics.md](05_mechanics.md#anti-exploit-rules-hard-enforced-in-code).

## Data Shard Distribution in Co-op

- **Elite kill**: the live (Shielded) elite grants **3 Shards directly to the killer** on death (user 2026-07-13, was 2) (`shielded_death_reward` in `_acc_elites.gsc`) — no pickup entity, no corpse walk. (The generic pickup path `spawn_pickup_at` is gated by `acc_elite_shard_drop`, default 0 = OFF.)
- **Shared damage on an elite**: no automatic split. The direct 2-Shard grant always goes to the player credited with the kill (`attacker`); there is no pickup to collect or despawn.
- **Boss shard grant**: independent per-player (the round-scaled boss Shard amount goes to every player on a boss kill, not shared).
- **Objective Shard rewards** (Hack): go to the player who activated and saw the event through. In 4p, if 3 players help but one player activated the Hack, only the activator gets the 2 Shards.

## Boss Item Drops in Co-op

- **Every boss kill**: exactly 1 item drops at the boss corpse (guaranteed, unified boss reward; `on_boss_death` in `_acc_boss_items.gsc`, user 2026-07-07 "all bosses drop 1 item"). Any player can pick up.
- **Duplicate detection is per-player.** If player A has Neural Boots already and they pick up a dropped Neural Boots, it converts for them (to Shards). Player B without Neural Boots walking up gets a fresh Neural Boots equipped.
- **Pickup priority**: first player to reach the item pickup wins.
- **Team coordination**: in 4p, a single item drop can only go to one player. Expect teams to coordinate boss-kill approach so the "right" player (based on build needs) can claim the item.

## Weapon & PaP in Co-op

- **Mystery Box**: standard BO3 behavior. Any player can roll (950 Points). Only the rolling player gets the weapon. (This map is **box-only** for its large arsenal — Apex + Skye ports + elemental bows — with no wallbuy shortlist.)
- **Pack-a-Punch**: each player buys their own PaP levels for their own weapons. No sharing.
- **Overclock Terminal / Tiers**: each player buys their own tiers for their own weapons.

## Side Event Behavior in Co-op

### Hack Terminal

- **One activation per run.** (The Parallel Processing Cyberware's "2 event attempts" upgrade is **not live** — the Cyberware skill tree is disabled by default, `acc_cyberware_on` 0.)
- **Activator**: the player who holds F first wins the activation.
- **Other players can help** during the 3 stages (their kills count toward the stage counter).
- **Reward**: the Shard payout is **OFF by default** (`acc_hack_shard_drop` default 0, `_acc_events_hack.gsc:138-139`) — in default play the Hack pays **0 Shards**. When `acc_hack_shard_drop 1` is set, `ACC_HACK_REWARD_SHARDS` = 2 Data Shards go to the **activator only**. (Note: even when enabled, this is the one place where the 70/30 split does NOT apply - Shard rewards from events are activator-gated.)

> **Vault Overload** was a second side event (activator holds a defense point, leaving > 8s fails it, reward 3 Shards + a map shortcut). It was **RETIRED 2026-07-07** — `acc_events_overload::init()` is commented out in `_acc_main.gsc` and the trigger + point struct were deleted from the `.map`. Documented here only so the history is clear; it is not in the live map.

## Emergency Drop in Co-op

- Any player can activate at a power switch (spend 3 of their own Shards).
- Drop type is random (same table as solo).
- Drop pickups (e.g. Max Ammo): team-wide benefit (stock behavior). Insta-Kill applies team-wide.
- Strategic use: 4p teams can have one player stockpile Shards for emergency drops while others invest in weapons.

## Mule Kick Interaction

- **Mule Kick** = 3rd primary weapon slot (2,500 Points, stock BO3 price).
- **Per-player**. Each player buys their own.
- If a player loses Mule Kick (dying through respawn), the 3rd weapon slot reverts and can be reclaimed by repurchasing Mule Kick. Mule Kick takes the LAST gun in engine give-order — see the `mulekick-stable-order` handling in `_acc_gun_badges.gsc`.

## 4-Player "Easy Mode" Fact

4p co-op is intentionally the easiest configuration:

- Boss fights: ~4× damage output vs **2.6× boss HP** → faster time-to-kill than solo (the co-op boss table, above).
- Elite pressure spread across 4 players.
- 4 independent Shard pickups per elite.
- 1 boss item per boss kill (any player claims it) — but boss *rounds* land more bosses in 4p (count scales per slot), so more total items across a boss round.
- Rapid power switch flip and perk-buying.

Solo is the hardest configuration. **This is intentional.** Zombies is a co-op genre; solo is an option, not the default.

## Known Co-op Gotchas

- **Host migration**: if the host disconnects, run ends. Stock BO3 doesn't support mid-run migration in zombies.
- **Join-in-progress**: limited support. A player joining mid-run spawns with default loadout at the start of the next round. They do NOT inherit the host's weapons / tiers / Shards. They start fresh.
- **Desync**: rare but possible in long runs. Our systems all run server-side (GSC), so clients should stay in sync for gameplay state; the LUI HUD can occasionally drift (client-side, not GSC).

## Implementation Status

- Stock co-op: works out of the box via the zm template.
- **HP / spawn-rate scaling: LIVE.** Fully implemented and live-tuned in `_acc_coop_scaling.gsc` — the `level.max_zombie_func` override handles spawn count, `regular_hp_mult()` hooks `level.zombie_init_done` for regular HP, and `boss_hp_player_mult()` is wired into every boss module.
- Per-player state: correctly isolated in all our modules (grep `self.acc_*` in scripts/).
- Boss item per-player duplicate detection: implemented in `_acc_boss_items.gsc::watch_pickup` (per-grabber; `on_boss_death` is the now-dead full-boss reward path).
- Side-event activator-gating: implemented in `_acc_events_hack.gsc` (Hack Terminal).

## Tuning Levers

- **Regular zombie HP**: `ACC_COOP_REGULAR_HP_PER_EXTRA` (0.2 = +20%/extra player).
- **Boss HP in co-op**: `acc_boss_coop_hp_2p` / `_3p` / `_4p` (defaults 1.7 / 2.3 / 2.6). Raise for tankier bosses, lower for faster kills. Solo is always 1.0 and has no dvar. (Replaced `acc_boss_coop_hp_log_k`, retired 2026-07-15 with the log curve.)
- **Elite counts in co-op**: `acc_elite_count_log_k` (default 0.5 → 1p 1.0 / 2p 1.5 / 3p 1.79 / 4p 2.0). Multiplies both the Shielded shield-round quota and the Glitch Stalker per-round count.
- **Elite count round curves**: `acc_shielded_count_log_k` / `_log_c` (2.5 / 3.0) and `acc_glitch_count_log_k` / `_log_c` (2.0 / 3.0) — `int(k·log₂(round) − c)`. Raise `k` for a steeper late game; raise `c` to shift the whole curve down.
- **Spawn count**: `ACC_COOP_SPAWN_PER_EXTRA` (0.3 = +30%/extra player, vs solo). Dial down if 4p reads as chaos.
- **Boss per-round HP exponents**: `acc_boss_mini_hp_exp` / `acc_phantom_hp_exp` / `acc_protector_hp_exp` / `acc_panzer_hp_exp` (per-boss round compounding).
- **Shard rewards in 4p**: if players feel they progress too fast in 4p, adjust `acc_boss_shards_round_div` (currently 3) to change the per-player boss Shard payout.
