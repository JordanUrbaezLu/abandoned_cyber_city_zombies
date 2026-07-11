// =============================================================================
// _acc_jukebox.gsc - the JUKEBOX in the NORTH trench under-room (user 2026-07-09)
//
// REPLACES the 3-teddy-bear song system (_acc_ee_song.gsc, removed 2026-07-09): ONE jukebox machine
// (IW cp_town_jukebox model, eMoX "Jukebox Menu" pack - MODEL-ONLY lift, the pack's LUI menu/GSC is NOT
// installed) that plays a RANDOM song from its playlist. Walk up and hold [activate]:
//
//   COST (user 2026-07-09): 2 Data Shards + 1000 points, charged to the triggering player.
//   Tunables: acc_jukebox_cost_points / acc_jukebox_cost_shards.
//
//   RANDOM PICK: uniformly random from level.acc_jukebox_songs, but never the SAME song twice in a row
//   (when >1 song is banked). REPEATABLE all game - the jukebox is never consumed.
//
//   5-MINUTE COOLDOWN between plays (global, carried over from the bear system, user 2026-06-25 rule:
//   let the song play out). Tunable: acc_jukebox_cooldown (sec).
//
// ADDING A SONG (manual, user 2026-07-09): bank the wav (48k/16-bit, sound_assets\acc\music\ +
// sound/aliases/acc_audio.csv STREAMED/2D/NONLOOPING row + GAME-CLOSED full build), then add ONE
// add_song( "<alias>", "<title>" ) line in init() below. Title = the "NOW PLAYING" banner text.
// Launch playlist = the 3 songs the bears played (aliases unchanged, so no sound-bank rebuild).
//
// PLACEMENT: NORTH under-room, the old LEFT-bear spot - interior x[-192,192], walkable y[2189,2517],
// floor z=-240. NOT the center spot: the deep reactor Arm Plinth (0,2493, _acc_reactor) owns the room's
// center line and a jukebox-sized machine there would crowd it (the bears only got away with it by being
// small). The machine sits WEST at (-140, 2350, -240), yaw 0 = facing +x into the room. If that room
// ever moves/resizes, update ACC_JUKEBOX_ORIGIN. All GSC-spawned (model + use trigger), ZERO new
// geometry - -GscOnly builds, no LED bake.
//
// Disable live: acc_jukebox_on 0.  IP/credit: every song's licence must be confirmed before the
// Workshop item goes Public (CREDITS.md - ee_song_3 is copyrighted, TEST-ONLY, DO NOT PUBLISH).
// =============================================================================

#using scripts\shared\util_shared;

#using scripts\zm\_zm_score;     // can_player_purchase / minus_to_player_score (the points half of the price)

#using scripts\zm\zm_abandoned_cyber_city\_acc_utility;
#using scripts\zm\zm_abandoned_cyber_city\_acc_data_shards;   // try_spend / get_count (the shard half of the price)
#using scripts\zm\zm_abandoned_cyber_city\_acc_music;          // single music channel: a jukebox song stops boss music etc.

#insert scripts\shared\shared.gsh;   // IS_TRUE

#precache( "model", "cp_town_jukebox" );

#define ACC_JUKEBOX_ORIGIN        ( -140, 2350, -240 )   // NORTH under-room, west side (the old LEFT bear spot; center is the reactor plinth's)
#define ACC_JUKEBOX_YAW           0                      // face +x = into the room (retune in-game if the IW model's forward differs)
#define ACC_JUKEBOX_COOLDOWN_SEC  300                 // seconds between plays (lets a song play out) - dvar acc_jukebox_cooldown
#define ACC_JUKEBOX_COST_POINTS   1000                // points per play      - dvar acc_jukebox_cost_points
#define ACC_JUKEBOX_COST_SHARDS   2                   // Data Shards per play - dvar acc_jukebox_cost_shards (settled 2 after 1/3 same-day, user 2026-07-09)

#namespace acc_jukebox;

function init()
{
    if ( getdvarint( "acc_jukebox_on", 1 ) != 1 )
        return;

    level.acc_jukebox_cooldown_until = 0;          // GetTime() ms; no play before this (the 5-min gate)
    level.acc_jukebox_last = undefined;            // alias of the last song played (no same-song-twice rule)

    // -------- PLAYLIST (add songs HERE - one line each; see the header recipe) --------
    level.acc_jukebox_songs = [];
    add_song( "acc_ee_song",   "Cyber Dreams" );                    // by Lilex (the old CENTER bear)
    add_song( "acc_ee_song_2", "Night Groove" );                    // (the old LEFT bear)
    add_song( "acc_ee_song_3", "I Want To Stay At Your House" );    // (the old RIGHT bear) - TEST-ONLY licence, CREDITS.md

    level thread spawn_jukebox();
}

function add_song( alias, title )
{
    s = spawnstruct();
    s.alias = alias;
    s.title = title;
    level.acc_jukebox_songs[ level.acc_jukebox_songs.size ] = s;
}

