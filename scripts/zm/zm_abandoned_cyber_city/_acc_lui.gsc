// =============================================================================
// _acc_lui.gsc - LUI client pipeline FOUNDATION (server half)
//
// Stands up the map's custom LUI HUD overlay (ui/uieditor/menus/hud/acc_hud.lua)
// and the clientuimodel data bridge that drives it. This is the substrate every
// future premium-UI touchpoint rides on (perk-icon glow, Data Shards counter,
// Cyberware indicators, boss bar - see docs/27_ui_plan.md, docs/28_lui_pipeline.md).
//
// Pattern (verified vs stock _zm_perk_deadshot.gsc/.csc + shipped usermaps
// zm_alien_isolation / zm_building / zm_countryside): REGISTER_SYSTEM so the
// clientfield registers at the correct pre-load phase, IN LOCKSTEP with the .csc
// mirror (_acc_lui.csc) - a gsc/csc registration order/width mismatch corrupts
// the field and hangs the load. Server registers + sets; client only mirrors the
// registration (no callback). clientuimodel scope is auto-piped to the LUI model.
// =============================================================================

#using scripts\shared\callbacks_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\flag_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;
#using scripts\shared\ai\zombie_utility;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#using scripts\zm\zm_abandoned_cyber_city\_acc_utility;
#using scripts\zm\zm_abandoned_cyber_city\_acc_mega_bottles;

#precache( "lui_menu", "acc_hud" );

#namespace acc_lui;

REGISTER_SYSTEM( "acc_lui", &__init__, undefined )

function __init__()
{
    // Must match the .csc mirror EXACTLY (scope/name/version/bits/type) AND in the
    // SAME ORDER - the bit layout is assigned in registration order.
    clientfield::register( "clientuimodel", "accLuiTest", VERSION_SHIP, 4, "int" );
    // Perk/PaP info card selector: code = perkIndex*4 + mode (0 = hide), +64 when the
    // viewing player holds The Armory (Mule Kick Mega) so the card shows the 10%-off
    // price. Max 10*4+3+64 = 107 -> 7 bits. Decoded + rendered by acc_hud.lua.
    clientfield::register( "clientuimodel", "accPerkCard", VERSION_SHIP, 7, "int" );
    // Pack-a-Punch current tier (0..5) of the held weapon, pushed when near PaP so
    // the card shows only the NEXT tier (not the whole ladder). 3 bits (0..7).
    clientfield::register( "clientuimodel", "accPapTier", VERSION_SHIP, 3, "int" );
    // Mega-perk bitmask: bit i set => the perk at bar-bit i is Mega'd (perk_state_watch
    // order). 9 bits (9 perks; PhD Flopper bit 8). acc_hud.lua tints the matching
    // perk-bar icon teal.
    clientfield::register( "clientuimodel", "accMegaMask", VERSION_SHIP, 9, "int" );
    // Damage number: value = min(dmg,99999)*2 + parity. acc_hud.lua shows it near
    // the crosshair (you aim at the zombie, so it reads on-target). The parity bit
    // flips every push so an identical number still re-triggers the popup. 18 bits.
    clientfield::register( "clientuimodel", "accDmgNum", VERSION_SHIP, 18, "int" );
    // Owned-perk bitmask: bit i set => the player OWNS the perk at bar-bit i
    // (perk_state_watch order), regardless of Mega. Pairs with accMegaMask so the LUI
    // overlay can pick the icon: owned+mega => teal (Mega), owned+!mega => red (base),
    // !owned => hide. 9 bits (9 perks). Driven by perk_state_watch(). Appended LAST so
    // the existing fields' bit layout is untouched (must match _acc_lui.csc order).
    clientfield::register( "clientuimodel", "accOwnedMask", VERSION_SHIP, 9, "int" );
    // Power-up active bitmask: bit 0 = Insta-Kill, bit 1 = Double Points, bit 2 = Fire Sale
    // (TIMED, shown while active), bit 3 = Nuke, bit 4 = Max Ammo, bit 5 = Carpenter, bit 6 =
    // Random Perk / free_perk (INSTANT, flashed 3s on pickup). Driven by powerup_state_watch() off
    // the stock zombie_vars + the pickup-flash stamps; acc_hud.lua CoD.AccPowerupBar shows the
    // matching Ronan icon. 7 bits. Appended LAST so the existing fields' bit layout is untouched
    // (MUST match _acc_lui.csc order/width).
    clientfield::register( "clientuimodel", "accPowerupMask", VERSION_SHIP, 7, "int" );
    // Round-progress bar (upper-right): fill PERCENT 0..100 (full at round start, drains to 0
    // as the round's zombies die). 7 bits (0..127). Appended LAST so existing fields' bit
    // layout is untouched (MUST match _acc_lui.csc order/width). NOTE: kept to 7 bits because
    // the clientuimodel clientfield pool is nearly full - wider count fields overflow it and
    // a STOCK field (zmhud.swordEnergy) then fails to register => Com_ERROR at load. docs/42.
    clientfield::register( "clientuimodel", "accRoundRing", VERSION_SHIP, 7, "int" );
    callback::on_connect( &on_player_connect );

    // Hide the STOCK power-up active-icon HUD for the 3 timed power-ups so ONLY our Ronan
    // icons (CoD.AccPowerupBar) show (user 2026-06-15). See suppress_stock_powerup_hud.
    level thread suppress_stock_powerup_hud();

    // Flash Carpenter / Random-Perk (free_perk) icons 3s on pickup via the generic stock
    // powerup_dropped -> powerup_grabbed signal pair (works for ANY powerup by name).
    level thread powerup_drop_flash_watch();
}

