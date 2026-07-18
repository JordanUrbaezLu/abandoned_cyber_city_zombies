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
//             (acc_paradise_music) drops, and the bosses storm in ALONGSIDE the horde (x4 spawn rate +
//             shield/glitch gauntlet) on a STAGED ROSTER (user 2026-07-12 nerf - was 1 of each all at once):
//             3:45 Trench Warden (Brutus) + Phantom -> 2:45 +Rogue Protector -> 1:45 +Panzer ->
//             0:45 +Avogadro (cap 1 of each; the Apothicon Fury is DROPPED from the wave - not in the
//             user's schedule). EVERY MINUTE the whole battle escalates IN LOCKSTEP: the boss wave tops
//             the UNLOCKED roster back up to 1 of each (a killed boss is replaced next minute), the wave-baseline horde trench-buff steps
//             up a layer (L2 minute 0-1 -> L3 -> L4 -> L5 final wave), and a UI alert fires ("The horde is getting
//             stronger", or "You will never escape!" on the final L5 step). Four waves: L2/L3/L4 are
//             60s each, the FINAL L5 wave is 45s (3:00 -> 3:45). ON TOP of the wave, EVERY ZOMBIE individually
//             jumps +1 tier for each 30s it stays ALIVE (acc_paradise_age_step_sec, capped L5 - the anti-kite
//             ramp restored 2026-07-09): kill the wave or the ones chasing you outscale the wave clock 2:1. NO power-up drops the whole
//             battle (no insta-kill / max-ammo / double-points - block_powerup_drop). A countdown TIMER HUD shows
//             the time left; the BOSS HUD + boss music are SUPPRESSED for the whole battle (level.acc_paradise_
//             onslaught - read by _acc_health_bars and _acc_boss::boss_music).
//
// WIN: survive the 3:45 battle (team not wiped) -> the documented BO3 end-game sequence (docs/16): victory
// banner -> freeze controls -> fade to black -> purge the horde (DoDamage health+666) -> level notify("end_game")
// (the single stock signal that ends the zombies match to the post-game scoreboard; there is no separate
// "victory" screen, so the banner is what tells the player they WON vs died).
// LOSE: if the team is wiped at any point, stock fires game-over normally (our endon kills the loops).
//
// AUDIO: three wavs at sound_assets/acc/ (48k/16-bit) + a GAME-CLOSED sound build (the .sabs bank is file-locked
// while BO3 runs - memory custom-sound-48k-and-game-lock): music/115.wav (battle), music/paradise_calm.wav
// (victory fanfare), fx/paradise_omen.wav (the omen cue). *** REAL 115 + Mario wavs landed 2026-07-09: both are
// GITIGNORED (licensing) so they never migrated from the old box - this machine had silent PLACEHOLDER copies
// (115 = a byte-copy of brutus_music, calm = a copy of the nuke SFX). Restore from a download via
// tools/resample48k.js (44.1k -> 48k) if ever lost again. *** LICENSING: 115 / Mario fanfare are not CC0 -
// test-only, NOT for the public Workshop (CREDITS.md IP review).
//
// GSC-ONLY + LED-SAFE: pure script (risers are computed structs, the HUD is server hudelems, the fog is a script
// SetVolFog) - builds with `-GscOnly`, no .map / material / sky change, no LED bake.
// =============================================================================

#using scripts\shared\flag_shared;
#using scripts\shared\util_shared;
#using scripts\shared\hud_util_shared;
#using scripts\shared\ai\zombie_utility;

#using scripts\zm\_zm_utility;   // play_sound_2D() - the proven "music for the whole lobby" path (same as the EE song)
#using scripts\zm\_zm_perks;     // give_perk + perk_set_max_health_if_jugg (Paradise-win reward: all perks + 350 HP Jug)
#using scripts\zm\_zm_weapons;   // weapon_give (Paradise-win reward: wonder-weapon ground pickups)
#using scripts\zm\_zm_powerups;  // specific_powerup_drop (the scripted 1:45 max-ammo, user 2026-07-13)

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
#using scripts\zm\zm_abandoned_cyber_city\_acc_coop_scaling;  // boss_hp_player_mult (coop boss-HP table)
#using scripts\zm\zm_abandoned_cyber_city\_acc_civil_protector; // spawn_boss (Rogue Protector - lands in front of a living player, reaches the arena)
#using scripts\zm\zm_abandoned_cyber_city\_acc_boss_avogadro;   // spawn_boss (Avogadro - has a paradise branch that spawns him in the arena)
#using scripts\zm\zm_abandoned_cyber_city\_acc_fury;            // spawn_paradise_fury (Apothicon Fury - meteor-drops onto a player in the arena, user 2026-07-09)
#using scripts\zm\zm_abandoned_cyber_city\_acc_boss_panzer;     // spawn_boss (Panzer - has a paradise branch that spawns him on a player in the arena, user 2026-07-09)

