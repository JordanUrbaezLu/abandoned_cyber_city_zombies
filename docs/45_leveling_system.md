# 45 — Leveling System — DESIGN SPEC + STATUS

Status: **BUILT, currently DISABLED** (user 2026-07-24: "disable for now, dev and non-dev").
Module `_acc_leveling.gsc`, namespace `acc_leveling`. History: built Jul 20-21 (dev-only), economy
retuned for risk/skill Jul 21, LIVE Jul 22, OFF Jul 24. `is_active()` is the SINGLE on/off point —
it returns `false`, making everything inert everywhere (no XP, no HUD chip, no tier gates; all hook
sites no-op through the guarded grants). **Re-enable = one line in `is_active()`** (`true` = live,
`IS_TRUE(level.acc_dev)` = dev-only). NOTE: sections below describe the system as built; gating
status is only ever `is_active()`. Companion docs: docs/03, docs/29, docs/28, docs/11, docs/22.

---

## 1. Intent

A per-player **level** (1..10) that is the player's **augmentation ceiling**. It gates
the two tier-ladder systems and gives players a reason to push objectives — kill Brutus,
dive the trenches, clear rounds fast — instead of camping a safe room.

Design decisions locked with the user (2026-07-20):

- **Level caps BOTH tier ladders.** Max weapon-Overclock tier = max Exo-Suit tier =
  your level. **You start at LV0** (nothing tier-able yet); **reaching LV1** unlocks tier 1
  of both; **LV5** → tier 5 of each; **LV10** = fully maxed. The two systems are structural
  twins in this map (both 0..10 Data-Shard ladders), so one symmetric rule covers both.
  Starting at LV0 makes the first level a real objective, not a freebie.
- **XP comes from all four sources**: boss kills, trench dwell, round survival,
  zombie kills. **Round-survival XP scales with clear speed** (fast = more, camping =
  base only) — this is the explicit anti-camping lever.
- **Progression = XP bar + rising thresholds.** Cap at **level 10** (= fully unlocked).
- **HUD**: bottom-left, part of the Aetherium HUD — a `LV N` readout + a thin XP bar.

