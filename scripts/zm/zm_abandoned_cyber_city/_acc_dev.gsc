// =============================================================================
// _acc_dev.gsc - test/dev harness gated on the `acc_dev` dvar - EXCEPT the crosshair damage NUMBERS, which
// are an ALWAYS-ON game FEATURE (set up at the top of init() before the dev gate, user 2026-06-22)
//
// `+set acc_dev 1` (run_game.ps1 sets it by default) turns on a sandbox so the
// whole map can be exercised in one sitting:
//   - Unlimited money: every player's points are topped back up to ~1,000,000
//     whenever they drop below a floor (buy any wallbuy, spam the box, PaP).
//   - Data Shards: each player STARTS with 200 (one-time grant in _acc_data_shards::on_player_connect;
//     NOT a refill loop, so spending behaves normally). Test the Cyberware / Overclock / trench economy.
//   - Perk cap raised to 18 so every machine in the test room is buyable.
//   - Buyable-door markers: a through-walls waypoint over each closed buyable
//     door (the doors stay closed - this just makes them findable). The marker
//     is destroyed once that door's script_flag is set (i.e. it's been bought).
//
// Everything no-ops when acc_dev != 1, so this module is inert in normal play.
// Marker shader is the engine built-in "white" (always present) tinted via
// .color, so it can never introduce a missing-asset build error.
// =============================================================================

#using scripts\shared\callbacks_shared;
#using scripts\shared\flag_shared;
#using scripts\shared\hud_util_shared;
#using scripts\shared\util_shared;

#insert scripts\shared\shared.gsh;

#using scripts\zm\_zm;
#using scripts\zm\_zm_perks;
#using scripts\zm\_zm_score;

#using scripts\zm\zm_abandoned_cyber_city\_acc_utility;
#using scripts\zm\zm_abandoned_cyber_city\_acc_lui;
#using scripts\zm\zm_abandoned_cyber_city\_acc_bus_trench;   // underground_layer() for trench/abyss location titles
#using scripts\zm\zm_abandoned_cyber_city\_acc_weapon_variants;   // true_base() for the dev packed-AK loadout
#using scripts\zm\zm_abandoned_cyber_city\_acc_overclocks;        // get_or_init_progress() for the dev OC tier

#define ACC_DEV_MONEY_TARGET 1000000
#define ACC_DEV_MONEY_FLOOR  100000
#define ACC_DMGQ_MAX         16   // damage-number queue depth (caps lag/drop in heavy multi-hit bursts)

#namespace acc_dev;

