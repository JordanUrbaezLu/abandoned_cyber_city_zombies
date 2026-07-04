# 11 - Enemies

The bestiary: regular zombies, three elite classes, mini-boss, and full boss. Design principles for difficulty and how enemies tie back into the Data Shard and Cyberware loops.

Weapons are in a separate doc: [05_weapons.md](05_weapons.md).

## Design Rules (hard, non-negotiable)

1. **Every enemy has a clear read.** A visual + audio cue distinct enough that a competent player can prioritize in a 1-second glance.
2. **No bullet-sponge elites.** HP is chosen so a PaP'd weapon kills an elite in 1-2 seconds at any round. Difficulty comes from *movement, flanking, utility*, not raw HP.
3. **Movement solves most problems.** Any 1v1, including elites, should be outrun by an unupgraded player. Elite *density* is the threat, not individual stats.
4. **Boss rooms are the only forced-camp encounter.** Everywhere else rewards movement.
5. **Data Shards are on the body.** Elites drop shards at their feet (not auto-granted). Skilled players get them; panicking players don't.

## Cast

### Regular Zombie

- **Behavior**: stock BO3 chaff. HP scales per round.
- **Data Shard drop**: none.
- **Value in the loop**: drives Point economy, keeps pressure up, triggers AoE Overclocks and Cyberware capstones.
- **HP scaling delta vs stock**: +1 effective round (start at 150 HP instead of 130, same per-round ramp). See [04_progression_and_skills.md](04_progression_and_skills.md).
- **Speed curve** (`_acc_zombie_speed.gsc` — replaced the old Rampage Inducer): zombies get faster **every round**, with a **natural gait** (never slow-motion). The BO3 engine has no continuous "move at X% speed" knob for zombies — movement is root-motion / animation-driven, so the only levers are the discrete gait **tier** (walk/run/sprint, each a real animation whose baked gait *is* its ground speed) and the animation **playback rate** (which scales cadence *and* ground speed together, so a rate below 1.0 looks like literal slow-motion — it is the Widow's Wine slow mechanism). So "slower than max" comes from a slower **gait**, not a slowed animation:
  - **Rounds 1–14:** the **run** gait (a natural jog) at playback rate ≥ 1.0, creeping up `acc_zspeed_jog_step_pct` (0.5%) per round. The jog's intrinsic speed is the "slow start" (~70–80% of max — baked into the xanim, so it's approximate, not a dialled percentage). (user 2026-06-23: jog phase extended for a gentler early-round ramp; step cut to 0.5% so the jog never outpaces the real sprint.)
  - **Round 15** (`acc_zspeed_sprint_round`, was 10): zombies break into the full **sprint** gait at rate 1.0 = base-game max — a deliberate, natural escalation. sprint@1.0 clears the topped-out jog, so the wave still steps **up** (strictly monotonic).
  - **Round > 15:** sprint gait, rate `1.0 + 0.6%·(round−15)` (`acc_zspeed_sprint_step_pct`, cut from 1% — user 2026-06-24, gentler post-sprint creep) — a faster sprint (rate > 1.0 reads fine, no slow-mo). No upper clamp (R20 ≈ 1.03, R25 ≈ 1.06).
  The playback rate is **floored at 1.0** in code, so the wave never animates below natural cadence. The "sprint" run modifier (`acc_mod_force_sprint`) forces the sprint gait on every round. Tunable live via the `acc_zspeed_*` dvars — see [34_flags_reference.md](34_flags_reference.md).
  - *Footgun — two abandoned attempts, kept as warnings:* (1) a walk→run→sprint-**by-round** variant with `rate = target% ÷ category_base%` dipped at each tier up-shift (the per-tier baked speeds are unknowable from data) → read as "slowing down per round." (2) A **sprint-locked** variant scaling `ASMSetAnimationRate` to an exact target % *below 1.0* produced the correct ground speed but a **slow-motion** sprint gait → "slomo running." Deep research (2026-06-15) confirmed there is **no script lever** for continuous speed at natural cadence (`SetMoveSpeedScale` is player-only; `moveplaybackrate` / `animtranslationScale` are dead/death-only). The natural-gait model above is the resolution: exact percentages are traded away for a correct-looking, monotonic ramp.

### Elite: Shielded ("Riot") — the ONLY elite (Teleporter + EMP removed, user 2026-06-22)

