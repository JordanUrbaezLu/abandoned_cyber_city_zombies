// =============================================================================
// _acc_paradise.gsc - the PARADISE final gauntlet + WIN condition (user 2026-06-25)
//
// Paradise (the open-air plaza below the abyss, gen_descent_hub.js) is the END of the map. Once the communal
// gate opens (_acc_abyss_doors) and the team drops in, a SCRIPTED FINALE plays out - and surviving it WINS the
// match. "Paradise" is ironic: it lulls you, then it tries to kill you.
//
// THE SEQUENCE (all live-tunable acc_paradise_* dvars; defaults below):
//   PHASE 1 - CALM (acc_paradise_calm_sec, 60s): you "made it." A one-shot VICTORY fanfare (acc_paradise_calm)
//             plays, the air is clear, only a VERY light trickle of zombies wanders in. A fakeout.
//   PHASE 2 - OMEN (instant, at the end of the calm): the FOG rolls back in (acc_atmosphere::paradise_fog_on)
//             and the dog-round announcer ("fetch me their souls" = stock zmb_dog_round_start) howls.
//   PHASE 3 - DREAD (acc_paradise_dread_sec, 10s): just the fog closing in, the trickle continuing. Tension.
//   PHASE 4 - BATTLE (acc_paradise_survive_sec, 225s = 3:45): the arena SEALS, the "115" anthem
//             (acc_paradise_music) drops, and 2 Brutus + 1 Phantom storm in ALONGSIDE the horde (x4 spawn rate +
//             shield/glitch gauntlet). EVERY MINUTE the whole battle escalates IN LOCKSTEP: +1 Brutus + 1 Phantom
//             join (up to the caps), the WORLD-WIDE horde trench-buff steps up a layer (L2 minute 0-1 -> L3 -> L4 ->
//             L5 final wave), and a UI alert fires ("The horde is getting stronger", or "You will never escape!"
//             on the final L5 step) - so the alert lands exactly when a Brutus spawns. Four waves: L2/L3/L4 are
//             60s each, the FINAL L5 wave is 45s (3:00 -> 3:45). NO power-up drops the whole
//             battle (no insta-kill / max-ammo / double-points - block_powerup_drop). A countdown TIMER HUD shows
//             the time left; the BOSS HUD + boss music are SUPPRESSED for the whole battle (level.acc_paradise_
//             onslaught - read by _acc_health_bars and _acc_boss::boss_music).
//
// WIN: survive the 3:45 battle (team not wiped) -> the documented BO3 end-game sequence (docs/22): victory
// banner -> freeze controls -> fade to black -> purge the horde (DoDamage health+666) -> level notify("end_game")
// (the single stock signal that ends the zombies match to the post-game scoreboard; there is no separate
// "victory" screen, so the banner is what tells the player they WON vs died).
// LOSE: if the team is wiped at any point, stock fires game-over normally (our endon kills the loops).
//
// AUDIO needs three wavs at sound_assets/acc/music/ (48k/16-bit) + a GAME-CLOSED sound build to play (the .sabs
// bank is file-locked while BO3 runs - memory custom-sound-48k-and-game-lock): 115.wav (battle), paradise_calm.wav
// (victory fanfare). The omen uses the STOCK zmb_dog_round_start (no asset). LICENSING: 115 / Mario fanfare are
// not CC0 - test-only, NOT for the public Workshop (CREDITS.md IP review).
//
// GSC-ONLY + LED-SAFE: pure script (risers are computed structs, the HUD is server hudelems, the fog is a script
// SetVolFog) - builds with `-GscOnly`, no .map / material / sky change, no LED bake.
// =============================================================================

#using scripts\shared\flag_shared;
#using scripts\shared\util_shared;
#using scripts\shared\hud_util_shared;
#using scripts\shared\ai\zombie_utility;

#using scripts\zm\_zm_utility;   // play_sound_2D() - the proven "music for the whole lobby" path (same as the EE song)

#insert scripts\shared\shared.gsh;

#using scripts\zm\zm_abandoned_cyber_city\_acc_utility;
#using scripts\zm\zm_abandoned_cyber_city\_acc_music;         // single music channel (calm + 115 route through it)
#using scripts\zm\zm_abandoned_cyber_city\_acc_atmosphere;    // paradise_fog_on (roll the fog back in)
#using scripts\zm\zm_abandoned_cyber_city\_acc_bus_trench;    // get_paradise_risers / tag_trench_zombie / player_in_second_part
#using scripts\zm\zm_abandoned_cyber_city\_acc_elites;        // promote_to_shielded (the "Riot" elite)
#using scripts\zm\zm_abandoned_cyber_city\_acc_boss_glitch;   // spawn_glitch (the Glitch Stalker)
#using scripts\zm\zm_abandoned_cyber_city\_acc_boss_brutus;   // spawn_one_paradise / paradise_warden_think
#using scripts\zm\zm_abandoned_cyber_city\_acc_boss_phantom;  // spawn_phantom (returns the host)
#using scripts\zm\zm_abandoned_cyber_city\_acc_boss;          // scale_mini_boss_hp (paradise Brutus HP, consistent with the trench warden)
#using scripts\zm\zm_abandoned_cyber_city\_acc_coop_scaling;  // boss_hp_player_mult (log coop HP)

