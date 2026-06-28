// =============================================================================
// _acc_points.gsc - kill-point awards with co-op damage splitting
//
// Design reference: docs/06_mechanics.md (Point Economy).
//
// Replaces stock BO3 kill-point awards with:
//   - Regular kill:  70 pts
//   - Headshot kill: 110 pts
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

#define ACC_POINTS_REGULAR_KILL    70    // body/non-headshot kill (user 2026-06-23: 40 -> 70)
#define ACC_POINTS_HEADSHOT_KILL   110    // headshot kill (user 2026-06-23: 100 -> 110)
#define ACC_POINTS_KNIFE_KILL      100

#define ACC_POINTS_KILLER_SHARE    0.70
#define ACC_POINTS_OTHERS_SHARE    0.30

// Fraction of the zombie's max HP a player must contribute to qualify for
// a share of the 30% pool. 5% = anti tag-and-run.
#define ACC_POINTS_MIN_CONTRIB_FRAC 0.05

// Loot Stash / Payroll Ledger (boss-drop item): a FLAT bonus to the KILLER per kill (user 2026-06-23; the
// old +10% multiplier was swallowed by the points round-to-10). Double Points adds a FLAT extra (user
// 2026-06-26: +5 regular / +10 headshot - NOT the base's x2). 15/25 aren't multiples of 10, so the award
// path BANKS the sub-10 remainder (money rounds UP to 10s, _zm_score.gsc:528) and flushes it on a later kill
// -> exact net (award_killer_with_ledger). Nuke payout for a holder = ACC_LEDGER_NUKE.
#define ACC_LEDGER_KILL          10   // regular kill, no Double Points
#define ACC_LEDGER_KILL_DP       15   // regular kill WITH Double Points (additive +5)
#define ACC_LEDGER_HEADSHOT      15   // headshot kill, no Double Points
#define ACC_LEDGER_HEADSHOT_DP   25   // headshot kill WITH Double Points (additive +10)
#define ACC_LEDGER_NUKE          500   // a Nuke gives the holder 500 (vs the stock ~400)

// COMEBACK BONUS (user 2026-06-26): a player who fully bleeds out and respawns the next round comes back with
// their money SET to exactly ACC_COMEBACK_PER_ROUND * round_number (e.g. round 20 -> $10,000). Supports players
// who have a bad start. SET, not added: whatever they kept through the death (stock penalty_died is 0.0, so they
// DO keep it) is wiped and replaced with the target - so a rich player who dies drops to the floor and a broke
// player is lifted to it (user picked "set to exactly", full-death respawns only - NOT last-stand revives,
// which never bleed_out so they don't qualify). See on_player_spawned / watch_comeback_death + docs/06.
#define ACC_COMEBACK_PER_ROUND   500

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

    // KILL-ONLY ECONOMY (user 2026-06-18): no points-per-shot map-wide - you earn ONLY on
    // kills. Suppress the stock per-hit score events (_zm_spawner.gsc:1941/1957/2066/2082 ->
    // "damage" / "damage_ads" / "damage_light"). Reversible: dvar acc_hit_points 1 restores
    // the stock per-hit values; default 0 = removed.
    zm_score::register_score_event( "damage",       &score_per_hit );
    zm_score::register_score_event( "damage_ads",   &score_per_hit );
    zm_score::register_score_event( "damage_light", &score_per_hit );

    // VERIFIED(acc): there is no level-wide "zombie_killed" notify in stock
    // (the only notify site is on the PLAYER, no args - _zm_powerups.gsc:1463).
    // The stock per-death hook is zm_spawner::register_zombie_death_event_callback
    // (_zm_spawner.gsc:2463), invoked ON the killed zombie with one arg
    // (attacker); mod/hit_loc live on the zombie (self.damagemod /
    // self.damagelocation, read the same way by stock at _zm_spawner.gsc:1790).
    zm_spawner::register_zombie_death_event_callback( &on_zombie_death );

    // Loot Stash / Payroll Ledger NUKE bonus (user 2026-06-23): a Nuke pays a holder 500, not the stock 400.
    level thread ledger_nuke_watch();
}

// Loot Stash / Payroll Ledger NUKE bonus: the stock Nuke awards 400 to EVERY player (_zm_powerup_nuke.gsc:154)
// then level-notifies "nuke_complete" (:149). Top up each ledger HOLDER by the difference so their Nuke reads
// ACC_LEDGER_NUKE (500). Flat add (NOT through award_player), so the Double-Points scalar doesn't touch it.
function ledger_nuke_watch()
{
    level endon( "end_game" );
    for ( ;; )
    {
        level waittill( "nuke_complete" );
        players = GetPlayers();
        for ( i = 0; i < players.size; i++ )
        {
            p = players[ i ];
            if ( isdefined( p ) && isplayer( p ) && acc_boss_items::player_has_ledger( p ) )
                // Double Points doubles the Nuke too (user 2026-06-23: a DP Nuke = 1000). The stock 400 already
                // doubles to 800 under DP, so we double our +100 top-up as well -> total 500 (no DP) / 1000 (DP).
                p zm_score::add_to_player_score( ( ACC_LEDGER_NUKE - 400 ) * double_points_scalar( p ) );
        }
    }
}

