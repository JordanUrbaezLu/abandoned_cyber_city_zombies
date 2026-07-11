# 24 — Punishing the Middle: Design Investigation

> **Status: investigation record — its shipped outcome is the LOCKDOWN CHALLENGE (Glitch Purge).**
> This doc captured the design study for a "punishing middle." What actually shipped out of it is the
> **per-round red-alarm room lockdown** (§11, `_acc_lockdown.gsc`) that grew into a **full trap
> challenge** — 30 confined Glitch Stalkers → clear the room → free boss item — now living in
> `_acc_lockdown_challenge.gsc` and documented in full in **[26_lockdown_challenge_room.md](26_lockdown_challenge_room.md)**.
> Both the lights and the purge are wired into `acc_main::init()` but are **hardcode-disabled by
> default** (`acc_lockdown_challenge_on` defaults 0; enable with `+set acc_lockdown_challenge_on 1` —
> `_acc_lockdown.gsc:91`, `_acc_lockdown_challenge.gsc:30`).
>
> The two big directions studied here — **A (Contaminated Core)** and **B (Toll Daemon)** (§3–§6) —
> and the recurring "reason to cross" bottom-pull (§2, §10) **were never built** (no
> `_acc_contaminated_core.gsc`, no Toll Daemon / Plaza Regulator code exists anywhere in `scripts/`).
> They remain open design options, kept here as the reasoning trail. Output of a 26-agent design
> workflow (5 research deep-dives → 5 competing concepts → 3 adversarial judges each → synthesis),
> re-grounded against the real `.map` + scripts.
>
> Companion docs: **[02_layout.md](02_layout.md)** (flow / cut-vertex / decon), **[08_enemies.md](08_enemies.md)**
> (difficulty philosophy), **[06_replayability.md](06_replayability.md)** (modifiers / per-run state),
> **[26_lockdown_challenge_room.md](26_lockdown_challenge_room.md)** (the shipped Glitch-Purge trap this study led to),
> **[10_perks.md](10_perks.md)** (the live 4-of-10 perk rotation), **[05_mechanics.md](05_mechanics.md)** (hack / shard economy).

---

## 1. The goal & the trap

**The ask:** make the *middle* of the map dangerous to dwell in, so players naturally settle at one
of the two poles — **Plaza** ("first room", south) or **Lab** (north apex) — and
only cross the middle when they must, with that crossing carrying real risk and *fear*. The leading
idea was **a new entity that controls the middle**.

**The geography that makes this work (and constrains it):**

```
            LAB   ← north pole: PaP, ALL 10 perks (rotating 4-of-10), Overclock terminal,
           /    \    wonder-weapon craft, full-boss venue.  NEVER sealed.
        ROOF    VAULT   (Roof = best late train, one hop from Lab)
           \    /
           CORP  ← THE MIDDLE. Cut-vertex hub: the power switch, box, hack terminal, 2 trains.
           /    \    NEVER sealed (sealing it disconnects Plaza↔Lab).
      MARKET    ALLEY
           \    /
          PLAZA  ← south pole: no perks, no box, and (2-gun directive) NO wallbuys either.
```

To go Plaza↔Lab you **must** pass through **Corp + one lower spoke + one upper spoke**. Corp is the
sole articulation point in the zone graph — which is exactly why it's the right place to make
fearsome, and exactly why it **can never be a wall**: seal it and you strand the team from the Lab.
Any "punishing middle" must be a survivable **toll** (damage / fear / cost you can always run out of),
keeping **≥2 traversable routes through Corp at every frame**.

**The trap underneath the question (the most important finding):** the map is a **one-way ratchet
toward the Lab.** Every recurring reason to move lives at or beside the Lab pole (PaP, all perks,
Overclocks, wonder-weapon, Mega Bottles), Roof — the best late train — is one hop from Lab, and Data
Shards are **portable** (corpse drops + passive timer follow the player anywhere). Plaza is barren:
no perks, no box, and no wallbuys (the box-only arsenal directive removed them all). So layering
a scary middle onto today's economy doesn't make players cross *more* — **it freezes them at the
Lab+Roof cluster forever and never sends them back down.** The fear lands on nobody because nobody
crosses. A punishing middle is **necessary but insufficient.**

