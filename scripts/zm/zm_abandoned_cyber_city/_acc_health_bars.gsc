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

// Overhead bar + name that FOLLOW the boss in world space (above its head). Built
// from RAW NewClientHudElem PER PLAYER (the stock entityheadicons follow pattern:
// world .z offset + SetWaypoint(false) + SetTargetEnt) - NOT hud::createServerBar /
// createServerFontString, which setParent the elems to the SCREEN layer and clamp
// the bar to the top of the screen (the bug hit twice). The bar is a "white" fill
// icon whose WIDTH is scaled by the health fraction (stock updateBarScale math); a
// dark bg sits behind it; the name is a text elem. Per-player NewClientHudElem
// matches our working door markers (create_door_marker in _acc_dev.gsc).
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
        w = int( ACC_BOSS_OH_W * frac );
        if ( w < 1 ) w = 1;
        for ( i = 0; i < sets.size; i++ )
        {
            if ( isdefined( sets[ i ].fill ) )
                sets[ i ].fill SetShader( "white", w, ACC_BOSS_OH_H );
        }
        wait 0.1;
    }

    for ( i = 0; i < sets.size; i++ )
        destroy_boss_bar_set( sets[ i ] );
}

// One bg + colored fill + name elem set, all following the boss for `player`.
function make_boss_bar_set( player, boss, name )
{
    s = SpawnStruct();

    // ONE red "health bar" icon over the boss. Last test: a black bg + red fill at the
    // SAME world target rendered as just the black box - overlapping world-space waypoints
    // don't layer reliably, so we use a SINGLE elem. Its WIDTH = the health fraction, so
    // the bar shrinks as the boss dies. (No text name - text can't render on a world elem.)
    fill = NewClientHudElem( player );
    fill.archived = false;
    fill.alignX = "center"; fill.alignY = "middle";
    fill.x = 0; fill.y = 0; fill.z = 76;
    fill.color = ( 0.95, 0.12, 0.12 ); fill.alpha = 1.0;
    fill SetShader( "white", ACC_BOSS_OH_W, ACC_BOSS_OH_H );
    fill SetWaypoint( false );
    fill SetTargetEnt( boss );

    s.fill = fill;
    return s;
}

function destroy_boss_bar_set( s )
{
    if ( isdefined( s.fill ) ) s.fill Destroy();
}
