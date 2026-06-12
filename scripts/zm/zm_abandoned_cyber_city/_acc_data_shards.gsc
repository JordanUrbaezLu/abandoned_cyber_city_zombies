// =============================================================================
// _acc_data_shards.gsc - the custom "Data Shards" currency
//
// Design reference: docs/04_progression_and_skills.md (Two Currencies, Data
// Shard Sources), docs/06_mechanics.md (Data Shard Economy flow).
//
// Responsibilities:
//  - Per-player shard counter (self.acc_data_shards).
//  - Shard drop entities spawned by elite kills and objectives.
//  - HUD bridge - clientfield / hudelem that renders the count.
//  - Public API for other modules to query/spend shards.
// =============================================================================

#using scripts\codescripts\struct;
#using scripts\shared\callbacks_shared;
#using scripts\shared\hud_util_shared;
#using scripts\shared\util_shared;

#using scripts\zm\_zm_score;
#using scripts\zm\_zm_utility;

#using scripts\zm\zm_abandoned_cyber_city\_acc_utility;

// ---------------------------------------------------------------------------
// Constants - tune freely; documented in docs/04_progression_and_skills.md.
// ---------------------------------------------------------------------------

#define ACC_SHARDS_MAX 99
#define ACC_SHARD_DROP_LIFETIME_SEC 30
#define ACC_SHARD_PICKUP_RADIUS 48
#define ACC_SHARD_LOW_ROUND_THRESHOLD 10
#define ACC_SHARD_LOW_ROUND_DIMINISH_AFTER 2

// (Phase 4: the LUI widget gets a "clientuimodel" clientfield named
// "hudItems.accDataShards" - the only pool that is provably safe to register
// GSC-only, see CHANGELOG stock-API notes. The old "toplayer" registration
// was a load-crash: stock registers every toplayer field in BOTH VMs.)

#namespace acc_data_shards;

// ---------------------------------------------------------------------------
// Init
// ---------------------------------------------------------------------------

function init()
{
    acc_utility::log( "data_shards init" );

    // VERIFIED(acc): the old GSC-only clientfield::register("toplayer", ...)
    // here was a map-load crash - stock registers every "toplayer" field in
    // BOTH VMs (e.g. _zm_perk_deadshot.gsc:71 vs .csc:47); zero GSC-only
    // counterexamples exist in the whole mirror. Greybox HUD is a classic
    // server-side hudelem instead (stock-alive: _zm.gsc:4880, hud_util_shared
    // createFontString + SetValue, numeric = no localization needed).

    level.acc_shards_pickup_model = "tag_origin"; // TODO(acc-model): swap in a glowing shard model once we have one.
    level.acc_shards_pool = []; // tracks live drops for cleanup.

    // Subroutine Tier 1 passive regen tick. Driven by cyberware module, which
    // just calls grant() on a timer. Nothing to do here.
}

function client_init()
{
    // Client-side HUD wiring lives in the CSC/LUI implementation (Phase 4).
    // For Phase 3 we rely on iprintln text feedback.
}

function on_player_connect( player )
{
    player.acc_data_shards = 0;
    player sync_shards_to_client();
}

function on_player_spawned( player )
{
    player sync_shards_to_client();
}

function on_player_disconnect( player )
{
    // Nothing persistent yet; post-1.0 we may write best-round metadata.
}

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

// Grant shards to a player. Returns actual grant amount (may be clamped or
// diminished based on round).
function grant_player( player, amount, source_tag )
{
    if ( !isdefined( player ) || !isdefined( amount ) || amount <= 0 )
    {
        return 0;
    }

    effective = amount;

    // Low-round elite diminishing returns (see docs/06_mechanics.md).
    if ( isdefined( source_tag ) && source_tag == "elite_kill" )
    {
        if ( level.round_number <= ACC_SHARD_LOW_ROUND_THRESHOLD )
        {
            if ( !isdefined( player.acc_shards_elite_count_round ) )
            {
                player.acc_shards_elite_count_round = 0;
            }
            player.acc_shards_elite_count_round += 1;
            if ( player.acc_shards_elite_count_round > ACC_SHARD_LOW_ROUND_DIMINISH_AFTER )
            {
                effective = int( amount * 0.5 );
                if ( effective < 1 ) effective = 1;
            }
        }
    }

    new_total = acc_utility::clamp_int( player.acc_data_shards + effective, 0, ACC_SHARDS_MAX );
    granted = new_total - player.acc_data_shards;
    player.acc_data_shards = new_total;
    player sync_shards_to_client();

    if ( granted > 0 )
    {
        player iprintln( "+" + granted + " Data Shard" + ( granted > 1 ? "s" : "" ) );
    }
    return granted;
}

