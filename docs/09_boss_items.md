# 09 - Boss Items

Machin[a]-style randomized passive-buff items dropped on boss kills. Shape your build around what bosses give you; high variance, high reward.

## At a Glance

- **11 items** in the drop pool: Gas Tank, Loot Stash, Repair Kit, Rocket Shield, Phase Serum, Boots, Lucky Horseshoe, **Turbocharger (Havoc)** (a hyper-niche Havoc-only mod, added 2026-07-07), **Nuclear Energy** (+15% explosive & energy damage, added 2026-07-07), **Battery** (boss zaps absorbed → +20% speed surge for 5 s + a blue-green screen aura instead of the slow, 10 s cooldown — buffed from 12 s 2026-07-09, added 2026-07-08), and **Berzerker** (+35% melee swing speed at 5% max HP per connecting melee — regular knife / Leviathan Axe / Action Figure only, added 2026-07-11). The two tactical grenades (Li'l Arnie + Monkey Bomb) were moved to mystery-box rolls 2026-06-24 — see the note under "The items". (Pool + slot count are live in `_acc_boss_items.gsc`: `init()` logs the live `pool=` size, `ACC_ITEM_SLOTS_PER_PLAYER 3`.)
- **3 active items** per player (2 → 3, user 2026-07-09; three bench pads = Slot 1 / 2 / 3, in the Plaza Implant Lab AND Paradise; filling an empty slot is FREE, replacing a full slot = 2500 pts).
- **Every boss drops exactly 1 item, guaranteed** (user 2026-07-07): every roster boss (Phantom / Rogue Protector / Avogadro / Panzer / Trench Warden-Brutus) routes its death reward through `_acc_boss::grant_unified_boss_reward` → `acc_boss_items::grant_challenge_reward` — the old per-tier chance roll was removed. (`acc_boss_items::on_boss_death` was the legacy full-boss drop path — dead code since the "Subroutine Core" full boss became unreachable 2026-06-22, `_acc_boss.gsc:118` / README.) **Exception:** the **Glitch Stalker** is a *frequent* mini-boss (1–3 every round) and deliberately does **not** drop items (killer gets 1 Data Shard instead) — dropping every round would flood the pool (`_acc_boss_glitch::glitch_death_watch`, user 2026-06-22).
- **Every dropped item glows** (user 2026-07-07): a small coloured "loot" glow (default dim amber) makes pickups easy to spot on the dark ground. Uses the client-side `acc_perk_lights` glow pipeline; live dvar `acc_item_glow_color` (0 = off). The glow despawns with the pickup. The aura sits at **ground level** — anchored to a separate invisible `tag_origin` host at the drop origin (a few units under, live dvar `acc_item_glow_z`), NOT on the lifted item model — so it reads as a pool of light on the floor beneath the item rather than floating above it. The host is torn down with the pickup in `cleanup_pickup()`.
- **Regular zombies** also have a tiny drop chance (user 2026-06-27; rates halved 2026-06-29): every non-boss zombie death independently rolls **0.2%** to drop a random pool item (free-for-all world pickup) **and** **0.2%** to grant **one Empty Mega Bottle to the killer only** (direct grant, not shared). **The Lucky Horseshoe raises BOTH to 0.3%** (×1.5) for its carrier — so 0.2% normally, 0.3% with the Horseshoe. Bosses/mini-bosses are excluded (they keep their guaranteed drops). Live dvars: `acc_zombie_item_drop_chance` / `acc_zombie_bottle_drop_chance` (default `0.002`). Code: `_acc_boss_items::on_zombie_death_drop`.
- **Duplicates** (user 2026-07-08 rework): an item you already have **IMPLANTED** (any slot) **cannot be
  grabbed at all** — the grab is refused ("Already implanted" print) and the pickup **stays on the ground**
  (glow + 60 s lifetime intact) so a teammate who lacks it can still take it. Per-grabber check, so co-op
  free-for-all drops behave correctly. Only a duplicate of your loose **CARRY** (picked up, not yet enabled —
  transient per-player state no teammate can see or use) still converts to 3 Data Shards.
- **Drops always land on the floor** (root-caused 2026-07-08 after "still floating — the glow is airborne
  too"): every drop origin routes through **`acc_utility::drop_floor_origin`**. A plain down-trace from the
  death origin **starts inside the dying enemy's own body** — a solid AI hit returned the hit ON the corpse,
  which pinned hovering-boss drops (Rogue Protector / Avogadro) mid-air; ground zombies never showed it. The
  helper **steps through ACTOR/PLAYER hits** (≤8 × 4u) down to real **world geometry** (stock idiom
  `fraction < 1 && !isdefined(tr["entity"])`), accepts solid non-AI surfaces (brushmodel bridges/platforms),
  and keeps the origin on a true miss (never buries). Live dvar `acc_drop_floor_snap` (1 = on); step/miss
  diagnostics on the dev `drops_debug` channel. Model seats were verified against the props' real
  `.xmodel_bin` vertex bounds — all three 4×-scaled props are base-pivot (≤2u error), so `model_z` values
  stand; `acc_drop_scale_lift_add` (additive, scaled items only, default 0) remains as a fine-tune knob.
- **Lost when you DIE OUT** (user 2026-06-26): bleeding out (a real death, not a revived down) wipes **all** implant slots — their buffs go with them, and you respawn implant-less and must find + re-implant new ones. A revived down keeps your implants. Implemented in `_acc_boss_items::lose_implants_on_bleed_out` (per-player stock `"bled_out"` notify). Also no persistence across runs (run-end resets everything).

## Separate From Mega Bottles

**This doc covers the 11-item implantable pool only.** Bosses also drop a separate **Empty Mega Bottle** resource (guaranteed per player per boss kill) used to upgrade perks to their Mega variants. Mega Bottles do not take the active-item slot and are not part of the pool described here. See [10_perks.md](10_perks.md#mega-bottles-system) for the Mega Bottle acquisition + persistence rules; per-perk Mega effects are under **Perk reference (base + Mega)** in the same doc.

## Drop Mechanics

> **v4 (2026-07-09): THREE active slots.** (v3 2026-06-23 introduced the bench-gate with
> two slots.) Picking an item up only CARRIES it; you ENABLE its buff at an Implant Bench —
> **three pads** (Slot 1 / 2 / 3 — you pick which slot by which pad you use), in both the
> Plaza Implant Lab and Paradise. Filling an EMPTY slot is **free**; once all slots are
> full, implanting another **replaces that pad's slot for 2500 pts**. So any empty slot is
> always free ("first three free"). A sound plays on each implant.

```mermaid
flowchart LR
    Kill[Boss killed] --> Drop[Item drops at corpse<br/>hold ⓕ Use = GRAB]
    Drop --> Roll{Already have it?}
    Roll -->|IMPLANTED| Refuse[Grab refused - item STAYS<br/>on the ground for teammates]
    Roll -->|same loose CARRY| Dust[Converts to 3 Data Shards]
    Roll -->|No| Carry[CARRY it]
    Carry --> Bench[Implant Bench pad 1/2/3<br/>hold ⓕ Use = ENABLE the buff]
    Bench -->|empty slot| Free[FREE]
    Bench -->|replace a full slot| Cost[costs 2500 points]
```

### Acquisition flow
1. **Bosses drop items.** Every boss kill drops a random pool item at the corpse, **guaranteed** (user 2026-07-07; the frequent Glitch Stalker is the exception — it gives a Data Shard instead). Hold **ⓕ Use** to **grab** it — this only **carries** it (HUD: `CARRYING <item>`); the buff is NOT active yet. Uncollected drops despawn after **60 s** (`ACC_ITEM_DROP_LIFETIME_SEC`). Grabbing an item you already have **IMPLANTED** is **refused** — the pickup stays on the ground for teammates (user 2026-07-08; was a +3-shard conversion that consumed the drop). Grabbing a duplicate of the item you already loosely **carry** → **+3 Data Shards**. Grabbing a NEW item while already carrying a different (un-enabled) one **drops the old one back to the ground** (re-grabbable) — it's never lost. (An already-implanted item stays implanted.)
2. **Enable it at an Implant Bench** — the Plaza bench is in the gated **Implant Lab** side-room off the Plaza spawn (buy the tight-entrance door, `enter_implant`, **1500**, to reach it; 2026-06-26). **Three pads** (2 → 3, 2026-07-09), Slot 1 / 2 / 3, spread as a **staggered arc** across the room (**relayout 2026-07-10**: the lab was **widened east** — wall x-40 → x180, room now x[-720,180] — and the three pads moved out of the old tight south-wall row into the open EAST clear area, clear of the Exchange staircase's SW corner and every wall — user "the 3 benches are cluttered and one is right next to a wall"). Hold **ⓕ Use** on a pad to **implant** the carried item into that slot → buff goes active (HUD: `IMPLANT 1 <item>` / `IMPLANT 2 <item>` / `IMPLANT 3 <item>`). A confirmation sound plays. Paradise has its own 3-pad row (south-west, by the Mystery Box).
3. **Three active items at a time** (2 → 3, user 2026-07-09). Implanting into an **empty** slot is **FREE** (so your first three are free). Once **all** slots are full, using a pad **replaces that pad's slot** for **2500 points** (removing that slot's previous buff) — you choose which to lose by which pad you use. Carrying a new item does nothing until you bench it.
   - **The single engine tactical slot** is shared by the two box-rolled grenade weapons (Li'l Arnie + Monkey Bomb — see the note below; they are NOT boss-drop implants). The engine has only one tactical, so the **last one granted is the grenade you actually throw** ("last one wins", `player.acc_tactical_owner`); losing it hands the tactical back to the other.

### The items (pool of 11)

> **The two tactical-grenade items moved OUT of this pool (user 2026-06-24).** Li'l Arnie (Octobomb) and
> Monkey Bomb (Cymbal Monkey) are no longer boss drops — they are now rare **mystery-box** tactical pre-rolls
> (Monkey Bomb **1%** / Li'l Arnie **0.5%**). See
> [`_acc_map_randomizer.gsc::acc_box_tactical_preroll`](../scripts/zm/zm_abandoned_cyber_city/_acc_map_randomizer.gsc)
> + `acc_boss_items::watch_box_tactical_grab`. After they left, the pool was 6; items **7–10** (Lucky
> Horseshoe / Turbocharger / Nuclear Energy / Battery / Berzerker) were added later, so the live pool is **11** (IDs 1–11).

| ID | Item | Model | Buff | How to use |
|----|------|-------|------|-----------|
| 1 | **Gas Tank** | nitrous tank (`p7_zm_zod_nitrous_tank`) | **Nitro burst** — +100% move speed for 5 s | **Double-tap the Sprint button** to trigger. Runs the full 5 s (uncancellable), then a **60 s** lockout — can't re-trigger until fully recharged. A **NITRO bar** on the left HUD shows the charge: full **cyan** = ready; it drains to empty over the burst, then refills **orange** over the 60 s regen. |
| 2 | **Loot Stash** | locked money bag (`p7_wes_money_bag` — T7 Assets carve 2026-07-08; was the gold brick) | **+10 pts/kill, flat** — NO headshot tier, and **Double Points does NOT boost it** (DP still ×2's the base kill points, just not this bonus; user 2026-06-29 nerf, was 10/15 +5/+10 DP). A **Nuke still pays the holder 500** (scaled by Double Points). | Passive, KILLER only. Logic in `_acc_points` (`award_killer_with_ledger` + `ledger_nuke_watch`; `ACC_LEDGER_KILL 10` / `ACC_LEDGER_NUKE 500`). |
| 3 | **Repair Kit** | first-aid box (`p7_spl_first_aid_box` — T7 Assets carve 2026-07-08; was the carpenter power-up icon) | **+10 HP/sec** passive health regen (user 2026-07-11: back to 10, was briefly 13; `ACC_OVERCHARGE_REGEN 10`) | Passive (caps at max health; pauses while downed). |
| 4 | **Rocket Shield** | rocket shield (`wpn_t7_zmb_zod_rocket_shield_world`) | **Mobility** — **+75% speed while sliding** (×1.75), a forward lunge on slide-start, **2× jump height** (×1.42 velocity ≈ 2× apex) | Passive — just slide and jump. (user 2026-07-05: slide →1.75×; dvars `acc_rocket_slide_mult` / `acc_rocket_jump_mult` / `acc_rocket_slide_kick`) |
| 5 | **Phase Serum** | MOTD surgical vial (`p7_zm_mob_vial_surgical_lrg` — T7 Assets carve 2026-07-08; was the generic perk bottle) | **Phase-boss suppression aura** (user 2026-06-29 nerf, was a cloak; Phantom added 2026-07-11) — any **Glitch Stalker within ~350u is slowed to 1/5 speed AND loses its blink** (its glitch ability), and any **Phantom in the same aura is slowed by 30%** (milder: its gait only — teleports keep working). Both can still SEE + chase you — just hindered, not blinded. Regular horde unaffected. | Passive. Dvars `acc_phase_serum_radius` (350) / `acc_phase_serum_slow` (0.2, Glitch) / `acc_phantom_serum_slow` (0.7, Phantom). Aura check shared in `acc_utility::serum_aura_active`; consumers `_acc_boss_glitch::acc_serum_suppressed` + `_acc_boss_phantom::phantom_speed_think`. |
| 6 | **Boots** | boots prop (`p7_boots_safehouse_01`) | **Mobility** — **+8% move speed everywhere**. (Does NOT cancel the trench slow — user 2026-06-21; only the Exo Suit does that, `_acc_utility.gsc:495`, docs/29.) | Passive. (user 2026-06-18) |
| 7 | **Lucky Horseshoe** (was "Lucky Clover" — renamed 2026-07-08 to follow the real model; internal id `lucky_clover` + all `acc_clover_*` dvars unchanged) | vintage iron horseshoe (`p7_ra2_tool_vintage_horseshoe` — T7 Assets carve 2026-07-08; no clover/charm model exists in ANY T7 source, the horseshoe is the luck icon) | **Drop luck** — while implanted, YOUR kills raise the zombie random-item + Mega-Bottle drop chance from **0.2% → 0.3%** (×1.5, `acc_clover_mult`) **and** add a **0.5%/kill** chance to drop a random power-up (full_ammo / insta_kill / double_points / nuke), bypassing the per-round cap, **and boost mystery-box rare odds**. Works in Paradise. | Passive, KILLER only. Per-player. Live dvars `acc_clover_mult` / `acc_clover_powerup_chance` / `acc_clover_box_*`. (user 2026-06-27, retuned 2026-06-29, box-luck nerfed 2026-07-05; **defaults rescaled 2026-07-09** — the old thresholds were tuned for the 482-weight pool and had silently become a no-op after the 2026-07-06 pool rescale to ~3400+) |
| 8 | **Turbocharger (Havoc)** | car carburetor (`p7_ban_debris_car_carburetor` — T7 Assets carve 2026-07-08; was the Insta-Kill orb) | **Havoc-only — 0 charge-up time.** While implanted, any **Havoc** (the Apex beam rifle) the carrier holds fires with **no wind-up** — the script charge gate is skipped, so it rips like a normal auto instead of the 1.25 s spool. **Deliberately hyper-niche: does nothing unless you actually own a Havoc** (equip it without one and it's a wasted slot). The `(Havoc)` in the name is the on-screen tell. | Passive. Read by `_acc_havoc_charge` via `self.acc_item_turbocharger` (set by `apply_turbocharger`). (user 2026-07-07) |
| 9 | **Nuclear Energy** | nuke power-up orb (`p7_zm_power_up_nuke` — stock, runtime-loaded, no zone line) | **+15% explosive & energy damage.** While implanted, the carrier's hits that are **explosive** (grenades / launchers / any `MOD_EXPLOSIVE`/`MOD_PROJECTILE` — `is_explosive_mod`) **or** from an **energy weapon** (Havoc / Tac-19 / AE4 / RW1 / Blast-O-Matic / Thundergun — `is_energy_weapon`) deal +15% (additive bonus layer, same shape as the Mega Flopper explosive +15%). Plain bullet/melee guns are unaffected. | Passive. Read by `_acc_damage::on_ai_damage` via `attacker.acc_item_nuclear` (set by `apply_nuclear_energy`). `ACC_ITEM_NUCLEAR_MULT` in `_acc_damage.gsc`. (user 2026-07-07) |
| 10 | **Battery** | Der Eisendrache ceramic battery (`p7_zm_ctl_battery_ceramic` — own install-side carve GDT) | **Boss-zap absorber.** While implanted AND off cooldown, a boss zap (Phantom chain special / Rogue Protector close-range zap / Avogadro bolt+aura) does **NOT slow** the carrier — it instead grants a **+20% move speed surge for 5 s** plus a **light blue-green full-screen aura** (the trench-warning tint recipe) and its own distinct **"electric voltage" SFX** (`acc_battery_zap`). Then the battery **recharges for 10 s** (`acc_battery_cooldown_sec`; user 2026-07-09 buff, was 12 s): **one surge per 10 s** (no refresh-on-re-zap). **While the surge is active (the 5 s window) a second zap is absorbed** so it can't hinder your boost (user 2026-07-08 fix — the slow used to multiply against the active surge and net a slowdown); only a zap during the **later recharge window** (surge ended, cooldown not up) slows you normally. The zap's chip **damage still applies** (Avogadro/Protector damage is a separate call) — only the slow is converted. When ready, supersedes the Mega Electric Cherry −10% softening. | Passive. The three zap applicators in `_acc_elites.gsc` gate on `acc_battery_ready()` (`self.acc_item_volt_battery` + cooldown) → `acc_battery_surge()`; boost via `recompute_move_speed`, aura via `battery_aura()`. **NOT the legacy Kinetic Battery** (dormant v1 item; distinct flag on purpose). Dvars `acc_battery_boost_mult` / `acc_battery_boost_sec` / `acc_battery_cooldown_sec` / `acc_battery_aura_alpha`. (user 2026-07-08) |
| 11 | **Berzerker** | Wolf Bow death skull (`rune_prison_death_skull` — already registered install-side by the HB21 bow dep packs, zero new asset work; ×4 scale, added 2026-07-11) | **+35% melee swing speed, paid in blood.** The three melee surfaces swing 35% faster: the **regular knife bash**, the **Leviathan Axe** (stacks with its +10%/PaP-tier spd twins), and the **Action Figure** (stacks with its +33%/tier fast twins). Every melee that **connects** costs **5% of MAX HP** as **real damage** — red flash, and it **resets the engine HP-regen timer** (the point of it being damage); PhD does not negate it (MOD_UNKNOWN); clamped to a **1-HP floor** so it can never down you (at 1 HP you keep the speed and stop paying). Debounced per **swing** (150 ms) — a Leviathan cleave through a crowd taxes once; whiffs are free (only connecting swings pay). Guns are completely untouched; a **Widow's-Wine knife is NOT the regular knife** (no speed, no tax while WW holds the melee slot). | Passive. Speed = pre-baked GDT twins on all three legs (no runtime melee-speed setter exists; `tools/oneshots/gen_berzerker_twins.js`): Leviathan via the `brz` variant axis (`_acc_weapon_variants::axis_brz`), AF via a parallel `_brz` fast-twin ladder (`_acc_pap_levels`), knife via the **EXPERIMENTAL** `acc_berzerker_melee` melee-slot swap (bare-fist swipe — see Caveats). Tax = `_acc_damage::berzerker_melee_tax` off `self.acc_item_berzerker`. Dvar `acc_berzerker_hp_frac` (0.05). (user 2026-07-11) |

All IDs/names show `id - name` in the pickup prompt, the messages, and the HUD. Models are link-verified (errorlog-clean) and per-item floor-lifted (`model_z`) so they don't sink in.

### Real pickup models (T7 Assets carve, 2026-07-08)

Five placeholder models (three power-up orbs + the gold brick + the generic perk bottle) were
replaced with **real props carved from the MidgetBlaster "T7 Assets V2.7" rar** (already in the
user's Downloads — the same proven slice pipeline as the exchange-room decor pilot, see the
`.zone` comment + `tools/external_assets_manifest.ps1` "items slice" entry). Install-side:
`source_data\acc_t7_props_items.gdt` + `model_export\_midgetblaster\props\{p7_mp_waterpark,
p7_mp_wes,p7_mp_rome,p7_zm_genesis,p7_mp_banzai}`. Materials whose colormaps didn't ship in the
dump reference their stock `i_mtl_*_c` names (the pilot's proven stock-resolve pattern; build
errorlog is the verdict). **Playtest polish (2026-07-08, applies to ALL drops):** horseshoe/vial/carburetor
read tiny at 1× → per-item `model_scale` (**×4.0 all three**, user after seeing ×2ish) applied via `SetScale`
in `spawn_pickup` (script_model-safe). The loot glow is now **dim amber** (`acc_perk_lights`
index 13 = amber at **25%** brightness, generated `fx_perk_glow_amber_dim`; Mule Kick keeps full
amber index 5) and sits low (`ACC_ITEM_GLOW_Z_DEF −40`). **Dev-mode visual QA:**
`_acc_boss_items::dev_scatter_items()` lays out one pickup of every pool item on a ground-checked 3×3 grid
(170 u spacing; `find_clear_ground` skips spots whose floor trace lands >24 u above the plaza floor) on the
open Plaza floor — persistent, spawn-struct anchored, `level.acc_dev`-gated per docs/22. The function +
`find_clear_ground()` remain in the file; **re-enable the one line in `init()` for the next model/scale QA
pass** — it takes a space-separated id filter (currently `"turbocharger battery"`, or pass no arg for the
full grid).

### Caveats / honest framing
- **Granting the Octobomb / Cymbal Monkey works via a CSV row only** (no `.zone` weapon line). Both weapon defs already ship in `zm_levelcommon` (the common fastfile every usermap loads — assetlist lines 6175/6225), so a row in `gamedata/weapons/zm/zm_levelcommon_weapons.csv` makes `is_weapon_included` true and `GetWeapon("octobomb"/"cymbal_monkey")` resolves at runtime. **Do NOT add `weapon,<name>_zm` to the `.zone`** — that forces a re-pack from a GDT source not on disk and errors `Unable to load weapon` (an earlier self-inflicted build error, since corrected).
- **The thrown grenade's BEHAVIOR (attract / spore / explode) has to be manually activated — the HACK (2026-06-18).** `GiveWeapon` alone makes the grenade *throwable*, but the thrown projectile "just sits there": the attract/explode logic lives in a per-player watcher thread (`player_handle_octobomb` / `player_handle_cymbal_monkey`) that stock starts ONLY from `zm_weapons::weapon_give`, which fires the registered `level.zombie_weapons_callbacks[weapon]`. Our grant uses a **raw** `GiveWeapon`, which skips that path, so the watcher never starts. Fix: `give_octobomb` / `give_monkey_bomb` now dispatch the callback themselves — `self thread [[ level.zombie_weapons_callbacks[w] ]]()` — **verbatim the stock dispatch at `_zm_weapons.gsc:2791-2793`**. The watchers self-guard (notify/endon), so the revive re-grant is safe; no `#using` or clientfield needed (it's a `level` field). The SoE/DLC3 **spore / glow / lightning FX are absent from this install** so the visuals won't render, but the gameplay (attract + damage + detonate) is fully server-side and works.
- **Rocket Shield "slide lasts 1.5× longer" isn't literally possible** — BO3 exposes no per-player slide-duration lever. Shipped as a **forward distance lunge** on slide-start (slide carries you farther) + the +75% slide speed. The **2× jump height** is a per-player upward velocity **multiply** (×1.42 → apex ~2×, since height ∝ velocity²; NOT the global `jump_height` dvar, which is all-players + persists).
- **Detection uses the right engine builtin per trigger** (the `*_begin` notifies are MP-only, so we poll): Gas Tank double-tap reads **`SprintButtonPressed()`** — the raw sprint-KEY edge — because `IsSprinting()` latches continuously true under ZM auto-sprint and so can never register the second tap (that was the "Gas Tank does nothing" bug). Rocket Shield slide reads **`IsSliding()`** (the dedicated slide-state builtin) because `GetStance()` only ever returns stand/crouch/prone — never a slide value (that was the "slide doesn't work" bug). Jump + lunge still read `IsOnGround`/velocity. Tune the feel with the dvars below.
- **Turbocharger is a cross-module flag, not a weapon edit.** It cannot touch the Havoc's GDT `fireDelay` at runtime, and it does not need to. `apply_turbocharger` just sets `self.acc_item_turbocharger = true`; the Havoc charge owner (`_acc_havoc_charge::havoc_charge_loop`) already polls every 50 ms, and while that flag is set it **never engages the charge gate** — so the beam rifle keeps its base GDT `fireDelay 0.1` press-guard and simply fires when held, i.e. no wind-up. "0 charge-up" is therefore *the gate being absent*, not a literal 0 ms timer. Because the effect lives entirely inside the Havoc loop's `IsSubStr(cur.name, "apex_beam_rifle")` gate, the item is **inert on every other weapon** — that's why it's pointless without a Havoc. Removing it (bench swap, or dying out) clears the flag, so the normal script charge returns on the next trigger pull.
- **Berzerker's +35% is three different twin swaps, and the knife leg is EXPERIMENTAL (2026-07-11).** There
  is NO runtime melee-speed setter in this engine, so every leg is a pre-baked GDT clone with its timing
  fields ÷1.35 (`tools/oneshots/gen_berzerker_twins.js` → 9 blocks in `acc_weapon_variants.gdt`):
  - **Leviathan** rides the variant engine — a new trailing `brz` axis (`axis_brz`, the turbo precedent:
    token active for all guns, twins baked LEVIATHAN-only) with one `_brz` form per PaP-tier form, so the
    implant stacks with the +10%/tier spd twins (`leviathan_acc_brz` / `_acc_spd1_brz` / `_up_acc_spd2_brz` /
    `_up_acc_spd3_brz`).
  - **Action Figure** is OUTSIDE the variant engine (its PaP is the in-place fast-twin ladder), so it gets a
    parallel `_brz` ladder (`t8_melee_figure[_fastN]_brz`): `acc_pap_actionfigure` packs up whichever ladder
    matches the flag, and `_acc_boss_items::berzerker_af_reconcile` swaps carried forms at implant/unequip
    (+ a 0.5 s watch so a later box pull upgrades too).
  - **Regular knife (EXPERIMENTAL — user: "if you cant do the knife thats fine but please try"):** the
    quick-melee is gated by the MELEE-SLOT weapon def (the mechanism stock Bowie/Widow's-Wine use via
    `zm_utility::set_player_melee_weapon`), but the stock `knife` def ships in fastfiles only — **no public
    GDT exists** (swept the install, T7-GDT-Backup, and the web) and no knife viewmodel/anims ship in the
    tools. So `acc_berzerker_melee` is a melee-slot clone of the AF pack's `t8_actionfigure_melee` (the only
    melee-slot GDT on disk) with timings ÷1.35, `meleeDamage 150` (stock-knife parity) and **emptied
    gun/world models → a bare-fist rage swipe** (engine-legal: stock ships `weapon,bare_hands_mp`). The
    Widow's-Wine `w_widows_wine_prev_knife` restore pointer is retargeted on both apply and remove so losing
    WW always hands back the right knife. **LIVE-QA (next session):** (a) confirm the melee-slot def's
    timing really gates the bash speed (all evidence says yes — the AF pack's melee-slot sibling carries its
    own distinct melee timing fields), (b) confirm the bare-fist swipe reads OK. If either fails, the knife
    leg is a one-line disable (the `berzerker_apply_knife` call in `apply_berzerker`) — the axe + AF legs
    stand on the proven twin mechanics regardless.
- **Turbo "delay after running" was the GDT `sprintOutTime` → fixed with the TURBO TWIN AXIS (2026-07-08).** The ported Havoc ships `sprintOutTime 0.98` (every other Apex gun: 0.3) — the engine blocks firing until the sprint-out transition completes, so a turbo carrier (no script charge to mask it) ate a raw ~1 s first-shot delay out of sprint; ZM auto-sprint made this read as "first hip-fire bullet is slow" too. A GDT field is baked per weapon def (no per-player runtime setter exists), and the user wants the fast sprint-out **only with the Turbocharger** — so it ships as a twin swap: **8 hand-cloned turbo forms** (`apex_beam_rifle[_up]_acc_[recoil50_][fastreload_]turbo`, `acc_weapon_variants.gdt`) bake **`sprintOutTime 0.2`**, while all 8 normal forms keep **0.98**. The **`turbo` variant axis** in `_acc_weapon_variants.gsc` (`axis_turbo`, driven by `self.acc_item_turbocharger`) swaps a held/stowed Havoc to the turbo form at implant and back at unequip (implant pokes `request_reconcile` = instant at the bench). Turbo is the **trailing token** in canonical order so every non-Havoc gun degrades to its recoil/reload twins (turbo forms are baked Havoc-ONLY; the allow-list filters them). **Race guard:** `reconcile` defers while `self.acc_havoc_gated` so a swap can never eat the gated ammo.

### Tuning dvars (live, no rebuild)
| Dvar | Default | Effect |
|------|---------|--------|
| ~~`acc_boss_item_chance_mini`~~ / ~~`acc_boss_item_chance_full`~~ | — | **DEAD** — the per-tier chance roll was removed (every boss drop is guaranteed, user 2026-07-07); the legacy full boss itself became unreachable dead code 2026-06-22. |
| `acc_drop_model_z` | 24 | global fallback floor-lift for drop models (per-item `model_z` overrides) |
| `acc_item_glow_color` | 13 | `acc_perk_lights` colour index of the loot glow (13 = dim amber; 0 = off) |
| `acc_item_glow_z` | -40 | Z offset of the ground glow host below the drop origin |
| `acc_bench_off_x` | 153 | Plaza bench CENTER-pad (Slot 2) X offset from the spawn struct (staggered-arc relayout 2026-07-10; was -40) |
| `acc_bench_off_y` | -359 | Plaza bench CENTER-pad Y offset from the spawn struct — the deepest pad, near the south wall (arc back point) |
| `acc_bench_off_z` | -35 | bench Z offset from the Plaza spawn struct (it sat too high; 2026-06-18) |
| `acc_bench_lab_sep` | 175 | Plaza-only: X half-spread of the two OUTER pads from the center pad (Slot 1 at −sep, Slot 3 at +sep) |
| `acc_bench_lab_stagger` | 60 | Plaza-only: Y forward-offset (toward the north doorway) of the two OUTER pads → the pads read as an arc, not a line |
| `acc_bench_pad_sep` | 80 | **Paradise-only now** (`_acc_glitch_altar`): half-spacing of that row's 3 pads (−2·sep / 0 / +2·sep = 160 apart). The Plaza bench no longer reads this (it uses `acc_bench_lab_sep`) |
| `acc_bench_pad_radius` | 40 | each bench pad's use-trigger radius (small so the pad volumes don't overlap) |
| `acc_move_scale_cap` | 2.2 | hard ceiling on the total move-speed multiplier (two mobility items can now stack) |
| `acc_gas_dtap_ms` | 350 | Gas Tank double-tap-sprint window (ms) |
| `acc_gas_burst_mult` | 2.0 | Gas Tank nitro burst move-speed multiplier (+100%) |
| `acc_gas_regen_sec` | 60 | Gas Tank cooldown/regen seconds after the 5 s burst (= NITRO bar refill time) |
| `acc_rocket_slide_mult` | 1.75 | Rocket Shield slide move-speed multiplier (+75%) |
| `acc_mega_flopper_slide_mult` | 1.75 | PhD Flopper Mega slide move-speed multiplier (+75%, slide-gated) |
| `acc_boots_mult` | 1.08 | Boots item move-speed multiplier (+8% everywhere; does NOT negate the trench slow, user 2026-06-21) |
| `acc_arnie_scale` | 1.0 | Li'l Arnie (octobomb) visual scale — 1.0 = stock size |
| `acc_rocket_slide_kick` | 200 | Rocket Shield slide-start forward lunge |
| `acc_rocket_jump_mult` | 1.42 | Rocket Shield jump velocity multiply (~2× apex height; height ∝ velocity²) |
| `acc_battery_boost_mult` | 1.20 | Battery item surge multiplier (+20% move) when a boss zap is absorbed |
| `acc_battery_boost_sec` | 5.0 | Battery item surge duration (s) — also the screen-aura window |
| `acc_battery_cooldown_sec` | 10.0 | Battery recharge after a proc; a zap during it slows normally (one surge per cooldown) (user 2026-07-09: 12 → 10) |
| `acc_battery_aura_alpha` | 0.15 | Battery blue-green full-screen aura opacity while surging — subtle wash (user 2026-07-08: 0.35 was too opaque; 0 = off) |
| `acc_berzerker_hp_frac` | 0.05 | Berzerker blood tax: fraction of MAX HP paid per connecting melee (0 = free swings; the +35% speed is GDT-baked and not dvar-tunable) |

### Implementation (all in `_acc_boss_items.gsc` unless noted)
- **State:** `player.acc_carried_item` (picked up, no buff) + `player.acc_equipped_items` (a **fixed `ACC_ITEM_SLOTS_PER_PLAYER`-element array**, 3 since 2026-07-09 = the single source of truth; index i = Slot i+1 / Pad i+1; `""` = empty slot) + `player.acc_tactical_owner` (which grenade weapon owns the single tactical slot — last-one-wins). `ACC_ITEM_SLOTS_PER_PLAYER = 3`. There is no scalar "active item" and no "first-done" bool — "is it implanted" scans all slots via `player_has_item()`, and "free" is simply `slot_is_empty(slot)`.
- **Bench (three pads, staggered arc 2026-07-10):** `spawn_bench()` polls the `player_respawn_point` struct, then spawns **three** pads via `spawn_bench_pad(org, slot)`: the CENTER pad (Slot 2) at `base = struct + (acc_bench_off_x 153, acc_bench_off_y -359, acc_bench_off_z -35)` ≈ (-75,-490), and the two OUTER pads at `base + (∓sep, +stag, 0)` — Slot 1 west ≈ (-250,-430), Slot 3 east ≈ (100,-430) — where `sep = acc_bench_lab_sep 175` (X spread) and `stag = acc_bench_lab_stagger 60` (Y forward toward the north doorway). So the outer pads sit forward of the center pad → an **arc facing the entrance**, not a cramped line, in the **widened east clear area** (lab east wall moved x-40 → x180) away from the Exchange staircase (SW). Each pad is a `script_model` + look-at-gated `trigger_radius_use` (`acc_bench_pad_radius` 40) with `acc_bench_slot` = its fixed target index. Clearances: ≥40u off the east wall, ≥70u off the Exchange staircase + its buy triggers, ≥38u off the south wall; ~96u gaps between tables. **(Plaza uses `acc_bench_lab_*`; the shared `acc_bench_pad_sep` now drives only the Paradise row in `_acc_glitch_altar`.)** Collision clips mirror these origins in `tools/add_prop_clips.js` (`lab_bench_slot1/2/3`). `bench_use_loop()` reads its pad's slot: `equip_slot(player, slot, carried)` (which `unequip_slot`s the old occupant first), free into an empty slot or `ACC_BENCH_SWAP_COST` (2500) to replace a full one, plays `acc_item_implant`, and clears the carry.
- **Tactical "last one wins":** `apply_arnie_octobomb`/`apply_monkey_bomb` set `acc_tactical_owner`; the `*_regrant_on_spawn` threads regrant only the owner; each `remove_*` hands the tactical to the surviving grenade (or clears it). Prevents the two regrant threads from fighting and the unequip from disarming a co-resident grenade.
- **Implant sound:** `acc_item_implant` alias (`sound/aliases/acc_audio.csv`), 2D wav at `sound_assets/acc/fx/item_implant.wav` (48k/16-bit mono via `tools/convert_wav_48k_mono.ps1`). Played **once at the bench commit** (never in an `apply_*`, or it would re-fire on every respawn-regrant). A new wav needs a **game-closed build** so the `/MIR` sound sync can purge the (otherwise file-locked) `CachedBanks` and the linker rebuilds the `.sabs`/`.sabl` bank.
- **Move-speed clamp:** two mobility items can now stack, so `_acc_utility::recompute_move_speed` caps the total at `acc_move_scale_cap` (2.2) to prevent clip-through-geometry / nav desync.
- **Glitch suppression (Phase Serum):** `apply_arnie_cloak` sets `player.acc_phase_serum = true` and **clears** the legacy `acc_cloak_glitch` flag (`_acc_boss_items.gsc:1218-1219`; the header comment at :1211 spells it out — "It NO LONGER hides you"). The live effect is a **suppression aura** (user 2026-06-29 NERF, was a glitch-only cloak), read by `_acc_boss_glitch::acc_serum_suppressed` (`:163`): any Glitch Stalker within `acc_phase_serum_radius` (350) is slowed to `acc_phase_serum_slow` (1/5) speed in `glitch_speed_think` (`:151`) **and** skips its blink in `glitch_blink_loop` — it can still SEE + chase you, just nullified, not blinded (matches the item-table row above). This is deliberately **NOT** `zm_utility::increment_ignoreme` (that hid you from the *entire* horde = invulnerable, the rejected bug); the regular horde always sees you. The Stalker's per-AI `host.closest_player_override = &glitch_pick_uncloaked_target` picker (`:336`) still ships and strips `acc_cloak_glitch` players before delegating to the stock factory picker, but since nothing sets that flag true anymore the old cloak path is **inert** — a serum holder is targeted exactly like stock.
- **Speed buffs** (nitro burst, slide, boots, battery surge) ride `_acc_utility::recompute_move_speed`; regen + jump/slide impulses are self-contained polling threads.
- **Gas Tank NITRO bar:** `gas_bar_loop` (threaded on equip, ended on `acc_gas_tank_removed`) reuses the verified `hud::createBar` widget (left HUD stack). `gas_tank_burst` stamps `acc_gas_burst_start`; `gas_charge_frac` derives the 0..1 fill from elapsed time (drain over `ACC_GAS_BURST_SEC`, refill over `ACC_GAS_REGEN_SEC`), polled at 20 Hz so it glides. Created/destroyed with the item (single-active).

## Design Logic

### Why 3 slots out of 10

- A 3-slot inventory forces trade-offs. 11 items across several distinct build axes (mobility / economy / survival / weapon-mod / melee / anti-boss) mean the three you wear say a lot about your build intent.
- Wearing them all would remove the decision.
- With 11 items in the pool and 3 slots, **there are C(11,3) = 165 possible equipped triples** per run. Meaningful run-to-run combinatorial variance on top of drop RNG.

### Why random drops and not player choice

- RNG drops create run variance. Same pool, different runs get different builds.
- Forced choice would converge on the optimal loadout across players; random keeps build adaptation a skill in itself.
- Duplicate-to-Shards (loose carry) means even a "useless" repeat drop contributes something (3 Shards), while an already-implanted duplicate is left on the ground for a teammate.

### Why no persistence across runs

- This is a zombies map. Per-run resets are the genre norm. Persistence would break our explicit "no meta-progression" stance in [00_overview.md](00_overview.md).
- Mastery is measured in *pattern recognition across runs*, not inventory hoarding.

### Why every boss drop is guaranteed (was: full boss 100% / mini 50%)

- Boss kills take real time and coordination; a guaranteed item matches the commitment (user 2026-07-07 — the old 50% mini-boss roll made boss rounds feel unrewarding half the time).
- Pacing comes from the **boss cadence** instead: the mini-boss (Trench Warden) first appears at power-on, and full boss rounds land every 9 rounds (r9 = 1 boss, r18 = 2, r27 = 3), the count and types dealt from the shared no-duplicate roster (docs/08).
- With 11 items in the pool and ~1 drop per boss, all three slots fill over the first few boss rounds and implanted-duplicate refusals leave later drops for teammates.

## Stacking and Interaction Notes

- **Intentionally synergistic combos** (all reference live items):
  - **Boots + Battery** — +8% move always, and a boss zap flips into a further +20% surge (5 s, 10 s cooldown) instead of a slow: the anti-boss mobility build.
  - **Gas Tank + Rocket Shield** — nitro burst + slide/jump mobility for the pure kiting build (the `acc_move_scale_cap` 2.2 clamp keeps it in bounds).
  - **Loot Stash + Lucky Horseshoe** — economy engine: flat +10/kill plus the Horseshoe's power-up/drop luck feed each other on long kill streaks.
  - **Nuclear Energy + an energy/explosive build** — +15% on Havoc/Tac-19/AE4/launchers stacks with the Mega Flopper explosive layer.
- **Redundant on paper but fine:** two mobility items (Boots + Rocket Shield) both feed speed but cover different states (constant vs slide/jump); the clamp stops a runaway.

## Co-op Notes

- Each player has their own 3-slot inventory.
- Items are per-player (a boss drop is grabbed by one player, not team-wide). The guaranteed-drop-per-boss reward loop (`grant_unified_boss_reward`) still pays every player their points / shards / Mega Bottle.
- Free-for-all drops behave correctly in co-op: the per-grabber duplicate check leaves an item a teammate lacks on the ground even if the killer already has it implanted.

## Stock-Override Concerns

- Stock BO3 already has some boss drops (e.g. max-ammo powerups on mini-boss kill). We keep those behaviors untouched — item drops are **additional**, not replacements.

## Implementation Status

**Shipped.** The map compiled clean 2026-06-12 and the item system is fully wired in
[`_acc_boss_items.gsc`](../scripts/zm/zm_abandoned_cyber_city/_acc_boss_items.gsc): all 11 pool
items are built in `build_item_pool()` with real `apply_*`/`remove_*` effects, the 3-pad bench
(`spawn_bench`) is placed in the Plaza Lab + Paradise, and the guaranteed boss-drop path runs
through `_acc_boss::grant_unified_boss_reward` → `grant_challenge_reward`. The Loot Stash points
bonus lives in [`_acc_points.gsc::award_killer_with_ledger`](../scripts/zm/zm_abandoned_cyber_city/_acc_points.gsc).

## Out of Scope

- **Item upgrades.** No "+1" tier system on any item. Flat items; richness comes from combinations.
- **Item sets.** No bonus for wearing related items ("full mobility set: +5% extra"). Kept simple.
- **Trading items between players.** You can't hand an implant to a teammate mid-run. Drop-unequip-pickup (loose carry) is the only informal hand-off path; an already-implanted item left on the ground for a teammate is the co-op sharing route.
- **Permanent item unlocks / meta-progression.** No cross-run unlocks (see "Why no persistence").

---

## Shipped model reference (consolidated from docs/09, the retired model-upgrade audit)

The old "model-upgrade checklist" (docs/09) is superseded: its high-priority swaps **shipped**, and its
first Greyhound-catalog swap batch was reverted after teaching the durable lesson below. The still-true
facts live here now.

### How a stock/carved model swap works
- **Stock xmodels load by NAME** — an upgrade just changes the `setmodel()` / `#precache("model", …)` and
  puts the name on an `xmodel,<name>` line in `zone_source\zm_abandoned_cyber_city.zone` (stock power-up
  orbs like the nuke are runtime-loaded and need no zone line). A model-name swap touches no geometry, so
  the build is **`-GscOnly`** (no LED bake). **The build ERRORLOG is the oracle for "does it pack"** —
  a campaign-only model logs `xmodel '<name>' is missing` and shows nothing.
- **The Greyhound runtime catalog is NOT what the Mod Tools LINKER can pack.** Greyhound dumps models
  loaded in the *game*; the linker needs the model's *source asset* in the install's GDT/asset DB. That
  gap reverted an entire "zod family = proven" swap batch 2026-06-22 (memory
  `greyhound-catalog-not-modtools-packable`). The fix that unblocked everything is the **T7-dump carve
  pipeline** (`tools/xmodel_bin_inspect.js` for material/vertex bounds, `tools/gen_t7_carve_gdt.js` to
  auto-author the carve GDT from the `.xmodel_bin`s), which packs *any* dump model via an install-side
  GDT. The boss-item props (above) and the station remodel (below) both ride it; the Battery ships from
  its own `p7_zm_ctl_battery_ceramic.gdt`.

### Station models (shipped 2026-07-09, de-dup complete)
Every interactive station now has a distinct, use-case-correct model — the 6-way `p7_cai_sign_inteactive_kiosk`
and 3-way `p7_cai_work_table_metal_03_white` reuses are GONE. All picks were bounds-measured and spawn at
`SetScale 1.0` so collision == visual (`SetScale` does NOT rescale a `script_model`'s collision); collision
clips were re-cut to the new footprints.

| Station | Model | Notes |
|---|---|---|
| Implant Bench (3 pads; this doc) | `p7_zm_isl_table_operating` — Zetsubou operating table (79×24×42) | surgical implant read; no longer shares the Exo workbench |
| Exo Suit Station (Foundry + Paradise) | `p7_cry_cryogen_pod_exterior` — Cryogen stasis pod (58×53×114) | origin mid-body → +63 z lift (`_acc_exo::spawn_station_at`) |
| Neural Expansion Bay | `p7_zm_sta_drop_pod_console_blue` — Gorod drop-pod console (49×44×71) | — |
| Weapon Overclock terminal | `p7_zm_sta_dragon_network_data_terminal` — Gorod network terminal (48×34×78) | replaced the theatre ticket kiosk |
| Glitch Altar base | `p7_ram_altar` — Citadel stone altar (162×66×58) | core orb `p7_fxanim_zm_stal_ray_gun_ball_mod` hovers ~14u above |
| Reactor Surge Plinth | `p7_ris_generator_lg_01_blue` — Rise industrial generator (92×46×50) | yaw 270→0 |
| Armory weapon rack | `p7_con_cargo_train_armory_cabinet` — Conduit armory cabinet (138×18×48) | long axis spans the two pads |
| Armory bottle exchange | `p7_zm_vending_wonder` — Wonderfizz chassis (74×56×110) | **STOCK** — packs from gdtDB, no carve |
| Transfer Vault stations ×4 | `p7_out_monitor_atm` — ATM totem (37×34×103) | model spawns −80 z |
| Ammo Crate (L2/L5/Paradise) | `p7_zm_sha_crate_ammo_closed_sml_stack_full` (78×20×21) | — |
| Data Cache (**4** plaza + 2 pit) | `p7_cai_stacking_cargo_crate` — stacking cargo crate (64×64×48) | **model reverted from the computer tower 2026-07-10** (user preferred the crate); crate origin at base → **0 z lift**. Crate ships a `_col` LOD so it self-collides; belt-and-suspenders clips are `add_prop_clips.js` `plaza_cache_1..4` + `pit_cache_w/e`. 4th plaza cache added for 4-player parity (path to Market door) |
| Data Shard pickup / Altar orb core | `p7_fxanim_zm_stal_ray_gun_ball_mod` | shared on purpose (the orb IS the shard motif) |

Install-side: `source_data\acc_t7_props_stations.gdt` (+ `acc_t7_props_items.gdt` for the pickups), registered
in `tools/external_assets_manifest.ps1` + CREDITS.md.

### Boss / elite tells (shipped as SetModel + eye-tint + aura, no new xmodels)
The Greyhound boss/elite model swaps did NOT pack, so the readability tells ship as **client-FX + stock
`SetModel`** instead (verified against the live code):
- **Glitch Stalker** — `SetModel("c_sat_zmb_zombie_toxic_1")` (WetEgg toxic body; head is included so the
  engine-attached charred head is Detached) + **teal eyes** via the `accEyeTint` clientfield
  (`_acc_boss_glitch.gsc:303,313`). `accPhantomAura` stays Phantom/Core-only.
- **Shielded elite** — `SetModel("c_t8_zmb_mob_zombie_body3")` chain-armor MOB body + MOB head, `no_gib`
  (the armor never comes off) = the tell (`_acc_elites.gsc:333,339`). The old rocket-shield back-attach
  was **REMOVED** 2026-07-03 (the `wpn_t7_zmb_zod_rocket_shield_world` zone line stays only for the Rocket
  Shield boss item).
- **Teleporter / EMP elites** — recoloured eyes via `accEyeTint` only (`_acc_elites.gsc:433,471`). It's a
  single on/off bit today; a per-actor colour index is a future widening.
- **Full boss "Subroutine Core"** — `run_full_boss` / `spawn_subroutine_core` (with their Giant-body +
  teal-eye + aura reskin) are **unreachable dead code** (removed 2026-06-22, `_acc_boss.gsc:118`). The live
  boss visuals are carried by the every-9 roster (Phantom / Avogadro / Panzer / Rogue-Civil Protector) plus
  the Trench Warden (NSZ Brutus external pack). See docs/08 for the enemy roster.
