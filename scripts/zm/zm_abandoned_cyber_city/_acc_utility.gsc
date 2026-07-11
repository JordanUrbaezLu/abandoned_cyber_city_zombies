// =============================================================================
// _acc_utility.gsc - shared helpers used across every _acc_ module
//
// Keep this file SMALL. Rule of thumb: if only one module uses a helper, put
// it in that module. If two or more need it, it belongs here.
// =============================================================================

#using scripts\shared\array_shared;
#using scripts\shared\util_shared;
#using scripts\shared\hud_util_shared;

#using scripts\zm\_zm_utility;

#namespace acc_utility;

// ---------------------------------------------------------------------------
// On-screen feedback message (shared). Use INSTEAD of iprintln for trench / machine
// feedback: iprintln dumps into the bottom notification area where the round counter and
// points cover it (user 2026-06-19). This is a per-player hudelem at upper-center,
// dvar-tunable (acc_msg_y; SMALLER = higher) and (acc_msg_sec = hold seconds); a new message
// on the SAME slot refreshes the elem in place instead of stacking. Call ON the player:
// `player acc_utility::hud_msg( txt )` (= slot 0, the shared cyan toast every system uses).
//
// SLOTS (user 2026-06-24): two pickups can fire on the same frame (a boss kill grants a Mega
// Bottle while a Data Shard drop is grabbed) - on one slot the second SetText overwrites the
// first. `hud_msg_slot( txt, slot, color )` gives each independent line its own elem + own
// fade at its own y (slot N sits acc_msg_slot_h px below slot N-1), so they never overlap. The
// Mega Bottle pickup uses slot 1 (gold); slot 0 stays the generic/shard toast.
// ---------------------------------------------------------------------------

// Back-compat API: the generic upper-center toast = slot 0 (cyan). Every existing
// caller (cyberware/exo/overclocks/reactor/shards/...) routes here unchanged.
function hud_msg( text )   // self = player
{
    self hud_msg_slot( text, 0, ( 0.6, 0.9, 1.0 ) );
}

// One INDEPENDENT toast line per `slot`, each at its own y (slot 0 = acc_msg_y; each higher
// slot acc_msg_slot_h px lower) with its own elem + its own fade, so two simultaneous pickups
// never overwrite each other. `color` optional (defaults cyan). See the header note.
function hud_msg_slot( text, slot, color )   // self = player
{
    if ( !isdefined( self ) ) return;
    if ( !isdefined( slot ) ) slot = 0;
    if ( !isdefined( color ) ) color = ( 0.6, 0.9, 1.0 );
    if ( !isdefined( self.acc_hud_msg_slots ) ) self.acc_hud_msg_slots = [];
    if ( !isdefined( self.acc_hud_msg_slots[ slot ] ) )
    {
        e = he_check( self hud::createFontString( "default", 1.5 ), "toast.slot" + slot );
        if ( isdefined( e ) )
        {
            e.alignX = "center";
            e.alignY = "middle";
            e.hidewheninmenu = true;
        }
        self.acc_hud_msg_slots[ slot ] = e;
    }
    e = self.acc_hud_msg_slots[ slot ];
    // [acc] COOP CRASH GUARD: when the shared hudelem pool is FULL, he_check returns undefined and the
    // store above (assigning undefined) REMOVES the key, so `e` is undefined here. Dereferencing it
    // (setPoint/SetText) threw "method on undefined" and ended the game - a demonstrated 4-player
    // pool-exhaustion condition (memory server-hudelem-pool-exhaustion-coop). Bail; the toast just doesn't draw.
    if ( !isdefined( e ) ) return;
    // Re-apply the anchor each show so a live acc_msg_y tweak takes effect without a relog.
    e hud::setPoint( "TOP", "TOP", 0, getdvarint( "acc_msg_y", 190 ) + slot * getdvarint( "acc_msg_slot_h", 26 ) );
    e.color = color;
    e SetText( text );
    e.alpha = 1;
    self thread hud_msg_fade( slot );
}

