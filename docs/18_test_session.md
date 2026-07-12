# 18 — Test Session Guide (dev sandbox)

> **How dev mode works (one flag, hardcoded — not a console):** everything below
> is gated on the single **`acc_dev`** dvar, resolved ONCE in
> `zm_abandoned_cyber_city.gsc::acc_resolve_dev_flags()` into the global bool
> `level.acc_dev` (default `0` = ship-safe **normal play**). The dev launch script
> passes `+set acc_dev 1`; that one flag then drives the legacy sub-dvars
> (`acc_open_map`, `acc_glitch_test`, …) so no per-feature
> toggle is needed. **Never "set dvar X in the console" to test a feature** —
> add a `IS_TRUE( level.acc_dev )` branch instead (design: docs/22). During an
> active test cycle a hardcode line `level.acc_dev = true;` (and `level.acc_god = true;`)
> is enabled in that function — `prep_release.ps1` FAILS on those lines, so they
> get commented out before any Workshop ship.

## Launch

- **`PLAY_TEST_MAP.bat`** (repo root) — the dev sandbox (`+set acc_dev 1`).
- **`PLAY_GOD_MODE.bat`** — `+set acc_god 1`: a SEPARATE test flag from `acc_dev`.
  Real perks / economy / progression / closed map (normal play), but players are
  **demigod** (damage lands, health floors at 1 HP — `_acc_elites::on_player_damaged`).
- **`PLAY_NORMAL.bat`** — plain ship behaviour, no flags.

Or run `.\tools\run_game.ps1`. The one load-bearing arg is
**`+set_gametype zclassic`** (already in all launchers) — see
[docs/17_launch_runbook.md](17_launch_runbook.md) for why `g_gametype` doesn't work.

**If the game doesn't open** (Steam's launch handler can jam after force-quits):
fully restart Steam (`Steam → exit`, reopen), then launch again. A normal load
climbs to ~4.7 GB over ~40 s.

## What dev mode (`acc_dev 1`) gives you

| Feature | Behaviour |
|---|---|
| **Unlimited money** | Points top back up to 1,000,000 whenever they drop below 100,000. Buying any zone door / wallbuy / perk is effectively free. |
| **Doors** | NOT auto-opened. Dev runs the **same** per-round 4-of-10 perk-alcove rotation and the same buyable zone doors as normal play (user 2026-07-07: "dev and non-dev should work the same") — unlimited money just makes buying them trivial. `set acc_perk_doors_all_open 1` is a manual escape hatch in either mode. |
| **Data Shards** | **25 granted ONCE at spawn**, then the real trench economy runs (spend/earn like normal play — the old per-second 999 pin is gone, so you can actually test a shard SPEND). |
| **Power** | NOT auto-on — flip the Bus Station (corp) power switch yourself (perks/PaP/traps gate on it), same as normal play. (`set acc_auto_power 1` is a dormant manual shortcut.) |
| **Bosses** | The full multi-boss roster runs on **per-module dev cadences** (see below), not one fixed test boss. |
| **Mega Bottles** | Topped up to **25** in dev regardless of any boss kill, so perk Mega-upgrades are testable without farming a boss. |
| **Status banner** | None — the on-screen green `[ACC] DEV BUILD LIVE …` banner was **removed 2026-07-10** (user asked to kill the green "DEV MODE ACTIVE" UI). The money/shards/bottle top-ups still run silently; the dev-live cue is now points jumping to 1,000,000 at spawn. |
| **Diagnostics** | Dev now runs with a **clean screen** (user 2026-07-10): it does NOT auto-enable the hudelem-pool logger or the weapon-variant swap readout. Each rides only its own opt-in dvar (default 0) — `set acc_hudelem_debug 1` / `set acc_variants_debug 1` to turn one on. Door/boss debug stays off the screen (log only). |
| **Zombie speed** | Two-phase natural-gait curve (see below). |

### Boss dev cadences (per module)

- **Phantom** (display name `PHANTOM`) — normal first round 10, then the every-9 shared roster
  (legacy fallback every 10); dev bypasses the master gate and owes Phantoms on the
  dev cadence, first spawn from round 4 (dev fallback: every 4; the every-9 shared
  roster from round 9 takes over once published) (`_acc_boss_phantom.gsc`).
- **Glitch Stalker** — dev spawns from round 2 (`acc_glitch_test`, `_acc_boss_glitch.gsc`).
- **Avogadro** (cyberhacker) — dev runs a repeating test spawn (`_acc_boss_avogadro.gsc`).
- **Rogue/Civil Protector** (r20 hostile) — this module also hosts the shared boss
  director; dev cadence = round 3, every 3 (`_acc_civil_protector.gsc`).
