# 51 — Master SFX Checklist (full audio pass)

Working doc for the "spice up the map with sound everywhere" pass. Built from a
187-event code audit (deduped to the table rows below). Check boxes off as the
extracted Greyhound wavs land + the alias rows go in.

---

## 0. The rule that makes every row below work (READ FIRST)

**This is a STANDALONE usermap sound zone.** Stock aliases (`zmb_*`, `evt_*`,
`vox_*`, `mus_*`) are **UNDEFINED here**, so any `PlaySound("zmb_...")` /
`PlaySound("evt_...")` in our code (and inside the stock prefab/box/perk/PaP/door
flows) is a **SILENT no-op** at runtime. Only the map's own `acc_*` aliases that
physically exist in `sound/aliases/acc_audio.csv` actually play.

**Currently working `acc_*` aliases (verified in acc_audio.csv):**
`acc_amb_city_bed`, `acc_main_theme`, `acc_brutus_music`, `acc_glitch_warp`,
`acc_overclock_zap`, `acc_mega_drink`, `acc_headshot_ding`,
`acc_soul_steal` (3D, plays at the kill spot when a soul banks toward a descent
gate — `_acc_abyss_doors.gsc::on_zombie_death_souls`, `PlaySoundAtPosition`; added
2026-06-25, verified in the `.sabl` loaded bank). (NSZ Brutus aliases
live in `nsz_brutus.csv`, also working.)

**Aliases REFERENCED in our code but NOT in the CSV = silent today** (high-value
gaps): `acc_shard_pickup` (referenced 5×!), `acc_decon_alarm`, plus every
`evt_*` / `zmb_*` we already call (`evt_bottle_dispense`, `evt_perk_deny`,
`evt_nuke_flash`, `zmb_perks_packa_upgrade/ready/deny`).

### The workflow for every silent event

1. **Extract** the stock BO2/BO3 wav from the Greyhound export (the
   "suggested stock alias" column points at the right asset).
2. **Re-encode to 48 kHz / 16-bit** (hard linker req — see memory
   `custom-sound-48k-and-game-lock`).
3. **Drop the wav** under `sound/_dev/...` and **add ONE alias row** to
   `sound/aliases/acc_audio.csv`. Name it `acc_<thing>` (our zone) — do NOT try
   to revive the stock name, it can't resolve.
4. **Point the code at the new alias.** Two cases:
   - Code already calls a stock name (`PlaySound("evt_perk_deny")`) → change the
     string to the new `acc_*` alias.
   - Code calls a not-yet-defined `acc_*` (`acc_shard_pickup`,
     `acc_decon_alarm`) → **just add the CSV row, the call already works.**
   - No call exists yet → add the `PlaySound`/`PlayLocalSound`/
     `playsoundatposition`/`PlayLoopSound` at the cited line.
5. **GAME MUST BE CLOSED** when you build — the `.sabs` bank is file-locked while
   BlackOps3 runs, so a new sound stays silent (no error) until a game-closed
   build rebuilds the bank. Sound-only changes are `-GscOnly` (no geometry).

