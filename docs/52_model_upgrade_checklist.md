# 52 — Model-Upgrade Checklist (stock xmodel swaps)

Master checklist for upgrading PLACEHOLDER / generic / ill-fitting world models to
better-fitting **stock BO3 xmodels**, now that the full asset catalog can be browsed
(Greyhound). 36 models audited across stations/kiosks, pickups, bosses/enemies, and props.

---

## ❌ ATTEMPTED + REVERTED — 2026-06-22 (the model swaps below DO NOT PACK in our Mod Tools)

> **BUILD OUTCOME (the verdict that overrides everything below):** all 11 swapped models — **including
> the "Tier-A proven" zod ones** — logged `ERROR: xmodel '<name>' is missing` and were **REVERTED**.
> **Hard lesson:** the **Greyhound catalog is a dump of models loaded in the GAME at runtime, which is
> NOT the same as what the Mod Tools LINKER can pack.** The linker needs the model's *source asset* in
> the install's GDT/asset DB; for almost all catalog models (zod / moo / cai-beyond-ours) that source
> is absent. The ONLY models that pack are the small set already on our `.zone` and proven by a prior
> build (the list in `_acc_*` today). The "zod family = proven" reasoning was WRONG — `p7_zm_zod_nitrous_tank`
> packs because *its* source happens to be installed, not because the whole zod family is. See memory
> `greyhound-catalog-not-modtools-packable`. **The station de-dup is BLOCKED** until a packable distinct
> model is found (would need extracting/GDT-authoring the model sources into the Mod Tools — out of scope).
>
> **What DID ship from this audit (proven client-FX / already-packed assets, no new xmodel):**
> Subroutine Core boss = teal eye-tint + `accPhantomAura` glow (model unchanged — distinct from the
> plain horde by glow, not mesh); Shielded elite = `wpn_t7_zmb_zod_rocket_shield_world` Attach (already
> on `.zone`); Teleporter + EMP elites = teal eye-tint (shared color — 1-bit field). `zombietron_gold_brick`
> turned out to pack fine on this install, so the Loot Stash kept it.

<details><summary>Original (now-obsolete) audit plan — kept for reference only; do NOT re-apply</summary>

The Greyhound export (`tmp/model_catalog.txt`, a Moon/Zombies-Chronicles session) was mined +
adversarially loadability-checked. **Key finding:** the safe, ship-now backbone is the base-game
**`zod` (Shadows of Evil)** family — already proven packable here (`p7_zm_zod_nitrous_tank`, .zone
199). The on-theme **Moon `moo_*` consoles** are Tier-B (DLC source may be absent from base Mod
Tools) → **one build-verify batch**, fall back if `is missing`. **Bug caught:** `zombietron_gold_brick`
is NOT in the catalog (external/asset-pack → fails on a fresh clone) — the Loot Stash swap fixes it.

**TIER A — ship now (zod = base game, high confidence; build still confirms each name):**

| Slot | Current | → New | File |
|------|---------|-------|------|
| Exo Suit Station | `p7_cai_work_table_metal_03_white` | `p7_zm_zod_fungus_pod` | `_acc_exo.gsc:24,93` |
| Glitch Altar base | `p7_cai_sign_inteactive_kiosk` | `p7_zm_zod_table_ritual` | `_acc_glitch_altar.gsc:35,91` |
| Reactor Plinth | `p7_cai_sign_inteactive_kiosk` | `p7_zm_zod_power_box_yellow` | `_acc_reactor.gsc:30,74` |
| Plaza Implant Bench | `p7_cai_work_table_metal_03_white` | `p7_zm_zod_beast_basin_pap` | `_acc_boss_items.gsc:56,1058` |
| Loot Stash (+pts) | `zombietron_gold_brick` *(BROKEN)* | `p7_zm_zod_magic_box` | `_acc_boss_items.gsc:148` |
| Phase Serum (cloak) | `zombie_pickup_perk_bottle` | `p7_zm_zod_magicians_drink_bottle` | `_acc_boss_items.gsc:55,192` |
| **Subroutine Core boss** | plain zombie (no SetModel) | `c_zom_zod_zombie_body1` + `c_zom_zod_zombie_head1_1` + teal eyes + aura | `_acc_boss.gsc:392` |
| **Shielded elite** | plain zombie | Attach `wpn_t7_zmb_zod_rocket_shield_world` (already packs, .zone 203) | `_acc_elites.gsc:237` |
| **Teleporter elite** | plain zombie | distinct `accEyeTint` only (no model) | `_acc_elites.gsc:248` |
| **EMP elite** | plain zombie | distinct `accEyeTint` only (no model) | `_acc_elites.gsc:276` |
| Phantom (if re-enabled) | Giant reskin | `c_zom_zod_zombie_body3`+`head3` + diff aura | `_acc_boss_phantom.gsc:222` |

