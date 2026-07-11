# 17 — Launch Runbook (how to actually open the built map)

> **TL;DR:** Build in the Launcher with **Run unchecked**, make sure BO3's Steam
> **Launch Options are empty**, then double-click **`PLAY_TEST_MAP.bat`** (or run
> `.\tools\run_game.ps1`). The single non-obvious requirement is the gametype
> token: **`+set_gametype zclassic`**, NOT `+set g_gametype zclassic`.

This map is a **split install** (Mod Tools in `...Black Ops III 455130`, game in
`...Black Ops III`). Getting the built fastfile to actually open as a playable
zombies match took solving four separate, independent gotchas. They are all
fixed in the repo tooling now; this doc records *why*, so a regression is
diagnosable in minutes instead of an afternoon.

## The four gotchas (all solved)

| # | Symptom | Cause | Fix (already in repo) |
|---|---------|-------|------------------------|
| 1 | Exe launches, **nothing opens**, no crash dump/log | Split install: linker writes the `.ff` into the **tools** `usermaps`, but the game loads `usermaps` from the **game** folder | `sync_to_modtools.ps1` creates a directory **junction** `<game>\usermaps -> <tools>\usermaps` |
| 2 | **"Steam must be running to play this game"** popup, then exits | BO3 Steam DRM rejects a raw-exe launch | `steam_appid.txt` = `311210` next to `BlackOps3.exe` **and** launch **through Steam** (`steam://run/311210//<args>`), not the raw exe |
| 3 | **Black screen**, log ends `Com_ERROR: Script file not found: 'scripts/zm/gametypes/tdm.gsc'` | Gametype resolves to the MP default **tdm**; a plain `+set g_gametype zclassic` is **reset to the session default by the engine** (`callbacks_shared.gsc`) and never sticks | Pass the **engine command** `+set_gametype zclassic` (what the Mod Tools Launcher uses). It sticks. |
| 4 | Same `tdm.gsc` black screen even after #3 | Steam **appends** the game's **Launch Options** to the `steam://run//<args>`, producing a **doubled command line** that re-corrupts the gametype | Keep Steam **Launch Options EMPTY**; use exactly ONE arg source |

## The gametype detail (the subtle one — gotcha #3)

The engine builds the gametype script path as `scripts/<session>/gametypes/<NAME>.gsc`:
- `<session>` (`zm` vs `mp`) is the **engine session mode**.
- `<NAME>` is the value of the **`g_gametype`** dvar.

`g_gametype` is **reset to `level._gametype_default`** during init
(`callbacks_shared.gsc` ~line 1004): default is `zclassic` for a ZM session,
`tdm` for MP. So `+set g_gametype zclassic` on the command line is overwritten
before the gametype script loads → it looks for the missing `tdm.gsc` → fatal.

The Mod Tools Launcher (`OnRunMapOrMod`) doesn't use `g_gametype` — it launches
`BlackOps3.exe +set fs_game <name> +devmap <map>` plus enabled launcher dvars,
and the gametype is applied through the engine command **`set_gametype`**. So on
the command line we pass **`+set_gametype zclassic`** (before `+devmap`) and it
holds. Verified 2026-06-13: `+set_gametype zclassic` → clean load to ~4.7 GB, no
`Com_ERROR`; `+set g_gametype zclassic` (or omitted) → `tdm.gsc` black screen.

## Canonical launch (copy-paste)

```
steam://run/311210//+set fs_game zm_abandoned_cyber_city +set_gametype zclassic +devmap zm_abandoned_cyber_city +set developer 1 +set logfile 1 +set g_log games_mp.log +set g_logSync 1 +set acc_dev 1
```

Equivalently: `PLAY_TEST_MAP.bat` (double-click) or `.\tools\run_game.ps1`.
The engine args before `+set acc_dev 1` (`fs_game` / `set_gametype` / `devmap` /
`developer` / `logfile` / `g_log` / `g_logSync`) are required to load the map, not
dev toggles. `g_log games_mp.log` + `g_logSync 1` enable the engine GAME log where
the `[ACCDIAG]` 30s diagnostics census lands (`_acc_diag.gsc`, file-only); `logfile 1`
covers `console_mp.log` separately.