> Note on the "stock-driven" rows (power switch, mystery box, doors, perk buy,
> revive, downed, points blip, game over): these are baked into Treyarch prefabs
> / `_zm_*.gsc` we don't own. We can't edit those scripts, but we CAN give the
> ALIAS THEY ALREADY CALL a definition by adding a row **named exactly that stock
> alias** to our CSV — if the stock script calls `PlaySound("zmb_box_open")` and
> we add an `acc_audio.csv` row literally named `zmb_box_open`, the linker packs
> it into our zone and the stock call resolves. (This is the only way to "fix"
> stock-driven SFX from our side. Verify per-alias; some are events on viewmodel
> anims that we can't reach.)

Legend for **Current state**:
`WORKS` = custom acc_* defined & playing · `SILENT(stock)` = code calls a
stock/undefined alias = no-op · `SILENT(acc-undef)` = code calls an `acc_*` not
in the CSV = no-op · `NONE` = no PlaySound call exists yet.

---

## 1. Progression & Buys

| done | Event | Where it fires | State | Sound it wants | Suggested stock alias | Pri |
|---|---|---|---|---|---|---|
| [ ] | Mega upgrade APPLIED (drink + sting) | `_acc_mega_bottles.gsc:246` | WORKS | heartbeat/synth sting over gulp | `acc_mega_drink` (done) | low |
| [ ] | Mega bottle DISPENSE at parallel trigger | `_acc_mega_bottles.gsc:441` | SILENT(stock) | vending bottle clunk | `evt_bottle_dispense`→`acc_bottle_dispense` | high |
| [ ] | Mega upgrade DENY (already mega'd / no bottle) | `_acc_mega_bottles.gsc:471,477` | NONE | deny buzz | `zmb_perks_packa_deny` | med |
| [ ] | Mega re-drink anim replay | `_acc_mega_bottles.gsc:260` | SILENT(stock) | gulp tied to bottle anim | `zmb_perks_drink` | med |
| [ ] | Empty Mega Bottle GRANTED (boss kill) | `_acc_mega_bottles.gsc:177` | NONE | glassy reward clink | `zmb_bgb_pickup` / `zmb_perk_grab` | high |
| [ ] | Neural Expansion +1 slot BUY | `_acc_perks.gsc:204` | SILENT(acc-undef) | upgrade-success confirm | `acc_shard_pickup` (add row) / `zmb_perks_packa_upgrade` | high |
| [ ] | Neural Expansion DENY (max/no shards) | `_acc_perks.gsc:190,198` | NONE | deny buzz | `zmb_no_purchase` | med |
| [ ] | Perk buy DENY — at slot cap | `_acc_perk_info.gsc:143` | SILENT(stock) | perk-machine reject | `evt_perk_deny`→`acc_perk_deny` | high |
| [ ] | Normal perk BUY (drink + jingle) | stock `_zm_perks.gsc` vending | SILENT(stock) | iconic gulp + machine jingle | `zmb_perks_<perk>_jingle` + `zmb_perks_drink` | high |
| [ ] | PaP first pack 0→1 (cook + ready) | `_acc_pap_levels.gsc:292,302` | SILENT(stock) | PaP whir then ready ding | `zmb_perks_packa_upgrade` + `zmb_perks_packa_ready` | high |
| [ ] | PaP tier up 1→2 / 2→3 (cook + ready) | `_acc_pap_levels.gsc:337,367` | SILENT(stock) | same cook + ready pair | `zmb_perks_packa_upgrade` + `zmb_perks_packa_ready` | high |
| [ ] | PaP DENY — not enough points | `_acc_pap_levels.gsc:279,332` | SILENT(stock) | PaP reject buzz | `zmb_perks_packa_deny` | high |
| [ ] | PaP re-pack on maxed (3/3) gun | `_acc_pap_levels.gsc:323-326` | NONE | short "already maxed" deny | `zmb_perks_packa_deny` | low |
| [ ] | Overclock weapon TIER UP (zap) | `_acc_overclocks.gsc:299` | WORKS | electric overclock zap | `acc_overclock_zap` (done) | low |
| [ ] | Overclock DENY (4 fail paths) | `_acc_overclocks.gsc:255,261,280,289` | NONE | deny buzz | `zmb_perks_packa_deny` | med |
| [ ] | Exo Suit body TIER UP | `_acc_exo.gsc:138` | SILENT(acc-undef) | servo/augment confirm | `acc_shard_pickup` (add row) / `zmb_perks_juggernog_sting` | high |
| [ ] | Exo Suit DENY (maxed/no shards) | `_acc_exo.gsc:123,132` | NONE | deny buzz | `zmb_no_purchase` | med |
| [ ] | Cyberware node BUY *(tree disabled)* | `_acc_cyberware.gsc:279` | NONE | skill-unlock chime | `zmb_perks_packa_upgrade` | low |
| [ ] | Cyberware respec/refund *(disabled)* | `_acc_cyberware.gsc:324,445` | NONE | reset + deny | `zmb_powerup_drop` / `zmb_no_purchase` | low |
| [ ] | Phase Step blink *(disabled)* | `_acc_cyberware.gsc:679` | NONE | warp whoosh | `acc_glitch_warp` (just wire) | low |
| [ ] | Ghost Protocol cloak on/off *(disabled)* | `_acc_cyberware.gsc:759` | NONE | cloak shimmer/pop | custom shimmer | low |
| [ ] | Meltdown AoE explosion *(disabled)* | `_acc_cyberware.gsc:840` | NONE | corpse explosion boom | `evt_nuke_flash`→`acc_*` | low |
| [ ] | PhD slide/down NOVA explosion | `_acc_perk_phd_flopper.gsc:262` | SILENT(stock) | big explosive WHOOMP | `evt_nuke_flash`→`acc_phd_nova` | high |
| [ ] | PhD Flopper perk BUY | cherry vending flow | SILENT(stock) | drink + machine jingle | `zmb_perks_electric_cherry_jingle` + `zmb_perks_drink` | med |
| [ ] | Widow's Wine web round restock | `_acc_mega_bottles.gsc:115` | NONE | subtle restock tick (optional) | `zmb_powerup_grab` / none | low |
| [ ] | Quick Revive / Savior revive complete | `_acc_perks.gsc:314` (stock-driven) | SILENT(stock) | revive jingle/sting | `zmb_perks_revive_jingle` | med |

---

## 2. Pickups, Economy & Powerups

| done | Event | Where it fires | State | Sound it wants | Suggested stock alias | Pri |
|---|---|---|---|---|---|---|
| [ ] | **Data Shard PICKUP** (world drop) | `_acc_data_shards.gsc:336` | SILENT(acc-undef) | bright digital data-chime | **`acc_shard_pickup` (add row — ref'd 5×)** / `zmb_cha_ching` | high |
| [ ] | Data Cache EXTRACTED (grant shards) | `_acc_data_shards.gsc:268` | SILENT(acc-undef) | crate-unlock clunk + chime | `acc_shard_pickup` / `zmb_box_move_stop` | high |
| [ ] | Data Cache DENY (depleted) | `_acc_data_shards.gsc:263` | NONE | soft empty buzz | `zmb_no_money` | low |
| [ ] | Data Cache re-arm (round start) | `_acc_data_shards.gsc:283` | NONE | recharge hum | `zmb_perks_packa_ready` | low |
| [ ] | Shards GRANTED (+N HUD, any source) | `_acc_data_shards.gsc:141` | NONE | tiny UI income tick | `acc_shard_pickup` (soft) | low |
| [ ] | Glitch Altar SPIN start | `_acc_glitch_altar.gsc:144,152` | NONE | glitch slot-machine whir | layer `acc_glitch_warp` / `zmb_perks_packa_upgrade` (riser) | high |
| [ ] | Glitch Altar BOON (powerup drop) | `_acc_glitch_altar.gsc:190-215` | SILENT(stock) | jackpot win chime | win sting + powerup grab (see §2 powerups) | high |
| [ ] | Glitch Altar Free-Perk boon | `_acc_glitch_altar.gsc:204` | NONE | perk-bottle acquire gulp | `evt_bottle_dispense` / `zmb_perks_jingle` | med |
| [ ] | Glitch Altar SHARD JACKPOT | `_acc_glitch_altar.gsc:208-209` | NONE | coin-cascade cha-ching | `zmb_cha_ching` / `acc_shard_pickup` | med |
| [ ] | Glitch Altar MEGA WIN (~1%) | `_acc_glitch_altar.gsc:211-215` | NONE | big triumphant fanfare | `zmb_round_start_stinger` | high |
| [ ] | Glitch Altar CURSE: Surge | `_acc_glitch_altar.gsc:218-220` | NONE | ominous grid-spike alarm | `zmb_lightning_zap` + `acc_glitch_warp` | high |
| [ ] | Glitch Altar CURSE: Shard Drain | `_acc_glitch_altar.gsc:222-224` | NONE | corruption power-down whine | `zmb_power_off` | med |
| [ ] | Glitch Altar CURSE: Dud | `_acc_glitch_altar.gsc:226-228` | NONE | sad fizzle/flicker-die | electrical fizzle | med |
| [ ] | Glitch Altar DENY (cooldown/shards) | `_acc_glitch_altar.gsc:138,146` | NONE | deny buzz | `zmb_no_money` | low |
| [ ] | Reactor Surge ARMED / start | `_acc_reactor.gsc:150-153` | NONE | reactor klaxon + rumble | `zmb_alarm` / boss sting | high |
| [ ] | Reactor each wave begins | `_acc_reactor.gsc:160-162` | NONE | escalating surge whoosh | `zmb_round_start` | low |
| [ ] | Reactor STABILIZED success | `_acc_reactor.gsc:189-191` | SILENT(acc-undef) | objective-complete fanfare + chime | `acc_shard_pickup` + objective sting | high |
| [ ] | Reactor FAILED | `_acc_reactor.gsc:179-180` | NONE | meltdown-failed power-down | `zmb_power_off` | med |
| [ ] | Reactor DENY (busy/used) | `_acc_reactor.gsc:120-127` | NONE | deny buzz | `zmb_perks_packa_deny` | low |
| [ ] | Emergency Drop PURCHASED | `_acc_emergency_drop.gsc:84,116` | SILENT(stock) | beacon-called beep + powerup ding | custom beep + powerup grab (§2) | high |
| [ ] | Emergency Drop overclock_scroll outcome | `_acc_emergency_drop.gsc:139-142` | NONE | pickup chime (invisible reward) | `acc_overclock_zap` / `acc_shard_pickup` | low |
| [ ] | Emergency Drop DENY | `_acc_emergency_drop.gsc:79` | NONE | deny buzz | `zmb_no_money` | low |
| [ ] | Boss item WORLD-DROP spawns | `_acc_boss_items.gsc:313` | NONE | loot drop / glint cue | `zmb_spawn_powerup` | med |
| [ ] | Boss item GRABBED / carried | `_acc_boss_items.gsc:394-395` | NONE | item-collected whoosh | `zmb_powerup_grabbed` | high |
| [ ] | Duplicate item → auto-convert to shards | `_acc_boss_items.gsc:370,278` | NONE | shard chime (dupe→currency) | `acc_shard_pickup` / `zmb_cha_ching` | med |
| [ ] | Implant Bench item ENABLED | `_acc_boss_items.gsc:1106-1109` | NONE | heavy implant-install clunk | `zmb_perks_packa_upgrade` | high |
| [ ] | Implant Bench DENY | `_acc_boss_items.gsc:1079,1085,1095` | NONE | deny buzz | `zmb_no_money` | low |
| [ ] | Gas Tank Nitro ACTIVATED | `_acc_boss_items.gsc:724` | NONE | pneumatic nitro hiss | gas-release whoosh | med |
| [ ] | Gas Tank Nitro RECHARGED | `_acc_boss_items.gsc:729` | NONE | soft ready ping | `zmb_perks_packa_ready` | low |
| [ ] | Li'l Arnie / octobomb granted | `_acc_boss_items.gsc:855` | NONE | equipment-received click | `zmb_powerup_grabbed` | low |
| [ ] | Cymbal Monkey granted | `_acc_boss_items.gsc:1002` | NONE | equipment-received click | `zmb_powerup_grabbed` | low |
| [ ] | Phase Serum cloak ACTIVATED | `_acc_boss_items.gsc:822-825` | NONE | phase shimmer cloak-on | `acc_glitch_warp` | med |
| [ ] | Repair Kit HP regen ENABLED | `_acc_boss_items.gsc:563-567` | NONE | one-shot systems-online hum | `zmb_perks_packa_ready` | low |
| [ ] | Rocket Shield mobility ENABLED | `_acc_boss_items.gsc:922-926` | NONE | thruster-online cue | jetpack whoosh | low |
| [ ] | **Powerup: Max Ammo** drop+grab+VO | stock `_zm_powerups.gsc` | SILENT(stock) | drop ding + grab + "Max Ammo!" VO | `zmb_spawn_powerup` + `zmb_powerup_grabbed` + `vox_zmba_powerup_maxammo_0` | high |
| [ ] | **Powerup: Insta-Kill** drop+grab+VO | stock `_zm_powerups.gsc` | SILENT(stock) | drop+grab+"Insta-Kill!" VO | `zmb_spawn_powerup` + `zmb_powerup_grabbed` + `vox_zmba_powerup_instakill_0` | high |
| [ ] | **Powerup: Nuke** drop+grab+VO+whoomp | stock `_zm_powerup_nuke.gsc` | SILENT(stock) | drop+grab+"Nuke!"+screen-clear WHOOMP | `zmb_spawn_powerup` + `zmb_powerup_grabbed` + `vox_zmba_powerup_nuke_0` + `evt_nuke_flash` | high |
| [ ] | **Powerup: Double Points** drop+grab+VO | stock `_zm_powerups.gsc` | SILENT(stock) | drop+grab+"Double Points!" VO | `zmb_spawn_powerup` + `zmb_powerup_grabbed` + `vox_zmba_powerup_doublepoints_0` | high |
| [ ] | Powerup: Free Perk grab | `_acc_lui.gsc:494` | SILENT(stock) | grab whoosh + bottle gulp | `zmb_powerup_grabbed` + `evt_bottle_dispense` | med |
| [ ] | Powerup: Fire Sale grab+VO | stock `_zm_powerups.gsc` | SILENT(stock) | grab + "Fire Sale!" VO | `zmb_powerup_grabbed` + `vox_zmba_powerup_firesale_0` | med |
| [ ] | Powerup: Carpenter grab+VO+hammer | `_acc_lui.gsc:489` | SILENT(stock) | grab + "Carpenter!" VO + hammer loop | `zmb_powerup_grabbed` + `vox_zmba_powerup_carpenter_0` + `zmb_carpenter` | med |
| [ ] | Powerup IDLE beacon loop (un-grabbed) | stock `_zm_powerups.gsc:833` | SILENT(stock) | looping beacon hum | `zmb_spawn_powerup_loop` | med |

> Powerup note: Glitch Altar boons, Emergency Drop, Reactor, and elite drops ALL
> route through stock `specific_powerup_drop`, so fixing the 6 powerup rows above
> (drop ding / grab whoosh / announcer VO / idle loop) lights up every drop source
> at once. Highest single-fix leverage in the whole doc.

---

## 3. Bosses

| done | Event | Where it fires | State | Sound it wants | Suggested stock alias | Pri |
|---|---|---|---|---|---|---|
| [ ] | Brutus pre-spawn + spawn yell | `_NSZ/nsz_brutus.gsc:180-183,660-666` | WORKS (NSZ) | metallic arrival + yell | NSZ pack | low |
| [ ] | Brutus footsteps | `_NSZ/nsz_brutus.gsc:613` | WORKS (NSZ) | armored footfalls | NSZ pack | low |
| [ ] | Brutus melee swing | `_NSZ/nsz_brutus.gsc:645-646` | WORKS (NSZ) | whoosh + grunt | NSZ pack | low |
| [ ] | Brutus helmet knocked off | `_NSZ/nsz_brutus.gsc:693,745` | WORKS (NSZ) | helmet clang (could reinforce) | `zmb_brutus_helmet_off` | med |
| [ ] | Brutus death vocal | `_NSZ/nsz_brutus.gsc:694-695` | WORKS (NSZ) | death groan + thud | NSZ pack | low |
| [ ] | **Brutus kill REWARD** (item+shards+bottle) | `_acc_boss.gsc:302-329` | NONE | triumphant reward sting | `zmb_perks_packa_upgrade` | med |
| [ ] | **Subroutine Core SPAWN** telegraph | `_acc_boss.gsc:390-498` | NONE | huge mechanical boot-up surge | `zmb_mechz_spawn` | high |
| [ ] | **Subroutine Core MUSIC** (not wired!) | `_acc_boss.gsc:253-287` (not called) | SILENT | wire `boss_music(core)` in spawn | `acc_brutus_music` (exists) | high |
| [ ] | Core phase 2 (66%) — power outage | `_acc_boss.gsc:598-640` | NONE | power-down whine / grid-cut | `zmb_power_off` | high |
| [ ] | Core phase 3 (33%) — perks disabled | `_acc_boss.gsc:645-654` | NONE | glass-shatter de-buff | `zmb_perks_shatter` | high |
| [ ] | Core power/perks RESTORED | `_acc_boss.gsc:638-639,652` | NONE | re-energize hum | `zmb_power_on` | med |
| [ ] | Core phase 4 (15%) — EMP add spawn | `_acc_boss.gsc:707-711` | NONE | enrage / EMP-charge sting | `zmb_emp_explode` | med |
| [ ] | **Core DEATH + reward** | `_acc_boss.gsc:377-388,530-550` | NONE | boss-death explosion + victory sting | `zmb_mechz_death` | high |
| [ ] | **Glitch Stalker WAVE inbound** announce | `_acc_boss_glitch.gsc:176-185` | NONE | glitchy digital alarm sting | `zmb_margwa_spawn` | high |
| [ ] | Glitch Stalker per-boss spawn | `_acc_boss_glitch.gsc:213-314` | NONE | per-actor materialize cry | `acc_glitch_warp` | med |
| [ ] | Glitch Stalker teleport-blink | `_acc_boss_glitch.gsc:435-442` | WORKS | 3D warp zap | `acc_glitch_warp` (done) | low |
| [ ] | Glitch Stalker POUNCE on camper | `_acc_boss_glitch.gsc:413-453` | NONE | sharp lunge/screech (≠ blink) | `zmb_thrasher_attack` | med |
| [ ] | **Glitch Stalker VULN window opens** | `_acc_boss_glitch.gsc:675-682` | NONE | shield-down / destabilized tone | `zmb_vo_round_robot_taunt` | high |
| [ ] | **Glitch Stalker DEATH + drop** | `_acc_boss_glitch.gsc:691-719` | NONE | digital de-rez + reward chime | `zmb_margwa_death` | high |
| [ ] | Phantom inbound announce *(disabled)* | `_acc_boss_phantom.gsc:170-178` | NONE | eerie phase-in whisper | `zmb_apothicon_fly_spawn` | low |
| [ ] | Phantom materialize REVEAL screech | `_acc_boss_phantom.gsc:359-369` | WORKS (reuses warp) | jump-scare screech (own sound?) | `zmb_cloaker_reveal` | med |
| [ ] | Phantom spawn → bar + music | `_acc_boss_phantom.gsc:236-237` | WORKS (music) | arrival sting (separate from screech) | custom | low |
| [ ] | Phantom DEATH + drop *(disabled)* | `_acc_boss_phantom.gsc:399-416` | NONE | hologram-collapse de-rez | `zmb_apothicon_fly_death` | low |
| [ ] | Boss MUSIC loop + 4s fade | `_acc_boss.gsc:253-287` | WORKS | looping battle track | `acc_brutus_music` (done) | low |
| [ ] | Boss headshot KILL ding | `_acc_damage.gsc:539-546` | WORKS | 2D hitmarker ding (kill only) | `acc_headshot_ding` (done) | low |
| [ ] | Boss non-lethal body hit | `_acc_damage.gsc:283` | NONE | armored metallic thunk (subtle) | `zmb_mechz_bullet_impact` | low |

---

## 4. Events & Traps

| done | Event | Where it fires | State | Sound it wants | Suggested stock alias | Pri |
|---|---|---|---|---|---|---|
| [ ] | Hack START (breach initiated) | `_acc_events_hack.gsc:126-131,211` | NONE | terminal boot-up + rising alarm | `zmb_perks_packa_upgrade` | high |
| [ ] | Hack stage advance | `_acc_events_hack.gsc:220` | NONE | stage-cleared confirm blip | `zmb_perks_packa_filldrink` | med |
| [ ] | Hack hold-progress tick | `_acc_events_hack.gsc:325` | NONE | per-sec upload bleep (ramps) | `zmb_perks_packa_beep` | med |
| [ ] | Hack survive-trace window + purge | `_acc_events_hack.gsc:337-363` | NONE | ominous trace pulse + relief sweep | `zmb_perk_packa_loop` | med |
| [ ] | **Hack SUCCESS** | `_acc_events_hack.gsc:231,133-143` | NONE | "access granted" chime | `zmb_perks_packa_ready` | high |
| [ ] | **Hack FAILED** | `_acc_events_hack.gsc:226,144-148` | NONE | "access denied" klaxon | `zmb_perks_packa_deny` | high |
| [ ] | Hack penalty wave spawns | `_acc_events_hack.gsc:404-419` | NONE | security-horde surge roar | `zmb_vox_zmball_round_start` | med |
| [ ] | Hack DENY (afford/state) | `_acc_events_hack.gsc:107,117` | NONE | purchase-deny tone | `zmb_cha_ching_deny` | low |
| [ ] | Overload START | `_acc_events_overload.gsc:123-128,209-213` | NONE | reactor-overload power-up hum | `zmb_perks_packa_upgrade` | high |
| [ ] | Overload defense-wave pulse (0/30/60s) | `_acc_events_overload.gsc:312-334` | NONE | per-wave horde alarm | `zmb_vox_zmball_round_start` | med |
| [ ] | **Overload OFF-POINT warning** | `_acc_events_overload.gsc:279-283` | NONE | urgent leaving-zone beep | `zmb_perks_packa_beep` | high |
| [ ] | Overload hold-progress announce | `_acc_events_overload.gsc:266-269` | NONE | reactor-charging rising tone | `zmb_perk_packa_loop` | low |
| [ ] | **Overload SUCCESS + shortcut unlock** | `_acc_events_overload.gsc:225,358-381` | NONE | power-discharge climax + door confirm | `zmb_perks_power_on` | high |
| [ ] | **Overload FAILED + takedown wave** | `_acc_events_overload.gsc:229,341-348` | NONE | shutdown whine + failure sting | `zmb_perks_packa_deny` | high |
| [ ] | Overload DENY (afford) | `_acc_events_overload.gsc:104,114` | NONE | purchase-deny tone | `zmb_cha_ching_deny` | low |
| [ ] | **DEFCON room LIGHTS RED** (armed) | `_acc_lockdown.gsc:202,276-288` | NONE | distant red-alert klaxon bed | `zmb_alarm_loop` | high |
| [ ] | DEFCON cleared (all-clear) | `_acc_lockdown.gsc:207-216` | NONE | alarm power-down resolve | `zmb_perks_power_on` | med |
| [ ] | **Lockdown SEALS — "ENGAGED"** | `_acc_lockdown_challenge.gsc:178,450-478` | NONE | blast-door slam + alarm hit | `zmb_door_slam_metal` | high |
| [ ] | Lockdown confined glitch spawns | `_acc_lockdown_challenge.gsc:225-254` | WORKS (warp) | per-spawn warp pop | `acc_glitch_warp` | low |
| [ ] | Lockdown purge tally per kill | `_acc_lockdown_challenge.gsc:267-269` | NONE | escalating tally tick | `zmb_perks_packa_beep` | med |
| [ ] | **Lockdown CLEARED** | `_acc_lockdown_challenge.gsc:333-346` | NONE | victory fanfare + unseal clunk | `zmb_perks_jingle_packa` | high |
| [ ] | **Lockdown FAILED** | `_acc_lockdown_challenge.gsc:355-371` | NONE | grim failure down-sweep | `zmb_perks_packa_deny` | high |
| [ ] | **Decon WARNING / start klaxon** | `_acc_decontamination.gsc:245,253` | SILENT(acc-undef) | facility decon siren bed | **`acc_decon_alarm` (add row)** / `zmb_alarm_loop` | high |
| [ ] | Decon seal T-10s warning | `_acc_decontamination.gsc:256` | NONE | escalating warning beep | `zmb_perks_packa_beep` | high |
| [ ] | Decon seal T-5s warning | `_acc_decontamination.gsc:259` | NONE | faster final-countdown beep | `zmb_perks_packa_beep` | high |
| [ ] | Decon zone SEALED | `_acc_decontamination.gsc:263-289` | NONE | blast-door slam + gas vent hiss | `zmb_door_slam_metal` | high |
| [ ] | Decon straggler killed (gas) | `_acc_decontamination.gsc:385-401,524-557` | NONE | gas-burn / electrocution cue | `zmb_elec_trap_zap` | med |
| [ ] | Bus Trench fall tax (jump-in) | `_acc_bus_trench.gsc:365-375` | NONE | grunt + hard-land thud | `zmb_player_land_hard` | med |
| [ ] | **Trench DANGER warning** | `_acc_bus_trench.gsc:251-253,870-895` | NONE | ominous dread drone (~4s) | `zmb_perk_packa_loop` | high |
| [ ] | **Trench spawn SURGE / eruption** | `_acc_bus_trench.gsc:259-264,476-546` | NONE | subterranean burst + horde roar | `zmb_zombie_rise_dirt` | high |
| [ ] | Descend to deeper Abyss layer | `_acc_bus_trench.gsc:222-234` | NONE | descending bass swell | `zmb_blackhole_ambient` | med |
| [ ] | Trench continuous DRIP surge | `_acc_bus_trench.gsc:437-461` | NONE | smaller recurring floor-burst | `zmb_zombie_rise_dirt` | low |

---

## 5. Combat & Enemies

| done | Event | Where it fires | State | Sound it wants | Suggested stock alias | Pri |
|---|---|---|---|---|---|---|
| [ ] | Headshot KILL ding (shooter) | `_acc_damage.gsc:546` | WORKS | crisp hitmarker ding | `acc_headshot_ding` (done) | low |
| [ ] | Headshot HIT (non-kill) | `_acc_damage.gsc:539-570` | NONE | softer tick (≠ kill ding) | pitch variant of `acc_headshot_ding` | low |
| [ ] | Crit proc (CW Overload chance-crit) | `_acc_damage.gsc:307-322` | NONE | electric crit zap | `acc_overclock_zap` (reuse) | low |
| [ ] | **Shielded elite SPAWN** telegraph (r5+) | `_acc_elites.gsc:229-238` | NONE | metallic shield-clank growl | `zmb_brutus_spawn` | high |
| [ ] | **Shielded frontal hit ABSORBED** | `_acc_damage.gsc:504-513` | NONE | metallic clank/ricochet (flank cue) | `zmb_bullet_impact_metal` | high |
| [ ] | Shield BREAK / shielded death | `_acc_elites.gsc:365-389` | NONE | shield-shatter crunch | `zmb_brutus_helmet_off` | med |
| [ ] | **Teleporter elite SPAWN** (r11+) | `_acc_elites.gsc:240-246` | NONE | glitchy phase-in cue | `acc_glitch_warp` (exists) | high |
| [ ] | **Teleporter elite BLINK** (src+dest) | `_acc_elites.gsc:248-270` | NONE | warp-out at src + warp-in at dest (3D) | `acc_glitch_warp` ×2 positional | high |
| [ ] | **EMP elite SPAWN** (r21+) | `_acc_elites.gsc:272-277` | NONE | charging electrical hum | `acc_overclock_zap` (reuse) | high |
| [ ] | **EMP-on-hit zap** (drains pts + locks CW) | `_acc_elites.gsc:335-356` | NONE | sharp discharge / power-down whine | `acc_overclock_zap` (PlayLocal on player) | high |
| [ ] | EMP lockout EXPIRES | `_acc_elites.gsc:353` | NONE | reboot blip | `zmb_power_on` | low |
| [ ] | Subroutine T3 recursion drop (5th kill) | `_acc_elites.gsc:391-406` | NONE | bonus-drop sparkle | `zmb_powerup_grabbed` | low |
| [ ] | **Generic ability ACTIVATED** | `_acc_weapon_abilities.gsc:251-252` | NONE | ability-armed whoosh (baseline) | `zmb_perk_packa_upgrade` | high |
| [ ] | Ability DENY (cooldown/none) | `_acc_weapon_abilities.gsc:221,228,242` | NONE | deny error tone | `zmb_no_purchase` | med |
| [ ] | Ability READY again | `_acc_weapon_abilities.gsc:249` | NONE | subtle ready chime | `zmb_perk_bottle_ready` | low |
| [ ] | Precision Mode armed | `_acc_weapon_abilities.gsc:293-301` | NONE | scope-zoom / target-lock click | `zmb_scope_in` | med |
| [ ] | Focus Fire armed | `_acc_weapon_abilities.gsc:303-311` | NONE | weapon spin-up ramp | `zmb_minigun_spinup` | med |
| [ ] | Slug Round armed | `_acc_weapon_abilities.gsc:313-323` | NONE | shell-chamber cha-chunk | `zmb_shotgun_pump` | med |
| [ ] | **Whirlwind activated (AoE clear)** | `_acc_weapon_abilities.gsc:336-396` | NONE | swooshing spin gust + impact thuds | `zmb_whoosh_big` | high |
| [ ] | Stabilizer armed *(inert)* | `_acc_weapon_abilities.gsc:277-291` | NONE | brace servo whir | custom | low |
| [ ] | ACC round START | `_acc_main.gsc:345-352` | SILENT(stock?) | optional cyber round sting | `zmb_round_start` | low |
| [ ] | ACC round END | `_acc_main.gsc:347-349` | SILENT(stock?) | round-cleared accent | `zmb_round_over` | low |
| [ ] | Elite pressure pulse incoming | `_acc_elites.gsc:135-154` | NONE | ominous warning swell pre-spawn | `zmb_alarm` | med |
| [ ] | Special/dog round announce | `_acc_elites.gsc:122-133` | SILENT(stock?) | dog howl / special klaxon | `zmb_dog_round_start` | med |
| [ ] | Last-zombie / round milestone | `_acc_main.gsc` round fan-out | NONE | tension cue on final few | `zmb_vox_last_zombie` | low |
| [ ] | Modifier active at load | `_acc_modifiers.gsc:156-168` | NONE | one-time "ruleset engaged" tone | `zmb_challenge_start` | low |
| [ ] | Draft Mode pick offered | `_acc_modifiers.gsc:174-184` | NONE | notification chime | `zmb_perk_select` | low |
| [ ] | Shardless free-CW pick (r10/20/30) | `_acc_modifiers.gsc:186-203` | NONE | reward chime | `zmb_perk_select` | low |
| [ ] | Express start (skip + bonus) | `_acc_modifiers.gsc:226-244` | NONE | jackpot fanfare | `zmb_powerup_double_points` | low |
| [ ] | Roguelike down penalty | `_acc_modifiers.gsc:206-224` | NONE | node-lost power-down whine | `zmb_perk_lose_power` | low |
| [ ] | Adaptive Aim ammo-refund proc | `_acc_damage.gsc:548-555,745-753` | NONE | quiet ammo-chamber blip | `zmb_weap_reload_blip` | low |
| [ ] | Kinetic Battery charged shot | `_acc_damage.gsc:471-478` | NONE | heavy charged-shot thump | `zmb_charged_shot` | low |
| [ ] | Early-round +45% horde (r1-4) | `_acc_early_round_pacing.gsc:61-89` | NONE | none warranted (skip) | — | low |

---

## 6. World, Atmosphere & UI

| done | Event | Where it fires | State | Sound it wants | Suggested stock alias | Pri |
|---|---|---|---|---|---|---|
| [ ] | **POWER ON — the breaker flip** | stock `_zm_power.gsc` prefab (`.map:3161`) | SILENT(stock) | breaker CLUNK + rising electrical hum | `zmb_switch_flip` + `zmb_power_on` | high |
| [ ] | Power-on fog settle + light warm-up | `_acc_atmosphere.gsc:159,267` | NONE | ambient power-grid wake swell | `zmb_power_on` / custom `acc_power_swell` | med |
| [ ] | **Door BUY + open** (8 buyable + 2 underground) | `.map:4599…4858` (`_zm_blockers.gsc`) | SILENT(stock) | buy ka-ching + debris/scrape rumble | `zmb_buildable_purchase` + `zmb_door_slide_open` | high |
| [ ] | **Mystery BOX full suite** (open/fly/ready/grab/teddy/move) | `.map` 6 spots (`_zm_magicbox.gsc`) | SILENT(stock) | lid creak + gun-fly whir + ready shing + teddy giggle + poof | `zmb_box_open` + `zmb_box_gun_loop` + `zmb_box_ready` + `zmb_box_move` + `zmb_box_teddy_giggle` | high |
| [ ] | **PaP cook + ready + deny** | `_acc_pap_levels.gsc` (calls stock names) | SILENT(stock) | churn + ding + deny | `zmb_perks_packa_upgrade` + `zmb_perks_packa_ready` + `zmb_perks_packa_deny` | high |
| [ ] | Perk buy DENY at slot cap | `_acc_perk_info.gsc:143` (calls `evt_perk_deny`) | SILENT(stock) | perk-machine "no" buzz | `evt_perk_deny`→`acc_perk_deny` | high |
| [ ] | Mega bottle DISPENSE on bench | `_acc_mega_bottles.gsc:441` (calls `evt_bottle_dispense`) | SILENT(stock) | vending bottle-drop clunk | `evt_bottle_dispense`→`acc_bottle_dispense` | med |
| [ ] | PhD dive-to-prone explosion | `_acc_perk_phd_flopper.gsc:262` (calls `evt_nuke_flash`) | SILENT(stock) | explosion boom | `evt_nuke_flash`→`acc_phd_nova` | med |
| [ ] | **Data Shard pickup / spend confirm** (5 call-sites) | shards/perks/reactor/exo all call `acc_shard_pickup` | SILENT(acc-undef) | bright cyber data-chime | **add `acc_shard_pickup` row** | high |
| [ ] | Decon klaxon | `_acc_decontamination.gsc:253` (calls `acc_decon_alarm`) | SILENT(acc-undef) | industrial siren bed | **add `acc_decon_alarm` row** | med |
| [ ] | Ambient city/rain bed (OFF by default) | `_acc_atmosphere.gsc:393` (`acc_amb_city_bed`, `acc_amb_on 0`) | WORKS but OFF | rainy cyber-city loop | `acc_amb_city_bed` — author wav + turn ON | med |
| [ ] | **Player DOWNED → last stand** | stock `_zm_laststand.gsc` (`player_downed` notify) | SILENT(stock) | down stinger + heartbeat + death-screen laugh | `zmb_laststand_down` + `zmb_heartbeat_loop` | high |
| [ ] | **Revive start + complete** | stock `_zm_laststand.gsc` | SILENT(stock) | revive charge whir + stand-up gasp | `zmb_revive_start` + `zmb_revive_finished` | high |
| [ ] | GAME OVER + round transitions | stock end_game; `_acc_main.gsc:352` | SILENT(stock) | game-over sting / Samantha laugh + round tick | `zmb_gameover_stinger` + `zmb_round_start` | med |
| [ ] | **Points blip + generic PURCHASE confirm** | stock `zm_score::` + buyable triggers | SILENT(stock) | score blip + buy cha-ching | `zmb_cha_ching` / `zmb_points_gain` | high |
| [ ] | Perk machines + PaP light up on power | `_acc_perk_lights.gsc:71` (visual only) | NONE | flicker-on buzz + per-perk jingle loop | `zmb_perks_*_jingle` + `zmb_elec_buzz` | med |
| [ ] | Map intro THEME (once) + stock music killed | `_acc_atmosphere.gsc:433,110` | WORKS | CC0 cyberpunk theme | `acc_main_theme` (done) | low |

---

## 7. ALREADY WORKING (custom acc_* — DO NOT TOUCH)

These play correctly today. Leave them alone unless re-balancing.

- `acc_main_theme` — intro theme on spawn (`_acc_atmosphere.gsc:433`); stock music suppressed.
- `acc_amb_city_bed` — city/rain ambient bed (`_acc_atmosphere.gsc:393`) — **alias works but gated OFF (`acc_amb_on 0`); author the wav + turn on.**
- `acc_brutus_music` — boss battle loop + 4s fade (`_acc_boss.gsc:270`). Plays for Phantom; **Core never calls boss_music() — wire it (see Bosses table).**
- `acc_glitch_warp` — Glitch Stalker blink + Phantom reveal (`_acc_boss_glitch.gsc:442`, `_acc_boss_phantom.gsc:368`). Available to reuse for Phase Step, teleporter elite, Phase Serum.
- `acc_overclock_zap` — overclock tier-up zap (`_acc_overclocks.gsc:299`). Reusable for crit / EMP.
- `acc_mega_drink` — Mega upgrade sting (`_acc_mega_bottles.gsc:246`), layered over the (stock, maybe-silent) bottle gulp.
- `acc_headshot_ding` — headshot-kill 2D ding (`_acc_damage.gsc:546`).
- NSZ Brutus pack (`nsz_brutus.csv`): spawn/footstep/swing/helmet/death — all working.

---

## 8. TOP-PRIORITY FIRST PASS (~14 wires for max impact)

Do these first — they're the loudest absences in normal play. Roughly ordered by
how often a player hits them × how dead the silence feels.

1. **Data Shard pickup / spend** — add the `acc_shard_pickup` row. ONE row fixes
   5 call-sites (shard grab, cache, Neural Expansion buy, Reactor reward, Exo
   tier). The core currency is fully mute today.
2. **Mystery Box full suite** — box currently mimes silently. Add box-named rows
   (`zmb_box_open/gun_loop/ready/move/teddy_giggle`). Single most-used object.
3. **Pack-a-Punch cook/ready/deny** — code already calls the stock names; just
   define `acc_*` (or stock-named) rows. Iconic, fully silent.
4. **Power ON breaker** — the biggest atmosphere beat; clunk + rising hum.
5. **Door buy + open** — 10 doors, every one silent on purchase.
6. **Powerup drop + grab + announcer VO** — fixes Max Ammo / Insta-Kill / Nuke /
   Double Points / Fire Sale / Carpenter AND every Altar/Emergency/Reactor/elite
   drop at once (all route through `specific_powerup_drop`).
7. **Player downed + Revive** — critical co-op UX, both silent.
8. **Points blip + generic purchase cha-ching** — the constant dopamine loop.
9. **Perk buy drink + jingle** + **Mega dispense** (`evt_bottle_dispense`) +
   **perk DENY** (`evt_perk_deny`).
10. **Subroutine Core**: wire `boss_music(core)` (one line) + spawn telegraph +
    death sting — the full boss is currently silent end to end.
11. **Glitch Stalker** wave-inbound alarm + vuln-window cue + death de-rez —
    makes the signature mini-boss readable by ear.
12. **Event alarms**: Decon klaxon (`acc_decon_alarm` row), Lockdown SEAL slam,
    Hack/Overload success+fail stings, Trench surge/danger.
13. **Shielded elite** spawn clank + frontal-absorb ricochet (teaches "flank").
14. **Teleporter + EMP elite** spawn/ability cues (reuse `acc_glitch_warp` /
    `acc_overclock_zap` — zero new wavs needed).

---

## 9. STOCK ALIASES TO EXTRACT (Greyhound shopping list, deduped)

Each maps to one or more rows above. Extract the wav, re-encode 48k/16-bit, add
an `acc_*` (or stock-named, for stock-driven flows) row.

### Perk / PaP / vending (highest reuse)
- `zmb_perks_packa_upgrade` (PaP cook; also Hack/Overload start, implant, Brutus reward, skill-unlock)
- `zmb_perks_packa_ready` (PaP ready; Hack success, cache rearm, nitro recharged, repair-kit)
- `zmb_perks_packa_deny` (PaP/perk/event DENY everywhere — the universal "no" buzz)
- `zmb_perks_packa_beep` (hold-progress / off-point / countdown beeps)
- `zmb_perk_packa_loop` (trace / hold / danger drone loops)
- `zmb_perks_packa_filldrink`, `zmb_perks_drink` (perk gulp)
- `zmb_perks_<perk>_jingle` (per-machine jingle loops; incl. electric_cherry)
- `zmb_perks_jingle_packa` (lockdown-cleared fanfare)
- `zmb_perks_shatter` (lose-perks de-buff)
- `evt_perk_deny`, `evt_bottle_dispense` (already called by name in our code)

### Powerups + announcer VO
- `zmb_spawn_powerup`, `zmb_spawn_powerup_loop` (drop ding + idle beacon)
- `zmb_powerup_grabbed`, `zmb_powerup_grab`, `zmb_powerup_drop`
- `zmb_perk_grab`, `zmb_bgb_pickup` (reward/grant chimes)
- `vox_zmba_powerup_maxammo_0`, `..._instakill_0`, `..._nuke_0`, `..._doublepoints_0`, `..._firesale_0`, `..._carpenter_0`
- `zmb_carpenter` (board-repair hammer loop)
- `evt_nuke_flash` (nuke whoomp; also PhD nova — already called by name)
- `zmb_cha_ching`, `zmb_points_gain`, `zmb_cha_ching_deny`, `zmb_no_purchase`, `zmb_no_money` (economy + deny family)

### Power / electrical / events
- `zmb_switch_flip`, `zmb_power_on` / `zmb_perks_power_on`, `zmb_power_off`
- `zmb_alarm`, `zmb_alarm_loop` (Reactor/DEFCON/Decon klaxons)
- `zmb_lightning_zap`, `zmb_elec_trap_zap`, `zmb_elec_buzz`
- `zmb_emp_explode`
- `zmb_door_slam_metal`, `zmb_door_slide_open`, `zmb_debris_move`, `zmb_buildable_purchase`

### Mystery box
- `zmb_box_open`, `zmb_box_gun_loop`, `zmb_box_ready`, `zmb_box_move`, `zmb_box_move_stop`, `zmb_box_poof`, `zmb_box_teddy_giggle`

### Bosses / enemies
- `zmb_mechz_spawn`, `zmb_mechz_death`, `zmb_mechz_bullet_impact`
- `zmb_margwa_spawn`, `zmb_margwa_death`
- `zmb_brutus_spawn`, `zmb_brutus_helmet_off`
- `zmb_thrasher_attack`, `zmb_cloaker_reveal`
- `zmb_apothicon_fly_spawn`, `zmb_apothicon_fly_death`
- `zmb_vo_round_robot_taunt`, `zmb_vox_zmball_round_start`, `zmb_dog_round_start`, `zmb_dog_howl`, `zmb_vox_last_zombie`
- `zmb_bullet_impact_metal` (shield ricochet)
- `zmb_zombie_rise_dirt` (trench eruption)

### Combat / weapon-ability / misc
- `zmb_scope_in`, `zmb_minigun_spinup`, `zmb_shotgun_pump`, `zmb_whoosh_big`
- `zmb_weap_reload_blip`, `zmb_charged_shot`
- `zmb_laststand_down`, `zmb_heartbeat_loop`, `zmb_revive_start`, `zmb_revive_finished`
- `zmb_gameover_stinger`, `zmb_round_start`, `zmb_round_over`, `zmb_round_start_stinger`
- `zmb_player_land_hard`, `zmb_blackhole_ambient`, `zmb_challenge_start`, `zmb_perk_select`

### NEW acc_* rows to author (no stock extract needed / custom)
- `acc_shard_pickup` (referenced 5×, must exist)
- `acc_decon_alarm` (referenced, must exist)
- `acc_amb_city_bed` wav (alias exists, needs the wav + `acc_amb_on 1`)
- optional: `acc_perk_deny`, `acc_bottle_dispense`, `acc_phd_nova`, `acc_power_swell` (rename the `evt_*`/`zmb_*` calls to these once authored)

---

*Source: 187-event code audit (this session). Update rows/state as wavs land and
the alias CSV grows. Build sound-only changes with `-GscOnly` and the GAME CLOSED
(the .sabs bank is file-locked while BlackOps3 runs — see memory
`custom-sound-48k-and-game-lock`).*
