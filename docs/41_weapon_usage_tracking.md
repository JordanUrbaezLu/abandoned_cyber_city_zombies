# 41 — Weapon Usage Tracking (anonymous per-gun held-time)

**Status: ✅ FULLY VERIFIED END-TO-END (2026-07-12).** The user's first real
flags-off game landed correct rows in `/stats/guns.txt` (Leviathan 128s 46.7% /
CEL-3 72s / Five-Seven 40s / Grav 34s — shares sum to 100%), proving the ONE
previously-unverified link: **the rec chunk's dvar read works on retail HKS**.
That makes `GSC SetDvar (host) → LUI dvar read` a **new proven GSC→LUI string
channel** for this codebase (variable-length, no clientfield bits, host-local). All layers implemented (Phases 0–4), adversarially reviewed
(2 confirmed backend bugs + 3 low fixed), `-GscOnly` build clean, and the
**backend is deployed + smoke-tested live** (POST with a `guns` array → correct
`gun_time` rows → `/stats/guns` returns share%/pick-rate/labels, fold-sum + clamps
+ HMAC token all verified). The design + evidence below is unchanged from the
6-agent research pass.

> **The GSC→LUI dvar read (R2) — VERIFIED IN PRODUCTION 2026-07-12.** The rec
> chunk reads `acc_lb_guns` via a **pcall-guarded multi-arity attempt**
> (`Engine.DvarString`/`GetDvarString` in both `(name)` and `(ctrl,name)` forms,
> + `GetDvar`) and **degrades gracefully** (unsupported read → `guns` field
> omitted, the leaderboard record still posts). The design self-verified exactly
> as planned: the first real flags-off game landed correct rows in `/stats/guns`.
> The clientfield fallback (§3.3) stays documented but is NOT needed. The one-shot
> dev probe (`dvar_transport_probe()` + the `acc_lb_dvarprobe` menu) was **removed
> post-verification** in the pre-publish cleanup — resurrect from git history only
> if a future engine/HKS change ever needs re-verification.

## Build status (what shipped vs the plan)

| Phase | Status | Where |
|---|---|---|
| 0 — registry + generator | ✅ built | `tools/gun_ids.json` (31 guns, append-only), `tools/gen_gun_ids.js` (idempotent; regenerates the GSC id switch + the inlined worker label map) |
| 1 — GSC measurement | ✅ built | `_acc_weapon_usage.gsc` (sampler/exclusions/`true_base` fold/`serialize`/`checksum`), wired in `_acc_main` |
| 2 — transport probe | ✅ served its purpose, REMOVED | transport production-verified 2026-07-12 → probe fn/menu/zone/csc wiring deleted (pre-publish cleanup); in git history |
| 3 — backend | ✅ deployed + live-smoke-tested | `gun_time` table + indexes on D1, ingest in `POST /games` (own try/catch, HMAC token, clamps, fold-sum), `GET /stats/guns.txt|.json` |
| 4 — wire payload | ✅ built | `record_at_end_game` publishes `acc_lb_guns`+`acc_lb_dur`; `acc_lb_rec_chunk.lua` reads them (robust) → `guns`/`duration_secs` in the SAME POST |
| — in-game e2e | ✅ **VERIFIED 2026-07-12** | real game → `/stats/guns` correct (Leviathan 128s 46.7% / CEL-3 72s / Five-Seven 40s / Grav 34s; shares sum 100%) |
| Tier B — box take-rate | ✅ built + **DEPLOYED 2026-07-12** | §3.8 — `gun_box` + offer/take hooks + `box`/`take_rate`. Worker `fd9f4c8a` live, `gun_box` table created; `take_rate` now served (null until games POST `box`) |
| Tier C — replace-rate | ✅ built + **DEPLOYED 2026-07-12**; in-game verify pending | §3.9 — `gun_drop` + carried-set diff (`drop_sample`) + `drop`/`replace_rate`. GscOnly + LUI bytecode green; `gun_drop` table created; `replace_rate` served (null until a new-build game POSTs `drop`) |

Decisions locked: §6. Original research + design: below.

> Builds directly on the shipped leaderboard (**docs/40**) — same end_game POST,
> same detached agent, same Worker+D1. Read docs/40 first.

## 1. Problem + locked decisions

At `end_game`, `_acc_leaderboard.gsc::record_at_end_game()` already opens an
invisible `acc_lb_rec` LUI menu whose hksc chunk (`tools/lui_chunks/acc_lb_rec_chunk.lua`)
builds one JSON body, writes `players/acc_lb_post.json` + a trigger file, and a
detached background agent curl-POSTs it to a Cloudflare Worker + D1. We want to
add **anonymous per-gun held-in-hands usage tracking**: a server-GSC sampler sums,
per game, the seconds each gun was any player's *current* weapon; folds every held
form to its canonical base gun; and ships an `{id, secs}` array in the **same
single POST**. The backend derives held-time **share** and **pick rate** per gun.

**Locked decisions (user, 2026-07-12):** (1) count **held-in-hands only** (not
inventory ownership); (2) the gun payload is **anonymous** — no gamertags anywhere
in the gun data; (3) the wonder-**melee** Leviathan Axe **counts** — "it's really
weapon usage."

