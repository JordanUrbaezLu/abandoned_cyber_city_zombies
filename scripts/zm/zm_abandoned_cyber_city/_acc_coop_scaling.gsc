// =============================================================================
// _acc_coop_scaling.gsc - per-player-count HP + spawn-rate scaling (1-4p)
//
// Design reference: docs/12_coop_rules.md (HP Scaling table).
// Targets, all relative to the SOLO value (user 2026-06-24):
//   regular zombie HP : 2p 1.20x / 3p 1.40x / 4p 1.60x  (+20% per extra)
//   elite/boss HP     : 2p 1.50x / 3p 2.00x / 4p 2.50x  (+50% per extra)
//   zombie COUNT      : 2p 1.30x / 3p 1.60x / 4p 1.90x  (+30% per extra, vs SOLO)
// The COUNT target is measured vs the SOLO count: we back stock's OWN per-player count
// term out and apply ours instead, so the per-player count scaling is exactly the table
// above regardless of stock's curve (see acc_coop_max_zombie_override).
//
// What stock actually does (verified vs tmp/bo3_stock_ref, 2026-06-12):
//   - HP: NO per-player term anywhere. ai_calculate_health is purely
//     round-based (zombie_utility.gsc:1906-1929). docs/12's "stock scales HP
//     per player" assumption is wrong about BO3 - the FULL multiplier is
//     our delta to implement, done here via the level.zombie_init_done hook.
//   - Spawn count: stock DOES scale per player (_zm.gsc:3858-3865), but on a
//     curve we don't want - so we invert it to the solo number and re-scale.
//
// Wiring (see _acc_main.gsc / zm_abandoned_cyber_city.gsc):
//   - post_zm_main() from the entry script (AFTER early_round_pacing's) - chains
//     level.max_zombie_func to acc_coop_max_zombie_override (spawn count).
//   - init() from acc_main::init() (before the first zombie spawn) - installs
//     the regular-zombie HP hook.
//   - regular_hp_mult()/special_hp_mult()/boss_hp_player_mult()/spawn_rate_mult()
//     are the public API; elites/bosses apply special_hp_mult() at promote time on
//     a SOLO baseline (never on a maxhealth that already carries regular_hp_mult()).
// =============================================================================

#using scripts\shared\ai\zombie_utility;

#using scripts\zm\zm_abandoned_cyber_city\_acc_utility;

#insert scripts\shared\shared.gsh;

// ---------------------------------------------------------------------------
// Tuning (keep in sync with docs/12_coop_rules.md scaling tables)
// ---------------------------------------------------------------------------

#define ACC_COOP_MAX_PLAYERS 4
#define ACC_COOP_REGULAR_HP_PER_EXTRA 0.2   // regular zombie HP +20%/extra player (user 2026-06-24): 1p 1.0 / 2p 1.2 / 3p 1.4 / 4p 1.6. Was 1.0 (+100%/extra = 2/3/4x - too tanky).
#define ACC_COOP_SPECIAL_HP_PER_EXTRA 0.5
#define ACC_COOP_ELITE_COUNT_LOG_K 0.5       // elite COUNT log-player strength: 1 + k*log2(n); k=0.5 -> 1p 1.0 / 2p 1.5 / 3p 1.79 / 4p 2.0 (user 2026-07-15; elite counts were PLAYER-BLIND before). Live dvar acc_elite_count_log_k.
#define ACC_COOP_SPAWN_PER_EXTRA 0.3        // zombie COUNT +30%/extra player, VS SOLO (user 2026-06-24, re-added; had been removed earlier same day): 1p 1.0 / 2p 1.3 / 3p 1.6 / 4p 1.9. Applied by acc_coop_max_zombie_override on the solo-equivalent count.
// BOSS co-op HP, EXPLICIT PER-COUNT TABLE (user 2026-07-15: 1.00 / 1.70 / 2.30 / 2.60). Replaced the
// 1 + k*log2(n) curve (ACC_COOP_BOSS_HP_LOG_K 0.5 -> 1/1.5/1.79/2.0, user 2026-06-24) - see
// boss_hp_player_mult() for WHY no k can express these numbers. Solo is not listed: it is always 1.0.
#define ACC_COOP_BOSS_HP_2P 1.7   // +70% vs solo
#define ACC_COOP_BOSS_HP_3P 2.3   // +60% over 2p
#define ACC_COOP_BOSS_HP_4P 2.6   // +30% over 3p (curve decelerates - see boss_hp_player_mult)

#namespace acc_coop_scaling;

