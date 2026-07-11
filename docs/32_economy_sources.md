# 32 — Economy Sources (Data Shards / Mega Bottles / Boss Items)

Every in-game way a player obtains the three reward currencies. Source tags in `()` are the
`acc_data_shards::grant_player` source string (some skip diminishing returns). Tune via the listed
dvars. Audited from the code; verify amounts in-game.

> **Key shift (user 2026-07-05): ALL bosses pay the SAME reward — no per-boss differences.**
> Every boss (Trench Warden/Brutus, Phantom, Rogue Protector, Avogadro, Panzer) routes its death
> reward through **one** function, `acc_boss::grant_unified_boss_reward()` (`_acc_boss.gsc:367`). The
> old per-boss "3k flat / round×500" values below June are superseded. The frequent **Glitch Stalker**
> mini-boss is the ONE exception (1 shard to the killer, no bottle/item).

---

## 💎 Data Shards

**Primary (the trench economy — earn-as-you-go):**
| Source | Amount | Who | File |
|---|---|---|---|
| **Shard orb pickups** (glowing orbs) | per-orb (`acc_shard_count`) | the grabber | `_acc_data_shards.gsc:385` (`pickup`) |
| **Pit / vault caches** (crates) | `cache_yield` (scales w/ cache count) | the opener | `_acc_data_shards.gsc:330` (`vault_cache`) |
| **Plaza spawn caches** (4 crates) | 1 shard each, re-arms every round | the opener | `zm_abandoned_cyber_city.gsc::acc_spawn_plaza_props` (`vault_cache`) — early-game faucet at spawn (user 2026-06-28; 4th cache added 2026-07-10 so a full 4-player lobby keeps 1-per-player parity) |

**Enemy kills:**
| Source | Amount | Who | File |
|---|---|---|---|
| **Riot (Shielded) elite** | **2** | the killer | `_acc_elites.gsc:370` (`riot_elite`) |
| **Glitch Stalker** (frequent mini-boss) | 1 | the killer | `_acc_boss_glitch.gsc:802` (`glitch_kill`) — no bottle/item (see below) |
| **Any full BOSS** (Trench Warden, Phantom, Rogue Protector, Avogadro, Panzer) | `int( round / acc_boss_shards_round_div )` (default div 3) | every player | `_acc_boss.gsc:382` (`boss`), via `grant_unified_boss_reward` — see the Boss Reward block below. NOT the Paradise-fight bosses (suppressed) |

**Events / interactables:**
| Source | Amount | Who | File |
|---|---|---|---|
| **Reactor Surge** | `reactor_reward()` | every player | `_acc_reactor.gsc:268` (`reactor`) |
| **Hack Terminal** event | 2 (`ACC_HACK_REWARD_SHARDS`) | the player | `_acc_events_hack.gsc:139` (`hack_terminal`) |
| **Glitch Altar** gamble | jackpot `n` (`acc_altar_jackpot`, default 4) | the gambler | `_acc_glitch_altar.gsc:435` (`altar_jackpot`) |

**Conversions / passive / refunds:**
| Source | Amount | Who | File |
|---|---|---|---|
| **Duplicate boss item** (you already own it) | 3 (`ACC_ITEM_DUPLICATE_SHARD_CONVERT`) | the picker | `_acc_boss_items.gsc:623` (`boss_item_duplicate`) |
| Boss-item **salvage** effect | 1 / interval | the holder | `_acc_boss_items.gsc:1057` (`salvage`) |
| Cyberware **respec refund** _(dormant)_ | the node's cost | the player | `_acc_cyberware.gsc:310` (`respec_refund`) |
| Cyberware **subroutine regen** node _(dormant)_ | 1 | the player | `_acc_cyberware.gsc:912` (`subroutine_regen`) |

> **Dormant (Cyberware tree disabled):** the two Cyberware rows above are UNREACHABLE in normal play.
> The skill tree was removed 2026-06-19 — `_acc_cyberware.gsc::init()` only spawns the kiosk / enables
> node purchase when `acc_cyberware_on 1` (default **0**, `_acc_cyberware.gsc:96`), and `_acc_glitch_altar`
> spawns only the **Overclock terminal**, never `spawn_kiosk_at`. With no node buyable, `respec_refund`
> (fires on a kiosk respec) and `subroutine_regen` (needs `acc_cw_shard_regen_active`, set by buying a
> node) never trigger. The live weapon-upgrade path is the **Cyberware Weapon Overclock** terminal
> (`_acc_overclocks.gsc`).

**Dev only:** each player starts with **1,000 shards** (`ACC_DEV_SHARDS`) in `acc_dev 1`
(`_acc_data_shards.gsc:106`, `on_player_connect`); the shard cap is also raised to 1,000 in dev.

> **Retired:** the **Vault Overload** side-event (`_acc_events_overload.gsc`, `overload` tag, 3 shards)
> was removed 2026-07-07 — `init()` is commented out in `_acc_main.gsc:199` and its `.map` trigger deleted.
>
> **Dead code:** the full-boss "Subroutine Core" shard payout (`_acc_boss.gsc:848`, `reward_players`,
> `boss`) — the Core was removed 2026-06-22, so `run_full_boss` / `reward_players` are defined but
> unreachable (`_acc_boss.gsc:117-118`).