// --- Tunable defaults. Every one a live acc_paradise_* dvar (mirror docs/34). ---
#define ACC_PARADISE_CALM_SEC_DEF         60    // PHASE 1: calm/victory-fakeout seconds before the fog hits
#define ACC_PARADISE_DREAD_SEC_DEF        10    // PHASE 3: fog-closing-in seconds before the battle (user 2026-06-26: 15 -> 10)
#define ACC_PARADISE_SURVIVE_SEC_DEF      225   // PHASE 4: battle survival time to WIN (seconds) = 3:45 (user 2026-06-27). 60s escalation => waves L2/L3/L4 @ 60s each + the final L5 wave @ 45s (180->225).
#define ACC_PARADISE_TRICKLE_SEC_DEF      12.0  // seconds between the "very light" calm/dread trickle spawns
#define ACC_PARADISE_AI_BONUS_DEF         12    // EXTRA global AI-cap headroom for the battle horde (stacks on the trench +14)
#define ACC_PARADISE_SPAWN_MULT_DEF       4     // the "x4" battle spawn-rate multiplier (user 2026-06-25)
#define ACC_PARADISE_SURGE_COUNT_DEF      1     // base regular zombies per surge tick (x spawn_mult)
#define ACC_PARADISE_SURGE_INTERVAL_DEF   3.0   // seconds between regular surge ticks (battle)
#define ACC_PARADISE_SPECIAL_INTERVAL_DEF 10.0  // seconds between shield+glitch special waves (battle) - was 15 (user 2026-06-25: "more shields")
#define ACC_PARADISE_SHIELD_PER_WAVE_DEF  3     // Shielded ("Riot") elites per special wave - was 1 (user 2026-06-25: "not enough shields")
#define ACC_PARADISE_GLITCH_PER_WAVE_DEF  1     // Glitch Stalkers per special wave
#define ACC_PARADISE_SPECIAL_MAX_DEF      12    // concurrent shielded+glitch cap (engine actor-overflow guard) - was 8 (room for the extra shields; lower if unstable)
#define ACC_PARADISE_BRUTUS_MAX_DEF       4     // concurrent paradise Brutus cap (escalation stops adding past this) - lower if unstable
#define ACC_PARADISE_PHANTOM_MAX_DEF      4     // concurrent paradise Phantom cap
#define ACC_PARADISE_BOSS_INTERVAL_DEF    60.0  // seconds between escalation ticks (+1 Brutus +1 Phantom + buff step + alert each "minute")
#define ACC_PARADISE_BUFF_START_DEF       2     // world-wide horde trench-buff layer for the FIRST battle minute (0-1 min)
#define ACC_PARADISE_BUFF_MAX_DEF         5     // deepest horde layer (reached at the 3:00 step, held for the final 45s wave)
// (The Paradise holistic HORDE BUFF anti-camp - the WHOLE battle horde shares ONE trench-equivalent layer that steps
// L2 -> L3 -> L4 -> L5 on the BATTLE CLOCK, +1 each minute, in lockstep with the Brutus escalation + the UI alert
// below. The per-layer SPEED + HEALTH treatment lives in _acc_zombie_speed.gsc::paradise_buff_layer (it just READS
// our level.acc_paradise_horde_layer); WE own + step that var here in escalation_loop. user 2026-06-26, reworked
// from the old per-zombie 30s-alive ramp.)

#namespace acc_paradise;

// ---------------------------------------------------------------------------
// Lifecycle
// ---------------------------------------------------------------------------

function init()
{
    acc_utility::log( "paradise: init (calm -> fog/omen -> 3:45 battle -> WIN; arms on Paradise open)" );
    level.acc_paradise_open       = false;
    level.acc_paradise_started    = false;
    level.acc_paradise_onslaught  = false;   // true ONLY during PHASE 4 (battle): suppresses the boss HUD + boss music + power-up drops
    level.acc_paradise_won        = false;
    level.acc_paradise_brutus_count  = 0;
    level.acc_paradise_phantom_count = 0;
    level.acc_paradise_horde_layer   = 0;    // world-wide horde trench-buff layer (0 outside the battle); set to L2 at start_battle, +1/min in escalation_loop

    // NO power-up drops during the battle (user 2026-06-26): claim the stock powerup_drop override hook
    // (_zm_powerups.gsc:588 - a true return SUPPRESSES the drop). block_powerup_drop returns true ONLY while
    // level.acc_paradise_onslaught, so the rest of the match drops normally and this self-clears on win/wipe.
    level.custom_zombie_powerup_drop = &block_powerup_drop;

    level thread arm_watch();
}

// True once the finale is allowed to start: Paradise has OPENED in normal play (the communal gate set
// level.acc_paradise_open), OR the dev sandbox is on (so a tester who drops in gets the finale without paying the
// gate). Master live toggle acc_paradise_deathzone 0 disables the whole thing.
function armed()
{
    if ( getdvarint( "acc_paradise_deathzone", 1 ) != 1 ) return false;
    if ( IS_TRUE( level.acc_paradise_open ) ) return true;
    if ( IS_TRUE( level.acc_dev ) ) return true;
    return false;
}

// Wait for Paradise to be armed AND the team to actually DROP IN, then run the finale - ONCE.
function arm_watch()
{
    level endon( "end_game" );
    level flag::wait_till( "initial_blackscreen_passed" );

    while ( !( armed() && any_player_in_paradise() ) )
        wait 0.5;

    if ( IS_TRUE( level.acc_paradise_started ) ) return;
    level.acc_paradise_started = true;
    level thread run_finale();
}