// Attempt to spend shards. Returns true iff the spend succeeded.
function try_spend( player, amount )
{
    if ( !isdefined( player ) || amount <= 0 ) return false;
    if ( player.acc_data_shards < amount ) return false;

    player.acc_data_shards -= amount;
    player sync_shards_to_client();
    return true;
}

function get_count( player )
{
    if ( !isdefined( player.acc_data_shards ) ) return 0;
    return player.acc_data_shards;
}

// Spawn a shard pickup entity at origin that any player can grab.
// Used by elite-kill hook in _acc_elites and by Hack/Overload events.
function spawn_pickup_at( origin, count )
{
    if ( !isdefined( count ) || count <= 0 ) count = 1;

    // TODO(acc-model): swap script_model / fx for a real shard model.
    shard = spawn( "script_model", origin );
    shard setmodel( level.acc_shards_pickup_model );
    shard.acc_shard_count = count;
    shard.acc_created_at = gettime();

    // TODO(acc-fx): attach a hovering glow FX once the art pass exists.

    level.acc_shards_pool[ level.acc_shards_pool.size ] = shard;
    shard thread watch_pickup();
    shard thread watch_lifetime();
}

// ---------------------------------------------------------------------------
// Internals
// ---------------------------------------------------------------------------

function sync_shards_to_client()
{
    if ( !isdefined( self.acc_data_shards ) ) self.acc_data_shards = 0;
    if ( !isdefined( self.acc_shards_hud ) )
    {
        self.acc_shards_hud = self hud::createFontString( "default", 1.5 );
        self.acc_shards_hud hud::setPoint( "BOTTOMLEFT", "BOTTOMLEFT", 10, -130 );
        self.acc_shards_hud.color = ( 0.3, 0.85, 1.0 );
        self.acc_shards_hud.hidewheninmenu = true;
    }
    // SetValue = numeric display, no localized string required (stock numeric
    // precedent _globallogic.gsc:758). Counter hidden until first shard.
    self.acc_shards_hud SetValue( self.acc_data_shards );
    self.acc_shards_hud.alpha = ( self.acc_data_shards > 0 ) ? 0.9 : 0;
    level notify( "acc_shards_changed", self );
}

function watch_pickup()
{
    self endon( "acc_shard_claimed" );
    self endon( "death" );

    for ( ;; )
    {
        wait( 0.1 );
        closest = acc_utility::get_closest_player_to( self.origin );
        if ( !isdefined( closest ) ) continue;
        if ( !is_player_alive( closest ) ) continue;
        if ( distancesquared( closest.origin, self.origin ) > ( ACC_SHARD_PICKUP_RADIUS * ACC_SHARD_PICKUP_RADIUS ) )
        {
            continue;
        }

        // Grant and destroy.
        grant_player( closest, self.acc_shard_count, "pickup" );
        self notify( "acc_shard_claimed" );
        self delete();
        return;
    }
}

function watch_lifetime()
{
    self endon( "acc_shard_claimed" );
    self endon( "death" );

    wait( ACC_SHARD_DROP_LIFETIME_SEC );

    if ( isdefined( self ) )
    {
        self delete();
    }
}

function is_player_alive( player )
{
    if ( !isdefined( player ) ) return false;
    // VERIFIED(acc): zm_utility::is_player_valid (_zm_utility.gsc:1600) checks
    // defined/alive/spawned/not-laststand/not-spectator. The old manual check
    // read player.isdowned, a field that does not exist anywhere in BO3 stock
    // (the real downed flag is self.laststand, _zm_laststand.gsc:200) - downed
    // players could claim shards.
    return zm_utility::is_player_valid( player );
}
