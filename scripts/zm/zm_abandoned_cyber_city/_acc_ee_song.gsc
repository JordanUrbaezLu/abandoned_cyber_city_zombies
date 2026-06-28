// =============================================================================
// _acc_ee_song.gsc - the teddy-bear JUKEBOX in the NORTH trench under-room (user 2026-06-25)
//
// THREE interactable TEDDY BEARS sit along the back wall of the NORTH trench under-room (the one
// WITHOUT the Overclock terminal / Glitch Altar - those live in the SOUTH "Foundry" room). The
// ORIGINAL center bear (easter-egg song "Cyber Dreams" by Lilex) is now flanked by a LEFT and a
// RIGHT bear, each playing its OWN song. Walk up and hold [activate]: the bear vanishes and its song
// plays 2D for the whole lobby.
//
// RULES (user 2026-06-25):
//   - ORDER-BASED PRICE, charged to the triggering player and keyed to HOW MANY songs you've played
//     this game (NOT which bear): 1st = 500, 2nd = 1000, 3rd = 1500 points. Play in ANY order; the
//     price always follows the trigger order. (Was free.) Tunable: acc_ee_song_cost_1/_2/_3.
//   - 5-MINUTE COOLDOWN between triggers (global): once you play one, you must wait ~5 min before any
//     other bear can be triggered - that lets the song play out. Tunable: acc_ee_song_cooldown (sec).
//   - ONE song per bear (each bear is consumed when played).
//
// Classic CoD idiom: the teddy bear IS the song trigger (p7_zm_teddybear - a proven-packed model, also
// used by _acc_boss_items). ZERO new geometry (the room is already baked - map_source UNDER ROOM NORTH /
// add_under_room.js): all three bears are spawned in GSC, so this is a -GscOnly change, no LED bake.
//
// PLACEMENT: NORTH under-room (ORIGINAL): interior x[-192,192], walkable y[2189,2517] floor z=-240. The three bears
// sit at y=2350: LEFT (-140), CENTER (0, the original), RIGHT (+140), facing the door (south); nudged forward from
// y2430 (user 2026-06-28) so the deep reactor plinth at the back wall (0,2493) sits CENTERED and clear behind them.
// 140u apart so the 48u use-triggers never overlap. If that room ever moves/resizes, update the origins below.
//
// AUDIO: each bear plays a STREAMED 2D NONLOOPING music alias (sound/aliases/acc_audio.csv):
//   center = acc_ee_song   -> acc\music\ee_song.wav    ("Cyber Dreams" - already present)
//   left   = acc_ee_song_2 -> acc\music\ee_song_2.wav  (ADD a 48k/16-bit wav here, then a GAME-CLOSED full build)
//   right  = acc_ee_song_3 -> acc\music\ee_song_3.wav  (ditto) - until the wavs are banked these bears charge +
//   cooldown but play silently (the alias resolves to nothing). See memory custom-sound-48k-and-game-lock.
//
// Disable live: acc_ee_song_on 0.  IP/credit: confirm every song's licence permits Workshop
// redistribution before going Public (CREDITS.md).
// =============================================================================

#using scripts\shared\util_shared;

#using scripts\zm\_zm_score;     // can_player_purchase / minus_to_player_score (charge the trigger cost)

#using scripts\zm\zm_abandoned_cyber_city\_acc_utility;
#using scripts\zm\zm_abandoned_cyber_city\_acc_music;   // single music channel: a teddy song stops boss music etc.

#insert scripts\shared\shared.gsh;   // IS_TRUE

#precache( "model", "p7_zm_teddybear" );

#define ACC_EE_COOLDOWN_SEC  300     // seconds between ANY two song triggers (lets the song play out) - dvar acc_ee_song_cooldown
#define ACC_EE_COST_1        500     // points for the 1st song you trigger this game (any bear) - dvar acc_ee_song_cost_1
#define ACC_EE_COST_2        1000    // 2nd song                                                  - dvar acc_ee_song_cost_2
#define ACC_EE_COST_3        1500    // 3rd song                                                  - dvar acc_ee_song_cost_3

#namespace acc_ee_song;

