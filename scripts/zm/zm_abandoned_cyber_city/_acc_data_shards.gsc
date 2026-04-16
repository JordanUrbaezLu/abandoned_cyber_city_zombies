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
#using scripts\shared\clientfield_shared;
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

// Clientfield bit width: 7 bits = 0..127, covers our cap with headroom.
#define ACC_SHARDS_CF_NAME "acc_data_shards"
#define ACC_SHARDS_CF_BITS 7

// ---------------------------------------------------------------------------
// Init
// ---------------------------------------------------------------------------

init()
{
    _acc_utility::log( "data_shards init" );

    // Register clientfield so the client HUD can read shard count efficiently
    // without us polling from GSC. Signature verified via modme forums +
    // bo3explorer; see docs/16_gsc_reference.md section 2.
    clientfield::register(
        "toplayer",                // scope: per-player (HUD binding)
        ACC_SHARDS_CF_NAME,        // unique id string
        1,                         // version
        ACC_SHARDS_CF_BITS,        // bit width: 7 bits = 0..127
        "int"                      // format
    );

    level.acc_shards_pickup_model = "tag_origin"; // TODO(acc-model): swap in a glowing shard model once we have one.
    level.acc_shards_pool = []; // tracks live drops for cleanup.

    // Subroutine Tier 1 passive regen tick. Driven by cyberware module, which
    // just calls grant() on a timer. Nothing to do here.
}

client_init()
{
    // Client-side HUD wiring lives in the CSC/LUI implementation (Phase 4).
    // For Phase 3 we rely on iprintln text feedback.
}

on_player_connect( player )
{
    player.acc_data_shards = 0;
    player sync_shards_to_client();
}

on_player_spawned( player )
{
    player sync_shards_to_client();
}

on_player_disconnect( player )
{
    // Nothing persistent yet; post-1.0 we may write best-round metadata.
}

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

// Grant shards to a player. Returns actual grant amount (may be clamped or
// diminished based on round).
grant_player( player, amount, source_tag )
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

    new_total = _acc_utility::clamp_int( player.acc_data_shards + effective, 0, ACC_SHARDS_MAX );
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
try_spend( player, amount )
{
    if ( !isdefined( player ) || amount <= 0 ) return false;
    if ( player.acc_data_shards < amount ) return false;

    player.acc_data_shards -= amount;
    player sync_shards_to_client();
    return true;
}

get_count( player )
{
    if ( !isdefined( player.acc_data_shards ) ) return 0;
    return player.acc_data_shards;
}

// Spawn a shard pickup entity at origin that any player can grab.
// Used by elite-kill hook in _acc_elites and by Hack/Overload events.
spawn_pickup_at( origin, count )
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

sync_shards_to_client()
{
    self clientfield::set_to_player( ACC_SHARDS_CF_NAME, self.acc_data_shards );
    level notify( "acc_shards_changed", self );
}

watch_pickup()
{
    self endon( "acc_shard_claimed" );
    self endon( "death" );

    for ( ;; )
    {
        wait( 0.1 );
        closest = _acc_utility::get_closest_player_to( self.origin );
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

watch_lifetime()
{
    self endon( "acc_shard_claimed" );
    self endon( "death" );

    wait( ACC_SHARD_DROP_LIFETIME_SEC );

    if ( isdefined( self ) )
    {
        self delete();
    }
}

is_player_alive( player )
{
    if ( !isdefined( player ) ) return false;
    // Stock provides _zm_utility::is_player_valid() which checks connected,
    // alive, not downed, and some edge cases. Prefer that over rolling our own.
    // TODO(acc-verify): confirm _zm_utility::is_player_valid exists in BO3;
    // if not, the below manual check is the community-standard fallback.
    if ( !isalive( player ) ) return false;
    if ( isdefined( player.isdowned ) && player.isdowned ) return false;
    return true;
}
