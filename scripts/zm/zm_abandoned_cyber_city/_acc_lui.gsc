// =============================================================================
// _acc_lui.gsc - LUI client pipeline FOUNDATION (server half)
//
// Stands up the map's custom LUI HUD overlay (ui/uieditor/menus/hud/acc_hud.lua)
// and the clientuimodel data bridge that drives it. This is the substrate every
// future premium-UI touchpoint rides on (perk-icon glow, Data Shards counter,
// Cyberware indicators, boss bar - see docs/11_controls_and_hud.md, docs/19_lui_pipeline.md).
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
    // ===== AETHERIUM HUD MASTER FLAG (2026-07-03) =====
    // true  = the Aetherium kit (scripts/zm/_zm_aetherium_hud + ui/uieditor .../Aetherium*)
    //         REPLACES the stock T7Hud_zm_factory menu. Everything below that existed only to
    //         suppress or duplicate the stock HUD is skipped: stock-perk-bar zeroing, stock
    //         powerup-icon suppression, the weapon_hud_visible clear, our LUI powerup mask
    //         feeds, and (in _acc_health_bars) the co-op roster. accOwnedMask/accMegaMask KEEP
    //         flowing - they now drive the REWIRED AetheriumPerksContainer (Mappings/
    //         AetheriumPerks.lua carries the bit->icon table).
    // false = SERVER half of the restore ONLY. The FULL pre-Aetherium restore is 3 steps
    //         (review catch 2026-07-03 - the .csc lives in the OTHER VM and can't read this):
    //           1. this bool -> false            (re-arms suppressors, roster, mask feeds)
    //           2. _zm_aetherium_hud.csc         -> #define ACC_AETHERIUM_HUD_ON 0
    //              (stops the LuiLoad that replaces T7Hud_zm_factory - REQUIRED, else the
    //               re-armed powerup suppressor blanks Aetherium's powerup row = no powerup
    //               display ANYWHERE, and the kit HUD double-draws over the roster)
    //           3. acc_hud.lua createMenu        -> re-add the RETIRED widget registrations
    //              (AccPerkBar / AccPowerupBar / AccAmmoBlock / AccEquip - recipes in place)
    // Hardcoded bool by design (dev-mode-hardcoded-not-console rule: no runtime dvar).
    level.acc_aetherium_hud = true;
    // NOTE (crash-hunt 2026-07-10): flipping ONLY this bool + the .csc define black-screens the load -
    // the full stock-HUD rollback really is the 3-step recipe above (step 3 included). Verified live.

    // Must match the .csc mirror EXACTLY (scope/name/version/bits/type) AND in the
    // SAME ORDER - the bit layout is assigned in registration order.
    // [acc] Held weapon's Cyberware Overclock tier (0..5), shown as "vN" near the gun name by
    // acc_hud.lua CoD.AccOcTierText; pushed by _acc_overclocks::oc_hud_loop. REPURPOSED 2026-06-21
    // from the dead `accLuiTest` test field - SAME 4-bit slot in the SAME registration order, so the
    // clientfield bit layout is UNCHANGED (no pool growth -> no overflow / stock-field break, docs/11).
    clientfield::register( "clientuimodel", "accOcTier", VERSION_SHIP, 4, "int" );
    // Perk/PaP info card selector: code = perkIndex*4 + mode (0 = hide), +64 when the
    // viewing player holds The Armory (Mule Kick Mega) so the card shows the 10%-off
    // price. Max 10*4+3+64 = 107 -> 7 bits. Decoded + rendered by acc_hud.lua.
    clientfield::register( "clientuimodel", "accPerkCard", VERSION_SHIP, 7, "int" );
    // Pack-a-Punch current tier (0..5) of the held weapon, pushed when near PaP so
    // the card shows only the NEXT tier (not the whole ladder). 3 bits (0..7).
    clientfield::register( "clientuimodel", "accPapTier", VERSION_SHIP, 3, "int" );
    // Mega-perk bitmask: bit i set => the perk at bar-bit i is Mega'd (perk_state_watch
    // order). 10 bits (10 perks; PhD Flopper bit 8, Electric Cherry bit 9). acc_hud.lua
    // tints the matching perk-bar icon teal. (Widened 9->10 for Electric Cherry, user
    // 2026-06-25 - testing whether the near-full clientuimodel pool has room; revert to 9
    // + a bit-reclaim if the load Com_ERRORs on zmhud.swordEnergy.)
    clientfield::register( "clientuimodel", "accMegaMask", VERSION_SHIP, 10, "int" );
    // Damage number: value = min(dmg,99999)*2 + parity. acc_hud.lua shows it near
    // the crosshair (you aim at the zombie, so it reads on-target). The parity bit
    // flips every push so an identical number still re-triggers the popup. 18 bits.
    clientfield::register( "clientuimodel", "accDmgNum", VERSION_SHIP, 18, "int" );
    // Owned-perk bitmask: bit i set => the player OWNS the perk at bar-bit i
    // (perk_state_watch order), regardless of Mega. Pairs with accMegaMask so the LUI
    // overlay can pick the icon: owned+mega => teal (Mega), owned+!mega => red (base),
    // !owned => hide. 10 bits (10 perks; Electric Cherry bit 9). Driven by perk_state_watch().
    // Appended LAST so the existing fields' bit layout is untouched (must match _acc_lui.csc order).
    clientfield::register( "clientuimodel", "accOwnedMask", VERSION_SHIP, 10, "int" );
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
    // a STOCK field (zmhud.swordEnergy) then fails to register => Com_ERROR at load. docs/11.
    clientfield::register( "clientuimodel", "accRoundRing", VERSION_SHIP, 7, "int" );
    // [acc] ACTOR-scope eye-tint marker for the Glitch Stalker (teal eyes, NO FX). Separate
    // bit pool from the clientuimodel fields above. MUST match _acc_lui.csc EXACTLY
    // (scope/name/version/bits/type). Server only registers + sets; the client mirror owns the
    // recolour callback. See set_actor_eye_tint + _acc_boss_glitch.gsc spawn_glitch.
    clientfield::register( "actor", "accEyeTint", VERSION_SHIP, 1, "int" );
    callback::on_connect( &on_player_connect );

    // AETHERIUM: both level threads below existed to make OUR CoD.AccPowerupBar the only
    // powerup display. Aetherium's PowerupsContainer reads the STOCK powerup clientfields,
    // so suppressing them would blank it - skip both when the kit is on.
    if ( !IS_TRUE( level.acc_aetherium_hud ) )
    {
        // Hide the STOCK power-up active-icon HUD for the 3 timed power-ups so ONLY our Ronan
        // icons (CoD.AccPowerupBar) show (user 2026-06-15). See suppress_stock_powerup_hud.
        level thread suppress_stock_powerup_hud();

        // Flash Carpenter / Random-Perk (free_perk) icons 3s on pickup via the generic stock
        // powerup_dropped -> powerup_grabbed signal pair (works for ANY powerup by name).
        level thread powerup_drop_flash_watch();
    }
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

