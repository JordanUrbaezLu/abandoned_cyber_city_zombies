// =============================================================================
// _acc_perk_electric_cherry.gsc - Electric Cherry, the REAL 10th perk (perk #10)
//
// Design reference: docs/13_perks.md / docs/perk_abilities.md (Electric Cherry).
//
// This is a genuinely NEW perk registered FROM SCRATCH on the unused engine
// specialty `specialty_combat_efficiency` (the shipped Elemental Pop precedent,
// docs/22 - HasPerk/SetPerk/HUD all work natively on it). It does NOT touch the
// stock `specialty_electriccherry` pipeline, which PhD Flopper still hijacks
// (_acc_perk_phd_flopper.gsc). So both PhD AND a real Electric Cherry coexist:
//   - PhD Flopper  -> specialty_electriccherry + p7_zm_vending_nuke (unchanged)
//   - Electric Cherry (this) -> specialty_combat_efficiency + the real
//     p6_zm_vending_electric_cherry_on/off vending model (its OWN Lab alcove,
//     added by tools/respace_perk_alcoves_10.js).
//
// Registration mirrors the stock 6-call chain (cleanest example _zm_perk_deadshot.gsc;
// shipped custom-perk precedent ColDog/zm_countryside, docs/22):
//   register_perk_basic_info / precache / machine / threads / host_migration_params.
// We DELIBERATELY SKIP register_perk_clientfields: the clientuimodel pool is near
// full (memory hud-pool-full-workarounds), and this map's perk HUD is driven by the
// custom accOwnedMask (widened 9->10 in _acc_lui), NOT per-perk hudItems.perks.* -
// so no new clientfield is needed. No .csc either (the nova FX is one-shot SERVER
// PlayFX, exactly like PhD's nova - that path renders; the "server PlayFX doesn't
// render" caveat is only for the LOOPING perk-machine glow, handled by _acc_perk_lights).
//
// ABILITY (lifted + adapted from stock _zm_perk_electric_cherry.gsc::electric_cherry_
// reload_attack, L353-492): RELOADING discharges an electric nova that electrocutes
// nearby zombies. The blast SCALES with how empty the clip was (the cherry signature) -
// reloading a near-empty mag = big blast, reloading a full mag = a spark. We FIX the
// stock clip-fraction stub (it hardcoded 1/10, L383-4) by reading GetWeaponAmmoClip +
// weapon.clipSize for real. Damage is round-scaled (one-shots trash at any round when
// the mag is empty). A cooldown stops reload-spam. NO laststand-boom (PhD owns the
// single global level.custom_laststand_func - we don't fight it).
//
// MEGA ("Power Surge", read live from the Mega flag): bigger radius, more targets,
// higher damage, shorter cooldown, AND immunity to boss "special moves" - the Phantom
// chain-zap slow + the Subroutine Core power/perk-disable (moved here from Mega Widow's
// Wine, user 2026-06-25; thematically the electric perk shrugs off the electric special).
// That immunity is enforced in _acc_boss::protect_immune_players_during_debuff and
// _acc_elites::acc_phantom_chain_zap, which gate on the PERSISTENT Mega flag
// (specialty_combat_efficiency) - the only ownership marker that survives the boss's
// UnsetPerk debuff, which is exactly why it must live on the Mega tier, not base.
//
// REGISTER_SYSTEM autoexec runs the registration at the correct pre-load phase (same
// as stock perks + _acc_perk_lights); wired by the #using in zm_abandoned_cyber_city.gsc
// + the scriptparsetree line in the .zone.
// =============================================================================

#using scripts\codescripts\struct;

#using scripts\shared\array_shared;
#using scripts\shared\math_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#using scripts\shared\ai\zombie_utility;

#using scripts\zm\_zm_perks;
#using scripts\zm\_zm_perk_electric_cherry;   // call the STOCK cherry tesla-FX functions (real electrocution; its clientfields are already live via PhD's pipeline)
#using scripts\zm\_zm_score;
#using scripts\zm\_zm_utility;

#insert scripts\zm\_zm_perks.gsh;

#using scripts\zm\zm_abandoned_cyber_city\_acc_utility;
#using scripts\zm\zm_abandoned_cyber_city\_acc_mega_bottles;

