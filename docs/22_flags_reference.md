# 22 — Dvar Flags Reference (dev / test / tuning)

**The golden rule: no flags = a clean consumer game.** Every flag below is read
with a default that means "off / intended behavior", so a launch with **no dvars
set** plays exactly as a Workshop player will experience it — closed map (buy
your own doors), earn your own money, no dev HUDs. This is how we expect
consumers to play. Flags are strictly **opt-in** tweaks for testing and tuning.
(The old decontamination zone-seal hazard was **removed entirely** — user
2026-06-22, [`_acc_decontamination.gsc:197-205`](../scripts/zm/zm_abandoned_cyber_city/_acc_decontamination.gsc#L197) —
no zone is ever sealed and no player is ever killed by it, in either mode.)

> The BALANCE/TUNING flags below are runtime **dvars** — toggling one never needs
> a rebuild, just a relaunch (or a live console set for the ones polled at
> runtime). **The exception is `acc_dev` / `acc_god`: those are compile-time
> booleans, NOT dvars (since 2026-07-16) — flipping them IS a rebuild.** See
> "How to set a flag" below.

---

## How to set a flag

> **⚠ DEV/GOD ARE NOT DVARS AT ALL (user, 2026-07-15 "we don't use launch flags and this keeps
> happening"; 2026-07-16 "even the dev flag is not used as a launch flag — we hardcode on and
> rebuild").** `level.acc_dev` / `level.acc_god` are **compile-time booleans** in
> `acc_resolve_dev_flags()`: SHIP state is `= false;`, a TEST session flips the line to `= true;`
> **and rebuilds** — that IS the toggle. The old `getdvarint("acc_dev",0)` ship resolution was
> **removed 2026-07-16** (it let any Workshop subscriber arm the dev sandbox with `+set acc_dev 1`);
> `+set acc_dev 1` now does **nothing**. Restore `= false;` before any publish —
> `prep_release.ps1` Gate 0 FAILs on a hardcode-`true` AND on any reappearing dvar read.
> Agents: when asked to "turn on dev/god", make that edit and rebuild; never answer with a `+set`
> arg or a launcher script. The launch-flag mechanics below apply ONLY to the live-BALANCE dvars.

- **At launch** (balance dvars only): add `+set <name> <value>` to the
  game command line. Example: `+set acc_glitch_first_round 4`.
- **In the in-game console** (needs `developer 1`): press `~` and type
  `<name> <value>`. The one-shot dev commands (teleport / skip / open-doors)
  are designed to be typed this way mid-session (they only work while the
  build has `level.acc_dev = true;`).
- **ONE dev flag (user 2026-06-22):** `acc_dev` is the *only* dev switch. A `level.acc_dev = true;`
  build turns on the **whole** hardcoded sandbox — money, 1000 starting shards, a topped-up Mega
  Bottle stash, all perk slots, and the dev HUDs / console commands — plus ALL debug output (which
  rides `IS_TRUE( level.acc_dev )` since 2026-07-16). `acc_resolve_dev_flags()` (entry
  [`main()`](../scripts/zm/zm_abandoned_cyber_city.gsc), function `acc_resolve_dev_flags`) sets the
  global bool **once** and `SetDvar`s `acc_open_map` off it for the one dvar-reading module.
  (No god mode — god is the *separate* `acc_god` flag; no auto power-on either; bosses run their
  REAL cadence in dev. See the `acc_dev` / `acc_god` rows below.)
- The launchers (since 2026-07-15 there is ONE play script):
  - **`PLAY_NORMAL.bat`** / **`tools/run_game.ps1`** → engine args only. Dev/god state comes from the
    BUILD (the `acc_resolve_dev_flags()` hardcode — see the warning at the top of this section).
    `PLAY_TEST_MAP.bat`, `PLAY_GOD_MODE.bat` and `tools\run_avo_test.bat` were **deleted** (user:
    "remove all the play scripts except the Normal play script").
  - `-NoBoss` / `-NoDev` / `-ClosedMap` / `-NoVarDebug` / `-NoAmbient` / `-NoLockdown` remain in
    `run_game.ps1`'s param block for call compatibility but **no longer affect the launch** — dev is
    all-or-nothing by design, and the gameplay knobs they used to bundle (ambient audio, DEFCON
    lockdown, the zombie-speed curve) run on their in-code defaults, not launch flags.

> ### Why one flag, hardcoded — not a runtime console (design rationale, docs/22)
>
> The user's goal is a **binary normal-play vs dev-mode**: dev OFF = the real game, dev ON = a
> *fixed, hardcoded* dev config (money / unlimited / all-unlocked / open perk access). It is
> deliberately **NOT** a runtime console you tweak — **never tell anyone to "set dvar X in the console" to
> test something, and never add a new `acc_dev_*` toggle**, even though a per-feature dvar is the "normal"
> modding practice. This is a CLAUDE.md hard constraint (memory `dev-mode-hardcoded-not-console`).
>
> **The mechanism (use it — do not add flags):** `level.acc_dev` is a compile-time boolean set **once** in
> `acc_resolve_dev_flags()` — the canonical gate every module reads via `IS_TRUE( level.acc_dev )`. The
> resolver also `SetDvar`s the surviving **gameplay** sub-dvar (`acc_open_map`) off that one value. **To add
> a dev behavior: branch on `IS_TRUE( level.acc_dev )` and hardcode the value, or add a `SetDvar` line in
> the resolver — never introduce a new toggle, and never a per-feature `acc_*_debug`/`acc_*_test` dvar
> (all removed 2026-07-16; debug rides `acc_dev`, temp diagnostics get deleted when done).**
>
> Why resolve-once matters: `acc_dev` used to be read at several call sites, each with its *own* literal
> default, and was never shared — so the flag could arm a **partial, mismatched** dev state (money/HUD on,
> perk-slots off). That skew *was* the old "some flags don't work." Setting `level.acc_dev` once and driving
> everything from it kills the skew permanently: the one boolean turns the whole sandbox on or off.

### Quick recipes

| Goal | How (build-state, NOT command line) |
|---|---|
| Full dev sandbox | `level.acc_dev = true;` in `acc_resolve_dev_flags()` + rebuild |
| God test (no dying; combine with dev at will) | `level.acc_god = true;` in `acc_resolve_dev_flags()` + rebuild |
| Clean consumer game / test the real economy | restore `level.acc_dev = false;` / `level.acc_god = false;` + rebuild |

> **⚠️ Dev/God hardcode — VOLATILE, read the code, not this line.** The two SHIP lines in
> `acc_resolve_dev_flags()` are `level.acc_dev = false;` / `level.acc_god = false;` (no dvar read — the
> `getdvarint` resolution was removed 2026-07-16). The user flips them **`true` for local testing** and
> **back to `false` for publish** — often several times a day across parallel sessions — so **any
> "currently ON/OFF" claim in the docs will be stale; the two lines in the code are the only live truth.**
> Either way the shipped artifact is always OFF: `prep_release.ps1` Gate 0 FAILs the publish if either
> line is `true` (and if a dvar read ever reappears).
> **Debug output rides the ONE `acc_dev` flag (re-coupled 2026-07-16, reversing the 2026-07-10 decoupling).**
> The user's standing rule is **only `acc_dev` / `acc_god` / mock flags exist** — the ~26 per-feature
> `acc_*_debug` / `acc_*_test` dvars were REMOVED (all debug gates converted back to `IS_TRUE( level.acc_dev )`;
> leftover/temp on-screen diagnostics deleted). So **dev shows debug, ship is silent** — the trade-off (a
> noisier dev screen) is accepted over juggling levers (see §E + memory `debug-banners-gated-by-acc-dev-only`).
> The dev starting gun is the Blast-O-Matic (`t9_semiauto_cosplay`). `prep_release.ps1` **fails** while either
> flag is hardcoded `true`; **restore `= false;` before any Workshop publish**.

---

## A) Dev / sandbox flags

These move the game **away** from intended consumer play. All default `0` (off).

| Flag | Effect when `1` | Read site |
|---|---|---|
| `acc_dev` | **THE SINGLE DEV SWITCH — a compile-time boolean, NOT a dvar (since 2026-07-16; `+set acc_dev 1` does nothing).** Ship state = `level.acc_dev = false;`; test sessions flip it to `true` + rebuild. *(Working-tree caveat: the line is toggled `true`/`false` frequently — testing vs publish — so check the code, not a date; see the volatility callout under Quick recipes.)* When `true`, `acc_resolve_dev_flags()` `SetDvar`s the sub-dvars off it, turning on the sandbox: money (~1,000,000, `_acc_dev::dev_unlimited_money`), **1000 starting Data Shards** (`ACC_DEV_SHARDS`, one-shot at connect + the per-player cap raised to 1000 — [`_acc_data_shards.gsc:39,106,128`](../scripts/zm/zm_abandoned_cyber_city/_acc_data_shards.gsc#L39); the real economy then runs), **a topped-up Mega Bottle stash** ([`_acc_mega_bottles::dev_unlimited_bottles`](../scripts/zm/zm_abandoned_cyber_city/_acc_mega_bottles.gsc#L82)), **all perk slots** (via the `acc_perks::acc_perk_slot_limit` hook returning MAX while dev — not by raising the global, [`_acc_perks.gsc:144`](../scripts/zm/zm_abandoned_cyber_city/_acc_perks.gsc#L144)), the always-on crosshair damage numbers + area-name banner, the **Leviathan Axe starting gun** (`leviathan` — 2026-07-15, the PaP tier-II fix test vector; swap the runtime name in `_acc_dev::dev_give_starting_guns` to test-start a different gun — history in the code comment), and the dev console commands below. **(2026-07-16: debug output RE-COUPLED to `acc_dev` — the ~26 per-feature `acc_*_debug`/`acc_*_test` dvar levers were removed, reversing the 2026-07-10 decoupling. Debug now shows in dev + is silent in ship, off the ONE flag; leftover/temp diagnostics like the `[COUNTLOG-TEMP]` every-round glitch text were deleted. Only `acc_dev`/`acc_god`/mock exist — never add a new toggle. See §E + memory `debug-banners-gated-by-acc-dev-only`.)** **Dev boss cadence (2026-07-17, supersedes the 07-16 "real cadence" doctrine): 2 Glitch Stalkers spawn EVERY round + one Phantom spawns on round 3** — hardcoded `IS_TRUE( level.acc_dev )` branches in `cadence_hits`/`glitch_count_for_round` and `phantom_due_count` (docs/44 FX eyeballing); **Brutus and the r9/18/27 roster still run REAL** (the old `acc_test_boss` / `acc_glitch_test` / `acc_phantom_test` force-spawn *dvars* stay deleted — these are compile-time dev branches, not levers). **No god mode (that's the separate `acc_god` flag) and no auto power-on — you take regular damage and flip the Bus Station power switch yourself.** **Modules read `IS_TRUE( level.acc_dev )` — to add a dev behavior, branch on that or add a `SetDvar` in the resolver; never add a new flag.** | [`acc_resolve_dev_flags()` :369](../scripts/zm/zm_abandoned_cyber_city.gsc#L369) · gate [`_acc_dev.gsc:73`](../scripts/zm/zm_abandoned_cyber_city/_acc_dev.gsc#L73) |
| `acc_god` | **SEPARATE test flag, independent of `acc_dev` — a compile-time boolean, NOT a dvar (since 2026-07-16; `+set acc_god 1` does nothing).** Ship state = `level.acc_god = false;`; test sessions flip it to `true` + rebuild (the PLAY_GOD_MODE launcher was deleted 2026-07-15). *(Working-tree caveat: the `level.acc_god = true;` hardcode (`:416`) is toggled with `acc_dev` — check the code, not a date; same volatility callout.)* Lets the user test **normal** gameplay (real perks / economy / progression, closed map) without dying. **DEMIGOD since 2026-07-08:** real damage still *lands* (every per-hit effect — EMP, trench-melee scaling, boss chain-slow — fires) but the player's health **floors at 1 HP**, enforced in [`_acc_elites::on_player_damaged`](../scripts/zm/zm_abandoned_cyber_city/_acc_elites.gsc). *Not* an `EnableInvulnerability` loop (that suppressed the whole damage callback and killed the effects). | [`acc_resolve_dev_flags()` :411](../scripts/zm/zm_abandoned_cyber_city.gsc#L411) |
| `acc_auto_power` | **Default `0`; NOT driven by `acc_dev`** (user 2026-06-22 — power is flipped at the Bus Station switch even in dev). Pass `acc_auto_power 1` manually only if you want the dormant shortcut that replicates the flip ~1.5s after blackscreen. | [`zm_abandoned_cyber_city.gsc`](../scripts/zm/zm_abandoned_cyber_city.gsc#L450) |
| `acc_open_map` | **`SetDvar`'d by `acc_dev` but now effectively vestigial.** The old whole-map auto-unlock (`acc_hardcoded_open_map`) is **no longer called** ([`zm_abandoned_cyber_city.gsc:266-267`](../scripts/zm/zm_abandoned_cyber_city.gsc#L266)) — doors must **always be bought** in both modes (`acc_fix_zone_doors` just makes the `.map`-written triggers usable; dev simply has unlimited money to buy them trivially). Decon is gone, so there is nothing left for this dvar to disable. To reach a walled-off perk in dev, use the per-round buy trigger (dev tops you up a Mega Bottle stash to open any closed Lab door) or the `acc_open_doors` console command below. | [`zm_abandoned_cyber_city.gsc` (dormant fn)](../scripts/zm/zm_abandoned_cyber_city.gsc#L794) |

### Power switch (Bus Station) — `_acc_power.gsc`

As of 2026-06-19 (user) power uses the **stock `power_switch` prefab** wall-mounted at `(790 1600 1)`,
which provides the native flip animation + power-on sound + power via stock `_zm_power`. `_acc_power.gsc`
**stands down**: it leaves the prefab's `use_elec_switch` trigger alone and just deletes our leftover
mid-air `acc_power_switch` trigger at runtime (the earlier custom dual-switch + script-spawned lever were
dropped; the `acc_power_*` tuning dvars no longer exist). `acc_auto_power` stays `0`, so the player flips
the wall switch. The custom dual-switch is recoverable from git (restore notes in the module header).

### Dev console commands (only active in a dev build)

These are watched by the `_acc_dev` module, so they do nothing unless `acc_dev`
is on. Each is a **one-shot**: set it to `1`, it fires, then it auto-resets to `0`.

| Command | Effect | Read site |
|---|---|---|
| `acc_open_doors 1` | Set every `enter_*` buyable-door flag → the whole map walkable (the manual open-everything bypass; also clears the door slabs in place). | [`_acc_dev.gsc:135`](../scripts/zm/zm_abandoned_cyber_city/_acc_dev.gsc#L135) |
| `acc_skip_round 1` | Kill all live zombies + end the round → advance to the next round. | [`_acc_dev.gsc:249`](../scripts/zm/zm_abandoned_cyber_city/_acc_dev.gsc#L249) |
| `acc_tp_perks 1` | Teleport all players to the perk row. | [`_acc_dev.gsc:125`](../scripts/zm/zm_abandoned_cyber_city/_acc_dev.gsc#L125) |
| `acc_tp_spawn 1` | Teleport all players back to spawn. | [`_acc_dev.gsc:130`](../scripts/zm/zm_abandoned_cyber_city/_acc_dev.gsc#L130) |

---

## B) Test flags — **REMOVED 2026-07-16**

> **⚠️ The `acc_test_boss` / `acc_glitch_test` / `acc_phantom_test` early-boss-spawn levers were DELETED
> 2026-07-16** (user: only `acc_dev`/`acc_god`/mock flags exist). **Dev boss cadence since 2026-07-17: 2 Glitches/round + a round-3 Phantom (hardcoded dev branches); Brutus + roster REAL** like
> normal play — Brutus on his round-5 power cadence, the Glitch Stalker on `acc_glitch_first_round`/interval,
> the Phantom on the multi-boss roster (user 2026-06-22 "Brutus spawns round 5, shouldn't be any override";
> 2026-07-12 "no early boss spam in dev"). There is no per-boss test opt-in anymore. `acc_glitch_enable` /
> `acc_phantom_enable` (balance kill-switches, default 1) still exist — they gate the real cadence, not a test spawn.

---

## C) Gameplay modifiers (`acc_mod_*`)

Opt-in **rule changes** (the replayability "modifiers" from docs/06). Each is a
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
| `acc_mod_draft_mode` | Every 120s the loop fires, but only logs "offering picks" — the random 3-perk pick UI is an unimplemented TODO stub (no LUI picker yet). (reconciled to code 2026-07-11) |
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
defaults **ON** (set `0` to disable); everything else defaults off. (The per-feature
debug/test dvars that used to sit in this table were removed 2026-07-16 — debug rides
the one `acc_dev` flag; see §E + memory `debug-banners-gated-by-acc-dev-only`.)

| Flag | Default | Effect | Read site |
|---|---|---|---|
| `acc_weapon_variants` | **`1` (on)** | Master enable for the weapon-variant "twin" swap system (Deadshot/Speed Cola/Double Tap/Mega stat swaps). Set `0` to disable all swaps (guns fall back to their base weapon). This is an intended live feature — leave on for normal play. | [`_acc_weapon_variants.gsc:624`](../scripts/zm/zm_abandoned_cyber_city/_acc_weapon_variants.gsc#L624) |
| `acc_ttk_bolt_vis_speed` | `4500` | Triple Take: flight speed (u/s) of the three plasma-orb bolt VISUALS (script movers, `acc_ttk_bolt_fx` clientfield → 1.5× geotrail clones; blue base / red PaP). Damage is HITSCAN and already landed — the orbs are a tracer that sells the volley, so faster = tighter sync with the instant kill, slower = more watchable. (600 was the round-5/6 diagnostic that exposed the hitscan root cause: zombies died before the orb arrived.) Read live per shot. | [`_acc_tripletake.gsc` `bolt_visual`](../scripts/zm/zm_abandoned_cyber_city/_acc_tripletake.gsc) |
| `acc_ttk_spread_deg` | `4.0` | Triple Take volley: degrees each SIDE bolt is offset from the aim line (2026-07-16 projectile rework — a trigger = 3 bolts / 3 rounds: 1 native center + 2 script side bolts). Applied in the VIEW plane (right vector), so steep up/down shots keep true separation. Default was 1.5 for ~an hour: the three bolts visually merged into one (~13u apart at 500u) — the first live test read as "the side bolts aren't firing" (they were; user 2026-07-16 "make it a wider spread"). 4° = a readable fan that clips adjacent zombies; drop toward ~2 for a tighter single-target volley. Read live per shot. | [`_acc_tripletake.gsc` `volley_watcher`](../scripts/zm/zm_abandoned_cyber_city/_acc_tripletake.gsc) |
| `acc_lb_on` | **`1` (on)** | Master enable for the LEADERBOARD (docs/40): end_game recorder (cloud POST — auto-skipped whenever dev **or** god mode is on, user rule 2026-07-11), the Plaza top-10 station, and the dev fetch probe. Set `0` to disable the whole system. The `acc_lb_r1..r10` / `acc_lb_done` / `acc_lb_rec_trace` / `acc_lb_board_trace` / `acc_lb_round_raw` dvars are the LUI→GSC **bridge**, not knobs — never set them by hand. | [`_acc_leaderboard.gsc` `init`](../scripts/zm/zm_abandoned_cyber_city/_acc_leaderboard.gsc) |
| `acc_lb_agent` | `0` | Launcher-integration flag, **passed automatically by the `PLAY_*.bat` scripts / `run_game.ps1`** (never set it yourself): `1` = "the launcher already pre-spawned the hidden leaderboard network agent (`tools/spawn_lb_agent.ps1`)", so the game skips its own agent spawn — the fix for the terminal window that `os.execute` popped at match start (user 2026-07-12, docs/40). Workshop players never have it set and get the game's own minimized spawn. | [`_acc_leaderboard.gsc` `boot_agents`](../scripts/zm/zm_abandoned_cyber_city/_acc_leaderboard.gsc) |
| ~~`acc_boss_item_chance_mini`~~ / ~~`acc_boss_item_chance_full`~~ | *(removed 2026-07-07)* | **Retired — no longer read.** The per-tier boss-item drop-**chance** roll is gone: **every boss kill now drops exactly one item** ([`_acc_boss_items.gsc:382-383` `on_boss_death`](../scripts/zm/zm_abandoned_cyber_city/_acc_boss_items.gsc#L382)). Roster bosses (Phantom / Rogue Protector / Avogadro / Trench Warden) drop via `_acc_boss::grant_unified_boss_reward`; this guaranteed path also covers the retired full-boss slot. The frequent Glitch Stalker is deliberately **NOT** on this path (it would flood items — see `_acc_boss_glitch::glitch_death_watch`, docs/09). | — |
| `acc_boss_score_per_round` | **`180`** | Cash (Points) every player gets per boss kill = `round × this`. **Nerfed −40% (was `300`), user 2026-07-07.** Applies to EVERY boss via the unified reward (r9 → $1,620; r30 → $5,400). Read live per boss kill. | [`_acc_boss.gsc` `grant_unified_boss_reward`](../scripts/zm/zm_abandoned_cyber_city/_acc_boss.gsc) |
| `acc_boss_shards_round_div` | **`3`** | Data Shards every player gets per boss kill = `int( round ÷ this )` (r9 → 3, r30 → 10). Read live per boss kill. | [`_acc_boss.gsc` `grant_unified_boss_reward`](../scripts/zm/zm_abandoned_cyber_city/_acc_boss.gsc) |
| `acc_drop_model_z` | `24` | Z (units) the Data-Shard + Boss-item ground-pickup MODELS are lifted off the floor so they don't sink in (high model pivots). Boss items now carry per-item `model_z` values that OVERRIDE this; it's the fallback (shard drop + anything without a baked value). Read live per drop. | [`_acc_boss_items.gsc` `spawn_pickup`](../scripts/zm/zm_abandoned_cyber_city/_acc_boss_items.gsc) · [`_acc_data_shards.gsc` `spawn_pickup_at`](../scripts/zm/zm_abandoned_cyber_city/_acc_data_shards.gsc) |
| `acc_drop_floor_snap` | `1` | Floor-snap every loot drop origin (boss/zombie item pickups + shard pickups): BulletTrace down 2500u from the drop point, snap **only on a real hit** (`fraction < 1`; a miss keeps the origin — never buries). Kills airborne drops from hovering/jumping enemies. `0` = raw origins. Read live per drop. | [`_acc_boss_items.gsc` `spawn_pickup`](../scripts/zm/zm_abandoned_cyber_city/_acc_boss_items.gsc) · [`_acc_data_shards.gsc` `spawn_pickup_at`](../scripts/zm/zm_abandoned_cyber_city/_acc_data_shards.gsc) |
| `acc_drop_scale_lift_add` | `0` | Additive Z nudge (units, may be negative) applied to the model lift of **up-scaled** item pickups ONLY (`model_scale != 1`: Phase Serum vial / Lucky Horseshoe / Turbocharger carburetor at 4×). SetScale grows the mesh about the model pivot, so the 1×-tuned `model_z` can float at 4× — dial this live until the props seat on the floor, then bake into each `model_z`. Read live per drop. | [`_acc_boss_items.gsc` `spawn_pickup`](../scripts/zm/zm_abandoned_cyber_city/_acc_boss_items.gsc) |
| `acc_bench_off_x` | `153` | X offset (units) of the Plaza Implant Bench from the `player_respawn_point` spawn struct. `153` offsets the two-pad row +153u along X from the spawn (behind the spawns). Read once at `spawn_bench`. | [`_acc_boss_items.gsc` `spawn_bench`](../scripts/zm/zm_abandoned_cyber_city/_acc_boss_items.gsc) |
| `acc_bench_off_y` | `-359` | Y offset (units) of the Plaza Implant Bench from the spawn struct. `-359` pushes the pair SOUTH to ~59u in front of the Plaza south wall (interior face y=-540) so it sits **against the back wall**, out of the open middle (user 2026-06-24). Read once at `spawn_bench`. | [`_acc_boss_items.gsc` `spawn_bench`](../scripts/zm/zm_abandoned_cyber_city/_acc_boss_items.gsc) |
| `acc_gas_dtap_ms` | `350` | Gas Tank: max ms between two **Sprint-button** presses (`SprintButtonPressed`) to count as a double-tap (triggers the nitro burst). Higher = more forgiving. Read live. | [`_acc_boss_items.gsc` `gas_tank_watch`](../scripts/zm/zm_abandoned_cyber_city/_acc_boss_items.gsc) |
| `acc_gas_burst_mult` | `2.0` | Gas Tank: nitro-burst move-speed multiplier (**+100%**, i.e. double speed) applied for the 5 s burst. Read live (rides `recompute_move_speed`). | [`_acc_utility.gsc` `recompute_move_speed`](../scripts/zm/zm_abandoned_cyber_city/_acc_utility.gsc) |
| `acc_gas_regen_sec` | `60` | Gas Tank: cooldown/regen seconds after the 5 s burst — you can't re-fire until full. Also the NITRO-bar refill time (the bar reads the same dvar). Read live. | [`_acc_boss_items.gsc` `gas_tank_burst`](../scripts/zm/zm_abandoned_cyber_city/_acc_boss_items.gsc) |
| `acc_rocket_slide_mult` | `2.0` | Rocket Shield: move-speed multiplier while sliding (**+100%**; 2026-07-15 rework, was 1.75). Read live (rides `recompute_move_speed`). | [`_acc_utility.gsc` `recompute_move_speed`](../scripts/zm/zm_abandoned_cyber_city/_acc_utility.gsc) |
| `acc_rocket_slide_kick` | `250` | Rocket Shield: forward velocity impulse applied on slide-start ("slide carries you farther"; 2026-07-15 rework, was 200). Slide is detected via `IsSliding()`. | [`_acc_boss_items.gsc` `rocket_shield_watch`](../scripts/zm/zm_abandoned_cyber_city/_acc_boss_items.gsc) |
| `acc_rocket_jump_mult` | `1.42` | Rocket Shield: jump upward-velocity **multiply** → ~**2× apex height** (height ∝ velocity², so ×1.42 ≈ double). Per-player; never touches the global `jump_height` dvar. (`acc_rocket_slide_thresh`/`acc_rocket_jump_kick` are retired — slide now uses `IsSliding()`, jump is a multiply.) | [`_acc_boss_items.gsc` `rocket_shield_watch`](../scripts/zm/zm_abandoned_cyber_city/_acc_boss_items.gsc) |
| `acc_rocket_shield_hp` | `750` | Rocket Shield: EFFECTIVE riot-shield hit points (user 2026-07-15). The real pool is the `zod_riotshield` weapon def's GDT-baked `weaponstarthitpoints` (1850, engine `DamageRiotShield`, NO runtime setter) — `acc_shield_damage` scales every BLOCKED hit up by `1850 / this` before the stock damage fn, so the HUD bar stays linear and empties after exactly this much real damage. Shield-BASH self-costs stay stock-priced (they bypass the hook). Read live per hit. | [`_acc_boss_items.gsc` `acc_shield_damage`](../scripts/zm/zm_abandoned_cyber_city/_acc_boss_items.gsc) |
| `acc_rocket_shield_regrant_sec` | `60` | Rocket Shield: delay (s) before a zombie-DESTROYED riot shield (`zod_riotshield`) is regranted to the implant holder (user 2026-07-15: 1 min, was 30 s). Respawn regrants are immediate (`spawned_player` + 0.1 s). Read live per destroy. | [`_acc_boss_items.gsc` `riot_shield_regrant_on_destroy`](../scripts/zm/zm_abandoned_cyber_city/_acc_boss_items.gsc) |
| `acc_hive_radius` | `300` | Hive Node (item 14): radius (units) of BOTH the passive support aura AND the active Bloom burst — a player must be within this of the carrier to be healed / shielded / revived, and a killer must be within it for a covered-teammate commission. Read live per tick / burst. | [`_acc_boss_items.gsc` `hive_aura_loop`](../scripts/zm/zm_abandoned_cyber_city/_acc_boss_items.gsc) |
| `acc_hive_regen` | `15` | Hive Node: passive aura HP/sec regen granted to every player in range (the carrier included). Repair Kit is 10 and self-only. Read live per 0.25 s tick. | [`_acc_boss_items.gsc` `hive_aura_loop`](../scripts/zm/zm_abandoned_cyber_city/_acc_boss_items.gsc) |
| `acc_hive_dr` | `0.15` | Hive Node: passive aura **damage reduction** (0..1) for every player in range (−15%). Applied after Exo + Savior (multiplicative), floored at 1. Read live per hit. | [`_acc_elites.gsc` `apply_player_mitigations`](../scripts/zm/zm_abandoned_cyber_city/_acc_elites.gsc) |
| `acc_hive_bubble_dr` | `0.50` | Hive Node: active **Bloom-burst** damage reduction (0..1, −50%) for everyone caught in the burst, for `acc_hive_bubble_sec`. Stacks on the aura DR (both multiplicative). Read live per hit. | [`_acc_elites.gsc` `apply_player_mitigations`](../scripts/zm/zm_abandoned_cyber_city/_acc_elites.gsc) |
| `acc_hive_bubble_sec` | `5` | Hive Node: duration (s) of the Bloom-burst shield. Read live per burst. | [`_acc_boss_items.gsc` `hive_bloom_burst`](../scripts/zm/zm_abandoned_cyber_city/_acc_boss_items.gsc) |
| `acc_hive_cd` | `60` | Hive Node: cooldown (s) after a Bloom burst before it can re-fire. Read live per burst. | [`_acc_boss_items.gsc` `hive_bloom_burst`](../scripts/zm/zm_abandoned_cyber_city/_acc_boss_items.gsc) |
| `acc_hive_dtap_ms` | `350` | Hive Node: max ms between two **Jump-button** presses (`JumpButtonPressed`) to count as a double-tap (fires the Bloom burst). Distinct input from Gas Tank's Sprint double-tap. Read live. | [`_acc_boss_items.gsc` `hive_watch`](../scripts/zm/zm_abandoned_cyber_city/_acc_boss_items.gsc) |
| `acc_hive_commission` | `10` | Hive Node (reward-the-medic): points paid to each in-aura carrier when a **covered teammate** gets a kill. `0` = off. Read live per kill (2nd `register_zombie_death_event_callback`). | [`_acc_boss_items.gsc` `hive_on_kill`](../scripts/zm/zm_abandoned_cyber_city/_acc_boss_items.gsc) |
| `acc_hive_revive_shards` | `2` | Hive Node: Data Shards paid to the carrier per teammate the Bloom **revives**. Read live per burst. | [`_acc_boss_items.gsc` `hive_bloom_burst`](../scripts/zm/zm_abandoned_cyber_city/_acc_boss_items.gsc) |
| `acc_hive_revive_pts` | `250` | Hive Node: points paid to the carrier per teammate the Bloom **revives**. Read live per burst. | [`_acc_boss_items.gsc` `hive_bloom_burst`](../scripts/zm/zm_abandoned_cyber_city/_acc_boss_items.gsc) |
| `acc_hive_heal_pts` | `50` | Hive Node: points paid to the carrier per living teammate the Bloom **heals**. Read live per burst. | [`_acc_boss_items.gsc` `hive_bloom_burst`](../scripts/zm/zm_abandoned_cyber_city/_acc_boss_items.gsc) |
| `acc_trench_aggro` | **`1` (on)** | Trench per-layer scaling master gate. A zombie **physically standing in a trench layer** (`acc_bus_trench::underground_layer` > 0 — gated on the **zombie's own** position, not its target) moves faster, hits harder, and is tankier, scaling by layer. Set `0` to disable. Re-asserted each 1.5 s keepalive sweep. **No forced sprint, no beeline** (removed 2026-06-21). | [`_acc_zombie_speed.gsc` `trench_layer_for_zombie`](../scripts/zm/zm_abandoned_cyber_city/_acc_zombie_speed.gsc) |
| `acc_trench_layer_speed_pct` | `3` | Trench: **move-speed bump per layer** (anim-rate ×`(1 + layer·pct/100)`). Layer 1 = +3%, layer 2 = +6%, … L5 = +15% (was 4 → 3.5, user 2026-07-16). Stacks on top of the round gait/rate; always ≥ 1.0 (no slow-mo). | [`_acc_zombie_speed.gsc` `apply_speed_for_round`](../scripts/zm/zm_abandoned_cyber_city/_acc_zombie_speed.gsc) |
| `acc_trench_layer_hp_pct` | `25` | Trench: **max-health bump per layer (%)**, **stacks on top of** the round + co-op HP — final HP = (round curve × player-count mult) × `(1 + layer × this%)`. L1 = +25%, L5 = +125% (nerf 30 → 27 → 25, user 2026-07-16). Applied **one-way by the deepest layer reached** (added as armor on descent; never re-healed, so it can't be exploited by the keepalive). So both proper player-count scaling AND trench difficulty apply (user 2026-07-04). | [`_acc_zombie_speed.gsc` `apply_trench_health`](../scripts/zm/zm_abandoned_cyber_city/_acc_zombie_speed.gsc) |
| `acc_trench_layer_dmg_add` | `4` | Trench: **flat melee bonus per layer (HP)** — a zombie melee hit you take in layer L adds `L × this` HP. L1 = +4 (≈49/hit), L2 = +8 (≈53), … L5 = +20 (≈65) (was 6 → 5, user 2026-07-16). Added to the **player's incoming damage** (open-field melee ignores `self.meleeDamage`, so this is the only reliable lever). | [`_acc_bus_trench.gsc` `trench_melee_scaled`](../scripts/zm/zm_abandoned_cyber_city/_acc_bus_trench.gsc) |
| `acc_trench_aggro_melee` | **`1` (on)** | Trench: enable the per-layer **incoming-melee** bump. `0` = unscaled melee everywhere (the per-layer move bump still applies). | [`_acc_bus_trench.gsc` `trench_melee_scaled`](../scripts/zm/zm_abandoned_cyber_city/_acc_bus_trench.gsc) |
| `acc_zombie_melee_base` | `45` | **Baseline** regular-zombie melee damage (HP), re-asserted every speed sweep on non-boss zombies (down from stock `60`; bosses keep their own). NOTE: `self.meleeDamage` is only read by the **window-board** melee path; **open-field** melee uses the engine weapon, so the trench bump scales the player's incoming damage instead (above). | [`_acc_zombie_speed.gsc` `apply_baseline_melee`](../scripts/zm/zm_abandoned_cyber_city/_acc_zombie_speed.gsc) |
| `acc_trench_warn` | **`1` (on)** | Trench: show the **danger warning** while a player is exposed in the pit — a pulsing red banner ("DANGER — EXPOSED IN THE TRENCH", upper-center) + a subtle pulsing red screen tint. `0` = no warning. Created lazily per player, hidden on exit. | [`_acc_bus_trench.gsc` `trench_warning_on`](../scripts/zm/zm_abandoned_cyber_city/_acc_bus_trench.gsc) |
| `acc_trench_zombie_points` | `30` | Trench: **flat kill payout** for a surge/drip-spawned trench zombie (tagged `acc_trench_zombie`). These are a THREAT, not a payout — no damage-share split, headshot/knife bonus, or Kinetic Battery accrual, and they're excluded from the round count. Set `0` for no payout. (user 2026-06-24: 10 → 20; user 2026-06-26: 20 → 30.) | [`_acc_points.gsc` `on_zombie_death`](../scripts/zm/zm_abandoned_cyber_city/_acc_points.gsc) |
| `acc_trench_income` | **`1` (on)** | Trench: **passive Data Shard income** master gate (user 2026-06-26 "reward players for staying in the trenches"). While a player STANDS in a trench layer they earn `acc_trench_income_amount` shard(s) every N seconds (N per layer below). Per-player; the timer resets the instant they leave the trench (it does NOT count on the surface or in Paradise — both are layer 0). Cap-clamped by the shard cap. `0` = no passive income. | [`_acc_bus_trench.gsc` `trench_shard_income`](../scripts/zm/zm_abandoned_cyber_city/_acc_bus_trench.gsc) |
| `acc_trench_income_amount` | `1` | Trench: shards granted per passive income tick. | [`_acc_bus_trench.gsc` `trench_shard_income`](../scripts/zm/zm_abandoned_cyber_city/_acc_bus_trench.gsc) |
| `acc_trench_income_l1` … `_l5` | `45` / `31` / `20` / `12` / `7` | Trench: **seconds between passive shard grants per layer** — L1 (Bus Station pit) 45s, L2 31s, L3 20s, L4 12s, L5 7s. Deeper = faster (more reward for the greater risk). The clock carries across layer changes (paid at the **current** layer's rate), so descending never loses progress. Set a layer's value to `0` to disable income on that layer. | [`_acc_bus_trench.gsc` `trench_income_interval`](../scripts/zm/zm_abandoned_cyber_city/_acc_bus_trench.gsc) |
| `acc_oob_grace_ms` | **`12000`** | **OOB-kill grace** (co-op "instant reset while reviving in the Lab" fix, user 2026-07-11). The stock `player_out_of_playable_area_monitor` (`_zm.gsc:2035+`) instant-kills — `DisableInvulnerability; lives=0; DoDamage(health+1000); bleedout_time=0` = **instant** bleed-out → our Comeback respawn (start pistol + money SET to 500×round) — any player its **~3s poll** finds outside every enabled `player_volume`. A revive PINS you stationary next to the downed body, so if the body fell in a zone-coverage gap the poll catches the reviver. This is the ms a player must be **continuously** outside the volumes before the kill is allowed: a reviver is OOB for ~one poll and is spared; a genuinely escaped/noclipped player stays OOB for many polls and is still culled. `0` = kill on first detection (stock behavior). | [`_acc_bus_trench.gsc` `acc_trench_oob_allow`](../scripts/zm/zm_abandoned_cyber_city/_acc_bus_trench.gsc) |
| `acc_zspeed_sprint_round` | `15` | First round zombies use the full **sprint** gait. Rounds before this use the **run** gait (a jog). This is the "they break into a sprint" round. (user 2026-06-23: 10 → 15 → 17; **user 2026-07-09: back to 15 — the whole speed curve shifted 2 rounds earlier**, zombies slightly faster at every round.) Read **live per spawn**. | [`_acc_zombie_speed.gsc` `tier_for_round`](../scripts/zm/zm_abandoned_cyber_city/_acc_zombie_speed.gsc) |
| `acc_zspeed_jog_start_pct` | `101.3` | Round-1 jog playback rate, as % (`100` = the run anim's **natural** cadence/speed; the `101.3` default = the old curve's round-3 value, completing the 2026-07-09 2-round shift). Read as a **float**. Floored at 100 in code — the wave never animates below natural cadence (anything lower would look like slow-motion). | [`_acc_zombie_speed.gsc` `rate_for_round`](../scripts/zm/zm_abandoned_cyber_city/_acc_zombie_speed.gsc) |
| `acc_zspeed_jog_step_pct` | `0.65` | Added jog playback % per round during the jog phase (rounds 1 → `sprint_round`−1). Higher = the jog ramps up faster. Read as a **float**. | [`_acc_zombie_speed.gsc` `rate_for_round`](../scripts/zm/zm_abandoned_cyber_city/_acc_zombie_speed.gsc) |
| `acc_zspeed_sprint_start_pct` | `100` | Sprint playback rate at `sprint_round`, as % (`100` = natural full sprint = base-game max). | [`_acc_zombie_speed.gsc` `rate_for_round`](../scripts/zm/zm_abandoned_cyber_city/_acc_zombie_speed.gsc) |
| `acc_zspeed_sprint_step_pct` | `0.5` | Added sprint playback % per round **after** `sprint_round` (the "+0.5%/round" creep — cut from `1` by user 2026-06-24 for a gentler post-sprint ramp; rate > 1.0 = a faster sprint, no slow-mo, no upper clamp). Read as a **float** (fractional %), so a value like `0.6` is honoured (an int read would truncate it to `0`). | [`_acc_zombie_speed.gsc` `rate_for_round`](../scripts/zm/zm_abandoned_cyber_city/_acc_zombie_speed.gsc) |
| `acc_fog_on` | `1` | `1` enables global volumetric fog (cold city haze); polled every 0.5s so it can be toggled live. | [`_acc_atmosphere.gsc:69`](../scripts/zm/zm_abandoned_cyber_city/_acc_atmosphere.gsc#L69) |
| `acc_warden_first_round` | **`5`** | Earliest round the FIRST Trench Warden (Brutus) can appear — he also needs Bus Station power on; if power comes on earlier he holds until this round. Respawns are kill-anchored (naturally later). | [`_acc_boss.gsc` `brutus_power_watch`](../scripts/zm/zm_abandoned_cyber_city/_acc_boss.gsc) |
| `acc_brutus_respawn_interval` | **`3`** | Rounds AFTER a Trench Warden **kill** that the next one spawns — kill-anchored (not a fixed round grid), only one alive at a time. | [`_acc_boss.gsc` `round_hook_loop`](../scripts/zm/zm_abandoned_cyber_city/_acc_boss.gsc) |
| `acc_warden_trench` | **`1` (on)** | `1` spawns Brutus **in the trench** (relocates his spawn points onto the pit floor so the whole rise happens in the pit); `0` = pack-native lab spawn. | [`_acc_boss_brutus.gsc`](../scripts/zm/zm_abandoned_cyber_city/_acc_boss_brutus.gsc) |
| `acc_warden_patrol_reach` | **`96`** | Distance (units) at which the Warden counts a trench patrol point as "reached" and picks a new one. | [`_acc_boss_brutus.gsc` `warden_patrol_step`](../scripts/zm/zm_abandoned_cyber_city/_acc_boss_brutus.gsc) |
| `acc_warden_patrol_dwell` | **`2.5`** | Seconds the Warden dwells at a patrol point before moving on. Read as a **float**. | [`_acc_boss_brutus.gsc` `warden_patrol_step`](../scripts/zm/zm_abandoned_cyber_city/_acc_boss_brutus.gsc) |
| `acc_warden_melee_damage` | **`85`** | Trench Warden (Brutus) scripted swing damage to a player (user 2026-07-12: 75 → 85). | [`_NSZ/nsz_brutus.gsc` `note_tracker`](../scripts/_NSZ/nsz_brutus.gsc) |
| `acc_warden_anim_rate` | **`1.03`** | Trench Warden (Brutus) ground-speed multiplier (**+3%**, user 2026-07-12) applied via a **bare `ASMSetAnimationRate`**; `≤0` disables. Read as a **float**. Safe because he's flagged `acc_boss_custom_speed`, so the global `_acc_zombie_speed` keep-alive skips him (no writer fight) — the same lever the Panzer uses, not the `SetScale` / run-cycle-override that historically froze him. | [`_acc_boss_brutus.gsc` `warden_speed_think`](../scripts/zm/zm_abandoned_cyber_city/_acc_boss_brutus.gsc) |
| `acc_boss_mini_hp` | **`65000`** | Brutus (Trench Warden) **base** solo HP — SHARED with the Phantom/Rogue/Avogadro (unified boss scale, user 2026-07-04; base 56000 → 65000 user 2026-07-05). The round-scaled value is then × the logarithmic co-op multiplier. Read at each Brutus spawn. | [`_acc_boss.gsc` `scale_mini_boss_hp`](../scripts/zm/zm_abandoned_cyber_city/_acc_boss.gsc) |
| `acc_boss_mini_hp_exp` | **`1.12`** | Brutus HP **compounding exponent per round** past the anchor — base × 1.12^(round−anchor) (user 2026-07-08: 1.12 → 1.13 → 1.14 → 1.12 after the anchor moved to r5, the TANKIEST tier tied with the Panzer: Brutus/Panzer 1.12 > Rogue 1.09 > Phantom 1.06). Solo (anchor 5) r5 65k → r10 115k → r20 356k → r30 1.11M → r40 3.43M. **No cap.** Read as a **float**; `1.0` = flat (no round scaling). | [`_acc_boss.gsc` `scale_mini_boss_hp`](../scripts/zm/zm_abandoned_cyber_city/_acc_boss.gsc) |
| `acc_boss_mini_hp_anchor` | **`5`** | The round at which Brutus HP equals the base **and compounding starts** (user 2026-07-08: 10 → 5, "all boss scaling starts on round 5"; matches `acc_phantom_hp_anchor`). He debuts at round ≥ 5 on power-on, so his first appearance is exactly the base and every round after compounds. | [`_acc_boss.gsc` `scale_mini_boss_hp`](../scripts/zm/zm_abandoned_cyber_city/_acc_boss.gsc) |
| `acc_fury_dmg_mult` | **`2.0`** | Apothicon Fury bamf-land melee-damage multiplier — base 25 × this (user 2026-07-12 = **2× = 50**; the only Fury player-damage site). Read as a **float**. | [`archetype_apothicon_fury.gsc` `apothiconBamfLand`](../scripts/shared/ai/archetype_apothicon_fury.gsc) |
| `acc_panzer_flame_mult` | **`1.21`** | Panzer flamethrower per-tick burn multiplier (**+10%**, user 2026-07-12: 1.0 → 1.1; **+10% again in the 2026-07-18 all-Panzer damage pass → 1.21** — per-tick 36, 24 with Jugg). The same-day "+20%" / `1.2` experiment was reverted to `1.0` on 2026-07-11, then re-buffed to `1.1`. Read as a **float**. | [`mechz_spiki.gsc` `acc_player_flame_damage`](../scripts/zm/mechz_spiki.gsc) |
| `acc_panzer_explosive_mult` | **`1.1`** | Panzer **electroball explosion** damage-to-player multiplier (user 2026-07-18 +10% all-Panzer damage) — the 115-grenade blast damage is engine/GDT-side, so the buff is applied in the player-damage callback (attacker `acc_is_panzer` + a GRENADE MoD). | [`_acc_elites.gsc` `on_player_damaged`](../scripts/zm/zm_abandoned_cyber_city/_acc_elites.gsc) |
| `acc_panzer_zap_radius` | **`220`** | Panzer electroball blast/zap RADIUS in units (**+10%**, user 2026-07-12: 200 → 220). NOTE: the scripted layer only applies the shared boss zap **slow** inside this radius; the electroball's literal explosion **damage** is the engine 115-grenade detonation (mechz grenade GDT, install-side, not repo code), so this dvar tunes the blast **radius**, not the damage. Read as a **float**. | [`_acc_boss_panzer.gsc` `electroball_impact`](../scripts/zm/zm_abandoned_cyber_city/_acc_boss_panzer.gsc) |
| `acc_protector_mahem_dmg` | **`69`** | Rogue Protector "Mahem" rocket damage to a player (**+25%**, user 2026-07-12: 55 → 69) — used BOTH as the real-rocket player-damage CAP (`_acc_elites.gsc`) and the scripted fallback `RadiusDamage` (`_acc_civil_protector.gsc`). | [`_acc_elites.gsc`](../scripts/zm/zm_abandoned_cyber_city/_acc_elites.gsc) / [`_acc_civil_protector.gsc`](../scripts/zm/zm_abandoned_cyber_city/_acc_civil_protector.gsc) |
| `acc_pap_tier_anim` | **`1` (on)** | Each PaP **tier-up** replays the first-pack in-hand "gun comes out" draw (re-equips the held weapon, carrying ammo). Set `0` to revert to instant, animation-free tier-ups. Read per tier-up. | [`_acc_pap_levels.gsc` `replay_pack_draw`](../scripts/zm/zm_abandoned_cyber_city/_acc_pap_levels.gsc) |
| `acc_corpse_linger_sec` | **`0`** | Seconds a zombie corpse stays VISIBLE on the ground before we hide it (`Ghost`). The body is de-collided (`NotSolid`) IMMEDIATELY on death so it never blocks movement/pathing. Set `0` for instant removal (the pre-2026-06-15 behavior). Under a heavy horde the engine's corpse cap may recycle a body sooner — this is an upper bound, not a guarantee. Read per zombie death (bosses skipped). | [`_acc_corpse_cleanup.gsc`](../scripts/zm/zm_abandoned_cyber_city/_acc_corpse_cleanup.gsc) |
| `acc_global_dmg_mult` | **`3.25`** (+225%) | **GLOBAL "buff all guns" knob** (code default is now `3.25`; user 2026-06-25 bumped `2.50` → `3.0` → `2.75`, user 2026-06-29 → `3.25`). A single across-the-board scalar applied as a flat FINAL multiply on **all PLAYER damage** in `on_ai_damage` (body, headshot, melee, explosive). Sits OUTSIDE the bonus-sum/reduction buckets, so it lifts every gun uniformly while **preserving** the per-gun tiers in `acc_weapon_balance_mult`. `1.0` = off. NOTE: this ×3.25 compounds the boss-nuke problem for multi-hit specials (see the two boss-cut dvars below). | [`_acc_damage.gsc` `on_ai_damage`](../scripts/zm/zm_abandoned_cyber_city/_acc_damage.gsc) |
| `acc_shotgun_boss_mult` | **`0.25`** | Pellet-shotgun (Tac-19 / Olympia) damage multiplier **vs bosses/mini-bosses only**. Their 8 pellets all land on one boss hitbox → ~8× nuke; this cut keeps chaff power but stops the boss nuke. | [`_acc_damage.gsc` `on_ai_damage` 0b](../scripts/zm/zm_abandoned_cyber_city/_acc_damage.gsc) |
| `acc_thundergun_boss_mult` | **`0.20`** | Thundergun damage **vs bosses/mini-bosses only** (boss-nuke audit, user 2026-06-24). Its wind-blast cone multi-traces one boss hitbox → ~200k; this surgical cut (on top of its 0.70 balance mult) brings a blast to ~28k vs a boss while leaving its chaff/clear power on regular zombies. `1.0` = no boss cut. | [`_acc_damage.gsc` `boss_nuke_mult`](../scripts/zm/zm_abandoned_cyber_city/_acc_damage.gsc) |
| `acc_launcher_boss_mult` | **`0.50`** | Mahem launcher damage **vs bosses/mini-bosses only** (boss-nuke audit, user 2026-06-24). Direct + splash both hit one boss hitbox; gentler cut than the Thundergun because the launcher is ammo-limited. On top of its 0.29 balance mult → ~3,300/rocket + splash vs a boss. `1.0` = no boss cut. | [`_acc_damage.gsc` `boss_nuke_mult`](../scripts/zm/zm_abandoned_cyber_city/_acc_damage.gsc) |
| `acc_paladin_boss_mult` | **`0.50`** | Paladin HB50 sniper damage **vs bosses/mini-bosses only** (user 2026-06-24). A single-shot boss-killer (not a multi-hit nuke), reined in vs bosses on request; on top of its 0.49 balance mult (B tier). NOTE: the Paladin's niche is single-target boss DPS — raise toward `1.0` if it feels too weak vs bosses. | [`_acc_damage.gsc` `boss_nuke_mult`](../scripts/zm/zm_abandoned_cyber_city/_acc_damage.gsc) |
| `acc_explosive_boss_mult` | **`1.5`** (+50%) | **Explosive-vs-boss AMPLIFIER** (user 2026-07-16) — the one boss dvar that goes **up**, not down. A true multiplicative ×1.5 on **explosive** damage **vs bosses/mini-bosses only** (reduction bucket, block 0c4). "Explosive" is the same gate as Warhead Bomber (`is_explosive_mod` = grenades / launcher / projectile / splash, **minus** energy weapons and the three unbuffed wonders): frags, Monkey Bomb, Li'l Arnie, the Mahem, the War Machine. **Stacks on** the launcher boss-cut, so a Mahem/War Machine rocket nets `0.50 × 1.5 = 0.75` of its uncut boss damage; thrown grenades get the full ×1.5. Still clamped by `acc_boss_per_hit_cap_pct` (4d) — never a one-shot. `1.0` = off. | [`_acc_damage.gsc` `on_ai_damage` 0c4](../scripts/zm/zm_abandoned_cyber_city/_acc_damage.gsc) |
| `acc_boss_per_hit_cap_pct` | **`0.10`** | **Boss-damage HARD CAP** (catch-all backstop, boss-nuke audit 2026-06-24). A single PLAYER hit on a heavyweight boss (anything carrying `acc_is_boss`/`acc_is_mini_boss` — Brutus/Trench Warden, Phantom, Rogue Protector, Avogadro, Panzer — **not** the Glitch Stalker) deals at most this fraction of the boss's maxhealth, clamped **after every multiplier** (global ×3.25 + insta-kill ×2). `0.10` → ≥10 hits to kill any boss regardless of weapon/weaponless-DoDamage/insta-kill/investment. The only thing that stops the stock Thundergun fling (`DoDamage(self.health+666)`, weaponless → invisible to the name-keyed cuts) one-shotting bosses. Raise (e.g. `0.15`) if bosses feel too tanky, lower (`0.05`) for tankier, `0` = off (uncapped). | [`_acc_damage.gsc` `on_ai_damage` 4d](../scripts/zm/zm_abandoned_cyber_city/_acc_damage.gsc) |
| `acc_cache_w_count` / `acc_cache_e_count` | **`3`** each | Base shards each pit Data Cache pays per round (west / east). (user 2026-06-23: 1 → 2; user 2026-06-25: 2 → 3, faster faucet.) Final yield = this + round/`acc_cache_scale_rounds` (scaling effectively off), capped at `acc_cache_yield_max` (9). | [`_acc_glitch_altar.gsc`](../scripts/zm/zm_abandoned_cyber_city/_acc_glitch_altar.gsc) / [`_acc_data_shards.gsc` `cache_yield`](../scripts/zm/zm_abandoned_cyber_city/_acc_data_shards.gsc) |
| `acc_cache_one_per_player` | **`1` (on)** | **CO-OP anti-hog** (user 2026-06-25; **per-group split** user 2026-07-11): a player who loots a Data Cache this round **can't loot another from the same GROUP** ("plaza" = the 4 plaza crates, "trench" = the 2 pit caches) — but CAN still grab one from the *other* group (one plaza + one trench per round is allowed). Per-player per-group round-number gate (self-healing). **SOLO is exempt** (1 player → the extra caches would otherwise be unlootable/wasted). `0` = disable (first-come per cache again). | [`_acc_data_shards.gsc` `cache_loop`](../scripts/zm/zm_abandoned_cyber_city/_acc_data_shards.gsc) |
| `acc_mww_crouch_speed` | **`2.6`** | **Mega Widow's Wine** low-stance mobility (user 2026-06-25; crouch 2.2→2.4→**2.6** user 2026-06-26): a Mega-Widow's holder's **crouch** move speed × this vs the normal crouch baseline (so N× faster than another crouched player). Read as a **float**. | [`_acc_mega_bottles.gsc` `mww_stance_factor`](../scripts/zm/zm_abandoned_cyber_city/_acc_mega_bottles.gsc) |
| `acc_mww_prone_speed` | **`10.0`** | Mega Widow's: **prone** speed × this vs the normal prone baseline. Float. | [`_acc_mega_bottles.gsc` `mww_stance_factor`](../scripts/zm/zm_abandoned_cyber_city/_acc_mega_bottles.gsc) |
| `acc_mww_down_speed` | **`15.0`** | Mega Widow's: **last-stand (downed crawl)** speed × this. Float. **NOTE:** depends on the engine applying the move scale to the laststand crawl — verify in-game (crouch/prone are unaffected by this caveat). | [`_acc_mega_bottles.gsc` `mww_stance_factor`](../scripts/zm/zm_abandoned_cyber_city/_acc_mega_bottles.gsc) |
| `acc_mww_speed_cap` | **`16.0`** | Safety clamp on the final move scale **after** the Mega Widow's stance multiplier (bounds a pathological item × stance stack). Must stay ≥ `acc_mww_down_speed` for the down rate to land. | [`_acc_utility.gsc` `recompute_move_speed`](../scripts/zm/zm_abandoned_cyber_city/_acc_utility.gsc) |
| `acc_soul_fx` | **`1` (on)** | **Soul light** (user 2026-06-25): a glowing orb that flies from each soul-banking kill into the abyss soul box. `0` = no orb (the soul still banks + the departure SFX still plays). | [`_acc_abyss_doors.gsc` `spawn_soul_light`](../scripts/zm/zm_abandoned_cyber_city/_acc_abyss_doors.gsc) |
| `acc_soul_glow_index` | **`6`** | Soul orb colour, an `accPerkGlow` palette index (6 = blue; 8 white, 9 purple, 10 teal — see `_acc_perk_lights`). | [`_acc_abyss_doors.gsc` `spawn_soul_light`](../scripts/zm/zm_abandoned_cyber_city/_acc_abyss_doors.gsc) |
| `acc_soul_travel_time` | **`0.8`** | Seconds for a soul orb to fly from the kill spot to the box (read as a **float**). | [`_acc_abyss_doors.gsc` `spawn_soul_light`](../scripts/zm/zm_abandoned_cyber_city/_acc_abyss_doors.gsc) |
| `acc_soul_fx_max` | **`14`** | Max concurrent soul orbs — caps a mass-wipe (nuke) FX swarm; over the cap the soul still banks, only the visual is skipped. | [`_acc_abyss_doors.gsc` `spawn_soul_light`](../scripts/zm/zm_abandoned_cyber_city/_acc_abyss_doors.gsc) |
| `acc_soul_arrive_sfx` | **`1` (on)** | Play the `acc_soul_steal` cue again as the orb reaches the box (the "soul enters" pop). `0` = departure SFX only. | [`_acc_abyss_doors.gsc` `spawn_soul_light`](../scripts/zm/zm_abandoned_cyber_city/_acc_abyss_doors.gsc) |
| `acc_reactor_cooldown` | **`3`** | **Reactor Surge** (trench-pit climax): rounds before the plinth re-arms after an activation (user 2026-06-24). Replaces the old buggy once-per-round flag with a **self-healing round-number gate** (reads `level.round_number` live + a busy-watchdog), so it can never lock for the game. `1` = usable every round. | [`_acc_reactor.gsc` `reactor_available`](../scripts/zm/zm_abandoned_cyber_city/_acc_reactor.gsc) |
| `acc_reactor_wave_count` | **`13`** | Reactor Surge: regular zombies spawned **per wave** (user 2026-06-24: `6` → `10` → `13`, more aggressive). Capped in practice by the AI limit. | [`_acc_reactor.gsc` `run_surge`](../scripts/zm/zm_abandoned_cyber_city/_acc_reactor.gsc) |
| `acc_reactor_shielded_per_wave` | **`3`** | Reactor Surge: **Shielded ("Riot") elites** erupted from the pit risers **per wave** (user 2026-06-24). Each is 4× HP + front armor; flagged **no-shard** (gives no Data Shards on kill — a threat, not a farm, same as the glitch purge). `0` = none. | [`_acc_reactor.gsc` `reactor_spawn_specials`](../scripts/zm/zm_abandoned_cyber_city/_acc_reactor.gsc) |
| `acc_reactor_glitch_per_wave` | **`1`** | Reactor Surge: **Glitch Stalkers** spawned **per wave** (user 2026-06-24). Full blinking mini-boss; flagged **no-shard** (gives no Data Shards on kill). `0` = none. | [`_acc_reactor.gsc` `reactor_spawn_specials`](../scripts/zm/zm_abandoned_cyber_city/_acc_reactor.gsc) |
| `acc_reactor_wave_interval` | **`2.1`** | Reactor Surge: seconds **between waves** (user 2026-06-24: `6.0` → `3.0` → `2.1`, spawn quicker). Read as a **float**. | [`_acc_reactor.gsc` `run_surge`](../scripts/zm/zm_abandoned_cyber_city/_acc_reactor.gsc) |
| `acc_reactor_waves` | **`5`** | Reactor Surge: number of waves per activation. | [`_acc_reactor.gsc` `run_surge`](../scripts/zm/zm_abandoned_cyber_city/_acc_reactor.gsc) |
| `acc_reactor_reward` | **`5`** | Reactor Surge: Data Shards granted to **every** player on a successful survive (user 2026-06-24: `3` → `5`; also drops a shared **Fire Sale** — user 2026-06-27, was an Insta-Kill — **plus 1 random boss-pool Implant** as a free-for-all world drop at the armer, user 2026-07-16, via `acc_boss_items::grant_challenge_reward`). | [`_acc_reactor.gsc` `reactor_reward`](../scripts/zm/zm_abandoned_cyber_city/_acc_reactor.gsc) |
| `acc_reactor_on` | **`1` (on)** | Master gate for the whole Reactor Surge feature. `0` = no plinth. | [`_acc_reactor.gsc` `spawn_reactor`](../scripts/zm/zm_abandoned_cyber_city/_acc_reactor.gsc) |
| `acc_vault_points_inc` | **`1000`** | **The Exchange** (transfer vault, [docs/37](37_transfer_vault.md)): Points moved per deposit/withdraw press. 1000 → the 10% tax is exactly **100**. | [`_acc_transfer.gsc` `deposit_points`](../scripts/zm/zm_abandoned_cyber_city/_acc_transfer.gsc) |
| `acc_vault_shards_inc` | **`10`** | The Exchange: **Data Shards** moved per press (10 → 10% tax is exactly **1**; withdraw clamps to the recipient's 500 cap). | [`_acc_transfer.gsc` `deposit_shards`](../scripts/zm/zm_abandoned_cyber_city/_acc_transfer.gsc) |
| `acc_vault_items_max` | **`8`** | The Exchange: max **Boss Items** the shared locker holds (deposit refused when full). | [`_acc_transfer.gsc` `deposit_item`](../scripts/zm/zm_abandoned_cyber_city/_acc_transfer.gsc) |
| `acc_vault_tax_pct` | **`10`** | The Exchange: **deposit tax** on Points + Data Shards (the house cut — the pool receives ~90% of a deposit, the rest is destroyed). `0` = free 1:1. **Mega Bottles + Boss Items are never taxed.** | [`_acc_transfer.gsc` `after_tax`](../scripts/zm/zm_abandoned_cyber_city/_acc_transfer.gsc) |
| `acc_ammo_crate_base` | **`2000`** | **Trench ammo crate** (abyss L2, opposite the Overclock terminal, user 2026-06-27): points to refill a **base** (un-Pack-a-Punched) held weapon's reserve. | [`_acc_ammo_crate.gsc` `crate_cost`](../scripts/zm/zm_abandoned_cyber_city/_acc_ammo_crate.gsc) |
| `acc_ammo_crate_pap` | **`10000`** | Trench ammo crate: points to refill a **Pack-a-Punched** held weapon. A weapon with **no PaP version** (melee/equipment/no-pack specials) can't use the crate at all (charges nothing). | [`_acc_ammo_crate.gsc` `crate_cost`](../scripts/zm/zm_abandoned_cyber_city/_acc_ammo_crate.gsc) |
| `acc_ammo_crate_wonder` | **`20000`** | Trench ammo crate: **flat** refill price for a **WONDER-tier** held weapon (same list as the WONDER PaP tier, `_acc_pap_levels::pap_price_bucket`), regardless of PaP state; checked before the base/PaP tiers so the Fire Bow (in-place PaP, no `.upgrade` form) stays serviceable. The Leviathan Axe (ammo-less melee) is excluded. (user 2026-07-08) | [`_acc_ammo_crate.gsc` `crate_cost`](../scripts/zm/zm_abandoned_cyber_city/_acc_ammo_crate.gsc) |
| `acc_ammo_crate_scale` | **`2.5`** | Trench ammo crate: **visual scale** of all 3 crate models (user 2026-07-12: the West model is ~29×33×25 units, knee-high — "tiny boxes you have to look down to even see"; was 3.0 for an hour, tuned down same day). The `.map` clip brushes (`acc_clip_ammo_crate_l2`/`_l5`, `acc_clip_paradise_ammo_crate`) are **baked at 2.5x to match** — the dvar is fine for a quick visual experiment, but a permanent scale change must re-size those clips too (geometry → full build + LED bake). Use-trigger radius grows with it (`64 + (scale-1)*24`). | [`_acc_ammo_crate.gsc` `spawn_crate_at`](../scripts/zm/zm_abandoned_cyber_city/_acc_ammo_crate.gsc) |
| `acc_paradise_rp_unlock_min` / `_panzer_unlock_min` / `_avo_unlock_min` | **`1` / `2` / `3`** | **Paradise staged boss roster** (user 2026-07-12 nerf): the escalation minute each boss JOINS the battle wave — Brutus + Phantom open at minute 0 (3:45 on the countdown), Rogue Protector at 1 (2:45), Panzer at 2 (1:45), Avogadro at 3 (0:45). The Apothicon Fury is dropped from the wave entirely. | [`_acc_paradise.gsc` `spawn_paradise_boss_wave`](../scripts/zm/zm_abandoned_cyber_city/_acc_paradise.gsc) |
| `acc_paradise_win_banner_sec` | **`5`** | Paradise win: seconds into the reward window before the green victory banner fades out (2s fade, then destroyed — it used to stay forever). | [`_acc_paradise.gsc` `clear_win_banners`](../scripts/zm/zm_abandoned_cyber_city/_acc_paradise.gsc) |
| `acc_armory_rack_max` | **`1`** | **The Armory** (upper room, [docs/39](39_armory.md)): max weapons the shared **team weapon rack** holds (deposit refused when full). **1 = ONE gun at a time** (user 2026-07-10; was 8). The cabinet-top display self-centers for the configured cap (≤8 per row, +16z per extra row). | [`_acc_armory.gsc` `deposit_gun`](../scripts/zm/zm_abandoned_cyber_city/_acc_armory.gsc) |
| `acc_armory_bottle_cost` | **`1`** | The Armory: **Empty Mega Bottles** spent per exchange for a **random Implant** (boss item; dropped via `acc_boss_items::grant_challenge_reward`, 60 s despawn). | [`_acc_armory.gsc` `bottle_loop`](../scripts/zm/zm_abandoned_cyber_city/_acc_armory.gsc) |
| `acc_armory_rack_hover` | **`6`** | The Armory weapon-rack **display tuning**: units the racked gun's world model floats above the cabinet's `+48` top face (worldModel origins vary per gun). Live-tune to seat the gun cleanly. | [`_acc_armory.gsc` `rack_slot_origin`](../scripts/zm/zm_abandoned_cyber_city/_acc_armory.gsc) |
| `acc_armory_rack_yaw` / `_pitch` / `_roll` | yaw **cap-aware** (0 for cap 1, 90 for a multi-gun row); pitch/roll **`0`** | The Armory weapon-rack **display angle**. A single racked gun lies **along** the 138u cabinet length (yaw 0) — the old fixed yaw 90 laid it across the 18u-deep cabinet so it stuck out both faces (fixed 2026-07-11). Live-tune the exact lie in-game. | [`_acc_armory.gsc` `spawn_rack_display`](../scripts/zm/zm_abandoned_cyber_city/_acc_armory.gsc) |

### Fog tuning (only read while `acc_fog_on 1`)

All floats, read at [`_acc_atmosphere.gsc:79-86`](../scripts/zm/zm_abandoned_cyber_city/_acc_atmosphere.gsc#L79-L86).

| Flag | Default | Meaning |
|---|---|---|
| `acc_fog_start_dist` | `0` | Distance (units) from camera where fog starts. |
| `acc_fog_halfway_dist` | `550` | Distance to half opacity. |
| `acc_fog_halfway_height` | `750` | Vertical falloff distance. |
| `acc_fog_base_height` | `0` | World-Z where the densest fog sits. |
| `acc_fog_r` / `acc_fog_g` / `acc_fog_b` | `0.15` / `0.19` / `0.29` | Fog color (0..1). |
| `acc_fog_max_opacity` | `0.80` | Max fog opacity (0..1). |

### Glitch Stalker mini-boss tuning

The Glitch Stalker is a script-only **mobile** mini-boss (default **r6**, then every 2nd
round — user 2026-06-23, was every round from r2) that teleport-blinks to flank players, moves **~15% faster** than the round's normal
zombies, and takes **bonus damage** in a short window after each blink. It wears the **stock
("Giant") zombie skin** (body + head) so it stands out from the charred horde, and has **no
health bar and no marker** — the skin is the only tell. Most values are read **live**. See
[`_acc_boss_glitch.gsc`](../scripts/zm/zm_abandoned_cyber_city/_acc_boss_glitch.gsc)
and [08_enemies.md](08_enemies.md).

| Flag | Default | Effect |
|---|---|---|
| `acc_glitch_enable` | **`1` (on)** | Master on/off; gates the real cadence. Set `0` to disable entirely. *(The dev/test *dvar* path is gone — `acc_glitch_test`/`acc_glitch_test_round` deleted 2026-07-16. Since 2026-07-17 dev instead HARDCODES 2 Stalkers EVERY round from round 1 (`cadence_hits`/`glitch_count_for_round` dev branches, docs/44); ship runs the real r6/every-2 cadence. See §E + memory `debug-banners-gated-by-acc-dev-only`.)* |
| `acc_glitch_hp_mult` | `1.5` | HP = this × the round's **normal zombie** health, read from the host's post-init `maxhealth`. (user 2026-06-23: 3 → 1.5, 3× too tanky; read as a float now so fractional mults work.) Auto-scales with the round — no separate HP curve. **Co-op:** the base already carries `regular_hp_mult()` (+20%/extra player), so this is a clean 1.5× a *co-op-scaled* zombie at any player count. *(Row corrected 2026-07-15: it named `level.zombie_health` and claimed "no co-op multiplier" — that WAS the bug. Reading the solo field made a 4p Stalker 0.94× a 4p zombie.)* |
| `acc_glitch_first_round` | `6` | First round it can spawn (real cadence). (History 2 → 8 → 4 → **6**, user 2026-07-15 "I actually like the first round being 6".) **This codifies reality:** r4 never produced a Stalker — the frame-0 spawn refusal ate the first spawn of every wave and r4's count was 1, so r4 delivered **zero** for the module's whole life while r6 delivered 1. |
| `acc_glitch_interval` | `2` | Then every N rounds **from `acc_glitch_first_round`** → **r6, 8, 10, 12, …**. (user 2026-06-23: was every round, then 4, now 2.) *(Row corrected twice on 2026-07-15: it read "r8, 10, 12, 14" — a fossil from when `first_round` was 8 — then briefly "r4, 6, 8, 10" before `first_round` moved to 6.)* |
| `acc_glitch_spawn_stagger` | `1.5` | Seconds between Stalker spawns **and before the first one**. The "before the first" part is load-bearing: spawning on frame 0 of a round is refused by the engine, which silently ate one Stalker per wave until 2026-07-15. Don't set this to 0. |
| `acc_glitch_count` | `3` | **UNUSED** — superseded by the `glitch_count_for_round` log curve below (kept only so an old console line is harmless). |
| `acc_glitch_count_log_k` | `2.0` | Glitch count curve `int(k·log₂(round) − c)`, then × `elite_count_player_mult()`. Raise for a steeper late game. (user 2026-07-15, replaced the linear `(round−2)/2`.) |
| `acc_glitch_count_log_c` | `4.0` | Offset for the curve above; `4.0` anchors **r6 → 1** = the count the game actually **delivered** pre-fix. Raise to shift the whole curve down. *(2026-07-15: was 3.0, which anchored r4 → 1 against **nominal** counts the frame-0 spawn bug never produced.)* |
| `acc_glitch_speed_mult` | `1.005` | Anim rate vs the round's normal zombies — ONE lever drives both chase speed **and melee-swing speed** (whole-ASM playback). (user 2026-07-17: 0.86 → 1.005, cut the 07-16 "they swing too fast" pass in half after it felt "too passive" — now about the same as the horde; the blink is its mobility. 2026-07-16: 1.15 → 0.86.) Locks the horde's gait × this rate. |
| `acc_glitch_blink_cd_min` | `1.55` | Min seconds between blinks. (user 2026-07-17: 1.77 → 1.55, cut the 07-16 pass in half — "too passive now"; 2026-07-16: 1.33 → 1.77; 2026-06-23: 1.0 → 1.33.) |
| `acc_glitch_blink_cd_max` | `2.59` | Max seconds between blinks. (user 2026-07-17: 2.96 → 2.59, cut the 07-16 pass in half; 2026-07-16: 2.22 → 2.96; 2026-06-23: 1.665 → 2.22.) |
| `acc_glitch_blink_dist` | `300` | Flank offset (units) from the target before the navmesh clamp (the **repositioning** flank, used when the boss is NOT engaged/camping). |
| `acc_glitch_engage_dist` | `160` | **Commit range (user 2026-06-18).** Within this distance of its target the boss does **not** blink — it commits to the melee swing (re-checked every blink tick). Fixes the "attacks then teleports away" bug; raise it to make the boss less blinky / more sticky, lower it to keep it blinking closer in. |
| `acc_glitch_still_thresh` | `48` | Units a target may move between two blink ticks (~1.0–1.665s) and still count as **stationary** → triggers a pounce. Below a strafe step, above idle jitter. |
| `acc_glitch_pounce_dist` | `56` | How far **short of** a stationary target (along the boss's approach vector) a pounce blink lands — in melee, on the reachable side. |
| `acc_glitch_pounce_cooldown` | `1867` | Min ms between pounces **on the same player** (any Stalker) — throttles a pack so it can't teleport-stack one camper. (user 2026-07-17: 2133 → 1867, cut the 07-16 pass in half; 2026-07-16: 1600 → 2133; 2026-06-23: 1200 → 1600.) |
| `acc_glitch_ldc_blink_dist` | `90` | Side-flank distance for the **lockdown-challenge** aggressive blink (small so the destination stays in the sealed room; `ldc_in_room`-checked). |
| `acc_glitch_recovery_sec` | `1.2` | Length of the post-blink vulnerability window (was 1.5). **Only fires on a real repositioning flank** now — never on a pounce/commit (a committed boss is never marked vulnerable, so no free-shoot). |
| `acc_glitch_recovery_dmg_mult` | `2.0` | Damage the boss **takes** while vulnerable (additive with headshots). Read in `_acc_damage`. **Not** the damage it deals. |
| `acc_glitch_melee_dmg_mult` | `0.45` | Melee damage the boss **deals** to players, vs a stock zombie's 60 (0.45 = −55%; was 0.5 — bumped now the boss actually reaches+holds melee, user 2026-06-18). Scales `host.meleeDamage` at spawn (`_acc_boss_glitch.gsc::spawn_glitch`). |
| `acc_glitch_stock_skin` | **`1` (on)** | Swap the boss to the stock Giant zombie **body + head** (vs the charred horde). Set `0` to keep the charred look. |
| `acc_glitch_fx` | **`1` (on)** | Post-blink **phase-in / hidden charge**: right after each blink the boss stays HIDDEN (`Ghost`, render-only — still hittable) and is physically driven toward the nearest player (navmesh-clamped), then revealed only once the AI has resumed moving — so it never *appears* standing still while it re-paths. Set `0` to leave it visible through the standstill (user 2026-06-17). |
| `acc_glitch_phasein_max` | `2.5` | Hard cap (s) on how long the boss stays hidden after a blink before it's force-revealed — a stuck actor can never stay invisible. |
| `acc_glitch_charge_speed` | `591` | Units/sec the boss closes the gap toward the player **while hidden** after a blink (the "exaggerated" anti-standstill drive). Higher = it rematerialises on you faster. (user 2026-07-17: 506 → 591, cut the 07-16 pass in half; 2026-07-16: 675 → 506; 2026-06-23: 900 → 675.) |
| `acc_glitch_reveal_dist` | `140` | Distance (units) from a player at which the hidden charge stops and control hands back to the zombie AI — it then reveals once moving. **140 (was 240)** so it reveals *inside* `acc_glitch_engage_dist` and presses the attack instead of re-blinking before contact (user 2026-06-18). Higher = reappears farther out / less in-your-face. |
| `acc_glitch_teal_eyes` | **`1` (on)** | Tint the Glitch Stalker's eyes (vs the horde) via a client eyeball-material recolour — **no FX asset**. Set `0` for stock eyes. |
| `acc_glitch_eye_color` | `0.5` | Eye colour value (client `mapshaderconstant`, live-tunable). **Dial this in-game until the eyes read teal** — the exact value→colour mapping is the engine's eye shader, so tune by eye. |
| `acc_glitch_eye_lum` | `1.0` | Eye glow luminance (live-tunable). **Lower it** if the map's dark colour-grade (`VisionSetNaked`) washes a full-luminance eye toward white. |

> The Glitch Stalker spawns on **every scheduled cadence round** — the old full-boss round it
> used to yield to (the Subroutine Core) was **removed 2026-06-22**, so there is nothing left to
> yield to ([`_acc_boss_glitch.gsc:123-126`](../scripts/zm/zm_abandoned_cyber_city/_acc_boss_glitch.gsc#L123)).
> It runs **alongside** the normal wave and does **not** gate round end (like Brutus).
> **No size override:** a 75% size was requested but NOT implemented — `SetScale` on a live
> zombie AI is the confirmed `0xC0000005` crasher; a smaller body would need a pre-scaled model
> asset (baked at export), swapped via the same `acc_glitch_stock_skin` SetModel path.

### Phantom (holographic cloaker boss) — `_acc_boss_phantom.gsc` / `.csc`

The marquee ~round-10 boss (the random round-boss rotation slot). Cloaks while stalking, materializes
to strike with a cyan glow aura, gets the boss health bar **and** boss music (Brutus was down-leveled).

| Flag | Default | Effect |
| --- | --- | --- |
| `acc_phantom_enable` | **`1` (on)** | Master on/off; gates the real cadence. *(The per-feature dev/test spawn + debug dvars in this table were removed 2026-07-16; the `[phantom]`/`[AVO]` traces ride `level.acc_dev`. Since 2026-07-17 dev HARDCODES one extra Phantom on round 3 (`phantom_due_count` dev branch above the roster consult, docs/44); the r9/18/27 roster runs REAL in dev and ship. See §E + memory `debug-banners-gated-by-acc-dev-only`.)* |
| `acc_phantom_hp` | `65000` | Phantom **base** solo HP at the **round-5 anchor** (`acc_phantom_hp_anchor`, 5) — **SHARED by Phantom + Rogue + Avogadro + Panzer** (user 2026-07-05: 56000 → 65000). The round-scaled value is then × the logarithmic co-op multiplier (`boss_hp_player_mult`). |
| `acc_phantom_hp_exp` | `1.06` | Phantom HP **compounding exponent per round** past the anchor — base × 1.06^(round−anchor) (user 2026-07-04: 1.1 → 1.08 → 2026-07-08 1.06 after the anchor moved to r5, the SOFTEST boss tier — Brutus/Panzer 1.12 > Rogue 1.09 > Phantom 1.06, all on the same 65k/anchor-5 scale). **Avogadro shares this exponent** (it reads `acc_phantom_hp_exp` too). Solo (anchor 5) r5 65k → r10 87k → r20 156k → r30 279k → r40 500k. Read as a **float**; `1.0` = flat. |
| `acc_protector_hp_exp` | `1.09` | Rogue Protector HP **compounding exponent per round** — the MIDDLE tier on the shared `scale_phantom_hp` scale (user 2026-07-04 1.1 → 2026-07-08 1.11 → 1.09 after anchor moved to r5). Solo (anchor 5) r5 65k → r10 100k → r20 237k → r30 561k → r40 1.33M. Read as a **float**. | [`_acc_civil_protector.gsc`](../scripts/zm/zm_abandoned_cyber_city/_acc_civil_protector.gsc) |
| `acc_protector_close_mult` | `3.0` | Rogue Protector **proximity damage** — his BULLETS hit for up to this multiple at point-blank, tapering **linearly** to `1.0` at `acc_protector_far_range` (user 2026-07-05 "more damage the closer he is"). BULLETS ONLY — his mahem (`MOD_PROJECTILE_SPLASH`, already blast-tapered) and zap pulse (`MOD_GRENADE_SPLASH`) are excluded. Applied in [`_acc_elites.gsc`](../scripts/zm/zm_abandoned_cyber_city/_acc_elites.gsc)`::on_player_damaged` BEFORE Exo/Savior resistances. `1.0` = off. Read as a **float**. |
| `acc_protector_close_range` | `150` | Distance (units) at/inside which the Rogue Protector's bullet does the **full** `acc_protector_close_mult`. Read as a **float**. |
| `acc_protector_far_range` | `1000` | Distance (units) at/beyond which the proximity boost is **gone** (multiplier `1.0`). Between this and `acc_protector_close_range` the multiplier ramps linearly. Must exceed `close_range` or the ramp is skipped. Read as a **float**. |
| `acc_phantom_hp_anchor` | `5` | Round at which the base HP applies **and compounding starts** for ALL roster bosses (Phantom/Rogue/Avogadro/Panzer) + a matched Brutus anchor (user 2026-07-08: 10 → 5, "all boss scaling starts on round 5"). They first spawn at round 9, so their first HP is already base × exp^4. |
| `acc_phantom_melee_dmg` | `19` | Melee damage dealt to players — **~30% UNDER a Glitch Stalker's 27/hit** (user 2026-06-24 "not super lethal, 30% less than a glitch"; was 85). Jumpscary, not a murderer. Survives the trench-melee override (bosses are excluded). |
| `acc_phantom_first_round` | `10` | **Legacy-fallback cadence only.** The Phantom's real spawn cadence is the shared multi-boss roster — **every 9 rounds from round 9** (r9/18/27…; `level.acc_boss_roster_fn`, always published). This dvar drives spawns **only** if that roster pointer isn't published yet ([`_acc_boss_phantom.gsc:235-245` `cadence_hits`](../scripts/zm/zm_abandoned_cyber_city/_acc_boss_phantom.gsc#L235)), so it is inert in normal play. First round of that fallback — same in dev (the dev 4/4 fast cadence was disabled 2026-07-12; the CURRENT dev accelerator is the hardcoded one-shot round-3 spawn in `phantom_due_count`, 2026-07-17, which bypasses this dvar entirely). |
| `acc_phantom_interval` | `10` | Legacy-fallback interval (see above) — every N rounds, same in dev. Dvar-overridable, but **inert in normal play** because the every-9 roster drives the real cadence (matches the "Current values" summary below). |
| `acc_phantom_director_period` | `3` | Seconds between `phantom_director` retry ticks (the fullproof owed-flag spawner). |
| `acc_phantom_cloak` | **`1` (on)** | The cloaker gimmick: invisible (`Ghost`) while stalking, materialize (`Show`) within `acc_phantom_reveal_dist`. Set `0` to keep it always visible. |
| `acc_phantom_reveal_dist` | `240` | Distance (units) from a player at which it materializes; cloaks beyond. **240 (was 400)** so he stays invisible until he's almost on you = a startling reveal. |
| `acc_phantom_screech` | **`1` (on)** | Play a warp screech (`acc_glitch_warp`) on each materialize / teleport-in (cooldown'd by `acc_phantom_screech_cd`). The audio "jump-scare" cue. Set `0` to mute. |
| `acc_phantom_screech_cd` | `1200` | Min ms between screeches (so a chained teleport burst still scares but never machine-guns). |
| `acc_phantom_flicker_pct` | `12` | % of 0.1 s ticks it blips invisible **while materialized** (the unstable-hologram flicker). `0` = no flicker. |
| `acc_phantom_aura` | **`1` (on)** | The holographic cyan **glow aura** (client FX, `accPhantomAura` clientfield → `_acc_boss_phantom.csc` PlayFX `fx_perk_glow_teal`). Cloak-aware (on only while materialized, so it never reveals the cloaked boss). Set `0` to disable. Swap `level._effect["acc_phantom_aura"]` in the `.csc` for a different look. |
| `acc_phantom_eyes` | **`1` (on)** | Cyan/teal eyes via the shared actor eye-tint (`accEyeTint`). |
| `acc_phantom_stock_skin` | **`1` (on)** | Swap to the stock Giant body/head canvas (vs the charred horde). |
| `acc_phantom_speed_mult` | `1.1` | Sprint-gait playback rate (1.0 = natural zombie sprint ~181 u/s). The TELEPORTING reads as "fast", so the gait stays a modest +10% (higher anim rates risk the non-linear catch+instakill overshoot). |
| `acc_phantom_serum_slow` | `0.7` | Gait multiplier while the Phantom is inside a **Phase Serum** holder's aura (radius = the shared `acc_phase_serum_radius`, 350) — **30% slow** (user 2026-07-11; retuned twice same day `0.5` → `0.6` → `0.7`). The Glitch concept at a milder penalty: the Glitch takes `acc_phase_serum_slow` 0.2 **and** loses its blink; the Phantom only slows — **teleports keep working**. Read live each speed sweep (`phantom_speed_think` → `acc_utility::serum_aura_active`). |
| **Teleport mobility (user 2026-06-24)** | | The Phantom stalks + periodically blinks (~30% slower cadence than a glitch); the player→player chain is a random special. |
| `acc_phantom_teleport` | **`1` (on)** | Master on/off for the teleport mobility. `0` = pure cloaked stalker (no blinks). |
| `acc_phantom_tp_delay` | `2.0` | Grace seconds after spawn before the first teleport. |
| `acc_phantom_tp_cd_min` / `_max` | `1.89` / `2.7` | Seconds of plain stalking between teleport actions (glitch blink is 1.33–2.22). Cut 10% from `2.1`/`3.0` (user 2026-06-24) = **+10% aggro** — it teleport-strikes 10% more often. |
| `acc_phantom_strike_dist` | `56` | A blink lands this far short of the player (melee range). |
| `acc_phantom_strike_min` / `_max` | `1.0` / `1.4` | Dwell seconds in melee after a normal blink (one swing) before backing off. |
| `acc_phantom_retreat` | **`1` (on)** | Hit-and-run: warp away after a normal strike so it never camps. `0` = it lingers in melee. |
| `acc_phantom_retreat_dist` | `420` | How far the back-off warp jumps from the struck player. |
| `acc_phantom_chain_chance` | `25` | % of teleport actions that fire the **player→player CHAIN special** (fires with **1+ players**; hits **each player once**). `0` = never chain. |
| `acc_phantom_chain_hops` | `4` | **MAX** hops per chain — **capped to the live player count** so each player is hit once (user 2026-06-26). **Solo = 1 hop** (a single strike, not a re-chain on the same player). |
| `acc_phantom_chain_dwell_min` / `_max` | `0.7` / `1.1` | Seconds on each chain hop (the rapid combo). |
| `acc_phantom_slow_mult` | `0.70` | Move-speed multiplier applied by the chain-special **zap** when it connects — **−30%** (user 2026-07-05, boss-stun unified to 30%; was `0.75`/−25%). Read by `acc_utility::recompute_move_speed` while `acc_phantom_slowed`. |
| `acc_protector_slow_mult` | `0.70` | Move-speed multiplier for the **Rogue Protector** zap stun — **−30%**, matches the other bosses (user 2026-07-05, was `0.75`/−25%). Read while `acc_protector_slowed`. |
| `acc_boss_slow_mega_mult` | `0.90` | **Mega Electric Cherry "Power Surge"** softened boss-stun multiplier — a flat **−10%** floor instead of the full `−30%` (user 2026-07-03; the softening is a fixed floor, so it always brings any boss stun to −10% regardless of the base). Used in place of the `−30%` above when the slowed player holds live Mega EC (`acc_*_slow_mega` flag set in `_acc_elites::acc_phantom_chain_zap`/`acc_protector_zap`/`acc_avogadro_zap`). **Also anti-stack** (user 2026-07-09): while every active stun is Mega-softened, the concurrent-stun stack add below is skipped entirely — flat −10% no matter how many bosses zap at once. |
| `acc_boss_slow_stack_add` | `0.05` | Extra slow per **additional concurrent** boss stun (user 2026-07-09: boss stuns barely stack — the strongest slow is the base, each extra active stun adds a flat −5%: one −30%, two −35%, three −40%). Applied once in `recompute_move_speed`; floor-clamped at a 0.10 total multiplier. Mega Electric Cherry holders skip the add (see `acc_boss_slow_mega_mult`). |
| `acc_phantom_slow_sec` | `3.0` | Seconds the zap slow lasts; a fresh chain hit refreshes the window (`_acc_elites::acc_phantom_slow_clear`). |
| **Avogadro "cyberhacker" (user 2026-07-04)** | | Fast electric harasser: 0-damage shots that stun-lock, hacks Lab machines. Spawns in the Lab; HP = the Phantom's (`scale_phantom_hp` × `acc_phantom_hp_exp`). 3rd boss-roster type. |
| `acc_avo_enable` | **`1` (on)** | Master on/off. Gates the roster type (a disabled roll re-homes to the Rogue Protector so the count never shrinks). |
| `acc_avo_gait` | **`run`** | Locomotion gait: `walk` \| `run` \| `sprint`. String dvar; applied at spawn (change takes effect on the next Avogadro). |
| `acc_avo_anim_rate` | `1.15` | Anim playback rate applied at spawn via `ASMSetAnimationRate` — run gait at boosted playback; also speeds his throw anim. Playtest ladder (user 2026-07-06): 1.0 too slow → 2.0 way too fast → 1.5 still out-speeds the player → 1.2 a bit slower → **1.15**. **Design intent: an un-slowed player outruns him — the 30% zap slow closes the gap, not raw pace.** Persists (the `_acc_zombie_speed` mechanism); safe because it does NOT touch the run-cycle override that froze Brutus. |
| `acc_avo_shot_damage` | `6` | Damage per **bolt** impact (user 2026-07-06 ladder: pure-stun 0 → 1 → 5; **user 2026-07-18 +25% all-Avogadro damage → 6**). Attacker = the boss (damage direction + the pack's electric shellshock/overlay tell, made stock-safe). `0` restores pure-stun. |
| `acc_avo_aura_damage` | `10` | Damage per point-blank **aura** zap (own dvar; user 2026-07-12: 5 → 8/tick; **user 2026-07-18 +25% → 10**). The **bolt** stays at `acc_avo_shot_damage` 6. |
| `acc_avo_bolt_speed` | `900` | Bolt projectile speed, u/s (was 1100; user 2026-07-06 "hard to see" — slower flight reads clearly and is honestly dodgeable). Min flight time is clamped to 0.25 s so close throws survive client-snapshot latency. |
| `acc_avo_shock_sec` | `0.75` | Electric shellshock + `zm_trap_electric` overlay duration per zap hit (pack's 1.25 s would chain into permanent wobble at aura cadence). |
| `acc_avo_bolt_cd` | `0.75` | Seconds between **bolt throws** (2026-07-06 attack rework: the BT plays his throw anim, the anim notetrack launches a **visible bolt projectile**, the stun+damage land on **impact**; replaces the pack's hardcoded 20 s cooldown. Playtest ladder: 3.0 "so slow" → 1.5 → "2x faster" → 0.75; the throw anim — itself 2x via `acc_avo_anim_rate` — spaces the real cadence). Read in `_zm_ai_avogadro::avoFinishBoltShoot`. His bolt LOS check also lost the pack's ±50 u facing-rect (an orbiting player never sat in it — bolts starved on `los`); only the behind-check + world trace remain. |
| `acc_avo_bolt_speed` | `900` | Bolt projectile speed (units/sec) — dodgeable at range. |
| `acc_avo_bolt_hit_radius` | `130` | Impact radius (units) inside which the bolt's 30% slow lands (everyone inside, so a huddled co-op pair both get clipped). |
| `acc_avo_bolt_lead` | `0.25` | Seconds of target-velocity lead on the bolt's aim point (the pack's original 1.5 s over-led wildly). |
| `acc_avo_fire_interval` | `0.5` | Seconds between **point-blank AURA zaps** — the direct stun that covers the bolt's 150 u minimum range (2026-07-06: this dvar no longer paces the main attack; the bolt does. Playtest: 0.8 → 0.5). Read as a **float**. |
| `acc_avo_aura_range` | `220` | Aura zap reach (units). Beyond this, only the bolt (150–2000 u, needs LOS + facing) stuns — hiding from the bolt is intended counterplay. |
| `acc_avo_fire_range` | `1500` | Fallback-target search radius (bolt retarget when his enemy dies mid-throw + the starvation watchdog). |
| `acc_avogadro_slow_mult` | `0.70` | Move-speed multiplier his **shot** applies — **−30%**, matches the Phantom/Rogue (user 2026-07-05, was `0.75`). Read by `recompute_move_speed` while `acc_avogadro_slowed`. Mega EC softens to `acc_boss_slow_mega_mult` (−10%). |
| `acc_avogadro_slow_sec` | `3.0` | Seconds the shot-slow lasts; every shot refreshes the window (so while he keeps shooting you, you stay slowed). Read by `_acc_elites::acc_avogadro_slow_clear`. |
| `acc_avo_knife_hits` | `100` | Knife hits to kill him at **any** round — the knife does `maxhealth / this` per hit, so he's deliberately **weak to melee** (user 2026-07-05). Read as an **int** in `_zm_ai_avogadro::avogadro_damage_override`. **Applies to KNIVES only** (bare knife, Berzerker knife, ballistic-knife stab). The **Leviathan Axe** and **Action Figure** are excluded (review 2026-07-15) and keep their own designed hits-to-kill from `acc_damage::on_ai_damage` (`acc_leviathan_hits_t0..t3` / `acc_af_boss_hits`) — `actor_damage_func` runs *after* our actor-damage callback and **replaces** its value (`_zm.gsc:5748`), so without the exclusion the counter collapsed both to 100 and made the melee-weak boss the melee weapons' *worst* target. |
| `acc_avo_hack_secs` | `30` | Seconds a machine stays disabled after he hacks it. **Full-disable contract (user 2026-07-06)**: base perk off (`perk_pause`), **cannot buy** (`TriggerEnable(false)` on every trigger of the specialty, both dimensions), machine glow dark, **and all Mega live effects drop** — `owns_or_paused` treats an avo-hacked perk as not-owned (spider drops, Power Surge, boss-special/EMP immunity), the Widow's stance watcher self-pauses, and Ultimate Tank's +50 (plus jugg's +150) is recomputed away via `health_reboot` (`_acc_mega_bottles::on_perk_hacked/restored`). PaP hack = `level.acc_pap_hacked` pack-refusal. Read as an **int**. |
| `acc_avo_hack_range` | `150` | Proximity (units) to a machine at which he disables it. |
| `acc_avo_hack_think` | `0.4` | Seconds between `hack_director` ticks (seek-a-machine / hack cadence). |

**Multi-Avogadro (round 18+):** the 2-machine hack cap is **per-boss**, so two Avogadros can disable up to **4** machines (all 4 perks) between them (user 2026-07-05). Each boss owns its hacks (`level.acc_avo_hacked_by[key]` = the boss's `acc_avo_id`) and restores **only its own** when it dies; a last-Avogadro death also force-restores any residue. One machine is only ever hacked by one Avogadro at a time (the other seeks a different one).
| `acc_avo_seek_timeout_ms` / `acc_avo_seek_blacklist_ms` | `9000` / `30000` | Anti-softlock: if he can't get within `acc_avo_hack_range` of a machine within the timeout, that machine is blacklisted for the blacklist window and he chases players. **2026-07-06 playtest fix:** blacklist 8 s → 30 s and the seek is now **sticky** (commits to one machine until arrival/timeout) — the old re-pick-nearest-every-tick + short blacklist ping-ponged between two machines forever, resetting the timeout so the chase fallback never engaged. Machine goals are also **navmesh-projected** at cache time (`GetClosestPointOnNavMesh`, Brutus recipe) — the raw vending-machine origin sits inside the machine at z=60, off-mesh, so `SetGoal` silently failed = he stood still all game and never hacked. |
| `acc_avo_chase_after_timeout_ms` | `12000` | Pure player-chase window after a seek timeout before he tries the next machine (so failed seeks read as "hunts you between hack attempts", not standing). Player chase itself is the BT target service's **entity** goal (auto-tracking), not a stale position. |

> Shares `acc_boss_music_on` (the boss-music master gate) and the boss health-bar pipeline
> (`acc_boss_spawned`). No `SetScale` (the `0xC0000005` crasher); all the script-only boss landmines
> are pre-solved by the `_acc_boss_glitch` template it was cloned from.
>
> **Spawn (fixed 2026-06-24):** `spawn_promoted_zombie` sets `spawner.script_forcespawn = true` before
> `zombie_utility::spawn_zombie` (with a short retry) — without it the stock call returns `undefined` at round
> start (the wave only flags spawners mid-round), which is why the Phantom "never spawned." It also picks the
> active spawner **nearest a player** and **deletes its corpse** on death (the `acc_is_mini_boss` body is
> skipped by `_acc_corpse_cleanup`). Memory: `boss-spawn-needs-forcespawn`.
> **Current values:** spawns via the shared boss roster (every 9 rounds from round 9, `_acc_civil_protector`);
> **HP** = base **65k × 1.06^(round−5)** × the logarithmic co-op mult (`acc_phantom_hp` / `_exp` / `_anchor` — user
> 2026-06-27 no-longer-flat, anchor 10→5 + exp →1.06 on 2026-07-08); **speed** `acc_phantom_speed_mult` **1.1** (sprint gait); **glow RED**
> (`acc/light/fx_perk_glow_red`).

---

## E) Debug-visual flags — **REMOVED 2026-07-16 (all re-coupled to `acc_dev`)**

> **⚠️ THE `acc_*_debug` DVARS NO LONGER EXIST (user 2026-07-16, reversing the 2026-07-10 decoupling).**
> The user's standing rule: **the ONLY flags are `acc_dev`, `acc_god`, and the Lua `ACC_MOCK_PARTY`** — no
> per-feature debug/test/gating dvars. The 2026-07-10 "clean screen" pass that gave every `dbg()`/inline print
> its own `acc_*_debug` dvar was **reversed**: all 33 gates were converted back to `IS_TRUE( level.acc_dev )`,
> so **debug rides the ONE dev flag** (visible in dev, silent in ship). The dvars below —
> `acc_variants_debug`, `acc_glitch_debug`, `acc_drops_debug`, `acc_phantom_debug`, `acc_avo_debug`,
> `acc_warden_debug`, `acc_panzer_debug`, `acc_protector_debug`, `acc_dmg_debug`, `acc_fury_debug`,
> `acc_hudelem_debug`, `acc_crash_debug`, `acc_perk_lights_debug`, `acc_lockdown_debug`,
> `acc_lockdown_challenge_debug`, `acc_mega_flopper_debug`, `acc_lb_debug`, `acc_wpn_debug`, `acc_oob_debug`,
> `acc_trench_dbg`, `acc_door_debug` — are all **gone**; setting them does nothing. To see any of this debug,
> launch dev (`level.acc_dev = true;` hardcode + rebuild). Leftover/temp on-screen diagnostics (the
> `[COUNTLOG-TEMP]` glitch/elite spawn-count spam, `dev_report_exchange_props`, `bridge_debug_readout`) were
> **deleted outright**. Rule of thumb going forward: gate debug on `acc_dev`, or if it's temp verification,
> REMOVE it when done — never mint a new dvar. See memory `debug-banners-gated-by-acc-dev-only`.

---

## Conventions & gotchas

- **All flags are `acc_`-prefixed.** No un-prefixed custom dvars exist.
- **Default polarity:** everything defaults to *off / intended behavior* **except
  `acc_weapon_variants`, `acc_pap_tier_anim`,
  `acc_glitch_enable`, `acc_glitch_fx`, `acc_glitch_stock_skin`, and
  `acc_glitch_teal_eyes`** (default on).
  Those are the "set to 0 to disable" flags — every other flag is "set to 1 to
  enable". (`acc_corpse_linger_sec` is a numeric seconds value, default `0` in
  code; set `0` for instant corpse removal.) (`acc_suppress_flying_gibs` default **1** —
  stops loose severed-limb gib chunks spawning on the ground (dismemberment model + blood
  FX still play); set `0` to let limbs fly off and litter the map again.)
- **One-shot vs sustained:** `acc_open_doors`, `acc_skip_round`, `acc_tp_perks`,
  `acc_tp_spawn` auto-reset to `0` after firing (momentary triggers). Everything
  else is a sustained read (stays in effect until you change it / relaunch).
- **Dev console commands need a dev build (`level.acc_dev = true;`).** The `_acc_dev` module returns early
  unless `IS_TRUE( level.acc_dev )` ([`_acc_dev.gsc:73`](../scripts/zm/zm_abandoned_cyber_city/_acc_dev.gsc#L73)),
  so its console watchers (teleport / skip / open-doors) are inert without the
  master flag. (The always-on crosshair damage numbers + area-name banner are set
  up *above* that gate, so they run in normal play too — they are game features,
  not dev tools.)
- **Keep this doc in sync.** When you add a new `getdvarint`/`getdvarfloat`
  read, add a row here in the same commit (CLAUDE.md convention: docs follow
  code). Find every read with:
  `node` / grep `getdvar` across `scripts/zm/zm_abandoned_cyber_city/`.
