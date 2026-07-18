# Leaderboard backend — Cloudflare Worker + D1

The cloud half of the map's leaderboard (docs/40). The game can only reach the
outside world via **curl HTTPS**, so this Worker exposes two endpoints it hits:

| Method | Path | What |
|---|---|---|
| `POST` | `/games` | record a finished game (JSON body; dedup by `session`) |
| `GET`  | `/top10.txt` | the top 10 as plain text, one row per line: `round\|name1,name2,…` (Lua parses this with no JSON lib). With `?v2=N` a LAST line `T\|<games>\|<wins>` carries the board's map-wide totals footer (all games ever recorded / Paradise wins — GLOBAL, never filtered by the `v2=N` lobby-size ladder) |
| `GET`  | `/top10.json` | same data as JSON (web/debug) |
| `GET`  | `/health` | liveness check |

Free tier is *enormous* relative to this workload (100k requests/day, 100k
row-writes/day) and **never pauses for inactivity**. No credit card required.

## Deploy (wrangler — recommended, ~5 minutes)

You need [Node.js](https://nodejs.org) (already on this box) and a free
Cloudflare account.

```bash
cd backend/leaderboard

# 1. one-time: install + log in (opens a browser)
npm install -g wrangler
wrangler login

# 2. create the D1 database, then paste the printed database_id into wrangler.toml
wrangler d1 create acc_leaderboard
#   -> copy the "database_id = ..." value into wrangler.toml

# 3. create the table (‑‑remote = the real cloud DB, not a local copy)
wrangler d1 execute acc_leaderboard --remote --file=schema.sql

# 4. (optional but recommended) set the shared write key
wrangler secret put ACC_KEY
#   -> type any random string; the game will send it as the x-acc-key header.
#      Skip this to run an open board (anyone can POST).

# 5. deploy — prints your URL, e.g. https://acc-leaderboard.<you>.workers.dev
wrangler deploy
```

**Then send me two things** and I bake them into the game build:
1. the deployed URL (`https://acc-leaderboard.<you>.workers.dev`)
2. the `ACC_KEY` value you chose (if you set one)

## Deploy (dashboard — no CLI)

1. Cloudflare dashboard → **Workers & Pages → Create → Worker**, name it
   `acc-leaderboard`, deploy the placeholder, then **Edit code** and paste
   `worker.js`.
2. **Storage & Databases → D1 → Create** a database named `acc_leaderboard`;
   open its **Console** and paste the contents of `schema.sql`, run it.
3. Back in the Worker → **Settings → Bindings → Add → D1 database**: variable
   name `DB`, database `acc_leaderboard`.
4. (optional) Worker → **Settings → Variables and Secrets → Add** a secret
   `ACC_KEY`.
5. Deploy. The URL is on the Worker's overview page.

## Smoke test (after deploy)

```bash
URL=https://acc-leaderboard.<you>.workers.dev
curl "$URL/health"                                  # -> ok
curl -X POST "$URL/games" -H "content-type: application/json" \
     -H "x-acc-key: <your ACC_KEY>" \
     -d '{"session":"test1","round":42,"players":["Alice","Bob"],"ts":1,"map_version":"dev"}'
#   -> {"ok":true}
curl "$URL/top10.txt"                               # -> 42|Alice,Bob
```

## Cleanup: split-session dedupe (`npm run cleanup`)

`session_id` is the games PRIMARY KEY, so literal duplicate ids cannot exist — but the
SAME GAME can land under TWO ids if the game's session-dvar read hiccups mid-match and
mints a fresh one (the GSC re-asserts the dvar every record since 2026-07-18, so this
mainly concerns historic rows). `cleanup.js` drives the Worker's `/admin/dedupe`:

```bash
# one-time setup: a SEPARATE admin secret (never shipped in the game - the extractable
# ACC_KEY must never authorize deletes), then redeploy worker.js
npx wrangler secret put ADMIN_KEY        # or dashboard Variables
# put the same value in deployed.local.json as "admin_key" (or $ACC_LB_ADMIN_KEY)

npm run cleanup                          # REPORT ONLY - never writes
npm run cleanup -- --apply               # merge clusters verdicted "mergeable"
npm run cleanup -- --sessions=a,b --apply  # manual: delete exactly these ids
npm run cleanup -- --gap=6               # widen the cluster window (default 3h)
```

Detection is conservative: a cluster = identical roster CSV with client_ts gaps under
the window; it is auto-**mergeable** only if every consecutive pair looks like a
continuation of one match (round never decreases, every shared player's
kills/downs/revives component-wise grows — stock counters only grow within a match; a
real new game resets them). Anything else is reported as **suspect** for a human —
same-crew back-to-back games look similar and must never auto-merge. Merges keep the
max-round row, MAX-merge `player_stats`, OR in `paradise_winner`. The anonymous `gun_*`
tables are untouched (`game_key` is an HMAC of the session — deliberately unjoinable).

## Notes

- **Anti-abuse is best-effort** (docs/40): the write key ships inside the game
  and is extractable, so a determined cheater can still POST fake scores. The
  Worker does the cheap high-value gates (key check, field clamping, round
  bounds `1..2000`, per-IP rate limit, dedup-by-session). Serious records stay
  video-verified (zwr.gg). If abuse happens, tighten `worker.js` and redeploy —
  no game rebuild needed.
- **Dedup:** co-op sends one POST per client for the same game; the
  `ON CONFLICT(session_id)` upsert keeps one row (highest round).
- **Schema/logic changes** never require a game update — only `wrangler deploy`.
