// =============================================================================
// _acc_reactor.gsc - the "Reactor Surge": the underground CLIMAX event (docs/30).
//
// OWNER SPLIT (docs/30): the SYSTEM (this module) owns the event LOGIC + the Arm
// Plinth interactable + the tier-dialed payout. The GEOMETRY agent owns the Core
// room, the seal door, and the FX seam. INTERFACE: the §3 anchor (Plinth at
// 0,2120,-240, on the existing pit floor at the Core entrance) + a named seal
// entity "acc_reactor_seal" (OPTIONAL - the surge runs OPEN in the pit until that
// geometry lands; it is still a real "survive the horde" challenge because the
// spawned zombies persist and hunt the armer).
//
// LOOP: pay shards at the Plinth -> a timed, escalating zombie SURGE erupts from
// the pit floor (reusing acc_bus_trench::spawn_corp_surge - tagged low-payout /
// ignore_enemy_count, so it never disturbs the round count) -> survive it -> a
// TIER-DIALED payout (shards + Fire Sale + a Mega Bottle). Each completion raises
// the tier: the next Surge costs more and pays more. You don't farm it - you raid it.
//
// All GSC, no geometry. Dvar acc_reactor_on (default 1) gates the whole feature.
// =============================================================================

#using scripts\shared\ai\zombie_utility;
#using scripts\shared\util_shared;

#using scripts\zm\_zm_powerups;

#using scripts\zm\zm_abandoned_cyber_city\_acc_utility;
#using scripts\zm\zm_abandoned_cyber_city\_acc_data_shards;
#using scripts\zm\zm_abandoned_cyber_city\_acc_bus_trench;
#using scripts\zm\zm_abandoned_cyber_city\_acc_elites;
#using scripts\zm\zm_abandoned_cyber_city\_acc_boss_glitch;
#using scripts\zm\zm_abandoned_cyber_city\_acc_mega_bottles;

// Plinth model: a Cyber City interactive sign kiosk (industrial/power read for the Reactor; stock t7_props, proven packable). Placed in
// the pit, far from the perk vendor, with a distinct red REACTOR prompt - no player confusion.
// STATION REMODEL (user 2026-07-09, docs/09): Rise industrial generator (92x46x50, T7-dump
// carve) - a power read for the reactor Arm Plinth; kills the 6-way sign-kiosk reuse.
#precache( "model", "p7_ris_generator_lg_01_blue" );

// Surge tuning defaults: MORE + QUICKER waves, and re-arm on a round COOLDOWN (was a buggy once-per-round).
// SCARY PASS (user 2026-06-25): make the surge something you might NOT want to start - 5 waves (was 3), +30%
// aggression (more zombies per wave + ~30% faster spawn), and more ARMOR (Shielded "Riot") elites per wave.
// All live-dvar overridable (acc_reactor_waves / _wave_count / _wave_interval / _cooldown / _shielded_per_wave).
#define ACC_REACTOR_WAVES_DEF           5     // surge waves (3 -> 5: longer gauntlet, user 2026-06-25)
#define ACC_REACTOR_WAVE_COUNT_DEF      13    // zombies PER wave (10 -> 13: +30% aggression, user 2026-06-25)
#define ACC_REACTOR_WAVE_INTERVAL_DEF   2.1   // seconds between waves (3.0 -> 2.1: ~30% faster spawn, user 2026-06-25)
#define ACC_REACTOR_COOLDOWN_DEF        3     // rounds before the surge re-arms (was once-per-round)
#define ACC_REACTOR_SHIELDED_PER_WAVE_DEF 3   // SHIELDED ("Riot") elites erupted per wave (2 -> 3: more armor, user 2026-06-25)
#define ACC_REACTOR_GLITCH_PER_WAVE_DEF   1   // GLITCH Stalkers spawned per wave (user 2026-06-24)

#namespace acc_reactor;

// ---------------------------------------------------------------------------
// Lifecycle
// ---------------------------------------------------------------------------

