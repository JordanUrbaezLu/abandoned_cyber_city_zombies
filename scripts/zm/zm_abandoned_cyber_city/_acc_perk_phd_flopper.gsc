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
//   - Slide-to-explode (MEGA-ONLY since 2026-06-26): starting a slide fires a grenade-explosion
//     nova that clears nearby trash (on a cooldown). BO3 zombies has the sprint-slide but NO
//     dolphin-dive (confirmed in-game), so we trigger off the engine isSliding() directly - NOT the
//     shipped countryside jump -> land-sliding -> Z-drop dive. BASE PhD does NOT slide-explode now;
//     only the Mega ("PhD Slider") does (dvar acc_phd_base_slide_nova 1 re-enables it for base). The
//     blast visual is the stock ORANGE def_explosion FX + an Earthquake. The BOOM differs by tier
//     (user 2026-06-22): MEGA plays the Nuke-powerup "whoomp" (evt_nuke_flash = our shipped
//     powerup_nuke.wav); the slide/down nova otherwise relies on def_explosion's own baked boom. All
//     ship in every zm map (framework-precached / our wav), so this needs NO new FX/sound asset, no
//     clientfields, no .csc. (The earlier purple Apothicon + electric spark FX were dropped - see the
//     def_explosion note further down; user 2026-06-25 "why does PhD slide spark".)
//   - Explode-on-down (BASE + Mega): PhD-flavoured laststand (you flop down, you go boom) - also
//     replaces the stock cherry electrocution-on-down (foreign element + pays stock points). This is
//     base PhD's nova trigger (the slide one is Mega-only).
//   - Mega "PhD Slider": adds the slide-explode (above) + a bigger/stronger slide + down explosion
//     on a shorter slide cooldown (read live from the Mega flag).
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
#define ACC_PHD_MEGA_DAMAGE_MULT        0.8     // PhD Slider (Mega) nova damage as a multiple of the BASE nova (= round zombie health). Was a flat 2.0; NERF -60% (user 2026-06-24: Mega read ~64k - absurd, the x2 compounding with the global x2.5 + Mega Flopper +15% explosive). 0.8 x base still one-shots trash via the global; the Mega keeps its radius/cooldown/fling/move-speed edge. Live dvar acc_phd_mega_dmg_mult.
#define ACC_PHD_SLIDE_CD                10       // seconds between slide explosions (base, user 2026-06-22: 8 -> 10)
#define ACC_PHD_SLIDE_CD_MEGA           8        // PhD Slider Mega slide cooldown (user 2026-06-22: 5 -> 8)

// The nova's visible "pop" is a per-kill head-gib + guts burst (mirrors stock Nuke: gib the LIVE
// zombie, THEN deal the lethal damage). The old corpse-FLING (StartRagdoll/LaunchRagdoll, modelled on
// Thunder Wall) was REMOVED 2026-06-24 - it was the "invisible zombie still hitting me after a PhD
// slide" bug: StartRagdoll fired in the SAME frame as the zombie's killing DoDamage, racing the
// engine's death processing. That left the actor half-dead (model ragdolled/flung out of view while
// its AI kept swinging), and the interrupted death sometimes skipped the zombie-death callback so
// _acc_corpse_cleanup never ran and the body lingered. It was also INVISIBLE on this map regardless:
// _acc_corpse_cleanup Ghost()s + Delete()s every body within ~0.05s of death (acc_corpse_linger_sec
// default 0), so a launched ragdoll vanished before it could arc. The head-gib + guts FX play instantly
// (before the body is hidden), so the kill still reads as an explosion. #defines retired (kept for history).
#define ACC_PHD_FLING_FORCE             125      // RETIRED 2026-06-24 (corpse-fling removed - see note above)
#define ACC_PHD_FLING_UP                30       // RETIRED 2026-06-24
#define ACC_PHD_FLING_MAX               6        // RETIRED 2026-06-24
#define ACC_PHD_FLING_MAX_MEGA          8        // RETIRED 2026-06-24