// The scripted finale: calm -> omen -> dread -> battle. A single linear thread so the phase order is obvious;
// each phase's ongoing behaviour (trickle, horde, escalation, timer) is a child thread it spawns.
function run_finale()
{
    level endon( "end_game" );

    // ---- PHASE 1: CALM (the fakeout) ----
    acc_utility::log( "paradise: PHASE 1 calm (" + getdvarint( "acc_paradise_calm_sec", ACC_PARADISE_CALM_SEC_DEF ) + "s)" );
    play_calm_music();   // one-shot victory fanfare
    foreach ( p in GetPlayers() )
        if ( isdefined( p ) && isplayer( p ) ) p IPrintLnBold( "^2PARADISE^7 - you made it..." );
    level thread light_trickle_loop();   // a VERY light trickle (endon'd when the battle takes over)
    wait getdvarfloat( "acc_paradise_calm_sec", ACC_PARADISE_CALM_SEC_DEF );

    // ---- PHASE 2: OMEN (the turn) ----
    acc_utility::log( "paradise: PHASE 2 omen - fog + 'fetch me their souls'" );
    acc_atmosphere::paradise_fog_on();   // roll the fog back in
    play_fetch_souls();                  // stock dog-round announcer
    foreach ( p in GetPlayers() )
        if ( isdefined( p ) && isplayer( p ) ) p IPrintLnBold( "^1...something is coming." );

    // ---- PHASE 3: DREAD (fog closing in) ----
    wait getdvarfloat( "acc_paradise_dread_sec", ACC_PARADISE_DREAD_SEC_DEF );

    // ---- PHASE 4: BATTLE ----
    start_battle();
}

function start_battle()
{
    level notify( "acc_paradise_battle" );   // stop the light trickle (the battle horde takes over)
    level.acc_paradise_onslaught   = true;   // -> _acc_health_bars + _acc_boss::boss_music suppress the boss HUD/music; block_powerup_drop suppresses drops
    level.acc_paradise_horde_layer = getdvarint( "acc_paradise_buff_start", ACC_PARADISE_BUFF_START_DEF );  // the whole horde opens at L2 (minute 0-1); escalation_loop steps it +1/min to L5

    acc_utility::log( "paradise: PHASE 4 BATTLE - survive " +
        getdvarint( "acc_paradise_survive_sec", ACC_PARADISE_SURVIVE_SEC_DEF ) + "s to win" );

    seal_arena();          // a true last stand: no retreat up the abyss
    gather_stragglers();   // pull any player NOT in the plaza INTO the fight - nobody left behind / stuck up top
    start_finale_music();  // the "115" anthem at max volume

    // CLEAN SLATE (user 2026-06-25): kill EVERY zombie currently on the map - the leftover horde (incl. any
    // stuck up top, since all players are now down in Paradise) and the calm-phase trickle - so the battle
    // starts fresh with only the Paradise horde + bosses. DoDamage health+666 = same purge the win cut uses.
    purge_zombies();

    // SPAWN LOCKDOWN (user 2026-06-25: "all zombies need to spawn down low in paradise"). PAUSE the STOCK round
    // spawn manager so NO more zombies erupt from the surface / abyss zones - those spawn UP TOP and, with the
    // gate re-sealed (seal_arena), get stranded away from the fight. Stock round_spawning blocks on the flag
    // "spawn_zombies" (_zm.gsc:3753), so clearing it stops ALL stock surface spawns AND freezes the round
    // (level.zombie_total never drains -> the round can't advance and re-spawn topside) for the timed finale.
    // The Paradise onslaught (surge / spawn_shielded / the bus-trench surge) force-spawns via
    // zombie_utility::spawn_zombie DIRECTLY, bypassing this flag, so it keeps erupting ONLY from the Paradise
    // risers - making Paradise the SOLE spawn source. Win or wipe both end the match, so no restore is needed.
    if ( getdvarint( "acc_paradise_spawn_lockdown", 1 ) == 1 )
        level flag::clear( "spawn_zombies" );

    foreach ( p in GetPlayers() )
        if ( isdefined( p ) && isplayer( p ) ) p IPrintLnBold( "^1THE PARADISE ONSLAUGHT^7 - SURVIVE 3:45!" );

    // Initial bosses: 2 Brutus + 1 Phantom storm in with the horde.
    level thread spawn_n_brutus( 2 );
    level thread maybe_spawn_phantom();

    level thread ai_pressure();         // raise the AI cap for the x4 horde
    level thread deathzone_loop();      // the x4 regular surge + shield/glitch specials
    level thread escalation_loop();     // every minute: +1 Brutus +1 Phantom, step the horde buff L2->L5, fire the UI alert (all in lockstep)
    level thread survival_timer_loop(); // the countdown HUD + the WIN trigger
}

// Re-seal the Paradise gate so the battle is a contained last stand. Same brushmodel primitives the gate
// open/close uses (_acc_abyss_doors). The surge erupts from risers INSIDE paradise, so cutting the door's
// navmesh link doesn't strand them. Gated by acc_paradise_seal (0 = let players retreat up the abyss).
function seal_arena()
{
    if ( getdvarint( "acc_paradise_seal", 1 ) != 1 ) return;
    door = GetEnt( "acc_abyss_hub_door", "targetname" );
    if ( !isdefined( door ) ) return;
    door show();
    door solid();
    door disconnectpaths();
    acc_utility::log( "paradise: arena sealed (no retreat)" );
}

// ---------------------------------------------------------------------------
// Audio
// ---------------------------------------------------------------------------

// PHASE 1 one-shot victory fanfare (the "you won!" fakeout) - the Mario stage-win jingle (acc_paradise_calm). 2D
// NONLOOPING alias, played LOCALLY on each player once so it fires the moment the team drops in, then leaves an
// eerie quiet before the omen. (PlayLocalSound = the stock dog-round-start idiom; a short jingle, so no stop needed.)
function play_calm_music()
{
    if ( getdvarint( "acc_paradise_music_on", 1 ) != 1 ) return;
    acc_music::play( "acc_paradise_calm", false );   // single music channel - overrides any prior song, one-shot
}

