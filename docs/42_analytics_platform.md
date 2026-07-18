# 42 — The Analytics Platform (cloud DB + telemetry pipeline)

**This is the map's path forward for ANY online feature** (user, 2026-07-12: "this
is our path forward for stuff like this and it needs to be bug free"). Two systems
already ride it end-to-end in production: the **global leaderboard** (docs/40) and
**anonymous weapon-usage tracking** (docs/41). This doc is the system-level view +
the runbook for adding the NEXT metric without re-deriving anything.

Backend: Cloudflare Worker + D1 (SQLite) at
`https://acc-leaderboard.jordana-urbaez.workers.dev` — source in
`backend/leaderboard/` (`worker.js`, `schema.sql`, `wrangler.toml`,
`deployed.local.json` = gitignored URL+key).

---

## 1. The pipeline (one diagram)

```
GSC (server VM)                LUI (HKS Lua VM)              off-process           cloud
---------------                ----------------              -----------           -----
collect during play            acc_lb_rec chunk:             hidden .bat agent     Cloudflare Worker
  |                            readdvar("acc_lb_guns")       polls players\ ~1s      |
serialize at end_game          build JSON (omit-empty)       acc_lb_do_post.txt    POST /games (upsert)
  |                            io.open acc_lb_post.json  ->  -> curl POST   ---->    |
SetDvar("acc_lb_guns", blob)   io.open acc_lb_do_post.txt                          D1 tables
  |                                                                                  |
OpenLUIMenu("acc_lb_rec")  ->  (menu open = the GSC->LUI trigger)                  GET /top10, /stats/*
```

Reverse path (station fetch): GSC opens `acc_lb_board` → chunk writes
`acc_lb_do_get.txt` → agent curls `/top10.txt` → chunk reads the result file →
`Engine.Exec 'set acc_lb_rows_*'` → GSC polls the dvars → renders the card.

**Why this shape** (each hop is forced by an engine constraint):
- **GSC has no file/network IO at all.** The ONLY runtime with `io`/`os` is LUI
  (docs/40; memory `retail-lui-io-os-persistence-and-http`).
- **LUI `io`/`os` need `EnableGlobals()`**, and L3akMod's compiler crashes on those
  globals in plain source — so the real logic ships as **hksc bytecode chunks**
  embedded as `\ddd` strings (`tools/lui_chunks/*.lua` → `tools/build_lb_lui.js` →
  `ui/uieditor/menus/hud/acc_lb_*.lua`). Never hand-edit the generated files.
- **`os.execute` spawns a console window that yanks exclusive fullscreen** (the
  2026-07-11 tab-out bug). So the game execs a process ONCE per map load (boot
  chunk, under the load fade) and every later network op is **pure `io`: write a
  trigger file, the pre-spawned hidden agent does the curl** off-process.
- **The agent** (`players\acc_lb_agent_*.bat`) polls ~1s for **~8h** then
  self-deletes. On the dev box the launcher pre-spawns it fully hidden
  (`tools/spawn_lb_agent.ps1` + `+set acc_lb_agent 1` skips the in-game spawn);
  subscribers get the in-game boot via a self-deleting `wscript` SW_HIDE
  trampoline (sub-second flash at most, under the load fade).

## 2. The two PROVEN in-game transports

| Direction | Mechanism | Capacity | Proven |
|---|---|---|---|
| GSC → LUI | `SetDvar("name", blob)` then open the menu; chunk `readdvar()` (multi-arity `Engine.DvarString` read, pcall-guarded) | variable-length string, host-local | ✅ production 2026-07-12 (gun blob → `/stats/guns` correct) |
| LUI → GSC | `Engine.Exec 'set name value'`; GSC polls `GetDvarString` | string dvars | ✅ (board rows, trace breadcrumbs) |
| engine → LUI | UI models (`PlayerList.<i>.playerName`, `gameScore.roundsPlayed`) | engine-owned fields | ✅ (recorder payload) |

Prefer the dvar channel for anything new — it costs no clientfield bits and takes
arbitrary-length strings. (Clientfields remain the fallback for per-entity or
non-host client state; the actor bit budget is FINITE — memory
`actor-clientfield-bit-budget`.)

## 3. Runbook — adding a new metric (follow `_acc_weapon_usage` as the template)

