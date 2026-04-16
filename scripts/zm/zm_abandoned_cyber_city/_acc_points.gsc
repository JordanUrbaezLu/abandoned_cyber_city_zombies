// =============================================================================
// _acc_points.gsc - kill-point awards with co-op damage splitting
//
// Design reference: docs/06_mechanics.md (Point Economy).
//
// Replaces stock BO3 kill-point awards with:
//   - Regular kill:  40 pts
//   - Headshot kill: 100 pts
//   - Knife kill:    100 pts
//   - Killer gets 70% of base; 30% pool split equally among qualifying
//     non-killer damage contributors. Solo kills (no other contributors)
//     grant 100% to the killer.
//
// Anti-exploit rules (all enforced in record_damage and distribute_points):
//   1. Per-player contribution CAPPED at zombie.maxhealth (no overkill inflation).
//   2. Minimum 5% of maxhealth required to qualify for a share (no tag-and-run).
//   3. Only player-sourced weapon damage tracked (no environmental claims).
//   4. Same player's shots AGGREGATE to one record (no multi-shot inflation).
//   5. Disconnected / invalid players at payout time are skipped.
// =============================================================================

#using scripts\shared\array_shared;
#using scripts\shared\util_shared;

#using scripts\zm\_zm_score;

#using scripts\zm\zm_abandoned_cyber_city\_acc_utility;
#using scripts\zm\zm_abandoned_cyber_city\_acc_boss_items;

// ---------------------------------------------------------------------------
// Tuning constants. See docs/06_mechanics.md.
// ---------------------------------------------------------------------------

#define ACC_POINTS_REGULAR_KILL    40
#define ACC_POINTS_HEADSHOT_KILL   100
#define ACC_POINTS_KNIFE_KILL      100

#define ACC_POINTS_KILLER_SHARE    0.70
#define ACC_POINTS_OTHERS_SHARE    0.30

// Fraction of the zombie's max HP a player must contribute to qualify for
// a share of the 30% pool. 5% = anti tag-and-run.
#define ACC_POINTS_MIN_CONTRIB_FRAC 0.05

// Payroll Ledger (boss-drop item) multiplier on a player's earned share.
// See docs/12_boss_items.md "Payroll Ledger" and docs/06_mechanics.md for
// stacking behavior with Double Points powerup.
#define ACC_POINTS_LEDGER_MULT 1.10

// ---------------------------------------------------------------------------
// Init
// ---------------------------------------------------------------------------

init()
{
    _acc_utility::log( "points init (regular=" + ACC_POINTS_REGULAR_KILL +
                       ", headshot=" + ACC_POINTS_HEADSHOT_KILL +
                       ", knife=" + ACC_POINTS_KNIFE_KILL + ")" );

    // Stock BO3 kill-point awards flow through _zm_score::player_killed_event
    // (stock awards 60 regular / 100 headshot / 130 melee). We need to
    // suppress those and apply our own 40/100/100 via zombie_death_listener.
    //
    // Recommended approach (verified community pattern, Phase 3 work):
    //   1. Set `level.zombie_score_callback = &suppress_stock_score;` early
    //      in init so _zm_score defers to us.
    //   2. Have `suppress_stock_score( player, mod, hit_loc, ... )` return
    //      0 (no stock award).
    //   3. Our `distribute_points()` owns the award.
    //
    // Fallback if the override hook doesn't exist: hook on_ai_killed ahead of
    // stock ordering and zero out the zombie's stored score_award before stock
    // grants it. See docs/16_gsc_reference.md section 2 for `on_ai_killed`.
    //
    // TODO(acc-impl): wire one of these suppression paths during Phase 3.
    // Until wired, stock + our awards will DOUBLE on first compile (a player
    // gets ~100pts per regular kill instead of 40). Obvious in playtest.

    level thread zombie_death_listener();
}

zombie_death_listener()
{
    level endon( "end_game" );

    for ( ;; )
    {
        level waittill( "zombie_killed", zombie, attacker, mod, hit_loc );
        if ( !isdefined( zombie ) ) continue;
        distribute_points( zombie, attacker, mod, hit_loc );
    }
}

// ---------------------------------------------------------------------------
// Damage tracking.
//
// Called from _acc_damage.gsc::on_ai_damage on every player-sourced hit.
// `self` = the damaged zombie / elite / boss. `attacker` = player entity.
// `damage` = the (already-multiplier-applied) damage for this hit.
// ---------------------------------------------------------------------------

record_damage( attacker, damage )
{
    if ( !isdefined( attacker ) ) return;
    if ( !isplayer( attacker ) ) return;       // anti-exploit #3: players only
    if ( !isdefined( damage ) || damage <= 0 ) return;
    if ( !isdefined( self.maxhealth ) || self.maxhealth <= 0 ) return;

    if ( !isdefined( self.acc_damage_contrib ) )
    {
        self.acc_damage_contrib = [];
    }

    // Stable per-player key. getentitynumber survives disconnect (we verify
    // isdefined + isplayer again at payout time).
    // TODO(acc-verify): confirm getentitynumber is stable across the frame;
    // fall back to player.name if not.
    key = attacker getentitynumber();

    prior = 0;
    if ( isdefined( self.acc_damage_contrib[ key ] ) &&
         isdefined( self.acc_damage_contrib[ key ].damage ) )
    {
        prior = self.acc_damage_contrib[ key ].damage;
    }

    // Anti-exploit #1 + #4: cap cumulative contribution per player at maxhealth.
    new_total = prior + damage;
    if ( new_total > self.maxhealth ) new_total = self.maxhealth;

    if ( !isdefined( self.acc_damage_contrib[ key ] ) )
    {
        self.acc_damage_contrib[ key ] = spawnstruct();
    }
    self.acc_damage_contrib[ key ].damage = new_total;
    self.acc_damage_contrib[ key ].player = attacker;
}