- **Spawn (user 2026-06-22)**: a **"shield round" every 4 rounds from round 4** (r4, r8, r12, …); the **count that round = the round number ÷ 2** (r4 → 2 shields, r8 → 4, r12 → 6, r20 → 10 …), spread ~3 s apart across the round (`acc_shielded_spacing`). Other rounds spawn zero elites. High-round caveat: the ~24-AI cap throttles how many are concurrently alive.
- **Depth-scaled ratio (user 2026-06-25)**: ADDITIONALLY, in the **abyss** a depth-based share of *every* zombie spawns Shielded — **deeper = more**: **L2 10% · L3 15% · L4 22% · L5 30%** (surface + L1 pit = 0; the shield rounds above still cover those). Per-zombie roll on `zombie_init_done` (chained after coop_scaling so HP is already scaled), keyed by `acc_bus_trench::underground_layer(origin)`. Live dvars `acc_shielded_pct_l2..l5`. `promote_to_shielded` has a re-entrancy guard so a shield-round + depth-roll can't double-promote. `_acc_elites::acc_depth_shielded_roll` / `depth_shielded_pct`.
- **HP**: **4× a normal zombie's current health, at ANY player count** (user 2026-07-04: 5× → 4×, "5× is too much"). A **flat ×4** — it tracks the normal zombie's co-op scaling, NOT a separate elite curve. (Do **not** stack `special_hp_mult()` on top: by promote time the base HP already carries the regular +100%/player co-op mult, so multiplying the elite curve double-counts co-op — that earlier made a 2-player Shielded read ~4.5× a 2p zombie instead of a clean multiple.)
- **Movement**: a heavy **WALK** — roughly half the pace of the round's normal (jogging) zombies, a lumbering armoured brute. Uses the natural `walk` run cycle at full cadence, **not** the run gait at 0.5× rate (that read as slow-motion — `<1.0` anim rate is always slow-mo; user 2026-06-22 "why does it move so slow"). `_acc_elites::shielded_speed_think`; tune via `acc_shielded_walk_rate` (**default 1.2** = a bit faster than the natural walk, user 2026-06-24; 1.0 = natural, raise for faster); `acc_boss_custom_speed` opt-out; NO `SetScale`. Trade-off: it's the walk's natural pace, not a math-exact 50% — at high sprint rounds it reads slower-than-half; bump the rate if needed.
- **Behavior**: front-facing armor. Damage to the front quarter (90° arc) = 25% through — *unless* your gun's Overclock pierces it (below). Flank or break the shield with sustained fire.
- **Read**: rocket-shield world model bolted on its back (front-armoured silhouette).
- **Counter-play**: flanking (Reflex builds excel), grenades / explosives (always bypass), melee from the side, and the **Overclock Shield-Pierce** effect (4/4) — a gun's OC tier *partially* punches through the front armor: each tier restores a bit of the blocked damage, taking the front from **25% (T0) up to 62.5% at Tier 10** (`acc_oc_pierce_per_tier`, default 0.05/tier; `_acc_damage.gsc` effect 4/4). It's a **partial** pierce, never a full bypass, so flanking / explosives / side-melee always help. It's slow — kite it.
- **GSC**: `_acc_elites::promote_to_shielded()`.

### Elite: Teleporter ("Blink") — REMOVED (user 2026-06-22)

> No longer spawns. `pick_elite_class_for_round` returns only `"shielded"`; `promote_to_teleporter` + `teleporter_ability_loop` remain defined but unreachable (kept for trivial restore). The Glitch Stalker still carries the blink/flank fantasy this elite originated.

### Elite: EMP ("Surge") — REMOVED (user 2026-06-22)

> No longer spawns. `promote_to_emp` + the on-hit point-drain / Cyberware-lockout debuff (`apply_emp_melee_debuff`, the `acc_emp_on_hit` branch in `on_player_damaged`) remain defined but unreachable — `acc_emp_on_hit` is never set, so the debuff never fires. (The trench-melee + Exo-resist logic in `on_player_damaged` is untouched.)

### Mini-Boss: Brutus — the "Trench Warden"

