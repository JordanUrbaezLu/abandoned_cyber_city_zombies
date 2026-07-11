// =============================================================================
// _acc_perks.gsc - base-perk effect retuning (Phase 3, docs/10_perks.md)
//
// Owns the map-specific BASE-perk tuning + custom Mega effects that have a real
// GSC lever and don't belong to a more specific module. Current tenants:
//   - Jug hit model (250 HP)       (tune_jugg_health)
//   - QR regen: base 20% / Savior 40% sooner (qr_regen_booster + qr_damage_time_watcher)
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
#using scripts\zm\zm_abandoned_cyber_city\_acc_data_shards;

#insert scripts\shared\shared.gsh;

// Neural Expansion Bay world model (a Cyber City interactive sign kiosk - DNI/neural read; stock t7_props, proven packable).
// STATION REMODEL (user 2026-07-09, docs/09): Gorod drop-pod console (49x44x71, T7-dump carve)
// - a screen-covered tech console for the Neural Expansion read; kills the 6-way sign-kiosk reuse.
#precache( "model", "p7_zm_sta_drop_pod_console_blue" );

// --- Jug hit model (melee ~45 dmg/hit, stock GDT, unchangeable) ---------------
// player_base_health = 100 (stock _zm.gsc:1229) -> no-Jug downs on the 3rd melee.
// with-Jug HP = 100 + jugg add; docs/10: base Jug = 250 HP -> down on the 6th.
// Tuning lever: change ONLY this to move the with-Jug hit count.
#define ACC_JUGG_HEALTH_ADD          150
#define ACC_JUGG_HEALTH_ADD_UPGRADE  150  // stock persistent-upgrade var mirror

// --- Quick Revive regen: base 20% sooner, Savior Mega 40% sooner (docs/10; user 2026-06-21) ---
#define ACC_QR_REGEN_DELAY_BASE   0.80   // base QR: regen delay x0.80 (=20% sooner -> ~1.92s; was 0.85/15%)
#define ACC_QR_REGEN_DELAY_SAVIOR 0.60   // Savior: regen delay x0.60 (=40% sooner -> ~1.44s; was 0.70/30%)
#define ACC_QR_REGEN_RATE         0.10   // ratio healed/server-frame (= stock local regenRate)

// --- Revive time override (docs/10): base QR 2.0s, Savior Mega 1.0s ----------
// Replaces stock reviveTime (3s no-perk / 1.5s stock-QR) via the self.get_revive_time
// reviver hook, so BOTH base QR and Savior key off our numbers.
#define ACC_QR_BASE_REVIVE_TIME   2.0    // base QR reviver
#define ACC_SAVIOR_REVIVE_TIME    1.0    // Savior Mega reviver (half of base QR)

// --- Savior (Mega QR) revive damage reduction (docs/10; user 2026-06-26): take 50% damage while you are
//     actively reviving a teammate. Applied in _acc_elites::on_player_damaged via savior_revive_damage_mult. ---
#define ACC_SAVIOR_REVIVE_DMG_TAKEN  0.50    // fraction of incoming damage taken while a Savior is reviving (50% off)

// --- Perk slots (the marquee shard incentive, user 2026-06-19) ---------------
// Everyone STARTS at ACC_PERK_SLOT_BASE perks; extra slots are bought with Data Shards at the
// underground Neural Expansion Bay (the trench-only economy's headline sink), up to ACC_PERK_SLOT_MAX
// (all 9 perks). Per-player via the stock hook level.get_player_perk_purchase_limit (_zm_utility.gsc:
// 5874-5889). Each extra slot costs more than the last (escalating sink): cost = base + bonus*step.
#define ACC_PERK_SLOT_BASE        4
#define ACC_PERK_SLOT_MAX         10   // 10 perks now (Electric Cherry added as the real 10th, _acc_perk_electric_cherry)
#define ACC_PERK_SLOT_COST_BASE   4
#define ACC_PERK_SLOT_COST_STEP   2

#namespace acc_perks;

function init()
{
    acc_utility::log( "perks init" );

    // Per-player perk-slot limit hook (the stock-sanctioned override, _zm_utility.gsc:5879). The base
    // cap is level.perk_purchase_limit (4, set in the entry script); this hook adds each player's
    // shard-bought bonus on top. Installed here so it is live before any perk machine is used.
    level.get_player_perk_purchase_limit = &acc_perk_slot_limit;

    level thread tune_jugg_health();
    level thread force_perk_machine_facing();
    // Perk machines start lit + buyable via level.vending_machines_powered_on_at_start
    // (set in the entry script before zm_usermap::main) - no power watcher needed.
}