---

## 2. The crux: why would players cross at all?

**This decision the whole feature lives or dies on, so it leads.** Without a manufactured,
**recurring, NON-PORTABLE, bottom-anchored demand**, both directions below degrade into a wall that
either strands players or freezes them at the top. The demand must satisfy all of:

- **Terminate at Plaza** (never sealed) — *not* Corp or Roof (both are Lab-adjacent and would let
  players shortcut the trip).
- **Not be Shards or any portable currency** — players already earn those everywhere. It must be a
  unique resource/service that exists *only at the bottom*.
- **Be newly placed** — Plaza has no existing anchor to lean on.
- **Fire on a cadence** (every ~3 rounds) so the commute *recurs* rather than being a one-time errand.

The elegant coupling all five concepts converged on: **the trip down buys the trip back up.** A new
**Plaza Regulator console** (hold-to-bank, every few rounds) grants a non-portable credit you redeem
at the Lab — *and* simultaneously **resets the middle's safe window to maximum.** Descending is
rational because it pays for the team's next safe ascent.

### The reward — TWO candidates, decision OPEN (see §10 Q1)

| Option | Pro | Con |
|---|---|---|
| **A. Free Overclock tier on held weapon** | Buildable now; value *scales* with how deep you already are (Overclocks cost 1/2/3/4/5 Shards/tier), so it stays meaningful late. | Risks **decaying** as portable Shards inflate; needs new redemption plumbing at the Lab Overclock terminal. |
| **B. Perk-rotation re-roll token** | **Never goes stale** — re-rolling the Lab's 4-of-10 lineup is always valuable. | The rotation it re-rolls now **ships** — `_acc_perk_doors.gsc` opens a random 4-of-10 alcoves and re-rolls every round (`apply_round`, `_acc_perk_doors.gsc:187`). What's still unbuilt is a **player-triggered re-roll** (token/console) on top of that automatic per-round roll. |

> **The judges' single most consistent criticism across all five concepts:** this bottom-pull is the
> **load-bearing, least-built, most-fragile** half, and several concepts mislabel net-new economy
> plumbing as "reuse." Treat the Plaza console + credit as the **primary build risk**, not a polish
> pass bolted onto a cool hazard.

---

## 3. The two directions, in brief

A 26-agent panel generated and adversarially scored 5 concepts. Two are the finalists below (neither
was built — see the banner); three are parked/rejected (§9). In practice the map went a different
route entirely: the §11 lockdown grew into the shipped Glitch-Purge trap ([43](26_lockdown_challenge_room.md)).

| Direction | Avg | One-liner |
|---|---|---|
| **A — The Contaminated Core** (environmental) | **7.0** | The middle *breathes*: safe windows + a telegraphed lethal "saturation" you must dash through. No creature — the *place* is the threat. |
| **B — The Toll Daemon** (your entity idea) | 6.7 | A named boss leashed to Corp that *taxes presence* (drain + lock-on), reskinned stock zombie, dies to a PaP gun in 1–2s. Highest raw feasibility (8). |

Both are fleshed out below. Both pair with the §2 Plaza console.

---

## 4. Direction A — **The Contaminated Core** (environmental)

**Concept.** Corp + its four corridor mouths cycle a contamination rhythm: **~50s "purge" (safe)** →
**~6s telegraph** → **~18s "saturation"** where standing in the band stacks an escapable, draining
**exposure** debuff (graduated sub-lethal damage + point drain). A clean dash through (~4–6s exposed)
costs HP and points; loitering the full window downs you. **Never a seal** — all four mouths stay open
and spawning, so the cut-vertex and ≥2-exits rules hold by construction.

