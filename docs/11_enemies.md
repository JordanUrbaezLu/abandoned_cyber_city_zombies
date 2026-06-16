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
  - **Rounds 1–9:** the **run** gait (a natural jog) at playback rate ≥ 1.0, creeping up `acc_zspeed_jog_step_pct` (2%) per round. The jog's intrinsic speed is the "slow start" (~70–80% of max — baked into the xanim, so it's approximate, not a dialled percentage).
  - **Round 10** (`acc_zspeed_sprint_round`): zombies break into the full **sprint** gait at rate 1.0 = base-game max — a deliberate, natural escalation. sprint@1.0 clears the topped-out jog, so the wave still steps **up** (strictly monotonic).
  - **Round > 10:** sprint gait, rate `1.0 + 1%·(round−10)` (`acc_zspeed_sprint_step_pct`) — a faster sprint (rate > 1.0 reads fine, no slow-mo). No upper clamp (R15 ≈ 1.05, R20 ≈ 1.10).
  The playback rate is **floored at 1.0** in code, so the wave never animates below natural cadence. The "sprint" run modifier (`acc_mod_force_sprint`) forces the sprint gait on every round. Tunable live via the `acc_zspeed_*` dvars — see [34_flags_reference.md](34_flags_reference.md).
  - *Footgun — two abandoned attempts, kept as warnings:* (1) a walk→run→sprint-**by-round** variant with `rate = target% ÷ category_base%` dipped at each tier up-shift (the per-tier baked speeds are unknowable from data) → read as "slowing down per round." (2) A **sprint-locked** variant scaling `ASMSetAnimationRate` to an exact target % *below 1.0* produced the correct ground speed but a **slow-motion** sprint gait → "slomo running." Deep research (2026-06-15) confirmed there is **no script lever** for continuous speed at natural cadence (`SetMoveSpeedScale` is player-only; `moveplaybackrate` / `animtranslationScale` are dead/death-only). The natural-gait model above is the resolution: exact percentages are traded away for a correct-looking, monotonic ramp.

### Elite: Shielded ("Riot")

- **Unlocks**: round 5.
- **HP**: ~2x regular elite baseline.
- **Behavior**: front-facing armor. Damage to the front quarter = 25% through. Flank or break the shield with sustained fire.
- **Data Shard drop**: 1.
- **Read**: neon visor, distinct riot-shield silhouette.
- **Counter-play**: flanking (Reflex builds excel), Piercing / Penetration Overclocks, grenades, melee from the side.
- **GSC**: `_acc_elites::promote_to_shielded()`.

### Elite: Teleporter ("Blink")

- **Unlocks**: round 11.
- **HP**: ~0.8x regular elite (fragile).
- **Behavior**: short-range teleport to flank every 8-12 seconds. Post-teleport has a recovery window (shoot it then).
- **Data Shard drop**: 1.
- **Read**: cyan afterimage trail on teleport, audible *crack*.
- **Counter-play**: predict the flank angle; don't turn your back on a full screen of zombies. Ghost Protocol (Reflex T2) makes the standing-still recovery state safe.
- **EMP Grenade**: disables teleport for 8s - a reliable counter.

### Elite: EMP ("Surge")

- **Unlocks**: round 21.
- **HP**: ~1.5x regular elite.
- **Behavior**: slow movement. Melee hit drains 200 points and disables the player's active Cyberware ability (e.g. Phase Step locked out) for 5s.
- **Data Shard drop**: 1.
- **Read**: purple arcs crawling over the body, audible hum.
- **Counter-play**: range them. Don't melee. Locus / Sniper builds love them.
- **Damage profile**: heaviest HP of the three elites because it's slow; you *will* have time to kill it if you respect range.

### Mini-Boss: "Juggernaut Host" (rounds 10, 20)

