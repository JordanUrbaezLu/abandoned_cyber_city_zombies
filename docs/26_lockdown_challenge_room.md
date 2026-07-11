# 26 — Lockdown Challenge Room ("Glitch Purge")

> **Status: BUILT, but HARDCODE-DISABLED by default.** The full system ships in
> `scripts/zm/zm_abandoned_cyber_city/_acc_lockdown_challenge.gsc` (~1140 lines) — the trap catch,
> door seal, confined glitch wave, HUD, reward, all watchdogs. **It is OFF in every version** (normal
> AND dev — the gate is unconditional, not behind `level.acc_dev`) because it caused too many bugs and
> still needs testing. `init()` returns before arming anything unless you launch with
> `+set acc_lockdown_challenge_on 1` (`_acc_lockdown_challenge.gsc:103`, user 2026-07-04). The DEFCON
> room *lights* (`_acc_lockdown` rotation) keep rotating as ambient flavour regardless — only the PURGE
> is dead by default.
>
> This doc is the living reference for how the built system works and the hard-won correctness fixes
> baked into it. It was produced by a research → design → adversarial-verify workflow (2026-06-18) then
> implemented and iterated.

## 1. Concept (player experience)

Each round, `_acc_lockdown` lights ONE of four rooms RED (Vault / Alley / Helipad=`roof_zone` / Market)
and rotates which. When the Glitch Purge is enabled, that lit room becomes a **TRAP challenge**:

- You **see the red light from outside — it's the warning.** The lit (DEFCON) room is a **trap**: walk
  in while it's red, accidentally or on purpose, and **it's game time** — the room seals behind you.
  There is **no opt-in prompt**; the red light is the only telegraph. (A brief grace lets anyone
  *already* standing in the room when it lights bolt out before the trap arms.)
- The **first** player to step in trips the trap, but the doors do NOT seal instantly: a **join window**
  (`acc_lockdown_challenge_join_window`, default 2s) holds the doors open and announces
  "LOCKDOWN SEALING – get in!" to everyone, so teammates can pile in before it seals.
