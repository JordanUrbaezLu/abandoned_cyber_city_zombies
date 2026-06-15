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
#using scripts\shared\flag_shared;
#using scripts\shared\hud_util_shared;
#using scripts\shared\util_shared;

#using scripts\zm\_zm_score;
#using scripts\zm\_zm_spawner;

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

#namespace acc_points;

// ---------------------------------------------------------------------------
// Init
// ---------------------------------------------------------------------------

function init()
{
    acc_utility::log( "points init (regular=" + ACC_POINTS_REGULAR_KILL +
                       ", headshot=" + ACC_POINTS_HEADSHOT_KILL +
                       ", knife=" + ACC_POINTS_KNIFE_KILL + ")" );

    // VERIFIED(acc): suppress stock kill awards via
    // zm_score::register_score_event (dispatch _zm_score.gsc:147 - callback
    // return value replaces the award; "death" + "ballistic_knife_death"
    // cover zombies, dogs, and lightning-chain kills). NOTE this is
    // kill-specific, unlike level.player_score_override; per-hit damage
    // points, Carpenter, Nuke, board rebuilds, revives are untouched.
    // The old comment's level.zombie_score_callback does NOT exist in stock.
    // Caveats: (1) stock medal/challenge tracking for kills
    // (_zm_score.gsc:194-219) no longer fires - re-add in the callback if it
    // ever matters; (2) stock special AI use separate events ("death_mechz",
    // "death_thrasher", ...) - register those too if such AI are added.
    zm_score::register_score_event( "death", &suppress_stock_kill_score );
    zm_score::register_score_event( "ballistic_knife_death", &suppress_stock_kill_score );

    // VERIFIED(acc): there is no level-wide "zombie_killed" notify in stock
    // (the only notify site is on the PLAYER, no args - _zm_powerups.gsc:1463).
    // The stock per-death hook is zm_spawner::register_zombie_death_event_callback
    // (_zm_spawner.gsc:2463), invoked ON the killed zombie with one arg
    // (attacker); mod/hit_loc live on the zombie (self.damagemod /
    // self.damagelocation, read the same way by stock at _zm_spawner.gsc:1790).
    zm_spawner::register_zombie_death_event_callback( &on_zombie_death );
}

// Signature must match the dispatch at _zm_score.gsc:147; self = player.
function suppress_stock_kill_score( event, mod, hit_location, zombie_team, damage_weapon )
{
    return 0; // _acc_points owns all kill awards (docs/06_mechanics.md Point Economy)
}

function on_zombie_death( attacker ) // self = the killed zombie
{
    distribute_points( self, attacker, self.damagemod, self.damagelocation );

    // Kinetic Battery accrual (docs/12): every 10 kills charges the battery;
    // _acc_damage consumes the charge (3x next shot) and resets the counter.
    if ( isdefined( attacker ) && isplayer( attacker )
         && isdefined( attacker.acc_item_battery ) && attacker.acc_item_battery
         && !( isdefined( attacker.acc_item_battery_charged ) && attacker.acc_item_battery_charged ) )
    {
        if ( !isdefined( attacker.acc_item_battery_kill_count ) )
        {
            attacker.acc_item_battery_kill_count = 0;
        }
        attacker.acc_item_battery_kill_count++;
        if ( attacker.acc_item_battery_kill_count >= 10 )
        {
            attacker.acc_item_battery_charged = true;
            attacker iprintln( "Kinetic Battery CHARGED" );
        }
    }
}

// ---------------------------------------------------------------------------
// Damage tracking.
//
// Called from _acc_damage.gsc::on_ai_damage on every player-sourced hit.
// `self` = the damaged zombie / elite / boss. `attacker` = player entity.
// `damage` = the (already-multiplier-applied) damage for this hit.
// ---------------------------------------------------------------------------

function record_damage( attacker, damage )
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

function distribute_points( zombie, killer, mod, hit_loc )
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
        per = int( base / contributors.size / 10 ) * 10;
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

    // Co-op split. VERIFIED(acc): payouts are quantized to 10 by stock
    // add_to_player_score (_zm_score.gsc:528 rounds UP via
    // zm_utility::round_up_score) - compute shares in 10-pt units so the paid
    // total equals base exactly; leftover chunks go to the first contributors.
    killer_pts = int( base * ACC_POINTS_KILLER_SHARE / 10 + 0.5 ) * 10; // nearest 10
    if ( killer_pts > base ) killer_pts = base;
    award_player( killer, killer_pts );

    pool_units = int( ( base - killer_pts ) / 10 );
    per_units  = int( pool_units / contributors.size );
    extra      = pool_units - per_units * contributors.size;
    for ( i = 0; i < contributors.size; i++ )
    {
        share = per_units * 10;
        if ( i < extra ) share += 10;
        award_player( contributors[ i ], share );
    }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function base_points_for_kill( mod, hit_loc )
{
    if ( is_knife_kill( mod ) ) return ACC_POINTS_KNIFE_KILL;
    if ( is_headshot( hit_loc ) ) return ACC_POINTS_HEADSHOT_KILL;
    return ACC_POINTS_REGULAR_KILL;
}

function is_knife_kill( mod )
{
    if ( !isdefined( mod ) ) return false;
    // Common BO3 MOD strings from stock callbacks_shared damage args.
    // Covers Bowie Knife and stock melee button swings.
    // VERIFIED(acc): exact stock strings from _weapon_utils.gsc:25.
    if ( mod == "MOD_MELEE" ) return true;
    if ( mod == "MOD_MELEE_WEAPON_BUTT" ) return true;
    if ( mod == "MOD_MELEE_ASSASSINATE" ) return true;
    return false;
}

function is_headshot( hit_loc )
{
    if ( !isdefined( hit_loc ) ) return false;
    // Mirror of _acc_damage.gsc::is_headshot; keep in sync.
    // VERIFIED(acc): valid hitlocs are "head"/"helmet"/"neck"
    // (_zm_utility.gsc:5261, _loadout.gsc:1418); "j_head" is a model bone
    // tag, never a hit location - removed.
    if ( hit_loc == "head" )   return true;
    if ( hit_loc == "helmet" ) return true;
    if ( hit_loc == "neck" )   return true;
    return false;
}

function qualifying_non_killer_contributors( zombie, killer )
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

function award_player( player, pts )
{
    if ( !isdefined( player ) || !isplayer( player ) ) return;
    if ( pts <= 0 ) return;

    // Apply the Payroll Ledger boss-item bonus if equipped on this player.
    // Per docs/12_boss_items.md: applied to the player's SHARE (after split),
    // not to the base award. This prevents tag-share exploits. Shares are
    // multiples of 10, so the effective behavior is: no bonus on shares < 100.
    if ( acc_boss_items::player_has_ledger( player ) )
    {
        pts = int( pts * ACC_POINTS_LEDGER_MULT );
    }

    // VERIFIED(acc): stock add_to_player_score rounds UP to a multiple of 10
    // (_zm_score.gsc:528); floor here so the Ledger bonus never rounds a +10
    // share into +20.
    pts = int( pts / 10 ) * 10;
    if ( pts <= 0 ) return;

    // Use stock _zm_score helper so HUD floater ("+40") and VO cues play.
    player zm_score::add_to_player_score( pts );
}
