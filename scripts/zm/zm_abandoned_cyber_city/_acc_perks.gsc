// =============================================================================
// _acc_perks.gsc - base-perk effect retuning (Phase 3, docs/13_perks.md)
//
// Owns the map-specific BASE-perk tuning + custom Mega effects that have a real
// GSC lever and don't belong to a more specific module. Current tenants:
//   - Jug hit model (250 HP)       (tune_jugg_health)
//   - QR regen: base 15% / Savior 30% sooner (qr_regen_booster + qr_damage_time_watcher)
//   - QR revive: base 2.0s / Savior 1.0s     (qr_revive_time + qr_revive_watcher)
//   - Savior (QR Mega) +15% speed  (savior_speed_watcher + recompute term in
//                                   _acc_utility::recompute_move_speed)
//
// Wired from _acc_main: acc_perks::init() in init(); on_player_connect /
// on_player_spawned dispatched from the matching acc_main hooks.
// =============================================================================

#using scripts\shared\flag_shared;
#using scripts\shared\laststand_shared;

#using scripts\shared\ai\zombie_utility;

#using scripts\zm\zm_abandoned_cyber_city\_acc_utility;
#using scripts\zm\zm_abandoned_cyber_city\_acc_mega_bottles;

#insert scripts\shared\shared.gsh;

// --- Jug hit model (melee ~45 dmg/hit, stock GDT, unchangeable) ---------------
// player_base_health = 100 (stock _zm.gsc:1229) -> no-Jug downs on the 3rd melee.
// with-Jug HP = 100 + jugg add; docs/13: base Jug = 250 HP -> down on the 6th.
// Tuning lever: change ONLY this to move the with-Jug hit count.
#define ACC_JUGG_HEALTH_ADD          150
#define ACC_JUGG_HEALTH_ADD_UPGRADE  150  // stock persistent-upgrade var mirror

// --- Quick Revive regen: base 15% sooner, Savior Mega 30% sooner (docs/13) ---
#define ACC_QR_REGEN_DELAY_BASE   0.85   // base QR: regen delay x0.85 (=15% sooner -> ~2.04s)
#define ACC_QR_REGEN_DELAY_SAVIOR 0.70   // Savior: regen delay x0.70 (=30% sooner -> ~1.68s)
#define ACC_QR_REGEN_RATE         0.10   // ratio healed/server-frame (= stock local regenRate)

// --- Revive time override (docs/13): base QR 2.0s, Savior Mega 1.0s ----------
// Replaces stock reviveTime (3s no-perk / 1.5s stock-QR) via the self.get_revive_time
// reviver hook, so BOTH base QR and Savior key off our numbers.
#define ACC_QR_BASE_REVIVE_TIME   2.0    // base QR reviver
#define ACC_SAVIOR_REVIVE_TIME    1.0    // Savior Mega reviver (half of base QR)

#namespace acc_perks;

function init()
{
    acc_utility::log( "perks init" );
    level thread tune_jugg_health();
    // Perk machines start lit + buyable via level.vending_machines_powered_on_at_start
    // (set in the entry script before zm_usermap::main) - no power watcher needed.
}

// self unused; called as acc_perks::on_player_connect( player ) from acc_main.
function on_player_connect( player )
{
    // Revive-time override lives for the whole connection (covers base QR and the
    // sticky Savior Mega flag), so it is started once per connect, NOT per spawn.
    player thread qr_revive_watcher();
}

// self unused; called as acc_perks::on_player_spawned( player ) from acc_main.
function on_player_spawned( player )
{
    // Both threads endon( "death" ) and are restarted on the next spawn.
    player thread qr_regen_booster();
    player thread savior_speed_watcher();
}

// ---------------------------------------------------------------------------
// Jug 3/6 hit model
// ---------------------------------------------------------------------------

// Re-tune the Jug health add so base Jug downs on the 6th melee (docs/13 3/6).
// VERIFIED(acc): perk_set_max_health_if_jugg reads
// level.zombie_vars["zombie_perk_juggernaut_health"] LIVE on every perk
// give/revive (_zm_perks.gsc:803,835), so setting the var before any player can
// buy Jug (perks aren't buyable during blackscreen) makes it stick for the run.
function tune_jugg_health()
{
    level endon( "end_game" );

    // "initial_blackscreen_passed" is a FLAG; wait_till returns immediately if
    // already set. Stock init_juggernaut() sets the var to 100 at load BEFORE
    // blackscreen, so writing here wins (_zm_perk_juggernaut.gsc:58).
    level flag::wait_till( "initial_blackscreen_passed" );

    zombie_utility::set_zombie_var( "zombie_perk_juggernaut_health", ACC_JUGG_HEALTH_ADD );
    zombie_utility::set_zombie_var( "zombie_perk_juggernaut_health_upgrade", ACC_JUGG_HEALTH_ADD_UPGRADE );

    acc_utility::log( "jugg health add retuned to " + ACC_JUGG_HEALTH_ADD
        + " (base Jug = 250 HP -> 6 melee hits @ 45 dmg)" );
}

// ---------------------------------------------------------------------------
// Quick Revive: HP regen starts sooner after damage - base 15% sooner, Savior
// Mega 30% sooner (docs/13).
//
// VERIFIED(acc): the ZM regen authority (_zm_playerhealth.gsc::playerHealthRegen)
// honors NO per-player override field and uses a hardcoded local regenRate. So we
// run a PARALLEL per-player booster that starts healing earlier than the stock
// delay and matches the stock 0.1/frame ramp. During [scale*delay, delay) stock is
// still in its `continue` window (no setnormalhealth yet) so our writes are
// uncontested; after the delay both heal toward 1.0 (harmless).
// ---------------------------------------------------------------------------