function init()
{
    // [acc] Crosshair damage NUMBERS: ALWAYS ON (user 2026-06-22), NOT gated on acc_dev. The user tests
    // balance in the NON-dev god/normal modes (PLAY_GOD_MODE / PLAY_NORMAL) and needs to see the damage
    // dealt, so the feed hook is set BEFORE the dev gate. _acc_damage feeds this from INSIDE its own
    // actor-damage callback (a separate callback does NOT work - stock dispatch short-circuits on the first
    // non -1 return, _zm.gsc:5824, and _acc_damage runs first + returns the modified hit). The rest of the
    // pipeline (acc_center_dmg_add -> acc_center_dmg_push_loop -> acc_lui::set_dmg_num -> acc_hud.lua) lives
    // in always-active modules (proven by it working in dev), so nothing else is needed.
    level.acc_dmg_num_feed = &acc_center_dmg_add;

    // [acc] Top-center AREA-NAME banner (dev_player_hud_loop - historical name; it once shared this loop with a
    // now-removed dev DAMAGE/LOG panel, hence the "dev_" prefix on it + its helpers). ALWAYS ON for EVERY player
    // in BOTH dev and normal play (user 2026-06-27: "the area display when you go from one area to another should
    // be there for both dev and non-dev modes"). It is a permanent game FEATURE - a clean area title that reveals
    // on each area change (5s + fade on the surface, held the whole time you're underground), NOT a dev tool - so
    // it is threaded ABOVE the dev gate. The ONLY dev-only piece is the "DEV MODE ACTIVE" confirmation line inside
    // ensure_dev_huds, which stays gated on level.acc_dev there.
    level thread dev_player_hud_loop();

    // ONE dev switch: level.acc_dev (resolved once in the entry script's acc_resolve_dev_flags(),
    // which runs in main() before this init). Off = normal play; the REST of this harness no-ops.
    if ( !IS_TRUE( level.acc_dev ) )
        return;

    acc_utility::log( "DEV MODE ON (acc_dev 1): unlimited money + 200 shards + all perk slots" );

    // Perk cap is owned per-player by acc_perks::acc_perk_slot_limit (the level.get_player_perk_purchase_limit
    // hook), which returns the MAX while IS_TRUE(level.acc_dev) - so every machine is buyable in dev without
    // raising the global. (Raising level.perk_purchase_limit here would be a no-op: the hook's return overrides it.)

    level thread dev_unlimited_money();
    // DISABLED (user 2026-06-27): the cyan buyable-door waypoints rendered as a big TEAL SQUARE floating in
    // open space (a door whose brush origin resolves to the map center (0,0,0) -> the marker tracks there, not
    // over a door), which read as "a teal box on the zombies." They were redundant in dev anyway (acc_open_map
    // already opens every door), so the door-finder is just removed. create_door_marker/dev_door_markers stay
    // in the file as the referenced HUD-waypoint recipe (see _acc_health_bars wallhack markers) but are no
    // longer threaded. Re-enable by restoring this line if a future build needs to locate unbought doors.
    // level thread dev_door_markers();
    level thread dev_starting_loadout();   // start with the Blast-O-Matic - user 2026-07-03 (was Thundergun 07-02, Action Figure before)

    // (Damage numbers + the room-name banner are now set up ABOVE the dev gate - they are permanent game
    // FEATURES, always on for every player, not dev tools. See the top of init().)

    // Round skip (Machina-style "start the next round"): console `acc_skip_round 1`.
    level thread dev_round_skip_watcher();

    // Jugger-Nog perk-icon test: console `acc_dev_jugg_mega 1` = grant Jug + Mega
    // (icon TEAL), `2` = grant Jug base (icon RED). Self-contained - it GIVES you Jug,
    // so no money/machine needed to see the icon.
    level thread dev_jugg_mega_watcher();

    // Teleports so the greybox door chain never blocks testing:
    //   acc_tp_perks 1  -> the perk row    acc_tp_spawn 1 -> back to spawn
    //   acc_open_doors 1 -> set every enter_* door flag (open the whole map)
    level thread dev_teleport_watcher();
}

// ---------------------------------------------------------------------------
// Dev teleports / open-all-doors (console-driven; greybox door chain bypass)
// ---------------------------------------------------------------------------

function dev_teleport_watcher()
{
    level endon( "end_game" );
    for ( ;; )
    {
        if ( getdvarint( "acc_tp_perks", 0 ) == 1 )
        {
            SetDvar( "acc_tp_perks", "0" );
            dev_tp_players( ( 0, 4090, 32 ), "the perk row" );
        }
        if ( getdvarint( "acc_tp_spawn", 0 ) == 1 )
        {
            SetDvar( "acc_tp_spawn", "0" );
            dev_tp_players( ( -291, -316, 32 ), "spawn" );
        }
        if ( getdvarint( "acc_open_doors", 0 ) == 1 )
        {
            SetDvar( "acc_open_doors", "0" );
            dev_open_all_doors();
        }
        // Reliable power-on for testing the power-gating (perks light + buyable, PaP,
        // traps, fog lift) WITHOUT hunting for the switch. `set acc_power_on 1`.
        if ( getdvarint( "acc_power_on", 0 ) == 1 )
        {
            SetDvar( "acc_power_on", "0" );
            if ( !( level flag::get( "power_on" ) ) )
                level flag::set( "power_on" );
            // Setting the flag alone does NOT fire the stock powered-item callbacks that
            // light the machines - do what the switch (and boss EMP recovery) do: unpause
            // every perk machine so they light up + become buyable (zm_perks 1314-1330).
            level thread zm_perks::perk_unpause_all_perks();
            players = GetPlayers();
            for ( i = 0; i < players.size; i++ )
                if ( isdefined( players[ i ] ) ) players[ i ] IPrintLnBold( "^2>> POWER ON (perks lit + buyable, PaP/traps enabled, fog lifting)" );
            acc_utility::log( "dev: forced power_on + unpaused perks" );
        }
        wait 0.25;
    }
}

function dev_tp_players( org, label )
{
    players = GetPlayers();
    for ( i = 0; i < players.size; i++ )
    {
        p = players[ i ];
        if ( !isdefined( p ) || !isplayer( p ) ) continue;
        p SetOrigin( org );
        p IPrintLnBold( "^3>> Teleported to " + label );
    }
    acc_utility::log( "dev: teleported players to " + label );
}