// PERMANENT perk-machine facing fix (user 2026-06-19, after the facing reverted FOUR times). The .map
// "angles" on the perk structs keep getting rolled back to the wrong "0 270 0" by concurrent .map restores;
// re-fixing the (baked) .map keeps losing that race. So instead we FORCE the facing at RUNTIME, where it is
// immune to whatever the .ff baked. Stock perk_machine_spawn_init (_zm_perks.gsc:1526-1560) spawns each
// machine as a script_model and links it to its "zombie_vending" use-trigger via trigger.machine; we just
// re-orient that model. (VERIFIED(acc): the "zombie_vending" targetname is the proven machine handle used by
// _acc_perk_lights; trigger.machine is the spawned model, _zm_perks.gsc:1560.) Yaw 359.999 = the established
// correct facing (these vending models face the player at ~0, not the alcove generator's 270).
function force_perk_machine_facing()
{
    level endon( "end_game" );
    yaw = getdvarfloat( "acc_perk_face_yaw", 359.999 );
    // Machines spawn during stock perk init (normally within a couple seconds). Poll up to ~30s for them,
    // then assert; bail after the window so we never spin forever if the handle ever changes.
    set = 0;
    for ( tries = 0; tries < 60 && set == 0; tries++ )
    {
        set = apply_perk_facing( yaw );
        if ( set == 0 ) wait( 0.5 );
    }
    // Re-assert a few times in case stock finishes orienting a beat after the model spawns.
    for ( i = 0; i < 3; i++ ) { wait( 1.0 ); apply_perk_facing( yaw ); }
    acc_utility::log( "perk facing FORCED at runtime to yaw " + yaw + " on " + set + " machines" );
}

// Set every perk machine model to the given yaw. Returns the count set (0 = machines not spawned yet).
function apply_perk_facing( yaw )
{
    triggers = GetEntArray( "zombie_vending", "targetname" );
    n = 0;
    for ( i = 0; i < triggers.size; i++ )
    {
        t = triggers[ i ];
        if ( isdefined( t ) && isdefined( t.machine ) )
        {
            t.machine.angles = ( 0, yaw, 0 );
            n++;
        }
    }
    return n;
}

// self unused; called as acc_perks::on_player_connect( player ) from acc_main.
function on_player_connect( player )
{
    // Per-player perk-slot bonus (extra slots above the base, bought with shards). Init here so the
    // limit hook never reads it undefined.
    if ( !isdefined( player.acc_perk_slot_bonus ) )
        player.acc_perk_slot_bonus = 0;

    // Revive-time override lives for the whole connection (covers base QR and the
    // sticky Savior Mega flag), so it is started once per connect, NOT per spawn.
    player thread qr_revive_watcher();
}

// ---------------------------------------------------------------------------
// Perk slots - the marquee shard sink (docs/30 §3; user 2026-06-19).
// ---------------------------------------------------------------------------

// Per-player perk capacity. Called BY the engine as self [[level.get_player_perk_purchase_limit]]()
// with self = the player (_zm_utility.gsc:5881), so it returns THIS player's limit: base + bought
// bonus, capped at the max. Dev (IS_TRUE(level.acc_dev), the one dev switch) returns the max so every
// machine is buyable while testing; play normal (acc_dev 0) to test the real shard-bought purchase.
function acc_perk_slot_limit()   // self = player
{
    base = getdvarint( "acc_perk_slot_base", ACC_PERK_SLOT_BASE );
    maxs = getdvarint( "acc_perk_slot_max", ACC_PERK_SLOT_MAX );

    if ( IS_TRUE( level.acc_dev ) )   // dev = every machine buyable (one-flag, user 2026-06-22)
        return maxs;

    bonus = ( isdefined( self.acc_perk_slot_bonus ) ? self.acc_perk_slot_bonus : 0 );
    lim = base + bonus;
    if ( lim > maxs ) lim = maxs;
    if ( lim < 1 ) lim = 1;
    return lim;
}

// Shard cost of the NEXT extra slot, given how many extras the player already owns (escalating).
function perk_slot_cost( bonus )
{
    return getdvarint( "acc_perk_slot_cost_base", ACC_PERK_SLOT_COST_BASE ) +
           ( bonus * getdvarint( "acc_perk_slot_cost_step", ACC_PERK_SLOT_COST_STEP ) );
}

// Spawn the Neural Expansion Bay (model + hold-USE trigger). Called by _acc_glitch_altar with the
// underground origin. Pure GSC (deletable trigger_radius_use - no Radiant brush / zone line).
function spawn_perk_slot_vendor_at( origin, yaw )
{
    m = spawn( "script_model", origin );
    m setmodel( "p7_zm_sta_drop_pod_console_blue" );   // Gorod drop-pod console (screens + blue glow = neural-tech read)
    if ( isdefined( yaw ) ) m.angles = ( 0, yaw, 0 );

    t = spawn( "trigger_radius_use", origin + ( 0, 0, 40 ), 0, 64, 80 );
    t TriggerIgnoreTeam();   // REQUIRED for a script-spawned use-trigger to be player-usable (stock _zm_perks.gsc:1523). Without it you walk up and get no usable prompt.
    t SetCursorHint( "HINT_NOICON" );
    t SetHintString( "Hold ^3[{+activate}]^7  ^5NEURAL EXPANSION^7 - buy +1 Perk Slot (Data Shards)" );
    t.acc_vendor_model = m;
    t thread perk_slot_vendor_loop();
    acc_utility::log( "perk-slot vendor (Neural Expansion Bay) spawned at " + origin );
}