// Push the held weapon's Cyberware Overclock tier (0..10) -> acc_hud.lua "vN" indicator (0 = hidden).
// accOcTier is a 4-bit clientfield (max 15) so 10 fits. (user 2026-06-25: was clamped to 5, froze the HUD at v5/10.)
function set_oc_tier( player, tier )
{
    if ( !isdefined( tier ) || tier < 0 ) tier = 0;
    if ( tier > 10 ) tier = 10;
    player clientfield::set_player_uimodel( "accOcTier", tier );
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

// Push a crosshair damage number. `value` = min(dmg,65535)*4 + headshot_bit + parity
// (the caller owns the encoding: parity flips so identical numbers re-pop, bit 1 = the
// hit was a headshot -> teal). 0 hides the number. Fits the 18-bit accDmgNum field exactly.
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

// Mark/unmark an ACTOR for the teal eye-tint recolour (Glitch Stalker). The matching client
// callback (_acc_lui.csc eye_tint_cb) recolours ONLY this actor's eyeball material - no FX asset,
// horde untouched. `on` falsey => clear back to the stock eye colour.
function set_actor_eye_tint( actor, on )
{
    if ( !isdefined( actor ) ) return;
    actor clientfield::set( "accEyeTint", ( IS_TRUE( on ) ? 1 : 0 ) );
}

// Per-player loop driving the round-progress bar (acc_hud.lua CoD.AccRoundRing). The bar is
// ALWAYS visible. remaining = alive on field + still-to-spawn = "zombies left to kill this
// round" (drops by exactly 1 per kill); total = the round's full count, tracked as the peak
// of `remaining` this round. We push the PERCENT remaining (remaining/total*100) - the raw
// counts would need wider clientfields than the (full) clientuimodel pool allows. On change.
function round_ring_watch()
{
    self endon( "disconnect" );
    self endon( "acc_lui_life" );   // re-threaded per life by player_lui_init (respawn HUD rebuild)
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

// Open the always-on overlay for this player and (RE)BUILD it on every (re)spawn.
//
// RESPAWN FIX (user 2026-06-24: "drops + perks don't show after a player dies and respawns").
// The whole HUD - the perk bar AND the power-up drop icons (Nuke/Max Ammo flash, Insta-Kill/
// Double Points/Fire Sale) AND the round ring - is ONE LUI overlay (the acc_hud menu). The
// engine CLOSES a player's LUI menu on the death->spectate transition, and the old code opened
// it only ONCE on connect, so a respawned player lost the entire overlay for the rest of the
// game. Now we re-open the menu and RE-THREAD the watch loops once per life: fresh change-
// trackers => an immediate full re-push to the just-opened menu. The previous life's watchers
// are killed by the "acc_lui_life" notify so they never stack. "spawned_player" fires on the
// initial spawn AND every co-op respawn (notify site _zm.gsc:3337), the same per-life hook
// _acc_boss_items uses for its respawn reapplies.
function player_lui_init()
{
    self endon( "disconnect" );
    level flag::wait_till( "initial_blackscreen_passed" );

    for ( ;; )
    {
        wait 0.5; // let the (re)spawned client HUD settle before (re)opening our overlay

        if ( isdefined( self.acc_lui_menu ) )
            self CloseLUIMenu( self.acc_lui_menu );
        self.acc_lui_menu = self OpenLUIMenu( "acc_hud" );
        wait 0.1; // menu must instantiate client-side before we push model data

        // End the prior life's watchers, then (re)start all five with FRESH change-trackers so
        // they immediately re-push the current state to the just-opened menu (a perk bar that
        // hasn't changed since the last push would otherwise never repaint into the new menu).
        self notify( "acc_lui_life" );
        self thread perk_state_watch();          // owned/mega masks - feed the (rewired) Aetherium perk row, or CoD.AccPerkBar pre-Aetherium
        self thread round_ring_watch();           // upper-right round-progress bar

        // AETHERIUM: the four threads below only serve the PRE-Aetherium HUD. With the kit on:
        // the stock perk bar / ammo block don't exist (T7Hud_zm_factory replaced, so no zeroing
        // or weapon_hud_visible clear needed - clearing it might even hide Aetherium's d-pad
        // models), and power-ups are drawn by Aetherium from the STOCK clientfields (our
        // accPowerupMask feeds + pickup flashes are dead weight).
        if ( !IS_TRUE( level.acc_aetherium_hud ) )
        {
            self thread stock_perk_hud_suppressor();  // instant zero-flash hide of the stock perk bar
            self thread powerup_state_watch();        // Insta-Kill / Double Points / Fire Sale icons
            self thread pickup_flash_watch();         // Nuke / Max Ammo 3s pickup flash (the "drops")
            self thread suppress_stock_weapon_hud();  // hide the stock ammo/weapon HUD (we draw our own: acc_hud.lua AccAmmoBlock/AccEquip)
        }

        acc_utility::log( "lui: overlay (re)opened for a player (per-life)" );

        self waittill( "spawned_player" );        // next death->respawn -> rebuild the overlay
    }
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
    self endon( "acc_lui_life" );   // re-threaded per life by player_lui_init (respawn HUD rebuild)
    level endon( "end_game" );

    // BAR-BIT order: array index i -> mask bit i. MUST stay in lockstep with ALL of:
    //   ui/uieditor/widgets/HUD/Mappings/AetheriumPerks.lua `bit` fields  <- the LIVE consumer
    //     (Aetherium perk row, since the 2026-07-03 adoption),
    //   acc_hud.lua ACC_PERK_ICONS / ACC_PERK_COUNT  (retired CoD.AccPerkBar - restore path),
    //   _acc_perk_info::perk_card_index  (info-card indices).
    // All 10 perks carry a Ronan icon (PhD bit 8, Electric Cherry bit 9), so every bit renders.
    specialties = array(
        "specialty_armorvest",               // bit 0  Jugger-Nog
        "specialty_quickrevive",             // bit 1  Quick Revive
        "specialty_fastreload",              // bit 2  Speed Cola
        "specialty_doubletap2",              // bit 3  Double Tap
        "specialty_staminup",                // bit 4  Stamin-Up
        "specialty_additionalprimaryweapon", // bit 5  Mule Kick
        "specialty_deadshot",                // bit 6  Deadshot
        "specialty_widowswine",              // bit 7  Widow's Wine
        "specialty_electriccherry",          // bit 8  PhD Flopper (over the cherry pipeline)
        "specialty_combat_efficiency"        // bit 9  Electric Cherry (real 10th perk)
    );

    last_owned = -1;
    last_mega  = -1;

    for ( ;; )
    {
        // BLINK an Avogadro-hacked perk on the row (user 2026-07-05: "the perk that is affected should
        // blink"). CONSTRAINT: the clientuimodel clientfield pool is FULL (docs/11) so NO new field, and
        // toggling the perk's OWNED bit is NOT viable - HandlePerksList (AetheriumPerksContainer.lua) rebuilds
        // the row in ACQUISITION order, so a perk whose owned bit drops out re-appends on the far RIGHT and
        // replays its slide-in => the whole row reshuffles every blink. INSTEAD flip the hacked perk's MEGA
        // bit on a wall-clock half-second: owned stays set so the icon KEEPS ITS SLOT (no reflow, no slide-in)
        // and only its art alternates base<->mega IN PLACE - a stable, eye-catching pulse with NO new
        // clientfield and NO LUI edit (zero map-load / LUI-runtime risk). Same server-clock idiom as
        // pu_show_bit's powerup blink. The paired hack_alert toast says WHAT went down; this pulse draws the
        // eye to WHICH perk. Hack state = level.acc_avo_hacked[ specialty ] (_acc_boss_avogadro::do_hack /
        // undo_hack), read directly to avoid a HUD->boss #using. Only the 5 hackable perks ever match; PaP
        // isn't on the row (toast only). perk_state_watch recomputes mega from source every tick, so the real
        // Mega state is restored the instant the hack ends - the flip is transient, never persisted.
        blink_flip = ( ( GetTime() % 1000 ) < 500 );   // 1Hz, wall-clock -> co-op players pulse in sync
        hacks = level.acc_avo_hacked;                  // may be undefined pre-Avogadro-init; guarded below

        owned = 0;
        mega  = 0;
        for ( i = 0; i < specialties.size; i++ )
        {
            sp = specialties[ i ];
            // owns_paused_or_hacked (not bare HasPerk, not owns_or_paused): an EMP-pause OR an
            // Avogadro hack keeps the icon IN ITS SLOT (owns_or_paused now reads a hacked perk as
            // not-owned for gameplay gates, 2026-07-06 - using it here would drop the owned bit and
            // reflow the whole row, exactly what the blink design below avoids).
            if ( acc_mega_bottles::owns_paused_or_hacked( self, sp ) )
            {
                owned   = owned | ( 1 << i );
                is_mega = acc_mega_bottles::has_mega_perk( self, sp );
                // On the "flip" half of the blink cycle, invert a hacked perk's mega art so its icon pulses.
                if ( blink_flip && isdefined( hacks ) && IS_TRUE( hacks[ sp ] ) )
                    is_mega = !is_mega;
                if ( is_mega )
                    mega = mega | ( 1 << i );
            }
        }

        // Re-assert stock perk-bar suppression. The common BUY case is already ZERO-flash
        // (stock_perk_hud_suppressor clears it the same frame the perk is gained); this
        // 0.25s re-assert just covers the rarer unpause / edge re-gives.
        // AETHERIUM: skipped - the stock perk bar's menu no longer exists, and the rewired
        // Aetherium perk row reads our masks, not hudItems.perks.
        if ( !IS_TRUE( level.acc_aetherium_hud ) )
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

// PHASE 0 - hide the STOCK bottom-right ammo/weapon HUD block so only OUR custom combat HUD
// (acc_hud.lua CoD.AccAmmoBlock / CoD.AccEquip) shows. The ENTIRE stock ZmAmmo suite (mag,
// reserve, weapon name, weapon icon, lethal, tactical, d-pad) is gated by the engine visibility
// bit BIT_WEAPON_HUD_VISIBLE (the stock HUD checks it at t7hud_zm_custom.lua:166). Clearing that
// bit server-side with the stock call `SetClientUIVisibilityFlag( "weapon_hud_visible", 0 )` (a
// real ZM call - stock uses it at _zm.gsc:6149/1761/536, e.g. for the siegebot) hides the whole
// block in ONE call: no LUI edit, no stock-menu override (which would brick the .ff -
// lui-menu-can-break-map-load), and NO new clientfield (ammo has no writable uimodel, so the
// perk-style clear_stock_perk_hud trick does NOT transfer here).
//
// RE-ASSERT every 0.25s (not one-shot): stock re-SETS weapon_hud_visible to 1 on spawn/revive/etc
// (_zm.gsc:536/1761/1882), so a single call would let the stock block flicker back. Cheap poll,
// mirrors clear_stock_perk_hud's re-assert cadence. Per-life (re-threaded by player_lui_init).
// NOTE (verify in-game, docs/22 Phase 0 gate): confirm this cleanly hides the block AND does not
// also hide a d-pad/GobbleGum prompt we want to keep; if it over-hides, scope down before Phase 2.
function suppress_stock_weapon_hud()
{
    self endon( "disconnect" );
    self endon( "acc_lui_life" );   // re-threaded per life by player_lui_init (respawn HUD rebuild)
    level endon( "end_game" );

    for ( ;; )
    {
        self SetClientUIVisibilityFlag( "weapon_hud_visible", 0 );
        wait 0.25;
    }
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
    self endon( "acc_lui_life" );   // re-threaded per life by player_lui_init (respawn HUD rebuild)
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
// 0.1s poll, push only on change (0.1s keeps the last-4s blink smooth). If the (opt-in) stock
// powerup vars are absent the mask stays 0 (icons hidden) - safe.
function powerup_state_watch()
{
    self endon( "disconnect" );
    self endon( "acc_lui_life" );   // re-threaded per life by player_lui_init (respawn HUD rebuild)
    level endon( "end_game" );

    last_mask = -1;
    for ( ;; )
    {
        wait 0.1;

        // Double Points drives its own stock HUD indicator via this uimodel (set 1 by its
        // grab, _zm_powerup_double_points.gsc:86 - NOT via the monitor we disable in
        // suppress_stock_powerup_hud). Zero it every tick so only our Ronan icon shows
        // (mirrors clear_stock_perk_hud). Cosmetic-only field (no gameplay coupling).
        self clientfield::set_player_uimodel( "hudItems.doublePointsActive", 0 );

        mask = 0;
        team = self.team;

        // TIMED power-ups (Insta-Kill / Double Points / Fire Sale): show the custom icon while active,
        // then BLINK it during the last ~4s like base zombies. pu_show_bit self-clocks each one's 30s
        // lifetime off its activation edge and returns false on the blink-OFF frames. (We clock it
        // ourselves because insta-kill runs its own stock wait with NO countdown var to read, so there
        // is no uniform "time left" var - one 30s rule covers all three.)
        if ( isdefined( level.zombie_vars ) )
        {
            // Insta-Kill grab sets "zombie_insta_kill"=1 directly (the registered "..._on" is NOT
            // reliably set - _zm_powerups.gsc:1432); Double Points / Fire Sale use their "_on" flag.
            ik_on = ( isdefined( team ) && isdefined( level.zombie_vars[ team ] )
                      && IS_TRUE( level.zombie_vars[ team ][ "zombie_insta_kill" ] ) );
            dp_on = ( isdefined( team ) && isdefined( level.zombie_vars[ team ] )
                      && IS_TRUE( level.zombie_vars[ team ][ "zombie_powerup_double_points_on" ] ) );
            fs_on = IS_TRUE( level.zombie_vars[ "zombie_powerup_fire_sale_on" ] );   // GLOBAL, no team key

            if ( self pu_show_bit( 0, ik_on ) ) mask = mask | 1;
            if ( self pu_show_bit( 1, dp_on ) ) mask = mask | 2;
            if ( self pu_show_bit( 2, fs_on ) ) mask = mask | 4;
        }

        // INSTANT power-ups have no "active" var; pickup_flash_watch stamps an expiry GetTime() on
        // the player, and we OR the bit in until it lapses (~3s). The on-change push + 0.1s poll
        // turns the icon on within a tick of pickup and off within a tick of expiry. (Instant icons
        // do NOT blink - they have no countdown to "run out".)
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

// self = player. Decide whether a TIMED power-up's mask bit (0=Insta-Kill, 1=Double Points, 2=Fire Sale)
// shows THIS frame. Steady-on while active until the last 4s, then BLINK (and blink faster under 2s) so
// CoD.AccPowerupBar flashes the custom icon like base zombies. We clock the 30s lifetime ourselves off
// the activation edge - insta-kill runs its own stock wait with no countdown var to read. A re-grab that
// extends the real timer past our 30s estimate just stops blinking (remaining<=0 -> steady) until the
// stock expiry flips the flag off and clears us. Blink periods (400/200ms) are even multiples of the
// 0.1s poll so the on/off halves sample cleanly.
function pu_show_bit( bit, active )
{
    if ( !isdefined( self.acc_pu_expiry ) )
        self.acc_pu_expiry = [];

    if ( !active )
    {
        self.acc_pu_expiry[ bit ] = undefined;   // arm a fresh 30s clock for the next pickup
        return false;
    }

    if ( !isdefined( self.acc_pu_expiry[ bit ] ) )       // activation edge -> start the clock
        self.acc_pu_expiry[ bit ] = GetTime() + 30000;   // N_POWERUP_DEFAULT_TIME = 30s

    remaining_ms = self.acc_pu_expiry[ bit ] - GetTime();
    if ( remaining_ms >= 4000 || remaining_ms <= 0 )
        return true;   // steady on (outside the blink window, or extended past our estimate)

    period = ( ( remaining_ms < 2000 ) ? 200 : 400 );    // 2.5Hz, speeding to 5Hz in the final 2s
    return ( ( GetTime() % period ) < ( period / 2 ) );
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
    self endon( "acc_lui_life" );   // re-threaded per life by player_lui_init (respawn HUD rebuild)
    level endon( "end_game" );

    self thread maxammo_flash_watch();
    self thread nuke_flash_watch();
}

function maxammo_flash_watch()
{
    self endon( "disconnect" );
    self endon( "acc_lui_life" );   // re-threaded per life by pickup_flash_watch - die with it (was leaking 1/respawn)
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
    self endon( "acc_lui_life" );   // re-threaded per life by pickup_flash_watch - die with it (was leaking 1/respawn)
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
