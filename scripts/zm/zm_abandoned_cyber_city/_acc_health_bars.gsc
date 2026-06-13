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

// Overhead bar + name that FOLLOW the boss in world space (above its head),
// not a fixed top-of-screen bar. SetWaypoint(false) = 3D world placement;
// elem.z is the height offset above the entity origin (entityheadicons pattern).
function boss_bar_track( boss, name )
{
    level endon( "end_game" );
    if ( !isdefined( boss ) ) return;
    if ( !isdefined( name ) ) name = "BOSS";

    bar = hud::createServerBar( ( 0.9, 0.12, 0.12 ), 96, 7 );
    bar.alignX = "center";
    bar.alignY = "middle";
    bar.x = 0; bar.y = 0; bar.z = 76; // above the head
    bar SetWaypoint( false );
    bar SetTargetEnt( boss );
    bar.alpha = 0.95;

    label = hud::createServerFontString( "default", 1.0 );
    label.alignX = "center";
    label.alignY = "middle";
    label.x = 0; label.y = 0; label.z = 88;
    label SetWaypoint( false );
    label SetTargetEnt( boss );
    label.color = ( 1.0, 0.35, 0.35 );
    label.alpha = 0.95;
    label SetText( "^1" + name );

    while ( isdefined( boss ) && isalive( boss ) && isdefined( boss.health ) && boss.health > 0 )
    {
        maxh = ( isdefined( boss.maxhealth ) && boss.maxhealth > 0 ? boss.maxhealth : boss.health );
        frac = boss.health / maxh;
        if ( frac < 0 ) frac = 0;
        if ( frac > 1 ) frac = 1;
        bar hud::updateBar( frac );
        wait 0.1;
    }

    if ( isdefined( bar ) )   bar hud::destroyElem();
    if ( isdefined( label ) ) label hud::destroyElem();
}
