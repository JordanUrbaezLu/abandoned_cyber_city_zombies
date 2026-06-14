// =============================================================================
// _acc_mega_bottles.gsc - Empty Mega Bottle acquisition + perk-Mega upgrades
//
// Design reference: docs/13_perks.md (Mega Bottles system + Perk reference base/Mega).
//
// Acquisition: 1 bottle guaranteed per player on EVERY boss kill (mini + full).
// Usage: at a Lab perk machine currently dispensing a perk the player owns,
// consume 1 bottle to flag that perk as Mega'd on self.acc_mega_perks.
// Persistence: Mega flag stays across death (player re-buys perk -> re-apply).
// =============================================================================

#using scripts\shared\array_shared;
#using scripts\shared\hud_util_shared;
#using scripts\shared\util_shared;

#insert scripts\shared\shared.gsh;

#using scripts\zm\_zm_perks;
#using scripts\zm\_zm_utility;
#using scripts\zm\_zm_weapons;

#using scripts\zm\zm_abandoned_cyber_city\_acc_utility;

#namespace acc_mega_bottles;

// ---------------------------------------------------------------------------
// Init
// ---------------------------------------------------------------------------

function init()
{
    acc_utility::log( "mega_bottles init" );

    // VERIFIED(acc): the old GSC-only clientfield::register("toplayer", ...)
    // here was a map-load crash - stock registers every "toplayer" field in
    // BOTH VMs; the greybox HUD is a server-side hudelem (see
    // sync_bottle_count_to_client). LUI clientfield bridge returns in Phase 4.

    // Sticky-Mega lifecycle: stock calls these ON the player after a
    // successful perk drink / on perk loss (_zm_perks.gsc:652-655 / :956-958).
    // Re-buying a Mega'd perk re-applies its deltas (docs/13 persistence rule).
    level.perk_bought_func = &on_perk_bought;
    level.perk_lost_func = &on_perk_lost;

    level thread mega_machine_watcher();
}

function on_player_connect( player )
{
    player.acc_mega_bottles = 0;
    // Per-perk Mega flags. Key = specialty string (e.g. "specialty_armorvest");
    // Value = true if Mega'd. Persists through death for the run.
    player.acc_mega_perks = [];
    player sync_bottle_count_to_client();
    player thread flash_respawn_watcher();
}

// The Flash move-speed bonus is wiped on every (re)spawn: zm_usermap's
// giveCustomCharacters resets SetMoveSpeedScale(1) (zm_usermap.gsc:336).
// Re-apply when the player still holds a Mega'd Stamin-Up (retained-perk
// respawns re-give the perk via return_retained_perks).
function flash_respawn_watcher()
{
    self endon( "disconnect" );

    for ( ;; )
    {
        self waittill( "spawned_player" );
        self.acc_flash_speed = false;
        wait 0.25; // after the spawn-path speed reset
        if ( self HasPerk( "specialty_staminup" )
             && has_mega_perk( self, "specialty_staminup" ) )
        {
            self apply_flash_speed();
        }
    }
}

// ---------------------------------------------------------------------------
// Boss drop entry point. Called from _acc_boss.gsc on every boss kill,
// BOTH mini-boss (Juggernaut Host) and full boss (Subroutine Core).
//
// killer may be undefined (boss death by falling, rare edge case). In that
// case fall back to awarding all living players.
// ---------------------------------------------------------------------------

function on_boss_death( tier, killer, origin )
{
    // Rule per design: every PLAYER gets a Mega Bottle, not just the killer.
    // 4p co-op gets 4 bottles per boss kill.
    for ( i = 0; i < level.players.size; i++ )
    {
        player = level.players[ i ];
        if ( !isdefined( player ) ) continue;
        if ( !isplayer( player ) ) continue;
        player grant_bottle( 1, "boss_" + tier );
    }

    acc_utility::log( "mega_bottles: granted +1 to all players (" + tier + " boss)" );
}

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

function grant_bottle( amount, source_tag )
{
    if ( !isdefined( amount ) || amount <= 0 ) return;
    if ( !isdefined( self.acc_mega_bottles ) ) self.acc_mega_bottles = 0;

    self.acc_mega_bottles += amount;
    self sync_bottle_count_to_client();

    self iprintln( "+" + amount + " Empty Mega Bottle" +
                   ( amount > 1 ? "s" : "" ) );
}