**REJECTED:** Repair Kit → `p7_zm_power_up_max_ammo` (audit pick) — *overruled, KEEP carpenter*: a
Max-Ammo bullet icon reads "ammo" not "heal", no better than carpenter's "repair". No ZM medkit exists.

**TIER B — BUILD-VERIFY BATCH (add all to .zone, ONE `-GscOnly` build, revert any that log `is missing`):**
`p7_zm_moo_console_control_screen_on` (Overclock terminal, fallback `p7_zm_moo_console_control` → else keep
ticket kiosk) · `p7_zm_moo_console_monitor` (Neural Bay → else keep kiosk) · `p7_zm_moo_space_suit_boots`
(Boots → else keep `p7_boots_safehouse_01`) · *(optional)* `p7_zm_moo_server_comm_02` (Data Cache) ·
*(stretch)* `p7_zm_moo_capsule_biolab_base` (better Exo pod) · `p7_zm_ctl_vril_generator_complete` (Gorod, Reactor core).

**STAR DISCOVERY:** `c_zom_zod_robot_protector_fb` — a giant SoE "Protector" robot (Tier A). Best used as a
**static derelict-guardian landmark prop**, NOT a boss SetModel (unique skeleton ≠ base zombie rig).
*(Also unpackable on this install — same `is missing` fate as the rest.)*

</details>

---

## How a model upgrade works (read first)

- **Stock xmodels need NO bundling.** Unlike custom sounds (48k wav + locked `.sabs`
  bank, see memory `custom-sound-48k-and-game-lock`), a stock xmodel loads **by name**
  from the base game. An upgrade = change the `setmodel()` / `model=` reference to a
  nicer stock model name. Nothing to download or pack.
- **Two edits per swap** (proven by every existing entry in the `.zone`):
  1. Change the `setmodel( "old" )` (and matching `#precache( "model", "old" )`) in the `.gsc`.
  2. Replace the `xmodel,old` line with `xmodel,new` in
     `zone_source\zm_abandoned_cyber_city.zone` (current xmodel lines: 198–215).
  Script-spawned `script_model`s in this map are all `setmodel()` calls — there are no
  Radiant prefab model refs in scope. Boss reskins (`SetModel`/`Attach`) are GSC-only but
  still need their model on an `xmodel,` line (e.g. `c_zom_der_zombie_body1` is line 179).
- **Build = `-GscOnly`.** A model-name swap touches no geometry/BSP/lightmap, so the fast
  linker-only path is correct; **no LED bake needed** (LED gate only applies to
  geometry/`.map`/material/sky changes). Re-add the `.zone` line, sync, `-GscOnly`.
- **The build ERRORLOG is the oracle for "does it pack."** A stock xmodel is safe if it is
  zone-packed (our `xmodel,` line) OR runtime-loaded by stock (memory
  `stock-pickup-model-safety`). If a candidate is **campaign-only** it logs
  `xmodel '<name>' is missing` and falls back / shows nothing — that already bit the
  Repair-Kit syringe (`p7_medical_surgical_tools_syringe` = campaign, missing in ZM).
  **Always confirm a NEW model in the build ERRORLOG before keeping it.**
- **Greyhound is for BROWSE/CONFIRM only** — preview the mesh + confirm the exact xmodel
  name. The actual pack-test still happens in the build ERRORLOG.
- **Naming convention:** a non-`_set` folder name == the xmodel name. `_set` folders hold
  numbered members (`..._01`, `..._02`); confirm the exact member suffix in Greyhound /
  ERRORLOG. Names flagged **(CONFIRM)** below are best-guess — verify before wiring.

---

## 1. Stations / Kiosks (the machines the player interacts with)

These are the highest-visual-impact items — the player walks up to them every round.
**Big secondary win: de-duplicate.** `p7_cai_sign_inteactive_kiosk` is reused 4 ways
(Glitch Altar base, Neural Expansion Bay, Reactor Plinth, Perk vendor) and
`p7_cai_work_table_metal_03_white` 3 ways (Exo station, Cyberware kiosk, Plaza Implant
Bench) — so multiple distinct stations look identical and confuse the player.

