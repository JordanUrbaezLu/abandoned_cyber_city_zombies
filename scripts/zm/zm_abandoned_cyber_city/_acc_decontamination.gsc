// =============================================================================
// _acc_decontamination.gsc - per-round decontamination zone hazard
//
// Design reference: docs/03_layout.md "Decontamination zones (round hazard)",
// docs/13_perks.md "Per-Round Rotating Lab Machines" (timing contract).
//
// Rules implemented (docs/03_layout.md Rules v1.0):
//   - A permutation of the 4 eligible zones (Undercity Market, Service Alley,
//     Server Vault, Rooftop Helipad) is rolled ONCE at map load. NEVER
//     start_zone / corp_zone / lab_zone (spawn-safe floor / cut vertex / the
//     perk+PaP hub).
//   - On acc_round_start for rounds 1-4, slot (round-1) is declared
//     contaminated: level notify("acc_decontamination_start", round, zone),
//     global warning + countdown at T-10/T-5, 20s escape window, then SEAL:
//     every player still inside one of the zone's info_volume brushes dies
//     via the stock down/kill path (laststand / Quick Revive / co-op rules
//     apply), the zone's spawning is disabled permanently, and a
//     kill-on-reentry monitor covers the zone volumes for the rest of the run.
//   - Rounds 5+: no new seal - the "nominal 0s decontamination tick".
//   - EVERY round emits level notify("acc_decontamination_complete", round)
//     after its phase (rounds 1-4: after the 20s window + seal; rounds 5+:
//     immediately at round start). _acc_map_randomizer's Lab perk re-roll
//     keys on this notify - never on acc_round_start (docs win).
//
// OUT OF SCOPE (v1.0): physically closing doors into sealed zones. The repo
// uses stock buy-once doors (door script_flags are set on open and only
// cleared by door-close logic, _zm_blockers.gsc:952-967), so an already-open
// or later-bought door into a sealed zone stays passable - the kill-on-reentry
// monitor is the seal's enforcement. Optional acc_seal_<zone>
// script_brushmodels (hidden by default in Radiant) are shown+solid at seal
// time when they exist; placing them + door-close/debris art is Radiant/Phase 4
// work (close_seal_geometry below no-ops gracefully until then).
//
// HUD/audio: iprintlnbold is the greybox warning. Real LUI widget + sound
// alias are Phase 4 (.csc) work.
//
// Public API:
//   init()                    - roll permutation + start the round watcher
//                               (call once from acc_main::init(), before the
//                               first acc_round_start fires)
//   is_zone_sealed(zone_name) - true once <zone_name> has been sealed this run
// =============================================================================

#using scripts\codescripts\struct;

#using scripts\shared\util_shared;

#using scripts\zm\_zm_utility;

#using scripts\zm\zm_abandoned_cyber_city\_acc_utility;

#insert scripts\shared\shared.gsh;

// ---------------------------------------------------------------------------
// Tuning (keep in sync with docs/03_layout.md Rules v1.0)
// ---------------------------------------------------------------------------

#define ACC_DECON_ESCAPE_WINDOW_SEC 20
#define ACC_DECON_SEAL_ROUNDS 4
#define ACC_DECON_REENTRY_POLL_SEC 0.25
#define ACC_DECON_ENFORCE_POLL_SEC 1

#namespace acc_decontamination;

// ---------------------------------------------------------------------------
// Lifecycle
// ---------------------------------------------------------------------------

function init()
{
    acc_utility::log( "decontamination: init" );

    level.acc_decon_sealed = [];
    level.acc_decon_volume_cache = [];

    // Rolled ONCE at map load (docs/03_layout.md "Order"). Round 1 seals
    // slot 1, ..., round 4 seals slot 4. Round 5+ adds no new seal.
    level.acc_decon_order = roll_decon_order();

    for ( i = 0; i < level.acc_decon_order.size; i++ )
    {
        acc_utility::log( "decon order slot " + ( i + 1 ) + ": " +
                           level.acc_decon_order[ i ] );
    }

    level thread watch_rounds();
}