function try_consume_bottle( player, amount )
{
    if ( !isdefined( player ) ) return false;
    if ( !isdefined( amount ) || amount <= 0 ) return false;
    if ( !isdefined( player.acc_mega_bottles ) ) return false;
    if ( player.acc_mega_bottles < amount ) return false;

    player.acc_mega_bottles -= amount;
    player sync_bottle_count_to_client();
    return true;
}

function get_bottle_count( player )
{
    if ( !isdefined( player.acc_mega_bottles ) ) return 0;
    return player.acc_mega_bottles;
}

// Check if a specific perk is Mega'd for this player. Other modules call
// this when applying perk effects to decide whether to layer on Mega deltas.
function has_mega_perk( player, specialty_string )
{
    if ( !isdefined( player ) ) return false;
    if ( !isdefined( player.acc_mega_perks ) ) return false;
    if ( !isdefined( player.acc_mega_perks[ specialty_string ] ) ) return false;
    return player.acc_mega_perks[ specialty_string ] == true;
}

// Set the Mega flag. Called from perk-machine interaction logic once a
// Mega Bottle is consumed successfully.
function set_mega_perk( player, specialty_string )
{
    if ( !isdefined( player ) ) return;
    if ( !isdefined( specialty_string ) ) return;
    if ( !isdefined( player.acc_mega_perks ) ) player.acc_mega_perks = [];
    player.acc_mega_perks[ specialty_string ] = true;

    mega_name = mega_display_name( specialty_string );
    player iprintln( "Mega unlocked: " + mega_name );
    level notify( "acc_mega_perk_applied", player, specialty_string );

    // Re-play the perk drink animation (the bottle is the Mega upgrade).
    player thread replay_perk_drink( specialty_string );
    // NOTE: the lower-left "MEGA <perk>" banner was REMOVED (user: not wanted).
    // The real ask is to glow the actual perk ICON, which the engine perk bar
    // doesn't expose to script - tracked as a separate, proper LUI task.
}

// ---------------------------------------------------------------------------
// Mega upgrade feedback: re-drink animation + glowing perk icon
// ---------------------------------------------------------------------------

// self = player. Re-play the stock perk DRINK animation (the perk's bottle
// weapon's own viewmodel) WITHOUT re-giving the perk - mirrors the stock
// vending drink flow (_zm_perks.gsc post-think) with robust switch-back.
function replay_perk_drink( perk )
{
    self endon( "disconnect" );
    self endon( "death" );

    if ( !isdefined( level._custom_perks ) || !isdefined( level._custom_perks[ perk ] )
         || !isdefined( level._custom_perks[ perk ].perk_bottle_weapon ) )
        return;

    w_bottle = level._custom_perks[ perk ].perk_bottle_weapon;

    self zm_utility::increment_is_drinking();
    self zm_utility::disable_player_move_states( true );

    original_weapon = self GetCurrentWeapon();
    self GiveWeapon( w_bottle );
    self SwitchToWeapon( w_bottle );

    self util::waittill_any_return( "weapon_change_complete", "player_downed", "death", "disconnect" );

    self zm_utility::enable_player_move_states();
    self TakeWeapon( w_bottle );

    if ( isdefined( original_weapon ) && original_weapon != level.weaponNone
         && !zm_utility::is_placeable_mine( original_weapon )
         && !zm_utility::is_melee_weapon( original_weapon ) )
        self zm_weapons::switch_back_primary_weapon( original_weapon );
    else
        self zm_weapons::switch_back_primary_weapon();

    self util::waittill_any_timeout( 3, "weapon_change_complete" );
    self zm_utility::decrement_is_drinking();
}

