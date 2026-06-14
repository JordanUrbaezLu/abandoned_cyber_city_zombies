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
#define ACC_AURA_EMP_STUN_SEC  1.0         // EMP elite: shorter 1s stun (docs/13:164)
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

    // VERIFIED(acc): the cherry module ALSO wires level.custom_laststand_func
    // (= an AOE that DoDamages zombies + pays STOCK points, bypassing our
    // economy) which _zm.gsc:2563-2570 threads for any cherry-perk holder -
    // i.e. every Aura Blast owner who goes down. Replace it with a
    // visionset-only stub (_zm.gsc skips the standard laststand visionset
    // whenever the cherry perk is held, so the stub must re-apply it).
    level.custom_laststand_func = &aura_blast_laststand;

    level thread fix_machine_identity();

    acc_utility::log( "aura blast registered over specialty_electriccherry (cost " + ACC_AURA_COST + ")" );
}

function aura_blast_laststand() // self = player, threaded from _zm.gsc:2569
{
    VisionSetLastStand( "zombie_last_stand", 1 );
}

// VERIFIED(acc): cherry's registered perk_machine_set_kvps is a Treyarch
// placeholder that names the machine/trigger "vending_marathon" - Stamin-Up's
// names (_zm_perk_electric_cherry.gsc:117-122 vs _zm_perk_staminup.gsh:9).
// Left alone, Stamin-Up's perk_machine_think captures our machine (stomping
// its model/FX with Stamin-Up's) while the cherry think scans
// "vending_electriccherry" and finds nothing. The KVPs are applied inside
// zm_usermap::main() BEFORE our init(), so fix the entities after the fact
// and bounce both think loops (they cache their entity scans; endon hook =
// str_perk + PERK_END_POWER_THREAD, _zm_perks.gsc:115-116).
function fix_machine_identity()
{
    level endon( "end_game" );

    t_use = undefined;
    for ( i = 0; i < 60; i++ )
    {
        a_triggers = GetEntArray( "zombie_vending", "targetname" );
        for ( j = 0; j < a_triggers.size; j++ )
        {
            if ( isdefined( a_triggers[ j ].script_noteworthy )
                 && a_triggers[ j ].script_noteworthy == PERK_ELECTRIC_CHERRY )
            {
                t_use = a_triggers[ j ];
                break;
            }
        }
        if ( isdefined( t_use ) ) break;
        wait 0.5;
    }

    if ( !isdefined( t_use ) )
    {
        acc_utility::log( "aura blast: no cherry vending trigger found, machine identity unfixed" );
        return;
    }

    t_use.target = "vending_electriccherry";
    if ( isdefined( t_use.machine ) )
    {
        t_use.machine.targetname = "vending_electriccherry";
    }

    level notify( "specialty_staminup" + PERK_END_POWER_THREAD );
    level notify( PERK_ELECTRIC_CHERRY + PERK_END_POWER_THREAD );
    util::wait_network_frame();
    level thread zm_perks::perk_machine_think( "specialty_staminup", level._custom_perks[ "specialty_staminup" ] );
    level thread zm_perks::perk_machine_think( PERK_ELECTRIC_CHERRY, level._custom_perks[ PERK_ELECTRIC_CHERRY ] );

    // The hint_string &"ZOMBIE_PERK_AURABLAST" isn't localized yet (no .str), so
    // the machine shows the raw token. Override the trigger's hint with readable
    // text and re-apply it (the perk think loop re-sets hints on power changes).
    t_use thread aura_hint_keeper();

    acc_utility::log( "aura blast: machine identity fixed (vending_electriccherry)" );
}

