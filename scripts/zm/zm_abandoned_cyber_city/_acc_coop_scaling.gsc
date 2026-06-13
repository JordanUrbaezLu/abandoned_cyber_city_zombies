// =============================================================================
// _acc_coop_scaling.gsc - per-player-count HP + spawn-rate scaling (1-4p)
//
// Design reference: docs/15_coop_rules.md (HP Scaling + Spawn Rate Scaling
// tables). Targets, all relative to the SOLO value:
//   regular zombie HP : 2p 2.00x / 3p 3.00x / 4p 4.00x  (+100% per extra)
//   elite/boss HP     : 2p 1.50x / 3p 2.00x / 4p 2.50x  (+50% per extra)
//   zombie spawn count: 2p 130%  / 3p 160%  / 4p 190%   (+30% per extra)
//
// What stock actually does (verified vs tmp/bo3_stock_ref, 2026-06-12):
//   - HP: NO per-player term anywhere. ai_calculate_health is purely
//     round-based (zombie_utility.gsc:1906-1929). docs/15's "stock scales HP
//     per player" assumption is wrong about BO3 - the FULL doc multiplier is
//     our delta to implement, done here via the level.zombie_init_done hook.
//   - Spawn count: stock DOES scale per player (_zm.gsc:3858-3865), and that
//     term is already baked into the n_max our max_zombie_func override
//     receives - so we back it out to the exact solo number first, then
//     apply the doc table multiplier.
//
// Wiring (see _acc_main.gsc / zm_abandoned_cyber_city.gsc):
//   - post_zm_main() from the entry script, immediately AFTER
//     acc_early_round_pacing::post_zm_main() (chain order matters - we must
//     be invoked FIRST by stock so the solo-normalized input feeds the rest
//     of the chain).
//   - init() from acc_main::init() (before the first zombie spawn).
//   - regular_hp_mult()/special_hp_mult()/spawn_rate_mult() are the public
//     API; elites/bosses apply special_hp_mult() at promote time on a SOLO
//     baseline (never on a maxhealth that already carries regular_hp_mult()).
// =============================================================================

#using scripts\shared\ai\zombie_utility;

#using scripts\zm\zm_abandoned_cyber_city\_acc_utility;

#insert scripts\shared\shared.gsh;

// ---------------------------------------------------------------------------
// Tuning (keep in sync with docs/15_coop_rules.md scaling tables)
// ---------------------------------------------------------------------------

#define ACC_COOP_MAX_PLAYERS 4
#define ACC_COOP_REGULAR_HP_PER_EXTRA 1.0
#define ACC_COOP_SPECIAL_HP_PER_EXTRA 0.5
#define ACC_COOP_SPAWN_PER_EXTRA 0.3

#namespace acc_coop_scaling;

// ---------------------------------------------------------------------------
// Lifecycle
// ---------------------------------------------------------------------------

function post_zm_main()
{
    acc_utility::log( "coop scaling: post_zm_main (chain max_zombie_func)" );

    // Chain pattern copied from _acc_early_round_pacing::post_zm_main (own
    // prev-slot, never clobber). MUST run AFTER it so the full chain is:
    // stock round logic -> us (co-op rescale) -> early pacing (r1-4 mult)
    // -> stock default_max_zombie_func.
    if ( isdefined( level.max_zombie_func ) )
        level.acc_coop_prev_max_zombie_func = level.max_zombie_func;
    else
        level.acc_coop_prev_max_zombie_func = &zombie_utility::default_max_zombie_func;

    level.max_zombie_func = &acc_coop_max_zombie_override;
}

function init()
{
    acc_utility::log( "coop scaling: init (zombie_init_done HP hook)" );

    // VERIFIED(acc): stock only INVOKES level.zombie_init_done, never assigns
    // it (_zm_spawner.gsc:385-387 is the sole stock reference), and no other
    // _acc_ module sets it (repo grep 2026-06-12: only self.zombie_init_done
    // flag polls exist). Chain politely anyway so a future hook composes.
    if ( isdefined( level.zombie_init_done ) )
        level.acc_coop_prev_zombie_init_done = level.zombie_init_done;

    level.zombie_init_done = &on_zombie_init_done;
}