// Slide/down NOVA visual = the framework stock ORANGE explosion (level._effect["def_explosion"] =
// "_t6/explosions/fx_default_explosion", registered by stock _zm.gsc). It's framework-baked (NOT a loose
// .efx), so we do NOT #precache it - phd_explode() just PlayFX's the handle. The earlier custom FX (a DLC4
// apothicon burst, then a STOCK electric spark burst) were dropped: the apothicon never built here, and the
// electric one read as "sparks" (user 2026-06-25 - "why does PhD slide spark"). def_explosion = proper boom.

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
// from being a spammable free AOE; the Mega ("PhD Slider") shortens it. MEGA-ONLY since
// 2026-06-26 (user): base PhD does NOT explode on a slide anymore - only the Mega does
// (the explode-when-downed in phd_laststand stays on base). Dvar acc_phd_base_slide_nova.
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

        // SLIDE NOVA IS MEGA-ONLY (user 2026-06-26): base PhD keeps explosive immunity + the
        // explode-when-downed (phd_laststand), but NO LONGER explodes on a slide - only PhD Slider
        // (the Mega) gets the slide boom. Live dvar acc_phd_base_slide_nova 1 re-enables it for base.
        b_mega = acc_mega_bottles::has_mega_perk( self, PERK_ELECTRIC_CHERRY );
        if ( IS_TRUE( b_mega ) || getdvarint( "acc_phd_base_slide_nova", 0 ) == 1 )
        {
            acc_utility::crash_log( self, "phd_slide_watcher: slide ->phd_explode" );
            self phd_explode();
            acc_utility::crash_log( self, "phd_slide_watcher: phd_explode returned" );

            // Cooldown: ignore further slides for a beat (Mega shortens it).
            n_cd = ( IS_TRUE( b_mega ) ? ACC_PHD_SLIDE_CD_MEGA : ACC_PHD_SLIDE_CD );
            wait n_cd;
        }

        // Wait out the current slide so one long slide can't immediately re-trigger (and so a base
        // player who now gets NO slide nova doesn't busy-loop on a held slide).
        while ( self isSliding() )
        {
            wait 0.05;
        }
    }
}