// PHASE 2 omen: the "fetch me their souls" cue. The stock dog-round alias (zmb_dog_round_start) lives in a
// dog-round sound bank our map never loads, so it was SILENT (user 2026-06-25) - so this is a CUSTOM alias
// (acc_paradise_omen) from a user-supplied wav, guaranteed to load (same path as the 115 / Mario tracks).
// 2D NONLOOPING, played LOCALLY on each player. NEEDS sound_assets/acc/fx/paradise_omen.wav (48k/16-bit) + a
// game-closed sound build to play; silent until then.
function play_fetch_souls()
{
    foreach ( p in GetPlayers() )
        if ( isdefined( p ) && isplayer( p ) ) p PlayLocalSound( "acc_paradise_omen" );
}

// PHASE 4 battle anthem: the "115" track at MAX VOLUME (acc_paradise_music, VolMax 100). 2D streamed LOOPING music
// on a level emitter, the same pattern as the boss music - heard everywhere at full volume. Boss music is
// suppressed for the battle (_acc_boss::boss_music returns while level.acc_paradise_onslaught), so this is the ONLY
// track. Stopped on win.
function start_finale_music()
{
    if ( getdvarint( "acc_paradise_music_on", 1 ) != 1 ) return;
    acc_music::play( "acc_paradise_music", false );   // the "115" anthem via the single music channel (overrides + stops boss music)
    acc_utility::log( "paradise: 115 anthem ON (acc_paradise_music)" );
}

// ---------------------------------------------------------------------------
// Occupancy helpers
// ---------------------------------------------------------------------------

function any_player_in_paradise()
{
    players = GetPlayers();
    for ( i = 0; i < players.size; i++ )
    {
        p = players[ i ];
        if ( isdefined( p ) && isplayer( p ) && isalive( p ) && acc_bus_trench::player_in_second_part( p ) )
            return true;
    }
    return false;
}

function any_player_alive()
{
    players = GetPlayers();
    for ( i = 0; i < players.size; i++ )
    {
        p = players[ i ];
        if ( isdefined( p ) && isplayer( p ) && isalive( p ) )
            return true;
    }
    return false;
}

// Once the battle starts, PULL any straggler INTO Paradise so nobody is left behind / stuck up top behind the
// re-sealed gate (user 2026-06-25). Teleports every live player (incl. downed - so they can be revived in the
// arena) who is NOT already in second_part to a validated plaza floor spot, with a small ring offset so they
// don't stack on one point. Live toggle acc_paradise_gather_in (default 1).
function gather_stragglers()
{
    if ( getdvarint( "acc_paradise_gather_in", 1 ) != 1 ) return;

    dest = paradise_gather_point();
    if ( !isdefined( dest ) ) return;

    // Collect the stragglers first, then fan them onto a DETERMINISTIC evenly-spaced ring (ang = i*360/n)
    // instead of a random angle per player. Two random angles can land two stragglers inside each other's
    // ~16u capsule -> the engine EJECTS the stack -> a teammate is punted OOB and killed by the second_part
    // decontamination (project rule: memory coop-teleport-fan-out-not-one-point). Same dest + 48u radius as
    // before, so no new OOB risk - just guaranteed non-overlap (co-op audit 2026-06-27).
    stragglers = [];
    foreach ( p in GetPlayers() )
    {
        if ( !isdefined( p ) || !isplayer( p ) || !isalive( p ) ) continue;
        if ( acc_bus_trench::player_in_second_part( p ) ) continue;   // already in the arena - leave them
        stragglers[ stragglers.size ] = p;
    }
    for ( i = 0; i < stragglers.size; i++ )
    {
        ang = i * 360 / stragglers.size;
        off = ( cos( ang ) * 48, sin( ang ) * 48, 0 );   // 48u ring so multiple stragglers don't stack
        stragglers[ i ] SetOrigin( dest + off );
        stragglers[ i ] IPrintLnBold( "^5The gate seals^7 - pulled into PARADISE for the final stand" );
    }
}

// A validated Paradise floor spot to teleport stragglers to: a living teammate already in the plaza (safest -
// guaranteed standable), else the nav-snapped plaza centre, else a computed riser, else the raw centre.
// Plaza floor z=-1200, interior x[-1000,1000] y[-2200,-600], inside the second_part OOB-veto band.
function paradise_gather_point()
{
    foreach ( p in GetPlayers() )
        if ( isdefined( p ) && isplayer( p ) && isalive( p ) && acc_bus_trench::player_in_second_part( p ) )
            return p.origin;

    c = GetClosestPointOnNavMesh( ( 0, -1300, -1200 ), 256, 16 );
    if ( isdefined( c ) ) return c;

    risers = acc_bus_trench::get_paradise_risers();
    if ( isdefined( risers ) && risers.size > 0 )
        return risers[ 0 ].origin;
    return ( 0, -1300, -1200 );
}

// ---------------------------------------------------------------------------
// The calm/dread "very light trickle" (PHASES 1-3)
// ---------------------------------------------------------------------------

// One wandering zombie every acc_paradise_trickle_sec while the calm/dread phases run - so paradise is never
// FULLY safe, but it is calm. Stops the instant the battle begins (the battle horde takes over).
function light_trickle_loop()
{
    level endon( "end_game" );
    level endon( "acc_paradise_battle" );   // the x4 battle surge replaces it
    level endon( "acc_paradise_end" );

    for ( ;; )
    {
        wait getdvarfloat( "acc_paradise_trickle_sec", ACC_PARADISE_TRICKLE_SEC_DEF );
        if ( !any_player_in_paradise() ) continue;
        surge( 1 );
    }
}

