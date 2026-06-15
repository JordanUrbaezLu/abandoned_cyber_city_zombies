// =============================================================================
// _acc_perk_info.gsc - perk + Pack-a-Punch info CARD selector (drives LUI)
//
// Player-facing (REQUIREMENTS / docs/13_perks.md, docs/27_ui_plan.md): walk up
// to a perk machine (or Pack-a-Punch) and a premium card shows the NAME, PRICE,
// and BULLETED benefits (base + Mega for perks; the 5-tier ladder for PaP) so
// players can craft builds.
//
// This module is now just the BRAIN: per player it finds the nearest machine and
// the context (buy/mega/maxed/pap) and pushes a single int "card code"
// (perkIndex*4 + mode, 0 = hide) to the LUI overlay via acc_lui::set_perk_card.
// The card itself (title/price/bulleted text + styling) is RENDERED in
// ui/uieditor/menus/hud/acc_hud.lua from its perk-card lookup table - the proven
// clientuimodel-int + Lua-lookup pattern (room_manager.lua). The old all-GSC
// server-HUD card (acc_ui::card) is retired for this touchpoint (mis-aligned text
// outside the box); acc_ui remains available for any non-LUI fallback.
// =============================================================================

#using scripts\shared\flag_shared;
#using scripts\shared\util_shared;

#using scripts\zm\_zm_magicbox;

#insert scripts\shared\shared.gsh;

#using scripts\zm\zm_abandoned_cyber_city\_acc_utility;
#using scripts\zm\zm_abandoned_cyber_city\_acc_mega_bottles;
#using scripts\zm\zm_abandoned_cyber_city\_acc_lui;
#using scripts\zm\zm_abandoned_cyber_city\_acc_pap_levels;

// Match-or-slightly-exceed the stock perk BUY range so the card + discounted price
// show whenever you can buy. Stock use trigger = radius 40 at machine+60 height; with
// the player's ~30u width the effective buy edge is ~70u horizontal -> ~92u 3D from
// the feet. 105u gives a small lead so the card is up by the time the buy prompt is.
#define ACC_PERK_INFO_RANGE_SQ 11025   // 105u (slightly above perk buy distance)
#define ACC_PAP_RANGE_SQ       12100   // 110u
#define ACC_BOX_RANGE_SQ       10000   // 100u (players "at the box" for the group discount)

#namespace acc_perk_info;

function init()
{
    acc_utility::log( "perk_info: init" );
    level thread watch_players();

    // The Armory (Mega Mule Kick) = 10% off perks, POINT OF SALE. Overriding the
    // stock cost code from a usermap does NOT work (base game wins), so the CHARGE
    // is set deterministically per-player via the stock custom_perk_validation hook
    // (acc_perk_validate, below) - it runs ON the trigger with the BUYING player
    // immediately before _zm_perks.gsc reads `current_cost = self.cost`, so there is
    // no proximity dependence and no race. The DISPLAY (hint) is a separate, cosmetic
    // proximity refresh (armory_perk_pricing) since the shown price can't be per-player
    // on a shared trigger - it shows the discount once you're at the machine.
    level.custom_perk_validation = &acc_perk_validate;
    level thread armory_perk_pricing();
    level thread armory_box_pricing();
}

// The Armory also gives 10% off the Mystery Box (spec docs/13_perks.md). Unlike perk
// machines, the box uses PER-PLAYER unitriggers (unitrigger_force_per_player_triggers),
// and both its charge (box.zombie_cost) and its shown price (trigger_target.zombie_cost)
// resolve to the same box-entity field - so we wrap each box's prompt func to set that
// field, then run the stock prompt. Skips fire sales (don't fight that powerup, and a 10%
// cut of the 10-point sale price would round to free).
function armory_box_pricing()
{
    level endon( "end_game" );
    level flag::wait_till( "initial_blackscreen_passed" );

    // Retry until the stock box init has wired every chest's unitrigger stub.
    for ( n = 0; n < 40; n++ )
    {
        if ( install_box_prompt_hooks() ) break;
        wait 0.5;
    }
}