// ---------------------------------------------------------------------------
// Comeback bonus (user 2026-06-26): a full-death respawn sets money to 500 * round.
// Registered in acc_main::on_player_connect / ::on_player_spawned.
// ---------------------------------------------------------------------------

function on_player_connect( player )
{
    // One watcher per player: a FULL bleed-out (not a last-stand revive) arms the comeback for the next spawn.
    player thread watch_comeback_death();
}

// Mark a pending comeback the instant the player fully bleeds out. A last-stand revive happens BEFORE bleed_out
// (so it never sets this) and the first spawn never bleeds out - so only a genuine death-and-respawn qualifies.
// bled_out is the stock notify fired at _zm_laststand.gsc:523/580 (VERIFIED in the stock mirror).
function watch_comeback_death()
{
    self endon( "disconnect" );
    for ( ;; )
    {
        self waittill( "bled_out" );
        self.acc_comeback_pending = true;
    }
}

// Fires on EVERY spawn (acc_main dispatch). Only acts when a death armed the comeback. Runs during the stock
// spectator-respawn callback (_zm.gsc:3340, before the no-op "died" penalty), so self.score here still holds
// whatever they kept - we overwrite it.
function on_player_spawned( player )
{
    if ( !( isdefined( player.acc_comeback_pending ) && player.acc_comeback_pending ) )
        return;
    player.acc_comeback_pending = false;

    rn = 1;
    if ( isdefined( level.round_number ) && level.round_number > 1 )
        rn = level.round_number;

    target = ACC_COMEBACK_PER_ROUND * rn;
    player comeback_set_score( target );
    player iprintln( "^2Comeback bonus: respawned with $" + target );
}

// SET the player's money to exactly `target` (user chose "set to exactly", not a top-up). take_all is the
// canonical "remove all money" (zeroes self.score); add_to_player_score then awards the target and re-syncs both
// self.score and self.pers["score"] (+ the HUD). target is always a multiple of 10 (500 * round), so
// add_to_player_score's round-up-to-10 is a no-op. Net result is exactly `target` whether they came back rich
// (dropped to the floor) or broke (lifted to it).
function comeback_set_score( target )
{
    self zm_score::player_reduce_points( "take_all" );
    self zm_score::add_to_player_score( target );
}

// Signature must match the dispatch at _zm_score.gsc:147; self = player.
function suppress_stock_kill_score( event, mod, hit_location, zombie_team, damage_weapon )
{
    return 0; // _acc_points owns all kill awards (docs/06_mechanics.md Point Economy)
}

// Per-hit points (the +10/shot). Default 0 = kill-only economy (user 2026-06-18). Set
// acc_hit_points 1 to restore the stock per-hit values the _zm_score switch would have used.
function score_per_hit( event, mod, hit_location, zombie_team, damage_weapon )
{
    if ( getdvarint( "acc_hit_points", 0 ) != 1 )
        return 0;

    normal = 10;
    if ( isdefined( level.zombie_vars ) && isdefined( level.zombie_vars[ "zombie_score_damage_normal" ] ) )
        normal = level.zombie_vars[ "zombie_score_damage_normal" ];

    if ( event == "damage_light" )
    {
        light = normal;
        if ( isdefined( level.zombie_vars ) && isdefined( level.zombie_vars[ "zombie_score_damage_light" ] ) )
            light = level.zombie_vars[ "zombie_score_damage_light" ];
        return light;
    }
    if ( event == "damage_ads" )
        return int( normal * 1.25 );
    return normal;
}

