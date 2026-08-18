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
// fade at its own y (slot N sits acc_msg_slot_h px below slot N-1), so they never overlap.
// (2026-08-02: shard + Mega Bottle GAINS moved to the mid-screen kill feed - slot 1 gold and
// the slot-0 shard gain line are now non-Aetherium fallbacks only; slot 0 remains the live
// generic toast for everything else.)
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
// ONCE-PER-MATCH broadcast banner (user 2026-08-01 "text like 'scientist is in the lab' /
// 'perks have moved spots'... I only want each one to show once per match. It gets annoying").
// For RECURRING-EVENT INFO lines only (boss arrivals, perk scatter) - the event's other tells
// (nameplates, boss music, moved machines) still fire every time. NOT for actionable/critical
// feedback (costs, cooldowns, damage warnings, objective status): those keep printing directly.
// String-keyed level array; resets naturally on map restart. isdefined-based check (never
// compare a possibly-undefined value with == - T7 throws). IPrintLnBold = hudelem-pool-free.
// ---------------------------------------------------------------------------
function announce_once( key, msg )
{
    if ( !isdefined( level.acc_announced ) ) level.acc_announced = [];
    if ( isdefined( level.acc_announced[ key ] ) ) return;
    level.acc_announced[ key ] = true;
    players = GetPlayers();
    for ( i = 0; i < players.size; i++ )
    {
        if ( isdefined( players[ i ] ) && isplayer( players[ i ] ) )
            players[ i ] IPrintLnBold( msg );
    }
}

// ---------------------------------------------------------------------------
// HUDELEM POOL DIAGNOSTIC (user 2026-06-28). The server hudelem pool is SHARED + FIXED; when it fills,
// hud::create* returns UNDEFINED and the widget silently does NOT draw (no crash - row_complete relies on this).
// he_check(elem,label): call right after a hud::create* - counts live allocations AND logs the exact site the
// moment one FAILS (pool full). Returns elem (pass-through): x = he_check( self createFontString(...), "label" ).
// he_free(): call on Destroy() to keep the count honest. he_log(): the on-screen channel (IPrintLnBold = pool-
// FREE, so the logger itself can't fail), rides level.acc_dev - visible in a dev build, silent in ship
// (the acc_hudelem_debug dvar was removed 2026-07-16; debug rides the one acc_dev flag). acc_he_hi = the
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
    if ( !( isdefined( level.acc_dev ) && level.acc_dev ) ) return;   // re-coupled to acc_dev 2026-07-16 (only dev/god/mock flags exist)
    players = get_all_players();
    for ( i = 0; i < players.size; i++ )
        if ( isdefined( players[ i ] ) ) players[ i ] IPrintLnBold( msg );
}

// ---------------------------------------------------------------------------
// EARLY start gate (user 2026-08-02 "the map starts before everything is loaded
// - fog/music/HUD pop in while you're already walking"): blocks until at least
// one player ENTITY exists (players connect + spawn DURING the loading
// blackscreen), which is seconds BEFORE stock lifts the fade - stock sets
// "initial_blackscreen_passed" only AFTER unfreezing controls (_zm.gsc:530).
// Level-state systems (fog, looping FX, loop sounds) started after THIS gate
// are already live the frame the screen fades in. NOT a replacement for the
// blackscreen flag where all-clients delivery matters (one-shot 2D sounds) or
// where stock load-order must finish first - those keep the flag.
// ---------------------------------------------------------------------------