**How it controls the middle.** The hazard exists *only* where every Plaza↔Lab path converges — the
Corp interior (the existing `corp_zone` info_volumes, tested with the verified
`get_zone_volumes` / `player_in_zone_volumes` `IsTouching` pattern from `_acc_decontamination.gsc`) plus
the four 256u corridor mouths (anchored to placed structs so the test survives the planned Corp shrink).
A zone-state genuinely *owns* the middle in a way a creature can't: **it cannot be kited or lured to a
pole.** A boss can be dragged to the Lab and farmed; a *place* can't.

**How it stays fair** (honors [08_enemies.md](08_enemies.md)):
- **No sponge:** there's no HP bar to chew — the threat is escapable DoT. *Literally* "movement solves
  most problems": leave the band and exposure decays.
- **≥2 exits, always:** saturation never closes a route; the band is fully traversable every frame.
- **Not a forced camp:** it *punishes* dwelling — structurally the opposite of a camp, so it can never
  become one. Boss rooms (Lab) stay the only forced camp.
- **No invisible damage:** exposure is an on-screen meter (clientfield-driven), preceded by a 6s
  telegraph — rising 3D emitter at the fountain center + `iprintlnbold` + reddening `.csc` haze
  creeping in from the four mouths. Players learn the rhythm in one run.

**First-pass numbers** (all live `acc_core_*` dvars — tunable with no rebuild):

| Knob | First pass | Rationale |
|---|---|---|
| `acc_core_purge_sec` | 50 | Generous safe window; most crossings are free. |
| `acc_core_hot_sec` | 18 | Saturation is the minority of the ~68s cycle. |
| `acc_core_telegraph_sec` | 6 | Enough to decide "sprint the gap or wait." |
| `acc_core_dot_per_tick` | tuned so a clean dash ≈ 35–45% base HP at R10–15 | Survivable-but-scary; loiter = down. |
| `acc_core_drain_pts` | ~150/tick past a 2-tick threshold | Economic sting on a hot crossing. |
| `acc_core_first_round` | 5 | **Never fires during decon's R1–4 seal window.** |
| `acc_core_console_rounds` | every 3 | Recurring but not a chore-treadmill. |
| `acc_core_mouth_radius` | tight to the 256u corridor footprint | Minimize phantom through-wall exposure (§8 risk 4). |
| `acc_disable_core` | dev-gate mirroring `level.acc_disable_decon` | Force-open dev map stays roamable. |