**The one hard problem is transport.** Gun usage is a *server-side sum across all
players*, but the rec chunk reads its data *client-side*, and — verified by grep —
**no LUI anywhere in this repo reads a dvar** (`Engine.GetDvar*`/`DvarString` = 0
matches in `ui/` and `tools/lui_chunks/`). The GSC→LUI channel for the gun blob is
therefore **unproven on our HKS build** and must pass a verification probe (like
io/os did, docs/40) before we rely on it. Measurement + backend are low-risk.

## 2. Architecture (gun data joins the existing flow)

```
  ┌────────────────────── SERVER GSC (host) ───────────────────────┐
  │  _acc_weapon_usage.gsc  (NEW, wired like _acc_gun_badges)        │
  │  on_player_connect → usage_sampler()  per player, 1 Hz           │
  │     cur = self GetCurrentWeapon()                                 │
  │     pause if self.laststand / self.acc_box_grabbing              │
  │     name = acc_weapon_variants::true_base(cur).name  (REUSE fold)│
  │     exclude grenade/equipment/fists/vanilla-knife                │
  │     level.acc_wpn_seconds[name]++      (ONE map, team-summed)    │
  │                                                                  │
  │  record_at_end_game()  [end_game; dev/god early-return]          │
  │     packed = serialize()  → "9:840,7:540,32:35"  (id:secs)      │
  │     SetDvar("acc_lb_guns", packed)   ⟵ NEW, BEFORE OpenLUIMenu   │
  │     SetDvar("acc_lb_guns_ck", checksum)                          │
  └────────┬─────────────────────────────────────────────────────────┘
           │  *** TRANSPORT — UNPROVEN, verify first ***  (host-local dvar read)
  ┌────────▼───────────── RECORDER LUI (host client) ──────────────┐
  │  acc_lb_rec_chunk.lua                                            │
  │     names/round/ts ◀ Engine.GetModelValue   (PROVEN, unchanged) │
  │     guns           ◀ Engine.DvarString("acc_lb_guns")  (NEW)    │
  │     j = {session,round,ts,map_version,players[], guns[]}        │
  │     io.write acc_lb_post.json  +  acc_lb_do_post.txt            │
  └────────┬─────────────────────────────────────────────────────────┘
           │  (agent UNCHANGED — acc_lb_boot_chunk.lua curl … URL/games)
  ┌────────▼───────────── CLOUDFLARE WORKER + D1 ──────────────────┐
  │  POST /games   key+rate+dedup UNCHANGED                          │
  │     ├─ games upsert          (existing, own try/catch)          │
  │     └─ gun_time upsert       (NEW, SEPARATE try/catch)          │
  │  GET /stats/guns.txt|.json   (NEW: share%, pick_rate, games)    │
  └──────────────────────────────────────────────────────────────────┘
```

Two touch-points only: GSC `record_at_end_game()` publishes `acc_lb_guns` before
`OpenLUIMenu`; the rec chunk reads it and appends a `guns` array. Agent + trigger
plumbing untouched.

## 3. Layer specs

### 3.1 GSC measurement — `_acc_weapon_usage.gsc` (NEW; high confidence)

**Wiring** (mirror `_acc_gun_badges`): `acc_weapon_usage::init()` from
`acc_main::init`; `on_player_connect(self)` threaded next to
`acc_gun_badges::on_player_connect` (`_acc_main.gsc:343`/`:359`). `#using` the
variants module + stock `_zm_utility`/`_zm_equipment`.

**Dev/god guard (gate once at connect):** `if ( IS_TRUE(level.acc_dev) ||
IS_TRUE(level.acc_god) ) return;` — mirrors `record_at_end_game`'s guard
(`_acc_leaderboard.gsc:167`). Both flags resolve in `acc_resolve_dev_flags()`
before `acc_main::init`, so assisted runs thread nothing.

**Sampler** (per player, `self endon("disconnect")`, **1 Hz** — the badge poll runs
0.25 s at `_acc_gun_badges.gsc:107-117` with no cost; 1 Hz is 4× cheaper, pure GSC,
no HUD/clientfield/pool exposure):

```gsc
for(;;){
  wait 1;
  if ( IS_TRUE(self.laststand) )       continue;   // downed → laststand pistol
  if ( IS_TRUE(self.acc_box_grabbing) ) continue;   // box raise → GetCurrentWeapon is STALE
  name = usage_base_name( self GetCurrentWeapon() );
  if ( !isdefined(name) ) continue;
  if ( !isdefined(level.acc_wpn_seconds[name]) ) level.acc_wpn_seconds[name] = 0;
  level.acc_wpn_seconds[name]++;                     // ONE level map = team sum (2 players → +2/s)
}
```

`self.laststand` = stock (`_zm_laststand.gsc:200`, switches to laststand pistol
`:492`). `self.acc_box_grabbing` = ours (`_acc_weapon_variants.gsc:530`, cleared
after `wait_box_give_settled()`) — during the slow box raise `GetCurrentWeapon`
returns the stale OLD gun (memory `box-grab-defer-weapon-reconcile`). Storage =
one level-scope assoc array keyed by canonical name; no per-player keys, so the
flat map *is* the cross-player sum. (Greenfield — no prior `acc_wpn`/`held_time`
accumulator exists.)

**Fold-to-base — REUSE, do not build:** `acc_weapon_variants::true_base(weapon)`
(`_acc_weapon_variants.gsc:1005`). Composes `logical_stem_name()` (strips our
`_acc_<combo>` twin suffix) → stock `zm_weapons::get_base_weapon()` (alt-fire →
primary, attachments → rootWeapon, PaP `_up` → base) → literal `_up` fallback.
It is the repo's canonical identity key (PaP tier, OC tier, Mule, abilities,
damage all key off it). Overclocks never swap the weapon entity, so OC'd guns need
no special handling. **Do NOT** key rows off the `acc_weapon_balance_mult`
`IsSubStr` scheme or the `pred_*` badge tests — those are classifiers, not folds.

