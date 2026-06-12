// =============================================================================
// _acc_perk_aura_blast.gsc - Aura Blast (custom perk #9)
//
// Design reference: docs/13_perks.md (Aura Blast - 2,500 Points, 400u
// shockwave, 3s stun, 120s cooldown, full bosses immune).
//
// Strategy: hijack the stock-but-unfinished _zm_perk_electric_cherry module.
// Mod tools ship it with Treyarch's own "TODO update these to proper settings"
// placeholders (cost 10, machine model p7_zm_vending_nuke, Widow's Wine hint
// string) - it is a complete, registered perk pipeline (machine spawn, bottle
// drink, clientfields, power handling) for specialty_electriccherry waiting
// for real values. The entry script #using's the stock module (BOTH .gsc and
// .csc - the client module must be included or its clientfield registration
// mismatches and the level will not load); init() here then overwrites the
// level._custom_perks entry with Aura Blast's cost/hint and swaps the
// give/take threads for ours, so the cherry reload-attack behavior never
// attaches to players.
//
// Map wiring: script_struct targetname "zm_perk_machine", script_noteworthy
// "specialty_electriccherry", model "p7_zm_vending_nuke" (the model the stock
// module's machine_assets expects; TODO(acc-geom) custom machine model is a
// Phase 5 art task).
//
// Activation: crouch + melee chord. VERIFIED(acc): BO3 has no console command
// that fires a script notify (see _acc_weapon_abilities.gsc, which owns the
// ADS+melee chord for weapon abilities - this module deliberately uses a
// different chord). TODO(acc-input): real LUI keybind in Phase 4.
// TODO(acc-localize): hint shows the raw ZOMBIE_PERK_AURABLAST token until a
// .str localization pass; Mega tier (Mega Man) arrives with _acc_mega_bottles
// integration in Phase 3.
// =============================================================================

#using scripts\shared\util_shared;

#insert scripts\shared\shared.gsh;

#using scripts\zm\_zm_perks;
#using scripts\zm\_zm_utility;

#insert scripts\zm\_zm_perks.gsh;

#using scripts\zm\zm_abandoned_cyber_city\_acc_utility;
#using scripts\zm\zm_abandoned_cyber_city\_acc_mega_bottles;

#define ACC_AURA_COST          2500
#define ACC_AURA_RADIUS_SQ     160000      // 400u * 400u (docs/13_perks.md)
#define ACC_AURA_STUN_SEC      3.0
#define ACC_AURA_COOLDOWN_MS   120000      // 120s

#precache( "triggerstring", "ZOMBIE_PERK_AURABLAST" );

#namespace acc_perk_aura_blast;

// ---------------------------------------------------------------------------
// Init - MUST run after zm_usermap::main() (the stock cherry REGISTER_SYSTEM
// __init__ runs inside the bootstrap and populates level._custom_perks); the
// entry script calls this before the first game tick, so no vending trigger
// ever shows the placeholder values.
// ---------------------------------------------------------------------------

function init()
{
    if ( !isdefined( level._custom_perks ) || !isdefined( level._custom_perks[ PERK_ELECTRIC_CHERRY ] ) )
    {
        acc_utility::log( "aura blast: electric cherry pipeline missing, perk disabled" );
        return;
    }

    level._custom_perks[ PERK_ELECTRIC_CHERRY ].cost = ACC_AURA_COST;
    level._custom_perks[ PERK_ELECTRIC_CHERRY ].hint_string = &"ZOMBIE_PERK_AURABLAST";
    // Direct overwrite (not register_perk_threads - that API only assigns
    // when undefined, and cherry's threads are already registered).
    level._custom_perks[ PERK_ELECTRIC_CHERRY ].player_thread_give = &give_aura_blast;
    level._custom_perks[ PERK_ELECTRIC_CHERRY ].player_thread_take = &take_aura_blast;

    acc_utility::log( "aura blast registered over specialty_electriccherry (cost " + ACC_AURA_COST + ")" );
}