Why this is "hard to test/systematize" (user's words) and how we handle it: leveling
touches five modules and only manifests over a long run, so the whole thing sits behind
`level.acc_dev` and is validated in a dev build where shards are unlimited (see §8).

---

## 2. Player state

New per-player fields owned by `_acc_leveling.gsc` (created on connect, coop-crash-guarded
exactly like `acc_data_shards::grant_player`):

| Field | Type | Meaning |
|---|---|---|
| `player.acc_level` | int 0..10 | Current level. Starts at **0** (nothing tier-able until LV1). |
| `player.acc_xp` | int | XP accumulated **within the current level** (resets to remainder on level-up). |

Level is **per-player** and **per-run** (resets each game; no transfer-vault persistence
for now — see §11). Range is 0..10 because both gated ladders cap at tier 10 (`ACC_EXO_MAX`,
`ACC_TIER_MAX`); a level above 10 would gate nothing.

### XP curve

`xp_to_next(level)` — rising cost to reach the next level. `level+1` so it is well-defined
at **LV0** (no divide-by-zero in the HUD fraction). Starting proposal (all `#define`, TUNE
in dev):

```
xp_to_next(level) = ACC_LVL_XP_STEP * (level + 1)   // ACC_LVL_XP_STEP = 75 (halved from 150, user 2026-07-22 "too grindy")
// L0->1: 75, L1->2: 150, ... L9->10: 750; cumulative to LV10 = 4,125 XP (~round 20-25 engaged)
```

At `acc_level == 10` XP stops mattering (no further level-ups); the bar shows full.

---

## 3. Gating rule — symmetric ceiling

Both gates are a **single line inserted before the Data-Shard spend**, so a level-denied
press costs no shards. Both files already have the exact `hud_msg` fail-ack idiom to copy.

**Deny condition (both):** `acc_leveling::is_active() && next_tier > player.acc_level`.

### 3a. Exo Suit — `_acc_exo.gsc::station_loop()`

Insert between `next_tier = player.acc_exo_tier + 1;` (≈:158) and the `try_spend` (≈:160):

```gsc
next_tier = player.acc_exo_tier + 1;
if ( acc_leveling::is_active() && next_tier > player.acc_level )
{
    player acc_utility::hud_msg( "^5EXO SUIT^7 - Tier " + next_tier + " requires ^5Level " + next_tier + "^7" );
    wait 0.4;
    continue;
}
cost = exo_cost( next_tier );
...
```

Single grant chokepoint downstream is `player.acc_exo_tier = next_tier;` (≈:167); gating
purchase automatically caps every downstream effect (depth-speed, -6%/tier resist,
+15%/tier melee) with no change to those effect sites.

### 3b. Weapon Overclock — `_acc_overclocks.gsc::terminal_loop()`

Insert between `next_tier = progress.tier + 1;` (≈:337) and the `try_spend` (≈:339):

```gsc
next_tier = progress.tier + 1;
if ( acc_leveling::is_active() && next_tier > player.acc_level )
{
    player acc_utility::hud_msg( "^5OVERCLOCK^7 - Tier " + next_tier + " requires ^5Level " + next_tier + "^7" );
    wait( 0.5 );
    continue;
}
cost = tier_cost( next_tier );
...
```

Grant chokepoint downstream is `progress.tier = next_tier;` (≈:346). Overclock is
**per-weapon**, but the gate is **per-player**: one level caps how high ANY of your guns
can be overclocked. (Terminology note: in this map "Overclock" is the per-weapon tier
ladder, NOT the disabled Cyberware skill branch in docs/03.)

### 3c. `is_active()` — the dev-gate flip point (READ THIS — semantics are inverted)

```gsc
// scripts/zm/.../_acc_leveling.gsc
function is_active()
{
    // The ENTIRE leveling feature (XP + HUD + these gates) is dev-only FOR NOW.
    // So the gate ENFORCES when dev is ON (that is how we test it), and is a
    // complete no-op when dev is OFF (ship = overclock/exo ungated, as today).
    // This is the OPPOSITE of the usual "dev bypasses restrictions" idiom — do
    // not flip it. Single point to promote the system out of dev later: change
    // this return to `true` (or the real ship condition).
    return IS_TRUE( level.acc_dev );
}
```

Consequences:

- **Ship (dev off):** `is_active()` is false, so both gate `if`s short-circuit before
  reading `player.acc_level` (which is never set when the module early-returns). Overclock
  and Exo behave **exactly as today**. Zero footprint. Passes `prep_release.ps1` Gate 0/0c
  for free.
- **Dev build (dev on):** gates enforce. Dev grants **unlimited shards**, but the gate
  denies on **level before the spend**, so unlimited shards do NOT bypass it — the gate is
  genuinely testable in dev.

`_acc_overclocks.gsc` and `_acc_exo.gsc` each need `#using scripts\zm\zm_abandoned_cyber_city\_acc_leveling;`
to call `is_active()`.

---

## 4. XP sources

Public API: `acc_leveling::grant_xp( player, amount, source_tag )` — mirrors
`acc_data_shards::grant_player` (`_acc_data_shards.gsc:136`): init-guard the field, clamp,
add, then check for level-up and re-push the HUD. `source_tag` is for dev logging only.

All amounts are `#define` (TUNE). Zombie-kill XP is deliberately **small** so passive
farming never out-earns objectives (it dilutes the push-objectives intent — it is in
only because the user asked for it).

### 4a. Boss kills — DAMAGE-WEIGHTED (built 2026-07-21)

**User rule (2026-07-21): "XP points on bosses is distributed by damage allocation. Players
who did more damage get more XP and it's proportional."**

The distribution rides the EXISTING per-victim damage ledger — `_acc_points::record_damage`
already maintains `victim.acc_damage_contrib[entnum] = { damage, player }` on **every**
player damage path in `_acc_damage::on_ai_damage` (final post-multiplier damage, players
only, capped at maxhealth per player). No new tracking was added.

- Each boss **death watcher captures the ledger pre-reap** (the corpse can be reaped the
  same frame as the death notify — the same coop crash race the watchers already guard) and
  passes it as `grant_unified_boss_reward( drop_origin, b_skip_item, a_dmg_contrib )`.
  Poll-loop watchers (Avogadro, Panzer) poll the ledger alongside `org` + do a final
  post-loop refresh so the killing blow is counted.
- `acc_leveling::grant_boss_xp_shares( a_contrib )`: **pool = `ACC_LVL_XP_BOSS` (250) ×
  damage-dealers** (solo unchanged at 250; a non-participant's slice lapses, never transfers —
  soloing a boss in a 4-player game pays 250, not a 4× windfall). Split 20% even floor + 80%
  by damage. Returns false when no usable ledger → the caller **falls back to the flat
  per-player grant** (scripted/ally kills, capture failure, ship).
- Points/shards/bottle in the shared reward stay FLAT for everyone — only XP is weighted.
- Covers every boss (Brutus, Panzer, Phantom, Avogadro, Scientist, Rogue Protector);
  Paradise-suppressed as before (early return in the shared fn).
- **Participation floor (BUILT 2026-07-21, user decision):** `ACC_LVL_BOSS_FLOOR_PCT` (20%)
  of the pool is split EVENLY among all damage-dealers; the remaining 80% is damage-weighted.
  A high-DPS carry still earns most, but a revive/support teammate isn't starved of the
  ceiling. Solo unchanged (floor + weighted both go to the one player = 250).
- **Brutus finisher (BUILT 2026-07-21):** `watch_mini_boss_death()` grants
  `grant_brutus_killer_xp(attacker)` (`ACC_LVL_XP_BRUTUS_KILLER` = 100) to the player who
  lands the kill on the REAL Trench Warden — a commitment-gated bonus (he's damage-immune
  outside the trench). Paradise Brutus excluded (no_reward path).

### 4b. Trench dwell — combat-gated (REWORKED 2026-07-21)

The 4-lens review found the #1 exploit: passive dwell was a pure occupancy timer, so a
maxed-Exo player could stand in a safe deep pocket and AFK-farm ~257 XP/min at L5. FIX — in
`acc_leveling::grant_trench_xp` (called from the trench income tick in `_acc_bus_trench.gsc`):
- **Combat gate** — pays only if you killed / took a hit within `ACC_LVL_TRENCH_COMBAT_MS`
  (8s), stamped `player.acc_lvl_last_combat`. No fighting → no dwell XP. Rewards fighting
  deep, not standing deep.
- **Per-round cap** `ACC_LVL_TRENCH_ROUND_CAP` (60) — dwell is a top-up, not the main course.
- `ACC_LVL_XP_TRENCH_BASE` 6→3 (× layer). Deeper still pays more.

### 4c. Round survival — individual + risk/skill-weighted (REWORKED 2026-07-21)

Per-player at `acc_round_end` (trackers reset in `reset_round_trackers()` at `acc_round_start`;
`acc_round_end(N)` fires before `acc_round_start(N+1)` so the award reads round-N state before
the reset for N+1):

```
xp  = ACC_LVL_XP_ROUND_BASE (15)
    + speed_bonus (0..ACC_LVL_XP_ROUND_SPEED=75)   // FORFEITED if you went down this round (p.downs)
    + ACC_LVL_XP_ROUND_DEEP_LAYER (5) * deepest layer reached this round   // RISK
    + ACC_LVL_XP_FLAWLESS (15)          if no enemy damage taken AND >= ACC_LVL_FLAWLESS_MIN_KILLS (8)   // SKILL (user 40->15)
    + ACC_LVL_XP_NODOWN_MILESTONE (75)  if p.downs==0 and round is a milestone (10/15/20...)   // consistency
```

**Fast-clear (`speed_bonus`) — measured vs the spawn-limited floor (REWORKED 2026-07-21):** the old
linear par (`15 + 4×round`) was too tight early / too loose late ("fast clear is tough"). Now:
zombies can't be killed before they spawn, so the round's minimum possible clear time =
`level.zombie_total × spawn_delay`. `capture_round_zombie_total()` snapshots the count the instant
stock fires `zombie_total_set` (before the spawn loop decrements it); at award, `active = cycle −
ACC_LVL_ROUND_BREATHER (13s breather)`, `ratio = active / floor`. Full bonus at
`ratio ≤ ACC_LVL_ROUND_RATIO_FULL` (1.5×), zero at `≥ ACC_LVL_ROUND_RATIO_ZERO` (3.5×), linear
between. **Auto-adapts** to round, player count, and the map's custom spawn density (ai_limit 50,
spawn-delay ×0.85) — no per-round guessing. Boss/special rounds (no `zombie_total_set`) fall back to
0 speed bonus.