function perk_slot_vendor_loop()   // self = the vendor trigger
{
    self endon( "death" );
    level endon( "end_game" );

    for ( ;; )
    {
        self waittill( "trigger", player );
        if ( !acc_data_shards::is_player_alive( player ) ) continue;

        base = getdvarint( "acc_perk_slot_base", ACC_PERK_SLOT_BASE );
        maxs = getdvarint( "acc_perk_slot_max", ACC_PERK_SLOT_MAX );
        if ( !isdefined( player.acc_perk_slot_bonus ) ) player.acc_perk_slot_bonus = 0;

        if ( ( base + player.acc_perk_slot_bonus ) >= maxs )
        {
            player acc_utility::hud_msg( "^5NEURAL EXPANSION^7 - max perk capacity (" + maxs + " slots)" );
            wait 0.4;
            continue;
        }

        cost = perk_slot_cost( player.acc_perk_slot_bonus );
        if ( !acc_data_shards::try_spend( player, cost ) )
        {
            player acc_utility::hud_msg( "^5NEURAL EXPANSION^7 - +1 Perk Slot costs ^5" + cost + " Data Shards" );
            wait 0.4;
            continue;
        }

        player.acc_perk_slot_bonus += 1;
        player PlaySound( "acc_shard_pickup" );
        player acc_utility::hud_msg( "^5NEURAL EXPANSION^7 - perk capacity now ^2" + ( base + player.acc_perk_slot_bonus ) + " ^7slots" );
        wait 0.4;
    }
}

// self unused; called as acc_perks::on_player_spawned( player ) from acc_main.
function on_player_spawned( player )
{
    // PER-LIFE THREAD KILL (user 2026-06-27 crash-hunt): a BO3 ZM player NEVER notifies "death" during play
    // (a bleed-out routes to spectator; "death" only fires on disconnect). So the loops' self endon("death")
    // does NOT terminate the prior life's instances - re-threading them per respawn LEAKED one qr_regen_booster
    // (+ its qr_damage_time_watcher) and one savior_speed_watcher per full-death respawn, stacking duplicate
    // per-frame setnormalhealth loops + duplicate waittill("damage") subscribers for the rest of a co-op run
    // (slow-burn VM/notify exhaustion). Fire "acc_perk_life" to kill the previous life's copies first, then
    // re-thread - the same per-life idiom _acc_lui uses ("acc_lui_life"). Both loops re-check ownership live.
    player notify( "acc_perk_life" );
    player thread qr_regen_booster();
    player thread savior_speed_watcher();
}

// ---------------------------------------------------------------------------
// Jug 3/6 hit model
// ---------------------------------------------------------------------------

// Re-tune the Jug health add so base Jug downs on the 6th melee (docs/10 3/6).
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
// Quick Revive: HP regen starts sooner after damage - base 20% sooner, Savior
// Mega 40% sooner (docs/10).
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
    self endon( "acc_perk_life" );   // killed + re-threaded each respawn (death never fires on a ZM player)

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
    self endon( "acc_perk_life" );   // child of qr_regen_booster - die with it on respawn (no duplicate damage subs)

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
// (docs/10). Fully replaces stock's computed reviveTime (3s no-perk / 1.5s stock QR).
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
    self endon( "acc_perk_life" );   // killed + re-threaded each respawn (death never fires on a ZM player)

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

// ---------------------------------------------------------------------------
// Savior (Mega QR): 50% damage reduction while actively reviving a teammate (user 2026-06-26).
//
// Returns the incoming-damage multiplier for `player` RIGHT NOW: ACC_SAVIOR_REVIVE_DMG_TAKEN (0.5) while they
// own Mega Quick Revive AND are mid-revive, else 1.0. Called LIVE from the player-damage callback
// (_acc_elites::on_player_damaged) - no poll lag. VERIFIED(acc): self.is_reviving_any is the stock
// reviver-side counter, held > 0 for the WHOLE revive channel (incremented _zm_laststand.gsc:1208 just before
// the channel loop, decremented :1285 after it ends) - so it is true exactly while you are standing on a
// downed teammate channeling the revive. A last-stand revive that never completes still counts (you were
// channeling); self-revive does not (the downed player is is_player_valid==false, rejected earlier in the cb).
// ---------------------------------------------------------------------------

function savior_revive_damage_mult( player )
{
    if ( !isdefined( player ) ) return 1.0;
    if ( !( player HasPerk( "specialty_quickrevive" ) ) ) return 1.0;
    if ( !acc_mega_bottles::has_mega_perk( player, "specialty_quickrevive" ) ) return 1.0;
    if ( !( isdefined( player.is_reviving_any ) && player.is_reviving_any > 0 ) ) return 1.0;
    return ACC_SAVIOR_REVIVE_DMG_TAKEN;
}