function hud_msg_fade( slot )   // self = player
{
    if ( !isdefined( slot ) ) slot = 0;
    self notify( "acc_hud_msg_refresh_" + slot );   // cancel only THIS slot's in-flight fade (per-slot, so slots don't cancel each other)
    self endon( "acc_hud_msg_refresh_" + slot );
    self endon( "disconnect" );
    wait( getdvarfloat( "acc_msg_sec", 3.0 ) );
    if ( isdefined( self.acc_hud_msg_slots ) && isdefined( self.acc_hud_msg_slots[ slot ] ) )
    {
        self.acc_hud_msg_slots[ slot ] fadeovertime( 0.5 );
        self.acc_hud_msg_slots[ slot ].alpha = 0;
    }
}

// ---------------------------------------------------------------------------
// HUDELEM POOL DIAGNOSTIC (user 2026-06-28). The server hudelem pool is SHARED + FIXED; when it fills,
// hud::create* returns UNDEFINED and the widget silently does NOT draw (no crash - row_complete relies on this).
// he_check(elem,label): call right after a hud::create* - counts live allocations AND logs the exact site the
// moment one FAILS (pool full). Returns elem (pass-through): x = he_check( self createFontString(...), "label" ).
// he_free(): call on Destroy() to keep the count honest. he_log(): the on-screen channel (IPrintLnBold = pool-
// FREE, so the logger itself can't fail), gated by acc_hudelem_debug (dev mode SetDvars it on). acc_he_hi = the
// live high-water mark so you watch the count climb to the break. memory server-hudelem-pool-exhaustion-coop.
// ---------------------------------------------------------------------------
function he_check( elem, label, n )   // n = raw hudelems this create represents (createBar = 3); default 1
{
    if ( !isdefined( n ) ) n = 1;
    if ( !isdefined( level.acc_he_n ) ) { level.acc_he_n = 0; level.acc_he_hi = 0; level.acc_he_fail = 0; }
    if ( isdefined( elem ) )
    {
        level.acc_he_n += n;
        if ( level.acc_he_n > level.acc_he_hi )
        {
            level.acc_he_hi = level.acc_he_n;
            if ( ( level.acc_he_hi % 5 ) == 0 ) he_log( "^3[hudelem] live peak " + level.acc_he_hi + " (+" + label + ")" );
        }
    }
    else
    {
        level.acc_he_fail++;
        he_log( "^1[hudelem] '" + label + "' did NOT allocate - POOL FULL (live=" + level.acc_he_n + ", fails=" + level.acc_he_fail + ")" );
    }
    return elem;
}

function he_free( n )
{
    if ( !isdefined( n ) ) n = 1;
    if ( isdefined( level.acc_he_n ) ) { level.acc_he_n -= n; if ( level.acc_he_n < 0 ) level.acc_he_n = 0; }
}

function he_log( msg )
{
    if ( !( isdefined( level.acc_dev ) && level.acc_dev ) && getdvarint( "acc_hudelem_debug", 0 ) != 1 ) return;
    players = get_all_players();
    for ( i = 0; i < players.size; i++ )
        if ( isdefined( players[ i ] ) ) players[ i ] IPrintLnBold( msg );
}

// ---------------------------------------------------------------------------
// Logging. All _acc_ logs are prefixed so you can grep console.log cleanly.
// ---------------------------------------------------------------------------

function log( msg )
{
    iprintlnbold_if_dev( "[acc] " + msg );
    /# println( "[acc] " + msg ); #/  // /# #/ = devmode-only block
}

function log_player( player, msg )
{
    log( "player=" + player.name + " " + msg );
}

function iprintlnbold_if_dev( msg )
{
    /# iprintln( msg ); #/
}