| ✔ | Thing | Current model | File:line | Verdict | Suggested upgrade | Pri |
|---|-------|---------------|-----------|---------|-------------------|-----|
| [ ] | Exo Suit Upgrade Station | `p7_cai_work_table_metal_03_white` | `_acc_exo.gsc:93` (precache :24) | placeholder-upgrade | Generic white work-table as a body-augment station (file comment: "a freestanding metal bench"). Swap to a cyber pod/console. Best: `p7_sgen_dni_testing_pod` (Corvus DNI neural/cyberware chamber). Alt: `p7_lab_bio_machinery_01`, `p7_lab_machine_chemical`. (CONFIRM names) | **high** |
| [ ] | Weapon Overclock terminal | `p7_cai_ticket_kiosk_theatre` | `_acc_overclocks.gsc:230` (precache :43) | placeholder-upgrade | A movie-THEATRE ticket kiosk as a gun-tier upgrade bench — thematically wrong. Swap to a tech/control console. Best: `p7_zur_house_control_panel` or `p7_sin_bio_fastpass_machine` (sci-fi scanner). Alt: `p7_tech_panel_metal_01`, `p7_inf_dni_monitor_large`. (CONFIRM names) | **high** |
| [ ] | Plaza Implant Bench | `p7_cai_work_table_metal_03_white` | `_acc_boss_items.gsc:56,1058` | placeholder-upgrade | Plain white campaign work-table as a high-tech "Implant Bench". Strongest proven-in-map fit: `p7_cai_sign_inteactive_kiosk` (consistent station language, already packs here). Or a ZM vending/PaP chassis (`p7_zm_zod_pap_table_mod` — CONFIRM). | **high** |
| [ ] | Neural Expansion Bay (+1 Perk Slot) | `p7_cai_sign_inteactive_kiosk` | `_acc_perks.gsc:162` | ok-could-improve | Bland for a brain/neural upgrade AND identical to the Altar + Reactor. Give a distinct DNI look: `p7_sgen_dni_testing_pod` (neural pod) or `p7_inf_dni_monitor_large` / `p7_cai_monitor_wall_large`. De-duping is the main win. (CONFIRM names) | medium |
| [ ] | Glitch Altar — kiosk BASE | `p7_cai_sign_inteactive_kiosk` (base) | `_acc_glitch_altar.gsc:91` | ok-could-improve | The floating orb core (below) is great — keep it. The BASE is the same sign kiosk as Neural Bay + Reactor. Give an occult/corrupted-tech pedestal: `p7_zur_house_control_panel` or `p7_lab_machine_chemical`. Low stakes (orb sells it); priority = de-dupe. (CONFIRM names) | medium |
| [ ] | Reactor Surge Arm Plinth | `p7_cai_sign_inteactive_kiosk` | `_acc_reactor.gsc:74` (precache :30) | ok-could-improve | Third identical use of the sign kiosk. A "Reactor" arm console should read power/industrial: `p7_zur_house_control_panel`, `p7_tech_panel_metal_01`, or `p7_lab_bio_machinery_01` for a reactor-core feel. (CONFIRM names) | medium |
| [ ] | Cyberware skill-tree kiosk (`spawn_kiosk_at`) | `p7_cai_work_table_metal_03_white` | `_acc_cyberware.gsc:419` (precache :47) | ok-could-improve | **DEAD CODE** — `glitch_altar.gsc` no longer calls `spawn_kiosk_at` (Cyberware tree removed 2026-06-19, replaced by the Overclock terminal). Not placed in-game today. If revived, use `p7_sgen_dni_lab_module` (CONFIRM `_set` member suffix) or `p7_lab_bio_machinery_01`. | low |
| [ ] | Glitch Altar — floating orb CORE | `p7_fxanim_zm_stal_ray_gun_ball_mod` | `_acc_glitch_altar.gsc:94` | good-keep | Spinning Ray-Gun energy orb — on-theme, keep. No change. | low |
| [ ] | Data Cache crate (`spawn_cache_at`) | `p7_cai_stacking_cargo_crate` | `_acc_data_shards.gsc:71,213` (precache :46) | good-keep / ok-could-improve | Coalescence cargo crate reads fine as a lootable cache & stays in the `p7_cai_` family. Optional flavor for a stronger "DATA" read: a ZM supply box (`p7_zm_zod_supply_box` — CONFIRM) or a server/screen container. Not placeholder; lowest priority. | low |