// Public: has <zone_name> been permanently sealed this run?
function is_zone_sealed( zone_name )
{
    if ( !isdefined( level.acc_decon_sealed ) )
    {
        return false;
    }
    return IS_TRUE( level.acc_decon_sealed[ zone_name ] );
}

// ---------------------------------------------------------------------------
// Eligible zones + display names
// ---------------------------------------------------------------------------

// docs/03_layout.md: eligible seals are EXACTLY these four. Spawn Plaza
// (start_zone), Corporate Plaza (corp_zone) and Subterranean Lab (lab_zone)
// are NEVER sealed - do not add them here.
function get_eligible_zones()
{
    zones = [];
    zones[ 0 ] = "market_zone";
    zones[ 1 ] = "alley_zone";
    zones[ 2 ] = "vault_zone";
    zones[ 3 ] = "roof_zone";
    return zones;
}

function is_eligible_zone( zone_name )
{
    eligible = get_eligible_zones();
    for ( i = 0; i < eligible.size; i++ )
    {
        if ( eligible[ i ] == zone_name )
        {
            return true;
        }
    }
    return false;
}

function get_zone_display_name( zone_name )
{
    if ( zone_name == "market_zone" )
    {
        return "Undercity Market";
    }
    if ( zone_name == "alley_zone" )
    {
        return "Service Alley";
    }
    if ( zone_name == "vault_zone" )
    {
        return "Server Vault";
    }
    if ( zone_name == "roof_zone" )
    {
        return "Rooftop Helipad";
    }
    return zone_name;
}

// Fisher-Yates over the 4 eligible zones using the project RNG wrapper so the
// roll joins the seeded-PRNG plan (see acc_utility::acc_rand_int).
function roll_decon_order()
{
    zones = get_eligible_zones();

    for ( i = zones.size - 1; i > 0; i-- )
    {
        j = acc_utility::acc_rand_int( i + 1 );
        tmp = zones[ i ];
        zones[ i ] = zones[ j ];
        zones[ j ] = tmp;
    }

    return zones;
}

// ---------------------------------------------------------------------------
// Round watcher
// ---------------------------------------------------------------------------

function watch_rounds()
{
    level endon( "end_game" );

    // acc_round_start is dispatched by _acc_main::watch_round_transitions
    // after stock "start_of_round" (and after the initial_blackscreen_passed
    // flag for round 1).
    for ( ;; )
    {
        level waittill( "acc_round_start", round_number );

        // Threaded so a pathologically short round can never make the watcher
        // miss the next acc_round_start; seal phases are idempotent per zone.
        level thread run_decon_phase( round_number );
    }
}

function run_decon_phase( round_number )
{
    level endon( "end_game" );

    if ( isdefined( round_number ) && round_number >= 1 &&
         round_number <= ACC_DECON_SEAL_ROUNDS )
    {
        zone_name = level.acc_decon_order[ round_number - 1 ];
        run_seal_phase( round_number, zone_name );
    }

    // ALWAYS emitted, every round (docs/03_layout.md Implementation notes):
    // rounds 1-4 after the 20s window + seal logic above; rounds 5+
    // immediately at round start ("nominal 0s decontamination tick").
    // _acc_map_randomizer::watch_round_for_perk_rotation keys its 4-of-9 Lab
    // perk re-roll on this notify (docs/13_perks.md "Implementation").
    level notify( "acc_decontamination_complete", round_number );
}

// ---------------------------------------------------------------------------
// Seal phase: warn -> 20s window -> kill stragglers -> permanent seal
// ---------------------------------------------------------------------------

