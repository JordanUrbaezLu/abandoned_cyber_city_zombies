# 08 - Enemies

The bestiary: regular zombies, the Shielded elite, the Glitch Stalker mini-boss, the boss-round roster (The Phantom / Rogue Protector / Avogadro / Panzer, rolled every 9 rounds from r9), plus the Trench Warden (NSZ Brutus) and the Apothicon Fury trench elite. Design principles for difficulty and how enemies tie back into the Data Shard and Overclock loops (the Cyberware tree is dormant — see the Regular Zombie note).

Weapons are in a separate doc: [04_weapons.md](04_weapons.md).

## Design Rules (hard, non-negotiable)

1. **Every enemy has a clear read.** A visual + audio cue distinct enough that a competent player can prioritize in a 1-second glance.
2. **No bullet-sponge elites.** HP is chosen so a PaP'd weapon kills an elite in 1-2 seconds at any round. Difficulty comes from *movement, flanking, utility*, not raw HP.
3. **Movement solves most problems.** Any 1v1, including elites, should be outrun by an unupgraded player. Elite *density* is the threat, not individual stats.
4. **Boss rooms are the only forced-camp encounter.** Everywhere else rewards movement.
5. **Data Shards go to the killer.** Killing a Shielded elite auto-grants the killing player 3 Data Shards on death (user 2026-07-13, was 2) — there is no world pickup to collect. (reconciled to code 2026-07-11)

## Cast

### Boss weaknesses (+20%, user 2026-07-16)

Every heavyweight boss takes **+20% damage from ONE signature weapon class** — a light "use the right
tool" nudge, not a hard counter. Implemented as a true multiplicative ×1.2 in `_acc_damage.gsc`
(block **0c5** in `on_ai_damage`, the 0c2/0c3/0c4 amplification precedent), backstopped by the 10%/hit
boss cap. One shared live-balance knob: dvar `acc_boss_weakness_mult` (default 1.2, `1.0` = off).
Boss identity rides per-boss flags set at each boss's spawn chokepoint (all spawn paths covered,
paradise included).

| Boss | Weak to | Class matcher | Notes |
|---|---|---|---|
| Trench Warden (Brutus) | **Snipers** | `weapon_is_sniper` (MORS / Triple Take / MK14) | flag `acc_is_brutus` (nsz_brutus.gsc spawn); Paladin kept in the list for restore |
| Panzer | **Explosive + Energy** | `is_explosive_mod` (0c4 scope) + `is_energy_weapon` | flag `acc_is_panzer`; unbuffed wonders excluded; a gun matching both applies once |
| Rogue Protector | **Shotguns** | `is_pellet_shotgun` | flag `acc_is_rogue_protector`; stacks on the pellet boss cut: 0.25 × 1.2 = 0.30 (shotguns still under-perform on bosses, just 20% less so here) |
| Avogadro | **Melee** | melee MOD (normal chain) | flag `acc_is_avogadro`; the Leviathan Axe / Action Figure fixed hits-to-kill paths bypass the chain by design and keep their exact counts |
| Phantom | **SMGs + ARs** | `weapon_is_smg` / `weapon_is_ar` | flag `acc_is_phantom` (already existed for the chain-special slow) |

### Regular Zombie