// Open EVERY barrier so the whole map - Mystery Box included - is walkable from
// spawn. Two classes of barrier, both handled here:
//   1) The 8 buyable doors (zombie_door triggers). flag::set on the door's
//      script_flag only ACTIVATES THE ZONE behind it (stock sets that flag as an
//      OUTPUT of a purchase, _zm_blockers.gsc:1322); it does NOT retract the
//      door slab. So we also physically clear each slab (Hide/NotSolid/
//      ConnectPaths) - the same thing the entry script's acc_hardcoded_open_map
//      does on load.
//   2) The per-run PaP blocker brush. The randomizer (apply_pap_approach) leaves
//      ONE of acc_pap_block_server / acc_pap_block_roof solid every run; it is a
//      bare script_brushmodel (no trigger/flag), so the door pass misses it. That
//      is the "one door that never opens" and it walls off the box when the box
//      rolls to the blocked side - open BOTH.
function dev_open_all_doors()
{
    doors = GetEntArray( "zombie_door", "targetname" );
    for ( i = 0; i < doors.size; i++ )
    {
        door = doors[ i ];
        if ( !isdefined( door ) )
            continue;

        if ( isdefined( door.script_flag ) && flag::exists( door.script_flag ) )
            flag::set( door.script_flag );

        if ( isdefined( door.target ) )
        {
            slab = GetEnt( door.target, "targetname" );
            if ( isdefined( slab ) )
            {
                slab Hide();
                slab NotSolid();
                slab ConnectPaths();
            }
        }

        door TriggerEnable( false );
    }

    dev_open_pap_blockers();

    players = GetPlayers();
    for ( i = 0; i < players.size; i++ )
        if ( isdefined( players[ i ] ) ) players[ i ] IPrintLnBold( "^3>> All doors + PaP blockers opened" );
    acc_utility::log( "dev: opened " + doors.size + " buyable doors + PaP blockers" );
}

// Open BOTH per-run PaP blocker brushes regardless of which side this run blocked
// (inverse of the randomizer's block: Hide / NotSolid / ConnectPaths).
function dev_open_pap_blockers()
{
    names = array( "acc_pap_block_server", "acc_pap_block_roof" );
    for ( n = 0; n < names.size; n++ )
    {
        brushes = GetEntArray( names[ n ], "targetname" );
        for ( i = 0; i < brushes.size; i++ )
        {
            b = brushes[ i ];
            if ( !isdefined( b ) )
                continue;
            b Hide();
            b NotSolid();
            b ConnectPaths();
        }
    }
}

// ---------------------------------------------------------------------------
// Round skip - console: `acc_skip_round 1` advances to the next round
// ---------------------------------------------------------------------------

function dev_round_skip_watcher()
{
    level endon( "end_game" );
    for ( ;; )
    {
        if ( getdvarint( "acc_skip_round", 0 ) == 1 )
        {
            SetDvar( "acc_skip_round", "0" );
            dev_skip_round();
        }
        wait 0.25;
    }
}

function dev_skip_round()
{
    // Kill whatever is alive (clean next round) + zero the spawn budget, then end
    // the round-wait. "kill_round" only fires in developer mode (we run with
    // +set developer 1); the kill + zombie_total=0 ends it regardless.
    team = ( isdefined( level.zombie_team ) ? level.zombie_team : "axis" );
    zombies = GetAITeamArray( team );
    for ( i = 0; i < zombies.size; i++ )
    {
        z = zombies[ i ];
        if ( isdefined( z ) && isalive( z ) )
            z DoDamage( z.health + 1000, z.origin );
    }
    level.zombie_total = 0;
    /# level notify( "kill_round" ); #/

    players = GetPlayers();
    for ( i = 0; i < players.size; i++ )
    {
        if ( isdefined( players[ i ] ) )
            players[ i ] IPrintLnBold( "^3>> SKIPPING TO NEXT ROUND" );
    }
    acc_utility::log( "dev: round skipped" );
}

// ---------------------------------------------------------------------------
// Jugger-Nog Mega toggle - perk-icon indicator test (console: acc_dev_jugg_mega
// 1 = Mega/teal, 2 = base/red). Buy Jug first (the icon needs ownership to show).
// ---------------------------------------------------------------------------