// Snap a loot-drop origin to the FLOOR beneath it - the ONE shared ground-snap for every world
// pickup (boss items, zombie item drops, shard drops). Live dvar acc_drop_floor_snap (1 = on).
//
// WHY THE ENTITY-STEPPING LOOP (user 2026-07-08, "items still floating; the GLOW is airborne too"):
// a plain BulletTrace down from origin+60 starts INSIDE the dying enemy's own body, and a solid
// AI hit returns position ~= the airborne death origin - so the "snap" landed the drop ON THE
// CORPSE mid-air. That was the real cause of floating drops from the hovering bosses (Rogue
// Protector / Avogadro); ground zombies never showed it because their corpse already sits on the
// floor. Fix: when the trace hits an ACTOR or PLAYER (the dying boss, a sibling, a teammate), step
// 4u below the hit and re-trace, until we reach either WORLD geometry (tr["entity"] undefined -
// the stock world-hit idiom, vehicle_shared.gsc:2772) or a solid NON-AI entity (a script_brushmodel
// bridge/platform IS a floor - accept it). A true miss (fraction >= 1: over a void) KEEPS the
// original origin - never bury a drop 2500u below. Diagnostics ride drops_debug (dev-visible).
function drop_floor_origin( origin )
{
    if ( getdvarint( "acc_drop_floor_snap", 1 ) != 1 ) return origin;

    start  = origin + ( 0, 0, 60 );
    bottom = origin - ( 0, 0, 2500 );
    for ( i = 0; i < 8; i++ )
    {
        tr = BulletTrace( start, bottom, false, undefined );
        if ( !isdefined( tr ) || !isdefined( tr[ "fraction" ] ) || tr[ "fraction" ] >= 1 || !isdefined( tr[ "position" ] ) )
        {
            drops_debug( "floor-snap MISS (kept origin) after " + i + " step(s) at " + origin );
            return origin;   // nothing below within 2500u: keep the origin (never bury)
        }

        e = tr[ "entity" ];
        if ( !isdefined( e ) )
        {
            if ( i > 0 ) drops_debug( "floor-snap stepped through " + i + " body/bodies -> floor " + tr[ "position" ] );
            return tr[ "position" ];   // world geometry = the real floor
        }
        if ( !isplayer( e ) && !( IsActor( e ) ) )
        {
            return tr[ "position" ];   // solid non-AI entity (brushmodel bridge / door slab) = a walkable surface
        }

        // Hit a live/dying AI or player body (the boss's own corpse on its death frame, a sibling
        // boss, a teammate under the flyer): step just below the hit and keep tracing down.
        start = tr[ "position" ] - ( 0, 0, 4 );
        if ( start[ 2 ] <= bottom[ 2 ] ) break;
    }

    drops_debug( "floor-snap gave up (8 entity hits) - kept origin " + origin );
    return origin;
}

// Drop/pickup debug channel, gated by the `acc_drops_debug` dvar (default 0 =
// silent in normal play). Uses IPrintLnBold deliberately: it is the ONLY channel
// that reaches console_mp.log (printed there as "[ SCRIPTER] ..."); the /# #/
// dev block in log() does NOT reliably route to the log (CLAUDE.md logging truth).
// Launch with: +set acc_drops_debug 1 +set logfile 1
function drops_debug( msg )
{
    if ( !( isdefined( level.acc_dev ) && level.acc_dev ) && getdvarint( "acc_drops_debug", 0 ) != 1 ) return;
    players = get_all_players();
    for ( i = 0; i < players.size; i++ )
    {
        p = players[ i ];
        if ( isdefined( p ) && isplayer( p ) )
        {
            p IPrintLnBold( "^6[drops] ^7" + msg );
        }
    }
}

// Crash-diagnostic breadcrumb channel (user 2026-06-19: random CTD on boots + slide). GSC can't
// catch a hard engine crash, so instead we drop a breadcrumb at each step of the suspect paths; the
// LAST [CRASHDBG] line in console_mp.log = the step just before the CTD. Gated by `acc_crash_debug`
// (default 0, silent). Routes via IPrintLnBold (the one channel that reaches console_mp.log as
// "[ SCRIPTER] ..."; the /# #/ println does not reliably). ENABLE + REPRODUCE + READ:
//   launch with  +set acc_crash_debug 1 +set logfile 1
//   reproduce the crash, then read the LAST "[CRASHDBG]" lines in <game>\console_mp.log.
function crash_log( player, msg )
{
    if ( !( isdefined( level.acc_dev ) && level.acc_dev ) && getdvarint( "acc_crash_debug", 0 ) != 1 ) return;
    if ( isdefined( player ) && isplayer( player ) )
    {
        player IPrintLnBold( "^1[CRASHDBG]^7 " + msg );
    }
    else
    {
        players = get_all_players();
        if ( isdefined( players ) && players.size > 0 && isdefined( players[ 0 ] ) )
            players[ 0 ] IPrintLnBold( "^1[CRASHDBG]^7 " + msg );
    }
    /# println( "[CRASHDBG] " + msg ); #/
}

