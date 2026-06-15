// =============================================================================
// _acc_perk_phd_flopper.gsc - PhD Flopper (perk #9)
//
// Design reference: docs/13_perks.md / docs/perk_abilities.md (PhD Flopper).
//
// Strategy: HIJACK the stock-but-unfinished _zm_perk_electric_cherry pipeline (its
// registered machine/bottle/clientfield/power scaffold) and present it as PhD Flopper.
// We do this rather than register specialty_phdflopper from scratch because:
//   (1) specialty_phdflopper is a ZERO-init stub in BO3 (no stock ability + the real
//       p9_sur_machine_phd_slider vending model is NOT in this install - it needs a
//       game-rip import, same wall the cherry machine hit), whereas the cherry
//       pipeline is fully registered with a working machine entity (map_source
//       entity 43) + the stock nuke vending model, which already ships.
//   (2) the stock p7_zm_vending_nuke placeholder reads as an explosion/ordnance
//       machine - a fine thematic fit for PhD (the explode-on-slide perk), so no model
//       import is needed (user call, 2026-06-15).
// So the perk's underlying specialty stays specialty_electriccherry (PERK_ELECTRIC_CHERRY)
// for all HasPerk / Mega-flag / rotation / HUD plumbing; only its PRESENTATION (icon,
// name, hint, card) and ABILITY are PhD.
//
// Ability (adapted from the shipped HarryBo21/ColDog PhD Flopper,
// tmp/zm_countryside/scripts/zm/_zm_perk_phdflopper.gsc):
//   - Fall + self-explosive immunity: a level.perk_damage_override func returning 0 for
//     MOD_FALLING / MOD_GRENADE(_SPLASH) / MOD_PROJECTILE(_SPLASH) / MOD_EXPLOSIVE(_SPLASH)
//     when the player holds the perk. VERIFIED(acc): _zm.gsc:5231-5236 iterates
//     level.perk_damage_override on player damage and a returned value REPLACES the damage.
//   - Slide-to-explode: starting a slide fires a grenade-explosion nova that clears nearby
//     trash (on a cooldown). BO3 zombies has the sprint-slide but NO dolphin-dive (confirmed
//     in-game), so we trigger off the engine isSliding() directly - NOT the shipped countryside
//     jump -> land-sliding -> Z-drop dive. The blast uses the stock def_explosion FX +
//     evt_nuke_flash (Nuke powerup) sound + an Earthquake - all ship in every zm map (the FX is
//     framework-precached, the sound loads with the Nuke powerup), so this needs NO new FX/sound
//     asset, NO new clientfields and NO .csc. NOTE: def_explosion is orange/white, not purple -
//     a true purple blast needs a custom/imported FX (FX Editor or game-rip); see the buildlog.
//   - Explode-on-down: PhD-flavoured laststand (you flop down, you go boom) - also replaces
//     the stock cherry electrocution-on-down (foreign element + pays stock points).
//   - Mega "PhD Slider": a bigger/stronger slide + down explosion on a shorter slide cooldown
//     (read live from the Mega flag).
//
// No .csc: the stock _zm_perk_electric_cherry.csc (already #using'd by the entry .csc) owns
// the cherry client clientfield/FX; we add none. Icon = Ronan Cyberpunk "exo_flopper"
// (i_acc_perk_phd_{base,mega}) on the LUI perk bar.
//
// init() is called from the entry script main() AFTER zm_usermap::main() (which runs the
// stock cherry REGISTER_SYSTEM that populates level._custom_perks), before the first tick.
// =============================================================================

#using scripts\shared\util_shared;
#using scripts\shared\ai\zombie_utility;

#insert scripts\shared\shared.gsh;

#using scripts\zm\_zm_perks;
#using scripts\zm\_zm_utility;

#insert scripts\zm\_zm_perks.gsh;

#using scripts\zm\zm_abandoned_cyber_city\_acc_utility;
#using scripts\zm\zm_abandoned_cyber_city\_acc_mega_bottles;