// --- Tunable defaults. Every one a live acc_paradise_* dvar (mirror docs/22). ---
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
#define ACC_PARADISE_BRUTUS_MAX_DEF       1     // concurrent paradise Trench Warden (Brutus) cap (user 2026-07-05: 1 of each boss)
#define ACC_PARADISE_PHANTOM_MAX_DEF      1     // concurrent paradise Phantom cap
#define ACC_PARADISE_RP_MAX_DEF           1     // concurrent paradise Rogue Protector cap
#define ACC_PARADISE_AVO_MAX_DEF          1     // concurrent paradise Avogadro cap
#define ACC_PARADISE_FURY_MAX_DEF         1     // concurrent paradise Apothicon Fury cap (DROPPED from the wave 2026-07-12 - kept for a re-add)
#define ACC_PARADISE_PANZER_MAX_DEF       1     // concurrent paradise Panzer cap (user 2026-07-09: joins the wave)
// STAGED BOSS INTRO (user 2026-07-12, "Paradise needs to be nerfed"): each boss UNLOCKS at a battle
// minute (escalation tick). Minute 0 = battle start (3:45 on the countdown): Brutus + Phantom only;
// minute 1 (2:45) +Rogue Protector; minute 2 (1:45) +Panzer; minute 3 (0:45) +Avogadro. Live dvars
// acc_paradise_{rp,panzer,avo}_unlock_min.
#define ACC_PARADISE_RP_UNLOCK_MIN        1     // Rogue Protector joins at the 2:45 escalation tick
#define ACC_PARADISE_PANZER_UNLOCK_MIN    2     // Panzer joins at 1:45
#define ACC_PARADISE_AVO_UNLOCK_MIN       3     // Avogadro joins at 0:45 (the final wave)
#define ACC_PARADISE_BOSS_INTERVAL_DEF    60.0  // seconds between escalation ticks (+1 Brutus +1 Phantom + buff step + alert each "minute")
#define ACC_PARADISE_BUFF_START_DEF       2     // world-wide horde trench-buff layer for the FIRST battle minute (0-1 min)
#define ACC_PARADISE_BUFF_MAX_DEF         5     // deepest horde layer (reached at the 3:00 step, held for the final 45s wave)
// WIN REWARD (user 2026-07-12: Paradise no longer ENDS the run - beating it rewards + continues).
#define ACC_PARADISE_REWARD_SEC_DEF       60    // the plaza reward window: wonder-weapon loot lifetime + time before the auto-return to the surface
#define ACC_PARADISE_HP_BOOST_DEF         50   // PERMANENT +50 HP boost on Paradise win (user 2026-07-13, was 100): base 100 -> 150, so a Jug'd survivor = 100 + 150 Jug + 50 = 300 (n_player_health_boost, survives downs)
// (The Paradise HORDE BUFF anti-camp/anti-kite - TWO escalation vectors (user 2026-07-09 restored the second):
//  (1) the WAVE clock: one trench-equivalent layer that steps L2 -> L3 -> L4 -> L5 on the BATTLE CLOCK, +1 each
//      minute, in lockstep with the boss escalation + the UI alert below - fresh spawns open at the current wave;
//  (2) the PER-ZOMBIE 30s-ALIVE ramp: a zombie left alive jumps +1 tier above its wave-of-birth every
//      acc_paradise_age_step_sec (30) - so kiting instead of killing outscales the wave clock 2:1.
// The per-layer SPEED + HEALTH treatment + the age stamp live in _acc_zombie_speed.gsc::paradise_buff_layer (it
// READS our level.acc_paradise_horde_layer as the wave baseline); WE own + step that var here in escalation_loop.)

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
    level.acc_paradise_rp_count      = 0;    // live paradise Rogue Protector count (cap 1)
    level.acc_paradise_avo_count     = 0;    // live paradise Avogadro count (cap 1; separate from the module's acc_avo_alive, which may include a stranded Lab test-spawn)
    level.acc_paradise_fury_count    = 0;    // live paradise Apothicon Fury count (cap 1; user 2026-07-09)
    level.acc_paradise_panzer_count  = 0;    // live paradise Panzer count (cap 1; user 2026-07-09; separate from the module's acc_panzer_alive)
    level.acc_paradise_battle_minute = 0;    // escalation minutes elapsed since battle start - gates the staged boss roster (user 2026-07-12)
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

    // Opening bosses (STAGED roster, user 2026-07-12): only Trench Warden (Brutus) + Phantom at 3:45.
    // Each escalation minute unlocks the next boss (RP -> Panzer -> Avogadro) and tops the unlocked
    // roster back up to 1 of each (spawn_paradise_boss_wave reads level.acc_paradise_battle_minute).
    level.acc_paradise_battle_minute = 0;
    spawn_paradise_boss_wave();

    level thread ai_pressure();         // raise the AI cap for the x4 horde
    level thread deathzone_loop();      // the x4 regular surge + shield/glitch specials
    level thread escalation_loop();     // every minute: top the boss wave back to 1 of each, step the horde buff L2->L5, fire the UI alert (all in lockstep)
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

