# Changelog

All substantive design + implementation changes. Follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) structure loosely. Dates are when the change was decided / committed, not shipped.

Version scheme: `v0.x.y` during pre-release (no public v1.0 yet). `v1.0.0` = first Workshop publish.

## [Unreleased]

### Fixed — Jukebox "NOW PLAYING" banner didn't show on purchase (user, 2026-06-28)

Buying a teddy-bear song in the north trench room played the song but showed **no UI**. The banner used
`acc_utility::hud_msg` — a lazily-created **server hudelem** that silently fails to appear when the hudelem pool
is exhausted (the user hit it in **dev mode**, where the extra dev HUDs pressure that shared pool). Switched the
all-player "NOW PLAYING <title>" banner in [_acc_ee_song.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_ee_song.gsc)
`bear_watch` to **`IPrintLnBold`** — the engine built-in, pool-FREE, all-client announcement this map already uses
for the Paradise gate / soul milestones — so it shows reliably regardless of pool pressure or dev mode. The
per-player deny toasts ("Need N points" / "Jukebox busy") stay as `hud_msg` (minor, and they also play a sound).
GSC-only.

### Added — 2nd Cyberware Overclock station on abyss L5 (user, 2026-06-28)

Placed an extra Overclock terminal on the **bottom abyss floor (L5, z=-1200)** at `(400, 1948, -1200)` EAST — opposite the
existing L5 ammo crate (WEST), mirroring the L2 "OC + crate on opposite chunks" layout. One line in
[_acc_glitch_altar.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_glitch_altar.gsc) `spawn_altars`
(`acc_overclocks::spawn_terminal_at`), so it's a **pure GSC spawn** — `-GscOnly`, **no `.map` edit** (deliberately avoids the
in-flight geometry work). The proximity info card works automatically (`spawn_terminal_at` appends `level.acc_oc_kiosk_origins`).

**Collision is QUEUED, not yet baked:** a deep clip (`add_prop_clips.js` `overclock_l5`, brushmodel/LED-exempt) was added to the
clip data but NOT emitted — making it solid needs an `add_prop_clips.js` run + a full LED bake (a `.map` change). So the terminal
is **functional now but its kiosk model is walk-through** until the next geometry/bake pass folds the clip in. docs/48 synced.

### Added — Crouch drop-in shortcut beside each trench staircase (user, 2026-06-28)

A **crouch-height window** in the **rim parapet** right beside each staircase (the "wall with the bridge" = this rim parapet, which the bridge column plugs into), so a player can crouch through and **drop straight into the trench** (~240u fall → fall damage, a deliberate PhD-Flopper play) instead of taking the stairs. [tools/gen_trench_walls.js](tools/gen_trench_walls.js) splits the parapet around an opening (`OPEN_W 56` wide × **64u tall**, open z[0,64] with a header z[64,128] above so it still reads as a wall) — sized so a standing hull (~72u) won't fit, forcing a crouch. West: south parapet beside the W stair (x[−665,−609]); East: north parapet beside the E stair (x[647,703]). Layout is now `Stairs → [crouch drop-in] → Wall → Bridge → Wall` on both sides. (First attempt put it in the stair's *pit-side* wall and too small at 48u — moved to the parapet + enlarged, user 2026-06-28.) World-brush geometry → fast-bake-gated (BAKED) + FULL cod2map/LED/navmesh rebuild.

### Changed — Perk-card UI text: Quick Revive regen wording + dropped the obvious Jug no-perk line (user, 2026-06-28)

Clarity pass on two perk cards ([acc_hud.lua](ui/uieditor/menus/hud/acc_hud.lua)):
- **Quick Revive** base `Heal up sooner` → **`Health regen starts sooner`**; Mega `Heal even sooner` → **`Regen starts even sooner`** (the latter also re-syncs the card to docs/50, which the `.lua` had drifted from).
- **Jugger-Nog** base: dropped the **`(no perk: dies fast)`** line — redundant ("it's obvious", user). docs/50 synced. LUI rawfile (linker build).

### Reverted — Under-room resize abandoned; teddy room restored to original (user, 2026-06-28)

A resize of the teddy/song (NORTH) + exo/Foundry (SOUTH) under-rooms was attempted (384×344 → 320×200 → 352×272 → "back to original") via two new regenerator tools, then **abandoned** — the tools were wrong and the user caught it. **Root cause:** these under-rooms are NOT self-contained; their `UNDER ROOM <SIDE>` block is just the **floor slab + room floor** (NORTH = 2 brushes, SOUTH = 3) — the room's actual **walls come from the surrounding corp-trench geometry**. My regenerators emitted the full add_under_room-style **7-brush** structure (slab + side/back fills + front walls), which **duplicated/conflicted** with the corp walls and reshaped the room ("removed part of the room").
- **Fix:** the NORTH teddy room is restored to its true **original 2-brush block**, spliced from a pre-change `.map` backup (not regenerated). The SOUTH/exo room was left as-is (user: "the exo room is fine"). The two flawed tools (`gen_shrink_north/south_room.js`) were **deleted**. Memory `under-room-shrink-regenerator-bake-safe` rewritten as the cautionary lesson.
- **Also:** the reactor plinth (`p7_cai_sign_inteactive_kiosk`) is too **deep** to sit dead-center behind the center bear without overlapping it even at the back wall (reported "on the bear" twice — "back" never cleared it). The user wanted it **kept centered**, so instead of touching the corp geometry the **3 jukebox bears were nudged forward** y2430 → **y2350** ([`_acc_ee_song.gsc`](scripts/zm/zm_abandoned_cyber_city/_acc_ee_song.gsc)), giving ~143u clearance so the plinth stays **dead-center** at (0,2493) and clear. [`_acc_reactor.gsc`](scripts/zm/zm_abandoned_cyber_city/_acc_reactor.gsc) + `add_prop_clips.js`. FULL LED-baked build.

### Fixed — Area/room banner moved up off the boss + Paradise UI (user, 2026-06-28)

The on-entry area-name banner (`acc_dev_zone_hud`, shown in **both** modes — only the "DEV MODE ACTIVE" print is dev-gated) sat at TOP+20 scale 2.0; its tall line grew downward into the top-center dynamic cluster (Phantom/boss nameplate y22 + bar y46, Paradise timer y24) and overlapped them. [`_acc_dev.gsc`](scripts/zm/zm_abandoned_cyber_city/_acc_dev.gsc): pinned to the top edge (TOP+20 → **TOP+2**) and trimmed scale (**2.0 → 1.3**) so the ~16px line sits cleanly **above** the y[22,60] cluster. (A scale-2.0 line can't fit above y22 by moving the anchor alone — hence the trim; the alternative was moving it *below* the boss bar.) GSC-only.

### Changed — Brutus + Phantom HP now compound at 1.1/round like zombies (user, 2026-06-27)

Both bosses now scale HP at the **same 1.1 per-round exponent as the regular horde** (were 1.08 / 1.06):
- **Brutus** [`_acc_boss.gsc`](scripts/zm/zm_abandoned_cyber_city/_acc_boss.gsc) `ACC_BOSS_MINI_HP_EXP` `1.08 → 1.1`. Base 48k @ anchor r5 → solo **r10 77k / r20 200k / r30 520k / r40 1.35M**.
- **Phantom** [`_acc_boss_phantom.gsc`](scripts/zm/zm_abandoned_cyber_city/_acc_boss_phantom.gsc) `ACC_PHANTOM_HP_EXP` `1.06 → 1.1`. Base 56k @ anchor r10 → solo **r10 56k / r20 145k / r30 377k / r40 977k**.
- Brutus **stays the tankier of the two** despite the equal exponent — it anchors 5 rounds earlier (r5 vs r10), so it accrues more compounding. Base HP + anchors + the logarithmic co-op mult unchanged. Live dvars `acc_boss_mini_hp_exp` / `acc_phantom_hp_exp`. Docs 11/34 synced. GSC-only.

### Changed — Sniper reserve nerf: MORS −15%, Paladin −15% (user, 2026-06-27)

Reserve-only (clip/damage path untouched), applied **evenly across all 16 forms each** (base + `_up` + 14 perk twins):
- **MORS** (clip 1, so maxAmmo == reserve rounds): `48/72 → 41/61` rounds (−14.6% / −15.3%).
- **Paladin** maxAmmo `12 → 10` mags → reserve `96/132 → 80/110` (−16.7%; closest even integer-mag cut to −15%, since reserve = maxAmmo × clip 8/11).
- Durable record in [`tools/reduce_base_ammo.js`](tools/reduce_base_ammo.js) `MAXAMMO_FIX` (MORS values + a new Paladin block).
- **Applied SURGICALLY to the live GDT `maxAmmo`/`startAmmo`, NOT via a tool re-run** — a full-diff (`live` vs `.acc-ammo-orig`) found the reduce backups are **stale**: Paladin `locHead`/`locHelmet` 5.0 (fix_paladin_loc) and MORS `_up` damage 1500/minDamage 750 (PaP-form tuning) ran *after* reduce last snapshotted, so a blind `reduce_base_ammo.js` re-run would silently REVERT those fixes. A `WARN` block in the tool documents this — refresh those backup fields (or re-apply the loc/PaP tools after) before any future re-run. Built via `gdtdb /update` + linker.

### Changed — Gun damage retune: Paladin −25%, MORS −35%, RW1 +20%, MK14 −10% (user, 2026-06-27)

Pure damage tweaks via [`_acc_damage.gsc`](scripts/zm/zm_abandoned_cyber_city/_acc_damage.gsc) `acc_weapon_balance_mult` (`IsSubStr` match → covers **base + `_up` + every twin** in one value; scales body AND headshot proportionally):
- **Paladin HB50** ×`0.4753 → 0.3565` (−25%); full PaP+OC ~5,228 → ~3,921/shot, ~13.1k → ~9.8k/head.
- **MORS** ×`0.66 → 0.429` (−35%); ~10,890 → ~7,079/shot.
- **RW1** ×`0.11 → 0.132` (+20% **buff**); ~1,210 → ~1,452/shot.
- **MK14** ×`0.291 → 0.2619` (−10%); ~1,921 → ~1,729/shot.
- **PaP price tiers + box odds DELIBERATELY UNCHANGED** (user: "don't touch anything else… only a damage change") — `compute_gun_tiers.js` / docs/54 NOT regenerated; the runtime pricing (`pap_price_bucket`) and box weight (`acc_box_weight`) are independent hardcoded functions and stay as-is. Paladin's separate `acc_paladin_boss_mult` boss cut stacks, so its boss damage also drops 25%. Docs 05/41 synced (tiers/scores kept). GSC-only.

### Changed — PhD Slider (Mega PhD Flopper) nerf: frozen damage + half radius + 10-hit cap (user, 2026-06-27)

The Mega slide nova used to track **live** `level.zombie_health` and ran through the global ×2.75 buff + the
+15% Mega Flopper bonus, so it one-shot trash at **every** round ("a single slide" forever) and read ~64k vs
bosses. It now deals a **frozen** damage = a **round-16 normal-zombie's health** (solo **1851** = 950 × 1.1⁷;
scaled by the co-op regular-HP mult so it holds in any lobby), dealt **raw**:

- **One slide one-shots trash through round 16**, then takes **2 slides** (~r17–23), then **3** (~r24–27), as
  zombies outscale the frozen value — exactly the requested "single slide until 16, then 2, then 3".
- The nova now **bypasses** the `on_ai_damage` global ×2.75 + the whole bonus chain (new `attacker.acc_phd_nova_hit`
  tag set around the `phd_explode` damage loop), so the frozen number is *exactly* what lands and can't balloon
  past the breakpoint. Without this, the multipliers pushed the one-shot ceiling out to ~round 30.
- **Half radius:** Mega slide/down nova `ACC_PHD_MEGA_EXPLODE_RADIUS` **500 → 250u** (base on-down stays 300u).
- **10-zombie hit cap:** the Mega nova now damages at most **10 targets per slide** (`ACC_PHD_MAX_HITS` / dvar
  `acc_phd_max_hits`, 0 = uncapped); the base on-down nova stays uncapped (it's a panic clear).
- **Boss-safe:** the frozen value doesn't scale with round (~1851 solo on a 48k+ boss = chip), and the existing
  **10% boss per-hit cap is still applied** on the bypass path. So PhD can't go crazy on bosses.

Base PhD (on-down panic nova) is unchanged — still live round-scaled. New helper `phd_round_zombie_health()`
mirrors stock `ai_calculate_health` (150 start, +100/round to r9=950, then ×1.1). Breakpoint is the live dvar
`acc_phd_freeze_round` (16); the old `acc_phd_mega_dmg_mult` is retired. GSC-only (`-GscOnly`, no `.map` edit).
Synced: [_acc_perk_phd_flopper.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_perk_phd_flopper.gsc),
[_acc_damage.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_damage.gsc), docs/13, docs/perk_abilities. xref lint
clean. **Not yet built** — staged while the user is mid-playtest (building with BO3 open corrupts the zone).

### Changed — Trench passive-income curve retuned (user, 2026-06-27)

The seconds-between-passive-shard-grants per trench layer changed from **45 / 35 / 28 / 22 / 18** to
**50 / 34 / 22 / 14 / 10** (L1→L5). L1 (Bus Station pit) is slightly slower (45→50s); every deeper layer is
faster, with a steeper drop — L5 now pays 1 shard every 10s (was 18s). Net effect: shallow loitering is nudged
down, deep diving is rewarded harder. Defaults + comments in
[_acc_bus_trench.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_bus_trench.gsc) `trench_income_interval`
(dvars `acc_trench_income_l1`…`_l5`); docs/34 + docs/06 synced. GSC-only (`-GscOnly`, no `.map` edit).
**Not yet built** — staged while the user is mid-playtest (building with BO3 open corrupts the zone).

### Changed — Trench per-layer zombie scaling retuned down (user, 2026-06-27)

Softened all three trench/abyss per-layer levers (each applies per depth layer 1–5, on top of normal round scaling):
- **Speed** `+5% → +4%`/layer (`acc_trench_layer_speed_pct`, [_acc_zombie_speed.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_zombie_speed.gsc) `apply_speed_for_round`) → L5 +20% (was +25%).
- **Health** `+50% → +30%`/layer, one-way (`acc_trench_layer_hp_pct`, `apply_trench_health`) → L5 +150% (was +250%).
- **Melee** `+10 → +6` HP/layer, flat (`acc_trench_layer_dmg_add`, [_acc_bus_trench.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_bus_trench.gsc) `trench_melee_scaled`) → base 45 now ≈51/57/63/69/75 per hit (was ≈55…95).
- **Paradise inherits automatically** — its onslaught reads the same `paradise_buff_layer` / `apply_trench_health` / `trench_melee_scaled` path, no separate change. Docs [11](docs/11_enemies.md)/[34](docs/34_flags_reference.md)/[46](docs/46_trench_systems_guide.md) synced (also fixed docs 11/34 still showing the old +25% health). GSC-only.

### Changed — Paradise gate cost now scales by player count (user, 2026-06-27)

The communal Paradise door (`acc_abyss_hub_door`, the L5 gate into the final-onslaught hub) was a flat **100 Data
Shards + 100,000 points**. Now it **scales with the live player count**: **solo = 50 shards + 50,000 points**, and
**+25 shards + +25,000 points per extra player** — so 2p = 75/75k, 3p = 100/100k, 4p = 125/125k. Both pools stay
communal (the team contributes-all; each pool draws down separately).

Implemented like the abyss soul-box gates' `souls_needed` (same file): new `hub_cost_shards()` / `hub_cost_points()`
helpers (dvars `acc_hub_door_shards_solo` 50 / `_per` 25 / `acc_hub_door_points_solo` 50000 / `_per` 25000; dev mode
keeps the cheap 10 / 10k testable override). A new `hub_cost_watcher` (mirrors `soul_hint_watcher`) keeps the price —
and the constant gate hint — aligned to the live count, then **locks it at the first contribution** so a
partially-paid pool is never rescaled if someone dis/connects. Constant-hint / triggerstring-cap design preserved
(re-sync only on count change = ≤4 strings). GSC-only (`-GscOnly`, no `.map` edit). Synced:
[_acc_abyss_doors.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_abyss_doors.gsc) header + defines, docs/48.
**Not yet built** — staged while the user is mid-playtest (building with BO3 open corrupts the zone).

### Changed — Glitch Purge −20% aggressiveness (user, 2026-06-27)

The sealed-room Glitch Purge (lockdown challenge) was nerfed **20% less aggressive**. The purge's aggression =
how many Glitch Stalkers are **simultaneously hunting you at once** in the sealed room — the concurrent cap.
`ACC_LDC_CONCURRENT_DEF` / `acc_lockdown_challenge_concurrent` **10 → 8** (−20% on-screen hunter density). At
steady state the room sits at the cap, so 8-vs-10 is the felt pressure; this is the same lever the "super easy"
fix raised `6 → 8 → 10` to make the purge *more* aggressive.

Deliberately a **single lever, no compounding**: the kill **count** stays `round × 2` (that's objective *length*,
not aggression) and the glitch **blink cadence / melee** stay put (they're shared with the regular Glitch Stalker —
touching them would nerf the normal boss too). GSC-only, live-dvar-tunable (`-GscOnly`, no `.map` edit). Synced:
[_acc_lockdown_challenge.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_lockdown_challenge.gsc) #define + live-knobs
header, docs/43. **Not yet built** — staged while the user is mid-playtest (building with BO3 open corrupts the zone).

### Fixed — deep abyss stations are solid again (Glitch Altar + Overclock + both Ammo Crates) (user, 2026-06-27)

The **Glitch Altar** (and the Overclock terminal + both Ammo Crates) were **walk-through**: GSC-spawned props get no
collision unless a clip brush is added, but a deep worldspawn `clip` brush (below z−240) crashes the LED bake
(`brush.cpp:1860`), so `add_prop_clips.js` had been *skipping* every abyss clip. (Pre-existing — at the last commit
the altar already sat at deep L3 with no clip; not introduced by recent work.)

Fix via the documented LED-exempt lever (memory `brushmodel-wall-led-exempt`): `add_prop_clips.js` now emits a deep
clip as a **`script_brushmodel` entity** (which the lightmapper *ignores*) instead of skipping it, when its PROPS
entry sets `brushmodel: true`. The 4 **abyss** stations are now clipped this way — Glitch Altar (L3 z−720), Overclock
terminal (L2 z−480), Ammo Crate L2 (z−480), Ammo Crate L5 (z−1200) — snug to each model silhouette, solid to
player/AI/bullets. The 4 **Paradise** stations stay walk-through for now (flip them by adding the flag).
**FULL build + LED bake passed** (no `brush.cpp:1860`; fresh `.ff`) — the brushmodel entities bake clean.

### Fixed — Crash-hunt pass: co-op thread leaks, disconnect-window CTD, boss soft-lock (user, 2026-06-27)

A two-pass multi-agent crash audit of all 59 GSC/CSC modules (every finding adversarially verified) surfaced
five runtime faults; all five fixed. GSC-only — `-GscOnly` build.
- **Per-life thread leak (THE co-op slow-burn)** — [_acc_perks.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_perks.gsc)
  `on_player_spawned` re-threaded `qr_regen_booster` (+ child `qr_damage_time_watcher`) and `savior_speed_watcher`
  every respawn, relying on `self endon("death")` to kill the prior life's copies — but a BO3 **ZM player never
  notifies `"death"`** (bleed-out routes to spectator; `"death"` only fires on disconnect). So every full-death
  respawn permanently STACKED 3 loops per player — duplicate per-frame `setnormalhealth` + duplicate
  `waittill("damage")` subscribers — growing for the whole run until the script VM degrades/exhausts (matches
  "the longer we play the worse it gets, then it dies"). Fix: `player notify("acc_perk_life")` before re-threading
  + `self endon("acc_perk_life")` on all three loops (the `acc_lui_life` per-life idiom).
- **Same leak class in the HUD** — [_acc_lui.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_lui.gsc)
  `maxammo_flash_watch` / `nuke_flash_watch` were missing `endon("acc_lui_life")` (their parent had it), leaking
  one thread each per revive. Added the endon to both.
- **Paradise Box disconnect-window CTD** — [_acc_glitch_altar.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_glitch_altar.gsc)
  `paradise_box_loop` runs on the box trigger (so its `endon("death")` doesn't fire on a player leaving); after the
  0.75s spin `wait` it derefed `player` (`weapon_give`/`PlaySound`/`.name`) with no re-check — a player disconnecting
  mid-spin → method call on a freed entity → whole-session co-op fatal. Added an `isdefined/is_player_valid`
  re-check across the yield (same fix as `_acc_overclocks::terminal_loop`).
- **Electric Cherry froze bosses (boss-round soft-lock)** — [_acc_perk_electric_cherry.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_perk_electric_cherry.gsc)
  `ec_nova` dropped the stock `is_brutus` guard, so the ~4s `ignoreall` stun applied to bosses (always non-lethal
  vs the nova) — reloading near a boss froze it most of the round. Now skips the stun for any `acc_is_boss`/
  `acc_is_mini_boss` (bosses still take the shock FX + nova damage).
- **Brutus respawn gate stuck-guard** — [_acc_boss.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_boss.gsc)
  `watch_mini_boss_death` cleared `acc_brutus_active` only on the `"death"` notify; if the host were ever removed
  without one, the Trench Warden could never respawn. Added `brutus_guard_failsafe` to release the gate if the
  host is freed silently. (Latent hardening — no known live trigger today.)

### Added — M60 S-tier wall-buy on Abyss Layer 5 (user, 2026-06-27)

A second deep-abyss S-tier wall-buy, mirroring the AK-47 on L4 exactly. On the **L5 (bottom) south wall west
jamb** (x=−400, y1725, z−1200): an **M60** wall-buy (1500), next to the bottom Ammo Crate before the Paradise
door. Built the stock-pattern way (same as Five-Seven/Olympia/AK-47):
- **`.map`**: a worldspawn chalk quad (`mtl_t6_wpn_lmg_m60_wall_chalk` — same bake-safe material.gdf class as
  the AK-47/Five-Seven chalks) + a `weapon_upgrade` trigger struct (`zombie_weapon_upgrade t9_m60`) + a model
  struct (`wpn_t9_m60_world`). The chalk is the AK-47 brush **translated −240u to L5** (t-coords are
  decal-relative — verified identical between the Five-Seven and AK-47 chalks — so the winding is preserved =
  bake-safe). Placed in the west jamb, clear of the centered doorway (x[−96,96]) and the far-west stairs.
- **`_acc_map_randomizer.gsc`**: added `t9_m60` to the `remove_all_wallbuys` keep-list (else it'd be stripped).
- Cost **1500** comes from the M60's existing `zm_levelcommon_weapons.csv` row (no CSV change). Docs/57 updated.
- **FULL build + LED bake passed** (no `brush.cpp:1860` crash; fresh `.ff`), per the geometry-change gate — the
  AK-47 deep wall-buy was the precedent that this would bake.

### Changed — Co-op roster HUD: tiered health bar + one-row stats + gun-HUD cleanup (user, 2026-06-27)

[_acc_health_bars.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_health_bars.gsc) + [acc_hud.lua](ui/uieditor/menus/hud/acc_hud.lua):
- **Tiered health bar** — each roster row's bar is now THREE proportional segments (`make_hp_seg`/`update_hp_seg`,
  0.4 px/HP): base 0–100 **green**, Jug 100–250 **darker green**, Mega 250–300 **dark green**, so you can see who
  has Jug/Mega at a glance. Segments fill left-to-right and deplete right-to-left; base flips amber when ≤30 HP.
  Tier bounds = `ACC_HP_TIER_BASE/JUG/MEGA` (100/250/300, a 5th Jug-numbers sync site).
- **Player state by bar/name colour** — alive = green tiers, **downed = red**, **dead = gray** (dead players stay
  on the roster, gray, until they respawn); the old "DOWNED" text was dropped.
- **One-row stats line** — `$points  SH {shards}  EXO {e}  MB {m}` on a single row (was split across the stats +
  perks lines). Each field can't share a `SetText` (unbounded score → `SetValue`; exact shards × EXO × MB would
  overflow the 2048 'string' cache), so they're 4 hudelems flowed by a char-count estimate (`ACC_ROSTER_STAT_CHARW`).
  The 3 hidden top-left shards/EXO/MB readouts were reclaimed to fund the extra elements.
- **Gun HUD** — removed the background plate + accent strip + corner brackets (floats now); melee weapons (Action
  Figure) show `-/-` instead of `0/0`.
- **Pool note:** the roster is now 9 hudelems/row — heavy in full 4-player co-op; the Jug/Mega tier segments are
  the first thing to trim if boss/event HUD ever fails to allocate. GSC + LUI only (`-GscOnly`).

### Added — Lucky Clover boss item (drop-luck doubler + bonus power-ups) (user, 2026-06-27)

- New **7th boss-pool item, "Lucky Clover"** [`_acc_boss_items.gsc`](scripts/zm/zm_abandoned_cyber_city/_acc_boss_items.gsc).
  Drops like any other item (boss kills + the 0.4% zombie roll); implant it at the Plaza Implant Bench. Mirrors the
  Loot Stash pattern: `apply_lucky_clover` sets a per-player flag, `player_has_clover()` is read at drop time.
- **While implanted, the carrier's KILLS are luckier** (per-killer, so co-op players each run their own):
  - Zombie **random-item** drop **0.4% → 0.8%** (×`acc_clover_mult`)
  - Zombie **Mega-Bottle** drop **0.4% → 0.8%** (×`acc_clover_mult`)
  - **+0.5%/kill** to force-drop a random power-up (full_ammo / insta_kill / double_points / nuke) at the corpse,
    bypassing the stock per-round cap (`drop_clover_powerup_at`, mirrors `_acc_elites::drop_recursion_powerup_at`).
- **Works during the Paradise finale** too (NOT gated out, per user). Bosses/mini-bosses still excluded from the
  base zombie rolls. Live dvars: `acc_clover_mult` (2.0), `acc_clover_powerup_chance` (0.005).
- **Placeholder model** = the **X2 power-up orb** (`p7_zm_power_up_double_points`, user "use the X2 for now") —
  stock-runtime-loaded (no zone line, same path as the carpenter model the Repair Kit uses); the X2 reads as the
  Clover's double-luck. Pickup hint still says "7 - Lucky Clover". Swap to a real clover model later.
  Doc: [docs/12](docs/12_boss_items.md).

### Changed — Abyss station layout finalized; ammo crates bookend the descent (user, 2026-06-27)

Final abyss-floor layout in [_acc_glitch_altar.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_glitch_altar.gsc)
`spawn_altars`: **L2 (−480)** Cyberware Overclock (west) **+ Ammo Crate (east)**, **L3 (−720)** Glitch Altar,
**L4 (−960)** = the AK-47 wall-buy (no GSC station), **L5 (−1200)** **Ammo Crate** (bottom, before Paradise).
So ammo refills **bookend** the dive — top up on entry (L2) and before the finale (L5). `spawn_crate_at` is just
called twice (one model+trigger each). GSC-only (deep clips stay skipped/walk-through; no orphan walls). Synced
docs/46, the clip bookkeeping in `add_prop_clips.js`, and the memory.

### Changed — Area-name banner now shows in BOTH dev and normal play (was dev-only) (user, 2026-06-27)

The top-center **area-name title** (e.g. `PLAZA`, `BUS STATION (TRENCHES LV2)`, `EXCHANGE BANK`) that reveals
when you cross from one area to another was **gated behind dev mode** — `dev_player_hud_loop()` was threaded
*below* the `acc_dev` gate in [_acc_dev.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_dev.gsc) `init()`, so
normal-play sessions never saw it. **Fix:** the loop is now threaded **above** the gate (alongside the
already-always-on crosshair damage numbers), so the banner is a permanent feature for **every player in both
modes**. The only remaining dev-only piece is the "DEV MODE ACTIVE" confirmation line — its `IS_TRUE( level.acc_dev )`
guard inside `ensure_dev_huds` is now load-bearing (keeps just that line dev-only). Behavior unchanged otherwise:
5s reveal + fade on the surface, held the whole time you're underground (it's pitch-black down there). No new
HUD element (the same single per-player `acc_dev_zone_hud` font string, now created for everyone). Docs/49 synced.
GSC-only build. Follow-up done same day (user "yes I want it"): added a **`PARADISE`** title — `dev_get_player_area`
now returns `"paradise"` via the existing `acc_bus_trench::player_in_second_part()` detector, `dev_area_name`
renders it, and `dev_update_zone` holds it **persistently** (like the trench) since Paradise is the dark/foggy
finale where a 5s fade gets missed. So every area a player can reach — surface zones, Exchange, trench/abyss
L1–5, and Paradise — now titles correctly for both modes.

### Changed — Abyss stations: one per floor (Ammo Crate → L3, Glitch Altar → L4) (user, 2026-06-27)

Spread the descendable abyss stations so **every floor has a reason to go deeper** (was: L2 doubled, L4 empty).
In [_acc_glitch_altar.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_glitch_altar.gsc) `spawn_altars`:
- **Cyberware Overclock** stays on **L2** (z=−480, west).
- **Ammo Crate** L2 east → **L3** (z=−720, west).
- **Glitch Altar** L3 → **L4** (z=−960, west; above the −1000 below-world cull, so no failsafe needed).

All three sit on the guaranteed-solid west slab (x[−781,−112], y=1948) per `gen_abyss_layer.js`. GSC-only (the
abyss floors are already baked). Descent loop: earn in the pit → Exo up top → OC L2 → Ammo L3 → Altar L4.
Docs/46 station table synced.

### Fixed — Ammo Crate no longer services the Action Figure (user, 2026-06-27)

The Action Figure (melee special, no ammo) could slip past the crate's "no PaP form" gate because
`make_actionfigure_packable` points its `level.zombie_weapons[w].upgrade` at **itself** (so the PaP machine
shows). Added an explicit name-based exclude in [_acc_ammo_crate.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_ammo_crate.gsc)
`crate_cost` (`t8_melee_figure` / `t8_actionfigure_melee` → 0), so the crate says "this weapon can't be
refilled here" and charges nothing. GSC-only.

### Changed — Action Figure: removed the cleave; PaP will scale SWING SPEED instead (user, 2026-06-27)

The Action Figure's per-PaP-tier **cleave / multi-hit** (extra nearby zombies one-knifed per swing) is **removed** —
it now **always one-knifes a single regular zombie**, every swing. The new direction (user): **PaP scales SWING
SPEED**, not targets — **+100% / +200% / +300%** swing rate at tiers 1/2/3 (`fireTime ×0.5 / ×0.33 / ×0.25`).
Code: deleted `actionfigure_cleave` + `actionfigure_cleave_count` (and the `acc_af_cleave_radius` dvar) from
[`_acc_damage.gsc`](scripts/zm/zm_abandoned_cyber_city/_acc_damage.gsc); the one-knife gate now uses a
`is_action_figure_weapon()` helper (covers the base figure, its off-hand sibling, and the coming `_fast1/2/3` speed
twins). **Speed twins are WIP** (they require cloned weapon GDTs — an external-asset build that gambles our last ~6
twin slots vs the ~230 boot cap), so for **feel-testing right now the base figure is set to the max test speed**
(`fireTime 0.2125` = 4× / +300%) — swing it cleave-free to judge whether faster `fireTime` reads as a faster knife
on this port before the per-tier twins are built. Dev now starts you with the Action Figure (was a packed Chicom) and
dev mode is hardcoded ON. GSC + figure-GDT only.

### Fixed — EE jukebox: swapped the two edge bears' titles (user, 2026-06-27)

The LEFT and RIGHT teddy-bear "NOW PLAYING" banners were on the wrong songs. Swapped the two title strings in
[_acc_ee_song.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_ee_song.gsc) `init`: LEFT (`acc_ee_song_2`) now
shows **"Night Groove"**, RIGHT (`acc_ee_song_3`) now shows **"I Want To Stay At Your House"** (center
unchanged — "Cyber Dreams"). Audio aliases are untouched; only the displayed titles moved. Docs/46 synced.
GSC-only build.

### Added — Regular zombies can drop items / Mega Bottles (0.4% each) (user, 2026-06-27)

- Every **regular (non-boss) zombie death** now independently rolls two small drops in a new zombie death-event
  callback [`_acc_boss_items.gsc::on_zombie_death_drop`](scripts/zm/zm_abandoned_cyber_city/_acc_boss_items.gsc):
  - **0.4%** → a random pool **item** drops at the corpse as a **free-for-all** world pickup (same pickup/grab/
    duplicate handling as a boss item).
  - **0.4%** → ONE Empty **Mega Bottle** granted **directly to the killer only** (not a shared/world drop), via
    `acc_mega_bottles::grant_bottle`.
- **Bosses + mini-bosses are excluded** (they keep their own guaranteed drops via `on_boss_death`), so a boss kill
  never double-dips. Elites + the regular horde are eligible.
- Both rates are **live dvars** (no rebuild): `acc_zombie_item_drop_chance` / `acc_zombie_bottle_drop_chance`
  (defaults `0.004` = 0.4%). Raise to make drops more common. Doc: [docs/12](docs/12_boss_items.md).

### Fixed — LED bake crash from DEEP prop clips (fullbright `.ff`) (user, 2026-06-27)

**Bug:** the full build's **Radiant LED bake CRASHED** (`exit 0xC0000005` / `brush.cpp:1860`), leaving a
**stale lightmap on a fresh BSP = fullbright** — the gate-failing state the LED bake exists to catch. Root
cause: **7 deep worldspawn `clip` brushes** that had accumulated in [tools/add_prop_clips.js](tools/add_prop_clips.js)
for abyss/Paradise props (`ammo_crate`, `overclock_terminal` at `z=-480`; `glitch_altar_l3` at `z=-720`;
`paradise_altar`/`_overclock`/`_exo`/`_perk_vendor` at `z=-1200`). Every other prop clip is **shallow**
(`z[-240,-160]`, the trench floor) and bakes clean; a deep world-brush `clip` **inside the enclosed,
sealed abyss layers** is the known lightmapper killer (memory `led-relight-dead-end-enclosed-geometry`).

**Fix:** `add_prop_clips.js` now **skips any clip whose bottom is below the `-240` floor** at emit time
(robust against the entries being re-added — the skip is in the emit loop, not the data), with a console
warning pointing to the real fix. The `.map` was regenerated (12 shallow clips kept, 7 deep skipped) and a
**full build with LED bake now passes**: `.led` (14:25:55, 70.4 MB) newer than `.d3dbsp` (14:25:33),
no crash, `.ff` 46.07 MB.

**Trade-off / follow-up:** the 7 deep props are **walk-through** until their collision is re-authored as a
**`script_brushmodel`** (LED-**exempt**) + a GSC `solid()` pass — the exact pattern the mystery-box clips use
(`acc_box_clip_*` + `_acc_map_randomizer::solidify_all_box_clips`, which notes *"script_brushmodel clips are
solid by author-default"*). A `script_brushmodel` can't be a pure-tool fix (worldspawn-brush emitter), so the
deep-floor collision is flagged for the agent who owns the abyss/Paradise props. Build: full cod2map+LED+linker.

**Verification + cleanup (same pass):** a 13-agent audit cross-checked every clip against its **live** GSC spawn
origin (decoding the actual `.map` brush planes) — all 12 props **ALIGNED**, no drift (the stale `(230,1450)`
header comment was just text; code uses `(-120,1550)`), `.map` braces balanced, 5 shallow present / 7 deep absent.
Two small fixes fell out: (1) the tool's summary log printed `PROPS.length` (`"12 … injected"`) when only 5 are
actually injected — now prints the true count (`"5 of 12 … 7 deep skipped"`). (2) **`exo_station` clip extents
swapped `hx30/hy18` → `hx18/hy30`**: that work table spawns at yaw 90, so its ~60-long axis runs along Y; the old
footprint was the un-rotated one (90° off, poked out the long sides). The yaw-0 Paradise twin keeps `30/18`.
Re-baked clean. (Flip back if the table reads wrong in-game — the model's native facing is the one unknown.)

### Fixed — Boss HP now compounds with the round (Brutus + Phantom died too easy late) (user, 2026-06-27)

**Bug:** late-game bosses melted because their HP didn't keep up with the zombie curve. Zombies compound
**×1.1/round** (from round 10); the **Phantom didn't scale at all** (flat `ACC_PHANTOM_HP` × coop, same HP
at round 10 and 40), and **Brutus** only grew **+6%/round simple** — so their lead over trash collapsed
(by round 50 the Phantom was barely tougher than one zombie).

**Fix:** both bosses now **compound per round** at a tamer exponent than zombies, pegged to their tuned debut
HP so early game is unchanged:
- **Brutus** ([_acc_boss.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_boss.gsc) `scale_mini_boss_hp`):
  `48,000 × 1.08^(round−5)` → solo r10 **70.5k** / r20 **152k** / r30 **329k** / r40 **710k**.
- **Phantom** ([_acc_boss_phantom.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_boss_phantom.gsc) new
  `scale_phantom_hp`): `56,000 × 1.06^(round−10)` → solo r10 **56k** / r20 **100k** / r30 **180k** / r40 **322k**.
- Brutus uses the **higher exponent (1.08 vs 1.06)** so it's always tankier than the Phantom and the gap
  widens each round (r10 +26% → r40 +121%), per user intent. The logarithmic co-op multiplier
  (`boss_hp_player_mult`: 1p ×1.0 / 2p ×1.5 / 3p ×1.79 / 4p ×2.0) still applies on top, unchanged.

New live dvars: `acc_boss_mini_hp_exp` (replaced `acc_boss_mini_hp_round_pct`), `acc_phantom_hp` /
`acc_phantom_hp_exp` / `acc_phantom_hp_anchor`. GSC has no `pow` builtin, so each uses a small
integer-exponent loop (same as stock `ai_calculate_health`). The 10%-of-maxHP per-hit boss cap still applies.
Docs synced: docs/11, docs/34. GSC-only build.

### Changed — Reactor Surge reward: Insta-Kill → Fire Sale (user, 2026-06-27)

The shared power-up dropped on a successful Reactor Surge is now a **Fire Sale** instead of an Insta-Kill (the +5 Data
Shards per player is unchanged). One-line functional swap in
[`_acc_reactor.gsc`](scripts/zm/zm_abandoned_cyber_city/_acc_reactor.gsc) `reactor_succeed` —
`specific_powerup_drop("insta_kill", …)` → `("fire_sale", …)` (`fire_sale` is a registered stock power-up, the entry
script already `#using`s `_zm_powerup_fire_sale`; no new import). UI updated to match: the plinth **hint** ("…+ Fire
Sale") and the **REACTOR STABILIZED** success message. Docs synced: 34 (`acc_reactor_reward`), 46 (trench guide), 57
(player guide ×2). GSC-only.

### Fixed — Roster shard count showed floored-to-10 (looked like a shard drain) (user, 2026-06-27)

The squad-roster shard readout floored to the nearest 10 (`shards - shards % 10`) — so 13 showed "10", 19
showed "10", and it jumped to "20" at 20, dropping the ones digit. A Glitch-Altar "Double Points" win made it
look like the altar drained shards, but shards were never touched (the altar correctly charges 2/spin). The
floor was a string-cache hack (exact shards × EXO in one SetText = ~5,500 unique strings > the 2048 cap). **Fix**
([_acc_health_bars.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_health_bars.gsc)): show shards **exact** and move
EXO (and MB) to the perks line, so the shard string is just `"Sh N"` (≤501 unique) — cache-safe, **no new
hudelem** (the roster pool is at its limit). GSC-only.

### Changed — God mode: damage = 0 but per-hit effects still fire (user, 2026-06-27)

God mode used `EnableInvulnerability`, which blocks the **entire** player-damage event — so the EMP debuff,
trench melee scaling, and Phantom interactions never ran while godded. Reworked: removed the `acc_god_watch`
invuln loop; god is now enforced in [_acc_elites.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_elites.gsc)
`on_player_damaged`, which **returns 0 damage** after the per-hit effects have already fired. Zombie melee, boss
hits, and `DoDamage` all route through that callback, so it stays death-proof, while the Phantom chain slow and
melee effects now apply. Normal play (`acc_god` off) is unchanged. GSC-only.

### Added — Trench ammo crate (abyss L2, opposite the Overclock terminal) (user, 2026-06-27)

A buyable ammo refill in the trench Lv2 room. The Cyberware Overclock terminal sits **west** at `(-400,1948,-480)`;
the new **ammo crate sits east** at `(400,1948,-480)`, mirrored across the central stairwell (right where the L1 stairs
land). Walk up, hold `[activate]`, and your **held** weapon's reserve is topped off (personal Max Ammo). **Pricing by
PaP state** (user): **1000** for a base gun, **5000** if it's Pack-a-Punched. A weapon with **no PaP version**
(melee / equipment / no-pack specials) **can't be serviced** — the crate says so and charges nothing. Detection uses the
same gates as the rest of the PaP pipeline: stock `zm_weapons::is_weapon_upgraded` for "is it PaP'd", and
`level.zombie_weapons[base].upgrade` for "does it have a PaP version" (the `_acc_weapon_variants` test). Refill =
`GiveMaxAmmo` (reserve; magazine tops off on reload, like the stock Max Ammo powerup). New module
[`_acc_ammo_crate.gsc`](scripts/zm/zm_abandoned_cyber_city/_acc_ammo_crate.gsc) (script-spawned model +
`trigger_radius_use`, mirroring `acc_overclocks::spawn_terminal_at`), spawned by `_acc_glitch_altar::spawn_altars`.
Live dvars `acc_ammo_crate_base` / `acc_ammo_crate_pap`. Uses the **same model `p7_cai_stacking_cargo_crate` as the
underground Data Cache shards crate**, and is **solid** with the **same 56×56×48 clip** (user: "same model clip as the
shards crate") — added via `tools/add_prop_clips.js`, which gained a per-prop `bot` (z-base) override so the clip sits on
the **deep L2 floor (z=-480)** rather than the hardcoded z=-240 pit. The **Overclock terminal opposite it was also
re-clipped** (user follow-up: "the overclock kiosk should have a clip too") — it had been a walk-through orphan since it
moved off the z=-240 Foundry floor (its old clip was stripped to avoid an invisible wall); re-homed to L2 with the same
60×68×80 `ticket_kiosk_theatre` dims via the new `bot`. Then the **last walk-through interactables were clipped too**
(user follow-up: "add clips to those") — the **L3 Glitch Altar** (z=-720) and the **four Paradise kiosks** (Altar /
Overclock / Exo / perk vendor, z=-1200), each reusing its model's snug dims (ticket-kiosk 60×68×80, work-table 60×36×80,
sign-kiosk 48×18×64 thin slab; the sign kiosks spawn yaw 0 → thin in Y, matching the reactor/perk-vendor clips; floating
core orbs stay decorative/no-clip). 12 prop clips total now. **Full build with LED bake passed every time** (`.led`
recomputed fresh, between BSP and `.ff`; no `brush.cpp:1860`). Docs: 48, 34. ⚠ L2..L5 bake pitch-black, so like the
Overclock kiosk the crate doesn't self-glow — if it's hard to find in-game we'd add a bake-gated light.

### Changed — Room-name banner back to DEV-ONLY + two safe audit hardening fixes (user, 2026-06-27)

- **Top-center area-name banner reverted to dev-only** (user: "all 6 clips UI showing in non dev mode … shows
  right when you spawn in"). `dev_player_hud_loop` (the PLAZA / MARKET / LAB / … room title at top-center) was
  threaded ABOVE the dev gate so it showed for every player in normal play; it read as leftover dev/log clutter.
  Moved the thread BELOW the `if (!IS_TRUE(level.acc_dev)) return;` gate in
  [`_acc_dev.gsc`](scripts/zm/zm_abandoned_cyber_city/_acc_dev.gsc) `init()`, so normal play shows no top-center
  banner; dev still shows it. The always-on crosshair damage-number feed (line 53) is unaffected. To re-ship the
  room banner to all players, move the thread back above the gate.
- **`spawn_elite` init-wait cap (F20).** Added the `n < 100` iteration cap + post-loop bail that the four sibling
  spawn-init loops already use (`_acc_boss_glitch`/`_acc_reactor`/`_acc_paradise`/`_acc_boss_phantom`), so a
  culled/never-init elite spawn can't tie up the spawn thread for the rest of a round.
  [`_acc_elites.gsc`](scripts/zm/zm_abandoned_cyber_city/_acc_elites.gsc). (Already bounded by
  `endon("acc_round_end")`; this just bails cleanly. Established pattern, no behavior change in the normal case.)
- **Paradise `gather_stragglers` deterministic fan-out (F39).** Stragglers pulled into the finale were teleported
  onto a RANDOM ring angle, which could stack two players inside each other's capsule → engine ejection → a
  teammate punted OOB and killed by decontamination. Now collected first and fanned onto an evenly-spaced ring
  (`ang = i*360/n`), same dest + 48u radius. [`_acc_paradise.gsc`](scripts/zm/zm_abandoned_cyber_city/_acc_paradise.gsc).
  Matches the project's `coop-teleport-fan-out` rule.

### Fixed — 3rd EE song cost 15000 → 1500 (typo, user 2026-06-27)

The trench teddy-bear jukebox's 3rd song charged **15,000** points (an extra zero); intended **1,500**.
`ACC_EE_COST_3` 15000 → 1500 in [_acc_ee_song.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_ee_song.gsc)
(dvar `acc_ee_song_cost_3` default; no override elsewhere). Order-based jukebox price is now **500 / 1000 /
1500**. Synced the two in-file comments, docs/46, and memory `music-channel-and-jukebox`. GSC-only build.

### Fixed — Soul-box hint now matches the live cost (UI ↔ code alignment) (user, 2026-06-27)

The abyss soul-box floating hint ("[bank N souls]") could disagree with the actual bank requirement. `souls_needed(layer)`
scales by `GetPlayers().size` (first gate 125/player, deeper gates 50/player → deeper = **50 solo, 200 at 4p**), and the
**per-kill check evaluates it live**, but the **hint was set once at door creation** — so in co-op (or after a dis/connect)
the displayed goal could read e.g. 50 while the code actually required 200. Added `soul_hint_watcher` in
[`_acc_abyss_doors.gsc`](scripts/zm/zm_abandoned_cyber_city/_acc_abyss_doors.gsc) that re-runs `soul_update_hint` for the
open doors **only when the player count changes** — a tiny bounded set of strings (≤16), so it stays far under the
250-`triggerstring` cap that forced the original snapshot (never re-set per kill — that was the overflow). The values
themselves were already correct/as-designed; this just keeps the **UI showing exactly what the code requires**. GSC-only build.

### Fixed — Perk-twin ammo drift: handling perks silently changed clip/reserve (user, 2026-06-27)

**Bug (reported live):** getting a handling perk (Mega Deadshot=recoil, Gun Slinger=fast-fire, Speed
Cola=fast-reload) swaps the held gun to a perk-**twin**, and the twins carried the **wrong ammo** — usually
the pristine **uncut** clip/reserve, sometimes lower. E.g. Tac-19 jumped clip 3→6 / reserve 27→72; ASM1 clip
22→32; RW1 was badly broken (clip 8→**1**, reserve 7→**40**). **Root cause:** `apply_recoil_overhaul.js`
generates the twins from the **pristine** base GDT, but `reduce_base_ammo.js` (+ RW1 CLIP_FIX / Olympia
MAXAMMO_FIX) only cut the **install** base/`_up` blocks — never the twins in `acc_weapon_variants.gdt`.

**Audited all 32 twin forms** (`scratchpad` audit) → 10 guns drifted on ammo: Tac-19, ASM1, AE4, MK14,
Galil, MORS, Olympia, RW1, PPSH-41, Paladin (+ a residual Five-Seven `startAmmo`). New tool
[tools/fix_twin_ammo_drift.js](tools/fix_twin_ammo_drift.js) SETs every twin's `clipSize`/`maxAmmo`/`startAmmo`
to its canonical install form (231 fields across 147 twin blocks). Re-audit = **0 ammo drift** (only the
intentional Gun-Slinger fast-fire `fireTime` diffs remain). Damage was already consistent.

- GDT-only → `gdtdb /update` (done by the tool) + `-GscOnly` linker. Clean `.ff`.
- **PIPELINE FIX (prevents recurrence):** the canonical post-port order is now
  `apply_recoil_overhaul.js → reduce_base_ammo.js → fix_twin_ammo_drift.js → remove_ppsh_pap_optic.js →
  rebalance_pap_forms.js → gdtdb/build`. The first two reset base + regenerate twins, so the last three
  must always re-run after them (documented in each tool header + memory `pap-per-form-stat-tuning`).

### Changed — Workshop thumbnail = real gameplay screenshot (user, 2026-06-27)

Replaced the `zone/previewimage.png` placeholder (was 600×340) with a **512×512** thumbnail cropped from an
in-game screenshot (the perk-machine lineup + Chicom, HUD roster cropped out). Centered square crop →
HighQualityBicubic downscale via System.Drawing; written to the repo **and** the deployed
`usermaps\zm_abandoned_cyber_city\zone\previewimage.png` (the absolute path `workshop.json` already points at).
Satisfies docs/55 §B3 (512×512). No code/build change — publish picks it up via the Launcher (re-publishing
updates the same item, PublisherID 3751124295).

### Fixed — Co-op crash/lag-out audit: PaP/Overclock disconnect CTDs, PaP pre-power CTD, string-cache feeders (user, 2026-06-27)

Multi-agent crash audit (78 agents over all ~28.9k lines, every finding adversarially verified) targeting the
reported "almost every co-op session crashes or someone lags out." Applied the confirmed, reachable crash fixes
(the user-selected scope). GSC-only build OK, fresh 46 MB `.ff`.

- **Overclock terminal: disconnect-during-redraw CTD.** `terminal_loop` calls `player replay_pack_draw()`
  **inline** on the shared trigger thread (whose only `endon` is the TRIGGER's `"death"`), then reuses `player`
  on the next line. A disconnect/timeout during the multi-frame empty-handed redraw window made that a method
  call on a freed entity → fatal script error → whole-session CTD. Added an `isdefined(player)` re-validation
  after the redraw. [`_acc_overclocks.gsc`](scripts/zm/zm_abandoned_cyber_city/_acc_overclocks.gsc) (~L325).
- **Pack-a-Punch: same disconnect window (higher frequency than the terminal).** `acc_do_first_pack` /
  `acc_do_tier_up` run as `player thread` but lacked `self endon("disconnect")`, so a disconnect mid-pack
  resumed on a freed player (`minus_to_player_score` / `fill_full_ammo`) → CTD. Added `self endon("disconnect")`
  to both (player-threaded, so the endon only aborts that player's own pack).
  [`_acc_pap_levels.gsc`](scripts/zm/zm_abandoned_cyber_city/_acc_pap_levels.gsc).
- **Pack-a-Punch before power: undefined-cost CTD.** Stock sets the PaP trigger `.cost` only after
  `Pack_A_Punch_on`, but power ships OFF behind the manual dual-switch and everyone spawns with a packable
  tier-0 gun, so the price keeper compared `t.acc_saved_cost` (= undefined `t.cost`) `< ACC_PAP_STOCK_FIRST_COST`
  — a relational compare on undefined = fatal — the moment anyone walked within 130u of PaP pre-power. Guarded
  with `isdefined(t.acc_saved_cost)` (falls through to the per-gun first-pack price). `_acc_pap_levels.gsc` (~L233).
- **String-cache (2048 'string' BG-cache) feeders → gradual CTD in long games.** Two `SetText` paths embedded
  unbounded/high-cardinality numbers (each distinct string permanently burns a never-freed cache slot — the
  `Exceeded 2048 items for type string` class this map hit before): The Exchange deposit/withdraw toasts baked
  the ever-climbing `vault: <total>` into the text (dropped → bounded per-press amount only,
  [`_acc_transfer.gsc`](scripts/zm/zm_abandoned_cyber_city/_acc_transfer.gsc)); the co-op squad roster baked the
  live shard count `[0..500]` × EXO tier into 4 simultaneously-rendered rows (~5.5k possible strings) — floored
  the displayed shards to the nearest 10 (~561 strings) rather than adding a SetValue elem (the hudelem pool is
  already near-exhausted). [`_acc_health_bars.gsc`](scripts/zm/zm_abandoned_cyber_city/_acc_health_bars.gsc) (~L470).
- **Audit backlog (not yet applied, user-deferred):** dev+god mode is HARD-CODED on (masks the down/revive
  crash family + ship-unsafe); Reactor-surge actor-pool stall (round-freeze/lag-out, 6-actor headroom); Paradise
  `gather_stragglers` random-ring teleport stacking; and 5 latent FATALs in the disabled Avogadro module
  (gate before re-enabling). See the audit summary in conversation.

### Changed — Exchange Bank: 1000/10 deposit increments (clean 10% tax) + swarm removed (user, 2026-06-27)

- **Deposit increments → 1000 Points / 10 Shards** so the 10% tax is **exact**: `acc_vault_points_inc` 250→**1000**
  (tax = 100), `acc_vault_shards_inc` 25→**10** (tax = 1). No more whole-tens rounding wobble. Both deposit +
  withdraw use the same per-press chunk. [`_acc_transfer.gsc`](scripts/zm/zm_abandoned_cyber_city/_acc_transfer.gsc).
- **The vault swarm was REMOVED** (user: "just remove the spawns in the exchange room, they just cause issues").
  Deleted `vault_swarm_loop`/`vault_surge`/`count_vault_zombies`/`get_vault_risers` + the init thread from
  [`_acc_bus_trench.gsc`](scripts/zm/zm_abandoned_cyber_city/_acc_bus_trench.gsc). The bank is a safe-ish utility
  room again — the only zombies down there are the normal horde that follows you down. GSC-only build OK, 46 MB `.ff`.

### Changed — The Exchange Bank: gentle stairs, step-off landing, room name + a vault swarm (user, 2026-06-27)

Four in-game fixes after a playtest of The Exchange.

- **Gentler stairs (no more sliding).** The 16/16 (45°) stairwell made you slide; re-pitched to **10-rise / 16-run**
  (~32°, the trench's pitch) over 15 treads, drop reduced 240→**160** so the gentle run fits + leaves ~144u
  headroom. [`gen_plaza_basement.js`](tools/gen_plaza_basement.js) (`STEP_RISE`/`STEP_RUN`; vault `z=-160`).
- **Bottom now steps off into open floor (zombies can leave).** The stairs no longer dead-end at the west wall —
  the well stops ~100u short (x1=-620), leaving an open vault **LANDING** (x[-720,-620]) so the bottom tread
  steps off WEST into open floor (the abyss "never end at a wall" rule), with a lab-level west wall above it so
  nobody falls in from the lab. Door doorway moved to x=-380; GSC origin `(-380,-376,50)`; station heights → z=-160.
- **Room name "EXCHANGE BANK"** + **the room-name banner now SHIPS in normal play** (user 2026-06-27). The
  top-center area banner ([`_acc_dev.gsc`](scripts/zm/zm_abandoned_cyber_city/_acc_dev.gsc) `dev_player_hud_loop`)
  was gated behind `acc_dev` only because it used to share a loop with a removed dev damage panel. Moved the
  `level thread dev_player_hud_loop()` **above** the dev gate in `acc_dev::init` so **every player** sees room
  names (PLAZA / MARKET / LAB / … / **EXCHANGE BANK** / trench levels) on entry in normal play; only the "DEV MODE
  ACTIVE" confirmation stays dev-gated. Added the `player_in_vault` → `"exchange"` → "EXCHANGE BANK" case. (There
  is no *separate* shipped room-UI — the only other non-dev area text is the decon "EVACUATE" warning + "Welcome to PARADISE".)
- **It swarms now.** New `vault_swarm_loop`/`vault_surge`/`get_vault_risers` in
  [`_acc_bus_trench.gsc`](scripts/zm/zm_abandoned_cyber_city/_acc_bus_trench.gsc): while any player is in the vault,
  force-spawns zombies from 9 nav-snapped vault-floor risers (`riser_location`/`find_flesh` + `tag_trench_zombie`'s
  below-volume melee fix — the trench pit-eruption recipe, since the vault is below every player_volume + excluded
  from `underground_layer`). Not a wave system — a steady eruption up to a cap. Live dvars `acc_vault_swarm_on` (1),
  `_interval` (2.0), `_count` (5), `_cap` (28). **LED bake BAKED (23s); full build OK, fresh 46 MB `.ff`.** Needs
  walk-test: no slide, zombies disperse off the bottom, the bank actually swarms.

### Changed — Tier-2 (PaP) form rebalance: 6 guns retuned (user, 2026-06-27)

Per-gun **packed-form** rebalance using the Tier-2 transform as the lever — bad guns get a bigger T2 jump,
strong guns get reined in. All edits are on the weapon's own `_up` (or base) GDT stats, so they hit ONLY
the targeted form (the shared `acc_weapon_balance_mult` can't isolate a form). New re-runnable tool
[tools/rebalance_pap_forms.js](tools/rebalance_pap_forms.js) applies them to the install base/`_up` blocks
**and** all 7 perk-twin blocks per gun (so the change holds with/without Deadshot/Gun Slinger/Speed Cola),
then deploys the twin GDT + runs `gdtdb /update`. Verified live via `dump`/`distinct` GDT reads.

| Gun | Form | Change |
|---|---|---|
| **RPD** | `_up` | **+20% damage** 390→468 (min 375→450) + **~15% fire rate** (fireTime 0.08→0.0696 / fast-fire twin 0.0552→0.048; RPM 750→862, 1087→1250). "Bad gun → strong once packed." |
| **Tac-19** | `_up` | **−20% damage** (per-pellet 217→174); pellets/clip/reserve unchanged |
| **Five-Seven** | `_up` | **+30% damage** 350→455 (min 320→416); **+30% clip & reserve** (21→27 / 147→189) |
| **Five-Seven** | base | **+30% clip & reserve** (14→18 / 56→72) — also buffs the starting pistol + Lab wall-buy |
| **MORS** | `_up` | damage **2000→1500** (min 1000→750, keeps 50% falloff ratio) |
| **AK-74u** | `_up` | **+20% damage** 260→312 (min 250→300) |
| **Chicom CQB** | `_up` | **−20% reserve** (maxAmmo 8→6 ⇒ 448→336; closest whole-magazine to −20%, user-chosen over 392/−12.5%) |

- **PaP prices + mystery-box rarity deliberately UNCHANGED** (user choice): `compute_gun_tiers.js` was NOT
  re-run, so `pap_price_bucket`/`acc_box_weight` stay exactly as-is (RPD stays cheap **3k/4.5k/6k** + common
  **~10.6%** but is now S-tier once packed; Tac-19 stays TOP-price + rare but 20% softer). The `GUNS` table in
  `compute_gun_tiers.js` is now intentionally **stale on power** for these 6 — do not regenerate docs/54 unless
  you mean to re-rank the economy.
- **Incidentally fixed:** Five-Seven's perk-twins had **uncut ammo** (clip 30/20 vs the base form's 21/14) —
  now uniform at the new 27/18. The same pre-existing twin ammo-drift still exists on **Tac-19** (twin clip 10
  vs base 6) and **MORS** (twin reserve 90 vs base 72) in fields this pass didn't touch — flagged for a future
  cleanup, not changed here.
- GDT-only → `gdtdb /update` (done by the tool) + `-GscOnly` linker. No geometry/LED. Clean `.ff`. **RE-RUN
  `rebalance_pap_forms.js` after `apply_recoil_overhaul.js` / `reduce_base_ammo.js`** (they reset the base GDT +
  regenerate twins, reverting this), same as the optic/ammo tools.

### Fixed — Zombies wouldn't path to the player + duplicate-Exchange-door crash (user, 2026-06-27)

Two bugs surfaced after the 08:02 plaza-shrink/Exchange `.map` rewrite. **(1) Duplicate Exchange door
crash:** the `.map` shipped the `enter_exchange` door DUPLICATED — two `zombie_door` trigger_use + two
`acc_door_exchange` slabs (identical GUID, a `gen_plaza_basement` copy-paste). `zone_door_buy_loop`'s
`GetEnt("acc_door_exchange")` FATAL'd ("getent used with more than one entity", confirmed in
`console_mp.log`) and killed the door thread. Added `acc_dedupe_exchange_door()`
([zm_abandoned_cyber_city.gsc](scripts/zm/zm_abandoned_cyber_city.gsc), runs first in `main()` next to the PaP
dedupe) — renames surplus slabs off the GetEnt key and disables surplus triggers, self-heals every load.
**(2) Zombies stood still / wouldn't target the player:** the navmesh deployed at 08:03 (built right after the
geometry edit) was **bad** — zombies acquired the player as enemy (`e=1 fav=1`) but had **no path** to them, so
they froze ~220u away; opening the implant→Exchange doors gave the navmesh its only working bridge. Root cause:
that build regenerated a botched `_navmesh.hkt`, and subsequent `-GscOnly` builds **reuse** the navmesh so they
couldn't fix it. A clean **full** `build_map.ps1` (cod2map64 with cwd=`bin` → fresh BSP + navmesh + LED bake)
regenerated a correct navmesh and zombies path normally again. Diagnosed with a temporary dev `[targdbg]`
readout (player + nearest-zombie coords to `console_mp.log`), since removed. Ruled out (multi-agent + log):
god mode, Cyberware Ghost Protocol (kiosk gated off by `acc_cyberware_on`, unreachable in dev), and all
this-session script changes — none touch targeting. GSC + full geometry build.

### Fixed — The Exchange v2: enclosed staircase + enlarged lab + the dead door (user, 2026-06-27)

The first Exchange was broken on two counts the user hit in-game: "a big square block in the middle of
the room" and "I can open a door but it doesn't do anything." Both fixed.

- **Root-cause: the door was dead from a generator bug.** [`gen_plaza_basement.js`](tools/gen_plaza_basement.js)
  emitted the buyable-door entities **top-level**, but its old `strip()` only removed single-level **leaf**
  brushes — so re-running it (which I did, twice) left the door **entities duplicated** and stripped their
  inner brush, leaving an **empty shell**. `acc_dedupe_exchange_door` then kept the empty shell as the live
  `acc_door_exchange`, so buying hid a brushless phantom (a no-op) while the real slab stayed **solid
  forever**. `strip()` v2 now removes **every** block carrying this generator's `7A2BAE0` GUID — leaf world
  brushes inside worldspawn, top-level door/light entities, **and** orphaned shells — keeping worldspawn and
  re-emitting exactly **one** trigger + **one** slab (verified: 1 / 1, no `_dupe`). The de-dupe is now a no-op.
- **Redesign: enclosed staircase, not a railed pit.** The "big block" was the well's 128u opaque railing
  ring around an open pit dropped into a 360×300 room. v2 **enlarges the Implant Lab WEST** to x[-720,-40]
  ([`gen_plaza_shrink.js`](tools/gen_plaza_shrink.js): west wall -400→-720, north wall extended; benches +
  doorway unchanged, self-check clean) and rebuilds the descent as an **enclosed staircase room** in the new
  SW corner: the stairwell well (now x[-720,-496], flush against the west wall) is wrapped in **full-height
  (z[0,256]) N/S walls + a doorway on the EAST face** so it reads as a basement stairwell. The vault extends
  west (x[-720,300]) to meet the stair bottom; stations unchanged. Door origin → `(-496,-376,50)`; OOB
  `origin_in_vault` box widened to x[-740,320]. **LED bake: BAKED (17.8s); full build OK, fresh 46 MB `.ff`.**
- **NEEDS WALK-TEST**: buy the door, confirm the slab vanishes and you descend; benches reachable in the
  bigger room; zombies path the stairs.

### Changed — PaP PPSH-41 no longer has the MK8 reflex sight (user, 2026-06-27)

The Pack-a-Punch PPSH ("The Pale Rider") shipped an **mk8 reflector reflex sight** baked into the Skye
Vanguard port's `_up` GDT — 9 fields: the reflex view/world models (`vm_s4_reflex_mk8_reflector_*` /
`wm_s4_reflex_mk8_reflector`), their `tag_reflex` mount tags, the reflector ADS anims
(`am_s4_ppsh41_mk8reflector_ads_*`), and a `hideTags "tag_irons_hide…"` that hid the irons. New tool
[tools/remove_ppsh_pap_optic.js](tools/remove_ppsh_pap_optic.js) reverts **exactly those 9 fields** to the
base gun's values (no optic, iron-sight ADS restored) on **every** PPSH `_up` form — the install base
`s4_ppsh41_base_up` **and** all 7 perk-twin `_up` blocks in `source_data/acc_weapon_variants.gdt` (so the
sight is gone with *and* without Deadshot/Gun Slinger/Speed Cola). Every other PaP upgrade is untouched
(clip 54, damage 280, special stock, drum mag, upgraded muzzle FX, "The Pale Rider" name).

- **Re-runnable + idempotent**, deploys the twin GDT to install `source_data`, and runs `gdtdb /update`
  itself. **RE-RUN after `apply_recoil_overhaul.js`** — that tool restores the pristine base GDT + regenerates
  twins, both of which re-add the sight (same footgun as `reduce_base_ammo.js`).
- GDT-only change → `gdtdb /update` (done by the tool) + `-GscOnly` linker repack. No geometry, no LED bake.
  Fresh `.ff` written. Memory: `pap-ppsh-reflex-optic-removal`. Recipe added to docs/33.

### Fixed — Deep audit: all 7 confirmed co-op bugs (user, 2026-06-27)

A 10-cluster adversarial code/doc audit (52 modules, 22 agents) surfaced 7 confirmed bugs (5 plausible findings
were refuted as unreachable). **All 7 are now fixed** — the 4 clean ones first, then the 3 balance/scope ones:

- **Glitch Purge HUD hudelem leak (high)** — `hud::createBar` allocates 3 hudelems (bar, **frame**, bg) but
  `_acc_lockdown_challenge::destroy_challenge_hud` only freed `.bar` + the handle, leaking the **`barFrame`** per
  inside-player **per purge**, permanently starving the shared co-op HUD pool (the documented ~96-elem ceiling).
  **Fix:** the purge bar is now a single `hud::createIcon("white",…)` width-scaled by progress (the squad-roster
  idiom) — 1 hudelem instead of 3, and no `barFrame` to leak. Also freed the same leaked `barFrame` in
  [_acc_health_bars.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_health_bars.gsc) `make_player_bar` (rare rebuild path).
- **Trench Warden permanently suppressed (high/softlock)** — `_acc_boss.gsc::run_mini_boss` carried
  `level endon("acc_round_end")` and set `level.acc_brutus_active = true` before the spawn telegraph; a fast co-op
  round ending mid-telegraph tore the thread down before the flag was cleared / death-watch attached → Brutus
  **never respawned all match**. **Fix:** dropped the round-scoped endon (Brutus roams across rounds via
  `ignore_enemy_count`), so the cleanup + death-watch always run.
- **Paradise gate could open for free (economy)** — `_acc_abyss_doors.gsc::hub_door_loop` debited the shared
  Points pool by `give_p` unconditionally, but stock `minus_to_player_score` charges nothing under **Shopping
  Free Gobblegum** / `intermission`. **Fix:** debit the pool by the **actual** `score` delta (mirrors the shards
  branch). Now you can't drain the communal gate cost without spending.
- **Paradise Phantom reward farm (balance)** — `_acc_boss_phantom::phantom_death_watch` granted the full
  guaranteed reward set (item + Mega Bottle + shards to every player) on **every** kill, ungated — so the
  survive-don't-farm finale (up to 4 Phantoms cycling) became a loot piñata. **Fix:** the reward block is now
  gated on `!level.acc_paradise_onslaught` (the corpse-cleanup + host-clear still always run), mirroring the
  reward-free Paradise Brutus path and `block_powerup_drop`.
- **Boss-item drop denied to teammates (co-op)** — `_acc_boss_items::on_boss_death` converted the roll to shards
  and `return`ed when the **killer** already owned the item, spawning **no** pickup — so a teammate who lacked it
  got nothing. **Fix:** always `spawn_pickup` (like `grant_challenge_reward`); `watch_pickup`'s per-grabber dedupe
  still converts the killer's own duplicate to shards if they grab it.
- **Late-join boss bar (cosmetic)** — `_acc_health_bars::boss_bar_track` snapshotted the player set once at boss
  spawn, so a mid-fight joiner never saw the bar. **Fix:** reconcile against `GetPlayers()` each tick and lazily
  add a set for any untracked player (dedup by `s.player`, so existing players are never re-created = no HUD spam).

GSC-only; lint-clean; build OK.

### Changed — Final boss battle (Paradise Onslaught) → 3:45 with a 45s final wave (user, 2026-06-27)

The PHASE 4 survival fight is now **3:45** (was 4:00): `ACC_PARADISE_SURVIVE_SEC_DEF` 240 → **225**
([_acc_paradise.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_paradise.gsc)). The 60s escalation is
unchanged, so the horde steps **L2 (0–60) → L3 (60–120) → L4 (120–180) → L5 (180–225)** — making the
**final L5 wave exactly 45s** (3:00 → 3:45), while the first three waves stay 60s each. The escalation +
survival timer are both purely time-driven (no hardcoded tick count), so only the one constant moved.
In-game banner "SURVIVE 4 MINUTES!" → "SURVIVE 3:45!"; header + docs/48 phase table synced. GSC-only
(`-GscOnly` linker build).

### Fixed — Reactor Surge plinth pushed off the center teddy bear (user, 2026-06-27)

The Reactor Surge arm plinth in the teddy-bear north under-room was still sitting on the center bear. Moved
it back to the rear wall: `y` **2465 → 2473** in both the spawn ([_acc_reactor.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_reactor.gsc) `spawn_plinth_at`) and its collision clip ([add_prop_clips.js](tools/add_prop_clips.js) `reactor_plinth`, re-run). The clip is 48 deep (±24), so 2473 puts its north edge on the 2497 wall and its south edge at 2449 — ~9u clear of the center bear (y=2430). Geometry change → full build + LED bake (passed: fresh BSP/navmesh/lightmap, no crash).

### Removed — Gold Pack-a-Punch camo is no longer a feature (user, 2026-06-27)

Stripped the runtime **gold PaP camo** that every pack applied on top of the held gun. It was a stock
BO3 camo *option* (`zm_weapons::get_pack_a_punch_camo_index` → `CalcWeaponOptions(camo,0,0)`) layered on
at pack time; the PaP **tier** (damage) and the **`_up` transform** are untouched — only the gold skin is
gone. Tier 1 is now a pure **damage** pack with no visual change (the in-hand "gun comes out" draw still
plays); T2 still swaps to the `_up` form, just given **without** the camo option.

- [_acc_pap_levels.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_pap_levels.gsc): deleted `apply_pap_camo()`;
  removed the `CalcWeaponOptions` camo from `acc_do_transform`, `replay_pack_draw` (both the held-gun re-give
  and the restore loop now `GiveWeapon` with no options), and the tier-1 first-pack path; `tier_benefit(1)`
  now reads `"more damage."` (was `"more damage + camo."`).
- [_acc_weapon_variants.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_weapon_variants.gsc): the perk-twin
  `swap_weapon` no longer re-gives a camo option to preserve it across a Deadshot/Gun Slinger/Speed Cola swap
  — plain `GiveWeapon( w_to )`. The PaP tier still rides `player.acc_pap_tier[ true_base ]`, asset-independent.
- [_acc_overclocks.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_overclocks.gsc): comment fix only.
- [acc_hud.lua](ui/uieditor/menus/hud/acc_hud.lua): `pap_tier_benefit(1)` → `"more damage"`.
- Docs: [05_weapons.md](docs/05_weapons.md), [27_ui_plan.md](docs/27_ui_plan.md),
  [50_vague_ui_language.md](docs/50_vague_ui_language.md), [24_test_session.md](docs/24_test_session.md).

**Note (not yet done):** the ported Skye `_up` weapon forms carry their own `"camo" "skye_up_camo"` baked
into their GDT (in `acc_weapon_variants.gdt` for our twins, and in the external/gitignored Skye GDTs for the
real box guns), so those packed guns may still show an upgraded skin independent of this runtime removal.
Stripping that is a separate GDT change + full asset rebuild — pending a user call. `-GscOnly` build.

### Fixed — Removed the stray "big teal box" in dev mode (user, 2026-06-27)

A large cyan square floated in the Lab in dev mode and read as "a teal box on the zombies." Root cause: the
dev buyable-door waypoints (`_acc_dev::create_door_marker`, a cyan `SetShader("white",14,14)` +
`SetWaypoint` HUD square) target the `zombie_door` brush entities, which report origin `(0,0,0)` (no origin
brush — the known map-brush-origin quirk). So every door marker stacked at the map center and rendered as one
big cyan square hovering in open space near the horde — NOT actually on any zombie (it's a flat 2D HUD shader,
not a model). Fix: stopped threading `dev_door_markers()` in [_acc_dev.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_dev.gsc)
— the door-finder was redundant in dev anyway (`acc_open_map` already opens every door). The red zombie
wallhack markers are untouched. `create_door_marker`/`dev_door_markers` stay in the file as the referenced
HUD-waypoint recipe but are no longer invoked. Also retired the related dev door-debug **on-screen text**
([zm_abandoned_cyber_city.gsc](scripts/zm/zm_abandoned_cyber_city.gsc)): the periodic `[doordbg]` readout
(`zone_door_debug`) is no longer threaded, and the one-time `[accdoor]` lines (`acc_door_dbg`) now route to
`acc_utility::log` instead of `IPrintLnBold` — so the door debug info is kept in the log but off the screen.
GSC-only — `-GscOnly` build.

### Changed — Squad roster restacked + round counter to one line (user, 2026-06-27)

Follow-up layout pass on the co-op squad roster ([_acc_health_bars.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_health_bars.gsc),
same file as the 2026-06-26 `BG_Cache 2048` fix). Each player is now a **2-line block** — LINE 1 = name + health
bar (the bars form a fixed column at x=150, right of the names), LINE 2 = the stats — with a gap between players,
stacked bottom-up (you at the bottom). Previously the stats were crammed onto the same line as the bar. **Mega
Bottles dropped from the roster** (still shown on its own top HUD element); the stats line is now
`Sh {shards}   EXO {e}   $<points>`. The crash-safety is unchanged: `points` (the only unbounded field) stays a
right-flushed `SetValue` number (zero `string`-cache cost), shards/EXO stay bounded `SetText` — so this **cannot**
reintroduce the `Exceeded '2048' items for type 'string'` CTD. Still 4 hudelems/row (16 in 4-player).

Also: the **top-left round counter** is now `"Round N"` on **one line, inset from the corner** (`x=40,y=30`,
scale 1.6), replacing the stacked `"ROUND"` label over a big number jammed in the corner. It's one `SetText`
element — safe because the round number is **bounded** (≤~255 distinct, change-guarded), unlike the unbounded
score. Pure GSC — linker (`-GscOnly`) build. Docs: [49_hud_modernization.md](docs/49_hud_modernization.md).
Memory: `string-cache-setvalue-not-settext`.

**HUD polish pass (same day):** roster shifted **up** so it clears the perks rail (`base` 50→90) and the
health-bar column pulled **left** to sit close to the names (bar `x` 150→92, was a huge gap). On the bottom-right
combat card ([acc_hud.lua](ui/uieditor/menus/hud/acc_hud.lua)): the **gun-name** text dropped 0.78→0.58
("1.5×, not 2×"), and the **grenade/equipment row** moved down to sit flush above the card (`BOTTOM` 168→144,
killing a 26-unit dead gap). Pure cosmetic offsets/scales — `-GscOnly` (GSC + LUI rawfile) build.

**HUD polish pass 2 (same day):** roster row is now a **3-line block** — name / health bar / stats — with the
**bar on its own line at `x=12`** (so it shares the left column with name + stats; this *removes the name-width
guessing* the 2-line layout needed). On the combat card, the **gun name and ammo were pulled right toward the
card's border** to kill the dead space on their right (`NameTxt` right pad 14→6; the mag+reserve shifted ~38
right — reserve's left edge held at `-72` so a 4-digit `/ 9999` still fits without clipping at the border). Pure
cosmetic offsets — `-GscOnly` build. (A transient "UNRECOVERABLE ERROR" the wrapper flagged during one build was
a file-lock false alarm — a clean re-link confirmed no Lua/asset error; the t9 shell-eject FX warnings are
pre-existing Cold-War-gun asset noise.)

**HUD polish pass 3 + per-player perks (same day):** roster row is now a **4-line block** — name / health bar /
stats / **perks** — with the stats line **left-aligned at `x=12`** (was right-aligned/indented) and the
inter-player gap made bigger than the within-block line spacing so each player's lines read as one group. The new
**LINE 4 shows each player's owned perks** as colour-coded abbreviations: **`^1` red = base, `^5` teal = mega**
(`JUG QR SPD DT STM MULE DEAD WW PHD EC`). Reads `HasPerk` + the `q.acc_mega_perks` field directly (no
cross-module `#using`); the perk set is **bounded + change-guarded**, so `SetText` is BG-cache-safe. The Ronan
perk *icons* can't be reused here — they're LUI `image,` assets and a server hudelem needs a material this usermap
can't build (memory `hud-custom-image-lui-not-material`), so abbreviations are the server-side path. Costs **+1
hudelem/row (5/row, 20 in 4-player)** — fine solo, but approaching the co-op pool ceiling (would slim by
rendering the perk line only when a player has perks, if 4-player UI ever vanishes). Dev mocks show a red/teal mix
(one mock = all 10 perks) to exercise the layout. Pure GSC — `-GscOnly` build.

### Added — "The Exchange": a player-to-player transfer vault under the Plaza (user, 2026-06-27)

A new room where players **transfer resources to each other** — Points, Data Shards, Mega Bottles, and
Boss Items. Reached by a **stairwell carved DOWN from the Implant Lab** into an enclosed vault at **z=-240
directly under the spawn Plaza**, gated by a buyable slide-up door (`enter_exchange`, 1500 pts). Full design:
[docs/58_transfer_vault.md](docs/58_transfer_vault.md).

- **Model = SHARED TEAM VAULT** (user's choice over directed-give / two-pad): deposit into a level-side team
  pool, **any teammate withdraws** — no player-targeting (sidesteps the `closest_player_override` co-op
  hazards). Co-op redistribution of the strictly per-player economy (docs/15); a personal stash in solo.
- **Module** [`_acc_transfer.gsc`](scripts/zm/zm_abandoned_cyber_city/_acc_transfer.gsc) (new, orchestrated
  by `_acc_main` after data_shards/mega_bottles/boss_items; `scriptparsetree` added to the `.zone`). Four
  script-spawned terminals (no LED-bake cost), each with a **DEPOSIT** + **WITHDRAW** pad (one trigger per
  action — the Implant-Bench multi-pad idiom). Each press moves one fixed increment (`acc_vault_points_inc`
  250 / `acc_vault_shards_inc` 25 / 1 bottle / 1 item; locker caps at `acc_vault_items_max` 8). **A 10%
  deposit tax** (`acc_vault_tax_pct`, user 2026-06-27) applies to **Points + Data Shards** only — the pool
  receives ~90% of a deposit (the cut is destroyed); **Bottles + Items are untaxed** — so a team can't
  trivially funnel the whole economy onto one player. Currency
  uses the documented APIs (`zm_score::minus_/add_to_player_score` — never writes `player.score`;
  `acc_data_shards::try_spend`/`grant_player(…,"transfer")` so withdraw deducts by what actually landed under
  the cap; `try_consume_bottle`/`grant_bottle`). Boss-item deposit can **un-implant** a slot (runs
  `on_unequip` → buff off, speed recomputed); withdraw drops it into the carry slot (enable at a bench).
  Hints are constant (250-hint cap); amounts + pool show via `hud_msg`. Both ends gate on `is_player_valid`.
- **Geometry** [`tools/gen_plaza_basement.js`](tools/gen_plaza_basement.js) (new, re-runnable + `--revert`):
  **carves** the single stock arena-floor slab (`{219830C1…}`) into a connected 4-chunk frame around a
  stairwell well (the abyss strip-and-re-emit pattern — the only way to hole a solid slab), + a 14-tread
  16/16 stairwell, the enclosed vault room (carved floor = its ceiling), a jump-proof railing ring, and the
  door slab. Bake-safe `box()` filler-winding + a **unique `7A2BAE0*` GUID prefix** (NOT the `-ACE0-` middle
  group — the abyss family already uses `{7A2BAB0E-ACE0-…}`, so stripping on `-ACE0-` would have deleted 23
  abyss brushes; bug caught + fixed during the build). **LED bake: BAKED** (`tools/_bake_test.ps1`); full
  `build_map.ps1` OK, fresh 46 MB `.ff`, navmesh regenerated over the stairs.
- **Fix (user 2026-06-27): the well was walling off the Implant Bench room.** First placement put the well
  (and its north railing) right behind the plaza→lab doorway, so buying the implant door led straight into a
  wall and the benches were unreachable. The well was shifted **south** (y −252→−300) so a ~60u landing sits
  at the doorway and the open west/east side-corridors let a player walk **around** the railed well to the
  bench pads; the vault room extends south to match. **Needs a rebuild (game must be closed).**
- **Safe utility room**: at z=-240 inside the trench OOB box, so it's **excluded from the trench amping**
  (no −20% slow / surge / danger HUD) via new `origin_in_vault()`/`player_in_vault()` in
  [`_acc_bus_trench.gsc`](scripts/zm/zm_abandoned_cyber_city/_acc_bus_trench.gsc) — but still **OOB-kill-vetoed**
  there (the second-part pattern: excluded from `underground_layer`, vetoed in `acc_trench_oob_allow`).
- Door wiring: `enter_exchange` case in `zm_abandoned_cyber_city.gsc::zone_door_trigger_origin` (X-thin →
  default buy-trigger offset). NB **`enter_vault` was already taken** (the corp/lab Vault) — hence `enter_exchange`.
- **NEEDS WALK-TEST** (build OK ≠ proven): stairwell collision survived cod2map (single-slab T-junction trap is
  invisible to the bake); zombies path down; the door buys; co-op deposit-A/withdraw-B + item bench round-trip.

### Added — Mega Quick Revive (Savior): −50% damage while reviving (user, 2026-06-26)

Savior (Mega Quick Revive) gains a 4th effect: while you are **actively reviving a teammate** you take
**50% less incoming damage** (×0.50) for the whole revive channel — you can no longer be punished as easily
for stopping to pick someone up in a horde. New `acc_perks::savior_revive_damage_mult()`
([_acc_perks.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_perks.gsc), `ACC_SAVIOR_REVIVE_DMG_TAKEN=0.50`)
returns the live multiplier, gated on owning Mega QR **and** the stock reviver-side counter
`self.is_reviving_any > 0` (held for the entire channel, `_zm_laststand.gsc:1208`→`:1285`, verified in the
stock mirror). It's read **live, per hit** in the player-damage chokepoint
[_acc_elites.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_elites.gsc)`::on_player_damaged` (no poll lag),
applied **after** the Exo Suit resist so the two stack multiplicatively, floored at 1 (always killable).
Self-revive doesn't qualify (the downed player is rejected as invalid earlier in the callback). **Display UI:**
the Savior perk-info card ([acc_hud.lua](ui/uieditor/menus/hud/acc_hud.lua), index `[2]`) gains a qualitative
"Shielded while reviving" bullet (mega + megaFull) — magnitude stays in the docs per the no-numbers-in-game
rule. Docs synced: docs/13 (table, full Mega description, mechanics, at-a-glance, impl-status, verification
table, tuning lever) + docs/perk_abilities.md. GSC + LUI — linker (`-GscOnly`) build.

### Added — Jukebox "NOW PLAYING" banner shows the song title, to all players (user, 2026-06-26)

When a Teddy-Bear jukebox song starts, the UI now shows the **song title** (e.g. "Cyber Dreams") and shows
it to **every player**, not just the one who fed the jukebox ([_acc_ee_song.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_ee_song.gsc)).
Each bear carries a `b.title` (set in `make_bear`); on trigger, the old single-player `"^5MUSIC PLAYING^7"`
toast is replaced by a `"^5NOW PLAYING^7  <title>"` banner broadcast over `GetPlayers()` (the song already
plays 2D for the whole lobby, so the banner should too). Titles (user): center = **"Cyber Dreams" (Lilex)**,
left = **"I Want To Stay At Your House"**, right = **"Night Groove"**. The two flanking songs' wavs
(`acc_ee_song_2` / `_3`) still need banking — until then those bears show the banner but play silently.
GSC-only. Doc: [46_trench_systems_guide.md](docs/46_trench_systems_guide.md).

### Added — Comeback bonus: full-death respawn sets money to 500 × round (user, 2026-06-26)

To support players who have a bad start, a player who **fully bleeds out and respawns** the next round now
comes back with their money **set to exactly `500 × round_number`** (round 20 → **$10,000**). New code in
[_acc_points.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_points.gsc): a per-player `watch_comeback_death()`
watcher flags `acc_comeback_pending` on the stock `bled_out` notify; `on_player_spawned()` (newly registered
in [_acc_main.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_main.gsc)'s connect + spawn dispatch) consumes the
flag on the next spawn and `comeback_set_score()`s the player to the floor via
`player_reduce_points("take_all")` + `add_to_player_score(500 × round)`. **Set, not add** (user's choice): I
verified against the stock mirror that BO3's `penalty_died` defaults to **0.0** and this map never overrides it
— players actually *keep* their money on a bleed-out respawn — so a pure add would make dying profitable (a
death-farm); setting to exactly the floor means dying never nets more than `500 × round` and a rich player who
dies drops to it. **Trigger = full death only** — uses the same `bled_out` signal as the implant-wipe change
below, so a last-stand revive never qualifies (no revive-farming) and the first spawn never bleeds out.
Practically co-op-only (solo downs either auto-revive with money kept, or end the game). Tuning lever
`ACC_COMEBACK_PER_ROUND` (default 500). docs/06 Point Economy synced. GSC-only — linker (`-GscOnly`) build,
fresh `.ff` (no geometry change).

### Added — Dying out wipes your implants (user, 2026-06-26)

Boss-item **implants no longer survive a real death.** Previously the equipped-item buffs re-applied on
every respawn, so a player who bled out kept their implants — the doc even *claimed* "items are lost on
death," but nothing implemented it. Now `_acc_boss_items::lose_implants_on_bleed_out` (threaded per player
from `on_player_connect`) hooks the stock per-player **`"bled_out"`** notify — the canonical real-death
signal (`_zm_laststand.gsc` fires it at bleed-out `:523/:580`; stock waits on it `:1311`) that does **not**
fire on a down that gets revived — and `unequip_slot`s **both** slots, so each item's `on_unequip` strips its
buff + does the tactical hand-off + re-syncs the HUD. Result: a revived player keeps their implants, but a
player who **dies out** respawns implant-less and must find + re-implant new boss items ("^1IMPLANTS LOST^7"
on screen). Carried-but-not-yet-implanted items are unaffected. Solo bleed-out is game-over, so it's a no-op
there. GSC-only. Doc: [12_boss_items.md](docs/12_boss_items.md).

### Changed — Paradise DREAD phase 15s → 10s (user, 2026-06-26)

`ACC_PARADISE_DREAD_SEC_DEF` 15 → **10** ([_acc_paradise.gsc:61](scripts/zm/zm_abandoned_cyber_city/_acc_paradise.gsc#L61)):
shorter lead-in between the fog rolling back in (PHASE 2 Omen) and the bosses storming the arena (PHASE 4
Battle) — Brutus now spawns **10s** after the fog instead of 15s. Live dvar `acc_paradise_dread_sec`. Header
comment + [docs/48](docs/48_abyss_descent.md) phase table synced. GSC-only.

### Changed — Dev mode opens all Lab perk alcoves (user, 2026-06-26)

In the **dev sandbox** all 10 Lab perk alcoves are now **OPEN** (no per-round rotation), so every perk is
buyable while testing. Driven off the single dev flag: `acc_resolve_dev_flags()`
([zm_abandoned_cyber_city.gsc](scripts/zm/zm_abandoned_cyber_city.gsc)) now `SetDvar`s
`acc_perk_doors_all_open` to 1 when `level.acc_dev`, exactly like the other dev sub-dvars
(`acc_open_map`/`acc_glitch_test`/`acc_variants_debug`). `_acc_perk_doors::dev_all_open()` already reads that
dvar, so **no module logic changed** — only the wiring. **Normal play is unchanged**: `acc_dev 0` leaves the
dvar at the ship default 0 and the per-round random **4-of-10** rotation runs as designed; the manual
`set acc_perk_doors_all_open 1` override still works on its own. This **reverses the 2026-06-18 "walls close
in dev too" choice**; it also corrects a stale doc that claimed dev followed `acc_open_map` (the code only ever
read `acc_perk_doors_all_open`, which dev never set — which is why the walls actually closed in dev).
Comments in [_acc_perk_doors.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_perk_doors.gsc) + docs/13 synced.
GSC-only — linker (`-GscOnly`) build (no geometry change).

### Changed — Dev starting loadout: maxed Chicom CQB instead of AK-47 (user, 2026-06-26)

Dev mode now spawns every player holding a **fully-packed (PaP III) + max-Overclock Chicom CQB**
(`t6_chicom_cqb_up`) instead of the AK-47 ([_acc_dev.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_dev.gsc),
`dev_give_packed_chicom`). Two changes: (1) weapon swapped `t9_ak47_up` → `t6_chicom_cqb_up` (true-base
`t6_chicom_cqb`), so PaP-tier and Overclock progress key correctly; (2) **Overclock bumped tier 5 → 10** —
the cap went `ACC_TIER_MAX` 5 → 10 on 2026-06-24, so the old `tier=5` was only *half* max. Effects scale
off the tier in `_acc_damage::get_oc_tier` (no clamp) and `oc_hud_loop` pushes "v10" to the chip. Dev-only,
hardcoded (no console dvar). GSC-only.

### Changed — Loot Stash bonus: +10/+15, additive Double-Points boost, banked (user, 2026-06-26)

The Loot Stash / Payroll Ledger per-kill Points bonus is now **+10 regular / +15 headshot**, rising to
**+15 / +25 with Double Points** (the DP boost is **additive** +5 / +10, not the base's ×2). Since 15/25 aren't
multiples of 10 and the stock money currency rounds every award **up** to 10 (`_zm_score.gsc:528`), the new
`award_killer_with_ledger` ([_acc_points.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_points.gsc)) **banks**
the sub-10 remainder on the killer and flushes it on a later kill, so the net payout is exact (the floater
alternates +10/+20). Folds base + bonus into one payout (single floater). Replaces the flat +10/+20-doubled
scheme. docs/12 + boss-item comments synced. GSC-only — linker build.

### Fixed — Bus-Station → trench stairs re-pitched (too steep, glitched the player) (user, 2026-06-26)

Players reported the stairs descending from the Bus Station into the corp trench were "so steep the
player glitches." They were **14 steps of 16 tall × 16 deep = a 45° pitch**; the player collision hull
catches on the step nosings at 45° and stutters. **Fix** (per the user's request — keep the top, extend
the length so each step is shorter): `tools/regen_trench_stairs.js` (new, re-runnable) rebuilds both
stairs at **10 tall / 16 deep = ~32°, 23 steps, 368u long** (was 224u). The top lip is unchanged (W stair
south lip `y=1723`, E stair north lip `y=2173`); each extends further toward the middle (W `y[1723,2091]`,
E `y[1805,2173]`). The two stairs sit on **opposite x-walls** (W `x[-761,-665]`, E `x[703,799]`) so growing
them toward the centre can't collide, and 368u fits the 450u trench with ~82u to spare. Both **pit-side
walls** re-sized to match. Lower 10u risers (well under the ~18u stock step tolerance) link the navmesh
even more easily than the old 16u, so zombies still path the crossing. Geometry change → **full LED bake
(passed: fresh BSP + navmesh + lightmap, no `brush.cpp:1860`)**. Doc: [03_layout.md](docs/03_layout.md).

### Added — Passive trench shard income (reward for staying in the trenches) (user, 2026-06-26)

Standing in a trench layer now passively earns Data Shards — **1 shard every N seconds, N shrinking with
depth**: **L1 (Bus Station pit) 45s · L2 35s · L3 28s · L4 22s · L5 18s** (deeper = more reward for the risk).
A new trench-only shard source on top of the caches / Warden / altar / reactor.

- **Impl:** [_acc_bus_trench.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_bus_trench.gsc) `trench_shard_income`
  — an isolated **per-player** 1s thread (threaded in `watch_connections` alongside the fall/bridge watchers),
  using the existing `underground_layer()` (which already returns 0 for surface AND Paradise, so income only
  ticks in real trench layers 1-5) + `acc_data_shards::grant_player(self, 1, "trench_income")` (shows the
  "+1 Data Shard" floater; cap-clamped). `trench_income_interval(layer)` is the per-layer table.
- **Behavior:** per-player (each player earns their own); clock resets when you leave the trench; carries
  across layer changes (paid at the current layer's rate, so descending never loses progress); stops at the
  shard cap and resumes after spending.
- **Tunable:** `acc_trench_income` (master, default 1), `acc_trench_income_amount` (1),
  `acc_trench_income_l1..l5` (45/35/28/22/18). docs/34 + docs/06 synced. GSC-only — linker build, `.ff` 46 MB.

Recurring hard crash, reproduced **during normal play** (not at an interaction). This is a **DIFFERENT BG-cache
pool** from the 2026-06-25 soul-box fix: that one was `triggerstring` (cap **250**, fed by `SetHintString`); this
one is the general **`string` cache (cap 2048**, fed by every DISTINCT string passed to a server hudelem
`SetText`). Like the triggerstring cache, every distinct string **permanently burns a slot for the whole match**
(never freed). A live number rendered via **`SetValue` costs ZERO slots** (stock `_zm.gsc` `countdown_hud SetValue`)
— that is the cache-free path the old code never used (it only mentioned `SetValue` in a comment).

**THE crash — co-op squad roster** ([_acc_health_bars.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_health_bars.gsc)):
`update_roster` ran **10×/sec per player** and `SetText`'d one merged line `"Sh "+shards+...+"$"+points` with
**no change-guard**. `points` (= live `.score`) takes **thousands of distinct values** over a match → thousands
of permanent `string`-cache slots → overflow at 2048. Because the roster is *always running*, it crashed during
normal play rather than at a specific interaction (unlike the soul boxes). Fix = **two elements that render as
one flush string** `"Sh {shards}  MB {b}  EXO {e}  $<points>"`: the text part (`Sh`/shards/`MB`/`EXO`/`$`, or
`"DOWNED  $"`) is a **`SetText` element RIGHT-aligned to end exactly at the `$`** (change-guarded), and the only
truly-unbounded field, **`points`** (= live `.score`), is a **`SetValue` element LEFT-aligned 2px after it** —
so the `$` sits flush against the score every frame. A number via `SetValue` costs **zero** cache slots, so the
climbing score can never overflow the 2048 cap again. shards/MB/EXO remain in `SetText` because they're a small
**bounded** set (shards is a spend-capped currency — it was the stable pre-roster top-left readout), not a runaway
like the score. Cost: **+1 hudelem/row** (3→4; lazy, so 4-player = 16, still well under the old 24 that blew the
pool). *(Two earlier attempts were reverted: a 3-column `SetValue` layout — user rejected it for dropping the
`Sh`/`$` labels and widening gaps; then `.label` + `SetValue` — **`.label` does NOT draw on `createFontString`
server hudelems** (verified in-game: only the bare number rendered, all prefix text vanished). The right-aligned
`SetText` is the reliable way to keep a text prefix on a flush, crash-safe number.)*

**Two more `SetText` offenders hardened** (both → `SetValue`): the hidden top-left **Data-Shards counter**
([_acc_data_shards.gsc:360](scripts/zm/zm_abandoned_cyber_city/_acc_data_shards.gsc#L360), high-cardinality), and
the **round counter** ([_acc_health_bars.gsc:106](scripts/zm/zm_abandoned_cyber_city/_acc_health_bars.gsc#L106),
bounded ≤255 but the correct cache-free path). **Key correction:** `alpha = 0` (hidden) does **NOT** stop `SetText`
registering a string — registration happens on the *call*, regardless of visibility — so the hidden shard counter
was still leaking.

A full-repo audit (6-tool sweep) confirmed **no other unbounded** feeder: the Paradise finale timer (~240 distinct
`M:SS` strings, **one-shot** end-game) and lockdown `killed/total` counter (≤~30/challenge, totals reused) are
**bounded-small** and left as-is; all `SetHintString` callers are bounded or already change-guarded; **no**
`PrecacheString` anywhere; LUI `setText` uses a separate pool. Rule (extends the soul-box rule to this cache):
**never `SetText` a live/unbounded number — use `SetValue`; a hidden element still burns the slot.** Built clean
(GSC-only, fresh `.ff` 46 MB). Docs: [49_hud_modernization.md](docs/49_hud_modernization.md). Memory:
`string-cache-setvalue-not-settext`.

### Changed — Phantom boss cadence → round 10, every 10 (user, 2026-06-26)

The Phantom ("Reaper") now first spawns at **round 10** and recurs **every 10 rounds** (10, 20, 30, …) in
normal play, up from round 8 / every 8 ([_acc_boss_phantom.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_boss_phantom.gsc)
`ACC_PHANTOM_FIRST_ROUND_DEF`/`ACC_PHANTOM_INTERVAL_DEF` 8→10; dvars `acc_phantom_first_round`/`acc_phantom_interval`).
Dev mode stays every-4 for fast testing. No collision risk: the `is_full_boss_round` yield is dead code and
`_acc_boss.gsc`'s round-10 slot is the kill-anchored Trench Warden, not a fixed full boss. docs/34 synced.
GSC-only — linker build.

### Glitch-purge co-op spawn-stacking fixed + dev/god ship-safe + HUD pool fix (user, 2026-06-26)

Lockdown/"Glitch Purge" `relocate_party_safe` was `SetOrigin`-ing every player to one centre point, stacking
their capsules so the engine ejected them through the unsealed doorway → OOB death in co-op. Now fans each
player onto a distinct ring slot ([_acc_lockdown_challenge.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_lockdown_challenge.gsc)).
Also: `acc_dev`/`acc_god` reverted from hard-coded ON to dvar-gated ship-safe defaults; the co-op squad-roster
HUD rewritten lazy (24→12 hudelems/player) to stop server-hudelem pool exhaustion that silently hid the trench
warning / glitch-purge / boss bars in 4-player; roster now shows player names + points + red bar when down.

### Changed — Trench-zombie kill payout 20 → 30 (user, 2026-06-26)

Surge/drip-spawned trench zombies (tagged `acc_trench_zombie`) now pay **30** points per kill, up from 20
([_acc_points.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_points.gsc) `on_zombie_death`, dvar
`acc_trench_zombie_points` default 20→30). Still a flat award (no damage-share split / headshot / Kinetic
Battery / round count). docs/34 synced. GSC-only — linker build.

### Fixed — Paladin HB50 headshots did LESS than body shots (user, 2026-06-26)

Paladin headshots were doing **half a body shot**. Root cause: the damage code applies a universal headshot
"temper" (×0.5 reg / ×0.6 boss) that assumes every gun's GDT `locHead` is ~5.0 (→ 5.0 × 0.5 = **2.5× body**),
but the Paladin's `skye_t8_paladin_hb50.gdt` had `locHead`/`locHelmet` flattened to **1.0** (1.0 × 0.5 = **0.5×
body**) — an old "all-1.0" Paladin pass had been re-applied on this box. (Both loc tools, `normalize_gun_loc.js`
and the older `normalize_sniper_loc.js`, actually set snipers to head 5.0; the MORS was already correct at 5.0 —
only the Paladin had regressed. It's a known recurring regression, see the memory.)

- **Fix:** restored `locHead`/`locHelmet` to **5.0** on both Paladin blocks (base `t8_paladin_hb50` + PaP
  `t8_paladin_hb50_up`) in the install GDT, then `gdtdb /update` + relink. Headshots now do **2.5× body** like
  every other gun. Variants inherit (no own loc); MORS untouched (already correct).
- Updated the stale `_acc_damage.gsc` comments that described the Paladin as locHead 1.0 / 0.5× as if intended.
- GDT is install-side (not repo-tracked); a fresh box gets the right value from `normalize_gun_loc.js` (sets the
  Paladin → 5.0). If "headshot < body" recurs, the Paladin GDT loc is the first thing to check. Memory:
  `sniper-gdt-loc-headshot-convention`.

### Fixed — Phantom only damaged one player in co-op + HP −30% (user, 2026-06-26)

The Phantom **sapped (slowed) every player on its chain but only ever damaged one** in co-op. Two separate damage
paths were both broken; both fixed:

- **Normal melee — stale AI enemy** ([_acc_boss_phantom.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_boss_phantom.gsc)):
  the Phantom deals normal damage via the **stock zombie AI melee** (`host.meleeDamage`), but it never told the AI
  who to hit — so the AI held one acquired `self.enemy` and the blinks onto other players never connected a swing.
  **Fix:** `host.closest_player_override = &phantom_pick_target_override`, which returns the Phantom's **current
  blink target** (updated every blink in `phantom_blink_to`). Stock `get_closest_valid_player` consults this per-AI
  override (`_zm_utility.gsc:1474`) to set **both** `self.favoriteenemy` (movement) and `self.enemy` (melee), so the
  AI now chases + swings at whoever the Phantom just warped onto, rotating across the team. Same mechanism the
  Glitch Stalker uses.
- **Chain special — sapped but didn't damage** (the exact symptom): the chain applies its **slow directly** to each
  hop player, but relied on the AI for *damage* — and the 0.7–1.1s rapid hops never give the AI a swing, so only its
  one enemy took damage. **Fix:** the chain now also deals the per-hop hit **directly** via
  `target DoDamage(meleeDmg, …, "MOD_MELEE")` — the same means-of-death as a stock zombie melee, so Jugg / Exo /
  trench scaling / downing all apply (`_acc_elites::on_player_damaged`). Now the chain damages **each** player it
  saps.
- **Chain reaches all 4**: `ACC_PHANTOM_CHAIN_HOPS_DEF` 3 → **4** (still capped to the live player count), so a
  4-player chain hits everyone, not 3 of 4.
- **HP −30%, scaling preserved**: `ACC_PHANTOM_HP` 80000 → **56000** (solo) × the unchanged logarithmic
  `boss_hp_player_mult()` → solo 56k / 2p 84k / 3p ~100k / 4p 112k (was 80k/120k/143k/160k). Pure GSC — linker-only.

### Fixed — Phantom override could hang the server in co-op (audit, 2026-06-26)

Follow-up from a 6-dimension adversarial audit of the Phantom (19 raw findings → 1 confirmed, 18 refuted). The
`closest_player_override` melee fix above had a **reachable co-op server-hang**: `phantom_pick_target_override`
returned `self.acc_phantom_target` gated only on `acc_data_shards::is_player_alive` (no `.ignoreme` check), but
stock `get_closest_valid_player` (`_zm_utility.gsc`) pre-culls its `players` array to `am_i_valid` entries
(**which includes `.ignoreme`**) and then re-checks the returned player in a **wait-less** loop,
`ArrayRemoveValue`-ing invalid ones. If the Phantom's target was a teammate cloaked by **Cyberware Ghost
Protocol** (`rx2b` → `zm_utility::increment_ignoreme`, who stays alive + standing so `is_player_alive` passes),
stock's `ArrayRemoveValue` was a no-op, `players.size` never hit 0, and the override handed back the same player
every iteration → **infinite loop on the AI targeting frame** (server hang). Needs ≥2 players (the cloaked target
+ one still-valid teammate). **Fix** ([_acc_boss_phantom.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_boss_phantom.gsc)):
membership-check `acc_phantom_target` against the passed-in `players` array before returning it (mirrors the
Glitch Stalker's `glitch_pick_uncloaked_target`, which only ever returns a member of the validated set);
otherwise fall through to the path-distance / closest fallback. Pure GSC — linker-only.

### Fixed — Trench prop clips: snug to the models (user, 2026-06-26)

[add_prop_clips.js](tools/add_prop_clips.js) clips were over-reaching = invisible walls. Added a per-prop `top`
override and re-tuned the underground props:
- **Flat-screen panel model** (`p7_cai_sign_inteactive_kiosk`, used several places): its square clips were big
  invisible walls → now **thin slabs** matching the panel, oriented by spawn yaw. **Reactor Surge plinth** (yaw
  270, faces E/W): 48×48×80 → **18(X)×48(Y)×64** (thin in X). **Perk-slot vendor / Neural Bay** (yaw 0, faces
  +Y): 56×56×80 → **48(X)×18(Y)×64** (thin in Y). The 3 deeper uses (Glitch Altar at abyss L3, + altar/vendor in
  Paradise) are walk-through (no clip = no invisible wall) — left as-is.
- **Data-cache crates** (`p7_cai_stacking_cargo_crate`, ±360,1950): kept the snug 56×56 footprint but dropped the
  height 80→**48** (`top:-192`) to match the model + the plaza crates.
- Other props (work table / perk-slot kiosk) unchanged. Re-ran the generator; full LED-baked build.

### Fixed — Mystery Boxes: solid collision at every node + each box flush against a wall (user, 2026-06-26)

You could walk straight through every Mystery Box, and they floated in open floor. **Two root causes:** (1) the
MagicBox xmodel has no player clip, and the `acc_box_clip_*` collision brushmodels the code expected **were never
authored into the `.map`** — `manage_box_collision` no-oped with nothing to solidify; (2) even the code only
solidified the *active* node, but every node always shows a box model (the moving box, or the idle "fake" box when
it's elsewhere), so all 6 should be solid.

- **Collision at all 6 nodes** ([tools/place_boxes_against_walls.js](tools/place_boxes_against_walls.js)): authored a
  `script_brushmodel` `clip` (60×60×48) at each box, and changed
  [_acc_map_randomizer.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_map_randomizer.gsc) `manage_box_collision` to keep
  **every** node's clip permanently solid (replaced the old active-only toggle with `solidify_all_box_clips`). No more
  walk-through anywhere. `script_brushmodel` is LED-exempt, so the lightmap bake is unaffected.
- **Against a wall** — repositioned all 6 boxes ~40u off a verified-solid interior wall face, facing into the room,
  clear of door gaps/spawns/wallbuys/machines/PaP/boss spawn/Overload point/trench/power switch (per the room-feature
  map + `source_data/rooms.json`): Plaza (173,250 E-wall), Market (−1891,928 W), Corp (400,2708 N), Roof (−1684,2830 W),
  Vault (1684,2830 E), Lab (759,3650 E). zbarrier + struct share origin/angles so the buy prompt stays attached.
- Full build (cod2map + navmesh + LED bake) — **bake passed**. The `clip` blocks AI too, so a zombie won't walk through
  a box either; against a wall the navmesh impact is minimal. Plaza (shrunk spawn room) is the one to eyeball in-game.

### Fixed — Mahem "only packs twice" — the REAL cause: AAT exemption hides the machine (user, 2026-06-26)

The Mahem could PaP only **twice** despite several prior fixes. **Those fixes were all wrong** — they patched
`level.zombie_weapons_upgraded` (the upgrade table), but that was never broken. Full trace through stock
`_zm_pack_a_punch.gsc` + `aat_shared.gsc` + `_zm_weapons.gsc`:

- After the tier-2 transform you hold `s1_mahem_up`. For pack 3 the machine must stay **visible**.
  `player_use_can_pack_now()` shows it only if `can_pack_weapon(held) || weapon_supports_aat(held)`.
- `can_pack_weapon(_up)` is **false for every gun** — `is_weapon_included(_up)` fails because stock
  `add_zombie_weapon` registers only the BASE in `level.zombie_weapons`, never the `_up`. So **all** guns rely on
  **`weapon_supports_aat(_up)`** for the tier-2→3 visibility: `is_weapon_upgraded(root) && !aat::is_exempt_weapon`.
- `is_weapon_upgraded(s1_mahem_up)` was **already true** (stock `add_zombie_weapon:554` maps every CSV upgrade) —
  so the upgrade-table patches were no-ops. **The real blocker:** the Mahem's CSV row has **`AAT_EXEMPT` (col 17)
  = `TRUE`** (it's a launcher) → `register_aat_exemption(s1_mahem_up)` → `weapon_supports_aat` returns false →
  **machine hides the instant pack 2 finishes.** Conventional guns leave that column blank, so they pack 3×.
- **Fix** ([_acc_pap_levels.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_pap_levels.gsc)
  `make_mahem_pap_visible_to_tier3()`, called from `pap_tier_machine_watcher`): drop `s1_mahem_up` from
  `level.aat_exemptions`. AAT is globally OFF (`level.aat_in_use=false`), so this grants **no** alt-ammo — it only
  restores machine visibility so `acc_pap_validate` (which `vending_weapon_upgrade` calls first, before any AAT
  branch) runs the in-place tier-3 pack, exactly like every conventional `_up` gun.
- The earlier `register_special_upgrades()` is kept (harmless defensive net) but its comment is corrected — it was
  never the Mahem fix. Dev log prints `was_aat_exempt=1 is_weapon_upgraded=1`; `+set acc_dev 1` then shows the 3rd
  pack reach `tier 3/3`. Pure GSC — linker-only. docs/05 + memory updated.
- **Belt-and-suspenders (this build):** pack 3 has TWO independent gates — machine **visibility** (above) AND the
  **tier key** resolving `s1_mahem_up`→`s1_mahem` (so `get_tier` reads the tier stored on packs 1‑2). Hardened the
  latter too: `_acc_weapon_variants::true_base()` now strips a trailing `_up` by NAME if the stock upgrade table
  didn't, so the tier key is always the true base regardless of stock-table state (no-op for conventional guns).
  Added an `acc_dev` ground-truth readout `dev_mahem_pap_watch()` that prints, whenever you hold a Mahem,
  `upg= base= tier= exempt= machine_visible=` — so any remaining issue is diagnosable at a glance instead of guessed.

### Added — AK-47 wall-buy on Abyss Layer 4 ("4th floor" trench) (user, 2026-06-26)

Planted a **4th fixed wall-buy** — the **S-tier AK-47** (`t9_ak47`, **1500**, from
[zm_levelcommon_weapons.csv](gamedata/weapons/zm/zm_levelcommon_weapons.csv)) — on the **south wall of Abyss
Layer 4** (`z=-960`, the "4th floor" of the trench). Goal: a real reason to commit to the deep descent, not
just box-roll up top. Followed the existing 3-part wall-buy recipe exactly (`wallbuy-chalk-inline-mesh-recipe`):

- **Geometry** ([map_source/zm/zm_abandoned_cyber_city.map](map_source/zm/zm_abandoned_cyber_city.map)): an
  inline worldspawn **chalk mesh** (entity `ACCC0004`, the real AK-47 chalk `mtl_t6_wpn_ar_ak47_wall_chalk`
  from the installed `skye_t6_ak47.gdt`) on the L4 south wall face (y=1723, room to the north, +y normal),
  centered x=-400, z=-927.5..-885.5 — same winding as the Five-Seven chalk. Plus the **trigger struct**
  (`ACCB0007`, `weapon_upgrade` / `zombie_weapon_upgrade t9_ak47`) + **model struct** (`ACCB0008`,
  `wpn_t9_ak47_world`), 2u proud, facing +y. All clear of the L4 down-well (north) and the L3→L4 stair landing.
- **LED-bake trap caught + fixed:** the first material tried, stock `t7_zm_chalk_buy_m8a4`, is in the runtime
  asset list but **crashes the Radiant lightmapper** (0xC0000005) — proven by `_bake_test` bisection (baseline
  bakes; +m8a4 chalk crashes; +frag and +skye-AK chalk bake). Lesson: a chalk being a valid *runtime* asset ≠
  bake-safe; use a skye `*_wall_chalk` `material.gdf` (same class as the kard/olympia chalks already shipping).
- **Whitelist** ([_acc_map_randomizer.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_map_randomizer.gsc)
  `remove_all_wallbuys()`): added `t9_ak47` so the box-only stripper KEEPS it (the other 3 stay whitelisted).
- **Idempotency:** the new entities use non-`-ACA2-` GUIDs, so `gen_abyss_layer.js` re-runs won't strip them
  (same as the existing `ACCC000x`/`ACCB000x` wall-buys).
- Docs synced: [05_weapons.md](docs/05_weapons.md), [07_replayability.md](docs/07_replayability.md),
  [57_player_guide.md](docs/57_player_guide.md). **Geometry change → full LED-baked build.**

### Changed — Widen gun spread ±3% (best 5 buff / worst 5 nerf) + S-tier box rarity ~1.7% (user, 2026-06-26)

Pushed the best-vs-worst gun gap a notch wider and made the S-tier guns the rarest box rolls.

- **±3% damage spread** ([_acc_damage.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_damage.gsc) `acc_weapon_balance_mult`,
  `IsSubStr` → base + `_up` + all twins): **best 5 ×1.03** — Chicom CQB (0.25→0.2575), M60 (0.20→0.206),
  AK-47 (0.227→0.2338), PPSH-41 (0.24→0.2472), Tac-19 (0.612→0.6304); **worst 5 ×0.97** — Paladin HB50
  (0.49→0.4753), RPD (0.125→0.1213), Five-Seven (0.26→0.2522), MK14 (0.30→0.291), Olympia (0.489→0.4743).
  Specials (Thundergun / Mahem / Action Figure) left untouched.
- **No tier/price churn** (verified via `tools/compute_gun_tiers.js`): the buff only lifted already-TOP guns and the
  nerf only lowered already-BOT guns, so every PaP **price tier is unchanged**. The only label change: **Tac-19's
  formula tier ticks A→S** (papScore 7.60→7.74), so the S-tier set is now exactly the buffed best 5 (Chicom, M60,
  AK-47, PPSH-41, Tac-19).
- **S-tier box rarity ~1.7%** ([_acc_map_randomizer.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_map_randomizer.gsc)
  `acc_box_weight`): those 5 S guns pinned to `boxForce: 8` (was 10–12) → ~1.7% each (pool weight 477→463). MORS
  (A-tier, TOP price) stays wt 12 ~2.6%; everything else ticks up slightly (MID ~6.3%, BOT ~10.8%) from the smaller pool.
- Roster `e` mirrored in `compute_gun_tiers.js`; regenerated docs/54 + pasted `acc_box_weight`; `pap_price_bucket`
  comments + docs/57 (player guide) + docs/05 (box-odds table) synced. Pure GSC — linker-only.
  (Note: docs/41 stats table + the docs/05 base/PaP **tier tables** carry pre-existing drift — removed guns, mults that
  never matched code — and were NOT reconciled here; regenerate separately if needed. docs/54 is authoritative.)

### Changed — Brutus (Trench Warden) HP +20% (user, 2026-06-26)

Bumped Brutus's base HP **+20%** (`ACC_BOSS_MINI_HP` / `acc_boss_mini_hp` default **40000 → 48000**) in
[_acc_boss.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_boss.gsc). The base is the only lever needed — round
scaling (`scale_mini_boss_hp` = `base × (1 + pct·rounds_past_anchor)`) and the logarithmic co-op multiplier
(`boss_hp_player_mult`) both **multiply** this base, so a 20% bigger base lifts the entire curve by exactly 20%
at every round and player count, out of the box. New solo curve: **r5 48k → r10 62.4k → r20 91.2k → r30 120k →
r40 148.8k**; co-op (round 5) 1–4p: **48k / 72k / 86k / 96k**. Comments + docs (11, 15, 34) synced. GSC-only.

### Changed — Shrink the Spawn Plaza ~75% + Implant Lab side-room + scattered crate cover (user, 2026-06-26)

The **Spawn Plaza (`start_zone`)** was a huge, near-empty arena (interior ~2110×1260) you could run giant
circles in. Tightened it to a compact, chaotic space, carved the blocked-off south into a gated **Implant Lab**
room, and replaced plain blocks with themed props. All via [tools/gen_plaza_shrink.js](tools/gen_plaza_shrink.js)
(re-runnable) + GSC door/prop wiring. Built clean (LED passed, `.ff` 45.99 MB). **NEXT: user playtest.**

- **~75% smaller** — new plaza interior **x[-470,213] y[-240,720]** (683×960 ≈ 25% of the original ~2.66M). West/
  south/north walls are fixed by spawns + the window-barricade entry + the corridor mouths, so the squeeze is
  taken from the **east** (wall pulled 580→213). Both corner exits still connect via connector corridors to the
  original Market(NW)/Alley(NE) mouths at y[400,656]; the buyable doors out there are untouched.
- **Mechanism — additive inner walls, NOT a perimeter value-remap** (the template arena is too irregular; value-
  remapping crashed the LED bake in the tightening overhaul). New world-brush walls (proven `gen_room_cover`
  winding → baked light + correct compile-time navmesh) seal the dead space; the big template floor is untouched.
- **Implant Lab room (fixes a bug this work introduced):** the boss-item **Implant Bench** (its 2 pads, at
  y≈−480, anchored to the spawn struct) was getting **sealed behind the new plaza south wall** — that's the
  "benches disappeared" the user saw. Now the sealed south strip is a real room (interior **x[-400,-40]
  y[-540,-240]**, both pads inside), entered from the plaza by a **tight 80u doorway** (x[-260,-180]) gated by a
  **buyable slide-up door** (`enter_implant`, **1500**). Wired in
  [zm_abandoned_cyber_city.gsc](scripts/zm/zm_abandoned_cyber_city.gsc) `zone_door_trigger_origin` (center
  (-220,-240,50)) + `zone_door_thin_offset` (thin-in-Y). Room is inside `start_zone`'s volume → no separate zone.
- **Interior maze — tried, then removed (user, 2026-06-26).** Built a full-height serpentine of partition walls +
  "teeth" to force tight winding paths, iterated tighter, but the user decided against it ("remove the whole
  maze"). The plaza is now **open-but-shrunk** — difficulty comes from the ~75% shrink + scattered crate cover,
  not interior walls. (Lesson logged in memory: a wall ran through the plaza mystery box / a crate blocked a leg —
  always audit existing entities + flood-fill traversability before adding interior geometry.)
- **Obstacles — crates only, scattered (user: "only the little bunker things… spread them out"):** **3 cargo
  crates** (`p7_cai_stacking_cargo_crate`, already packed) scattered across the open plaza (SW / center-E / N) as
  low cover, spawned via `acc_spawn_plaza_props` (proven SetModel path) at **angle 0**; collision = matching `clip`
  brushes (gen_plaza_shrink `CLIPS`, coords in sync), **snug 56×56×48** (hx=hy=28 — the value tuned for this exact
  model in `add_prop_clips.js`; the earlier 80×80 axis-aligned clip around a rotated crate read as a "too-big/weird
  hitbox"). The plaza mystery box (`acc_box_plaza`) sits at (100,-150) in the SE spawn band.
- **Player spawns (user, 2026-06-26):** all 8 `initial_spawn_points` + `info_player_start` clustered into the open
  **SE back band beside the mystery box** (4×2 grid x{-200..40} y{-90,-130}); self-check + a box-collision check
  confirm none land in a wall or the box. `player_respawn_point` is left in place (the Implant Bench is anchored
  to it). The 5 start_zone risers outside the footprint + the box were relocated too (all idempotent by GUID).
- **Bake/build:** baseline BAKED 20.2s → tighter+room geometry BAKED 16s → **full build OK, LED passed.**
  Backup: `map_source/zm/zm_abandoned_cyber_city.map.pre-plaza-shrink-bak`. Lab/Alley/Market are the follow-up
  zones (harder: perk machines, etc.). Memory: `plaza-shrink-inner-walls`.

### Changed — Swap AK-47 ↔ AK-74u tiers (user, 2026-06-26)

Swapped the two AKs so the **AK-47 is now the TOP-tier gun and the AK-74u the MID-tier gun** — done by
adjusting their damage so the PaP-form scores genuinely trade places (not a cosmetic relabel), per the
`tools/compute_gun_tiers.js` recalc.

- **Damage lever** ([_acc_damage.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_damage.gsc) `acc_weapon_balance_mult`):
  AK-47 `0.186 → 0.227` (effDPS ~465 → ~568), AK-74u `0.23 → 0.184` (effDPS ~518 → ~414). That moves AK-47's
  PaP score ~7.04 → **7.90** and AK-74u's ~7.90 → **7.03**.
- **Recalc + regen** ([tools/compute_gun_tiers.js](tools/compute_gun_tiers.js) `GUNS` roster mirrored: AK-47 `e 568`,
  AK-74u `e 414`; AK-74u's `boxForce: 29` **removed** so its box rarity follows price). Re-ran the scorer →
  AK-47 lands **TOP** (rank 3), AK-74u **MID** (rank 9). Pasted the regenerated `pap_price_bucket` into
  `_acc_pap_levels.gsc` and `acc_box_weight` into `_acc_map_randomizer.gsc`.
- **Net effect:** AK-47 → PaP cost 5000/7500/10000, box roll ~2.5% (rare); AK-74u → PaP cost 4000/6000/8000,
  box roll ~6.1% (common). Box rarity now follows price for both (per user).
- **Docs synced:** docs/54 (auto-generated), docs/05 (base + PaP tier tables, price/box tables), docs/41 (stat
  table mults/DPS), docs/57 (player guide rows + the "breaks the rule" note → now MK14-only). Pure GSC — linker-only.

### Added — Custom combat HUD, phase 0+1: hide the stock ammo/weapon block, draw our own teal ammo/weapon/equip (user, 2026-06-26)

Replaced the stock BO3 ZM bottom-right ammo/weapon HUD with our own cyber-styled block, the **safe additive way** (Track A —
no stock-menu override, which would brick the `.ff`). The data is read **client-side from the engine's own weapon UIModels**
(the same models the stock `zmammo` widgets read, on a namespace **separate from our full clientuimodel clientfield pool**),
so this costs **ZERO new clientfields**. Bindings lifted verbatim from the on-disk `zm_building` `zmammo_*_abbey.lua`
widgets, recolored to `ACC_PAL` teal (no custom font, no custom material). Memory: `hud-combat-reskin-client-models`. docs/49.

- **Phase 0 — suppression** ([_acc_lui.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_lui.gsc) `suppress_stock_weapon_hud`,
  threaded per-life from `player_lui_init`): clears the engine bit `BIT_WEAPON_HUD_VISIBLE` via the stock call
  `self SetClientUIVisibilityFlag( "weapon_hud_visible", 0 )` (verified real — stock `_zm.gsc:6149/1761/536`), re-asserted
  every 0.25s because stock re-sets it to 1 on spawn/revive. One call, no LUI edit, no clientfield. **IN-GAME VERIFY GATE
  (docs/49 Phase 0):** confirm it hides the whole stock block AND doesn't kill a wanted d-pad/GobbleGum prompt.
- **Phase 1 — our widgets** ([acc_hud.lua](ui/uieditor/menus/hud/acc_hud.lua) TOUCHPOINT 7): `CoD.AccAmmoBlock` (big mag +
  `/reserve` + weapon name, low-ammo color via `acc_mag_color`, dark-glass plate + teal accent + corner brackets) bound to
  `CurrentWeapon.ammoInClip/ammoStock/weaponName`; `CoD.AccEquip` (lethal + tactical icon+count, icon free from the engine
  offhand models) bound to `CurrentPrimaryOffhand`/`CurrentSecondaryOffhand`. Build: `-GscOnly`, BUILD OK (fresh `.ff`).
- **Layout pass 2 (2026-06-26):** fixed the mag/reserve overlap (mag big lower-right, `/reserve` to its right, weapon name
  clearly above); tightened the plate (W 216) to read as one device; **folded the PaP-tier shield + Overclock `vN` into the
  device HEADER row** (top-left status chips) and re-registered them AFTER the ammo block so they draw on top of the plate
  (no more overlap); tightened the equip row above the plate. Build `-GscOnly`, BUILD OK (`.ff` 45.99 MB).
- **Co-op SQUAD roster (2026-06-26):** the bottom-left "player HUD with all 4 players" the user asked for — every player's
  **health bar + Data Shards + Mega Bottles + Exo tier**, small text, your row highlighted teal. Built as SERVER-SIDE GSC
  hudelems ([_acc_health_bars.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_health_bars.gsc) `ensure_roster`/`update_roster`),
  so it reads EVERY player's fields with **zero clientfields** (the no-budget path; memory `hud-combat-reskin-client-models`).
  The single solo health bar is now dormant (roster supersedes it); shared `hp_bar_color` recolored green→**teal** (Jug-tier
  shading kept, critical = magenta). Build `-GscOnly`, BUILD OK (`.ff` 45.99 MB).
- **Known follow-ups:** positions still first-pass (iterating from screenshots); per-gun weapon *silhouette* icon = later art
  pass; top-left Shards/Exo/Bottles readouts now DUPLICATE the roster (fold/remove once verified); roster could show NAMES
  instead of P#; PaP'd guns show the variant name ("Ultra").

### Fixed — Mahem "only packs twice": register the AW launcher's `_up` as a real engine upgrade, key-mismatch-hardened (user, 2026-06-26)

The Mahem (AW launcher, `s1_mahem` → `s1_mahem_up`) could PaP only **twice** — the 3rd pack silently no-oped and the
machine prompt vanished after the tier-2 transform. **Root cause** (traced through the real stock
[_zm_weapons.gsc](Call of Duty Black Ops III 455130/share/raw/scripts/zm/_zm_weapons.gsc)): the held packed form
`s1_mahem_up` was **not recognized as an engine upgrade** — `zm_weapons::is_weapon_upgraded(s1_mahem_up)` returned
`false`. That single fact breaks **both** PaP gates at once: (1) stock `can_upgrade_weapon` hides the machine while you
hold a weapon it thinks is un-upgradeable, and (2) our [_acc_pap_levels.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_pap_levels.gsc)
`get_tier` (keyed by `true_base` → `get_base_weapon`) returns 0, so the 3rd Use-hold reroutes to `acc_do_first_pack`,
finds no upgrade to apply, and no-ops.

- **Fix** ([_acc_weapon_variants.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_weapon_variants.gsc)
  `register_special_upgrades`, called from `init()` after the stock CSV weapons register): map every base box weapon's
  `_up` form back to its base in `level.zombie_weapons_upgraded` for any port the engine left unmapped (idempotent —
  conventional/stock guns that already resolve are skipped, so only the Mahem is patched). Now
  `is_weapon_upgraded(s1_mahem_up)` is `true` → the machine stays visible AND `get_tier` reads tier 2 → the 3rd pack
  routes to `acc_do_tier_up` and reaches tier 3 (MAX), like every other gun.
- **Key-mismatch hardening** (this build): stock `add_zombie_weapon` keys `zombie_weapons_upgraded` by the **raw**
  upgrade object (`:554`), but the lookups (`is_weapon_upgraded` `:1736` / `get_base_weapon` `:1630`) normalize the held
  weapon via `get_nonalternate_weapon(w).rootWeapon` first. For an AW launcher those can differ, so registering the raw
  object alone (the first cut of the fix) could still miss. `register_upgrade_key` now registers the raw upgrade, its
  `rootWeapon`, and the non-alternate form + its `rootWeapon` — every key a held copy can normalize to. Strictly safe
  (extra keys only make more `_up` copies resolve to their base). Pure GSC — linker-only.
- **Verify in-game** with `+set acc_dev 1`: the `^5[dev] PaP s1_mahem… -> tier N/3` prints (added 2026-06-25 in
  `_acc_pap_levels.gsc`) should now reach **tier 3/3** on the third pack. (The previously-deployed `.ff` was built
  ~12:04 on 2026-06-26, **before** the first cut of this fix landed at ~13:48 — so the running build never had it; this
  rebuild is what actually ships it.)

### Changed — Paradise: holistic horde buff (L2→L5 per minute) + UI alerts + NO power-up drops (user, 2026-06-26)

**Reworked** the Paradise anti-camp from a *per-zombie* alive-time ramp into a **world-wide horde buff stepped on the
battle clock**, and **disabled all power-up drops for the duration of the fight**.

- **Holistic buff** ([_acc_zombie_speed.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_zombie_speed.gsc)
  `paradise_buff_layer` now just READS `level.acc_paradise_horde_layer`): the WHOLE battle horde — including fresh
  spawns — shares ONE trench-equivalent layer. **L2** for minute 0–1, then **+1 each minute** → **L3** (1:00), **L4**
  (2:00), **L5** (3:00, held to the 4:00 win). That layer still feeds the SAME per-layer **speed**
  (`+acc_trench_layer_speed_pct%`/layer) **and health** (`apply_trench_health`, `+acc_trench_layer_hp_pct%`/layer,
  one-way) as a real trench floor, so the entire onslaught gets faster AND tankier every minute. **Replaces** the
  per-zombie "spawn at L3, +1 every 30s alive" ramp (and its `acc_paradise_t0` / `_buff_step_sec` machinery).
- **In lockstep with Brutus + a UI alert** ([_acc_paradise.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_paradise.gsc)
  `escalation_loop`, renamed from `boss_escalation_loop`): the same per-minute tick that spawns +1 Brutus + 1 Phantom
  now also steps the buff and fires an `IPrintLnBold` alert — **"The horde is getting stronger"** at 1:00 and 2:00,
  **"You will never escape!"** on the final step to L5 at 3:00. So the alert always lands when a Brutus spawns.
  `_acc_paradise.gsc` OWNS `level.acc_paradise_horde_layer` (set to L2 in `start_battle`, capped at
  `acc_paradise_buff_max` 5). New defines `ACC_PARADISE_BUFF_START_DEF` 2 / `_MAX_DEF` 5.
- **No power-up drops during the battle**: claims the stock `level.custom_zombie_powerup_drop` override hook
  (`_zm_powerups.gsc:588` — a true return suppresses the drop) via `block_powerup_drop`, gated on
  `level.acc_paradise_onslaught`, so **every** regular zombie-death drop (insta-kill / max-ammo / double-points /
  nuke / …) is blocked for the 4-minute finale and the rest of the match is untouched. The two FORCED drops that
  bypass that hook and can fire in the sealed plaza are gated explicitly: the Subroutine **recursion capstone**
  (`_acc_elites::drop_recursion_powerup_at`) and the **last-Brutus** drop (`nsz_brutus.gsc:690`). (The Mega Widow's
  `ww_grenade` refill is intentionally LEFT on — it's a paid perk's own grenade economy, not a round power-up.)

Bosses/mini-bosses are unaffected by the buff (`apply_speed_for_round` early-returns for them). Pure GSC — linker-only.

### Fixed — CW guns: invisible reload magazine + checkered detail surfaces (user, 2026-06-26)

Two visual bugs from the Cold War swap, both from over-aggressive asset stripping by `graft_cw_weapon_stats.js`:
- **Reload animated an invisible magazine** (all 4 CW guns). The graft tool blanked EVERY attachment slot to
  kill the AK-47 PaP form's broken optic/laser refs (which point at missing shared `_common` models). But these
  guns' only attachment was `attachViewModel5`/`attachWorldModel5` = the gun's **own** magazine model (installed,
  xmodel asset defined in the gdt) — so the mag got stripped for nothing. New `tools/restore_cw_mag.js` puts the
  mag attachment back (live gdt + `.acc-orig` baseline); the graft strip now KEEPS `_mag_` attachments (only
  optics/lasers stay stripped, since those genuinely crash the load). Twins inherit the attachment from the base.
- **Bullet / case / rail-mount / fast-mag / ammo-link surfaces rendered as the missing-material checker.** The
  BOCW pack shipped the gun-body materials but not these 5 shared attachment-detail materials, so they weren't in
  gdtDB. New `tools/gen_t9_attach_mats.js` defines them by CLONING a working gun material (the AK-47 barrel,
  `lit_weapon` metal) under each missing name → they reuse the barrel's cached techset + metal textures and render
  as gun-metal. gdtDB-only (no zone `material,` line → no techset recompile, avoiding the docs/29 §14 trap).
  **Build is now fully clean — 0 unexpected linker errors** (was 5).

### Changed — Phantom chain-zap slow softened −30% → −25% (user, 2026-06-26)

The Phantom chain-special's on-hit **move slow** is now **−25%** (was −30%): `acc_phantom_slow_mult` default
**`0.70` → `0.75`** in [_acc_utility.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_utility.gsc) `recompute_move_speed`.
Duration (`acc_phantom_slow_sec` 3.0, refreshed on re-hit) and the **Mega Electric Cherry "Power Surge" immunity**
are unchanged. Synced the code comments (`_acc_utility`, `_acc_elites::acc_phantom_chain_zap`, `_acc_boss_phantom`)
and added both slow dvars to [docs/34](docs/34_flags_reference.md) (they were previously undocumented). GSC-only.

### Fixed — Phantom chain special hits each player ONCE (no solo re-chaining) (user, 2026-06-26)

When the Phantom's **player→player CHAIN special** was opened up to fire with 1+ players (so a solo player still
faces the stun), it kept **re-striking the same solo player** for all 3 hops: `phantom_chain()` forced a minimum
of **2 hops** and only avoided the *immediately previous* target, so with one player it just warped onto them
repeatedly. Now the chain **visits each distinct player exactly once** — hop count is capped to the live valid
player count and every hop targets a not-yet-hit player (new `players_not_yet_hit()` helper + a per-chain `hit`
list). **Solo → a single strike** on the lone player (the special still lands its −30% zap once); **coop →** one
hit per player, warping player→player as intended. `acc_phantom_chain_hops` (3) is now the **max**, bounded by
the player count. Comments + [docs/34](docs/34_flags_reference.md) synced. `_acc_boss_phantom.gsc`, GSC-only.

### Changed — CW gun SFX: layered the bass (LFE) into AK-74u/M60/RPD fire (user, 2026-06-26)

The Cold War models ship a per-gun `_lfe` (low-end/boom) wav that the GDT never plays on its own, leaving the
guns thin ("sfx sounded a bit off / not as good"). `gen_cw_box_aliases.js` now sets each gun's `shot_plr/npc`
**Secondary = its `shot_lfe`** so every shot carries the bass (separate freq band → punch, not mud). The AK-47
(hand-authored, already liked) is untouched. **Open diagnostic for the next pass:** the CW fire wavs are long
*start-of-burst* sounds (M60 **1.2s**, RPD 0.76s, AK-74u 0.62s, AK-47 0.86s) played once per bullet at ~0.08-0.1s
cadence → 8-12× overlap on full-auto, which can wash out (the M60 is the worst). If a gun still sounds muddy
after the bass pass, the fix is to tighten that fire wav to a crisp single-shot (the reverb tail comes from the
bus). Tracked by ear with the user.

### Changed — Widow's Wine spider-drops retuned; we now own the whole roll (user, 2026-06-26)

Retuned the blue `ww_grenade` refill-pickup drop on a **webbed-zombie kill**, for BOTH tiers — and the base
needed to go **below** stock (stock is 15/20/25), which a usermap can't do by editing the chances (they're
`#define`s in `_zm_perk_widows_wine.gsc`, base game wins). So we **suppress the stock drop and own the roll**:

| Kill type | Base (was stock 15/20/25) | Mega "Spiderman" (= base +10) |
|---|--:|--:|
| Web-grenade kill | **10%** | **20%** |
| Gun kill | **15%** | **25%** |
| Knife kill | **20%** | **30%** |

Mechanism in [_acc_mega_bottles.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_mega_bottles.gsc): a spawn hook
`mww_suppress_stock_spider_drop` (`callback::on_ai_spawned`) sets `b_widows_wine_no_powerup` on every zombie to
disable the stock auto-drop — that field is **read-only in all of stock** (only `_zm_perk_widows_wine.gsc:313`
reads it; nothing assigns it), so once set at spawn it sticks — and the death hook `mww_spider_drop_roll`
(replaces the old `mww_spider_drop_boost`) does the **single** replacement roll → exact rates, **no double-drops**.
Killer must hold Widow's (base) or active Mega. Live dvars `acc_widow_spider_web_pct` (10) /
`acc_widow_spider_gun_pct` (15) / `acc_widow_spider_knife_pct` (20) / `acc_widow_mega_spider_add_pct` (10);
`acc_widow_spider_custom 0` reverts to stock. Docs: perk_abilities §8 (base + Mega), docs/13 §8, LUI card [8].
GSC-only — fresh `.ff`. (Supersedes the same-day +15pp add-roll; base is now a deliberate slight nerf vs stock.)

### Fixed — 3 regressions from the Cold War gun swap (user, 2026-06-26)

Follow-ups after the AK-74u/M60/RPD CW swap surfaced in playtest:
- **All guns' ammo was un-cut (MK14 etc. buffed).** Re-running `apply_recoil_overhaul` during the swap reverts
  the global 30% ammo cut (documented trap, memory `recoil-tool-reverts-ammo-cut`) and I had not re-run
  `reduce_base_ammo.js` after. Re-ran it (MK14 back to clip 14/12); added `CLIP_FIX` pins for the 4 CW guns
  (`t9_ak47` 21/31, `t9_ak74u` 20/40, `t9_m60` 100/120, `t9_rpd` 75/125) so the cut does **not** re-cut their
  already-correct grafted clips.
- **RPD ADS recoil drifted off-center.** The BOCW models ship ASYMMETRIC / inverted horizontal gun-kick
  (`adsGunKickYaw` RPD +15/-5, M60 +10/-15 inverted, AK-74u +10/-5), which our ×1.75 recoil scaling amplifies
  into a consistent sideways pull. New `tools/symmetrize_cw_recoil.js` centers the yaw (min/max → ∓ the average
  magnitude) in the recoil baseline + live GDT; regenerated. RPD now ±17.5 symmetric. The AK-47 was already
  symmetric (left untouched). Vertical "shoots up" kick is intentional and unchanged.
- **CW guns couldn't be Overclocked while a perk twin was the held form.** `_acc_overclocks.gsc`
  `weapon_name_to_family` classified via `strip_pap_suffix` (get_base_weapon — strips PaP only), so a held
  `_acc_*` perk twin fell through to "weapon not supported." Made it form-invariant via
  `acc_weapon_variants::true_base` (strips the `_acc` twin suffix too), mirroring the tier key.

### Fixed — Electric Cherry machine showed the PACK-A-PUNCH card (10th-perk off-by-one) (user, 2026-06-26)

The real Electric Cherry (the 10th perk, `specialty_combat_efficiency`) displayed the **Pack-a-Punch tier ladder**
instead of its own card. Root cause: when EC was inserted at card index **10**, Pack-a-Punch shifted to **11**, but
the LUI `RenderCard` special-case was still hardcoded `if idx == 10` ([acc_hud.lua](ui/uieditor/menus/hud/acc_hud.lua)),
so the PaP renderer intercepted EC's code (40-42) across all modes — the player saw "Tier 0/3 – re-pack to raise" at
the EC machine. **Fix: `idx == 10` → `idx == 11`** so index 10 falls through to the normal perk-card render. Found via
a 5-agent display audit; the rest of the EC pipeline (owned/Mega masks, perk-bar icon, card-code ranges, card index,
Mega name, jingle, boss-special immunity) all verified correct.

Also corrected, in the same pass:
- **Card wording:** the Mega bullet said **"Bigger, faster zap"**, but the code *deliberately* makes the Mega's
  empty-mag radius **smaller** (`EC_RADIUS_MAX_MEGA` 200 < base 220) — its edge is damage/targets/cooldown. Changed
  to **"Stronger, faster zap"** (card + [docs/13](docs/13_perks.md) + [docs/perk_abilities.md](docs/perk_abilities.md)
  no longer claim a bigger radius).
- **docs/13** all-perks total **27,500 (9 perks) → 30,500 (10)** (Electric Cherry 3,000 was omitted).
- **`apply_mega_effects`** now has an explicit no-op case for `specialty_combat_efficiency` (its Mega is read live),
  silencing a misleading "mega effect pending implementation" log on every Mega EC purchase.
- **`perk_color_index`** EC machine glow made an explicit `return 10` (teal = electric, intentional — no spare colour
  FX) instead of a silent fall-through.
- **Stale comments** in [_acc_boss.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_boss.gsc) that still credited "Mega
  Widow's Wine"/"Jug" for the boss-special immunity → corrected to Mega Electric Cherry (the immunity moved there
  2026-06-25; runtime gate was already correct). LUI + GSC — linker-only repack.

### Changed — AK-74u / M60 / RPD swapped to Cold War (t9) models (user, 2026-06-26)

Following the AK-47 pilot, the last three guns the user wanted on newer models are now Cold War (BOCW, `t9`)
ports — **same gun, new model**: every gameplay stat (damage / RPM / clip / reserve / reload / hit-location
profile / tier / box-odds / PaP price) is GRAFTED from the old BO1/BO2 GDT onto the `t9` GDT by
`tools/graft_cw_weapon_stats.js`, so nothing changes but the model + anims + sounds.
- `t5_ak74u` → `t9_ak74u` (SMG), `t6_m60` → `t9_m60` (LMG), `t6_rpd` → `t9_rpd` (LMG). The AK-74u's old
  irregular `_up_zm` PaP form is gone — `t9_ak74u` uses the regular `_up`, so the `variant_up_name()`
  special-case in [_acc_weapon_variants.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_weapon_variants.gsc) was deleted.
- Every per-gun reference moved to the new name in lockstep (or the value silently regresses with **no build
  error**): the `acc_weapon_balance_mult` scalars in [_acc_damage.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_damage.gsc)
  (incl. the RPD **+25% damage buff** `0.125`), the PaP price buckets + box-rarity weights
  ([_acc_pap_levels.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_pap_levels.gsc) /
  [_acc_map_randomizer.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_map_randomizer.gsc)), the box pool, the
  Overclock + weapon-ability family lists, perk-info indices, the twin roster, and `compute_gun_tiers.js`. The
  RPD's **+25% ammo buff** (clip 75/125, reserve 300/500) rides along in the grafted `clipSize`/`maxAmmo`.
- Twins regenerated by `apply_recoil_overhaul.js` (224 twin lines, name-for-name — twin count unchanged, no
  boot-cap risk). Core SFX (fire / PaP-fire / shot-last / LFE + reload foley) authored 1:1 off the AK-47 alias
  template by the new `tools/gen_cw_box_aliases.js` (built from each gun's actual `t9` foley wavs); the dead old
  `t5/t6` aliases were removed (escaping the known-broken `wpn_t6_m60_pap_shot.wav`).
- **Model compile verified** (the LMG risk): all `.xmodel_bin` sources present install-side; build clean, no
  missing-model errors. The only linker warnings are 5 cosmetic detail-surface materials (bullet / case /
  rail-mount / ammo-link / fast-mag lack a techset on this install) — same class the AK-47 ships with; gun
  bodies render fine.
- Install-side only (`source_data/t9_weapons/wpn_t9_{smg_ak74u,lmg_m60,lmg_rpd}.gdt`, gitignored — **see the
  CREDITS IP gate: these are BOCW game-rip models, the Workshop stays Private until reviewed**). Reversibility
  backups at `*.gdt.acc-preswap`. Discovery + model-compile verification done via a 4-agent workflow.

### Fixed — Brutus randomly died in Paradise after ~30s (spawn-failsafe race + boss-blind purge) (user, 2026-06-26)

Bug: a Brutus in **Paradise** would randomly die if alive too long. Root cause (workflow `brutus-paradise-death-hunt`,
4 scouts + adversarial verify): the **Paradise floor is z=−1200, BELOW the stock `below_world_check` (−1000)**, so the
stock `round_spawn_failsafe` (threaded on every zombie at spawn by `nsz_brutus.gsc`) treats a settled Brutus as
"fallen out of the world" and `DoDamage(health+100)`'s him ~30s in. The immunity flag `ignore_round_spawn_failsafe`
WAS set, but only inside `paradise_warden_think()` — **threaded after spawn + a drop-in retry loop**, so the
failsafe's timer could win the race (the trench Warden avoids this by setting it before its loop). Fixes in
[_acc_paradise.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_paradise.gsc):
- **`maybe_spawn_brutus`** now sets `host.ignore_round_spawn_failsafe = true` **at the spawn frame** (same frame,
  no waits) — closing the race for good.
- **`purge_zombies`** (the battle-start "clean slate") now **skips bosses/mini-bosses** (`acc_is_boss` /
  `acc_is_mini_boss`, same skip `_acc_corpse_cleanup` uses) — it was `DoDamage(health+666)`-ing every live AI with
  no boss filter, so a Brutus alive when the final battle began got purged too.
- GSC-only — linker rebuild, fresh `.ff`.

### Fixed — Bridge anti-camp drain was bleeding the TRENCH (pointed at the wrong structure) (user, 2026-06-26)

The anti-camp drain was bleeding players **in the trench** and never the actual bridge — four attempts (three
z-floor nudges + a dwell band-aid) failed because they all assumed the wrong geometry. **Root cause:** the
detection box was pointed at the **abyss connector** (`gen_abyss_layer.js` chunk C) at **`z=−240` — down in the
pit**, coplanar with the trench floor. But the real camp spot is the **elevated "2x-jump-only" corp trench
BRIDGE** (the `.map` "corp trench BRIDGE" slab / `bridge_v2.js`): `x[−109,147]`, `y[1723,2173]`, **deck top
`z=+58`** — the highest point on the map, **above** ground (`z=0`), reachable only with the double-jump item
(it also holds the two power levers). The box was ~300u too low. **Fix (the user's "use height" call):** the
deck is positive z (above ground) and the whole trench/abyss is negative z, so the detection box is retargeted
to the bridge footprint with a Z window **above ground** (`z 50..178`) — which excludes the entire trench by
elevation. Kept the **dwell gate** (`acc_bridge_dwell_sec`, 2s, resets on step-off) so brief lever-flip /
crossing visits don't bleed; only camping does. `_acc_bus_trench::bridge_drain_watcher`. GSC-only. Doc:
[48_abyss_descent.md](docs/48_abyss_descent.md).

### Fixed — Mega Double Tap (Gun Slinger) card was missing its weapon-swap-speed benefit (user, 2026-06-26)

The in-game perk card for Mega Double Tap ([acc_hud.lua](ui/uieditor/menus/hud/acc_hud.lua), card `[4]`) listed only
"Shoots even faster" — it never told the player the Gun Slinger Mega also **swaps weapons faster**, even though the
`fastfire` twin has granted that the whole time (the swap bullet was deliberately dropped from the card 2026-06-14
but the code feature stayed). Added **"Swap weapons faster"** to both the `mega` (what it adds) and `megaFull` (owned)
bullet lists — qualitative, per the card's no-magnitudes style, under the ~28-char wrap limit.

While verifying (a 6-surface code/UI/docs scan), found the **magnitude was stale in several places**: the canonical
baked value (`tools/apply_recoil_overhaul.js` TWIN_DIMS `fastfire {fire:0.69, swap:0.5}`) is **+45% fire rate / −50%
weapon-swap (≈2× faster)**, but [_acc_mega_bottles.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_mega_bottles.gsc) and
two GDT docs still claimed the pre-retune **"+50% / −75% (≈4×)"**. Corrected to +45% / −50% in `_acc_mega_bottles.gsc`
(code comment), [docs/30](docs/30_perk_gdt_radiant_spec.md), [docs/31](docs/31_ape_perk_gdt_walkthrough.md); added the
missing swap mention to [docs/05](docs/05_weapons.md), [docs/39](docs/39_all_guns_perk_handling_plan.md),
[docs/41](docs/41_weapon_stats_table.md) (which listed Gun Slinger as fire-rate only); marked docs/20
`mega-gun-slinger` **built** and reconciled MISSING_REQUIREMENTS.md. (docs/13 + docs/perk_abilities were already
correct.) LUI rawfile + GSC comment — linker-only repack.

### Changed — Paradise "fetch me their souls" omen replaced with a new wav (user, 2026-06-26)

Swapped the Paradise Phase-2 omen cue (`acc_paradise_omen` → `sound_assets/acc/fx/paradise_omen.wav`) for a
user-supplied recording. Converted 44.1k stereo → **48k/16-bit mono** via `tools/convert_wav_48k_mono.ps1`;
game-closed build rebuilt the `.sabs`/`.sabl` bank (verified mtime moved). No code change — same alias.
**Licensing:** like the 115/Mario tracks, verify this audio is clear before any Workshop publish (CREDITS.md).

### Changed — Mega Widow's Wine crouch speed 2.2× → 2.6× (user, 2026-06-26)

Bumped the Mega Widow's Wine **crouch** low-stance multiplier to **2.6×** (2.2 → 2.4 → 2.6) (`acc_mww_crouch_speed`
default in [_acc_mega_bottles.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_mega_bottles.gsc) `mww_stance_factor`).
Prone (10×) and last-stand/down (15×) are unchanged. Covers all forms (it's a live multiplier on the shared move
scale, applied per-stance via the watcher). Docs synced: [13_perks](docs/13_perks.md), [perk_abilities](docs/perk_abilities.md),
[34_flags_reference](docs/34_flags_reference.md). GSC-only.

### Fixed — Mahem could only be Pack-a-Punched twice (user, 2026-06-26)

The Mahem is an AW projectile **port** (`s1_mahem` → `s1_mahem_up`) and is **not twinned**, so its `_up`
form was never added to `level.zombie_weapons_upgraded` — and the engine didn't map this ported projectile
natively either. Consequence: `is_weapon_upgraded(s1_mahem_up)` was **false** and `get_base_weapon(s1_mahem_up)`
did **not** strip to `s1_mahem`. Our PaP tier is keyed by the true base: tiers 1-2 record at key `s1_mahem`
(held = base), but at tier 3 the held gun is `s1_mahem_up`, which (unmapped) read its tier from key
`s1_mahem_up` (0) — and the `is_weapon_upgraded` clamp that normally bridges that gap also failed. So
`get_tier` returned 0, the pack routed back to the *first*-pack path, found no upgrade to apply, and bailed →
**only two packs landed.** Fix: new `register_special_upgrades()` ([_acc_weapon_variants.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_weapon_variants.gsc))
registers the `_up` form of every non-twinned box gun whose upgrade the engine left unmapped (idempotent —
skips every `_up` that already maps to its base, i.e. all stock guns + the twins). The dev-mode
`[dev] PaP … -> tier N/3` prints are kept so the fix is verifiable in-game (now reaches tier 3/3).

### Fixed — 3 bugs: damage numbers stop, Phantom solo stun, bridge drain under the deck (user, 2026-06-26)

- **Damage numbers randomly stop showing.** The crosshair number only re-draws when `accDmgNum` *changes*; a
  1-bit parity flips so identical-damage hits still pop. But the parity was a **loop-local reset to 0 every time
  the push loop restarted** (the loop self-terminates after ~1s idle). So a player dealing the SAME damage with
  sporadic fire (loop idles between hits) pushed the IDENTICAL value each time → no change → numbers silently
  stopped (self-healed only when damage varied). Fix: persist parity on `self.acc_dmg_parity` so consecutive
  pushes always alternate across loop restarts. [_acc_dev.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_dev.gsc).
- **Phantom chain special never fired solo (no stun in god mode).** The signature player→player CHAIN (which
  applies the −30% slow Phantom-side, so it lands even under god-mode invuln) was gated to `valid.size >= 2`.
  Lowered to **`>= 1`** so it fires at any player count (solo it re-strikes the same target each hop) — testable
  in god mode and a lone camper still faces it. [_acc_boss_phantom.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_boss_phantom.gsc).
- **Bridge anti-camp drain fired UNDER the bridge.** The detection Z window's lower bound (`-244`) caught up to
  4u below the z=-240 deck (walking off the edge / dropping into the pit). Tightened `ACC_BRIDGE_Z_MIN` to
  **`-241`** (keeps standers at -240 with 1u jitter, excludes below-deck). [_acc_bus_trench.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_bus_trench.gsc).

### Changed — PhD slide-explode is now Mega-only (user, 2026-06-26)

Base PhD Flopper no longer detonates when you start a **slide** — that nova is now **PhD Slider (Mega) only**.
Base keeps the explosive/fall immunity + the **explode-when-downed**. Gated in
[_acc_perk_phd_flopper.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_perk_phd_flopper.gsc) `phd_slide_watcher`
on the Mega flag (live dvar `acc_phd_base_slide_nova 1` re-enables it for base). PhD perk card updated
(`acc_hud.lua` [9]: "Slide to explode" moved base→Mega). GSC + LUI — linker rebuild.

### Fixed — Perk docs + code comments realigned to the code (was: +40% RoF / +1.4-1.8 Deadshot / +25% Armory / purple PhD FX / corpse-fling — all stale) (user, 2026-06-26)

The user flagged that they keep having to correct stale perk facts. Did a full code↔docs↔UI sweep and fixed
every drift found (the **code is the source of truth**):
- **Double Tap Mega is +45% RoF, not +40%** — the baked `fastfire` twin is `fireTime ×0.69` (raised from
  ×0.714/+40% on 2026-06-25, [apply_recoil_overhaul.js](tools/apply_recoil_overhaul.js) `fire 0.69`). Fixed
  in perk_abilities.md, docs/13 (×6 spots), docs/39, docs/41, docs/50, and `_acc_weapon_variants.gsc` comments.
- **Deadshot is +1.3 base / +1.5 Mega** (not +1.4/+1.8/+1.6), and **base has NO recoil change** — recoil is
  **Mega-only −50%** via the `recoil50` twin (×0.50 off the **1.75×** map base → ~0.875× vanilla; the old
  recoil25/recoil40 tiers were dropped 2026-06-16). Fixed across docs/05, docs/13 (table + §7 + mechanics +
  ledger + tuning), docs/20, docs/30, and the stale `recoil25/40` comments in `_acc_weapon_variants.gsc`.
- **Headshot temper** corrected to `locHead ×0.5` trash / `×0.6` boss (= ×2.5/×3), not the old ×0.4/×0.5.
- **Mule Armory** is a **+20% reserve REFILL per round** (sustain), not a "+25% capacity" ammo twin (that axis
  was removed 2026-06-16).
- **PhD Flopper FX** is the stock **orange `def_explosion`** (not "purple Apothicon"); the **corpse-fling**
  was removed 2026-06-24 (docs/13 still listed "flings"); Mega is **~0.8× nova / 10s→8s cd / 1.5× slide /
  +15% explosive** (was 2×/8s→5s/+20%/+20%).
- Docs-only except the PhD card (above); `_acc_weapon_variants.gsc` changes are comments only.

### Fixed — SFX spatialization audit: 8 world sounds were 2D (heard map-wide) → 3D positional (user, 2026-06-26)

A full sweep of `sound/aliases/acc_audio.csv` (`PanType` column) + every GSC play site. Eight world SFX were
flagged **`2d`** (no attenuation → full volume for the WHOLE lobby) but are played on an entity/at a position,
so they're now **`3d`** (positional, ~150→1200/1600u falloff):
- **`evt_nuke_flash`** — PhD Slider (Mega) nuke whoomp; also switched the play to `PlaySoundAtPosition(v_burst)`
  at the blast ([_acc_perk_phd_flopper.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_perk_phd_flopper.gsc)).
- **`acc_bottle_pickup`** + **`evt_bottle_dispense`** — the perk/mega-bottle "glass clink".
- **`acc_shard_pickup`** — Data Shard / cache / Exo / perk-slot / Reactor pickups (its code comment already
  *intended* a positional cue; the `2d` flag made it global).
- **`acc_item_implant`** — boss-item bench implant stinger.
- **`acc_overclock_zap`** — Overclock terminal (also **tightened** its falloff `1200/1600 → 600/900u`, user 2026-06-26: keep the overclock zap kiosk-local — audible at the terminal, gone within a room, never across the map).
- **`acc_phantom_zap`** — Phantom chain-zap + Electric Cherry reload nova (also had EMPTY distance columns —
  filled to 150/1200/1600).
- **`evt_perk_deny`** — perk-limit deny buzz.

**Correctly left 2D:** music/announce (`acc_brutus_music`, `acc_ee_song`×3, `acc_main_theme`,
`acc_paradise_calm`/`_music`/`_omen`), ambience (`acc_amb_city_bed`), and `acc_headshot_ding` (already personal —
played via `PlayLocalSound`, only the shooter hears it). All `acc_jingle_*`, `zmb_perks_packa_*`, powerup, soul,
and glitch-warp aliases were already 3D. **Requires a game-CLOSED build** to rebuild the `.sabs` bank (done — the
bank regenerated). Docs: [35_sound_plan.md](docs/35_sound_plan.md).

### Fixed — Perk docs + perk UI realigned to the actual code (10-perk audit) (user, 2026-06-26)

Ran a 10-perk audit (code vs `perk_abilities.md` / `docs/13_perks.md` vs the in-game perk UI) and fixed every
confirmed drift so all three surfaces match the code:
- **Doc — perk count:** `perk_abilities.md` said "9 perks" and was **missing Electric Cherry entirely** → now
  **10 perks**, with a new **§10 Electric Cherry** section (base reload-nova + Mega "Power Surge"), slot cap up to
  **10** (cost 4/6/8/10/12/14), all-perks total **30,500**.
- **Doc — Jugger-Nog & Widow's:** removed the stale **"boss-special immunity"** bullet from both Mega Jug and
  Mega Widow's — it lives on **Mega Electric Cherry "Power Surge"** now (code gates on `specialty_combat_efficiency`).
- **Doc — Deadshot:** corrected to **+1.3 base / +1.5 Mega** headshot (code `ACC_DEADSHOT_MULT 1.3` /
  `ACC_DEADSHOT_MEGA_MULT 1.5`; doc said +1.4/+1.6) and fixed the headshot-temper math (×2.5 trash / ×3 boss).
- **Doc — Double Tap:** fixed the internal cost contradiction (now **3,000**, not 5,000).
- **Doc — PhD Flopper:** FX corrected to the stock **orange `def_explosion`** (was "purple Apothicon burst"),
  removed the stale **"extra flings"** (corpse-fling was removed 2026-06-24).
- **Doc — The Flash / docs/13 ledger:** Mega Flash is **+15% move** (not "longer sprint / +12%"); fixed PhD
  damage (~0.8×, not 2×) and cooldown (10s→8s), Widow's frag/grenade-OHK removed, DT damage layer removed.
- **UI — Electric Cherry was invisible in the perk system:** added its missing cases —
  `acc_overclocks`/`_acc_perk_info::perk_card_index` (`specialty_combat_efficiency` → 10, PaP shifted 10→11),
  `_acc_mega_bottles::mega_display_name` (→ **"Power Surge"**, was falling through to "Mega Perk"), and a new
  **Electric Cherry card** in `acc_hud.lua` (PaP shifted to [11]); fixed the Widow's card (immunity → low-stance
  speed). GSC + LUI — linker rebuild, fresh `.ff`. **In-game load-verify is pending** (the Steam launcher jammed
  after a force-kill; the LUI edit is a well-formed addition to an already-loading file).

### Fixed — Paradise PhD Flopper machine showed the Stamin-Up model (user, 2026-06-26)

PhD Flopper hijacks the stock electric-cherry pipeline, whose placeholder `perk_machine_set_kvps` names the
machine `vending_marathon` (**Stamin-Up's** identity). `fix_machine_identity()` in
[_acc_perk_phd_flopper.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_perk_phd_flopper.gsc) repointed only the
**first** PhD machine it found — so the **Paradise duplicate** (gen_paradise_props `.map` struct) kept the
Stamin-Up identity/model. Now it fixes **every** PhD machine (Lab + Paradise): repoints each to
`vending_electriccherry` and force-sets the correct `p7_zm_vending_nuke` model. Pure GSC — linker-only.

### Changed — Action Figure PaP cleave is now probabilistic (nerf) (user, 2026-06-26)

The Action Figure's per-swing cleave (extra zombies one-knifed beyond the primary) is now **rolled from its PaP
tier** instead of a flat `1+tier` ([_acc_damage.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_damage.gsc)
`actionfigure_cleave_count`). "Hit N" = 1 primary + (N-1) cleaved:
**T1** 50% hit 1 / 50% hit 2; **T2** 25%/50%/25% hit 1/2/3; **T3** 50% hit 2 / 50% hit 3 (was T1→2, T2→3, T3→4
always). Base (un-PaP'd) still one-knifes exactly 1. Pure GSC — linker-only.

### Changed — Paradise anti-camp is now NATURAL: zombies that survive buff themselves L3→L4→L5 (user, 2026-06-26) — SUPERSEDED same day by the holistic horde buff (top of Unreleased)

**Reverted** the first-pass anti-camp (an artificial `MOD_UNKNOWN` health "pulse" on players who killed < 6/20s —
it felt like a game-master punishing you) and replaced it with an **emergent** one
([_acc_zombie_speed.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_zombie_speed.gsc) `paradise_buff_layer`): every
Paradise **battle** zombie now spawns at the **L3 trench buff** and climbs **+1 trench layer every 30s it stays
ALIVE**, capped at **L5** (`L3 → L4 @30s → L5 @60s`). That layer feeds the SAME per-layer **speed**
(`+acc_trench_layer_speed_pct%`/layer) **and health** (`apply_trench_health`, `+acc_trench_layer_hp_pct%`/layer,
one-way — it ADDS armor, never heals), so **a zombie you DON'T kill gets faster AND tankier the longer it lives**.
Kiting the horde instead of clearing it organically makes the survivors deadlier — no script tax on the player.
Mechanism: `trench_layer_for_zombie` substitutes the ramped layer in Paradise (excluded from `underground_layer`),
so the whole trench treatment applies automatically via the 1.5s speed keepalive; `t0` (first-seen) is recorded
lazily per actor ≈ spawn. **Replaces** the old fixed "L5 from battle start" speed parity. 0 (base) during the
calm/dread entry. Live dvars `acc_paradise_buff_start` / `_max` / `_buff_step_sec`. Pure GSC — linker-only.
Note: health now scales (L3 = +150%, L5 = +250% at the default `acc_trench_layer_hp_pct` 50) — that pct is SHARED
with the real trench, so retune there if survivors feel too spongey.

### Fixed — Paladin HB50 headshot did LESS than a body shot (user, 2026-06-26)

The `gun_maxscale_table` surfaced it: the BO4-port Paladin GDT ships **`locHead`/`locHelmet` 1.0**, so with the
map's ×0.5 headshot temper a Paladin headshot dealt **0.5× body** (backwards). Every other non-shotgun is
`locHead 5.0` (→ the intended **2.5× body**); MORS, the other sniper, was already correct. Set the Paladin to
**5.0** across base + `_up` + all 14 twins via `tools/fix_paladin_loc.js` (targeted — does **not** touch the
headshot-excluded shotguns). Headshot now **13,475 vs 5,390 body** (was 2,695). Also patched the gun's
`.acc-orig` backup so a future `apply_recoil` run won't revert it (the recurring loc-revert ordering gotcha).
GDT-only relink; fresh `.ff`. Doc: [41](docs/41_weapon_stats_table.md).

### Changed — Shotgun max-scale damage nerf: Tac-19 −10%, Olympia −50% (user, 2026-06-25)

New `tools/gun_maxscale_table.js` (per-gun damage-per-shot / -headshot / DPS at **full PaP T3 + Weapon Overclock
T10** — the ceiling where outliers show) surfaced the shotguns as wild outliers: at max scale the 12-pellet stack ×
the ×4 PaP+OC bonus made **Olympia ~33k/shot, ~100k/headshot — 6–18× every other gun** (Tac-19 ~19k/shot). Fixed
at the damage level via `acc_weapon_balance_mult`:
- **Tac-19** ×0.68 → **0.612** (−10%). PaP score 8.11 → **7.60** (S → A, still TOP price tier, #6).
- **Olympia** ×0.9775 → **0.489** (−50%, the near-uncut mult was the root cause). PaP score 5.21 → **3.67** (still C/BOT).
- Synced `compute_gun_tiers.js` `e` (613→552, 525→263) → regenerated [docs/54](docs/54_pap_pricing_tiers.md) +
  `pap_price_bucket`/`acc_box_weight` (no tier/price/box-weight changes — both stayed in their tiers). GSC-only.
  The remaining auto-gun band (1.1k–2.5k/head, ~7–15k DPS) is healthy and untouched. Doc: [41](docs/41_weapon_stats_table.md).

### Fixed — Phantom chain-special slow now lands in GOD MODE (for speed testing) (user, 2026-06-25)

The Phantom's player→player CHAIN special applies a brief −30% move slow, but it rode on the player-damage
callback (`_acc_elites::on_player_damaged`), which **god mode suppresses** — `acc_god_watch` uses engine
`EnableInvulnerability()`, so the damage event (and its `if ( iDamage <= 0 ) return -1` gate) never fires, and the
slow never applied while invulnerable. So you couldn't feel/tune the slow in god mode. Fix: the chain slow is now
applied from the **Phantom side** in [_acc_boss_phantom.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_boss_phantom.gsc)
`phantom_chain` — on each chain hop's blink-strike, if the target is within melee range it calls
`acc_elites::acc_phantom_chain_zap()` directly (independent of damage), so the stun lands even under
invulnerability. Removed the now-redundant `on_player_damaged` chain path (avoids double-applying in normal play);
Mega Electric Cherry immunity is still honored inside the zap. Tune with `acc_phantom_slow_sec` (slow duration) +
`acc_phantom_speed_mult` (the Phantom's own gait). Pure GSC — linker-only.

### Changed — Mega Widow's low-stance speeds retuned + downed-player crawl-speed fix (user, 2026-06-25)

Retuned the Mega Widow's "Spider-mobility while low" multipliers and fixed the bug where a **downed** holder
never got the crawl speed (going down strips the perk, so the live `HasPerk` check failed). In
[_acc_mega_bottles.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_mega_bottles.gsc) +
[_acc_utility.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_utility.gsc):
- **Multipliers:** crouch **×3 → ×2.2**, prone **×5 → ×10**, last-stand/downed **×8 → ×15** (`acc_mww_crouch_speed`
  / `_prone_speed` / `_down_speed`).
- **Cap raised** `acc_mww_speed_cap` **10 → 16** so the ×15 down (and ×10 prone) aren't clamped.
- **Down-ownership snapshot (the fix the user asked for):** the stance watcher now records legit ownership
  every tick *while up* (when `HasPerk` is reliable) into `player.acc_mww_down_owner`, and `mww_stance_factor`'s
  last-stand branch gates the ×15 on that **snapshot** instead of the live perk check. So a player who held
  Mega Widow's keeps the crawl speed through the entire bleed-out even though the engine reports the perk as
  lost the instant they go down. Snapshot is cleared on genuine loss-while-up and on respawn.
- GSC-only — linker rebuild, fresh `.ff`. perk_abilities.md updated. *(Caveat unchanged: the ×15 down assumes
  the engine applies `SetMoveSpeedScale` to the laststand crawl — crouch/prone are solid; verify the down rate
  in-game.)*

### Changed — Paradise finale: spawn lockdown (all down low), base→L5 speed, more shields (user, 2026-06-25)

Four tuning fixes to the Paradise final battle ([_acc_paradise.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_paradise.gsc),
[_acc_zombie_speed.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_zombie_speed.gsc)):

- **All zombies spawn DOWN LOW in Paradise (no more topside spawns).** `start_battle` now
  `flag::clear("spawn_zombies")` (dvar `acc_paradise_spawn_lockdown`, default 1), which pauses the STOCK round
  spawn manager (it blocks on that flag, `_zm.gsc:3753`) — so no zombies erupt from the surface/abyss zones
  (which the re-sealed gate would strand up top) and the round freezes (`zombie_total` never drains). The
  Paradise onslaught force-spawns (`spawn_zombie` direct) bypass the flag, so Paradise risers become the SOLE
  spawn source.
- **Base speed on entry, L5 speed once the battle starts.** `paradise_speed_layer` now returns 0 (base) until
  `level.acc_paradise_onslaught` is set, then feeds the **L5** virtual speed layer (`ACC_PARADISE_SPEED_LAYER`
  **3 → 5**, dvar `acc_paradise_speed_layer`). So Paradise feels calm/normal on arrival and ramps to "trench L5
  floor" run speed for the fight. SPEED only — health stays base (no bullet sponges; the pressure is volume).
- **More Shielded "Riot" elites during the fight.** `ACC_PARADISE_SHIELD_PER_WAVE_DEF` **1 → 3**,
  `ACC_PARADISE_SPECIAL_INTERVAL_DEF` **15 → 10s**, `ACC_PARADISE_SPECIAL_MAX_DEF` **8 → 12** (all live dvars).
- **Door re-locks at battle start** — already handled by `seal_arena()` (re-seals `acc_abyss_hub_door`,
  `acc_paradise_seal` default 1); no change needed.
- **Stragglers are teleported in.** New `gather_stragglers()` (called from `start_battle` after `seal_arena`)
  `SetOrigin`s every live player (incl. downed, so they can be revived) who is NOT already in the plaza to a
  validated Paradise floor spot — nobody gets left behind / stranded up top by the sealing gate. Anchor = a
  teammate already in the plaza, else the nav-snapped plaza centre `(0,-1300,-1200)`; small ring offset so they
  don't stack. Live toggle `acc_paradise_gather_in` (default 1). Pure GSC — linker-only.

### Changed — Phantom spawns every 4 rounds in DEV mode (every 8 in base game) (user, 2026-06-25)

`cadence_hits()` in [_acc_boss_phantom.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_boss_phantom.gsc) now branches
on `level.acc_dev`: dev mode spawns the Phantom every **4** rounds (4, 8, 12, …) for faster testing; the base game
is unchanged at every **8** (8, 16, 24, …). Hardcoded off the single dev flag (no new toggle — dev-mode rule); the
`acc_phantom_first_round` / `acc_phantom_interval` dvars still override either default for live tuning. Doc:
[34_flags_reference.md](docs/34_flags_reference.md). Pure GSC — linker-only.

### Added — Chicom CQB box gun (BO2 burst SMG), fully twinned, tuned to S+ #2 (user, 2026-06-25)

New **16th box gun**: the **Chicom CQB** (`t6_chicom_cqb`, Skye BO2 port) — a 3-round-burst SMG (PaP = 4-round
"Auto Burst"). Added across all 10 integration points + the 3 generator tools, fully **twinned** (the Mega-perk
recoil/fire-rate/reload variants) and tuned to be a **top-3, S+ gun players want to run**:
- **Stats → S+ #2.** `acc_weapon_balance_mult` **×0.25** (~497 honest sustained eff DPS after the 0.1s inter-burst
  delay) + **uncut** generous ammo (clip 36/56, reserve 180/448). `tools/compute_gun_tiers.js` scores its PaP form
  **8.05 → Rank #2, S tier** (just under Tac-19 8.11, above M60 7.97) → **TOP** price tier (5000/7500/10000) and
  **~2.4% rare box roll** (weight 12). Base form ranks #2 A-tier (7.64). Regenerated [docs/54](docs/54_pap_pricing_tiers.md)
  + the `pap_price_bucket`/`acc_box_weight` GSC.
- **Fully twinned (224 twins total).** Added to `apply_recoil_overhaul.js` GUNS + `variant_guns()` + the zone twin
  block (16 guns × 14 = **224**, ~6 under the ~230 boot-proven cap — **boot-test before any 17th twinned gun**).
  Pinned the twin clip to the native **36/56** in `reduce_base_ammo.js` (`CLIP_FIX`) so a perk twin never shrinks
  the mag. Loc normalized (head ×5.0 = 2.5× body) via `normalize_gun_loc.js`.
- **SFX wired + verified.** `gen_box_weapon_sounds.js` gained a `dir` override (the Chicom's disk folder
  `t6_chicom_cqb` differs from its alias prefix `t6_chicomcqb`); emits fire + PaP-fire + 4 foley (bolt/mag) aliases
  → the loaded sound bank **`.sabl` grew 33.04 → 33.28 MB**, errorlog sound-clean. Wavs are stock-format 48k/16-bit.
- **Wiring:** CSV row (smg, 1300), zone `weapon,`/`weaponfull,` lines, box pool, **Whirlwind** SMG ability, SMG
  Overclock family. GSC-only build (no geometry) — fresh `.ff` 45.91 MB. Docs: [05](docs/05_weapons.md) /
  [41](docs/41_weapon_stats_table.md) / [54](docs/54_pap_pricing_tiers.md). **In-game boot/test pending** (the
  twin-cap failure is a silent AV — a clean build is not proof; verify it loads + the gun fires/PaPs/sounds).

### Added — Anti-camp health drain on the zombie-unreachable bus-trench bridge (user, 2026-06-25)

The abyss-L1 **bridge** (the `z=−240` floor strip at `x[−112,112] y[1851,2173]` that bridges the west/east pit
chunks over the descent well) is reachable with the **Rocket Shield** jump but **zombies can't path onto it** —
a free safe-camp. New `acc_bus_trench::bridge_drain_watcher` (per-player, started from `watch_connections`)
bleeds **15% of max health every second** while a player stands on it, with a red **"GET OFF THE BRIDGE"**
prompt. Implementation notes:
- **MOD_UNKNOWN** (not `MOD_FALLING`) so **PhD Flopper does NOT negate it** — unlike the fall tax, this drain
  must always apply. Guarded by `zm_utility::is_player_valid` (stops cleanly when downed; resumes on revive);
  `DoDamage` routes through the stock laststand pipeline if it downs you.
- **Detection = XY box + a TWO-SIDED Z window** `[−244,−160]`. The upper Z bound is the whole point: a one-sided
  "feet z above −240" test false-positives on the corp **surface** (the north lip has feet `z=0`). Bounds are the
  adversarially-verified safe set (workflow `bridge-anticamp-research`): bridge stander (`−240`) & bunny-hop apex
  (`~−195`) caught; corp-surface player (`0`) & stair-descender (`−256`) NOT caught.
- Live dvars: `acc_bridge_drain_on` (1), `acc_bridge_drain_pct` (15), `acc_bridge_drain_sec` (1.0). GSC-only —
  linker rebuild, fresh `.ff`. docs/48 updated.

### Changed — Overclock shield-pierce per-tier 0.20 → 0.05 (no more full bypass / weak-point) (user, 2026-06-25)

`ACC_OC_PIERCE_PER_TIER` (dvar `acc_oc_pierce_per_tier`) in
[_acc_damage.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_damage.gsc) cut **0.20 → 0.05** per Overclock tier.
The Shielded "Riot" elite's front still takes **25%** base; the pierce now lerps it **`front = 0.25 + 0.75 ×
0.05 × tier`** = **25% (T0) → 43.75% (T5) → 62.5% (T10)** — a clean **+3.75 pts/tier**. Max pierce at T10 is
0.50 (≪ 1.0), so it is now a **partial** restore: **no full bypass, no over-100% weak point** (the old 0.20/tier hit
full bypass at T5 and ~175% from the front at T10). Flanking / explosives / side-melee remain the primary
counters. GUN frontal hits only (melee `oc_tier` is 0); side/back unaffected. Docs:
[11_enemies.md](docs/11_enemies.md), [46_trench_systems_guide.md](docs/46_trench_systems_guide.md). Pure GSC —
linker-only.

### Added — Teddy-bear JUKEBOX (3 bears, order-priced) + single MUSIC CHANNEL override (user, 2026-06-25)

The lone trench teddy bear is now a **3-bear jukebox** and a global **single-music-channel** rule stops songs
overlapping.

- **Three bears** in the NORTH trench under-room ([_acc_ee_song.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_ee_song.gsc)):
  the original CENTER bear (Lilex "Cyber Dreams") now flanked by a LEFT and RIGHT bear at x=±140 (y=2430, z=-240),
  each its own song. All GSC-spawned — no geometry/LED.
- **Order-based price** (was free): the **1st** song you play (any bear) costs **500**, the **2nd 1000**, the
  **3rd 15000** points — charged to the triggering player, keyed to trigger order, any order allowed. Dvars
  `acc_ee_song_cost_1/_2/_3`.
- **5-minute global cooldown** between triggers (`acc_ee_song_cooldown`, 300s) so a song plays out before the
  next can start; the un-played bears' hints show the live price or "Jukebox busy".
- **Two new songs** added + converted to 48k mono ([convert_wav_48k_mono.ps1](tools/convert_wav_48k_mono.ps1)):
  `acc_ee_song_2` = "the mountain – Cyber Security" (Pixabay #144111, LEFT), `acc_ee_song_3` = "I Really Want to
  Stay at Your House" (Rosa Walton / Cyberpunk Edgerunners, RIGHT). New aliases in
  [acc_audio.csv](sound/aliases/acc_audio.csv); banked via a game-closed build. **LICENSING:** ee_song_3 is
  **copyrighted — TEST-ONLY, 🚫 do not publish**; ee_song_2 is Pixabay (⚠️ verify). See [CREDITS.md](CREDITS.md).
- **Single MUSIC CHANNEL** — new [_acc_music.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_music.gsc): every song
  source (main theme, boss music, the jukebox, Paradise calm/115) now routes through `acc_music::play()`, which
  **stops whatever song is playing and starts the new one** so two never overlap ("play the last one triggered").
  E.g. trigger a teddy-bear song while fighting the Phantom → the boss music stops and only the bear song plays.
  PERK JINGLES and the ambient city bed are deliberately NOT routed (SFX/ambience, meant to layer under music).
  Boss music's stop is gated (`stop_if`) so a teddy song that overrode it mid-fight isn't yanked when the boss
  dies. The channel owns its emitter (a one-shot uses the proven reach-all `PlaySoundWithNotify` idiom, a loop
  uses `PlayLoopSound`), so it can stop a song — which `zm_utility::play_sound_2D`'s internal temp ent could not.
  Pure GSC + 2 sound aliases; linker rebuilds the `.sabs` (game-closed). New module wired in the `.zone` + `_acc_main`.

### Fixed — Removed the invisible Lab overclock machine (overclock is TRENCH-ONLY) (user, 2026-06-25)

Bug: you could overclock weapons in the **Lab** at an invisible (model-less) machine — overclocking is meant
to be an underground RISK. Root cause: a stray map-placed `trigger_use` targetname `acc_overclock_terminal`
in the Lab (emitted long ago by `tools/gen_interactives.js`, "Lab east"); `acc_overclocks::watch_terminal_trigger`
wires up *any* such trigger, and it had no kiosk model → invisible. The intended terminals are script-spawned
underground by `_acc_glitch_altar` via `spawn_terminal_at` (which calls `terminal_loop` directly, not through
`watch_terminal_trigger`). Fix:
- **GSC guard** (the live fix) in [_acc_overclocks.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_overclocks.gsc)
  `watch_terminal_trigger`: ignore any map-placed `acc_overclock_terminal` that is **not underground**
  (`acc_bus_trench::underground_layer(origin) <= 0`). Above-ground = skipped; the Lab terminal is dead.
- **Source removal**: deleted the entity from [the .map](map_source/zm/zm_abandoned_cyber_city.map) and
  commented the emitter line in [gen_interactives.js](tools/gen_interactives.js) so it can't come back on a
  full rebuild.
- Build: first shipped **GSC-only** because the LED bake was transiently crashing on unrelated WIP geometry;
  once the bake recovered (re-checked: **BAKED** 15.2s) a **FULL build** (cod2map64 + LED + linker) landed the
  `.map` deletion at the **BSP level** with **fresh lighting** — fresh `.ff` 45.71 MB. The GSC guard now stands
  as a permanent safety net (no above-ground overclock terminal can ever wire up, even if one is re-added).

> Note: the `brush.cpp:1860` LED-bake crash seen mid-task was **pre-existing** (verified: it crashed even with
> this change reverted) and has since cleared — the full build above baked clean. Not caused by this change.

### Changed — Soul-door costs are per-layer AND scale with player count (user, 2026-06-25)

`souls_needed(layer)` in [_acc_abyss_doors.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_abyss_doors.gsc) now takes
the gate's layer **and multiplies a per-player base by `GetPlayers().size`**: the **first descent gate** (layer 1 /
the trench, where everyone roams early) needs **125 souls/player**; every **deeper gate** needs **50/player** — so
**125/50 solo up to 500/200 at a full 4-player lobby** (was a flat 150 for all). Evaluated **live**, so the per-kill
bank check auto-rescales if a player dis/connects (the floating hint, set once at door creation, captures the
starting count; the live check is the source of truth). Tuning dvars `acc_soul_door_cost_first` (125/player) +
`acc_soul_door_cost` (50/player); dev mode stays a cheap flat 10. Both callers (the soul-box hint + the per-kill
bank check) pass the matched door's layer. Doc: [48_abyss_descent.md](docs/48_abyss_descent.md). Pure GSC — linker-only.

### Changed — S-tier guns (Tac-19 / M60 / PPSH-41) box odds → ~2% (box odds only) (user, 2026-06-25)

The three remaining S-tier guns (Tac-19, M60, PPSH-41 — AK-74u was already moved to MID) pinned to box weight
**10 (~2.04% real per spin**, was ~2.4% at weight 12) via `boxForce` in
[compute_gun_tiers.js](tools/compute_gun_tiers.js). MORS (A-tier) stays at weight 12. **PaP prices unchanged**
(all stay TOP, 5000/7500/10000) — box rarity only. Regenerated [54_pap_pricing_tiers.md](docs/54_pap_pricing_tiers.md)
+ the GENERATED `acc_box_weight` block. Pool total weight 488 → 482. Pure GSC — linker-only rebuild.

### Changed — AK-74u + MK14 moved to the MID box tier (box odds only) (user, 2026-06-25)

Mystery-box **rarity** only — PaP prices deliberately left alone. AK-74u (box weight 12 → **29**, ~2.4% → ~5.9%,
more common) and MK14 (box weight 50 → **29**, ~10% → ~5.9%, rarer) both pinned to the MID box tier. Done via a
new `boxForce` override in [compute_gun_tiers.js](tools/compute_gun_tiers.js) (decouples box rarity from the PaP
price tier, same as the specials already do — Action Figure is TOP price / box 5). Regenerated
[54_pap_pricing_tiers.md](docs/54_pap_pricing_tiers.md) + the GENERATED `acc_box_weight` block in
[_acc_map_randomizer.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_map_randomizer.gsc). Pool total weight 492 → 488.
**PaP prices unchanged:** AK-74u stays TOP (5000/7500/10000), MK14 stays BOT (3000/4500/6000). Pure GSC — linker-only rebuild.

### Changed — Trench Data Caches now give 3 shards each (was 2) (user, 2026-06-25)

The two pit **Data Caches** (the "shard stores") now yield **3** shards each per round instead of 2 —
`acc_cache_w_count` / `acc_cache_e_count` defaults **2 → 3** in
[_acc_glitch_altar.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_glitch_altar.gsc). Faster faucet; still
once-per-round, first-come, one-cache-per-player in co-op. GSC-only — linker rebuild, fresh `.ff` (45.71 MB).
docs/46 + the docs/57 player guide updated to match.

### Changed — Reactor Surge "scary pass": 5 waves + ~30% more aggressive + more armor (user, 2026-06-25)

The user wanted the **Reactor Surge** to feel like something you might *not* want to start. Retuned the
defaults in [_acc_reactor.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_reactor.gsc):
- **Waves 3 → 5** (`ACC_REACTOR_WAVES_DEF`) — a longer gauntlet.
- **Zombies per wave 10 → 13** (`ACC_REACTOR_WAVE_COUNT_DEF`, +30% aggression).
- **Wave interval 3.0s → 2.1s** (`ACC_REACTOR_WAVE_INTERVAL_DEF`, ~30% faster spawn-in).
- **Shielded ("Riot") armor elites 2 → 3 per wave** (`ACC_REACTOR_SHIELDED_PER_WAVE_DEF`).
- Glitch Stalkers unchanged at 1/wave; reward (5 shards + Insta-Kill) and the 3-round cooldown unchanged.

All values stay live dvars (`acc_reactor_waves` / `_wave_count` / `_wave_interval` / `_shielded_per_wave`).
The busy-watchdog ceiling reads the dvars, so it auto-scales to the longer surge. GSC-only — linker rebuild,
fresh `.ff` packed (45.71 MB). docs/46 updated to match.

### Changed — Abyss descent soul boxes 100 → 150 souls per door (user, 2026-06-25)

Each of the 4 abyss descent gates (`acc_abyss_door_1..4`, the trench soul boxes in
[_acc_abyss_doors.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_abyss_doors.gsc)) now requires **150** banked
souls (kills on that door's layer) to open, up from 100 — `#define ACC_SOUL_DOOR_COST 150`, surfaced via
`souls_needed()` and overridable by the `acc_soul_door_cost` dvar (default now 150; dev mode still 10 for quick
testing). The constant hint reads `[bank 150 souls]` automatically. GSC-only — `-GscOnly` build (no geometry
touched). Doc: [48_abyss_descent.md](docs/48_abyss_descent.md).

### Added — New-player guide (docs/57), code-aligned (user, 2026-06-25)

Shareable, newcomer-facing **player guide** at [57_player_guide.md](docs/57_player_guide.md): a 5-minute
read covering the two currencies, the gun **tier/PaP-cost/box-odds** table (Base vs Packed letter tiers, the
3-level PaP costs, and ~roll% — all pulled from `tools/compute_gun_tiers.js` / docs/54), the **Exo Suit** and
**Weapon Overclock** (why they exist, what each tier does, and the **4 × tier → 220-to-max** cost ladders,
verified against `_acc_exo.gsc::exo_cost` + `_acc_overclocks.gsc` `ACC_TIER_COST_*`), and **how the Trench
works** (layers/amping, Shard sources, the spend sinks). Numbers reconciled against current GSC where
docs/46 was stale (Shard cap **500** not 50; Exo/OC cost **4 × tier, 10 tiers**; perk slots up to **10**,
cost 4/6/8/10/12/14; Trench Warden **+3**). Doc-only — no build needed.

### Fixed — Box-tactical data + docs reconciliation (odds UNCHANGED at 1% / 0.5%) (user, 2026-06-25)

Triggered by a "I never see Monkey Bomb / Li'l Arnie in the box" report. The Cymbal Monkey (`cymbal_monkey`)
and Li'l Arnie (`octobomb`) are mystery-box tactical **pre-rolls** (not in the gun pool, not boss items since
2026-06-24). Their odds are **kept at Monkey Bomb 1% / Li'l Arnie 0.5%** (combined 1.5%) — an odds bump was
tried and reverted at the user's request. Two non-odds fixes remain:
- **Latent data inconsistency fixed:** both tacticals had `in_box = FALSE` in
  [zm_levelcommon_weapons.csv](gamedata/weapons/zm/zm_levelcommon_weapons.csv) even though the box requires
  `in_box = TRUE` (stock `treasure_chest_CanPlayerReceiveWeapon` rejects `in_box=FALSE` outright). The runtime
  `register_mystery_box_pool` already flips them TRUE at load, so this is belt-and-suspenders, but the source
  data now matches intent.
- **Docs reconciled:** [12_boss_items.md](docs/12_boss_items.md) still listed the two grenades as boss items
  #2/#6 in an "8 items" table — corrected to the real **6-item** pool with renumbered IDs and a note that the
  grenades are now box rolls. CSV+GSC — linker-only rebuild.

### Changed — Phantom now spawns every 8 rounds (user, 2026-06-25)

`ACC_PHANTOM_FIRST_ROUND_DEF` **10 → 8** and `ACC_PHANTOM_INTERVAL_DEF` **10 → 8** in
[_acc_boss_phantom.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_boss_phantom.gsc) — the Phantom now first appears
at round **8**, then every **8** rounds (8, 16, 24, …). Both are still live dvars (`acc_phantom_first_round` /
`acc_phantom_interval`). Doc: [34_flags_reference.md](docs/34_flags_reference.md). Pure GSC — linker-only.

### Fixed — Phantom spawn made FULLPROOF + decoupled from the purge; purge auto-shuts-down after 2 rounds (user, 2026-06-25)

Robust fixes for the recurring "Phantom never spawned" (a jammed purge stopped it for the whole match — "I can't
even test the Phantom in real gameplay") + "died in the purge and the door never reopened" reports:

- **Fullproof Phantom spawn (owed-flag director).** Rebuilt the Phantom scheduler in
  [_acc_boss_phantom.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_boss_phantom.gsc) into two halves: `round_watch`
  only DECIDES whether a Phantom is due (`phantom_round_is_due`) and raises a `level.acc_phantom_owed` flag — it
  never spawns, so nothing can block it. A new persistent `phantom_director` is the SINGLE spawner: while a
  Phantom is owed and none is alive, it RETRIES the spawn every few seconds, across rounds, until one actually
  exists. The owed flag clears only when a Phantom is alive or a spawn succeeds, so the boss can never be
  permanently suppressed. Removed the old `if ( isdefined( level.acc_ldc_active ) ) return;` purge gate AND the
  deferred `pending_watch` machinery — the director reads nothing about the purge. A jammed purge that saturates
  the engine actor pool can now at most DELAY the Phantom a few seconds (the director retries), never drop it.
  `run_round_boss` lost its `endon`s so the director can call it inline without being torn down at round end.
- **Round-cap auto-shutdown (progress-aware).** `commit_challenge` captures `level.acc_ldc_start_round`; a new
  `ldc_round_cap_watch` force-calls a new `challenge_timeout` (clean teardown, no reward, +cooldown gate). Two
  tiers so it never robs a legitimately-winning fight: a SOFT cap (`acc_lockdown_challenge_max_rounds`, default
  **2**) fires only if the purge made no kill in the round that just ended (genuinely stalled), and a HARD cap
  (soft + `acc_lockdown_challenge_hard_grace`, default 2+4=**6**) fires unconditionally as the absolute
  anti-softlock backstop. Guaranteed escape valve for every stuck purge; a purge can never hold the room sealed
  past the cap. Doc: [43_lockdown_challenge_room.md](docs/43_lockdown_challenge_room.md). Pure GSC — linker-only.

### Fixed — Glitch Purge death/resolve hardening (multi-agent audit, 2026-06-25)

A 40-agent adversarial audit of the purge subsystem confirmed the headline "died in the purge, door never opened"
was a *premature abort*, plus several edge cases. Fixes in
[_acc_lockdown_challenge.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_lockdown_challenge.gsc) +
[_acc_lockdown.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_lockdown.gsc):

- **`watch_fail` laststand grace (the real headline fix).** It called `is_player_valid( p )` with no 3rd arg, so
  the instant the only inside player hit laststand it tore the whole purge down (culling every glitch, no reward)
  even with Quick Revive self-rezzing 2.5s later. Now: a downed-but-inside player keeps the purge alive when
  there's no outside teammate to rescue them (solo self-revive / inside-revive), but with an outside rescuer
  available the door unseals so they can come in — `is_player_valid( p, false, true )` (ignore-laststand) drives
  it. Preserves the load-bearing "respawned-outside doesn't keep it sealed" invariant. Also **debounced** to 2
  consecutive polls so a sub-second doorway-clip during the seal can't false-abort.
- **Met-count always wins.** `challenge_fail`/`challenge_timeout` now redirect to `challenge_clear` if
  `acc_ldc_killed >= total`, so a final kill on the same frame as a down/timeout never forfeits the reward.
- **Fail cooldown.** `challenge_fail` now passes the round to `on_defcon_failed`, which gates the next DEFCON to
  `acc_lockdown_fail_cooldown` (default **1**) — a wiped party gets ≥1 DEFCON-free round (was zero).
- **`on_end_game_safety` now unseals** the doors too (was: restored spawning only, contradicting its comment).
- Phantom comments corrected (stock `spawn_zombie` BLOCKS on a saturated pool, it doesn't fail). Pure GSC — linker-only.

### Changed — Action Figure mystery-box odds ~2.4% → ~1% (user, 2026-06-25)

Action Figure (`t8_melee_figure`) pulled out of the box weight-12 group into its own **weight 5** in
`acc_box_weight` ([_acc_map_randomizer.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_map_randomizer.gsc)) —
~2.4% → **~1.0%** (pool total weight 499 → 492; it's now the rarest roll after the Thundergun). Driven through
the generator: edited the `SPECIALS` box override in [compute_gun_tiers.js](tools/compute_gun_tiers.js)
(`box: 5`) and regenerated [54_pap_pricing_tiers.md](docs/54_pap_pricing_tiers.md) + the GENERATED GSC block.
Its **PaP price tier is unchanged** (still TOP / S-tier) — only box rarity dropped. The other guns' odds shift
trivially (denominator 499 → 492). Pure GSC — linker-only rebuild.

### Fixed — `BG_Cache ... Exceeded '250' items for type 'triggerstring'` crash near the soul boxes (user, 2026-06-25)

Recurring hard error `BG_Cache_GetIndexInternal - Exceeded '250' items for type 'triggerstring'`,
reproduced **twice around round ~18-20, both times by the abyss SOUL BOXES** (user-confirmed). The engine
caps the **`triggerstring` BG-cache at 250 UNIQUE strings for the whole match** — *every distinct string
ever passed to `SetHintString` permanently burns one slot* (never freed; shared with stock + `#precache`).
A multi-agent audit of all ~51 modules found **two** new-2026-06-25 per-event accumulators, both in
[_acc_abyss_doors.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_abyss_doors.gsc):

1. **THE crash — `soul_update_hint`:** the SOUL BOX hint embedded the **live per-kill counter**
   `door.acc_souls` and was re-set on **every underground soul-banking kill**, minting a new unique string
   per soul (`0..souls_needed()` = up to **100 per layer door**, × multiple layers). Grinding souls
   underground to test the descent overran the cap → CTD. Fix: drop `door.acc_souls` from the hint (show
   only the fixed `souls_needed()` goal) → a **constant** string set once at trigger creation; the per-kill
   `soul_update_hint()` call is removed. Live progress still shows via the existing `IPrintLnBold` milestone
   (every 25 souls).
2. **`hub_set_hint` (Paradise gate):** embedded **live remaining** shards/points, re-set per deposit (same
   bug, per-deposit). Fixed via snapshotted `level.acc_hub_shards_total` / `_points_total` constants.

`IPrintLn`/`IPrintLnBold` (chat prints) do **not** feed the cache — proven behaviorally: the map has heavy
dynamic `IPrintLnBold` that ran fine across many prior sessions; the crash was new only because the
soul-box `SetHintString` was new. Every other dynamic `SetHintString` is **bounded** (discrete PaP price
buckets, capped cache yield `ACC_CACHE_YIELD_MAX 9`, set-once per-instance); the main PaP is BG-safe (stock
`.cost` field + localized `&"ZOMBIE_PERK_PACKAPUNCH"` ref). Removing the soul-box drip frees ~100+ slots →
comfortable margin. Rule: never interpolate an unbounded runtime value into a `SetHintString` literal, and
audit **every** per-kill/per-event/looped hint — not just one. Pure GSC, linker-only (`-GscOnly`). Doc:
[48_abyss_descent.md](docs/48_abyss_descent.md). Memory: `triggerstring-cap-hint-strings`.

**Follow-up stability audit (6-agent sweep + adversarial verify, 2026-06-25).** Swept all ~51 modules for
any other unbounded-growth / resource-exhaustion bug (triggerstring, `fx` 256-cap, entity/trigger/model
leaks, HUD pool, thread/array growth) and fixed three real ones; the other dismissed findings verified as
bounded/dev-gated/false-positive (lockdown arrays reset per challenge, pickups self-clean, boss-item HUD
reused), and the soul-box/gate fixes re-verified safe:
- **`_acc_data_shards.gsc` — `level.acc_shards_pool` leak (real):** the array was appended per shard drop
  (line 210) but **never read or trimmed** anywhere — an unbounded dead-reference leak over a long match.
  Removed it (pickups already self-clean via `watch_lifetime` / `cleanup_pickup`).
- **`_acc_pap_levels.gsc` — Paradise PaP hint loop:** a 0.25s poll re-`SetHintString`d the live per-tier
  cost with no change-guard. The cost set is bounded (~18 = 3 buckets × 3 tiers × armory toggle) so it is
  **not** a cache overflow, but added the `acc_last_pap_hint` dedupe guard (mirrors `_acc_perk_info`) to
  stop the 4×/sec re-registration churn.
- **`_acc_reactor.gsc` — stale cooldown hint (cosmetic):** the "recharging (N rounds)" countdown only
  refreshed on state changes, so it went stale between surges. Added a display-only `acc_round_start`
  refresh thread (the availability gate stays live-read, so no correctness impact). Pure GSC, linker-only.

### Changed — RPD damage +25% (user, 2026-06-25)

RPD (`t6_rpd`) `acc_weapon_balance_mult` in [_acc_damage.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_damage.gsc)
bumped **0.10 → 0.125** (+25% damage, ~337 → ~421 effective DPS). This is the runtime damage lever only — the
RPD's PaP-pricing tier + box-odds (docs/54, scored off a separate curated `e:337` DPS in `compute_gun_tiers.js`)
were **deliberately not recomputed**, so its PaP cost (BOT 3000/4500/6000) and box weight (50, ~10%) are unchanged.
Docs: [05_weapons.md](docs/05_weapons.md) (tier table DPS + LMG balance prose). Pure GSC — linker-only rebuild.

### Fixed — Phantom never spawned when a purge straddled its cadence round (user, 2026-06-25)

The Phantom only *attempts* to spawn on its exact cadence rounds (10, 20, 30…), and
[maybe_spawn_for_round](scripts/zm/zm_abandoned_cyber_city/_acc_boss_phantom.gsc) did a hard `return` if a
lockdown purge was active (`level.acc_ldc_active`) — "the purge owns the actor budget." But a DEFCON lights at
**round 7** and a committed purge holds `acc_ldc_active` set **across rounds** until cleared, so a purge
straddling round 10 **dropped the Phantom's entire 10-round slot with no retry until round 20** — the reported
"got to round 15, Phantom never spawned." (The Glitch Stalker spawns every round, so a skipped round self-heals;
the Phantom's once-per-10 cadence does not.)

Fix: instead of abandoning the slot, **defer** it — set `level.acc_phantom_pending` and let a new persistent
`pending_watch()` spawn the Phantom the instant the purge clears. The one-at-a-time guard (`run_round_boss`)
still prevents stacking, and `run_round_boss` is threaded from the watcher so its `acc_round_end` endon can't
tear the watcher down. Pure GSC, linker-only (`-GscOnly`). Doc: header note in
[_acc_boss_phantom.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_boss_phantom.gsc).

### Changed — Double Tap 2.0 price 5,000 → 3,000 (user, 2026-06-25)

`set_perk_costs()` in [zm_abandoned_cyber_city.gsc](scripts/zm/zm_abandoned_cyber_city.gsc) — `specialty_doubletap2`
machine cost dropped **5,000 → 3,000 Points**. The perk-info card reads `.cost` dynamically, so the displayed
price + armory discount follow automatically. Docs: [13_perks.md](docs/13_perks.md) (table, per-perk header, and
the all-perks total **29,500 → 27,500**), [perk_abilities.md](docs/perk_abilities.md). Pure GSC — linker-only rebuild.

### Fixed — Glitch Purge escape: buying an un-bought border door walked you out (user, 2026-06-25)

The lockdown seal in [_acc_lockdown_challenge.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_lockdown_challenge.gsc)
`seal_room` only re-CLOSES the room's 2 border doors that were **already open** (their `enter_*` flag set). An
**un-bought** border door is a solid wall it correctly leaves alone — but its **buy trigger stayed live**, so a
player sealed inside the purge could walk up to that un-bought door, **buy it, and walk straight out**, escaping
the lockdown. The buyable-door loop in [zm_abandoned_cyber_city.gsc](scripts/zm/zm_abandoned_cyber_city.gsc)
(`zone_door_trigger_wait`) had no knowledge of an active purge.

Fix: new public query `acc_lockdown_challenge::is_door_sealed( flag )` returns true while a door is one of the 2
border doors of the room currently sealed by an active purge (`level.acc_ldc_active`). `zone_door_trigger_wait`
now refuses such a purchase (no-purchase deny sound) until the purge resolves — also blocks an OUTSIDE player from
buying *into* the sealed room. The gate auto-lifts the instant `acc_ldc_active` clears (no state to restore), and
respects the `acc_lockdown_lock_doors 0` test knob. Pure GSC, linker-only (`-GscOnly`). Docs:
[43_lockdown_challenge_room.md](docs/43_lockdown_challenge_room.md).

### Changed — Damage tuning: global 3.0 → 2.75, headshots up (user, 2026-06-25)

Pre-publish damage pass in [_acc_damage.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_damage.gsc):
- **Global damage** `ACC_GLOBAL_DMG_MULT` **3.0 → 2.75** (+200% → +175%) — the `acc_global_dmg_mult` flat
  final multiply on all player damage.
- **Regular/elite headshot** `ACC_HEADSHOT_MULT` **0.4 → 0.5** → with the roster's `locHead 5.0` that's
  **2× → 2.5× body**.
- **Boss/mini-boss headshot** `ACC_BOSS_HEADSHOT_MULT` **0.5 → 0.6** → **2.5× → 3× body**.

Per-gun balance tiers (`acc_weapon_balance_mult`) and the headshot-excluded shotgun list are unchanged. Docs:
[06_mechanics.md](docs/06_mechanics.md) (Headshot Multiplier + Deadshot tables), [05_weapons.md](docs/05_weapons.md),
[34_flags_reference.md](docs/34_flags_reference.md). Pure GSC `#define` change — linker-only rebuild.

### Changed — RELEASE BUILD: dev + god mode HARD-CODED OFF (user, 2026-06-25)

Release-prep for the Workshop publish. `level.acc_dev` and `level.acc_god` in
[`acc_resolve_dev_flags`](scripts/zm/zm_abandoned_cyber_city.gsc) are now **literal `false`** (replacing the
temp `= true` Paradise-testing hardcodes), so NO launch flag (`+set acc_dev 1` / `+set acc_god 1`) can
re-enable the dev sandbox or invulnerability in the shipped `.ff`. To dev/god-test again, restore the
`getdvarint( ..., 0 ) == 1` forms noted inline. Built with the full LED-bake pipeline for release.

### Fixed — PhD slide blast is a proper explosion now, not electric sparks (user, 2026-06-25)

The PhD Flopper slide-to-explode nova was firing `electric/fx_elec_sparks_burst_xlg_os` (an electric spark burst —
a stopgap after the original DLC4 apothicon FX wouldn't build here), so sliding "sparked." Swapped the blast visual
to the framework stock **orange explosion** (`level._effect["def_explosion"]` = `_t6/explosions/fx_default_explosion`)
in [_acc_perk_phd_flopper.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_perk_phd_flopper.gsc) `phd_explode` — both
tiers now show a proper PhD-style boom. def_explosion is framework-baked (not a loose `.efx`), so it's NOT
`#precache`d — we just `PlayFX` the registered handle. Removed the now-unused electric `#precache`/`#define`/
registration, and dropped the base tier's redundant second `def_explosion` (the visual block plays it for both
tiers, and its FX carries the boom). Mega still adds the nuke "whoomp" over it. Pure GSC.

### Changed — Global damage multiplier 2.50 → 3.0 (user, 2026-06-25)

`ACC_GLOBAL_DMG_MULT` (the `acc_global_dmg_mult` "buff all guns" lever) bumped **2.50 → 3.0** (+150% → +200%)
in [_acc_damage.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_damage.gsc). Flat final multiply on all player
damage; per-gun balance tiers and headshot multipliers unchanged. Docs:
[05_weapons.md](docs/05_weapons.md), [34_flags_reference.md](docs/34_flags_reference.md).

### Changed — Dev mode starts with 1000 Data Shards (user, 2026-06-25)

Dev sandbox (`acc_dev 1`) now starts each player with **1000** Data Shards (was 200), via the new
`ACC_DEV_SHARDS` define in [_acc_data_shards.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_data_shards.gsc).
Added a dev-aware `shards_cap()` so the per-player ceiling is 1000 in dev (was hard-capped at the 500 ship
cap, which would clobber the stash back down on the next pickup). **Normal play is unchanged** — starts at 0,
caps at `ACC_SHARDS_MAX` (500). Doc: [docs/49](docs/49_dev_mode_consolidation.md).

### Changed — Pre-release cleanup: dev/god off, Avogadro disabled, debug-text + HUD-clamp fixes (user, 2026-06-25)

Pre-publish pass from a multi-reviewer bug sweep:
- **Dev + God mode default OFF.** `level.acc_dev` / `level.acc_god` were HARDCODED `true` for local testing;
  both now resolve from `getdvarint( "...", 0 ) == 1` in
  [`acc_resolve_dev_flags`](scripts/zm/zm_abandoned_cyber_city.gsc) (ship-safe; `+set acc_dev 1` / `+set acc_god 1`
  still re-enable them for a local test launch).
- **Avogadro electric boss DISABLED for release** (not shipping him yet). The `level thread acc_boss_avogadro::init()`
  call in `main()` is commented out (the AI stays registered but nothing spawns him — it was the only spawn path),
  and `acc_avo_test` now defaults `0`. Was force-spawning a round-1 test boss in shipped play. Re-enable = uncomment
  the one thread.
- **Lockdown debug text no longer prints in shipped play.** `acc_lockdown_debug` now defaults `0` (was `1`), so the
  on-screen `[lockdown] round N -> <zone>` `IPrintLnBold` only shows when explicitly enabled
  ([_acc_lockdown.gsc `ld_debug`](scripts/zm/zm_abandoned_cyber_city/_acc_lockdown.gsc)).
- **Overclock HUD no longer frozen at "v5 / 10".** [`_acc_lui::set_oc_tier`](scripts/zm/zm_abandoned_cyber_city/_acc_lui.gsc)
  clamp widened 5 → 10 (the `accOcTier` clientfield is 4-bit / max 15, so 10 fits).
- **Exo Suit report card no longer frozen at "Tier 5 / 10".** [`_acc_perk_info`](scripts/zm/zm_abandoned_cyber_city/_acc_perk_info.gsc)
  exo clamp widened 5 → 10 (code 108+10=118 fits `accPerkCard`'s 7 bits; `ACC_EXO_MAX = 10`).

### Fixed — Reverted the broken Exo Suit room relocate (door was invisible/unusable) (user, 2026-06-25)

A prior agent's `gen_relocate_exo_room.js` moved the Foundry/Exo under-room + its buyable door EAST to center
x=350 to clear the abyss staircase — but it **broke the door** (moved the doorway to the room's east edge; it
became invisible/unusable). Surgically reverted the under-room + door + station to the **HEAD (`a18c3ac`)**
working state: [zm_abandoned_cyber_city.map](map_source/zm/zm_abandoned_cyber_city.map) "UNDER ROOM SOUTH" block +
"UNDER ROOM DOOR (south)" entities restored byte-for-byte (doorway back at `x[-192,-112]`). **Full LED-baked
build passed** (cod2map + navmesh + LED, no `brush.cpp:1860` crash). The door sits near the central descent well
again (user opted to keep that). `gen_relocate_exo_room.js` left untracked in `tools/` — do NOT re-run as-is.
Then the exo **table/station was moved INSIDE that restored room** (user 2026-06-25):
[_acc_exo.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_exo.gsc) `spawn_station_at( (0,1450,-240), 90 )` —
center-back of the room interior (x[-192,192] y[1379,1723]), clear of the west doorway, facing the entry. It's a
GSC-spawned prop, so that part was a `-GscOnly` build (no extra bake). Only the exo region was touched — the rest
of the `.map` (Paradise, soul doors, etc.) is intact.

### Changed — Action Figure PaP now costs S-tier (TOP) instead of BOT (user, 2026-06-25)

The Action Figure IS Pack-a-Punchable (in-place, no `_up` form; +1 cleave target per tier) but was charging the
**BOT** default (3,000/4,500/6,000). Moved it from the `compute_gun_tiers.js` EXCLUDED list into SPECIALS at
`tier: 'TOP'`, so `pap_price_bucket()` now returns **TOP → 5,000 / 7,500 / 10,000** for it. Pasted the regenerated
line into [_acc_pap_levels.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_pap_levels.gsc) `pap_price_bucket()` +
fixed the stale BOT comment in `acc_pap_actionfigure`. Box weight unchanged (still 12 = 2.4%); box odds unaffected.

### Added — Paradise final onslaught + WIN condition (user, 2026-06-25)

Paradise (the open-air plaza below the abyss) is now the **end of the map**: a scripted timed finale that, if
survived, **WINS the match**. New module
[`_acc_paradise.gsc`](scripts/zm/zm_abandoned_cyber_city/_acc_paradise.gsc) (orchestrated by `acc_main`, armed
by [`_acc_abyss_doors`](scripts/zm/zm_abandoned_cyber_city/_acc_abyss_doors.gsc) when the gate opens):

- **Phase 1 — CALM (60s):** a one-shot **victory fanfare** (`acc_paradise_calm` = the Mario "stage win" jingle)
  plays, the air is clear, only a **very light trickle** of zombies — a fakeout ("you made it").
- **Phase 2 — OMEN:** the **fog rolls back in** (`acc_atmosphere::paradise_fog_on` re-asserts the map's standard
  haze via `set_fog_from_dvars`, overriding the power-on settle) and the stock **dog-round announcer**
  (`zmb_dog_round_start`, "fetch me their souls") howls.
- **Phase 3 — DREAD (15s):** fog closing in.
- **Phase 4 — BATTLE (240s = 4 min):** the arena **seals**, the **"115" anthem** (`acc_paradise_music`) drops at
  max volume, and **2 Brutus + 1 Phantom** storm in alongside the **x4 horde** (regular surge + shield/glitch
  gauntlet). **Every minute +1 Brutus & +1 Phantom** join (up to concurrent caps `acc_paradise_brutus_max`/
  `_phantom_max`, default 4). A **countdown timer HUD** shows the time left. The **boss HUD + boss music are
  suppressed** for the whole battle (`level.acc_paradise_onslaught`, read by `_acc_health_bars` +
  `_acc_boss::boss_music`).
- **WIN:** survive → victory banner → replay the fanfare → **lift the fog** (`paradise_fog_off` = `disable_fog`,
  push the planes off-map) → fade to black → purge the horde → `level notify("end_game")` (the documented BO3
  end-game signal, docs/22). **LOSE:** a team wipe ends the match normally.

Also: **Paradise zombie SPEED parity** — regular zombies in Paradise now keep the **L5 trench run speed**
(`_acc_zombie_speed::paradise_speed_layer`) instead of dropping to base speed at the L5 doorway (user: "they stop
running faster"). **Paradise risers 6 → 12** (`_acc_bus_trench::get_paradise_risers`) so the horde erupts from the
whole plaza. Paradise **Brutus** spawn/tether added
([`_acc_boss_brutus::spawn_one_paradise` / `paradise_warden_think`](scripts/zm/zm_abandoned_cyber_city/_acc_boss_brutus.gsc)).

GSC-only (no `.map`/material/sky change) — builds `-GscOnly`, no LED bake. Audio (`115.wav`, `paradise_calm.wav`,
48k/16-bit) packed via a game-closed sound build. **Both tracks are copyrighted (test-only — NOT for the public
Workshop; see CREDITS.md).** Docs: [48_abyss_descent.md](docs/48_abyss_descent.md),
[34_flags_reference.md](docs/34_flags_reference.md). Verified: clean linker compile + fresh `.ff` (in-game runtime
behaviour still to be playtested).

### Changed — Brutus Mega Bottle drop 100% → 50% (user, 2026-06-25)

The Trench Warden's **Mega Bottle** reward is now a **50% chance** per kill (was guaranteed). It is rolled
**separately** from his item + Data Shard drops (those stay 100%, still gated by `acc_brutus_reward_chance`)
via the new **`acc_brutus_bottle_chance`** dvar (default `0.5`) in
[`_acc_boss::watch_mini_boss_death`](scripts/zm/zm_abandoned_cyber_city/_acc_boss.gsc). When the roll hits,
1 bottle goes to every player (unchanged). GSC-only change. Docs: [11_enemies.md](docs/11_enemies.md),
[34_flags_reference.md](docs/34_flags_reference.md).

### Changed — Mystery-box odds retuned: S = 12%, BOT = 50%, rest = ~38% (user, 2026-06-25)

[compute_gun_tiers.js](tools/compute_gun_tiers.js) `BOX_WEIGHT` MID `24→29`, BOT `35→50` (TOP stays 12). New
gun-pool odds: each **S gun 2.4% (5 → 12.0% total)**, each **BOT gun 10.0% (5 → 50.1% total)**, each MID gun
5.8% (5 → 29.1%), Mahem 5.8%, Action Figure 2.4%, Thundergun 0.6% — so "everything that isn't S or BOT" (MID
guns + 3 specials) = ~37.9%. Regenerated `acc_box_weight()` pasted into
[_acc_map_randomizer.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_map_randomizer.gsc) (drives the stock box
picker + the Glitch Altar gamble). (×0.985 for real in-box odds after the fixed Monkey Bomb 1% + Li'l Arnie 0.5%.)

### Fixed — placeholder `115.wav` so the soundbank compiles (user, 2026-06-25)

`acc_paradise_music` referenced `acc\music\115.wav` which didn't exist → the missing file failed the WHOLE
sound compile (no `CachedBanks` → zero custom audio in-game). Added a placeholder `sound_assets/acc/music/115.wav`
(copy of `main_theme.wav`) so the bank builds; verified `.sabl`/`.sabs` regenerated + `acc_soul_steal`/jingles
present. **TODO:** overwrite `115.wav` with the real Paradise track (no CSV change needed — same filename).

### Changed — MORS reserve ammo cut 50% (all versions) (user, 2026-06-25)

MORS reserve **120/180 → 60/90** (base/PaP) across base + `_up` + all 14 perk twins, via
[reduce_base_ammo.js](tools/reduce_base_ammo.js) `MAXAMMO_FIX` (clip stays 1, so `maxAmmo == reserve rounds`).
Verified in the deployed GDT (maxAmmo 60/90) + packed. This lowers MORS's balance score (reserve factor)
7.90 → 7.60, so [compute_gun_tiers.js](tools/compute_gun_tiers.js) now **`force: 'TOP'`** on MORS — its PaP
price (5000/7500/10000) and box rarity (3.0%) are **unchanged**, making this a pure ammo nerf, not a
price/rarity demotion. Re-baked via reduce_base_ammo → gdtdb → relink (no `apply_recoil_overhaul`, so the
headshot-loc normalization stayed intact).

### Added — Working 2nd Pack-a-Punch in Paradise (no surface-PaP breakage) (user, 2026-06-25)

Paradise now has its own Pack-a-Punch — built as a **STANDALONE custom vendor**, not a 2nd stock machine.
The previous attempt added a second stock `zm_pack_a_punch` zbarrier, which **fatals the load**: stock
`spawn_init` renames *every* such zbarrier to the shared `vending_packapunch`, then
`vending_weapon_upgrade()` does a **singular** `GetEnt("vending_packapunch")` that errors with two — and that
is what broke the surface PaP. Fix:
- New [_acc_pap_levels.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_pap_levels.gsc) `spawn_paradise_pap_at()`
  — a `script_model` (`p7_zm_vending_packapunch`) + `trigger_radius_use`, same idiom as the Paradise Mystery
  Box. On Use it dispatches **exactly like the surface PaP's `acc_pap_validate`** (Action Figure / first pack /
  tier-up), calling the same player-scoped `acc_do_first_pack` / `acc_do_tier_up` / `acc_pap_actionfigure`.
- **No tier reset by construction:** the PaP tier lives on `player.acc_pap_tier[ true_base ]`, not on any
  machine, so packing at the surface and continuing in Paradise reads the *same* stored tier. A hint loop shows
  the live next-pack price (mirrors `pap_cost_display_keeper`).
- The trigger **never** carries the `zm_pack_a_punch` targetname, so stock's singleton `GetEnt` is untouched —
  the surface PaP cannot break. `acc_find_pap_machine` also weighs registered custom PaPs so the cook/ready
  **sounds play in Paradise** (cosmetic-only hook).
- Wired from [_acc_glitch_altar.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_glitch_altar.gsc)
  `spawn_paradise()` at `(0,-1700,-1200)`.
- [gen_paradise_props.js](tools/gen_paradise_props.js): **removed** the stock-prefab 2nd-PaP injection (the
  root cause). `acc_dedupe_pack_a_punch()` still neutralizes any leftover stock Paradise PaP from an older
  `.map` at load. Pure GSC — `-GscOnly`, no bake.

### Changed — Thundergun nerfed harder, Mahem nudged up (user, 2026-06-25)

Per-gun base damage (`acc_weapon_balance_mult` in [_acc_damage.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_damage.gsc)),
on top of the existing boss-only cuts (Thundergun ×0.20 / Mahem ×0.50 vs bosses) + the 10% per-hit boss cap, all unchanged:
- **Thundergun `0.70 → 0.45`** (−55% from raw, deeper nerf — "so good when I played").
- **Mahem `0.315 → 0.40`** (a small **+27% BUFF**, bringing the ammo-limited launcher closer to the now-harder-nerfed Thundergun).

Both cover base + PaP via `IsSubStr`. Pure GSC.

### Fixed — Can't get sealed inside a Lab perk alcove on the round flip (user, 2026-06-25)

Standing in a Lab perk alcove as a round ended/began could trap you: `apply_round()` ran `close_all()` (every
`acc_perk_door_<spec>` → `show()`/`solid()`/`disconnectpaths()`) then opened the new 4, so an alcove you were
in that wasn't re-rolled open went **solid around you**. Reworked
[_acc_perk_doors.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_perk_doors.gsc) so it never blanket-closes: a
per-round intended open-set drives a reconcile pass (`apply_round` + a 0.25s `enforce_doors` loop) that closes
a door **only when its alcove is empty**. If any player — **alive OR downed** (so a revive isn't sealed off) —
is inside, the close is **deferred** and the door stays passable until they leave; occupancy also force-*opens*,
so even a sprint-through-the-doorway race self-corrects within one tick. Occupancy box = each door's own x-span
(read from the live `.map` door brushes, x-centers −675..675 — *not* the generator's −600..600) × `y[4150,4232]`
× a generous z window. Verified by a 3-reviewer adversarial pass (GSC-compile / BO3-API / trap-hunter): no
load-fatal, compile, or trap defects; downed-player `.origin` persistence and the no-reliance-on-`solid()`-push
design both independently confirmed. Removed the now-dead `open_all()`/`close_all()`.

### Fixed — Electric Cherry alcove: sealed the open right side (user, 2026-06-25)

The rightmost Lab perk stall (Electric Cherry, x=675) had no end-cap wall, so a player could walk around
its **closed** door and buy it. Added a wall — but a WORLD brush filling the gap to the Lab east wall (x=799)
**crashed the LED bake** twice (butting both walls = winding crash; a free-standing partition = lightmap hang
on the thin 45u nook — the reason the end caps were dropped). Built it instead as a `script_brushmodel`
`acc_ec_right_wall` ([the .map](map_source/zm/zm_abandoned_cyber_city.map), x746..799 · y4154..4228 · z0..150),
which the lightmapper **ignores** (like the perk doors) — forced solid at init by
`_acc_perk_doors::seal_ec_right_wall` ([_acc_perk_doors.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_perk_doors.gsc)),
never opened. Bake-test **BAKED 15.2s**; full build OK. Reusable technique: memory `brushmodel-wall-led-exempt`.

### Changed — Glitch Purge: 2s "join window" so the whole team can get in before the doors seal (user, 2026-06-25)

The lockdown / Glitch Purge sealed the instant the FIRST player stepped into the lit room, locking the rest of
the team out. [_acc_lockdown_challenge.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_lockdown_challenge.gsc)
`arm_trap` now holds a **join window** (`acc_lockdown_challenge_join_window`, default **2.0s**) after the first
entry: it announces "LOCKDOWN SEALING - get in!" to all players, waits, then **re-captures everyone inside at
that moment** as the sealed party and commits. Guards re-checked after the wait (room-rotation / commit-elsewhere
bails cleanly; an empty room re-arms instead of sealing nobody). No new geometry, no seal-logic change — only
*when* the existing seal fires. Pure GSC.

### Changed — Double Tap rebalanced: damage tempered (no longer ~2.66x DPS) + Mega fire-rate 40%→45% (user, 2026-06-25)

Base Double Tap 2.0's stock extra bullet (~2x dmg) + 33% fire rate stacked to ~2.66x DPS and felt mandatory. The
extra bullet can't be stripped from a usermap, so [_acc_damage.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_damage.gsc)
now tempers the per-hit DAMAGE for Double-Tap holders (`acc_doubletap_dmg_mult`, default **0.6** → base DT ≈ **1.6x
DPS**: 2 bullets × 0.6 × 1.33 RoF). The fire rate is untouched.
- **100%-safe allow gate** (`weapon_gets_dt_bullet`): applied to all guns **except Thundergun + Mahem**, and only
  on bullet hits (`b_bullet && !b_melee` auto-excludes melee / grenades / equipment) — so it can never nerf a
  weapon that lacks the extra bullet. Applies to base AND Mega.
- **VERIFY in-game:** MORS (charge railgun) + Paladin (bolt sniper) — if they don't fire 2 rounds with Double Tap
  (one crosshair damage number, not two), add them to the deny-list so the cut doesn't nerf them.
- **Mega Double Tap (Gun Slinger) fire rate 40%→45%** ([apply_recoil_overhaul.js](tools/apply_recoil_overhaul.js)
  `fire 0.714→0.69`) — a baked twin GDT, so it requires the weapon re-bake (apply_recoil_overhaul → re-apply the
  ammo cut → gdtdb /update → relink). **NOT yet rebuilt** (game was running).

### Fixed — Electric Cherry: genuine base-game zap + distinct machine + real jingle (user, 2026-06-25)

User: "just use the base cherry", a machine model "we haven't used" (not PhD's nuke), and the real jingle.
- **Zap is now 100% base-game.** [_acc_perk_electric_cherry.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_perk_electric_cherry.gsc)
  `ec_nova` dropped the custom burst FX + Earthquake and now fires the stock `zm_perk_electric_cherry::electric_cherry_reload_fx`
  (the real on-player discharge); the per-zombie electrocution was already the stock death/stun/shock FX. No PhD/slot
  swap was needed — the stock effect is self-contained (`self`=player, no internal specialty gate), so it runs on EC's
  existing `specialty_combat_efficiency` and everything else stays untouched.
- **Machine model = `p7_lab_bio_machinery_01`** (was the PhD nuke). The real cherry + Wunderfizz vending models are
  unpackable here; every stock perk-machine model is taken. This unused lab-equipment model fits EC's Lab spot and is
  **force-packed** via an `xmodel,p7_lab_bio_machinery_01` line in [the zone](zone_source/zm_abandoned_cyber_city.zone) —
  verified present in the packed assetinfo (renders, unlike the invisible cherry model).
- **Real jingle** — "Elemental Pop Sting" → `jingle_cherry.wav` (48k stereo), `acc_jingle_cherry` alias in
  [acc_audio.csv](sound/aliases/acc_audio.csv), wired in `_acc_mega_bottles::acc_perk_jingle_alias`; sound bank rebuilt
  game-closed. See [docs/13_perks.md](docs/13_perks.md).

### Added — depth-scaled Shielded ratio: deeper abyss = more Riot zombies (user, 2026-06-25)

The deeper you descend, the higher the share of zombies that spawn as **Shielded ("Riot")** elites. New per-zombie
roll in [_acc_elites.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_elites.gsc): on `zombie_init_done` (chained
AFTER coop_scaling so HP is already scaled — we're the outermost hook), a zombie that finishes init on an abyss
floor rolls `depth_shielded_pct(underground_layer(origin))` to become Shielded. Ratios: **L2 10% · L3 15% · L4
22% · L5 30%** (live dvars `acc_shielded_pct_l2..l5`); surface + L1 pit = 0 (the existing round-based shield
rounds still cover those — this is additive). `promote_to_shielded` gained a re-entrancy guard so the depth-roll
and a shield round can't double-promote (which would 25× HP). Same 5× HP / 25%-front-armor Riot as before.

### Fixed — Exo Suit room door relocated EAST, out of the abyss well (user, 2026-06-25)

The Foundry (Exo Suit) buyable door played tiny and "half on the stairs." Root cause: the Foundry is a small
384u-wide enclosed room sitting dead-center under the pit, and the abyss descent well (+ its east railing) is
*also* centered — so the door, pinned to the room's front wall at the room's east edge, was jammed right beside
the well. The door can't simply slide along the wall: past the room's edge it opens into the solid fill packed
under the floor. So the **whole room** was relocated east into the open part of the pit.
- New [tools/gen_relocate_exo_room.js](tools/gen_relocate_exo_room.js) (idempotent; reuses add_under_room.js's
  single-slab floor recipe so it doesn't fall through or break the LED bake) regenerates the south under-room at
  **room center x=350**: room `x[158,542]`, doorway/door `x[462,542]` (same 80u width — not enlarged, just moved),
  **350u east of the abyss well**, 161u west of the east trench stairs. Slides −80 west into the solid front wall.
- [_acc_exo.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_exo.gsc) station origin `(-120,1450,-240) → (230,1450,-240)`
  (+350, stays mid-room). [tools/add_prop_clips.js](tools/add_prop_clips.js) exo_station collision clip moved the
  same +350 (old clip's spot is now solid fill = harmless). Full LED-baked build — bake passed.

### Changed — Headshot multiplier lowered to 2x reg / 2.5x boss + Deadshot retuned (user, 2026-06-25)

Headshot damage felt too high. In [_acc_damage.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_damage.gsc) the headshot
temper (a separate multiplicative factor on top of the engine's `locHead 5.0`, NOT in the additive bonus pool):
- `ACC_HEADSHOT_MULT` **0.5 → 0.4** → regular/elite headshot **2.5x → 2x body**.
- `ACC_BOSS_HEADSHOT_MULT` **1.0 → 0.5** → boss/mini-boss headshot **5x → 2.5x body**.
- **Deadshot** `ACC_DEADSHOT_MULT` **1.4 → 1.3**; **Mega Deadshot (American Sniper)** `ACC_DEADSHOT_MEGA_MULT`
  **1.6 → 1.5**. These ADD into the crit bonus pool, which the headshot temper then scales — effective head:body
  (no PaP): base Deadshot **2.6x reg / 3.25x boss**, Mega **3.0x reg / 3.75x boss**.

New per-shot headshot = 2x the body shot (regular zombie, via `tools/audit_gun_damage.js`): e.g. PaP T3 **MORS
6,600 body → 13,199 head**, **Paladin 4,900 → 9,800**, **MK14 900 → 1,800**, **AK-74u 299 → 598**. Headshot-excluded
shotguns (Tac-19/Olympia) unchanged (flat, no bonus). Tier ratings are DPS-based, unaffected. Docs: docs/06
(Headshot Multiplier), docs/13 (Deadshot).

### Changed — Soul light: louder SFX + flies to the door's MIDDLE, not the top (user, 2026-06-25)

Two tweaks after the first in-game look at the moving soul light:
- **Louder `acc_soul_steal`** ([sound/aliases/acc_audio.csv](sound/aliases/acc_audio.csv)): VolMin/VolMax `87/92 → 100`
  and the full-volume radius DistMin `150 → 300` (so soul-bank kills across a layer stay at full volume instead
  of attenuating). Verified the soundbank recompiled (the repo's `sound/zone` is empty, so every build
  regenerates the banks from the alias CSVs — `.alias.sz`/`.sabl` mtime advanced).
- **Soul now lands at the door's vertical MIDDLE.** It was hitting the top because the perk-glow FX carries a
  built-in ~25u `LIFT_Z` (tuned to ride up a perk cabinet) on top of the old `+30` destination offset → visible
  glow at ~`floorZ+95` on a 128-tall door. [_acc_abyss_doors.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_abyss_doors.gsc)
  `spawn_soul_light` now targets the door origin with NO offset → host at `floorZ+40`, glow at ~`floorZ+65` = the
  door's true middle (`+64`). (The soul is a glowing point-light, no model — confirmed.)

### Fixed — Insta-Kill on bosses = a true 2× (was a 6× that the cap clamped to 4k) (user, 2026-06-25)

Insta-Kill felt useless on bosses — a Mahem hit on Brutus during Insta-Kill did only ~4k. Two issues: the
Insta-Kill multiplier was **6×** (user wants **2×**), AND it was applied BEFORE the boss per-hit cap (10% of
boss maxHP), so any value clamped to 10% (Brutus ~40k → 4k) regardless of the multiplier. Now in
[_acc_damage.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_damage.gsc): `ACC_INSTAKILL_BOSS_MULT` = **2** (live
dvar `acc_instakill_boss_mult`), applied as BOTH the damage multiplier AND a cap scale (cap ×2 → 20% during
Insta-Kill), so every gun deals **exactly 2× its normal capped boss damage** during the powerup (Brutus 8k/hit
instead of 4k) — still bounded, no one-shot. Normal (non-Insta-Kill) cap unchanged at 10%.

### Fixed — headshot loc-temper moved OUT of the additive bonus sum (PaP headshots no longer balloon) (user, 2026-06-25)

The headshot's loc-temper (`resolve_headshot_multiplier`, 0.5 reg) was summed INTO `bonus_sum`, so the engine's
`locHead` (~5.0) multiplied the *other* bonuses (PaP ladder, Deadshot, Cyberware) on a headshot too — PaP
headshots ballooned to ~**6.25× body** instead of a clean **2.5×** (MORS PaP head was 41k, Paladin 30k). Now in
[_acc_damage.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_damage.gsc) it's a **separate multiplicative factor**
(`n_hs_temper`) applied after the bonus sum: real headshots only, regular 0.5 / boss 1.0; body crits (Precision
Mode / Cyberware, no loc) keep the additive base layer untouched. Result: every gun's headshot is a consistent
2.5× of its (perk/PaP-boosted) body — **MORS PaP head 41,248 → 16,499, Paladin 30,624 → 12,249**. **Tier ratings
unchanged** (DPS-based, not headshot-based). `audit_gun_damage.js` updated to match + now flags per-shot >5000
(the boss per-hit-cap line) so "too crazy" numbers get caught (currently only the 2 snipers, by design).

### Added — Moving "soul light": a glowing orb flies from each kill into the soul box (user, 2026-06-25)

Completes the soul-box feel (research workflow `research-soul-light`). When a kill banks a soul toward an abyss
descent gate ([_acc_abyss_doors.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_abyss_doors.gsc)
`on_zombie_death_souls` → new `spawn_soul_light`), a **glowing soul orb now flies from the kill spot into the
soul box**: departure SFX at the death point (existing `acc_soul_steal`) → a blue glow orb streaks to the box
over ~0.8s → arrival SFX as it enters. Full flow = sound + light + travel + arrival.

- **How (reuses proven pipeline, zero new assets):** the orb is an invisible `script_model` set to `"tag_origin"`
  (no mesh — just the glow) spawned fresh at the captured death origin (never the corpse — it's deleted ~0.05s
  later), lit via `acc_perk_lights::set_glow()` (the `accPerkGlow` clientfield → `_acc_perk_lights.csc` renders
  it **client-side**; server `PlayFX` does NOT render in this build), and flown with the stock
  `MoveTo` + `waittill("movedone")` primitive. On arrival it zeroes the glow (leak-safe) + plays the arrival
  cue + deletes. **Pure GSC, `-GscOnly` build** — reused glow index 6 (blue), so no `.csc`/FX/`.zone` change.
- **Safe under load:** a concurrent-orb cap (`acc_soul_fx_max` 14) so a mass wipe can't spawn an FX swarm (the
  soul still banks + departure SFX still plays; only the visual throttles), plus a timeout self-clean so an orb
  can never orphan. Only fires for actual soul-banking kills (a layer kill with the gate still closed).
- **Live tuning dvars:** `acc_soul_fx` (1 = on), `acc_soul_glow_index` (6 = blue; try 8 white / 9 purple / 10 teal),
  `acc_soul_travel_time` (0.8s), `acc_soul_fx_max` (14), `acc_soul_arrive_sfx` (1).
- **Needs an in-game look check** (per the research): whether the static glow reads as a "soul" while moving. If it
  washes out, the documented next step is a dedicated trail FX index (e.g. `zombie/fx_ritual_pap_energy_trail`).
  Docs: docs/34, docs/48.

### Fixed — normalized EVERY gun's headshot loc to the 5.0 standard + Paladin PaP boost (user, 2026-06-25)

Acted on all 8 `audit_gun_damage.js` anomalies. New tool [normalize_gun_loc.js](tools/normalize_gun_loc.js)
(supersedes normalize_sniper_loc.js) forces the standard convention on all 15 roster guns (base + PaP + twins,
7433 GDT loc fields): `locHead`/`locHelmet` = **5.0** (→ uniform **2.5× body** headshot), excluded shotguns
(Tac-19, Olympia) = **1.0** (truly flat), all other body loc = 1.0. Was wildly inconsistent (Five-Seven/PPSH 3.0,
ASM1 3.5, MK14 6.0, RW1 7.5). Also re-encoded **Paladin `_up` damage 1000 → 2000** (it was the only gun whose PaP
gave no GDT damage boost — now matches MORS's 2×; its B-tier balance mult 0.49 keeps it under MORS). Re-audit =
**0 anomalies**. Loc-only + that one damage field (no recoil/ammo/base-damage touched); gdtdb + build. Added a
base-form ranking print to `compute_gun_tiers.js`; docs/54 regenerated (scores unchanged — they're DPS/kit-based,
not headshot-based, so the loc fix doesn't move them).

### Added — tools/audit_gun_damage.js: recompute every gun's per-shot damage + flag anomalies (user, 2026-06-25)

A re-runnable balance auditor (born from the MORS/Paladin headshot bug). Reads the LIVE data — `ACC_GLOBAL_DMG_MULT`
+ `ACC_HEADSHOT_MULT` + `acc_weapon_balance_mult()` + `is_weapon_headshot_excluded()` from
[_acc_damage.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_damage.gsc), and each gun's base/`_up` `damage` +
`locHead`/`locHelmet` from the install GDTs — and prints a per-gun table (body / headshot / PaP body / PaP head)
plus ANOMALY callouts (non-standard `locHead`, headshot weaker than body, excluded-but-not-flat shotguns,
head/helmet mismatch, PaP with no GDT boost, missing balance entry). `node tools/audit_gun_damage.js`. First run
flagged 8: the headshot `locHead` is wildly inconsistent (Five-Seven/PPSH 3.0 → 1.5× heads, ASM1 3.5, MK14 6.0,
RW1 7.5 → 3.75×, vs the 5.0 → 2.5× standard) + Tac-19/Olympia "headshot-excluded" yet still 2–3× on heads.

### Fixed — MORS + Paladin headshots now follow the standard loc convention (user, 2026-06-25)

Both snipers were mis-calculating headshots ("one does 8k, the other 800"). Root cause = bad GDT hit-location
(`loc*`) mults: **Paladin** (`t8_paladin_hb50` + `_up`) was set to **all-1.0 including the head**, so a headshot
did `locHead(1.0) × map-factor(0.5) = 0.5×` body — a headshot did **half** a body shot. And **MORS PaP** still had
**9.0 limbs** because `normalize_mors_loc.js`'s limb field names were wrong (`locRightArm` vs the real
`locRightArmLower/Upper`/`locRightHand`…), so it never touched them. New tool
[normalize_sniper_loc.js](tools/normalize_sniper_loc.js) forces the **standard convention on both snipers**
(base + PaP + twins): `locHead`/`locHelmet` = **5.0**, every other body loc = **1.0** — so each sniper's headshot
is now **2.5× its own body**, and the only remaining gap is the intended balance tier (MORS 0.66 S > Paladin 0.49 B).
Edits the install GDTs in place (loc only — does not touch damage/recoil/ammo). Fixed the wrong field names in
`normalize_mors_loc.js` too. docs/05 loc-trap note still applies (docs/33 §"check the GDT loc mults").

### Added — Soul-steal SFX at the kill location when a soul is banked (user, 2026-06-25)

Every kill that banks a soul toward an abyss soul-box descent gate now plays a **soul-steal SFX at the spot
the zombie died** ([_acc_abyss_doors.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_abyss_doors.gsc)
`on_zombie_death_souls`, right at `door.acc_souls++`): `PlaySoundAtPosition( "acc_soul_steal", self.origin )`.
`PlaySoundAtPosition` is an engine builtin that plays at a WORLD point, independent of the dying actor (which
corpse-cleanup deletes within ~0.05s). New **3D NONLOOPING** alias `acc_soul_steal` (sound/aliases/acc_audio.csv,
cloned from `acc_glitch_warp` so the ~102-column row matches) → `sound_assets/acc/fx/soul_steal.wav` (the user's
"soul steal" download, converted to **48k mono** via `tools/convert_wav_48k_mono.ps1`). Game-closed build packed
it: verified in `alias.sz` + `assets.sz` + the **LOADED bank `.sabl`** (a short non-streamed SFX lives in `.sabl`,
NOT the streamed `.sabs` — the `.sabs` is correctly unchanged). Docs: docs/35, docs/51.

### Changed — Data Shards HUD: PNG icon replaces the "DATA SHARDS" text label (user, 2026-06-25)

The "DATA SHARDS" text label is replaced by the user's `data_shard_cyber_bare.png`; the count stays beside it.
Imported the PNG as image `i_acc_data_shard` (source_data/acc_perk_shaders.gdt, `image,` in the .zone).
**Dead end found + documented:** the server hudelem (`createIcon`/`setShader`) needs a 2D *material*, and a
usermap CANNOT build one (`No techsetdef for material type '2d'`) — so the icon is drawn in **LUI**
(`acc_hud.lua` `CoD.AccShardIcon`, the proven image path the perk bar / PaP-tier icons use), and
`_acc_data_shards::sync_shards_to_client` now shows the count only (moved to x44, right of the icon). LUI icon
position (LEFT/TOP/SIZE) + the count x are estimates to fine-tune in-game. ⚠ Verify the map LOADS (a bad LUI
edit can make the `.ff` un-loadable) — the change is an isolated, revertible static widget copied from the PaP icon.

### Changed — boss-item HUD: each implant + the carry line on its OWN line (no more center bleed) (user, 2026-06-25)

The left-HUD boss-item indicator concatenated IMPLANT 1, IMPLANT 2 and CARRYING into one long string that ran
off into the center of the screen. Split into stacked, one-per-line server hud elements in
[_acc_boss_items.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_boss_items.gsc) `sync_items_hud`: IMPLANT 1 (y146),
IMPLANT 2 (y168), CARRYING (y190), each hidden when empty. The Gas-Tank NITRO label/bar moved down to y214/y232
to clear the stack. (PNG icon for the Data Shards label is a separate follow-up — needs a 2D-material import.)

### Added — Mega Widow's Wine: low-stance spider mobility (crouch ×3 / prone ×5 / down ×8) (user, 2026-06-25)

Mega Widow's Wine ("Spiderman") now makes you move dramatically faster the **lower** you are: **crouch ×3,
prone ×5, last-stand (downed crawl) ×8** the normal speed of *that stance*. It **multiplies** the move scale,
so versus another player in the **same** stance the Mega-Widow's holder is N× faster (standing is unchanged).

- **Mechanism:** BO3 exposes only one player move lever — the single overall `SetMoveSpeedScale` (scales the
  current stance). A per-player watcher [`_acc_mega_bottles.gsc` `mww_stance_speed_watch`] polls `GetStance()` +
  `.laststand`, stores the factor in `player.acc_mww_stance_speed`, and recomputes through the single
  move-speed owner [`_acc_utility.gsc` `recompute_move_speed`], which multiplies it in **after** the base
  `acc_move_scale_cap` (so 3×/5×/8× survive the cap). Mirrors the Flash / Mega-Flopper speed watchers; started
  on acquire and re-applied each respawn (the spawn path resets the scale). Absolute speed stays sane because
  crouch/prone/down stance ratios are <1 (3× crouch ≈ 2× run; 8× crawl is still slow); a higher final clamp
  `acc_mww_speed_cap` (10.0) bounds pathological item×stance stacks.
- **Down ×8 caveat:** depends on the engine applying the move scale to the last-stand crawl — flagged for
  in-game verification; crouch/prone are not affected by that uncertainty. The watcher applies the down rate on
  `.laststand` directly (not re-checking `HasPerk`, which can flicker mid-down) so the 8× lands if the engine honors it.
- Live dvars: `acc_mww_crouch_speed` (3) / `acc_mww_prone_speed` (5) / `acc_mww_down_speed` (8) / `acc_mww_speed_cap` (10).
- Also fixed stale docs/perk_abilities Spiderman text (still listed the removed web-grenade pool). GSC-only; lint clean. Docs: docs/perk_abilities, docs/34.

### Added — Electric Cherry as the real 10th perk (keeps PhD Flopper) (user, 2026-06-25)

The map now ships **10 perks**: PhD Flopper still rides the stock `specialty_electriccherry` pipeline (nuke
placeholder model), and a **genuine Electric Cherry** was added as a from-scratch perk on the unused engine
specialty **`specialty_combat_efficiency`**, with the **real `p6_zm_vending_electric_cherry` vending model**
(the one perk-machine model that shipped unused in the install).

- **Geometry** ([tools/respace_perk_alcoves_10.js](tools/respace_perk_alcoves_10.js)): re-spread the Lab perk
  row from 9 → 10 stalls — all 9 machines shifted left 75u, Electric Cherry dropped into the freed right end
  (X=+675). 9 partitions (end caps dropped, all geom ≥60u off the walls = sliver-safe), 10 door gates incl.
  `acc_perk_door_specialty_combat_efficiency`. **LED bake PASSED (BAKED, 18.5s).**
- **Perk** ([_acc_perk_electric_cherry.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_perk_electric_cherry.gsc)):
  `REGISTER_SYSTEM` + the stock 6-call `register_perk_*` chain (clientfields skipped — HUD via `accOwnedMask`,
  no pool hit; no `.csc`). Ability = **reload-discharge electric nova** lifted from stock cherry, with the
  clip-fraction bug **fixed** (`GetWeaponAmmoClip`+`clipSize`): reloading discharges an electric blast that
  scales with mag emptiness (empty mag → big, round-scaled, one-shots trash). Up to 8 zombies, +40 pts/kill,
  6s cooldown. FX = stock `electric/fx_elec_sparks_burst_xlg_os`, sound `acc_phantom_zap`. Cost 3,000.
- **Mega "Power Surge":** bigger radius (→200u), 12 targets, +50% damage, 5s cooldown, **AND boss-special
  immunity** — the Phantom chain-zap slow + the Subroutine Core power/perk-disable. This immunity was **moved
  off Mega Widow's Wine "Spiderman"** (user 2026-06-25): `_acc_boss::protect_immune_players_during_debuff` and
  `_acc_elites::acc_phantom_chain_zap` now gate on `specialty_combat_efficiency`. (It stays a *Mega* benefit
  because only the persistent Mega flag survives the boss's `UnsetPerk` debuff.) Mega Widow's keeps its
  one-hit-melee Spiderman benefit; it loses the boss-special immunity.
- **Wiring:** entry `#using` + `set_perk_costs`; `.zone` scriptparsetree line; `_acc_perk_doors`
  `get_perk_door_specs` → 10; `ACC_PERK_SLOT_MAX` 9→10. **`-GscOnly` build OK** (fresh 40.98 MB `.ff`, module
  compiled, zero missing-asset errors). **Pending:** HUD perk-bar icon (Ronan `cherry`, needs the near-full
  clientuimodel pool handled) + a buy jingle (needs the source wavs + a game-closed build).

### Fixed — re-synced ALL prop collision clips to live positions + snug sizes (no more invisible walls) (user, 2026-06-25)

Generalised the altar-barrier fix: audited every underground interactable's **live** spawn origin against
`add_prop_clips.js`'s clip list, which had drifted badly. The list still clipped `glitch_altar_base` (90,1500) and
`overclock_terminal` (-150,1440) — but both props moved to the abyss layers (altar→L3, terminal→L2), so those clips
were pure **invisible walls** in the empty Foundry. Re-synced the list to the actual z=-240 props: **exo_station**
(-120,1450), **reactor_plinth** (0,2120, was unclipped/walk-through), **pit_cache_w/e** (±360,1950), **perk_slot_vendor**
(-250,1820) — each sized snug to its model (half-extents tightened from a flat 30). Regenerated the `.map` block.
Known limits (flagged): the generator only clips z=-240, so the altar (L3) + overclock terminal (L2) are now
**walk-through** at their deep homes (not invisible walls — a future per-z generator pass); and a model's own
oversized collision LOD (if any) can't be shrunk by a clip. Half-extents are estimates — trivial to nudge + re-run.

### Changed — Data Caches: one per player per round in co-op (anti-hog) (user, 2026-06-25)

The two pit **Data Caches** could each be looted by the same player every round — one player could hog both.
Now ([_acc_data_shards.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_data_shards.gsc) `cache_loop`) a player who
loots one cache **can't loot the other that round** — it must go to a teammate. Implemented as a per-player
round-number gate (`player.acc_cache_looted_round`, compared to `level.round_number`) — **self-healing**, no
reset thread (a new round re-enables the player automatically). **SOLO is exempt** (`level.players.size <= 1`):
with no teammate to leave it for, blocking the 2nd cache would just waste its shards every round. Toggle
`acc_cache_one_per_player` (default `1`; `0` = first-come per cache again). GSC-only; lint clean. Docs: docs/34, docs/46.

### Fixed — removed orphan invisible barrier where the Glitch Altar used to be (Foundry / Exo room) (user, 2026-06-25)

The Glitch Altar moved out of the Foundry (the Exo-suit room) to abyss L3, but its `add_prop_clips.js` collision
clip (`glitch_altar_base` @ `(90,1500)`, a `clip` box `x[60,120] y[1470,1530] z[-240,-160]`) stayed behind — an
**invisible barrier in the empty east side of the room**. Deleted the orphan brush from
[the .map](map_source/zm/zm_abandoned_cyber_city.map) and removed its entry from `tools/add_prop_clips.js` so a
re-run won't re-add it. (The `overclock_terminal` clip is a similar orphan but sits under the Exo workbench, so it
was left in place — flagged for review.)

### Added — "Paradise": open-air plaza hub below the abyss + soul-box descent gates (user, 2026-06-24/25) — WIP

The bottom of the abyss (L5) now opens, through a **communal currency gate**, into a long dark hallway that emerges
in a large **open-air plaza** — **"Paradise"**, a deep pit far below the city whose top is capped with the existing
night sky (`skybox_default_night`). Intended as a full second hub; the **shell + access are built and baked**,
amenities (perks / box / PaP / kiosks) are being populated.

- **Geometry (`tools/gen_descent_hub.js`, new; `tools/gen_abyss_layer.js` edited):** `gen_abyss_layer` now cuts a
  centered DOORWAY (jambs + lintel) in the L5 south wall. `gen_descent_hub` builds, south of the surface map (so the
  sky cap has clear void above it): a slim **dark hallway** `y[-580,1703] x[±96]` (enclosed, 2 dim lights) and a
  **2000×1600 open-air plaza** `x[±1000] y[-2200,-600]`, floor z=-1200, walls rising to a `sky`-material cap at
  z=-200 (~1000u-deep pit), 6 dim insurance lights. `sky` is the map's existing skybox material → **no new sky, no
  `.zone` line**. All brushes reuse the proven bake-safe `box()` winding; **LED bake PASSED (14.9s), full build OK,
  fresh .ff 40.98 MB.**
- **Descent gates are now SOUL BOXES ([_acc_abyss_doors.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_abyss_doors.gsc), user 2026-06-25):**
  `acc_abyss_door_1..4` no longer cost currency — each opens when the team banks **100 zombie souls** by slaying the
  horde **on that door's layer** (one soul per kill, credited to the single gate that layer feeds via
  `acc_bus_trench::underground_layer`; gates fill sequentially as you fight down). Souls hook =
  `zm_spawner::register_zombie_death_event_callback`; an info trigger shows the running count. Dvar `acc_soul_door_cost` (100).
- **Paradise gate (`acc_abyss_hub_door`, communal — keeps currency):** the bottom gate into Paradise costs
  **100 Data Shards + 100,000 points** paid into **two separate shared pools** — not a one-shot buy: any player holds
  [activate] to dump **all** they carry of both (each capped to its pool), so the pools draw down separately. Once both
  hit 0, **all living players must gather** within 256u, then it opens for everyone. Dvars: `acc_hub_door_shards` /
  `acc_hub_door_points` / `acc_hub_gather_radius`.
- **OOB safety ([_acc_bus_trench.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_bus_trench.gsc)):** new
  `player_in_second_part` / `origin_in_second_part` (footprint `ACC_SP_*`) — vetoes the stock out-of-playable-area
  hard-kill over the hallway/plaza AND excludes them from `underground_layer()` so the new area is **neutral** (no
  per-layer trench amping/slow there; structure-first).
- **Populated Paradise (user 2026-06-25: "everything a player needs, spread throughout"):**
  - *GSC, no bake ([_acc_glitch_altar.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_glitch_altar.gsc) `spawn_paradise`):*
    DUPLICATE Glitch Altar, Cyberware Overclock terminal, Exo Suit station, Neural Expansion Bay (perk-slot vendor),
    and a 2-pad boss-item Implant Bench — all the existing `spawn_*_at` helpers (each is independently duplicable),
    placed across the plaza floor (z=-1200).
  - *`.map` + bake ([tools/gen_paradise_props.js](tools/gen_paradise_props.js), new):* a **full duplicate perk row —
    all 10 perks** (6 stock `vending_*_struct.map` prefabs + 4 inline `zm_perk_machine` structs, **verbatim assets from
    the surface set** so zero new-asset risk) in **one row along the north with a center walkway gap** + a **2nd
    Pack-a-Punch**. `_acc_pap_levels::pap_tier_machine_watcher` now binds `custom_validation` on **every** `pack_a_punch`
    machine (was the singular `level.pack_a_punch`) so the 2nd PaP also does the in-place tier pack.
  - *Permanent Mystery Box ([_acc_glitch_altar.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_glitch_altar.gsc) `spawn_paradise_box_at`):*
    a **fully custom standalone box** — a script-spawned `p7_zm_der_magic_box` model + hold-use trigger that charges 950
    pts (`acc_paradise_box_cost`) and gives a random weapon from OUR box pool (`acc_map_randomizer::acc_box_weighted_pick`
    + `is_box_tactical`/`player_owns_box_weapon`; `zm_weapons::weapon_give(w,false,false)` with `magic_box=false` so it
    won't trip the PaP/boss-item `user_grabbed_weapon` listeners). It **never touches `_zm_magicbox`/chests/`start_chest_name`**,
    so the surface roaming box is provably untouched and the "malformed pair hides ALL boxes" failure is impossible.
    Stationary, always present (guns-only pool; tacticals excluded).
  - **Whole Paradise populate: LED bake PASSED, build OK, fresh .ff 41.00 MB.** Placements are geometrically sound but
    not yet eyeball-verified in-game (deep-gated content); facing/spacing nudges are trivial coordinate tweaks.

### Fixed — Mega perk jingle now emanates from the perk MACHINE, not the player (user, 2026-06-24)

The Mega-perk jingle (the fuller `_loop` arrangement) followed the player around — a long-standing annoyance.
Two causes, both fixed to match the regular perk-buy jingle exactly: (1) `_acc_mega_bottles::set_mega_perk` played
`player PlaySound( sting+"_loop" )` (2D on the buyer) → now uses the same path as `perk_purchase_jingle_watch`:
`acc_find_perk_machine( player, perk )` then `machine PlaySound(...)` (3D from the vending machine), with the
`acc_utility::play_sound_at_origin` static-origin fallback. (2) The 9 `acc_jingle_*_loop` aliases were authored
`PanType=2d` (non-positional → centered on the listener = the "follows you" symptom) while the regular stings are
`3d`; flipped all loops to `3d` in [acc_audio.csv](sound/aliases/acc_audio.csv) so they actually position at the
machine (same 150→1200 falloff as the stings). Soundbank rebuilt.

### Changed — Reactor Surge: glitch + shield enemies in the waves, 5-shard reward, no-shard specials (user, 2026-06-24)

Building on the Reactor Surge rework ([_acc_reactor.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_reactor.gsc)):

- **Each wave now also erupts elite types** alongside the regular surge — **2 Shielded ("Riot") elites + 1 Glitch
  Stalker per wave** (new `reactor_spawn_specials`; dvars `acc_reactor_shielded_per_wave` / `acc_reactor_glitch_per_wave`,
  `0` disables a type). Shielded erupt from the **pit risers** (reusing `acc_bus_trench::get_layer_risers` +
  `tag_trench_zombie` for the pit emergence/melee fix), wait the per-actor init gate, then
  `acc_elites::promote_to_shielded` (5× HP + front armor + shield model). Glitch reuse
  `acc_boss_glitch::spawn_glitch` (full blinking mini-boss). Both are `ignore_enemy_count` (off the round books,
  like the regular surge) and persist as threats.
- **No shards from the surge specials** (user: "same as the glitch purge"). New `self.acc_no_shard_reward` flag,
  set on every reactor-spawned shielded/glitch, checked in **both** reward paths — `_acc_elites::shielded_death_reward`
  (was 2 shards) and `_acc_boss_glitch::glitch_death_watch` (was 1 shard, folded in next to the existing `acc_ldc`
  skip). They're a survive-the-gauntlet threat, not a farm. (Kept decoupled from `acc_ldc` so no lockdown-room
  targeting semantics leak in.)
- **Survive reward 3 → 5 Data Shards** per player (`acc_reactor_reward` default 5); the hint/success text auto-reflects it.
- GSC-only build (3 modules); lint clean; docs/34 (new dvars + reward), docs/46 (trench guide) updated.

### Fixed — Foundry/Exo door moved EAST, off the abyss-L2 well door (mis-buy fix) (user, 2026-06-24)

The south under-room (Foundry — holds the **Exo Suit** station) buyable door (`enter_under_plaza` /
`acc_door_under_plaza`) sat at the WEST doorway `x[−192,−112]`, **overlapping the abyss-L2 (Descent-1) well buy
trigger** at `(−136,1787)` (radius 100) — so you'd accidentally buy the wrong one. Moved the doorway to the room's
**EAST** side `x[112,192]` (the only spot clear of both the central descent well `x[−112,112]` AND the D1 trigger).
Three surgical X-face translations in [the .map](map_source/zm/zm_abandoned_cyber_city.map) (pure translations →
bake-safe): front-wall solid shifted −80 (seals the old west gap, opens the east), the door brush +304 (slide
flipped `80`→`-80` so it still tucks behind the solid wall), and the buy trigger +304 with it (`x[96,192]`). Exo
station origin `(−120,1450)` unaffected. docs/45, docs/48 + the glitch-altar placement comment updated.

### Fixed + Changed — Reactor Surge: more aggressive waves + fixed the "used once, dead for the game" lockout (user, 2026-06-24)

The trench-pit **Reactor Surge** kiosk ([_acc_reactor.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_reactor.gsc)):

- **More aggressive surge** (lever tuning): zombies **per wave 6 → 10** (`acc_reactor_wave_count`) and the gap
  **between waves 6.0s → 3.0s** (`acc_reactor_wave_interval`); still **3 waves** (`acc_reactor_waves`). So ~30
  zombies erupt in ~10s instead of ~18 over ~18s (the AI cap throttles the true peak). New `#define` defaults.
- **Lockout bug FIXED.** Availability gated on **two** flags: `acc_reactor_used_round` (reset each round on
  `acc_round_start`) **and** `acc_reactor_busy` (cleared **only** at the end of `run_surge`). If a surge ever
  aborted before that clear — the plinth trigger's `self endon("death")` firing, or any mid-run error —
  `acc_reactor_busy` stuck **true forever**, and the round-reset (which only cleared `used_round`) never
  recovered it → **used once, dead the rest of the game**. **Fix:** replaced the flag+notify reset with a
  **self-healing round-number cooldown** — `reactor_available()` compares `level.round_number` live against
  `level.acc_reactor_ready_round` (committed at surge *start*), so re-availability **never depends on a notify
  firing or a flag being cleared**. Added `reactor_busy_watchdog()` (runs on `level`, survives the trigger's
  death) that force-clears a stuck `busy` after the surge's max duration. Mirrors the lockdown anti-softlock
  watchdog (memory `stuck-lockdown-blocks-all-bosses`).
- **Re-arm cadence** is now a **3-round cooldown** (`acc_reactor_cooldown`, default 3 = "raid it, don't farm it",
  docs/45) instead of once-per-round — matches the user's "should reset every few rounds." Set `1` for every round.
- Hint/HUD now shows "recharging (N round(s))". Docs: docs/46 (trench guide), docs/34 (new reactor dvars). GSC-only.

### Changed — Sniper tier swap: MORS → S, Paladin HB50 → B (user, 2026-06-24; formula-justified)

The two snipers swap roles — MORS becomes the premier S-tier boss-killer, Paladin drops to a mid B-tier one-shot.
**Every edit is justified by the docs/05 "v2 sustain" scoring formula** (run via `tools/compute_gun_tiers.js`), and
applied to **all versions** of each gun (base + `_up` + perk twins):

- **MORS → S** (base **7.73** / PaP **7.90**, was B 5.84/6.02). Damage `acc_weapon_balance_mult` **0.47 → 0.66**
  (`e` 470 → 660/shot, near-max single-target — the premier boss-killer). **Reserve 60/90 → 120/180** too: the
  **formula caps DPS at `e`=664**, and MORS's **clip-1 charge floors the SUSTAIN factor** (~0.40 of 1.8), so a
  DPS-only buff tops out at **~A 7.46** — the reserve lift is what clears S. Reserve applied to base + `_up` + **all
  14 perk twins** via a new `reduce_base_ammo.js` `MAXAMMO_FIX` block (+ `skye_s1_mors.gdt` added to its GDT list;
  clip stays 1) so a Deadshot/Mega twin swap can't clamp you back to 60. Damage covers all forms via `IsSubStr`.
- **Paladin HB50 → B** (base **6.14** / PaP **6.42**, was low-S 7.70/7.98). Damage **0.70 → 0.49** (`e` 624 → 437,
  700 → 490/shot). Clip 8 / reserve 96/132 / reload 4.1 unchanged. `ACC_PALADIN_BOSS_MULT` boss cut is separate and stays.
- **Cascade (auto):** the PaP-form rank reshuffle moves **MORS BOT → TOP** price tier (PaP 3000/4500/6000 →
  5000/7500/10000; box weight 35 → 12, rarer) and **Paladin TOP → BOT** (the reverse). The MID group is untouched —
  no other gun changed tier/price/odds. Regenerated `pap_price_bucket`/`tier_cost` (`_acc_pap_levels.gsc`) +
  `acc_box_weight` (`_acc_map_randomizer.gsc`) + docs/54 from the tool; docs/05 tier tables + box-odds updated
  (MORS was previously **missing** from both tier tables — now added). Verified: `audit_gun_ammo.js` shows MORS
  120/180 with **zero regression** on other guns. **GDT changed → needs `gdtdb /update` + relink** (not GSC-only).

### Fixed — PhD nova FX swapped off the missing DLC4 apothicon FX → stock electric burst (user, 2026-06-24)

The PhD Flopper slide/down nova used `dlc4/genesis/fx_apothicon_fury_spawn_in_exp`, a **DLC4 asset not built in this
install** — it threw 24 linker errors (the FX + its `gfx_fog_slow_lg` / `gfx_shockwave` anim materials, "invalid
atlas 0×0") and **never rendered**. Swapped to **`electric/fx_elec_sparks_burst_xlg_os`** — a stock, on-disk,
one-shot electric spark burst (on-theme: PhD hijacks Electric Cherry + cyber-city). `ACC_PHD_EXPLODE_FX` in
[_acc_perk_phd_flopper.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_perk_phd_flopper.gsc) + the `.zone` `fx,` line
both repointed; the `acc_phd_purple` handle renamed `acc_phd_nova`; `def_explosion` stays the fallback. Clears the
last of the "unexpected linker errors" (the `s1_mors`/`s1_mk14` weapon errors were already fixed). docs/13 updated.

### Removed — Mega Widow's custom web-grenade pool (6-cap + 4/round restock + WEB GRENADES HUD) (user, 2026-06-24)

Ripped out the Spiderman virtual web-grenade pool entirely ([_acc_mega_bottles.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_mega_bottles.gsc)): the **6-usable-grenade pool**, the **+4/round pool restock**, and the **"WEB GRENADES" HUD counter** are gone — deleted `acc_web_pool_max`, `acc_web_refill_clip`, `web_grenade_pool_watcher`, `web_grenade_manage_watcher`, `widow_round_restock_watcher`, `sync_web_grenades_to_client`, the `acc_web_pool`/`acc_web_hud` fields, the per-player thread starts, the Mega-apply pool raise, and the `ACC_SPIDERMAN_WEB_GRENADES` / `ACC_SPIDERMAN_ROUND_RESTOCK` / `ACC_WIDOW_BASE_ROUND_RESTOCK` constants. Mega Widow's web grenades now use **stock** behavior. Its remaining Mega effects are **one-hit melee on regular zombies** + **immunity to boss specials**. UI card (acc_hud.lua) + docs/13 updated; no dangling refs (verified). GSC + LUI; linker-only build.

### Added — Phantom chain-special SLOW + zap; boss-special immunity moved Jug → Mega Widow's (user, 2026-06-24)

The Phantom's **player→player CHAIN special** now does more than damage: a connecting chain hit **zaps** you —
an electric-zap SFX + a brief **−30% move slow** (`acc_phantom_slow_mult` 0.70, `acc_phantom_slow_sec` 3.0).
The hit's *damage* always lands; the **SLOW** is the special part. And the **boss-special immunity** that used to
belong to **Mega Jug ("Ultimate Tank")** is **moved to Mega Widow's Wine ("Spiderman")** — it now negates both
the boss power/perk debuffs *and* the new Phantom slow.
- **Detection** ([_acc_elites.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_elites.gsc) `on_player_damaged`): a MOD_MELEE hit where the attacker is the Phantom (`acc_is_phantom`) *and* it's mid-chain (`acc_phantom_chaining`) → `acc_phantom_chain_zap`: play `acc_phantom_zap`, then set `acc_phantom_slowed` + a refreshing 3 s clear-timer, UNLESS the player has live Mega Widow's (mega flag + holds the perk).
- **Phantom** ([_acc_boss_phantom.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_boss_phantom.gsc)): tags the actor `acc_is_phantom` at spawn; `phantom_teleport_loop` brackets the chain call with `acc_phantom_chaining` true/false.
- **Move speed** ([_acc_utility.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_utility.gsc)): `recompute_move_speed` multiplies `×0.70` while `acc_phantom_slowed` (+ `active_speed_flags` "phantomslow").
- **Immunity move** ([_acc_boss.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_boss.gsc) `protect_immune_players_during_debuff`): `specialty_armorvest` → `specialty_widowswine`.
- **Sound**: new alias `acc_phantom_zap` → `sound_assets/acc/fx/electric_zap.wav` (Freesound Community "electric zap", 48 kHz mono). CREDITS row + IP-verify flag added.
- **UI cards** ([acc_hud.lua](ui/uieditor/menus/hud/acc_hud.lua)): Mega Jug card drops "Immune to boss attacks"; Mega Widow's card gains "Immune to boss specials".
- GSC + LUI + sound; linker-only build. docs/11 (Phantom) + docs/13 (perks) updated.

### Fixed — PhD slide left an "invisible zombie still hitting you"; removed the nova corpse-fling (user, 2026-06-24)

Sliding into zombies with PhD Flopper could leave a zombie **invisible but still meleeing you**. Root cause in
[_acc_perk_phd_flopper.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_perk_phd_flopper.gsc) `phd_explode`: the
nova ran `StartRagdoll` + `LaunchRagdoll` (a "corpse-fling") in the **same frame** as each zombie's killing
`DoDamage`, racing the engine's death processing. That left the actor **half-dead** — its model ragdolled and
flung out of view while its AI kept swinging — and the interrupted death sometimes **skipped the zombie-death
callback**, so `_acc_corpse_cleanup` never ran and the body lingered. **Fix: removed the corpse-fling entirely.**
It was **invisible on this map regardless** — `_acc_corpse_cleanup` Ghost()s + Delete()s every body within
~0.05s of death (`acc_corpse_linger_sec` default 0), so a launched ragdoll vanished before it could arc. The
per-kill **head-gib + guts-burst FX are kept** (they play instantly, before the body is hidden), so the kill
still reads as an explosion. `zombie_head_gib` already self-guards `no_gib` + `endon("death")`, so a survivor or
boss is never left headless. GSC-only — linker-only build. Docs: docs/13, docs/perk_abilities.

### Changed — Suppress loose "flying gib" limb chunks so they stop littering the map (user, 2026-06-24)

Bodies vanish on death (`_acc_corpse_cleanup`) but the **severed-limb gib chunks** stayed on the ground; the
user worried they'd crash the map. **They can't** — those loose limbs are **client-side dynents** the engine
spawns via `CreateDynEntAndLaunch` (`scripts\shared\ai\systems\gib.csc`), live in a **fixed auto-recycling
pool**, and are **not server entities** (they don't count toward `level.zombie_actor_limit`). So no overflow /
crash is possible; the real crash vector (corpse **actor** count) is the body-delete that already runs. Still,
to match the instant-vanish look, [_acc_corpse_cleanup.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_corpse_cleanup.gsc)
now stops the loose limbs from spawning at all: on each regular-zombie spawn (`callback::on_ai_spawned`) it sets
the gib **"don't spawn flying pieces"** bit via `gibserverutils::ToggleSpawnGibs(z, false)`. That bit persists
through every later gib (`SET_GIBBED` OR-preserves it), and the client reads it as `SHOULD_SPAWN_GIBS == false`
— so a dismembered limb still **swaps in the stump model + sprays blood FX** but leaves **nothing physical on
the floor**. Stock uses the same call on death-anim clones (`gib.gsc CopyGibState`), so it's a verified-safe
lever. Live toggle `acc_suppress_flying_gibs` (default 1). Bosses/specials already set `no_gib` (never gib).
GSC-only — linker-only build. Needs an in-game playtest to confirm the visual. Docs: docs/11, docs/34.

### Changed — Phantom +10% aggression (faster teleport cadence) (user, 2026-06-24)

The Phantom's aggression is governed by its **teleport cadence** — the stalk-gap between teleport-strike
actions (the code measures its aggression this way; a longer gap = "less aggro"). Cut that window 10% in
[_acc_boss_phantom.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_boss_phantom.gsc): `ACC_PHANTOM_TP_CD_MIN_DEF`
`2.1 → 1.89`, `ACC_PHANTOM_TP_CD_MAX_DEF` `3.0 → 2.7`, so it teleport-strikes ~10% more often (and rolls the
player→player chain special ~10% more often as a result). Lethality/mobility are unchanged — melee (19), speed
(+10% gait), reveal distance, and chain odds are deliberately left alone per the "jumpscary harasser, not a
murderer" design. Live-tunable via `acc_phantom_tp_cd_min` / `_max`. GSC-only → `-GscOnly`. Docs: docs/34.

### Fixed — Bosses one-shot by the Thundergun (and others); added a hard boss-damage cap (user + audit, 2026-06-24)

A 19-agent adversarial audit of the boss-damage surface found the weapon-name boss cut shipped earlier today
was **structurally defeated** — most importantly, **the Thundergun's ~200k one-shot was never touched by it**.
Root cause: the Thundergun's lethal damage is the stock `thundergun_fling_zombie` → `DoDamage(self.health +
666)` with **no weapon attached**, so `acc_weapon_balance_mult` (gated on `isdefined(weapon)`) and
`boss_nuke_mult` (returns 1.0 for an undefined weapon) **never fire**. `int(80666 × 2.5) = ~201,665` = the
exact ~200k reported. The −30% nerf and ×0.20 boss cut did nothing to the actual one-shot. Other confirmed
bypasses: the **Li'l Arnie octobomb** pull (`DoDamage(target.health)`, weaponless full-HP one-shot); **Insta-Kill
×6** applied after the cut; **PaP+Cyberware+Overclock investment** (bonus_sum bucket) multiplying past the
multiplicative cut (~130k/blast even at ×0.20); and **ability auto-crit** (+4.0 Precision Mode / +3.0 Slug) on
the uncut snipers **MORS / MK14**.

**Fix — a final per-hit boss-damage HARD CAP** ([_acc_damage.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_damage.gsc)
block 4d): a single PLAYER hit on a **heavyweight boss** (Brutus / Phantom / Subroutine Core) is clamped to
`acc_boss_per_hit_cap_pct` (**0.10**) of its maxhealth, applied **after** the global ×2.5 **and** insta-kill ×6
— so it survives every bypass above. The **Glitch Stalker is excluded** (`acc_is_glitch_zombie`) so the
lightweight mini-boss still dies fast. Normal sustained DPS is unaffected (only hits exceeding 10 % of boss HP
clamp). The existing `boss_nuke_mult` cuts are kept (they shape the baseline below the cap). Live dvar (`0` =
off). Docs: docs/05 "Deeper audit", docs/34.

### Changed — PhD Slider (Mega PhD Flopper) nova damage −60% (user, 2026-06-24)

The PhD Slider slide/down nova read **~64k** with Mega — absurd. The base nova is already round-scaled to
one-shot trash (`max(2000, level.zombie_health)`); the Mega then **doubled** it, and the global ×2.5 + Mega
Flopper +15 % explosive compounded it. Cut the Mega multiplier **−60%** (`2.0 → 0.8` of the base nova, new
`ACC_PHD_MEGA_DAMAGE_MULT` / dvar `acc_phd_mega_dmg_mult`) in
[_acc_perk_phd_flopper.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_perk_phd_flopper.gsc). Still one-shots trash
via the global buff; the Mega's edge is now its radius (500) / cooldown (8s) / extra flings / move-speed, not
raw nova damage. GSC-only — linker-only build. Docs: docs/13, docs/perk_abilities.

### Changed — Player health bar scales with max HP + greens by Jug tier (user, 2026-06-24)

The player health bar was a **fixed width** regardless of max HP, so Jug (250) and Mega Jug (300) looked the
same as base (100). Now in [_acc_health_bars.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_health_bars.gsc):
- **Width scales with max HP** — `1 px / HP` (no-Jug 100 / Jug 250 / Mega-Jug 300; floored 60, capped
  `acc_hp_bar_max_w` 360 so a max-health item can't run it off-screen). `createBar` bakes the width, so the bar
  is rebuilt only when max HP changes (perk buy / max-health item / death) — not per poll.
- **Fill colour greens by Jug tier** — no Jug = bright green, **Jug = darker green, Mega Jug = darkest green**,
  so the perk benefit reads at a glance. A **critical-HP red override** (≤33%) is kept so the "one hit from
  down" warning isn't lost. Mega flag read off `player.acc_mega_perks` (no new `#using`).
- This is a deliberate, user-requested softening of docs/50 D1 (which removed the numeric HP readout to hide
  the Jug magnitude): the bar now conveys the magnitude **qualitatively** (wider/greener), not as a number.
- Also fixed a pre-existing build blocker: `_acc_lockdown_challenge.gsc` used `IS_TRUE` without
  `#insert shared.gsh` (xref-lint catch). GSC-only build.

### Fixed — Glitch Purge froze the OUTSIDE horde for the rest of the team in co-op (user, 2026-06-24)

Separate from the Phase-Serum/in-room-glitch freeze: when **one** player sealed into a purge, the other
players reported the **entire outside horde froze** — regular zombies included. Root cause is stock targeting,
not the serum. `factory_closest_player` ([zm_usermap_ai.gsc]) caches each zombie's target in
`self.last_closest_player` and only re-picks when that player goes **invalid** (down/dead/disconnected) —
**never when they merely become unreachable** (`factory_validate_last_closest_player` keeps the cached player
while `am_i_valid`). The sealed-in player stays alive/valid, but `seal_room`'s `DisconnectPaths()` cuts the
navmesh to them, so every zombie already locked onto that player idled forever instead of switching to the
teammates still reachable outside. Fix in
[_acc_lockdown_challenge.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_lockdown_challenge.gsc): new
`ldc_release_outside_horde` thread (started in `commit_challenge`, ends on `acc_ldc_done`) re-picks, once per
second, any **non-purge** zombie (`!acc_ldc`) whose cached target is a sealed-in party member — pointing it
at a reachable outside player and raising `need_closest_player` so the stock factory refines to the
true-closest reachable one. Purge glitches are skipped (they must keep hunting the in-room player); true-solo
/ whole-team-sealed has no reachable target so it no-ops. GSC-only → `-GscOnly`. Docs: docs/43 §4.

### Changed — Overclock + Exo Suit extended to 10 tiers; shield-pierce can exceed 100% (user, 2026-06-24)

Both upgrade tracks now go to **10 tiers** (was 5) on a shared **LINEAR cost ladder** of **4 × tier** —
`4 / 8 / 12 / 16 / 20 / 24 / 28 / 32 / 36 / 40` Data Shards (220 to max one track; all fit the 500 cap).
- **Gun Overclock** ([_acc_overclocks.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_overclocks.gsc)): `ACC_TIER_MAX` 5→10 + `ACC_TIER_COST_T6..T10`. Effects scale automatically (no clamp): flat dmg →+100%, glitch →+250%, ammo refund →100%, shield-pierce →200% at T10.
- **Exo Suit** ([_acc_exo.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_exo.gsc)): `ACC_EXO_MAX` 5→10 + `exo_cost` T6–T10. Resist →−50% (clamp −80%), melee →+300%. **Depth gate caps at L5** (only 5 abyss layers are built — T6–T10 add only resist+melee until layers 6–10 exist).
- **Shield-pierce over 100%** ([_acc_damage.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_damage.gsc)): removed the `pierce > 1.0` clamp and the `front_frac < 1.0`→`!= 1.0` guard, so past T5 the Riot's frontal armor flips into a **weak point** — over-pierce amplifies frontal damage (T10 = 200% pierce → ~175% from the front).
- **UI** ([acc_hud.lua](ui/uieditor/menus/hud/acc_hud.lua)): the `vN` indicator already renders any tier (clientfield is 4-bit / 0–15); fixed the hardcoded `/ 5` denominators → `/ 10` on the OC + Exo report cards, extended `AccExoCosts` to 10 entries, bumped the exo "MAX" check 5→10, and capped the "full speed to layer N" text at the 5 built layers. Server HUD/buy messages already use `ACC_*_MAX`. docs/46 tables updated.
- GSC + LUI rawfile; linker-only build.

### Changed — Thundergun −30% / Mahem −10% damage + boss-nuke audit (user, 2026-06-24)

The Thundergun was doing **~200k to bosses**. Root cause found in
[_acc_damage.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_damage.gsc) `acc_weapon_balance_mult`: the
Thundergun had **no entry at all** → it fell through to the default `1.0` (zero damage cut), while every
other gun is cut to 0.10–0.70. Its wind-blast cone multi-traces a boss's single hitbox, and the **×2.5
global player-damage buff** (`ACC_GLOBAL_DMG_MULT`) compounds it → ~200k. Nerfs (both via `IsSubStr`, covering
base + PaP + twins):
- **Thundergun −30%** — added `IsSubStr("thundergun") → 0.70` (was implicit 1.0). Covers `thundergun` + `thundergun_upgraded`.
- **Mahem −10%** — `s1_mahem` `0.35 → 0.315`.

Also ran a **boss-nuke audit** of every acquirable weapon (docs/05 "Boss-nuke audit"). Finding: the boss-damage
cut (`ACC_SHOTGUN_BOSS_MULT ×0.25`) only protected **pellet shotguns** (Tac-19/Olympia); the Thundergun and
Mahem bypassed it, so a flat damage nerf alone couldn't fix the boss case (the Thundergun still ~140k vs a
boss at 0.70). Paladin HB50 is fine by design (single-target, bosses negate its headshot mult).

**Boss-damage cut generalized (user picked this fix):** new `boss_nuke_mult()` applies a boss-only REDUCTION
(gated on `acc_is_boss`/`_mini_boss`, stacks on the balance mult) for the high-burst weapons that bypass the
pellet cut — **Thundergun ×`acc_thundergun_boss_mult` (0.20)** → ~28k/blast vs a boss, **Mahem
×`acc_launcher_boss_mult` (0.50)** → ~2,756/rocket, and **Paladin HB50 ×`acc_paladin_boss_mult` (0.50)** →
~half its per-shot boss damage (user follow-up: the sniper reined in vs bosses too — a single-shot weapon, not
a multi-hit nuke, so dial toward 1.0 if it loses its boss-killer niche). Chaff/clear power on regular zombies
is untouched; all three are live dvars. Also discovered + fixed a stale doc: `acc_global_dmg_mult` code default is **2.50** (+150%),
not the `1.32` docs/34 claimed — that ×2.5 is what compounds every multi-hit weapon's boss damage. GSC-only —
linker-only build. Docs: docs/05 boss-nuke audit, docs/34 (3 boss-cut dvars + the global-mult correction).

### Added — MK14 battle-rifle / DMR box gun (B tier, fully twinned) (user, 2026-06-24)

New box gun: the **MK14** (AW `s1_mk14`), a semi-auto marksman rifle — the roster's first DMR. **B tier base
AND PaP** (the user-requested tier), verified against the docs/54 scoring formula: papScore **5.99**, baseScore
**5.90** (B band = 5.6–6.6, so it sits mid-band with margin). Single-wield `bulletweapon` with empty `altWeapon`,
so it's **FULLY TWINNED** like the other conventional box guns (14 twins → **196** total, under the ~230 cap).

Tuning: `acc_weapon_balance_mult` **0.30** → base body **90/shot**, PaP **180/shot** (×1.32 global = 119 / 238),
scored as **curated single-target DPS** (`cu`, `e=400`) because a semi-auto's raw `damage/fireTime`
(300/0.095 ≈ 3158) wildly overstates real DPS — same treatment as the Five-Seven/Paladin. 30% ammo cut
(clip 20→14 / PaP 17→12; reserve **168 / 240**). Body hit-location mults are clean (1.0) so **no normalization
needed** — `locHead 6.0` just gives a clean ~3× headshot (marksman reward). Sniper **ability** (Precision Mode)
+ sniper **Overclock** family.

All 10 integration points wired (CSV, zone weapon + 14-line twin block, sounds via `gen_box_weapon_sounds.js`,
box pool, ability, overclock, balance, recoil twins via `apply_recoil_overhaul.js`, `variant_guns()`,
`reduce_base_ammo.js`, `compute_gun_tiers.js`). Box odds reshuffled (pool **16→17**, weight **72→77**; MK14 BOT /
commonest at ~9.1%; Galil drifted BOT→MID). Docs: docs/05 (tier lists + box odds), docs/54 (regenerated), docs/33.

### Changed — Brutus (Trench Warden) HP now scales with the round (user, 2026-06-24)

Brutus HP was a **flat 40k** (× co-op player count) regardless of round — a round-5 Warden and a round-25
Warden had identical HP. Now it **scales with the round like a regular zombie gets tougher, but tamer** than
stock's ~10%/round compounding so a high-round Warden is never "crazy" (user's words). New
`scale_mini_boss_hp()` in [_acc_boss.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_boss.gsc): **simple
(non-compounding)** growth off the tuned base — `hp = base * (1 + pct * rounds_past_anchor)`, anchored at his
debut round so the **first Warden stays exactly the 40k** the user tuned. Defaults: base `40000`
(`acc_boss_mini_hp`), `+6%` of base/round (`acc_boss_mini_hp_round_pct`, read as a float), anchor round `5`
(`acc_boss_mini_hp_anchor`). Solo curve: **r5 40k → r10 52k → r20 76k → r30 100k → r40 124k**. The round-scaled
base is then × the existing **logarithmic co-op multiplier** (`boss_hp_player_mult`, ×1/1.5/1.8/2.0 for 1–4p),
unchanged — so a round-20 4-player Warden = 76k × 2.0 = 152k. The dev/test low-HP Brutus override path is
untouched (it bypasses scaling). All three knobs are live balance dvars. GSC-only — linker-only build
(`-GscOnly`). Docs: docs/11 Trench Warden note, docs/34 flags.

### Changed — Descent now pays off: Overclock → abyss L2, Glitch Altar → L3, Exo Suit → Foundry (user, 2026-06-24)

The trenches had **no reward for going deeper** — the two big Data-Shard SINKS sat in the Foundry under-room
(layer 1) alongside the Exo Suit, so there was no reason to descend the abyss. Re-anchored the three stations
so the abyss pays out and the Exo gates it:

- **Cyberware Weapon Overclock terminal** → **abyss L2** (`(-400, 1948, -480)`, was Foundry `(-120,1450,-240)`).
- **Glitch Altar** gamble → **abyss L3** (`(-400, 1948, -720)`, was Foundry `(90,1500,-240)`).
- **Exo Suit station** → **Foundry under-room** (`(-120, 1450, -240)`, was trench pit `(250,1800,-240)`) — the
  freed Overclock spot. The Exo is what *lets* you walk deeper, so it now sits at the top of the descent.

Loop: earn shards from the pit caches → buy Exo tiers up top → descend → Overclock on L2 → descend more →
gamble at the Altar on L3. Both deep stations sit on the **WEST floor chunk** (`x[-781,-112]`, a solid
full-depth slab on every layer) at the layer mid (`y=1948`) — clear of the alternating center stairwells
(`x[-112,112]`) and of where the stairs from above land (east, `x≈+112`). All three are **pure GSC script
spawns** (`_acc_glitch_altar.gsc`, `_acc_exo.gsc`) — no `.map`/geometry, so **`-GscOnly` build, zero LED-bake
risk**. The proximity info cards follow automatically (`level.acc_oc_kiosk_origins` /
`acc_exo_station_origins` are populated at spawn). ⚠ L2..L5 bake **pitch black** (`gen_abyss_layer.js
lightsForLayer=0`) — the Altar self-glows (core orb beacon) but the Overclock kiosk does not; add a bake-gated
light if it's hard to find. **Depends on the abyss floors being walk/zombie-path verified** (docs/48 open
item). Docs: docs/48 (first abyss content), docs/47 (Exo station placement).

### Changed — Shielded ("Riot") elite walks a bit faster (user, 2026-06-24)

`acc_shielded_walk_rate` default `1.0 → 1.2` in [_acc_elites.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_elites.gsc)
`shielded_speed_think` — ~20% faster walk cadence (still the heavy WALK gait, so no slow-mo; rate stays floored
at 1.0). Live-tunable via `acc_shielded_walk_rate`. docs/11 updated.

### Changed — Shielded ("Riot") elite HP = flat 5× a normal zombie (no co-op double-count) (user, 2026-06-24)

Settled on **5×** a normal zombie's HP (user 2026-06-24, after 5×→3×→5×). The important fix underneath: the old
`z.maxhealth = base_hp * N * special_hp_mult()` **double-counted co-op** — by promote time `base_hp`
(`z.maxhealth`) **already carries the co-op regular +100%/player mult** (applied at `zombie_init_done`), so
multiplying `special_hp_mult()` on top made a 2-player Shielded ~4.5× a 2p zombie ("read as 4×, not the
intended multiple"). `_acc_coop_scaling`'s own comment forbids stacking `special_hp_mult` on a maxhealth that
already has `regular_hp_mult`. Now a **flat `base_hp * 5`** in
[_acc_elites.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_elites.gsc) — the Shielded is **exactly 5× a normal
zombie at any player count** (it tracks the normal co-op scaling instead of a second elite curve). GSC-only;
docs/11 updated.

### Changed — Post-sprint zombie speed creep 1%/round → 0.6%/round (user, 2026-06-24)

Once zombies break into the **sprint** gait (round `acc_zspeed_sprint_round`, default 15), they speed up a bit
each subsequent round via `acc_zspeed_sprint_step_pct`. Cut that creep from **1% → 0.6% per round** for a
gentler late-game ramp (e.g. with sprint_round 15: R20 ≈ 1.03×, R25 ≈ 1.06×, vs the old 1.05× / 1.10×).
Two edits in [_acc_zombie_speed.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_zombie_speed.gsc): `ACC_ZSPEED_SPRINT_STEP_PCT_DEF`
`1` → `0.6`, **and** the two dvar reads switched `getdvarint` → **`getdvarfloat`** (`rate_for_round` curve +
the init log) — an int read would have truncated the fractional `%` to `0` (no creep at all). Mirrors the jog phase, which
already reads its fractional `jog_step_pct` as a float. The jog phase, sprint round, and the floor-at-1.0
(never slow-mo) are unchanged. GSC-only → linker-only build (`-GscOnly`). Docs: docs/11 speed curve,
docs/34 (`acc_zspeed_sprint_step_pct`; also refreshed the stale `acc_zspeed_sprint_round` 13→15 and
`acc_zspeed_jog_step_pct` 2→0.5 defaults to match code).

### Changed — Glitch Altar odds spiced up to a riskier 65/35 boon/curse split (user, 2026-06-24)

The [Glitch Altar](scripts/zm/zm_abandoned_cyber_city/_acc_glitch_altar.gsc) gamble shifted from **~72%
boon / ~28% curse** to **~65% / ~35%** — bigger swings both ways. The marquee **Mega Win** (free Perk +
Insta-Kill) **doubled 1% → 2%** for a juicier top end, and the curse share grew to 35% — most of the added
weight went to **Surge** (the most action-y downside, an immediate burst of trench zombies) so a spin bites
more often without ever instant-downing you. Free Perk was then trimmed 12→8 with the 4% moved into Shard
Jackpot (11→15), and the jackpot payout bumped **+3 → +4 shards** — the altar leans more into refunding
shards than handing out perks (user 2026-06-24). New weights (sum 100 = %): Max Ammo 15 / Insta-Kill 13 /
Double Points 12 / Free Perk 8 / Shard Jackpot 15 / Mega Win 2 — Surge 16 / Corruption 11 / Dud 8. Net shard
EV stays negative even at +4/15% (≈ −1.6 shards/spin at cost 2 — still a sink, not a farm). Also synced
docs/06's stale altar numbers to the live code defaults (cost 4→2, jackpot +7→+4, drain 6→2). GSC-only —
linker-only build (`-GscOnly`). Doc: docs/06 "Glitch Altar System".

### Changed + Fixed — Action Figure: always one-hit, PaP-tier cleave, and PaP now actually works (user, 2026-06-24)

Reworked the Action Figure per the user, and fixed the bug that made it un-packable in-game:
- **Always one-knife** a regular zombie (was a 50%+ chance roll, which also depended on exo tier). Bosses/elites
  stay exempt (normal melee). `_acc_damage::on_ai_damage` AF block rewritten; the old
  `acc_actionfigure_onehit_chance` removed.
- **PaP-tier CLEAVE:** each PaP tier one-knifes one EXTRA nearby regular zombie per swing, so a swing hits
  `1 + PaP_tier` at once — base 1 / PaP1 2 / PaP2 3 / **PaP3 4**. New `_acc_damage::actionfigure_cleave`
  (threaded out of the damage callback; finds the nearest valid zombies via `util::get_array_of_closest` within
  `acc_af_cleave_radius`, default 140; cleave kills pass no weapon so they don't recurse the AF block).
- **FIXED — the AF could not be Pack-a-Punched at all.** It has no `_up` asset, so stock's
  `can_upgrade_weapon()` returned false → `player_use_can_pack_now()` **hid the PaP machine** whenever you held
  it (root cause of the user's "i cant even pap"). Fix: `make_actionfigure_packable()` points the AF's
  `level.zombie_weapons[...].upgrade` at **itself**, so the visibility gate passes; the real pack is still the
  in-place `acc_pap_validate` → `acc_pap_actionfigure` (returns false before any stock swap, so it never
  swaps to itself). Also fixed the machine's displayed price for AF tiers 2-3 in `pap_cost_display_keeper`.
- **Overclock:** unchanged — the AF stays OC-exempt by design (user confirmed they want no overclock on it).

GSC-only — linker rebuild. docs/05 Action Figure entry synced.

### Fixed — Stuck "purge" lockdown soft-locked all boss spawns in co-op ("Phantom never came") (user, 2026-06-24)

In a 3-player game the Phantom never spawned at round 10 or 20. Root cause (user-confirmed): a player
triggered a lockdown/purge challenge that **got stuck and never resolved**, leaving `level.acc_ldc_active`
set for the rest of the match. Both bosses gate on it —
`_acc_boss_phantom`/`_acc_boss_glitch::maybe_spawn_for_round` do `if ( isdefined( level.acc_ldc_active ) ) return;`
(they yield while a sealed-room challenge owns the actor budget) — so a stuck purge **permanently blocks every
boss spawn**. The structural flaw: the challenge only clears on `acc_ldc_killed >= total`, and `watch_fail` only
fires when nobody is up-and-inside; in between sits a dead zone (a challenge zombie that dies/vanishes
**without being counted**, the producer unable to spawn the full count under co-op actor-budget starvation, or a
stuck-alive zombie) that freezes `killed` short while a player sits inside — so neither resolver ever fires.

**Fix:** added an anti-softlock watchdog `ldc_stall_watch()` (threaded from `commit_challenge`) in
[_acc_lockdown_challenge.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_lockdown_challenge.gsc): (1) **room clear
but count short** (all spawned + none alive + `killed < total`) → the players cleared everything killable →
`challenge_clear` with reward; (2) **hard stall** — no kill AND no spawn for `ACC_LDC_STALL_SEC` (60s,
dvar `acc_lockdown_challenge_stall_sec`) → force `challenge_clear` (kinder than trapping; gates the next DEFCON
to +cooldown). Both routes clear `acc_ldc_active`, so the bosses come back. `challenge_clear` is one-shot guarded,
so racing the real resolvers is safe. GSC-only — linker-only build.

### Fixed — perk/PaP sounds followed the buyer instead of emanating from the machine (user, 2026-06-24)

When the machine-ent lookup missed, the perk-buy jingle (`_acc_mega_bottles::perk_purchase_jingle_watch`)
and the Pack-a-Punch cook sound (`_acc_pap_levels::acc_pap_play_on_machine`) fell back to
**`self PlaySound(...)` on the player** — and those aliases are **3D**, so the sound attached to the moving
player and **trailed them around the map** instead of staying at the perk machine / PaP. Fix: a shared
`acc_utility::play_sound_at_origin( origin, alias )` plays the alias from a **short-lived static emitter at
the buyer's position** (they stand AT the machine when buying), so even on a lookup miss the sound stays put.
Both fallbacks now use it; the primary path still plays on the machine ent (also static). GSC-only; lint
`xref OK`. (If a *specific* sound still follows after this, it's a separate source — identify which.)

### Changed — Mahem PaP reserve 40 → 30 (user, 2026-06-24)

The Pack-a-Punched Mahem launcher (`s1_mahem_up`) carried **too much reserve when packed**. Its GDT
shipped `maxAmmo/startAmmo 4` over a PaP `clipSize 10`, and in-game reserve = `maxAmmo × clipSize`, so it
held **40** reserve rockets. Dropped `maxAmmo`/`startAmmo` to **3** (3 × 10 = **30 reserve**). Base Mahem
(`s1_mahem`, `clipSize 1`, `maxAmmo 20`) is unchanged at 20. Edited `skye_s1_mahem.gdt` directly — this GDT
is hand-tuned and deliberately **not** in `tools/reduce_base_ammo.js`'s list ("Mahem launcher left uncut"),
so no ammo tool reverts it; a fresh asset re-install does (re-apply then). Build: `gdtdb /update` + linker
(weapon-GDT change, no geometry). Doc: docs/05_weapons.md ammo-economy note.

### Fixed — Glitch Purge stayed sealed for the rest of the game after a player died inside (user, 2026-06-24)

A player who **died inside the Glitch Purge (lockdown challenge)** left the room's two border doors **sealed
for the rest of the game** — the purge "never closed". Root cause in
[_acc_lockdown_challenge.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_lockdown_challenge.gsc) `watch_fail`:
the purge was only failed/unsealed when **no party member was `is_player_valid`**. But in co-op a member who
bleeds out **inside** the sealed room **respawns OUTSIDE** the seal at the next round, flipping
`is_player_valid` back to `true` even though they are locked *out* of the fight and can never reach it.
Counting that respawned-outside survivor as "still up" meant `challenge_fail` never fired, and with nobody
inside to kill the glitches the kill count froze so `challenge_clear` never fired either — the room stayed
sealed permanently. Fix: gate "still fighting" on **valid AND still inside the room volume**
(`acc_decontamination::player_in_zone_volumes`) — a respawned-outside player no longer keeps the purge alive,
so the instant nobody is up-and-inside the purge fails, unseals the doors (escape/revive valve), and despawns
the wave. Also covers solo Quick-Revive self-rez and the all-down wipe (unchanged). GSC-only — linker-only
build (`-GscOnly`), no geometry/LED. Doc: docs/43 §9.

### Fixed — HUD (perk bar + power-up drop icons) gone after a player dies & respawns (user, 2026-06-24)

A player who **died and respawned** (co-op next-round respawn) lost the entire custom HUD overlay for the
rest of the game — the **perk bar**, the **power-up drop icons** (Nuke/Max Ammo flash, Insta-Kill / Double
Points / Fire Sale), and the round-progress ring. Root cause: that whole overlay is the single `acc_hud`
**LUI menu**, which the engine **closes on the death→spectate transition**, and
[_acc_lui.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_lui.gsc) opened it **once on connect** and never again.
Fix: `player_lui_init` now runs a per-life loop — on the initial spawn **and every `spawned_player`
(respawn)** it re-opens the menu and **re-threads** the five watch loops (perk / stock-suppressor / powerup /
pickup-flash / round-ring), killing the prior life's via an `acc_lui_life` notify so they don't stack and so
their fresh change-trackers force an immediate full re-push to the just-opened menu. (`spawned_player` is the
same per-life hook `_acc_boss_items` already uses for respawn reapplies.) GSC-only; lint `xref OK`. The
server-side Data-Shard/Mega-Bottle text counters are separate `hud::createFontString` elems on the persistent
player ent (not the LUI menu) and are expected to survive respawn — if any are still missing after this, they
need their own destroy+recreate pass.

### Fixed — Easter-egg song only played for the picker (now plays for the whole lobby) (user, 2026-06-24)

The teddy-bear EE song ("Cyber Dreams") was meant to play 2D for everyone, but in co-op only the
player who activated the bear heard it. Root cause: `_acc_ee_song.gsc::play_ee_song()` played it via
`level.acc_ee_song_ent PlaySound("acc_ee_song")` on a spawned `script_origin` — which is **exactly the
approach stock COMMENTED OUT and abandoned** inside `zm_utility::play_sound_2D` (verified in the stock
mirror, `_zm_utility.gsc:3493`). The active stock path is `play_sound_2D → really_play_2D_sound`, used
for Samantha VO every player must hear (`zm_giant_teleporter.gsc:454`) and by our own main theme
(`_acc_atmosphere::apply_music`). Fix: route the EE song through `zm_utility::play_sound_2D("acc_ee_song")`
(added `#using scripts\zm\_zm_utility`), dropping the persistent origin-ent. GSC-only — linker-only build.

### Changed — Co-op scaling retuned: regular HP +20%/extra, zombie count +30%/extra (user, 2026-06-24)

Two `_acc_coop_scaling.gsc` changes (the spawn-count one earlier the same day had been removed "to follow
base game"; the user wanted it back at a lower rate):
- **Regular zombie HP → +20% per extra player** (`ACC_COOP_REGULAR_HP_PER_EXTRA` `1.0 → 0.2`): 1p 1.0× /
  2p **1.2×** / 3p **1.4×** / 4p **1.6×** (was +100% = 2/3/4× — too tanky in co-op). Stock BO3 adds *zero*
  per-player HP, so this whole multiplier is ours, applied via the `level.zombie_init_done` hook. Elites
  (+50%/extra) and bosses (log curve) unchanged.
- **Zombie spawn count → +30% per extra player, vs SOLO** (re-added `ACC_COOP_SPAWN_PER_EXTRA` `0.3` +
  `acc_coop_max_zombie_override`/`solo_equivalent_max`/`stock_round_player_count`/`spawn_rate_mult`): 1p 1.0× /
  2p **1.3×** / 3p **1.6×** / 4p **1.9×**. Because stock already scales count per player on its own curve, the
  override **inverts stock's per-player term back to the solo number** and applies our flat multiplier instead —
  so the per-player count is exactly this table regardless of stock's curve. `post_zm_main` chains
  `level.max_zombie_func` again (installed AFTER `early_round_pacing`'s, so it wraps it → stock default).

GSC-only — linker rebuild. docs/15 (HP + spawn tables, and the corrected "stock does NOT scale HP per player"
note), the README module line, and the entry-script chain comment all synced.

### Changed — Phantom reworked: teleporting harasser, every 10 rounds, less lethal (user, 2026-06-24)

Three Phantom changes in `_acc_boss_phantom.gsc`:
- **Teleport mobility (new signature behavior).** The Phantom now STALKS most of the time (cloaked walk +
  melee) and periodically BLINKS to reposition + land a single HIT-AND-RUN (blink into melee → one swing →
  blink away, never camps). Cadence is deliberately ~30% SLOWER than the Glitch Stalker's blink (1.33–2.22s) →
  `acc_phantom_tp_cd_min`/`_max` `2.1`/`3.0` = "~30% less aggro than a glitch". The flashy **player→player CHAIN**
  (warp from one player to the next, a hit on each) is a **RANDOM SPECIAL** move (`acc_phantom_chain_chance` 25%,
  needs 2+ players, `acc_phantom_chain_hops` 3) — fired occasionally, NOT the constant mode. Teleports reuse the
  VERIFIED(acc) `GetClosestPointOnNavMesh` → `forceteleport` pattern (never lands off-mesh). New thread
  `phantom_teleport_loop` + helpers (`phantom_chain`/`phantom_blink_to`/`phantom_back_off`/`valid_target_players`/
  `pick_chain_target`/`phantom_strike_point`/`phantom_retreat_point`). Downed teammates are excluded as targets
  (it harasses, not executes). All behavior is live `acc_phantom_*` dvars (docs/34).
- **Melee −78% (85 → 19):** ~30% UNDER a Glitch Stalker's 27/hit (glitch = stock 60 × `acc_glitch_melee_dmg_mult`
  0.45). "Jumpscary, not a murderer." Screech cooldown is now a dvar (`acc_phantom_screech_cd` 1200ms) so a chained
  teleport burst still scares without machine-gunning.
- **Spawn cadence every 10 rounds:** `ACC_PHANTOM_INTERVAL_DEF` `1 → 10` (round 10, 20, 30, …; was every round).
  The one-at-a-time guard still applies.

GSC-only (no geometry) — linker rebuild. docs/34 Phantom dvar table refreshed (also corrected stale melee/speed rows).

### Changed — Boss-battle music swapped to "The Final Boss Battle" (user, 2026-06-24)

The boss-music track (`acc_brutus_music` → `sound_assets/acc/music/brutus_music.wav`, played on Phantom spawn by
`acc_boss::boss_music`) is now **"The Final Boss Battle"** (alperomeresin, Pixabay #158700) — full ~4:01 STREAMED
stereo, resampled 44.1→48k via `tools/convert_wav_48k_stereo.ps1` (the Mod Tools' bundled ffmpeg is a stripped
build with no PCM encoder, so the no-dependency resampler was used). Dropped in over the same filename, so the
alias is unchanged — no CSV/zone edits. The alias keeps the historical "brutus" name (Brutus is music-less now;
the track is effectively the Phantom's theme). Needs a GAME-CLOSED build (the `.sabs` bank locks while BO3 runs).
NOTE: the wav is **44 MB** (the prior loop was ~9.5s/1.8 MB) — it roughly doubles the package; trim with the
resampler's `-TrimSeconds` if Workshop size matters. docs/35 updated.

### Changed — Opening theme swapped to "Suspense Dark Thriller" (user, 2026-06-24)

The `acc_main_theme` opening song (played once at spawn by `_acc_atmosphere::apply_music`) is now
**lnplusmusic — "Suspense Dark Thriller Music"** (Pixabay #392762), the **full ~1:45 track** (user's
pick), replacing StockTune "Ethereal Neon Odyssey". Swap mechanics:
- Resampled the download 44.1 kHz → **48 kHz, kept stereo**, 16-bit PCM via a new
  [tools/convert_wav_48k_stereo.ps1](tools/convert_wav_48k_stereo.ps1) (the existing
  `convert_wav_48k_mono.ps1` force-downmixes to mono — wrong for music). Wrote it straight to
  `sound_assets/acc/music/main_theme.wav` (same filename → the alias + GSC are unchanged; old
  StockTune theme backed up to `tmp/theme_backup/`).
- Built **game-closed** (the `.sabs` stream bank is file-locked while BO3 runs). Verified the streamed
  bank regenerated fresh and grew ~1.5 MB → **19.68 MB** (contains the `acc\music\main_theme` ref).
  The `.ff` size is unchanged because a STREAMED alias lives in the `.sabs`, not the `.ff`.
- Licensing: Pixabay Content License (royalty-free) — flagged ⚠️ in [CREDITS.md](CREDITS.md) IP review
  (Pixabay forbids redistributing the audio as a *standalone* file; bundling in the map `.ff` is fine).
  Updated docs/35 + the `_acc_atmosphere.gsc` comment (which still wrongly said "Joth CC0").

### Added — Easter Egg song "Cyber Dreams" (Lilex) on a hidden teddy bear (user, 2026-06-24)

A classic-zombies song easter egg. A single interactable **teddy bear** (`p7_zm_teddybear` — proven-packed
stock model) is hidden in the **NORTH trench under-room** — the one *without* the Overclock terminal / Glitch
Altar (those are in the SOUTH "Foundry" room). Hold **[activate]**: the bear vanishes and the song plays **2D
for the whole lobby, once per game**.
- New module **`_acc_ee_song.gsc`** (wired into `_acc_main` + the `.zone`): spawns the bear + a
  `trigger_radius_use` (`TriggerIgnoreTeam`) back-center in the north room at `(0, 2430, -240)` (interior
  x[-172,172] y[2193,2497], `map_source` UNDER ROOM NORTH / add_under_room.js); on trigger it `Delete()`s the
  bear+trigger and `PlaySound`s the song on a level emitter (mirrors `_acc_boss::boss_music`). Disable live:
  `acc_ee_song_on 0`.
- New audio: alias **`acc_ee_song`** (STREAMED / 2D / NONLOOPING, `sound/aliases/acc_audio.csv`) →
  `sound_assets/acc/music/ee_song.wav` (the user's `lilex-cyber-dreams-314323.wav` run through
  `convert_wav_48k_mono.ps1` → 48 kHz/16-bit mono, 16.45 MB, ~3 min). Verified compiled into the soundbank
  (`acc_ee_song` in `.all.alias.sz`; `.sabs` grew ~9 MB).
- Zero new geometry (room already baked; teddy is a runtime script_model). **GSC-only build OK** (fresh `.ff`,
  soundbank rebuilt). docs/46 + docs/35; CREDITS row + IP-review checklist item added (⚠️ Lilex licence
  VERIFY-before-Public). NOTE: needs a re-publish before co-op players get it.

### Changed — Enemy glow re-theme (Glitch=magenta, Phantom=dark purple) + magenta purge lights + trench shard-bank indicator glow (user, 2026-06-24)

Visual pass on the boss tells, the lockdown "purge" room lights, and a new trench shard-bank indicator.
All ride the existing client-side glow pipeline (server `PlayFX` doesn't render here), so it's pure
GSC/CSC/FX — **linker-only, LED-safe**. Four new recoloured `.efx` generated by
[gen_perk_glow_fx.js](tools/gen_perk_glow_fx.js) (`magenta`, `magenta_dim`, `dark_purple`, `white_dim`)
and packed via new `fx,acc/light/...` zone lines.

- **Glitch Stalker body aura → MAGENTA, and 50% less intense.** The `accPhantomAura` value-2 FX in
  [_acc_boss_phantom.csc](scripts/zm/zm_abandoned_cyber_city/_acc_boss_phantom.csc) now points at
  `fx_perk_glow_magenta_dim`. Brightness halved from the old teal's `0.75` to **`0.375`** (the "50% less
  intense" ask). (The Glitch Stalker's **eyes stay teal** — that's a separate single-scalar shader-constant
  mechanism; say the word to retint them too.)
- **Phantom body aura → DARK PURPLE.** `accPhantomAura` value-1 FX → `fx_perk_glow_dark_purple`
  (`[0.42, 0, 0.72]`, deep violet), replacing red.
- **Lockdown "purge" room lights → MAGENTA (were red).** `ACC_LOCKDOWN_GLOW_INDEX` in
  [_acc_lockdown.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_lockdown.gsc) `1 → 11` so the DEFCON/purge
  alarm matches the Glitch Stalker's magenta. Added palette indices **11 = magenta, 12 = dim-white** to the
  `accPerkGlow` map (4-bit field, 0..15 — no width change, no clientfield-pool risk).
- **Trench shard banks (Data Caches) → DIM WHITE "has shards" indicator glow.** New in
  [_acc_data_shards.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_data_shards.gsc): each cache crate glows
  dim white while armed; the glow is **removed the instant a player loots it that round**, and **comes back
  when it re-arms at the next round start** — a clear at-a-glance "is there anything to grab" tell. Rides the
  crate model via `acc_perk_lights::set_glow(crate, 12)` / `set_glow(crate, 0)`.

### Changed — PPSH-41 all-around buff: +20% damage + 10 bigger mag (user 2026-06-24)

User wanted the PPSH made stronger across the board, with all twins included. Two levers, both covering
base + PaP (`_up`) + every perk twin:
- **Damage +20%:** `acc_weapon_balance_mult` (`_acc_damage.gsc`) `s4_ppsh41` `0.20 → 0.24` (~492 → ~590 DPS).
  The `IsSubStr( "s4_ppsh41" )` match applies to the base, PaP, and all `_acc_*` perk twins in one line.
- **Mag +10 rounds:** `CLIP_FIX` in `tools/reduce_base_ammo.js` `s4_ppsh41_base` `30 → 40`, `s4_ppsh41_base_up`
  `44 → 54`. Keyed on the stem (`stemOf`) so the perk twins inherit. Reserve = `maxAmmo (9) × clipSize`, so
  it rises with the clip: base `270 → 360`, PaP `396 → 486`.

Net: PPSH returns to **S tier** (base and PaP). It was already in the **TOP** PaP-price / box-rarity tier
(docs/54), and stays there — no box-odds or PaP-pricing change. The GDT clip edit needs `reduce_base_ammo.js`
re-run + `gdtdb /update` + linker; the damage edit is GSC-only. docs/05 tables + prose synced.

### Changed — Riot elite HP 5×→3×; Overclock gains a Shield-Pierce effect (user, 2026-06-24)

Two Riot/Shielded-elite balance changes:
- **HP cut 5× → 3×** the round's normal zombie ([_acc_elites.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_elites.gsc) `promote_to_shielded`, × the elite co-op curve unchanged). Docs/11 + docs/15.
- **Piercing added back to the Overclock system** as a 4th always-on, tier-scaled effect (the old per-family
  "Piercing Rounds / Penetration / Breach" rolled flags stayed dead — wiring is now tier-based, matching the
  post-2026-06-19 model). A gun's OC tier punches through the Riot's **frontal armor**: `front_frac` lerps from
  0.25 (take 25% from front) toward 1.0 as `min(1, tier × acc_oc_pierce_per_tier)` rises — default `0.20`/tier →
  T1 0.40 / T2 0.55 / T3 0.70 / T4 0.85 / **T5 1.00 = full frontal bypass**. So an un-overclocked gun still wants
  to flank, a maxed gun ignores the shield (the "designed counter," now earned via investment). Guns only
  (oc_tier is 0 on melee); explosives/grenades still bypass entirely. `_acc_damage.gsc` effect 4/4 +
  `ACC_OC_PIERCE_PER_TIER`; OC header in `_acc_overclocks.gsc` updated. Docs/11 counter-play.
- GSC-only change. NOTE: not in the published Workshop `.ff` yet — needs a re-publish for co-op.

### Fixed — "Gray screen + dead HUD after revive" = the map-name `.vision` was a desaturated grade (user, 2026-06-24)

Testing the real build: after going **down and being revived**, the screen stayed a washed
**GRAY**, the crosshair **damage numbers** seemed to vanish, and the HUD read "buggy" — but
only after a death/revive. A verified multi-agent audit (3 investigators → adversarial verify →
synthesis, against the stock-script mirror) traced **all three symptoms to one root cause** and
**refuted** the initial LUI-teardown theory.

**Root cause:** BO3's per-client visionset manager uses the **map name** as each client's
"default" visionset (`visionset_mgr_shared.csc:225` → `"zm_abandoned_cyber_city"`). On a DOWN it
activates the stock laststand/death visionsets; on REVIVE it **force-stamps
`VisionSetNaked(client, "zm_abandoned_cyber_city")` per-client** (`_zm_laststand.gsc`,
`visionset_mgr_shared.csc:1007`) — which **bypasses** our server-side global
`VisionSetNaked("default")`. And `_acc_atmosphere::apply_vision` is **change-gated** (re-fires
only when `want != applied`), so once `applied == "default"` it never re-asserts. Our shipped
`vision/zm_abandoned_cyber_city.vision` was a **desaturated cool grade** (`vkRM 1.0`, ramp
`0.24/0.25/0.25`) → the per-client revive restore looked gray. The damage numbers were **never
unbound** (per-controller LUI models + feed + watch loops all survive revive; there is **no
`CloseLUIMenu` anywhere**) — they just lost contrast under the wash and returned with the fix.

**Fix:** `vision/zm_abandoned_cyber_city.vision` is now **byte-identical to stock
`default.vision`** (`vkRM 0`, pure `R=G=B`, `r_reviveFX_Enable 0`), so the engine's per-client
revive restore lands on **neutral stock colours** — harmless by construction, coop-correct, zero
GSC. Consistent with the §7b "ship base colours" decision (`ACC_VISION_ON 0`); the tinted
map-name file was a vestige that only ever surfaced on revive. Added warnings (zone comment next
to the rawfile line, `apply_vision` header, docs/29 **§7c**) that the **map-name `.vision` must
stay neutral** — custom global grades go through `acc_vision_set` (the `acc_grade_*` files), never
the map-name file, which the engine force-restores per-client on every revive. Linker-only
(`.vision` is a rawfile — no LED bake). In-game check still pending: confirm the damage numbers
read normally once the gray is gone (the audit's lowest-confidence link, 0.6).

### Changed — Zombie spawn COUNT reverted to the BASE GAME (user, 2026-06-24)

The map no longer applies **any** custom multiplier to the per-round zombie total — it now follows
stock BO3 exactly ("follow how base game does it"). Two overrides on `level.max_zombie_func` were
removed/neutralized:
- **[_acc_coop_scaling.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_coop_scaling.gsc)** no longer
  chains `max_zombie_func`. Deleted `acc_coop_max_zombie_override` + its `solo_equivalent_max` /
  `stock_round_player_count` helpers and the now-dead `spawn_rate_mult()` / `ACC_COOP_SPAWN_PER_EXTRA`.
  `post_zm_main()` is now a no-op for spawn count; the module is **HP-scaling only**. (This briefly went
  +30% → +50% per extra player earlier the same day; both reverted.)
- **[_acc_early_round_pacing.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_early_round_pacing.gsc)** —
  the +45–50% rounds-1–4 boost is **neutralized** (`ACC_EARLY_SPAWN_MULT*` → `1.0`). The module is kept
  only to carry the modifier-round multiplier (`level.acc_mod_round_zombie_mult`, the "thin herd" modifier).

Stock now owns `level.zombie_total` end to end, **including stock's own per-player scaling**
(`_zm.gsc:3858-3865`) and the stock early-round ramp (R1 ×0.25 … R6+ full, `zombie_utility.gsc:1932`).
**Untouched on purpose** (separate spawn paths, never part of this count): trench surges
(`_acc_bus_trench.gsc`), riot-shield elites (round-based: shield round every 4th round, count = round/2),
and glitch zombie rounds. Updated docs/15, docs/04, docs/11, docs/20. GSC-only — `-GscOnly` build.

### Changed — Phantom +10% movement speed (user, 2026-06-24)

`ACC_PHANTOM_SPEED_MULT_DEF` (the sprint-gait `ASMSetAnimationRate`) `1.0 → 1.1` in
[_acc_boss_phantom.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_boss_phantom.gsc). CAVEAT: anim-rate →
ground-speed is **non-linear** here (history: `1.685` once overshot to caught-and-instakilled), so this is +10%
playback rate, not provably +10% u/s — verify with the in-game `[SPD]` probe and fine-tune live via the
`acc_phantom_speed_mult` dvar. Still well under a player's ~299 sprint, so it stays kiteable.

### Changed — Phantom + Brutus HP now scale LOGARITHMICALLY with player count (user, 2026-06-24)

Both bosses scaled **linearly** with players (×N), so a 4-player lobby faced **4× HP** — Phantom 400k, Brutus
200k — an HP-sponge slog ("scaling linearly is crazy"). Replaced with a logarithmic curve:
**`mult = 1 + 0.5·log₂(n)`** → each *doubling* of players adds 50% HP, so 4p is **2.0×**, not 4.0×.
New shared helper `acc_coop_scaling::boss_hp_player_mult()` (GSC has no log builtin and `player_count()`
clamps 1–4, so log₂ is a `switch` over the four valid counts; strength live-tunable via the
`acc_boss_coop_hp_log_k` dvar, default `0.5`). Resulting HP:
Bases were ALSO cut **−20%** in the same session (user 2026-06-24: Phantom `ACC_PHANTOM_HP` 100k→**80k**, Brutus
`ACC_BOSS_MINI_HP` 50k→**40k**), applied before the log mult. Final HP:
- **Phantom** ([_acc_boss_phantom.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_boss_phantom.gsc)): solo 80k / 2p 120k / 3p 143k / 4p **160k** (was 100/200/300/**400k**). Added `#using _acc_coop_scaling`.
- **Brutus** ([_acc_boss.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_boss.gsc)): solo 40k / 2p 60k / 3p 72k / 4p **80k** (was 50/100/150/**200k**).
- Only the log curve + the −20% base changed. The Subroutine Core full boss still uses the flat
  `special_hp_mult` (1.5/2.0/2.5×). Rationale: 4 players don't deal a clean 4× DPS to one target (shared
  aggro, overlap, downs), so log scaling keeps 4p time-to-kill near solo. Docs/15.
- GSC-only build OK (fresh `.ff`, `xref OK`). NOTE: not yet in the published Workshop `.ff` — needs a
  re-publish before co-op players see it.

### Changed — Global bullet buff 1.50 → 2.50 (guns still too weak, user 2026-06-24)

User reported guns feel way too weak in normal (non-dev/non-god) play. Raised the single across-the-board
damage scalar `ACC_GLOBAL_DMG_MULT` (`_acc_damage.gsc`) from **1.50 → 2.50** — +67% over the previous value,
so every gun now does 2.5× its raw output (was 1.5×). This is the intended "buff all guns" knob: a flat FINAL
multiply on ALL player damage in `on_ai_damage`, OUTSIDE the per-gun `acc_weapon_balance_mult` tiers, so the
relative S/A/B/C balance still holds — every weapon lifts uniformly. Live dvar `acc_global_dmg_mult` unchanged
(1.0 = off). Progression of the knob: 1.20 → 1.32 → 1.50 (all 2026-06-23) → 2.50 (2026-06-24). GSC-only
(no geometry) — linker-only build. docs/05 default synced.

### Removed — Phantom speed-probe diagnostic HUD leaked into the Steam build (user, 2026-06-24)

A live tuning readout (`^3[SPD] ^7you N (peak N)  ^5| PH N u/s @rate X`) was printing to the top of
every player's screen via `IPrintLnBold` on a 0.1s loop. It was a `[DIAG 2026-06-24]` probe added to
re-dial the Phantom boss speed (current vs session-peak player ground speed vs the live Phantom speed),
defaulting **ON** (`acc_phantom_speed_probe` defaulted to 1), so it shipped visible in the Steam build.
Removed the `level thread phantom_speed_probe();` call from `_acc_boss_phantom.gsc::init()` and deleted
the `phantom_speed_probe()` function entirely. GSC-only (no geometry) — linker-only build.

### Fixed — Workshop publish: thumbnail needs an ABSOLUTE path (first publish, 2026-06-24)

First Workshop publish of the map. The Launcher's `File → Publish Mod/Map` errored with a truncated
**"Error updating Steam Workshop item. Error code:"** dialog. Steam's own `Steam\logs\workshop_log.txt`
revealed it was NOT a build/permission/legal-agreement failure: the item was **created (PublisherID
`3751124295`)** and the **map content (`.ff`+`.xpak`, 36 MB) uploaded fine** — the ONLY failure was
`[AppID 455130] Failed to read preview file zone/previewimage.png`. The Launcher resolves the
`workshop.json` `Thumbnail` field **relative to its own working dir, not the usermap folder**, so the
relative `zone/previewimage.png` missed the file (which exists at
`usermaps/zm_abandoned_cyber_city/zone/previewimage.png`). Fix: set `Thumbnail` to the **absolute path**
of the preview in both the repo template `zone/workshop.json` AND the deployed copy, and captured
`PublisherID` `3751124295` into the repo so re-publishing UPDATES the same item instead of creating a
duplicate. Retry the publish (Visibility = Private — IP review still blocks Public). Documented in docs/55
§Gotchas + §A5; memory `workshop-publish-thumbnail-absolute-path`. (NOTE: the absolute path is
dev-box-specific — acceptable for this single-box repo.)

### Changed — Plaza Implant Bench moved against the south wall (user, 2026-06-24)

The two Implant-Bench pads (Slot 1 / Slot 2, where you enable a carried boss item) were spawning in the
**wide-open middle** of the Plaza right by the spawn points. They now sit **against the Plaza south wall,
behind the spawns**, out of the central training area. GSC-only (the bench is runtime-spawned relative to
the `player_respawn_point` struct — no Radiant edit, no bake): in `_acc_boss_items.gsc::spawn_bench()` the
pads are now laid **side by side along X** (a row parallel to the wall) instead of stacked along Y, and
pushed **south** to ~59u in front of the wall's interior face (y=-540, verified against the baked `.map`
perimeter brushes — full-width, no exits, no props). Default dvars retuned: `acc_bench_off_x` 64→**0**
(centre on spawn X), new **`acc_bench_off_y` -350** (push to the wall), `acc_bench_pad_sep` 56→**80** (now
the X half-spread, 160 apart — wide enough the two table models can't overlap at any orientation). `off_z`
(-35, floor height) and the trigger radius (40) unchanged. Docs/12 + docs/34.

### Added — Mega Bottle pickup UI + sound; non-overlapping pickup toasts; real pickup SFX (user, 2026-06-24)

Picking up a **Mega Bottle** now shows a UI toast + plays a sound (previously it only did a stock
`iprintln` and was silent on acquire). Three parts:
- **UI / no-overlap:** `acc_utility::hud_msg` is refactored into a SLOT system (`hud_msg_slot(text, slot,
  color)`) — each slot is an independent upper-center line at its own y (slot N sits `acc_msg_slot_h`=26 px
  below slot N-1) with its own elem + own fade. The generic/Data-Shard toast stays slot 0 (cyan, API
  unchanged for all ~10 existing callers); the **Mega Bottle pickup uses slot 1 (gold)**. So a boss kill
  granting a bottle WHILE a Data Shard drop is grabbed shows BOTH stacked instead of one overwriting the
  other on the shared slot. (Persistent left-stack counters `DATA SHARDS` y50 / `MEGA BOTTLES` y98 were
  already non-overlapping and unchanged.)
- **Sounds (user-supplied SFX):** Data Shard pickup → `acc_shard_pickup` now plays **`diamond_found.wav`**
  (liecio "Diamond Found", trimmed 5.7s→2.5s); Mega Bottle pickup → new alias **`acc_bottle_pickup`** →
  **`glass_cling.wav`** (Freesound "Glass Cling 01"); the bottle-drink-at-machine `evt_bottle_dispense` also
  moved to the glass cling. Both converted to 48 kHz/16-bit; rows in `sound/aliases/acc_audio.csv`; CC0
  license **VERIFY-before-publish** flagged in CREDITS.
- **Build:** full pipeline — the linker recompiled the `.szc` soundbank (confirmed: `.sabs` + `.all.alias.sz`
  mtimes advanced, `acc_bottle_pickup`/`diamond_found`/`glass_cling` present in the deployed bank; fresh
  `.ff`). Note: a `-GscOnly` relink DOES rebuild the soundbank (the docs/35 §4 "stale soundbank" caveat is
  wrong). `_acc_utility.gsc` + `_acc_mega_bottles.gsc` + `acc_audio.csv` + 2 wavs + CREDITS + docs/35.

### Added — Steam Workshop release-prep tooling + runbook (2026-06-24)

New **`tools/prep_release.ps1`** — a one-command release-readiness gate that runs the external-asset
gate → a FULL build (`build_map.ps1`, LED bake included) → and a battery of release checks
(fresh non-corrupt `.ff`; **LED lightmap freshness** — `.led` newer than `.d3dbsp`, catching the
`brush.cpp:1860` bake crash that `build_map` only WARNs about; `zone/workshop.json` fields + no leftover
"dev build" copy; 512×512 thumbnail; ≥5 screenshots; the CREDITS.md IP sign-off), then prints a
**two-track verdict** (Track A = Private
dev publish, Track B = Public v1.0) and the manual Launcher publish steps. It is **additive and safe**:
it calls the existing scripts (never reimplements them), **never uploads/publishes** (the Steam click
stays manual), **never flips visibility**, and **never edits game code/geometry/GDT/assets**. Switches:
`-NoBuild` (report only), `-Public` (Track-B blockers become fatal), `-DeployPerkShaders`, `-SkipAssetCheck`.
New **[docs/55_release_runbook.md](docs/55_release_runbook.md)** is now the authoritative publish procedure
(docs/09 + docs/18 §5–6 demoted to background, cross-linked). **`CREDITS.md`** completed: added the missing
NSZ Brutus + Skye-weapon-ports provenance rows and an **"IP review sign-off"** checklist gated by a
machine-readable `IP REVIEW STATUS: INCOMPLETE` marker (the prep script reads it; flip to `COMPLETE` only
when every game-rip clearance + credit is resolved). Committed a release-ready **`zone/workshop.json`**
(empty `PublisherID`; filled on first publish, then `-Reverse`-synced). No gameplay/build behavior changed.

### Fixed — Phantom boss never spawned: spawner needed `script_forcespawn` (user, 2026-06-24)

**The Phantom mini-boss never appeared in normal play.** Root cause, proven from a live `console_mp.log`
(`[PH] ... spawn_zombie returned undefined`): `spawn_phantom` fires the instant `acc_round_start` notifies,
but stock `zombie_utility::spawn_zombie` **returns `undefined` unless the spawner has `script_forcespawn`
set** (`zombie_utility.gsc:1538-1542`, *"ZOMBIE SPAWNER MUST BE SET FORCESPAWN"*). The round wave sets that
flag on spawners *as it pumps the wave*, so a boss spawning **mid-round** inherits it (Glitch r4+, elites) —
but the Phantom spawns at the very **start** of the round, before the wave has flagged the spawner, so its
spawn failed every time. Fix: `_acc_boss_phantom.gsc::spawn_promoted_zombie` now sets
`spawner.script_forcespawn = true` before calling `spawn_zombie` (deterministic at any round incl. r1).
Also ported the Glitch's `nearest_spawner_to_player()` (Phantom now materializes in the player's zone, not a
random open one — memory `custom-spawn-near-player-not-random`), cleared `level.acc_phantom_host` on death,
and added `cleanup_phantom_corpse()` to **delete the corpse** on death (it carried `acc_is_mini_boss`, which
makes `_acc_corpse_cleanup` skip it → a leaked actor slot every round now that it spawns every round).
A **prior** no-show was a stale build (committed `ACC_PHANTOM_ENABLE_DEF 0`); the working tree was already `1`.
**Final tuning (same session, after live verification):** first spawn **round 10**, then every round;
**speed fixed at +2% over a player's base sprint, every round** — `ACC_PHANTOM_SPEED_MULT_DEF` 1.4→**1.685**
now applied to the **sprint gait** (decoupled from the round curve), tuned by an in-game speed probe
(measured player sprint 299 u/s, Phantom sprint-gait@rate-1.0 = 181 u/s → 1.685 ≈ 305 u/s = +2%);
**glow recoloured cyan → RED** (`_acc_boss_phantom.csc` now uses the already-packed
`acc/light/fx_perk_glow_red`, no new asset); and **all temporary diagnostics removed** (the `[PH]` spawn
trace + `plog`, the `[SPD]` speed probe — only the standard gated `pdebug` remains). `-GscOnly`. docs/34 updated.

### Fixed — Phantom (red) vs Glitch Stalker (teal) auras decoupled + Glitch dimmed 25% (user, 2026-06-24)

Making the Phantom glow red also turned the **Glitch Stalker** red — both bosses drove the **same** 1-bit
`accPhantomAura` clientfield and the single `level._effect["acc_phantom_aura"]` FX (the Glitch calls
`acc_boss_phantom::set_phantom_aura`). Fixed by **colour-coding the shared field**: widened `accPhantomAura`
to **2 bits** (0 off / 1 red / 2 teal) in lockstep (`.gsc` + `.csc`); `set_phantom_aura` now reads a per-actor
`ent.acc_aura_color` (default 1 = red Phantom), and the Glitch sets `acc_aura_color = 2` before raising its
aura; the `.csc` `aura_cb` maps the value → the matching FX. Also **dimmed the Glitch's teal 25%**: added a
brightness scale to `tools/gen_perk_glow_fx.js` and generated a **separate** `fx_perk_glow_teal_dim` (@75%) so
the **PaP machine's** teal (shared `fx_perk_glow_teal`) stays full-bright; new `fx,` zone line + `.csc`
precache. So now: Phantom = red, Glitch = dimmed teal, PaP machine = full teal. `-GscOnly` (FX packs via the
linker, no geometry).

### Changed — PaP damage ladder → linear +33.33%/pack, T3 = +100% MAX (user, 2026-06-24)

`pap_tier_mult` **1.5 / 2.0 / 2.5 → 1.3333 / 1.66666 / 1.999999** (`_acc_pap_levels.gsc`). Now a **linear**
ladder: each pack adds a flat **+33.33% of base**, so a PaP-only body shot is ×1.3333 / ×1.66666 / ×1.999999
= **+33% / +67% / +100%** over base — **T3 MAX = double damage** (was +150%). Applied as the additive
`bonus_sum` layer in `_acc_damage::on_ai_damage`. docs/05 PaP table + ceiling note updated. `-GscOnly`.

### Fixed — Wall-buys now have CHALK outlines + sit flush ON the wall (user, 2026-06-24)

The previous wall-buy pass (Five-Seven @ Lab / Olympia @ Bus Station / frag grenade @ Spawn) shipped two
defects: **(a) no chalk outline** — abandoned on a *false* "the chalk material's `lit_emissive_transparent`/
`_scroll` shader won't compile → UNRECOVERABLE linker error" claim; and **(b) the gun floated ~15-17u off the
wall** (the model struct sat at the trigger origin, z50, instead of on the wall face). Both fixed by returning
to the **proven early recipe** (commit `0044a16`, the `t7_zm_chalk_buy_icr1` wall-buy that built + worked
flawlessly): per wall-buy, an inline worldspawn **chalk mesh** on the wall face (42×42u, 2u proud, `contents
nonColliding`) + a `weapon_upgrade` trigger + a model struct, all co-located ON the wall and angled into the
room (facing convention verified vs the early ICR/Bowie wall-buys AND the stock `t6_olympia` prefab: model
angles `0 0 0` → faces +y/north room; `0 180 0` → faces -y/south room). Chalk tokens
`mtl_t6_wpn_pistol_kard_wall_chalk` / `mtl_t6_wpn_shotty_olympia_wall_chalk` / `t7_zm_chalk_buy_frag` are plain
`material.gdf` colorMap assets (`.tiff` sources verified on disk in the installed `skye_t6_*` GDTs) — they are
**face materials, so they need NO `.zone` line** (discovered from the brush token at cod2map time). The chalk
shape is purely cosmetic; the hint text + weapon/nade granted come from `zombie_weapon_upgrade` + the CSV
(unchanged 500/500/100), so a generic outline is fine. Also dropped a stray `script_string "1"` the trigger
structs carried (the proven `weapon_upgrade` structs never had it — it risked acting as a bogus zone filter).
**FULL build WITH LED bake passed** (`.led` newer than `.d3dbsp`, fresh `.ff`); all three chalk materials +
images confirmed in the packed assetlist. `map_source/.map` + `_acc_map_randomizer.gsc` whitelist (unchanged) +
zone comment + docs/05.

**Follow-up — CHALK ONLY (user 2026-06-24):** with the chalk now on the wall, the server-spawned 3D
gun/monkey-bomb model was redundant ("two things in each spot"). Disabled the `spawn_acc_wallbuy_models()`
call in `_acc_map_randomizer::init` (function kept defined, uncalled) so each spot shows ONLY the chalk
outline. GSC-only (`-GscOnly`; the chalk geometry was already baked).

### Changed — Trench zombie kill payout 10 → 20 points (user, 2026-06-24)

Surge/drip-spawned trench zombies (tagged `acc_trench_zombie`) now pay **20 points** per kill, up from 10
(`_acc_points.gsc::on_zombie_death`, dvar `acc_trench_zombie_points` default 10 → 20). They remain a pure
flat award — no damage-share split, headshot/knife bonus, or Kinetic Battery accrual, and still excluded from
the round count. Documented in docs/34 flags reference. `-GscOnly`.

### Changed — Glitch Purge: all-down now ENDS the purge (doors open, glitches gone, no reward) (user, 2026-06-23)

When EVERY player in the purge is down, the challenge now ends immediately so they can be revived:
`_acc_lockdown_challenge::watch_fail` calls `challenge_fail` UNCONDITIONALLY on all-down — `teardown_common`
unseals the doors (revive valve) + despawns all the purge glitches, and fail grants NO reward. Previously it
only unsealed when an OUTSIDE player was still alive (solo / whole-team-down was left to the stock game-over);
now it ends in every all-down case (solo Quick-Revive, or a teammate reaching the room). `-GscOnly`.

### Changed — Glitch Purge count = round × 2 (was × 2.5) (user, 2026-06-23)

`ACC_LDC_ROUND_MULT_DEF` 2.5 → **2.0** (`acc_lockdown_challenge_mult`), so the auto purge count is now
**current round × 2** (e.g. r10 → 20, r20 → 40) instead of × 2.5. `_acc_lockdown_challenge.gsc` + its comments.
`-GscOnly` (auto-builds when the game closes).

### Changed — Phantom: 100k HP × players, spawns EVERY round (was 10× round-zombie, every 10) (user, 2026-06-23)

`_acc_boss_phantom.gsc`:
- **HP = flat 100,000 × player_count** (linear, same as Brutus): solo 100k / 2p 200k / 3p 300k / 4p 400k.
  Replaces the old `10 × the round's normal zombie health` (which scaled with the round).
- **Spawns EVERY round** from its first round (8): `ACC_PHANTOM_INTERVAL_DEF` 10 → 1 ("spawn with the
  round"). A **one-at-a-time guard** (`run_round_boss` checks `level.acc_phantom_host` isalive) prevents
  stacking — since the Phantom fights alongside the wave and never gates round end, it can outlive its
  round; a new one only spawns once the previous is dead.
- Confirmed already-correct (no change): top-screen boss health bar (`acc_boss_spawned` → `_acc_health_bars`,
  "PHANTOM" nameplate) and enabled in BOTH dev and non-dev (`ACC_PHANTOM_ENABLE_DEF = 1` + dev bypass).

### Fixed/Changed — Loot Stash reworked to a FLAT per-kill bonus (the +10% was invisible) (user, 2026-06-23)

The Loot Stash boss item "didn't seem to work": its **+10% Points** was swallowed by the points floor-to-10
(a 60-pt kill → `60×1.10 = 66` → floored back to **60** = zero bonus; it only ever survived on shares ≥100).
Replaced with a **flat per-kill bonus to the KILLER**: **+10 / regular kill, +20 / headshot kill**, **×2 with
Double Points** (the bonus rides the killer's award so the Double-Points scalar doubles it, and being a
multiple of 10 it survives the floor). Plus a **Nuke now pays a holder 500** (was the stock 400), and **1000
with Double Points** — a new `_acc_points::ledger_nuke_watch` tops up each holder on the stock `"nuke_complete"`
notify (×`double_points_scalar`). Removed `ACC_POINTS_LEDGER_MULT`; added `ACC_LEDGER_KILL_BONUS` /
`_HEADSHOT_BONUS` / `_NUKE`. `_acc_points.gsc` + `_acc_boss_items.gsc` comment + docs/12. `-GscOnly`.

### Added — Power-up icons blink in their last 4 seconds (user, 2026-06-23)

The timed power-up icons (Insta-Kill / Double Points / Fire Sale) on the custom HUD now **blink during their
last ~4s** like base zombies — speeding from ~2.5 Hz to ~5 Hz under 2s. Implemented server-side by flickering
the power-up's bit in the existing `accPowerupMask` clientfield (no new HUD field — the pool is full), so the
custom Ronan icon flashes with **no LUI/art change**. `pu_show_bit` self-clocks each one's 30s lifetime off its
activation edge (Insta-Kill runs its own stock `wait` with no readable countdown var, so all three are clocked
the same way); instant pickups (Nuke/Max Ammo) don't blink — no countdown to run out. Poll raised 0.25s → 0.1s
so the blink samples cleanly. `_acc_lui.gsc`, `-GscOnly`.

### Removed — Glitch Stalker "inbound" banner (user, 2026-06-23)

The on-screen **"GLITCH STALKER inbound"** `IPrintLnBold` is removed in BOTH normal and dev play (the call +
the `announce_inbound` function deleted from `run_glitch_wave`). It fired at the same instant the Stalkers
arrived, so it warned of nothing; the cyan aura + stock-Giant skin remain the visual tell. `_acc_boss_glitch.gsc`, `-GscOnly`.

### Changed — Brutus HP cut 250k → 50k + LINEAR coop scaling (took forever to kill) (user, 2026-06-23)

`ACC_BOSS_MINI_HP` 250,000 → **50,000** (`_acc_boss.gsc`; back to the 1× "50k baseline", after 5×/250k and
10×/500k). Our integration OVERWRITES the NSZ pack's `brutus_base_health 3500 × round × players` formula with
this flat value. Coop scaling switched from the shared `special_hp_mult` (+0.5/extra = 2.5× at 4p) to
**`player_count()` — linear N× by player count** (user: "4 players is 4×"): **solo 50k / 2p 100k / 3p 150k /
4p 200k**. Brutus now scales 1:1 with players, matching the team's ~N× damage output. With the map's
deliberately-weak base guns, the old flat 250k was a slog.

### Changed — Insta-Kill does 6× gun damage to non-regular enemies (was glitch/no-impact) (user, 2026-06-23)

Insta-Kill on bosses/elites/Glitch Stalker/Brutus now does **6× the gun's hit** instead of the stock
instant-kill — which glitched the Glitch Stalker (it gibbed an elite that shouldn't one-shot) and did
nothing to Brutus (`no_powerups`/its own mechz-style handler ignored it). Regular zombies are still
one-shot. Implemented in `_acc_damage.gsc`:
- `level.check_for_instakill_override` = `acc_instakill_override` — returns false for non-regular so stock
  `zm_powerups::check_for_instakill` skips the gib+lethal; true for regular (stock one-shots as normal).
- `on_ai_damage` 4c block: `final_damage ×6` when Insta-Kill is active and the target `is_non_regular`
  (applied after the global buff = "6× the gun's actual hit", before record/feed so points + the crosshair
  number reflect it). `is_non_regular` = our `acc_is_*` boss/elite/mini-boss flags, stock `self.is_boss`
  (covers Brutus, no pack edit), or `acc_is_glitch_zombie`.

### Changed — Kill points retuned: body 40 → 70, headshot 100 → 110 (user, 2026-06-23)

`_acc_points.gsc`: `ACC_POINTS_REGULAR_KILL` 40 → **70** (above the stock 60), `ACC_POINTS_HEADSHOT_KILL` 100 → **110**
(knife stays 100) → headshot:body ratio ~1.57×. Flows through the 70/30 co-op split + the Double Points / Payroll
Ledger multipliers automatically. docs/06 point table updated. `-GscOnly`.

### Fixed — arsenal ammo regression + melee headshot half-damage + dropped damage numbers (user, 2026-06-23)

- **Ammo cut restored.** The 6-23 GDT regen (adding RW1/Mahem) silently reverted the gun GDTs to their
  uncut Skye ammo, and the RW1-buff `gdtdb /update` then shipped those LARGER mags/reserves for the whole
  arsenal (e.g. ASM1 `_up` 52/416 instead of 36/288, Tac-19 `_up` 10/120 instead of 6/54, Galil 50/**600**).
  Re-ran `tools/reduce_base_ammo.js` to re-apply the designed 30% cut (verified with the new read-only
  `tools/audit_gun_ammo.js`). Built with `gdtdb /update` + link so the `.ff` carries the cut values.
- **RW1 ammo consolidated** into `reduce_base_ammo.js` `CLIP_FIX`/`MAXAMMO_FIX` (8 base / 12 PaP, reserve
  56/96 — ABSOLUTE, exempt from ×0.7 since the clip-1 original would floor to 1; covers base+_up+twins via
  stemOf). Removed the one-off `tools/buff_rw1_stats.js`. RW1 stays A-tier (PaP 7.15); price buckets unchanged.
- **Melee no longer "headshots."** A knife head/neck hit was entering the bullet crit chain, where its only
  bonus layer was the `0.5` `ACC_HEADSHOT_MULT` → `bonus_factor 0.5` = **half damage + a blue number** (guns
  avoid this because their incoming damage already carries the GDT `locHead` ×5). Gated `b_headshot` on
  `!b_melee` in `_acc_damage.gsc::on_ai_damage`: melee now does full damage wherever it lands, no crit tint.
- **Melee damage numbers now show (Action Figure / Widow's-Mega knife).** The crosshair number is fed at
  the END of `on_ai_damage`, but the melee ONE-KNIFE and miss paths (`_acc_damage.gsc`: Action Figure swing,
  Widow's-Wine-Mega "Spiderman" knife) `return` early — so those swings showed NO number ("knife a zombie,
  see no damage"). Added `feed_dmg_number` to each early-return (one-knife shows the lethal damage; AF miss
  shows its 50%-max-hp chunk). The regular knife/bash already reached the feed. (Reverted an earlier
  drain/queue tweak — the cause was the early-return, not snapshot collapse.)

### Fixed — Chalk wall-buys broke the build (emissive shader won't compile); reverted to 3D models on real walls (user, 2026-06-23/24)

Chalk wall-buys were attempted (Skye `t6_olympia_wallbuy.map` prefab + custom `acc_*_wallbuy.map` copies w/ KARD
pistol + `t7_zm_chalk_buy_frag` chalks). **They broke the build:** the chalk materials use the
`lit_emissive_transparent` / `lit_emissive_scroll_transparent` shaders, which the public Mod Tools linker
**cannot compile** → 24 "Shader preprocessor error" → **UNRECOVERABLE** (the pre-chalk build had 0). Same class of
toolchain limit as the Lua/L3akMod issue, so **chalk wall-buys are not buildable here.** Reverted to **3D
weapon-model** wall-buys (compiles clean): a `weapon_upgrade` struct pair per gun + a SERVER-spawned `script_model`
(`_acc_map_randomizer::spawn_acc_wallbuy_models`) for the visible gun, models `wm_t6_five_seven` / `wm_t6_olympia` /
`wpn_t7_zmb_monkey_bomb_world` (zone-packed, non-emissive). Also **fixed placement** — they had been floating at
zone-volume edges; now mounted on the REAL wall brushes found via `tools/list_walls.js`: Five-Seven on the Lab
south wall (y3068, room north), Olympia on the corp south-rim wall (y1703), grenade on the Plaza north wall (y720).
Chalk `material,` lines removed from the `.zone`; the `acc_*_wallbuy.map` chalk prefabs are now dead/unreferenced.
Build clean (0 shader errors), bake passed. Memory `wallbuy-system-box-only-whitelist` updated. Model angle/position
still best-effort — nudge in-game.

### Fixed — Twinned guns reverted to FULL mags/reserve (user report: ASM1/Tac-19 bigger than intended, 2026-06-23)

Running `apply_recoil_overhaul.js` (3× this session to twin M60/RPD/RW1) restored each base gun GDT from its
`.acc-orig` backup (FULL ammo) and re-scaled recoil — silently **reverting the 30% ammo cut** (`reduce_base_ammo.js`),
which the recoil tool's header says must be re-run after it. Result: every twinned gun got its full mag/reserve back
(ASM1 clip 32 not 22, Tac-19 6 not 3, AK-47 30 not 21, etc.). **Fix:** re-ran `reduce_base_ammo.js` (206 clip fields
×0.70) + `gdtdb /update` + build. Refreshed the twin GDT's stale `acc_weapon_variants.gdt.acc-ammo-orig` first (it
held the OLD 140-twin set — running the cut against it would have reverted the 182 twins). Added `skye_s1_rw1.gdt` to
the ammo tool's GDTS list so RW1's base + twins are both cut (consistent); Mahem left uncut (launcher). Verified
ASM1 22 / Tac-19 3 / AK-47 21 post-cut. Memory: `recoil-tool-reverts-ammo-cut` — **always re-run the ammo tool after
the recoil tool.** Consider auto-chaining it.

### Fixed — The 3 new wall-buys were invisible + unusable (user report "I dont even see them", 2026-06-23)

Root cause was two-fold: (1) the display models `wm_t6_five_seven` / `wm_t6_olympia` had **no `.zone` line**, so the
stock code's `tempModel setModel(target_struct.model)` (which it uses to size the PURCHASE TRIGGER, `_zm_weapons.gsc:943`)
got a degenerate model → near-zero-size, unusable trigger; (2) the visible wall gun is drawn **client-side** via
`spawn_buildkit_weapon_model(weapon)` (`_zm_weapons.csc:310`), which renders **nothing** for Skye-port guns or grenades.
Fixes: **packed** `wm_t6_five_seven` + `wm_t6_olympia` (zone); new `_acc_map_randomizer::spawn_acc_wallbuy_models()`
spawns the gun model **server-side** (`script_model`, replicates to all clients — unlike the client buildkit) at each
model-struct origin; and `script_string "1"` on the 3 trigger structs (bigger trigger, no look-at required). Full
geometry build, bake passed. Memory `wallbuy-system-box-only-whitelist` updated with the gotcha.

### Changed — Mahem + Thundergun now Overclock; Action Figure is the only OC-exempt weapon (user, 2026-06-23)

`weapon_name_to_family` (`_acc_overclocks.gsc`): added a `special_list` (`s1_mahem`, `thundergun`) returning a new
`"special"` family so both tier up; removed `s1_mahem` from `none_list` and `thundergun` from `wonder_list`; added
`t8_melee_figure` to `none_list`. The `"special"` value only needs to be non-`none`/`unknown` to gate overclocking
on — the OC effects are tier-based and family-agnostic (verified `weapon_name_to_family` has one caller). Both gain
the **+damage** and **+vs-glitch** tiers (keeps a launcher / wonder weapon lethal at high rounds); the third tier
(headshot kills → ammo) is **inert** on them since explosions / wind-blast don't headshot — harmless. PaP also
confirmed working for both (Thundergun → `thundergun_upgraded`, Mahem → `s1_mahem_up`). `-GscOnly`, BUILD OK.
- **Cosmetic gap:** the OC kiosk report card shows a generic/stale name for these two (Mahem → "Held weapon",
  Thundergun → the old "Wunderwaffe DG-2" label) — the OC works, only the card label is off (`gun_card_index` +
  `acc_hud.lua` AccGunNames not updated). Fixable later.

### Added — Action Figure melee QUIRK: a chance-based one-knife that scales with PaP + exo (user, 2026-06-23)

The Action Figure now has a signature mechanic instead of flat melee damage. Each swing **vs a regular zombie**
rolls a **one-hit-kill chance**; on a hit it instakills, on a miss it deals **50% of the victim's max health**
(so a miss still chunks — two misses = a kill). The chance scales:
**`50% base + 10% per PaP tier (0–3) + 4% per Exo Suit tier (0–5)`, capped at 100%** — so base 50%, PaP1/2/3 =
60/70/80%, and **PaP3 + max exo = 100% (always one-knife)**. Bosses/elites are exempt (they take normal melee
damage, never a chance-kill). Implemented as its own logic for this one weapon:
- `_acc_damage::on_ai_damage` — weapon-name-gated short-circuit (like the Spiderman Widow's one-knife) +
  `acc_actionfigure_onehit_chance()`.
- **Made the melee PaP-able IN PLACE** (it has no `_up` form): `_acc_pap_levels::is_actionfigure` +
  `pap_weapon_packable` exception + a dedicated `acc_pap_actionfigure()` that charges the BOT-bucket price
  (3000/4500/6000) and bumps `acc_pap_tier` 1→2→3 with the normal pack sounds — no asset swap, no ammo fill.
  The gun pack/transform flow is untouched. **Needs a game-closed `-GscOnly` build.**

### Changed — Pack-a-Punch cost is now PER-GUN by price tier (rank terciles on PaP-form power) (user, 2026-06-23)

PaP no longer charges a flat 5000/7500/10000 for every gun. Each gun's per-step cost now scales with how
good it is **at its fully-packed ceiling**: every gun is scored by the docs/05 "v2 sustain" formula on its
**PaP-form** stats, ranked best→worst, and split into thirds — **TOP 5000/7500/10000 · MID 4000/6000/8000 ·
BOT 3000/4500/6000**. The 10% Armory discount now applies to the first pack too (was tier-ups only).
- **New balancer + doc:** `tools/compute_gun_tiers.js` computes the scores, ranks, splits into terciles, and
  **generates [docs/54_pap_pricing_tiers.md](docs/54_pap_pricing_tiers.md)** (ranking table + the GSC
  `pap_price_bucket()` / `tier_cost()` to paste). Add/remove a gun → edit the script's roster, re-run, paste,
  rebuild. Rank-tercile = relative, so the tiers always stay evenly populated.
- **PaP-form stats GDT-verified** (workflow `pap-form-gdt-stats`, 12/12 gather=verify). Corrected two stale
  doc claims: **Five-Seven's PaP is single-wield `t6_fiveseven_up`, NOT akimbo** (no DPS bump → B); the AR/SMG
  PaP magazines are much larger than the old doc T3 table (e.g. Tac-19 10/120, Galil 50/600).
- **Tiers (TOP/MID/BOT):** TOP = Tac-19, M60, AK-74u, Paladin, PPSH-41, Thundergun; MID = AK-47, AE4, ASM1,
  RW1, Mahem; BOT = Galil, Five-Seven, RPD, Olympia. PPSH-41 pinned TOP (`force`); **RW1 BUFFED to a real
  magazine** (`tools/buff_rw1_stats.js`: install-side GDT clip 1→8 base / 1→12 PaP, reserve 56/96, backed up,
  needs `gdtdb /update` + link) so it EARNS A (7.15) on merit instead of a `force` pin — which pushed **Galil
  (7.01) down into BOT** (strict rank-terciles, user-confirmed: 5 A-score guns, only 4 MID slots);
  Mahem/Thundergun hand-tiered (specials); **Action Figure unpriced** (no `_up` form, can't be packed).
- **GSC:** `_acc_pap_levels.gsc` — added `pap_price_bucket()` + `tier_cost()` + `weapon_tier_cost()` (replaced
  the flat `tier_repack_cost()` / `ACC_PAP_TIER_COST_2/3`); the cost-display keeper + first-pack now read the
  per-gun price; tier-0 first-pack price is overridden per held gun, **guarded so a Bonfire Sale (if ever added)
  still wins**. `-GscOnly` build pending.
- **Mystery-box odds re-based on the SAME PaP tiers** (user 2026-06-23): `_acc_map_randomizer.gsc::acc_box_weight`
  now weights by price tier (WW 1 / TOP 3 / MID 5 / BOT 7; higher = commoner), also generated by
  `compute_gun_tiers.js`. Box pool grew to **16 weapons (total weight 72)** with RW1/Mahem/Action Figure. Net:
  AK-74u + PPSH-41 became rarer (rose to TOP), ASM1/Galil rarer (MID); best guns are now both rarest to roll and
  priciest to pack. Replaces the old base-tier weights (which still referenced removed guns). docs/05 + docs/54 updated.

### Added — RW1 (AW energy pistol, twinned) + Mahem (AW explosive launcher, exempt) — both A-tier (user, 2026-06-23)

Two AW-pack guns added to the box (assets already installed with the AW pack; no new download). `-GscOnly` build OK
(35.69 MB `.ff`); **needs a boot test** (now 182 twins). Both **A-tier box odds** (`acc_box_weight` = 5).
- **RW1 (`s1_rw1`)** — AW directed-energy PISTOL. FULLY TWINNED (verified `bulletweapon`/single-wield/regular
  `s1_rw1_up`/empty altWeapon): added to `variant_guns()` + `apply_recoil_overhaul.js` GUNS (13 guns × 14 = **182
  twins**, under the ~230 cap). Wired: CSV row, zone lines, box pool, balance (`acc_weapon_balance_mult` = 0.11,
  ~590 eff, A-tier), Overclock `pistol` family, Precision Mode ability.
- **Mahem (`s1_mahem`)** — AW molten-metal ROCKET LAUNCHER, the user's explosive. **EXEMPT special** (projectile,
  NOT twinned — like the Thundergun WW; ~2 registrations, doesn't touch the twin budget). Empty altWeapon → no
  `_zm_zm` Com_ERROR. **Explosive-damage trap handled:** raw 7000 direct + 2750/1500 splash would over-scale through
  `acc_weapon_balance_mult` × the global 1.5× (the old M1911 lesson), so it gets a low explicit mult **0.35** (~3675
  direct post-global, one-shots ~r22 + scaled splash). Overclock-exempt (`none_list`). Tune the explosive in playtest.
- **CSV repair:** `zm_levelcommon_weapons.csv` had **merged rows** (PPSH/Paladin/Olympia had lost their own lines,
  breaking those guns) — rewrote the file cleanly (one weapon per row), preserved the `t8_melee_figure` row.
- **Sounds imported (2026-06-23):** the AW wavs were already installed (`sound_assets/skye_ports/s1_rw1`, `…/s1_mahem`),
  so the 26 canonical alias rows (13 each) from the pack's `ADD TO USER_ALIASES.txt` were appended to
  `acc_skye_box_weapons.csv` and the sound bank rebuilt game-closed (`.sabl` 24.3 → 27.3 MB). Both guns are audible.
  Models load fine (only non-fatal DROPPED VERTS warnings).

### Added — Action Figure melee weapon (BO4 t8 port by T0nic) — box S-tier (user, 2026-06-23)

A fun handheld melee weapon: you equip the Action Figure and swing it (BO4 `t8_melee_figure` + its
`t8_actionfigure_melee` offhand). **Source is a gitignored external asset** (rip port → TEST-ONLY until IP
review; see CREDITS + `tools/external_assets_manifest.ps1`). Pipeline: installed the pack into the Mod Tools
(`model_export`/`xanim_export`/`source_data\t8_weapons`), `gdtdb /update`, two `.zone` `weapon,` lines + a
`zm_levelcommon_weapons.csv` row, and the box pool + **S-tier weight (3 — with the M60/Paladin)** in
`_acc_map_randomizer`. **Box-only delivery** — rolled from the Mystery Box like any gun (no dev give / no
special grant). **Fixed two amateur-port bugs** the linker flagged (`tools/fix_actionfigure_port.js`, idempotent):
`sharedWeaponSounds "melee_sounds"` (invalid BO4 bank) → stock `"fist"`, and a missing 6th model material
(`xmaterial_1cc1a388339cec8`) cloned from an existing one. Build-verified: 24 AF assets packed in the `.ff`,
zero linker errors. `-GscOnly`.

### Changed — Every box gun now FULLY benefits from Mega perks: twin M60/RPD, remove 4 un-twinnable guns (user, 2026-06-23)

The Mega-perk **handling** buffs (Deadshot Mega −50% recoil, Gun Slinger fire-rate, Speed Cola Mega reload)
are delivered by pre-baked weapon "twins"; guns that can't be twinned silently missed those buffs. User rule:
**"any gun that can't be fully twinned, remove it."** Result — every conventional box gun is now fully twinned;
only the Thundergun (wonder weapon) is exempt by design. Box went **17 → 13 guns** (12 twinned + WW); twin count
**140 → 168** (still under the ~230 boot-proven cap). `-GscOnly` build OK (35.36 MB `.ff`); **needs a boot test**
(the twin cap is only provable by launching).
- **Twinned M60 + t6_rpd** — verified clean (single-wield `bulletweapon`, regular `_up`, empty `altWeapon`).
  Added to `apply_recoil_overhaul.js` GUNS + `_acc_weapon_variants::variant_guns()`; the tool regenerated the
  variant GDT (+28 twins), rewrote the zone to 168 twin lines, and ran `gdtdb /update`. Their long reloads
  (9.7s / 7.5s) make the Speed Cola Mega twin especially valuable.
- **REMOVED Ripper (`iw6_ripper_smg`), Nail Gun (`t9_nail_gun`), PDW-57 (`s1_pdw`), M1911 (`s2_m1911`).** None
  could be fully twinned: Ripper = convertible `altWeapon` (swap fights the mode toggle), Nail Gun =
  `projectileweapon` (the twin tool only clones `bulletweapon`), PDW/M1911 = akimbo PaP (`_rdw_up`/`_ldw_up`,
  one `up` slot can't emit dual-wield twins). Stripped from every integration point: box pool + tier weights
  (`_acc_map_randomizer`), weapon CSV rows, zone `weapon,` lines, **71 sound-alias rows** (`acc_skye_box_weapons.csv`),
  damage balance (`_acc_damage`), overclock families (`_acc_overclocks`), OC report-card index (`_acc_perk_info`),
  weapon-ability categories (`_acc_weapon_abilities`). Install-side GDTs left in place (just unreferenced).
- **Five-Seven + AK-74u confirmed SAFE** — verified the CSV `upgrade_name` is the single-wield `t6_fiveseven_up`
  / irregular-but-handled `t5_ak74u_up_zm`, both covered by their twins. The starting pistol stays.

### Changed — Wonder weapon swapped: Wunderwaffe DG-2 → Thundergun (user, 2026-06-23)

The box's S+ wonder weapon is now the **Thundergun** (`thundergun`, wind-blast knockback) instead of the
Wunderwaffe DG-2 (`tesla_gun`). Same recipe — both are stock no-download WWs cooked in `zm_levelcommon`
(`is_wonder_weapon=TRUE`), so it's a `-GscOnly` swap with **stock-cooked SFX + PaP** included:
- **CSV** (`gamedata/weapons/zm/zm_levelcommon_weapons.csv`): the `tesla_gun` row → the authoritative stock
  `thundergun,thundergun_upgraded,…,special,TRUE,TRUE` row (`is_limited`=1, one in the world at a time). PaP
  target = `thundergun_upgraded` (cooked); `weaponVO=thundergun` (cooked firing sounds ship with the def).
- **Box pool** (`_acc_map_randomizer::register_mystery_box_pool` `box_weapons[]`): `"tesla_gun"` → `"thundergun"`.
- **Tier weight** (`acc_box_weight`): `thundergun` = **S+**, weight 1 (~1%, rarest box roll) — unchanged tier.
- **Overclocks** (`_acc_overclocks` `wonder_list`) + **perk-info** (`_acc_perk_info` index 16): `tesla_gun` → `thundergun`.
- `-GscOnly`, lint clean, BUILD OK. **⚠ LAUNCH-VERIFY** (BUILD OK ≠ runtime, like any stock WW): box-roll until
  Thundergun appears, confirm it draws + fires (wind blast) + PaPs to `thundergun_upgraded`. If it never shows,
  the box log prints `! box weapon missing from weapon table: thundergun` (graceful degrade, no crash).

### Added — Three fixed wall-buys: Five-Seven @ Lab, Olympia @ Bus Station, frag grenade @ Spawn (user, 2026-06-23)

First wall-buys on the map (it was box-only since 2026-06-14). Uses the **stock** `weapon_upgrade` system
end-to-end, so buy-gun → buy-ammo is automatic and the ammo price keys off the player's PaP level
(`has_upgrade` → 4500, else ~half the gun cost) — exactly the "buy ammo depending on level of gun" ask.
- **Prices** ([zm_levelcommon_weapons.csv](gamedata/weapons/zm/zm_levelcommon_weapons.csv) `cost`): `t6_fiveseven`
  900→**500**, `t6_olympia` 1500→**500**, `frag_grenade` 250→**100** (+ `ammo_cost` 250→**100**). All three were
  already registered zombie weapons, so no `get_weapon_cost` assert risk.
- **Re-enabled for these 3 only**: `_acc_map_randomizer::remove_all_wallbuys()` (the box-only enforcer) now
  **whitelists** `t6_fiveseven` / `t6_olympia` / `frag_grenade` (skips removing their stubs); everything else
  stays box-only.
- **Geometry**: 3 `weapon_upgrade` struct pairs added to the `.map` (trigger struct → model struct), placed on
  the **Bus-Station-facing interior wall** of each room (user 2026-06-23, read off the `docs/map_design.png`
  render): Five-Seven on the **Lab south wall** ≈ (0, 3064, 40), grenade on the **Plaza/start_zone north
  (barricade) wall** ≈ (50, 235, 40); Olympia in the Bus Station ≈ (−700, 1948, 40). Display models:
  `wm_t6_five_seven` / `wm_t6_olympia` (runtime-loaded by the weapons, no zone line) and
  `wpn_t7_zmb_monkey_bomb_world` as the grenade placeholder. May still need a small in-game nudge to sit flush.
- **Build**: full geometry build (cod2map + LED bake + linker) — bake passed, fresh `.ff`. docs/07 + docs/05 updated.

### Fixed — Double Points powerup did nothing on kill points (user report, 2026-06-23)

**Bug:** Double Points never doubled kill points. The custom economy (`_acc_points.gsc`) suppresses the stock kill
award (`suppress_stock_kill_score` returns 0 via `register_score_event`) and pays out through its own `award_player`
→ `zm_score::add_to_player_score`. But the stock x2 is applied in `_zm_score::get_points_multiplier` (`_zm_score.gsc:339`)
to the *score-event callback's return value* — which we zeroed — and `add_to_player_score` itself applies **no**
multiplier. So the powerup's `level.zombie_vars[team]["zombie_point_scalar"] = 2` (`_zm_powerup_double_points.gsc:79`)
never reached our points; the HUD icon showed but points were unchanged.
**Fix:** `award_player` now multiplies by a new `double_points_scalar(player)` helper that reads the same team-scoped
`zombie_point_scalar` var stock uses (defensive → 1 if unset). Applied to the base **before** the Payroll Ledger bonus
so they stack multiplicatively (docs/12: "Double Points doubles the base, Ledger +10% on top" = x2.2). Covers kills,
co-op damage-shares, and the trench-zombie flat award (all route through `award_player`). `-GscOnly`.

### Changed — Overclock flat-damage buff doubled to +10%/tier (user, 2026-06-23)

`ACC_OC_DMG_PER_TIER` (`acc_oc_dmg_per_tier`) 0.05 → **0.10**, so the gun Overclock's always-on flat-damage
effect is now **+10% per tier → +50% at T5** (was +5% → +25%). Only effect 1 of 3; Glitch Piercing (+125% at
T5) and Ammo refund (50% at T5) unchanged, and the Exo Suit's separate melee scaler (`acc_exo_melee_per_tier`)
is untouched. `_acc_damage.gsc` + comments; docs/46 (per-tier table) + docs/47 + `_acc_overclocks.gsc` header
synced. `-GscOnly`.

### Fixed — Glitch Stalker now spawns near you, not in a random open zone (user, 2026-06-23)

"No glitch zombies in the Plaza until power is on." Root cause: `spawn_promoted_zombie` picked a FULLY RANDOM
`level.zombie_spawners` entry. That array is already active-zone-only (the zonemgr adds/removes spawners as
zones open — `_zm.gsc:3885/3918`), but a random pick scattered the boss across EVERY currently-open zone, so it
often spawned somewhere other than where you were standing (most visible pre-power, with the start area + a
couple of bought zones open). Fix: new `nearest_spawner_to_player()` — spawn at the active spawner closest to a
random living player, so it always appears in the player's area and comes for them. Falls back to a random
active spawner if no living player. `_acc_boss_glitch.gsc`, `-GscOnly`. (Visibility was already fixed via the
cyan aura; this is the placement half.)

### Changed — Boss items: TWO active slots + two-pad bench + implant sound (user, 2026-06-23)

Boss items go from **1 active slot to 2** (docs/12). Design decisions (user): two bench **pads** (pick a slot by
which pad you use), **any empty slot is free** (so first two are free; replacing a full slot = 2500), grenade pair
**last-one-wins**, and a **new dedicated implant sound**. All in `_acc_boss_items.gsc` except the move-speed clamp
(`_acc_utility.gsc`) and the sound alias. Built game-closed `-GscOnly` (BUILD OK, fresh 36 MB `.ff`); the new wav's `.sabl`
bank rebuilt automatically because the game-closed sound `/MIR` sync purges the unlocked stale `CachedBanks` and the linker regenerates them.
- **State model rewrite.** `acc_equipped_items` is now a **fixed 2-element array** (index 0 = Slot 1, 1 = Slot 2;
  `""` = empty) and the single source of truth. The scalar `acc_active_item` and the `acc_bench_first_done` bool are
  **deleted**; "is it implanted" scans both slots via `player_has_item()`, "free" = `slot_is_empty(slot)`. New
  slot helpers `empty_slots` / `slot_is_empty` / `equip_slot` / `unequip_slot` replace the old `equip_item` / `unequip_item`.
- **Two bench pads.** `spawn_bench()` now spawns two `spawn_bench_pad(org, slot)` triggers (fixed `acc_bench_slot`),
  separated along Y (`acc_bench_pad_sep` 56) with a small radius (`acc_bench_pad_radius` 40) so volumes don't overlap.
  Each pad fills/replaces ITS slot; per-slot hint string + iprintln.
- **Implant sound.** New `acc_item_implant` alias (`acc_audio.csv`) played once at the bench commit (never in `apply_*`,
  to avoid respawn-regrant spam). Wav = a UI-equip SFX (user download) converted to 48k/16-bit mono via
  `convert_wav_48k_mono.ps1` → `sound_assets/acc/fx/item_implant.wav`; **baked into the `.sabl` bank on a game-closed
  build** (verified: bank rebuilt at 9:38 AFTER the wav landed at 9:34).
- **Tactical "last one wins".** Li'l Arnie + Monkey Bomb both want the single tactical slot; new `acc_tactical_owner`
  tracks the last-implanted grenade. Regrant-on-spawn fires only for the owner; each `remove_*` captures `was_owner`
  first and only hands the tactical to the surviving grenade item (or clears it) **when the removed grenade actually
  owned it** — so replacing a grenade slot while the OTHER grenade is the live tactical no longer needlessly re-grants
  it (which had reset its ammo to 4). No nondeterministic regrant fight or co-resident disarm. (Review-found bug fixed.)
- **Move-speed clamp.** `recompute_move_speed` caps the total at `acc_move_scale_cap` (2.2) since two mobility items
  (Boots × Gas/Rocket) can now stack on top of Cyberware/Mega speed.
- **HUD.** `sync_items_hud` shows up to two numbered implant lines (`IMPLANT 1` / `IMPLANT 2`) + `CARRYING`, server-side
  font string only (no LUI / no clientfield). Carry-suppression now uses `player_has_item`.

### Changed — Difficulty cut, pass 1: nerf zombies + buff guns (user, 2026-06-23)

First batch of the "decrease difficulty a lot" pass (analysis: difficulty-scaling audit). All `-GscOnly`:
- **Glitch Stalker spawns far less often + smaller waves.** `ACC_GLITCH_FIRST_ROUND_DEF` 2 → **4**
  (`acc_glitch_first_round`), `ACC_GLITCH_INTERVAL_DEF` 1 → **2** (`acc_glitch_interval`): was every round
  from r2, now r4/6/8/10… (every 2nd round). Per-wave count formula changed `floor((round-2)/2)+1` →
  **`floor((round-2)/2)`** (dropped the +1 so it starts at 1): r4 = 1, r6 = 2, r8 = 3, r10 = 4, … (was r4 = 2 …).
  Also **HP 3× → 1.5×** the round's normal zombie (`acc_glitch_hp_mult`, now read as a float so 1.5 works) — 3× was too tanky.
  And **~25% less aggressive**: blink cadence `acc_glitch_blink_cd_min`/`_max` 1.0/1.665 → **1.33/2.22** (×1.33 = 25% fewer
  teleport-blinks), hidden-charge `acc_glitch_charge_speed` 900 → **675** (−25%, closes the gap slower), camper-pounce
  `acc_glitch_pounce_cooldown` 1200 → **1600 ms** (pounces ~25% less often). `_acc_boss_glitch.gsc`.
- **All guns +50% damage — single global knob.** New `ACC_GLOBAL_DMG_MULT` (1.50 — started at 1.20/+20%, user
  2026-06-23 bumped 1.20 → 1.32 → 1.50) applied as a flat FINAL multiply on all PLAYER damage in
  `_acc_damage::on_ai_damage`, OUTSIDE the bonus-sum/reduction buckets, so it lifts every gun uniformly while
  **preserving the per-gun `acc_weapon_balance_mult` tiers**. Live dvar `acc_global_dmg_mult` (1.0 = off).
  M1911 base table value left untouched. `_acc_damage.gsc`.
- **More perk access.** `ACC_PERK_DOORS_OPEN_PER_ROUND` 3 → **4** (4 of 9 Lab machines open per round).
  `_acc_perk_doors.gsc`.
- **Faster shard faucet.** Pit Data Caches pay **2** each (was 1): `acc_cache_w_count` / `acc_cache_e_count`
  defaults 1 → 2. `_acc_glitch_altar.gsc`.
- **Gentler, slower early-round speed ramp.** `ACC_ZSPEED_SPRINT_ROUND_DEF` 10 → **15** (`acc_zspeed_sprint_round`)
  and the jog ramp `ACC_ZSPEED_JOG_STEP_PCT_DEF` 2 → **0.5**/round (`acc_zspeed_jog_step_pct`, now read as a float).
  Rounds 1-14 stay near the natural jog (100 → 106.5%) instead of the old +2%/round, and the horde doesn't break
  into the full sprint gait until r15 (was r10). Net: the early-mid game is SLOWER than before — round 9 is ~104%
  vs the old ~116%. Round-1 start speed (jog 100%) is unchanged. Cut from a brief mis-tune (jog_step 2.75) that
  overshot the sprint by mid-game; the sprint gait is barely faster than the jog, so the jog must stay low.
  `_acc_zombie_speed.gsc`, `-GscOnly`.

### Changed — Glitch Purge (lockdown challenge): kill count = round × 2.5, was a flat 15 (user, 2026-06-23)

The purge count now **scales with the round**: `current round × 2.5` (e.g. r10 → 25, r20 → 50), so the
challenge stays meaningful at every depth instead of a flat 15. New `ACC_LDC_ROUND_MULT_DEF` 2.5 (dvar
`acc_lockdown_challenge_mult`); `ACC_LDC_TOTAL_DEF` repurposed 15 → **0** = AUTO (round-based) — set the
`acc_lockdown_challenge_total` dvar > 0 to force a fixed count for testing. The total is **captured ONCE at
commit** (`level.acc_ldc_total = ldc_compute_total()`, floored, min 1) so it can't drift if the fight spans
rounds; every read site (announce / spawn loop / clear check / both HUDs) goes through the `ldc_total()`
accessor. `_acc_lockdown_challenge.gsc`, `-GscOnly`.

### Changed — Boss reward buff: Brutus 100% + 3 shards, Phantom 5 shards (user, 2026-06-22)

Tuning the boss economy up: **Brutus** all 3 drops back to **100%** (`acc_brutus_reward_chance` 0.75 → **1.0**)
and its shards **2 → 3** (`acc_warden_shard_reward`); **Phantom** shards **2 → 5** (`acc_phantom_shard_reward`).
So Brutus = guaranteed 1 item + 1 Mega + **3** shards (everyone); Phantom = guaranteed 1 item + 1 Mega + **5**
shards (everyone). `_acc_boss.gsc` / `_acc_boss_phantom.gsc`, docs/53 updated. `-GscOnly`.

### Added — Riot (Shielded) elite kill grants the killer 2 Data Shards (user, 2026-06-22)

The Shielded elite (the riotshield-bearing "Riot zombie") had no kill reward (the `elite_kill` diminishing infra
existed but no grant was wired). New `_acc_elites::shielded_death_reward` (threaded in `promote_to_shielded`):
on death, `acc_data_shards::grant_player(attacker, 2, "riot_elite")` if the killer is a player — a FLAT 2 (the
`"riot_elite"` source skips the low-round `elite_kill` diminishing). Only the Shielded class; Teleporter/EMP
unchanged. `-GscOnly`. Also added docs/53 — the full economy-source reference (shards / Mega bottles / items).

### Removed — Random PaP-approach blocker walls (deprecated feature) + door debug logs gated to dev (user, 2026-06-23)

- **Random path-blocking walls removed.** `_acc_map_randomizer::apply_pap_approach` used to leave one of the
  two lab corridors walled off each run by a tall, floor-to-ceiling, un-buyable brush
  (`acc_pap_block_roof` / `acc_pap_block_server`) — which read in-game as a "broken door" on the
  Helipad(`roof_zone`)→Lab path. That per-run random-wall mechanic is no longer in the design, so the function
  now **opens BOTH walls every run** (hide/notsolid/connectpaths) — neither corridor is ever blocked. The
  brushes stay in the `.map` (always hidden/open); `blocked_side` is ignored. GSC-only.
- **Buyable-door debug logs gated to dev.** The `[accdoor]`/`[doordbg]` on-screen readouts (added while
  fixing the doors) now only print when `level.acc_dev` is on (new `acc_door_dbg` helper + the
  `zone_door_debug` thread is dev-only). Normal play shows no door text. `-GscOnly`, lint clean.

### Fixed — Buyable zone doors show no prompt (trigger spawned at map center) (user, 2026-06-22)

The 8 buyable map doors (`zombie_door`) gave no "Open Door" prompt — walk up, can't buy. Root cause in
`zm_abandoned_cyber_city.gsc::zone_door_buy_loop`: it disabled each stock trigger and `spawn`ed a
`trigger_radius_use` at `door.origin - (0,0,120)`, but a **map-placed brush entity with no origin brush
reports `.origin = (0,0,0)`** (not its centroid) — so all 8 replacement triggers spawned **stacked at the
map center**, nowhere near a door. **Fix:** stop spawning a replacement; make the stock trigger usable
**in place** (`TriggerEnable(true)` + `TriggerIgnoreTeam()` + `SetCursorHint`/`SetHintString` on the door
entity itself, then `waittill("trigger")` on it) — its brush volume already sits in the doorway. Purchase
path unchanged (`zm_score` points → `flag::set(script_flag)` zone adjacency → `hide/notsolid/connectpaths`
the slab). `-GscOnly`, lint clean. Memory: `map-brush-origin-zero`.

### Changed — Boss rewards: Phantom = guaranteed full set; Brutus = same set at 75% each (user, 2026-06-22)

Unified the two real bosses' reward set to **1 item drop + 1 Mega Bottle to every player + 2 Data Shards to
every player**, differing only by certainty:
- **Phantom** (`_acc_boss_phantom::watch_..._death`): all three **GUARANTEED** (100%). Item now uses
  `acc_boss_items::grant_challenge_reward` (guaranteed pool drop, was the chance-based `on_boss_death("mini")`);
  added the 2-shard grant to every player (`acc_phantom_shard_reward`, default 2, "phantom" source = no diminish).
- **Brutus** / Trench Warden (`_acc_boss::watch_mini_boss_death`): the SAME set but **each reward rolls its OWN
  independent 75% chance** - 75% item, 75% Mega-to-everyone, 75% 2-shards-to-everyone. New `acc_brutus_reward_chance`
  (default 0.75); replaces the old guaranteed-item + 2026-06-18 40% Mega + always-shards structure. The dev test
  boss (`n_bottles>1`) still gets a guaranteed item + bulk Mega.
`-GscOnly`. (Glitch Stalker stays separate: 1 shard to the killer, no item/Mega.)

### Changed — Glitch Stalker reward: 1 Data Shard to the killer, no item/Mega drop (user, 2026-06-22)

The Glitch Stalker is a FREQUENT mini-boss (every round, 1-3×), so the boss-tier rewards were too generous.
`_acc_boss_glitch::glitch_death_watch` no longer calls `acc_boss_items::on_boss_death` (item drop) or
`acc_mega_bottles::on_boss_death` (Mega Bottle) — those stay **exclusive to the rare Brutus / Phantom**.
Instead the **killer gets exactly 1 Data Shard** (`acc_data_shards::grant_player(attacker, 1, "glitch_kill")`,
guarded `isplayer(attacker)`; `"glitch_kill"` tag = no low-round diminishing). `-GscOnly`.

### Fixed — Glitch Stalker invisible in the dark; added a cyan aura so it reads (user, 2026-06-22)

"Saw the inbound but never saw a glitch zombie" in the Plaza. Root cause: the Stalker IS spawning (it uses
the SAME `level.zombie_spawners` path as the elites, which work, and the cadence is **not** dev-gated -
`cadence_hits` fires every round ≥ 2 in non-dev too). The problem was **visibility** - its tell is TEAL EYES,
and the dark non-dev vision grade **washes out eye-glow shaders** (memory `zombie-eye-color-mechanism`), so it
looked like a normal charred zombie. Fix: added the **`accPhantomAura` cyan body-glow** (a client PlayFX glow,
not a grade-washed shader → stays visible in the dark) on every Stalker, in `_acc_boss_glitch::spawn_glitch`
(gated `acc_glitch_aura`, default on; `#using _acc_boss_phantom` + its already-REGISTER_SYSTEM clientfield).
`-GscOnly`. (Spawn cadence reference: round **2 onward, every round**, count **1→2→3** at r2-3 / r4-5 / r6+.)

### Removed — Decontamination / "contamination zone" seal hazard + its UI (user, 2026-06-22)

The per-round decontamination zone-seal hazard is GONE — it was never part of the final design and its `DECONTAMINATION – EVACUATE / SEALS IN 10s / SEALED` warning was firing in **normal play** (the old `level.acc_disable_decon` gate only suppressed it in the dev sandbox). `-GscOnly`, lint clean.
- **`_acc_decontamination::run_decon_phase`** now only re-emits `acc_decontamination_complete` each round (for the legacy `_acc_map_randomizer` Lab re-roll, which is itself inert). No zone is sealed, no warning UI, no player killed — in **either** mode.
- The seal chain (`run_seal_phase` with the 4 `iprintlnbold` warnings / `seal_zone` / `kill_players_in_zone` / `reentry_kill_monitor` / `roll_decon_order`) is now **dead code** (never called); `init()` no longer rolls the contamination order.
- The **module stays** (not deleted) because `_acc_lockdown` + `_acc_lockdown_challenge` reuse its zone helpers (`get_zone_volumes` / `player_in_zone_volumes` / `enable+disable_zone_spawning`) and `_acc_lockdown` reads `is_zone_sealed` (now always false). Verified no other module shows seal/contamination UI and no LUI widget exists.
- Docs: `docs/03_layout.md` "Decontamination zones" + `scripts/.../README.md` row marked REMOVED.

### Added — Buyable gate on each abyss descent (2k/3k/5k/8k) (user, 2026-06-22)

Each of the 4 abyss descent stairways (pit→L2→L3→L4→L5) now has a buyable **upright door** that blocks the
stairway until you pay **Points** to open it — a depth-gated money sink. Costs escalate: **D1 2000 · D2 3000 ·
D3 5000 · D4 8000**. Descents are sequential, so you can only reach gate k+1 by opening gate k.
- **Geometry** (`tools/gen_abyss_doors.js`): one **vertical `script_wall` door** (`acc_abyss_door_1..4`)
  standing in each stairwell's **WEST entry** (the only walk-in; the S/N/E sides are sealed with the abyss's
  128u jump-proof railings). 12u thick, 128 tall to match the rails. (Revised from the first pass, which used
  a horizontal floor-cap that read wrong.) Reuses the abyss `box()` bake-safe winding; a **distinct `-ACD0-`
  GUID marker** so `gen_abyss_layer.js`'s `-ACA2-` regen leaves them alone (and vice-versa). Bake-tested
  **BAKED** then full-built clean (navmesh regenerated).
- **Logic** (`_acc_abyss_doors.gsc`): each door starts CLOSED (show/solid/disconnectpaths); buying it
  (`zm_score` Points + the script-spawned trigger with `TriggerIgnoreTeam`, sitting just west of the door)
  opens it PERMANENTLY (hide/notsolid/connectpaths) for players AND zombies — the proven `_acc_perk_doors` toggle.
- Wired from `_acc_main::init`; zone scriptparsetree added. **Full LED build** (geometry). Needs an in-game
  pass to confirm trigger reach + that zombies path the descent after `connectpaths` (the abyss nav is finicky).

### Changed — PhD Flopper tuning + tier-split blast sound; perk-door 3-of-9 rotation restored (user, 2026-06-22)

`-GscOnly`, BUILD OK 2026-06-22 (lint clean).
- **PhD Flopper Mega slide speed 1.35× → 1.5×** (`acc_mega_flopper_slide_mult`, applied in `_acc_utility::recompute_move_speed`); stacks multiplicatively with the Rocket Shield's 1.35× → ~2.0× while sliding with both.
- **Slide-explosion cooldowns**: base **8s → 10s** (`ACC_PHD_SLIDE_CD`), Mega **5s → 8s** (`ACC_PHD_SLIDE_CD_MEGA`). `_acc_perk_phd_flopper.gsc`.
- **Blast sound now splits by tier**: the Nuke "whoomp" (`evt_nuke_flash`) plays for **Mega only**; **base** plays the stock **`def_explosion`** bomb boom (the sound the perk used before the nuke whoomp — its FX carries the boom; a bare stock sound *alias* would be muted by our standalone sound zone). Purple-Apothicon visual unchanged for both; base adds a faint orange flash. *If def_explosion's boom turns out muted in-game, the fallback is shipping a CC0 explosion wav.*
- **Perk-door 3-of-9 rotation RESTORED** (was cut 2026-06-18 = all 9 open). `_acc_perk_doors::init` now runs `if (dev_all_open()) open_all(); else close_all();` + `watch_rounds()`. Each round a random **3 of 9** Lab perk alcoves open (never repeating the prior round's 3); the other 6 are walled off. Works in **normal play AND dev** — gated only by `acc_perk_doors_all_open` (default 0), **not** `acc_dev`/`acc_open_map`; force all-9-open with `set acc_perk_doors_all_open 1`. All 9 door entities verified present in the .map and matching the specs.

### Added — Two new standalone play scripts: PLAY_GOD_MODE.bat + PLAY_NORMAL.bat (user, 2026-06-22)

Three launch scripts now, each a distinct mode (`run_game.ps1` / `PLAY_TEST_MAP.bat` left untouched):
- **PLAY_TEST_MAP.bat** — DEV sandbox (`acc_dev 1`): unlimited money, open map, test bosses, all slots.
- **PLAY_GOD_MODE.bat** (new) — regular play + GOD (`acc_dev 0 + acc_god 1`): real perks/economy/progression,
  closed map, but invulnerable, so you can playtest flow without dying.
- **PLAY_NORMAL.bat** (new) — clean normal game (`acc_dev 0 + acc_god 0`): REAL damage — the honest balance test.

God is a NEW flag `acc_god` (resolved in the entry script's `acc_resolve_dev_flags()` into `level.acc_god`,
default 0, **INDEPENDENT of `acc_dev`** — dev still has no god). When set, `acc_god_watch()` keeps every player
`EnableInvulnerability()`'d (re-applied each second). Additive — changes no existing dev/normal behavior. `-GscOnly`.

### Fixed — PaP'd PDW ammo: the REAL fix was the GDT, the GSC was clamped (user, 2026-06-22)

The earlier GSC `SetWeaponAmmoClip/Stock(17/306)` in `fill_full_ammo` didn't take — **those calls are CLAMPED to
the weapon's own `clipSize`/`maxAmmo`.** `skye_s1_pdw.gdt` shipped the errors: off-hand `s1_pdw_ldw_up_zm` clipSize
**15** (vs the main's 17) and main `s1_pdw_rdw_up_zm` maxAmmo/startAmmo **18**. Fixed in the GDT: off-hand clipSize →
**17**, main maxAmmo/startAmmo → **306**. The math: single-wield reserve = maxAmmo(mags) × clipSize (base PDW 12 × 11
= 132 ✓), but **akimbo treats maxAmmo as ROUNDS 1:1** (18 → 18, the quirk), so 306 lands the intended 18 mags × 17 =
306. Built via `<tools>\gdtdb\gdtdb.exe /update` + linker. The GDT is gitignored (external Skye pack), so
**`tools/fix_pdw_akimbo_ammo.js`** (idempotent) makes it reproducible — run after `reduce_base_ammo.js`. The GSC
override stays (now within caps, harmless). docs/05 / memory `akimbo-maxammo-units-quirk`.

### Fixed — Buyable doors unreachable in non-dev (acc_dev defaulted to 1) + all doors now 1000 (user, 2026-06-22)

"Doors aren't triggerable to buy." Root cause: **`acc_dev` defaulted to `1`** in `acc_resolve_dev_flags()` (`getdvarint("acc_dev", 1)`), so even *omitting* the flag — or using `run_game.ps1 -NoDev` — still resolved to **dev mode**, where `acc_hardcoded_open_map` force-opens every door and `TriggerEnable(false)`s the buy trigger. So non-dev was effectively unreachable and you never saw a buy prompt. CLAUDE.md + `PLAY_TEST_MAP.bat` already document the intended **default 0** ("omit it = clean normal play"); the code had drifted to 1.
- **Fix:** `getdvarint("acc_dev", 0)` — default 0 (ship-safe normal play). `run_game.ps1` still passes `+set acc_dev 1` for dev; `run_game.ps1 -NoDev` (or a shipped/no-flag launch) now actually runs **non-dev**, where the stock `_zm_blockers::door_init` shows the "Open Door [cost]" prompt and a purchase slides the clip open.
- **The doors were already correct** for non-dev: `zombie_door` trigger + `zombie_cost` + `script_flag` + a target clip with an open-method (`script_vector "192 0 0"`, `script_transition_time "1.5"`). Nothing was wrong with the doors themselves.
- **All 10 door costs set to 1000** (`zombie_cost`, was 750/1000/1250/1500). Done entity-aware so the 6 `treasure_chest_use` (mystery box) costs stay at 950 — an initial blind replace had caught those too and was reverted.
- `.map` entity change (door costs) ⇒ full `cod2map`+LED build.

The Shielded elite's speed was a genuine 50% (run gait @ 0.5× anim rate), but `<1.0` anim rate renders as
**slow-motion** (the documented zombie-speed constraint), so it looked like it was crawling/floating instead
of just half-pace. Fix: `shielded_speed_think` now uses the naturally-slow **`walk`** run cycle at full (≥1.0)
cadence — a walk is inherently ~half a jog and animates correctly (no slow-mo), so the brute reads as a proper
heavy half-speed zombie. Tunable via `acc_shielded_walk_rate` (1.0 = natural walk; raise for faster — still no
slow-mo since walk is the slow gait). Trade-off: it's the walk anim's natural pace, not a math-exact 50% of the
horde's current gait, so at high *sprint* rounds it reads slower-than-half (bump the rate if wanted). docs/11.

### Changed — Trimmed non-sting music/loops to 10s (bank de-bloat) (user, 2026-06-22)

The long music tracks + perk loops were full-length, bloating the soundbank (`.sabl` had ballooned ~31 MB). Trimmed every **non-sting song** to the first **10.0s** (hard cut + 150ms fade-out to avoid an end-click), preserving each file's existing format (sr/ch/bits): `acc/music/main_theme.wav` (84s→10s), `acc/music/brutus_music.wav` (123s→10s), and the 9 perk **loops** `acc/fx/jingles/loop_*.wav` (20s→10s each). **Stings left untouched** (they're already short cues): all `jingle_*.wav` (incl. `jingle_phd` at 13.5s — it's a sting, not a song), `pap_sting`, deny/powerup/etc. **`city_bed.wav` (ambient, 47.6s) left as-is** — it's ambience, not a song, and a 10s ambient loop would get repetitive (say the word to trim it too). Originals backed up to `tmp/songs_untrimmed/` (these wavs aren't committed). CSV unchanged; needs a game-closed build to recompile the `.sabs`/`.sabl` bank (which also shrinks substantially).

A focused pass on which enemies spawn, when, how many, and how hard they hit. `-GscOnly`, BUILD OK 2026-06-22 (lint clean). All values stay live `acc_*` dvars.
- **Phantom ENABLED in normal play AND dev, first spawn round 8** (then every 10: 8, 18, 28…). `ACC_PHANTOM_ENABLE_DEF 0→1`, `ACC_PHANTOM_FIRST_ROUND_DEF 10→8` (`_acc_boss_phantom.gsc`).
- **EMP + Teleporter elites REMOVED.** `pick_elite_class_for_round` now always returns `"shielded"`; the two promotions + the EMP on-hit debuff remain defined but UNREACHABLE (dead, kept for trivial restore). `_acc_elites.gsc`.
- **Glitch Stalker: round 2, EVERY round, count steps up every 2 rounds** — r2-3 = 1, r4-5 = 2, r6-7 = 3 … `floor((round-2)/2)+1` (new `glitch_count_for_round`). `ACC_GLITCH_FIRST_ROUND_DEF 3→2`, `ACC_GLITCH_INTERVAL_DEF 10→1`, `ACC_GLITCH_TEST_ROUND_DEF 3→2`; the old fixed `acc_glitch_count` is now superseded. `_acc_boss_glitch.gsc`.
- **Glitch Stalker −25% damage:** melee multiplier `ACC_GLITCH_MELEE_DMG_MULT_DEF 0.6→0.45` (its only damage source).
- **Shielded: 5× HP (was 2×) + moves 50% slower.** New `shielded_speed_think` (mirror of the Glitch speed-think at 0.5× anim rate, `acc_boss_custom_speed` opt-out so the global keep-alive doesn't fight it; NO `SetScale`). New dvars `acc_shielded_speed_mult` (0.5), `acc_shielded_spacing` (3.0). `_acc_elites.gsc`.
- **Shielded schedule: every 4 rounds from r4, count = the round number ÷ 2** (r4 = 2, r8 = 4, r12 = 6, r20 = 10…). `elite_quota_for_round` returns `round/2`; spawn spacing dropped 38s→3s so the whole batch fits the round. (High-round caveat: the ~24-AI cap throttles concurrently-live shields.)
- **Subroutine Core full boss REMOVED** (no r30/40/50 spawn). The r≥30 `run_full_boss` trigger is deleted from `round_hook_loop`; `run_full_boss`/`spawn_subroutine_core` stay defined but unreachable. Brutus now also eligible on r30/40/50. The Glitch/Phantom "yield to the Core" checks were removed. `_acc_boss.gsc`.

### Changed — Tier-weighted Mystery Box + Death Machine removed (user, 2026-06-22)

- **Mystery box is now tier-weighted (was uniform).** Better guns are rarer. Per-gun weights (≈ % on the fresh
  17-gun pool, total 94 → the box normalizes): **S+ ~1% (Wunderwaffe) · S ~3% · A ~5% · B ~7% · C ~8%** — the
  wonder weapon is the rarest of all, the worst gun ~8× more likely.
  New `_acc_map_randomizer::acc_box_weight` (tiers per docs/05) + `acc_box_weighted_pick`, hooked into the
  existing `acc_box_only_weapon_keys` (it does the weighted pick and returns it at the front; stock's
  `treasure_chest_ChooseWeightedRandomWeapon` takes the first eligible key). The no-duplicate filter still
  applies, so live odds re-normalize as you collect guns. Tier table: docs/05 "Mystery box roll odds".
- **Death Machine (minigun powerup) removed.** `acc_disable_minigun_powerup` (threaded from `main()`) swaps the
  stock minigun powerup's drop gate (`level.zombie_powerups["minigun"].func_should_drop_with_regular_powerups`)
  to a false-returning function, so `get_valid_powerup` skips it on every roll — it never drops.
- `-GscOnly`, BUILD OK 2026-06-22.

### Fixed — PaP'd PDW akimbo ammo: 17/17 mags + 306 reserve (was 15/17/18) (user, 2026-06-22)

The long-standing PaP'd-PDW ammo bug — **15 left mag / 17 right mag / 18 reserve** — is fixed to the
docs/05 numbers (**17 each magazine + 306 combined reserve**). `-GscOnly`, GSC-only, PDW-specific.
- **Two Skye `s1_pdw_rdw_up` data errors** no generic fill caught: (1) the OFF-HAND magazine's `clipSize`
  ships **15**, not the main's 17 (akimbo guns must share a mag size); (2) `maxAmmo` is a broken **920**
  the engine clamps to a ~18 reserve, not the intended 306.
- **Root cause that earlier passes missed:** stock akimbo keeps **ONE shared reserve on the MAIN weapon +
  SEPARATE per-gun magazines** (verified vs `_zm.gsc:3055-3062`: `stock_amt = GetWeaponAmmoStock(weapon)`,
  `left_clip_amt` = the `dualWieldWeapon`'s own clip) — exactly the symptom (shared reserve 18, split clips 17/15).
- **Fix** (`_acc_pap_levels::fill_full_ammo`, after the generic fill, gated `w.isDualWield && IsSubStr(w.name,"pdw")`):
  set the shared reserve once (`SetWeaponAmmoStock(w, 306)`) + BOTH magazines (`SetWeaponAmmoClip(w/dw, 17)`).
  The base PDW, the M1911/Five-Seven akimbos, and every other gun are **untouched**. See `akimbo-maxammo-units-quirk`.

### Changed — Perk jingles + PaP sound play ON the machine (3D); PaP cook = plasma-gun fire (user, 2026-06-22)

Sounds now emanate from the machine, not the buyer. Game-closed build (`-GscOnly` + CachedBanks clear for the alias changes).
- **Perk-buy jingle** now fires the INSTANT you pay — off the stock `perk_purchased` notify (`_zm_perks.gsc:605`, the moment points are deducted, *before* the drink) — and plays **ON the vending machine in 3D**, not on the buyer after the drink. New `_acc_mega_bottles::perk_purchase_jingle_watch` (threaded per player in `on_player_connect`) + `acc_find_perk_machine`; the `acc_jingle_*` aliases are now 3D. (Root cause of the old delay: `perk_bought_func` fires post-`weapon_change_complete`, i.e. after the drink, and was player-2D.)
- **Pack-a-Punch cook sound** swapped from the PaP jingle sting to the user's **plasma-gun-fire** wav (`sound_assets/acc/fx/pap_plasma.wav`, 48k from `lordsonny-plasma-gun-fire`), and ALL PaP sounds (cook / ready / deny) now play **ON the nearest `pack_a_punch` machine in 3D** via `_acc_pap_levels::acc_pap_play_on_machine` + `acc_find_pap_machine`. The 3 `zmb_perks_packa_*` aliases are now 3D. `pap_sting.wav` is now unused.
- **Mega perk drink** now plays that perk's FULL (non-sting) jingle **LOOP** — the fuller arrangement (the pack's 30–70 s `1.XX` loop, trimmed to ~20 s mono with a fade, `loop_*.wav`, ~17 MB total), 2D on the player — so a Mega upgrade sounds weightier than a normal buy's short 3D sting. The old **`acc_mega_drink` heartbeat stinger was REMOVED** (alias + code call; wav now orphaned). Loop alias = the sting alias + `_loop` (`acc_jingle_<perk>_loop`), played in `_acc_mega_bottles::set_mega_perk`.

### Changed — M60 Pack-a-Punch now fires with the Mk48 sound + cleared the UNRECOVERABLE linker error (user, 2026-06-22)

`-GscOnly`, BUILD OK — **clean** build (only the one always-waived `mtl_origins_camo_alt` warning; the `UNRECOVERABLE`/`Object reference` linker error is GONE). Two-part story:
- **The bug:** the Skye M60's PaP fire alias pointed at `skye_ports\t6_m60\fire\wpn_t6_m60_pap_shot.wav`, which the sound compiler rejected on every full bank rebuild (valid-looking — 48k/16-bit PCM — but the linker still choked, surfacing as `! ERROR: ...pap_shot.wav` / `Object reference not set` / `UNRECOVERABLE`). That one file is a bad egg.
- **The fix (user pick):** repointed both PaP fire rows (`wpn_t6_m60_pap_shot_plr` / `_npc`) in `sound/aliases/acc_skye_box_weapons.csv` to a **different, beefier LMG that isn't on the map — the Mk48** (`skye_ports\t6_mk48\fire\wpn_t6_mk48_pap_shot.wav`). Mk48 is a BO2 (`t6`) belt-fed LMG, so it's tonally consistent with the M60 base but distinct (and the only other map LMGs are M60 + RPD). Its `_pap_shot` links clean (the gremlin was specific to the M60 file). So the PaP'd M60 now has a distinct, heavy PaP fire tone AND the build is clean. Repo-tracked CSV change (wavs are gitignored external assets). Candidates considered: LSAT / HAMR / QBB LSW (all valid 48k, none referenced); Mk48 chosen for the heaviest tone.

`-GscOnly`, BUILD OK, sound bank rebuilt (game closed). Two changes baked in one build:
- **Round-count fix (re-added `ignore_enemy_count`).** Bug: in the trench the surge/drip kept spawning and the round NEVER ended, because surge zombies were counting toward the round (I'd removed `ignore_enemy_count` earlier while chasing the melee bug). That removal was unnecessary — verified from stock that `ignore_enemy_count` is read in ONLY two pure count loops (`zombie_utility.gsc:2031` `get_round_enemy_array`, `_zm_utility.gsc:105`) and does **not** touch `.enemy`/pathing/the melee gate; the real melee fix is the emergence gate (`completed_emerging_into_playable_area`), which is independent. With the flag back, surge zombies are excluded from `get_current_zombie_count()`, so the round-over check (`_zm.gsc:4733`) and the spawn loop (`:3735`) ignore them: **the round advances + ends on the normal horde, while the pit horde stays a separate relentless threat.** Set in `_acc_bus_trench.gsc::tag_trench_zombie`, gated `acc_trench_no_count` (default 1; `0` = count again, for A/B). Precedent: margwa/mechz set the same flag while attacking fine.
- **All custom sounds −8%.** Every alias in `sound/aliases/acc_audio.csv` (25 rows: overclock zap, PaP sting, perk jingles, powerup spawn/grab, nuke/deny/shard/bottle, headshot ding, mega-drink, main/brutus music, city ambience) has `VolMin`/`VolMax` set to **round(original × 0.92)**. Tuned: an initial −25% (×0.75) was too quiet, then −10%, settled at **−8%**. Always recomputed from the recorded originals (no double-rounding drift). **Exception:** the 9 perk-drink jingles (`acc_jingle_*`) were then bumped **+4%** above that baseline (78/83 → 81/86) per user request — they read a touch quiet on a perk buy. CSV-only → needs a game-closed build to recompile the `.sabs` bank.
- Build note: 1 "UNRECOVERABLE" linker line during the full bank rebuild = the **pre-existing broken Skye M60 PaP sound** (`wpn_t6_m60_pap_shot.wav`); same class as prior builds that loaded + played. `.ff` packed fresh (36 MB), bank rebuilt. If the map ever fails to LOAD, that M60 alias row in `acc_skye_box_weapons.csv` is the suspect to comment out.

A big batch of real BO3-zombies SFX wired in. **STAGED — needs a GAME-CLOSED build to bake the locked `.sabs`
bank** (memory `custom-sound-48k-and-game-lock`). Aliases in `sound/aliases/acc_audio.csv`, wavs in `sound_assets/acc/fx/`.
- **The "name the alias like the stock alias" hack** (HACKY-IS-GOOD): our `.szc` is a STANDALONE sound zone, so every
  stock alias (`zmb_*`, `evt_*`) is undefined → silent. Defining a row with the *exact stock alias name* makes the
  STOCK code play OUR wav with **zero GSC change**. Used for: powerups (`zmb_spawn_powerup`, `zmb_powerup_grabbed`),
  nuke (`evt_nuke_flash`), PaP cook (`zmb_perks_packa_upgrade`), PaP/perk deny (`zmb_perks_packa_deny`, `evt_perk_deny`).
- **Powerups now audible** — every powerup SPAWN + GRAB (`zmb_spawn_powerup`/`zmb_powerup_grabbed`, 3D positional) and
  the nuke flash. Source = the user's loose BO3 powerup WAVs (44.1k) → **48k via a new Node linear-interp resampler**
  (`/tmp/resample48.js`; 44.1→48 is a non-integer ratio so simple frame-dup won't do).
- **Pack-a-Punch cook** — `zmb_perks_packa_upgrade` (already called in `_acc_pap_levels`) → the **Pack-a-Punch Sting**
  from the ZombiePerkJingles pack. The PaP sound the user asked for, now real.
- **Perk-buy jingles** — `_acc_mega_bottles::on_perk_bought` plays the iconic per-perk sting on purchase (this IS our
  perk-buy reward sound — the stock bottle gulp is a silent undefined alias here). New `acc_perk_jingle_alias(perk)`
  maps each of the 9 specialties → `acc_jingle_*` (Jugg/Speed/DoubleTap/Stamin/Mule/Revive/Deadshot/Widows/PhD).
- **Data Shard pickup + deny buzz** — filled `acc_shard_pickup` (was SILENT across 5+ call sites: data_shards, exo,
  perks, reactor) with the cha-ching, and `evt_perk_deny`/`zmb_perks_packa_deny` with the no-money buzz.
- **Tooling:** downloaded a static **ffmpeg** (the 5 GB "Audio Dumps" + the jingle pack are FLAC/MP3, which BO3 can't
  ingest) — converts FLAC/MP3 → 48k WAV in one step; unblocks all future audio packs.
- **Dead-ends documented:** the 5 GB `Audio Dumps.zip` is the WRONG banks (core_frontend/post_gfx/cp_common/zm_common —
  ambient + music + MP VO, **no** PaP/drink/box/announcer SFX) AND it's FLAC. The perk MUSIC jingles it has are the
  loop versions; we used the cleaner MP3 sting pack instead.

### Changed — Model-upgrade audit: boss/elite tells shipped; station de-dup BLOCKED (catalog ≠ packable) (user, 2026-06-22)

Deep model audit (9-agent workflow) vs the real 5873-model Greyhound (Moon/ZC) dump → a swap plan for
13 slots. Applied + built → **all 11 new xmodels logged `is missing` and were REVERTED.** `-GscOnly`,
fresh `.ff` (36 MB), lint clean, zero `is missing` after revert.
- **Hard lesson (memory `greyhound-catalog-not-modtools-packable`):** a Greyhound catalog is models
  loaded in the GAME, NOT what the Mod Tools LINKER can pack (the linker needs the model's *source* in
  the install). Even the "Tier-A proven" zod family failed — `p7_zm_zod_nitrous_tank` packs because
  *its* source is installed, not the whole family. Only the small set already on our `.zone` packs.
- **What DID ship (proven client-FX / already-packed assets, no new xmodel):** Subroutine Core boss now
  has a teal eye-tint + `accPhantomAura` body-glow (distinct from the plain horde by glow, since its
  marquee boss previously had NO SetModel and looked identical to the charred horde); Shielded elite gets
  a `wpn_t7_zmb_zod_rocket_shield_world` shield Attach (already `.zone`-packed); Teleporter + EMP elites
  get the teal eye-tint (shared color — the `accEyeTint` field is 1-bit + one global colour, so they are
  not colour-distinct from each other or the Glitch Stalker; widening it is blocked by the full HUD pool).
- **Station de-dup BLOCKED:** the 4× `p7_cai_sign_inteactive_kiosk` + 3× `p7_cai_work_table_metal_03_white`
  reverted to as-is — no distinct on-theme model packs on this install. Reopening needs GDT-authoring the
  model sources (out of scope). Full reverted plan + reference kept in docs/52 (collapsed).

### Added — Power-on light WARM-UP: lights swell up over 10s instead of snapping (user, 2026-06-22)

When power comes on, the baked lights map-wide now **fade up over ~10s** (mirrors the fog settling away) rather
than the instant pop. Baked lights are lighting STATES (a binary swap — they can't be faded at the bake), so
the swell is faked with the vision tonemap (the only continuous brightness lever): `_acc_atmosphere::apply_vision`
detects the `power_on` flag, instantly masks the just-flipped bright lightmap with a near-black neutral grade
(`vision/acc_grade_blackout.vision`, ~5%, R=G=B), then `VisionSetNaked("default", ramp)` lerps back to normal
over the ramp seconds (the blend arg IS transition-time-in-seconds, verified vs stock `VisionSetNaked("flash_grenade",1.5)`).
It's the GLOBAL vision slot so the whole scene swells together (the player is at the switch, not the lit Plaza).
Live dvars: `acc_power_light_ramp 10` (duration), `acc_power_light_ramp_on 1` (toggle). `-GscOnly` (rawfile vision + GSC).
**Fix (2026-06-22):** the first cut looked near-instant — both `VisionSetNaked` calls fired in the SAME frame, so
the blackout never became the "current" vision and the lerp ran `default → default` (no change). Added a
`wait 0.25` between the snap-to-black and the lerp so it starts from black; the linear lerp then worked.

**Reworked to EXPONENTIAL + no-flash + 15s (2026-06-22):**
- **No flash:** the blackout is applied in `CheckForPower` (entry script) BEFORE `set_lighting_state(1)`, so there's
  no split-second of full brightness before the mask lands (same `acc_power_light_ramp_on` gate).
- **Exponential hold-then-surge** (user: "keep it super dark for the first few seconds, almost no improvement right
  away, then gets lighter fast"): the ramp HOLDS blackout for the first ~55% of the duration, then accelerates
  through stage grades `acc_grade_warm1` (~18%) → `acc_grade_warm2` (~45%) → `default` (100%) in shrinking time
  slices (`0.55 / 0.20 / 0.14 / 0.11` of `ramp`). Two new neutral rawfile grades; the block runs synchronously and
  owns the vision for the duration.
- **15s** default (`acc_power_light_ramp 15`, was 10). `-GscOnly`.

### Added — Custom headshot-kill ding (user, 2026-06-22)

`-GscOnly`, BUILD OK, sound bank rebuilt (game closed). A custom "ding" now plays on a **headshot KILL**.
- **Asset:** `cartoon-music-game-sfx-battle-game-headshot-ding-489769.wav` (user download, 44.1k stereo) → converted to BO3-required **48k mono** via `tools/convert_wav_48k_mono.ps1` → `sound_assets/acc/fx/headshot_ding.wav`. Alias `acc_headshot_ding` added to `sound/aliases/acc_audio.csv` (2D / NONLOOPING / UIN_MOD, modeled on `acc_main_theme`); `.szc` already registers `acc_audio.csv`.
- **Trigger:** `_acc_damage.gsc::on_ai_damage`, in the existing headshot-KILL gate (`b_headshot && b_bullet && final_damage >= self.health`) — plays `attacker PlayLocalSound("acc_headshot_ding")` (per-client 2D = the shooter hears it crisply, full volume, no world reverb). Gated to KILLS (not every headshot hit). Live toggle: `acc_headshot_ding 0`.
- **"Remove default sound" — verified there's nothing to remove:** stock BO3 plays **no** headshot "ding"/bonus-points cue (`_zm_score.gsc player_add_points_kill_bonus` awards points silently). The only headshot-related sound is the head-gib **pop** (`zmb_zombie_head_gib`, stock client-side `_zm.csc`/`zombie.csc` gib FX) — not a "ding", and not ours. So the ding is purely additive. The gib pop *could* be muted by redefining that alias in our CSV (map CSVs can override stock aliases) if ever wanted — left intact for now.
- Build note: the 2 "unexpected" linker errors (`wpn_t6_m60_pap_shot.wav` / null-ref) are a pre-existing Skye M60-PaP sound issue, unrelated to this change; the `.ff` packed fresh.

Drinking a **Mega** perk now plays **both** SFX: the stock bottle gulp (`replay_perk_drink`) AND a custom
heartbeat/tense-synth sting, so a Mega upgrade feels weightier than a normal buy.
- New CC0 alias **`acc_mega_drink`** (`sound/aliases/acc_audio.csv` → `sound_assets/acc/fx/mega_drink.wav`, the user's
  48 kHz/16-bit file — no resample needed), played `player PlaySound("acc_mega_drink")` in `_acc_mega_bottles::set_mega_perk`
  right before the gulp. 2D, non-looping. **Note:** the source clip is ~34 s long, so the sting lingers well past the
  drink — flag for trim if it overstays.
- Bank rebuilt game-closed; verified `acc_mega_drink` baked into the `.sabl`/`.sz`. (Caught + worked around a malformed
  `acc_headshot_ding` FileSpec that was aborting the sound build — once corrected the bank rebuilt with all custom
  sounds: mega_drink, headshot_ding, overclock_zap.)

### Changed — Pack-a-Punch: no UI/indication (price prompt only) + stock "cooking" pack sound (user, 2026-06-22)

PaP now has **zero on-screen display** — the only PaP UI is the machine's price prompt. `-GscOnly`, BUILD OK.
- **Removed the PaP info card** — `_acc_perk_info::update_for_player` now pushes code 0 when the PaP machine is the
  nearest interactable (was the perk/PaP proximity card); the PaP tier push (`set_pap_tier`) is gone.
- **Removed the PaP tier banner/icon** — the roman-numeral I/II/III shield (`CoD.AccPapTierIcon`) is no longer
  instantiated/added in `acc_hud.lua` (class left defined, dead). Also stripped the **"PaP X/3" line from the Overclock
  report card** (PaP gets no indication anywhere; the OC card is now overclock-only).
- **Removed every PaP tier-up TOAST** — the `^5PaP TIER N/3 - <benefit>` + "already max tier" `IPrintLnBold`s in
  `_acc_pap_levels.gsc` (first pack, tier-up, the `pap_taken` watcher) are gone. The "not enough points (need N)" deny
  stays (it's price text).
- **KEPT: the price prompt** — `pap_cost_display_keeper` still drives the machine's live cost (5000 → 7500 → 10000,
  Armory-discounted), so the player sees what the next pack costs and nothing else.
- **Added the iconic PaP "cooking" sound** — `zmb_perks_packa_upgrade` (stock BO3) now plays at the start of every pack
  (`acc_do_first_pack` + `acc_do_tier_up`), alongside the existing `zmb_perks_packa_ready` ding — so a pack still *feels*
  like a pack with no text.
- **Perk DRINK sound on buy** — `_acc_mega_bottles::on_perk_bought` (the stock per-buy hook) now threads
  `replay_perk_drink(perk)`, giving the perk's stock 1st-person bottle so its viewmodel plays the BO3 gulp on every
  (re)buy — even where the stock vending drink was silent (e.g. a free/instant dev buy). Guarded by `self.is_drinking`
  so it never doubles a stock drink already in progress; no-ops if the perk has no bottle weapon. All-stock audio.

`-GscOnly`, BUILD OK. Two trench changes:
- **Per-layer health 25% → 50%.** `acc_trench_layer_hp_pct` default 25 → 50 (`_acc_zombie_speed.gsc::apply_trench_health`). Zombies are now far tankier the deeper you go (L1 +50% … L5 +250% on top of round HP). Speed (+5%/layer) and melee (+10/layer) unchanged.
- **Spawns at the lower layers.** Previously the surge/drip only erupted at the L1 pit risers; the Abyss layers 2–5 only got zombies that walked all the way down. Now `spawn_corp_surge` reads **each underground player's current layer** and erupts there: new `get_layer_risers(layer)` returns the L1 map pit risers for layer 1 and **computed + nav-snapped floor risers** for layers 2–5 (`x=±400, y=1850/2046`, clear of the center well, at each layer's floor z). Triggers: the entry surge, a **new eruption when a player descends to a deeper layer** (`trench_fall_watcher` layer-change hook), and the continuous drip (`trench_ai_pressure`) — all now layer-aware. Each spawned zombie still gets the low-payout flag + the emergence fix, so it melees on whatever layer it erupts on. No `.map` change (synthetic risers) → no bake.

`_acc_overclocks::weapon_name_to_family` previously returned `"none"` for pistols (Five-Seven `t6_fiveseven`,
M1911 `s2_m1911`), so the Cyberware Overclock terminal refused them ("this weapon class cannot be tiered").
Pistols now return a new `"pistol"` family → eligible. The **Wunderwaffe DG-2** (`tesla_gun`) is now the only
gun explicitly excluded (added to `wonder_list` → `"none"`); it keeps its intrinsic wonder-weapon power.
All other box guns were already eligible. Knife / grenade / laststand pistol stay `"none"` (not guns). The
OC damage effect is tier-driven (`_acc_damage::get_oc_tier`, applies on any `oc_tier > 0` bullet hit), so
the family value only gates eligibility — pistols get the real per-tier bonus once overclocked. `-GscOnly`,
docs/05 updated.

### Changed — Abyss gets darker with depth via FEWER lights per layer (user, 2026-06-22)

**The fix that worked: reduce the NUMBER of abyss light objects per layer** — `gen_abyss_layer.js
lightsForLayer(n)`. Iterated from a depth-descending count (`5 - n` → L2=3/L3=2/L4=1/L5=0) to the final
**`return 0` — ZERO lights on every abyss layer L2→L5** (user: "remove the lights in the trenches completely,
only from L2 and on"). The whole descent below the pit is now pitch black, lit only by what spills down the
wells; the **Bus Station trench (L1) is untouched** and keeps its lights. 24 lights → 0. FULL LED build.
Lowering each light's *intensity* had barely helped because 6 lights/layer at radius 320 **blanketed** the
whole floor (overlap) — removing the objects is what leaves real dark.

The earlier theory below (an "unbeatable" vision-tonemap/IBL baseline) was **disproved by the user**: the surface
building goes genuinely dark when power is off, so a sealed lightless area DOES bake black — the baseline is
beatable and the abyss brightness was its own lights. The vision crush is kept as an **optional** lever (now
default OFF, `acc_abyss_dark_on 1` to stack it on). Original investigation notes (still useful — fog is additive
so black fog is invisible; no runtime exposure dvar; global_fill already `0 0 0`):

The trench/abyss "wouldn't get dark" no matter how low the point lights went — because the baseline brightness
is **not** the point lights. A multi-agent investigation traced it to the **vision tonemap curve top + sky/IBL
ambient**: the shipped vision maps even the brightest input up to ~1.0 (`vkRM 1.0`), and on this flat scene every
surface lands at that bright top — *above* whatever the lightmap bakes. (Corroborating: all 7 reflection probes
are surface-only `z=90`, so the abyss falls back to the bright default cubemap; `volume_sun` fill is already
`0 0 0`; BO3 vol fog is additive so black fog is invisible; no runtime exposure dvar exists.)
- **New mechanism:** a NEUTRAL near-black vision grade (`vision/acc_grade_abyss_dark.vision` — `vkRM 0.08`,
  R=G=B, `vkTS 0`, `vkTT 6500` = zero hue, modeled on the darkest stock ZM grade `thrasher_stomach`) applied via
  `VisionSetNaked` whenever a player is below the trench lip (`_acc_atmosphere::apply_vision` +
  `any_player_underground()` gating on `acc_bus_trench::underground_layer`). The tonemap is the LAST stage before
  the frame, so it crushes the IBL/curve floor that point-light dimming can't reach. Reverts to `default` on the
  surface. `-GscOnly` (rawfile vision + GSC, no LED bake).
- **Tuning:** edit `vkRM` (lower = darker; raise toward `0.15` if too dark to navigate) → `-GscOnly`. Live dvars
  `acc_abyss_dark_on 0` (disable) / `acc_abyss_dark_vision <name>` (swap). NOTE the crush also dims the abyss's own
  point lights, so the per-layer `0.40→0.05` gradient now provides the depth *variation* (visible once the baseline
  is crushed); those lights may need RAISING for readability — an in-game tune.
- **Coop:** this first pass uses the GLOBAL vision slot (solo-correct; darkens everyone while anyone is underground).
  The per-player clientfield→`.csc` `VisionSetNaked` upgrade (coop-correct, mirrors `_acc_perk_lights`) is the
  planned follow-up once the look is locked.

### Changed — Vague UI: hide exact magnitudes in-game (perks/PaP/overclock/exo), exact numbers in docs (user, 2026-06-22)

Players should feel an upgrade is **better** without knowing **by how much** — qualitative "feel", not a spreadsheet.
Survey (`survey-ui-numbers` workflow, 133 in-game strings) → **~46 strings vagued, ~87 kept**. Full exact→vague mapping
+ the design (word ladders, keep policy, resolved decisions) is the new SoT **docs/50_vague_ui_language.md**. `-GscOnly`.
- **Vagued (magnitudes hidden), base→Mega→tier ordering preserved by a word ladder** (e.g. reload `Faster`→`Even faster`;
  PaP damage `more`→`much more`→`greatly increased`; per-tier `grows each tier`). Edited: every perk card
  (`acc_hud.lua AccPerkCards` base/mega/megaFull), `pap_tier_benefit` + the PaP MAX-branch literal, the Overclock + Exo
  report cards, the PaP tier-up toasts (`_acc_pap_levels.gsc tier_benefit`), and the Stabilizer toast
  (`_acc_weapon_abilities.gsc`). The user's canonical example shipped verbatim: "Regen starts 20% sooner" → "Regen starts
  sooner" / Mega "even sooner".
- **HP readout DROPPED** (`_acc_health_bars.gsc`, decision D1) — the `250 / 250` numeric leaked the Juggernog magnitude
  (max 100→250→300); the color bar is now the only health cue. Biggest leak removed.
- **Kept (NOT "how much a stat grows"):** prices (Points + Data Shards), tier/progress indicators (`Tier N/5`, `vN`,
  `PaP I/II/III`), currency/inventory counts, reaction timers (decon/EMP), pure mechanics. Discount label `(-10%)` →
  `(Armory)` (price stays real). Dev crosshair damage number left as-is (never ships).
- **Relative hints kept (D7):** the most info-losing lines retain a relative word ("Much larger web-grenade pool",
  Double Tap "(much more damage)") so scale is felt without a number.
- **Docs hold the exact numbers** (perk_abilities / 13_perks / 05_weapons / 47_exo + the docs/50 mapping) so balance tuning
  reads off docs, never the in-game wording. ⚠️ LUI string-only change is syntax-safe but **needs a launch-test** (LUI
  runtime errors only show in-game as `UI Error <code>`, never in the linker log).
- **Refinement (user 2026-06-22):** rewrote every card bullet to be **SHORT (≤~28 chars, no wrap — esp. Double Tap)** and
  **SIMPLE/plain** ("Take more hits", "Fires extra bullets / Shoots faster", "Carry an extra gun", PaP "T1: more damage …
  T3: max damage"). A node length-check gates card edits. A per-perk audit (`audit-perk-numbers`, 9 agents) + a re-sweep
  caught two MISSES the first pass left: a 2nd perk-buy discount line still showed `(-10%)` → `(Armory)`, and the **exo
  upgrade toast** still printed `-N% dmg / +N% melee` → "faster, tougher, stronger melee". All 9 perks verified clean.
  docs/50 §8.

### Changed — Data Shard cap 50 → 500 + dev mode grants 200 shards (user, 2026-06-22)

- **Cap raised 50 → 500** (`ACC_SHARDS_MAX`, `_acc_data_shards.gsc`): the 50 cap was too tight (user "we
  dont really need a 50 cap"). 500 lets players bank toward the deep multi-tier sinks (Exo Suit + per-gun
  Overclocks) without constantly hitting the ceiling; still finite. `grant_player` clamps to the new cap.
- **Dev shard grant** (`_acc_data_shards.gsc::on_player_connect`, branched on `level.acc_dev`): each player
  STARTS with **200** Data Shards in dev mode (0 in normal play). One-time grant at connect, NOT a refill
  loop, so spending behaves normally. There was no dev shard grant before (the old "pins at 99" was stale).
- `-GscOnly`. docs/04 updated.

### Fixed — Abyss descent stairwells ENCLOSED with jump-proof railings (a "door down") (user, 2026-06-22)

"Zombies try to path over and get stuck; make it like a door to go down levels" + (after the first pass) "you can still jump down off the ledge." Full LED-baked build, **bake passed** (no `brush.cpp:1860`), navmesh regenerated.
- **Cause:** each Abyss descent (D1–D4) is a slim center stairwell whose stairs run W→E inside an opening cut in the layer floor; the sides were wide open, so zombies fell off / jammed and the player could **drop straight in from a side ledge** instead of using the stairs.
- **First pass was incomplete:** it walled the open long side only *below* the floor (`fz..cz`), which stops stair-walkers falling out the side but leaves the hole in the floor wide open — so you could still jump in (the screenshot).
- **Real fix:** `emitWellWalls(k, w)` in `tools/gen_abyss_layer.js` now encloses each well on its three non-entry sides **both below the floor AND as a 128u jump-proof railing above it**: SOUTH + NORTH long sides = full wall `fz..(cz+128)`; EAST (the exit side) = railing **above the floor only** (`cz..cz+128`) because the stairs step off the **bottom** eastward onto the next layer (must stay open). The **WEST stair entry stays open** — the only way down is to walk the stairs from the west.
- 12 walls (3 × 4 descents, `grep "stairwell"`), `.map` 8129→8350 lines. Bake-safe `box()` winding; re-runnable/idempotent.

### Changed — Location banner persists while underground (user, 2026-06-22)

The dev location title now stays up the whole time you're below the lip — it used to fade after 5s, which got
missed in the now-pitch-black trench ("went down layers, didn't see the location title"). `_acc_dev.gsc
dev_update_zone` re-asserts the hold every tick while `acc_bus_trench::underground_layer(origin) > 0`, and still
re-reveals on each area change; surface rooms keep the 5s declutter fade. **Banner set unchanged** — the 7
surface zones + "BUS STATION (TRENCHES LV1–5)" by depth; the user explicitly did NOT want per-room Black Market
names (an interim build added them, then reverted). `GscOnly` build. (Also this session: caught + restored the
abyss after a stray `strip`/`--revert` wiped it from the source `.map` post-PR-#18; re-applied the depth gradient.)

Reverted the Phase-1 "Overclock glass chip": `CoD.AccOcTierText` (`ui/uieditor/menus/hud/acc_hud.lua`) had
gained a glass mini-plate + cyan keyline box behind the `vN` (to match the PaP shield). User wants just the
text — removed the `Plate`/`Key` `CoD.TextWithBg` elements and their show/hide, kept the bare teal `vN`
`LUI.UIText`. No data/clientfield change (`accOcTier` untouched). `-GscOnly`.

### Fixed — Left HUD stack text overlap (boss-item lines collided with MEGA BOTTLES / WEB GRENADES) (user, 2026-06-22)

The 3 boss-item HUD lines in `_acc_boss_items.gsc` were positioned for the OLD left stack (before the
EXO SUIT and WEB GRENADES lines were inserted), so their Y's collided: BOSS-ITEM carry line at y=100
printed on top of **MEGA BOTTLES** (y=98), and the GAS label at y=124 on top of **WEB GRENADES** (y=122)
— visible in-game as overlapping "MEGA BOTTLES" / "CARRYING … Repair Kit" text. Moved all three below the
stack: carry/implant **146**, GAS label **170**, GAS bar **188**. Current full left stack (x=16):
HEALTH 16 / bar 32 / DATA SHARDS 50 / EXO SUIT 74 / MEGA BOTTLES 98 / WEB GRENADES 122 / BOSS-ITEM 146 /
GAS label 170 / GAS bar 188. `-GscOnly`.

### Fixed — Pit-spawned zombies can now MELEE (force-complete emergence; the actual root cause) (user, 2026-06-22)

The real fix for the long "zombies that spawn IN the trench can't hit me" saga, found by a 7-agent investigation (3 independent stock-source traces + 2 adversarial verifiers, all converged, stock precedent cited). `-GscOnly`, BUILD OK. Pending playtest confirmation but high-confidence + stock-grounded.
- **Root cause — the behavior-tree `inPlayableArea` gate, NOT navmesh.** The pit risers emerge zombies at **z=-240**, which is **below the corp_zone `player_volume` (z[-16,400])**. The stock zombie behavior tree only enters its MELEE branch when the engine condition `inPlayableArea()` is true (`_zm_behavior.gsc:1118-1126`), and that returns true **only** when `self.completed_emerging_into_playable_area` is set. That flag is set only when the zombie `IsTouching` a `"player_volume"` (`zombieEnteredPlayable` / `zombie_entered_playable`). A walk-down zombie emerges *inside* the volume → gets the flag for free → melees. A pit zombie at z=-240 **never touches any player_volume** → flag stays unset → `inPlayableArea()` false → it's locked in the NON-playable branch, which has find-flesh chase/taunt but **literally no melee action** (and the engine `.enemy` the melee gate reads is never assigned). That's exactly why it chased + stood in your face (`favoriteenemy` set → logs read `enemy=Y`) yet logged **0 MOD_MELEE**. This is the *same* geometry mismatch (pit below the zone volume) behind the old trench OOB-kill.
- **Fix:** in `_acc_bus_trench.gsc tag_trench_zombie()`, after the rise finishes, force-complete emergence like the round path does — `self zm_spawner::zombie_complete_emerging_into_playable_area()` (guarded `!IS_TRUE(...)`, bounded `waittill_notify_or_timeout("risen",5)` so a missed notify can't deadlock). Added `#using scripts\zm\_zm_spawner;`. **Stock precedent: `raz.gsc:516-528`** force-calls this same function for window-traverse zombies that bypass normal emergence. No `.map`/geometry change → can't regress the LED bake.
- **`ignore_enemy_count` stays removed** from surge zombies (a separate, real footgun: it excludes a regular zombie from `update_closest_player`'s array — `zombie_utility.gsc:2031` — but it was a different layer and removing it alone did not fix melee).
- **`acc_trench_vanilla` kept as a bisect toggle, now default 0** (full trench WITH the fix). `1` strips all trench customization (no force-spawn / AI-cap / per-layer scaling / tags) to isolate our pipeline.
- **Dead ends ruled out:** Abyss-carve navmesh theory (reverted + full bake, still broke), riser nav-clamp, spawning at corp spawners. The single-slab pit floor + full bake stays (correct geometry) but was never the melee fix.
- Diagnostic logging (RISER/SURGE#/PLAYER/CENSUS/MWIN/HIT, `[acctr]`, dvar `acc_trench_dbg`) stays in until the playtest confirms `spawnKind=SURGE` hits appear, then strip it.

### Fixed — Dev boss spawns follow REAL cadence + PaP fills the magazine (user, 2026-06-22)

- **Brutus on round 5, no dev override.** The dev sandbox was force-spawning a low-HP test Brutus every round
  from round 2 (`test_boss_loop`). Dev no longer triggers it — Brutus now follows his real **round-5** power
  cadence (`brutus_power_watch`, `acc_warden_first_round` 5) in dev exactly like normal play. The every-round
  test Brutus is now a manual opt-in only (`+set acc_test_boss 1`); the resolver no longer drives it.
- **Phantom ("Reaper") on round 10, no dev override.** Its real cadence is already round 10
  (`ACC_PHANTOM_FIRST_ROUND_DEF`), but the dev path force-spawned it from round 8. Dev no longer triggers the
  round-8 test branch; the master gate stays dev-bypassed so the real **round-10** cadence runs in the sandbox.
  Manual early spawn still available via `+set acc_phantom_test 1`. (Glitch Stalker is unchanged — its real
  first round already equals its test round, 3.)
- **Pack-a-Punch now fills the MAGAZINE too, at every tier — dual-wield included.** `GiveMaxAmmo()` only
  refills the reserve, so a packed gun had full reserve but an unfilled clip. New `fill_full_ammo()` helper now
  tops the reserve + magazine at both pack sites (first pack + tier-up). For **akimbo `_rdw_up` PaP forms
  (PDW / M1911)** it also fills the OFF-HAND magazine (`weapon.dualWieldWeapon`) — a single `SetWeaponAmmoClip`
  left one gun empty (the "PDW PaP ammo issue", user 2026-06-22). PaP at any level = **100% full clip+reserve
  on both guns**.
- `-GscOnly`, BUILD OK 2026-06-22.

### Added — Exo Suit: restored the damage-resistance + knife/melee augments (user, 2026-06-22)

The Exo Suit was meant to be the **body** counterpart to the gun Overclock — 3 scaling effects — but two of them
(resistance + melee) were dropped 2026-06-21, leaving only the depth-speed gate. Restored both, so each exo tier
now grants all three; the HUD report card lists them. (Speed verified working: `trench_fall_watcher` → `acc_trench_layer`
→ `recompute_move_speed` applies `exo_tier ≥ layer ⇒ no slow`.)
- **Damage resistance** — `_acc_elites::on_player_damaged` (the player-damage chokepoint) now reduces **ALL**
  incoming damage by `acc_exo_resist_per_tier` (default 0.05 → **−25% at T5**), capped at −80%, floored at 1 (always
  killable). The function was restructured so the EMP/trench-melee bump stays melee-only while the resist applies to
  every damage source; no-exo / non-melee paths are byte-identical to before (`return -1`).
- **Knife/melee damage** — `_acc_damage::on_ai_damage` adds an additive bonus layer for the player's melee hits
  (`b_melee`) scaled by `attacker.acc_exo_tier`: `acc_exo_melee_per_tier` (default 0.30 → **+150% at T5**).
  Mirrors the Overclock's flat-damage layer (guns get `oc_tier`, melee gets `exo_tier`); the Cyberware Amplifier
  already skips melee, so the Exo Suit is now the melee scaler. Guns untouched.
- **HUD + docs** — the station report card + upgrade message now show all 3 effects (speed/layer, −dmg%, +melee%);
  module header, docs/47 (§1/§9/§10), and the new dvars updated. `-GscOnly` (blocked on a game-closed build — the
  running game was locking the script files).

### Changed — Damage numbers → floating combat text (queue) (user, 2026-06-22, docs/49)

Reworked `CoD.AccDmgNum` (`ui/uieditor/menus/hud/acc_hud.lua`) from a single number that overwrote itself
into **floating combat text**: each push spawns its OWN number from a 12-element pool, at a **scattered
point in a small circle DEAD-CENTER on screen** (12 preset offsets cycled so consecutive hits never land
on the same spot), which **rises (~46px) and fades over 0.6 second**, then the slot recycles.

- **PER-EVENT queue (`_acc_dev.gsc`):** every individual damage event — each bullet, each shotgun PELLET,
  and each separate zombie a single bullet hits/penetrates — becomes its OWN number. NO summing. Because
  the `accDmgNum` value rides one networked channel that carries only the LAST value per snapshot, events
  are QUEUED (16-deep ring buffer; drops oldest on overflow) and drained ONE per ~0.05s tick. So a spray
  = one number per bullet (effectively instant); a same-frame burst (shotgun pellets, one bullet through
  2 zombies) = a fast flurry of separate numbers over a few tenths of a second. Replaced the old
  accumulate-and-sum-per-0.1s-window behavior.
- **Size + color (user 2026-06-22):** normal hit scale **0.45** (~50% smaller); **headshot 25% larger**
  (0.56). Headshot **teal** / normal **amber**, and the headshot flag is **hit-location based**
  (`is_headshot(sHitLoc)`), NOT weapon/MOD-gated — so a head hit is teal for bullet, knife, etc. (only the
  Tac-19 is ever headshot-excluded, by design).
- **Placement (user 2026-06-22):** circle center = **screen dead-center** (`ACC_DMG_CY = 0`); spawn
  circle **50% smaller** via `ACC_DMG_SPREAD = 0.5` (one knob scales every scatter offset); each number's
  box is **centered on its point** (`cy ± 17`) so the cluster's middle lands exactly on screen center;
  **lifetime 0.6s** (`ACC_DMG_LIFE = 600`).

`-GscOnly`, BUILD OK. Still behind the `acc_dev` feed (shows in dev/pre-release). In-game verify needed
(LUI errors only show as an on-screen UI Error box).

`acc_dev` is now the **single** dev switch — a binary normal-vs-dev mode with the dev values hardcoded in GSC,
not a pile of console toggles. Root cause of the old "some flags don't work": `acc_dev` was read at 6 sites
with **mismatched defaults** (1 in four files, 0 in two) and **never `SetDvar`'d**, and the sub-behaviors
(open map / test bosses / perks) each gated on their **own** flag — so `+set acc_dev 1` alone only half-worked.
Fix (additive, non-breaking — the working `acc_hardcoded_dev` / `_acc_dev` engines are kept):
- **New `acc_resolve_dev_flags()`** runs first in `main()`: reads `acc_dev` ONCE, caches the global bool
  **`level.acc_dev`**, and `SetDvar`s the legacy sub-dvars (`acc_open_map`, `acc_test_boss`, `acc_glitch_test`,
  `acc_phantom_test`, `acc_variants_debug`) to match — one flag drives all. (Not `acc_auto_power` — dev no
  longer auto-powers; you flip the switch. No god mode either — regular damage.) Default **1
  during the pre-release** (dev on even if the Steam launcher drops the `+set` arg — the proven original
  behavior); **one-line `TODO(ship)` flips it to 0** before publish.
- **All 6 `getdvarint("acc_dev",N)` reads converged** to `IS_TRUE( level.acc_dev )` (entry gate, `_acc_dev`,
  `_acc_boss`, `_acc_boss_glitch`, `_acc_boss_phantom`, `_acc_perks`) — the default-skew class is gone. The
  always-on zombie wallhack (`_acc_health_bars`) is now gated on `level.acc_dev` too. The Phantom test boss
  bypasses its master gate (`acc_phantom_enable`) when `level.acc_dev`, so all three test bosses spawn in dev.
- **Dev sandbox starts you with 25 Data Shards (one-shot)** instead of the per-second 999 pin — so a shard
  *spend* is testable in dev. **No god mode** — the user tests with regular gameplay/damage.
- **Launch is literally one flag — `+set acc_dev 1`** (`PLAY_TEST_MAP.bat` / `tools/run_game.ps1`); all the
  old open-map/test-boss/glitch/audio/lockdown/zspeed flags are dropped (dev-driven or run on code defaults).
- **Pattern enforced for future agents:** to add a dev behavior, branch on `IS_TRUE( level.acc_dev )` or add a
  `SetDvar` in the resolver — **never add a new dev dvar.** CLAUDE.md "Dev/test mode" + docs/49 + memory
  `dev-mode-hardcoded-not-console`. Built `-GscOnly` (BUILD OK 2026-06-22).

### Added — Exo Suit HUD: always-on tier readout + detailed station report card (user, 2026-06-22)

The Exo Suit's only feedback was a transient buy message, so "when a player upgrades their exo suit they don't
even know what it does." Added the same two-part HUD the Weapon Overclock has — both with **NO new clientfield**
(the clientuimodel pool is full; the always-on overclock "vN" took the last dead field). `-GscOnly`, BUILD OK.
- **Always-on "EXO SUIT N/5" readout** — a server-side font string (`sync_exo_hud` in `_acc_exo.gsc`), mirroring
  the `DATA SHARDS` count's `hud::createFontString` mechanism (NOT LUI — the exo state is server-side, so this
  sidesteps the clientfield pool). Grouped with DATA SHARDS at the top of the left HUD stack (y=74); dim at
  tier 0 so it's discoverable, bright once augmented. Refreshed on spawn + every upgrade.
  `level.acc_exo_station_origins` records the station origin for the card below.
- **Detailed report card at the station** — reuses the live LUI proximity-card system (`_acc_perk_info` →
  `accPerkCard` → `acc_hud.lua`), exactly like the Overclock kiosk card. The exo tier is encoded into the
  **unused `accPerkCard` code range 108..127** (`108 + exo_tier`, above the +64 discount range 64..107) — so
  **no new clientfield**. Walking up shows the current tier, what it does (full speed down to trench layer N +
  the slow rule below), and the **next tier's Data-Shard cost + benefit**, so you know what you're buying.
  `acc_hud.lua AccExoCosts` mirrors `_acc_exo::exo_cost` (5/10/15/20/25); the Armory discount bit is excluded
  (exo costs shards, not points). docs/47 §11.
- **Adversarial verification pass** (`verify-exo-hud` workflow, 15 agents): 4 dimensions (card code-range
  contract, server-hud lifecycle, GSC runtime-fatal, benefit-text accuracy) → refute per finding. Confirmed +
  fixed: (1) the always-on EXO line collided with the MEGA BOTTLES readout (both at y≈74) → reordered the left
  HUD stack to DATA SHARDS 50 / EXO 74 / MEGA BOTTLES 98 / WEB GRENADES 122 (always-on items grouped on top);
  (2) `_acc_exo.gsc` had `#define ACC_EXO_MAX` after `#namespace` (pre-existing; failed the preflight
  directive-order lint though the linker tolerated it) → moved above `#namespace`; (3) the card showed a
  vacuous "-20%/layer" line at MAX tier → suppressed when `exoTier == 5`. The code-range contract + server-hud
  wiring verified correct. Rebuilt `-GscOnly`, BUILD OK.

### Fixed — Trench melee restored: reverted the Abyss carve, single-slab pit floor + FULL bake (user, 2026-06-22)

**THE fix for "zombies spawn in the trench but never hit me."** Confirmed by a multi-agent investigation: it was a GEOMETRY/navmesh problem, not script — every `-GscOnly` build I tried physically could not fix it (reuses the navmesh).
- **Root cause:** the 2026-06-21 Abyss well carve (`gen_abyss_layer.js`) replaced the one clean pit-floor slab with 3 fragmented chunks + a stairwell hole. cod2map drops navmesh across carved/coplanar-seamed floors (the `single-slab-floor-over-room` rule), so the z=-240 pit floor had **no navmesh**. Surge zombies emerge there via `do_zombie_rise` (no navmesh registration) → land off-mesh → drift but never enter the melee state. Walk-down zombies reach you over the still-meshed stairs/edges, so they meleed — the asymmetry that pinpointed it.
- **Fix:** `node tools/gen_abyss_layer.js --revert` restored the original single-slab pit floor (the geometry that meshed + meleed when the surge shipped 6-18); then a **FULL `build_map.ps1` bake** (cod2map64 regenerated the navmesh over it: `navmesh.hkt` updated; LED baked clean; fresh .ff 35.97 MB). Re-enabled pit eruption by default (`acc_trench_surge_from_pit` 1) — surge zombies now erupt from the pit floor on-mesh and melee.
- **Casualty / follow-up:** the revert removed the Abyss L2–L5 descent (it was the carve that broke the pit, and was a WIP sealed dead-end). It must be **re-added OFF the open pit floor** — the L1→L2 descent as a wall doorway → external shaft, or from inside a trench room (Foundry), NOT a hole in the open combat floor — so it can never re-fragment the pit navmesh. docs/48 + gen_abyss_layer.js need that redesign before re-applying.
- Verify: `developer 1; ai_shownavmesh 1`, drop in the pit → continuous mesh on the z=-240 floor; surge zombies erupt and swing.

### Changed — HUD modernization Phase 1 (safe restyle batch) (user, 2026-06-22, docs/49)

First batch of the HUD modernization plan (docs/49) — presentation-only, in `ui/uieditor/menus/hud/acc_hud.lua`,
zero new clientfields/assets, `-GscOnly`, BUILD OK. Only proven LUI primitives (CoD.TextWithBg.Bg rects +
keyframe tweens), each widget self-contained so a fault can't cascade:
- **Shared palette** `ACC_PAL` (glass/cyan/teal/violet/amber/danger) — one source of truth for the HUD's
  identity colors; re-used by the new elements below (groundwork for routing all widgets through it).
- **Perk-icon overlap fixed** — `AccPerkBar` PITCH 38 → 48 (≥ SIZE 44) so icons stop crowding/overlapping.
- **Damage numbers rise + fade** — `AccDmgNum` now drifts up while fading (proven setTopBottom+setAlpha
  tween), reset to baseline on each hit, for game-feel.
- **Overclock readout → glass chip** — `AccOcTierText` "vN" now sits on a dark-glass plate + cyan keyline
  (shown only at tier > 0), matching the PaP tier shield instead of floating as bare text.
- **Info card framed top + bottom** — `AccPerkCard` gets a matching bottom cyan accent strip so it reads
  as a designed panel, not a bare box.

Deferred to later batches (need careful edge-gating / new data / assets, per the docs/49 critique): the
info-card slide-in entrance, perk gain-pop / Mega flash, power-up countdown rings, round-ring danger
glitch, and migrating the stock GSC text/bars into LUI (gated on a clientfield bit-budget audit — the
pool is nearly full). **In-game verify needed** (LUI runtime errors only show as an on-screen UI Error
box, never console).

The abyss layers now get **dimmer the deeper you go**, so the dark visibly deepens as you descend the trench
— a visual read on the rising risk. The post-power `bake_intensity_scale` on the 24 abyss lights goes from the
old uniform `0.4` to a **geometric (halving) depth ramp: L2 `0.40` → L3 `0.20` → L4 `0.10` → L5 (deepest) `0.05`**
— the deepest floor is 1/8 of the top (steepened from the interim linear `0.40→0.10` per user "scale even more
per trench level"), floored at `0.03`. `tools/gen_abyss_layer.js` `abyssLayerIntensity(n)` is the source of truth; applied to the live map
by `tools/_grade_abyss_lights.js` (light-KVP only — no geometry/navmesh regen, since re-running the abyss
generator re-carves the descent well + trench navmesh). The abyss lights stay power-gated (dark until power).
FULL LED build (intensity is baked).

### Changed — Pitch-black-until-power lighting + power lever moved to force a dark crossing (user, 2026-06-21)

The map now goes **truly dark until the power switch is flipped** — the player must cross a pitch-black Bus
Station to reach the lever.
- **Root cause of "bright before AND after power" was a FULLBRIGHT `.ff`, not the source.** The baked lightmap
  lives in the `.led`; a build had regenerated the `.d3dbsp` (cod2map) *after* the LED bake, so the linker packed
  an un-relit BSP → every lighting state rendered identically and the `set_lighting_state(0→1)` flip was a visual
  no-op. Oracle going forward: **`.led` mtime must be newer than `.d3dbsp`** (file size is NOT the tell — a relit
  BSP is still ~617 KB). Fix = full `build_map.ps1` (cod2map → LED → linker). Memory `fullbright-ff-stale-led-vs-bsp`.
- **Interior rooms: pure black until power.** Dropped the pre-power DIM floor set entirely (the `0.02` trace still
  read "too light"); each sealed room now bakes black in the pre-power state and lights up on power. The 63 BRIGHT
  (post-power) lights stay. `tools/gen_room_roofs.js` `EMIT_DIM_PREPOWER = false`.
- **Sealed areas (abyss + underground) now power-gate too.** The 24 abyss + 41 underground lights were always-on
  (`lightingstate1..4 = 1`); flipped to `0,1,1,1` (dark pre-power, lit post-power) via `tools/_gate_sealed_lights.js`
  (light-KVP only — no geometry/navmesh regen) + the generator sources (`gen_abyss_layer.js`,
  `gen_underground_lights.js` `POWER_MASK`). Only the **15 Plaza lights** stay always-on (the lit safe-haven spawn).
- **Night sky dimmed to 0.6.** `worldspawn sky_intensity_factor0/1` `1 → 0.6` (global multiplier, not per-state) to
  cut the `default_night` sun's bleed into open doorways.
- **Power lever moved across the trench to the Lab side, FAR (west) wall.** The Bus Station has an E–W trench
  (y[1723,2173]) splitting it into a south/Plaza half and a north/Lab half, crossed by stairs whose only north
  exit is the EAST channel (x[703,799]). The `power_switch.map` prefab moved from the south/Plaza side
  `(790 1600 1)` to the north/Lab half **west wall** `(-752 2250 1)`, angles `0 90 0` (faces east into the room).
  Players drop through the pitch-black trench, climb out the NE stairs, then must cross the dark Lab half to the
  opposite (west) wall to flip it — so they can't power on the instant they leave the stairs. (Interim spot
  `(790 2250 1)` sat right beside the east stairs — too easy.) `_acc_power.gsc` stands down to the prefab's
  native trigger, so no script change. FULL LED build.

### Added — Overclock kiosk: full held-gun report card + zap SFX + PaP-style re-draw (user, 2026-06-21)

Walk up to an Overclock kiosk → a card now reports the **gun in your hand**: its name, PaP level (+ benefit),
and Overclock level (+ all three benefits at that tier). Plus tactile feedback when you overclock.
- **Report card** (`acc_hud.lua` + `_acc_perk_info.gsc` + `_acc_overclocks.gsc`). The kiosk records its
  trigger origins (`level.acc_oc_kiosk_origins`); `_acc_perk_info::update_for_player` competes them with the
  perk/PaP machines for the nearest interactable. When the kiosk wins it shows a combined card:
  - **Gun name** — encoded into the **unused `accPerkCard` code range 44..63** as `44 + gun_card_index(held)`
    (the gap between perk codes 0..43 and the +64 Armory-discount bit). `acc_hud.lua` decodes `gunIdx = code-44`
    → `AccGunNames[]` (mirrors `_acc_perk_info::gun_card_index`). **No new clientfield** — the full clientuimodel
    pool is untouched (avoids the documented overflow that breaks `zmhud.swordEnergy`).
  - **PaP + Overclock levels/benefits** — read from the already-live `accPapTier` / `accOcTier` models (the held
    gun's tiers), so the card needs no extra data. OC benefit text mirrors `_acc_damage`: +5%/tier damage,
    +25%/tier vs glitch zombies, 10%/tier ammo back on a headshot KILL. The +64 discount is guarded off for the
    overclock card.
- **Zap SFX on overclock** — new CC0 alias `acc_overclock_zap` (freesound community laser-zap) in
  `sound/aliases/acc_audio.csv` → `sound_assets/acc/fx/overclock_zap.wav`, played `player PlaySound(...)` on each
  tier-up. The source wav was **24 kHz** (BO3 linker rejects: *"wav is not 48k sample rate"*); resampled in-repo
  to **48 kHz** via a no-dependency Node 2× frame-duplication upsampler (same pitch/length). ⚠️ **The soundbank
  only recompiles on a GAME-CLOSED build** (a running game file-locks `CachedBanks/*.sabs`, so the linker reuses
  the stale bank). **Done:** rebuilt with the game closed (deleted the locked `CachedBanks`, relinked) and verified
  `overclock_zap` is baked into the `.sabl` bank + compiled `.sz` — the zap plays. Memory `custom-sound-48k-and-game-lock`.
- **PaP-style re-draw on overclock** — `player acc_pap_levels::replay_pack_draw(current)` replays the same
  "gun comes out" first-raise PaP uses (preserving the gun's camo/tier), so an overclock *feels* like an upgrade.
  Gated by the existing `acc_pap_tier_anim` dvar.
  - **Fix (post-review):** `replay_pack_draw` re-gave the redrawn held gun with the gold PaP camo
    **unconditionally** (`_acc_pap_levels.gsc:494`) — fine when only PaP called it, but overclocking a never-packed
    gun would paint it gold. Now tier-gated (`if get_tier(self,w) >= 1`) exactly like the restore loop; PaP camo
    unaffected (both PaP callers hold a tier ≥1 gun at that point).
- **Adversarial verification pass** (`verify-overclock-batch` workflow, 13 agents): 5 review dimensions (clientfield
  lockstep, the card encode/decode contract, GSC runtime-fatal patterns, logic correctness incl. the headshot-KILL
  timing, balance-number consistency) → adversarial refute per finding. Result: wiring + gameplay values all correct;
  issues found = stale tier comment tags (Five-Seven `[B]`→`[C-]`, AE4 `[A]`→`[B]` in `_acc_damage.gsc`) + a stale
  docs/05 LMG paragraph (M60 `A-top`→`S`, RPD `0.13/B`→`0.10/C`) + the camo bug above. All fixed. `-GscOnly`, BUILD OK.

### Changed — Location title: trench/abyss layers + transient 5s reveal (user, 2026-06-21)

The on-screen area name (top-center "zone signage" in `_acc_dev.gsc`, `dev_update_zone`) now:
- **Names the trench/abyss layers** — descending overrides the surface zone via
  `acc_bus_trench::underground_layer()`: `BUS STATION (TRENCHES LV1)` (the pit) … `LV5` (the deepest
  floor). Surface zones (Plaza/Market/Alley/Bus Station/Vault/Helipad/Lab) unchanged.
- **Is transient (declutter):** it was a persistent label; now it **fades in only when you ENTER a new
  area, holds 5 s, then fades out**, and re-appears for 5 s on the next new area (`FadeOverTime` + a
  `GetTime()+5000` timer per player; HUD starts hidden). Applies to surface zones AND trench layers.
- New helpers `dev_get_player_area` (trench override → surface zone) + `dev_area_name` (trench names →
  `dev_zone_name`). `-GscOnly`, BUILD OK.
- **NOTE:** this element lives in the dev module and is gated on `acc_dev` (default-on pre-release, so
  it shows now; **off in a public build**). If it should be a permanent player feature, it needs
  promoting out of the `acc_dev` gate — not done yet (awaiting the call).

THE actual fix for "zombies don't hit me in the trench" (after the nav-snap attempts failed). Decisive user clue: **zombies spawned IN the trench can't melee, but ones that spawn above ground and WALK down can.** `-GscOnly`, BUILD OK.
- **Root cause / what changed:** the pit surge/drip relocates zombies onto z=-240 risers via `spawn_zombie(spawner,_,riser)` → `do_zombie_rise`, with no navmesh validation. This worked when the pit floor was one clean slab (surge added 2026-06-18, zombies meleed). The **2026-06-21 Abyss L1 well carve fragmented the pit-floor navmesh** (the "map generation issues"), so risen zombies at the central risers are now **off-mesh → they drift at you but never enter the melee attack state**. Walk-down zombies reach you over the still-meshed stairs/edges, so they melee fine. The earlier nav-snap couldn't help because there's no good navmesh at the riser spots to snap to.
- **Fix:** `spawn_corp_surge` now spawns the surge at the **normal navmesh-valid corp spawners** (the same proven-working path the walk-down zombies use) and lets them path in — so the surge zombies CAN melee. The **pit-floor eruption is opt-in** via `acc_trench_surge_from_pit 1` (default 0); flip it back on once the pit-floor navmesh is rebuilt (single-slab + full bake). Drip / reactor / altar surges all route through this, so all are fixed. No other lever changed (AI-cap bump, drip cadence, aggro, per-layer scaling untouched).
- **Trade-off:** the surge no longer literally erupts from the pit floor — the zombies rush in from the corp spawners. Working melee > broken eruption; the eruption returns for free once the floor navmesh is fixed (a separate geometry task).

### Fixed/Added — PaP full ammo + overclock-loss fix + Overclock tier HUD ("vN") (user, 2026-06-21)

Three weapon fixes (`-GscOnly`):
- **Full ammo on Pack-a-Punch.** Every pack tier now refills the gun (`self GiveMaxAmmo()` at the end of `acc_do_first_pack` (T1) and `acc_do_tier_up` (T2/T3) in `_acc_pap_levels.gsc`) — matching stock PaP, which the in-place pack system had stopped doing.
- **Overclock no longer randomly lost.** The Overclock tier was keyed by the **held weapon object** in `_acc_overclocks::terminal_loop`, so overclocking while holding a PaP'd or perk-twin form stored it under that object — then switching forms (PaP, or a Mega-perk twin swapping in/out) made `get_oc_tier` miss it and read 0. Now keyed by `acc_weapon_variants::true_base(current)` (form-invariant), matching `get_oc_tier`'s own true-base fallback.
- **Overclock tier indicator on the HUD.** Display-name append isn't possible (weapon display names are static), so added a "**vN**" text near the gun name (bottom-right, above the PaP tier icon), driven by a new `accOcTier` clientuimodel + `_acc_overclocks::oc_hud_loop` + `acc_lui::set_oc_tier` + `acc_hud.lua CoD.AccOcTierText`. **Safe-by-design:** `accOcTier` **repurposes the dead `accLuiTest` test field** (same 4-bit slot/order in both `_acc_lui.gsc`/`.csc`), so the clientfield bit layout is unchanged — no pool growth, no risk of the documented overflow that breaks the stock `zmhud.swordEnergy` field. docs/46 + tag comments synced.

### Fixed — Trench risen zombies were off-mesh (couldn't melee); corrected riser nav-snap (user, 2026-06-21)

The real root cause of "zombies never hit me in the trench," found from the user's decisive clue: **zombies spawned IN the trench can't melee, but ones that spawn above ground and walk down CAN.** `-GscOnly`, BUILD OK.
- **Cause:** our pit risers carry `script_noteworthy "riser_location"`, so the surge/drip spawn routes through stock `zm_spawner::do_zombie_rise(spot)`, which emerges the zombie **at `spot.origin` with no navmesh registration** (`move_zombie_spawn_location` → `do_zombie_rise`). If the raw z=-240 riser isn't exactly on a navmesh poly, the risen zombie is **off-mesh** — it drifts at you but never enters the melee attack state. A walked-down zombie is continuously on-mesh, so it melees fine. (This is why the pit floor navmesh being freshly baked didn't matter, and why the prior "remove the clamp" fix didn't work — raw risers are still off-mesh.)
- **Fix:** `get_trench_risers()` nav-snaps each riser onto the floor navmesh — but with the **correct parameters** this time: a **small radius** (`acc_trench_riser_navsnap_radius` 128, well under the ~240u gap to the z=0 surface) **plus a down-guard** (`snapped[2] <= origin[2] + 16`) that rejects any up-snap toward the lip (mirrors `_zm_weap_gravityspikes.gsc:1325`). So it resolves **down onto the pit floor**, never up to the surface — unlike the earlier radius-256 clamp that snapped the whole horde topside. Toggle `acc_trench_riser_navsnap 0` to A/B against raw origins.
- A down-snapped on-mesh point is also correct for the Brutus warden (shares this cache).
- **If this still doesn't restore melee**, the central pit floor genuinely has no navmesh (a cod2map/geometry problem, not script) → rebuild the floor as a single clean slab + full bake. Confirm path: `set acc_trench_riser_navsnap 0/1` to compare; `set acc_trench_drip_on 0 / acc_trench_surge_on 0` to check walked-down zombies (which already melee).

### Fixed — Overclock ammo refund now requires a headshot KILL, not just a headshot hit (user, 2026-06-21)

Cyberware Weapon Overclock effect 3/3 (Adaptive Aim ammo refund) previously rolled its per-tier chance on *any* headshot hit. Now it only triggers when the headshot is the **killing blow** — gated on `final_damage >= self.health` in `_acc_damage::on_ai_damage` (the callback runs pre-damage, so `self.health` is still the target's current health; if our returned damage meets/exceeds it, the hit kills). `-GscOnly`. docs/46 + the `#define` comment synced.

### Changed — Tac-19 clip cut (→ A+) + PDW packed → bottom S (user, 2026-06-21)

- **Tac-19 clip 4→3 / PaP 7→6** (`reduce_base_ammo.js` CLIP_FIX). With the prior damage −9% + `MAXAMMO_FIX` 9, this drops it from low-S to **A+ base (~7.45)** / **S packed (8.1)**; reserve follows to **27 base / 54 PaP**. The user opted to cut the clip knowing it leaves S. Still chaff-strong; boss-damage cut (`ACC_SHOTGUN_BOSS_MULT`) unchanged.
- **PDW-57 packed → bottom S:** gave the akimbo PaP forms (`s1_pdw_rdw`/`_ldw`) a **separate higher balance mult (0.33, +50% over the 0.22 base)** in `acc_weapon_balance_mult` — same split pattern as the M1911. Base PDW stays **C**; the packed akimbo (double-fire + PaP ladder on top) now reaches **bottom S (~7.7)**. Tune in playtest (akimbo damage stacking is hard to predict precisely).
- docs/05 both tables + tier-tags + CHANGELOG synced. `-GscOnly` (Tac-19 clip = GDT regen; PDW mult = GSC).

### Changed — Tac-19 all-around nerf (kept at low S) (user, 2026-06-21)

Damage **−9%** (`acc_weapon_balance_mult` 0.75→**0.68**) + reserve **−25%** (`reduce_base_ammo.js` `MAXAMMO_FIX` s1_tac19 12→**9** mags: base 48→36, PaP 84→63). [Superseded same day by the clip cut above.] (This is separate from the earlier `ACC_SHOTGUN_BOSS_MULT` boss-damage cut.) docs/05 both tables + tier-tag synced. `-GscOnly`.

### Changed — Gun curation batch + Tac-19 boss-damage fix + base/PaP tier lists (user, 2026-06-21)

Stat changes (all built; GSC mults + GDT ammo):
- **M60** stays S but DPS↓ traded for ammo: `acc_weapon_balance_mult` 0.24→**0.20** (~696→~580 DPS), clip 60→**100** / PaP 100→**120** (reserve **400/480**). The huge mag (sustain) carries it now.
- **PPSH-41 → A+**: 0.27→**0.20** (~664→~492 DPS).
- **Galil → B+**: 0.198→**0.15** (~545→~412 DPS).
- **Paladin → low S**: clip 4→**8** / PaP 7→**11** (reserve 96/132) + now **scored on single-target DPS** (a one-shot boss-killer, not chaff) in the tier formula.
- **Five-Seven → C**: reserve 84→**56** (`MAXAMMO_FIX` 6→4 mags); clip kept for the early game.
- **Tac-19 boss-damage fix:** new **`ACC_SHOTGUN_BOSS_MULT`** (default **×0.25**, dvar `acc_shotgun_boss_mult`) + `is_pellet_shotgun()` helper in `_acc_damage.gsc`. Root cause: an 8-pellet shotgun is balanced for chaff (pellets spread), but on a boss all 8 concentrate → ~8× stacked damage. Now pellet shotguns (Tac-19 + Olympia) deal ¼ damage vs bosses/mini-bosses — chaff tier (S) unchanged, boss-nuke removed (the intended "shotguns under-perform vs bosses").
- **docs/05 now has TWO tier lists** — **Base guns** (roll quality) and **Fully-PaP T3** (investment ceiling). Key PaP insight: the transform pistols **M1911 / PDW / Five-Seven are C base but A packed** (akimbo / explosive); **Olympia stays C even maxed** (2-round clip). Tier-tags + formula notes synced.

### Changed — Tier scoring formula v2 ("sustain" model): clip now rewarded via effective reload (user, 2026-06-21, docs/05)

The tier formula under-rewarded exceptional clips (clip was a low-weight, hard-capped factor). v2 folds clip into a **Sustain** factor = **effective reload (reloadEmpty ÷ clip)**, log-scaled — a huge clip earns its keep by making you reload rarely, with built-in diminishing returns — and **log-scales reserve**. Weights: **DPS 30 · Mobility 16 · Sustain 18 · Penetration 14 · Reserve 14 · Handling 8** (clip is no longer a standalone factor); DPS scale steepened (340→1 … 664→10) so weak-DPS guns can't free-ride on handling. **No stat changes** — this is a scoring-model + docs + tier-tag-comment change only, so no rebuild (the live `.ff` already matches). Resulting tier moves vs the previous list: **M60 now EARNS S** (8.1 — its 60-clip makes the 9.7s reload trivial per-round, no more `*` override), **AE4 → A**, **AK-47 → A**, **ASM1 → B**, **Tac-19 → S**, **Paladin → B** (4-round clip + 4s reload = poor horde sustain), **Olympia → C** (2-round clip), **Five-Seven → B**. `_acc_damage.gsc` tier-tags + docs/05 table synced.

### Fixed — Trench nav-clamp regression reverted (zombies melee in the pit again) (user, 2026-06-21)

The earlier riser nav-clamp (added to fix "run into me but never swing") **caused a worse regression: zombies NEVER hit the player in the trench.** Root-caused via a multi-agent investigation (confirmed by synthesis + 2/3 adversarial verifiers + the author's own code). `-GscOnly`, BUILD OK.
- **Cause:** `get_trench_risers` ran `GetClosestPointOnNavMesh(riser.origin, 256, 64)` **unconditionally, mutating `.origin` in place**, on every z=-240 pit riser. A nav-snap on a z=-240 point can resolve **UP to the z=0 surface lip** (the ~240u gap is inside the 256u radius; the 64u boundary arg pushes the result off the tight pit floor onto the large surface slab). The surge/drip horde — the **only** pit population (risers are surge-only, not `corp_zone_spawners`) — then erupted **on the surface**, so a player in the pit was never approached/meleed.
- **Smoking gun:** `_acc_boss_brutus.gsc:124-126` already documents this exact hazard and *deliberately* drops the warden on the raw z=-240 origin ("the trench SURGE proves entities spawn AND path there"). The clamp did the very thing Brutus avoids — and, via the **shared cache**, silently snapped the Brutus warden to the surface too.
- **Fix:** removed the clamp; `get_trench_risers` returns the raw z=-240 structs (which spawn + path fine on the full-baked pit navmesh). Un-breaks the Brutus warden. Documented the "never nav-clamp deep sunken spawn points" rule at the function.
- **Ruled out** (same investigation): the per-layer melee-damage hook, the +25% health buff, the speed/anim-rate change, and "stale navmesh" — none can produce a never-melee; the navmesh was fully re-baked after the well rework.
- **Confirm in-game:** `set acc_trench_aggro_melee 0` → still no hits (proves the damage hook is innocent); `set acc_trench_drip_on 0 / acc_trench_surge_on 0` → only walked-down zombies remain (if those swing, the clamp was it). After the fix, surge zombies should erupt in the pit and melee. Also re-check the Brutus warden drops into the pit (`acc_warden_trench 1`).

### Changed — Gun tier curation pass: M60/Nail→S, AE4→B, PDW/RPD→C, Five-Seven→C- (user, 2026-06-21)

Retuned six guns to target tiers (stats aligned via the multi-factor formula in docs/05; tier-tags + tier table synced):
- **M60 → S**: `acc_weapon_balance_mult` 0.20 → **0.24** (~580 → ~696 DPS). Move/reload untouched per user — so the formula caps M60 at ~7.3 (top A); curated **S** (`*`).
- **Nail Gun → S without touching DPS**: clip 30 → **40** + reload 2.6 → **2.0s** (new `RELOAD_FIX` in `reduce_base_ammo.js`); reserve ~280. Composite 7.7 = S.
- **AE4 → B**: 0.35 → **0.31** (~467 → ~413 DPS). Formula still reads 6.8 (A) — its reload/pierce/mobility kit is A-grade; curated **B** (`*`), trim clip/pierce for a true formula-B.
- **PDW-57 → C**: 0.33 → **0.22** (~495 → ~330 DPS).
- **RPD → C**: 0.13 → **0.10** (~439 → ~337 DPS) — the "bad LMG".
- **Five-Seven → C-**: 0.30 → **0.26** (~60 → ~52/shot); sits on the 5.6 B/C line (`*`).
- Tooling: `reduce_base_ammo.js` gained a `RELOAD_FIX` map (+ `RELOAD` regex) for reload tuning. Build: `node tools/reduce_base_ammo.js` → `gdtdb /update` → linker. BUILD OK.

### Added — Documented multi-factor gun tier scoring formula (user, 2026-06-21, docs/05)

The Gun Tier List is now **formula-driven**, not DPS-only. Composite (0–10) = weighted sum of seven 1–10 factor scores → S/A/B/C. Weights (user-tuned this pass: mobility 12→18, penetration 18→14, clip 12→10): **DPS 28 · Mobility 18 · Reload 16 · Penetration 14 · Clip 10 · Reserve 8 · Handling 6**. Thresholds S ≥7.7 / A 6.6 / B 5.6 / C below. Each factor's 1–10 scale documented (e.g. penetration none 2 / small 4 / medium 7 / large 10; mobility `moveSpeedScale` 0.8→4…1.0→10; reload 0.47s→10…9.7s→1). Full raw-stat matrix pulled from the Skye GDTs (move/reload/penetration/clip/reserve/range/fire-type) feeds the scores. **Docs-only** — no code/stat changes. The formula's output moves four guns vs the earlier DPS-first hand-set picks (Tac-19 A→S, Nail Gun S→A, AE4 B→A, ASM1 C→B; M60 stays A but borderline at 6.7 due to its 9.7s reload + 0.8 move); `_acc_damage.gsc` tier-tags left as-is pending confirmation.

### Changed — Gun re-tier pass + Nail Gun PaP de-explosived (user, 2026-06-21)

Re-tiered six guns (and aligned `acc_weapon_balance_mult` to the new tier's DPS band; one `IsSubStr` return covers base + `_up` + all perk twins). All `-GscOnly` except the Nail Gun GDT change:
- **M60** → **top A**: 0.15 → **0.20** (~435 → ~580). *(RPD left at B — flagged to align if wanted.)*
- **Galil** → **mid A**: 0.1785 → **0.198** (~491 → ~545).
- **AK-74u** → **low A**: 0.2925 → **0.23** (~658 → ~518; reverts the earlier +30%).
- **PPSH-41** → **S**: 0.17 → **0.27** (~418 → ~664).
- **AK-47** → **B**: 0.21 → **0.186** (~525 → ~465).
- **AE4** → **B**: 0.38 → **0.35** (~506 → ~467).
- **Nail Gun PaP de-explosived:** the `_up` form shipped an explosive transform (`explosionInnerDamage 1300 / Outer 1000 / Radius 144`) the user disliked. Zeroed those + matched `_up` fireTime to base (0.133 → 0.157) in `tools/reduce_base_ammo.js` (new `EXPLOSION_ZERO` map + `EXPLODE` regex; durable across generator re-runs). PaP now upgrades **only** damage (% ladder + raw 600) / clip (30→40) / reserve (210→320), keeping base nail behavior. Build: `node tools/reduce_base_ammo.js` → `gdtdb /update` → linker.
- Tier-tags + docs/05 Gun Tier List re-sorted; LMG section synced.

### Fixed — Trench melee actually scales + zombies swing again (user, 2026-06-21)

Two pre-existing trench bugs the new per-layer rules exposed. `-GscOnly`, BUILD OK.
- **Melee damage never applied (got 45, not the trench value).** Root cause: `apply_trench_melee` wrote `self.meleeDamage`, but that field is only read by the **window-board** melee path (`_zm_spawner.gsc:1156`); **open-field** zombie melee (the whole trench) uses the engine `Melee()` builtin = the zombie's melee **weapon**, which ignores `self.meleeDamage`. So the trench bump never landed. **Fix:** add to the **player's incoming `MOD_MELEE` damage** by their trench layer — a **flat `+acc_trench_layer_dmg_add` HP/layer** (default 10; L1 ≈55/hit … L5 ≈95) — in the existing player-damage callback (`_acc_elites::on_player_damaged` → new `acc_bus_trench::trench_melee_scaled`). Works regardless of melee path; player's layer == the adjacent zombie's layer. Retired the dead per-zombie write (`apply_trench_melee` → `apply_baseline_melee`, holds the 45 baseline for the board path only).
- **"Run into me but never swing" in the trench (only there).** Attempted fix here was a nav-clamp on the risers (`get_trench_risers` `GetClosestPointOnNavMesh(origin, 256, 64)`) — **this BACKFIRED into "never hit me at all" and was reverted; see the "Trench nav-clamp regression reverted" entry above.** The real fix for the residual no-swing is the geometry/full-bake (the L2 well rework) + raw z=-240 risers, not a script clamp.
- **Speed (+5%/layer) unchanged** — `ASMSetAnimationRate` is the right lever and already worked.
- Note: any residual no-swing with only *walked-down* zombies (test: `set acc_trench_drip_on 0 / acc_trench_surge_on 0`) would be the carved floor's own navmesh seams — a geometry/full-bake fix, not script. Docs: 11, 34.

### Added — Gun Tier List (S/A/B/C) + gun tweak batch (user, 2026-06-21)

New **Gun Tier List (design intent)** section in `docs/05_weapons.md`: every gun gets an S/A/B/C tier + rationale + current stats (mult / eff-DPS / clip / reserve / ability), and the workflow is "set the tier, then align stats to its band." Every `acc_weapon_balance_mult` return line in `_acc_damage.gsc` is now tier-tagged `[S]/[A]/[B]/[C]` to match. Tiers: **S** AK-74u, Nail Gun, Wunderwaffe · **A** AK-47, AE4, Tac-19, Paladin, Ripper · **B** PDW, Galil, M60, RPD, Five-Seven, Olympia · **C** ASM1, PPSH (→B with a buff), M1911 base (→A packed).

Bundled gun changes (all `-GscOnly`):
- **AK-47 buff** `acc_weapon_balance_mult` 0.184 → **0.21** (~460 → ~525 DPS) — the AR jackpot was the weakest auto; lifted into the A band.
- **Weapon abilities: every box gun now has one.** The category lookup (`_acc_weapon_abilities.gsc::weapon_name_to_ability_category`) was never updated for the 2026-06-15/19 box guns, so M1911 / PPSH / AK-74u / PDW / Nail Gun / Paladin / M60 / RPD had NO ability. Wired them to their category's existing LIVE effect and added **sniper → Precision Mode** + **lmg → Focus Fire** table entries (distinct cooldown ids). No new gameplay code.
- **Comment hygiene:** rewrote the stale `acc_weapon_balance_mult` header (it listed old mults that drifted from the live returns) to point at the tier list; refreshed the stale "5 shipped guns" headers in `_acc_weapon_abilities.gsc`; updated the docs/05 box count (12 → 17) + ability table to the live mapping.
- **Documented** a known minor issue: `armory_refill` uses `weapon.maxammo` (mags-not-rounds for akimbo), so Mule Kick's refill on a packed PDW/M1911 is tiny — left as-is pending a robust akimbo cap.

### Changed — Perk retune: Mule Kick refill 35→20%, Quick Revive regen 15→20% / Savior 30→40% (user, 2026-06-21)

- **Mule Kick / The Armory** round-start reserve refill **35% → 20%** (`ACC_ARMORY_ROUND_REFILL` 0.35→0.20, `_acc_mega_bottles.gsc`; covers both the per-round refill and the instant top-up on acquire).
- **Quick Revive** HP-regen-start **15% → 20% sooner** (`ACC_QR_REGEN_DELAY_BASE` 0.85→0.80, begin 2.04s→1.92s) and **Savior** Mega **30% → 40% sooner** (`ACC_QR_REGEN_DELAY_SAVIOR` 0.70→0.60, begin 1.68s→1.44s) in `_acc_perks.gsc`.
- Display + docs synced: perk HUD cards (`ui/uieditor/menus/hud/acc_hud.lua` QUICK REVIVE + MULE KICK), `docs/perk_abilities.md`, `docs/13_perks.md` (table + detail + quick-ref + status + trim list). `-GscOnly` (the HUD `.lua` rebuilds with the linker; no geometry/GDT).

### Added — Exo Suit (trench depth gate) + 5-tier overclock + layered trench slow (user, 2026-06-21, docs/47)

The trench now descends in LAYERS, each slower; the new **Exo Suit** is the key to depth. `-GscOnly`, BUILD OK,
not yet playtested. Layer 1 works today; layers 2–5 light up as the geometry agent builds floors (they extend
`acc_bus_trench::underground_layer`, deepest-z-first — no system change needed).

- **New `_acc_exo.gsc`** — per-player `acc_exo_tier` (0–5), a buy Station in the pit (250,1800,-240,
  `TriggerIgnoreTeam`), costs **5/10/15/20/25**. Wired into `_acc_main` (init + connect + spawned) and the `.zone`.
- **Layered trench slow** — `acc_utility::recompute_move_speed` now applies a depth-aware slow from
  `player.acc_trench_layer` (set each poll by the `_acc_bus_trench` watcher via `underground_layer`) + the
  player's exo tier: reduction = 0 if layer≤tier, else `0.20 + 0.10*(layer-tier-1)` (−20% first uncovered
  layer, −10%/layer deeper, cap 0.90). Replaced the old flat boolean trench slow. Re-applied on spawn
  (`acc_exo::on_player_spawned`) since `SetMoveSpeedScale` resets each spawn. Dvars `acc_exo_slow_first` (0.20),
  `acc_exo_slow_step` (0.10), `acc_exo_cost_t1..t5`, `acc_exo_on`.
- **Gun Overclock → 5 tiers** — `ACC_TIER_MAX` 4→5, `ACC_TIER_COST_T5` 24 (ladder 2/4/8/16/24, 54 to max). The
  3 effects scale off the tier automatically, reaching T5: flat dmg +25%, glitch +125%, ammo refund 50%.
- Docs/46 reconciled (overclock row + detailed section to 3 effects / 5 tiers, + the Exo Suit section/table);
  docs/47 marked built.

### Fixed — akimbo-PaP reserve collapse (PDW/M1911 "~30 bullets" bug, user, 2026-06-21)

PaP'ing the PDW-57 (and M1911) dropped its reserve to ~18 rounds. Root cause in `_acc_pap_levels::acc_do_transform`: the reserve carry was `stock + (packed.maxAmmo - w.maxAmmo)`, but `weapon.maxAmmo` reads as reserve-in-**rounds** for the single-wield base (132) yet as the raw **magazine count** for the akimbo `_rdw_up` packed form (18), so the mixed-unit subtraction gave `132 + (18 - 132) = 18`. Fixed: carry the player's current reserve in rounds, clamped to the packed gun's real full reserve (`GetWeaponAmmoStock` after the fresh give, which reports rounds for both wield types). Clip carry was already correct (uses `clipSize` = rounds). `-GscOnly`. Needs a playtest confirm.

### Changed — M1911 nerf (user, 2026-06-21)

`acc_weapon_balance_mult` (`_acc_damage.gsc`): base **4.375 → 3.50** (~88 → ~70 eff/shot) and the akimbo-explosive PaP **0.50 → 0.35** (7000×0.35 = 2450 direct + scaled splash, was 3500). Still a strong PaP nuke, falls off a few rounds sooner. `-GscOnly`.

### Changed — AK-74u +30% damage (user, 2026-06-21)

`acc_weapon_balance_mult`: **0.225 → 0.2925** (~506 → ~658 DPS), now the top of the SMG pack. `-GscOnly`.

### Changed — PPSH-41 +5 clip on all versions (user, 2026-06-21)

`reduce_base_ammo.js` `CLIP_FIX`: `s4_ppsh41_base` **25 → 30**, `s4_ppsh41_base_up` **39 → 44** (base + PaP + all perk twins via stem match). Reserve rises with it (`maxAmmo` 9 mags unchanged): base 225 → 270, PaP 351 → 396. Build: `node tools/reduce_base_ammo.js` → `gdtdb /update` → linker.

### Added — Abyss descent: all 5 floors (Made in Abyss vertical pivot, user 2026-06-21)

Reframing the map around the Bus Station trench as a **Made in Abyss / Persona descent** — deeper =
harder, reach the bottom. **5 floors total**, trench = Layer 1, plus 4 identical enclosed floors
straight down (240u pitch: L2 −480, L3 −720, L4 −960, L5 −1200). Research first established there is
**no practical depth limit** (engine world bound ≥ ±65,536, symmetric; current map only spans ≈
+272..−256) so we build DOWN rather than moving the map up — full plan + per-layer recipe in
**docs/48_abyss_descent.md**.

**All 5 floors now built** via the multi-layer `gen_abyss_layer.js` (`--upto N` for incremental
bake-gating): one carved pit floor + four generated rooms joined by four **slim WIDE-AXIS (X-running)
center stairwells** that step off the bottom into open interior floor (never a wall), alternating
south/north (D1 XS, D2 XN, D3 XS, D4 XN) so a floor's down-well is never where the stairs from above
land. Every floor stays a connected surface (West–Bridge–East) — never bisected. Full build **OK**
(fresh .ff 36.02 MB, navmesh regenerated). 24 always-dim lights (6/room).

**Descent placement iterated 4× (all user-caught 2026-06-21, pathing):** (1) full-depth central well
**bisected** the trench (zombies couldn't cross); (2) SE-**corner** well merged with the existing east
trench stair → **navmesh break point**; (3) center but **short-axis (Y) stairs ended jammed at the next
layer's wall** → zombies stuck at the bottom; (4) **FIX = wide-axis (X) center stairs** — the well is
`x[−112,112]`×128u against the S/N wall, stairs run west→east and exit at x≈+112 (~700u of open floor),
so zombies disperse. Only the orientation/placement changed; floors, z-levels, and the per-layer scaling
(`underground_layer`, pitch 240) are unchanged and still aligned.
Floors are identical greybox shells for now; per-layer escalation/props later.

**(5) Overclock-room door moved off the descent well (user-caught 2026-06-21):** the south under-room
(overclock terminal) door sat at the **center** of the south trench wall (x[−96,96]) — directly behind
the centered D1 descent well, so zombies couldn't path across the hole to reach it → **player invincible
in that room**. Moved the door (doorway + sliding brush + use-trigger) to the room's **WEST edge**
(`x[−192,−112]`, by the terminal), onto the solid west floor chunk, clear of the well. The descent stays
centered. (`.map`-only edit to the `acc_door_under_plaza` brushes; the abyss generator's strip leaves
them alone. Guard comment added in `gen_abyss_layer.js`: do NOT move the D1 well west or it re-blocks the
door.) Re-baked + rebuilt OK (fresh .ff 36.02 MB).

**D1 pathing fix (user-caught 2026-06-21):** the L1 pit already has the trench crossing stairs (far
west `x[−761,−665]` + east `x[703,799]` walls). Two earlier D1 placements broke zombie pathing: (1) a
full-depth central well **bisected** the trench; (2) an SE-**corner** well put the east stair on the
small carved chunk, so the navmesh merged the descent into the existing stair = a **break point** on the
pit floor. Fix: D1's well moved to the **center-south** (`x[−64,64] y[1723,1947]`, against the south
wall), ~600u clear of both stairs; the pit carves into west + east full-depth chunks + a north bridge,
staying one connected surface. (Only L1 needs this — L2–L5 are our rooms with no other stairs, so corner
wells are fine there.) Re-baked + rebuilt. Also verified the per-layer zombie scaling
(`underground_layer`, `ACC_LAYER_PITCH=240` / `ACC_LAYER_MAX=5`) aligns with the built floors at exactly
−240·N: speed (+5%/layer), **health (+25%/layer, `apply_trench_health`)**, and melee (+10 HP/layer) all
land on the correct layer 1–5 automatically.

The detail below describes the original L2-only build + the v1→v2 bisection fix.

**This change builds L2 (z=−480) only.** New generator `tools/gen_abyss_layer.js` (re-runnable,
idempotent): carves the single pit-floor brush into a WEST + EAST chunk leaving a **full-depth central
well** (x[−128,128]) — full-depth strips meet at matching vertices so there's **no T-junction
fall-through cull** (memory `single-slab-floor-over-room`); adds a single-slab L2 floor, 4 sealing
walls, a **14-step stairwell** (16/16 navmesh-linking pitch) descending the well from the pit floor
(−240) to L2 (−480), and 6 always-dim lights. Brushes reuse the EXACT bake-safe `box()` filler-winding
+ hex GUID (real-corner windings crash `brush.cpp:1860`). **No GSC change needed** — L2 sits inside the
existing trench OOB-veto band (`player_in_underground`: z≤−36, x[−900,900], y[−400,2900]), so standing
on it doesn't trip the stock out-of-playable-area hard-kill; zombies path down via the regenerated
navmesh. **LED BAKED 16.4s; full build OK** (fresh .ff 35.99 MB). L2 is a sealed dead-end until its
down-well is added with L3.

**REVERTED then REWORKED same-day (user, 2026-06-21):** v1's full-depth central well **bisected the
trench floor** into two disconnected islands → zombie path/targeting broke (user-caught). Reverted
(`node tools/gen_abyss_layer.js --revert`, restores the original pit-floor brush — git can't be used,
the .map had other uncommitted WIP), then **reworked to a slim SE-corner well** `x[691,819]
y[1723,1947]` with slim stairs `x[691,799]`: the pit floor is carved into a connected L-shape (chunk A
= full main floor + chunk B = NE patch carrying the east stair) so the **trench is NOT bisected**. Only
one benign same-plane T-junction (cod2map-fixed), not the thin-lip cull. v2 **LED BAKED 16s, full build
OK** (fresh .ff). Awaiting in-game walk + zombie-path test.

### Changed — Trench zombies: per-layer scaling, no forced sprint/beeline (user, 2026-06-21)

The combat companion to the Abyss descent: how zombies behave in the trench. `-GscOnly`, BUILD OK.
- **Removed forced sprint gait** and **removed beeline** (`level.should_zigzag` override deleted → every zombie keeps stock zig-zag). The forced beeline made the trench pack stack on one vector and *bump-without-swinging* (the "they run into me but never hit" bug).
- **Re-gated on the zombie's OWN position, not its target.** Previously every zombie *chasing* a player in the trench got buffed (so the whole map "ran at you"); now only a zombie **physically standing in a trench layer** is affected. Surface zombies are 100% stock.
- **Three per-layer levers:** **+5% move** (anim-rate), **+25% max health** (on top of round health; one-way by deepest layer reached — added as armor on descent, never re-healed so the keepalive can't exploit it), and **+10 HP melee** (flat, added to the player's incoming hit). L1 = +5%/+25%/+10 HP … L5 = +25%/+125%/+50 HP. (Melee delivery: see the "Trench melee actually scales" fix above — open-field melee ignores `self.meleeDamage`, so it's added to incoming damage.)
- **Layer is depth-based**, reusing the Abyss 240u pitch: `acc_bus_trench::underground_layer(origin)` = how many 240u steps below the lip (L1 −240 … L5 −1200, clamp `ACC_LAYER_MAX` 5). So each new floor's zombies scale correctly the instant its geometry lands — no per-layer code edit.
- New dvars: `acc_trench_layer_speed_pct` (5), `acc_trench_layer_hp_pct` (25), `acc_trench_layer_dmg_add` (10, flat HP). Retired: `acc_trench_aggro_rate`, `acc_trench_melee_dmg`, `acc_trench_no_zigzag` (+ `ACC_TRENCH_MELEE_DEF`). Kept: `acc_trench_aggro` (master gate), `acc_trench_aggro_melee` (per-layer melee on/off). Docs: 11, 34, 46.

### Changed — LMG reserve ammo +33% (user "~25% more", 2026-06-21)

Both LMGs (M60 `t6_m60`, RPD `t6_rpd`) get more reserve ammo: base **180 → 240**, PaP **300 → 400**. Lever is `tools/reduce_base_ammo.js` `MAXAMMO_FIX` (M60/RPD base+`_up` raised **3 → 4 magazines**; clipSize unchanged at 60 base / 100 PaP). Reserve = `maxAmmo` (in magazines) × `clipSize`, so it is **quantized to whole magazines** — an exact +25% (225/375) isn't reachable without an odd clip; 3→4 mags = **+33%**, the closest step above the request (erring high suits a sustained-fire LMG). Build: `node tools/reduce_base_ammo.js` → `gdtdb /update` → linker (`-GscOnly`; GDT/ammo only, no geometry). docs/05 LMG section updated.

### Changed — Trench exposed move-slow → −20% (user, 2026-06-21)

The Bus Station trench / underground move-speed penalty is now **−20%** (`acc_trench_slow_mult` default **0.80**; history 0.65 → 0.75 → 0.80). Still composed through the single move-speed owner `_acc_utility::recompute_move_speed` and still **negated by the Boots boss item**. `-GscOnly` (dvar default only, no geometry). Also swept the leftover **"−35%"** wording — the effective value had already moved to −25% but two comments in `_acc_bus_trench.gsc` plus `docs/46` still read −35%; synced those and `docs/03`.

### Changed — Cyberware Weapon Overclock finalized to 3 effects (user, 2026-06-19)

Dropped from 4 effects to 3 (still small-per-tier, per-gun, all raised each tier). `-GscOnly`, BUILD OK; docs/46 updated.
- **1 Flat Damage** (`acc_oc_dmg_per_tier` 0.05) — +5%/tier ALWAYS on (hip + ADS, gun hits). Replaced the old ADS-only "Overpressure".
- **2 Glitch Piercing** (`acc_oc_glitch_per_tier` 0.25) — +25%/tier (+100% at T4) bonus damage vs GLITCH zombies (`self.acc_is_glitch_zombie`, set on the Glitch Stalker host in `_acc_boss_glitch` — covers the Stalker + lockdown-challenge glitch zombies). Replaced the old anti-Shielded-elite "Armor-Pierce" (the elite frontal resist reverts to explosives/flank-countered, no overclock involvement).
- **3 Ammo Refund** (`acc_oc_adaptive_per_tier` 0.10, cut 60% from 0.25) — headshot refund chance +10%/tier (40% at T4).
- **Removed Headshot AoE** (the old 4th effect; `reactive_powder_aoe` left defined but unwired).

### Added — Perk machines: "max perks reached" message when at your slot limit (user, 2026-06-19)

Buying a perk you don't own while at your perk-slot limit previously just played a deny sound with no
explanation (stock `_zm_perks.gsc:585`). Now it shows clear text. Extended our existing
`level.custom_perk_validation` hook (`_acc_perk_info.gsc::acc_perk_validate`, which runs on F-press right
before the stock limit gate): if `zm_utility::can_player_purchase_perk()` is false (num_perks ≥ the
player's `acc_perks::acc_perk_slot_limit`), it plays the deny sound and prints
`"You've reached your max of <N> perks - raise the limit at the Neural Expansion in the Bus Station trenches"`,
then blocks the buy. Matches
stock's own limit condition exactly (incl. the unquenchable-BGB exception). GSC-only (`-GscOnly`).

### Added — Wonder weapon: Wunderwaffe DG-2 in the mystery box (user, 2026-06-19)

The map's first wonder weapon. User picked the Wunderwaffe DG-2 (`tesla_gun`, chain lightning — fits the
electrical/cyber theme) from the 4 stock options, via the box at **uniform odds**. A 5-agent inventory
verified the no-download landscape: the **only** wonder weapons addable without DLC are the 4
`is_wonder_weapon=TRUE` rows cooked into the base ZM common fastfiles — **Ray Gun (`ray_gun`), Wunderwaffe
(`tesla_gun`), Ray Gun Mark III (`raygun_mark3`), Thundergun (`thundergun`)**. Every DLC WW (Bows / KT-4 /
GKZ-45 / Apothicon Servant / Ray Gun Mark II) is BLOCKED — those map fastfiles aren't installed.

- **Two-line, `-GscOnly` add** (no model compile, no LED, **no `weapon,` `.zone` line** — the def is cooked in
  `zm_levelcommon`): (1) a row in our weapon table `gamedata/weapons/zm/zm_levelcommon_weapons.csv`
  (`tesla_gun,tesla_gun_upgraded,,10000,tesla,…,special,TRUE,TRUE` — the stock columns; `is_limited`=1 so only
  one exists at a time, stock WW behavior); (2) `"tesla_gun"` in `_acc_map_randomizer::register_mystery_box_pool`
  `box_weapons[]`. KEY: our weapon table is a **slim 22-row OVERRIDE** of the stock common table (same path,
  usermap copy wins), so a stock gun is NOT auto-present — it needs the CSV row for `level.zombie_weapons` to
  hold a struct the box gate can flip (the octobomb/cymbal_monkey precedent). Stock weapon = full cooked
  sounds + stock damage (no `gen_box_weapon_sounds` / no `_acc_damage` balance entry).
- **Box odds caveat (set expectations):** the BO3 box is a UNIFORM draw — `is_wonder_weapon` does NOT make it
  rarer. In the ~19-gun pool it rolls ~1/19 like any box gun. A true rare-roll (or a dedicated reward) would
  need custom weighting code — not added (user chose uniform).
- **FIX — couldn't PaP a 3rd time (user 2026-06-19):** the Wunderwaffe packed to tier 2 then refused tier 3.
  Root cause: I'd copied stock's `is_aat_exempt=TRUE`. The map's 3-tier PaP reaches tier 3 via the stock
  machine's *re-pack* prompt on an already-upgraded gun, and stock gates that prompt on
  `!can_upgrade_weapon && !weapon_supports_aat` (`_zm_pack_a_punch.gsc:303/412`) — an AAT-exempt upgraded gun
  shows NO prompt, so our `custom_validation` tier-up hook never fired. Set `is_aat_exempt=FALSE` so the
  re-pack prompt appears; our hook still returns false so no actual alt-ammo is ever applied (the map never
  grants AAT). Now packs all 3 tiers like every other gun. CSV-only, `-GscOnly`.
- **⚠️ LAUNCH-VERIFY** (BUILD OK ≠ runtime): box-roll until `tesla_gun` appears, confirm it draws + fires
  (chain lightning) + PaPs to `tesla_gun_upgraded`. If it never shows, the box log says
  `! box weapon missing from weapon table: tesla_gun` (graceful degrade, no crash) = the asset wasn't cooked
  on this install after all → fall back to `ray_gun` (the known-good shipped precedent).

### Changed — Shard economy scaled WAY down so 1 shard matters + Cyberware tree cut (user, 2026-06-19)

Tight, even, low numbers. `-GscOnly`, BUILD OK.
- **Cap 99 → 30** (= the cost to fully overclock one weapon). `ACC_SHARDS_MAX`.
- **Data Caches: flat 1 shard each**, once/round, first-come (was 2/3 + round scaling; scaling removed).
- **Trench Warden: everyone +2** (was 3). `acc_warden_shard_reward`.
- **Glitch Altar: 2/spin** (was 4); jackpot 7→3, drain 6→2. Still net-negative EV.
- **Reactor: reworked** — FREE, **once per round**, survive the surge → **everyone +3 shards + a shared
  Insta-Kill** (was a paid, escalating-tier sink with a Mega Bottle). Per-round re-arm on `acc_round_start`.
  `acc_reactor_reward` (3), `acc_reactor_waves`/`_wave_count`/`_wave_interval`.
- **Overclock tier costs 2/4/8/16** (was 1/2/3/4) = 30 to max one weapon.
- **Cyberware tree REMOVED** from play (`acc_cyberware_on` 0; kiosk no longer spawned). The weapon Overclock
  terminal is rebranded **"Cyberware Weapon Overclock"** and is now the sole upgrade. Module stays loaded
  (its damage-flag readers are harmless no-ops with no nodes bought); re-enable with `acc_cyberware_on 1`.
- **Overclock EFFECT redesigned (user choice):** each tier now gives a SMALL boost to ALL FOUR effects at
  once (was: roll one random effect per tier), scaling with the gun's tier — minimal at T1, full at T4.
  **Per-gun** (tracked on the held weapon, carries through PaP). New `_acc_damage::get_oc_tier`; the four
  effects scale off it: ADS damage `+acc_oc_ads_per_tier`/tier (0.05), headshot AoE `acc_oc_aoe_per_tier`/tier
  (0.05), ammo-refund CHANCE `acc_oc_adaptive_per_tier`/tier (0.25 → 100% at T4), and armor-pierce = tier/4 of
  the elite frontal resist bypassed (full at T4). The terminal just raises the tier now (no random roll/reroll).
  Engine note: fire rate / reload / mobility are NOT runtime-settable, so "all aspects" = damage + on-hit.

### Changed — All trench machine feedback uses one positioned HUD message (not iprintln) + docs/46 trench guide (user, 2026-06-19)

The altar fix generalized: `iprintln` lands in the bottom notification area where the round counter /
points cover it. Added a shared `acc_utility::hud_msg( text )` — one per-player upper-center hudelem,
dvar-tunable (`acc_msg_y`, smaller = higher; `acc_msg_sec` = hold time), refreshes in place. Routed
**every** trench/shard feedback through it: Glitch Altar, Cyberware kiosk, Overclock terminal, Neural
Expansion Bay (perk slots), Reactor Plinth, Data Caches + the `+X Data Shards` grant tick, and the
Emergency Drop. The altar's own `altar_msg` is now a thin delegate. `-GscOnly`, BUILD OK.

Also added **[docs/46_trench_systems_guide.md](docs/46_trench_systems_guide.md)** — a super-high-level
"what each thing in the trench does" guide (caches / Bay / Reactor / altar / cyberware / overclock /
Warden + the danger + the loop). Systems view; geometry stays in docs/45.

### Added — Two LMGs (M60 + RPD) — the arsenal's first LMG category (user, 2026-06-19)

User wanted two diverse, theme-fitting LMGs ("Stoner63 + HK21 from BO1"). Those exact Skye ports have
**uncompiled xmodels** (linker "Unable to load weapon" — needs APE, not headless; memory
`skye-lmg-ports-uncompiled`), so per the user's follow-up ("pick any LMG from the packs that fit + are
diverse") I shipped the two Skye LMGs whose models ARE compiled, verified by build:

- **M60** (`t6_m60`, Skye BO2) — heavy belt-fed, 600 RPM. **clip 60 / reserve 180** (PaP 100/300). Balance mult **0.15** (~435 DPS).
- **RPD** (`t6_rpd`, Skye BO2) — faster drum-fed, 750 RPM. **clip 60 / reserve 180** (PaP 100/300). Balance mult **0.13** (~440 DPS; lighter feel).
- Both **box-only**, **twin-less** (weapon-count cap). Wiring: rows in `zm_levelcommon_weapons.csv` (class `lmg`,
  cost 1500) + `weapon,*`/`*_up` in the `.zone` + `_acc_map_randomizer` box pool + `_acc_damage::acc_weapon_balance_mult`
  + activated the dormant `_acc_overclocks` `lmg_list`. Build loaded both clean (no "Unable to load").
- **REBALANCE (user 2026-06-19): they held WAY too much + hit too hard.** Native was clip 100 / reserve 400 (base)
  and PaP clip 300-200 / reserve **900-1000** = you never reloaded. Cut via `reduce_base_ammo.js` CLIP_FIX
  (base 60 / PaP 100) + MAXAMMO_FIX (3 mags → base reserve 180, PaP 300), and dropped the damage mults 0.17→0.15
  (M60) / 0.15→0.13 (RPD) so they sit just BELOW the AR Good band (LMG = sustained fire, not top per-shot).
  Ammo path: `reduce_base_ammo.js` → `gdtdb /update` → relink. Twin-less, so the `_up` PaP forms are the only
  variants and got the same treatment (CLIP_FIX `_up` + the damage substring covers `_up`).
- **Pre-test audit (4-agent) caught 2 fixes** before the audit's verdict: (a) **balance was ~2× hot** — the
  first-pass mults (0.33/0.27) assumed lower raw GDT damage; corrected to 0.17/0.15 to land ~500 DPS like the
  AE4/AK-74u peers. (b) **silent guns** — the Skye pack ships M60/RPD `.wav`s but no aliases, so added them to
  `tools/gen_box_weapon_sounds.js` (fire + PaP-fire + auto-scanned foley) → regenerated `acc_skye_box_weapons.csv`.
  Sound needs a **bank rebuild** (the linker reuses stale `CachedBanks` on a relink, docs/35) — cleared the
  cached banks + FULL build so the `.szc` recompiles. crash-modes / registration / PaP all PASSED the audit.
- **⚠️ LAUNCH-VERIFY** (BUILD OK ≠ runtime-proven): box-roll each, confirm they draw + **fire WITH sound** +
  reload/foley + PaP (`_up`) + the Overclock terminal offers the LMG family, and kill-rounds feel ~peer (not 2×).

Playtest hit "I walk up to it and can't use it." Root cause: a script-spawned `trigger_radius_use` is NOT
player-usable in ZM until you call `TriggerIgnoreTeam()` on it (ZM players carry a team; the fresh trigger's
team filter excludes them). The stock perk machine (`_zm_perks.gsc:1523`) and navcard (`_zm_utility.gsc:5442`)
both call it; our only one that did was the elite-kill shard pickup. **Every other trench interactable omitted
it** — so the Glitch Altar, Cyberware kiosk, Overclock terminal, Data Caches, the perk-slot **Neural Expansion
Bay**, and the Reactor Plinth all spawned but gave no usable prompt. Added `t TriggerIgnoreTeam();` to all six
(right after spawn, before `SetCursorHint`). This is why "can't increase past 4 perks" — the Bay was unusable.
`-GscOnly`, BUILD OK. Memory: `script-trigger-needs-ignoreteam`.

### Added — PANZER (mechz) boss spawns at Plaza — from-scratch integration, SPAWNS in-game (user, 2026-06-19)

Clean-room redo of the broken decompiled Panzer attempt (Phantom removed earlier; Panzer takes the
~round-10 boss slot). **Verified in-game: the Panzer SPAWNS at Plaza** (the map starts fine — the earlier
"can't start" was transient). The attack-crash (the historical killer) is the one remaining gate to confirm
by playtest (melee/shoot/kill it).

- **`_acc_boss_panzer.gsc` rewritten** — round-10 cadence, spawns the mechz at the central Plaza riser
  (`acc_panzer_spot`/`mechz_genesis_spawner`, `-227.5 350 0`), boss bar + `acc_boss::boss_music` + on-death
  rewards, Brutus CTD-safety flags (`acc_boss_custom_speed`). Calls `mechz_spiki::mechz_health_increases()`
  first (it's defined-but-never-called → otherwise HP = undefined).
- **Attack-crash fix** (`mechz_spiki.gsc`) — stock `mechz.gsc` registers `mechz_face` at VERSION_SHIP and
  sets it on attack/death/idle/pain, but the usermap client never registers it → set-on-attack = layout
  desync crash. Fixed by re-binding the 4 face StartFunctions (`mechzAttackStart`/`Death`/`Idle`/`Pain`,
  name-bound via `BT_REGISTER_API`, last-write-wins) to a no-op so `mechz_face` is never set.
- **Spawner classname** — `actor_archetype_zm_mechz_genesis` (the `actor_<aitype>` pattern, like the charred
  spawner). `actor_spawner_zm_castle_mechz` is a DLC class this install rejects ("not a valid aitype").
- **Zone** — `aitype,archetype_zm_mechz_genesis` (its `.ai_asm`/`.ai_bt` are on disk) + mechz models/fx.
  `.ff` +4 MB. Non-fatal waived noise: `gfx_spark_blink_anim_pcloud_em` (from `fx_mech_dmg_sparks`) +
  `mechz.zpkg` — cosmetic; trim `fx_mech_dmg_sparks` for a clean log.
- A full revert + re-apply was exercised; the changes are stashed in `tools/_panzer_stash/`. Workshop stays
  Private until the IP/credit review (the mechz pack is an unlicensed game-rip; gitignored).

### Added — The Reactor Surge: the underground climax event (new `_acc_reactor.gsc`, docs/45) (user, 2026-06-19)

The marquee shard SINK at the top of the trench risk/reward ladder. An **Arm Plinth** in the pit (the docs/45
§3 anchor (0,2120,-240), on existing pit floor at the future Core entrance): pay shards to trigger a **timed,
escalating zombie Surge** that erupts from the pit floor (reuses `acc_bus_trench::spawn_corp_surge` — tagged
low-payout + `ignore_enemy_count`, so the round count is untouched); **survive it** for a **tier-dialed payout**
(shards + Insta-Kill + a Mega Bottle). Each completion **raises the tier** — the next Surge costs more and pays
more. You don't farm it, you raid it.

- **Self-contained + geometry-safe:** all GSC, no `.map`. The Plinth sits on the existing pit floor and the
  Surge runs **open in the pit** today (the spawned zombies persist and hunt you — a real survival test). When
  the parallel geometry agent builds the Core room + seal, it becomes a true sealed arena via a named-entity
  contract: a `script_brushmodel` `targetname acc_reactor_seal` that listens for `acc_reactor_seal_close` /
  `acc_reactor_seal_open` notifies (until it exists, `getentarray` is empty → harmless no-op).
- **Owner split honored (docs/45):** system agent owns the event logic + Plinth + payout (this module);
  geometry agent owns the Core room, seal door, FX seam. Wired in `_acc_main` after `acc_glitch_altar`;
  `scriptparsetree` added to the `.zone`.
- **Dvars:** `acc_reactor_on`(1), `acc_reactor_cost`(8)+`_step`(2)/tier, `acc_reactor_reward`(10)+`_step`(3)/tier,
  `acc_reactor_waves`(3), `acc_reactor_wave_count`(5+tier), `acc_reactor_wave_interval`(6), `acc_reactor_bottle`(1).
  `-GscOnly` build, BUILD OK. Not yet playtested.

### REVERTED — Death-screen "RESTART LEVEL" menu broke the map load (user, 2026-06-19)

Attempted a `zm_countryside`-cloned game-over "RESTART LEVEL" button (LUI `Intermission_Main.lua` rawfile +
`_acc_restart_menu.gsc` opener). It LINKED ("BUILD OK", Lua syntax OK) but added an **UNRECOVERABLE linker
error** — verified by bisection: with the menu in, the build reported **6** unexpected errors + UNRECOVERABLE;
removing it dropped to **5** (the unrelated concurrent Panzer errors) and the UNRECOVERABLE disappeared. The
`.ff` it produced **would not load** (user: "I cannot start the map anymore").

- **Reverted in full:** deleted `_acc_restart_menu.gsc` + `ui/uieditor/menus/Intermission/Intermission_Main.lua`,
  removed the `acc_main` `#using`/`init` + both `.zone` lines. `-GscOnly` rebuild → BUILD OK, no UNRECOVERABLE.
- **LESSON (hard-won):** a custom LUI menu rawfile can pass the linker's Lua *syntax* check yet still cause an
  UNRECOVERABLE link error (likely the `require(...)` of stock widgets / overriding the stock `Intermission_Main`
  menu name) that yields a non-loadable `.ff` — "BUILD OK" is NOT proof of a loadable map for LUI menus.
  If we retry a restart MENU later, build it incrementally + confirm the map LOADS, and prefer a uniquely-named
  menu over overriding a stock one. (The stock pause-menu Restart, `restart_level_zm`→`MissionFailed`, is the
  zero-risk alternative.)

### Fixed — Glitch Stalker corpses lingered on the ground (cleanup-skip bug; possible crash factor) (user, 2026-06-19)

User saw "glitch bodies on the ground" and wondered if they crashed the game. Root cause: the Glitch Stalker
sets `acc_is_mini_boss=true` (for the 2× headshot multiplier), and `_acc_corpse_cleanup` **skips** anything
flagged boss/mini-boss (so death-anim bosses like Brutus aren't deleted mid-animation). But the Glitch
Stalker is a **reskinned zombie with NO death anim**, so its body just lingered — and the lockdown challenge
spawns ~30 of them, so they pile up (entity bloat → a real crash suspect).

- **Fix:** `_acc_boss_glitch::glitch_death_watch` now threads `cleanup_glitch_corpse()` on death (NotSolid +
  Ghost now, then Delete one frame later) — for BOTH the normal kill and the lockdown-tagged (`acc_ldc`)
  path, *before* the reward branch (so the drop still captures `self.origin` first). Mirrors
  `_acc_corpse_cleanup::corpse_linger_remove`.
- Regular zombies + elites already vanish on death (cleanup linger default 0). Brutus/Panzer keep their
  death animations (intentionally skipped). The **Phantom** (currently disabled) would need the same one-liner
  if re-enabled. `-GscOnly` build, BUILD OK.

### Removed — Phantom boss disabled for now (it overlapped the Glitch Stalker); Panzer to take the slot (user, 2026-06-19)

The Phantom read as a redundant, less-aggressive Glitch Stalker (both cyan + phase/"blink" + tanky), so
it's **disabled by default** (`ACC_PHANTOM_ENABLE_DEF` 1→0) while the **Panzer (mechz)** is wired in from
scratch to take the ~round-10 boss slot. The module + its `.csc` aura are left fully intact and
recoverable — flip `acc_phantom_enable 1` to bring it back (ideally re-themed distinct from the Glitch
first). GSC-only (`-GscOnly`). The Panzer integration is a separate, in-progress from-scratch effort.

### Changed — Data Shards become a TRENCH-ONLY economy + the trench is finally worth descending into (user, 2026-06-19)

A 27-agent audit found the trench was all-risk-no-reward: today's geometry rewrite (`fill_trench_rooms.js`
+ `add_under_room.js`) had **stranded 4 of 5 underground interactables in void/solid** (the GSC placer in
`_acc_glitch_altar.gsc` still targeted the deleted Hall A / Chamber B coords — only the altar landed on
floor), the main weapon sink was **16/22 inert overclocks**, the dev grant pinned everyone at the 99 cap, and
the signature trench boss dropped no shards. Full incentive pass (all GSC-only, `-GscOnly`, no LED bake):

- **Underground content re-placed onto the live geometry** (`_acc_glitch_altar.gsc::spawn_altars`, coords now
  PINNED to `add_under_room.js`). **SOURCE: 2 Data Caches in the EXPOSED trench PIT** (`±360, 1950, -240`) —
  you brave the amped horde/slow/surge to loot them, no door needed. **SINKS: the Foundry inside the enclosed
  room** (`y[1379,1723]`, behind the 1500 `enter_under_plaza` door): Glitch Altar (center) + Cyberware kiosk
  (`-140,1420`) + Overclock terminal (`140,1420`), all on real floor, triggers spaced clear of each other.
- **Trench-only sources (user choice):** the topside **elite shard drop is OFF by default** (`acc_elite_shard_drop`
  0) and the **Trench Warden now pays shards** on death (`acc_warden_shard_reward`, default 3, all players,
  skips the dev bulk boss). Shards now come from the trench: pit caches + Warden + altar jackpot.
- **Pit-cache yield scales with the round** (`_acc_data_shards::cache_yield`: base + 1 / `acc_cache_scale_rounds`
  rounds, cap `acc_cache_yield_max` 9) so the trench faucet keeps pace; re-arms each round (unchanged). Bases
  `acc_cache_w_count` 2 / `acc_cache_e_count` 3.
- **Overclock terminal no longer sells no-ops:** `build_family_pools` TRIMMED to the 4 implemented effects
  (Overpressure / Piercing-Penetration-Breach / Adaptive Aim / Reactive Powder), every family gets all 4,
  `ACC_TIER_MAX` 5→4 so every tier-up rolls a REAL effect (maxing a gun = 1+2+3+4 = 10 shards). Reroll at max
  now dry-runs first so a fully-overclocked gun is never charged for nothing.
- **HUD always-on (dim at 0):** the Data Shards counter is now visible at 0 shards (alpha 0.35 vs old 0) so the
  currency is discoverable (`_acc_data_shards::sync_shards_to_client`).
- **Real economy is now testable:** the dev shard firehose is gated behind `acc_dev_shards` (default 1) — flip
  `acc_dev_shards 0` to playtest with money/open-map dev still on.
- *Still inert (separate follow-ups, not shard-loop blockers):* cyberware `rx3` Overdrive + `oc2b` Fission, the
  Emergency-Drop overclock-scroll, the EMP cyberware-lockout. Tracked in memory `data-shard-trench-economy-audit`.

### Added — The marquee shard incentive: buy PERK SLOTS in the trench (start at 4, up to 9) (user, 2026-06-19)

The headline reason to chase shards. You now **start with 4 perk slots** and **buy more (up to 9) with Data
Shards** at a new **Neural Expansion Bay** in the exposed trench pit — the most powerful upgrade demands the
most danger.

- **Per-player cap via the stock hook:** `acc_perks::acc_perk_slot_limit` is installed as
  `level.get_player_perk_purchase_limit` (_zm_utility.gsc:5874-5889), returning `base + player.acc_perk_slot_bonus`.
  The global `level.perk_purchase_limit` dropped 9 → **4** (the base/floor); the hook adds each player's bought
  bonus on top, so it's individual in co-op.
- **Escalating sink:** each extra slot costs `acc_perk_slot_cost_base`(4) + bonus×`acc_perk_slot_cost_step`(2)
  → 4/6/8/10/12 shards (40 total to go 4→9) — a long-horizon goal bigger than the whole Cyberware tree. Caps at
  `acc_perk_slot_max`(9). Vendor `acc_perks::spawn_perk_slot_vendor_at`, placed by `_acc_glitch_altar` in the pit
  at (0,1800,-240).
- **Dev:** `acc_dev_perks` (default 1) makes the hook return max in dev so every machine is buyable while
  testing; flip `acc_dev_perks 0` (with `acc_dev_shards 0`) to playtest the real perk-slot purchase. The old
  `_acc_dev` `perk_purchase_limit = 18` is now superseded by the hook.

### Changed — Glitch Altar: Mega Win is now a ~1% jackpot (user, 2026-06-19)

The altar weights sum to 100 (= % chance). **Mega Win** (free Perk + Insta-Kill) cut 6 → **1** (the rare single
big win); the freed weight went to the common boons (Max Ammo 16→18, Free Perk 10→12, Shard Jackpot 12→13) so
the boon/curse split stays ~72/28. (`_acc_glitch_altar.gsc::resolve_gamble`)

### Changed — Hack Terminal / Vault Overload shard rewards OFF by default (trench-only) (user, 2026-06-19)

Adversarial review caught that these two **topside** objectives still paid shards (+2 / +3), contradicting the
trench-only economy. Both shard grants are now gated behind `acc_hack_shard_drop` / `acc_overload_shard_drop`
(default **0**). The Vault Overload's map-shortcut unlock still fires (its real payoff). Flip the dvars to 1 to
restore them as surface sources.

> **Coordination note:** the underground is being redesigned in parallel into "The Black Market" (docs/45). The
> shard-system spawn coords follow the docs/45 §3 anchor table where rooms exist (Altar + pit caches match
> exactly). Cyberware/Overclock anchors there target the new Stalls/Cages rooms (not built yet), so they stay in
> the existing Foundry room until that geometry lands, then migrate. The Neural Expansion Bay needs a §3 anchor
> row (currently in the guaranteed pit floor at (0,1800,-240)).

### Changed — Phantom: made genuinely menacing (he earns the guaranteed Mega Bottle) (user, 2026-06-19)

The Phantom drops a guaranteed Mega Bottle but wasn't threatening — same melee as a normal zombie, only
1.1× speed, and he revealed from 400u away. Scary pass:

- **Hits HARD:** sets `host.meleeDamage` = `acc_phantom_melee_dmg` (**85**, vs the 45/60 horde) after the
  init-gate — confirmed it sticks because `_acc_zombie_speed::apply_speed_for_round` returns early for any
  boss, so the trench-melee system never resets it. Two hits down a no-Jug player, and you don't see them coming.
- **Relentless:** `acc_phantom_speed_mult` 1.1 → **1.4** (hard to kite).
- **Startling reveal:** `acc_phantom_reveal_dist` 400 → **240** — he stays cloaked until he's almost on you,
  then materializes (with the cyan aura burst) right in your face.
- **Materialize screech:** new `materialize_scare()` plays a warp screech (`acc_glitch_warp`, the confirmed
  Glitch SFX) on the cloaked→visible reveal, 2 s cooldown'd. Gated by `acc_phantom_screech`.
- **Tankier:** `acc_phantom_hp_mult` 8 → **10** (survives long enough to press the attack).
- New dvars: `acc_phantom_melee_dmg`, `acc_phantom_screech`. All live-tunable — dial speed/melee down if too
  brutal. The guaranteed Mega Bottle drop is kept (the reward now matches the danger). GSC-only (`-GscOnly`).

### Added — Crash-diagnostic breadcrumb logging for the boots+slide CTD (user, 2026-06-19)

User hit a random crash equipping the Boots item and then sliding. GSC can't catch a hard engine CTD, so
instead we drop a breadcrumb at each step of the suspect paths — the LAST `[CRASHDBG]` line in
`console_mp.log` = the step just before the crash.

- **New channel `acc_utility::crash_log(player, msg)`** — gated by the `acc_crash_debug` dvar (default 0,
  silent). Routes via `IPrintLnBold` (the only channel that reaches `console_mp.log` as `[ SCRIPTER]`).
  Plus `acc_utility::active_speed_flags(player)` for a compact active-flags string.
- **Instrumented every slide-triggered path + the convergence point:**
  - `_acc_utility::recompute_move_speed` — logs scale + active flags **immediately before** `SetMoveSpeedScale`
    and again after (so if the CTD is that engine call, you see the value but never the "OK").
  - `_acc_boss_items`: `apply_boots`/`remove_boots`, and `rocket_shield_watch` (slide-kick `SetVelocity` + slide on/off).
  - `_acc_mega_bottles::mega_flopper_slide_watch` — slide on/off.
  - `_acc_perk_phd_flopper::phd_slide_watcher` — before/after `phd_explode` (the slide-to-explode nova, the
    most complex slide-triggered action).
- **Usage:** launch with `+set acc_crash_debug 1 +set logfile 1`, reproduce, then read the last `[CRASHDBG]`
  lines in `<game>\console_mp.log`. Off by default → no spam in normal play. `-GscOnly` build.

### Fixed (PERMANENT) — Perk machine facing FORCED at runtime, immune to .map reverts (user, 2026-06-19)

The facing reverted a **4th** time: concurrent `.map` restores keep rolling the perk-struct `"angles"` back
to the wrong `"0 270 0"`, and re-fixing the (baked) `.map` keeps losing that race. **New durable fix:** force
the facing at **runtime** in GSC, where it's immune to whatever the `.ff` baked.

- `_acc_perks::force_perk_machine_facing()` (threaded from `init()`): polls until the perk machines spawn,
  then sets each machine **model's** angle to yaw `acc_perk_face_yaw` (default **359.999** — the established
  facing). Reuses the proven handle: stock `perk_machine_spawn_init` (`_zm_perks.gsc:1526-1560`) spawns each
  machine as a `script_model` linked to its `zombie_vending` use-trigger via `trigger.machine` (the same
  trigger `_acc_perk_lights` already uses). Re-asserts a few times post-spawn. `-GscOnly` build.
- The `.map` fixes still stand (`fix_perk_facing.js` + `add_perk_alcoves.js` now emits 359.999) so the
  editor/baked state is correct too — but the runtime force is the guarantee. **This should be the last time.**

### Fixed — Perk machines facing the wrong way AGAIN (recurrence) + root cause (user, 2026-06-19)

The 9 Lab perk machines were facing the wrong way again — a `.map` restore (the bus-station floor fix)
rolled their `"angles"` back to `"0 270 0"`, the value `add_perk_alcoves.js` originally stamped. The
vending models actually face the player at **`"0 359.999 0"`** (270 = "face south" was wrong; documented
the first time, 2026-06-18).

- **Current `.map` fixed:** re-ran `tools/fix_perk_facing.js` → all **9** machines set to `0 359.999 0`
  (3 inline `zm_perk_machine` + 6 vending-prefab structs); the 74 riser angles (legitimately `0 270 0`)
  were left untouched.
- **Root cause fixed (durability):** `add_perk_alcoves.js::setSouthFacing()` hardcoded `"0 270 0"` — now
  emits `"0 359.999 0"` (a named `MACHINE_ANGLES` const), so re-running the alcove generator no longer
  re-breaks the facing.
- **⚠️ Known fragility:** the facing lives in the `.map` entity lump, so **any `.map` restore from an old
  backup reverts it. After restoring the `.map`, re-run `node tools/fix_perk_facing.js`** (idempotent).
- Full build (cod2map re-emits the entity lump → LED → linker).

### Fixed/Added — Roofs: full coverage (corridors + east strip) + de-duplicated stacked ceilings (user, 2026-06-19)

Finished the ceiling pass — **every non-Plaza floor is now roofed** (Plaza stays open). A deterministic
coverage probe (`tools/probe_coverage.js` — parses each brush as axis-aligned planes, grid-samples
floor-without-ceiling) showed the room bounding-box ceilings missed all 8 room-to-room **corridors** + a
central Plaza→Bus-Station **spine** + a walled strip **east of the Alley**. Added a ceiling + light for
each (abutting the room ceilings edge-to-edge, no overlapping coplanar slabs). Coverage probe now reports
**MISSING = 0**.

Also fixed a **dedup bug in `gen_room_roofs.js`**: the old `strip()` only removed the *first* ceiling per
re-run, so repeated runs (×2 agents) stacked **2–3 duplicate coplanar ceilings** at the same z (an LED
overlap hazard + bloat — 34 ceiling entries for ~16 areas). Rewrote `strip()` to remove **every** roof
artifact by its `-ACC7-` guid marker (order-independent, idempotent); one run collapsed 34 → **16 unique
ceilings, 0 duplicate footprints**. Full build OK (cod2map → LED bake → linker → fresh `.ff`); the brighter
grid lighting bakes in ~15s. (Two pre-existing/concurrent linker FX errors — the Ripper SMG shell-eject
and the Phantom boss's `fx_apothicon_fury_spawn_in_exp` invalid atlas — are unrelated to the roofs; the
`.ff` builds, those FX just won't render.)

### Fixed — Power switch: one wall switch with native anim + sound (dropped the mid-air duplicate) (user, 2026-06-19)

The Bus Station ended up with TWO stacked switches: a stock `power_switch` **prefab** wall-mounted at
`(790 1600 1)` — which has the native flip animation + power-on sound — **and** our custom
`acc_power_switch` trigger, whose generator brush has degenerate winding so its centroid floated and the
(earlier-spawned) lever model appeared **mid-air**. User chose to keep the wall prefab and remove the
mid-air duplicate.

- **`_acc_power.gsc` now STANDS DOWN** (replaces the earlier same-day "spawn a lever + decouple the sound"
  attempt): it no longer deletes the prefab's stock `use_elec_switch` trigger (so stock `_zm_power` powers
  the map **natively** — animation + sound — when you flip the wall switch), no longer spawns a lever
  model, and just **deletes our leftover `acc_power_switch` trigger(s)** at runtime so there's no mid-air
  use-prompt. Pure GSC, no `.map` edit → LED-safe, no interference with concurrent Radiant edits.
- Reverted the two `xmodel,p7_zm_der_pswitch_*` zone lines (the script-spawned lever is gone) and the
  `acc_power_*` tuning dvars. `acc_auto_power` stays `0`, so the player still flips the wall switch.
- The custom DUAL-switch is recoverable from git if wanted later (restore notes in `_acc_power.gsc`).

### Changed — Interior lighting: brighter + denser grid (user, 2026-06-18)

The roofs (ceilings on every room except Plaza) made interiors dark, and the hand-placed 4-6 radius-150
lights per room were far too dim — "we need a ton more light inside, it's so dark; trenches can be dark."

- **`tools/gen_room_roofs.js`** now fills each ceiling footprint with a **GRID** of lights (was a hand-placed
  4-6) and brightens each one: `LIGHT_RADIUS` 150→320, `bake_intensity_scale` 1→1.3, `GRID_SPACING` 420.
  Result: **62 lights** (was 28) — corp 16, lab 12, each other room 6, plus the corridors. All tunable
  constants at the top of the generator; re-run + FULL build (LED) to retune.
- **Trenches stay dark** — `gen_room_roofs.js` lights only the rooms + corridors; the trench / trench-rooms
  get no lights, so they remain dark in both lighting states.
- FULL build with the LED bake (geometry/light change → BSP+lightmap re-bake; the bake is the gate).

> ⚠️ **CORRECTION (2026-06-19): the "already power-gated" claim was WRONG** — see the dim/bright entry below.
> The lights carried `lightingstate1..4="1"`, so the `set_lighting_state(0)→(1)` power flip was a NO-OP
> (lit in both states). The fix is the dim/bright state split below.

### Changed — Lighting: DIM before power, BRIGHT on power (lighting-state OFF-BY-ONE fix) (user, 2026-06-19)

User: "add a dim light — still hard to see but you can see — then way brighter when power is on." A
parallel research pass (verified vs stock `zm_giant_light.map` + `share/raw/scripts/shared/util_shared.gsc`)
uncovered the real mechanism + a bug:

- **BO3 lighting-state OFF-BY-ONE (hard-won):** GSC `set_lighting_state(N)` displays Radiant **State N+1** =
  the light field `lightingstate(N+1)`. There is **no `lightingstate0` key** (absent from `bin/t7.def.json`).
  Our `CheckForPower` runs `set_lighting_state(0)` pre-power then `(1)` on `power_on`, so **pre-power =
  `lightingstate1`, post-power = `lightingstate2`**.
- **The bug:** all 62 grid lights had `lightingstate1..4="1"` → lit in *both* states → the power flip did
  nothing; the scene only looked dark because `volume_sun global_fill_color="0 0 0"` (black base).
- **The fix (`gen_room_roofs.js`):** emit **two** lights per grid point, split by state —
  a **DIM** set (`lightingstate1="1"`, others `"0"`; `DIM_RADIUS` **220**, `DIM_INTENSITY` **0.02** — stepped
  0.30→0.15→0.06→0.02 on 2026-06-19 per user, final ask "almost pitch black inside"; a parallel audit confirmed
  each step WAS live/baked, just too bright; the bright/post-power set was kept "perfect" and untouched) lit
  **pre-power only** = the faint navigable floor; and the existing **BRIGHT** set (`lightingstate1="0"`,
  `2/3/4="1"`; radius 320, intensity 1.3) lit **post-power only** = the powered look. **126 lights** (63 dim
  + 63 bright). No GSC change. Masks/`DIM_INTENSITY` tunable at the top of the generator.
- **Trenches stay pitch-dark** (no lights there, no global ambient added). FULL build, LED baked clean.
- Documented fallback (not used): a faint state-independent floor via `volume_sun global_fill_color` if the
  dim lights ever read too dark in corners — but that lifts trenches + reduces contrast, so dim lights win.
- **Dark inside / safe outside (user 2026-06-19):** final ask was "almost pitch black inside; feel safe
  outside until power." An audit found the open Plaza was NOT sky-lit (default_night + black global_fill),
  so it was dark too. Added an **always-on Plaza light grid** (`acc_roof_light_plaza_*`, `lightingstate1..4`
  all `"1"` = `ALWAYS_MASK`, **15 lights**, `PLAZA_INTENSITY` 0.55, `PLAZA_RADIUS` 360, NO ceiling — Plaza
  stays open) so OUTSIDE is a lit safe haven in both power states, while the roofed rooms (DIM 0.02) go almost
  black pre-power. **141 lights** total (63 bright + 63 dim + 15 Plaza).

### Changed — Perk-door rotation CUT (temporary): all 9 alcove doors open every round (user, 2026-06-18)

The per-round random-3-of-9 Lab perk-door rotation is temporarily disabled — all 9 alcove doors now
open every round (every perk always buyable). The user wants it back later, so the cut is minimal and
clearly reversible.

- `_acc_perk_doors::init()` now just calls `open_all()` and does NOT start the round watcher. All the
  rotation machinery (`watch_rounds` / `apply_round` / `roll_order` / `candidates_excluding_last` /
  `close_all` / `dev_all_open`) is left **intact-but-unused** — a `CUT 2026-06-18` comment block in
  `init()` gives the exact one-line restore (`if(dev_all_open()) open_all(); else close_all();` +
  `level thread watch_rounds();`). A STATUS banner at the top of the file flags the override.
- **Side effect (documented in docs/13):** since every Lab machine is now always reachable, every base
  perk is also always **Mega-able** — the "wait for your perk to rotate in" Mega-bottle texture is paused
  until the rotation is restored. No code change to the Mega path (the gate was physical access only).
- Verified the rotation is self-contained: only `acc_main::init()` calls into the module, and nothing
  else touches the `acc_perk_door_*` gates (the `_acc_map_randomizer` mention is an inert comment).
- GSC-only (existing geometry, just left open) → `-GscOnly`, no LED bake.

### Changed — The whole underground IS the trench now + a calmer 4s danger warning (user, 2026-06-18)

Two trench tweaks in `_acc_bus_trench`:
- **The new underground rooms + Hall/Chamber floor now count as "the trench"** — they were a respite, but the
  user wants the entire sub-level to carry the trench danger. `player_in_trench` now aliases
  `player_in_underground` (the broad footprint), so **every** trench effect that gates on it — −35% move slow,
  spawn surge, raised AI cap, zombie aggro (`_acc_zombie_speed`), and the danger warning — applies anywhere down
  there, not just the open pit. (The fall-tax still only *fires* on a real fast fall, which only happens dropping
  into the pit, so walking room-to-room never gets taxed.)
- **The red danger warning is shorter + less naggy** — was a continuous fast pulse; now a **4s** window
  (`acc_trench_warn_sec` 5→4) with a **slower ~2s pulse** (new dvar `acc_trench_warn_pulse`, default 1.0s
  half-cycle = ~2 gentle breaths) that auto-offs and only re-triggers on a fresh entry. GSC-only.

### Added — Real models + pickup/use logic for the underground systems (the "Foundry") (user, 2026-06-18)

Wired actual stock models + interaction onto every underground system (placeholders → real props), all
**verified to pack** (present in the build `xmodel.csv`; errorlog clean of "missing", only benign DROPPED-VERTS
mesh warnings). Models chosen from **docs/44** (stock model reference), all `p7_cai_*` family (same as the
proven-packed Plaza workbench):
- **Glitch Altar** (Plaza room) — base = `p7_cai_sign_inteactive_kiosk` (interactive kiosk) + a glowing
  spinning orb (`p7_fxanim_zm_stal_ray_gun_ball_mod`) floating above. (Logic already existed.)
- **Data Caches** (Hall A + Chamber B) — `p7_cai_stacking_cargo_crate`; **new** `_acc_data_shards::spawn_cache_at`
  + hold-USE `cache_loop`: grants shards **once per round** then shows "depleted" until round start (anti-grind:
  one pay/cache/round to whoever loots first; `vault_cache` tag skips the elite diminish). This is the
  underground shard **SOURCE** (moving collection down here).
- **Cyberware kiosk** (Chamber B west) — `p7_cai_work_table_metal_03_white`; **new** `_acc_cyberware::spawn_kiosk_at`
  spawns the model + a trigger running the existing `kiosk_loop`. First time the Cyberware sink is reachable in-game.
- **Overclock terminal** (Chamber B east) — `p7_cai_ticket_kiosk_theatre`; **new** `_acc_overclocks::spawn_terminal_at`
  + the existing `terminal_loop`. First time the Overclock sink is reachable.

`_acc_glitch_altar::spawn_altars` is now the underground content **placer** (knows the built-geometry origins);
each system's model+logic lives in its own module. 4 zone `xmodel,` lines added. Pure GSC/`-GscOnly` (models are
runtime-spawned via SetModel; geometry unchanged). Live counts: `acc_cache_hall_count` (2) / `acc_cache_chamber_count` (3).

### Added — Phantom v2: holographic cyan GLOW aura (cloak-aware, client-side FX) (user, 2026-06-18)

The strongest part of the holographic look: a cyan energy glow now wraps the Phantom while it's
MATERIALIZED, so it reads as a destabilizing hologram rather than just a cloaked zombie.

- **Cloak-aware:** the aura is ON only while the Phantom is materialized (near a player) and OFF while
  cloaked — a floating glow over an invisible body would betray its position. Materializing now reads as
  "phases in with a cyan energy burst"; the glow tracks the materialized state, NOT the per-tick flicker,
  so the field stays steady while the body phases.
- **Pipeline = the proven client-FX path** (server PlayFX doesn't render in this build): new actor-scope
  clientfield `accPhantomAura` (1 bit), registered in lockstep by `_acc_boss_phantom.gsc` (server, REGISTER_SYSTEM)
  + new `_acc_boss_phantom.csc` (client, `PlayFXOnTag`, leak-safe). Server sets the field on the cloak
  transitions in `phantom_cloak_loop`; client draws the glow. Mirrors `_acc_perk_lights`.
- **FX = `acc/light/fx_perk_glow_teal`** — the cyan/teal recoloured power-up aura, ALREADY packed (the PaP
  machine uses it) and confirmed to render here → zero new asset. Swap `level._effect["acc_phantom_aura"]`
  in the `.csc` to try a different look (e.g. an electric `.efx`) with no server change.
- dvar `acc_phantom_aura` (default 1) toggles it live. Wired into the entry `.csc` `#using` + a
  `scriptparsetree` zone line. GSC/CSC/existing-FX only → `-GscOnly`, no LED bake.

### Changed — DEFCON cadence (defeat → 4-round cooldown), room-name HUD raised, banner removed, glitch 40 (user, 2026-06-18)

- **DEFCON is no longer a per-round rotation.** A room lights RED and **stays lit until the player
  DEFEATS the challenge inside it**; on defeat the alarm turns **off** (so players don't think another
  is available) and the next DEFCON lights `acc_lockdown_cooldown` (**4**) rounds later, round-robin
  through the four rooms. First DEFCON still gated to `acc_lockdown_first_round` (7); a FAILED attempt
  re-arms next round. `_acc_lockdown::run_lockdown` reworked (keep-lit-until-defeated + cooldown gate),
  `pick_zone` is now counter-based (DEFCONs are sparse), new `on_defcon_cleared`/`on_defcon_failed`
  called from `_acc_lockdown_challenge::challenge_clear`/`challenge_fail`.
- **Glitch challenge total 50 → 40.**
- **Room-name HUD raised 50** (`_acc_dev` zone sign y70 → y20, above the boss nameplate); the
  "`>> <room>`" room-switch banner removed (the persistent label is enough).
- GSC-only (`-GscOnly`), builds clean.

### Changed — Perk/PaP glow: steady GLOW instead of moving sparkle (user, 2026-06-18)

The power-on glow (recolored clones of the green power-up aura, `tools/gen_perk_glow_fx.js`) read as a
rising/twinkling SPARKLE — user wants a steady glow. Added two reshape rules to the generator: kill
`gravity` (50→0, so sprites don't drift up/down) and lengthen every particle's `lifeSpanMsec` ×`LIFE_MULT`
(5, so sprites persist + fade slowly instead of rapidly spawning/dying); dropped `DENSITY` 3→2 to offset
the longer life. Regenerated all 10 `acc/light/fx_perk_glow_*` .efx; `-GscOnly` repack. Tunables in the
generator (`LIFE_MULT`, `DENSITY`, `gravity` rule) — re-run + rebuild to retune. Item-pickup glow (same
effect via the client-FX path) is a separate follow-up.

The Phantom is the real ~round-10 boss, so it gets the full boss treatment; Brutus (now the trench guard)
keeps his HP but drops to a regular mini-boss — no boss music, no boss health bar.

- **Phantom = boss:** named boss **health bar** (`acc_boss_spawned` "PHANTOM", already had it) + boss **music**
  now (`level thread acc_boss::boss_music( host )` in `spawn_phantom`).
- **Brutus down-leveled:** removed the `acc_boss_spawned` emit (no health bar) and the music call from
  `_acc_boss::spawn_brutus_miniboss`. He KEEPS all his HP (`ACC_BOSS_MINI_HP` × coop) + rewards + the
  Trench-Warden roam — just no bar/music. He reads as a tough mini-boss, not THE boss.
- **Generic boss music:** renamed `brutus_boss_music` → `acc_boss::boss_music` (public, refcounted, plays
  the CC0 "Epic Boss Battle" loop, fades 4s on the last boss's death) so any boss can use it. Gated by
  `acc_boss_music_on`. (The next rotation boss just calls it too.)
- Phantom cadence confirmed: first spawn **round 10**, every 10 after (Core owns r30+); `acc_dev 0` to
  see the real cadence (dev mode test-spawns it from round 8). GSC-only (`-GscOnly`).

### Fixed — Perk alcoves: walls now CLOSE, machines face right + better item models (user, 2026-06-18)

Three fixes after testing:
- **Walls weren't closing** — the 3-of-9 rotation was gated behind `acc_open_map` (default 1 → all 9 open in dev).
  Made the rotation the **DEFAULT** (`_acc_perk_doors::dev_all_open` now only all-open if `acc_perk_doors_all_open 1`).
  Round 1 opens 3, the other 6 close, each round swaps to 3 new (no immediate repeats) — no dvar needed.
- **Perks faced the wrong way** — `add_perk_alcoves.js` had reoriented the 9 machines to `0 270 0` (wrong for these
  vending models). `tools/fix_perk_facing.js` reverts the 9 machine entities to their original `0 359.999 0`
  (machines only — the risers correctly keep `0 270 0`).
- **Item models** — +10% Points: double-points icon → **gold brick** (`zombietron_gold_brick`, money; renamed
  "Payroll Ledger" → **"Loot Stash"**) — verified PACKS (xmodel.csv, real geom). Tried a medical syringe for Repair
  Kit but `p7_medical_surgical_tools_syringe` is a campaign asset ("is missing" in zm) → **reverted Repair Kit to the
  proven carpenter** (no zm-packable medkit exists; a custom one needs the Poly Haven→APE route). Full LED bake clean.

The long-standing "enclosed ceilings crash the LED lightmapper" conclusion was **wrong** — it was
confounded by a brush-construction bug. `add_vault_ceiling.js` (and the 2026-06-15 "exhaustive" test
that used it) emit brushes with **real-corner points + a malformed non-hex GUID**, and *that* trips
`brush.cpp:1860`. The proven `gen_zone_greybox` / `add_perk_alcoves` **filler-plane winding + a hex
GUID** bakes fine. Verified via `tools/_bake_test.ps1` on the current map: baseline BAKED 13s; + a vault
ceiling BAKED 12.8s; + a cover box BAKED 13.2s; the same geometry with the old winding CRASHED. So
**roofs AND cover are both feasible** — emit brushes the right way, add incrementally, bake-gate each
batch (the lightmap atlas budget is finite). Memory `led-relight-dead-end-enclosed-geometry` corrected.

First real increment: **the Vault is now roofed** — a `script_floor_ceiling` slab on the z256 walls +
**4 `light` entities** (verified kelson8 `PRIMARY_OMNI`, white, radius **150** — `radius 500` was a
crash; keep omni radius ≤~150). FULL build OK (cod2map → LED → linker → fresh `.ff`); `light` entities
need **no `.zone` line** (worldspawn-baked). New tools: `tools/gen_room_roofs.js` (ceilings + lights,
keyed per room, re-runnable), `tools/gen_room_cover.js` (waist-high cover, proven winding),
`tools/probe_rooms.js` (live room model from spawner/door origins — the old greybox generators are
stale). Plaza stays open/roofless by design. **NEXT (bake-gated, room by room):** roll roofs out to
Helipad/Market/Alley/Bus Station/Lab + add cover (Plaza lightest, Bus Station most hectic), tuning the
lighting to playtest. Backup at `map_source/zm/*.map.pre-roofs-bak`.

### Added — Underground floor, segment 1: tight Hall A + Chamber B off the Plaza-facing room (user, 2026-06-18)

First piece of the **underground gauntlet** (workflow "Data Vault"). `tools/add_trench_floor.js` (post-processor
after `add_trench_rooms.js`, reads the south back-wing's **live** z) carves a 192u-wide **tight hall (Hall A)**
and a wider **Chamber B** extending **south** out of the Plaza-facing trench room, at the same z-band as the
rooms (floor −240, ceiling void top −80). Built as fully-**enclosed sealed boxes** (floor + ceiling-slab-to-z0
+ all walls) with a 192u doorway carved through the room's back wall. **Key validation:** the south extension
**did NOT leak** (cod2map sealed it — the map's outer hull contains the sub-level) and the **LED bake held**
with +15 brushes — so the floor is buildable **segment-by-segment with the generators**, bake-gating each
(refutes the design-critic's "generator geometry can never bake" worst case; the 2 rooms + this segment all
bake). Navmesh regenerated through the doorway (zombies path in). Interiors are empty greybox — shard caches +
the deeper gauntlet (Hall C → Vault/kiosks) are the next segments. Re-run after any `gen_corp_trench`/`add_trench_rooms` regen.

### Added — "Phantom" mini-boss: holographic cloaker, the ~round-10 rotation-boss slot (user, 2026-06-18)

After deep-researching new bosses + boss models, added a NEW script-only boss for the every-~10-rounds
slot (distinct from Brutus the trench guard). The user wanted a custom model, but a genuinely non-zombie
mesh needs Maya/APE rigging (not headless), so this is the **"Cyber Phantom" combo**: a promoted stock
zombie whose identity is built from headless cosmetic levers (the model research's recommended path), NOT
a mesh import. New `_acc_boss_phantom.gsc`, cloned from the proven `_acc_boss_glitch.gsc` template.

- **Holographic CLOAKER:** invisible (`Ghost`) while stalking at range, **materializes** (`Show`) within
  `acc_phantom_reveal_dist` (400) of a player to strike, with a ~12% per-tick **flicker** (brief invisible
  blips) = a destabilizing hologram. Still always solid/hittable (cloak = "can't see it coming," not
  invulnerable). Cyan eyes via the existing actor eye-tint clientfield (shared color, no new `.csc`).
  Distinct stock Giant body as the canvas (mostly cloaked anyway).
- **Cadence = a round-boss ROTATION slot** (user: random pick per ~10-round slot): fires every
  `acc_phantom_interval` (10) rounds from `acc_phantom_first_round` (10), randomly picking from a pool
  (one entry now = Phantom; future script-only bosses register in `run_round_boss`). Yields to the
  Subroutine Core on its sealed rounds.
- **Boss scaffold (all landmines pre-solved by the template):** init-gated promotion, `acc_is_mini_boss`,
  `ignore_enemy_count`, `acc_boss_custom_speed` (keep-alive skip → no ASM-stomp freeze), NO `SetScale`.
  HP = `acc_phantom_hp_mult` (8) × the round's zombie health. Named boss bar. Death → boss-item roll +
  Mega Bottle (`on_boss_death`).
- dvars: `acc_phantom_enable/_hp_mult/_first_round/_interval/_reveal_dist/_speed_mult/_flicker_pct/
  _cloak/_eyes/_stock_skin/_test/_test_round/_debug`. GSC + existing `.csc` only → `-GscOnly`, no LED bake.
- **v2 (offered, not built):** a full-body cyan **glow aura** (an actor-scope clientfield + `PlayFXOnTag`,
  the `_acc_perk_lights` pattern) for the strongest holographic read.

### Changed — Boss-item models: thematic fixes (user, 2026-06-18)

Audited all 8 boss-item models vs their effects; the 6 that fit kept (Gas Tank=nitro tank, Li'l Arnie=octobomb,
Repair Kit=carpenter, Rocket Shield, Monkey Bomb, Phase Serum=bottle). Two mismatches fixed:
- **+10% Points: teddy bear → the double-points ×2 icon** (`p7_zm_power_up_double_points`, runtime-loaded so no
  `.zone` line) + renamed display **"Teddy Bear" → "Payroll Ledger"**. Teddy bear didn't read as cash.
- **Boots: perk-bottle placeholder → real boots prop** (`p7_boots_safehouse_01`) — verified it PACKS (in the
  build xmodel.csv with real geometry; only harmless LOD warnings) + added the `.zone` line (dropped the now-unused
  `p7_zm_teddybear` line). Model_z tuned (8 / 4) — fine-tune live if the pickup floats/sinks. GSC + zone, builds clean.

Decided **what Data Shards DO** (workflow `underground-shards-design`, 14 agents): the user chose **shard
gambling**. New `_acc_glitch_altar.gsc` — a **Glitch Altar** in the Plaza-facing trench room where you spend
shards (default 4) for a **weighted jackpot**: ~72% boons (Max Ammo / Insta-Kill / Double Points / free Perk /
**Shard Jackpot +7** / **Mega Win**) and ~28% glitch-curses (**Surge** / **Corruption** shard-drain / **Dud**)
that **never instant-down** you. Modeled on the Emergency Drop (weighted-pick + `specific_powerup_drop` +
`give_random_perk`), but higher-variance with a real downside and **negative shard EV** (a sink, not a farm).
**Pure GSC** — the altar core + hold-USE trigger are script-spawned (no `.map` entity, no geometry), ships
`-GscOnly` with zero LED risk. Live dvars: `acc_altar_cost/cooldown/jackpot/surge/drain`. Wired in `acc_main`
after `emergency_drop`; docs/06 §Glitch Altar.

**Also fixed (was a latent bug in the 2 new trench rooms):** the OOB hard-kill. `_acc_bus_trench`'s
out-of-playable-area veto only covered the trench **y-band**, so a player standing in a room at z=−240
(outside the band) got the stock ~3 s hp-full no-MOD kill. The veto now covers the whole **underground
footprint** (`player_in_underground`, x[−900,900] y[−400,2900] below z=−36) — the trench + both rooms + any
future floor are safe; the fall-tax/surge stay gated to `player_in_trench` so the rooms remain a respite.

### Added — Stock-model reference doc (user, 2026-06-18)

`tools/gen_stock_models_doc.js` enumerates every stock BO3 xmodel this install references (stock scripts'
SetModel/precache + model-prefixed strings + stock prefabs + GDT xmodels) → **`docs/44_stock_models.md`**
(6001 models, categorized: perks/vending, power-ups, characters, props, weapons world vs view, vehicles,
gore, FX) + flat dump `docs/stock_models_full.txt`. All stock models are Workshop-publishable (ship in the
Mod Tools). Caveat in the doc: a name is a *source* reference — confirm any specific one packs via the build
ERRORLOG (some are DLC/SoE-fastfile-only). Re-runnable after a Mod Tools update.

### Added — Boots boss item (#8) + shrink Li'l Arnies (user, 2026-06-18)

- **New boss item "Boots"** (#8): **+8% move speed everywhere** (`acc_boots_mult` 1.08 factor in
  `_acc_utility::recompute_move_speed`) AND **immune to the Bus Station trench slow** — the −35% trench slow
  is now gated on `!acc_item_boots`, so with Boots you walk normal in the pit. Registered in the
  `_acc_boss_items` pool with `apply_boots`/`remove_boots` (mirror Neural Boots; reapplied on spawn via the
  existing hook). **Model is a placeholder** (`zombie_pickup_perk_bottle`, proven-safe) — swap the string in
  the pool entry to a real boots xmodel any time.
- **Li'l Arnies shrunk to ~1/3** (`acc_arnie_scale` 0.33): the thrown Octobomb's visible model
  (`e_grenade.anim_model`, a script_model in `level.octobombs` — NOT live AI, so `SetScale` is crash-safe)
  is scaled by a new `_acc_boss_items::scale_octobombs_watch` poll. Visual-only; attract/explode behavior
  (on the grenade entity) is untouched. Set `acc_arnie_scale 1` for stock size. GSC-only.

Two greybox rooms now open off the trench at the **trench-floor level**: a **Plaza-facing** room behind the
south wall and a **Lab-facing** room behind the north wall, each gated by a **buyable stock `zombie_door`**
(1500 pts, `enter_trench_plaza` / `enter_trench_lab` → `acc_door_trench_plaza` / `acc_door_trench_lab`) that
slides **sideways** into the wall pocket (so room height isn't limited by a slide-up). Built by
`tools/add_trench_rooms.js` — a post-processor that finds the two ground slabs by their **live** z-bounds (so
it tracks the parallel trench-depth retunes, which had already moved the floor from −288 to −240), carves a
~512×384×160 room into each (the slab above stays solid = the walkable floor), and emits the door entities.
The fall-tax (`_acc_bus_trench`, **y-band gated**) is untouched: it still bites in the pit but **not inside
the rooms** (a respite). **Full LED bake + cod2map navmesh clean** (BAKED 13.6 s, fresh `.ff`); navmesh
regenerates through the doorways so zombies follow once a door is bought. Empty interiors for now (contents
TBD). **Re-run the generator after any `gen_corp_trench` regen.**

### Added — Per-round perk-closet rotation: 3-of-9 open, no immediate repeats (user, 2026-06-18)

The 9 Lab perks now each sit in their own door-gated closet; 3 random open each round, the other 6 walled
off. Two parts: (1) **built the alcove geometry** — ran `tools/add_perk_alcoves.js` (the 9 machines already
lined the Lab north wall at Y=4195, X=−600..600): 10 thin partitions → 9 stalls, 9 `acc_perk_door_<spec>`
script_brushmodel gates across each mouth, machines reoriented to face south. Open-top stalls = **LED bake
clean** (full build). (2) **No-repeat rotation** in `_acc_perk_doors`: each round rolls 3 from the perks that
were NOT open last round (`candidates_excluding_last`), so the 3 that open are always different from the 3
that just closed; door OPEN = hide/notsolid (buyable), CLOSED = show/solid/disconnectpaths (walled off, perks
you already own are unaffected — gate is access-only). Round 1 = any 3 of 9. **To test the rotation without
full ship mode: `set acc_perk_doors_rotate 1`** (in dev, default `acc_open_map 1` keeps all 9 open).

The challenge room stopped locking — a regression I introduced. The prior "crush-safe" seal switched to
`zm_blockers::door_activate(t, false)`, which **`MoveTo`s the door slab down by `script_vector` (130u)**.
That's correct only if the door was opened via the stock buy path (slab slid +130z UP). But **this map
force-opens every door in place** — `acc_hardcoded_open_map` (and `dev_open_all_doors`) do `slab
ConnectPaths(); NotSolid(); Hide()` with **no MoveTo**, so the slab sits at its closed origin z[0,128],
just hidden. `door_activate(false)` therefore slid it **below the floor**, where it blocked nothing. Fixed
by re-closing **in place**: `Show(); DisconnectPaths(); Solid()` (unseal = `Hide(); NotSolid();
ConnectPaths()`, matching how the map opens them). Crush-safety is preserved without moving the slab —
`Solid()` is gated on `door_player_touching()` (stock `IsTouching`, only solidify when the doorway is
player-clear) and the 1 Hz `reseal_monitor` re-asserts it; the commit-time relocate to the room centre
still clears the doorway first. docs/43 §8 + the BO3 KB door recipe corrected (check *how* a door was
opened before re-closing it).

Plus the requested wave bump: **total 30 → 50**, **concurrent 8 → 10**, **stagger 1.3 → 0.6s**, and a new
**fast initial fill** — the first room-load spawns at `acc_lockdown_challenge_stagger_initial` (0.3s) so
the room fills quickly when the trap snaps shut instead of trickling in, then settles to the normal
replacement pace. HUD ("GLITCH PURGE X/Y") and the clear threshold already read the total dvar, so they
track 50 automatically. All live-tunable. `-GscOnly`, no `.map` edit.

### Changed — Slide-speed perks → 1.35×, Mega Flopper now slide-gated + explosive nerf (user, 2026-06-18)

- **Rocket Shield slide: +25% → +35%** (`acc_rocket_slide_mult` 1.25→1.35 in `_acc_utility::recompute_move_speed`).
- **PhD Flopper Mega: now a 1.35× SLIDE-speed boost** (`acc_mega_flopper_slide_mult` 1.35), replacing the old
  always-on +20% move. A new `_acc_mega_bottles::mega_flopper_slide_watch` (mirrors the Rocket Shield's
  `IsSliding` watcher, single-instance via a stop notify) sets `acc_mega_flopper_speed` only while sliding.
  Both slide boosts stack multiplicatively if you have the Rocket Shield + PhD Flopper Mega.
- **Mega Flopper explosive damage: +20% → +15%** (`ACC_MEGA_FLOPPER_EXPLOSIVE_MULT` 1.20→1.15 in `_acc_damage`).
- GSC-only. Docs: perk_abilities.md §9 + docs/12 synced.

### Changed — Trench ~25% less aggressive (user, 2026-06-18)

Eased the pit kill-box ~25% across all four drivers (defaults; all live-tunable dvars): entry burst
`acc_trench_surge_count` 6→5, in-pit AI-cap bonus `acc_trench_ai_bonus` 18→14, sustained eruption
interval `acc_trench_drip_sec` 4→5s, and in-pit zombie move-speed `acc_trench_aggro_rate` 1.15→1.11
(+15%→+11%). Still a clear kill-box, just less punishing. GSC-only.

### Changed — KILL-ONLY economy: no more points-per-shot, map-wide (user, 2026-06-18)

You now earn points ONLY on kills — the stock +10/shot (chip-damage points) is gone everywhere.
`_acc_points::init` registers a suppressor (`score_per_hit`) on the three stock per-hit score events
(`"damage"` / `"damage_ads"` / `"damage_light"`, fired at `_zm_spawner.gsc:1941/1957/2066/2082`), returning
**0** by default. Kills are unchanged (the existing `_acc_points` custom kill awards). Reversible: dvar
`acc_hit_points 1` restores the stock per-hit values (`zombie_score_damage_normal`, ×1.25 ADS,
`zombie_score_damage_light`). Note: this lowers early-round income by design (a harder, kill-driven
economy). GSC-only.

Playtest feedback: the Stalker "attacks me then teleports away, almost like a glitch," wasn't
aggressive, and the lockdown round was super easy. Root cause (found via a research→design→
adversarial-verify workflow): `glitch_blink_loop` was an **unconditional fixed-timer teleporter** — it
blinked 300u away every 1.0–1.665s **with no check for whether it was already on its target**, so it
reached a stationary player, swung once, then yanked itself away and re-charged forever. Standing still
was the safe option. The lockdown was worse because challenge zombies blinked to **random in-room
anchors** (a containment side-effect) — actively scattering *away* from you. Fixes, all in
`_acc_boss_glitch.gsc`, GSC-only / live-dvar-tunable:

- **Engagement gate (the core fix).** If a Stalker is within `acc_glitch_engage_dist` (160u) of its
  target it does **not** blink — it commits to the melee swing. Re-checked every tick, so a target that
  flees just gets chased (no stale pin). Kills the "attacks then teleports" bug and makes standing still
  dangerous (it stays and hits you).
- **Pounce on campers.** A target that barely moved since the last tick (`acc_glitch_still_thresh` 48u)
  and isn't downed gets **pounced**: the boss blinks to a point just short of them *along its own
  approach vector* (`pounce_point`, never behind the player's facing — that would clamp into a wall) so
  it lands in melee, then the gate holds it there. A per-target throttle (`claim_pounce`,
  `acc_glitch_pounce_cooldown` 1200ms) stops a whole pack from teleport-stacking one camper; downed
  (laststand) players are exempt so a revive can't be pounced mid-animation.
- **No free-shoot.** The 2×-damage-taken window now fires **only on a real repositioning flank**, never
  on a pounce/commit — so a camper can't step back and free-shoot a stationary, currently-vulnerable
  boss (a cheese the naive fix would have *created*).
- **Phases in closer.** `acc_glitch_reveal_dist` 240→140 so it reveals inside engage range and presses
  the attack instead of un-hiding far out and re-blinking before contact.
- **Lockdown aggression (the "super easy" fix).** Challenge zombies now blink **toward** the player
  (`ldc_aggressive_blink`, small offsets only, every candidate `ldc_in_room`-checked with the random
  anchor as the guaranteed-in-room fallback) instead of scattering — containment fully preserved
  (verified vs docs/43 §4.5).
- **Modest difficulty bump:** `acc_glitch_recovery_sec` 1.5→1.2, `acc_glitch_melee_dmg_mult` 0.5→0.6,
  lockdown `concurrent` 6→8, `stagger` 1.5→1.3. HP/speed/blink-cadence unchanged — the aggression fix is
  the main lever.

Crash-safety + containment invariants preserved: no `SetScale`, no second speed writer (the
`_acc_zombie_speed` keep-alive stays the sole owner), every teleport still `GetClosestPointOnNavMesh`-
clamped, every challenge blink `ldc_in_room`-gated. The adversarial pass caught and removed two
would-be regressions: `EnemyInMeleeRange()` is **not** a real builtin (would have built clean but
**fatal'd at load**), and the naive pounce would have opened a pin-and-free-shoot cheese. New dvars:
`acc_glitch_engage_dist` (160), `acc_glitch_still_thresh` (48), `acc_glitch_pounce_dist` (56),
`acc_glitch_pounce_cooldown` (1200), `acc_glitch_ldc_blink_dist` (90). **Needs a playtest to confirm the
feel** — every number is a live dvar (no rebuild to retune). `-GscOnly`, no `.map` edit.

### Fixed — Spiderman 6 web grenades now actually work (virtual pool + WEB GRENADES HUD counter) (user, 2026-06-18)

The "hold 6 web grenades" Mega never worked: the web grenade is carried in the lethal **clip**, which the
engine clamps to the grenade GDT carry cap (~2), and a usermap **can't raise that cap** (overriding a
base-game weapon — the doc/30 `maxAmmo→6` edit is **abandoned**; stock cost-override + stock-special-weapon
zone-line evidence both say it won't take). So the stock HUD showed ~2 and you only ever had ~2.

Replaced with a GSC **virtual pool** (`_acc_mega_bottles.gsc`): `player.acc_web_pool` (0..6 Mega / 0..2 base)
is the real reserve. `web_grenade_pool_watcher` spends it on each throw (stock `grenade_fire` notify, matched
to `level.w_widows_wine_grenade` — modeled on `last_stand_take_thrown_grenade`) and refills the clip, so you
throw **up to 6 in a row**; `web_grenade_manage_watcher` inits/caps the pool (handles buy / Max-Ammo / pickup /
revive) and drives the HUD. The round restock now tops the **pool** (2 base / 4 Mega), and `apply_mega_effects`
raises it to 6.

Display: a custom **WEB GRENADES N** counter — a `hudelem` (mirrors `sync_bottle_count_to_client`) at TOP_LEFT
under MEGA BOTTLES, showing the *real* pool count (the stock grenade-clip HUD stays clamped and isn't
authoritative). No clientfield used (the LUI clientuimodel pool is near-full — `hudelem` sidesteps it).

Docs updated to the **actual** ability: `docs/13_perks.md` (table + Spiderman section + impl status),
`docs/perk_abilities.md` §8, `docs/30` (GDT cap raise marked ABANDONED/superseded), and the Spiderman
perk-info card (`acc_hud.lua` [8]). GSC + LUI only (`-GscOnly`).

### Changed — Trench surge zombies: excluded from the round + flat 10-pt payout (user, 2026-06-18)

The pit horde is a THREAT, not a farm or a round-extender. Surge/drip zombies (`_acc_bus_trench::spawn_corp_surge`)
are now tagged in `tag_trench_zombie` (after `zombie_init_done`) with: (1) `ignore_enemy_count = true` — the
stock field (margwa.gsc:866 / mechz.gsc:953 precedent, read at `_zm_utility.gsc:105`) that drops them from
the round enemy count, so the surge can't keep adding to the round / stop it ending; and (2) `acc_trench_zombie`,
which `_acc_points::on_zombie_death` reads to award a **flat `acc_trench_zombie_points` (default 10)** on kill —
no damage-share split, no headshot/knife bonus, no Kinetic Battery accrual. Set the dvar to `0` for no payout.
GSC-only.

The map had three box spots (Market, Bus Station, Helipad). Added **three more** — Plaza (start room), Lab, and Vault — and changed the first-spawn rule so the box always *starts* in the Plaza (deterministic every run), then teddy-bears randomly among **all six**.

- **`.map` (`map_source/zm/zm_abandoned_cyber_city.map`):** three new `acc_box_<node>` chest pairs, each a `zbarrier_zmcore_MagicBox` (`script_noteworthy "acc_box_<node>_zbarrier"`) + a `script_struct` (`targetname "treasure_chest_use"`, `script_noteworthy "acc_box_<node>"`, `zombie_cost 950`) at the same origin — Plaza `(0, 350)`, Lab `(400, 3400)`, Vault `(1400, 2560)`, all z `13.75`. Placed clear of spawns, PaP, perk machines, `acc_boss_spawn` (19, 3648) and `acc_overload_point` (1524, 2925). Mirrors the existing Market/Corp/Roof pairs exactly. The six node names are mutually non-substring (required by stock's `IsSubStr` start match).
- **`roll_mystery_box_initial()` (`_acc_map_randomizer.gsc`):** returns `"plaza"` — the first box is **always** the Plaza (was `market|corp|roof`, briefly `plaza|lab`; pinned to Plaza per user 2026-06-18). Only the *start* node is constrained; the wider teddy-bear rotation pool is every chest in the map (stock `_zm_magicbox` default move logic), so all six spots are reachable after the first move. The Plaza always has a chest, avoiding the silent "no-match → all boxes hidden" failure (docs/research/BO3_Mystery_Box_Radiant_anatomy_multi_.txt §C).
- **`box_clip_nodes()`:** updated to the six real chest nodes (collision clips still unauthored, so it remains a no-op — the box model is walk-through on every spot, same as the existing three).
- Docs: `docs/07_replayability.md` (Mystery Box Spawn Weights + variance count). **Geometry change → full build WITH LED bake** (entities are point entities, but the `.map` changed → cod2map re-embeds the entity lump; ran the gate).

### Added — Brutus "Trench Warden": roams the trench, spawns at the bottom, trench-floor-only target + damage, guaranteed item drop (user, 2026-06-18)

Next step of repurposing Brutus as the Trench Warden — making him a true trench guardian, done
**safely** (Brutus has a long CTD/freeze history, so this respects every known landmine and edits
**no** vendored-pack code).

- **New supervisor thread `acc_boss_brutus::trench_warden_think()`** (threaded from
  `_acc_boss::spawn_brutus_miniboss`, gated by `acc_warden_trench` default 1). It drives the pack's
  OWN variables — `self.brutus_enemy` (target lock) and `self.v_zombie_custom_goal_pos` (the
  legacy-find-flesh goal consumed under the usermap's `scr_zm_use_code_enemy_selection=0`) — so it
  never fights a stock `SetGoalPos` and never touches the pack source (`scripts/_NSZ/nsz_brutus.gsc`).
- **Spawns at the trench bottom:** one-time navmesh-clamped `ForceTeleport` onto a `get_trench_risers()`
  point (z=-240) right after spawn (he spawns at the lab spot, then drops into the pit).
- **Targets only trench-floor players:** every 0.05s it builds the set of valid players where
  `acc_bus_trench::player_in_trench(p)` is true, locks the closest, and refreshes the pack's chase
  timer so it never re-acquires the global-closest (off-trench) player. Nobody on the floor → it clears
  the target and **patrols** between the trench risers (always a valid in-pit goal → never freezes,
  never paths out).
- **Safety:** NO `SetScale`, NO `PathMode` change, NO speed/anim-rate setter (the `_acc_zombie_speed`
  `is_boss`/`acc_boss_custom_speed` guard keeps the keep-alive off him — touching it = the known freeze);
  every goal/teleport is `GetClosestPointOnNavMesh`-clamped (off-mesh = frozen).
- **Damage-gated to the pit (no rim-sniping):** while he's the pit boss (`self.acc_warden_active`, set when
  he drops in), `_acc_damage::on_ai_damage` returns **0** for any player not `acc_bus_trench::player_in_trench`
  — you can't snipe/grenade him from the rim/stairs/slab, you must commit and drop in. Non-player/scripted
  damage unaffected; inert when the gate is off.
- **Guaranteed item drop:** killing the Warden now ALWAYS drops a boss item (user: "killing him gives an
  item") via `grant_challenge_reward` — not the 50%-design mini roll. `_acc_boss::watch_mini_boss_death`,
  gated by `acc_warden_item` (1; set 0 = back to the chance roll). The Glitch Stalker's roll is unchanged.
  Mega Bottle drop unchanged.
- **Rollback:** `set acc_warden_trench 0` → instant revert to the pack-native charge, mid-fight (re-read
  each tick). New dvars: `acc_warden_trench` (1), `acc_warden_item` (1), `acc_warden_patrol_dwell` (2.5),
  `acc_warden_patrol_reach` (96), `acc_warden_debug` (0). GSC-only (`-GscOnly`). NEEDS in-game verification
  (goal-write contention, riser nav for his hull, no freeze) — `set acc_warden_debug 1` shows tgt / inTrench / hasPath.

### Changed — DEFCON / lockdown gated to round 7+ (was every round from r1) (user, 2026-06-18)

DEFCON started on round 1 — too early (no ammo / not prepared for the 30-glitch trap). `_acc_lockdown::run_lockdown` lit one room every round with no floor; the challenge trap arms off that `acc_lockdown_room_lit` notify, so it fired early too. Added a round gate: no room lights (and therefore no trap can arm) before `acc_lockdown_first_round` (default **7**, dvar-tunable). Rounds 1–6 stay dark via `lockdown_clear()`. Single point of control — gating the lighting source covers both the red alarm and the challenge trap. GSC-only (`-GscOnly`). `#define ACC_LOCKDOWN_FIRST_ROUND 7`.

### Added — Trench boss-arena walls v1 (block sniping the reward-boss from above) (user, 2026-06-18)

Prep for a reward-boss in the pit (the "Trench Warden"): players must commit and go down, not snipe him
from the rim. `tools/gen_trench_walls.js` (one-shot, like gen_corp_trench) emits **rim parapet walls**
(`script_wall`, z[0,128]) along both long rims, GAPPED at the two stair mouths (so you can still descend)
and at the Rocket-Shield slab/bridge column (x[-109,147]); that column gets an **under-slab fill**
(z[0,42]) so it isn't a ground-level peek-hole under the floating slab. PLUS **stair pit-side walls**
(`script_wall`, z[−240,128]) on each stair's pit-facing edge (west stair east edge x=−665; east stair west
edge x=703) for the full run, so you can't shoot the pit while descending — only at the bottom (where the
stair opens onto the floor) do you get a line = you've committed. 8 brushes total, spliced into worldspawn
after the bridge brush; **full LED bake clean** (enclosed trench geometry survived the lightmapper — the
known brush.cpp:1860 risk). Tunable: `PARAPET_TOP`/`STAIR_WALL_TOP`/`PAR_TH` in the generator, re-run to retune.
PLUS a **Trench Warden damage-gate** (done 2026-06-18): once Brutus drops into the pit
(`trench_warden_think` sets `self.acc_warden_active`), `_acc_damage::on_ai_damage` returns **0** for any
player attacker who isn't `acc_bus_trench::player_in_trench` — so he can't be sniped/grenaded from the
rim, stairs, or slab regardless of any wall sightline gap; you must commit and go all the way down. Inert
when the warden behaviour is off (`acc_warden_trench 0` → flag never set). GSC-only. The walls are the
visual/atmosphere layer; this is the hard lock (hacky-is-good).

### Changed — Brutus = the "Trench Warden": first spawn gated on POWER (was round 4) (user, 2026-06-18)

User: "we want this to be the actual warden ... right now we have him spawn on round 4 but let's change
that and have him spawn when power is on. That's the first step." → **him = Brutus.** Brutus is being
repurposed as the recurring trench Warden (it already has massive HP, an every-5-round cadence, and a
boss-item / Mega-Bottle drop — it just needed to stop appearing before the area is powered).

- **First Brutus now appears when the Bus Station power is turned on**, not at a fixed round. New
  `_acc_boss::brutus_power_watch` waits the blackscreen → polls the global `power_on` flag → spawns ONE
  Brutus. **Respawn is KILL-ANCHORED, one at a time** (corrected 2026-06-18 — the first cut was a fixed
  power-on grid of 5 that could stack two): on death `watch_mini_boss_death` records
  `level.acc_brutus_kill_round` + clears `level.acc_brutus_active`; `round_hook_loop` respawns him
  `ACC_BRUTUS_RESPAWN_INTERVAL` (**3**) rounds after the kill ("kill him → back 3 rounds later"), and
  `acc_brutus_active` blocks a second while he's alive. `run_mini_boss` spawns exactly ONE (no more r20=2).
  No power on / never-killed → no respawn. Dvar `acc_brutus_respawn_interval` (3).
- `ACC_BRUTUS_FIRST_ROUND` (4) and `ACC_BRUTUS_INTERVAL` (5) are superseded (dead constants for ref).
- The dev `test_boss_loop` (round-2 test Brutus under `acc_dev`/`acc_test_boss`) is unchanged — set
  `acc_dev 0` for clean power-gated behavior when testing.
- **Pivot note:** an earlier standalone `_acc_boss_trench_warden.gsc` (a separate promoted-zombie roamer)
  was built then removed when the user clarified the Warden should BE Brutus — its trench-roam logic will
  be grafted onto Brutus in a later step ("make the Warden roam the trench").
- GSC-only (`-GscOnly`). NEXT STEPS (user-directed): tether Brutus to roam the Bus Station trench; verify
  the guaranteed item drop.

### Removed — dog/hellhound rounds disabled entirely (user, 2026-06-18)

Dog rounds were silently ACTIVE: stock `zm_usermap::main` DEFAULTs `level.dog_rounds_allowed` to 1 and
calls `zm_ai_dogs::enable_dog_rounds()` → `dog_round_tracker` swaps a wave to hellhounds every 4–7 rounds.
Our entry script never overrode it. Fix: set `level.dog_rounds_allowed = 0;` before `zm_usermap::main()`
in `zm_abandoned_cyber_city.gsc` (the tracker thread never starts). No round-pacing side effects (dogs use
a separate special-round counter); the 7 orphan `dog_location` structs stay (harmless, removing them = a
needless LED-gated rebuild). GSC-only (`-GscOnly`).

### Added — Spiderman (Mega Widow's Wine): one-hit melee on regular zombies (user, 2026-06-18)

Re-added the **melee one-hit-kill** the 2026-06-14 overhaul had removed: a melee from a player holding
Mega'd Widow's Wine instakills a **regular zombie** (gated `!is_boss_or_elite`, so bosses/elites are
unaffected). GSC short-circuit return in `_acc_damage::on_ai_damage` (`has_active_mega_perk("specialty_widowswine")`).
The **6 web-grenade max** and **4/round restock** were already live (`_acc_mega_bottles`); the web-grenade
OHK stays removed. UI: the Spiderman perk-info card now lists the one-knife. **NOT done — +30% knife swing
speed:** the engine exposes no per-player melee-swing-speed lever (same class as the slide-duration /
global jump-height limits we already hit); the only path is a custom/twinned melee weapon (involved +
uncertain), so it's deferred — the OHK delivers the "strong knife" goal instead.

### Fixed — Lockdown CHALLENGE: keep the glitch zombies inside the sealed room (no blink-out) (user, 2026-06-18)

The Glitch Stalker's signature blink + invisible-charge both teleport via
`GetClosestPointOnNavMesh` + `forceteleport`, and that nav clamp can land on the *corridor* side of a
sealed door (the navmesh polys still exist past the door even though `disconnectpaths` cut the
*pathing*) — stranding a challenge zombie outside, where the 30-kill quota could never complete
(docs/43 §4.5). Three layers now keep challenge-tagged zombies (`self.acc_ldc`) in-room, all no-op for
normal bosses: (1) **blink → a random IN-ROOM spawn anchor** instead of a free flank point (the
anchors are interior risers, guaranteed inside the seal); (2) the **invisible charge skips any step
whose nav point left the room** (`ldc_in_room` — within `acc_lockdown_challenge_bounds_margin`,
default 300u, of any room anchor — else it walks the last bit via the AI); (3) a **1 Hz yank-back
safety net** (`ldc_keep_in_room`) that force-teleports any zombie that still ends up outside back to a
random anchor. The challenge stocks each zombie's room anchor origins on the actor at spawn. `-GscOnly`,
no `.map` edit. docs/43 §4.5 marked resolved.

### Fixed — Lockdown CHALLENGE door seal: actually seals + can't crush/eject the player (move-door + crush-safety) (user, 2026-06-18)

A research→design→adversarial-verify workflow (the user asked "make sure the door can't kill the
player or knock him out the map") caught a **critical bug in the first door-seal pass and the safety
gap together**, both now fixed. Two findings, verified against stock `_zm_blockers.gsc` + the `.map`:

1. **The seal didn't actually seal (move-door bug).** The `acc_door_*` brushmodels carry
   `script_vector "0 0 130"` and no `script_string`, so stock `door_classify` auto-sets
   `script_string="move"` — a **bought door has physically slid +130z UP** out of the doorway (solid
   up at z[130,258]; the gap z[0,128] is wide open). The first pass did `e show(); e solid()`, which
   re-solidified the slab **at its raised position → players and zombies walked straight under it.**
2. **A door going `solid()` on a player can stick→eject→OOB-kill them.** The engine generates no crush
   damage from a static `solid()`, but a player caught inside the collision gets displaced, and if that
   lands them outside the zone `player_volume` the stock out-of-playable-area monitor **hard-kills
   them** (full hp, no MOD, Sam laugh — same mechanism as the sunken-floor trench bug).

**Fix — drive the stock crush-safe CLOSE instead of `show`/`solid`:** `_acc_lockdown_challenge` now
seals via `zm_blockers::door_activate(t, false)` (after clearing the door's `door_moving` once-guard):
`NotSolid()` so it can't crush during the descent → `MoveTo` the door back DOWN into the doorway →
`door_solid_thread()` re-`Solid()`s it **only once no player `IsTouching`** it → `disconnect_paths_
when_done()` cuts the nav. Teardown re-opens via `door_activate(t, true)`. The 1 Hz `reseal_monitor`
now re-asserts **`DisconnectPaths` only** (never `Solid()`), so it can't crush either. Belt-and-
suspenders: `commit_challenge` first `SetOrigin`s the party to a **navmesh-snapped, degenerate-guarded**
room centre (`relocate_party_safe` — guards the `room_center_origin` (0,0,0)-with-no-spawners case that
would itself OOB-kill, and never moves a laststand player). The OOB-monitor-veto backstop was
deliberately NOT used (it would clobber `_acc_bus_trench`'s single `player_out_of_playable_area_
monitor_callback`). New dvars: `acc_lockdown_door_close_time` (0.6s slam). All stock-proven logic;
`-GscOnly`, no `.map` edit, LED bake untouched.

### Added — Lockdown CHALLENGE room Phase B: the door seal (the hard lock-in), LED-safe (user, 2026-06-18)

The "doors slam, you're stuck for the round" lock-in — implemented **without any new geometry** (zero
LED-bake risk; the original plan's seal brushes were a confirmed `brush.cpp:1860` culprit). A geometry
probe of the *current* map (reworked vs the stale rooms.json) found each of the 4 challenge rooms is
bordered by exactly **2 stock buyable doors** (`acc_door_*`). `_acc_lockdown_challenge` re-closes those
on commit and re-opens on teardown — only the ones that were OPEN (`enter_*` flag set), so an un-bought
door stays a wall. Mapping: vault=`acc_door_vault`+`acc_door_lab_e`, roof=`acc_door_roof`+`acc_door_lab_w`,
alley=`acc_door_alley`+`acc_door_corp_e`, market=`acc_door_market`+`acc_door_corp_w`. Combined with
`disable_zone_spawning` (no risers inside) + the glitch in-room teleport clamps, this is a true seal
(no walk-in, no walk-out, no rise-inside, no blink-out). `acc_lockdown_lock_doors` (1) gates it.
**The actual close mechanism + crush-safety were corrected the same day — see the Fixed entry above.**
`tools/add_lockdown_seals.js` is obsolete. docs/43 §8 updated.

### Added — Mega Flopper (PhD Slider): +20% move speed + +20% explosive damage (user, 2026-06-18)

PhD Flopper's Mega (PhD Slider) now also grants, on top of the bigger slide/down explosion:
- **+20% move speed** — uniform, identical to The Flash Mega. Stacks multiplicatively with the Rocket
  Shield's +25% slide bonus (`recompute_move_speed` multiplies all flags → ×1.5 while sliding). New `acc_mega_flopper_speed` flag in
  `_acc_utility::recompute_move_speed`, set via `_acc_mega_bottles::apply_mega_flopper_speed()` from the
  `specialty_electriccherry` mega case, and re-applied each respawn in `flash_respawn_watcher` (the spawn
  path resets `SetMoveSpeedScale`).
- **+20% explosive damage** — grenades / projectiles / `MOD_EXPLOSIVE` deal +20% to zombies. A GSC
  damage-dealt scalar in `_acc_damage::on_ai_damage` (new `is_explosive_mod` + `ACC_MEGA_FLOPPER_EXPLOSIVE_MULT`
  1.20, gated on `has_active_mega_perk`). **No weapon twin needed** — twins are only for weapon-GDT stats
  (recoil, a gun's base damage); a damage scalar in the actor-damage callback is pure GSC.

Display UI updated: the PhD Flopper perk-info card (`acc_hud.lua` `[9]`) lists both buffs under Mega. Docs:
`docs/13_perks.md` (table + PhD Slider section) + `docs/perk_abilities.md` §9.

### Added/Changed — trench depth −240, in-pit spawns, pit slow, spawn surge, more Plaza/Lab risers, bench, 5s warning (user, 2026-06-18)

- **Trench floor −112 → −240** (deep pit). Safe at any depth via the OOB-kill veto below.
  gen_corp_trench.js: TRENCH_FLOOR −240 / SLAB_BOT −256 / N_STEPS 14 (treads to −224 + a clean 16u drop;
  NOT 15 — that = a zero-height bottom step); rooms.json `trenches.corp` synced; .map re-spliced (33
  brushes, bridge preserved). Full LED bake clean each time.
- **Zombies SPAWN IN THE PIT** (user: "they should start spawning down there", "as fearful as possible").
  10 surge-only risers `acc_trench_risers` on the pit floor (z=−240, central, `zone_name corp_zone`).
  `spawn_corp_surge` relocates the burst there via `spawn_zombie(spawner,_,struct)` — VERIFIED safe vs
  stock: the relocate (move_zombie_spawn_location) does no navmesh/zone validation, there is NO zombie
  out-of-playable-area kill at −240 (only a ~−500 below-world floor + a motion stuck-timer), and the
  struct's `zone_name` zones the spawned zombie directly. No info_volume edit needed.
- **Continuous pit eruption** while you stay down (`trench_ai_pressure` drip: `acc_trench_drip_count` 2 every
  `acc_trench_drip_sec` 4s, single-in-flight + AI-cap-bounded = a treadmill, not runaway; `acc_trench_drip_on` 1).
- **Pit slows you −35%** while exposed (`acc_trench_slow` factor in `_acc_utility::recompute_move_speed`,
  ×`acc_trench_slow_mult` 0.65; composes with Gas Tank / Rocket Shield / perks).
- **Entry burst + raised cap**: `spawn_corp_surge` bursts `acc_trench_surge_count` (6) on fresh entry
  (`acc_trench_surge_cd_sec` 8s cooldown); `trench_ai_pressure` raises `level.zombie_ai_limit` by
  `acc_trench_ai_bonus` (18) while ANY player is in the pit (poll-based, self-corrects on disconnect).
- **Danger warning now auto-offs after 5s** (`acc_trench_warn_sec` 5) and only re-arms on a fresh entry
  (step out + back in), instead of pulsing the whole time you're down.
- **More risers at Plaza + Lab** (were a slow trickle "from the sides"). start_zone 3 → 12 (+9), lab_zone
  4 → 14 (+10), interpolated strictly within each zone's known-good riser span (proven walkable floor;
  same approach as corp's +10). Auto-wired via the existing `target "<zone>_spawners"`.
- **Plaza Implant Bench −35z** (`acc_bench_off_z` −35) — it sat too high; trigger moves down with it.
- Removed the obsolete fall-through “catch-net” (deaths were the OOB kill, not a leak; it would
  false-trigger on a normal stander at −200).

### Changed — Perk/PaP glow: whole-machine coverage + more intense + recolor (user, 2026-06-18)

Three lighting requests on the `_acc_perk_lights` client-FX glow. (First researched whether base BO3
lights machines natively — it does, but via SERVER-side `PlayFXOnTag` (`_zm_perks.gsc:302`) which does
NOT render in usermaps, the same reason our 2026-06-17 attempt failed; our client-FX path is the only
one that renders, so we kept it. There is no emissive-model native light to use.)

- **Whole-machine coverage + intensity:** the source aura was a small sphere at `tag_origin` (machine
  base) → only the bottom lit. `tools/gen_perk_glow_fx.js` now `reshape()`s the `.efx` (tunable consts):
  glow sprites ×1.6 (`SIZE_MULT`) so one aura envelops the ~70u cabinet, emission lifted +25u
  (`LIFT_Z`) to centre on the body, `emitDensity` ×2 (`DENSITY`) for a fuller glow, dynamic-light
  `_color` ×1.5 (`LIGHT_BOOST`) for stronger coloured cast light, and a widened cull box. Single
  `PlayFXOnTag` unchanged (one leak-safe handle per machine).
- **Recolor:** Deadshot → **blacklight/UV** `[0.45,0,1.0]`, Widow's Wine → **white** `[1,1,1]`,
  PhD Flopper → **purple** `[0.62,0.08,1.0]`, Pack-a-Punch → **teal** `[0,0.85,0.75]`. Done with honest
  `.efx` filenames (added `fx_perk_glow_blacklight`/`_teal`, retired `_cyan`/`_gold`) updated in lockstep
  across `gen_perk_glow_fx.js` COLORS, `_acc_perk_lights.csc` (`#precache` + `level._effect`), and the
  `zone_source` `fx,acc/light/...` lines; index↔perk map in `_acc_perk_lights.gsc` unchanged.
- GSC/CSC/FX only — `-GscOnly`, no LED bake. (Blacklight is intentionally dim/violet; teal vs the now-
  removed cyan no longer collide. Coverage/intensity consts may want an in-game tuning pass.)

### Changed — Concurrent zombie cap 28 → 50 + corpses delete on death (user, 2026-06-18)

User wanted more zombies on screen at once. The engine HARD cap is **64** (netcode-imposed; verified vs
UGX/community) and is gated by BOTH `level.zombie_ai_limit` (alive) AND `level.zombie_actor_limit`
(alive + corpses, `get_current_actor_count` = live AI + `GetCorpseArray`). So corpses eat the cap.

- **Corpses now DELETE on death** (`_acc_corpse_cleanup.gsc`): default `acc_corpse_linger_sec` 5 → **0**.
  A `Ghost()`'d body stays invisible but still counts as an actor; we now `Delete()` it (mirroring stock
  giant-cleanup `zm_giant_cleanup_mgr.gsc:236-241`: NotSolid + hide now, brief wait so death drops/points
  fire, then Delete) so it never throttles the cap. Set the dvar > 0 to restore visible piling (now also
  slot-freeing). Bosses/mini-bosses still skipped.
- **Alive cap 28 → 50** (`_acc_main.gsc` `ACC_AI_LIMIT`), `ACC_ACTOR_LIMIT` 35 → **56** (small headroom
  over alive; corpses no longer consume it). Well under the 64 ceiling. (4-player netcode may strain
  near the top — drop toward ~40 if it rubber-bands.)
- GSC-only (`-GscOnly`). docs/11 + memory updated.

### Added — Lockdown CHALLENGE room, Phase A (GSC-only trap → 30-glitch wave → reward) (user, 2026-06-18)

Built from the deep plan (docs/43) in two LED-safe increments (`-GscOnly`, no `.map` touched). The
lit DEFCON room becomes a **trap**: walk in and a confined wave of 30 Glitch Stalkers spawns; kill all
30 and the room drops a free-for-all random boss-item. Isolated from the round via the glitch
`ignore_enemy_count` flag (it doesn't count the round nor eat the spawn budget); it stays committed
across rounds until cleared. New module `_acc_lockdown_challenge.gsc`.
- **Increment 1 (additive hooks, zero behaviour change):** `_acc_lockdown` gains `room_center_origin`,
  an `acc_lockdown_room_lit` notify, and a round-boundary guard (the rotation pauses while a challenge
  is active — fixes the unseal-mid-fight conflict); `_acc_decontamination` gains a public
  `enable_zone_spawning` (the re-enable decon never does — needed so the room's outside spawns come back
  on teardown); `_acc_boss_items` gains `grant_challenge_reward` (guaranteed free-for-all drop);
  `_acc_boss_glitch::maybe_spawn_for_round` is gated off while a challenge is active.
- **Increment 2 (the module):** trap (ambient catch + grace), commit + `disable_zone_spawning` (the
  fatal riser-leak fix — stops the horde rising inside the sealed room), confined producer reusing
  `spawn_glitch` (now returns the host; its `glitch_death_watch` skips the per-kill reward for
  `acc_ldc`-tagged actors → no 30-items bug), private kill counter, one-shot-guarded clear/fail
  teardown (+ `acc_ldc_done` endon so culled stragglers never re-count), basic fail detection, and the
  Phase-A SOFT confinement (script yank-back; the hard `disconnectpaths` seal is Phase B, LED-gated).
- **Increment 3 (HUD + feedback):** the real per-inside-player "GLITCH PURGE X / 30" objective HUD —
  a server-side `hud::createFontString` label + a `hud::createBar` that fills as you clear (reusing
  `acc_health_bars::acc_set_bar_smooth`), top-centre, created on commit + destroyed on teardown. NO
  `clientuimodel` field (that pool is full at 64 bits → load crash, per the verifier). Plus the robust
  `watch_fail` (fail only when every live party member is down AND an outside player is alive, so it
  never pre-empts the stock solo/team-wipe → `end_game`; re-arms on revive).
- Dvars: `acc_lockdown_challenge_on` (1) / `_total` (30) / `_concurrent` (6) / `_stagger` / `_grace` /
  `_confine` / `_debug` / `_force "<zone>"` (dev start). All three increments build clean (`-GscOnly`).
  Phase B (the physical `disconnectpaths` door-seal for the hard lock-in) is the LED-gated next step
  (docs/43 §8). docs/43.

### Fixed — ROOT CAUSE of the trench deaths: stock out-of-playable-area kill (user, 2026-06-18)

After a long hunt (the deaths were NOT fall damage, NOT zombies, NOT a leak — a research workflow +
in-game per-tick logging nailed it): the **corp_zone `player_volume` only spans z=[-16, 400]**, but the
trench rework dropped the floor to z=-112, so a player standing in the trench is **entirely below the
zone volume**. Stock ZM's per-player monitor (`_zm.gsc:2064-2100`) then flags them as out of the
playable area and **hard-kills** them on its ~3s poll (`self.lives=0; dodamage(self.health+1000);
bleedout_time=0`) — a no-laststand, HP-still-full, no-MOD, delayed kill (every reported symptom; and it
"worked before" only because the old shallow floor kept the player box inside the -16 volume). FIX
(GSC-only, verified vs `_zm.gsc:2066` — the monitor kills only if the callback is undefined OR returns
true): `_acc_bus_trench::init` registers `level.player_out_of_playable_area_monitor_callback =
&acc_trench_oob_allow`, which returns **false** for a player in the trench (vetoing the kill there) and
true everywhere else (rest of the map stays guarded). Decon, scripted kills, native fall damage, and a
hull leak were each independently ruled out. Proper follow-up (optional, geometry): extend the corp_zone
`player_volume` bottom plane (-16 → below -128) so the volume actually covers the trench. With the OOB
kill vetoed, the trench can now be ANY depth safely.

### Changed — Ultimate Tank (Mega Jugger-Nog) health 314 → 300 (user, 2026-06-18)

User asked for a round 300 number. Base Jugger-Nog stays **250 HP** (6th-hit down); only the Mega
(Ultimate Tank) drops from 314 → **300 HP**. Hit count is unchanged — at the ~45 baseline melee both
314 and 300 survive 6 hits and **down on the 7th** (6×45 = 270 < 300 < 315 = 7×45), so this is a
display/number cleanup, not a balance shift.

- **Code:** `_acc_mega_bottles.gsc` `n_player_health_boost` 64 → **50** (250 + 50 = 300; the field is
  the only one the stock `health_reboot` recompute adds, so it survives revives). Comments updated.
- **UI:** `acc_hud.lua` Jug perk card `mega` + `megaFull` → "300 HP - down on the 7th hit".
- **Docs:** `13_perks.md` (all 314 → 300, boost ref 64 → 50) + `perk_abilities.md` (314 → 300).
- GSC + LUI only (`-GscOnly`, no geometry → no LED bake). memory `spawn-intensity-moderate-tune`.

### Fixed — trench RAISED: floor was below the world bottom limit = instant void death (user report, 2026-06-18)

The earlier "died in the trench, not from a zombie" was NOT (just) fall damage — the trench floor at
**z = −288** sat **below the map's world bottom limit**, so entering the pit by ANY route (jump OR the
stairs, which descended to −288) dropped the player into the void = instant death every time (confirmed
by the in-game `[trench-dbg]` z readout + "even on the stairs I'm dying"). Fix: **raised the trench floor
−288 → −112** (above the world hull AND below the 256u fall-damage threshold, so the drop is survivable
and the danger is the amped zombies). Changed `source_data/rooms.json` trenches.corp (`floorZ −112`,
`slabBottom −128`, `stepCount 7`) + `tools/gen_corp_trench.js` (`TRENCH_FLOOR/SLAB_BOT/N_STEPS`),
regenerated the 21 trench brushes and spliced them into the `.map` (the bridge + end-trench marker
preserved), and ran the **FULL build** (cod2map64 BSP + navmesh + Radiant LED — baked clean, navmesh
regenerated so zombies path the new shape). `validate_rooms` passes for the trench. (The earlier
bg_fallDamage disable in `_acc_bus_trench` stays as belt-and-suspenders.)

### Changed — Zombie melee damage: baseline 60 → 45, Bus Station trench → 50 (user, 2026-06-18)

User asked to lower regular-zombie melee from the stock value back toward the old number, and make
the Bus Station trench a fixed harder hit.

- **Baseline regular-zombie melee 60 → 45 HP.** Stock `zombie_spawn_init` sets `self.meleeDamage = 60`
  (`_zm_spawner.gsc:358` — its trailing `// 45` is the pre-bump value, which is what "I thought it was
  45" referred to). We now re-assert **45** every speed sweep on non-boss zombies via
  `_acc_zombie_speed.gsc::apply_trench_melee` (the `off` branch), which is already boss-guarded
  (`apply_speed_for_round` returns early for bosses) so bosses keep their own melee.
- **Bus Station trench melee → absolute 50 HP** (was the old `×1.5` of base = 90). Trench-aggro
  zombies now hit for a flat 50 while their target is in the pit — still a step up from the 45 baseline,
  but no longer a big spike. Replaces dvar `acc_trench_aggro_melee_mult` with `acc_trench_melee_dmg`.
- New dvars (hardcoded defaults, live-tunable): `acc_zombie_melee_base` (45), `acc_trench_melee_dmg` (50).
  `#define ACC_ZOMBIE_MELEE_BASE_DEF` / `ACC_TRENCH_MELEE_DEF`. Glitch Stalker (`×0.5`) unchanged.
- GSC-only (`-GscOnly`, no geometry → no LED bake). docs/11, docs/34 updated; memory
  `spawn-intensity-moderate-tune`.

### Changed — per-round red room lockdown (Vault/Alley/Helipad/Market) now RENDERS, on the client-FX path (user, 2026-06-18)

`_acc_lockdown` already did "each round one room lights red, rotating" but played its FX
**server-side**, so the red light never actually showed (same wall the perk-glow hit — server
`PlayFX` doesn't render here). Reworked onto the proven **client-side glow pipeline**:
- The red alarm is now driven via `acc_perk_lights::set_glow(host, 1)` — a new public helper on
  `_acc_perk_lights` that sets the `accPerkGlow` clientfield (the `.csc` renders the red
  `acc/light/fx_perk_glow_red` clone). `_acc_lockdown` spawns invisible `script_model` hosts at
  each room's `<zone>_spawners` anchors (centroid + perimeter) and glows them; clears on round
  change (set 0 + delete). Dropped the old server `PlayFXOnTag` + pulse loop + flash/glow FX.
- **Rooms repointed to the four requested:** Vault (`vault_zone`), Alley (`alley_zone`), Helipad
  (`roof_zone` — the rooftop helipad), Market (`market_zone`). Dropped corp/lab/start. Per-run
  Fisher-Yates shuffle → per-round round-robin (a different room each round).
- **ON by default now** (`acc_lockdown_on` 1, was 0) since it's a wanted feature. Live knobs:
  `acc_lockdown_color` (1 red … 10 gold), `acc_lockdown_fx_z`, `acc_lockdown_emitters`,
  `acc_lockdown_force_zone <zone>` (pin one room), `acc_lockdown_debug 0` (silence the
  on-screen "round N → zone" text).
- **Stage 2 (doors lock, stuck in the room for the round) stays scaffolded:** `lock_doors`/
  `unlock_doors` toggle `acc_seal_<zone>` script_brushmodels — none authored yet, so it's a
  no-op until those Radiant seals exist (the future step you flagged). Pure GSC/CSC, reuses the
  already-packed red `.efx` → LED-safe `-GscOnly` build, no `.map` edit. docs/37 updated.

### Changed — Trench: stair rails removed + Rocket-Shield-only BRIDGE (user, 2026-06-18)

Removed both stair guard rails (the trench is now a real fall risk on foot). Added one central
**bridge** deck across the trench (`tools/add_trench_bridge.js`): `x[-45,83]` (128u) × `y[1723,2173]`
(full S→N span), floating over the open pit with its **top at z=+58 = 58u above the rim**. The ONLY way
up is the **Rocket Shield 2× jump** — apex ≈78u (velocity ×1.42) clears it; the stock ≈39u apex can't.
Anti-cheese (user: "only way on is the 2× jump"): the deck floats over the 288u pit with no supports or
footholds, sheer 16u sides, ends flush with the rim edges (so the approach is a pure vertical hop), and
it's disconnected from the navmesh so zombies can't path onto it. The open pit floor under it is
untouched, so the down-one-stair / across / up-the-other route still works for everyone else. Height is
baked geometry — retune the `BZ2` constant + rebuild if the in-game feel needs it. LED bake GATE PASSED (13.1 s).

### Fixed — trench killed you on the DROP (native fall damage), not from zombies (user report, 2026-06-18)

User jumped into the trench and died with no zombie involved. Cause: the trench floor was deepened to
**z=−288** (`gen_corp_trench.js`), which is **past the stock 256u `bg_fallDamageMinHeight`** — so native
engine fall damage applied on a jump-in, on top of the scripted 25 tax (the generator comment even notes
"native fall dmg stacks on the scripted tax"). The trench was designed assuming native fall damage = 0
(the 25 tax was meant to be the only, PhD-negatable cost). Fix: `_acc_bus_trench::init` now threads
`disable_native_fall_damage()` which (after `_globallogic` sets 256/512 at match init) raises
`bg_fallDamageMinHeight 1024` / `MaxHeight 2048` so no realistic map fall triggers native damage — the
trench's danger is the amped zombies, not the drop. Only the controlled 25 `MOD_FALLING` tax remains
(non-lethal, PhD-negated; set `ACC_TRENCH_FALL_DMG 0` to remove it entirely). Stale 112u header comment
corrected to 288u. GSC/linker-only build.

The new `_acc_power.gsc` (dual-switch power) called `trig trigger_off();` at line 79 — but **there is no
`trigger_off` function** in BO3 (in stock `_zm_power.gsc:683` `trigger_off` is an entity *field*, not a
function). It linked (the public linker packed it as a deferred external) but the game's script loader
rejected it: `Unresolved external "trigger_off"` → **Fatal Error on load**. Replaced it with the engine
builtin `trig TriggerEnable( false )` (52 stock uses) — disables the relay so it can't be re-flipped while
keeping the entity alive (the next line reads `trig.origin`). GSC/linker-only build. **Lesson:** a bare
undefined function call (no namespace) can slip past `lint_gsc_xref.js` + the linker and only fatal at game
load — the game load is the real check.

User-directed customization of zombie spawning (researched first via the spawn-system briefing —
all 4 axes tuned, hardcoded values, physical `.map` spawn additions). **"Moderate" intensity:** denser
and faster, kept under the ~32 netcode ceiling stock warns about. All GSC knobs are hardcoded constants.

- **Concurrent on-screen cap:** `level.zombie_ai_limit` 24 → **28**, `level.zombie_actor_limit` 31 → **35**
  (keeps the +7 corpse headroom). Set in `_acc_main::configure_spawn_density()` (new), called from
  `init()` after `zm::main()` so it overrides the stock defaults (`_zm.gsc:337-343`) before the spawn
  loop reads them. `#define ACC_AI_LIMIT` / `ACC_ACTOR_LIMIT`.
- **Wave fill speed:** inter-spawn delay ×**0.85** (0.1 s floor). Chains the stock
  `level.func_get_zombie_spawn_delay` hook (`_zm.gsc:307/4502`) with `acc_spawn_delay_override()` —
  own prev-slot, never clobbers. `#define ACC_SPAWN_DELAY_MULT`.
- **Early-round count:** r1 ×1.40 → **×1.50**, r2-4 ×1.35 → **×1.45** (`_acc_early_round_pacing.gsc`).
- **Elite cadence:** spacing 45 → **38 s** (`_acc_elites.gsc` `spawn_elites_over_round`).
- **Co-op scaling unchanged** (Moderate keeps +30% spawn / extra player).
- **Bus Station (`corp_zone`) = high-threat avoid-zone:** +10 `riser_location` structs added to
  `corp_zone_spawners` in the `.map` (**4 → 14 risers**, ~3.5× any other zone), 5 each on the two floor
  rows (y=1548 / y=2348) straddling the trench, x interpolated strictly inside the existing-inside
  footprint (x[-381,419]) so every origin is guaranteed inside the `info_volume` on the z=0 floor.
  Point entities only (no brushes) → LED-bake-neutral.
- **Build: full pipeline WITH LED bake — GATE PASSED** (cod2map64 BSP+navmesh regen → LED recompute,
  no `brush.cpp:1860` crash → linker → fresh 35.32 MB `.ff`). docs/06, docs/11 updated; memory
  `spawn-intensity-moderate-tune`.

### Added — Bus Station trench DANGER warning (player feedback that the pit is dangerous) (user, 2026-06-18)

While a player is in the trench (reusing `player_in_trench`, hooked onto the existing
`trench_fall_watcher` enter/leave transitions), show a **pulsing danger warning** so they feel the
threat: a red banner **"DANGER — EXPOSED IN THE TRENCH"** (upper-center, `fontscale 1.4`) + a subtle
pulsing **red screen tint**, both fading in/out together (~0.8 s cycle) and fading out on exit. Created
lazily per player, hidden (not destroyed) on exit, reused on re-entry. Pairs with the trench zombie
aggression. Gated by dvar `acc_trench_warn` (default 1). Banner placed at TOP y=110 to clear the boss
nameplate/bar and the dev zone sign (no HUD overlap). GSC/linker-only build. docs/34 updated.

### Added — Bus Station trench geometry re-added + DUAL-SWITCH power (user, 2026-06-18)

**Trench geometry re-added** (it was lost in the pre-stage3 revert): the cross-room E-W cut at
`y[1723,2173]`, recessed floor at z=-288, sealed E/W end walls, and the two diagonal 17-step staircases
(down the west/south side, up the east/north side) + guard rails — 41 brushes from
`tools/gen_corp_trench.js`, injected by the new `tools/add_corp_trench.js` (which removes the flat
1600×1600 corp floor slab first). The fall-tax script `_acc_bus_trench.gsc` already matched these exact
coords, so it re-armed with no script change. **LED bake GATE PASSED** (13.9 s) — proving the LED crash
was the cumulative tightening overhaul, not trench-style sunken geometry.

**Power is now DUAL-SWITCH** (`_acc_power.gsc`, new module): BOTH Bus Station switches must be flipped
to turn power on, one each side of the trench — Switch A relocated **south-east** (`790 1600 1`; it was
left floating inside the new trench) and Switch B added **north-west** (`-750 2300 1`). Order-independent;
flipping one shows `POWER RELAY 1/2` and you must cross the trench (jump in / diagonal stairs) to reach the
other. HACK (we don't own `_zm_power`): stock is OR-logic (any `use_elec_switch` powers on), so we
`Delete()` the stock switches and gate power behind our own two `acc_power_switch` trigger_use brushes →
`zm_power::turn_power_on_and_open_doors`. Lever handles still flip for feedback. Auto-power stays off
(`acc_auto_power=0`). Tools: `tools/add_power_switches.js`, `tools/list_walls.js`,
`tools/remove_walls_in_region.js`. LED bake GATE PASSED (13.7 s); GSC linked clean.

### Added — Bus Station trench AGGRESSION: zombies get scary when you're in the pit (user, 2026-06-18)

Design goal: make players afraid to cross the trench on foot. While any player is in the trench band
(reusing the existing `acc_bus_trench::player_in_trench` test), every zombie **chasing that player**
now gets three stacked, dvar-gated levers — wired INSIDE `_acc_zombie_speed.gsc` so the 1.5 s keepalive
re-asserts them (an external thread would be stomped):
- **Faster** — forced **sprint** gait + anim-rate ×`acc_trench_aggro_rate` (1.15).
- **Beeline** — installed a `level.should_zigzag` override (`trench_should_zigzag`) returning false for
  trench-chasers so they cut straight at you (verified contract `_zm_behavior.gsc:550`); every other
  zombie keeps stock zig-zag.
- **Harder hits** — cached + raised `self.meleeDamage` ×`acc_trench_aggro_melee_mult` (1.5 → 90), restored
  when the target leaves.
Co-op safe: only affects zombies ALREADY targeting the trench player (no re-targeting / aggro theft); the
whole-horde "designated target" funnel was deliberately NOT added (it steals teammate aggro). Master gate
`acc_trench_aggro` + per-lever dvars (`_aggro_rate` / `_aggro_melee` / `_aggro_melee_mult` / `_no_zigzag`),
all live. GSC/linker-only build. docs/34 updated.

**Still TODO (separate, full-geometry step):** the Rocket-Shield "jump over the trench" skip. Investigation
(workflow) confirmed NO jump clears the current 450u gap (shield max ~310u). Per user decision we'll keep
the 450u pit + add a **center mid-platform** (two ~200u hops: a shield hop clears 200u, a normal ~175u jump
falls in) + keep the stairs. That's a baked-brush change (rooms.json → gen_corp_trench.js → cod2map64+LED+
navmesh) — not done here.

### Changed — Gas Tank: +100% burst speed + the NITRO label is now a small activation hint (user, 2026-06-18)

- Nitro burst **+50% → +100%** move speed (`acc_gas_burst_mult` default 2.0 = double speed; live dvar).
- The on-screen **"NITRO" label rendered hugely oversized** in-game. Root cause: `hud::createFontString`
  stores its 2nd arg as `.fontscale`, and a **sub-1.0 fontscale (0.9) renders oversized** in this build —
  it was the only sub-1.0 HUD element. Set the gas label to **fontscale 1.0** (matches HEALTH, which
  renders correctly) and changed its text from "NITRO" to the activation hint **"Double-tap Sprint to
  activate"** so it reads as a small caption for the bar. Added a code comment warning to keep this
  label's fontscale >= 1.0. GSC/linker-only build. docs/12 + docs/34 updated.

Base-zombies "the machines light up when you restore power" look: dark before the Bus
Station switch, coloured glow after. New `_acc_perk_lights.gsc` (server) + `.csc` (client).

**Root cause of the 2026-06-17 failure, found via a multi-agent research/design/verify
workflow:** that attempt played the glow FX **server-side** (`PlayFX` in a `.gsc`, like
`_acc_lockdown`), and **server-side PlayFX does not render in this build** — which is also
why stock perk machines (server-side `perk_fx`) are dark here. The path that DOES render is
the **client VM**: stock power-ups glow via a `scriptmover` clientfield + client-side
`PlayFXOnTag` (`_zm_powerups.csc`), and power-ups render fine. So we copy that exactly.

- **Server** (`_acc_perk_lights.gsc`): on the `power_on` flag (polled like
  `_acc_atmosphere::apply_fog`, after the blackscreen — no flag-wait-from-`__init__` crash),
  enumerate `GetEntArray("zombie_vending","targetname")` and set a per-perk colour-index
  `accPerkGlow` clientfield on each `trigger.machine` (the renderable script_model). PaP's
  `pack_a_punch` ent is a *trigger*, not a model, so we spawn an invisible `script_model`
  host at its origin (the `_acc_lockdown` idiom) and glow that. Idempotent; value latches so
  late joiners glow too. Correct specialty keys (`specialty_doubletap2` / `specialty_staminup`).
- **Client** (`_acc_perk_lights.csc`): registers the mirror clientfield + a callback that
  `PlayFXOnTag`s the glow on the machine, leak-safe (stores the handle, `StopFX` before
  replacing, replays on the initial-snapshot for new clients) — verbatim from stock
  `_zm_powerups.csc`. The missing **client `#precache("client_fx")` half** is the fix the
  2026-06-17 attempt lacked.
- **Per-perk colours (validated in-game 2026-06-18):** first a green-everywhere proof build
  confirmed the client-FX path renders on all 9 machines + the PaP host (the earlier "Jugg/PaP
  dark" was just the faint red-blink + one-shot packapunch FX). Then `tools/gen_perk_glow_fx.js`
  generates 10 **recoloured clones of the proven green power-up aura** (the colour is pure
  `colorGraph` tint on white sprites → recolourable; `PlayFX` takes no runtime tint, so one
  `.efx` per colour): Jugg red, Speed Cola green, Double Tap yellow, Stamin-Up orange, Mule
  Kick amber, Quick Revive blue, Deadshot white, Widow's Wine purple, Electric Cherry/PhD cyan,
  Pack-a-Punch gold. Clones live in `<tools>\share\raw\fx\acc\light\` (regenerate via the tool,
  like the external asset packs — not in git). `set acc_perk_lights_debug 1` re-shows the live
  specialty→colour map on screen.
- **LED-SAFE / no Radiant risk:** pure `.gsc/.csc/.zone/.fx` — never touches `map_source/*.map`,
  ships with `build_map.ps1 -GscOnly` (no cod2map64/LED). Build clean, fresh `.ff`.
- `set acc_perk_lights_on 0` disables the feature. docs/29 §7c added; memory
  [[power-on-lights-perks-mechanism]] updated (client-side FX renders; server-side does not).

### Fixed — HUD overlap audit: re-spaced the top-left stack so nothing overlaps (user, 2026-06-18)

A 4-agent audit enumerated every on-screen HUD element (GSC hudelems + LUI) and computed each one's
screen rect. The top-left column was packed at a 20 px pitch — too tight for the 1.3-scale counters,
so descenders touched. Re-spaced for positive gaps everywhere: HEALTH label 16 / bar 32 / DATA SHARDS
50 / **MEGA BOTTLES 70→74** / **BOSS-ITEM 90→100** / **NITRO label 108→124** / **NITRO bar 122→142**
(files `_acc_mega_bottles.gsc`, `_acc_boss_items.gsc`). Also moved the dev-only zone-name sign
`_acc_dev.gsc` TOP 36→70 so it clears the top-center boss nameplate+bar during a boss fight.
Verified non-issues: the GSC `_acc_ui.gsc` info card is **retired** (no live callers — `_acc_perk_info`
drives only the LUI `accPerkCard`), so no GSC-vs-LUI card overlap; the off-screen `AccRoundRing`
(`ACC_BAR_TOPC=-300`) is the deferred radial ring, parked intentionally. GSC/linker-only build.

User wants the rooms cleared of random freestanding structures (keep walls, floor, and
all gameplay: boxes/perks/bench). The reverted pre-stage3 baseline still had the training
obstacles the generator stopped emitting on 6/16 (gen_zone_greybox.js:130-137: debris pile,
fountain, 2 S-curves, 3 market stalls, roof obstacle) — but at room-shrunk coords, so an
exact-coord match only caught 3. New `tools/remove_obstacles.js` removes them by a robust,
position-independent signal: **short `script_wall` box brushes in worldspawn (z-min≈0,
z-max<250)** — walls are full-height `WALL_H=256`, obstacles are ≤128, and functional structs
(PaP/doors) are separate `script_brushmodel` entities, so they're untouched. Removed **10**
(the 8 above + 2 thin 8u panels in spawn); kept all **66** full-height walls + the floor +
every entity (3 boxes, 3 perks, spawn, 7 zone volumes). LED bake GATE PASSED (13.9s, fresh
.led). Backup at `.map.pre-obstacle-removal-bak`. Map/geometry build (cod2map+LED+linker).

### Changed — boss-item buff tuning: Gas Tank +50%/60s, Rocket Shield +25% slide + 2× jump, Monkey Bomb model up (user, 2026-06-18)

Per-user tuning, all live-tunable dvars (no rebuild to re-tune):
- **Gas Tank** nitro burst **+20% → +50%** (`acc_gas_burst_mult` 1.50) and cooldown **30 s → 60 s**
  (`acc_gas_regen_sec` 60; the NITRO bar reads the same dvar so its refill stays in sync).
- **Rocket Shield** slide speed **+15% → +25%** (`acc_rocket_slide_mult` 1.25); jump changed from a
  ~1.5× additive impulse to a velocity **multiply** for **2× apex height** (`acc_rocket_jump_mult` 1.42 —
  height ∝ velocity², so ×1.42 ≈ double). Retired `acc_rocket_slide_thresh` (slide now `IsSliding()`)
  and `acc_rocket_jump_kick`.
- **Monkey Bomb** pickup `model_z` **−11 → +14** (it was sunk in the floor; user: +25).

GSC/linker-only build. docs/12 + docs/34 updated.

### Added — Gas Tank "NITRO" charge bar (player indication) (user, 2026-06-18)

User wanted an on-screen gas bar that drains on use and regens smoothly. Added a left-HUD bar
(reusing the verified `hud::createBar` widget from `_acc_health_bars.gsc`): full **cyan** = ready,
drains to empty over the 5 s burst, refills **orange** over the 30 s regen. `gas_bar_loop`
(threaded by `apply_gas_tank`, ended on `acc_gas_tank_removed`, destroyed by `remove_gas_tank`)
polls at 20 Hz and reads `gas_charge_frac`, which derives the 0..1 fill from a new
`acc_gas_burst_start` timestamp stamped in `gas_tank_burst` — so the motion glides. Burst/regen
durations are now `ACC_GAS_BURST_SEC` (5) / `ACC_GAS_REGEN_SEC` (30) defines shared by the burst
and the bar. `remove_gas_tank` now also clears `acc_gas_cooldown` so unequipping mid-lockout leaves
the item ready on re-equip. GSC/linker-only build. docs/12 updated.

### Fixed — three boss-item buffs that did nothing + the boss-item HUD overlap (user report, 2026-06-18)

A research workflow (5 agents, verified on disk — `recompute_move_speed` confirmed CORRECT, so each
buff failed at its OWN trigger, not a shared sink):
- **Phase Serum (cloak) now hides you from the Glitch Stalker's WHOLE behavior, not just blink/charge.**
  The `acc_cloak_glitch` flag was only consulted at the blink (`:353`) and charge (`:409`) targeting, so
  the Stalker's stock follow+melee AI still walked up and hit you. Now `spawn_glitch` sets
  `host.closest_player_override = &glitch_pick_uncloaked_target` — stock `get_closest_valid_player`
  consults that per-AI picker first (`_zm_utility.gsc:1472`) for both `favoriteenemy` (movement) and
  `enemy` (melee). The picker strips cloaked players then delegates to the stock factory picker via the
  `level.closest_player_override` pointer, so non-cloaked players are targeted exactly as stock.
- **Gas Tank double-tap now works.** It polled `IsSprinting()`, which latches continuously true under ZM
  auto-sprint and so never produced a second rising edge — `gas_tank_burst` was unreachable. Switched
  the detector to `SprintButtonPressed()` (the raw sprint-KEY edge, verified stock builtin `_prowler.gsc:45`).
- **Rocket Shield slide now works.** It gated on `GetStance()=="crouch"`, but `GetStance()` only returns
  stand/crouch/prone — never a slide value — so the gate never latched (no +15% speed, no lunge). Switched
  to `IsSliding()` (dedicated slide-state builtin, verified stock `_behavior_tracker.gsc`/`challenges_shared.gsc`).
- **Boss-item HUD line no longer overlaps Shards/Mega Bottles.** Moved `sync_items_hud` from `TOP_LEFT 16,68`
  (which collided with the Shards descender at y=50 and Mega Bottles at y=70) down to `16,90` — clean left
  column: HEALTH / SHARDS / MEGA BOTTLES / BOSS-ITEM.

All four are pure server-GSC edits in `_acc_boss_glitch.gsc` + `_acc_boss_items.gsc`; linked clean.
docs/12 updated. GSC/linker-only build.

### Changed — auto-power OFF; ONE power switch (Bus Station/corp), vault switch removed (user, 2026-06-18)

User: remove the auto-power trigger and drive power off the Bus Station power switch (powers
perks + PaP **and** starts the fog settle); also remove the vault switch.
- **Auto-power off.** `acc_auto_power` default `1 → 0` in `zm_abandoned_cyber_city.gsc`. Power
  now comes only from the player flipping the stock Bus Station (corp) switch — the stock handler
  (`_zm_power.gsc`) lights perks (`perk_unpause_all_perks`), powers PaP/traps/doors and sets the
  global `power_on` flag, which the fog loop already polls → the haze settles on switch flip. The
  auto-power block is kept behind `acc_auto_power 1` as a dev shortcut (no longer tied to `acc_dev`).
- **Vault switch removed.** Deleted the vault `power_switch` misc_prefab from the `.map` source
  (entity 114) — its body is gone now, not just its trigger. The map ships ONE switch (corp). Both
  the inner `use_elec_switch` trigger and its `elec_switch_fx` struct go together, so the
  `zombie_power_on/off` clientfield widths stay consistent server↔client at count 1 (a normal
  single-switch map). `_acc_map_randomizer`: `roll_power_switch_side` now hard-returns `corp`
  (the `acc_power_side` override is retired — vault no longer exists), and `apply_power_switch_side`
  early-returns for the single-switch map instead of warning about a missing dead side.
- **Build:** full pipeline (cod2map64 + LED + linker) — removing the prefab changes baked geometry.
  docs/34 (flags) updated; docs/29 already notes the fog keys off `power_on`.

### Fixed — mystery box "light but no chest" on the reverted pre-stage3 map (user report, 2026-06-18)

Two stacking bugs (found via a 4-probe workflow, verified vs repo + built fastfile manifest):
(1) `_acc_map_randomizer.gsc:roll_mystery_box_initial()` rolled the start box over **7** node
names but the reverted pre-stage3 map has only **3** chests (market/corp/roof). On ~4/7 runs
it set `level.start_chest_name` to a non-existent box, so stock `_zm_magicbox`
`init_starting_chest_location()` hid ALL boxes (no model, no use prompt) then dumped the
orphan `pandora_light` beam on a random box → "light beam, no chest, no prompt." Fix: clamp the
roll to `array("market","corp","roof")` (restore the 7-node list when the 6/16 box geometry
returns). (2) The 3 box entities overrode `zbarrierboardmodel*` to `p6_anim_zm_magic_box`,
which is NOT in the built `.ff` (only `p7_zm_der_magic_box` is, auto-pulled by the zmcore
MagicBox zbarrier) → a shown box drew nothing. Fix: point the 9 board-model KVPs at
`p7_zm_der_magic_box`/`_fake` (already loaded → zero new assets). Now exactly one of the 3 boxes
shows light + a visible Der-box chest + a working prompt; the others hide cleanly. LED bake
GATE PASSED (13.4s, fresh .led) — no geometry change. GSC + map-entity build (full pipeline).

### Fixed — Li'l Arnie (octobomb) + Monkey Bomb (cymbal_monkey) thrown grenades now actually function (user report, 2026-06-18)

User: the granted Li'l Arnie throws but the projectile "just sits there" (no attract/explode).
Root cause (research workflow, verified on disk): our `give_octobomb` / `give_monkey_bomb` grant
the weapon with a **raw** `self GiveWeapon(w)`, which bypasses `zm_weapons::weapon_give` — the only
stock path that dispatches the registered zombie-weapon callback (`player_give_octobomb` /
`player_give_cymbal_monkey`). That callback is what threads the per-player `grenade_fire` watcher
(`player_handle_*`) driving attract / spore / point-of-interest / detonate. The engine still handles
the THROW (so the projectile appears), but with no watcher it's inert. Fix: after `GiveWeapon` both
functions now dispatch the callback exactly the way stock does —
`if (isdefined(level.zombie_weapons_callbacks[w])) self thread [[ level.zombie_weapons_callbacks[w] ]]();`
(verbatim `_zm_weapons.gsc:2791-2793`). The watchers self-guard via notify/endon so the revive
re-grant is safe; no new `#using` and no clientfield work. The SoE/DLC FX (spore/glow/lightning)
are absent from this install so visuals won't render, but the gameplay is server-side and works.
Also fixed a stale code comment that wrongly told future agents Monkey Bomb needs a
`weapon,cymbal_monkey_zm` `.zone` line (it's CSV-row-only). docs/12 documents the hack.
GSC/linker-only build.

### Changed — TEMP: mini-boss boss-item drop chance 50% -> 100% for testing + made per-tier chance live-tunable (user, 2026-06-18)

User wants Brutus / Glitch Stalker to drop a boss item **every** kill for now (testing; will tune
later). Bumped `ACC_BOSS_ITEM_DROP_CHANCE_MINI` `0.50 -> 1.00` in `_acc_boss_items.gsc` and made
`on_boss_death` read both tiers from live dvars so the rate can be tuned with no rebuild:
`acc_boss_item_chance_mini` (default `1.0`, **design value 0.5** — restore when done) and
`acc_boss_item_chance_full` (default `1.0`). docs/12 tuning table + docs/34 flags reference updated.
GSC/linker-only build.

### Docs — boss-items doc + code comments corrected to match live v2 (2026-06-18)

Aligned [docs/12_boss_items.md](docs/12_boss_items.md) with the shipped v2 system: "At a Glance"
and the Mega-Bottles note now say **7 items / 1 active item** (were 6 items / 2 slots); the
**Cloak** implementation note now reflects the custom `acc_cloak_glitch` flag instead of the old
`increment_ignoreme` text (which contradicted both the code and the rejected whole-horde-cloak
bug). Fixed the `apply_arnie_octobomb` code comment in `_acc_boss_items.gsc` that still told future
agents to add a `weapon,octobomb_zm` `.zone` line — corrected to **CSV-row-only** (the zone line
re-packs from an absent GDT and errors `Unable to load weapon`; the def ships in `zm_levelcommon`).
Reverted the temporary `acc_drops_debug` default (`1 -> 0`) used to diagnose the "no items on
ground" report (root cause was transient; drops verified working in-game). GSC/linker-only build.

### Changed — fog now SETTLES AWAY DOWNWARD when POWER is turned on (user, 2026-06-18)

User: don't teleport the fog away in one frame — make it look like a fade by moving it a slight
amount once per second, straight **down** so it settles into the ground; and trigger it **when
power is turned on** (was: on the first zombie kill). Replaced the instant `disable_fog()` call
with a new `settle_fog_step()` in `_acc_atmosphere.gsc`, driven by the existing single-authority
`apply_fog` loop. **Trigger:** that loop now polls the stock `power_on` flag (exists-guarded, no
separate flag-wait thread → sidesteps the flag-not-yet-created crash); the old per-death callback
`on_zombie_death_clear_fog` + its `register_zombie_death_event_callback` registration (and the now-
unused `_zm_spawner` import) were removed. Once power is on it flips `level.acc_fog_cleared` and
each tick re-applies the haze with a **base height** (`SetVolFog` arg 4 = where fog is densest)
that drops one slight step **once per second**; vol-fog opacity halves every `acc_fog_halfway_height`
units above the base, so as the dense layer sinks below the floor the haze thins to nothing at eye
level. When the base has sunk `acc_fog_settle_depth` (7500u) below the floor — invisible — or
`acc_fog_settle_max_steps` (1200) nudges have run, it hard-disables for good (`disable_fog()`,
planes pushed out — opacity still can't be faded directly, so the *sink* is the fade). Five live
dvars (`acc_fog_clear_on_power` gate + `acc_fog_settle_interval` / `_step` / `_depth` / `_max_steps`);
defaults settle over ~38s, tunable live, no rebuild. Pacing is by accumulated-time counter
(framerate-safe). **Timing:** with the dev build's auto-power (~1.5s post-blackscreen) the haze is
brief; a switch-gated ship build (`acc_auto_power 0`) holds it until the player turns power on.
GSC/linker-only build. docs/29 + the in-code fog-history note updated.

### Fixed — boss-item polish: glitch-only cloak, carry-drop, carry HUD + real bench model (user, 2026-06-18)

- **Phase Serum cloak is now Glitch-Stalker-only** (was hiding you from the whole
  horde). Dropped `zm_utility::increment_ignoreme` (engine-wide ignore) for a custom
  `self.acc_cloak_glitch` flag that ONLY `acc_utility::get_closest_uncloaked_player`
  (the Stalker's targeting, ×2 in `_acc_boss_glitch`) honors; the charred horde uses
  the stock find-flesh path and still targets you.
- **Pickup no longer destroys a carried item.** Grabbing a new item while carrying a
  different un-enabled one now `spawn_pickup`s the old one back to the ground (at the
  new item's spot) instead of overwriting it. Enabled/implanted items are unaffected.
- **"CARRYING" HUD line fixed.** `sync_items_hud` had a leftover early-return on
  `acc_equipped_items.size == 0` that hid the whole element whenever nothing was
  enabled — so a carried-but-not-yet-enabled item never showed. Removed it; carry text
  is now bright `^3CARRYING <id - name> (enable at bench)` (was an near-invisible `^8`).
- **Plaza Implant Bench now uses a real model** — imported the stock Cyber City white
  metal workbench `p7_cai_work_table_metal_03_white` (on-disk t7_props GDT, packed via
  an `xmodel,` `.zone` line; errorlog-clean) instead of the carpenter-icon placeholder.
  Licensing-clean (stock Treyarch asset).

GSC-only / linker build.

### Changed — colour grade OFF by default; map ships with BASE GAME COLOURS (user, 2026-06-18)

User: every tint we tried made it look worse — **remove any lighting tint, go with base
game colours.** Flipped `ACC_VISION_ON` `1 -> 0` in `_acc_atmosphere.gsc`. With the grade
off, `apply_vision` applies the stock neutral `"default"` vision and adds no tint of its
own, so the map renders in base game colours. Nothing deleted — the custom grades
(`zm_abandoned_cyber_city` / `acc_grade_magenta` / `acc_grade_orange` / `acc_grade_dark`)
stay zoned and dormant; re-enable live with `set acc_vision_on 1` (+ `set acc_vision_set
<name>` to pick one). Supersedes the cyan/magenta/neutral grade churn below. Fog
(`acc_fog_on`, the cool haze that clears on first kill) is a SEPARATE system and is
untouched — disable it too with `set acc_fog_on 0` if base-game air is wanted. Linker-only
(GSC) build. docs/29 §7b updated.

### Changed — default colour grade = NEUTRAL look with a very small cyan tint (user, 2026-06-18)

User: away from magenta — make the map look **normal with a very, very small cyan
tint**. The earlier "light cyan" restore (below) still washed the scene to a light
blue-grey, because its luminance curve topped out dim + blue-grey
(`vkRGB4 0.69/0.72/0.80`, `vkRM 0.8`) and the fullbright scene sits at that top stop.
Replaced the default `vision/zm_abandoned_cyber_city.vision` with a **near-identity
neutral curve** (`vkRGB1..4 = 0.25/0.5/0.75/1.0` grey ramp, `vkRM 1.0`, tint filter
off `vkTS 0` / `vkTC 1/1/1`) so brightness + contrast read normal, then knocked **red
down ~4% at every stop** (`R = 0.96·G` e.g. top stop `0.96/1.00/1.00`). Cyan = white
minus red, so a uniform small red cut = a faint pale-cyan cool with no other shift.
Tune strength by the red column (lower red = more cyan; `1.00/1.00/1.00` = dead
neutral). The vibrant magenta / orange / dark looks remain as live-swappable
`acc_grade_*` files (set `acc_vision_set acc_grade_magenta`). Linker-only build
(`.vision` is BSP-independent). docs/29 §7b updated.

### Reverted then superseded — default reverted to the prior light cyan/cool grade (user, 2026-06-18)

User: move the map tint back from magenta to the **light cyan**. Restored
`vision/zm_abandoned_cyber_city.vision` (the `ACC_VISION_SET` default) to its prior
cool grade (`vkTS 0`, `vkTC 0.91/0.97/1.11`, blue-grey curve to `0.69/0.72/0.80`,
`vkRM 0.8`). Superseded same day by the neutral+small-cyan grade above (the light-grey
wash was still too strong). The vibrant magenta look stays live-swappable as
`acc_grade_magenta`.

### Changed — boss items now GRANT the real Octobomb + Cymbal Monkey; cloak split to its own item (user, 2026-06-18)

Corrects the prior "give-the-real-tactical is infeasible" conclusion — it was wrong.
Both `octobomb_zm` and `cymbal_monkey_zm` weapon defs ship in **zm_levelcommon**
(assetlist 6175/6225), which every usermap loads at runtime, so they're grantable.

- **Lesson:** include such a weapon with a **CSV row only** in
  `gamedata/weapons/zm/zm_levelcommon_weapons.csv` (→ `is_weapon_included` true,
  `GetWeapon` resolves at runtime). Adding `weapon,<name>_zm` to the `.zone` is what
  caused the earlier `Unable to load weapon` errors — it forces a re-pack from a GDT
  source not on disk. Removed those zone lines; build is errorlog-clean.
- **Li'l Arnie (item 2)** now grants the **Octobomb** tactical (`apply_arnie_octobomb`);
  **Monkey Bomb (item 6)** now grants the **Cymbal Monkey** (`apply_monkey_bomb`,
  un-shelved). Both via `GiveWeapon` + `set_player_tactical_grenade` + regrant-on-spawn.
- **Cloak** moved off Li'l Arnie to a NEW **item 7 "Phase Serum"** (perk-bottle vial,
  `apply_arnie_cloak`). Pool is now **7 items**.

docs/12 (7-item table + corrected caveat) + memory updated. GSC-only build.

### Changed — boss-item v2: bench-gated single active item + new per-item buffs (user, 2026-06-17)

Major redesign of the boss-item system (`_acc_boss_items.gsc` + `_acc_utility` + `_acc_boss_glitch`).

- **Acquisition = carry → bench.** Picking an item off the ground now only CARRIES
  it (no buff); a new **Plaza Implant Bench** (runtime `script_model` + `trigger_radius_use`
  at the `player_respawn_point` struct, no Radiant edit) ENABLES it onto your character.
  **Single active item**; first enable FREE, each swap costs **2500 points**
  (`zm_score::can_player_purchase`/`minus_to_player_score`). New state:
  `acc_carried_item`/`acc_active_item`/`acc_bench_first_done`; `ACC_ITEM_SLOTS_PER_PLAYER=1`;
  the old 2-slot auto-equip + ground-swap removed. HUD shows `(carry)` vs `IMPLANT`.
- **New per-item buffs:** 1 Gas Tank = double-tap-sprint nitro burst (+20% 5s, 30s
  lockout, uncancellable; `IsSprinting` polling); 2 Li'l Arnie = cloak via
  `zm_utility::increment/decrement_ignoreme` + a cloak-aware `get_closest_uncloaked_player`
  swapped into the Glitch Stalker targeting (×2); 3 Teddy Bear = +10% points (unchanged);
  4 Repair Kit = +10 HP/s (was 8); 5 Rocket Shield = +15% slide speed + slide-start
  forward lunge + ~1.5× jump impulse (polled `GetStance`/velocity/`IsOnGround`);
  6 Monkey Bomb = **placeholder** +1 shard/20s.
- **Per-item floor-lift** (`model_z`) so each model sits right (Gas −6, Arnie −1,
  Teddy/Repair 19, Rocket 24, Monkey −11), overriding the global `acc_drop_model_z`.
- New tuning dvars (docs/34): `acc_bench_off_x`, `acc_gas_dtap_ms`,
  `acc_rocket_slide_thresh`/`_slide_kick`/`_jump_kick`.

**Could NOT be done as asked (surfaced to user):** (1) Giving special-grenade weapons is
BLOCKED on this install — tested + confirmed for the Cymbal Monkey (`Unable to load weapon
'cymbal_monkey_zm'`, DLC3) AND the Octobomb/Li'l Arnie (`'octobomb_zm'`, base-game SoE). The
weapon DEFS aren't in the loadable set (only `_zm_weap_*` scripts+models ship; gdtdb limited),
so it's not a DLC-only issue. → Li'l Arnie stays the cloak; Monkey Bomb stays a shard-income
placeholder; either would need the weapon asset imported (external-pack style). (2) Slide
"1.5× duration" has no per-player engine lever → shipped as a distance lunge. (3) Jump uses
a per-player velocity impulse, not the global `jump_height` dvar. Build errorlog clean.
docs/12 rewritten (v2 spec + legacy section). GSC-only build.

### Changed — atmosphere retuned DARK + VIBRANT, pivoted to MAGENTA palette; 4 live-swappable grades (user, 2026-06-17)

User: the map reads dull/washed light-grey ("white"), wants **dark but vibrant**.
Root cause (6-probe investigation): the global colour grade
`vision/zm_abandoned_cyber_city.vision` was doing it — `vkTS 0` (saturation OFF)
plus a 5-stop luminance→colour curve where every stop is a near-equal R≈G≈B
blue-grey at `vkRM 0.8`. That's a hard DESATURATE + BRIGHTEN. And because the map
renders effectively fullbright (LED bake is permanently dead — `brush.cpp:1860`
crash on enclosed geometry; zero placed lights; `global_fill_color "0 0 0"`), every
surface sits at the TOP of that curve → the brightest/greyest stop
(`vkRGB4 0.69/0.72/0.80`) → washed light blue-grey. The grade is BOTH the cause and
the fix: it's the only colour lever that's linker-only + live-swappable
(`VisionSetNaked`, `set acc_vision_set`).

First pass was a dark TEAL grade (`vkTS 0.70`, cyan cast). User tested it: **still
super dull** + wanted away from teal toward orange/magenta. Lesson: on a flat
fullbright scene the grade tints a uniform field, so the hue must be BOLD and the
saturation/cast pushed hard, or it reads muddy. **Pivoted to a vibrant MAGENTA
palette and cranked everything:** `vkTS 0.90` (was 0.70), `vkRM 1.0` (full curve
authority, was 0.8/0.9), strong magenta `vkTC 1.28/0.60/1.20 @ 0.45`, and a curve
with green CRUSHED at every stop + big R/B spread (top stop `0.72/0.26/0.64`) so
surfaces read hot neon magenta. Now ships **four** live-swappable grades (one
build): default `zm_abandoned_cyber_city` = vibrant magenta;
`acc_grade_magenta` = hotter/brighter pink (`vkTS 0.98`); `acc_grade_orange` =
amber-neon (warm `vkTT 7400`, R↑G·B↓ curve); `acc_grade_dark` = deeper magenta
(negative-`vkTC`-alpha global-darken, per stock `zod_ritual_dim`). All zoned
(`rawfile,vision/...`). Pick live: `set acc_vision_set acc_grade_orange` /
`acc_grade_magenta` / `acc_grade_dark` / (default) `zm_abandoned_cyber_city`, no
rebuilds. **Known ceiling:** the grade can only saturate a flat field — if magenta
still reads dull, the real neon punch needs SCENE contrast (emissive prop xmodels +
placed colour FX), the next lever (docs/29 §7b). LED stays dead; material reskin
stays blocked (§14). GSC/linker-only build. Memory: [[hacky-solutions-encouraged]].

### Changed — boss-item redesign: 6 model-fit items, each with a unique buff + floor-lift (user, 2026-06-17)

Model-first redesign of the 6 boss items (name chosen to fit the model) + a real
player buff per item + a fix for models sinking into the floor.

- **6 items** (`_acc_boss_items.gsc` `build_item_pool`): 1 Gas Tank (`nitrous_tank`,
  +20% move speed), 2 Li'l Arnie (`octobomb`, every 10 kills → next shot 3×), 3 Teddy
  Bear (`teddybear`, +10% Points/kill), 4 Repair Kit (`p7_zm_power_up_carpenter`, +8
  HP/sec regen), 5 Rocket Shield (`rocket_shield`, +50 max HP), 6 Monkey Bomb
  (`monkey_bomb`, +1 Data Shard/20s). Items 1-3 REUSE the already-wired effects
  (neural_boots / kinetic_battery / payroll_ledger); items 4-6 are NEW self-contained
  buffs — `apply_overcharge` (regen thread), `apply_bulwark` (idempotent max-HP
  recompute + spawn-reapply, mirrors the move-speed reapply), `apply_salvage` (timed
  shard thread). Only safe levers (self.health add capped at maxhealth, maxhealth
  delta, grant_player) — no fragile cross-module rewiring. `_acc_points` battery-charge
  message made generic ("Charged shot ready").
- **Model link-verification:** `zombie_zapper_handle` + `p6_power_lever` FAILED to
  link ("xmodel missing" — not in ZM-common fastfiles), caught by the build errorlog;
  swapped to `p7_fxanim_zm_zod_octobomb_mod` + `p7_zm_power_up_carpenter`. All 6 now
  errorlog-clean.
- **Floor-sink fix:** drops spawned at the corpse origin sank ~70% into the floor
  (high model pivot). Models now spawn lifted by dvar **`acc_drop_model_z`** (default
  24, live-tunable); the trigger stays at +40. Swap re-drop uses the stored unlifted
  `acc_ground_origin` so repeated swaps don't creep upward. Applied to the shard drop too.

CHANGELOG + docs/12 (table + legacy note) + docs/34 (dvar). GSC-only build.

### Changed — boss items each get a unique world model (user, 2026-06-17)

All 6 boss items shared the one `p7_zm_zod_nitrous_tank` model; now each has a
distinct stock xmodel so they read differently on the ground (not thematically
matched — just unique). `item()` gained a `model` field; `spawn_pickup` reads
`item_struct.model` (fallback nitrous tank); all 6 `#precache`'d. Mapping: 1 Boots
= nitrous_tank, 2 Gauntlets = zombie_pickup_perk_bottle, 3 Visor =
p7_zm_power_up_insta_kill, 4 Battery = p7_zm_power_up_max_ammo, 5 Shroud =
p7_zm_power_up_double_points, 6 Ledger = p7_zm_power_up_nuke.

Each is link-verified safe on this install (build errorlog clean): packed via the
`.zone` (nitrous tank) or already runtime-loaded by stock (perk-bottle pickup via
our `#using`; powerup icons `_zm_powerups` precaches in every ZM map). Established
the reliable test — a model is safe if our build errorlog has no entry for it;
`xmodel.csv` only lists OUR-packed models, NOT base-fastfile ones. docs/12 updated.
GSC-only build.

### Fixed — fog now actually disappears on the first kill (root cause: opacity ≠ disable) (user, 2026-06-17)

**Hard-won fact:** you CANNOT remove BO3 volumetric fog by zeroing its opacity.
Stock `_art.gsc:231` hits the same wall verbatim — `setExpFog( 100000000,
100000001, 0, 0, 0, 0 ); // couldn't find discreet fog disabling other than to
never set it in the first place`. The reliable disable is to push the fog START
PLANE out to ~100,000,000 units so fog begins far beyond the world and never
reaches the camera. This is why every prior fog-clear attempt (power-on lift, then
the opacity-fade-on-first-kill shipped earlier today) "never reliably faded" — the
death callback fired fine, but ramping opacity to 0 left the haze fully visible.

Fix in `_acc_atmosphere.gsc`: ripped out the fade machinery (`acc_fog_fade`,
`acc_fog_target_fade`, the ease, `acc_fog_clear_time`, the opacity-multiply) and
replaced it with an INSTANT hard disable. `apply_fog` (still the single `SetVolFog`
authority) applies the full haze each tick until `level.acc_fog_cleared` flips, then
calls `disable_fog()` = `SetVolFog( 100000000, 100000001, 0,0,0,0,0,0 )` (planes
out). The per-death callback `on_zombie_death_clear_fog`
(`zm_spawner::register_zombie_death_event_callback`) just flips the flag on the first
kill — no fade, removed within 0.1s. The `initial_blackscreen_passed` wait stays
(fog cannot be set before players are in — that is how it gets set at all). Gated by
`acc_fog_clear_on_kill` (default 1). GSC-only build. Doc: docs/29.

### Fixed — swapped boss item now actually drops to the ground (user, 2026-06-17)

The swap-on-pickup path equipped the new item but the old one never reappeared.
Cause: `spawn_pickup()` for the dropped item was called AFTER `cleanup_pickup()`,
which does `self delete()` on the trigger — deleting `self` ends the running
thread, so the re-drop line never executed. Fix: re-drop the old item (and
capture its struct/origin) BEFORE the notify + cleanup. `_acc_boss_items.gsc`
`watch_pickup`. GSC-only build.

### Reverted — teal round counter ABANDONED ENTIRELY; stock red counter kept (user, 2026-06-17)

**The whole teal-round-counter feature was dropped at the user's request after every approach
failed in-game.** Attempts: (1) same-path `RoundStatus.lua` rawfile, (2) `require` from `acc_hud`,
(3) wrapping the HUD-root `T7Hud_zm_factory`, (4) a teal overlay + opaque cover. None worked
reliably and it can't be debugged blind (no runtime LUI introspection; stock HUD menu
names/load-timing unverifiable offline). **Fully reverted** — removed `CoD.AccRoundNum` (acc_hud.lua),
the `world`-scope `accRound` clientfield + `round_num_watch` (`_acc_lui.gsc`), the `accRound_cb`
mirror (`_acc_lui.csc`), and the `acc_round_status.lua` / `RoundStatus.lua` widget files + zone
line. The stock red round counter is back, untouched. (The round-progress/zombies-remaining BAR,
`CoD.AccRoundRing`, is a SEPARATE feature and stays.) The deep-dive notes below are retained for
reference only — they describe what was tried, not what shipped.

### Changed — perk bar: purchase-order stacking + shifted right (user, 2026-06-17)

The bottom-left Mega perk-icon bar (`CoD.AccPerkBar`, `acc_hud.lua`) now **stacks in acquisition
order**: the first perk you buy keeps the leftmost slot and each new perk appears to its RIGHT.
Previously it packed by perk-TYPE bit order, so a newly-bought low-bit perk (e.g. Jugger-Nog,
bit 0) jumped to the leftmost slot ahead of perks owned longer. `Render` now maintains a persistent
`order` list (keep still-owned entries in place, append newly-owned ones; bit order only breaks
ties when two are gained within one 0.25s poll). Also moved the whole bar **+10px right**
(`START_X` 96 → 106) so it no longer clips the round number at bottom-left. LUI only; linker build.

<details><summary>(retained reference: the failed HUD-root override investigation)</summary>

**Earlier (superseded) write-up.** The stock
zombies round number is built by the HUD ROOT menu `LUI.createMenu.T7Hud_zm_factory`, which calls
`LUI.createMenu.RoundStatus(InstanceRef)` (chalk marks + `ZOMBIE_ROUND` + round number, driven by
the `GameScore`/`roundsPlayed` global model; zm_building `t7hud_zm_custom.lua:145`).

What did NOT work: dropping a rawfile at the stock `RoundStatus.lua` path (a packed rawfile doesn't
execute on its own, and lost the load/cache race) → stayed red. **What works (HUD-root wrapper):**
1. ship our teal round-counter at a UNIQUE path `ui/uieditor/widgets/hud/acc_round_status.lua` so a
   `require` ALWAYS executes it (no stock-`RoundStatus` cache collision); it stashes its factory in
   `CoD.AccTealRoundStatus`.
2. in `acc_hud.lua` (loaded early), `require` it, then WRAP `LUI.createMenu.T7Hud_zm_factory`: keep
   the original and, on each call, force `LUI.createMenu.RoundStatus = CoD.AccTealRoundStatus` before
   delegating — so the round widget the stock HUD builds is ours, regardless of load order. All
   `pcall`/nil-guarded so it can never take down the rest of the overlay.

Our `acc_round_status.lua` is the stock round-counter structure UNCHANGED except `DefaultColor`
dark-red `(0.21,0,0)` → cyber **teal** `(0.25,0.88,0.82)` — native chalk/round-up animation
preserved. All assets stock (`bo1_hud_chalk_1..5`, the fonts, `ZOMBIE_ROUND`); no new assets.

**Removed** the earlier overlay approach: `CoD.AccRoundNum` + opaque mask in `acc_hud.lua` and its
whole data path (`world`-scope `accRound` clientfield + `round_num_watch` in `_acc_lui.gsc`, the
`accRound_cb` mirror in `_acc_lui.csc`). Net: no extra clientfield, no mask, no position-guessing.
LUI + GSC/CSC; linker build. (Reusable technique logged in docs/22: override a stock LUI HUD widget
by wrapping the HUD-root factory.)

</details>

### Changed — boss items: swap-on-pickup when full + numeric item IDs in all displays (user, 2026-06-17)

- **Swap when full:** grabbing a boss item while both slots are full no longer
  refuses — it now **drops your oldest equipped item (slot 0)** back to the ground
  as a fresh `spawn_pickup` (re-grabbable, own 60s lifetime) and equips the new one.
  The drop spot is captured before `cleanup_pickup()` deletes the grabbed entity.
  FIFO rotation; a per-slot replace prompt remains the Phase-4 LUI upgrade.
- **Numeric item IDs:** `item()` now takes a stable `num` (1 Neural Boots · 2
  Overclocked Gauntlets · 3 Targeting Visor · 4 Kinetic Battery · 5 Ghost Shroud ·
  6 Payroll Ledger). New shared `display_for(item) -> "<num> - <name>"` drives the
  world pickup prompt, the pickup/swap message, and the equipped-items HUD, so all
  three read e.g. `3 - Targeting Visor`. docs/12 + docs/14 §1c updated.

GSC-only / linker build.

### Fixed — pickups now despawn on grab + added equipped-item HUD indicator (user, 2026-06-17)

Two follow-ups to the hold-Use pickup change:

- **Despawn bug:** a picked-up Data Shard / Boss-item drop stayed on the ground
  forever. Root cause was a GSC `endon` trap introduced with the interact change —
  `watch_pickup` had `self endon( "acc_*_claimed" )`, so its own
  `self notify( "acc_*_claimed" )` (meant only to stop the sibling lifetime timer)
  aborted the thread one line BEFORE `cleanup_pickup()` ran, so the model + trigger
  were never deleted (the grant still happened, which masked it). Fix: that `endon`
  now lives ONLY on `watch_lifetime`; `watch_pickup` ends via its explicit `return`
  after cleanup. Both `_acc_data_shards.gsc` and `_acc_boss_items.gsc`.
- **Equipped-item indicator:** there was no persistent on-screen sign you were
  holding a Boss Cyberware item (only a one-shot `iprintln` at pickup). New
  `_acc_boss_items::sync_items_hud` — a server-side hudelem mirroring the Data
  Shards counter, stacked under it (`TOP_LEFT` 16,68), showing `ITEMS <name> | <name>`
  for the ≤2 equipped slots, updated on equip/unequip, hidden when empty
  (`#using hud_util_shared` added). Documented in docs/14 §1c.

GSC-only / linker build.

### Changed — pickups are now HOLD-USE interact + drop-lifecycle logging (user, 2026-06-17)

The two custom ground pickups (Data Shard, Boss Cyberware item) no longer
auto-grab on proximity — you now **hold ⓕ Use** to take them, and the whole
drop/pickup lifecycle is logged behind a dvar for debugging.

- **Interact pickup** (`_acc_data_shards.gsc`, `_acc_boss_items.gsc`): each drop
  now spawns a stock `trigger_radius_use` alongside the model (canonical navcard
  recipe, `_zm_utility.gsc:5439`). Wiring: `TriggerIgnoreTeam` (any player) +
  `UseTriggerRequireLookAt` (no grabbing through walls; trigger origin raised
  `+40z`) + `SetCursorHint("HINT_NOICON")` + `SetHintString("Hold ^3[{+activate}]^7
  to grab …")`. The watchers now run **on the trigger** (`self.acc_model` reaches
  the model); the use-loop is `waittill("trigger", player)` (fires only on
  use-press — no 0.1s proximity poll, no `wait(1.0)` anti-spam needed). New
  `cleanup_pickup()` (one per file) deletes trigger + model together; lifetime
  despawn (30s shards / 60s items) routes through it. Hint token is the
  stock-proven `[{+activate}]` (raw `&&1` has zero stock backing).
- **Logging** (`_acc_utility::drops_debug`): new shared helper gated by the
  `acc_drops_debug` dvar (default 0). Uses `IPrintLnBold` — the only channel that
  reaches `console_mp.log` (`[ SCRIPTER] [drops] …`, needs `+set logfile 1`).
  Log points: DROP-ROLL / DROP-MISS / SPAWN / PICKUP-TRY / GRANT / EQUIP / DUPE /
  FULL / DESPAWN. Documented in `docs/34_flags_reference.md` §E.
- **Drop attribution (no behavior change, documented):** Brutus mini-boss →
  boss item @50% + Mega Bottle each + one NSZ-pack stock powerup (last Brutus
  only); Glitch Stalker mini-boss → boss item @50% + Mega Bottle each (no
  powerup); Subroutine Core full boss → boss item @100% + flat Data Shards to
  every player; elite kills → a Data-Shard pickup entity (+ a stock powerup every
  5th elite under the Subroutine T3 capstone).

GSC-only / linker build (no `.map`/`.zone`/`.csc`/BSP). Known doc/code drift left
as-is per scope: `docs/12` still names the mini-boss "Juggernaut Host @ r10/20"
(code = Brutus @ r4-then-every-5, Glitch unlisted), and the elite-shard
diminishing branch is dead (`source_tag "pickup"` never matches `"elite_kill"`).

### Added — QA: zombie wallhack markers (hardcoded ON, user, 2026-06-17)

A small red through-walls waypoint now floats over **every live zombie** so a stuck /
broken-pathing one is always findable. New always-on system in `_acc_health_bars.gsc`
(`zombie_wallhack_loop` / `zombie_wallhack_one` / `create_zombie_marker`), threaded from
`init()`. **Not behind a flag** — hardcoded on per request (the dev door-marker system it
mirrors is gated on `acc_dev`; this is independent). Recipe = the proven `_acc_dev`
door-marker HudElem path: `NewClientHudElem(player)` + `SetShader("white", 10, 10)` +
`SetWaypoint(true)` + `SetTargetEnt(zombie)` (`"white"` is an engine built-in material →
no asset risk). A discovery loop (0.5 s) tags each new zombie once and hands it to a
LEVEL-scoped per-zombie manager (level thread, not on the zombie, so it survives corpse
removal and still destroys the player-owned elems); each manager keeps one marker per
connected player (refreshes for co-op late joins) and destroys them all on death.
**TODO(ship): remove before a public build.** GSC only; linker build.

- **Smaller markers (user, 2026-06-17):** the dot shrank from 10 px to `ACC_WH_MARKER_SIZE` = 2 px
  (~90% smaller footprint) to cut on-screen clutter with a full round of zombies.

### Changed — round bar redesigned (cyber HUD) + % readout removed (user, 2026-06-17)

The zombies-remaining bar (`CoD.AccRoundRing`, `acc_hud.lua`) lost its `pct%` readout and
got a layered cyberpunk look, all from the render-safe `CoD.TextWithBg.Bg` rectangle
primitive (no custom material/shader): an outer cyan **halo**, the navy track, the
teal→magenta drain fill, **segment notches** (battery/tech-gauge divisions), a bright
**"drain front" sliver** that rides the fill's moving edge (also tweened), a **top accent
line**, four **corner targeting brackets**, and a small right-aligned **"HOSTILES"
caption** above the bar (replaces the number). The drain-front sliver hides once the round
is cleared (`frac <= 0.02`). LUI only; linker build.

### Changed — Glitch Stalker: teal eyes + clean teleport-in + 3 per round (user, 2026-06-17)

Three Glitch Stalker tweaks (`_acc_boss_glitch.gsc`, GSC/CSC-only / linker build):

- **3 per round** (was 2): `ACC_GLITCH_COUNT_DEF` / `acc_glitch_count` default → `3`.
- **No more visible standstill after a blink (exaggerated fix).** Just hiding the actor wasn't
  enough — when the AI's post-teleport re-path took longer than the reveal cap it would un-hide a
  still-frozen zombie. Now the boss not only `Ghost()`s the instant it blinks in, it is physically
  DRIVEN toward the nearest player while hidden (navmesh-clamped micro-teleports at
  `acc_glitch_charge_speed`, default 900 u/s) so it actually CLOSES the gap during the invisible
  window. Once within `acc_glitch_reveal_dist` (240, just outside melee) it hands control back to the zombie AI and
  `Show()`s only once the AI has resumed moving (origin drift) — so it reappears already charging,
  never standing. The whole re-path pause is spent hidden. Hard `acc_glitch_phasein_max` (2.5s)
  failsafe; `Ghost`/`Show` are render-only (stays hittable); a fresh blink cancels an in-flight
  phase-in (`endon "acc_glitch_phasein"`). Belt-and-suspenders `Show()` on death so a corpse can
  never be left invisible. (`glitch_blink_fx` → `glitch_phase_in`, `acc_glitch_fx` gate.)
- **Teal eyes** (`acc_glitch_teal_eyes`, default on), **no FX asset** (by request). The
  zombie eye glow is client-side, and only orange (default) + green ship prebuilt — no teal
  FX exists, and authoring one needs the FX editor. Instead we recolour the boss's eyeball
  MATERIAL via the engine's intended hook: a new 1-bit **actor**-scope clientfield `accEyeTint`
  (registered in the `_acc_lui` pair, separate pool from the near-full clientuimodel fields)
  set on the boss at spawn; the `_acc_lui.csc` callback drives `mapshaderconstant("scriptVector2",
  luminance, colour)` — the exact stock eye-colour path (`_zm.csc zombie_eyes_clientfield_cb`) —
  with `acc_glitch_eye_color` / `acc_glitch_eye_lum`. Both are **live-tunable** (1s re-apply
  loop): the exact value→colour mapping is the engine's eye shader, so the colour is dialed
  in-game by eye, no rebuild. This is also the lever for the "all eyes glow white" FYI — the
  map's dark `VisionSetNaked` grade (highlight ≈ `0.69 0.72 0.80`, desaturated cool grey)
  washes the bright orange eye glow toward white; the same grade applies to the recolour, so
  drop `acc_glitch_eye_lum` if teal blows out.

Docs: [11_enemies.md](docs/11_enemies.md), [34_flags_reference.md](docs/34_flags_reference.md).

### Changed — dropped-item world models: Data Shard + Boss item now visible (user, 2026-06-17)

The two custom proximity-pickups were spawning a `script_model` skinned to the
invisible `tag_origin` placeholder — they worked but you couldn't see them on the
ground. Both now use verified stock xmodels (no APE/GDT import; no FX, by request):

- **Data Shard** (`_acc_data_shards.gsc:56`) → `p7_fxanim_zm_stal_ray_gun_ball_mod`
  (glowing energy ball, reads as a data shard). Stock asset, used as a `script_model`
  pickup in `_zm_weap_raygun_mark3.gsc`.
- **Boss Cyberware item** (`_acc_boss_items.gsc:204`) → `p7_zm_zod_nitrous_tank`
  (tech canister). Per-slot models (boots/gauntlets/visor/battery/shroud) are a later
  art pass; one shared model for now.

Pipeline (the reusable recipe for any custom drop): change the `setmodel` string →
add a `#precache( "model", … )` directive (after `#using`/`#define`, before
`#namespace`) → add an `xmodel,<name>` line to `zone_source/*.zone` (a `setmodel` is a
script ref, so the linker won't pull it in otherwise — same reason the Glitch Stalker
models are listed). Stock models need no GDT import; materials ride in transitively.
GSC-only / linker build (no geometry). Stock-powerup drops (emergency/recursion) were
already visible and are untouched.

### Changed — HUD bars SLIDE instead of jumping: health + round-progress (user, 2026-06-17)

Both meters now animate to their new value rather than snapping to it.

- **Round-progress / zombies-remaining bar** (`CoD.AccRoundRing`, `acc_hud.lua`): the teal
  fill now SLIDES via the proven LUI tween path (`completeAnimation()` →
  `beginAnimation("keyframe", 250, …, CoD.TweenType.Linear)` — the same call
  `CoD.AccDmgNum` uses for its alpha fade), which interpolates the `setLeftRight` offsets
  **and** the teal→magenta `setRGB` from the current state to the target. The FIRST update
  stays instant so the `(true,false,..)` anchor baseline is set before any tween (mixing
  anchor flags mid-tween renders wrong). 250 ms ≈ the server push cadence
  (`round_ring_watch` waits 0.25 s) so consecutive steps chain into a continuous drain.
- **Player + boss health bars** (`_acc_health_bars.gsc`): new `acc_set_bar_smooth(bar_bg,
  frac, dur)` helper drives the stock `createBar` fill (`.bar`) with `scaleOverTime` — the
  SAME engine call stock `updateBarScale` uses for its `rateOfChange` path
  (`hud_util_shared.gsc`) — so the fill GLIDES to the new width instead of the instant
  `setShader` snap `hud::updateBar` does. First touch snaps (establishes size); every later
  change animates over 0.25 s. Re-issues only when the target width changes, so the 0.1 s
  poll calling it each tick is cheap and never restarts the glide on a no-op.

LUI + GSC; linker-only build (no geometry).

### Changed — crosshair damage number: teal on headshots + 20% smaller (user, 2026-06-17)

The center-screen damage number (`CoD.AccDmgNum`, `acc_hud.lua`) now turns **teal
`(0.20, 0.95, 0.85)`** when the batch landed a headshot (amber `(1.0, 0.88, 0.25)` for
normal hits), and the text is **20% smaller** (scale `1.9` → `1.52`).

Plumbing: `_acc_damage::on_ai_damage` already knows `b_headshot`, so it now passes it
through `feed_dmg_number(attacker, final_damage, b_headshot)` → `level.acc_dmg_num_feed`
→ `_acc_dev::acc_center_dmg_add(amount, is_headshot)`. The headshot flag is **sticky-OR'd
across the ~0.1s accumulation batch** (per-shot color is impossible — many shots batch
into one number), then read + cleared each push in `acc_center_dmg_push_loop`.

Encoding change (the `accDmgNum` clientuimodel is a fixed **18-bit** field, max 262143, and
the clientuimodel pool is full so it **cannot** be widened): was `dmg*2 + parity`, now
`min(dmg,65535)*4 + headshot_bit + parity`. Capping dmg at 65535 makes the max value
`65535*4 + 2 + 1 = 262143` fit the 18 bits **exactly** (was 99999; the lower cap only
clamps absurd single-tick burst sums). Lua decodes `dmg = floor(v/4)`,
`headshot = floor(v/2) % 2`, `parity = v % 2`. LUI + GSC (`_acc_damage`, `_acc_dev`,
`_acc_lui` comment); linker build (sync + relink, no geometry).

### Fixed/Changed — HUD polish: PaP icon stretch, centered powerup list, lower row (user, 2026-06-17)

In-game test feedback on the new HUD icons (`ui/uieditor/menus/hud/acc_hud.lua`):
- **PaP tier icon was stretched across the whole screen.** `CoD.AccPapTierIcon` used
  `setLeftRight(true, true, …)` which is STRETCH/fill mode (the form the parent containers use to
  fill). Switched to the far-edge fixed-box idiom `setLeftRight(false, true, -(RIGHT+SIZE), -RIGHT)` +
  `setTopBottom(false, true, …)` (the proven `AccPerkCard` right-anchor pattern) so it's a fixed 40px
  box in the bottom-right corner. RIGHT/BOTTOM still want an in-game nudge to center on the gadget.
- **Powerup row is now a DYNAMIC centered list, not fixed slots.** `CoD.AccPowerupBar` Render now shows
  ONLY active icons, packed in bit order and centered as a group (with K active, the j-th sits
  `(j-(K-1)/2)*PITCH` from center) — a lone icon is dead-center, the 3rd of 5 lands in the middle, like
  the stock powerup HUD. Lowered the row (`BOTTOM` 92 → 58).
- **Stock powerup active-icons — race fixed (was intermittent).** `suppress_stock_powerup_hud` nulled
  the 3 timed powerups' `client_field_name` ONCE at `initial_blackscreen_passed`, betting it beats the
  stock monitor's one-shot capture at `start_zombie_round_logic` — it RACED and lost some sessions
  (base icons showed e.g. the Double Points "2X"). Now it LOOP-nulls from the moment the powerups
  register, every frame, until the capture has fired (then one sweep after), so the monitor always
  reads `undefined`. Same fix shape as the perk-bar suppression (continuous re-assert, not one-shot).
- **PaP tier icon nudged** toward the gadget (`RIGHT` 80 → 40, `BOTTOM` 100 → 50).

LUI + one GSC function; linker build (sync + relink).

### Added — cyber round-progress BAR HUD (top-right, drains as the round dies) (2026-06-17)

A teal cyber health-bar-style meter at the top-right that is FULL at round start and drains
right-to-left to empty as the round's zombies are killed, lerping teal→magenta as it empties. Built
clean (`-GscOnly`, fresh `.ff` 2026-06-17). Backed by `docs/42_round_progress_ring_research.md`
(6-domain deep-research + adversarial-verify). A circular radial ring was the first attempt but the
stock `hud_objective_circle_meter` material draws in full screen space (it needs the center/radius
shader components the shipped recipe sets); deferred to a later upgrade in favor of this simple,
robust bar built only from proven primitives.

- **LUI** (`acc_hud.lua`): new `CoD.AccRoundRing` widget (TOUCHPOINT 5), proven primitives only —
  `CoD.TextWithBg.Bg` solid rectangles (renders, per the perk card) for the cyan outline + navy track
  + teal fill, and the drain is a dynamic `Fill.Bg:setLeftRight(true, false, 0, frac*W)` (the exact
  `AccPerkBar` UIImage resize idiom). `acc_ring_color` lerps teal `(0.25,0.85,0.80)` → magenta
  `(0.90,0.20,0.55)`. Top-right; geometry knobs `ACC_BAR_W/H/RIGHT/TOP/BORDER`.
- **Bridge**: new `accRoundRing` clientuimodel int (7 bits), appended LAST in lockstep in `_acc_lui.gsc`
  + `_acc_lui.csc`. Values: 0..100 = fill %, 127 = hide. `set_round_ring()` setter.
- **GSC** (`_acc_lui.gsc`): `round_ring_director()` (one level thread, started once + guarded)
  captures the per-round denominator ONCE on round change (after a 0.5s settle) and decides
  visibility; per-player `round_ring_watch()` pushes `remaining = get_current_zombie_count() +
  level.zombie_total` over that denominator each 0.25s (push-on-change). Added
  `#using scripts\shared\ai\zombie_utility;`. **Math (2 research refutations applied):** the numerator
  sum is correct (hits 0 at round end), but the denominator is captured once — NOT a high-water-mark
  latch (refuted: `zombie_total` only decrements + would mis-track overload waves). Boss rounds force
  `zombie_total=0` → bar hides (denom `<1`); overload/hack `+= N` is clamped to a full bar.

### Changed — PaP tier HUD = roman-numeral icon + Nuke/Max-Ammo pickup icons (user, 2026-06-16)

Two HUD changes, both on the proven LUI plain-image rail (`setImage(RegisterImage(...))`, no custom
material — sidesteps the docs/29 §14 shader-compile blocker), using Ronan's Cyberpunk Shaders art.

- **PaP tier icon (replaces the bottom-right "PaP TIER x/3" text).** The held weapon's current PaP
  tier now shows as one small teal hex roman-numeral shield (I/II/III) centered over the gadget HUD
  circle (bottom-right). New LUI element `CoD.AccPapTierIcon` in `acc_hud.lua`, driven by the existing
  `accPapTier` clientuimodel; `_acc_pap_levels::pap_hud_loop` now pushes the held gun's tier on change
  instead of drawing a `createFontString` (same `get_tier` value `_acc_perk_info` pushes for the card,
  so the two writers never disagree). Images `i_acc_pap_tier{1,2,3}`. Position is eyeballed — `SIZE`/
  `RIGHT`/`BOTTOM` in the element need an in-game tune for a pixel-perfect center.
- **Instant power-up pickup flashes (Nuke / Max Ammo / Carpenter / Random Perk).** These INSTANT
  power-ups have no timed window, so they now flash their Ronan icon in the power-up row for ~3s on
  pickup. `accPowerupMask` widened 3→7 bits (bit 3 = Nuke, 4 = Max Ammo, 5 = Carpenter, 6 = Random
  Perk/`free_perk`; `.gsc` + `.csc` in lockstep); `_acc_lui` stamps a 3s window per player and
  `powerup_state_watch` ORs the bit in while live. Nuke / Max Ammo use dedicated grab signals
  (`zmb_max_ammo_level` team-wide; `nuke_triggered` on the grabber → all players). Carpenter / Random
  Perk use a generic `powerup_dropped`→`powerup_grabbed` watcher (`powerup_drop_flash_watch`) keyed on
  `powerup.powerup_name`, so they fire if/when those drops are enabled on the map (not assumed live).
  `CoD.AccPowerupBar` extended to 7 centered slots. Images
  `i_acc_powerup_{nuke,maxammo,carpenter,randomperk}`.

Assets added to `source_data/acc_perk_shaders.gdt` + zone `image,` lines; deploy via
`tools/deploy_perk_shaders.ps1` (gdtdb) before linking. Linker-only build (no geometry/BSP).

### Changed — Brutus mini-boss HP 10x → 5x (user, 2026-06-16)

`ACC_BOSS_MINI_HP` 500000 → **250000** (5× the 50k baseline) in `_acc_boss.gsc`. The r10/r20 Brutus
now spawns at 250k HP × co-op scaling (`special_hp_mult`). Dev test spawn (1500 HP, behind
`acc_test_boss`/`acc_dev`) unchanged. Comments synced in `_acc_boss.gsc` + `_acc_boss_brutus.gsc`.
Linker-only; `.ff` 34.50 MB.

### Changed — Headshot bonus nerf: 2.0→0.5 trash, 2.0→1.0 boss (user, 2026-06-16)

`ACC_HEADSHOT_MULT` 2.0 → **0.5** (regular/elite), `ACC_BOSS_HEADSHOT_MULT` 2.0 → **1.0** (boss/mini)
in `_acc_damage.gsc`. These are summed bonus values; effective head:body ratio = `gun locHead ×
bonus`. Most box guns are `locHead 5.0` → headshots drop from 10× to **2.5× (trash) / 5× (boss)** body;
**Paladin** (`locHead 1.0`) → **0.5× / 1.0×** (still one-shots via raw damage, doesn't lean on heads).
With Deadshot the bonus sum climbs again (e.g. American Sniper trash ≈ 5.0×(0.5+1.6)=×10.5 on a
5.0-loc gun) — so Deadshot is what makes headshots premium now. Shotguns stay headshot-excluded.
docs/perk_abilities.md synced. Linker-only; `.ff` 34.50 MB.

### Fixed — Stale in-game perk cards (Deadshot/Armory) after the perk rework (user, 2026-06-16)

The functionality changed but the LUI perk cards (`ui/uieditor/menus/hud/acc_hud.lua` `AccPerkCards`)
still showed the OLD text — that's why the descriptions "looked wrong." Updated to match:
- **Deadshot:** base now "+1.4 HS, ADS-snap" (dropped the stale "−25% recoil"); American Sniper
  "**+1.6** HS, **−50%** recoil" (was +1.8 / −40%).
- **Armory (Mule Kick Mega):** "**+35% reserve ammo each round**" (was "+25% ammo capacity").
Card-index map (`_acc_perk_info::perk_card_index`) verified correct (deadshot→7, mule→6). Functionality
audited and intact: `axis_recoil` returns `recoil50` only for Mega Deadshot; `armory_round_refill_watcher`
fires on `acc_round_start` (emitted by `_acc_main:260`) and `armory_refill` adds 35% of cap (clamped).
Linker-only; LUI packed clean; `.ff` 34.51 MB. Other 7 cards spot-checked accurate.

### Changed — Pack-a-Punch 3-tier revamp; transform deferred to tier 2 (user, 2026-06-16, NEEDS BOOT TEST)

Full PaP rework from the 5-tier money ladder to **3 tiers**, and the actual PaP **transform**
(the upgraded "_up" form — explosive M1911, akimbo PDW, gold-camo'd upgrade) is now **deferred to
tier 2** instead of landing on the first pack. Tier 1 is a pure "camo + damage" pack.
- **Tiers / costs:** T1 **5000** (+50% dmg, gold camo on the **base** gun, NO transform) → T2
  **7500** (+100% dmg, **transforms** to the `_up` form / matching packed twin + camo) → T3
  **10000** (+150% dmg, MAX). `pap_tier_mult` = 1.5 / 2.0 / 2.5 (additive layer into
  `_acc_damage`'s `bonus_sum`). `ACC_PAP_MAX_TIER` 5→3; `ACC_PAP_TIER_COST_4/5` removed.
- **"% is the only damage lever"** (user choice): `acc_weapon_balance_mult` already normalizes
  base / `_up` / twin per gun by substring, so the `_up` form's higher raw damage doesn't
  double-count — the +50/100/150% ladder is the whole PaP damage progression. No `_acc_damage`
  logic change; comment updated.
- **Routing (`_acc_pap_levels.gsc`):** `acc_pap_validate` now routes by `get_tier` (tier 0 →
  `acc_do_first_pack` = camo-only; tier ≥1 → `acc_do_tier_up`). New `acc_do_transform` does the
  T1→T2 base→`_up` asset swap (the old first-pack swap body, moved). `acc_do_first_pack` just
  applies camo via `replay_pack_draw` + records tier 1.
- **Box-stock invariant rebuilt:** tier 1 is now a base-form gun, so the old
  `is_weapon_upgraded()` guard (which kept Mystery-Box copies stock) no longer works. Replaced by
  (a) `box_grab_clear_watcher` — on the stock `user_grabbed_weapon` notify, reset the just-boxed
  base's tier to 0; (b) `prune_lost_tiers` (in `pap_hud_loop`) — clear tiers for any base the
  player no longer carries, gated on `!laststand && !is_drinking && !acc_pap_busy`. `get_tier`
  drops the upgraded-only guard and reads the stored base tier (clamping an `_up` gun to ≥2).
- **Twins follow tiers** (user choice): reconcile already reskins whatever form is held, so a
  tier-1 gun uses base-form twins and a tier-2 gun uses `_up` twins automatically. Added camo
  preservation to `acc_weapon_variants::swap_weapon` (reads `acc_pap_tier` raw, like `has_mega`)
  so a perk-twin swap keeps the gold camo on a tier-1 base gun.
- **Cost display (`pap_cost_display_keeper`):** now drives `self.cost` for a tier-1 base gun (the
  next pack is the T2 transform) with save/restore so bonfire/stock first-pack cost isn't
  clobbered; `self.aat_cost` for `_up` guns (T3 cost, or 0 when maxed).
- **UI:** `acc_hud.lua` PaP card + `tier_benefit` rewritten to the 3-tier ladder; `set_pap_tier`
  comment 0..5→0..3. Docs: `05_weapons.md` (PaP tier table), `06_mechanics.md` (damage stack),
  `27_ui_plan.md`.
- **No twin/GDT regen:** the recoil/fire/reload twin matrix is unchanged (both base and `_up`
  twins already exist), so no `apply_recoil_overhaul.js` re-run and no twin-cap pressure.

### Investigated — LED relight definitively dead; stale-shadow "fix" rejected, deferred (user, 2026-06-16)

Persistent floor shadows = the `.led` lightmap is from 6/15 (baked while the now-removed pillars
still existed); every `-SkipLED` build re-packs that stale lightmap. Ran the controlled test
docs/38 §6 step-0 never ran: a fresh LED bake on the **current pillars-removed** geometry,
**game closed / GPU free** → SAME crash (`SANITY CHECK FAILURE … brush.cpp:1860`, live modal
captured). So geometry simplification did NOT help and it is NOT GPU contention — the install's
lightmapper is genuinely dead (confirms memory `led-relight-dead-end-enclosed-geometry`).
Also verified the **no-lightmap fallback fails**: re-linking with the `.led` moved aside packs a
valid `.ff` (linker warns `Failed to open …​.led`, non-fatal) but the world renders **fullbright
pure white** (greybox base color = white). Restored the stale `.led`; `.ff` back to 34.5 MB normal
brightness. Stale lightmap backed up at `share/raw/maps/zm/zm_abandoned_cyber_city.led.stale-6-15-bak`.
**Then attempted the full per-feature LED-safe rework (~30 bakes, fast bisection harness):** proved
Radiant is healthy (clean ~13s bakes of old snapshots — **no reinstall**) and localized the crash to
4 recent generator brush groups (vault seals, perk flank walls, box collision clips, vault ceiling).
But the fix **does not converge** — even the simplest static flank walls crash in every config
(z256/z250/penetrate/abut/no-overlap) while the same map without them bakes clean; the docs/36
"LED-safe" heuristics are false on this install. `tools/fix_led_safe_geometry.js` is a parked
incomplete artifact. **Final decision: abandon baked LED; deliver the dark look via runtime vision
tint + fog (LED-free), which makes the stale shadows moot.** Full writeup docs/40.

### Changed — Perk-handling rework STAGE 3: AK-74u added → all 10 eligible guns (user, 2026-06-16, NEEDS BOOT TEST)

Final gun in the twin set. **140 twins / 10 guns**, `.ff` 34.50 MB, lint + node-syntax clean.
- **AK-74u twin** wired via a new `variant_up_name()` helper (`_acc_weapon_variants.gsc`): its PaP
  GDT asset is the irregular `t5_ak74u_up_zm` (zone loads that; CSV says `t5_ak74u_up`). The helper
  returns the real `_up_zm` name for build_available_twins + register_twin_box_weapons; gen uses the
  same via GUNS `up`. **Non-destructive** (no GDT/zone rename). NOTE: if in-game the PaP'd AK-74u's
  runtime weapon name turns out to be `t5_ak74u_up` (CSV) rather than `t5_ak74u_up_zm`, its *PaP*
  twins won't swap (base twins still work, no crash) — would then need the GDT-entry rename instead.
- **Stem-based CLIP_FIX** (`reduce_base_ammo.js` `stemOf()`): AK-74u's clip override (20/40) now
  covers its twins too (verified twin clip 20 base-form / 40 up-form, not floored to 14).
- All 10 eligible guns (ASM1, AE4, AK-47, Tac-19, Five-Seven, PPSH, Galil, Olympia, Paladin,
  AK-74u) now get recoil(Mega Deadshot)/fire/reload twins + runtime Armory + base perks + damage.
  Ripper/Nail/PDW/M1911 stay structural (no twins). **Perk-handling rework COMPLETE pending boot test.**

### Changed — Base recoil 2.1×→1.75× + Mega Deadshot/Armory doc sync (user, 2026-06-16)

- **Map base-recoil "skill theme" lowered 2.1× → 1.75×** (`apply_recoil_overhaul.js` `BASE_SCALE`)
  on the 9 twin guns. Mega Deadshot's recoil twin (`recoil50` = ×0.50) is now 1.75 × 0.50 =
  **0.875× vanilla** (was 1.05×). Tool chain re-run (the 9 twin guns' + variant ammo-backups reset
  so the clip-cut re-snapshots the new recoil; ak74u/nail/pdw/m1911 untouched). `.ff` 34.43 MB.
- **docs/perk_abilities.md** synced to the new perk wording: base Deadshot = no recoil (dropped
  layer); American Sniper = **+1.6 HS** (was 1.8) + **−50% recoil** (0.875× vanilla); Armory =
  **+35% reserve refill at round start** (was "+25% capacity"). (No in-game text card exists —
  `_acc_perk_info` is index-only; perks use stock vending visuals.)
- **Still TODO:** AK-74u twin (CSV `_up` vs GDT `_up_zm` name mismatch — needs an in-game check of
  the PaP'd weapon's real name before wiring, or a GDT-entry rename; deferred to avoid a risky build).

### Changed — Perk-handling rework STAGE 2: expand twins to 9 guns (user, 2026-06-16, NEEDS BOOT TEST)

With the slimmed 14-twin/gun layout from Stage 1, expanded the twin matrix from 5 → **9 guns**
(added **PPSH-41, Galil, Olympia, Paladin HB50**) = **126 twins** (well under the ~230 cap). Those
4 guns now get the recoil(Mega Deadshot)/Gun-Slinger-fire/Sleight-reload twins + runtime Armory
refill + base perks + universal damage — i.e. full perk handling, same as the original 5.

- `apply_recoil_overhaul.js` GUNS +4; `_acc_weapon_variants.gsc` `variant_guns()` +4 (lockstep).
- **Olympia-twin clip fix:** `reduce_base_ammo.js` `MAXAMMO_WEAPONS` exact-set → `isMaxAmmoWeapon()`
  PREFIX match, so Olympia's twins keep clipSize 2 (double-barrel) and take the cut on maxAmmo
  instead (verified: `t6_olympia_acc_recoil50` = clip 2 / maxAmmo 13), not floored to clip 1.
- Tool chain re-run (pristine reset of the +4 base GDTs first); `.ff` 34.43 MB; linker clean.

**Held back:** **AK-74u** — CSV PaP name `t5_ak74u_up` ≠ GDT asset `t5_ak74u_up_zm`; needs a
`variant_up_name()` helper in the GSC (build_available_twins + register_twin_box_weapons) before it
can be a twin gun. **Ripper / Nail Gun / PDW / M1911** stay structural (altWeapon/projectile/akimbo)
— runtime ammo + base perks + damage only.

**Still TODO:** Mega Deadshot **UI card** + perk docs (13_perks / perk_abilities / 30 / 31) to the
1.6× / −50%-Mega-only / Armory-sustain wording; AK-74u up-name fix (→10 guns); remove dead
`axis_ammo`/`deadshot_recoil_level` + stale recoil25/40 comments.

### Changed — Perk-handling rework STAGE 1: ammo→runtime, recoil Mega-only, Mega Deadshot 1.6× (user, 2026-06-16, NEEDS BOOT TEST)

Cuts the twin count so perk handling can later reach all 10 eligible guns (plan: docs/39).
Mechanics changed on the CURRENT 5 twin guns first (5 × 14 = **70 twins**, down from 230);
Stage 2 = expand to 10 guns. The 414-twin count-cap experiment above was reverted; this is the
real fix.

- **Armory (Mule Kick Mega) → runtime sustain.** No more `maxAmmo` twin (the engine clamps
  reserve to the baked cap, so +capacity *required* a twin — that axis is now removed). Armory is
  now **+35% reserve refill per carried gun at the start of every round** (`ACC_ARMORY_ROUND_REFILL`,
  `armory_round_refill_watcher` on `acc_round_start`) + an instant top-up on acquire. `armory_apply`
  → `armory_refill`. The 10%-off discount is unchanged.
- **Recoil → single −50% tier, MEGA Deadshot only.** Base Deadshot now has NO recoil twin (dropped
  layer); recoil axis 3→2 levels. `recoil25`/`recoil40` → one `recoil50` (×0.50). `axis_recoil`
  gated on `has_mega(specialty_deadshot)`.
- **Mega Deadshot headshot 1.8 → 1.6** (`ACC_DEADSHOT_MEGA_MULT`). Base Deadshot stays 1.4×.
- Ammo axis removed from `apply_recoil_overhaul.js` TWIN_DIMS + `variant_dims()` +
  `acc_variant_axes`. `lint_gsc_xref` clean; tool chain re-run; `.ff` 34.36 MB.

**TODO (after a clean boot):** Stage 2 (add PPSH/Galil/Olympia/Paladin + AK-74u `_up_zm` fix →
10 guns / 140 twins); update the **Mega Deadshot UI card** + perk docs (13_perks / perk_abilities /
30 / 31) to the new 1.6×/−50%-Mega-only + Armory-sustain definitions; remove the now-dead
`axis_ammo`/`deadshot_recoil_level` helpers + stale recoil25/40 comments.

### EXPERIMENTAL — twin count-cap re-test: 9 guns / 414 twins (user, 2026-06-16, PENDING BOOT TEST)

User believes the "~230 twin boot cap" is a misdiagnosis and asked to test past it (revertible).
Expanded the twin matrix from 5 → **9 guns** (added PPSH, Galil, Olympia, Paladin — the
structurally-safe single-wield bulletweapons with clean `_up` PaP names) = **414 twins**,
decisively past the 368 that previously AV'd at boot. Held out: AK-74u (irregular `_up_zm` PaP
name desyncs the GSC twin lookup), Ripper (convertible altWeapon), Nail Gun (projectile),
PDW/M1911 (akimbo) — separate crash modes.

Changes: `apply_recoil_overhaul.js` GUNS +4; `_acc_weapon_variants.gsc` `variant_guns()` +4;
tool chain re-run (reset the +4 GDT backups to pristine first so clips don't double-cut / recoil
doesn't get wiped); zone auto-regenerated to 414 `weaponfull` lines; gdtdb (1838 assets).
**Linker packs a clean `.ff` (34.80 MB)** — but the cap crashes at RUNTIME weapon registration,
which the linker can't catch, so this NEEDS an in-game boot test.
- **If it boots:** cap was a misdiagnosis → proceed to AK-74u (rename fix) + the structural guns.
- **If it black-screens / won't load:** cap confirmed. REVERT = `git checkout` the two source
  files, restore the +4 base GDTs from `*.acc-ammo-orig`, re-run apply_recoil_overhaul +
  reduce_base_ammo + gdtdb (regenerates the 230/5-gun state).
- Known cosmetic TODO if it boots: Olympia *twins* got clipSize floored to 1 (the double-barrel
  maxAmmo-instead rule only protects the exact base/up names, not twins) — fix before shipping.

### Changed — Tier reassignment pass; 6 guns re-pointed + restatted (user, 2026-06-16)

User reshuffled the tier table; each moved gun's damage mult was retuned so its actual
power matches the new tier (all `acc_weapon_balance_mult` edits → cover base+PaP+twins via
`IsSubStr`; no GDT/twin GSC changes this round). Moves + restats:
- **Nail Gun** Bad → **Excellent**: ×0.204 → **×0.37** (~589 DPS; heavy per-nail punch offsets projectile travel).
- **Paladin HB50** Excellent → **Good**: ×0.80 → **×0.70** (700/shot; one-shots a couple rounds sooner).
- **ASM1** Good → **Bad**: ×0.2625 → **×0.21** (~401 DPS; now the weakest auto by design).
- **AK-47** Good → **Average**: ×0.1955 → **×0.184** (~460 DPS; Focus Fire keeps it appealing).
- **AK-74u** Average → **Good**: ×0.22 → **×0.225** (~506 DPS; clear of the now-Average AK-47).
- **AE4** stays **Good** (×0.38). Galil/Ripper/Tac-19/PPSH/PDW/M1911/Five-Seven/Olympia unchanged.

New tiers — **Excellent:** Tac-19, Ripper, Nail Gun. **Good:** AE4, Galil, AK-74u, Paladin.
**Average:** PPSH-41, PDW-57, M1911, AK-47. **Bad:** Five-Seven, Olympia, ASM1.
Linker-only; `.ff` 34.55 MB clean.

**Twin-alignment sweep (2026-06-16): VERIFIED clean, no edits needed.** Audited all 230
perk-variant entries in `acc_weapon_variants.gdt` (46 each × ASM1/AE4/AK-47/Tac-19/Five-Seven)
vs their base/PaP reference: every twin's baked `damage`/`clipSize`/`maxAmmo` matches the base
(ammo twins correctly at maxAmmo ×1.25), and every twin name carries its base substring so the
`acc_weapon_balance_mult` `IsSubStr` lookup applies the tier multiplier to it at runtime. **0 drift.**
This is by design — tier damage is a runtime GSC multiplier keyed by substring, so a base-gun
tier change auto-propagates to all its twins; the GDT only bakes recoil/fire/reload/ammo (clip
unchanged for the 5 twin guns this pass), so nothing to hand-edit.

### Changed — Balance audit + 4-tier classification; AE4 buff (user, 2026-06-16)

Full power audit of all 14 box guns, sorted into **Excellent / Good / Average / Bad**
(~25% each) on a holistic score: single-target DPS, horde power (penetration/pellets/RoF),
ammo economy (reserve/clip/reload), ease-of-use (RPM feel, projectile travel), and
role/PaP-gimmick value — NOT raw DPS alone.

- **AE4 buffed** ×0.2635 → **×0.38** (~351 → ~506 body DPS). It was the DPS floor AND the
  slowest-firing AR (500 RPM), so it sits at the TOP of the Good band to offset the sluggish
  feel. Lands ~AK-47/Galil/ASM1 with the bonus of medium penetration + 200 reserve.
- No other mechanical change — the just-applied PPSH/Nail-Gun nerfs + Olympia buff are
  intentional and define the lower/role tiers; nothing else was "crazy" out of band.

Final tiers:
- **Excellent:** Tac-19, Paladin HB50, Ripper.
- **Good:** AE4, AK-47, Galil, ASM1.
- **Average:** AK-74u, PPSH-41, PDW-57, M1911.
- **Bad:** Five-Seven, Nail Gun, Olympia.

Auto DPS band after the buff: ~418 (PPSH) – 565 (Ripper) = 1.35x spread (role/Bad guns sit
outside by design). Linker-only (GSC mult); fresh `.ff` 34.55 MB, clean. Needs playtest feel-check.

### Changed — Weapon balance pass: per-gun damage + AK-74u/Nail Gun stats (user, 2026-06-16)

Seven targeted changes across two systems. **Damage** retunes go through
`_acc_damage::acc_weapon_balance_mult` (an `IsSubStr` lookup, so each edit covers base +
PaP + every perk twin in one line — nothing to propagate by hand). **Clip / reserve /
fire-rate** are GDT fields handled by `tools/reduce_base_ammo.js` (new `CLIP_FIX` /
`FIRETIME_FIX` maps); both retuned guns are **twin-less** (not in `acc_weapon_variants.gdt`),
so the base-GDT edit is the whole story.

Damage (`acc_weapon_balance_mult`):
- **Olympia +15%** ×0.85 → **×0.9775**.
- **PPSH-41 −15%** ×0.20 → **×0.17**.
- **Five-Seven −20%** ×0.375 → **×0.30**.
- **M1911 +25%** base ×3.5 → **×4.375**; akimbo-explosive PaP ×0.40 → **×0.50**.
- **All ARs −15%** (rifle-class, incl. Nail Gun per user): AK-47 ×0.23 → **×0.1955**,
  Galil ×0.21 → **×0.1785**, AE4 ×0.31 → **×0.2635**, Nail Gun ×0.24 → **×0.204**.

Clip / reserve / fire-rate (`reduce_base_ammo.js`):
- **AK-74u** clip restored **20 / 40** (base/PaP) — exempt from the 30% cut; with maxAmmo
  8/7 that's **reserve 160 / 280** (user: "back to 20, reserve 160"). `CLIP_FIX`.
- **Nail Gun** clip **30 / 40** (`CLIP_FIX`) and **fire rate −25%** — `fireTime` 0.118→**0.157**
  base, 0.10→**0.133** PaP (RPM ~508→381) via `FIRETIME_FIX`. Reserve follows clip → 210/320.

Pipeline: `_acc_damage.gsc` edit + `node tools/reduce_base_ammo.js` → `gdtdb /update`
(15 GDTs, 1654 assets) → linker. Fresh `.ff` 34.55 MB, GSC clean, 1-waiver baseline.
**Needs in-game confirmation.** REVERT damage = git revert the GSC; REVERT ammo = restore
`*.acc-ammo-orig` + remove the CLIP_FIX/FIRETIME_FIX entries + `gdtdb /update`.

### Fixed — Ammo-economy pass: Olympia/Galil reduction + PDW-PaP 920 outlier (user, 2026-06-16)

Two gaps in the global 30% ammo cut (`tools/reduce_base_ammo.js`, FACTOR 0.70):

- **Olympia + Galil were never reduced.** Both were added to the box on 2026-06-15
  but left out of the tool's `GDTS` list, so they shipped at full Skye-port ammo while
  every other box gun was already 30% tighter (no `.acc-ammo-orig` backup existed for
  either = proof they were never processed). **Galil** now takes the standard `clipSize`
  ×0.70 (mag 35→25 base / 50→35 PaP; reserve 315→225 / 600→420). **Olympia** is a
  double-barrel (`clipSize 2`) — ×0.70 would round it to **1** (a single-barrel gun), so
  its 30% comes off `maxAmmo`/`startAmmo` instead (reserve 38→26 base / 60→42 PaP, clip
  stays 2). The tool now handles this floor case via `MAXAMMO_WEAPONS`.
- **PDW PaP `s1_pdw_rdw_up_zm` had `maxAmmo`/`startAmmo` 920** — a Skye-port data error,
  ~70-130× every peer (others are 6-12; the m1911 akimbo-PaP uses 10). Reserve = clipSize
  × maxAmmo, so 920 mags is a wildly broken stockpile. Clamped to **18** (reserve ≈ 306,
  right in the PaP band of ~280-420) via the tool's new `MAXAMMO_FIX`. This is the "PDW PaP
  has ~900 bullets while other guns have ~300" imbalance.

Reserve model (verified across all 14 box guns): `maxAmmo`/`startAmmo` are reserve
**magazine** counts (6-12), so in-game reserve rounds = `maxAmmo × clipSize`. Low-clip guns
carry more mags (Tac-19/Paladin clip 4 × 12 = 48; Olympia clip 2) and high-clip guns fewer
(Galil 35 × 9). After this pass the economy is consistent — no >2× outliers. **Damage**
balance is a separate lever (`_acc_damage::acc_weapon_balance_mult`) and was NOT touched here.

Pipeline: `node tools/reduce_base_ammo.js` (idempotent, reduces from `.acc-ammo-orig`) →
`gdtdb /update` (15 GDTs, 1654 assets) → linker. Fresh `.ff` 34.55 MB at the 1-waiver
baseline. **Needs in-game confirmation** of the new reserve counts (box-spin Olympia/Galil/PDW,
PaP each). REVERT = restore `*.acc-ammo-orig` + `gdtdb /update`.

### Added — Bus Station cross-room trench + jump-down fall tax (user, 2026-06-16)

The **Bus Station (corp_zone)** now has a horizontal (E-W) **trench cut
dead-centre**, splitting the room into a south half (Market/Alley entrances +
power switch + box) and a north half (doors to Vault/Helipad). It spans the full
1600u width, is **288u deep with vertical walls on all four sides** (incl. E/W
**end walls** below the perimeter walls — without them the trench's open ends let
players walk off the map), and the **450u top gap can't be jumped** — to cross you
go down and up the far side. **One thin 96u staircase per side, hugging the E/W
side walls** (so they don't eat the open pit floor): a **west-wall** stair (south
lip) + an **east-wall** stair (north lip), joined by the open floor → you cross by
going **down one wall and up the other** (diagonal: SW down → NE up). Each stair has
a **guard rail down its open (pit-facing) side** (end wall on the other) so you can't
fall off the stair into the pit; the bottom stays open so it still spills onto the floor.
Walk it free, or **just jump in** (preferred). At **288u it is now past the engine's
256u fall-damage threshold**, so a jump-in takes a little NATIVE fall damage on top
of the scripted tax. _(Scaled from the initial 112u/288u: depth ×1.2 → ×1.3 → ×1.2
→ ×1.2 → ×1.15 = 288u; width ×1.2 → ×1.3 = 450u; on user request,
2026-06-16.)_ Geometry: one-shot generator `tools/gen_corp_trench.js` replaces
the single corp floor brush with south + north thick ground slabs (z[-304,0] —
inner faces are the N/S retaining walls), the trench floor (top z=-288), 2 E/W
end walls, and 2×17 stair brushes (one per lip); the corp `info_volume` floor was
lowered (-16 → -320) so the trench interior stays inside the zone; the corp power
switch (790,1900→790,1600) and dog spawn (319,1948→319,1560) were moved clear of
the trench band.

**Jump-down fall tax:** new module `_acc_bus_trench.gsc` (wired in `_acc_main::init`
+ `.zone`) applies a **~25 `MOD_FALLING` tax** when a player drops into the trench
with downward velocity past a threshold — so jumping in is taxed but **walking the
stair walkway down is free**. Native engine fall damage can't do this (stock ZM
`bg_fallDamageMinHeight` is 256u — the 288u trench is now just past it, so native fall dmg stacks on the scripted tax), hence the scripted, velocity-
gated tax. Uses `MOD_FALLING` so **PhD Flopper's existing damage override negates it**.
**Always on — no flag/dvar** (retune via the `ACC_TRENCH_FALL_DMG` constant, default 25).

SoT: `source_data/rooms.json` gains a `"trenches"` block (corp); `tools/validate_rooms.js`
is now trench-aware (checks the 3 split slabs instead of the single full-footprint
floor — 24 ok / 0 err). Docs: `docs/03_layout.md` Bus Station. ⚠️ **Playtest:** the
trench walls block every crossing except the stair channel, so **zombies funnel
through it** — verify navmesh links the 16/16 stairs and the chokepoint feels right.
Requires a **full geometry build** (cod2map64 + navmesh), not GSC-only.

### Added — Lab perk alcoves with per-round random-3 access (user, 2026-06-16)

The 9 Lab perk machines (the row at Y=4195: QR/Jug/Speed/DoubleTap/Stamin/Mule/
Deadshot/Widow's/PhD) are now each in their own **door-gated alcove** on the Lab
north wall, and only a **random 3 of the 9 open each round** (the rest are walled
off and unbuyable that round; a closed door never removes an already-owned perk).
New geometry via `tools/add_perk_alcoves.js`: 10 partition walls (one stall per
machine), 9 `acc_perk_door_<specialty>` `script_brushmodel` gates across the stall
mouths, and all 9 machines reoriented to face south (into the stall/player). New
module `_acc_perk_doors.gsc` (wired in `_acc_main::init` + `.zone`) closes all then
opens a random 3 on each `acc_round_start` (Fisher-Yates via `acc_utility::acc_rand_int`,
gates toggled with the `_acc_lockdown` seal idiom). **Dev: all 9 open** (follows
`acc_open_map`; force with `acc_perk_doors_all_open 1`). A ship build launches
`acc_open_map 0` to enable the rotation.

**Follow-up (2026-06-16, `tools/fix_perk_facing_flanks.js`):** the yaw-270 reorient
above actually faced the machines WEST (sideways) — reverted all 9 to **yaw 0**
(the original facing = south, toward the player at the stall mouth). Also added two
**flanking walls** (west `X[-761,-675]`, east `X[675,799]`, full stall depth + height)
so the gallery reads as a recess in the back wall ("the wall moved forward") instead
of moving the machines behind the real hull (which would leak). Still verify facing
in-game; if a model looks backwards it's a one-line yaw flip.

### Added — Mystery box spawn node in every room + walk-through collision fix (user, 2026-06-16)

The single moving Mystery Box now has a spawn node in **all 7 rooms** (was 3:
Market/Bus Station/Helipad; added Plaza/Alley/Vault/Lab via `tools/add_room_boxes.js`,
each tucked against a room wall). `roll_mystery_box_initial` rolls all 7; the stock
teddy-bear move walks the box among them. **Collision:** the MagicBox model has no
player clip (walk-through), so each node gets an invisible `acc_box_clip_<node>`
`clip` brushmodel; `_acc_map_randomizer::manage_box_collision` keeps **only the
active node's clip solid** (tracks `level.chests[level.chest_index]`), so the 6
rooms without the box have no phantom invisible block.

### Changed — Zone rename: Plaza→Bus Station, Spawn→Plaza (user, 2026-06-16)

Two **display-name** renames (internal zone IDs `corp_zone` / `start_zone` are
UNCHANGED — only the human-facing names move):
- `corp_zone` "Plaza" → **"Bus Station"**
- `start_zone` "Spawn" → **"Plaza"**

Updated everywhere the names surface: `source_data/rooms.json` (`name` fields),
`_acc_dev.gsc::dev_zone_name`, `tools/gen_map_design.js` zone labels (SVG
regenerated), `tools/gen_zone_greybox.js` header comments, and the GSC comments in
`_acc_decontamination.gsc` / `_acc_events_hack.gsc`. Doc sweep across `docs/*.md`
(Plaza→Bus Station first, then the start-zone location "Spawn"→Plaza, leaving spawn
*mechanics* words untouched). Decon eligibility and all gameplay wiring key off the
unchanged internal IDs, so behaviour is identical.

### Reverted — Scattered match-start spawns (attempted, shelved; user, 2026-06-16)

A "each player starts in a random outer zone (Helipad/Vault/Market/Alley), not
Plaza" feature was attempted but **hit two BO3 engine walls and was removed**;
players spawn in Plaza (`start_zone`) as before. Module `_acc_spawn_distribute.gsc`
deleted, unwired from `_acc_main` + the `.zone`, spawn points restored to start_zone.
(1) **Teleport after spawn** → player spawns fine but is consistently lifted to
`z=105` and stuck ~7s later (not a zombie swarm — verified `znear=0`); reground/clear
mitigations didn't hold. (2) **Moving the `initial_spawn_points` structs into the
zones** → stock `_zm.gsc`/`clientfield_shared.gsc` `cannot cast undefined to int`
crash on spawn (BO3 initial-spawn isn't built to start players in a non-start zone).
Full diagnosis: memory `scatter-spawn-engine-walls`. Plaza spawn is the known-good
baseline; revisit per-zone spawns as a researched, standalone task.

### Removed — All free-standing blocking obstacles → flat rooms (user, 2026-06-16)

Per user request, the map's rooms are now **flat/open**: every free-standing blocking
structure was removed so only the room shells (floor/walls/ceiling), doors, and
functional structs (mystery box, Pack-a-Punch, perk machines) remain. Deleted 10
worldspawn `script_wall` cover brushes from
`map_source/zm/zm_abandoned_cyber_city.map` (guids `…0145`–`…014C` + `ACCADDS0/ACCADDS1`):
spawn debris pile, corp fountain, corp S-curve A/B, the 3 market stalls, the roof
central obstacle, and the two Stage-3 start-cover blocks. The vault ceiling
(`ACCVCEIL`), the spawn barricade-window frame, and all gameplay structs were left
untouched. Source-of-truth generators updated so a regen can't reintroduce them:
training-obstacle pushes commented out in `tools/gen_zone_greybox.js`, `S0/S1`
disabled in `tools/apply_room_shrink.js` ADD list, `obstacles[]` emptied in
`tools/gen_map_design.js` (SVG regenerated — no obstacle markers). Backup:
`…map.pre-flatten-bak`. Geometry change → needs the FULL build (cod2map+navmesh+LED+
linker), not a `-GscOnly` pass.

### Added — Glitch Stalker teleport "warp" SFX (2026-06-15)

The Glitch Stalker now plays a 3D positional **warp** sound at its destination every time it blinks
(`_acc_boss_glitch::glitch_blink_loop`, gated by `acc_glitch_warp_snd`, default on). Source WAV
(`warp.wav`) converted to the BO3 3D-SFX convention (**48 kHz / 16-bit / mono**) via the new
`tools/convert_wav_48k_mono.ps1` (no ffmpeg needed), placed at `sound_assets/acc/fx/warp.wav`, aliased
as `acc_glitch_warp` in `sound/aliases/acc_audio.csv` (3D, NONLOOPING). **Build note (corrects docs/35):**
the linker *does* rebuild the soundbank on a `-GscOnly` pass when an alias CSV or WAV changed (verified:
bank + `.alias.sz` regenerated, `acc_glitch_warp` present) — a stale-bank reuse only happens when the
sound sources are unchanged. ⚠️ **LICENSE:** `warp.wav` came from a local download — its origin/licence
must be verified (CC0 / self-authored only) before the Workshop item goes Public (CREDITS.md / docs/35).

### Fixed — Twin guns (AE4/Tac-19/etc.) had NO Pack-a-Punch prompt while a perk was active (user, 2026-06-15)

**Real root cause of the recurring "some guns can't PaP" report** — and it was neither max-tier
nor the akimbo CSV `_zm` bug. The PaP machine's interact **prompt visibility** is gated by stock
`can_pack_weapon` (`_zm_pack_a_punch.gsc:253`) → `is_weapon_or_base_included` + `can_upgrade_weapon`,
both of which look up `level.zombie_weapons[ weapon.rootWeapon ]`. The weapon-variant **base twins**
(`s1_ae4_acc_recoil25`, etc. — what you actually HOLD whenever **Deadshot / Gun Slinger / Speed Cola
Mega / The Armory** is active) have `rootWeapon == themselves` and are **deliberately absent** from
`level.zombie_weapons` (so the Mystery Box can't roll a twin). So the machine judged the held weapon
un-packable and `SetInvisibleToPlayer`-hid the trigger → **no prompt at all**. It read as random
because it is **perk-gated and twin-only** (the 5 `variant_guns`), "moving" to whichever twin gun you
held with a qualifying perk — pistols before, AE4 + Tac-19 now. The variant twin GDTs carry no
`rootWeapon` field, which is the kernel of the user's "_zm / gun name" hunch.

Fix in `_acc_weapon_variants::register_twin_box_weapons()` (new, called from `init()` after
`register_twin_upgrades`): register each base twin into `level.zombie_weapons` mirroring its base
gun's struct (`.upgrade` → the packed twin) but with **`is_in_box = false`**. `is_weapon_included` +
`can_upgrade_weapon` now pass → the prompt shows; the box still skips it
(`treasure_chest_CanPlayerReceiveWeapon` gates on `get_is_in_box`, `_zm_magicbox.gsc:1222`). The pack
itself is unchanged — our `acc_pap_validate` custom_validation still does the in-place first-pack and
returns false, so stock's float pack never runs. PaP'd (`_up`) twins already showed the prompt via the
AAT re-pack path, so only the un-upgraded base twins needed this. GSC-only; xref lint clean; linker-only
rebuild. **Needs in-game confirm:** hold a twin gun with Deadshot/Gun Slinger/Speed Cola Mega/Armory
active → the Pack-a-Punch prompt now appears and first-packs normally.

### Changed — Zone display names simplified to one word each (2026-06-15)

Rebranded every zone's human-readable **display name** from two words to one, across all docs,
code, the SVG, and the SoT. Internal identifiers are **untouched** (zone keys `*_zone`, `shortName`s,
script_strings `corp`/`vault`, decon flags, mermaid node ids) — only the names players/designers read.

| Zone | Old name | New name |
|---|---|---|
| `start_zone` | Spawn Plaza | **Spawn** |
| `market_zone` | Undercity Market | **Market** |
| `alley_zone` | Service Alley | **Alley** |
| `corp_zone` | Corporate Plaza | **Plaza** |
| `vault_zone` | Server Vault | **Vault** |
| `roof_zone` | Rooftop Helipad | **Helipad** |
| `lab_zone` | Subterranean Lab | **Lab** |

- **SoT:** `source_data/rooms.json` `rooms.*.name`. Propagated to the in-game strings
  (`_acc_decontamination::get_zone_display_name`, `_acc_dev` zone HUD), generators
  (`gen_map_design.js`, `gen_zone_greybox.js`, `gen_rooms.js`), and ~20 docs. `docs/03_layout.md`
  ASCII diagram + mermaid graphs hand-redrawn; `docs/map_design.svg` regenerated via
  `node tools/gen_map_design.js`. `validate_rooms.js` still PASS (22 ok, names aren't geometry).
- **Deliberately left as historical record:** prior CHANGELOG entries (dated, names accurate at the
  time) and the `*.map.*-bak` snapshots (internal `// ACC room shell` comments only, no display names).

### Fixed — Brutus mini-boss "spawns then stands frozen" (TRUE root cause, 2026-06-15)

Brutus spawned in the lab and never moved (only swung if you walked into melee range). Root-caused
**live** via temporary `[BRUTUS-DBG]` instrumentation, which printed `pm=move allowed, hasPath=Y,
target=Y, goalSet=Y, moved=0` every second — i.e. his pathing was **perfect** (valid navmesh path to
the player) but his body never translated. So it was never a navmesh / PathMode / ignoreall / spawn-anim
bug (every prior theory — all disproven by the data). It was a **locomotion/ASM** bug: our
`_acc_zombie_speed.gsc` `speed_keepalive()` sweep runs every 1.5 s and calls
`set_zombie_run_cycle_override_value()` + `ASMSetAnimationRate()` on every actor where
`zombie_utility::is_zombie()` is true. Brutus sets `self.is_zombie = true` (needed for melee), so the
sweep grabbed him and **stomped his custom `zm_brutus` run-cycle animation** — re-freezing him every
1.5 s. (This system replaced the old Rampage Inducer, which is exactly the "he moved a few PRs ago"
window.)
- **Fix:** `_acc_zombie_speed::apply_speed_for_round` now early-outs for any boss
  (`is_boss` / `acc_boss_custom_speed` / `acc_is_boss` / `acc_is_mini_boss`) — one chokepoint covering
  both the on-spawn hook and the keepalive sweep. The pack flags Brutus `is_boss` + `acc_boss_custom_speed`
  the instant he spawns (before any callback can race). The Glitch Stalker already opted out the same way;
  this generalizes it. **Invariant going forward: the zombie-speed curve only ever touches regular zombies
  — any custom-AI boss MUST set a boss marker.**
- **Restored** Brutus's full promotion now that the cause is known: 10× HP, boss health bar + nameplate,
  Mega-Bottle/boss-item rewards, boss music. Added belt-and-suspenders robustness in the pack:
  `GetClosestPointOnNavMesh` clamp on the spawn spot + a host-player fallback if the lab spot isn't
  activated (no more silent no-shows).
- **Removed** all the debug scaffolding and dead experiments (the `[BRUTUS-DBG]`/`[BRUTUS-TEST]` diag,
  hardcoded spawner, `brutus_spawn_diag`, the obsolete `brutus_force_resume` band-aid, and the
  `apply_brutus_buffs`/`boss_speed_think`/`brutus_movement_fix` size/speed experiments). The **+50% size
  buff stays OUT** — `SetScale` on the live Brutus AI is a *separately* confirmed engine CTD (0xC0000005,
  minidump-verified), unrelated to this freeze.

### Fixed/Investigated — Radiant LED crash root-caused; baked darkness is a dead end here (2026-06-15)

The Mod Tools **Radiant lightmapper crashes** (`SANITY CHECK FAILURE` `brush.cpp:1860` →
`Device.cpp:395 (pDevice)` → `GfxFrustumRegister`/`Gfx::ProbeInst` "outstanding allocations" cascade)
on the enclosed-vault geometry (ceiling + door seals). **Exhaustively confirmed it crashes in EVERY
config:** GUI Launcher (Compile+Light) AND headless; `+localprobes` ON and OFF; BlackOps3 running and
closed. So it's **not** the probes, GPU contention, or brush winding (cod2map64 accepts the brushes as
valid boxes) — it's the same lightmapper limitation that shelved the lab ceilings (docs/36/38). Output
of a multi-agent root-cause workflow + an empirical probe-free build test.
- **Real bug found + fixed:** all 7 `reflection_probe` entities had an **inverted Y box** (`size_min`
  548.5 > `size_max` 544.75 — a verbatim `zm_alien_isolation` copy) → corrected to 540.75 in the `.map`.
  (Did not stop the crash, but is a genuine latent bug to fix before LED is ever usable again.)
- **Brush generators** (`add_vault_ceiling.js`, `add_lockdown_seals.js`) rewritten to emit **real corner
  coordinates** (not the filler-coordinate winding) — good hygiene; cod2map64 was always fine with both.
- **`build_map.ps1`:** LED comment updated to the verified dead-end; **build this map with `-SkipLED`**.
  `+localprobes` dropped (fragile GPU pass) so LED can be retried IF the ceiling/seals are removed.
- **Path forward for a dark vault = LED-free per-player vision** (`VisionSetNaked("zombie_turned")` in a
  `.csc`, driven by a zone-IsTouching clientfield) — no lightmap, no crash. Spec: docs/37 §11. New
  memory: `led-relight-dead-end-enclosed-geometry`.
- Red alarm FX (`_acc_lockdown.gsc`) is unaffected/LED-free and now pulses + has on-screen `[lockdown]` debug.

### Investigated (NOT a bug) — "can't PaP Tac-19/AK-47" was MAX-TIER, not the Olympia/Galil add (user, 2026-06-15)

After adding the Olympia + Galil box guns, the user reported the Tac-19 and AK-47 would no
longer Pack-a-Punch. Investigated with a temporarily-widened `PaPDIAG` print in
`acc_pap_validate`. The diag was conclusive — **there was no bug**:
```
held=s1_tac19    upg=0 tier=0  getup=s1_tac19_up  packed=s1_tac19_up   (fresh base → first-packs)
held=s1_tac19_up upg=1 tier=1..4  getup=s1_tac19_up  packed=s1_tac19_up  (tiers fine, → 5/5 MAX)
```
The upgrade resolution (`getup`/`packed`) works at every step. The "can't PaP" was the guns
being at **MAX TIER 5/5** from earlier that session — `acc_do_tier_up` correctly refuses a maxed
gun ("already max tier 5"), which reads as "won't PaP". `acc_pap_tier` is an in-memory player
field keyed by `true_base`, so a maxed tier persists across losing/re-boxing that base within a
session and only clears on a **relaunch** (new session) or a fresh first-pack (resets to 1) —
which is why it "worked again" after the user relaunched. The gun-add was coincidental: the build
has all the upgrade assets (verified `s1_tac19_up`/`t6_ak47_up` + twins in the asset deps), and a
new gun's assets are independent of existing guns' PaP. Documented the trap in the
`_acc_pap_levels.gsc` header ("MAX-TIER reads as can't-PaP"); `PaPDIAG` reverted to its original
akimbo-only scope (the Tac-19/AK-47 widening removed). No functional change. Linker-only rebuild.

### Added — docs/38: LED-safe enclosed lab-tunnel research (read-only; corrects the LED diagnosis) (2026-06-15)

Read-only investigation (10-agent workflow + adversarial verification) into doing the deferred lab-approach
ceilings + maze + lighting **seamlessly** — no code/geometry changes (map owned by a concurrent agent).
New doc **`docs/38_lab_tunnel_led_safe_research.md`** with a decision-ready, asset-verified recipe.
- **Corrects the earlier root-cause:** the "coplanar z256 ceiling crashes the LED lightmapper" theory is
  **not proven and partly contradicted** — `gen_rooms`' coplanar-overlapping shells baked clean (2026-06-13), and
  the crashing `C0` ceiling was z264 (8u *above* the wall tops, not coplanar). **Dominant cause = headless
  `-ledSilent` instability** (nondeterministic after repeated runs + a force-kill); thin slivers (8u-off-wall cover)
  are the only credible geometric co-factor; enclosure/no-light bakes **black**, it does not crash.
- **New latent hazard found:** all 7 `reflection_probe`s have a malformed box (`size_min Y 548.5 > size_max Y
  544.75` → inner ball not contained) — a documented LED-crash trigger; fix independently.
- **Verified-real assets:** the `light` entity = kelson8 `PRIMARY_OMNI` block with **no `def` key**
  (`tmp/kelson8_testmap/...:3792`); `caulk`/`clip`/`hint` tool materials are real (shipped maps use them).
- **Recipe:** build each tunnel as ONE watertight closed tube (replace the open-top walls, don't cap them) +
  an in-tunnel omni light + a contained per-tunnel probe; **put the maze cover in the vault/roof rooms, not the
  216u corridors** (too tight — at/below the horde-lane floor + already gated by a door + PaP blocker); resolve the
  z258 door-open-vs-ceiling clearance. **Diagnose LED flakiness first** (rebuild current map headless twice);
  confirm a REAL relight (fresh `.led` mtime + lit-not-black in-game), never ship a black tunnel.

### Added — Lockdown stage 2: Server Vault door seal (full geometry build) (2026-06-15)

The DEFCON lockdown now physically **seals the room's doors** (not just the red light), built for the
**Server Vault** (the current pinned test room). Decision: **locks players IN, no escape window** (docs/37 §11).
- **New geometry:** `tools/add_lockdown_seals.js` (idempotent) appends two `acc_seal_vault_zone`
  `script_brushmodel` box brushes — one per vault doorway (both on the west wall x=1119: corp↔vault
  corridor y[2300,2556], vault↔lab corridor y[3100,3356]). Box-brush winding reused from
  `apply_room_shrink.js`; inset 8u off corridor walls (LED coplanar-crash gotcha), full height z[0,256].
- **Wiring** in [_acc_lockdown.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_lockdown.gsc): `init_seals()` hides them at startup;
  `lock_doors()` = `show`+`solid`+`disconnectpaths`, `unlock_doors()` = `hide`+`notsolid`+`connectpaths`
  (the `_acc_map_randomizer::apply_pap_approach` pattern). `lockdown_apply` seals, `lockdown_clear` unseals.
- **Dvar** `acc_lockdown_lock_doors` (default 1; `0` = red light only — walk in, then `1` to seal next round).
- **Vault ceiling + brighter red (visibility pass):** `tools/add_vault_ceiling.js` caps the vault
  (z[256,272]) — a guaranteed-visible landmark + a surface for the red FX to read against. Red FX now
  also emits at the room center and defaults to 6 emitters @ z180. Launchers set `acc_lockdown_lock_doors
  0` so you can walk in and see it (`1` to test the seal).
- **Build:** `cod2map64` bakes the brushes + regenerates navmesh; linker packs `.ff` 34.54 MB.
  ⚠️ **Radiant LED `-ledSilent +recompute` CRASHES** on the added ceiling/seal brushes (`SANITY CHECK
  FAILURE` / `brush.cpp:1860`, exit `-2147483645`) — same lightmapper fragility that deferred the lab
  ceilings (docs/36). Build-time **modal popup only** (never at launch), **non-fatal** (the `.ff` packs).
  **Build with `build_map.ps1 -SkipLED`** until an LED-safe geometry pass; lighting isn't recomputed but
  the checker greybox + red FX are visible.
- **To seal more rooms:** add their corridor-mouth boxes to `add_lockdown_seals.js` `SEALS` + full build.

### Added — Olympia + Galil box guns (BO2 ports, twin-less) (user, 2026-06-15)

Two more Mystery Box guns: **Olympia** (double-barrel shotgun) and **Galil** (full-auto AR).
User asked for the BO1 rips, but only their GDTs were installed (no models/sounds), so the
**fully-installed BO2 ports** (`t6_olympia`, `t6_galil`) are used — same guns. Both pre-screened
against all three boot-crash modes (docs/33) and clean: **empty `altWeapon`** (no AK-74u-style
`_zm_zm` Com_ERROR), **single-wield bulletweapon** (no akimbo/projectile twin break), and shipped
**twin-less** (the weapon-count cap silently access-violates at boot past ~230 twins, and the
5-gun twin matrix is already at the ceiling). Galil's loc mults are identical to the shipped
AK-47 (locHead 5.0, torso 1.0) so no install-side GDT edit was needed.

Wiring per gun (docs/33 ten-point recipe, steps 8–10 twins skipped):
- **Olympia** — CSV row (shotgun), zone `weapon,t6_olympia`/`_up`, box pool, **Slug Round**
  ability (shotgun category), shotgun Overclock family, balance ×0.85 + **headshot-excluded**
  (flat-damage crowd control like the Tac-19), fire + foley sounds (`close/open/shell_in/switch`).
- **Galil** — CSV row (rifle), zone `weapon,t6_galil`/`_up`, box pool, **Focus Fire** ability
  (AR category, shared w/ AK-47/AE4), AR Overclock family, balance ×0.21 (220@0.08 = 2750 raw →
  ~578 eff, AK-47 band; keeps the AR headshot chain), fire + foley (`bolt_*/futz/mag_*`).

Sounds via `tools/gen_box_weapon_sounds.js` (added both to `GUNS[]`, foley auto-scanned). Built
one-at-a-time per the runbook's hard rule (Olympia first, then Galil). Linker-only (no geometry);
each `.ff` fresh + growing (34.3 → 34.4 → 34.54 MB), sound bank 13.5 → 14.04 MB, errorlog shows
only the pre-existing waived Five-Seven camo `^1 ERROR` (new guns appear only in non-fatal `^3`
xmodel-processing warnings). **Needs in-game boot-test + box spin confirming both fire/PaP/sound.**

### Fixed — Brutus spawn-freeze SOLVED: `ignoreall` + dead custom-goal under stock dvar (2026-06-15)

**Root cause (verified against stock `_zm_behavior.gsc`/`zombie.gsc` via an ultracode multi-agent
workflow + independent re-read).** Brutus stood still (only AnimScripted spawn/melee played) because the
NSZ pack's chase model is **dead code under stock BO3's default**. The pack chases by writing
`self.v_zombie_custom_goal_pos` (custom_find_flesh), but stock defaults `SetDvar("scr_zm_use_code_enemy_selection",1)`
([_zm_behavior.gsc:145]) → `zombieFindFlesh` delegates to `zombieFindFleshCode` (`:160-164`) which targets
`self.enemy`, **not** the custom goal — the only custom-goal consumer (`:276`) is dead under that dvar. And
`brutus.ignoreall = true` ([nsz_brutus.gsc:195], never cleared) makes the engine never assign `self.enemy`
**and** gates off the alternate consumer `zombieTargetService` ([zombie.gsc:443]). So `zombieFindFleshCode`
takes its no-target branch → `SetGoal(self.origin)` (`:438`) → `HasPath()` false forever → frozen.

**Fix (code-only, GSC-only build):** add `brutus.ignoreall = false;` in `spawn_brutus`'s post-spawn-anim
block ([_NSZ/nsz_brutus.gsc](scripts/_NSZ/nsz_brutus.gsc)) so the **standard code-side find-flesh chase** runs — the exact path that already
moves the Glitch Stalker (which never sets `ignoreall`) in this same map. `canattack`/`allowmelee` stay
false so the pack's scripted melee remains his only attack; the navmesh-clamp + PathMode/SetGoal stay as
harmless belt-and-suspenders. **Why the prior fixes failed:** navmesh-clamp fixes only spawn *position* (goal
was pinned to origin regardless); `PathMode` is checked only in the dead legacy branch (`:171`) so re-opening
it is a no-op under dvar=1; `SetGoal(brutus.origin)` re-confirmed the freeze.

Also fixed 3 orthogonal **death-path** crashers surfaced by the runtime log (concurrent edits, verified in
tree): `track_helmet` missing `endon("death")`; `new_death` unguarded `self.light`/`self`/`clone` deletes;
and the `_acc_boss.gsc` base-pack log line concatenating an undefined `host.maxhealth`.

### Changed — Brutus: STRIPPED to pure base-pack (all promotion commented out) to isolate the spawn-freeze (user, 2026-06-15)

User reports Brutus **still freezes every spawn** after the movement fix was defaulted off, and asked to
**comment out ALL our changes** to see the pure pack version move, then re-add incrementally. Done:
- `spawn_brutus_miniboss` ([_acc_boss.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_boss.gsc)) now spawns the **pure NSZ pack actor** — the entire
  promotion block (HP override, mini-boss flag, `DisableAimAssist`, boss health bar `acc_boss_spawned`,
  death-reward drops, boss music, movement fix, force-resume, size/speed buffs) is **commented out as
  labeled STEP 1–5 blocks** for one-at-a-time re-add. The only thing kept is the **observational**
  `brutus_spawn_diag` (reads pack fields, never mutates him — it's how we measure whether base moves).
- This **supersedes** the prior `acc_brutus_runfwd 1→0` revert (that default is unchanged; the whole
  call is now commented anyway).

**This freeze IS recorded before (≥4 times):** "Brutus stuck at spawn (off-navmesh z=45) + moved to the
lab" (the z fix), "Brutus 'spawns then stands frozen' — added an off-by-default spawn diagnostic" (twice),
and the two earlier **crash** (not freeze) fixes (`melee_track` deref guard; defer size/speed buffs).
The recurring pattern: each fix addressed one cause, then it resurfaced from another — so this time we
go to the **pure base** and add back deliberately.

**Investigation (the user's "we made a change to help his pathing" hypothesis does NOT hold up):**
- The Brutus GSC (`_acc_boss.gsc` / `_acc_boss_brutus.gsc` / vendored `nsz_brutus.gsc`) is **unchanged**
  since the last commit (`1ebcea5`). What changed recently (uncommitted) is the **map** (room-tightening),
  but `lab_zone` was **held** (`apply_room_shrink.js` `new == old`; lab cover/maze ADD brushes are
  disabled) and the **navmesh is fresh** (rebuilt 5:18 PM, after the 4:48 PM map edits) — so neither our
  code nor Brutus's lab arena changed under him.
- `brutus_movement_fix` gates on `self.brutus_enemy` (only touches goal/anim fields *after* he acquires a
  target), so it **cannot** cause an *immediate* on-spawn freeze. Prime suspect is the **base pack spawn**:
  it `ForceTeleport`s Brutus to the **raw, un-navmesh-clamped** origin `(19,3648,0)` (`nsz_brutus.gsc:224`,
  unlike stock `clampToNavmeshLocation`) and runs an `AnimScripted(%brutus_spawn)`; if locomotion doesn't
  resume after that anim, or the spot is marginally off-mesh, he stands frozen.
- **Confirmed pack race this turn:** the pack fires `acc_brutus_spawned` (`nsz_brutus.gsc:223`, which
  starts ALL our layer) and THEN, in the same spawn function, `ForceTeleport`s (:224) + `AnimScripted`s
  (:225). Locomotion is unlocked on a **separate** thread: `zombie_spawn_init` → `PathMode "dont move"`
  (:847) → `boss_think` → `PathMode "move allowed"` (:573) + `SetGoal(self.origin)`. That `SetGoal`/unlock
  RACES the teleport — if it runs before the teleport, his goal/path is anchored to the pre-teleport
  origin. This is why `brutus_force_resume` (re-assert PathMode+SetGoal AFTER the anim, STEP 3 in the
  re-add list) is the likely real fix.
- **Next test (to confirm the cause in one run):** launch with `acc_brutus_debug 1` and read the
  `[brutus diag]` line — `target=N` ⇒ never acquires a target; `target=Y goal=Y movedLastSec~0` ⇒ has a
  goal but can't path (off-mesh/spot); then try `acc_brutus_force_resume 1` (re-asserts
  `PathMode("move allowed")` + `SetGoal` after the spawn anim — the likely real fix if it's a
  locomotion-resume stall). Linker-only rebuild (GSC-only change).

### Changed — Glitch Stalker: −50% melee damage + blinks 2× more often (user, 2026-06-15)

Two live-dvar tweaks to the Glitch Stalker mini-boss ([_acc_boss_glitch.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_boss_glitch.gsc)):
- **Melee damage to players −50%.** New `host.meleeDamage` write in `spawn_glitch` (after the
  init-gate, so stock `zombie_spawn_init` can't clobber it — `zombie_init_done`:389 is set after
  `meleeDamage`:358). Scales the stock zombie's `60` by `acc_glitch_melee_dmg_mult` (default **0.5
  → 30**). This is the damage the boss *deals*; the existing `acc_glitch_recovery_dmg_mult` is the
  damage it *takes* while vulnerable (unchanged).
- **Blinks 2× more often.** Halved `acc_glitch_blink_cd_min` `2.0 → 1.0` and `acc_glitch_blink_cd_max`
  `3.33 → 1.665` (now 6× the original 6–10s baseline). Cadence only — blink distance, recovery
  window, and FX are unchanged.

Docs synced: [docs/11_enemies.md](docs/11_enemies.md) Glitch Stalker entry + [docs/34_flags_reference.md](docs/34_flags_reference.md) dvar table (new
`acc_glitch_melee_dmg_mult` row). Linker-only rebuild (GSC-only change).

**Not done — perk drink speed 40% faster:** no GSC/text-config lever exists. The perk-drink
duration is the perk-bottle viewmodel *animation* (the drink ends on `weapon_change_complete`,
which is anim-timed), and the stock vending flow (`_zm_perks.gsc::vending_trigger_post_think`)
can't be overridden by a usermap. This is the same proven blocker that cut Speed Cola's faster-drink
(docs/13 :441, docs/30 :135). A map-wide change would require re-exporting the bottle xanims at a
higher rate (APE/asset pipeline) — out of scope for a headless edit. Surfaced to the user.

### Fixed — Mystery Box guns no longer come out PaP'd/tiered (user, 2026-06-15)

A gun pulled from the box that the player had previously PaP'd/tiered still did upgraded damage
and showed the `PaP TIER x/5` HUD, even though the box only ever hands out **stock base** forms.
Root cause: `player.acc_pap_tier[]` is keyed by BASE weapon and never cleared, so the old tier
stuck to the base weapon forever. Fix in `_acc_pap_levels::get_tier`: the tier only counts while
the player holds the **upgraded** form (`zm_weapons::is_weapon_upgraded`). A stock/base gun now
reads tier 0 — no damage mult ([_acc_damage.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_damage.gsc) reads through `get_tier`), no HUD, no machine
re-pack cost (already gated on upgraded). Re-packing that base re-records tier 1 from scratch.
The box pool is confirmed all base forms (`_acc_map_randomizer`), so box guns are correct stock
models; this was purely the tier-tracking bleeding onto the re-rolled base. Linker-only rebuild.

### Added — Per-round "DEFCON" room lockdown, stage 1: red alarm lighting (built, linker-only) (2026-06-15)

First slice of the punishing-middle / room-event idea (docs/37): each round one room is put
under a **red flashing security alert**, and which room lights up rotates every round. New module
**`scripts/zm/zm_abandoned_cyber_city/_acc_lockdown.gsc`** (orchestrated by `acc_main::init()`,
armed before `watch_round_transitions` like decon). **OFF by default** — same stance as the fog/
ambient knobs; the owner enables + eyeballs it in-game.
- **Localized red, not global:** `SetVolFog`/vision are whole-map, so fog/tint can't be confined
  to a room. The alarm look is **placed FX emitters** instead — a few flashing-red light FX spawned
  on invisible `tag_origin` hosts inside the room (`PlayFXOnTag`), `Delete()`d to clear. Anchored to
  the room's own `<zone>_spawners` structs so the placement auto-tracks the docs/36 geometry shrink
  (no hardcoded coords; rooms.json stays SoT).
- **FX (verified present in this install, `<tools>\share\raw\fx\light\`):** primary
  `light/fx_light_flashing_red_factory_zmb` (the ZM Giant/factory flashing-red alarm light, self-
  flashing — no script pulse needed); alt `light/fx_glow_blink_red_5` (set `acc_lockdown_use_glow 1`).
  Both `#precache`d + listed in `zone_source/…zone` (the research's suggested FX names did **not**
  exist here — checked on disk before building).
- **Rotation:** per-run Fisher-Yates order over the 6 non-start rooms (`acc_utility::acc_rand_int`),
  indexed `(round-1) % size` (no out-of-bounds), skipping any decon-sealed room.
- **Dvars:** `acc_lockdown_on` (master, default 0), `acc_lockdown_use_glow`, `acc_lockdown_fx_z`
  (emitter height, default 140), `acc_lockdown_emitters` (max/room, default 4),
  `acc_lockdown_force_zone` (test pin to one room, default ""). **Both playtest launchers currently
  enable lockdown AND pin it to `vault_zone`** for easy testing — remove the `acc_lockdown_force_zone`
  token to resume per-round rotation.
- **Stage 2 (NOT built — needs Radiant geometry):** physically LOCKING the room's doors via new
  hidden `acc_seal_<zone>` brushes + show/solid/disconnectpaths. **Decision recorded: lock players
  IN, no escape window** (punishing by design). See docs/37 §11.
- **Build:** linker-only (`build_map.ps1 -GscOnly`); fresh `.ff` 34.25 MB, FX linked clean, only the
  pre-existing waived `mtl_origins_camo_alt` warning. xref lint green.

### Changed — Map tightening Stage 3: further ~25% squeeze + start cover (built); lab tunnels deferred (2026-06-15)

Second squeeze of the 4 free-wall rooms + start obstacles, built clean. **Lab-approach ceilings + maze
were attempted but reverted — they crash the LED lightmapper** (see gotcha below); deferred to an LED-safe pass.
Backups: `…map.pre-stage2-bak`, `…map.pre-stage3-bak`.
- **Further shrink (~25% on free walls)** via `tools/apply_room_shrink.js` (Stage-3 config): market `X[-1951,-1281]`,
  alley `X[1319.5,1989.5]`, vault `X[1119,1744]`, roof `X[-1744,-1119]` (Y is gap-locked, so the squeeze is in X;
  interiors now ~630 (market/alley) / ~585 (vault/roof) wide). All 4 footprint copies synced; validator 22 ok/0 err;
  0 crossed bounds; all spawners inside.
- **Start obstacles**: the tool now also APPENDS brushes (idempotent `{ACCADD` guids) — 2 cover blocks
  `S0 X[-680,-510] Y[-80,80]`, `S1 X[480,650] Y[60,220]` (z0-128), clear of every start spawner, to break the open
  spawn arena (the "first-room freedom" note; see docs/37).
- **Built**: cod2map (no leak, fresh navmesh) → linker; deployed `.ff` 35.9 MB. Regenerated `docs/map_design.svg`.
- **⚠️ LED-lightmapper gotcha (verified, hard-won):** radiant `-ledSilent +recompute` **crashes** (`0x80000003` /
  exit -1, no `.led` written; cod2map + navmesh are unaffected) on cover/enclosure inside the narrow 216u lab
  corridors — BOTH flush-coplanar AND 8u-off-wall maze, AND the ceilings (bottom coplanar with z256 wall tops).
  Coplanar parallel faces and thin slivers between cover and wall are the trigger; enclosed greybox tunnels get no
  sky light. Bottom-on-floor at z0 is fine (Stage-1/2 stalls). **Also: headless LED is flaky after repeated runs +
  a force-kill** — same geometry that relit fine earlier later crashed; the build uses a valid relight of this exact
  geometry. **Lab-approach difficulty is DEFERRED** to a dedicated pass (in-tunnel `light` entities + no-sliver
  cover, or author in the Radiant GUI whose relight is reliable). Disabled C*/M* coords kept in `apply_room_shrink.js`.

### Added — docs/37: "Punishing the Middle" design investigation (pre-implementation, NO code) (2026-06-15)

Investigated how to make the map **middle** (Corp + its 4 corridor mouths — the cut-vertex
band every Spawn↔Lab trip must cross) punishing enough to push players to settle at a pole
(Spawn or Lab) and only cross under risk/fear. Output of a 26-agent design workflow (5 research
deep-dives → 5 competing concepts → 3 adversarial judges each → synthesis). New doc
**`docs/37_punishing_middle_design.md`** — decision-ready, no code authored.
- **Key finding:** the map is a one-way ratchet toward the Lab (all recurring sinks are
  top-anchored; Shards are portable; Spawn is barren — no perks/box/wallbuys). A scary middle
  alone just freezes players at Lab+Roof. **The load-bearing piece is a recurring, non-portable,
  bottom-anchored reason to cross** (a new Spawn "Regulator" console whose credit is spent at the
  Lab and that resets the middle's safe window — "the trip down buys the trip back up").
- **Two directions fleshed out side-by-side** (per owner request): **A — The Contaminated Core**
  (environmental zone-state DoT cycle; clones the decon engine; no AI ⇒ sidesteps every live-AI
  crash class; can't be kited; judge avg 7.0) vs **B — The Toll Daemon** (a named mini-boss leashed
  to Corp that taxes presence; clones `_acc_boss_glitch`; a "face to fear"; avg 6.7 with 3 fixable
  issues). 3 other concepts rejected/parked (false-reuse / unproven AI / worst-stack double-count).
- **Open decisions deferred by owner:** entity-vs-environment and the reason-to-cross reward
  (free-Overclock-tier vs perk-reroll token) — both captured in docs/37 §10. Composition guards
  (decon double-count, speed-curve + 24-cap, Corp never-sealed, opt-in modifier first) documented.

### Changed — Map tightening Stage 2: alley/vault/roof/start shrunk + vault/roof double-shell removed (built) (2026-06-15)

Scaled the market pilot (Stage 1) to 4 more rooms via a new deterministic tool, then BUILT
(full cod2map64→LED→linker; no leak, navmesh fresh, `.ff` 35.9 MB). Lab + Corp held for a
dedicated pass (lab = dense PaP/perks/boss + unplaced `acc_lab_perk` machines; corp = cut-vertex
hub, ~10% cap without corridor surgery). Backups: `…map.market-bak` (pre-Stage-1), `…map.pre-stage2-bak`.
- **New tool `tools/apply_room_shrink.js`** — shrinks rooms by GUID/geometry from a per-room
  old→new footprint. Floor + perimeter walls (planes that touch a room edge) get **value-remapped**
  (edge→new edge, gap coords untouched); interior obstacles/triggers/spawners get **proportionally
  moved + clamped** inside; non-axis-aligned brushes (start's angled template cover) are **skipped**;
  gen_rooms shell brushes deleted by guid-prefix. All edits surgical (UV/winding/GUIDs preserved).
  **Regression-validated**: `--verify-market` reproduces the hand-edited+playtested market geometry
  byte-for-byte before trusting it on other rooms. (Caught + fixed 2 bugs pre-write: a loose guid
  substring match that would have deleted 2 start walls, and angled-brush distortion.)
- **Shrunk** (interior): **alley** 1160×1360→840×1096 (X-mirror of market, ~41.6%); **vault**
  1160×1160→780×1100 (east wall in 380, ~36%); **roof** mirror of vault; **start**
  ~2110×1962→2070×1240 (N/S trimmed, X fixed by the spawn corridors, ~36%). All 4 footprint copies
  synced (rooms.json + gen_zone_greybox + gen_map_design + baked `.map`); 17 spawners + box +
  obstacles relocated inside; `validate_rooms` 22 ok / 0 error.
- **vault/roof double-shell RESOLVED** (docs/36 §12): deleted the 12 overlapping `gen_rooms` shell
  brushes (guids `ACCB0010-0015`/`ACCB0020-0025`) — the rooms are now single open-top greybox boxes
  (cod2map confirms no leak). genRoomsShells dropped from `rooms.json`.
- Verified: market regression byte-exact, validator green, braces balanced (262/262), 0 crossed
  bounds, all spawners inside new interiors, cod2map clean (0 degenerate tris). Regenerated
  `docs/map_design.svg`. **Pending: in-game playtest** (docs/36 §11 per room).

### Fixed — AE4 + Ripper missing-FX linker errors (muzzle flash / shell eject) (2026-06-15)

The two Skye box guns each logged a non-fatal missing-FX `ERROR:` that another agent
flagged as a pre-existing asset-pack issue. Both root-caused and repaired install-side
(the Skye GDTs/`.efx` are game-rip, NOT repo-tracked — same Reproducibility-gap class as
the AK-74u altWeapon edit; `.acc-fx-orig` backups kept; a fresh box must re-apply):
- **AE4 muzzle flash** (`iw7_efx_plasma_muz_flash`): the weapon field points at a `.efx`
  that exists — the missing reference was a single material string buried in the effect's
  companion file `share\raw\fx\skye_efx\s1_efx\fx_s1_fusion_muz_flash_efxs.efx` (line 884,
  a `billboardSprite` element). Repointed it from the missing IW7 material to the present
  sibling `mtl_s1_plasma_muz_flash` already used by the rest of that effect. `.efx` edit →
  linker-only (no gdtdb).
- **Ripper shell eject**: a `ffx\` path **typo** in `source_data\skye_iw6_ripper.gdt`
  (line 34705, `"viewShellEjectEffect" "ffx\\…h1_shell_eject_57x28.efx"` vs the 7 correct
  `fx\\` siblings). The `.efx` and its shell xmodel are both installed — so the prior
  "Scobalula pack lacks the 57x28 variant" claim (docs/33) was wrong; only the typo broke
  it. Fixed `ffx`→`fx`, then `gdtdb /update`.
- **Verified** via a headless linker re-run: both errors gone from the log, the only
  remaining `ERROR:` is the pre-existing/waived Five-Seven PaP camo `mtl_origins_camo_alt`,
  a fresh 34.26 MB `.ff` was written, and no new FX/material warnings were introduced.
- Docs/tooling synced: docs/33 ("FIX APPLIED — AE4 + Ripper FX" + corrected exit baseline,
  now 1 waived error not 3), docs/32, CLAUDE.md, and `tools/build_map.ps1` (dropped
  `iw7_efx_plasma_muz_flash` from `$WaivedLinkerErrors` so a regression would re-surface).

### Fixed — Brutus stuck at spawn (off-navmesh z=45) + moved to the lab (user, 2026-06-15)

Brutus spawned then stood frozen. Root cause: the single `brutus_spawner_spot` struct sat at
**z=45** while every real spawner/riser/dog location in the map is at **z=0** (the floor). The NSZ
pack teleports him to the struct's **raw, unclamped** origin (`nsz_brutus.gsc:224`
`ForceTeleport(spot.origin, spot.angles, 1)`) — unlike stock AI teleports, which clamp to ground/
navmesh (`zombie.gsc:1225/:762`). So he landed ~45u **above** the navmesh; his chase goal is set
fine (`custom_find_flesh` → `v_zombie_custom_goal_pos`, consumed at `_zm_behavior.gsc:276`) but **no
path can be generated off-mesh** → frozen. Fix: relocated the struct to the **lab center
`(19 3648 0)`** (the lab `dog_location` origin — proven on-navmesh/pathable, on the floor at z=0),
which fixes the z=45 bug AND fulfills the "spawn him in the lab" request.
- **User choice: always-lab.** There is still only ONE spawn spot, so Brutus ALWAYS spawns in the
  lab. Accepted caveat: at early boss rounds (first = r4) players are usually in the start zone and
  may be too far / behind a closed door to be reached until they open the path to the lab. (The
  pack's `choose_a_spawn` picks the placed spot nearest a player; adding per-zone spots later would
  make him appear near players again.)
- `script_string` kept as the literal `"start_zone"` — that is the pack's "active from match start"
  sentinel (`nsz_brutus.gsc:94`), NOT a geometric tie to the start zone; keeps the spot always
  available so a spawn always happens even before the lab is unlocked.
- **BUILT 2026-06-15** via the new `tools/build_map.ps1` (full geometry pipeline: sync → cod2map64
  [cwd=bin, navmesh regenerated] → radiant LED → linker). Fresh 34.26 MB `.ff` written; the only
  linker errors were the two pre-existing user-waived material warnings (`mtl_origins_camo_alt`,
  `iw7_efx_plasma_muz_flash`). Ready to test (`tools/run_game.ps1`; test boss spawns from round 2).
- File: `map_source/zm/zm_abandoned_cyber_city.map` (struct at the `brutus_spawner_spot` entity).
  Diag harness unchanged: `acc_brutus_debug 1` still prints target/goal/dist/moved if it recurs.

### Added — `tools/build_map.ps1`: one-command headless map build (2026-06-15)

Agents kept punting "compile the geometry" to the user even though the whole pipeline is
CLI-scriptable on this box. `build_map.ps1` closes that gap: `.\tools\build_map.ps1` runs
asset-gate → sync → cod2map64 (BSP+navmesh, **cwd=bin** so the navmesh actually regenerates) →
Radiant LED → linker → verifies a fresh `.ff`; `-GscOnly` is the linker-only fast path for
script/zone/csv changes; `-Run` chains `run_game.ps1`. Auto-detects the Mod Tools root (via
`bin\modlauncher.exe`), refuses to build stale (hashes deployed `.map` vs repo after sync), treats
the silent navmesh-abort string as fatal. **Build success = a FRESH `.ff` was written, NOT the
linker exit code** — the linker prints `ERROR:` for missing-but-substituted assets (the two waived
camo/FX materials), exits nonzero, yet still packs a valid `.ff`; the script waives those and only
fails when no fresh `.ff` lands. File: `tools/build_map.ps1`.

### Changed — Map tightening Stage 1: market_zone shrunk ~41.6% + leftover gun chalk removed (2026-06-15)

First geometry edit of the docs/36 overhaul (the market_zone pilot), plus a requested cleanup.
**Needs a full geometry rebuild** (cod2map64 [cwd=bin] → radiant LED → linker) — not linker-only —
then an in-game playtest (docs/36 §11 checklist). Backup: `map_source/zm/zm_abandoned_cyber_city.map.market-bak`.
- **market_zone shrunk** outer `X[-2481,-1281] Y[200,1600]` → `X[-2161,-1281] Y[360,1496]` (interior
  1160×1360 → 840×1096 = **41.6% smaller**). Used the **non-flush variant** (docs/36 §10): only constant-axis
  plane values edited, **no brush deletions** — the EAST wall + both corridor gaps (`Y[400,656]` start,
  `Y[1200,1456]` corp_w) are untouched; WEST/NORTH/SOUTH walls moved in, with bw35/bw37 kept as 20u stubs
  so the 256u corridor mouths stay full-width.
- **Propagated to all 4 footprint copies** (rooms.json SoT + `gen_zone_greybox.js` + `gen_map_design.js` +
  baked `.map` floor) — `validate_rooms.js` green (26 ok / 0 error).
- **Relocated inside the new footprint** (origins are .map-authoritative): 4 risers `(-2066,560)/(-2066,1296)/
  (-1376,560)/(-1376,1296)`, dog `(-1721,1130)`, MagicBox both entities `(-1721,1340)`, reflection probe
  origin `(-1721,928)` (size left — cosmetic), 3 stalls shifted +160u east to fit (`X[-2021,-1861]/
  [-1801,-1641]/[-1581,-1421]`). Zero GSC coupling (market referenced only by name).
- **Removed 5 orphaned wallbuy chalk decals** (the gun outlines left on walls after the wallbuys were
  deleted): `t7_zm_chalk_buy_` icr1/bowie/drakon/shiva/frag meshes (guids `ACCB0020/0025/0026/0027/0028`,
  `contents nonColliding` → visual-only). Removed by GUID via a brace-balanced pass; grep confirms 0 chalk
  remain, `.map` braces balanced (274/274), worldspawn boundary intact.
- Files: `map_source/zm/zm_abandoned_cyber_city.map`, `source_data/rooms.json`, `tools/gen_zone_greybox.js`,
  `tools/gen_map_design.js`. Pending: build + playtest (then regen `docs/map_design.svg`).

### Fixed — PaP tier-ups (2→5) now replay the first-pack pullout/re-cock (user, 2026-06-15)

The first pack visibly swaps the gun + plays the "pulled out / needs re-cocking" draw;
tier-ups 2→5 showed nothing. Root cause in `_acc_pap_levels::replay_pack_draw`: a deploy
animation only plays when you `SwitchTo` an asset that ISN'T the one currently deployed. The
first pack animates because it swaps a different asset in (base → `_up`). The tier-up re-gave
the SAME held weapon — `TakeWeapon(w)` + `GiveWeapon(w)` + `SwitchToWeapon(w)` in one frame
never changes the current weapon, so the give re-adds before the take resolves and the
switch-to-already-current no-ops. Immediate-vs-non-immediate was a red herring (both no-op on
the equipped weapon). Fix (user: "do the twin gun swap, don't hide the animation"): blip to the
un-packed base form and back. `increment_is_drinking()` + `disable_player_move_states()` wrap
the whole swap (exactly like the stock knuckle crack / `replay_perk_drink`): give base,
`SwitchToWeaponImmediate(base)`, **wait two server frames** so base actually becomes current
(one frame collapses to a no-op), then `SwitchToWeaponImmediate(w)` back — base→packed is a real
deployed-asset change, so the packed gun pulls out. The earlier attempts swapped to the player's
OTHER gun for two reasons, both fixed here: **(1) reconcile interference** — our switches raise
`weapon_change`, which woke `acc_weapon_variants::reconcile()` mid-swap and, with a second
primary present, churned the player onto the other gun; the `is_drinking` wrap makes reconcile
defer (it early-returns while `is_drinking>0`). **(2) taking the packed gun** — the old code did
`TakeWeapon(w)`+`GiveWeapon(w)` to re-give it "fresh," and any frame where `w` wasn't current let
the engine auto-switch; now `w` is **never taken** (keeps camo + ammo), and the only transient is
`base`, removed only once `w` is current again — nothing to auto-switch onto. Gated by
`acc_pap_tier_anim` (default 1). **Needs in-game confirm** — a brief flash of the un-camo'd base
before the packed pulls out is expected; watch the akimbo/dual guns. Tune knobs: 2-frame base
dwell, or drop `disable_player_move_states` if the input lock feels like a hitch.

### Fixed — Akimbo/`_zm` guns couldn't Pack-a-Punch (CSV upgrade name) (user, 2026-06-15)

AK-74u, PDW, and M1911 silently refused to PaP. Root cause: their `zm_levelcommon_weapons.csv`
`upgrade_name` carried a `_zm` suffix (`t5_ak74u_up_zm`, `s1_pdw_rdw_up_zm`,
`s2_m1911_rdw_up_zm`). The engine maps a BARE CSV upgrade name onto the `_zm` weapon asset
itself (the working guns — Paladin/PPSH/Nail Gun and the Ripper — all use a bare `_up` in
CSV while their asset is `_up_zm`), so a `_zm` already in the CSV breaks the lookup →
`get_upgrade_weapon` returns none → `packed_form` is none → first-pack bails with no charge.
Fix: drop the `_zm` from the three CSV upgrade names (keep `_rdw`): `t5_ak74u_up`,
`s1_pdw_rdw_up`, `s2_m1911_rdw_up`. Zone weapon lines keep the `_zm` asset names (unchanged).
A temp `PaPDIAG` print in `_acc_pap_levels::acc_pap_validate` (now covers all three) stays
until confirmed in-game, then gets removed.

### Changed — GLOBAL gun mag + reserve ammo −30% via one const (user, 2026-06-15)

Tighter ammo economy applied **globally to every gun and every form** — base, PaP (`_up`),
and all recoil/fire/reload/ammo twins — driven by a SINGLE constant (`FACTOR = 0.70`, was
0.80). One number rescales all 12 guns at once; PaP keeps its relative ammo edge but the
whole economy is 30% tighter. Mechanic: in BO3 GDTs `maxAmmo`/`startAmmo` are reserve
MAGAZINE counts (6–12), so in-game reserve = `maxAmmo × clipSize`. Reducing **`clipSize`
alone by ×FACTOR** drops BOTH mag and reserve by 30% in one edit, and the Armory +25% "ammo"
twin (`maxAmmo×1.25`) then yields +25% of the *reduced* reserve automatically. `maxAmmo`
untouched. **Why a build-time const, not a live dvar:** mag size + reserve cap are baked into
the fastfile (the engine reads `clipSize` off the compiled weapon asset), so there is no
runtime lever — retune = change `FACTOR`, re-run, rebuild. (Stock weapons — laststand
`pistol_standard`, knife, grenades — aren't Skye GDTs, untouched.)

New tool `tools/reduce_base_ammo.js`: reduces `clipSize ×FACTOR` (round, min 1) on **every**
weapon entry across the 12 box-gun GDTs + the twin GDT (266 fields). Idempotent (snapshots
`*.acc-ammo-orig` on first run, always reduces from that snapshot — never compounds, so the
0.80→0.70 retune is exact off the original; REVERT = restore snapshots + `gdtdb /update`).
Install-side, not repo-tracked; must run AFTER `apply_recoil_overhaul.js`. Examples base→
(clip / reserve = maxAmmo×clip): AK-47 30/240→21/168, AK-74u 20/160→14/112, Five-Seven
20/120→14/84, PPSH 35/245→25/175, Paladin 5/60→4/48, PDW 15→11 (PaP forms also ×0.70).
gdtdb re-baked, linker clean at the 3-waiver baseline, FF 34.7 MB.
**Pending: in-game confirm mag + reserve dropped ~30%.**

### Changed — Glitch Stalker mini-boss refinements (round 3, stock skin, faster, no HUD) (2026-06-15)

Iterated the Glitch Stalker (`_acc_boss_glitch.gsc`; original entry further down) per playtest:
- **Stock zombie SKIN (body + head).** Re-skins the promoted (charred) zombie to the stock "Giant"
  body + head at runtime so it stands out from the charred horde: `host SetModel("c_zom_der_zombie_body1")`
  + `Detach("c_zom_dlc4_zombie_charred_head")` + `Attach("c_zom_der_zombie_head1")` (the gdtDB-registered
  name — the raw bin `c_zom_der_head_1` has NO xmodel GDT entry and fails to link). Two `xmodel` zone
  lines; both pack. Same-skeleton swap = anims/gibs intact (verified via two skin workflows).
  `acc_glitch_stock_skin` (default 1). No external pack — both are stock t7_characters models.
- **Cadence:** first spawn **round 3** (was 12), **×2 per round** (`acc_glitch_count`). Brutus moved to
  first **round 4** (`_acc_boss.gsc`, `(round-first)%interval`). The real "never spawned" root cause was
  fixed: the dev/test spawn reads `acc_dev` with **default 1** to match the entry script (acc_dev is
  never `SetDvar`'d), since the granular `+set` flags weren't reaching the game's launch.
- **HP = 3× the round's normal zombie health** (`acc_glitch_hp_mult`, default 3) — replaces the old
  fixed 50k base + per-round curve; auto-scales with the round. The dev/test HP override (2500) and
  the `acc_glitch_hp`/`acc_glitch_hp_per_round` dvars were removed.
- **+15% move speed** (`acc_glitch_speed_mult`): locks the horde's per-round gait × 1.15 with an
  `acc_boss_custom_speed` flag so the global `_acc_zombie_speed` keep-alive skips it (no writer fight).
- **Teleport 3× more frequent** (blink cd 6–10s → 2–3.3s). **Removed the health bar** (no
  `acc_boss_spawned` notify) **and the over-head purple box** — the stock skin is the only tell now.
- **75% size: NOT done (would crash).** `SetScale` on a live zombie AI is the confirmed `0xC0000005`
  crasher (Brutus isolation proves it's SetScale-on-live-AI, not Brutus-specific); a smaller body needs
  a pre-scaled model asset, not a runtime call.
- Build: clean compile, both skin xmodels packed, only the 2 long-standing cosmetic material warnings.
  docs/11 + docs/34 + the play scripts updated.

### Added/Changed — Corpse linger, PaP tier animation, Ronan power-up HUD icons, Brutus diag (2026-06-15)

Four user-requested changes this session (all GSC/LUI/image — linker-only, no BSP; docs/34 updated):

- **Zombie corpses linger ~5s** instead of vanishing on death. `_acc_corpse_cleanup.gsc`
  threads a per-corpse timer off the death callback (`zm_spawner::register_zombie_death_event_callback`,
  fired on the dying actor at `_zm_spawner.gsc:2344` — which persists as the on-ground corpse),
  `NotSolid()`s the body IMMEDIATELY (so the fresh corpse never blocks movement/pathing — the real
  problem), keeps it VISIBLE through the window, then `Ghost()`s it. New dvar `acc_corpse_linger_sec`
  (default `5`, `0` = old instant removal). NOTE: under a heavy horde the engine's corpse cap may
  recycle a body before the timer (the `isdefined(self)` guard handles that) — the timer is an upper
  bound, not a guarantee.

- **Every PaP tier replays the first-pack "gun comes out" draw.** `acc_do_tier_up` →
  `replay_pack_draw()` mirrors stock PaP's give-back (`TakeWeapon`→`GiveWeapon`→
  **`SwitchToWeapon`** non-immediate — the immediate variant plays NO animation, which was
  the first-attempt bug). New dvar `acc_pap_tier_anim` (default `1`).

- **Ronan power-up HUD icons** (Insta-Kill / Double Points / Fire Sale). New 3-bit
  `accPowerupMask` clientuimodel field (`_acc_lui.gsc`+`.csc` lockstep), `powerup_state_watch`
  reads stock `zombie_vars` (insta-kill = team-scoped `zombie_insta_kill`; double-points/
  fire-sale = `*_on`), `CoD.AccPowerupBar` LUI widget draws the icons top-center while active.
  3 GDT `image` entries + 3 zone lines + 3 staged PNGs (`i_acc_powerup_{instakill,double,sale}`).
  Adversarially reviewed (1 blocker fixed: insta-kill var name). Build packs all 3 images,
  baseline exit. **World-drop model reskin NOT done** — needs an APE-authored xmodel from the
  PNGs (same-name material override is blocked by missing shader source, docs/29 §14).

- **Brutus "frozen statue"**: added off-by-default `brutus_spawn_diag` (`acc_brutus_debug 1`)
  to pin the cause in one run + a gated `brutus_force_resume` (`acc_brutus_force_resume 1`)
  fallback. Most likely cause is stale navmesh / spawn spot off-mesh (room-shrink) → needs a
  navmesh regen, not a script fix; the `ignoreall` theory was ruled out.

### Changed — Box-gun balance audit: Paladin/PPSH cut, AE4 buffed (2026-06-15)

Full 12-gun balance audit (per-gun GDT stats vs the additive damage model + solo health
curve; workflow + adversarial synthesis). Three guns were off-tier; the other 9 confirmed
in the ~495–575 effective-DPS band (autos) or as intentional anchors (pistols/shotgun).
Applied to `acc_weapon_balance_mult` in `_acc_damage.gsc`:
- **Paladin HB50** `t8_paladin_hb50`: the "crazy strong" cause was deeper than a missing
  balance entry — the Skye rip ships **MP-inflated hit-location mults**: `locTorso` 5.0
  (PaP 9.0), limbs 4.0 (8.0), `locHead` 7.5 (10.0). The engine bakes these into `damage`
  before our script sees it, so at ×1.0 even a **body/limb** shot one-shot to ~r23 and a
  **headshot** to ~r33 (the audit missed this — it assumed body=base). **Two-part fix:**
  (1) added a ×0.80 balance entry; (2) **normalized the GDT's loc\* mults to 1.0** install-side
  (`skye_t8_paladin_hb50.gdt`, base + `_up`; backup `.acc-loc-orig`; not repo-tracked). With
  loc=1.0 the gun obeys the additive model like every other gun (body = base, headshot = our
  2.0 map mult only), so ×0.80 → **body r7 / headshot r14 / HS+Deadshot r20**, PaP+Cyberware
  push higher. Normal guns ship `locTorso`=1.0 already (AK-47/ASM1 verified), so only the
  Paladin needed this.
- **PPSH-41** `s4_ppsh41`: **0.36 → 0.20.** The 0.36 was set against a wrong raw-DPS
  assumption (1400); the real GDT is 155 dmg @ 952 RPM = **2460 raw**, so 0.36 = 885 body
  DPS (+77% over band). 0.20 = 492 DPS, in band. (Was quietly the strongest auto.)
- **AE4** `s1_ae4`: **0.22 → 0.31.** 0.22 = 293 DPS (−41% under band); 0.31 = 442 DPS, band
  floor as the slowest-RPM AR. (No GDT penetration field → no penetration discount.)
- **Nail Gun** `t9_nail_gun`: a 2nd hidden loc offender found by the cross-check — GDT
  shipped **`locTorso` 3.0** (limbs 3.0, head 6.0), so real body DPS was `250×3×0.24/0.118 =
  ~1525` (3× over band), not the 508 the audit computed. **Normalized loc\* to 1.0** install-
  side (head → 5.0 to match peer autos; backup `.acc-loc-orig`); existing ×0.24 now lands the
  true 508 DPS, mult unchanged.
- **Loc-mult sweep:** checked all 12 — only the Paladin (5.0–9.0) and Nail Gun (3.0) had
  inflated torso/limb mults; the other 10 ship `locTorso` 1.0 (Tac-19 1.5, left as a close-
  range shotgun anchor), confirming the audit's body-DPS math + the PPSH/AE4 changes are
  correct. docs/33 gained a "check the GDT `loc*` mults, not just `damage`" trap.

GSC mult edits + 2 install-side GDT loc-normalizations (gdtdb re-baked); `lint_gsc_xref`
green, linker clean at the 3003000 waiver baseline, FF 34.6 MB. **Pending: in-game feel
check, esp. the Paladin.**

### Changed — Every PaP tier now replays the first-pack "gun comes out" draw (2026-06-15)

Reverses the 2026-06-14 "no animation on any tier" decision per user request: the first
pack visibly fresh-equips a different-model gun (the `_up` form + gold camo), but tier-ups
2→5 keep the SAME asset, so they previously upgraded silently. `acc_do_tier_up` now calls a
new `replay_pack_draw( w )` that mirrors the STOCK PaP give-back — `TakeWeapon` →
`GiveWeapon` → **`SwitchToWeapon`** (non-immediate), carrying clip+reserve across — so the
held gun visibly lowers + raises on every tier. (First attempt used
`SwitchToWeaponImmediate`, which plays NO raise/lower — that's exactly why recoil-twin swaps
are invisible — so a same-model tier-up showed nothing; corrected to the non-immediate
switch per `_zm_pack_a_punch.gsc:823-831`.) Still no machine float / take-back / weapon-lock
on any tier. New dvar **`acc_pap_tier_anim`** (default `1`; set `0` for instant,
animation-free tier-ups). docs/34 updated.

### Brutus "spawns then stands frozen" — added an off-by-default spawn diagnostic (2026-06-15)

User report: Brutus spawns but stands as a frozen statue (no animation, never faces
players). Static trace ruled OUT the obvious `ignoreall`-never-cleared theory (it's in the
base NSZ pack unchanged, and the stock behavior tree honors Brutus's custom goal regardless
of `ignoreall`). "No animation, never faces" means the behavior tree/ASM isn't ticking —
i.e. stuck in the `AnimScripted(%brutus_spawn)` state or anims didn't load — NOT a simple
navmesh-unreachable (which still faces + idles). Added **`brutus_spawn_diag()`** (dvar
**`acc_brutus_debug 1`**, default off) printing target/goal/distance/movement once a second
for ~25s after each spawn so the cause is pinned in one run. Fix follows the diagnosis;
likely suspect given the recent room-shrink: stale navmesh / a `brutus_spawner_spot` off the
mesh (regen navmesh per CLAUDE.md).

### Changed — Zombie corpses now linger ~10s instead of vanishing on death (2026-06-15)

User request: dead zombies were disappearing the instant they were killed (`_acc_corpse_
cleanup` immediately `Ghost()`+`NotSolid()`-ed bodies on the death event). They now stay on
the ground for a configurable window before being hidden + de-collided. The module threads a
per-corpse timer off the death-event callback; after the window it `Ghost()`+`NotSolid()`s
the body and leaves it for the engine's corpse recycling. Bosses/mini-bosses still skipped.
New dvar **`acc_corpse_linger_sec`** (default `10`, set `0` for the old instant removal)
replaces the boolean `acc_instant_corpse`; docs/34 updated. NOTE: during the linger window
the body is solid again, so it can intercept shots like stock corpses do — flag if a
non-blocking-but-visible variant is wanted.

### Fixed — Box-gun sounds: complete fire + foley aliases for all 6 silent/incomplete guns (2026-06-15)

User reported guns appeared but had no sound. Root cause: Skye packs ship wavs but **no
aliases**, and `gen_box_weapon_sounds.js` authored **fire only** — so the 3 newest guns
(Nail Gun, PDW, M1911) had **zero** aliases (silent), and Paladin/PPSH/AK-74u had fire but
**no foley** (no reload/bolt/charge). The GDTs reference `wpn_<sid>_*` tokens where `<sid>`
is the sound-folder id (drops underscores: `t9_nail_gun`→`wpn_t9_nailgun`,
`t8_paladin_hb50`→`wpn_t8_paladinhb50`); unmatched tokens resolve to silence.

Rewrote `tools/gen_box_weapon_sounds.js` to author **both fire and foley**: fire =
`wpn_<sid>_shot_plr/_npc` (one row per shot-variant wav → engine randomization) +
`wpn_<sid>_pap_shot_*`; foley = one alias per wav auto-scanned from
`sound_assets\skye_ports\<sid>\foley\` (alias name = wav basename = the GDT token, which
also catches cross-named wavs like AK-74u's `wpn_t5_tishina_bolt_back`). Idempotent by
exact alias-name. Generated **157 rows (100 fire, 57 foley)** for 6 guns —
paladinhb50(8), s4_ppsh41(73), t5_ak74u(16 +2 tishina), t9_nailgun(23), s1_pdw(8),
s2_m1911(27: base+ldw+rdw akimbo foley). CSV 102 cols, 0 malformed, 224 rows. Deployed to
`share\raw\sound\aliases\`; rebuild grew the loaded bank `.all.sabl` **11.2 → 13.55 MB**,
zero sound/wav errors. **Pending: in-game confirm fire + reload audio on every box gun.**
(Unrelated non-fatal: 2 missing-image errors `i_acc_perk_phd_base/_mega` from a separate
zone change — PhD perk-shader GDT has 0 phd entries; deploy_perk_shaders gap, not sound.)

### Changed — Every PaP tier now replays the first-pack "gun comes out" draw (2026-06-15)

Reverses the 2026-06-14 "no animation on any tier" decision per user request: the first
pack visibly fresh-equips a different-model gun (the `_up` form + gold camo), but tier-ups
2→5 keep the SAME asset, so they previously upgraded silently with no on-screen feedback.
`acc_do_tier_up` now calls a new `replay_pack_draw( w )` that Take→re-Give→
`SwitchToWeaponImmediate`s the held weapon (carrying clip+reserve across) so the engine
treats it as a fresh equip and re-draws it — matching the first-pack feel. Still no machine
float / take-back / weapon-lock on any tier. New dvar **`acc_pap_tier_anim`** (default `1`;
set `0` for instant, animation-free tier-ups). docs/34 updated.

### Brutus "spawns then stands frozen" — added an off-by-default spawn diagnostic (2026-06-15)

User report: Brutus spawns but stands as a frozen statue (no animation, never faces
players) instead of charging. Static trace ruled OUT the obvious `ignoreall`-never-cleared
theory (it's in the base NSZ pack unchanged, and the stock behavior tree honors Brutus's
custom goal `v_zombie_custom_goal_pos` regardless of `ignoreall`). "No animation, never
faces" means the behavior tree/ASM isn't ticking — i.e. stuck in the `AnimScripted(%brutus_
spawn)` state or his anims didn't load — NOT a simple navmesh-unreachable (which still faces
+ idles). Added **`brutus_spawn_diag()`** (dvar **`acc_brutus_debug 1`**, default off) that
prints target/goal/distance/movement once a second for ~25s after each spawn so the cause is
pinned in one run without a rebuild. No behavior change yet — fix follows the diagnosis (see
the function's comment for the decision tree). Likely suspect given the recent room-shrink:
stale navmesh / a `brutus_spawner_spot` now off the mesh — regen navmesh per CLAUDE.md.

### Changed — Zombie corpses now linger ~10s instead of vanishing on death (2026-06-15)

User request: dead zombies were disappearing the instant they were killed (the
old `_acc_corpse_cleanup` behavior was an immediate `Ghost()`+`NotSolid()` on the
death event). They now stay on the ground for a configurable window before being
hidden + de-collided. `_acc_corpse_cleanup.gsc` threads a per-corpse timer off the
death-event callback (`zm_spawner::register_zombie_death_event_callback`); after
the window it `Ghost()`+`NotSolid()`s the body and leaves it for the engine's
corpse recycling. Bosses/mini-bosses are still skipped (they own their death
visuals). New dvar **`acc_corpse_linger_sec`** (default `10`, set `0` for the old
instant removal) replaces the boolean `acc_instant_corpse`; docs/34 updated.
NOTE: during the linger window the body is solid again, so it can intercept shots
the way stock corpses do (the old module existed partly to stop that) — flag if a
non-blocking-but-visible variant is wanted.

### Added — Box guns: the remaining 4 (Nail Gun, PDW, M1911, AK-74u), all twin-less (2026-06-15)

The mystery box is now the full 12-gun roster. The four previously-benched guns were
cleared by a per-gun anomaly scan (one investigator + one adversarial GDT re-verifier
each) and added twin-less. Build clean — FF **34.5 MB**, **0** new errors (errorlog
byte-identical to the prior build; none of the 4 gun ids appear), `_zm_zm` refs **0**:
- **Nail Gun** (`t9_nail_gun`, CW projectile AR): altWeapon empty, PaP `_up` resolves;
  twin-less by type (projectileweapon). Balance ×0.24, family ar.
- **PDW-57** (`s1_pdw`, AW): base single-wield, PaPs to akimbo. Zoned all 3 forms
  (`s1_pdw` + `_rdw_up_zm` + `_ldw_up_zm`) so the left hand doesn't dangle. ×0.33, smg.
- **M1911** (`s2_m1911`, WWII): base bullet pistol, PaPs to akimbo **explosive**
  (Mustang-and-Sally, 7000 dmg + splash). Zoned all 3 forms. **Balance split**: the
  broad `IsSubStr("s2_m1911")×3.5` base buff would scale the explosive PaP to ~24,500/
  shot (acc_weapon_balance_mult applies to ALL damage incl. explosive), so a specific
  `s2_m1911_rdw`/`_ldw` → ×0.40 line was added ABOVE the base match (7000×0.40 = 2800
  direct, one-shots ~r20; tune in playtest). Base stays ×3.5. Family pistol.
- **AK-74u** (`t5_ak74u`, BO1): the Class-B launcher altWeapon crash, fixed
  **install-side** — blanked the PaP form's `altWeapon t5_ak74u_launcher_zm` → `""` in
  `skye_t5_ak74u.gdt` L10416 + `gdtdb /update`, killing the `t5_ak74u_launcher_zm_zm`
  Com_ERROR. Vestigial GL launcher never zoned. ×0.22, smg.

docs/33 "Failure modes" gained the applied-fix recipes (akimbo zone-all-forms, explosive
balance split, AK-74u GDT blank) and a corrected exit-code baseline (3003000 = 3 waived
errors + 3 warnings, all on existing guns/cosmetic). **Pending: in-game boot + PaP test.**

### Added — Box guns: Paladin HB50 + PPSH-41 (twin-less); gun-add failure modes documented (2026-06-15)

Second box-gun wave. Two new Skye-ported weapons shipped into the mystery box:
**Paladin HB50** (BO4, sniper `t8_paladin_hb50`) and **PPSH-41** (Vanguard, SMG
`s4_ppsh41_base`) — both **without recoil/perk twins** (the twin matrix stays at the
original 5 guns, 110 twins). They fire, PaP, sound (78 generated aliases), and carry
their ability/overclock family; they just use one recoil profile across perk states.
Box pool + zone weapon lines updated; balance lines in `_acc_damage.gsc`; families in
`_acc_overclocks.gsc`. Build clean (FF 33.8 MB, 0 weapon/altWeapon errors).

Four candidates **benched** with documented reasons (see below): AK-74u, PDW, M1911,
Nail Gun.

### Documented — Three boot-crash classes for box-gun adds (docs/33 "Failure modes")

Adding the 6-gun wave surfaced three independent boot-crash classes; docs/33 now has a
**"Failure modes — boot crashes"** section + triage checklist, and the box/zone
comments cross-reference it:
- **A. Twin weapon-count cap** — twins are full weapon registrations; past ~230 the
  engine **silently access-violates at load** (`0xC0000005` at
  `blackops3.exe+0x25DF24E` in `BG_Cache_RegisterWeapon`, no linker/console error).
  Live: 230 twins boot, 368 crash. Mitigation: new guns ship twin-less (2 slots).
- **B. Attachment `altWeapon` double-`_zm`** — the AK-74u's vestigial launcher
  attachment resolves to `t5_ak74u_launcher_zm_zm` → hard `Com_ERROR` on launch.
  Pre-screen every GDT for a non-empty `altWeapon` (PPSH/Paladin both empty → safe).
- **C. Twin-tool exclusions** — Nail Gun is a `projectileweapon` (twin tool aborts);
  M1911/PDW PaP to akimbo (`_rdw`/`_ldw`, breaks the perk-swap + `_up` substring
  assumptions).
- **Process rule:** add ONE gun at a time, then sync→build→boot-test before the next —
  a black-screen crash across 50+ edits is not bisectable after the fact.

### Changed — CC0 audio WAVs tracked in-repo + auto-deployed (2026-06-15)

The two CC0 audio WAVs (`acc_main_theme`, `acc_amb_city_bed`) are now committed at
`sound_assets/acc/` (48k/16-bit), so a fresh clone has them — unlike the gitignored
game-rip packs. `tools/sync_to_modtools.ps1` now deploys `repo/sound_assets/` → the
tools-root `sound_assets/` (**COPY, not mirror**, so the externally-installed
`skye_ports/` / `_NSZ/` rip packs in the tools tree are never purged). `.gitignore`
guards against accidentally committing those rip ports if they land under
`sound_assets/`. Sources credited in CREDITS.md (new "Current shipped audio assets
(CC0)" table).

### Added — Custom main theme (CC0) + stock zombies music disabled; ambient bed live (2026-06-15)

First real custom audio in the map (all CC0, Workshop-safe). In `_acc_atmosphere.gsc`:
- **Stock zombies music DISABLED** (user request): `init()` sets
  `level.bonuszm_musicoverride = true` — `music_shared::setMusicState` early-returns
  while that flag is set (music_shared.gsc:25-26), so no round/intro `musicCmd` is
  ever sent. (Remove the one line to restore stock music.)
- **Custom main theme** plays ONCE at game start: `apply_music()` waits on
  `initial_blackscreen_passed`, then `zm_utility::play_sound_2D("acc_main_theme")`
  (verified: `really_play_2D_sound` blocks on `PlaySoundWithNotify` until the full
  ~117 s track ends — no cutoff). Track = **Joth "Cyberpunk Moonlight Sonata" (CC0)**.
  Dvar `acc_music_on` (default 1) mutes it.
- **Ambient bed** (`acc_amb_city_bed`, dvar `acc_amb_on` default 0) now has its WAV
  (Joth "Infestation in the Control Room", CC0).

Assets: both WAVs converted to **48000 Hz / 16-bit PCM** (the theme via a downloaded
static ffmpeg for the MP3 decode; the bed via a small C# resampler from 44.1k) and
placed at `sound_assets/acc/{music,amb}/`. New alias rows
(`acc_main_theme` = `BUS_MUSIC`/`IsMusic`/`STREAMED`/`2d`, `acc_amb_city_bed` =
`BUS_FX`/`LOOPING`/`2d`) in `sound/aliases/acc_audio.csv`, now **registered in the
`.szc`**. `lint_gsc_xref` green; synced to Mod Tools. **Needs a Launcher Compile +
Run to build the soundbank and verify in-game.** (CC0 sources to log in CREDITS.md
before any Public ship. The 48k WAVs live only in the tools `sound_assets/` tree so
far — repo-tracking of the CC0 audio is a follow-up.)

### Added — +6 box weapons: PPSH-41, AK-74u, PDW, Nail Gun, Paladin HB50, M1911 (2026-06-15)

Six Skye weapon-port imports added to the Mystery Box pool (user request), each balanced against the
existing box anchors (raw DPS = `damage/fireTime` from the GDT; targeted ~500 eff-DPS band):

| Gun | Asset id | Class | balance mult | PaP form | Twins |
|---|---|---|---|---|---|
| PPSH-41 | `s4_ppsh41_base` | SMG | 0.36 | `_base_up` | ✅ |
| AK-74u | `t5_ak74u` | SMG | 0.22 | `_up_zm` | ✅ |
| PDW-57 | `s1_pdw` | SMG | 0.33 | akimbo `_rdw/_ldw_up_zm` | ⛔ |
| Nail Gun | `t9_nail_gun` | AR (projectile) | 0.24 | `_up` | ⛔ |
| Paladin HB50 | `t8_paladin_hb50` | sniper | 1.0 (uncut) | `_up` | ✅ |
| M1911 | `s2_m1911` | pistol | **3.5 (BUFF)** | akimbo `_rdw/_ldw_up_zm` | ⛔ |

- **M1911 is buffed, not cut** — its Skye port is MP-tuned at `damage 20`; x3.5 brings it to ~70 eff/shot
  (≈ Five-Seven per-shot). The only `>1` entry in `acc_weapon_balance_mult`.
- **Paladin uncut** — full 1000-dmg one-shot sniper, like Locus/Drakon.
- **Twins skipped** for PDW + M1911 (PaP to akimbo/dual-wield) and Nail Gun (a `projectileweapon` -
  the twin generator only handles `bulletweapon.gdf`). Same exclusion class as the convertible Ripper.
- Files: `_acc_map_randomizer.gsc` (box pool), `zm_levelcommon_weapons.csv` (rows), `*.zone` (weapon
  lines + 368 twin `weaponfull` lines auto-written by the recoil tool), `_acc_damage.gsc` (balance),
  `_acc_overclocks.gsc` (families), `tools/apply_recoil_overhaul.js` GUNS[] + prefix regex widened to
  `s[0-9]_/t[0-9]_/iw[0-9]_`, `_acc_weapon_variants.gsc` `variant_guns()`.
- Assets: each gun's pack TARGET-extracted into the Mod Tools (`model_export/skye_ports/<id>` + each
  pack's `<prefix>_wepcommon/` shared attachment/optic folder + GDTs) + `gdtdb /update`. ~1.9 GB total.
- **TODO:** custom sound aliases not yet authored (`sound/aliases/acc_skye_box_weapons.csv`) - the guns
  fire with fallback/no custom audio until added. AK-74u under-barrel M203 launcher works once
  `t5_wepcommon` was pulled. Build clean of new-gun errors (residual log = pre-existing waived noise).

### Added — Map-tightening overhaul: research (docs/36) + Stage 0 tooling (2026-06-15)

Kickoff for the requested "tighten the map + add tight spaces to make it harder" overhaul — the
unstarted **docs/29 §6** ("Halve room sizes + add obstacles", HIGH RISK). Output of a 9-agent
research workflow (6 parallel inventory readers → 2 adversarial verifiers → synthesis), then the
first build-safe slice. **User decisions:** aggressive **~40-50%** shrink, **all 7 zones**, **Stage 0
tooling first**, **geometry-only** (no difficulty re-tune yet). *(Numbered docs/36 — docs/35 was
claimed concurrently by the sound plan.)*

**Research — new doc `docs/36_map_tightening_research.md`:** verified per-zone as-built layout
(interior AABBs, doors, ~40 entity origins, spawners), the coupling/risk map, interaction with the
(geometry-blind) difficulty stack, a build-gated staged plan, per-zone tightening proposals, and
the open decisions. Verified corrections: room walls are **20u/256u** (not the brief's 16u/128u);
Start has **one wall-gap per side** (no direct Spawn↔Corp edge — `zm_abandoned_cyber_city.gsc:427-434`);
the **only** literal world coord in production GSC was `_acc_perk_info.gsc:240` `(-700,3700,7.5)`.
**New finding (corrects the dossiers): vault/roof have TWO overlapping room shells** — the
`gen_zone_greybox` outer room *and* a larger `gen_rooms.js` shell (`// ACC room shell` brushes,
different door-gap Y-bands) — a conflict to reconcile when those zones are tightened.

**Stage 0 — tooling (no geometry change):**
- **`source_data/rooms.json`** — canonical source-of-truth for the *duplicated* geometry only
  (7 outer footprints, 20u/256u wall dims, 8 corridors, wall-gaps, the vault/roof gen_rooms
  shells, PaP origin). Entity origins stay authoritative in the `.map` (they're hand-tuned, e.g.
  market dog y=1100 ≠ the generator's computed y=900).
- **`tools/validate_rooms.js`** — asserts the 4 footprint copies (`gen_zone_greybox`,
  `gen_map_design`, baked `.map` floor slabs via a generic axis-aligned brush-AABB parser, and
  the `gen_rooms` shells) + the 2 PaP-origin literals all agree with the SoT. Wired into
  `tools/preflight_windows.ps1`. Current: **26 ok / 0 error**, 2 warns (the known vault/roof
  double-shell).
- **`tools/gen_rooms.js`** — added the missing **re-run guard** (it writes the `.map` in place
  and had none → would double-inject the shells; now refuses if `// ACC room shell` is present).
- **`scripts/.../_acc_perk_info.gsc`** — PaP origin now read **live** from
  `GetEntArray("pack_a_punch","script_noteworthy")[0].origin` (mirrors `_acc_pap_levels.gsc:80`),
  literal kept only as a fallback → the silent-break-on-PaP-move literal is fixed.
- Verified: validator green, gen_rooms guard refuses re-inject, GSC xref lint clean, preflight
  PowerShell parses clean. No `.map`/BSP change (linker-only when next built).

**Stage-1 pre-edit de-risk (docs/36 §9-§14, no edits yet):** 12-agent deep workflow (7 mechanics
deep-dives → 4 adversarial verifiers → synthesis) so the first geometry edit is mechanical. Added:
the brush-editing playbook (§9: the 6-plane gen_zone_greybox format, hand-edit-the-constants
mechanism, what makes a brush invalid, the fixed-vs-free wall rule, the full cod2map→LED→linker
sequence + navmesh-staleness check); the **exact copy-ready market_zone shrink spec** (§10:
`X[-2201,-1281] Y[400,1456]` = **43.3% smaller**, every brush/entity edit with line+guid, with a
non-flush fallback); pre-edit + in-game verification checklists (§11); the vault/roof double-shell
**delete-12-brushes** reconciliation (§12); per-zone feasibility for all 7 (§13 — **corp caps at
~15% geometry-only**, the rest reach ~40-45%); and a build-time-unknowns list (§14). Verifier
corrections folded in (the "192u" clearance figure was non-spec → use ≥64u/≥96u spawner rule; the
"normal inverts" wording → half-space offset; lab N-wall ≥3720 to keep PaP inside). **§14 #10
resolved:** GSC has zero hardcoded market coords (`market_zone` referenced only by name) → the
market shrink has no GSC coupling.

### Changed — Perk #9 is now PhD Flopper (over the cherry slot); removed Aura Blast + Vulture Aid (2026-06-15)

Settled the perk #9 slot and reverted the roster to **9 perks**. Removed two perks-in-flight — the
**WIP Aura Blast** (which hijacked the stock electric-cherry pipeline) and the briefly-added
**from-scratch Vulture Aid**. The slot briefly became a finished **Electric Cherry**, then changed
to **PhD Flopper**: the real Electric Cherry machine model isn't in the base install (it needs a
game-rip import), so PhD reuses the stock **nuke** machine, which fits the explosion theme — **no
import needed**.
- **PhD Flopper (perk #9, cost 2,500, LIVE):** a custom **HIJACK** of the stock electric-cherry
  pipeline via new **`scripts/zm/zm_abandoned_cyber_city/_acc_perk_phd_flopper.gsc`** (the
  underlying specialty stays `specialty_electriccherry`). Adapted from the shipped HarryBo21/ColDog
  PhD Flopper: **fall + self-explosive immunity** (`level.perk_damage_override`), a
  **slide-to-explode** nova, and **explode-on-down**. BO3 ZM has no dolphin-dive (confirmed
  in-game 2026-06-15), so the nova triggers off the engine `isSliding()` directly (with a
  cooldown), not the shipped countryside jump→land-sliding→Z-drop dive. **No `.csc` needed**
  (the map draws its own LUI perk bar from `HasPerk`).
- **Blast presentation (2026-06-15):** the nova now plays a **purple/void Apothicon burst FX**
  (`dlc4/genesis/fx_apothicon_fury_spawn_in_exp` — stock .efx, source present in the Mod Tools;
  `def_explosion` is the runtime fallback) + the **Nuke-powerup "whoomp"** (`evt_nuke_flash`,
  guaranteed-loaded since the Nuke powerup ships in every zm map) + an `Earthquake` shake.
  Replaces the original tiny `grenadeExplosionEffect` poof + silent `zmb_phdflop_explo` (that
  alias isn't in this map's soundbanks). Two of the FX's particle sub-layers (shockwave/fog)
  log the same non-fatal "invalid atlas" warning as the Skye muzzle-flash FX.
- **Zombies now visibly EXPLODE + blast centres on the impact point (2026-06-15):** the burst now
  spawns on the **zombie you slid into** (nearest in-radius zombie) instead of on the player, and
  every zombie the nova KILLS pops apart — **head-gib** (`zombie_utility::zombie_head_gib`, the
  Nuke powerup's own death, called on the live zombie pre-kill) + a **torso gore burst**
  (`level._effect["zombie_guts_explosion"]`, framework-precached) + a **capped corpse-fling**
  (`StartRagdoll(true)` + `LaunchRagdoll`, the stock Thunder Wall pattern; cap 6 / Mega 8 so a
  crowd can't ragdoll-storm the network). Gib/fling gate on `health <= n_damage`, so a living
  **boss** (Brutus/Panzer/Glitch, same team, huge HP) is only chipped — never gibbed/ragdolled
  mid-fight. All stock builtins/assets — no import, no new clientfield, no `.csc`.
- **Mega — "PhD Slider":** a bigger explosion (larger radius / ~2× damage on the slide + down
  novas) on a shorter slide cooldown. **Live from the Mega flag.**
- **Perk icon:** Ronan's `exo_flopper` shader (`i_acc_perk_phd_{base,mega}`) — credit **Ronan +
  Treyarch** per the pack readme. **Machine:** stock `p7_zm_vending_nuke` placeholder (real PhD
  models need a game-rip import).
- **Roster reverted to 9:** `level.perk_purchase_limit` **10 → 9**, rotation back to **4-of-9**;
  buying all 9 base perks = 29,500.
- **Deletions:** `_acc_perk_aura_blast.gsc` + `_acc_perk_vulture_aid.gsc` + the Vulture Aid
  placeholder PNGs + the `.map` Vulture Aid machine struct (entity 44).
- **Reverted Vulture Aid wiring** everywhere it landed: the entry script + `_acc_main` `#using`/
  `init`, the zone `scriptparsetree` line, the variant/cost GDT, and the HUD/LUI masks (10 → 9 bits,
  Mega display, rotation roster, info card).
- **Docs:** [docs/13_perks.md](docs/13_perks.md), [docs/perk_abilities.md](docs/perk_abilities.md)
  (perk #9 now PhD Flopper, Vulture Aid section removed). **Built + synced clean** — PhD icons
  converted; only pre-existing Skye material warnings remain.

### Added — "Glitch Stalker" mobile blink mini-boss (script-only, zero assets) (2026-06-15)

New self-contained mini-boss in **`scripts/zm/zm_abandoned_cyber_city/_acc_boss_glitch.gsc`** —
the map's first *mobile* boss (the Juggernaut Host charges, the Subroutine Core is pinned).
Output of a 9-agent survey/design/verify workflow that ranked it #1 for "cool + unique +
easy + slider-friendly" (all four load-bearing buildability claims adversarially verified).
- **What it is:** a **promoted stock zombie** (the `spawn_subroutine_core` scaffold), so it
  needs **no new model/anim/FX assets** and a fresh clone still links. It chases at the round
  speed and every 6–10s **teleport-blinks** to flank the nearest player (reusing the Teleporter
  elite's VERIFIED(acc) `GetClosestPointOnNavMesh` → `forceteleport` path), then is **vulnerable
  for ~1.5s** (takes 2× damage) — punish the recovery window, don't out-DPS a sponge.
- **Cadence:** default **r12, then every 10** (alongside the wave; `ignore_enemy_count` so it
  never gates round end or starves the AI budget — can't soft-lock a round). Yields its round to
  the Subroutine Core on full-boss rounds. Reward tier "mini" (50% boss item + 1 Mega Bottle/player).
- **Crash-safety (deliberate):** **no `SetScale`** (the confirmed 0xC0000005 live-AI crasher) and
  **no second `ASMSetAnimationRate` writer** (the global `_acc_zombie_speed` keep-alive already
  owns this actor's speed — the blink is its mobility). Spawn is init-gated; HP written absolute.
- **Visual tell:** on each blink it **phase-flickers in** — an asset-free `Ghost`/`Show` render
  toggle (the stock zombie spawn-in builtins), render-only so it stays hittable, no new FX asset,
  no crash surface. Toggle `acc_glitch_fx`; a real glitch FX is the Phase 5 art upgrade.
- **Abstraction / tuning:** fully decoupled — owns its own `acc_round_start` cadence, so
  `_acc_boss.gsc` is **untouched**. The only cross-module edit is one additive bonus layer in
  `_acc_damage.gsc` (reads `self.acc_glitch_vulnerable`). Everything is a live `acc_glitch_*` dvar
  (master `acc_glitch_enable`, HP/cadence/blink/vulnerability + `acc_glitch_test` early spawn and
  `acc_glitch_debug` on-screen trace). Slider table: **docs/34 §D**.
- **Wiring:** `#using` + `acc_boss_glitch::init()` in `_acc_main.gsc`; `scriptparsetree` line in
  the zone manifest; bestiary entry in **docs/11**. Lints green (`lint_gsc_xref.js` OK;
  brace/paren/bracket balanced; `#namespace` after usings). **Not yet built/run on the Windows box.**

### Added — Sound & music plan (docs/35) + build-safe Phase A audio scaffold (2026-06-15)

New authoritative audio spec **[docs/35_sound_plan.md](docs/35_sound_plan.md)** +
a Soundscape pointer section (§15) in `docs/29`. Output of a 10-agent research
workflow (repo inventory, local stock-script + 3 shipped-usermap pipeline
extraction, web research, and an **adversarial license/pipeline verification pass**).

**Build-safe Phase A scaffold (code landed — no audio assets yet):** every cue is a
**silent no-op until its alias + WAV exist** (a missing alias never errors a build,
proven by the long-silent `evt_bottle_dispense`), and the `.szc` is intentionally
**untouched**, so the tree still builds clean — `lint_gsc_xref` green. Landed:
- `sound/aliases/acc_audio.csv` — new alias table (header only; paste-ready rows in
  docs/35 §8). **Not** yet registered in the `.szc` (inert to the linker until then).
- `_acc_atmosphere.gsc` — **ambient bed**: a dvar-gated (`acc_amb_on`, default 0)
  global 2D looping emitter (`acc_amb_city_bed`), mirroring the existing fog
  watch-loop pattern (waits on `initial_blackscreen_passed`, live start/stop).
- `_acc_decontamination.gsc` — **decon alarm** (`acc_decon_alarm`, 2D via
  `zm_utility::play_sound_2D`) at the EVACUATE warning — the audio half of
  `decon-hud-audio-warning`, previously text-only.
- `_acc_data_shards.gsc` — **shard pickup blip** (`acc_shard_pickup`) at the physical
  pickup (`watch_pickup`, not `grant_player` — passive regen must stay silent).
- Go-live checklist (download CC0 WAV → paste row → add one `.szc` line → build) +
  the next-wiring map for UI/elite/boss/event/music cues in docs/35 §8.

Key research findings captured in docs/35:
- **icegrenade.co.uk = local-playtest ONLY.** It's a link *index* (not a host); its
  ToS forbids redistribution and ~95% of its audio is ripped Activision/third-party
  IP — fails the CC0-only Workshop bar. Never in the shipped `.ff`.
- **Shippable audio = stock / self-authored / CC0 only** (a `.ff` exposes raw wavs).
  Verified-CC0 shortlist: Kenney Sci-fi/Digital/UI, Tallbeard music loops, Joth
  ambience + Cyberpunk Moonlight Sonata, ObsydianX UI, Kronbits, Freesound (CC0
  filter). Dropped ROT (paid) + flagged OwlishMedia (mixed-license) and CC-BY/Pixabay/
  Sonniss (grey-area in a `.ff`).
- **Current state:** audio is fog-only + 5 stock `PlaySound` calls. The one real bug
  is `evt_bottle_dispense` (`_acc_mega_bottles.gsc:420`) — **defined nowhere, plays
  silent**. The `.szc`'s `user_aliases.csv` / `ambient_mod.csv` are **stock files**
  (resolve from the tools install — not bugs). All 6 enemy/boss audio reads + the
  decon alarm remain `phase4-blocked`.
- **Pipeline (verified live):** 48000 Hz/16-bit PCM wav → `sound_assets/` → alias CSV
  row (`Template=UIN_MOD`, `Pan` = 2d/3d, `Looping`, `IsMusic`) → `ALIAS` Source in
  the `.szc` → the GSC build pass also builds the soundbank (a GSC-only relink reuses
  stale `.sabl/.sabs`; sync-to-modtools first). Reverb is BSP-driven (Radiant
  `ambient_room` volumes), not server-scriptable.

### Changed — Recoil retune (base 2.1×, Deadshot −25%/−40%) + perk-doc audit vs code (2026-06-14)

Recoil values lowered (`tools/apply_recoil_overhaul.js`, regenerated 230-twin matrix + zone):
- **Map base recoil 2.5× → 2.1×** (`BASE_SCALE`). Every gun kicks at 2.1× vanilla by default.
- **Deadshot recoil −35% → −25%** (base) and **−70% → −40%** (Mega "American Sniper"). The twin
  tokens were **renamed** `recoil35→recoil25`, `recoil70→recoil40` (factors 0.65→0.75, 0.30→0.60)
  so the names match the values — updated everywhere: `TWIN_DIMS`, `variant_dims()`, `axis_recoil`/
  `deadshot_recoil_level`, the Stabilizer `apply_timed_variant` call, GDT/zone (auto), and the
  Deadshot perk card (`acc_hud.lua` −25%/−40%). Net vanilla: base 1.575×, Mega 1.26× (both still ≥
  stock now — the −40% Mega no longer dips below stock like the old −70% did).

Plus a **code-as-source-of-truth pass** reconciling both perk docs to the actual code (a subagent
diffed all 9 perks' cost/base/Mega against `set_perk_costs` + `TWIN_DIMS` + the `_acc_*` modules):
- `docs/perk_abilities.md`: "Buy all 9 = 26,500" → **29,500** (only error found in this doc).
- `docs/13_perks.md`: boss-headshot example fixed (boss bonus is **+2.0, equal to trash** — no ×3.0
  multiplier; `ACC_BOSS_HEADSHOT_MULT 2.0`); the damage-stack illustration reworded for the additive
  crit model; "cross-cutting fact #1" corrected (the map **does** ship a generated `.gdt` + delivers
  recoil/rate/reload/ammo via GSC-gated twins — the old "zero .gdt / no GSC lever" was stale); Widow
  web duration aligned to 16 s/12 s (stock, matches perk_abilities + the card).
- Stale code comments fixed: `_acc_mega_bottles.gsc` Speed Cola reload `x0.882/+70%` → `x0.857/+75%`;
  `set_perk_costs` "26,500" → "29,500". (The pre-finalization ledger table in docs/13 is left as the
  already-banner-flagged "STALE — trust the Implemented ledger" historical appendix.)

`lint_gsc_xref` clean; `gdtdb /update` run. **Needs a Compile** (weapon assets + scripts + LUI).

### Added — Instant zombie-corpse removal (2026-06-14)

New module `_acc_corpse_cleanup.gsc`: dead zombies were lingering and occasionally **blocking
bullet traces**. On every zombie death (`zm_spawner::register_zombie_death_event_callback`,
self = the killed zombie) the corpse is immediately `Ghost()` (invisible + stops bullet collision
— stock confirms, `fr.gsc:816`) + `NotSolid()` (drops physics collision), so it can't block a shot
or pile up; the engine still frees the entity on its normal recycle schedule. Bosses / mini-bosses
are **skipped** (they own their death visuals — e.g. Brutus's death-anim clone). Dvar
`acc_instant_corpse` (default 1) toggles it. Wired into `_acc_main` (after `acc_points` so earlier
death hooks read the body first) + the zone manifest (new `scriptparsetree` line).

### Changed — Dropped the weapon-swap line from the Gun Slinger perk card (2026-06-14)

`acc_hud.lua` Double Tap Mega card no longer lists "Weapon swaps 2x faster" (user request). The
line was **accurate** (matches the −50% / ≈2× `fastfire` swap retune); the swap feature is
unchanged in code — only the card bullet was removed.

### Changed — Mega retunes: Gun Slinger swap −50%, Speed Cola +75% reload, + perk cards (2026-06-14)

Two Mega weapon-twin retunes (`tools/apply_recoil_overhaul.js` `TWIN_DIMS`, regenerated; twin names
unchanged so the zone is unchanged), plus the in-game perk display cards brought in sync:
- **Gun Slinger (Double Tap Mega) weapon-swap −75% → −50%** — `fastfire` twin `swap ×0.25 → ×0.5`
  (TAC-19 raise 0.75 → 0.375). "≈4× faster swaps" → "≈2× faster".
- **Sleight of Hand Expert (Speed Cola Mega) reload +70% → +75%** — `fastreload` twin
  `reloadTime ×0.882 → ×0.857` (net of the engine +50% it compounds with: ×0.857 × 0.667 ≈ ×0.571
  = +75%). TAC-19 reload 0.467 → 0.4002.
- **Perk cards updated** (`ui/uieditor/menus/hud/acc_hud.lua`, the LUI source of the card text +
  price): Double Tap → "DOUBLE TAP 2.0", price 2000 → **5000**, base now lists the **extra bullet**
  ("Fires 2 bullets/shot (~2x dmg)") + "+33% rate of fire", Mega "+40% rate of fire / Weapon swaps
  2x faster"; Speed Cola Mega "+75% reload speed". (Card price is the Lua `d.price`, with the Armory
  10%-off applied on top — kept in lock-step with `set_perk_costs`.)

`lint_gsc_xref` clean; GDT regenerated + `gdtdb /update`; synced. **Needs a Compile** (weapon
assets + the LUI rawfile). Docs: docs/perk_abilities.md, docs/13_perks.md.

### Changed — Double Tap kept as 2.0 (extra bullet), cost 5,000, Gun Slinger +40% (2026-06-14)

Double Tap is now officially **Double Tap 2.0** (the stock `specialty_doubletap2`), not the
previously-planned rate-only "1.0". The stock perk fires an **extra bullet per shot** (≈2× damage;
double pellets on shotguns; excludes Wonder Weapons / Ballistic Knife / explosives) and there is no
usermap-side way to strip it — so we keep it and balance around what we have:
- **Cost 2,000 → 5,000** (`set_perk_costs` in the entry script) — doubling bullet output is a major
  damage perk, priced up. "Buy all 9" total → 29,500.
- **Mega Gun Slinger fire rate +50% → +40%** — `fastfire` twin `fireTime ×0.667 → ×0.714`
  (`tools/apply_recoil_overhaul.js` `TWIN_DIMS`). Regenerated the 230-twin matrix (twin names
  unchanged, so the zone is unchanged). (Weapon-swap later retuned −75%→−50%; see the entry above.)
- The "+33% rate of fire" base is the stock Double Tap boost; the headline is the extra bullet. The
  old "convert the base to a rate-only 1.0 / strip the extra bullet" TODO is **cancelled**.
- Docs rewritten to accurately describe Double Tap 2.0 (extra bullet + rate + exclusions):
  docs/perk_abilities.md §4, docs/13_perks.md (table / prose / impl-status / 29,500 total).

`lint_gsc_xref` clean; GDT regenerated + `gdtdb /update`; synced. **Needs a Compile** (weapon
assets + the entry-script cost change). Mechanics source: Double Tap II Root Beer (CoD Wiki).

### Changed — Damage stacking is now ADDITIVE; boss-headshot + Deadshot values lowered (2026-06-14)

**Bonus damage multipliers now ADD instead of multiplying** (`_acc_damage.gsc::on_ai_damage`),
per user rule "if we have 3x and 2x that's 5x not 6x." Every bonus layer (headshot, Deadshot,
PaP custom tier, Cyberware Amplifier/Overload, ADS Overpressure, Precision Mode, Slug Round,
Kinetic Battery) is summed into one **bonus factor** = the literal sum of the applied values
(1.0 if none fired). Damage **reductions** (<1: per-gun balance cuts, shielded-elite frontal
resist) stay **multiplicative** and apply AFTER the sum, so a 0.25× resist still cuts. New
formula: `final = int( damage * bonus_factor * reduction )`.

- The old multiplicative crit chain (`crit_chain_multiplier`) was **removed** — its three layers
  (map headshot mult, Deadshot/Mega, Cyberware Overload) are now added directly into the bonus sum.
- Effect: big stacks no longer explode geometrically (the old ~100x builds collapse to roughly the
  sum of their layers); two small bonuses are slightly larger than before (2.0 + 1.4 = 3.4 vs 2.8).
  Order now matters (it was commutative under pure multiplication).
- **Boss / mini-boss headshot:** `ACC_BOSS_HEADSHOT_MULT` **3.0 → 2.0** (now equal to the regular
  `ACC_HEADSHOT_MULT` 2.0).
- **Deadshot:** `ACC_DEADSHOT_MULT` **1.5 → 1.4**; American Sniper Mega `ACC_DEADSHOT_MEGA_MULT`
  **2.0 → 1.8** (still replaces base, no double-dip).
- **Docs updated:** docs/06 (Headshot Multiplier + stacking + Deadshot tables rewritten additive),
  docs/05, docs/13, docs/perk_abilities.md, docs/18, docs/20, docs/30, docs/31.

### Changed — Zombie speed rearchitected into a round-driven curve; Rampage Inducer removed (2026-06-14)

Replaced the **Rampage Inducer** (toggle kiosk device + `acc_rampage` dvar + gated spawn-count/
spawn-delay levers) with a single **deterministic per-round zombie speed curve** in the new
`_acc_zombie_speed.gsc`. Zombies get faster **every round** with a **natural gait** (never slow-motion):

- **Rounds 1–9:** the **run** gait (a natural jog) at playback rate ≥ 1.0, creeping **+2%/round**
  (`acc_zspeed_jog_step_pct`). The jog's intrinsic speed is the "slow start" (~70–80% of max).
- **Round 10** (`acc_zspeed_sprint_round`): break into the full **sprint** gait at rate 1.0 = base-game
  max — a deliberate, natural escalation that still steps the wave **up** (strictly monotonic).
- **After round 10:** sprint gait, **+1%/round** (`acc_zspeed_sprint_step_pct`; R15 ≈ 1.05, R20 ≈ 1.10);
  rate > 1.0 = a faster sprint (no slow-mo, no upper clamp).

**Why natural-gait and not an exact-% curve — the engine constraint** (deep-researched 2026-06-15,
10-agent workflow vs the stock mirror): a BO3 normal zombie has **no continuous "move at X% speed" knob**.
Movement is root-motion / animation-driven, so the only levers are the discrete gait **tier**
(walk/run/sprint — baked speeds, unknowable from data) and `ASMSetAnimationRate` (which scales cadence
*and* ground speed together, so a rate < 1.0 is literal **slow-motion** — the Widow's Wine slow
mechanism). `SetMoveSpeedScale` is player-only; `moveplaybackrate` / `animtranslationScale` are
dead/death-only. So exact percentages and a natural early gait can't coexist — "slower than max" must
come from a slower **gait**, never a rate < 1.0 (rate is floored at 1.0 in code).

A keep-alive **continuously re-asserts** the gait + rate on every live zombie (load-bearing: a one-shot
run-cycle override DECAYS while `ASMSetAnimationRate` persists — that mismatch caused the earlier
"round-1 crawl"). It skips zombies under an *active* Widow's Wine / trap slow (those own the rate, then
reset to 1.0 on expiry) and restores ours on the next sweep. Live dvars: `acc_zspeed_sprint_round` (10),
`acc_zspeed_jog_start_pct` (100), `acc_zspeed_jog_step_pct` (2), `acc_zspeed_sprint_start_pct` (100),
`acc_zspeed_sprint_step_pct` (1) — see docs/34. The "sprint" modifier (`acc_mod_force_sprint`) forces the
sprint gait every round.

*Iteration history (three attempts, kept as footgun warnings in docs/11):* (1) walk→run→sprint **by
round** with `rate = target% ÷ tier_base%` — dipped at each tier up-shift (unknowable baked baselines) →
"slowing down per round." (2) **sprint-locked**, scaling `ASMSetAnimationRate` to an exact % (R1 70% →
R10 105% → +1%/round) — correct ground speed but a **slow-motion** sprint gait → "slomo running"; also
exposed a one-shot-override decay → "round-1 crawl" (fixed with the continuous keep-alive). (3) the
**natural-gait** model above — the resolution, trading exact percentages for a correct-looking, monotonic
ramp.

- **Removed:** `_acc_rampage_inducer.gsc` and all wiring — its `#using` + `init()` in `_acc_main`,
  its `#using` + `post_zm_main()` in the entry script, and its `scriptparsetree` line in the zone
  manifest (replaced by `_acc_zombie_speed.gsc`).
- **`_acc_early_round_pacing.gsc`** is now spawn-**count** only (kept the rounds-1–4 +35%/+40%
  count boost); its old +15% on-spawn speed boost is superseded by the curve (avoids two
  `ASMSetAnimationRate` calls fighting). `init()` no longer registers an `on_ai_spawned` hook.
- **`acc_mod_force_sprint`** (the per-run "sprint" modifier) is **no longer a no-op** — the curve
  consumes it: target clamped to ≥100% every round + forced sprint cycle. Resolves docs/26 audit #5.
- Stale Rampage references updated: `_acc_boss.gsc` comments (boss logic unchanged — it pins its
  own sprint × 1.25, and mini-bosses only spawn at R10/20 where the wave tops out at × 1.10, so it
  still outruns), and docs 11/23/24/26/27/29/34.

Verification: `lint_gsc_xref` + `preflight_windows.ps1` structural lints (directive order, ternary
wrapping, brace/paren, zone↔module list) all **green**. **Needs a sync + Compile** to take effect
in-game (new scriptparsetree module; geometry unchanged → linker-only build is enough). Not yet
runtime-tested.

### Added — Mule Kick Mega "The Armory" +25% reserve ammo (now actually works) (2026-06-14)

The Mule Kick Mega already existed in name ("The Armory") but its headline **+25% ammo capacity
was a no-op**: reserve is capped by each gun's GDT `maxAmmo`, the engine clamps runtime ammo to
that cap (proven via Widow grenades), and nothing raised the cap — so `armory_apply()` was only a
full *refill*, never extra. Now it's a real, Mega-gated +25% reserve, implemented as a new
**weapon-variant twin axis** (`axis_ammo`) — the only clean way to raise a GDT-baked stat for
only-Mega-holders (same pattern as the Deadshot/Gun-Slinger/Speed-Cola recoil/fire/reload twins):

- `tools/gen_weapon_variant_gdt.js`: new `--ammo` factor + `AMMO_KEYS` (`maxAmmo`/`startAmmo`),
  int-rounded (those are INT-typed, like `damage`).
- `tools/apply_recoil_overhaul.js`: 4th `TWIN_DIMS` row `ammo ×1.25`. **The twin matrix doubles:
  11→23 combos/form → 110→230 twins.** The generator now ALSO rewrites the zone's twin
  `weaponfull` block (`rewriteZoneTwinLines` from one shared enumeration), so GDT + zone + GSC can
  never drift again.
- `_acc_weapon_variants.gsc`: `variant_dims()` ammo row, `axis_ammo()` (gated on the Mule Kick
  Mega flag), `&axis_ammo` in `level.acc_variant_axes`; `build_available_twins()` refactored to
  generate from the dims (no more hardcoded combo list).
- `_acc_mega_bottles.gsc`: the Armory case `reconcile()`s to swap in the raised-cap twin **then**
  `armory_apply` GRANTS the extra capacity as actual bullets — per user spec (2026-06-14), it adds
  the `(twin maxAmmo − base maxAmmo)` delta (= +25% of base) to each gun's **current** reserve,
  NOT a full refill: **`100/200 → 150/250`**. Applies to every carried gun + the equipped weapon
  (the pistol slot isn't always a "primary"); a gun with no ammo twin gets delta 0. Losing Mule
  Kick strips the twin (engine re-clamps to base cap). Removed the now-redundant
  `armory_maxammo_watcher` — stock Max Ammo already fills the raised twin cap. The ammo twin also
  inherits each gun's baseline (e.g. the TAC-19 range/FMJ/spread/−15% dmg).

Scope: box guns only (the twin system covers the 5 box guns, like the other Mega twins — not
wallbuys/pistol). Regenerated + `gdtdb /update` run; zone rewritten to 230 lines; synced.
`lint_gsc_xref` clean. **Needs a full Compile** (geometry unchanged, but 230 weapon assets +
scripts). Docs: docs/13_perks.md (impl status → DONE).

### Changed — Pack-a-Punch is now INSTANT + in-place on every tier (no animation, no near-PaP swap) (2026-06-14)

PaP no longer plays the gun-into-machine float / take-back on **any** tier (user: "remove
the animation all together… no pap will ever have the animation"). Holding Use swaps the
held gun for its packed form **right there, instantly**. This also retires the near-PaP
**twin suppression** entirely — so the gun now changes **only when you actually pack**, never
from walking near the machine.

`_acc_pap_levels.gsc`:
- `acc_pap_validate` now blocks the stock float for **every** gun (always returns false) and
  routes the pack itself: un-packed → new **`acc_do_first_pack`**, packed → `acc_do_tier_up`.
- `acc_do_first_pack`: instant `GiveWeapon` of the packed form **with the gold PaP camo**
  (`CalcWeaponOptions(camo,…)` like the stock give), carries clip+reserve across, records
  tier 1, charges the machine's live cost (`self.cost`, so a bonfire sale still applies). When
  the held gun is a perk twin it hands over the matching **packed twin** in one swap.
- `acc_do_tier_up`: the 2.5s `DisableWeapons` "pack-feel" lock is **removed** — tier-ups are
  instant. (This reverses the earlier "tier-ups shouldn't be click-and-go" lock.)
- Factored the Armory (Mega Mule Kick) 10%-off into one `armory_discount()` helper (was
  duplicated across the tier-up, the cost-display keeper, and now the first pack). First pack
  stays at the stock `self.cost` so the prompt price matches the charge.

`_acc_weapon_variants.gsc`:
- **Removed** the proximity suppression (`near_pap` / `pap_origins` / `stem_is_upgraded` /
  the `ACC_PAP_SUPPRESS_*` radii / the fast near-PaP poll). `reconcile()` and `resolve_held()`
  apply the twin unconditionally; the gun is never force-reverted near the machine.
- Added **`packed_form(weapon)`**: the upgraded form of a (possibly twin) weapon, preserving
  the twin suffix (`<stem>_up_acc_<combo>`) so the first pack is a single swap; non-twins use
  the stock `get_upgrade_weapon`. Returns the weapon unchanged when there's no upgrade, so a
  knife/equipment hold can't be "packed".

Supersedes the earlier per-weapon near-PaP suppression approach (now deleted). Safe because
PaP tier / damage / overclocks / box-dedup all key off `true_base()`. `node
tools/lint_gsc_xref.js` clean; brace/paren/column-0 balanced. **Verify in-game** (can't build
from here): (1) the **gold PaP camo** appears on the instant first pack — esp. on the imported
twins; (2) ammo carries across; (3) first-pack while holding a Deadshot/etc. twin lands on the
packed twin in one swap; (4) tier-ups are instant and charge the right (Armory-discounted)
cost; (5) walking around the machine with any gun causes **zero** swaps.

### Fixed — Buying Deadshot (any base-perk twin swap) no longer eats your ammo (2026-06-14)

Buying **Deadshot** at the machine (the one base perk that triggers a weapon-variant
**twin swap**) drained the gun's ammo. Root cause was a collision between two weapon-
management systems, NOT the ammo math:
- The stock perk-drink (`_zm_perks.gsc::perk_give_bottle_begin/end`) captures your gun as
  `original_weapon`, holsters it for the bottle, and at the end switches **back to that
  captured weapon**.
- Our **async** `variant_manager` wakes on the drink's `weapon_change` and runs
  `reconcile()` **mid-drink**, which `TakeWeapon`s the base gun and gives the twin. The
  stock switch-back then targets a gun that no longer exists, re-gives the base with
  default (often 0-reserve) ammo, and the next reconcile copies that onto the twin.

Fix (`_acc_weapon_variants.gsc`):
- `reconcile( force )` now **defers while `self.is_drinking > 0`** (mirrors the existing
  `self.laststand` guard). After the drink, the switch-back's `weapon_change_complete` /
  the 3s safety-net reconciles cleanly on the **re-equipped real gun** — the stock-PaP-
  equivalent equipped swap, ammo intact (recoil twin applies <=3s later).
- The Mega path (`_acc_mega_bottles::replay_perk_drink`) IS mid-drink on purpose (its own
  coordinated holstered swap + twin re-raise), so it now calls `reconcile( true )` to
  bypass the new guard.
- Hardened `swap_weapon` to carry ammo via the stock-PaP clip/reserve **cap-delta**
  formula (`_zm_pack_a_punch.gsc:693-696`) + clamp-at-0, so the copy can never clamp even
  if a future twin ever changes a cap.

GSC-only; `node tools/lint_gsc_xref.js` clean. Needs a scripts recompile to test. Verify
in-game: `acc_variants_debug 1`, note clip+reserve, buy Deadshot, confirm both unchanged.

### Changed — Mystery Box never hands out a gun you already hold (2026-06-14)

The box draw now excludes any box gun the player already owns **in any form** — base, Pack-a-Punch
(`_up`), or a perk-variant twin. Implemented in the existing box-roll hook
(`level.CustomRandomWeaponWeights` → `acc_box_only_weapon_keys` in `_acc_map_randomizer.gsc`),
which feeds BOTH the stock weighted loop AND its `keys[0]` fallback (`_zm_magicbox.gsc:1273-1287`),
so it closes the two ways a dupe slipped through:
1. **The `keys[0]` fallback** that fired once every candidate was owned (the old code's documented
   "worst case is a duplicate box gun").
2. **The twin gap** — stock `treasure_chest_CanPlayerReceiveWeapon`'s `has_weapon_or_upgrade()` does
   not recognize a held twin (e.g. a Deadshot `s1_tac19_acc_recoil35`) as owning its base
   `s1_tac19`, so the box would re-roll the gun you're holding while a perk was active.

New helper `player_owns_box_weapon()` compares by `acc_weapon_variants::true_base` (strips the
`_acc_<token>` twin suffix → stock base-weapon table) against the player's primaries. Only
unavoidable edge case: if the player owns *every* available box gun, the box falls back to the full
box list (stock then gives a duplicate w/ max ammo — the box must hand out something). Added
`#using _acc_weapon_variants`; `lint_gsc_xref` clean. GSC-only change — synced to the usermap;
**needs a scripts recompile** (Launcher Compile or linker). Docs: docs/07_replayability.md.

### Added — External-asset onboarding: pack/unpack/check scripts + ONBOARDING manifest (2026-06-14)

A fresh `git clone` is source-only, so a second dev hit linker `no file for filespec`
errors (Brutus/Skye/Charred) — the game-rip asset packs live in the Mod Tools install,
not in git (no redistribution licence; CREDITS.md). Added a **zip-and-share** workflow so a
teammate who already has the packs can hand them over without anyone re-hunting rot-prone
MEGA links:
- `tools/external_assets_manifest.ps1` — single source of truth: every external pack,
  author, Mod-Tools-root install paths, marker, and source link. Dot-sourced by the tools
  below + shares the `Resolve-ModToolsRoot` detection (proof = `bin\modlauncher.exe`).
- `tools/pack_external_assets.ps1` — owner runs it; stages every installed pack from the
  Mod Tools root (relative paths preserved) and zips to `acc_external_assets.zip`
  (`System.IO.Compression`). Reports packed vs not-installed; `-IncludeOptional` adds
  Panzer/mechz; `-DryRun` lists without writing.
- `tools/unpack_external_assets.ps1` — receiving dev runs it; extracts into the Mod Tools
  root (robocopy `/E` merge, never deletes) and runs `gdtdb /update`.
- `tools/check_external_assets.ps1` — pre-build gate; PASS/FAIL each pack by its marker
  path, names the source link for any missing required pack, exit 1 if any required pack is
  absent (preflight does NOT cover this).
- `ONBOARDING.md` §2(c) — comprehensive pack list (all documented links + install paths) +
  the zip workflow, flagged Private-until-IP-review.

Decision (user, 2026-06-14): do NOT vendor these in git — game-rip + multi-GB; the private
zip is the supported transfer. Also surfaced: the perk-icon shaders
(`source_data/acc_perk_shaders*`), `tools/deploy_perk_shaders.ps1`, mechz/Panzer scripts,
and `docs/34_flags_reference.md` are currently **UNTRACKED on main**, so they're absent from
a fresh clone too — the shaders ride in the asset zip (same game-rip licensing posture);
the safe text files should be committed (see follow-up).

### Changed — TAC-19 crowd-control profile: range + FMJ + wider spread, −15% damage (2026-06-14)

The TAC-19 (`s1_tac19`, an 8-pellet `weaponClass spread` hitscan shotgun — `shotCount 8`) now
ships an **always-on, non-perk-gated** profile that leans into its "best crowd-control gun" role:
- **Small range buff (x1.5)** — falloff *distance* stretched: `maxDamageRange` 550→825,
  `minDamageRange` 900→1350 (base); 1100→1650 (`_up`). Holds full damage a bit further out.
- **FMJ over-penetration (`penetrateType` none→`large`)** — pellets pierce through a line of
  zombies (max tier).
- **Wider blast "girth" (hip spread x1.25)** — `hipSpread*Min/Max` widened (`hipSpreadStandMin`
  7→8.75, `hipSpreadMax` 10→12.5, etc.) so the 8 pellets fan across a wider arc and catch more
  adjacent zombies. `adsSpread` left at 0, so ADS stays a precise single-target shot (hip = crowd).
- **−15% per-pellet damage (x0.85, rounded to int)** — `damage` 175→149 / `damage2` 125→106 (base);
  255→217 / 205→174 (`_up`). The balance trade for the pierce + width. **GOTCHA (fixed same day):**
  `damage` is an INT-typed GDF field — the first pass wrote the raw `148.75` and the gun did **0
  damage in-game** (verified: every other weapon uses integer damage; only our decimals broke). The
  generator now `Math.round()`s the damage axis (`KEYSETS` int flag); range/spread/recoil/timing stay
  float (decimals fine there).

Implementation is generator-only — no GSC/zone/asset-count change (still 110 twins):
- `tools/gen_weapon_variant_gdt.js` gained numeric `--range` (`RANGE_KEYS`: falloff *distances*,
  excludes the `multishotBaseDamageRange*` ~15000u caps), `--damage` (`DAMAGE_KEYS`:
  `damage`/`damage2..5`/`minDamage`), `--spread` (`SPREAD_KEYS`: `hipSpread*Min/Max`, excludes
  decay/bloom dynamics + `adsSpread`), and a `--penetrate <tier>` **literal-set** path (FMJ
  `penetrateType` is a string enum, not a scalable number — `LITERAL_FIELDS`).
- `tools/apply_recoil_overhaul.js` gained a per-gun `baseline` config applied **in place** to the
  base + `_up` forms; because the 11 twins are cloned *from* those forms, they **inherit** the
  whole profile for free (the base gun and all 22 TAC-19 entries carry it; other 4 guns unchanged).
  `GUNS[tac19].baseline = { range: 1.5, penetrate: "large", damage: 0.85, spread: 1.25 }`.

Tunable in that one config object. Regenerated + `gdtdb /update` run (468 assets). **Needs a
linker/asset recompile** (Launcher Compile, Run unchecked) to bake into the `.ff`; no
`sync_to_modtools` needed (GDTs deploy straight to source_data, no GSC/zone change). Also fixed
stale "66 twins / 3 guns" comments → 110 twins / 5 guns in the live code. Docs: docs/05_weapons.md.

### Fixed — Brutus spawn crash #2: defer the size/speed buffs off the spawn→move transition (2026-06-14)

Brutus still **hard-crashed ~1-2s after a visible spawn** even after the `melee_track`
guard (CHANGELOG below) — i.e. *not* in the spawn frame, but right as his `%brutus_spawn`
animation ends and the pack threads `custom_find_flesh` (his charge), handing locomotion
back to the ASM. Our buff layer mutated the actor **across that fragile transition**:
`SetScale(1.5)` on a live, pathing, custom-animated AI (stock never scales an AI actor —
only `script_model`s), **plus** `host.helmet SetScale(1.5)` which double-scaled the
`LinkTo`'d helmet to 2.25×, **plus** `boss_speed_think` hitting the ASM anim-rate while he
was still `AnimScripted`. These are exactly the "stage-2 promotion" buffs the prior fix
noted had "shifted it over the limit".

Fix (`_acc_boss.gsc`): the `acc_is_mini_boss` flag, HP, and health-bar notify stay
immediate, but **size + speed are now applied by a deferred `apply_brutus_buffs()` thread**
that waits until Brutus is fully in and charging (`.brutus_enemy` set, 8s cap) before
touching scale/ASM — past the crash window. The **helmet double-scale is removed** (it
inherits the body's scale via its `j_head` link). Each buff is **dvar-gated, default on**,
so a remaining crash can be bisected live without a rebuild: `acc_brutus_scale 0`
(skip +50% size), `acc_brutus_speed 0` (skip +25% speed). If it still CTDs with both `0`,
the cause is the base NSZ pack spawn, not our buffs. Cadence also moved to r3/every-3
(`ACC_BRUTUS_FIRST_ROUND`/`_INTERVAL` 5→3) for faster testing. Docs: docs/34 (two new
flags). **Needs a scripts-only recompile** (sync → linker) to take effect in-game.

### Fixed — perk info-card bullets reconciled against implemented code (2026-06-14)

Audited all 9 perk cards in `ui/uieditor/menus/hud/acc_hud.lua` against the
finalized spec (docs/perk_abilities.md) **and** the shipped GSC/GDT, fixing every
bullet that misstated what the perk actually does. Jugger-Nog, Quick Revive, Speed
Cola, and Double Tap were already accurate. Fixes:

- **Deadshot** — recoil numbers were wrong: base **−25% → −35%**, Mega **−50% →
  −70%** (the GDT twin bakes `recoil35`=0.65 / `recoil70`=0.30 off the 2.5× map
  baseline — `tools/apply_recoil_overhaul.js:55`, `_acc_weapon_variants.gsc:425-430`;
  spec agreed too). Also fixed two stale code-comments in `_acc_damage.gsc` (:88 said
  −25%/−50%, :468 said ×1.75 Mega headshot — actual `#define` is ×2.0).
- **Mule Kick (The Armory)** — **"+25% ammo capacity per gun" KEPT** on the card
  (to be implemented later, owner decision). It is **not implemented yet**:
  `armory_apply()` (`_acc_mega_bottles.gsc:578-590`) only tops reserve to the existing
  GDT cap (no raise) and the variant GDT keeps `maxAmmo` identical (docs/30 pending
  GDT/APE task). "All buys 10% cheaper" is implemented and real.
- **Widow's Wine** — trap duration **"~20s" → "16s (slow 12s)"** to match the
  untouched stock durations (verified `WIDOWS_WINE_COCOON_DURATION` 16.0 / `_SLOW_DURATION`
  12.0 in the stock mirror). Also corrected docs/perk_abilities.md (it inflated 16/12 to ~20).
- **Stamin-Up** — base **"Faster sprint + mobility" → "+7-8% movement speed"** (the
  real stock marathon effect; BO3 has no sprint-only speed lever).
- **Aura Blast** — Mega **"Affects bosses too" → "Bosses affected (reduced stun)"**:
  on Mega a full boss gets a halved 1.5s stun, not the full 3s (`_acc_perk_aura_blast.gsc:288`).
- **Double Tap** — card kept as-is, but **flagged a migration in the docs**
  (docs/perk_abilities.md §4 + docs/13_perks.md §4 + impl-status): the base is
  currently the **stock Double Tap 2.0** (`specialty_doubletap2`, extra-bullet); the
  "+33% rate-of-fire-only / Double Tap 1.0" presentation is the migration target, and
  converting the base to a true 1.0 is a pending TODO.

### Added — Charred zombie base-horde reskin (Logical's Charred Zombie Pack) (2026-06-14)

The whole regular horde now spawns as **charred zombies** (DLC3 sentinel body +
DLC4 charred head, recoloured), replacing the greybox test bodies. Logical's pack
is a self-contained custom aitype `archetype_charred_zombie` (stock `zm_zombie.ai_bt`
behaviour + `zm_factory_zombie` anim tables + charred `c_zom_charred_zombie`
character + matching gibcharacterdef), so behaviour/health/pathing/limb-gibbing are
identical to a normal zombie — only the skin changes. Its character/gib materials
pull transitively as MODEL dependencies, so they dodge the docs/29 §14 brush-face
shader trap (same asset class as the Brutus model).

Integration (built + linked clean, `.ff` 34.6 MB, 2026-06-14):
- Assets deployed to the Mod Tools root (`model_export/_custom_zombies/charredzombies/*`
  + `source_data/_charred_zombies.gdt`); `gdtdb /update` = 1 GDT, 31 assets.
- `zone_source/…zone`: `aitype,archetype_charred_zombie` (pulls character + 15
  xmodels + materials/images; verified in the linker dependency tree).
- `map_source/…map`: BOTH `zombie_spawner`-tagged roster spawners (entity 8 factory
  + entity 12, random-picked per spawn — docs/research/BO3_stock_round_spawning_flow_actor_spa.txt)
  remapped to the charred aitype → 100% charred horde. Editor preview model → charred body.
- Pipeline: `gdtdb` → `cod2map64` → `linker` (entity-only `.map` change; no LED).

**HARD-WON FACT (do not re-learn):** a hand-placed custom-aitype spawner classname
must be **`actor_<aitype>`**, NOT `actor_spawner_<aitype>`. The linker derives the
aitype by stripping only the `actor_` prefix, so `actor_spawner_archetype_charred_zombie`
→ aitype `spawner_archetype_charred_zombie` → ERROR "not a valid aitype asset".
Stock `actor_spawner_*` classes resolve only because Radiant generates an entity-def
mapping them; a raw `.map` text edit has no def, so use the generic `actor_<aitype>`
form (matches entity 12's existing `actor_zm_nuked_basic_01`). cod2map64 accepts
either spelling — the **linker** is the gate. (Graduate to CLAUDE.md hard-won facts.)

Provenance: Logical (setup) + Scobalula (Greyhound/HydraX). 🔴 game-rip (Treyarch
DLC3/DLC4 models) — IP review before any Public Workshop publish ([CREDITS.md](CREDITS.md)).
**In-game visual confirmation pending** (skins can't be verified from a build log).

### Changed — perk info card "owns Mega" view: merged benefit list, Mega name as title (2026-06-14)

When a player owns a perk's **Mega** upgrade, the info card (mode 2) used to stack
the full base bullet list (cyan) on top of the Mega bullet list (gold), repeating
every stat the Mega supersedes (e.g. both "+50% reload speed" and "+70% reload
speed"). It now shows:

- **Title = "Mega: <name>"** — the Mega name (e.g. "Mega: Sleight of Hand Expert")
  replaces the base perk name; the base name is no longer shown alongside it.
- **One merged "effective benefits" list** — base + Mega combined, but where a Mega
  stat supersedes a base stat only the Mega value is listed (Speed Cola Mega →
  "+70% reload speed", "Faster barrier repair" — never the superseded "+50%").
  Base-only benefits (e.g. "Faster barrier repair") still show.
- **Yellow throughout** (the existing Mega colour), title + bullets.

Also **removed the "faster perk drink" bullets** from the Speed Cola card (base
"25%" + Mega "50%") — that effect was **cut** (the drink animation is shared
map-wide with no per-perk lever; `_acc_mega_bottles.gsc:550`, docs/13_perks.md),
so the card was advertising a benefit the perk doesn't grant. Card now matches
docs/13: Speed Cola = +50%/+70% reload + barrier repair only.

Implemented in `ui/uieditor/menus/hud/acc_hud.lua`: each of the 9 perks gains a
`megaFull` array (the curated merged list); `RenderCard`'s `mode == 2` branch now
renders `megaFull` with the Mega name as title. The `base`/`mega` arrays are
unchanged (still drive the buy card and the Mega preview, modes 0/1). Card-mode
behaviour documented in [docs/27_ui_plan.md](docs/27_ui_plan.md).

### Added — Cyberpunk Mega perk-icon bar replaces the stock perk bar (Ronan's Cyberpunk Shaders), all 8 perks + verified in-game (2026-06-14)

Our own perk bar whose **icon colour encodes Mega state** — **RED = base perk, TEAL = Mega'd**
(user direction) — drawn in the additive LUI overlay, with the **stock perk bar hidden** so
there's no duplication. Built up from a Jug-only proving slice to all 8 live perks and
confirmed in-game (icons render + swap red↔teal, stock icons gone, zero flash on buy).

- **Asset path = LUI `image`, not a material/stock override.** Icons are 2D UI `image` assets
  drawn via `setImage(RegisterImage(...))` (countryside `PerkImage` idiom) — no custom
  material/techset, so they sidestep the geometry-material shader-compile blocker (docs/29 §14).
  Source art: 8 perks × base(Red variant)/mega(default-teal), 128×128 RGBA from
  `Ronans_Cyberpunk_Shaders.zip` → [`source_data/acc_perk_shaders/_images/`](source_data/acc_perk_shaders/_images/),
  16 `image.gdf` entries in [`acc_perk_shaders.gdt`](source_data/acc_perk_shaders.gdt) (`noMipMaps 1`,
  `noPicMip 1`), 16 `image,` zone lines.
- **Data bridge** — new 9-bit `accOwnedMask` clientuimodel (bit i = owns perk i+1, perk_card_index
  order) + the existing `accMegaMask`, registered in lockstep
  ([`_acc_lui.gsc`](scripts/zm/zm_abandoned_cyber_city/_acc_lui.gsc) +
  [`.csc`](scripts/zm/zm_abandoned_cyber_city/_acc_lui.csc)). `perk_state_watch()` (per-player,
  0.25s) polls `owns_or_paused`/`has_mega_perk` and pushes both masks — so the bar tracks buys,
  downs/bleed-out, EMP-pause, and re-buys automatically (no manual event tracking).
- **Widget** — `CoD.AccPerkBar` in [`acc_hud.lua`](ui/uieditor/menus/hud/acc_hud.lua): one icon
  per owned perk, packed left-to-right at the bottom-left (red base / teal Mega / hidden if not
  owned). Tunable `SIZE`/`PITCH`/`START_X`/`BOTTOM`.
- **Stock perk bar HIDDEN via GSC clientfield suppression — NOT asset override.** Two
  asset-override attempts (`specialty_*_zombies`, then `i_t7_specialty_*`) both FAILED, which a
  6-agent investigation traced to a load-order fact: **a usermap zone loads LAST, and a
  same-named base-game asset always wins (the usermap copy is "Redundant" and discarded)** — so
  a usermap can never shadow a base asset (the false "usermap version wins" assumption is
  corrected in the zone + docs/28). The stock perk bar is a LUI widget keyed off per-player
  models `hudItems.perks.<key>` (>0 = show). Fix: `clear_stock_perk_hud()` zeroes all 9 of those
  fields (`set_player_uimodel` → engine `CodeSetUIModelClientField`, no scoping; names verified
  vs `_zm_perks.gsh PERK_CLIENTFIELD_*`). **Cosmetic only** — perk *effects* come from engine
  `SetPerk`, untouched.
- **Zero-flash hide** — `stock_perk_hud_suppressor()` clears the fields on the stock
  `perk_acquired` notify, which fires the **same server frame** as the stock OWNED clientfield
  set with no wait between (`_zm_perks.gsc:756→780`), so the client's end-of-frame snapshot never
  carries the OWNED value → the stock icon never appears on buy. The 0.25s poll is the re-assert
  for the rarer boss-unpause path.
- **Deploy/build** — [`tools/deploy_perk_shaders.ps1`](tools/deploy_perk_shaders.ps1) copies the
  GDT + images to the Mod Tools `source_data/` + `gdtdb /update`; then `sync_to_modtools.ps1` →
  linker (asset/GSC/LUI only, no geometry). Dev test hook `acc_dev_jugg_mega 1`/`2`.
- **Licensing:** art is Treyarch + CDPR-derived → **personal build only** (docs/29 §8); not
  Workshop-publishable without rights.

### Changed — dev mode DEFAULT-ON for pre-release testing (reverses the gating below) (2026-06-14)

The Steam launcher truncates its command line and silently drops `+set acc_dev 1` (and
`acc_open_map`), so the just-added flag-gating left every test launch in a clean consumer game
(no money/power → decon killed the tester). Flipped the gate defaults from `0` to `1` in
[`zm_abandoned_cyber_city.gsc`](scripts/zm/zm_abandoned_cyber_city.gsc) main() and
[`_acc_dev.gsc`](scripts/zm/zm_abandoned_cyber_city/_acc_dev.gsc) `init()`, so a plain launch IS
the dev sandbox regardless of the launcher. `acc_dev 0` / `acc_open_map 0` still give a clean
consumer test. **`TODO(ship)`: flip these defaults back to `0` before any public/Workshop build**
(both sites are commented). Also added a visible **"DEV MODE ACTIVE"** spawn banner so dev state
is confirmable at a glance.

### Fixed — dev sandbox gated behind flags; no flags = clean consumer game (2026-06-14)

The dev/test sandbox was **hardcoded ON** in three places, so a default launch
shipped in god-mode (infinite money/shards, whole map open, decon hazard off,
perk cap 18) while the code's own comments claimed it self-gated. Restored the
opt-in gates so a launch with **no `acc_` dvars is a clean consumer game** — the
intended player experience. Audit finding #1 (2026-06-14 architecture audit).

- **`_acc_dev::init()`** ([`_acc_dev.gsc:36`](scripts/zm/zm_abandoned_cyber_city/_acc_dev.gsc#L36))
  — re-added the `getdvarint("acc_dev",0) != 1` early-return (the gate its own
  header + `_acc_main` comment always described). With the flag unset the whole
  module no-ops; production never shows debug HUDs/numbers (the damage-number
  hook `level.acc_dmg_num_feed` is only set when on, and `_acc_damage` already
  guards `isdefined` on it — verified, no regression).
- **Entry script** ([`zm_abandoned_cyber_city.gsc` main()](scripts/zm/zm_abandoned_cyber_city.gsc#L150))
  — the three hardcoded threads/assignments are now gated:
  - `acc_dev 1` → `acc_hardcoded_dev()` (unlimited money + Data Shards + Mega
    Bottles, auto power-on, dev banner).
  - `acc_open_map 1` → `acc_hardcoded_open_map()` (open all doors + both PaP
    blockers) **and** `level.acc_disable_decon = true` (decon is lethal when you
    roam a fully-open map, so it's tied to the same flag).
  - Both default OFF → closed map, earn-your-own-money, decon live.
- **Launch scripts** now set the flags so the dev experience is unchanged:
  `PLAY_TEST_MAP.bat` and `tools/run_game.ps1` pass `+set acc_dev 1 +set
  acc_open_map 1`. New `run_game.ps1 -ClosedMap` (sandbox but closed map + decon
  live) and the existing `-NoDev` (clean consumer game) switches.
- **New doc** [docs/34_flags_reference.md](docs/34_flags_reference.md) — the
  authoritative list of every `acc_` dvar (dev/test/modifier/tuning/debug),
  defaults, effects, read sites, and launch recipes. Linked from ONBOARDING.

### Changed — ONBOARDING.md refreshed for the recent perk / weapon-variant / PaP work (2026-06-14)

New-dev onboarding caught up to this session's changes: (1) the Build section now distinguishes
a GSC/`.lua` relink (linker only) from geometry (`.map`) or weapon-GDT changes (which need a full
Compile: `gdtdb /update` → `cod2map64` → Radiant LED → linker) — the "I changed it but nothing
changed in game" trap; (2) a heads-up on the weapon-variant **twin** swap system
(`_acc_weapon_variants.gsc` + `tools/apply_recoil_overhaul.js`; the GSC allow-list + zone
`weaponfull` lines + `source_data/acc_weapon_variants.gdt` must stay in lockstep); (3) new "read
more" links — `perk_abilities.md`, docs/30/31, docs/33 (adding a gun), and CHANGELOG.

### Fixed — dev "open all doors" now opens the PaP blocker too (the one door that never opened) (2026-06-14)

The dev open-the-whole-map overrides left **one barrier closed every run**: the
per-run Pack-a-Punch blocker. The randomizer (`apply_pap_approach`) leaves one of
`acc_pap_block_server` / `acc_pap_block_roof` solid each run to gate the PaP
approach. These are bare `script_brushmodel`s (no trigger, no `script_flag`), so
**both** open-all paths — which only walk `zombie_door` trigger ents — skipped it.
That was the "one door that never opens", and on runs where traversal funneled
through the blocked corridor it could wall off reaching the Mystery Box.

Two fixes (dev-only; the shipped per-run PaP randomization is untouched):

- **`acc_hardcoded_open_map()`** (entry script, auto-runs every dev game at
  blackscreen+3s) now also opens **both** PaP blockers (`Hide`/`NotSolid`/
  `ConnectPaths` — the inverse of the randomizer's block). Runs after
  `apply_pap_approach`, so it always wins.
- **`dev_open_all_doors()`** (manual console `acc_open_doors 1`) was **flag-only**
  — `flag::set` on a door's `script_flag` activates the zone but, per stock
  (`_zm_blockers.gsc:1322`, the flag is set as an *output* of a purchase), does
  NOT retract the door slab. It now physically clears each slab and opens both
  PaP blockers, matching the auto path. New `dev_open_pap_blockers()` helper.

`lint xref OK`. No new stock APIs (reuses the randomizer's own verified open
calls). docs/23 dev-flags note updated.

### Added — Ripper (`iw6_ripper`) box gun: 6th gun, convertible SMG⇄AR (2026-06-14)

Added the **Skye Ghosts Ripper** as the 6th box gun — a **convertible SMG⇄AR** (Evo Pro
III), the map's most mechanically unique weapon. Downloaded + extracted the Skye Ghosts
pack (1.27 GB) to the BO3 root. The Ripper is **4 GDT assets** (smg/ar × base/_up) linked
by `altWeapon`: the weapon-switch input toggles AR⇄SMG mid-fight. Wired per the pack's
canonical ADD-TO files:

- **CSV / box** — the **`_zm` naming trap**: CSV/box use `iw6_ripper_smg` (NO `_zm`); the
  engine resolves the `_zm` asset (`add_zombie_weapon` keys the box by
  `GetWeapon(weapon_name)`, `_zm_weapons.gsc:531/559`). `box_weapons` += `iw6_ripper_smg`.
- **Zone** — all **4** `_zm` weapon assets so both modes + both PaP forms + the altWeapon
  links resolve (verified all 4 in the FF assetlist/deps).
- **Classification** — SMG family (primary mode): SMG Overclock pool + **Whirlwind**
  ability; both mode-names mapped so they work in AR mode too.
- **Balance** — `acc_weapon_balance_mult` += `iw6_ripper → ×0.25` (one `IsSubStr` covers
  all 4 assets). SMG 190 dmg/674 RPM, AR 140 dmg/968 RPM — both ~530-565 effective DPS.
- **Sound** — 13 canonical aliases (`wpn_iw6_ripper_*`) copied verbatim from the pack.
- **NO perk twins** — the convertible `altWeapon` conflicts with the weapon-variant SWAP
  engine (a twin swap would break the toggle), so the Ripper is intentionally absent from
  `variant_guns()` / the recoil tool. Keeps every other system (headshots, damage perks,
  PaP both modes, ability, overclocks).

`lint xref OK`. Linker: **no Ripper errors** (all 4 assets + 13 sounds + models/anims
compiled; only the 2 pre-existing waived cosmetics remain). FF **30.18 MB**. New docs/33
gotcha (convertible weapons); docs/05 + docs/32 updated. Credit: TheSkyeLord + LilRobot.

### Fixed — Brutus spawn crash: guard `self.brutus_enemy` deref in the pack's melee_track (2026-06-14)

After the stage-2 integration, Brutus spawning **hard-crashed the game** (`console_mp.log`:
repeated `nsz_brutus.gsc:596` script errors — "undefined is not a field object" / "not a vector"
/ "undefined and 75"). Root cause: the vendored pack's `melee_track()` dereferences
`self.brutus_enemy.origin` every 0.05s, but `brutus_enemy` isn't set until `custom_find_flesh()`
runs a few frames AFTER spawn. That window floods script errors → hits BO3's script-error limit →
fatal crash. (Stage 1 stayed under the limit by timing luck; our stage-2 promotion shifted it over.)
Fix: one-line `isdefined( self.brutus_enemy ) &&` short-circuit guard on the melee_track condition —
the exact pattern the pack already uses in `custom_find_flesh`. `lint` clean, relinked.

(Unrelated: the build also logs a non-fatal missing-material warning `iw7_efx_plasma_muz_flash` — a
weapon muzzle-flash material, cosmetic, not from this fix or Brutus; tracked separately.)

### Added — AE4 (`s1_ae4`) box gun: 5th gun, directed-energy AR (2026-06-14)

Added the **Skye AW AE4** as the 5th box gun — a **directed-energy AR** fitting the
cyberpunk theme. Already installed (the AW pack), so no download. Full docs/33 treatment:

- **Box / table / zone** — `box_weapons` += `s1_ae4`; CSV `rifle` row; zone
  `weapon,s1_ae4`/`_up`.
- **Classification** — joins the **AR** category: overclock `ar` family (Burst Coil /
  Piercing Rounds / … — synergy with its native penetration) + shares the AR ability
  **Focus Fire** with the AK-47 (category-based by design).
- **Balance** — `acc_weapon_balance_mult` += `s1_ae4 → ×0.22`. 160 dmg @ 500 RPM
  (slower than the AK) but medium **penetration** (pierces a zombie train) + clip 36 +
  tight spread; ×0.22 keeps single-target ~ASM1 tier so effective penetrating output
  lands in band, not above (hard-map discipline).
- **Twins** — `apply_recoil_overhaul.js` + `variant_guns()` += AE4; 22 AE4 twins +
  22 zone lines. Matrix 88 → **110** (11 × 5 × base/_up).
- **Sound** — 12 aliases (`wpn_s1_ae4_*`, incl. energy start/end + first-raise).

`lint xref OK`. Linker exit `2006000` = **2 waived cosmetic** gdtDB items: the
Five-Seven camo + the AE4's `iw7_efx_plasma_muz_flash` muzzle-flash FX (Skye points the
AW AE4 at an Infinite Warfare plasma FX not in our packs — non-fatal; gun fires/sounds/
damages fine, only the muzzle VFX is absent). FF 29.98 MB. Verified: AE4 weapon + 22
twins compiled, sound bank loads. New docs/33 gotcha (cross-game FX); docs/05 + docs/32 updated.

### Changed — Boss health bar: removed the over-head world marker (top bar only) (2026-06-14)

User request: keep just the single depleting boss bar + name label at top-center, drop the colored
waypoint marker that floated over the boss. `_acc_health_bars.gsc` — removed the marker create
(`make_boss_bar_set`), per-frame recolor (`boss_bar_track`), and destroy. The `ACC_BOSS_OH_*` defines
are now unused (left in place). Scripts-only relink; clean but the pre-existing waived camo warning.

### Added — BO2 AK-47 (`t6_ak47`) box gun: 4th gun, full suite (2026-06-14)

Added the **Skye BO2 AK-47** as the 4th box gun (full-auto AR), filled in completely
— sounds, recoil/perk twins, classification, balance — via a new reusable runbook,
**docs/33**. Touch points:

- **Box / table / zone** — `_acc_map_randomizer.gsc` `box_weapons` += `t6_ak47`;
  `zm_levelcommon_weapons.csv` AK row (`rifle`); zone `weapon,t6_ak47`/`_up`.
- **Ability** — new `ar` category → **Focus Fire** (`effect_focus_fire`, 25 s cd):
  arms 6 auto-crit shots (reuses the Precision Mode `acc_ability_crit_shots`
  contract, longer burst to fit a full-auto AR). `_acc_weapon_abilities.gsc`.
- **Overclock** — `ar_list = ("t6_ak47")` → the existing AR pool (Burst Coil, etc.).
- **Balance** — `acc_weapon_balance_mult` += `t6_ak47 → ×0.23`. Raw 200 dmg @ 750 RPM
  is the highest in the pool; ×0.23 lands sustained DPS just above the ASM1 — the
  AR-workhorse box reward, still inside the HARD-map band. Gets headshots (not
  shotgun-excluded).
- **Twins** — `apply_recoil_overhaul.js` `GUNS[]` += AK + `variant_guns()` += AK;
  re-ran the tool → 22 AK twins + base recoil ×2.5 + gdtdb. Zone twin matrix
  66 → **88** (11 combos × 4 guns × base/_up).
- **Sound** — 10 aliases (`wpn_t6_ak47_*`) cloned into `acc_skye_box_weapons.csv`.

**Pipeline fix:** `sync_to_modtools.ps1` now also deploys `sound/aliases/*.csv` to
`share\raw\sound\aliases\`. The sound-bank build reads `share\raw`, not the usermap;
a stale copy there made the WHOLE alias bank fail to load the moment a source changed
(caught this build — `nsz_brutus.csv` had never been deployed there → all guns silent).

`lint xref OK`. Linker exit `1000000` (waived Five-Seven camo only). FF 29.26 MB.
New doc **docs/33** (reusable gun-add runbook); docs/05 + docs/32 updated.

### Added — Speed Cola + Double Tap Mega abilities via weapon-variant twins (2026-06-14)

Completes the three baked-weapon-stat Mega abilities the 2026-06-14 perk audit found
non-functional (GSC flag set, zero in-game effect). They have **no live engine lever**, so —
like Deadshot recoil — they ship as per-perk **weapon-variant twin swaps**:

- **Speed Cola "Sleight of Hand Expert" — +70% reload.** `fastreload` twin: `reloadTime` /
  `reloadEmptyTime` / `*AddTime` ×0.882, layered on the engine's free +50% → ~+70% net
  (`_acc_weapon_variants.gsc::axis_reload`, Mega-only). The base-25% / Mega-50% **perk-drink
  speedup was CUT** — the drink anim is shared map-wide and plays before you own the perk, so
  it can't be perk-gated (user call).
- **Double Tap "Gun Slinger" — +50% fire rate AND −75% weapon-swap.** Bundled into one
  `fastfire` twin (`fireTime` / `holdFireTime` ×0.667 + raise/drop times ×0.25) since both
  gate on the DT Mega flag (`axis_fire`).

Built on the other agent's axis-based variant rearchitecture (`level.acc_variant_axes`,
graceful `desired_weapon()` fallback). Changes:

- `tools/gen_weapon_variant_gdt.js` — now scales reload + swap timing keys via `--reload` /
  `--swap` (added `RELOAD_KEYS` / `SWAP_KEYS`); one twin can combine recoil+fire+swap+reload.
- `tools/apply_recoil_overhaul.js` — generates the full **recoil × fastfire × fastreload**
  cross-product: 11 combos × 3 guns × (base + `_up`) = **66 twins** into
  `source_data/acc_weapon_variants.gdt`.
- `_acc_weapon_variants.gsc` — `build_available_twins()` enables all 11 combos; header refreshed.
- `zone_source/*.zone` — 66 `weaponfull` lines (verified 0 mismatches vs the GDT, both ways).
- `_acc_mega_bottles.gsc` — `specialty_fastreload` Mega case + perk-loss revert; fixed stale
  comments (deleted DT "+6% damage"; Deadshot recoil −25%/−50% → −35%/−70%; "inert" claims).
- Docs — `perk_abilities.md` / `13_perks.md` Speed Cola drink lines removed + Deadshot recoil
  corrected to −35%/−70%; `13_perks.md` ledger synced + a "stale" banner on the pre-finalization
  audit table; `docs/30` + `docs/31` Gun Slinger + Speed Cola sections flipped to BUILT.

`lint_gsc_xref.js` clean. **Build caveats:** (1) +54 `weaponfull` assets (12→66) — watch the
linker for a weapon-budget error; the GSC fallback lets you trim the rare 3-axis combos safely
if needed. (2) `FIRE 0.667` / `RELOAD 0.882` magnitudes assume specific engine compounding —
confirm in-game (`acc_variants_debug 1`) and retune the single generator constants.

### Added — NSZ Brutus replaces the Juggernaut Host mini-boss (2026-06-14)

Begin replacing the Juggernaut Host mini-boss with **Brutus** (NateSmithZombies' BO2 port,
`NSZ_Brutus_V1.0.4`). Audit finding: Brutus is a custom **aitype** (`zm_brutus` — stock-zombie
behaviour + BO2 model + custom anims via the `zm_brutus` animtable), NOT a hard behaviour-tree
archetype like `mechz`, so it ships fully and works in usermaps. Full dossier + verified script
API: `docs/research/NateSmithZombies_Brutus_BO2_boss_pack.txt`; ledger entry in docs/22.

Design decisions (user, 2026-06-14): Brutus replaces the **mini-boss** (r10/r20); he **charges
alongside the normal wave** (his native `ignore_enemy_count` design, not our wave-suppressing
gate); the perk/box **lock mechanic is dropped**; our health bar + 10× HP + +25% speed +
Mega-Bottle/boss-item rewards get layered on (stage 2).

This commit is **stage 1 only** — wiring so the asset import can be proven in-game:
- **Source assets copied into the Mod Tools root** (`model_export/_NSZ`, `xanim_export/_NSZ`,
  `sound_assets/_NSZ`, `share/raw/fx/_NSZ`, `share/raw/animtables/zm_brutus.*`,
  `map_source/_prefabs/_NSZ`) for the APE GDT import. (Not repo-tracked; source = the pack zip.)
- **`scripts/_NSZ/nsz_brutus.gsc`** — pack script vendored. One config edit:
  `brutus_lock_machines = false` (REQUIRED — with no lock prefabs, the pack's `watch_for_machines`
  `while(1)` has no wait and hard-loops).
- **`_acc_boss_brutus.gsc`** — thin wrapper; stage-1 `init()` just calls `brutus::init()`.
- Wired into `zone_source` (scriptparsetree + scriptbundle/xmodel/fx lines), `_acc_main` init list,
  and sound (`sound/aliases/nsz_brutus.csv` (19 aliases) + `.szc` source).

Done by the agent: Brutus GDT registered via `gdtdb /update` (52 assets, clean) — it stays at its
pack location `model_export\_NSZ\_GDT\` (GOTCHA: `gdtdb` scans BOTH `model_export\**\_GDT` AND
`source_data`, so do NOT also copy a pack GDT into `source_data` — that double-defines every asset
and `gdtdb` errors); spawner + spawn-spot entities appended to the `.map` (`actor_spawner_zm_brutus`
at the navmesh-valid stock-spawner spot; `brutus_spawner_spot` struct `script_string=start_zone` by
the player spawn); `brutus_debug=true` for a round-1 test spawn; synced to the usermap. The greybox
has no AI traversals, so the "ignore Brutus" step is N/A. Remaining (Windows/user): **one Launcher
Compile (map + scripts)** — it converts the Brutus GDT assets (proven path: the Skye weapon GDTs
already convert into this map's `.ff`) and bakes the new entities — then launch.

**Stage 2 — full integration (GSC-only, done; needs a scripts-only recompile).** Brutus now IS the
mini-boss, driven by `_acc_boss` instead of the pack's own systems:
- **Cadence: every 5 rounds from round 5** (r5, 10, 15, 20, 25, 35, 45, …) via `round_hook_loop`
  (`ACC_BRUTUS_FIRST_ROUND`/`_INTERVAL`); the full boss (Subroutine Core) still takes r30/40/50 and
  suppresses Brutus those rounds. `run_mini_boss` no longer suppresses the wave — Brutus charges
  **alongside** it and keeps his native `ignore_enemy_count` (doesn't gate round end, user choice).
- **`spawn_brutus_miniboss`** (was `spawn_juggernaut_host`) gets a live actor from the new
  `acc_boss_brutus::spawn_one()` and layers on: **10× HP** (500k × coop), **+25% speed**
  (`boss_speed_think`), **50% bigger** (`SetScale 1.5`, body + helmet), the **health bar + over-boss
  marker**, and **Mega-Bottle + boss-item** rewards on death.
- Vendored `nsz_brutus.gsc` hooks: gate its `brutus_spawn_logic` behind `acc_brutus_external_spawns`,
  emit the live actor to `level.acc_brutus_last` + `"acc_brutus_spawned"`, skip the 5–20s pre-spawn
  delay when we drive it, `brutus_debug` reverted to false. Test loop re-gated behind `acc_test_boss`.

`lint_gsc_xref.js` clean; brace/paren balanced. **Built** via headless
`linker_modtools.exe -modsource zm_abandoned_cyber_city` (scripts-only relink; reuses the stage-1
BSP + converted assets) → `.ff` repacked, only the pre-existing waived `mtl_origins_camo_alt`
warning. GOTCHA: szc alias files resolve from the Mod Tools ROOT `share\raw\sound\aliases\`, not the
usermap — the Launcher's sound step copies them there, but a standalone `linker` run does NOT, so a
sound-alias change needs the csv copied to root (or a Launcher compile). Polish backlog: more
spawn-point structs (only one in start_zone today), helmet-scale fine-tune, confirm
`ASMSetAnimationRate` visibly speeds his charge.

### Changed — Weapon-variant framework generalized to a data-driven AXIS registry (2026-06-14)

Refactored `_acc_weapon_variants.gsc` from hardcoded (recoil-level, fast) logic into an
effect-agnostic **axis** model, so other agents can add perk/ability twins (Gun Slinger
fire-rate, Speed Cola reload, …) **without touching the swap engine**:

- **Axes** — each is `axis_<name>(self=player)` returning its active token or undefined;
  `level.acc_variant_axes` lists them in canonical order. Added `axis_recoil` (Deadshot),
  `axis_fire` (Gun Slinger), `axis_reload` (Speed Cola Mega). `compute_tokens()` collects the
  active tokens; `desired_weapon()` resolves `<gun>[_up]_acc_<tok1>_<tok2>…` with graceful
  fallback (missing combined twin → partial effect → base).
- **Single source of truth** — `variant_dims()` (token levels per axis, mirrors the
  generator's `TWIN_DIMS`); `build_variant_suffixes()` derives the stem-strip list as a
  mixed-radix cross-product (all 11 combos, forward-safe); `build_available_twins()` gates on
  the `built` combo list (= what's compiled in).
- **Timed overlay** generalized to a token-set (`apply_timed_variant(tokens[], dur)` +
  `timed_has()`), so any axis can be granted by an ability (Stabilizer now passes
  `["recoil70","fastfire"]`).
- **Full 66-twin matrix BAKED + LINKED** — recoil × Gun-Slinger(fire+swap) × Speed-Cola(reload),
  11 combos × 3 guns × (base+`_up`). `tools/apply_recoil_overhaul.js` (user-extended to the
  cross-product) generates them; GDT/zone/allow-list verified in sync (66=66=66); all 66 link
  (0 twin errors). **Gotcha:** after regenerating the GDT you MUST run
  `<tools>\gdtdb\gdtdb.exe /update` before linking, or the new twins are `unable to locate asset
  in gdtdb` (the linker doesn't refresh the DB; the Launcher Compile does).
- **Extension guide** for agents: docs/30 "Adding a weapon-variant effect" + the EXTENSION
  POINT banner in-module. The generator already scales recoil/fire/reload/swap GDT key-sets.
- Recoil behavior preserved (Deadshot still resolves `_acc_recoil70`); fire/reload combos resolve
  with graceful fallback. Lint clean; linked clean (twin side).

### Changed — gun damage balance pass: Five-Seven −50%, ASM1 −65% (user, 2026-06-14)

Audit (base, close-range, single-target DPS): **Five-Seven** 200 dmg × 12.5/s (semi) = ~2,500
peak; **ASM1** 170 × 11.2/s (full-auto) = ~1,910 sustained; **Tac-19** 175 × 3.3/s (single blast)
= ~580. The starting pistol and the SMG were badly out-DPSing the Tac-19. Applied flat per-gun
damage multipliers in **`_acc_damage.gsc`** (new `acc_weapon_balance_mult`, called at the top of
`on_ai_damage` into the `n_mult` chain): Five-Seven **×0.5**, ASM1 **×0.35** (−65%), Tac-19 **×1.0**.
Substring match so it covers base + PaP (`_up`) + the Deadshot recoil variants. Post-pass single-
target DPS ≈ Five-Seven 1,250 peak / ASM1 668 / Tac-19 580 — much tighter; ASM1's full-auto makes
it the real sustained benchmark, hence the deeper cut. GSC-only (linker), lint clean. Single source
of per-gun balance, easy to retune. (Tac-19's niche stays its wide blast + flat/no-headshot damage.)

**Follow-up (same day): a further −25% on ALL three** — the map should be HARD and heavily reward
progress, so base guns are deliberately weak and PaP / Deadshot / Cyberware damage carry the
scaling. Compounded multipliers are now Five-Seven **×0.375** (−62.5%), ASM1 **×0.2625** (−73.75%),
Tac-19 **×0.75** (−25%). Base-DPS lands ~Five-Seven 940 peak / ASM1 500 / Tac-19 440. Not lethal
cuts (e.g. ASM1 still ~134/headshot with the map's ~3× head mult), but early/mid rounds now demand
upgrades. Edit `acc_weapon_balance_mult` to retune.

### Fixed — Recoil-variant rearchitecture: instant swaps + engine-native upgrades (2026-06-14)

Playtest surfaced 3 bugs (gun randomly swaps out / flip-flops between versions; PaP indicator
breaks until repack). A multi-agent design exploration (8 agents) root-caused a single mechanism:
**`SwitchToWeapon`'s ~0.5s raise animation left `GetCurrentWeapon()` in a transitional state that
fed the reconcile loop**, and the twins were **invisible to the engine's PaP upgrade table** so a
held twin read as un-upgraded. Fixes in `_acc_weapon_variants.gsc`:

- **Instant swap** — `SwitchToWeapon` → `SwitchToWeaponImmediate` (verified stock builtin). No
  raise/lower animation → the swap is invisible AND closes the transitional-weapon window that
  caused the "random swap out" + flip-flop.
- **Engine-native upgrades** — `register_twin_upgrades()` registers each **`_up`** twin in
  `level.zombie_weapons_upgraded` (twin→true-base, the table stock `add_zombie_weapon` writes), so
  `is_weapon_upgraded(twin)=true` / `get_base_weapon(twin)=base` natively → the PaP HUD/tier-up/
  re-pack all read a held twin correctly (kills the "PaP breaks until repack" bug). Only `_up`
  twins are registered (base twins must stay un-upgraded so first-pack still applies tier 1 + camo);
  twins are never added to `zombie_weapons`/`include_weapons`, so the box can't roll them.
- **Re-entrancy mute** — `self.acc_swapping` guard so the swap's own `weapon_change` can't re-wake
  reconcile mid-swap.
- **Down / lose-Deadshot handled** — reconcile early-returns while `self.laststand` (don't touch
  guns mid-down); the poll became a **3s safety-net** that re-derives from live `HasPerk()`, so a
  down that strips Deadshot reverts the gun to base once revived (plus `perk_lost_func`→`on_perk_lost`
  →`request_reconcile` pokes it immediately). PaP tier persists (player field, `true_base`-keyed).

Kept: `true_base()`, the 12 generated twins, `near_pap()` suppression (still needed so a base twin
reverts to the real gun for the FIRST pack). Lint clean; linked clean.

### Changed — Tac-19 blast girth: wider spread cone (user, 2026-06-14)

The Tac-19 (`weaponClass = spread`, hitscan — not an explosive) now has a noticeably wider
blast: `hipSpreadStandMin` 3°→**7°**, `hipSpreadMax` 5°→**10°** (`adsSpread` left at 0, so it
still tightens when aimed). Applied to base + PaP + all 4 Deadshot recoil variants — I widened
the spread in the canonical `skye_s1_tac-19.gdt.acc-orig` backup (so it survives the idempotent
`apply_recoil_overhaul.js` re-runs, which restore from `.acc-orig`) and re-ran the overhaul tool,
which re-derived `acc_weapon_variants.gdt` so the variants inherit the wide cone. gdtdb + linker
clean (only the waived Five-Seven camo warning). Trade-off: bigger crowd-control arc up close,
less density/reach at range. **Reproducibility note:** the base-GDT spread lives install-side
(the Skye pack is install-only — same gap as the whole import); the variant GDT copy IS in the
repo (`source_data/acc_weapon_variants.gdt`). Could be made fully repo-tracked by adding the
spread step to `apply_recoil_overhaul.js` if desired.

### Changed — Juggernaut Host mini-boss: +25% speed + 10× HP (2026-06-14)

The moving boss (mini-boss "Juggernaut Host", the one with the health bar + over-boss marker)
got two buffs. The full boss (Subroutine Core) is unchanged — it's pinned stationary by
design, so a speed buff is meaningless there. (`_acc_boss.gsc`; docs/11_enemies.md updated.)

- **+25% faster than the current round speed.** New `boss_speed_think()` keep-alive locks the
  Host to the **sprint** run cycle (the round's top base tier, and the same cap the Rampage
  Inducer forces the wave to) and applies `ASMSetAnimationRate( 1.25 )` on top — zombie movement
  is anim-driven, the same lever early-round pacing / Widow's Wine use. Re-asserted every 2s so
  round transitions, state changes, or a mid-fight Rampage toggle can't decay it. Net effect:
  Rampage **off** → +25% over the round's top zombie speed; Rampage **on** → still +25% above the
  sprint cap, so the Host outruns even a rampage-sprinting wave. Replaces the old fixed
  `set_zombie_run_cycle("run")` lock (which made the Host *slower* than the round at sprint rounds).
- **10× HP** (`ACC_BOSS_MINI_HP` 50,000 → **500,000**, still ×`special_hp_mult()` coop scaling).
  The round-2 dev test-boss override (`acc_test_boss`) is left low on purpose so the Mega-Bottle
  drop loop stays testable without surviving to round 10.

### Fixed — 3-gun arsenal audit follow-ups: box junk-draw + weapon abilities (2026-06-14)

Post-change adversarial audit (4-agent, read-only) flagged real gameplay issues; fixed the
three that mattered. (It also raised a "grenades never given" *blocker* that was a FALSE alarm —
the entry `main()` calls `zm_usermap::main()` at line 130, which registers `frag_grenade` and
gives it at spawn; verified, no change needed.) `lint_gsc_xref.js` clean; linker built (only the
waived Five-Seven camo warning).

- **Box could dispense a knife / frag / pistol.** With only 3 box guns + Mule Kick a player can
  own all three; stock `treasure_chest_ChooseWeightedRandomWeapon` then falls back to `keys[0]`
  (a random entry from the whole weapon table). Fix: `_acc_map_randomizer.gsc` sets
  `level.CustomRandomWeaponWeights = &acc_box_only_weapon_keys`, narrowing the draw key list to
  `is_in_box` weapons — so both the loop and the fallback only ever see box guns (worst case = a
  duplicate box gun, stock max-ammo behaviour).
- **Every gun now has a LIVE signature ability** (`_acc_weapon_abilities.gsc build_ability_table`):
  Five-Seven (pistol) → **Precision Mode** (3 auto-crit shots), ASM1 (smg) → **Whirlwind** (96u
  AoE), Tac-19 (shotgun) → **Slug Round** (next shot 3×). Previously ASM1 had **no** ability (no
  `smg` category) and the pistol's Triple Tap was a no-op stub. Removed the unreachable
  melee/grenade/AR/sniper categories (offhand weapons are never `getcurrentweapon()`), so there
  are no more dead-end abilities. ASM1 already gets SMG **Overclocks** (the pool existed). The
  unused effect fns (`effect_triple_tap` etc.) are kept defined for future re-add.

### Added — Recoil overhaul Phase 1: 2.5× base + Deadshot −35%/−70% twins + PaP persistence (2026-06-14)

The map's skill theme: **every gun kicks at 2.5× vanilla recoil**, and Deadshot claws it back
(**−35% base / −70% Mega**, off the 2.5× baseline → 1.625× / 0.75× vanilla). Built on the 3
imported box guns (`s1_tac19`, `s1_asm1`, `t6_fiveseven` + their `_up` PaP forms), all-automated
(GDTs are plain text — no APE).

- **`tools/apply_recoil_overhaul.js`** (idempotent, repo-tracked) — scales each gun's base +
  `_up` recoil ×2.5 *in place* in the Skye GDTs (keeps a `.acc-orig` backup, restores before
  re-scaling so re-runs never compound), then generates **12 twins** (`recoil35` ×0.65,
  `recoil70` ×0.30, base+`_up` × 3 guns) into `source_data/acc_weapon_variants.gdt`. Verified
  value chain: vanilla 60 → base 150 → recoil35 97.5 (1.625×) → recoil70 45 (0.75×).
- **`tools/gen_weapon_variant_gdt.js`** — added an `--inplace` mode (scales an asset's recoil
  fields inside the source GDT, no rename) alongside the twin-clone mode.
- **`_acc_weapon_variants.gsc`** — tokens `recoil35`/`recoil70` (was 25/50); `deadshot_recoil_level`
  returns 70 (Mega) / 35 (base) / 0; `build_available_twins()` lists all 12; Stabilizer maps to −70%.
- **PaP persistence (the hard part):** `acc_weapon_variants::true_base(weapon)` strips the
  `_acc_*` twin suffix *before* `get_base_weapon`, so the 5-tier PaP tier — **and** overclock
  state + headshot-exclusion — follow a gun across recoil swaps. Re-keyed every base-keyed
  lookup in `_acc_pap_levels.gsc` (4 sites) and `_acc_damage.gsc` (3 sites); `true_base` ≡
  `get_base_weapon` for non-twins, so it's a safe drop-in. Plus: reconcile **suppresses twins
  within 150u of the PaP machine**, so the stock first-pack + custom tier-up always operate on
  the real (upgrade-table-recognized) weapon — a twin can't be first-packed.
- Zone: 12 `weaponfull,` lines. Docs: perk_abilities §7 (2.5× + 35/70), docs/30-31. Lint clean.
- **BUILT + LINKED (2026-06-14):** all 12 twins load clean (linker: zero "unable to load"), `.ff`
  written (26 MB). The lone build error — `mtl_origins_camo_alt not found` — is **pre-existing
  and pack-wide** (referenced by `skye_up_camo.gdt` + every BO2 `t6_` import's PaP camo; the
  Origins PaP camo material the Skye BO2 pack never bundled). Non-fatal (`.ff` builds; cosmetic
  missing camo on PaP'd BO2 guns). NOT caused by the recoil work.
- **Default ON (2026-06-14):** `ACC_VARIANTS_DEFAULT` flipped 0→1 (core feature, not an
  experiment) — no dvar needed; `acc_weapon_variants 0` disables, `acc_variants_debug 1` prints
  each swap on-screen. Also: `reconcile()` now includes the **equipped** weapon, not just
  `GetWeaponsListPrimaries()`, so the starting-pistol slot (Five-Seven) gets swapped too.
- **Remaining:** in-game test (recoil 2.5×→1.625×→0.75× + PaP persistence). Phase 2 = Gun
  Slinger fire-rate/swap-time twins.

### Added — Recoil twins authored by TEXT (no APE) + `tools/gen_weapon_variant_gdt.js` (2026-06-14)

The installed Skye weapon GDTs are **plain text on disk** (`source_data/skye_s1_tac-19.gdt`,
asset `s1_tac19`), so a recoil/fire twin can be authored by **editing the GDT text directly —
the APE GUI is not required** (APE just edits the same text). This unblocks the variant system
without touching the Asset Editor.

- New tool **`tools/gen_weapon_variant_gdt.js`** — extracts a `bulletweapon` asset block from a
  source GDT, renames it `<asset>_<suffix>`, and SCALES the kick-magnitude fields (Pitch/Yaw
  Min/Max for hip+ads gun & view kick) by a factor (+ optional `fireTime` scale). Brace-matched
  extraction, value-preserving formatting.
- Generated **`source_data/acc_weapon_variants.gdt`** = `s1_tac19_acc_recoil50` (recoil ×0.50,
  −50% Mega Deadshot) + `s1_tac19_acc_recoil25` (×0.75, −25% base Deadshot). Verified: envelope
  matches the source GDT (1-tab asset / 2-tab fields), braces balanced, 16 recoil fields scaled
  each, `fireTime` untouched.
- Deployed to the tools `source_data`; zone `weaponfull,` lines + `build_available_twins()`
  entries activated; repo synced to the usermap; GSC lint clean.
- **Remaining (GUI-gated, can't run headless):** a Launcher **Compile** registers the new GDT
  in `gdtdb\gdt.db` (via GdtDBTray, which needs the interactive session) and links the `.ff`;
  then `acc_weapon_variants 1` + in-game test. The `linker`-only path can't register a new GDT
  asset on its own, and the tray won't index headlessly — so the compile is the one user step.

### Verified — Weapon-GDT sourcing reality (no editable stock weapon stats) + doc corrections (2026-06-14)

A research pass + live-box check (APE shows no `weapon`/`bulletweapon` stat type, only
`wpn_t7_base` art) established the ground truth for the whole GDT perk layer (docs/22
"Weapon-GDT sourcing reality"; docs/30-31 updated):

- **No editable stock weapon stat GDTs exist in this install** — the tools ship weapon ART
  only; stock `frag_grenade`/`ar_accurate`/etc. stat defs are baked into base fastfiles. No
  download fixes it (`T7-GDT-Backup` mirrors only shipped GDTs; its sole weapon-stat GDT is a
  template `smg_standard.gdt`).
- **The Launcher has no extractor** — corrects an earlier wrong "Launcher → extract" claim.
  Decompiling a stock weapon needs **HydraX** (reads the running game), with a known
  incomplete-dump caveat → validate one throwaway twin before scaling.
- **Grenade carry caps don't need a GDT** if the target is ≤ the stock cap: the GSC fills
  (`SetWeaponAmmoClip`/`GiveMaxAmmo`, already shipped) set the count, clamped to the baked
  cap. A GDT raise is only needed to *exceed* the cap (and then via a HydraX clone).
- **Recoil-reduction / fast-fire twins are imported-weapon-only** for stock guns (can't clone
  a GDT you don't have) — the `_acc_weapon_variants` framework is name-driven, so twins built
  on the now-installed Skye box imports (`s1_tac19`, `t6_fal`, `t6_ak47`) drop straight in.
- **Field-name fixes:** recoil keys are `hipGunKick*`/`adsGunKick*`/`hipViewKick*`/
  `adsViewKick*` (not bare `gunKick*`); `fireTimeAkimbo` is not a confirmed BO3 field.

### Fixed — Deadshot is recoil REDUCTION (−25%/−50%), not zero; variant model reworked (2026-06-14)

Spec correction (docs/perk_abilities §7): Deadshot is **−25% recoil on any owner** and **−50%
on Mega "American Sniper"** — NOT "no recoil." `_acc_weapon_variants.gsc` reworked from a
`norecoil`/`fastfire` token list to a proper **(recoil-level ∈ {0,25,50}, fast ∈ bool)** state:

- Twins are now `_acc_recoil25` (gunKick* ×0.75), `_acc_recoil50` (×0.50), `_acc_fastfire`
  (fireTime ×0.667), + optional combined. APE step is **SCALE** the recoil fields, not zero.
- The recoil twin now swaps in for **base Deadshot too** (−25%), upgrading to −50% on Mega —
  wired via `_acc_mega_bottles::on_perk_bought` (base) + `apply_mega_effects` (Mega). Graceful
  fallbacks: missing −50% twin steps down to −25%; missing combined falls back to single.
- Stabilizer ability maps to the −50% + fast overlay. Zone/`build_available_twins()` examples
  updated to the imported-gun twin names. xref + structural lint clean.

### Changed — box arsenal → Tac-19/Locus/FN-FAL/AK-47: imports installed + wired (2026-06-14)

User wants the Mystery Box to dispense Tac-19, Locus, FN FAL, AK-47. Only **Locus**
(`sniper_fastbolt`) is stock BO3 — added to the box now (builds clean, linker-only). The
other three are **Skye weapon-pack imports** that need assets installed on the Windows box
(AW pack → `s1_tac19` Tac-19 + `s1_ak47` AK-47; BO2 pack → `t6_fal` FN FAL). Full download
list + the exact CSV/zone/szc/GSC wiring to flip once installed: **docs/32**.

- **`_acc_map_randomizer.gsc`** — interim box pool = ICR-1 + Man-O-War + Locus; the FINAL
  4-gun array is staged as a comment right below it (swap when imports land).
- **Import names pre-wired (inert until assets exist, so build-safe):** `_acc_overclocks.gsc`
  weapon families (Tac-19→shotgun, FN-FAL/AK-47→ar, Locus→sniper) **and purged the old invalid
  `<name>_zm` family strings** (replaced with real unsuffixed class names); `_acc_weapon_abilities.gsc`
  ability categories; `_acc_damage.gsc` Tac-19 (`s1_tac19`) headshot-exclusion (was stale `tac19_zm`).
- AK-47 lands as `s1_ak47` (AW) or `t6_ak47` (BO2); both are listed in the classification tables
  so whichever installs is classified. `lint_gsc_xref.js` clean; linker exit 0.

**UPDATE (same day): Skye AW + BO2 packs downloaded by the user and installed by me.** Final
box = `s1_tac19` (Tac-19/AW), `sniper_fastbolt` (Locus/stock), `t6_fal` (FN FAL/BO2),
`t6_ak47` (AK-47/BO2). Wiring (all deployed via sync):
- Packs extracted to the Mod Tools root (AW pack needed WinRAR — Deflate64 zip the .NET reader
  rejects; BO2 via .NET). Weapon GDTs/models/anims/sounds now in `source_data`/`model_export`/etc.
- **`gamedata/weapons/zm/zm_levelcommon_weapons.csv`** (NEW) — custom weapon-table override =
  stock 50-weapon table + the 3 import rows (verbatim from each pack's `ADD TO ZM_LEVELCOMMON…`).
- **`tools/sync_to_modtools.ps1`** — now mirrors `gamedata/` into the usermap.
- **`zone_source/…zone`** — 6 `weapon,` asset lines (base + `_up` per import).
- **`_acc_map_randomizer.gsc`** — box pool flipped from INTERIM to the FINAL 4-gun set.
- **BUILT** (Launcher Compile = `gdtdb /update` → `cod2map64` → LED → `linker`): all 3 imports
  converted + packed (assetinfo refs s1_tac19 152 / t6_fal 81 / t6_ak47 689), `.ff` repacked.
  The box now dispenses the four guns in-game. One non-fatal warning: the FN FAL's **PaP camo**
  (`t6_camo_fal_table` → `mtl_origins_camo_alt`) is a BO2-Origins material the pack didn't bundle,
  so the PaP'd FAL's camo shows default — base FAL + others fine (fix tracked in docs/32).
- **Correction:** a headless GDT-convert CLI DOES exist (`<tools>\gdtdb\gdtdb.exe /update`, not in
  `bin\`) — weapon-import rebuilds need not go through the Launcher GUI.
- **Sounds added** (later same day): per-pack `ADD TO USER_ALIASES` rows for the box guns →
  custom alias CSV `acc_skye_box_weapons.csv` + a new ALIAS source in the `.szc`; the linker
  rebuilds the sound bank from the `.szc` (confirmed headless). All box guns fire with audio.

**FINAL ARSENAL (user, 2026-06-14): exactly 3 guns.** Box returns ONLY **Five-Seven**
(`t6_fiveseven`, Skye BO2 — also the **starting pistol** via `level.start_weapon` in
`_acc_main::init`), **ASM1** (`s1_asm1`, Skye AW), **Tac-19** (`s1_tac19`, Skye AW). **FN FAL +
AK-47 fully removed** (zone/CSV/aliases/classification → 0 asset refs); Locus/ICR/Man-O-War out
of the box. New file `gamedata/weapons/zm/zm_levelcommon_weapons.csv` (stock table + imports);
`sound/aliases/acc_skye_box_weapons.csv`; `tools/sync_to_modtools.ps1` mirrors `gamedata/`.
Built headless (gdtdb→linker), `.ff` 24.97 MB. Lone non-fatal warning: Five-Seven PaP camo
(BO2-Origins `mtl_origins_camo_alt`, unbundled — user-waived). Status: **docs/32**.

**Table cleanup (user, 2026-06-14):** to stop the unused stock roster confusing devs/agents,
`gamedata/weapons/zm/zm_levelcommon_weapons.csv` was cut from the full ~50-weapon stock table to
**6 rows** — the 3 guns + the 3 framework essentials that the engine hardcodes and the loadout
needs: `pistol_standard` (last-stand pistol), `knife` (`give_start_weapons` melee), `frag_grenade`
(lethal). The ~45 unreachable stock guns / wonder weapons / equipment were removed (they were
never wallbuy/box-dispensed anyway; `GetWeapon()` flavor refs resolve globally, not from the level
table — proven by stock `hk416`/`knife_held` working without a row). The `_acc_overclocks` +
`_acc_weapon_abilities` family/ability tables were trimmed to match (AR/sniper/lmg lists now empty;
melee → `knife`). Build clean (only the waived Five-Seven camo warning); lint clean.

### Added — Weapon-variant swap framework (perk recoil/fire-rate twins) (2026-06-14)

> Magnitudes corrected same day — see "Fixed — Deadshot is recoil REDUCTION" above (Deadshot
> is −25%/−50% recoil, not zero; twins are `recoil25`/`recoil50`/`fastfire`, the APE edit
> SCALES recoil rather than zeroing). This entry describes the framework; that one the model.

New module **`_acc_weapon_variants.gsc`** — the GSC half of the perk magnitudes that are
**baked weapon-GDT properties** with no live setter (recoil tables, `fireTime`), per the
2026-06-14 audit (docs/30 §4-5, docs/31 §4-5). Since the engine can't change recoil or
fire rate on a held weapon, the only mechanism is to **swap the gun for a cloned twin**
whose GDT scales recoil / lowers fireTime while the perk is held, then swap the base back.

- **Engine:** an idempotent per-player reconcile loop keeps every carried primary matching
  the player's desired (recoil-level, fast) state (derived **live** from perk state, so it
  survives the death/re-buy cycle). Carries clip + reserve across each swap (mirrors the
  stock PaP ammo-carry, `_zm_pack_a_punch.gsc:688`). Resolves the exact twin first, else
  falls back (combined→single, −50%→−25%), else stays on base.
- **Wired:** Deadshot −25% (base) / −50% (Mega) → `recoil25`/`recoil50` twin; Mega Double Tap
  "Gun Slinger" → `fastfire` twin (`_acc_mega_bottles.gsc` `on_perk_bought` +
  `apply_mega_effects` + `on_perk_lost`); the **Stabilizer** weapon ability → timed −50%+fast
  overlay (`_acc_weapon_abilities.gsc`, no longer a Phase-4 stub).
- **Ships INERT (safe no-op).** Does nothing until the twins are cloned in APE, added to the
  zone (`weaponfull,<name>`), listed in `build_available_twins()` (a GetWeapon allow-list so
  an un-baked name can't throw), and `acc_weapon_variants 1` is set. Until then desired state
  is "base" and reconcile only ever leaves guns on base.
- Reads the Mega flag **field directly** to avoid a `#using` cycle with `_acc_mega_bottles`.
- Verified: xref lint clean; brace/paren/`#namespace`-order/no-ternary/col-0 checks pass.
  Builtins (`Get/SetWeaponAmmoStock`, `GiveWeapon`, `weapon_change` notifies, `GetSubStr`)
  confirmed against the stock mirror. Next step is the APE twin bake (docs/31).

### Added — Armory point-of-sale 10% discount + PaP tier-cost hint (vendored stock files) (2026-06-14)

Mule Kick's Mega "The Armory" now makes **all point purchases 10% cheaper at point of
sale** — the **charge AND the displayed price** reflect the discount (a spend-rebate
can't change shown prices). Also fixes the PaP machine showing a generic
"re-Pack-a-Punch" with no cost. This needed editing *hint/cost code that lives in stock
framework files*, so **5 stock files were vendored** into `scripts/zm/` (a deployed
`scriptparsetree` at the stock path shadows the base-game copy — verified builds clean):

- **`_zm_pers_upgrades_functions.gsc`** — the persistent-upgrades system is dormant here,
  so its `is_pers_double_points_active` / `pers_upgrade_double_points_cost` stubs are
  **repurposed** for the Armory discount (active only for the Mega-Mule-Kick flag, ×0.9
  rounded to 10). Every stock cost site already calls these → perk + stock-PaP first-pack
  charge for free. (Reads the flag **field directly** to avoid a `#using` cycle.)
- **`_zm_weapons.gsc`** — wallbuy/ammo **charge** (inline `/2` → ×0.9 helper) + per-player
  **display** in `wall_weapon_update_prompt`; needs `weapon_cost_client_filled=false`
  (entry script) so the price renders server-side. *(Inert now that wall buys are removed —
  see "arsenal lockdown" — but harmless and ready if they return.)*
- **`_zm_magicbox.gsc`** — box **charge** (`pay_cost`) + **display** (`hint_parm1`)
  discounted per-player. Box triggers are already per-player → exact.
- **`_zm_pack_a_punch.gsc`** — new `acc_pap_set_cost_hint` shows the **actual tier-up cost**
  ("Pack-a-Punch Tier N/5 [Cost: X]" / "MAX") on an upgraded weapon instead of the stock
  generic hint (tier from `player.acc_pap_tier`).
- **`_zm_perks.gsc`** — `acc_perk_hint_monitor` re-sets the machine hint to the touching
  player's discounted price (solo-exact; co-op reflects the toucher).
- **Our files:** `_acc_pap_levels.gsc` tier-up ×0.9; entry sets `weapon_cost_client_filled=false`;
  **removed the old `armory_discount_watcher` rebate** (double-discounted vs point-of-sale).

### Changed — HUD: shards/bottles moved top-left, blue points readout (2026-06-14)

- **Data Shards + Mega Bottles** moved from bottom-left (behind the stock points card) to
  the **top-left under the health bar** (`_acc_data_shards.gsc`, `_acc_mega_bottles.gsc`).
- **Blue points readout** added in the top-left stack (`_acc_points::points_hud_loop`) —
  the stock white points number is packed LUI we can't recolor in place, so this is the
  legible blue copy. (Stock card still renders; full hide/recolor is a future LUI task.)

### Fixed — arsenal lockdown: box now ICR-1 + Man-O-War only; ALL wall buys removed (2026-06-14)

The map is meant to ship exactly two guns (ICR-1 `ar_accurate`, Man-O-War `ar_damage`), both
Mystery-Box-only. Two bugs from the batch-6 pass let other guns through; both fixed GSC-only
(linker rebuild, no geometry change). `lint_gsc_xref.js` clean.

- **Mystery box still drew the whole stock arsenal.** The map references the *stock*
  `zm_levelcommon_weapons.csv` (zone:78), whose ~47 rows are flagged `in_box=TRUE`, and the
  box gate reads each weapon's live `level.zombie_weapons[wpn].is_in_box` per spin. Setting
  the flag on our two guns did nothing about the other ~45. `register_mystery_box_pool()`
  now **clears `is_in_box` on every weapon first**, then re-enables only `ar_accurate` +
  `ar_damage`. (`_acc_map_randomizer.gsc`)
- **4 wall buys were still live.** Haymaker/Drakon/Sheiva/Frag had no pool entry, so the old
  `apply_wallbuy_pool` *skipped* them — they kept dispensing their Radiant-default gun (the
  "go dead" comment was wrong). Replaced with **`remove_all_wallbuys()`**: walks
  `level._spawned_wallbuys` in `pre_init` and `zm_unitrigger::unregister_unitrigger`s every
  stub (incl. the ICR wall + Bowie melee), so no purchase trigger is ever built. Deleted the
  now-dead `roll_wallbuy_pool` / `roll_wallbuy_slot` / `weapon_in_zm_table` /
  `is_rolled_onto_wall` / `apply_wallbuy_pool` and the `state.wallbuy_pool` plumbing.
- **Walls also removed visually (geometry rebuild, 2026-06-14).** Unregistering kills the
  *purchase* only; the wall gun model + chalk + fx are client-spawned (`_zm_weapons.csc`).
  Deleted the 6 wallbuy struct PAIRS (12 `script_struct` entities, 123→111) from
  `map_source/zm/zm_abandoned_cyber_city.map` and ran the full pipeline (sync → `cod2map64`
  → Radiant LED → `linker_modtools`, all exit 0, `.ff` repacked clean). `remove_all_wallbuys()`
  stays as the runtime safety net (now a no-op — `level._spawned_wallbuys` is empty).
  **⚠️ The `vending_weapon_upgrade_spawnable` prefab is Pack-a-Punch, NOT a wallbuy — preserved**
  (along with the box, Quick Revive, and the 3 perk machines). Adversarial map/GSC/build
  verification passed (3 agents, no blockers). Docs: docs/05, docs/07, docs/29.

### Changed — perk overhaul: reconcile GSC to the finalized 2026-06-14 spec (docs/13 + perk_abilities.md)

Implemented the user's "Code change list" (docs/13). Retunes, removals, two new
mechanics; Aura Blast parked (WIP). `lint_gsc_xref.js` clean; builds.

- **Jug** Ultimate Tank 300→**314 HP** (`_acc_mega_bottles.gsc` `n_player_health_boost` 50→64).
- **Quick Revive** — base revive now **2.0s** / Savior **1.0s** (override applies to base QR
  too, not just Mega; `_acc_perks.gsc::qr_revive_time`/`qr_revive_watcher`); regen split to
  base **15%** / Savior **30%** sooner (`ACC_QR_REGEN_DELAY_BASE/_SAVIOR`).
- **Double Tap** → "Double Tap 1.0": **removed** the +3%/+6% damage layer (fire-rate only now).
- **Widow's Wine** — **removed** base +50% frag damage and **both** Spiderman one-hit-kill
  blocks; added **round restock** (base 2 / Spiderman 4, `widow_round_restock_watcher`).
- **Stamin-Up** Flash ×1.12→**×1.15**; **removed** the sprint-duration override.
- **Deadshot** American Sniper headshot ×1.75→**×2.0**.
- **Mule Kick** Armory: removed the +2-grenade fill; added **"all buys 10% cheaper"** as a
  spend-rebate (`armory_discount_watcher`) — *open decision:* point-of-sale discount (the
  spec's `pers_double_points` mirror) would also lower the affordability threshold but needs
  4 stock files vendored.
- **LUI cards** (`acc_hud.lua`) rewritten to the new bullets; Double Tap → "1.0", Aura Blast → "(WIP)".
- GDT-only items (Speed reload/drink, Gun Slinger fire-rate/swap, Deadshot recoil, Armory
  +25% ammo, Widow 6-clip) tracked in docs/30–31.

### Fixed — perk info card layout (full-width / off-card text) (2026-06-14)

Corrected the LUI anchor math (verified vs `zm_building` reference: `false`=center-relative,
`true`=edge-relative). Card left value −394 made it ~1012px wide (nearly full screen);
set to **+246** for a ~372px right-side panel, and the text lines now inset with the proven
`(true,true,18,-18)` idiom so they sit inside the card instead of hugging the far left.

### Changed — perk/PaP info card: closer range, left-overflow fix, full Mega description (2026-06-14)

- **Proximity now ~buy distance.** `_acc_perk_info.gsc` show range cut from 170u/180u to
  80u/85u to match the stock perk buy trigger (radius 40 + the trigger's ~60u height
  offset → ~72u at the buy-cylinder edge). The card no longer pops up from across the room.
- **Fixed the left overflow / "content too far left".** The card's
  `setLeftRight(false, true, …)` made its LEFT edge center-relative (center-394), so the
  372-wide card spilled off the left of the screen and the title/text overflowed left.
  Changed to `(true, true, …)` so both edges anchor to the screen right → a proper
  372-wide card, 22px from the right edge (cf. the centered damage-number widget's
  `(false,false)`). Title scale 1.15→1.0 and the Mega preview drops the long `"MEGA: "`
  prefix (the gold title + "Mega upgrade: 1 Bottle" subline already convey it).
- **Mega'd perks now show the FULL description.** When you own a Mega'd perk (mode 2),
  the card lists the **base** bullets (cyan) **and** the **Mega** bullets (gold) together,
  instead of just an "Owned + Mega upgraded" line. `ACC_CARD_BULLETS` (6) fits the largest
  base+Mega set.

### Added — numeric "current / max" health readout next to the player health bar (2026-06-14)

`_acc_health_bars.gsc` now draws a `current / max` number (e.g. `150 / 250`) to the
right of the top-left player health bar, recolored green→amber→red in lockstep with the
bar so a low value reads red at a glance. Current is clamped to `[0, max]` so a
downed/over-heal frame can't show a negative or out-of-range number. Makes the Jug 3/6/7
HP testing legible.

### Fixed — crosshair damage numbers now show on EVERY hit (incl. headshots / PaP) (2026-06-14)

The damage number was inconsistent and dead on Pack-a-Punched / perk'd guns. **Root
cause** (verified against `_zm.gsc:5824`): the number was fed by a *second*
actor-damage callback (`dev_damage_cb`), but stock dispatch **short-circuits on the
first non-`-1` return**, and `_acc_damage` reorders itself to the front and returns the
*modified* damage — so on every modified hit (any headshot, and **every** gun hit once
you own Double Tap, plus crits/Widow/Cyberware/PaP) the second callback never ran.
Numbers only survived bare, unmodified body shots.

- **Fix:** feed the number from **inside `_acc_damage::on_ai_damage`**, at the
  `record_damage` chokepoints that run for *every* player hit before the short-circuit
  return (`feed_dmg_number`, passing the true `final_damage`). Wired via a level hook
  `level.acc_dmg_num_feed` (`_acc_dev` sets it to the accumulator) — no module
  dependency cycle, and it auto-clears when dev mode is off so production shows nothing.
- Removed the broken `dev_damage_cb` actor-damage callback. Covers bullets, grenades,
  and the Spiderman melee/web one-hit paths (minigun deliberately excluded — a stock
  callback adjusts its damage after us, so we can't report it accurately).

### Fixed — PaP tier damage now stacks (was silently dropped on headshots/perk hits) (2026-06-14)

Found while making the damage number truthful: the custom Pack-a-Punch **tier**
multiplier (T2 ×1.25 … T5 ×2.30) lived in its OWN actor-damage callback
(`_acc_pap_levels::pap_damage_cb`), separate from `_acc_damage`. But stock dispatch
(`_zm.gsc:5824`) takes the **first** callback that returns non-`-1` and passes the
**original** damage to each — so two modifying callbacks are mutually exclusive.
`_acc_damage` runs first, so on **any** modified hit (every headshot, every Double-Tap'd
hit, every crit) the PaP-tier callback never ran → **PaP'd guns were under-damaging**,
and the damage number under-reported PaP on the body-shot path.

- **Fix:** folded the PaP tier multiplier into `_acc_damage`'s single multiplier chain
  (one authoritative `final_damage` that stacks PaP × headshot × Deadshot × Double Tap ×
  Cyberware × …, exactly as docs/13's stack example intends). Removed `pap_damage_cb`;
  `get_tier`/`pap_tier_mult` remain as the queryable source the chain reads. Net result:
  PaP tiers now stack correctly **and** the crosshair number equals the true applied
  damage on packed guns. `lint_gsc_xref.js` clean; builds.

### Fixed — grenade-fill field bug + full perk-requirement re-verification (2026-06-14)

A **55-agent audit** opened and adversarially re-checked every one of the **42 perk
sub-requirements** in `docs/13_perks.md` against literal code (our `_acc_*` modules +
the installed stock `share/raw/scripts`), with each "no GSC lever exists" claim backed
by a quoted grep. Net: **30/42 met in code** (all stock base behaviors, all working
Megas, Aura Blast, cap-removal, the whole Mega-Bottle infrastructure), the rest
physically not GSC-reachable (APE weapon-GDT / Radiant / engine-impossible / design).

- **Real bug fixed — `_acc_mega_bottles.gsc` grenade fills targeted the wrong field.**
  ZM carries grenades in the **clip**, not the reserve (stock refills lethals via
  `SetWeaponAmmoClip`, `_zm.gsc:4582`; Widow's Wine decrements/reads the clip,
  `_zm_perk_widows_wine.gsc:214`/`:294`). The **Spiderman 6-web-grenade** top-up and the
  **Armory lethal/tactical** top-off used `Get/SetWeaponAmmoStock` → they filled the
  unused grenade reserve and did **nothing**. Switched both to `…AmmoClip` (value kept:
  web → 6, Armory → grenade GDT `maxAmmo`), so the GSC halves of WW-7 and MK-2 now
  actually fire (magnitudes above the baked GDT carry cap still need the APE raise).
  `lint_gsc_xref.js` clean.
- **`docs/13_perks.md` Implementation Status re-verified.** Corrected stale citations
  (`:325`→`:326`, `:326`→`:327`, `_acc_damage.gsc:279-285`→`:294-300`,
  `:414-419`→`:429-435`, `perk_purchase_limit :192`→`:193`); removed the unverifiable
  **"melee 45"** assumption (the in-script `60` is the *board-hit* value; open-field
  melee is a baked GDT stat → Jug 6/7 hit counts are an **in-game** confirm, not a code
  fact); flagged **Mule Kick base** as pure stock (no `additionalprimaryweapon_limit=3`
  line ever existed — old citation was wrong). Reclassified Gun Slinger +50% RoF and
  Flash ×2-walk/×4-crawl from "GDT/MISSING" to **engine-impossible (grep-proven) → cut
  from card**, and Widow EMP to **strike (no stock asset)**.
- **Rotation lockout — headless lever documented.** The audit found stock
  `level.custom_perk_validation` (`_zm_perks.gsc:560-562`) can enforce the 4-of-9
  per-round lockout on existing machines with no Radiant work; left **off by default**
  (user decision 2026-06-14: leave off until the 4 Lab machines are built).
- **Perk cards trued-up (`acc_hud.lua` + `docs/perk_abilities.md`).** Struck the two
  un-deliverable lines: **The Flash ×2 walk / ×4 crawl** (engine-impossible — only a
  uniform move scalar exists) and **Widow's Wine +50%/+25% EMP** (no stock EMP asset).
  The cards now promise only what the build delivers or what the APE pass will add.
- **Gun Slinger +50% fire rate reclassified** from "engine-impossible" to **APE
  weapon-variant swap** (verified: no runtime fire-rate setter/dvar exists *anywhere*,
  but a cloned gun with a lower `fireTime` swapped in while the Mega is held delivers it
  — same framework as Deadshot no-recoil).
- **New `docs/31_ape_perk_gdt_walkthrough.md`** — click-by-click APE guide for the
  remaining baked-stat magnitudes (Armory grenade/reserve caps · Widow frag radius +
  6-web cap · Deadshot no-recoil + Gun Slinger fire-rate variant-swaps · Speed Cola
  timings), with the global/perk-gating caveats and a payoff-ordered priority list.

### Added — `docs/perk_abilities.md` flat perk/ability quick-reference (2026-06-14)

- New **[docs/perk_abilities.md](docs/perk_abilities.md)**: a flattened, one-bullet-per-ability
  list of all 9 perks (base + Mega) plus the map-wide perk rules (no 4-perk cap,
  Mega-via-bottle, HP baseline). Each bullet that is stock *Black Ops III* behavior is
  tagged **`(BASE)`** (per the 13_perks.md "stock vs custom" split: perks 1–6 + Widow's
  Wine; Deadshot/Aura Blast and all Mega tiers are map-custom, untagged). Derived from
  `docs/13_perks.md`, which stays the source of truth; added a pointer from `13_perks.md`.

### Added — perk-requirement GSC fixes: new `_acc_perks.gsc` + Mega/effect wiring (2026-06-14)

Closed every **GSC-reachable** gap from the 2026-06-13 perk audit, driven by a
per-perk research+verify workflow (each fix's stock APIs verified against
`tmp/bo3_stock_ref`; hand-applied; `tools/lint_gsc_xref.js` clean; structural
brace/paren/directive-order checks pass). The non-GSC remainder is specced in the
new **[docs/30_perk_gdt_radiant_spec.md](docs/30_perk_gdt_radiant_spec.md)**.

- **New module `scripts/zm/zm_abandoned_cyber_city/_acc_perks.gsc`** (wired into
  `_acc_main::init` + `on_player_connect`/`on_player_spawned`, entry `#using`, and
  the `.zone` manifest): hosts the base-perk GSC retuning —
  - **Jug 3/6 hit model** — `tune_jugg_health` sets `zombie_perk_juggernaut_health`
    = 150 (→ 250 HP → down on the 6th melee @ 45 dmg) after blackscreen.
  - **Quick Revive +30% regen** — `qr_regen_booster` starts HP regen ~30% sooner.
  - **Savior (QR Mega) revive ×0.6** — `savior_revive_time` via the stock
    `self.get_revive_time` hook (1.5s → 0.9s).
  - **Savior +15% move while a teammate is down** — `savior_speed_watcher` + a new
    `×1.15` term in `_acc_utility::recompute_move_speed`.
- **`_acc_boss.gsc`** — **Ultimate Tank (Jug Mega) boss-ability immunity**:
  `protect_immune_players_during_debuff` re-grants immune holders' perks across the
  power-off / perks-off cascade. (Power is a global flag, so a holder's traps still
  go dark — only owned perks are preserved.)
- **`_acc_mega_bottles.gsc`** — wired the stubbed Megas that have a GSC lever:
  **The Flash** longer sprint (`SetSprintDuration(6.0)` + respawn re-apply),
  **The Armory** reserve/grenade fill (`armory_apply` + Max-Ammo watcher),
  **Spiderman** 6-web-grenade top-up; recalibrated **Ultimate Tank** to `+50` HP
  (→ 300 → 7th-hit down; +100 had overshot to 8).
- **`_acc_damage.gsc`** — **Spiderman web-grenade OHK** on ordinary zombies (gated
  on `level.w_widows_wine_grenade`, mirroring the melee-OHK block).
- **`_acc_perk_aura_blast.gsc` + `_acc_elites.gsc`** — **Aura Blast per-enemy-type
  matrix**: shielded→shield-down, teleporter→no-teleport (companion guard in the
  teleporter loop), EMP→1s, mini-boss→50% at base (was wrongly immune), full
  boss→immune base / affectable Mega.
- **Docs:** `13_perks.md` Implementation Status rewritten to the post-fix ledger
  (8 of 9 Mega effects now fire); new `30_perk_gdt_radiant_spec.md` work order for
  the GDT (Armory caps, Widow radius/6-nade cap, Deadshot no-recoil, Speed Cola
  timing) + Radiant (4 `acc_lab_perk_*` rotation machines) remainder.
- **Verify bar:** `lint_gsc_xref.js` = "all resolve"; brace/paren balance + no
  `#using`/`#define` after `#namespace` + no column-0/reserved-word issues on all 8
  touched files. Real verification still pends the Windows build + in-game tuning
  confirm of the Jug 3/6/7 hit counts (melee dmg is a GDT constant).

### Changed — perk implementation audit + verified status ledger (2026-06-13)

Audited all 9 perks (base + Mega) and the 3 shared systems in
[docs/13_perks.md](docs/13_perks.md) against the actual GSC that grants each
ability, via a 24-agent workflow (one auditor + one adversarial verifier per
item; every verdict re-checked by opening the cited code and grepping the whole
`scripts/zm` tree — verifiers flipped nothing).

- **Rewrote `docs/13_perks.md` "Implementation Status"** from the stale
  "only Aura Blast implemented" prose into a **verified per-ability ledger**
  (OK / PARTIAL / STOCK / STUB / MISSING, each with `file:line`).
- **Headline findings:** Aura Blast is essentially complete; Deadshot ×1.5/×1.75,
  Double Tap & Widow's frag *damage* halves, Spiderman melee-OHK, Mega-Bottle
  plumbing, and `level.perk_purchase_limit=9` cap-removal all genuinely fire.
  Everything else is stock-default, GDT-blocked, or an un-wired stub.
- **Two root causes captured in the doc:** (1) the repo ships **zero `.gdt`
  files**, so every baked-stat ability (fire rate, recoil, reload scalar, ammo/
  grenade caps, blast radius, Jug health) is unbacked and *cannot* be done in
  GSC; (2) **`_acc_perks.gsc` was never authored** — cap-removal + cost table
  landed inline, the rest of its scope is unbuilt.
- **Rotation reality recorded:** the roll/timing/storage "brain" is real but
  `apply_perk_rotation_to_machines` is a `TODO(acc-geom)` stub with no
  `acc_lab_perk_*` Radiant entities, so all 9 perks are always buyable and the
  4-of-9 lockout never happens.
- **No code changed** — documentation-only pass.

### Fixed — Vault/Roof doorways cut, back third of map now reachable (2026-06-13, branch `MajorImprovements`)

The Server Vault and Rooftop Helipad were sealed greybox boxes (injected by
`gen_rooms.js` in `56799dc`) whose door openings had never been cut — so opening
`enter_vault`/`enter_roof`/`enter_lab_e`/`enter_lab_w` revealed a solid wall, and
the Subterranean Lab (reachable only *through* those two rooms) was unreachable in
normal play. Not a regression — that geometry was never finished.

- **Cut 4 doorway gaps in the `.map` source** (`map_source/zm/...` worldspawn): the
  Vault **west wall** (`ACCB0012`) and Roof **east wall** (`ACCB0023`) were each
  reduced to their solid middle (y2536–3120), opening a full-height gap at each end
  aligned to the existing sliding door slabs — Corp door @y2474–2536, Lab door
  @y3120–3186. Corp Plaza and Lab are open-plan, so no other walls needed cutting.
- **Full rebuild verified** (cod2map64 BSP+navmesh run from the `bin` cwd so the nav
  settings load, LED recompute, linker) — clean; `.ff` 24,936,832 B @ 23:16.
- Greybox openings (full height, no frame); Radiant polish (jambs/lintel, raised
  Vault ceiling, Roof sky brush) deferred. docs/29 §13 updated.

### Added — atmosphere & materials plan + Phase-1 fog (2026-06-13, branch `Wallpaper`)

First pass at the map's *look* — turning the greybox (every face the placeholder
`script_wall`/`script_floor_ceiling` tool material, flat `skybox_default_day`)
into an **abandoned cyber city**. Driven by a 6-agent research workflow
(install-prober + pipeline + stock-inventory + community-scout + art-director,
then an adversarial verifier), all findings file-verified against the local Mod
Tools install + the shipped `tmp/zm_alien_isolation` source.

- **New design doc [docs/29_atmosphere_and_materials.md](docs/29_atmosphere_and_materials.md)** —
  art direction (palette, low-key neon lighting, smog-night sky/fog), the
  **build-vs-buy decision (~90% stock-skin, ~10% custom emissive/LUT, ~0% bespoke
  modeling)**, the verified BO3 material/sky/fog pipeline, a **verified stock
  asset shortlist** (`t7_*` walls/floors + `default_night` sky), per-zone art
  direction for all 7 zones, a phased plan, Workshop **licensing policy**, the
  trap list, and the open design decisions.
- **New module `_acc_atmosphere.gsc`** (wired into `acc_main::init`, lint-clean,
  `.zone`-registered): a cold city-haze `SetVolFog` applied after the initial
  blackscreen. Fog is the ONE atmosphere lever that is pure GSC; the rest (night
  sky, wet-ground re-skin, reflection probes) are Radiant/BSP edits. Every fog
  parameter is live-tunable via `acc_fog_*` dvars (`acc_fog_livetune 1` re-applies
  continuously so the look can be dialed from the console with no rebuild);
  defaults `(0, 1600, 600, 0, 0.02, 0.03, 0.06, 0.70)`. `SetVolFog`'s 8-arg
  signature + 0..1 float RGB confirmed against stock `load_shared.gsc:807`.
- **Verifier caught two costly errors before any build:** (1) the
  `zm_alien_isolation` material names (`black1_plaster`, `ayz_floor`,
  `really_dirty_emissive`, …) are that author's **custom, unlicensed** assets, NOT
  stock — they'd fail to resolve + can't ship; use the verified `t7_*` names.
  (2) Face materials need **no** `.zone` line (the shipped map has 2 `material,`
  lines for ~1017 materials); only non-face assets (LUT/sky/FX/decal) get listed.
- **KB + hard-won facts updated:** [docs/BO3_MAPMAKING_KB.md](docs/BO3_MAPMAKING_KB.md)
  gains a Materials/Sky/Fog recipe; CLAUDE.md gains the face-token=material-name,
  `default_night` ZM-safe sky, and alien-vocab-not-stock facts.
- **Phase-1 `.map` flip applied (plain-text edits, buildable):** per the owner's
  choices (full-send scope · bespoke-HDRI sky target · cyan/magenta/amber neon),
  edited `map_source/zm/zm_abandoned_cyber_city.map`: worldspawn + `volume_sun`
  sky → night (`skyboxmodel skybox_default_night`, all `ssi*=default_night`;
  `wsi=default_night`, `fsi` stays `default` — the exact key-set a stock prefab
  ships, byte-verified); all 546 wall faces → `t7_concrete_bare_weathered_01_dark`;
  all 90 floor faces → `t7_concrete_floor_garage_cracked_wet_nw` (both byte-
  verified in `t7_concrete.gdt`). Geometry untouched (2822 lines, 0 `havoc` refs).
  `default_night` is the interim sky; the bespoke smog-orange HDRI is the locked
  target (build kit in docs/29 §12.3). Needs a full build (cod2map64+LED+linker)
  to render — the sky/material changes are BSP-baked. docs/29 §10 records the
  locked decisions; §12 adds the per-zone / neon / HDRI-sky / vision build kits.
- **Reflection probes (7) added to the `.map`** — one per zone, origins = the
  average of each zone's spawn risers (z≈90), keys mirrored from a shipped probe,
  unique guids, named `acc_probe_*`. They give the wet ground its neon reflections
  (the #1 "cyberpunk city" signal; we had 0). First-pass box sizes — grow to each
  zone's extent + retune in Radiant once visible. Baked → needs the LED pass.
  Brush/brace balance verified (559/559), geometry intact.
- **CREDITS.md added** (owner decision) — asset-provenance ledger + the
  stock/original/CC0-only licensing policy; current assets are all stock+original.
- **Phase-2 per-zone material differentiation** (`tools/apply_zone_materials.js`,
  one-shot): classifies each wall/floor face by its own position (nearest zone
  center) and swaps the global concrete for the zone's byte-verified `t7_*`
  material. 5 built zones now read distinct — spawn=concrete, market=brick,
  alley=black-metal+wet-asphalt, corp=stainless-steel, lab=brushed-steel+lab-floor.
  Geometry byte-identical (braces 559/559, only material tokens changed). First
  classifier used per-*brush* centroids — wrong for the greybox's large
  zone-spanning brushes (lumped big shared walls into one zone); fixed to per-*face*.
- **Finding (docs/29 §13): Vault + Roof have NO built room geometry** — 0 of the
  636 wall/floor faces fall in their regions. The built greybox is a Spawn→Corp→Lab
  spine + Market (west) + Alley (east); Vault/Roof are `info_volume` gameplay zones
  + spawners only, no walls. They'll auto-skin when their rooms are built + the
  tool re-runs. A map-construction gap to reconcile vs the "full 7-zone greybox"
  status.
- **Vault + Roof room shells injected** (`tools/gen_rooms.js`, one-shot): each room
  = 6 worldspawn brushes (floor, ceiling, 4 walls), a **fully closed box** so it's
  guaranteed leak-free + compiles clean. Winding copied verbatim from a verified
  box brush (`acc_door_vault` slab); inset to avoid the door slabs; pre-skinned
  (vault = grey metal + grate floor; roof = weathered concrete + wet asphalt).
  Braces balanced (583/583). **Closed** = not reachable yet — cut the doorways in
  Radiant (positions in docs/29 §13) to finish. Build-clean as-is (noclip in to
  preview the skinned rooms). Audit in §13 confirmed the zone graph + doors +
  spawners were already coherent — only the shells were missing.
- **Neon emissive kit — copy-paste APE recipe** (docs/29 §12.2): step-by-step to
  author the 3 cyan/magenta/amber emissive "dead sign" materials by duplicating a
  shipped emissive (`door_light_emissive` et al., verified in the alien GDT) and
  retinting (`colorTint` RGBs given), + source-image specs, build steps, and the
  landmark placement plan. Face tokens → no `.zone` line.
### Overhaul batch 7 — LUI: PaP next-tier card + crosshair damage numbers (2026-06-13)

- **PaP card shows the NEXT tier only (item 3).** New `accPapTier` clientuimodel field
  (3b, lockstep gsc/csc); `_acc_perk_info` pushes the held weapon's current tier when near
  the machine; `acc_hud.lua` renders one "Next - Tier N: <benefit> (cost)" line (or MAX at
  5) instead of the whole T1-T5 ladder, re-rendering on tier change.
- **Damage numbers — crosshair-anchored LUI (item 8).** New `accDmgNum` field (18b);
  `_acc_dev` batches each attacker's damage and pushes it every ~0.12s; `acc_hud.lua`'s new
  `CoD.AccDmgNum` widget shows the number just above the crosshair (you aim at the zombie,
  so it reads on-target) and fades ~0.4s after you stop firing.
  - **Why not over each zombie's head:** proven from shipped code (`zm_countryside`
    `hb21waypoints.lua`) that over-entity *text* requires globally overriding `CoD.Waypoints`
    (the engine's objective/waypoint dispatcher) + shipping `objectives.json`, which `error()`s
    the entire HUD if that table fails to load. That system renders persistent quest markers,
    not many-per-second combat popups (it would spam the compass + objective list). World-space
    HUD text is impossible and waypoint icons are fixed-size with no digit shaders. The
    crosshair-anchored number is the reliable, correct path.
- **Mega-perk indicator is now a GLOWING badge, not flat text (item 2).** The stock perk
  bar is engine-LUI and its `specialty_*_zombies` HUD materials are not loadable in a
  usermap, so the *real* perk icon can't be glowed here. Replaced the pulsing text label
  with a per-perk **pulsing colored badge** (`hud::createIcon` "white" tinted to each
  perk's signature colour) + the Mega name over it, with proper cleanup on perk loss.
  (`accMegaMask` (9b) registered for a future LUI version; the GSC badge is the reliable now.)

### Overhaul batch 6 — reliable boss bar + arsenal strip + honest perk cards (2026-06-13)

Driven by test feedback ("rampage stops after a minute"; "boss is a box that only
changes colour — why not a real depleting bar?") + the research workflow (7 agents).

- **Boss health bar — REAL depleting bar.** Confirmed the hard limit: a world-anchored
  waypoint icon is FIXED-SIZE (SetShader resets the anchor; SetWaypoint resets the size —
  a catch-22), so it can only recolour, never deplete. Fix: the depleting bar now lives at
  **top-centre of the screen**, reusing the SAME proven path as the working player health
  bar (`hud::createBar`/`updateBar`, which sizes a real fill). It shows remaining/max and
  recolours green→amber→red. The over-boss icon is KEPT but reduced to a colour-only marker
  so you still know which zombie is the boss. (`_acc_health_bars.gsc`)
- **Rampage Inducer — PERSISTS now.** Added a keep-alive loop that re-asserts the sprint
  override on every live zombie every 2s while active (stock re-evaluates locomotion on
  round/state changes and clobbered the one-shot override → "sprinted then stopped after a
  minute"). (`_acc_rampage_inducer.gsc`)
- **Arsenal = ICR-1 + Man-O-War only (item 7).** GSC-only, no geometry rebuild: mystery box
  pool → `ar_accurate` + `ar_damage`; wallbuy pool keeps only the ICR wall (the other four
  wall slots get no purchase trigger → Haymaker/Drakon/Sheiva/Frag walls go dead); Bowie
  melee kept. Overclock AR family fixed from the never-valid `*_zm` names to `ar_accurate`/
  `ar_damage` (they were silently breaking Overclocks on both guns).
  (`_acc_map_randomizer.gsc`, `_acc_overclocks.gsc`)
- **Perk cards are now HONEST (item 5, partial).** Removed every GSC-impossible claim
  (zero recoil, +fire rate, faster swap/drink times, ×2 walk/×4 crawl, EMP grenade) so no
  card promises something the code can't do. Implemented the GSC-possible damage perks so
  their claims are TRUE: **Double Tap 2.0** +3% damage (base) / +6% (Gun Slinger Mega), and
  **Widow's Wine** +50% frag-grenade damage — both wired into the `_acc_damage` multiplier
  chain. Megas still being built (Quick Revive / Speed Cola / Mule Kick) are marked "in
  progress" instead of claiming an effect. (`_acc_damage.gsc`, `acc_hud.lua`)
- **Deferred to an isolated next build** (UI-error / anchor-guesswork risk kept out of this
  testable batch): over-the-zombie damage NUMBERS + the perk-icon GLOW overlay + the PaP
  next-tier card (all LUI), and the remaining GSC-possible perk effects (Mule Kick ammo,
  Quick Revive regen/revive-speed, Jug exact tuning). Full cited recipes captured from the
  research workflow.

### Overhaul batch 5 — boss bar + rampage root causes (2026-06-13)

- **Boss bar "top-left, not over the boss" — root cause found + fixed.** `SetShader`
  RESETS a HudElem's waypoint anchor, so resizing the bar every 0.1s dumped it back to
  screen-space (0,0). That's exactly why the STATIC black bg used to sit over the boss
  but the RESIZING red fill did not — and after batch 4 removed the bg, nothing was left
  over the boss at all. Fix: in `boss_bar_track`, re-apply `SetWaypoint(false)` +
  `SetTargetEnt(boss)` in the SAME frame right after each `SetShader` (no wait between →
  no flicker). The bar now follows the boss, shrinks with health, AND runs
  green→amber→red so it doubles as a "which one is the boss" marker.
- **Rampage Inducer toggle + persistence — root cause found + fixed.** A leftover dvar
  watcher (`watch_dvar_toggle`) polled `acc_rampage` (default 0) every second and
  *deactivated* a device-activated rampage ~1s later — exactly "zombies sprint for a few
  seconds then go back to normal" and "the device hint never flips to OFF / always says
  turn on." Made the watcher ACTIVATE-ONLY (it can still force ON for console testing);
  the in-map device is now the sole on/off toggle and its activation persists.

### Overhaul batch 4 — proper fixes after batch-3 feedback (2026-06-13)

- **PaP gun-steal fixed at the ROOT:** deleted the parallel `acc_pap_tier` trigger
  entirely (it shared the machine's origin, raced the stock take-back, and ate the Use -
  worst on the 2nd gun). Tier-ups now ride the stock machine's own `custom_validation`
  hook: un-upgraded gun → return true (stock does the normal first pack + float +
  take-back, uninterfered); upgraded gun → tier up in place (charge + bump, NO asset
  re-swap, NO float) and return false. No second trigger → nothing to steal, no flicker.
- **PaP tier HUD** lowered to -130 (the -175 in batch 3 was too high).
- **Rampage Inducer:** dropped the over-the-top `ASMSetAnimationRate(1.7)` "modded" speed;
  it now forces the SPRINT run cycle = the engine's MAX BASE zombie speed (nothing faster).
  Removed the early-pacing `acc_mod_force_sprint` deferral that was netting out the +15%
  and making it feel like nothing, and clears stale move-speed overrides so the sprint
  applies to live zombies. Toggle (each use on/off) kept.
- **Boss bar:** overlapping world-space waypoints (bg + fill) rendered as only the black
  box, so the bar is now a SINGLE red icon whose width = the health fraction.
- **Floating damage numbers DISABLED** (no more stray top-left number). Hard BO3 rule
  proven in-game: world-space TEXT is impossible (`SetWaypoint` suppresses text; no
  `SetWaypoint` dumps to 0,0; no `WorldToScreen`). The correct version (world-projected
  digit ICONS or a LUI world widget) is being researched + built next.

### Overhaul batch 3 — test-feedback fixes (2026-06-13)

In-game test of batches 1-2 surfaced:
- **PaP gun-steal (showstopper):** our parallel `acc_pap_tier` trigger (same origin as
  the stock machine) EATS the Use during a stock first-pack take-back, so the packed gun
  never returned (`SetInvisibleToPlayer` hides the hint but does NOT stop a trigger
  firing). Fix: `pap_tier_visibility` now `TriggerEnable(false)`s our trigger whenever
  nobody can tier up, so it can't intercept the take-back.
- **PaP tier HUD** raised (`-100`→`-175`) so the ammo HUD stops overlapping it.
- **World-space HUD TEXT was invisible** (damage numbers, boss name) while the boss bar
  ICON rendered fine. Root cause proven in-game: `SetWaypoint` puts the elem in icon-only
  waypoint mode and SUPPRESSES text. Fix: text elems now use `SetTargetEnt` WITHOUT
  `SetWaypoint` (icons keep `SetWaypoint(false)`). Boss bar bg made a few px larger than
  the red fill so it reads as a framed bar, not a black box.
- **Rampage Inducer:** the trigger could only turn ON (`if(active) continue`) and the
  sprint effect wasn't visibly faster. Fix: the device is now a TOGGLE (each use flips
  on/off) and the effect layers a proven-visible `ASMSetAnimationRate(1.7)` (the
  mechanism early-pacing/Widow's Wine use) on live + new zombies, restored to 1.0 on off.

(Flicker fix from batch 1 confirmed working in-game.)

### Overhaul batch 2 — damage numbers + boss bar over the head (item 8) (2026-06-13)

Root cause (audit + a verified-pattern agent): `hud::createFontString` /
`createServerFontString` / `createServerBar` all `setParent(level.uiParent)` → the
elem binds to the SCREEN layer, so `SetTargetEnt` + world `.z` are ignored and it
clamps to the top of the screen (the bug hit twice). And `WorldToScreen` does NOT
exist in BO3, so per-frame screen projection is impossible. Fix = the stock
`entityheadicons` follow pattern, mirroring our working door markers: raw
`NewClientHudElem` (NEVER a `hud::create*` factory) + world `.z` offset +
`SetWaypoint(false)` + `SetTargetEnt(ent)`.
- **Damage numbers** (`_acc_dev::show_dmg_number`): `NewClientHudElem(attacker)` +
  `SetText` + `SetTargetEnt(anchor)` over the zombie, rise + fade. (The old
  screen-parented version proved the text renders — it was only mis-positioned.)
- **Boss bar** (`_acc_health_bars::boss_bar_track`): per-player `NewClientHudElem`
  dark bg + a "white" fill icon whose WIDTH scales with the health fraction (stock
  `updateBarScale` math) + a name text elem, all following the boss in world space.

All builtins verified vs the stock mirror; build exit 0. One in-game unknown (no
stock precedent for TEXT on a `SetTargetEnt` elem) — but the prior attempt's text
DID render (just mis-placed), so confidence is high; the icon bar is stock-proven.

### Overhaul batch 1 — PaP HUD/flicker, rampage in spawn (2026-06-13, MajorImprovements)

First slice of the 9-item overhaul (full code-cited tracker: **docs/29_overhaul_checklist.md**,
built from a 15-agent audit: per-perk requirement→code proof + per-area gaps/fixes).
- **(1) PaP tier HUD → bottom-right** (`_acc_pap_levels::pap_hud_loop`, was bottom-left).
- **(9) Multi-pack flicker fixed:** the stock `pack_a_punch_machine_trigger_think`
  VISIBILITY loop (0.1s) kept re-showing the stock trigger for upgraded guns and
  fought our 0.25s `pap_tier_visibility` → hint flicker. We now `notify(
  "pack_a_punch_trigger_think")` to stop ONLY that visibility loop (the first-pack USE
  handler `vending_weapon_upgrade` is a separate thread and still works); our loop
  owns the stock trigger's visibility (shown un-upgraded / hidden upgraded). Re-killed
  each tick for robustness.
- **(4) Rampage Inducer relocated into the spawn plaza** (`(-1881,1900)`→`(-600,200,14)`,
  inside `start_zone`, facing spawn). The device + enrage effect were already
  implemented/wired; it was just spawning outside the start room. (Audit also notes
  an optional BO4/CW timed-enrage mode — deferred.)

Audit headline gaps queued (docs/29): ~30 perk benefits claimed-but-unimplemented
(several GSC-impossible — recoil/fire-rate/move-speed — need weapon-GDT or card
re-scope); damage numbers + boss bar need the world-space `NewClientHudElem` +
`SetWaypoint(TRUE)` rewrite; arsenal strip to ICR-1 (`ar_accurate`) + Man-O-War
(`ar_damage`); PaP card next-tier-only; real perk-icon glow; room-halving (high risk).

### Changed — perk info card rebuilt in premium LUI (2026-06-13)

The perk/PaP info card (UI touchpoint 1, docs/27) is now a premium **LUI** widget,
replacing the server-HUD card whose bulleted text mis-rendered outside the box
("the descriptions aren't even in the card"). Split of concerns:
- **`_acc_perk_info.gsc` = the BRAIN only:** per player it finds the nearest machine
  + context (buy/mega/maxed/pap) and pushes a single int "card code"
  (`perkIndex*4 + mode`, 0 = hide) via a new `clientuimodel` field **`accPerkCard`**
  (`acc_lui::set_perk_card`). Its old `show_card`/`card_data` + `acc_ui` rendering
  is retired (text now lives in the Lua display layer).
- **`acc_hud.lua` = the card:** a classed LUI widget `CoD.AccPerkCard =
  InheritFrom(LUI.UIElement)` (the shipped `room_manager.lua` / `inventory_control.lua`
  pattern) renders title / price / bulleted **base + Mega** benefits (or the 5-tier
  PaP ladder) from a perk lookup table, context-coloured (cyan buy / gold Mega /
  green maxed / purple PaP), right side, vertically centered.
- Mechanism is the **proven** clientuimodel-int + Lua-lookup (room_manager), not an
  unproven string push. Every LUI call verified against shipped-**active** maps + a
  dedicated adversarial review (no blockers; confirmed `LUI.UIText:setScale/setRGB`,
  the `math.floor`/`%` decode, nil guards, on-screen anchoring). Build exit 0.

### Changed — Pack-a-Punch: scaling-cost 5-tier ladder, no alt-ammo (2026-06-13)

Test feedback: PaP prices read "2500" on every re-pack, multi-pack didn't take,
and the stock alt-ammo extras (turned/fireworks/etc.) were unwanted. Reworked
`_acc_pap_levels`:
- **Stock AAT disabled** — `level.aat_in_use = false` in the entry `main()` right
  after `zm_usermap::main()` (the stock gate, defaulted true; every
  `aats/_zm_aat_*` bails when false), so no random alt-ammo reroll.
- **Stock re-pack blocked for upgraded guns** via
  `level.pack_a_punch.custom_validation = &acc_pap_block_stock_repack` (the hook
  at `_zm_pack_a_punch.gsc:399` — `self [[…]]( player )`, returning false makes
  the machine skip the gun). The stock machine now only does the **first** pack
  (tier 1, recorded by `pap_taken_watcher` off the `"pap_taken"` notify).
- **Tiers 2-5 via our own trigger** — a parallel `acc_pap_tier`
  `trigger_radius_use` at the PaP origin charges a **scaling cost** (T2 2500 / T3
  5000 / T4 7500 / T5 10000) through `zm_score::can_player_purchase` +
  `minus_to_player_score`, bumping `player.acc_pap_tier[base]` (no asset re-swap,
  no alt-ammo). Per-player trigger visibility hands off cleanly: gun upgraded →
  stock trigger hidden + ours shown; gun not upgraded → vice-versa.
- Held-weapon **tier HUD at bottom-left** next to the gun ("PaP TIER x/5").
- Damage ladder unchanged: pap_tier_mult 1.25/1.55/1.90/2.30 (= +25/55/90/130pct).
- All stock APIs re-verified against `tmp/bo3_stock_ref` before building
  (the GetMaxHealth lesson). Lint + preflight green; linker exit 0.

### Fixed — HUD `%` renders as `.`; PaP card shows scaling cost (2026-06-13)

The HUD font draws `%` as a period (screenshot: "+30. HP regen"). Replaced every
`%` with the literal "pct" in `_acc_perk_info` and `_acc_pap_levels`. The PaP
info card now lists the per-tier re-pack costs and drops the "alt-ammo" line.

### Added — reusable BO3 mapmaking knowledge base + test-feedback fixes (2026-06-13)

**docs/BO3_MAPMAKING_KB.md** (NEW) — a map-agnostic distillation of everything
learned building this map, so future maps don't re-fight it: build pipeline
(sync-before-build, direct `linker_modtools`), the full launch saga
(`+set_gametype zclassic`, DRM/junction/empty-Launch-Options/Steam-jam), GSC
dialect rules, Radiant entity recipes, verified stock APIs, the dev/test sandbox
toolkit, verification/lints, and a full gotchas catalog.

In-game test-pass fixes (round-3 session feedback):
- **Random death** = decontamination zone-seal `DoDamage`ing the player when a
  zone seals (rounds 1-4). Disabled in the hardcoded dev build.
- **Boss** announces on spawn (round 2); **Mega Bottles granted directly** so
  perk Mega-upgrades are testable without the boss.
- **Damage indicators** HUD (last hit + 1s DPS) via a read-only actor-damage
  callback (perk/OC-modified values).
- **Custom perk prices** (`set_perk_costs`): Jug 4000, QR 2500, Speed 3500, DT
  2000, Stamin 2000, Mule 2500, Deadshot 3500, Widow 4000, Aura 2500 = 26,500.
- **Zone signage** (current-zone HUD + enter banner).
- **Aura Blast** machine raw hint token → readable `SetHintString` override.

### Added — hardcoded dev test sandbox + whole-map-open (2026-06-13)

For an end-to-end test pass, the dev conveniences are now **hardcoded ON** (no
dvars) — tagged `HARDCODED` in source, to be re-gated before ship:
- **Entry-script `acc_hardcoded_dev()`** (in `zm_abandoned_cyber_city.gsc` main,
  the guaranteed-run path independent of every `_acc_` module): unlimited money
  + unlimited Data Shards + auto-power (`flag::set("power_on")`) + an on-screen
  status banner that reads `level.acc_init_complete` so it confirms the full
  `_acc_` init chain ran (`systems: COMPLETE`).
- **`acc_hardcoded_open_map()`**: opens every `zombie_door` (sets its zone
  adjacency flag + `ConnectPaths`/`NotSolid`/`Hide` on the `acc_door_*`
  script_brushmodel slab + `TriggerEnable(false)`) so the whole map is walkable
  from spawn — fixes "stuck in the start room."
- Removed the `acc_dev` / `acc_test_boss` dvar gates (boss spawns round 2 with
  10 Mega Bottles unconditionally). `_acc_main::init` sets `acc_init_complete`.
- Test guide: **docs/24_test_session.md**.

**Root cause of "I changed the code but nothing changed in game" (resolved):**
the linker compiles from the DEPLOYED `usermaps\...` copy, not the repo — edits
weren't synced before building, so every build used stale code. A 5-agent +
4-agent adversarial workflow confirmed the code was correct and isolated it to
deploy staleness. Verified the fix live: built the `.ff` directly via
`linker_modtools` after syncing, launched, and confirmed the banner firing in
`console_mp.log` (`[ SCRIPTER] [msg]^2[ACC] HARDCODED DEV BUILD LIVE`). Build
pipeline + Steam-launch-jam lessons recorded in CLAUDE.md.

### Fixed — the `tdm.gsc` black screen: gametype must be `+set_gametype` (2026-06-13)

The map black-screened on every direct launch with
`Com_ERROR: Script file not found: 'scripts/zm/gametypes/tdm.gsc'`. Root cause
(found via a 5-agent investigation + live verification): the engine builds the
gametype script path as `scripts/<session>/gametypes/<g_gametype>.gsc`, and the
**`g_gametype` dvar is reset to the session default by the engine**
(`callbacks_shared.gsc`) — `zclassic` for ZM, `tdm` for MP — so a command-line
`+set g_gametype zclassic` is overwritten before the gametype script loads and
it falls back to the missing `tdm.gsc`. The Mod Tools Launcher applies the
gametype through a different hook: the engine command/dvar **`set_gametype`**
(its "Set a gametype to load with map" knob). Fix: pass **`+set_gametype
zclassic`** (before `+devmap`), not `g_gametype`. Verified live — clean load to
~4.7 GB, no `Com_ERROR`. `tools/run_game.ps1` + `PLAY_TEST_MAP.bat` updated;
full four-gotcha launch runbook in **docs/23_launch_runbook.md**; hard-won fact
added to CLAUDE.md. NOT a rebuild issue (the error fires before any `_acc_`
module loads; the fastfile was current and healthy throughout).

### Added — in-game launch fix + test sandbox + Rampage Inducer (2026-06-13)

**Launch.** First successful in-game load. The Mod Tools Launcher "Run" trips
BO3's Steam DRM ("Steam must be running to play this game" → exits) because it
launches `BlackOps3.exe` directly. Launching **through Steam**
(`steam://run/311210//<args>`) gives the proper DRM context and the map loads
(verified: RAM climbed to ~4.8 GB, responding). New `tools/run_game.ps1` wraps
this; `SETUP_WINDOWS.md` §2c rewritten. `steam_appid.txt` + the usermaps
junction are necessary but not sufficient on their own.

**Rampage Inducer** (`_acc_rampage_inducer.gsc`, new) — typical functionality:
once activated, every zombie sprints and the wave spawns faster/denser.
Activate via dvar `acc_rampage 1` (toggles off with `0`) or an optional in-map
`acc_rampage_inducer` trigger. Mechanism: chains BOTH `level.max_zombie_func`
(+50% on-screen) and `level.func_get_zombie_spawn_delay` (×0.25 interval) in
`post_zm_main` — the delay must chain the **function**, not the value, because
stock recomputes `zombie_vars["zombie_spawn_delay"]` every round (_zm.gsc:4502).
Sprint uses `set_zombie_run_cycle_override_value("sprint")`, stock's own
permanent-speed lock. Also makes the previously-stubbed `sprint` modifier real.

**Dev/test harness** (`_acc_dev.gsc`, new; gated on `acc_dev 1`) — unlimited
money (tops each player to ~1,000,000 via `zm_score::add_to_player_score`),
perk cap raised to 18, and **buyable-door markers**: a through-walls waypoint
(`SetShader("white")` + `SetWaypoint` + `SetTargetEnt`, zero asset risk) over
each closed buyable door, destroyed once the door's `script_flag` is set. Doors
stay closed — they're just findable now (user couldn't locate them first play).

**Test boss** now drops **10** Mega Bottles (was 1) — `spawn_juggernaut_host`
takes an optional bottle count; `watch_mini_boss_death` bulk-grants it. Still
gated on `acc_test_boss 1`, spawns from round 2. `run_game.ps1` enables
`acc_dev` + `acc_test_boss` by default (`-NoDev` / `-NoBoss` to opt out).

PaP confirmed already placed (`vending_weapon_upgrade_spawnable`, start room).
Lints + preflight all green (25 scriptparsetree files, 23 `_acc_` modules).

### MILESTONE — first clean compile + link (2026-06-12) 🎉

`zm_abandoned_cyber_city` builds end-to-end on the real BO3 Mod Tools:
cod2map (BSP + navmesh), Radiant LED lighting, and the linker all complete
with **no errors** — both the main fastfile and the localized
`en_zm_abandoned_cyber_city` fastfile write to `zone_out\`. All 21 `_acc_`
GSC modules + the entry `.gsc`/`.csc` compile clean.

Total first-compile shakeout: **6 fix passes** over real linker output, each
a distinct, codebase-wide-swept error class (MP skybox asset; GSC `#namespace`
ordering; ternary paren-wrapping ×9; the `class` reserved keyword; a missing
cross-module `#using`; field access on a parenthesized expression). Every
class is now covered by an automated lint in `tools/preflight_windows.ps1` +
`tools/lint_gsc_xref.js`, so they cannot silently recur. Paper-verification
(11 sessions vs the stock mirror + shipped sources) held up: the failures were
all GSC-dialect syntax/wiring nits, not logic rewrites.

Next: Run Game (`+set developer 1 +set logfile 1 +set acc_test_boss 1`) and
walk the in-game test loop (docs/18) — first runtime validation of the systems.

### Fixed — first compile, pass 6: field access on a parenthesized expression (2026-06-12)

`_acc_damage.gsc:661` had `return ( zm_weapons::get_base_weapon( w ) ).name;`
→ `Compiler Internal Error: Primitive expression field object must be either
call, variable expression, self, level, or anim`. GSC forbids `.field` on a
**parenthesized** expression. (A direct `call().field` IS allowed — stock uses
`GetPlayers().size` 15 times — so the two such calls in `_acc_coop_scaling` are
fine; only the paren-wrapped one breaks.) Fixed with a temp:
`w_base = zm_weapons::get_base_weapon( w ); return w_base.name;`.

`tools/lint_gsc_xref.js` gained two checks: a paren-aware `( expr ).field`
detector (matches the `(` back, flags grouping parens, ignores function-call
parens), and **function-pointer resolution** — `&ns::fn` and bare `&fn` (used
in `register_*` callbacks) are checked the same as calls, since a typo'd
pointer is also an unresolved external. Swept clean: the only pointer is
`&zombie_utility::default_max_zombie_func` (confirmed in the mirror).

### Fixed — first compile, pass 5: proactive cross-reference sweep (2026-06-12)

The compile reached `_acc_boss.gsc:551` with `Unresolved external
'acc_coop_scaling::special_hp_mult'` — `_acc_boss.gsc` called that function but
never `#using`'d `_acc_coop_scaling` (an earlier node-patch added the calls but
its `#using` insertion silently failed to match). Added the missing `#using`.

Rather than rebuild-per-error, swept the **whole codebase** for this class and
its siblings with a new tool, `tools/lint_gsc_xref.js` — found **only this one**
real issue. The checks (all reliable, run in preflight now):
- every `acc_X::fn()` call has a `#using _acc_X` and `fn` is defined there;
- every stock `ns::fn()` call has the right stock `#using` (hardcoded verified
  namespace→file map — `util`→`util_shared`, `flag`→`flag_shared`, etc.);
- every stock macro (`IS_TRUE`, `PERK_*`, `VERSION_SHIP`...) has its `#insert`
  (transitive `.gsh` resolution from the mirror);
- no bare `fn()` call resolves to a different acc module (missing namespace).
- Also confirmed all 21 flagged stock functions exist in the mirror (so the
  "BAD STOCK API" noise was indexer false positives, not real) — the lint
  deliberately does NOT check stock-function existence (unreliable; compiler's
  job).

Progress: 12 modules + the entry script now compile clean (cyberware,
data_shards, early_round_pacing, elites, emergency_drop, events_hack,
events_overload, main, map_randomizer, modifiers, overclocks, utility). The
remaining untested modules (boss, boss_items, mega_bottles, weapon_abilities,
points, damage, decontamination, coop_scaling, perk_aura_blast) passed all four
dependency lints, so any further error is a different class.

### Fixed — first compile, pass 4: `class` reserved keyword as a variable (2026-06-12)

GSC compile reached `_acc_elites.gsc:147` (`spawn_elites_over_round`) and
rejected `class = pick_elite_class_for_round(...)` — `class` is a reserved
keyword (TOKEN_CLASS) in BO3 GSC and can't be an identifier. Renamed to
`elite_class`. Swept the codebase for reserved words as identifiers (lvalue /
param / foreach): only this one was real. `type` flagged as a false positive —
stock uses it as a parameter (`setup_hero_rival(... type)`), so it's NOT
reserved and was left alone.

Hardening: `preflight_windows.ps1` now lints a narrow confirmed reserved-word
list (`class`) used as identifiers — kept narrow to avoid false positives.

Progress: the `.gsc.gdb` outputs show utility, main, data_shards, cyberware,
overclocks, early_round_pacing all compiled clean this pass before the elites
break — the phase-2 body compile is steadily clearing modules.

### Fixed — first compile, pass 3: GSC ternary paren-wrapping (2026-06-12)

Past the directive fix, the GSC compile reached `_acc_data_shards.gsc:185`
and rejected an unwrapped ternary: `= ( self.acc_data_shards > 0 ) ? 0.9 : 0`
(`unexpected TOKEN_CONDITIONAL, expecting TOKEN_SEMICOLON`). BO3 GSC has no
general ternary operator — it only parses a **fully paren-wrapped**
`( cond ? a : b )` (verified vs stock: `util_shared.gsc:1425`,
`:3990`, `:3996` all wrap the whole expression). Our broken sites either
closed the paren after the condition (`( cond ) ? a : b`) or were bare
(`return cond ? a : b`).

Swept **every `?` in the codebase** (the first pass's grep wrongly excluded
`::`-containing lines, hiding two `return acc_utility::...( ) == 0 ? a : b`
sites) and fixed all **9 broken ternaries** to `( cond ? a : b )` across
`_acc_boss` (2), `_acc_data_shards` (1), `_acc_mega_bottles` (1), and
`_acc_map_randomizer` (5). The 3 already-wrapped ones were left alone.
`?`-in-string-literal log messages are not ternaries (left alone).

Hardening: `preflight_windows.ps1` gained a **paren-aware ternary lint** (walk
each line at paren depth; a `?` at depth 0 is unwrapped) — catches this class
with zero false positives, unlike a regex. Would have flagged all 9 pre-build.

### Fixed — first compile, pass 2: GSC directive-ordering error (2026-06-12)

With the skybox fixed, the build reached the **GSC compile** (geometry +
Umbra + lighting all passed) and hit one syntax error:
`_acc_boss_items.gsc (15,6): syntax error, unexpected TOKEN_USING, expecting
$end`. Cause: `#namespace acc_boss_items;` was on line 13, **above** the
`#using` block — `#namespace` terminates the directive preamble, so the
following `#using` lines are illegal. Fixed by moving `#namespace` below all
`#using`/`#define`. Scanned all 21 modules: only this one had the bug; the
other 20 order `#namespace` correctly.

Signal from the compiler: it processes `_acc_main`'s `#using` list in order
and stopped on the 12th dependency, so the **11 modules before it compiled
clean** (utility, data_shards, cyberware, overclocks, elites, map_randomizer,
events_hack, events_overload, emergency_drop, modifiers, boss). The remaining
modules (mega_bottles, weapon_abilities, points, damage, early_round_pacing,
decontamination, coop_scaling, perk_aura_blast) get their first compile on the
next build.

Hardening: `tools/preflight_windows.ps1` now lints GSC directive ordering
(`#namespace` after every `#using`/`#insert`/`#define`/`#precache`) across all
modules — the brace/paren lint missed this class. Also verified all `_acc_`
`#using` paths resolve to real files and no module self-imports.

### Fixed — first compile, pass 1: MP-skybox link error + chalk-material warnings (2026-06-12)

The first real Launcher build reached the linker and died on ONE hard error
(`^1ERROR: xmodel 'skybox_mp_havoc_override' is missing`, referenced by the
gfx_map). Root cause: the stock zm-template `volume_sun` entity ships with
**MP sky settings** — `ssi1`/`ssi2` = `mp_havoc`, `ssi1_runtime_override` =
`mp_havoc_overide` — and the `mp_havoc` sun/sky asset pulls in
`skybox_mp_havoc_override`, an **MP-only skybox** that does not exist in a ZM
build. Fixed by setting all three to `default_day` (matching the worldspawn
`ssi`/`wsi` and the sun volume's primary `ssi`, which converted cleanly). The
power-on lighting-state switch (`util::set_lighting_state`) now stays on
`default_day` for every state — cosmetically the lighting no longer changes
mood on power-on, which is correct for greybox (and avoids the MP dependency).

Also cleared the two non-fatal chalk-material warnings
(`t7_zm_chalk_buy_icr1`, `t7_zm_chalk_buy_drakon`): the stock asset set has
**no ICR-1 or sniper chalk decals at all** (verified against the installed
asset list — only arak/bowie/cqw/frag/krm/kuda/m8a4/shiva/spyder/trip_mine/
triton/vmp exist). Repointed both to `t7_zm_chalk_buy_shiva` (a confirmed-
converting AR chalk) as a greybox placeholder; real imported guns bring their
own chalk later.

**Note for the next build**: the link died at a gfx_map (geometry) asset
*before* the linker reached the `scriptparsetree` GSC compilation, so the 21
`_acc_` modules have **not yet been compiled** — the next build is the first
real test of the GSC. Findings logged here as we go (standing convention:
first-compile discoveries get documented).

### Added — Windows build-readiness: preflight automation, sync fixes, Mod Tools live (2026-06-12)

- **The machine is build-ready: `tools/preflight_windows.ps1` reports ALL 20
  CHECKS GREEN** — repo integrity (map brace balance, zone↔module
  consistency), line endings, execution policy, disk/RAM, the officially
  documented Windows locale requirement (decimal symbol "."), BO3 + Mod Tools
  installs, extracted prefabs, and the synced usermap. Run it any time;
  failures print the exact fix.
- **Mod Tools detected at the AppID-suffixed folder**
  `...\Call of Duty Black Ops III 455130` (Steam name-collision layout).
  Both `sync_to_modtools.ps1` and the preflight now identify the tools root
  by `bin\modlauncher.exe` — the old folder-name detection would have synced
  into the GAME folder and the Launcher would never have seen the map.
- **Fixed a latent parse bug in `sync_to_modtools.ps1`** (`"$label:"` is a
  drive-qualified variable reference in PowerShell — the script had never
  been executed on a real Windows box). **First real sync completed**: all
  trees + the .map are in the usermap / tools `map_source`.
- **`.gitattributes` added** (`* text=auto eol=lf`): line-ending policy is
  now repo-pinned and machine-independent; Radiant's CRLF re-saves normalize
  back to LF on commit. Verified zero-churn (everything already LF).
- **[SETUP_WINDOWS.md](SETUP_WINDOWS.md) rewritten** for reality: this
  machine's verified state up top, install facts corrected against the
  open-sourced Treyarch Launcher + official guides (Mod Tools = ~25 GB base
  **+ the ~50 GB "Additional Assets" DLC** — a step the old doc omitted
  entirely; the big one-time extraction is **Radiant's first launch**, not
  the Launcher's; Launcher lists any usermap with a `zone_source/*.zone` —
  "New Map" never required, verified in Launcher source; run-options box +
  Edit→Dvars are both valid for `+set developer 1`), the evidence-backed
  top-5 first-build failures, the full in-game test loop (doors → perks →
  decon → `acc_test_boss` Mega loop), and the post-first-build priority list.
  CLAUDE.md hard constraints updated (compiles now possible via Launcher).

### Added — community techniques ledger + research knowledge base (2026-06-12)

- **[docs/22_community_techniques.md](docs/22_community_techniques.md)** —
  **142 techniques across 18 systems** mined from shipped community sources by
  a 7-agent fleet reading actual code line-by-line (elevator/transport
  choreography, endgame flow, LUI menu + HUD pipelines, custom perk kits, soul
  boxes, traps + zombie POI lure, item-drop frameworks, quest chains, sound
  states, performance budgets, publishing anatomy...). Every entry = exact
  mechanism + repo/file/line citation + how our map uses it. **Standing
  convention** (also saved to session memory): every external-codebase finding
  gets documented here; raw dossiers go to **[docs/research/](docs/research/)**
  (the 9 stock/shipped ground-truth dossiers + weapon research are now
  committed there — they're the receipts behind the `VERIFIED(acc)` code
  comments).
- **14 newly discovered verified source repos** catalogued (headliners:
  `kelson8/bo3-Zombies-Test-Map` — a working GSC→LUI purchase-menu bridge,
  the blueprint for our Cyberware tree UI; `Scobalula/Bo3CWStyleItemDrops` —
  weighted item-drop framework for physical Data Shard pickups;
  `Owen-C137` Aetherium HUD (clientfield→LUI pipeline, bit-packed state) +
  sawblade trap kit; `Resxt/T7-Scripts` soul boxes/challenges/buyable ending;
  `shidouri/T7-GDT-Backup` — greppable stock GDTs, the asset-layer ground
  truth we lacked). CLAUDE.md ground-truth section updated.
- **First technique applied immediately**: `level.perk_purchase_limit = 9` in
  the entry script — the writable stock field for the perk cap
  (`_zm_perks.gsc:43`, shipped precedent in two maps) closes the
  **no-perk-cap requirement** that was waiting on a planned `_acc_perks.gsc`
  override. Checklist: 202/471.

### Added — full requirements push: doors+boxes+terminals, decontamination, co-op scaling, effect consumers, visual map design (2026-06-12, second ultracode pass)

9-agent file-owned implementation fleet + map pass 3 + integration. Tracker
now at **201/471 implemented** ([docs/20_requirements_checklist.md](docs/20_requirements_checklist.md));
everything still open is categorized with reasons + unblock steps in
**[MISSING_REQUIREMENTS.md](MISSING_REQUIREMENTS.md)**.

- **Visual map design**: [docs/map_design.svg](docs/map_design.svg) (+ .png) —
  rendered from the LIVE .map by `tools/gen_map_design.js` (parses the entity
  lump): all 7 zones, 8 corridors, every perk/wallbuy/box/door/terminal/
  power/spawn marked with legend. Linked from docs/03.
- **Map pass 3** (`tools/gen_interactives.js`, one-shot): 8 buyable doors
  (trigger_use + sliding script_brushmodel slab per corridor, costs
  750/1000/1250/1500, script_flag `enter_*`; zone adjacency flags switched
  from always_on to the door flags — zones now open by purchase); 3 inline
  Mystery Boxes replacing the single template box (zbarrier_zmcore_MagicBox +
  treasure_chest_use struct pairs with `acc_box_market/corp/roof` noteworthy
  pairing, KVPs verbatim from the shipped box_start.map — the randomizer's
  initial-box roll is now live); 2nd power switch (Vault) with
  `script_string` side tags; acc_cyberware_kiosk + acc_overclock_terminal
  (Lab), acc_hack_terminal (Corp), acc_overload_terminal + point (Vault),
  acc_power_corp/vault emergency-drop triggers, acc_pap_block_server/roof
  brushes (both Lab corridors), acc_boss_spawn struct (Lab).
- **NEW `_acc_decontamination.gsc`**: docs/03 hazard complete — per-run
  permutation of the 4 eligible zones, rounds 1-4 contaminate one each
  (20s evac warning + countdown, stragglers die via the stock kill path),
  permanent seal (spawning disabled + kill-on-reentry monitor), emits
  acc_decontamination_start/complete; **Lab perk rotation now keys on
  acc_decontamination_complete** (the docs-mandated timing), every round.
- **NEW `_acc_coop_scaling.gsc`**: regular zombie HP +100%/player (delta vs
  stock's own scaling, via the level.zombie_init_done hook), elites/bosses
  +50%/player (`special_hp_mult()` consumed by elites + both boss spawns),
  spawn rate +30%/player (max_zombie_func chained after early pacing).
- **`_acc_damage.gsc`** is now the single consumer of every damage-side
  contract flag: Cyberware Amplifier ×1.15 + Overload crit chain, Kinetic
  Battery 3× discharge (accrual added in `_acc_points` — 10 kills),
  Precision Mode (3 auto-crit ×4) + Slug Round (×3) ability flags, the
  damage-shaped Overclocks (Overpressure ADS ×1.5, Piercing/Penetration/
  Breach shield-bypass, Reactive Powder headshot AoE, Adaptive Aim refund),
  Shielded-elite frontal ×0.25 resist with pierce/explosive counter-play.
- **`_acc_cyberware.gsc`**: all 9 node effects real — Phase Step (slide →
  160u blink through zombies, walls block, 6s CD), Ghost Protocol (2s
  still → stock ignoreme cloak), Meltdown (no-chain corpse AoE with kill
  attribution), Caching (2× bleed-out via the stock laststand multiplier
  field), plus crouch+use respec at the kiosk (3-Shard tax, once/run,
  never T3).
- **`_acc_boss.gsc`**: mini-boss rounds now REPLACE the wave
  (level.zombie_total=0 at boss round start); full boss Subroutine Core is a
  real damageable actor spawned at acc_boss_spawn (stationary, failsafe+
  enemy-count exempt — boss rounds 30+ run normal waves alongside);
  acc_boss_dead carries killer payload; co-op HP scaling applied.
- **`_acc_events_hack.gsc` / `_acc_events_overload.gsc`**: both events
  completable end-to-end against the placed terminals (3-stage hack,
  90s overload defense at the point struct), kill counting via the verified
  death-event callback, sr2a retry honored, shortcut reward no-ops with a
  log until its geometry exists (design call — see MISSING_REQUIREMENTS).
- **`_acc_elites.gsc`**: per-round shard-diminish counter reset, co-op HP,
  quota table verified vs docs/11; **`_acc_map_randomizer.gsc`**: all three
  TODO applies real (dead power switch DELETED pre-tick by side tag; PaP
  blocker hidden/connected on the open side; wallbuy pool rewrites the
  post-init purchase layer — struct rewrite is provably unsafe client-side);
  **`_acc_weapon_abilities.gsc`**: Precision/Slug/Whirlwind real, weapon
  table fixed to verified class names, GDT-bound abilities honestly stubbed.
- 22 items confirmed unresolvable from this machine — all documented with
  what's needed in MISSING_REQUIREMENTS.md (headline: everything is
  compile-unverified until Mod Tools exist on a Windows box; imports need
  the Skye packs downloaded; recoil/fire-rate/LUI effects need Phase 4
  GDT/csc work).

### Fixed — adversarial verification pass over the zones+mega+boss commit (2026-06-12)

15-agent verify pass (one adversarial reviewer per changed file/aspect +
independent refutation judges; zero findings refuted). All confirmed defects
fixed in the same day:

- **Sky hull sealed off the Lab** (the big one): the template skybox's north
  wall sat at y≈2900 — the Lab, both Lab corridors, and the north 500u of
  Vault/Roof were OUTSIDE the sealed hull, making all 9 perk machines, PaP,
  and Bowie permanently unreachable (and zombies spawning at the northern
  risers unable to path). Extended the hull (north wall + floor/ceiling/east/
  west sky brushes to y=4300) and the sun + umbra volumes to match.
- **Cherry hijack hole #1**: the stock cherry module also wires
  `level.custom_laststand_func` — downing with Aura Blast fired Electric
  Cherry's laststand AOE (DoDamage + STOCK points bypassing our economy).
  Replaced with a visionset-only stub (`_zm.gsc` skips the standard laststand
  visionset for cherry-perk holders, so the stub re-applies it).
- **Cherry hijack hole #2**: cherry's machine-setup KVPs are a Treyarch
  placeholder naming the machine `vending_marathon` — Stamin-Up's think loop
  captured our Aura Blast machine (reskinning it as Stamin-Up) while cherry's
  own think scanned `vending_electriccherry` and found nothing. Fixed by
  renaming the spawned machine/trigger at init and bouncing both
  `perk_machine_think` loops (PERK_END_POWER_THREAD endon).
- **Boss soft-lock combo**: the host was counted toward round end AND opted
  out of the stuck-zombie failsafe — a pathing-stuck boss = round never ends.
  Removed the failsafe opt-out (boss death is the reward trigger; a stuck
  boss now self-cleans); header comment corrected (boss is ADDITIVE to the
  wave — replacement still open in the checklist). Also switched to the stock
  `set_zombie_run_cycle("run")` setter and made `acc_test_boss` re-sampled
  every round so the console toggle works mid-match.
- **Move-speed last-writer-wins bug**: Flash's read-modify-write ×1.12 was
  silently erased by Neural Boots / Reflex T1 absolute writes (and its
  removal could push speed below baseline). Centralized: ONE recompute
  (`acc_utility::recompute_move_speed`) owns `SetMoveSpeedScale`; boots /
  rx1 / Flash all set flags and call it.
- **HUD counters anchored mid-screen**: `setPoint("BOTTOMLEFT")` is not a
  recognized token (stock only matches "BOTTOM_LEFT"/"BOTTOM LEFT") — both
  counters silently rendered near screen center. Fixed both.
- **Minigun powerup short-circuited our damage callback** (registered first,
  returns non-−1 for every minigun hit): headshot multipliers + 70/30
  contribution were skipped for minigun fire. Our callback now runs first
  and passes minigun hits through (recording the contribution) so stock
  minigun balancing still applies; the wrong ordering comment fixed.
- **Map data fixes**: 3 dog_location structs were inside obstacle brushes
  (market stall / corp fountain / roof obstacle — dogs would teleport into
  solid and stall dog rounds); frag wallbuy model struct 0.5u inside the
  vault wall; 3u zone-volume coverage gap in the spawn↔market doorway.
  Aura Blast also got: chord-drain (holding crouch+melee can't auto-dump the
  Mega second charge) and Widow's-Wine-web coordination on the shared
  ASMSetAnimationRate.

### Added — 7-zone greybox + Mega upgrades + real mini-boss + requirements tracker (2026-06-12, ultracode pass)

Backed by a 39-agent audit (471 requirements extracted and statused vs the
real code+map) + 9 stock/shipped ground-truth dossiers + a 27-agent weapon
import research pass (23/23 sources URL-verified). New tracker:
**[docs/20_requirements_checklist.md](docs/20_requirements_checklist.md)** —
work top-down from it.

- **7-zone greybox map** — the whole docs/03 zone graph is in the .map:
  market/alley/corp/vault/roof/lab rooms + 8 corridors (exactly the 8 graph
  edges; no Spawn↔Corp or Corp↔Lab shortcut), per-zone `info_volume`
  (player_volume, target `<zone>_spawners`) + 4 risers + 1 dog struct each,
  training geometry (spawn debris loop, market stall row, corp fountain +
  S-curve, roof central obstacle), spawn-perimeter corridor cuts. Generated
  deterministically by `tools/gen_zone_greybox.js` + applied by
  `tools/apply_zone_greybox.js` (one-shot scripts, refuse to double-apply).
  Gameplay set relocated to doc zones (`tools/apply_entity_moves.js`): all 9
  perk machines + PaP + Bowie → Lab; ICR-1 + Sheiva wallbuys + power switch →
  Corp; Haymaker → Alley; Drakon → Roof; Frag → Vault; Mystery Box → Market.
  Chalk decals moved with their wallbuys.
- **Zone manager wired** — entry script `usermap_test_zone_init` now makes 8
  `zm_zonemgr::add_adjacent_zone` calls on the always-set `"always_on"` flag
  (VERIFIED: an info_volume alone does nothing — zones only exist once
  zone_init runs via adjacency/init list, `_zm_zonemgr.gsc:288/:595`; the
  shipped `zm_alien_isolation` works exactly this way). Buyable doors arrive
  next pass (swap flags to door `script_flag` "enter_*" KVPs).
- **Mega Bottle upgrades are live end-to-end** — `_acc_mega_bottles.gsc`:
  - Machine interaction: parallel `trigger_radius_use` spawned at every
    `zombie_vending` trigger with INVERTED per-player visibility (VERIFIED:
    perk owners can never fire the stock trigger — `check_player_has_perk`
    SetInvisibleToPlayer's them every 0.1s, `_zm_perks.gsc:865`), shown only
    to players who own the base perk + hold a bottle + aren't Mega'd.
  - Real Mega effects: **Ultimate Tank** (+100 max HP via
    `n_player_health_boost` — the only field stock's health_reboot recompute
    preserves across revives, `_zm_perks.gsc:828`), **The Flash** (+12% move,
    multiplicative compose, re-applied on respawn — stock resets the scale,
    `zm_usermap.gsc:336`), **American Sniper** (×1.75 headshot replacing
    Deadshot's new base ×1.5, in `_acc_damage`), **Spiderman** (melee OHK on
    ordinary zombies, in `_acc_damage`), **Mega Man** (800u / 60s / 2
    charges / reduced boss stun, live-read in `_acc_perk_aura_blast`).
    Gun Slinger / Savior / Sleight Expert / Armory: flag set, effects
    TODO(acc-mega) (need engine-side hooks).
  - Sticky persistence via stock lifecycle pointers `level.perk_bought_func`
    / `level.perk_lost_func` (re-buy re-applies; Jug boost cleared on loss).
  - Display-name keys fixed to the REAL specialties (`specialty_deadshot`,
    `specialty_widowswine`, `specialty_electriccherry` — the old
    `specialty_acc_*` keys could never match).
- **Deadshot base effect implemented** — ×1.5 headshot for the shooter when
  `HasPerk(specialty_deadshot)` (docs/13), stacking with the 2×/3× map
  multiplier in `_acc_damage::on_ai_damage`.
- **Real Juggernaut Host mini-boss** — `spawn_juggernaut_host` is no longer a
  stub: spawns via `zombie_utility::spawn_zombie` + the verified
  init-flag-poll pattern, 50k HP (docs/11), mechz-mirrored durability set
  (`no_gib`/`ignore_nuke`/`ignore_round_spawn_failsafe`/...),
  `acc_is_mini_boss` for the 3× headshot rule, death watcher drops boss item
  (50%) + **1 Mega Bottle per player**. r10=1 / r20=2 scheduling already
  existed. **Test loop: `acc_test_boss 1` dvar** spawns a killable 1500 HP
  host every round from round 2 — the Mega loop is testable immediately.
- **Fixed two latent map-load crashes** — `_acc_data_shards` and
  `_acc_mega_bottles` registered `"toplayer"` clientfields GSC-only;
  VERIFIED vs the whole stock mirror: every toplayer field is registered in
  BOTH VMs (zero counterexamples), mismatch = load failure. Replaced with
  classic server-side hudelems (`hud::createFontString` + numeric `SetValue`,
  no localization, no .csc) — shards counter + bottle counter now actually
  render. LUI clientfield bridge returns in Phase 4 via the safe
  `clientuimodel` pool.
- **[docs/21_weapon_import_sources.md](docs/21_weapon_import_sources.md)** —
  all 7 roster imports resolved to TheSkyeLord's verified packs (B23R=`t6_b23r`,
  Tac-19=`s1_tac19`, AK-47, M14 EBR=`iw4_m14ebr`, G3, FAL, Intervention=
  `iw4_intervention`) + install recipe. Two doc corrections flagged: B23R is
  BO2 (not "MW series"), G3 is CoD4/MWR (WaW has the Gewehr 43).

### Added — start-room gameplay set: all 9 perks + 6 wallbuys in one big room (2026-06-11)

Everything currently placeable now lives in the (enlarged) start room in
**[map_source/zm/zm_abandoned_cyber_city.map](map_source/zm/zm_abandoned_cyber_city.map)**,
so all systems can be developed/tested against real machines before Phase 2
splits the map into zones (greybox placement — final layout per
docs/03_layout.md and docs/13_perks.md):

- **Deadshot Daiquiri machine** — inline `script_struct` (`targetname
  "zm_perk_machine"`, `script_noteworthy "specialty_deadshot"`, model
  `p7_zm_vending_ads`, `script_string "zclassic_perks_start_room"`), placed in
  the perk row east of Mule Kick. Format proven by shipped `zm_alien_isolation`
  (ships jug as the same inline struct, no prefab needed) + stock
  `_zm_perk_deadshot.gsh` defines (machine model/name). The entry script
  already `#using`s `_zm_perk_deadshot` and precaches `ZOMBIE_PERK_DEADSHOT`,
  so no script change was needed. Location match verified:
  `zm_usermap.gsc:122` sets `default_start_location = "start_room"` →
  `perk_machine_spawn_init` match string `"zclassic_perks_start_room"`.
- **Widow's Wine machine** — same inline-struct pattern on the new south
  wall (`script_noteworthy "specialty_widowswine"`, model
  `p7_zm_vending_widows_wine`, per stock `_zm_perk_widows_wine.gsh`).
- **Aura Blast machine + module — all 9 perks now physically in the map**:
  Quick Revive, Jug, Speed Cola, Double Tap, Stamin-Up, Mule Kick (template
  prefabs) + Deadshot, Widow's Wine, Aura Blast (inline structs). Aura Blast
  is implemented by hijacking the **stock-but-unfinished
  `_zm_perk_electric_cherry` module** (mod tools ship it with Treyarch's own
  "TODO update these to proper settings" placeholders — cost 10, machine model
  `p7_zm_vending_nuke`, Widow's Wine hint string — i.e. a complete registered
  perk pipeline waiting for real values). New module
  [`_acc_perk_aura_blast.gsc`](scripts/zm/zm_abandoned_cyber_city/_acc_perk_aura_blast.gsc)
  overwrites the `level._custom_perks[specialty_electriccherry]` entry after
  `zm_usermap::main()` (cost 2,500, our hint string, our give/take threads —
  cherry's reload-attack never attaches) and implements the docs/13 base
  tier: 400u shockwave, 3s stun via `ASMSetAnimationRate` (the verified stock
  slow mechanism), 120s cooldown, full bosses immune, **crouch+melee chord**
  activation (BO3 has no console-command script notify — VERIFIED in
  `_acc_weapon_abilities.gsc`, whose weapon abilities own the ADS+melee
  chord). Entry `.gsc` AND `.csc` both `#using` the stock cherry module (the
  client half must match or its clientfield registration mismatches at load);
  zone gets the new `scriptparsetree` line; machine struct sits on the west
  perimeter wall. TODO(acc-localize): hint shows the raw token; custom machine
  model is Phase 5 art; Mega Man tier is Phase 3.
- **Six wallbuys** — each a `weapon_upgrade` script_struct targeting a model
  struct, copied field-for-field from `zm_alien_isolation`'s shipped wallbuy
  prefabs (every weapon name + world model + chalk material below was read
  out of that map's prefab sources):
  - **ICR-1** (`"ar_accurate"`, chalk `t7_zm_chalk_buy_icr1`) and
    **Haymaker 12** (`"shotgun_fullauto"`, no chalk) on the extended north
    wall.
  - South perimeter wall, all with chalk decals: **Bowie Knife**
    (`"bowie_knife"`, targetname `bowie_upgrade` — the stock melee-wallbuy
    variant; model `wpn_t7_zmb_knife_bowie_world`, chalk
    `t7_zm_chalk_buy_bowie`), **Drakon** (`"sniper_fastsemi"`, chalk
    `t7_zm_chalk_buy_drakon`) standing in for the sniper slot until the
    Intervention import lands (docs/05_weapons.md names it the explicit
    fallback), **Sheiva** (`"ar_marksman"`, model `wpn_t7_ar_shva_world`,
    chalk `t7_zm_chalk_buy_shiva`) standing in for the M14 EBR semi-auto-AR
    slot, and **Frag Grenade** (`"frag_grenade"`, model
    `wpn_t7_grenade_frag_world`, chalk `t7_zm_chalk_buy_frag`) standing in
    for the custom EMP Grenade tactical slot.
  - That covers every roster wallbuy slot with the best stock equivalent.
    The remaining roster guns are box-only stock weapons (Brecci, XR-2,
    Locus, Drakon — already in the stock box pool) or unported imports
    (B23R, Tac-19, AK-47, M14 EBR, G3, FN FAL, Intervention) and the custom
    EMP grenade — those need GDT/asset porting on the Windows box (Phase 4,
    docs/05_weapons.md import notes; NOT plug-and-play: each needs APE
    conversion + a `weaponfull` zone line).
  - Costs come from the stock `zm_levelcommon_weapons.csv` table for now; our
    pricing is a Phase 3 script pass.
- **TODO(acc-geom)**: Haymaker and Drakon model structs reuse
  `wpn_t7_ar_talon_world` (ICR-1's real world model; shipped prefabs prove a
  mismatched model still functions — the shipped drakon prefab itself uses
  the talon model — it only drives trigger bounds + post-buy display). Swap
  to their real world models once verified in APE on the Windows box.
- **Room enlarged to a full arena** — five new worldspawn brushes
  (`script_wall`, plane format cloned from the adjacent template brush):
  north wall extension (x 518.5→732.5, y 419.5–439.5) backing the new
  machine/wallbuy row and closing the NE floor gap, plus a perimeter around
  the whole template floor slab (south/north/west/east walls at the slab
  edges: x −1056→1094.5, y −1073.5→928, 20 thick, 256 tall). Playable space
  is now the entire ~2150×2000 slab. Zombie entry path is unchanged (window
  barricade; both riser structs and the dog spawner are in-room and inside
  the perimeter).
- **Already present from the template copy (no change needed)**: Mystery Box
  (`box_start` prefab — verified: single-chest maps ignore
  `level.start_chest_name`, stock `_zm_magicbox.gsc` size==1 branch), the six
  template perk prefabs, PaP, power switch.

### Fixed — stock-API verification pass (multi-agent, vs real Treyarch sources)

Every stock-API touchpoint in all 20 GSC files was verified claim-by-claim
against a local clone of the stock scripts (one verifier agent per file + 4
external-evidence researchers + adversarial re-check of every finding):
**211 verified clean, 52 confirmed issues fixed, 5 findings refuted.** Full
ledger with citations: **[docs/19_stock_api_verification.md](docs/19_stock_api_verification.md)**;
every fix is marked `VERIFIED(acc)` in code with stock `file:line` evidence.
The big ones (each was a silent no-op or hang, not a compile error):

- **Damage pipeline was dead**: `callback::on_ai_damage` is register-only in BO3 (no dispatch site exists in stock). Rewired `_acc_damage.gsc` to `zm::register_actor_damage_callback` with the real 12-arg signature and `-1`-passthrough return convention — headshot multipliers and damage tracking now actually run.
- **All "zombie_killed" listeners were dead** (points, elites, hack event): that notify is player-entity/no-args/insta-kill-only. Rewired to `zm_spawner::register_zombie_death_event_callback` (runs on the dying zombie, attacker arg, `self.damagemod`/`self.damagelocation`).
- **Stock kill points were never suppressed** (players would have earned stock 60/130 ON TOP of our 40/100/100): now zeroed via `zm_score::register_score_event("death"/"ballistic_knife_death")`. Point shares re-quantized to 10-pt units because `add_to_player_score` rounds UP to multiples of 10 (a 2-contributor 40-pt kill would have paid 50).
- **Flag-vs-notify hangs**: `"power_on"` and `"initial_blackscreen_passed"` are flags — five bare `level waittill` sites (entry script, main, modifiers, randomizer) replaced with `flag::wait_till`.
- **Zombie speed boost never applied**: `on_ai_spawned` dispatches with no args on the actor — handler rewritten zero-param/self, and switched from player-only `SetMoveSpeedScale` to `ASMSetAnimationRate` (the Widow's Wine mechanism).
- **Wrong weapon/perk identifiers**: BO3 names are class-based (`"shotgun_fullauto"`, `"ar_accurate"`, `"sniper_fastsemi"`, `"bowie_knife"`...) — all `<name>_zm` strings replaced; perk specialties corrected to `specialty_doubletap2`/`specialty_staminup`; melee mod string `MOD_MELEE_ASSASSINATE`; dead `"j_head"` hitloc removed.
- **Compile blockers**: GSC has no `obj.(name)` dynamic-member syntax (overclock flags now string-keyed arrays); two missing `#using scripts\codescripts\struct;`; calls to nonexistent `util::waittill_round`, `zombie_utility::get_active_zombie_spawners`, `level._zm_is_power_on()`, `zm_power::turn_power_off_all`, `zm_perks::perk_lose_on_damage` replaced with the real stock APIs (`between_round_over` loop, `level.zombie_spawners`, `flag::get/clear/set`, `perk_pause_all_perks`).
- **Ordering bugs**: `level._zombie_custom_add_weapons` must be set BEFORE `zm_usermap::main()` (consumed synchronously inside); Mystery Box initial location must be set in pre_init via `level.start_chest_name` (stock reads it ~0.05s after init); boss phase-runner threaded so its `acc_boss_dead` waittill arms before the notify; elite promotion now waits for `zombie_init_done` (frame-end spawn func clobbers health); elite teleports clamped to navmesh; Neural Boots speed re-applied each spawn (usermap template resets it); downed-player check fixed (`player.isdowned` doesn't exist → `zm_utility::is_player_valid`); direct `player.score` writes replaced with `zm_score::` API; roguelike down-watcher moved to per-player with refire debounce; express modifier now actually skips to round 10 (`zm_utility::zombie_goto_round`); emergency-drop powerups and random perk wired to the real stock helpers.
- **[docs/16_gsc_reference.md](docs/16_gsc_reference.md)** — the callbacks/damage/scoring sections were the SOURCE of several of these bugs (forum-derived, wrong); rewritten with mirror-verified dispatch sites, the on_ai_damage/on_ai_killed trap warning, flag-vs-notify, scoring quantization, and weapon-object rules. **[docs/18_first_build_checklist.md](docs/18_first_build_checklist.md)** known-risks list shrunk accordingly (subfolder layout, sound line, and `#define` risks all proven safe via shipped maps).
- External evidence (4 research agents): GSC subfolders under usermaps are proven by shipped Workshop maps (zm_nuked, UGX Mod) — our layout stays; our `.zone` validated line-by-line against 7 shipped zones; Workshop publish flow documented (Launcher generates `workshop.json`, publish does not verify a build exists — link first).

### Added — starting-room build kit (e2e path to Workshop)

- **[map_source/zm/zm_abandoned_cyber_city.map](map_source/zm/zm_abandoned_cyber_city.map)** — Radiant map source: byte-identical copy of the stock Launcher zm template starting room (player spawns, barrier + zombie spawner, `start_zone` info_volume, perk slots, PaP, Mystery Box, power switch, intermission/respawn structs, sun/umbra volumes). Sourced from the Launcher `rex/templates` ZM Base template; deliberately unmodified so the first compile is the known-good path.
- **[zone_source/zm_abandoned_cyber_city.zone](zone_source/zm_abandoned_cyber_city.zone)** — proper BO3 `.zone` manifest (`>class,zm_mod_level`, `col_map`/`gfx_map`, `scriptparsetree` for all 20 scripts, `zm_levelcommon_weapons.csv` stringtable). **Replaces** `zone_source/zm_abandoned_cyber_city.csv`, which used a WaW-era `rawfile`/CSV format BO3 does not read.
- **[sound/zoneconfig/zm_abandoned_cyber_city.szc](sound/zoneconfig/zm_abandoned_cyber_city.szc)**, **[zone/](zone/)** (loading/preview images + `workshop.json.example`) — the remaining files the Launcher build + Workshop publish expect.
- **[docs/18_first_build_checklist.md](docs/18_first_build_checklist.md)** — turnkey sync → compile → run → publish → subscribe walkthrough with failure-mode table and an honest "known risks" list.

### Changed — BO3-correctness fixes (the old scaffold would not have compiled)

- **All 18 `_acc_*.gsc` modules** — converted from WaW-era to BO3 GSC: `function` keyword added to all 206 definitions, `#namespace acc_<name>;` declared per module (file keeps the `_acc_` prefix, namespace drops the underscore, mirroring stock `_zm_utility.gsc` → `zm_utility::`), all cross-module call sites renamed (`_acc_x::` → `acc_x::`), stock namespaces corrected (`_zm_score::` → `zm_score::`, `_zm_utility::` → `zm_utility::`, etc.).
- **Entry scripts moved** from `maps/zm/` (WaW convention, wrong for BO3) to **[scripts/zm/zm_abandoned_cyber_city.gsc](scripts/zm/zm_abandoned_cyber_city.gsc)** / `.csc`, rebuilt on the stock template structure: `zm_usermap::main()` bootstrap (BO3 has no `_zm::main()`; `load::main()` runs inside the usermap framework), `start_zone` zone manager registration, stock starting weapon/points, then our three hooks (`acc_main::pre_init()`, `acc_early_round_pacing::post_zm_main()`, threaded `acc_main::init()`).
- **`_acc_main.gsc`** — removed the `client_init()` cross-VM path: a `.csc` cannot call into `.gsc` modules (separate VMs). Client-side `_acc_` work returns as real `.csc` files with the Phase 4 LUI pass. The new entry `.csc` is pure stock template.
- **[tools/sync_to_modtools.ps1](tools/sync_to_modtools.ps1)** — new layout: `scripts/`, `zone_source/`, `sound/`, `ui/` mirror into the usermap; `zone/` copies without deleting (Launcher writes `workshop.json` there); the `.map` single-file-copies into the game root `map_source\zm\` (where Radiant reads it — never mirrored, that folder holds `_prefabs/` and other maps). Reverse mode never deletes repo files; run it after every Radiant session.
- **[SETUP_WINDOWS.md](SETUP_WINDOWS.md)** — rewritten as the complete blank-machine → published-Workshop-build path: prerequisites (BO3 ownership, ~170 GB disk), line-endings guard at Git install/clone (`core.autocrlf false` — protects `.map`/`.gsc`), PowerShell execution-policy unblock, sync verify paths, build → test (dev console, expected `[acc]` output) → publish (workshop.json capture via `-Reverse` sync) → subscribe-and-verify, day-to-day iteration loop, expanded troubleshooting.
- **Docs aligned**: README (layout, conventions, first-compile status), tools/README (mapping table + modes), module README (call order via `zm_usermap::main()`, namespace convention), 01_toolchain (directory layout, `map_source` location, zone manifest pitfall), 05_weapons / 06_mechanics / 16_gsc_reference (manifest format, `weaponfull` lines, no `_zm::main()`), 08_milestones (Phase 2 deliverables).

### Changed

- **[docs/13_perks.md](docs/13_perks.md)** — **Base + Mega merged**: roster table adds **Base** and **Mega** summary columns (readable in one pass). Nine subsections each have **Base (full description)** and **Mega: … (full description)** prose paragraphs plus **Mechanics** bullets. **[Mega Bottles (system)](docs/13_perks.md#mega-bottles-system)** keeps acquisition, persistence, HUD, implementation. Cross-links updated in [REQUIREMENTS.md](REQUIREMENTS.md), [11_enemies.md](docs/11_enemies.md), [12_boss_items.md](docs/12_boss_items.md), [14_controls_and_hud.md](docs/14_controls_and_hud.md); comment in `_acc_mega_bottles.gsc`.
- **[docs/13_perks.md](docs/13_perks.md)**, **[REQUIREMENTS.md](REQUIREMENTS.md)** — **Stock *Black Ops III* vs this map:** [Player HP Baseline](docs/13_perks.md#player-hp-baseline) states retail **Jug** (**5** melee hits with Jug from full, **3** without); this map keeps authoritative **3 / 6** (**6** with Jug = **+1** vs stock Jug). **Speed Cola** retail = **+50%** reload + faster barrier boards — **not** faster perk drink or weapon swap (those are map-only). **Double Tap II** retail = **+33%** RoF + **double-bullet** damage model; this map documents **+3%** damage as a **stacking abstraction** for Phase 3. Wiki links added for Juggernog / Speed Cola / Double Tap Root Beer.

## [v0.14.0] - Perk rebalance (base + Mega numbers)

### Changed

- **[docs/13_perks.md](docs/13_perks.md)** — Full alignment of prose **Mechanics** with roster table: **Jug** Mega = +1 hit + **boss-ability immunity**; **QR** Mega = **×0.6** revive vs base QR + **+15% move** while any teammate is down; **Speed** Mega = **+65%** reload + **+15%** gun switch / perk drink; **Double Tap** Mega = **+50%** RoF + **+6% total** damage; **Stamin-Up** base = **stock BO3** longer sprint + faster sprint; **The Flash** Mega = longer sprint + **+12%** run + **×2** walk + **×4** crawl (**not** unlimited sprint); **Mule Kick** = **2,500** pts; **Armory** = **+30%** ammo + **+2** lethal **+2** tactical; **Deadshot** Mega = **×1.75** headshot + **no recoil**; **Widow** Mega = zombie-only **OHK** melee + **OHK** web nades on regulars + **6** web nades; **Aura** base (**bosses immune**); **Mega Man** = still 800u / 60s / 2 charges + **bosses can be stunned** (tuned). Roster table removes **“Unchanged:”** wording in favor of plain perk effects. Buying all 9 base perks = **26,500** Points. Mega damage example uses **×1.75** for American Sniper.
- **[docs/15_coop_rules.md](docs/15_coop_rules.md)** — **Mule Kick** cost callout **2,500** (was 4,000).

### Note (historical)

- Mega variant **effect numbers** in the **v0.11.0** changelog entry are superseded by this doc pass; use [13_perks.md](docs/13_perks.md) as source of truth.

## [v0.13.0] - Map layout diagram + decontamination zones

### Added

- **[docs/03_layout.md](docs/03_layout.md)** — ASCII + mermaid **map diagrams** (topology, safe vs sealable zones). **Decontamination** rules: rounds **1–4** each **permanently seal** one of **Market, Alley, Server Vault, Rooftop Helipad** (random permutation at map load); **20s** evacuation window at round start or **death**; **Spawn, Corporate Plaza, Lab never seal** (hub + progression).
- **Perk timing**: Lab **4-of-9 perk re-roll runs only after** decontamination completes — updated [docs/13_perks.md](docs/13_perks.md), [docs/06_mechanics.md](docs/06_mechanics.md) §4, [REQUIREMENTS.md](REQUIREMENTS.md). Stub comment in [`_acc_map_randomizer.gsc`](scripts/zm/zm_abandoned_cyber_city/_acc_map_randomizer.gsc) for future `acc_decontamination_complete` wait.

---

## [v0.12.0] - Early round pressure (faster + more zombies, rounds 1–4)

### Added

- **Design**: Opening rounds are no longer a slow stock walk phase. Rounds **1–4** use higher spawn totals and faster zombie movement so the start of a run is a deliberate **setup phase** (doors, lanes, Lab check, economy). See [docs/06_mechanics.md](docs/06_mechanics.md) § Early round pressure; [docs/04_progression_and_skills.md](docs/04_progression_and_skills.md) difficulty table.
- **Module** [`_acc_early_round_pacing.gsc`](scripts/zm/zm_abandoned_cyber_city/_acc_early_round_pacing.gsc):
  - `post_zm_main()` chains `level.max_zombie_func` to multiply stock output by **×1.40** (round 1) and **×1.35** (rounds 2–4), `ceil` to int. Multiplies with `level.acc_mod_round_zombie_mult` when set (e.g. Shortened Rounds).
  - `init()` registers `callback::on_ai_spawned` to apply **`setmovespeedscale( 1.15 )`** to zombies in rounds **1–4**. Skipped when **Sprint** modifier sets `level.acc_mod_force_sprint`.
- **Map wiring**: [`maps/zm/zm_abandoned_cyber_city.gsc`](maps/zm/zm_abandoned_cyber_city.gsc) calls `post_zm_main()` immediately after `_zm::main()` so the spawn override exists before round 1.
- **Docs**: [docs/16_gsc_reference.md](docs/16_gsc_reference.md) — `level.max_zombie_func( n_max, n_round )` delegation pattern.

### Constants (sync with docs)

- `ACC_EARLY_ROUND_MAX` = 4, `ACC_EARLY_SPAWN_MULT_R1` = 1.40, `ACC_EARLY_SPAWN_MULT` = 1.35, `ACC_EARLY_SPEED_SCALE` = 1.15.

---

## [Unreleased]

Tracked changes planned but not yet applied.

- Author FN FAL, Tac-19, Intervention, M14 EBR, G3, AK-47, B23R weapon GDTs (Phase 4 work).
- Author Signal Staff + Vibro Cleaver wonder weapon GSC modules.
- Author LUI widgets for all custom HUD elements (Data Shards counter, Cyberware stack, weapon status, items row, objective prompts, boss health).
- Wire ability hotkey through LUI binding screen.
- Suppress stock BO3 kill-point awards so our 40/100/100 replaces rather than adds. (Researched options documented in `_acc_points.gsc::init` comment.)

---

## [v0.11.0] - Mega Bottle perk-upgrade system

### Added

- **Empty Mega Bottle** item: guaranteed drop from every boss kill (mini + full), **1 per player**. Separate from the 6-item boss-drop pool. Counter tracked on `self.acc_mega_bottles`.
- **9 Mega perk variants** with themed names:
  - Jugger-Nog → **Ultimate Tank** (immune to boss stuns + 1 extra hit)
  - Quick Revive → **Savior** (revive at 35% time + +15% speed post-revive for both players)
  - Speed Cola → **Sleight of Hand Expert** (+65% reload + faster drink/swap/lethal)
  - Double Tap 2.0 → **Gun Slinger** (+50% fire rate)
  - Stamin-Up → **The Flash** (unlimited sprint + +10% walk + +12% sprint)
  - Mule Kick → **The Armory** (+35% ammo per gun + double grenade capacity)
  - Deadshot → **American Sniper** (+2x headshot + zero recoil)
  - Widow's Wine → **Spiderman** (grenade 1-shot zombies + hold 6)
  - Aura Blast → **Mega Man** (2x radius + 60s CD + 2 charges)
- **Mega application**: at a Lab perk machine currently dispensing a perk the player owns, consume 1 bottle → perk becomes Mega. No additional Points cost. Must be in current rotation.
- **Sticky Mega flag**: Mega state persists through death for the rest of the run. Re-buying the perk after respawn re-applies Mega automatically. Flag cleared only at run end.
- **New module** [`_acc_mega_bottles.gsc`](scripts/zm/zm_abandoned_cyber_city/_acc_mega_bottles.gsc) - bottle acquisition, inventory tracking, Mega flag storage, clientfield for HUD counter, machine-interaction entry point, display-name helpers for all 9 Mega variants.
- **HUD counter** for Mega Bottles (`Bottles: N`) adjacent to Data Shards counter, hidden when count is 0. LUI widget planned for Phase 4; `iprintln` fallback for Phase 3.

### Changed

- [docs/13_perks.md](docs/13_perks.md) - major new section "Mega Bottles (upgraded perk variants)" with acquisition loop, usage rules, persistence rule, timing tension with rotation, the 9 Mega variants in detail, co-op notes, HUD notes, implementation pointers, and 4 tuning levers.
- [docs/11_enemies.md](docs/11_enemies.md) - mini-boss and full-boss entries both list the new guaranteed Mega Bottle drop.
- [docs/12_boss_items.md](docs/12_boss_items.md) - clarifies that it covers the 6-item equippable pool only, cross-references the sibling Mega Bottle system.
- [docs/14_controls_and_hud.md](docs/14_controls_and_hud.md) - new HUD element "Mega Bottle counter" (1b) adjacent to Data Shards counter.
- [scripts/zm/zm_abandoned_cyber_city/_acc_boss.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_boss.gsc) - both `watch_mini_boss_death` and the full-boss death path now call `_acc_mega_bottles::on_boss_death` in addition to the existing `_acc_boss_items::on_boss_death`.
- [scripts/zm/zm_abandoned_cyber_city/_acc_main.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_main.gsc) - new module included in init sequence + per-player connect callback.
- [zone_source/zm_abandoned_cyber_city.csv](zone_source/zm_abandoned_cyber_city.csv) - new module registered.
- [scripts/zm/zm_abandoned_cyber_city/README.md](scripts/zm/zm_abandoned_cyber_city/README.md) - module table, call order, and per-player state conventions updated for Mega Bottle system.
- [REQUIREMENTS.md](REQUIREMENTS.md) - perk summary + code↔doc mapping include the new Mega system.

### Design Decisions Taken

- **Bottle cost is bottle only** (no extra Points). Base perk Points spend is the "first payment"; bottle is the "upgrade currency." Cleaner UX.
- **Must be in rotation** to apply Mega. Adds a second timing layer on top of the per-round rotation. If this feels too punishing in playtest, decouple (allow Mega at any machine regardless of rotation) — flagged as a tuning lever.
- **Per-player, not per-team**: each player gets their own bottle per boss kill. 4p co-op = 4 bottles per boss across the team.

### Known Balance Risks

- **American Sniper + full Cyberware/Overclock/PaP L5 stack** produces insane headshot damage (~100x+ on regulars, ~160x+ on boss headshots). Intended as a power fantasy; playtest decides if it crosses into "unfun-absurd."
- **Ultimate Tank "immune to boss stuns"** needs explicit scope — Phase 4 TODO. First-pass: fully skip all phase debuff effects. Could soften to 50%.
- **Double lethal/tactical capacity from The Armory** stacks with Spiderman's "hold 6" → Frag max becomes 8 (double of 4) with Armory alone, 6 cap with Spiderman, min of the two = 6. Clarified in the doc.

---

## [v0.10.0] - per-round perk rotation at the Lab

### Added

- **All 9 perks consolidated to the Lab** (4 perk machines: `acc_lab_perk_a/b/c/d`).
- **Per-round rotation**: at every round start (`acc_round_start` notify), machines re-roll to a random 4-of-9 perks from the full roster. No duplicates.
- New function [`_acc_map_randomizer.gsc::roll_perk_rotation(round_number)`](scripts/zm/zm_abandoned_cyber_city/_acc_map_randomizer.gsc) that emits `acc_perk_rotation_rolled` level notify on roll.
- New function [`_acc_map_randomizer.gsc::apply_perk_rotation_to_machines(rotation)`](scripts/zm/zm_abandoned_cyber_city/_acc_map_randomizer.gsc) that reads Radiant `targetname` lookups and sets per-machine `acc_current_specialty` (Phase 4 visual re-skin is a TODO).
- Listener loop [`_acc_map_randomizer.gsc::watch_round_for_perk_rotation()`](scripts/zm/zm_abandoned_cyber_city/_acc_map_randomizer.gsc) that subscribes to `acc_round_start`.
- Helper [`_acc_map_randomizer.gsc::get_full_perk_roster()`](scripts/zm/zm_abandoned_cyber_city/_acc_map_randomizer.gsc) as the single source of truth for the 9 specialty names.

### Changed

- [docs/13_perks.md](docs/13_perks.md) - slot assignment section fully rewritten: 4 Lab machines, per-round rotation, probability tables (Jug-less odds, consecutive-miss probabilities), route/patience player-adaptation notes.
- [docs/03_layout.md](docs/03_layout.md) - perk slots **removed** from Market, Corp Plaza, Server Vault, Rooftop Helipad. Lab now lists 4 perk machines. Lab's description flags it as "highest-traffic zone in the map" due to rotation visits. Randomized-elements list updated to "Perk rotation (per round)".
- [docs/07_replayability.md](docs/07_replayability.md) - perk section rewritten: per-round not per-run; probability notes; variance math updated.
- [REQUIREMENTS.md](REQUIREMENTS.md) - perk summary reflects all-Lab rotation model.
- [scripts/zm/zm_abandoned_cyber_city/_acc_map_randomizer.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_map_randomizer.gsc) - `pre_init` no longer rolls `state.perk_pool`; `apply_state_when_ready` no longer calls `apply_perk_pool`; `log_state` no longer logs perk slots (rotation logs its own per-round).

### Removed

- `roll_perk_pool()` function (replaced by per-round `roll_perk_rotation`).
- `apply_perk_pool()` function (replaced by `apply_perk_rotation_to_machines`).
- `state.perk_pool` field on `level.acc_map_state`.
- **Zone-distributed perk machines**: perk machines at Market / Corp / Server Vault / Rooftop Helipad are gone.
- Jug / Quick Revive "guaranteed in specific zone" rules. Both are now equal-weighted in the rotation.
- Old per-run 420-configuration count (replaced by per-round 126 rotations, 50 per run = far more variance).

### Known Tuning Risks

- **Jug-less early runs**: ~5% of runs will see no Jug until round 6+. If this feels terrible in playtest, options:
  1. Weight Jug 2x (roughly doubles appearance odds).
  2. Guarantee Jug in round 1's rotation (player gets Jug within a minute).
  3. Add a "hasn't appeared in 5 rounds" pity-timer that forces Jug next roll.
- **Lab choke during round transitions**: with 4 players all rushing to Lab simultaneously at round start, the zone could feel crowded. Playtest; consider widening Lab geometry if so.
- **Some rounds offer nothing useful**: if the RNG gives a player 4 perks they already own, the Lab trip is wasted. Intended tension but worth watching; if too frequent, add "skip-reroll button" (costs Points to force a re-roll).

---

## [v0.9.0] - perk overhaul

### Added

- **Aura Blast** (custom active perk, 2,500 Points) — hold [perk ability key] to stun all enemies within 400u for 3s. 120s cooldown. Replaces Lattice Bond.
- **Deadshot** (custom, 3,500 Points) — +1.5x headshot multiplier + auto-aim to head when ADS. Stacks multiplicatively with our 2x/3x headshot system. Auto-aim disabled against bosses. Replaces Void Cache.
- **Widow's Wine** (custom, 4,000 Points) — stock web-grenade mechanics + +50% damage/radius to both Frag Grenade and EMP Grenade. New addition.
- **No 4-perk cap** — stock BO3's per-player limit is explicitly removed in this map. Players can hold all 9 perks simultaneously.
- **Perk ability hotkey** (`acc_perk_ability` notify, default G / D-pad Up) — separate from weapon ability hotkey so players can chain both. Documented in [docs/14_controls_and_hud.md](docs/14_controls_and_hud.md).
- **Baseline HP rule** documented: 3 zombie melee hits to die without Jug, 6 hits with Jug. Authoritative tuning target.
- **Per-run perk lockout** — 4 of 7 rotatable perks are excluded per run (randomized). 420 distinct configurations possible.
- Console logging added to `_acc_map_randomizer.gsc::roll_perk_pool` for the 4 locked-out perks so playtest can see run state.

### Changed

- **Jugger-Nog** cost: stock 2,500 → **4,000**. HP doubling preserved.
- **Quick Revive** cost: 500/1,500 → **2,500**. Added **+30% health regen speed after damage**. Faster-revive preserved.
- **Speed Cola** cost: 3,000 → **3,500**. Added **faster perk drinking** + **faster equipment change**. +50% reload preserved.
- **Stamin-Up**: speed buff **+5% → +10%**. Changed **unlimited sprint → extended sprint** (~2x stock duration). Significant nerf to stock behavior.
- **Mule Kick** cost: stock 4,000 → **3,000**.
- **Double Tap 2.0**: unchanged.
- Perk total: 8 → **9** (added Widow's Wine; replaced Lattice Bond + Void Cache with Aura Blast + Deadshot + Widow's Wine).
- [docs/13_perks.md](docs/13_perks.md) fully rewritten with new tuning, the "Swiss Army Player" full-stack example, implementation status, and tuning levers.
- [docs/12_boss_items.md](docs/12_boss_items.md) Ghost Shroud stacking notes updated (no longer references Lattice Bond; now references Jug + Aura Blast for the clutch-survival layer).
- [docs/06_mechanics.md](docs/06_mechanics.md) - Deadshot effective damage table added; stacking chain updated; Void Cache notes in co-op section replaced with Widow's Wine + Deadshot notes.
- [docs/07_replayability.md](docs/07_replayability.md) - perk roster list corrected to 9-perk set; build archetype notes updated.
- [docs/05_weapons.md](docs/05_weapons.md) - removed inline Lattice Bond / Void Cache perk descriptions; now delegates entirely to [13_perks.md](docs/13_perks.md) with a weapon-relevance summary.
- [docs/16_gsc_reference.md](docs/16_gsc_reference.md) section 5 - custom perk creation example updated to Aura Blast (active-perk pattern). Added patterns for active perks, damage-modifier perks, and grenade-boost perks.
- [docs/08_milestones.md](docs/08_milestones.md) Phase 4 deliverables - custom perk list updated.
- [REQUIREMENTS.md](REQUIREMENTS.md) - perk summary updated to 9 perks + no cap + 3/6 HP rule.
- [scripts/zm/zm_abandoned_cyber_city/_acc_map_randomizer.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_map_randomizer.gsc) - `roll_perk_pool` updated to 7-perk rotatable pool, logs 4 locked-out per run.

### Removed

- **Lattice Bond** perk (replaced by Aura Blast).
- **Void Cache** perk (replaced by Deadshot - different role but same "3rd custom perk" slot).
- **4-perk cap** enforcement.

### Tuning Notes

Watch in playtest:
- Deadshot + 3x boss headshot multiplier + Overload Cyberware + Precision Mode ability = absurd boss-damage stack. Tuning levers in [docs/13_perks.md](docs/13_perks.md).
- Widow's Wine damage boost on Frag might make Meltdown-capstone grenade spam dominant. Consider reducing +50% to +25% if this validates.
- Aura Blast 2,500 is cheap for what it does (on-demand 3s AoE stun). Could bump to 3,000-3,500 if it trivializes mid-game.

---

## [v0.8.0] - BO3 API research + verified fixes

### Added

- **[docs/16_gsc_reference.md](docs/16_gsc_reference.md)** — BO3 GSC/CSC language + API reference doc. Verified signatures (via modme forums, bo3explorer, UGX Mods wiki) for `callback::on_ai_damage`, `_zm_score::add_to_player_score`, `clientfield::register`, `zombie_killed` notify, common utility modules, custom perk workflow, custom weapon import workflow, debug loop, common gotchas.
- **[docs/17_reference_maps_study.md](docs/17_reference_maps_study.md)** — Design patterns study covering Ameliorama I/II, Machin[a], Shadows of Evil, Der Eisendrache, Origins. What we took from each, what we explicitly rejected, open questions, maps queued for future study.

### Changed

- **[scripts/zm/zm_abandoned_cyber_city/_acc_damage.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_damage.gsc)** — `on_ai_damage` callback signature corrected to canonical BO3 order: `(str_mod, str_hit_location, v_hit_origin, e_player, n_amount, w_weapon, ...)`. Previous approximated order was wrong. Added `weapon_root_name()` helper to handle weapon struct vs string gracefully.
- **[scripts/zm/zm_abandoned_cyber_city/_acc_points.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_points.gsc)** — `award_player()` now uses `player _zm_score::add_to_player_score(pts)` instead of direct `player.score += pts`, so HUD floaters and VO cues fire correctly. Added `#using scripts\zm\_zm_score;`.
- Stock-kill-award suppression TODO upgraded to a concrete research plan in `_acc_points.gsc::init()` with three possible community-standard paths.
- **[REQUIREMENTS.md](REQUIREMENTS.md)** — new "Reference Material" section indexing the two new docs. Code↔doc mapping annotates which scripts reference the GSC reference for verified APIs.

### Resolved TODO(acc-verify) markers

- `_acc_data_shards.gsc` — `clientfield::register` signature verified.
- `_acc_data_shards.gsc` — `is_player_alive` now documented to prefer `_zm_utility::is_player_valid` when available, with a manual fallback.
- `_acc_utility.gsc` — `level.players` iteration pattern confirmed as canonical.
- `_acc_damage.gsc` — zombie team string `"axis"` confirmed.
- `_acc_events_hack.gsc` — `"head"` / `"helmet"` hit locations confirmed for headshot detection.
- `_acc_points.gsc` — `MOD_MELEE` / `MOD_MELEE_WEAPON_BUTT` / `MOD_MELEE_ASSASSINATION` as the knife MOD strings.

### Remaining TODO(acc-verify) markers

Still need first-Mod-Tools-compile verification:

- `_acc_overclocks.gsc` PaP suffix naming (exact strings).
- `_acc_map_randomizer.gsc` Mystery Box weapon registration API call shape.
- `_acc_elites.gsc` zombie spawn + promotion pipeline (stock flow is tangled; community helpers exist).
- `_acc_modifiers.gsc` `util::waittill_round` stock helper existence.
- `_acc_cyberware.gsc` exact move-speed multiplier API (`setmovespeedscale` or equivalent).

These are documented in the code with current best-guess implementations and fallback strategies.

---

## [v0.7.0] - Payroll Ledger (6th boss-drop item)

### Added

- **Payroll Ledger** boss-drop item (implant slot): +10% Points on any kill the wearer contributes to. Applied after the 70/30 co-op split (on the player's share, not the base award).
- Boss-item pool expanded from 5 to 6 items. Player inventory still 2 slots; drop chance unchanged (mini 50%, full 100%); duplicate → 3 Shards unchanged.
- `ACC_POINTS_LEDGER_MULT = 1.10` constant in `_acc_points.gsc`.
- `ACC_ITEM_LEDGER_POINTS_MULT = 1.10` constant in `_acc_boss_items.gsc` (exposed for cross-module reference).
- Helper `_acc_boss_items::player_has_ledger()`.
- Stacking rules documented: multiplicative with Double Points, independent from Void Cache tokens, cannot stack with itself.

### Changed

- [docs/12_boss_items.md](docs/12_boss_items.md) - updated item count throughout, new "Why 2 slots out of 6" rationale, new synergistic combo examples (Ledger + Battery, Ledger + Shroud), tuning levers updated.
- [docs/05_weapons.md](docs/05_weapons.md) - boss-items cross-reference updated to 6 items + Ledger interaction note.
- [docs/13_perks.md](docs/13_perks.md) - Void Cache section adds Ledger stacking note.
- [REQUIREMENTS.md](REQUIREMENTS.md) - item pool size and per-system summary updated.
- [scripts/zm/zm_abandoned_cyber_city/README.md](scripts/zm/zm_abandoned_cyber_city/README.md) - module table updated to reflect dependency on `_acc_points.gsc` for the Ledger bonus.

### Fixed

- Stale "Overclock Active Pool" text in [docs/07_replayability.md](docs/07_replayability.md) that described the pre-Tier-1-5 design ("3 per family, rerolled per run"). Replaced with the current per-tier-up draw model matching [05_weapons.md](docs/05_weapons.md).

---

## [v0.6.0] - docs established as requirements

### Added

- `REQUIREMENTS.md` at repo root. Master index of every game system with change-control policy. Designated as the authoritative requirements document.
- `docs/13_perks.md` - full perk spec (6 stock + 2 custom perks, per-run slot randomization rules, custom perk cooldown details, stacking/interaction rules, tuning levers).
- `docs/14_controls_and_hud.md` - input bindings, HUD element list with layout sketch, LUI widget file plan, accessibility notes.
- `docs/15_coop_rules.md` - consolidated co-op behavior (HP scaling, spawn-rate scaling, revive rules, per-player vs shared resources, item pickup priority, side-event activator gating).
- `CHANGELOG.md` at repo root.

### Changed

- Audited existing docs; fixed stale references to removed weapons (Sheiva, HVK-30, Gorgon, Kuda, M1911, Argus) and to the old PaP II system in `03_layout.md`, `06_mechanics.md`, `07_replayability.md`.

---

## [v0.5.0] - weapon progression overhaul + boss items

### Added

- PaP L1-L5 system (money track, 5k / 7.5k / 10k / 12.5k / 15k, cumulative +20% damage + 1 reserve mag per level, 50k total to max).
- Tier 1-5 system (Shards track, 1 / 2 / 3 / 4 / 5, each tier unlocks 1 Overclock slot, 15 Shards total to max).
- Per-category weapon abilities: Triple Tap, Stabilizer, Precision Mode, Slug Round, Thermal Vision, Whirlwind, Extended Fuse, Overcharge.
- Boss-drop item system: 5 items (Neural Boots, Overclocked Gauntlets, Targeting Visor, Kinetic Battery, Ghost Shroud), 2 player slots, mini-boss 50% / full boss 100% drop chance, duplicates → 3 Shards.
- New modules: `_acc_weapon_abilities.gsc`, `_acc_boss_items.gsc`.
- New doc `docs/12_boss_items.md`.

### Changed

- `_acc_overclocks.gsc` refactored: removed "per-run 3 active per family" roll; replaced with per-weapon tier-up draw system.
- `_acc_boss.gsc` now triggers boss-item drops on death.
- Overclock pools no longer re-rolled per run; full family pool is draftable across tier-ups.
- Docs `04_progression_and_skills.md` updated with per-sink Shard spend table showing round 30 decision tension.

---

## [v0.4.0] - kill-point overhaul + headshot multiplier

### Added

- Headshot damage multiplier: 2x regular / 3x boss, multiplicative with stock per-weapon headshot multiplier. Tac-19 explicitly excluded.
- Kill-point replacement system: 40 regular / 100 headshot / 100 knife.
- Co-op kill-point split: 70% killer / 30% pool split among qualifying damage contributors. Solo = 100%.
- Anti-exploit rules (7 hard-enforced): min-contribution threshold, per-player damage cap at maxhealth, per-player aggregation, environmental damage exclusion, disconnect handling, invalid-killer fallback, integer rounding remainder-to-pool.
- New modules: `_acc_damage.gsc`, `_acc_points.gsc`.

### Changed

- `docs/06_mechanics.md` Point Economy section fully rewritten with example payout tables.

---

## [v0.3.0] - wonder weapons and sniper rework

### Added

- Two wonder weapons: **Signal Staff** (ranged, counters Subroutine Core with +300%) and **Vibro Cleaver** (wonder melee, counters Juggernaut Host with +300%).
- Wonder weapon craft gating: Signal Staff requires Vault Overload completion, Vibro Cleaver requires Hack Terminal completion (+ 5 Shards each).
- Boss counter pairings documented in [docs/11_enemies.md](docs/11_enemies.md).

### Changed

- Sniper tier swap: Drakon promoted to **strong** (box), Intervention demoted to **normal** (wallbuy), Locus remains **bad** (box).
- Replaced previous "candidates" (Nanite Swarm / EMP Railgun / Code Injection Pistol) with committed Signal Staff + Vibro Cleaver.
- Tac-19 design locked: no headshot multiplier applies; base damage bumped to compensate; **best crowd-control gun** in the roster.

### Removed

- Wonder weapon candidate list; those three are now "post-1.0" ideas at most.

---

## [v0.2.0] - 16-weapon roster finalized

### Added

- 3-tier-per-category weapon structure: normal (wallbuy), bad (box), strong (box).
- Final roster of 16 weapons locked:
  - Pistol: B23R (import, starter).
  - Shotgun: Haymaker 12 / Brecci / Tac-19.
  - AR full-auto: ICR-1 / XR-2 / AK-47.
  - Semi-auto AR: M14 EBR / G3 / FN FAL (all imports).
  - Sniper: Drakon / Locus / Intervention.
  - Melee: Bowie Knife.
  - Grenades: Frag + EMP Grenade (custom tactical).
- Mystery Box pool registered in `_acc_map_randomizer.gsc::register_mystery_box_pool`.

### Removed

- Previous short-list weapons that didn't survive roster review: Sheiva, HVK-30, Kuda, Argus, Bulldog, Gorgon, BRM, M1911.

---

## [v0.1.0] - weapons and enemies docs split

### Added

- `docs/05_weapons.md` (weapons-only; extracted from combined `05_weapons_and_enemies.md`).
- `docs/11_enemies.md` (enemies-only, bestiary).

### Removed

- `docs/05_weapons_and_enemies.md` (replaced by two docs above).

---

## [v0.0.0] - initial project scaffold

### Added

- Repo scaffold: `README.md`, `ROADMAP.md`, `SETUP_WINDOWS.md`.
- Design docs 00-10 covering overview, toolchain, learning path, layout, progression, mechanics, replayability, milestones, language/publishing, today-quickstart.
- Radiant entry scripts: `maps/zm/zm_abandoned_cyber_city.gsc` + `.csc`.
- 12 GSC modules under `scripts/zm/zm_abandoned_cyber_city/` covering custom data shards, cyberware, elites, events, emergency drop, modifiers, boss, map randomizer, main orchestrator, utility helpers.
- Zone source CSV.
- Windows sync tooling (`tools/sync_to_modtools.ps1`).

---

## Change Entry Guidance (for future updates)

When changing the game, append a new section following this template:

```markdown
## [vX.Y.Z] - brief title

### Added
- ...

### Changed
- ...

### Removed
- ...

### Fixed
- ...
```

Keep entries tight: one line per change, link to the doc the change applies to.

Increment:
- **x** when the change breaks previous design (e.g. replacing a whole system).
- **y** when adding new systems or substantial reworks.
- **z** for bug fixes, tuning pass deltas, small doc edits.

For every entry, update the corresponding detailed doc in `/docs` and the summary in `REQUIREMENTS.md` if the change is visible at that level.
