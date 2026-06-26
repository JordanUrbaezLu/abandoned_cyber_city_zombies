// =============================================================================
// _acc_health_bars.gsc - player health bar + boss health bar/nameplate
//
// (1) Player bar: a per-player hud bar that tracks self.health / self.maxhealth,
//     recolored green->amber->red so you can see when you're one hit from down,
//     plus a numeric "current / max" readout to its right (same recolor).
// (2) Boss bar: a shared (server) bar + name label at the top of the screen
//     while a boss is alive, driven by the "acc_boss_spawned" notify that
//     _acc_boss.gsc emits, hidden on the boss's death.
//
// Stock precedents (tmp/bo3_stock_ref): hud::createBar/updateBar = the vehicle
// health bar (_vehicle.gsc:647) + craftable progress bar (_zm_craftables.gsc).
// createBar() returns the BACKGROUND elem; the colored FILL is elem.bar.
// =============================================================================

#using scripts\shared\flag_shared;
#using scripts\shared\hud_util_shared;
#using scripts\shared\util_shared;

#insert scripts\shared\shared.gsh;

#using scripts\zm\zm_abandoned_cyber_city\_acc_utility;

#define ACC_PLAYER_BAR_W 120
#define ACC_PLAYER_BAR_H 9
#define ACC_BOSS_BAR_W   340
#define ACC_BOSS_BAR_H   14
#define ACC_BOSS_OH_W    80   // overhead (world-space) boss bar width, px
#define ACC_BOSS_OH_H    7    // overhead (world-space) boss bar height, px
#define ACC_WH_MARKER_SIZE 2  // zombie wallhack marker px (was 10; ~90% smaller per user 2026-06-17)

#namespace acc_health_bars;

function init()
{
    acc_utility::log( "health_bars: init" );
    level thread player_bars_loop();
    level thread boss_bar_listener();
    // Through-walls zombie waypoints are a DEV/QA aid only - gate on the one dev switch so a ship
    // build never shows them (was hardcoded-on; user 2026-06-22, one-flag migration).
    if ( IS_TRUE( level.acc_dev ) )
        level thread zombie_wallhack_loop();
}

// ---------------------------------------------------------------------------
// Player health bar (per player)
// ---------------------------------------------------------------------------

function player_bars_loop()
{
    level endon( "end_game" );
    level flag::wait_till( "initial_blackscreen_passed" );

    for ( ;; )
    {
        players = GetPlayers();
        for ( i = 0; i < players.size; i++ )
        {
            p = players[ i ];
            if ( !isdefined( p ) || !isplayer( p ) ) continue;
            ensure_player_bar( p );
            update_player_bar( p );
        }
        wait 0.1;
    }
}

function ensure_player_bar( p )
{
    if ( isdefined( p.acc_hp_bar ) ) return;

    // Top-left of screen. createBar is called ON the player -> per-player elem.
    p.acc_hp_label = p hud::createFontString( "default", 1.0 );
    p.acc_hp_label hud::setPoint( "TOP_LEFT", "TOP_LEFT", 16, 16 );
    p.acc_hp_label.alignX = "left";
    p.acc_hp_label.alignY = "top";
    p.acc_hp_label.color = ( 1, 1, 1 );
    p.acc_hp_label.alpha = 0.7;
    p.acc_hp_label.hidewheninmenu = true;
    p.acc_hp_label SetText( "^7HEALTH" );

    make_player_bar( p, bar_width_for_hp( player_maxhp( p ) ) );

    // HP NUMERIC READOUT REMOVED (docs/50 D1, user 2026-06-22): the "current / max" text leaked the
    // Juggernog magnitude as a NUMBER. The bar now conveys the same thing VISUALLY (user 2026-06-24): its
    // WIDTH scales with max HP and its GREEN SHADE deepens with the Jug tier (see make_player_bar / hp_bar_color).
}

// Player max HP (Jug etc. update p.maxhealth; default 100 before it's set).
function player_maxhp( p )
{
    if ( !isdefined( p.maxhealth ) || p.maxhealth <= 0 ) return 100;
    return p.maxhealth;
}

