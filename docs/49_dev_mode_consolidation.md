# docs/49 — One hardcoded dev mode (research + change plan, NOT built)

**Status:** ✅ **BUILT 2026-06-22** (`-GscOnly`, BUILD OK) — the §3 non-breaking plan was implemented:
`acc_resolve_dev_flags()` + `level.acc_dev` + the 6 converged reads + one-shot 25 shards + the
single-flag launch. Reviewed adversarially. (Originally 9-agent research, 2026-06-21.) Not yet playtested.

**The user's goal:** ONE `acc_dev` flag. Off = normal play. On = a **fixed, hardcoded** dev config (god /
unlimited / all-unlocked / open map / power on / test bosses). **Not** a runtime console you tweak — see
CLAUDE.md "Dev/test mode" + memory `dev-mode-hardcoded-not-console`. Never "set dvar X in console".
**Hard requirement (user 2026-06-21): do NOT break anything — build on the path that already works.**

**Decisions locked:** Shards in dev = a **one-shot start grant** (NOT the old per-second 999 pin). Current value
(user 2026-06-25): **start with 1000** Data Shards (`ACC_DEV_SHARDS`, granted in `acc_data_shards::on_player_connect`),
with the per-player cap raised to 1000 in dev (`shards_cap()`) so pickups don't clobber it back to the 500 ship cap.

## 1. Root cause of "some flags don't work" (CONFIRMED)

`acc_dev` is **read at 6 call sites, each with its own literal default**, and is **never `SetDvar`'d** anywhere
(0 matches). So when the `+set acc_dev` arg doesn't arrive — or in any no-flag launch — each site falls back to
**its own default**, and the defaults **disagree**:

| Default **1** (acts dev-ON) | Default **0** (acts dev-OFF) |
|---|---|
| `zm_abandoned_cyber_city.gsc:170` (entry dev loop) | `_acc_perks.gsc:140` (all-perk-slots) |
| `_acc_dev.gsc:43` (dev module) | `_acc_boss.gsc:80` (Brutus test boss) |
| `_acc_boss_glitch.gsc:113` | |
| `_acc_boss_phantom.gsc:123` | |

→ A plain launch silently runs a **partial dev state**: money / shards / HUD / Glitch+Phantom **ON**, but the
perk-slot unlock and the Brutus test boss **OFF**. That mismatch *is* "some flags don't work." The fix is to
stop letting each site invent a default: **resolve `acc_dev` once and share it.**

## 2. Secondary problems (all verified)

- **Ships ON.** `acc_dev` *and* `acc_open_map` default 1 → a public build runs god/open-map/decon-off unless
  every scattered default is flipped (the `TODO(ship)` at entry :168 + `_acc_dev.gsc:42`). The inverse footgun.
- **Per-second clamp loop.** `acc_hardcoded_dev` re-tops money (<100k→1M) and re-grants shards (<200→+999)
  **every 1s** (`zm_abandoned_cyber_city.gsc:269-314`). It **pins the shard economy** so you can't test a spend
  — which is *why* the `acc_dev_shards` sub-flag exists. "Dev + real economy" is impossible without another flag.
- **Two duplicate money loops** — entry `acc_hardcoded_dev` AND `_acc_dev::dev_unlimited_money`, independent 1s
  timers, separate constants → drift/double-grant.
- **Steam command-line doubling** is real (docs/23) but its symptom is a *black screen* (gametype→tdm), not a
  missing `acc_dev`. The "+set after logfile is dropped" claim was **refuted** — flags after `logfile` work, and
  `+set` dvars ARE applied before GSC `main()` runs. **So the timing of `+set` itself is fine** — the failure is
  the per-file default skew + (occasionally) dropped trailing args, not *when* `+set` lands.
- **~13 scattered dev knobs** total: `acc_dev`, `acc_dev_perks`, `acc_dev_shards`, `acc_open_map`,
  `acc_auto_power`, `acc_dev_jugg_mega`, boss-test (`acc_test_boss`/`acc_glitch_test`/`acc_phantom_test`, which
  also auto-fire under `acc_dev`), debug channels (`acc_drops_debug`/`acc_crash_debug`/`acc_trench_dbg`). Plus a
  **hardcoded wallhack** not behind any flag (`_acc_health_bars.gsc:263-272`). And `acc_dev_zone_hud` /
  `acc_dev_cur_zone` aren't dvars at all — per-player struct fields (mis-named).