// self = player. The bottom perk bar is engine LUI (no GSC handle), so draw our
// OWN glowing icon per Mega'd perk using the same engine perk material + a
// continuous pulse. Stacks in a row so multiple Mega'd perks don't overlap.
// The stock perk bar is engine-LUI (untouchable) and the stock
// specialty_*_zombies HUD materials are NOT in this usermap (log: "could not
// find material"). So draw a guaranteed pulsing "white" glow badge + the Mega
// name per upgraded perk, stacked at the lower-left, as the "this perk is
// Mega'd and glowing" indicator.
function add_mega_glow_icon( perk )
{
    if ( !isdefined( self.acc_mega_glow ) ) self.acc_mega_glow = [];
    if ( isdefined( self.acc_mega_glow[ perk ] ) ) return; // already glowing

    idx = self.acc_mega_glow.size;
    y = -205 - idx * 24; // stack upward, clear of the shards/bottles counters
    col = mega_perk_color( perk );

    // The stock perk bar is engine-LUI and its perk HUD materials are NOT loadable
    // in a usermap, so we can't glow the real icon. Instead draw our OWN per-perk
    // GLOWING badge: a pulsing perk-colored bar (reads as a glow, not flat text)
    // with the Mega name over it. One per Mega'd perk, stacked at the lower-left.
    s = SpawnStruct();

    s.badge = self hud::createIcon( "white", 162, 22 );
    s.badge hud::setPoint( "BOTTOM_LEFT", "BOTTOM_LEFT", 12, y );
    s.badge.alignX = "left";
    s.badge.alignY = "middle";
    s.badge.color = col;
    s.badge.alpha = 0.55;
    s.badge.sort = 4;
    s.badge.hidewheninmenu = true;
    s.badge setPulseFX( 55, 700, 700 ); // the pulse = the "glow"

    s.label = self hud::createFontString( "default", 1.05 );
    s.label hud::setPoint( "BOTTOM_LEFT", "BOTTOM_LEFT", 20, y );
    s.label.alignX = "left";
    s.label.alignY = "middle";
    s.label.color = ( 1, 1, 1 );
    s.label.alpha = 1.0;
    s.label.sort = 5;
    s.label.hidewheninmenu = true;
    s.label SetText( "^7MEGA  " + mega_display_name( perk ) );

    self.acc_mega_glow[ perk ] = s;
}

// Per-perk signature colour for the Mega glow badge.
function mega_perk_color( perk )
{
    switch ( perk )
    {
    case "specialty_armorvest":               return ( 0.30, 0.70, 0.22 ); // Jug - green
    case "specialty_quickrevive":             return ( 0.30, 0.60, 1.00 ); // QR - blue
    case "specialty_fastreload":              return ( 0.45, 0.90, 0.45 ); // Speed - light green
    case "specialty_doubletap2":              return ( 0.90, 0.30, 0.20 ); // DT - red
    case "specialty_staminup":                return ( 0.92, 0.80, 0.20 ); // Stamin - yellow
    case "specialty_additionalprimaryweapon": return ( 0.80, 0.45, 0.20 ); // Mule - orange
    case "specialty_deadshot":                return ( 0.65, 0.72, 0.82 ); // Deadshot - steel
    case "specialty_widowswine":              return ( 0.55, 0.25, 0.65 ); // Widow's - purple
    case "specialty_electriccherry":          return ( 0.95, 0.50, 0.12 ); // Aura - orange-red
    }
    return ( 0.40, 0.85, 1.0 ); // default cyan
}

// ---------------------------------------------------------------------------
// Perk-machine Mega interaction.
//
// VERIFIED(acc): a perk owner can never fire the STOCK vending trigger -
// check_player_has_perk (_zm_perks.gsc:865-895) runs SetInvisibleToPlayer
// every 0.1s for owners, so listening on the stock trigger never sees them.
// The known-good pattern is a PARALLEL trigger_radius_use at the same origin
// (stock spawn pattern _zm_perks.gsc:1513) with INVERTED per-player
// visibility: shown only to players who own the base perk, hold a bottle,
// and haven't Mega'd it yet.
// ---------------------------------------------------------------------------

function mega_machine_watcher()
{
    level endon( "end_game" );

    // Vending triggers spawn during the stock load flow (perk __main__ +
    // perk_machine_spawn_init); poll briefly until they exist.
    triggers = [];
    for ( i = 0; i < 60; i++ )
    {
        triggers = GetEntArray( "zombie_vending", "targetname" );
        if ( triggers.size > 0 ) break;
        wait 0.5;
    }

    if ( triggers.size == 0 )
    {
        acc_utility::log( "mega: no zombie_vending triggers found, Mega upgrades unavailable" );
        return;
    }

    for ( i = 0; i < triggers.size; i++ )
    {
        level thread mega_trigger_think( triggers[ i ] );
    }
    acc_utility::log( "mega: parallel upgrade triggers on " + triggers.size + " machines" );
}