**Scaffold it builds on** — `_acc_contaminated_core.gsc` (new) + a thin `_acc_contaminated_core.csc`
for haze/vignette/meter, bridged by a clientfield (the only cross-VM path; `.csc` can't call `.gsc`):
- Phase loop + telegraph cadence: clone of `_acc_decontamination.gsc`'s warn→countdown→effect phase,
  **looping** instead of one-shot.
- Band occupancy: `get_zone_volumes` + `player_in_zone_volumes` for `corp_zone`, plus DistanceSquared
  mouth spheres (the Overload `is_player_on_point` idiom).
- Graduated damage: decon's laststand-routed `player DoDamage(dmg, player.origin)` with `dmg < health`
  (injures instead of overkilling).
- Point drain: `zm_score::minus_to_player_score` (the elite-EMP idiom, with the existing negative-clamp floor).
- Ships behind a modifier (`level.acc_mod_contaminated_core` via `_acc_modifiers.gsc`'s `all[]` array).

**Pros:** No live AI ⇒ **sidesteps every AI crash class this project has been bitten by** in one move
(`SetScale` crash, Brutus-class spawn→move CTD, second speed-writer fight, bodies past the 24-alive
cap). Can't be kited away. Pure recombination of proven in-repo code; zero new assets; fresh-clone-safe.
No feasibility *or* systems-fit killer flaw from any judge.

**Cons:** No *face* to fear (the user's instinct was a creature). Tuning a sub-lethal repeating DoT to
be scary-but-fair across Jug/armor/revive is finicky (§8). The "place is alive" read leans on the
`.csc` haze landing as v1, not v2.

---

## 5. Direction B — **The Toll Daemon** (named entity owning the middle)

**Concept.** A named mini-boss ("Toll Daemon" / "The Throttle") **leashed to Corp** that *taxes your
presence* rather than blocking it: while you're in the middle it locks on (telegraphed) and **drains
points + applies escalating pressure**; it dies to a PaP gun in 1–2s, and killing it **buys a clean
crossing window** (a risk/reward beat — kill it to cross safely, or sprint past and pay the toll).

**How it controls the middle.** A near-pure clone of the proven **`_acc_boss_glitch.gsc`** scaffold —
a promoted stock zombie reskinned to the **stock Giant body** (crash-safe, **zero new assets**), with
its own cadence/spawn/death-reward. Leashed to Corp via `SetGoal` on the Corp struct; aggro/tax gated
on Corp-zone occupancy (same `IsTouching` pattern as A). The feasibility judge **verified every cited
scaffold exists** — this scored the highest raw feasibility (8) of all five concepts.

**How it stays fair:** dies fast (no sponge — honors the "PaP kills any elite in 1–2s" rule); the tax
is escapable (leave the band, leash resets); the telegraphed lock-on is the read; killing it is the
counterplay. ≥2 exits preserved (it taxes, never seals).

**The three issues that must be fixed before it ships** (judges caught all three; all fixable, but
together they make this the **larger balance surface / higher-risk** pick):
1. **False reuse — the "disable perks" punishment.** `disable_perks_for` calls the **map-wide**
   `perk_pause_all_perks()`, which would kill perks *everywhere*, including on the carrier mid-crossing
   and on safe teammates at the poles. **Fix:** lock a *discrete* interaction (the Overclock/PaP
   trigger) instead of pausing perks, or build a genuinely per-player effect.
2. **Recurring objective leans on a per-run safety net.** The proposed recurring "coolant/cell" beat
   borrows Overload's wipe-safety, which is **per-run, Cyberware-gated, 2-attempts-capped** and does
   not generalize to an every-few-rounds cadence (solo soft-lock risk). **Fix:** build a real recurring
   respawn net.
3. **Overstated spawn-steering.** "Bump `level.zombie_total` toward the player's mouth" overstates the
   primitive — `zombie_total` raises the round *total*, it does not *steer* spawns (directional
   convergence needs a POI lure).

**Pros:** A **face to fear** — matches the original instinct. Highest feasibility; clones a scaffold
that already ships (`_acc_boss_glitch`). A killable threat gives a satisfying risk/reward "clear the
middle" beat that a faceless hazard lacks.

**Cons:** **Kiteable** — a boss can be dragged toward a pole and farmed/abused, undercutting "owns the
middle." Larger balance surface (the 3 fixes above). Adds an AI body — must respect the 24-alive cap
and avoid the documented worst-stack (tight Corp + sprint + 4p). Carries the live-AI crash classes A
avoids entirely.

---

## 6. Side-by-side

| Dimension | A — Contaminated Core | B — Toll Daemon |
|---|---|---|
| **Threat is…** | the *place* (zone-state DoT) | a *creature* (leashed mini-boss) |
| **A "face to fear"?** | No | **Yes** |
| **Can be kited to a pole?** | **No** | Yes (the core weakness) |
| **Live-AI crash classes** | **None** (no AI) | Inherits all (mitigated by Glitch scaffold) |
| **Adds bodies vs 24-cap** | No | Yes — must budget |
| **New assets** | None | None (stock Giant reskin) |
| **Build base** | `_acc_decontamination` engine | `_acc_boss_glitch` clone |
| **Counterplay** | dash the safe window / time the cycle | kill it for a clean window / sprint past |
| **Judge avg** | **7.0** (no killer flaw) | 6.7 (3 fixable issues) |
| **Biggest risk** | tuning sub-lethal DoT; `.csc` read | kite-abuse; the 3 false-reuse fixes |

Both share the **same** §2 Plaza-console reason-to-cross and the same fairness guarantees. The fork is
really **"faceless-but-bulletproof"** vs **"named-but-riskier."**

---

## 7. How each composes with existing systems

| System | Guard (applies to both unless noted) |
|---|---|
| **Decontamination** (double-count risk) | **Suspend the hazard entirely during the `acc_decontamination_start..complete` evac window**; gate `first_round = 5` so it never fires during the R1–4 seal window. On rounds where decon has funneled the team to a single lower+upper spoke (`is_zone_sealed`), soften that round (longer safe window / weaker tax). **Listen only** to the decon notifies — never rename/suppress `acc_decontamination_complete`. (The perk re-roll itself fires off `acc_round_start`, not decon — `_acc_perk_doors.gsc:182` — but decon still consumes that notify.) |
| **Speed curve + AI-cap-24 congestion** | **A:** adds no bodies — peak-alive stays 24, no second speed writer. **B:** adds an AI body — must stay within the cap and **avoid the documented worst-stack** (tight Corp + sprint modifier + 4p). Any optional hot-wave surge stays **default OFF**. |
| **Corp cut-vertex** | Respected absolutely: **no seal, no spawn-kill, all four mouths always open and live.** `is_eligible_zone` already hard-refuses Corp — we never touch that path. Both designs are escapable pressure, structurally incapable of disconnecting Plaza↔Lab. |
| **Modifiers (opt-in first?)** | **Ship opt-in.** Add to `_acc_modifiers.gsc`'s `all[]` → `level.acc_mod_*`; gate every effect on `IS_TRUE(...)`. Harder-modifier score-multiplier interaction already specced ([07](06_replayability.md)). Promote to default only after the worst-stack playtest. |
| **Randomizer** | Optional per-run variant (safe-window length, or which mouth telegraphs first) rolled in `_acc_map_randomizer::pre_init` via `acc_utility::acc_rand_int` (seeded PRNG). Not required for v1. |
| **Corp interior** | If the Corp interior is ever shrunk, plan it **together** with the middle hazard's volume/mouth anchors — anchor the mouth tests to placed structs, not literal coords, so a shrink can't desync the hazard. |
| **Dev safety** | `level.acc_disable_core` mirrors `level.acc_disable_decon` so the force-open dev map (`acc_open_doors`) stays roamable during the build. |

---

## 8. Build feasibility & risks

**Reality check:** both directions are **recombinations of proven, in-repo code, not new tech.** Every
cited scaffold was verified to exist: the decon volume/damage engine, the Glitch mini-boss, the Overload
DistanceSquared point test, the atmosphere emitter, the modifiers `all[]` opt-in, the working
clientfield bridge. Zero new aitype, zero custom model/anim, fresh-clone-safe.

**Engine guardrails respected by construction:** thread from `init()` polling
`flag::exists("initial_blackscreen_passed")` (never `flag::wait_till` from a `REGISTER_SYSTEM __init__`
— the documented init crash); honor the `.csc`/`.gsc` split via clientfield; never seal Corp; preserve
the decon→perk-rotation contract. **A** additionally avoids `SetScale`, the spawn→move CTD, and the
speed-writer fight by having no AI; **B** inherits those and mitigates via the Glitch scaffold + deferred buffs.

**Biggest unknowns (ordered):**
1. **The bottom-pull is the real new work, not "reuse."** The Overclock terminal is per-weapon and
   auto-advances tier with no credit/voucher concept — a `player.acc_core_tier_credits` int + a new
   redemption branch is **genuinely new economy plumbing** that must compose with per-weapon tier state
   without desync. *Budget it as the primary build.*
2. **Reward magnitude vs. decay** (§2). If the credit's value evaporates as Shards inflate, the toll
   lapses → camp-Lab returns. **Must be confirmed at the first 4-player playtest.**
3. **(A) Graduated DoT ≠ a verified kill idiom.** Decon always overkills (`health+666`); a tunable
   sub-lethal repeating DoT must interact correctly with Jug/armor, the laststand threshold, and revive
   timing across 0.5s ticks — and must **yield to decon's authoritative kill** in any boundary frame
   (explicit guard so a player isn't double-downed).
4. **(A) Mouth spheres have no LOS trace.** Pure DistanceSquared at a 256u mouth applies exposure
   *through* the corridor side-walls — phantom "invisible damage" (banned). **Tune radii tight or add
   LOS bullettraces before ship.**
5. **(A) The `.csc` haze is the entire "place is alive" read** — treat the clientfield meter + edge
   vignette as **v1 scope, not v2**, or the greybox relies on text+sound only ("arbitrary damage" complaints).
6. **(B) Kite-abuse + worst-stack.** A leashed-but-attacking boss that holds Corp without chasing to a
   pole is the design's load-bearing AI behavior — prototype the leash early; budget the body against the cap.
7. **Early-game double-jeopardy.** Hazard + a fresh decon seal + the climbing speed curve in early
   rounds is the danger window. The suspend-during-evac + single-spoke-softening gates are sound in
   principle but **unwritten state logic** — prove against the worst legitimate stack at the first 4p playtest.

---

## 9. Rejected / parked concepts

- **The Night Warden** (patroller, avg 6.3) — *parked.* Its bottom-pull is **dodgeable, so it isn't
  structural**: a player who blitzes fast (the intended counterplay) is never branded and never
  descends — reproducing camp-Lab-forever. Marquee punishment (`acc_cw_locked_until`) is **dead code
  with no consumer**; purge station is the unbuilt Cyberware kiosk.
- **The Grid — Signal Denial Field** (perk/HUD strip, avg 5.3) — *rejected.* Central "per-player perk
  strip" **has no implementation path** — the only API is **team-global** `perk_pause_all_perks()`, so
  one camper strips a safe teammate's perks (a co-op grief tool). Cyberware lockout is the same dead
  `acc_cw_locked_until`; fear-read depends on unproven, fragile LUI (minimap suppression, full-screen
  post-process) on the project's most failure-prone surface.
- **The Conductor / Warden of the Pinch** (lane-holding sentinel, avg 5.3) — *rejected.* Core primitive
  — a **"leashed-but-attacking" Sentinel that holds a mouth without chasing** — is **unproven** (every
  in-repo `SetGoal` either fully pins, i.e. walk-around-able, or chases, i.e. abandons the lane). Adds
  `ignore_enemy_count` bodies *past* the 24 cap into the 256u escape mouths — **double-counts into the
  explicitly-deferred worst-stack** the overhaul says to resolve *before* adding middle pressure.

---

## 10. Open decisions (ordered by how much each gates the design)

1. **[DEFERRED — "let me think on it"] Bottom-pull reward** — held-weapon free Overclock tier (buildable
   now, risks decaying late) **OR** a perk-rotation re-roll token (never stale; the 4-of-10 rotation it
   re-rolls now ships in `_acc_perk_doors.gsc`, so only the player-triggered re-roll is left to build)?
   *Sizes the largest build risk and whether the toll holds late-game.*
2. **[DEFERRED — "flesh out both, then decide"] Entity or environment** — Contaminated Core
   (faceless-but-bulletproof, can't be kited, no AI crash classes) **OR** Toll Daemon (a named face to
   fear, highest feasibility, larger balance surface)? *This doc is the input to that decision.*
3. **Console cadence** — fixed every ~3 rounds, kill-charged "battery," or both (cadence floor + kill
   accelerant)? *How often the team is forced to descend.*
4. **Co-op semantics of the console** — one player banks for the team (a courier "settle 3 of 4 at the
   pole" pattern), or per-player (everyone must descend — max fear, max chore risk)?
5. **Saturation/tax horde surge** — default OFF (respect the worst-stack budget, recommended) or a small
   ON bite?
6. **`.csc` visual fidelity** — full clientfield haze/visionset (richer read, maybe a BSP-baked lighting
   pass) or a lighter edge-vignette + 3D emitter (ships faster, stays headless)?
7. **Ship gating** — opt-in modifier first (recommended; ride to Workshop behind one flag for tuning) or
   straight to default-on once it compiles?

---

## 11. What actually shipped — the room lockdown → Glitch-Purge trap

This is the one piece of the study that got built. It started as a cosmetic **per-round red-alarm room
lockdown** (`_acc_lockdown.gsc`) — the telegraph / "place is alive" read both directions leaned on —
and grew into a **full trap challenge**: walk into the lit room and it seals, spawns a confined wave of
Glitch Stalkers, and drops a free boss item when you clear it. The trap layer lives in
**`_acc_lockdown_challenge.gsc`** with its full design in **[26_lockdown_challenge_room.md](26_lockdown_challenge_room.md)**;
this section covers only the **lighting/rotation half** (`_acc_lockdown.gsc`).

> **Currently HARDCODE-DISABLED.** Both the lights and the purge are wired into `acc_main::init()`
> (`_acc_main.gsc:181`, `:223`) but return early unless `+set acc_lockdown_challenge_on 1` — the
> lights are the purge's telegraph, so with the purge off the room-light rotation is killed too
> ("those are tied together", user 2026-07-04; `_acc_lockdown.gsc:91`). `acc_lockdown_on` itself
> defaults **1**; the master gate is `acc_lockdown_challenge_on` (default **0**).

**How the lit room is chosen (current behavior, `_acc_lockdown.gsc`).** It is **no longer a per-round
rotation.** One eligible room lights up with a steady **magenta** "DEFCON" glow and **stays lit until
the challenge inside it is defeated** (user 2026-06-18); on defeat the alarm turns off and the next
DEFCON lights `acc_lockdown_cooldown` (default **4**) rounds later, round-robin through a per-run
shuffled order (`roll_order` / `pick_zone`). The first one is gated at `acc_lockdown_first_round`
(default **7**). Armed from `acc_main::init()` next to `acc_decontamination::init()`, listening on the
same `acc_round_start` fan-out as decon.

**Why FX, not fog/tint (the core constraint).** `SetVolFog` and `.vision` are **whole-map globals** —
they cannot be confined to one room. And server-side `PlayFX`/`PlayFXOnTag` does **not render** in this
build (the same wall the 2026-06-17 perk-glow attempt hit). So the alarm rides the proven
**client-side glow pipeline**: `_acc_lockdown` spawns invisible `tag_origin` `script_model` hosts at the
room's anchor points and glows them via `acc_perk_lights::set_glow(host, color)` → the `accPerkGlow`
clientfield → `_acc_perk_lights.csc` PlayFX of the packed `acc/light/fx_perk_glow_magenta.efx` clone
(steady — the clone loops, no server pulse loop). This is **pure GSC/CSC, LED-safe, linker-only** (no
`cod2map64`/LED, no `.map` edit). Emitter anchors = the room's own `<zone>_spawners` structs (room
CENTER/centroid first, then perimeter up to the cap), so placement is data-driven with no hardcoded
coords.

> **Glow colour = MAGENTA, index 11** (`ACC_LOCKDOWN_GLOW_INDEX = 11`, `_acc_lockdown.gsc:50`). It was
> **red (index 1)** through 2026-06-24, then changed to magenta so the "purge" lights match the Glitch
> Stalker's own magenta glow (user 2026-06-24). `acc_lockdown_color` overrides it live (1 red … 12
> dim-white; palette in `_acc_perk_lights.csc`).

**Eligible rooms (`get_lockdown_zones`):** the **four** requested — Vault / Alley / Helipad
(`roof_zone`) / Market. **Not** start (spawns), Corp (the cut-vertex hub, 4 doorways), or Lab. Each has
≥5 `<zone>_spawners` anchor structs (verified in the `.map`) for emitter placement.

**Live dvars (`_acc_lockdown.gsc`):**

| Dvar | Default | Effect |
|---|---|---|
| `acc_lockdown_challenge_on` | `0` | **Master hardcode gate for the whole feature** (lights + purge). `1` = enable. |
| `acc_lockdown_on` | `1` | Secondary live switch; `0` clears any active lockdown and idles. |
| `acc_lockdown_color` | `11` | Glow colour index (11 = magenta; 1 red … 12 dim-white). |
| `acc_lockdown_fx_z` | `180` | Emitter height above each spawner anchor. |
| `acc_lockdown_emitters` | `6` | Max emitters per room. |
| `acc_lockdown_first_round` | `7` | DEFCON stays off before this round. |
| `acc_lockdown_cooldown` | `4` | Rounds after a DEFCON is *defeated* before the next lights. |
| `acc_lockdown_fail_cooldown` | `1` | Rounds after a *failed* challenge before the next lights (≥1 breather). |
| `acc_lockdown_force_zone` | `""` | TEST pin: a zone name (e.g. `vault_zone`) locks the lockdown to ONE room, bypassing rotation. |
| `acc_lockdown_lock_doors` | `1` | Door seal (see below). `0` = light only. |
| `acc_lockdown_debug` | `0` | On-screen `[lockdown]` rotation trace. `1` = show (decoupled from `level.acc_dev` 2026-07-10, `_acc_lockdown.gsc:252` — clean screen in dev; the `[acc]` dev log still fires either way). |

### Door locking — stock buyable-door reuse, NOT seal brushes

The lock-in half is handled by **`_acc_lockdown_challenge`** re-closing the room's **two stock buyable
border doors** via the stock crush-safe close (`door_activate open=false`) — see
[26_lockdown_challenge_room.md](26_lockdown_challenge_room.md). This **sidesteps Radiant/LED-bake risk
entirely.** The `acc_seal_<zone>` `script_brushmodel` scaffolding in `_acc_lockdown.gsc`
(`init_seals`/`lock_doors`/`unlock_doors`, gated by `acc_lockdown_lock_doors`) remains as a **harmless
no-op** — **no such brushes were ever authored.** `tools/add_lockdown_seals.js` and
`tools/add_vault_ceiling.js` exist but their output was part of the pre-stage3 geometry that was
**reverted**; do not resurrect that path.

> **The old "LED is a dead end for this geometry" conclusion is SUPERSEDED.** As of the pre-stage3
> revert the map **BAKES AGAIN** and `tools/build_map.ps1` runs the LED bake by **default** —
> `-SkipLED` is now a **RED FLAG**, not the recommended build (see CLAUDE.md). The vault-ceiling /
> seal-brush geometry that crashed `brush.cpp:1860` is gone with the revert, and the lockdown's
> render is now a **linker-only** client-FX path that never touches the lightmapper. There is no
> longer a "baked-dark ceiling is off the table" problem here.

> **Decision recorded (owner, 2026-06-15): LOCK PLAYERS IN — no escape window.** Unlike decon's timed
> evac, a lockdown seals immediately; players caught inside fight the trap out. This is the intended
> punishing/"fear" beat, now realized as the Glitch Purge ([43](26_lockdown_challenge_room.md)).

### Pointers if either unbuilt direction is ever revisited
- Decon engine to clone/extend: `scripts/zm/zm_abandoned_cyber_city/_acc_decontamination.gsc`
  (volume occupancy `get_zone_volumes`/`player_in_zone_volumes`; laststand-routed `DoDamage`; warn→countdown→effect phase).
- Entity scaffold (Direction B): `scripts/zm/zm_abandoned_cyber_city/_acc_boss_glitch.gsc` (promoted stock-zombie reskin, self-contained cadence/spawn/reward).
- Point drain idiom: `zm_score::minus_to_player_score` (used by the EMP elite in `_acc_elites.gsc`).
- Distance-check idiom: `_acc_events_overload.gsc` `is_player_on_point` (96u / hold) — note the Vault Overload event itself was **RETIRED** (2026-07-07, commented out in `_acc_main.gsc:199`), but the file/helper still exist to copy from.
- Opt-in modifier registration: `_acc_modifiers.gsc` `all[]` array → `level.acc_mod_*`.
- Per-run roll (optional): `_acc_map_randomizer::pre_init` + `acc_utility::acc_rand_int`.
- Atmosphere/telegraph hooks: `_acc_atmosphere.gsc` (3D emitter, dvar-tunable fog).
- Live flags/dvars convention: `docs/22_flags_reference.md`.
- The shipped trap this study led to: `_acc_lockdown_challenge.gsc` + `docs/26_lockdown_challenge_room.md`.