Flawless rides `on_leveling_player_damaged` (registered via `zm::register_player_damage_callback`,
always returns -1) which flags `acc_lvl_took_enemy_dmg` only on **axis-team** damage — so the
trench fall tax, Berzerker/PhD self-damage, etc. never break flawless (committing to risk is
not punished). A safe-corner hider or a carried player no longer collects the diver's award.

### 4c-bis. Kill XP — risk + skill (REWORKED 2026-07-21)

`on_zombie_killed`: base `ACC_LVL_XP_KILL` (2→1) + `ACC_LVL_XP_HS_KILL` (2) on a bullet
headshot (skill) + `ACC_LVL_XP_DEEP_KILL_LAYER` (1) × killer's trench layer (risk). Surge/drip
zombies now **pay** (surviving the trench threat is the risk) but are excluded from the
Flawless min-kills tally. Depth read from the maintained `attacker.acc_trench_layer` (no
`#using` cycle). Camp gating = **MODERATE** (a camper progresses slowly; LV10 still reachable
solo eventually).

### 4c-ter. Rewards beyond gating (user decision 2026-07-21: PURE GATING + LV10 prestige)

Levels grant **no power** (flat HP/damage explicitly rejected — double-dips the tiers, softens
the punishing map). The only added payoff is the **LV10 "Fully Augmented" capstone**: a distinct
toast + the bigger full-fireworks FX (`acc_levelup_max_fx` = `zombie/fx_aat_fireworks_zmb`) in
`level_up_feedback`. (A persistent LV10 aura is a possible future add — deferred for FX-lifecycle
simplicity.)

