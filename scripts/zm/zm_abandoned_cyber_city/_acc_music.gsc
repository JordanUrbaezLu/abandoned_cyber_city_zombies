// =============================================================================
// _acc_music.gsc - the single MUSIC CHANNEL (user 2026-06-25)
//
// ONE song at a time, ever. Every SONG source routes through acc_music::play(), which STOPS whatever is
// currently playing and starts the new one - so two songs can never overlap ("override and play the last one
// triggered, stop the previous"). Sources routed here:
//   - main theme            (_acc_atmosphere::apply_music)
//   - boss music            (_acc_boss::boss_music)
//   - teddy-bear jukebox    (_acc_ee_song::play_ee_song)
//   - Paradise calm + 115   (_acc_paradise)
// NOT routed (by design): PERK JINGLES (acc_jingle_*) and the ambient city bed (acc_amb_city_bed) - those are
// SFX / ambience, not songs, and are meant to layer under the music. (User 2026-06-25: "this doesn't apply to
// perk jingles.")
//
// WHY A CHANNEL: zm_utility::play_sound_2D spawns an INTERNAL temp emitter and gives you no handle, so a song
// started that way can't be stopped to make room for the next one. This channel OWNS the emitter, so play()
// can stop it. Reach-all in coop is preserved by using the exact proven idioms: a one-shot uses
// PlaySoundWithNotify on a script_origin (the stock really_play_2D_sound path the EE song already uses - whole
// lobby hears it); a loop uses PlayLoopSound (same as the boss / ambient emitters). Either is stoppable via
// StopLoopSound / StopSounds / Delete on the owned ent.
//
// HARD STOP, no fade: override is instant (Delete the old ent) so there is never a fade-overlap window. The
// boss music's old 4s fade-out is intentionally dropped in favour of the no-overlap guarantee.
// =============================================================================

#using scripts\shared\util_shared;

#using scripts\zm\zm_abandoned_cyber_city\_acc_utility;

#insert scripts\shared\shared.gsh;   // IS_TRUE

#namespace acc_music;

// Call ONCE from acc_main::init(), BEFORE any music source starts (atmosphere / boss / ee_song / paradise).
function init()
{
    level.acc_music_ent = undefined;
    level.acc_music_cur = undefined;   // alias currently playing (or undefined) - lets callers avoid restart / stop-if-mine
}

// Play `alias`, OVERRIDING (instantly stopping) whatever song is playing. looping=true for a track that loops
// until stopped (boss / finale); false for a one-shot that ends on its own. Reaches every client.
function play( alias, looping )
{
    if ( !isdefined( alias ) ) return;

    stop();   // hard-stop the current song first -> no overlap

    e = spawn( "script_origin", ( 0, 0, 0 ) );
    level.acc_music_ent = e;
    level.acc_music_cur = alias;

    if ( IS_TRUE( looping ) )
        e PlayLoopSound( alias );
    else
        e thread oneshot_play( alias );

    acc_utility::log( "music: -> " + alias + ( IS_TRUE( looping ) ? " (loop)" : "" ) );
}

// self = the channel ent. A one-shot, reach-all song (stock really_play_2D_sound idiom). Clears the channel
// when it ends naturally. If a newer play()/stop() overrides it first, the "acc_music_override" endon kills
// this thread before its cleanup and stop() deletes the ent.
function oneshot_play( alias )
{
    self endon( "acc_music_override" );
    level endon( "end_game" );

    self PlaySoundWithNotify( alias, "acc_music_oneshot_done" );
    self waittill( "acc_music_oneshot_done" );

    if ( isdefined( level.acc_music_ent ) && level.acc_music_ent == self )
    {
        level.acc_music_ent = undefined;
        level.acc_music_cur = undefined;
    }
    if ( isdefined( self ) ) self Delete();
}

// Stop the current song instantly. Safe if nothing is playing.
function stop()
{
    level.acc_music_cur = undefined;
    if ( !isdefined( level.acc_music_ent ) ) return;

    e = level.acc_music_ent;
    level.acc_music_ent = undefined;

    e notify( "acc_music_override" );   // end oneshot_play before we delete the ent
    e StopLoopSound( 0 );               // instant loop stop (no-op for a one-shot)
    e StopSounds();                     // stop a one-shot immediately (stock builtin, sound_shared.gsc)
    e Delete();                         // free the emitter (also stops anything still on it)
}

// Stop ONLY if `alias` is the song currently playing. Used by the boss-music end so a teddy-bear song (or a
// Paradise track) that OVERRODE the boss music mid-fight is not yanked when the boss later dies.
function stop_if( alias )
{
    if ( isdefined( level.acc_music_cur ) && level.acc_music_cur == alias )
        stop();
}

// True if `alias` is the song currently playing on the channel.
function is_playing( alias )
{
    return ( isdefined( level.acc_music_cur ) && level.acc_music_cur == alias );
}