function init()
{
    if ( getdvarint( "acc_ee_song_on", 1 ) != 1 )
        return;

    level.acc_ee_play_count     = 0;   // songs triggered so far -> drives the order-based price
    level.acc_ee_cooldown_until = 0;   // GetTime() ms; no NEW trigger before this (the 5-min gate)

    level thread spawn_jukebox_bears();
}

// Spawn the three bears, label them with the current price, then watch each one. All GSC-spawned (no .map edit).
function spawn_jukebox_bears()
{
    level endon( "end_game" );

    // 3rd arg = the SONG TITLE shown on the "NOW PLAYING" banner (user 2026-06-26, names 2026-06-27). All three
    // titles are the user's final names; the LEFT/RIGHT wavs (acc_ee_song_2 / _3) still need banking (see the
    // AUDIO note up top) - until then those two bears charge + show the banner but play silently.
    bears = [];
    bears[ bears.size ] = make_bear( ( -140, 2350, -240 ), "acc_ee_song_2", "Night Groove"                 );  // LEFT  (titles swapped w/ RIGHT, user 2026-06-27: were on the wrong songs)
    bears[ bears.size ] = make_bear( (    0, 2350, -240 ), "acc_ee_song",   "Cyber Dreams"                 );  // CENTER (by Lilex)
    bears[ bears.size ] = make_bear( (  140, 2350, -240 ), "acc_ee_song_3", "I Want To Stay At Your House" );  // RIGHT (titles swapped w/ LEFT, user 2026-06-27)

    refresh_hints( bears );              // show the current (1st-trigger) price on every bear
    level thread hint_ticker( bears );   // flip hints between price / "busy" as the cooldown comes and goes

    for ( i = 0; i < bears.size; i++ )
        level thread bear_watch( bears[ i ], bears );

    acc_utility::log( "ee_song: jukebox - 3 teddy bears placed in the NORTH trench room" );
}

// Spawn one bear (script_model) + its hold-USE trigger; return a struct describing it. The trigger MUST be made
// usable via TriggerIgnoreTeam (stock _zm_perks.gsc:1523) - a script-spawned use-trigger has no team otherwise.
function make_bear( origin, song_alias, title )
{
    bear = spawn( "script_model", origin + ( 0, 0, 2 ) );
    bear setmodel( "p7_zm_teddybear" );
    bear.angles = ( 0, 180, 0 );   // face the door (south)

    t = spawn( "trigger_radius_use", origin + ( 0, 0, 20 ), 0, 48, 64 );
    t TriggerIgnoreTeam();
    t SetCursorHint( "HINT_NOICON" );

    b = spawnstruct();
    b.bear = bear;
    b.trig = t;
    b.song = song_alias;
    b.title = title;       // shown on the all-players "NOW PLAYING" banner when this bear is triggered
    b.used = false;
    return b;
}