Award `xp` to every player in the game (survival is a team clear). `par` scales with round
so it stays fair as zombie counts grow. Camping past `par` → `speed_frac = 0` → base only.
(Alternative pace metric = zombies-per-second; par-time chosen for tunability and because
it needs no internal zombie-count plumbing. Noted for future.)

### 4e. Objective / elite XP (added 2026-07-22 — broaden the earn surface)

All wrappers in `_acc_leveling.gsc` (keep amounts local), all farm-guarded, sized by frequency+risk:

| Source | XP | Hook | Guard |
|---|---|---|---|
| Riot/Shielded elite kill | +10 | `_acc_elites::shielded_death_reward` | its `acc_no_shard_reward` early-return |
| Glitch Stalker kill | +12 | `_acc_boss_glitch::glitch_death_watch` (beside the shard) | its `acc_ldc`/`acc_no_shard_reward` early-return |
| Apothicon Fury kill | +30 | tagged `acc_is_fury` at spawn (`_acc_fury`), paid in `on_zombie_killed` | `!acc_no_shard_reward` |
| Reactor Surge (armer/crew) | +100 / +40 | `_acc_reactor::run_surge` success | armer survived-in-pit gate; crew must be alive+underground; 3-round cooldown |
| **Soul banked** (per soul) | **+1** | `_acc_abyss_doors::on_zombie_death_souls` (both `++` sites) | bounded by gate quotas |
| Paradise WIN | +250 | `_acc_paradise::win` survivor loop | once-per-run latch |
| Open a buyable door | +30 | entry `zone_door_trigger_wait` at the buy point | once-per-door (`d.acc_bought`) |

### 4d. Zombie kills — own callback in `_acc_leveling.gsc`

Register an **independent** `zm_spawner::register_zombie_death_event_callback` from
`init()` (additive; no edit to `_acc_points`). `self` = killed zombie, `attacker` = killer:

```gsc
if ( isdefined( attacker ) && isplayer( attacker ) )
    acc_leveling::grant_xp( attacker, ACC_LVL_XP_KILL, "kill" );   // ACC_LVL_XP_KILL = 2
```

