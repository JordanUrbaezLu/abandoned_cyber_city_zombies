// =============================================================================
// _acc_music.gsc - the single MUSIC CHANNEL (user 2026-06-25)
//
// ONE song at a time, ever. Every SONG source routes through acc_music::play(), which STOPS whatever is
// currently playing and starts the new one - so two songs can never overlap ("override and play the last one
// triggered, stop the previous"). Sources routed here:
//   - main theme            (_acc_atmosphere::apply_music)
//   - boss music            (_acc_boss::boss_music)
//   - jukebox machine       (_acc_jukebox - was the 3 teddy bears until 2026-07-09)
//   - Paradise calm + 115   (_acc_paradise)
// NOT routed (by design): PERK JINGLES (acc_jingle_*) and the ambient city bed (acc_amb_city_bed) - those are
// SFX / ambience, not songs, and are meant to layer under the music. (User 2026-06-25: "this doesn't apply to
// perk jingles.")
//
// WHY A CHANNEL: zm_utility::play_sound_2D spawns an INTERNAL temp emitter and gives you no handle, so a song
// started that way can't be stopped to make room for the next one. This channel OWNS the emitter, so play()
// can stop it.
//
// THE ONE STOPPABLE PRIMITIVE (2026-08-03 redesign - the 5th and FINAL "one song at a time" fix): EVERY song
// now plays via PlayLoopSound on a LOOPING alias, because that is the ONLY primitive this codebase has EVER
// observed cutting a streamed track (the boss loop, months of clean cuts). A STREAMED NONLOOPING one-shot
// started with PlaySoundWithNotify is engine-level UNSTOPPABLE: StopSounds() never silenced one here (the
// 2026-08-02 stop-frame fix ran on a live ent and the user still heard overlap), stock NEVER stops streamed
// music server-side (all stock music is the client-side musicstate machine, _zm_audio.gsc), and the aliases'
// StopOnEntDeath defaults to no so even Delete() left the stream playing. So: all 10 song aliases in
// sound/aliases/acc_audio.csv were flipped NONLOOPING -> LOOPING (2026-08-03), play() ALWAYS PlayLoopSound's,
// and one-shot SEMANTICS come from oneshot_end_watchdog: SoundGetPlaybackTime(alias) (proven server-side on
// these exact streamed aliases - the jukebox hold, _acc_jukebox.gsc) + wait(duration) + StopLoopSound before
// the loop wraps. This is the user's "check the time on the song" proposal, applied where it has teeth.
//
// HARD STOP, no fade: override is instant (Delete the old ent) so there is never a fade-overlap window. The
// boss music's old 4s fade-out is intentionally dropped in favour of the no-overlap guarantee.
//
// PRIORITY (user 2026-08-02 "only one song plays at a time: jukebox < boss < paradise"): the channel
// carries a priority level - jukebox 1 < boss 2 < paradise 3. NEW SONG SOURCES MUST USE claim_*()
// (claim_jukebox / claim_boss / claim_paradise), which refuse when a higher-priority source owns the
// channel and cut a lower one instantly. Bare play() is the FORCE path (priority 0 wins over nothing but
// overrides everything - it stops the current song regardless): only the main theme (blackscreen, nothing
// else can be live) and the game-over song (must beat even Paradise) still call it directly. Priority
// drops to 0 when the owning song stops or a one-shot ends naturally - the channel does NOT auto-resume
// the cut lower-priority song (a cut jukebox track stays cut; the jukebox hold self-clears, see
// _acc_jukebox::jukebox_cut_watch).
//
// STOP-FRAME FIX (2026-08-02, kept): StopSounds() is VOID if the emitter is Delete()'d in the same server
// frame (Treyarch's own comment, sound_shared.gsc::play_on_tag) - stop() defers the Delete one frame. This
// alone did NOT fix the overlap (streamed one-shots ignored StopSounds even on a live ent - see the
// primitive note above), but it stays as hygiene for the StopLoopSound path.
//
// NO LAYERED MUSIC EITHER (user 2026-08-03 "only have one song at a time... it doesnt work still"): the
// round-change stingers are full BUS_MUSIC tracks (~9-15s) that used to layer OVER the current song by
// design (2026-07-02) - at every round boundary that IS "two songs at once". Superseded: a stinger is
// SKIPPED while a channel song plays, rides the same LOOPING+watchdog recipe so it is stoppable, and
// play() kills any live stinger (plus the Fire Sale per-pad mus_fire_sale loops, registered by
// _zm_aw_mysterybox in level.acc_firesale_music_ents) before starting a song.
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
    level.acc_music_pri = 0;           // priority of the current song: 0 none/forced, 1 jukebox, 2 boss, 3 paradise
    level thread round_sounds_watcher();   // Kino/BO1 round-change stingers (user 2026-07-02)
}