// Per-bear loop. Hold-USE: gate on the 5-min cooldown, charge the order-based price, then play THIS bear's song
// 2D for the whole lobby and start the cooldown. One song per bear (the bear vanishes once played).
function bear_watch( b, all )
{
    level endon( "end_game" );

    for ( ;; )
    {
        b.trig waittill( "trigger", player );
        if ( !isdefined( player ) || !isplayer( player ) ) continue;
        if ( IS_TRUE( b.used ) ) continue;   // already played (trigger is disabled too, but guard the race)

        // 5-MINUTE GATE: a song is still playing / on cooldown -> deny, leave this bear for later.
        now = GetTime();
        if ( now < level.acc_ee_cooldown_until )
        {
            remain = int( ( level.acc_ee_cooldown_until - now + 999 ) / 1000 );
            player PlaySound( "zmb_no_purchase" );
            player acc_utility::hud_msg( "^3Jukebox busy^7 - " + remain + "s" );
            continue;
        }

        // ORDER-BASED PRICE (1st=500, 2nd=1000, 3rd=1500) - keyed to how many you've played, not which bear.
        cost = ee_cost_for_play( level.acc_ee_play_count );
        if ( !( player zm_score::can_player_purchase( cost ) ) )
        {
            player PlaySound( "zmb_no_purchase" );
            player acc_utility::hud_msg( "^1Need " + cost + " points" );
            continue;
        }

        player zm_score::minus_to_player_score( cost );
        player PlaySound( "zmb_cha_ching" );

        b.used = true;
        level.acc_ee_play_count++;
        level.acc_ee_cooldown_until = GetTime() + ( getdvarint( "acc_ee_song_cooldown", ACC_EE_COOLDOWN_SEC ) * 1000 );

        // Consume this bear: retire its trigger + vanish the bear (matches the original one-shot behaviour).
        b.trig SetHintString( "" );
        b.trig TriggerEnable( false );
        if ( isdefined( b.bear ) ) b.bear Delete();

        refresh_hints( all );   // remaining bears now show the NEXT (higher) price + the busy state

        play_ee_song( b.song );
        acc_utility::log( "ee_song: play #" + level.acc_ee_play_count + " (" + b.song + " / " + b.title + ") cost " + cost );

        // NOW-PLAYING banner with the SONG TITLE, shown to EVERY player (user 2026-06-26): the song plays 2D
        // for the whole lobby, so the whole lobby sees what's on - not just the player who fed the jukebox.
        // Uses IPrintLnBold (engine built-in, all-clients, pool-FREE) - NOT acc_utility::hud_msg, whose
        // lazily-created server hudelem can silently fail to appear when the hudelem pool is exhausted (esp. in
        // dev mode with the extra dev HUDs - user 2026-06-28 "song UI didn't show when I bought a song"). This
        // is the same reliable all-player announcement the Paradise gate / soul milestones use.
        foreach ( p in GetPlayers() )
            if ( isdefined( p ) && isplayer( p ) )
                p IPrintLnBold( "^5NOW PLAYING^7  " + b.title );

        return;   // this bear is done for the game
    }
}

// Cost for the Nth song triggered this game (0-indexed count). Past the 3rd it stays at the 3rd price (safety).
function ee_cost_for_play( count )
{
    if ( count <= 0 ) return getdvarint( "acc_ee_song_cost_1", ACC_EE_COST_1 );
    if ( count == 1 ) return getdvarint( "acc_ee_song_cost_2", ACC_EE_COST_2 );
    return getdvarint( "acc_ee_song_cost_3", ACC_EE_COST_3 );
}

// Set every un-played bear's hint to the live price, or a "busy" tag while the 5-min cooldown is running.
function refresh_hints( all )
{
    busy = ( GetTime() < level.acc_ee_cooldown_until );
    cost = ee_cost_for_play( level.acc_ee_play_count );
    for ( i = 0; i < all.size; i++ )
    {
        b = all[ i ];
        if ( IS_TRUE( b.used ) ) continue;
        if ( !isdefined( b.trig ) ) continue;
        if ( busy )
            b.trig SetHintString( "Hold ^3[{+activate}]^7  Play Song  ^1[Jukebox busy]" );
        else
            b.trig SetHintString( "Hold ^3[{+activate}]^7  Play Song  ^2[Cost: " + cost + "]" );
    }
}

// Keep the hints live: refresh once whenever the cooldown STARTS or ELAPSES. Stops when all 3 are played.
function hint_ticker( all )
{
    level endon( "end_game" );

    prev_busy = ( GetTime() < level.acc_ee_cooldown_until );
    for ( ;; )
    {
        wait 1;
        if ( level.acc_ee_play_count >= all.size ) return;   // all bears spent - nothing left to label

        busy = ( GetTime() < level.acc_ee_cooldown_until );
        if ( busy != prev_busy )
        {
            refresh_hints( all );
            prev_busy = busy;
        }
    }
}

// Play a song through the single MUSIC CHANNEL (one-shot). acc_music::play STOPS whatever song was playing first
// (e.g. boss music while you fight the Phantom) so only the teddy-bear song is heard, then plays it 2D for the
// whole lobby (user 2026-06-25 override rule). NONLOOPING.
function play_ee_song( alias )
{
    acc_music::play( alias, false );
    acc_utility::log( "ee_song: PLAYING " + alias + " - via music channel (stops any other song)" );
}
