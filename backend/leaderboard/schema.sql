-- Abandoned Cyber City leaderboard - D1 (SQLite) schema.
-- Apply once at deploy: `wrangler d1 execute acc_leaderboard --file=schema.sql`
-- (or paste into the D1 console in the Cloudflare dashboard).

CREATE TABLE IF NOT EXISTS games (
  session_id      TEXT PRIMARY KEY,   -- unique per game (host-minted); dedups co-op multi-POST
  round           INTEGER NOT NULL,   -- round reached (the ranking key)
  players         TEXT NOT NULL,      -- comma-separated gamertags (already sanitized by the Worker)
  client_ts       INTEGER,            -- os.time() from the game client (seconds)
  map_version     TEXT,               -- map build tag, for filtering across versions later
  ip              TEXT,               -- for best-effort per-IP rate limiting
  received_at     INTEGER,            -- server unixepoch() at insert
  paradise_winner INTEGER NOT NULL DEFAULT 0  -- 1 = this run beat the Paradise finale (docs/40 winner tag)
);

-- MIGRATION for an EXISTING database (the CREATE above only fires on a fresh DB, and this
-- file is meant to be re-runnable, so the ALTER is NOT an executable line here - it is not
-- idempotent). Run this ONCE by hand to add the winner column to a table created before
-- 2026-07-12; it errors "duplicate column name" if already applied - safe to ignore. The
-- Worker degrades gracefully until it lands (best-effort UPDATE on write, column-probe
-- fallback on read), so deploy order does not matter:
--   wrangler d1 execute acc_leaderboard --remote --command "ALTER TABLE games ADD COLUMN paradise_winner INTEGER NOT NULL DEFAULT 0;"

-- ranking + rate-limit lookups
CREATE INDEX IF NOT EXISTS idx_games_round ON games (round DESC, received_at ASC);
CREATE INDEX IF NOT EXISTS idx_games_ip    ON games (ip, received_at);

-- ---------------------------------------------------------------------------
-- Anonymous per-gun HELD-TIME usage telemetry (docs/41). Additive migration -
-- re-run this file (all CREATE ... IF NOT EXISTS) to apply, no rebuild.
-- ANONYMITY: the payload is an all-players AGGREGATE before it leaves the game (no
-- per-player gun vector), so no individual is attributable in co-op. game_key is a
-- KEYED hash of the session (worker.js hashGameKey): with GUN_KEY_SECRET set it is
-- HMAC-SHA256(secret, session) -> a D1 reader CANNOT recompute it from
-- games.session_id, so gun_time is genuinely unjoinable to gamertags. Without the
-- secret it falls back to a plain digest a DB operator could recompute (a solo game
-- becomes operator-joinable; co-op stays anonymous). Set the secret for the strong
-- guarantee. game_key is never the raw session_id, and no gamertags are stored here.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS gun_time (
  game_key    TEXT NOT NULL,       -- sha256(session) truncated; dedup key ONLY, no PII, unjoinable to games
  gun_id      INTEGER NOT NULL,    -- canonical base-gun id (0 = other); tools/gun_ids.json
  seconds     INTEGER NOT NULL,    -- team-summed held-in-hands secs this game
  end_round   INTEGER,             -- denormalized -> weighted stats without a join (docs/41 round-weighting)
  players     INTEGER,             -- denormalized player count -> clamp/normalize without a join
  map_version TEXT,                -- per-build filtering
  received_at INTEGER,
  PRIMARY KEY (game_key, gun_id)   -- dedup: one row per (game, gun); re-POST (marathon/co-op) UPSERTs, never doubles
);

CREATE INDEX IF NOT EXISTS idx_gun_time_gun  ON gun_time (gun_id);
CREATE INDEX IF NOT EXISTS idx_gun_time_mapv ON gun_time (map_version, gun_id);