// Push the contextual perk/PaP card selector to a player's LUI overlay.
// code 0 hides the card; otherwise perkIndex*4 + mode (see _acc_perk_info).
function set_perk_card( player, code )
{
    player clientfield::set_player_uimodel( "accPerkCard", code );
}

// Push the held weapon's current PaP tier (0..3) so the card renders the NEXT tier.
function set_pap_tier( player, tier )
{
    if ( !isdefined( tier ) || tier < 0 ) tier = 0;
    if ( tier > 5 ) tier = 5;
    player clientfield::set_player_uimodel( "accPapTier", tier );
}

// Push the Mega-perk bitmask (bit i = perk i+1 is Mega'd) so the HUD glows them.
function set_mega_mask( player, mask )
{
    if ( !isdefined( mask ) || mask < 0 ) mask = 0;
    player clientfield::set_player_uimodel( "accMegaMask", mask );
}

// Push the owned-perk bitmask (bit i = player owns perk i+1). See accOwnedMask reg.
function set_owned_mask( player, mask )
{
    if ( !isdefined( mask ) || mask < 0 ) mask = 0;
    player clientfield::set_player_uimodel( "accOwnedMask", mask );
}

// Push a crosshair damage number. `value` = min(dmg,99999)*2 + parity (the caller
// owns the parity flip so identical numbers re-pop). 0 hides the number.
function set_dmg_num( player, value )
{
    if ( !isdefined( value ) || value < 0 ) value = 0;
    player clientfield::set_player_uimodel( "accDmgNum", value );
}

// Push the power-up active bitmask (bit 0 insta-kill, bit 1 double points, bit 2 fire sale).
function set_powerup_mask( player, mask )
{
    if ( !isdefined( mask ) || mask < 0 ) mask = 0;
    player clientfield::set_player_uimodel( "accPowerupMask", mask );
}

// Push the round-progress bar fill percent (0..100). 100 = full, 0 = empty.
function set_round_ring( player, pct )
{
    if ( !isdefined( pct ) || pct < 0 ) pct = 0;
    if ( pct > 100 ) pct = 100;
    player clientfield::set_player_uimodel( "accRoundRing", pct );
}

