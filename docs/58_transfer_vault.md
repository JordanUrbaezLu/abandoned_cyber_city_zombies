# 58 — The Exchange (player-to-player transfer vault)

A room under the spawn Plaza where players **transfer resources to each other** —
Points, Data Shards, Mega Bottles, and Boss Items (user, 2026-06-27). Co-op is the
point; in solo it's a personal stash.

> Code: [`_acc_transfer.gsc`](../scripts/zm/zm_abandoned_cyber_city/_acc_transfer.gsc) ·
> Room geometry: [`tools/gen_plaza_basement.js`](../tools/gen_plaza_basement.js) ·
> Door wiring: [`zm_abandoned_cyber_city.gsc`](../scripts/zm/zm_abandoned_cyber_city.gsc) `zone_door_trigger_origin` ·
> Safe-room wiring: [`_acc_bus_trench.gsc`](../scripts/zm/zm_abandoned_cyber_city/_acc_bus_trench.gsc) `origin_in_vault`

## Why it exists

Every resource on this map is **strictly per-player** (see [15_coop_rules.md](15_coop_rules.md)) —
boss Shards/items even grant to each player **independently** (4p = 16 Shards per full boss).
The Exchange is the one place that lets a team **redistribute**: a strong killer can bank
Points/Shards/Bottles/a spare Boss Item that a teammate building toward an expensive sink
(Exo Suit, per-gun Overclocks) pulls back out. It deliberately amplifies the "help a teammate"
ethos already in the map (the Data Cache's "leave the other for a teammate" rule).

## Model — a SHARED TEAM VAULT (deposit / withdraw pool)

Chosen by the user over "directed give to a teammate" / "two-pad send→receive". You **deposit**
into a shared team pool; **any** teammate **withdraws**. No player-targeting (avoids the
`closest_player_override` co-op hazards) — anyone can pull what anyone deposited.

- The pool is **level-side** (`level.acc_vault_points / _shards / _bottles / _items`) — the only
  shared store on the map. Both currencies + bottles are per-player script fields with no shared
  field, so a shared bank has to be our own level var. Deposits transfer ownership to the level
  **immediately**, so nothing is lost if a depositor disconnects mid-run.
- Pools persist for the whole match (not reset on death/round). Solo = a personal stash.

## The room — under the Plaza, down from the (enlarged) Implant Lab

An enclosed vault at **z=-240** directly **under the spawn Plaza**, reached by an **enclosed
staircase** in the SW corner of the Implant Lab (the implant-bench side-room, [03_layout.md](03_layout.md)).

> **v2 redesign (user, 2026-06-27).** v1 put an open railed pit in the middle of a cramped 360×300
> room ("a big square block in the middle"), and the door was dead — the generator's old `strip()`
> only removed leaf brushes, so re-runs left **duplicate door entities** (one pair an empty shell with
> its brush stripped), and a workaround kept the empty shell as the live door, so buying hid a
> brushless phantom while the real slab stayed solid. v2 fixes the strip (removes every `7A2BAE0`
> block — leaf brushes, top-level entities, and orphaned shells), **enlarges the lab west** to
> x[-720,-40], and rebuilds the descent as an **enclosed staircase room** against the new west wall.

- **Enlarged lab** ([`gen_plaza_shrink.js`](../tools/gen_plaza_shrink.js)): the Implant Lab is widened
  WEST from x[-400,-40] to **x[-720,-40]** (west wall moved + the north wall extended); benches stay
  center, the plaza doorway stays north. The new SW area holds the staircase.
- **Geometry** ([`gen_plaza_basement.js`](../tools/gen_plaza_basement.js)): the single stock
  arena-floor slab (`{219830C1…}`) is **carved** into a connected 4-chunk frame around a **stairwell
  well** at **x[-720,-496] y[-440,-312]** (flush against the new west wall — the same strip-and-re-emit
  the abyss does to the trench floor, the only way to hole a solid slab). A 14-tread 16/16 stairwell
  descends z=0→-240 EAST(top)→WEST(bottom) into the vault (x[-720,300] y[-448,360]); the carved arena
  floor is the room **ceiling**. The stairs are wrapped in an **enclosed staircase room** — full-height
  (z[0,256]) N/S walls + the west lab wall + a **doorway on the EAST face** — so it reads as a basement
  stairwell, not a pen. Always-on lights. **LED-bake-gated** — passes (`tools/_bake_test.ps1` → BAKED).
- **Gate**: a buyable door, flag **`enter_exchange`**, **1500 pts** (slab `acc_door_exchange`) in the
  staircase-room east doorway; trigger origin `(-496,-376,50)`. On buy the slab is hidden+notsolid and
  you walk down. (`enter_vault` was already the corp/lab Vault door — this room is `enter_exchange`.
  `acc_dedupe_exchange_door` in the entry script is now a harmless no-op since v2 ships exactly one door.)
- **Safe utility room**: it sits at z=-240 inside the trench OOB box, so it's **excluded from the
  trench amping** (no −20% slow / surge / danger HUD) via `origin_in_vault()` in `_acc_bus_trench.gsc`
  — but still **OOB-kill-vetoed** there (the second-part pattern: excluded from `underground_layer`,
  vetoed in `acc_trench_oob_allow`). Zombies still path down the stairs (navmesh links the 16/16 run);
  it is not a turtle haven.

## The stations

Four terminals (script-spawned, no `.map` / `.zone` / LED-bake cost — the canonical station
recipe), each flanked by a **DEPOSIT** pad and a **WITHDRAW** pad (one trigger per action = the
Implant-Bench multi-pad idiom; BO3 use-triggers are single-button). Each press moves **one fixed
increment** (the codebase's "how much" idiom — no in-game menu exists). Hints are **constant**
(the 250-unique-`SetHintString` cap); the actual amount + running pool show via `hud_msg` on use.

| Station | Deposit (per press) | Withdraw (per press) | Notes |
|---|---|---|---|
| **Points** | `acc_vault_points_inc` (**1000**), whole-tens, **−10% tax (= 100)** | whole-tens | `zm_score::minus_/add_to_player_score` (never writes `player.score`); deposit applies the tax (pool gets ~90%); withdraw grants whole-tens (sub-10 dust stays in the pool) |
| **Data Shards** | `acc_vault_shards_inc` (**10**), **−10% tax (= 1)** | clamped to your cap | `try_spend` / `grant_player(…, "transfer")`; deposit applies the tax (pool gets ~90%); withdraw deducts the pool by what **actually** landed (recipient may be at the 500 cap) |
| **Mega Bottles** | **1** | **1** | `try_consume_bottle` / `grant_bottle(1, "transfer")` |
| **Boss Items** | **1** (carried, else un-implants Slot 1→2) | **1** (FIFO → your carry slot) | deposit can **un-implant** a slot (runs `on_unequip` → buff off, speed recomputed); withdraw drops it into your **carry** slot — **enable it at an Implant Bench** (upstairs), exactly like a fresh pickup. Locker caps at `acc_vault_items_max` (**8**) |

Validity: both ends gate on `zm_utility::is_player_valid` (a downed/spectating player can't transact).

## Tuning dvars

| Dvar | Default | Effect |
|---|---|---|
| `acc_vault_points_inc` | 1000 | Points moved per deposit/withdraw press (whole-tens; 10% tax = **100**, exact) |
| `acc_vault_shards_inc` | 10 | Data Shards moved per press (10% tax = **1**, exact) |
| `acc_vault_items_max` | 8 | Max Boss Items the shared locker holds |
| `acc_vault_tax_pct` | 10 | **Deposit tax** on Points + Shards (the house cut). `0` = free 1:1. Bottles + Items are never taxed. |

## Balance note — the 10% tax

Points + Data Shards carry a **10% deposit tax** (`acc_vault_tax_pct`, user 2026-06-27) — the house
cut that keeps a team from trivially funnelling the whole economy onto one player (the documented
"4p easy mode"). It's applied on **deposit** (the pool receives ~90% of what you put in, the rest is
destroyed), so the pool always holds clean 1:1 value and the withdraw paths — including the shard
cap clamp — stay simple. The default increments are chosen (user 2026-06-27) so the tax is **exact**:
a **1000**-Point deposit taxes exactly **100**; a **10**-Shard deposit taxes exactly **1**.
**Mega Bottles + Boss Items are NOT taxed** (the user scoped the tax to "money and
shards"). Set `acc_vault_tax_pct 0` for free 1:1 transfers.

## NEEDS WALK-TEST (build OK ≠ proven)

- The stairwell **collision floor** survived cod2map (the single-slab T-junction fall-through is
  invisible to the LED bake — only a walk-test proves it).
- Zombies path **down** the stairs to a player in the vault.
- The `enter_exchange` door buys + opens; both buy-triggers are reachable.
- In co-op: deposits by player A are withdrawable by player B; the item un-implant/withdraw→bench
  round-trip works; the squad-roster balances update live.