## 2.5 The path that WORKS today + the REAL reason "one flag" attempts fail

**What works (the known-good path, do not rebuild it):** double-click `PLAY_TEST_MAP.bat` (or
`run_game.ps1`). It passes **~10 `+set` flags explicitly** — `acc_dev 1` AND `acc_open_map 1` AND
`acc_test_boss 1` AND `acc_glitch_test 1` AND `acc_amb_on 1` AND `acc_lockdown_on 1` … (the full string is
`PLAY_TEST_MAP.bat:66` / `run_game.ps1:90`). With every flag named, the two dev engines run and the whole
sandbox lights up. The engines are:
- `acc_hardcoded_dev()` (`zm_abandoned_cyber_city.gsc:245-315`) — money / shards / mega bottles / banner / auto-power.
- `acc_dev::init()` (`_acc_dev.gsc`) — sets up TWO ALWAYS-ON features ABOVE the dev gate, for every player in
  dev AND normal play (NOT dev tools): the crosshair **damage numbers** and the top-center **area-name banner**
  (`dev_player_hud_loop`, user 2026-06-27). Everything BELOW the gate is dev-only: perk-slot max, the "DEV MODE
  ACTIVE" line, console teleports / round-skip / power-on watchers. (The door-marker HUD was removed.)

**The real reason your past "single flag" attempts failed:** `acc_dev 1` **by itself does NOT turn the others
on.** Each dev behavior gates on its **OWN** flag, read at its own site (verified):

| Dev behavior | Gating flag | Read at | Default |
|---|---|---|---|
| Open the whole map | `acc_open_map` | `zm_abandoned_cyber_city.gsc:172` (in `main()`) | 1 |
| Auto power-on | `acc_auto_power` | `zm_abandoned_cyber_city.gsc:260` (runtime) | 0 |
| Unlimited shards | `acc_dev_shards` | `zm_abandoned_cyber_city.gsc:289` (runtime loop) | 1 |
| Brutus test boss | `acc_test_boss` (**OR** `acc_dev`) | `_acc_boss.gsc:80` (per-round) | 0 / 0 |
| Glitch Stalker test | `acc_glitch_test` | `_acc_boss_glitch.gsc:112` (per-round) | 0 |
| Phantom test | `acc_phantom_test` | `_acc_boss_phantom.gsc:122` (per-round) | 0 |
| All perk slots | `acc_dev` **AND** `acc_dev_perks` | `_acc_perks.gsc:140` (per-call) | 0 / 1 |
| Ambient audio | `acc_amb_on` | `_acc_atmosphere.gsc:321` (runtime) | 0 |
| DEFCON lockdown | `acc_lockdown_on` | `_acc_lockdown.gsc:158` (module init) | 1 |

So if you launch with just `+set acc_dev 1`, you get money/shards/HUD/perks but **NOT** open-map, test bosses,
or ambient — they need their own flags. The `.bat` hides this by listing all ten. **That mismatch — `acc_dev`
not driving the others — is the "some flags don't work."** (The per-file default skew on `acc_dev` itself,
§1, is the secondary half.)

## 3. The fix — make `acc_dev` DRIVE the others (additive, non-breaking)

**Do not rewrite the working engines.** Add ONE small driver and let it set the other flags from the single
switch. Read sites stay exactly as they are, so nothing that works today can break.

**New `acc_dev::resolve_and_drive()`**, called as the **first line of the dev section in `main()`** (just
**before** `zm_abandoned_cyber_city.gsc:170`, because `acc_open_map` is read at :172 inside `main()` — the only
timing-critical read; every other flag above is read at runtime or in `acc_main::init` (line 238), all *after*
this point). It does:
1. `dev = getdvarint("acc_dev", DEFAULT)` **once** (`DEFAULT` = `1` for the current pre-release, `0` for ship);
   cache `level.acc_dev = (dev == 1)`.