// --- identity ---------------------------------------------------------------
// specialty_combat_efficiency = an UNUSED engine specialty (no stock perk binds it;
// HasPerk/SetPerk work natively). Hosts the real Electric Cherry so PhD keeps the
// cherry pipeline. (docs/22 "Reserved specialty strings are engine-valid".)
#define EC_PERK                "specialty_combat_efficiency"
#define EC_ALIAS               "acc_electric_cherry"
#define EC_COST                3000
#define EC_BOTTLE_WEAPON       "zombie_perk_bottle_cherry"   // reuse the stock cherry bottle (already zoned by PhD/stock cherry; no new asset)
#define EC_RADIANT_MACHINE     "vending_acc_electric_cherry" // unique radiant name (NOT the stamin-up default - avoids the machine-identity collision)
#define EC_MACHINE_LIGHT_FX    "acc_ec_machine_light"
#define EC_OFF_MODEL           "p6_zm_vending_electric_cherry_off"
#define EC_ON_MODEL            "p6_zm_vending_electric_cherry_on"

// --- nova tuning (live-tunable dvars; magnitudes hidden in UI per vague-ui rule) ---
#define EC_RADIUS_MIN          64     // full-mag reload = small spark
#define EC_RADIUS_MAX          220    // empty-mag reload = big blast
#define EC_RADIUS_MIN_MEGA     96
#define EC_RADIUS_MAX_MEGA     200    // user 2026-06-25: 360 -> 200 (Mega's edge is dmg/targets/immunity, not raw radius; base empty-radius is 220)
#define EC_DMG_MIN             1      // full-mag floor
#define EC_TARGET_CAP          8      // max zombies zapped per nova (base)
#define EC_TARGET_CAP_MEGA     12     // user 2026-06-25: 16 -> 12
#define EC_COOLDOWN            6      // seconds between novas (base)
#define EC_COOLDOWN_MEGA       5      // user 2026-06-25: 4 -> 5
#define EC_KILL_POINTS         40     // points per zombie the nova kills (mirrors stock RELOAD_ATTACK_POINTS)

// Electric burst FX - the PhD-proven, on-disk one-shot spark burst (electric/, "_os" =
// one-shot). Reused so this needs NO new FX asset (memory verify-fx-efx-on-disk).
#define EC_BURST_FX            "electric/fx_elec_sparks_burst_xlg_os"

#precache( "fx", EC_BURST_FX );

#namespace acc_perk_electric_cherry;

// REGISTER_SYSTEM autoexec - runs __init__ at the system-init load phase (before
// perk_machine_spawn_init iterates the zm_perk_machine structs), same as stock perks.
REGISTER_SYSTEM( "acc_perk_electric_cherry", &__init__, undefined )

// ---------------------------------------------------------------------------
// Registration
// ---------------------------------------------------------------------------

function __init__()
{
    // The 6-call chain (minus clientfields - skipped on purpose, see header).
    zm_perks::register_perk_basic_info( EC_PERK, EC_ALIAS, EC_COST, "Hold ^3&&1^7 for Electric Cherry [Cost: " + EC_COST + "]", GetWeapon( EC_BOTTLE_WEAPON ) );
    zm_perks::register_perk_precache_func( EC_PERK, &ec_precache );
    zm_perks::register_perk_machine( EC_PERK, &ec_machine_setup );
    zm_perks::register_perk_threads( EC_PERK, &give_electric_cherry, &take_electric_cherry );
    // host_migration_params sets .radiant_machine_name + .machine_light_effect, which (with
    // .alias) is what makes stock auto-thread perk_machine_think for this machine (_zm_perks.gsc:98-100).
    zm_perks::register_perk_host_migration_params( EC_PERK, EC_RADIANT_MACHINE, EC_MACHINE_LIGHT_FX );
}