> Diminishing returns: only the `elite_kill` source diminishes at low rounds (docs/05). Every tag
> above is flat. `riot_elite` is intentionally flat (not the diminishing `elite_kill` tag).

---

## 🧪 Mega (Perk) Bottles

Every full boss grants **1 Mega Bottle to every player** on death, via
`grant_unified_boss_reward` → `acc_mega_bottles::grant_bottle( 1, "boss" )` (`_acc_boss.gsc:383`).

| Source | Amount | File |
|---|---|---|
| **Any full BOSS** (Trench Warden, Phantom, Rogue Protector, Avogadro, Panzer) | 1 to every player | `_acc_boss.gsc:383` |
| Dev test boss | bulk (`n_bottles`) | `_acc_boss.gsc:437` (`test_boss`) |

- The **Glitch Stalker does NOT grant Mega Bottles** — it's a frequent mini-boss (`_acc_boss_glitch.gsc:797-802`).
- **Dead code:** the removed full-boss "Subroutine Core" path still calls
  `acc_mega_bottles::on_boss_death( "full", … )` (`_acc_boss.gsc:504`), but `run_full_boss` is unreachable.
- (Empty Mega Bottles are then SPENT at a Lab perk machine to Mega-upgrade an owned perk — a sink, not a source.)

---

## 🎁 Boss Items (the passive-buff pool)

Every full boss drops **1 random item** on death (free-for-all world pickup; a duplicate auto-converts
to 3 shards), via `grant_unified_boss_reward` → `acc_boss_items::grant_challenge_reward()`
(`_acc_boss.gsc:371`).

| Source | Chance | File |
|---|---|---|
| **Any full BOSS** (Trench Warden, Phantom, Rogue Protector, Avogadro, Panzer) | **100%** (guaranteed) | `_acc_boss.gsc:371` |
| Dev test boss | guaranteed | `_acc_boss.gsc:432` |

- The **Glitch Stalker does NOT drop items** (`_acc_boss_glitch.gsc:797-802`).
- **Dead code:** the removed full-boss "Subroutine Core" path still calls
  `acc_boss_items::on_boss_death( "full", … )` (`_acc_boss.gsc:502`), unreachable.

---

## Boss Reward block — the ONE unified payout

`acc_boss::grant_unified_boss_reward( drop_origin )` (`_acc_boss.gsc:367`) is what EVERY boss death
calls (user 2026-07-05: "the boss reward rule applies for ALL bosses, no differences"):

- **1 guaranteed challenge item** (dupes convert to shards at pickup)
- **1 Mega Bottle** to every player
- **round × `acc_boss_score_per_round`** points to every player (default **180**; user 2026-07-07 nerfed −40%, was 300)
- **int( round / `acc_boss_shards_round_div` )** Data Shards to every player (default div **3**)

Paid PER boss, so a 2-boss round pays the full set for EACH kill. Examples: round 9 → 3 shards +
$1,620; round 18 (×2 bosses) → 6 shards + $3,240 EACH; round 30 → 10 shards + $5,400.
**Paradise-suppressed** — `grant_unified_boss_reward` returns early when `level.acc_paradise_onslaught`
is set (`_acc_boss.gsc:369`); the finale is survive-don't-farm. The Paradise-fight Brutus is also
flagged `acc_no_shard_reward` and grants nothing (`_acc_boss.gsc:408,422`).

Callers (each boss threads its own death watcher, then calls the shared function):
| Boss | Death watcher | Call site |
|---|---|---|
| **Trench Warden** (Brutus) | `watch_mini_boss_death` | `_acc_boss.gsc:426` |
| **Phantom** | `phantom_death_watch` | `_acc_boss_phantom.gsc:889` |
| **Rogue Protector** (Civil Protector) | | `_acc_civil_protector.gsc:946` |
| **Avogadro** | | `_acc_boss_avogadro.gsc:1149` |
| **Panzer** (mechz) | | `_acc_boss_panzer.gsc:671` |

Boss cadence: mini-boss first at round 10; full BOSS rounds every 9 from round 9 (r9=1, r18=2,
r27=3); the boss TYPE is dealt from a no-duplicate shuffled deck (shared via `level.acc_boss_roster_fn`).

---

## Summary — the reward hierarchy

- **Shards** = the broad currency: orbs + caches (primary), small per-kill trickles (Glitch 1 /
  Riot 2), event payouts (Reactor / Hack / Altar), and the big boss payout (`int(round/3)` to
  everyone). Spent on the Overclock terminal / the Altar / perk slots (the Cyberware tree is disabled by
  default — `acc_cyberware_on 0` — so the Overclock terminal is the sole live weapon-upgrade sink).
- **Mega Bottles** = rare, boss-only (1 to everyone from every full boss). Spent to Mega-upgrade perks.
- **Boss Items** = rare, boss-only (1 guaranteed drop from every full boss).
- The frequent **Glitch Stalker** gives neither bottle nor item — just 1 shard to its killer.