// Per-player loop driving the round-progress bar (acc_hud.lua CoD.AccRoundRing). The bar is
// ALWAYS visible. remaining = alive on field + still-to-spawn = "zombies left to kill this
// round" (drops by exactly 1 per kill); total = the round's full count, tracked as the peak
// of `remaining` this round. We push the PERCENT remaining (remaining/total*100) - the raw
// counts would need wider clientfields than the (full) clientuimodel pool allows. On change.
function round_ring_watch()
{
    self endon( "disconnect" );
    level endon( "end_game" );

    last_round = -1;
    total = 1;
    last_pct = -1;
    for ( ;; )
    {
        // New round -> reset the denominator after a short settle so stock has baselined
        // level.zombie_total for the round (avoids a between-rounds 0 flicker).
        if ( isdefined( level.round_number ) && level.round_number != last_round )
        {
            last_round = level.round_number;
            wait 1;
            total = 1;
        }

        alive = zombie_utility::get_current_zombie_count();
        togo  = 0;
        if ( isdefined( level.zombie_total ) && level.zombie_total > 0 )
            togo = level.zombie_total;
        remaining = alive + togo;
        if ( remaining < 0 ) remaining = 0;

        if ( remaining > total ) total = remaining;   // peak = the round's full count

        pct = Int( ( remaining * 100 ) / total );
        if ( pct < 0 ) pct = 0;
        if ( pct > 100 ) pct = 100;

        if ( pct != last_pct )
        {
            set_round_ring( self, pct );
            last_pct = pct;
        }

        wait 0.25;
    }
}

function on_player_connect()
{
    self thread player_lui_init();
}

// Open the always-on overlay for this player and light the foundation banner so
// we can confirm in-game that the whole LUI pipeline loaded.
function player_lui_init()
{
    self endon( "disconnect" );
    level flag::wait_till( "initial_blackscreen_passed" );
    wait 0.5; // let the client HUD settle before opening our overlay

    self.acc_lui_menu = self OpenLUIMenu( "acc_hud" );
    wait 0.1; // menu must instantiate client-side before we push model data
    self clientfield::set_player_uimodel( "accLuiTest", 1 );

    // Drive the perk-icon overlay (owned/mega bitmasks -> acc_hud.lua CoD.AccPerkBar) and
    // suppress the stock perk bar (instant zero-flash hide on perk gain + 0.25s re-assert).
    self thread perk_state_watch();
    self thread stock_perk_hud_suppressor();

    // Drive the power-up icon overlay (Ronan Insta-Kill / Double Points / Fire Sale).
    self thread powerup_state_watch();
    // Flash the INSTANT power-ups (Nuke / Max Ammo) for 3s on pickup (no timed window).
    self thread pickup_flash_watch();

    // Round-progress bar (upper-right). Per-player watcher; always-visible bar, drains as
    // the round's zombies die.
    self thread round_ring_watch();

    acc_utility::log( "lui: overlay opened + banner set for a player" );
}

// Per-player loop: track which perks the player OWNS and which are Mega'd and push BOTH
// bitmasks to the LUI overlay (acc_hud.lua CoD.AccPerkBar), which draws one cyberpunk icon
// per owned perk: owned+mega => teal, owned+!mega => red, !owned => hidden. All 8 live perks
// render (perk_card_index order). Also re-asserts the stock perk-bar suppression each tick
// (the instant zero-flash hide is stock_perk_hud_suppressor). Cheap: a 0.25s poll that
// pushes the masks only when they flip.
function perk_state_watch()
{
    self endon( "disconnect" );
    level endon( "end_game" );

    // BAR-BIT order: array index i -> mask bit i -> acc_hud.lua ACC_PERK_ICONS[i].
    // All 9 perks now carry a Ronan icon (PhD Flopper got exo_flopper at bit 8), so
    // every bit renders. MUST stay in lockstep with acc_hud.lua ACC_PERK_ICONS /
    // ACC_PERK_COUNT and _acc_perk_info::perk_card_index.
    specialties = array(
        "specialty_armorvest",               // bit 0  Jugger-Nog
        "specialty_quickrevive",             // bit 1  Quick Revive
        "specialty_fastreload",              // bit 2  Speed Cola
        "specialty_doubletap2",              // bit 3  Double Tap
        "specialty_staminup",                // bit 4  Stamin-Up
        "specialty_additionalprimaryweapon", // bit 5  Mule Kick
        "specialty_deadshot",                // bit 6  Deadshot
        "specialty_widowswine",              // bit 7  Widow's Wine
        "specialty_electriccherry"           // bit 8  PhD Flopper
    );

    last_owned = -1;
    last_mega  = -1;

    for ( ;; )
    {
        owned = 0;
        mega  = 0;
        for ( i = 0; i < specialties.size; i++ )
        {
            sp = specialties[ i ];
            // owns_or_paused (not bare HasPerk) so a boss EMP-pause of the perk does
            // NOT flicker the icon off mid-fight (mirrors has_active_mega_perk intent).
            if ( acc_mega_bottles::owns_or_paused( self, sp ) )
            {
                owned = owned | ( 1 << i );
                if ( acc_mega_bottles::has_mega_perk( self, sp ) )
                    mega = mega | ( 1 << i );
            }
        }

        // Re-assert stock perk-bar suppression. The common BUY case is already ZERO-flash
        // (stock_perk_hud_suppressor clears it the same frame the perk is gained); this
        // 0.25s re-assert just covers the rarer unpause / edge re-gives.
        self clear_stock_perk_hud();

        if ( owned != last_owned )
        {
            set_owned_mask( self, owned );
            last_owned = owned;
        }
        if ( mega != last_mega )
        {
            set_mega_mask( self, mega );
            last_mega = mega;
        }

        wait 0.25;
    }
}