// self = player. An explosive nova that damages/clears nearby zombies AND makes the ones it kills
// visibly explode (head-gib + torso gore burst). The burst CENTRES on the
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

    // VISIBLE blast at the impact point: the stock ORANGE explosion (def_explosion = the framework
    // "_t6/explosions/fx_default_explosion", registered by stock _zm.gsc - guaranteed loaded, NOT a loose
    // .efx so we don't #precache it). Was the electric spark burst (acc_phd_nova) - swapped out per user
    // (2026-06-25: "why does PhD slide spark") for a proper PhD-style explosion. def_explosion's FX carries
    // its own boom, so it doubles as the BASE tier's slide sound. Earthquake adds the screen-shake punch.
    if ( isdefined( level._effect[ "def_explosion" ] ) )
    {
        PlayFX( level._effect[ "def_explosion" ], v_burst );
    }
    Earthquake( 0.45, 0.6, v_burst, n_radius + 200 );

    // AUDIBLE boom: MEGA ("PhD Slider") adds the Nuke-powerup "WHOOMP" (evt_nuke_flash = our shipped
    // powerup_nuke.wav) over the explosion. Played 3D POSITIONALLY at the blast point v_burst via
    // PlaySoundAtPosition - the evt_nuke_flash alias is now 3d/attenuated (was 2d = full-volume EVERYWHERE on
    // the map for every player; user 2026-06-26 "I can hear the nuke across the map"). BASE relies on
    // def_explosion's own baked boom (3D, played in the visual block above), so no extra cue.
    if ( IS_TRUE( b_mega ) )
    {
        PlaySoundAtPosition( "evt_nuke_flash", v_burst );
    }

    // Per-zombie EXPLODE: every zombie the nova KILLS pops apart - head-gib + a torso gore burst.
    // Mirrors stock Nuke (_zm_powerup_nuke.gsc:139/145): zombie_head_gib() on the LIVE zombie, THEN
    // DoDamage (head_gib is non-blocking - it gibs the head + threads a DoT, then returns; it also
    // self-guards no_gib and endon("death"), so a survivor or boss is never left headless). Gating on
    // (health <= n_damage) restricts the gib to trash the nova actually kills, so a living BOSS
    // (Brutus/Panzer/Glitch - all on level.zombie_team with huge HP) is only chipped, never gibbed.
    // NO StartRagdoll/LaunchRagdoll here - the corpse-fling was removed 2026-06-24 (the invisible-zombie
    // bug + it's invisible under instant corpse-cleanup anyway; see the #define note above). Zombies the
    // nova kills die their normal death and are vanished by _acc_corpse_cleanup.
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
            z zombie_utility::zombie_head_gib(); // dismember while ALIVE (Nuke's own death; non-blocking, self-guarded)
            if ( isdefined( level._effect[ "zombie_guts_explosion" ] ) )
            {
                PlayFX( level._effect[ "zombie_guts_explosion" ], z.origin ); // stock torso gore burst
            }
        }

        z DoDamage( n_damage, v_origin, self, self, 0, "MOD_GRENADE_SPLASH" );
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
        // PhD Slider Mega nova: was a flat x2 of the base nova, but the round-scaled base ALREADY one-shots
        // trash, so the x2 just inflated the number (the ~64k the user saw, compounded by the x2.5 global +
        // Mega Flopper +15% explosive). NERF -60% (user 2026-06-24): x0.8 of base. Still one-shots trash via
        // the global; the Mega's real edge is its bigger radius / shorter cooldown / extra flings / +speed.
        return int( n_base * getdvarfloat( "acc_phd_mega_dmg_mult", ACC_PHD_MEGA_DAMAGE_MULT ) );
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

    // Fix EVERY PhD machine, not just the first (user 2026-06-26). There are now TWO PhD machines - the
    // surface/Lab one AND the Paradise duplicate (gen_paradise_props .map struct). The old code stopped at the
    // FIRST match, so the Paradise machine kept the stock cherry placeholder identity (vending_marathon =
    // Stamin-Up's name) and read as STAMIN-UP. Re-point ALL of them to vending_electriccherry + force the PhD
    // (p7_zm_vending_nuke) model so the duplicate can't be left on Stamin-Up's identity/model.
    fixed = 0;
    for ( i = 0; i < 60; i++ )
    {
        a_triggers = GetEntArray( "zombie_vending", "targetname" );
        for ( j = 0; j < a_triggers.size; j++ )
        {
            t_use = a_triggers[ j ];
            if ( !isdefined( t_use.script_noteworthy ) || t_use.script_noteworthy != PERK_ELECTRIC_CHERRY )
                continue;
            t_use.target = "vending_electriccherry";
            if ( isdefined( t_use.machine ) )
            {
                t_use.machine.targetname = "vending_electriccherry";
                t_use.machine setmodel( "p7_zm_vending_nuke" );   // force the PhD (nuke) model on EVERY PhD machine (Lab + Paradise)
            }
            fixed++;
        }
        if ( fixed > 0 ) break;
        wait 0.5;
    }

    if ( fixed == 0 )
    {
        acc_utility::log( "phd flopper: no vending trigger found, machine identity unfixed" );
        return;
    }

    level notify( "specialty_staminup" + PERK_END_POWER_THREAD );
    level notify( PERK_ELECTRIC_CHERRY + PERK_END_POWER_THREAD );
    util::wait_network_frame();
    level thread zm_perks::perk_machine_think( "specialty_staminup", level._custom_perks[ "specialty_staminup" ] );
    level thread zm_perks::perk_machine_think( PERK_ELECTRIC_CHERRY, level._custom_perks[ PERK_ELECTRIC_CHERRY ] );

    acc_utility::log( "phd flopper: machine identity fixed (vending_electriccherry)" );
}
