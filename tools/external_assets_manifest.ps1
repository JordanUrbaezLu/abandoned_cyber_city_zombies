# =============================================================================
# external_assets_manifest.ps1 - single source of truth for the external
# (game-rip) asset packs this map's BUILD depends on but that are NOT committed
# to git (no redistribution licence + multi-GB binaries - see CREDITS.md).
#
# Dot-sourced by:
#   tools/pack_external_assets.ps1   (owner: zip the installed packs to share)
#   tools/check_external_assets.ps1  (anyone: pre-build "is everything here?" gate)
#
# Paths are RELATIVE TO THE MOD TOOLS ROOT (the AppID-suffixed
# "...Call of Duty Black Ops III 455130" folder, detected via bin\modlauncher.exe -
# never the folder name). A path entry may be:
#   - a folder      -> copied recursively         (e.g. model_export\_NSZ)
#   - a wildcard    -> matching files/dirs in its parent  (e.g. source_data\skye_*.gdt)
# 'Marker' is the one path whose presence proves the pack is installed.
# 'Required' = $false packs are skipped by pack unless -IncludeOptional, and are
# only WARN (not FAIL) in check.
# =============================================================================

function Resolve-ModToolsRoot([string]$Override) {
    if ($Override -ne '') { return $Override }
    # Require bin\modlauncher.exe as proof of the tools root (the game folder
    # alone passes Test-Path but is NOT the tools root) - same detection as
    # sync_to_modtools.ps1 / preflight_windows.ps1.
    $libRoots = @(
        'C:\Program Files (x86)\Steam\steamapps\common',
        'D:\Steam\steamapps\common',
        'E:\Steam\steamapps\common',
        'C:\Steam\steamapps\common'
    )
    foreach ($lib in $libRoots) {
        if (-not (Test-Path $lib)) { continue }
        $dirs = Get-ChildItem $lib -Directory -Filter 'Call of Duty Black Ops III*' -ErrorAction SilentlyContinue
        foreach ($d in $dirs) {
            if (Test-Path (Join-Path $d.FullName 'bin\modlauncher.exe')) { return $d.FullName }
        }
    }
    throw "Could not auto-detect the Mod Tools root (no folder with bin\modlauncher.exe). Pass -ModToolsRoot explicitly."
}

