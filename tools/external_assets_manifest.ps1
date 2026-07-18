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
        Provides = 'archetype_zm_avogadro aitype + variant_/spawner_ derived chain (model c_zom_t7_avogadro, 11 xanims, ASM, behavior tree, avogadro_bolt/melee/shock weapons, FX, sounds, GDT) + vendored control script. Spawned via SpawnActor("spawner_zm_avogadro") - round-1 Plaza spawn SPIKE (user 2026-07-04, _acc_boss_avogadro).'
        Required = $true   # zone references aitype,archetype_zm_avogadro + aitype,spawner_zm_avogadro -> a fresh clone link-errors without it
        Marker   = 'model_export\gwm_avogadro'
        Link     = 'Avogadro.rar (56.9 MB) - modme thread 2402 "Mike''s repertoire" (Dick_Nixon, from Bus Depot Reimagined; MediaFire). docs/08_enemies.md (was docs/56 pre-renumber). GDT ships INSIDE model_export\gwm_avogadro\gwm_avogadro.gdt (like NSZ Brutus) - gdtdb /update picks it up from model_export. The pack "PUT IN YOUR ZM_USERMAP FOLDER" scripts are NOT installed (we vendor our own crash-fixed _zm_ai_avogadro.gsc/.csc). The pack ships an actor_spawner_zm_avogadro prefab we do NOT use (its .map entity crashes the LED bake).'
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
        Name     = "Winter's Howl freeze gun (GCPeinhardt BO1 port)"
        Author   = "GCPeinhardt (scripting/FX/porting) + booris (models/anims) / Treyarch (orig BO1 weapon)"
        Provides = "freezegun_zm + freezegun_upgraded_zm projectileweapons (view/world models, 28 view anims, 5 unique zombie freeze-death anims, freeze/shatter/crumple FX, the c_t8_freezegun_mtl dissolve material, sounds) - the box UTILITY wonder weapon (slows bosses / super-effective vs Shielded+Glitch). Self-registering scripts are VENDORED in git (scripts/zm/_zm_weap_freezegun.gsc/.csc/.gsh); only the binary assets ride this manifest."
        Required = $true   # zone references weapon,freezegun_zm / _upgraded_zm + the freeze FX/material -> a fresh clone link-errors without it
        Marker   = 'source_data\wpn_t8_zmb_freezegun.gdt'
        Link     = "Winter's Howl.rar (44 MB) - GCPeinhardt 1:1 BO1 port, posted in the BO3 Mod Tools Discord (server 230615005194616834, #releases). The self-contained GDT installs to source_data\wpn_t8_zmb_freezegun.gdt (NOT model_export). PATCH AFTER (RE)INSTALL (all in tools/oneshots, see CHANGELOG 2026-07-11): (1) strip the 2 STOCK duplicate xanim blocks (ai_zm_dlc5_zombie_crawl_freeze_death_01 / _02) from the GDT or gdtdb /update fails 'Duplicate xanim asset' (freeze_death_a..e are UNIQUE - keep them); (2) run gen_freezegun_twins.js to set moveSpeedScale 1.07 (the rar ships 1) AND regenerate acc_freezegun_twins.gdt (the fastreload wonder twins) - then gdtdb /update (PowerShell) + link. docs/04_weapons.md. Personal/testing - CREDITS/IP review before any public Workshop release."
        Paths    = @(
            'source_data\wpn_t8_zmb_freezegun.gdt',
            'source_data\acc_freezegun_twins.gdt',
            'model_export\weapons_t8\freezegun',
            'xanim_export\t8_viewmodels\freezegun',
            'xanim_export\ai\zombie\zm_dlc5_zombie',
            'sound_assets\wpn\energy\freezegun',
            'share\raw\fx\dlc5\zmb_weapon\fx_freezegun_*.efx',
            'share\raw\fx\dlc5\zmb_weapon\fx_exp_freezegun_impact.efx',
            'share\raw\fx\dlc2\island\fx_zombie_gib_trail.efx',
            'share\raw\lensflares\lf_freezegun.klf',
            'share\raw\sound\aliases\freezegun_sounds.csv'
        )
    },
    @{
        Name     = 'Ballistic Knife (pmr360 pack over the stock t7 loot asset)'
        Author   = 'pmr360 (script tweaks) + Serious/Scobalula (decompile tooling) / Treyarch (orig BO3 weapon art - all stock-cooked)'
        Provides = 'knife_ballistic_zm + knife_ballistic_upgraded_zm projectileweapon defs (wpn_t7_loot_ballistic_knife.gdt) + impactsoundbolt.gdt (bolt impact table) + 13x 48k wavs + a raw art tree (models/anims/textures duplicate STOCK-cooked assets; installed so the linker rebuilds from raw). Override script scripts/zm/_zm_weap_ballistic_knife.gsc is VENDORED in git (pmr360 impl + [acc] Krauss revive / brz watchers); acc_ballistic_knife_twins.gdt (the _acc_brz stab-speed twins) is REGENERATED by tools/oneshots/gen_ballistic_brz_twins.js. Box utility special: base one-hits regular+glitch / deflects off Shielded; PaP tier 2 = the Krauss Refibrillator ranged revive.'
        Required = $true   # zone references weapon,knife_ballistic_zm etc. -> a fresh clone link-errors without it
        Marker   = 'source_data\wpn_t7_loot_ballistic_knife.gdt'
        Link     = 'Black Ops 3 - Ballistic Knife.rar (6.7 MB, pmr360; user Downloads copy 2026-07-11). Extract model_export/xanim_export/texture_assets/sound_assets/source_data into the tools root. INSTALL-SIDE STEPS AFTER (RE)INSTALL: (1) comment out the zm_patch.csv line `scriptparsetree,scripts/zm/_zm_weap_ballistic_knife.gsc` (backup zm_patch.csv.acc-orig kept) or the linker SILENTLY keeps the 116-byte stock stub and drops our override (memory stock-override-zm-patch-dedupe); (2) run tools/oneshots/gen_ballistic_brz_twins.js to regenerate acc_ballistic_knife_twins.gdt; (3) gdtdb /update - TOUCH the GDT mtimes first if freshly extracted (rar timestamps predate gdt.db so the incremental scan silently skips them: "processed 0 GDTs"); then link. docs/04_weapons.md. Credit pmr360 in CREDITS before any public Workshop release.'
        Paths    = @(
            'source_data\wpn_t7_loot_ballistic_knife.gdt',
            'source_data\impactsoundbolt.gdt',
            'source_data\acc_ballistic_knife_twins.gdt',
            'model_export\weapons_t7\ballistic_knife',
            'xanim_export\t7_viewmodels\ballistic_knife_t7',
            'texture_assets\knife_ballistic_reticle.png',
            'sound_assets\wpn\melee\ballistic_knife',
            'sound_assets\prj\bolt\whoosh',
            'sound_assets\wpn\crossbow\dry_fire',
            'share\raw\fx\dlc5\mp_weapon\fx_muz_ballistic_smk_1p.efx',
            'share\raw\fx\dlc5\mp_weapon\fx_muz_ballistic_smk_3p.efx'
        )
    },
    @{
        Name     = 'Ultimis player crew (WaW models)'
        Author   = 'Illuminati Donut (port) / Treyarch (orig) / DTZxPorter (tools)'
        Provides = 'zm_character_customization customizationtable that SHADOWS the stock one -> swaps the 4 ZM player bodies to Ultimis WaW Dempsey/Nikolai/Richtofen/Takeo (+ 1st-person viewhands/viewlegs). 12 xmodels, 4 playerbodytype/style, ~218 images, 56 materials. HUD portraits aligned in AetheriumCharacters.lua (hud* keys -> operator faces).'
        Required = $true   # zone references customizationtable,zm_character_customization -> a fresh clone link-errors without it
        Marker   = 'source_data\wawmodels.gdt'
        Link     = 'BO3 Ultimis.rar (user download 2026-07-04). Pure assets, NO scripts. README: comment core_common.csv customizationtable line + add customizationtable,zm_character_customization to usermap zone (we add the zone line; the core_common.csv edit is SKIPPED unless the stock crew still shows - split-install core is prebuilt + usermap loads last). PATCH AFTER (RE)INSTALL: the pack forgot Nikolai hair GDT entries (only ships i_c_zom_der_nikolai_head_hair_c.tiff) so his hair stubs to $default grey - re-add the image i_c_zom_der_nikolai_head_hair_c + material mtl_c_zom_der_nikolai_head_hair to wawmodels.gdt (cloned from Dempsey hair, colorMap -> nikolai _c; backup wawmodels.gdt.acc-hairfix-orig) then gdtdb /update. Personal/testing - CREDITS/IP review before any public Workshop release.'
        Paths    = @(
            'model_export\wawmodels',
            'texture_assets\wawmodels',
            'source_data\wawmodels.gdt'
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
            # Red-team fix 2026-07-10: the old 'ai_robot_*'/'ai_cmpn_*' wildcards
            # matched NOTHING (the 440 xanims live one level deeper, inside the
            # c_zom_zod_robot_protector subfolder) - dead entries since install:
            'xanim_export\black_ops_3\c_zom_zod_robot_protector',
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
            # 2026-07-10 audit: zm_ai_apothicon_fury.csv also references 24 wavs in
            # these 4 sibling dirs the rar ships:
            'sound_assets\zmb\ai\attack',
            'sound_assets\zmb\ai\meatball',
            'sound_assets\zmb\ai\raz',
            'sound_assets\zmb\ai\spiderqueen',
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
        Provides = 'Tac-19, Five-seven, ASM1, AK-47, AE4, Ripper (+ FAL), s4_klauser (VG Luger, C-tier box pistol, user 2026-07-05). PATCH AFTER (RE)INSTALL of Skye_VG_Klauser: the s4_klauser_up (PaP) block ships a baked Nydar reflex optic whose vm_/wm_s4_reflex_nydar models are absent -> the PaP weapon FAILS to load. Blank the 6 optic fields on the _up block (attachViewModel1/2, attachWorldModel1, attachViewModelTag1/2, attachWorldModelTag1 -> "") to match the base = iron sights, then gdtdb /update. Backup skye_s4_klauser.gdt.acc-optic-orig. (Same install-side-GDT-patch caveat as the AK-74u altWeapon fix - not repo-tracked.) The 2 leftover mtl/i_optic_nydar_00 errors are cosmetic/waived (weapon loads).'
        Required = $true
        Marker   = 'model_export\skye_ports'
        Link     = 'UGX Master Hub https://www.ugx-mods.com/forum/full-weapons/84/skyes-weapon-ports-to-bo3-master-hub/16874/'
        Paths    = @(
            'model_export\skye_ports',
            'xanim_export\skye_ports',
            'sound_assets\skye_ports',
            'share\raw\fx\skye_efx',
            'source_data\skye_*.gdt',
            # Our install-side twin GDT cloned from the Skye t6_war_machine blocks
            # (rip-derived text; generator rescued to tools/oneshots 2026-07-10;
            # wildcard also grabs the .acc-*-orig balance backups):
            'source_data\acc_war_machine_twins.gdt*',
            # Skye-common techsetdefs (back the waived mtl_origins_camo family):
            'share\raw\techsetdefs_stable\geometry_advanced\lit_micro_tile_triple_mix_advanced_camo.techsetdef',
            'share\raw\techsetdefs_stable_toolsgfx\geometry_advanced\lit_micro_tile_triple_mix_advanced_camo.techsetdef',
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
        Provides = 'Ronan-derived rip ART only (Apr-2023 PNGs: acc_perk_*_base/mega, i_acc_perk_phd/cherry_*, i_acc_powerup_*, pap-tier hexshield .acc-hexshield-orig backups). SPLIT 2026-07-10: the hand-written acc_perk_shaders.gdt + all custom July-2026 art (i_acc_badge_*, i_acc_oc_tier*, i_acc_pap_tier*, i_acc_data_shard, acc_blank) are now GIT-TRACKED in repo source_data/ and deploy via tools/deploy_perk_shaders.ps1 — only the rip PNGs stay gitignored and ride this pack.'
        Required = $true
        # Marker must be a RIP-ONLY file the repo deploys can never create — the
        # GDT was the old marker, but deploy_perk_shaders.ps1 now creates it from
        # the repo, which made the check a permanent false [PASS] (red-team fix):
        Marker   = 'source_data\acc_perk_shaders\_images\acc_perk_jugg_base.png'
        Link     = 'Private zip only (art is game-rip-derived, no public link). RESTORE ORDER on a fresh machine: unpack this zip FIRST (seeds the install-side Ronan PNGs; install _images also holds 16 vestigial i_acc_perk_* dupes referenced by no GDT), THEN run tools/deploy_perk_shaders.ps1 to overlay the repo-tracked GDT + custom art.'
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
        Name     = 'West Ammo Crates (ammo-crate station model)'
        Author   = 'Westchief596 ([West] Ammo Crates pack); crate model + textures ZeRoY; tester Shidouri'
        Provides = 'xmodel west_ammo_crate_model + 1 material + 2 textures (ZeRoY S4 ammo crate, 29x33x25) - the 3 buyable Ammo Crate stations (_acc_ammo_crate.gsc; replaced the stock Shangri-La stack 2026-07-12). MODEL-ONLY lift - the pack GSC/sounds/prefab are NOT installed (we keep our own buy logic). NO _col LOD -> clip-dependent (add_prop_clips.js ammo_crate_l2/_l5/paradise_ammo_crate).'
        Required = $true   # the .zone has xmodel,west_ammo_crate_model -> a fresh clone link-errors without it
        Marker   = 'source_data\acc_west_ammo_crate.gdt'
        Link     = '"[West] Ammo Crates.zip" (user download 2026-07-12). Install: pack GDT -> source_data\acc_west_ammo_crate.gdt (xmodel filename is ..\_custom\...-relative, so the GDT must sit at source_data ROOT, not a subfolder) + the 2 pngs/XMODEL_BIN -> _custom\westchief596\ammo_crate; gdtdb /update.'
        Paths    = @(
            'source_data\acc_west_ammo_crate.gdt',
            '_custom\westchief596\ammo_crate'
        )
    },
    @{
        Name     = 'CW power-direction arrows (dogcanary wall decals)'
        Author   = 'DOGCANARY (rip pack "Images arrow coldwar dogcanary"); art Treyarch (BOCW dark-aether wall scrawls)'
        Provides = '11 materials arrow_power_coldwar[1-10] + 11 images (lit_emissive_scroll_transparent - glowing animated scroll): directional arrows (blank=right, 4=left, 2=up-right) + words (1=POWER, 5=ENGINE, 6=VENT, 7=STAIRS, 8=ASSEMBLE, 9=PASSWORD, 3=FAMILY, 10=STOLEN). Used as inline worldspawn chalk-recipe meshes pointing at the Bus Station power switch (map ACC POWER-DIRECTION ARROWS section, render test 2026-07-12).'
        Required = $true   # the .map worldspawn meshes reference arrow_power_coldwar1/4 -> cod2map fails "missing material" without it
        Marker   = 'model_export\codimages\arrow_coldwar_dogcanary\arrow_power_coldwar_dogcanary.gdt'
        Link     = '"Images arrow coldwar dogcanary.rar" (user download 2026-07-12). Install: drop the pack model_export\codimages + model_export\_modelos_dogcanary folders into the tools-root model_export (both gdtdb-scanned as-is); gdtdb /update.'
        Paths    = @(
            'model_export\codimages\arrow_coldwar_dogcanary',
            'model_export\_modelos_dogcanary\arrow_coldwar_power'
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
            'source_data\fanatic\ww2\ww2_power_switch.gdt'
            # (map_source\_prefabs\acc\power_switch_ww2.map dropped 2026-07-10: our
            # clone prefab is git-tracked + synced by sync_to_modtools now.)
        )
    },
    @{
        Name     = 'Kortifex Announcer (Vanguard VO, full announcer migration)'
        Author   = 'westchief596 ([West] pack; rip tools dest1yo Cordycep; VO Treyarch/Activision)'
        Provides = '46 Kortifex announcer wavs + the stock vox_zmba_* override alias CSV (share\raw\sound\aliases\west\vg_kortifex_ann.csv). Extra 29 aliases = repo sound/aliases/acc_kortifex_extra.csv; engine = _acc_kortifex.gsc.'
        Required = $true   # szc references west/vg_kortifex_ann.csv + acc_kortifex_extra.csv FileSpecs point at these wavs
        Marker   = 'sound_assets\west\ann\kortifex'
        Link     = 'user download "[West] Kortifex Announcer.zip"'
        Paths    = @(
            'sound_assets\west\ann\kortifex',
            'share\raw\sound\aliases\west\vg_kortifex_ann.csv'
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
        Provides = 'ONE pilot material t10_brick_stone_wall_rough_dark + images (docs/20_atmosphere_and_materials.md face-techset trap verdict: LIKELY-TRAP; not on any face, cannot affect builds)'
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
        Name     = 'MidgetBlaster T7 Assets V2.7 (items slice - 8 boss-item pickup models)'
        Author   = 'MidgetBlaster (T7 rips; tools: Spiki, Scobalula, Serious)'
        Provides = 'REAL boss-item pickup xmodels replacing the placeholder orbs/brick (docs/09_boss_items.md, 2026-07-08): p7_spl_first_aid_box (Repair Kit), p7_wes_money_bag (Loot Stash), p7_ra2_tool_vintage_horseshoe (Lucky Horseshoe), p7_zm_mob_vial_surgical_lrg (Phase Serum), p7_ban_debris_car_carburetor (Turbocharger). EXTENDED 2026-07-15 (acc_t7_props_items2.gdt, second GDT same slice): p7_zm_ctl_ammo_flak_bullet_01 (High Caliber Rounds), p7_zm_ctl_deathray_sphere_coil (Plasma Generator), projectile_t7_drone_amws_missile (Warhead Bomber) - their bins ride the castle/stalingrad map dirs already packed by the deco/stations slices. Same carve pipeline as the pilot slice: LOD xmodel_bins + shipped PNG maps; missing colormaps reference their stock i_ names (resolve from fastfiles, errorlog-verified).'
        Required = $true   # zone has all 8 xmodel lines; _acc_boss_items precaches + spawns them
        Marker   = 'source_data\acc_t7_props_items.gdt'
        Link     = 'User rar "T7 Assets V2.7.rar" (Downloads) - keep compressed as the prop library; extract per-prop slices on demand (spike report 2026-07-02)'
        Paths    = @(
            'source_data\acc_t7_props_items.gdt',
            'source_data\acc_t7_props_items2.gdt',
            'model_export\_midgetblaster\props\p7_mp_waterpark',
            'model_export\_midgetblaster\props\p7_mp_wes',
            'model_export\_midgetblaster\props\p7_mp_rome',
            'model_export\_midgetblaster\props\p7_zm_genesis',
            'model_export\_midgetblaster\props\p7_mp_banzai'
        )
    },
    @{
        Name     = 'MidgetBlaster T7 Assets V2.7 (stations slice - 10 interactive-station models)'
        Author   = 'MidgetBlaster (T7 rips; tools: Spiki, Scobalula, Serious)'
        Provides = 'STATION REMODEL xmodels (docs/09_boss_items.md (stations; was docs/52), 2026-07-09) - one distinct model per interactive station: p7_cry_cryogen_pod_exterior (Exo), p7_zm_isl_table_operating (Implant Bench), p7_zm_sta_drop_pod_console_blue (Neural Bay), p7_zm_sta_dragon_network_data_terminal (Overclock), p7_ram_altar (Glitch Altar), p7_ris_generator_lg_01_blue (Reactor), p7_con_cargo_train_armory_cabinet (Armory rack), p7_out_monitor_atm (Transfer Vault x4), p7_zm_sha_crate_ammo_closed_sml_stack_full (Ammo Crate), p7_zm_sta_computer_tower_01 (Data Cache). GDT auto-generated by tools/gen_t7_carve_gdt.js (all-LOD material scan, BulletCollisionLOD High). (The 11th station, the Wonderfizz bottle exchange, is stock - no carve.)'
        Required = $true   # zone has all 10 xmodel lines; 9 _acc_ modules precache + spawn them
        Marker   = 'source_data\acc_t7_props_stations.gdt'
        Link     = 'User rar "T7 Assets V2.7.rar" (Downloads) - keep compressed as the prop library; extract per-prop slices on demand (spike report 2026-07-02)'
        Paths    = @(
            'source_data\acc_t7_props_stations.gdt',
            'model_export\_midgetblaster\props\p7_mp_citadel',
            'model_export\_midgetblaster\props\p7_zm_island',
            'model_export\_midgetblaster\props\p7_mp_cryogen',
            'model_export\_midgetblaster\props\p7_zm_stalingrad',
            'model_export\_midgetblaster\props\p7_mp_city',
            'model_export\_midgetblaster\props\p7_mp_conduit',
            'model_export\_midgetblaster\props\p7_mp_rise',
            'model_export\_midgetblaster\props\p7_zm_temple'
        )
    },
    @{
        Name     = 'MidgetBlaster T7 Assets V2.7 (deco slice - Infected Descent abyss props)'
        Author   = 'MidgetBlaster (T7 rips; tools: Spiki, Scobalula, Serious)'
        Provides = 'INFECTED DESCENT abyss-floor decoration xmodels (docs/30 enhancement, locked plan 2026-07-12). Phase 0: p7_zm_isl_specimen_container_lg (L4 "Specimen Vault" hero - Zetsubou LARGE specimen tank 63x65x120, glass+interior+body-silhouette materials + the 2 shipped _images PNGs) + _egg (Phase-2 clutter). NO _col LOD -> clip via add_prop_clips when placed in a lane. CARVE TRAPS (2026-07-12): the mutant vats (specimen_container_mutant/_2/_3) are SKINNED (junk j_ joints in the Greyhound bins) -> linker convert-fail as rigid carves, STATIC variants only; and strip stock-named materials the carve tool re-authors (global_invisible -> gdtdb "Duplicate material"). Grows batch-by-batch as Phases 1-2 carve the remaining L2/L3/L5 palettes (batches A-I in the locked plan). GDT auto-generated by tools/gen_t7_carve_gdt.js; the island model folders land inside the stations slice''s pack path (props\p7_zm_island), so only NEW props\<map> dirs need adding here.'
        Required = $true   # zone has xmodel,p7_zm_isl_specimen_container_lg; _acc_abyss_deco spawns it
        Marker   = 'source_data\acc_t7_props_deco.gdt'
        Link     = 'User rar "T7 Assets V2.7.rar" (Downloads) - keep compressed as the prop library; extract per-prop slices on demand (staging: Downloads\_t7x - short path, the 260-char rar trap)'
        Paths    = @(
            'source_data\acc_t7_props_deco.gdt',
            # Phase-1 batches (2026-07-12): 4 map dirs no other slice packs. The rest of the
            # deco models ride existing slice paths (stations: island/citadel/cryogen/city/
            # conduit/rise/temple/stalingrad; items: genesis/banzai/wes/rome/waterpark;
            # pilot: moon/crucible).
            'model_export\_midgetblaster\props\p7_zm_asylum',
            'model_export\_midgetblaster\props\p7_zm_cosmodrome',
            'model_export\_midgetblaster\props\p7_zm_castle',
            'model_export\_midgetblaster\props\p7_cairo_lotus3'
        )
    },
    @{
        Name     = 'Blast-O-Matic v1.2 (CW DOA energy blaster)'
        Author   = 'Owens (weapon port/FX/prefab); custom camos GDT tagged _mg'
        Provides = 't9_semiauto_cosplay(_up) wonder weapon - box S+ slot, dev-spawn gun, fully twinned (14 hand-built projectile twins in the repo variants GDT). README claims a devraw "Bo3 Gun Pack" dependency - empirically REFUTED (all dangling refs are stock-shipped assets; CHANGELOG 2026-07-03). PATCHES REQUIRED AFTER (RE)INSTALL (all found/applied 2026-07-03, .acc-orig backups next to patched files): (1) both share\raw\fx\_owens_effects\t9_semiauto_cosplay\fx_raygun_geotrail_{blue,red}_doa.efx line 787 blanked to emission ""; - the pack references stock-fastfile-only fx zombie/fx_raygun_trail_ring_doa (no raw .efx exists); (2) weapon GDT wpn_t9_shotgun_semiauto_cb_cosplay.gdt: aiVsPlayerAccuracyGraph "pistol.accu" blanked on both entries (file does not exist under accuracy\aivsplayer\) - EITHER dangling ref HARD-FAILS the whole weapon conversion (0 weapon rows in assetinfo, gun silently absent; weaponfull twins = native DB-load crash instead); (3) balance: base entry clipSize 7 -> 5 + maxAmmo/startAmmo 12 (= 60 reserve), _up entry maxAmmo/startAmmo 80 -> 6 (= 120 reserve) - NOTE maxAmmo/startAmmo count MAGAZINES not rounds (reserve = maxAmmo x clipSize, docs/33_pap_pricing_tiers.md); twins GDT carries the same. After patching: full gdtdb rebuild.'
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
            # (share\raw\sound\aliases\_owens_weapons.csv dropped 2026-07-10: the
            # hand-patched CSV is git-tracked at repo sound/aliases/ and deployed
            # by sync_to_modtools - zipping the install copy would roll back the
            # 26 patched lines on unpack.)
            # 2026-07-10 audit fixes: the pack's wavs actually install to _bocw (the
            # old 'sound_assets\_owens_weapons' path never existed = dangling), the
            # _mg camo GDT references source images under texture_assets, and the
            # install drops an (inert) sound template:
            'sound_assets\_bocw',
            'texture_assets\_mg_custom_images',
            'share\raw\sound\templates\template_skye_t9_sounds.csv',
            'map_source\_prefabs\owens_prefabs'
        )
    },
    @{
        # Installed 2026-07-08 (Panzer Soldat = 4th roster boss). Layout notes: the 5 source_data
        # GDTs are CURATED copies of the pack's (Panzer_soldat*.gdt renamed; HB21-duplicate blocks
        # STRIPPED: flamethrower_beam_3p_zm_mechz + electric_arc_beam_electroball beams live in
        # t7_beams.gdt, one shared vaultover xanim in t7_zombie_animations.gdt). Stray pack GDTs
        # inside model_export\Custom\Panzer are quarantined as *.gdt_DISABLED_ACC (dupes/joke
        # variants). NO fx copied: the HB21 FX Library ships every mech .efx (dlc1/castle +
        # dlc4/genesis + dlc5/tomb) incl. the electroball weapon's fx_wpn_115_blob_exp. Sound
        # alias csv is FILTERED (only zmb\ai\mechz rows - the pack csv also referenced castle-crew
        # vox/hellhound/drone wavs we do not ship).
        Name     = 'Panzer / mechz (Panzer Soldat roster boss)'
        Author   = 'Spiki'
        Provides = 'Panzer Soldat boss (aitype archetype_zm_mechz_genesis)'
        Required = $true
        Marker   = 'source_data\mechz_spiki.gdt'
        Link     = 'modme #3087 (MEGA, password Chungus4Prez; verified live 2026-07-03 - base https://mega.nz/#!Clh0VYCY!gS1r0bmJLQb6VQAq2dcNs3i4zbMRohTY8S5fIyoDhzU + update https://mega.nz/file/65Aj3aRB#mjw-His7ZbGUs974tVRC8XbziAGlaIgEjn19NpqAgs8; recipe tools/_panzer_stash/README.md)'
        Paths    = @(
            'model_export\Custom\Panzer',
            'source_data\mechz_spiki.gdt',
            'source_data\mechz_spiki_anims.gdt',
            'source_data\mechz_spiki_trav.gdt',
            'source_data\mechz_spiki_origins_models.gdt',
            'source_data\mechz_spiki_table.gdt',
            'share\raw\animtrees\mechz_tomb.atr',
            'share\raw\animtrees\mechz_claw.atr',
            'share\raw\animstatemachines\mechz*',
            'share\raw\animtables\mechz*',
            'share\raw\behavior\mechz*',
            'share\raw\fx\custom\Fire\panzer_booster*',
            'share\raw\sound\aliases\mechz_spiki.csv',
            'sound_assets\zmb\ai\mechz'
        )
    },
    @{
        Name     = 'HB21 Elemental Bows v1.0.0 (Fire Bow wonder weapon)'
        Author   = 'HarryBo21 + credits list (see pack INSTRUCTIONS.txt / CREDITS.md)'
        Provides = 'Der Eisendrache elemental bows suite (base + storm/rune_prison/wolf_howl/demongate). We box-wire ONLY the DEMONGATE (fire) bow; all 5 script pairs load for clientfield lockstep (entry gsc/csc). Assets ride include,hb21_elemental_bows (share/zone_source zpkg). Sounds: share/raw/sound/aliases/elemental_bow_sounds.csv + sound_assets (szc source added). INSTALL FIX (2026-07-07): the pack GDT referenced a phantom rpg.accu accuracy graph (absent on this install) -> silent weapon drop; retargeted all 48 refs in source_data\wpn_t7_zmb_bow.gdt to default.accu (backup wpn_t7_zmb_bow.gdt.acc-accu-backup). Requires the 4 HB21 dependency packs below.'
        Required = $true   # zone include,hb21_elemental_bows + the 5 scriptparsetree pairs link-error without it
        Marker   = 'share\zone_source\hb21_elemental_bows.zpkg'
        Link     = 'hb21_elemental_bows_v1.0.0.rar (137 MB) - devraw.net/assets / icegrenade.co.uk/assets (mega jHhRCYyY). Scripts vendored into repo scripts/zm/_zm_weap_elemental_bow*.gsc/.csc; map prefabs (pedestals) NOT installed - box-only.'
        Paths    = @(
            'share\zone_source\hb21_elemental_bows.zpkg',
            'share\raw\fx\dlc1\zmb_weapon',
            'share\raw\sound\aliases\elemental_bow_sounds.csv',
            'source_data\wpn_t7_zmb_bow.gdt',
            'source_data\c_zom_chomper.gdt',
            'source_data\p7_fxanim_zm_bow_rune_prison.gdt',
            'source_data\p7_zm_ctl_bow_pedestal.gdt',
            'source_data\rune_prison_death_skull.gdt',
            'sound_assets\wpn',
            # 2026-07-10 audit: elemental_bow_sounds.csv FileSpecs also reference 65
            # wavs OUTSIDE sound_assets\wpn (rar verified to ship all four dirs):
            'sound_assets\amb',
            'sound_assets\fly\weapon\reload',
            'sound_assets\zmb\egg',
            'sound_assets\zmb\level\zm_castle',
            'model_export\black_ops_3',
            'xanim_export\black_ops_3'
        )
    },
    @{
        Name     = 'Leviathan Axe (GoW wonder melee)'
        Author   = 'WetEgg (port) / M5_Prodigy (model+textures) / J.G. (concept) / DeLeon (model, CC-BY-4.0 skfb.ly/orATq)'
        Provides = 'leviathan_zm + leviathan_up_zm melee weapon (runtime names leviathan / leviathan_up - the _zm suffix strips). GDT rides _custom\wetegg\leviathanaxe via bin\converter_gdt_dirs_0.txt (_custom entry prepended 2026-07-07 - the axe pack''s own install step; re-add the line if the tools update resets that file).'
        Required = $true   # zone weapon,leviathan_zm lines link-error without it
        Marker   = '_custom\wetegg\leviathanaxe\leviathanaxe.gdt'
        Link     = 'leviathanaxe.rar (226 MB) - WetEgg release (Discord WetEgg#7000; user download 2026-07-07)'
        Paths    = @(
            '_custom\wetegg\leviathanaxe'
        )
    },
    @{
        Name     = 'HB21 FX Library v2.1.0 (Fire Bow dependency)'
        Author   = 'HarryBo21 / Scobalula / DTZxPorter (DEVRAW distribution)'
        Provides = 'bow_explosion impacts-table + gfx_* FX materials the elemental bows reference. INSTALL FIX (2026-07-07): its broad model dump conflicts with our packs in gdtdb - DISABLE p7_zm_sta_temp_heroes_pose.gdt (renamed +_DISABLED_ACC; dup of wawmodels.gdt) and STRIP 4 dup FX-image blocks from black_ops_3_fx.gdt (fxt_lightning_beam_trail2_specialty / fxt_smk_trail_tracer_chaser / fxt_smk_trail_wispy / gfx_sam_trail_smk_em) so it does not clobber the existing bo3_gfx.gdt. Do NOT install the model_export/texture_assets model dump beyond what gdtdb needs.'
        Required = $true   # bows drop without bow_explosion + gfx_* materials
        Marker   = 'source_data\black_ops_3_fx.gdt'
        Link     = 'hb21_black_ops_3_fx_library_v2.1.0.rar (468 MB) - devraw.net/approved-assets/devraw/fx-assets (mega 6WYARBxB). NOTE the icegrenade mirror truncates MEGA keys - use the devraw link.'
        Paths    = @(
            'source_data\black_ops_3_fx.gdt',
            'source_data\black_ops_2_fx.gdt',
            'source_data\fxuse_*.gdt',
            # 2026-07-10 audit: these ship in the same FX-library extraction batch
            # and are load-bearing (zone beam,flamethrower_beam_3p_zm_mechz lives in
            # t7_beams.gdt after the Panzer dup-strip; battery GDT is zone xmodel'd;
            # the texture_assets dirs are the GDTs' source images):
            'source_data\t7_beams.gdt',
            'source_data\p7_zm_ctl_battery_ceramic.gdt',
            'texture_assets\waw',
            'texture_assets\black_ops_2',
            'texture_assets\black_ops_3',
            'share\raw\fx'
        )
    },
    @{
        Name     = 'HB21 New BT Stuff v3.0.0 (Fire Bow dependency)'
        Author   = 'HarryBo21 + credits list (DEVRAW distribution)'
        Provides = 'zombie demongate swarm-react xanims + t7_zombie_animations.gdt (bows drop without them). We install the ASSETS ONLY (source_data + xanim_export + share). The pack ALSO ships a core zombie behavior-tree override (usermaps: _hb21_zm_behavior.gsc + zm_zombie.ai_bt/.ai_asm + animtables) that we DID NOT install (modifies shared zombie AI); add it only if the demon-gate swarm VISUAL is needed. NOTE the icegrenade mirror truncates its MEGA key to 33 chars (invalid) - the full key is on devraw / recovered via wayback.'
        Required = $true   # demongate swarm-react anims dangle without it
        Marker   = 'source_data\t7_zombie_animations.gdt'
        Link     = 'hb21_new_bt_stuff_v3.0.0.rar (236 MB) - devraw.net/assets (mega bSAxWQJS#weh95pMZWuSmnV0kpgzt5mFtk7qZ4xq06E23PBOOOMQ - FULL key)'
        Paths    = @(
            'source_data\t7_zombie_animations.gdt',
            'source_data\t6_zombie_anims.gdt',
            'xanim_export\black_ops_3',
            'archetypes'
        )
    },
    @{
        Name     = 'HB21 Rumbles v2.0.0 + Physics Presets v1.0.0 (Fire Bow deps, tiny)'
        Author   = 'HarryBo21 (DEVRAW distribution)'
        Provides = 'bow_fire / grenade_rumble rumble presets (t7_rumbles.gdt + share\raw\rumble\*.rmb) and t7_phys_presets.gdt. Both tiny (47 KB / 7 KB); no conflicts observed.'
        Required = $true   # bow_fire rumble ref dangles without rumbles; physpreset ref without physics
        Marker   = 'source_data\t7_rumbles.gdt'
        Link     = 'hb21_rumbles_v2.0.0.rar (mega OaJnTQbD) + hb21_physics_presets_v1.0.0.rar (mega HCZkTbJT) - devraw.net/assets'
        Paths    = @(
            'source_data\t7_rumbles.gdt',
            'source_data\t7_phys_presets.gdt',
            'share\raw\rumble'
        )
    },
    @{
        Name     = 'eMoX Jukebox Menu (model-only lift)'
        Author   = 'eMoX (kit; base craftable lua lilrifa); model Infinity Ward (IW cp_town_jukebox rip)'
        Provides = 'xmodel cp_town_jukebox (+_off variant, unused) + 5 materials / 13 images - the trench JUKEBOX machine spawned by _acc_jukebox.gsc (replaced the 3 teddy bears 2026-07-09). The pack''s LUI menu / GSC / radio-song wavs / prefab are NOT installed - our own GSC (1 Data Shard + 1000 pts, random song) drives it.'
        Required = $true   # zone has xmodel,cp_town_jukebox -> a fresh clone link-errors without it
        Marker   = 'source_data\iw_jukebox.gdt'
        Link     = 'User zip "eMoX - Jukebox Menu.zip" (Downloads, 2026-07-09). Model-only install: model_export\infinite_warfare\xmodels\cp_town_jukebox + source_data\iw_jukebox.gdt, then gdtdb /update (19 assets).'
        Paths    = @(
            'source_data\iw_jukebox.gdt',
            'model_export\infinite_warfare\xmodels\cp_town_jukebox'
        )
    },
    @{
        # Added by the 2026-07-10 asset-portability audit: this pack previously had
        # NO manifest entry at all (its GDT was only incidentally half-covered by the
        # OPTIONAL 54-Immortals 'source_data\zeroy' folder path, which -Required
        # $false packs skip by default). The install-side GDTs are PATCHED IN PLACE
        # (fireDelay/sprintout/movespeed/rof/reload/recoil/fire-sound/legend-skin
        # passes, .acc-*-orig backups beside them; the patch scripts were scratchpad-
        # only and are GONE) — this zip is the ONLY carrier of the patched state.
        # The 38 apex twin blocks in git-tracked source_data\acc_weapon_variants.gdt
        # are safe in the repo. acc_havoc_chg.gdt is an abandoned-approach leftover
        # (not zone-referenced) and is deliberately NOT listed.
        Name     = 'Apex Weapons (zeroy port)'
        Author   = 'zeroy & ElTitoPricus (Apex Legends rips via Legion/DTZxPorter; Respawn/EA orig)'
        Provides = '10 zone-demanded apex_* box weapons (+_up_zm PaP blocks in acc_apex_up.gdt) incl. the Havoc charge-gun (docs/21_adding_a_gun_runbook.md, apex-weapons-pack-integration memory). Repo-side: sound/aliases/acc_apex_weapons.csv (hand-curated, git-tracked) + apex twins in acc_weapon_variants.gdt (git-tracked).'
        Required = $true
        Marker   = 'source_data\zeroy\APEX_BO3.gdt'
        Link     = 'zm_apex_weapons.zip (user download 2026-07-06, Downloads). Runtime names drop the _zm suffix (memory apex-weapons-pack-integration). After (re)install from the ORIGINAL zip the balance patches are lost — prefer this manifest zip which carries the patched GDTs + backups.'
        Paths    = @(
            'source_data\zeroy\APEX_BO3.gdt*',
            'source_data\acc_apex_up.gdt*',
            'model_export\apex',
            'xanim_export\apex',
            'sound_assets\apex',
            'share\raw\sound\aliases\zm_apex_weapons.csv',
            # ACC-CUSTOM weapon-bolt FX (git-AUTHORED, deployed install-side; ride this bundle so a fresh
            # install links). acc_cj_bolt_violet = THE CYBERJACK shot bolt (apex_lstar chassis, docs/43);
            # the ttk geotrails share the acc_ttk_bolt_fx clientfield (Blast-O-Matic + Triple Take + CYBERJACK).
            'share\raw\fx\acc\acc_cj_bolt_violet.efx',
            'share\raw\fx\acc\acc_ttk_geotrail_blue.efx',
            'share\raw\fx\acc\acc_ttk_geotrail_red.efx'
        )
    },
    @{
        # Added by the 2026-07-10 asset-portability audit: these wavs are
        # deliberately GITIGNORED (copyrighted placeholder tracks — see
        # .gitignore + CREDITS.md IP gate) but were previously in NO transfer channel
        # at all; a machine wipe destroyed the originals once already (2026-07-01
        # move). The private zip is the correct carrier for licensed test audio.
        # Swap for CC0 before any Public Workshop release.
        # 2026-07-10 (2nd audit pass): ee_song_3.wav ADDED here — it is the same
        # 🚫-DO-NOT-PUBLISH class as 115/paradise_calm (Rosa Walton, Cyberpunk:
        # Edgerunners) but had leaked into git (commit 90aa25b) and rode NO manifest
        # entry. Untracked + gitignored to match its siblings; now carried by this zip.
        Name     = 'Copyrighted placeholder music (COPYRIGHTED - private transfer only)'
        Author   = '115 = Treyarch/Kevin Sherwood (Remaster since 2026-07-18); paradise_calm = Nintendo (Mario Stage Win); ee_song_3 = Rosa Walton/Hallie Coggins (Cyberpunk: Edgerunners, CD PROJEKT RED); ee_song_4/5/6/7 = Kevin Sherwood et al. (CoD-zombies EE songs: Dead Again / Beauty of Annihilation / Can You Hear Me? Come In / The Gift)'
        Provides = 'sound_assets\acc\music\115.wav + paradise_calm.wav (finale) + ee_song_3..7.wav (jukebox songs #3-#7, 4-7 added 2026-07-18) — the gitignored copyrighted placeholder tracks the szc/alias CSVs reference; sound-bank build fails without files at these paths'
        Required = $true
        Marker   = 'sound_assets\acc\music\115.wav'
        Link     = 'No download link (copyrighted rips) — teammate zip only. Any 48k/16-bit stereo wav at these paths satisfies the build if the real ones are unavailable (tools/resample48k.js converts).'
        Paths    = @(
            'sound_assets\acc\music\115.wav',
            'sound_assets\acc\music\paradise_calm.wav',
            'sound_assets\acc\music\ee_song_3.wav',
            'sound_assets\acc\music\ee_song_4.wav',
            'sound_assets\acc\music\ee_song_5.wav',
            'sound_assets\acc\music\ee_song_6.wav',
            'sound_assets\acc\music\ee_song_7.wav'
        )
    },
    @{
        Name     = 'eMoX T8 Delayed Powerup Drop'
        Author   = 'eMoX'
        Provides = 'BO4-style 1.5s pre-drop FX + sound before every power-up materializes. Install-side: 4 .efx (share\raw\fx\_mori2), sound alias csv, 2 wavs (48k/16-bit verified), emox_t9_fx_spark.gdt (material+image) + texture tif. Repo-side (git, NOT this zip): scripts/zm/_zm_powerups.gsc STOCK OVERRIDE + .gsh, zone + szc lines, level-thread caller fixes in mechz_spiki/nsz_brutus.'
        Required = $true   # zone references fx,_mori2/* + the szc references the alias csv -> fresh clone link-errors without it
        Marker   = 'source_data\_emox\emox_t9_fx_spark.gdt'
        Link     = '"eMoX - T8 Powerup Delayed Drop.zip" (user download 2026-07-11, Downloads). PATCH AFTER (RE)INSTALL of Mod Tools: comment out line `scriptparsetree,scripts/zm/_zm_powerups.gsc` in <tools>\zone_source\all\assetlist\zm_patch.csv (backup kept at zm_patch.csv.acc-orig-backup) — WITHOUT this the linker dedupe silently drops our override and drops revert to instant (no crash, feature just vanishes). Leave the .csc line alone. Then gdtdb /update.'
        Paths    = @(
            'source_data\_emox\emox_t9_fx_spark.gdt',
            'texture_assets\_emox\zm_mori2\t9_fxt_spark_omni.tif',
            'sound_assets\_emox\t8\powerup',
            'share\raw\fx\_mori2\t8_powerup_pre_drop.efx',
            'share\raw\fx\_mori2\t8_powerup_pre_drop_solo.efx',
            'share\raw\fx\_mori2\t8_powerup_pre_drop_pop.efx',
            'share\raw\fx\_mori2\t8_powerup_pre_drop_pop_solo.efx',
            'share\raw\sound\aliases\emox_t8_powerups_delayed_drop.csv'
        )
    },
    @{
        Name     = 'BO2 TranZit props (Zombie115201 static-xmodel pack)'
        Author   = 'Zombie115201 (export/setup); rip tools Scobalula/DTZxPorter/Ultra/Blakintosh/Eric Maynard/ID-Daemon / Treyarch (orig BO2 Green Run art)'
        Provides = '80 BO2 TranZit (Green Run: bus depot / town / diner / farm) STATIC prop xmodels (prefix p7_zm_tra_*, grouped as per-prop GDTs under model_export). Surface set-dressing for the plain zones; PILOT = Bus Station transit concourse (_acc_surface_deco.gsc, 20 models zoned). Model-only lift - install the model_export tree; the pack `optional\` folder (a MidgetBlaster DUDV-image correction + fxanim/character extras) is NOT installed. TRAP: some props share textures with the MidgetBlaster T7 dump - p7_zm_tra_bookshelf_wood_dmg misses its Verruckt materials, so it is deliberately NOT zoned (drop or carve the 3 mtl_p7_zm_ver_bookshelf_* materials to use it).'
        Required = $true   # zone references xmodel,p7_zm_tra_* -> a fresh clone link-errors without it
        Marker   = 'model_export\t7_props_dlc\zm\dlc5\zm_transit\p7_zm_tra_bench\p7_zm_tra_bench.gdt'
        Link     = 'p7_zm_transit_assets.zip (444 MB, user download 2026-07-16). Install: drag the archive''s model_export\* into the tools-root model_export (SKIP the optional\ folder), then TOUCH the per-prop *.gdt mtimes under model_export\t7_props_dlc\zm\dlc5\zm_transit (rip timestamps predate gdt.db -> gdtdb''s incremental scan skips them otherwise), then gdtdb /update. Personal/testing - CREDITS/IP review before any public Workshop release.'
        Paths    = @(
            'model_export\t7_props_dlc\zm\dlc5\zm_transit'
        )
    },
    @{
        Name     = 'AW 3D Printer Mystery Box (PLANET)'
        Author   = 'Planet (port + scripts) / Scobalula (export tools) / Sledgehammer-Activision (orig AW Exo Zombies art)'
        Provides = 'The map''s mystery box: dlc_weapon_mystery_box_01 rigged door-rig xmodel + _static base + fx_aw_scanner_laser, 5 xanims (activate/open/close/open_idle/malfunction), aw_mysterbox.gdt (26 assets incl. mc/dr_fx_holo duplicate-render holo material + aw_magic_box_bundle scriptbundle), 3 holo/idle .efx, 4x 48k wavs. Driver scripts are VENDORED in git (scripts/planet/_aw/_zm_aw_mysterybox.gsc/.csc with [acc] shims); alias CSV vendored as sound/aliases/acc_aw_magicbox.csv (normalized to 102 cols).'
        Required = $true   # zone references the scriptbundle/material/fx + map places the xmodels -> a fresh clone link-errors without it
        Marker   = 'source_data\_planet_aw\aw_mysterbox.gdt'
        Link     = 'AW_MAGICBOX.rar (31 MB, user download 2026-07-12; MEGA mega.nz/file/RNUTBaRI#2xEwNgTQROAjv5KfOaqLPNzN3yWblCj_KdrZQfRMKRo). Extract model_export\_aw + xanim_export\_aw + share\raw\fx\_custom\atlas + sound_assets\planet into the tools root; GDT goes to source_data\_planet_aw\ (moved out of the pack''s model_export home) - TOUCH its mtime before gdtdb /update (rar timestamps predate gdt.db). The pack''s share\raw\scripts + sound alias CSV + zpkg are NOT installed (vendored in repo / inlined in the .zone). Credit Planet + Scobalula in CREDITS before any public Workshop release.'
        Paths    = @(
            'source_data\_planet_aw\aw_mysterbox.gdt',
            'source_data\_planet_aw\acc_aw_holo_gold.gdt',   # [acc]-authored GOLD wonder-holo material (dr_fx_holo clone, cg02 tint cyan->gold) - rides this pack since it derives from the pack entry
            'source_data\_planet_aw\acc_aw_holo_green.gdt',  # [acc]-authored GREEN knife-to-share holo (dr_fx_holo clone, cg02 tint cyan->green, user 2026-07-13) - regenerate: clone acc_aw_holo_gold.gdt, rename dr_fx_holo_gold->green, set cg02 0.0/1.0/0.15
            'source_data\_planet_aw\acc_aw_holo_dim.gdt',    # [acc]-authored interact-glow DIM holo (acc_dr_fx_holo_dim; cg02+colorTint x0.35 = the proven ghost-techset dimmer - _acc_interact_glow.csc, v4 2026-07-17)
            'source_data\_planet_aw\acc_aw_holo_dim2.gdt',   # [acc]-authored SPARE deep clone (acc_dr_fx_holo_dim2, currently un-zoned/unused - kept for a future two-level pulse)
            'model_export\_aw',
            'xanim_export\_aw',
            'sound_assets\planet\aw\mysterybox',
            'share\raw\fx\_custom\atlas\aw_magicbox_open.efx',
            'share\raw\fx\_custom\atlas\aw_idle_box_fx.efx',
            'share\raw\fx\_custom\atlas\aw_idle_box_off_fx.efx'
        )
    },
    @{
        Name     = 'Ninjamanny Ascension Zombies (labcoat scientist boss body)'
        Author   = 'Ninjamanny829 (porting) / Raptroes+Aimless (testing) / Scobalula (Greyhound/Hydrax/Gameimageutil) / DTZxPorter (Darkiris) / Treyarch (orig ZC Ascension art)'
        Provides = 'ZC Ascension zombie bodies on the STOCK T7 zombie rig - 3 body types (labcoat / cosmo spacesuit / spetznaz) as full-LOD XMODEL_BINs + gib variants (beheaded/blegsoff/...) + 3 Radiant spawner prefabs + dlchd_ascension_zombies.gdt (1.1MB). p7_zm_dlchd_cosmo_labcoat_body = the SCIENTIST BOSS body (docs/44 - promoted-zombie SetModel path, zero rigging). NOTE: pack zip bundles _images incl. i_c_gen_char_* commons, but the devraw DB row says the pack REQUIRES Ninjamanny Material Common (mega.nz/file/iMIBCbqK#aho0tRTo86fbuGLv6-UeWSCS4ilEWi5wDLywRXS6WdA) - VERIFY at first link (grep build log for missing i_c_gen_*/char_base_fabric images) and install the common pack if they miss.'
        Required = $true   # zone has xmodel,p7_zm_dlchd_cosmo_labcoat_body + 5 cosmo heads (The Scientist boss, docs/44) -> fresh clone link-errors without it
        Marker   = 'source_data\_ninjaman_models\bo3\dlchd_ascension_zombies.gdt'
        Link     = 'ninja_dlchd_ascension_zombies.zip (143 MB, user download 2026-07-17; devraw DB "Ascension Zombie Pack" mega.nz/file/rdwDjBaA#izfzrxL4GMP_bHwlxGCTmYacbrT84tB4fWK2w9YWuNs). Install: unzip into tools root (model_export + map_source\_prefabs + source_data), move howtouse/credits txts into source_data\_ninjaman_models\, TOUCH the GDT, gdtdb /update. Credit Ninjamanny829+Scobalula+DTZxPorter+Treyarch in CREDITS before any public Workshop release.'
        Paths    = @(
            'source_data\_ninjaman_models\bo3\dlchd_ascension_zombies.gdt',
            'model_export\_ninjaman_models\t7\dlchd_ascension_zombies',
            'map_source\_prefabs\zm\_ninjaman_zombie_spawners'
        )
    },
    @{
        Name     = 'HB21 BO3 FX Library v2.1.0 (de-rez / teleporter / electric FX arsenal)'
        Author   = 'HarryBo21 (compilation) / Treyarch (orig BO2+BO3+WaW FX) - the devraw DB "BO3 FX Library" entry'
        Provides = '6,542 .efx (share\raw\fx: BO2+BO3+WaW libraries) + fx-use model_export trees + texture_assets + 64 source_data GDTs (~1,700 assets). Headliners for the boss work (docs/44): dlc0\nuketown\fx_de_rez_ambient/_grey/_vista_beam (the digital-dissolve GLITCH language), dlc0\factory\fx_teleporter_elec_strike(+_os,+sparks)/fx_teleporter_beam_factory, p7_fxp_electric_arc pack, BO2 portal air/elec/fire/ice. Inert until zone-referenced.'
        Required = $true   # zone has fx,dlc0/factory/fx_teleporter_elec_strike_os (de-rez blink zap, docs/44) -> fresh clone link-errors without it
        Marker   = 'source_data\p7_fxp_electric_arc.gdt'
        Link     = 'hb21_black_ops_3_fx_library_v2.1.0.rar (490 MB, user download 2026-07-17; devraw DB mega.nz/file/6WYARBxB#-NUWhmjzCySBXx9FCBpTy_wvjhe5FsyBec7nPKYwOl0). Install (INSTALL-SIDE EDITS REQUIRED, 2026-07-17): 7z-extract, merge share/model_export/texture_assets/source_data into tools root, move README+CHANGELOG to source_data\_hb21_fx_library\, then (1) DELETE source_data\p7_zm_sta_temp_heroes_pose.gdt (Gorod hero statues - mass image collision with wawmodels.gdt/Ultimis) and (2) STRIP 4 duplicate blocks from source_data\black_ops_3_fx.gdt: images fxt_lightning_beam_trail2_specialty / fxt_smk_trail_tracer_chaser / fxt_smk_trail_wispy + material gfx_sam_trail_smk_em (collide with pre-existing bo3_gfx.gdt; scratch gdt_dedupe.js recipe in CHANGELOG 2026-07-17) - then TOUCH all pack GDTs + gdtdb /update (expect ~65 GDTs / ~1,796 assets clean). Credit HarryBo21+Treyarch in CREDITS before any public Workshop release.'
        Paths    = @(
            'source_data\p7_fxp_electric_arc.gdt',
            'source_data\black_ops_3_fx.gdt',
            'share\raw\fx\dlc0\nuketown\fx_de_rez_ambient.efx',
            'share\raw\fx\dlc0\factory\fx_teleporter_elec_strike_os.efx',          # zone-referenced (derez blink zap)
            'share\raw\fx\dlc0\factory\fx_teleporter_elec_strike_sparks_os.efx',   # zone-referenced (phantom sparks layer)
            'model_export\black_ops_3\p7_fxp_electric_arc'
        )
    },
    @{
        Name     = 'BO1 Nixie Numbers FX (coolyer) - Pentagon Thief trail base'
        Author   = 'coolyer (BO3 rebuild, help Rayjiun, upscaled textures Oblight) / Treyarch (orig BO1 fx_misc_nix_numbers)'
        Provides = '3 BO3-native iwfx-3 .efx (fx/misc/numbers_fx/fx_misc_nix_numbers_{normal,random,random_directions}) + material gfx_fxt_misc_nixnumbers_bo1 (GDT + i_fxt_misc_nixnumbers.tif/_r + upscaled up2/up_r2 tiffs). The authentic BO1 115-numbers particle effect - base for the Pentagon Thief red aura (clone normal.efx -> red colorGraph, PlayFxOnTag on a linked tag_origin = BO1 fx_zombie_tech_trail pattern; plan docs/44).'
        Required = $true   # zone has fx,_custom/acc/fx_acc_derez_blink whose material gfx_fxt_misc_nixnumbers_bo1 lives in this pack's GDT -> fresh clone link-errors without it
        Marker   = '_custom\_coolyer\numbers_fx\numbers_fx.gdt'
        Link     = 'numbers_fx.zip (96 KB, user download 2026-07-17; github.com/coolyer/t6_numbers_fx - BO3 release; the t6_numbers_fx-1.0.zip sibling is the BO2 version, NOT needed). Install: drag share\ + _custom\ into the tools root, TOUCH the GDT mtime, gdtdb /update, THEN copy the repo-vendored [acc] tinted clones share\raw\fx\_custom\acc\*.efx into the tools share\raw\fx\_custom\acc\ (regen recipe: tools/tint_numbers_efx.js - cyan de-rez blink 0.25/0.95/1 from the random_directions variant; the red Scientist trail rides docs/44 workstream B). colorGraph ships white 1-1-1 (tint lives in the texture). Credit coolyer/Rayjiun/Oblight in CREDITS before any public Workshop release.'
        Paths    = @(
            '_custom\_coolyer\numbers_fx',
            'share\raw\fx\misc\numbers_fx',
            'share\raw\fx\_custom\acc\fx_acc_derez_blink.efx',           # [acc]-authored vendored clone, cyan (repo share/raw/fx/_custom/acc)
            'share\raw\fx\_custom\acc\fx_acc_derez_blink_phantom.efx',   # [acc]-authored vendored clone, neon yellow (zone-referenced, phantom warps)
            'share\raw\fx\_custom\acc\fx_acc_derez_blink_red.efx',       # [acc]-authored vendored clone, red burst (The Scientist, docs/44)
            'share\raw\fx\_custom\acc\fx_acc_scientist_trail.efx'        # [acc]-authored vendored clone, red CONTINUOUS aura (from the normal counting variant)
        )
    }
    @{
        Name     = 'BO1 campaign sounds rip (numbers-station audio for the Scientist hum)'
        Author   = 'unknown ripper (user download 2026-07-17) / Treyarch (orig BO1 campaign audio)'
        Provides = 'BO1Sounds.7z: 605 campaign wavs (radio/interr/numbers/other). USED: numbers\New foldernum_04_d_PCM.wav (the pack author glued "New folder" into filenames) -> prepped by tools/prep_scientist_numbers_from_rip.js (stereo 47991Hz -> mono 48k, -3dB peak, 150ms seam xfade) OVERWRITING the tools-root sound_assets\acc\fx\scientist_numbers_lp.wav. The repo keeps the SYNTH fallback (tools/gen_scientist_numbers_wav.js) so fresh clones build + sound without the rip; installing this = the authentic BO1 numbers broadcast.'
        Required = $false  # repo synth fallback keeps a fresh clone green; this rip only upgrades the sound
        Marker   = 'sound_assets\acc\fx\scientist_numbers_lp.wav'
        Link     = 'BO1Sounds.7z (279 MB, user Downloads 2026-07-17). Re-prep: 7z-extract the numbers folder, run tools/prep_scientist_numbers_from_rip.js on numbers\New foldernum_04_d_PCM.wav targeting the tools-root sound_assets\acc\fx\scientist_numbers_lp.wav, bump a .zone comment, rebuild game-CLOSED. RIP stays OUT of git. Credit Treyarch in CREDITS before any public Workshop release.'
        Paths    = @(
            'sound_assets\acc\fx\scientist_numbers_lp.wav'
        )
    }
)