function init()
{
    acc_utility::log( "reactor init" );
    level.acc_reactor_busy = false;        // one Surge at a time
    level.acc_reactor_ready_round = 0;     // round-number cooldown gate (user 2026-06-24): usable when round >= this
    level thread spawn_reactor();
}

// Round-number COOLDOWN gate (user 2026-06-24) - replaces the old once-per-round acc_round_start listener.
// WHY the rewrite: the old design gated on TWO flags - level.acc_reactor_used_round (reset each round on
// "acc_round_start") AND level.acc_reactor_busy (cleared ONLY at the end of run_surge). If a surge ever
// ABORTED before that clear (the plinth trigger's `self endon("death")`, or any mid-run error), busy stuck
// TRUE forever and the round-reset - which only cleared used_round - never recovered it => "used once, dead
// the rest of the game" (the reported bug). The new gate reads level.round_number LIVE against
// acc_reactor_ready_round, so re-availability NEVER depends on a notify firing or a flag being cleared - it
// self-heals. The cooldown is committed at the START of run_surge, and reactor_busy_watchdog force-clears a
// stuck busy. Default 3 rounds ("raid it, don't farm it", docs/30). Live dvar acc_reactor_cooldown.
function reactor_available()
{
    if ( level.acc_reactor_busy )
        return false;
    cur = ( isdefined( level.round_number ) ? level.round_number : 1 );
    return cur >= level.acc_reactor_ready_round;
}

function reactor_rounds_left()
{
    cur = ( isdefined( level.round_number ) ? level.round_number : 1 );
    n = level.acc_reactor_ready_round - cur;
    return ( n > 0 ? n : 0 );
}

// Self-heal: force-clear a stuck busy if a surge never reaches the clear in run_surge (e.g. the plinth trigger
// dies mid-run). Runs on LEVEL so it SURVIVES the trigger's death (the very failure that would stick busy),
// and exits early on the normal "acc_reactor_ended" notify. t = the plinth trigger (for the hint refresh).
// Mirrors the lockdown anti-softlock watchdog (memory: stuck-lockdown-blocks-all-bosses).
function reactor_busy_watchdog( t )
{
    level endon( "end_game" );
    level endon( "acc_reactor_ended" );
    waves = getdvarint( "acc_reactor_waves", ACC_REACTOR_WAVES_DEF );
    gap   = getdvarfloat( "acc_reactor_wave_interval", ACC_REACTOR_WAVE_INTERVAL_DEF );
    wait( waves * gap + 20 );   // generous ceiling over the real surge time + payout buffer
    if ( level.acc_reactor_busy )
    {
        level.acc_reactor_busy = false;
        if ( isdefined( t ) ) t reactor_set_hint();
        acc_utility::log( "reactor: busy watchdog force-cleared a stuck surge (self-heal)" );
    }
}

function spawn_reactor()
{
    level endon( "end_game" );
    wait 1.5;   // after data_shards / bus_trench / glitch_altar so models + pit risers are ready
    if ( getdvarint( "acc_reactor_on", 1 ) != 1 )
        return;

    // Arm Plinth - in the jukebox NORTH under-room (user 2026-06-26: declutter the trench + reward opening that
    // door). Room is ORIGINAL: interior x[-192,192], walkable y[2189,2517], floor z=-240. Plinth is CENTERED (x=0)
    // at the back wall (0,2493) - clip north flush at 2517. STATION REMODEL 2026-07-09: the plinth is now the
    // Rise industrial generator (92 LONG in X x 46 deep) - yaw 0 keeps the long axis along the back wall
    // (yaw 270 would poke it through the north wall at 2517) and stays clear of the jukebox machine
    // (_acc_jukebox, replaced the 3 teddy bears 2026-07-09) - MOVED to the SOUTH-WEST at (-150, 2240)
    // on 2026-07-10 (user: "spread them out") so the plinth (north wall) and jukebox (south corner) sit
    // ~290u apart across the room instead of clustered ~200u in the north-west.
    spawn_plinth_at( ( 0, 2493, -240 ), 0 );
}