**ONE dev flag** (user 2026-06-22). `+set acc_dev 1` is the ENTIRE dev switch —
`acc_resolve_dev_flags()` (first thing in `main()`) resolves it once into
`level.acc_dev` and drives every legacy sub-dvar off it. There are **no
per-feature dev flags**; dev is all-or-nothing by design.
- `acc_dev 1` — the full hardcoded sandbox: unlimited money, 25 starting Data
  Shards, topped-up Mega Bottles, all test bosses (Brutus / Glitch / Phantom),
  all perk slots, the weapon-variant debug readout, and the dev HUDs +
  teleport / round-skip / open-doors console commands. **No god mode and no
  auto power-on** — you take regular damage and flip the Bus Station power
  switch yourself (`_acc_boss.gsc`, `zm_abandoned_cyber_city.gsc::acc_hardcoded_dev`).
  `acc_dev 0` (or omit) = clean normal play.
- `run_game.ps1` still accepts `-NoBoss` / `-ClosedMap` / `-NoVarDebug` /
  `-NoAmbient` / `-NoLockdown`, but they **no longer affect the launch** (kept
  only for call compatibility). Only `-NoDev` is functional — it drops
  `+set acc_dev 1` for a clean consumer game.

**Separate manual test flags** (not part of the canonical launch, pass them
yourself if you want them):
- `acc_god 1` — invulnerability (demigod: real damage lands but HP floors at 1;
  effects still fire). Independent of `acc_dev`, which deliberately has NO god.
  The standalone `PLAY_GOD_MODE.bat` passes it.
- `acc_test_boss 1` — a **low-HP test Brutus every round from round 2**, drops
  10 Mega Bottles, so the Mega-Bottle → perk-upgrade loop is testable without
  surviving to the real boss rounds (`_acc_boss.gsc::test_boss_loop`, lines
  89-105). NOT triggered by dev — in the dev sandbox Brutus follows his real
  round-5 power cadence.

**Zombie-speed tuning** — in-game console (`~`, enabled by `+set developer 1`):
the speed curve is live-tunable, e.g. `acc_zspeed_sprint_round 12` (break into
sprint earlier than the default **15**) / `acc_zspeed_jog_step_pct 1.0` (faster
early ramp) / `acc_zspeed_sprint_step_pct 1.0`. Read per spawn AND re-asserted on
live zombies, so changes show within a couple seconds. Full list in
docs/22_flags_reference.md.

**Open-all-map** (dev console): doors are now **always buyable, never
auto-opened** — dev simply has unlimited money so buying is trivial
(`acc_fix_zone_doors` makes the `.map`-written triggers player-usable; the old
`acc_hardcoded_open_map()` auto-unlock is no longer called —
`zm_abandoned_cyber_city.gsc:262-267`). To walk the whole map instantly, type
`set acc_open_doors 1` in the dev console: it opens all 8 buyable doors **and both
per-run PaP blocker brushes** (`acc_pap_block_server` / `acc_pap_block_roof`).
The randomizer leaves one PaP blocker solid each run; it is a bare
`script_brushmodel` (no door trigger), so it is the lone barrier the door pass
misses unless opened explicitly (`_acc_dev.gsc::dev_open_all_doors`).

## Do NOT use the Mod Tools Launcher's "Run" checkbox

On this split install it launches the raw exe (DRM popup / silent exit). Build
with **Run unchecked**, then launch via the canonical method above.

## If it black-screens again — fast triage

1. Read `<game>\console_mp.log` (written with `+set logfile 1`). The **last**
   lines are the fatal error — ignore the wall of "Could not find material/fx"
   (normal usermap asset noise).
2. `Com_ERROR ... tdm.gsc` → gametype regressed: confirm `+set_gametype zclassic`
   is present **and** Steam Launch Options are empty (no doubled command line —
   check the `Command line:` echo at the top of the log).
3. A GSC `script runtime error` banner naming an `_acc_*` file → our code; fix
   the script (this is AFTER gametype resolution, so it means we got further).
4. `nothing opens` / DRM popup → junction or `steam_appid.txt` missing; re-run
   `.\tools\sync_to_modtools.ps1`.
