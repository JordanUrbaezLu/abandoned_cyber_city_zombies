-- Abandoned Cyber City leaderboard - D1 (SQLite) schema.
-- Apply once at deploy: `wrangler d1 execute acc_leaderboard --file=schema.sql`
-- (or paste into the D1 console in the Cloudflare dashboard).

CREATE TABLE IF NOT EXISTS games (
  session_id  TEXT PRIMARY KEY,   -- unique per game (host-minted); dedups co-op multi-POST
  round       INTEGER NOT NULL,   -- round reached (the ranking key)
  players     TEXT NOT NULL,      -- comma-separated gamertags (already sanitized by the Worker)
  client_ts   INTEGER,            -- os.time() from the game client (seconds)
  map_version TEXT,               -- map build tag, for filtering across versions later
  ip          TEXT,               -- for best-effort per-IP rate limiting
  received_at INTEGER             -- server unixepoch() at insert
);

-- ranking + rate-limit lookups
CREATE INDEX IF NOT EXISTS idx_games_round ON games (round DESC, received_at ASC);
CREATE INDEX IF NOT EXISTS idx_games_ip    ON games (ip, received_at);