function spawn_plinth_at( origin, yaw )
{
    m = spawn( "script_model", origin );
    m setmodel( "p7_ris_generator_lg_01_blue" );
    if ( isdefined( yaw ) ) m.angles = ( 0, yaw, 0 );

    t = spawn( "trigger_radius_use", origin + ( 0, 0, 40 ), 0, 64, 90 );
    t TriggerIgnoreTeam();   // REQUIRED for a script-spawned use-trigger to be player-usable (stock _zm_perks.gsc:1523).
    t SetCursorHint( "HINT_NOICON" );
    t.acc_plinth_model = m;
    t reactor_set_hint();
    t thread reactor_loop();
    t thread reactor_hint_round_refresh();
    acc_utility::log( "reactor: Arm Plinth spawned at " + origin );
}

// Cosmetic: refresh the cooldown hint each round so the "(N round(s))" countdown stays current while the
// reactor recharges. DISPLAY ONLY - the availability gate (reactor_available) reads level.round_number
// LIVE, so this never affects re-arming; a missed notify just leaves the hint briefly stale. (The module
// deliberately avoids a notify for CORRECTNESS - user 2026-06-24 - but a display refresh carries no such
// risk.) reactor_set_hint already branches on busy/available, so calling it every round is safe.
function reactor_hint_round_refresh()   // self = the plinth trigger
{
    self endon( "death" );
    level endon( "end_game" );
    for ( ;; )
    {
        level waittill( "acc_round_start" );
        self reactor_set_hint();
    }
}

// ---------------------------------------------------------------------------
// Cost / reward dial (scale with the completed-Surge tier).
// ---------------------------------------------------------------------------

// FREE to activate, then a few-round COOLDOWN (acc_reactor_cooldown, default 3); survive the surge ->
// a flat reward to EVERYONE (user 2026-06-19; cooldown 2026-06-24; reward 3 -> 5 shards/player 2026-06-24).
function reactor_reward() { return getdvarint( "acc_reactor_reward", 5 ); }   // shards PER PLAYER on success

function reactor_set_hint()   // self = the plinth trigger
{
    if ( level.acc_reactor_busy )
        self SetHintString( "^1REACTOR CRITICAL^7 - surge in progress" );
    else if ( !reactor_available() )
        self SetHintString( "^1REACTOR^7 - recharging (" + reactor_rounds_left() + " round(s))" );
    else
        // Buyable-UI audit fix (2026-07-03): "survive for" tripped the router's "hold"+"for"
        // mystery-box weapon-pickup mode (it displayed "5 Data Shards each + Fire Sale" as a
        // WEAPON name). "survive it:" carries no router token -> DefaultHint.
        self SetHintString( "Hold ^3[{+activate}]^7  ^1REACTOR SURGE^7 - survive it: ^5" + reactor_reward() +
                            " Data Shards^7 each + Fire Sale" );
}

// ---------------------------------------------------------------------------
// Interaction
// ---------------------------------------------------------------------------

function reactor_loop()   // self = the plinth trigger
{
    self endon( "death" );
    level endon( "end_game" );

    for ( ;; )
    {
        self waittill( "trigger", player );
        if ( !acc_data_shards::is_player_alive( player ) ) continue;

        if ( level.acc_reactor_busy )
        {
            player acc_utility::hud_msg( "^1REACTOR^7 - already critical!" );
            wait 0.4;
            continue;
        }
        if ( !reactor_available() )
        {
            player acc_utility::hud_msg( "^1REACTOR^7 - recharging (" + reactor_rounds_left() + " round(s))" );
            wait 0.4;
            continue;
        }

        // FREE to activate (it's a reward event now, not a paid sink).
        self thread run_surge( player );
        wait 0.4;
    }
}