2. **`SetDvar` the whole dev bundle to `dev`** — on when dev, off when not:
   `SetDvar("acc_open_map", dev)`, `acc_auto_power`, `acc_test_boss`, `acc_glitch_test`, `acc_phantom_test`,
   `acc_dev_perks`. (Values are strings in GSC: `"1"`/`"0"`.)

Because the driver runs before every read, the existing `getdvarint` sites now all see the **one** flag's value
— `+set acc_dev 1` alone turns the full sandbox on, and `acc_dev 0` forces it fully off (the mismatched
read-site defaults become irrelevant, so the §1 skew + the scattered `TODO(ship)` are both neutralized at once).

**Verified non-breaking:** nothing reads any of these flags before the driver's `main()` insertion point —
`zm_usermap::main()` (:144) is stock and never touches `acc_*`; `acc_main::pre_init` is :181 (after); modules
init at :238 (after). So the SetDvars are always visible to their readers. The `.bat`/`.ps1` keep working
verbatim during the transition (passing a flag the driver also sets is harmless — same value).

**Shards (locked):** replace the per-second `< 200 → grant 999` pin (`zm_abandoned_cyber_city.gsc:289-294`)
with a **one-shot grant of 25** at first spawn (still `"dev"` source so no diminishing/cap fight). Dev now
starts you with 25 shards and lets the real economy run from there — no economy pinning, no `acc_dev_shards`
sub-flag needed.

**Separate "dev convenience" from "always-on gameplay" (cleanup, not a behavior change):** `acc_amb_on`
(audio), the `acc_zspeed_*` curve, weapon variants, and DEFCON lockdown are **gameplay**, not dev — they
shouldn't ride `acc_dev`. The `.bat` only bundles them because it's the test launcher. Set each to its intended
NORMAL default in code; leave them OUT of the dev driver. (This is why the `.bat` is so long — it conflates
"dev" with "things I want on while testing.")

## 4. Exact change list (small + safe; when greenlit)
- **`zm_abandoned_cyber_city.gsc`** — add `acc_dev::resolve_and_drive()` just before :170; change the shard
  block (:289-294) to a one-shot 25. (Keep `acc_hardcoded_dev` and `acc_hardcoded_open_map` as-is — they still
  run, now driven by the one flag. Optional later: fold the duplicate `_acc_dev::dev_unlimited_money` loop away,
  but that's a *separate* tidy-up, not required for one-flag.)
- **`_acc_dev.gsc`** — add `resolve_and_drive()` here (namespace `acc_dev`); flip the ship `DEFAULT` knob to 0
  when we cut a public build. No change to its working `init()` engines.
- **Optional convergence (do AFTER the driver proves out, lowest priority):** point the 6 `acc_dev` reads at
  `level.acc_dev` to delete the default-skew permanently. The driver already neutralizes the skew, so this is
  belt-and-suspenders, not load-bearing.
- **Launch** — `PLAY_TEST_MAP.bat` / `run_game.ps1` / `tools/run_game.ps1`: can collapse to a single
  `+set acc_dev 1` (place it right after `logfile`). Safe to do incrementally — the driver makes the extra
  flags redundant, so removing them changes nothing.
- **God mode** — was briefly added (`EnableInvulnerability` each tick) then **removed** (user 2026-06-22:
  "I like to test with regular gameplay"). Dev does NOT grant invulnerability.
- **Docs** — `docs/34` (flag reference) + the `.bat`/`.ps1` header comments updated; the hardcoded wallhack
  (`_acc_health_bars.gsc`) folded under `level.acc_dev`.

## 5. Decisions (resolved)
1. **The dev bundle** (`acc_dev 1`): money + **25 shards (one-shot)** + mega bottles + all perks/slots + open
   map + all 3 test bosses + dev HUDs. **No god mode and no auto power-on** — regular gameplay/damage, and
   you flip the Bus Station power switch yourself.
2. **Default** — `acc_dev` DEFAULT **1 during the pre-release** (dev on even if the launcher drops the arg);
   one-line `TODO(ship)` to flip to 0 before a Workshop build.