// Bar WIDTH from max HP (user 2026-06-24): 1 px / HP by default -> no-Jug 100 / Jug 250 / Mega-Jug 300,
// so buying Jug visibly WIDENS the bar. Floored at 60, capped (acc_hp_bar_max_w, default 360) so a stacked
// max-health item can't run it off-screen. Live dvars acc_hp_bar_px_per_hp / acc_hp_bar_max_w.
function bar_width_for_hp( maxhp )
{
    w = int( maxhp * getdvarfloat( "acc_hp_bar_px_per_hp", 1.0 ) );
    if ( w < 60 ) w = 60;
    cap = getdvarint( "acc_hp_bar_max_w", 360 );
    if ( w > cap ) w = cap;
    return w;
}

// (Re)create the player HP bar at width w. createBar BAKES the width into the bg + fill, so a max-HP change
// = a rebuild (rare: only on a Jug/Mega buy, a max-health item, or perk loss on death - NOT every poll).
function make_player_bar( p, w )
{
    if ( isdefined( p.acc_hp_bar ) )
    {
        if ( isdefined( p.acc_hp_bar.bar ) ) p.acc_hp_bar.bar Destroy();
        p.acc_hp_bar Destroy();
    }
    p.acc_hp_bar = p hud::createBar( ( 0.25, 0.90, 0.30 ), w, ACC_PLAYER_BAR_H );
    p.acc_hp_bar hud::setPoint( "TOP_LEFT", "TOP_LEFT", 16, 32 );
    p.acc_hp_bar.alpha = 0.85;
    p.acc_hp_bar.hidewheninmenu = true;
    p.acc_hp_bar_w = w;
}

function update_player_bar( p )
{
    if ( !isdefined( p.acc_hp_bar ) ) return;

    maxhp = player_maxhp( p );

    // WIDTH scales with MAX health (user 2026-06-24): a Jug / Mega-Jug buy (or a max-health item) visibly
    // WIDENS the bar so the extra health is readable at a glance. createBar bakes the width, so REBUILD only
    // when the target width changes (a perk/max-health change), never per poll.
    want_w = bar_width_for_hp( maxhp );
    if ( !isdefined( p.acc_hp_bar_w ) || p.acc_hp_bar_w != want_w )
        make_player_bar( p, want_w );

    frac = p.health / maxhp;
    if ( frac < 0 ) frac = 0;
    if ( frac > 1 ) frac = 1;

    // Smooth: SLIDE the fill to the new health instead of snapping (was hud::updateBar).
    acc_set_bar_smooth( p.acc_hp_bar, frac, 0.25 );
    // createBar returns the BG; the colored fill is .bar - recolor THAT (by Jug tier).
    if ( isdefined( p.acc_hp_bar.bar ) )
        p.acc_hp_bar.bar.color = hp_bar_color( p, frac );
}

// Bar fill colour. GREEN SHADE by Juggernog tier (user 2026-06-24) so the bar SHOWS the perk benefit:
// no Jug = bright green, Jug = darker green, Mega Jug = darkest green. A critical-HP RED override stays
// (<=33% = one hit from down) so the death warning isn't lost. The Mega flag is read straight off the
// player field (player.acc_mega_perks, owned by _acc_mega_bottles) to avoid a cross-module #using.
function hp_bar_color( player, frac )
{
    if ( frac <= 0.33 ) return ( 0.90, 0.12, 0.12 );                                 // critical - about to go down
    if ( isdefined( player.acc_mega_perks ) && IS_TRUE( player.acc_mega_perks[ "specialty_armorvest" ] ) )
        return ( 0.05, 0.30, 0.08 );                                                 // Mega Jug - darkest green
    if ( player HasPerk( "specialty_armorvest" ) )
        return ( 0.10, 0.52, 0.14 );                                                 // Jug - darker green
    return ( 0.25, 0.90, 0.30 );                                                     // no Jug - bright green
}