function dev_jugg_mega_watcher()
{
    level endon( "end_game" );
    for ( ;; )
    {
        v = getdvarint( "acc_dev_jugg_mega", 0 );
        if ( v != 0 )
        {
            SetDvar( "acc_dev_jugg_mega", "0" );
            dev_apply_jugg_state( v );
        }
        wait 0.25;
    }
}

// Self-contained perk-icon test: GRANTS Jugger-Nog if you don't already own it (no
// money/machine needed), then sets the Mega flag has_mega_perk() reads so the
// _acc_lui perk_state_watch loop swaps the overlay icon. v: 1 = Jug + Mega (icon
// TEAL), 2 = Jug base (icon RED). give_perk is the stock grant (real perk + HP).
function dev_apply_jugg_state( v )
{
    mega = ( v == 1 );
    players = GetPlayers();
    for ( i = 0; i < players.size; i++ )
    {
        p = players[ i ];
        if ( !isdefined( p ) || !isplayer( p ) ) continue;

        if ( !( p HasPerk( "specialty_armorvest" ) ) )
            p zm_perks::give_perk( "specialty_armorvest", false );

        if ( !isdefined( p.acc_mega_perks ) ) p.acc_mega_perks = [];
        p.acc_mega_perks[ "specialty_armorvest" ] = mega;
        p IPrintLnBold( ( mega ? "^3>> Jugger-Nog + Mega (icon -> ^5TEAL^3)" : "^3>> Jugger-Nog base (icon -> ^1RED^3)" ) );
    }
    acc_utility::log( "dev: jugg state v=" + v + " mega=" + ( mega ? "1" : "0" ) );
}

// DEV starting loadout (user 2026-06-26): every player spawns holding a fully-packed (PaP III) +
// fully-tiered (max Overclock = tier 10) Chicom CQB so the combat-HUD device (gun name / PaP shield /
// OC chip) is testable immediately. Hardcoded in dev (no console dvar). Re-given each life.
function dev_starting_loadout()
{
    level endon( "end_game" );
    callback::on_connect( &dev_loadout_on_connect );
}

function dev_loadout_on_connect()
{
    self thread dev_loadout_per_life();
}

function dev_loadout_per_life()
{
    self endon( "disconnect" );
    level flag::wait_till( "initial_blackscreen_passed" );
    for ( ;; )
    {
        wait 1.5;                          // let the stock starting pistol settle, then hand over the Action Figure
        self dev_give_action_figure();
        self waittill( "spawned_player" ); // re-give on respawn
    }
}

function dev_give_action_figure()
{
    if ( !isdefined( self ) || !isplayer( self ) ) return;

    // Blast-O-Matic dev-start, BASE form (user 2026-07-03 "just give me the base blastomatic
    // on spawn - I'll PaP and overclock it myself"; supersedes the same-day maxed give, which
    // in turn replaced the Thundergun 07-02 / Action Figure before that). No tier/OC records
    // written - the machine and terminal treat it as a fresh gun.
    w = GetWeapon( "t9_semiauto_cosplay" );
    if ( !isdefined( w ) || w == level.weaponNone ) return;

    self GiveWeapon( w );
    self SwitchToWeapon( w );

    self IPrintLnBold( "^2>> DEV: Blast-O-Matic" );
}

// ---------------------------------------------------------------------------
// Damage indicators + zone signage HUD
// ---------------------------------------------------------------------------

// Crosshair damage NUMBER. self = the ATTACKING player; `amount` = the FINAL
// (perk/overclock/PaP-modified) damage, fed by _acc_damage from inside its own
// actor-damage callback via level.acc_dmg_num_feed. See the init() comment for why
// it must be fed there (stock dispatch short-circuit) - a second callback misses
// every modified/headshot/PaP hit.
//
// WHY crosshair, not over each zombie: over-entity arbitrary TEXT in BO3 requires
// globally overriding CoD.Waypoints (the engine's objective/waypoint dispatcher) +
// shipping objectives.json - it errors the whole HUD if that table fails to load
// (proven: zm_countryside hb21waypoints.lua). That system is built for persistent
// quest markers, NOT many-per-second combat popups (it would spam the compass +
// objective list). The reliable, correct path is a crosshair-anchored LUI number:
// you aim at the zombie, so it reads on-target. See acc_hud.lua CoD.AccDmgNum.