// ---------------------------------------------------------------------------
// Give / take (called on the player by _zm_perks)
// ---------------------------------------------------------------------------

function give_aura_blast()
{
    self thread aura_blast_listener();
}

function take_aura_blast( b_pause, str_perk, str_result )
{
    self notify( "acc_aura_blast_stop" );
}

// ---------------------------------------------------------------------------
// Ability
// ---------------------------------------------------------------------------

// Mega Man tier (docs/13_perks.md): 800u radius, 60s cooldown, 2 charges,
// bosses get a REDUCED stun instead of immunity. Read live from the Mega
// flag so applying a bottle mid-run upgrades the ability immediately.
function is_mega()
{
    return acc_mega_bottles::has_mega_perk( self, PERK_ELECTRIC_CHERRY );
}

function max_charges()
{
    if ( self is_mega() ) return 2;
    return 1;
}

function cooldown_ms()
{
    if ( self is_mega() ) return 60000;
    return ACC_AURA_COOLDOWN_MS;
}

function radius_sq()
{
    if ( self is_mega() ) return 640000; // 800u * 800u
    return ACC_AURA_RADIUS_SQ;
}

function aura_blast_listener()
{
    self endon( "disconnect" );
    self endon( "acc_aura_blast_stop" );

    self.acc_aura_charges = self max_charges();

    for ( ;; )
    {
        while ( !( self GetStance() == "crouch" && self MeleeButtonPressed() ) )
        {
            wait 0.05;
        }

        if ( self.acc_aura_charges <= 0 )
        {
            self iprintlnbold( "Aura Blast recharging" );
            wait 0.5; // debounce
            continue;
        }

        self.acc_aura_charges--;
        self thread recharge_one_charge();
        self iprintlnbold( "AURA BLAST" );
        level thread do_aura_blast( self.origin, self radius_sq(), self is_mega() );

        wait 0.5; // debounce so one chord press activates once
    }
}

function recharge_one_charge()
{
    self endon( "disconnect" );
    self endon( "acc_aura_blast_stop" );

    n_cooldown_sec = ( self cooldown_ms() ) / 1000;
    wait( n_cooldown_sec );

    if ( self.acc_aura_charges < self max_charges() )
    {
        self.acc_aura_charges++;
        self iprintlnbold( "Aura Blast ready" );
    }
}

function do_aura_blast( v_origin, n_radius_sq, b_mega )
{
    a_enemies = GetAITeamArray( level.zombie_team );

    foreach ( e_zombie in a_enemies )
    {
        if ( !IsAlive( e_zombie ) )
        {
            continue;
        }
        if ( DistanceSquared( e_zombie.origin, v_origin ) > n_radius_sq )
        {
            continue;
        }

        if ( IS_TRUE( e_zombie.acc_is_boss ) || IS_TRUE( e_zombie.acc_is_mini_boss ) )
        {
            // Base tier: bosses immune. Mega Man: reduced (~half) stun so the
            // fight isn't trivialized (docs/13_perks.md Mega Man mechanics).
            if ( IS_TRUE( b_mega ) )
            {
                e_zombie thread aura_stun( ACC_AURA_STUN_SEC * 0.5 );
            }
            continue;
        }

        e_zombie thread aura_stun( ACC_AURA_STUN_SEC );
    }
}

function aura_stun( n_seconds )
{
    self endon( "death" );

    if ( IS_TRUE( self.acc_aura_stunned ) )
    {
        return;
    }
    self.acc_aura_stunned = true;

    // VERIFIED(acc): ASMSetAnimationRate is the stock zombie slow mechanism
    // (Widow's Wine slow path) - see the stock-API pass in CHANGELOG.
    self ASMSetAnimationRate( 0.05 );
    wait n_seconds;

    if ( IsAlive( self ) )
    {
        self ASMSetAnimationRate( 1.0 );
    }
    self.acc_aura_stunned = false;
}