function on_zombie_death( attacker ) // self = the killed zombie
{
    // Trench surge/drip zombies (tagged in _acc_bus_trench::tag_trench_zombie) are a THREAT, not a payout: a
    // flat tiny BASE award (default 30, dvar acc_trench_zombie_points - set 0 for none), with NO damage-share
    // split or Kinetic Battery accrual, and excluded from the round count (ignore_enemy_count). (user 2026-06-26:
    // 20 -> 30.) The Loot Stash / Payroll Ledger bonus DOES apply, though (user 2026-06-26: "Loot stash doesnt
    // work on trench zombies") - award_killer_with_ledger adds it (incl. the headshot tier) on top of the flat
    // base, exactly like a normal kill, instead of the plain award_player that skipped it.
    if ( isdefined( self.acc_trench_zombie ) && self.acc_trench_zombie )
    {
        if ( isdefined( attacker ) && isplayer( attacker ) )
            award_killer_with_ledger( attacker, getdvarint( "acc_trench_zombie_points", 30 ), self.damagelocation );
        return;
    }

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
            attacker iprintln( "^3Charged shot ready" ); // Zapper Handle (kinetic-battery effect)
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

    // Loot Stash / Payroll Ledger bonus is folded into the killer's award by award_killer_with_ledger (flat
    // +10/+15 regular, +15/+25 headshot keyed to Double-Points state; banked so the non-10 values net exact).
    if ( contributors.size == 0 )
    {
        // Solo / no other qualifiers - killer gets 100%.
        award_killer_with_ledger( killer, base, hit_loc );
        return;
    }

    // Co-op split. VERIFIED(acc): payouts are quantized to 10 by stock
    // add_to_player_score (_zm_score.gsc:528 rounds UP via
    // zm_utility::round_up_score) - compute shares in 10-pt units so the paid
    // total equals base exactly; leftover chunks go to the first contributors.
    killer_pts = int( base * ACC_POINTS_KILLER_SHARE / 10 + 0.5 ) * 10; // nearest 10
    if ( killer_pts > base ) killer_pts = base;
    award_killer_with_ledger( killer, killer_pts, hit_loc );

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

// Team-scoped point multiplier: 2 while the Double Points powerup is active for the player's team,
// else 1. Mirrors stock get_points_multiplier (_zm_score.gsc:339) and reads the exact var the stock
// powerup writes (_zm_powerup_double_points.gsc:79/97). Defensive: any missing var -> 1 (no scaling).
function double_points_scalar( player )
{
    if ( !isdefined( player.team ) ) return 1;
    if ( !isdefined( level.zombie_vars ) ) return 1;
    if ( !isdefined( level.zombie_vars[ player.team ] ) ) return 1;
    if ( !isdefined( level.zombie_vars[ player.team ][ "zombie_point_scalar" ] ) ) return 1;
    return level.zombie_vars[ player.team ][ "zombie_point_scalar" ];
}

// Double-Points scale + floor to the money currency's 10-unit granularity (stock add_to_player_score then
// round_up_score's a no-op). The map suppresses the stock kill award and pays here, so the stock x2 (applied
// in _zm_score::get_points_multiplier to the callback return we zeroed) never reaches our points - we re-apply
// the SAME team scalar the powerup sets (level.zombie_vars[team]["zombie_point_scalar"]=2).
function dp_scaled_floored( player, pts )
{
    return int( pts * double_points_scalar( player ) / 10 ) * 10;
}

function award_player( player, pts )
{
    if ( !isdefined( player ) || !isplayer( player ) ) return;
    if ( pts <= 0 ) return;

    pts = dp_scaled_floored( player, pts );
    if ( pts <= 0 ) return;

    player zm_score::add_to_player_score( pts );   // stock helper so the HUD floater ("+40") + VO cues play
}

// Award the KILLER their Double-Points-scaled base PLUS the Loot Stash / Payroll Ledger flat bonus, in ONE
// payout (single HUD floater). The Ledger bonus is a FLAT amount keyed to Double-Points STATE (user 2026-06-26):
// regular +10 / DP +15, headshot +15 / DP +25 - the DP boost is ADDITIVE (+5 / +10), NOT the base's x2. 15/25
// aren't multiples of 10, and money only moves in 10s (round_up_score), so we BANK the sub-10 remainder on the
// killer and flush it on a later kill: paying whole-tens + carrying the leftover nets EXACTLY the intended
// per-kill amount (the on-screen number alternates 10/20, the banked total is exact).
function award_killer_with_ledger( killer, base_pts, hit_loc )
{
    if ( !isdefined( killer ) || !isplayer( killer ) ) return;

    award = dp_scaled_floored( killer, base_pts );

    if ( acc_boss_items::player_has_ledger( killer ) )
    {
        dp = ( double_points_scalar( killer ) > 1 );
        if ( is_headshot( hit_loc ) )
            amount = ( dp ? ACC_LEDGER_HEADSHOT_DP : ACC_LEDGER_HEADSHOT );
        else
            amount = ( dp ? ACC_LEDGER_KILL_DP : ACC_LEDGER_KILL );

        if ( !isdefined( killer.acc_ledger_bank ) ) killer.acc_ledger_bank = 0;
        killer.acc_ledger_bank += amount;
        pay = int( killer.acc_ledger_bank / 10 ) * 10;   // whole-tens payable now
        killer.acc_ledger_bank -= pay;                   // carry the <10 remainder to the next kill
        award += pay;
    }

    if ( award <= 0 ) return;
    killer zm_score::add_to_player_score( award );
}
