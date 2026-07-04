// =============================================================================
// _acc_overclocks.gsc - weapon Tier progression + Overclock slots
//
// Design reference: docs/05_weapons.md (Weapon Progression - Tier 1-5).
//
// Tier model:
//   - Each weapon tracks a TIER from 0 (base) to 5 (max) per player.
//   - Each tier-up unlocks ONE Overclock slot, filled with a random roll from
//     the weapon's family pool (no duplicates per weapon).
//   - Tier advancement costs 1/2/3/4/5 Shards respectively (1 to reach T1,
//     2 more to reach T2, etc; 15 total to max a weapon).
//   - Re-rolling an existing tier's Overclock costs 1 Shard.
//
// This module replaces the previous "3 active per family, 2 Shards to apply"
// design. Pools are NOT re-rolled per run; randomization comes from the
// tier-up draw and the re-roll mechanic.
// =============================================================================

#using scripts\shared\array_shared;
#using scripts\shared\util_shared;

#using scripts\zm\_zm_weapons;

#using scripts\zm\zm_abandoned_cyber_city\_acc_utility;
#using scripts\zm\zm_abandoned_cyber_city\_acc_data_shards;
#using scripts\zm\zm_abandoned_cyber_city\_acc_weapon_variants;
#using scripts\zm\zm_abandoned_cyber_city\_acc_lui;
#using scripts\zm\zm_abandoned_cyber_city\_acc_pap_levels;
#using scripts\zm\zm_abandoned_cyber_city\_acc_bus_trench;

// Tier costs per level. ACC_TIER_MAX 5 -> 10 (user 2026-06-24): both the gun Overclock and the Exo Suit
// now go to 10 tiers. The 4 effects scale off the tier in _acc_damage (get_oc_tier, no internal clamp),
// so they extend to T10 automatically: flat dmg +100%, glitch +250%, ammo 100%, shield-pierce 0.05/tier
// (the Riot's front takes 25% dmg at T0 -> 62.5% at T10; a PARTIAL restore, never a full bypass, user 2026-06-25).
// Cost ladder (SHARED with the Exo Suit, user 2026-06-24): LINEAR +4/tier = 4 x tier ->
// 4 / 8 / 12 / 16 / 20 / 24 / 28 / 32 / 36 / 40 (220 to max one gun; all fit the 500 shard cap).
#define ACC_TIER_MAX 10
#define ACC_TIER_COST_T1 4
#define ACC_TIER_COST_T2 8
#define ACC_TIER_COST_T3 12
#define ACC_TIER_COST_T4 16
#define ACC_TIER_COST_T5 20
#define ACC_TIER_COST_T6 24
#define ACC_TIER_COST_T7 28
#define ACC_TIER_COST_T8 32
#define ACC_TIER_COST_T9 36
#define ACC_TIER_COST_T10 40
#define ACC_OC_REROLL_COST_SHARDS 1

// Overclock terminal world model (a theatre ticket kiosk - on-theme tech read; xmodel-listed in the .zone).
#precache( "model", "p7_cai_ticket_kiosk_theatre" );

#namespace acc_overclocks;

// ---------------------------------------------------------------------------
// Init
// ---------------------------------------------------------------------------

function init()
{
    acc_utility::log( "overclocks init (Tier 1-5 model)" );

    level.acc_oc_pools = build_family_pools();
    // Active-3-per-family roll REMOVED in new design - pools are visible in
    // full, randomization happens per tier-up.

    // Kiosk origins for the proximity info CARD (_acc_perk_info reads this to show the
    // held weapon's Overclock report when you walk up). Appended by watch_terminal_trigger
    // (placed triggers) + spawn_terminal_at (script-spawned ones). user 2026-06-21.
    level.acc_oc_kiosk_origins = [];

    level thread watch_terminal_trigger();
}

function on_player_connect( player )
{
    // Per-player, per-weapon tier + Overclock state.
    // Shape: player.acc_weapon_progress[ weapon_name ] = struct {
    //   tier (int 0..5),
    //   overclocks (array of overclock_id strings, length = tier)
    // }
    player.acc_weapon_progress = [];

    // HUD: push the held weapon's Overclock tier as a "vN" indicator near the gun name (mirrors the
    // PaP tier icon). user 2026-06-21.
    player thread oc_hud_loop( player );
}