1. **Collect (GSC).** New module `_acc_<metric>.gsc`, wired in `acc_main`. Sample
   or count into a `level.` accumulator. **Dev/god → collect nothing** (return
   early on `IS_TRUE(level.acc_dev) || IS_TRUE(level.acc_god)` — user rule:
   assisted runs never stored).
2. **Stable ids.** Numeric ids from an **append-only registry** + generator
   (pattern: `tools/gun_ids.json` + `tools/gen_gun_ids.js` regenerates the GSC
   switch AND the inlined worker label map between `// <<< BEGIN GENERATED`
   markers). Never renumber; retire with tombstones.
3. **Serialize + publish (GSC, end_game).** Compact string (`"id:val,id:val"`,
   ascending). In `_acc_leaderboard.gsc::record_at_end_game`, `SetDvar` your blob
   right before `OpenLUIMenu("acc_lb_rec")`. Also CLEAR it in your module's
   `init()` (stale-leak guard — a host dvar survives across games in one app
   session).
4. **Extend the rec chunk** (`tools/lui_chunks/acc_lb_rec_chunk.lua` ~line 132):
   `local x = readdvar("acc_lb_<metric>")`, append to the JSON **only when
   non-empty** (`if x ~= "" then j = j .. ',"<metric>":...' end`) — absent field =
   graceful degradation, the leaderboard record still posts. Then
   `node tools/build_lb_lui.js` (regenerates the bytecode) and a `-GscOnly` build
   (repacks the rawfile).
5. **Backend.** `schema.sql`: new table keyed `(game_key, <id>)`. `worker.js`
   `POST /games`: parse your field **inside its own try/catch AFTER the games
   upsert** (a malformed analytics payload must NEVER break the game record),
   clamp everything (id range, value caps, count caps, sanity budget vs
   duration×players), upsert idempotently (`ON CONFLICT ... DO UPDATE`). Add a
   read endpoint `GET /stats/<metric>.txt|.json`. Deploy:
   `cd backend/leaderboard && npx wrangler deploy` (D1 DDL via
   `npx wrangler d1 execute acc_leaderboard --remote --command "..."` — `--file`
   hits an auth bug).
6. **Verify.** Dump the accumulator at end_game in a dev build — debug prints
   ride `IS_TRUE( level.acc_dev )`, never a new per-channel dvar (the per-feature
   debug dvars were removed 2026-07-16; see docs/22 §E) — then after one real
   non-dev game, `curl <url>/stats/<metric>.txt`. The pipeline **self-verifies in production**
   by design — every layer degrades to "field absent", so a broken new metric
   shows up as missing data, never as a broken game.

## 4. Invariants — what "bug free" means here (each learned the hard way)

- **Never spawn a process after boot** (fullscreen tab-out) and **never
  `os.execute` inside a UITimer callback** (froze the engine — boot chunk header).
  All post-boot network = trigger files.
- **Never block the game thread on network.** GSC fire-and-forget + the agent; the
  board fetch polls dvars with a timeout and a "local" fallback.
- **Dev/god records NOTHING.** Enforced at collect (module init/connect) AND at
  record (`record_at_end_game` skips before any dvar publish).
- **Every layer degrades gracefully.** pcall around every `io`/`Engine` call in
  chunks; omit-when-empty JSON fields; worker ingests analytics in isolated
  try/catch; board falls back to cached/local rows. A total backend outage costs
  features, never crashes or hangs.
- **On-screen debug prints gate on `IS_TRUE( level.acc_dev )`** (the per-channel
  `acc_lb_debug` / `acc_wpn_debug` dvars were removed 2026-07-16 — debug rides the
  one dev flag; memory `debug-banners-gated-by-acc-dev-only`). `IPrintLnBold`
  draws on EVERY player's screen — route all diagnostics through the module's
  `*_log()` helper, never call it raw (silent in a ship build by construction).
- **POSTs are idempotent** (upsert keyed on the session-derived `game_key`) —
  duplicate agents / re-fired triggers / retries are all benign.
- **Never trust the client.** Server-side clamps + sanity budgets on every field;
  the rate limit counts recent inserts. `ACC_KEY` ships inside the fastfile =
  extractable = spam gate ONLY. Real secrets (e.g. `GUN_KEY_SECRET` for HMAC game
  keys) live in **wrangler secrets**, never in game files or git.
- **Anonymity by construction.** Aggregate before the data leaves the game; the
  analytics tables key on HMAC'd game keys, unjoinable to gamertags.