#define ACC_PHD_COST                    2500
#define ACC_PHD_EXPLODE_RADIUS          300     // slide/down nova radius (base)
#define ACC_PHD_MEGA_EXPLODE_RADIUS     500     // PhD Slider Mega radius
#define ACC_PHD_EXPLODE_BASE_DAMAGE     2000    // floor damage (round-scaled up below)
#define ACC_PHD_SLIDE_CD                8        // seconds between slide explosions (base)
#define ACC_PHD_SLIDE_CD_MEGA           5        // PhD Slider Mega: shorter slide cooldown

// Corpse-fling (mirrors stock Thunder Wall _zm_aat_thunder_wall.gsh:16-18). Only zombies the nova
// actually KILLS are gibbed + flung; the count is capped so a big crowd can't ragdoll-storm the
// network. Force/up bias tunable.
#define ACC_PHD_FLING_FORCE             125      // launch impulse (stock thunder wall = 100)
#define ACC_PHD_FLING_UP                30       // upward bias added pre-normalize (stock = 30)
#define ACC_PHD_FLING_MAX               6        // max corpses flung per blast (stock cap = 6)
#define ACC_PHD_FLING_MAX_MEGA          8        // PhD Slider flings a few more

// Purple/void blast FX: the Apothicon Fury "spawn-in" burst (stock dlc4/genesis .efx, source
// present in the Mod Tools - verified 2026-06-15; also listed in the .zone). def_explosion
// (orange, framework-precached) is the runtime fallback if this fails to load.
#define ACC_PHD_EXPLODE_FX              "dlc4/genesis/fx_apothicon_fury_spawn_in_exp"

#precache( "fx", ACC_PHD_EXPLODE_FX );

#namespace acc_perk_phd_flopper;

// ---------------------------------------------------------------------------
// Init - overwrite the registered cherry pipeline's cost/hint/give/take + laststand,
// and register the damage-immunity override. Mirrors the old Aura Blast hijack.
// ---------------------------------------------------------------------------

function init()
{
    if ( !isdefined( level._custom_perks ) || !isdefined( level._custom_perks[ PERK_ELECTRIC_CHERRY ] ) )
    {
        acc_utility::log( "phd flopper: electric cherry pipeline missing, perk disabled" );
        return;
    }

    // Register the purple blast FX handle (the #precache above made it loadable).
    level._effect[ "acc_phd_purple" ] = ACC_PHD_EXPLODE_FX;

    level._custom_perks[ PERK_ELECTRIC_CHERRY ].cost = ACC_PHD_COST;
    // Readable raw hint (no localized PhD token exists; &&1 = use button, engine-substituted).
    level._custom_perks[ PERK_ELECTRIC_CHERRY ].hint_string = "Hold ^3&&1^7 for PhD Flopper [Cost: " + ACC_PHD_COST + "]";
    // Direct overwrite (register_perk_threads only assigns when undefined; cherry's are set).
    level._custom_perks[ PERK_ELECTRIC_CHERRY ].player_thread_give = &give_phd;
    level._custom_perks[ PERK_ELECTRIC_CHERRY ].player_thread_take = &take_phd;

    // Replace the stock cherry electrocution-on-down with a PhD explosion-on-down.
    // (_zm.gsc skips the standard laststand visionset for cherry holders, so re-apply it.)
    level.custom_laststand_func = &phd_laststand;

    // Fall + self-explosive immunity (the defining PhD trait). Registered ONCE; the engine
    // calls every level.perk_damage_override func on player damage (_zm.gsc:5231).
    zm_perks::register_perk_damage_override_func( &phd_damage_override );

    level thread fix_machine_identity();

    acc_utility::log( "phd flopper registered over specialty_electriccherry (cost " + ACC_PHD_COST + ")" );
}

// ---------------------------------------------------------------------------
// Damage immunity (self = the damaged player). Signature matches the dispatch at
// _zm.gsc:5235 (10 positional args); return the final damage (0 = negate).
// ---------------------------------------------------------------------------

function phd_damage_override( e_inflictor, e_attacker, n_damage, str_flags, str_mod, w_weapon, v_point, v_dir, str_hit_loc, n_offset_time )
{
    if ( !( self HasPerk( PERK_ELECTRIC_CHERRY ) ) )
    {
        return n_damage;
    }

    switch ( str_mod )
    {
    case "MOD_FALLING":
    case "MOD_GRENADE":
    case "MOD_GRENADE_SPLASH":
    case "MOD_PROJECTILE":
    case "MOD_PROJECTILE_SPLASH":
    case "MOD_EXPLOSIVE":
    case "MOD_EXPLOSIVE_SPLASH":
        return 0;
    }
    return n_damage;
}

