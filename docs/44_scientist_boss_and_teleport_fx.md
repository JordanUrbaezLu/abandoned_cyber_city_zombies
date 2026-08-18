# 44 — The Scientist boss (Pentagon Thief homage) + boss teleport FX

**Status: PLANNED 2026-07-17 (assets INSTALLED same day; no code yet).**
Two workstreams sharing one FX kit:

- **A. Glitch Stalker + Phantom teleport FX** — give the two existing invisible-teleport
  bosses a visible "de-rez" blink (cyan digital dissolve + numbers burst).
- **B. The Scientist** — a new roster boss recreating BO1 *Five*'s Pentagon Thief
  (Dr. Yuri Zavoyski, the weapon-stealing "mad scientist") with downloadable
  substitutes — **the authentic-rip path was researched and dropped** (user pivot
  2026-07-17: "assume we can't get the correct model and animations").
  **World-lore anchor (2026-07-26): THE SCIENTIST'S OFFICE** — the 2000-pt buyable
  room behind the Lab N wall (docs/02, `gen_scientist_office.js`) is HIS lair: lab
  coats, chemistry, x-ray lightbox, research notes, and his desk with a "prototype"
  gun + implant free pickup — "the lure is that it's the Scientist's office, the guy
  who comes around and steals your gun" (user). The Exo station + permanent
  Juggernog live there too.

Research trail (3 verified web sweeps, 2026-07-17): memory `pentagon-thief-boss-sourcing`.
Headlines: **no drop-in BO3 thief pack exists anywhere**; **BO4 Classified CUT the
thief** (replaced by Hellhounds — the "found Classified thief model" was a Takeo
model); the only authentic model+anims live in BO1 and need a Greyhound rip + Maya
re-rig (no Maya on this box) — hence the substitute build.

## Asset inventory (ALL installed + gdtdb-indexed 2026-07-17)

| Asset | What | Boss use |
|---|---|---|
| coolyer **BO1 Nixie Numbers FX** (`share/raw/fx/misc/numbers_fx/fx_misc_nix_numbers_{normal,random,random_directions}.efx` + `gfx_fxt_misc_nixnumbers_bo1` material) | The authentic BO1 115-numbers particle FX, BO3-native `iwfx 3`, colorGraph ships white 1-1-1 (tint = ours to choose) | Red clone = Scientist aura; cyan clone = Glitch/Phantom blink |
| Ninjamanny **Ascension Zombies** (`c_t7_zm_dlchd_cosmo_labcoat_body` + gibs, full LODs, stock T7 zombie rig; labcoat/cosmo/spetznaz spawner prefabs) | ZC Ascension scientist zombie bodies, **zero rigging needed** | Scientist boss body (promoted-zombie SetModel) |
| HB21 **BO3 FX Library v2.1.0** (6,542 .efx; install-side dedupe was required — see manifest entry) | `fx_de_rez_ambient/_grey/_vista_beam` (Nuk3town digital dissolve), `fx_teleporter_elec_strike(+_os,+sparks)`, `fx_teleporter_beam_factory`, `p7_fxp_electric_arc`, BO2 portals | Blink-out/in dressing for all three bosses |
| ~~Five Vox.zip~~ | **NOT installed** — crew (JFK/Nixon/…) player vox only, ZERO thief lines; we run Ultimis | archived in Downloads |

Manifest: all three under `tools/external_assets_manifest.ps1` (Required=$false until
zone-referenced — flip when the code lands). CREDITS review before any public publish:
coolyer/Rayjiun/Oblight; Ninjamanny829; HarryBo21; + Treyarch throughout.

## Workstream A — Glitch/Phantom "de-rez blink" (visual only, no balance change)