function qr_regen_booster()
{
    self endon( "disconnect" );
    self endon( "death" );

    self.acc_qr_last_hit_time = 0;
    self thread qr_damage_time_watcher();

    for ( ;; )
    {
        WAIT_SERVER_FRAME;

        if ( !( self HasPerk( "specialty_quickrevive" ) ) ) continue;
        if ( !isdefined( self.maxHealth ) || self.maxHealth <= 0 ) continue;
        if ( self.health >= self.maxHealth ) continue;  // already topped off
        if ( self.health <= 0 ) continue;               // downed/dead - leave to stock

        scale = ( acc_mega_bottles::has_mega_perk( self, "specialty_quickrevive" ) ? ACC_QR_REGEN_DELAY_SAVIOR : ACC_QR_REGEN_DELAY_BASE );
        boosted_delay = level.playerHealth_RegularRegenDelay * scale;
        elapsed = gettime() - self.acc_qr_last_hit_time;
        if ( elapsed < boosted_delay ) continue;        // not hurt long enough yet

        ratio = self.health / self.maxHealth;
        new_ratio = ratio + ACC_QR_REGEN_RATE;
        if ( new_ratio > 1.0 ) new_ratio = 1.0;
        self setnormalhealth( new_ratio );
    }
}

// Stamps the time of the player's last AI-damage event so the booster knows when
// the regen window opened. Mirrors stock playerHurtcheck (_zm_playerhealth.gsc:92).
function qr_damage_time_watcher()
{
    self endon( "disconnect" );
    self endon( "death" );

    for ( ;; )
    {
        self waittill( "damage", amount, attacker, dir, point, mod );
        // Ignore friendly-fire timestamps (matches stock filter at :101).
        if ( isdefined( attacker ) && isplayer( attacker ) && isdefined( attacker.team )
             && attacker.team == self.team )
            continue;
        self.acc_qr_last_hit_time = gettime();
    }
}

// ---------------------------------------------------------------------------
// Quick Revive: the revive YOU perform takes 2.0s (base QR) / 1.0s (Savior Mega).
//
// VERIFIED(acc): _zm_laststand.gsc::revive_get_revive_time runs on SELF = the
// reviver; if self.get_revive_time is defined it CALLS it and uses the return
// verbatim (:1161-1164). Nothing else sets that hook (grep clean). Our override
// REPLACES stock's computation (3s no-perk / 1.5s stock QR) entirely, so the
// number we return IS the revive time for any QR owner.
// ---------------------------------------------------------------------------

// self = the reviver. Base Quick Revive -> 2.0s; with the Savior Mega -> 1.0s
// (docs/13). Fully replaces stock's computed reviveTime (3s no-perk / 1.5s stock QR).
function qr_revive_time( e_revivee )
{
    if ( acc_mega_bottles::has_mega_perk( self, "specialty_quickrevive" ) )
        return ACC_SAVIOR_REVIVE_TIME;
    return ACC_QR_BASE_REVIVE_TIME;
}

// Binds self.get_revive_time to qr_revive_time whenever the player owns Quick
// Revive (base OR Savior), so every revive they perform uses our time; clears it
// otherwise. Light 0.5s poll - only matters while a revive is in progress.
function qr_revive_watcher()
{
    self endon( "disconnect" );

    for ( ;; )
    {
        if ( self HasPerk( "specialty_quickrevive" ) )
        {
            if ( !isdefined( self.get_revive_time ) )
                self.get_revive_time = &qr_revive_time;
        }
        else
        {
            if ( isdefined( self.get_revive_time ) && self.get_revive_time == &qr_revive_time )
                self.get_revive_time = undefined;
        }
        wait 0.5;
    }
}

// ---------------------------------------------------------------------------
// Savior (QR Mega): +15% move speed while any OTHER player is down/bleeding out.
// The 1.15 term lives in acc_utility::recompute_move_speed (single move-speed
// authority); this watcher just sets/clears self.acc_savior_speed and recomputes.
//
// VERIFIED(acc): down-state predicate is laststand::player_is_in_laststand()
// (laststand_shared.gsc:18). We count OTHER players only (self being down does
// not grant the buff).
// ---------------------------------------------------------------------------

function savior_speed_watcher()
{
    self endon( "disconnect" );
    self endon( "death" );

    self.acc_savior_speed = false;
    wait 0.25; // let the spawn-path SetMoveSpeedScale(1) reset land first

    for ( ;; )
    {
        want = false;
        if ( acc_mega_bottles::has_mega_perk( self, "specialty_quickrevive" )
             && self HasPerk( "specialty_quickrevive" )
             && any_other_player_down( self ) )
        {
            want = true;
        }

        if ( want != IS_TRUE( self.acc_savior_speed ) )
        {
            self.acc_savior_speed = want;
            acc_utility::recompute_move_speed( self );
        }
        wait 0.25;
    }
}

// True if any player OTHER than `me` is in laststand / bleedout.
function any_other_player_down( me )
{
    players = GetPlayers();
    for ( i = 0; i < players.size; i++ )
    {
        p = players[ i ];
        if ( !isdefined( p ) || p == me ) continue;
        if ( p laststand::player_is_in_laststand() ) return true;
    }
    return false;
}