// self = the Aura Blast vending trigger. Keeps a readable hint on the machine
// until the Phase-4 localization pass replaces the raw token.
function aura_hint_keeper()
{
    level endon( "end_game" );
    self endon( "death" );

    for ( ;; )
    {
        self SetCursorHint( "HINT_NOICON" );
        self SetHintString( "Hold ^3&&1^7 for Aura Blast [Cost: " + ACC_AURA_COST + "]" );
        wait 1.5;
    }
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

        // Drain the chord before re-arming so holding it can't dump the
        // Mega tier's second charge automatically.
        while ( self MeleeButtonPressed() )
        {
            wait 0.05;
        }
        wait 0.25;
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

// docs/13_perks.md:164 base enemy rules: zombies -> full 3s stun; shielded
// elites -> shield down for the stun; teleporters -> no teleport during the
// stun; EMP elites -> 1s stun; mini-boss -> 50% duration (~1.5s) at BASE; full
// boss -> immune at base. Mega Man (docs:158/165): full boss becomes affectable
// at a reduced (~half) stun. The mini-boss already uses the partial rule, so it
// is the SAME 1.5s at base and Mega.
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

        // --- Full boss (Subroutine Core, .acc_is_boss; _acc_boss.gsc:362) ---
        // Base: immune. Mega Man: ~half stun (1.5s) so the fight isn't trivialized.
        if ( IS_TRUE( e_zombie.acc_is_boss ) )
        {
            if ( IS_TRUE( b_mega ) )
            {
                e_zombie thread aura_stun_with_effects( ACC_AURA_STUN_SEC * 0.5, false, false );
            }
            continue;
        }

        // --- Mini-boss (Juggernaut Host, .acc_is_mini_boss; _acc_boss.gsc:191) ---
        // Partial rule at BASE: 50% duration (~1.5s); Mega is the same window.
        if ( IS_TRUE( e_zombie.acc_is_mini_boss ) )
        {
            e_zombie thread aura_stun_with_effects( ACC_AURA_STUN_SEC * 0.5, false, false );
            continue;
        }

        // --- Elites (.acc_is_elite + .acc_elite_class; _acc_elites.gsc:190-191) ---
        if ( IS_TRUE( e_zombie.acc_is_elite ) )
        {
            // .acc_elite_class is one of "shielded" / "teleporter" / "emp".
            if ( e_zombie.acc_elite_class == "shielded" )
            {
                // Shield down for the stun: drop the frontal damage resist
                // (self.acc_elite_front_damage_resist, _acc_elites.gsc:233,
                //  consumed at _acc_damage.gsc) so shots land full while frozen.
                e_zombie thread aura_stun_with_effects( ACC_AURA_STUN_SEC, true, false );
            }
            else if ( e_zombie.acc_elite_class == "teleporter" )
            {
                // No teleport during the stun: the teleporter loop
                // (_acc_elites.gsc) checks .acc_aura_no_teleport before forceteleport.
                e_zombie thread aura_stun_with_effects( ACC_AURA_STUN_SEC, false, true );
            }
            else
            {
                // EMP elite ("emp"): shorter 1s stun (docs/13_perks.md:164).
                e_zombie thread aura_stun_with_effects( ACC_AURA_EMP_STUN_SEC, false, false );
            }
            continue;
        }

        // --- Regular zombie: full stun. ---
        e_zombie thread aura_stun_with_effects( ACC_AURA_STUN_SEC, false, false );
    }
}

// self = the enemy AI. Anim-rate freeze plus optional per-type side effects
// (shield-down for shielded elites, teleport-suppress for teleporters), scoped
// to exactly the stun window and restored afterward. Deduped by .acc_aura_stunned
// so an overlapping blast can't double-apply or strand a half-restore.
function aura_stun_with_effects( n_seconds, b_drop_shield, b_no_teleport )
{
    self endon( "death" );

    if ( IS_TRUE( self.acc_aura_stunned ) )
    {
        return;
    }
    self.acc_aura_stunned = true;

    // Shielded elite: temporarily remove the frontal damage resist so it takes
    // full damage while frozen. Save the original and restore on stun end.
    n_saved_shield = undefined;
    if ( IS_TRUE( b_drop_shield ) && isdefined( self.acc_elite_front_damage_resist ) )
    {
        n_saved_shield = self.acc_elite_front_damage_resist;
        self.acc_elite_front_damage_resist = undefined;
    }

    // Teleporter elite: set the suppress flag the teleporter loop honors.
    if ( IS_TRUE( b_no_teleport ) )
    {
        self.acc_aura_no_teleport = true;
    }

    // VERIFIED(acc): ASMSetAnimationRate is the stock zombie slow mechanism
    // (Widow's Wine slow path, _zm_perk_widows_wine.gsc:443/:501). If the zombie
    // is webbed when the stun ends, leave the rate alone (widows owns it).
    self ASMSetAnimationRate( 0.05 );
    wait n_seconds;

    // Restore side effects (self is guaranteed alive here: endon("death") would
    // have terminated this thread otherwise, dropping the temp fields with the
    // corpse - no leak on death).
    if ( isdefined( n_saved_shield ) )
    {
        self.acc_elite_front_damage_resist = n_saved_shield;
    }
    if ( IS_TRUE( b_no_teleport ) )
    {
        self.acc_aura_no_teleport = false;
    }

    if ( !IS_TRUE( self.b_widows_wine_slow )
         && !IS_TRUE( self.b_widows_wine_cocoon ) )
    {
        self ASMSetAnimationRate( 1.0 );
    }
    self.acc_aura_stunned = false;
}