**STATUS: BUILT 2026-07-17 (fresh .ff, linked clean) — awaiting in-game test.** As built:
`share/raw/fx/_custom/acc/fx_acc_derez_blink.efx` (vendored in repo; cyan 0.25/0.95/1;
regen `tools/tint_numbers_efx.js`) + `fx_teleporter_elec_strike_os` zap, played by
`acc_utility::derez_burst(origin)` (lazy `level._effect` registration; 0.5s
play-then-delete `tag_origin` host at +36z). Wired: Glitch combat blink (both ends;
the hidden spawn-drive teleport deliberately FX-less), `phantom_blink_to` (both ends,
covers strike + every chain hop), `phantom_back_off` (departure only — no arrival
beacon on the re-cloak point). Zone: `fx,_custom/acc/fx_acc_derez_blink` +
`fx,dlc0/factory/fx_teleporter_elec_strike_os` (both FX packs now Required=$true in
the manifest).

**PHANTOM SPECIAL TREATMENT (same day, user: "make sure the phantom gets special
treatment in fx/sfx so players know the threat"):** boss colour language originally locked
as cyan-numbers = Glitch / yellow-numbers = Phantom / red = Scientist. **SUPERSEDED
2026-08-02 (user: "that fx is only for scientists — why does the phantom and possibly
glitches have it"): the nixie DIGIT GLYPHS are now the SCIENTIST'S EXCLUSIVE identity.**
Boss styles are digit-free — `"phantom"` = zap + the EXTRA
`fx_teleporter_elec_strike_sparks_os` layer (the real boss still reads bigger),
`"glitch_boss"` (the Stalker's combat blinks) = zap only; both still READ as teleports.
The WORLD teleports (Lab/Exchange pads, perk-scatter moves, style `"glitch"`) keep their
cyan digits — ambience, not a boss identity. The yellow numbers clone
(`fx_acc_derez_blink_phantom.efx`, tint 1/0.9/0.25) + its `acc_derez_phantom` key stay
registered but unused (zero-cost, easy restore). Gate lives in
`_acc_utility.gsc::derez_burst_run`. SFX unchanged: new
alias `acc_phantom_warp` (acc_audio.csv — same warp.wav but pitch **-500..-350
cents**, louder 90/95, longer range 200/1500/2000) = the Phantom's OWN deep voice:
`materialize_scare` no longer borrows `acc_glitch_warp` (high warp = Glitch, deep
warp = Phantom), and every warp departure drops the sound as a STATIC emitter at the
vacated spot (`play_sound_at_origin` — a `self PlaySound` would teleport with the
boss). Gate dvar `acc_phantom_warp_snd` (default 1, mirrors the Glitch's). The
existing cloak-aware aura (on while materialized, winks out on cloak) already covers
the "threat visible" channel — unchanged.

Both bosses teleport with zero FX today (script-only by design):
[_acc_boss_glitch.gsc](../scripts/zm/zm_abandoned_cyber_city/_acc_boss_glitch.gsc)
`glitch_blink_loop` (blink + 1.2s recovery window) and
[_acc_boss_phantom.gsc](../scripts/zm/zm_abandoned_cyber_city/_acc_boss_phantom.gsc)
`phantom_teleport_loop` + the 25% player→player chain special.

1. Author `share/raw/fx/_custom/acc/fx_acc_derez_blink.efx` — clone of
   `fx_misc_nix_numbers_random_directions.efx` cut down to a ~0.6s one-shot burst,
   colorGraph tinted cyan (match the bosses' cyan eye tint); optionally layer a
   `fx_de_rez_ambient` sample. Same .efx text-editing recipe as the Triple Take
   geotrail work (memory `tripletake-projectile-volley-rework`).
2. `.zone`: `fx,_custom/acc/fx_acc_derez_blink` (+ any HB21 fx we layer, e.g.
   `fx,dlc0/factory/fx_teleporter_elec_strike_os`).
3. GSC: `loadfx` in each module init; `PlayFX` at **departure origin + arrival origin**
   in `glitch_blink_loop`, `phantom_teleport_loop`, and the chain special. Phantom
   materialize/cloak flicker can reuse the same burst at low density.
4. Build: `-GscOnly` (fx + script only, no geometry → no LED gate needed).

## Workstream B — The Scientist (new roster boss)

Behavior blueprint = the real BO1 thief AI (local clone `tmp/bo1_reimagined_ref/maps/_zombiemode_ai_thief.gsc`).
BO1 reference names (for authenticity + any future audio pass):

- Anims (all reused stock BO1): run `ai_zombie_simianaut_run_man` (the hunched
  crouch-sprint), sprint `ai_zombie_electrician_run(_v2)`, walk
  `ai_zombie_electrician_walk`, idle `ai_zombie_tech_idle_base`, melee/steal
  `ai_zombie_tech_grab`, deaths `ai_zombie_tech_death_fall{backward,forward}`.
- FX: trail `maps/zombie/fx_zombie_tech_trail` (played on a linked `tag_origin`
  script_model — our numbers clone uses the SAME pattern), spawn
  `fx_zombie_ape_spawn_dust`, teleport `transporter_start`/`transporter_beam`.
- Sounds (BO1 aliases; NOT installed — rippable later with tom_bmx's Black Ops Sound
  Converter, tom-crowley.co.uk/downloads): `zmb_vocals_thief_{ambience,sprint,steal,death,anger}`,
  PA announcer `zmb_vox_pentann_thiefstart` / `_thiefend_good` / `_thiefend_bad`,
  alarm `evt_thief_alarm_looper/_single`, weapon-return `zmb_bolt`, thief-round music
  rides the dog-round aliases `mus_zombie_dog_{start,end}`.

### Build status: RELEASED 2026-07-18 (user: "he is ready for release")

**SHIP CADENCE:** debut ROUND 15 (lab must be open - zone_is_enabled gate); after each death
OR escape the next Scientist is owed +4 rounds (die r16 -> next r20;
acc_scientist_first_round / acc_scientist_respawn_rounds dvars). An unkilled lurker persists
(single-lurker gate). Dev keeps the every-round-from-3 accelerator. Ship HP = the SHARED boss curve (65k base @ r5 anchor) at exponent 1.05 (2026-07-25 retune, was 1.04) - still the softest
tier (Brutus 1.12 > Panzer 1.1 > Rogue 1.09 > Phantom/Avo 1.07 > Scientist 1.05; r15 solo ~106k,
r20 ~135k) x the coop boss-HP table; live dvar acc_scientist_hp_exp. Dev = flat 1000.
Final architecture: NATIVE lab-riser spawn (stock spawn_zombie spawn_point param - zero
teleports, engine-run emerge, healthy BT by construction), roam driver on the stock BT
custom-goal hook, whole-lab chase, lab-plaza shuttle flee with player avoidance + corner-
freeze proofing (full-circle escape fan + stuck-detector breakout), gun carried on the
ANIMATED j_wrist_ri bone (tag_weapon_right sits at bind pose on zombie rigs - floats),
audio = the authentic BO1 numbers-broadcast hum ONLY (all warp-family sounds + the zap layer
with its embedded teleporter audio removed). 35+ dev-gated [SCI] trace points remain.

**Announce dedupe (2026-08-01):** the arrival line (*"he wants your weapon. Don't let him touch
you."*) and the *"is down."* line (both kill paths — normal death and the reap race — share one
`sci_down` key) now print only the FIRST time per match via `acc_utility::announce_once` — he
respawns every ~4 rounds and the repeated copy got annoying. The nameplate/hum/de-rez bursts stay
the per-spawn tell, and the actionable steal warning / escaped / weapon-back lines stay always-on.

### INCIDENT 2026-07-19: hard CTD on every spawn — root cause = the 1.3x SetScale experiment (removed; fix authored, module disabled pending verification build)

**Symptom:** repeated hard CTDs seconds after the Scientist rose, live (dev r3 sessions) AND on
subscriber machines (Workshop comment "the Scientist breaks the map" on the 2026-07-18 published
build, r15 ship cadence) — cross-machine repro, so no local-env cause. The user hardcode-disabled
his `init()` in `_acc_main.gsc` for the 2026-07-19 ASAP push.

**Evidence chain:** (1) minidump `...1784477684.dmp` (2026-07-19 12:14) = `0xC0000005` READ AV at
`exe+0x15bf48f` — a NEW offset (7/16 dump = `0x13efab0`, fxanim class = `0x2bc4ee9`; 7/17 = the
solved CF-overflow, not an AV). (2) console_mp.log: spawn 325.0s → T+3s heartbeat
`moved=0u goal=none emerg=N! grnd=Y!` (still rising, roam never drove a goal) → total server-script
silence from 328.8s → client `PLATFORM_DISCONNECTED_FROM_SERVER` at 334.7s ⇒ server thread died in
the emerge-completion window (~T+4–6s). An earlier session crashed in the SAME window right after
`roam: emerge complete after 4s` / `patrol: new point 268u away`. (3) That window is exactly where
the deleted `scale_pin()` fired its one deferred `SetScale(1.3)` (emerge + 0.5s poll + 1.0s settle).
(4) Every OTHER write in the window is field-proven elsewhere and ran clean in the pre-scale
2026-07-17/18 live sessions (sprint gait + `ASMSetAnimationRate` = the Panzer/Warden sanctioned
lever; `v_zombie_custom_goal_pos`/`SetGoal` = the NSZ/Warden hook; the SetModel reskin = trench-skins
idiom). (5) `SetScale` on a live AI is THE project-banned `0xC0000005` crasher (Brutus,
minidump-verified 2026-06-15); the experiment was a deliberate retest on a stock skeleton —
**empirically refuted. The ban is UNCONDITIONAL: skeleton, deferral, write-count don't matter.**
Anchors/patrol acquitted for this crash: the latest session died with `goal=none` (no goal ever
written), and the 2026-07-19 boss-spawn audit found the lab risers/anchors clear of the sweep
clips/statics (only bus-station conflicts existed, already fixed).

**Fix (authored 2026-07-19, in `_acc_boss_scientist.gsc`; module stays disabled until the
verification build):** ACC_SCI_SCALE define + `scale_pin()` + its thread REMOVED (post-mortem
comment at the top of the module); hardening: sprint_pin waits 0.5s past emerge completion before
its first gait/rate write + `isalive` guard, roam chase goals navmesh-projected via
`GetClosestPointOnNavMesh` before `SetGoal` (raw-origin fallback). **Re-enable =** uncomment
`acc_boss_scientist::init()` in `_acc_main.gsc`, `-GscOnly` build, dev session past a r3 spawn
(watch the [SCI] heartbeat through emerge→patrol→chase→steal→flee); if a CTD recurs at
`exe+0x15bf48f`, the next suspect is the emerge-window first-write timing — parse the new dump
first. If ever re-asked for a bigger Scientist: pre-scaled model or nothing — never SetScale.

### v2 iteration notes (2026-07-18, superseded)

**2026-07-18 rework after in-game tests:** (1) **DEV-ONLY** (user): never schedules in ship
builds — ship cadence preserved in a comment in due_this_round for the production flip.
(2) **NO TELEPORTS EVER** (user hard rule: teleporting = Glitch/Phantom identity): the v1
phantom-style flee blinks AND the leash snap-teleport are gone — flee = goal-driven RUNNING
away (0.5s re-aim, +/-75deg corner escape), containment = walk-home branch in roam_loop.
Post-mortem: the blinks were a v1 design from before the roam driver proved stock zombies
can be goal-driven on foot; never re-derived from the spec ("he runs away") until the user
caught it. (3) **Whole-lab chase**: any player IsTouching lab_zone is a target regardless
of distance (range check only covers just-outside-the-door). (4) **Sprint floor**: tier
always sprint, rate = +5 curve clamped to >= sprint_start_round (he must never be outpaced
by his own horde). (5) STATUE ROOT CAUSE found by reading stock (memory
promoted-zombie-teleport-statue-ignoreall): BT goal service first-checks self.ignoreall
(zombie.gsc:443) — stock only clears it in the rise flow our spawn teleport bypasses; fix =
clear it + n_zombie_custom_goal_radius + PathMode/SetGoal. (6) Full [SCI] forensics
heartbeat (moved/goal/rate-vs-horde/chase/ignoreall/emerge flags).

### v1 notes (2026-07-17, superseded where marked)

`_acc_boss_scientist.gsc` shipped with these v1 decisions (deltas from the plan below,
each forced by verified constraints):
- **Own thief-round cadence** (ship r7 then every 6; dev r3 then every 3), NOT a 5th
  roster-deck slot — supersedes the "join the every-9 deck" line below; the shared
  deck/debt/re-home machinery in `_acc_civil_protector` stays untouched, and BO1's
  thief was a special-round enemy anyway. Debt-director spawn (Phantom pattern,
  `acc_boss_phantom::spawn_promoted_zombie` called cross-module).
- **Steal = BOSS-SIDE PROXIMITY** (0.2s ring, `acc_scientist_steal_range` 56u), NOT a
  damage-callback hook — god mode suppresses the whole player-damage callback chain
  (the Phantom chain-slow hit this wall), so a MOD_MELEE hook would be untestable in
  the dev/god sandbox. Touch-steal is also the BO1 mechanic.
- Steals the held gun only if it's a PRIMARY (BO1 priority); snapshots clip+stock;
  wears the gun's worldModel on `j_spine4`; skips players mid box-grab
  (`acc_box_grabbing`); victim is switched to a surviving primary.
- **HOME TURF = THE LAB** (user 2026-07-17): spawns at a `lab_zone_spawners` struct;
  a 0.5s `IsTouching(lab_zone)` leash teleports him back (red bursts) until he steals.
- Flee = phantom-style away-blinks (nav-clamped, red bursts both ends + the crazed
  `acc_scientist_warp` voice = warp.wav pitched UP +250/+400 — third voice in the
  sound language: high=Glitch, deep=Phantom, manic=Scientist). Escape after **60s** (user: 1 minute) →
  **the gun is GONE FOREVER** (user design 2026-07-17, replaced the hostage-pool draft);
  no death notify on escape = no rewards.
- Kill = carried loot returned (exact ammo, `HasWeapon` dupe-guard, NO forced
  weapon switch), Max Ammo drop, + Fire Sale when killed pre-steal (the Bonfire nod),
  + the shared `grant_unified_boss_reward` payout, nameplate, corpse cleanup.
- Look: `p7_zm_dlchd_cosmo_labcoat_body` + random `cosmo_head1-5` (trench-skins
  SetModel+Detach+Attach idiom), `no_gib` (gib set deliberately un-zoned), sprint
  gait pinned via `acc_boss_custom_speed` + a 2s re-assert loop (no ASM writer),
  RED numbers trail on a linked tag_origin (`fx_acc_scientist_trail`, the exact BO1
  `tech_trail` recipe) + red bursts via `derez_burst( ..., "scientist" )`.

### Original build plan (kept for reference; superseded items noted above)

1. **Body**: promoted stock zombie (the proven Phantom/BOTD SetModel machinery) wearing
   `c_t7_zm_dlchd_cosmo_labcoat_body` (+ matching head from the ninja GDT — pick at
   build time; body+head combos per memory `underground-54i-skins`).
2. **Movement**: sprint-tier zombie (`zombie_move_speed` sprint = the closest stock
   approximation of the hunched run; anims ride the stock rig for free).
3. **Aura**: `fx_acc_scientist_trail.efx` = numbers clone, colorGraph RED, PlayFxOnTag
   on a `tag_origin` script_model linked to the boss (exact BO1 `tech_trail` recipe;
   drop on death like BO1's `fx_org delete()`).
4. **The STEAL** (the signature): on melee touch → `takeweapon` the victim's HELD gun,
   store on level; **attach the stolen gun's worldmodel to the boss** (BO1 did);
   boss turns evasive (flee target selection + phantom-style blink escapes with red
   de-rez FX). MUST respect the weapon-reconcile machinery: box-grab defer
   (`acc_box_grabbing`), Mule Kick sticky slot, HasWeapon stale-guards (memories
   `box-grab-defer-weapon-reconcile`, `mulekick-stable-order`, `leviathan-melee-slot-twin-desync`).
5. **Resolution**: killed before escape → weapon returned (`giveweapon` + deferred
   switchback) + Max Ammo + a fire-sale-style box discount window (box price hook is
   owned by `acc_box_prompt` — memory `firesale-box-price-owned-by-prompt-hook`).
   Escapes → weapon held hostage; returned when he's next killed (BO1-faithful).
6. **Roster wiring**: join the every-9 no-dup boss deck (`_acc_boss.gsc`), mini-HP tier
   (65k base, exponent ~1.06-1.09 per the Phantom/Rogue band), boss-item grant set on
   death (same set as every boss — `_acc_boss.gsc` ~line 340), nameplate, splash,
   boss-filter exclusions (octobomb/splash — memory `octobomb-brutus-crash-and-boss-filter`),
   frame-0 spawn refusal guard (wait-then-spawn + retry), debt-director integration.
7. Follow the full add-a-boss checklist: memory `high-caliber-and-add-boss-item-checklist`.

### Fidelity tiers (how close we get)

| Dimension | This build | Authentic % |
|---|---|---|
| Behavior (steal/flee/rewards/cadence) | full GSC port of the BO1 loop | ~95% |
| Aura/FX (red numbers trail) | the REAL numbers FX, retinted | ~90% |
| Model | ZC Ascension labcoat scientist (vs BO1 suited thief) | ~70% — reads "mad scientist" instantly |
| Run anim | stock sprint (vs simianaut crouch-run) | ~60% |
| Audio | none at launch; BO1 rip path documented above | 0% now, ~90% later |

Upgrade path back to 100%: BO1 install + Greyhound rip + Maya re-rig (docs in memory
`pentagon-thief-boss-sourcing`) — nothing in this build blocks swapping the body/anims
later; the module only touches `SetModel` + animset surface.

## Workstream C — Lab ↔ Exchange player teleporter (reuses the FX kit)

**STATUS: BUILT 2026-07-17 (awaiting first in-game test).** A traversal device that reuses
the teleport-FX kit above for a *player* warp (not a boss blink). Module
`_acc_teleporter.gsc`; design decisions locked by the user 2026-07-17.

- **Endpoints**: a pad in **the Lab** (Pack-a-Punch room, far north, floor z=0) and one in
  **the Exchange vault** (under the Plaza, floor z=−240). Chosen because they're at opposite
  ends and the vault is gated behind two doors — the teleporter is the express lane.
- **Unlocked by beating Paradise — three-state UI** (user 2026-07-17, revised same day):
  **BROKEN** (pre-Paradise) = fast-blinking holo + `Dead teleporter` hint (user copy); pressing
  it toasts *"maybe going deep into the trench will fix it"*. **READY** (won + off cooldown) =
  **solid/permanent** glow + Teleport prompt (`acc_interact_glow::glow_solid`, new; pads
  override the blink cadence to 0.5/0.6 via `acc_glow_on_time`/`_off_time` ent fields).
  **RECHARGING** = blinking + recharging hint. Glow flips on state **edges** only (hint_ticker
  piggyback), never per-tick. Dev unlocks at spawn → dev never shows BROKEN (flip the branch
  in `unlock_watcher` to preview it).
- **Raised pads** (user): 11-tall full-footprint step-up clips (`add_prop_clips`
  `teleporter_lab`/`teleporter_exch`, brushmodel/LED-exempt — the `l2_pad_*` recipe): players
  physically **elevate onto the disc**; arrivals land on the clip top (+11). Full build + bake.
- **Third pad — trench, UNLINKED** (user): the abyss-L2 green fault-pad `(-250,1850,-480)`
  is now spawned by `_acc_teleporter` (removed from `_acc_abyss_deco`; same origin/model,
  `l2_pad_green` clip already present). Same state machine; destination = a not-yet-built map
  area → activating gives de-rez FX + `No destination signal`, no warp, **no cooldown arm**.
  Go-live = fill real coords/yaw (+ dst_zone if gated) in the `init()` spawn_pad call.
- **Pad model → assembled Der Eisendrache teleporter** (user 2026-07-18 "add the program 115
  teleporter"): the full iconic pad, built in GSC (`spawn_der_teleporter`) from the stock
  `p7_zm_der_teleporter*` fragments — 4 body wedges tiled radially (0/90/180/270) + blue/red wire
  pieces (glow targets) + glass dome, all `SetScale 2.5` (~167×63u, clears the vault's 144u
  headroom). Arrangement/scale from **Program115's Teleporter v1** prefab (CREDITS); models are
  STOCK (gdtDB) so **no pack asset ships** — Program115's GSC/sounds unused. The earlier
  "half-baked fragment" complaint was a usage bug: these are quarter-wedges pivoted at the min
  corner, MEANT to be placed 4× rotated to tile the ring. Idle beam `fx_teleporter_beam_factory`
  through the dome. Players stand on the central step-up clip inside the ring → still `-GscOnly`,
  no bake. Sit-height tune: dvar `acc_teleporter_pad_z`.
- **Coordinates — the vault floor is z=−160, NOT −240**: v1 trusted `_acc_transfer.gsc`'s
  stale "−240 floor" header and put the vault pad 80u under the floor → invisible pad + riders
  dropped into the void. Ground truth = the generator-tagged `vault floor slab` brush
  (`.map` ~L2603): room **x[−720,300] y[−448,360], floor top −160, ceiling −16**. Vault pad
  now `(−640,40,−160)` (west end, clear of the ATM column x~80 and the stair landing
  x[−620,−380] y[−440,−312]), arrival faces east; Lab pad `(150,3450,0)` (v1-confirmed live).
- **Door-independent + doors open from inside**: the pad triggers read **no** door flag, so
  you can warp into a still-sealed vault and open `enter_exchange` / `enter_implant` from the
  inside — the buyable-door system already spawns a radius-96 buy trigger on **both** faces of
  every slab (`zm_abandoned_cyber_city.gsc::zone_door_buy_loop`), so no door change was needed.
  (Note: the Exchange interior door trigger sits at the top of the stairs, z=50, not on the
  vault floor — a vault-pad rider climbs partway before the prompt reaches; add a pad-side
  trigger if that ever feels off.)
- **Landing safety** (adversarial review caught this): the Lab is zonemgr-gated, and
  `SetOrigin`-ing a player into a *disabled* zone trips the stock out-of-playable-area monitor
  → full reset. The lab-bound warp calls `zm_zonemgr::enable_zone("lab_zone")` **on arrival** —
  a no-op if already open (the usual post-Paradise case), and what makes the **dev** warp land
  safely before the lab doors are bought. The vault end needs none (it's inside the
  `player_in_vault` OOB-safe band, `_acc_bus_trench.gsc`).
- **90s SHARED cooldown**: either pad recharges both (one device). Static hint + `hud_msg`
  toast for live seconds (250-triggerstring cache + full CF pools rule out a hint-baked/CF
  countdown). Cooldown machinery copied from `_acc_jukebox.gsc`.
- **Rides (revised 2026-07-18 — NO pause/lock, user)**: the ~2.2s charge runs with **full player
  control** (the 2026-07-17 `FreezeControls` wind-up lock is gone); at discharge, whoever is
  within 96u of the pad **at that moment** rides (gather at fire time — step off mid-charge =
  you stay), fanned onto a 48u ring at the far pad (the `_acc_paradise` coop-safe fan-out).
- **Kino FX + SFX** (user 2026-07-17; FIXED 2026-07-18): we already OWN the visuals — HB21's
  library *is* the stock teleporter FX incl. the literal Kino family. Sequence: charge
  `fx_sophia_elec_charge_teleporter` + hum (~2.2s, `ACC_TP_CHARGE_SEC`) → bright
  `fx_elec_teleport_flash_lg` + sparks + `derez_burst` + loud boom → warp →
  `fx_teleport_flashback_kino` arrival beam + boom. **v3 was invisible**: it used bare
  `PlayFX(fx, origin)`, which does NOT render in this build (`_acc_perk_lights.gsc:6-15` rule;
  memory `server-playfx-does-not-render`) — every sequence FX now rides
  `acc_utility::play_fx_burst()` (PlayFxOnTag on a throwaway `tag_origin` host; same fix
  applied to `derez_burst`'s own zap/sparks layers, invisible on every boss blink till now).
  SFX = two new **CC0** wavs (`acc_teleport_warp`/`acc_teleport_charge`, OpenGameArt rubberduck
  "50 CC0 Sci-Fi SFX", 48k/16-bit mono via ffmpeg; CREDITS row added). Stock DLC teleporter
  sound aliases are NOT referenceable from a usermap (confirmed) — hence the custom wavs.
- **Pad sink**: `ACC_TP_PAD_ZOFF −52`, eyeball-tuned across three user passes (floor-z spawn =
  floats "in the sky"; the prefab's own −59 = "too far in the ground"; −45 = "too high").
  Tune: `acc_teleporter_pad_z` (spawn-time read — map restart to apply). **Pads are FLAT — clips REMOVED**
  (final; 11u and 8u both snagged zombies — entity clips are navmesh-invisible, an unseen wall
  at any height = safe-spot exploit): players stand at floor level inside the walk-through ring
  (`ACC_TP_CLIP_TOP` 0; the deco `l2_pad_red` keeps its 11u plate). **Charge tell** = the teleporter's own
  charge FX at host **+40** (was +6 = hidden at floor level inside the sunken assembly). The
  briefly-added solid-holo charge tell was removed (user: teleporter FX only, no station glow). **Glow = the STATION
  convention** (flipped 2026-07-18, supersedes blink-when-broken): the standard usable blink
  only while READY; BROKEN/RECHARGING = dark (hints/toasts + beam carry them). All 9 pieces
  pulse in lockstep (`acc_glow_sync` flag skips the per-ent random phase in `_acc_interact_glow`).
- **Build**: `-GscOnly` (fx + models + script only, no geometry). Pad origins are `#define`s —
  retune in-game. Dvars: `acc_teleporter_on` / `_cooldown` / `_beam`.

### Pending user asset: the constant numbers hum

User is sourcing a looping "numbers" wav (2026-07-17). Wiring is FLIP-READY in
`_acc_boss_scientist.gsc` (`spawn_scientist`, commented `PlayLoopSound` + full 3-step
recipe in the comment: wav placement → alias row template → zone-bump rebuild). Trail
FX note: `fx_acc_scientist_trail` is tinted red, ×3 size, AND **world-space** (the tool's
`world` arg strips `spawnRelative`/`runRelToEffect`) so the numbers linger in his wake —
regen: `node tools/tint_numbers_efx.js <src normal.efx> <dst> 1 0.12 0.08 3 world`.

## Order of work

1. ~~Install packs~~ ✅ 2026-07-17 (incl. HB21 gdtdb dedupe — see manifest).
2. Workstream A (small, validates the FX pipeline in game end-to-end).
3. Workstream B module + roster wiring.
4. ~~Workstream C — Lab↔Exchange teleporter~~ ✅ BUILT 2026-07-17 (awaiting in-game test).
5. Optional audio pass (tom_bmx rip) + optional authentic-model pass.
