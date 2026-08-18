// =============================================================================
// _acc_overclocks.gsc - weapon Tier progression + Overclock slots
//
// Design reference: docs/04_weapons.md (Weapon Progression).
//
// Tier model (LIVE; see the ACC_TIER_* defines and _acc_damage::get_oc_tier):
//   - Each weapon tracks a TIER from 0 (base) to ACC_TIER_MAX (10) per player.
//   - There is NO per-tier random Overclock ROLL any more. A tier-up simply
//     raises progress.tier; three FIXED effects (flat damage / glitch-pierce /
//     ammo-back) scale off the tier in _acc_damage. roll_new_overclock_for_weapon
//     and progress.overclocks[] are vestigial/unused (kept only to avoid churn).
//   - Tier advancement costs a LINEAR +4/tier ladder (4 / 8 / ... / 40 = 220 to
//     max a gun), SHARED with the Exo Suit; re-roll cost is dead alongside the roll.
//
// This module replaced the older "3 active per family, 2 Shards to apply" and the
// "random roll per tier" designs. Pools are NOT re-rolled per run.
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
#using scripts\zm\zm_abandoned_cyber_city\_acc_interact_glow;   // cyan "usable" holo on the OC terminal
#using scripts\zm\zm_abandoned_cyber_city\_acc_leveling;        // is_active()/player_level() level gate (docs/45; leveling is LIVE)

// Tier costs per level. ACC_TIER_MAX 5 -> 10 (user 2026-06-24): both the gun Overclock and the Exo Suit
// now go to 10 tiers. The 4 effects scale off the tier in _acc_damage (get_oc_tier, no internal clamp),
// so they extend to T10 automatically: flat dmg +120%, glitch +150%, ammo 50%, shield-pierce 0.04/tier
// (the Riot's front takes 25% dmg at T0 -> 55% at T10; a PARTIAL restore, never a full bypass). Per-tier
// magnitudes retuned 2026-07-08 (dmg 0.10->0.12, glitch 0.25->0.15, ammo 0.10->0.05, pierce 0.05->0.04).
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

// The kiosk's resting card - shown when nobody is standing at it (and during the empty-handed frames of
// the post-purchase re-draw). terminal_hint_loop composes every other state from the NEAREST player.
// Router-safe (memory lui-cursorhint-router-loose-weapon-matcher): contains "hold" but NOT "for", so
// neither the wallbuy ("hold"+" for ") nor the perk ("hold"+"for") matcher hijacks the card.
#define ACC_OC_HINT_IDLE "Hold ^3[{+activate}]^7  ^5CYBERWARE OVERCLOCK^7 - boost your held gun: +damage / glitch-pierce / +ammo (Data Shards)"

// Overclock terminal world model (a theatre ticket kiosk - on-theme tech read; xmodel-listed in the .zone).
// STATION REMODEL (user 2026-07-09, docs/09): Gorod dragon-network data terminal (48x34x78,
// T7-dump carve) - a real tech terminal instead of the thematically-wrong THEATRE ticket kiosk.
#precache( "model", "p7_zm_sta_dragon_network_data_terminal" );

#namespace acc_overclocks;

// ---------------------------------------------------------------------------
// Init
// ---------------------------------------------------------------------------

function init()
{
    acc_utility::log( "overclocks init (Tier 0..10, fixed-effect model)" );

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
    // Per-player, per-weapon tier state.
    // Shape: player.acc_weapon_progress[ weapon_name ] = struct {
    //   tier (int 0..ACC_TIER_MAX/10),
    //   overclocks (VESTIGIAL empty array - the per-tier roll was retired; effects
    //               scale off tier alone, so nothing reads this)
    // }
    player.acc_weapon_progress = [];

    // HUD: push the held weapon's Overclock tier as a "vN" indicator near the gun name (mirrors the
    // PaP tier icon). user 2026-06-21.
    player thread oc_hud_loop( player );
}