// Play `alias`, OVERRIDING (instantly stopping) whatever song is playing. looping=true for a track that loops
// until stopped (boss / finale); false for a track with one-shot SEMANTICS (ends on its own via the duration
// watchdog). EVERY alias is a LOOPING csv row played via PlayLoopSound - the one proven-stoppable primitive
// (see header, 2026-08-03 redesign). Reaches every client (2D alias).
function play( alias, looping )
{
    if ( !isdefined( alias ) ) return;

    stop();                 // hard-stop the current song first -> no overlap
    stop_layered_music();   // and kill stingers / fire-sale pad loops - ONE music at a time (user 2026-08-03)

    e = spawn( "script_origin", ( 0, 0, 0 ) );
    level.acc_music_ent = e;
    level.acc_music_cur = alias;

    e PlayLoopSound( alias );
    if ( !IS_TRUE( looping ) )
        e thread oneshot_end_watchdog( alias );

    acc_utility::log( "music: -> " + alias + ( IS_TRUE( looping ) ? " (loop)" : "" ) );
}

// self = the channel ent. Gives a LOOPING alias one-shot semantics: wait the track's real length (queried,
// not hardcoded - SoundGetPlaybackTime returns ms server-side on these exact streamed aliases, the proven
// jukebox-hold recipe at _acc_jukebox.gsc), then cut the loop ONE FRAME BEFORE IT WRAPS and free the
// channel. This is the user's "check the time on the song" watchdog (2026-08-03). If a newer play()/stop()
// overrides first, the "acc_music_override" endon kills this thread and stop() handles cleanup.
function oneshot_end_watchdog( alias )
{
    self endon( "acc_music_override" );
    // Deliberately NO level endon("end_game"): stock can notify end_game more than once (solo
    // insta-kill death, disconnect at the score screen - verify-pass catch 2026-08-03), and a
    // second notify would kill the GAME-OVER song's own watchdog, leaving the now-LOOPING
    // mus_gameover_intro repeating until map exit. Regular songs need no end_game kill either -
    // the gameover play() hard-stops them via the override notify.

    dur_ms = SoundGetPlaybackTime( alias );
    if ( !isdefined( dur_ms ) || dur_ms <= 0 ) dur_ms = 400000;   // query failed: conservative 400s cap
                                                                  // (longest song ~359s) so the loop can
                                                                  // never repeat forever
    t = ( dur_ms / 1000 ) - 0.05;
    if ( t < 0.05 ) t = 0.05;
    wait( t );

    if ( isdefined( level.acc_music_ent ) && level.acc_music_ent == self )
    {
        level.acc_music_ent = undefined;
        level.acc_music_cur = undefined;
        level.acc_music_pri = 0;       // a naturally-finished song frees the channel for any priority
    }
    self StopLoopSound( 0 );           // cut before the wrap - the track "ends" like a one-shot
    self StopSounds();
    level thread delete_next_frame( self );
}