**Exclusion predicate — `usage_base_name(cur)`** (exclusion-based so wonders +
future pack guns auto-include; **never** use `zm_utility::is_offhand_weapon`, which
unions `is_melee_weapon` and would silently drop the Leviathan the user wants
counted):

```gsc
if ( !isdefined(cur) || cur==level.weaponNone || cur==level.weaponZMFists ) return undefined;
if ( zm_utility::is_lethal_grenade(cur) )   return undefined;   // frag
if ( zm_utility::is_tactical_grenade(cur) ) return undefined;   // monkey/octobomb
if ( zm_utility::is_placeable_mine(cur) )   return undefined;
if ( zm_utility::is_hero_weapon(cur) )      return undefined;   // gadget (none registered; safe)
if ( zm_equipment::is_equipment(cur) )      return undefined;
base = acc_weapon_variants::true_base(cur);
if ( !isdefined(base) || base==level.weaponNone || !isdefined(base.name) ) return undefined;
if ( base.name=="knife" || base.name=="bowie_knife" ) return undefined;   // Leviathan/AF/Ballistic still pass
if ( base.name=="pistol_standard" ) return undefined;                     // start/laststand pistol EXCLUDED (decision 3)
return base.name;
```

Predicates verified stock (`_zm_utility.gsc:4145/4215/4267/4408`,
`_zm_equipment.gsc:691`; `level.weaponNone`/`weaponZMFists` `_zm.gsc:234/242`).
`weapClass` is **not** a usable positive filter (Fire Bow ships empty `weapClass`)
— exclusion is required. **Defensive assert:** if a folded `base.name` ends in
`_up`/`_upgraded`, dev-log it (catches a future unregistered irregular port before
it fragments a row — see R1).

### 3.2 Gun-ID scheme + generator

- **Registry (single source):** checked-in **append-only** `tools/gun_ids.json`
  mapping canonical base `.name` → permanent positive int (the 31 box guns).
  **id 0 = `other` catch-all** so an unmapped held gun is *counted, never dropped*.
  IDs assigned in registration order, **never renumbered**; new gun appends at
  `max+1`; retired gun keeps its id as a **tombstone** (pre-seed `t9_m16`,
  `s1_asm1`). **Never** derive ids from box order or `box_weight` rank (both
  reshuffle every rebalance).
- **Live set = the arsenal oracle:** the `box_weapons = array(...)` literal at
  `_acc_map_randomizer.gsc:146` (31 non-tactical guns), which `gen_weapon_stats.js`
  already comment-strip-parses + asserts 1:1 vs ROSTER(24)+SPECIALS(7). Keys are
  the **bare box names** `true_base().name` returns — traps: PPSH = `s4_ppsh41_base`,
  Apex guns bare (`apex_peacekeeper`, no `_zm`), Leviathan = `leviathan`. Count:
  **31 box guns → ids 1..31; id 0 = `other`/unknown catch-all.** `pistol_standard` is
  EXCLUDED (decision 3) — no id, never reaches the id map (the sampler drops it).
- **Generator `tools/gen_gun_ids.js`** (standalone; `gen_weapon_stats.js` is too
  deep in GDT logic): reads the registry, parses `box_weapons[]`, reuses the
  completeness audit to **auto-append + warn** on a new live gun and **abort** on
  unresolvable drift; emits a GSC `acc_gun_id(weapon_name)` switch between
  `// <<< BEGIN GENERATED` / `// >>> END GENERATED` markers (mirrors the
  `acc_box_weight()` idiom), defensively stripping a trailing `_upgraded`/`_up`/`_zm`
  before matching, `return 0` catch-all; also emits `backend/leaderboard/gun_ids.json`
  (id→display-name) so the backend can label without the game rebuilding.
- **Recommended: numeric ids over the wire; GSC owns `acc_gun_id()`, backend owns
  the label map** — so the Lua chunk needs **no** id table and no splice (minimal
  edits to the fragile chunk, two sides provably in sync from one registry).
  Alternative (splice an `@@ACC_GUN_IDS@@` Lua table via `build_lb_lui.js`) is
  possible but not recommended for v1.

### 3.3 GSC→LUI transport (THE risk leg)

**Verified fact:** `Engine.GetDvar*`/`DvarString`/`DvarInt` appear **nowhere** in
`ui/` or `tools/lui_chunks/`. The proven GSC→LUI *read* path is **only** engine
UI models (`Engine.GetModelValue` on `gameScore.roundsPlayed` /
`PlayerList.i.playerName`). The proven *reverse* path is `Engine.Exec 'set <dvar>'`
→ GSC `GetDvarString`. A chunk **reading** a dvar is genuinely unproven here. (The
API very likely exists — stock BO3 options menus read dvars via `Engine.DvarString`
— but "should work" is what burned us on io/os folklore; it must be probed.)

**Chosen PRIMARY: host-local dvar bridge**, gated behind the §5 probe. Rationale:
the recorder is `players[0]` = the listen-server **host** (`_acc_leaderboard.gsc:180`),
so GSC (server) and the rec chunk (client) run on the **same machine** — a dvar is
host-local, needs **no networked clientfield bit-pool** (docs/19: pool is FULL) and
trivially carries a **variable-length** string. `SetDvar` on this path is proven
(`acc_lb_rec_trace`).