// self = player. PER-EVENT damage numbers (user 2026-06-22): every individual damage event - each
// bullet, each shotgun PELLET, and each separate zombie a single bullet hits/penetrates - becomes its
// OWN floating number. NO summing. We QUEUE events here because the accDmgNum value rides ONE networked
// channel that carries only the LAST value per server snapshot, so we cannot deliver many numbers in the
// same instant; the push loop drains ONE queued event per ~0.025s tick (~40/sec - 2x, user 2026-06-22).
// So a spray shows one number per bullet (effectively instant), and a same-frame burst (shotgun pellets /
// one bullet through 2 zombies) appears as a fast flurry of separate numbers over a few tenths of a second.
function acc_center_dmg_add( amount, is_headshot )
{
    if ( !isdefined( amount ) || amount <= 0 ) return;

    if ( !isdefined( self.acc_dmgq ) )
    {
        self.acc_dmgq = [];
        self.acc_dmgq_head = 0;
        self.acc_dmgq_count = 0;
    }
    // PARITY MUST PERSIST ON THE PLAYER, not the push loop (bug fix, user 2026-06-26): the client
    // only re-fires a number when accDmgNum CHANGES, so the parity bit flips each push to make an
    // identical damage value differ. The push loop SELF-TERMINATES after ~1s idle and restarts on
    // the next hit - if parity lived in the loop it reset to 0 every restart, so a player dealing
    // the SAME damage with sporadic fire (loop idles between hits) pushed the IDENTICAL value every
    // time -> no change -> damage numbers silently STOPPED (self-heals only when damage varies).
    // Keeping it on `self` makes consecutive pushes always alternate across loop restarts.
    if ( !isdefined( self.acc_dmg_parity ) ) self.acc_dmg_parity = 0;

    d = int( amount );
    if ( d > 65535 ) d = 65535;            // so dmg*4 + hs*2 + parity still fits the 18-bit field
    ev = d * 2;                            // pack damage + headshot bit (unpacked in the push loop)
    if ( IS_TRUE( is_headshot ) ) ev += 1;

    // Ring buffer. If full, drop the OLDEST so a heavy multi-hit burst can never lag more than ~MAX ticks.
    if ( self.acc_dmgq_count >= ACC_DMGQ_MAX )
    {
        self.acc_dmgq_head = ( self.acc_dmgq_head + 1 ) % ACC_DMGQ_MAX;
        self.acc_dmgq_count--;
    }
    tail = ( self.acc_dmgq_head + self.acc_dmgq_count ) % ACC_DMGQ_MAX;
    self.acc_dmgq[ tail ] = ev;
    self.acc_dmgq_count++;

    if ( !IS_TRUE( self.acc_cdmg_loop_on ) )
    {
        self.acc_cdmg_loop_on = true;
        self thread acc_center_dmg_push_loop();
    }
}

// self = player. Drain the queue one event per tick -> one floating number each (acc_hud.lua pools +
// scatters + rise/fades each over 1s). DRAIN 0.025s = ~40/sec (2x, user 2026-06-22). A literal SECOND
// clientfield channel would overflow the near-full clientuimodel pool and crash stock zmhud.swordEnergy
// at LOAD (see _acc_lui.gsc:73-78), so we double the RATE on the one channel instead. If the local net
// can't deliver 40 distinct values/sec, extras collapse within a snapshot (the prior 0.05s ceiling) -
// dial back toward 0.033 / 0.05 if numbers drop. Queue stays 16 so a burst buffers + drains (now in ~0.4s).
function acc_center_dmg_push_loop()
{
    self endon( "disconnect" );
    level endon( "end_game" );

    idle_ticks = 0;   // parity now lives on self.acc_dmg_parity (persists across loop restarts - see acc_center_dmg_add)

    for ( ;; )
    {
        if ( !isdefined( self ) ) return;

        if ( isdefined( self.acc_dmgq_count ) && self.acc_dmgq_count > 0 )
        {
            ev = self.acc_dmgq[ self.acc_dmgq_head ];   // pop oldest
            self.acc_dmgq_head = ( self.acc_dmgq_head + 1 ) % ACC_DMGQ_MAX;
            self.acc_dmgq_count--;

            // ev = dmg*2 + headshot. Add parity (flips each push) so identical consecutive numbers still
            // re-fire the client callback: final = dmg*4 + hs*2 + parity (acc_hud.lua decodes this).
            self.acc_dmg_parity = 1 - self.acc_dmg_parity;
            acc_lui::set_dmg_num( self, ev * 2 + self.acc_dmg_parity );
            idle_ticks = 0;
        }
        else
        {
            idle_ticks++;
            if ( idle_ticks >= 40 )   // ~2s with an empty queue -> sleep until the next damage event
            {
                self.acc_cdmg_loop_on = false;
                return;
            }
        }

        wait 0.025;   // ~40/sec drain (2x the old 0.05s) - see the function header for the why/limits
    }
}

