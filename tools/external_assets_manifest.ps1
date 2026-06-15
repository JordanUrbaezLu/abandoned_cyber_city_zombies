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
        Name     = 'Panzer / mechz (OPTIONAL, WIP - not in shipped .ff)'
        Author   = 'Spiki'
        Provides = 'future heavy boss (in-progress)'
        Required = $false
        Marker   = 'source_data\mechz_spiki.gdt'
        Link     = 'modme #3087 (MEGA, password Chungus4Prez)'
        Paths    = @(
            'model_export\*mechz*',
            'xanim_export\*mechz*',
            'sound_assets\*mechz*',
            'share\raw\fx\*mechz*',
            'source_data\*mechz*'
        )
    }
)