---

## 2. Pickups / Boss items (carried world models)

| ✔ | Thing | Current model | File:line | Verdict | Suggested upgrade | Pri |
|---|-------|---------------|-----------|---------|-------------------|-----|
| [ ] | Data Shard pickup (currency orb) | `p7_fxanim_zm_stal_ray_gun_ball_mod` | `_acc_data_shards.gsc:70,174` | good-keep | Glowing energy orb = perfect "Data Shard". Best-in-class for the slot. No change. | low |
| [ ] | Repair Kit (HP regen) | `p7_zm_power_up_carpenter` | `_acc_boss_items.gsc:52,159` | ok-could-improve | Carpenter (hammer+nails) reads "repair barriers", not a personal med kit. Ideal syringe `p7_medical_surgical_tools_syringe` is **campaign-only (missing in ZM)** — confirmed fail. If Greyhound surfaces ANY zm-packable medkit/first-aid/stim/battery prop, swap; else keep carpenter (safe fallback). **Verify-then-keep.** | medium |
| [ ] | Loot Stash (+10% Points) | `zombietron_gold_brick` | `_acc_boss_items.gsc:148` | ok-could-improve | Gold brick = money/points, intent good. Code comment marks it **"TESTING packability + .zone line"** and `zombietron_*` may be non-stock/asset-pack. **Confirm it packs (ERRORLOG).** Fallback: a stock zod gold-bar/treasure or briefcase, or a cyber credits-chip prop. | medium |
| [ ] | Boots (+8% move + trench-slow immunity) | `p7_boots_safehouse_01` | `_acc_boss_items.gsc:203` | ok-could-improve | Literal boots = correct intent. Comment flags **"TESTING — needs .zone line; reverts to perk bottle if it can't pack"**; `safehouse` is a campaign-leaning prefix (common `is missing` risk). **Confirm it packs;** if it fails, find a zm-packable footwear/exo-boot prop rather than the perk-bottle fallback. *(Note: `xmodel,p7_boots_safehouse_01` IS present in .zone line 201 — so it should pack; verify in ERRORLOG.)* | medium |
| [ ] | Phase Serum (cloak) | `zombie_pickup_perk_bottle` | `_acc_boss_items.gsc:55,192` | ok-could-improve | Generic perk bottle reads "a perk", not a "serum/vial", and is ambiguous next to real perk machines. A distinct syringe/vial would help but campaign vials are missing in ZM. Low urgency — bottle is runtime-loaded & proven; the prompt name carries it. | low |
| [ ] | Gas Tank (nitro burst) | `p7_zm_zod_nitrous_tank` | `_acc_boss_items.gsc:49,126` | good-keep | Zod nitrous tank = exactly "Gas Tank", ZM-stock, build-verified. No change. | low |
| [ ] | Li'l Arnie (grants Octobomb) | `p7_fxanim_zm_zod_octobomb_mod` | `_acc_boss_items.gsc:50,137` | good-keep | IS the stock Octobomb model — drop matches what it grants. No change. | low |
| [ ] | Rocket Shield (mobility) | `wpn_t7_zmb_zod_rocket_shield_world` | `_acc_boss_items.gsc:53,170` | good-keep | Actual stock Rocket Shield world model, 1:1, comment "good as-is". No change. | low |
| [ ] | Monkey Bomb (grants Cymbal Monkey) | `wpn_t7_zmb_monkey_bomb_world` | `_acc_boss_items.gsc:54,181` | good-keep | Stock Cymbal Monkey world model, matches the tactical exactly. No change. | low |
| [ ] | Mega Bottle pickup/drink | *(none — HUD counter + perk-bottle viewmodel weapon)* | `_acc_mega_bottles.gsc:260-309` | good-keep | No world-drop model spawned; awarded to HUD, "drink" replays stock perk-bottle viewmodel. Nothing to upgrade. | low |
| [ ] | Emergency Drop powerups | *(none custom — stock `specific_powerup_drop`)* | `_acc_emergency_drop.gsc:116-150` | good-keep | Spawns genuine stock Max Ammo / Insta-Kill / Double Points / Random Perk models. The Ronan power-up ICON reskin is HUD/LUI-only, not a world model. Nothing in scope. | low |

