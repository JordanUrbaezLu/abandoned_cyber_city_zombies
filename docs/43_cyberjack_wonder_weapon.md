# 43 — THE CYBERJACK (signature wonder weapon)

> **Status: DESIGN LOCKED (user, 2026-07-16) — M0 + M1 core IMPLEMENTED 2026-07-17.**
> **CHASSIS CHANGED (user 2026-07-17: "the part I don't really like is that it's a bow"):
> the weapon now lives on `apex_lstar` — the Apex L-STAR plasma LMG (unused pack gun, full
> 1P assets verified; displayName = "THE CYBERJACK") — NOT the storm bow.** Everything in
> this doc that assumes the bow chassis reads with these corrections: charge defs are
> script-owned only (no engine charge levels), **the MagicBullet ban is LIFTED** (hitscan
> chassis — the chain hops ARE MagicBullets now), and the chassis' pre-registered FX CFs
> are replaced by reuse of the Triple Take's `acc_ttk_bolt_fx` CF/csc for the chain bolts.
> M1 shipped: jack-in chain + corruption slow/DoT + decompile harvest (`_acc_cyberjack.gsc`).
> Still open: M2 (breach rift, ROOT ACCESS, RAM), M3 (Avogadro rivalry, Jailbreak),
> M4 (ICEBREAKER COMPILE quest, records), presentation (terminal HUD, dial-up audio,
> codename ladder swaps on the legendary skins).
> This is the map's **big bet**: a map-exclusive signature wonder weapon that cannot be
> lifted into another map, because its identity is OUR GSC behavior + integration with
> THIS map's systems (Data Shards, Abyss, Avogadro, terminals, leaderboard) — not the model.
> Every feature below was **adversarially verified against the engine's real limits**
> (2026-07-16 design workflow: 29 features proposed across 4 design axes, 26 verified
> BUILDABLE with code-level receipts, 3 downgraded to EXPERIMENT with buildable fallbacks,
> 0 refuted). Verdict receipts are inlined per feature.

---

## 1. Identity

| | |
|---|---|
| **Name** | **THE CYBERJACK** (user-approved 2026-07-16) |
| **Chassis** | **`apex_lstar`** — the Apex L-STAR plasma LMG (unused zeroy-pack gun; full 1P viewmodel/anims/sounds installed; displayName renamed "THE CYBERJACK"; `legendary_01` skin). CHASSIS-SWAPPED from the storm bow 2026-07-17 (user: "the part I don't really like is that it's a bow"). Hitscan → the MagicBullet chain hops are legal; charge is fully script-owned (no engine charge defs). |
| **Fantasy** | A street-tech **plasma icebreaker**. The city is dead but its network isn't — and every zombie is full of badly-secured cyberware. An automatic plasma shooter that **charges (ADS-hold) into a tornado**. Corrupt the horde, harvest their data as Shards, tear open breach rifts, and out-hack the map's own hacker boss. |
| **Theme fix** | The whole weapon speaks ONE FX language — **white/violet lightning**: the shots are violet-white electric bolts, the chain hops are DE zap-bolts, the charge is the DE whirlwind funnel. FX + the energy chassis carry the cyberpunk read. |
| **The moat** | The model is a rip anyone can install. The weapon — corruption chains that pay the trench currency, an ultimate the city visibly reacts to, a boss that hacks the gun back, a compile-quest across the Abyss — exists ONLY here. |

**Codename ladder** (the in-place PaP tiers are named, not numbered — each is "the icebreaker
waking up"): **CYBERJACK** (v1.0) → **ZERO-DAY** (v2.0) → **BLACK ICE** (v3.0) → **DAEMONROOT** (v4.0).

---

## 2. Player experience (the 30-second pitch)

Tap-fire jacks a neon filament through a train — each zombie seizes as the arc stitches
zombie-to-zombie, and corrupted kills **decompile** into fountains of Data Shards.
Full-charge tears a **Breach Rift** into a wall: the horde abandons you mid-swing and dives
into a screaming neon whirlpool that slams shut in a physics ring. Sustained use builds
**SYNC%** on a hacker-terminal HUD; at 100% the release fires **ROOT ACCESS** — the whole
city's lights dim and strobe, the announcer growls, and everything standing gets chained,
slowed, and blown outward. On Avogadro rounds, the enemy hacker **counter-hacks your gun**
— SYNC drains, the weapon bricks to 0/0 — until you purge at a terminal or land his melee
weakness. And the weapon itself talks back through glitched terminal text that decodes as
it tiers up... eventually addressing you by your actual gamertag.

---

## 3. Feature spec

Features are grouped by build milestone (§6). Each carries its verdict + the tech recipe
(numbered techniques = the proven-recipe inventory in §7).

### M0 — Chassis online (dev-grant only; decision 2: NO public box entry, ever)

**F0. CYBERJACK exists (dev-acquirable, quest-reserved)** — `BUILDABLE (the Fire Bow template, traced end-to-end)`
CSV row, WONDER PaP, in-place tiers, claim cap, damage rows all land — but the gun is
**NOT added to the `box_weapons` pool array** (absence = never rolled; the array is the
sole authority). Acquisition until M4 = a `level.acc_dev`-gated grant **through the box's
own weapon_give path** or **charge levels break** (`_acc_dev.gsc:101` — hard-won). Public
players first meet the weapon via the ICEBREAKER COMPILE (F15). The vendored
`_zm_weap_elemental_bow_storm.gsc` behavior (chain lightning storms) stays as the M0
placeholder firing identity; our module progressively replaces its impact routing.

### M1 — The identity (corruption + harvest + presentation core)

**F1. DAISY-CHAIN CORRUPTION ARC (tap fire)** — `BUILDABLE`
Every uncharged hit chain-hops: radius gather picks nearest-uninfected, a visible neon arc
(scriptmover geotrail, ≥0.25s/hop, ~200u hop range) leaps chest-to-chest, each hop lands
scripted damage. Corrupted zombies flicker-slow (anim-rate 0.8, per-zombie
`acc_cj_corrupted` flag) so the chain reads as a paralysis wave. Hops scale with tier
(2/3/4/5). One-shots the Glitch Stalker; the chain **restarts from its corpse**.
*Recipe:* 8 (the chassis' own `bow_storm_storm_get_targets`, storm.gsc:156, refiltered) +
6/7 (geotrail + `.efx` clone) + 5/23 (slow flag honored by `_acc_zombie_speed` + watchdog) +
11 + 12. *Verifier correction (CRITICAL):* **never MagicBullet a projectile bow** — a
script-fired arrow re-enters the bow's own impact machinery (recursion/double-proc;
`bow_storm_fake_fire_impact:543` exists for exactly this). Hop damage = `DoDamage` **with
the player as attacker** (keeps kill credit/points/powerups; the MOD whitelist only zeroes
player-on-PLAYER damage). Re-validate the Stalker ent before the restart (it teleports).

**F2. DECOMPILE HARVEST (corrupted kills pay Data Shards)** — `BUILDABLE (strongest verdict: the drop spawner is OUR shipped code)`
Any zombie dying while corruption-flagged — killed by ANY teammate — decompiles: a burst of
rising neon glyphs + shard payout. `_acc_data_shards.gsc:222` already spawns pickups;
`grant_player(:136)` is the public API (`source_tag "cyberjack_harvest"`). Physical motes
for the slot-machine feel, auto-grant fallback if pickup spam bites.
**⚠ DESIGN DECISION REQUIRED (user):** the economy rule is **trench-only shards** — this
makes the CYBERJACK the map's ONLY surface-world shard printer. That is the *point* (the
hacking gun harvests the currency), but it amends a stated design rule. Options: bless the
exception (recommended — it's the weapon's identity), or z-gate drops to trench depth.
Anti-inflation regardless: per-round cap table shared across ALL cyberjack source tags.
*Traps:* death hook = `zm_spawner::register_zombie_death_event_callback` (never
`callback::on_ai_killed` — register-only, NEVER fires); corpse origin through
`acc_utility::drop_floor_origin` (airborne deaths); cap concurrent pickups; boss-jackpot
filter uses the complete boss-marker list, never mutated mid-foreach.