// Zero the 9 stock perk-bar LUI model fields (hudItems.perks.<key>) for this player, which
// HIDES the stock perk-bar icons (we draw our own CoD.AccPerkBar). Cosmetic ONLY - perk
// EFFECTS come from engine SetPerk, not this model. Asset-name overrides CANNOT hide these
// (usermap zone loads last, base zone wins). Field names verified vs stock _zm_perks.gsh
// PERK_CLIENTFIELD_* (aliases: staminup->marathon, fastreload->sleight_of_hand,
// deadshot->dead_shot, additionalprimaryweapon->additional_primary_weapon).
function clear_stock_perk_hud()
{
    fields = array(
        "hudItems.perks.juggernaut",                // Jugger-Nog
        "hudItems.perks.quick_revive",              // Quick Revive
        "hudItems.perks.sleight_of_hand",           // Speed Cola
        "hudItems.perks.doubletap2",                // Double Tap
        "hudItems.perks.marathon",                  // Stamin-Up
        "hudItems.perks.additional_primary_weapon", // Mule Kick
        "hudItems.perks.dead_shot",                 // Deadshot
        "hudItems.perks.widows_wine",               // Widow's Wine
        "hudItems.perks.electric_cherry"            // PhD Flopper
    );
    for ( i = 0; i < fields.size; i++ )
        self clientfield::set_player_uimodel( fields[ i ], 0 );
}

// ZERO-FLASH stock perk-bar hide. Stock give_perk sets the perk's HUD clientfield to OWNED
// then fires "perk_acquired" in the SAME server frame with no wait in between
// (_zm_perks.gsc:756 -> :780), so clearing the fields on that notify lands in the same
// frame - the client's end-of-frame snapshot never carries the OWNED value, so the stock
// icon never appears (no flash). perk_state_watch's 0.25s re-assert covers the rarer
// unpause path that does NOT fire perk_acquired.
function stock_perk_hud_suppressor()
{
    self endon( "disconnect" );
    level endon( "end_game" );
    for ( ;; )
    {
        self waittill( "perk_acquired" );
        self clear_stock_perk_hud();
    }
}