// ---------------------------------------------------------------------------
// Point distribution on zombie death.
// ---------------------------------------------------------------------------

distribute_points( zombie, killer, mod, hit_loc )
{
    base = base_points_for_kill( mod, hit_loc );
    if ( base <= 0 ) return;

    // Partition contributors into killer vs others.
    contributors = qualifying_non_killer_contributors( zombie, killer );

    if ( !isdefined( killer ) || !isplayer( killer ) )
    {
        // Killer gone / invalid (e.g. AI friendly fire not applicable here,
        // but handle gracefully). Redistribute base equally among qualifiers.
        if ( contributors.size == 0 ) return;
        per = int( base / contributors.size );
        for ( i = 0; i < contributors.size; i++ )
        {
            award_player( contributors[ i ], per );
        }
        return;
    }

    if ( contributors.size == 0 )
    {
        // Solo / no other qualifiers - killer gets 100%.
        award_player( killer, base );
        return;
    }

    // Co-op split.
    killer_pts = int( base * ACC_POINTS_KILLER_SHARE );
    others_pool = base - killer_pts; // use remainder to avoid rounding loss

    award_player( killer, killer_pts );

    per_other = int( others_pool / contributors.size );
    if ( per_other <= 0 ) per_other = 1; // minimum award dignity.
    for ( i = 0; i < contributors.size; i++ )
    {
        award_player( contributors[ i ], per_other );
    }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

base_points_for_kill( mod, hit_loc )
{
    if ( is_knife_kill( mod ) ) return ACC_POINTS_KNIFE_KILL;
    if ( is_headshot( hit_loc ) ) return ACC_POINTS_HEADSHOT_KILL;
    return ACC_POINTS_REGULAR_KILL;
}

is_knife_kill( mod )
{
    if ( !isdefined( mod ) ) return false;
    // Common BO3 MOD strings from stock callbacks_shared damage args.
    // Covers Bowie Knife and stock melee button swings.
    if ( mod == "MOD_MELEE" ) return true;
    if ( mod == "MOD_MELEE_WEAPON_BUTT" ) return true;
    if ( mod == "MOD_MELEE_ASSASSINATION" ) return true;
    return false;
}

is_headshot( hit_loc )
{
    if ( !isdefined( hit_loc ) ) return false;
    // Mirror of _acc_damage.gsc::is_headshot; keep in sync.
    if ( hit_loc == "head" )   return true;
    if ( hit_loc == "helmet" ) return true;
    if ( hit_loc == "j_head" ) return true;
    if ( hit_loc == "neck" )   return true;
    return false;
}

qualifying_non_killer_contributors( zombie, killer )
{
    result = [];
    if ( !isdefined( zombie.acc_damage_contrib ) ) return result;
    if ( !isdefined( zombie.maxhealth ) || zombie.maxhealth <= 0 ) return result;

    min_contrib = zombie.maxhealth * ACC_POINTS_MIN_CONTRIB_FRAC;

    keys = getarraykeys( zombie.acc_damage_contrib );
    for ( i = 0; i < keys.size; i++ )
    {
        entry = zombie.acc_damage_contrib[ keys[ i ] ];
        if ( !isdefined( entry ) ) continue;
        if ( !isdefined( entry.player ) ) continue;
        if ( !isplayer( entry.player ) ) continue;           // disconnected -> skip
        if ( isdefined( killer ) && entry.player == killer ) continue;
        if ( !isdefined( entry.damage ) ) continue;
        if ( entry.damage < min_contrib ) continue;          // anti-exploit #2

        result[ result.size ] = entry.player;
    }
    return result;
}

award_player( player, pts )
{
    if ( !isdefined( player ) || !isplayer( player ) ) return;
    if ( pts <= 0 ) return;

    // Apply the Payroll Ledger boss-item bonus if equipped on this player.
    // Per docs/12_boss_items.md: applied to the player's SHARE (after split),
    // not to the base award. This prevents tag-share exploits.
    // Integer floor-rounding: a share of 4 pts yields 4 * 1.10 = 4.4 -> 4
    // (no bonus on tiny shares), which is the documented anti-exploit.
    if ( _acc_boss_items::player_has_ledger( player ) )
    {
        pts = int( pts * ACC_POINTS_LEDGER_MULT );
    }

    // Use stock _zm_score helper so HUD floater ("+40") and VO cues play.
    // Verified in docs/16_gsc_reference.md section 2.
    player _zm_score::add_to_player_score( pts );
}