// UNWIND TRAP (review 2026-07-15) - this loop deliberately does NOT endon "acc_paradise_end", unlike every
// other driver in this module. It OWNS mutable LEVEL state (the +12 on zombie_ai_limit) and the endon would
// kill the thread mid-raise, before the "!occupied && raised" branch below could give the 12 back: win()
// fires that very notify (:1015) while the battle is still occupied, so the subtract would never run. Since
// win() no longer end_game's (the run CONTINUES, user 2026-07-12), the leak is PERMANENT - the surface horde
// cap would sit at ACC_AI_LIMIT 50 + a stranded 12 = 62 for the rest of the run, pushing at the 64 engine
// ceiling. win() clears level.acc_paradise_onslaught one line AFTER the notify (:1016), so occupied goes
// false on the next 0.5s tick and the subtract below IS the cleanup. Same proven shape as
// _acc_bus_trench::trench_ai_pressure, whose only endon is end_game for exactly this reason. Keeping the
// end_game endon is safe: the run is over, so the level state is discarded with it.
function ai_pressure()
{
    level endon( "end_game" );

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
// PHASE 4 bosses: STAGED roster - Brutus+Phantom at 3:45, +RP 2:45, +Panzer 1:45, +Avogadro 0:45
// ---------------------------------------------------------------------------

// Every acc_paradise_boss_interval (a "minute"), the WHOLE battle escalates IN LOCKSTEP (user 2026-06-26): the
// wave-baseline horde trench-buff steps up one layer (L2 -> L3 -> L4 -> L5, capped at acc_paradise_buff_max;
// _acc_zombie_speed::paradise_buff_layer reads level.acc_paradise_horde_layer as the FLOOR - each zombie also
// ages +1 tier per 30s it stays alive, the per-zombie ramp restored 2026-07-09), a UI alert fires ("The horde is
// getting stronger", or "You will never escape!" on the FINAL step to L5), and +1 Brutus + 1 Phantom join (up to
// the caps). Driving all three off the SAME tick is what makes the alert + buff line up with the Brutus spawn.
// No step / no alert past L5.
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

        // Advance the battle minute - unlocks the next staged boss (user 2026-07-12: RP at min 1,
        // Panzer at min 2, Avogadro at min 3; spawn_paradise_boss_wave reads it).
        if ( !isdefined( level.acc_paradise_battle_minute ) ) level.acc_paradise_battle_minute = 0;
        level.acc_paradise_battle_minute++;

        // Step the world-wide horde buff one layer (capped) and ANNOUNCE it - synced to this minute's boss wave.
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

        spawn_paradise_boss_wave();     // top back up to 1 of each: Trench Warden + Phantom + Rogue Protector + Avogadro + Fury + Panzer
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
    // The scripted 1:45 MAX AMMO (user 2026-07-13) sets acc_paradise_force_drop for its one call so it
    // passes even though the battle otherwise blocks all drops. Belt-and-suspenders: specific_powerup_drop
    // may bypass this hook anyway (it is a direct named-spawn, not the on-kill random path), but the flag
    // guarantees the drop lands.
    if ( IS_TRUE( level.acc_paradise_force_drop ) ) return false;
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

// The Paradise boss wave - STAGED roster (user 2026-07-12 nerf; was 1-of-each from the opening bell):
// each boss joins the wave only once the battle reaches its unlock minute, then the wave keeps topping
// the UNLOCKED set back up to 1 of each (each spawn self-gated by its cap-1). Threaded so the spawns
// (some carry a ground-tell wait) run concurrently, not serially. Called at battle start (minute 0:
// Brutus + Phantom only) and every escalation minute; a boss still alive simply skips (cap 1) until it
// is killed, then the next minute replaces it - a rolling "one of each unlocked" pressure.
// The Apothicon Fury is DROPPED from the wave (not in the user's 2026-07-12 schedule);
// maybe_spawn_fury stays below for a future re-add.
function spawn_paradise_boss_wave()
{
    minute = ( isdefined( level.acc_paradise_battle_minute ) ? level.acc_paradise_battle_minute : 0 );

    level thread maybe_spawn_brutus();            // Trench Warden - from the opening bell (3:45)
    level thread maybe_spawn_phantom();           // Phantom - from the opening bell (3:45)
    if ( minute >= getdvarint( "acc_paradise_rp_unlock_min", ACC_PARADISE_RP_UNLOCK_MIN ) )
        level thread maybe_spawn_rogue_protector();   // 2:45
    if ( minute >= getdvarint( "acc_paradise_panzer_unlock_min", ACC_PARADISE_PANZER_UNLOCK_MIN ) )
        level thread maybe_spawn_panzer();            // 1:45
    if ( minute >= getdvarint( "acc_paradise_avo_unlock_min", ACC_PARADISE_AVO_UNLOCK_MIN ) )
        level thread maybe_spawn_avogadro();          // 0:45 (the final wave)
}

// Spawn ONE Panzer IN PARADISE if under the cap (user 2026-07-09). acc_boss_panzer::spawn_boss already
// carries a paradise branch (spawns ON a living player - the every-boss rule; its Plaza anchor z=0 is
// unreachable from the z=-1200 arena) and its grant_drops self-suppresses during the onslaught like the
// other wave bosses. Same rewards/behavior as a normal-round Panzer otherwise (claw + electroball zap).
function maybe_spawn_panzer()
{
    level endon( "end_game" );
    level endon( "acc_paradise_end" );

    if ( getdvarint( "acc_paradise_panzer_on", 1 ) != 1 ) return;
    if ( !any_player_in_paradise() ) return;

    if ( !isdefined( level.acc_paradise_panzer_count ) ) level.acc_paradise_panzer_count = 0;
    if ( level.acc_paradise_panzer_count >= getdvarint( "acc_paradise_panzer_max", ACC_PARADISE_PANZER_MAX_DEF ) )
        return;

    host = acc_boss_panzer::spawn_boss();
    if ( !isdefined( host ) || !isalive( host ) )
    {
        acc_utility::log( "paradise: Panzer spawn returned none" );
        return;
    }

    level.acc_paradise_panzer_count++;
    host.ignore_round_spawn_failsafe = true;   // arena z=-1200 sits below the -1000 below-world cull (every-boss rule)
    level thread paradise_boss_count_watch( host, "panzer" );
    acc_utility::log( "paradise: Panzer joined the battle (#" + level.acc_paradise_panzer_count + ")" );
}

// Spawn ONE Rogue Protector IN PARADISE if under the cap (user 2026-07-05). acc_civil_protector::spawn_boss
// normally uses its fixed Plaza anchor, but has a paradise branch (review fix 2026-07-08) that spawns him ON a
// living player in the arena (the Plaza z=14 is unreachable from the z=-1200 arena - same reason the Avogadro
// spawns on a player here). Its own death_watch fires its rewards; this only tracks the cap-1 count.
function maybe_spawn_rogue_protector()
{
    level endon( "end_game" );
    level endon( "acc_paradise_end" );

    if ( getdvarint( "acc_paradise_rp_on", 1 ) != 1 ) return;
    if ( !any_player_in_paradise() ) return;

    if ( !isdefined( level.acc_paradise_rp_count ) ) level.acc_paradise_rp_count = 0;
    if ( level.acc_paradise_rp_count >= getdvarint( "acc_paradise_rp_max", ACC_PARADISE_RP_MAX_DEF ) )
        return;

    host = acc_civil_protector::spawn_boss();
    if ( !isdefined( host ) || !isalive( host ) )
    {
        acc_utility::log( "paradise: Rogue Protector spawn returned none" );
        return;
    }

    level.acc_paradise_rp_count++;
    host.ignore_round_spawn_failsafe = true;   // same below-world cull immunity the paradise Brutus needs (arena z=-1200)
    level thread paradise_boss_count_watch( host, "rp" );
    acc_utility::log( "paradise: Rogue Protector joined the battle (#" + level.acc_paradise_rp_count + ")" );
}

// Spawn ONE Avogadro IN PARADISE if under the cap (user 2026-07-05). acc_boss_avogadro::spawn_boss has a paradise
// branch that spawns him ON a living player in the arena (his Lab spawn is z=0, unreachable from z=-1200). His
// hack_director keeps working down here (user 2026-07-09 parity pass: it seeks the arena's own duplicate perk
// row / PaP via the paradise target cache - he used to pause and degrade to a pure chase+zap threat). The
// module's Lab test-respawn loop is paused during paradise, so this wave is the sole Avogadro source.
function maybe_spawn_avogadro()
{
    level endon( "end_game" );
    level endon( "acc_paradise_end" );

    if ( getdvarint( "acc_paradise_avo_on", 1 ) != 1 ) return;
    if ( !any_player_in_paradise() ) return;

    if ( !isdefined( level.acc_paradise_avo_count ) ) level.acc_paradise_avo_count = 0;
    if ( level.acc_paradise_avo_count >= getdvarint( "acc_paradise_avo_max", ACC_PARADISE_AVO_MAX_DEF ) )
        return;

    host = acc_boss_avogadro::spawn_boss();
    if ( !isdefined( host ) || !isalive( host ) )
    {
        acc_utility::log( "paradise: Avogadro spawn returned none" );
        return;
    }

    level.acc_paradise_avo_count++;
    host.ignore_round_spawn_failsafe = true;
    level thread paradise_boss_count_watch( host, "avo" );
    acc_utility::log( "paradise: Avogadro joined the battle (#" + level.acc_paradise_avo_count + ")" );
}

// Spawn ONE Apothicon Fury IN PARADISE if under the cap (user 2026-07-09). acc_fury::spawn_paradise_fury
// meteor-drops it onto a living player in the arena via the trench below-zone spawn path (zone check skipped,
// forced emergence) and boss-flags it (acc_is_mini_boss -> excluded from the battle purge, the Rogue Protector
// landing splash, and octobomb targeting; ignore_round_spawn_failsafe is set by the fury spawner itself - the
// arena z=-1200 sits below the -1000 below-world cull, same as every other paradise boss). The trench cadence
// never fires down here (underground_layer excludes the second part), so this wave is the sole arena source.
function maybe_spawn_fury()
{
    level endon( "end_game" );
    level endon( "acc_paradise_end" );

    if ( getdvarint( "acc_paradise_fury_on", 1 ) != 1 ) return;
    if ( !any_player_in_paradise() ) return;

    if ( !isdefined( level.acc_paradise_fury_count ) ) level.acc_paradise_fury_count = 0;
    if ( level.acc_paradise_fury_count >= getdvarint( "acc_paradise_fury_max", ACC_PARADISE_FURY_MAX_DEF ) )
        return;

    host = acc_fury::spawn_paradise_fury();
    if ( !isdefined( host ) || !isalive( host ) )
    {
        acc_utility::log( "paradise: Apothicon Fury spawn returned none" );
        return;
    }

    level.acc_paradise_fury_count++;
    level thread paradise_boss_count_watch( host, "fury" );
    acc_utility::log( "paradise: Apothicon Fury joined the battle (#" + level.acc_paradise_fury_count + ")" );
}

// Poll-based death watch for the paradise-only boss counts (RP / Avogadro / Fury). Level-threaded with the host
// passed in so it still decrements if the actor is Delete()d without a "death" notify (the pack death path).
// endon paradise end so a leftover watcher never outlives the finale.
function paradise_boss_count_watch( host, kind )
{
    level endon( "end_game" );
    level endon( "acc_paradise_end" );

    while ( isdefined( host ) && isalive( host ) )
        wait 0.5;

    if ( kind == "rp" )
    {
        if ( isdefined( level.acc_paradise_rp_count ) && level.acc_paradise_rp_count > 0 )
            level.acc_paradise_rp_count--;
    }
    else if ( kind == "avo" )
    {
        if ( isdefined( level.acc_paradise_avo_count ) && level.acc_paradise_avo_count > 0 )
            level.acc_paradise_avo_count--;
    }
    else if ( kind == "panzer" )
    {
        if ( isdefined( level.acc_paradise_panzer_count ) && level.acc_paradise_panzer_count > 0 )
            level.acc_paradise_panzer_count--;
    }
    else   // "fury"
    {
        if ( isdefined( level.acc_paradise_fury_count ) && level.acc_paradise_fury_count > 0 )
            level.acc_paradise_fury_count--;
    }
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
        // Scripted MAX AMMO at 1:45 on the countdown (user 2026-07-13): one guaranteed full_ammo
        // mid-battle (regular drops are blocked the whole finale). Default 105s = 1:45 remaining.
        if ( remaining == getdvarint( "acc_paradise_maxammo_at_sec", 105 ) )
            level thread paradise_drop_max_ammo();
        wait 1;
        remaining--;
    }

    update_timer_hud( 0 );

    // Survived to 0 with the team NOT wiped (a wipe would have endon'd this loop via end_game) -> WIN.
    if ( any_player_alive() )
        level thread win();
}