// Per-player loop: read the stock zombie_vars powerup-active flags and push a 3-bit mask to
// the LUI overlay (acc_hud.lua CoD.AccPowerupBar), which shows the matching Ronan icon while
// each power-up is active. Insta-Kill + Double Points are TEAM-scoped
// (level.zombie_vars[team][...]); Fire Sale is GLOBAL (no team key). Var names verified vs
// stock _zm_powerups.gsc set_zombie_var + the per-powerup modules (zombie_powerup_*_on).
// 0.25s poll, push only on change. If the (opt-in) stock powerup vars are absent the mask
// stays 0 (icons hidden) - safe.
function powerup_state_watch()
{
    self endon( "disconnect" );
    level endon( "end_game" );

    last_mask = -1;
    for ( ;; )
    {
        wait 0.25;

        // Double Points drives its own stock HUD indicator via this uimodel (set 1 by its
        // grab, _zm_powerup_double_points.gsc:86 - NOT via the monitor we disable in
        // suppress_stock_powerup_hud). Zero it every tick so only our Ronan icon shows
        // (mirrors clear_stock_perk_hud). Cosmetic-only field (no gameplay coupling).
        self clientfield::set_player_uimodel( "hudItems.doublePointsActive", 0 );

        mask = 0;
        team = self.team;

        if ( isdefined( level.zombie_vars ) )
        {
            // Insta-Kill (team-scoped) -> bit 0. NOTE the inconsistent stock naming: the
            // insta-kill grab sets "zombie_insta_kill" = 1 directly (_zm_powerup_insta_kill.gsc:68)
            // and stock's own is_insta_kill_active() reads THAT (_zm_powerups.gsc:1432) - the
            // registered "zombie_powerup_insta_kill_on" is NOT reliably set. (Double Points /
            // Fire Sale below DO use the "_on" flag - those grabs set it true directly.)
            if ( isdefined( team ) && isdefined( level.zombie_vars[ team ] )
                 && IS_TRUE( level.zombie_vars[ team ][ "zombie_insta_kill" ] ) )
                mask = mask | 1;

            // Double Points (team-scoped) -> bit 1
            if ( isdefined( team ) && isdefined( level.zombie_vars[ team ] )
                 && IS_TRUE( level.zombie_vars[ team ][ "zombie_powerup_double_points_on" ] ) )
                mask = mask | 2;

            // Fire Sale (GLOBAL, no team key) -> bit 2
            if ( IS_TRUE( level.zombie_vars[ "zombie_powerup_fire_sale_on" ] ) )
                mask = mask | 4;
        }

        // INSTANT power-ups have no "active" var; pickup_flash_watch stamps an expiry GetTime() on
        // the player, and we OR the bit in until it lapses (~3s). The on-change push + 0.25s poll
        // turns the icon on within a tick of pickup and off within a tick of expiry.
        if ( isdefined( self.acc_flash_nuke_until ) && GetTime() < self.acc_flash_nuke_until )
            mask = mask | 8;      // bit 3 = Nuke
        if ( isdefined( self.acc_flash_maxammo_until ) && GetTime() < self.acc_flash_maxammo_until )
            mask = mask | 16;     // bit 4 = Max Ammo
        if ( isdefined( self.acc_flash_carpenter_until ) && GetTime() < self.acc_flash_carpenter_until )
            mask = mask | 32;     // bit 5 = Carpenter
        if ( isdefined( self.acc_flash_randomperk_until ) && GetTime() < self.acc_flash_randomperk_until )
            mask = mask | 64;     // bit 6 = Random Perk (free_perk)

        if ( mask != last_mask )
        {
            set_powerup_mask( self, mask );
            last_mask = mask;
        }
    }
}

// ---------------------------------------------------------------------------
// Instant power-up pickup flash (Nuke / Max Ammo) - 3s, no timed window
// ---------------------------------------------------------------------------

// self = player. The INSTANT power-ups have no "active" duration, so we stamp a 3s window on the
// player; powerup_state_watch ORs the matching accPowerupMask bit while the stamp is live, so the
// Ronan icon shows in the power-up row for ~3s then clears. Two stock grab signals drive it:
//   - Max Ammo: team-wide level notify "zmb_max_ammo_level" (_zm_powerup_full_ammo.gsc:59) - every
//     player's watcher wakes and flashes itself.
//   - Nuke: "nuke_triggered" on the GRABBING player only (_zm_powerup_nuke.gsc:59); power-ups are
//     team-global, so the grabber's thread flashes ALL players.
function pickup_flash_watch()
{
    self endon( "disconnect" );
    level endon( "end_game" );

    self thread maxammo_flash_watch();
    self thread nuke_flash_watch();
}

function maxammo_flash_watch()
{
    self endon( "disconnect" );
    level endon( "end_game" );
    for ( ;; )
    {
        level waittill( "zmb_max_ammo_level" );
        self.acc_flash_maxammo_until = GetTime() + 3000;
    }
}

function nuke_flash_watch()
{
    self endon( "disconnect" );
    level endon( "end_game" );
    for ( ;; )
    {
        self waittill( "nuke_triggered" );   // stock notifies only the grabbing player
        foreach ( p in GetPlayers() )        // power-ups are team-global -> flash everyone
            p.acc_flash_nuke_until = GetTime() + 3000;
    }
}