function mega_trigger_think( t_vending )
{
    level endon( "end_game" );

    perk = t_vending.script_noteworthy;
    if ( !isdefined( perk ) ) return;

    t_mega = Spawn( "trigger_radius_use", t_vending.origin, 0, 40, 80 );
    t_mega.targetname = "acc_mega_vending";
    t_mega TriggerIgnoreTeam();
    t_mega UseTriggerRequireLookAt();
    t_mega SetCursorHint( "HINT_NOICON" );
    // TODO(acc-verify): raw-string hint (community-standard but unverified
    // against our toolchain; stock uses precached istrings). If blank on
    // first compile, precache a triggerstring instead.
    t_mega SetHintString( "Hold ^3&&1^7 for Mega upgrade [Cost: 1 Mega Bottle]" );
    t_mega thread mega_trigger_visibility( perk );

    for ( ;; )
    {
        t_mega waittill( "trigger", player );
        if ( !isdefined( player ) || !isplayer( player ) ) continue;
        if ( !( player HasPerk( perk ) ) ) continue;
        if ( has_mega_perk( player, perk ) ) continue;

        if ( try_apply_mega( player, perk ) )
        {
            t_mega PlaySound( "evt_bottle_dispense" );
        }
        wait 0.5;
    }
}

function mega_trigger_visibility( perk )
{
    level endon( "end_game" );
    self endon( "death" );

    for ( ;; )
    {
        players = GetPlayers();
        for ( i = 0; i < players.size; i++ )
        {
            p = players[ i ];
            b_show = ( p HasPerk( perk ) )
                     && !has_mega_perk( p, perk )
                     && get_bottle_count( p ) > 0;
            self SetInvisibleToPlayer( p, !b_show );
        }
        wait 0.25;
    }
}

function try_apply_mega( player, specialty_string )
{
    if ( has_mega_perk( player, specialty_string ) )
    {
        player iprintln( "Perk already Mega'd" );
        return false;
    }

    if ( !try_consume_bottle( player, 1 ) )
    {
        player iprintln( "Need 1 Empty Mega Bottle" );
        return false;
    }

    set_mega_perk( player, specialty_string );

    // Apply the Mega deltas immediately (player owns the base perk at the
    // moment of upgrade - the trigger visibility gate guarantees it).
    apply_mega_effects( player, specialty_string );

    return true;
}

// ---------------------------------------------------------------------------
// Mega effect application. Called on upgrade AND on every (re)buy of a
// Mega'd perk (sticky persistence, docs/13_perks.md). Per-perk status:
//   IMPLEMENTED here: Ultimate Tank (+100 max HP), The Flash (+12% speed).
//   IMPLEMENTED elsewhere, read live from the Mega flag: American Sniper
//     (x1.75 headshot, _acc_damage), Spiderman (melee OHK, _acc_damage),
//     Mega Man (800u/60s/2 charges, _acc_perk_aura_blast).
//   TODO(acc-mega): Gun Slinger (fire rate), Savior (revive speed),
//     Sleight Expert (reload), Armory (ammo/grenade caps) - need engine-side
//     hooks (Phase 3/4); the flag is set, effects log-only.
// ---------------------------------------------------------------------------

function apply_mega_effects( player, specialty_string )
{
    switch ( specialty_string )
    {
    case "specialty_armorvest":
        // Ultimate Tank: +100 max HP on top of Jug. VERIFIED(acc):
        // n_player_health_boost is the only field the stock "health_reboot"
        // recompute adds (_zm_perks.gsc:828-831), and that recompute re-runs
        // at every revive - so the bonus survives downs. A bare SetMaxHealth
        // would be wiped by the next recompute.
        player.n_player_health_boost = 100;
        player zm_perks::perk_set_max_health_if_jugg( "health_reboot", true, false );
        break;

    case "specialty_staminup":
        player apply_flash_speed();
        break;

    case "specialty_deadshot":       // American Sniper - live in _acc_damage
    case "specialty_widowswine":     // Spiderman - live in _acc_damage
    case "specialty_electriccherry": // Mega Man - live in _acc_perk_aura_blast
        break;

    default:
        acc_utility::log( "mega effect pending implementation: " + specialty_string );
        break;
    }
}

