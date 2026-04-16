// =============================================================================
// _acc_mega_bottles.gsc - Empty Mega Bottle acquisition + perk-Mega upgrades
//
// Design reference: docs/13_perks.md (Mega Bottles - upgraded perk variants).
//
// Acquisition: 1 bottle guaranteed per player on EVERY boss kill (mini + full).
// Usage: at a Lab perk machine currently dispensing a perk the player owns,
// consume 1 bottle to flag that perk as Mega'd on self.acc_mega_perks.
// Persistence: Mega flag stays across death (player re-buys perk -> re-apply).
// =============================================================================

#using scripts\shared\array_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\util_shared;

#using scripts\zm\zm_abandoned_cyber_city\_acc_utility;

// Clientfield for HUD counter.
#define ACC_BOTTLES_CF_NAME "acc_mega_bottles"
#define ACC_BOTTLES_CF_BITS 4  // 0..15 max

// ---------------------------------------------------------------------------
// Init
// ---------------------------------------------------------------------------

init()
{
    _acc_utility::log( "mega_bottles init" );

    // Register clientfield for HUD counter. Signature verified in
    // docs/16_gsc_reference.md.
    clientfield::register(
        "toplayer",
        ACC_BOTTLES_CF_NAME,
        1,
        ACC_BOTTLES_CF_BITS,
        "int"
    );
}

on_player_connect( player )
{
    player.acc_mega_bottles = 0;
    // Per-perk Mega flags. Key = specialty string (e.g. "specialty_armorvest");
    // Value = true if Mega'd. Persists through death for the run.
    player.acc_mega_perks = [];
    player sync_bottle_count_to_client();
}

// ---------------------------------------------------------------------------
// Boss drop entry point. Called from _acc_boss.gsc on every boss kill,
// BOTH mini-boss (Juggernaut Host) and full boss (Subroutine Core).
//
// killer may be undefined (boss death by falling, rare edge case). In that
// case fall back to awarding all living players.
// ---------------------------------------------------------------------------

on_boss_death( tier, killer, origin )
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

    _acc_utility::log( "mega_bottles: granted +1 to all players (" + tier + " boss)" );
}

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

grant_bottle( amount, source_tag )
{
    if ( !isdefined( amount ) || amount <= 0 ) return;
    if ( !isdefined( self.acc_mega_bottles ) ) self.acc_mega_bottles = 0;

    self.acc_mega_bottles += amount;
    self sync_bottle_count_to_client();

    self iprintln( "+" + amount + " Empty Mega Bottle" +
                   ( amount > 1 ? "s" : "" ) );
}

try_consume_bottle( player, amount )
{
    if ( !isdefined( player ) ) return false;
    if ( !isdefined( amount ) || amount <= 0 ) return false;
    if ( !isdefined( player.acc_mega_bottles ) ) return false;
    if ( player.acc_mega_bottles < amount ) return false;

    player.acc_mega_bottles -= amount;
    player sync_bottle_count_to_client();
    return true;
}

get_bottle_count( player )
{
    if ( !isdefined( player.acc_mega_bottles ) ) return 0;
    return player.acc_mega_bottles;
}

// Check if a specific perk is Mega'd for this player. Other modules call
// this when applying perk effects to decide whether to layer on Mega deltas.
has_mega_perk( player, specialty_string )
{
    if ( !isdefined( player ) ) return false;
    if ( !isdefined( player.acc_mega_perks ) ) return false;
    if ( !isdefined( player.acc_mega_perks[ specialty_string ] ) ) return false;
    return player.acc_mega_perks[ specialty_string ] == true;
}

// Set the Mega flag. Called from perk-machine interaction logic once a
// Mega Bottle is consumed successfully.
set_mega_perk( player, specialty_string )
{
    if ( !isdefined( player ) ) return;
    if ( !isdefined( specialty_string ) ) return;
    if ( !isdefined( player.acc_mega_perks ) ) player.acc_mega_perks = [];
    player.acc_mega_perks[ specialty_string ] = true;

    mega_name = mega_display_name( specialty_string );
    player iprintln( "Mega unlocked: " + mega_name );
    level notify( "acc_mega_perk_applied", player, specialty_string );
}

// ---------------------------------------------------------------------------
// Perk-machine interaction entry point.
//
// Called from the perk machine's "use" handler when:
//   - The player already owns the base perk.
//   - The machine is currently dispensing that perk (per-round rotation).
//   - The player has at least 1 Mega Bottle.
//
// The perk-machine code first offers the Mega prompt; only if the player
// confirms does it call this function.
// ---------------------------------------------------------------------------

try_apply_mega( player, specialty_string )
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

    // The perk effect system reads the Mega flag when (re-)applying the
    // perk's on_acquire function. It's expected that any already-equipped
    // Mega deltas get applied immediately here too.
    // TODO(acc-perks): call the perk's re-apply hook if player already has
    // the base perk equipped at the moment of Mega.
    reapply_perk_if_owned( player, specialty_string );

    return true;
}

// Stub: re-run the perk's acquire function to layer Mega effects on top.
// Phase 3 implementation work lives in _acc_perks.gsc.
reapply_perk_if_owned( player, specialty_string )
{
    // TODO(acc-perks): dispatch to `_acc_perks::reapply_perk( player, specialty )`.
    _acc_utility::log( "mega: reapply requested for " + specialty_string );
}

// ---------------------------------------------------------------------------
// Display names for Mega variants (docs/13_perks.md source of truth).
// ---------------------------------------------------------------------------

mega_display_name( specialty_string )
{
    switch ( specialty_string )
    {
    case "specialty_armorvest":              return "Ultimate Tank";         // Jug
    case "specialty_quickrevive":            return "Savior";                 // QR
    case "specialty_fastreload":             return "Sleight of Hand Expert"; // Speed Cola
    case "specialty_rof":                    return "Gun Slinger";            // Double Tap
    case "specialty_longersprint":           return "The Flash";              // Stamin-Up
    case "specialty_additionalprimaryweapon":return "The Armory";             // Mule Kick
    case "specialty_acc_deadshot":           return "American Sniper";        // Deadshot
    case "specialty_acc_widows_wine":        return "Spiderman";              // Widow's Wine
    case "specialty_acc_aura_blast":         return "Mega Man";               // Aura Blast
    }
    return "Mega Perk";
}

// ---------------------------------------------------------------------------
// HUD sync
// ---------------------------------------------------------------------------

sync_bottle_count_to_client()
{
    if ( !isdefined( self.acc_mega_bottles ) ) self.acc_mega_bottles = 0;
    self clientfield::set_to_player( ACC_BOTTLES_CF_NAME, self.acc_mega_bottles );
}
