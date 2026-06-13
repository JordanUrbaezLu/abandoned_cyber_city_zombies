// =============================================================================
// _acc_health_bars.gsc - player health bar + boss health bar/nameplate
//
// (1) Player bar: a per-player hud bar that tracks self.health / GetMaxHealth,
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

    // createBar is called ON the player -> newClientHudElem(self): per-player.
    p.acc_hp_bar = p hud::createBar( ( 0.2, 0.85, 0.25 ), ACC_PLAYER_BAR_W, ACC_PLAYER_BAR_H );
    p.acc_hp_bar hud::setPoint( "BOTTOM_LEFT", "BOTTOM_LEFT", 14, -88 );
    p.acc_hp_bar.alpha = 0.85;
    p.acc_hp_bar.hidewheninmenu = true;

    p.acc_hp_label = p hud::createFontString( "default", 1.0 );
    p.acc_hp_label hud::setPoint( "BOTTOM_LEFT", "BOTTOM_LEFT", 14, -100 );
    p.acc_hp_label.color = ( 1, 1, 1 );
    p.acc_hp_label.alpha = 0.7;
    p.acc_hp_label.hidewheninmenu = true;
    p.acc_hp_label SetText( "^7HEALTH" );
}

function update_player_bar( p )
{
    if ( !isdefined( p.acc_hp_bar ) ) return;

    maxhp = p GetMaxHealth();
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

function boss_bar_track( boss, name )
{
    level endon( "end_game" );

    if ( !isdefined( name ) ) name = "BOSS";

    // createServerBar -> newHudElem: every co-op player sees one shared bar.
    bar = hud::createServerBar( ( 0.9, 0.12, 0.12 ), ACC_BOSS_BAR_W, ACC_BOSS_BAR_H );
    bar hud::setPoint( "TOP", "TOP", 0, 34 );
    bar.alpha = 0.95;

    label = hud::createServerFontString( "default", 1.4 );
    label hud::setPoint( "BOTTOM", "TOP", 0, 30 );
    label SetText( "^1" + name );
    label.alpha = 0.95;

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