**GSC side** (in `record_at_end_game`, AFTER the dev/god early-return `:167`,
BEFORE `OpenLUIMenu` `:199`):
```gsc
guns = acc_weapon_usage::serialize();              // "9:840,7:540,32:35"
SetDvar( "acc_lb_guns", guns );
SetDvar( "acc_lb_guns_ck", acc_weapon_usage::checksum(guns) );
```
Reset both to `""` at match start (R4). ~31 guns ≈ 300–500 chars, within dvar limits.

**Lua side** (`acc_lb_rec_chunk.lua`, INSIDE the `if URL ~= "" then` branch so
local-only builds never touch it): read defensively, change the players-close from
`]}` to `]` + optional `guns` + `}`:
```lua
local guns = ""
pcall(function() local c = ctrl; if c==nil then c=Engine.GetLocalClientNum() end
                 guns = Engine.DvarString(c, "acc_lb_guns") or "" end)
-- after the players array:
j = j .. "]"
if guns ~= "" then
  j = j .. ',"guns":['
  local first = true
  for id, secs in string.gmatch(guns, "(%d+):(%d+)") do
    j = j .. (first and "" or ",") .. '{"id":' .. id .. ',"secs":' .. secs .. '}'
    first = false
  end
  j = j .. "]"
end
j = j .. "}"
```
Numeric id+secs need no JSON escaping. Add a `T("g"..count)` breadcrumb.

**Checksum self-check** (proves the flaky leg delivered identical ints): GSC
computes `C = Σ(id*31 + secs)` in `acc_lb_guns_ck`; the **probe** LUI re-parses
`acc_lb_guns`, recomputes `C'`, echoes it via `Engine.Exec set acc_lb_guns_ck_lui`;
GSC logs MATCH/MISMATCH. (Dev-probe-only gate; the shipped rec path has no
echo-back — production trusts the read once verified.)

**FALLBACK if `Engine.DvarString` fails verification:** the only other proven
GSC→LUI custom channel is clientfield-backed UI models (how `acc_hud.lua` reads
`accPapTier` etc.), but clientfields are fixed-width, networked, and the pool is
full — a variable-length array would need a serialized multi-frame stream over a
repurposed spare field + a bit-pool audit (real work, v2 only). **If verification
fails, do not ship the payload** — the leaderboard record still posts fine without
it (`guns` is optional end-to-end).

### 3.4 Rec-chunk + POST + the (unchanged) agent

One `post.json` = one POST = one trigger = one agent. The `guns` array folds into
the *same* `players/acc_lb_post.json`; the agent's curl is unchanged (the Worker
ignores unknown fields → forward-compatible). `map_version` is already end-to-end,
so gun stats filter per build for free. Body (`duration_secs` added, decision 5):
```json
{"session":"g1752...-ab12","round":31,"ts":175...,"map_version":"2026-07-12",
 "duration_secs":1920,"players":["Alice","Bob"],
 "guns":[{"id":9,"secs":840},{"id":7,"secs":540}]}
```
Missing/empty `guns` (old clients, local-only, dvar-read fails) = silent no-op that
still records the game.

### 3.5 Backend

**DDL** (`schema.sql`, additive `CREATE TABLE IF NOT EXISTS`, no rebuild):
```sql
CREATE TABLE IF NOT EXISTS gun_time (
  game_key    TEXT NOT NULL,       -- sha256/HMAC(session); dedup key ONLY, no PII, unjoinable to games (decision 4)
  gun_id      INTEGER NOT NULL,    -- canonical base-gun id (0 = other); anonymous
  seconds     INTEGER NOT NULL,    -- team-summed held-in-hands secs this game
  end_round   INTEGER,             -- denormalized → weighted stats w/o join
  players     INTEGER,             -- denormalized player count → clamp w/o join
  map_version TEXT,                -- per-build filtering
  received_at INTEGER,
  PRIMARY KEY (game_key, gun_id)   -- dedup: one row per (game, gun); re-POST (marathon/co-op) upserts
);
CREATE INDEX IF NOT EXISTS idx_gun_time_gun  ON gun_time (gun_id);
CREATE INDEX IF NOT EXISTS idx_gun_time_mapv ON gun_time (map_version, gun_id);
```

**Ingest** — folded into `POST /games`, AFTER the games upsert, in its **OWN
try/catch** so a gun-insert failure never rolls back / 500s the committed game row
(R5). Inherits key gate + rate limit + dedup. Steps: read `body.guns` (missing →
skip); `MAX_GUNS=64` (slice); fold-sum duplicate ids in-payload; per row require
`seconds>=1`, `gun_id` int in `[0, GUN_ID_MAX]` (drop else), clamp `seconds<=200000`;
compute `game_key = hashGameKey(session)` (HMAC-SHA256 with `GUN_KEY_SECRET`, else a
plain digest — never the raw `session_id`); D1-batch `INSERT … ON CONFLICT(game_key, gun_id)
DO UPDATE SET seconds = MAX(gun_time.seconds, excluded.seconds), end_round = MAX(…),
players = excluded.players, map_version = excluded.map_version` (idempotent — MAX-merge
handles marathon double-open + co-op re-POST without double-count, R6). Optional stronger
clamp needs `duration_secs` in the payload (§6 Q5).