// Zone signage only (the DMG/DPS side panel was replaced by floating numbers).
function dev_player_hud_loop()
{
    level endon( "end_game" );
    level flag::wait_till( "initial_blackscreen_passed" );

    for ( ;; )
    {
        players = GetPlayers();
        for ( i = 0; i < players.size; i++ )
        {
            p = players[ i ];
            if ( !isdefined( p ) || !isplayer( p ) )
                continue;
            ensure_dev_huds( p );
            dev_update_zone( p );
        }
        wait 0.2;
    }
}

function ensure_dev_huds( p )
{
    // The area banner is now created ON-DEMAND in dev_update_zone and DESTROYED after its 5s hold (user 2026-06-28),
    // so it only holds a per-client hudelem slot while actually visible (frees the pool in co-op). This function now
    // just fires the one-time dev-mode confirmation print.
    if ( IS_TRUE( p.acc_dev_huds_init ) ) return;
    p.acc_dev_huds_init = true;

    // Unmistakable dev-mode confirmation - if you SEE this, acc_dev IS active (also logs as [ SCRIPTER] in
    // console_mp.log). Absent = NOT in dev mode. The zone-banner hud loop runs in BOTH modes; only this print is dev.
    if ( IS_TRUE( level.acc_dev ) )
        p IPrintLnBold( "^2DEV MODE ACTIVE^7 - perk-icon test: console ^3acc_dev_jugg_mega 1^7 (teal) / ^32^7 (red)" );
}

// Create the area-name banner hudelem on demand (TOP, y2). CONDITIONAL/pooled (user 2026-06-28): dev_update_zone
// destroys it after the 5s hold and recreates it here on the next area change, so it only costs a slot while shown.
// y=2 + scale 1.3 (user 2026-06-27): the banner grows DOWNWARD, so a tall line at y20 bled into the top-center boss
// nameplate (y22) + bar (y46) + Paradise timer (y24); pinned at y2 it sits cleanly ABOVE that y[22,60] cluster.
function ensure_zone_banner( p )
{
    if ( isdefined( p.acc_dev_zone_hud ) ) return;
    p.acc_dev_zone_hud = p hud::createFontString( "default", 1.3 );
    p.acc_dev_zone_hud hud::setPoint( "TOP", "TOP", 0, 2 );
    p.acc_dev_zone_hud.color = ( 0.3, 0.85, 1.0 );
    p.acc_dev_zone_hud.alpha = 0;
    p.acc_dev_zone_hud.hidewheninmenu = true;
}