function install_box_prompt_hooks()
{
    if ( !isdefined( level.chests ) || level.chests.size == 0 ) return false;
    all_ready = true;
    for ( i = 0; i < level.chests.size; i++ )
    {
        box = level.chests[ i ];
        if ( !isdefined( box ) || !isdefined( box.unitrigger_stub ) ) { all_ready = false; continue; }
        // Per-player triggers read the stub's prompt func LIVE, so one reassign per
        // chest covers every (re)spawned per-player trigger at that location.
        box.unitrigger_stub.prompt_and_visibility_func = &acc_box_prompt;
    }
    return all_ready;
}

// self = the per-player box trigger; player = the looking player; self.stub.trigger_target
// = the box entity, whose zombie_cost is read by BOTH the buy charge and the prompt display.
// box.zombie_cost is ONE shared field but EVERY nearby player's per-frame prompt writes it,
// so basing it on the individual `player` would race (a buyer could be charged another nearby
// player's price). Instead base it on the GROUP - discount only when EVERY player near the
// box holds active Armory (same rule as the perk wall hint) - so all writers agree on the
// same value: mixed group pays base, all-Armory group pays the discount, solo pays your price.
function acc_box_prompt( player )
{
    box = self.stub.trigger_target;
    if ( isdefined( box ) && !box_firesale_active() )
    {
        base = ( isdefined( box.old_cost ) ? box.old_cost : box.zombie_cost );
        if ( isdefined( base ) )
        {
            if ( all_in_range_have_armory( box.origin, ACC_BOX_RANGE_SQ ) )
                box.zombie_cost = armory_discounted( base );
            else
                box.zombie_cost = base;
        }
    }
    return self zm_magicbox::boxtrigger_update_prompt( player );
}

function box_firesale_active()
{
    return isdefined( level.zombie_vars )
        && isdefined( level.zombie_vars[ "zombie_powerup_fire_sale_on" ] )
        && level.zombie_vars[ "zombie_powerup_fire_sale_on" ] == true;
}

// self = the perk trigger; player = the buyer. Set the trigger's cost to this
// player's price (10% off for Armory holders, base otherwise) RIGHT BEFORE the stock
// purchase reads self.cost, then allow the buy. Per-player + point-of-sale: whatever
// the player is shown they're charged, every time, at any range you can buy from.
function acc_perk_validate( player )
{
    perk = self.script_noteworthy;
    if ( isdefined( perk ) && isdefined( level._custom_perks ) && isdefined( level._custom_perks[ perk ] ) )
    {
        base = perk_base_cost( perk );
        if ( base > 0 )
        {
            if ( acc_mega_bottles::has_active_mega_perk( player, "specialty_additionalprimaryweapon" ) )
                self.cost = armory_discounted( base );
            else
                self.cost = base;
        }
    }
    return true; // always allow - we only adjust the price (no rotation lockout yet)
}