$ExternalAssetPacks = @(
    @{
        Name     = 'Avogadro (electric boss)'
        Author   = 'Dick_Nixon (BO2 port) / Treyarch (orig)'
        Provides = 'archetype_zm_avogadro aitype (model, 11 xanims, behavior tree, FX, sounds, GDT) + vendored control script'
        Required = $false
        Marker   = 'model_export\gwm_avogadro'
        Link     = 'Avogadro.rar - modme thread 2402 "Mike''s repertoire" (MediaFire). docs/56.'
        Paths    = @(
            'model_export\gwm_avogadro',
            'xanim_export\ai\avogadro',
            'sound_assets\avogadro',
            'share\raw\fx\zombie\fx_avogadro_linger.efx',
            'share\raw\fx\zombie\fxt\fx_tesla_bolt_secondary_zmb.efx',
            'share\raw\behavior\zm_avogadro.ai_bt',
            'share\raw\animstatemachines\zm_avogadro.ai_asm',
            'share\raw\animtables\zm_avogadro.*',
            'share\raw\sound\aliases\avogadro.csv'
        )
    },
    @{
        Name     = 'HB21 Civil Protector (ally robot)'
        Author   = 'HarryBo21 + credits list in pack INSTRUCTIONS.txt / CREDITS.md'
        Provides = 'archetype_ally_zod_robot_companion_ar/_gold_ar aitypes (2 models, 441 xanims, ASM/BT/animtables, FX, sounds, GDT) + call-box/fuse prefabs'
        Required = $true
        Marker   = 'model_export\black_ops_3\c_zom_zod_robot_protector'
        Link     = 'hb21_civil_protector_v2.0.0.rar (user download 2026-07-02). NOTE: requires the separate "HB21 FX library" for 2 fuse FX - we STUB them instead (see Paths).'
        Paths    = @(
            'model_export\black_ops_3\c_zom_zod_robot_protector',
            'model_export\wpn_t7_arak.gdt',
            'xanim_export\black_ops_3\ai_robot_*',
            'xanim_export\black_ops_3\ai_cmpn_*',
            'source_data\c_zom_zod_robot_protector.gdt',
            'sound_assets\chr\robot',
            'sound_assets\en\vox\scripted\zod',
            'sound_assets\evt\beautiful_corner',
            'sound_assets\evt\lfe_sweep_hits',
            'sound_assets\exp\firey',
            'sound_assets\fly\archetype\siegebot',
            'sound_assets\fly\bots',
            'sound_assets\fly\footsteps',
            'sound_assets\gdt\cybercore',
            'sound_assets\zmb\ai\civil_protector',
            'sound_assets\zmb\level\zm_zod',
            'share\raw\accuracy\aivsai\zod_companion.accu',
            'share\raw\animstatemachines\zod_robot_companion.ai_asm',
            'share\raw\animtables\zod_robot_companion.*',
            'share\raw\behavior\zod_robot_companion.ai_bt',
            'share\raw\fx\destruct\fx_dest_robot_*.efx',
            'share\raw\fx\electric\fx_elec_dmg_robot_helper_zod_zmb.efx',
            'share\raw\fx\impacts\fx_bul_impact_concrete_sm.efx',
            'share\raw\fx\zombie\fx_robot_helper_*.efx',
            # The 2 fuse FX below are OUR stub copies of fx_robot_helper_revive_hand (the real ones
            # are in the missing HB21 FX library; only render on unplaced fuse-quest props):
            'share\raw\fx\zombie\fx_fuse_glow_blue_zod_zmb.efx',
            'share\raw\fx\zombie\fx_fuse_master_switch_on_zod_zmb.efx',
            'share\raw\sound\aliases\zm_ai_zod_companion.csv',
            'share\zone_source\zm_ai_zod_companion.zpkg',
            'map_source\_prefabs\zm\harrybo21_prefabs'
        )
    },
    @{
        Name     = 'HB21 Apothicon Fury (trench elite)'
        Author   = 'HarryBo21 + credits list in pack INSTRUCTIONS.txt / CREDITS.md'
        Provides = 'archetype_zm_genesis_apothicon_fury aitype (DLC4 Apothicon Fury: model, xanims, ASM/BT/animtables, 25 dlc4/genesis FX, sounds, GDT). Spawning = _acc_fury.gsc (5x hp trench elite, 40s underground cadence); the pack SPECIAL FURY ROUNDS mode is disabled in our vendored zm_genesis_apothicon_fury.gsh, which ALSO swaps the ground-tell FX to the Civil Protector pack fx_robot_helper_ground_tell_zod_zmb because the fury pack references zombie/fx_meatball_impact_ground_tell_zod_zmb WITHOUT shipping it (dangling fx = fatal; memory silent-weapon-conversion-kill-dangling-refs). Scripts vendored in-repo at pack paths (scripts/shared/ai/ + scripts/zm/) - reinstalling the pack does NOT touch them.'
        Required = $true   # zone aitype,/fx,/character, lines + szc zm_ai_apothicon_fury block reference it
        Marker   = 'model_export\black_ops_3\c_zom_dlc4_apothicon_fury'
        Link     = 'hb21_apothicon_furys_v1.1.0.rar (user download 2026-07-02). Same-family install as HB21 Civil Protector; needs NO HB21 FX library (all its own FX ship in the rar).'
        Paths    = @(
            'model_export\black_ops_3\c_zom_dlc4_apothicon_fury',
            'xanim_export\black_ops_3\c_zom_dlc4_apothicon_fury',
            'source_data\c_zom_dlc4_apothicon_fury.gdt',
            'sound_assets\zmb\ai\fury',
            'sound_assets\evt\cp_infection',
            'sound_assets\pfx\sparks',
            'share\raw\animstatemachines\zm_genesis_apothicon_fury.ai_asm',
            'share\raw\animtables\zm_genesis_apothicon_fury.*',
            'share\raw\behavior\zm_genesis_apothicon_fury.ai_bt',
            'share\raw\fx\dlc4\genesis',
            'share\raw\sound\aliases\zm_ai_apothicon_fury.csv',
            'share\zone_source\zm_ai_apothicon_fury.zpkg',
            'map_source\_prefabs\zm\harrybo21_prefabs\apothicon_fury'
        )
    },
    @{
        Name     = 'BOTD Zombies (underground horde reskin)'
        Author   = 'Kingslayer Kyle (port; Wraith/Greyhound by DTZxPorter/Scobalula; Treyarch orig)'
        Provides = 'c_t8_zmb_mob_zombie_body1-3 + head1-4 (BO4 Blood of the Dead prisoners, self-contained materials) - SetModel+Attach reskin for below-base-level spawns (_acc_trench_skins)'
        Required = $true
        Marker   = 'model_export\kingslayer_kyle\characters\t8\c_t8_zmb_mob_zombie'
        Link     = '"BOTD Zombies - Kingslayer Kyle.rar" (user download 2026-07-03). Readme: credit Kingslayer Kyle.'
        Paths    = @(
            'model_export\kingslayer_kyle',
            'map_source\_prefabs\kingslayer_kyle'
        )
    },
    @{
        Name     = '54 Immortals zombies (INSTALLED FALLBACK - superseded by BOTD)'
        Author   = 'Zeroy (packaging/import; DTZxPorter Wraith; Treyarch orig)'
        Provides = 'c_54i_{assault,cqb,sniper}_body - FIRST underground-reskin pick, REJECTED 2026-07-03 (bodies render HEADLESS in-game; pack ships 1 head model). Kept installed for A/B.'
        Required = $false
        Marker   = 'model_export\zeroy\bodies_bo3_zm4'
        Link     = '54I_Zombies.rar (user download 2026-07-03; Zeroy pack). 2nd fallback (NOT installed): "ninja_dlchd_ascension_zombies.zip".'
        Paths    = @(
            'model_export\zeroy',
            'source_data\zeroy',
            'map_source\_prefabs\zm\zm_core\spawner_54i.map'
        )
    },
    @{
        Name     = 'NSZ Brutus (mini-boss)'
        Author   = 'NateSmithZombies'
        Provides = 'r3/r10/r20 mini-boss aitype (model, anims, FX, sounds, GDT, GSC)'
        Required = $true
        Marker   = 'model_export\_NSZ'
        Link     = 'MEGA folder https://mega.nz/folder/g7BHRCyI#5v2pEFoKQ058pAeWlHfmnA (NSZ_Brutus v1.0.4) | modme #765'
        Paths    = @(
            'model_export\_NSZ',
            'xanim_export\_NSZ',
            'sound_assets\_NSZ',
            'share\raw\fx\_NSZ',
            'share\raw\animtables\zm_brutus.*',
            'share\raw\scripts\_NSZ',
            'map_source\_prefabs\_NSZ'
        )
    },
    @{
        Name     = 'Skye weapon ports (box + starting guns)'
        Author   = 'TheSkyeLord + LilRobot'
        Provides = 'Tac-19, Five-seven, ASM1, AK-47, AE4, Ripper (+ FAL)'
        Required = $true
        Marker   = 'model_export\skye_ports'
        Link     = 'UGX Master Hub https://www.ugx-mods.com/forum/full-weapons/84/skyes-weapon-ports-to-bo3-master-hub/16874/'
        Paths    = @(
            'model_export\skye_ports',
            'xanim_export\skye_ports',
            'sound_assets\skye_ports',
            'share\raw\fx\skye_efx',
            'source_data\skye_*.gdt',
            'map_source\_prefabs\zm\skye_prefabs'
        )
    },
    @{
        Name     = 'Charred Zombie reskin (base horde)'
        Author   = 'Logical (rip via Greyhound/HydraX, Scobalula)'
        Provides = 'archetype_charred_zombie character + gibs (100% of normal spawns)'
        Required = $true
        Marker   = 'source_data\_charred_zombies.gdt'
        Link     = 'No public link recorded - obtain the zip from a teammate (search UGX/Modme "Logical Charred Zombie")'
        Paths    = @(
            'model_export\_custom_zombies\charredzombies',
            'source_data\_charred_zombies.gdt'
        )
    },
    @{
        Name     = 'Aetherium HUD assets (Owen-C137 BO7 remake)'
        Author   = 'Owen-C137 (+ Kingslayer Kyle, Shidouri, MadGaz); art derived from BO7/CW rips'
        Provides = '~103 HUD image assets + sat_hud_horizontal_compass material (GDT inside the pack folder) for the Aetherium HUD (zone AETHERIUM block; Lua/GSC/fonts/strings live IN the repo)'
        Required = $true   # the .zone AETHERIUM block references the GDT images -> fresh clone link-errors without it
        Marker   = 'model_export\_OwensAssets\bo7\aetherium_hud'
        Link     = 'https://github.com/Owen-C137/Aetherium-Hud-Bo7-Remake- (public repo; licence: free to use/modify, credit appreciated). Install: copy DRAG_IN_BO3_ROOT\model_export into the tools root, THEN retheme purple->cyan (user 2026-07-03): copy the 4 PNGs from ...\aetherium_hud\sat_hud_colors\blue\ over the same-named root PNGs in ...\aetherium_hud\ (originals backed up as *.png.acc-purple-orig), then gdtdb /update. Local clone: ..\Aetherium-Hud-Bo7-Remake'
        Paths    = @(
            'model_export\_OwensAssets'
        )
    },
    @{
        Name     = 'Perk-icon shaders (Ronan-derived)'
        Author   = 'Ronan (Cyberpunk Shaders)'
        Provides = '16x perk HUD icons (i_acc_perk_*), referenced by the .zone'
        Required = $true
        Marker   = 'source_data\acc_perk_shaders.gdt'
        Link     = 'Currently UNTRACKED in repo source_data\acc_perk_shaders* (deploy via tools/deploy_perk_shaders.ps1); art is game-rip-derived'
        Paths    = @(
            'source_data\acc_perk_shaders.gdt',
            'source_data\acc_perk_shaders'
        )
    },
    @{
        Name     = 'Action Figure melee (BO4 t8 port)'
        Author   = 'T0nic (port); base model BO4 / Treyarch'
        Provides = 'Action Figure handheld melee (t8_melee_figure + t8_actionfigure_melee offhand) - box S-tier + dev give'
        Required = $true   # the .zone references weapon,t8_melee_figure -> a fresh clone link-errors without it
        Marker   = 'source_data\t8_weapons\wpn_t8_melee_actionfigure.gdt'
        Link     = 'ZGC finder https://icegrenade.co.uk/assets/ (Melee) | direct https://drive.google.com/uc?export=download&id=1cVUc6ZaY17meLyT_LNlelXm5BcnSFwQ8 | AFTER install run: node tools/fix_actionfigure_port.js (patches 2 port bugs), then gdtdb /update'
        Paths    = @(
            'model_export\t8_weapons\wpn_t8_melee_actionfigure',
            'xanim_export\t8_weapons\t8_melee_actionfigure',
            'source_data\t8_weapons\wpn_t8_melee_actionfigure.gdt'
        )
    },
    @{
        Name     = 'West Electric Cherry machine (perk vending model)'
        Author   = 'Westchief596 ([West] Community Perk Collection v2.7); machine templates Betiroval/F3ARxReaper666/HarryBo21; base model Treyarch (BO2 Alcatraz)'
        Provides = 'xmodel electric_cherry_model + 3 materials + 12 textures - the real EC vending machine (EC-machine-only lift; the 60-perk pack itself is NOT installed)'
        Required = $true   # the .zone has xmodel,electric_cherry_model -> a fresh clone link-errors without it
        Marker   = 'source_data\acc_west_electric_cherry.gdt'
        Link     = 'Full pack: "Community Perk Collection v2.7" by Westchief596 (Discord @westchief596; owner keeps the zip). EC-only lift recipe: CHANGELOG 2026-07-01 (extract the 16 electric_cherry_model/_machine_* GDT entries into source_data\acc_west_electric_cherry.gdt - repoint body specColorMap to electric_cherry_machine_body_s - + copy _custom\westchief596\perks\Electric Cherry; then gdtdb /update)'
        Paths    = @(
            'source_data\acc_west_electric_cherry.gdt',
            '_custom\westchief596\perks\Electric Cherry'
        )
    },
    @{
        Name     = 'SAT Toxic Zombies (boss skins, model-only lift)'
        Author   = 'WetEgg (SAT Toxic Zombies pack; FX assist Rayjiun)'
        Provides = 'xmodels c_sat_zmb_zombie_toxic_1/_2 (+8 materials/39 images) - Glitch Stalker + Phantom boss skins. The pack AI system is NOT installed.'
        Required = $true   # zone has xmodel,c_sat_zmb_zombie_toxic_1/_2
        Marker   = 'source_data\acc_sat_toxic_zombies.gdt'
        Link     = 'devraw (WetEgg) - user zip "SAT Toxic Zombies.zip". Lift recipe: CHANGELOG 2026-07-02 (extract xmodel/material/image entries only; assets under _custom\_wetegg\ai\sat\c_sat_zmb_zombie_toxic).'
        Paths    = @(
            'source_data\acc_sat_toxic_zombies.gdt',
            '_custom\_wetegg\ai\sat\c_sat_zmb_zombie_toxic'
        )
    },
    @{
        Name     = 'BO1 Thundergun (TheAllNightFall t5 port - stock-name override)'
        Author   = 'TheAllNightFall'
        Provides = 'OVERRIDES stock thundergun_zm / thundergun_upgraded_zm weapon assets in place (BO1 model/anims/sounds; night_t5_thundergun.gdt shadows stock names - zero GSC changes)'
        Required = $true   # zone has weapon,thundergun_zm(+_upgraded_zm); szc has t5_thundergun_sounds
        Marker   = 'source_data\night_t5_thundergun.gdt'
        Link     = 'devraw - user zip "t5_thundergun.zip"'
        Paths    = @(
            'source_data\night_t5_thundergun.gdt',
            'model_export\TheAllNightFall_t5_thundergun',
            'xanim_export\TheAllNightFall',
            'sound_assets\t5_thundergun',
            'share\raw\sound\aliases\t5_thundergun_sounds.csv'
        )
    },
    @{
        Name     = 'ALXS CW/BO6 Pack-a-Punch machine model (model-only lift)'
        Author   = 'ALXS (model/anims: Madgaz, Owen C137)'
        Provides = 'xmodel p9_fxanim_zm_gp_pap_xmodel (+_off variant, unused) + hashed material/image set - both PaP machines'' visible model. Pack scripts/sounds NOT installed.'
        Required = $true   # zone has xmodel,p9_fxanim_zm_gp_pap_xmodel
        Marker   = 'source_data\acc_alxs_pap.gdt'
        Link     = 'devraw - user zip "ALXS_CW-BO6 PAP.zip"'
        Paths    = @(
            'source_data\acc_alxs_pap.gdt',
            'model_export\_blackops_coldwar_ehancepack'
        )
    },
    @{
        Name     = 'Nastian T9 Skyboxes (CW skybox set)'
        Author   = 'Nastian'
        Provides = '16 CW skybox xmodels (skybox_t9_*, stock t6 dome + skinOverride) + sky_latlong_hdr materials + HDR exr images. NOT currently shipped (2026-07-02: miami + zm_silver_dark both rejected, map back on stock skybox_default_night) - retained for future one-token sky experiments'
        Required = $false
        Marker   = 'source_data\acc_nastian_t9_skyboxes.gdt'
        Link     = 'devraw - user zip "Nastian - T9 Skyboxes.zip". NOTE: pack GDT skinOverride values shipped literal \r\n escapes - sanitized on install (CHANGELOG 2026-07-02).'
        Paths    = @(
            'source_data\acc_nastian_t9_skyboxes.gdt',
            'texture_assets\black_ops_cw\skyboxes'
        )
    },
    @{
        Name     = 'Fanatic WW2 Power Switch v1.0.1 (model-only lift)'
        Author   = 'Fanatic'
        Provides = 'ww2_circuit_breaker xmodel (+materials, 2 unused dial xanims) + our clone prefab _prefabs\acc\power_switch_ww2.map (stock power_switch prefab with only the body model swapped)'
        Required = $true   # .map references the clone prefab; zone has xmodel,ww2_circuit_breaker
        Marker   = 'model_export\fanatic\ww2\power_switch'
        Link     = 'devraw - user rar "Fanatic-WW2PowerSwitch.v1.0.1.rar". Interactive system NOT installed (model lift only).'
        Paths    = @(
            'model_export\fanatic',
            'xanim_export\fanatic',
            'source_data\fanatic\ww2\ww2_power_switch.gdt',
            'map_source\_prefabs\acc\power_switch_ww2.map'
        )
    },
    @{
        Name     = 'Ultimate Round Sounds Pack (Kino/t5_theater stingers)'
        Author   = 'WetEgg (music info MidgetBlaster; tools Scobalula/DTZxPorter/Dest1yo/echo000; refs Booris, Peppergogo)'
        Provides = 'Kino round-start/round-end/game-over stinger wavs (t4/t5 rips) - aliased by repo sound/aliases/acc_round_sounds.csv, hooked in _acc_music.gsc. Pack GSC system NOT installed.'
        Required = $true   # szc references acc_round_sounds.csv whose FileSpecs point at these wavs
        Marker   = 'sound_assets\_wetegg'
        Link     = 'devraw - user rar "Ultimate Round Sounds Pack.rar"'
        Paths    = @(
            'sound_assets\_wetegg'
        )
    },
    @{
        Name     = 'BO6 materials pilot (OPTIONAL - feasibility only, NOT zoned)'
        Author   = 'MadGaz (_mg_bo6_materials)'
        Provides = 'ONE pilot material t10_brick_stone_wall_rough_dark + images (docs/29 face-techset trap verdict: LIKELY-TRAP; not on any face, cannot affect builds)'
        Required = $false
        Marker   = 'source_data\acc_bo6_mat_pilot.gdt'
        Link     = 'devraw - user rar "_mg_bo6_materials.rar" (full 413-material GDT NOT installed)'
        Paths    = @(
            'source_data\acc_bo6_mat_pilot.gdt',
            'texture_assets\_bo6'
        )
    },
    @{
        Name     = 'MidgetBlaster T7 Assets V2.7 (pilot slice - 2 exchange-room props)'
        Author   = 'MidgetBlaster (T7 rips; tools: Spiki, Scobalula, Serious)'
        Provides = 'xmodels p7_zm_moo_server_comm_02 + p7_cru_monitor_holo_screen_01 (+ materials/PNG images) - exchange-room decor pilot (docs: T7 spike). The 53GB pack itself is NOT installed; slices carved per prop.'
        Required = $true   # zone has both xmodel lines; _acc_atmosphere spawns them
        Marker   = 'source_data\acc_t7_props_pilot.gdt'
        Link     = 'User rar "T7 Assets V2.7.rar" (Downloads) - keep compressed as the prop library; extract per-prop slices on demand (spike report 2026-07-02)'
        Paths    = @(
            'source_data\acc_t7_props_pilot.gdt',
            'model_export\_midgetblaster\props\p7_zm_moon',
            'model_export\_midgetblaster\props\p7_mp_crucible'
        )
    },
    @{
        Name     = 'Blast-O-Matic v1.2 (CW DOA energy blaster)'
        Author   = 'Owens (weapon port/FX/prefab); custom camos GDT tagged _mg'
        Provides = 't9_semiauto_cosplay(_up) wonder weapon - box S+ slot, dev-spawn gun, fully twinned (14 hand-built projectile twins in the repo variants GDT). README claims a devraw "Bo3 Gun Pack" dependency - empirically REFUTED (all dangling refs are stock-shipped assets; CHANGELOG 2026-07-03). PATCHES REQUIRED AFTER (RE)INSTALL (all found/applied 2026-07-03, .acc-orig backups next to patched files): (1) both share\raw\fx\_owens_effects\t9_semiauto_cosplay\fx_raygun_geotrail_{blue,red}_doa.efx line 787 blanked to emission ""; - the pack references stock-fastfile-only fx zombie/fx_raygun_trail_ring_doa (no raw .efx exists); (2) weapon GDT wpn_t9_shotgun_semiauto_cb_cosplay.gdt: aiVsPlayerAccuracyGraph "pistol.accu" blanked on both entries (file does not exist under accuracy\aivsplayer\) - EITHER dangling ref HARD-FAILS the whole weapon conversion (0 weapon rows in assetinfo, gun silently absent; weaponfull twins = native DB-load crash instead); (3) balance: base entry clipSize 7 -> 5 + maxAmmo/startAmmo 12 (= 60 reserve), _up entry maxAmmo/startAmmo 80 -> 6 (= 120 reserve) - NOTE maxAmmo/startAmmo count MAGAZINES not rounds (reserve = maxAmmo x clipSize, docs/54); twins GDT carries the same. After patching: full gdtdb rebuild.'
        Required = $true   # zone weapon,/weaponfull, lines + szc _owens_weapons block reference it
        Marker   = 'model_export\_owens_weapons'
        Link     = 'devraw - user zip "Blast-O-Matic [UPDATED v1.2].zip"'
        Paths    = @(
            'model_export\_owens_weapons',
            'model_export\_cwdb',
            'model_export\t7_props_zombie',
            'source_data\owens_weapons',
            'source_data\_mg_custom_camos.gdt',
            'share\raw\fx\_owens_effects',
            'share\raw\sound\aliases\_owens_weapons.csv',
            'sound_assets\_owens_weapons',
            'map_source\_prefabs\owens_prefabs'
        )
    },
    @{
        Name     = 'Panzer / mechz (OPTIONAL, WIP - not in shipped .ff)'
        Author   = 'Spiki'
        Provides = 'future heavy boss (in-progress)'
        Required = $false
        Marker   = 'source_data\mechz_spiki.gdt'
        Link     = 'modme #3087 (MEGA, password Chungus4Prez; verified live 2026-07-03 - base https://mega.nz/#!Clh0VYCY!gS1r0bmJLQb6VQAq2dcNs3i4zbMRohTY8S5fIyoDhzU + update https://mega.nz/file/65Aj3aRB#mjw-His7ZbGUs974tVRC8XbziAGlaIgEjn19NpqAgs8; recipe tools/_panzer_stash/README.md)'
        Paths    = @(
            'model_export\*mechz*',
            'xanim_export\*mechz*',
            'sound_assets\*mechz*',
            'share\raw\fx\*mechz*',
            'source_data\*mechz*'
        )
    }
)
