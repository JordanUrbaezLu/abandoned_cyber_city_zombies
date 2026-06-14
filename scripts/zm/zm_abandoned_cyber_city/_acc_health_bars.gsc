// =============================================================================
// _acc_health_bars.gsc - player health bar + boss health bar/nameplate
//
// (1) Player bar: a per-player hud bar that tracks self.health / self.maxhealth,
//     recolored green->amber->red so you can see when you're one hit from down.
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

#namespace acc_health_bars;

function init()
{
    acc_utility::log( "health_bars: init" );
    level thread player_bars_loop();
    level thread boss_bar_listener();
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

    p.acc_hp_bar = p hud::createBar( ( 0.2, 0.85, 0.25 ), ACC_PLAYER_BAR_W, ACC_PLAYER_BAR_H );
    p.acc_hp_bar hud::setPoint( "TOP_LEFT", "TOP_LEFT", 16, 32 );
    p.acc_hp_bar.alpha = 0.85;
    p.acc_hp_bar.hidewheninmenu = true;
}

function update_player_bar( p )
{
    if ( !isdefined( p.acc_hp_bar ) ) return;

    maxhp = p.maxhealth; // BO3 player max-HP field (Jug etc. update it)
    if ( !isdefined( maxhp ) || maxhp <= 0 ) maxhp = 100;
    frac = p.health / maxhp;
    if ( frac < 0 ) frac = 0;
    if ( frac > 1 ) frac = 1;

    p.acc_hp_bar hud::updateBar( frac );
    // createBar returns the BG; the colored fill is .bar - recolor THAT.
    if ( isdefined( p.acc_hp_bar.bar ) )
        p.acc_hp_bar.bar.color = hp_color( frac );
}

function hp_color( frac )
{
    if ( frac > 0.66 ) return ( 0.2, 0.85, 0.25 ); // green
    if ( frac > 0.33 ) return ( 0.95, 0.8, 0.15 ); // amber
    return ( 0.9, 0.12, 0.12 );                     // red - one hit from down
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
        if ( isdefined( boss ) )
            level thread boss_bar_track( boss, name );
    }
}

// Boss health = TWO pieces, per player:
//   (1) A real DEPLETING bar at top-center of the screen (remaining/max). This
//       reuses the SAME proven path as the working player health bar -
//       hud::createBar (bg + .bar fill, sized by hud::updateBar). It's the
//       genre-standard boss bar and it actually shrinks (a SCREEN elem is NOT a
//       waypoint, so its width can change - unlike an over-entity waypoint icon).
//   (2) A small colored MARKER that follows the boss in world space so you can
//       tell WHICH zombie is the boss. This one is a waypoint icon, so it can
//       only recolor (waypoint icons are fixed-size + SetShader resets the
//       anchor); the depleting happens on the screen bar above, not here.
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

    while ( isdefined( boss ) && isalive( boss ) && isdefined( boss.health ) && boss.health > 0 )
    {
        frac = boss.health / boss.maxhealth;
        if ( frac < 0 ) frac = 0;
        if ( frac > 1 ) frac = 1;
        col = boss_hp_color( frac );

        for ( i = 0; i < sets.size; i++ )
        {
            s = sets[ i ];
            if ( !isdefined( s ) ) continue;

            // (1) Screen bar - the real depleting health bar.
            if ( isdefined( s.screen_bar ) )
            {
                s.screen_bar hud::updateBar( frac );
                if ( isdefined( s.screen_bar.bar ) )
                    s.screen_bar.bar.color = col;
            }

            // (2) Over-boss marker - recolor only (it's a waypoint, fixed-size).
            if ( isdefined( s.marker ) )
                s.marker.color = col;
        }
        wait 0.1;
    }

    for ( i = 0; i < sets.size; i++ )
        destroy_boss_bar_set( sets[ i ] );
}

// Screen bar + name label + over-boss marker, for one `player`.
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

    // (2) Over-boss marker icon. Set the shader ONCE (no per-frame SetShader, so
    // the waypoint anchor never resets); the loop only recolors it.
    marker = NewClientHudElem( player );
    marker.archived = false;
    marker.alignX = "center"; marker.alignY = "middle";
    marker.x = 0; marker.y = 0; marker.z = 76;
    marker.color = boss_hp_color( 1.0 ); marker.alpha = 1.0;
    marker SetShader( "white", ACC_BOSS_OH_W, ACC_BOSS_OH_H );
    marker SetWaypoint( false );
    marker SetTargetEnt( boss );
    s.marker = marker;

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
    if ( isdefined( s.marker ) ) s.marker Destroy();
}