// One scripted MAX AMMO at the 1:45 mark (user 2026-07-13). Drops at the gather point (plaza centre);
// acc_paradise_force_drop lets it through block_powerup_drop. specific_powerup_drop MUST be level thread
// (memory stock-override-zm-patch-dedupe: eMoX's delayed-drop makes the call block ~1.6s).
function paradise_drop_max_ammo()
{
    level endon( "end_game" );
    level endon( "acc_paradise_end" );

    spot = paradise_gather_point();
    if ( !isdefined( spot ) ) spot = ( 0, -1300, -1200 );

    level.acc_paradise_force_drop = true;
    level thread zm_powerups::specific_powerup_drop( "full_ammo", spot );
    wait 0.5;
    level.acc_paradise_force_drop = false;

    foreach ( p in GetPlayers() )
        if ( isdefined( p ) && isplayer( p ) ) p IPrintLnBold( "^3MAX AMMO^7 dropped - grab it!" );
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
        if ( isdefined( p.acc_paradise_timer ) ) p.acc_paradise_timer SetText( txt );
    }
}

function ensure_timer_hud( p )
{
    if ( isdefined( p.acc_paradise_timer ) ) return;
    p.acc_paradise_timer = acc_utility::he_check( p hud::createFontString( "objective", 1.9 ), "paradise.timer" );
    if ( !isdefined( p.acc_paradise_timer ) ) return;   // pool full (he_check logged it) - degrade, don't touch undefined
    // y 24 -> 150 + scale 1.6 -> 1.9 (user 2026-07-06: "timer too high, none of the players noticed").
    // 150 sits clearly below the trench DANGER banner band (y 110) so the two never stack.
    p.acc_paradise_timer hud::setPoint( "TOP", "TOP", 0, 150 );
    p.acc_paradise_timer.alignX = "center";
    p.acc_paradise_timer.alignY = "top";
    p.acc_paradise_timer.color  = ( 1, 0.85, 0.2 );
    p.acc_paradise_timer.alpha  = 0.95;
    p.acc_paradise_timer.hidewheninmenu = true;
}

