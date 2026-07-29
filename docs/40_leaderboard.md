# 40 — Leaderboard (Plaza terminal + game records)

**Status: ✅ BUILT + LIVE (2026-07-11).** Every finished game posts **session id +
the (up to 4) player gamertags + round reached** to our Cloudflare Worker + D1
board; a **network-data terminal in the Plaza** (by spawn — user: "players can
view as soon as they load into the map") shows the global top 10 on interact.
**The as-built system is documented in "✅ SHIPPED" right below; everything after
that is the research/iteration history that got us here.**

## ➕ UPDATE 2026-07-25 — AGENT REUSE: the cmd-window flash no longer opens on retries

**The complaint (user: "players are commenting they are scared… without that command prompt
opening… a quick retry so cmd doesn't need to open every time they retry. Don't remove the
leaderboards").** The ONLY thing that shows a console is the single `os.execute` that launches
the background curl agent (every record afterward is pure trigger-file io). The in-game
`spawn_agent()` had **no reuse check**, so `boot_agents → boot_agent_verified` spawned a *fresh*
agent — and thus flashed a cmd window — at **every match start**, and up to **3×** when the
early-boot `acc_lb_boot_trace` confirmation was flaky. Because `BlackOps3.exe` (and the agent
`.bat` it spawned) **persist across `map_restart`** within one Steam app session, every
death→retry re-flashed a pipeline a live agent already covered.

**What was ruled out (exhaustive 6-angle research + adversarial verification, 2026-07-25):**

- **A windowless `os.execute` is impossible.** HavokScript `os.execute` == C `system()` ==
  `cmd.exe /c`; BlackOps3 is a GUI-subsystem process with no console, so Windows allocates a new
  console/conhost window *before the command even parses*. The flash is the `cmd` wrapper, not the
  child — no host swap (wscript/cscript/mshta/rundll32/wmic/`schtasks /run`) and no prefix
  (`start /b`, `/min`) removes it. This closes the entire "hide the exec" idea space.
- **No non-`os.execute` network primitive is shippable.** Native LUI HTTP does not exist on retail
  (T7Overcharged adds it via a non-shippable injected DLL); engine DemonWare/leaderboard calls hit
  Activision, not our Worker; `io.popen` is the same console + hangs; Steam Cloud doesn't sync
  `players\` in real time. **A pre-registered Scheduled Task / Startup autorun is REFUTED** — a game
  silently registering a hidden task that `curl`s a remote URL forever is a textbook
  malware-persistence signature (AV/SmartScreen bait), a *worse* "is this map hacking me?" than the
  flash. **Deferring the one spawn to `end_game` is also refuted** — the scoreboard is still
  exclusive-fullscreen so it still yanks there, and it strands a first-game Leave's queued POST.

**The fix (the "quick retry", realized as AGENT REUSE — pure io, no `os.execute`, zero flash):**
port the launcher pre-spawn's proven ping/pong handshake (`spawn_lb_agent.tpl.ps1`) into the
in-game path, GSC-driven so each chunk open stays synchronous in `createMenu` (the 2026-07-12
UITimer-freeze rule holds):

1. `acc_lb_boot_chunk.lua` — two new **pure-io modes**: `ping` (os.remove any stale
   `acc_lb_pong.txt`, then write `acc_lb_ping.txt`) and `pongcheck` (read the agent's
   `acc_lb_pong.txt` reply → Exec `acc_lb_boot_trace "alive"/"dead"`, then consume the pong). Both
   early-return **before** `spawn_agent`, so they never `os.execute`.
2. `_acc_leaderboard.gsc::agent_is_alive()` — writes the ping, waits ~1.6s for the agent's ~1s
   poll loop to answer (it answers at the top of the loop, before any curl), reads the pong.
3. `boot_agent_verified()` — **reuses first** (returns true with no spawn if an agent answers) and,
   after each spawn open, **confirms via ping/pong before re-firing** a redundant `os.execute`.
   This strengthens the 2026-07-16 verified-spawn outage fix (ping/pong is a more authoritative
   confirmation than the early-boot trace it distrusts) rather than weakening it.

**Net:** exactly **one** flash on the first game of a fresh app session (partly masked by load-in);
**zero** on every death→retry→restart thereafter — so the existing pause-menu **Restart Level** is
already a flash-free "quick retry" (no new button needed). Fallback on any handshake hiccup = the
old spawn behavior, so it **can never be worse than today**. Dev-only-storage gate, per-lobby
ladders, session-upsert and peer relay are all untouched (only the *spawn decision* is gated).

**Verification:** compiles + links clean (fresh `.ff` 2026-07-25; the linker emitted the
`_acc_leaderboard.gsc.gdb` = the GSC compiled, and the boot chunk regen'd to 8685 bytecode bytes).
**Needs a human in-game Steam-launch test before publish** — this pipeline is not headless-verifiable
(a scripted launch parks at the "Press ENTER to Start" splash, which is exactly why a prior in-game
ping/pong attempt was shelved as *unverifiable*, NOT as broken). Test: play game 1 (expect one flash
at spawn-in), die + retry 3× in the SAME app session → expect **zero** further cmd windows, and
confirm the board still fetches/records every retry (`players\acc_lb_boot_log.txt` shows an
`pongcheck alive` line and no new `acc_lb_agent_*.bat`). Memory: [[retail-lui-io-os-persistence-and-http]].

### RETRY ON DEATH + display-mode tip (built 2026-07-25, user "many tower maps allow a restart map option — follow that pattern")

> **v2 SUPERSEDES the v1 prompt below — see "GAME-OVER DECISION SCREEN (v2)" next section.**
> v1's mechanic (melee hold → `map_restart(true)`, proven in-game) carried over; its UI
> (`IPrintLnBold` + `acc_ui` card) did not.

- **`offer_retry_on_death()` / `retry_do_restart()`** (v1) — on a game-over wipe, after the record lands
  (~3s) and the stock survived/scoreboard is up, every player is offered an instant in-place restart:
  *"Hold [Melee] to RESTART this map instantly, or do nothing to return to the menu."* Any player
  completing a ~1.2s hold within a 12s window (safely under the 15s stock `zombie_intermission_time`)
  calls the **stock `map_restart( true )` builtin** — the same restart-on-wipe call stock makes at
  `_zm.gsc:6197/6245` (gated there behind a dev dvar in a `/# #/` block; tower/challenge maps ship it
  enabled). It is an ENGINE BUILTIN (called bare across four stock files, no `function map_restart`
  definition, no `#using`). Paired with the AGENT REUSE fix above the restart is **flash-free** (the
  persistent agent is reused). The pause-menu "Restart Level"
  (`AetheriumStartMenu.lua` → `AccLbFlushThen` → `map_restart`) is now flash-free for free too.
  Live-disable: `acc_retry_on_death 0`. Human-tested 2026-07-25: the hold + `map_restart(true)` work
  as expected during the game-over/spectate state ("It works as expected but the UI is the problem").

### GAME-OVER DECISION SCREEN (v2, built 2026-07-25 — user screenshot of a tower map's death menu: "Have the aetherium leaderboards show with options when you die… They can decide to end game or restart map")

The v1 text prompt is replaced by a full Aetherium death screen (`acc_gameover.lua` + the rewritten
`offer_retry_on_death()` in `_acc_leaderboard.gsc`), and the game now **waits for a decision instead of
auto-dumping to the BO3 lobby**:

- **Backdrop** (LUI menu `acc_gameover`, opened per player via `OpenLUIMenu`; v3 shifts the whole
  composition left by `X_OFF=-140` so the pause-menu button column at x868+ stays clear): full-screen
  dark glass, **YOU DIED** header + "NEURAL LINK SEVERED" sub-line, **YOU SURVIVED N ROUNDS**, a squad
  stats panel in the board's visual language (PLAYER | SCORE | KILLS | DOWNS | REVIVES | HEADSHOTS),
  a **TIME SURVIVED** tile (`H:MM:SS`), a teal **RUN SAVED** chip when any record lane stored this run
  (`level.acc_go_recorded`, latched in `publish_and_open_rec`), a "choose in the menu / [ESC] reopens"
  hint, and the 60s auto-END-GAME countdown footer.
- **The choice = the real pause menu (v3**, user: "make it a menu like when you pause a game you can
  go up and down from controller" — the v2 hold-melee/hold-aim gestures are GONE**)**: GSC re-enables
  the ingame menu (`SetMatchFlag("disableIngameMenu", 0)` — stock sets it 1 at end_game `_zm.gsc:6043`,
  and that flag being the ONLY gate is the proof the menu works during intermission), sets
  `acc_go_active=1`, and force-opens `StartMenu_Main` on every player (`OpenMenu` builtin,
  `_zm.gsc:636`). `AetheriumStartMenu.lua`'s game-over mode (dvar-gated at build) then shows exactly
  TWO native up/down entries — **Restart Map** (the menu's proven flash-free
  `AccLbFlushThen → Engine.Exec map_restart` lane; the extra flush is dedup-safe, the Worker upserts
  by session) and **End Game** (the proven Leave Game disconnect lane) — retitles to "Game Over",
  thins the DarkOverlay to 0.35 so the backdrop shows through, hides the pause-only side panels
  (implants/objective/perks/small-buttons) and moves initial focus onto the two-entry list. ESC/B
  closes it like any pause menu; the backdrop hint points the way back in. GSC reads NO buttons in v3.
- **Flow control (all script-side stock levers, VERIFIED vs `_zm.gsc`)**: on the `end_game` notify the
  handler synchronously sets `level._supress_survived_screen` (stock skips building its GAME OVER text,
  `:6057`, which it creates only after a `wait 0.1`, `:6035`) and stretches
  `level.zombie_vars["zombie_intermission_time"]` to 120 (read AT stock's exit wait `:6208`, so stock's
  `ExitLevel` is parked behind our window); after the menu opens we release stock's forced scoreboard
  with `LUINotifyEvent(&"force_scoreboard", 1, 0)` (stock's own release call, `:6244`).
- **Timeout**: both real choices act from the menu itself (`map_restart` / `disconnect` tear the VM
  down); GSC only runs a 60s countdown (`gameover_countdown`, mirrored to the backdrop on
  `acc_go_exit`) → `ExitLevel(false)` (stock's terminal call `:6249`). Solo note: an open menu may
  pause the server and freeze the countdown — by design (in the menu = deciding, not AFK).
- **Transport (v2.1 — the v2 controller-UI-model feed FAILED live 2026-07-25)**: the per-controller
  **Server UIModel pool is FULL** (stock + `accLbR*`/`accBoss*`/`accLevel`) — every new `accGo*` create
  threw `SetControllerUIModelValue: max number of Server UIModels` (a *recoverable* exception: the thread
  survives, so ship builds fail silently; the cap counts CREATES, precache reserves nothing; memory
  `controller-uimodel-pool-full`). v2.1 is budget-neutral:
  - **Squad stats need no transport**: stock replicates `PlayerList.<i>.playerName/.playerScore/.clientNum`
    to every machine, and `Engine.GetScoreboardColumnForClient(clientNum, 1/2/3/4)` =
    kills/downs/revives/headshots client-side — the exact AetheriumScoreboard.lua data path. Round =
    `gameScore.roundsPlayed` model.
  - **Dynamics ride dvars** (`acc_go_info` "round|H:MM:SS|rec", `acc_go_exit` countdown, plus the
    `acc_go_active` menu-mode flag) polled by ONE UITimer (150ms, close-on-menu-close hygiene) via the
    StartMenu's resilient try-list read. Host-side only: co-op **peers get the backdrop with client-side
    stats but the NORMAL pause list** (Leave Game works there; restarting is the host's call).
    Stale-dvar scrub at init (dvars persist across `map_restart` — a leftover `acc_go_active` would
    turn the next game's mid-run pause menu into the two-button list).
- **`gameover_failsafe()` watchdog** (v2.1, after the live "game can't end" hang): independent thread —
  if no decision landed 90s after `end_game` (main flow errored), `ExitLevel(false)`. Layering: main flow
  decides ≤63s, failsafe 90s, stock's stretched intermission ~120s. Never ship a stretched intermission
  without one.
- **End-of-game agent ensure-boot REMOVED** (v2.1, user: "i randomly get tabbed out at end of game"): the
  `record_at_end_game` boot spawned a cmd window that yanked exclusive-fullscreen BO3 to the desktop —
  tolerable over the old static scoreboard, unacceptable over a live decision screen. The record still
  stores + queues unconditionally; a dead agent only delays the POST (restart spawn-in boot / next app
  session sends the queue), never drops it.
- Live-disable: `acc_retry_on_death 0` = the untouched stock flow (stock text, 15s, auto-exit).
  **Needs a human in-game retest (v3)**: backdrop renders; the pause menu force-opens in game-over mode
  (two entries, "Game Over" title, up/down + confirm works at intermission); Restart Map stays
  flash-free; End Game exits clean; ESC-close → hint → ESC reopens; no tab-out at the wipe; a NORMAL
  mid-game pause still shows the full pause list (the `acc_go_active` scrub).

### REC-MENU INSTANCE LEAK (found 2026-07-26 — the round-38 marathon post-mortem)

The user's 72-minute solo run (died round 38) recorded only through round 31: the per-round lane
opened `acc_lb_rec` once per round and **never closed it** ("the chunk is pure io at menu-create,
nothing to close" — wrong conclusion), and the **per-client pool of OPEN LUI menu instances is finite
(~32 observed)**. At the cap every later `OpenLUIMenu` fails **silently** (no error, no return —
local records/rec_log just stop) — rounds 33-38, the **end_game record**, and even stock's
intermission camera fades (whose internal menu opens surfaced as the misleading `lui_shared.gsc`
"type undefined is not an int, param 1" script error). No earlier game had recorded past round 18, so
the leak was unreachable until a deep run. **Fix**: `publish_and_open_rec` now threads
`close_rec_menu_after_io` (CloseLUIMenu after the same 0.5s io-settle margin `leave_flush_record`
uses; no endon so the end_game record's close still runs at intermission). The boot + board lanes
always closed correctly. The lost run was **backfilled** by hand-POSTing the session upsert (round
37 = the completed-rounds convention) via the agent's own curl recipe — `backend/leaderboard/
backfill_r37.json`. Memory: `lui-menu-instance-cap`.

(An in-game "Fullscreen Window" display-mode tip was built alongside this and then REMOVED at the user's
request 2026-07-25 — the one residual first-launch flash only *yanks* players in exclusive fullscreen, but
the user preferred not to show an in-game card for it. If we want to nudge borderless later, put it in the
Steam Workshop description, not a card.)

## ➕ UPDATE 2026-07-18 — LEAVE FLUSH: pause-menu quit/restart records before exiting

**The hole (user: "it only sends when players die and game ends"):** a deliberate
**Leave Game / Restart Level** from the pause menu tears the server VM down **without
firing `end_game`**, so a run ended that way was never recorded or POSTed. The 07-17
Paradise win-time record fixed one instance of this; this fixes the general case,
**host-only** (user: "should only have to override for the host" — a peer's quit doesn't
end the session, the host still records it at `end_game`; and only the host machine has
the record/agent lanes anyway).

**The flow (Lua ⇄ GSC handshake, all proven bridges):**

1. **Arm** — `boot_agents` writes the **`accLbLeaveHook` controller UI model** (the
   docs/16 Wonderfizz bridge; per-player, fresh each match — deliberately NOT a dvar, a
   dvar would go stale across sessions on a machine that hosts then joins as peer):
   explicit `"0"` for every player, `"1"` for the HOST unless dev/god (assisted runs
   store nothing, so their Leave stays instant).
2. **Intercept** — `AetheriumStartMenu.lua`'s Leave Game AND Restart Level actions run
   through `AccLbFlushThen`: reads the model; unarmed = the exact old instant exit.
   Armed: **unpause first** (`cl_paused 0` — the solo pause freezes server GSC, so the
   watcher could never answer while paused; the menu still covers the screen), Exec-set
   `acc_lb_leave_req 1`, poll `acc_lb_leave_ack` on a 100ms UITimer, **4s hard cap**
   (never strand the player on a wedged bridge), then run the original exit. Timer
   follows `lui-uitimer-leaks-state-pool` (close-before-create + dies on menu close);
   ESC mid-flush just cancels the leave — the early record is a harmless upsert.
3. **Record** — GSC `leave_flush_watch` (threaded from init, **no** `endon("end_game")`
   so a post-game Leave still acks): same gates as `record_at_end_game`
   (dev/god/consent/`acc_lb_recorded`), then `publish_and_open_rec` and ALWAYS ack.
   **No agent boot on this path** — `boot_agent_verified` is up to ~15s of retries
   against a player waiting on a click; a down agent leaves the record + POST trigger
   queued on disk and the **next live agent sends the queue** (fix #4 below). Typical
   ack <1s.
4. **Survive the exit** — the POST rides the **detached** curl agent, so it lands after
   the game closes; repeat records per match land as ONE board row because the **Worker
   upserts by session id** (`round = MAX`, stats tables MAX-merge — fix #5's mechanism).

**PER-ROUND RECORD (same day, user: "lets go"):** `record_every_round()` closes the
**crash** hole too — a **baseline record ~30s in** (so even a round-1 crash/instant-quit
lands a row and the map-wide totals count every real game), then a record at **every
round transition** (the `round_number` poll pattern from `_acc_lui.gsc`, not the
`between_round_over` notify, so a missed notify can't end the lane mid-marathon). Zero
backend changes — each POST upserts the same session row at `MAX(round)`; a crash
mid-round N loses only that round's stats deltas, never the run. Costs: one POST per
round (Worker rate gate 20/min/IP; rounds are minutes apart — a 40-round game is ~40
POSTs over hours, and D1's free tier absorbs hundreds of such games daily) + one
local-records line per round, which forced a **dedup-by-session pass in the board
chunk's `local` mode** (keep highest round per session, later line wins ties for
freshest stats — without it one 40-round game filled the whole offline board).
Supporting changes: `publish_and_open_rec` gained a **record-lane lease** (timed,
self-expiring — four lanes call it now: end_game, Paradise win, leave flush, per-round;
the per-round lane SKIPS when busy since the next round re-records, the last-chance
lanes WAIT), and the pause-menu flush cap went 4s → 6s to cover waiting out a
just-fired round record. The leave flush stays valuable on top of per-round records:
it re-posts at quit time with the freshest stats/guns/duration.

**SPLIT-SESSION HARDENING + DB CLEANUP (same day):** the one dupe vector the session
upsert can't absorb is the rec chunk minting a SECOND id mid-match (its
`acc_lb_session` dvar read transiently failing — per-round posting gives it ~40 chances
per game instead of 2), splitting one run into two board rows. Prevention: GSC captures
the minted id (`capture_session_id`) and **re-asserts the dvar before every record**.
Historic/residual splits: `POST /admin/dedupe` on the Worker (gated on a separate
`ADMIN_KEY` secret, never shipped in the game; 404 until set) driven by
`backend/leaderboard/cleanup.js` — report-first, conservative continuation heuristic,
manual override for "suspect" clusters. Full runbook: backend README §Cleanup.

## 🚨 UPDATE 2026-07-17 — OUTAGE FIX: verified agent spawn, host-pinned recorder, win-time record, ladder-count fix

**The 2026-07-16 23:37 Workshop republish shipped a broken record/post lane — ZERO games posted
worldwide afterward** (last DB row = 22:30 that night; a 4-player Paradise-win game was lost).
Post-mortem: memory `lb-pipeline-outage-2026-07-16-republish`. Root exposure: the 07-14 auto
opt-in moved the agent spawn to a single UNVERIFIED `acc_lb_boot` open on the exact
`initial_blackscreen_passed` frame — on the pure Workshop launch (no launcher pre-spawn) that
open silently did nothing (no agent `.bat` written; the board menu 3s later worked), and every
dev-box game had masked the lane via `run_game.ps1`'s pre-spawned agent. Fixes (all live):

1. **Verified agent spawn** — `boot_agent_verified()`: settle 2s after blackscreen, then up to
   3 spawn attempts, each CONFIRMED via the chunk's `acc_lb_boot_trace` Exec (`spawn1`);
   `level.acc_lb_agent_up` is set only on confirmation, so record paths retry at their turn.
2. **Host-pinned recorder** — `pick_recorder()` (IsHost() scan, players[0] fallback) replaces
   the bare `players[0]` pick everywhere: the rec/boot menus do machine-local io on whatever
   client they open on, so a peer at index 0 stranded the record on a box with no agent.
3. **De-race waits** — every `SetDvar` batch now gets `wait 0.1–0.2` before its `OpenLUIMenu`
   so the chunk's createMenu never reads a not-yet-landed dvar.
4. **Self-healing POST queue** — the boot chunk no longer deletes `acc_lb_do_post.txt` on
   agent spawn: a queued POST from a session whose agent never ran is SENT by the next live
   agent (Worker upserts by session, so re-sends are safe).
5. **Paradise WIN-TIME record** — `record_on_paradise_win()`: the moment the win latches, the
   full record runs (same dev/god/consent gates). A winning crew that quits to menu (which
   fires NO `end_game`) is no longer lost. The rec chunk parks its session id on the
   `acc_lb_session` dvar (cleared per load) so the win-time and final end_game posts upsert
   ONE Worker row (every table is `ON CONFLICT … MAX()` — verified).
6. **Ladder-count fix** (user: "quads leaderboard was showing duos") — the board chunk now
   reads the GSC-published `acc_lb_players` dvar FIRST (server truth; fetches are host-only
   where the dvar round-trips) and falls back to the client-side PlayerList count, which can
   undercount on unresolved slots and used to pick the wrong ladder.
7. **Durable breadcrumbs** — boot + rec chunks append every open/outcome to
   `players\acc_lb_boot_log.txt` / `acc_lb_rec_log.txt` (dvar traces die with the session and
   plain Steam launches have no console_mp.log; the lost quad was un-post-mortemable).

**Needs a Workshop republish to reach subscribers.** Recovery: if a machine holds a stranded
`acc_lb_post.json` (e.g. a peer that recorded under the old players[0] pick), a manual
`curl -X POST -H "x-acc-key: <key>" --data @acc_lb_post.json <url>/games` lands it.

## ⚠️ UPDATE 2026-07-14 — AUTO OPT-IN (supersedes the 2026-07-13 consent prompt below)

The per-player consent PROMPT is **gone**. `boot_agents()` now **auto opt-ins the HOST** so every non-dev
game posts, spawns the host agent (the one accepted console tab-out) or reuses the launcher pre-spawn,
**auto-fetches + caches the board at match start** (`auto_fetch_board()`) so any player reads the top-10
instantly at the Plaza, and holds the pre-game zombie-spawn buffer at **20s** (`zombie_spawn_grace()`, was
10s). **Why:** the launcher path (`+set acc_lb_agent 1`) returned before ever running `consent_flow`, so
`level.acc_lb_consent` stayed unset and `record_at_end_game`'s opt-out gate silently skipped the POST — real
host games sent no data. `consent_flow` / `prompt_consent` / `dev_prompt_test` remain in-file but are
**superseded (uncalled)**, kept for reference. **Dev/god still never POST** (that user rule is unchanged).
The 2026-07-13 opt-in design below is retained as history.

## ➕ UPDATE 2026-07-14 — PER-PLAYER kills / downs / revives

Recorded games now carry **per-player kills, downs and revives** next to the round + roster. `npm run
summary` prints a **PLAYER STATS** board; the raw feed is `GET /stats/players.{json,txt}`.

- **NAMED, not anonymous.** These attach to the `games` posture (which already stores gamertags) — the
  new `player_stats` D1 table stores the gamertag keyed by `(session_id, name)`. This is deliberately
  *unlike* the anonymous `gun_*` telemetry (docs/41), because the ask was explicitly per-player.
- **Source = the STOCK scoreboard fields** `player.kills` / `player.downs` / `player.revives`, which the
  engine already maintains (verified vs stock ref: `_zm_spawner.gsc:2286` `attacker.kills++`,
  `_zm_laststand.gsc:149` `self.downs++`, `:1383/:1442` `reviver.revives++`). So there is **no new
  death/down/revive callback or per-player thread** — `_acc_leaderboard::serialize_stats()` just READS
  the three fields at end_game (undefined→0 guarded). Lowest-risk possible integration.
- **Transport** = the same host-local dvar as the gun blob: GSC publishes `acc_lb_stats` =
  `"name:kills:downs:revives,..."` (gamertag `StrTok`-scrubbed of `: , ; | " ' \` so it can't break the
  record/field split or the rec chunk's `([^:,]+):(%d+):(%d+):(%d+)` parse). The rec chunk appends a
  `stats` array to the POST. dev/god never reach the publish (existing `record_at_end_game` gate).
- **Worker** stores it in its own best-effort try/catch (a not-yet-migrated `player_stats` never 500s the
  game row) and exposes the aggregate endpoint (`?sort=kills|downs|revives|kpg|games|best_round`).
- **Rollout 2026-07-14:** D1 migrated (idempotent `schema.sql`), Worker deployed, `.ff` rebuilt
  (`-GscOnly`); round-trip POST→store→read verified live (test rows deleted). Games recorded on an OLDER
  `.ff` have no stats — the summary section notes it. Alignment is by GSC `player.name`, self-describing,
  so it needs no PlayerList-slot agreement with the roster.

## 🎨 UPDATE 2026-07-15 — BOARD UI v2: LUI panel with per-player KILLS / REVIVES / DOWNS

The Plaza terminal's board is no longer the 300px `acc_ui` hudelem card — it is a real **LUI panel**
rendered by the `acc_lb_board` menu shell itself (which used to draw nothing): a centered ~620px
glass plate in the map's HUD identity (acc_hud `ACC_PAL` navy/cyan/teal/amber/violet), with a
**SOLO/DUO/TRIO/QUADS LEADERBOARDS** title, an **OFFLINE-only source tag** (user 2026-07-15 "remove
the LIVE" — the healthy cloud board shows no tag; amber OFFLINE appears only when the net fetch
failed and the machine-local records are showing), a column header, and per
game: rank (gold/silver/bronze top 3), **ROUND N** (violet for a Paradise-winner run), then the
per-player **KILLS / REVIVES / DOWNS** columns — solo runs merge the single player onto the game row;
co-op runs nest one indented row per player (kills-sorted). Old games with no stats rows show the
roster CSV as before. Game blocks are zebra-striped; if the height cap truncates the list a
"+N more runs on the ladder" line says so.

- **Data**: `GET /top10.txt?v2=N` — ONE param carries both the v2 marker and the player-count filter
  (N=1..4, 0=global) so the agent `.bat`'s delayed-expansion GET suffix never needs a `&`. v2 rows
  append a third field `|name:kills:downs:revives,...` (the `player_stats` table joined by session,
  kills-sorted; names belt-and-braces scrubbed of `:,|`). `/top10.json` now always includes a `stats`
  array per row (additive). Old clients keep the 2-field format; stats join is skipped for
  `?limit>100` analytics pulls (bind-limit + summary.js reads `player_stats` directly).
  **Needs `wrangler deploy`** — pre-deploy, a v2 client just gets stats-less rows (names-only panel)
  and the per-count filter is ignored (old worker doesn't read `v2`). Deploy closes both.
- **Local records** (`players/acc_lb_records.txt`) gained a 5th field: the raw `acc_lb_stats` blob —
  the offline board shows the same columns. Old 4-field lines still parse.
- **Chunk contract**: `read`/`local` still push the legacy dvars `acc_lb_r1..r10`+`acc_lb_done`
  (unchanged format) but now RETURN a structured rows table `{src, show, rows={{r,w,names,st={{n,k,d,rv}}}}}`
  to the outer shell, which renders the panel (pcall-guarded — a render error can never pop the UI
  Error box) and reports `acc_lb_lui "ok:N"`/`"err"`.
- **GSC** (`show_board`): always opens the menu (the on-disk result file is now the per-session cache —
  `acc_lb_use_cache 1` makes the chunk skip the curl on a same-lobby-size re-open), holds it open for
  the 12s/walk-away display window, and **falls back to the legacy card** if the Exec→dvar bridge works
  (`acc_lb_done` landed) but no `"ok"` arrived on `acc_lb_lui` — the station can never show nothing.
  Silent fetch paths (`auto_fetch_board`, dev probe) set `acc_lb_board_show 0`; an unreadable flag
  (co-op peer client) defaults to SHOW, which is correct because the silent paths are host-only.
  Since 2026-07-17 the silent and visible lanes are mutually excluded by the **board lane lease**
  (next block) — a silent lane can no longer clobber a visible session's dvars mid-fetch.
- **CO-OP PEER LANE (2026-07-16, user: "non host players cant see the UI for the Leaderboards").**
  The 2026-07-15 claim that "peers get the full board client-side" was WRONG: every data lane is
  host-machine-only (the curl agent boots only on the host, `players/acc_lb_records.txt` exists only
  on the recording machine, and a server `SetDvar` never replicates to a remote client), so a peer's
  shell polled an empty file for 8s and rendered the empty local fallback. The fix relays the HOST's
  fetched rows through the server to the peer over **per-player controller UI models**
  (`SetControllerUIModelValue` — the docs/16 Wonderfizz bridge / docs/19 M2, the only replicated
  GSC→LUI string channel):
  1. the host chunk's `push_rows` now Exec-pushes stats + totals too (`acc_lb_st1..10`,
     `acc_lb_tot`) — the host's Exec lands in the SERVER dvar table, so GSC holds the full v2 board;
  2. `show_board` branches non-`IsHost()` players to `show_board_peer()`: writes `accLbR1..10`
     (= "round|names|stats"), `accLbTot`, `accLbSrc` on that player (all 12 written every open, so
     stale relays can't linger; 12 `lui_menu_data` precaches), opens the same shell, skips the
     `acc_lb_done` wait (a peer's Exec can't move a server dvar) and keeps the 12s/walk-away window;
  3. the chunk's new `"feed"` mode rebuilds `{src, show, rows, tot}` from those models (reusing
     `parse_rows`), and the outer's tick consults feed whenever the io lane has nothing — a peer
     renders at tick 1 (~0.5s). On the host the models are never pushed → feed returns `"none"` →
     io lane untouched. Peer freshness = the host's last fetch (auto-fetch at match start + every
     host station use). If the host never fetched (agent dead), the peer degrades to the old empty
     local fallback.
- Regenerate with `node tools/build_lb_lui.js` after touching the chunks/shell; `.ff` rebuild is
  `-GscOnly` (no geometry).

**BOARD LANE LEASE (2026-07-17, user: "I went to leaderboard and saw the old leaderboard UI... How
did the code go down that path at all"):** the visible station session and the two SILENT fetch
lanes (`auto_fetch_board` at match start, `dev_fetch_probe` at blackscreen+15s in dev builds) all
drive the SAME menu + dvar channel (`acc_lb_board_show` / `acc_lb_use_cache` / `acc_lb_done` /
`acc_lb_lui` / `acc_lb_r*`/`st*`/`tot`) and had no mutual exclusion. Live capture (console_mp.log):
station open t=64.9s → dev probe t=65.1s → its `clear_board_dvars()` wiped the in-flight handshake
and its `acc_lb_board_show "0"` made the visible shell's `serve()` take the silent-fetch
early-return — no `acc_lb_lui "ok"` ever landed, so the GSC handshake (working as designed) closed
the healthy panel and drew the **legacy card**. The next station use hit the cache with no silent
lane running and rendered the panel — i.e. "old UI once, new UI after", exactly the reported bug.
Fix (`_acc_leaderboard.gsc`): a **timed lane lease** (`level.acc_lb_lane_until`, GetTime-based —
NOT a boolean, because `endon(disconnect/end_game)` can kill a holder mid-lease and a stranded flag
would jam the station; a lease expires). Rules: `show_board` waits out a held lease (bounded
13s) then holds it through fetch + render handshake, releasing before the 12s display window;
`show_board_peer` only waits (its dvar-read→model-push relay has no waits, so it's atomic once the
channel is quiet); `auto_fetch_board` and `dev_fetch_probe` **skip** when the lease is held (a
visible fetch fills the same cache the pre-warm would; the probe is log-only). The legacy card
itself stays — it is the panel-failure safety net, not dead code.

**LIVE-TEST FIX ROUND (2026-07-15, user screenshot):** the first in-game test showed the panel
rendering but with the GLOBAL rows under a SOLO title and no stats — root cause: the Worker deploy
had not run yet (the game side was already v2; the old Worker ignores `?v2`). User deployed;
curl-verified `?v2=1` = solo-only rows and `?v2=2` = the round-22 duo with full
`name:kills:downs:revives` fields (cross-checked against `/stats/players` totals). Two follow-up
fixes shipped in the same pass:
- **Stat-less games render dashes, not blanks** (shell): a solo roster with no stats shows the name
  in PLAYER + dim `-` in each stat column ("no data recorded"); multi-name stat-less rosters keep
  the CSV span. Stats exist only for games recorded on the 2026-07-14+ LOCAL build — pre-tracking
  games never backfill, and **Workshop-subscriber games carry no stats until the next publish**
  (their published build predates the pipeline; add to the publish checklist).
- **Station hint no longer bleeds through the panel** (GSC): hint is blanked while the board is up
  and restored to idle on every exit (walk-away-mid-fetch, fallback card, panel close). A
  mid-display disconnect leaves it blank until the next use self-heals it (accepted edge).

**TOTALS FOOTER (2026-07-15, user):** one line under the ladder — *"`0 / 465` GAMES HAVE MADE IT TO
THE BOTTOM OF THE TRENCH"* (violet, the panel's winner-color language, under a cyan rule): games
recorded vs Paradise wins.
- **GLOBAL on purpose, NOT filtered by the `?v2=N` ladder above it.** It is a fact about the MAP
  (every run ever recorded, every lobby size), so the denominator does not move when the same player
  opens the board solo vs in a quad. This is the ONE place the per-lobby-size requirement above does
  not apply — it is a footnote, not a ladder. (One `WHERE` clause away if that ever changes.)
- **Wire**: the Worker appends a v2-only FOOTER line `T|<games>|<wins>` — always LAST, from
  `SELECT COUNT(*), SUM(paradise_winner) FROM games` (unfiltered), in its own try/catch (a totals
  failure = no footer, never a broken board; same graceful posture as the winner column). The leading
  `T` can't collide with a data row (those start with the round DIGITS), so the chunk's `^(%d+)|`
  gmatch and the GSC fallback skip it untouched; v1 clients never get it at all. Last-line placement
  is deliberate: the agent `.bat`'s `echo ACCEOF_OK>>` glues the marker onto the last line and the
  chunk strips both markers before parsing (so the footer pattern is unanchored at the tail).
- **Chunk contract**: `parse_rows` returns `rows, tot` (`{g=games, w=wins}` or nil) and `read` puts it
  on the result table as `res.tot`; the shell reserves `FOOT_H` in the measure pass and draws the line
  (also on the empty-ladder path — an empty SOLO ladder still gets the global footnote).
- **No footer OFFLINE** (`tot` stays nil): the local records file holds only THIS machine's games and
  never stored the Paradise flag, so any count built from it would be a wrong claim about a global
  stat. **Needs `wrangler deploy`** — pre-deploy the game just draws no footer.

**SECOND + THIRD LIVE-TEST ROUNDS (2026-07-15) — REQUIREMENT LOCKED: the board is PER-LOBBY-SIZE.**
User, round 3, explicit: *"The requirement is that I should see top 10 solo rounds"* (solo lobby →
SOLO ladder; duo → DUO; etc — the original 2026-07-13 per-count design). The board was briefly
switched to the GLOBAL `?v2=0` ladder that same day (a misread of round 2's "not the correct data")
and reverted hours later — **do not flip it back to global**; the global view stays available
Worker-side (`?v2=0` / `?players` absent) for web/analytics. What round 2's complaint actually was:
the user's own best solo runs are missing from the solo ladder because they were **dev/god sessions,
which never post** (the 2026-07-11 user rule) — the ladder itself was correct. Kept from the global
detour: dash alpha 0.55 (0.4 was near invisible in-game).

**"Board looks janky" fix (round 3) — THE LUI COLUMN LAYOUT RULE:** `setScale` scales an element
around its CENTER, so two labels in the same column with different scales get different effective
left/right edges — the board's mixed scales (0.65 header / 0.78 nested / 0.8 span / 0.85 solo) made
every row type land at slightly different x. The shell now uses **ONE scale (`SC=0.8`) for the
column header and every data cell**, per-column boxes shared by all row types (`statCells()` is the
only place number cells are drawn), headers differentiated by dim cyan instead of size. Rosters are
**truncated to the PLAYER column** (stat-less games show dashes) — nothing may bleed under the
number columns (long trio CSVs used to). Reuse this rule for any future LUI table.

**Map-isn't-loading incident (same day, resolved — NOT the board):** two launches died at the
frontend with an unprompted clean `quitting...` ~50s in, no map-load attempt, no error. Root cause =
the **Steam stale-stop jam** (game-spawned LB agent lingering in the process tree → Steam stuck at
"Stopping" → the NEXT launch receives the pending stop and self-quits). Cure: kill stale agents +
FULL Steam restart (docs/17); prevention = the same-day agent game-liveness exit (see memory
`lb-agent-game-liveness-exit`). Log fingerprints for next time: args provably arrived (fs_game in
search path, logfile on), "ModLoad done" then config execs then `quitting...`; the
"Could not find navvolume" error right after the map ff's frontend registration pass is
**pre-existing noise** (navvolume.hkt is 0 bytes since 2026-07-01; present in healthy boots too).

## ✅ SHIPPED (2026-07-11) — the as-built system

> **✅ LIVE IN NON-DEV (2026-07-13, user "enable in non dev mode").** Real subscribers run
> `consent_flow()` (host/solo): default **ON**, prompted **once** + persisted in
> `players\acc_lb_consent.txt`. Enable → helper spawns now (the accepted one-time flash) + board works;
> a RETURNING enabled player spawns invisibly at end_game (zero gameplay console). Disable → nothing
> runs, ever; the `record_at_end_game` **opt-out gate** (`!IS_TRUE(level.acc_lb_consent)`) stores
> nothing. `dev_prompt_test()` stays the DEV harness (card every launch, spawns on Enable to demo the
> flash, never persists/POSTs). **v1 co-op scope:** host-driven (only bridge that round-trips + the
> recorder); peers passive; host's record covers the game. Fully per-player co-op (each enabled client
> posts a host-broadcast shared session, Worker dedups) = the next step if wanted.
>
> **OPT-IN CONSENT — the fullscreen tab-out fix v2 (2026-07-13, user).** v1 still fired the agent's
> `os.execute` at **every match start for every player** (a console flash that yanks exclusive
> fullscreen: *"it tabs us out… players may think the map is hacking them"*). The flash is
> irreducible — retail LUI's only network primitive is `os.execute`, which always runs through
> `cmd.exe` (a console app), and in exclusive fullscreen any new window forces a mode-switch. So the
> fix is **when/whether we spawn**, reworked to **opt-in, default OFF**:
> - **Never opted in ⇒ nothing spawns.** No console, no tab-out, no local file, no POST. Clean map for
>   everyone by default.
> - **One-time prompt at spawn-in** (`prompt_consent`, an `acc_ui::card_show` panel) with **two explicit
>   choices** (user 2026-07-13): **Hold [Melee] = Enable (Recommended)** / **Hold [Aim] = Disable**
>   (~1s hold each, live "Enabling…/Disabling…" feedback). Both non-[Use] (no wallbuy conflict); Enable
>   needs the deliberate Melee hold, an accidental Aim-hold only ever Disables (safe default). **Zombie
>   spawning is PAUSED ~12s while deciding** (`zombie_spawn_grace()` re-clears the stock `spawn_zombies`
>   flag each tick on a disconnect-proof LEVEL thread with a hard cap; resumes on choice or cap). When
>   promoted, persisted in **`players\acc_lb_consent.txt`** (`"1"`/`"0"`/absent) → asked exactly **once**
>   (the current dev-gated `dev_prompt_test` does NOT persist — shows every launch for iteration).
> - **Opted-in players no longer spawn at blackscreen either.** The boot menu's **"check"** mode only
>   *reports* the saved choice to GSC; the agent is spawned at **end_game** ("spawn" mode) where a
>   console flash is invisible on the game-over screen. Opted-in players get **zero gameplay-time
>   console**. The one in-play `os.execute` is the instant they hold [Melee] to enable ("set1" spawns
>   immediately so the board works that session).
> - **Boot chunk modes** (dvar `acc_lb_boot_cmd`): `check` (report only), `set1` (force 1 + spawn),
>   `set0` (write 0, never clobbering an existing 1 — so a co-op re-prompt can't silently turn a board
>   off), `spawn` (spawn only: dev + end_game).
> - **Gating**: `record_at_end_game` returns unless `recorder.acc_lb_consent` (same "assisted runs
>   store nothing" spirit as the dev/god rule). **Dev** (no launcher) auto-spawns silently, no prompt,
>   no consent file (`boot_dev_spawn`) → terminal fetch + dev probe still work. **Launcher**
>   (`acc_lb_agent 1`) unchanged, fully silent.
> - **v1 co-op scope**: only the host/solo runs the flow (the only Exec→dvar bridge that round-trips,
>   and the recorder). Co-op peers spawn nothing — clean by default. A peer's terminal view just falls
>   back to the local/offline board.
> - **NEEDS AN IN-GAME HUMAN TEST** (a scripted launch parks at the ENTER splash and never reaches the
>   prompt — see the 2026-07-12 lesson below): load a NON-dev, non-launcher build, confirm the card
>   appears at spawn, hold [Melee] → the agent spawns + `players\acc_lb_consent.txt` = `1`; reload →
>   no prompt; finish a game → row in D1. A fresh box (no consent file) is the undecided case.

> **PER-PLAYER-COUNT BOARDS (2026-07-13, player request).** Separate solo/duo/trio/quad
> ladders. **NO schema change** — the count is derived from the existing `games.players`
> CSV: the Worker's `cleanName()` strips commas from every gamertag, so `commas + 1` = the
> roster size. Wiring:
> - **Worker** `GET /top10.txt?players=N` (N=1..4) adds
>   `WHERE (LENGTH(players) - LENGTH(REPLACE(players,',','')) + 1) = N`; no param = the global
>   board (backward compatible). **Must `wrangler deploy` for the filter to go live** (old
>   worker ignores the param → global board, so the game never breaks pre-deploy).
> - **GSC** (`_acc_leaderboard.gsc`) publishes the lobby size on `acc_lb_players` before opening
>   the board menu, caches the board PER COUNT (`acc_lb_cache_pc`), and prefixes the card title
>   **SOLO / DUO / TRIO / QUADS** (`acc_lb_count_label`).
> - **Board chunk** reads `acc_lb_players` (the `readdvar` forms) and writes the query suffix
>   `?players=N` as the CONTENT of the `acc_lb_do_get.txt` trigger; the **agent `.bat`** (both
>   generators) now `setlocal EnableDelayedExpansion` + `set /p ACCQ=<acc_lb_do_get.txt` and
>   appends `!ACCQ!` to the GET URL. Regenerate with `node tools/build_lb_lui.js`.

> **REWORKED SAME EVENING — the BACKGROUND AGENT (fullscreen tab-out fix).** The
> user's first live test found every `os.execute` spawning a console window that
> yanked exclusive fullscreen ("tabs us out + freezes", on interact AND at game
> end — the end-game POST also *blocked* the UI thread). Fix: all curl work moved
> to a hidden agent (`players\acc_lb_agent_<tok>.bat`, URL+key baked; polls ~1s
> via `ping -n 2` for ~8h then self-deletes — sized up from 2h in the 2026-07-12
> pre-publish hardening so a marathon high-round run can't outlive its agent and
> silently lose the end-game POST) serving trigger files. The rec/board
> chunks are **pure io**: they write `acc_lb_do_post.txt` / `acc_lb_do_get.txt`
> and the agent runs curl off-process — no window, no focus steal, no block, on
> any hot path. A RUNNING .bat must never be overwritten (cmd re-reads it from
> disk) — hence the per-boot token filename.
>
> **The match-start terminal — SOLVED via the LAUNCHER SILENT PATH (2026-07-12).**
> The in-game spawn's `os.execute` unavoidably creates a console — and with
> `start /b` the agent *shared* that console, so a terminal window appeared (and
> could linger) at every match start (user: "it just starts up my terminal every
> time... do it silently"). Shipped fix, zero in-game load-path changes:
> - **`PLAY_NORMAL.bat` (the only launcher) + `run_game.ps1`** call **`tools/spawn_lb_agent.ps1`**
>   (GENERATED by `build_lb_lui.js`, URL/key spliced — same source as the chunk):
>   it liveness-checks (ping/pong; reuses a running agent) and otherwise spawns the
>   agent via PowerShell **`-WindowStyle Hidden` = no window, ever** (4h lifetime),
>   then the launcher passes **`+set acc_lb_agent 1`** — `boot_agents()` reads the
>   dvar (the launch-dvar idiom) and **skips the in-game spawn entirely**. Verified
>   shell-side: hidden spawn → answers ping → 0 visible cmd windows; second run →
>   "already alive - reusing".
> - **Workshop players** (no launcher; user 2026-07-12: "dont want to open up
>   random programs for my subscribers") get a **WSH hidden trampoline**: the boot
>   chunk writes a tiny self-deleting `.vbs` and `os.execute`s
>   `wscript //B //Nologo` it; the vbs `WScript.Shell.Run(bat, 0, False)` launches
>   the agent with window-style **0 = SW_HIDE** — no window, no taskbar item, Task
>   Manager only. The vbs derives the bat path from its own `ScriptFullName`
>   (cwd-independent) and deletes itself. Shell-verified via the exact os.execute
>   path: the agent's startup marker was written with **0 visible windows** and no
>   lingering wscript. Only artifact left for subscribers = os.execute's own
>   sub-second cmd flash under the load fade (inherent; only the launcher path
>   removes even that). If WSH is policy-disabled, the agent just doesn't start and
>   the board falls back to offline — the game is unaffected.
> - History for the next agent: two in-game hide-it attempts (a UITimer-polled
>   handshake; an early `spawned_player` two-menu ping/pong) were REVERTED as
>   unverifiable — a scripted `steam -applaunch` parks at the "Press ENTER to
>   Start" splash (Responding=True, CPU climbing — not a hang) so the dev probe
>   never fires. Verify boot logic OUT-OF-GAME (delete-pong→write-ping→pong
>   reappears); real in-game confirmation needs a human launch. Keep io/os
>   synchronous in `createMenu`; don't open the boot menu before
>   blackscreen-passed. end_game keeps the >100-min marathon-guard boot.

> **AGENT LIFETIME — the Steam stuck-at-"Stopping" fix (2026-07-15, user report: "when I close the
> game it just gets stuck at Stopping on Steam; I have to close Steam entirely to launch again").**
> Root cause: an agent spawned BY THE GAME (os.execute → wscript → cmd) is a DESCENDANT of
> BlackOps3.exe, and Steam waits on the game's whole process tree before marking it stopped — the old
> agent looped ~8h with no exit condition, so Steam sat at "Stopping" until Steam was restarted.
> (Live evidence: a game-child agent from the same morning still running, parent PID dead, + 35
> orphaned `acc_lb_agent_*.bat` since 7/12 — one per session.) Fix (both generators, LOCKSTEP:
> `spawn_lb_agent.tpl.ps1` + `acc_lb_boot_chunk.lua`): the agent `.bat` now checks `tasklist` for
> `BlackOps3.exe` every ~10s and EXITS + self-deletes once the game has been seen and then gone for
> 2 consecutive checks (~20-30s after close; Steam then clears on its own), or after ~200s if the game
> never appears (aborted launch). The ~8h loop cap stays as a backstop only. Back-to-back games in one
> app session are unaffected (the game process persists between maps). Verified out-of-game 2026-07-15:
> fresh pre-spawn answered ping/pong, then self-exited + self-deleted with no game present.

```
 [GSC] _acc_leaderboard.gsc
   ├─ map load ──(every player)── OpenLUIMenu "acc_lb_boot"  → write+spawn the HIDDEN agent (the ONLY exec)
   ├─ end_game ──(players[0])──── OpenLUIMenu "acc_lb_rec"   (SKIPPED if dev OR god - user rule)
   ├─ Plaza station trigger ───── OpenLUIMenu "acc_lb_board" ── LUI panel (fallback: card_show)
   └─ dev fetch probe (acc_dev, log-only, GET-only, acc_lb_board_show 0)
 [LUI] acc_lb_boot/rec/board.lua   (GENERATED - hksc bytecode in \ddd strings; PURE IO after boot)
   ├─ boot:  write players\acc_lb_agent_<tok>.bat → spawn hidden (popen|start /b) → agent polls:
   │           acc_lb_do_post.txt → curl POST acc_lb_post.json → acc_lb_post_result.txt
   │           acc_lb_do_get.txt  → curl GET (suffix ?v2=N) → acc_lb_top10.txt + ACCEOF_OK/ERR marker
   ├─ rec:   roster = PlayerList.<i>.playerName models · round = gameScore.roundsPlayed - 1
   │         session/ts = os.time → append players\acc_lb_records.txt (round|names|ts|stats) + POST trigger
   └─ board: truncate result + write GET trigger (skipped on acc_lb_use_cache 1) → UITimer 400ms polls
             → rows -> dvars acc_lb_r1..r10 + acc_lb_done (legacy) + rows TABLE -> the shell's panel
             (KILLS/REVIVES/DOWNS columns; acc_lb_lui "ok:N") → net-fail/timeout = local-records fallback
 [cloud] backend/leaderboard/ Worker + D1 (deployed; see "CLOUD BACKEND LIVE" below)
```

- **Files**: `_acc_leaderboard.gsc` (recorder + station + probe; module init in
  `acc_main`), `ui/uieditor/menus/hud/acc_lb_rec.lua` + `acc_lb_board.lua`
  (**GENERATED — never hand-edit**), sources in `tools/lui_chunks/*` compiled by
  **`node tools/build_lb_lui.js`** (splices backend URL + key from the gitignored
  `backend/leaderboard/deployed.local.json`; missing file = LOCAL-ONLY build).
  Harvest a run: `tools/read_lb_logs.ps1`. Kill switch: `acc_lb_on 0`.
- **THE DEV/GOD RULE (user 2026-07-11)**: *"When either dev mode or god mode is
  enabled we will not make a post request to the db and store any data."* Enforced
  at the top of `record_at_end_game()` — `IS_TRUE(level.acc_dev) ||
  IS_TRUE(level.acc_god)` returns before the rec menu ever opens, so assisted runs
  never reach the DB **or** the machine-local file. (The station/fetch still works
  in dev — viewing stores nothing; the dev probe is GET-only.)
- **Station placement (user 2026-07-11)**: Plaza south wall **WEST of the Implant
  door** at `(-340, -210, 0)` — the *"other side of the door, not on the same side
  as the mystery box"* (the `acc_box_plaza` chest at `(100,-150)` is the east
  side, and the initial box roll is always plaza). Model
  `p7_zm_sta_dragon_network_data_terminal` (same as the Overclock terminals),
  GSC-spawned; it ships no `_col` LOD, so collision = the `leaderboard_terminal`
  brushmodel clip in `tools/add_prop_clips.js` (user: "no clip") — clip edits =
  map regen + FULL build. Hint text is cursor-hint-router-safe (NO
  "for"/"buy"/"cost"/"upgrade weapon" substrings — memory
  `lui-cursorhint-router-loose-weapon-matcher`). Card rows read
  `1.  Round 4   Name, Name` (user UI pass), and the busy ("loading top 10…") hint
  restores to idle the moment the fetch resolves.
- **Round source**: `gameScore.roundsPlayed` UI model reads **round_number + 1**
  (probe-verified live: raw=2 at round 1) → the chunk posts `raw - 1`.
- **Verified live (2026-07-11)**: dev probe = menu loads, background curl GET hits
  the Worker (~1.6s), rows parse → dvars → GSC (seeded row rendered; the
  no-trailing-newline ACCEOF glue bug found + fixed by stripping markers before
  parse). End-to-end capture = flags-off AFK run, real end_game → POST → row in
  D1 (see CHANGELOG). Anti-abuse posture unchanged (Worker key/rate/clamp gates;
  casual board, zwr.gg for serious records).
- **Ops**: tune/patch the board with `wrangler deploy` (no game rebuild). Wipe
  rows: `npx wrangler d1 execute acc_leaderboard --remote --command "DELETE FROM
  games WHERE ..."`. Rotate the key: `wrangler secret put ACC_KEY` + update
  deployed.local.json + `node tools/build_lb_lui.js` + rebuild. Editing the chunk
  logic = edit `tools/lui_chunks/*`, re-run the generator, sync + `-GscOnly` build.
- **Known limits (v1)**: quits/crashes mid-game aren't recorded (only a real
  end_game posts; per-round checkpoint upserts are the UEM-style future upgrade);
  co-op non-host machines don't get local-file rows (the host's POST covers the
  global board, and since 2026-07-16 the peer's TERMINAL view is served by the
  host-relay lane above, not the local file); the board shows the top 10 with no
  paging/tabs (the 2026-07-15 LUI panel upgraded the RENDER — see "BOARD UI v2"
  above — but not the depth).

> Research below (3 parallel passes, 2026-07-11): retail-BO3 I/O channels,
> community precedent, and in-repo building blocks. Verdict up front: **the
> user's architecture is buildable on retail Steam BO3** — with one twist: the
> game itself can't call an HTTP API from GSC; the bridge is **LUI (Havok
> Script) `io`/`os`**, which shipped Workshop maps already use.

## The headline research findings

### 1. Retail LUI has working `io` + `os` — SHIPPED precedent (MACHIN[A])

The top-tier Workshop map **MACHIN[A]** (`zm_trenches_early`, Rayjiun/Deadshot,
Workshop ids 3708647045 / 3731372542 — installed on this machine) persists
achievements/cosmetics/tutorials across sessions by **writing
`players\311210\save_trenches.dat` from plain Workshop-shipped LUI**. Verified
primary-source (2026-07-11): decompressed its fastfile with `tools/ff_grep.js`
and read the compiled `ui/uieditor/shared/save.lua` constant pool — it calls
Lua stdlib **`io` open/write/read/seek/close**, **`os.execute("mkdir
.\players\311210")`**, keys per-player via `Engine.GetXUID`, XOR/hex-encrypts,
gates writes behind a **one-time permission prompt**, handles Mac
(`PATH_MAC = ".\players\"`), and bridges to GSC via
`Engine.SendMenuResponse("TrenchesSave", …)`. The `.dat` file exists locally
(written by a normal Workshop subscription — no client mod). **So retail
HKS/LUI is NOT `io`-sandboxed**, contrary to community folklore.

### 2. A retail Workshop mod already runs a cloud leaderboard (UEM)

**Ultimate Experience Mod** (SphynxMods, Workshop id 2942053577) ships
cross-device persistent progression + **web leaderboards** on retail Steam BO3:
"each time a game starts, UEM sends a request to a **Cloudflare Worker** which
stores the game session into **Supabase**", updating **every round** so crashes
don't lose data; identity = XUID via Steam. (Sources:
cliftonvanhenten.com/ultimate-experience-mod, ultimate-experience-mod.com,
uem.wiki.gg.) The exact HTTP primitive is undocumented; given #1, the credible
vector is **`os.execute`/`io.popen` + `curl.exe`** (ships with Win10+). This is
*exactly* the user's proposed architecture, already shipped by someone else.

### 3. Everything else is a dead end or a fallback (verified)

| Channel | Verdict |
|---|---|
| GSC file/HTTP I/O | **NONE on retail** (BOIII/Plutonium `writefile`/`fs_*` don't exist here). Only out-channel: `LogPrint()` → `games_mp.log` (proven in `_acc_diag.gsc`; needs `+set g_log games_mp.log +set g_logSync 1`) |
| Archived dvars / `seta` | **Dead** — T7 `config.ini` is whitelist-only; script dvars die with the process |
| Playerdata / `SetDStat` | Per-mod local `.cgp` DOES persist (`players\mods\<map>\stats_zm_offline_0.cgp`), but fixed DDL schema, per-player scalars only — no roster strings, no custom DDL for usermaps. Fallback for "personal best round" only |
| Inbound at runtime | **Impossible** (no rcon for customs, no GSC file read, no push) |
| Inbound at launch | `+set acc_lb_data …` / exec'd cfg → `GetDvarString` works (the launch-dvar idiom, e.g. `acc_lb_agent`) — companion-app fallback only |
| Steam leaderboards API | Unreachable from mods (engine is DemonWare anyway) |
| Workshop republish | Auto-propagates to subscribers (slow, ~daily, full redownload) — viable "baked top-10" fallback |
| In-game leaderboard-at-an-object precedent | **Nobody has shipped one** — UEM's boards are web-side; challenge maps keep "leaderboards" as Workshop-description text; zwr.gg / codzombiestracker.com are manual video submission. Ours would be a first |

## Architecture — three stages, each shippable

```
        [GSC host]  roster + round + session id
             │ clientfield / UIModel (docs/19 pipeline)
             ▼
        [LUI, every client]
        ├─ Stage 1: io.write → players\save_acc_leaderboard.dat   (LOCAL board)
        ├─ Stage 2: os.execute curl POST → Cloudflare Worker → DB (GLOBAL board)
        │           os.execute curl GET top10 → temp file → io.read
        └─ render top-10 panel (or SendMenuResponse the rows up to GSC)
```

### Stage 0 — SPIKE — ✅ **PASSED 2026-07-11. io works; the leaderboard is buildable.**

> **RESULT: retail BO3 LUI CAN read/write files under `players\` from a
> Workshop usermap, and we now have the full working toolchain + recipe.**
> Proven live (self-run, no user cost): a hksc-compiled bytecode chunk,
> embedded as a `\ddd` string in our normal L3akMod source and loaded via
> `load(reader)`, called `EnableGlobals()` and did an `io.open`/write/read
> round-trip. Trace: `I:in|EG_function|io_table|wr_true_BCOK|done`, and
> **`players\acc_lb_bc.txt` exists on disk containing `BCOK`**.
>
> **BOTH STAGES PROVEN (v7, 2026-07-11).** A follow-up run added `os.execute`
> and curl to the chunk — they **also work, no crash** (my earlier "os.execute
> crashes" was a misdiagnosis: those runs used `load(string)` so the chunk
> never actually ran). Trace:
> `io_table_os_table|wr_true|exec_after_true_42|curl_after_true_rc0_bytes559|done`
> — `os.execute("cmd /c exit 42")` returned rc **42**, and **curl fetched 559
> bytes of real HTML over HTTPS** into `players\acc_lb_http.txt` (verified on
> disk). So Stage 2 (curl POST/GET to a cloud DB) is reachable too — the
> entire original architecture (every game → cloud → top-10 in game, zero
> player installs) is buildable. **The recipe is in "✅ THE WORKING RECIPE"
> below; the historical bisect follows it.**

#### ✅ THE WORKING RECIPE (io/os from a retail usermap, keeping L3akMod)

Four blocks had to line up; all verified:

1. **Compiler — `hksc` (Jake-NotTheMuss), built here via `w64devkit`.** No C
   toolchain was installed; grabbed portable w64devkit (MinGW-w64+make, unzipped
   to scratch), then `sh ./configure --game=t7 && make` → `src/hksc.exe`
   (static). It has **no stdlib whitelist** — a free `io` becomes
   `OP_GETGLOBAL "io"`. Compile: `hksc.exe -s -o out.luac src.lua` (the `-s`
   strips debug; `--game=t7` is baked in at configure-time, NOT a runtime flag).
   Output header `1b 4c 75 61 51 0e …` = **byte-identical to MACHIN[A]'s**.
2. **The stdlib unlock — `EnableGlobals()` / `DisableGlobals()`.** HavokScript
   locks `io`/`os` by default (that's why our v1–v5 probes read them as nil).
   The chunk must call `EnableGlobals()` first; `type(io)` then returns `table`.
   Re-lock with `DisableGlobals()` after. (Read out of MACHIN[A]'s save.lua.)
3. **Getting bytecode past L3akMod — embed it as a STRING, don't ship a rawfile.**
   L3akMod intercepts every `.lua`/`.luac` rawfile and tries to compile it;
   fed bytecode it either errors (`.luac` → the bogus `ERR`) or hard-crashes the
   linker (`.lua`-with-bytecode → `0xC00000FF`). So the bytecode does NOT ride as
   its own rawfile. Instead: convert the `.luac` bytes to a Lua **`\ddd`
   (3-digit, zero-padded)** string constant and paste it into a normal source
   `.lua` that L3akMod compiles. That outer file names **only** whitelist-clean
   globals (`load`/`pcall`/`type`/`tostring`/`Engine`) — never `io`/`os` — so it
   compiles fine, carrying the bytecode inert as string data.
4. **Loading it at runtime — `load(reader)`, NOT `load(string)`.** HKS `load` is
   5.1-strict: `load(string)` THROWS (this bit v5c AND v6 run 1). Pass a **reader
   function** that returns the bytecode string once then nil:
   `load(function() if served then return nil end served=true return BC end)`.
   For bytecode the reader form **undumps** to a callable chunk (no source
   compiler needed — which is why source-strings fail but bytecode works). Then
   `pcall(chunk)` runs it.

Reporting during the spike used the v5a-proven **`Engine.Exec(GetLocalClientNum(),
"set <dvar> <token>")`** bridge (GSC polls the dvar → console_mp.log);
`SendMenuResponse` stays dead from overlays. **Sanitize any value pushed through
Exec** (strip control chars / quotes / `;`) or a multiline Lua traceback splatters
as bogus console commands and can wedge the client (v6 run 1). Files:
`ui/uieditor/menus/hud/acc_lb_spike.lua` (v6 outer, generated by
`scratchpad/gen_v6_spike.js` from `inner_chunk.lua` → `hksc` → `inner_bc_string.txt`),
`_acc_leaderboard.gsc` (opener + dvar dump). hksc.exe + w64devkit live in scratch
(NOT yet in the repo — see "Productionizing" below).

#### Productionizing (next, for the real leaderboard build)

- **Move the toolchain into the repo/build**: commit `hksc.exe` (or a build
  script) under `tools/`, add a `tools/compile_lui_bytecode.js`-style step that
  compiles the leaderboard chunk + splices the `\ddd` string into the source, so
  the build is reproducible. (Decide per asset-portability rules whether the
  hksc binary is tracked or fetched.)
- **~~Resolve `os.execute` (Stage 2)~~ DONE (v7):** `os.execute` + curl work
  from the loaded chunk with no crash (rc 42; curl 559 bytes HTTPS→disk). The
  cloud tier just needs the backend (Cloudflare Worker + DB) + the POST/GET
  wiring; no engine blocker remains. (Watch curl's UI-thread block time at
  game-end; `-m <n>` caps it. Consider `start /B` / async if it hitches.)
- The io round-trip proves the local **record file** write/read; wire the real
  Stage-1 capture (session id + roster + round at `end_game`) to it.

Prove on OUR build what MACHIN[A] proves in theirs. Shipped as
`_acc_leaderboard.gsc` (module wired into `acc_main`, zone, entry `.csc`) +
`ui/uieditor/menus/hud/acc_lb_spike.lua`. **Dev-only** (gated on
`level.acc_dev`; normal-play builds never open the menu). ~2s after
blackscreen it opens the probe menu per player; the Lua runs 4 pcall-guarded
probes at menu-create and **self-logs on four channels** (user 2026-07-11:
"log things yourself so we can see" — no manual transcription; harvest
everything post-run with **`tools/read_lb_spike.ps1`**):

1. **`<game>\players\acc_lb_spike_report.txt`** — the FULL report, appended
   per run with an `os.date()` timestamp (written by the io under test; its
   absence is itself the io answer, still delivered by channel 2).
2. **`console_mp.log`** — every report line is `SendMenuResponse`'d to GSC,
   which `IPrintLnBold`s it (`[ SCRIPTER]` lines — the PROVEN durable engine
   log, docs/17). GSC also `LogPrint`s to `games_mp.log`, but that file has
   **never materialized on this box** (apex memory confirmed 2026-07-11:
   `+set g_log` is passed, no file appears anywhere) — console_mp.log is the
   log of record.
3. On-screen text lines (top-left, teal) — human-visible during the run.
4. The probe artifacts (`players\acc_lb_spike_io.txt` / `_http.txt`).

- **A libs** — `type()` of `io` / `os` / `pcall` / `os.execute` / `os.time` /
  `os.date` / `os.clock` / `io.popen`.
- **B file IO** — `io.open` write → read back a per-run token under `players/`.
- **C exec** — `os.execute("cmd /c exit 42")`, expect rc 42 (side-effect-free).
- **D HTTP** — `os.execute` curl (`-m 6`) → `io`-read the `-o` file back.

Last line prints the verdict: `Stage1 local file: GO/NO · Stage2 cloud:
GO/PARTIAL/NO`. B-pass alone greenlights Stage 1; C+D greenlight Stage 2.
C/D are timed with `os.clock` — the UI-thread hitch (and any console-window
flash) is itself a spike answer; mitigations if bad: `start /B`, `io.popen`,
batch to one call per game end. If B **fails**, fall to Plan B (below).

**BUILD BLOCKER FOUND + SOLVED (2026-07-11) — the real Stage-0 discovery.** The
first spike named `io`/`os` directly in Lua source and **failed the build**:
L3akMod's rawfile compiler has a **link-time global whitelist** and rejects
`io`/`os`/`_G`/`getfenv`/`loadstring` (surfacing as the bogus
`[L3akMod (D3V)] Error: attempt to index global 'ERR'` + exit -1 + no `.ff`).
This is a *compile* block, **separate from the runtime question the spike asks.**
Bisected live: `type(pcall)` builds, `type(io)` does not. **Fix (proven to
compile, now shipped in the spike):** reach `io`/`os` through **`load("… io …")`**
— a string chunk the HKS VM compiles at *runtime*, so the whitelist never sees
the identifier. Full write-up + the whitelist inventory: **docs/19 §"BUILD
GOTCHA: L3akMod rejects non-whitelisted GLOBALS"**. Consequence for the real
build: **all Stage 1/2 `io`/`os`/`os.execute` calls must use the `load()` dodge**
(or ship precompiled `.luac`, the other bypass — likely how MACHIN[A] does it).
The spike now **builds clean** (fresh `.ff` 2026-07-11); it still needs the
in-game dev run to answer the runtime half (does HKS actually expose `io`/`os`).

#### Iteration ledger (4 live runs, 2026-07-11) — what each death taught

| Run | Build | Symptom | Established |
|---|---|---|---|
| 1 (13:40) | v1: probes inline, un-pcall'd `load(string)`, sends at end | UI Error 52112, zero output | GSC lifecycle marker works; console_mp.log = the log of record (`games_mp.log` NEVER materializes despite `+set g_log` — apex memory confirmed) |
| 2 (13:59) | v2: dual-form `load` + everything pcall'd, sends at end | UI Error again, watchdog "no response in 10s" | Death is OUTSIDE the pcall'd probe pass — menu/display/send machinery or deeper |
| 3 (14:16) | v3: create does nothing; UITimer 750ms runs stages; s1 = first `SendMenuResponse` | No UI error report; watchdog fired; **`OpenLUIMenu handle defined=1`** | The file loads + menu registers fine. **`Engine.SendMenuResponse` from an `OpenLUIMenu` overlay never arrives** (3 runs; docs/16 pairs SendMenuResponse with `OpenMenu`/`#precache("menu")`, NOT overlays) — OR the UITimer handler never ran; v4 was built to split that |
| 4 (14:26) | v4: throw-proof probes DIRECTLY in create, breadcrumb to file + dvar per stage; sends demoted to a probe | **CTD** the frame the menu opened; ZERO breadcrumbs (no file header, no dvar) | Something in the first stretch of createMenu is **natively fatal** (pcall can't catch engine AVs). Suspects, in execution order: **(a) calling `load` at runtime** — a bytecode-only HKS build would have no source compiler; `load(reader)` was un-pcall'd, and even pcall wouldn't stop a native AV — **(b) `Engine.SetDvar(nil,…)` / `Engine.Exec(nil,…)` signature roulette** (nil/0 controller args into native code). No Windows Event Viewer record (BO3's own crash handler ate it) |

#### v5 bisect (runs 5a–5c, self-run via `steam.exe -applaunch`) — RESOLVED

The v5 protocol (one pre-announced native call per build, breadcrumbed so a CTD
names its killer) ran to completion. Agent-side launching was fixed here:
`steam://run/<id>//<args>` URLs **jam for scripted callers** even after a Steam
restart, but **`steam.exe -applaunch 311210 <args>`** launches reliably — so
these runs cost the user nothing.

| Run | Adds | Result | Established |
|---|---|---|---|
| 5a (15:08) | `Engine.Exec(GetLocalClientNum(), "set acc_lb_live …")` only | dvar landed, GSC mirrored it, **no CTD** | **The Exec→dvar→GSC bridge WORKS** from an `OpenLUIMenu` overlay — our crash-surviving Lua→GSC telemetry channel (SendMenuResponse stays dead; this replaces it) |
| 5b (15:05) | whole battery, one rolling dvar + `echo` marks | ran to `s9 DONE`, **no CTD**; only the last mark reached GSC; `echo` = "Unknown command" | v4's CTD was NOT `load`/Exec (both fine here) — most likely the **`Engine.SetDvar(nil,…)`/`Exec(nil,…)` nil-controller roulette** v4 did and v5 dropped. All stages run in ONE frame → need per-stage dvars |
| 5c (15:14) | per-stage `acc_lb_<tag>` dvars + GSC dump at +22s | **full trace delivered**, no CTD | **THE ANSWER (below)** |

#### THE FINDING — runtime `load()` cannot compile source; the dodge is DEAD

v5c's per-stage dump, verbatim:
```
[s0] entered pcall=true load=true          <- both globals EXIST
[s1b] AFTER pcall_load ok=false ret=string <- load("return 1") THREW (5.1-strict: rejects a string arg)
[s1c] reader-form ok=true ret=nil          <- load(readerfn) did NOT throw but returned NIL, not a function
[s2b] SKIP no chunk - runtime load unusable
[s3b..s6b] load ABSENT or chunk-compile failed   <- every io/os probe unreachable
[s7] VERDICT Stage1_local_file=NO Stage2_cloud=NO
```
**`load` is present but is a bytecode-only stub — retail shipped HKS has NO
runtime *source* compiler.** `load(string)` throws; `load(reader)` returns nil
for valid source text (it would only accept precompiled bytecode). So the
**`load("… io …")` runtime-eval dodge — our only way to name `io`/`os` without
tripping L3akMod's compile-time whitelist — cannot work.** Both independent
routes to reference `io`/`os` in usermap LUI are now closed:
1. name them in source → **L3akMod build whitelist rejects them** (docs/19);
2. name them in a runtime-compiled string → **no runtime source compiler**.

The io/os *runtime presence* question is therefore **still unanswered** — we
could never construct a reference that both compiles and runs. But the space of
solutions has collapsed to exactly one in-engine route + the fallback:

- **`.luac` precompiled bytecode** (the ONLY remaining in-engine route). Ship a
  rawfile that is already HKS bytecode naming `io`/`os` — bypasses BOTH blocks
  (not source, so no whitelist; not `load()`, so no runtime compiler needed;
  the linker embeds it as an asset). **MACHIN[A] definitively ships `io`/`os`
  this way** (its `save.lua` const pool + the `.dat` file on disk — docs/40
  research). Cost/risk: producing T7-HavokScript-compatible bytecode needs an
  HKS `luac` (Havok's, or captured from L3akMod's own compile output). This is
  reverse-engineering a toolchain — real work, uncertain, but **proven possible
  by MACHIN[A]**. Whitelist-patching L3akMod's DLL is a worse variant (shared
  tool, fragile).
- **Plan B — companion app** (no in-engine io needed). `LogPrint`… — actually
  `games_mp.log` never materializes here (confirmed again this session), so out
  = the `console_mp.log` `[ SCRIPTER]` channel we've been harvesting all along;
  in = launch-time dvars. A desktop helper tails the log → cloud; writes a top-10
  dvar cfg the launcher execs. Requires opted-in players to run an external app.

**Spike status: the probe stays live + dev-gated but is now inert-by-outcome**
(it reports `S1=NO S2=NO` every run because it can't reach io/os). Decision on
which route to take is the user's — see the session hand-off.

#### `.luac` route — MACHIN[A] fastfile dissected (2026-07-11, user chose this route)

Decompressed MACHIN[A]'s shipped fastfile
(`workshop/content/311210/3708647045/zm_trenches_early.ff`, via
`scratchpad/ff_dump.js`/`ff_extract2.js` built on `tools/ff_grep.js`) and read
its `ui/uieditor/shared/save.lua` rawfile bytes directly. Findings — the whole
recipe, verified from the shipped bytes:

1. **It is BYTECODE, not source.** Immediately after the rawfile name
   `ui/uieditor/shared/save.lua\0` come the bytes
   `1b 4c 75 61 51 0e 01 04 08 04 04 00 …` = `\x1bLua` · version `0x51` (5.1) ·
   **format `0x0e` (14 = HavokScript)** · little-endian · int 4 · size_t 8 ·
   Instruction 4 · Number 4 · then the HKS **14-entry type table**
   (`TNIL TBOOLEAN TLIGHTUSERDATA TNUMBER TSTRING TTABLE TFUNCTION TUSERDATA
   TTHREAD TIFUNCTION TCFUNCTION TUI64 TSTRUCT`). Vanilla Lua 5.1 `luac` (format
   `0x00`, no type table) will NOT match — a T7-HavokScript compiler is required.
   The rawfile is NAMED `.lua` but CONTAINS bytecode → L3akMod's source
   compiler (and its whitelist) is never invoked; the linker embeds the bytes.
2. **THE io/os UNLOCK = `EnableGlobals()` / `DisableGlobals()`.** The save.lua
   constant pool (in order) is: `EnableGlobals · require ·
   UI.UIEditor.Shared.Utils · Trenches · SaveData · … · Encrypt · Decrypt ·
   DisableGlobals`, and the chunk contains `io`×9, `os`×6, `open`, `write`,
   `read`, `execute`, `.\players\311210\`, `GetXUID`. **HavokScript locks the
   stdlib globals by default; `EnableGlobals()` unlocks `io`/`os`/etc., you do
   the file work, then `DisableGlobals()` re-locks.** This is the missing call —
   our earlier probes never made it, so even a runtime that HAS io/os would read
   them as nil. (It also means once we can emit bytecode, the source is simply:
   `EnableGlobals(); … io.open …; DisableGlobals()`.)

**Target format to emit** (match MACHIN[A] byte-for-byte): `\x1bLua` `0x51`
`0x0e` little-endian, int4/size_t8/instr4/number4, + the 14-type table. Blocked
on: a T7-compatible HavokScript compiler (`hksc`) — research in flight. Then the
recipe is: write source (`EnableGlobals()` … io/os … `DisableGlobals()`) →
compile with hksc → ship the `.luac` as a `rawfile,ui/…/x.lua` line → load with
`LuiLoad`/`require`. First milestone once hksc lands: a self-test that our
linker embeds a bytecode-bearing `.lua` rawfile (vs trying to recompile it).

### ✅ CLOUD BACKEND LIVE (2026-07-11) — Cloudflare Worker + D1, deployed & verified

`backend/leaderboard/` is **deployed and smoke-tested green**:
- URL: `https://acc-leaderboard.jordana-urbaez.workers.dev` (account
  `ac0e276b127d1b8ae9eb7c73fd2ceedb`, D1 db `acc_leaderboard`). URL + the
  `x-acc-key` write key are in the gitignored `backend/leaderboard/deployed.local.json`
  (the key ships in the game bytecode anyway; kept out of git history).
- Verified live: `GET /health`→`ok`; `POST /games` with key→`{"ok":true}`;
  **POST without key→401**; `GET /top10.txt`→`88|Carol,Dave,Eve,Frank` /
  `42|Alice,Bob` (round-DESC, Lua-ready); dedup upsert + per-IP rate limit +
  round clamp active. Test rows cleared; board starts empty.
- Tune/patch anytime with `wrangler deploy` — no game rebuild.

~~Remaining work is entirely **game-side**~~ — **DONE same day**: the capture +
the station shipped (moved to the **Plaza** per the user); see "✅ SHIPPED" at the
top of this doc.

### ▶ IMPLEMENTATION DESIGN (2026-07-11) — user picked **Cloud + MongoDB-ish + Card**

User decisions (2026-07-11): (1) **Cloud** global board; (2) backend "**something
super simple like MongoDB**" — but the game speaks only curl/HTTPS and Mongo's own
curl path (Atlas Data API) was on a deprecation path at the knowledge cutoff, so
the exact backend is under research (Supabase/Upstash/Worker+D1 are natively
curl-able; Mongo may need a thin HTTP shim); (3) **Card** display (server-HUD
`_acc_ui::card_show`, not a LUI panel).

**THE GSC↔LUI BRIDGE — SOLVED, no string channel needed.** The hard part (getting
gamertag *strings* from the GSC server to the LUI chunk that curls) dissolves
because **LUI can read every player's name client-side**: the Aetherium scoreboard
already does `Engine.GetModelValue( Engine.GetModel( Engine.GetModelForController(
controller ), "PlayerList.<i>.playerName" ) )` for `i=0..3`
(`AetheriumScoreboard.lua:467`). So the LUI bytecode chunk gathers the roster
itself.

> **GOTCHA — resolve `playerName` through `Engine.Localize`, never `tostring()` (fixed
> 2026-07-14).** A `PlayerList.<i>.playerName` model value is NOT always a Lua string: an
> empty/stale slot returns a **userdata reference** to a localized-string entry, and
> `tostring(userdata)` yields the raw handle `"userdata: 0000..."`. The scoreboard resolves it
> via `Engine.Localize` before `setText` (`AetheriumScoreboard.lua:468`) — the record chunk
> now does the same (`resolve_name()`). Belt-and-braces: the chunk's `clean()` and
> the Worker's `cleanName()` both reject `userdata:`-prefixed values. Symptom before the fix:
> `npm run summary` flagged `userdata: 00000000000000` roster entries (13 DB rows repaired).
>
> **LADDER COROLLARY — scrub the NAME, never the SLOT (fixed 2026-07-15).** The 07-14 fix also
> *dropped* every unresolvable tag, and the Worker filtered `"?"` a second time — but a userdata
> playerName is a **real teammate** whose tag didn't resolve, not an empty slot (empty slots give
> `nil`/`""`; proof: 97 solo games recorded exactly ONE name under the same guard). Since lobby
> size is stored as the roster **entry count** (`commas + 1`) while the board *asks* for its
> ladder with a PlayerList **slot** count (`acc_lb_board_chunk.lua`, matching `GetPlayers().size`),
> dropping an entry filed a quad under the TRIO ladder — invisible to its own `?v2=4` board and
> outranking real trios. Both stages now **keep the slot and store `"?"`** (exactly what the 13
> repaired rows carry), so write-count and read-count agree. Same lesson as that repair: **never
> change the entry count.** Only **numerics** cross GSC→LUI, via the existing clientfield pipeline:
`session_id` (host-minted number, broadcast so all clients agree), `round`, an
`is_recorder` flag (host only), and a `do_record` trigger. Timestamp = `os.time()`
in LUI. So the full data path uses ONLY proven mechanisms:
- GSC→LUI: clientfields (session/round/flags) — the docs/19 pipeline.
- LUI-native: `PlayerList.<i>.playerName` (roster), `os.time` (ts).
- LUI→cloud: `os.execute` curl POST (record) + curl GET (top-10) — proven v7.
- LUI→GSC: `Engine.Exec`→dvar (the ~10 top-10 display lines) — proven v5a.
- Display: `_acc_ui::card_show(title, lines[])` — exists today.

**Record capture flow:** GSC mints `session_id` at `initial_blackscreen_passed`,
marks the host `is_recorder`, sets `do_record`=1 at `end_game`. The recorder
client's LUI chunk (on `do_record`) gathers roster+round+session+ts → builds the
JSON record → writes the local file (offline cache) → curl POSTs it. **Display:**
at the trench terminal, any client's LUI chunk curl-GETs top-10 → parses → pushes
~10 lines to GSC via dvars → `card_show`. Offline / GET-fail → show the local-file
board. The bytecode chunk is compiled with `tools/build_lui_bytecode.js`
(hksc → `\ddd` string → spliced into an outer L3akMod source), and must
`EnableGlobals()` before any io/os. **Anti-abuse (shipped key is extractable):**
casual board — server-side plausibility checks + rate limit in the backend; light
cheating tolerated (serious records stay zwr.gg-style).

### Stage 1 — LOCAL leaderboard (ships to every subscriber, no backend)

- **Record**: one line/row per finished game:
  `session_id | round | names[1..4] | xuids[1..4] | duration_ms | os.time()`.
  LUI owns the file (versioned header, cap ~500 rows, prune worst). Every
  client writes its own copy — each machine's board reflects games *that
  machine played in* (solo + co-op both captured client-side).
- **Session id**: minted once by host GSC at `initial_blackscreen_passed`
  (hex chunks from `RandomInt` — no wall clock in GSC; `GetTime()` is
  match-relative ms) and broadcast via UIModel so all 4 clients record the
  SAME id. LUI adds `os.time()` for the real timestamp.
- **Capture hook**: `level waittill("end_game")` (the docs/15 §meta-progression
  hook), snapshot `level.round_number` + roster. Roster is tracked from
  `_acc_main::on_player_connect` (guard disconnected ents — memory
  `gsc-t7-runtime-traps`); `player.name` = gamertag (in-repo precedent
  `_acc_data_shards.gsc:397`). Belt-and-braces: push the roster/round UIModel
  every round start (UEM-style) so a crash still leaves a valid last-known row.
- **Ranking**: round DESC, then earlier `os.time()` wins (first to set it).
- **Privacy gate (MACHIN[A] precedent)**: first interact shows a one-time
  "enable saving game records?" yes/no, persisted in the file itself; default
  OFF until accepted. Writes only ever touch `players\` — same folder the game
  already owns.

### Stage 2 — GLOBAL leaderboard (the user's DB + top-10 API)

- **Backend** (UEM-proven stack): **Cloudflare Worker + D1 or Supabase**.
  Two endpoints: `POST /games` (upsert by `session_id`, server takes
  `max(round)`, stamps `received_at`) and `GET /top10` (cached, e.g. 60s).
  Table: `games(session_id PK, map_version, round, players jsonb, duration_ms,
  client_ts, received_at)`.
- **Upload**: at `end_game` (plus optional per-round checkpoint upserts for
  crash-resilience). All 4 clients may upload the same session — the
  session-id upsert dedupes server-side, no host-election needed.
- **Fetch**: at map load (and on terminal interact, throttled), `curl -s -m 3
  -o players\acc_lb_top10.json <api>/top10`, then `io.read` + parse (write a
  tiny Lua JSON-subset parser or serve a `|`-delimited format — simpler).
  Offline = show local board only; never block on the network.
- **Trust — be honest**: anyone can extract the FF and forge POSTs. HMAC the
  payload with an obfuscated key baked in the Lua (raises the bar, doesn't
  eliminate), server-side plausibility checks (round vs duration_ms, rate
  limit per IP/XUID), and a manual-flag admin path. This is a *casual* board —
  serious records stay zwr.gg-style video-verified. Same trust tier UEM ships.
- **Consent**: uploads ride the same opt-in gate as Stage 1 (explicitly
  mention "sends gamertags + round to our server"). CREDITS/privacy note in
  the Workshop description before publish.

### Trench terminal (display object) — all in-repo recipes

- **Placement**: the **south "Foundry" under-room** (open space) or the north
  under-room wall opposite the jukebox (docs/28; reactor owns the center).
  GSC-spawned like the jukebox — zero `.map`/LED-bake cost, `-GscOnly` builds.
- **Recipe**: clone `_acc_jukebox.gsc` — `spawn("script_model")` +
  `trigger_radius_use` + `TriggerIgnoreTeam()` + `SetCursorHint("HINT_NOICON")`
  + collision via `tools/add_prop_clips.js` (check the `_col`-LOD rule, memory
  `prop-clip-col-lod-test`).
- **Hint router guard**: hint = `"Hold ^3[{+activate}]^7 View Leaderboard"` —
  no `" for "`, no `[Cost:]`, no pack/perk/door/power keywords, so
  `ZMCursorHintNew.lua` falls through to `PromptDefault` (memory
  `lui-cursorhint-router-loose-weapon-matcher`).
- **Render**: v1 = `_acc_ui.gsc::card_show(title, lines[])` (exists today,
  auto-fits ~10 lines; change-guard the strings — 2048 `SetText` cache,
  docs/19). v2 = a real LUI panel (4-file contract, docs/19 §262) rendered
  client-side straight from the file/fetch — **zero** GSC string-cache cost
  and room for tabs (LOCAL | GLOBAL). v2 is where the kelson8
  `OpenMenu`/`SendMenuResponse` blueprint (docs/16 §menu round-trip) finally
  gets used.

### Plan B (only if the Stage-0 spike refutes LUI `io` on our build)

Opt-in **companion app**: GSC `LogPrint("ACCLB;…")` → tail `games_mp.log` →
POST to the same Worker; inbound via launcher `+set acc_lb_rows_1..N` dvars;
plus a **nightly Workshop republish** baking the top-10 into the map for
subscribers without the companion. Strictly worse UX — only if forced.

## Build order (proposed)

1. Stage-0 spike — **BUILT 2026-07-11** (see above), pending an in-game run.
2. `_acc_leaderboard.gsc` + `ui/.../acc_leaderboard_save.lua`: session id,
   roster tracking, end_game capture, local file, card_show top-10 at the
   terminal. **Ships value immediately.**
3. Cloudflare Worker + D1 (tiny; deploy free tier), curl POST/GET wiring,
   GLOBAL tab.
4. LUI panel upgrade + polish (consent UX, offline handling, admin flag path).

## Open questions / risks

- `os.execute` UX (console-window flash, frame hitch) — measure in the spike.
- Lua stdlib surface: MACHIN[A] proves `io`+`os.execute`; `os.time`/`io.popen`
  are LIKELY-present stdlib siblings but unverified — spike them too.
- A future BO3 patch stripping `io`/`os` would kill Stage 1+2 (low risk —
  BO3's last patch era is long past; MACHIN[A] ships on it today).
- Split-screen: two local players share one machine/file — fine (one record).
- Mac: use the `PATH_MAC` fallback + `curl` exists on macOS; test later.
- docs/15 §`meta-progression-layer` asked "archived dvars vs
  CodPersistentData?" — **answer: neither; LUI `io` files.** The same channel
  later unlocks PB-per-modifier-set meta-progression.

## Sources

- MACHIN[A] save system: local FF decompile (`ui/uieditor/shared/save.lua`
  const pool) + `players\311210\save_trenches.dat` on this machine.
- UEM: cliftonvanhenten.com/ultimate-experience-mod · uem.wiki.gg ·
  steamcommunity.com/sharedfiles/filedetails/?id=2942053577
- BOIII GSC I/O (contrast, custom-client only):
  github.com/Ezz-lol/boiii-free/blob/main/docs/gsc-scripting.md
- LUI HTTP-via-DLL (contrast): github.com/JariKCoding/T7Overcharged
- Plutonium round-tracker (contrast):
  forum.plutonium.pw/topic/3649 (Cahz, fopen-based)
- Records community (manual verification): zwr.gg/submit · codzombiestracker.com
- Stock LogPrint precedent: `tmp/bo3_stock_ref/scripts/shared/ai_shared.gsc:719`,
  `scripts/zm/gametypes/_globallogic_player.gsc` (live `logPrint` K-lines in ZM)
