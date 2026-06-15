# 26 — Requirements Compliance Audit (2026-06-13)

> Produced by a 7-domain adversarial audit (perks, currency/Cyberware/Overclocks,
> weapons/PaP, enemies/boss, map/zones/randomization, mechanics/events, HUD/UI)
> comparing **REQUIREMENTS.md + docs/** against the **actual current code**
> (not the stale docs/20 checklist). This is the implementation backlog.

## Headline

**~45–50% complete.** The skeleton is real and largely doc-faithful — structure,
costs, economies, state machines, reward plumbing are correct — but **roughly
half the gameplay EFFECTS are dead flags, flag-only stubs, or keyed on mismatched
identifiers**, and almost every world interaction is currently unreachable because
the Radiant entities are placed in a **start-room staging cluster** while the dev
sandbox force-opens the map + disables decon. `docs/20_requirements_checklist.md`
is **badly stale** (understates map progress; e.g. :405 claims zero `acc_*`
entities, but 18+ distinct `acc_*` targetnames exist).

## Critical violations (code contradicting the spec)

1. **[FIXED 2026-06-13] Perk specialty-string mismatch** — `_acc_map_randomizer.gsc`
   listed `specialty_acc_deadshot/widows_wine/electriccherry` in the rotation roster,
   but every machine/HasPerk/Mega-flag/cost/damage-hook keys on the stock
   `specialty_deadshot/widowswine/electriccherry`. Rolling a custom perk matched
   nothing → purchase/dispense structurally broken for 3 of 9 perks. **Fixed** to
   the registered strings (verified `specialty_acc_` has zero other references).
2. **Dead shard diminishing-returns** — `_acc_data_shards.gsc:101` only diminishes
   when `source_tag=="elite_kill"`, but elite shards always flow via
   `grant_player(...,"pickup")` (`_acc_elites.gsc:345`). The docs/06 low-round 50%
   cap **and** the per-round counter reset are dead code. *Fix:* apply the
   diminish at elite-death time, or thread the killer + `elite_kill` tag through.
3. **Dead EMP-elite Cyberware lockout** — `_acc_elites.gsc:323` writes
   `self.acc_cw_locked_until` (on the **elite**), but no consumer reads it; and
   `try_activate_ability`/`phase_step_watcher` are on the **player**. The EMP
   elite's signature ability does nothing (only the 200pt drain lands). *Fix:*
   store the lockout on the player + guard the ability/phase-step consumers.
4. **Overclock terminal classifier name-domain mismatch** — `_acc_overclocks.gsc:300-318`
   classifies weapons by `_zm`-suffixed names, but runtime weapons carry stock
   **class** names (`ar_accurate`, `shotgun_fullauto`). The OC terminal likely
   rejects every weapon. *Fix:* reconcile to the class-name domain.
5. **Sprint modifier inverted** — ~~`is_active("sprint")` only set
   `acc_mod_force_sprint=true`, whose sole consumer (early-round pacing) skipped the
   boost; nothing applied actual sprint.~~ **RESOLVED 2026-06-14:** the new
   `_acc_zombie_speed.gsc` curve consumes `acc_mod_force_sprint` — when set, it clamps
   every round's speed target to ≥100% (base-game max) and forces the sprint run cycle.
   (The Rampage Inducer was removed in the same change.)
6. **Weapon tier progress keyed by live weapon object** — `_acc_overclocks.gsc:177,192`
   key `acc_weapon_progress` by `getcurrentweapon()` with no base-weapon fallback,
   so PaP wipes/dupes tier state (shard re-tier exploit / silent loss). *Fix:*
   key by `get_base_weapon`.
7. **Dev sandbox + test-boss hardcoded ON** — entry `main()` force-opens doors,
   force-sets `power_on`, sets `acc_disable_decon`; `_acc_boss` spawns a host
   every round from r2. *Intentional for the current test pass*, but **must be
   dvar-gated before any real build** (they mask the door/power/decon/randomization
   domain at runtime).
8. **Stale docs** — docs/20:405 (zero `acc_*` entities — false); docs/14:33-34
   (documents `bind h notify acc_ability` but code uses ADS+melee / crouch+melee
   chords); docs/14:90 (claims a clientfield bridge for shard/bottle counters that
   doesn't exist — they're plain server hudelems).

## Prioritized backlog (build next, in order)

1. **Perk strings** ✅ done (#1 above).
2. **Make the differentiator EFFECTS real** — the map's identity is Cyberware/
   Overclocks/per-perk retunes, and most are flag-only stubs: wire dead Cyberware
   node payoffs (rx3 Overdrive sprint-mult in `_acc_damage:252`, oc2b Fission PaP
   elemental slot), the EMP lockout (#3), the shard diminish (#2), the OC
   classifier (#4), the inverted Sprint modifier (#5).
3. **Gate the dev sandbox** behind `acc_dev`/`acc_test_boss` dvars (default ON via
   `run_game.ps1`) so the door/power/decon/randomization domain becomes testable
   *and* the build is ship-safe (#7).
4. **Build the in-zone final layout** — place `acc_lab_perk_a/b/c/d` in the Lab;
   distribute wallbuys/perks/PaP/boxes from the start-room cluster (y≈4195) into
   their docs/03 zones; fix the power-switch side tag (the `script_string corp/
   vault` sits on the prefab wrapper and doesn't reach the inner `use_elec_switch`
   trigger, so power-side randomization leaves both switches live).
5. **Author the weapon content layer** — generate the weapon CSV (the box/OC
   systems already reference it); reconcile the box pool (~5 referenced assets
   don't exist → effective box ≈3 guns); implement the 5-level money-track PaP.
6. **Wire or de-scope the dead modifier system** — `code_red` (elite_rate/hp
   mults), `limited_liability` (no_jug), `one_shot` (one_overclock_slot) are
   set-but-never-read; `draft_mode`/`shardless`/`roguelike_lite` are log-only.
7. **Update the stale docs** (#8) so the spec tracks reality.

## Biggest stubs (exist but mostly TODO)

Cyberware node effects, Overclock weapon effects, the modifier suite, the full
boss scripted abilities (Subroutine Core attacks), and the LUI/`.csc` HUD layer
(all greybox `iprintln` stand-ins today). These + the in-zone layout (#4) are the
remaining bulk of the work.

## Method note

Re-verify any single finding against the live code before acting — the audit is
high-confidence but a few fixes name the wrong entity (e.g. #3's lock field). The
docs/20 checklist should be re-baselined against this audit (it is the stale one).