function apply_flash_speed()
{
    // VERIFIED(acc): SetMoveSpeedScale is ABSOLUTE - read-modify-write here
    // gets erased by other writers (Neural Boots hook, Reflex T1). Set the
    // flag and recompute through the single owner in acc_utility.
    self.acc_flash_speed = true;
    acc_utility::recompute_move_speed( self );
}

// Stock lifecycle hooks (self = player).

function on_perk_bought( perk )
{
    if ( has_mega_perk( self, perk ) )
    {
        apply_mega_effects( self, perk );
    }
}

function on_perk_lost( perk )
{
    // Remove the Mega glow badge for the lost perk.
    if ( isdefined( self.acc_mega_glow ) && isdefined( self.acc_mega_glow[ perk ] ) )
    {
        g = self.acc_mega_glow[ perk ];
        if ( isdefined( g.badge ) ) g.badge hud::destroyElem();
        if ( isdefined( g.label ) ) g.label hud::destroyElem();
        self.acc_mega_glow[ perk ] = undefined;
    }

    if ( perk == "specialty_armorvest" )
    {
        // Next health_reboot recompute drops the Ultimate Tank bonus.
        self.n_player_health_boost = 0;
    }

    if ( perk == "specialty_staminup" && IS_TRUE( self.acc_flash_speed ) )
    {
        self.acc_flash_speed = false;
        acc_utility::recompute_move_speed( self );
    }
}

// ---------------------------------------------------------------------------
// Display names for Mega variants (docs/13_perks.md source of truth).
// ---------------------------------------------------------------------------

function mega_display_name( specialty_string )
{
    switch ( specialty_string )
    {
    case "specialty_armorvest":              return "Ultimate Tank";         // Jug
    case "specialty_quickrevive":            return "Savior";                 // QR
    case "specialty_fastreload":             return "Sleight of Hand Expert"; // Speed Cola
    // VERIFIED(acc): stock ZM specialty strings from _zm_perks.gsh:26-27
    // (the old specialty_rof/specialty_longersprint never match in ZM).
    case "specialty_doubletap2":             return "Gun Slinger";            // Double Tap
    case "specialty_staminup":               return "The Flash";              // Stamin-Up
    case "specialty_additionalprimaryweapon":return "The Armory";             // Mule Kick
    // VERIFIED(acc): these are the specialties our machines actually register:
    // Deadshot + Widow's Wine are the stock modules (_zm_perks.gsh:29/:35);
    // Aura Blast hijacks the stock electric-cherry pipeline (see
    // _acc_perk_aura_blast.gsc), so its specialty is the cherry's.
    case "specialty_deadshot":               return "American Sniper";        // Deadshot
    case "specialty_widowswine":             return "Spiderman";              // Widow's Wine
    case "specialty_electriccherry":         return "Mega Man";               // Aura Blast
    }
    return "Mega Perk";
}

// ---------------------------------------------------------------------------
// HUD sync
// ---------------------------------------------------------------------------

function sync_bottle_count_to_client()
{
    if ( !isdefined( self.acc_mega_bottles ) ) self.acc_mega_bottles = 0;
    if ( !isdefined( self.acc_bottle_hud ) )
    {
        self.acc_bottle_hud = self hud::createFontString( "default", 1.5 );
        // VERIFIED(acc): setPoint only matches "BOTTOM_LEFT"/"BOTTOM LEFT"
        // (hud_util_shared.gsc:120-124); "BOTTOMLEFT" silently anchors center.
        self.acc_bottle_hud hud::setPoint( "BOTTOM_LEFT", "BOTTOM_LEFT", 10, -110 );
        self.acc_bottle_hud.color = ( 0.95, 0.78, 0.2 );
        self.acc_bottle_hud.hidewheninmenu = true;
    }
    // Labeled inline (SetText accepts raw strings). Hidden until first bottle.
    self.acc_bottle_hud SetText( "^3MEGA BOTTLES ^7" + self.acc_mega_bottles );
    self.acc_bottle_hud.alpha = ( self.acc_mega_bottles > 0 ? 0.9 : 0 );
}