// Compact string of the speed flags currently active on a player (for crash_log breadcrumbs).
function active_speed_flags( player )
{
    f = "";
    if ( isdefined( player.acc_item_boots ) && player.acc_item_boots )                 f += "boots ";
    if ( isdefined( player.acc_item_neural_boots ) && player.acc_item_neural_boots )   f += "nboots ";
    if ( isdefined( player.acc_mega_flopper_speed ) && player.acc_mega_flopper_speed ) f += "megaflop ";
    if ( isdefined( player.acc_rocket_slide_speed ) && player.acc_rocket_slide_speed ) f += "rocket ";
    if ( isdefined( player.acc_gas_burst ) && player.acc_gas_burst )                   f += "gas ";
    if ( isdefined( player.acc_flash_speed ) && player.acc_flash_speed )               f += "flash ";
    if ( isdefined( player.acc_savior_speed ) && player.acc_savior_speed )             f += "savior ";
    if ( isdefined( player.acc_cw_rx1_speed ) && player.acc_cw_rx1_speed )             f += "cwrx1 ";
    if ( isdefined( player.acc_trench_slow ) && player.acc_trench_slow )               f += "trench ";
    if ( isdefined( player.acc_phantom_slowed ) && player.acc_phantom_slowed )         f += "phantomslow ";
    if ( isdefined( player.acc_battery_boost ) && player.acc_battery_boost )           f += "battery ";
    return f;
}

// ---------------------------------------------------------------------------
// RNG. We use a seeded PRNG for map-state rolls so runs can be reproduced by
// seed later (post-1.0 feature, see docs/06_replayability.md).
// For now, randomint is fine; the wrapper gives us one place to swap in a
// seeded PRNG later without hunting every callsite.
// ---------------------------------------------------------------------------

function acc_rand_int( max_exclusive )
{
    // TODO(acc-seeded): swap in seeded PRNG when we build that feature.
    return randomint( max_exclusive );
}

function acc_rand_float()
{
    return randomfloat( 1.0 );
}

// Weighted pick. `choices` is an array of objects each with `.weight` and `.value`.
function acc_weighted_pick( choices )
{
    total = 0;
    for ( i = 0; i < choices.size; i++ )
    {
        total += choices[ i ].weight;
    }

    if ( total <= 0 )
    {
        // Fallback: uniform pick.
        return choices[ acc_rand_int( choices.size ) ].value;
    }

    roll = randomfloat( total );
    acc = 0;
    for ( i = 0; i < choices.size; i++ )
    {
        acc += choices[ i ].weight;
        if ( roll <= acc )
        {
            return choices[ i ].value;
        }
    }

    return choices[ choices.size - 1 ].value;
}

// ---------------------------------------------------------------------------
// Player helpers
// ---------------------------------------------------------------------------

function get_all_players()
{
    // level.players is maintained by stock on connect/disconnect.
    // Use this instead of iterating entity pools.
    return level.players;
}

function get_closest_player_to( origin )
{
    return zm_utility::get_closest_player( origin );
}

// Like get_closest_player_to but SKIPS players with the GLITCH cloak flag
// (self.acc_cloak_glitch, set by the Phase Serum boss item). Only the Glitch Stalker
// targeting uses this, so the cloak hides you from the STALKER ONLY - the regular
// horde (which uses the stock find-flesh path) still targets you normally. Returns
// undefined when every player is cloaked (callers already guard for that).
function get_closest_uncloaked_player( origin )
{
    players = arraycopy( level.players );
    filtered = [];
    for ( i = 0; i < players.size; i++ )
    {
        p = players[ i ];
        // Exclude cloaked (Li'l Arnie acc_cloak_glitch) AND invalid players. The is_player_valid
        // check is the COOP GLITCH-STALKER FIX (user 2026-07-04): without it a DOWNED teammate (who
        // stays on the map in coop, perfectly stationary) could be the straight-line-closest "target"
        // for the Stalker's blink AND phase-in charge, while the AI's real path-distance enemy is a
        // different LIVE player - the two fought and the boss teleported around the downed body in the
        // same spot over and over. is_player_valid = defined/alive/spawned/not-laststand/not-spectator
        // (mirrors the Phantom's valid_target_players, which already excludes downed teammates). Do NOT
        // remove this - re-including downed players revives the same-spot-teleport bug.
        if ( isdefined( p ) && zm_utility::is_player_valid( p )
             && !( isdefined( p.acc_cloak_glitch ) && p.acc_cloak_glitch ) )
        {
            filtered[ filtered.size ] = p;
        }
    }
    if ( filtered.size == 0 ) return undefined;
    return arraygetclosest( origin, filtered );
}