// ---------------------------------------------------------------------------
// WIN (user 2026-07-12: Paradise no longer ENDS the run - it REWARDS and CONTINUES).
// Sequence: latch the win flag (-> leaderboard "(Paradise Winner)" tag + gold health bar)
// -> celebrate (banner + fanfare) -> grant every survivor ALL perks + enhanced Jug (350 HP)
// -> drop the 5 wonder weapons on the plaza floor for a 60s reward window -> teleport the
// survivors back to the surface (carefully, no down) -> restore normal round spawning ->
// RETURN (no end_game). The run ends later on death/quit; the recorder reads the latched
// level.acc_paradise_won at THAT end. A team WIPE still ends via stock game-over (a loss).
// ---------------------------------------------------------------------------

function win()
{
    level endon( "end_game" );

    if ( IS_TRUE( level.acc_paradise_won ) ) return;
    level.acc_paradise_won = true;              // latched: read by the leaderboard recorder + the gold-bar hook

    level notify( "acc_paradise_end" );         // stop the surge / boss / timer / escalation drivers
    // KEEP THIS CLEAR: it is not only cosmetic state - it is the ONLY thing that unwinds ai_pressure's
    // +12 on level.zombie_ai_limit (that loop is notify-immune BY DESIGN; see the comment on it).
    level.acc_paradise_onslaught = false;       // -> restores powerup drops (block_powerup_drop), boss HUD/music

    acc_utility::log( "paradise: TEAM SURVIVED THE ONSLAUGHT - WIN (run CONTINUES + reward, user 2026-07-12)" );

    acc_atmosphere::paradise_fog_off();         // LIFT the fog (move it off the map)

    // CLEAN SLATE: purge the finale horde AND remove the finale bosses so the reward window /
    // continued run is a calm plaza. purge_zombies() SKIPS bosses BY DESIGN (its other caller,
    // start_battle, must not cull a pre-existing boss), so it can't do this itself. win() no
    // longer end_game's (user 2026-07-12: the run continues), so a boss still alive at 0:00 would
    // otherwise survive purge_zombies, keep attacking the unfrozen looters through the reward
    // window, and - once unseal_arena reconnects the navmesh + players teleport up - roam the whole
    // map for the rest of the run. Remove them here in the same clean-slate frame (review 2026-07-15).
    purge_zombies();
    remove_paradise_bosses();

    // ---- CELEBRATE: banner + fanfare, NO control freeze (user 2026-07-13: "your character freezes
    // when you win and that can cause you to die if there is a zombie alive - remove the freeze").
    // purge_zombies() above already clears the horde, but a straggler mid-spawn could survive a frame;
    // leaving the player IN CONTROL means they can fight/run instead of dying frozen. ----
    foreach ( p in GetPlayers() )
    {
        if ( !isdefined( p ) || !isplayer( p ) ) continue;
        if ( isdefined( p.acc_paradise_timer ) ) { p.acc_paradise_timer hud::destroyElem(); acc_utility::he_free( 1 ); p.acc_paradise_timer = undefined; }
        p show_win_banner();
        p PlayLocalSound( "acc_paradise_calm" );   // the victory fanfare
        p IPrintLnBold( "^2YOU SURVIVED PARADISE^7 - victory!" );
    }

    wait 5;   // let the banner + fanfare land (players stay in control)

    // ---- REWARD: every SURVIVOR gets all perks + enhanced Jug (350 HP / gold bar), then can roam ----
    foreach ( p in GetPlayers() )
    {
        if ( !isdefined( p ) || !isplayer( p ) || !isalive( p ) ) continue;
        grant_paradise_reward( p );
    }

    // ---- LOOT: the 5 wonder weapons on the plaza floor for the reward window ----
    level thread spawn_paradise_wonder_loot();
    level thread clear_win_banners();   // the banner fades a few seconds into the reward window (user 2026-07-12: it never disappeared)

    reward_sec = getdvarint( "acc_paradise_reward_sec", ACC_PARADISE_REWARD_SEC_DEF );
    foreach ( p in GetPlayers() )
        if ( isdefined( p ) && isplayer( p ) )
            p IPrintLnBold( "^3GRAB THE WONDER WEAPONS^7 - returning to the surface in " + reward_sec + "s..." );

    wait reward_sec;

    // ---- RETURN: clear un-grabbed loot, reopen the gate, teleport up, resume rounds ----
    level notify( "acc_paradise_reward_end" );   // tears down any un-grabbed wonder pickups
    unseal_arena();                              // reopen the abyss gate + reconnect its navmesh
    return_players_to_surface();                 // fan-out ring teleport up (OOB grace covers it; no down)
    if ( getdvarint( "acc_paradise_spawn_lockdown", 1 ) == 1 )
        level flag::set( "spawn_zombies" );      // RESUME stock round spawning (start_battle cleared it)

    acc_utility::log( "paradise: reward window over - survivors returned to the surface, rounds resume (run continues)" );
    // NO notify("end_game"): the run continues.
}