function run_seal_phase( round_number, zone_name )
{
    if ( !is_eligible_zone( zone_name ) )
    {
        // docs/03_layout.md: Spawn / Corp / Lab are NEVER sealed. This can
        // only trip if someone edits get_eligible_zones / the order roll.
        /# assertmsg( "decontamination rolled non-eligible zone: " + zone_name ); #/
        acc_utility::log( "decon: REFUSING to seal non-eligible zone " + zone_name );
        return;
    }

    if ( is_zone_sealed( zone_name ) )
    {
        acc_utility::log( "decon: zone already sealed, skipping: " + zone_name );
        return;
    }

    display_name = get_zone_display_name( zone_name );

    level notify( "acc_decontamination_start", round_number, zone_name );
    acc_utility::log( "decon: round " + round_number + " contaminates " +
                       zone_name + " (" + display_name + ")" );

    // Greybox warning + countdown (docs/03_layout.md "Player warning" /
    // "Escape window"). Phase 4 replaces with LUI HUD widget + audio alias.
    iprintlnbold( "DECONTAMINATION - EVACUATE " + display_name );

    wait( ACC_DECON_ESCAPE_WINDOW_SEC - 10 );
    iprintlnbold( "DECONTAMINATION - " + display_name + " SEALS IN 10 SECONDS" );

    wait( 5 );
    iprintlnbold( "DECONTAMINATION - " + display_name + " SEALS IN 5 SECONDS" );

    wait( 5 );

    seal_zone( zone_name );

    iprintlnbold( display_name + " SEALED" );
}

function seal_zone( zone_name )
{
    // Mark first so is_zone_sealed() is true from the seal instant.
    level.acc_decon_sealed[ zone_name ] = true;

    // docs/03_layout.md "Failure": each player evaluated independently.
    kill_players_in_zone( zone_name );

    // docs/03_layout.md "After the timer": spawners inside are disabled.
    disable_zone_spawning( zone_name );

    // Optional physical blockers (no-op until Radiant places them).
    close_seal_geometry( zone_name );

    // docs/03_layout.md "After the timer": kill volume on re-entry.
    level thread reentry_kill_monitor( zone_name );

    // Keep the spawn seal authoritative against later enable_zone calls.
    level thread enforce_spawn_seal( zone_name );

    acc_utility::log( "decon: " + zone_name + " sealed permanently" );
}

// ---------------------------------------------------------------------------
// Volume + player checks
// ---------------------------------------------------------------------------

// All info_volume brushes belonging to a zone, cached after first lookup
// (info_volume ents persist for the whole map).
function get_zone_volumes( zone_name )
{
    if ( isdefined( level.acc_decon_volume_cache[ zone_name ] ) )
    {
        return level.acc_decon_volume_cache[ zone_name ];
    }

    volumes = [];

    // VERIFIED(acc): the zonemgr's own volume list - zone_init collects every
    // ent with targetname == zone name whose classname == "info_volume" into
    // zone.volumes (_zm_zonemgr.gsc:319-330). Prefer that list when the zone
    // has been zone_init'd (all 7 zones are, via the entry script's
    // add_adjacent_zone graph); otherwise rebuild it the same way.
    if ( isdefined( level.zones ) && isdefined( level.zones[ zone_name ] ) &&
         isdefined( level.zones[ zone_name ].volumes ) )
    {
        volumes = level.zones[ zone_name ].volumes;
    }
    else
    {
        ents = getentarray( zone_name, "targetname" );
        for ( i = 0; i < ents.size; i++ )
        {
            if ( isdefined( ents[ i ].classname ) &&
                 ents[ i ].classname == "info_volume" )
            {
                volumes[ volumes.size ] = ents[ i ];
            }
        }
    }

    if ( volumes.size == 0 )
    {
        acc_utility::log( "decon: WARNING no info_volume found for " + zone_name );
    }

    level.acc_decon_volume_cache[ zone_name ] = volumes;
    return volumes;
}

function player_in_zone_volumes( player, volumes )
{
    // VERIFIED(acc): IsTouching(<info_volume ent>) is exactly how stock tests
    // zone occupancy - any_player_in_zone does players[j]
    // IsTouching(zone.volumes[i]) over each zone volume
    // (_zm_zonemgr.gsc:189-209, the check at :204) and entity_in_zone does
    // self IsTouching(e_volume) (_zm_zonemgr.gsc:232).
    for ( i = 0; i < volumes.size; i++ )
    {
        if ( player IsTouching( volumes[ i ] ) )
        {
            return true;
        }
    }
    return false;
}