// ---------------------------------------------------------------------------
// Public API (docs/15_coop_rules.md scaling tables)
// ---------------------------------------------------------------------------

// VERIFIED(acc): stock has NO per-player HP term - ai_calculate_health is
// purely round-based (zombie_utility.gsc:1906-1929: zombie_health_start=150,
// +100/round through 9, +10% compounding from round 10; var defaults
// _zm.gsc:1209-1211). The full doc multiplier is therefore the delta we add.

// Regular zombies: 1p 1.0 / 2p 2.0 / 3p 3.0 / 4p 4.0 (of the solo value).
function regular_hp_mult()
{
    return 1.0 + ( ACC_COOP_REGULAR_HP_PER_EXTRA * ( player_count() - 1 ) );
}

// Elites / mini-boss / full boss: 1p 1.0 / 2p 1.5 / 3p 2.0 / 4p 2.5.
// Apply at promote time on the SOLO baseline (level.zombie_health-derived or
// the absolute boss number) - never on a maxhealth that already carries
// regular_hp_mult().
function special_hp_mult()
{
    return 1.0 + ( ACC_COOP_SPECIAL_HP_PER_EXTRA * ( player_count() - 1 ) );
}

// Spawn counts: 1p 100% / 2p 130% / 3p 160% / 4p 190% of solo. Exposed so
// _acc_elites can reuse it for the elite quota (docs/15 spawn table scales
// elites at the same 130/160/190%).
function spawn_rate_mult()
{
    return 1.0 + ( ACC_COOP_SPAWN_PER_EXTRA * ( player_count() - 1 ) );
}

function player_count()
{
    n = GetPlayers().size;
    if ( n < 1 )
        n = 1;
    if ( n > ACC_COOP_MAX_PLAYERS )
        n = ACC_COOP_MAX_PLAYERS; // 5+ unsupported (docs/15: stock caps at 4)
    return n;
}

// ---------------------------------------------------------------------------
// Regular zombie HP - level.zombie_init_done function hook
// ---------------------------------------------------------------------------

// VERIFIED(acc): the hook is invoked ON the zombie with no args -
// 'self [[ level.zombie_init_done ]]()' (_zm_spawner.gsc:387) - at the END of
// zombie_spawn_init, AFTER stock wrote maxhealth/health from
// level.zombie_health (_zm_spawner.gsc:293-311) and BEFORE the
// self.zombie_init_done flag + "zombie_init_done" notify (:389-391). Writes
// here are NOT clobbered, and the promote-time flag pollers
// (_acc_elites.gsc:129, _acc_boss.gsc:125) only wake up after this returns.
function on_zombie_init_done()
{
    if ( isdefined( level.acc_coop_prev_zombie_init_done ) )
        self [[ level.acc_coop_prev_zombie_init_done ]]();

    // Specials scale flatter via special_hp_mult() at promote time
    // (docs/15 HP table). The flags are only visible here when set before
    // init completes (custom fields survive zombie_spawn_init - it only
    // clobbers stock fields like targetname/health). NOTE the current flow:
    // _acc_boss's mini-boss writes ABSOLUTE HP after its init poll
    // (_acc_boss.gsc:135-143), so a regular mult applied here is overwritten
    // and harmless; _acc_elites promotes RELATIVE to z.maxhealth
    // (_acc_elites.gsc:169-171) and must be rewired to special_hp_mult() -
    // tracked as checklist 'coop-elite-hp-flat'.
    if ( IS_TRUE( self.acc_is_elite ) || IS_TRUE( self.acc_is_mini_boss ) || IS_TRUE( self.acc_is_boss ) )
        return;

    mult = regular_hp_mult();
    if ( mult <= 1 )
        return;

    old_max = self.maxhealth;
    new_max = int( old_max * mult );
    if ( new_max < old_max )
        return; // signed-int overflow at extreme rounds - keep the stock value
                // (same guard pattern as ai_calculate_health,
                // zombie_utility.gsc:1917-1922)

    // VERIFIED(acc): health != maxhealth here only when the cleanup-respawn
    // ledger restored a previous life's remaining health
    // (_zm_spawner.gsc:297-301; the writer stores the dying zombie's
    // self.health, zm_giant_cleanup_mgr.gsc:232) - that value already carries
    // this co-op mult from the zombie's first init, so scale only maxhealth
    // and clamp instead of double-scaling.
    ledger_restored = ( self.health != self.maxhealth );

    self.maxhealth = new_max;
    if ( ledger_restored )
    {
        if ( self.health > self.maxhealth )
            self.health = self.maxhealth;
    }
    else
    {
        self.health = new_max;
    }
}