// Resolve the held weapon's Overclock tier (0..5), mirroring _acc_damage::get_oc_tier: held-object
// first, then the true-base fallback (progress is keyed by true_base since the 2026-06-21 fix).
function held_oc_tier( player )
{
    if ( !isdefined( player.acc_weapon_progress ) ) return 0;
    w = player getcurrentweapon();
    if ( !isdefined( w ) || w == level.weaponNone ) return 0;
    if ( isdefined( player.acc_weapon_progress[ w ] ) ) return player.acc_weapon_progress[ w ].tier;
    base = acc_weapon_variants::true_base( w );
    if ( isdefined( base ) && isdefined( player.acc_weapon_progress[ base ] ) ) return player.acc_weapon_progress[ base ].tier;
    return 0;
}

// Per-player loop: push the held weapon's Overclock tier to the LUI "vN" indicator on change.
function oc_hud_loop( player )
{
    player endon( "disconnect" );
    level endon( "end_game" );

    last = -1;
    for ( ;; )
    {
        wait( 0.25 );
        if ( !isdefined( player ) ) return;
        tier = held_oc_tier( player );
        if ( tier != last )
        {
            acc_lui::set_oc_tier( player, tier );
            last = tier;
        }
    }
}

// Helper: get or init progress struct for a weapon.
function get_or_init_progress( player, weapon_name )
{
    if ( !isdefined( player.acc_weapon_progress[ weapon_name ] ) )
    {
        p = spawnstruct();
        p.tier = 0;
        p.overclocks = [];
        player.acc_weapon_progress[ weapon_name ] = p;
    }
    return player.acc_weapon_progress[ weapon_name ];
}

function tier_cost( target_tier )
{
    switch ( target_tier )
    {
    case 1: return ACC_TIER_COST_T1;
    case 2: return ACC_TIER_COST_T2;
    case 3: return ACC_TIER_COST_T3;
    case 4: return ACC_TIER_COST_T4;
    case 5: return ACC_TIER_COST_T5;
    case 6: return ACC_TIER_COST_T6;
    case 7: return ACC_TIER_COST_T7;
    case 8: return ACC_TIER_COST_T8;
    case 9: return ACC_TIER_COST_T9;
    case 10: return ACC_TIER_COST_T10;
    }
    return 0;
}

// ---------------------------------------------------------------------------
// Pool definition. Synced with docs/05_weapons.md.
// Each overclock is a struct with id, display_name, on_apply (callback).
// ---------------------------------------------------------------------------

function build_family_pools()
{
    // DEAD since 2026-06-19 (kept harmless/unreferenced): the overclock no longer ROLLS effects from these
    // pools. Each tier just raises progress.tier (terminal_loop), and the 3 LIVE effects (flat damage /
    // glitch piercing / ammo refund) scale off that tier in _acc_damage via get_oc_tier (ACC_TIER_MAX is now
    // 5). These pools + the apply_oc_* / roll_new_overclock_for_weapon helpers DO NOTHING now - don't wire
    // them back without a real damage-side consumer.
    pools = [];

    pools[ "ar" ] = array(
        oc( "ar_overpressure", "Overpressure",     &apply_oc_ar_overpressure ),
        oc( "ar_piercing",     "Piercing Rounds",  &apply_oc_ar_piercing ),
        oc( "ar_adaptive",     "Adaptive Aim",     &apply_oc_ar_adaptive ),
        oc( "ar_reactive",     "Reactive Powder",  &apply_oc_sr_reactive )
    );

    pools[ "smg" ] = array(
        oc( "smg_overpressure","Overpressure",     &apply_oc_ar_overpressure ),
        oc( "smg_piercing",    "Piercing Rounds",  &apply_oc_ar_piercing ),
        oc( "smg_adaptive",    "Adaptive Aim",     &apply_oc_ar_adaptive ),
        oc( "smg_reactive",    "Reactive Powder",  &apply_oc_sr_reactive )
    );

    pools[ "shotgun" ] = array(
        oc( "sg_breach",       "Breach",           &apply_oc_sg_breach ),
        oc( "sg_overpressure", "Overpressure",     &apply_oc_ar_overpressure ),
        oc( "sg_adaptive",     "Adaptive Aim",     &apply_oc_ar_adaptive ),
        oc( "sg_reactive",     "Reactive Powder",  &apply_oc_sr_reactive )
    );

    pools[ "sniper" ] = array(
        oc( "sr_penetration",  "Penetration Round",&apply_oc_sr_penetration ),
        oc( "sr_reactive",     "Reactive Powder",  &apply_oc_sr_reactive ),
        oc( "sr_overpressure", "Overpressure",     &apply_oc_ar_overpressure ),
        oc( "sr_adaptive",     "Adaptive Aim",     &apply_oc_ar_adaptive )
    );

    pools[ "lmg" ] = array(
        oc( "lmg_overpressure","Overpressure",     &apply_oc_ar_overpressure ),
        oc( "lmg_piercing",    "Piercing Rounds",  &apply_oc_ar_piercing ),
        oc( "lmg_adaptive",    "Adaptive Aim",     &apply_oc_ar_adaptive ),
        oc( "lmg_reactive",    "Reactive Powder",  &apply_oc_sr_reactive )
    );

    return pools;
}