function kill_players_in_zone( zone_name )
{
    volumes = get_zone_volumes( zone_name );
    if ( volumes.size == 0 )
    {
        return;
    }

    players = acc_utility::get_all_players();
    for ( i = 0; i < players.size; i++ )
    {
        player = players[ i ];

        // VERIFIED(acc): zm_utility::is_player_valid excludes spectators
        // (_zm_utility.gsc:1622-1625, matching the zonemgr's own spectator
        // exclusion at _zm_zonemgr.gsc:204) and players already in laststand
        // (_zm_utility.gsc:1637-1643) - a player already downed inside the
        // zone is left to normal co-op revive/bleedout rules.
        if ( !zm_utility::is_player_valid( player ) )
        {
            continue;
        }

        if ( player_in_zone_volumes( player, volumes ) )
        {
            decon_kill_player( player );
        }
    }
}

function decon_kill_player( player )
{
    acc_utility::log_player( player, "caught by decontamination seal" );

    // Stock down/kill path (docs/03_layout.md "Failure": same as being downed
    // - Quick Revive / co-op laststand rules apply): a self-origin DoDamage
    // for more than current health routes through the stock player damage
    // pipeline into laststand instead of bypassing it.
    // VERIFIED(acc): stock downs players exactly this way - the electric trap
    // does self DoDamage( self.health + 100, self.origin ) on the player
    // (_zm_traps.gsc:829, player_elec_damage) and the shared crusher trap does
    // player DoDamage( player.health, player.origin ) (traps_shared.gsc:1202).
    // The +666 overkill margin mirrors stock kill-volume idiom
    // (_zm_blockers.gsc:636, _zm_powerup_nuke.gsc:145) and guarantees the down
    // regardless of Jugg/armor health totals.
    player DoDamage( player.health + 666, player.origin );
}

// ---------------------------------------------------------------------------
// Spawn seal
// ---------------------------------------------------------------------------

// Every spawner struct targeted by the zone's info_volumes.
function get_zone_spawner_spots( zone_name )
{
    spots = [];

    // VERIFIED(acc): zone_init gathers a zone's spawn spots via
    // struct::get_array( zone.volumes[0].target, "targetname" )
    // (_zm_zonemgr.gsc:345-347). We sweep EVERY volume's target (deduped) in
    // case a multi-volume zone ever carries differing targets - stock only
    // reads volume 0, so this is a superset of what the zonemgr can see.
    volumes = get_zone_volumes( zone_name );
    seen_targets = [];

    for ( i = 0; i < volumes.size; i++ )
    {
        if ( !isdefined( volumes[ i ].target ) )
        {
            continue;
        }
        if ( isdefined( seen_targets[ volumes[ i ].target ] ) )
        {
            continue;
        }
        seen_targets[ volumes[ i ].target ] = true;

        batch = struct::get_array( volumes[ i ].target, "targetname" );
        for ( j = 0; j < batch.size; j++ )
        {
            spots[ spots.size ] = batch[ j ];
        }
    }

    return spots;
}