**Read — `GET /stats/guns.txt`** (Lua-parseable, mirrors `/top10.txt`): one line
`gun_id|total_seconds|share_pct|pick_rate|games_seen` sorted by `total_seconds
DESC`; plus `/stats/guns.json` (labelled via `gun_ids.json`), `?map_version=`,
`?limit=`. Public GET like `/top10`.

**Anonymity guarantee:** the payload is an *all-players aggregate* before it leaves
the game — no per-player gun attribution exists anywhere; `gun_time` stores **zero
gamertags**. `session_id` is an opaque token, not PII. A join to `games.players`
reveals only "this game (these players collectively) used these guns" — cannot tie
a gun to a person → satisfies decision (2). `game_key` is a hash of the session (never
the raw `session_id`), so with `GUN_KEY_SECRET` set it is not even join-able back to
`games` (decision 4 / §6 Q4).

### 3.6 Stats math

`secs(g, game)` = seconds gun `g` (folded base) was any player's current weapon in
that game (summed across players).
- **Held-time share:** `SHARE(g) = total_seconds(g) / all_seconds`. Primary
  engagement metric. Also compute a **per-game-mean share** (mean over games of
  `secs(g,game)/game_total`) as an outlier-robust cross-check.
- **Pick rate:** `PICK_RATE(g) = games_with(secs(g,game) >= THRESHOLD) /
  total_games_reporting`. Reach metric. **Denominator = `COUNT(DISTINCT session_id)
  FROM gun_time`** (games that reported gun data), not `games`, so pre-feature games
  don't deflate it. `THRESHOLD ≈ 3s` (tune live) so a lone swap-sample doesn't
  inflate reach.

Both are needed and orthogonal: share flatters niche mains; pick-rate equates a 3 s
courtesy-try with a whole-game main. Together they classify workhorse (high/high),
box-filler tried-not-mained (high pick/low share), niche favorite (low pick/high
share), dead weight (low/low).
- **Optional round-weighting (store `end_round` NOW, apply later, zero migration):**
  `WEIGHTED_SHARE(g) = Σ secs(g,row)·w(end_round) / Σ Σ_h secs(h,row)·w(end_round)`.
  Ship `w(r)=1` (identity); switch to `min(r,30)/30` or `log2(1+r)` later via
  `wrangler deploy` — no game rebuild. Honest limit: weighting is **per-game** (every
  second inherits the game's single `end_round` weight), not per-round.

### 3.7 Availability-adjusted reading — preference index (LIVE 2026-07-12)

**The confound (user, 2026-07-12):** raw held-time measures **exposure, not
preference**. A gun the box offers heavily (or the free starting gun) racks up seconds
just by being *available* — the first live pull showed the top held-time guns were
almost exactly the highest-`acc_box_weight` guns (Five-Seven, Grav, Olympia, RPD **at the
time** — note the box was reshaped to a pinned-top mid-hump on 2026-07-16, so the
highest-weight/most-offered guns are now the mids, e.g. MK14 / Triple Take / Tac-19). To
read the data honestly, divide out availability. The box weight table
(`_acc_map_randomizer.gsc::acc_box_weight`) **is** the availability model, so this is
computable server-side with **no game rebuild** — a Worker deploy only.

`GET /stats/guns.txt|.json` now returns, per gun (in addition to `total_seconds`,
`share_pct`, `pick_rate`, `games_seen`):
- **`box_share_pct`** = `acc_box_weight(g) / Σ acc_box_weight` × 100 — the gun's
  *nominal full-pool offer rate*. (Honest limit: the real pool shrinks as guns are
  collected and Lucky Clover shifts odds, so this is the baseline, not the
  moment-to-moment odds. Documented as nominal.)
- **`pref_index`** = `share_pct / box_share_pct`. **>1 = held more than its offer rate
  predicts (genuinely preferred); <1 = offered-but-dropped (dead box weight).** `null`
  for a gun with no box offer path (id 0 `other`).
- **`secs_per_pick`** = `total_seconds / games_picked` — stickiness per acquisition,
  partly de-confounds *how often* a gun is acquired from *how long* it's kept.
- **`is_starting`** + **`verdict`** (`over-performs` / `as-offered` / `under-performs`
  / `starting` / `n/a`). The starting gun (`t6_fiveseven`, `_starting` in
  `tools/gun_ids.json`) is flagged because its `pref_index` is inflated by the free
  grant — discount it.
- **`?sort=`** `seconds` (default) `|share|pick|pref|secs_per_pick`, `?limit=`,
  `?map_version=`. Text format appends `|pref_index|secs_per_pick|verdict` after the
  original 5 columns (backward-compatible — old parsers that read the first 5 fields
  still work).

**Sync:** the box-weight table + starting set are **generated into `worker.js`** by
`tools/gen_gun_ids.js` (parses `acc_box_weight()`), between the
`GENERATED gun-box-weight` markers — a box rebalance re-syncs on the next generator
run, never hand-edited. `pistol_standard` (excluded, decision 3) never reaches this;
`t6_fiveseven` is a real box gun that *also* happens to be the free start weapon.

**First-data read (11 games, 2026-07-12 — method, not conclusion at this n):** the
index completely reorders the raw list. Leviathan Axe `pref_index ≈ 14` and M60 `≈ 2.2`
over-perform hard; **Streetsweeper `≈ 0.04`, War Machine `≈ 0.05`, MORS `≈ 0.09`,
Olympia `≈ 0.38`, AK-74u `≈ 0.43` are offered a lot but dropped** — box dead-weight /
buff-or-lower-box-weight candidates. Trustworthy around 50–100 games.

### 3.8 Tier B — true box take-rate (BUILT 2026-07-12 evening)

`pref_index` still leans on the nominal box weights as a proxy (the real pool shrinks,
Clover shifts odds) and can't see wallbuy/free acquisition. The availability-**free**
metric is **box take-rate** — *when the box landed on gun X, did the player grab it?* —
because conditioning on the offer cancels availability entirely. Now implemented
end-to-end, riding every proven docs/40–41 rail:

- **GSC** — `_acc_weapon_usage.gsc`: `level.acc_box_offers/takes` maps +
  `box_offer(weapon)` / `box_take(weapon)` (dev/god-gated, `usage_base_name` fold) +
  `serialize_box()` → `"id:offers:takes,..."`. The AW printer box calls them via
  **pointer hooks** `level.acc_box_offer_fn` / `acc_box_take_fn` (set in `init`; the
  no-`#using` idiom the vendored pack already uses for `CustomRandomWeaponWeights`):
  offer where the real draw sets `self.actual_weapon`, take in `box_get_weapon` next to
  the `user_grabbed_weapon` notify. The timeout/walk-away path never reaches the take —
  exactly the untaken-offer signal. Auto-give paths (glitch altar, Paradise Box,
  wallbuys) never touch the hooks, so ONLY real take-or-leave rolls count.
- **Transport** — `record_at_end_game` publishes `acc_lb_box` next to the gun blob;
  the rec chunk reads it and appends `"box":[{"id","offers","takes"},...]` to the same
  POST (3-capture gmatch — a malformed string degrades to an empty array, never corrupt
  JSON). Reset to `""` at level init (R4).
- **Backend** — `gun_box` table (PK `(game_key, gun_id)`, MAX-merge upsert = marathon/
  co-op idempotent, same keyed `game_key` anonymity as `gun_time`); ingest in its OWN
  try/catch (un-migrated table never 500s the game row); clamps: id range,
  `takes ≤ offers`, per-gun + total offers ≤ `BOX_OFFERS_MAX` (2000).
- **Read** — `/stats/guns` gains `box_offers`, `box_takes`, `take_rate` (null until
  data lands / pre-migration) + `?sort=take`; the text format appends `|take_rate`
  (backward-compatible). A gun offered but NEVER held still gets a row (zero
  held-time, real take stats) — pure box dead-weight is exactly what this exposes.
- **Reading the pair:** `take_rate` = do players *want* it when offered;
  `secs_per_pick` = do they *keep* it once taken. Low take + high offer share (nominal
  weight) = wasted box slot → buff or cut weight. High take + low `pref_index` = taken
  but soon replaced (a "bridge gun" — fine by design).

Activation: `wrangler d1 execute acc_leaderboard --remote --file=schema.sql` (additive
`CREATE TABLE IF NOT EXISTS gun_box`) + `wrangler deploy` + the next `-GscOnly` build
(LUI bytecode regenerated by `tools/build_lb_lui.js` in the same pass).

### 3.9 Tier C — voluntary replacement rate / retention (BUILT 2026-07-12)

**The gap this closes (user, 2026-07-12):** `secs_per_pick` is a *duration* proxy for
"do players keep a gun," but it can't (a) express a **rate** (Five-Seven is ~100%
replaced yet tolerated ~110 s first, so it reads "medium"), (b) separate a **voluntary
swap** from a **death / Mule-Kick loss**, or (c) survive **late acquisition** (a
Thundergun grabbed round 30 in a game that ends round 32 looks low-retention even though
nobody would ever swap it). Tier C measures the thing directly: of the times a gun
entered a player's hands, what fraction did that player **voluntarily swap away**.

