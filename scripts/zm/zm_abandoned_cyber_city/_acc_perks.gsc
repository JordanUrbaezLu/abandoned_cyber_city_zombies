// =============================================================================
// _acc_perks.gsc - base-perk effect retuning (Phase 3, docs/13_perks.md)
//
// Owns the map-specific BASE-perk tuning + custom Mega effects that have a real
// GSC lever and don't belong to a more specific module. Current tenants:
//   - Jug 3/6 hit model           (tune_jugg_health)
//   - Quick Revive +30% regen      (qr_regen_booster + qr_damage_time_watcher)
//   - Savior (QR Mega) revive x0.6 (savior_revive_time + savior_revive_watcher)
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

// --- Jug 3/6 hit model (melee = 45 dmg/hit, stock GDT, unchangeable) ---------
// player_base_health = 100 (stock _zm.gsc:1229) -> no-Jug downs on the 3rd melee.
// with-Jug HP = 100 + jugg add; for exactly 6 hits need 225 < HP <= 270, i.e.
// 125 < add <= 170. 150 = robust center -> HP 250 (survive 5x45=225, down 6x45=270).
// Tuning lever: change ONLY this to move the with-Jug hit count.
#define ACC_JUGG_HEALTH_ADD          150
#define ACC_JUGG_HEALTH_ADD_UPGRADE  150  // stock persistent-upgrade var mirror

// --- Quick Revive base +30% faster regen -------------------------------------
#define ACC_QR_REGEN_DELAY_SCALE  0.70   // start regen at 70% of stock delay (=30% sooner)
#define ACC_QR_REGEN_RATE         0.10   // ratio healed/server-frame (= stock local regenRate)

// --- Savior (QR Mega) revive speed -------------------------------------------
#define ACC_REVIVE_BASE_TIME      3      // stock base revive seconds (_zm_laststand.gsc:1154)
#define ACC_SAVIOR_REVIVE_SCALE   0.6    // docs/13: base QR revive duration x0.6

#namespace acc_perks;

function init()
{
    acc_utility::log( "perks init" );
    level thread tune_jugg_health();
}

// self unused; called as acc_perks::on_player_connect( player ) from acc_main.
function on_player_connect( player )
{
    // Savior revive override lives for the whole connection (sticky Mega flag),
    // so it is started once per connect, NOT per spawn.
    player thread savior_revive_watcher();
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
// Quick Revive base: +30% faster HP regen after damage
//
// VERIFIED(acc): the ZM regen authority (_zm_playerhealth.gsc::playerHealthRegen)
// honors NO per-player override field and uses a hardcoded local regenRate. So we
// run a PARALLEL per-player booster that starts healing 30% sooner than the stock
// delay and matches the stock 0.1/frame ramp. During [0.7*delay, delay) stock is
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

        boosted_delay = level.playerHealth_RegularRegenDelay * ACC_QR_REGEN_DELAY_SCALE;
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
// Savior (QR Mega): revive YOU perform completes 40% faster (base QR x0.6)
//
// VERIFIED(acc): _zm_laststand.gsc::revive_get_revive_time runs on SELF = the
// reviver; if self.get_revive_time is defined it CALLS it and uses the return
// verbatim (:1161-1164). Nothing else sets that hook (grep clean). The Savior
// owner always owns base QR, so base revive = 1.5s; Savior = 1.5 * 0.6 = 0.9s.
// The override REPLACES stock's computation, so we include the QR-half ourselves.
// ---------------------------------------------------------------------------

function savior_revive_time( e_revivee )
{
    base_qr_time = ACC_REVIVE_BASE_TIME / 2;          // stock QR half: 3 / 2 = 1.5s
    return base_qr_time * ACC_SAVIOR_REVIVE_SCALE;     // 1.5 * 0.6 = 0.9s
}

// Binds self.get_revive_time to savior_revive_time while the player holds the
// Savior Mega flag AND owns base QR; clears it otherwise. Light 0.5s poll - only
// matters while a revive is in progress.
function savior_revive_watcher()
{
    self endon( "disconnect" );

    for ( ;; )
    {
        if ( acc_mega_bottles::has_mega_perk( self, "specialty_quickrevive" )
             && self HasPerk( "specialty_quickrevive" ) )
        {
            if ( !isdefined( self.get_revive_time ) )
                self.get_revive_time = &savior_revive_time;
        }
        else
        {
            if ( isdefined( self.get_revive_time ) && self.get_revive_time == &savior_revive_time )
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