- On seal, the room **locks** (its 2 buyable border doors re-close; the outside horde can't rise inside)
  and fills with a wave of **Glitch Stalkers** you must defeat. It's **very hard.**
- It's a **separate game**: the challenge zombies do **not** count toward the round, and the round
  outside keeps spawning/ending independently. The room **stays sealed across round boundaries** until
  the wave is cleared.
- Clear the wave → the room **opens** and drops a **single random boss-item as a loose world drop —
  free-for-all**: anyone can grab it, or leave it for a teammate. Whoever grabs it carries it to the
  Plaza Implant Bench.

**Wave size is AUTO, not a fixed 30.** The kill target = `current round × 2` (`ACC_LDC_ROUND_MULT_DEF
= 2.0`, `acc_lockdown_challenge_mult`), captured once at commit so it can't drift mid-fight — e.g. r10
→ 20, r20 → 40 (`ldc_compute_total`, `_acc_lockdown_challenge.gsc:423`). `ACC_LDC_TOTAL_DEF = 0` means
AUTO; a non-zero `acc_lockdown_challenge_total` is a fixed testing override (was 15/40/50 in earlier
tuning). The HUD reads **"GLITCH PURGE X / N"** where N is the live captured total, not a literal 30.

## 2. Architecture

Pure-GSC module **`_acc_lockdown_challenge.gsc`**, threaded from `acc_main::init()` after
`_acc_lockdown` / `_acc_boss_glitch` / `_acc_boss_items`. It **reuses four shipped systems** rather
than reinventing:

| Reused system | What for |
|---|---|
| `_acc_boss_glitch` | the Glitch Stalker spawn (`spawn_glitch`) + buffs (HP, teal eyes, blink, speed), plus the in-room blink/charge clamps (`ldc_in_room` / `ldc_random_anchor_nav`) |
| `_acc_boss_items` | the random-item → carry → Plaza-bench reward flow (`grant_challenge_reward`) |
| `_acc_lockdown` | the red room rotation, `room_center_origin`, the `acc_lockdown_room_lit` notify, and the DEFCON cooldown gates (`on_defcon_cleared` / `on_defcon_failed`) |
| `_acc_decontamination` | zone-volume player detection (`get_zone_volumes` / `player_in_zone_volumes`) **and** `disable_zone_spawning` / `enable_zone_spawning` (the riser fix) |

**Everything is linker-only (`-GscOnly`), zero LED risk** — the door seal reuses the map's existing
buyable border doors instead of authoring new `acc_seal_*` brushes (see §8), so **no geometry is
touched at all.**

## 3. State machine

```
IDLE
 └─ acc_lockdown lights a room red  ──("acc_lockdown_room_lit" notify)──►  ARMED
ARMED  (after acc_lockdown_challenge_grace, arm_trap polls the room volume; disarms if the rotation moves on)
 └─ a valid player IsTouching the lit room  ──►  JOIN WINDOW (the trap is TRIPPED, not yet sealed)
JOIN WINDOW (acc_lockdown_challenge_join_window, default 2.0s): the FIRST entry trips the trap but holds the
 doors OPEN + announces "LOCKDOWN SEALING - get in!" so teammates pile in. After the hold, the ARMED guards
 are re-checked (rotation moved / committed elsewhere bails; an empty room re-arms), THEN ──► COMMIT.
COMMIT (snapshot the party = ALL valid players IsTouching the room volume at seal time)
 ├─ disable_zone_spawning(zone)         ◄── CRITICAL: stops the outside horde rising INSIDE
 ├─ relocate_party_safe (nav-snapped ring off the doorway) + seal_room (re-close the 2 border doors) + reseal_monitor
 ├─ capture level.acc_ldc_total (round x 2), create X/N HUD per inside player, announce
 └─ start challenge_producer + watch_fail + ldc_stall_watch + ldc_round_cap_watch + ldc_release_outside_horde
ACTIVE  (private quota: spawn `total` glitch, capped concurrent, refill on death; count kills)
 ├─ killed >= total  ──►  challenge_clear   (unseal, re-enable spawning, reward, teardown)
 ├─ nobody up-and-inside (unwinnable)  ──►  challenge_fail   (unseal, re-enable, no reward)
 └─ stalled / over the round cap  ──►  challenge_timeout / stall CLEAR  (anti-softlock escape valves)
TEARDOWN  (one-shot guarded; notifies "acc_ldc_done"; culls tagged stragglers; back to IDLE)
```

Every thread carries `level endon("end_game")` **and** `level endon("acc_ldc_done")`. Resolution is a
one-shot guard (`level.acc_ldc_resolved`) so clear / fail / timeout are mutually exclusive.

## 4. ⚠️ Hard-won correctness fixes (all implemented)

These are the bugs the adversarial pass caught, each now live in code.

1. **FATAL — riser leak.** A doorway seal only blocks *walking*. The outside round spawns zombies from
   **`riser_location` structs that rise out of the floor INSIDE the room** (`<zone>_spawners` are
   interior risers), so the horde would mix into the sealed challenge. **Fix (implemented):**
   `commit_challenge` calls `acc_decontamination::disable_zone_spawning(zone)`, and `teardown_common`
   calls `enable_zone_spawning(zone)` to restore it (decon intentionally never re-enables — the
   challenge must, or that room's outside spawns die for the rest of the run). Confinement is therefore
   **three cooperating mechanisms** (§7), not just the seal.

2. **Round-boundary unseal conflict.** `_acc_lockdown::run_lockdown()` runs every `acc_round_start` and
   would `lockdown_clear()` → re-open the sealed room and re-pick a new red room mid-fight. **Fix
   (implemented):** `_acc_lockdown` skips its clear + re-pick while `level.acc_ldc_active` is set
   (`_acc_lockdown.gsc:163` "lockdown rotation paused").

3. **Actor-budget reality.** Glitch zombies are invisible to the round's *completion* count and its
   *spawn* budget (both filter `ignore_enemy_count`), **but they DO consume the shared engine actor
   pool.** `spawn_zombie` hard-busy-waits on `GetFreeActorCount() < 1`, so `challenge_producer`
   gates on `ldc_alive() >= cap || GetFreeActorCount() < 1` and carries the teardown endons so it dies
   cleanly if the room resolves mid-spawn. Concurrent stays low (`default 8`); live-test at r20+ before
   raising the engine actor limit (don't approach the ~32 co-op netcode zone).

4. **Scheduled-glitch stacking.** On a round that is *both* a challenge and a glitch-cadence round, the
   scheduled glitch bosses + the challenge wave would stack on the actor pool. **Fix (implemented):**
   `_acc_boss_glitch` gates its scheduled spawn on `!isdefined(level.acc_ldc_active)`
   (`_acc_boss_glitch.gsc:110`).

5. **Blink strands zombies outside the seal.** `GetClosestPointOnNavMesh` can clamp a blink/charge
   teleport to the *corridor* side of the seal, stranding a stalker that can never path back. **Fix
   (implemented):** each challenge zombie is tagged `self.acc_ldc` and stocked with the room's interior
   **spawn anchors** (`<zone>_spawners`) on `self.acc_ldc_anchors` at spawn. Three layers, all no-op
   off-challenge: (a) `_acc_boss_glitch::glitch_blink_loop` blinks challenge zombies to a **random
   in-room anchor** (`ldc_random_anchor_nav`); (b) charge steps skip any nav point **not within
   `acc_lockdown_challenge_bounds_margin` (default 300u) of any anchor** (`ldc_in_room`); (c)
   `ldc_keep_in_room` polls each zombie at 1 Hz and force-teleports any escapee back to an anchor.
   (rooms.json was stale and zones overlap, so anchors — not an AABB — are the in-room proof.)

6. **N-items bug.** `_acc_boss_glitch::glitch_death_watch` drops a boss-item + Mega Bottle on **every**
   stalker death. The challenge wave uses its **own `ldc_death_watch`** (guarded on `self.acc_ldc`) and
   grants the reward **once** when `killed >= total`. Challenge kills never route through
   `glitch_death_watch` / `on_boss_death`.

7. **Teardown thread leak / double-resolve.** When teardown culls survivors, each survivor's death
   watch would re-increment the counter (spurious clear + unearned reward). **Fix (implemented):** a
   single `acc_ldc_done` notify endon'd by every challenge thread; `level.acc_ldc_teardown = true` set
   at the top of clear/fail/timeout **before** culling; `ldc_death_watch` bails on
   `!self.acc_ldc || level.acc_ldc_teardown`; the one-shot `level.acc_ldc_resolved` guard makes clear /
   fail / timeout mutually exclusive.

8. **HUD must NOT use the `clientuimodel` pool.** That pool is **exactly full at 64 bits** — adding a
   field crashes at load (memory `round-progress-ring-hud`). The "GLITCH PURGE X / N" counter is built
   the **server-side `hud::` way** per inside player (`create_challenge_hud`), destroyed on
   teardown/disconnect. Each player uses a **label + a single `hud::createIcon("white")` bar + a
   number** — the pool-frugal squad-roster idiom (NOT `hud::createBar`, which is 3 hudelems and whose
   `barFrame` child leaked in co-op). Every `hud::create*` is null-guarded (returns undefined when the
   shared hudelem pool is full — the 4p condition, when the pool is most saturated).

9. **Blink glitches on the sound/goal builtins.** `play2d` is not a builtin → `zm_utility::play_sound_2D`.
   `SetGoalVolume` does not exist → plain `SetGoal(centroid)`. `ignore_round_spawn_failsafe = true` is
   harmless but **redundant** (the failsafe is only threaded by stock `round_spawning`, which these
   direct spawns never use) — kept belt-and-suspenders, but don't rely on the "would be culled" reasoning.

10. **Four helpers were net-new code, not "reuse verbatim":** `_acc_boss_glitch`'s glitch-buff body is
    **copied inline** into `spawn_challenge_glitch` (minus `glitch_death_watch`) rather than refactored
    out of the live boss file, to avoid destabilising it; `acc_lockdown::room_center_origin` (centroid
    helper); the `acc_lockdown_room_lit` notify (in `lockdown_apply`, `_acc_lockdown.gsc:309`); and
    `acc_boss_items::grant_challenge_reward` (net-new).

11. **Co-op: the OUTSIDE horde freezes on a sealed-in player (user 2026-06-24).** When one player seals
    in, they stay `am_i_valid` but the seal's `DisconnectPaths()` cuts the navmesh to them. Stock
    `factory_closest_player` (zm_usermap_ai.gsc) caches each zombie's target and **only re-picks when the
    cached player goes INVALID, never when it just becomes UNREACHABLE**. So every zombie locked onto the
    sealed player idles forever instead of switching to teammates still reachable outside — the whole
    outside horde froze for the other players. (**Not the Phase Serum** — that only froze the in-room
    glitches.) **Fix (implemented):** `ldc_release_outside_horde` (threaded in `commit_challenge`) each
    second re-points any **non-purge** zombie (`!self.acc_ldc`) whose `last_closest_player` is a
    sealed-in party member to a reachable outside player + `need_closest_player = true`. Purge glitches
    skipped; true-solo / whole-team-sealed no-ops (no reachable target).

## 5. Component build spec (as implemented)

| Component | Mechanism |
|---|---|
| **`watch_challenge`** | `level waittill("acc_lockdown_room_lit", zone)`; re-gate on `acc_lockdown_challenge_on`; one challenge at a time (`level.acc_ldc_active`); `arm_trap(zone)`. |
| **`arm_trap`** (TRAP, ambient catch) | wait `acc_lockdown_challenge_grace` (1.5s flee-window), then poll the room volume ~every 0.25s; the first valid player `IsTouching` trips it → run the **join window** (announce + hold `acc_lockdown_challenge_join_window`, re-check guards, re-capture the party) → `commit_challenge`. Disarms if the rotation moved on. **No `trigger_use`, no prompt.** |
| **`commit_challenge`** | set state + capture `acc_ldc_total`; **`disable_zone_spawning(zone)`**; `relocate_party_safe`; `seal_room` + `reseal_monitor`; per-party HUD + announce; thread `challenge_producer`, `watch_fail`, `ldc_stall_watch`, `ldc_round_cap_watch`, `ldc_release_outside_horde`. |
| **`challenge_producer`** | loop while `spawned < total`: if `ldc_alive() >= concurrent` or `GetFreeActorCount() < 1` wait; else `spawn_challenge_glitch`, `spawned++`, thread `ldc_death_watch`; `wait stagger` (`stagger_initial` 0.3 while filling to the cap, then `stagger` 0.6). Endon `end_game`+`acc_ldc_done`. |
| **`spawn_challenge_glitch`** | `host = acc_boss_glitch::spawn_glitch(round)`; `host.acc_ldc = true`; stock `<zone>_spawners` origins onto `host.acc_ldc_anchors`; `forceteleport` to an in-room nav point; `SetGoal(room_center_origin(zone))`; thread `ldc_keep_in_room`. |
| **`ldc_death_watch`** | `self waittill("death")`; guard `acc_ldc`/`teardown`; `acc_ldc_killed++`; refresh HUD; if `killed >= total` → `challenge_clear(zone)`. Endon `acc_ldc_done`. |
| **`watch_fail`** | poll ~0.5s over party members **inside** the room volume. Someone **up + inside** → keep going. Someone in laststand **inside** with **no outside teammate** → KEEP alive (self-revive / inside-revive grace; `is_player_valid(p, false, true)` = ignore-laststand). Otherwise (real wipe, everyone respawned OUTSIDE, or a downed-inside player WITH an outside rescuer) → `challenge_fail`, **debounced 2 polls** so a sub-second doorway clip during the seal can't false-abort. |
| **`challenge_clear` / `challenge_fail` / `challenge_timeout`** | one-shot guard (`acc_ldc_resolved`); `acc_ldc_teardown = true`; notify `acc_ldc_done`; `teardown_common` (unseal + re-enable spawning + destroy HUD + cull tagged); clear → `grant_challenge_reward(room_center_origin(zone))`; `acc_ldc_active = undefined`; gate the next DEFCON (`on_defcon_cleared` / `on_defcon_failed`). `challenge_fail`/`challenge_timeout` first redirect to `challenge_clear` if `killed >= total` (a met count is a WIN regardless of who raced the resolver). Always unseal + re-enable on `end_game` (`on_end_game_safety`). |
| **`ldc_stall_watch`** (anti-softlock) | resets on any kill/spawn. (1) room clear of live challenge zombies but count short (lost zombies) → force CLEAR (earned reward). (2) no kill AND no spawn for `acc_lockdown_challenge_stall_sec` (60s) → force CLEAR. Both clear `acc_ldc_active` so bosses (which gate on it) come back — the fix for "Phantom never spawned in co-op." |
| **`ldc_round_cap_watch`** (round-cap backstop) | **SOFT cap** (`acc_lockdown_challenge_max_rounds`, default 2): fires `challenge_timeout` once the purge has lasted ≥ cap rounds AND made **no kill in the round that just ended** (genuinely stalled — won't rob a still-winning fight). **HARD cap** (soft + `acc_lockdown_challenge_hard_grace`, default 2+4=6): fires UNCONDITIONALLY as the absolute anti-softlock backstop. `challenge_timeout` = the same clean teardown as clear/fail with **no reward**, gating the next DEFCON to +cooldown. |
| **`grant_challenge_reward(origin)`** (in `_acc_boss_items`) | pick random from `level.acc_item_pool` → `spawn_pickup(picked, origin)` at the room centroid. **Single origin arg, no killer tie / no killer dedup** — a loose drop ANYONE can grab (the per-grabber dedupe in `watch_pickup` already converts "already owns it" → Data Shards at pickup). |

## 6. Round isolation ("separate game")

`ignore_enemy_count = true` (set on every glitch by `_acc_boss_glitch::spawn_glitch`) makes the wave
invisible to **both** the round-end gate and the horde spawn budget — both filter it via
`get_round_enemy_array`. The challenge tracks its **own** `level.acc_ldc_killed`, never
`level.zombie_total`, and spawns **directly** via `spawn_glitch` (never `round_spawning`). The outside
round therefore spawns and ends on its own horde, and a bugged challenge can never soft-lock the round.
The shared cost is only the **engine actor pool** — managed by the concurrent cap (§4.3). Rounds keep
advancing *during* a purge (the outside wave still ends them), which is exactly what the round-cap
watchdog leans on.

## 7. Confinement — the three mechanisms

1. **`disable_zone_spawning(zone)`** during the seal — no outside risers fire inside (§4.1). Re-enabled
   on teardown via `enable_zone_spawning`.
2. **Door seal** — re-close the room's 2 stock buyable border doors (§8). Crush-safe, LED-safe, no new
   geometry. An optional soft yank-back (`confine_players`, `acc_lockdown_challenge_confine 1`) exists as
   belt-and-suspenders but defaults **OFF** now the doors seal.
3. **Per-teleport in-room clamp** for challenge-tagged glitch — blink/charge clamps + the 1 Hz
   `ldc_keep_in_room` yank-back (§4.5).

## 8. Door seal — how it works (LED-safe, no new geometry)

The seal reuses the map's existing buyable border doors — **no `acc_seal_*` brushes, no `.map` edit,
`-GscOnly`, zero LED risk.** Each of the 4 rooms is bordered by exactly **2 stock buyable doors**
(`acc_door_*` `script_brushmodel`s, verified in the current `.map`), mapped in `room_doors`:

| Room | Border doors |
|---|---|
| `vault_zone` | `acc_door_vault` + `acc_door_lab_e` |
| `roof_zone` | `acc_door_roof` + `acc_door_lab_w` |
| `alley_zone` | `acc_door_alley` + `acc_door_corp_e` |
| `market_zone` | `acc_door_market` + `acc_door_corp_w` |

`seal_room` re-closes only doors that are currently **OPEN** (their `enter_*` flag set) and restores
exactly those on teardown — an un-bought door is already a solid wall, left alone.

**HOW THE SEAL WORKS — the load-bearing fact is *how this map OPENS its doors*.** The entry script's
`acc_hardcoded_open_map` (`zm_abandoned_cyber_city.gsc`) and `_acc_dev::dev_open_all_doors` force-open
every door via `slab ConnectPaths(); NotSolid(); Hide()` **IN PLACE** — the slab never moves, it just
goes invisible + non-colliding at its CLOSED origin z[0,128]. So:
- **SEAL = `e Show(); e DisconnectPaths(); e Solid()` in place** (the slab is already at z[0,128]).
- **UNSEAL = `e Hide(); e NotSolid(); e ConnectPaths()`** (exactly how the map opened it).
- **Crush-safety WITHOUT moving the slab:** gate `Solid()` on `door_player_touching(e)` (stock
  `IsTouching` occupancy) — only solidify when the doorway is player-clear; a 1 Hz `reseal_monitor`
  re-asserts `Show`+`DisconnectPaths`+gated-`Solid` (so a door left un-solid because a player stood in
  it finishes the moment they step off). `commit_challenge` first runs `relocate_party_safe` — a
  navmesh-snapped, degenerate-guarded ring off the doorway — so the doorway is normally already clear
  and it solidifies instantly.

> **The detour (do not repeat).** The `acc_door_*` brushmodels DO carry `script_vector "0 0 130"`, so a
> crush-safety workflow (correct for the stock buy path, where a bought door slides +130z UP) briefly
> switched the seal to `zm_blockers::door_activate(t, false)`. But this map BYPASSES the buy (it
> force-opens in place), so the slab is at z[0,128], and `door_activate(false)` `MoveTo`s it
> `origin − script_vector` = **below the floor** → "the room doesn't lock anymore." Reverted to the
> in-place `show/solid`. **Lesson: before re-closing a door, check HOW it was opened — hide-in-place →
> show/solid; stock-buy/MoveTo-up → MoveTo back down.**

**ESCAPE-BUG FIX — un-bought border doors stayed buyable (user 2026-06-25).** "An un-bought door is
already a wall" is true for the *slab*, but its **buy trigger is still live** — a sealed-in player could
buy a border door and walk straight out. `is_door_sealed(flag)` returns true while a door is one of the
2 border doors of the room currently sealed by an active purge; the buyable-door loop
(`zm_abandoned_cyber_city::zone_door_trigger_wait`, `zm_abandoned_cyber_city.gsc:686`) refuses that
purchase until the purge resolves (also stops an OUTSIDE player buying *into* the sealed room). Pure
query, auto-lifts the instant `acc_ldc_active` clears. Respects `acc_lockdown_lock_doors 0`.

> **Note:** `tools/add_lockdown_seals.js` (the old `acc_seal_*` brush generator) is **superseded and
> unused** — the door-reuse seal replaced the never-built brush-authoring plan entirely. The file still
> sits in `tools/` but is dead; do not run it.

## 9. Co-op rules

- Challenge is per-**room**: membership = valid players (`is_player_valid`, excludes spectators/down)
  `IsTouching` the room volume, captured at the join-window close. Multiple inside players **share** the
  one kill counter and each get the HUD. Everyone else continues the round outside.
- **Downs:** an inside member bleeds out per stock; only other inside members or solo Quick Revive can
  revive. Outsiders **cannot** revive through the solid seal (stock revive needs sight+bullet trace,
  blocked by the door). Downed players are **not** auto-killed.
- **Fail** when the purge is **unwinnable** = no party member is **both up AND still inside the room
  volume**. The **inside** half is load-bearing: in co-op a member who bleeds out **inside** the seal
  **respawns OUTSIDE** at the next round, so `is_player_valid` flips back to `true` while they are locked
  *out* — counting that respawned-outside survivor as "still up" is exactly what once left the room
  **sealed for the rest of the game** (`watch_fail`, user 2026-06-24). A downed-inside player *with* an
  outside rescuer available also fails (unseal → the door opening IS the co-op rescue path); a
  downed-inside player with **no** outside rescuer (solo / whole team sealed) keeps the purge alive for
  the self-revive. On fail: cull tagged zombies, unseal, re-enable spawning, **no reward**.
- **Always unseal + re-enable spawning on `end_game`** (`on_end_game_safety` — mandatory soft-lock
  safety valve; also re-opens the sealed doors, not just the spawns).

## 10. Reward (free-for-all loose drop)

Guaranteed random boss-item on completion → `grant_challenge_reward(room_center_origin(zone))` →
`spawn_pickup` a **single loose world drop** at the room centroid: a random item, **free-for-all** — any
player can grab it or leave it for a teammate. It is **not** tied to the killer. Whoever grabs it carries
it → Plaza Implant Bench (first enable free / swap otherwise; per-grabber dedupe → already-owns becomes
Data Shards). Gated on `acc_lockdown_reward` (default 1). **Item only, no Mega Bottle.**

## 11. HUD / telegraph / audio

- **Counter (built):** "GLITCH PURGE" label + a bar that FILLS as you progress + a "killed / total"
  number, server-side `hud::` per inside player (§4.8), top-centre under the zone-name banner. **No
  `clientuimodel` field.** The number reads `killed / N` where N is the live captured total.
- **Telegraph (built):** the **red DEFCON light IS the warning** — there is **no USE prompt**. On the
  join window: a "LOCKDOWN SEALING – get in!" announce; on seal: a "LOCKDOWN ENGAGED – defeat N Glitch
  Stalkers to escape" banner (the live N, never a stale "30"). Clear/fail/timeout each print their own
  banner.
- **Audio / red tint — NOT built (Phase C).** A 2D klaxon on seal, victory/fail stings, and a per-inside
  dark-red `VisionSetNaked` tint are still unimplemented. The challenge file makes **no** `play_sound_2D`
  call and registers **no** tint clientfield today. Audio needs aliases authored in
  `sound/aliases/*.csv` first (silent no-op until then); the tint would need a separate-pool player-scope
  clientfield registered lockstep in `_acc_lui.gsc`+`.csc` (load-test — a mismatch hangs the load).

## 12. Rollout status

- **Core (SHIPPED, `-GscOnly`).** Module + `grant_challenge_reward` + copied glitch-buff body +
  `room_center_origin` + `acc_lockdown_room_lit` notify + `disable/enable_zone_spawning` + the auto wave
  + private counter + server-side HUD + guaranteed reward + all watchdogs. Validates isolation,
  AI-budget, reward, HUD.
- **Door seal (SHIPPED, `-GscOnly`).** The physical lock-in via the existing buyable border doors (§8) —
  crush-safe re-close + `reseal_monitor` + `is_door_sealed` escape-fix. **No geometry, no LED risk** (the
  never-built `acc_seal_*` brush plan was abandoned in favour of door reuse).
- **Phase C — polish (NOT built).** Dark-red tint clientfield, audio aliases + stings, proximity
  telegraph, and live r20+ budget tuning remain.

**Currently gated off by default** — none of the above runs unless `+set acc_lockdown_challenge_on 1`.

## 13. Dvars (all live; defaults from `_acc_lockdown_challenge.gsc`)

| Dvar | Default | Meaning |
|---|---|---|
| `acc_lockdown_challenge_on` | **0** | Master gate. **0 = HARDCODE-DISABLED** (nothing arms; user 2026-07-04). Set 1 to enable. |
| `acc_lockdown_challenge_total` | 0 | Fixed wave-size override; **0 = AUTO** (round × mult). Was 15/40/50 in earlier tuning. |
| `acc_lockdown_challenge_mult` | 2.0 | AUTO wave size = round × this (r10 → 20). |
| `acc_lockdown_challenge_concurrent` | 8 | Glitches on-screen at once = the aggression lever (user: 10→8 = −20% density). Co-op self-limits via the producer's `GetFreeActorCount` gate. |
| `acc_lockdown_challenge_stagger` | 0.6 | Seconds between spawns (replacement trickle). |
| `acc_lockdown_challenge_stagger_initial` | 0.3 | Faster fill while first ramping to the cap. |
| `acc_lockdown_challenge_grace` | 1.5 | Flee-window after the room lights, before the trap arms. |
| `acc_lockdown_challenge_join_window` | 2.0 | Doors stay open this long after the first entry so teammates pile in. |
| `acc_lockdown_challenge_confine` | 0 | Optional soft yank-back (default OFF — the door seal is the real lock-in). |
| `acc_lockdown_challenge_bounds_margin` | 300 | In-room proof radius around anchors for the blink/keep-in clamps. |
| `acc_lockdown_challenge_stall_sec` | 60 | No-progress seconds before the stall-watchdog force-CLEARs a stuck purge. |
| `acc_lockdown_challenge_max_rounds` | 2 | SOFT round cap (fires only if no kill in the round that just ended). |
| `acc_lockdown_challenge_hard_grace` | 4 | HARD cap = soft + this (2+4=6 rounds), fires unconditionally. |
| `acc_lockdown_reward` | 1 | Guaranteed reward drop on clear. |
| `acc_lockdown_challenge_debug` | 0 | On-screen `[ldc]` debug banners (also on when `level.acc_dev`). |
| `acc_lockdown_challenge_force "<zone>"` | — | Dev: force-start a challenge without springing the trap. |

Also reuses `acc_lockdown_lock_doors` (1 — gates the door seal) and the `acc_glitch_*` per-zombie buff
knobs. (The old `_challenge_tint` / `_challenge_drop_lifetime` dvars from the design sketch were never
implemented — see §11 Phase C.)

## 14. Locked design decisions (owner, 2026-06-18)

1. ✅ **Round change mid-challenge:** **stay sealed across rounds** until cleared (always unseal on
   `end_game` as the safety valve).
2. ✅ **Entry = TRAP** (ambient catch), NOT an opt-in prompt. Enter the lit DEFCON room → it's game time.
   The red light + a short flee-grace are the only warning.
3. ✅ **Reward:** a single random boss-item as a **free-for-all loose drop** — anyone can grab it or
   leave it for a teammate; not tied to the killer. **Item only**, no Mega Bottle.

**Still open (needs live testing, not a design choice):** engine actor limit tuning (keep low + rely on
the concurrent cap, or bump?) — decide from a live r20+ co-op starvation test, not on paper. This is the
main reason the whole system is gated off by default (§ top banner).