- **Dvar transport hygiene.** Clear at `init()`, publish fresh at end_game, and
  keep payloads single-line (dvars are strings; the serializer never emits
  spaces/quotes).
- **worker.js stays dashboard-safe**: zero imports — generated constants are
  INLINED between markers (a JSON import broke a deploy once).
- **Agent protocol lockstep**: the boot chunk and `spawn_lb_agent.tpl.ps1` must
  implement the SAME files/handshake (ping/pong, post, get + `ACCEOF` markers —
  strip the marker before parsing GET results; curl output has no trailing
  newline). Lifetime 28800 loops ≈ 8h in BOTH.
- **HKS quirks**: 32-bit floats (`os.time()` prints e-notation — never use it for
  tokens; table-address entropy instead); L3akMod global whitelist (docs/40);
  generated-file rule (edit `tools/lui_chunks/`, run the builder).
- **Interact hints**: any new station's `SetHintString` must dodge the LUI
  cursor-hint router's loose matchers (memory
  `lui-cursorhint-router-loose-weapon-matcher`).

## 5. Live schema + endpoints (2026-07-12)

- `games` (leaderboard): session, names, round, map_version… → `GET /top10.txt|.json`
- `gun_time`: `(game_key, gun_id) → seconds, end_round, players, map_version` →
  `GET /stats/guns.txt|.json` (held-time share %, pick rate, `?map_version=&limit=`)
- `gun_box` (Tier B, docs/41 §3.8): `(game_key, gun_id) → offers, takes…` → the same
  `/stats/guns` gains `take_rate` + `?sort=take` (availability-free acquisition pref).
- `gun_drop` (Tier C, docs/41 §3.9): `(game_key, gun_id) → acquires, replaced…` → the
  same `/stats/guns` gains `replace_rate` + `?sort=replace` (availability-free RETENTION:
  once held, kept vs voluntarily swapped; death/down/Mule losses excluded in GSC).
- `POST /games` (x-acc-key) carries the whole per-game payload: leaderboard fields
  + optional `duration_secs` + optional `guns:[{id,secs}]` + `box:[{id,offers,takes}]`
  + `drop:[{id,acq,rep}]` + future metrics.

> **✅ Deployed 2026-07-12 (Worker version `fd9f4c8a`):** `gun_box` (Tier B) + `gun_drop`
> (Tier C) tables created on remote D1 and the updated Worker is live — `/stats/guns` now
> serves `take_rate` + `replace_rate` (both `null` until games running a build with the box
> hooks / carried-set diff actually POST `box`/`drop` arrays). Migration was run via the
> **`--command`** form (`--file` hits an auth bug, §3 step 5): `SQL=$(sed 's/--.*$//'
> schema.sql); npx wrangler d1 execute acc_leaderboard --remote --command "$SQL"` — comment-
> stripped because every quote char in `schema.sql` lives in a comment. Remaining step:
> a flags-off in-game run on the new build to populate the values.

**One POST per game, one payload, many tables.** Extend the payload; don't add a
second POST path.

## 6. Future-metric backlog (all ride the same POST unchanged in shape)

Perk purchase counts (popularity board) · PaP tier reached per gun (investment vs
usage) · deaths by zone/round (heatmap → balance the punishing middle) · boss
encounters: type, round, time-to-kill, wipes · economy flow (shards earned/spent
by source/sink, docs/32) · door-open order + round (route analysis) · Cyberware
node picks · challenge/lockdown completion rates · quit-round distribution
(difficulty cliff finder). Each is: accumulator → id registry → one dvar → one
JSON field → one table → one stats endpoint.

## 7. Change checklist (copy into any analytics PR)

- [ ] Collector skips dev/god; accumulator level-scoped; init clears its dvar
- [ ] Ids append-only via registry+generator; GSC switch + worker labels regenerated
- [ ] Rec chunk field omit-when-empty; `node tools/build_lb_lui.js` run; `-GscOnly` build
- [ ] Worker ingest isolated try/catch + clamps; upsert idempotent; wrangler deployed
- [ ] Debug prints behind `IS_TRUE( level.acc_dev )` (never a new dvar) — nothing on subscriber screens
- [ ] Verified: accumulator dump on a dev-build test run, then `/stats/<x>` after a real game
- [ ] docs/40-42 + CHANGELOG updated
