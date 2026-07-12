// =============================================================================
// Abandoned Cyber City - leaderboard backend (Cloudflare Worker + D1)
//
// Two endpoints the game hits via curl (the ONLY outbound channel BO3 has -
// docs/40 "✅ THE WORKING RECIPE"):
//   POST /games      - record one finished game (dedup by session id)
//   GET  /top10.txt  - the top 10, as PLAIN TEXT (one row per line) so the Lua
//                      side needs no JSON parser: "round|name1,name2,name3,name4"
//   GET  /top10.json - same data as JSON (for web/debug)
//   GET  /health     - liveness
//
// Anti-abuse note: the game is shipped to the public and the request key is
// EXTRACTABLE from the fastfile, so this can never be fully cheat-proof (docs/40).
// This Worker does the cheap, high-value server-side gates: a shared key check,
// strict field validation/clamping, per-IP rate limiting, and dedup-by-session.
// Serious records stay video-verified (zwr.gg). Tune to taste.
//
// Deploy: see README.md (wrangler or dashboard). Bindings expected:
//   env.DB       - D1 database (see schema.sql)
//   env.ACC_KEY  - shared secret; the game sends it as the `x-acc-key` header.
//                  Set via `wrangler secret put ACC_KEY` (or dashboard Variables).
//                  If unset, the key check is skipped (open board).
// =============================================================================

const MAX_ROUND = 2000;      // sanity clamp - no legit ACC game exceeds this
const NAME_MAX = 24;          // gamertag cap
const RATE_MAX = 20;          // max POSTs per IP per RATE_WINDOW
const RATE_WINDOW = 60;       // seconds

function txt(body, status = 200) {
  return new Response(body, { status, headers: { "content-type": "text/plain; charset=utf-8", "cache-control": "no-store" } });
}
function jsonResp(obj, status = 200) {
  return new Response(JSON.stringify(obj), { status, headers: { "content-type": "application/json; charset=utf-8", "cache-control": "no-store" } });
}

// Keep only printable, delimiter-safe chars in a gamertag (we use | and , as
// delimiters in the text format, so strip those + control chars).
function cleanName(s) {
  return String(s == null ? "" : s)
    .replace(/[\x00-\x1f|,\\"]/g, " ")
    .trim()
    .slice(0, NAME_MAX) || "?";
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const path = url.pathname;

    if (path === "/health") return txt("ok");

    // ---- read: top 10 ------------------------------------------------------
    if (request.method === "GET" && (path === "/top10.txt" || path === "/top10.json")) {
      let rows;
      try {
        const res = await env.DB.prepare(
          "SELECT round, players, client_ts FROM games ORDER BY round DESC, received_at ASC LIMIT 10"
        ).all();
        rows = res.results || [];
      } catch (e) {
        return path.endsWith(".json") ? jsonResp({ error: "db" }, 500) : txt("", 500);
      }
      if (path === "/top10.json") {
        return jsonResp(rows.map(r => ({ round: r.round, players: r.players.split(","), ts: r.client_ts })));
      }
      // plain text: one row per line "round|csv-of-names" (Lua-friendly)
      return txt(rows.map(r => `${r.round}|${r.players}`).join("\n"));
    }

    // ---- write: record a game ----------------------------------------------
    if (request.method === "POST" && path === "/games") {
      // shared-key gate (skipped if ACC_KEY not configured)
      if (env.ACC_KEY && request.headers.get("x-acc-key") !== env.ACC_KEY) {
        return jsonResp({ error: "unauthorized" }, 401);
      }

      // per-IP rate limit (best-effort; uses D1 so no extra binding needed)
      const ip = request.headers.get("cf-connecting-ip") || "0";
      try {
        const since = Math.floor(Date.now() / 1000) - RATE_WINDOW;
        const c = await env.DB.prepare(
          "SELECT COUNT(*) AS n FROM games WHERE ip = ? AND received_at > ?"
        ).bind(ip, since).first();
        if (c && c.n >= RATE_MAX) return jsonResp({ error: "rate" }, 429);
      } catch (e) { /* rate check is best-effort; never blocks on error */ }

      let body;
      try { body = await request.json(); } catch (e) { return jsonResp({ error: "bad json" }, 400); }

      const round = parseInt(body.round, 10);
      const session = String(body.session == null ? "" : body.session).replace(/[^\w.\-]/g, "").slice(0, 64);
      const ts = parseInt(body.ts, 10) || 0;
      const mapv = String(body.map_version == null ? "" : body.map_version).replace(/[^\w.\-]/g, "").slice(0, 24);
      let players = Array.isArray(body.players) ? body.players : [];
      players = players.slice(0, 4).map(cleanName).filter(n => n !== "?");

      if (!session || !(round >= 1 && round <= MAX_ROUND) || players.length === 0) {
        return jsonResp({ error: "invalid" }, 400);
      }
      const playersCsv = players.join(",");

      try {
        // dedup by session: multiple clients (co-op) may POST the same game;
        // keep the highest round seen for that session.
        await env.DB.prepare(
          `INSERT INTO games (session_id, round, players, client_ts, map_version, ip, received_at)
           VALUES (?, ?, ?, ?, ?, ?, unixepoch())
           ON CONFLICT(session_id) DO UPDATE SET
             round = MAX(games.round, excluded.round),
             players = excluded.players`
        ).bind(session, round, playersCsv, ts, mapv, ip).run();
      } catch (e) {
        return jsonResp({ error: "db" }, 500);
      }
      return jsonResp({ ok: true });
    }

    return jsonResp({ error: "not found" }, 404);
  }
};