// Spawn the machine + its hold-USE trigger, then run the purchase loop. All GSC-spawned (no .map edit).
function spawn_jukebox()
{
    level endon( "end_game" );

    jb = spawn( "script_model", ACC_JUKEBOX_ORIGIN );
    jb setmodel( "cp_town_jukebox" );
    jb.angles = ( 0, ACC_JUKEBOX_YAW, 0 );

    // Trigger MUST be made usable via TriggerIgnoreTeam (stock _zm_perks.gsc:1523) - a script-spawned
    // use-trigger has no team otherwise. Raised origin gives the use-cursor something to land on.
    t = spawn( "trigger_radius_use", ACC_JUKEBOX_ORIGIN + ( 0, 0, 32 ), 0, 64, 72 );
    t TriggerIgnoreTeam();
    t SetCursorHint( "HINT_NOICON" );

    level.acc_jukebox_trig = t;
    refresh_hint();
    level thread hint_ticker();

    acc_utility::log( "jukebox: placed in the NORTH trench room (" + level.acc_jukebox_songs.size + " songs)" );

    for ( ;; )
    {
        t waittill( "trigger", player );
        if ( !isdefined( player ) || !isplayer( player ) ) continue;

        // 5-MINUTE GATE: a song is still playing / on cooldown -> deny.
        now = GetTime();
        if ( now < level.acc_jukebox_cooldown_until )
        {
            remain = int( ( level.acc_jukebox_cooldown_until - now + 999 ) / 1000 );
            player PlaySound( "zmb_no_purchase" );
            player acc_utility::hud_msg( "^3Jukebox busy^7 - " + remain + "s" );
            continue;
        }

        // DUAL PRICE: check BOTH halves before charging EITHER (no partial charge on a deny).
        pts    = getdvarint( "acc_jukebox_cost_points", ACC_JUKEBOX_COST_POINTS );
        shards = getdvarint( "acc_jukebox_cost_shards", ACC_JUKEBOX_COST_SHARDS );

        if ( acc_data_shards::get_count( player ) < shards )
        {
            player PlaySound( "zmb_no_purchase" );
            player acc_utility::hud_msg( "^1Need " + shards + " Data Shard" + ( ( shards == 1 ) ? "" : "s" ) );
            continue;
        }
        if ( !( player zm_score::can_player_purchase( pts ) ) )
        {
            player PlaySound( "zmb_no_purchase" );
            player acc_utility::hud_msg( "^1Need " + pts + " points" );
            continue;
        }

        // Shards first (try_spend is its own check+deduct; precheck above makes a false return a pure
        // race loss - bail WITHOUT touching points), then the points.
        if ( shards > 0 && !acc_data_shards::try_spend( player, shards ) )
            continue;
        if ( pts > 0 )
            player zm_score::minus_to_player_score( pts );
        player PlaySound( "zmb_cha_ching" );

        song = pick_song();
        level.acc_jukebox_last = song.alias;
        level.acc_jukebox_cooldown_until = GetTime() + ( getdvarint( "acc_jukebox_cooldown", ACC_JUKEBOX_COOLDOWN_SEC ) * 1000 );
        refresh_hint();

        // Through the single MUSIC CHANNEL: stops boss music / the theme first (one song at a time,
        // user 2026-06-25 override rule), then plays 2D for the whole lobby. NONLOOPING.
        acc_music::play( song.alias, false );
        acc_utility::log( "jukebox: PLAYING " + song.alias + " (" + song.title + ") for " + pts + "pts + " + shards + " shard(s)" );

        // NOW-PLAYING banner to EVERY player (whole lobby hears the song, whole lobby sees the title).
        // IPrintLnBold = engine built-in, all-clients, hudelem-pool-FREE (the proven bear-era choice).
        foreach ( p in GetPlayers() )
            if ( isdefined( p ) && isplayer( p ) )
                p IPrintLnBold( "^5NOW PLAYING^7  " + song.title );
    }
}

// Uniform random song, but never the same one twice in a row (when the playlist has >1 entry).
function pick_song()
{
    songs = level.acc_jukebox_songs;
    pick = songs[ RandomInt( songs.size ) ];
    if ( songs.size > 1 && isdefined( level.acc_jukebox_last ) )
    {
        while ( pick.alias == level.acc_jukebox_last )
            pick = songs[ RandomInt( songs.size ) ];
    }
    return pick;
}

// Hint shows the live dual price, or the busy tag while the cooldown runs.
function refresh_hint()
{
    t = level.acc_jukebox_trig;
    if ( !isdefined( t ) ) return;

    if ( GetTime() < level.acc_jukebox_cooldown_until )
    {
        t SetHintString( "Hold ^3[{+activate}]^7  Play Random Song  ^1[Jukebox busy]" );
        return;
    }
    pts    = getdvarint( "acc_jukebox_cost_points", ACC_JUKEBOX_COST_POINTS );
    shards = getdvarint( "acc_jukebox_cost_shards", ACC_JUKEBOX_COST_SHARDS );
    t SetHintString( "Hold ^3[{+activate}]^7  Play Random Song  ^2[Cost: " + pts + " + " + shards + " Data Shard" + ( ( shards == 1 ) ? "" : "s" ) + "]" );
}

// Keep the hint live: refresh once whenever the cooldown STARTS or ELAPSES (the purchase path also
// refreshes immediately, so this only has to catch the elapse edge).
function hint_ticker()
{
    level endon( "end_game" );

    prev_busy = ( GetTime() < level.acc_jukebox_cooldown_until );
    for ( ;; )
    {
        wait 1;
        busy = ( GetTime() < level.acc_jukebox_cooldown_until );
        if ( busy != prev_busy )
        {
            refresh_hint();
            prev_busy = busy;
        }
    }
}