// Resolve the held weapon's Overclock tier (0..ACC_TIER_MAX/10), mirroring _acc_damage::get_oc_tier: held-object
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
// Pool definition. Synced with docs/04_weapons.md.
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
        // ABOVE-GROUND MAP-TRIGGER GUARD (user 2026-06-25): ignore any MAP-PLACED acc_overclock_terminal that
        // is NOT underground - this kills the old "invisible overclock machine in the Lab" exploit (a stray
        // model-less trigger the deleted-in-source entity 107 left behind in the live BSP). NOTE (user 2026-07-26):
        // this does NOT block the Lab overclock any more - the intended terminals (trench L2/L5, Paradise, AND the
        // Lab station beside PaP) are all SCRIPT-SPAWNED via spawn_terminal_at, which threads terminal_loop
        // directly and bypasses this loop entirely. So this guard only rejects stray MAP triggers; the deliberate
        // above-ground Lab terminal is spawned in _acc_glitch_altar::spawn_altars and is unaffected. We guard in
        // GSC because the .map deletion only lands on a FULL build - this keeps the exploit closed on a GSC-only
        // build even while the old BSP still carries the deleted Lab trigger.
        if ( acc_bus_trench::underground_layer( triggers[ i ].origin ) <= 0 )
        {
            acc_utility::log( "overclocks: ignoring above-ground terminal at " + triggers[ i ].origin + " (trench-only)" );
            continue;
        }
        triggers[ i ] thread terminal_loop();
        triggers[ i ] thread terminal_hint_loop();   // per-player card keeper (see terminal_hint_loop)
        level.acc_oc_kiosk_origins[ level.acc_oc_kiosk_origins.size ] = triggers[ i ].origin;
    }
}

// Spawn an Overclock terminal (kiosk model + a hold-USE trigger running the existing
// terminal_loop) at origin, facing yaw. Pure GSC - the trench "Foundry" home for the
// weapon-tier system. Called by _acc_glitch_altar with the underground origins.
function spawn_terminal_at( origin, yaw )
{
    m = spawn( "script_model", origin );
    m setmodel( "p7_zm_sta_dragon_network_data_terminal" );
    if ( isdefined( yaw ) ) m.angles = ( 0, yaw, 0 );
    acc_interact_glow::glow_on( m );

    t = spawn( "trigger_radius_use", origin + ( 0, 0, 40 ), 0, 64, 80 );
    t TriggerIgnoreTeam();   // REQUIRED for a script-spawned use-trigger to be player-usable (stock _zm_perks.gsc:1523).
    t SetCursorHint( "HINT_NOICON" );
    t.acc_terminal_model = m;   // glow_off target on first successful overclock (user 2026-07-17)
    // Buyable-UI audit fix (2026-07-03): "upgrade"+"weapon" made the Aetherium router show the
    // PACK-A-PUNCH card at this kiosk. "boost your held gun" avoids every router token ->
    // clean DefaultHint card with this text verbatim. Costs are DATA SHARDS (audit typo fix).
    // The kiosk's live tier/cost/result feedback ALSO lives in this hint now - the old floating
    // hud_msg popups are gone (user 2026-07-03: "remove the original display UI when you trigger
    // things"). terminal_hint_loop (not terminal_loop) owns every update since the co-op fix below.
    t SetHintString( ACC_OC_HINT_IDLE );
    t thread terminal_loop();
    t thread terminal_hint_loop();
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
        // trigger things"): every hud_msg popup here became a TRIGGER HINT update - the
        // Aetherium default card re-renders live from cursorHintText, so the card itself is
        // the feedback. CO-OP FIX (2026-07-15): those updates used to be written HERE, per
        // interaction, which latched the pressing player's private per-gun state onto the ONE
        // shared trigger entity for the whole team. terminal_hint_loop now owns the card and
        // composes it from the NEAREST player, so this loop is purely TRANSACTIONAL - do not
        // re-add a SetHintString below (it would fight the keeper and re-introduce the latch).
        current = player getcurrentweapon();
        family = weapon_name_to_family( current );
        if ( family == "unknown" || family == "none" )
        {
            wait( 0.5 );   // debounce; the keeper is already showing the not-supported / not-tierable card
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
        // FAIL ACK (user 2026-07-15 "restore a fail message") - mirrors _acc_exo::station_use_loop, full
        // rationale there. Short version: the nearest-player hint keeper made a failed press COMPLETELY
        // silent, so the ack goes back on hud_msg (a PER-PLAYER hudelem - the shared hint structurally
        // cannot address just the presser, which is the co-op bug the keeper fixed). Does NOT undo the
        // 2026-07-03 popup rework, which removed the SUCCESS display, not failure feedback.
        if ( progress.tier >= ACC_TIER_MAX )
        {
            player acc_utility::hud_msg( "^5OVERCLOCK^7 - this weapon is already Tier " + ACC_TIER_MAX + "/" + ACC_TIER_MAX + " MAX" );
            wait( 0.5 );   // debounce; the keeper is already showing this player's MAX card
            continue;
        }

        next_tier = progress.tier + 1;
        // [acc] LEVEL GATE (docs/45): your player level caps how high ANY gun can be overclocked
        // (LV N -> max OC tier N, twin of the exo gate). Deny BEFORE the shard spend so a level-locked
        // press costs nothing. is_active() is LIVE (leveling promoted out of dev 2026-07-22).
        if ( acc_leveling::is_active() && next_tier > acc_leveling::player_level( player ) )
        {
            player acc_utility::hud_msg( "^5OVERCLOCK^7 - Tier " + next_tier + " requires ^5Level " + next_tier + "^7" );
            wait( 0.5 );
            continue;
        }
        cost = tier_cost( next_tier );
        if ( !acc_data_shards::try_spend( player, cost ) )
        {
            player acc_utility::hud_msg( "^5OVERCLOCK^7 - Tier " + next_tier + " needs ^5" + cost + "^7 Data Shards" );
            player PlaySound( "acc_shard_deny" );   // [acc] shard-deny buzz (sfx sweep 2026-07-21)
            wait( 0.5 );   // debounce; the keeper is already quoting THIS player's next-tier price
            continue;
        }

        progress.tier = next_tier;
        acc_interact_glow::glow_off( self.acc_terminal_model );   // tier actually bought = successful use

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

        // No success SetHintString: the keeper re-reads progress.tier within 0.25s and re-quotes the NEW
        // next-tier price (or MAX) on its own. The zap SFX + the PaP re-draw above are the "it worked" beat.
        wait( 0.5 );
    }
}