- **Spawn**: replaces the normal round wave. Round 10 = 1 mini-boss. Round 20 = 2 mini-bosses simultaneously.
- **HP**: 500,000 base (10× the prior 50k baseline), scaling +50% per extra player.
- **Behavior**: charges across the map at **+25% over the current round's top speed** (locked to the sprint tier × 1.25, so it outruns even a maxed-out wave). Immune to stun from normal damage.
- **Data Shard drop**: 2 (round 10) / 3 (round 20).
- **Round pickup**: usually drops a max-ammo or insta-kill powerup alongside the shards.
- **Item drop**: **50% chance** to drop a random boss item (see [12_boss_items.md](12_boss_items.md)). If the player already has that item, it auto-converts to 3 Data Shards.
- **Mega Bottle drop**: **1 Empty Mega Bottle guaranteed** to every player on kill. Use at Lab perk machines to upgrade owned perks to their Mega variant. See [13_perks.md](13_perks.md#mega-bottles-system).
- **Read**: oversized cyber-zombie silhouette, pre-charge wind-up animation, distinctive ground-rumble audio.
- **Hard counter - Vibro Cleaver (wonder melee)**:
  - +300% damage vs Juggernaut Host on any hit.
  - Heavy-attack parry timed on a charge wind-up knocks the Host on its back + 3s stagger + massive damage.
  - Acquired via Hack Terminal completion + 5 Data Shards. See [05_weapons.md](05_weapons.md#vibro-cleaver-wonder-melee).
- **Other vulnerabilities**: elemental Overclocks (via Fission sub-node), EMP Grenade stun (brief). These are real but less effective than the Cleaver.

### Mini-Boss: "Glitch Stalker" (rounds 3+, every 10 rounds)

- **Spawn**: **2 per scheduled round** (`acc_glitch_count`), **alongside** the normal wave (does not replace it, does not gate round end). Yields the round to the Subroutine Core on full-boss rounds (r30/40/50) so the two never overlap.
- **Source**: script-only — a promoted stock zombie (the `spawn_subroutine_core` scaffold), re-skinned at runtime to the **stock Giant zombie body + head** (SetModel + head Detach/Attach; both stock xmodels, no external pack). The map's first *mobile* boss (the Juggernaut Host charges; the Subroutine Core is pinned).
- **HP**: **3× the round's normal zombie health** (`acc_glitch_hp_mult`, default 3) — auto-scales with the round, no separate curve.
- **Behavior**: chases at **~15% faster** than the round's normal zombies (`acc_glitch_speed_mult`) and every **1–1.67s teleport-blinks** to flank the nearest player (navmesh-clamped, reusing the Teleporter elite's verified path; blink cadence doubled 2026-06-15 — blinks 2× more often). For ~1.5s right after each blink it is **vulnerable** and takes **2× damage** — the fight rewards punishing the recovery window, not out-DPS-ing a sponge.
- **Melee damage**: deals **−50%** melee damage to players vs a stock zombie (`acc_glitch_melee_dmg_mult` 0.5 → `host.meleeDamage` 30, user 2026-06-15) — a fast, frequent-blinking harasser, not a heavy hitter.
- **Read**: it wears the **stock ("Giant") zombie skin** (body + head, `acc_glitch_stock_skin`) so it stands out from the charred horde — **no health bar, no over-head marker**; the skin is the only tell. On each blink it also **phase-flickers in** (a brief `Ghost`/`Show` glitch tell — render-only, stays hittable, `acc_glitch_fx`). (A 75% size was considered but dropped — `SetScale` on a live zombie AI is the confirmed `0xC0000005` crasher; would need a pre-scaled model.)
- **Data Shard / Item / Mega Bottle drop**: "mini" reward tier — 50% chance of a random boss item + **1 Empty Mega Bottle guaranteed to every player** on kill (same as the Juggernaut Host).
- **Counter-play**: don't chase it — hold an angle and burst it during the post-blink window.
- **GSC**: `_acc_boss_glitch.gsc` (self-contained: own cadence, spawn, blink, death/reward). Fully dvar-tunable — see [34_flags_reference.md](34_flags_reference.md#glitch-stalker-mini-boss-tuning). Toggle with `acc_glitch_enable`; trace with `acc_glitch_debug 1`.

### Full Boss: "Subroutine Core" (rounds 30+, every 10 rounds)

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

- **Shielded elites** spawn at the **end of a wave**, forcing a priority shift from chaff clearing to target killing.
- **Teleporters** spawn **during a wave**, splitting attention.
- **EMP elites** spawn **just before bleed** (the last few zombies of a round), preventing the lull.

This makes round *texture* predictable but round *moment* tense.

## Elite Quota Per Round

| Round range | Shielded | Teleporter | EMP | Total / round |
|---|---|---|---|---|
| 1-4 | 0 | 0 | 0 | 0 |
| 5-10 | ~1 | 0 | 0 | 1 |
| 11-19 | 1 | 1 | 0 | 2 |
| 21-29 | 1 | 1 | 1 | 3 |
| 30+ | 1-2 | 1-2 | 1 | 4+ |

Source: `_acc_elites.gsc::elite_quota_for_round()`. These numbers are first-draft and will be tuned against playtest.

## Co-op Scaling

- Regular zombies: +100% HP per extra player (stock).
- Elites: +50% HP per extra player (flatter so duos don't blender them).
- Spawn rate: +30% per extra player (not +100% - avoids chaos).
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
- **Why not randomize boss type?** Boss fights are the most scripted part of the map. Randomizing would explode the design surface and the bug surface. Same boss every 10 rounds, scaled HP.
- **Why seal the Lab for the boss fight?** It's the one true commitment check in the map. Up until 30 you can always run. At 30 you have to finish the job. Scaled difficulty justifies the scaled tension.

## Out of Scope (v1.0)

- Random "special event" enemy rounds (Hellhounds, etc.). Stock BO3 has these; we disable them and rely on our elite cadence.
- ~~Mini-boss variants beyond the Juggernaut Host.~~ (Added 2026-06-15: the "Glitch Stalker" mobile blink mini-boss — script-only, see above.)
- Additional boss archetypes.
- Per-run elite-class randomization (which 2 of 3 classes are active this run). Tempting but fights the "predictable pacing" design rule. Revisit post-1.0 as a modifier.