// ---------------------------------------------------------------------------
// Spawn rate - stock calls [[ level.max_zombie_func ]]( n_max, n_round ) once
// per round to turn the per-round max into level.zombie_total (_zm.gsc:3872,
// consumed at _zm.gsc:3717).
// ---------------------------------------------------------------------------

// VERIFIED(acc): n_max arrives ALREADY player-scaled -
// get_zombie_count_for_round (_zm.gsc:3842-3874) starts from
// zombie_vars["zombie_max_ai"] (:3844, default 24 set _zm.gsc:1217), builds
// multiplier = n_round/5 clamped >= 1 (:3846-3850), *= n_round*0.15 from
// round 10 (:3853-3856), then adds int( 0.5 * zombie_ai_per_player *
// multiplier ) solo (:3858-3861) or int( (n_players-1) * zombie_ai_per_player
// * multiplier ) co-op (:3862-3865) BEFORE invoking this hook (:3872).
// zombie_ai_per_player default 6 (_zm.gsc:1218). Stock co-op counts land
// anywhere from ~+17% (r1 2p) to ~+136% (r10+ 4p) over solo - not our doc
// targets - so we back the stock co-op term out, run the rest of the chain
// on the exact solo number, then apply docs/15: 130/160/190% of SOLO.
//
// Worked example (round 10, 4 players, stock defaults): multiplier =
// (10/5) * (10*0.15) = 3.0; stock 4p max = 24 + int(3*6*3.0) = 78;
// solo max = 24 + int(0.5*6*3.0) = 33; ours = ceil(33 * 1.9) = 63.
function acc_coop_max_zombie_override( n_max, n_round )
{
    n_players = stock_round_player_count();

    solo_max = solo_equivalent_max( n_max, n_round, n_players );

    // Run the rest of the chain (_acc_early_round_pacing -> stock
    // default_max_zombie_func) on the solo-equivalent input so every
    // multiplier composes off the one solo baseline.
    base = [[ level.acc_coop_prev_max_zombie_func ]]( solo_max, n_round );

    mult = spawn_rate_mult();
    if ( mult <= 1 )
        return base;

    // Integer ceil for positive values (same pattern as
    // _acc_early_round_pacing::acc_max_zombie_override).
    raw = base * mult;
    i = int( raw );
    if ( raw > i )
        return i + 1;
    return i;
}

// Inverts the stock per-player term: replays _zm.gsc:3846-3865 with the same
// int() truncations, subtracts the co-op term stock just added and re-adds
// the solo term, recovering get_zombie_count_for_round's exact 1-player
// output for this round.
function solo_equivalent_max( n_max, n_round, n_players )
{
    if ( n_players <= 1 )
        return n_max; // already the solo number (solo term applied, :3858-3861)

    if ( !isdefined( level.zombie_vars ) || !isdefined( level.zombie_vars[ "zombie_ai_per_player" ] ) )
        return n_max; // can't reconstruct - leave stock scaling untouched

    per_player = level.zombie_vars[ "zombie_ai_per_player" ];

    multiplier = n_round / 5;
    if ( multiplier < 1 )
        multiplier = 1;
    if ( n_round >= 10 )
        multiplier *= n_round * 0.15;

    coop_term = int( ( ( n_players - 1 ) * per_player ) * multiplier );
    solo_term = int( ( 0.5 * per_player ) * multiplier );

    solo_max = n_max - coop_term + solo_term;
    if ( solo_max < 1 )
        solo_max = 1;
    return solo_max;
}

// VERIFIED(acc): stock passes level.players.size into
// get_zombie_count_for_round (_zm.gsc:3717), which invokes our override in
// the same synchronous call stack - mirror that exact (unclamped) count when
// backing stock's term out. The clamped player_count() is only for OUR mults.
function stock_round_player_count()
{
    if ( isdefined( level.players ) )
        return level.players.size;
    return GetPlayers().size;
}