// DISPLAY ONLY (cosmetic): re-set the machine's shown hint to the discounted price so
// it's visible when you walk up. Does NOT touch self.cost (the CHARGE) - that is owned
// per-player by acc_perk_validate. A machine hint is ONE shared engine string (can't be
// per-player like the card), so we only discount it when EVERY player in range holds The
// Armory - that way the wall never advertises a discount a nearby non-Armory buyer won't
// get. The per-player info CARD remains the authoritative price for each player.
function armory_perk_pricing()
{
    level endon( "end_game" );
    level flag::wait_till( "initial_blackscreen_passed" );

    machines = [];
    for ( i = 0; i < 60; i++ )
    {
        machines = GetEntArray( "zombie_vending", "targetname" );
        if ( machines.size > 0 ) break;
        wait 0.5;
    }

    for ( ;; )
    {
        for ( i = 0; i < machines.size; i++ )
        {
            m = machines[ i ];
            if ( !isdefined( m ) || !isdefined( m.script_noteworthy ) ) continue;
            perk = m.script_noteworthy;
            if ( !isdefined( level._custom_perks ) || !isdefined( level._custom_perks[ perk ] ) ) continue;
            if ( !isdefined( level._custom_perks[ perk ].hint_string ) ) continue;

            base = perk_base_cost( perk );
            if ( base <= 0 ) continue;

            want_disc = all_in_range_have_armory( m.origin, ACC_PERK_INFO_RANGE_SQ );
            disp = ( want_disc ? armory_discounted( base ) : base );

            if ( !isdefined( m.acc_shown_cost ) || m.acc_shown_cost != disp )
            {
                m.acc_shown_cost = disp;
                m SetHintString( level._custom_perks[ perk ].hint_string, disp );
            }
        }
        wait 0.2;
    }
}

// Resolve a perk's BASE cost (level._custom_perks[perk].cost may be an int or, for
// Quick Revive, a function pointer). NOT the machine's live .cost (which we mutate).
function perk_base_cost( perk )
{
    c = level._custom_perks[ perk ].cost;
    if ( !isdefined( c ) ) return 0;
    if ( IsInt( c ) ) return c;
    return [[ c ]]();
}

function armory_discounted( base )
{
    n = int( base * 0.9 );
    return int( n / 10 ) * 10; // clean multiple of 10, like real ZM costs
}

// True only if at least one player is within range AND every player within range holds
// active Armory - so the shared wall hint shows the discount only when no nearby buyer
// would be over-promised a price they won't get. Solo: identical to "you have Armory".
function all_in_range_have_armory( origin, range_sq )
{
    any_in_range = false;
    players = GetPlayers();
    for ( i = 0; i < players.size; i++ )
    {
        p = players[ i ];
        if ( !isdefined( p ) || !isplayer( p ) ) continue;
        if ( DistanceSquared( p.origin, origin ) >= range_sq ) continue;
        any_in_range = true;
        if ( !acc_mega_bottles::has_active_mega_perk( p, "specialty_additionalprimaryweapon" ) )
            return false; // a non-Armory player is in range -> show base price
    }
    return any_in_range;
}

function watch_players()
{
    level endon( "end_game" );
    level flag::wait_till( "initial_blackscreen_passed" );

    machines = [];
    for ( i = 0; i < 60; i++ )
    {
        machines = GetEntArray( "zombie_vending", "targetname" );
        if ( machines.size > 0 ) break;
        wait 0.5;
    }
    acc_utility::log( "perk_info: tracking " + machines.size + " perk machines" );

    // PaP origin: read LIVE from the stock pack_a_punch trigger (script_noteworthy
    // "pack_a_punch", same lookup as acc_pap_levels::pap_cost_display_keeper) so the
    // info card follows the machine if it's relocated. Was hardcoded ( -700, 3700, 7.5 ),
    // which silently broke the card on any PaP move (docs/36 Stage 0). The literal is
    // kept ONLY as a fallback if the trigger never comes up.
    pap_org = ( -700, 3700, 7.5 );
    for ( i = 0; i < 60; i++ )
    {
        pap_ents = GetEntArray( "pack_a_punch", "script_noteworthy" );
        if ( pap_ents.size > 0 && isdefined( pap_ents[ 0 ] ) )
        {
            pap_org = pap_ents[ 0 ].origin;
            break;
        }
        wait 0.5;
    }

    for ( ;; )
    {
        players = GetPlayers();
        for ( i = 0; i < players.size; i++ )
        {
            p = players[ i ];
            if ( !isdefined( p ) || !isplayer( p ) ) continue;
            p update_for_player( machines, pap_org );
        }
        wait 0.2;
    }
}

