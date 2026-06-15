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
    sandbox: `acc_dev 1` + `acc_open_map 1` + `acc_test_boss 1` + `acc_variants_debug 1`.
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

> **Known caveats** (tracked from the 2026-06-14 architecture audit, not yet
> fixed): `acc_mod_sprint` is currently a **no-op** (`level.acc_mod_force_sprint`
> is written but never read), and `acc_mod_bleed_out` may not apply unless a
> cyberware bleed-out recompute fires. Don't trust these two until they're fixed.

---

## D) Gameplay-tuning flags

Knobs that tune intended behavior. **Note the polarity:** `acc_weapon_variants`
defaults **ON** (set `0` to disable); everything else defaults off.

| Flag | Default | Effect | Read site |
|---|---|---|---|
| `acc_weapon_variants` | **`1` (on)** | Master enable for the weapon-variant "twin" swap system (Deadshot/Speed Cola/Double Tap/Mega stat swaps). Set `0` to disable all swaps (guns fall back to their base weapon). This is an intended live feature — leave on for normal play. | [`_acc_weapon_variants.gsc:624`](../scripts/zm/zm_abandoned_cyber_city/_acc_weapon_variants.gsc#L624) |
| `acc_rampage` | `0` | `1` activates the Rampage Inducer (sustained zombie aggression). **Activate-only** (polled every 1s); the in-map device is the only way to turn it back off. | [`_acc_rampage_inducer.gsc:278`](../scripts/zm/zm_abandoned_cyber_city/_acc_rampage_inducer.gsc#L278) |
| `acc_fog_on` | `0` | `1` enables global volumetric fog (cold city haze); polled every 0.5s so it can be toggled live. | [`_acc_atmosphere.gsc:69`](../scripts/zm/zm_abandoned_cyber_city/_acc_atmosphere.gsc#L69) |
| `acc_brutus_scale` | **`1` (on)** | Master enable for the Brutus mini-boss **+50% size** buff (`SetScale`). Set `0` to skip it (Brutus spawns at normal size). Read once, ~a beat after each Brutus spawn — so a relaunch (not a live set) is needed to change it. Provided as a **spawn-crash bisect knob**: if Brutus still CTDs, set `0` to rule the size buff in/out. | [`_acc_boss.gsc` `apply_brutus_buffs`](../scripts/zm/zm_abandoned_cyber_city/_acc_boss.gsc) |
| `acc_brutus_speed` | **`1` (on)** | Master enable for the Brutus **+25% speed** think (ASM anim-rate). Set `0` to skip it (Brutus charges at the normal sprint tier). Read once, ~a beat after each Brutus spawn. Companion **bisect knob** to `acc_brutus_scale`. | [`_acc_boss.gsc` `apply_brutus_buffs`](../scripts/zm/zm_abandoned_cyber_city/_acc_boss.gsc) |

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

---

## E) Debug-visual flags

On-screen debug output only; no gameplay change. Default `0`.

| Flag | Effect when `1` | Read site |
|---|---|---|
| `acc_variants_debug` | On each weapon-variant swap, prints `[variants] <from> -> <to>` to that player's screen (so you can *see* an otherwise-invisible recoil/fire-rate swap happen). | [`_acc_weapon_variants.gsc:347`](../scripts/zm/zm_abandoned_cyber_city/_acc_weapon_variants.gsc#L347) |

---

## Conventions & gotchas

- **All flags are `acc_`-prefixed.** No un-prefixed custom dvars exist.
- **Default polarity:** everything defaults to *off / intended behavior* **except
  `acc_weapon_variants`, `acc_brutus_scale`, and `acc_brutus_speed`** (default on).
  Those are the only "set to 0 to disable" flags — every other flag is "set to 1
  to enable".
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