// Perk precache callback - register the machine light FX + the machine model assets.
function ec_precache()
{
    // Machine light: a stock cola light FX (must be a defined level._effect key for the
    // perk_machine_think auto-run gate; the actual machine GLOW is driven client-side by
    // _acc_perk_lights, but the gate still needs this defined).
    level._effect[ EC_MACHINE_LIGHT_FX ] = "_t6/misc/fx_zombie_cola_revive_on";

    level.machine_assets[ EC_PERK ] = SpawnStruct();
    level.machine_assets[ EC_PERK ].weapon    = GetWeapon( EC_BOTTLE_WEAPON );
    // MODEL = p7_lab_bio_machinery_01 (user 2026-06-25: "use a model we haven't used; if none, wunderfizz").
    // The real cherry vending model + the Wunderfizz machine are BOTH catalog-listed but UNPACKABLE here (no
    // source in the install - the cherry one rendered INVISIBLE). Every stock VENDING model is already taken
    // by one of the 9 perks (nuke=PhD), so there is no unused perk-machine model. p7_lab_bio_machinery_01 is
    // an UNUSED lab-equipment model that thematically fits Electric Cherry sitting in the LAB. It is FORCE-PACKED
    // via an `xmodel,p7_lab_bio_machinery_01` line in the .zone (so the linker bakes it into the .ff if a source
    // exists - VERIFY it lands in the packed assetinfo, else it renders invisible like the cherry model).
    // perk_machine_think SetModels this at runtime over the .map struct's model.
    level.machine_assets[ EC_PERK ].off_model = "p7_lab_bio_machinery_01";
    level.machine_assets[ EC_PERK ].on_model  = "p7_lab_bio_machinery_01";
}

// Machine setup callback (dispatched by perk_machine_spawn_init, _zm_perks.gsc:1599). MUST
// set UNIQUE radiant names or stock's hardcoded stamin-up default captures our machine
// (the machine-identity collision PhD's fix_machine_identity papers over - we avoid it by
// naming correctly the first time). Sig = ( use_trigger, perk_machine, bump_trigger, collision ).
function ec_machine_setup( use_trigger, perk_machine, bump_trigger, collision )
{
    use_trigger.script_string = "acc_electric_cherry_perk";
    use_trigger.target        = EC_RADIANT_MACHINE;
    perk_machine.script_string = "acc_electric_cherry_vending";
    perk_machine.targetname    = EC_RADIANT_MACHINE;
    if ( isdefined( bump_trigger ) )
        bump_trigger.script_string = "acc_electric_cherry_vending";
}

// ---------------------------------------------------------------------------
// Give / take (self = player)
// ---------------------------------------------------------------------------

function give_electric_cherry()
{
    self thread ec_reload_watcher();
}

function take_electric_cherry( b_pause, str_perk, str_result )
{
    self notify( "acc_ec_stop" );
}

// ---------------------------------------------------------------------------
// Reload-discharge nova
// ---------------------------------------------------------------------------

// self = player. Fires the nova when the player RELOADS (stock "reload_start" event),
// cooldown-gated so it can't be spammed. The blast scales with clip emptiness.
function ec_reload_watcher()
{
    self endon( "disconnect" );
    self endon( "death" );
    self endon( "acc_ec_stop" );

    self.acc_ec_cooldown = false;

    for ( ;; )
    {
        self waittill( "reload_start" );

        if ( !( self HasPerk( EC_PERK ) ) )           continue;
        if ( IS_TRUE( self.acc_ec_cooldown ) )         continue;

        self ec_nova();

        // Cooldown (Mega "Power Surge" recharges faster).
        self.acc_ec_cooldown = true;
        b_mega = acc_mega_bottles::has_mega_perk( self, EC_PERK );
        cd = ( IS_TRUE( b_mega ) ? getdvarint( "acc_ec_cooldown_mega", EC_COOLDOWN_MEGA ) : getdvarint( "acc_ec_cooldown", EC_COOLDOWN ) );
        wait cd;
        self.acc_ec_cooldown = false;
    }
}