// ---------------------------------------------------------------------------
// WIN REWARD helpers (user 2026-07-12)
// ---------------------------------------------------------------------------

// self-less: grant one survivor the full Paradise reward - ALL perks + a permanent enhanced Jug (350 HP).
function grant_paradise_reward( p )
{
    p.acc_paradise_reward = true;   // gates the GOLD health bar at full HP (_acc_health_bars::hp_bar_color)

    // ALL perks: the map's 10-perk registry (level.acc_perk_door_specs, set by acc_perk_doors::init).
    // give_perk is the stock grant (real perk + HP + machine thread) - the same call dev mode uses; it
    // drives the custom PhD/Electric-Cherry give-threads too. Read the level var (no _acc_perk_doors #using
    // needed -> no cross-module cycle risk). give_perk(spec, false): false = not a bottle/vending give.
    specs = level.acc_perk_door_specs;
    if ( isdefined( specs ) )
        for ( i = 0; i < specs.size; i++ )
            if ( isdefined( specs[ i ] ) && !( p HasPerk( specs[ i ] ) ) )
                p zm_perks::give_perk( specs[ i ], false );

    // ENHANCED JUG -> 350 HP. n_player_health_boost is the ONLY field the stock health_reboot recompute
    // adds, and that recompute re-runs on every revive, so the bonus SURVIVES DOWNS (same proven mechanism
    // as Mega Jug's Ultimate Tank, _acc_mega_bottles.gsc:710). perk_set_max_health_if_jugg needs Jug present
    // - the give_perk loop above guarantees specialty_armorvest, so it always takes. USER 2026-07-13:
    //   the Paradise HP reward is a PERMANENT +50 (base 100 -> 150), so a Jug'd survivor = 100 + 150 Jug
    //   + 50 = 300 (was +100/350). "for the rest of the game" = n_player_health_boost survives downs.
    p.n_player_health_boost = getdvarint( "acc_paradise_hp_boost", ACC_PARADISE_HP_BOOST_DEF );
    p zm_perks::perk_set_max_health_if_jugg( "health_reboot", true, false );
    p.health = p.maxhealth;   // top off to the new cap

    p IPrintLnBold( "^2PARADISE'S BLESSING^7 - all perks + " + p.maxhealth + " HP" );
}