-- ---------------------------------------------------------------------------
-- Tier-B box telemetry (docs/41 §3.7): per-gun OFFER/TAKE counts per game.
-- take_rate = SUM(takes)/SUM(offers) is conditioned on the offer, so box
-- availability cancels out entirely - the availability-FREE preference metric
-- (pref_index only approximates it via the nominal box weights). Same anonymity
-- model as gun_time (aggregate-only payload, keyed game_key, no gamertags).
-- Additive migration - re-run this file to apply, no rebuild.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS gun_box (
  game_key    TEXT NOT NULL,       -- same keyed hash as gun_time (worker.js hashGameKey)
  gun_id      INTEGER NOT NULL,    -- canonical base-gun id; tools/gun_ids.json
  offers      INTEGER NOT NULL,    -- times the box landed on this gun this game
  takes       INTEGER NOT NULL,    -- times a player grabbed it (takes <= offers, worker-clamped)
  end_round   INTEGER,             -- denormalized (mirrors gun_time)
  players     INTEGER,             -- denormalized player count
  map_version TEXT,                -- per-build filtering
  received_at INTEGER,
  PRIMARY KEY (game_key, gun_id)   -- dedup: re-POST (marathon/co-op) UPSERTs, never doubles
);

CREATE INDEX IF NOT EXISTS idx_gun_box_gun  ON gun_box (gun_id);
CREATE INDEX IF NOT EXISTS idx_gun_box_mapv ON gun_box (map_version, gun_id);

-- ---------------------------------------------------------------------------
-- Tier-C retention telemetry (docs/41 §3.9): per-gun ACQUIRE / voluntary-REPLACE
-- counts per game. replace_rate = SUM(replaced)/SUM(acquires) is the availability-
-- FREE RETENTION signal: once a player has the gun, do they KEEP it, or swap it away
-- the moment something else shows up? The GSC sampler counts a replace ONLY for a
-- clean swap while the player is alive + standing, so a death / down / Mule-Kick slot
-- loss is NEVER counted (replaced <= acquires by construction, and the Worker re-clamps
-- it). Same anonymity model as gun_time/gun_box (aggregate-only payload, keyed
-- game_key, no gamertags). Additive migration - re-run this file to apply, no rebuild.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS gun_drop (
  game_key    TEXT NOT NULL,       -- same keyed hash as gun_time (worker.js hashGameKey)
  gun_id      INTEGER NOT NULL,    -- canonical base-gun id; tools/gun_ids.json
  acquires    INTEGER NOT NULL,    -- times this gun entered a player's loadout this game
  replaced    INTEGER NOT NULL,    -- times it was voluntarily swapped out (replaced <= acquires, worker-clamped)
  end_round   INTEGER,             -- denormalized (mirrors gun_time)
  players     INTEGER,             -- denormalized player count
  map_version TEXT,                -- per-build filtering
  received_at INTEGER,
  PRIMARY KEY (game_key, gun_id)   -- dedup: re-POST (marathon/co-op) UPSERTs, never doubles
);

CREATE INDEX IF NOT EXISTS idx_gun_drop_gun  ON gun_drop (gun_id);
CREATE INDEX IF NOT EXISTS idx_gun_drop_mapv ON gun_drop (map_version, gun_id);

-- ---------------------------------------------------------------------------
-- Per-player kills / downs / revives per game (docs/40, user 2026-07-14). Unlike the
-- gun_* telemetry above, this is NAMED, not anonymous: it stores the gamertag, exactly
-- like the games table (same session_id, same privacy posture) - per-player attribution
-- is the point ("record kills/downs/revives for each player"). Source = the STOCK
-- scoreboard fields player.kills/.downs/.revives (GSC reads them at end_game; no new
-- callback). Additive migration - re-run this file (CREATE ... IF NOT EXISTS) to apply,
-- no rebuild. The Worker degrades gracefully if this table is missing (best-effort write,
-- endpoint returns empty), so deploy order does not matter.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS player_stats (
  session_id  TEXT NOT NULL,       -- FK-ish to games.session_id (same value); NOT anonymized
  name        TEXT NOT NULL,       -- gamertag, delimiter-scrubbed in GSC + Worker-cleaned
  kills       INTEGER NOT NULL,    -- stock player.kills at end_game
  downs       INTEGER NOT NULL,    -- stock player.downs
  revives     INTEGER NOT NULL,    -- stock player.revives (teammates this player revived)
  end_round   INTEGER,             -- denormalized game round (mirrors gun_time)
  players     INTEGER,             -- denormalized player count
  map_version TEXT,                -- per-build filtering
  received_at INTEGER,
  PRIMARY KEY (session_id, name)   -- one row per (game, player); co-op re-POST UPSERTs (MAX), never doubles
);

CREATE INDEX IF NOT EXISTS idx_player_stats_name ON player_stats (name);