- **`replace_rate`** = `SUM(replaced) / SUM(acquires)`. **0 = always kept (preferred);
  1 = always ditched (rejected).** Availability-FREE like `take_rate` (conditioned on the
  acquisition, so how-often-offered cancels out). `take_rate` = do players *want* it when
  offered; `replace_rate` = do they *keep* it once they have it — orthogonal axes.
- **The one hard problem is classification** (voluntary vs involuntary), solved entirely
  in GSC so the backend just sums two integers:

  **GSC** — `_acc_weapon_usage.gsc`, folded into the SAME 1 Hz sampler (no new thread).
  Each poll it diffs the player's carried-gun set (`GetWeaponsListPrimaries()` ∪
  `GetCurrentWeapon()`, each run through `usage_base_name` so PaP/twins/attachments fold
  to one base and grenades/equipment/start-pistol drop out — the pistol-slot union mirrors
  `_acc_mega_bottles::armory_refill`) against the previous CLEAN snapshot:
  - a base that **entered** → `note_acquire` (denominator). The first-ever poll baselines
    the spawn loadout as acquisitions, so the starter's later swap yields a real rate.
  - a **voluntary replace** (`note_replace`, numerator) is the clean-swap signature ONLY:
    **exactly one** gun left AND at least one entered the SAME poll AND the loadout is
    still non-empty. A mass-clear (death/teleport) or a lone removal with no incoming gun
    (scripted take, Mule down-loss after revive) never matches.
  - **involuntary losses are excluded by construction, not by heuristic:** the diff is
    gated to an *alive, standing, transaction-free* player (`isalive` && !`laststand` &&
    not box-grab/`acc_pap_busy`/`is_drinking` — the exact windows where
    `GetWeaponsListPrimaries()` is transiently wrong, mirroring
    `acc_gun_badges::mule_state_frozen`). Any non-tracking poll sets a **gap flag** that
    forces the next clean poll to RE-BASELINE without attributing — so whatever changed
    while the inventory was unknown (a down, a death, a Mule slot loss) is never blamed on
    a gun as a "voluntary" swap. `serialize_drop()` → `"id:acquires:replaced,..."`.

  **Transport** — `record_at_end_game` publishes `acc_lb_drop` next to the gun/box blobs;
  the rec chunk reads it and appends `"drop":[{"id","acq","rep"},...]` to the same POST
  (same 3-capture `gmatch` guard as `box` → a malformed read degrades to `[]`, never
  corrupt JSON). Reset to `""` at level init (R4).

  **Backend** — `gun_drop` table (PK `(game_key, gun_id)`, MAX-merge upsert =
  marathon/co-op idempotent, same keyed `game_key` anonymity as `gun_time`); ingest in its
  OWN try/catch (un-migrated table never 500s the game row); clamps: id range,
  `replaced ≤ acquires`, per-gun + total acquires ≤ `DROP_ACQ_MAX` (2000).

  **Read** — `/stats/guns` gains `acquires`, `replaced`, `replace_rate` (null until data
  lands / pre-migration) + `?sort=replace`; the text format appends `|replace_rate`
  (backward-compatible). `replaced` is re-clamped ≤ `acquires` on read too.

