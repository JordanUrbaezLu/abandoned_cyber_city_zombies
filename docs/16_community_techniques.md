# 16 - Community Techniques Ledger

Every reusable technique harvested from external BO3 zombies codebases,
with the exact mechanism and source citation. **Convention: every time we
explore an external codebase, findings land here** (raw dossiers go to
[research/](research/); design-level map studies go to
[13_reference_maps_study.md](13_reference_maps_study.md)). The original core (143
techniques across the 18 systems indexed below) was mined 2026-06-12 by a 7-agent
fleet reading actual source line-by-line (raw output:
[research/community_mining_raw.json](research/community_mining_raw.json)); the
**"Newly discovered source repos"** section further down was appended 2026-07-03
(sawblade trap, Scobalula item drops, Resxt soul-boxes/challenges/buyable-ending,
kelson8 Wonderfizz LUI menu, Owen-C137 Aetherium HUD, and more) and is **not**
reflected in the per-system counts below.

## Technique index (143 techniques across 18 systems — plus the 2026-07-03 appended repos)

- **perks** (34): Give; zm_usermap; Per; Trigger disable/enable by; Perk; Exact perk power; ...
- **misc** (24): 4; Custom color grading; Ambient prop animation kit (no xanims needed) + AnimScripted NPCs when needed; #insert of the core .gsc into sibling area scripts (shared macros across one namespace); World clientfields for fog/skybox/exposure/eye; GSC utilities worth stealing (nuked_utility); ...
- **hud** (13): Minimal LUI menu (blackscreen overlay); GSC; Custom TTF fonts in both classic HudElems and LUI; Localization pipeline; Zero; Mechanical world; ...
- **weapons** (9): Start; Custom weapon table CSV wiring (server + client + zone); Full; Starting; Mutex; AAT re; ...
- **publishing** (8): Workshop artifact set; Override stock scripts by shipping same; Repo layout + .zone anatomy for a heavily; Mod; Localization reality check; Zone manifest composition; ...
- **zones** (7): Zone adjacency flags can be left unset; Zone manifest split into .zpkg via include; 12; Room manager; Runtime random; Multi; ...
- **intro** (7): Full playable; CSC; In; Custom intermission camera ride (level.custom_intermission); Delay round 1 until a pre; Fade; ...
- **sound** (7): zm_audio music states backed by custom tracks via mus_<stem>_intro aliases; Map sound alias CSV anatomy; Layered scripted ambience; Music easter eggs + round music states; Workshop sound config (.szc) shape; Per; ...
- **boss** (7): Drop-in custom-archetype boss (NSZ Brutus); End; Endgame horde; Special; Scripted multi; Entity; Game
- **easteregg** (5): Keycard pickup; Scripted terminal/console interactions with model; Shootable + melee; Diegetic keypad code entry (no LUI); Shootable
- **box** (5): Mystery box move control + restricted locations; Mystery box gated on per; Live box; Kill switches for box / wallbuys / gobblegum / PaP; Animated prop via custom animtree (UGX weapon box) + dynamic weapon world models
- **powerups** (5): Zone; Script; Soul; Complete custom powerup recipe (register + drop; Custom powerup registration (drop
- **optimization** (4): Shipped performance budget; zombie_total_subtract bookkeeping for scripted kills; Zombie lifecycle hardening; Linker
- **doors** (4): Mover/destination naming conventions; Animated debris door reusing zm_blockers buy logic; Variable door pricing by player count via live hint rewrite; Programmatic open
- **elevators** (1): Fake
- **zombies** (1): Zombie head
- **teleporters** (1): Castle
- **craftables** (1): World

## PERKS

### Give-all-perks + max-ammo reward via level._custom_perks iteration

a_str_perks = GetArrayKeys(level._custom_perks); foreach str_perk: if(!player HasPerk(str_perk)) player zm_perks::give_perk(str_perk, false) (false = unpaid/no machine). Max ammo: foreach weapon in player GetWeaponsList(true): if(player HasWeapon(weapon)) player GiveMaxAmmo(weapon). Also main() sets level.perk_purchase_limit = 100 to lift the 4-perk cap globally.

- **Source:** MattFiler/zm_alien_isolation usermaps/zm_alien_isolation/scripts/zm/zm_alien_isolation.gsc L209, L433-456
- **For our map:** Direct mechanism for our Mega-perk rewards and Overclock 'all perks for 60s' effects; level._custom_perks keys are the canonical registered-perk enumeration.

### zm_usermap::perk_init() activates perk machine light FX

Stock template zm_usermap.gsc:446 defines perk_init() setting level._effect["jugger_light"|"revive_light"|"marathon_light"|"widow_light"|"sleight_light"|"doubletap2_light"|"deadshot_light"|"additionalprimaryweapon_light"] = zombie/fx_perk_*_factory_zmb — but main() never calls it. zm_nuked.gsc calls 'zm_usermap::perk_init();' right after zm_usermap::main(). The .csc side already has the matching include_perks(); the zpkg must also list each 'fx,zombie/fx_perk_*_factory_zmb' line.

- **Source:** zm_nuked scripts/zm/zm_nuked.gsc:134-137; stock zm_usermap.gsc:435-455; zpkg:35-84
- **For our map:** One-line fix we almost certainly need: our map places perk machines but nothing in our entry script calls perk_init(), so machine lights would be dark.

### Per-run randomized perk machine placement via struct_class_names injection

At __init__ (registered with REGISTER_SYSTEM/system::register so it runs pre-main): delete every map-placed 'zm_perk_machine' struct (struct::get_array then ent Delete() + struct::delete()). Build level.nuked_perks[n]=SpawnStruct() with .model (p7_zm_vending_*), .script_noteworthy (specialty_*), .turn_on_notify. Read candidate location structs (script_noteworthy 'zm_random_machine', each .target → positional struct carrying .script_int), randomize with zombie_death::randomize_array, then for each chosen struct set .targetname="zm_perk_machine_override", copy .model/.script_noteworthy/.turn_on_notify/.blocker_model onto it, and APPEND it into level.struct_class_names["targetname"]["zm_perk_machine_override"]; set level.override_perk_targetname="zm_perk_machine_override" so stock _zm_perks builds machines from your synthetic structs. Solo branch (GetNumExpectedPlayers()==1) forces quick revive into a dedicated 'solo_revive' pool first.

- **Source:** zm_nuked scripts/zm/zm_nuked_perks.gsc:63-238
- **For our map:** This is the canonical shipped pattern for our per-run randomization pillar — randomize perk/wallbuy/machine locations each run without touching the .map.

### Trigger disable/enable by -10000z origin displacement

#define TRIGGER_OFF_OFFSET_VECTOR (0,0,-10000). trigger_off(): if (!isdefined(self._wardog_old_origin)) { self._wardog_old_origin=self.origin; self.origin += offset; self notify("trigger_off"); }. trigger_on() restores saved origin and clears the field. Works on any stock purchase trigger (they used GetEnt("vending_jugg","target") to fetch the perk's trigger).

- **Source:** zm_nuked scripts/zm/zm_nuked_perks.gsc:55,879-899
- **For our map:** Cheap, stock-compatible way to gate any wallbuy/perk/craftable purchase behind our Cyberware/Overclock unlock conditions.

### Perk-machine arrival cinematic (vehicle path + clientfield FX + landing damage)

Server: machine MoveTo +20000z at init (move_perk saves .original_pos/.original_angles), trigger_off its purchase trigger. To deliver: machine clientfield::set("clientfield_perk_intro_fx",1); machine LinkTo(level.perk_arrival_vehicle [an invisible 'tag_origin' vehicle ent], "tag_origin"); vehicle AttachPath(GetVehicleNode("perk_arrival_path_"+machine.script_int,"targetname")); StartPath(); waittill("reached_end_node"); Unlink; restore origin/angles; clientfield 0; trigger_on(); level notify(machine.turn_on_notify); machine Vibrate + PlaySound("zmb_perks_power_on") + zm_perks::perk_fx(undefined,1) + thread zm_perks::perk_fx("jugger_light" etc). Landing damage: Earthquake(0.7,2.5,org,1000), RadiusDamage(org,300,10,5,undefined,"MOD_EXPLOSIVE"), players in radius SetStance("prone")+ShellShock("default",1.5); zombies via Array::get_all_closest + DoDamage(health+100). Client (.csc): clientfield::register("scriptmover","clientfield_perk_intro_fx",VERSION_SHIP,1,"int",&handler,...); handler case 1: self.fx=PlayFXOnTag(localClientNum,"dlc5/moon/fx_meteor_trail",self,...); self.fx LinkTo(self); case 0: StopFX+Delete.

- **Source:** zm_nuked scripts/zm/zm_nuked_perks.gsc:242-516,563-590,672-877; scripts/zm/zm_nuked_perks.csc:23-44
- **For our map:** Reusable delivery cinematic for our Mega perk upgrades or Overclock stations; also documents the scriptmover-clientfield FX idiom we don't use yet.

### Exact perk power-on notify pairs (turn_perks_on)

For machines hidden at start, unpause then fire BOTH notifies stock listens for, 0.1s apart: zm_perks::perk_unpause(PERK_STAMINUP); level notify("marathon_on"); wait .1; level notify("specialty_staminup_power_on"). Pairs: revive_on/specialty_quickrevive_power_on, sleight_on/specialty_fastreload_power_on, doubletap_on/specialty_doubletap2_power_on, juggernog_on/specialty_armorvest_power_on, deadshot_on/specialty_deadshot_power_on, widows_wine_on/specialty_widowswine_power_on, additionalprimaryweapon_on/specialty_additionalprimaryweapon_power_on.

- **Source:** zm_nuked scripts/zm/zm_nuked_perks.gsc:627-669
- **For our map:** Ground-truth notify names for scripting always-on or quest-unlocked perk machines without the power switch.

### Earnable perk slot increase (level.perk_purchase_limit++)

Easter-egg completion handlers simply do level.perk_purchase_limit++ (stock _zm_perks enforces the limit at purchase time). Nuked grants +1 for shooting all 28 mannequin heads, +1 for shooting all wall outlets, +1 for 3 teddy bears, gated by flag 'quest_perk_enable'.

- **Source:** zm_nuked scripts/zm/classic_features/mannequins.gsc:64-68; scripts/zm/new_features/ee_secondary.gsc:107-111; scripts/zm/classic_features/ee_music.gsc:60-64
- **For our map:** Direct mechanism for a Cyberware-tree node or Data Shard purchase that raises max perks.

### Relocatable Pack-a-Punch via custom_power_think + zbarrier states

level.pack_a_punch.custom_power_think=&fn (self = PaP machine). fn: self.zbarrier _zm_pack_a_punch::set_state_hidden(); pick destination struct; set_state_initial(); set_state_power_on(); on arrival set self.origin/.angles AND self.zbarrier.origin/.angles to new spot (+(0,0,7)); spawn collision: c=Spawn("script_model",org,1); c SetModel("zm_collision_perks1"); c.script_noteworthy="clip"; c DisconnectPaths(); raise trigger: level.pack_a_punch.triggers[0].origin += (0,0,level.pack_a_punch.interaction_height). Arrival itself is the same vehicle-path cinematic with a 'p7_zm_vending_packapunch_on' dummy model riding the vehicle, then zm_power::turn_power_on_and_open_doors().

- **Source:** zm_nuked scripts/zm/classic_features/pack_a_punch_from_the_sky.gsc:33-174
- **For our map:** Gives us verified PaP relocation/late-spawn mechanics for randomized PaP placement or a Mega-upgrade station that moves per run.

### Spare change under perk machines (stock one-liner)

Call zm_perks::spare_change() — stock scans triggers targetname 'audio_bump_trigger' with script_sound 'zmb_perks_bump_bottle'; going prone in one grants add_to_player_score(100) once + purchase sound. Map needs those KVP'd use-triggers under machines.

- **Source:** zm_nuked scripts/zm/zm_nuked.gsc:141; stock _zm_perks.gsc:1731-1761
- **For our map:** Free flavor secret for our start room; we'd add the audio_bump_trigger structs in Radiant and one GSC line.

### Matarra custom-perk registration recipe + unused stock specialty enums

A fully custom perk = one .gsc/.gsh pair calling, in function autoexec/init: zm_perks::register_perk_basic_info(PERK_X,"phdlite",cost,&"ZM_ABBEY_PERK_PHD_LITE",GetWeapon(bottle)); register_perk_precache_func; register_perk_clientfields(PERK_X,&reg_cf,&set_cf) (cf name like "hudItems.perks.phd_lite", clientuimodel, 2-bit); register_perk_machine(PERK_X,&machine_setup) where machine_setup(use_trigger,perk_machine,bump_trigger,collision) assigns use_trigger.script_sound/script_string/script_label and perk_machine.targetname; register_perk_threads(PERK_X,&give,&take) (give does self SetPerk(PERK_X)); register_perk_host_migration_params(PERK_X,radiant_machine_name,light_fx); optional register_perk_damage_override_func(&f). Machine assets: level.machine_assets[PERK_X]=SpawnStruct() with .weapon/.off_model/.on_model. PERK_X itself must be an unused stock specialty string — they use specialty_disarmexplosive (PhD Lite), specialty_holdbreath (Poseidon's Punch), specialty_jetpack (Double Tap 1.0); HasPerk/SetPerk then work natively and stock stats like specialty_jetpack_drank track it.

- **Source:** ohm-nabar/zm_building scripts/zm/_zm_perk_phdlite.gsc:62-71,179-227; _zm_perk_phdlite.gsh:12 (specialty_disarmexplosive); _zm_perk_poseidonspunch.gsh:12; _zm_perk_doubletaporiginal.gsh:12; zm_building.gsc:576-578
- **For our map:** If we outgrow the cherry hijack for PhD Flopper or add a 10th custom perk, this is the shipped-proven full registration path; the unused-specialty list (disarmexplosive/holdbreath/jetpack) is the scarce resource to budget.

### Complete fix list for stock-but-unfinished _zm_perk_electric_cherry (validates our cherry-slot hijack)

Diff vs stock shows every placeholder that must be patched for the stock cherry pipeline to ship: (1) cost is 10 (placeholder) -> real cost; (2) ELECTRIC_CHERRY_SHADER points at specialty_quickrevive_zombies -> own shader; (3) machine models are p7_zm_vending_nuke placeholders -> p6_zm_vending_electric_cherry_off/_on (xmodels exist stock, just add zone lines); (4) hint string is &"ZOMBIE_PERK_WIDOWSWINE" (wrong perk) -> own localized string; (5) custom_perk_machine_setup wires STAMINUP audio/targets by copy-paste bug: script_sound mus_perks_stamin_jingle, script_string marathon_perk, target/targetname vending_marathon -> must change all six KVP assignments to electriccherry values; (6) reload-attack damage code has hardcoded n_clip_current=1; n_clip_max=10 with real reads commented out under a wrong var name -> restore n_clip_current=self GetWeaponAmmoClip(current_weapon); n_clip_max=current_weapon.clipSize; (7) no insta-kill handling -> add || level.zombie_vars[self.team]["zombie_insta_kill"]==1 to both kill checks.

- **Source:** ohm-nabar/zm_building scripts/zm/_zm_perk_electric_cherry.gsc:30-59,76-77,121-129,229-231,385-388,446-476 (vs zeroy99/bo3_modtools stock)
- **For our map:** Checklist to audit our _acc_perk_electric_cherry finish against — items 5 and 6 are silent-failure traps (wrong jingle/targetname keeps machine bound to staminup; clip-size placeholder breaks reload-attack scaling).

### Script-spawned perk machine: inject struct into level.struct_class_names

function create_perk_loc(origin,angle,perk,model,parameters,string){ struct=struct::spawn(origin,angle); struct.targetname="zm_perk_machine"; struct.script_noteworthy=perk; struct.model=model; struct.script_string=string; struct.script_parameters=parameters; then append to level.struct_class_names["targetname"]["zm_perk_machine"] (creating the array if absent). Must run before zm_perks init consumes the array. Companion move_perk_machine(perk,origin,angles) reveals the runtime anatomy of a placed machine: trigger = GetEntArray(perk,"script_noteworthy")[0]; children are t_use.machine (vending model), t_use.bump (bump trigger), t_use.s_fxloc (fx struct), t_use.clip (collision — call clip ConnectPaths() before moving and DisconnectPaths() after).

- **Source:** ohm-nabar/zm_building scripts/Sphynx/_zm_sphynx_util.gsc:684-769
- **For our map:** Lets our per-run randomization relocate/spawn perk machines from GSC instead of hand-authoring every position in Radiant — pair with our existing inline-struct knowledge.

### Mega perk upgrades = challenge quest sets player flag; effect = stacking a second stock specialty

Per-player state on connect: self.hasX2=false, self.isUpgradingX, self.x_challenge_goal/progress; one thread per perk loops: when HasPerk(X) and not upgrading, start a timed challenge (e.g. 10 cherry kills within 1 round: snapshot level.round_number and a kill counter, fail resets progress); success calls givePerkUpgrade(X) setting self.hasX2=true. Kill attribution via zm::register_zombie_damage_override_callback(&f) whose signature gets willBeKilled — increment counters when isPlayer(attacker)&&(willBeKilled||insta_kill). Effects file polls IsPerkUpgradeActive(X) (=HasPerk(X)&&hasX2) every 0.05s and applies/removes the upgrade by literally SetPerk/UnSetPerk of a SECOND stock specialty: upgraded DoubleTap1.0 -> SetPerk(specialty_doubletap2); upgraded StaminUp -> SetPerk("specialty_unlimitedsprint"); upgraded Cherry -> SetPerk(PERK_SLEIGHT_OF_HAND); upgraded QuickRevive -> SetMoveSpeedScale(1.5) bursts on heal/revive notifies; upgraded Mule Kick -> gun-return-after-down via saved self.gunToGiveBack + clip/stock, re-given when zm_magicbox::can_buy_weapon(). Perk-loss hook: level.perk_lost_func=&cb (self=player, arg=perk). Perk cap override: level.get_player_perk_purchase_limit=&func returning int.

- **Source:** ohm-nabar/zm_building scripts/zm/zm_perk_upgrades.gsc:20-36,122-144,146-344; scripts/zm/zm_perk_upgrades_effects.gsc:25-247
- **For our map:** This is our Mega perk upgrade system, shipped: piggyback effects on free stock specialties (no second machine, no HUD plumbing for the buff itself), gate via challenge or Data Shard spend. We already use the per-player `level.get_player_perk_purchase_limit` hook (`_acc_perks.gsc:73` → `acc_perk_slot_limit`; the global `level.perk_purchase_limit` stays at 4 in the entry script, entry `.gsc:320`, and the hook adds each player's earned slots on top — up to `ACC_PERK_SLOT_MAX=10`); `level.perk_lost_func` is the other hook available for Mega-upgrade take-backs.

### Perk pause/retain library functions

_zm_sphynx_util.gsc provides player_pause_perk(perk,retain_perk=1)/player_unpause_perk(perk) and give_player_loadout(s_loadout,...)/get_player_loadout() for snapshot-restore of weapons+perks (used around boss/teleport sequences), plus set_perk_limit_now(n), give_all_perks/take_all_perks, remove_perk_from_map(perk). Also generic unitrigger factory create_unitrigger_general(str_hint,n_radius,func_prompt,func_logic,"unitrigger_radius_use") and a hold-to-use progress_bar(targetname,hintstringUse,useTime,progressString,craftingSoundLoop,craftingSoundComplete,offset) built on overriding zm_unitrigger internals.

- **Source:** ohm-nabar/zm_building scripts/Sphynx/_zm_sphynx_util.gsc:928-1020,1566-1586,1789-2073,2074-2165
- **For our map:** Loadout snapshot/restore is exactly what our boss arena and Antiverse-style sequences need; the progress_bar unitrigger is a ready-made craftable/hack-terminal interaction for Cyberware stations.

### Stock perk gating + per-perk disable (level.custom_perk_validation)

`level.custom_perk_validation = &f(player)` is called with self = the vending trigger; return false to block purchase (stock _zm_perks.gsc:560-562). UGX keys the check on `self.script_noteworthy` (= specialty name) against its settings registry. To also fix the hint: set `level._custom_perks[specialty].hint_string = undefined` then `trig SetHintString("Perk is disabled...")`. Blanket disable: `GetEntArray("zombie_vending","targetname")` → `trig TriggerEnable(false)`. Programmatic perk grant (no machine): `self SetPerk(perk)` + `self zm_perks::set_perk_clientfield(perk, PERK_STATE_OWNED)` (HUD icon), remove with UnSetPerk + PERK_STATE_NOT_OWNED; jugg needs `zm_perks::perk_set_max_health_if_jugg(PERK_JUGGERNOG, true, false)` and reset via ('health_reboot', true, true). Sharpshooter's kill-milestone perk ladder (perks_toggle, ugxm_sharpshooter.gsc:399-464) is a full grant/revoke implementation.

- **Source:** treminaor/ugx-mod-bo3 ugxmod/scripts/zm/ugxm/ugxm_init.gsc:160-197,244-250; ugxm_sharpshooter.gsc:327-488; ugxm_chaosmode.gsc:1151-1218; stock _zm_perks.gsc:560-562,969
- **For our map:** set_perk_clientfield + perk_set_max_health_if_jugg is the exact API our Mega perk upgrades and Cyberware-granted perks need to grant/revoke perks with correct HUD icons outside machines.

### CSC client-module pattern: perk clientfields + FX callbacks (client-module blueprint)

The cherry CSC is a complete client module: `REGISTER_SYSTEM("zm_perk_electric_cherry", &__init__, undefined)` works identically in .csc. GSC/CSC are MIRRORED registrations with different arg meanings: GSC `zm_perks::register_perk_clientfields(PERK, &register_clientfield, &set_clientfield)` vs CSC `(PERK, &client_field_func, &code_callback_func)` (stock _zm_perks.gsc:1951 / .csc:95). Clientfield bridge: SERVER registers `clientfield::register("actor","tesla_death_fx",VERSION_SHIP,1,"int")` (no callback); CLIENT registers the SAME name/pool/version/bits with a callback: `clientfield::register("actor","tesla_death_fx",VERSION_SHIP,1,"int",&cb,!CF_HOST_ONLY,!CF_CALLBACK_ZERO_ON_NEW_ENT)`; callback signature `(localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump)` with self = the entity. Pools used: "actor", "vehicle", "allplayers", "clientuimodel" (per-player HUD state, set server-side via `self clientfield::set_player_uimodel(name, state)`). CSC precaches with `#precache("client_fx", path)` (GSC uses "fx"); play with `PlayFXOnTag(localClientNum, level._effect[name], self, "J_SpineUpper")`, cleanup StopFX/DeleteFx(localClientNum, handle, true), `SetFXIgnorePause`. Both files ship as scriptparsetree lines in the same zone. Bonus screen-filter CSC pattern in _filter.csc: setfilterpassmaterial(player.localClientNum, filterid, 0, level.filter_matid[name]) + setfilterpassenabled.

- **Source:** treminaor/ugx-mod-bo3 ugxmod/scripts/zm/_zm_perk_electric_cherry_fixed.csc:25-165; _zm_perk_electric_cherry_fixed.gsc:58-147; _filter.csc:20-35; stock _zm_perks.gsc:1951, _zm_perks.csc:95
- **For our map:** Our `.csc` client modules (perk FX, boss FX, Cyberware visuals — e.g. `_acc_lui.csc`, `_acc_boss_phantom.csc`, `_acc_perk_lights.csc`) use this exact mirrored-registration shape; it also validates our cherry-hijack since this is the community-fixed cherry our PhD Flopper pipeline descends from.

### Perk removal/refund via '<specialty>_stop' notify (perk take-back)

To strip a perk: `player notify(perk + "_stop")` — every stock/HB21 perk module runs a watcher on that notify which fully tears the perk down; track ownership via player.perks_active array (must be initialized [] in callback::on_spawned handler); refund amount from `level._custom_perks[str_perk].cost` (solo quick-revive cost reads 0 — special-case to 500, and decrement self.lives-- when removing specialty_quickrevive under zm_perks::use_solo_revive()); refund via zm_score::add_to_player_score(cost*pct). The refund prompt is a second unitrigger overlaid on the existing machine: iterate GetEntArray("zombie_vending","targetname"), perk name from each trigger's .script_noteworthy. Gotcha recorded in source: REGISTER_SYSTEM_EX __init__ needs `wait 0.01` before touching ents ("Any other wait seems to prevent the game from starting").

- **Source:** ColDog5044/zm_countryside scripts/zm/_war_perk_return.gsc:29-38,47-74,122-147; scripts/zm/_war_perk_return.gsh:3-4
- **For our map:** Core mechanic for Mega perk upgrades (notify '<specialty>_stop' on the base perk, then give the Mega variant) and for per-run randomization perk strips.

### Full custom-perk registration ledger (HarryBo21 module shape)

One module per perk (gsc+csc+gsh) with all tunables as .gsh #defines (cost, machine targetname e.g. "vending_phdflopper", alias, jingle/sting aliases, specialty string, clientfield name "hudItems.perks.<name>", bottle weapon "zombie_perk_can_<name>", off/on machine models, FX paths). GSC init calls in order: zm_perks::register_perk_basic_info(PERK, ALIAS, COST, &"HINT_STR", getWeapon(BOTTLE)); register_perk_precache_func(PERK,&fn); register_perk_clientfields(PERK,&register_fn,&set_fn); register_perk_machine(PERK,&machine_setup_fn); register_perk_host_migration_params(PERK, RADIANT_MACHINE_NAME, PERK); register_perk_threads(PERK,&give_fn,&take_fn); optional register_perk_machine_power_override(PERK,&power_fn) for non-grid machines. Perk bottle weapons must each have a `weapon,zombie_perk_can_<x>` zone line.

- **Source:** ColDog5044/zm_countryside scripts/zm/_zm_perk_phdflopper.gsc:49-56; scripts/zm/_zm_perk_phdflopper.gsh:1-53; zone_source/zm_countryside.zone:20-30
- **For our map:** Mostly adopted via our PhD Flopper cherry hijack, but register_perk_machine_power_override + the gsh-tunables layout are the clean path for Mega perk tier variants with their own machines.

### Reserved specialty strings are engine-valid — no hijack needed

Stock scripts/zm/_zm_perks.gsh (38 lines) already defines PERK_PHDFLOPPER="specialty_phdflopper" (L28), PERK_ELECTRIC_CHERRY="specialty_electriccherry" (L31), PERK_TOMBSTONE (L32), PERK_WHOSWHO (L33), PERK_VULTUREAID (L34), PERK_WIDOWS_WINE (L35), plus matching clientuimodel paths hudItems.perks.phdflopper/tombstone/whoswho/electric_cherry/vultureaid/widows_wine (L8-20). Stock _zm_perks.gsc function give_perk(perk,bought) at L738-740 does `self SetPerk( perk )` directly with these strings and HasPerk(perk) works — proven by shipped maps (zm_countryside checks `self hasPerk(PHDFLOPPER_PERK)`). For perks beyond the 13 reserved slots, community packs reuse other compiled-but-unused engine specialties: Polystyreeni timewarp uses "specialty_fireproof" (_zm_perk_timewarp.gsh L8), HarryBo21 Elemental Pop uses "specialty_combat_efficiency" (_zm_perk_elemental_pop.gsh).

- **Source:** zeroy99/bo3_modtools scripts/zm/_zm_perks.gsh L8-38, scripts/zm/_zm_perks.gsc L738-740; Polystyreeni/BO3 scripts/zm/_zm_perk_timewarp.gsh L8; ColDog5044/zm_countryside scripts/zm/_zm_perk_elemental_pop.gsh
- **For our map:** A future custom perk can be a first-class perk under its own specialty (e.g. specialty_phdflopper or specialty_fireproof, since cherry is now used for our PhD Flopper) instead of hijacking another pipeline — HasPerk/SetPerk/HUD all work.

### Canonical 6-call custom-perk registration chain (GSC half)

Every community perk uses the STOCK zm_perks:: registration API, in a module with `REGISTER_SYSTEM("zm_perk_X", &__init__, undefined)` (or REGISTER_SYSTEM_EX with __main__): (1) register_perk_basic_info(PERK, alias, cost, hint_string, GetWeapon(bottle)) — hint may be inline "Hold ^3[{+activate}]^7 for X [Cost: &&1]" (&&1 = cost substitution) or a localized &"REF"; (2) register_perk_precache_func(PERK, &precache) — precache sets level._effect[lightfx], level.machine_assets[PERK]=SpawnStruct() with .weapon/.off_model/.on_model; (3) register_perk_clientfields(PERK, &reg_cf, &set_cf) — reg_cf does clientfield::register("clientuimodel", "hudItems.perks.<key>", VERSION_SHIP, 2, "int"); set_cf does self clientfield::set_player_uimodel(path, state); (4) register_perk_machine(PERK, &machine_setup); (5) register_perk_threads(PERK, &give_func, &take_func) — take signature (b_pause, str_perk, str_result); (6) register_perk_host_migration_params(PERK, radiant_machine_name, light_fx). Stock _zm_perks.gsc then auto-runs perk_machine_think when alias+radiant_machine_name+machine_light_effect are all registered (L98-100), or runs your register_perk_machine_power_override thread instead (L94-96). All tunables live in a .gsh (#define PERK cost/model/fx/alias/jingle).

- **Source:** Velaseriat/zombies_PHD Scripts/_zm_perk_phdflopper.gsc L42-51; ColDog5044/zm_countryside scripts/zm/_zm_perk_vulture_aid.gsc L63-72; zeroy99/bo3_modtools scripts/zm/_zm_perks.gsc L90-100
- **For our map:** If we ever move our _acc_perk_electric_cherry off the stock cherry pipeline, this chain in our own module is the path — it is pure stock API (already verified style in docs/14) and removes the dependency on the unfinished stock cherry file.

### CSC half of a custom perk (required mirror module)

The .csc file mirrors the namespace + REGISTER_SYSTEM and registers THREE things via zm_perks::: register_perk_clientfields(PERK, &client_field_func, &code_callback_func) — client_field_func registers the SAME clientuimodel field with full arg form clientfield::register("clientuimodel", path, VERSION_SHIP, 2, "int", undefined, !CF_HOST_ONLY, CF_CALLBACK_ZERO_ON_NEW_ENT); register_perk_effects(PERK, light_fx_key); register_perk_init_thread(PERK, &init) — init sets level._effect[key]=fx_path (guarded by IS_TRUE(level.enable_magic) in some kits). FX callbacks: actor/vehicle clientfields get handler funcs with signature (localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump); play via PlayFXOnTag(localClientNum, level._effect[k], self, "J_SpineUpper"/"J_Eyeball_LE") + SetFXIgnorePause, clean up with DeleteFx/StopFX. #precache("client_fx", path) for every FX used client-side.

- **Source:** Velaseriat/zombies_PHD Scripts/_zm_perk_phdflopper.csc L29-57; treminaor/ugx-mod-bo3 ugxmod/scripts/zm/_zm_perk_electric_cherry_fixed.csc L29-66, L102-165
- **For our map:** Our cherry-slot perk needs exactly this `.csc` mirror module; the tesla shock-eyes handlers are a drop-in template for the cherry-slot zap visuals.

### Finished Electric Cherry completion (UGX Mod, shipped)

ugx-mod-bo3 ships _zm_perk_electric_cherry_fixed.gsc/.csc — a complete cherry: registration chain (L70-87) with register_perk_threads(PERK_ELECTRIC_CHERRY, &electric_cherry_reload_attack, &electric_cherry_perk_lost); reload attack thread (L353-492): waittill("reload_start"), per-weapon re-arm tracking via self.wait_on_reload array + check_for_reload_complete (waittill "reload") + weapon_replaced_monitor (waittill "weapon_change", checks GetWeaponsListPrimaries), anti-spam zombie caps by self.consecutive_electric_cherry_attacks (1:unlimited, 2:8, 3:4, 4:2, 5+:0), radius/damage via math::linear_map(clip_fraction, 1.0, 0.0, 32..128, 1..1045), cooldown = reload time + 3s (halved-ish by specialty_fastreload via GetDvarFloat("perk_weapReloadMultiplier")); last-stand nova via level.custom_laststand_func = &electric_cherry_laststand (L137) — 500 radius, 1000 dmg, +40 points per kill via zm_score::add_to_player_score; stun = self.zombie_tesla_hit=true + self.ignoreall=true for 4s, guarded by self.ai_state=="zombie_think" (L315-347); FX clientfields: "allplayers" electric_cherry_reload_fx (2-bit, set via CodeSetClientField), "actor"/"vehicle" tesla_death_fx(_veh)/tesla_shock_eyes_fx(_veh) (vehicle ones at VERSION_TU10); perk_lost notifies PERK_ELECTRIC_CHERRY+"_stop" to endon-kill the reload thread. Assets: bottle "zombie_perk_bottle_cherry", models p6_zm_vending_electric_cherry_off/_on, fx _t6/misc/fx_zombie_cola_revive_on + dlc1/castle/fx_castle_electric_cherry_down. KNOWN GAP: clip fraction is stubbed n_clip_current=1/n_clip_max=10 (L383-384), so radius/damage are always max — fix with weapon.clipSize if reimplementing.

- **Source:** treminaor/ugx-mod-bo3 ugxmod/scripts/zm/_zm_perk_electric_cherry_fixed.gsc L70-87, L132-147, L207-253, L315-347, L353-595; .csc L37-61
- **For our map:** Direct answer to 'did anyone finish stock cherry': yes — use this as the verified reference for our cherry-slot hijack, and lift its stun/notify/anti-spam patterns into our cherry-slot perk.

### Script-spawned perk machine (zero Radiant edits)

zm_perk_utility::place_perk_machine(origin, angles, perk, model): spawn("trigger_radius_use", origin+(0,0,60), 0, 40, 80) with .targetname="zombie_vending", .script_noteworthy=<specialty>, TriggerIgnoreTeam(); spawn("script_model", origin) SetModel(machine model); bump = spawn("trigger_radius", origin+(0,0,30), 0, 40, 80) with .script_activated=1, .script_sound="zmb_perks_bump_bottle", .targetname="audio_bump_trigger"; collision = spawn("script_model", origin, 1) SetModel("zm_collision_perks1"), .script_noteworthy="clip", disconnectPaths(); then call [[level._custom_perks[perk].perk_machine_set_kvps]](t_use, machine, bump, collision) to apply the perk's registered KVP setup (which sets use_trigger.script_sound=<jingle alias>, .script_string=<perk>_perk, .script_label=<sting alias>, .target=vending_<perk>; machine.targetname=vending_<perk>). This mirrors exactly what stock perk_machine_think expects from Radiant-placed machines.

- **Source:** ColDog5044/zm_countryside scripts/zm/_zm_perk_utility.gsc L554-583
- **For our map:** Huge for our per-run randomization pillar: spawn the 10-perk roster at randomized struct locations from GSC each run instead of fixed hand-authored machines in the .map (the live Lab-alcove rotation rolls 4-of-10 per run).

### Per-perk power override / always-on machines (no power switch)

zm_perks::register_perk_machine_power_override(PERK, &override_thread) replaces stock perk_machine_think. The community override calls zm_perk_utility::force_power(perk): waits level flag::wait_till("initial_blackscreen_passed"), then loops: machines = getEntArray(level._custom_perks[perk].radiant_machine_name, "targetname"), triggers = getEntArray(same, "target"); for each machine setModel(level.machine_assets[perk].on_model), vibrate((0,-100,0),.3,.4,3), playSound("zmb_perks_power_on"), thread zm_perks::perk_fx(light_effect), thread zm_perks::play_loop_on_machine(); level notify(perk+"_power_on"); array::thread_all(triggers, &zm_perks::set_power_on, 1); optional level.machine_assets[perk].power_on_callback/power_off_callback hooks; waits level waittill(perk+"_off") / (perk+"_on") to toggle; endon = perk+PERK_END_POWER_THREAD ("_power_thread_end", stock gsh L38).

- **Source:** ColDog5044/zm_countryside scripts/zm/_zm_perk_utility.gsc L585-652; zeroy99/bo3_modtools scripts/zm/_zm_perks.gsh L38
- **For our map:** force_power runs perk machines from blackscreen before the power quest is satisfied; the stock <perk>_on/_off notifies take over once a power switch is thrown (our 10-perk roster).

### PHD damage immunity via stock level.perk_damage_override array (lightweight hook)

Stock _zm.gsc player-damage flow (L5231-5233) iterates `foreach(func in level.perk_damage_override)` calling self [[func]](eInflictor, eAttacker, iDamage, iDFlags, sMeansOfDeath, weapon, vPoint, vDir, sHitLoc, psOffsetTime); a defined return value replaces iDamage. HarryBo21 PHD pushes its handler: array::push(level.perk_damage_override, &phdflopper_damage_override, 0) in __main__ (utility initializes the array); handler returns 0 if self hasPerk(specialty_phdflopper) and sMeansOfDeath is MOD_FALLING/MOD_GRENADE/MOD_GRENADE_SPLASH/MOD_PROJECTILE/MOD_PROJECTILE_SPLASH/MOD_EXPLOSIVE/MOD_EXPLOSIVE_SPLASH, else returns n_damage. Contrast: Velaseriat's older kit instead sets level.overridePlayerDamage = &zm_overrides::player_damage_override (a full 500-line copy of stock damage logic with hasperk checks spliced in at MOD_FALLING and the explosive-cap branch) — works but fragile; the array hook is strictly better.

- **Source:** zeroy99/bo3_modtools scripts/zm/_zm.gsc L5231-5233; ColDog5044/zm_countryside scripts/zm/_zm_perk_phdflopper.gsc L152-166 + L280-302; Velaseriat/zombies_PHD Scripts/zm_mapname.gsc L78, Scripts/zm_overrides.gsc L38-217
- **For our map:** Use level.perk_damage_override for any Cyberware/Overclock damage-reduction node and for PhD Flopper self-damage immunity — no monolithic damage-function replacement needed.

### Complete single-perk install recipe incl. zone + sound (MikeyRay PHD)

Exact zone-file additions for one custom perk (must be BELOW the // BSP comment... actually thread says NOT above it): scriptparsetree,scripts/zm/perks/_zm_perk_phdflopper.gsc + .csc + .gsh (note: gsh listed too, and note the subfolder scripts/zm/perks/ — more proof subfolders link); xmodel,p7_zm_vending_phd; xmodel,p7_zm_vending_phd_active; xmodel,wpn_t7_zmb_perk_bottle_phd_view; xmodel,wpn_t7_zmb_perk_bottle_phd_world; weapon,zombie_perk_bottle_phd; fx,_mikeyray/perks/phd/fx_perk_phd; image,specialty_phdflopper_zombies. Sound: add ALIAS block {"Type":"ALIAS","Name":"ray_phdflopper","Filename":"ray_phdflopper.csv","Specs":[]} to the map .szc after user_aliases (zm_countryside.szc similarly carries "perk_sounds"/"perk_can_alias" ALIAS entries); alias csv lives in BO3root/raw/sound/aliases/. Entry scripts: #using scripts\zm\perks\_zm_perk_phdflopper; in BOTH zm_mapname.gsc and .csc under #using scripts\zm\zm_usermap. Map side: place vending_phd_struct.map prefab.

- **Source:** dtzxporter/ModmeForum wiki/threads/3537.md L8-36; ColDog5044/zm_countryside sound/zoneconfig/zm_countryside.szc L17-41
- **For our map:** This is the full checklist our docs/10_perks.md needs for finishing PhD Flopper with a real machine model: model x2 + bottle view/world models + weapon file + fx + shader image + szc alias block.

### Perk pause/unpause framework (Tombstone/Who's Who state machine)

zm_perk_utility keeps level + per-player pause registries: global_pause_perk(perk, retain=1)/global_unpause_perk, player_pause_perk/player_unpause_perk, is_perk_paused(perk) callable on level or player; _hasPerk(str_perk, b_count_paused=1) wrapper counts paused perks; perk_lost_callback(str_perk). give funcs start with: if (level is_perk_paused) self player_pause_perk; if (self is_perk_paused) return; — so re-buying while paused just unpauses. HUD shows paused via clientuimodel state 2. Loadout save/restore for revive-style perks: get_player_loadout(a_exclude_perks=[]) / give_player_loadout(s_loadout, b_remove_player_weapons=1, ...) (L818-973) snapshots weapons+perks. Tombstone uses it: on laststand spawns suicide unitrigger (hold 1.5s, kills with weapon "t6_bare_hands_death"), drops model p9_sur_machine_tombstone_grave with fx harry/tombstone/fx_tombstone_grave_glow, 50s timeout with wobble+beeps, grab restores loadout; solo variant toggle TOMBSTONE_USE_SOLO_VERSION.

- **Source:** ColDog5044/zm_countryside scripts/zm/_zm_perk_utility.gsc L391-507, L818-973; scripts/zm/_zm_perk_tombstone.gsh + .gsc L127-310
- **For our map:** Our Overclocks ('temporarily disable a perk for a buff') and Mega upgrades can reuse pause semantics + state-2 HUD instead of inventing a parallel system; loadout snapshot is ready-made for any death-recovery mechanic.

### Per-perk runtime disable + purchase validation (UGX gamemode gating)

All vending use-triggers share targetname "zombie_vending" with script_noteworthy = specialty. Disable all: foreach trig in GetEntArray("zombie_vending","targetname") trig TriggerEnable(false). Per-perk: stock checks level.custom_perk_validation — set level.custom_perk_validation = &func where func(player) runs with self = the vending trigger and returns bool (UGX returns false when level.ugxm_settings[self.script_noteworthy] is false, L244-250); blank the buy prompt by setting level._custom_perks[specialty].hint_string = undefined then trig SetHintString("Perk is disabled...") (L183-196). Related stock-respected fields seen: level.perk_purchase_limit (countryside sets 15 at zm_countryside.gsc L285, read via zm_utility::get_player_perk_purchase_limit), level.func_override_wallbuy_prompt for wallbuys, gobblegum kill via unregistering bgb_machine_use unitrigger_stubs.

- **Source:** treminaor/ugx-mod-bo3 ugxmod/scripts/zm/ugxm/ugxm_init.gsc L160-250; ColDog5044/zm_countryside scripts/zm/zm_countryside.gsc L285
- **For our map:** Per-run perk roster randomization: roll the run's available perks, then TriggerEnable(false)+hint swap the rest; custom_perk_validation gates purchases on Data Shards/Cyberware prerequisites.

### Vulture Aid kit: zombie drops + entity waypoints

Drops: hooks zm_spawner::add_custom_zombie_spawn_logic(&vulture_aid_zombie_function) so every spawned zombie rolls VULTUREAID_DROP_CHANCE 60% (cap VULTUREAID_MAX_DROPS 15 concurrent); on death spawns ammo (p6_zm_perk_vulture_ammo, gives clip fraction 1/10 of max) or points (p6_zm_perk_vulture_points, 10-20 points) models with glow fx harry/vulture_aid/fx_perk_vulture_drops_glow, 10s timeout, collected by proximity watcher threads per owner. Stink: 20% of zombies (max 3) get green mist; player inside gets ignored (increment_ignoreall/decrement_ignoreall refcount) + visionset "zm_vulture_aid_stink" via visionset_mgr. Waypoints through walls: clientfields on OTHER entities — "scriptmover" vulture_aid_register_perk/keyline_waypoints/register_powerup(2bit)/register_stink, "zbarrier" register_mystery_box/wonderfizz/pap/gobble_gum (all registered in vulture_aid_register_clientfield L113-129); each perk machine self-registers by threading zm_perk_utility::register_vulture_perk_safe() from its machine_setup (waits blackscreen, sets clientfield "vulture_aid_register_perk" 1 on the machine entity); CSC+Lua (hb21waypoints.lua) render waypoint widgets per registered entity; per-perk waypoint FX defines like VULTUREAID_VULTUREAID_WAYPOINT "harry/vulture_aid/fx_vulture_aid_waypoint_vulture_aid".

- **Source:** ColDog5044/zm_countryside scripts/zm/_zm_perk_vulture_aid.gsh (84 lines), .gsc L113-129, L141-154, L395-585; _zm_perk_utility.gsc L741-758, L975-978; ui/uieditor/widgets/HUD/ZM_Perks/hb21waypoints.lua
- **For our map:** The drop/glow/timeout pattern is a ready template for Data Shards physical pickups; the entity-clientfield waypoint trick gives us through-wall markers for Cyberware terminals and boss objectives.

### Custom original perk from template: Time Warp (teleport + slide buff)

Shows the find/replace custom-perk template fully instantiated: gsh defines TIMEWARP_PERK "specialty_fireproof", TIMEWARP_CLIENTFIELD "hudItems.perks.timewarp" (custom key needing Lua table entry), machine vending_timewarp, bottle "zombie_perk_bottle_timewarp", reuses Harry's tombstone light fx. Give thread: SetPerk("specialty_sprintfire") as a free secondary engine buff, hold-use interactions read raw input (self UseButtonPressed() loop with 2s hud::createPrimaryProgressBar()/updateBar/destroyElem progress bar), prone+hold = SaveLocation (self.saved_position/.saved_angles + PlayFX fx_elec_teleport_flash_sm), stand+hold = SetOrigin/SetPlayerAngles teleport with 90s cooldown (self.timewarp_inactive flag) and StunNearZombies; slide detection via self IsOnSlide()/IsSliding() with velocity boost SetVelocity(GetVelocity()*1.1), 25% chance ragdoll-launch kill: DoDamage(health+666) + StartRagdoll() + LaunchRagdoll((rand20-50,rand20-50,rand80-150)) + zm_score::add_to_player_score(60*level.zombie_vars[team]["zombie_point_scalar"]); teleport legality checks: targetname "timewarp_excluded" trigger_multiples, touching trigger_use/trigger_radius/trigger_use_touch classnames, proximity<100 to struct targetname "exterior_goal" (barriers), self.useBar defined (crafting).

- **Source:** Polystyreeni/BO3 scripts/zm/_zm_perk_timewarp.gsh L1-23, .gsc L104-160, L196-313, L331-498, L607-692
- **For our map:** Best end-to-end reference for inventing original perks: shows engine-specialty piggybacking, hold-to-use progress bars, cooldown flags, and teleport-safety checks reusable for any movement Cyberware.

### Wonderfizz integration: HB21 queue + zbarrier machine + CW Lua-menu variant

(a) HB21 queue: each perk gsh has <PERK>_IN_WONDERFIZZ 1; __main__ calls zm_perk_utility::add_perk_to_wunderfizz(PERK); pause_to_wunderfizz/unpause_to_wunderfizz move perks between machine rotation and disabled; give_random_perk() grants a random unowned registered perk. (b) _zm_perk_random (Origins-style): machines are zbarrier entities targetname "perk_random_machine"; unitrigger stubs via zm_unitrigger::register_static_unitrigger(stub, &perk_random_unitrigger_think); zbarrier clientfields set_client_light_state(2bit)/init_perk_random_machine; bottle cycle anim pieces by index (gsh defines piece indices 0-5); cost 1500. (c) _t9_wonderfizz (Cold War style): `function autoexec init()` (no REGISTER_SYSTEM — autoexec is the other valid bootstrap), map-side script_struct targetname "t9_wonderfizz" with target → machine model ent; RegisterBuyable(speciality) builds the offer list; purchase via Lua menu (WonderfizzMenuBase.lua) + WatchForMenuResponse()/perkPurchased(responseData) round-trip; light fx "madgaz/wunderfizz_2/fx_perk_madgaz_wunderfizz_light" (a surviving Madgaz asset path).

- **Source:** ColDog5044/zm_countryside scripts/zm/_zm_perk_utility.gsc L315-389, L509-545; scripts/zm/_zm_perk_random.gsc L44-167, .gsh; scripts/zm/_t9_wonderfizz.gsc L37-234
- **For our map:** The t9 pattern (struct + unitrigger + Lua menu with server response) is exactly the architecture for our Cyberware tree terminal and Mega-perk-upgrade vendor; autoexec init() is a lighter bootstrap for modules that don't need system ordering.

### Perk sellback / refund station (All0utWar via Wardog naming)

_war_perk_return.gsc: REGISTER_SYSTEM_EX("war_perk_return", &__init__, undefined, undefined); __init__ uses callback::on_spawned(&player_setup); spawns unitriggers near each owned-perk machine via create_unitrigger(str_hint, n_radius=32, func_prompt_and_visibility, str_perk, func_unitrigger_logic, "unitrigger_radius_use"); on use, refunds return_amount = level._custom_perks[str_perk].cost * INT_RETURN_PERCENT (gsh: B_RETURN_GIVE_POINTS 1, INT_RETURN_PERCENT 0.5) and war_remove_perk(perk) takes the perk properly (UnsetPerk + clientfield + threads). Zone lines: scriptparsetree for .gsc AND .gsh.

- **Source:** ColDog5044/zm_countryside scripts/zm/_war_perk_return.gsc L25-149, .gsh L1-5; zone_source/zm_countryside.zone L55-56
- **For our map:** Direct model for Data-Shards respec: sell back perks/Cyberware at a fraction; also demonstrates the canonical 'take perk cleanly' call path through level._custom_perks.

### Bottle-weapon and machine-model asset conventions

Bottle weapon files follow zombie_perk_bottle_<name> (classic) or zombie_perk_can_<name> (Cold War cans: zone lines weapon,zombie_perk_can_quick_revive ... zombie_perk_can_phd_slider, countryside zone L20-30); the bottle weapon is passed to register_perk_basic_info via GetWeapon() and stored at level._custom_perks[perk].perk_bottle_weapon (stock _zm_perks.gsc L1002-1027 swaps it in during the drink animation). Machine models used by kits when the real DLC model isn't extractable: reuse any vending model and re-skin (Snail's Pace = retextured speed cola; Velaseriat PHD = BO2 nuke-town vending p6_zm_al_vending_nuke_off/_on; MikeyRay extracted real p7_zm_vending_phd via Wraith/Greyhound; HB21 CW set = p9_sur_machine_<perk>(_off)). off_model/on_model swap is the entire powered visual (SetModel in force_power/perk_machine_think).

- **Source:** ColDog5044/zm_countryside zone_source/zm_countryside.zone L20-30; zeroy99/bo3_modtools scripts/zm/_zm_perks.gsc L1002-1027; Velaseriat/zombies_PHD Scripts/_zm_perk_phdflopper.gsh L7-8; dtzxporter/ModmeForum wiki/threads/3537.md L12-16
- **For our map:** PhD Flopper's placeholder model: legitimate shipped practice is reusing/re-skinning any stock vending xmodel and defining off/on pair — we can pick a cyber-looking stock machine (e.g. p7_zm_vending_*) now and swap later without touching script structure.

### Who's Who completion (HB21) — fake-death second-chance perk

whoswho_give registers level.custom_laststand_func-adjacent flow: on down, whoswho_fake_death() (notify fake_death, TakeAllWeapons, ignoreme, invulnerable), whoswho_spawn_corpse() leaves a revivable corpse clone, player respawns elsewhere via zm_perk_utility::get_player_spawn_point(n_min=800, n_max=1200, half_height 200,...) (PositionQuery-based), gets pistol loadout, distortion visionset loop while active; reviving own corpse → whoswho_fake_revive restores saved loadout (whoswho_save_loadout/whoswho_give_loadout), corpse cleanup threads handle bleedout timeout, multiple instances, spectator; health reset via zm_perks::perk_set_max_health_if_jugg("health_reboot", 1, 0) — note that stock helper also used by juggernaut module. Lua: whoswhorevivewidget.lua + whoswhowaypoint(.container).lua render the 'revive yourself' marker.

- **Source:** ColDog5044/zm_countryside scripts/zm/_zm_perk_whoswho.gsc L134-535; _zm_perk_utility.gsc L795-816; ui/uieditor/widgets/HUD/ZM_Perks/whoswho/*.lua
- **For our map:** get_player_spawn_point + save/restore loadout + corpse waypoint are the building blocks if our map adds any death-cheat mechanic (e.g. a Cyberware 'backup consciousness' Overclock).

## MISC

### 4-state Radiant lighting states driven by util::set_lighting_state(n)

Worldspawn declares "state_alias_1".."state_alias_4". Every light/script_model/brushmodel carries KVPs lightingstate1..lightingstate4 ("1" = lit in that state; "0" omits — e.g. a spot light with lightingstate2 "0" and lightingstate4 "0" only exists in states 1+3). Script: level util::set_lighting_state(n) with n = 0-3 (0-indexed -> Radiant state n+1). Usage map: state 0 = powered/normal, 1 = dark (intro ship + power outage, set at level start), 2 = power restored, 3 = red-alert alarms (set/cleared around the docking-clamp sequence with notifies). Paired with util::clientnotify("ayz_power_on"/"ayz_power_off") for client FX.

- **Source:** MattFiler/zm_alien_isolation map_source/zm/zm_alien_isolation.map L10-29 (worldspawn), L14247-14263 (state-excluded light); scripts/zm/bsp_torrens.gsc L22, L307; hab_airport.gsc L75-77, L392-393; eng_towplatform.gsc L82, L94
- **For our map:** Exactly what our power-on reveal and Overclock 'blackout' events need: author lights in 4 states in Radiant, flip with one call — no light entity scripting.

### Custom color grading: LUT material + map .vision rawfile

Three pieces: worldspawn KVP "lutmaterial" "luts_ayz" (custom LUT material, alongside the stock one); zone lines `material,luts_t7_default` + `material,luts_ayz`; and share/raw/vision/<mapname>.vision rawfile (key-value text: vkTT "6500" white balance, vkRGB0..4 + vkL0..4 + vkM0..4 HDR curve keys, vkRM) included via zone `rawfile,vision/zm_alien_isolation.vision` — engine applies the map-named vision automatically.

- **Source:** MattFiler/zm_alien_isolation map_source/zm/zm_alien_isolation.map L12-13; zone_source/zm_alien_isolation.zone L6-7, L27; share/raw/vision/zm_alien_isolation.vision L1-19
- **For our map:** One-file route to a neon/teal cyberpunk grade for our map: ship luts_acc material + zm_abandoned_cyber_city.vision.

### Ambient prop animation kit (no xanims needed) + AnimScripted NPCs when needed

Continuous rotators: ent Rotate((0,250,0)) / Rotate((180,0,0)) — fans, warning lights (never stops, one call). Nodders: loop RotatePitch(-90,2,1,1)/RotatePitch(90,2,1,1). Bobbers: loop MoveTo(origin+(0,0,1.5),0.5,0.2,0.2) and back. All driven by GetEntArray(targetname) so one thread animates every instance. Real NPC idles: #precache("xanim","<anim>"); #using_animtree("alien_isolation_zombies"); ent useanimtree(#animtree); ent AnimScripted("notify_name", ent.origin, ent.angles, %anim_name); requires zone lines `rawfile,animtrees/<name>.atr` + `xanim,<anim>`.

- **Source:** MattFiler/zm_alien_isolation usermaps/zm_alien_isolation/scripts/zm/zm_alien_isolation.gsc L328-429; bsp_torrens.gsc L15-17, L640-647; zone_source/zm_alien_isolation.zone L42-44
- **For our map:** Free life for our cyber city: rotating holo-signs, hovering drones, nodding vendors — zero custom assets; AnimScripted path covers story NPCs later.

### #insert of the core .gsc into sibling area scripts (shared macros across one namespace)

Each area script starts with `#insert scripts\zm\zm_alien_isolation.gsc;` then `#namespace alien_isolation_zombies;` while the core file `#using`s those same area scripts — i.e., every module compiles with the core's #defines (PLAYTYPE_*, cutscene ids) and helper functions textually included, all under ONE shared namespace, and the linker tolerates the resulting duplicate definitions across scriptparsetrees. Shipped and works, but fragile.

- **Source:** MattFiler/zm_alien_isolation usermaps/zm_alien_isolation/scripts/zm/bsp_torrens.gsc L9-12; eng_towplatform.gsc L10-13; hab_airport.gsc L10-13; zm_alien_isolation.gsc L73-78
- **For our map:** Do NOT copy wholesale — our #using + per-module namespace layout is cleaner — but it licenses putting shared #defines in a .gsh and proves multi-file single-namespace linking is legal if we ever need it.

### World clientfields for fog/skybox/exposure/eye-color banks

Server registers bare: clientfield::register("world","change_fog",VERSION_SHIP,4,"int") and sets via level clientfield::set(name,val). Client registers SAME name+size with handler: clientfield::register("world","change_fog",VERSION_SHIP,4,"int",&change_fog,!CF_HOST_ONLY,!CF_CALLBACK_ZERO_ON_NEW_ENT). Handlers map values to SetLitFogBank(localClientNum,-1,bank,-1)+SetWorldFogActiveBank(localClientNum,mask 1/2/4/8); exposure via SetExposureActiveBank(localClientNum,bank); eye color via level._override_eye_fx="frost_iceforge/blue_zombie_eyes"; level.zombie_eyeball_color_override=2. Also lighting states: level util::set_lighting_state(0|1|2).

- **Source:** zm_nuked scripts/zm/zm_nuked.gsc:118-122; scripts/zm/zm_nuked.csc:53-135; scripts/zm/zm_nuketown_hd_amb.csc:21-242
- **For our map:** Exactly the mechanism for our Overclock visual modifiers (per-run fog/lighting/eye-color mutations); our `.csc` client modules (e.g. `_acc_lui.csc`, `_acc_perk_lights.csc`) already exist to host handlers like this.

### GSC utilities worth stealing (nuked_utility)

wait_for_round_range(n): while(level.round_number < n) wait 0.05. wait_for_round_range_random(a,b): target=RandomIntRange(a,b) then 1s polls. playsound_to_players(alias): foreach player PlayLocalSound. Mass respawn: level waittill("can_respawn_players") → each player zm::spectator_respawn_player(). is_omega(): GetDvarString("mapname") compare — one BSP shipped as two Workshop maps with divergent script behavior. Variant cleanup: ents tagged script_noteworthy 'bo1_weapon'/'bo4_weapon'/etc deleted at init = data-driven loadout variants in one .map. Traversal gating: UnlinkTraversal/LinkTraversal on GetNodeArray("node_dog","targetname").

- **Source:** zm_nuked scripts/zm/nuked_utility.gsc:29-227; scripts/zm/zm_nuked.gsc:402-441
- **For our map:** wait_for_round helpers and noteworthy-tagged variant ents slot straight into our per-run randomization; traversal link/unlink is how we close zombie shortcuts per Overclock.

### Localized subtitle/VO registration pattern

Strings live in localize asset 'nuked_string' (zone: 'localize,nuked_string'); GSC does #precache("string","NUKED_STRING_X") and passes &"NUKED_STRING_X" references. Central zm_sub::register_subtitle_func(textLine, duration, origin, sound, duration_begin, to_player): plays PlaySoundAtPosition(sound,origin) or PlayLocalSound per player when to_player true — subtitle rendering deliberately stubbed out 'for mod compatibility' (no LUI shipped at all in this repo).

- **Source:** zm_nuked scripts/zm_exp/zm_subtitle.gsc:23-89; zpkg:26-27; scripts/zm/classic_features/vox_transmission.gsc:109-151
- **For our map:** Our quest/boss VO needs exactly this: localize asset + precache(string) + a single dispatch function we can later upgrade to real subtitles.

### Sphynx dvar-polling console command framework (~30 commands)

Each command = one infinite GSC thread: ModVar("points","") (engine builtin registering a console-writable dvar), then for(;;){WAIT_SERVER_FRAME; v=ToLower(GetDvarString("points","")); if(v!=""){ModVar("points",""); tok=StrTok(v," "); ...act...}}. Usage in console: 'points 0 5000'. Threads launched from REGISTER_SYSTEM("zm_commandsgui",&__init__,undefined); gated by #define DEV_ONLY_COMMANDS + DEV_ONLY_USERNAME_ARRAY/DEV_ONLY_XUID_ARRAY (checked vs GetPlayers()[0].name / GetXUID()); calls SetDvar("sv_cheats",1) at init. Command set: points, zombie/dog spawn, powerup at crosshair, upgrade/downgrade weapon, round set/next/prev, give/take perk (with a name_checker module mapping aliases like 'jugg'->specialty_armorvest), revive, ignoreme, power on/off, infinite ammo, camo, open all doors (flag-based), godmode (EnableInvulnerability), spawning on/off (flag::set/clear("spawn_zombies") + Kill all with level.zombie_total++/zombie_respawns++), notify/flag/alias debug, get_coords, teleport zombies (ForceTeleport), give bgb (bgb::give), aimbot.

- **Source:** ohm-nabar/zm_building scripts/Sphynx/commands/_zm_commands.gsc:69-154,200-241,604-700; scripts/Sphynx/commands/_zm_name_checker.gsc:1-30
- **For our map:** Adopt wholesale as our debug tooling for first Windows compiles — give-shards/set-round/give-perk/godmode commands cost one thread each and need zero UI; ModVar+GetDvarString polling is the entire trick.

### Clientfield + duplicaterender entity-outline debugging (X-ray keylines)

GSC: clientfield::register("scriptmover","debug_enable_keyline",VERSION_SHIP,1,"int") and ("actor","debug_zombie_enable_keyline",...); set per-entity via ent clientfield::set(name,1). CSC: register same fields with callbacks, then duplicate_render::set_dr_filter_framebuffer_duplicate("debug_enable_keyline",10,"debug_enable_keyline_active",undefined,DR_TYPE_FRAMEBUFFER_DUPLICATE,"mc/hud_outline_model_green",DR_CULL_NEVER) for movers, and set_dr_filter_offscreen(...,DR_TYPE_OFFSCREEN,"mc/hud_outline_model_z_red",DR_CULL_NEVER) for through-wall zombie outlines; callback bodies do self duplicate_render::set_dr_flag("<filter>_active",n_new_val) + update_dr_filters(localClientNum). Zone needs material,mc/hud_outline_model_z_red + material,mc/hud_outline_model_green. Console: 'outline struct <targetname> 1' / 'show_zombies 1'.

- **Source:** ohm-nabar/zm_building scripts/Sphynx/commands/_zm_commands.csc:19-33,74-100; _zm_commands.gsc:86-92,897-1003; zone_source/zm_building.zone:610-611
- **For our map:** Ideal for greybox QA on our 7 zones: outline all wallbuy structs/perk machines/spawners through walls when verifying placements in-game.
- **ADOPTED (2026-07-17):** the same clientfield→duplicate-render pattern now ships as the
  interactable-station holo shimmer (`_acc_interact_glow.gsc/.csc`, docs/11) — FRAMEBUFFER_DUPLICATE
  overlay of the AW box's `mc/dr_fx_holo` on 13 station meshes instead of the offscreen keyline
  (through-wall X-ray was too gamey for normal play; the shimmer is depth-drawn on the mesh like
  the box's reveal flash). Stock outline materials for a future debug pass: `mc/hud_outline_model_{red,green,orange,white}`
  + `_z_` through-wall variants (grep antipersonnelguidance.csc / _gadget_vision_pulse.gsh).

### Trials system (4 judges) granting tiered gobblegum rewards

REGISTER_SYSTEM init builds level.gg_tier1/2/3 arrays of reward ids; per-judge goal arrays level.gargoyle_goals (5 escalating goals each); progress published via toplayer float clientfields (trials.aramis etc.) and randomized challenge selection via trials.<judge>Random int clientfields. Trial implementations are function-pointer arrays: level.athos_trials=array(array(&wallbuy_trial,&area_assault_trial,&crouch_trial,&elevation_trial),...) keyed by game stage. wallbuy_trial enumerates all wallbuys via struct::get_array("weapon_upgrade","targetname") (proving wallbuys are addressable structs at runtime); area_assault uses struct::get_array("area_assault_waypoint","targetname") + compass/material waypoints (material,buy_waypoint/defend_waypoint in zone). Reward dispensers are map ents: gargoyle_judge triggers + gumballN model ents + abbey_bribe pay-to-reroll triggers, with rarity-colored hints precached as #precache("triggerstring","ZM_ABBEY_TRIAL_HINTSTRING_PURPLE","ZMUI_BGB_PERKAHOLIC").

- **Source:** ohm-nabar/zm_building scripts/zm/zm_challenges.gsc:67-164,691; scripts/zm/custom_gg_machine.gsc:69-100,248-266
- **For our map:** Blueprint for our Data Shard bounty/challenge system: function-pointer trial arrays + toplayer progress clientfields + runtime wallbuy struct enumeration (useful for 'buy N wallbuys' style Overclock conditions).

### Co-op pause via SetPauseWorld + inert zombies

Vote loop: when all-want-pause, do (in order) flag::clear("spawn_zombies"); foreach player SetMoveSpeedScale(0), AllowJump(false), DisableWeapons(), .pause_invulnerable=true (honored by a zm::register_player_damage_callback returning 0); foreach zombie in GetAITeamArray("axis") set .is_inert=true; then SetPauseWorld(1) (engine builtin; IsWorldPaused() to query). Unpause reverses. Round-spawn failsafe thread suspends its timeout counting while paused. HUD via clientuimodel "abbeyPause".

- **Source:** ohm-nabar/zm_building scripts/zm/zm_pause.gsc:25-52,221-320
- **For our map:** SetPauseWorld/IsWorldPaused + .is_inert + spawn_zombies flag is the complete safe-pause kit — also reusable piecewise to freeze the world during our boss intro or Cyberware menu.

### Solo lives system: every laststand override hook in one file

Hooks used together: level.override_use_solo_revive=&f (return false kills stock solo quick-revive auto-self-revive); level.playerlaststand_func=&f (custom laststand entry, signature (eInflictor,attacker,iDamage,sMeansOfDeath,weapon,vDir,sHitLoc,psOffsetTime,deathAnimDuration)); level.overridePlayerDamage=&f; level.player_out_of_playable_area_monitor_callback=&f (return true; used to refund a life when the kill-brush takes one — restores by polling self zm::in_kill_brush()/in_enabled_playable_area()/in_life_brush()); zm::register_player_damage_callback returning 0 while self.solo_revive_invulnerable. Lives count lives on the HOST player object (self IsHost()), displayed via clientuimodel "soloLivesUpdate" (2-bit) only while level flag "solo_game" is set.

- **Source:** ohm-nabar/zm_building scripts/zm/zm_solo_revive.gsc:37-140
- **For our map:** Names the five laststand/death override level-fields we'd need for any custom down/revive economy (e.g., Cyberware 'second heart' implant) — none are in our current hook list.

### Jump pads with KVP-encoded physics params

Radiant wiring: trigger targetname trig_jump_pad, .target -> start struct (startptName), start struct .target -> one or more destination structs; per-pad tuning packed into the TRIGGER's script_string as comma list parsed by StrTok: "time:4,zOffset:800,zPeakProgress:85,cost:500,delay:0.5". Optional jump_pad_gate ents block pads until purchased. Launch path computed from start->dest with parabola peak at zPeakProgress%, moved via spawned script_origin the player links to. FX anchored on spawned script_model with xmodel tag_origin (zone: xmodel,tag_origin + fx,redspace/fx_launchpad_blue.efx).

- **Source:** ohm-nabar/zm_building scripts/zm/rs_o_jump_pad.gsc:20-130,190-230,327; zone_source/zm_building.zone:253-257
- **For our map:** The script_string 'key:value,key:value' KVP-encoding idiom is the headline: lets one generic GSC module serve many map ents with per-instance tuning (our zone gates, vents, launch routes) without new KVP fields.

### Score rounding bypass for fine-grained currency

Custom add_to_player_score writes the player score state directly, skipping zm_score's round-up-to-10: self.score += points; self.pers["score"]=self.score; self IncrementPlayerStat("scoreEarned",points); level notify("earned_points",self,points); self.score_total += points; level.score_total += points. Used by the 'spare change' easter egg (go prone on the perk bump trigger targetname audio_bump_trigger with script_sound zmb_perks_bump_bottle to collect 1/5/10/25-point coins). Also note starting points set via level.player_starting_points and applied inside a fully overridden player_stats_init (registered as level.player_stats_init=&f) which initPersStat()s ~80 stats.

- **Source:** ohm-nabar/zm_building scripts/zm/zm_building.gsc:152,159,260-352,506-662
- **For our map:** Our Data Shards currency needs sub-10 precision — this is the shipped-safe way to award non-multiple-of-10 points while keeping earned_points notify and stat tracking consistent (refines our 'never write player.score' rule: safe iff you replicate all five side-effects).

### Self-registering module architecture (REGISTER_SYSTEM) vs explicit orchestration

Most custom modules never get called from the entry script: each file ends its header with REGISTER_SYSTEM("name",&__init__,undefined) or REGISTER_SYSTEM_EX("name",&__init__,&__main__,undefined) (macros from shared.gsh wrapping function autoexec + system::register), so merely having the scriptparsetree zone line + a #using from any loaded file activates it; __init__ runs pre-load (register clientfields, callback::on_connect), __main__ at level start. Entry zm_building.gsc main() only: sets level._effect entries, calls zm_usermap::main(), assigns level callbacks (dog_round_track_override, register_actor_damage_callback, register_player_damage_callback, _zombie_custom_add_weapons, zone_manager_init_func, no_target_override), sets level vars, then thread-launches only the modules that expose plain main().

- **Source:** ohm-nabar/zm_building scripts/zm/zm_building.gsc:140-200; scripts/zm/zm_room_manager.gsc:23; scripts/zm/zm_solo_revive.gsc:35; scripts/Sphynx/commands/_zm_commands.gsc:79
- **For our map:** Alternative to our acc_main orchestration: REGISTER_SYSTEM gives correct init ordering (clientfield registration must precede load) for free — worth adopting at least for any module that registers clientfields, where thread-from-main is too late.

### Self-bootstrapping modules via function autoexec + REGISTER_SYSTEM (no entry-script edits)

Any GSC/CSC module in the parse tree self-initializes with `function autoexec __init__() {...}` — the VM runs all autoexec functions at load, no call site needed (ugxm_init.gsc:52). The stock macro `REGISTER_SYSTEM("name", &__init__, undefined)` / `REGISTER_SYSTEM_EX("name", &__init__, &__main__, "zm")` (shared.gsh:204-212 in stock) expands to `function autoexec __init__sytem__(){ system::register(name, init, main, reqs); }`; __init__ runs pre-load, __main__ post-load. UGX uses REGISTER_SYSTEM_EX in ugxm_wallweapon.gsc:35 to get a post-load __main__. As a mod it injects by REPLACING stock scripts loaded on every map: scripts/zm/_art.gsc (GSC side, adds one line `#using scripts\zm\ugxm\ugxm_init;` at _art.gsc:7) and scripts/zm/_filter.csc (CSC side, _filter.csc:6), both listed as scriptparsetree in the mod zone.

- **Source:** treminaor/ugx-mod-bo3 ugxmod/scripts/zm/_art.gsc:7,13; ugxmod/scripts/zm/ugxm/ugxm_init.gsc:52-59; ugxmod/scripts/zm/ugxm/ugxm_wallweapon.gsc:35; zone_source/zm_mod.zone:7-8
- **For our map:** Our _acc_* modules could use REGISTER_SYSTEM/autoexec to drop the manual orchestration in acc_main and guarantee init ordering via system::register dependencies; the stock-override trick is also the fallback if an entry-script hook ever fails.

### Gamemode architecture: central settings registry + per-mode prepare() + flag-gated spawn callbacks

One flat registry `level.ugxm_settings[key]=val` written via tiny setters (ugxm_util::game_setting/powerup_setting/boss_setting, ugxm_util.gsc:244-264). Each gamemode is one module with: (1) REGISTER_SYSTEM __init__ that registers `callback::on_spawned(&on_player_spawned_<mode>)`; the callback first does `level flag::wait_till("voting_complete")` then `if(level.ugxm_settings["gamemode"] != MODE) return;` so all modes coexist; (2) a prepare_<mode>() called after mode selection that flips feature toggles (allow_perks, allow_mbox, allow_pap, allow_wall_guns, allow_gobblegums, grenades_disallowed, dont_increase_zombie_health, plus per-powerup toggles) and threads the mode main. A single post_gamemode_selection() (ugxm_init.gsc:89-242) then ENFORCES every toggle generically against stock systems. Mode constants are `#define GUNGAME 1` etc. per file.

- **Source:** treminaor/ugx-mod-bo3 ugxmod/scripts/zm/ugxm/ugxm_init.gsc:89-242; ugxm_gungame.gsc:36-42,130-220; ugxm_sharpshooter.gsc:39-94; ugxm_util.gsc:244-288
- **For our map:** Exactly the shape for our per-run randomization/Overclocks: one level.acc_run[] registry written by an overclock-roll module, enforced by one post-roll function — instead of scattering conditionals across modules.

### Round-system overrides: seamless rounds, continuous spawn, spawn-rate control

(1) `level.round_wait_func = &custom` MUST be set before zm::round_start runs (stock dispatch _zm.gsc:4446); UGX's override loops `wait 1` until `level.zombie_total <= 0 && !level.intermission` or flag "end_round_wait" (ugxm_timedgp.gsc:20-41). (2) Seamless transitions: `level.zombie_vars["zombie_between_round_time"]=0`, `level.zombie_round_start_delay=0`, `level.noRoundNumber=true` (suppresses round chalk/sounds, stock _zm.gsc:4195), `level.next_dog_round=9999` to kill dog rounds post-init. (3) Spawn pacing: `level.func_get_zombie_spawn_delay = &f(round_number)` and `level.func_get_delay_between_rounds = &f` (stock _zm.gsc:4502,4260) — return 0.1 for chaos-density spawning. (4) `level.custom_game_over_hud_elem = &f(player, game_over_hud, survived_hud)` lets you restyle the stock game-over HUD (stock _zm.gsc:6064-6066).

- **Source:** treminaor/ugx-mod-bo3 ugxmod/scripts/zm/ugxm/ugxm_init.gsc:224-241,77; ugxm_timedgp.gsc:20-41; ugxm_chaosmode.gsc:89-90,178-181; verified stock _zm.gsc:4195,4260,4344,4446,4502,6064
- **For our map:** Our boss rounds and Overclock round-modifiers (e.g. 'no round breaks' run) get four verified knobs; custom_game_over_hud_elem is how we show Data-Shard run stats on death.

### Per-round zombie stat forcing loops (health freeze, speed force)

Stock re-derives zombie vars each round, so overrides must be re-applied: a loop watches `level.round_number > last_change` then re-zeros `level.zombie_vars["zombie_health_increase_multiplier"]` and `"zombie_health_increase"` (health freeze, ugxm_util.gsc:26-43). Speed: `level.zombie_move_speed = N` (round 1) AND `level.zombie_vars["zombie_move_speed_multiplier"]`/`"_easy"` (later rounds), `"zombie_new_runner_interval"]=1`; scale: 0-40 walk, 41-70 run, 71+ sprint. Also force-clears flag "world_is_paused" and force-sets "spawn_zombies" each frame to defeat special-round spawn stalls (ugxm_chaosmode.gsc:183-211).

- **Source:** treminaor/ugx-mod-bo3 ugxmod/scripts/zm/ugxm/ugxm_util.gsc:26-43; ugxm_chaosmode.gsc:94-96,183-211
- **For our map:** Template for Cyberware/Overclock effects that tune zombie speed/health per run — shows which zombie_vars actually stick and that they need per-round reassertion.

### Kill-quality event bus: death callback → level notify with damage forensics

Register once: `ARRAY_ADD(level.zombie_death_event_callbacks, &on_zombie_died)` (stock registry _zm_spawner.gsc:2449-2470 dispatches `self [[cb]](attacker)` on the dying zombie). The callback just re-broadcasts: `level notify("zombie_died", zombie, zombie.attacker)`. Consumers `level waittill("zombie_died", zombie, player)` and read forensics fields stock sets on the corpse: `zombie.damagelocation` ("head"/"helmet"), `zombie.damagemod` ("MOD_GRENADE","MOD_PROJECTILE","MOD_MELEE"), `zombie.damageweapon`, plus `distance(zombie.origin, player.origin)` for longshots — chaosmode awards Grenade+400/Headshot+300/Longshot+150(>=450u)/Stab+150. Nuke kills arrive via `player waittill("nuke_triggered")` then iterate `player.zombie_nuked.size`.

- **Source:** treminaor/ugx-mod-bo3 ugxmod/scripts/zm/ugxm/ugxm_init.gsc:81,745-749; ugxm_chaosmode.gsc:917-978,1083-1099; stock _zm_spawner.gsc:2344,2449-2470
- **For our map:** Exactly how Data Shards should award by kill quality (headshot/melee/longshot multipliers) — one registered callback, one event bus, consumers stay decoupled.

### Currency hook: level.player_score_override

`level.player_score_override = &f` — stock _zm_score.gsc:297/406 calls `player_points = self [[level.player_score_override]](damage_weapon, player_points)` (self = player) on every point award; return the modified amount. UGX doubles points while `self.ugxm_powerup_times["multiplier"]` is active. Point scalar also available: `level.zombie_vars[team]["zombie_point_scalar"]`.

- **Source:** treminaor/ugx-mod-bo3 ugxmod/scripts/zm/ugxm/ugxm_powerups.gsc:78,253-260; stock _zm_score.gsc:297-299,406-408
- **For our map:** The clean interception point for Cyberware point-modifier nodes and Overclocks that scale economy — composes with our existing zm_score:: usage rule.

### Script-built unitrigger from SpawnStruct (no map-placed trigger needed)

u=SpawnStruct(); u.origin/u.angles from a map script_struct; u.script_unitrigger_type="unitrigger_box_use" (box, uses script_width/script_height/script_length) or "unitrigger_radius_use" (uses .radius); u.cursor_hint="HINT_NOICON"; u.hint_string=str; u.require_look_at=1; u.related_parent=<model ent>; u.inactive_reassess_time=1 (0.05 for fast prompt refresh); then zm_unitrigger::unitrigger_force_per_player_triggers(u,true); u.prompt_and_visibility_func=&fn (fn(player) runs with self=trigger stub, calls self SetHintString(...), returns bool usable — per-player prompts!); zm_unitrigger::register_static_unitrigger(u,&zm_unitrigger::unitrigger_logic). Consumers then `<struct> waittill("trigger_activated", player)`. Alt higher-level call: `perk zm_unitrigger::create_unitrigger(hint, 48, &visibility_func)` then perk.s_unitrigger.inactive_reassess_time=0.05. Per-player hide trick: self SetInvisibleToPlayer(player,true/false) on the trigger and on self.stub.related_parent to swap which of two stacked prompts a player sees.

- **Source:** ColDog5044/zm_countryside scripts/zm/zm_cwpap.gsc:385-400; scripts/zm/_war_perk_return.gsc:149-170,89-118; scripts/zm/_t9_wonderfizz.gsc:124-125
- **For our map:** Lets us spawn all Data Shard terminals, Cyberware stations and Overclock consoles purely from script structs (works with our inline-struct map authoring style; no trigger brushes in Radiant).

### Sphynx util API surface (QoL pack: hitmarkers, BO4 ammo/carpenter, caps, typewriter intro)

Source lives in share/raw/scripts/sphynx/_zm_sphynx_util.gsc (not in repo; only call sites + .gdb available). Verified call signatures: zm_sphynx_util::enable_bo4_zombie_hitmarkers(); black_ops_4_ammo() (max ammo fills clips); black_ops_4_carpenter(); zombie_health_cap(55) (round-cap zombie HP); zombie_limit_increase(24,8) (per-player zombie count cap); level thread zm_sphynx_util::intro_screen_text("TITLE","SUBTITLE/PLACE","DATE") — three-line typewriter intro after blackscreen. All called from map main() after zm_usermap::main().

- **Source:** ColDog5044/zm_countryside scripts/zm/zm_countryside.gsc:298-312; zone_source/zm_countryside.zone:10-11 (include,spx_util_script); zone_source/all/scriptgdb/scripts/sphynx/_zm_sphynx_util.gsc.gdb
- **For our map:** The intro_screen_text 3-line typewriter is the standard look for our map intro ("ABANDONED CYBER CITY / SECTOR 7 / 2087") — we'd reimplement in _acc_ since source is not public in this repo.

### gamedata/tables/common/objectives.json as usermap structuredtable

Countryside ships gamedata/tables/common/objectives.json (HydraX-exported stock table; array of {id, minimap_icon, objective_desc, waypoint_text, 3d_prompt_image/text/z_offset}) and the linker consumes it as `structuredtable,gamedata/tables/common/objectives.json` (visible in .deps) — required when any script touches the BO3 objectives/waypoint system in a usermap.

- **Source:** ColDog5044/zm_countryside gamedata/tables/common/objectives.json:1-30; zone_source/all/assetinfo/zm_countryside.deps (structuredtable entry)
- **For our map:** If our boss fight or Data Shard events use objective waypoints (zm_utility/objectives API), we must ship this table + zone line or the link fails — pre-empt that first-compile trap.

## HUD

### Minimal LUI menu (blackscreen overlay) — full asset chain

Lua file defines function LUI.createMenu.blackscreen(Instance): Hud = CoD.Menu.NewForUIEditor("blackscreen"); full-bleed CoD.TextWithBg.new element with Bg:setRGB(0,0,0)/setAlpha(1); LUI.OverrideFunction_CallOriginalSecond(Hud,"close",fn) to close children. Wiring (all four pieces required): (1) file at usermaps/<map>/ui/uieditor/menus/hud/blackscreen.lua, (2) zone line `rawfile,ui/uieditor/menus/hud/blackscreen.lua`, (3) CSC LuiLoad("ui.uieditor.menus.hud.blackscreen"), (4) GSC #precache("lui_menu","blackscreen") then menu = player OpenLUIMenu("blackscreen") / player CloseLUIMenu(menu).

- **Source:** MattFiler/zm_alien_isolation usermaps/zm_alien_isolation/ui/uieditor/menus/hud/blackscreen.lua L1-27; zone_source/zm_alien_isolation.zone L31; zm_alien_isolation.csc L51; zm_alien_isolation.gsc L139; bsp_torrens.gsc L131-135
- **For our map:** Foundation for our Data Shards counter / Cyberware tree UI panels: this is the smallest shippable LUI menu with the complete 4-file contract.

### GSC->Lua data channel: LUINotifyEvent + scriptNotify global model subscription

GSC: #precache("eventstring","AYZ_ObjectiveNotification"); player LUINotifyEvent(&"AYZ_AudiologVisible", 1, value) (eventstring istring, argc, args...). Lua: Hud:subscribeToGlobalModel(InstanceRef, "PerController", "scriptNotify", callback); inside callback: if IsParamModelEqualToString(ModelRef, "AYZ_AudiologVisible") then data = CoD.GetScriptNotifyData(ModelRef); use data[1]. Shipped map fell back to per-state OpenLUIMenu/CloseLUIMenu (audiolog menu opened for 40s window) because the live-update path was still flaky — both patterns are present and readable.

- **Source:** MattFiler/zm_alien_isolation usermaps/zm_alien_isolation/ui/uieditor/menus/hud/audiolog.lua L33-40; alien_objective_ui.lua L34-40; popup_zm_alien_isolation.lua L67-80; zm_alien_isolation.gsc L142-143, L278-291; hab_airport.gsc L369-373
- **For our map:** This is how our Shard count / Overclock timers update a custom HUD; the shipped fallback (open/close whole menus per state) is the low-risk first implementation.

### Custom TTF fonts in both classic HudElems and LUI

Drop .ttf at usermaps/<map>/fonts/<name>.ttf; zone lines `ttf,fonts/jixellation.ttf` (one per font). Classic GSC HUD: hud = NewHudElem(); hud.foreground=true; hud.fontScale=2; hud.alignX/horzAlign etc.; hud.font = "fonts/jixellation.ttf"; hud SetText(str); hud fadeOverTime(5); hud.alpha=0; hud Destroy(). LUI: element.Text:setTTF("fonts/jixellation.ttf"). The airlock 2-minute percent counter is a complete worked example of a timed progress readout.

- **Source:** MattFiler/zm_alien_isolation usermaps/zm_alien_isolation/zone_source/zm_alien_isolation.zone L34-36; scripts/zm/eng_towplatform.gsc L431-463; ui/uieditor/menus/hud/audiolog.lua L18
- **For our map:** Gives our cyberpunk map themed fonts for Shard counters and event timers without LUI complexity (NewHudElem path works server-side only).

### Localization pipeline: per-language .str + localize zone line + filename-prefixed istrings

File usermaps/<map>/<language>/localizedstrings/ayz.str for each of 12 language folder names (english, englisharabic, french, german, italian, japanese, polish, portuguese, russian, simplifiedchinese, spanish, traditionalchinese); format: VERSION "1" / CONFIG "...StringEd.cfg" / repeated [REFERENCE <KEY> / LANG_ENGLISH "text"] / ENDMARKER. Zone: `localize,ayz`. Runtime key = uppercase filename + '_' + REFERENCE (file ayz.str, REFERENCE OBJECTIVE_FIND_KEYCARD -> &"AYZ_OBJECTIVE_FIND_KEYCARD"). GSC must #precache("string","AYZ_...") for each, then pass as &"AYZ_..." to IPrintLnBold/setHintString. Parameterized stock istring on triggers: trigger setHintString(&"ZOMBIE_BUTTON_BUY_OPEN_DOOR_COST", price) injects the cost.

- **Source:** MattFiler/zm_alien_isolation usermaps/zm_alien_isolation/english/localizedstrings/ayz.str L1-63; zone_source/zm_alien_isolation.zone L17; zm_alien_isolation.gsc L93-119, L295-299
- **For our map:** We currently hard-code hint strings; adopting acc.str + localize,acc gives translatable hints and the &"ZOMBIE_BUTTON_BUY_OPEN_DOOR_COST" cost-injection for all our buyables.

### Zero-asset objective system: IPrintLnBold + local sound sting + timed reminders

UPDATE_OBJECTIVE(istr): PLAY_LOCAL_SOUND("<map>__objective_updated") (PlayLocalSound on every player) then IPrintLnBold(&"AYZ_UI_OBJECTIVE_UPDATED") header followed by IPrintLnBold(objectiveText). REMIND_OBJECTIVE same with "CURRENT OBJECTIVE:" header; reminder threads wait(60) and re-fire only if the corresponding level.hasActivatedConsoleN bool is still false. Objectives chained off level flags/notifies ("ayz_lockdown_completed", flag::wait_till("power_on"), zone-touch polls).

- **Source:** MattFiler/zm_alien_isolation usermaps/zm_alien_isolation/scripts/zm/zm_alien_isolation.gsc L258-269; eng_towplatform.gsc L284-292; hab_airport.gsc L83-125
- **For our map:** Cheapest possible quest-guidance layer for our Cyberware tree steps and boss phases — ship this first, upgrade to LUI popups later.

### Mechanical world-space counters as HUD + event bus

Population sign: two flip-digit models (targetname counter_tens/counter_ones) RotateRoll(±36,1s) + PlaySound("zmb_counter_flip") + waittill("rotatedone"), decremented while local_kills < (level.total_zombies_killed - level.zombie_total_subtract); at counts 33/66/99 → level notify("update_doomsday_clock"). Clock: minute hand model LinkTo(clock model,"mp_nuked_doomsday_clock" tag) — requires flag::wait_till("initial_blackscreen_passed") before LinkTo — RotatePitch steps; each move notifies "nuke_clock_moved" which other modules (powerup-behind-door, music EE) consume.

- **Source:** zm_nuked scripts/zm/classic_features/nuketown_panneau.gsc:21-63; scripts/zm/classic_features/clock_nuked.gsc:26-60
- **For our map:** Physical-counter pattern fits our cyber-city aesthetic (holo kill counters, shard meters) and shows chaining world events off kill counts; confirms initial_blackscreen_passed is a flag.

### Full custom HUD pipeline: clientuimodel clientfields -> rawfile Lua widgets in overridden t7hud_zm_custom.lua

(1) GSC: clientfield::register("clientuimodel","abbeyRoom",VERSION_SHIP,5,"int") then player clientfield::set_player_uimodel("abbeyRoom",v); 'world' and 'toplayer' scopes also used (toplayer supports "float" type for progress bars: clientfield::register("toplayer","trials.porthos",VERSION_SHIP,10,"float")). (2) Lua: widget file CoD.X=InheritFrom(LUI.UIElement); subscribeToModel(Engine.GetModel(Engine.GetModelForController(InstanceRef),"abbeyRoom"),cb); cb reads Engine.GetModelValue(ModelRef). (3) Hook into game HUD by shipping ui/uieditor/menus/hud/t7hud_zm_custom.lua (stock zm hud menu name — engine loads it by name) which require()s each widget and instantiates it in PreLoadCallback. (4) Zone: rawfile,ui/uieditor/menus/hud/t7hud_zm_custom.lua + rawfile per widget + image,<name> per texture. (5) One-shot events from GSC: player LUINotifyEvent(&"generator_activated",1,idx). (6) Visibility: subscribe to UIVisibilityBit models (BIT_HUD_VISIBLE etc.) and hide during scoreboard/killcam.

- **Source:** ohm-nabar/zm_building ui/uieditor/menus/hud/t7hud_zm_custom.lua:1-40,92-110; ui/uieditor/widgets/hud/room_manager.lua:1-60; scripts/zm/zm_challenges.gsc:69-87; zone_source/zm_building.zone:272-283
- **For our map:** The recipe our shipped custom HUD follows for the Data Shards counter and Overclock indicators (the same pattern would drive Cyberware-tree state if that dormant module is re-enabled) — register clientuimodel ints/floats server-side (`_acc_lui.gsc/.csc`), drive the LUI widgets (`AetheriumHud.lua` / `acc_hud.lua`), one rawfile zone line per Lua file.

### GSC-driven in-game journal/menu with zero LUI keybind plumbing

Toggle: poll self ActionSlotFourButtonPressed() (d-pad slot 4); on press flip self.abbey_inventory_active, PlaySoundToPlayer("journal_open"), clientfield::set_player_uimodel("inventoryVisible",1), self DisableWeapons(); debounce by while(buttonPressed)wait(.05). Tab nav while open: AttackButtonPressed() = next tab, AdsButtonPressed() = prev (with AllowAds(false) during hold), writing clientfield "currentTab" (2-bit). All page content is other clientuimodel ints (cherryUpdate 4-bit, staminUpdate 5-bit, ...) rendered by Lua menus (inventory_control.lua) that show/hide on inventoryVisible. Blueprint collection pages encode 3 booleans as one int: (a*4)+(b*2)+c, and Lua picks image weapon_bp_<a>_<b>_<c> — 8 precompiled images instead of compositing.

- **Source:** ohm-nabar/zm_building scripts/zm/zm_abbey_inventory.gsc:81-90,149-235; scripts/zm/zm_blueprints.gsc:76-119; zone_source/zm_building.zone:219-235
- **For our map:** Cheapest viable UI for our Cyberware tree: server polls buttons, client renders from uimodels — no Lua input handling; the bitmask->pre-rendered-image trick avoids dynamic compositing for shard/upgrade collection screens.

### Server-side hudelem toolkit: typed elems, progress bars, waypoints, icon timers (no LUI needed)

Mods/maps can build full HUD without lua: `NewHudElem()` (all players) / `NewClientHudElem(player)` / `newScoreHudElem(player)`; fields .alignX/.alignY('center','middle'), .horzAlign/.vertAlign('fullscreen' for overlays), .x/.y, .font='big'/'default', .fontScale, .sort, .foreground, .hidewheninmenu, .archived. Typed content: SetText(str), SetValue(n), SetTimer(secs) countdown, SetTimerUp(0) countup, SetShader(material,w,h). Animations: FadeOverTime/MoveOverTime/ScaleOverTime then set target field; SetPulseFx(70,2910,500) for glowing text; typewriter = SetText(substr) in a loop (ugxm_util.gsc:1068-1079). Progress bar = 'white' shader bar over 'black' shader bg, value set by `setShader(shader, int((value/total)*width), height)` (create_progressbar/progressbar_setvalue, ugxm_util.gsc:665-727). Full-screen fade = SetShader('black',640,480) at fullscreen align, sort 50. 3D waypoint: newHudElem with .x/.y/.z = world coords, setShader(icon,size,size), `setWaypoint(true, shadername)`, .fadeWhenTargeted=true (chaosmode dropCarePackage, ugxm_chaosmode.gsc:1339-1350). Hide stock HUD per player: `setClientUIVisibilityFlag("hud_visible",0)` and `"weapon_hud_visible"`. Their per-player icon tray (powerup_shader_timed + shader_shuffle) recenters N icons by computing totalWidth=(n*size)+((n-1)*spacing) and MoveOverTime — a reusable buff-tray widget. They explicitly note mods get no LUI access (ugxm_powerups.gsc:380).

- **Source:** treminaor/ugx-mod-bo3 ugxmod/scripts/zm/ugxm/ugxm_util.gsc:301-727,988-1092; ugxm_powerups.gsc:380-531; ugxm_chaosmode.gsc:1339-1350
- **For our map:** Lets us ship Data Shards counter, Cyberware progress bars, Overclock buff tray, and boss health bar in Phase 1 GSC-only — deferring all LUI work; the waypoint pattern marks Data Shard pickups through walls.

### Button-polled in-game menu (host votes gamemode) with debounce

Menu = stack of client hudelems (one per row, gap=15px, selected row flashes color (1,1,0) on 0.1s poll). Input loop polls `self MeleeButtonPressed()` (up) / `AttackButtonPressed()` (down) / `UseButtonPressed()` (select) / `JumpButtonPressed()` (toggle), each followed by `while(self XButtonPressed()) wait 0.001;` debounce. Button glyphs render in hint-style text: "[{+melee}]/[{+attack}]... [{+activate}]". Host-only via `self GetEntityNumber() == 0`; non-hosts get a pulsing 'Waiting for host' elem. Alternative stock-menu path exists: `#precache("menu","popup_leavegame")`, `self OpenMenu("popup_leavegame")`, `self waittill("menu_response", menu, response)` (menu_test, ugxm_init.gsc:437-449). Their custom .menu rawfile (ui/ugxm_vote_host.menu) is referenced in the zone but absent from the repo — don't copy that line.

- **Source:** treminaor/ugx-mod-bo3 ugxmod/scripts/zm/ugxm/ugxm_init.gsc:437-681
- **For our map:** Ready-made pattern for our Overclock/loadout selection at run start and for a debug menu — zero assets required.

### Lua-menu purchase station (CW Wunderfizz pattern) — full GSC<->LUI loop

GSC side: #precache("menu","WonderfizzMenuBase") + #precache("lui_menu_data","cw_perk_buyables.owned_perks"); `function autoexec init()` (autoexec keyword = runs without being called from main) registers buyables in level.cw_perk_buyables[specialty]=SpawnStruct. On unitrigger `waittill("trigger_activated", player)` -> `player CloseMenu("WonderfizzMenuBase"); player OpenMenu("WonderfizzMenuBase")`; push state to UI with `self SetControllerUIModelValue("cw_perk_buyables.owned_perks", "perk1|perk2|")`; receive purchases via `self waittill("menuresponse", menu, response)` filtered on menu=="WonderfizzMenuBase", parse `StrTok(response,".")` -> ["perk", name, cost], then zm_score::can_player_purchase/minus_to_player_score + zm_perks::give_perk("specialty_"+name,false). Lua side: LUI.createMenu.WonderfizzMenuBase PreLoadCallback creates the model: Engine.CreateModel(Engine.GetModelForController(InstanceRef),"cw_perk_buyables") then CreateModel(buyablesModel,"owned_perks"); items come from DataSourceHelpers.ListSetup("BuyablePerksDataSource", fn) with per-item models {text,description,cost,responseStr="perk.<specialty>."..cost,itemIcon}; selection sends Engine.SendMenuResponse(InstanceRef,"WonderfizzMenuBase",responseStr); owned state read back via Engine.GetModelValue(Engine.GetModel(Engine.GetModelForController(InstanceRef),"cw_perk_buyables.owned_perks")) and Widget:subscribeToModel on same; live points via subscribeToModel on DataSources.ZMPlayerList "0"."playerScore"; solo-vs-coop pricing via Engine.GetLobbyClientCount(Enum.LobbyType.LOBBY_TYPE_GAME)>1. Menu Lua ships as zone `rawfile,ui/uieditor/menus/...lua` lines; custom menu icons need `image,<name>` zone lines.

- **Source:** ColDog5044/zm_countryside scripts/zm/_t9_wonderfizz.gsc:40-41,49-90,124-131,161-244; ui/uieditor/widgets/Wonderfizz/MenuTabPerks.lua:10-31; ui/uieditor/widgets/Wonderfizz/PerksUIListWidget.lua:196; ui/uieditor/widgets/Wonderfizz/MenuListItemWidget.lua:618,698-703; ui/uieditor/menus/Craftables/WonderfizzMenuBase.lua:8-12,35-145
- **For our map:** This is THE template for our Cyberware tree / Overclock terminal UI: replace perk entries with cyberware nodes, responseStr="cyber.<node_id>.<shard_cost>", owned_perks model becomes our owned-upgrades pipe-delimited string.

### Full stock-HUD replacement via client LuiLoad + rawfile zone lines

In .csc main() BEFORE zm_usermap::main(): `LuiLoad("ui.uieditor.menus.hud.T7Hud_zm_factory");` — loads a same-named Lua override of the stock factory HUD; the Lua file ships as zone `rawfile,ui/uieditor/menus/hud/T7Hud_zm_factory.lua` (HB21's perk-icon widgets arrive the same way: rawfile,ui/uieditor/widgets/hud/zm_perks/*.lua per linker deps). HUD widgets gate visibility by subscribing to engine models: hudItems.playerSpawned and UIVisibilityBit.<Enum.UIVisibilityBit.BIT_HUD_VISIBLE|BIT_GAME_ENDED|BIT_IN_KILLCAM|...>.

- **Source:** ColDog5044/zm_countryside scripts/zm/zm_countryside.csc:55-68; ui/uieditor/menus/hud/T7Hud_zm_factory.lua:99-179; zone_source/all/assetinfo/zm_countryside.deps (rawfile,ui/uieditor/widgets/hud/zm_perks/*.lua)
- **For our map:** Our Data Shards counter and Cyberware HUD belong in a LuiLoad'ed override of T7Hud_zm_factory with a custom widget subscribed to a clientfield/UI model we set from GSC.

### Custom perk icon HUD (clientuimodel → Lua factory)

Server sets a 2-bit "clientuimodel" clientfield at path "hudItems.perks.<key>" (states: 0=off, 1=owned, 2=paused/greyed). A Lua widget shipped as rawfile (ui/uieditor/widgets/HUD/ZM_Perks/ZMPerksContainerFactory.lua, required by ui/uieditor/menus/hud/T7Hud_zm_factory.lua at L8/L51-54) holds a key→material table (e.g. phdflopper="i_t7_specialty_phdflopper", electric_cherry="i_t7_specialty_electriccherry", custom: timewarp="i_t6_specialty_timewarp") and polls Engine.GetModelValue(Engine.GetModel(Engine.GetModel(Engine.GetModelForController(controller), "hudItems.perks"), key)) per frame, inserting/removing icons in a UIList and writing status into the "ZMPerksFactory" model. Pause state set GSC-side: set_clientfield func coerces state to 2 when zm_perk_utility::is_perk_paused (vulture_aid_set_clientfield L130-140). Install: zone line rawfile,ui/uieditor/menus/hud/t7hud_zm_factory.lua + rawfile for each widget; shader image via zone line image,specialty_<perk>_zombies.

- **Source:** ColDog5044/zm_countryside ui/uieditor/widgets/HUD/ZM_Perks/ZMPerksContainerFactory.lua L12-29, L67-120; ui/uieditor/menus/hud/T7Hud_zm_factory.lua L8, L51-54; Polystyreeni/BO3 ui/uieditor/widgets/hud/zm_perks/customperkicons.lua; dtzxporter/ModmeForum wiki/threads/3537.md L36
- **For our map:** Gives PhD Flopper (and the Mega-upgrade 'paused/overclocked' visual state) a real icon; status=2 is a free 'perk disabled by Overclock' indicator.

## WEAPONS

### Start-weapon override + per-player scripted weapon grant

main(): level.ORIGINAL_start_weapon = level.start_weapon; level.start_weapon = getWeapon("knife") — players spawn with knife only; restored (level.start_weapon = level.ORIGINAL_start_weapon) when the real map begins. Scripted grant: player zm_weapons::weapon_give(GetWeapon("pistol_standard"), false, false, true, true); then player SetWeaponAmmoClip(weapon, 0) + SetWeaponAmmoStock(weapon, 0) to hand an EMPTY gun during the intro, refilled later with GiveMaxAmmo(GetWeapon("pistol_standard")) at the action beat.

- **Source:** MattFiler/zm_alien_isolation usermaps/zm_alien_isolation/scripts/zm/zm_alien_isolation.gsc L159-161; bsp_torrens.gsc L684-688, L787; hab_airport.gsc L182
- **For our map:** Our per-run randomization can swap level.start_weapon at main() time, and the empty-gun grant is a nice tension beat for the intro.

### Custom weapon table CSV wiring (server + client + zone)

CSV at gamedata/weapons/zm/zm_nuked_weapons.csv, header: weapon_name,upgrade_name,hint,cost,weaponVO,weaponVOresp,ammo_cost,create_vox,is_zcleansed,in_box,upgrade_in_box,is_limited,limit,upgrade_limit,content_restrict,wallbuy_autospawn,class,is_aat_exempt,is_wonder_weapon,force_attachments. Server: level._zombie_custom_add_weapons=&fn → zm_weapons::load_weapon_spec_from_table(path,1) (set BEFORE zm_usermap::main()). Client: identical call must exist in .csc — they override zm_usermap.csc since there is no client hook. Zone: 'stringtable,gamedata/weapons/zm/zm_nuked_weapons.csv' plus explicit 'weapon,<name>_zm' lines for DLC weapons (raygun_mark2_zm, t6_tazer_knuckles_zm...). force_attachments column example: 'reddot grip' on ar_famas.

- **Source:** zm_nuked gamedata/weapons/zm/zm_nuked_weapons.csv:1-36; scripts/zm/zm_nuked.gsc:131,342-345; scripts/zm/zm_usermap.csc:93-97; zpkg:1-16
- **For our map:** We already ship a modified `gamedata/weapons/zm/zm_levelcommon_weapons.csv` with our custom costs/roster, wired via `level._zombie_custom_add_weapons = &custom_add_weapons` → `zm_weapons::load_weapon_spec_from_table(...)` (entry `.gsc:213,949`); this entry documents the full verified path (including the client-side trap) that our override follows.

### Full-roster integration via zm_levelcommon_weapons.csv override

Three coupled pieces: (1) gamedata/weapons/zm/zm_levelcommon_weapons.csv with header weapon_name,upgrade_name,hint,cost,weaponVO,weaponVOresp,ammo_cost,create_vox,obsolete_false,in_box,upgrade_in_box,is_limited,limit,upgrade_limit,obsolete2_false,wallbuy_autospawn,class,is_aat_exempt,is_wonder_weapon,force_attachments — 44 data rows (31 with in_box=TRUE, 41 wallbuy_autospawn=TRUE; classes pistol/smg/rifle/shotgun/lmg/sniper/launcher/special/grenade/gas; ported weapons all is_aat_exempt=TRUE; force_attachments is space-separated, e.g. 'reddot fastreload' on bo3_mp40; wonder weapon zm_pitchfork upgrades to a DIFFERENT weapon zm_trident with is_limited=TRUE,limit=1). (2) GSC hook: level._zombie_custom_add_weapons = &custom_add_weapons; function body is one line: zm_weapons::load_weapon_spec_from_table("gamedata/weapons/zm/zm_levelcommon_weapons.csv", 1). (3) Zone: stringtable,gamedata/weapons/zm/zm_levelcommon_weapons.csv plus one weapon,<name> line per weapon file including upgrades — dual-wield pistols need three zone lines each: base, <name>_rdw_up_zm, <name>_ldw_up_zm, while CSV upgrade_name uses <name>_rdw_up (no _zm).

- **Source:** ohm-nabar/zm_building gamedata/weapons/zm/zm_levelcommon_weapons.csv (all 45 lines); scripts/zm/zm_building.gsc:177,391-394; zone_source/zm_building.zone:463-575
- **For our map:** Exact recipe for our wallbuy/box roster expansion — CSV row + zone weapon line + _zombie_custom_add_weapons hook is all a new gun needs; copy the column header verbatim.

### Starting-loadout choice via pickup triggers + bare-hands start weapon

level.start_weapon=GetWeapon("bare_hands_t7") (a custom do-nothing weapon, CSV row class special) forces players to choose: triggers targetname pistol_pickup with script_noteworthy bloodhound/colt/luger/cz map to weapons; each gets SetCursorHint("HINT_WEAPON",weapon) + SetHintString(&"ZM_ABBEY_TAKE_WEAPON") and a think thread giving the gun. Chosen pistol also sets last-stand pistol behavior: level.default_laststandpistol/laststandpistol/default_solo_laststandpistol (solo variant = dual-wield upgraded s4_1911_rdw_up). Lethal registration pattern: zm_utility::register_lethal_grenade_for_level("frag_grenade_potato_masher"); level.zombie_lethal_grenade_player_init=GetWeapon(...).

- **Source:** ohm-nabar/zm_building scripts/zm/zm_starting_pistol_choose.gsc:66-110; scripts/zm/zm_building.gsc:153,157-158
- **For our map:** Our per-run randomization can offer randomized starting-gear stations with this exact trigger pattern; bare_hands_t7 start weapon is the clean way to force an opening choice.

### Mutex-guarded weapon_give + cost-sorted weapon list + gamemode weapon filter

weapon_give (ugxm_util.gsc:406-506): guards re-entry with a player flag "weapon_give_in_progress" (flag::init/wait_till_clear/set/clear) to stop the ENGINE silently stealing guns when inventory overflows; resolves duplicates via `weapon.rootWeapon` comparison and `zm_weapons::has_weapon_or_attachments / has_upgrade / get_upgrade_weapon`; upgrade path via `level.zombie_weapons[weap.rootWeapon].upgrade`; enforces `zm_utility::get_player_weapon_limit(self)`; random cosmetics via `CalcWeaponOptions(RandomInt(125),5,randomInt(10),5,5,5,1)` + `GetRandomCompatibleAttachmentsForWeapon(weap,4)` + `getWeapon(name, att1..att4)`. Weapon roster: bubble-sort `level.zombie_weapons` keys by `.cost` (weapons ARE the array keys), filter with is_gamemode_weapon_allowed — reject weapclass "item"/"melee"/"grenade", level.weaponNone, and idgun_1..4 (SoE). Offhand purge each tick: `getWeaponsList()` → takeWeapon any `.weapClass == "offhand"`.

- **Source:** treminaor/ugx-mod-bo3 ugxmod/scripts/zm/ugxm/ugxm_util.gsc:9-24,393-518; ugxm_gungame.gsc:44-128
- **For our map:** Our random-weapon Overclocks and any 'give weapon' reward path should copy the mutex + rootWeapon dedup logic verbatim — it encodes several engine traps we can't discover without a compile.

### AAT re-Pack-a-Punch tier (second PaP purchase rerolls ammo type)

On trigger: weapon=player GetCurrentWeapon(); if zm_weapons::is_weapon_upgraded(weapon) && zm_weapons::weapon_supports_aat(weapon) && level.aat_in_use -> charge 2500 and `self thread aat::acquire(weapon)` (namespace from scripts\shared\aat_shared + #insert scripts\shared\aat_zm.gsh, plus #using scripts\zm\aats\_zm_aat_blast_furnace); rolled result readable at player.aat[weapon] in {"zm_aat_blast_furnace","zm_aat_dead_wire","zm_aat_fire_works","zm_aat_thunder_wall","zm_aat_turned"}. First-time upgrade path: zm_weapons::can_upgrade_weapon(weapon) -> zm_weapons::get_upgrade_weapon(weapon,false) -> self zm_weapons::weapon_give(up,true,false,true,true) + switchToWeapon. Machine FX synced to client via clientfield::register("scriptmover","t9_pap_FX_*",VERSION_SHIP,bits,"int") set on the machine script_model. Map side: script_struct targetname=pap_trigger_struct + script_model targetname=pack_a_punch_model. is_aat_exempt CSV column (col 18) blocks AAT per weapon.

- **Source:** ColDog5044/zm_countryside scripts/zm/zm_cwpap.gsc:23-25,46-66,78-163,265-277,343-371; gamedata/weapons/zm/zm_levelcommon_weapons.csv:1,7-11
- **For our map:** Direct blueprint for Overclocks: a re-purchase tier on an already-modified weapon that rerolls a randomized effect, with clientfield-driven machine FX.

### Weapon inspect system integration (lilrobot _inspectable_weapons)

Source GSC is NOT in either repo — it installs to `<BO3>/share/raw/scripts/lilrobot/_inspectable_weapons.gsc` (proven by linker .deps file path) and the linker resolves the zone line `scriptparsetree,scripts\lilrobot\_inspectable_weapons.gsc` from share/raw when absent from the usermap — i.e. scriptparsetree paths search usermaps/<map>/ then share/raw/. Server-only (no .csc). Wiring: `#using scripts\lilrobot\_inspectable_weapons;` then in main() BEFORE zm_usermap::main(): one `inspectable::add_inspectable_weapon( GetWeapon("<name>"), <inspect_anim_length_seconds> )` per weapon AND per upgraded variant (dual-wield upgrades registered as `<gun>_rdw_up`/`_ldw_up` — no _zm suffix in script even though zone assets are _zm-suffixed).

- **Source:** ColDog5044/zm_countryside scripts/zm/zm_countryside.gsc:19-20,116-274; zone_source/zm_countryside.zone:58-59; zone_source/all/assetinfo/zm_countryside.deps (scriptparsetree,scripts\lilrobot entry -> share\raw path); Skye-Weapon-Templates rex/templates/14. ZM - BOCW/usermaps/template/scripts/zm/template.gsc diff vs base
- **For our map:** If we ship Skye weapon packs, copy these exact call lists per pack; also documents the share/raw fallback our zone lines could exploit for third-party kits.

### Skye weapon-pack integration: the exact 5-file diff per game

Adding a Skye pack to a map changes exactly: (1) template.gsc — add `#using scripts\lilrobot\_inspectable_weapons;` + add_inspectable_weapon lines (ONLY for MWR/WW2/BO4/MW19/MW2R/BOCW packs; MW2/BO1/MW3/BO2/Ghosts/AW/IW/VG have no inspect anims) and swap startingWeapon/laststandWeapon to the pack pistol (e.g. "t9_1911"/"t9_1911_rdw_up"); (2) zone — one `weapon,<gun>` line per weapon asset: base + `_up` upgrade; dual-wield pistols use THREE assets `<gun>`, `<gun>_rdw_up_zm`, `<gun>_ldw_up_zm`; underbarrel variants get own lines (`_launcher_zm`, `_shotty_zm`); NO xmodel/xanim/sound/weaponcamo lines needed — the weapon asset pulls them transitively (errorlog proves chain weapon->weaponcamo-><material>); (3) szc — append one Sources entry {"Type":"ALIAS","Name":"skye_<game>_weapons","Filename":"skye_<game>_weapons.csv","Specs":[]} (alias csv ships with the pack, consumed by the sound tool not the linker); (4) gamedata/weapons/zm/zm_levelcommon_weapons.csv — one row per gun with header weapon_name,upgrade_name,hint,cost,weaponVO,...,wallbuy_autospawn,class,is_aat_exempt,is_wonder_weapon,force_attachments; note CSV upgrade_name uses `<gun>_rdw_up` WITHOUT the _zm suffix the zone asset carries; launchers set is_aat_exempt=TRUE; hint column (col 3) overrides wallbuy price display, ammo_cost (col 7) used for minigun-type ammo; force_attachments effectively unused across all 14 packs; (5) zone also gains `scriptparsetree,scripts\lilrobot\_inspectable_weapons.gsc` only for inspect-capable packs. csc: NO changes (52 lines identical in all 15 templates). PaP camo for packs handled per-map via level.pack_a_punch_camo_index (countryside uses 28) — packs ship their own weaponcamo tables (t9_camo_<gun>_table).

- **Source:** Skye-Weapon-Templates diffs: 01. ZM - Base vs {10. ZM - WW2, 12. ZM - MW19, 14. ZM - BOCW}/usermaps/template/{scripts/zm/template.gsc, zone_source/template.zone:24-29, sound/zoneconfig/template.szc:22-28, gamedata/weapons/zm/zm_levelcommon_weapons.csv}; ColDog5044/zm_countryside zone_source/all/assetinfo/zm_countryside.errorlog:2-6, scripts/zm/zm_countryside.gsc:295-296
- **For our map:** Our wallbuy roster expansion recipe: per added gun we need exactly one zone weapon line per asset variant + one CSV row; copy the dual-wield/_zm naming asymmetry into docs/14 to avoid the classic 'asset not found' first-compile error.

### Skye BASE template extras over true stock (widows wine, spare change, better max ammo, power lighting)

Base template (which we forked) already adds: #using scripts\zm\_zm_perk_widows_wine (gsc+csc); `level zm_perks::spare_change();`; better_max_ammo(): loop `level waittill("zmb_max_ammo_level")` then per player `foreach gun in GetWeaponsListPrimaries(): SetWeaponAmmoClip(gun, GetWeapon(gun.name).clipSize)` (refills clips, stock max-ammo only fills stock); CheckForPower(): util::set_lighting_state(0) at start, `level waittill("power_on")` -> set_lighting_state(1) (Radiant-baked dual lighting states); plus the triggerstring precache block (power-lag fix).

- **Source:** Skye-Weapon-Templates rex/templates/01. ZM - Base/usermaps/template/scripts/zm/template.gsc:42,59-82,115-148
- **For our map:** Already adopted — our entry script has spare_change, better_max_ammo, set_lighting_state and 19 triggerstring precaches; keep as verified-known-good cross-reference.

## PUBLISHING

### Workshop artifact set: workshop.json fields + zone/ images + named videos

usermaps/<map>/zone/workshop.json: {"Description": "...\r\n\r\n...", "FolderName": "zm_alien_isolation", "PublisherID": "817550789" (numeric Steam Workshop file id as string, filled after first publish), "Tags": "Map,Zombies", "Thumbnail": "<abs path>/zone/workshopimage.jpg", "Title": "...", "Type": "map"}. Companion files in zone/ (named in .gitignore allowlist): previewimage.png, loadingimage.png, workshopimage.jpg. Videos at zone/video/: <map>_load.mkv (loading screen movie, picked up by name convention) plus arbitrary cutscene movies (<map>_cs01..03.mkv) that need NO zone entry — lui::prime_movie/play_movie reference them by filename stem.

- **Source:** MattFiler/zm_alien_isolation usermaps/zm_alien_isolation/zone/workshop.json L1-9; .gitignore allowlist L23-28; usermaps/zm_alien_isolation/zone/video/*.mkv; zm_alien_isolation.gsc L81-83
- **For our map:** Completes our docs/34 publish checklist: exact field names, the three image filenames, and the <map>_load.mkv loading-video convention.

### Override stock scripts by shipping same-path copies in the map zone

Copy a stock script to identical path under usermap scripts/ (e.g. scripts/zm/_zm_perk_widows_wine.gsc/.csc/.gsh, scripts/zm/zm_usermap.csc), edit it, and list 'scriptparsetree,scripts/zm/_zm_perk_widows_wine.gsc' in the zone — the linker compiles your copy instead of stock. Nuked uses it to (a) swap perk-light FX #defines to factory variants, (b) add tazer-knuckle melee to widows wine, (c) repoint the CLIENT weapon table CSV (zpkg line 3 comment: 'Required to use custom table weapon' — GSC side has the level._zombie_custom_add_weapons hook, CSC has none so full-file override is mandatory).

- **Source:** zm_nuked zone_source/zm_nuked.zpkg:3,48-83; scripts/zm/zm_usermap.csc:95-97 (only diff vs stock); diff of _zm_perk_*.gsc/gsh vs stock
- **For our map:** Our verified escape hatch when a stock hook doesn't exist (e.g. client-side weapon tables, perk FX) — safer than our riskier inline patches.
- **zm_patch.csv DEDUPE TRAP (learned from eMoX T8 Delayed Powerup Drop, installed 2026-07-11):** if
  the stock script you're overriding is listed in `<tools>\zone_source\all\assetlist\zm_patch.csv`
  (e.g. `_zm_powerups.gsc` — the nuked examples above are NOT), the linker's already-in-a-parent-
  fastfile dedupe SILENTLY SKIPS your zone's scriptparsetree line and the override never lands (no
  error — the feature is just absent at runtime). Fix per the pack readme: comment out that line in
  zm_patch.csv (install-side stock-file edit — backup `.acc-orig-backup`, documented in
  `tools/external_assets_manifest.ps1`, re-apply after a Mod Tools reinstall). Verify the override
  actually landed by finding `scripts/zm/_zm_powerups.gsc` in the linker log's compile list.
- **Blocking-callers gotcha (same install):** an override that adds `wait()`s inside a function
  stock guaranteed to return same-frame (eMoX adds ~1.6s inside `powerup_setup`) changes the
  contract for every caller: entity-owned threads that die mid-wait (corpse delete) strand the
  half-initialized powerup. Audit call sites for `level thread` vs self-thread/plain calls
  (we fixed mechz_spiki + nsz_brutus, 2026-07-11).

### Repo layout + .zone anatomy for a heavily-modded map (no .map committed)

Repo mirrors only the usermap overlay: scripts/, ui/, gamedata/, sound/zoneconfig/, vision/, behavior/animtables/animstatemachines (custom AI), english..traditionalchinese/localizedstrings/<map>.str (13 langs), zone_source/. .gitignore excludes zone/ and all linker-generated zone_source/<lang>/ + zone_source/all/. The 708-line .zone demonstrates every asset-line type a modded map needs: >class,zm_mod_level / >group,modtools header; col_map+gfx_map BSP; sound,<szc name>; scriptparsetree per gsc/csc AND .gsh; weapon,<n>; image,/material,<HUD shaders>; xmodel,; fx,<path> (no .efx ext except legacy); xanim,<ported anims>; aitype,archetype_<custom zombie>; zbarrier,zmcore_magicbox_fade; scriptbundle,; postfxbundle,pstfx_zm_castle_teleport; stringtable,<csv>; localize,zm_abbey (pulls the .str); rawfile,ui/...lua per Lua file; ttf,fonts/<custom fonts>; vision rawfiles; and modular reuse via include,<pkg> resolving zone_source/<pkg>.zpkg — a .zpkg is just a plain fragment of the same asset lines (bgb_pack.zpkg = 120 scriptparsetree lines for all gobblegum modules).

- **Source:** ohm-nabar/zm_building .gitignore; zone_source/zm_building.zone:1-709; zone_source/bgb_pack.zpkg, flashlight.zpkg, spx_util_script.zpkg
- **For our map:** Adopt include,<feature>.zpkg to split our growing .zone per module (perks/boss/hud), note .gsh files also get scriptparsetree lines, and copy the localize,<map> + per-language .str pipeline for our custom hint strings.

### Mod-type zone file structure (vs map zone)

A mod ships one zone per game mode in zone_source/: zm_mod.zone, core_mod.zone, cp_mod.zone, mp_mod.zone. Header is `>mode,zm` + `>type,common` + `#include "zm_mod.class"` (NOT `>class,zm_mod_level`, no col_map/gfx_map BSP lines). Asset lines use the same vocabulary a map zone can use: `scriptparsetree,scripts/zm/x.gsc|.csc|.gsh`, `xmodel,name`, `fx,path/name`, `material,name`, `xanim,name`, `sound,zm_mod`, `rawfile,animtrees/ugx_box_anims.atr`, `rawfile,ui/x.menu`. Note .gsh files can be scriptparsetree'd too (line 25). zone/workshop.json uses `"Type": "mod"`, `"FolderName": "ugxmod"` (maps use "map"). Localization variants are linker-emitted per-language FFs (en_zm_mod.ff, ge_zm_mod.ff...) from per-language sound zones.

- **Source:** treminaor/ugx-mod-bo3 ugxmod/zone_source/zm_mod.zone:1-61; zone_source/core_mod.zone; ugxmod/zone/workshop.json
- **For our map:** Direct reference for adding custom models/fx/materials/animtrees to our map's .zone — we currently only have scriptparsetree + BSP lines; copy the material/fx/xanim/rawfile line syntax verbatim when we add custom assets.

### Localization reality check: no .str files, literal strings everywhere

The shipped mod contains zero .str/.english files; every player-facing string is a literal in SetText()/SetHintString()/iPrintLn — proving BO3 needs no string precache or localized-string assets for script HUD text. The only per-language artifacts are linker-generated sound zones (ugxmod/<language>/sound/zone/zm_mod.<lang>.alias.sz etc.), per-language assetinfo CSVs under zone_source/<language>/, and per-language FFs (zone/en_zm_mod.ff, ge_zm_mod.ff...) — all produced by the toolchain, not authored. zone_source/loc/zm_mod.zone is a linker-emitted resolution log (>expect, >level.xpak_read, scriptbundle lines), not hand-written.

- **Source:** treminaor/ugx-mod-bo3 repo-wide file inventory; ugxmod/english/sound/zone/*; zone_source/loc/zm_mod.zone
- **For our map:** Frees us from planning .str work: hardcode English strings in GSC like this shipped mod does; only sound localization would ever need per-language zones.

### Zone manifest composition: include,<kit> lines + .gsh scriptparsetree lines

.zone supports `include,<name>` which pulls another zone file (resolved from <BO3>/zone_source/<name>.zone) — countryside composes hb21_perks, spx_death_perception, spx_util_script, db_wunderfizz, alxs_cwpap as includes so the map zone stays small; third-party kit assets (perk bottle weapons etc.) still need their `weapon,` lines if not in the included zone. Also known-good: `.gsh` files CAN be listed as scriptparsetree lines (scriptparsetree,scripts/zm/_war_perk_return.gsh links fine and emits a .gsh.gdb). Slash styles mix freely in one file (lines 43 vs 59).

- **Source:** ColDog5044/zm_countryside zone_source/zm_countryside.zone:4-17,54-59,20-30
- **For our map:** If we adopt any community kit (HB21 perks etc.) use include, lines instead of inlining hundreds of asset lines; also relevant if we ever split our own zone into acc_core/acc_weapons includes.

### Workshop publish folder layout incl. compiled sound banks

Shipped layout: usermaps/<map>/zone/ holds loadingimage.png + previewimage.png + snd/all/<map>.all.{sabs,sabl} + snd/en/<map>.en.{sabs,sabl}; the snd files are copies of sound-tool output from usermaps/<map>/sound/zone/CachedBanks/{all,english}/. Sound build also emits sound/zone/<map>.all.{alias,ambient,assetcount,assets,ducklist,memory,musiclist,reverb,scriptid}.sz and english/sound/zone/<map>.english.*.sz. szc root keys: {"Name":"<map>","GameMode":"mpl","IsStandalone":true,"Builds":["T7"],"Sources":[{Type:ALIAS,Name,Filename,Specs:[]},{Type:AMBIENT,Filename,Specs:["mpl_mod"]}]}.

- **Source:** ColDog5044/zm_countryside file tree: zone/snd/{all,en}/, sound/zone/CachedBanks/, sound/zone/*.sz, sound/zoneconfig/zm_countryside.szc:1-54
- **For our map:** Extends our docs/34 publish checklist: after sound build, CachedBanks output must land in zone/snd/{all,en}/ or workshop audio is silent — countryside is the proof of the final folder shape.

### Perk packs ship as zone_source include files

Big packs install assets to BO3root (share/raw scripts/fx/sound + zone_source/<pack>.zone) and the usermap zone references them with ONE line: `include,hb21_perks` (zm_countryside.zone L5; also include,spx_death_perception, include,db_wunderfizz, include,alxs_cwpap L5-17), or `include,abnormal202_snails_pace_slurpee` (Snail's Pace). The include .zone contains the pack's scriptparsetree/xmodel/fx/weapon lines once, shared across maps. Per-can weapon assets still listed in map zone: weapon,zombie_perk_can_tombstone etc. (L20-30).

- **Source:** ColDog5044/zm_countryside zone_source/zm_countryside.zone L5-30; dtzxporter/ModmeForum wiki/threads/2294.md (zone snippet: include,abnormal202_snails_pace_slurpee)
- **For our map:** If we ever split _acc_ systems into reusable packs (or consume someone's pack), include-files keep our map .zone minimal; also documents that share/raw is the conventional pack asset root.

## ZONES

### Zone adjacency flags can be left unset — zones still activate on player entry (shipped evidence)

main() registers 10 zones via level.zone_manager_init_func + zm_zonemgr::manage_zones(init_zones); ZM_ALIEN_ISOLATION_ZONES() calls add_adjacent_zone with flags like "transition_from_torrens", "enter_perkroom_zone", "enter_adverts_zone", "ayz_elevator_zoneswap" — grep proves these flags are NEVER set by any script line nor carried as script_flag on any map/prefab entity, yet the map shipped and all areas spawn zombies. Conclusion verified by absence: zonemgr activates a zone when a player is physically inside its info_volume; adjacency flags only grant early/extra spawner activation. Where flags ARE wired, they ride on door/power triggers as KVP: stock power switch trigger_use 'use_elec_switch' carries "script_flag" "enter_noodlebar_zone" (power-on sets the flag, doubling as zone unlock), and door trigger_use ents carry "script_flag" "enter_main_zone"/"enter_end_zone".

- **Source:** MattFiler/zm_alien_isolation usermaps/zm_alien_isolation/scripts/zm/zm_alien_isolation.gsc L193-226; map_source/_prefabs/zm_alien_isolation/spaceflight_terminal_power.map L34; _prefabs/zm_alien_isolation/sft_lobby_to_old_spawn.map L100
- **For our map:** De-risks our 7-zone wiring: if a buyable-door flag wire is missed, zones still go live on entry; and we can hang zone flags on our existing door/power triggers as script_flag KVPs instead of explicit flag::set calls.

### Zone manifest split into .zpkg via include

zone_source/zm_nuked.zone is 14 lines: '>class,zm_mod_level', '>group,modtools', 'xmodel,skybox_default_day', 'material,luts_t7_default', col_map/gfx_map BSP lines, 'sound,zm_nuked', then 'include,zm_nuked' which pulls zone_source/zm_nuked.zpkg (227 lines) holding every scriptparsetree/fx/xmodel/weapon/stringtable/localize/image/xanim/scriptbundle line. A second 'include,camo_override' chains another package. Slashes mixed freely ('/' and '\'). zone_source/loc/zm_nuked.zone is the language variant ('>mode,zm', '>type,level', xpak_read/write lines, ignore_missing_shipped, 'localize,nuked_string').

- **Source:** zm_nuked zone_source/zm_nuked.zone:1-14, zone_source/zm_nuked.zpkg:1-227, zone_source/loc/zm_nuked.zone:1-216
- **For our map:** Adopt the .zpkg include to keep our growing 19-module scriptparsetree list out of the main .zone; loc zone shows the publish-time localize wiring we lack.

### 12-zone dense-map graph + runtime zone retirement

level.zones=[]; level.zone_manager_init_func=&init_fn; level thread zm_zonemgr::manage_zones(["start_zone"]). init_fn is only zm_zonemgr::add_adjacent_zone(zoneA, zoneB, "enter_flag") lines — same pair may repeat with different flags, and one flag may appear on several pairs (multi-path edges, e.g. enter_etage_house1 connects 3 pairs). Ends with flag::init("always_on")+flag::set("always_on"). Runtime: zm_zonemgr::enable_zone("start_omega_zone") to force-open, and direct pokes level.zones["start_zone"].is_enabled=.is_spawning_allowed=.is_active=false to retire a zone mid-game. level.pathdist_type=PATHDIST_ORIGINAL.

- **Source:** zm_nuked scripts/zm/zm_nuked.gsc:155-162,283-340,182-189
- **For our map:** Validates our 7-zone graph plan; the direct .is_* pokes give us a verified way to close zones for Overclock modifiers or boss arenas.

### Room manager: zone->display-name HUD + forced zombie migration between disconnected areas

Map zm_zonemgr zones to display rooms: level.abbey_rooms["Spawn Room"]=array("start_zone")...; level.abbey_rooms_indices[name]=int. Per-player thread polls self zm_zonemgr::entity_in_zone(zone) and sets clientfield::set_player_uimodel("abbeyRoom",index) (clientuimodel, 5-bit); Lua widget subscribes to model "abbeyRoom" and Engine.Localize()s from a lookup table. Zombie relocation when players move to an isolated area (beach): loop GetAiTeamArray(level.zombie_team); for zombies stuck in the wrong room (skip if IS_TRUE(zombie.in_the_ground)) do level.zombie_total++; level.zombie_respawns++; zombie dodamage(zombie.health+666, zombie.origin) — killing while crediting the round total makes the spawner re-emit them near the players.

- **Source:** ohm-nabar/zm_building scripts/zm/zm_room_manager.gsc:25-63,184-293; ui/uieditor/widgets/hud/room_manager.lua:11-30
- **For our map:** Gives our 7-zone map a zone-name HUD for free, and the kill+respawn-credit migration trick handles teleporter/boss-arena transitions without pathable connections.

### Runtime random-point generation over zones (PositionQuery_Source_Navigation)

No authored structs needed: for each `level.zones[zone].volumes[i].origin` call `PositionQuery_Source_Navigation(origin, minSearchRadius, maxSearchRadius, halfHeight, innerSpacing, undefined, outerSpacing)` (theirs: 1000, 2500, 300, 256, 512); validate each `queryResult.data[k].origin` with `zm_zonemgr::get_zone_from_position(point, true)` (discard if undefined); accumulate into `game["random_spawn_positions"]`. Consumers draw via a used-node history (reject points within 10 units of used ones; clear history when exhausted). Ground-snap helpers: `bullettrace(origin, origin+(0,0,-100000), 0, self)["position"]` or `playerphysicstrace(...)`.

- **Source:** treminaor/ugx-mod-bo3 ugxmod/scripts/zm/ugxm/ugxm_init.gsc:752-796; ugxm_chaosmode.gsc:1600-1630; ugxm_util.gsc:291-299
- **For our map:** Core enabler for our per-run randomization: scatter Data Shard pickups, craftable parts, and randomized box/teleport spots across the 7 zones without authoring hundreds of structs in Radiant.

### Multi-switch district power grid (power_on only when ALL switches thrown)

N map `trigger_use` ents each carrying script_int (used as a key); script: level.power_zones[name]=false per district; per-switch thread does `switch_ent waittill("trigger", player); level.power_zones[name]=true; check_power_status(); switch_ent Delete();`; check_power_status sets `level flag::set("power_on")` only when every district is true. Per-machine local power supported separately via zm_perks::register_perk_machine_power_override(PERK,&fn). Note their lookup helper compares ent.script_int against the key.

- **Source:** ColDog5044/zm_countryside scripts/zm/zm_countryside.gsc:314-315,344-390; scripts/zm/_zm_perk_phdflopper.gsc:56
- **For our map:** Fits our 7-zone cyber city: 2-3 district breakers that must all be restored before grid power, with machine-level overrides for pre-power Cyberware stations.

### Zone graph wiring with shared door flags + multiple initial zones

level.zones=[]; level.zone_manager_init_func=&fn; init_zones[] can hold MULTIPLE zone names (countryside starts with both "start_zone" and "perk_demo_zone" active); zm_zonemgr::manage_zones(init_zones). In init fn: zm_zonemgr::add_adjacent_zone(zoneA, zoneB, "flag_name") — the SAME flag may gate multiple edges ("enter_house_zone" used for both start->house and garage->house, i.e. one door opens two adjacencies); end with level flag::init("always_on"); flag::set("always_on"). Plus level.pathdist_type=PATHDIST_ORIGINAL.

- **Source:** ColDog5044/zm_countryside scripts/zm/zm_countryside.gsc:317-334
- **For our map:** Already adopted (we use add_adjacent_zone); the multi-initial-zone array and one-flag-many-edges patterns are useful for our hub room opening into two districts at once.

## INTRO

### Full playable-intro pipeline: blackscreen LUI + control-freeze watchdog + staged player state

Order matters: SetDvar("cg_draw2d",0) + SetDvar("ai_disableSpawn","1") first; level flag::wait_till("all_players_connected"); lui::prime_movie(id); per player: FreezeControls(true), thread open blackscreen (menu = player OpenLUIMenu("blackscreen"), closed via level waittill("starting_torrens_wakeup") then player CloseLUIMenu(menu)), and thread OVERRIDE_CONTROL_UNFREEZE(player) — a watchdog that waits while player AreControlsFrozen()==true then instantly re-freezes, defeating the stock blackscreen auto-unfreeze; level flag::wait_till("initial_blackscreen_passed"); then stage players: DisableWeaponFire/DisableOffhandSpecial, AllowStand(false)/AllowCrouch(false)/AllowProne(true), SetStance("prone"), HideViewModel(), SetMoveSpeedScale(0.7), player.allowdeath=false, setClientUIVisibilityFlag("weapon_hud_visible",0), with WAIT_SERVER_FRAME between stance-affecting calls; level.start_weapon swapped to getWeapon("knife") in main() (level.ORIGINAL_start_weapon saved, restored at transition). Transition into real map: fade out, lui::play_movie_with_timeout, physically relocate the 'initial_spawn_points' script_structs (currentSpawner.origin/.angles = struct::get("sft_spawners_"+i) values) AND 'player_respawn_point', SetOrigin each player, restore movement perms + allowdeath + start_weapon, then self notify("players_on_sevastopol") which other area threads waittill on and intro threads endon.

- **Source:** MattFiler/zm_alien_isolation usermaps/zm_alien_isolation/scripts/zm/bsp_torrens.gsc L65-135 (intro), L105-128 (player staging), L703-792 (transition); zm_alien_isolation.gsc L159-161, L460-466
- **For our map:** Blueprint for our cyber-city wake-up intro: the OVERRIDE_CONTROL_UNFREEZE watchdog and the dvar/flag ordering are the hard-won bits we cannot discover without a Windows box.

### CSC-side intro support: FOV override + GSC->CSC levelNotify channel

CSC main(): zm_usermap::main(); LuiLoad("ui.uieditor.menus.hud.blackscreen"); callback::on_localclient_connect(&fn); util::waitforclient(0); save GetDvarFloat("cg_fov_default"), SetDvar("cg_fov_default","91") for the cramped cryopod shot, restore after level waittill("out_of_cryopod", localClientNum). GSC sends that event per player with util::setClientSysState("levelNotify","out_of_cryopod", player); broadcast variant is util::clientnotify("ayz_power_on") / ("ayz_power_off") for lighting-side reactions. This is the only legal .gsc->.csc signaling (separate VMs).

- **Source:** MattFiler/zm_alien_isolation usermaps/zm_alien_isolation/scripts/zm/zm_alien_isolation.csc L44-65; bsp_torrens.gsc L379; hab_airport.gsc L76, L393
- **For our map:** Our `.csc` client modules standardize on util::setClientSysState("levelNotify", ...) / clientnotify for power, Overclock activations, and boss-phase visual cues.

### In-engine cutscene pipeline via .mkv + lui_shared (stock signatures verified)

Stock: prime_movie(str_movie, b_looping=false, str_key=""); play_movie(str_movie, str_type, show_black_screen=false, ...); play_movie_with_timeout(str_movie, str_type, timeout, show_black_screen=false, ...); screen_fade_out(n_time, v_color, str_menu_id) / screen_fade_in(...). Usage: level thread lui::prime_movie(id) well before play; lui::screen_fade_out(1); level thread lui::play_movie_with_timeout(id, "fullscreen", <seconds>, true); audio is NOT in the movie — a separate full-length wav alias is PLAY_LOCAL_SOUND'd in sync; hardcoded wait(<length>) then screen_fade_in(1). Movie ids #define'd (AYZ_CUTSCENE_ID_01..03 = mkv filename stems).

- **Source:** MattFiler/zm_alien_isolation usermaps/zm_alien_isolation/scripts/zm/zm_alien_isolation.gsc L81-83; bsp_torrens.gsc L73, L98, L708-720; eng_towplatform.gsc L216-225; zeroy99/bo3_modtools scripts/shared/lui_shared.gsc L192, L216, L336, L486, L501
- **For our map:** If we ship an intro or ending video for the cyber-city story, this is the whole API surface; the audio-as-separate-alias trick avoids mkv audio-sync issues.

### Custom intermission camera ride (level.custom_intermission)

level.custom_intermission=&fn (runs on player). fn: self CloseInGameMenu(); CloseMenu("StartMenu_Main"); self notify+endon("player_intermission"); self notify("_zombie_game_over"); self.score=self.score_total (scoreboard shows total earned); fullscreen black NewClientHudElem(self) setshader("black",640,480) alpha fade; if(self IsHost()) thread camera path: camera=Spawn("script_model") SetModel("tag_origin"); each player FreezeControls(true), HideViewModel(), SetInvisibleToAll(), SetDepthOfField(0,128,7000,10000,6,1.8), LinkTo(camera); camera MoveTo/RotateTo end struct over ~9s; flag::set ends it. Save level.old_custom_intermission to restore stock ending conditionally. Companion hook level.custom_player_fake_death=&fn: self.ignoreme=true; self EnableInvulnerability().

- **Source:** zm_nuked scripts/zm/zm_nuked.gsc:207-213,834-1003
- **For our map:** Drop-in pattern for a custom game-over flyover of our cyber city; both hooks are stock-dispatched.

### Delay round 1 until a pre-game choice completes (level.initial_round_wait_func)

Set `level.initial_round_wait_func = &wait_func` where wait_func does `level waittill("voting_complete")` — stock _zm.gsc:4344 calls `[[level.initial_round_wait_func]]()` before starting round 1 (verified in stock mirror). Pair with `level.player_movement_suppressed = true` (stock _zm.gsc:511-513 FreezeControls's every player to that bool) plus per-player FreezeControls(true)/DisableWeapons() on spawn, then on completion: FreezeControls(false), EnableWeapons(), `setClientUIVisibilityFlag("hud_visible",1)` / `"weapon_hud_visible"`, and both `level notify("voting_complete")` AND `flag::set("voting_complete")`.

- **Source:** treminaor/ugx-mod-bo3 ugxmod/scripts/zm/ugxm/ugxm_init.gsc:63,76-87,95-112,541-542; stock _zm.gsc:4344-4345,511-513
- **For our map:** Perfect hook for our run-start Overclock selection / intro sequence: roll per-run randomization while zombies are held off, without touching round logic.

### Fade-from-black + per-player gate before gameplay

On spawn (callback::on_spawned), create fullscreen black elem: NewHudElem(), .x/.y=0, .horzAlign/.vertAlign="fullscreen", SetShader("black",640,480), .sort=50, .foreground=false, alpha 1; remove with FadeOverTime(2.0/2.5)→alpha 0→Destroy after wait. Gate logic uses `IS_FALSE(level.passed_introscreen)` to skip for late joiners, and `flag::wait_till("initial_blackscreen_passed")` before showing menus (consistent with our ledger's flag rule). Spawn-time custom logic registry: `level._player_custom_spawn_logic` array of func pointers run threaded on each spawn (mirrors stock `level._zombie_custom_spawn_logic` in _zm_spawner.gsc:190-195,333-344).

- **Source:** treminaor/ugx-mod-bo3 ugxmod/scripts/zm/ugxm/ugxm_init.gsc:353-435,386-392,451-460; stock _zm_spawner.gsc:190-195,333-344
- **For our map:** Drop-in intro sequence shell for our map's cold-open, and the _player/_zombie_custom_spawn_logic arrays are the right registries for Cyberware on-spawn effects.

### Custom end-game screen (suppress stock intermission)

REGISTER_SYSTEM_EX(name,&__init__,&__main__,undefined); __main__ sets `level.disable_intermission = true` and callback::on_connect handler threads per-player: `level waittill("end_game")`; if IS_TRUE(level.host_ended_game) re-enable stock and bail; else zm_audio::sndMusicSystem_PlayState("game_over"), array::run_all(level.players,&clientfield::set,"zmbLastStand",0), level clientfield::set("game_end_time", int((GetTime()-level.n_gameplay_start_time+500)/1000)), self closeInGameMenu(); self CloseMenu("StartMenu_Main"); wait 2; self OpenMenu("Intermission_Main") (custom menu precached via #precache("menu","Intermission_Main") + rawfile Lua).

- **Source:** ColDog5044/zm_countryside scripts/zm/_zm_intermission_menu.gsc:18-64
- **For our map:** End-of-run stats screen for our systems map (shards earned, cyberware acquired, overclocks rolled) — exact hook points for a custom game-over menu.

## SOUND

### zm_audio music states backed by custom tracks via mus_<stem>_intro aliases

Stock signature (verified): zm_audio::musicState_Create(stateName, playType = PLAYTYPE_REJECT, musName1..6); player path builds aliasname = "mus_" + stem + "_intro" (_zm_audio.gsc L1060-1070). So: define aliases mus_<stem>_intro in your map's sound CSV pointing at your .wav (they hijacked stock stem names zod_gameover/zod_parasite_start/zod_egg_coldhardcash/zod_endigc_lullaby/zod_meatball_end so the stems are guaranteed registered), then musicState_Create("tpf_intro_theme", PLAYTYPE_GAMEEND, "zod_endigc_lullaby") and fire with level thread zm_audio::sndMusicSystem_PlayState("tpf_intro_theme"). PLAYTYPE constants #define'd 1-5 (REJECT/QUEUE/ROUND/SPECIAL/GAMEEND) controlling interrupt policy. Music alias row shape: Template UIN_MOD, Bus BUS_MUSIC, VolMin/Max 100, LimitCount 2 + oldest, 2d, NONLOOPING.

- **Source:** MattFiler/zm_alien_isolation usermaps/zm_alien_isolation/scripts/zm/zm_alien_isolation.gsc L85-90, L318-324; share/raw/sound/aliases/zm_alien_isolation.csv L3-8; zeroy99/bo3_modtools scripts/zm/_zm_audio.gsc L991-1041, L1111
- **For our map:** Our music plan (per-zone themes, boss phases) should register states once in a GLOBAL_MUSIC_SETUP-style function and reuse stock stems with overridden mus_* aliases — zero new sound-system code.

### Map sound alias CSV anatomy: new aliases + stock alias overrides in one file

share/raw/sound/aliases/<mapname>.csv with header Name,Behavior,Storage,FileSpec,...,Bus,...,VolMin,VolMax,DistMin,DistMaxDry,DistMaxWet,...,LimitCount,LimitType,...,(2d|3d),(wpn_all),(LOOPING|NONLOOPING). Patterns: 2d UI/music rows (BUS_MUSIC, 100/100, 2d, NONLOOPING); 3d spatial rows (BUS_FX, VolMin 0-50, DistMin 50, DistMaxDry 250-400, DistMaxWet +1, 3d, wpn_all curve, LOOPING for ambience); '#' prefix comments out a row. Crucially the file also REDEFINES stock aliases — zmb_perks_machine_loop (perk hum) and the entire wpn_smg_ppsh_fire_* chain — proving a map CSV can override stock sounds. Zone references only `sound,zm_alien_isolation` (the .szc itself is not committed/gitignored; the CSV in share/raw is the part the linker reads via the szc). Playback idioms: PLAY_LOCAL_SOUND helper = foreach player PlayLocalSound(alias) for 2d (with STOP_LOCAL_SOUND twin); ent PlaySound(alias) or PlaySoundAtPosition(alias, origin) for 3d.

- **Source:** MattFiler/zm_alien_isolation share/raw/sound/aliases/zm_alien_isolation.csv L1, L53-59, L208, L230-243; zone_source/zm_alien_isolation.zone L14; zm_alien_isolation.gsc L235-248
- **For our map:** Template rows for our .szc/CSV; overriding zmb_perks_machine_loop is exactly how we re-skin perk machine hums for the 9 cyber perks.

### Layered scripted ambience: shuffled playlists, notify-gated alarm loops, positional speakers

Three reusable loop shapes: (1) shuffled playlist — while(true) pick forwards/backwards order at 50% (randomintrange(1,100)>50), iterate 23 one-shot aliases with randomintrange(100,250)s gaps; (2) notify-gated loop — self waittill("start_alarms_at_towplatform"); self endon("stop_alarms_at_towplatform"); while(true){ PlaySoundAtPosition("<alias>_"+n, speakerEnt.origin); wait(period); } with one thread per speaker at staggered periods (1.97/4.724/2.438s) for phasing; (3) jukebox with pause flag — level.PauseSevastopolTourAudio bool checked each cycle, per-track hardcoded wait table, ent StopSound(currentAlias) to interrupt. Random arcade-machine stingers pick both emitter and alias by string concat (getEnt("gameroom_monitor_"+RandomIntRange(1,3))).

- **Source:** MattFiler/zm_alien_isolation usermaps/zm_alien_isolation/scripts/zm/hab_airport.gsc L208-255, L497-530, L410-435; eng_towplatform.gsc L374-404
- **For our map:** Drop-in ambience kit for cyber-city streetscape (holo-ad jingles, distant sirens, boss-phase alarms gated by our event notifies).

### Music easter eggs + round music states

EE songs: ent=Spawn("script_origin"); ent PlaySound(alias); mutex level.music_override=1; manual duration thread waits N seconds then level notify("sndSongDone"); waittill_either("end_game","sndSongDone") → ent StopSounds + Delete. Pre-activation hum: spawned tag_origin PlayLoopSound("zmb_meteor_loop",0.1) per trigger, StopLoopSound(1) on trigger. Round music: zm_audio::musicState_Create("round_start", PLAYTYPE_ROUND(3), "alias1"[, more aliases]) for states round_start/round_start_short/round_start_first/round_end/game_over/dog_start/dog_end/timer/power_on (PLAYTYPE defines: REJECT 1, QUEUE 2, ROUND 3, SPECIAL 4, GAMEEND 5). Background loop: tag_origin model PlayLoopSound(alias,1) on level notify "play_bg_music", StopLoopSound on "end_of_round", re-notify 38s after "start_of_round".

- **Source:** zm_nuked scripts/zm/classic_features/ee_music.gsc:23-191; scripts/zm/zm_nuked.gsc:243-357; scripts/zm/zm_nuketown_hd_amb.gsc:73-83
- **For our map:** Complete recipe for our map's music: registered round states plus collectible-triggered songs with a working mutex.

### Workshop sound config (.szc) shape

JSON: {"Name":"zm_nuked","GameMode":"mpl","IsCommon":false,"IsStandalone":true,"MapFile":"zm\\zm_nuked.map","Builds":["T7"],"Sources":[{"Type":"ALIAS","Name":"perk_sounds","Filename":"perk_sounds.csv","Specs":[]}, {"Type":"AMBIENT","Name":"zm_nuketown_hd","Filename":"zm_nuketown_hd.csv","Specs":["mpl_mod"]}, ...]} — one ALIAS source per alias CSV (music, perk_sounds, ee sounds, vox_language), AMBIENT type takes Specs ["mpl_mod"]. Main zone needs matching 'sound,zm_nuked'.

- **Source:** zm_nuked sound/zoneconfig/zm_nuked.szc:1-84
- **For our map:** Template to grow our single .szc into multiple alias CSVs (perk jingles, boss stingers, vox) for publish.

### Per-weapon-pack sound alias CSVs in the .szc

.szc Sources[] holds one ALIAS entry per content pack: {Type:"ALIAS",Name:"s4_weapons",Filename:"s4_weapons.csv",Specs:[]} — likewise t7_weapons_dlc.csv, perk_sounds.csv, trap_sounds.csv, abbey_music.csv, abbey_sfx.csv, flashlight.csv, zm_castle_vox.csv, plus an AMBIENT entry {Type:"AMBIENT",Filename:"ambient_mod.csv",Specs:["mpl_mod"]} and top-level "MusicFiles":["zm_abbey"]. GameMode is "mpl", IsStandalone true. The alias CSVs themselves live in sound_assets (not committed). Zone side just needs sound,zm_building. Player VO reuses a stock table: zm_audio::loadPlayerVoiceCategories("gamedata/audio/zm/zm_castle_vox.csv") with zone line stringtable,gamedata/audio/zm/zm_castle_vox.csv.

- **Source:** ohm-nabar/zm_building sound/zoneconfig/zm_building.szc:1-104; scripts/zm/zm_building.gsc:396-399; zone_source/zm_building.zone:47,50
- **For our map:** Pattern for our .szc: one alias CSV per feature (perks, weapons pack, boss, ambience) instead of one monolith, and free player-character VO by loading the stock castle vox table.

### Pooled announcer vox queue + mod-level sound zone

Queue per player: `level.pending_announcer_vox[entnum][]` appended by play_pooled_announcer_vox(aliasname); one drain thread per player (started on spawn, endon disconnect) plays `self playlocalsound(alias)` then waits 2s before the next — prevents announcer lines overlapping. Sound assets: alias CSV at share/raw/sound/aliases/ugxmbo3.csv (Template column UIN_MOD, FileSpec wav paths), wired by sound/zoneconfig/zm_mod.szc with `"Type":"ALIAS","Filename":"ugxmbo3.csv"` and empty MapFile, plus `sound,zm_mod` line in the zone.

- **Source:** treminaor/ugx-mod-bo3 ugxmod/scripts/zm/ugxm/ugxm_util.gsc:194-228; sound/zoneconfig/zm_mod.szc; share/raw/sound/aliases/ugxmbo3.csv; zone_source/zm_mod.zone:56
- **For our map:** Our announcer/boss vox needs exactly this serialization queue; the szc shape confirms our existing sound config approach.

## BOSS

### Stock Panzer/mechz in a usermap = ADVANCED, not drop-in (vs self-contained bosses)

The BO3 Panzer is the stock `mechz` (DLC1 / Der Eisendrache). Adding it to a base usermap is the most failure-prone AI add: 10/11 clientfields are `VERSION_DLC1` (must be re-versioned to `VERSION_SHIP` in BOTH gsc+csc), the model/anim/FX assets aren't in a fresh install (come from Spiki's asset dump #3087 pw `Chungus4Prez`, or self-extract via Greyhound from the user's Origins/zm_tomb), a partial FX folder = FATAL linker abort, plus a documented attack-crash with no posted fix. The `set_zombie_var("mech_first_round")`/`can_spawn_mech()` API is a WaW/BO1 PORT name, NOT BO3 stock (native = the stock `mechz` archetype; our Panzer boss `_acc_boss_panzer.gsc` spawns it via `SpawnActor("archetype_zm_mechz_genesis", ...)`, not `zombie_utility::spawn_zombie` — `_acc_boss.gsc` itself does not spawn a mechz). Contrast: self-contained custom-aitype bosses (Spiki's **Brutus 2** #2875 = "drag and drop"; our NSZ Brutus = ~1 gdtdb run) are the EASY class. Full method + risk list: [research/BO3_Panzer_mechz_usermap_method.txt](research/BO3_Panzer_mechz_usermap_method.txt).

- **Source:** modme #3087 (Spiki dump) / #2875 (Brutus 2) / #3849 (FX fatal) / #3233 (XANIM fix) / #830 (clientfield parity); bo3explorer mechz_8gsc / version_8gsh; local stock `mechz.{gsc,csc,gsh}`.
- **For our map:** If we want THE Panzer it's a multi-session, crash-debugging job (Spiki's dump is the cleanest route); if we want "a cool boss easily," prefer a self-contained custom-aitype pack like Brutus 2.

### Drop-in custom-archetype boss (NSZ Brutus, BO2 port) for usermaps

NateSmithZombies' "NSZ BO2 Pack: Zombie Boss - Brutus" - a FULL custom archetype (model + anims + behavior tree + FX + GDT + sound + GSC) that, unlike stock `mechz`, ships its own redistributable assets and therefore spawns/fights in a usermap. API: `#using scripts\_NSZ\nsz_brutus;`, `brutus::init()` (own round-spawn loop), `brutus::spawn_brutus()` (manual spawn); config via `level.min_brutus_round` / `max_brutus_round` / `max_brutus` / `brutus_lock_machines` (the upstream pack also has a `level.nsz_debug` trace toggle — removed from our vendored copy 2026-07-16, debug rides `level.acc_dev`). Known issues: usermaps-only, PaP abilities disabled while alive, traversal nodes must be marked to ignore him, co-op high-round spawn crashes without spawn-delay staggering. Full dossier + audit checklist (used during our now-complete adoption): [research/NateSmithZombies_Brutus_BO2_boss_pack.txt](research/NateSmithZombies_Brutus_BO2_boss_pack.txt).

- **Source:** modme thread #765 (forum.modme.co/wiki/threads/765.html) + UGX mod #10676; download via the MEGA link there. v1.0.4 stable.
- **For our map:** ADOPTED and live — Brutus is one of our boss roster types (`_acc_boss_brutus.gsc` drives it; the pack ships at `scripts/_NSZ/nsz_brutus.gsc`). We call its spawn through the actor-only seam and drive it through OUR health bar / Mega-Bottle / boss-item / speed / HP pipeline (shared roster `level.acc_boss_roster_fn`), leaving its own round/lock/reward logic inert. The old SetModel-reskin fallback is moot.

### End-game sequence: level notify("end_game") after cutscene + zombie purge

ENG_TOWPLATFORM_ENDING_CUTSCENE: level thread lui::prime_movie(id); foreach player FreezeControls(true); lui::screen_fade_out(1); level thread lui::play_movie_with_timeout(id, "fullscreen", 36, true); stop lingering music via per-player StopLocalSound(alias); purge zombies: zombies=GetAiTeamArray("axis"); foreach: zombie StopSounds(); zombie dodamage(zombie.health+666, zombie.origin); wait(30); level notify("end_game") — the single stock-recognized signal that triggers BO3 zombies game-over/intermission flow. No RecordMapEvent anywhere in the map. All-players-present gate before this: poll player IsTouching(airlockZone) vs count of non-spectator players; airlockZone is a NotSolid()'d script_brushmodel 'tow_airlock_zone'.

- **Source:** MattFiler/zm_alien_isolation usermaps/zm_alien_isolation/scripts/zm/eng_towplatform.gsc L172-244; stock signatures verified in zeroy99/bo3_modtools scripts/shared/lui_shared.gsc L192/336
- **For our map:** Our buyable-ending / boss-kill finale should end with exactly: freeze, fade/movie, zombie purge via dodamage(health+666), then level notify("end_game").

### Endgame horde-mode pacing overrides (no rounds, capped AI, no dogs, no failsafe)

On entering the finale area: zombie_utility::set_zombie_var("zombie_use_failsafe", false); level.next_dog_round = 9999; level.zombie_ai_limit = N scaled by player count (9/9/8/7, later raised to 12/11/10/9 for the climax); level.round_wait_func = &round_wait_override (custom function pointer — loops wait(1) until !(level.zombie_total>0 || level.intermission) or level flag::get("end_round_wait"), removing inter-round downtime); level.zombie_vars["zombie_between_round_time"]=0; level.zombie_round_start_delay=0; spawn faucet toggled purely with SetDvar("ai_disableSpawn","1"/"0") around scripted beats (notify "ayz_should_enable_zombies" re-opens it).

- **Source:** MattFiler/zm_alien_isolation usermaps/zm_alien_isolation/scripts/zm/eng_towplatform.gsc L17-36, L296-349
- **For our map:** Exact level-field set for our boss fight and Overclock 'lockdown events': continuous pressure instead of rounds, with co-op-scaled AI caps.

### Special-round subsystem fork (3-variant hellhound rounds)

Fork stock _zm_ai_dogs into own namespace. Round takeover: tracker thread loops 'level waittill("between_round_over")'; on trigger round it saves level.round_spawn_func/level.round_wait_func, calls dog_round_start() (flag::set "dog_round"/"special_round"/"dog_clips", SetDvar ai_meleeRange 100, music state), then sets level.round_spawn_func=&dog_round_spawning, level.round_wait_func=&dog_round_wait_func; next between_round_over with flag set restores the saved funcs. round_dog_by_script() forces one on demand. Spawning: single spawner ent (script_noteworthy 'zombie_dog_spawner'), spawn locations from level.zm_loc_types["dog_location"] structs filtered 400-1000 units from least-hunted player (.hunted_by counter). Variant system: flags zombie_dog_default/elec/nova; define_dog_type() randomizes among set flags into self.type_dog; 4-bit actor clientfield "dog_nuked_fx" (1/2/3) drives client eyes (self._eyeglow_fx_override + zm::createZombieEyes + mapshaderconstant) and PlayFxOnTag(trail,self,"j_spine2"). On-death AoE: elec death does players SetElectrified(3) + zm_perks::lose_random_perk() + RadiusDamage, then trigger_radius gas field for 7s checking IsTouching; nova does ShellShock+SetBlur gas. dog_clip_monitor(): GetEntArray("dog_clips","targetname") ConnectPaths normally, DisconnectPaths while flag 'dog_clips' set and any 'zombie_dog' alive. End-of-round: last dog death sets level.last_dog_origin and notifies 'last_ai_down' → drop full_ammo there. special_dog_spawn(num,spawners) spawns dogs OUTSIDE round logic (caps at 9 alive).

- **Source:** zm_nuked scripts/zm/_zm_ai_dogs_nuked.gsc:55-1459; _zm_ai_dogs_nuked.gsh:1-37; _zm_ai_dogs_nuked.csc:26-78
- **For our map:** Blueprint for our custom boss: round_spawn_func/round_wait_func swap for boss rounds, variant-by-clientfield FX, AoE deaths, and special_dog_spawn shows mid-round minion injection.

### Scripted multi-phase live event (earth_blowup) with skybox swap

Long thread: poll level.round_number>=26 and a code flag; SetDvar("ai_disableSpawn",1); staged VO via subtitle func + timed waits; rockets = vehicle ents with tag_origin FX riders (PlayFXOnTag trail) launched on GetVehicleNode paths via LinkTo(node,"tag_origin")+AttachPath+StartPath+waittill("reached_end_node"); climax: PlayFx explosions at named structs (fx_nuke/fx_nuke_light/fx_nukeshock_position), player StartFadingBlur(7,3), level clientfield::set("setup_skybox",2) + level util::set_lighting_state(1) + exploder::exploder("nuke_fx") + earthquake(0.6,8,org,1000000); re-enable spawns; set flags 'aftermath'/'spawn_zombies'. Author notes the simultaneous PlayFx burst freezes the game seconds — batch or stagger heavy FX.

- **Source:** zm_nuked scripts/zm/zm_nuked.gsc:692-831
- **For our map:** Phase-transition template for our boss fight (arena state change + skybox/fog/lighting swap mid-match), including the documented FX-freeze pitfall.

### Entity-driven arena boss (attack patterns, no AI actor)

Boss = scripted attack director over pre-placed ent arrays sorted by script_int: level.laser_squares_warning/fire = array::sort_by_script_int(GetEntArray("ee_laser_square_yellow"/"_green","targetname"),true); same for ee_laser_pillar, ee_laser_beam_green, ee_laser_damage trigger hitboxes, ee_antimatter_strike_yellow/green/hitbox, ee_cloak_model/ee_cloak_damage. Fight starts from trigger ee_start_fight. boss_fight() loop picks attacks by dynamic weights (calculate_weights avoids repeating last attack); each attack = show warning ents (yellow), wait telegraph, swap to damage ents (green) + enable damage trigs; player damage applied via the level damage_adjustment callback and per-attack iframe threads (reset_strike_iframes, laser_iframes). Hit feedback to players via hitmarker()/playHitSound.

- **Source:** ohm-nabar/zm_building scripts/zm/zm_abbey_boss.gsc:40-58,108,148-260,515-560,682-719
- **For our map:** A shipped pattern for our custom boss that needs zero animation/AI assets: telegraphed warning->damage entity pairs, script_int-ordered arrays, weighted attack selection — perfect for a greybox-stage boss.

### Game-end override + forced solo-revive (extra-lives systems)

`level._game_module_game_end_check = &f` (self = downed player): return false to keep the game alive when all players are down (stock _zm.gsc:5392). UGX pairs it with `level.force_solo_quick_revive = true` (stock _zm.gsc:3015/5394 grants solo-revive behavior in coop), `self.lives = 9999`, and SetPerk(PERK_QUICK_REVIVE) while `self.chaos_self_revive_count > 0`. Also `level.whoswho_laststand_func = &f` (stock _zm.gsc:5375-5377) replaces last-stand entirely — their painkiller_respawn teleports to `struct::get_array("initial_spawn","script_noteworthy")[entnum]`, EnableInvulnerability + .ignoreme=true for 5+(round*0.35)s with black-flash HUD.

- **Source:** treminaor/ugx-mod-bo3 ugxmod/scripts/zm/ugxm/ugxm_chaosmode.gsc:225-252; ugxm_init.gsc:121-129,252-339; stock _zm.gsc:3015,5375-5394
- **For our map:** Gives our boss arena custom death rules (e.g. shard-purchased self-revives, respawn-at-checkpoint during boss) with verified stock hooks.

## EASTEREGG

### Keycard pickup: trigger_use targeting a deletable script_model

Map: trigger_use targetname 'keycard_trigger', cursorhint HINT_ACTIVATE, KVP "target" "keycard_model"; the item is script_model 'keycard_model' (model ayz_keycard, modelscale 2, client_server ServerSide). GSC: UPDATE_TRIGGER("Hold ^3[{+activate}]^7 to pick up keycard", key); key waittill("trigger", player); model = GetEnt(key.target,"targetname"); model delete(); key SetVisibleToAll(); key delete(); level.key_obtained=true; PLAY_LOCAL_SOUND pickup sting; iprintlnbold("Keycard acquired."); then re-hint the remote gated door trigger to "use keycard". Gated door loop: endgame_trigger waittill("trigger",player); if(!level.key_obtained){ playsound "zmb_no_cha_ching"; continue; } — a non-currency gate using the identical buy-loop skeleton.

- **Source:** MattFiler/zm_alien_isolation usermaps/zm_alien_isolation/scripts/zm/hab_airport.gsc L616-640 (keycard), L439-493 (gated door); map_source/zm/zm_alien_isolation.map L31408-31415 + L31396-31407
- **For our map:** Exact pattern for Data Shard physical pickups and any Cyberware part / quest item: trigger_use + target'd script_model, delete both on grab, flip a level flag consumed by gate loops.

### Scripted terminal/console interactions with model-swap state displays

Interactive prop = trigger_use + nearby script_models. Flow: UPDATE_TRIGGER(hint, trig); trig waittill("trigger", player); HIDE_TRIGGER(trig); state shown by SetModel swaps on monitor script_models (monitor_static_trace_orange -> wait(2.5) -> monitor_static_trace 'green') each with PlaySound sfx; physical button press = MoveTo(origin+(0.25,0,0),0.5,0.25,0.25) then back; big machinery = MoveTo over 35.87s with 10/25.87 accel/decel + Earthquake(0.08, 35, rumbleStruct.origin, 99999) for room-shake; per-character gating compares player.characterIndex (0 Dempsey/1 Nikolai/2 Richtofen/3 Takeo) inside the waittill loop, continue if wrong player. Helper set worth copying verbatim: UPDATE_TRIGGER/UPDATE_BUYABLE_TRIGGER/HIDE_TRIGGER/SHOW_TRIGGER built on setCursorHint("HINT_NOICON"), setHintString, SetVisibleToAll/SetInvisibleToAll; per-player variants SetVisibleToPlayer(p)/SetInvisibleToPlayer(p, true).

- **Source:** MattFiler/zm_alien_isolation usermaps/zm_alien_isolation/scripts/zm/eng_towplatform.gsc L248-280, L408-428, L119-129; zm_alien_isolation.gsc L294-314; bsp_torrens.gsc L201-253, L675-680
- **For our map:** Our Cyberware upgrade terminals and Data Shard kiosks are exactly this: trigger + SetModel state machine + the trigger-helper macros.

### Shootable + melee-filtered damage interactables

Shootables: model SetCanDamage(1); waittill("damage", amount, attacker, dir, org, mod); then Delete/SetModel(burnt variant)/PlayFX + level counter + level notify. Heads attached via GetTagOrigin/GetTagAngles("tag_base_d1_head") + LinkTo(parent, tag). Melee-only: trigger=Spawn("trigger_damage", pos, 0, radius, height); waittill("damage",...,mod,tagName,ModelName,Partname,weapon); continue unless mod=="MOD_MELEE"; guard isdefined(weapon)&&isdefined(weapon.name) (Purifier sends undefined weapon — documented crash) and check IsSubStr(weapon.name,"knife"); 'wait 1' between damage waits because Purifier streams damage continuously (documented hard-crash fix).

- **Source:** zm_nuked scripts/zm/new_features/ee_secondary.gsc:34-122; scripts/zm/classic_features/mannequins.gsc:35-115; scripts/zm/classic_features/vox_transmission.gsc:63-94; new_features/ee_tv_code.gsc:363-408
- **For our map:** Core input primitive for our Data Shard collectibles and quest steps; the two Purifier crash guards are hard-won facts to copy verbatim.

### Diegetic keypad code entry (no LUI)

TV script_model with custom tag: button=Spawn model at level.tv GetTagOrigin("tag_bouton_fdp"), LinkTo(tv,tag). Selection trigger increments button.position (0-9, RotatePitch(-36,0.1) per step, waittill "rotatedone"); validate trigger stores level.code_a..code_d from button.position, swapping TV screen model per digit entered (tv_nuked_on_code_1..4); after 4th, level notify("check_code"). Codes registered as competing threads add_code_to_tv(a,b,c,d,condition,result) each waiting on "check_code" and comparing; success swaps model tv_nuked_good + sets level flag; tv_fail thread detects no-match (level.code_possible unchanged 0.5s after check_code) → fail model + FX. Random per-run code: pick 1 of 13 (code,voice-line) tuples; melee the TV with tazer knuckles to hear the code VO.

- **Source:** zm_nuked scripts/zm/new_features/ee_tv_code.gsc:46-409
- **For our map:** World-space input device pattern for our Overclock terminal / Cyberware console without touching Lua, which we cannot test.

### Shootable-poster perk-limit increase with per-run randomization

Prefabs (map_source/_prefabs/perk_poster_prefabs/shootable_<perk>.map) pair a damage trigger targetname "<perk>_poster_trigger" with a poster model targetname "<perk>_poster". Script (38 lines, autoexec main): per perk type, GetEntArray both, x=RandomInt(trig.size), Delete() every non-chosen trigger+model pair (per-run random placement from N authored candidates); chosen trig waittill("trigger", player) → level.shootableEE++; when all 4 found: level.perk_purchase_limit++ (runtime-mutable; countryside proves init value level.perk_purchase_limit=15). Install: one #using + one scriptparsetree zone line + prefabs.

- **Source:** Fearlessninja98/Perk-Poster-Challenge share/raw/scripts/zm/zm_perk_poster_challenge.gsc L5-39, INSTRUCTIONS.txt; ColDog5044/zm_countryside scripts/zm/zm_countryside.gsc L285
- **For our map:** Two direct lifts: (1) the author-N-pick-1-delete-rest idiom is the cheapest map-side per-run randomization primitive for our randomized spawners/shops; (2) runtime perk_purchase_limit++ is how a Cyberware node can raise the perk cap.

## BOX

### Mystery box move control + restricted locations

level._zombiemode_custom_box_move_logic=&fn picks next level.chest_index: skip chests whose .script_noteworthy contains "restricted"; script_noteworthy "move<N>_chestX" forces a specific chest for move N; on wraparound array::randomize(level.chests) avoiding repeat. Fire-sale spawn filter: level._zombiemode_check_firesale_loc_valid_func=&fn returning false when IsSubStr(self.script_noteworthy,"restricted"). Also level.random_pandora_box_start=true for random first box.

- **Source:** zm_nuked scripts/zm/zm_nuked.gsc:140-144,405,444-522; stock _zm_magicbox.gsc:1065-1067
- **For our map:** Lets our per-run randomization seed the first box location and dynamically exclude locked zones from box moves/fire sales.

### Mystery box gated on per-zone power flags (tiny stock _zm_magicbox patch)

Only 3 edits to stock _zm_magicbox.gsc: (1) init: level.abbey_box_generators["chest_1"]=2 etc. mapping each chest's script_noteworthy to a generator number; (2) in trigger setup: self.unitrigger_stub.script_noteworthy = self.script_noteworthy (stock loses the chest id on the unitrigger); (3) in the visibility func: generator=level.abbey_box_generators[self.script_noteworthy]; if(!(level flag::exists("power_on"+generator) && flag::get(...))) visible=false. Power flags power_on1..power_on4 are custom flags set by generator activation, which also Delete()s 'boxcage_qN' targetname brush ents physically caging each box quadrant until powered. Box price changed by precaching alternate triggerstrings: #precache("triggerstring","ZOMBIE_RANDOM_WEAPON_COST","950"). Midgame box-pool injection: level.zombie_weapons[GetWeapon(name)].is_in_box = 1.

- **Source:** ohm-nabar/zm_building scripts/zm/_zm_magicbox.gsc:33-34,90-113,325,413-419; scripts/zm/zm_bloodgenerator.gsc:102-105,turn_generator_on (boxcage Delete loop); scripts/Sphynx/_zm_sphynx_util.gsc:99-101
- **For our map:** Direct template for Overclock/zone-gated box access: keep stock magicbox, patch only the visibility func against our own flags; is_in_box=1 enables per-run randomized box pools.

### Live box-location map HUD via world clientfields

clientfield::register("world","boxLightToggle1..4",VERSION_SHIP,4,"int") + "boxLightFlashToggle1..4" (2-bit). Server loop reads cur_chest=level.chests[level.chest_index]; index=lookup[cur_chest.script_noteworthy]; level clientfield::set("boxLightToggle"+n,index); on level flag::wait_till("moving_chest_now") sets flash=1 until flag clears; during fire sale (level.zombie_vars["zombie_powerup_fire_sale_on"]) sets index=10/flash=2 (all-boxes state). Client side lights up lamp models on physical map-board ents (targetname abbey_box_map, script_int = quadrant).

- **Source:** ohm-nabar/zm_building scripts/zm/zm_abbey_box_map.gsc:16-119
- **For our map:** Reusable for any 'where is the thing now' world indicator (box location, boss zone, active Overclock terminal): world clientfields + level.chests/level.chest_index are the stock state to read.

### Kill switches for box / wallbuys / gobblegum / PaP

Magic box: foreach `level.chests` → `zm_unitrigger::unregister_unitrigger(chest.unitrigger_stub)`, `chest.pandora_light delete()`, `chest.zbarrier clientfield::set("magicbox_closed_glow", false)`. Wallbuys: `level.func_override_wallbuy_prompt = &f(player)` where self has .stub — set `self.stub.cursor_hint = "HINT_NONE"` and return false (stock dispatch _zm_weapons.gsc:1194). Gobblegum: GetEntArray("bgb_machine_use","targetname") → unregister each .unitrigger_stub. PaP: `level.pack_a_punch.power_on_callback = &f` and inside it `getEnt(self.targetname,"target") TriggerEnable(false)`.

- **Source:** treminaor/ugx-mod-bo3 ugxmod/scripts/zm/ugxm/ugxm_init.gsc:168-222,341-351; stock _zm_weapons.gsc:1194
- **For our map:** Per-run randomization can disable/enable purchase systems per Overclock; also the documented way to lock our box/PaP behind the boss event.

### Animated prop via custom animtree (UGX weapon box) + dynamic weapon world models

Custom animtree pipeline: ship `rawfile,animtrees/ugx_box_anims.atr` + `xanim,ugx_weapon_box_spin` in zone; in GSC `#using_animtree("ugx_box_anims")`, `#precache("xanim","ugx_weapon_box_spin")`, store `level.scr_anim["ugx_weapon_box_spin"] = %ugx_weapon_box_spin`; play with `model useanimtree(#animtree); model AnimScripted("notify_name", model.origin, model.angles, level.scr_anim[name])`; duration = `getAnimLength(anim)`. Show any gun on a prop: `spawn("script_model", model getTagOrigin("tag_weapon")+offset)`, `setModel(GetWeaponWorldModel(GetWeapon(weapon_name)))`, `LinkTo(model, "tag_weapon")`. Proximity open: any player within 200u. Wallbuy struct reading confirmed: `struct::get_array("weapon_upgrade","targetname")` with .zombie_weapon_upgrade and .target chain; costs via `zm_weapons::get_weapon_cost/get_ammo_cost/get_upgraded_ammo_cost(weapon)`.

- **Source:** treminaor/ugx-mod-bo3 ugxmod/scripts/zm/ugxm/ugxm_wallweapon.gsc:23-52,97-279; zone_source/zm_mod.zone:58-61; ugxmod/animtrees/ugx_box_anims.atr
- **For our map:** The animtree zone+GSC wiring is the recipe for any animated machine we add (craftable bench, boss door); GetWeaponWorldModel is how our randomized wallbuys can swap displayed guns at runtime.

## POWERUPS

### Zone-aware powerup drop veto via probe spawn

level.custom_zombie_powerup_drop=&fn(drop_point): powerup=zm_net::network_safe_spawn("powerup",1,"script_model",drop_point+(0,0,40)); can_drop=powerup zm_zonemgr::entity_in_active_zone(); powerup Delete(); return !can_drop (return true VETOES the drop). Stock calls it from _zm_powerups.gsc:588-590.

- **Source:** zm_nuked scripts/zm/zm_nuked.gsc:524-536
- **For our map:** Stops drops landing in our locked/out-of-play zones; the probe-spawn idiom generalizes to any 'is this point in an active zone' check.

### Script-spawned powerup with custom grab notify

powerup=zm_net::network_safe_spawn("powerup",1,"script_model",pos+(0,40,0)); powerup.grabbed_level_notify="magic_door_power_up_grabbed" (level notify fired on grab); powerup zm_powerups::powerup_setup(name,team,location); thread powerup_wobble(); thread powerup_grab(team); thread powerup_move(). Nuked cycles a 5-powerup list behind a door, replacing (Delete) the old one each clock tick.

- **Source:** zm_nuked scripts/zm/classic_features/clock_nuked.gsc:62-108; scripts/zm/nuked_utility.gsc:237-250
- **For our map:** Exactly what our Data Shard pickups and quest rewards need: full powerup lifecycle without a zombie death.

### Soul-generator power system replacing the central power switch

Four 'blood generators' each own a quadrant: flags power_on1..4 (flag::init in system init) gate perks/box/teleporter instead of stock "power_on". Activation (turn_generator_on("generatorN")) sets the flag, Delete()s boxcage_qN cage brushes, appends to level.active_generators[], destroys per-player HUD indicators, fires player LUINotifyEvent(&"generator_activated",1,idx) and level notify(#"generator_activated"). Quick Revive kept usable pre-power via level.initial_quick_revive_power_off=true in main. Visual state via swapped xmodels on mainframe ents (blood_mainframe/blood_computer targetnames, offline/online/_s/_ms model variants all listed in zone).

- **Source:** ohm-nabar/zm_building scripts/zm/zm_bloodgenerator.gsc:100-160,536-540,turn_generator_on; scripts/zm/zm_building.gsc:151; zone_source/zm_building.zone:657-675
- **For our map:** Template for our per-zone power/Overclock nodes: N custom flags instead of one power_on, with each subsystem patched to wait on its zone's flag (we already know power_on is a flag — this generalizes it).

### Complete custom powerup recipe (register + drop-gate + timed effect framework)

Per powerup: `zm_powerups::register_powerup(name, &grab_func)` then `zm_powerups::add_zombie_powerup(name, model_name, hint_string, &func_should_drop, POWERUP_ONLY_AFFECTS_GRABBER, !POWERUP_ANY_TEAM, !POWERUP_ZOMBIE_GRABBABLE, fx, client_field_name, time_name, on_name, VERSION_SHIP, player_specific)` (stock sigs verified _zm_powerups.gsc:477,1955). CAVEAT: add_zombie_powerup early-returns if `level.zombie_include_powerups` is defined and the name isn't in it — call `zm_powerups::include_zombie_powerup(name)` first on a map that builds an include list. Grab func: self = powerup struct, arg = player, MUST NOT wait (breaks powerup deletion) — thread the real work. Their generic_powerup_give(name, player, time, &effect_func, &loop_func): effect_func(true/false) toggles, optional loop_func runs every server frame (e.g. terminator refills clip via `SetWeaponAmmoClip(cw, cw.clipSize)`); re-grab stacks duration via `player.ugxm_powerup_times[name] += time`. Effects use engine per-player fields: `self.personal_instakill = true` (killshot), `SetMoveSpeedScale(1.2)`, `EnableInvulnerability()`. Drop gating per gamemode = should_drop funcs reading the settings registry; remove stock drops with `zm_powerups::powerup_remove_from_regular_drops("double_points")` etc (must run in main, not init). Stock models reusable: p7_zm_power_up_carpenter, p7_zm_power_up_double_points, p7_zm_der_spine.

- **Source:** treminaor/ugx-mod-bo3 ugxmod/scripts/zm/ugxm/ugxm_powerups.gsc:54-142,191-378; stock _zm_powerups.gsc:477-479,562,572,1955
- **For our map:** Direct recipe for our custom powerups (REQUIREMENTS has Data-Shard drops); the include_zombie_powerup caveat matters because our map template builds an include list.

### Custom powerup registration (drop-type API)

In REGISTER_SYSTEM __init__: zm_powerups::register_powerup("free_perk", &grab_fn) — grab_fn(player) runs with self=powerup ent; zm_powerups::add_zombie_powerup("free_perk", "zombie_pickup_perk_bottle" /*world model*/, &"ZOMBIE_POWERUP_FREE_PERK", &zm_powerups::func_should_never_drop /*random-drop eligibility func*/, !POWERUP_ONLY_AFFECTS_GRABBER, !POWERUP_ANY_TEAM, !POWERUP_ZOMBIE_GRABBABLE) — macros from scripts/zm/_zm_powerups.gsh; precache the hint string. Give-random-perk helper exists: player zm_perk_utility::give_random_perk(). Guard players with laststand::player_is_in_laststand() and sessionstate=="spectator" checks before awarding.

- **Source:** ColDog5044/zm_countryside scripts/zm/_zm_powerup_free_perk.gsc:34-74
- **For our map:** Exact registration path for Data Shards as a custom zombie drop (model + grab callback that increments our shard wallet instead of score).

## OPTIMIZATION

### Shipped performance budget: 3 giant umbra volumes, lightingquality 4096, 23 tuned reflection probes

Worldspawn: "lightingquality" "4096", "umbra_prime_depth" "1", "numOmniShadowSlices" "24", "numSpotShadowSlices" "64", "samplescale" "1", "lodbias" "default". Occlusion: only THREE umbra_volume brush entities total — each a single huge box wrapping one whole discrete play area (the three areas are placed far apart in the void, e.g. Torrens at z=+11778, Tow Platform at z=-14200, so each umbra box fully isolates its area). Reflection: 23 reflection_probe point entities, roughly one per room, uniform KVPs: "ao_range" "38", "ao_strength_double_sided" "1", "brightnessAdjust" "-5", "evcomp" "-5", "resolution" "8x".

- **Source:** MattFiler/zm_alien_isolation map_source/zm/zm_alien_isolation.map L9-29 (worldspawn), L21547-21558 + L31498-31509 (umbra), L24678-24714 (probes); counts via grep: 3 umbra_volume, 23 reflection_probe
- **For our map:** Concrete numbers for our greybox: one umbra box per zone cluster is enough for a shipped map; copy the probe KVP set verbatim.

### zombie_total_subtract bookkeeping for scripted kills

When script kills a zombie outside normal flow: level.zombie_total++; level.zombie_total_subtract++; then self DoDamage(self.health+100, origin) — keeps round totals correct and lets HUD counters exclude scripted kills via (total_zombies_killed - zombie_total_subtract). Also SetDvar("ai_disableSpawn",1)/0 to pause all AI spawning during cinematics.

- **Source:** zm_nuked scripts/zm/zm_nuked_perks.gsc:592-603; scripts/zm/zm_nuked.gsc:724,779
- **For our map:** Needed whenever our boss fight, traps, or PhD Flopper kill zombies by script without skewing round progression.

### Zombie lifecycle hardening: no-target escape, melee-walk, unpush, health cap, AI limit scaling

(1) level.no_target_override=&f: when no player target, route zombie to a dog_location struct positioned away from players (level.zm_loc_types["dog_location"], pick where DistanceSquared(loc, self+600*away_vec) < player dist), validate via GetClosestPointOnNavMesh(pos,100) + SetGoal, else giant_cleanup::get_escape_position_in_current_zone()/get_escape_position() (requires zm_giant_cleanup_mgr module). (2) spawner::add_archetype_spawn_function("zombie",&f) thrice to: enable hb21 side-step behavior, force walk speed while ZombieBehavior::zombieShouldMeleeCondition (stores/restores .zombie_move_speed), and loop self PushActors(false) to stop zombie-shoving. (3) health cap: after round N, zombie_utility::set_zombie_var("zombie_health_increase_multiplier",0,1,2), or hard-set level.zombie_health on level waittill("zombie_total_set"). (4) per-player count limits each round: level.zombie_actor_limit/zombie_ai_limit = base + inc*GetPlayers().size on "start_of_round".

- **Source:** ohm-nabar/zm_building scripts/zm/zm_building.gsc:147-149,180,195-259,434-504; scripts/Sphynx/_zm_sphynx_util.gsc:138-176; scripts/zm/zm_high_round_health.gsc:8-16
- **For our map:** Five copy-ready stability/balance levers for our rounds module — especially no_target_override + cleanup manager, which prevents the classic 'zombies idle forever in cleared zones' usermap bug.

### Linker-emitted artifact formats (what a SUCCESSFUL link writes)

A successful link of usermap X emits under usermaps/X/zone_source/: (1) all/assetinfo/X.errorlog — first line `return <code>`, then `^1ERROR:` (red/fatal-ish) and `^3` (yellow/warning) lines each followed by an indented asset dependency chain (e.g. material -> weaponcamo -> weapon -> csv:zone_source/X.zone); (2) all/assetinfo/X.deps — `version,...` header, `ignore_missing_shipped,core_*` lines, then per-asset blocks `scriptparsetree,<path>` followed by tab-indented `file,<absolute path>,<timestamp>,` lines for EVERY file consumed (proves which gsh/gsc/prefab/gdt the linker actually read — countryside's shows vending_*_struct.map prefabs and share/raw scripts); (3) all/assetinfo/X.csv — per-asset memory `index,type,name,resident,streamed,parentStack`; (4) X_poolinfo.csv — `type,limit,total` asset pool budgets (xmodel 10240, xanim 25000, image 49152...); (5) X_bulletreport.csv — bad bullet-collision meshes (high-tri models flagged, e.g. perk machines at 252k tris); (6) X.badnodes — bad/useless pathnodes; (7) all/assetlist/X.csv — flat `type,name` of every asset in the FF; (8) all/scriptgdb/scripts/**/<name>.gsc.gdb — binary script debug DB per compiled script (magic \200GDB), one per scriptparsetree line, proving each script compiled.

- **Source:** ColDog5044/zm_countryside zone_source/all/assetinfo/zm_countryside.errorlog:1-9; zone_source/all/assetinfo/zm_countryside.deps:1-40; zone_source/all/assetinfo/zm_countryside_poolinfo.csv:1-12; zone_source/all/scriptgdb/scripts/lilrobot/_inspectable_weapons.gsc.gdb
- **For our map:** Our build checklist should assert: a `scriptgdb/*.gsc.gdb` exists for every one of our custom scripts (now ~60 `_acc_*.gsc` modules plus 4 `_acc_*.csc` under `scripts/zm/zm_abandoned_cyber_city/`, not the original 21), errorlog has no `^1ERROR`, and use `.deps` to verify the linker consumed our subfolder modules.

## DOORS

### Mover/destination naming conventions: <name>_move structs and same-name ent+struct pairing

Two conventions used: (1) destination struct named <entity_targetname>_move (door scripts do struct::get(name+"_move") for every door/clip); (2) same-targetname pairing — window shutters have a script_model AND a script_struct both targetname'd "window_close_script_N"; GetEnt finds the model, struct::get finds the struct (separate lookup namespaces), so mover+destination need only one name. Doors are always script_model (visible) + script_brushmodel clip moved in lockstep; status lights are script_models whose model is swapped to 'ayz_new_door_lights_open' AND MoveTo'd with the door. Defensive fallback shipped: if struct::get returns origin (0,0,0), fall back to a sibling struct (IsVec/undefined checks are unreliable on struct fields).

- **Source:** MattFiler/zm_alien_isolation usermaps/zm_alien_isolation/scripts/zm/hab_airport.gsc L64-79 (same-name pair), L259-307, L543-612 (fallback L562-569); map_source/_prefabs/zm_alien_isolation/spaceflight_terminal_buyableending_door.map
- **For our map:** Adopt the _move suffix and same-name ent/struct trick as our standard Radiant convention for all remaining buyable doors — it keeps targetname count low and scripts generic.

### Animated debris door reusing zm_blockers buy logic

Map side (inferred KVPs, .map not committed): script_model targetname 'floating_debris' with .target → trigger_use that carries script_flag (the zone-enter flag) and .target → clip; blockers 'explo_blocker_trig_<id>' paired with exploder 'blocker_fx_<id>'. Script: array::thread_all(debris,&generic_door); each: self UseAnimTree(#animtree) [#using_animtree("generic")], AnimScripted("optionalNotify",origin,angles,%idle_debris_anim) for hover idle; trig thread zm_blockers::debris_init() so STOCK handles price/hint/flag-set; then level flag::wait_till(trig.script_flag); PlayFX(level._effect["poltergeist"],origin); AnimScripted %rise_debris_anim; wait 2; self Delete(). Zone needs 'scriptbundle,floating_debris_sb' + the script.

- **Source:** zm_nuked scripts/zm/zm_nuked_floating_debris.gsc:34-131; zpkg:160-162
- **For our map:** Upgrade path for our 7 buyable doors: keep stock zm_blockers purchase flow but replace static brush motion with animated/FX'd removal.

### Variable door pricing by player count via live hint rewrite

For each ent in GetEntArray("zombie_door","targetname") (and "zombie_debris"): store original_price=self.zombie_cost, then loop every 0.05s: self.zombie_cost = original_price + 100*(GetPlayers().size-1); self zm_utility::set_hint_string(self,"default_buy_door",self.zombie_cost). Stock purchase code reads .zombie_cost at use time, so no other changes needed.

- **Source:** ohm-nabar/zm_building scripts/zm/zm_variable_pricing.gsc:64-105
- **For our map:** Drop-in for our buyable doors — same two fields (.zombie_cost + set_hint_string with "default_buy_door"/"default_buy_debris") support Overclock-driven dynamic pricing or per-run randomized door costs.

### Programmatic open-all-doors / power-on (debug + run modifiers)

Doors: every `trigger_use` classname ent with a defined .script_flag gets `notify("trigger", level, true)` (third arg = force); then set every flag in `getArrayKeys(level.zone_flags)` via flag::set; `zm_blockers::open_all_zbarriers()` opens all boarded windows; flag_blocker targetname ents need `flag::set(blocker.script_flag_wait)`. Power: `getEntArray("use_elec_switch","targetname")` → same notify("trigger", level, true). 0.001s wait between notifies to avoid same-frame pileup.

- **Source:** treminaor/ugx-mod-bo3 ugxmod/scripts/zm/ugxm/ugxm_util.gsc:45-100
- **For our map:** Instant debug command for testing our 7-zone greybox on the Windows box, and the mechanism for an Overclock that pre-opens random doors per run.

## ELEVATORS

### Fake-elevator transport: two distant elevator boxes + fade-teleport, full zombie handling

No moving platform. Two identical elevator interiors are built ~46k units apart; 'transport' = screen fade + SetOrigin. Map side: trigger_use targetname 'ending' (cursorhint HINT_ACTIVATE, brush faces textured 'trigger'); ride volume = plain script_brushmodel 'ayz_elevator_area' (NotSolid()'d at init, polled with player IsTouching); doors = script_model 'sft_elevator_sideone/sidetwo' (model elevator_door_side1/2) MoveTo'd to a shared script_struct 'sft_elevator_struct'; zombie seal = script_brushmodel 'sft_elevator_zombo_blocker_clip' with KVP "DYNAMICPATH" "1" and faces textured 'clip', plus twin '..._bullet' textured 'global_invisible_bullet_clip', both parked away and MoveTo(struct.origin, 0.001) to snap into place (DYNAMICPATH makes AI pathing respect the moved brush). Script flow (HAB_AIRPORT_ELEVATOR_PURCHASE/SEQUENCE): price scales by player count via switch (50000/45000/40000/35000); purchase loop = trigger waittill("trigger", player), reject if player.score < cost (playsound "zmb_no_cha_ching") or if players_in_zone != alive players (sessionstate != "spectator"), else zm_score::minus_to_player_score(cost) + "zmb_cha_ching"; then SetDvar("ai_disableSpawn","1"); close doors; snap blockers; drop POI failsafe struct + zm_utility::create_zombie_point_of_interest(5000,500,10000) with .attract_to_origin=true; level notify("ayz_elevator_moving") (drives FX thread); lui::screen_fade_out(1); foreach player SetOrigin(struct::get("ayz_elevator_destination_"+i).origin) + SetPlayerAngles; lui::screen_fade_in(1); level notify("ayz_elevator_arrived"); relocate all struct::get_array("initial_spawn_points") structs onto 'tpf_spawners_N' and 'player_respawn_point' onto 'tpf_spawners_9'; kill stragglers via GetAiTeamArray("axis") foreach zombie dodamage(zombie.health+666, zombie.origin); open far-side doors ('tpf_elevator_sideone/two' to '..._struct' positions) and far clips ('tpf_clip_side1/2' to '..._moveto' structs); zm_utility::deactivate_zombie_point_of_interest(); level notify("arrived_at_tow_platform"). Destination is its own zone: info_volume 'comms_volume' (script_noteworthy player_volume, target comms_zone_spawners), pre-registered via zm_zonemgr::add_adjacent_zone("endgame_zone","comms_volume","ayz_elevator_zoneswap").

- **Source:** MattFiler/zm_alien_isolation usermaps/zm_alien_isolation/scripts/zm/hab_airport.gsc L644-823; map_source/zm/zm_alien_isolation.map L31871-31885 (door), L42529-42585 (blockers), L15521-15538 (ending trigger), L31548-31560 (comms_volume); map_source/_prefabs/zm_alien_isolation/TOW_PLATFORM/elevator_full.map (destinations/doors/structs)
- **For our map:** Direct template for any boss-arena or endgame transport in our 7-zone map: a sealed 'transit pod' room far from the greybox + fade-teleport avoids all moving-geometry pathing risk.

## ZOMBIES

### Zombie head-variety fix via shipped .gscc + stub source

Commit compiled scripts/shared/xmodelalias_shared.gscc (binary) plus a 6-line stub .gsc declaring empty function add_head_models/add_helmet_models/set_helmet_head_override/apply for reference; zone line is 'scriptparsetree,scripts\shared\xmodelalias_shared.gscc' (note .gscc extension). Usage: xmodelalias::add_head_models("c_zom_dlc0_zom_solciv_body1", array("c_zom_dlc0_zom_head1".."head4")); zm_spawner::add_custom_zombie_spawn_logic(&xmodelalias::apply); zone also lists each head xmodel.

- **Source:** zm_nuked scripts/shared/xmodelalias_shared.gsc:1-6 (.gscc alongside); scripts/zm/zm_nuked.gsc:230-237; zpkg:147-152
- **For our map:** Two takeaways: zm_spawner::add_custom_zombie_spawn_logic is the per-zombie-spawn hook for our cyber-zombie cosmetics, and scriptparsetree accepts precompiled .gscc.

### Navmesh ignores ALL entity collision — script-placed props need DisconnectPaths() (2026-07-11)

`radiant\configs\navmesh.json` (Mod Tools install) is the navmesh generator's config: its `exclusions` list names `misc_model`, `script_model`, `script_brushmodel`, `dyn_model` (plus `clip_player`/`clip_missile`/`clip_weapon`/`clip_vehicle`/`clip_physics`/triggers/volumes) — cod2map64 generates walkable navmesh STRAIGHT THROUGH all of them, no matter how solid their collision is at runtime. Only worldspawn brushes (`clip` and `clip_ai` are NOT excluded) cut the mesh at compile, plus the dedicated carver materials `clip_carver` / `clip_navmesh_carver` / `clip_navvolume_carver` (carve nav only, no player collision; `clip_navmesh_carver` + `static_navmesh` are literal strings in cod2map64.exe; shipped prefab precedent `_prefabs/mp/mp_sector/.../mp_sector_aquaculture_bdg_west` uses `clip_navvolume_carver`). Community also sets Radiant KVP `static_navmesh = true` on clip brushes over props (UGX). The runtime half: a solid entity is invisible to pathing until you call `<ent> DisconnectPaths()` — stock does this for EVERY placed collision: perk machines (`_zm_perks.gsc:1551-1555` spawns `zm_collision_perks1` + DisconnectPaths), Pack-a-Punch (`_zm_pack_a_punch.gsc:114-118`), door slabs auto-disconnect iff classname==script_brushmodel (`_zm_blockers.gsc:272-275`), dogs' round clips toggle Connect/DisconnectPaths (`_zm_ai_dogs.gsc:806/819`). Official API doc: script_brushmodels "must have DYNAMICPATH set" for DisconnectPaths (UGX help-desk #10603 = the runtime error when missing). NO other dynamic nav primitive exists in T7 (zero stock hits for NavTrace/SpawnNavObstacle/BlockNavmesh). Symptom of getting this wrong: zombie paths onto the prop's footprint, grinds against the invisible clip until the target moves — and stock `factory_closest_player` (zm_usermap_ai.gsc) NEVER re-picks a merely-unreachable target (only invalid ones); the only stock recovery is round_spawn_failsafe suiciding zombies that moved <24 units in 30s (`zombie_utility.gsc:1805-1903`).

- **Source:** local install `radiant/configs/navmesh.json` + `bin/cod2map64.exe` strings + `map_source/zm/zm_giant.map` (worldspawn clip_ai precedent); tmp/bo3_stock_ref `_zm_perks.gsc`, `_zm_pack_a_punch.gsc`, `_zm_blockers.gsc`, `_zm_ai_dogs.gsc`, `zm_usermap_ai.gsc`, `zombie_utility.gsc`; UGX #13266/#13217/#10603; official API doc mirror marcogravbrot/bo3-mod-tools
- **For our map:** THE fix for zombies stuck on our GSC-spawned stations/caches/benches: our 30 `acc_clip_*` script_brushmodel prop clips (tools/add_prop_clips.js `brushmodel:true`) + 6 `acc_box_clip_*` give collision but never DisconnectPaths → navmesh runs through them. Call DisconnectPaths() on them at init (mirror stock perks), pairing Connect/DisconnectPaths anywhere we toggle Solid/NotSolid (box moves). Worldspawn `clip` clips (exo_station/reactor_plinth/perk_slot_vendor) are already correct.

## TELEPORTERS

### Castle-style teleporter network: pads, core, image-room blackout, linkto movement

Entities: trigger_teleport_pad_1..4 + trigger_teleport_core (targetnames), structs teleport_dest_<padIdx><slot> (4 standing slots per pad), teleport_room_0..3 (offscreen 'image rooms'), pad_N_wire structs chained by .target for power-wire fx, tele_help_N hint ents; link progress tracked by flags teleporter_pad_link_1..4 set while holding use at the core. Teleport: for each touching player activate visionset_mgr overlay pstfx ("zm_castle_teleport" postfxbundle in zone), disableweapons+disableOffhandWeapons, spawn script_origin at player, player LinkTo(it), move .origin to image_room slot with stance-dependent z offset (prone +49, crouch +20), FreezeControls(true), util::setClientSysState("levelNotify","black_box_start",player); wait 2; check destination slots not occupied (Distance2D < 16), then move to teleport_dest struct, black_box_end, unfreeze. Aftereffects = shellshock + FOV lerp + per-client vision threads.

- **Source:** ohm-nabar/zm_building scripts/zm/zm_abbey_teleporter.gsc:40-115,596-700,1036-1105; zone_source/zm_building.zone:613-616
- **For our map:** Complete entity naming + GSC choreography for our fast-travel/boss-arena teleporters; the LinkTo-script_origin + FreezeControls + image-room pattern avoids all collision/interp glitches that plague naive SetOrigin.

## CRAFTABLES

### World-pickup pattern: model + linked trigger_radius + useButtonPressed (dogtags, care packages, gun spots)

Pickup = `spawn("script_model", pos+(0,0,40))` + setModel; trigger = `spawn("trigger_radius", pos, 0, 50, 100)` (spawnflags, radius, height) with `setHintString("Press &&1 for ...")` (&&1 = use-key glyph), `setCursorHint("HINT_NOICON")` or `setCursorHint("HINT_WEAPON", weapon_ent)` to show a weapon icon; `EnableLinkTo(); LinkTo(model)`. Loop `trig waittill("trigger", player)` then gate on `player useButtonPressed()`. Proximity-only variant (dogtags): poll `distance(player.origin, ent.origin) < 64`. Juice: float anim via `rotateto((-60+randomint(120), yaw, -45+randomint(90)), t, t*0.5, t*0.5)` loop, spin via `rotateyaw(360,3,0,0)` every 2.9s. ALWAYS timeout-delete (45s) to avoid G-spawn overflow. Drop a physics-settled package: spawn at +60z then `physicsLaunch(origin,(0,0,0))`. Weapon pickups reuse `zm_magicbox::treasure_chest_ChooseWeightedRandomWeapon(player)` + `zm_utility::spawn_weapon_model(weapon, undefined, origin+(0,0,40), angles, undefined)`. FX ring: `SpawnFx("ui/fx_ctf_flag_base_team", origin, (0,0,1), (0,-1,0))` + `TriggerFx(fx, 0.001)`; sky beam: tag_origin script_model + playfxontag(level._effect["lght_marker"],...).

- **Source:** treminaor/ugx-mod-bo3 ugxmod/scripts/zm/ugxm/ugxm_chaosmode.gsc:979-1042,1295-1373,1488-1598
- **For our map:** This is the Data Shards physical-pickup implementation almost verbatim: spawn shard model, linked trigger, use-gate, float anim, timeout, waypoint icon — plus the FX-ring pattern for craftable bench highlights.

## Source codebase overviews

> **Note on the `local clone at …` / cached paths in this section:** these were scratch
> checkouts on the OLD dev box (user `Jordan Urbaez`, and `AppData\Local\Temp` clones that
> are ephemeral anyway). We moved to a NEW box (user `jorda`) on 2026-07-01, so those absolute
> paths no longer exist. They are kept only as mining provenance — re-clone from the GitHub URLs
> if a source needs re-reading. The stock-scripts mirror on the current box lives at
> `tmp/bo3_stock_ref` (per CLAUDE.md).

### MattFiler/zm_alien_isolation (GitHub, shipped Steam Workshop map Dec 2016; original scratch clone `tmp\zm_ai_full` on the old box)

Full BO3 mod-tools root for a shipped, objective-driven 3-act escape map (Torrens intro ship -> Sevastopol terminal -> Tow Platform endgame): 4 server GSC + 1 CSC, 4 LUI lua menus, 12-language localization, sound alias CSV, vision/LUT, full Radiant .map + prefabs, workshop.json. Binary assets (models/wavs/textures) are gitignored but every script/manifest/entity is present, making it the best known-good reference for scripted sequences, area transitions, end-game flow, LUI, localization, and publishing artifacts. Everything below was read from actual source in the clone and cross-verified against zeroy99/bo3_modtools stock scripts where stock APIs are involved.

Files worth reading first on a future deep-dive:
- C:\Users\Jordan Urbaez\Repositories\abandoned_cyber_city_zombies\tmp\zm_ai_full\usermaps\zm_alien_isolation\scripts\zm\hab_airport.gsc
- C:\Users\Jordan Urbaez\Repositories\abandoned_cyber_city_zombies\tmp\zm_ai_full\usermaps\zm_alien_isolation\scripts\zm\eng_towplatform.gsc
- C:\Users\Jordan Urbaez\Repositories\abandoned_cyber_city_zombies\tmp\zm_ai_full\usermaps\zm_alien_isolation\scripts\zm\bsp_torrens.gsc
- C:\Users\Jordan Urbaez\Repositories\abandoned_cyber_city_zombies\tmp\zm_ai_full\usermaps\zm_alien_isolation\scripts\zm\zm_alien_isolation.gsc
- C:\Users\Jordan Urbaez\Repositories\abandoned_cyber_city_zombies\tmp\zm_ai_full\usermaps\zm_alien_isolation\scripts\zm\zm_alien_isolation.csc
- C:\Users\Jordan Urbaez\Repositories\abandoned_cyber_city_zombies\tmp\zm_ai_full\usermaps\zm_alien_isolation\zone_source\zm_alien_isolation.zone
- C:\Users\Jordan Urbaez\Repositories\abandoned_cyber_city_zombies\tmp\zm_ai_full\usermaps\zm_alien_isolation\ui\uieditor\menus\hud\blackscreen.lua
- C:\Users\Jordan Urbaez\Repositories\abandoned_cyber_city_zombies\tmp\zm_ai_full\usermaps\zm_alien_isolation\ui\uieditor\menus\hud\popup_zm_alien_isolation.lua
- C:\Users\Jordan Urbaez\Repositories\abandoned_cyber_city_zombies\tmp\zm_ai_full\usermaps\zm_alien_isolation\english\localizedstrings\ayz.str
- C:\Users\Jordan Urbaez\Repositories\abandoned_cyber_city_zombies\tmp\zm_ai_full\share\raw\sound\aliases\zm_alien_isolation.csv
- C:\Users\Jordan Urbaez\Repositories\abandoned_cyber_city_zombies\tmp\zm_ai_full\usermaps\zm_alien_isolation\zone\workshop.json
- C:\Users\Jordan Urbaez\Repositories\abandoned_cyber_city_zombies\tmp\zm_ai_full\map_source\zm\zm_alien_isolation.map
- C:\Users\Jordan Urbaez\Repositories\abandoned_cyber_city_zombies\tmp\zm_ai_full\map_source\_prefabs\zm_alien_isolation\TOW_PLATFORM\elevator_full.map
- C:\Users\Jordan Urbaez\Repositories\abandoned_cyber_city_zombies\tmp\zm_ai_full\map_source\_prefabs\zm_alien_isolation\spaceflight_terminal_buyableending_door.map
- C:\Users\Jordan Urbaez\Repositories\abandoned_cyber_city_zombies\tmp\zm_ai_full\share\raw\vision\zm_alien_isolation.vision

### clixmods/zm_nuked @ tag 2025.10.11 (https://github.com/clixmods/zm_nuked, shallow-cloned to %TEMP%/zm_nuked; diffs verified against zeroy99/bo3_modtools stock mirror at tmp/bo3_stock_ref)

Official source-script release of the 2024/2025 shipped Workshop Nuketown Zombies remaster by clixmods. Contains ALL GSC/CSC (entry scripts, classic_features + new_features modules, a full forked dog-round subsystem, 9 stock-perk override copies), zone manifests (.zone + .zpkg include), .szc sound config, and a custom weapon-table CSV — but NO .map, NO GDTs, NO Lua/LUI (subtitle module was deliberately gutted to sound-only for mod compatibility). It is the best available reference for how a shipped usermap wires randomized perk placement, special rounds, clientfield-driven FX, and stock-script overrides; map-side KVPs must be inferred from GSC GetEnt/struct::get calls since the .map is absent.

Files worth reading first on a future deep-dive:
- C:/Users/JORDAN~1/AppData/Local/Temp/zm_nuked/scripts/zm/zm_nuked_perks.gsc
- C:/Users/JORDAN~1/AppData/Local/Temp/zm_nuked/scripts/zm/zm_nuked.gsc
- C:/Users/JORDAN~1/AppData/Local/Temp/zm_nuked/scripts/zm/_zm_ai_dogs_nuked.gsc
- C:/Users/JORDAN~1/AppData/Local/Temp/zm_nuked/zone_source/zm_nuked.zpkg
- C:/Users/JORDAN~1/AppData/Local/Temp/zm_nuked/scripts/zm/classic_features/pack_a_punch_from_the_sky.gsc
- C:/Users/JORDAN~1/AppData/Local/Temp/zm_nuked/scripts/zm/zm_nuked_floating_debris.gsc
- C:/Users/JORDAN~1/AppData/Local/Temp/zm_nuked/scripts/zm/new_features/ee_tv_code.gsc
- C:/Users/JORDAN~1/AppData/Local/Temp/zm_nuked/scripts/zm/nuked_utility.gsc
- C:/Users/JORDAN~1/AppData/Local/Temp/zm_nuked/scripts/zm/zm_nuked.csc
- C:/Users/JORDAN~1/AppData/Local/Temp/zm_nuked/gamedata/weapons/zm/zm_nuked_weapons.csv
- C:/Users/JORDAN~1/AppData/Local/Temp/zm_nuked/sound/zoneconfig/zm_nuked.szc

### ohm-nabar/zm_building (GitHub, HEAD 3d01097, 2025-09-22) — shipped BO3 custom zombies map "The Abbey" (internal name zm_abbey, dev greybox zm_building), mined via shallow clone

Mod-tools overlay repo (366 files) for a shipped two-map project: a dev greybox (zm_building) and the full Abbey map, switched at runtime by GetDvarString("ui_mapname"). No .map sources committed — only scripts/, ui/ (Lua HUD), gamedata/ (weapon+BGB CSVs), sound/zoneconfig, 13-language localizedstrings, and zone_source/ (708-line .zone + modular .zpkg includes). It is the best available reference for: huge ported-weapon rosters (44-row zm_levelcommon_weapons.csv override + 88 zone weapon lines), a dvar-driven console-command framework (Sphynx), generator-gated power/box systems, challenge-quest perk upgrades, GSC-driven LUI menus, and an itemized list of every unfinished spot in stock _zm_perk_electric_cherry — which directly de-risks our cherry-slot hijack.

Files worth reading first on a future deep-dive:
- ohm-nabar/zm_building: scripts/zm/script details.txt (annotated index of every system + credits)
- ohm-nabar/zm_building: zone_source/zm_building.zone (full asset-line taxonomy, 708 lines)
- ohm-nabar/zm_building: gamedata/weapons/zm/zm_levelcommon_weapons.csv (44-weapon roster spec)
- ohm-nabar/zm_building: scripts/zm/zm_building.gsc (entry script: every level hook a heavy map sets)
- ohm-nabar/zm_building: scripts/zm/_zm_perk_electric_cherry.gsc (diff vs stock = checklist for our cherry-slot hijack)
- ohm-nabar/zm_building: scripts/zm/zm_perk_upgrades.gsc + zm_perk_upgrades_effects.gsc (Mega perk upgrades)
- ohm-nabar/zm_building: scripts/Sphynx/commands/_zm_commands.gsc + .csc (dvar console commands + outline debug)
- ohm-nabar/zm_building: scripts/Sphynx/_zm_sphynx_util.gsc (2239-line utility grab bag: create_perk_loc, loadouts, unitrigger/progress bar, perk pause)
- ohm-nabar/zm_building: scripts/zm/_zm_magicbox.gsc (minimal power-gating patch pattern)
- ohm-nabar/zm_building: scripts/zm/zm_abbey_inventory.gsc + ui/uieditor/menus/hud/t7hud_zm_custom.lua + ui/uieditor/widgets/hud/room_manager.lua (GSC->clientuimodel->Lua HUD pipeline end to end)
- ohm-nabar/zm_building: scripts/zm/_zm_perk_phdlite.gsc/.gsh (custom perk registration template)
- ohm-nabar/zm_building: scripts/zm/zm_abbey_boss.gsc (entity-driven arena boss)
- ohm-nabar/zm_building: scripts/zm/zm_abbey_teleporter.gsc (pad network choreography)
- ohm-nabar/zm_building: scripts/zm/zm_pause.gsc + zm_solo_revive.gsc (laststand/world-pause override hooks)
- ohm-nabar/zm_building: english/localizedstrings/zm_abbey.str + sound/zoneconfig/zm_building.szc (localization + sound config formats)

### treminaor/ugx-mod-bo3 (GitHub, master @ 1aa6252, cloned to C:\Users\Jordan Urbaez\AppData\Local\Temp\ugx-mod-bo3)

UGX Mod BO3 Edition v0.1.2 alpha — a map-agnostic zombies MOD (not a usermap) that injects gamemodes (Classic/Gungame/Sharpshooter/Timed/Chaos), custom powerups, and HUD into any BO3 zombies map by overriding two stock scripts as load hooks. It is a shipped Workshop item (ID 791127116) with full source: ~7k lines of GSC/CSC, mod-type zone files, mod sound zone, and prebuilt FFs. Contrary to expectations it contains NO lua/LUI files and NO .str localization — every HUD is server-side hudelems and every string is a literal — making it the best open catalog of stock level.* function-pointer hooks and hudelem techniques, all of which I cross-verified against the zeroy99/bo3_modtools stock mirror.

Files worth reading first on a future deep-dive:
- C:\Users\Jordan Urbaez\AppData\Local\Temp\ugx-mod-bo3\ugxmod\scripts\zm\ugxm\ugxm_init.gsc
- C:\Users\Jordan Urbaez\AppData\Local\Temp\ugx-mod-bo3\ugxmod\scripts\zm\ugxm\ugxm_util.gsc
- C:\Users\Jordan Urbaez\AppData\Local\Temp\ugx-mod-bo3\ugxmod\scripts\zm\ugxm\ugxm_powerups.gsc
- C:\Users\Jordan Urbaez\AppData\Local\Temp\ugx-mod-bo3\ugxmod\scripts\zm\ugxm\ugxm_chaosmode.gsc
- C:\Users\Jordan Urbaez\AppData\Local\Temp\ugx-mod-bo3\ugxmod\scripts\zm\_zm_perk_electric_cherry_fixed.csc
- C:\Users\Jordan Urbaez\AppData\Local\Temp\ugx-mod-bo3\ugxmod\zone_source\zm_mod.zone
- C:\Users\Jordan Urbaez\AppData\Local\Temp\ugx-mod-bo3\ugxmod\scripts\zm\ugxm\ugxm_gungame.gsc
- C:\Users\Jordan Urbaez\AppData\Local\Temp\ugx-mod-bo3\ugxmod\scripts\zm\ugxm\ugxm_timedgp.gsc
- C:\Users\Jordan Urbaez\Repositories\abandoned_cyber_city_zombies\tmp\bo3_stock_ref\scripts\zm\_zm.gsc
- C:\Users\Jordan Urbaez\Repositories\abandoned_cyber_city_zombies\tmp\bo3_stock_ref\scripts\zm\_zm_powerups.gsc

### github.com/ColDog5044/zm_countryside (HEAD ac06b80) + github.com/FanaticSoftware/Skye-Weapon-Templates (rex/templates, 15 per-game ZM templates)

zm_countryside is a complete, compiled-and-shipped BO3 usermap repo that uniquely commits its linker-EMITTED artifacts (zone_source/all/assetinfo + assetlist + scriptgdb) alongside source: HarryBo21 perk modules (gsc/csc/gsh per perk), a Cold-War-style Lua-menu Wunderfizz, a CW Pack-a-Punch with AAT re-pack, a perk-refund system, and full LUI widgets. Skye-Weapon-Templates contains the pristine launcher ZM base template plus 14 per-game weapon-pack variants whose only deltas are inspect wiring, starting-weapon swaps, zone weapon lines, one szc ALIAS source, and a weapon-spec CSV — a perfect minimal diff showing exactly what adding a weapon pack requires. Together they are the best known-good reference for Lua-menu purchase stations (our Cyberware tree), script-built unitriggers, custom powerups (Data Shards), and for diagnosing our first Windows compile via real linker output formats.

Files worth reading first on a future deep-dive:
- C:/Users/Jordan Urbaez/AppData/Local/Temp/mine/countryside/scripts/zm/_t9_wonderfizz.gsc
- C:/Users/Jordan Urbaez/AppData/Local/Temp/mine/countryside/scripts/zm/zm_cwpap.gsc
- C:/Users/Jordan Urbaez/AppData/Local/Temp/mine/countryside/scripts/zm/_war_perk_return.gsc
- C:/Users/Jordan Urbaez/AppData/Local/Temp/mine/countryside/scripts/zm/zm_countryside.gsc
- C:/Users/Jordan Urbaez/AppData/Local/Temp/mine/countryside/zone_source/zm_countryside.zone
- C:/Users/Jordan Urbaez/AppData/Local/Temp/mine/countryside/zone_source/all/assetinfo/zm_countryside.errorlog
- C:/Users/Jordan Urbaez/AppData/Local/Temp/mine/countryside/zone_source/all/assetinfo/zm_countryside.deps
- C:/Users/Jordan Urbaez/AppData/Local/Temp/mine/countryside/ui/uieditor/widgets/Wonderfizz/MenuTabPerks.lua
- C:/Users/Jordan Urbaez/AppData/Local/Temp/mine/countryside/ui/uieditor/widgets/Wonderfizz/PerksUIListWidget.lua
- C:/Users/Jordan Urbaez/AppData/Local/Temp/mine/countryside/scripts/zm/_zm_perk_phdflopper.gsh
- C:/Users/Jordan Urbaez/AppData/Local/Temp/mine/skye/rex/templates/01. ZM - Base/usermaps/template/scripts/zm/template.gsc
- C:/Users/Jordan Urbaez/AppData/Local/Temp/mine/skye/rex/templates/14. ZM - BOCW/usermaps/template/zone_source/template.zone
- C:/Users/Jordan Urbaez/AppData/Local/Temp/mine/skye/rex/templates/12. ZM - MW19/usermaps/template/gamedata/weapons/zm/zm_levelcommon_weapons.csv

### GitHub multi-repo survey (2026-06-12): ColDog5044/zm_countryside (ships HarryBo21 Perks v3.1.0 source), treminaor/ugx-mod-bo3, Velaseriat/zombies_PHD, Polystyreeni/BO3, Fearlessninja98/Perk-Poster-Challenge, MakeCentsGaming/BO3_Modified_Scripts, dtzxporter/ModmeForum (Modme forum mirror), zeroy99/bo3_modtools (stock reference). Note: Wardogsk93/jbird632/Madgaz/ZombieKid164 have no BO3 perk repos on GitHub (their releases are mega.nz/forum only), but Wardog's perk-sellback and HarryBo21's full pack survive inside zm_countryside, and MikeyRay's PHD install recipe survives in the ModmeForum mirror.

Surveyed open-source BO3 custom-perk implementations across seven repos. The headline find is ColDog5044/zm_countryside — a complete shipped Workshop usermap that bundles the HarryBo21 Perks v3.1.0 framework in full source (utility framework + PHD Flopper, Electric Cherry, Tombstone, Who's Who, Vulture Aid, Widow's Wine, Elemental Pop, wonderfizz, plus the Lua HUD icon factory and the real .zone manifest). Second find: treminaor/ugx-mod-bo3 contains `_zm_perk_electric_cherry_fixed.gsc/.csc` — a finished, shipped Electric Cherry completion for BO3 (exactly what our cherry-slot hijack targets the unfinished stock module for). Together these provide verified known-good patterns for every layer of a custom perk: GSC registration, CSC clientfield/FX halves, machine entities/KVPs, zone lines, sound aliases, and HUD icons.

Files worth reading first on a future deep-dive:
- https://github.com/ColDog5044/zm_countryside/blob/main/scripts/zm/_zm_perk_utility.gsc
- https://github.com/ColDog5044/zm_countryside/blob/main/scripts/zm/_zm_perk_vulture_aid.gsc
- https://github.com/ColDog5044/zm_countryside/blob/main/scripts/zm/_zm_perk_electric_cherry.gsh
- https://github.com/ColDog5044/zm_countryside/blob/main/zone_source/zm_countryside.zone
- https://github.com/ColDog5044/zm_countryside/blob/main/ui/uieditor/widgets/HUD/ZM_Perks/ZMPerksContainerFactory.lua
- https://github.com/treminaor/ugx-mod-bo3/blob/master/ugxmod/scripts/zm/_zm_perk_electric_cherry_fixed.gsc
- https://github.com/treminaor/ugx-mod-bo3/blob/master/ugxmod/scripts/zm/_zm_perk_electric_cherry_fixed.csc
- https://github.com/Velaseriat/zombies_PHD/blob/master/Scripts/_zm_perk_phdflopper.gsc
- https://github.com/zeroy99/bo3_modtools/blob/master/scripts/zm/_zm_perks.gsc
- https://github.com/zeroy99/bo3_modtools/blob/master/scripts/zm/_zm_perks.gsh
- https://github.com/Polystyreeni/BO3/blob/master/scripts/zm/_zm_perk_timewarp.gsc
- https://github.com/dtzxporter/ModmeForum/blob/main/wiki/threads/3537.md
- https://github.com/Fearlessninja98/Perk-Poster-Challenge/blob/main/share/raw/scripts/zm/zm_perk_poster_challenge.gsc
- https://github.com/ColDog5044/zm_countryside/blob/main/scripts/zm/_t9_wonderfizz.gsc
- https://github.com/ColDog5044/zm_countryside/blob/main/scripts/zm/_war_perk_return.gsc

## Newly discovered source repos (verified by tree+file reads)

### [Owen-C137/Bo7-Sawblade-Trap-Bo3-Script-](https://github.com/Owen-C137/Bo7-Sawblade-Trap-Bo3-Script-)

- **What:** Complete drop-in buyable trap system (BO7-style sawblade) for BO3 mod tools usermaps: server GSC + Radiant prefabs + assets.
- **Completeness:** Verified full tree (99 files): Usermap_Files/scripts/zm/_zm_trap_sawblade.gsc (read in full, 666 lines), 6 prefab .map files under BO3_Root/map_source/_prefabs/_OwensAssets/bo7/sawblade/, model_export GDT, 4 xanim_bin, 2 xmodel_bin, 16 wav, .efx, .atr. No full map source (it is a kit, not a map).
- **Unique value:** Our repo has NO trap system; this is a known-good complete one. Map-side anatomy (read from sawblade_trap1.map L134-169): components are paired across targetnames by matching script_int — trigger_multiple {targetname=sawblade_trap_damage, script_int=1} (damage volume), script_model {targetname=sawblade_trap_model, model=sat_zm_sawblade_trap_set_fxanim, script_int=1}, and a lever pair sharing targetname=sawblade_trap_lever (trigger_use + script_model, disambiguated by classname check at gsc L168). GSC mechanisms: zm_traps::register_trap_damage("sawblade", &player_damage_sawblade, &zombie_damage_sawblade) (L49) so trap kills hit stock stats; purchase gate via zm_score::can_player_purchase / minus_to_player_score + zm_audio::create_and_play_dialog("general","outofmoney") (L261-268); power gate via level flag::get("power_on") / flag::wait_till (L182/457, matches our ledger); zombie LURE via self zm_utility::create_zombie_point_of_interest(dist, num_attractors, poi_value, true); self.attract_to_origin = 1 (L633-634) and zm_utility::deactivate_zombie_point_of_interest(true) on stop (L389) — the monkey-bomb POI API, reusable for any decoy/Cyberware aggro mechanic; hybrid kill detection = trigger_multiple waittill("trigger", ent) thread PLUS 0.2s poll of GetAITeamArray("axis") within radius for stationary zombies (L472-535) with self.marked_for_death dedupe flag; gore via gibserverutils::gibhead/gibleftarm/gibrightarm/giblegs then DoDamage(self.health+666, ..., "MOD_UNKNOWN") (L610-619); player knockback via SetVelocity + DoDamage (L559-568); lever state machine via hidepart/showpart on named bones; FX anchored by spawning tag_origin script_model LinkTo(model, bone) + playfxontag (L322-328); all tunables (cost/duration/cooldown/attract numbers) in #insert _zm_trap_sawblade.gsh. State fields: self._trap_in_use/_trap_cooling_down/.zombie_cost; notifies: trap_done, trap_stop_attraction, stop_blade_anim.

### [Scobalula/Bo3CWStyleItemDrops](https://github.com/Scobalula/Bo3CWStyleItemDrops)

- **What:** Cold War-style ground item/loot drop framework for BO3 zombies by Scobalula (Greyhound author): zombies drop weapons/items with rarity FX on kill.
- **Completeness:** Verified full tree (12 files): share/raw/scripts/zm/_zm_item_drops.gsc (read in full, 670 lines) + matching .csc + .gsh + source_data GDT + 4 rarity .efx. Drop-in mod, not a map.
- **Unique value:** THE blueprint for our Data Shards as physical world pickups. Registry pattern: register_item_drop(item_name, item, rarity, chance, on_item_picked_up_func, pickup_type, pickup_hint, on_spawn_item_model_func, on_item_dropped_func, on_item_cleaned_up_func, sounds...) storing SpawnStruct entries in level.zm_item_drop_registered_items with summed weights (L95-143), weighted roll in try_get_weighted_item_drop_info (L492). Death hook: zm_spawner::register_zombie_death_event_callback(&drop_item_callback) (L68) — same API our ledger mandates. Drop placement: PositionQuery_Source_Navigation(origin, min_radius, max_radius, half_height, inner_spacing) + array::randomize + zm_utility::groundpos_ignore_water_new (L459-470), validated by BulletTracePassed LOS and zm_utility::check_point_in_enabled_zone(v_to, true, level.active_zones) (L437-439) and overlap distance checks; arc toss via zm_utility::fake_physicslaunch(v_dest, 200) returning flight time (L587). Pickup options: per-player unitrigger stub (fields: .origin/.angles/.radius/.height/.script_unitrigger_type="unitrigger_radius_use"/.require_look_at/.trigger_target, plus .weapon_to_give/.cursor_hint="HINT_WEAPON"/.hint_string) registered via zm_unitrigger::unitrigger_force_per_player_triggers(stub, true) + register_static_unitrigger(stub, &dropped_item_trigger_think) (L196-229), or proximity DistanceSquared poll (L269). Rarity glow: clientfield::register("scriptmover", name, VERSION_SHIP, GetMinBitCountForNum(variants), "int") (L62) then ent clientfield::set(name, rarity) after util::wait_network_frame (L577-579). ~20 level.zm_item_drops_* tunables incl. function-pointer overrides (should_drop_item_override, try_calc_drop_location_override, calculate_custom_weights) — exactly the override-hook architecture our per-run randomization wants. Entity lifecycle notifies: zm_dropped_item_picked_up / zm_dropped_item_timed_out; cleanup unregisters unitrigger then Delete().

### [Resxt/T7-Scripts](https://github.com/Resxt/T7-Scripts)

- **What:** Curated BO3 mod tools GSC module collection (soul boxes, challenges system, buyable ending, utils), each with .gsh config + README documenting Radiant KVPs and zone lines.
- **Completeness:** Verified tree (5 .gsc + 4 .gsh + per-module READMEs): soulboxes/_soulboxes.gsc, challenges/_challenges.gsc + challenge_simon, ending/_ending.gsc, utils/_utils.gsc. Scripts-only kit; all three core modules read in full.
- **Unique value:** Three systems we lack, in clean REGISTER_SYSTEM_EX modules. SOUL BOXES (_soulboxes.gsc, 101 lines): Radiant = any script_model targetname="soulboxes"; zm_spawner::register_zombie_death_event_callback(&OnZombieKilled) with guard IS_TRUE(self.completed_emerging_into_playable_area) (L53) to ignore unspawned zombies; ArrayGetClosest(self.origin, level.soulboxes) + radius check; per-box .souls_collected counter; on fill: array::exclude from level.soulboxes, SetModel swap, completion hooks level.soulboxes_any_completed_func_data / level.soulboxes_all_completed_func_data invoked via util::new_func function-pointer-with-args pattern, and zm_spawner::deregister_zombie_death_event_callback when all done (L94) — the deregister call is a technique our ledger doesn't capture. Zone needs scriptparsetree for the .gsh too plus fx line (README L22-25). CHALLENGES (_challenges.gsc): triggers targetname="challenges_trigger"; script_noteworthy holds a comma-separated allowed-challenge list, one picked via StrTok+RandomInt per run (L56-57) and unreserved triggers draw randomly from level.challenges registry minus level.challenges_removed — a shipped per-run randomization pattern matching our Overclocks concept; level notify("challenge_completed")/("challenge_failed") protocol; progress UI via hud::createServerBar((r,g,b), w, h, ...) + hud::updateBar(pct) + createServerFontString (L167-188). BUYABLE ENDING (_ending.gsc): trigger targetname="ending_trigger", cost = ENDING_BASE_COST + ENDING_PER_PLAYER_COST * level.players.size (L51), partial co-op payments via ENDING_PART_COST decrementing level.ending_remaining_cost, SetHintString(&str, value) cost interpolation, level notify("end_game") to finish (L117).

### [kelson8/bo3-Zombies-Test-Map](https://github.com/kelson8/bo3-Zombies-Test-Map)

- **What:** Complete BO3 usermap source (zm_test_map) whose star feature is a working Cold-War-style Wonderfizz: a perk-purchase MENU built in LUI/Lua, opened from a GSC unitrigger.
- **Completeness:** Verified full tree (59 files): map_source/zm_test_map.map + 3 prefab .maps, zone_source/zm_test_map.zone + loc zone, sound/zoneconfig/zm_test_map.szc, entry gsc/csc/gsh, scripts/zm/_t9_wonderfizz.gsc (read in full), zm_elevator_functions.gsc (read), 8 Lua uieditor widgets/menus. Zone file read in full.
- **Unique value:** A verified GSC-to-LUI MENU bridge — the reference architecture for a Mega perk / weapon-upgrade menu (we now ship our own LUI: `_acc_lui.gsc/.csc` + `acc_hud.lua`, plus the live Data-Shard and Overclock systems in `_acc_data_shards.gsc` / `_acc_overclocks.gsc`; the Overclock terminal, not a menu, is our live upgrade path). Note: the Cyberware skill-TREE is a dormant module — `_acc_cyberware.gsc::init()` only spawns the kiosk / enables node purchase under `getdvarint("acc_cyberware_on",0)` (default 0, removed from play 2026-06-19) and its `client_init()` LUI screen is still a `// Stub for now.` placeholder, so no Cyberware menu ships today; this Wonderfizz bridge is what a re-enabled Cyberware/Mega UI would be built on. Mechanism (_t9_wonderfizz.gsc): #precache("menu", "WonderfizzMenuBase") + #precache("lui_menu_data", "cw_perk_buyables.owned_perks") (L40-41); machine = script_struct targetname="t9_wonderfizz" with target -> script_model (struct::get + GetEnt(perk.target,"targetname"), L89-90); interaction via perk zm_unitrigger::create_unitrigger(hint, 48, &visibility_and_update_prompt) + perk.s_unitrigger.inactive_reassess_time=0.05 + waittill("trigger_activated", player) (L114-118); open with player CloseMenu/OpenMenu("WonderfizzMenuBase") (L177-178); push state to Lua with self SetControllerUIModelValue("cw_perk_buyables.owned_perks", pipeDelimitedString) (L171); receive purchases with self waittill("menuresponse", menu, response) then StrTok(response, ".") -> [_, perkName, cost] (L208-227); grant via zm_perks::give_perk("specialty_"+name, false) after zm_score gate. Model load trick: SetModel on, WAIT_SERVER_FRAME, SetModel off to force-load both states (L93-95). Matching Lua lives in ui/uieditor/menus/Craftables/WonderfizzMenuBase.lua + Widgets/Wonderfizz/*. Zone file shows scriptparsetree lines for .gsh files (L22, 28-33) and an `include,db_wunderfizz` zone-include directive (L48) — a zone composition technique we don't use. Bonus: zm_elevator_functions.gsc = moving platform/doors via MoveZ with call buttons and documented targetnames (elevator_moving_platform, elevator_top/bottom_floor_doors, elevator_*_call_btn, elevator_*_platform_trigger).

### [Owen-C137/Aetherium-Hud-Bo7-Remake-](https://github.com/Owen-C137/Aetherium-Hud-Bo7-Remake-)

- **What:** Full custom zombies HUD replacement (BO7 Aetherium style) for BO3 usermaps: GSC + CSC + 40 Lua uieditor widgets (health bars, perks, points delta, kill feed, powerups, round counter, custom interaction prompts).
- **Completeness:** Verified full tree (207 files): USERMAPS/scripts/zm/_zm_aetherium_hud.gsc (read, 15.5KB) + .csc (read in full) + ui/uieditor menus/widgets Lua + model_export GDT + fonts + .str. Drop-in kit with install layout (DRAG_IN_BO3_ROOT / USERMAPS).
- **Unique value:** The complete server->client->Lua data pipeline behind our custom HUD (Data Shards counter, Overclock status; the Cyberware tree is dormant — see the kelson8 entry — so there are no live Cyberware indicators). This kit is ADOPTED — it is our shipped base HUD (`_zm_aetherium_hud.gsc/.csc` + `ui/uieditor/menus/hud/AetheriumHud.lua`, live since 2026-07-03; details below). CSC side (_zm_aetherium_hud.csc): clientfield::register("world", "player_health_"+i, VERSION_SHIP, 7, "float", &set_ui_model_value, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT) registered in a loop over GetDvarInt("com_maxclients") (L30-33); the callback signature (localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump) writes straight into LUI: setuimodelvalue(createuimodel(getuimodelforcontroller(localClientNum), fieldName), newVal) (L20-24); custom HUD loaded from CSC __init__ via LuiLoad("ui.uieditor.menus.HUD.AetheriumHud") (L39). Bit-packing trick: one 8-bit world int clientfield "player_states_packed" carries 4 players x 2-bit states (alive/downed/dead), unpacked with (newval >> 2*i) & 3 (csc L57-80) — directly applicable to broadcasting compact Overclock/Cyberware state. GSC side: per-player monitor thread sets level clientfield::set("player_health_"+GetEntityNumber(), float(health/maxhealth)) each WAIT_SERVER_FRAME with IS_EQUAL dedupe (gsc L86-108); kill feed hooks zm::register_zombie_damage_override_callback(&zombie_death_callback) (gsc L71). Also includes Lua replacements for every cursor-hint prompt type (PromptWallBuy/PromptPerks/PromptDoors/PromptMysteryBox/PromptPAP under ZM_CursorHint/Prompts/) — a catalogue of how stock hint UI models are named.
- **ADOPTED 2026-07-03 (same day as discovery)** — vendored + retargeted + built (fresh .ff, zero kit-related linker errors); full record in the CHANGELOG entry "AETHERIUM HUD adopted". Master kill-switch `level.acc_aetherium_hud` (_acc_lui.gsc). Key integration deltas vs the stock kit: perk row rewired to our accOwnedMask/accMegaMask masks + Ronan icons (Mega tint preserved), maxclients register loops pinned to 4, zm_weapon_ports art refs stripped, signatures off. The kit also settled two docs/22 unknowns: custom fonts DO have a shipped path (`ttf,` zone lines + `setTTF`), and the T7Hud_zm_factory menu-key redefinition is the working recipe for a full-HUD replacement (supersedes the old lui-menu-can-break-map-load fear — proven live in our build).
- **Adoption record (2026-07-03, clone at `..\Aetherium-Hud-Bo7-Remake` next to this repo):** adoption was the structural fix for our server-hudelem pool pressure (Aetherium uses ZERO hudelems; everything is clientfield→UI-model→LUI). It was a vendor-and-port job, not a drag-and-drop — the notes below are the completed integration record.
  - **License:** "free to use and modify … credit appreciated but not required" (README) — unlike the game-rip packs this CAN live in git. Credit Owen-C137 + Kingslayer Kyle, Shidouri, MadGaz in CREDITS.md.
  - **Payload:** USERMAPS side = 46 files / 484 KB (2 scripts, 42 Lua, 2 TTF fonts, 1 `.str`); asset side = 160 files / 49 MB PNGs + a 103-image GDT at `model_export\_OwensAssets\bo7\aetherium_hud\bo7_aetherium_hud.gdt`. GDT-inside-model_export has working precedent in our installs (`model_export\wpn_t7_arak.gdt` from the HB21 pack) — gdtdb indexes it.
  - **Attach mechanism / the one real conflict:** AetheriumHud.lua **redefines `LUI.createMenu.T7Hud_zm_factory`** — a wholesale replacement of the stock ZM HUD menu (ammo, points, round, perks, powerups, hints, pause menu, scoreboard, kill feed). Our `acc_hud.lua` is a separate additive overlay menu (`OpenLUIMenu("acc_hud")`), so they load side-by-side without a Lua collision — but visually that would give DOUBLE perk rows / powerup bars. Resolution (done): Aetherium is the base HUD, the duplicated acc_hud widgets were dropped/ported while our unique ones (shard counter, perk card, PaP tiers) stayed, and the retheme uses the repo's theme PNG variants toward our teal/magenta identity.
  - **No collisions found:** clientfield names (`player_health_*`, `player_states_packed`) unused by us; namespace `zm_aetherium_hud` free; kill feed uses `zm::register_zombie_damage_override_callback` (returns false = no override) while `_acc_damage` uses `register_actor_damage_callback` — both run.
  - **Install for OUR pipeline (differs from their README):** vendor the USERMAPS payload INTO the map folder in this repo (scripts/zm/, ui/, fonts/, localizedstrings/) so `sync_to_modtools.ps1` deploys it — their "copy to usermaps root" layout would be invisible to our robocopy-/MIR sync. Skip the `include,aetherium_hud` zpkg; inline its lines into our `.zone` (all standard types; `ttf,` + `localize,` are first-timers for us — verify at link).
  - **Hardcodes fixed during the port:** `CoD.UsermapName = "Weapon Ports"` in AetheriumHud.lua; pin the `GetDvarInt("com_maxclients")` register loops to 4 in BOTH .gsc and .csc (must match or clientfield mismatch); mappings (`Mappings/AetheriumPerks.lua`, `AetheriumWeapons.lua`, `AetheriumAAT.lua`, characters) know only stock content — our custom perks / Skye guns / custom powerups need entries (wiki pages on the README document the recipe).
  - **Verify-at-runtime list:** world-clientfield bit budget (+36 bits on top of our ~48 registrations — register-time assert will scream); custom `SetHintString` interactions flowing through their `PromptDefault`; kill-feed points math vs our `zm_score` usage; UI Error boxes (docs/19 trap — Lua compiles at link, APIs fail at load).
  - **No machine blockers (verified live 2026-07-03):** SAC is off, gdt.db fresh, and L3akMod is installed (`bin\libtiff64r.dll` = 432,640-byte L3akMod DLL) — the `rawfile,*.lua` lines will link. (Earlier setup-era notes claiming otherwise were stale; corrected in CLAUDE.md + memory the same day.)

### [Fearlessninja98/Perk-Poster-Challenge](https://github.com/Fearlessninja98/Perk-Poster-Challenge)

- **What:** Shootable easter-egg kit: 4 perk posters spawn at randomized locations; shooting all 4 raises the perk limit.
- **Completeness:** Verified full tree (22 files): share/raw/scripts/zm/zm_perk_poster_challenge.gsc (read in full, 39 lines), 4 prefab .map files (shootable_juggernog.map etc.), GDT, 4 xmodel_export + 4 xmodel_bin.
- **Unique value:** Smallest clean example of PER-RUN RANDOMIZED EE PLACEMENT — our map's per-run randomization pillar, map-side: author places N candidate trigger+model pairs (targetnames `<perk>_poster_trigger` / `<perk>_poster`), script keeps one via x=RandomInt(trig.size) and Deletes the rest (L16-27); completion counts level.shootableEE and rewards level.perk_purchase_limit++ (L32-34) — confirming perk_purchase_limit is the writable stock field for raising the perk cap (relevant to Mega perk upgrades). Ships the matching prefab .maps showing how a damage trigger is paired with a poster model, plus the GDT for poster materials.

### [carsongooch/BO3-GSC-Mod-Library](https://github.com/carsongooch/BO3-GSC-Mod-Library)

- **What:** Five usermap GSC scripts from the author's published maps: a multi-switch power door plus two maps' full easter-egg scripts (zm_eefs_dungeon, zm_nathans_crib).
- **Completeness:** Verified tree: 5 .gsc + README (scripts only, no map source). zm_power_door.gsc read in full (40 lines).
- **Unique value:** N-of-M gating pattern our buyable-door system could extend (e.g. activate K terminals to open a Cyberware vault): each trigger targetname="secret_door_trig" runs MonitorTrigger() -> UseTriggerRequireLookAt + SetHintString + waittill("trigger") -> Level notify("power_door_trig") then Delete()s itself; main() counts notifies until trigs.size reached (L12-15), then GetEnt("power_door"/"power_door_two"/"power_door_clip") -> MoveZ(-128,1) + clip Delete() (L18-25). Note it omits ConnectPaths — cross-check with PotatoClips fetchquest which does it correctly. The two EE scripts are complete map quest lines to mine for multi-step quest sequencing.

### [AndresTejeroMena/BO3ZMB_DonAndres666](https://github.com/AndresTejeroMena/BO3ZMB_DonAndres666)

- **What:** Map-specific GSC from a Workshop custom-maps author: per-perk soul challenges, arcade challenge, co-op riddle EE, troll perk machines, plus a GSC+CSC pair.
- **Completeness:** Verified tree: 8 .gsc + 1 .csc (BO3_Scripts/), no map source. zm_trollperkmachines.gsc (67KB) structurally skimmed via grep.
- **Unique value:** Shipped-map example of PERK-GATING VIA SOUL CHALLENGES (Mega perk upgrade earn-mechanic candidate): per perk, soul models getEnt("almas_su"/"almas_ec"/"almas_jg"/"almas_ww", "targetname") and the purchase trigger getEnt("get_su",...) stays locked until level waittill("almas_su_allgrowsouls") fires (zm_trollperkmachines.gsc L432-543 function-per-perk pattern); also zombie modifier triggers — slow zombies (SZ_trig) and sprinters via mpjw_make_sprinter (L424) showing zombie_utility speed overrides; zm_saw_breaking_brain.gsc/.csc is a small same-name GSC+CSC pair worth mirroring for our `.csc` client modules; zm_cooperativeriddle.gsc = multi-player simultaneous-interaction EE.

### [PotatoClips/potatoclips-bo3-scripts](https://github.com/PotatoClips/potatoclips-bo3-scripts)

- **What:** Generic, KVP-driven fetch-quest module (start -> find N items -> return -> reward) for BO3 usermaps.
- **Completeness:** Verified tree: scripts/zm/pc_fetchquest.gsc (read in full, 219 lines) + READMEs. Script-only.
- **Unique value:** Reusable QUEST-CHAIN-BY-TARGETNAME-CONVENTION engine (Data Shard collection quests): init("fetchquest_1", reward); entities are trigger_use targetnames `<kvp>_start` / `<kvp>_find` / `<kvp>_return` / `<kvp>_door`, each trigger's .target pointing at its script_model(s) (header L21-28); progression via level notify/waittill of kvp+"_start"/"_find"/"_return" with a findables counter in level.pc_fetchquest[targetname] (L83, 110-117); fan-out via array::thread_all(ents, &Handler, kvp). Its door-reward handler is the most complete door-open recipe found: self DisconnectPaths() while closed, flag::init(self.script_flag) then flag::set on open (enabling the zone's spawners), self NotSolid() + ConnectPaths(), then move clip's .target door models via MoveTo(origin + script_vector, 1) and delete the clip (L165-181) — KVPs script_flag, script_vector, script_noteworthy=move|rotate all honored, matching stock _zm_zonemgr expectations.

### [coolyer/zm_slots](https://github.com/coolyer/zm_slots)

- **What:** Slot-machine gambling minigame for BO3 maps (sibling repos coolyer/zm_blackjack and coolyer/zm_texasholdem add blackjack and Texas hold'em with GSC AI opponents).
- **Completeness:** Verified trees: zm_slots = zm_slots.gsc (22KB, first 100 lines read) + _custom/_coolyer/gambling/ui_gambling_icons.gdt + 11 icon PNGs; zm_texasholdem adds zm_texas_ai.gsc; zm_blackjack same layout. Script+GDT kits.
- **Unique value:** In-map minigame/gambling pattern (candidate for an Overclock-roll or Data Shard wager station): trigger_use targetname="slot_machine"; icon HUD done with #precache("material", "cherry"...) driven by a GDT of 2D materials — a server-driven icon HUD technique needing no Lua (L16-27); reward/odds architecture entirely in #define blocks (PRICE, PAIR_REWARD, CHANCE_THREE_IN_A_ROW, per-icon ODDS_* weights, USE_WEIGHTED_ODDS toggle, L33-69) — a tidy weighted-loot-table template; rewards span points/powerups/perks incl. reading PERKLIMITMAX vs perk limit. zm_texas_ai.gsc is a rare example of scripted non-combat AI turn logic in GSC.

### [AsteaFrostweb/BO3_Radio_Easteregg](https://github.com/AsteaFrostweb/BO3_Radio_Easteregg)

- **What:** Tiny shoot/melee-activated radio easter egg script.
- **Completeness:** Verified tree: _zm_radio_easteregg.gsc (read in full, 67 lines) + README. Single script.
- **Unique value:** Cleanest reference for DAMAGE-ACTIVATED world objects (shootable lore/intel triggers): trigger with targetname="radio", script_string = sound alias to play, script_int=1 = melee-only; key mechanism is self setcandamage(true) then the full 13-arg damage waittill signature — self waittill("damage", damage, player, dir, point, str_type, model, tag, part, w_weapon, flags, inflictor, chargeLevel) (L43) — plus melee filtering via str_type == "MOD_MELEE" || zm_utility::is_melee_weapon(w_weapon) (L50). That exact waittill arg order is hard-won knowledge worth recording.

### [marinesciencedude/BO3SoloEasterEggs](https://github.com/marinesciencedude/BO3SoloEasterEggs)

- **What:** Workshop MOD (not usermap) that patches stock maps' easter eggs to be completable solo, via per-map ffotd hook scripts.
- **Completeness:** Verified tree: scripts/zm/zm_cosmodrome_ffotd.gsc, zm_temple_ffotd.gsc, zone_source/zm_mod.zone. Mod-only.
- **Unique value:** Shows the MOD packaging variant we have not documented: zone_source/zm_mod.zone manifest for a mod (vs our usermap .zone) and the `zm_<mapname>_ffotd.gsc` filename hook that the engine auto-loads per map — useful if we ever ship side-mods (e.g. a standalone Cyberware mod) or want to hot-patch stock-map behavior for testing scripts on shipped maps without a compiled map of our own.

### [pistakilla/t7-gsc-scripts](https://github.com/pistakilla/t7-gsc-scripts)

- **What:** Compilation of BO3 zombies GSC utilities (free gobblegums, zombie counter + HP HUD, round timer), each in source/ and compiled/ form for shiversoftdev's t7-compiler injection.
- **Completeness:** Verified tree: 6 .gsc (3 systems x source+compiled) + per-system READMEs/screenshots. Injector-oriented, no zone/map files.
- **Unique value:** Lower priority (targets GSC injection into stock maps rather than mod tools builds), but the zombie-counter/HP HUD and round-timer scripts are compact references for server-side HUD elem patterns, and the repo demonstrates the source-vs-compiled (.gscc) workflow of the t7-compiler toolchain — relevant context for understanding community script distribution we may encounter when mining other kits.

### [shidouri/T7-GDT-Backup](https://github.com/shidouri/T7-GDT-Backup)

- **What:** Backup of all stock GDTs shipped with BO3 Mod Tools (8.7MB; sibling repo prov3ntus/stock-gdt-list holds their hashes).
- **Completeness:** Tree listing only (GDT dump; individual files not read — contents are the stock Mod Tools source_data GDTs).
- **Unique value:** Since our repo cannot compile locally, this gives greppable ground truth for GDT syntax and stock asset definitions (perk machine models, FX, materials) referenced by name in our map/zone files — same verification role zeroy99/bo3_modtools plays for scripts, but for the GDT/asset layer which none of our known sources cover (Skye templates ship only template GDTs).
- **GAP (verified 2026-06-14 research pass):** it does **NOT** contain stock weapon **stat** GDTs — it mirrors only what the tools ship, and the tools ship weapon **art** (camos/materials/models), never the `bulletweapon`/`grenadeweapon` stat defs. Its sole weapon-stat GDT is the template `smg_standard.gdt`. `prov3ntus/stock-gdt-list` is just a hash manifest (no files). So there is **no download** that hands you an editable stock `frag_grenade`/`ar_accurate` GDT.

### Weapon-GDT sourcing reality (verified 2026-06-14 research pass + live box)

The crux for every weapon-GDT perk magnitude (docs/21-31). Live box: `source_data` has 173
GDTs; the only `bulletweapon`-typed ones are 102 community `skye_*` ports + a template
`smg_standard.gdt`. **No stock weapon stat GDT exists to open or clone.** Consequences:

- **The Launcher has NO extractor** (File menu = New / Asset Editor / Open in Radiant /
  Export2Bin GUI). Earlier "Launcher → extract" guidance was WRONG.
- **GSC cannot mutate** `maxAmmo`/`clipSize`/`fireTime`/`gunKick*` at runtime — zero such
  assignments/builtins across the stock mirror; baked, read-only. Carry **count** is settable
  (`SetWeaponAmmoClip`/`SetWeaponAmmoStock`/`GiveMaxAmmo`) but clamps to the baked cap.
- A weapon GDT is necessarily **complete** (~800 fields; `["parent"]` chains only to a GDT you
  already own) — no partial single-field override of a stock gun.
- **To get a cloneable stat GDT:** (A) build on an **imported** gun (Skye port ships a full
  editable weaponfile GDT — the practical path), or (B) decompile a stock gun from the
  *running game* with **[Scobalula/HydraX](https://github.com/Scobalula/HydraX)** (`weapon`
  asset type; writes GDTs to an export `source_data`). HydraX caveat: documented history of
  incomplete weapon dumps (v3.8.0.0 "Fixes missing weapon data") — clone under a NEW name,
  validate one throwaway twin end-to-end before scaling, never overwrite stock.
- Field-name correction (from a real weaponfile GDT): recoil keys are `hipGunKick*` /
  `adsGunKick*` / `hipViewKick*` / `adsViewKick*` (NOT bare `gunKick*`); `fireTimeAkimbo` is
  **not** a confirmed BO3 field.

### Discovery method + gaps

METHOD: No gh CLI or GITHUB_TOKEN on this box, so GitHub code search (search/code) was unavailable (auth-required) and grep.app was blocked by a Vercel security checkpoint (both curl and WebFetch got 429/checkpoint pages). Worked within unauthenticated limits: ~30 queries against api.github.com/search/repositories (10/min bucket) across keyword angles (zm_ bo3, zombies map black ops 3, bo3 zombies gsc/script, custom zombies bo3, bo3 mod tools, t7 gsc, topic:black-ops-3, zone_source, zm_usermap, iwmap, bo3 easter egg, wonderfizz, bo3 teleporter/buildable/soul box, etc.), plus /users/<name>/repos listings for community authors (shippuden1592, Harrybo21, Abnormal202, Sphynxmods, coolyer, Owen-C137) and two WebSearch passes. VERIFICATION: every reported repo's full tree was fetched via api.github.com/repos/<r>/git/trees/HEAD?recursive=1 and the load-bearing source files were downloaded from raw.githubusercontent.com and read line-by-line (cached at C:\\Users\\Jordan Urbaez\\AppData\\Local\\Temp\\src\\ — sawblade.gsc, sawblade_trap1.map, item_drops.gsc, soulboxes.gsc+README, challenges.gsc, ending.gsc, t9_wonderfizz.gsc, zm_test_map.zone, aetherium.gsc/.csc, perk_poster.gsc, power_door.gsc, fetchquest.gsc, radio_ee.gsc, zm_slots.gsc, elevator.gsc, trollperks.gsc). All line numbers cited come from these reads, not memory. FALSE POSITIVES EXCLUDED after tree verification: RexTheWho/zm_zombies (PAYDAY 2 BeardLib mod), LouisRichard/ZombieRandomiser (C# desktop app), philkluge/BO3-ZMH_Server (JS), marcogravbrot/bo3-mod-tools (stock raw_scripts mirror, redundant with known zeroy99/bo3_modtools), mahrens1/tombofcorvius + lb249/dead-water + ttvcursedkfm-cmyk/bo3-zm-scripts (0KB/empty), shippuden1592 repos (WaW/BO1, not BO3), DoktorSAS/GSC + Apparition/Synergy/CabCon menus (injector mod menus, not map systems), Sandwichas tools + Owen-C137/Echo + KingslayerKyle/CoDCharacterTools (asset tooling, noted but not map source). NOTABLE NEGATIVE: no additional FULL usermap source repos (map_source+zone_source+scripts) were found beyond known ones except kelson8/bo3-Zombies-Test-Map; full shipped-map sources on GitHub remain rare — most community value is in drop-in system kits (trap/drops/soulbox/menu/HUD), which is exactly what was harvested. GAPS: authenticated GitHub code search for strings like \"scriptparsetree\" or \"zombie_weapon_upgrade\" would likely surface more private-ish usermap sources; rerun these queries from a machine with gh auth if deeper coverage is wanted. Headline harvests for our systems: kelson8's Wonderfizz GSC-to-LUI menu bridge (Cyberware tree UI), Scobalula's item-drops framework (Data Shards pickups, weighted loot, drop placement), Owen-C137's sawblade trap (traps + zombie POI lure API) and Aetherium HUD (clientfield-to-LUI pipeline + bit-packed state), Resxt's soulboxes/challenges/buyable-ending (soul boxes, per-run randomized challenges, ending), Fearlessninja98's randomized shootable EE placement, PotatoClips' quest-chain + correct door-open recipe (DisconnectPaths/flag/NotSolid/ConnectPaths).

---

## Custom LUI client pipeline — verbatim deep-dive (2026-06-13)

Four shipped maps cloned to `tmp/` and mined line-by-line for the custom-LUI HUD
pipeline (now shipped — our LUI HUD is live). Consolidated recipe + our architecture
decision live in **docs/19_lui_pipeline.md**; this is the cited source ledger.

### L3akMod is mandatory to build custom `.lua` (linker: "Lua not supported")

The public mod tools linker rejects `rawfile,*.lua` source with
`ERROR: Lua not supported`. Fix = **L3akMod v1.0.4** (DTZxPorter): overwrite
`<bo3_root>\bin\libtiff64r.dll` (prereqs VS2013+VS2015 x64 runtimes). Runtime needs
the dashed `-unsafe-lua` switch or BO3 blocks the script. `.lua` is a rawfile
(verbatim copy) so syntax errors hit at LOAD, not link.
- **Source:** dtzxporter.com/tools/l3akmod; wiki.modme.co/wiki/black_ops_3/lua_(lui)/Installation.html; Steam discussion 4415299132514324843.

### Standalone overlay menu (the low-risk template we use)

`MattFiler/zm_alien_isolation` `ui/uieditor/menus/hud/blackscreen.lua` (27 lines) +
`audiolog.lua`: `function LUI.createMenu.<name>(Instance)` → `CoD.Menu.NewForUIEditor`,
full-bleed `setLeftRight/setTopBottom(true,true,0,0)`, `Hud.Bg:setAlpha(0)`,
elements are `CoD.TextWithBg.new(Hud,Instance)` (`.Text:setText/:setScale/:setRGB`,
`.Bg:setRGB/:setAlpha`), teardown via `LUI.OverrideFunction_CallOriginalSecond(Hud,
"close", fn)`. 4-file contract: `rawfile,...lua` (zone) + `LuiLoad("ui.uieditor.
menus.hud.<name>")` (entry .csc main) + `#precache("lui_menu","<name>")` + `m =
player OpenLUIMenu("<name>")` (gsc). Opened SERVER-side per player (bsp_torrens.gsc:132).
This is additive — does NOT override the stock HUD, so it cannot break points/perks/ammo.
- **Source:** MattFiler/zm_alien_isolation usermaps/.../ui/uieditor/menus/hud/{blackscreen,audiolog}.lua; zone L31; zm_alien_isolation.csc:51; .gsc:139,283-287.

### Stock-HUD override (the higher-risk alternative — NOT used)

`ohm-nabar/zm_building` ships `ui/uieditor/menus/hud/t7hud_zm_custom.lua` redefining
the stock `function LUI.createMenu.T7Hud_zm_factory(InstanceRef)` (engine loads by
that name). It `require()`s ~25 widgets + `CoD.Zombie.CommonHudRequire()` and adds
each as `local W=CoD.<Name>.new(HudRef,InstanceRef); W:setLeftRight/TopBottom; HudRef
:addElement(W)`. Lets you touch the real perk bar but you must re-instantiate every
stock widget — drop one and the HUD breaks. Widget pattern (room_manager.lua):
`CoD.X=InheritFrom(LUI.UIElement)`, child `LUI.UIText/UIImage`, `:subscribeToModel(
Engine.GetModel(Engine.GetModelForController(InstanceRef),"abbeyRoom"), cb)`, cb reads
`Engine.GetModelValue`; lookup tables are 1-based so index with `value+1`.
**Key correction:** `clientuimodel` scope DOES need a `.csc` MIRROR register (matching
scope/name/version/bits/type) — without it the model never exists client-side and
the Lua subscribe silently never fires — but it needs NO callback handler (engine
auto-pipes). Set server-side only via `set_player_uimodel`. Register via REGISTER_SYSTEM
in BOTH VMs so the field bit-layout stays in lockstep.
- **Source:** ohm-nabar/zm_building ui/uieditor/menus/hud/t7hud_zm_custom.lua; widgets/hud/room_manager.lua; scripts/zm/zm_room_manager.gsc+.csc; zone L82-83,272,280.

### Perk-bar glow/pulse widget (the perk-icon-glow technique)

`ColDog5044/zm_countryside` `ui/uieditor/widgets/HUD/ZM_Perks/hb21perklistitemfactory.lua`:
per-perk glow = a `LUI.UIImage` centered on the 36px slot (`setLeftRight(true,true,
-IconSize/2,IconSize/2)`), additive material `setMaterial(LUI.UIImage.GetCachedMaterial
("ui_add"))` over `RegisterImage("...glow")`, `:subscribeToModel(...,"dead_shot_ui_glow")`;
the glow itself is `el:beginAnimation("keyframe",100,false,false,CoD.TweenType.Linear);
el:setAlpha(model_value)`. GSC pulses it: `self clientfield::set_player_uimodel(
"dead_shot_ui_glow",1); wait .25; ...set...(...,0)`. The whole bar is anchored once in
the HUD menu (`setLeftRight(true,false,130,281)`/`setTopBottom(false,true,-62,-26)` =
bottom-left) and a `UIList` lays out slots. NOTE: their bar is a FULL custom perk-bar
replacement (HarryBo21 hb21_perks, via `include,hb21_perks` — the rawfile/image lines
are in that external zpkg, not the repo). For our additive OVERLAY we draw the glow at
the stock bar's screen anchor instead of inside a perk-list item.
- **Source:** ColDog5044/zm_countryside ui/uieditor/widgets/HUD/ZM_Perks/hb21perklistitemfactory.lua; menus/hud/T7Hud_zm_factory.lua L51-54; scripts/zm/_zm_perk_deadshot.gsc L80-85,178-185; assetlist image,i_specialty_vulture_zombies_glow.

### GSC↔LUI menu round-trip (Cyberware-tree menu blueprint)

`kelson8/bo3-Zombies-Test-Map` `_t9_wonderfizz.gsc` + `WonderfizzMenuBase.lua`:
open `player CloseMenu(M); player OpenMenu(M)` (player-scoped, close-before-open);
push data `#precache("lui_menu_data", "path")` + `self SetControllerUIModelValue("path",
"a|b|c|")` (delimited string; Lua `Engine.CreateModel` in PreLoadCallback mirrors it,
reads via `Engine.GetModelValue`/`subscribeToModel`); button → `Engine.SendMenuResponse(
InstanceRef,"M","perk.armorvest.2500")`; receive in GSC per-player `waittill("menuresponse",
menu,response)` (ONE global channel — MUST filter `if(menu!="M")continue`), `StrTok(".")`.
Input focus = `Engine.LockInput(InstanceRef,true)` + `Engine.SetUIActive(InstanceRef,
true)` in the menu Lua (OpenMenu alone doesn't grab input). 5 names must match exactly:
`#precache("menu",M)` · `OpenMenu(M)`/`SendMenuResponse(...,M,...)` · `LuiLoad("...M")` ·
`function LUI.createMenu.M`. `function autoexec init()` self-bootstraps (no entry wiring).
- **Source:** kelson8/bo3-Zombies-Test-Map scripts/zm/_t9_wonderfizz.gsc; ui/uieditor/menus/Craftables/WonderfizzMenuBase.lua; Widgets/Wonderfizz/{PerksUIListWidget,MenuTabPerks,MenuListItemWidget}.lua; zm_test_map.csc; assetlist zm_test_map.csv.

## Stock-file vendor-override (point-of-sale cost edits)

- **Technique:** to change behavior that lives INSIDE a stock framework function (no GSC
  partial-override exists), copy the whole stock `.gsc` from
  `share/raw/scripts/zm/<f>.gsc` into the repo at `scripts/zm/<f>.gsc`, edit it, and add
  `scriptparsetree,scripts/zm/<f>.gsc` to the `.zone`. A deployed scriptparsetree at the
  STOCK path **shadows the base-game copy** (verified: builds + links clean with
  `_zm_perks`/`_zm_weapons`/`_zm_magicbox`/`_zm_pack_a_punch`/`_zm_pers_upgrades_functions`
  vendored, 2026-06-14 — but NONE of those five are vendored in the repo today; the vendoring was
  reverted, so no `scripts/zm/<f>.gsc` copies or `scriptparsetree` zone lines for them exist.
  reconciled to code 2026-07-11). Keep the file's original `#namespace`.
- **Cycle trap:** a vendored stock file that needs an `_acc_*` value must read the FIELD
  directly (e.g. `player.acc_mega_perks["specialty_..."]`), NOT `#using` the `_acc_` module
  — those modules `#using` the stock files back, so importing them creates a `#using` cycle.
  Field access needs no `#using`.
- **Not applied (Armory redesigned):** the `pers_double_points` cost-discount hook was never shipped.
  `_acc_armory.gsc` is now a Mega-Bottle → random-implant exchange station (`acc_armory_bottle_cost`
  empty Mega Bottles per exchange, consumed via `acc_mega_bottles::try_consume_bottle`) with no
  `is_pers_double_points_active` / `pers_upgrade_double_points_cost` discount logic anywhere in
  `scripts/`. (reconciled to code 2026-07-11)
- **Cost↔display split (hard-won):** the CHARGE and the DISPLAYED price are computed in
  DIFFERENT code paths. Discounting only the charge leaves the shown price wrong. Wallbuy
  prices are client-filled by default (`level.weapon_cost_client_filled=true`) — flip it
  false to render the (discounted) price server-side. Perk/PaP machine hints are a single
  SHARED trigger string (not per-player), so a per-player price needs a per-player hint
  loop (we re-set the hint to the TOUCHING player's price) or per-player triggers; the box
  trigger is already per-player so its display is exact.

## LUI HUD widget override — recolor/replace a STOCK HUD element (zm_building, 2026-06-17)

> **STATUS: UNVERIFIED / did NOT work on our setup (2026-06-17).** We tried all of the below to
> recolor the stock round counter teal — same-path rawfile, `require`, and the HUD-root wrapper —
> and the counter stayed red in-game every time. zm_building clearly ships this, but we could not
> reproduce it here and can't debug blind (no runtime LUI introspection). The feature was abandoned.
> Treat this section as THEORY to revisit only with live LUI debugging, not a proven recipe.


- **What:** the stock zombies HUD elements are individual LUI widgets, built by the HUD ROOT menu
  `LUI.createMenu.T7Hud_zm_factory`, which instantiates each by CALLING its `LUI.createMenu.<name>`
  factory — e.g. the round counter: `LUI.createMenu.RoundStatus(InstanceRef)` (chalk marks +
  `ZOMBIE_ROUND` + round number, driven by the `GameScore`/`roundsPlayed` global model). Source:
  `tmp/zm_building/ui/uieditor/menus/hud/t7hud_zm_custom.lua:68` (defines `T7Hud_zm_factory`) `:145`
  (calls `LUI.createMenu.RoundStatus`); the widget body `.../widgets/hud/RoundStatus.lua`.
- **WHAT DOESN'T WORK (tried, stayed red):** shipping a `.lua` rawfile at the stock widget's *same
  path* and expecting it to auto-override. A packed rawfile does NOT execute on its own, and even
  when loaded it loses the load-order / `require`-cache race against the stock copy. (zm_building
  ships RoundStatus.lua as a rawfile, but it ALSO `require`s it from its full HUD-root replacement —
  the rawfile alone is not the mechanism.)
- **WHAT WORKS — wrap the HUD-root factory:** (1) put your widget at a UNIQUE path
  (`acc_round_status.lua`) so `require` ALWAYS executes it (no stock-name cache collision); have it
  stash its factory in a global (`CoD.AccTealRoundStatus = LUI.createMenu.RoundStatus`). (2) From a
  LUI file that loads early (our `acc_hud.lua`, LuiLoad'd in the `.csc __init__`), `require` it, then
  wrap the root:
  `local o = LUI.createMenu.T7Hud_zm_factory; LUI.createMenu.T7Hud_zm_factory = function(I) LUI.createMenu.RoundStatus = CoD.AccTealRoundStatus; return o(I) end`.
  Forcing the factory ref right before delegating defeats the order/cache race. `pcall`/nil-guard it.
- **Asset-name rule still applies separately:** for *assets* (materials/images/xmodels) the base
  zone wins a name collision (docs/20 — why the perk bar can't be recolored via image names). LUI
  *behavior* is overridable via the `LUI.createMenu.*` function table (code), which is the lever here.
- **Superseded (never shipped):** the `acc_round_status.lua` factory-wrap teal recolor was NOT applied —
  no such file exists in the repo, and no `CoD.RoundStatus.DefaultColor` / `(0.25,0.88,0.82)` override
  survives in any `.lua`. The round counter is now the Aetherium HUD widget
  `ui/uieditor/widgets/HUD/AetheriumWidgets/AetheriumRoundCounter.lua` (Aetherium HUD adopted 2026-07-03,
  after this 2026-06-17 section). (reconciled to code 2026-07-11)
- **Reuse:** the same factory-wrap can restyle other stock HUD widgets the root builds (ammo, score,
  perks) — override their `LUI.createMenu.<name>` inside the same `T7Hud_zm_factory` wrapper.