> **Implemented as Brutus** (NSZ pack), not the old "Juggernaut Host" placeholder below. **Spawn cadence (user 2026-06-18): FIRST appears when the Bus Station POWER is turned on** (`_acc_boss::brutus_power_watch` — was a fixed round 4), then **every 5 rounds** from that anchor. Runs alongside the wave (`ignore_enemy_count`), drops a boss item + Mega Bottle. **HP (user 2026-07-04): the TOP tier of the UNIFIED boss scale.** All three bosses now share the **same base (56k) + anchor (round 10)**, differing ONLY by per-round exponent: **Brutus 1.12 > Rogue Protector 1.1 > Phantom 1.08**. So Brutus = **56k × 1.12^(round−10)**, **NO cap** (`acc_boss_mini_hp` / `acc_boss_mini_hp_exp` / `acc_boss_mini_hp_anchor`), e.g. solo **r10 56k → r20 174k → r30 541k → r40 1.68M**. (He debuts at power-on & round ≥ 5; rounds 5–9 sit at the flat 56k base, then compound from r10.) Brutus stays the tankiest via the highest exponent. (The NSZ pack's old linear `3500×round` / 85k-cap HP is dead — overwritten every spawn.) That round-scaled base is then × a **logarithmic co-op multiplier** (`boss_hp_player_mult`: ×1 / 1.5 / 1.79 / 2.0 for 1–4 players). PLANNED: tether it to **roam the Bus Station (corp_zone) trench** as a true "warden." The stale "Juggernaut Host / rounds 10,20 / 500k HP" details below are superseded.

- **Spawn (stale)**: replaces the normal round wave. Round 10 = 1 mini-boss. Round 20 = 2 mini-bosses simultaneously.
- **HP**: 500,000 base (10× the prior 50k baseline), scaling +50% per extra player.
- **Behavior**: charges across the map at **+25% over the current round's top speed** (locked to the sprint tier × 1.25, so it outruns even a maxed-out wave). Immune to stun from normal damage.
- **Data Shard drop**: 2 (round 10) / 3 (round 20).
- **Round pickup**: usually drops a max-ammo or insta-kill powerup alongside the shards.
- **Item drop**: **50% chance** to drop a random boss item (see [12_boss_items.md](12_boss_items.md)). If the player already has that item, it auto-converts to 3 Data Shards.
- **Mega Bottle drop**: **50% chance** (user 2026-06-25, was guaranteed) — when it hits, **1 Empty Mega Bottle to every player** on kill (rolled separately from the item + shard drops, which stay 100%; tunable via `acc_brutus_bottle_chance`, default 0.5). Use at Lab perk machines to upgrade owned perks to their Mega variant. See [13_perks.md](13_perks.md#mega-bottles-system).
- **Read**: oversized cyber-zombie silhouette, pre-charge wind-up animation, distinctive ground-rumble audio.
- **Hard counter - Vibro Cleaver (wonder melee)**:
  - +300% damage vs Juggernaut Host on any hit.
  - Heavy-attack parry timed on a charge wind-up knocks the Host on its back + 3s stagger + massive damage.
  - Acquired via Hack Terminal completion + 5 Data Shards. See [05_weapons.md](05_weapons.md#vibro-cleaver-wonder-melee).
- **Other vulnerabilities**: elemental Overclocks (via Fission sub-node), EMP Grenade stun (brief). These are real but less effective than the Cleaver.

### Mini-Boss: "Glitch Stalker" (round 4+, every 2nd round)

- **Spawn (user 2026-06-23, difficulty cut)**: from **round 4, every 2nd round** (`ACC_GLITCH_FIRST_ROUND_DEF 4`, `ACC_GLITCH_INTERVAL_DEF 2` → r4, 6, 8, 10, …; was every round from r2), **alongside** the normal wave (does not replace it, does not gate round end — `ignore_enemy_count`). The **per-wave count steps up by 1 each spawn round**: `floor((round-2)/2)` (`glitch_count_for_round`, user 2026-06-23 dropped the +1 so it starts at 1; the old fixed `acc_glitch_count` is superseded) — so r4 = 1, r6 = 2, r8 = 3, r10 = 4, ….
- **Source**: script-only — a promoted stock zombie (the `spawn_subroutine_core` scaffold), re-skinned at runtime to the **stock Giant zombie body + head** (SetModel + head Detach/Attach; both stock xmodels, no external pack). The map's first *mobile* boss (the Juggernaut Host charges; the Subroutine Core is pinned).
- **HP**: **1.5× the round's normal zombie health** (`acc_glitch_hp_mult`, default 1.5; user 2026-06-23, was 3×) — auto-scales with the round, no separate curve.
- **Behavior**: chases at **~15% faster** than the round's normal zombies (`acc_glitch_speed_mult`) and every **1–1.67s teleport-blinks** to flank the nearest player (navmesh-clamped, reusing the Teleporter elite's verified path; blink cadence doubled 2026-06-15 — blinks 2× more often). For ~1.5s right after each blink it is **vulnerable** and takes **2× damage** — the fight rewards punishing the recovery window, not out-DPS-ing a sponge.
- **Melee damage**: deals **−55%** melee damage to players vs a stock zombie (`acc_glitch_melee_dmg_mult` **0.45**, user 2026-06-22 — 25% lower than the prior 0.6) — a fast, frequent-blinking harasser, not a heavy hitter.
- **Read**: it wears the **stock ("Giant") zombie skin** (body + head, `acc_glitch_stock_skin`) so it stands out from the charred horde, plus **teal eyes** (`acc_glitch_teal_eyes`, user 2026-06-17 — a client eyeball-material recolour, **no FX asset**; colour/luminance live-tunable via `acc_glitch_eye_color` / `acc_glitch_eye_lum`) — **no health bar, no over-head marker**; the skin + eyes are the only tells. After each blink it now **vanishes, physically charges toward the nearest player while hidden** (navmesh-clamped, `acc_glitch_charge_speed`), and only rematerialises once the AI has resumed moving (`Ghost`/`Show`, render-only, stays hittable, capped by `acc_glitch_phasein_max`, `acc_glitch_fx`) — so it reappears already on top of you, never frozen in the open mid-blink (exaggerated anti-standstill fix, user 2026-06-17). (A 75% size was considered but dropped — `SetScale` on a live zombie AI is the confirmed `0xC0000005` crasher; would need a pre-scaled model.)
- **Data Shard / Item / Mega Bottle drop**: "mini" reward tier — 50% chance of a random boss item + **1 Empty Mega Bottle guaranteed to every player** on kill (same as the Juggernaut Host).
- **Counter-play**: don't chase it — hold an angle and burst it during the post-blink window.
- **GSC**: `_acc_boss_glitch.gsc` (self-contained: own cadence, spawn, blink, death/reward). Fully dvar-tunable — see [34_flags_reference.md](34_flags_reference.md#glitch-stalker-mini-boss-tuning). Toggle with `acc_glitch_enable`; trace with `acc_glitch_debug 1`.

### Full Boss: "Subroutine Core" — REMOVED (user 2026-06-22)

> **No longer spawns.** The r≥30 `run_full_boss` trigger was deleted from `_acc_boss::round_hook_loop`; `run_full_boss` + `spawn_subroutine_core` remain defined but unreachable (kept for trivial restore). With the Core gone, Brutus is now also eligible on r30/40/50 and the Glitch Stalker spawns those rounds too. The design below is retained for reference / a future re-enable.

- **Venue**: Lab only. Lab exits seal for the duration of the fight.
- **Phases**: 3 phases (round 30) or 4 phases (round 40+). Transitions at 66%, 33%, and 15% HP.
- **Phase effects**:
  - Phase 2 (at 66% HP): **Power disables for 60s** across the map. Perks you've already bought stay active; perk machines become inert for refills.
  - Phase 3 (at 33% HP): **Perks disabled for 60s**. Your active perk effects pause. Jug-less rounds of truth.
  - Phase 4 (at 15% HP, round 40+ only): spawns an EMP elite add to apply movement pressure inside the seal.
- **Adds**: constant chaff spawn during the fight plus one elite per minute.
- **Data Shard drop**: 4 (each player independently).
- **Bonus reward**: guaranteed Overclock re-roll voucher (consumed for a free re-roll, banks until used).
- **Item drop**: **100% guaranteed** random boss item on every kill (see [12_boss_items.md](12_boss_items.md)). Duplicates auto-convert to 3 Data Shards.
- **Mega Bottle drop**: **1 Empty Mega Bottle guaranteed** to every player on kill (same as mini-boss). See [13_perks.md](13_perks.md#mega-bottles-system).
- **HP scaling**: 50,000 base at round 30, +15,000 per round past 30.
- **GSC**: `_acc_boss::run_full_boss()`.
- **Hard counter - Signal Staff (ranged wonder weapon)**:
  - +300% damage vs Subroutine Core on any hit.
  - A charged pulse fired at the exact moment of a phase transition can *skip* the phase's debuff window (power-disable or perk-disable). Rewards timing knowledge.
  - Acquired via Vault Overload completion + 5 Data Shards. See [05_weapons.md](05_weapons.md#signal-staff-ranged-wonder-weapon).
- **Why this pairing**: the Core is itself a corporate-AI signal network; the staff is engineered to disrupt that exact network. Fiction and mechanics align.

## Elite Spawn Timing (pacing, not randomness)

Stock BO3 leaves elite timing to spawn RNG. We don't. See [06_mechanics.md](06_mechanics.md) for the full model; summary:

- **Shielded** is now the only elite. Its whole quota arrives on the **"shield round"** (every 4th round from r4), spread ~3 s apart across that round so the batch is a sustained pressure event rather than a single spike.

This makes round *texture* predictable but round *moment* tense.

## Elite Quota Per Round (user 2026-06-22)

Shielded-only "shield rounds". Every other round = 0 elites.

| Round | Shielded count |
|---|---|
| r4 | 2 |
| r8 | 4 |
| r12 | 6 |
| r16 | 8 |
| r4k (every 4th) | = the round number ÷ 2 |

Source: `_acc_elites.gsc::elite_quota_for_round()` (returns `round / 2` on `round % 4 == 0 && round >= 4`, else 0). Spawned across the round on a **3 s** timer (`acc_shielded_spacing`, was 38 s — the batch is much larger now). At high rounds the ~24-AI cap throttles concurrently-live shields, so the *spawned* count can trail the nominal target.

## Spawn Intensity (Moderate tune, 2026-06-18)

The map otherwise runs stock round spawning; this is the "Moderate" intensity pass — denser and faster, still under the netcode-cautioned ceiling. All hardcoded constants (no dvars). See memory `spawn-intensity-moderate-tune`.

| Lever | Controls | Value (stock → ours) | Where |
|---|---|---|---|
| Concurrent AI limit | live zombies on screen | 24 → **50** | `_acc_main.gsc` `ACC_AI_LIMIT` (engine hard cap = 64) |
| Actor limit | live + corpses | 31 → **56** | `_acc_main.gsc` `ACC_ACTOR_LIMIT` (small headroom; corpses deleted on death) |
| Corpse linger | body stays after death | 5s → **0 (delete on death)** | `_acc_corpse_cleanup.gsc` `acc_corpse_linger_sec` — frees the actor slot so the 50 cap refills |
| Spawn-delay mult | time between spawns (wave fill speed) | ×1.0 → **×0.85** (0.1 s floor) | `_acc_main.gsc` `ACC_SPAWN_DELAY_MULT` (chains `level.func_get_zombie_spawn_delay`) |
| Early-round count | r1 / r2-4 spawn mult | ×1.40/×1.35 → **×1.50/×1.45** | `_acc_early_round_pacing.gsc` |
| Elite spacing | seconds between elite spawns | 45 → **38** | `_acc_elites.gsc` |
| Co-op spawn rate | per extra player | **+30%** (unchanged) | `_acc_coop_scaling.gsc` |
| Regular-zombie melee | damage per hit to player | 60 → **45** HP (baseline) | `_acc_zombie_speed.gsc` `ACC_ZOMBIE_MELEE_BASE_DEF` / dvar `acc_zombie_melee_base` |
| Trench melee (per layer) | damage per hit while in the trench | **+6 HP per layer** on the incoming hit (L1 ≈51, L2 ≈57, … L5 ≈75) | `_acc_bus_trench.gsc` `trench_melee_scaled` / dvar `acc_trench_layer_dmg_add` |
| Trench move (per layer) | move speed while in the trench | baseline **+4% per layer** (anim-rate) | `_acc_zombie_speed.gsc` `apply_speed_for_round` / dvar `acc_trench_layer_speed_pct` |
| Trench health (per layer) | max health while in the trench (**stacks on top of** round + co-op HP) | **+30% per layer** (L1 +30% … L5 +150%; one-way, deepest layer reached) — final HP = (round curve × player-count mult) × (1 + layer × 30%), so player scaling AND trench difficulty both apply (user 2026-07-04) | `_acc_zombie_speed.gsc` `apply_trench_health` / dvar `acc_trench_layer_hp_pct` |

Melee values are re-asserted every speed sweep on non-boss zombies (bosses keep their own — Glitch Stalker stays ×0.5). Stock baseline was 60 (`_zm_spawner.gsc:358`, originally 45). Player health is **100** (gametype setting `playerMaxHealth`, `_globallogic_spawn.gsc:242`), so 45/hit = **3 hits to down** in the open. In the trench, melee adds a **flat +10 HP per layer** (and move **+5% per layer**) on top — L1 ≈55/hit up to L5 ≈95/hit — so the deeper you descend the harder and faster they hit; the lethality ramps with depth (user 2026-06-21).

### Bus Station = high-threat zone

`corp_zone` (the **Bus Station**, with the cross-room trench) is intentionally the densest spawn zone — somewhere players should *avoid* holding. It carries **14 `riser_location` structs** (vs 4 in every other zone), 7 on each side of the trench (floor rows y=1548 / y=2348), so when players are in the Bus Station zombies pour in from both sides far faster than elsewhere. Risers are in `map_source/zm/zm_abandoned_cyber_city.map` (`targetname corp_zone_spawners`). Adding/removing risers there retunes the density (LED-bake-gated — point entities, low risk, but still re-run the bake).

## Co-op Scaling

- Regular zombies: +100% HP per extra player (stock).
- Elites: +50% HP per extra player (flatter so duos don't blender them).
- Spawn rate: **base game** (stock per-player scaling); no custom multiplier. Riot-shield elites (round-based) + glitch rounds add enemies separately.
- Shard drops from elites go to the **killing player**.
- Boss shard drops go to **every player independently** (intentional; 4p co-op = 16 boss shards per full boss).

See [04_progression_and_skills.md](04_progression_and_skills.md) for the full co-op scaling rationale.

## Sound / VFX Budget Notes

Deferred to Phase 5 art pass, but documented here so we don't forget:

- Elite classes must be **audibly distinguishable offscreen**. Shielded has a metallic *clank*, Teleporter has a *crack* on teleport, EMP has a continuous hum.
- Mini-boss has a pre-spawn siren + ground rumble so players know to reposition before they're on top of you.
- Full boss venue (Lab) gets a looping low-frequency drone when the fight is active; silence when not, for contrast.

## Design Notes

- **Why three elites, not five?** Each class should have a distinct counter-play loop. Five+ dilutes the "I know how to fight this" muscle memory.
- **Why not make EMP the early elite?** Would punish players before they have Cyberware / Overclocks to react. Progressive unlock (5 -> 11 -> 21) mirrors the difficulty ramp.
- **Boss rounds (user 2026-07-03):** a boss ROUND lands **every 9 rounds from round 9** (9, 18, 27, …; dev: every 3 from round 3), and the COUNT scales with the slot — **round 9 = 1 boss, 18 = 2, 27 = 3, …** (slot+1). Each boss that round is an **independent** Phantom-or-Rogue-Protector roll, so a round can be one-of-each, all one type, or any mix. Boss music holds until **every** boss that round is dead. Only two boss archetypes are in the random pool (Phantom, Rogue Protector), keeping the design/bug surface bounded while still varying which fight(s) you get; both scale HP off the SHARED `scale_phantom_hp` scale (base 56k, anchor 10) but with their OWN exponents — **Rogue Protector 1.1 > Phantom 1.08** (user 2026-07-04), so the Rogue is the tankier of the two; Brutus tops both at 1.12. Owner: `_acc_civil_protector` (shared roster, `level.acc_boss_roster_fn`); each module spawns its own type via a debt-based director. Multiple of either boss can be alive at once.
- **Why seal the Lab for the boss fight?** It's the one true commitment check in the map. Up until 30 you can always run. At 30 you have to finish the job. Scaled difficulty justifies the scaled tension.

## Out of Scope (v1.0)

- Random "special event" enemy rounds (Hellhounds/dogs). Stock BO3 enables these by default (`zm_usermap::main` DEFAULTs `level.dog_rounds_allowed = 1`); we **disable them entirely** (`level.dog_rounds_allowed = 0` before `zm_usermap::main()` in `zm_abandoned_cyber_city.gsc`, 2026-06-18) and rely on our elite + Brutus cadence. The orphan `dog_location` structs in the `.map` are inert.
- ~~Mini-boss variants beyond the Juggernaut Host.~~ (Added 2026-06-15: the "Glitch Stalker" mobile blink mini-boss — script-only, see above.)
- Additional boss archetypes.
- Per-run elite-class randomization (which 2 of 3 classes are active this run). Tempting but fights the "predictable pacing" design rule. Revisit post-1.0 as a modifier.