// ---------------------------------------------------------------------------
// Give / take (self = player).
// ---------------------------------------------------------------------------

function give_phd()
{
    self thread phd_slide_watcher();
}

function take_phd( b_pause, str_perk, str_result )
{
    self notify( "acc_phd_stop" );
}

// PhD-flavoured laststand: flop down -> explode. self = player, threaded from _zm on down.
function phd_laststand()
{
    VisionSetLastStand( "zombie_last_stand", 1 );
    self phd_explode();
}

// ---------------------------------------------------------------------------
// Slide-to-explode: fire the nova when the player starts a slide. BO3 zombies has the
// sprint-slide but NO dolphin-dive (confirmed in-game 2026-06-15), so we trigger off
// isSliding() directly instead of the shipped countryside jump -> land-sliding -> Z-drop
// dive (there is no airborne dive + no height drop to gate on here). A cooldown keeps it
// from being a spammable free AOE; the Mega ("PhD Slider") shortens it.
// ---------------------------------------------------------------------------

function phd_slide_watcher()
{
    self endon( "disconnect" );
    self endon( "acc_phd_stop" );

    for ( ;; )
    {
        // Wait for a slide to begin (false -> true transition).
        while ( !( self isSliding() ) )
        {
            wait 0.05;
        }

        self phd_explode();

        // Cooldown: ignore further slides for a beat (Mega shortens it)...
        n_cd = ( acc_mega_bottles::has_mega_perk( self, PERK_ELECTRIC_CHERRY ) ? ACC_PHD_SLIDE_CD_MEGA : ACC_PHD_SLIDE_CD );
        wait n_cd;
        // ...then wait out the current slide so one long slide can't immediately re-trigger.
        while ( self isSliding() )
        {
            wait 0.05;
        }
    }
}