// self = player
function update_for_player( machines, pap_org )
{
    nearest_id = undefined;
    best_sq = ACC_PERK_INFO_RANGE_SQ;

    for ( i = 0; i < machines.size; i++ )
    {
        m = machines[ i ];
        if ( !isdefined( m ) || !isdefined( m.script_noteworthy ) ) continue;
        d_sq = DistanceSquared( self.origin, m.origin );
        if ( d_sq < best_sq )
        {
            best_sq = d_sq;
            nearest_id = m.script_noteworthy;
        }
    }

    // PaP machine competes for the "nearest interactable" slot.
    pap_sq = DistanceSquared( self.origin, pap_org );
    if ( pap_sq < ACC_PAP_RANGE_SQ && pap_sq < best_sq )
    {
        best_sq = pap_sq;
        nearest_id = "pap";
    }

    code = 0; // 0 = hide the card
    if ( isdefined( nearest_id ) )
    {
        pidx = perk_card_index( nearest_id );
        // Context: show only what buying NOW gives you - base(0) / Mega upgrade(1)
        // / maxed(2) / PaP tier ladder(3). The Lua card renders the right bullets.
        mode = 0;
        if ( nearest_id == "pap" )
            mode = 3;
        else if ( self HasPerk( nearest_id ) )
        {
            if ( acc_mega_bottles::has_mega_perk( self, nearest_id ) )
                mode = 2;
            else
                mode = 1;
        }
        if ( pidx > 0 )
            code = pidx * 4 + mode;
    }

    // Armory (Mule Kick Mega) = all buys 10% cheaper. The CHARGE is already discounted
    // at point of sale (acc_perk_validate / _acc_pap_levels), so flag the card too (+64)
    // and the Lua shows the matching 10%-off price. The flag tracks the viewer's CURRENT
    // Armory status, so the card flips the instant they Mega Mule Kick / lose it.
    if ( code != 0 && acc_mega_bottles::has_active_mega_perk( self, "specialty_additionalprimaryweapon" ) )
        code += 64; // ACC_CARD_DISCOUNT_BIT (acc_hud.lua RenderCard decodes it)

    // Pack-a-Punch: push the held weapon's CURRENT tier so the Lua card shows the
    // NEXT tier only (not the whole T1-T5 ladder). The card CODE is constant 43 for
    // PaP, so the tier is tracked + pushed separately from acc_pinfo_code.
    if ( isdefined( nearest_id ) && nearest_id == "pap" )
    {
        tier = acc_pap_levels::get_card_tier( self, self GetCurrentWeapon() );
        if ( !isdefined( self.acc_pap_card_tier ) || self.acc_pap_card_tier != tier )
        {
            self.acc_pap_card_tier = tier;
            acc_lui::set_pap_tier( self, tier );
        }
    }

    if ( isdefined( self.acc_pinfo_code ) && self.acc_pinfo_code == code )
        return; // already pushed this exact card

    self.acc_pinfo_code = code;
    acc_lui::set_perk_card( self, code );
}

// Stable perk -> card index for the LUI lookup table (acc_hud.lua AccPerkCards).
// MUST match the Lua table. 0 = unknown/none.
function perk_card_index( id )
{
    switch ( id )
    {
    case "specialty_armorvest":               return 1;  // Jugger-Nog
    case "specialty_quickrevive":             return 2;  // Quick Revive
    case "specialty_fastreload":              return 3;  // Speed Cola
    case "specialty_doubletap2":              return 4;  // Double Tap 2.0
    case "specialty_staminup":                return 5;  // Stamin-Up
    case "specialty_additionalprimaryweapon": return 6;  // Mule Kick
    case "specialty_deadshot":                return 7;  // Deadshot
    case "specialty_widowswine":              return 8;  // Widow's Wine
    case "specialty_electriccherry":          return 9;  // PhD Flopper (over the cherry slot)
    case "pap":                               return 10; // Pack-a-Punch
    }
    return 0;
}