// Smoothly SLIDE a stock createBar fill to `frac` over `dur` seconds instead of the instant
// width snap stock hud::updateBar does (it setShaders the fill to the new width every call).
// We drive the fill HudElem (.bar) with scaleOverTime - the SAME engine call stock
// updateBarScale uses for its rateOfChange path (hud_util_shared.gsc) - so the bar GLIDES to
// the new value rather than jumping. The first touch snaps (establishes the size); after that
// every change animates. Re-issues only when the target width actually changes, so a fast
// poll calling this each tick is cheap and doesn't restart the glide on no-ops.
function acc_set_bar_smooth( bar_bg, frac, dur )
{
    if ( !isdefined( bar_bg ) || !isdefined( bar_bg.bar ) ) return;
    if ( frac < 0 ) frac = 0;
    if ( frac > 1 ) frac = 1;
    if ( !isdefined( dur ) || dur <= 0 ) dur = 0.25;

    fill = bar_bg.bar;
    target_w = int( bar_bg.width * frac + 0.5 );
    if ( target_w < 1 ) target_w = 1;

    if ( !isdefined( fill.acc_shown_w ) )
    {
        // First touch: snap to the current width so the glide starts from the right place.
        fill setShader( fill.shader, target_w, bar_bg.height );
        fill.acc_shown_w = target_w;
        fill.frac = frac;
        return;
    }
    if ( fill.acc_shown_w == target_w ) return;   // unchanged -> don't restart the slide

    fill scaleOverTime( dur, target_w, bar_bg.height );
    fill.acc_shown_w = target_w;
    fill.frac = frac;
}

// ---------------------------------------------------------------------------
// Boss health bar + nameplate (shared / server)
// ---------------------------------------------------------------------------

function boss_bar_listener()
{
    level endon( "end_game" );
    for ( ;; )
    {
        level waittill( "acc_boss_spawned", boss, name );
        // PARADISE FINALE (user 2026-06-25): suppress the boss HUD for the whole onslaught - a Phantom spawns
        // every minute and would spam boss bars/nameplates over the survival countdown. The gate is the level
        // flag level.acc_paradise_onslaught (set by _acc_paradise::start_onslaught).
        if ( IS_TRUE( level.acc_paradise_onslaught ) )
            continue;
        if ( isdefined( boss ) )
            level thread boss_bar_track( boss, name );
    }
}

// Boss health bar (per player): a real DEPLETING bar + name label at top-center of the
// screen (remaining/max), reusing the SAME proven path as the player health bar -
// hud::createBar (bg + .bar fill, sized by hud::updateBar). A SCREEN elem (not a
// waypoint) can actually shrink in width. The over-boss world marker was removed per
// user request - just the top bar now.
function boss_bar_track( boss, name )
{
    level endon( "end_game" );
    if ( !isdefined( boss ) ) return;
    if ( !isdefined( name ) ) name = "BOSS";
    if ( !isdefined( boss.maxhealth ) || boss.maxhealth <= 0 ) boss.maxhealth = boss.health;

    sets = [];
    players = GetPlayers();
    for ( i = 0; i < players.size; i++ )
        sets[ sets.size ] = make_boss_bar_set( players[ i ], boss, name );

    // Also self-destroys the bar the instant the Paradise onslaught begins, so any boss bar already showing
    // when the finale starts is cleared too (user 2026-06-25).
    while ( isdefined( boss ) && isalive( boss ) && isdefined( boss.health ) && boss.health > 0
            && !IS_TRUE( level.acc_paradise_onslaught ) )
    {
        frac = boss.health / boss.maxhealth;
        if ( frac < 0 ) frac = 0;
        if ( frac > 1 ) frac = 1;
        col = boss_hp_color( frac );

        for ( i = 0; i < sets.size; i++ )
        {
            s = sets[ i ];
            if ( !isdefined( s ) ) continue;

            // (1) Screen bar - the real depleting health bar. Smooth: SLIDE to the new
            // value instead of snapping (was hud::updateBar).
            if ( isdefined( s.screen_bar ) )
            {
                acc_set_bar_smooth( s.screen_bar, frac, 0.25 );
                if ( isdefined( s.screen_bar.bar ) )
                    s.screen_bar.bar.color = col;
            }
        }
        wait 0.1;
    }

    for ( i = 0; i < sets.size; i++ )
        destroy_boss_bar_set( sets[ i ] );
}

// Screen bar + name label, for one `player`.
function make_boss_bar_set( player, boss, name )
{
    s = SpawnStruct();

    // (1) Name label, top-center.
    s.label = player hud::createFontString( "objective", 1.5 );
    s.label hud::setPoint( "TOP", "TOP", 0, 22 );
    s.label.alignX = "center"; s.label.alignY = "top";
    s.label.color = ( 1, 0.85, 0.2 ); s.label.alpha = 0.95;
    s.label.hidewheninmenu = true;
    s.label SetText( "^1" + name );

    // (1) Depleting bar, top-center, just under the name (proven createBar path).
    s.screen_bar = player hud::createBar( boss_hp_color( 1.0 ), ACC_BOSS_BAR_W, ACC_BOSS_BAR_H );
    s.screen_bar hud::setPoint( "TOP", "TOP", 0, 46 );
    s.screen_bar.alpha = 0.9;
    s.screen_bar.hidewheninmenu = true;

    return s;
}

