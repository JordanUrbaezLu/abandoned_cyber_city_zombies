#!/usr/bin/env node
// =============================================================================
// Abandoned Cyber City - leaderboard DB CLEANUP (split-session dedupe)
//
//   npm run cleanup                       report only (default - NOTHING is written)
//   npm run cleanup -- --apply            merge the clusters verdicted "mergeable"
//   npm run cleanup -- --sessions=a,b     delete EXACTLY these session ids (dry-run
//                                         unless --apply is also passed)
//   npm run cleanup -- --gap=6            widen the cluster window to 6h (default 3)
//
// WHAT IT CLEANS: games.session_id is the PRIMARY KEY, so literal duplicate ids cannot
// exist - what can exist is the SAME GAME under TWO ids (the rec chunk's session dvar
// read hiccuped mid-match and minted a fresh id, splitting one run into two board rows).
// The Worker's /admin/dedupe endpoint (worker.js) does the detection + merge server-side;
// this script is just the console for it. Detection is conservative: only clusters where
// every consecutive pair looks like a CONTINUATION (same exact roster, round never
// decreases, every shared player's kills/downs/revives component-wise grows - stock
// counters only grow within one match) are auto-mergeable; everything else is reported
// as "suspect" for a human decision (same crew playing back-to-back real games looks
// similar - never auto-merge those). gun_* tables are untouched (game_key is an HMAC of
// the session, deliberately unjoinable - a split's gun rows stay as aggregate noise).
//
// AUTH: needs the ADMIN_KEY - a separate secret that never ships in the game (the
// fastfile-extractable ACC_KEY must never authorize deletes). Resolution (first hit):
//   1. $ACC_LB_ADMIN_KEY env var
//   2. deployed.local.json "admin_key" (gitignored)
// Set it server-side once: `wrangler secret put ADMIN_KEY` (or dashboard Variables) +
// redeploy worker.js. Until it is set, the endpoint 404s and this script reports that.
//
// Base URL resolution matches summary.js ($ACC_LB_URL -> deployed.local.json -> fallback).
// Zero-dependency (Node 18+ global fetch).
// =============================================================================

const fs = require("fs");
const path = require("path");

const FALLBACK_URL = "https://acc-leaderboard.jordana-urbaez.workers.dev";
const TIMEOUT_MS = 30000;

function readLocalCfg() {
  try {
    return JSON.parse(fs.readFileSync(path.join(__dirname, "deployed.local.json"), "utf8")) || {};
  } catch { return {}; }
}

function resolveBaseUrl(cfg) {
  if (process.env.ACC_LB_URL) return process.env.ACC_LB_URL.replace(/\/+$/, "");
  if (cfg.url) return String(cfg.url).replace(/\/+$/, "");
  return FALLBACK_URL;
}

function resolveAdminKey(cfg) {
  if (process.env.ACC_LB_ADMIN_KEY) return process.env.ACC_LB_ADMIN_KEY;
  if (cfg.admin_key) return String(cfg.admin_key);
  return "";
}

function arg(name) {
  const hit = process.argv.find(a => a === `--${name}` || a.startsWith(`--${name}=`));
  if (!hit) return undefined;
  const eq = hit.indexOf("=");
  return eq === -1 ? true : hit.slice(eq + 1);
}

const fmtTs = t => (t ? new Date(t * 1000).toISOString().replace("T", " ").slice(0, 19) : "?");

(async () => {
  const cfg = readLocalCfg();
  const base = resolveBaseUrl(cfg);
  const key = resolveAdminKey(cfg);
  if (!key) {
    console.error("No admin key. Set $ACC_LB_ADMIN_KEY or add \"admin_key\" to deployed.local.json");
    console.error("(server side: wrangler secret put ADMIN_KEY, or dashboard Variables, then redeploy worker.js)");
    process.exit(1);
  }

  const apply = arg("apply") === true;
  const sessionsArg = arg("sessions");
  const gap = parseFloat(arg("gap"));

  const body = {};
  if (apply) body.apply = true;
  if (typeof sessionsArg === "string" && sessionsArg.length) body.sessions = sessionsArg.split(",").map(s => s.trim()).filter(Boolean);
  if (gap > 0) body.gap_hours = gap;

  let res;
  try {
    res = await fetch(`${base}/admin/dedupe`, {
      method: "POST",
      headers: { "content-type": "application/json", "x-admin-key": key },
      body: JSON.stringify(body),
      signal: AbortSignal.timeout(TIMEOUT_MS),
    });
  } catch (e) {
    console.error(`Request failed: ${e.message}`);
    process.exit(1);
  }
  if (res.status === 404) {
    console.error("Endpoint 404 - ADMIN_KEY is not set on the Worker (or worker.js predates /admin/dedupe).");
    console.error("Fix: wrangler secret put ADMIN_KEY (or dashboard Variables) + redeploy worker.js.");
    process.exit(1);
  }
  if (res.status === 401) {
    console.error("Unauthorized - the local admin key does not match the Worker's ADMIN_KEY secret.");
    process.exit(1);
  }
  if (!res.ok) {
    console.error(`HTTP ${res.status}: ${await res.text()}`);
    process.exit(1);
  }
  const out = await res.json();

  if (out.mode === "sessions" || out.mode === "sessions-dry-run") {
    const ids = out.deleted || out.would_delete || [];
    console.log(`${out.mode === "sessions" ? "DELETED" : "WOULD DELETE (pass --apply to execute)"}: ${ids.length} session(s)`);
    for (const id of ids) console.log(`  ${id}`);
    return;
  }

  const clusters = out.clusters || [];
  if (!clusters.length) {
    console.log("No duplicate-suspect clusters found. DB is clean.");
    return;
  }
  console.log(`${clusters.length} cluster(s) (gap window ${out.gap_hours || 3}h)${out.mode === "apply" ? ` - MERGED ${out.clusters_merged}, deleted ${out.rows_deleted} row(s)` : " - REPORT ONLY (pass --apply to merge the mergeable ones)"}`);
  for (const c of clusters) {
    console.log(`\n[${c.verdict.toUpperCase()}] ${c.players}   (keeper: ${c.keeper})`);
    for (const r of c.rows) {
      const mark = r.session === c.keeper ? "KEEP " : (c.verdict === "mergeable" ? "merge" : "  ?  ");
      console.log(`  ${mark}  round ${String(r.round).padStart(3)}  ts ${fmtTs(r.ts)}  ${r.paradise ? "PARADISE " : ""}${r.session}`);
    }
    if (c.verdict === "suspect") {
      console.log("        ^ not auto-merged (could be real back-to-back games). To remove manually:");
      console.log(`          npm run cleanup -- --sessions=<id,...> --apply`);
    }
  }
})();