// Reverse of seal_arena(): reopen the abyss gate + reconnect its navmesh so the survivors aren't trapped and
// the surface is reachable again. ConnectPaths PAIRS the seal's DisconnectPaths (memory
// navmesh-excludes-entities-disconnectpaths).
function unseal_arena()
{
    door = GetEnt( "acc_abyss_hub_door", "targetname" );
    if ( !isdefined( door ) ) return;
    door connectpaths();
    door notsolid();
    door hide();
    acc_utility::log( "paradise: arena UNsealed (gate reopened, navmesh reconnected)" );
}

// Teleport every live survivor (incl. downed - so nobody is left below the map) up to the surface start area,
// fanned onto a deterministic ring so they never stack (memory coop-teleport-fan-out-not-one-point). The OOB
// monitor's 12s continuous-OOB grace (acc_trench_oob_allow) means a single warp CANNOT down them.
function return_players_to_surface()
{
    dest = ( -291, -316, 32 );   // surface start/spawn area (the dev "spawn" warp target, _acc_dev.gsc)

    survivors = [];
    foreach ( p in GetPlayers() )
        if ( isdefined( p ) && isplayer( p ) && isalive( p ) )
            survivors[ survivors.size ] = p;

    for ( i = 0; i < survivors.size; i++ )
    {
        ang = i * 360 / survivors.size;
        off = ( cos( ang ) * 48, sin( ang ) * 48, 0 );   // 48u ring (no capsule-stack eject)
        survivors[ i ] FreezeControls( false );          // belt-and-braces: never leave anyone frozen up top
        survivors[ i ] SetOrigin( dest + off );
        survivors[ i ] IPrintLnBold( "^2Returned to the surface^7 - the run continues!" );
    }
}

// ---------------------------------------------------------------------------
// WONDER-WEAPON LOOT (the plaza reward pickups)
// ---------------------------------------------------------------------------

// Drop all 5 wonder weapons as hold-USE ground pickups fanned around the plaza centre. They live for the reward
// window (torn down on "acc_paradise_reward_end") so the team can grab whichever they want before the return.
function spawn_paradise_wonder_loot()
{
    level endon( "end_game" );
    if ( getdvarint( "acc_paradise_wonder_loot", 1 ) != 1 ) return;

    // Drop the reward loot around the PARADISE PACK-A-PUNCH (user 2026-07-13: "drop all the rewards
    // near the Pack a Punch machine once the team has beaten it"). The 2nd PaP is at (0,-1700,-1200)
    // (spawn_paradise_pap_at); a 120u ring keeps the pickups clear of the machine's own footprint.
    center = ( 0, -1700, -1200 );

    // The 5 wonders, runtime base names (verified _acc_map_randomizer.gsc box specials).
    // THE CYBERJACK (apex_lstar) is DELIBERATELY EXCLUDED (user 2026-07-17, docs/43 decision 2:
    // QUEST-ONLY - Paradise handing it out would bypass the ICEBREAKER COMPILE). Don't add it in a sweep.
    wonders = array( "thundergun", "t9_semiauto_cosplay", "elemental_bow_demongate", "leviathan", "freezegun" );
    for ( i = 0; i < wonders.size; i++ )
    {
        ang = i * 360 / wonders.size;
        org = center + ( cos( ang ) * 120, sin( ang ) * 120, 0 );   // 120u ring around the PaP
        level thread spawn_one_wonder_pickup( wonders[ i ], org );
    }
}

// One wonder-weapon ground pickup: script_model + hold-[+activate] trigger_radius_use (the proven data-shard /
// boss-item pickup recipe), granting the weapon via the box's own weapon_give path. One-shot; self-cleans on
// grab or at the reward-window close.
function spawn_one_wonder_pickup( wname, origin )
{
    level endon( "end_game" );

    w = GetWeapon( wname );
    if ( !isdefined( w ) ) return;

    origin = acc_utility::drop_floor_origin( origin );

    m = spawn( "script_model", origin + ( 0, 0, getdvarint( "acc_drop_model_z", 24 ) ) );
    if ( isdefined( w.worldModel ) )
        m setmodel( w.worldModel );

    t = spawn( "trigger_radius_use", origin + ( 0, 0, 40 ), 0, 56, 72 );
    t TriggerIgnoreTeam();            // any player may grab (public pickup) - REQUIRED for a script-spawned use trigger
    t UseTriggerRequireLookAt();      // can't grab through a wall
    t SetCursorHint( "HINT_NOICON" );
    t SetHintString( "Hold ^3[{+activate}]^7 for " + w.displayName );
    t.acc_wonder_model = m;

    t thread wonder_pickup_reward_end_cleanup();   // deletes model+trigger when the reward window closes

    t endon( "acc_wonder_gone" );
    for ( ;; )
    {
        t waittill( "trigger", player );
        if ( !isdefined( player ) || !isplayer( player ) || !isalive( player ) )
            continue;
        player zm_weapons::weapon_give( w, undefined, undefined, undefined, true );   // box's give path (ammo/state bootstrap)
        player PlayLocalSound( "zmb_box_weapon_grab" );
        player IPrintLnBold( "^3Paradise reward:^7 " + w.displayName );
        break;
    }

    // grabbed: tear the pickup down. DELETE, no notify - the old `t notify("acc_wonder_gone")` here
    // fired THIS thread's own `t endon` above and killed it BEFORE the deletes ran, so a grabbed
    // weapon's model + trigger stayed in the world forever (user 2026-07-12 "it needs to disappear
    // once someone takes it"). Deleting t also ends the reward-end cleanup thread (it runs ON t).
    if ( isdefined( m ) ) m delete();
    if ( isdefined( t ) ) t delete();
}