// ---------------------------------------------------------------------------
// Lifecycle
// ---------------------------------------------------------------------------

function post_zm_main()
{
    acc_utility::log( "coop scaling: post_zm_main (chain max_zombie_func)" );

    // Chain pattern (same as _acc_early_round_pacing::post_zm_main): save whatever override is
    // currently installed (early_round_pacing's, which carries the modifier-round multiplier) as
    // our prev, then install ours ON TOP. The entry script calls early_round_pacing::post_zm_main()
    // BEFORE us, so we wrap it -> stock default_max_zombie_func. Order is load-bearing again
    // (user 2026-06-24: spawn-count override re-added).
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
// Public API (docs/12_coop_rules.md scaling tables)
// ---------------------------------------------------------------------------

// VERIFIED(acc): stock has NO per-player HP term - ai_calculate_health is
// purely round-based (zombie_utility.gsc:1906-1929: zombie_health_start=150,
// +100/round through 9, +10% compounding from round 10; var defaults
// _zm.gsc:1209-1211). The full doc multiplier is therefore the delta we add.

// Regular zombies: 1p 1.0 / 2p 1.2 / 3p 1.4 / 4p 1.6 (of the solo value; +20%/extra player).
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

// BOSSES - EXPLICIT PER-COUNT TABLE (user 2026-07-15): 1p 1.00 / 2p 1.70 / 3p 2.30 / 4p 2.60.
// Consumed by EVERY boss (Brutus, Phantom, Rogue Protector, Avogadro, Panzer + the Paradise mini-boss)
// - this one function is the single co-op boss-HP authority, so retuning it retunes all six.
//
// WHY A TABLE, NOT A CURVE: this REPLACED 1 + k*log2(n) (k = 0.5 -> 1/1.5/1.79/2.0, user 2026-06-24).
// The requested numbers are NOT logarithmic and NO k reproduces them - fitting 2p = 1.70 forces k = 0.70,
// which then yields 2.11 at 3p and 2.40 at 4p, not 2.30/2.60. Since player_count() clamps to 1..4 there
// are only ever three values to state, so a table is the honest shape; a curve here would have to LIE
// about at least one player count. (The old code already hardcoded a log2 switch for the same reason -
// GSC has no log builtin - so this is strictly less indirection, not more.)
//
// The 2026-06-24 rationale STILL HOLDS and this still honors it: the old LINEAR xN made 4p "crazy" tanky,
// and this curve remains far under linear (2.60 vs 4.00 at 4p) and still DECELERATES per added player
// (+0.70 / +0.60 / +0.30) because 4p is not 4x the DPS. It is simply tuned tankier than the old log.
//
// Every value is a LIVE dvar (acc_boss_coop_hp_2p/_3p/_4p) - retune mid-session, no rebuild. Solo has no
// dvar: it is the 1.0 baseline by definition. Apply on the SOLO boss baseline (the absolute boss number),
// like special_hp_mult - never on a health that already carries a co-op mult.
function boss_hp_player_mult()
{
    n = player_count(); // already clamped 1..ACC_COOP_MAX_PLAYERS
    switch ( n )
    {
        case 2:  m = getdvarfloat( "acc_boss_coop_hp_2p", ACC_COOP_BOSS_HP_2P ); break;
        case 3:  m = getdvarfloat( "acc_boss_coop_hp_3p", ACC_COOP_BOSS_HP_3P ); break;
        case 4:  m = getdvarfloat( "acc_boss_coop_hp_4p", ACC_COOP_BOSS_HP_4P ); break;
        default: m = 1.0; break; // 1p (or any out-of-range) -> the solo baseline, never scaled
    }
    if ( m < 1.0 ) m = 1.0; // a bad slider must never make a co-op boss WEAKER than its solo self
    return m;
}

// ELITE/SPECIAL *COUNT* per-player multiplier (user 2026-07-15) - LOGARITHMIC, like the bosses' HP
// used to be: 1 + k*log2(n), k = acc_elite_count_log_k (ACC_COOP_ELITE_COUNT_LOG_K 0.5) ->
// 1p 1.00 / 2p 1.50 / 3p 1.79 / 4p 2.00. Consumed by BOTH elite count curves:
// _acc_elites::elite_quota_for_round (Shielded) and _acc_boss_glitch::glitch_count_for_round.
//
// Before this, elite counts were PLAYER-BLIND: a 4p lobby saw the exact same number of Shielded and
// Glitch Stalkers as a solo run, while the regular horde grew +30%/player (spawn_rate_mult). Elites
// were therefore silently DILUTED in co-op - a shrinking share of the wave as the lobby grew.
//
// WHY LOG AND NOT LINEAR: elites are the expensive actors. Both count curves are also log-in-ROUND
// (see either module), and the two logs COMPOUND - at 4p this doubles the round term, so the round
// term has to stay flat late or the pair overruns ACC_AI_LIMIT (50). Concretely, the REJECTED design
// (linear-in-round counts x this mult) produced 78 elites at r40 4p: past the cap, so the wave would
// have been elites-only with normal zombies starved out of the budget entirely.
//
// player_count() clamps 1..4, so log2(n) is a 3-literal switch (no acc_utility::acc_log2 needed here -
// that exists for the UNBOUNDED round term). Solo is 1.0 by definition: never scaled.
function elite_count_player_mult()
{
    n = player_count(); // already clamped 1..ACC_COOP_MAX_PLAYERS
    switch ( n )
    {
        case 2:  l2 = 1.0;   break;
        case 3:  l2 = 1.585; break;
        case 4:  l2 = 2.0;   break;
        default: l2 = 0.0;   break; // 1p (or any out-of-range) -> 1.0x
    }
    k = getdvarfloat( "acc_elite_count_log_k", ACC_COOP_ELITE_COUNT_LOG_K );
    if ( k < 0 ) k = 0; // a negative k would make co-op spawn FEWER elites than solo
    return 1.0 + ( k * l2 );
}

// Zombie COUNT per-player multiplier, applied to the SOLO-equivalent count (user 2026-06-24,
// re-added): 1p 1.0 / 2p 1.3 / 3p 1.6 / 4p 1.9. Consumed by acc_coop_max_zombie_override.
// (The riot-shield elite quota in _acc_elites is round-based, NOT scaled by this.)
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
        n = ACC_COOP_MAX_PLAYERS; // 5+ unsupported (docs/12: stock caps at 4)
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
    // (docs/12 HP table). The flags are only visible here when set before
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
// Spawn count - level.max_zombie_func override (user 2026-06-24, re-added)
// ---------------------------------------------------------------------------
// Stock calls [[ level.max_zombie_func ]]( n_max, n_round ) once per round to turn the per-round
// max into level.zombie_total (_zm.gsc:3872). n_max ARRIVES already player-scaled
// (get_zombie_count_for_round adds stock's OWN per-player term, _zm.gsc:3858-3865, on a curve we
// don't want). We back that stock co-op term OUT, run the rest of the chain on the exact SOLO
// number, then apply OUR target: 1p 1.0 / 2p 1.3 / 3p 1.6 / 4p 1.9 of SOLO (spawn_rate_mult). So the
// per-player count scaling is exactly our table, independent of stock's curve.
//
// Worked example (round 10, 4 players, stock defaults): multiplier = (10/5)*(10*0.15) = 3.0;
// stock 4p max = 24 + int(3*6*3.0) = 78; solo max = 24 + int(0.5*6*3.0) = 33; ours = ceil(33 * 1.9) = 63.
function acc_coop_max_zombie_override( n_max, n_round )
{
    n_players = stock_round_player_count();

    solo_max = solo_equivalent_max( n_max, n_round, n_players );

    // Run the rest of the chain (early_round_pacing -> stock default_max_zombie_func) on the
    // solo-equivalent input so every multiplier composes off the one solo baseline.
    base = [[ level.acc_coop_prev_max_zombie_func ]]( solo_max, n_round );

    mult = spawn_rate_mult();
    if ( mult <= 1 )
        return base;

    // Integer ceil for positive values (same pattern as _acc_early_round_pacing's override).
    raw = base * mult;
    i = int( raw );
    if ( raw > i )
        return i + 1;
    return i;
}

// Inverts the stock per-player term: replays _zm.gsc:3846-3865 with the same int() truncations,
// subtracts the co-op term stock just added and re-adds the solo term, recovering
// get_zombie_count_for_round's exact 1-player output for this round.
function solo_equivalent_max( n_max, n_round, n_players )
{
    if ( n_players <= 1 )
        return n_max; // already the solo number (solo term applied, _zm.gsc:3858-3861)

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

// VERIFIED(acc): stock passes level.players.size into get_zombie_count_for_round (_zm.gsc:3717),
// which invokes our override in the same synchronous call stack - mirror that exact (unclamped)
// count when backing stock's term out. The clamped player_count() is only for OUR mults.
function stock_round_player_count()
{
    if ( isdefined( level.players ) )
        return level.players.size;
    return GetPlayers().size;
}