function oc( id, name, on_apply )
{
    o = spawnstruct();
    o.id = id;
    o.display_name = name;
    o.on_apply = on_apply;
    return o;
}

// ---------------------------------------------------------------------------
// Terminal interaction
// ---------------------------------------------------------------------------

function watch_terminal_trigger()
{
    level endon( "end_game" );

    triggers = getentarray( "acc_overclock_terminal", "targetname" );
    if ( triggers.size == 0 )
    {
        acc_utility::log( "overclocks: no terminal placed yet" );
        return;
    }

    if ( !isdefined( level.acc_oc_kiosk_origins ) ) level.acc_oc_kiosk_origins = [];
    for ( i = 0; i < triggers.size; i++ )
    {
        // TRENCH-ONLY OVERCLOCK GUARD (user 2026-06-25): overclocking is meant to be an underground RISK,
        // so ignore any map-placed acc_overclock_terminal that is NOT underground. This kills the "invisible
        // overclock machine in the Lab" exploit (a stray model-less trigger). The intended terminals are
        // script-spawned underground via spawn_terminal_at (which calls terminal_loop directly, bypassing this
        // loop), so they are unaffected. We guard in GSC because the .map deletion only lands on a FULL build
        // and the LED bake is currently broken by unrelated WIP geometry - this makes the fix effective on a
        // GSC-only build even while the old BSP still carries the Lab trigger.
        if ( acc_bus_trench::underground_layer( triggers[ i ].origin ) <= 0 )
        {
            acc_utility::log( "overclocks: ignoring above-ground terminal at " + triggers[ i ].origin + " (trench-only)" );
            continue;
        }
        triggers[ i ] thread terminal_loop();
        level.acc_oc_kiosk_origins[ level.acc_oc_kiosk_origins.size ] = triggers[ i ].origin;
    }
}

// Spawn an Overclock terminal (kiosk model + a hold-USE trigger running the existing
// terminal_loop) at origin, facing yaw. Pure GSC - the trench "Foundry" home for the
// weapon-tier system. Called by _acc_glitch_altar with the underground origins.
function spawn_terminal_at( origin, yaw )
{
    m = spawn( "script_model", origin );
    m setmodel( "p7_cai_ticket_kiosk_theatre" );
    if ( isdefined( yaw ) ) m.angles = ( 0, yaw, 0 );

    t = spawn( "trigger_radius_use", origin + ( 0, 0, 40 ), 0, 64, 80 );
    t TriggerIgnoreTeam();   // REQUIRED for a script-spawned use-trigger to be player-usable (stock _zm_perks.gsc:1523).
    t SetCursorHint( "HINT_NOICON" );
    // Buyable-UI audit fix (2026-07-03): "upgrade"+"weapon" made the Aetherium router show the
    // PACK-A-PUNCH card at this kiosk. "boost your held gun" avoids every router token ->
    // clean DefaultHint card with this text verbatim. Costs are DATA SHARDS (audit typo fix).
    // The kiosk's live tier/cost/result feedback ALSO lives in this hint now (terminal_loop
    // updates it per interaction) - the old floating hud_msg popups are gone (user 2026-07-03:
    // "remove the original display UI when you trigger things").
    t SetHintString( "Hold ^3[{+activate}]^7  ^5CYBERWARE OVERCLOCK^7 - boost your held gun: +damage / glitch-pierce / +ammo (Data Shards)" );
    t thread terminal_loop();
    if ( !isdefined( level.acc_oc_kiosk_origins ) ) level.acc_oc_kiosk_origins = [];
    level.acc_oc_kiosk_origins[ level.acc_oc_kiosk_origins.size ] = origin;
    acc_utility::log( "overclocks: terminal spawned at " + origin );
}

