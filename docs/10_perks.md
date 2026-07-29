# 10 - Perks

Full roster, costs, **base + Mega** descriptions (table + prose), per-slot randomization, stacking behavior, and the baseline player-HP / zombie-damage model.

> **This is the single living reference for perks.** The **source of truth is the code** — `_acc_perks.gsc`, `_acc_perk_info.gsc`, `_acc_perk_doors.gsc`, `_acc_mega_bottles.gsc`, `_acc_damage.gsc`, `_acc_perk_phd_flopper.gsc`, `_acc_perk_electric_cherry.gsc`. Every number below is reconciled against it; when in doubt, grep the constant. (This doc absorbed the old `10_perks.md` at-a-glance list and the `21_adding_a_gun_runbook.md` rotating-machines TODO — both retired into here.)

## Player HP Baseline

### Stock *Black Ops III* (reference)

- **Without Jugger-Nog:** **3** regular zombie melee hits from full health → down [common BO3 zombies baseline].
- **With Jugger-Nog:** you down on the **5th** melee hit (i.e. **5** hits from full to bleedout — survive **4**, **5th** downs). Sources: [COD Wiki — Juggernog](https://callofduty.fandom.com/wiki/Juggernog) player-facing tables and community testing; *not* a literal “double” hit count vs no-Jug.

### This map (`zm_abandoned_cyber_city`) — authoritative targets

- **No perk:** **125 HP** → **3** hits to down. *(base health buffed 100 → 125, user 2026-07-16)*
- **Jugger-Nog:** **250 HP** → **6** hits to down (**+1** vs stock BO3 Jug's 5). *(unchanged — Jug add cut 150→125 to absorb the base buff)*
- **Ultimate Tank (Jug Mega):** **300 HP** → **7** hits to down. *(unchanged)*

Hit counts assume ~**45** damage per regular zombie melee hit (HP ÷ ~45 → 125=3rd, 250=6th, 300=7th). Open-field melee damage is a baked GDT value, so confirm the **3 / 6 / 7** counts in-game and retune the HP adds if they drift.

## Roster (10 perks)

Seven stock BO3 perks (retuned) + three custom (Deadshot, PhD Flopper, **Electric Cherry**). Players **start with 4 perk slots** and **buy more (up to all 10) with Data Shards** at the underground Neural Expansion Bay — see [Perk-Slot Rule](#perk-slot-rule--start-at-4-buy-more-with-data-shards-user-2026-06-19). **All 10 perks are live today.** (PhD Flopper rides the stock `specialty_electriccherry` pipeline; the **real Electric Cherry** is a from-scratch perk on `specialty_combat_efficiency` with the real cherry vending machine — `electric_cherry_model`, ported from the West Community Perk Collection 2026-07-01 — added 2026-06-25, its own Lab alcove.)

| # | Perk | Cost | Base (what it does) | Mega name | Mega (what the upgrade adds) |
|---:|---|---:|---|---|---|
| 1 | **Jugger-Nog** | 4,000 | **250 HP** → down on the **6th** zombie melee hit (no perk = 125 HP / 3rd). | **Ultimate Tank** | **300 HP** → down on the **7th** hit. *(The boss-zap protection now lives on Mega Electric Cherry "Power Surge" as a **−10% softening** — was Mega Jug → Mega Widow's → Mega Electric Cherry, user 2026-06-25; softened from full immunity 2026-07-03.)* |
| 2 | **Quick Revive** | 2,500 co-op / **500 solo** | Revive teammates in **2.0 s**; HP regen starts **20% sooner** after damage; solo self-revive (the 500 solo price is the stock BO3 self-revive cost). | **Savior** | Revive in **1.0 s**; regen starts **40% sooner**; **+15% move speed** while any other player is downed; **−50% damage taken while reviving**. |
| 3 | **Speed Cola** | 3,500 | **+50%** reload; faster **barrier board / repair**. | **Sleight of Hand Expert** | **+75%** reload (replaces +50%). |
| 4 | **Double Tap 2.0** | **3,000** | Fires **2 bullets per shot for 1 round of ammo** (double pellets on shotguns) **plus +33%** rate of fire. Extra-bullet damage tempered ×0.7 → ~**1.86× DPS**. Excludes Wonder Weapons / Ballistic Knife / explosives. | **Gun Slinger** | **Extra bullets hit harder** — temper eases ×0.7 → ×0.9 (~**2.39× DPS**). *No* fire-rate/swap bonus (twin removed 2026-07-04). |
| 5 | **Stamin-Up** | 2,000 | Sprint lasts **~12 s** (vs ~4 s no perk); **~4 s** stamina recharge; **+7–8%** move speed (mobility caps ~109%). | **The Flash** | **+15% sprint speed** (×1.15, uniform move scalar). |
| 6 | **Mule Kick** | **2,500** | Third primary weapon slot. | **The Armory** | **+20%** reserve ammo refilled each round (per gun); **all buys 10% cheaper**. |
| 7 | **Deadshot** | 3,500 | **+1.3** headshot bonus (additive); **no recoil change** (recoil is Mega-only); **ADS snap-to-head** (not on bosses). | **American Sniper** | **+1.5** headshot (replaces +1.3); **−50%** recoil (off the 1.75× map base → ~0.875× vanilla). |
| 8 | **Widow's Wine** | 4,000 | Web grenades (web un-killed zombies **8 s cocoon / 6 s slow** — stock 16/12 halved); self-defense webbing on hit (**50%** proc, stock 100%); webbing melee (**25%**, stock 50%); stock per-round grenade restock. **Base nerfed 50% all-around, user 2026-07-17** (`_acc_perks.gsc` `ACC_WW_*`). | **Spiderman** | **low-stance speed** (crouch ×2.6 / prone ×10 / downed ×15) + **boosted spider-drops**. *(One-hit melee REMOVED user 2026-06-29. Boss-special immunity MOVED to Mega Electric Cherry "Power Surge", user 2026-06-25. The custom 6-grenade pool + 4/round restock + WEB GRENADES HUD were REMOVED 2026-06-24 — web grenades use stock behavior now.)* |
| 9 | **PhD Flopper** | 2,500 | **Immune to fall damage and your own explosive / grenade / projectile splash**; **explode when you go down** (PhD-flavoured last-stand; orange `def_explosion` nova). *(Slide-to-explode is **Mega-only** since 2026-06-26.)* | **PhD Slider** | Adds **slide-to-explode** (Mega-exclusive) + a nova — radius **300→250u** (HALVED, user 2026-06-27), **≤10 zombies hit/slide** (`acc_phd_max_hits`), **10s→8s** cooldown; nova **damage FROZEN at round-16 zombie HP** (one slide one-shots trash ≤r16, then 2/3 slides past it; `acc_phd_freeze_round`); **1.75× slide speed**; **+15% explosive damage**. |
| 10 | **Electric Cherry** | 3,000 | **Reloading discharges an electric nova** that zaps nearby zombies — the **emptier the mag, the bigger the blast** (an empty-mag reload one-shots trash at any round); on a short cooldown. *(Custom from-scratch perk on `specialty_combat_efficiency`, real cherry machine `electric_cherry_model` (West pack port). No explode-on-down — PhD owns that.)* | **Power Surge** | **+50% damage, more targets (12), faster recharge (4 s** — user 2026-07-08, was 5 s**)** — the Mega's edge is damage/targets/cooldown, **not** blast size (the empty-mag radius is actually a touch tighter than base, by design: 200 vs 220). AND **boss zaps are softened** — any boss zap slow (Phantom chain / Rogue Protector / Avogadro) hits at **−10% instead of −30%** (was full immunity, softened 2026-07-03; the protection moved here from Mega Widow's Wine 2026-06-25). *(The **Battery** boss item fully absorbs boss zaps — +8% surge instead of any slow — superseding this softening for its holder, docs/09.)* |

**Sources (stock vs custom):** Perks **1–6 and 8** are stock BO3 machines (retuned — see table). **7** Deadshot, **9** PhD Flopper, and **10** Electric Cherry are **custom** (from-scratch abilities — not stock BO3 perks). PhD **hijacks the registered stock electric-cherry pipeline + its machine** (the underlying specialty is still `specialty_electriccherry`, exactly as the old Aura Blast placeholder did) — our module `_acc_perk_phd_flopper.gsc` overwrites the cherry cost/hint/give/take and installs a custom `level.perk_damage_override` immunity func; **the ability is entirely our code** (adapted from the shipped HarryBo21 / ColDog PhD Flopper), NOT the stock reload-shockwave. Electric Cherry (10) is a separate from-scratch perk on the unused `specialty_combat_efficiency` (`_acc_perk_electric_cherry.gsc`) — it does NOT touch PhD's cherry hijack, so the two coexist. Widow's Wine (8) base is pure stock; its **Spiderman** Mega is custom.

**Mega** tiers are all map-specific. **All 10 perks are live today.**

Buying all 10 = **30,500 Points** (Double Tap **3,000**, lowered from 5,000; Electric Cherry **3,000**). Hitting that by round ~25 is possible with dedicated economy play (Payroll Ledger boss item + high-round headshot farm).

The table above is a **complete at-a-glance** summary (base + Mega). Below, **[Perk reference (base + Mega)](#perk-reference-base--mega)** gives **full paragraphs** you can read start-to-finish, then **Mechanics** for exact numbers. **How** to acquire Mega (bottles, Lab machine, persistence) is in **[Mega Bottles (system)](#mega-bottles-system)**.

## Perk-Slot Rule — start at 4, buy more with Data Shards (user, 2026-06-19)

- You **start with 4 perk slots** (`level.perk_purchase_limit = 4`, the stock base; `ACC_PERK_SLOT_BASE`).
- Extra slots (up to **10** = all perks) are **bought with Data Shards** at the underground **Neural
  Expansion Bay** — the marquee trench-economy incentive (see [03_progression_and_skills.md](03_progression_and_skills.md), docs/30 §3).
- **Implementation**: `acc_perks::acc_perk_slot_limit` is installed as the stock per-player hook
  `level.get_player_perk_purchase_limit` (`_zm_utility.gsc:5874-5889`); it returns
  `base + player.acc_perk_slot_bonus`, capped at `ACC_PERK_SLOT_MAX` (**10** — bumped from 9 when Electric
  Cherry landed as the real 10th perk). Each extra slot escalates in cost — `ACC_PERK_SLOT_COST_BASE 4` +
  `ACC_PERK_SLOT_COST_STEP 2` × slots-already-owned → **4 / 6 / 8 / 10 / 12 / 14 shards** for the six extra
  slots (**54 shards total** to reach all 10). See `_acc_perks.gsc`.
- **"Max perks" feedback**: trying to buy a perk you don't own while at your slot limit shows
  `"You've reached your max of <N> perks - raise the limit at the Neural Expansion in the Bus Station trenches"`
  (+ the deny sound), instead
  of the stock silent deny. Done in `_acc_perk_info.gsc::acc_perk_validate` (the `custom_perk_validation`
  hook), gated on `zm_utility::can_player_purchase_perk()` so it matches the stock limit exactly.
- **Co-op**: per-player — each player buys and owns their own slot bonus.

### Why a buyable cap (changed from the old "no cap")

- This map previously shipped **no cap** (all perks free to anyone who could afford the points). That removed a
  decision rather than adding one. Making slots a **shard purchase** turns "how many perks" into the headline
  reason to risk the trench: the cap is a *goal you grind toward*, not a freebie.
- A round-10 player runs the base 4; reaching all 10 is a long-horizon investment (54 shards) that competes with
  weapon Overclocks (the **Overclock terminal** — the live shard-driven weapon upgrade) and the Exo Suit for the
  same trench-earned shards — exactly the "tight Shard decisions" tension the progression design wants. *(The
  Cyberware skill tree is **dormant** — gated off behind `acc_cyberware_on` (default 0), so it is **not** currently
  a competing shard sink; see [03_progression_and_skills.md](03_progression_and_skills.md).)*
- Dev mode (the one hardcoded `level.acc_dev` flag) returns the max so every machine is buyable while testing
  (`acc_perk_slot_limit` short-circuits to `ACC_PERK_SLOT_MAX` when `IS_TRUE( level.acc_dev )`).

## Perk reference (base + Mega)

Read **top to bottom** for full prose on every perk. Each entry has a **Base** description (what you buy with Points), a **Mega** description (what you unlock with an **Empty Mega Bottle** at a Lab machine when that perk is on rotation — no extra Points), then **Mechanics** with numbers and stacking. Bottle acquisition, persistence, and UI: [Mega Bottles (system)](#mega-bottles-system).

### 1. Jugger-Nog — 4,000 Points

**Base.** Raises max health to **250 HP** (no-perk base is **125 HP** — buffed from 100, user 2026-07-16; Jug add cut 150→125 so the Jug total stays 250) — you survive **5** regular zombie melee hits and go **down on the 6th** (no perk: down on the 3rd). Buy Jug for survivability, training, and room for mistakes.

**Mega: Ultimate Tank.** Max health to **300 HP** → survive **6** hits, **down on the 7th**. *(The boss-zap protection that used to be here now lives on **Mega Electric Cherry "Power Surge"** as a **−10% softening** — it moved Jug → Mega Widow's → Mega Electric Cherry, settled 2026-06-25, softened from full immunity 2026-07-03. Mega Jug is HP only.)*

**Mechanics**

- **HP / hit counts** (at ~45 dmg per zombie melee): **125 HP → 3rd · 250 HP → 6th · 300 HP → 7th**. Open-field melee damage is a baked GDT value — confirm hit counts in-game.
- **Stacking**: Ghost Shroud (boss item). *(Cyberware Subroutine Caching also stacks if the tree is re-enabled — dormant by default, docs/03.)*

### 2. Quick Revive — 2,500 Points (co-op) / 500 Points (solo)

**Base.** **Revive teammates in 2.0 s** (vs 3.0 s with no perk). **HP regen starts 20% sooner** after you take damage — begins at **1.92 s** instead of the **2.4 s** baseline (an earlier *start*, not a faster heal rate). **Solo:** self-revive per stock BO3, priced at the **stock 500** (up to 3 buys). The cost is a function pointer (`quickrevive_cost` in the entry script) that returns **500 when `zm_perks::use_solo_revive()` is true, else 2,500** — stock reads `.cost` live for both the machine price and the look-at hint, so solo and co-op each show/charge the right number.

**Mega: Savior.** (1) **Revive in 1.0 s** — half of base QR's 2.0 s. (2) **HP regen starts 40% sooner** (begins at 1.44 s) — upgraded from base QR's 20%. (3) **+15% move speed** (×1.15) while any *other* player is downed / bleeding out; clears the moment nobody is down (your own down does not count). (4) **−50% incoming damage while you are reviving a teammate** (user 2026-06-26) — you take half damage for the whole revive channel, so you can't be punished as easily for stopping to pick someone up.

**Mechanics**

- **Revive time:** no perk **3.0 s** → base QR **2.0 s** → Savior **1.0 s**.
- **Regen delay:** baseline **2.4 s** → base QR **1.92 s** (20% sooner) → Savior **1.44 s** (40% sooner). Heal rate is unchanged; the % is the delay reduction.
- **Low-health red-screen trigger** (map-wide; 2026-07-25): the red pulse fires at **≤30% HP** — `_acc_perks.gsc::init` raises the stock `level.healthOverlayCutoff` from `0.2` (20%) to **`0.30`** (`ACC_HEALTH_OVERLAY_CUTOFF`; stock ZM level init runs first, so our override sticks; the overlay gate re-reads it live each damage tick). Separate from the *sync* below, which stops the pulse when HP is back to full.
- **Low-health red-screen sync** (map-wide, not QR-gated; 2026-07-25): the stock red pulse vignette is **time-based** — below the cutoff (now 30% HP) it flashes for a fixed `longRegenTime` (5 s) + ~2.6 s tail and never re-reads health (stock aligned only because stock very-hurt regen also waits exactly 5 s). With our earlier-start regen and instant heals (Jug purchase, Megas) the screen stayed red for seconds at full HP. `_acc_perks.gsc::health_overlay_sync` (per player, per life) fires stock's own kill switch `self notify("clear_red_flashing_overlay")` (the notify `_zm_laststand` uses on revive) edge-triggered on the not-full → full transition, which fades the overlay in 0.05 s, clears the flag, and stops the heartbeat loop. Not gated on the `player_has_red_flashing_overlay` flag — stock clears that flag at full health *without* stopping the visual, so flag-off-but-pulsing is exactly the broken state.
- **Move speed:** Savior **×1.15** while a teammate is in last-stand (multiplicative with other speed buffs).
- **Revive damage reduction:** Savior takes **×0.50 incoming damage** for the full duration of a revive (the whole time `self.is_reviving_any > 0`). Applied in `_acc_elites::on_player_damaged` after the Exo Suit resist, so the two **stack multiplicatively** (e.g. Exo T5 −25% then ×0.5 → ~0.375× total). Floored at 1 (always killable). Self-revive does not qualify (the downed player is rejected as invalid earlier in the callback). Lever: `ACC_SAVIOR_REVIVE_DMG_TAKEN` in `_acc_perks.gsc`.

### 3. Speed Cola — 3,500 Points

**Base.** **+50% reload speed** and **faster barrier board / repair** animations (stock). Weapon swap is **not** a Speed Cola effect — and no longer a perk effect at all: weapon-swap time is now **stock for everyone** (the old Gun Slinger −50% swap twin was **removed 2026-07-04**). *(A faster perk-drink animation was considered but **cut** 2026-06-14 — the drink anim is shared map-wide with no per-perk lever, so it can't be gated to Speed Cola owners.)*

**Mega: Sleight of Hand Expert.** **+75% reload** (replaces the base +50%), delivered by the per-gun `fastreload` weapon-variant twin (`reloadTime ×0.857` layered on the engine's +50%).

**Mechanics**

- **Reload:** base **+50%** (stock engine, off the specialty) → Mega **+75%** (replaces, not additive; the `fastreload` weapon-variant twin layers `reloadTime ×0.857` on top of the engine +50%).
- **Barrier repair:** faster (stock).

### 4. Double Tap 2.0 — 3,000 Points

*The full stock Double Tap II Root Beer — kept as-is (the extra bullet can't be stripped from a usermap, so we embrace + balance around it).*

> **Design decision (2026-06-14):** the base perk IS the stock `specialty_doubletap2` machine,
> which fires an **extra bullet per shot** (≈2× damage). There is no usermap-side way to remove
> that, so we **keep Double Tap 2.0** (the old "convert to a rate-only 1.0" plan is cancelled) and
> price/balance around what we have: **5,000** (up from ~2,000; **later lowered to 3,000** on 2026-06-25 —
> the current price, see the table above) because doubling bullet output is a major damage perk.
> **REWORK 2026-07-04:** the Mega (Gun Slinger) is no longer a fire-rate/swap perk. Its `fastfire`
> weapon-variant twin was **removed entirely** (freeing 8 twins/gun, 224 → 96 total at the then-16-gun
> roster; the current matrix — 140 twins on 22 guns incl. the Havoc turbo axis — lives in docs/21
> §A). Mega Double Tap's **only** effect is now a **damage buff**: the extra-bullet temper
> eases **×0.6 → ×0.8** (later eased again to **×0.7 → ×0.9**, user 2026-07-17), so Mega DT lands ~2.39× DPS vs base ~1.86×. Rationale: the fire-rate twin
> stacked too hard (Mega was OP) and it was the single most twin-hungry axis in the matrix.

**Base (Double Tap 2.0).** **Fires 2 bullets per shot for the cost of 1 round of ammo** (double pellets on shotguns) **plus +33% rate of fire** (stock). Untouched, the extra bullet would stack to ~2.66× DPS (2× dmg × 1.33 RoF), so we **temper the per-hit DAMAGE** (user 2026-06-25): `acc_doubletap_dmg_mult = 0.6` → base DT lands ≈ **1.6× DPS** (2 bullets × 0.6 × 1.33). The fire rate is left intact. Does **not** apply to Wonder Weapons, the Ballistic Knife, or explosive weapons. *(The temper reduces EVERY bullet from a DT holder on the allow-list — it cannot isolate "the extra bullet"; the net is a buff only because DT fires two.)*

**Mega: Gun Slinger (reworked 2026-07-04).** **Extra bullets hit harder** — the per-bullet damage temper **eases ×0.7 → ×0.9** for Mega holders (`acc_doubletap_mega_dmg_mult = 0.9`, user 2026-07-17 was 0.8), so Mega DT lands ≈ **2.39× DPS** (2 bullets × 0.9 × 1.33) vs base ~1.86×. **No fire-rate or weapon-swap bonus** — the old `fastfire` twin was removed. Pure runtime damage (read live via `has_mega_perk`), no weapon-variant twin.

**Mechanics**

- **Damage temper (base `acc_doubletap_dmg_mult` = 0.6 / Mega `acc_doubletap_mega_dmg_mult` = 0.8):** a per-hit REDUCTION in `_acc_damage.gsc` on Double-Tap holders — base nets ≈**1.6× DPS**, Mega ≈**2.1× DPS** (both vs the raw stock ~2.66×). **100%-safe allow gate** (`weapon_gets_dt_bullet`): applied to every gun **except the Thundergun, Mahem, China Lake, War Machine, Havoc, and Blast-O-Matic** (all explosive / projectile — no extra bullet), and only on bullet hits (melee / grenades / equipment auto-excluded) — so it can never nerf a weapon that lacks the extra bullet. (VERIFY in-game that MORS / Paladin fire 2 rounds with DT — two crosshair damage numbers; if not, add them to the deny-list.)
- **Fire rate:** base **+33%** (stock engine, both base and Mega). *(Mega no longer adds fire rate — the `fastfire` twin was removed 2026-07-04.)*
- **Weapon swap:** stock (no perk bonus — the −50% swap twin was removed 2026-07-04).

### 5. Stamin-Up — 2,000 Points

**Base.** Sprint lasts **~12 s** (vs ~4 s with no perk); stamina refills in **~4 s** after it depletes; **+7–8% movement speed** (overall mobility caps ~109%). Sprint is still finite. (Stock BO3 engine values.)

**Mega: The Flash.** **+15% sprint speed** (×1.15) — applied as a uniform move-speed scalar (BO3 has no sprint-only speed lever, so it raises all movement). No sprint-duration change (base already grants the ~12 s reserve).

**Mechanics**

- **Sprint duration:** no perk **~4 s** → Stamin-Up **~12 s** → The Flash unchanged.
- **Move speed:** base Stamin-Up **+7–8%** → The Flash adds **×1.15**.
- **Stacking**: Neural Boots (boss item, ×1.20) — a multiplicative speed term. *(Cyberware Reflex T1 also stacks if the tree is re-enabled — dormant by default, docs/03.)*

### 6. Mule Kick — 2,500 Points

**Base.** A **third primary weapon slot** so you can run close / mid / long without returning to the box.

**Mega: The Armory.** **+20% reserve ammo refilled each round** per weapon (sustain refill, not a capacity boost; also instant on acquire); **all buys 10% cheaper** — every point purchase (wallbuys, ammo, perks, Pack-a-Punch, Mystery Box) costs **10% less** (×0.9) while you hold The Armory.

**Mechanics**

- **Base**: third primary; **2,500** pts.
- **Mega — The Armory**: **+20%** reserve refill per gun each round; **×0.9** cost on all point purchases.
- **The Mule Kick gun (the one you lose on a down) is a STICKY SLOT** (user 2026-07-11): the gun that **fills your 3rd slot** is designated the Mule Kick gun (MULE badge) and **keeps** that designation while you carry it — PaP'ing it, twinning it (Mega swaps), or replacing your *other* guns never moves it. It moves only when **that gun itself** leaves: replace it → its replacement inherits the slot; go down → it's taken and the next gun to fill slot 3 starts fresh. Implementation: `_acc_gun_badges.gsc` `mule_desired_at_risk_base` (sticky `acc_mule_at_risk` over the acquisition-order list, frozen during PaP/box/drink inventory transactions); the same designation drives the badge and **every** removal path. Stock hangs the gun-take off **two independent hooks** and both are overridden (fixed 2026-07-15 — only the first was): `callback::on_laststand` → `acc_mule_on_laststand` (the down), and the `zm_perks::register_perk_threads` take → `acc_mule_on_perk_take` (**perk pause**: the boss phase-3 perk-EMP and phase-2 power-off both route through `perk_pause`, which takes a Mule gun *permanently* — stock's unpause give-thread is empty). Before the fix that second leg still used stock's give-order pick, so an EMP removed a **different** gun than the MULE badge advertised.
- **Mystery Box pricing note**: the box price/charge is owned per-frame by `acc_box_prompt` (`_acc_perk_info.gsc`) — it applies the ×0.9 Armory discount normally, and during a **Fire Sale** it forces the stock **10**-point sale price itself (no discount stacks on a 10-point sale). The separate **Paradise Box** is an independent interactable and does not take part in Fire Sale.

### 7. Deadshot — 3,500 Points (custom — not a stock BO3 perk)

**Base.** **+1.3 headshot damage bonus** (user 2026-06-25, was 1.4), **no recoil change** (recoil reduction is Mega-only since 2026-06-16), and **ADS snap-to-head** (auto-aim to the nearest head while aiming; not on bosses).

**Mega: American Sniper.** **+1.5 headshot** (replaces the base +1.3 — no double-dip; user 2026-06-25, was 1.6); **−50% recoil** via the `recoil50` twin (off the **1.75×** map base → ~**0.875× vanilla**). Head-snap is inherited from base (unchanged).

**Mechanics**

- **Headshot temper** is applied **multiplicatively** to a head hit: `locHead × 0.5` on trash (`ACC_HEADSHOT_MULT`) / `locHead × 0.8` on boss (`ACC_BOSS_HEADSHOT_MULT`). Most box guns are `locHead 5.0` → **×2.5 trash / ×4 boss** with no perk (user 2026-06-25; boss ×3 → ×4 on 2026-07-08). **Deadshot's bonus is SEPARATE and additive** — it adds **+1.3** (base) / **+1.5** (American Sniper) into the crit-damage bonus pool on top (PaP/Cyberware also add into that pool).
- **Recoil:** base = **no recoil change** → Mega **−50%** (off the **1.75×** map base → ~0.875× vanilla; delivered by the Mega-only `recoil50` weapon-variant twin).

### 8. Widow's Wine — 4,000 Points

**Base (stock BO3 Widow's Wine, NERFED 50% across the board — user 2026-07-17 "too good at preventing you from dying").** Your lethal becomes **Widow's Wine grenades** (sticky / Semtex-like) — zombies caught in the blast but not killed are trapped in webs (**8 s** frozen close in / **6 s** slowed further out — HALF the stock 16/12 s; freeze/slow *strength* stays stock, the nerf is uptime). **Self-defense webbing:** when a zombie melees you, you release a web burst trapping nearby zombies — now a **50% chance per hit** (stock: every hit; a denied proc takes the melee normally and spends no grenade). **Webbing melee:** meleeing a zombie webs it at **25%** (stock 50%). Web grenades **restock 2 at the start of each round** (also on Max Ammo and from blue spider-drop pickups — a webbed-zombie kill drops one at **10%** web-grenade / **15%** gun / **20%** knife; we own the roll, see Mega). *Implementation (`_acc_perks.gsc`, `ACC_WW_*` defines): stock's numbers are unreachable `#define`s, so the proc chances ride in-place pointer swaps of the stock handlers in `level.perk_damage_override` / `level.zombie_damage_callbacks` (wrap-delegate), and the durations ride a per-AI spawn-hooked watchdog that force-fires stock's own expiry notifies + cleanup at half time (re-applications re-arm the clock via the extend-notify listener).*

**Mega: Spiderman.** Two upgrades (the **one-hit melee was REMOVED user 2026-06-29** — a Mega-Widow's melee now does normal melee damage; it had been re-added 2026-06-18): **spider-mobility while low** — you scuttle far faster the lower your stance (**crouch ×2.6 / prone ×10 / downed ×15**, `_acc_mega_bottles::mww_stance_speed_watch`); and **+10 percentage points of spider-drops on all three kill types** — killing a *webbed* zombie drops the blue web-grenade refill pickup more often (base **10/15/20** web/gun/knife → Mega **20/25/30**; `mww_spider_drop_roll`, user 2026-06-26). We **own the whole roll** (the stock chances are unchangeable `#define`s and the base needed to go *below* stock): a spawn hook (`mww_suppress_stock_spider_drop`) sets the read-only-in-stock `b_widows_wine_no_powerup` to disable the stock auto-drop per-zombie, and the death hook does the single replacement roll — no double-drops. *(The old 6-web-grenade virtual pool + 4/round restock + WEB GRENADES HUD were removed 2026-06-24 — Mega Widow's web grenades use stock behavior now; the boss-special immunity that briefly lived here moved to Mega Electric Cherry "Power Surge" 2026-06-25.)*

**Mechanics**

- **Base**: web grenades, self-defense webbing, webbing melee, **2**/round restock — stock mechanics at **half strength** (user 2026-07-17): contact web **50%** proc, melee web **25%**, cocoon **8 s**, slow **6 s** (`_acc_perks.gsc` `ACC_WW_CONTACT_PROC_CHANCE` / `ACC_WW_MELEE_PREROLL` / `ACC_WW_COCOON_DURATION` / `ACC_WW_SLOW_DURATION`).
- **Mega — Spiderman**: **spider-mobility while low** (crouch ×2.6 / prone ×10 / downed ×15, `_acc_mega_bottles::mww_stance_speed_watch`); **+10 pp spider-drops on all kill types** (base web **10** / gun **15** / knife **20** → Mega **20 / 25 / 30**; `_acc_mega_bottles::mww_spider_drop_roll` + `mww_suppress_stock_spider_drop`, user 2026-06-26 — we OWN the roll: suppress the stock drop per-zombie via the read-only `b_widows_wine_no_powerup`, then one replacement roll, no double-drops; dvar `acc_widow_spider_custom 0` reverts to stock). *(The custom 6-grenade virtual pool + 4/round restock + WEB GRENADES HUD counter were REMOVED 2026-06-24, and the boss-special immunity MOVED to Mega Electric Cherry "Power Surge" 2026-06-25 — both are OFF Mega Widow's now.)*

### 9. PhD Flopper — 2,500 Points (custom ability — hijacks the stock cherry pipeline)

**Base.** Three abilities: **(1) Immunity** — you take **no fall damage** and **no splash damage from your own explosives, grenades, or projectiles** (rockets, frags, the launcher, etc. can't hurt you). **(2) Explode when you go down** — entering last-stand fires a nova around you, buying space to be revived (this is base PhD's only nova trigger). **(3) Blast look** — the nova is a **stock orange explosion** (`level._effect["def_explosion"]`, user 2026-06-25 — swapped off the old purple Apothicon / electric-spark FX) + a screen-shake. **Slide-to-explode is Mega-only** as of 2026-06-26 (see PhD Slider). BO3 ZM has the sprint-slide but **no dolphin-dive** (confirmed 2026-06-15), so the Mega slide nova triggers off the engine `isSliding()` directly — not the BO1/BO2 dive-to-prone.

**Mega: PhD Slider.** Adds the **slide-to-explode** (Mega-exclusive — base PhD doesn't detonate on a slide) + a **bigger/stronger nova** on a **shorter slide cooldown** (base **10s** → Mega **8s**). Radius **300→250u** (Mega HALVED, user 2026-06-27), **capped at 10 zombies hit per slide** (`acc_phd_max_hits`); Mega nova damage **FROZEN at a round-16 zombie's health** (`ACC_PHD_FREEZE_ROUND 16`, dealt raw via the `acc_phd_nova_hit` bypass — one slide one-shots trash ≤r16, then 2/3 slides past it; replaces the old ~0.8× live-scaled). **Plus 1.75× SLIDE speed** (slide-gated, like the Rocket Shield — stacks multiplicatively with the shield's own 1.75× slide bonus; combined sliding clamps to the **2.2× move cap**) and **+15% explosive damage** (a GSC scalar in `_acc_damage`, **no weapon twin**). Working Mega — the Empty Mega Bottle sets the flag and the bigger nova fires immediately.

**Mechanics**

- **Trigger**: passive — fall-damage / self-splash immunity is always on; the down-state nova fires when you enter last-stand (base + Mega); the **slide** nova is **Mega-only** (cooldown-gated). No input chord.
- **Base**: custom fall-damage + self-splash immunity (via a `level.perk_damage_override` func) + a **down-state explosion**. Radius **300u**, base (round-scaled) damage. **No slide nova on base** (`phd_slide_watcher` gates on the Mega flag; dvar `acc_phd_base_slide_nova`).
- **Mega — PhD Slider**: adds the **slide** nova + a down nova at radius **250u** (user 2026-06-27, HALVED from 500), **capped at 10 zombies hit per slide** (`acc_phd_max_hits`), **damage FROZEN at a round-16 normal-zombie's health** (`ACC_PHD_FREEZE_ROUND 16`, co-op-scaled, dealt raw via the `acc_phd_nova_hit` bypass — one slide one-shots trash through r16, then 2 slides ~r17–23, then 3; user 2026-06-27, replaces the old live-scaled ×0.8), and an **8s** slide cooldown (base would be 10s). **Also 1.75× SLIDE speed** (`acc_mega_flopper_speed` → `acc_utility::recompute_move_speed`, slide-gated, re-applied on respawn; **carries through a slide-jump** until landing — 0.5s post-slide grace (`acc_slide_jump_grace`, a slide-jump stands you up for a few grounded frames first) + a jump-button pre-launch speed top-up with a liftoff restore fallback [both along your current heading, floored at half slide speed], and the boost ramps down smoothly over 0.4s on release instead of snapping (`acc_slide_carry_decay`); momentum mechanic 2026-07-15, mirrors the Rocket Shield) and **+15% explosive damage** (grenades / projectiles / `MOD_EXPLOSIVE` via `_acc_damage::on_ai_damage` `is_explosive_mod` + `has_active_mega_perk` — GSC scalar, no twin). **Slide speed stacks multiplicatively** with the Rocket Shield slide bonus: sliding with both = `1.75 × 1.75 ≈ ×3.06` → clamped to the **2.2× move cap** (`acc_move_scale_cap`), plus the shield's forward lunge.
- **Blast FX/sound**: the burst centres on the **nearest in-radius zombie** (the impact point — i.e. the zombie you slid into on the Mega slide — not the player): the **stock orange `def_explosion` FX** (`level._effect["def_explosion"]`, user 2026-06-25 — off the old DLC4 Apothicon / electric-spark FX) + an `Earthquake`; sound base = `def_explosion`'s own boom, **Mega = `evt_nuke_flash`** (the Nuke "whoomp").
- **Zombies explode**: every zombie the nova kills pops apart — **head-gib** (`zombie_utility::zombie_head_gib`, the Nuke powerup's own dismember, called on the live zombie pre-kill) + a **torso gore burst** (`level._effect["zombie_guts_explosion"]`). Gated on `health <= damage` so a living **boss** is only chipped, never gibbed. *(The old corpse-fling `StartRagdoll`/`LaunchRagdoll` was **removed 2026-06-24** — the invisible-zombie bug; see CHANGELOG.)* All stock — no import.
- **Implementation**: `_acc_perk_phd_flopper.gsc` **hijacks the registered stock `_zm_perk_electric_cherry` pipeline + machine** — it overwrites the cherry cost/hint/give/take and installs the `level.perk_damage_override` immunity func, then layers the slide / down explosion in our code (adapted from the shipped HarryBo21 / ColDog PhD Flopper). The underlying specialty stays `specialty_electriccherry` (HasPerk / rotation / HUD / Mega plumbing all key off it). The old `_acc_perk_electric_cherry.gsc` was **deleted**.
- **Skin**: machine = stock placeholder `p7_zm_vending_nuke` model (fits PhD's explosion theme and avoids a game-rip vending import); icon = Ronan's Cyberpunk "exo_flopper" (`i_acc_perk_phd_base` / `_mega`) on the LUI perk bar; bottle = stock `zombie_perk_bottle_cherry`.
- **Build fit**: aggressive movement + crowd clearing on landing; self-explosive-safety; down-state self-defense.

### 10. Electric Cherry — 3,000 Points (custom — the REAL 10th perk)

**Base.** **Reloading discharges an electric nova** that electrocutes nearby zombies, and **the emptier your mag, the bigger the blast** — an empty-mag reload one-shots trash at any round; a full-mag reload is just a spark (we fixed the stock `1/10` clip-fraction stub to read the real `GetWeaponAmmoClip / clipSize`). Zombies the nova doesn't kill are **stunned** with the stock tesla stun + shock FX (~4 s); lethal hits get the full electrocution. **8 targets** per nova (`EC_TARGET_CAP`), **6 s cooldown** (`EC_COOLDOWN`) to stop reload-spam, base empty-mag radius **220u** (`EC_RADIUS_MAX`). **No last-stand explosion** — PhD Flopper owns the single global down-explosion hook. Built from scratch on the unused engine specialty **`specialty_combat_efficiency`** (the Elemental Pop precedent), so it does **not** collide with PhD Flopper's `specialty_electriccherry` hijack — both perks coexist. Code: `_acc_perk_electric_cherry.gsc`; own machine (the real cherry model `electric_cherry_model`, West-pack port) with its own spawn slot on the Lab N wall — like every perk it rides the map-wide scatter (the alcove row is gone, 2026-07-25).

**Mega: Power Surge.** A stronger, faster nova — **+50% damage** (`× 1.5`), **12 targets** (`EC_TARGET_CAP_MEGA`), **4 s cooldown** (`EC_COOLDOWN_MEGA`, user 2026-07-08, was 5). All read live off the persistent Mega flag. The Mega's edge is damage / targets / cooldown, **not** blast size: the empty-mag radius is a touch *tighter* by design (`EC_RADIUS_MAX_MEGA 200` vs base `220`). **Plus boss-zap softening** — a Power-Surge holder takes any boss zap slow (**Phantom chain / Rogue Protector / Avogadro**) at a flat **−10% instead of −30%** (`acc_boss_slow_mega_mult 0.90` vs the `0.70` non-holder slow; was full immunity, softened 2026-07-03; the protection moved here from Mega Jug → Mega Widow's 2026-06-25).

**Mechanics**

- **Nova scaling:** radius/damage interpolate on clip emptiness between `EC_RADIUS_MIN` (64u full mag) and `EC_RADIUS_MAX` (220u empty); Mega interpolates 96u → 200u. Damage ×1.5 on Mega. Target cap 8 → 12.
- **Boss-zap softening + anti-stack** (`_acc_utility.gsc::recompute_move_speed`, ~L440-491): non-holders take the **single strongest** active boss slow as the base (`−30%`) **+ a flat −5% per extra concurrent stun** (`acc_boss_slow_stack_add`) — so two bosses zapping at once = **−35%**, three = **−40%**. A **full Power-Surge holder is exempt from the stack** (user 2026-07-09): while *every* active stun is Mega-softened, the slow stays a **flat −10% no matter how many bosses zap you** — the anti-stack is part of the perk. A *mixed* set (perk bought/lost mid-window) falls back to non-holder behavior. Gated on the **persistent** `specialty_combat_efficiency` Mega flag in the `_acc_elites` zap applicators. UI line: "Shrugs off boss zaps".
- **Battery override:** the **Battery** boss item fully absorbs boss zaps — a **+8% move surge** instead of any slow — superseding this softening for its holder (docs/09).
- **LUI perk-bar card index 10** (PaP shifted to 11). Icon `i_acc_perk_cherry_{base,mega}`.

## Mega Bottles (system)

**Mega** perk tiers (Savior, Gun Slinger, Ultimate Tank, etc.) are **not** bought with Points. They unlock by spending **Empty Mega Bottles** at the perk's machine, wherever the scatter currently has it parked (the parallel `acc_mega_vending` trigger moves with the machine) — full **Mega** descriptions are in [Perk reference (base + Mega)](#perk-reference-base--mega) under each perk’s **Mega: … (full description)**.

### Acquisition Loop

- **Drop rate**: **1 Empty Mega Bottle is guaranteed on every boss kill**, granted to every living player via the unified boss reward (`_acc_boss::grant_unified_boss_reward` → `acc_mega_bottles::grant_bottle( 1, "boss" )`). The roster is Brutus / Glitch / Phantom / Avogadro / Panzer + the Rogue/Civil Protector (docs/08); the **full boss rounds run every 9 from round 9** (r9=1, r18=2, r27=3 bosses, types dealt from a no-duplicate shuffled deck), and a **mini-boss first appears at round 10** (`ACC_BOSS_MINI_FIRST_ROUND`).
- **Additional to** the boss item-drop pool — Mega Bottles do NOT take an item-pool slot. They are a separate drop resource.
- **Inventory**: unlimited stack, per-player (counter on `self.acc_mega_bottles`).
- **In co-op**, each player independently receives 1 bottle per boss kill.
- **Realistic rate**: a long run yields a **handful of bottles per player** — enough to Mega a few perks, nowhere near all 10. Bottles are a scarce, decision-forcing resource: which perk you Mega first, and whether to instead sink 2 bottles into **pinning a Mega'd perk to its pad** (the scatter pin, below), is the tension.

### Usage

1. You must **already own the base perk** (bought normally from its machine).
2. **Find the machine wherever the scatter currently has it parked** (the paired `acc_mega_vending` trigger moves with the machine — the old "alcove must be open this round" gate died with the door rotation, 2026-07-24).
3. Interact with that machine → UI prompt "Apply Mega? (1 Empty Mega Bottle)".
4. Consume 1 Mega Bottle → the base perk upgrades to its Mega variant.
5. **No Points cost** — the bottle IS the cost.

### Persistence Rule

Once a perk is Mega'd on a player, the Mega effect is **sticky** for the rest of the run:

- **If you die** and lose the base perk, your Mega flag remains on `self.acc_mega_perks[perk_id]`.
- **If you re-buy the perk** from a machine (after respawn), it immediately applies the Mega variant — no second Mega Bottle required.
- **Run-end**: all Mega flags cleared (like all other run state).

This means: **the Mega Bottle is a one-time investment per perk per run**. Death doesn't punish your Mega progression.

### Cross-Round Timing Tension

- **You get a Mega Bottle at round 10** (the first mini-boss kill).
- **You decide you want to Mega Jug** — but the scatter parked Jug's machine somewhere across the map (maybe deep: the Abyss L2 or Exchange pad).
- **You trek to it** (or wait for the next divisible-by-3 reshuffle to bring it somewhere safer), interact, consume the bottle → Jug becomes Ultimate Tank.
- Once it's Mega'd you can also **pin it**: 2 more bottles lock that perk onto its current pad for the rest of the run (the successor of the old 2-bottle door unlock).

This keeps the decision texture the door rotation used to provide: Mega-ing a perk means owning it, reaching wherever it currently lives, and choosing between spending bottles on more Megas or on pinning the ones you rely on.

### Mega damage stack example

PaP L5 + Tier 5 FAL + American Sniper + Precision Mode ability + a clean headshot on a boss (plus the Cyberware Overload node, if its **dormant** tree is re-enabled — docs/03):

- The head hit takes the gun's **multiplicative headshot temper** — `locHead × ACC_BOSS_HEADSHOT_MULT (0.8)` = **×4** on a boss with a `locHead 5` gun (`×2.5` on trash via `ACC_HEADSHOT_MULT 0.5`). Deadshot's bonus stacks **additively** into the separate crit-damage bonus pool: **+1.5** with American Sniper (+1.3 base), alongside the PaP crit adds (and Cyberware's, only if its dormant tree is re-enabled).
- That result is then scaled by the multiplicative damage terms: `× 4.0` (Precision Mode ability) `× 1.5` (Overpressure Overclock if rolled) → a large multiple per headshot (illustrative; recompute once exact PaP/Tier values are locked). *(The Cyberware damage terms `× 1.15` (Oc1) and `× 1.30` (Overload T2) apply **only** if the Cyberware tree is re-enabled — it's **dormant** by default, so in normal play those flags stay unset, docs/03.)* Numbers live in `_acc_damage.gsc::on_ai_damage`.

Absurd. Intended for late-game power-fantasy. Tune via the levers at the bottom of the doc if playtest shows this is *unfun* absurd rather than *earned* absurd.

### Co-op Notes

- Mega Bottles are per-player. 4p = 4 bottles per boss kill collectively (but each player holds their own).
- Cannot give a Mega Bottle to a teammate.
- In 4p, a boss kill means 4 players each get +1 bottle. Over 5 bosses = 20 bottles total. Teams can coordinate who Mega's what for efficient role specialization.

### Mega HUD

HUD indicators:

- **Mega Bottle counter** next to Data Shards counter (lower-left). Format: `Bottles: 2`.
- **Mega-flagged perks** show a distinct perk icon (e.g. gold border) in the perk row.
- **Machine prompt** when standing near a rotating machine that dispenses a perk you own: "[Hold F] Apply Mega (1 Bottle)".

See [11_controls_and_hud.md](11_controls_and_hud.md) for HUD element spec.

### Implementation

- [`scripts/zm/zm_abandoned_cyber_city/_acc_mega_bottles.gsc`](../scripts/zm/zm_abandoned_cyber_city/_acc_mega_bottles.gsc) is the dedicated module (Phase 3/4 authoring).
- Drop hook: `_acc_mega_bottles::on_boss_death(killer)` fires on every boss death via the unified boss reward (`_acc_boss::grant_unified_boss_reward`).
- Mega flags: `self.acc_mega_perks[specialty_string]` is set true when Mega applied. Perk machines check this flag when dispensing.
- Effect application: when a Mega'd perk is acquired, the perk's `on_acquire` function checks `self.acc_mega_perks[id]` and applies the Mega deltas in addition to base effects.

### Tuning Levers

- **Drop rate too generous**: make some boss tiers a 50% roll instead of guaranteed.
- **Drop rate too stingy**: mini-bosses give 2 bottles each.
- **Mega too strong**: reduce specific Mega effects (e.g. American Sniper +1.5 → +1.4 headshot bonus, Gun Slinger damage temper `acc_doubletap_mega_dmg_mult` 0.9 → 0.8).
- **Rotation timing frustrating**: allow Mega application at ANY perk machine as long as the player owns the base perk (decouple from rotation). Simpler but less texture.

## Perk Availability: Map-Wide Perk Scatter (every 3rd round)

> **STATUS: LIVE (built 2026-07-24)** — `_acc_perk_scatter.gsc`. **Supersedes** the per-round
> 4-of-10 Lab alcove-door rotation AND its 2-bottle permanent door unlock (both retired the same
> day). **2026-07-25 lab cleanup (user):** the alcove geometry itself — the 9 partition fins,
> all 10 `acc_perk_door_*` gate slabs and the `acc_ec_right_wall` seal — was **deleted from the
> `.map`** (tombstone comments mark the spots), so `_acc_perk_doors.gsc` is now **registry-only**
> (it keeps `level.acc_perk_door_specs`, which `_acc_paradise` reads). The two Lab pads were
> split apart in the same pass: one stays on the (now flat) N wall, the other moved **inside the
> S-wall decon tent**. Geometry changed ⇒ that pass needed a full LED-bake build; every
> GSC-only scatter tune after it is `-GscOnly` again.

**The 10 perk machines are spread across the whole map on 10 fixed pads, and the perk→pad
assignment reshuffles at random at the start of every round divisible by 3** (3, 6, 9, … —
`ACC_SCATTER_INTERVAL`). The **opening layout is also random**, rolled per run and applied during
load while the blackscreen still hides the map. A scatter is announced (*"PERK MACHINES
SCATTERED"* banner) but the new homes are **not** revealed — finding them is the gameplay.
**Swap presentation (2026-07-25, punched up same day after the first test read as "nothing"):**
each live scatter plays the teleporter's de-rez read at **both** ends of every move — cyan
de-rez numbers + zap burst and the `acc_teleport_warp` boom at the vacated pad (open air —
the machine is already gone) and **above** the destination — while the machine **materializes
60u up and descends for 0.8 s**, then **lands with a punch**: the stock perk power-on
*ka-chunk* (`zmb_perks_power_on`), the stock machine shake (`Vibrate`), and one more de-rez
flash at body height. Purely cosmetic: the buy trigger and collision land instantly, so the
glide can never trap or block anyone. Pinning a perk also fires one de-rez burst on the
machine as the lock lands. The opening layout is silent (nobody sees it anyway).

| # | Pad (announce name) | Zone / room | Notes |
|---|---|---|---|
| 0 | the Plaza | `start_zone`, W wall | **Permanently Quick Revive**, never scatters. Solo auto-power + the stock solo 3-buy/self-revive rules ride the specialty + trigger (not the position), so solo QR works pre-power here like normal maps |
| 1 | the Lab | `lab_zone`, N wall at (75, 4195) — the alcove row was deleted 2026-07-25, flat wall now | the old in-game-verified Mule Kick spot |
| 2 | the Lab | `lab_zone`, **inside the S-wall decon tent** at (−560, 3103) — the big curtain-open decontamination unit | machine backs the S wall and faces N out the open curtain; buy from the 100u tent mouth; the ~128-tall machine top pokes through the z96 curtain-rail band (accepted) |
| 3 | the Alley | `alley_zone`, N wall | clear of the corp corridor mouth + NE rubble corner |
| 4 | the Market | `market_zone`, S wall | far from the stall training loop |
| 5 | the Helipad | `roof_zone`, S wall | wall-flush so the bomber training oval keeps its S lane |
| 6 | the Vault | `vault_zone`, W wall, N band (the 62u free span between the dragon-network clip and the monitor-support pole) | between the two W corridor gaps |
| 7 | the Bus Station depths | corp N under-room — the jukebox/reactor arena (z=−240), E wall solid segment south of the east-wing mouth | the room is the full expand_core arena (x to ±384), NOT the stale 192-wide floor brush |
| 8 | the Abyss (Layer 2) | L2 shaft W wall (z=−480), **past the first soul door**, straight west of the well landing — moved down from the jukebox S wall 2026-07-25 | no compile pre-cut (deep worldspawn clips crash the LED bake); the machine's runtime clip behaves like L2's existing clipped mid-floor pillars |
| 9 | the Exchange | the transfer vault (z=−160) | behind the 1,500-pt `enter_exchange` door — a safe-room perk is the reward for opening it |

Exact origins/yaws live in ONE place: the pad table in `_acc_perk_scatter.gsc::build_pads()`
(placement-verified against the docs/02 keep-clear bands).

**Rules**

- **Spots = perks, always** (user 2026-07-24): every perk has a home at all times — the 9 rotating
  perks permute over the 9 rotating pads each scatter. If a perk is ever added to the map, a pad
  gets added with it.
- **Owned perks are untouched** — only machines move; perks are player state (unchanged rule).
- **Power gating unchanged**: the single global `power_on` flag. Machines relocate before power
  too — just unbuyable until the corp switch is flipped. Plaza QR keeps stock solo behavior.
- **Mega upgrades unchanged**: the parallel `acc_mega_vending` trigger rides along on every move
  (back-linked at spawn in `_acc_mega_bottles::mega_trigger_think`).
- **Dev = ship**: dev runs the real scatter, exactly like normal play. The only dev delta is the
  per-scatter assignment printout (rides `IS_TRUE( level.acc_dev )`, no dvars).

### Pin — lock a Mega'd perk to its pad for good (2 Mega Bottles)

*The direct successor of the retired permanent door unlock: same currency, same cost, same
"spend bottles to make perk access permanent" role — but now gated on the Mega.*

- The pin prompt shows **only to players who own that perk's Mega** (the sticky
  `has_mega_perk` flag — survives a down, like the Mega itself) while the perk is unpinned.
  Costs `ACC_SCATTER_PIN_COST = 2` Empty Mega Bottles from the buyer; benefits the whole team.
- On pin: the perk **and its current pad both leave the rotation forever** (the remaining pool
  keeps permuting over the remaining pads — counts stay equal by construction). Announced
  team-wide; the pin trigger deletes itself (entity freed).
- Quick Revive has **no pin trigger** — it never moves, so pinning it would waste 2 bottles.
- **Prompt UI:** the pin hint keeps `permanently` + `Mega Bottles` in its text so the LUI
  cursor-hint router (`ZMCursorHintNew.lua`, guards fixed 2026-07-11) classifies it to the
  **DefaultHint** card exactly like the old unlock prompt. 9 static hint strings replace the 10
  retired unlock strings (net negative on the engine hint-string cap).

### How machines move (the mechanism)

Stock `perk_machine_spawn_init` (`_zm_perks.gsc:1513-1561`) builds every machine from **4 script
entities** — the `zombie_vending` use trigger (pad+60z), `.machine` (the vending `script_model`),
`.bump` (audio trigger, +20z) and `.clip` (solid `zm_collision_perks1` `script_model`,
DisconnectPaths'd) — nothing is baked world geometry, so the scatter simply **rewrites origins**:

> phase 1: `ConnectPaths()` EVERY moving clip while all machines still sit at their old pads →
> phase 2: move clip / machine / trigger / bump (+ the paired `acc_mega_vending` and
> `acc_perk_pin` triggers + the `s_fxloc` FX host) and `DisconnectPaths()` at each new pad →
> unstick any player the arrival overlapped (pushed out the machine's front, per-pad distance).
> **Power look (FX auras — re-affirmed 2026-07-25):** the per-machine `accPerkGlow` colour
> auras (`_acc_perk_lights`) are the power-on visual. The 07-24 "native" attempt (rely on the
> stock `off_model`→`on_model` swap) was **refuted live** — the swap shows no visible delta in
> this build. The auras are strictly power-gated (fields only ever set after the `power_on`
> flag; pre-power = no glow), re-pulsed after every scatter move, and re-kicked per z-band when
> players first descend (under-rooms/Exchange/L2 at z<−100; the Paradise row at z<−1000) so a
> latched far-away set still renders on arrival. Avogadro's hack darkens the aura; his re-light
> is gated on the power-on latch. Note: Electric Cherry's West-pack model and PhD's nuke
> placeholder are inherently emissive models — they *look* lit at all times regardless of the
> aura (fixing that needs darkened model variants, asset work).

Shipped precedent for every step: zm_nuked's ±10000z trigger displacement, mid-game flying
machine, and relocatable PaP; ohm-nabar/zm_building's literal `move_perk_machine` utility
(docs/16:60-121); plus this repo's own `force_perk_machine_facing` mutating the same handles.
Everything downstream resolves machines **by name** (`zombie_vending` / `radiant_machine_name`),
never by position, so the stock purchase pipeline, drink anim, jingles and power gating all
survive. Integrations that ARE position-aware were wired: `_acc_boss_avogadro` re-runs
`cache_target_origins()` on the `acc_perk_scatter_applied` notify (its Lab-vs-Paradise split
survives because every surface pad sits at z ≥ −240, far above the z<−600 twin filter);
`_acc_perks::apply_perk_facing` honors the per-pad `acc_pad_yaw` so its post-load facing
re-assert can't spin machines back to the Lab-row yaw; `b_keep_when_turned_off` is set on every
machine so no power-off path can Delete-and-respawn a model out from under the captured handles.
The Paradise duplicate row (z=−1200) is excluded by z-band and never scatters.

**Tuning levers:** `ACC_SCATTER_INTERVAL` (default **3**) and `ACC_SCATTER_PIN_COST` (default
**2**) in `_acc_perk_scatter.gsc`.

### Retired predecessors (history — none of this is live)

Two prior perk-availability designs are fully superseded by the scatter; their implementations were
**deleted** on 2026-07-24 (recoverable from git history):

- **The Lab alcove-door rotation (live 2026-06-16 → 2026-07-24)**: all 10 perks in door-gated Lab
  alcoves, a random 4-of-10 doors open per round (no immediate repeats, no-trap occupancy
  reconcile), plus the **2-Mega-Bottle permanent door unlock** (2026-07-07) whose cost/currency/
  team-benefit shape lives on as the scatter's **pin**. The `ACC_PERK_DOORS_OPEN_PER_ROUND` and
  `ACC_PERK_DOOR_UNLOCK_COST` defines and the `acc_perk_doors_all_open` dvar **no longer exist**;
  the rewritten `_acc_perk_doors.gsc` only forces the doors open and keeps the
  `level.acc_perk_door_specs` registry. The prompt-UI lesson carries over: hints containing
  `permanently` + `Mega Bottles` route to the **DefaultHint** LUI card (`ZMCursorHintNew.lua`
  guards, fixed 2026-07-11) — the pin hint keeps that wording.
- **Rotating Lab machines (never built)**: 4 dedicated `acc_lab_perk_a..d` machines re-assigned
  per round — `_acc_map_randomizer::apply_perk_rotation_to_machines()` stayed a `TODO(acc-geom)`
  stub because the entities were never placed; still inert/unthreaded, kept for reference.
  (Ironically the scatter now does the "machines move" idea for real, map-wide, by relocating the
  stock machine assemblies instead of re-skinning dedicated ones.)

## Perk Machine Behavior

- **Interaction**: hold [use] on active perk machine.
- **Power gate**: machines require map power on.
- **Perks retained through down/revive**: yes (stock behavior).
- **Perks lost on death (respawn)**: yes (stock behavior).
- **Quick Revive auto-refund in solo**: once per run, first death only.
- **Perk-slot cap IS enforced** (changed 2026-06-19): you start with 4 slots and buy up to 10 with Data Shards. The stock "has space for perk" gate is honored via the per-player `acc_perks::acc_perk_slot_limit` hook; hitting your limit shows the Neural-Expansion prompt (see [Perk-Slot Rule](#perk-slot-rule--start-at-4-buy-more-with-data-shards-user-2026-06-19)), not the old silent deny.

## Powerup Interactions

- **Insta-Kill**: Deadshot's +1.3 headshot bonus still applies during Insta-Kill (redundant for regulars since they insta-die, but relevant for elites/bosses).
- **Double Points**: 2x base kill Points BEFORE 70/30 split, Payroll Ledger's +10% on top.
- **Max Ammo**: no perk interaction.
- **Carpenter**: no perk interaction.
- **Perk Bottle** (random perk drop): not in v1.0.

## Co-op Perk Rules

- Perks are **per-player**.
- No shared lockout — multiple players can buy the same perk at the same machine simultaneously.
- Reviving does NOT drop perks.
- Dying (not reviving from down in time) drops all perks.

## Full Stacking Example — "Swiss Army Player" Build

A player with **all 10 live perks** + boss items + PaP L5 + Tier 5 FAL (plus the Cyberware tree, if its **dormant** nodes are re-enabled — docs/03):

- **HP**: **250 HP** → down on the 6th with Jug; **300 HP** → down on the 7th with Ultimate Tank.
- **HP regen**: starts 20% sooner (Quick Revive) / 40% sooner (Savior).
- **Revive**: 2.0 s (Quick Revive) / 1.0 s (Savior). Savior also takes **−50% damage while reviving** a teammate.
- **Reload**: +50% reload (Speed Cola) / +75% (Sleight of Hand Expert).
- **Move / sprint**: ~12 s sprint + ~7–8% move (Stamin-Up); +15% sprint speed (The Flash); +15% move while a teammate is down (Savior); plus Boss-item speed terms (Neural Boots ×1.20), and Cyberware speed terms only if the dormant tree is re-enabled (multiplicative).
- **Fire rate**: **+33%** (Double Tap 2.0 base, stock — both base and Mega). Mega **Gun Slinger** adds **no** fire rate or weapon-swap bonus (reworked 2026-07-04 to a pure damage buff). Base fires an extra bullet per shot tempered 0.7× → ~1.86× DPS; Mega eases the temper to 0.9× → ~2.39× DPS.
- **Headshot damage**: the map's **multiplicative** headshot temper (×2.5 trash via `ACC_HEADSHOT_MULT 0.5` / ×4 boss via `ACC_BOSS_HEADSHOT_MULT 0.8`, on a `locHead 5` gun), plus Deadshot **+1.3** / American Sniper **+1.5** added into the separate crit-bonus pool; recoil none (base) / −50% (Mega-only).
- **Weapon slots**: 3 primaries (Mule Kick); +20% reserve refill each round & all buys 10% cheaper (The Armory).
- **Crowd control**: Widow's Wine web grenades + self-defense webbing + webbing melee (2-per-round stock restock; low-stance mobility + boosted spider-drops with Spiderman); PhD Flopper slide-to-explode nova clears zombies (and explodes when you go down) — immune to fall + your own splash damage throughout.

Add **2 Boss Items** + **PaP L5 + Tier 5 with 5 Overclocks** on 2 weapons + the **Exo Suit** = our peak power fantasy (and the **Cyberware full branch** on top, if its dormant tree is re-enabled — docs/03). Reaching that takes a full 30+ round commitment; it's a reward for sustained play, not a baseline.

## Implementation Status

> **⚠️ Spec finalized 2026-06-14; GSC reconciled to it the same day, and kept current since.** The requirements are the **table + per-perk prose above**. The ledger below is the **implemented-vs-spec status** after the overhaul. The old pre-finalization audit (further down) is kept only for code-location (`file:line`) reference — trust the ledger, not that table.

### Implemented ledger (code now matches the spec)

**Legend:** ✅ done in GSC (cited) · 🎨 GDT/APE only — no GSC lever, see [30](21_adding_a_gun_runbook.md)/[31](21_adding_a_gun_runbook.md) · 🧪 confirm number in-game.

- **Jugger-Nog** — ✅ base 250 HP (125 base + `_acc_perks.gsc` `ACC_JUGG_HEALTH_ADD=125`); ✅ Ultimate Tank 300 HP (`_acc_mega_bottles.gsc` `n_player_health_boost=50`). *(The boss-zap protection now lives on **Mega Electric Cherry "Power Surge"** as a **−10% softening** — moved Jug→Widow's→Electric Cherry, settled 2026-06-25, softened from full immunity 2026-07-03; enforced in the `_acc_elites` zap applicators off `specialty_combat_efficiency`.)* 🧪 confirm 6/7 hit counts.
- **Quick Revive** — ✅ base revive 2.0s / Savior 1.0s (`_acc_perks.gsc::qr_revive_time` via `self.get_revive_time` hook; watcher `qr_revive_watcher`); ✅ base regen 20% / Savior 40% sooner (`qr_regen_booster`, `ACC_QR_REGEN_DELAY_BASE=0.80` / `_SAVIOR=0.60`); ✅ Savior +15% speed (`savior_speed_watcher` + `_acc_utility.gsc:155`); ✅ Savior **−50% damage while reviving** (`_acc_perks.gsc::savior_revive_damage_mult`, `ACC_SAVIOR_REVIVE_DMG_TAKEN=0.50`, applied in `_acc_elites::on_player_damaged`).
- **Speed Cola** — ✅ +50% reload + barrier (stock); ✅ Mega +75% reload via the `fastreload` weapon-variant twin (`reloadTime ×0.857` layered on the engine +50%; baked 2026-06-14, `_acc_weapon_variants.gsc::axis_reload`); ✂️ faster perk-drink **cut** (shared map-wide anim, no per-perk lever). Weapon-swap is **not** a perk effect (the old Gun Slinger −50% swap twin was removed 2026-07-04; swap time is stock for everyone).
- **Double Tap 2.0** — ✅ **kept as stock Double Tap 2.0** (`specialty_doubletap2`, the engine extra bullet) — the "convert to a rate-only 1.0" plan is **cancelled** (can't strip the extra bullet from a usermap); priced **3,000** (`set_perk_costs`, lowered from 5,000 on 2026-06-25); ✅ each DT bullet **tempered to 0.6×** (`ACC_DOUBLETAP_DMG_MULT`, user 2026-06-25) → net **~1.6× DPS** (the old flat +3%/+6% damage layer was removed 2026-06-14); ✅ **Gun Slinger reworked 2026-07-04 to a damage buff only** — the extra-bullet temper eases **×0.6 → ×0.8** for Mega holders (`acc_doubletap_mega_dmg_mult = 0.8`, runtime in `_acc_damage.gsc` via `has_mega_perk`) → ~**2.1× DPS**. The old `fastfire` fire-rate/swap twin (`fireTime ×0.69` + raise/drop `×0.5`) was **removed entirely** 2026-07-04 (fire axis deleted from `_acc_weapon_variants.gsc`, `apply_recoil_overhaul.js`, the GDT, and the zone). Card "Double Tap 2.0".
- **Stamin-Up** — ✅ base stock sprint; ✅ The Flash ×1.15 move (`_acc_utility.gsc:151`); ✅ sprint-duration override removed (`_acc_mega_bottles.gsc`).
- **Mule Kick** — ✅ base 3rd primary (stock); ✅ Armory **+20% reserve refill each round** (a SUSTAIN refill toward each gun's existing cap, not a cap raise — `armory_refill`; was +25%-capacity, reworked 2026-06-16, rate 35%→20% on 2026-06-21); ✅ Armory **all buys 10% cheaper at POINT OF SALE** (charge **and** displayed price) — done by **vendoring 5 stock files** and repurposing the dormant `pers_double_points` cost hook (gated on the Armory Mega flag, ×0.9): `_zm_pers_upgrades_functions` (perk + stock-PaP charge), `_zm_weapons` (wallbuy/ammo — inert now wall buys are removed), `_zm_magicbox` (box, per-player), `_zm_perks` (perk hint), plus `_acc_pap_levels` tier-up. The old spend-rebate (`armory_discount_watcher`) was **removed**. Co-op display reflects the toucher on shared triggers (perks); box/tier are per-player-exact. See docs/16 + CHANGELOG. ✅ +2 grenade fill removed.
- **Deadshot** — ✅ base **+1.3** headshot (`_acc_damage.gsc` `ACC_DEADSHOT_MULT 1.3`) + ADS snap, no boss; ✅ American Sniper **+1.5** headshot (`ACC_DEADSHOT_MEGA_MULT 1.5`, replaces base — no double dip; was 1.8→1.6→1.5); both **add** into the crit/headshot bonus pool (additive stacking, 2026-06-14), not multiply; ✅ base = **no recoil change** (recoil is Mega-only since 2026-06-16); Mega American Sniper **−50% recoil** via the `recoil50` twin (`recoil ×0.50` off the **1.75×** map base → ~**0.875× vanilla**; `axis_recoil` returns `recoil50` for Mega only).
- **Widow's Wine** — ✅ base webs / self-defense / webbing melee (stock mechanics, **NERFED 50% all-around 2026-07-17**: contact web 50% proc / melee web 25% / cocoon 8 s / slow 6 s — `_acc_perks.gsc` `ACC_WW_*` pointer-swap wrappers + duration watchdog; strength fractions stay stock); ✅ +50% frag damage removed; ✅ Spiderman **melee OHK REMOVED** (user 2026-06-29 — Mega Widow's melee now does normal damage; was briefly re-added 2026-06-18 in `_acc_damage.gsc`, web-grenade OHK stays removed); ❌ the custom Spiderman **web-grenade virtual pool** (6-cap + 4/round restock: `acc_web_pool` / `web_grenade_pool_watcher` / `web_grenade_manage_watcher` / `widow_round_restock_watcher`) and the **WEB GRENADES** HUD counter (`sync_web_grenades_to_client`) were **all REMOVED 2026-06-24** (`_acc_mega_bottles.gsc:1012-1014`) — Mega Widow's now uses **stock web-grenade behavior**; the GDT clip-cap raise of doc 30 stays **ABANDONED** (infeasible in a usermap).
- **PhD Flopper** — ✅ **live.** Custom ability hijacking the registered stock `_zm_perk_electric_cherry` pipeline + machine: `_acc_perk_phd_flopper.gsc` overwrites the cherry cost/hint/give/take (cost **2,500**) and installs a `level.perk_damage_override` immunity func, then layers our own ability (adapted from the shipped HarryBo21 / ColDog PhD Flopper): ✅ immunity to fall damage **and** your own explosive / grenade / projectile splash; ✅ dive-to-prone grenade-explosion nova (jump → slide with a real height drop); ✅ explode-on-down last-stand. The underlying specialty stays `specialty_electriccherry` (HasPerk / rotation / HUD / Mega plumbing key off it). The old `_acc_perk_electric_cherry.gsc` was **deleted**. ✅ **PhD Slider** Mega is a **working tier** (not a TODO) — read live from the Mega flag: radius **250u** (HALVED from 500, user 2026-06-27), **≤10 zombies hit per slide**, and **damage frozen at round-16 zombie HP** (one slide one-shots trash ≤r16, then 2/3 slides past it). 🎨 machine = stock placeholder `p7_zm_vending_nuke` (fits PhD's explosion theme, avoids a game-rip vending import); icon = Ronan "exo_flopper" (`i_acc_perk_phd_base`/`_mega`); bottle = stock `zombie_perk_bottle_cherry`.
- **Electric Cherry** — ✅ **live.** The **real 10th perk**, a from-scratch ability on the unused `specialty_combat_efficiency` (NOT the cherry pipeline PhD hijacks): `_acc_perk_electric_cherry.gsc`, cost **3,000**, own Lab machine (`vending_acc_electric_cherry`, the **real cherry vending model `electric_cherry_model`** — EC-machine-only lift from [West] Community Perk Collection v2.7, 2026-07-01; replaced the `p7_lab_bio_machinery_01` lab-prop stand-in used while the stock `p6_zm_vending_electric_cherry_on/_off` names were unpackable — external pack, see `tools/external_assets_manifest.ps1` + CREDITS.md) + own perk door + red/teal perk-bar icon (`i_acc_perk_cherry_{base,mega}`). ✅ reloading fires an electric nova electrocuting nearby zombies, radius/damage scaling with clip emptiness (empty mag = big blast — fixes the stock 1/10 stub); **8** targets / **6s** cooldown; survivors get the real tesla stun + shock FX. ✅ **Power Surge** Mega (read live off the Mega flag): **+50% damage, 12 targets, 4s cooldown** (user 2026-07-08, was 5s; radius NOT raised — `EC_RADIUS_MAX_MEGA` 200 ≤ base 220, by design — its edge is damage/targets/cooldown), **AND boss-zap softening** — boss zap slows (Phantom / Rogue Protector / Avogadro) land at **−10% instead of −30%** (`_acc_elites.gsc` gates on the **persistent** `specialty_combat_efficiency` Mega flag; was full immunity, softened 2026-07-03; the Battery boss item fully absorbs zaps and supersedes this for its holder, docs/09). Card "Electric Cherry" / "Power Surge". LUI card index **10** (PaP shifted to 11).

---

**Original pre-finalization audit (for code locations only):** Audited 2026-06-13, GSC fixes applied 2026-06-14 (24-agent audit → per-perk research+verify → hand-applied, `lint_gsc_xref.js` clean). The non-GSC remainder is detailed in **[21_adding_a_gun_runbook.md](21_adding_a_gun_runbook.md)**.

> **⚠️ The Status column in the table below is PRE-FINALIZATION and now STALE.** It predates the 2026-06-14 weapon-variant twin matrix + perk overhaul. Several rows are wrong — e.g. Speed Cola "+65% / drink", "Double Tap 2.0", American Sniper "×1.75 / no recoil", Deadshot "−25% / −50%", and the "GDT-only / cut" verdicts on reload / recoil (now **built** via `_acc_weapon_variants.gsc` twins; the fire-rate `fastfire` twin was built then **removed 2026-07-04** — Gun Slinger is now a runtime damage buff). **Trust the "Implemented ledger" above, not this table** — it's kept only for the `file:line` code citations.

**Status legend:** **OK** = real code grants it (cited). **OK\*** = GSC implemented
but the exact tuning number needs an in-game confirm (depends on a baked GDT
constant). **PARTIAL** = GSC half done, full magnitude needs a GDT bump (doc 30).
**STOCK** = provided by the stock pipeline once the specialty is given. **GDT** =
no GSC lever; needs an Asset-Editor edit (doc 30). **MISSING** = no backing /
spec blocker.

### Two cross-cutting facts

1. **Baked weapon stats are delivered via the weapon-variant twin matrix** (UPDATED
   2026-06-14 — this fact was originally "zero `.gdt`, no GSC lever"). The map now ships
   `source_data/acc_weapon_variants.gdt` (generated by `tools/apply_recoil_overhaul.js`):
   recoil and reload timing are each a cloned
   "twin" GDT the GSC swaps in while the qualifying perk is held (`_acc_weapon_variants.gsc`
   axes). So Deadshot recoil and Sleight reload are **built**, not "no GSC lever". *(Two other
   axes were retired: the Gun Slinger fire-rate/swap `fastfire` twin was **removed 2026-07-04**
   — Gun Slinger is now a runtime damage buff — and the Armory ammo-capacity axis was removed
   2026-06-16 for a runtime reserve refill; only recoil + reload remain as twin axes.) Blast radius (Widow frag) is still an APE-only GDT edit —
   see [doc 30](21_adding_a_gun_runbook.md).
2. **`_acc_perks.gsc` now exists** (authored 2026-06-14) and hosts the base-perk
   GSC retuning (Jug 3/6, QR regen, Savior revive + speed). Cap-removal stays
   inline in the entry script.

### Per-perk ability ledger

**Citations re-verified 2026-06-14** against literal code by a 55-agent audit
(each requirement opened + adversarially refuted; stale line numbers corrected
below). The earlier prose `45`-damage melee assumption was disproved and the
grenade-fill field bug was found and fixed — see the notes.

| Perk (specialty) | Ability | Status | Where (or why not) |
|---|---|---|---|
| **Jug** (`armorvest`) | base 6-hit model | OK\* | `_acc_perks.gsc::tune_jugg_health` sets `zombie_perk_juggernaut_health=125` → **250 HP** (125 base + 125 add; base 100→125 but Jug add 150→125 so Jug STAYS 250, user 2026-07-16; read live by `_zm_perks.gsc:803`). **Melee correction:** the open-field melee that downs you is a **baked GDT stat NOT readable from script** — the in-script `60` (`_zm_spawner.gsc:358`) is the *board-hit* value, and "@ melee 45" was an unverified assumption. Exact hit count **must be confirmed in-game**; if not 6, retune `ACC_JUGG_HEALTH_ADD` (base-health floor = `ACC_PLAYER_BASE_HEALTH`) |
| | cost 4,000 | OK | `zm_abandoned_cyber_city.gsc:326` |
| | Mega Ultimate Tank +1 hit | OK\* | `_acc_mega_bottles.gsc:418` armorvest case = `+50` HP → **300 HP**, survives revives via stock `health_reboot` recompute. "+1 over base" inherits base Jug's in-game melee confirmation |
| | Mega boss-ability immunity | OK | `_acc_boss.gsc::protect_immune_players_during_debuff` re-grants immune holders' perks during disable_*_for. *Caveat: power-off is a global flag, so the holder's traps still go dark — only owned perks are preserved* |
| **Quick Revive** (`quickrevive`) | base faster teammate revive | STOCK | `_zm_laststand.gsc:1156` halves revive to 1.5s when the reviver owns the specialty |
| | base +30% HP regen after damage | OK\* | `_acc_perks.gsc::qr_regen_booster` (regen window opens ~30% sooner, then parallel ramp). *Verified: ZM has NO per-player regen-rate hook (MP-only), so "earlier start" is the strongest GSC-reachable interpretation — design call: accept, or reword card to "+30% faster regen start"* |
| | base solo self-revive; cost **500** (co-op 2,500) | STOCK / OK | `.cost` = `&quickrevive_cost` fn ptr (returns 500 when `zm_perks::use_solo_revive()`); stock reads it live at `_zm_perks.gsc:490` (machine) + `:386` (hint) |
| | Mega Savior revive ×0.6 | OK | `_acc_perks.gsc::savior_revive_time` via `self.get_revive_time` hook, consumed at `_zm_laststand.gsc:1163` (1.5s→0.9s; sole writer of the hook — grep-confirmed) |
| | Mega Savior +15% move while teammate down | OK | `_acc_perks.gsc::savior_speed_watcher` + `×1.15` term in `_acc_utility.gsc:155` |
| | Mega Savior −50% damage while reviving | OK | `_acc_perks.gsc::savior_revive_damage_mult` (×0.50, gated on Mega QR + `self.is_reviving_any > 0`) applied in `_acc_elites::on_player_damaged` after Exo resist; stock counter held the whole channel (`_zm_laststand.gsc:1208`/`:1285`) |
| **Speed Cola** (`fastreload`) | base +50% reload + barrier | STOCK | engine response to the specialty |
| | base ~40% shorter drink; ~30% faster swap; cost 3,500 | GDT / OK | **No GSC lever (proven):** grep over stock = zero drink-/swap-time setters; anim/timing assets, APE-only and map-wide — [doc 30](21_adding_a_gun_runbook.md); cost `…gsc:328` |
| | Mega +65% reload / +15% switch / +15% drink | GDT | no GSC reload/swap setter (proven); unconditional GDT or **cut** — [doc 30](21_adding_a_gun_runbook.md) |
| **Double Tap 2.0** (`doubletap2`) | base +33% fire rate | STOCK | engine-granted free with the specialty (doc abstracts DT to damage-only) |
| | base bullet damage ×0.7 temper | OK | `_acc_damage.gsc` (`ACC_DOUBLETAP_DMG_MULT 0.7`, user 2026-07-17 was 0.6): the stock extra bullet can't be stripped in a usermap, so each DT bullet is cut to 0.7× → net **~1.86× DPS** (2 × 0.7 × +33% RoF), not a flat 2×. Allow-list `weapon_gets_dt_bullet` (bullet guns only); base AND Mega. *(The old +3% damage layer was removed 2026-06-14.)* |
| | cost 3,000 | OK | `set_perk_costs` (`specialty_doubletap2 = 3000`; 5,000 → 3,000 user 2026-06-25) |
| | Mega Gun Slinger damage buff (temper ×0.6→×0.8) | OK | **Reworked 2026-07-04.** Gun Slinger is now a pure **runtime damage** buff: the extra-bullet temper eases ×0.6 → **×0.8** for Mega holders (`acc_doubletap_mega_dmg_mult = 0.8`, `_acc_damage.gsc` via `has_mega_perk`) → ~**2.1× DPS** vs base ~1.6×. The old **`fastfire` fire-rate/swap twin** (`fireTime ×0.69` + raise/drop ×0.5, `axis_fire`) was **removed entirely** — fire axis deleted from `_acc_weapon_variants.gsc`, [apply_recoil_overhaul.js](../tools/apply_recoil_overhaul.js), the GDT, and the zone (frees 8 twins/gun, 224 → 96 total) |
| | ~~Mega Gun Slinger +6% flat damage~~ | REMOVED | The old flat +6% damage layer was removed 2026-06-14. *(Gun Slinger was later **reworked 2026-07-04** into a damage buff via the extra-bullet temper ease ×0.6→×0.8 (since eased to ×0.7→×0.9, user 2026-07-17) — see the row above; the +45% fire rate + −50% weapon-swap `fastfire` twin was removed with it.)* |
| **Stamin-Up** (`staminup`) | base longer/faster sprint; cost 2,000 | STOCK / OK | engine-driven; cost `…gsc:330` |
| | Mega Flash +15% move | OK | `_acc_mega_bottles.gsc:509-512` sets the flag → `_acc_utility.gsc:298` `n_scale ×1.15` (uniform move scalar) |
| | ~~Mega Flash longer sprint / +12% run~~ | SUPERSEDED | Replaced by the single ×1.15 move scalar above (2026-06-14 overhaul): `SetSprintDuration` was removed; base sprint (~12 s) unchanged |
| | Mega Flash ×2 walk / ×4 crawl | **cut** | **Engine-impossible (proven):** grep over stock returns ONLY `SetMoveSpeedScale` (uniform) + `SetSprintDuration` — no per-stance walk/crawl setter exists in GSC, GDT, or Radiant. Strike from the card |
| **Mule Kick** (`additionalprimaryweapon`) | base third primary; cost 2,500 | STOCK / OK | pure stock (owning the specialty grants the 3rd slot — **no `additionalprimaryweapon_limit=3` line exists in our code**; old citation was wrong); cost `…gsc:331` |
| | Mega Armory +2 lethal / +2 tactical | PARTIAL | `armory_apply` fills the **lethal/tactical CLIP** to cap (**field bug fixed 2026-06-14:** `SetWeaponAmmoStock` → `SetWeaponAmmoClip`; ZM carries grenades in the clip, `_zm.gsc:4582`). The `+2`-over-stock needs the grenade-GDT carry cap raised in APE — [doc 30](21_adding_a_gun_runbook.md) |
| | Mega Armory +20% reserve refill / round | DONE | Reworked 2026-06-16 to a runtime **sustain refill** (NOT a cap raise): `armory_refill` tops each carried gun's reserve toward its existing baked cap by **+20%** every round start + instantly on acquire (was "+25% capacity" via an ammo twin — that ammo axis was REMOVED; rate lowered 35%→20% on 2026-06-21). No twin / no GDT cap-raise needed. |
| **Deadshot** (`deadshot`) | base ADS head-snap, no boss snap | STOCK + OK | stock snap; boss snap suppressed by `DisableAimAssist()` on the boss actor (`_acc_boss.gsc:218,371`) |
| | base +1.3 headshot (additive); cost 3,500 | OK / OK | `_acc_damage.gsc:452-459` (`ACC_DEADSHOT_MULT 1.3`, added into the crit bonus pool); cost in `set_perk_costs` |
| | Mega American Sniper +1.5 headshot (replaces +1.3) | OK | `_acc_damage.gsc:456-457` (`ACC_DEADSHOT_MEGA_MULT 1.5`, true if/else, no double-dip) + −50% recoil twin |
| | Mega no recoil | GDT | **No GSC recoil setter exists** (grep = only vehicle/turret kick fields). Needs a `_norecoil` weapon-variant swap in APE — [doc 30](21_adding_a_gun_runbook.md) — or cut |
| | Mega snap still on regulars/elites | STOCK | stock |
| **Widow's Wine** (`widowswine`) | base webs / melee / defense | STOCK | stock |
| | ~~base +50% frag damage~~ | REMOVED | The base frag-damage layer was removed (2026-06-14 overhaul, `_acc_damage.gsc:543-544`); base Widow's is pure-stock web behavior now |
| | base +25% frag radius | GDT | `explosionRadius` ×1.25 in APE — [doc 30](21_adding_a_gun_runbook.md). (A GSC `RadiusDamage`-on-detonation hack exists but double-counts + ignores falloff — APE preferred) |
| | base +50% EMP stun / +25% radius; cost 4,000 | **strike** | **Spec blocker (proven):** stock Widow's Wine registers NO EMP component — no asset to edit, no hook tying EMP to `specialty_widowswine`. Re-scope or strike. cost `…gsc:333` |
| | ~~Mega Spiderman melee OHK zombies~~ | REMOVED | The Mega one-hit melee was removed 2026-06-29 (user); a Mega-Widow's melee now deals normal melee damage (see `_acc_damage::on_ai_damage` Widow's note). |
| | ~~Mega Spiderman web-grenade OHK~~ | REMOVED | Not in the code (grep: no `w_widows_wine_grenade` damage path); Mega Widow's web grenades are stock now. Mega Widow's also gains **low-stance speed** (crouch ×2.6 / prone ×10 / down ×15, `_acc_mega_bottles::mww_stance_factor`) |
| | ~~Mega Spiderman 6 web grenades~~ | REMOVED | The custom 6-grenade virtual pool + 4/round restock + WEB GRENADES HUD were **removed 2026-06-24** (user). Mega Widow's web grenades use **stock** behavior now (the GDT carry cap was never raisable, docs/21 abandoned). |
| | ~~Mega Spiderman boss-special immunity~~ | MOVED | Boss-special immunity moved OFF Mega Widow's to **Mega Electric Cherry "Power Surge"** (2026-06-25) — the power/perk-disable half (`_acc_boss::protect_immune_players_during_debuff`) is **DEAD** since the full boss that cast it was removed 2026-06-22 (unreachable code); the surviving half is `_acc_elites::acc_phantom_chain_zap`/`acc_protector_zap` gating on `specialty_combat_efficiency`. **Boss STUN softened, not immune (user 2026-07-03):** Mega Electric Cherry takes any boss slow (Phantom / Rogue Protector / Avogadro) to a flat **-10%** (`acc_boss_slow_mega_mult 0.90`) instead of 0%, vs the normal **-30%** (`acc_phantom_slow_mult`/`acc_protector_slow_mult`/`acc_avogadro_slow_mult 0.70`; boss stun unified to 30% on 2026-07-05, was 25%). Gate now also covers `_acc_elites::acc_avogadro_zap` |
| **PhD Flopper** (`electriccherry`) | base fall + self-splash immunity; explode-on-down; cost 2,500 | OK | custom ability hijacking the registered stock `_zm_perk_electric_cherry` pipeline + machine — `_acc_perk_phd_flopper.gsc` overwrites cost/hint/give/take + installs `level.perk_damage_override`; specialty stays `specialty_electriccherry`; base nova triggers on DOWN only (explode-on-down). Nova FX = stock ORANGE `level._effect["def_explosion"]` (user 2026-06-25, off the electric spark-burst: *"why does PhD slide spark"*); sound base = `def_explosion`'s own boom, Mega = `evt_nuke_flash` whoomp; prior `_acc_perk_electric_cherry.gsc` deleted |
| | Mega PhD Slider (**slide-to-explode** + bigger/stronger slide + down explosion) | OK | **Slide-to-explode is MEGA-ONLY (user 2026-06-26)** — base no longer detonates on a slide (`phd_slide_watcher` gates on the Mega flag; dvar `acc_phd_base_slide_nova`). Mega tier read live from the Mega flag: radius 300→**250u** (Mega HALVED, user 2026-06-27), **≤10 zombies hit/slide** (`acc_phd_max_hits`), **damage FROZEN at round-16 zombie health** (one slide one-shots trash ≤r16, then 2/3 slides past it; `ACC_PHD_FREEZE_ROUND 16`, co-op-scaled, dealt raw via the `acc_phd_nova_hit` bypass; user 2026-06-27), **10s→8s** slide cooldown, +15% explosive, ×1.5 slide speed |

### Shared systems

- **Buyable perk slots — OK (changed 2026-06-19).** Base `level.perk_purchase_limit = 4`
  (`zm_abandoned_cyber_city.gsc`); the per-player limit is lifted to as high as **10** by the stock
  hook `level.get_player_perk_purchase_limit` = `acc_perks::acc_perk_slot_limit` (consumed by the
  live buy-gate `_zm_utility.gsc:5876`/`:5889`). Extra slots are bought with Data Shards at the
  Neural Expansion Bay (escalating 4/6/8/10/12/14). NOT the old no-cap design.
- **Per-round gating — now the map-wide SCATTER; door layer retired; machine-reskin path STUB.**
  Per-round texture ships as `_acc_perk_scatter.gsc` (perk→pad reshuffle every 3rd round; the
  4-of-10 alcove-door lockout ran 2026-06-16 → 2026-07-24, and the door geometry itself was
  deleted 2026-07-25). The older
  machine-reskin rotation is inert: `roll_perk_rotation()` rolls/stores fine, but
  `apply_perk_rotation_to_machines` is a `TODO(acc-geom)` stub and **no `acc_lab_perk_*` entities
  exist in Radiant**, so that array is never consumed — see [Rotating Lab machines (unbuilt
  alternative)](#rotating-lab-machines-unbuilt-alternative). A headless gate on the existing machines
  via `level.custom_perk_validation` (`_zm_perks.gsc:560-562`) also exists but is unused — the door
  layer is the shipped answer.
- **Mega Bottle system — OK; all 10 Mega effects live.** drop / inventory / apply / flag /
  persistence all real (SH-3 fully verified). **All 10 Megas fire:** Ultimate Tank, Savior,
  **Sleight of Hand Expert** (built via the `fastreload` weapon-variant twin, `_acc_weapon_variants.gsc::axis_reload`),
  Gun Slinger (extra-bullet temper ×0.7→×0.9, reworked 2026-07-04; eased 2026-07-17), The Flash, The Armory, American
  Sniper (headshot + `recoil50` twin), Spiderman, **PhD Slider** (radius 300→250u / frozen round-16-HP
  damage / ≤10 hits per slide), and **Power Surge** (EC — +50% dmg / 12 targets / 4s cd / boss-zap
  softening). All read live from the persistent Mega flag.

### Remaining work (re-verified 2026-06-14, 55-agent audit)

**Every GSC-reachable lever is pulled.** The one remaining GSC defect found by the
audit — the grenade-fill targeting the unused reserve instead of the clip — **was
fixed 2026-06-14** (`_acc_mega_bottles.gsc`, Spiderman + Armory cases now use
`SetWeaponAmmoClip`). What is left is **physically not GSC-reachable** and falls into
four buckets (proof for each in the per-perk ledger above + [doc 30](21_adding_a_gun_runbook.md)):

- **APE GUI (weapon GDT, interactive — can't be done headlessly):** Widow +25% frag radius
  (`explosionRadius`) · Mule Armory +2 grenade cap + +30% gun reserve. *(Deadshot Mega −50% recoil
  and Sleight of Hand Expert +75% reload are already **BUILT** via the `recoil50` / `fastreload`
  weapon-variant twins — no longer remaining work. The old **Gun Slinger +45% fire rate** `_fastfire`
  swap was **removed 2026-07-04** — Gun Slinger is now a runtime damage buff, no twin.)* Full
  click-by-click steps: **[21_adding_a_gun_runbook.md](21_adding_a_gun_runbook.md)**.
  *The stock weapon **stat** files are baked in the base fastfiles — not editable text in
  this public-tools install — so these require APE's weapon editor + a full rebuild.*
- **Radiant (interactive):** the 4 `acc_lab_perk_*` rotating Lab machines — an **unbuilt alternative**
  that the door layer already superseded; details in [Rotating Lab machines (unbuilt
  alternative)](#rotating-lab-machines-unbuilt-alternative). Not needed for shipped per-round gating.
- **Engine-impossible (grep-proven, no lever ANYWHERE — not even APE):** The Flash
  ×2 walk / ×4 crawl (only a uniform move scalar exists). → **struck from cards 2026-06-14.**
- **Cut by design (no stock asset):** Widow's Wine EMP line. → **struck from cards 2026-06-14.**
- **Design decisions (yours to make):** Speed Cola Mega timing (cut from card vs ship
  unconditional map-wide — the GDT edit is NOT perk-gateable) · QR "+30% regen" wording
  (accept "earlier start" vs reword) · in-game confirm of Jug 6/7 hit counts (depends on
  the baked open-field melee GDT value, **not** the doc's old `45` assumption).

The custom perks (Deadshot, PhD Flopper) follow the custom perk template workflow in [14_stock_api_verification.md](14_stock_api_verification.md) section 5. PhD Flopper hijacks the registered stock electric-cherry pipeline + machine for its slot (`_acc_perk_phd_flopper.gsc`) while keeping the `specialty_electriccherry` specialty, then layers its own ability in our code.

## Tuning Levers

If perks feel broken after playtest:

- **Jug**: the **3 / 6 / 7** hit model — retune the HP adds (250 base / 300 Mega) if hit counts drift.
- **Deadshot**: +1.3 / +1.5 headshot bonus (additive) → lower if the headshot ceiling is too high.
- **Mule Kick (Armory)**: 10% discount / +20% reserve refill each round → trim if economy or ammo trivializes late game.
- **Stamin-Up (The Flash)**: +15% sprint speed → lower if speed-running trivializes late rounds.
- **Quick Revive (Savior)**: 1.0 s revive / +15% speed / −50% damage while reviving (`ACC_SAVIOR_REVIVE_DMG_TAKEN`) → raise the multiplier toward 1.0 (less reduction) if reviving in a horde becomes too safe.
- **PhD Flopper (PhD Slider)**: scale back the dive / down explosion radius (300u base / 250u Mega), the Mega's per-slide hit cap (`acc_phd_max_hits`, default 10), or move the Mega's frozen-damage breakpoint (`acc_phd_freeze_round`, default 16) earlier/later, if it over- or under-clears.

Numeric levers live in `_acc_perks.gsc` / `_acc_mega_bottles.gsc` / `_acc_damage.gsc` constants (incl. the Gun Slinger damage temper `acc_doubletap_mega_dmg_mult`); reload timing / recoil are GDT (APE). *(Fire rate is no longer a lever — the `fastfire` twin was removed 2026-07-04.)*

## Out of Scope for v1.0

- **Other stock perks not listed above** (Tombstone, Vulture-Aid, etc.) — each adds pipeline complexity and isn't worth the authoring budget. (PhD Flopper IS in the roster — perk #9.)
- **Perk-a-Holic** powerup (random perk drop): scope cut.
- **Perk Shuffle** modifier: fun idea, not in v1.0.
- **Perk animations / custom bottle art**: stock bottles for all 10 in v1.0 (PhD Flopper and Electric Cherry already get custom Ronan perk-bar icons); a later art pass (Phase 5) may add distinct bottles.