// ---------------------------------------------------------------------------
// Delayed actions. Safe wrappers so we don't forget endon-on-disconnect.
// ---------------------------------------------------------------------------

function run_after_delay( delay_sec, func )
{
    self endon( "disconnect" );
    wait( delay_sec );
    self [[ func ]]();
}

// ---------------------------------------------------------------------------
// Math
// ---------------------------------------------------------------------------

function clamp_int( x, low, high )
{
    if ( x < low ) return low;
    if ( x > high ) return high;
    return x;
}

function clamp_float( x, low, high )
{
    if ( x < low ) return low;
    if ( x > high ) return high;
    return x;
}

// ---------------------------------------------------------------------------
// Move speed - single owner.
//
// VERIFIED(acc): SetMoveSpeedScale is ABSOLUTE (last-writer-wins; stock
// resets to 1 on every spawn, zm_usermap.gsc:336), so read-modify-write
// stacking between modules silently erases each other. Every speed-affecting
// system sets its flag and calls this recompute instead of writing the scale
// directly. Writers: _acc_boss_items (Neural Boots), _acc_cyberware (Reflex
// T1), _acc_mega_bottles (The Flash).
// ---------------------------------------------------------------------------

function recompute_move_speed( player )
{
    n_scale = 1.0;
    if ( isdefined( player.acc_item_neural_boots ) && player.acc_item_neural_boots )
    {
        n_scale = n_scale * 1.20; // Neural Boots (docs/09_boss_items.md)
    }
    if ( isdefined( player.acc_item_boots ) && player.acc_item_boots )
    {
        n_scale = n_scale * getdvarfloat( "acc_boots_mult", 1.08 ); // Boots boss item: +8% move overall + trench-slow immunity (user 2026-06-18, docs/09)
    }
    if ( isdefined( player.acc_cw_rx1_speed ) && player.acc_cw_rx1_speed )
    {
        n_scale = n_scale * 1.10; // Cyberware Reflex T1 (docs/03)
    }
    if ( isdefined( player.acc_flash_speed ) && player.acc_flash_speed )
    {
        n_scale = n_scale * 1.15; // The Flash Mega: +15% move (docs/10)
    }
    if ( isdefined( player.acc_battery_boost ) && player.acc_battery_boost )
    {
        // Battery boss item (docs/09, user 2026-07-08): a boss zap ABSORBED by the implant becomes a
        // +20% surge for 5s instead of a slow (flag set by _acc_elites::acc_battery_surge). While the surge
        // is active the zap applicators absorb further zaps (acc_battery_absorb_zap), so a slow flag is NOT
        // set during the boost - they never multiply against each other. (A zap during the post-surge
        // recharge CAN set a slow flag, but the boost is already cleared by then, so still no stacking.)
        n_scale = n_scale * getdvarfloat( "acc_battery_boost_mult", 1.20 );
    }
    if ( isdefined( player.acc_savior_speed ) && player.acc_savior_speed )
    {
        n_scale = n_scale * 1.15; // Savior Mega: +15% while a teammate is down (docs/10)
    }
    if ( isdefined( player.acc_mega_flopper_speed ) && player.acc_mega_flopper_speed )
    {
        n_scale = n_scale * getdvarfloat( "acc_mega_flopper_slide_mult", 1.75 ); // Mega Flopper (PhD Slider): 1.75x WHILE SLIDING (user 2026-07-05, was 1.5x, docs/10)
    }
    if ( isdefined( player.acc_gas_burst ) && player.acc_gas_burst )
    {
        n_scale = n_scale * getdvarfloat( "acc_gas_burst_mult", 2.0 ); // Gas Tank nitro burst: +100% (live dvar, docs/09)
    }
    if ( isdefined( player.acc_rocket_slide_speed ) && player.acc_rocket_slide_speed )
    {
        n_scale = n_scale * getdvarfloat( "acc_rocket_slide_mult", 1.75 ); // Rocket Shield: 1.75x while sliding (user 2026-07-05, was 1.5x; live dvar, docs/09)
    }
    // BOSS ZAP STUNS BARELY STACK (user 2026-07-09). The three boss zap slows - Phantom chain-special /
    // Rogue Protector / Avogadro, each -30% normally (user 2026-07-05, was -25%), softened to -10% for Mega
    // Electric Cherry "Power Surge" (was full immunity; applicators in _acc_elites) - used to MULTIPLY when
    // two+ bosses zapped the same player (0.70 x 0.70 = 0.49x, all three = 0.34x): a multi-boss/Paradise
    // pile-on stun-locked you to a crawl. Now the single STRONGEST active boss slow is the base and each
    // EXTRA concurrent stun adds only a flat -5% (acc_boss_slow_stack_add): one stun -30%, two at once
    // -35%, three -40%. MEGA ELECTRIC CHERRY PREVENTS THE STACKING OUTRIGHT (user 2026-07-09): while every
    // active stun is Mega-softened, the slow is a FLAT -10% no matter how many bosses zap you - the
    // anti-stack is part of the perk's ability. Each boss's 3s window still refreshes independently (its
    // own flag + clear thread) - as stuns expire the count drops and the base falls back to the strongest
    // one still running.
    n_boss_slow  = 1.0;
    n_boss_stuns = 0;
    b_all_mega   = true;   // stays true only while every active stun carries its mega-softened snapshot
    if ( isdefined( player.acc_phantom_slowed ) && player.acc_phantom_slowed )
    {
        n_boss_stuns++;
        if ( isdefined( player.acc_phantom_slow_mega ) && player.acc_phantom_slow_mega )
            m = getdvarfloat( "acc_boss_slow_mega_mult", 0.90 );
        else
        {
            m = getdvarfloat( "acc_phantom_slow_mult", 0.70 );
            b_all_mega = false;
        }
        if ( m < n_boss_slow ) n_boss_slow = m;
    }
    if ( isdefined( player.acc_protector_slowed ) && player.acc_protector_slowed )
    {
        n_boss_stuns++;
        if ( isdefined( player.acc_protector_slow_mega ) && player.acc_protector_slow_mega )
            m = getdvarfloat( "acc_boss_slow_mega_mult", 0.90 );
        else
        {
            m = getdvarfloat( "acc_protector_slow_mult", 0.70 );
            b_all_mega = false;
        }
        if ( m < n_boss_slow ) n_boss_slow = m;
    }
    if ( isdefined( player.acc_avogadro_slowed ) && player.acc_avogadro_slowed )
    {
        n_boss_stuns++;
        if ( isdefined( player.acc_avogadro_slow_mega ) && player.acc_avogadro_slow_mega )
            m = getdvarfloat( "acc_boss_slow_mega_mult", 0.90 );
        else
        {
            m = getdvarfloat( "acc_avogadro_slow_mult", 0.70 );
            b_all_mega = false;
        }
        if ( m < n_boss_slow ) n_boss_slow = m;
    }
    // Stack add ONLY when at least one non-Mega stun is active: a full Mega Electric Cherry holder stays
    // at the flat -10% (all snapshots mega -> n_boss_slow is already the 0.90 base, no add). A MIXED set
    // (perk bought/lost mid-window) behaves as non-mega: strongest raw slow + the stack add.
    if ( n_boss_stuns > 1 && !b_all_mega )
        n_boss_slow = n_boss_slow - ( ( n_boss_stuns - 1 ) * getdvarfloat( "acc_boss_slow_stack_add", 0.05 ) );
    if ( n_boss_slow < 0.10 ) n_boss_slow = 0.10;   // never near-zero speed (mirrors the exo-slow 0.90 cap)
    n_scale = n_scale * n_boss_slow;
    // Layered trench slow (docs/29): depends on how many layers you are BELOW your Exo Suit's coverage.
    // Exo tier T -> normal in layers 1..T; below that, -20% at the first uncovered layer, then -10% per
    // layer deeper (-0.10*(L-T-1)). Boots do NOT cancel this (user 2026-06-21) - only the Exo Suit does.
    // acc_trench_layer is set by the bus_trench watcher; acc_exo_tier by _acc_exo. Gated by acc_trench_slow_on.
    exo_layer = ( isdefined( player.acc_trench_layer ) ? player.acc_trench_layer : 0 );
    exo_tier  = ( isdefined( player.acc_exo_tier ) ? player.acc_exo_tier : 0 );
    if ( exo_layer > exo_tier && getdvarint( "acc_trench_slow_on", 1 ) == 1 )
    {
        exo_red = getdvarfloat( "acc_exo_slow_first", 0.20 ) + ( ( exo_layer - exo_tier - 1 ) * getdvarfloat( "acc_exo_slow_step", 0.10 ) );
        if ( exo_red > 0.90 ) exo_red = 0.90;   // never let speed hit 0
        n_scale = n_scale * ( 1.0 - exo_red );
    }
    // TWO active boss-item slots (docs/09) let two MOBILITY items stack (Boots x Gas burst / Rocket
    // slide) ON TOP of Cyberware + Mega speed - all multiplicative with no natural ceiling, and a
    // very high SetMoveSpeedScale clips you through geometry / desyncs nav. Clamp the TOTAL (live
    // dvar). Applied AFTER the trench slow so the clamp (a max) never masks the slow (which only
    // lowers the scale). Default 2.2 leaves a Gas-burst (x2.0) intact while capping pathological stacks.
    move_cap = getdvarfloat( "acc_move_scale_cap", 2.2 );
    if ( n_scale > move_cap ) n_scale = move_cap;

    // [acc] Mega Widow's Wine LOW-STANCE mobility (user 2026-06-25): a Mega-Widow's holder moves N times
    // faster than another player in the SAME stance - crouch 2.6x / prone 10x / last-stand (down) 15x. The
    // factor lives in player.acc_mww_stance_speed (1.0 normally; set by _acc_mega_bottles::mww_stance_speed_watch
    // off GetStance() + .laststand). Applied AFTER the base cap on purpose: the base cap guards STANDING stacks,
    // but these factors must survive (2.6x/10x/15x > the 2.2 cap). The effective ABSOLUTE speed stays sane
    // because the crouch/prone/down stance RATIOS are < 1 (a 15x crawl is still slow). A separate, higher final
    // clamp (acc_mww_speed_cap, raised to 16 to fit the 15x down) bounds a pathological item x stance stack.
    if ( isdefined( player.acc_mww_stance_speed ) && player.acc_mww_stance_speed > 1.0 )
    {
        n_scale = n_scale * player.acc_mww_stance_speed;
        mww_cap = getdvarfloat( "acc_mww_speed_cap", 16.0 );
        if ( n_scale > mww_cap ) n_scale = mww_cap;
    }

    // Crash breadcrumb (boots+slide CTD diag, user 2026-06-19): log the scale + active flags
    // immediately BEFORE the engine call, then AFTER. If the CTD is SetMoveSpeedScale, the log
    // shows "->SetMoveSpeedScale" (with the value) but never "OK".
    crash_log( player, "recompute_move_speed scale=" + n_scale + " flags=[ " + active_speed_flags( player ) + "] ->SetMoveSpeedScale" );
    player SetMoveSpeedScale( n_scale );
    crash_log( player, "recompute_move_speed SetMoveSpeedScale OK (scale=" + n_scale + ")" );
}

// ---------------------------------------------------------------------------
// Play a one-shot sound at a FIXED world position via a short-lived emitter, so a 3D alias does
// NOT attach to (and follow) a moving entity. Use for "comes from the machine" sounds (perk-buy
// jingle / Pack-a-Punch cook) when the machine ent can't be resolved: pass the BUYER's origin
// (they stand AT the machine when buying), so the sound stays put instead of trailing the player
// (user 2026-06-24: perk/PaP sounds followed the buyer because the on-player fallback plays a 3D
// alias on the moving player ent). The emitter self-deletes after the longest sound.
// ---------------------------------------------------------------------------
function play_sound_at_origin( origin, alias )
{
    if ( !isdefined( origin ) || !isdefined( alias ) || alias == "" ) return;
    e = spawn( "script_origin", origin );
    e PlaySound( alias );
    e thread acc_emitter_cleanup();
}

function acc_emitter_cleanup()   // self = the temp emitter
{
    level endon( "end_game" );
    wait 12;   // longer than any jingle / PaP cook sound
    if ( isdefined( self ) ) self Delete();
}
