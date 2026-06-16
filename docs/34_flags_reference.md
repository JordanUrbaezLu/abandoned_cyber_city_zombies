# 34 — Dvar Flags Reference (dev / test / tuning)

**The golden rule: no flags = a clean consumer game.** Every flag below is read
with a default that means "off / intended behavior", so a launch with **no dvars
set** plays exactly as a Workshop player will experience it — closed map, earn
your own money, decontamination hazard live, no dev HUDs. This is how we expect
consumers tF play. Flags are strictly **opt-in** tweaks for testing and tuning.

> These are runtime **dvars**, not build settings. Nothing here is baked into the
> `.ff` — toggling a flag never needs a rebuild, just a relaunch (or a live
> console set for the ones polled at runtime).

---

## How to set a flag

- **At launch** (how the test scripts do it): add `+set <name> <value>` to the
  game command line. Example: `+set acc_dev 1`.
- **In the in-game console** (needs `+set developer 1`, which the test scripts
  pass): press `~` and type `<name> <value>`, e.g. `acc_skip_round 1`. The
  one-shot dev commands (teleport / skip / open-doors) are designed to be typed
  this way mid-session.
- The launch scripts already set the test flags for you:
  - **`PLAY_TEST_MAP.bat`** / **`tools/run_game.ps1`** (no args) → full test
    sandbox: `acc_dev 1` + `acc_open_map 1` + `acc_test_boss 1` + `acc_glitch_test 1`
    + `acc_glitch_debug 1` + `acc_variants_debug 1` (both the Brutus and Glitch Stalker
    test bosses spawn from round 2).
  - **`run_game.ps1 -ClosedMap`** → dev sandbox but the map starts closed and the
    decon hazard is live (test door buys / decontamination).
  - **`run_game.ps1 -NoDev`** → clean consumer game (no sandbox, closed map).
  - **`run_game.ps1 -NoBoss`** / **`-NoVarDebug`** → drop just that flag.

### Quick recipes

| Goal | Command line |
|---|---|
| Full dev sandbox | `+set acc_dev 1 +set acc_open_map 1 +set acc_test_boss 1 +set acc_variants_debug 1` |
| Clean consumer game | *(no acc_ flags at all)* |
| Sandbox, closed map (test decon / door buys) | `+set acc_dev 1` (omit `acc_open_map`) |
| Tune the boss loop only | `+set acc_test_boss 1` |

---

## A) Dev / sandbox flags

These move the game **away** from intended consumer play. All default `0` (off).