// Level-once. Generic pickup flash for the remaining INSTANT power-ups that have no dedicated grab
// signal of their own (Carpenter, Random Perk / free_perk). Stock fires level notify
// "powerup_dropped" with the powerup ENT on every drop (_zm_powerups.gsc:681/692); the ent carries
// .powerup_name and notifies itself "powerup_grabbed" on pickup (:963). We watch each dropped ent
// for its grab and flash the matching bit. (Nuke / Max Ammo keep their own watchers above; this
// only acts on carpenter/free_perk, so there's no double-handling.) Drops may not be enabled on the
// map yet - this fires only if/when those power-ups actually drop.
function powerup_drop_flash_watch()
{
    level endon( "end_game" );
    for ( ;; )
    {
        level waittill( "powerup_dropped", powerup );
        if ( isdefined( powerup ) )
            level thread one_powerup_grab_flash( powerup );
    }
}

function one_powerup_grab_flash( powerup )
{
    level endon( "end_game" );
    powerup endon( "powerup_timedout" );   // expired un-grabbed -> stop watching

    powerup waittill( "powerup_grabbed" );
    if ( !isdefined( powerup ) || !isdefined( powerup.powerup_name ) ) return;

    // power-ups are team-global -> flash all players (matches the Nuke behaviour)
    if ( powerup.powerup_name == "carpenter" )
    {
        foreach ( p in GetPlayers() )
            p.acc_flash_carpenter_until = GetTime() + 3000;
    }
    else if ( powerup.powerup_name == "free_perk" )
    {
        foreach ( p in GetPlayers() )
            p.acc_flash_randomperk_until = GetTime() + 3000;
    }
}

// Level-once: hide the STOCK power-up active-icon HUD for the 3 TIMED power-ups (Insta-Kill /
// Double Points / Fire Sale) so ONLY our Ronan icons (CoD.AccPowerupBar) show. The stock HUD is
// driven by stock powerup_hud_monitor, which captures each powerup's client_field_name ONCE - the
// frame "start_zombie_round_logic" fires (_zm_powerups.gsc:167,216) - and only includes powerups
// whose client_field_name IsDefined. Null it for the 3 timed powerups and they drop out of the
// monitor -> their stock clientfield is never set -> the stock icon never renders. client_field_name
// is used ONLY by the monitor (verified, _zm_powerups.gsc) - no gameplay coupling. Instant power-ups
// (Max Ammo / Nuke / Carpenter) register NO client_field_name, so they have no persistent stock icon.
// (Double Points' separate hudItems.doublePointsActive uimodel is zeroed in powerup_state_watch.)
//
// RACE FIX (2026-06-17): the old code did a ONE-SHOT clear at "initial_blackscreen_passed", betting
// that fires before the monitor's "start_zombie_round_logic" capture. It RACED and intermittently
// lost - base icons showed some sessions, not others. Now we LOOP-null from system-init (the moment
// the powerups exist) until the capture has happened, so the monitor ALWAYS reads undefined,
// regardless of flag order. We never flag::wait_till a gameplay flag from this REGISTER_SYSTEM
// __init__ thread (that crashes - "cannot cast undefined to bool", 2026-06-15); flag::exists is safe
// anytime, and flag::get is only called after exists confirms it.
function suppress_stock_powerup_hud()
{
    level endon( "end_game" );

    timed = array( "insta_kill", "double_points", "fire_sale" );

    // Poll until the stock powerups are registered (their REGISTER_SYSTEM runs at system-init too,
    // so registration order vs ours is not guaranteed).
    while ( !isdefined( level.zombie_powerups ) || !isdefined( level.zombie_powerups[ "insta_kill" ] ) )
        wait( 0.05 );

    // Keep client_field_name null every frame until the monitor's one-shot capture has fired. Nothing
    // re-sets client_field_name after registration, so once null it stays null across the capture.
    for ( ;; )
    {
        for ( i = 0; i < timed.size; i++ )
            if ( isdefined( level.zombie_powerups[ timed[ i ] ] ) )
                level.zombie_powerups[ timed[ i ] ].client_field_name = undefined;

        if ( level flag::exists( "start_zombie_round_logic" ) && level flag::get( "start_zombie_round_logic" ) )
            break;
        wait( 0.05 );
    }

    // One more sweep a frame after capture (belt-and-suspenders vs same-frame thread wake order).
    wait( 0.1 );
    for ( i = 0; i < timed.size; i++ )
        if ( isdefined( level.zombie_powerups[ timed[ i ] ] ) )
            level.zombie_powerups[ timed[ i ] ].client_field_name = undefined;
}