// self = player. An explosive nova that damages/clears nearby zombies AND makes the ones it kills
// visibly explode (head-gib + torso gore burst + a capped corpse-fling). The burst CENTRES on the
// zombie you slid into (the nearest in-radius zombie = the impact point), not on the player.
// MOD_GRENADE_SPLASH (explosive) so PhD holders are immune to their own boom via
// phd_damage_override; kills route through DoDamage -> the zombie death callback -> our _acc_points
// economy. Mega ("PhD Slider") is read live from the Mega flag for a bigger radius + damage.
function phd_explode()
{
    self endon( "disconnect" );

    b_mega   = acc_mega_bottles::has_mega_perk( self, PERK_ELECTRIC_CHERRY );
    n_radius = ( IS_TRUE( b_mega ) ? ACC_PHD_MEGA_EXPLODE_RADIUS : ACC_PHD_EXPLODE_RADIUS );
    n_damage = phd_explode_damage( b_mega );

    v_origin    = self.origin;                 // slide centre: radius / damage / self-immunity ref
    n_radius_sq = n_radius * n_radius;
    a_zombies   = GetAITeamArray( level.zombie_team );

    // The blast CENTRES on the zombie you slid into (nearest in-radius zombie) so the burst spawns
    // at the impact point, not on the sliding player (previously it played at self.origin = on you).
    // Falls back to the player if you slid into open air.
    z_near    = undefined;
    n_best_sq = undefined;
    for ( i = 0; i < a_zombies.size; i++ )
    {
        z = a_zombies[ i ];
        if ( !IsAlive( z ) )
        {
            continue;
        }
        n_d_sq = DistanceSquared( z.origin, v_origin );
        if ( n_d_sq > n_radius_sq )
        {
            continue;
        }
        if ( !isdefined( n_best_sq ) || n_d_sq < n_best_sq )
        {
            z_near    = z;
            n_best_sq = n_d_sq;
        }
    }
    v_burst = ( isdefined( z_near ) ? z_near.origin : v_origin );

    // VISIBLE blast at the impact point: PURPLE Apothicon void-burst (registered in init from
    // ACC_PHD_EXPLODE_FX); fall back to the stock orange def_explosion only if it didn't load.
    // Earthquake adds the screen-shake punch (engine builtin).
    if ( isdefined( level._effect[ "acc_phd_purple" ] ) )
    {
        PlayFX( level._effect[ "acc_phd_purple" ], v_burst );
    }
    else if ( isdefined( level._effect[ "def_explosion" ] ) )
    {
        PlayFX( level._effect[ "def_explosion" ], v_burst );
    }
    Earthquake( 0.45, 0.6, v_burst, n_radius + 200 );

    // AUDIBLE boom: the Nuke powerup "WHOOMP" (evt_nuke_flash) - guaranteed loaded (the Nuke powerup
    // ships in every zm map). 2D/owner-anchored, like the stock nuke_flash.
    self PlaySound( "evt_nuke_flash" );

    // Per-zombie EXPLODE: every zombie the nova KILLS pops apart - head-gib + a torso gore burst,
    // then a capped corpse-fling away from the blast. Ordering mirrors the studio patterns:
    //   * Nuke (_zm_powerup_nuke.gsc:139/145): zombie_head_gib() on the LIVE zombie, THEN dodamage
    //     (head_gib is non-blocking - it gibs the head + threads a DoT, then returns).
    //   * Thunder Wall (_zm_aat_thunder_wall.gsc:122/136-137): DoDamage, THEN StartRagdoll+LaunchRagdoll.
    // Gating on (health <= n_damage) restricts gib/fling to trash the nova actually kills, so a
    // living BOSS (Brutus/Panzer/Glitch - all on level.zombie_team with huge HP) is only chipped,
    // never head-gibbed or ragdolled mid-fight.
    n_flung = 0;
    n_cap   = ( IS_TRUE( b_mega ) ? ACC_PHD_FLING_MAX_MEGA : ACC_PHD_FLING_MAX );
    for ( i = 0; i < a_zombies.size; i++ )
    {
        z = a_zombies[ i ];
        if ( !IsAlive( z ) )
        {
            continue;
        }
        if ( DistanceSquared( z.origin, v_origin ) > n_radius_sq )
        {
            continue;
        }

        b_lethal = ( isdefined( z.health ) && z.health <= n_damage );

        if ( b_lethal )
        {
            z zombie_utility::zombie_head_gib(); // dismember while ALIVE (Nuke's own death; non-blocking)
            if ( isdefined( level._effect[ "zombie_guts_explosion" ] ) )
            {
                PlayFX( level._effect[ "zombie_guts_explosion" ], z.origin ); // stock torso gore burst
            }
        }

        z DoDamage( n_damage, v_origin, self, self, 0, "MOD_GRENADE_SPLASH" );

        if ( b_lethal && n_flung < n_cap )
        {
            // Away from the blast + an upward bias (the (0,0,UP) term also guards a zero-length
            // vector when the corpse sits exactly on v_origin). Stock Thunder Wall shape.
            v_dir = ( z.origin - v_origin ) + ( 0, 0, ACC_PHD_FLING_UP );
            z StartRagdoll( true );
            z LaunchRagdoll( ACC_PHD_FLING_FORCE * VectorNormalize( v_dir ), "torso_lower" );
            n_flung++;
        }
    }
}

// Round-scaled so the nova one-shots a trash zombie at any round; Mega hits much harder.
function phd_explode_damage( b_mega )
{
    n_base = ACC_PHD_EXPLODE_BASE_DAMAGE;
    if ( isdefined( level.zombie_health ) && level.zombie_health > n_base )
    {
        n_base = level.zombie_health;
    }
    if ( IS_TRUE( b_mega ) )
    {
        return n_base * 2;
    }
    return n_base;
}

// ---------------------------------------------------------------------------
// Machine identity fix (identical to the cherry/Aura Blast fix). The stock cherry
// perk_machine_set_kvps is a Treyarch placeholder that names the machine/trigger
// "vending_marathon" (Stamin-Up's names); left alone, Stamin-Up's perk_machine_think
// captures our machine while the cherry think scans "vending_electriccherry" and finds
// nothing. Re-point the entities + bounce both think loops. Runs after the KVPs are
// applied inside zm_usermap::main().
// ---------------------------------------------------------------------------

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
        acc_utility::log( "phd flopper: no vending trigger found, machine identity unfixed" );
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

    acc_utility::log( "phd flopper: machine identity fixed (vending_electriccherry)" );
}