| Flag | Effect when `1` | Read site |
|---|---|---|
| `acc_dev` | Master dev sandbox. Enables the `_acc_dev` module **and** the entry-script `acc_hardcoded_dev` thread: unlimited money (topped to ~1,000,000), unlimited Data Shards, Mega Bottles topped up, **auto power-on**, perk cap raised to 18, on-screen dev banner + zone-name HUD + crosshair damage numbers, and the dev console commands below. | [`zm_abandoned_cyber_city.gsc` main()](../scripts/zm/zm_abandoned_cyber_city.gsc#L150) · [`_acc_dev.gsc:36`](../scripts/zm/zm_abandoned_cyber_city/_acc_dev.gsc#L36) |
| `acc_open_map` | Opens **every** buyable door + activates the zone behind it, and opens **both** per-run PaP blocker brushes, on spawn — the whole map (Mystery Box included) is walkable from the start. Also **disables the decontamination zone-seal hazard** (it is lethal to a player roaming a fully-open map). | [`zm_abandoned_cyber_city.gsc` main()](../scripts/zm/zm_abandoned_cyber_city.gsc#L150) |

### Dev console commands (only active while `acc_dev 1`)

These are watched by the `_acc_dev` module, so they do nothing unless `acc_dev`
is on. Each is a **one-shot**: set it to `1`, it fires, then it auto-resets to `0`.

| Command | Effect | Read site |
|---|---|---|
| `acc_open_doors 1` | Open every buyable door + both PaP blockers (manual equivalent of `acc_open_map`). | [`_acc_dev.gsc:88`](../scripts/zm/zm_abandoned_cyber_city/_acc_dev.gsc#L88) |
| `acc_skip_round 1` | Kill all live zombies + end the round → advance to the next round. | [`_acc_dev.gsc:186`](../scripts/zm/zm_abandoned_cyber_city/_acc_dev.gsc#L186) |
| `acc_tp_perks 1` | Teleport all players to the perk row. | [`_acc_dev.gsc:78`](../scripts/zm/zm_abandoned_cyber_city/_acc_dev.gsc#L78) |
| `acc_tp_spawn 1` | Teleport all players back to spawn. | [`_acc_dev.gsc:83`](../scripts/zm/zm_abandoned_cyber_city/_acc_dev.gsc#L83) |

---

## B) Test flags

Intended for testing a specific system without grinding to it. Default `0`.

| Flag | Effect when `1` | Read site |
|---|---|---|
| `acc_test_boss` | Spawns a low-HP test boss every round from round 2, dropping 10 Mega Bottles on death — exercises the boss → bottle → Mega-perk loop without surviving to the natural boss round. Sampled each round (not one-shot). | [`_acc_boss.gsc:71`](../scripts/zm/zm_abandoned_cyber_city/_acc_boss.gsc#L71) |
| `acc_panzer_test` | Spawns a test Spiki Panzer at the lab on round 2 (stage-1 go/no-go). Gated OFF by default 2026-06-14 so it can't confound other tests. | [`_acc_boss_panzer.gsc`](../scripts/zm/zm_abandoned_cyber_city/_acc_boss_panzer.gsc) |
| `acc_glitch_test` | Spawns the Glitch Stalker (×2, low HP) every round from `acc_glitch_test_round` (default 2) so the blink → vulnerability → reward loop is testable without surviving to r12. **Also fires automatically whenever `acc_dev` is on** (the default — see entry-script `getdvarint("acc_dev",1)`), so the boss is visible in any dev session even when this flag isn't passed. `acc_glitch_enable 0` disables both. | [`_acc_boss_glitch.gsc`](../scripts/zm/zm_abandoned_cyber_city/_acc_boss_glitch.gsc) |

---

## C) Gameplay modifiers (`acc_mod_*`)

Opt-in **rule changes** (the replayability "modifiers" from docs/07). Each is a
distinct dvar named `acc_mod_<name>`, default `0`, read once at load
([`_acc_modifiers.gsc:78`](../scripts/zm/zm_abandoned_cyber_city/_acc_modifiers.gsc#L78)).
These are an intended player-facing feature, currently surfaced only as dvars
(no in-map UI yet), so they belong with the flags for now.

| Flag | Effect when `1` |
|---|---|
| `acc_mod_code_red` | Elite spawn rate ×1.5 + zombie HP ×1.2. |
| `acc_mod_limited_liability` | Disables Jugger-Nog. |
| `acc_mod_fragility` | Each player's max health halved. |
| `acc_mod_bleed_out` | Bleed-out (down) time ×0.5. |
| `acc_mod_draft_mode` | Every 120s, offer a random 3-perk pick. |
| `acc_mod_shardless` | No shard pickups; periodic free cyberware handouts instead. |
| `acc_mod_one_shot` | Only one Overclock slot. |
| `acc_mod_roguelike_lite` | Roguelike per-player down rules. |
| `acc_mod_express` | Express-start pacing. |
| `acc_mod_sprint` | Force-sprint zombies. |
| `acc_mod_shortened_rounds` | Round zombie count ×0.6. |

> **Known caveats** (tracked from the 2026-06-14 architecture audit): `acc_mod_bleed_out`
> may not apply unless a cyberware bleed-out recompute fires — don't trust it until fixed.
> (`acc_mod_sprint` is **now wired** as of 2026-06-14 — `level.acc_mod_force_sprint` clamps the
> zombie speed curve to ≥100% every round and forces the sprint cycle; see `_acc_zombie_speed.gsc`.)

---

## D) Gameplay-tuning flags

Knobs that tune intended behavior. **Note the polarity:** `acc_weapon_variants`
defaults **ON** (set `0` to disable); everything else defaults off.

| Flag | Default | Effect | Read site |
|---|---|---|---|
| `acc_weapon_variants` | **`1` (on)** | Master enable for the weapon-variant "twin" swap system (Deadshot/Speed Cola/Double Tap/Mega stat swaps). Set `0` to disable all swaps (guns fall back to their base weapon). This is an intended live feature — leave on for normal play. | [`_acc_weapon_variants.gsc:624`](../scripts/zm/zm_abandoned_cyber_city/_acc_weapon_variants.gsc#L624) |
| `acc_zspeed_sprint_round` | `10` | First round zombies use the full **sprint** gait. Rounds before this use the **run** gait (a jog). This is the "they break into a sprint" round. Read **live per spawn**. | [`_acc_zombie_speed.gsc` `tier_for_round`](../scripts/zm/zm_abandoned_cyber_city/_acc_zombie_speed.gsc) |
| `acc_zspeed_jog_start_pct` | `100` | Round-1 jog playback rate, as % (`100` = the run anim's **natural** cadence/speed). Floored at 100 in code — the wave never animates below natural cadence (anything lower would look like slow-motion). | [`_acc_zombie_speed.gsc` `rate_for_round`](../scripts/zm/zm_abandoned_cyber_city/_acc_zombie_speed.gsc) |
| `acc_zspeed_jog_step_pct` | `2` | Added jog playback % per round during the jog phase (rounds 1 → `sprint_round`−1). Higher = the jog ramps up faster. | [`_acc_zombie_speed.gsc` `rate_for_round`](../scripts/zm/zm_abandoned_cyber_city/_acc_zombie_speed.gsc) |
| `acc_zspeed_sprint_start_pct` | `100` | Sprint playback rate at `sprint_round`, as % (`100` = natural full sprint = base-game max). | [`_acc_zombie_speed.gsc` `rate_for_round`](../scripts/zm/zm_abandoned_cyber_city/_acc_zombie_speed.gsc) |
| `acc_zspeed_sprint_step_pct` | `1` | Added sprint playback % per round **after** `sprint_round` (the "+1%/round" creep; rate > 1.0 = a faster sprint, no slow-mo, no upper clamp). | [`_acc_zombie_speed.gsc` `rate_for_round`](../scripts/zm/zm_abandoned_cyber_city/_acc_zombie_speed.gsc) |
| `acc_fog_on` | `0` | `1` enables global volumetric fog (cold city haze); polled every 0.5s so it can be toggled live. | [`_acc_atmosphere.gsc:69`](../scripts/zm/zm_abandoned_cyber_city/_acc_atmosphere.gsc#L69) |
| `acc_brutus_scale` | **`0` (off)** | Brutus **+50% size** buff (`SetScale`). **CONFIRMED to hard-crash the game (0xC0000005) ~1-2s after spawn** — defaulted OFF 2026-06-14. Set `1` only to experiment. Read once, ~a beat after each Brutus spawn. | [`_acc_boss.gsc` `apply_brutus_buffs`](../scripts/zm/zm_abandoned_cyber_city/_acc_boss.gsc) |
| `acc_brutus_speed` | **`0` (off)** | Brutus **+25% speed** think (ASM anim-rate). Defaulted OFF 2026-06-14 (bundled with the crash-suspect buffs; the movement fix already holds him at full forward sprint). Set `1` to experiment. | [`_acc_boss.gsc` `apply_brutus_buffs`](../scripts/zm/zm_abandoned_cyber_city/_acc_boss.gsc) |
| `acc_brutus_runfwd` | **`0` (off)** | Brutus straight-charge **movement fix** (`alwaysRunForward` + wider goal radius) so a circling player can't push him into the slow strafe anim (~75% slower). **Defaulted OFF 2026-06-15** while isolating the "freezes every spawn" report — baseline is now pack-stock movement + our HP + health bar only. Set `1` to re-enable. NOTE: this fix gates on target acquisition, so it cannot cause an *immediate* on-spawn freeze. Read once per Brutus spawn. | [`_acc_boss.gsc` `brutus_movement_fix`](../scripts/zm/zm_abandoned_cyber_city/_acc_boss.gsc) |
| `acc_brutus_debug` | **`0` (off)** | Diagnostic for the "Brutus spawns then stands frozen" report. `1` prints to all players once a second for ~25s after each Brutus spawn: target acquired?, has a custom goal?, distance to nearest player, and how far he moved last second — separates target-acquisition vs navmesh/pathing vs stuck-spawn-anim without a rebuild. Read once per Brutus spawn. | [`_acc_boss.gsc` `brutus_spawn_diag`](../scripts/zm/zm_abandoned_cyber_city/_acc_boss.gsc) |
| `acc_brutus_force_resume` | **`0` (off)** | Frozen-statue fallback. `1` re-asserts the stock zombie-think resume (`SetGoal` + `PathMode("move allowed")`) on Brutus ~1.5s after spawn, in case locomotion didn't resume after his spawn anim. Confirm the cause with `acc_brutus_debug` first — does NOT help if the goal is unreachable (stale navmesh / spawn spot off-mesh after the room-shrink; that needs a navmesh regen). Read once per Brutus spawn. | [`_acc_boss.gsc` `brutus_force_resume`](../scripts/zm/zm_abandoned_cyber_city/_acc_boss.gsc) |
| `acc_pap_tier_anim` | **`1` (on)** | Each PaP **tier-up** replays the first-pack in-hand "gun comes out" draw (re-equips the held weapon, carrying ammo). Set `0` to revert to instant, animation-free tier-ups. Read per tier-up. | [`_acc_pap_levels.gsc` `replay_pack_draw`](../scripts/zm/zm_abandoned_cyber_city/_acc_pap_levels.gsc) |
| `acc_corpse_linger_sec` | **`5`** | Seconds a zombie corpse stays VISIBLE on the ground before we hide it (`Ghost`). The body is de-collided (`NotSolid`) IMMEDIATELY on death so it never blocks movement/pathing. Set `0` for instant removal (the pre-2026-06-15 behavior). Under a heavy horde the engine's corpse cap may recycle a body sooner — this is an upper bound, not a guarantee. Read per zombie death (bosses skipped). | [`_acc_corpse_cleanup.gsc`](../scripts/zm/zm_abandoned_cyber_city/_acc_corpse_cleanup.gsc) |

### Fog tuning (only read while `acc_fog_on 1`)

All floats, read at [`_acc_atmosphere.gsc:79-86`](../scripts/zm/zm_abandoned_cyber_city/_acc_atmosphere.gsc#L79-L86).

| Flag | Default | Meaning |
|---|---|---|
| `acc_fog_start_dist` | `0` | Distance (units) from camera where fog starts. |
| `acc_fog_halfway_dist` | `700` | Distance to half opacity. |
| `acc_fog_halfway_height` | `900` | Vertical falloff distance. |
| `acc_fog_base_height` | `0` | World-Z where the densest fog sits. |
| `acc_fog_r` / `acc_fog_g` / `acc_fog_b` | `0.22` / `0.27` / `0.38` | Fog color (0..1). |
| `acc_fog_max_opacity` | `0.85` | Max fog opacity (0..1). |

### Glitch Stalker mini-boss tuning

The Glitch Stalker is a script-only **mobile** mini-boss (default **r3**, then every 10
rounds) that teleport-blinks to flank players, moves **~15% faster** than the round's normal
zombies, and takes **bonus damage** in a short window after each blink. It wears the **stock
("Giant") zombie skin** (body + head) so it stands out from the charred horde, and has **no
health bar and no marker** — the skin is the only tell. Most values are read **live**. See
[`_acc_boss_glitch.gsc`](../scripts/zm/zm_abandoned_cyber_city/_acc_boss_glitch.gsc)
and [11_enemies.md](11_enemies.md).

| Flag | Default | Effect |
|---|---|---|
| `acc_glitch_enable` | **`1` (on)** | Master on/off; gates the real cadence **and** the dev/test spawn. Set `0` to disable entirely. (Test spawn also fires whenever `acc_dev` is on — the default.) |
| `acc_glitch_hp_mult` | `3` | HP = this × the round's **normal zombie** health (`level.zombie_health`). Auto-scales with the round — no separate HP curve, no co-op multiplier (the normal-zombie value already reflects the round). |
| `acc_glitch_first_round` | `3` | First round it can spawn (real cadence). |
| `acc_glitch_interval` | `10` | Then every N rounds (r3, 13, 23, …). |
| `acc_glitch_test_round` | `3` | Dev/test path: first round it spawns when `acc_dev`/`acc_glitch_test` is on. |
| `acc_glitch_count` | `2` | Glitch Stalkers spawned per scheduled round. |
| `acc_glitch_speed_mult` | `1.15` | Move speed vs the round's normal zombies (1.15 = +15%). Locks the horde's gait × this rate. |
| `acc_glitch_blink_cd_min` | `1.0` | Min seconds between blinks (halved 2026-06-15 — blinks 2× more often; 6× the original 6.0s baseline). |
| `acc_glitch_blink_cd_max` | `1.665` | Max seconds between blinks (halved 2026-06-15 — blinks 2× more often; 6× the original 10.0s baseline). |
| `acc_glitch_blink_dist` | `300` | Flank offset (units) from the target before the navmesh clamp. |
| `acc_glitch_recovery_sec` | `1.5` | Length of the post-blink vulnerability window. |
| `acc_glitch_recovery_dmg_mult` | `2.0` | Damage the boss **takes** while vulnerable (additive with headshots). Read in `_acc_damage`. **Not** the damage it deals. |
| `acc_glitch_melee_dmg_mult` | `0.5` | Melee damage the boss **deals** to players, vs a stock zombie's 60 (0.5 = −50%, user 2026-06-15). Scales `host.meleeDamage` at spawn (`_acc_boss_glitch.gsc::spawn_glitch`). |
| `acc_glitch_stock_skin` | **`1` (on)** | Swap the boss to the stock Giant zombie **body + head** (vs the charred horde). Set `0` to keep the charred look. |
| `acc_glitch_fx` | **`1` (on)** | Brief "glitch" visibility flicker (`Ghost`/`Show`, render-only — stays hittable) as it phases in after each blink. |

> The Glitch Stalker yields its round to the Subroutine Core on full-boss rounds
> (r30/40/50), runs **alongside** the normal wave, and does **not** gate round end (like Brutus).
> **No size override:** a 75% size was requested but NOT implemented — `SetScale` on a live
> zombie AI is the confirmed `0xC0000005` crasher; a smaller body would need a pre-scaled model
> asset (baked at export), swapped via the same `acc_glitch_stock_skin` SetModel path.

---

## E) Debug-visual flags

On-screen debug output only; no gameplay change. Default `0`.

| Flag | Effect when `1` | Read site |
|---|---|---|
| `acc_variants_debug` | On each weapon-variant swap, prints `[variants] <from> -> <to>` to that player's screen (so you can *see* an otherwise-invisible recoil/fire-rate swap happen). | [`_acc_weapon_variants.gsc:347`](../scripts/zm/zm_abandoned_cyber_city/_acc_weapon_variants.gsc#L347) |
| `acc_glitch_debug` | Prints `[glitch] <event>` to every player's screen on each Glitch Stalker spawn / blink / death — trace the boss live without the console. | [`_acc_boss_glitch.gsc` `gdebug`](../scripts/zm/zm_abandoned_cyber_city/_acc_boss_glitch.gsc) |

---

## Conventions & gotchas

- **All flags are `acc_`-prefixed.** No un-prefixed custom dvars exist.
- **Default polarity:** everything defaults to *off / intended behavior* **except
  `acc_weapon_variants`, `acc_brutus_runfwd`, `acc_pap_tier_anim`,
  `acc_glitch_enable`, `acc_glitch_fx`, and `acc_glitch_stock_skin`** (default on).
  Those are the "set to 0 to disable" flags — every other flag is "set to 1 to
  enable". (`acc_corpse_linger_sec` is a numeric seconds value, default `5`; set
  `0` for instant corpse removal.) (`acc_brutus_scale` / `acc_brutus_speed` were flipped to default **OFF**
  on 2026-06-14 — the size `SetScale` is a confirmed spawn crasher.)
- **One-shot vs sustained:** `acc_open_doors`, `acc_skip_round`, `acc_tp_perks`,
  `acc_tp_spawn` auto-reset to `0` after firing (momentary triggers). Everything
  else is a sustained read (stays in effect until you change it / relaunch).
- **Dev console commands need `acc_dev 1`.** The `_acc_dev` module returns early
  when `acc_dev != 1`, so its console watchers (teleport / skip / open-doors) are
  inert without the master flag.
- **Keep this doc in sync.** When you add a new `getdvarint`/`getdvarfloat`
  read, add a row here in the same commit (CLAUDE.md convention: docs follow
  code). Find every read with:
  `node` / grep `getdvar` across `scripts/zm/zm_abandoned_cyber_city/`.