// self = the trigger. Tears the pickup down when the reward window closes (or match end). Notifies
// "acc_wonder_gone" FIRST so the grab loop's endon kills that thread, THEN deletes. This thread
// deliberately has NO matching endon of its own - the old self-endon meant its own notify killed
// this thread before the deletes ran, so un-grabbed pickups survived the reward-window close too
// (same self-notify-vs-own-endon bug as the grab path). The grab path never needs to kill this
// thread explicitly: deleting the trigger (self) ends it.
function wonder_pickup_reward_end_cleanup()
{
    level endon( "end_game" );
    level waittill( "acc_paradise_reward_end" );
    self notify( "acc_wonder_gone" );
    if ( isdefined( self.acc_wonder_model ) ) self.acc_wonder_model delete();
    if ( isdefined( self ) ) self delete();
}

// Fade out + destroy every player's win banner a few seconds into the reward window (user 2026-07-12:
// "the winning UI never disappears" - nothing ever destroyed what show_win_banner created, so the
// green text sat on screen for the rest of the run). Runs ~5s after the reward window opens (the
// 5s celebration freeze already elapsed), 2s alpha fade, then a real destroyElem so the hudelem
// slot is freed. Live dvar acc_paradise_win_banner_sec.
function clear_win_banners()
{
    level endon( "end_game" );

    wait getdvarfloat( "acc_paradise_win_banner_sec", 5 );

    foreach ( p in GetPlayers() )
    {
        if ( !isdefined( p ) || !isplayer( p ) || !isdefined( p.acc_paradise_win_txt ) ) continue;
        p.acc_paradise_win_txt fadeovertime( 2 );
        p.acc_paradise_win_txt.alpha = 0;
    }

    wait 2.1;   // let the fade land before freeing the elems

    foreach ( p in GetPlayers() )
    {
        if ( !isdefined( p ) || !isplayer( p ) || !isdefined( p.acc_paradise_win_txt ) ) continue;
        p.acc_paradise_win_txt hud::destroyElem();
        p.acc_paradise_win_txt = undefined;
    }
}

function show_win_banner()   // self = player
{
    self.acc_paradise_win_txt = self hud::createFontString( "objective", 2.2 );
    // [acc] COOP CRASH GUARD: the win fires when the shared hudelem pool is most saturated (a full
    // match of HUD x4 players); createFontString can return undefined - the field writes would throw
    // and turn the victory into a crash. Degrade to no banner rather than crash the win.
    if ( !isdefined( self.acc_paradise_win_txt ) )
        return;
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
        if ( !isdefined( bg ) )   // [acc] COOP CRASH GUARD: pool-full undefined at match-end; skip this player's fade overlay
            continue;
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

// Purge the whole horde (the documented end-game step, docs/16): DoDamage health+666 on every live AI so nothing
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

// Force-REMOVE every finale boss (Brutus / Phantom / Rogue Protector / Panzer / Avogadro / Fury) so the
// win() reward window and the continued run are a calm plaza (review 2026-07-15 - the win()==continue-the-run
// change turned purge_zombies()'s intentional boss-skip into a "boss survives + roams" regression). Delete()
// is deliberate over DoDamage: the Panzer/mechz body damage floors at stock's 0.1x scale (a DoDamage(health+666,
// origin) body hit does NOT one-shot it - _acc_boss_panzer.gsc:570), and the Avogadro's death rises via an
// allowdeath=false exit anim so DoDamage leaves isalive() TRUE mid-rise. Delete() bypasses all of that in one
// frame. It is safe: self-bound boss think/death-watch threads are torn down with the actor; the level-threaded
// paradise_boss_count_watch polls isdefined() (and is already endon'd by the acc_paradise_end notify win() fired
// just above), so nothing hangs; and no "death" notify means no death drops / rise anim in the calm window. The
// GetAITeamArray snapshot is a copy, so Deleting while iterating it is safe. Zero the caps for a clean state.
function remove_paradise_bosses()
{
    team = ( isdefined( level.zombie_team ) ? level.zombie_team : "axis" );
    zs = GetAITeamArray( team );
    for ( i = 0; i < zs.size; i++ )
    {
        b = zs[ i ];
        if ( !isdefined( b ) ) continue;
        if ( !IS_TRUE( b.acc_is_boss ) && !IS_TRUE( b.acc_is_mini_boss ) ) continue;
        b Delete();
    }

    level.acc_paradise_brutus_count  = 0;
    level.acc_paradise_phantom_count = 0;
    level.acc_paradise_rp_count      = 0;
    level.acc_paradise_avo_count     = 0;
    level.acc_paradise_panzer_count  = 0;
    level.acc_paradise_fury_count    = 0;
}