// ---------------------------------------------------------------------------
// PHASE 4 horde: x4 regular surge + shield/glitch specials
// ---------------------------------------------------------------------------

function ai_pressure()
{
    level endon( "end_game" );
    level endon( "acc_paradise_end" );

    raised  = false;
    applied = 0;

    for ( ;; )
    {
        wait 0.5;

        occupied = IS_TRUE( level.acc_paradise_onslaught ) && any_player_in_paradise();

        if ( occupied && !raised && isdefined( level.zombie_ai_limit ) )
        {
            applied = getdvarint( "acc_paradise_ai_bonus", ACC_PARADISE_AI_BONUS_DEF );
            level.zombie_ai_limit = level.zombie_ai_limit + applied;
            raised = true;
        }
        else if ( !occupied && raised )
        {
            level.zombie_ai_limit = level.zombie_ai_limit - applied;
            raised  = false;
            applied = 0;
        }
    }
}

function deathzone_loop()
{
    level endon( "end_game" );
    level endon( "acc_paradise_end" );

    surge_t   = 0;
    special_t = 0;

    for ( ;; )
    {
        wait 0.5;

        if ( !IS_TRUE( level.acc_paradise_onslaught ) || !any_player_in_paradise() )
        {
            surge_t = 0; special_t = 0;
            continue;
        }

        // x4 REGULAR SURGE - a batch from the paradise risers on a short interval. The raised AI cap is the
        // headroom; spawn_zombie blocks at the cap, so this is a treadmill (refills as you clear), not a runaway.
        surge_t += 0.5;
        if ( surge_t >= getdvarfloat( "acc_paradise_surge_interval", ACC_PARADISE_SURGE_INTERVAL_DEF ) )
        {
            surge_t = 0;
            mult = getdvarint( "acc_paradise_spawn_mult", ACC_PARADISE_SPAWN_MULT_DEF );
            if ( mult < 1 ) mult = 1;
            count = getdvarint( "acc_paradise_surge_count", ACC_PARADISE_SURGE_COUNT_DEF ) * mult;
            level thread surge( count );
        }

        // SHIELD + GLITCH specials on a medium cadence (bounded by a concurrent cap).
        special_t += 0.5;
        if ( special_t >= getdvarfloat( "acc_paradise_special_interval", ACC_PARADISE_SPECIAL_INTERVAL_DEF ) )
        {
            special_t = 0;
            level thread spawn_specials();
        }
    }
}

// Erupt `n` REGULAR zombies from the paradise floor risers. Each is tagged like a trench zombie: ignore_enemy_count
// (off the round books, never gates round end), the below-player_volume emergence fix (so it can MELEE in paradise,
// which sits below every player_volume like the abyss), and the flat low payout. The _acc_zombie_speed paradise
// parity then runs them at L5 trench speed.
function surge( n )
{
    level endon( "end_game" );
    level endon( "acc_paradise_end" );

    if ( !isdefined( level.zombie_spawners ) || level.zombie_spawners.size == 0 ) return;
    risers = acc_bus_trench::get_paradise_risers();
    if ( !isdefined( risers ) || risers.size == 0 ) return;

    for ( i = 0; i < n; i++ )
    {
        spawner = level.zombie_spawners[ acc_utility::acc_rand_int( level.zombie_spawners.size ) ];
        loc     = risers[ acc_utility::acc_rand_int( risers.size ) ];
        z = zombie_utility::spawn_zombie( spawner, undefined, loc );
        if ( isdefined( z ) )
        {
            z.acc_trench_zombie = true;                    // flat low payout (_acc_points::on_zombie_death)
            z.acc_spawn_origin  = loc.origin;
            z thread acc_bus_trench::tag_trench_zombie();  // ignore_enemy_count + paradise emergence fix (melee)
        }
        wait 0.15;   // small stagger so the batch doesn't pop the same frame
    }
}

// A SHIELDED ("Riot") elite + GLITCH Stalker gauntlet per call (mirror of the reactor surge specials). BOTH are
// flagged acc_no_shard_reward so they grant NO Data Shards on kill (a survive-the-threat, not a farm). Bounded by
// acc_paradise_special_max concurrent (engine actor-overflow guard - you SURVIVE these, not necessarily kill them).
function spawn_specials()
{
    level endon( "end_game" );
    level endon( "acc_paradise_end" );

    if ( count_specials() >= getdvarint( "acc_paradise_special_max", ACC_PARADISE_SPECIAL_MAX_DEF ) )
        return;

    rn = ( isdefined( level.round_number ) ? level.round_number : 1 );

    n_shield = getdvarint( "acc_paradise_shielded_per_wave", ACC_PARADISE_SHIELD_PER_WAVE_DEF );
    n_glitch = getdvarint( "acc_paradise_glitch_per_wave", ACC_PARADISE_GLITCH_PER_WAVE_DEF );

    for ( i = 0; i < n_shield; i++ )
    {
        level thread spawn_shielded();
        wait 0.2;
    }
    for ( i = 0; i < n_glitch; i++ )
    {
        // spawn_glitch builds a full Glitch Stalker near a living player and BLINKS to them (its teleport
        // ability brings it into paradise even if it spawns from a topside spawner). Flag it no-shard.
        host = acc_boss_glitch::spawn_glitch( rn );
        if ( isdefined( host ) )
            host.acc_no_shard_reward = true;
        wait 0.2;
    }
}