- **Reading the trio:** `pref_index`/`take_rate` = acquisition preference; `secs_per_pick`
  = raw stickiness; `replace_rate` = the clean retention rate. A gun with high `take_rate`
  + high `replace_rate` = "tried then dumped" (a bridge gun — fine by design); low
  `take_rate` + low `replace_rate` = a niche gun its fans keep; low `replace_rate` +
  low `secs_per_pick` = kept-but-acquired-late (the Thundergun case `secs_per_pick` got
  wrong — `replace_rate` fixes it).
- **Honest limits:** a scripted **auto-give that displaces a held gun** (Paradise Box,
  glitch altar) could read the displaced gun as "replaced" — rare, end-of-run, aggregate;
  accepted like the box auto-give note. A voluntary swap that straddles a down is missed
  (re-baseline is conservative — undercount replacements rather than mis-blame a death).

Activation: same as Tier B — `wrangler d1 execute … --file=schema.sql` (additive
`gun_drop`) + `wrangler deploy` + the next `-GscOnly` build.

## 4. Risks

| # | Risk | Mitigation |
|---|------|-----------|
| **R1** | Variant-fold row fragmentation — a FUTURE unregistered `_upgraded`-convention port folds to a `_up` row and undercounts into `other`. Current roster is safe (all CSV-registered). | `acc_gun_id()` strips a trailing `_upgraded`/`_up`/`_zm` before matching; dev assert if a folded key still ends `_up`. `gen_gun_ids.js` aborts the build on an unmapped live gun. |
| **R2** | **Transport flakiness (the feature-blocker).** `Engine.DvarString` read is unverified (0 LUI dvar reads in the repo). If it returns empty/nil, `guns` is empty; game still posts, but no gun data ever lands. | Mandatory §5 checksum-verified probe BEFORE reliance; `guns` optional end-to-end (degrades to leaderboard-only); documented clientfield fallback. |
| **R3** | Box-grab / laststand mis-credit (stale/old gun, laststand pistol). | Pause the sampler on `self.acc_box_grabbing` + `self.laststand` (both shipped; sampler only reads them). |
| **R4** | Stale dvar leaks across games. | Reset `acc_lb_guns`/`_ck` to `""` at match start; publish fresh right before `OpenLUIMenu`. |
| **R5** | Gun insert 500s the game row. | Separate guarded block AFTER the committed games upsert. |
| **R6** | Double-count (marathon re-open / co-op re-POST). | `PRIMARY KEY(session_id, gun_id)` + idempotent `DO UPDATE SET seconds=excluded.seconds`. |
| **R7** | Local-only build (empty URL) runs gun code with no backend. | Place the guns block INSIDE the `if URL ~= ""` branch. |
| **R8** | `is_offhand_weapon` drops the Leviathan. | Use individual non-melee predicates; keep melee; name-skip only `knife`/`bowie_knife`. |
| **R9** | Anonymity via join. | Payload is aggregate-only (no per-player gun vector) → a join can't attribute a gun to a person; `gun_time` stores no names. Stronger separation = §6 Q4. |
| **R10** | Extractable write key (casual telemetry). | Server-side clamps (id range, secs cap, guns cap); documented not cheat-proof (mirrors docs/40). |
| **R11** | **Load-path fragility (burned 2026-07-12).** | **CONFIRMED this feature touches NOTHING on the boot/load path:** sampler wires from `on_player_connect` (post-init); `acc_gun_id()` is a pure switch; dvar publish + rec chunk run only at `end_game`; generator is build-time. No new `#precache`, no GDT/geometry → `-GscOnly` build, no LED bake. |

## 5. Phased build order + verification

- **Phase 0 — Registry & generator** (minutes, no game run): author `tools/gun_ids.json`
  (31 box guns + tombstones; `pistol_standard` is EXCLUDED per decision 3, not given an id);
  write `tools/gen_gun_ids.js`;
  generate the GSC `acc_gun_id()` block + `backend/leaderboard/gun_ids.json`.