// Stop the current song instantly. Safe if nothing is playing.
function stop()
{
    alias = level.acc_music_cur;       // capture BEFORE clearing - the per-alias StopSound below needs it
    level.acc_music_cur = undefined;
    level.acc_music_pri = 0;
    if ( !isdefined( level.acc_music_ent ) ) return;

    e = level.acc_music_ent;
    level.acc_music_ent = undefined;

    e notify( "acc_music_override" );   // end oneshot_end_watchdog before we delete the ent
    e StopLoopSound( 0 );               // THE stop that works (every song is a loop now - see header)
    if ( isdefined( alias ) )
        e StopSound( alias );           // per-alias builtin, belt-and-braces (stock face.gsc precedent;
                                        // zm_alien_isolation's jukebox interrupt recipe, docs/16:802)
    e StopSounds();
    level thread delete_next_frame( e );   // STOP-FRAME FIX (see header): a same-frame Delete voids the
                                           // stop calls - defer the Delete one tick. stop() itself stays
                                           // synchronous for play() callers.
}

// Kill every music source OUTSIDE the song channel (user 2026-08-03 "only one song at a time"): live
// round-change stingers (LOOPING + watchdog, same recipe as songs) and the Fire Sale per-pad
// mus_fire_sale loops (_zm_aw_mysterybox registers them in level.acc_firesale_music_ents; a pad loop
// dies with its ent - the proven loop kill).
function stop_layered_music()
{
    stop_stingers();
    if ( isdefined( level.acc_firesale_music_ents ) )
    {
        foreach ( e in level.acc_firesale_music_ents )
        {
            if ( isdefined( e ) ) e Delete();   // loop dies with the ent
        }
        level.acc_firesale_music_ents = [];
    }
}

// Kill every live stinger. Called by stop_layered_music (song starting) AND by play_stinger itself -
// a NEW stinger CUTS the previous one (verify-pass catch 2026-08-03: with the same-day ~5s round
// transitions, the ~10s round-END stinger is still playing when the ~14s round-START stinger fires,
// so uncut stingers would overlap each other at nearly every round boundary).
function stop_stingers()
{
    if ( !isdefined( level.acc_music_stinger_ents ) ) return;
    foreach ( e in level.acc_music_stinger_ents )
    {
        if ( !isdefined( e ) ) continue;
        e notify( "acc_stinger_override" );
        e StopLoopSound( 0 );
        e StopSounds();
        level thread delete_next_frame( e );
    }
    level.acc_music_stinger_ents = [];
}