- **Panzer** (mechz) — dev keeps one alive from round 2 (`_acc_boss_panzer.gsc`).
- **Brutus** — follows his real round-5 power cadence even in dev (`acc_test_boss` stays off).

In normal play, bosses come as a mini-boss first at round 10, then full boss
rounds every 9 from round 9 (r9=1, r18=2, r27=3), types dealt from a no-duplicate
shuffled deck (`level.acc_boss_roster_fn`).

### Zombie speed curve

Natural-gait, two-phase (`_acc_zombie_speed.gsc`) — never below natural cadence
(a slowed sprint reads as slow-mo, user-rejected):

- **Rounds 1 – 14: JOG gait**, playback rate creeping up each round
  (start 101.3%, +0.65%/round). The jog's baked ground speed is the "slow start".
- **Round 15: SPRINT gait** at rate 1.0 (base-game max speed) — a deliberate
  "they start sprinting now" step up. (The whole curve was shifted 2 rounds
  earlier on 2026-07-09; was round 17.)
- **Round 16+: sprint gait, rate 1.0 + 0.5%/round** (R20 = 1.025×, R25 = 1.05×,
  R30 = 1.075×; unbounded, no upper clamp).

Live-tune dvars (read per spawn): `acc_zspeed_sprint_round` (15),
`acc_zspeed_jog_start_pct` (101.3), `acc_zspeed_jog_step_pct` (0.65),
`acc_zspeed_sprint_start_pct` (100), `acc_zspeed_sprint_step_pct` (0.5).
(Zombies physically in the trench / Paradise plaza also get per-layer speed +
health scaling on top — see docs/08_enemies.md.)

## Test checklist

1. **Spawn** — confirm points jump to 1,000,000 (the dev-live cue; the old on-screen
   `[ACC] DEV BUILD LIVE` banner was removed 2026-07-10). If money never tops up, the
   dev sandbox didn't thread — tell me. `[acc]` init breadcrumbs land in `console_mp.log`.
2. **Move freely** — buy the zone doors (money is unlimited) and walk every zone:
   Market, Alley, Corp Plaza, Vault, Roof, Lab, plus the Armory, the Exchange, and
   the underground Abyss layers → Paradise plaza. Note any spot where geometry blocks you.
3. **Perks (all 10)** — buy every perk machine (Electric Cherry is the real 10th);
   confirm each effect (flip the power switch first). Note the Lab alcoves only
   expose 4 of the 10 machines per round (the rotation).
4. **Guns** — weapons are **box-only** here: spam the **Mystery Box** (Apex +
   Skye ports + elemental bows in the pool); confirm they fire. Buy any wallbuys too.
5. **Pack-a-Punch** — PaP a gun (power on); confirm T1 damage, T2 `_up` transform, T3 max.
6. **Perk upgrades** — dev tops you to 25 Mega Bottles; at a perk machine you own,
   hold for the "Hold ✋ for Mega upgrade" prompt → upgrade. Test several
   (Jug→Ultimate Tank, Stamin-Up→The Flash, Deadshot→American Sniper, …).
7. **Bosses** — let the dev cadences run (Glitch from ~round 2, Panzer from round 2,
   Protector director round 3 / every 3, Phantom on its dev cadence); confirm each
   spawns, moves, attacks, and dies, and drops its reward.
8. **Data Shards / Overclocks** — you start with 25 shards. Live shard spends: buy
   extra perk slots at the **Neural Expansion Bay** perk-slot vendor, and roll/re-roll
   Overclocks at the **Overclock terminal** (`p7_zm_sta_dragon_network_data_terminal`).
   Confirm a SPEND actually deducts (the real economy is live in dev). NOTE: the
   **Cyberware skill tree is disabled** — its kiosk isn't spawned unless `acc_cyberware_on 1`
   is set (dev never sets it), so the Overclock terminal is the sole weapon-upgrade path.
9. **Zombie speed** — early rounds jog (creeping faster); the wave breaks into a
   full sprint at **round 15**, then inches up after. Optionally `set acc_zspeed_jog_step_pct <n>`
   and re-check the feel.

## Reporting back

For anything broken, note: **which system**, **what you did**, **what happened**
(or didn't). Examples: "Speed Cola upgrade did nothing", "box gave a broken gun",
"can't reach the Lab — wall at X", "shards HUD not showing". When you quit, the
console log (`<game>\console_mp.log`) captures `[acc]` breadcrumbs + any runtime
error for me to cross-check.