// Count live Shielded + Glitch specials (the concurrent-cap guard for spawn_specials). Cheap O(n) team scan.
function count_specials()
{
    team = ( isdefined( level.zombie_team ) ? level.zombie_team : "axis" );
    zs = GetAITeamArray( team );
    n = 0;
    for ( i = 0; i < zs.size; i++ )
    {
        z = zs[ i ];
        if ( !isdefined( z ) || !isalive( z ) ) continue;
        if ( IS_TRUE( z.acc_is_glitch_zombie ) || IS_TRUE( z.acc_is_shielded ) )
            n++;
    }
    return n;
}

// Erupt ONE Shielded ("Riot") elite from the paradise risers (mirror of reactor_spawn_shielded). No-shard,
// trench-tagged (ignore_enemy_count + paradise emergence fix so it melees), then promoted (5x HP + front armor +
// shield model). Its 2-shard death reward is suppressed by the no-shard flag (set first).
function spawn_shielded()
{
    level endon( "end_game" );
    level endon( "acc_paradise_end" );

    if ( !isdefined( level.zombie_spawners ) || level.zombie_spawners.size == 0 ) return;

    risers  = acc_bus_trench::get_paradise_risers();
    spawner = level.zombie_spawners[ acc_utility::acc_rand_int( level.zombie_spawners.size ) ];
    loc = undefined;
    if ( isdefined( risers ) && risers.size > 0 )
        loc = risers[ acc_utility::acc_rand_int( risers.size ) ];

    z = ( isdefined( loc ) ? zombie_utility::spawn_zombie( spawner, undefined, loc )
                           : zombie_utility::spawn_zombie( spawner ) );
    if ( !isdefined( z ) ) return;

    n = 0;
    while ( isdefined( z ) && !isdefined( z.zombie_init_done ) && n < 100 )
    {
        util::wait_network_frame();
        n++;
    }
    if ( !isdefined( z ) || !isalive( z ) ) return;

    z.acc_no_shard_reward = true;
    z thread acc_bus_trench::tag_trench_zombie();
    acc_elites::promote_to_shielded( z );
}

// ---------------------------------------------------------------------------
// PHASE 4 bosses: 2 Brutus + 1 Phantom at start, then +1 of each every minute
// ---------------------------------------------------------------------------

// Every acc_paradise_boss_interval (a "minute"), the WHOLE battle escalates IN LOCKSTEP (user 2026-06-26): the
// world-wide horde trench-buff steps up one layer (L2 -> L3 -> L4 -> L5, capped at acc_paradise_buff_max - the
// holistic anti-camp that replaced the old per-zombie 30s-alive ramp; _acc_zombie_speed::paradise_buff_layer just
// READS level.acc_paradise_horde_layer), a UI alert fires ("The horde is getting stronger", or "You will never
// escape!" on the FINAL step to L5), and +1 Brutus + 1 Phantom join (up to the caps). Driving all three off the
// SAME tick is what makes the alert + buff line up with the Brutus spawn. No step / no alert past L5.
function escalation_loop()
{
    level endon( "end_game" );
    level endon( "acc_paradise_end" );

    interval = getdvarfloat( "acc_paradise_boss_interval", ACC_PARADISE_BOSS_INTERVAL_DEF );
    if ( interval < 5 ) interval = 5;

    max_l = getdvarint( "acc_paradise_buff_max", ACC_PARADISE_BUFF_MAX_DEF );

    for ( ;; )
    {
        wait interval;
        if ( !any_player_in_paradise() ) continue;

        // Step the world-wide horde buff one layer (capped) and ANNOUNCE it - synced to this minute's Brutus spawn.
        if ( !isdefined( level.acc_paradise_horde_layer ) )
            level.acc_paradise_horde_layer = getdvarint( "acc_paradise_buff_start", ACC_PARADISE_BUFF_START_DEF );
        if ( level.acc_paradise_horde_layer < max_l )
        {
            level.acc_paradise_horde_layer++;
            if ( level.acc_paradise_horde_layer >= max_l )
                horde_buff_alert( "You will never escape!", "^1" );        // the FINAL buff (-> L5)
            else
                horde_buff_alert( "The horde is getting stronger", "^3" );
            acc_utility::log( "paradise: horde buff -> L" + level.acc_paradise_horde_layer + " (whole horde)" );
        }

        level thread spawn_n_brutus( 1 );
        level thread maybe_spawn_phantom();
    }
}

// Broadcast a one-line buff alert to every player (the file's IPrintLnBold idiom). col = a ^N colour code.
function horde_buff_alert( msg, col )
{
    foreach ( p in GetPlayers() )
        if ( isdefined( p ) && isplayer( p ) ) p IPrintLnBold( col + msg );
}

// Stock powerup_drop() override hook (set on level.custom_zombie_powerup_drop in init). Returns TRUE to SUPPRESS
// the drop - true ONLY during the Paradise battle, so EVERY regular zombie-death power-up (random + score: insta-
// kill, max-ammo, double-points, nuke, ...) is blocked for the 3:45 finale and the rest of the match is stock.
// Reads only level state (no self dependency - powerup_drop invokes it as [[ ]]( drop_point )). user 2026-06-26.
function block_powerup_drop( drop_point )
{
    return IS_TRUE( level.acc_paradise_onslaught );
}

// Spawn `n` Brutus SEQUENTIALLY (the pack uses shared spawn state - maybe_spawn_brutus serializes via
// acc_paradise_brutus_spawning, so calling it back-to-back in one thread spawns them one at a time, never racing).
function spawn_n_brutus( n )
{
    level endon( "end_game" );
    level endon( "acc_paradise_end" );

    for ( i = 0; i < n; i++ )
        maybe_spawn_brutus();
}