function wait_players_in()
{
    while ( GetPlayers().size < 1 )
        wait 0.05;
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

// [LEVBUG-TEMP] Leviathan double-PaP forensics (user 2026-07-15: "write logs to console, I'll
// reproduce"). Timestamped IPrintLnBold ON THE PLAYER = the proven [ SCRIPTER] channel into
// console_mp.log (CLAUDE.md launch findings). Dev-gated hard so it is inert in normal play.
// REMOVE every LEVBUG-TEMP block once the axe bug is root-caused + fixed.
function levbug( player, msg )
{
    if ( !isdefined( level.acc_dev ) || !level.acc_dev ) return;
    if ( !isdefined( player ) ) return;
    player IPrintLnBold( "^3[LEVBUG " + GetTime() + "]^7 " + msg );
}

// (countlog() [COUNTLOG-TEMP] spawn-count verification helper removed 2026-07-16: it was
// deliberately ungated on-screen text that shipped to every player every boss-eligible round.
// The Glitch/Shielded count curves it verified are confirmed + retuned. Any future spawn
// diagnostics ride level.acc_dev like every other dev affordance - never a standalone dvar.)

// [LEVBUG-TEMP] safe weapon-name stringifier for the forensics lines.
function levbug_wname( w )
{
    if ( !isdefined( w ) ) return "undef";
    if ( w == level.weaponNone ) return "none";
    if ( !isdefined( w.name ) ) return "unnamed";
    return w.name;
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
// bridge/platform IS a floor - accept it; EXCEPT tagged loot-pickup models (.acc_item_id /
// .acc_shard_count), stepped through like bodies - the 2026-08-03 item-swap z-drift fix, see the
// branch below). A true miss (fraction >= 1: over a void) KEEPS the
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
            if ( i > 0 ) drops_debug( "floor-snap stepped through " + i + " body/pickup hit(s) -> floor " + tr[ "position" ] );
            return tr[ "position" ];   // world geometry = the real floor
        }
        if ( !isplayer( e ) && !( IsActor( e ) ) )
        {
            // LOOT PICKUPS ARE NEVER A FLOOR (item-swap z-drift, user 2026-08-03 "keeps moving up in
            // space"): on a swap, _acc_boss_items::watch_pickup re-drops the old carry at the grabbed
            // item's ground origin BEFORE cleanup_pickup() deletes the grabbed model, so this trace runs
            // with that model still standing on the drop point - accepting its TOP surface as "floor"
            // raised the re-drop by ~z_lift + model height, and the NEXT swap traced onto THAT raised
            // model (compounding climb; the stored acc_ground_origin was already snap-correct, this
            // branch was the leak). Pickup models are tagged (boss items: .acc_item_id / shard drops:
            // .acc_shard_count) - step through them like bodies down to the real floor.
            if ( isdefined( e.acc_item_id ) || isdefined( e.acc_shard_count ) )
            {
                start = tr[ "position" ] - ( 0, 0, 4 );
                if ( start[ 2 ] <= bottom[ 2 ] ) break;
                continue;
            }
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

// Drop/pickup debug channel, rides level.acc_dev (silent in a ship build; the
// acc_drops_debug dvar was removed 2026-07-16). Uses IPrintLnBold deliberately: it is the ONLY channel
// that reaches console_mp.log (printed there as "[ SCRIPTER] ..."); the /# #/
// dev block in log() does NOT reliably route to the log (CLAUDE.md logging truth).
// To read it: arm a dev build (level.acc_dev = true; + rebuild) and launch with +set logfile 1.
function drops_debug( msg )
{
    if ( !( isdefined( level.acc_dev ) && level.acc_dev ) ) return;   // re-coupled to acc_dev 2026-07-16 (only dev/god/mock flags exist)
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
// LAST [CRASHDBG] line in console_mp.log = the step just before the CTD. Rides level.acc_dev
// (silent in a ship build; the acc_crash_debug dvar was removed 2026-07-16). Routes via
// IPrintLnBold (the one channel that reaches console_mp.log as
// "[ SCRIPTER] ..."; the /# #/ println does not reliably). ENABLE + REPRODUCE + READ:
//   arm a dev build (level.acc_dev = true; in acc_resolve_dev_flags() + rebuild), launch with +set logfile 1,
//   reproduce the crash, then read the LAST "[CRASHDBG]" lines in <game>\console_mp.log.
function crash_log( player, msg )
{
    if ( !( isdefined( level.acc_dev ) && level.acc_dev ) ) return;   // re-coupled to acc_dev 2026-07-16 (only dev/god/mock flags exist)
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
    if ( isdefined( player.acc_speed_fade_scale ) && player.acc_speed_fade_scale > 1.0 ) f += "fade ";
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

// ---------------------------------------------------------------------------
// acc_log2 - base-2 logarithm. GSC HAS NO log/pow BUILTIN, so this is ours.
// ---------------------------------------------------------------------------
// WHY THIS EXISTS: co-op scaling needs log curves. Where the input is CLAMPED to a
// tiny domain you can dodge the math with a hardcoded switch - that is exactly what
// acc_coop_scaling::elite_count_player_mult does for players (only 1..4 are legal, so
// 3 literals cover it). But ROUND NUMBER IS UNBOUNDED, so the log-in-round elite curves
// (_acc_elites::elite_quota_for_round, _acc_boss_glitch::glitch_count_for_round) cannot
// use a switch and need a real function.
//
// METHOD: split x into 2^e * m with m in [1,2), then approximate log2(m) on that octave.
// The octave loop is exact; only the mantissa is approximated, by the quadratic
//   log2(1+f) ~ f * (A - (A-1)*f),  A = 1.339849
// which is pinned EXACT at both endpoints (f=0 -> 0, f=1 -> 1, so octave boundaries never
// drift) and pinned exact at the midpoint f=0.5 (log2(1.5)); A is derived from that midpoint
// constraint, not guessed. Verified numerically over the octave: max error 0.0087, vs 0.086
// for the obvious linear (m-1) - a 10x tightening for one multiply. Well inside the noise of
// curves whose result is int()'d into a spawn count anyway.
//
// Deliberately NOT named log2/log: acc_utility::log is ALREADY this module's debug logger
// (:135) - a `log2` next to it reads like a logging call at every callsite. Hence acc_log2.
//
// Guards: x <= 0 is undefined for a real log; callers pass round numbers / counts, so 0 is
// the only sane floor (a caller clamping to >= 1 gets 0 back, which is log2(1) = 0 anyway).
function acc_log2( x )
{
    if ( !isdefined( x ) || x <= 1 )
        return 0.0;   // log2(1) = 0; anything <= 0 is invalid input -> same floor

    e = 0;
    m = x;
    while ( m >= 2.0 )   // exact: strip whole octaves
    {
        m = m / 2.0;
        e++;
    }

    // m now in [1,2). Quadratic mantissa fit, exact at f = 0 / 0.5 / 1 (see header).
    f = m - 1.0;
    return e + ( f * ( 1.339849 - ( 0.339849 * f ) ) );
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

// PHASE SERUM aura check (shared home 2026-07-11; lifted from _acc_boss_glitch::acc_serum_suppressed
// so the Phantom can read it too - glitch already #using's phantom, so phantom #using glitch would be
// circular). True if any alive player within acc_phase_serum_radius holds the Phase Serum boss item
// (p.acc_phase_serum, set by _acc_boss_items::apply_arnie_cloak). Consumers pick their own penalty:
// Glitch Stalker = 0.456x speed + no blink; Phantom = 20.4% slower (gait only, teleports untouched).
// (user 2026-08-03: Phase Serum -15% again; 2026-07-22 -20% across the board - was 1/5 + 30%.)
function serum_aura_active( origin )
{
    radius = getdvarint( "acc_phase_serum_radius", 350 );
    if ( radius <= 0 ) return false;
    players = GetPlayers();
    for ( i = 0; i < players.size; i++ )
    {
        p = players[ i ];
        if ( !isdefined( p ) || !isplayer( p ) ) continue;
        if ( !isdefined( p.acc_phase_serum ) || !p.acc_phase_serum ) continue;   // no IS_TRUE here - this file has no shared.gsh #insert
        if ( Distance( origin, p.origin ) <= radius ) return true;
    }
    return false;
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
        n_scale = n_scale * getdvarfloat( "acc_boots_mult", 1.10 ); // Boots boss item: +10% move overall (user 2026-06-18, buffed 8%->10% 2026-07-14, docs/09; trench-slow immunity was never in code - Exo only)
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
        // +24% surge for 5s instead of a slow (flag set by _acc_elites::acc_battery_surge; user 2026-07-22:
        // +20% buffed by 20% -> 1.20 -> 1.24). While the surge
        // is active the zap applicators absorb further zaps (acc_battery_absorb_zap), so a slow flag is NOT
        // set during the boost - they never multiply against each other. (A zap during the post-surge
        // recharge CAN set a slow flag, but the boost is already cleared by then, so still no stacking.)
        n_scale = n_scale * getdvarfloat( "acc_battery_boost_mult", 1.24 );
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
        n_scale = n_scale * getdvarfloat( "acc_rocket_slide_mult", 2.0 ); // Rocket Shield: 2x while sliding (user 2026-07-15 rework: slight slide boost, was 1.75x; live dvar, docs/09)
    }
    if ( isdefined( player.acc_speed_fade_scale ) && player.acc_speed_fade_scale > 1.0 )
    {
        // Timed-buff RELEASE fade (speed_fade_release below; sole caller = the Gas Tank
        // nitro burst ending). Stands in for the flag it replaces, inside the base cap.
        // Undefined - the normal state - is a no-op.
        n_scale = n_scale * player.acc_speed_fade_scale;
    }
    // TWO active boss-item slots (docs/09) let two MOBILITY items stack (Boots x Gas burst / Rocket
    // slide) ON TOP of Cyberware + Mega speed - all multiplicative with no natural ceiling, and a
    // very high SetMoveSpeedScale clips you through geometry / desyncs nav. Clamp the BOOST TOTAL
    // (live dvar). Default 2.2 leaves a Gas-burst (x2.0) intact while capping pathological stacks.
    //
    // APPLIED BEFORE THE SLOWS (fixed 2026-07-15). It used to run AFTER them, under a comment
    // claiming that order kept the clamp from masking the slow - exactly BACKWARDS, and that
    // inverted reasoning is why this survived so long. A ceiling applied AFTER a slow is precisely
    // what DISCARDS it: min( B * 0.70, 2.2 ) and min( B, 2.2 ) are the SAME 2.2 for every boost
    // stack B >= 2.2/0.70 = 3.14, so a stacked player was SILENTLY IMMUNE to boss stuns - and the
    // stacks are trivially reachable: Rocket slide (2.0) x PhD Slider (1.75) = 3.5 (both latch on
    // the same IsSliding, so they ALWAYS co-occur), or nitro (2.0) x Rocket slide (2.0) = 4.0. It
    // swallowed the trench slow identically (free Exo coverage while sliding), and it collapsed the
    // deliberate boss-slow tuning below (anti-stack add / Mega Electric Cherry -10% softening) to
    // one indistinguishable 2.2. Capping the BOOST first means every slow multiplies a bounded
    // value and therefore always costs its full percentage: 4.0 -> cap 2.2 -> x0.70 = 1.54. That is
    // what the old comment INTENDED. The ramp/fade above stays INSIDE this ceiling (contract of
    // speed_fade_release); the Mega Widow's stance factor deliberately stays OUTSIDE it (see below).
    move_cap = getdvarfloat( "acc_move_scale_cap", 2.2 );
    if ( n_scale > move_cap ) n_scale = move_cap;
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
// TIMED-BUFF release fade. When a BIG (>=2x) timed speed buff EXPIRES, dropping its flag
// snaps the scale 2x -> 1x in one tick. This fades it to 1.0 over acc_speed_fade_decay
// seconds instead, via player.acc_speed_fade_scale - an extra factor recompute_move_speed
// multiplies in, INSIDE the base cap, so it can never exceed what the flag itself gave.
//
// SOLE CALLER: _acc_boss_items::gas_tank_burst (the 5s nitro burst ending).
//
// !! DO NOT WIRE THE SLIDE BOOSTS BACK INTO THIS (user 2026-07-15, tried + rejected on
// feel: "slide and start walking you have that speed boost but that ramp is just janky").
// A fade is right for a TIMED buff expiring on its own clock - the player's movement STATE
// is not changing, only the buff's clock ran out, so easing it out reads as intended.
// It is WRONG for a slide ENDING, because that IS a state change: the player is now
// walking, and a decaying walk-speed multiplier reads as ice, not momentum. Slide momentum
// is a VELOCITY mechanic - see _acc_movement.gsc. (Renamed from slide_carry_* 2026-07-15
// when the slide callers were removed; "slide" in the name was actively misleading.)
//
// The sub-1.2x flags (Battery surge / Savior / Flash) stay instant on purpose - their snap
// is imperceptible and not worth the moving parts.
//
// CONTRACT: a caller re-arming the SAME buff MUST speed_fade_cancel first, or the flag and
// a still-running fade multiply together. Single fade per player (stop notify).
// acc_speed_fade_decay 0 = feature off (instant drop). Neither fn recomputes on the
// set/clear tick - the caller recomputes right after, picking the change up atomically.
// ---------------------------------------------------------------------------
function speed_fade_release( player, mult )
{
    decay_sec = getdvarfloat( "acc_speed_fade_decay", 0.4 );
    if ( decay_sec < 0.05 || !isdefined( mult ) || mult <= 1.0 ) return;
    // Two callers fading the same tick: keep the strongest.
    if ( isdefined( player.acc_speed_fade_scale ) && player.acc_speed_fade_scale >= mult ) return;
    player notify( "acc_speed_fade_stop" );
    player.acc_speed_fade_scale = mult;   // synchronous - the caller's recompute sees it this tick
    player thread speed_fade_decay( decay_sec );
}

function speed_fade_cancel( player )
{
    player notify( "acc_speed_fade_stop" );
    player.acc_speed_fade_scale = undefined;
}

function speed_fade_decay( decay_sec )    // self = player
{
    self endon( "disconnect" );
    self endon( "acc_speed_fade_stop" );
    start = self.acc_speed_fade_scale;
    steps = int( decay_sec * 20 );   // one step per 50ms server frame
    if ( steps < 1 ) steps = 1;
    for ( i = 1; i <= steps; i++ )
    {
        wait( 0.05 );
        self.acc_speed_fade_scale = start + ( 1.0 - start ) * i / steps;
        recompute_move_speed( self );
    }
    self.acc_speed_fade_scale = undefined;
    recompute_move_speed( self );
}

// ---------------------------------------------------------------------------
// Play a one-shot sound at a FIXED world position via a short-lived emitter, so a 3D alias does
// NOT attach to (and follow) a moving entity. Use for "comes from the machine" sounds (perk-buy
// jingle / Pack-a-Punch cook) when the machine ent can't be resolved: pass the BUYER's origin
// (they stand AT the machine when buying), so the sound stays put instead of trailing the player
// (user 2026-06-24: perk/PaP sounds followed the buyer because the on-player fallback plays a 3D
// alias on the moving player ent). The emitter self-deletes after the longest sound.
// ---------------------------------------------------------------------------
function play_sound_at_origin( origin, alias, life_sec )
{
    if ( !isdefined( origin ) || !isdefined( alias ) || alias == "" ) return;
    e = spawn( "script_origin", origin );
    if ( !isdefined( e ) ) return;   // entity pool full - drop the sound, never throw (cyberjack:834 pattern)
    e PlaySound( alias );
    e thread acc_emitter_cleanup( life_sec );
}

function acc_emitter_cleanup( life_sec )   // self = the temp emitter
{
    level endon( "end_game" );
    if ( !isdefined( life_sec ) ) life_sec = 12;   // default sized for perk jingles / PaP cook; short-lived
                                                   // callers (phantom warps ~every 2s) pass their own so
                                                   // emitters don't pool 6-deep per boss (review 2026-07-17)
    wait life_sec;
    if ( isdefined( self ) ) self Delete();
}

// ---------------------------------------------------------------------------
// De-rez teleport burst (docs/44 workstream A, 2026-07-17). One cyan burst of the
// BO1 nixie-numbers FX (coolyer pack clone, tinted via tools/tint_numbers_efx.js)
// + a Giant teleporter zap (HB21 library), played at a POINT. Used by the Glitch
// Stalker blink + every Phantom warp (strike/retreat/chain) so the two invisible
// teleports finally READ as teleports. The numbers .efx is LOOPING (pack ships it
// that way for teleporter pads), so the burst rides a throwaway tag_origin host
// that dies after ACC_DEREZ_BURST_SEC - the same play-then-delete control the BO1
// thief used for its fx_org trail; a PlayFX'd looping fx at a bare point could
// never be stopped. Lazy fx registration = no init-order coupling for callers.
// ---------------------------------------------------------------------------
#precache( "fx", "_custom/acc/fx_acc_derez_blink" );
#precache( "fx", "_custom/acc/fx_acc_derez_blink_phantom" );
#precache( "fx", "_custom/acc/fx_acc_derez_blink_red" );
#precache( "fx", "_custom/acc/fx_acc_scientist_trail" );
#precache( "fx", "dlc0/factory/fx_teleporter_elec_strike_os" );
#precache( "fx", "dlc0/factory/fx_teleporter_elec_strike_sparks_os" );

#define ACC_DEREZ_BURST_SEC 0.5

// Idempotent registration of every de-rez/boss-fx key. PUBLIC because the Scientist plays
// level._effect["acc_sci_trail"] directly (BO1 tech_trail recipe) BEFORE its first burst -
// lazy-init inside derez_burst alone would leave that key undefined at spawn time.
function derez_register()
{
    if ( !isdefined( level._effect ) ) level._effect = [];
    if ( isdefined( level._effect[ "acc_derez" ] ) ) return;
    level._effect[ "acc_derez" ]         = "_custom/acc/fx_acc_derez_blink";
    level._effect[ "acc_derez_phantom" ] = "_custom/acc/fx_acc_derez_blink_phantom";
    level._effect[ "acc_derez_red" ]     = "_custom/acc/fx_acc_derez_blink_red";
    level._effect[ "acc_sci_trail" ]     = "_custom/acc/fx_acc_scientist_trail";
    level._effect[ "acc_derez_zap" ]     = "dlc0/factory/fx_teleporter_elec_strike_os";
    level._effect[ "acc_derez_sparks" ]  = "dlc0/factory/fx_teleporter_elec_strike_sparks_os";
}

function derez_burst( origin, style )
{
    if ( !isdefined( origin ) ) return;
    if ( !isdefined( style ) ) style = "glitch";   // default = cyan Glitch burst (existing callers pass 1 arg)
    derez_register();
    level thread derez_burst_run( origin, style );
}

function derez_burst_run( origin, style )
{
    // NO level endon("end_game") here, deliberately (review 2026-07-17): the thread lives 0.5s max,
    // and an endon killing it mid-wait would orphan the host script_model with the LOOPING numbers
    // FX playing through the whole game-over screen. Letting the wait finish guarantees cleanup.
    // ZAP via a tag-origin HOST (fixed 2026-07-18): this was a bare `PlayFX( fx, origin )`, which
    // does NOT render in this build (the _acc_perk_lights.gsc:6-15 rule - five modules carry the
    // warning) - the zap layer had been silently invisible under the numbers. PlayFxOnTag on a
    // spawned host is the proven server-side pattern (cyberjack tesla / scientist trail / the
    // numbers below). Same fix for the phantom sparks layer.
    // DIGIT GLYPHS ARE SCIENTIST-EXCLUSIVE (user 2026-08-02 "that fx is only for scientists so
    // why does the phantom and possibly glitches have it" - supersedes the docs/44 per-boss
    // numbers-color language): only the "scientist" style (red) and the WORLD-teleport default
    // (cyan - Lab/Exchange pads, perk-scatter moves; not a boss identity) spawn the nixie
    // numbers host. Boss styles "phantom" / "glitch_boss" are numbers-FREE - their warps still
    // READ as teleports via the zap/sparks layers. The yellow numbers .efx + acc_derez_phantom
    // key stay registered (zero-cost, easy restore).
    numbers_key = "acc_derez";                                   // cyan (world teleports / legacy default)
    if ( style == "phantom" )
    {
        // Phantom warp = zap + sparks, NO digits (the sparks layer keeps the REAL boss reading
        // bigger than a Glitch blink).
        numbers_key = undefined;
        level thread play_fx_burst( "acc_derez_zap", origin, 1.0 );
        level thread play_fx_burst( "acc_derez_sparks", origin, 1.0 );
    }
    else if ( style == "glitch_boss" )
    {
        // Glitch Stalker combat blink = zap only, NO digits.
        numbers_key = undefined;
        level thread play_fx_burst( "acc_derez_zap", origin, 1.0 );
    }
    else if ( style == "scientist" )
    {
        // RED numbers ONLY - NO zap layer (user 2026-07-18 "I still hear him trying to
        // teleport"): fx_teleporter_elec_strike_os EMBEDS the Giant teleporter sound
        // (elemSpawnSound/elemFollowSound in the .efx), so any zap on the Scientist literally
        // plays a teleport sound. Teleport sight AND sound belong to the Glitch/Phantom only.
        numbers_key = "acc_derez_red";
    }
    else
    {
        level thread play_fx_burst( "acc_derez_zap", origin, 1.0 );   // world teleports: zap + cyan numbers
    }
    if ( !isdefined( numbers_key ) ) return;                     // numbers-free boss style - zap/sparks threads self-clean
    host = Spawn( "script_model", origin + ( 0, 0, 36 ) );       // numbers at torso height, not the feet
    if ( !isdefined( host ) ) return;                            // entity pool full - skip the numbers, keep the zap
    host SetModel( "tag_origin" );
    PlayFxOnTag( level._effect[ numbers_key ], host, "tag_origin" );
    wait ACC_DEREZ_BURST_SEC;
    if ( isdefined( host ) ) host Delete();
}

// ---------------------------------------------------------------------------
// Play a level._effect fx AT A WORLD POINT the way that actually renders in this build:
// PlayFxOnTag on a throwaway tag_origin host, deleted after life_sec. Bare `PlayFX( fx, origin )`
// does NOT render here (the _acc_perk_lights.gsc:6-15 rule); this is the shared server-side
// primitive for one-shot point FX (derez zap/sparks, the teleporter charge/flash/kino beam...).
// life_sec must outlive a one-shot fx's visual (cutting a LOOPING fx short is the feature).
// NO endon(end_game) - the thread is short and must finish to guarantee the host delete.
// ---------------------------------------------------------------------------
function play_fx_burst( fx_key, origin, life_sec )
{
    if ( !isdefined( level._effect ) || !isdefined( level._effect[ fx_key ] ) ) return;
    if ( !isdefined( life_sec ) ) life_sec = 1.0;
    host = Spawn( "script_model", origin );
    if ( !isdefined( host ) ) return;                            // entity pool full - drop the fx, never throw
    host SetModel( "tag_origin" );
    PlayFxOnTag( level._effect[ fx_key ], host, "tag_origin" );
    wait life_sec;
    if ( isdefined( host ) ) host Delete();
}