Consider skipping the trivial trench surge/drip zombies (they already branch early in
`acc_points::on_zombie_death` :238) so trench XP isn't double-counted; decide in Phase 3.

### Starting constants (all `#define`, TUNE in dev)

| Const | Value | Source |
|---|---|---|
| `ACC_LVL_XP_STEP` | 150 | curve: `xp_to_next(l) = STEP*l` |
| `ACC_LVL_XP_BOSS` | 250 | per boss, all players |
| `ACC_LVL_XP_BRUTUS_KILLER` | 100 | optional, killer only (Ph4) |
| `ACC_LVL_XP_TRENCH_BASE` | 6 | ×layer, per trench interval |
| `ACC_LVL_XP_ROUND_BASE` | 25 | survive a round |
| `ACC_LVL_XP_ROUND_SPEED` | 50 | max fast-clear bonus |
| `ACC_LVL_ROUND_PAR_BASE` | 15 | par seconds baseline |
| `ACC_LVL_ROUND_PAR_PER` | 4 | par seconds per round |
| `ACC_LVL_XP_KILL` | 2 | per real zombie kill |

---

## 5. HUD — bottom-left `LV N` + XP bar

**Channel (no clientfield — all three CF pools are FULL):** the per-player controller
UI-model string bridge, same one `_acc_leaderboard.gsc` uses.

GSC side (in `_acc_leveling.gsc`):

- `#precache( "lui_menu_data", "accLevel" );`
- Push on connect, on `spawned_player`, and after every XP/level change:

```gsc
frac = ( player.acc_level >= 10 ? 1.0 : player.acc_xp / xp_to_next( player.acc_level ) );
player SetControllerUIModelValue( "accLevel", player.acc_level + "|" + frac );
```

This is per-player, **replicates to co-op peers** (the property the LB peer relay relies
on), costs **zero clientfield bits**, carries `lvl|frac` in one string, and stays pinned to
the receiving client under spectate (correct for a personal stat) — no
`CF_CALLBACK_ZERO_ON_NEW_ENT` respawn-staleness trap.

LUI side — new `CoD.AccLevel` widget in `ui/uieditor/menus/hud/acc_hud.lua`
(the additive overlay menu that already reads `accPapTier`/`accOcTier` the same way):

- **Read:** `Engine.CreateModel( Engine.GetModelForController( InstanceRef ), "accLevel" )`
  + `self:subscribeToModel( model, fn )` + an initial `Engine.GetModelValue` paint.
  Use **`CreateModel`, not `GetModel`** — the node may not exist before the first server
  write (the bug that killed the MULE/TURBO badges; note at `acc_hud.lua:~1014-1020`).
- **Parse `"3|0.45"`:** `string.find(s,"|",1,true)` → `string.sub` + `tonumber`
  (form already used in `ZMCursorHintNew.lua`).
- **Art frame (BUILT 2026-07-20, user-supplied):** the widget draws on `i_acc_level_frame`
  (512×128 PNG; repo `source_data/acc_perk_shaders/_images/`, GDT entry in
  `acc_perk_shaders.gdt` cloned from the implant cards, `image,` zone line, deploys via
  `tools/deploy_perk_shaders.ps1` BEFORE the linker). Two reserved zones, **measured from
  the PNG's alpha channel** (re-scan if the art ever changes): the bar window x140-489 /
  y52-75 is fully transparent — the teal fill element sits BEHIND the PNG and grows through
  it; the emblem dark-glass center (70.5, 63.5) hosts the level number (digits only, the
  "LEVEL" caption is baked into the art). Geometry in the widget is ratio-mapped from these
  master pixels (`ACC_LVL_*` constants), so resizing = change `ACC_LVL_W`.
- **Gain floater:** every grant flashes "+N XP" (amber, 1.4s alpha tween) right of the bar.
  Payload = `"lvl|frac|gain|seq"`; `seq` bumps per grant so equal amounts still re-fire the
  subscription; spawn/reopen pushes carry gain 0 (no stale replay).
- **Anchor (bottom-left):** `AetheriumPlayerInfo` rides −20 (its container offset), freeing
  the true corner; the chip sits x24-184 / y676-716 (TUNE in-game).