**F3. FIRMWARE VERSIONS (in-place PaP + codename ladder)** — `BUILDABLE`
The exact `acc_firebow_tier` template (bows are the one class where in-place tiers are
ALREADY shipped): `player.acc_cyberjack_tier` 0..3, WONDER pricing (10k/15k/20k) **plus a
Data Shard surcharge per tier** — the map's deepest dual-currency sink. Each version is a
patch note: v2.0 ZERO-DAY (+2 hops, fatter arc), v3.0 BLACK ICE (longer slow, 2× harvest
proc, unlocks F7 Lance), v4.0 DAEMONROOT (chain-kill clusters tear mini-rifts).
*Verifier corrections:* damage growth = script-side bolt-damage scaling + tier-keyed
`_acc_damage` multiplier (NOT MagicBullet volleys — F1 trap); beam fattening = **additive
server-side FX layers** per tier (storm bolt FX are client-side; no csc fx swap). Purchase
must be atomic: `try_spend` shards BEFORE points deduction (`zm_score` API, never
`player.score`), clean refund on partial failure.
*AS-BUILT PaP VISUAL (v5.12, 2026-07-17):* the user asked for "a different model for pap two" — but
**BO3 ZM has no runtime weapon skin/model/camo API** (verified: no `SetWeaponSkin`/`SetViewModel`/
`SetWorldModel`/`SetModelFromWeaponCamo` in the stock mirror or our tree; stock PaP looks ride the
`_up` weapon-def swap we deliberately don't use). A literal model change = a weapon swap that would
break the in-place tier counter + the twin matrix + the OC family map (the pack ships `legendary_02/03`
skins but there's no safe runtime path to them). So the PaP signature is a **trail recolor**: the shot
bolt goes from base violet (`acc_cj_bolt_violet`, RGB 0.85/0.62/1.0, CF value 3) to a **richer violet**
(`_custom/acc/acc_cj_bolt_violet_pap`, RGB 0.75/0.42/1.0, CF value 4) once packed (tier ≥ 1). This
AMENDS the "no csc fx swap" note above — the shared TT `acc_ttk_bolt_fx` scriptmover CF was widened
2→3 bits for value 4, and `shot_orb()` reads the shooter's tier so it applies on the base gun and every
perk-Mega twin. Pure FX layer — no weapon-def contact, so twins/OC cannot regress.

**F4. BLACK ICE Terminal HUD** — `BUILDABLE`
Held-weapon docked panel: SYNC% bar, HARVEST counter, codename plate, 3-line scrolling
glitched "intrusion log". GSC packs state into ONE dvar string (`sync:harvest:tier:eventId`),
LUI polls — **zero new clientfields** (both CF pools are FULL; the dvar-read channel is the
proven transport). *Traps:* co-op peers don't see host dvars — ship dvar-poll for
solo/host in M1, add the `SetControllerUIModelValue` relay (the accLbR* recipe) in M4;
throttle ~10Hz, quantize SYNC to 5% steps; UITimers closed-before-create.

**F5. DIAL-UP SOUL (audio identity)** — `BUILDABLE`
Recognizable eyes-closed: charge = 56k-modem handshake rising into a weapon whine; full
charge = carrier-lock tone; each hop = packet-chatter burst; harvest = download blip;
tier-up = "ACCESS GRANTED" chord. Script-owned charge timing gives every alias an exact GSC
hook. *Traps:* **no runtime pitch lever** — bake one asset per charge stage and tune GSC
hold constants to the wav; every charge alias needs a stop/abort path (early release);
48k/16-bit PCM (`tools/resample48k.js`); `.sabs` locked while BO3 runs.

**F6. SEGFAULT kill-feed + JACK-IN boot** — `BUILDABLE (lowest-risk on the sheet)`
Kill-feed: `[SEGFAULT] <zombie> :: connection terminated` via our own `send_kill_feed`
(`_acc_points.gsc:534`) + the `.str` filename-prefix recipe — **gated to chain-finisher
kills only** (8 rows in 2s = spam). First-acquisition boot: 3s "jacking in" — per-player
ice-blue flicker, handshake screech, HUD boots line-by-line, rumble pulse, Kortifex line.
*Verifier correction (CRITICAL):* the flicker uses `visionset_mgr::activate` with the
**stock-registered `zm_trap_electric` overlay** — NOT `VisionSetNaked`/`SetVolFog` (both
GLOBAL, would tint the whole lobby) and NOT a new visionset registration (visionset_mgr
version bits are the exact CF space that overflowed once).

### M2 — The spectacle

**F7. BREACH RIFT (full charge)** — `BUILDABLE`
Max charge tears a vertical neon rift: for 8s it's a zombie POI lure (the horde physically
abandons players and dives in) + 65% slow field + 1s-tick decompile DoT; at timeout it
SNAPS shut — `PhysicsExplosionCylinder` ring + shard payout per rift kill. Whirlwind rumble
rides the chassis' **already-registered** `elem_storm_whirlwind_rumble` CF (free).
*Traps:* POI = stock `create_zombie_point_of_interest` (engine-proven, used by our own
`_zm_powerups.gsc:964` — but smoke-test a bare POI first); navmesh-project the landing;
deactivate+delete the POI ent on close; **bosses/pack AI ignore POI** — exclude them from
rift expectations AND the collapse fling; undefined-attacker DoT kills give NO credit →
track rift kills via the death-event callback for payouts; slow watchdog covers despawn AND
mid-slow death; physics ring pairs with the Thundergun-style knockdown path (cylinder alone
doesn't hurl live zombies); DoT radius = `Distance2D` + z-band.

**F8. SYNC% → ROOT ACCESS (usage-built ultimate)** — `BUILDABLE`
SYNC builds from cyberjack actions (kills, full chains, harvests, terminal use). At 100%,
holding past 2.5s arms the ult; **the release still fires the arrow** (verifier: no legal
fire-suppression exists — the ult *piggybacks* the max-charge release, framed as the
payload injection). Effect: **CITY BROWN-OUT** — the whole map's fog dims and strobes
(override state INSIDE `_acc_atmosphere::apply_fog` — it is the single fog authority with a
0.1s re-assert gate; never a second `SetVolFog` caller), a beat of near-black, then a huge
radius chain + 35% slow + physics ring + lingering DoT field, staggered kill ripple
outward (the KERNEL PANIC visual, merged here). SYNC resets to 0.
*Traps:* fog/vision are level-wide — that IS the feature (your teammate's ult dims YOUR
street; players learn to read an overcharge from across the map), but mutex two
simultaneous ults, yield entirely during Paradise (haze owns fog) and pre-power (ramp owns
vision); fail-safe restore watchdogs (a revive force-restores the map vision per-client);
fire-input latches ~1.25s after release — debounce re-arm; exclude bosses/friendlies from
the freeze+kill wave; snapshot the target array (no mutate-mid-foreach).

**F9. HARDLINE RAM (shard-fed ammo)** — `BUILDABLE (80% a reskin of _acc_ammo_crate pointed at shards)`
No wallbuy, no reliable Max Ammo for a wonder — instead jack into ANY hack terminal and
convert Shards→ammo; price scales with firmware tier, Exo tier discounts it. Every terminal
becomes CYBERJACK infrastructure. *Traps:* the terminal now serves hack/purge/compile/RAM —
build ONE prioritized state machine over `set_hint_for_state` (held-CYBERJACK + context
selects mode); hint text must dodge the `ZMCursorHintNew.lua` catch-all matcher (unique
word); clamp grants to `weapon.maxammo`.

**F10. TRACEROUTE (the engineered signature clip)** — `BUILDABLE`
The full-charge chain is choreographed for capture: fat neon beam leaves the muzzle, hops
target-to-target, final target detonates in a knockback ring that fountains shard pickups.
*Verifier math:* 0.25s/hop × 8 hops = 2.0s+ — **cap the choreographed chain at 5-6 hops**.
Rumble CF is 1-bit: hold it high for the whole chain (stock does set-1…set-0); per-hop
feedback is AUDIO (packet-chatter), or native `PlayRumbleOnEntity`.

### M3 — The rivalry (the map fights back)

**F11. BLACK ICE COUNTERHACK (Avogadro bricks your gun)** — `BUILDABLE`
During Avogadro rounds he periodically counter-hacks the wielder: SYNC drains live on the
HUD; a full counter-hack **BRICKS the weapon** — clip+reserve forced to 0/0 (the one legal
fire block) + glitch flicker. Purge by landing his existing MELEE weakness (a notify from
inside the already-melee-gated block 0c5 branch — verified 5-line hook,
`_acc_damage.gsc:860`) or at any hack terminal (restores exact saved clip+stock + partial
SYNC refund). **No other map's wonder weapon can be hacked back.**
*Traps:* brick must hold BOTH clip and reserve continuously (a reserve reload un-bricks);
save/restore exact ammo; guard Max Ammo drops, `_acc_ammo_crate`, and F9 against refilling
mid-brick (all check the bricked flag); brick the wielder only; verify the def has no ammo
regen (else re-zero watchdog).

**F12. ICE BREAKER (counter-hack his machines)** — `BUILDABLE (every ingredient verified in-tree)`
Avogadro's signature is hacking perk machines dark (`level.acc_avo_hacked`,
`_acc_boss_avogadro.gsc:110`). The CYBERJACK is the only weapon that can trace it back:
channel a hacked machine ~3s (zombies converging) → the machine snaps back via **his own
restore path** (`:1010-1022`), Avogadro seizes 8s (`ASMSetAnimationRate` — already used on
him at `:330`), and his weakness **flips from MELEE to the CYBERJACK for 20s** (+20%
window via the block 0c5 table). The enemy hacker gets out-hacked. Announcer:
"INTRUSION... REVERSED."
*Traps:* his anim-rate PERSISTS — restore to the dvar-resolved 1.15 chase rate (not 1.0)
via a watchdog that survives boss death mid-stun; NEVER kill `hack_director` (that exact
bug froze him once, `:988`) — suppress via a flag his loop checks; restore through the
existing undo path incl. `acc_avo_hacked_by`.

**F13. JAILBREAK (capture the Glitch Stalker)** — `BUILDABLE (deliberately avoids AI possession)`
The CYBERJACK one-shots the Stalker (per-weapon hits table precedent:
`acc_leviathan_hits_glitch=1`, `_acc_damage.gsc:476`). Kill it with a FULL charge and it's
**captured**: a hovering drive-fragment orbits you 45s, blink-striking the nearest zombie
every 4s with its own teleport sound + glitch burst. Implemented as a script_model homing
minion (wolf-bow pattern — the real stalker dies properly; its ghost serves you).
*Traps:* the capture kill MUST route through real death (`DoDamage`/`Kill`, never
`Delete()`) — `glitch_death_watch` waits on `"death"` and the corpse system + boss
scheduler bookkeeping depend on it; decide reward interplay (capture should replace, not
stack with, the kill payout).

**F14. KORTIFEX HATES THIS GUN** — `BUILDABLE (mechanism live at _acc_kortifex.gsc:104-146)`
Announcer beef: acquisition ("So. You found the city's skeleton key."), 5+ chain ("Stop...
rewriting... my horde."), and the crown jewel on an Avogadro kill with it: "The hacker...
hacked. Delicious irony." *Traps:* overlap = silent DROP — boss-death moments are
announcer-busy; retry-for-N-seconds and burn the once-per-run flag only AFTER it played;
stock registry plays only the `_0` alias suffix.

### M4 — The legend (acquisition quest + persistence)

**F15. THE ICEBREAKER COMPILE (quest acquisition)** — `BUILDABLE — this is the "buildable signature wonder" every marquee map ships`
End-state: the CYBERJACK is **never in the box**. Five code-fragment nodes, one per Abyss
floor L1–L5 (all five floors live, docs/30). Jacking a node starts a ~45s TRACE — the node
becomes a POI lure *pinging YOUR position to every implant in range* (horde converges) with
a dvar HUD progress bar; survive → the fragment ejects as a beacon-trailed pickup. Kortifex
counts down ("FRAGMENT DECRYPTED. FOUR REMAIN."). All five + a shard fee feed the COMPILER
terminal at the bottom of L5 — the weapon grants **through the box weapon_give path** so
charge defs arm. Deeper floor = harder trace: acquisition difficulty rides the map's own
spine. The defend-at-terminal state machine already exists (`_acc_events_hack.gsc`
`run_stage_survive` — copy it, don't reinvent).
*Traps:* new node/compiler triggers = `.map` edits → **FULL LED bake gate** (no `-SkipLED`)
+ the concurrent-session `.map` clobber check; trace reinforcements: frame-0 wait+retry,
z≤-240 forced `completed_emerging`, below-volume melee-lock handled (the penalty wave
already navigates some of this). **Decision 2: quest-only** — there is no box fallback and
no pre-quest public release mode; the dev-grant (F0) is the only other acquisition path and
it never ships enabled.

**F16. DAEMON ROLL (per-run compile variance)** — `BUILDABLE (config-flag branches over verified primitives)`
The compiler rolls ONE resident daemon per run — the CYBERJACK never compiles the same
twice: **LEECH.EXE** (2× harvest — economy build) / **SIREN.EXE** (chain-kills plant 4s
corpse lures — shepherding build) / **WYRM.EXE** (corruption death-bursts spread DoT —
plague build) / **FROST.EXE** (slow deepens to freezegun-grade 35% — control build).
HUD shows the daemon; Kortifex announces the roll; re-roll costs shards at the compiler.
Run identity for leaderboard bragging. *Traps:* SIREN cap 2-3 concurrent POIs + timed
delete + `drop_floor_origin` + navmesh-project; WYRM spread-depth cap (no chain-reaction
runaway); FROST rides the honored per-zombie flag.

**F17. THE GUN THAT TALKS BACK** — `BUILDABLE`
The intrusion log occasionally prints first-person lines FROM the weapon; legibility tied
to tier: v1.0 leetspeak garbage ("f33d m3 sh4rd5") → v3.0 cold clean sentences → once per
run it addresses the player **by gamertag** (GSC knows `player.name`; relay via the proven
LB name path — resolve via `Engine.Localize`, never `tostring`). GSC sends only a line
INDEX over the channel (dodges `string==undefined`); the string table + glitch-decode
typewriter live in Lua. *Trap:* sequence-number the index (seq*100+index) so repeats retype
and missed polls don't skip.

**F18. ICEBREAKER RECORDS (leaderboard)** — `BUILDABLE`
Two per-run stats ride the existing end_game dvar blob (`_acc_leaderboard.gsc:564` format,
omit-when-empty): **SHARDS HARVESTED** and **LONGEST TRACE (chain)**. Plaza board gains an
ICEBREAKER line with the record holder's gamertag — the wonder weapon becomes a competitive
category, feeding the record-chase creator hook. *Traps:* the per-lobby-size ladder is
LOCKED at `?v2=N` with the totals footer as the ONE sanctioned global exception — a global
LONGEST TRACE line is a SECOND exception: decide deliberately or scope per lobby size; bump
row version; dev/god runs never post (existing gate).

### M5 — Experiments (spike-gated; ship only what passes)

**F19. ICE DAEMON (rift-spawned ally construct)** — `EXPERIMENT`
Every third rift compiles a friendly construct that steps out and fights 25s. The CP-clone
friendly-AI spawn path is shipped but documented-flaky at its ONE curated location, never
run at arbitrary origins; the below-z=-1000 actor cull would silently delete it in the deep
Abyss (no friendly has ever been whitelisted). **v1 fallback (BUILDABLE): 2 homing "wisp"
script_movers** (wolf-bow pattern) that seek-and-pop — every piece proven, zero AI risk.
Spike gate for the real daemon: SpawnActor the clone at a navmesh-projected rift point in
Market AND deep-Abyss; verify pathing (`defaultGoalRadius` statue bug), blackboard init,
cull-whitelist, frame-0 retry, clean 25s Delete.

**F20. ZOMBIE.EXE (root a real zombie to fight for you)** — `EXPERIMENT (core claim refuted as specced)`
Verifier: the team-flip precedent flips a ROBOT archetype; the **zombie archetype does NOT
use engine team acquisition** (`get_favorite_enemy` iterates players), so a team-flipped
zombie stands idle. Buildable fallback shipped as the fantasy: beam-kill the target and
spawn a wolf-bow-pattern "ZOMBIE.EXE process" mover wearing PWNED FX that blink-melees
zombies (= F13's proven recipe). The real turned-zombie needs a `favoriteenemy`-forcing
spike — do not build the feature on it unspiked. *Hard trap:* a `.map` actor_spawner for a
nonstandard-team aitype HARD-CRASHED at load (`_acc_civil_protector.gsc:40`) — direct
SpawnActor only.

**F21. TRIPWIRE ARC / ADMIN ACCESS** — `BUILDABLE, deferred`
Tripwire: two quick shots plant linked anchors bridging a crackling data-fence
(segment-train movers, NOT one stretched .efx — FX have baked geometry). Admin Access:
full-charge a hack terminal to boot a 60s escort protector (ALLY gold spawner is
load-proven). Both parked: M2/M3 already deliver area-denial and ally moments; revisit
post-launch as a content-update beat (idea: SIREN/WIRE daemon variants).

---

## 4. Balance & tuning (all dvar-resolved, defaults in `_acc_cyberjack.gsc`)

| Dvar | Default | What |
|---|---|---|
| `acc_cj_hops_base` | 2 (+1/tier) | chain hops (AS-BUILT name; M1 2026-07-17) |
| `acc_cj_hop_range` | 220 | max hop distance (u) |
| `acc_cj_dot_frac` / `_frac_tier` / `_ticks` | 0.195075 / +0.0459 / 3 | decompile DoT (exact-damage marked — lands verbatim; ×0.9 all-lane nerf 2026-07-27 took 0.34/+0.08 → 0.306/+0.072; ×0.75 retune 2026-08-01 → 0.2295/+0.054; ×0.85 overall −15% 2026-08-03 → current) |
| `acc_cj_slow_rate` / `_ms` / `_ms_tier` | 0.8 / 3500 / +500 | corruption flicker-slow (window outlives the DoT) |
| `acc_cj_harvest_chance` | 0.20 (×2 at tier ≥2 BLACK ICE) | decompile shard proc (rarified 2026-07-17: was 0.35) |
| `acc_cj_harvest_cap_base` | 3+round/10 | per-round shard cap, ALL cyberjack tags (rarified 2026-07-17: was 6 — the binding constraint, so this is the real rarity lever) |
| `acc_cj_max_chains` / `acc_cj_bolt_speed` | 2 / 700 | live-chain cap per player / arc visual speed |
| `acc_cj_rift_life_ms` / `_dot_frac` | 8000 / tune | breach rift |
| `acc_cj_brutus_gun_chance` | 0.2375 | Brutus (Trench Warden) gun-drop roll (−5% relative 2026-08-03; was 0.25) — 0% while a CYBERJACK is in rotation |
| `acc_cj_sync_per_kill/chain/harvest` | 2/8/1 | SYNC% gains |
| `acc_cj_root_radius` | 900 | ROOT ACCESS reach |
| `acc_cj_brick_ms` | 12000 | Avogadro brick duration |
| `acc_cap_cyberjack` | 1 | wonder claim cap (matches the other five) |
| box weight | — | **NONE — decision 2: never in the box** (no pool entry, no weight row) |
| PaP | WONDER bucket | 10000/15000/20000 + shard surcharge 25/50/75 |

Wonder-roster ripple: the page copy becomes **SIX wonder weapons** (at M4, when the quest
ships it); the claim-cap tables and `docs/33` pricing gain one row. **`_acc_paradise.gsc:1171`
does NOT gain it** (decision 2 — Paradise loot would bypass the quest).

---

## 5. Implementation map (every touchpoint, mirroring the traced Fire Bow wiring)

**New files**
- `scripts/zm/zm_abandoned_cyber_city/_acc_cyberjack.gsc` — the weapon brain: corruption
  state, chain driver, harvest bookkeeping, rift, SYNC/ROOT, brick/purge, quest hooks.
  Orchestrated by `acc_main` (`#using` + init), threads per-player on connect.
- `scripts/zm/zm_abandoned_cyber_city/_acc_cyberjack.csc` — client FX twin **only if** new
  scriptmover CFs are needed; FIRST reuse the chassis' already-registered CFs
  (`elem_storm_bolt_fx`, `elem_storm_zap_ambient`, `elem_storm_fx`, whirlwind rumble) —
  their budget is already paid. Any genuinely-new CF: ONE shared 2-bit cyberjack scriptmover
  CF, registered in a `REGISTER_SYSTEM` autoexec on BOTH sides (post-finalization
  registration = hard map-load crash).
- `fx/acc/cyberjack_*.efx` — sizeGraph-scaled clones (arc filament, decompile glyphs, rift
  ring, root shockwave). Clone into `fx/acc/`, NEVER scale a pack-shared .efx in place.
  Each needs an `fx,` zone line + csc `#precache(client_fx,…)` — a dangling ref **silently
  kills the whole weapon** (grep assetinfo **`,weapon,apex_lstar_zm`** after every link —
  NOT the old storm-bow name, which still packs via the hb21 include and would vacuously pass).
- `sound/` new aliases via `.szc` (handshake, carrier-lock, packet-chatter, ACCESS GRANTED,
  brick/purge stings) — 48k/16-bit PCM through `tools/resample48k.js`.
- LUI: terminal-HUD widget (new `.lua`, wired like the LB panels — dvar-poll ladder now,
  `SetControllerUIModelValue` relay at M4); L3akMod global whitelist applies.

**Edited files (AS SHIPPED — L-STAR chassis, the Fire Bow's footprint)**
- `gamedata/weapons/zm/zm_levelcommon_weapons.csv` — one row: `apex_lstar`,
  upgrade=self, **`in_box FALSE`** (decision 2 — and it never enters the pool array, which
  is the real authority), `is_limited TRUE limit 1`, class `special`, `is_aat_exempt TRUE`,
  `is_wonder_weapon TRUE`.
- `_acc_map_randomizer.gsc` — **NO box-pool entry, NO `acc_box_weight` row** (decision 2);
  only `wonder_cap_key :284` → `"cyberjack"` + `wonder_cap_limit :295`
  (dvar `acc_cap_cyberjack`) so the claim system still governs the quest grant.
- `_acc_paradise.gsc:1171` — **do NOT add** (decision 2: Paradise loot would bypass the
  quest); add an explicit exclusion comment so a future wonder-roster sweep doesn't
  "helpfully" restore it.
- `_acc_dev.gsc` — dev-grant of the CYBERJACK via the box weapon_give path
  (`level.acc_dev`-gated; the `:101` Fire Bow pattern) — the ONLY acquisition until M4.
  **TRAP (found 2026-07-20, the "Brutus never drops at 100%" hunt):** this per-life
  dev-grant means EVERY dev session has a CYBERJACK holder, so the Brutus gun-drop's
  "only 1 in rotation" gate (`cyberjack_in_rotation`'s primaries scan) was permanently
  closed in dev — the drop returned false BEFORE the roll at any chance, and the gun can
  hide in a background Mule-Kick slot so it *looks* like nobody holds one. Fix:
  `cyberjack_in_rotation()` skips the holder scan under `IS_TRUE( level.acc_dev )`
  (the `acc_cj_pickup_live` gate still prevents stacked ground pickups); ship behavior
  unchanged. A dev-gated `[CJ]` trace (`cj_log`, the sci_log pattern) now prints every
  gate decision (death-watch armed / death state / rotation-holder / weapon-resolve /
  roll / pickup commit-grab-expire) so the next dev-armed kill is self-diagnosing.
- `_acc_pap_levels.gsc` — `pap_price_bucket :372` WONDER row; clone the four firebow
  functions (`is_cyberjack`/`cyberjack_tier`/`acc_pap_cyberjack`/`make_cyberjack_packable`)
  + the 6 hook points (`:222/:530/:568/:959/:1253/:1572`).
- `_acc_weapon_variants.gsc` — no-twin special lists `:360/:508` + in-place guard `:513`.
- `_acc_damage.gsc` — balance mult row (IsSubStr `apex_lstar`, **0.2754** as-built after the 2026-08-03 reshape's +50% shooting buff; was 0.1836 after the same-day overall −15%, 0.216 after the 2026-08-01 −25% retune, 0.288 after the 2026-07-27 all-lane −10%); `is_energy_weapon`
  row; Glitch one-shot row (the `:476` pattern); the F12 weakness-flip + F11 melee-purge
  notify in block 0c5 (M3).
- `_acc_cyberjack.gsc` (NEW, git-tracked = ours) — the whole combat identity: jack-in
  chain, corruption slow/DoT, decompile harvest, shot electric ball, TEMPEST tornado. The
  chain/orb bolts reuse the Triple Take's `acc_ttk_bolt_fx` scriptmover CF (value 3 =
  `acc_cj_bolt_violet`); the tornado uses the DE storm's `elem_storm_*` CFs. (The vendored
  `_zm_weap_elemental_bow_storm.gsc` is UNTOUCHED — the bow returned to dormant.)
  **TEMPEST balance (2026-07-26, user "nerf it by 20%" + "another 10%... Its just so
  strong" + "I dont want it to just one hit zombies"):** two stacked changes.
  (1) tough-enemy (boss/Shielded/mini-boss) DoT `acc_cj_storm_dot_frac` **0.5 → 0.4 →
  0.36** — per 0.3s tick = `0.36 × zombie-round-HP × lvl-mult` (L4 mult 5 → 1.8× zHP/tick,
  was 2.5×). (2) the normals lane is NO LONGER a guaranteed one-shot: `storm_zombie_tick`
  deals **SET flat damage per tick** — `acc_cj_storm_zombie_dmg` (default **1080**, the
  −20%−10% of a 1500-class base) × the same lvl-mult, deliberately NOT round-scaled so the
  zombie HP curve overtakes it: one-hits at L1 through ~r10, L2 ~r17, L3 ~r20, **L4 (5400)
  ~r26**; past that even a full charge needs multiple ticks ("still a one hit for earlier
  round but not forever — you would need a full recharge on really late round"). Applies to
  the tornado AND the small jack-in finisher storms (same field loop at lvl 1). Zombies
  already corrupted now also take storm ticks (the old one-shot skipped them). Wonder-weapon
  kills (incl. every Cyberjack kill) also pay HALF kill money since 2026-07-26 (docs/05).
  **(3) 2026-07-27 (user "how much they slow currently should only be a max charge. I can do
  a 15 bullet charge and its super OP. Make sure all aspects of it scale up"): the storm SLOW
  now scales with charge level** — `acc_cj_storm_slow_rate` (0.5) is the MAX-charge rate only;
  the slow fraction interpolates linearly: **L1 12.5% / L2 25% / L3 37.5% / L4 50%** (finisher
  micro-storms = the light L1 slow). With this, EVERY strength axis of the storm scales with
  the charge: damage (both lanes ×lvl-mult), life (+1.2s/lvl), range (+90u/lvl), funnels
  (=lvl), bolt visuals (lvl+1), slow (12.5%×lvl), ammo cost (15×lvl). Only cadence (0.3s
  tick), the 4-storm cap, and the corruption mark (the same passive every bullet applies)
  stay charge-flat. **(4) 2026-07-27 ALL-LANE −10% (user "give the cyberjack another 10%
  nerf... They are just too good"):** every damage lane ×0.9 — bullet stream balance mult
  0.32 → **0.288** (~234/shot, ~2786 base DPS; the chain hops inherit it), storm normals base
  1080 → **972** (one-hits L1 ~r9 / L2 ~r16 / L3 ~r20 / L4 4860 ~r26), storm boss DoT frac
  0.36 → **0.324** (L4 = 1.62× zHP/tick), decompile DoT 0.34/+0.08 → **0.306/+0.072**.
  **(5) 2026-08-01 EXPONENTIAL CHARGE CURVE + −25% ALL-AROUND, MAX CHARGE FROZEN:** the
  linear charge→strength ladder (mult 1/2/3/5 by lvl — i.e. ×1.25 at L4) is replaced by a
  **cubic** `charge_mult(lvl) = 5 × (lvl/4)³` → **L1 0.078 / L2 0.625 / L3 2.109 / L4 5.0**
  (L4 EXACTLY unchanged; bases `acc_cj_storm_zombie_dmg` **972** and `acc_cj_storm_dot_frac`
  **0.324** UNCHANGED). Storm normals per 0.3s tick 972/1944/2916/4860 → **75/607/2050/4860**
  (L1 deliberately near-worthless); boss/tough DoT per tick 0.324/0.648/0.972/1.62 × zHP →
  **0.025/0.203/0.684/1.62**. The tornado SLOW now rides the same cubic curve (`charge_mult/5`,
  superseding (3)'s linear interp): 12.5%/25%/37.5%/50% → **0.8%/6.3%/21.1%/50%** (max
  unchanged). Jack-in chain FINISHER micro-storms drop the L1 lookup for a flat **0.75**
  multiplier (= a clean −25% of their old lvl-1 output: normals **729**/tick, boss
  **0.243×** zHP/tick). Bullet stream −25%: `_acc_damage.gsc` mult 0.288 → **0.216**
  (~175.5/shot, ~2089 base DPS; the chain hops inherit it — they MagicBullet the held
  weapon). Decompile/corruption DoT ×0.75: `acc_cj_dot_frac` 0.306 → **0.2295**,
  `acc_cj_dot_frac_tier` 0.072 → **0.054**. UNCHANGED: 550ms charge step, 15×lvl ammo cost,
  storm life/range/funnel scaling, harvest economy, PaP tier ladder — everything at max
  charge is exactly as before.
  **(6) 2026-08-03 OVERALL −15% (every damage lane ×0.85, max charge INCLUDED — supersedes
  (5)'s max-charge freeze):** bullet stream bal mult 0.216 → **0.1836** (~149.2/shot, ~1776
  base DPS; chain hops inherit it), storm normals base `acc_cj_storm_zombie_dmg` 972 →
  **826** (per 0.3s tick L1 64 / L2 516 / L3 1742 / L4 4130, finisher 619; L4 one-hits
  through ~r24), storm boss DoT `acc_cj_storm_dot_frac` 0.324 → **0.2754** (L4 1.377× zHP,
  finisher 0.207×), decompile DoT `acc_cj_dot_frac`/`_tier` 0.2295/+0.054 →
  **0.195075/+0.0459**. The cubic `charge_mult` (5×(lvl/4)³) and the finisher 0.75 mult are
  UNTOUCHED (scaling them too would double-dip, and charge_mult also drives the tornado
  SLOW). UNCHANGED non-damage axes: slow rates, storm life/range/funnels, 15×lvl ammo,
  550ms charge step, harvest economy, PaP/OC ladders.
  **(7) 2026-08-03 IDENTITY RESHAPE (same day, on top of (6) — user "actually needs a 30%
  nerf. Mostly the charge up... nerf all charge up stages by 25% and buff the actually
  shooting by 50%"):** the GUN becomes the weapon's core and the charge nuke recedes.
  **Charge-up (tornado) stages ×0.75:** storm bases `acc_cj_storm_zombie_dmg` 826 → **620**
  (per 0.3s tick L1 48 / L2 387 / L3 1307 / L4 3100; L4 one-hits through ~r21; net vs the
  played 972 build ≈ ×0.6375) and `acc_cj_storm_dot_frac` 0.2754 → **0.20655** (L4 1.033×
  zHP/tick; net vs played ≈ ×0.6375). The jack-in FINISHER micro-storms are shooting-derived,
  NOT a charge stage — their flat mult moved 0.75 → **1.0** to exactly compensate the shared
  base cut (finisher output unchanged: 620/tick, 0.207× zHP). **The actual shooting ×1.5:**
  bullet-stream bal mult 0.1836 → **0.2754** (~223.8/shot, ~2664 base DPS; net vs the played
  0.216 build = **+27.5%**; chain hops inherit). `charge_mult` cubic curve, tornado SLOW,
  decompile DoT (still at (6)'s 0.195075/+0.0459), ammo/charge/harvest all UNCHANGED.
- `_acc_events_hack.gsc` — terminal state machine grows purge/RAM/compile modes (ONE
  prioritized `set_hint_for_state`; unique-word hints).
- `_acc_boss_avogadro.gsc` — counter-hack director (F11) + ICE-breach flag his loops check
  (F12). `_acc_boss_glitch.gsc` — capture branch (F13) through real death.
- `_acc_kortifex.gsc` — new vox rows (`_0` suffix). `.str` — SEGFAULT + names (filename
  prefix trap). `_acc_leaderboard.gsc` + `backend/leaderboard/worker.js` — M4 stats.
- `zone_source/zm_abandoned_cyber_city.zone` — fx lines; scripts already listed (`:275-276`);
  the weapon assets already ride `include,hb21_elemental_bows` (`:363`).
- **Box card: MOOT** (decision 2 — never in the box, no card ever renders; the 5-bit
  `acc_box_gun` CF problem vanishes). The weapon's *display name* (kill feed, loadout,
  Aetherium) is separate and lands at M1. `tools/gun_ids.json` still appends id 32 for
  usage telemetry + LB records (that transport is the dvar blob, not the capped CF).
- Docs same-commit: docs/04, 25, 33, 36, 38 (SIX wonders), REQUIREMENTS.md:78, CHANGELOG.
  CREDITS: HB21 storm-bow line beside the Fire Bow's.
- `.map` (M4 ONLY): 5 fragment nodes + compiler terminal → cod2map + **LED bake gate**.

**Build loop:** M0–M3 are GSC/CSV/zone/FX-only → `sync_to_modtools.ps1` →
`build_map.ps1 -GscOnly` → fresh `.ff` check + assetinfo grep → `PLAY_NORMAL.bat`
(dev/god hardcoded in `acc_resolve_dev_flags()` for test sessions). M4's `.map` edits =
full pipeline WITH LED.

---

## 6. Milestones

| M | Ships | Build risk |
|---|---|---|
| **M0** | Chassis online: CSV/PaP/tiers/claim-cap + dev-grant (NO box — decision 2) | linker-only; the whole add-a-gun pipeline learned on the lowest-risk surface |
| **M1** | Corruption chain + harvest + tiers-with-teeth + HUD + audio + kill-feed + boot | the weapon becomes OURS; first shareable clips |
| **M2** | Breach Rift + ROOT ACCESS/brown-out + RAM + TRACEROUTE choreography | the trailer beats |
| **M3** | Avogadro rivalry (brick + ICE-breach) + Jailbreak + announcer beef | the "no other map has this" systems |
| **M4** | Compile quest + daemon roll + records + talks-back + co-op HUD relay | the content-update headline ("2.0"); LED-gated |
| **M5** | Spiked experiments (real daemon, rooted zombie, tripwire) | only what passes its spike |

Each milestone is independently shippable and independently marketable (M1 = reveal clips,
M2 = trailer, M4 = the "CYBERJACK 2.0" update wave the growth plan calls for).

---

## 7. Proven-technique inventory (what the recipes cite)

1 script-owned charge/hold (Fire Bow, Havoc) · 2 MagicBullet volleys — **hitscan guns
only, BANNED on this projectile bow** · 3 undefined-attacker env DoDamage · 4 DoT zones
(round-fraction / boss divisor) · 5 ASMSetAnimationRate slow + restore watchdog ·
6 scriptmover-CF geotrail movers · 7 `.efx` sizeGraph clones · 8 the chassis' own
chain-gather (`storm.gsc:156`) · 9 stock zombie POI lure · 10 PhysicsExplosionCylinder +
Thundergun knockdown · 11 per-target rules (`_acc_damage`) · 12 in-place tier counter
(`acc_firebow_tier` template) · 13 `acc_data_shards::grant_player` · 14 Kortifex vox
registry · 15 dvar-read GSC→LUI channel (+ SetControllerUIModelValue relay for peers) ·
16 terminal state machine (`_acc_events_hack`) · 17 shard pickup spawner
(`_acc_data_shards:222`) · 18 friendly AI (CP ally spawner; wolf-bow movers) · 19 per-boss
weakness block 0c5 · 20 SetDrawName nameplates · 21 48k audio pipeline · 22 the chassis'
pre-registered rumble/FX CFs (budget already paid) · 23 per-zombie flags honored by
`_acc_zombie_speed` · 24 navmesh-project + DisconnectPaths pairing · 25 **box weapon_give
path for ALL grants**.

## 8. Trap register (verifier-compiled; check before EVERY feature)

Damage/credit: undefined-attacker kills pay nothing (use player-attacker DoDamage for
chains; death-event callbacks for env-kill payouts) · never MagicBullet the bow · Glitch
teleports between gather and hit (re-validate) · boss filters complete + never mutate
arrays mid-foreach. FX/CF: both toplayer+actor CF pools FULL · scriptmover CFs registered
autoexec-only · rumble CF is 1-bit (hold high) · min 0.25s mover flight · muzzle-offset
births · no world-PlayFX of looping fx · dangling .efx/.accu = silent weapon kill.
Atmosphere: fog/vision ride override states inside `_acc_atmosphere` (single-authority +
revive force-restore) · per-player flicker = `visionset_mgr` `zm_trap_electric` only.
AI: frame-0 spawn refusal · z≤-240 emergence forcing · below-z-1000 cull whitelist ·
`defaultGoalRadius` statue bug · POI ents deactivated+deleted, never on the actor itself.
Economy: one shared per-round cap across all `cyberjack_*` source tags · trench-only rule
amendment needs user sign-off (§3-F2) · atomic dual-currency spends via `try_spend` +
`zm_score`. UX: no per-gun SetHintString EVER (250-slot leak) · unique-word hints (router
hijack) · `.str` filename prefix · announcer overlap-drop retry. Weapon state: brick holds
clip AND reserve + guards all refill paths · charge resets on mid-draw ammo writes (defer
pokes) · all grants via the box give path. Build: `-GscOnly` until M4 · LED bake gate for
`.map` · `.sabs` lock · assetinfo grep after every link · leaderboard dev/god no-post.

## 9. Marketing tie-in (docs/38)

The CYBERJACK headlines every growth beat: the **SIX wonder weapons** page bullet; the
TRACEROUTE/rift/brown-out clips ARE the trailer beats; "the wonder weapon the boss can hack
back" and "the gun that farms the trench currency" are the cross-fandom short hooks; the
LONGEST TRACE record feeds the leaderboard record-chase; M4's compile quest is the "2.0"
content-update wave and the "buildable wonder weapon" collection credential. Keep the
compile-quest solution embargoed pre-release for a world-first race.

## 10. Decisions — RESOLVED (user, 2026-07-17)

1. **F2 economy amendment: APPROVED.** The CYBERJACK prints shards above ground — that IS
   its identity. The shared per-round cap table across all `cyberjack_*` source tags is
   MANDATORY (the approved exception must not trivialize abyss-door pricing).
2. **Acquisition: QUEST-ONLY. NO BOX. EVER.** The CYBERJACK never appears in the public
   mystery box — the ICEBREAKER COMPILE (F15) is the ONLY player-facing acquisition.
   Ripples baked into this spec:
   - **M0 is re-scoped to "chassis online (dev-grant only)"**: CSV row + PaP + tiers +
     damage rows land, but the gun is NOT added to the `box_weapons` pool array (the array
     is the sole authority — absence = never rolled). Dev/test acquisition = a
     `level.acc_dev`-gated grant **through the box's own weapon_give path** (the
     `_acc_dev.gsc:101` Fire Bow pattern — charge levels break on raw gives).
   - **EXCLUDE from the Paradise wonder-loot array** (`_acc_paradise.gsc:1171`) — Paradise
     granting it would bypass the quest. The claim cap (1/match) still registers.
   - The public weapon therefore SHIPS WITH the quest — the CYBERJACK is the M4 "2.0"
     headline in its entirety, one big reveal (stronger marketing than a drip).
3. **Box card: MOOT.** No box entry → no box card ever renders → the 5-bit `acc_box_gun`
   CF pool problem vanishes. (Telemetry/LB still append gun id 32 in `gun_ids.json` — the
   usage/records transport is the dvar blob, not the capped CF.)
4. **Voice lines: the installed [West] Kortifex pack (user's Downloads, verified
   2026-07-17) — 46-line FIXED inventory, no bespoke lines.** F14 re-scopes to repurposing
   fitting lines at zero production cost: `zann_abox_byebye` → Avogadro bricks your gun;
   `zann_apfp_fullpower` → SYNC hits 100%; `zann_apkb_kaboom` → rift collapse;
   `zann_agvr_laughter` / `zann_aror_painedangryroar` → ICE-breach reversal (his rage);
   `zann_asen_tearthemtopieces` / `zann_asen_fetchmetheirsouls` → ROOT ACCESS.
   The scripted beef lines ("The hacker... hacked.") become OPTIONAL polish gated on new
   audio ever materializing (AI TTS or cut — do not block any milestone on them).