// self = player. The electric discharge: damage + electrocute zombies near the player,
// scaled by how empty the reloaded clip was. Kills route through DoDamage -> the zombie
// death callback -> our points economy (MOD_GRENADE_SPLASH like PhD's nova).
function ec_nova()
{
    self endon( "disconnect" );

    b_mega = acc_mega_bottles::has_mega_perk( self, EC_PERK );

    // Clip emptiness fraction (FIX for the stock 1/10 stub): 0.0 = empty (max blast), 1.0 = full (min blast).
    w_cur   = self GetCurrentWeapon();
    clip_max = ( isdefined( w_cur ) && isdefined( w_cur.clipSize ) && w_cur.clipSize > 0 ? w_cur.clipSize : 1 );
    clip_cur = self GetWeaponAmmoClip( w_cur );
    frac = clip_cur / clip_max;
    if ( frac > 1.0 ) frac = 1.0;
    if ( frac < 0.0 ) frac = 0.0;

    r_min = ( IS_TRUE( b_mega ) ? EC_RADIUS_MIN_MEGA : EC_RADIUS_MIN );
    r_max = ( IS_TRUE( b_mega ) ? EC_RADIUS_MAX_MEGA : EC_RADIUS_MAX );
    radius = math::linear_map( frac, 1.0, 0.0, r_min, r_max );

    // Damage: round-scaled so an empty-mag nova one-shots trash at any round (full-mag = floor).
    dmg_max = ( isdefined( level.zombie_health ) && level.zombie_health > EC_DMG_MIN ? level.zombie_health : 1045 );
    if ( IS_TRUE( b_mega ) ) dmg_max = int( dmg_max * 1.5 );
    dmg = int( math::linear_map( frac, 1.0, 0.0, EC_DMG_MIN, dmg_max ) );

    cap = ( IS_TRUE( b_mega ) ? EC_TARGET_CAP_MEGA : EC_TARGET_CAP );

    // GENUINE base-game Electric Cherry discharge (user 2026-06-25: "just use the base cherry").
    // electric_cherry_reload_fx = the REAL on-player reload burst FX from the stock cherry pipeline
    // (PhD already initialised that pipeline, so the clientfields/FX are live and this renders).
    // Sound: our STANDALONE sound zone mutes stock aliases like zmb_cherry_explode, so we keep our
    // audible electric zap wav rather than ship a silent stock alias (separate sound-zone fix later).
    self thread zm_perk_electric_cherry::electric_cherry_reload_fx( frac );
    self PlaySound( "acc_phantom_zap" );

    v_origin = self.origin;
    r_sq = radius * radius;
    a_zombies = GetAITeamArray( level.zombie_team );
    hit = 0;

    for ( i = 0; i < a_zombies.size; i++ )
    {
        z = a_zombies[ i ];
        if ( !IsAlive( z ) )                                       continue;
        if ( DistanceSquared( z.origin, v_origin ) > r_sq )       continue;
        if ( hit >= cap )                                          break;
        hit++;

        b_lethal = ( isdefined( z.health ) && z.health <= dmg );

        // REAL stock Electric Cherry tesla FX (user 2026-06-25 - fixes the "fake stun"). The stock cherry
        // clientfields + their .csc handlers are already LIVE (PhD rides the stock cherry pipeline, so
        // init_electric_cherry registered them), and these per-zombie FX functions are public + callable.
        // Lethal hits get the full electrocution death; survivors get the genuine shock-eyes + a ~4s freeze
        // (the real base-game look + crowd-control), exactly like buying stock Electric Cherry.
        if ( b_lethal )
        {
            z thread zm_perk_electric_cherry::electric_cherry_death_fx();   // real tesla electrocution death
        }
        else
        {
            // BOSS STUN GUARD (user 2026-06-27 crash-hunt): the stock reload-attack guards the stun with
            // `if(!IsDefined(...is_brutus)) electric_cherry_stun();` so a boss is never frozen; this port
            // dropped that guard. electric_cherry_stun sets self.ignoreall for ~4s, and a boss is ALWAYS
            // non-lethal here (HP >> nova dmg) -> a player reloading near a boss froze it ~4s every cooldown,
            // soft-locking the boss round. Skip the freeze for any boss / mini-boss (covers Brutus/Warden,
            // Phantom, Subroutine Core, Glitch Stalker - all carry acc_is_boss or acc_is_mini_boss). They
            // still get the shock FX + the nova DoDamage below, just not the ignoreall stun.
            if ( !IS_TRUE( z.acc_is_boss ) && !IS_TRUE( z.acc_is_mini_boss ) )
                z thread zm_perk_electric_cherry::electric_cherry_stun();    // real ~4s freeze (ignoreall)
            z thread zm_perk_electric_cherry::electric_cherry_shock_fx();    // real shock-eyes FX
        }

        z DoDamage( dmg, v_origin, self, self, 0, "MOD_GRENADE_SPLASH" );

        if ( b_lethal )
            self zm_score::add_to_player_score( EC_KILL_POINTS );
    }

    acc_utility::log( "electric cherry nova: frac " + frac + " radius " + int( radius ) + " dmg " + dmg + " hit " + hit + ( IS_TRUE( b_mega ) ? " (Power Surge)" : "" ) );
}