// Location title: show the current AREA's name (top of screen) ONLY when it CHANGES,
// hold 5s, then fade out to declutter the HUD (user 2026-06-21). Re-appears for 5s on the
// next new area. Trench/Abyss layers override the surface zone (e.g. "BUS STATION (TRENCHES LV2)").
function dev_update_zone( p )
{
    area = dev_get_player_area( p );

    // Entered a NEW area -> reveal the title for 5s.
    if ( isdefined( area ) && ( !isdefined( p.acc_dev_cur_zone ) || p.acc_dev_cur_zone != area ) )
    {
        p.acc_dev_cur_zone = area;
        ensure_zone_banner( p );                    // (re)create the banner elem for this reveal
        if ( !isdefined( p.acc_dev_zone_hud ) ) return;   // pool full -> skip; shows on a later change
        p.acc_dev_zone_hud SetText( dev_area_name( area ) );
        p.acc_dev_zone_hud FadeOverTime( 0.3 );
        p.acc_dev_zone_hud.alpha = 0.85;            // fade in
        p.acc_dev_zone_until = GetTime() + 5000;    // hold 5 seconds
        p.acc_dev_zone_shown = true;
        return;
    }

    // UNDERGROUND (trench/abyss) + PARADISE: keep the title up the WHOLE time you're down there - it's pitch
    // black (and Paradise is the dark/foggy finale arena), so a 5s fade gets missed (user 2026-06-22: "went
    // down layers in the trench, didn't see the location title"). Gate on the DEPTH (underground_layer>0) OR
    // Paradise; it still RE-reveals (above) on each area change. On the surface the 5s declutter fade is unchanged.
    if ( acc_bus_trench::underground_layer( p.origin ) > 0 || acc_bus_trench::player_in_second_part( p ) )
    {
        ensure_zone_banner( p );                    // recreate if it was destroyed on the surface before descending
        if ( !isdefined( p.acc_dev_zone_hud ) ) return;
        if ( !( isdefined( p.acc_dev_zone_shown ) && p.acc_dev_zone_shown ) )
        {
            // Title was hidden (e.g. destroyed on the surface before descending) - bring it back up.
            p.acc_dev_zone_hud SetText( dev_area_name( area ) );
            p.acc_dev_zone_hud FadeOverTime( 0.3 );
            p.acc_dev_zone_hud.alpha = 0.85;
            p.acc_dev_zone_shown = true;
        }
        p.acc_dev_zone_until = GetTime() + 5000;    // push the hold forward so it never fades while underground
        return;
    }

    // 5s elapsed since the last change -> fade out (declutter). SURFACE only (underground returned above).
    if ( isdefined( p.acc_dev_zone_shown ) && p.acc_dev_zone_shown &&
         isdefined( p.acc_dev_zone_until ) && GetTime() >= p.acc_dev_zone_until )
    {
        // 5s hold elapsed -> DESTROY the banner to FREE its pool slot (was: fade to alpha 0, which kept the slot).
        // Recreated by ensure_zone_banner on the next area change. SURFACE only (underground returned above). 2026-06-28.
        if ( isdefined( p.acc_dev_zone_hud ) ) p.acc_dev_zone_hud Destroy();
        p.acc_dev_zone_hud = undefined;
        p.acc_dev_zone_shown = false;
    }
}

// Current AREA key: the trench/abyss layer (underground) OVERRIDES the surface zone, so
// descending the trench reads "trench1".."trench5" instead of the corp surface zone.
function dev_get_player_area( p )
{
    layer = acc_bus_trench::underground_layer( p.origin );
    if ( layer > 0 )
        return "trench" + layer;          // trench1 = the pit/Lv1 .. trench5 = the deepest floor
    // The Exchange Bank vault is excluded from underground_layer AND sits below every zone player_volume,
    // so it would read undefined (blank banner). Give it its own key (user 2026-06-27).
    if ( acc_bus_trench::player_in_vault( p ) )
        return "exchange";
    // Paradise (the open-air hub below the abyss, z=-1200) is ALSO excluded from underground_layer and sits below
    // every zone player_volume, so it would read undefined (blank banner). Give it its own key (user 2026-06-27).
    if ( acc_bus_trench::player_in_second_part( p ) )
        return "paradise";
    return dev_get_player_zone( p );       // surface zone key (undefined while between zone volumes)
}

function dev_get_player_zone( p )
{
    if ( !isdefined( level.zones ) )
        return undefined;

    keys = GetArrayKeys( level.zones );
    for ( i = 0; i < keys.size; i++ )
    {
        z = level.zones[ keys[ i ] ];
        if ( !isdefined( z ) || !isdefined( z.volumes ) )
            continue;
        for ( j = 0; j < z.volumes.size; j++ )
        {
            if ( isdefined( z.volumes[ j ] ) && p IsTouching( z.volumes[ j ] ) )
                return keys[ i ];
        }
    }
    return undefined;
}

function dev_zone_name( zone )
{
    switch ( zone )
    {
    case "start_zone":  return "PLAZA";
    case "market_zone": return "MARKET";
    case "alley_zone":  return "ALLEY";
    case "corp_zone":   return "BUS STATION";
    case "vault_zone":  return "VAULT";
    case "roof_zone":   return "HELIPAD";
    case "lab_zone":    return "LAB";
    }
    return zone;
}

// Friendly area name incl. the trench/abyss layers (user format, 2026-06-21:
// "Bus Station (Trenches LvN)"). Surface zones delegate to dev_zone_name().
function dev_area_name( area )
{
    switch ( area )
    {
    case "exchange": return "EXCHANGE BANK";
    case "paradise": return "PARADISE";
    case "trench1": return "BUS STATION (TRENCHES LV1)";
    case "trench2": return "BUS STATION (TRENCHES LV2)";
    case "trench3": return "BUS STATION (TRENCHES LV3)";
    case "trench4": return "BUS STATION (TRENCHES LV4)";
    case "trench5": return "BUS STATION (TRENCHES LV5)";
    }
    return dev_zone_name( area );
}