// Boss bar tint: green (healthy) -> amber -> red (nearly dead).
function boss_hp_color( frac )
{
    if ( frac > 0.66 ) return ( 0.25, 0.9, 0.3 );
    if ( frac > 0.33 ) return ( 0.95, 0.78, 0.15 );
    return ( 0.95, 0.12, 0.12 );
}

function destroy_boss_bar_set( s )
{
    if ( !isdefined( s ) ) return;
    if ( isdefined( s.label ) ) s.label hud::destroyElem();
    if ( isdefined( s.screen_bar ) ) s.screen_bar hud::destroyElem();
}

// ---------------------------------------------------------------------------
// Zombie wallhack markers (QA: see every zombie through walls, incl. stuck ones)
// ---------------------------------------------------------------------------
// HARDCODED ON (user 2026-06-17): a small red through-walls waypoint floats over every live
// zombie so a stuck / broken-pathing one is always findable. Same proven HudElem recipe as the
// dev door markers (_acc_dev::create_door_marker): NewClientHudElem + SetShader("white",..) +
// SetWaypoint(true) + SetTargetEnt(zombie). "white" is an engine built-in material (no
// missing-asset risk). NOT behind a flag, per request. TODO(ship): remove before a public build.
//
// Discovery loop tags each new zombie once (z.acc_wh_tagged) and hands it to a LEVEL-scoped
// per-zombie manager (level thread, NOT a thread ON the zombie - so it survives the corpse being
// removed and can still destroy the player-owned HudElems).
function zombie_wallhack_loop()
{
    level endon( "end_game" );
    level flag::wait_till( "initial_blackscreen_passed" );

    for ( ;; )
    {
        team = ( isdefined( level.zombie_team ) ? level.zombie_team : "axis" );
        zombies = GetAITeamArray( team );
        for ( i = 0; i < zombies.size; i++ )
        {
            z = zombies[ i ];
            if ( !isdefined( z ) || !isalive( z ) ) continue;
            if ( IS_TRUE( z.acc_wh_tagged ) ) continue;   // already managed
            z.acc_wh_tagged = true;
            level thread zombie_wallhack_one( z );
        }
        wait 0.5;
    }
}

// One through-walls marker per connected player; refreshes for co-op late joins; destroys all
// markers once the zombie is dead/removed. markers[] is keyed by the player's entity number and
// kept LOCAL so cleanup works even after `zombie` goes undefined.
function zombie_wallhack_one( zombie )
{
    level endon( "end_game" );

    markers = [];
    while ( isdefined( zombie ) && isalive( zombie ) )
    {
        players = GetPlayers();
        for ( i = 0; i < players.size; i++ )
        {
            p = players[ i ];
            if ( !isdefined( p ) || !isplayer( p ) ) continue;
            key = p GetEntityNumber();
            if ( isdefined( markers[ key ] ) ) continue;
            markers[ key ] = create_zombie_marker( p, zombie );
        }
        wait 1;
    }

    keys = GetArrayKeys( markers );
    for ( i = 0; i < keys.size; i++ )
        if ( isdefined( markers[ keys[ i ] ] ) )
            markers[ keys[ i ] ] Destroy();
}

// Red square that tracks the zombie and shows through walls (off-screen arrow points toward it).
// "white" is the engine built-in material, tinted by .color.
function create_zombie_marker( player, zombie )
{
    elem = NewClientHudElem( player );
    elem.archived = false;
    elem.x = 0;
    elem.y = 0;
    elem.z = 64;                       // float above the zombie's origin
    elem.alpha = 0.85;
    elem.color = ( 1.0, 0.25, 0.18 );  // red = enemy
    elem SetShader( "white", ACC_WH_MARKER_SIZE, ACC_WH_MARKER_SIZE );  // small locator dot
    elem SetWaypoint( true );          // constant on-screen size + edge arrow when offscreen
    elem SetTargetEnt( zombie );
    return elem;
}