function terminal_loop()
{
    self endon( "death" );

    for ( ;; )
    {
        self waittill( "trigger", player );

        // FEEDBACK CHANNEL REWORK (user 2026-07-03: "remove the original display UI when you
        // trigger things"): every hud_msg popup below became a TRIGGER HINT update - the
        // Aetherium default card re-renders live from cursorHintText, so the card itself is
        // the feedback. All hint strings are BOUNDED (state x tier <= ~25) - cap-safe.
        current = player getcurrentweapon();
        family = weapon_name_to_family( current );
        if ( family == "unknown" )
        {
            self SetHintString( "^5CYBERWARE OVERCLOCK^7 - this weapon is not supported" );
            wait( 0.5 );
            continue;
        }
        if ( family == "none" )
        {
            self SetHintString( "^5CYBERWARE OVERCLOCK^7 - this weapon class cannot be tiered" );
            wait( 0.5 );
            continue;
        }

        // FIX (user 2026-06-21 "randomly lose the overclock"): key the tier by the TRUE BASE weapon,
        // not the held object. Previously this used `current` (the held form), so overclocking while
        // holding a PaP'd or perk-twin form stored the tier under that object - then switching forms
        // (PaP, or a Mega-perk twin swapping in/out) made get_oc_tier miss it and read 0. true_base
        // strips the _acc twin suffix + maps PaP, so the tier is form-invariant and get_oc_tier's
        // own true_base fallback always finds it.
        base_wpn = acc_weapon_variants::true_base( current );
        progress = get_or_init_progress( player, base_wpn );

        // Each tier gives a SMALL boost to ALL THREE overclock effects at once (user 2026-06-19) -
        // the magnitudes scale with progress.tier in _acc_damage (get_oc_tier), so the terminal just
        // raises the tier. No more random per-effect roll. PER-GUN (tracked on the true-base weapon).
        if ( progress.tier >= ACC_TIER_MAX )
        {
            self SetHintString( "^5CYBERWARE OVERCLOCK^7 - Tier " + ACC_TIER_MAX + "/" + ACC_TIER_MAX + " MAX ^7(damage / glitch-pierce / ammo all +)" );
            wait( 0.5 );
            continue;
        }

        next_tier = progress.tier + 1;
        cost = tier_cost( next_tier );
        if ( !acc_data_shards::try_spend( player, cost ) )
        {
            self SetHintString( "^5CYBERWARE OVERCLOCK^7 - Tier " + next_tier + " costs ^5" + cost + " Data Shards^7 - hold ^3[{+activate}]^7 to boost" );
            wait( 0.5 );
            continue;
        }

        progress.tier = next_tier;

        // Feedback (user 2026-06-21): a zap SFX + the SAME PaP "gun comes out" re-draw animation, so
        // overclocking FEELS like you just enhanced the weapon. replay_pack_draw re-gives the held gun
        // (preserving its PaP tier) and plays the first-raise; gated by the acc_pap_tier_anim dvar.
        player PlaySound( "acc_overclock_zap" );
        player acc_pap_levels::replay_pack_draw( current );

        // CRASH GUARD (co-op disconnect audit 2026-06-27): replay_pack_draw runs INLINE on this SHARED trigger
        // thread (whose only endon is self=TRIGGER "death", NOT the player) and has a multi-frame empty-handed
        // window. If the player disconnects/times out during it, the `player ...` calls below would be method
        // calls on a freed entity -> fatal server-script error -> whole-session CTD for everyone. Re-validate
        // before reusing `player`. (Cannot fix this inside replay_pack_draw with `self endon("disconnect")`:
        // it's inline, so that endon would terminate this shared trigger loop for ALL players.)
        if ( !isdefined( player ) )
            continue;

        self SetHintString( "^5CYBERWARE OVERCLOCK^7 - Tier " + next_tier + "/" + ACC_TIER_MAX +
                            " ^7(damage / glitch-pierce / ammo all +) - hold ^3[{+activate}]^7 to boost again" );
        wait( 0.5 );
    }
}