---

## 3. Bosses / Enemies

| ✔ | Thing | Current model | File:line | Verdict | Suggested upgrade | Pri |
|---|-------|---------------|-----------|---------|-------------------|-----|
| [ ] | **Subroutine Core — the FULL boss (r30/r40+)** | Plain promoted stock zombie, **NO SetModel** → inherits the charred-horde skin; flagged `TODO(acc-model)` | `_acc_boss.gsc:390-434` (`:392`) | placeholder-upgrade | **HIGHEST-VALUE.** The marquee boss looks like a normal zombie. Apply the proven headless `SetModel` idiom (Glitch/Phantom use it): `SetModel` + Detach charred head + Attach stock head, **NO SetScale** (the `0xC0000005` crasher). Best free imposing skin that shares the `base` rig: `c_zom_der_zombie_body1` + `c_zom_der_zombie_head1` (already link-proven & in .zone, lines 179/185), or a heavier armored skin. Pair with teal/cyan `acc_lui::set_actor_eye_tint` + the existing `accPhantomAura` body-glow `.csc` FX to distinguish from the horde. No new assets. | **high** |
| [ ] | **Elite zombies: Shielded / Teleporter / EMP** | Plain promoted stock zombie, **NO SetModel / no prop attach** → identical to a regular zombie; `TODO(acc-model)` | `_acc_elites.gsc:229-277` (Shielded `:237`) | placeholder-upgrade | **Elites are unreadable.** Give each a cheap stock-only tell: (1) **Shielded** — Attach a stock riot/ballistic shield xmodel (`t6_wpn_zmb_shield_*` / stock riotshield world — CONFIRM) to a hand/torso tag, OR SetModel to a stock armored/helmeted zombie skin; (2) **Teleporter** — a distinct eye-tint colour via the `accEyeTint` clientfield so the blinker reads at range; (3) **EMP** — a small attached emitter/antenna prop or another eye colour. Even per-class eye-tints alone = legible with zero new assets. Same headless `SetModel`/`Attach` + eye-tint toolbox as the boss. | **high** |
| [ ] | Glitch Stalker mini-boss (r3, then every 10) | `c_zom_der_zombie_body1` + `c_zom_der_zombie_head1` reskin + teal eyes | `_acc_boss_glitch.gsc:275-289` | ok-could-improve | Deliberate, link-verified reskin; identity = blink + teal eyes, not the mesh. Optional polish: add the existing cyan `accPhantomAura` `.csc` aura for a stronger glitch/hologram read. Not a placeholder — leave the model. No new assets. | low |
| [ ] | Phantom / "Reaper" mini-boss (~r10; **disabled by default**) | Same Giant reskin as Glitch Stalker + cyan eyes + cloak + `accPhantomAura` | `_acc_boss_phantom.gsc:220-231` (`ENABLE_DEF 0` at `:60`) | ok-could-improve | Identity = cloak + cyan aura + eyes; body hidden most of the time, so the Giant body is acceptable. Comment (`:57`): reads as a redundant clone of the Glitch Stalker (why it's off). If re-enabled, differentiate the MESH (a different free stock zombie skin) + a different aura colour so the two aren't twins. Off by default → lower priority. No new assets. | medium |
| [ ] | Brutus / Trench Warden mini-boss (r10/r20) | NSZ Brutus pack (BO2-port custom AITYPE) | `_acc_boss_brutus.gsc:20,38,58` | external-pack | **Keep as-is.** Genuine custom imposing boss mesh from an external (gitignored) pack — NOT stock. Swapping would lose the unique BO2 Brutus identity. Note: a fresh clone needs the NSZ bundle or the linker fails `no file for filespec`. | low |
| [ ] | Panzer mini-boss (former ~r10) | **REMOVED** — `_acc_boss_panzer.gsc` + `mechz_spiki.gsc/.csc` deleted; stale comment refs only | deleted file; comments at `_acc_boss_phantom.gsc:57`, `_acc_boss_glitch.gsc:16`, `_acc_perk_phd_flopper.gsc:270` | good-keep | No Panzer model in live code. Optional: scrub the stale "Panzer" comment mentions so the next agent doesn't think one spawns. Not a model issue. | low |

---

## 4. Props / World (invisible or already-good)

| ✔ | Thing | Current model | File:line | Verdict | Suggested upgrade | Pri |
|---|-------|---------------|-----------|---------|-------------------|-----|
| [ ] | Lockdown red-alarm FX host | `tag_origin` (script_model) | `_acc_lockdown.gsc:307` | good-keep | **Intentionally invisible** — empty FX-host carrying client-side glow FX (matches the perk-lights pipeline). Nothing to upgrade. | low |
| [ ] | Atmosphere 2D ambient-sound emitter | `script_origin` | `_acc_atmosphere.gsc:389` | good-keep | **Intentionally invisible** — non-positional 2D ambient-sound anchor. Not a visible prop. Nothing to upgrade. | low |

---

## GOOD — LEAVE ALONE (correct/self-documenting stock models)

These already match their effect 1:1 and are build-verified. **No change.**

- **Gas Tank** → `p7_zm_zod_nitrous_tank`
- **Li'l Arnie** → `p7_fxanim_zm_zod_octobomb_mod` (the actual Octobomb)
- **Rocket Shield** → `wpn_t7_zmb_zod_rocket_shield_world`
- **Monkey Bomb** → `wpn_t7_zmb_monkey_bomb_world`
- **Data Shard pickup / Glitch Altar orb core** → `p7_fxanim_zm_stal_ray_gun_ball_mod`
- **Data Cache crate** → `p7_cai_stacking_cargo_crate` (acceptable; optional flavor only)
- **Mega Bottle** — no world model (HUD + viewmodel)
- **Emergency Drop powerups** — stock `specific_powerup_drop` models
- **Glitch Stalker** → Giant reskin (intentional, identity is blink + teal eyes)
- **Lockdown FX host / atmosphere sound emitter** — intentionally invisible

## EXTERNAL PACK — DON'T TOUCH

- **Brutus / Trench Warden** — NSZ Brutus (BO2-port custom AITYPE, gitignored pack).
  A stock swap would LOSE its unique identity. Fresh clones need the NSZ bundle installed
  (`tools/unpack_external_assets.ps1`) or the linker fails `no file for filespec`.

---

## TOP PRIORITY — highest-visual-impact placeholder swaps

Ordered by player-facing impact. The first two are bosses; the rest are interactable
stations the player visits every round.

1. **Subroutine Core (FULL boss)** — `_acc_boss.gsc:392` — the marquee boss looks like a
   normal zombie. Headless `SetModel` (Giant body+head, NO SetScale) + teal eyes + aura.
2. **Elite zombies (Shielded/Teleporter/EMP)** — `_acc_elites.gsc:237` — currently
   indistinguishable from regular zombies. Per-class eye-tint and/or shield attach.
3. **Exo Suit Upgrade Station** — `_acc_exo.gsc:93` — white work-table → DNI testing pod.
4. **Weapon Overclock terminal** — `_acc_overclocks.gsc:230` — theatre ticket kiosk →
   tech/control console.
5. **Plaza Implant Bench** — `_acc_boss_items.gsc:1058` — white work-table → kiosk/PaP chassis.
6. **Neural Expansion Bay** — `_acc_perks.gsc:162` — de-dupe from altar/reactor → DNI pod/monitor.
7. **Reactor Surge Plinth** — `_acc_reactor.gsc:74` — de-dupe → power/industrial console.
8. **Glitch Altar base** — `_acc_glitch_altar.gsc:91` — de-dupe → occult/corrupted pedestal.
9. **Loot Stash** — `_acc_boss_items.gsc:148` — verify `zombietron_gold_brick` actually packs.
10. **Repair Kit** — `_acc_boss_items.gsc:159` — carpenter → a zm-packable medkit if one exists.

The big theme: **de-duplicate the 4× `p7_cai_sign_inteactive_kiosk` and 3×
`p7_cai_work_table_metal_03_white`** so distinct stations stop looking identical.

---

## MODELS TO FIND IN GREYHOUND (preview / confirm names)

Flat list of every suggested stock model. **Preview the mesh + confirm the exact xmodel
name in Greyhound, then confirm it packs in the build ERRORLOG.** Items marked
**(CONFIRM)** are best-guess names from memory — verify before wiring. The `p7_cai_*`
"Coalescence Corporation" Singapore campaign family is the in-theme cyber-city set;
`p7_sgen_/p7_inf_/p7_sin_` DNI props read as neural/cyberware tech.

**Stations / consoles / kiosks**
- `p7_sgen_dni_testing_pod` — Corvus DNI neural/cyberware chamber (Exo / Neural Bay) **(CONFIRM)**
- `p7_zur_house_control_panel` — cyber control panel/console (Overclock / Reactor / Altar) **(CONFIRM)**
- `p7_sin_bio_fastpass_machine` — sci-fi scanner/fastpass (Overclock terminal) **(CONFIRM)**
- `p7_tech_panel_metal_01` — tech wall/panel (Overclock / Reactor) **(CONFIRM)**
- `p7_inf_dni_monitor_large` — DNI brain-interface monitor (Neural Bay) **(CONFIRM)**
- `p7_cai_monitor_wall_large` — Coalescence wall monitor (Neural Bay) **(CONFIRM)**
- `p7_lab_bio_machinery_01` — sci-fi lab machine (Exo / Cyberware / Reactor) **(CONFIRM)**
- `p7_lab_machine_chemical` — lab chemical machine (Exo / Altar) **(CONFIRM)**
- `p7_sgen_dni_lab_module` — DNI lab implant module (`_set` member suffix) (Cyberware) **(CONFIRM)**
- `p7_cai_sign_inteactive_kiosk` — **already packs in this map** (.zone line 213); proven station chassis
- `p7_zm_zod_pap_table_mod` — ZM Pack-a-Punch table chassis (Implant Bench) **(CONFIRM)**

**Pickups / loot**
- `p7_zm_zod_supply_box` — ZM supply box (Data Cache flavor) **(CONFIRM)**
- a zm-packable medkit / first-aid / stim / syringe / battery prop (Repair Kit) — **name unknown, hunt in Greyhound** *(campaign `p7_medical_surgical_tools_syringe` = missing in ZM, do NOT use)*
- a stock zod gold-bar / treasure / briefcase / cyber credits-chip prop (Loot Stash fallback) — **name unknown, hunt in Greyhound** *(verify `zombietron_gold_brick` packs first)*
- a zm-packable footwear / exo-boot prop (Boots fallback) — **name unknown** *(verify `p7_boots_safehouse_01` packs first — it has a .zone line, line 201)*

**Boss / enemy reskins**
- `c_zom_der_zombie_body1` + `c_zom_der_zombie_head1` — Giant body+head, **already pack** (.zone 179/185); for the Subroutine Core
- `t6_wpn_zmb_shield_*` / stock riotshield world model — Shielded-elite shield attach **(CONFIRM exact name)**
- a different free stock zombie skin (armored / burned / cosmonaut-style) for a re-enabled Phantom — **name unknown, hunt in Greyhound**

---

## Reference: existing `.zone` xmodel lines (the swap target)

`zone_source\zm_abandoned_cyber_city.zone` (lines 198–215) — replace the relevant
`xmodel,<old>` with `xmodel,<new>` when swapping:

```
198  xmodel,p7_fxanim_zm_stal_ray_gun_ball_mod   # Data Shard orb / altar core (KEEP)
199  xmodel,p7_zm_zod_nitrous_tank               # Gas Tank (KEEP)
200  xmodel,p7_fxanim_zm_zod_octobomb_mod        # Li'l Arnie (KEEP)
201  xmodel,p7_boots_safehouse_01                # Boots (verify packs)
202  xmodel,zombietron_gold_brick                # Loot Stash (verify packs)
203  xmodel,wpn_t7_zmb_zod_rocket_shield_world   # Rocket Shield (KEEP)
204  xmodel,wpn_t7_zmb_monkey_bomb_world         # Monkey Bomb (KEEP)
208  xmodel,p7_cai_work_table_metal_03_white     # Exo / Cyberware / Implant Bench  <-- SWAP TARGET (3 uses)
213  xmodel,p7_cai_sign_inteactive_kiosk         # Altar / Neural Bay / Reactor / Perk  <-- SWAP TARGET (4 uses)
214  xmodel,p7_cai_stacking_cargo_crate          # Data Cache crate (KEEP / flavor)
215  xmodel,p7_cai_ticket_kiosk_theatre          # Overclock terminal  <-- SWAP TARGET
```

> If a station is split to a NEW distinct model (de-dup), ADD a new `xmodel,<new>` line
> rather than replacing — the shared model is still used by the other stations until they
> too are swapped. Each `setmodel()` change must have its `#precache` updated and its model
> on an `xmodel,` line, then `-GscOnly` build and read the ERRORLOG for `is missing`.