function disable_zone_spawning( zone_name )
{
    // (a) Zone-level gate.
    // VERIFIED(acc): create_spawner_list only harvests spots from zones where
    // is_enabled && is_active && is_spawning_allowed (_zm_zonemgr.gsc:1166),
    // and it rebuilds level.zm_loc_types FROM SCRATCH every ~1s manage_zones
    // scan (called at _zm_zonemgr.gsc:974, wait(1) at :983) - so clearing
    // these fields removes the zone's spawn points on the next scan, and
    // keeps them removed for as long as the fields stay cleared.
    if ( isdefined( level.zones ) && isdefined( level.zones[ zone_name ] ) )
    {
        level.zones[ zone_name ].is_spawning_allowed = false;
    }

    // (b) Per-spot gate - survives independently of the zone struct.
    // VERIFIED(acc): create_spawner_list skips any spot with
    // is_enabled == false (_zm_zonemgr.gsc:1172-1175). zone_init stamps
    // spot.is_enabled from !IS_TRUE(spot.is_blocked) (_zm_zonemgr.gsc:355-362),
    // so setting is_blocked=true keeps the spot dead across any later
    // zone_init as well. Because both gates must pass, even a same-frame race
    // with enable_zone re-setting is_spawning_allowed (see enforce_spawn_seal)
    // produces zero harvested spots from this zone.
    spots = get_zone_spawner_spots( zone_name );
    for ( i = 0; i < spots.size; i++ )
    {
        spots[ i ].is_enabled = false;
        spots[ i ].is_blocked = true;
    }

    acc_utility::log( "decon: spawning disabled for " + zone_name +
                       " (" + spots.size + " spawner spots)" );
}

function enforce_spawn_seal( zone_name )
{
    level endon( "end_game" );

    // VERIFIED(acc): enable_zone unconditionally re-sets
    // is_spawning_allowed = true (_zm_zonemgr.gsc:497-498), and it re-runs
    // whenever a door flag connects this zone - zone_flag_wait calls
    // enable_zone on BOTH zones of the pair when its flag sets
    // (_zm_zonemgr.gsc:723-736). Doors into sealed zones are out of scope
    // (buy-once doors, see module header), so a post-seal door purchase WOULD
    // re-enable spawning without this loop. Cadence matches the manage_zones
    // scan that feeds create_spawner_list (wait(1) at _zm_zonemgr.gsc:983);
    // the per-spot is_enabled=false gate covers the sub-second race window.
    while ( true )
    {
        if ( isdefined( level.zones ) && isdefined( level.zones[ zone_name ] ) )
        {
            level.zones[ zone_name ].is_spawning_allowed = false;
        }
        wait( ACC_DECON_ENFORCE_POLL_SEC );
    }
}

// ---------------------------------------------------------------------------
// Kill-on-reentry monitor
// ---------------------------------------------------------------------------

function reentry_kill_monitor( zone_name )
{
    level endon( "end_game" );

    volumes = get_zone_volumes( zone_name );
    if ( volumes.size == 0 )
    {
        acc_utility::log( "decon: no volumes - reentry monitor disabled for " +
                           zone_name );
        return;
    }

    // The sealed zone is a kill volume from now on (docs/03_layout.md "After
    // the timer"). is_player_valid keeps us from re-hitting a player already
    // bleeding out in laststand inside the zone; if they get revived in place,
    // the next poll downs them again - that is the kill volume working.
    while ( true )
    {
        players = acc_utility::get_all_players();
        for ( i = 0; i < players.size; i++ )
        {
            player = players[ i ];
            if ( !zm_utility::is_player_valid( player ) )
            {
                continue;
            }
            if ( player_in_zone_volumes( player, volumes ) )
            {
                decon_kill_player( player );
            }
        }
        wait( ACC_DECON_REENTRY_POLL_SEC );
    }
}

// ---------------------------------------------------------------------------
// Optional physical seal geometry (Radiant-dependent, graceful no-op)
// ---------------------------------------------------------------------------

function close_seal_geometry( zone_name )
{
    // TODO(acc-geom): Radiant should place hidden-by-default
    // script_brushmodels named "acc_seal_<zone_name>" across each eligible
    // zone's doorways (debris / blast-door look is Phase 4 art). Pattern
    // matches _acc_map_randomizer::apply_pap_approach (show + solid). Until
    // they exist this finds nothing and the kill-on-reentry monitor alone
    // enforces the seal.
    blockers = getentarray( "acc_seal_" + zone_name, "targetname" );
    for ( i = 0; i < blockers.size; i++ )
    {
        blockers[ i ] show();
        blockers[ i ] solid();
    }

    if ( blockers.size > 0 )
    {
        acc_utility::log( "decon: closed " + blockers.size +
                           " seal blockers for " + zone_name );
    }
}