function run_surge( player )   // self = the plinth trigger
{
    self endon( "death" );
    level endon( "end_game" );

    level.acc_reactor_busy = true;
    // Commit the round COOLDOWN NOW (not at the end), so the kiosk re-arms in N rounds even if this surge
    // aborts before the busy-clear below - reactor_available() reads round_number live, so it self-heals.
    cur = ( isdefined( level.round_number ) ? level.round_number : 1 );
    level.acc_reactor_ready_round = cur + getdvarint( "acc_reactor_cooldown", ACC_REACTOR_COOLDOWN_DEF );
    self reactor_set_hint();
    level thread reactor_busy_watchdog( self );   // self-heal: force-clears busy if this surge never reaches the clear

    waves = getdvarint( "acc_reactor_waves", ACC_REACTOR_WAVES_DEF );
    per   = getdvarint( "acc_reactor_wave_count", ACC_REACTOR_WAVE_COUNT_DEF );   // zombies PER wave (more aggressive)
    gap   = getdvarfloat( "acc_reactor_wave_interval", ACC_REACTOR_WAVE_INTERVAL_DEF );   // seconds between waves (quicker)

    level notify( "acc_reactor_started" );
    seal_close();
    if ( acc_data_shards::is_player_alive( player ) )
        player acc_utility::hud_msg( "^1REACTOR SURGE^7 - SURVIVE!" );

    for ( i = 0; i < waves; i++ )
    {
        // Reuse the pit-surge machinery: erupts `per` zombies from the pit floor risers, tagged
        // low-payout + ignore_enemy_count (so the round count is untouched). The trench-aggro
        // system beelines/sprints them at the armer.
        level thread acc_bus_trench::spawn_corp_surge( per );
        // Plus a few SHIELDED elites + GLITCH Stalkers per wave (user 2026-06-24) - the elite gauntlet.
        // Both are flagged acc_no_shard_reward so they grant NO shards on kill (same as the glitch purge).
        level thread reactor_spawn_specials( cur );
        if ( acc_data_shards::is_player_alive( player ) )
            player acc_utility::hud_msg( "^1REACTOR^7 - wave " + ( i + 1 ) + "/" + waves );
        wait( gap );
    }

    wait 2;   // let the last wave commit before we judge survival
    seal_open();
    level.acc_reactor_busy = false;
    self reactor_set_hint();
    level notify( "acc_reactor_ended" );

    // Payout ONLY if the armer SURVIVED IN THE DANGER ZONE - alive AND still underground (else you could
    // arm it, climb out of the pit to safety, and collect free). acc_reactor_require_pit 0 relaxes it.
    survived = acc_data_shards::is_player_alive( player ) &&
               ( getdvarint( "acc_reactor_require_pit", 1 ) == 0 || acc_bus_trench::player_in_underground( player ) );
    if ( !survived )
    {
        if ( acc_data_shards::is_player_alive( player ) )
            player acc_utility::hud_msg( "^1REACTOR FAILED^7 - you abandoned the core (stay in the pit!)" );
        level notify( "acc_reactor_failed" );
        return;
    }

    // Success: EVERYONE gets reactor_reward() shards + a shared FIRE SALE (user 2026-06-27: was a shared Insta-Kill).
    reward = reactor_reward();
    players = level.players;
    for ( i = 0; i < players.size; i++ )
        acc_data_shards::grant_player( players[ i ], reward, "reactor" );
    level thread zm_powerups::specific_powerup_drop( "fire_sale", player.origin );
    player PlaySound( "acc_shard_pickup" );
    player acc_utility::hud_msg( "^2REACTOR STABILIZED^7 - everyone +" + reward + " Data Shards + Fire Sale!" );
}

// ---------------------------------------------------------------------------
// Surge SPECIALS (user 2026-06-24): each wave also erupts a few SHIELDED ("Riot") elites + GLITCH
// Stalkers, turning the surge into an elite gauntlet. BOTH are flagged self.acc_no_shard_reward so
// they grant NO Data Shards on kill (a survive-the-threat, not a farm - same as the glitch purge):
// _acc_elites::shielded_death_reward and _acc_boss_glitch::glitch_death_watch both honour the flag.
// They're ignore_enemy_count (off the round books, like the regular surge) and persist as threats.
// Per-wave counts are live dvars; 0 disables that type.
// ---------------------------------------------------------------------------