// Pick a random Overclock from the family pool that isn't already active
// on this weapon. Returns undefined if pool is exhausted.
function roll_new_overclock_for_weapon( player, weapon_name, family, progress )
{
    pool = level.acc_oc_pools[ family ];
    if ( !isdefined( pool ) || pool.size == 0 ) return undefined;

    // Build candidate list of Overclocks not already on this weapon.
    existing_ids = progress.overclocks;
    candidates = [];
    for ( i = 0; i < pool.size; i++ )
    {
        oc_struct = pool[ i ];
        dup = false;
        for ( j = 0; j < existing_ids.size; j++ )
        {
            if ( oc_struct.id == existing_ids[ j ] )
            {
                dup = true;
                break;
            }
        }
        if ( !dup ) candidates[ candidates.size ] = oc_struct;
    }

    if ( candidates.size == 0 ) return undefined;
    return candidates[ acc_utility::acc_rand_int( candidates.size ) ];
}

// ---------------------------------------------------------------------------
// Weapon classification
// ---------------------------------------------------------------------------

// Takes the weapon OBJECT from GetCurrentWeapon() (BO3 weapons are objects,
// not strings - stock compares weapon.name, e.g. _zm_weapons.gsc:2650).
function weapon_name_to_family( weapon_name )
{
    // TODO(acc-data): replace this giant switch with a GDT-driven table.
    // Weapon names are class-based + unsuffixed for stock; Skye imports are
    // engine-prefixed (s1_=AW, t6_=BO2 - docs/21).
    // EVERY weapon Overclocks EXCEPT the Action Figure (user 2026-06-23): the box guns, the start pistol,
    // the Mahem launcher + Thundergun WW (special_list) all map to a real family below; only the Action
    // Figure melee (+ the non-box laststand pistol, knife, grenades) return "none". A gun not listed falls
    // through to "unknown" (blocked) - add any NEW gun to a family list.
    ar_list = array( "t9_ak47", "s1_ae4",           // AK-47 (BO2), AE4 (AW energy)
                     "t6_galil" );                  // Galil (BO2, 2026-06-15)
    // ASM1 RETIRED 2026-07-03 (user) - re-add "s1_asm1" first in this array to restore.
    smg_list = array( "s4_ppsh41_base", "t9_ak74u",  // PPSH-41, AK-74u
                      "t6_chicom_cqb" );             // Chicom CQB (BO2 burst SMG, 2026-06-25)
    sg_list = array( "s1_tac19", "t6_olympia" );    // Tac-19, Olympia (BO2, 2026-06-15)
    sr_list = array( "t8_paladin_hb50", "s1_mk14", "s1_mors" ); // Paladin HB50 (BO4 sniper) + MK14 (AW DMR) + MORS (AW railgun sniper, 2026-06-24)
    lmg_list = array( "t9_m60", "t9_rpd" );         // M60 + RPD (Cold War LMGs, 2026-06-26)

    // Pistols are NOW Overclock-able (user 2026-06-22: "every gun except wunderwaffe").
    pistol_list = array( "t6_fiveseven", "s1_rw1" ); // Five-Seven (start pistol) + RW1 (AW energy pistol, 2026-06-23)

    // SPECIAL weapons that DO Overclock (user 2026-06-23: "every weapon except the Action Figure"). The Mahem
    // launcher + Thundergun WW gain the damage + vs-glitch tiers (the headshot->ammo effect is inert on them -
    // explosions / wind-blast don't headshot - but harmless). "special" is just the overclockable gate; the OC
    // effects are tier-based and family-agnostic, so the value string beyond none/unknown doesn't change them.
    special_list = array( "s1_mahem", "thundergun" );

    // The ONLY weapon that CANNOT Overclock is the Action Figure melee (the Exo Suit scales melee instead),
    // plus the non-box held things that were never tier-able (laststand pistol, knife, grenade) -> "none"
    // (a useful terminal message, not "unknown").
    none_list = array( "pistol_standard", "knife", "frag_grenade", "t8_melee_figure" );

    // Resolve to the TRUE base NAME: strips BOTH the PaP "_up" AND the "_acc" perk-twin suffix, so a held
    // PaP'd OR perk-twin form (e.g. t9_rpd_acc_fastreload while Speed Cola is active) still classifies into its
    // family. strip_pap_suffix (get_base_weapon) alone does NOT strip the _acc twin suffix, so a twin fell
    // through to "unknown" = "weapon not supported" (user 2026-06-26: couldn't Overclock the CW guns while a
    // perk twin was the held form). true_base mirrors the tier key at line ~297 so eligibility + tracking agree.
    base_obj = acc_weapon_variants::true_base( weapon_name );
    base = base_obj.name;

    if ( array::contains( ar_list, base ) ) return "ar";
    if ( array::contains( smg_list, base ) ) return "smg";
    if ( array::contains( sg_list, base ) ) return "shotgun";
    if ( array::contains( sr_list, base ) ) return "sniper";
    if ( array::contains( lmg_list, base ) ) return "lmg";
    if ( array::contains( pistol_list, base ) ) return "pistol";
    if ( array::contains( special_list, base ) ) return "special";
    if ( array::contains( none_list, base ) ) return "none";
    return "unknown";
}