// Spawn ONE more Brutus IN PARADISE if under the concurrent cap (user 2026-06-25). A no-shard, no-item THREAT
// (NOT the trench warden's loot pinata - that would flood the player), HP-scaled like the trench warden, and
// tethered to paradise (paradise_warden_think). Serialized via acc_paradise_brutus_spawning (the pack uses a
// shared level.brutus_spawn_points / acc_brutus_spawned notify, so two concurrent spawns would race).
function maybe_spawn_brutus()
{
    level endon( "end_game" );

    if ( getdvarint( "acc_paradise_brutus_on", 1 ) != 1 ) return;
    if ( !any_player_in_paradise() ) return;
    if ( IS_TRUE( level.acc_paradise_brutus_spawning ) ) return;

    if ( !isdefined( level.acc_paradise_brutus_count ) ) level.acc_paradise_brutus_count = 0;
    if ( level.acc_paradise_brutus_count >= getdvarint( "acc_paradise_brutus_max", ACC_PARADISE_BRUTUS_MAX_DEF ) )
        return;

    level.acc_paradise_brutus_spawning = true;
    host = acc_boss_brutus::spawn_one_paradise();
    level.acc_paradise_brutus_spawning = false;

    if ( !isdefined( host ) || !isalive( host ) )
    {
        acc_utility::log( "paradise: Brutus spawn returned none" );
        return;
    }

    level.acc_paradise_brutus_count++;

    // *** Arm the spawn-failsafe immunity AT THE SPAWN FRAME (user 2026-06-26: "Brutus randomly dies in
    //     Paradise if he's alive too long"). *** The stock round_spawn_failsafe (threaded on every zombie at
    //     spawn, nsz_brutus.gsc) DoDamage(health+100)'s an actor that sits below the below_world_check
    //     (z < -1000) or moved <24u in 30s. The Paradise floor is z=-1200 - BELOW the -1000 below-world line -
    //     so EVERY Paradise Brutus reads as "fallen out of the world" and is culled ~30s in. paradise_warden_think
    //     ALSO sets this flag, but only AFTER spawn + its drop-in retry loop (threaded below), so the failsafe's
    //     timer can win the race. Setting it HERE, the same frame as the spawn (no waits), closes the window.
    host.ignore_round_spawn_failsafe = true;

    host.acc_is_mini_boss    = true;   // boss headshot mult in _acc_damage; also makes _acc_zombie_speed skip him
    host.acc_no_shard_reward = true;   // a THREAT, not a farm (no drops)
    host.disableAmmoDrop     = true;
    host DisableAimAssist();

    rn = ( isdefined( level.round_number ) ? level.round_number : 1 );
    host.maxhealth = int( acc_boss::scale_mini_boss_hp( rn ) * acc_coop_scaling::boss_hp_player_mult() );
    host.health    = host.maxhealth;

    host thread acc_boss_brutus::paradise_warden_think();
    host thread brutus_death_watch();

    acc_utility::log( "paradise: Brutus joined the battle (#" + level.acc_paradise_brutus_count + ", " + host.maxhealth + " hp)" );
}

function brutus_death_watch()
{
    self waittill( "death" );
    if ( isdefined( level.acc_paradise_brutus_count ) && level.acc_paradise_brutus_count > 0 )
        level.acc_paradise_brutus_count--;
}

// Spawn ONE more Phantom if under the concurrent cap (user 2026-06-25). acc_boss_phantom::spawn_phantom builds a
// full Phantom (cloak, teleport-harass) near a living player and TELEPORTS to them, so it reaches paradise. The
// boss HUD it emits is suppressed for the whole battle (_acc_health_bars reads level.acc_paradise_onslaught).
function maybe_spawn_phantom()
{
    level endon( "end_game" );

    if ( getdvarint( "acc_paradise_phantom_on", 1 ) != 1 ) return;
    if ( !any_player_in_paradise() ) return;

    if ( !isdefined( level.acc_paradise_phantom_count ) ) level.acc_paradise_phantom_count = 0;
    if ( level.acc_paradise_phantom_count >= getdvarint( "acc_paradise_phantom_max", ACC_PARADISE_PHANTOM_MAX_DEF ) )
        return;

    rn = ( isdefined( level.round_number ) ? level.round_number : 1 );
    host = acc_boss_phantom::spawn_phantom( rn );   // returns the live host (or undefined)
    if ( !isdefined( host ) || !isalive( host ) )
        return;

    level.acc_paradise_phantom_count++;
    host thread phantom_death_watch();

    acc_utility::log( "paradise: Phantom joined the battle (#" + level.acc_paradise_phantom_count + ")" );
}

function phantom_death_watch()
{
    self waittill( "death" );
    if ( isdefined( level.acc_paradise_phantom_count ) && level.acc_paradise_phantom_count > 0 )
        level.acc_paradise_phantom_count--;
}

// ---------------------------------------------------------------------------
// Survival timer (countdown HUD) + the WIN trigger
// ---------------------------------------------------------------------------

function survival_timer_loop()
{
    level endon( "end_game" );        // team wipe -> stock game-over fires this -> the win never triggers (a LOSS)
    level endon( "acc_paradise_end" );

    remaining = getdvarint( "acc_paradise_survive_sec", ACC_PARADISE_SURVIVE_SEC_DEF );
    if ( remaining < 1 ) remaining = 1;

    while ( remaining > 0 )
    {
        update_timer_hud( remaining );
        wait 1;
        remaining--;
    }

    update_timer_hud( 0 );

    // Survived to 0 with the team NOT wiped (a wipe would have endon'd this loop via end_game) -> WIN.
    if ( any_player_alive() )
        level thread win();
}