// The one-frame deferred emitter delete (stock sound_shared.gsc::play_on_tag precedent). No endon:
// at end_game the ent dies with the map anyway; a 0.05s transient ent is negligible G_Spawn load.
function delete_next_frame( e )
{
    wait 0.05;
    if ( isdefined( e ) ) e Delete();
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

// ---------------------------------------------------------------------------
// PRIORITY CLAIMS (user 2026-08-02): jukebox 1 < boss 2 < paradise 3. A claim at >= the
// current priority cuts the current song and takes the channel; a claim BELOW it is DENIED
// (returns false, nothing plays, nothing stops). Callers use the named wrappers - the
// priority values stay module-private (GSC #defines don't cross files). Priority is set
// AFTER play() because play()'s internal stop() zeroes it.
// ---------------------------------------------------------------------------
function claim( alias, looping, pri )
{
    if ( pri < level.acc_music_pri ) return false;
    play( alias, looping );
    level.acc_music_pri = pri;
    return true;
}

function can_claim( pri )
{
    return ( pri >= level.acc_music_pri );
}

function claim_jukebox( alias )  { return claim( alias, false, 1 ); }
function claim_boss( alias )     { return claim( alias, true,  2 ); }
function claim_paradise( alias ) { return claim( alias, false, 3 ); }
function jukebox_can_claim()     { return can_claim( 1 ); }

// =============================================================================
// Kino/BO1 round-change stingers (Ultimate Round Sounds pack by WetEgg, user 2026-07-02).
// Stock usermaps play NOTHING on a round change, so these hook the stock round notifies
// (verified in stock _zm.gsc: "start_of_round" :4433, "end_of_round" :4449, "end_game" :1791)
// and play the classic WaW/Kino stingers. NO LONGER LAYERED (user 2026-08-03 "only one song
// at a time" - the old 2026-07-02 layering design put a full ~9-15s BUS_MUSIC track over the
// current song at EVERY round boundary, which IS the "two songs at once" the user kept
// hearing): a stinger is SKIPPED while a channel song plays, rides the same LOOPING-alias +
// duration-watchdog recipe as songs so it is actually stoppable, is tracked in
// level.acc_music_stinger_ents, and play() kills any live stinger before a song starts.
// GAME OVER routes through the channel (play() stops everything; correct at end_game). The
// pack's own GSC/gsh system + its zm_usermap assetlist hack are deliberately NOT installed -
// aliases only (sound/aliases/acc_round_sounds.csv, stinger + gameover rows flipped
// nonlooping -> looping 2026-08-03; wavs install-side under sound_assets\_wetegg\).
// The dog-round aliases (mus_dogstart1_intro/mus_dogend1_intro) ship in the CSV but are
// unhooked - this map has no dog rounds.
// =============================================================================
function round_sounds_watcher()
{
    level.acc_music_stinger_ents = [];
    level thread round_stinger_loop( "start_of_round", "mus_roundstart1_intro" );
    level thread round_stinger_loop( "end_of_round", "mus_roundend1_intro" );
    level thread gameover_song_watcher();
}

function round_stinger_loop( note, alias )
{
    level endon( "end_game" );
    for ( ;; )
    {
        level waittill( note );
        // ONE music at a time (user 2026-08-03): never layer a stinger over a channel song.
        if ( isdefined( level.acc_music_cur ) ) continue;
        level thread play_stinger( alias );
    }
}

function gameover_song_watcher()
{
    level waittill( "end_game" );
    play( "mus_gameover_intro", false );   // channel play: stops the theme for the game-over song
}

// 2D stinger on its own emitter, OUTSIDE the song channel but no longer layered over it (gated in
// round_stinger_loop; killed by play()). Same LOOPING-alias + watchdog recipe as songs - the
// PlaySoundWithNotify one-shot it used before was engine-unstoppable (see header). Registered in
// level.acc_music_stinger_ents (pruned of dead ents on each registration). Reaches every client.
function play_stinger( alias )
{
    stop_stingers();   // a new stinger CUTS the previous one (5s round transitions: the round-end
                       // stinger tail would otherwise underlie every round-start stinger)

    e = spawn( "script_origin", ( 0, 0, 0 ) );
    level.acc_music_stinger_ents = [];
    level.acc_music_stinger_ents[ 0 ] = e;

    e PlayLoopSound( alias );
    e thread stinger_end_watchdog( alias );
}

// self = the stinger emitter. Cuts the loop at the track's real length so the stinger plays exactly
// once (the songs' oneshot_end_watchdog recipe, short-form).
function stinger_end_watchdog( alias )
{
    self endon( "acc_stinger_override" );
    // NO level endon("end_game") - same reasoning as oneshot_end_watchdog: an endon kill here
    // would strand a LOOPING stinger; at end_game the gameover play()'s stop_layered_music
    // cuts live stingers via the override notify anyway.

    dur_ms = SoundGetPlaybackTime( alias );
    if ( !isdefined( dur_ms ) || dur_ms <= 0 ) dur_ms = 20000;   // stingers are ~9-15s; 20s cap
    t = ( dur_ms / 1000 ) - 0.05;
    if ( t < 0.05 ) t = 0.05;
    wait( t );

    self StopLoopSound( 0 );
    self StopSounds();
    level thread delete_next_frame( self );
}
