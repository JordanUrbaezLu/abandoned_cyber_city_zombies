# Code + Repo/Map Audit — 2026-07-12

> **Method.** A 54-agent workflow. Every one of the 66 GSC modules + 5 CSC twins was reviewed for
> real T7 runtime defects (grouped by subsystem so integration bugs surfaced), each group's findings
> then re-checked by an independent adversarial verifier told to *refute* them; only CONFIRMED /
> PLAUSIBLE survivors were kept. Separate verified tracks covered the Cloudflare leaderboard backend,
> all custom LUI, map-source integrity (degenerate faces, orphan entities), doc-drift on the uncommitted
> changes, zone/CHANGELOG bookkeeping, and a tools/repo cleanup plan. Agents were armed with this repo's
> known runtime-trap catalog and told **not** to flag intentional documented hacks.
> **Scope note.** This is the *code/bug* companion to the 2026-07-11 doc-truth audit
> ([`DOC_AUDIT_2026-07-11.md`](DOC_AUDIT_2026-07-11.md)); it did not re-litigate that audit's fixes.
>
> **✅ STATUS: ACTIONED 2026-07-12.** All items below were fixed, or consciously deferred with a note.
> A `-GscOnly` build after the code fixes produced a fresh `.ff` (all modules compile; xref lint green).

## 1. Runtime bugs — FIXED

| # | File | Was | Fix |
|---|------|-----|-----|
| 1 | `_acc_emergency_drop.gsc` | `overclock_scroll` drop charged 3 Data Shards then wrote a counter (`acc_oc_free_scrolls`) **nothing read** — paid no-op, ~10-15% of drops | **Removed the OC-voucher entirely** (user decision: "isn't even in the game"): dropped from both weight tables + the case handler, the dead `TODO(acc-oc)` in `_acc_events_hack.gsc`, and every doc mention (05/15/02, hack-success reward). |
| 2 | `mechz_spiki.gsc` (Panzer melee) | The `MOD_MELEE` callback returned a fixed value and short-circuited `_acc_elites::on_player_damaged` — the **only** place Exo Suit + Savior DR apply — so Panzer melee alone ignored that progression | Extracted `acc_elites::apply_player_mitigations(dmg)` (Exo + Savior), called from **both** `on_player_damaged` and the mechz melee branch (mitigate → then demigod clamp). Added `#using _acc_elites` to the pack. |
| 3 | `_acc_transfer.gsc::deposit_points` | Shopping Free gobblegum makes `minus_to_player_score` a no-op, yet the vault was still credited → minted points | Snapshot `player.score` around the debit; only credit the vault if the points were actually removed. `deposit_shards` was already immune. |
| 4 | `_acc_havoc_charge.gsc::restore_gate` | Clip restored to the raw pre-charge value → a Max Ammo landing mid-charge lost its clip refill | Mirror the reserve's max-logic for the clip: `max(cur_clip, saved)`. |
| 5 | `_acc_damage.gsc` (Action-Figure boss path) | The 1/33-max-HP boss path fed the damage number but skipped `record_damage`, losing co-op assist credit when a teammate lands the kill | Added `self acc_points::record_damage(attacker, dmg)` before the feed, matching the Leviathan/Thundergun/PhD paths. |
| 6 | `_acc_elites.gsc::acc_depth_shielded_roll` | Depth-shielded elites set `acc_is_elite` but never incremented `level.acc_elite_active_count`, while the death path decrements for any elite → latent counter drift (no live reader yet) | Added the symmetric `+= 1` so both spawn paths match the single decrement. |

## 2. Backend / LUI / map integrity — status

- **`backend/leaderboard/worker.js`** (verified findings, **not yet applied — separate `wrangler` deploy, not a map build**):
  - `:161` a POST body of JSON `null` escapes the try/catch → raw 500 instead of a 400. Guard the shape after parse.
  - `:238` a negative `?limit` bypasses the clamp (`Math.min(-1,100) = -1`; SQLite `LIMIT -1` = unbounded). Clamp both ends.
  - `:197` (partly intentional) omitting `duration_secs` sets the plausibility budget to `Infinity`. Optional hardening only; anonymous cosmetic telemetry, not rank.
- **LUI** `_acc_lui.csc:53` `eye_tint_cb` ignores the 1→0 clear transition — **dormant** (all 5 callers pass `true`); no fix needed unless a clearing caller is ever added.
- **Zone comment** `zone_source/…zone:1044` falsely called live `_acc_havoc_charge.gsc` a "dead file" (deletion hazard) → **fixed**.
- **Map integrity** track found no degenerate-face or orphan-entity defects beyond the stale "six chests" comment (→ seven), fixed.

## 3. Doc ↔ code drift (new, from the uncommitted changes) — FIXED

- `docs/41_weapon_usage_tracking.md` §3.5 rewritten to the shipped `game_key` schema (was `session_id`) + MAX-merge upsert; Phase-0 `pistol_standard` line corrected (it is excluded).
- `docs/40_leaderboard.md` "syncing" hint → the renamed "loading top 10…" busy hint.
- **In-code stale headers/comments** corrected: `_acc_overclocks` (tiers 0-5 → 0-10, no roll), `_acc_reactor` (tier-payout → flat + dead `#using` removed), `_acc_boss_items` (6-item/2-slot/STUB → 11/3/LIVE, ×2), `_acc_boss_panzer` (zap radius 200 → 220), `_acc_glitch_altar` (dvar defaults), `_acc_coop_scaling` (2/3/4× → 1.2/1.4/1.6×), `_acc_map_randomizer` (six → seven chests). Added the missing `specialty_quickrevive` Mega no-op case in `_acc_mega_bottles`.

## 4. Repo / map cleanup — DONE

- **Archived 96 spent one-shot tool scripts** `tools/*.js → tools/oneshots/` (map-geometry adders/generators/mutators + install-side GDT one-shots). Verified none is `.ps1`-invoked and no kept tool `require()`s a moved one; `gen_rooms`/`gen_zone_greybox` held back (preflight references them). Families + the keep-list are documented in `tools/oneshots/README.md`. Root `tools/*.js`: 134 → 38 (active pipeline / restore-chain / diagnostics / preflight only).
- **Deleted orphan `_acc_ee_song.gsc`** (not compiled since the jukebox replaced it 2026-07-09; audio aliases live on in the CSV).
- **Root de-cluttered:** `Notes.md` + `ToDoList.md` → consolidated into `docs/backlog.md`; `DOC_AUDIT_2026-07-11.md` → `docs/archive/` (+ CHANGELOG link fixed). Root now holds only the 9 canonical `.md` files.
- **Anti-drift:** a **fact-ownership table** now lives at the top of `docs/README.md` — code owns numbers, one doc owns each prose topic, everyone else links. This is the durable fix for the 78 redundant-doc overlaps the prior audit flagged.

## 5. Deferred (needs a decision or a non-map-build)

- The 3 `worker.js` hardening items — batch into one `wrangler` deploy (out of the map-build loop).
- `worker.js:197` telemetry budget — decide whether to add the finite fallback or leave best-effort.
- Two superseded greybox generators (`gen_rooms`, `gen_zone_greybox`) intentionally kept in `tools/` root because `preflight_windows.ps1` names them in a comment.