- **Instantiate:** three lines in `LUI.createMenu.acc_hud` next to the implant/badge rows
  (`acc_hud.lua:~1697`).

No `.csc` twin is needed — the value is a server-written controller model read purely in
LUI.

**Level-up feedback (BUILT 2026-07-21):** `level_up_feedback()` fires a HUD toast + a **3D world
sound** `PlaySoundAtPosition("acc_level_up", self.origin)` (positional broadcast so nearby players
hear it — WAV pending: `sound_assets/acc/fx/level_up.wav` + an `acc_level_up` row in
`sound/aliases/acc_audio.csv`) + a **celebration FX** `level thread acc_utility::play_fx_burst(
"acc_levelup_fx", self.origin+(0,0,52), 1.5 )`. `acc_levelup_fx` = the stock AAT **"Fireworks" burst**
(`zombie/fx_aat_fireworks_burst_zmb`) — a colorful firework pop (user wanted a reward beat, not an
ambient glow). Registered in `init()` + `#precache("fx",...)` + a `fx,` zone line (stock, ships free).
Swap the `level._effect` value to recolor (PaP swirl / powerup burst / body power-surge are stock
alternatives). Kept wait-free (grant_xp is on the round-listener's wait-free path): FX threaded off `level`.

---

## 6. Module structure & wiring

New file `scripts/zm/zm_abandoned_cyber_city/_acc_leveling.gsc`, namespace `acc_leveling`,
with `#insert scripts\shared\shared.gsh;` (for `IS_TRUE`).

```
function init()
{
    if ( !IS_TRUE( level.acc_dev ) ) return;   // whole feature dev-only; ship = inert. COPY of _acc_dev.gsc:79
    // everything below only runs in a dev build:
    callback::on_connect( &on_player_connect );                 // init fields + first HUD push
    zm_spawner::register_zombie_death_event_callback( &on_zombie_killed );
    level thread round_xp_listener();                           // acc_round_start/acc_round_end
}
```

Self-register hooks from inside `init()` (the `_acc_dev.gsc` pattern) so the shared
`acc_main::on_player_connect/on_player_spawned` fan-out stays clean and the system is truly
inert in ship. `is_active()` is a pure function (no init needed), safe to call from the
gates even when dev is off.

Orchestrator wiring in `_acc_main.gsc`:

- Add `#using scripts\zm\zm_abandoned_cyber_city\_acc_leveling;` to the `#using` block (≈:83).
- Add `acc_leveling::init();` in `acc_main::init()` **immediately before** `acc_dev::init();`
  (≈:340) — after all economy/boss/HUD modules are up, so it can read their state; `acc_dev`
  stays last.

**No new dvars, no new flags.** The only on/off is `level.acc_dev` (hardcode true/false in
`acc_resolve_dev_flags()` + rebuild). XP/curve values are `#define`s. Any temporary
diagnostic rides `IS_TRUE(level.acc_dev)` and is DELETED when done (never a `*_debug` dvar —
Gate 0c fails on those). If leveling is ever persisted/posted anywhere, it must skip when
`level.acc_dev || level.acc_god` (dev/god never post).

---

## 7. Files touched

**New**
- `scripts/zm/zm_abandoned_cyber_city/_acc_leveling.gsc` — the module (state, `grant_xp`,
  curve, `is_active`, HUD push, round listener, zombie-death cb, level-up feedback).
- `docs/45_leveling_system.md` — this spec.

**Modified**
- `scripts/zm/zm_abandoned_cyber_city/_acc_main.gsc` — `#using` + `acc_leveling::init();`.
- `scripts/zm/zm_abandoned_cyber_city/_acc_exo.gsc` — level gate + `#using`.
- `scripts/zm/zm_abandoned_cyber_city/_acc_overclocks.gsc` — level gate + `#using`.
- `scripts/zm/zm_abandoned_cyber_city/_acc_boss.gsc` — boss XP grant (+ optional Brutus killer).
- `scripts/zm/zm_abandoned_cyber_city/_acc_bus_trench.gsc` — trench dwell XP twin.
- `ui/uieditor/menus/hud/acc_hud.lua` — `CoD.AccLevel` widget + instantiation.
- `CHANGELOG.md` + companion docs (03/28/29/11/22, docs/README index).

No geometry / GDT / `.zone` changes → **`-GscOnly` build**, no LED bake.

---

## 8. Build & test plan (dev-gated — the hard part)

1. Arm: hardcode `level.acc_dev = true;` in `acc_resolve_dev_flags()`; rebuild
   `.\tools\build_map.ps1 -GscOnly` (sync first). Smoke-check `console_mp.log` for
   `out of space` / `Clientfield Mismatch` (we add no CF, so expect clean).
2. **HUD**: confirm bottom-left `LV 1` + empty bar appears on spawn; grant XP (kill zombies)
   and watch the bar fill and roll over to `LV 2`.
3. **Gate**: at LV1, press the Exo station / OC terminal for tier 2 → denied with the
   `requires Level 2` `hud_msg`, **no shards spent** (dev has unlimited shards, proving the
   gate blocks on level, not cost). Level up → tier 2 now buyable.
4. **XP sources**: kill Brutus (boss chunk), sit deep in a trench (dwell ticks), clear a
   round fast vs slow (speed bonus differs), farm kills (small trickle).
5. **Co-op** (mock party / real): each player has an independent level + own HUD; peers see
   correct values (controller-model relay).
6. Tune `#define`s until reaching LV10 over a run feels earned and objective-weighted.
7. **Before any publish**: restore `level.acc_dev = false;` (Gate 0 enforces). System ships
   fully OFF and inert.

Temporary dev diagnostics: gate on `IS_TRUE(level.acc_dev)`, DELETE when done.

---

## 9. Implementation phases

- **Phase 1 — core + HUD.** Module skeleton, state, `grant_xp`, curve, HUD push +
  `CoD.AccLevel` widget. Wire to `_acc_main`. Prove the bar fills / levels roll using ONE
  temporary XP source (zombie kills). No gates yet.
- **Phase 2 — gates.** `is_active()` + the two one-line gates (exo, overclock). Prove
  denial + unlock.
- **Phase 3 — XP economy.** Boss + trench + round-speed + zombie-kill grants. Balance the
  curve. Decide the surge-zombie double-count skip.
- **Phase 4 — polish.** Level-up SFX/feedback, optional Brutus-killer bonus, station/terminal
  hint cards showing `requires LV N`, docs + CHANGELOG, README index.

---

## 10. Constraints honored (why this shape)

- **Clientfield pools (toplayer/clientuimodel/scriptmover) are FULL** → controller
  UI-model string channel, zero new bits. (memories: `toplayer-clientfield-pool-full`,
  `scriptmover-clientfield-pool-full`, `weapon-usage-tracking-state`,
  `toplayer-spectate-stale-and-lb-peer-relay`.)
- **Dev = one compile-time flag, no console/launch levers** → whole module self-gates on
  `level.acc_dev`; ship line stays `false`; no new dvars/flags. (memories:
  `all-dev-features-ride-acc-dev-only`, `dev-mode-hardcoded-not-console`.)
- **Single grant chokepoint per ladder** → the gate fully controls acquisition and every
  downstream effect with no effect-site edits.
- **Additive death callback / global round notifies** → XP hooks add no edits to
  `_acc_points`/`_acc_main` orchestration beyond the one `init()` call.
- **HACKY-IS-GOOD**: the inverted `is_active()` (dev ON = gate ON, because the feature is
  dev-only for now) is the deliberate, documented lever — one flip to promote later.

---

## 11. Open questions / future

- **Promotion out of dev**: when shipped for real, flip `is_active()` to `true` (or a real
  condition) and remove the `init()` early-return — one file, two edits. Re-balance then.
- **Persistence via Transfer Vault (docs/37)**: currently per-run. Could carry level across
  runs later; out of scope now.
- **Leaderboard tie-in (docs/40/42)**: max level reached could be a posted stat; if so it
  MUST skip dev/god runs.
- **Round-speed metric**: par-time now; could switch to zombies-per-second pace if par-time
  feels wrong at extreme rounds.
- **Zombie-kill XP**: kept intentionally tiny; revisit whether it should exist at all after
  Phase 3 balancing.
