# 43 — Lockdown Challenge Room (deep plan)

> **Status: PLAN ONLY (not built).** Produced by a research → design → adversarial-verify
> workflow (2026-06-18, 11 agents). Verdict: **feasible, 5/5 "sound with changes," 0 reject.**
> This doc is the corrected, implementation-ready recipe — it folds in every verifier fix, so the
> design sketch's original mistakes are already removed here. Build from THIS, not the raw sketch.

## 1. Concept (player experience)

Each round, `_acc_lockdown` already lights ONE of four rooms RED (Vault / Alley / Helipad=`roof_zone`
/ Market) and rotates which. This feature turns that lit room into a **TRAP challenge** (decisions
locked by the owner, 2026-06-18):

- You **see the red light from outside — it's the warning.** The lit (DEFCON) room is a **trap**:
  walk in while it's red, accidentally or on purpose, and **it's game time** — the room seals behind
  you. There is **no opt-in prompt**; the red light is the only telegraph. (A brief grace lets anyone
  *already* standing in the room when it lights bolt out before the trap arms.)
- On the trap springing, the room **seals** (you're locked in; the outside horde can't get in; the
  glitch wave can't get out) and fills with **30 Glitch Stalkers** you must defeat. It's **very hard.**
- It's a **separate game**: the challenge zombies do **not** count toward the round, and the round
  outside keeps spawning/ending independently. The room **stays sealed across round boundaries** until
  all 30 die (decision #1).
- Kill all 30 → the room **opens** and drops a **single random boss-item as a loose world drop —
  free-for-all** (decision #3): anyone can grab it, or leave it for a teammate; a player can walk away
  and someone else picks it up. Whoever grabs it carries it to the Plaza Implant Bench.

## 2. Architecture

New pure-GSC module **`_acc_lockdown_challenge.gsc`**, orchestrated alongside `_acc_lockdown`. It
**reuses four shipped systems** rather than reinventing:

| Reused system | What for |
|---|---|
| `_acc_boss_glitch` | the Glitch Stalker spawn/promote + buffs (HP, teal eyes, blink, speed) |
| `_acc_boss_items` | the random-item → carry → Plaza-bench reward flow |
| `_acc_lockdown` | the red room rotation + `lock_doors`/`unlock_doors` seal toggle |
| `_acc_decontamination` | zone-volume player detection **and** `disable_zone_spawning` (the riser fix) |

**Only one piece touches geometry** — the physical door-seal brushes — and that is deferred to a
later phase that is **gated on a passing LED bake** (see §8). Everything else is **linker-only
(`-GscOnly`)**.

## 3. State machine

```
IDLE
 └─ acc_lockdown lights a room red  ──(new "acc_lockdown_room_lit" notify)──►  ARMED
ARMED  (after a short grace, a TRAP watcher polls the room volume; disarms next round if unsprung)
 └─ a valid player IsTouching the lit room  ──►  COMMIT  (the trap SPRINGS)
COMMIT (snapshot the party = ALL valid players IsTouching the room volume this frame)
 ├─ seal the room (script-confine in Phase A; disconnectpaths brush in Phase B)
 ├─ disable_zone_spawning(zone)         ◄── CRITICAL: stops the outside horde rising INSIDE
 ├─ create X/30 HUD for inside players, klaxon, (Phase C) dark-red tint
 └─ start challenge_producer + watch_fail
ACTIVE  (private quota: spawn 30 glitch, capped concurrent, refill on death; count kills)
 ├─ 30th glitch dies  ──►  CLEAR  (unseal, re-enable spawning, reward, teardown)
 └─ every live party member down + an outside player alive  ──►  FAIL (unseal, re-enable, no reward)
TEARDOWN  (one-shot guarded; fires "acc_ldc_done"; clears tagged stragglers; back to IDLE)
```

Every thread carries `level endon("end_game")` **and** `level endon("acc_ldc_done")`. Teardown is
guarded one-shot so CLEAR and FAIL can never both run.

## 4. ⚠️ Hard-won correctness fixes (the verifier findings — do NOT skip)

These are the bugs the adversarial pass caught. The plan is only correct **with all of them**.

1. **FATAL — riser leak.** The doorway seal only blocks *walking*. The outside round spawns zombies
   from **`riser_location` structs that rise out of the floor INSIDE the room** (`<zone>_spawners`
   are interior risers), so the horde would mix into the sealed challenge. **Fix:** during the seal,
   call `acc_decontamination::disable_zone_spawning(zone)` (sets `level.zones[zone].is_spawning_allowed=false`
   + per-spot `loc.is_enabled=false`/`is_blocked=true`), and **re-enable on teardown** with a NEW helper
   (decon intentionally never re-enables — the challenge must, or that room's outside spawns die for
   the rest of the run). Confinement is therefore **three cooperating mechanisms**, not just the brush:
   (a) `disable_zone_spawning` (no risers fire inside), (b) `disconnectpaths`/seal (no walk-in),
   (c) per-teleport in-room clamp (glitch can't blink out). The brush alone is necessary-but-insufficient.

2. **Round-boundary unseal conflict.** `_acc_lockdown::run_lockdown()` runs every `acc_round_start`
   and unconditionally `lockdown_clear()` → `unlock_doors()`. That would **re-open the sealed challenge
   room mid-fight** (and re-pick a new red room). **Fix:** `_acc_lockdown` must **skip its clear +
   re-pick while `level.acc_ldc_active` is set** (suppress `unlock_doors` for the active challenge zone;
   don't rotate to a new room until the challenge resolves).

3. **Actor-budget reality.** Glitch zombies are invisible to the round's *completion* count and its
   28-live *spawn* budget (both filter `ignore_enemy_count`, verified `_zm.gsc:4733` / `:3735`), **but
   they DO consume the shared engine actor pool.** `spawn_zombie` hard-busy-waits on
   `GetFreeActorCount()<1` (`zombie_utility.gsc:1462`), so the producer's pre-check isn't sufficient —
   it can block *inside* the spawn under a dense outside horde. That's acceptable (it stalls the
   challenge, never the round) **only if** the producer thread carries the teardown endons so it's
   killed cleanly. Keep concurrent low (`default 6`, gated on `GetFreeActorCount()>=1`); live-test at
   r20+ before raising `ACC_ACTOR_LIMIT` past 35 (don't approach the ~32 co-op netcode zone).

4. **Scheduled-glitch stacking.** On a round that is *both* a challenge and a glitch-cadence round
   (3/13/23…), the scheduled glitch bosses + the challenge wave stack on the actor pool. **Fix:** gate
   `_acc_boss_glitch::maybe_spawn_for_round` on `!isdefined(level.acc_ldc_active)` (suppress the
   scheduled wave while a challenge is live).

5. **Blink strands zombies outside the seal.** `GetClosestPointOnNavMesh` can clamp a blink/charge
   teleport to the *corridor* side of the seal, stranding a stalker that can never path back (quota
   never completes). **Fix:** for challenge-tagged actors (`self.acc_ldc`), clamp every teleport target
   to a point **proven inside the room** (reject nav points whose XY is outside the room AABB; fall back
   to centroid). Apply in both `glitch_blink_loop` and `glitch_phase_in`.

   > **RESOLVED 2026-06-18 (implemented, `-GscOnly`).** Rather than an AABB (rooms.json is stale, zones
   > overlap), the in-room proof uses each room's own interior **spawn anchors** (`<zone>_spawners`),
   > stocked on the actor (`self.acc_ldc_anchors`) at spawn. Three layers, all no-op off-challenge:
   > (a) `_acc_boss_glitch::glitch_blink_loop` blinks challenge zombies to a **random in-room anchor**
   > (`ldc_random_anchor_nav`) instead of `player + blink_offset()`; (b) `glitch_phase_in` skips any
   > charge step whose nav point is **not within `acc_lockdown_challenge_bounds_margin` (default 300u)
   > of any anchor** (`ldc_in_room`) — the AI walks the last bit; (c) `_acc_lockdown_challenge::
   > ldc_keep_in_room` polls each zombie at 1 Hz and force-teleports any that escaped back to an anchor.
   > Combined with the door seal (§8) + `disable_zone_spawning`, containment is now belt-and-suspenders.

6. **30-items bug.** `_acc_boss_glitch::glitch_death_watch` drops a boss-item + Mega Bottle on **every**
   stalker death. The challenge wave **must use its own `ldc_death_watch`** (tagged `self.acc_ldc`) and
   grant the reward **once** on the 30th. Never route challenge kills through `glitch_death_watch` /
   `on_boss_death`.

7. **Teardown thread leak / double-resolve.** When teardown culls survivors, each survivor's death
   watch would re-increment the counter (spurious CLEAR + unearned reward). **Fix:** add a single
   `acc_ldc_done` notify endon'd by every challenge thread; set `level.acc_ldc_teardown=true` at the top
   of CLEAR/FAIL **before** culling; guard `ldc_death_watch` with
   `if(!IS_TRUE(self.acc_ldc) || IS_TRUE(level.acc_ldc_teardown)) return;`; one-shot guard
   `if(IS_TRUE(level.acc_ldc_resolved)) return; level.acc_ldc_resolved=true;` so CLEAR and FAIL are
   mutually exclusive.

8. **HUD must NOT use the `clientuimodel` pool.** That pool is **exactly full at 64 bits** — adding a
   field crashes at load (uncaught by the build; memory `round-progress-ring-hud`). Build the "GLITCH
   PURGE X/30" counter the **`_acc_health_bars` server-side way** (`hud::createFontString` +
   `hud::createBar` + `acc_set_bar_smooth`), per inside player, destroyed on teardown/disconnect. No
   new clientfield for the counter.

9. **Sketch corrections.** `play2d` is not a builtin → use `zm_utility::play_sound_2D`.
   `SetGoalVolume` does not exist in this build → use plain `SetGoal(centroid)`. The
   `acc_lockdown_*` sound aliases don't exist yet → silent no-op until authored (Phase C).
   `ignore_round_spawn_failsafe=true` is harmless but **redundant** (the failsafe is only threaded by
   stock `round_spawning`, which these direct spawns never use) — keep as belt-and-suspenders, but
   don't rely on the "would be culled otherwise" reasoning.

10. **Four helpers are net-new code (not "reuse verbatim").** `acc_boss_glitch::apply_glitch_buffs`
    (the buffs are currently inline in `spawn_glitch:210-301`, interwoven with the behaviour threads —
    extracting a clean buff helper that **excludes** `glitch_death_watch` is the single biggest piece of
    real work; **prefer copying the buff body into the new module** rather than refactoring the live
    boss file, to avoid destabilising it), `acc_lockdown::room_center_origin` (refactor the centroid out
    of `room_emitter_origins`), the `acc_lockdown_room_lit` notify (add to `lockdown_apply`), and
    `acc_boss_items::grant_challenge_reward` (net-new).

## 5. Component build spec

| Component | Mechanism (corrected) |
|---|---|
| **`watch_challenge`** | `level waittill("acc_lockdown_room_lit", zone)` (new notify in `lockdown_apply`); gate on `acc_lockdown_challenge_on`; `arm_entry(zone)`. One challenge at a time (`level.acc_ldc_active`). |
| **`arm_trap`** (TRAP, ambient catch — decision #2) | wait `acc_lockdown_challenge_grace` (~1.5s, the flee-window for players already inside when the room lit), then poll the room volume (`get_zone_volumes` / `player_in_zone_volumes`) ~every 0.25s; the first valid player `IsTouching` **springs the trap** → snapshot party = ALL valid players inside this frame → `commit_challenge`. **No `trigger_use`, no prompt** — the red light is the only warning. Disarm on the next `acc_round_start` if unsprung. |
| **`commit_challenge`** | seal (Phase A: script-confine; Phase B: `acc_lockdown::lock_doors`) **+ `acc_decontamination::disable_zone_spawning(zone)`**; set state; per-party HUD + klaxon + (Phase C) tint; thread `reseal_monitor` (re-assert seal + spawn-disable every ~1s), `challenge_producer`, `watch_fail`. |
| **`challenge_producer`** | loop while `spawned < total`: if `ldc_alive() >= concurrent` or `GetFreeActorCount()<1` wait; else `spawn_challenge_glitch`, `spawned++`, thread `ldc_death_watch`; `wait stagger`. Endon `end_game`+`acc_ldc_done`. |
| **`spawn_challenge_glitch`** | `host = acc_boss_glitch::spawn_promoted_zombie()`; apply the glitch buffs **inline (copied)** minus `glitch_death_watch`; `host.acc_ldc=true; ignore_nuke=true`; `forceteleport` to an in-room nav point from `<zone>_spawners`; `SetGoal(centroid)`. |
| **`ldc_death_watch`** | `self waittill("death", attacker)`; guard `acc_ldc`/`teardown`; `killed++`; refresh HUD; if `killed >= total` → `challenge_clear(zone, attacker, in-room origin)`. Endon `acc_ldc_done`. |
| **`watch_fail`** | poll ~0.5s: live party = connected non-removed members; if empty → fail; else if **every** live member `player_is_in_laststand()` AND an **outside** player `is_player_valid` → `acc_ldc_fail`. Never fail while anyone is up/self-reviving (keeps the stock solo-wipe→end_game path authoritative). Re-arm on revive. |
| **`challenge_clear` / `challenge_fail`** | one-shot guard; `level.acc_ldc_teardown=true`; notify `acc_ldc_done`; unseal (`unlock_doors` in Phase B) **+ re-enable the room's spawning**; teardown HUD/tint/party; cull tagged stragglers; CLEAR → `acc_boss_items::grant_challenge_reward(killer, in-room origin)`; `acc_ldc_active=undefined`. Always unseal+re-enable on `end_game`. |
| **`grant_challenge_reward`** (in `_acc_boss_items`) | guaranteed **free-for-all world drop** (decision #3): pick random from `level.acc_item_pool` → existing `spawn_pickup(picked, origin)` at the room centroid. **No killer-tie / no killer dedup** — a loose drop ANYONE can grab (or leave for a teammate). The per-grabber dedupe in `watch_pickup` already converts "already owns it" → Data Shards at pickup. |

## 6. Round isolation ("separate game") — verified

`ignore_enemy_count=true` (already on every glitch, `_acc_boss_glitch.gsc:255`) makes the 30 invisible
to **both** the round-end gate (`get_current_zombie_count()>0 || zombie_total>0`, `_zm.gsc:4733`) and
the horde spawn budget (`>= zombie_ai_limit`, `_zm.gsc:3735`) — both filter it via `get_round_enemy_array`
(`zombie_utility.gsc:2031`). The challenge tracks its **own** `level.acc_ldc_killed`, never
`level.zombie_total`, and spawns **directly** via `spawn_promoted_zombie` (never `round_spawning`). The
outside round therefore spawns and ends on its own horde, and a bugged challenge can never soft-lock the
round. The shared cost is only the **engine actor pool** — managed by the concurrent cap (§4.3).

## 7. Confinement — the three mechanisms

1. **`disable_zone_spawning(zone)`** during the seal — no outside risers fire inside (§4.1). Re-enable on
   teardown (new helper).
2. **Seal** — Phase A: a script "teleport-the-player/zombie back if they leave the room volume" monitor
   (`SetGoal` pin + `IsTouching` poll, the decon `enforce_spawn_seal` pattern). Phase B: the physical
   `disconnectpaths` brush (no walk-in/out). Phase A confinement is *soft* (a determined zombie/player can
   break it) → **Phase A is dev/solo validation only, not a coop-shippable milestone.**
3. **Per-teleport in-room clamp** for challenge-tagged glitch (§4.5).

## 8. Door-seal geometry + LED reality (Phase B)

> **RESOLVED 2026-06-18 — implemented WITHOUT new geometry (no LED risk), via the stock crush-safe
> door CLOSE.** A geometry probe of the *current* map (heavily reworked since rooms.json) showed each
> of the 4 rooms is bordered by exactly **2 stock buyable doors** (`acc_door_*` `script_brushmodel`s):
> vault = `acc_door_vault` + `acc_door_lab_e`; roof = `acc_door_roof` + `acc_door_lab_w`; alley =
> `acc_door_alley` + `acc_door_corp_e`; market = `acc_door_market` + `acc_door_corp_w`. The seal
> **re-closes those existing doors** and restores them on teardown (only doors whose `enter_*` flag is
> set — an un-bought door is already a wall). Pure GSC, `-GscOnly`, zero `.map` edit → zero LED risk.
>
> **HOW THE SEAL WORKS — and a regression-and-fix saga (settled 2026-06-18).** The load-bearing fact is
> *how this map OPENS its doors*: the entry script `acc_hardcoded_open_map` (and `_acc_dev::dev_open_all_
> doors`) force-open every door via `slab ConnectPaths(); NotSolid(); Hide()` **IN PLACE** — the slab
> never moves, it just goes invisible + non-colliding at its CLOSED origin z[0,128]. So:
> - **SEAL = `e Show(); e DisconnectPaths(); e Solid()` in place** (the slab is already at z[0,128]).
> - **UNSEAL = `e Hide(); e NotSolid(); e ConnectPaths()`** (exactly how the map opened it).
> - **Crush-safety WITHOUT moving the slab:** gate `Solid()` on `door_player_touching(e)` (stock
>   `IsTouching` occupancy, `_zm_blockers.gsc:1104`) — only solidify when the doorway is player-clear; a
>   1 Hz `reseal_monitor` re-asserts `Show`+`DisconnectPaths`+gated-`Solid` (so a door left un-solid
>   because a player stood in it finishes the moment they step off). `commit_challenge` first relocates
>   the party to a **navmesh-snapped, degenerate-guarded** room centre (`relocate_party_safe` — never the
>   raw `room_center_origin`, which returns (0,0,0) with no spawners = an OOB-kill), so the doorway is
>   normally already clear and it solidifies instantly.
>
> **The detour (do not repeat):** the `acc_door_*` brushmodels DO carry `script_vector "0 0 130"`, so a
> crush-safety workflow (correct *in the abstract* for the stock buy path, where `door_classify` sets
> `script_string="move"` and a bought door slides +130z UP) switched the seal to
> `zm_blockers::door_activate(t, false)`. But this map BYPASSES the buy (it force-opens in place), so the
> slab is at z[0,128], and `door_activate(false)` `MoveTo`s it `origin − script_vector` = **below the
> floor** → "the room doesn't lock anymore." Reverted to the in-place `show/solid` above. **Lesson:
> before re-closing a door, check HOW it was opened — hide-in-place → show/solid; stock-buy/MoveTo-up →
> MoveTo back down.** `acc_lockdown_lock_doors` (1) gates the seal. `tools/add_lockdown_seals.js` is
> obsolete. The rest of this section is the superseded brush-authoring plan.

### 8 (superseded) — Door-seal geometry + LED reality (Phase B — NOT assume-able)

The physical lock-in needs `acc_seal_<zone>` `script_brushmodel`s across each room's doorways
(`lock_doors`/`unlock_doors` already drive them). **But the verifier flagged this as the riskiest, least
certain piece:**

- The `acc_seal_*` brushes (and `tools/add_lockdown_seals.js`) are a **named, confirmed
  `brush.cpp:1860` LED-crash culprit** (docs/40 §5b: "crashes in EVERY configuration tried"). The
  earlier "pre-built LED-safe" claim is **refuted by prior testing.**
- `-SkipLED` is **no longer acceptable** — the map was reverted to a baking baseline and **the LED bake
  is now the gate** (`build_map.ps1`: "-SkipLED is a RED FLAG"). Shipping seals with `-SkipLED` hides
  exactly the regression the gate catches.
- The current working map already carries ~70 more unpacked-UV faces than the baking baseline, so it may
  be near the atlas limit **before** any seals. The seal coordinates in the design sketch are also
  **stale** (current walls are ~`z88`, not `z256`; the bridge/levers/raise edits moved geometry) — they
  must be **re-derived from the current `.map`.**

**Therefore Phase B procedure (do NOT shortcut):** (1) run `tools/_bake_test.ps1` on the *current* map →
confirm `RESULT: BAKED` at baseline. (2) Author seals **in the Radiant GUI** (clean packed brushes), per
the memory's mandated method — **not** the text generator (which made the malformed brushes blamed for
the crash). (3) `_bake_test.ps1` again → `RESULT: BAKED` is the hard gate; if it crashes, **revert the
seals** (don't ship `-SkipLED`). Verify each room's **complete** nav-opening set (Helipad/roof is a
rooftop — confirm no vertical/jump-down edge bypasses a wall seal). Until then, **Phase A's script
confinement is the real v1.**

## 9. Coop rules

- Challenge is per-**room**: membership = valid players (`is_player_valid`, excludes spectators/down)
  `IsTouching` the room volume at the commit frame. Multiple inside players **share** the one 30-kill
  counter and each get the HUD. Everyone else continues the round outside.
- **Downs:** an inside member bleeds out per stock; only other inside members (radius-40 revive trigger,
  LOS) or solo Quick Revive (`auto_revive`, no LOS) can revive. Outsiders **cannot** revive through a
  Phase-B solid seal (stock revive needs sight+bullet trace, blocked by the brush — verified). Do **not**
  auto-kill downed players (no decon `kill_players_in_zone`).
- **Fail** only when every live member is simultaneously in laststand **and** an outside player is alive
  (so it doesn't pre-empt the stock solo-wipe→`end_game`). On fail: cull tagged zombies, unseal, re-enable
  spawning, no reward — so a revived/bled-out player is never permanently walled.
- **Always unseal + re-enable spawning on `end_game`** (mandatory solo soft-lock safety valve).

## 10. Reward (decision #3 — free-for-all loose drop)

Guaranteed random boss-item on the 30th kill → `grant_challenge_reward` → `spawn_pickup` a **single
loose world drop** at the room centroid: a random item, **free-for-all** — any player can grab it, or
leave it for a teammate to take (a player can walk away and someone else picks it up). It is **not**
tied to the killer. Whoever grabs it carries it → Plaza Implant Bench (first enable free / 2500 swap;
per-grabber dedupe already solved — already-owns → 3 Data Shards). Gate on `acc_lockdown_reward`
(default 1). **Item only, no Mega Bottle.**

## 11. HUD / telegraph / audio

- **Counter:** "GLITCH PURGE X / 30" — server-side `hud::` per inside player (§4.8), depleting bar via
  `acc_health_bars::acc_set_bar_smooth`. **No `clientuimodel` field.**
- **Telegraph (trap — decision #2):** the **red light IS the warning** — there is **no USE prompt**.
  Optional: a proximity hint to players approaching the lit doorway ("DEFCON — DO NOT ENTER unless you
  want the fight") and a one-time "LOCKDOWN ENGAGED — DEFEAT 30 GLITCH STALKERS" banner the instant the
  trap springs. The fairness comes from the red telegraph + the short flee-grace, not from a prompt.
- **Audio/feel (Phase C):** 2D klaxon on seal, victory sting on clear, downbeat on fail — via
  `zm_utility::play_sound_2D`; **aliases must be authored** in `sound/aliases/acc_audio.csv` first (silent
  no-op until then). Optional per-inside-player dark-red `VisionSetNaked` tint — **net-new** client path
  via a **separate-pool** player-scope clientfield (registered lockstep in `_acc_lui.gsc`+`.csc` or the
  load **hangs** — load-test, don't just build); the `zombie_turned` visionset name is unverified.

## 12. Phased rollout

- **Phase A — GSC-only, script confinement, no seal (the shippable v1, `-GscOnly`).** New module +
  `grant_challenge_reward` + copied glitch-buff body + `room_center_origin` + `acc_lockdown_room_lit`
  notify + `disable_zone_spawning`/re-enable + the 30-wave + private counter + server-side HUD + guaranteed
  reward. **Must include `disable_zone_spawning`** even in Phase A (else the isolation you validate is a
  false positive). Validates isolation, AI-budget, reward, HUD with **zero geometry**. **Dev/solo
  validation only** — coop "others-out / no-revive-through" rules need Phase B.
- **Phase B — physical seal (geometry, LED-gated).** Re-derive seal coords from the current `.map`, author
  in Radiant GUI, gate on `_bake_test.ps1` `RESULT: BAKED`, full `build_map.ps1` (LED on, **never**
  `-SkipLED`). Switch confinement from soft-pin to `disconnectpaths` + re-seal monitor. **Only attempt
  once the live bake question is answered** — if it won't bake, the script-pin stays v1.
- **Phase C — polish.** Proximity telegraph, dark-red tint clientfield (lockstep + load-test), audio
  aliases + stings, banner, coop tuning (concurrent-by-player-count, fail-on-wipe, revive-through-seal
  confirmation), live r20+ budget tuning.

## 13. Dvars (all live)

`acc_lockdown_challenge_on` (1) · `_total` (30) · `_concurrent` (6, the AI-budget safety) · `_stagger`
(1.5) · `_grace` (1.5, the flee-window before the trap arms — decision #2) · `acc_lockdown_reward` (1)
· `_challenge_debug` (0) · `_challenge_force "<zone>"` (dev start without springing the trap) ·
`_challenge_tint` (1, Phase C) · `_challenge_drop_lifetime` (60). Reuses `acc_lockdown_lock_doors`
(Phase B seal) and the `acc_glitch_*` per-zombie buff knobs.

## 14. Decisions

**LOCKED by the owner (2026-06-18):**
1. ✅ **Round change mid-challenge:** **stay sealed across rounds** until all 30 die (always unseal on
   `end_game` as the safety valve).
2. ✅ **Entry = TRAP** (ambient catch), NOT an opt-in prompt. Enter the lit DEFCON room → it's game
   time. The red light + a short flee-grace are the only warning. (Overrides the design's original
   opt-in recommendation, deliberately.)
3. ✅ **Reward:** a single random boss-item as a **free-for-all loose drop** — anyone can grab it or
   leave it for a teammate; not tied to the killer. **Item only**, no Mega Bottle.

**Still open (needs live testing, not a design choice):**
4. **`ACC_ACTOR_LIMIT`:** keep 35 + low concurrent cap, or bump to ~42–44? Decide from a live r20+
   co-op starvation test, not on paper.
5. **Phase B (physical seal) feasibility** is contingent on the seal brushes actually baking on the
   *current* map (the verifier flagged them as a confirmed LED-crash culprit). If they won't bake, v1
   ships with the Phase-A script confinement and the "trap" is enforced by the soft pin until a bakeable
   seal exists.