function reactor_spawn_specials( round_number )
{
    level endon( "end_game" );

    n_shield = getdvarint( "acc_reactor_shielded_per_wave", ACC_REACTOR_SHIELDED_PER_WAVE_DEF );
    n_glitch = getdvarint( "acc_reactor_glitch_per_wave", ACC_REACTOR_GLITCH_PER_WAVE_DEF );

    for ( i = 0; i < n_shield; i++ )
    {
        level thread reactor_spawn_shielded();
        wait 0.2;   // small stagger
    }
    for ( i = 0; i < n_glitch; i++ )
    {
        // spawn_glitch builds a full Glitch Stalker near a living player (its own spawn path), already
        // ignore_enemy_count + no_gib. Flag it so glitch_death_watch grants no shard.
        host = acc_boss_glitch::spawn_glitch( round_number );
        if ( isdefined( host ) )
            host.acc_no_shard_reward = true;
        wait 0.2;
    }
}

// Erupt ONE Shielded ("Riot") elite from the pit risers (so it's part of the surge, in the pit with you),
// wait the per-actor init gate, flag it no-shard, tag it as a surge zombie (ignore_enemy_count + the pit
// emergence fix so it can melee), then promote. promote_to_shielded threads its 2-shard death reward, but
// the flag (set FIRST) suppresses it. Falls back to a plain spawner if the risers aren't available.
function reactor_spawn_shielded()
{
    level endon( "end_game" );

    if ( !isdefined( level.zombie_spawners ) || level.zombie_spawners.size == 0 )
        return;

    risers  = acc_bus_trench::get_layer_risers( 1 );   // L1 = the map pit risers
    spawner = level.zombie_spawners[ acc_utility::acc_rand_int( level.zombie_spawners.size ) ];

    loc = undefined;
    if ( isdefined( risers ) && risers.size > 0 )
        loc = risers[ acc_utility::acc_rand_int( risers.size ) ];

    z = ( isdefined( loc ) ? zombie_utility::spawn_zombie( spawner, undefined, loc )
                           : zombie_utility::spawn_zombie( spawner ) );
    if ( !isdefined( z ) )
        return;

    // Promote AFTER the per-actor init gate - stock zombie_spawn_init resets health at frame-end, so
    // promoting before it gets clobbered (same pattern as spawn_elite / spawn_promoted_zombie). Bounded
    // so a never-init actor can't hang the thread.
    n = 0;
    while ( isdefined( z ) && !isdefined( z.zombie_init_done ) && n < 100 )
    {
        util::wait_network_frame();
        n++;
    }
    if ( !isdefined( z ) || !isalive( z ) )
        return;

    z.acc_no_shard_reward = true;                  // user 2026-06-24: reactor specials grant NO shards
    z thread acc_bus_trench::tag_trench_zombie();  // ignore_enemy_count + pit emergence fix (so it melees) + flat points (no shards)
    acc_elites::promote_to_shielded( z );          // 5x HP + front armor + shield model; its 2-shard reward is now suppressed
}

// ---------------------------------------------------------------------------
// Sealed-arena hook (docs/30 §5). If the parallel geometry agent has placed a seal door
// (script_brushmodel targetname "acc_reactor_seal") that listens for these notifies, the Core
// seals during a Surge. Until that geometry lands, getentarray is empty => harmless no-op and
// the surge runs OPEN in the pit. NEVER hard-depends on the unbuilt Core room.
// ---------------------------------------------------------------------------

function seal_close()
{
    doors = getentarray( "acc_reactor_seal", "targetname" );
    for ( i = 0; i < doors.size; i++ )
        doors[ i ] notify( "acc_reactor_seal_close" );
}

function seal_open()
{
    doors = getentarray( "acc_reactor_seal", "targetname" );
    for ( i = 0; i < doors.size; i++ )
        doors[ i ] notify( "acc_reactor_seal_open" );
}