// Resolve a (possibly PaP'd) weapon OBJECT to its base weapon NAME string.
// VERIFIED(acc): BO3 PaP mapping is table-driven, not suffix-based -
// zm_weapons::get_base_weapon (_zm_weapons.gsc:1624) resolves via
// level.zombie_weapons_upgraded and handles non-upgraded weapons too.
// Returning .name gives the string the family lists compare against.
function strip_pap_suffix( weapon )
{
    base = zm_weapons::get_base_weapon( weapon );
    return base.name;
}

// ---------------------------------------------------------------------------
// Effect implementations (stubs - flesh out in Phase 3/4)
//
// Each function runs on `self` = the player with the weapon equipped.
// Storage convention: self.acc_oc_active[ weapon_name ] = struct of flags.
// ---------------------------------------------------------------------------

function apply_oc_ar_burst_coil( weapon )        { set_oc_flag( weapon, "burst_coil", true ); }
function apply_oc_ar_overpressure( weapon )      { set_oc_flag( weapon, "overpressure", true ); }
function apply_oc_ar_piercing( weapon )          { set_oc_flag( weapon, "piercing", true ); }
function apply_oc_ar_adaptive( weapon )          { set_oc_flag( weapon, "adaptive", true ); }
function apply_oc_ar_overheat( weapon )          { set_oc_flag( weapon, "overheat", true ); }
function apply_oc_ar_subcritical( weapon )       { set_oc_flag( weapon, "subcritical", true ); }

function apply_oc_smg_swarm( weapon )            { set_oc_flag( weapon, "swarm", true ); }
function apply_oc_smg_reflex( weapon )           { set_oc_flag( weapon, "reflex_fire", true ); }
function apply_oc_smg_coolant( weapon )          { set_oc_flag( weapon, "coolant", true ); }
function apply_oc_smg_shrapnel( weapon )         { set_oc_flag( weapon, "shrapnel", true ); }
function apply_oc_smg_microboost( weapon )       { set_oc_flag( weapon, "microboost", true ); }

function apply_oc_sg_spread( weapon )            { set_oc_flag( weapon, "spread", true ); }
function apply_oc_sg_breach( weapon )            { set_oc_flag( weapon, "breach", true ); }
function apply_oc_sg_concussive( weapon )        { set_oc_flag( weapon, "concussive", true ); }
function apply_oc_sg_reflow( weapon )            { set_oc_flag( weapon, "reflow", true ); }

function apply_oc_sr_thermal( weapon )           { set_oc_flag( weapon, "thermal", true ); }
function apply_oc_sr_penetration( weapon )       { set_oc_flag( weapon, "penetration", true ); }
function apply_oc_sr_reactive( weapon )          { set_oc_flag( weapon, "reactive", true ); }
function apply_oc_sr_quickchamber( weapon )      { set_oc_flag( weapon, "quickchamber", true ); }

function apply_oc_lmg_sustained( weapon )        { set_oc_flag( weapon, "sustained", true ); }
function apply_oc_lmg_suppression( weapon )      { set_oc_flag( weapon, "suppression", true ); }
function apply_oc_lmg_reloaddrum( weapon )       { set_oc_flag( weapon, "reloaddrum", true ); }

function set_oc_flag( weapon, flag_name, value )
{
    // VERIFIED(acc): BO3 GSC has no dynamic member syntax (obj.(name) appears
    // nowhere in stock); string-keyed arrays are the stock pattern
    // (_zm.gsc:3054 self.stored_weapon_info[ weapon ] = SpawnStruct()).
    if ( !isdefined( self.acc_oc_active ) ) self.acc_oc_active = [];
    if ( !isdefined( self.acc_oc_active[ weapon ] ) ) self.acc_oc_active[ weapon ] = [];
    self.acc_oc_active[ weapon ][ flag_name ] = value;
    // Damage callback / weapon-fire callback reads these flags at runtime.
    // See damage hook in _acc_elites.gsc / _acc_main.gsc callbacks.
}
