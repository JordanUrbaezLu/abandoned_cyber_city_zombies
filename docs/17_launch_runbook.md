# 17 — Launch Runbook (how to actually open the built map)

> **TL;DR:** Build in the Launcher with **Run unchecked**, make sure BO3's Steam
> **Launch Options are empty**, then double-click **`PLAY_NORMAL.bat`** — the ONLY
> play script (user 2026-07-15; PLAY_TEST_MAP / PLAY_GOD_MODE deleted) — or run
> `.\tools\run_game.ps1`. Dev/god are NOT launch flags: they're hardcoded in the
> build (`acc_resolve_dev_flags()`, docs/22). The single non-obvious launch
> requirement is the gametype token: **`+set_gametype zclassic`**, NOT
> `+set g_gametype zclassic`.

This map is a **split install** (Mod Tools in `...Black Ops III 455130`, game in
`...Black Ops III`). Getting the built fastfile to actually open as a playable
zombies match took solving four separate, independent gotchas. They are all
fixed in the repo tooling now; this doc records *why*, so a regression is
diagnosable in minutes instead of an afternoon.

## The launch gotchas (all solved)

| # | Symptom | Cause | Fix (already in repo) |
|---|---------|-------|------------------------|
| 1 | Exe launches, **nothing opens**, no crash dump/log | Split install: linker writes the `.ff` into the **tools** `usermaps`, but the game loads `usermaps` from the **game** folder | `sync_to_modtools.ps1` creates a directory **junction** `<game>\usermaps -> <tools>\usermaps` |
| 2 | **"Steam must be running to play this game"** popup, then exits | BO3 Steam DRM rejects a raw-exe launch | `steam_appid.txt` = `311210` next to `BlackOps3.exe` **and** launch **through Steam** (`steam://run/311210//<args>`), not the raw exe |
| 3 | **Black screen**, log ends `Com_ERROR: Script file not found: 'scripts/zm/gametypes/tdm.gsc'` | Gametype resolves to the MP default **tdm**; a plain `+set g_gametype zclassic` is **reset to the session default by the engine** (`callbacks_shared.gsc`) and never sticks | Pass the **engine command** `+set_gametype zclassic` (what the Mod Tools Launcher uses). It sticks. |
| 4 | Same `tdm.gsc` black screen even after #3 | Steam **appends** the game's **Launch Options** to the `steam://run//<args>`, producing a **doubled command line** that re-corrupts the gametype | Keep Steam **Launch Options EMPTY**; use exactly ONE arg source |
| 5 | Launch **silently ignored** (no process, no log write) right after a game **crash** | Steam's stale launch-handler jam (see CLAUDE.md): after a CTD + rapid retries Steam drops `steam://run` requests | Fully restart Steam (`steam.exe -shutdown`, wait for exit, relaunch, wait for login) — then see #6 |
| 6 | Launch still silently ignored **after a Steam restart** — `console_log.txt` (Steam's `logs\` folder) shows `LaunchApp waiting for user response to ShowGameArgs` | After a Steam restart, **EVERY** `steam://run//<args>` launch pops an **in-Steam launch-arguments confirmation dialog** and waits for a click (verified live 2026-07-17: re-prompted at 20:48 after a 20:35 approval); headless/scripted launches hang on it, and a follow-up `-applaunch` queues behind the pending action. Pre-restart launches were silent, so some approval state persists per Steam session until a restart clears it | **Click OK/Allow in the Steam window** (a human step — scripts can't dismiss it; tick "don't ask again" if offered). The queued launch then fires with the right args. Agents: after launching headless, if the process doesn't appear in ~30s, check `Steam\logs\console_log.txt` (grep `311210`) and ask the user to click — do NOT stack more launch requests |
| 7 | Map loads into an on-screen **"UI Error \<code\>"** box (e.g. 44429) after a launch that overlapped a build | The game read a **half-written `.ff`** while the linker was still packing it (live-hit 2026-07-25: launch 3:31:44 vs `.ff` finished 3:34:07) — torn Lua chunks surface as a UI Error; NOT a code bug | **Both launchers now refuse to start while `linker_modtools`/`cod2map64`/`radiant_modtools` are running** (`PLAY_NORMAL.bat` + `tools/run_game.ps1` tasklist guard). If you ever see it anyway: quit fully, wait for the build, relaunch |

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
steam://run/311210//+set fs_game zm_abandoned_cyber_city +set_gametype zclassic +devmap zm_abandoned_cyber_city +set developer 1 +set logfile 1 +set g_log games_mp.log +set g_logSync 1
```

Equivalently: `PLAY_NORMAL.bat` (double-click) or `.\tools\run_game.ps1`. Every
arg (`fs_game` / `set_gametype` / `devmap` / `developer` / `logfile` / `g_log` /
`g_logSync`) is an ENGINE arg required to load the map — there are no gameplay
toggles on the command line. `g_log games_mp.log` + `g_logSync 1` enable the
engine GAME log where the `[ACCDIAG]` 30s diagnostics census lands
(`_acc_diag.gsc`, file-only); `logfile 1` covers `console_mp.log` separately.

**DEV / GOD ARE BUILD STATE, NOT LAUNCH FLAGS** (user 2026-07-15 "this is the
way we test in this repo... we don't use launch flags"; ONE-flag design user
2026-06-22). `acc_resolve_dev_flags()` (first thing in `main()`) owns the two
booleans `level.acc_dev` / `level.acc_god`; every module gates on
`IS_TRUE( level.acc_dev )` — no per-feature dev flags, dev is all-or-nothing.
- **Test session:** hardcode `level.acc_dev = true;` (and `level.acc_god = true;`
  when wanted) in that function + rebuild (`-GscOnly`). `prep_release.ps1` FAILS
  on those lines, so a publish build can't ship them.
- **Publish:** restore `level.acc_dev = false;` / `level.acc_god = false;` +
  rebuild (ship-safe for every Workshop subscriber). There is no dvar fallback —
  the `getdvarint` resolution was removed 2026-07-16, and `prep_release.ps1`
  Gate 0 FAILS if a dvar read reappears.
- **Dev sandbox** (`level.acc_dev`) = unlimited money, 25 starting Data Shards,
  topped-up Mega Bottles, the full 13-item Plaza scatter, all perk slots, and
  the dev HUDs + teleport / round-skip / open-doors console commands. Bosses
  keep their real round cadences; no auto power-on — flip the Bus Station switch
  yourself (`_acc_boss.gsc`, `zm_abandoned_cyber_city.gsc::acc_hardcoded_dev`).
- **God** (`level.acc_god`) = demigod: real damage lands but HP floors at 1;
  per-hit effects still fire (`_acc_elites::on_player_damaged`). Independent of
  dev.
- `run_game.ps1` still accepts `-NoBoss` / `-NoDev` / `-ClosedMap` /
  `-NoVarDebug` / `-NoAmbient` / `-NoLockdown`, but they **no longer affect the
  launch at all** (kept only for call compatibility).

(The old `acc_test_boss` manual test flag + `_acc_boss.gsc::test_boss_loop`
were removed 2026-07-16 along with all per-feature debug/test dvars — dev tops
up Mega Bottles directly and Brutus follows his real round-5 power cadence.)

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
`set acc_open_doors 1` in the dev console: it opens all 13 buyable doors **and both
PaP blocker brushes** (`acc_pap_block_server` / `acc_pap_block_roof`).
The randomizer now opens **both** PaP blocker brushes every run (the per-run
random path-block was removed 2026-06-22 — `blocked_side` is ignored), so neither
is ever left solid; they are bare `script_brushmodel`s (no door trigger), which is
why the door pass hides + unsolids them explicitly
(`_acc_dev.gsc::dev_open_all_doors`). (reconciled to code 2026-07-11)

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
