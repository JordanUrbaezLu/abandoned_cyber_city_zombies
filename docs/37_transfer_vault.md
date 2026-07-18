# 37 — The Exchange (player-to-player transfer vault)

A room under the spawn Plaza where players **transfer resources to each other** —
Points, Data Shards, Mega Bottles, and Boss Items (user, 2026-06-27). Co-op is the
point; in solo it's a personal stash.

> Code: [`_acc_transfer.gsc`](../scripts/zm/zm_abandoned_cyber_city/_acc_transfer.gsc) ·
> Room geometry: [`tools/gen_plaza_basement.js`](../tools/gen_plaza_basement.js) ·
> Door wiring: [`zm_abandoned_cyber_city.gsc`](../scripts/zm/zm_abandoned_cyber_city.gsc) `zone_door_trigger_origin` ·
> Safe-room wiring: [`_acc_bus_trench.gsc`](../scripts/zm/zm_abandoned_cyber_city/_acc_bus_trench.gsc) `origin_in_vault`

## Why it exists

Every resource on this map is **strictly per-player** (see [12_coop_rules.md](12_coop_rules.md)) —
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

An enclosed vault at **z=-160** directly **under the spawn Plaza**, reached by an **enclosed
staircase** in the SW corner of the Implant Lab (the implant-bench side-room, [02_layout.md](02_layout.md)).

> *History (user, 2026-06-27):* the first attempt was an open railed pit in a cramped room with a
> dead door (the generator's old `strip()` left duplicate door entities + brushless shells). The
> current design fixes the strip (removes every `7A2BAE0` block), **enlarges the lab west** to
> x[-720,-40], and rebuilds the descent as an **enclosed staircase room** against the new west wall.

- **Enlarged lab** ([`gen_plaza_shrink.js`](../tools/gen_plaza_shrink.js)): the Implant Lab is widened
  WEST from x[-400,-40] to x[-720,-40], then EAST to **x[-720,180]** (2026-07-10, for the 3-bench relayout; west wall moved + the north wall extended); benches stay
  center, the plaza doorway stays north. The new SW area holds the staircase.
- **Geometry** ([`gen_plaza_basement.js`](../tools/gen_plaza_basement.js)): the single stock
  arena-floor slab (`{219830C1…}`) is **carved** into a connected 4-chunk frame around a **stairwell
  well** at **x[-620,-380] y[-440,-312]** (deliberately NOT flush against the new west wall — the stairs
  stop ~100u short, leaving an open vault landing at x[-720,-620]; the same strip-and-re-emit the abyss
  does to the trench floor is the only way to hole a solid slab). A 15-tread 16-run/10-rise stairwell
  descends z=0→-160 EAST(top)→WEST(bottom) into the vault (x[-720,300] y[-448,360]); the carved arena
  floor is the room **ceiling**. The stairs are wrapped in an **enclosed staircase room** — full-height
  (z[0,256]) N/S walls + the west lab wall + a **doorway on the EAST face** — so it reads as a basement
  stairwell, not a pen. Always-on lights. **LED-bake-gated** — passes (`tools/_bake_test.ps1` → BAKED).
- **Gate**: a buyable door, flag **`enter_exchange`**, **1500 pts** (slab `acc_door_exchange`) in the
  staircase-room east doorway; trigger origin **`(-380,-376,50)`** (`zone_door_trigger_origin`,
  `zm_abandoned_cyber_city.gsc:734` — the doorway is X-thin so the buy trigger takes the default
  `(60,0,0)` offset onto the playable side). On buy the slab is hidden+notsolid and you walk down.
  (`enter_vault` was already the corp/lab Vault door — this room is `enter_exchange`. The `.map` ships
  exactly one `acc_door_exchange` slab+trigger, so `acc_dedupe_exchange_door()` — still invoked from
  the entry script as a self-heal — is currently a harmless no-op.)
- **Safe utility room**: its floor sits at z=-160 inside the trench OOB box (the veto box spans z(-260,0)), so it's **excluded from the
  trench amping** (no −20% slow / surge / danger HUD) via `origin_in_vault()` in `_acc_bus_trench.gsc`
  — but still **OOB-kill-vetoed** there (the second-part pattern: excluded from `underground_layer`,
  vetoed in `acc_trench_oob_allow`). Zombies still path down the stairs (navmesh links the 16-run/10-rise steps);
  it is not a turtle haven.

## The stations

Four terminals (script-spawned, no `.map` / `.zone` / LED-bake cost — the canonical station
recipe), each flanked by a **DEPOSIT** pad and a **WITHDRAW** pad (one trigger per action = the
Implant-Bench multi-pad idiom; BO3 use-triggers are single-button). Each press moves **one fixed
increment** (the codebase's "how much" idiom — no in-game menu exists). Hints are **constant**
(the 250-unique-`SetHintString` cap); the actual per-press amount shows via `hud_msg` on use — the running pool total is shown only for Bottles + Items; Points/Shards toasts show just the bounded per-press amount (no pool total) to stay under the string-cache cap.

| Station | Deposit (per press) | Withdraw (per press) | Notes |
|---|---|---|---|
| **Points** | `acc_vault_points_inc` (**1000**), whole-tens, **−10% tax (= 100)** | whole-tens | `zm_score::minus_/add_to_player_score` (never writes `player.score`); deposit applies the tax (pool gets ~90%); withdraw grants whole-tens (sub-10 dust stays in the pool) |
| **Data Shards** | `acc_vault_shards_inc` (**10**), **−10% tax (= 1)** | clamped to your cap | `try_spend` / `grant_player(…, "transfer")`; deposit applies the tax (pool gets ~90%); withdraw deducts the pool by what **actually** landed (recipient may be at the 500 cap) |
| **Mega Bottles** | **1** | **1** | `try_consume_bottle` / `grant_bottle(1, "transfer")` |
| **Boss Items** | **1** (carried, else un-implants the first filled slot, 1→3) | **1** (FIFO → your carry slot) | deposit can **un-implant** a slot (runs `on_unequip` → buff off, speed recomputed); withdraw drops it into your **carry** slot — **enable it at an Implant Bench** (upstairs), exactly like a fresh pickup. Withdrawing an item you already have **IMPLANTED** is **refused** and it **stays in the vault** for a teammate — the ground grab's semantics ([09_boss_items.md](09_boss_items.md)); the bench refuses an implanted duplicate, so handing one to the carry slot would strand it (invisible carry + every further withdrawal blocked). Locker caps at `acc_vault_items_max` (**8**) |

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

<!-- TODO(acc-verify): these are runtime checks from the v2 build (2026-06-27); no code records the outcome. The module is live in _acc_main::init and the stations were remodelled 2026-07-09, but the walk-test pass/fail is not captured in-repo. -->

- The stairwell **collision floor** survived cod2map (the single-slab T-junction fall-through is
  invisible to the LED bake — only a walk-test proves it).
- Zombies path **down** the stairs to a player in the vault.
- The `enter_exchange` door buys + opens; both buy-triggers are reachable.
- In co-op: deposits by player A are withdrawable by player B; the item un-implant/withdraw→bench
  round-trip works; the squad-roster balances update live.