// ---------------------------------------------------------------------------
// Unlimited money
// ---------------------------------------------------------------------------

function dev_unlimited_money()
{
    level endon( "end_game" );

    // CRASH GUARD (user 2026-07-02 "game won't start"): giving score to a player whose zm
    // stats/bgb structures aren't seeded yet throws through _zm_score -> _zm_bgb ("undefined
    // is not an array index" then a thrown script exception - console_mp.log 23:44). Gate the
    // whole loop on the blackscreen flag (players fully initialized) AND skip any player whose
    // pers score table isn't up yet (late joiners / first ticks).
    level flag::wait_till( "initial_blackscreen_passed" );

    for ( ;; )
    {
        players = GetPlayers();
        for ( i = 0; i < players.size; i++ )
        {
            p = players[ i ];
            if ( !isdefined( p ) || !isplayer( p ) ) continue;
            if ( !isdefined( p.pers ) || !isdefined( p.pers[ "score" ] ) ) continue;

            // Reading .score is fine; only WRITES must go through the API
            // (zm_score::add_to_player_score rounds up to multiples of 10).
            cur = 0;
            if ( isdefined( p.score ) ) cur = p.score;
            if ( cur < ACC_DEV_MONEY_FLOOR )
                p zm_score::add_to_player_score( ACC_DEV_MONEY_TARGET - cur );
        }
        wait 1;
    }
}

// ---------------------------------------------------------------------------
// Buyable-door markers (through-walls waypoints)
// ---------------------------------------------------------------------------

function dev_door_markers()
{
    level endon( "end_game" );

    // Doors are spawned by the stock blocker init during the load flow; wait
    // for the world to be live, then poll briefly for the triggers.
    level flag::wait_till( "initial_blackscreen_passed" );

    doors = [];
    for ( i = 0; i < 30; i++ )
    {
        doors = GetEntArray( "zombie_door", "targetname" );
        if ( doors.size > 0 ) break;
        wait 0.5;
    }
    if ( doors.size == 0 )
    {
        acc_utility::log( "dev: no zombie_door triggers to mark" );
        return;
    }

    for ( i = 0; i < doors.size; i++ )
        level thread dev_mark_one_door( doors[ i ] );
    acc_utility::log( "dev: marking " + doors.size + " buyable doors" );
}

function dev_mark_one_door( door )
{
    level endon( "end_game" );

    // End marking when the door is purchased (its script_flag gets set).
    if ( isdefined( door.script_flag ) )
        level thread end_marking_on_flag( door, door.script_flag );

    markers = [];
    for ( ;; )
    {
        if ( IS_TRUE( door.acc_marker_done ) ) break;

        // (Re)create a marker for any player that doesn't have one yet
        // (handles late joins in co-op tests).
        players = GetPlayers();
        for ( i = 0; i < players.size; i++ )
        {
            p = players[ i ];
            if ( !isdefined( p ) || !isplayer( p ) ) continue;
            key = p GetEntityNumber();
            if ( isdefined( markers[ key ] ) ) continue;
            markers[ key ] = create_door_marker( p, door );
        }
        wait 2;
    }

    keys = GetArrayKeys( markers );
    for ( i = 0; i < keys.size; i++ )
    {
        if ( isdefined( markers[ keys[ i ] ] ) )
            markers[ keys[ i ] ] Destroy();
    }
}

function end_marking_on_flag( door, flagname )
{
    level endon( "end_game" );
    level flag::wait_till( flagname );
    door.acc_marker_done = true;
}

// Cyan square that tracks the door and shows through walls (off-screen arrow
// points toward it). "white" is the engine built-in material, tinted by .color.
function create_door_marker( player, door )
{
    elem = NewClientHudElem( player );
    elem.archived = false;
    elem.x = 0;
    elem.y = 0;
    elem.z = 56;            // float above the door trigger's origin
    elem.alpha = 0.9;
    elem.color = ( 0.15, 0.9, 1.0 );
    elem SetShader( "white", 14, 14 );
    elem SetWaypoint( true ); // constant on-screen size + edge arrow when offscreen
    elem SetTargetEnt( door );
    return elem;
}