- **Behavior**: stock BO3 chaff. HP scales per round.
- **Data Shard drop**: none.
- **Value in the loop**: drives Point economy, keeps pressure up, triggers AoE Overclocks. (The Cyberware skill tree is **dormant** — gated off behind `acc_cyberware_on` (default 0), `_acc_cyberware.gsc::init()`; the live weapon-upgrade path is the **Overclock terminal** (`_acc_overclocks.gsc`).)
- **HP scaling**: no custom start-HP override — regular zombies use stock BO3 scaling (150 HP start, +100/round through round 9, +10% compounding from round 10); only the co-op per-player multiplier is layered on top. See [03_progression_and_skills.md](03_progression_and_skills.md).
- **Speed curve** (`_acc_zombie_speed.gsc` — replaced the old Rampage Inducer): zombies get faster **every round**, with a **natural gait** (never slow-motion). The BO3 engine has no continuous "move at X% speed" knob for zombies — movement is root-motion / animation-driven, so the only levers are the discrete gait **tier** (walk/run/sprint, each a real animation whose baked gait *is* its ground speed) and the animation **playback rate** (which scales cadence *and* ground speed together, so a rate below 1.0 looks like literal slow-motion — it is the Widow's Wine slow mechanism). So "slower than max" comes from a slower **gait**, not a slowed animation:
  - **Rounds 1–14:** the **run** gait (a natural jog) at playback rate ≥ 1.0, starting at **101.3%** (`acc_zspeed_jog_start_pct`) and creeping up `acc_zspeed_jog_step_pct` (0.65%) per round. The jog's intrinsic speed is the "slow start" (~70–80% of max — baked into the xanim, so it's approximate, not a dialled percentage). (user 2026-06-23: jog phase extended for a gentler early-round ramp; step cut to 0.65% so the jog never outpaces the real sprint.)
  - **Round 15** (`acc_zspeed_sprint_round`; **user 2026-07-09: whole curve shifted 2 rounds EARLIER** — was 17; every round now runs the old curve's speed from 2 rounds later, and the 101.3% jog start is the same shift, keeping the R14→R15 sprint hand-off near-continuous at ~109.75%): zombies break into the full **sprint** gait at rate 1.0 = base-game max — a deliberate, natural escalation. sprint@1.0 clears the topped-out jog, so the wave still steps **up** (strictly monotonic).
  - **Round > 15:** sprint gait, rate `1.0 + 0.5%·(round−15)` (`acc_zspeed_sprint_step_pct`, cut from 1% — user 2026-06-24, gentler post-sprint creep) — a faster sprint (rate > 1.0 reads fine, no slow-mo). No upper clamp (R20 = 1.025, R25 = 1.05).
  The playback rate is **floored at 1.0** in code, so the wave never animates below natural cadence. The "sprint" run modifier (`acc_mod_force_sprint`) forces the sprint gait on every round. Tunable live via the `acc_zspeed_*` dvars — see [22_flags_reference.md](22_flags_reference.md).
  - **RAMPAGE INDUCER v2 (user 2026-08-03):** a grounded power-breaker station
    (`p7_zm_ver_powerbreaker`) on the **Plaza→Alley connector** at (1020, 452, 0)
    (`_acc_rampage.gsc`, script-spawned — no baked geometry; the floating Berzerker-skull
    reuse was rejected in playtest) that players can **toggle during
    rounds 1–4**; at **round 5 it seals** at whatever state it was left on. While ON, the
    curve is evaluated at **round + 7** (`acc_zombie_speed::effective_round()`, live dvar
    `acc_rampage_round_bonus`) for **exactly four enemy classes**: normal zombies (on-spawn
    hook + 1.5 s keep-alive → a mid-round toggle retro-applies within one sweep), **Glitch
    Stalkers** (`glitch_speed_think`), **armored/Shielded elites** (`shielded_speed_think` —
    walk cadence only, the heavy identity keeps its gait), and the **Scientist**
    (`sprint_pin` — both his +5 curve and his 1.10× anti-horde floor read the rampaged
    round, so he stays strictly faster than a rampaged horde). **Nothing else**: Phantom
    (fixed gait), Brutus (the freeze lesson), Avogadro/Rogue/Panzer/Fury never read
    `effective_round()`. With rampage on, sprint arrives at real round 8 (8+7=15); rounds
    1–4 only quicken the jog (+~4.6% playback) — the visible jump starts round 8. This
    supersedes nothing: the 2026-06-14 curve stays the base; rampage is a pure round-offset
    on top (the old Inducer's failure modes — dvar watcher fights, one-way toggle, raw-rate
    overshoot, override decay, boss ASM stomps — are all dodged by construction; see the
    `_acc_rampage.gsc` header). While ON the breaker **pulses RED** (~1 Hz,
    `acc_perk_lights::set_glow` colour 1 — the client-rendered Jugg aura; a sealed-ON
    breaker keeps pulsing, the light signifies the state); OFF = no red.
  - *Footgun — two abandoned attempts, kept as warnings:* (1) a walk→run→sprint-**by-round** variant with `rate = target% ÷ category_base%` dipped at each tier up-shift (the per-tier baked speeds are unknowable from data) → read as "slowing down per round." (2) A **sprint-locked** variant scaling `ASMSetAnimationRate` to an exact target % *below 1.0* produced the correct ground speed but a **slow-motion** sprint gait → "slomo running." Deep research (2026-06-15) confirmed there is **no script lever** for continuous speed at natural cadence (`SetMoveSpeedScale` is player-only; `moveplaybackrate` / `animtranslationScale` are dead/death-only). The natural-gait model above is the resolution: exact percentages are traded away for a correct-looking, monotonic ramp.

### Elite: Shielded ("Riot") — the ONLY elite (Teleporter + EMP removed, user 2026-06-22)

- **Spawn (user 2026-06-22)**: a **"shield round" every 4 rounds from round 4** (r4, r8, r12, …); the **count that round = the round number ÷ 2** (r4 → 2 shields, r8 → 4, r12 → 6, r20 → 10 …), spread ~3 s apart across the round (`acc_shielded_spacing`). Other rounds spawn zero elites. High-round caveat: the 50-AI cap (`ACC_AI_LIMIT`) throttles how many are concurrently alive.
- **Depth-scaled ratio (user 2026-06-25)**: ADDITIONALLY, in the **abyss** a depth-based share of *every* zombie spawns Shielded — **deeper = more**: **L2 13% · L3 20% · L4 29% · L5 40%** (scare pass 2026-08-01, was 10/15/22/30; surface + L1 pit = 0; the shield rounds above still cover those). Per-zombie roll on `zombie_init_done` (chained after coop_scaling so HP is already scaled), keyed by `acc_bus_trench::underground_layer(origin)`. Live dvars `acc_shielded_pct_l2..l5`. `promote_to_shielded` has a re-entrancy guard so a shield-round + depth-roll can't double-promote. `_acc_elites::acc_depth_shielded_roll` / `depth_shielded_pct`.
- **HP**: **4× a normal zombie's current health, at ANY player count** (user 2026-07-04: 5× → 4×, "5× is too much"). A **flat ×4** — it tracks the normal zombie's co-op scaling, NOT a separate elite curve. (Do **not** stack `special_hp_mult()` on top: by promote time the base HP already carries the regular +20%/player co-op mult, so multiplying the elite curve double-counts co-op — that earlier made a 2-player Shielded read ~4.5× a 2p zombie instead of a clean multiple.)
- **Movement**: a heavy **WALK** — roughly half the pace of the round's normal (jogging) zombies, a lumbering armoured brute. Uses the natural `walk` run cycle at full cadence, **not** the run gait at 0.5× rate (that read as slow-motion — `<1.0` anim rate is always slow-mo; user 2026-06-22 "why does it move so slow"). `_acc_elites::shielded_speed_think`; tune via `acc_shielded_walk_rate` (**default 1.2** = a bit faster than the natural walk, user 2026-06-24; 1.0 = natural, raise for faster); `acc_boss_custom_speed` opt-out; NO `SetScale`. Trade-off: it's the walk's natural pace, not a math-exact 50% — at high sprint rounds it reads slower-than-half; bump the rate if needed.
- **Behavior**: front-facing armor. Damage to the front quarter (90° arc) = 25% through — *unless* your gun's Overclock pierces it (below). Flank or break the shield with sustained fire.
- **Read**: rocket-shield world model bolted on its back (front-armoured silhouette).
- **Counter-play**: flanking (Reflex builds excel), grenades / explosives (always bypass), melee from the side, and the **Overclock Shield-Pierce** effect (4/4) — a gun's OC tier *partially* punches through the front armor: each tier restores a bit of the blocked damage, taking the front from **25% (T0) up to 55% at Tier 10** (`acc_oc_pierce_per_tier`, default 0.04/tier; `_acc_damage.gsc` effect 4/4). It's a **partial** pierce, never a full bypass, so flanking / explosives / side-melee always help. It's slow — kite it. **The Winter's Howl freeze gun (`freezegun`) is SUPER-EFFECTIVE here** — its freeze AoE ignores the front armor entirely for **×3 damage** (`acc_freeze_vs_shielded`) plus a freeze move-slow (2026-07-11; docs/04, docs/25).
- **GSC**: `_acc_elites::promote_to_shielded()`.

### Elite: Teleporter ("Blink") — REMOVED (user 2026-06-22)

> No longer spawns. `pick_elite_class_for_round` returns only `"shielded"`; `promote_to_teleporter` + `teleporter_ability_loop` remain defined but unreachable (kept for trivial restore). The Glitch Stalker still carries the blink/flank fantasy this elite originated.

### Elite: EMP ("Surge") — REMOVED (user 2026-06-22)

> No longer spawns. `promote_to_emp` + the on-hit point-drain / Cyberware-lockout debuff (`apply_emp_melee_debuff`, the `acc_emp_on_hit` branch in `on_player_damaged`) remain defined but unreachable — `acc_emp_on_hit` is never set, so the debuff never fires. (The trench-melee + Exo-resist logic in `on_player_damaged` is untouched.)

### Mini-Boss: Brutus — the "Trench Warden"

> **Implemented as Brutus** (NSZ pack) — the old "Juggernaut Host / 500k-HP / Vibro-Cleaver-countered" design was never built; this is the real enemy. **Spawn cadence (user 2026-06-18): FIRST appears when the Bus Station POWER is turned on** (`_acc_boss::brutus_power_watch` — was a fixed round 4), then **respawns 3 rounds after each kill** (`acc_brutus_respawn_interval`, was every 5). Runs alongside the wave (`ignore_enemy_count`), drops a boss item + Mega Bottle. **HP (user 2026-07-04): the TOP tier of the UNIFIED boss scale.** All bosses now share the **same base (65k, user 2026-07-05) + anchor (round 5, user 2026-07-08: was 10)**, differing ONLY by per-round exponent: **Brutus 1.11 > Panzer 1.09 > Rogue Protector 1.08 > Phantom/Avogadro 1.06 > Scientist 1.04** (2026-07-26: −0.01 all-boss health nerf; earlier 2026-07-25 retune, and 2026-07-08 the anchor moved to r5 + exponents were trimmed 0.02). So Brutus = **65k × 1.11^(round−5)**, **NO cap** (`acc_boss_mini_hp` / `acc_boss_mini_hp_exp` / `acc_boss_mini_hp_anchor`), e.g. solo **r5 65k → r10 110k → r20 311k → r30 883k → r40 2.51M**. (He debuts at power-on & round ≥ 5, so his FIRST appearance is exactly the 65k base and every round after compounds — scaling now starts at round 5, not 10.) Brutus stays the tankiest (the Panzer sits one rung below at 1.10 since 2026-07-25; before that he shared the Rogue's 1.09). (The NSZ pack's old linear `3500×round` / 85k-cap HP is dead — overwritten every spawn.) That round-scaled base is then × a **logarithmic co-op multiplier** (`boss_hp_player_mult`: ×1 / 1.5 / 1.79 / 2.0 for 1–4 players). PLANNED: tether it to **roam the Bus Station (corp_zone) trench** as a true "warden."

- **Drops (unified boss reward, user 2026-07-05 — EVERY boss identical)**: `grant_unified_boss_reward()` grants, to **every player**, a **guaranteed** challenge item (dupes auto-convert to Data Shards; see [09_boss_items.md](09_boss_items.md)) + **1 Empty Mega Bottle** + `round × 180` points (`acc_boss_score_per_round`) + `int(round / 3)` Data Shards (`acc_boss_shards_round_div`). Mega Bottles upgrade owned perks to their Mega variant at the Lab machines — see [10_perks.md](10_perks.md#mega-bottles-system). (The Paradise-fight Brutus is a survive-the-threat spawn and grants nothing.)
- **Attacks / mobility (user 2026-07-12)**: his scripted swing hits a player for **85** (`acc_warden_melee_damage`, was 75), and he now moves **~3% faster on the ground** (`acc_warden_anim_rate`, default 1.03 — `≤0` disables) applied via a safe **bare `ASMSetAnimationRate`** (`acc_boss_brutus::warden_speed_think`, the same lever the Panzer uses). He's flagged `acc_boss_custom_speed`, so the global `_acc_zombie_speed` keep-alive leaves him alone (no writer fight) — this avoids the `SetScale` / run-cycle-override calls that historically crashed/froze him.
- **Read**: oversized cyber-zombie silhouette, pre-charge wind-up animation, distinctive ground-rumble audio.
- **GSC**: `_acc_boss_brutus.gsc` / `_acc_boss.gsc` (`brutus_power_watch` cadence). Runs on the NSZ Brutus pack.

### Mini-Boss: "Glitch Stalker" (round 6+, every 2nd round)

- **Spawn**: from **round 6, every 2nd round** (`ACC_GLITCH_FIRST_ROUND_DEF 6`, `ACC_GLITCH_INTERVAL_DEF 2` → r6, 8, 10, 12, …), **alongside** the normal wave (does not replace it, does not gate round end — `ignore_enemy_count`).
  - **Why 6** (user 2026-07-15, "I actually like the first round being 6"; history 2 → 8 → 4 → 6): **round 4 never produced a Stalker.** The frame-0 spawn refusal (see the Fixed entry in CHANGELOG) ate the first spawn of *every* wave, and r4's count was exactly 1 — so r4 delivered **zero** for the module's entire life while r6 delivered 1. "First glitch at round 6" *is* the shipped game. Setting `first_round = 6` codifies reality rather than changing the feel; without it, the spawn fix would have silently added a brand-new r4 Stalker nobody had play-tested. The **per-wave count is log in round × log in players** (user 2026-07-15, `glitch_count_for_round`; the old fixed `acc_glitch_count` is superseded): `max(1, int(k·log₂(round) − c))` × `elite_count_player_mult()`, with `k` = `acc_glitch_count_log_k` (2.0) and `c` = `acc_glitch_count_log_c` (3.0).

| Round | 1p | 2p | 3p | 4p | (what actually shipped pre-fix) |
|---|---|---|---|---|---|
| r4 | — | — | — | — | 0 (no longer a glitch round) |
| r6 | 1 | 1 | 1 | 2 | 1 |
| r8 | 2 | 3 | 3 | 4 | 2 |
| r12 | 3 | 4 | 5 | 6 | 4 |
| r16 | 4 | 6 | 7 | 8 | 6 |
| r20 | 4 | 6 | 7 | 8 | 8 |
| r30 | 5 | 7 | 8 | 10 | 13 |
| r40 | 6 | 9 | 10 | 12 | 18 |
| r50 | 7 | 10 | 12 | 14 | 23 |

This replaced the **linear** `floor((round−2)/2)`, which ran to 24 Stalkers by r50 and was **player-blind** (identical solo and 4p).

**`k`/`c` are anchored to *delivered* counts, not nominal ones.** The rightmost column is what the game actually produced before the frame-0 spawn fix — the old formula's nominal 1/2/3/4/5 at r4/r6/r8/r10/r12 shipped as **0/1/2/3/4**, because every wave silently lost its first spawn. This curve's first version (c = 3.0) matched the *nominal* numbers, which would have made every glitch round **+1 harder than anything ever play-tested**. `c = 4.0` with `first_round = 6` anchors **r6 → 1** and **r8 → 2**: exactly what was being played, now delivered honestly instead of by accident. It flattens from there (r30: 5 vs 13, r50: 7 vs 23).

> **Lesson worth keeping:** a formula's output was never evidence of what reached the world. After fixing a spawn bug, re-tune against **measured** counts — never re-derive from the formula.

Peak combined elite load (Glitch + Shielded) at 4p is **40 at r64**, inside `ACC_AI_LIMIT` 50. See the Elite Quota section for why both logs are needed to stay in that budget.
- **Source**: script-only — a promoted stock zombie (the `spawn_subroutine_core` scaffold, a legacy code name inherited from the removed full boss — see the note below), re-skinned at runtime to a **WetEgg SAT toxic zombie body** (`c_sat_zmb_zombie_toxic_1`, an external gitignored pack; `SetModel`, and the engine-attached charred head is `Detach`'d with nothing re-attached since the toxic body includes its own head).
- **HP**: **1.5× the round's normal zombie health** (`acc_glitch_hp_mult`, default 1.5; user 2026-06-23, was 3×) — auto-scales with the round, no separate curve, and **1.5× a *co-op-scaled* zombie at any player count** (the multiply reads the host's post-init `maxhealth`, which already carries `regular_hp_mult()`). Fixed 2026-07-15: it previously read `level.zombie_health` (the **solo** value), making a 4p Stalker 1.5× a *solo* zombie = **0.94× a 4p zombie** — softer than the trash around it. Solo was always correct, which is why it survived so long (see Co-op Scaling below).
- **Behavior**: chases **and swings at ~1.0× the round's normal zombies** (`acc_glitch_speed_mult` **1.005** — one anim-rate lever drives both; user 2026-07-17 cut the 07-16 "25% less aggressive" pass in half after it felt too passive, 0.86 → 1.005 — the blink is its mobility, not raw speed) and every **1.55–2.59s teleport-blinks** to flank the nearest player (navmesh-clamped, reusing the Teleporter elite's verified path; blink cadence widened on 2026-06-23 and 2026-07-16, then pulled halfway back 2026-07-17 — the same 07-17 pass also restored the hidden post-blink charge to 591 u/s and the camper-pounce throttle to 1867 ms). For ~1.2s right after each blink it is **vulnerable** and takes **2× damage** — the fight rewards punishing the recovery window, not out-DPS-ing a sponge.
- **Melee damage**: deals **−55%** melee damage to players vs a stock zombie (`acc_glitch_melee_dmg_mult` **0.45**, user 2026-06-22 — 25% lower than the prior 0.6) — a fast, frequent-blinking harasser, not a heavy hitter.
- **Read**: it wears a **toxic zombie skin** (WetEgg SAT body `c_sat_zmb_zombie_toxic_1`, still gated by the legacy-named `acc_glitch_stock_skin` dvar — was the stock Giant body pre-2026-07-02) so it stands out from the charred horde, plus **teal eyes** (`acc_glitch_teal_eyes`, user 2026-06-17 — a client eyeball-material recolour, **no FX asset**; colour/luminance live-tunable via `acc_glitch_eye_color` / `acc_glitch_eye_lum`) — **no health bar, no over-head marker**; the skin + eyes are the only tells. After each blink it now **vanishes, physically charges toward the nearest player while hidden** (navmesh-clamped, `acc_glitch_charge_speed`), and only rematerialises once the AI has resumed moving (`Ghost`/`Show`, render-only, stays hittable, capped by `acc_glitch_phasein_max`, `acc_glitch_fx`) — so it reappears already on top of you, never frozen in the open mid-blink (exaggerated anti-standstill fix, user 2026-06-17). (A 75% size was considered but dropped — `SetScale` on a live zombie AI is the confirmed `0xC0000005` crasher; would need a pre-scaled model.)
- **Data Shard / Item / Mega Bottle drop**: as a FREQUENT mini-boss (1–3 per spawn round) it **no longer drops boss items or Mega Bottles** (those stay exclusive to the rare bosses, user 2026-06-22) — instead the **killer gets exactly 1 Data Shard**.
- **Counter-play**: don't chase it — hold an angle and burst it during the post-blink window. The **Winter's Howl freeze gun ONE-HITS it** (any freeze-cone hit kills it, user 2026-07-11) plus a freeze move-slow.
- **GSC**: `_acc_boss_glitch.gsc` (self-contained: own cadence, spawn, blink, death/reward). Fully dvar-tunable — see [22_flags_reference.md](22_flags_reference.md#glitch-stalker-mini-boss-tuning). Toggle with `acc_glitch_enable`; trace via a dev build (debug prints ride `level.acc_dev`).

### Full Boss: "Avogadro" — the Cyberhacker (user 2026-07-04)

> **REWORKED 2026-07-24 (built same-day, post-perk-scatter — user: "he can turn off any perk.
> And any amount at once. He also moves faster"):** he now hacks **ANY perk — all 10
> specialties + PaP** (was a 5-perk subset), with **NO cap on simultaneous hacks** (the
> max-2-per-boss limit is deleted; the **30 s per-hack expiry + travel time between the
> scattered pads** is the counter-pressure — hacks also still restore when their owner dies),
> and moves **faster** (`acc_avo_anim_rate` default 1.15 → **1.3**). The perk scatter turned
> his machine-seek into a **map-wide tour** by construction (pads span every zone incl. the
> under-rooms; his target cache re-syncs on `acc_perk_scatter_applied`, unreachable pads ride
> the seek blacklist + player-chase fallback). Lab-centric wording below predates this.

A **non-lethal, super-annoying** electric harasser. Dick_Nixon's BO2 Avogadro model (a floating lightning apparition) reframed as a rogue-AI netrunner. His whole threat is **stun-locking you and knocking the Lab's utilities offline** — not damage.

- **Spawn**: **always in the Lab** (`struct::get("acc_boss_spawn")` @ (19,3648,0)) — then **roams the map** to whichever pads currently host machines (perk scatter). Joins the shared boss roster as a **3rd type** (now a 4-boss pool: Phantom / Rogue Protector / Avogadro / Panzer, no-duplicate deck deal every 9 rounds from r9). Dev builds run the same real roster cadence (the repeating Lab test-spawn was removed 2026-07-16).
- **HP**: **exactly the Phantom's** — the shared `scale_phantom_hp` scale (65k base, anchor 5, exp 1.06 after the 2026-07-26 −0.01 all-boss nerf) × the co-op boss-HP table. Killable by guns (his BO2 bullet-immunity was removed).
- **Movement**: the **run** gait (`acc_avo_gait`) at **1.2× anim playback** (`acc_avo_anim_rate`; raised from the 1.15 ship value in the 2026-07-24 rework — user: "he also moves faster", tempered by "be careful with the speed lever — it's super sensitive". The 07-06 ladder proved 0.05 steps are felt (1.5 out-speeds the player; 1.2 → 1.15 was a deliberate step-down), so the rework takes exactly ONE rung back up: 1.2 is a real, visible speed-up without gambling past the catch-crossover in (1.2, 1.5). Read at spawn — push it live if it under-shoots. `ASMSetAnimationRate` persists and is boss-safe — it's the run-cycle *override* that froze Brutus, not the rate call). He seeks the nearest enabled machine to hack (navmesh-projected goal, sticky until arrival/timeout), falling back to chasing the nearest player when no machine is reachable.
- **Attack — the stun IS the threat** (reworked 2026-07-06 so anim + SFX + bolt + stun are ONE synced event): the pack **behavior tree plays his throw animation** (enemy 150–2000 u away + line of sight), whose anim notetrack (`avo_send_bolt`, frame 20) launches a **visible electric bolt projectile** (script_model carrying his crackling `avogadro_fx` linger FX) that flies at the target (`acc_avo_bolt_speed` 900 u/s, slight lead) and applies the **30% boss slow + 6 damage on impact** (`_acc_elites::acc_avogadro_zap` + `acc_avo_shot_damage`; user 2026-07-06 ladder: pure-stun 0 → 1 → 5, then user 2026-07-18 +25% all-Avogadro damage → 6; the hit also plays the stock electric shellshock/overlay tell, `acc_avo_shock_sec` 0.75 s) to everyone within `acc_avo_bolt_hit_radius` (130 u) — **step aside and it misses**. **Presentation (2026-07-06, "hard to see the projectile")**: the bolt rides its own `acc_avo_bolt_fx` clientfield — the `.csc` stacks his crackle-cloud FX **plus** the bright tesla arc on the mover, and plays the throw bark at launch / warp-out fizzle at impact **client-side, positionally at the bolt** (server `PlaySound` on AI actors is dead in this build — nameplate precedent), so audio is frame-locked to the visual; speed 1100→**900 u/s** and min flight time 0.15→**0.25 s** so even close throws render across client snapshots. Cadence `acc_avo_bolt_cd` (0.75 s; the pack's hardcoded 20 s cooldown was replaced, and its ±50 u facing-rect LOS gate dropped — playtests starved on both). **Point-blank** (inside the bolt's 150 u minimum) an **aura zap** (`acc_avo_fire_interval` 0.5 s, ≤`acc_avo_aura_range` 220 u, same slow + `acc_avo_aura_damage` 10 — user 2026-07-12: 5 → 8/tick, user 2026-07-18 +25%: 8 → 10) keeps the stun-lock on players hugging him, preferring un-stunned targets to spread the slow. A **watchdog** logs (and direct-zap fallbacks) only if the BT bolt starves on a bug — hiding without LOS is legit counterplay. **Mega Electric Cherry** softens the slow to **−10%** (and if he's hacked your EC off, that softening naturally stops). No melee, no damaging bolt.
- **2026-07-06 bug-fix trio** (playtest: "never walks / no bolt / doesn't hack"): the pack BT gated the bolt on an **unregistered** `ShouldDopunchAttack` condition — the bolt branch could never run, and since both the move and idle branches require `avoShouldShootBolt` to be false, the boss **froze in place** whenever the bolt wanted to fire (typically the moment a player engaged at mid-range). A stub registration (`false`) unblocks both. Additionally the target service now maintains `.enemy` even while machine-seeking (it used to early-return, starving the bolt condition and `OrientMode("face enemy")`).
- **2026-07-06 round 2** (diagnostics-guided): machine seek goals were the vending-machine **entity origin — inside the machine at z=60, off the navmesh** — so `SetGoal` silently failed and he stood still all game and never hacked; all cached targets are now **navmesh-projected** (`GetClosestPointOnNavMesh`, the Brutus recipe). The seek is **sticky** (commits to one machine until arrival/timeout; the old nearest-re-pick + 8 s blacklist ping-ponged two machines forever, starving the player-chase fallback), a timeout blacklists 30 s and opens a 12 s chase window, and player chase is the BT service's **entity** goal.
- **Signature — hacks machines (UNCAPPED + all-perk since 2026-07-24)**: walks up to the nearest enabled machine (**perks prioritized** over PaP) and **disables it for 30 s**; **no limit on how many he holds at once** — a long-lived Avogadro can in principle dark the whole board, and the counter-pressure is that each hack expires on its own 30 s clock while he's still traveling between the scattered pads (plus every hack he owns restores instantly when he dies). **Full-disable contract (user 2026-07-06 — "check all cases")**: the base perk stops working for **all** players (`zm_perks::perk_pause`), the machine **can't be bought** (`TriggerEnable(false)` on every trigger of that specialty, both dimensions), the machine's **aura goes dark** (`set_glow 0`; the restore re-light is gated on the power-on aura latch so a pre-power unhack can't light a machine early — auras re-affirmed as THE power visual 2026-07-25), **and every Mega live effect drops with it** — `owns_or_paused` reads an avo-hacked perk as not-owned, and the stateful megas (Ultimate Tank's +50 HP, The Flash's +15% speed, Spiderman's stance watcher) are recomputed away for the window (`_acc_mega_bottles::on_perk_hacked/on_perk_restored`; every other perk's effects read live and drop automatically); **PaP** can't pack while hacked. Targets (2026-07-24): **ALL 10 perks + Pack-a-Punch** (PhD rides `specialty_electriccherry`, Electric Cherry rides `specialty_combat_efficiency`). A hack restores after 30 s, when **that** Avogadro dies (each restores only its own), or when the **last** Avogadro dies (a belt-and-suspenders force-restore — a perk can never stay stuck off). Two simultaneous Avogadros (possible from round 45 via the deck repeat) never fight over a machine — one hack per machine; the sibling seeks a different one. **Per-perk hack audit hardening (user 2026-07-25):** (1) **solo Quick Revive is UN-hackable** — in a solo-revive game QR is the self-revive lifeline, so `is_key_enabled`/`do_hack` both skip it while `level.using_solo_revive` is set (co-op QR hacks normally); (2) **Mule Kick's 3rd gun is stashed and returned** — stock's pause take removes the at-risk gun permanently, so the hack snapshots primaries+ammo pre-pause, diffs to find the taken gun, and re-gives it (with ammo, no forced switch) after the restore — validated per player (a full death mid-window forfeits it like any real mule loss; deferred while downed); (3) **twin megas revert in-place, instantly** — Speed Cola Mega (+75% reload) and Deadshot Mega (−50% recoil) live in `_acc_weapon_variants`' in-place weapon-def twins gated on `HasPerk && mega`; the hack/restore now pokes `request_reconcile` so the base form swaps back (and the twin returns) the same frame instead of riding the 3 s net; (4) **re-hack cooldown** (`acc_avo_rehack_cd_ms`, 45 s, level-wide) — a restored perk is guaranteed usable for the window before any Avogadro may hack it again, so uncapped hacking can't camp one machine into a permanent blackout.
- **Counter-play**: he's fragile relative to the disruption — burn him down fast to get your perks/PaP back, or ride out the 30 s. He's deliberately **weak to melee**: a knife does **1/100 of his max HP**, so **exactly 100 knives kill him at any round** (`acc_avo_knife_hits`) — a high-risk close-range counter, since getting in his face means eating the stun-lock. Kill him and everything he disabled comes back at once.
- **Drops**: standard boss tier — a guaranteed challenge item + 1 Empty Mega Bottle + Data Shards to every player.
- **GSC**: `_acc_boss_avogadro.gsc` (drives the pack AI in `_zm_ai_avogadro.gsc`). Fully dvar-tunable — see [22_flags_reference.md](22_flags_reference.md). Toggle with `acc_avo_enable`; trace via a dev build (debug prints ride `level.acc_dev`).

### Full Boss: "Panzer" (user 2026-07-08 — renamed from "Panzer Soldat" same day — rebuilt; previously live 2026-06-19)

The literal Der Eisendrache Panzer chassis (Spiki asset-dump mechz port) — the roster's heavy
walker: hardest melee in the pool, Rogue-Protector-tier HP.

- **Spawn**: **always the Plaza** (outside — he's huge) at his **own anchor, the central Plaza riser
  `(-227.5, 350, 0)`** (the proven 2026-06-19 spot), deliberately ~600u from the Rogue Protector's
  chest-spot anchor so two bosses never share a doorstep. A **navmesh ring query with 150u
  boss-clearance** (`pick_spawn_point`) scatters multi-boss-round spawns so a second Panzer (or a
  wandering RP) is dodged, not stacked. Joins the shared roster as the **4th type** (no-duplicate
  deck deal). Dev builds run the same real roster cadence (the round-2 keep-one-alive dev loop was
  disabled 2026-07-12; if disabled via `acc_panzer_enable`, his roster slots re-home — the Avogadro rule).
- **Movement + zap**: run gait at **1.10× anim playback** (`acc_panzer_anim_rate`; user ladder
  2.0 "buggy fast" → 1.15 → 1.1 → 1.09 → **1.10** final — lumbers just under the Avogadro's 1.15). His
  **zap grenades explode on impact** (`electroball_watch` detonates on first bounce) and apply
  the SHARED boss zap slow (`acc_protector_zap`: 3s refreshing window, Battery item absorbs,
  Power Surge softens) to everyone in the **220u** blast (`acc_panzer_zap_radius`; user 2026-07-12 **+10%**, 200 → 220 — the code-side buff is the blast **radius**; the electroball's literal explosion **damage** is the engine 115-grenade detonation, GDT-side/install-side, not repo code).
- **HP (his own rung — user 2026-07-26: −0.01 all-boss nerf → **1.09**)**: shared 65k/anchor-5 scale with exponent **1.09**
  (`acc_panzer_hp_exp`; the tuning ladder walked 1.12 → 1.13 → 1.14 → 1.12 → 1.09 "match the RP" → 1.10 →
  **1.09**) × the co-op boss-HP table — the full ladder is **Brutus 1.11 > Panzer 1.09 > Rogue Protector 1.08 >
  Phantom/Avogadro 1.06 > Scientist 1.04**. Solo (anchor 5, exp 1.09) r5 65k → r10 100k → r20 237k → r30 561k → r40 1.33M.
- **Attacks**: stock mechz BT — flamethrower sweeps, 115-grenade volleys, and a **very hard melee**
  (`acc_panzer_melee_damage`, default **99** — user 2026-07-18 +10% all-Panzer damage, was 90; nearly a
  one-hit down without Jugg; the pack's original
  dead value was an instadown 150). **Flamethrower +10% (user 2026-07-12):** stock burn constants
  (30/tick, 20 with Jugg — 0.5s ticks over a 1.5s burn) live in a stock `#define`d function, so the
  vendored flame loop now calls `acc_player_flame_damage` (a scaled twin in `mechz_spiki.gsc`, same
  `is_burning` mutex + Jugg branch) — per-tick damage × `acc_panzer_flame_mult` (default **1.21** after
  the 2026-07-18 +10% all-Panzer pass → 36 / 24 with Jugg). His **electroball explosion** (engine-side 115
  grenade damage) takes the same +10% via `acc_panzer_explosive_mult` (1.1) in `_acc_elites::on_player_damaged`. Claw-grapple is **deliberately OFF** (broken-as-decompiled +
  inescapable in the Origins variant; requires targetname "mechz_tomb" we never set). Armor plates
  track their own part health server-side but read as **solid armor** (detach visuals are DLC1-gated).
- **Hit-location damage (user 2026-07-11, RE-TUNED 2026-07-12 — "weak headshot damage + a lot of guns
  can't even hit him in the head"):** he does NOT use the normal-zombie damage path; he runs the stock
  `MechzServerUtils::mechzDamageCallback`, which scales by body part — **head = 100%, exposed power
  core = 100%, everything else (torso/limbs) = stock 10%**, explosives = 50%. Problems fixed in a
  wrapper on `actor_damage_func` (`acc_mechz_damage_wrap`; splash-only MODs keep stock handling):
  - **Body was a 10% sponge.** We **rebuff the body/limb family from 10% → `acc_panzer_body_scale`
    (default 0.35)**: the wrapper delegates to stock (all part-destruction / faceplate / hit-marker /
    explosive side effects intact), recovers the pure stock hit scale by dividing the result by the
    weapon-modified base, and multiplies ONLY the 0.1 family by 3.5. Exposed-core (0.5/1.0) stays stock.
  - **The head was gated behind the helmet, so weak guns couldn't headshot at all.** Stock only lets the
    head register once the faceplate is destroyed, and **our faceplate is a fat pool** (`level.var_fa14536d`
    1500+, scaling toward a 16000 cap — vs stock's **50**). With the helmet ON the engine never even
    reports `"head"` — face hits come in as `torso_upper` (or `helmet`/`neck`, which stock's switch
    DEFAULTs to the 0.1× family). The wrapper makes the head a weak spot for **every aimed shot,
    faceplate or not**: `head`/`helmet`/`neck` hitLocs count directly, else proximity to the
    `j_faceplate` tag within **`acc_panzer_head_radius` (default 36u — 2026-07-12: was 21, but the tag
    is the INTERIOR joint and impacts land on the helmet SURFACE 10–25u out, so 21 only caught
    dead-center face shots; jaw/side/top hits fell to 0.1× = the "can't hit his head" report;
    height-guarded)**, paying **`acc_panzer_head_scale` (default 0.9× base — user's dialed-in value
    after a brief 2.0 same-day; ≈ 2.6× a body shot, the head stays the best target)**. Stock still
    chips the faceplate as a side effect.
  - **Projectile-class guns could NEVER headshot (2026-07-12).** Stock `MOD_PROJECTILE` (Thundergun,
    Blast-O-Matic, energy launchers) has **no head path at all while the faceplate exists** and only a
    12u `tag_eye` window after — and the wrapper's old splash early-return locked that in. A projectile
    **direct** hit now gets the same head check/scale as bullets; projectile body hits keep stock's flat
    0.5×, and splash-only mods (grenade/explosive) still can't headshot.
  - **TRAP — scripted `DoDamage` on the Panzer must NOT pass hitloc `"none"` (fix 2026-07-15).** Stock
    wraps its **entire** hit-location switch in `if( hitloc !== "none" )` (`mechz.gsc:1146`), and the only
    branches after it are `MOD_PROJECTILE` / `MOD_PROJECTILE_SPLASH` — so a **`"none"` + `MOD_MELEE`**
    scripted hit matches nothing and falls through to `mechz.gsc:1448` **`return 0`** = literally zero
    damage (the wrapper's `result <= 0` early-return then forwards the 0 verbatim, so no wrapper tuning
    can rescue it). `"none"` is the *normal* stock convention for scripted damage
    (`_zm_weap_gravityspikes.gsc`), which is what makes this mechz-specific trap so easy to hit — it bit
    the Leviathan Axe hold-to-auto-swing, whose follow-ups did 0 damage while still showing damage numbers
    and charging the Berzerker blood tax. **Pass a real hitloc**; prefer **`"torso_lower"`**, which routes
    to the switch's `default:` case (a bare `return damage * MECHZ_BODY_DAMAGE_SCALE`) and therefore never
    calls `GetPartName( .., boneIndex )` — `DoDamage` supplies **no boneIndex**, and stock's `torso_upper`
    case does call it. That lands the normal 0.1 body family → rebuffed to `acc_panzer_body_scale` as usual.
  - **Melee was silently tripled-to-kill (audit fix 2026-07-15).** The wrapper is **bullet-scoped**, but
    `MOD_MELEE` is neither a bullet nor a splash mod, so it fell through into the body path — and stock
    `_zm.gsc` runs `actor_damage_func` **after** `check_actor_damage_callbacks`, so the wrapper was
    re-scaling a value `_acc_damage::on_ai_damage` had already declared **final**. The **Leviathan Axe**
    and **Action Figure** deal a fraction of MAX health (`maxhealth/N` = "N hits to kill ANY boss
    regardless of HP", docs/04): stock DEFAULTs a melee hitLoc into the 0.1× body family and the rebuff
    paid it back to only 0.35×, so a tier-3 axe took **~23 swings instead of its designed 8** and the
    figure **~94 instead of 33** — while the damage number on screen already showed the *designed* value.
    Melee now **passes through untouched** (stock still runs first, so part destruction / faceplate chip /
    hit marker / pain audio / scoring are intact — only its *scale* is refused). Melee correctly skips the
    head block (melee never headshots on this map); knife/bowie ride the normal scaled chain and stay
    backstopped by the map-wide **10% per-hit boss cap**, so undoing the 0.1× can't cheese him.
  - **Dvars:** `acc_panzer_body_scale` 0.35 (set 0.1 = exact stock body), `acc_panzer_head_scale` 0.9,
    `acc_panzer_head_radius` 36, `acc_panzer_melee_scale` 1.0 (honour `on_ai_damage`; ~0.1 = old stock
    melee feel — **not** `acc_panzer_melee_damage`, which is damage the Panzer *deals*). Panzer is the
    only mechz on the map, so this touches nothing else.
- **THE historical crash, fixed**: every prior attempt CTD'd "when he attacks or is attacked" — stock
  `mechz.gsc` registers the `mechz_face` clientfield at VERSION_SHIP **server-side only** and sets it
  on every idle/attack/pain/death → layout desync. Fix (proven in-game 2026-06-19): no-op rebind of
  the 4 face StartFunctions (last-write-wins `BT_REGISTER_API`) + 2026-07-08 belt-and-braces: the
  vendored `.csc` mirror-registers all 11 stock server-side mechz fields. Full fix ledger: the
  `scripts/zm/mechz_spiki.gsc` / `.csc` headers.
- **Drops**: standard boss tier — a guaranteed challenge item + 1 Empty Mega Bottle + round-scaled
  points + Data Shards to every player.
- **GSC**: `_acc_boss_panzer.gsc` (drives the vendored `scripts/zm/mechz_spiki.gsc/.csc`). Toggle with
  `acc_panzer_enable`; trace via a dev build (debug prints ride `level.acc_dev`); spawn nudge via `acc_panzer_spawn_*`.
  **Assets**: Spiki dump modme #3087 (external, gitignored; manifest marker
  `source_data\mechz_spiki.gdt`, links in `tools/_panzer_stash/README.md`).

### Full Boss: "Rogue Protector" (user 2026-07-02 — the Civil Protector weaponised into the ~round-20 boss)

The HB21 Civil Protector robot turned hostile — the roster's **ranged** boss. He hunts players with a
rifle + rocket and never stops walking; the whole fight is about surviving the gap between his volleys.

- **Spawn**: **always the Plaza** (`acc_box_plaza`; nudge with `acc_protector_spawn_*`), deliberately ~600u
  from the Panzer's riser so two bosses never share a doorstep. Joins the shared roster as the **`protector`**
  type (no-duplicate deck deal every 9 rounds from r9, count = slot+1). Spawned **directly via `SpawnActor`**
  (`spawner_acc_zod_robot_boss`) — a `.map` actor_spawner for this axis-team aitype **hard-crashed the game at
  load**, so there is deliberately NO spawner entity (do not re-add one). His debt director trickles one in per
  ~3s tick (multiple may be alive on a multi-boss round); during the Paradise onslaught he spawns **on a living
  player** in the arena.
- **HP (the MIDDLE tier)**: shared 65k/anchor-5 scale with exponent **1.08** (`acc_protector_hp_exp`; after the
  2026-07-26 −0.01 all-boss nerf the ladder is Brutus 1.11 > Panzer 1.09 > **Rogue Protector 1.08** > Phantom/Avogadro 1.06 > Scientist 1.04) × the co-op boss-HP table. Solo
  (anchor 5) r5 65k → r10 95k → r20 206k → r30 445k → r40 961k.
- **How he's hostile (the whole trick)**: a NEW install-side aitype `acc_zod_robot_boss` = the pack's GOLD
  companion clone with ONE field changed — `"team" "allies" → "axis"`. Engine target acquisition is team-based,
  so on axis he natively acquires **players** as enemies (and same-team zombies ignore him), **with zero
  behavior-tree edits**. The companion-only services (follow leader / **revive downed players** / chase powerups)
  are permanently off (`b_robot_finished = 1`), so an enemy robot never revives the players it just downed.
- **Attacks (a 4-bullet volley, then a rocket, plus a zap)**: (1) a **rifle volley** — one `MagicBullet` every
  `acc_protector_fire_interval` (2.5s) from his muzzle, range `acc_protector_fire_range` (1500u) + LOS, ~28
  damage/bullet ramping **toward ~60 at point-blank** (`acc_protector_close_mult`). He fires *script-side*
  because the engine's `CanShootEnemy()` verdict stays 0 forever (the `_zm_aat_fire_works` MagicBullet
  precedent). (2) A **real, visible Mahem rocket** (`s1_mahem`) as the **5th shot** — its raw 3100 is
  hard-capped player-side to `acc_protector_mahem_dmg` (**69** after the 2026-07-12 +25%, was 55) with big
  knockback (**+25% user 2026-07-18**: rocket `acc_protector_mahem_knockback` 320 → **400**, per-bullet
  `acc_protector_knockback` 160 → **200**), then `acc_protector_mahem_cooldown` (3s) before the next cycle. (3) A close-range **zap** every
  `acc_protector_zap_interval` (3s): every player within `acc_protector_zap_range` (250u, **no LOS**) takes a
  **−30% move slow for 3s** (`acc_protector_slow_mult` 0.70) + `acc_protector_pulse_dmg` (10) AoE — Battery item
  absorbs it, Mega Electric Cherry softens the slow to −10%.
- **Presentation**: a self-contained **slam-down entrance** (ground-tell telegraph → quake + landing FX + a
  boss-**excluding** kill-splash so a sibling boss isn't killed by his landing → "activated" VO), a relentless
  **sprint-lock chase** (`hunt_players` re-pins the goal every 0.5s), an **LUI health-bar row**
  (`CoD.AccBossBars` — the ONLY boss indicator; the 3D over-head plate was removed 2026-07-25),
  and boss music (held until every boss that round is dead).
- **Drops**: the unified boss reward — a guaranteed challenge item + 1 Empty Mega Bottle + `round × 180` points
  + `int(round / 3)` Data Shards to **every** player (suppressed during the Paradise onslaught).
- **Counter-play**: no weak-spot gate — standard damage, headshots read effective (teal crosshair numbers). His
  outgoing bullets route through the player-damage chain, so **god mode zeroes them** and the rocket is capped;
  **Juggernog** comfortably survives a concentrated burst, and the survivable window is the ~3s gap after each
  volley+rocket. Fight him at **mid-range** — closing in both raises his bullet damage and triggers the 250u zap.
- **GSC**: `_acc_civil_protector.gsc` (this module also OWNS the shared multi-boss roster, `level.acc_boss_roster_fn`).
  Force-spawn via the `acc_protector_spawn 1` dev console command (polled only while a dev build is running);
  trace via a dev build (debug prints ride `level.acc_dev`). Assets: HB21 Civil Protector pack
  (external, gitignored). Integration recipe: memory `hb21-civil-protector-integration`.

### Trench Elite / Paradise Mini-Boss: "Apothicon Fury" (user 2026-07-03; Paradise wave 2026-07-09)

A teleport-charging demon that **only appears deep in the trench** (and in the Paradise finale) — the price of
pushing the abyss. In normal play it's a **trench elite** (kills like a zombie, no boss loot); in Paradise it's
promoted to a wave mini-boss.

- **Spawn (normal — a per-player trench clock)**: each connected player at trench **layer ≥ `acc_fury_min_layer`
  (2)** ("level 2 and below", not the pit) gets one meteor-dropped near them — the first after `acc_fury_arm_sec`
  (**6s**, was 8 — scare pass 2026-08-01) of being deep, then every `acc_fury_interval` (**22s**,
  `ACC_FURY_INTERVAL_DEF`; was 30 — scare pass 2026-08-01), **shrinking with depth** (`fury_delay_sec`, NEW
  2026-08-01: −2.5s per layer below L2, floored 15s → **L2 22 / L3 19.5 / L4 17 / L5 15**; recomputed live each
  wait tick, so descending mid-clock speeds it up) while they stay down; surfacing **pauses** that
  player's clock (re-arms the 6s on the next descent). N deep players = **N independent streams**; the alive cap
  is the **lobby size** (solo 1 / quad 4) **+1 while ANY player is at layer ≥ 4** (scare pass 2026-08-01 — solo
  at L4/L5 can face 2 at once; ceiling `acc_fury_max_ceil` 8 unchanged). **Paradise**: one fury per rolling wave
  dropped **on a living player** in the arena (cap `acc_paradise_fury_max` 1), flagged `acc_is_mini_boss`.
- **HP**: a flat **12× the current round's normal-zombie health** (`acc_fury_health_mult`; history 5 → 8 → 10 →
  12), and **Furious mode doubles it again**. The 12× is against a **co-op-scaled** zombie at any player count.
  Unlike the Shielded elite and the Glitch Stalker — promoted factory zombies that inherit the co-op HP mult
  automatically via the `zombie_init_done` hook — the fury is **`SpawnActor`'d from the pack's spawner, so that
  hook never runs on it** and `_acc_fury` must apply `regular_hp_mult()` **by hand**. Fixed 2026-07-15: it
  previously multiplied the raw `level.zombie_health` (**solo**) value, so a 4p fury was 12× a *solo* zombie =
  only **7.5× a 4p zombie**. Note its `self.maxhealth` is *not* a valid base either — it holds the pack's own
  `health_init` tier (1.2/1.5/1.7×), not a scaled zombie.
- **Attacks**: (1) the signature **bamf teleport-charge** — it vanishes (`Ghost` + `NotSolid`) and rematerialises
  next to its target (cooldown ~4.5–6s). (2) **Bamf-land melee** — **50 damage** (after the 2026-07-12 2× via
  `acc_fury_dmg_mult`, base 25) + a `PhysicsExplosionSphere` knock-push to anyone within 250u. (3) **Furious
  mode** — after taking 3 hits it enters super-sprint locomotion, **doubles its own health**, and gains a
  pre-emptive bullet-dodge juke (only one fury may be furious at a time). It also knocks down nearby regular
  zombies on every bamf.
- **Robustness fixes** (all `[acc]`, hard-won): a **Ghost/NotSolid bamf watchdog** (`acc_bamf_ghost_failsafe`)
  force-`Show()`/`Solid()`s it after 4s so an interrupted bamf can't strand it permanently invisible + unhittable
  ("charge attack then invisible"); `ignore_enemy_count` (a fury alive after the horde clears would otherwise
  never let the round end); `ignore_round_spawn_failsafe` (a trench/Paradise fury at z=−1200 sits below the −1000
  below-world line and was being culled ~30s in); the deep-trench spawn skips the enabled-zone check and
  force-completes emergence into the playable area; immune to **Turned + Thunder Wall** AATs; and it takes **0
  damage until it finishes spawning**.
- **Drops**: it pays like a **normal zombie kill** (points only, hi-score-weapon aware) — deliberately **NO** boss
  item and **NO** Data Shards (it's an elite, not a boss). In Paradise it's explicitly `acc_no_shard_reward` (a
  threat, not a farm).
- **Weaknesses**: the **Leviathan Axe** kills it in 2 hits (a one-shot from 2nd PaP onward), and a **charged Fire
  Bow demon-gate hit is a guaranteed one-shot at any round** (`acc_firebow_fury_onehit`) — the intended hard
  counter. No gated weak spot, so raw high-DPS / PaP fire also burns through the 12× HP; but it is immune while
  spawning and to Turned / Thunder Wall, so those are non-answers.
- **GSC**: `_acc_fury.gsc` (drives the vendored `zm_genesis_apothicon_fury` + `scripts/shared/ai/archetype_apothicon_fury`),
  wired from `_acc_main`. Toggle `acc_fury_on`; trace via a dev build (debug prints ride `level.acc_dev`); tune `acc_fury_health_mult` /
  `acc_fury_dmg_mult` / `acc_fury_interval` / `acc_fury_min_layer`. Assets: HB21 Apothicon Fury pack (external, gitignored).

### Full Boss: "Subroutine Core" — REMOVED (user 2026-06-22)

> The legacy Subroutine Core full boss (a pinned Lab fight at rounds 30/40/50 with phase-transition power/perk debuffs) was **removed 2026-06-22**; boss rounds are now the every-9-rounds roster above. `run_full_boss` / `spawn_subroutine_core` remain defined-but-unreachable dead code in `_acc_boss.gsc` (the `spawn_subroutine_core` scaffold is now reused by the Glitch Stalker). The full removed design lives in CHANGELOG.md (2026-06-22).

## Elite Spawn Timing (pacing, not randomness)

Stock BO3 leaves elite timing to spawn RNG. We don't. See [05_mechanics.md](05_mechanics.md) for the full model; summary:

- **Shielded** is now the only elite. Its whole quota arrives on the **"shield round"** (every 4th round from r4), spread ~3 s apart across that round so the batch is a sustained pressure event rather than a single spike.

This makes round *texture* predictable but round *moment* tense.

## Elite Quota Per Round (user 2026-06-22; curve reworked 2026-07-15)

Shielded-only "shield rounds" — every 4th round from r4. Every other round = 0 elites (cadence unchanged).

**Count = `max(2, int(k·log₂(round) − c))` × `elite_count_player_mult()`** — log in *round* **and** log in *players*
(`k` = `acc_shielded_count_log_k` 2.5, `c` = `acc_shielded_count_log_c` 3.0).

| Round | 1p | 2p | 3p | 4p | (old linear `round÷2`) |
|---|---|---|---|---|---|
| r4 | 2 | 3 | 3 | 4 | 2 |
| r8 | 4 | 6 | 7 | 8 | 4 |
| r12 | 5 | 7 | 8 | 10 | 6 |
| r16 | 7 | 10 | 12 | 14 | 8 |
| r20 | 7 | 10 | 12 | 14 | 10 |
| r24 | 8 | 12 | 14 | 16 | 12 |
| r40 | 10 | 15 | 17 | 20 | 20 |
| r48 | 10 | 15 | 17 | 20 | 24 |

Two changes vs the old `round ÷ 2`:

1. **Log in round.** The old curve grew linearly *forever* (24 shields by r48) — this doc's own source note used to
   flag it as "still a chunk of shields vs the AI cap … revisit if it feels heavy". This is that revisit. `k`/`c` are
   anchored so **1p is bit-identical to the old curve early** (r4 = 2, r8 = 4); it only flattens once the old one ran away.
2. **Log in players.** The quota used to be **player-blind** — a 4p lobby saw the same shield count as solo while the
   regular horde grew +30%/player, so Shielded were a *shrinking* share of the wave as the lobby grew.

The two logs **compound** (4p doubles the round term), which is exactly why the round term must stay flat late. The
rejected alternative (keep linear round × add the player mult) reached **78 elites at r40 4p** against `ACC_AI_LIMIT`
**50** — an elites-only wave with normal zombies starved out of the actor budget. Worst case on the shipped curve is
**38 at r52 4p** (Glitch + Shielded combined), inside the cap.

Source: `_acc_elites.gsc::elite_quota_for_round()`. Spawned across the round on a **3 s** timer
(`acc_shielded_spacing`). At high rounds the 50-AI cap (`ACC_AI_LIMIT`, `_acc_main.gsc:98` — **not** the stock 24 an
older note here claimed) throttles concurrently-live shields, so the *spawned* count can still trail the nominal target.
**This quota is only one of three Shielded sources** — the depth roll and the reactor surge spawn Shielded
independently and are **not** bounded by it.

## Spawn Intensity (Moderate tune, 2026-06-18)

The map otherwise runs stock round spawning; this is the "Moderate" intensity pass — denser and faster, still under the netcode-cautioned ceiling. All hardcoded constants (no dvars). See memory `spawn-intensity-moderate-tune`.

| Lever | Controls | Value (stock → ours) | Where |
|---|---|---|---|
| Concurrent AI limit | live zombies on screen | 24 → **50** | `_acc_main.gsc` `ACC_AI_LIMIT` (engine hard cap = 64) |
| Actor limit | live + corpses | 31 → **56** | `_acc_main.gsc` `ACC_ACTOR_LIMIT` (small headroom; corpses deleted on death) |
| Corpse linger | body stays after death | 5s → **0 (delete on death)** | `_acc_corpse_cleanup.gsc` `acc_corpse_linger_sec` — frees the actor slot so the 50 cap refills |
| Spawn-delay mult | time between spawns (wave fill speed) | ×1.0 → **×0.85** (0.1 s floor) | `_acc_main.gsc` `ACC_SPAWN_DELAY_MULT` (chains `level.func_get_zombie_spawn_delay`) |
| Early-round count | r1 / r2-4 spawn mult | ×1.40/×1.35 → **×1.0/×1.0 (neutralized to base-game counts)** | `_acc_early_round_pacing.gsc` |
| Elite spacing | seconds between elite spawns | 45 → **3 s** (`acc_shielded_spacing`, default 3.0) | `_acc_elites.gsc:200` |
| Co-op spawn rate | per extra player | **+30%** (unchanged) | `_acc_coop_scaling.gsc` |
| Regular-zombie melee | damage per hit to player | 60 → **45** HP (baseline) | `_acc_zombie_speed.gsc` `ACC_ZOMBIE_MELEE_BASE_DEF` / dvar `acc_zombie_melee_base` |
| Trench melee (per layer) | damage per hit while in the trench | **+5 HP per layer** on the incoming hit (L1 ≈50, L2 ≈55, … L5 ≈70; 6 → 5 → 4 user 2026-07-16, back to **5** scare pass 2026-08-01) | `_acc_bus_trench.gsc` `trench_melee_scaled` / dvar `acc_trench_layer_dmg_add` |
| Trench move (per layer) | move speed while in the trench | baseline **+4% per layer** (anim-rate; 4 → 3.5 → 3 user 2026-07-16, back to **4** scare pass 2026-08-01; L5 +20%) | `_acc_zombie_speed.gsc` `apply_speed_for_round` / dvar `acc_trench_layer_speed_pct` |
| Trench health (per layer) | max health while in the trench (**stacks on top of** round + co-op HP) | **+25% per layer** (L1 +25% … L5 +125%; one-way, deepest layer reached; nerf 30 → 27 → 25, user 2026-07-16) — final HP = (round curve × player-count mult) × (1 + layer × 25%), so player scaling AND trench difficulty both apply (user 2026-07-04) | `_acc_zombie_speed.gsc` `apply_trench_health` / dvar `acc_trench_layer_hp_pct` |

Melee values are re-asserted every speed sweep on non-boss zombies (bosses keep their own — Glitch Stalker stays ×0.45). Stock baseline was 60 (`_zm_spawner.gsc:358`, originally 45). Player health is **100** (gametype setting `playerMaxHealth`, `_globallogic_spawn.gsc:242`), so 45/hit = **3 hits to down** in the open. In the trench, melee adds a **flat +5 HP per layer** (and move **+4% per layer**) on top — L1 ≈50/hit up to L5 ≈70/hit — so the deeper you descend the harder and faster they hit; the lethality ramps with depth (user 2026-06-21; melee-add history 6 → 5 → 4 user 2026-07-16 → **5** scare pass 2026-08-01).

### Bus Station = high-threat zone

`corp_zone` (the **Bus Station**, with the cross-room trench) is intentionally the densest spawn zone — somewhere players should *avoid* holding. It carries **14 `riser_location` structs** (vs 4 in the market/alley/vault/roof zones; start and lab carry more), 7 on each side of the trench (floor rows y=1548 / y=2348), so when players are in the Bus Station zombies pour in from both sides far faster than elsewhere. Risers are in `map_source/zm/zm_abandoned_cyber_city.map` (`targetname corp_zone_spawners`). Adding/removing risers there retunes the density (LED-bake-gated — point entities, low risk, but still re-run the bake).

## Co-op Scaling

- Regular zombies: +20% HP per extra player (user 2026-06-24, was +100%) — `regular_hp_mult()`, applied to every
  factory zombie by the `level.zombie_init_done` hook (`_acc_coop_scaling.gsc`).
- **Elites/mini-bosses: a clean multiple of a *co-op-scaled* zombie — i.e. they inherit the regular +20%/player
  and nothing more.** Shielded = 4×, Glitch Stalker = 1.5×, Apothicon Fury = 12×, at **any** player count.
  `special_hp_mult()` (+50%/extra player) is defined in `_acc_coop_scaling.gsc` but **no live elite uses it** —
  stacking it on a base that already carries `regular_hp_mult()` **double-counts co-op** (it once made a 2p
  Shielded ~4.5× a 2p zombie instead of a clean 4×), which is why `_acc_elites.gsc:311-318` explicitly forbids it.
  *Do not "fix" an elite by adding `special_hp_mult()`.*
  - The two ways to get this right, and when each applies: a **promoted factory zombie** (Shielded, Glitch) gets
    the mult for free — multiply its **post-init `maxhealth`**, never `level.zombie_health`. A **`SpawnActor`'d
    actor** (Apothicon Fury) never runs `zombie_spawn_init`, so the hook never fires — it must multiply
    `level.zombie_health × regular_hp_mult()` **by hand**.
  - **Why this class of bug hides:** at 1p `regular_hp_mult()` is exactly **1.0**, so `level.zombie_health` and a
    post-init `maxhealth` are identical in every solo test — and solo is the whole dev/test loop. Both the Glitch
    Stalker and the Fury shipped reading the solo field and were only caught by audit (2026-07-15). Any new
    special that scales off "the round's zombie health" must state which of the two bases it uses.
- Spawn rate: a custom **+30% per extra player** spawn-count multiplier (1p 1.0 / 2p 1.3 / 3p 1.6 / 4p 1.9), applied via `acc_coop_max_zombie_override` (`spawn_rate_mult` = 1 + 0.3×(players−1)). Riot-shield elites (round-based) + glitch rounds add enemies separately.
- Shard drops from elites go to the **killing player**.
- Boss shard drops go to **every player independently** (intentional; 4p co-op = 4× the boss shard amount per kill, not split).

See [03_progression_and_skills.md](03_progression_and_skills.md) for the full co-op scaling rationale.

## Sound / VFX Budget Notes

Audio/VFX polish targets (not all built yet), documented here so we don't forget: <!-- TODO(acc-verify): which of these cues are wired in sound/aliases is not confirmed -->


- The Shielded elite must be **audibly distinguishable offscreen** — a metallic *clank*. (Shielded is the only elite; the removed Teleporter/EMP cues are gone.)
- Mini-boss has a pre-spawn siren + ground rumble so players know to reposition before they're on top of you.
- The boss spawn venue (Lab) gets a looping low-frequency drone while a boss fight is active; silence when not, for contrast.

## Design Notes

- **Why one elite, not several?** The Shielded is the only elite (Teleporter + EMP were removed 2026-06-22). One class with a clear front-armor counter-play loop keeps the "I know how to fight this" muscle memory sharp; the blink/flank fantasy the old Teleporter carried now lives in the Glitch Stalker mini-boss.
- **Boss rounds (user 2026-07-03; 3-boss pool 2026-07-04; 4-boss pool 2026-07-08):** a boss ROUND lands **every 9 rounds from round 9** (9, 18, 27, … — dev builds run the same real schedule since 2026-07-12; `acc_boss_first_round` / `acc_boss_interval` remain live overrides for a manual fast burst), and the COUNT scales with the slot — **round 9 = 1 boss, 18 = 2, 27 = 3, …** (slot+1). The types are dealt from a **shuffled 4-type deck WITHOUT replacement — Phantom / Rogue Protector / Avogadro / Panzer** (no-duplicate guard, user 2026-07-08: the old independent per-slot roll could double a type as early as round 18) — so rounds with up to 4 bosses are always **all-distinct types**, and a repeat first becomes possible at the **forced 5th slot (round 45)**, where the deck reshuffles. Boss music holds until **every** boss that round is dead. All four scale HP off the SHARED `scale_phantom_hp` scale (base 65k, **anchor round 5** — user 2026-07-08, was 10; they first spawn at round 9 = base × exp^4), differing only by exponent — **Panzer 1.09 > Rogue Protector 1.08 > Phantom/Avogadro 1.06** (2026-07-26 −0.01 all-boss health nerf; before it, the 2026-07-25 retune had Panzer 1.10 / Rogue 1.09 / Phantom-Avo 1.07); Brutus (the Trench Warden — a separate power-on-then-respawn-3-rounds-after-each-kill cadence, *not* part of this roster) tops the ladder alone at 1.11 (on 2026-07-08 the anchor moved 10 → 5 and then all three exponents were trimmed 0.02 — Brutus/Panzer 1.14→1.12, Rogue 1.11→1.09, Phantom 1.08→1.06). A disabled type re-homes its rolled slots to the Rogue Protector so the round's boss count never shrinks (dev builds run the full roster on the real cadence — the per-module repeating test-loops were removed). Owner: `_acc_civil_protector` (shared roster, `level.acc_boss_roster_fn`); each of the four modules spawns its own type via a debt-based director. Multiple bosses (of any type) can be alive at once — **spawn de-stacking**: each type has its own anchor (Phantom: promoted-zombie spawn, RP: Plaza chest spot, Avogadro: Lab, Panzer: Plaza riser), directors trickle one spawn per ~3s tick, the Panzer additionally navmesh-scatters with 150u boss clearance, and every boss carries the shared flags so no entrance AoE can kill a sibling.
- **No Lab-seal.** Current boss rounds do NOT seal the arena — the old "seal the Lab" commitment check belonged to the removed Subroutine Core fight (2026-06-22). Boss rounds run alongside the wave; you can still move.

## Out of Scope (v1.0)

- Random "special event" enemy rounds (Hellhounds/dogs). Stock BO3 enables these by default (`zm_usermap::main` DEFAULTs `level.dog_rounds_allowed = 1`); we **disable them entirely** (`level.dog_rounds_allowed = 0` before `zm_usermap::main()` in `zm_abandoned_cyber_city.gsc`, 2026-06-18) and rely on our elite + Brutus cadence. The orphan `dog_location` structs in the `.map` are inert.
- Per-run elite-class randomization. Moot now that the Shielded is the only elite; kept as a note in case future elites return.

(Since shipped, the roster grew well past the original v1.0 scope: the **Glitch Stalker** mini-boss and the **Rogue Protector / Avogadro / Panzer** full bosses — all documented above.)