// self = the Overclock terminal trigger. CO-OP CARD KEEPER (2026-07-15).
// WHY: SetHintString is a property of the ONE shared trigger entity, but the overclock TIER is
// per-player AND per-gun. terminal_loop used to write the card per interaction, so it LATCHED whoever
// pressed last: player A maxing their ICR-1 left "Tier 10/10 MAX" on the kiosk, and player B walked up
// holding a Tier-0 Haymaker and was told their gun was already maxed (with no price). Invisible solo -
// with one player the latched string is always your own truth.
// FIX (same shape as _acc_pap_levels::paradise_pap_hint_loop, the proven in-repo precedent for exactly
// this constraint - see also _acc_perk_info.gsc:55 "the shown price can't be per-player on a shared
// trigger"): poll the NEAREST live player and compose the card from THEIR held gun's true-base tier.
// This also stops the kiosk contradicting the per-player OC report card (_acc_perk_info), which was
// already correct - a teammate used to get two conflicting readouts at the same terminal.
function terminal_hint_loop()
{
    self endon( "death" );
    level endon( "end_game" );

    for ( ;; )
    {
        ht = terminal_hint_text( nearest_terminal_player( self.origin ) );
        // Change-guard (mirrors paradise_pap_hint_loop's acc_last_pap_hint). The string set is BOUNDED -
        // 10 tier prices + MAX + unsupported + not-tierable + idle = ~14 - so the 250-triggerstring cache
        // is safe; but an un-guarded 4x/sec SetHintString re-registers the same string every tick for
        // nothing (memory triggerstring-cap-hint-strings: interpolate ONLY small bounded values).
        if ( !isdefined( self.acc_last_oc_hint ) || self.acc_last_oc_hint != ht )
        {
            self SetHintString( ht );
            self.acc_last_oc_hint = ht;
        }
        wait 0.25;
    }
}

// Nearest LIVE player to the kiosk. Mirrors _acc_pap_levels::nearest_pap_player but scoped to this
// terminal's own 64u use-trigger (+ margin, so the card is already right as you walk in) and filtered to
// valid players - a DOWNED teammate bleeding out next to the kiosk must not drive the card, since they
// cannot buy. undefined = nobody there -> the idle discovery string.
function nearest_terminal_player( origin )
{
    best = 10000;   // 100u squared
    np = undefined;
    players = GetPlayers();
    for ( i = 0; i < players.size; i++ )
    {
        p = players[ i ];
        if ( !isdefined( p ) || !isplayer( p ) ) continue;
        if ( !acc_data_shards::is_player_alive( p ) ) continue;
        d = DistanceSquared( p.origin, origin );
        if ( d < best ) { best = d; np = p; }
    }
    return np;
}

