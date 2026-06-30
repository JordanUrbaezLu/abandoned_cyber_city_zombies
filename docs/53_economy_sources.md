# 53 — Economy Sources (Data Shards / Mega Bottles / Boss Items)

Every in-game way a player obtains the three reward currencies, as of 2026-06-22. Source tags in
`()` are the `acc_data_shards::grant_player` source string (some skip diminishing returns). Tune via the
listed dvars. Audited from the code; verify amounts in-game.

---

## 💎 Data Shards

**Primary (the trench economy — earn-as-you-go):**
| Source | Amount | Who | File |
|---|---|---|---|
| **Shard orb pickups** (glowing orbs) | per-orb (`acc_shard_count`) | the grabber | `_acc_data_shards.gsc:330` (`pickup`) |
| **Pit / vault caches** (crates) | `cache_yield` (scales w/ cache count) | the opener | `_acc_data_shards.gsc:267` (`vault_cache`) |
| **Plaza spawn caches** (3 crates) | 1 shard each, re-arms every round | the opener | `zm_abandoned_cyber_city.gsc` `acc_spawn_plaza_props` (`vault_cache`) — early-game faucet at spawn (user 2026-06-28) |

**Enemy kills:**
| Source | Amount | Who | File |
|---|---|---|---|
| **Riot (Shielded) elite** | **2** | the killer | `_acc_elites.gsc` (`riot_elite`) — NEW 2026-06-22 |
| **Glitch Stalker** | 1 | the killer | `_acc_boss_glitch.gsc:737` (`glitch_kill`) |
| **Brutus** / Trench Warden | **3 shards + 3,000 points** | every player | `_acc_boss.gsc` (`watch_mini_boss_death`, `warden`) — **100%**, +50% Mega Bottle; user 2026-06-29 added 3k points. NOT the Paradise Brutus (`acc_no_shard_reward`) |
| **Phantom** | **round × 1** (10 @ r10, 20 @ r20) + **round × 500 points** | every player | `_acc_boss_phantom.gsc` (`phantom_death_watch`) — 100%, **NOT in the Paradise fight** (gated on `!acc_paradise_onslaught`); user 2026-06-29 round-scaled, was flat 5 |

**Events / interactables:**
| Source | Amount | Who | File |
|---|---|---|---|
| **Reactor Surge** | `reward` | every player | `_acc_reactor.gsc:188` (`reactor`) |
| **Hack Terminal** event | 2 | the player | `_acc_events_hack.gsc:139` (`hack_terminal`) |
| **Overload** event | 3 | the player | `_acc_events_overload.gsc:136` (`overload`) |
| **Glitch Altar** gamble | jackpot `n` (weighted boon) | the gambler | `_acc_glitch_altar.gsc:208` (`altar_jackpot`) |

**Conversions / passive / refunds:**
| Source | Amount | Who | File |
|---|---|---|---|
| **Duplicate boss item** (you already own it) | 3 (`ACC_ITEM_DUPLICATE_SHARD_CONVERT`) | the picker/killer | `_acc_boss_items.gsc:280,372` |
| Boss-item **salvage** effect | 1 | the holder | `_acc_boss_items.gsc:656` (`salvage`) |
| Cyberware **respec refund** | the node's cost | the player | `_acc_cyberware.gsc:310` (`respec_refund`) |
| Cyberware **subroutine regen** node | 1 | the player | `_acc_cyberware.gsc:912` (`subroutine_regen`) |

**Dev only:** each player starts with 200 shards in `acc_dev 1` (`_acc_data_shards::on_player_connect`).
**Dead code:** the full-boss "Subroutine Core" `reward_players` (`_acc_boss.gsc:734`, `boss`) — the Core was
removed 2026-06-22, so it never fires.

> Diminishing returns: only the `elite_kill` source diminishes at low rounds (docs/06). All the tags above
> EXCEPT a future `elite_kill` are flat. `riot_elite` is intentionally flat (not `elite_kill`).

---

## 🧪 Mega (Perk) Bottles

Granted to **every player** on a qualifying boss kill (`_acc_mega_bottles::on_boss_death` → `grant_bottle(1)`).
| Source | Chance | File |
|---|---|---|
| **Brutus** / Trench Warden | **100%** (`acc_brutus_reward_chance`) | `_acc_boss.gsc:315` |
| **Phantom** | 100% | `_acc_boss_phantom.gsc:415` |
| Dev test boss | bulk (`n_bottles`) | `_acc_boss.gsc:337` |

- The **Glitch Stalker does NOT grant Mega Bottles** (changed 2026-06-22 — it's a frequent mini-boss).
- **Dead code:** full-boss "Subroutine Core" (`_acc_boss.gsc:385`, `full`) — Core removed.
- (Empty Mega Bottles are then SPENT at a Lab perk machine to Mega-upgrade an owned perk — that's a sink, not a source.)

---

## 🎁 Boss Items (the 6-item passive-buff pool)

One random item drops (free-for-all world pickup; a duplicate auto-converts to 3 shards).
| Source | Chance | File |
|---|---|---|
| **Brutus** / Trench Warden | **100%** (`acc_brutus_reward_chance`) | `_acc_boss.gsc:308` (`grant_challenge_reward`) |
| **Phantom** | 100% | `_acc_boss_phantom.gsc` (`grant_challenge_reward`) |
| Dev test boss | guaranteed | `_acc_boss.gsc:332` |

- The **Glitch Stalker does NOT drop items** (changed 2026-06-22).
- **Dead code:** full-boss "Subroutine Core" (`_acc_boss.gsc:383`, `full`) — Core removed.
- `ACC_BOSS_ITEM_DROP_CHANCE_MINI`/`_FULL` (the `on_boss_death` chance path) are currently 1.00 but only used by
  Brutus's `acc_warden_item 0` fallback now; the real drops go through `grant_challenge_reward` (guaranteed pool).

---

## Summary — the intended hierarchy (2026-06-22)

- **Shards** = the broad currency: orbs + caches (primary), small per-kill trickles (Glitch 1 / Riot 2), event
  payouts, and big boss payouts (Brutus **3 shards + 3,000 points** flat / Phantom **round × 1 shards + round × 500 points** to-everyone — NOT the Paradise-fight versions of either). Spent on Cyberware / Overclocks / the Altar.
- **Mega Bottles** = rare, boss-only (Brutus + Phantom 100%), 1 to everyone. Spent to Mega-upgrade perks.
- **Boss Items** = rare, boss-only (Brutus + Phantom 100%), 1 drop. The frequent Glitch Stalker gives neither.