function update_timer_hud( remaining )
{
    mins   = int( remaining / 60 );
    secs   = remaining % 60;
    secstr = ( secs < 10 ? "0" + secs : "" + secs );
    col    = ( remaining <= 30 ? "^1" : "^3" );   // red in the final 30s
    txt    = col + "SURVIVE  " + mins + ":" + secstr;

    players = GetPlayers();
    for ( i = 0; i < players.size; i++ )
    {
        p = players[ i ];
        if ( !isdefined( p ) || !isplayer( p ) ) continue;
        ensure_timer_hud( p );
        p.acc_paradise_timer SetText( txt );
    }
}

function ensure_timer_hud( p )
{
    if ( isdefined( p.acc_paradise_timer ) ) return;
    p.acc_paradise_timer = p hud::createFontString( "objective", 1.6 );
    p.acc_paradise_timer hud::setPoint( "TOP", "TOP", 0, 24 );
    p.acc_paradise_timer.alignX = "center";
    p.acc_paradise_timer.alignY = "top";
    p.acc_paradise_timer.color  = ( 1, 0.85, 0.2 );
    p.acc_paradise_timer.alpha  = 0.95;
    p.acc_paradise_timer.hidewheninmenu = true;
}

// ---------------------------------------------------------------------------
// WIN: the documented BO3 end-game sequence (docs/22): banner -> freeze -> fade -> purge -> notify("end_game").
// ---------------------------------------------------------------------------

function win()
{
    level endon( "end_game" );

    if ( IS_TRUE( level.acc_paradise_won ) ) return;
    level.acc_paradise_won = true;

    level notify( "acc_paradise_end" );        // stop the surge / boss / timer drivers
    level.acc_paradise_onslaught = false;

    acc_utility::log( "paradise: TEAM SURVIVED THE ONSLAUGHT - WIN" );

    acc_atmosphere::paradise_fog_off();   // LIFT the fog (move it off the map - user 2026-06-25)

    // Victory banner + lock the survivors + the Mario fanfare again (the REAL win this time). There is no
    // separate "victory" screen in zombies, so the banner + fanfare are what tell the team they WON vs died.
    foreach ( p in GetPlayers() )
    {
        if ( !isdefined( p ) || !isplayer( p ) ) continue;
        if ( isdefined( p.acc_paradise_timer ) ) { p.acc_paradise_timer hud::destroyElem(); p.acc_paradise_timer = undefined; }
        p FreezeControls( true );
        p show_win_banner();
        p PlayLocalSound( "acc_paradise_calm" );   // the victory fanfare again
        p IPrintLnBold( "^2YOU SURVIVED PARADISE^7 - victory!" );
    }

    wait 5;   // let the fanfare play + the win land

    fade_all_to_black( 2.0 );
    wait 2.4;

    purge_zombies();   // documented end-game step: nothing mid-attack at the cut
    wait 1.5;

    // The single stock-recognized signal that ends the BO3 zombies match (-> post-game scoreboard).
    level notify( "end_game" );
}

function show_win_banner()   // self = player
{
    self.acc_paradise_win_txt = self hud::createFontString( "objective", 2.2 );
    self.acc_paradise_win_txt hud::setPoint( "CENTER", "CENTER", 0, -16 );
    self.acc_paradise_win_txt.alignX = "center";
    self.acc_paradise_win_txt.alignY = "middle";
    self.acc_paradise_win_txt.color  = ( 0.3, 1.0, 0.45 );
    self.acc_paradise_win_txt.alpha  = 1;
    self.acc_paradise_win_txt.hidewheninmenu = true;
    self.acc_paradise_win_txt SetText( "^2YOU SURVIVED  -  PARADISE CONQUERED" );
}

// Per-player fullscreen black overlay fading in (the proven fullscreen-icon recipe from _acc_bus_trench's
// danger tint - avoids any LUI screen-fade API risk). Lands fully black for the match-end cut.
function fade_all_to_black( dur )
{
    foreach ( p in GetPlayers() )
    {
        if ( !isdefined( p ) || !isplayer( p ) ) continue;
        bg = p hud::createIcon( "white", 640, 480 );
        bg.horzAlign = "fullscreen";
        bg.vertAlign = "fullscreen";
        bg.alignX = "left";
        bg.alignY = "top";
        bg.x = 0;
        bg.y = 0;
        bg.color = ( 0, 0, 0 );
        bg.alpha = 0;
        bg.sort  = 50;   // above the rest of the HUD
        bg.hidewheninmenu = false;
        bg fadeovertime( dur );
        bg.alpha = 1;
    }
}

// Purge the whole horde (the documented end-game step, docs/22): DoDamage health+666 on every live AI so nothing
// is mid-swing when the match ends.
function purge_zombies()
{
    team = ( isdefined( level.zombie_team ) ? level.zombie_team : "axis" );
    zs = GetAITeamArray( team );
    for ( i = 0; i < zs.size; i++ )
    {
        z = zs[ i ];
        if ( !isdefined( z ) || !isalive( z ) ) continue;
        // SKIP bosses/mini-bosses (user 2026-06-26): the clean-slate purge is for the trash horde - NOT the
        // Brutus / Phantom / Subroutine Core. health+666 would instant-kill a live boss too (same skip
        // _acc_corpse_cleanup uses). Without this, a Brutus alive when the battle starts is purged.
        if ( IS_TRUE( z.acc_is_boss ) || IS_TRUE( z.acc_is_mini_boss ) ) continue;
        z DoDamage( z.health + 666, z.origin );
    }
}