// The kiosk card text for `player` (undefined = nobody near). READ-ONLY on purpose: resolves the tier via
// held_oc_tier, NOT get_or_init_progress - the latter MUTATES player.acc_weapon_progress, and a 4x/sec
// display poll must never allocate progress structs for every gun a player happens to walk up holding.
// held_oc_tier keys off the held object then falls back to true_base, matching terminal_loop's tier key.
function terminal_hint_text( player )
{
    if ( !isdefined( player ) ) return ACC_OC_HINT_IDLE;

    current = player getcurrentweapon();
    // EMPTY-HANDED GUARD: replay_pack_draw (the post-purchase re-draw) has a multi-frame window with no
    // weapon held, and weaponNone falls through weapon_name_to_family to "unknown" - without this the card
    // would flash "this weapon is not supported" for a tick right after a SUCCESSFUL tier-up.
    if ( !isdefined( current ) || current == level.weaponNone ) return ACC_OC_HINT_IDLE;

    family = weapon_name_to_family( current );
    if ( family == "unknown" ) return "^5CYBERWARE OVERCLOCK^7 - this weapon is not supported";
    if ( family == "none" ) return "^5CYBERWARE OVERCLOCK^7 - this weapon class cannot be tiered";

    tier = held_oc_tier( player );
    if ( tier >= ACC_TIER_MAX )
        return "^5CYBERWARE OVERCLOCK^7 - Tier " + ACC_TIER_MAX + "/" + ACC_TIER_MAX + " MAX ^7(damage / glitch-pierce / ammo all +)";

    next_tier = tier + 1;
    return "^5CYBERWARE OVERCLOCK^7 - Tier " + next_tier + " costs ^5" + tier_cost( next_tier ) +
           " Data Shards^7 - hold ^3[{+activate}]^7 to boost";
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
                     "t9_grav", "t9_xm4" );        // Grav (CW, Galil stats + CW model, 2026-07-05), XM4 (CW, 2026-07-04)
    // ASM1 RETIRED 2026-07-03 (user) - re-add "s1_asm1" first in this array to restore.
    smg_list = array( "s4_ppsh41_base", "t9_ak74u",  // PPSH-41, AK-74u
                      "apex_prowler", "apex_alternator" );  // Apex Prowler + Alternator (2026-07-06; Chicom removed)
    sg_list = array( "s1_tac19", "t6_olympia",      // Tac-19, Olympia (BO2, 2026-06-15)
                     "t9_streetsweeper", "s1_cel3", "apex_peacekeeper" ); // Streetsweeper, CEL-3, + Peacekeeper (Apex, 2026-07-06)
    sr_list = array( "s1_mk14", "s1_mors", "apex_tripletake" ); // MK14 (AW DMR) + MORS (AW railgun) + Triple Take (Apex energy sniper, replaces the M16 2026-07-11)
    lmg_list = array( "t9_m60", "t9_rpd", "t6_hamr" );   // M60 + RPD (Cold War LMGs, 2026-06-26) + HAMR (BO2, 2026-07-10)

    // Pistols are NOW Overclock-able (user 2026-06-22: "every gun except wunderwaffe").
    pistol_list = array( "t6_fiveseven", "s1_rw1" ); // Five-Seven + RW1 (AW energy pistol). Klauser removed (Apex migration 2026-07-06).

    // SPECIAL weapons that DO Overclock (user 2026-06-23: "every weapon except the Action Figure"). The Mahem
    // launcher + Thundergun WW gain the damage + vs-glitch tiers (the headshot->ammo effect is inert on them -
    // explosions / wind-blast don't headshot - but harmless). "special" is just the overclockable gate; the OC
    // effects are tier-based and family-agnostic, so the value string beyond none/unknown doesn't change them.
    special_list = array( "s1_mahem", "apex_beam_rifle", "thundergun", "t6_war_machine",
                          "apex_lstar",     // Mahem + Apex Havoc + Thundergun + War Machine + THE CYBERJACK (L-STAR plasma LMG, docs/43 - user 2026-07-17 "this gun should be able to overclock"; energy special, OC damage+vs-glitch tiers, family-agnostic)
                          "s1_mdl",         // EPG-1 plasma-lobber (added 2026-07-25, MISSED here = "unknown"/blocked - user bug report 2026-07-30 "the new grenade launcher cant be overclocked"; same launcher class as Mahem/War Machine)
                          "special_discgun" ); // D13 Sector disc launcher (added 2026-07-24, same fall-through bug caught in the same audit; exact-name verified vs _acc_map_randomizer:622)

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

// REMOVED 2026-07-15 (audit): `function strip_pap_suffix( weapon )` lived here and was DEAD - zero
// callers anywhere. It resolved a weapon via zm_weapons::get_base_weapon, which is NOT twin-aware: it
// strips the PaP mapping but NOT our _acc variant-twin suffix, the exact failure this file's own note at
// :508 records ("strip_pap_suffix (get_base_weapon) alone does NOT strip the _acc twin suffix, so a twin
// fell ..."). Leaving a dead, known-twin-unsafe resolver in the file was a ready-made regression for the
// next caller who reached for the obvious name. Use acc_weapon_variants::true_base for weapon identity.
// (NOTE: _acc_damage.gsc:1998 has an unrelated LIVE strip_pap_suffix( name ) that takes a STRING - it is
// a different function in a different namespace; this removal does not touch it.)

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