- **Phase 1 — GSC measurement** (ships day 1; verify with local log only): build
  `_acc_weapon_usage.gsc` (sampler + exclusion + `serialize()` + `checksum()`),
  wire into `acc_main`, `-GscOnly` build. Verify with NO transport — `lb_log` the
  full accumulator at end_game (`[USAGE] id name secs`, total, players, end_round).
  **Oracle runs:** hold one gun ~60 s → `secs≈60`; swap 30/30 → ≈50/50; confirm
  Leviathan folds to `leviathan` and grenades/fists/downed-pistol are excluded.
- **Phase 2 — Transport verification (MUST pass before trust):** a dev probe (model
  on `dev_fetch_probe`): GSC `SetDvar` a known string + checksum; probe LUI reads via
  `Engine.DvarString` (test arity variants `(name)` and `(ctrl,name)` + any `CoD.*`
  accessor in one pass, log which returns non-empty), recomputes the checksum, echoes
  `acc_lb_guns_ck_lui`; GSC logs `gsc=<C> lui=<C'> MATCH/MISMATCH`. **MATCH = pipe
  trustworthy; MISMATCH/empty = do NOT wire the payload, escalate to the clientfield
  fallback.** This is the gate the whole feature hinges on.
- **Phase 3 — Backend** (minutes; `wrangler deploy`, no rebuild): `gun_time`
  migration; ingest in `POST /games`; `GET /stats/guns.txt|.json`. Verify by manual
  `curl` of a hand-built payload to a **staging** table, then `wrangler d1 execute …
  SELECT`.
- **Phase 4 — Wire the payload (after Phase 2 MATCH):** add the `SetDvar` publish +
  the `guns` block. Full-chain proof on a non-dev/god build: GSC ints (Phase 1 log)
  == LUI-read ints (checksum) == `acc_lb_post.json` == D1 row; then `GET /stats/guns`
  shares sum ~1.0 and the deliberately-most-held gun tops the list.

## 6. Decisions — RESOLVED (user, 2026-07-12)

1. **Downed time — EXCLUDED.** Sampler pauses while `self.laststand`; laststand-pistol
   time is not counted.
2. **Vanilla melee/fists — EXCLUDED.** Leviathan wonder-melee still counts (decision 3);
   plain `knife`/`bowie_knife`/fists are skipped by name.
3. **Starting pistol — EXCLUDED entirely.** `pistol_standard` is a default state, not a
   weapon choice — dropped like fists (NOT given an id, NOT folded into `other`). So the
   id set is **31 box guns → ids 1..31; id 0 = `other`/unknown catch-all**; there is no
   id 32. `usage_base_name()` returns `undefined` for `pistol_standard`.
4. **Anonymity — KEYED token, honest tiers (agent's call; user deferred "idk";
   CORRECTED after adversarial review).** `gun_time` never stores the raw `session_id`
   — it stores `game_key`, a keyed hash of the session. The payload is **always**
   aggregate-only (all-players sum, no per-player gun vector), so **no individual is
   ever attributable in co-op** regardless of joins. On top of that:
   - **With `GUN_KEY_SECRET` set** (`wrangler secret put GUN_KEY_SECRET` — a value NOT
     in the fastfile and NOT in D1): `game_key = HMAC-SHA256(secret, session)`, which a
     D1 reader **cannot** recompute from `games.session_id` → `gun_time` is genuinely
     unjoinable to gamertags. **Recommended.**
   - **Without the secret:** a plain digest fallback that a DB *operator* could
     recompute from `games.session_id` (a review caught that a bare `sha256(session)` is
     NOT "structurally unjoinable" — the earlier claim was wrong). A **solo** game would
     then be operator-joinable to its player; co-op stays k-anonymous. Low-sensitivity
     gun data, so the fallback is acceptable out-of-the-box; set the secret for the
     strong guarantee. (Never key with `ACC_KEY` — it ships extractable in the fastfile.)
5. **`duration_secs` — ADDED.** The rec chunk includes `duration_secs` (`os.time`-based
   or GSC `GetTime()/1000` at end_game) so the Worker can apply the tighter sanity clamp
   `Σ seconds ≤ duration_secs · players · 1.1` (reject the gun payload, keep the game
   row, if exceeded).
6. **Round-weighting — FLAT NOW, curve later.** Ship `w(r)=1`; store `end_round` per
   gun row so a bounded curve (`min(r,30)/30` or `log2(1+r)`) can be switched on later
   via `wrangler deploy` with no game rebuild.

*(§3.1, §3.2, §3.4, §3.5 below already reflect these — the doc is internally consistent
and implementation-ready.)*

## Sources

6-agent parallel research (workflow `weapon-usage-research`, 2026-07-12) over
`_acc_weapon_variants.gsc`, `_acc_gun_badges.gsc`, `_acc_pap_levels.gsc`,
`_acc_overclocks.gsc`, `_acc_weapon_abilities.gsc`, `_acc_leaderboard.gsc`,
`_acc_map_randomizer.gsc`, `_acc_damage.gsc`, `tools/gen_weapon_stats.js`,
`tools/lui_chunks/acc_lb_rec_chunk.lua`, `tools/build_lb_lui.js`,
`backend/leaderboard/worker.js` + `schema.sql`, `gamedata/.../zm_levelcommon_weapons.csv`,
`docs/19_lui_pipeline.md`, and the stock mirror `tmp/bo3_stock_ref/` — every §3
claim carries file:line evidence in the workflow journal.
