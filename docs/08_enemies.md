# 08 - Enemies

The bestiary: regular zombies, the Shielded elite, the Glitch Stalker mini-boss, the boss-round roster (The Phantom / Rogue Protector / Avogadro / Panzer, rolled every 9 rounds from r9), plus the Trench Warden and NSZ Brutus. Design principles for difficulty and how enemies tie back into the Data Shard and Overclock loops (the Cyberware tree is dormant — see the Regular Zombie note).

Weapons are in a separate doc: [04_weapons.md](04_weapons.md).

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
- **Value in the loop**: drives Point economy, keeps pressure up, triggers AoE Overclocks. (The Cyberware skill tree is **dormant** — gated off behind `acc_cyberware_on` (default 0), `_acc_cyberware.gsc::init()`; the live weapon-upgrade path is the **Overclock terminal** (`_acc_overclocks.gsc`).)
- **HP scaling delta vs stock**: +1 effective round (start at 150 HP instead of 130, same per-round ramp). See [03_progression_and_skills.md](03_progression_and_skills.md).
- **Speed curve** (`_acc_zombie_speed.gsc` — replaced the old Rampage Inducer): zombies get faster **every round**, with a **natural gait** (never slow-motion). The BO3 engine has no continuous "move at X% speed" knob for zombies — movement is root-motion / animation-driven, so the only levers are the discrete gait **tier** (walk/run/sprint, each a real animation whose baked gait *is* its ground speed) and the animation **playback rate** (which scales cadence *and* ground speed together, so a rate below 1.0 looks like literal slow-motion — it is the Widow's Wine slow mechanism). So "slower than max" comes from a slower **gait**, not a slowed animation:
  - **Rounds 1–14:** the **run** gait (a natural jog) at playback rate ≥ 1.0, starting at **101.3%** (`acc_zspeed_jog_start_pct`) and creeping up `acc_zspeed_jog_step_pct` (0.65%) per round. The jog's intrinsic speed is the "slow start" (~70–80% of max — baked into the xanim, so it's approximate, not a dialled percentage). (user 2026-06-23: jog phase extended for a gentler early-round ramp; step cut to 0.65% so the jog never outpaces the real sprint.)
  - **Round 15** (`acc_zspeed_sprint_round`; **user 2026-07-09: whole curve shifted 2 rounds EARLIER** — was 17; every round now runs the old curve's speed from 2 rounds later, and the 101.3% jog start is the same shift, keeping the R14→R15 sprint hand-off near-continuous at ~109.75%): zombies break into the full **sprint** gait at rate 1.0 = base-game max — a deliberate, natural escalation. sprint@1.0 clears the topped-out jog, so the wave still steps **up** (strictly monotonic).
  - **Round > 15:** sprint gait, rate `1.0 + 0.5%·(round−15)` (`acc_zspeed_sprint_step_pct`, cut from 1% — user 2026-06-24, gentler post-sprint creep) — a faster sprint (rate > 1.0 reads fine, no slow-mo). No upper clamp (R20 = 1.025, R25 = 1.05).
  The playback rate is **floored at 1.0** in code, so the wave never animates below natural cadence. The "sprint" run modifier (`acc_mod_force_sprint`) forces the sprint gait on every round. Tunable live via the `acc_zspeed_*` dvars — see [22_flags_reference.md](22_flags_reference.md).
  - *Footgun — two abandoned attempts, kept as warnings:* (1) a walk→run→sprint-**by-round** variant with `rate = target% ÷ category_base%` dipped at each tier up-shift (the per-tier baked speeds are unknowable from data) → read as "slowing down per round." (2) A **sprint-locked** variant scaling `ASMSetAnimationRate` to an exact target % *below 1.0* produced the correct ground speed but a **slow-motion** sprint gait → "slomo running." Deep research (2026-06-15) confirmed there is **no script lever** for continuous speed at natural cadence (`SetMoveSpeedScale` is player-only; `moveplaybackrate` / `animtranslationScale` are dead/death-only). The natural-gait model above is the resolution: exact percentages are traded away for a correct-looking, monotonic ramp.

### Elite: Shielded ("Riot") — the ONLY elite (Teleporter + EMP removed, user 2026-06-22)

- **Spawn (user 2026-06-22)**: a **"shield round" every 4 rounds from round 4** (r4, r8, r12, …); the **count that round = the round number ÷ 2** (r4 → 2 shields, r8 → 4, r12 → 6, r20 → 10 …), spread ~3 s apart across the round (`acc_shielded_spacing`). Other rounds spawn zero elites. High-round caveat: the 50-AI cap (`ACC_AI_LIMIT`) throttles how many are concurrently alive.
- **Depth-scaled ratio (user 2026-06-25)**: ADDITIONALLY, in the **abyss** a depth-based share of *every* zombie spawns Shielded — **deeper = more**: **L2 10% · L3 15% · L4 22% · L5 30%** (surface + L1 pit = 0; the shield rounds above still cover those). Per-zombie roll on `zombie_init_done` (chained after coop_scaling so HP is already scaled), keyed by `acc_bus_trench::underground_layer(origin)`. Live dvars `acc_shielded_pct_l2..l5`. `promote_to_shielded` has a re-entrancy guard so a shield-round + depth-roll can't double-promote. `_acc_elites::acc_depth_shielded_roll` / `depth_shielded_pct`.
- **HP**: **4× a normal zombie's current health, at ANY player count** (user 2026-07-04: 5× → 4×, "5× is too much"). A **flat ×4** — it tracks the normal zombie's co-op scaling, NOT a separate elite curve. (Do **not** stack `special_hp_mult()` on top: by promote time the base HP already carries the regular +20%/player co-op mult, so multiplying the elite curve double-counts co-op — that earlier made a 2-player Shielded read ~4.5× a 2p zombie instead of a clean multiple.)
- **Movement**: a heavy **WALK** — roughly half the pace of the round's normal (jogging) zombies, a lumbering armoured brute. Uses the natural `walk` run cycle at full cadence, **not** the run gait at 0.5× rate (that read as slow-motion — `<1.0` anim rate is always slow-mo; user 2026-06-22 "why does it move so slow"). `_acc_elites::shielded_speed_think`; tune via `acc_shielded_walk_rate` (**default 1.2** = a bit faster than the natural walk, user 2026-06-24; 1.0 = natural, raise for faster); `acc_boss_custom_speed` opt-out; NO `SetScale`. Trade-off: it's the walk's natural pace, not a math-exact 50% — at high sprint rounds it reads slower-than-half; bump the rate if needed.
- **Behavior**: front-facing armor. Damage to the front quarter (90° arc) = 25% through — *unless* your gun's Overclock pierces it (below). Flank or break the shield with sustained fire.
- **Read**: rocket-shield world model bolted on its back (front-armoured silhouette).
- **Counter-play**: flanking (Reflex builds excel), grenades / explosives (always bypass), melee from the side, and the **Overclock Shield-Pierce** effect (4/4) — a gun's OC tier *partially* punches through the front armor: each tier restores a bit of the blocked damage, taking the front from **25% (T0) up to 55% at Tier 10** (`acc_oc_pierce_per_tier`, default 0.04/tier; `_acc_damage.gsc` effect 4/4). It's a **partial** pierce, never a full bypass, so flanking / explosives / side-melee always help. It's slow — kite it.
- **GSC**: `_acc_elites::promote_to_shielded()`.

### Elite: Teleporter ("Blink") — REMOVED (user 2026-06-22)

> No longer spawns. `pick_elite_class_for_round` returns only `"shielded"`; `promote_to_teleporter` + `teleporter_ability_loop` remain defined but unreachable (kept for trivial restore). The Glitch Stalker still carries the blink/flank fantasy this elite originated.

### Elite: EMP ("Surge") — REMOVED (user 2026-06-22)

> No longer spawns. `promote_to_emp` + the on-hit point-drain / Cyberware-lockout debuff (`apply_emp_melee_debuff`, the `acc_emp_on_hit` branch in `on_player_damaged`) remain defined but unreachable — `acc_emp_on_hit` is never set, so the debuff never fires. (The trench-melee + Exo-resist logic in `on_player_damaged` is untouched.)

### Mini-Boss: Brutus — the "Trench Warden"

> **Implemented as Brutus** (NSZ pack) — the old "Juggernaut Host / 500k-HP / Vibro-Cleaver-countered" design was never built; this is the real enemy. **Spawn cadence (user 2026-06-18): FIRST appears when the Bus Station POWER is turned on** (`_acc_boss::brutus_power_watch` — was a fixed round 4), then **respawns 3 rounds after each kill** (`acc_brutus_respawn_interval`, was every 5). Runs alongside the wave (`ignore_enemy_count`), drops a boss item + Mega Bottle. **HP (user 2026-07-04): the TOP tier of the UNIFIED boss scale.** All bosses now share the **same base (65k, user 2026-07-05) + anchor (round 5, user 2026-07-08: was 10)**, differing ONLY by per-round exponent: **Brutus 1.12 > Rogue Protector/Panzer 1.09 > Phantom 1.06** (user 2026-07-08: after moving the anchor to r5, all three exponents were trimmed 0.02 — Brutus/Panzer 1.14→1.12, Rogue 1.11→1.09, Phantom 1.08→1.06). So Brutus = **65k × 1.12^(round−5)**, **NO cap** (`acc_boss_mini_hp` / `acc_boss_mini_hp_exp` / `acc_boss_mini_hp_anchor`), e.g. solo **r5 65k → r10 115k → r20 356k → r30 1.11M → r40 3.43M**. (He debuts at power-on & round ≥ 5, so his FIRST appearance is exactly the 65k base and every round after compounds — scaling now starts at round 5, not 10.) Brutus stays the tankiest (the Panzer later settled at the Rogue tier, 1.09 — user 2026-07-08 final). (The NSZ pack's old linear `3500×round` / 85k-cap HP is dead — overwritten every spawn.) That round-scaled base is then × a **logarithmic co-op multiplier** (`boss_hp_player_mult`: ×1 / 1.5 / 1.79 / 2.0 for 1–4 players). PLANNED: tether it to **roam the Bus Station (corp_zone) trench** as a true "warden."

- **Drops (unified boss reward, user 2026-07-05 — EVERY boss identical)**: `grant_unified_boss_reward()` grants, to **every player**, a **guaranteed** challenge item (dupes auto-convert to Data Shards; see [09_boss_items.md](09_boss_items.md)) + **1 Empty Mega Bottle** + `round × 180` points (`acc_boss_score_per_round`) + `int(round / 3)` Data Shards (`acc_boss_shards_round_div`). Mega Bottles upgrade owned perks to their Mega variant at the Lab machines — see [10_perks.md](10_perks.md#mega-bottles-system). (The Paradise-fight Brutus is a survive-the-threat spawn and grants nothing.)
- **Read**: oversized cyber-zombie silhouette, pre-charge wind-up animation, distinctive ground-rumble audio.
- **GSC**: `_acc_boss_brutus.gsc` / `_acc_boss.gsc` (`brutus_power_watch` cadence). Runs on the NSZ Brutus pack.

### Mini-Boss: "Glitch Stalker" (round 4+, every 2nd round)

- **Spawn (user 2026-06-23, difficulty cut)**: from **round 4, every 2nd round** (`ACC_GLITCH_FIRST_ROUND_DEF 4`, `ACC_GLITCH_INTERVAL_DEF 2` → r4, 6, 8, 10, …; was every round from r2), **alongside** the normal wave (does not replace it, does not gate round end — `ignore_enemy_count`). The **per-wave count steps up by 1 each spawn round**: `floor((round-2)/2)` (`glitch_count_for_round`, user 2026-06-23 dropped the +1 so it starts at 1; the old fixed `acc_glitch_count` is superseded) — so r4 = 1, r6 = 2, r8 = 3, r10 = 4, ….
- **Source**: script-only — a promoted stock zombie (the `spawn_subroutine_core` scaffold, a legacy code name inherited from the removed full boss — see the note below), re-skinned at runtime to the **stock Giant zombie body + head** (SetModel + head Detach/Attach; both stock xmodels, no external pack).
- **HP**: **1.5× the round's normal zombie health** (`acc_glitch_hp_mult`, default 1.5; user 2026-06-23, was 3×) — auto-scales with the round, no separate curve.
- **Behavior**: chases at **~15% faster** than the round's normal zombies (`acc_glitch_speed_mult`) and every **1.33–2.22s teleport-blinks** to flank the nearest player (navmesh-clamped, reusing the Teleporter elite's verified path; blink cadence doubled 2026-06-15 — blinks 2× more often). For ~1.2s right after each blink it is **vulnerable** and takes **2× damage** — the fight rewards punishing the recovery window, not out-DPS-ing a sponge.
- **Melee damage**: deals **−55%** melee damage to players vs a stock zombie (`acc_glitch_melee_dmg_mult` **0.45**, user 2026-06-22 — 25% lower than the prior 0.6) — a fast, frequent-blinking harasser, not a heavy hitter.
- **Read**: it wears the **stock ("Giant") zombie skin** (body + head, `acc_glitch_stock_skin`) so it stands out from the charred horde, plus **teal eyes** (`acc_glitch_teal_eyes`, user 2026-06-17 — a client eyeball-material recolour, **no FX asset**; colour/luminance live-tunable via `acc_glitch_eye_color` / `acc_glitch_eye_lum`) — **no health bar, no over-head marker**; the skin + eyes are the only tells. After each blink it now **vanishes, physically charges toward the nearest player while hidden** (navmesh-clamped, `acc_glitch_charge_speed`), and only rematerialises once the AI has resumed moving (`Ghost`/`Show`, render-only, stays hittable, capped by `acc_glitch_phasein_max`, `acc_glitch_fx`) — so it reappears already on top of you, never frozen in the open mid-blink (exaggerated anti-standstill fix, user 2026-06-17). (A 75% size was considered but dropped — `SetScale` on a live zombie AI is the confirmed `0xC0000005` crasher; would need a pre-scaled model.)
- **Data Shard / Item / Mega Bottle drop**: as a FREQUENT mini-boss (1–3 per spawn round) it **no longer drops boss items or Mega Bottles** (those stay exclusive to the rare bosses, user 2026-06-22) — instead the **killer gets exactly 1 Data Shard**.
- **Counter-play**: don't chase it — hold an angle and burst it during the post-blink window.
- **GSC**: `_acc_boss_glitch.gsc` (self-contained: own cadence, spawn, blink, death/reward). Fully dvar-tunable — see [22_flags_reference.md](22_flags_reference.md#glitch-stalker-mini-boss-tuning). Toggle with `acc_glitch_enable`; trace with `acc_glitch_debug 1`.

### Full Boss: "Avogadro" — the Cyberhacker (user 2026-07-04)

A **non-lethal, super-annoying** electric harasser. Dick_Nixon's BO2 Avogadro model (a floating lightning apparition) reframed as a rogue-AI netrunner. His whole threat is **stun-locking you and knocking the Lab's utilities offline** — not damage.

- **Spawn**: **always in the Lab** (`struct::get("acc_boss_spawn")` @ (19,3648,0)), where all five target machines sit. Joins the shared boss roster as a **3rd type** (now a 4-boss pool: Phantom / Rogue Protector / Avogadro / Panzer, no-duplicate deck deal every 9 rounds from r9). DEV mode runs a repeating Lab test-spawn.
- **HP**: **exactly the Phantom's** — the shared `scale_phantom_hp` scale (65k base, anchor 5, exp 1.06) × the log co-op multiplier. Killable by guns (his BO2 bullet-immunity was removed).
- **Movement**: the **run** gait (`acc_avo_gait`) at **1.15× anim playback** (`acc_avo_anim_rate`; user 2026-07-06 ladder: 1× too slow → 2× way too fast → 1.5× still out-speeds the player → 1.2× a bit slower → 1.15×. **Intent: an un-slowed player outruns him; the 30% zap slow is what closes the gap.** `ASMSetAnimationRate` persists and is boss-safe — it's the run-cycle *override* that froze Brutus, not the rate call). He seeks the nearest enabled machine to hack (navmesh-projected goal, sticky until arrival/timeout), falling back to chasing the nearest player when there's no reachable machine or he's at his hack cap.
- **Attack — the stun IS the threat** (reworked 2026-07-06 so anim + SFX + bolt + stun are ONE synced event): the pack **behavior tree plays his throw animation** (enemy 150–2000 u away + line of sight), whose anim notetrack (`avo_send_bolt`, frame 20) launches a **visible electric bolt projectile** (script_model carrying his crackling `avogadro_fx` linger FX) that flies at the target (`acc_avo_bolt_speed` 1100 u/s, slight lead) and applies the **30% boss slow + 5 damage on impact** (`_acc_elites::acc_avogadro_zap` + `acc_avo_shot_damage`; user 2026-07-06 ladder: pure-stun 0 → 1 → 5; the hit also plays the stock electric shellshock/overlay tell, `acc_avo_shock_sec` 0.75 s) to everyone within `acc_avo_bolt_hit_radius` (130 u) — **step aside and it misses**. **Presentation (2026-07-06, "hard to see the projectile")**: the bolt rides its own `acc_avo_bolt_fx` clientfield — the `.csc` stacks his crackle-cloud FX **plus** the bright tesla arc on the mover, and plays the throw bark at launch / warp-out fizzle at impact **client-side, positionally at the bolt** (server `PlaySound` on AI actors is dead in this build — nameplate precedent), so audio is frame-locked to the visual; speed 1100→**900 u/s** and min flight time 0.15→**0.25 s** so even close throws render across client snapshots. Cadence `acc_avo_bolt_cd` (0.75 s; the pack's hardcoded 20 s cooldown was replaced, and its ±50 u facing-rect LOS gate dropped — playtests starved on both). **Point-blank** (inside the bolt's 150 u minimum) an **aura zap** (`acc_avo_fire_interval` 0.5 s, ≤`acc_avo_aura_range` 220 u, same slow + `acc_avo_aura_damage` 5) keeps the stun-lock on players hugging him, preferring un-stunned targets to spread the slow. A **watchdog** logs (and direct-zap fallbacks) only if the BT bolt starves on a bug — hiding without LOS is legit counterplay. **Mega Electric Cherry** softens the slow to **−10%** (and if he's hacked your EC off, that softening naturally stops). No melee, no damaging bolt.
- **2026-07-06 bug-fix trio** (playtest: "never walks / no bolt / doesn't hack"): the pack BT gated the bolt on an **unregistered** `ShouldDopunchAttack` condition — the bolt branch could never run, and since both the move and idle branches require `avoShouldShootBolt` to be false, the boss **froze in place** whenever the bolt wanted to fire (typically the moment a player engaged at mid-range). A stub registration (`false`) unblocks both. Additionally the target service now maintains `.enemy` even while machine-seeking (it used to early-return, starving the bolt condition and `OrientMode("face enemy")`).
- **2026-07-06 round 2** (diagnostics-guided): machine seek goals were the vending-machine **entity origin — inside the machine at z=60, off the navmesh** — so `SetGoal` silently failed and he stood still all game and never hacked; all cached targets are now **navmesh-projected** (`GetClosestPointOnNavMesh`, the Brutus recipe). The seek is **sticky** (commits to one machine until arrival/timeout; the old nearest-re-pick + 8 s blacklist ping-ponged two machines forever, starving the player-chase fallback), a timeout blacklists 30 s and opens a 12 s chase window, and player chase is the BT service's **entity** goal.
- **Signature — hacks machines**: walks up to the nearest enabled machine (**perks prioritized** over PaP) and **disables it for 30 s**; **max 2 at once PER Avogadro**. **Full-disable contract (user 2026-07-06 — "check all cases")**: the base perk stops working for **all** players (`zm_perks::perk_pause`), the machine **can't be bought** (`TriggerEnable(false)` on every trigger of that specialty, both dimensions), its **glow goes dark** (`acc_perk_lights::set_glow 0`), **and every Mega live effect drops with it** — `owns_or_paused` reads an avo-hacked perk as not-owned (Spiderman mobility/spider drops, Power Surge softening, boss-special/EMP immunity), and Ultimate Tank's +50 (plus Jugg's own +150 HP) and The Flash's +15% speed are recomputed away for the window (`_acc_mega_bottles::on_perk_hacked/on_perk_restored`); **PaP** can't pack while hacked. Targets (2026-07-06, Stamin-Up added): **Pack-a-Punch, Juggernog, Quick Revive, Stamin-Up, Electric Cherry, Widow's Wine**. A hack restores after 30 s, when **that** Avogadro dies (each restores only its own), or when the **last** Avogadro dies (a belt-and-suspenders force-restore — a perk can never stay stuck off). **Two simultaneous Avogadros — together disabling up to 4 of the 5 hackable perks (the 2-machine cap is per-boss) — first become possible at round 45**, when the no-duplicate roster deck (2026-07-08) is forced to repeat a type (or earlier only via disabled-type re-homing, which re-homes to the Rogue Protector, not him).
- **Counter-play**: he's fragile relative to the disruption — burn him down fast to get your perks/PaP back, or ride out the 30 s. He's deliberately **weak to melee**: a knife does **1/100 of his max HP**, so **exactly 100 knives kill him at any round** (`acc_avo_knife_hits`) — a high-risk close-range counter, since getting in his face means eating the stun-lock. Kill him and everything he disabled comes back at once.
- **Drops**: standard boss tier — a guaranteed challenge item + 1 Empty Mega Bottle + Data Shards to every player.
- **GSC**: `_acc_boss_avogadro.gsc` (drives the pack AI in `_zm_ai_avogadro.gsc`). Fully dvar-tunable — see [22_flags_reference.md](22_flags_reference.md). Toggle with `acc_avo_enable`; trace with `acc_avo_debug 1`.

### Full Boss: "Panzer" (user 2026-07-08 — renamed from "Panzer Soldat" same day — rebuilt; previously live 2026-06-19)

The literal Der Eisendrache Panzer chassis (Spiki asset-dump mechz port) — the roster's heavy
walker: hardest melee in the pool, Rogue-Protector-tier HP.

- **Spawn**: **always the Plaza** (outside — he's huge) at his **own anchor, the central Plaza riser
  `(-227.5, 350, 0)`** (the proven 2026-06-19 spot), deliberately ~600u from the Rogue Protector's
  chest-spot anchor so two bosses never share a doorstep. A **navmesh ring query with 150u
  boss-clearance** (`pick_spawn_point`) scatters multi-boss-round spawns so a second Panzer (or a
  wandering RP) is dodged, not stacked. Joins the shared roster as the **4th type** (no-duplicate
  deck deal). DEV keeps one alive from round 2 (his roster slots re-home, the Avogadro rule).
- **Movement + zap**: run gait at **1.09× anim playback** (`acc_panzer_anim_rate`; user ladder
  2.0 "buggy fast" → 1.15 → 1.1 → **1.09** final — lumbers just under the Avogadro's 1.15). His
  **zap grenades explode on impact** (`electroball_watch` detonates on first bounce) and apply
  the SHARED boss zap slow (`acc_protector_zap`: 3s refreshing window, Battery item absorbs,
  Power Surge softens) to everyone in the 200u blast (`acc_panzer_zap_radius`).
- **HP (the Rogue Protector tier — user 2026-07-08 final: "match the RP")**: shared 65k/anchor-5 scale with exponent **1.09**
  (`acc_panzer_hp_exp`; the tuning ladder walked 1.12 → 1.13 → 1.14 → 1.12 → **1.09** after
  the anchor moved to r5) × the log co-op multiplier — the full ladder is **Brutus 1.12 > Rogue Protector = Panzer 1.09 >
  Phantom/Avogadro 1.06**. Solo (anchor 5, exp 1.09) r5 65k → r10 100k → r20 237k → r30 561k → r40 1.33M.
- **Attacks**: stock mechz BT — flamethrower sweeps, 115-grenade volleys, and a **very hard melee**
  (`acc_panzer_melee_damage`, default **90** — nearly a one-hit down without Jugg; the pack's original
  dead value was an instadown 150). Claw-grapple is **deliberately OFF** (broken-as-decompiled +
  inescapable in the Origins variant; requires targetname "mechz_tomb" we never set). Armor plates
  track their own part health server-side but read as **solid armor** (detach visuals are DLC1-gated).
- **THE historical crash, fixed**: every prior attempt CTD'd "when he attacks or is attacked" — stock
  `mechz.gsc` registers the `mechz_face` clientfield at VERSION_SHIP **server-side only** and sets it
  on every idle/attack/pain/death → layout desync. Fix (proven in-game 2026-06-19): no-op rebind of
  the 4 face StartFunctions (last-write-wins `BT_REGISTER_API`) + 2026-07-08 belt-and-braces: the
  vendored `.csc` mirror-registers all 11 stock server-side mechz fields. Full fix ledger: the
  `scripts/zm/mechz_spiki.gsc` / `.csc` headers.
- **Drops**: standard boss tier — a guaranteed challenge item + 1 Empty Mega Bottle + round-scaled
  points + Data Shards to every player.
- **GSC**: `_acc_boss_panzer.gsc` (drives the vendored `scripts/zm/mechz_spiki.gsc/.csc`). Toggle with
  `acc_panzer_enable`; trace with `acc_panzer_debug 1`; spawn nudge via `acc_panzer_spawn_*`.
  **Assets**: Spiki dump modme #3087 (external, gitignored; manifest marker
  `source_data\mechz_spiki.gdt`, links in `tools/_panzer_stash/README.md`).

### Full Boss: "Subroutine Core" — REMOVED (user 2026-06-22)

> The legacy Subroutine Core full boss (a pinned Lab fight at rounds 30/40/50 with phase-transition power/perk debuffs) was **removed 2026-06-22**; boss rounds are now the every-9-rounds roster above. `run_full_boss` / `spawn_subroutine_core` remain defined-but-unreachable dead code in `_acc_boss.gsc` (the `spawn_subroutine_core` scaffold is now reused by the Glitch Stalker). The full removed design lives in CHANGELOG.md (2026-06-22).

## Elite Spawn Timing (pacing, not randomness)

Stock BO3 leaves elite timing to spawn RNG. We don't. See [05_mechanics.md](05_mechanics.md) for the full model; summary:

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

Source: `_acc_elites.gsc::elite_quota_for_round()` (returns `round / 2` on `round % 4 == 0 && round >= 4`, else 0). Spawned across the round on a **3 s** timer (`acc_shielded_spacing`, was 38 s — the batch is much larger now). At high rounds the 50-AI cap (`ACC_AI_LIMIT`) throttles concurrently-live shields, so the *spawned* count can trail the nominal target.

## Spawn Intensity (Moderate tune, 2026-06-18)

The map otherwise runs stock round spawning; this is the "Moderate" intensity pass — denser and faster, still under the netcode-cautioned ceiling. All hardcoded constants (no dvars). See memory `spawn-intensity-moderate-tune`.

| Lever | Controls | Value (stock → ours) | Where |
|---|---|---|---|
| Concurrent AI limit | live zombies on screen | 24 → **50** | `_acc_main.gsc` `ACC_AI_LIMIT` (engine hard cap = 64) |
| Actor limit | live + corpses | 31 → **56** | `_acc_main.gsc` `ACC_ACTOR_LIMIT` (small headroom; corpses deleted on death) |
| Corpse linger | body stays after death | 5s → **0 (delete on death)** | `_acc_corpse_cleanup.gsc` `acc_corpse_linger_sec` — frees the actor slot so the 50 cap refills |
| Spawn-delay mult | time between spawns (wave fill speed) | ×1.0 → **×0.85** (0.1 s floor) | `_acc_main.gsc` `ACC_SPAWN_DELAY_MULT` (chains `level.func_get_zombie_spawn_delay`) |
| Early-round count | r1 / r2-4 spawn mult | ×1.40/×1.35 → **×1.50/×1.45** | `_acc_early_round_pacing.gsc` |
| Elite spacing | seconds between elite spawns | 45 → **3 s** (`acc_shielded_spacing`, default 3.0) | `_acc_elites.gsc:200` |
| Co-op spawn rate | per extra player | **+30%** (unchanged) | `_acc_coop_scaling.gsc` |
| Regular-zombie melee | damage per hit to player | 60 → **45** HP (baseline) | `_acc_zombie_speed.gsc` `ACC_ZOMBIE_MELEE_BASE_DEF` / dvar `acc_zombie_melee_base` |
| Trench melee (per layer) | damage per hit while in the trench | **+6 HP per layer** on the incoming hit (L1 ≈51, L2 ≈57, … L5 ≈75) | `_acc_bus_trench.gsc` `trench_melee_scaled` / dvar `acc_trench_layer_dmg_add` |
| Trench move (per layer) | move speed while in the trench | baseline **+4% per layer** (anim-rate) | `_acc_zombie_speed.gsc` `apply_speed_for_round` / dvar `acc_trench_layer_speed_pct` |
| Trench health (per layer) | max health while in the trench (**stacks on top of** round + co-op HP) | **+30% per layer** (L1 +30% … L5 +150%; one-way, deepest layer reached) — final HP = (round curve × player-count mult) × (1 + layer × 30%), so player scaling AND trench difficulty both apply (user 2026-07-04) | `_acc_zombie_speed.gsc` `apply_trench_health` / dvar `acc_trench_layer_hp_pct` |

Melee values are re-asserted every speed sweep on non-boss zombies (bosses keep their own — Glitch Stalker stays ×0.45). Stock baseline was 60 (`_zm_spawner.gsc:358`, originally 45). Player health is **100** (gametype setting `playerMaxHealth`, `_globallogic_spawn.gsc:242`), so 45/hit = **3 hits to down** in the open. In the trench, melee adds a **flat +6 HP per layer** (and move **+4% per layer**) on top — L1 ≈51/hit up to L5 ≈75/hit — so the deeper you descend the harder and faster they hit; the lethality ramps with depth (user 2026-06-21).

### Bus Station = high-threat zone

`corp_zone` (the **Bus Station**, with the cross-room trench) is intentionally the densest spawn zone — somewhere players should *avoid* holding. It carries **14 `riser_location` structs** (vs 4 in every other zone), 7 on each side of the trench (floor rows y=1548 / y=2348), so when players are in the Bus Station zombies pour in from both sides far faster than elsewhere. Risers are in `map_source/zm/zm_abandoned_cyber_city.map` (`targetname corp_zone_spawners`). Adding/removing risers there retunes the density (LED-bake-gated — point entities, low risk, but still re-run the bake).

## Co-op Scaling

- Regular zombies: +20% HP per extra player (user 2026-06-24, was +100%).
- Elites: +50% HP per extra player (flatter so duos don't blender them).
- Spawn rate: **base game** (stock per-player scaling); no custom multiplier. Riot-shield elites (round-based) + glitch rounds add enemies separately.
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
- **Boss rounds (user 2026-07-03; 3-boss pool 2026-07-04; 4-boss pool 2026-07-08):** a boss ROUND lands **every 9 rounds from round 9** (9, 18, 27, …; dev: every 3 from round 3), and the COUNT scales with the slot — **round 9 = 1 boss, 18 = 2, 27 = 3, …** (slot+1). The types are dealt from a **shuffled 4-type deck WITHOUT replacement — Phantom / Rogue Protector / Avogadro / Panzer** (no-duplicate guard, user 2026-07-08: the old independent per-slot roll could double a type as early as round 18) — so rounds with up to 4 bosses are always **all-distinct types**, and a repeat first becomes possible at the **forced 5th slot (round 45)**, where the deck reshuffles. Boss music holds until **every** boss that round is dead. All four scale HP off the SHARED `scale_phantom_hp` scale (base 65k, **anchor round 5** — user 2026-07-08, was 10; they first spawn at round 9 = base × exp^4), differing only by exponent — **Rogue Protector = Panzer 1.09 > Phantom/Avogadro 1.06** (Panzer matched to the RP, user 2026-07-08 final); Brutus (the Trench Warden — a separate power-on-then-respawn-3-rounds-after-each-kill cadence, *not* part of this roster) tops the ladder alone at 1.12 (on 2026-07-08 the anchor moved 10 → 5 and then all three exponents were trimmed 0.02 — Brutus/Panzer 1.14→1.12, Rogue 1.11→1.09, Phantom 1.08→1.06). A disabled type re-homes its rolled slots to the Rogue Protector so the round's boss count never shrinks — this is how DEV mode works too (Avogadro and the Panzer are re-homed in the roster and spawn instead via their own repeating test-loops). Owner: `_acc_civil_protector` (shared roster, `level.acc_boss_roster_fn`); each of the four modules spawns its own type via a debt-based director. Multiple bosses (of any type) can be alive at once — **spawn de-stacking**: each type has its own anchor (Phantom: promoted-zombie spawn, RP: Plaza chest spot, Avogadro: Lab, Panzer: Plaza riser), directors trickle one spawn per ~3s tick, the Panzer additionally navmesh-scatters with 150u boss clearance, and every boss carries the shared flags so no entrance AoE can kill a sibling.
- **No Lab-seal.** Current boss rounds do NOT seal the arena — the old "seal the Lab" commitment check belonged to the removed Subroutine Core fight (2026-06-22). Boss rounds run alongside the wave; you can still move.

## Out of Scope (v1.0)

- Random "special event" enemy rounds (Hellhounds/dogs). Stock BO3 enables these by default (`zm_usermap::main` DEFAULTs `level.dog_rounds_allowed = 1`); we **disable them entirely** (`level.dog_rounds_allowed = 0` before `zm_usermap::main()` in `zm_abandoned_cyber_city.gsc`, 2026-06-18) and rely on our elite + Brutus cadence. The orphan `dog_location` structs in the `.map` are inert.
- Per-run elite-class randomization. Moot now that the Shielded is the only elite; kept as a note in case future elites return.

(Since shipped, the roster grew well past the original v1.0 scope: the **Glitch Stalker** mini-boss and the **Rogue Protector / Avogadro / Panzer** full bosses — all documented above.)
