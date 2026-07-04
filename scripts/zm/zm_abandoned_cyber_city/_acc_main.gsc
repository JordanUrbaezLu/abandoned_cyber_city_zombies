// =============================================================================
// _acc_main.gsc - orchestrator for the Abandoned Cyber City custom systems
//
// This module is the only thing the map entry script (zm_abandoned_cyber_city.gsc)
// needs to touch. It fans out to every other _acc_ module and owns the lifecycle
// (pre_init -> init -> round/player callbacks -> shutdown).
//
// Pattern stolen from stock _zm.gsc. Keep ordering stable; several modules
// depend on others being initialized first (see `init()`).
// =============================================================================

#using scripts\codescripts\struct;
#using scripts\shared\array_shared;
#using scripts\shared\callbacks_shared;
#using scripts\shared\flag_shared;
#using scripts\shared\util_shared;

#using scripts\zm\_zm;
#using scripts\zm\_zm_utility;

#using scripts\zm\zm_abandoned_cyber_city\_acc_utility;
#using scripts\zm\zm_abandoned_cyber_city\_acc_data_shards;
#using scripts\zm\zm_abandoned_cyber_city\_acc_cyberware;
#using scripts\zm\zm_abandoned_cyber_city\_acc_overclocks;
#using scripts\zm\zm_abandoned_cyber_city\_acc_elites;
#using scripts\zm\zm_abandoned_cyber_city\_acc_trench_skins;
#using scripts\zm\zm_abandoned_cyber_city\_acc_fury;
#using scripts\zm\zm_abandoned_cyber_city\_acc_map_randomizer;
#using scripts\zm\zm_abandoned_cyber_city\_acc_events_hack;
#using scripts\zm\zm_abandoned_cyber_city\_acc_events_overload;
#using scripts\zm\zm_abandoned_cyber_city\_acc_emergency_drop;
#using scripts\zm\zm_abandoned_cyber_city\_acc_glitch_altar;
#using scripts\zm\zm_abandoned_cyber_city\_acc_music;
#using scripts\zm\zm_abandoned_cyber_city\_acc_ee_song;
#using scripts\zm\zm_abandoned_cyber_city\_acc_reactor;
#using scripts\zm\zm_abandoned_cyber_city\_acc_exo;
#using scripts\zm\zm_abandoned_cyber_city\_acc_abyss_doors;
#using scripts\zm\zm_abandoned_cyber_city\_acc_paradise;
#using scripts\zm\zm_abandoned_cyber_city\_acc_modifiers;
#using scripts\zm\zm_abandoned_cyber_city\_acc_boss;
#using scripts\zm\zm_abandoned_cyber_city\_acc_boss_brutus;
#using scripts\zm\zm_abandoned_cyber_city\_acc_boss_glitch;
#using scripts\zm\zm_abandoned_cyber_city\_acc_boss_phantom;
#using scripts\zm\zm_abandoned_cyber_city\_acc_boss_items;
#using scripts\zm\zm_abandoned_cyber_city\_acc_weapon_variants;
#using scripts\zm\zm_abandoned_cyber_city\_acc_mega_bottles;
#using scripts\zm\zm_abandoned_cyber_city\_acc_transfer;
#using scripts\zm\zm_abandoned_cyber_city\_acc_perks;
#using scripts\zm\zm_abandoned_cyber_city\_acc_weapon_abilities;
#using scripts\zm\zm_abandoned_cyber_city\_acc_points;
#using scripts\zm\zm_abandoned_cyber_city\_acc_corpse_cleanup;
#using scripts\zm\zm_abandoned_cyber_city\_acc_damage;
#using scripts\zm\zm_abandoned_cyber_city\_acc_early_round_pacing;
#using scripts\zm\zm_abandoned_cyber_city\_acc_decontamination;
#using scripts\zm\zm_abandoned_cyber_city\_acc_lockdown;
#using scripts\zm\zm_abandoned_cyber_city\_acc_lockdown_challenge;
#using scripts\zm\zm_abandoned_cyber_city\_acc_perk_doors;
#using scripts\zm\zm_abandoned_cyber_city\_acc_coop_scaling;
#using scripts\zm\zm_abandoned_cyber_city\_acc_zombie_speed;
#using scripts\zm\zm_abandoned_cyber_city\_acc_perk_info;
#using scripts\zm\zm_abandoned_cyber_city\_acc_health_bars;
#using scripts\zm\zm_abandoned_cyber_city\_acc_pap_levels;
#using scripts\zm\zm_abandoned_cyber_city\_acc_atmosphere;
#using scripts\zm\zm_abandoned_cyber_city\_acc_perk_lights;
#using scripts\zm\zm_abandoned_cyber_city\_acc_bus_trench;
#using scripts\zm\zm_abandoned_cyber_city\_acc_power;
#using scripts\zm\zm_abandoned_cyber_city\_acc_dev;
#using scripts\zm\zm_abandoned_cyber_city\_acc_diag;

// ---------------------------------------------------------------------------
// Spawn-intensity tune (2026-06-18). Stock knobs we override. Hardcoded - retune here.
//   ACC_AI_LIMIT       : concurrent LIVE zombies on screen. Stock 24
//                        (_zm.gsc:339); the spawn loop stalls at >= this
//                        (_zm.gsc:3735). Engine HARD cap is 64 (netcode-imposed).
//                        50 = a big horde; safe to run this high because corpses are
//                        DELETED on death (_acc_corpse_cleanup) so they never eat the
//                        actor cap. (4-player netcode may strain near the ceiling -
//                        if it rubber-bands, drop toward ~40.)
//   ACC_ACTOR_LIMIT    : live + corpse cap (_zm.gsc:343; get_current_actor_count =
//                        live AI + GetCorpseArray). Stock 31. With instant corpse
//                        delete, actors ~= alive, so a small +6 headroom over
//                        ACC_AI_LIMIT (covers the brief death-frame + skipped bosses)
//                        is plenty and stays well under the 64 engine ceiling.
//   ACC_SPAWN_DELAY_MULT: scales the stock per-round inter-spawn delay
//                        (_zm.gsc:4598 get_zombie_spawn_delay). 0.85 = waves
//                        fill 15% faster. Floored at 0.1s (stock's own floor).
// ---------------------------------------------------------------------------
#define ACC_AI_LIMIT 50
#define ACC_ACTOR_LIMIT 56
#define ACC_SPAWN_DELAY_MULT 0.85

#namespace acc_main;

// Run before zm::main() so we can register callbacks the stock framework fires.
function pre_init()
{
    acc_utility::log( "pre_init start" );

    // Modifiers are read BEFORE everything else because they can mute/replace
    // subsystems (e.g. "Shardless" disables _acc_data_shards pickup logic).
    acc_modifiers::pre_init();

    // Map randomizer runs next - every other system may read rolled state.
    acc_map_randomizer::pre_init();

    callback::on_connect( &on_player_connect );
    callback::on_spawned( &on_player_spawned );
    callback::on_disconnect( &on_player_disconnect );

    acc_utility::log( "pre_init done" );
}

// Run after zm::main() has finished bootstrapping stock systems.
function init()
{
    acc_utility::log( "init start" );

    // Starting pistol = Five-Seven (Skye BO2 import t6_fiveseven), replacing the
    // stock MR6. Stock sets level.start_weapon = pistol_standard during
    // zm_usermap::main (_zm.gsc:1156); init() runs after that and before any
    // player spawns / give_start_weapon reads it (_zm_utility.gsc:4536). The
    // laststand pistol (level.default_laststandpistol) intentionally stays MR6.
    w_start = GetWeapon( "t6_fiveseven" );
    if ( isdefined( w_start ) && isdefined( level.zombie_weapons ) &&
         isdefined( level.zombie_weapons[ w_start ] ) )
    {
        level.start_weapon = w_start;
        acc_utility::log( "start weapon -> Five-Seven (t6_fiveseven)" );
    }
    else
    {
        acc_utility::log( "start weapon: t6_fiveseven missing from table - kept stock MR6" );
    }

    // Spawn-intensity tune (Moderate): raise the concurrent on-screen cap and
    // speed up the inter-spawn delay. init() runs after zm::main() (where stock
    // sets these defaults, _zm.gsc:337-343/307) and before round 1's spawn loop
    // reads them (_zm.gsc:3735/4502), so our values win and stick. GSC-only.
    configure_spawn_density();

    acc_early_round_pacing::init();
    acc_coop_scaling::init();

    // Atmosphere: cold city-haze fog (Phase 1 of docs/29). Pure GSC; the night
    // sky + wet-ground re-skin + reflection probes are Radiant edits (see doc).
    acc_atmosphere::init();

    // Perk machine + Pack-a-Punch glow on power-on (the base-zombies "machines light
    // up when you turn the power on" look). Server sets a per-machine colour clientfield
    // on the power_on flag; the .csc renders the glow client-side (the path that works
    // here - server-side PlayFX does not). Pure GSC/CSC, no .map edit -> LED-safe.
    acc_perk_lights::init();

    // Bus Station trench: small velocity-gated fall tax when you jump into the
    // cross-room trench (the stair walkway down is free). MOD_FALLING, so PhD
    // negates it. ALWAYS ON (no flag); retune via the ACC_TRENCH_FALL_DMG constant.
    acc_bus_trench::init();

    // Dual-switch power: BOTH Bus Station switches (one each side of the trench)
    // must be flipped to turn the power on (deletes the stock OR-switches). The
    // trench forces a crossing between them. Auto-power stays off (acc_auto_power=0).
    acc_power::init();

    // Single MUSIC CHANNEL - one song at a time; every song source (main theme, boss music, teddy-bear
    // jukebox, Paradise) routes through acc_music::play() so a new song stops the previous (user 2026-06-25).
    // Init BEFORE any of those sources can start (all are deferred to blackscreen/round/trigger anyway).
    acc_music::init();

    // Decontamination must arm its acc_round_start listener before
    // watch_round_transitions below can fire the first one; it also rolls
    // the per-run seal permutation.
    acc_decontamination::init();

    // Per-round "DEFCON" room lockdown - stage 1 is the red alarm-light half
    // (rotates one lit room per round; OFF by default via acc_lockdown_on). Like
    // decon it must arm its acc_round_start listener before watch_round_transitions
    // fires the first one. Door-locking is stage 2 (needs Radiant seal brushes).
    acc_lockdown::init();

    // Per-round random perk access: 3 of the 9 Lab perk-alcove doors open each
    // round (dev: all open via acc_open_map). Arms an acc_round_start listener,
    // so init before watch_round_transitions fires (next to acc_lockdown).
    acc_perk_doors::init();

    // Order matters: data_shards owns the currency HUD, so it initializes before
    // cyberware / overclocks / emergency_drop which all read/write it.
    acc_data_shards::init();
    acc_cyberware::init();
    acc_overclocks::init();
    acc_elites::init();
    // Underground 54i reskin - MUST init after elites (both chain level.zombie_init_done;
    // this order makes the skin roll run after the depth-Shielded promo, docs in the module).
    acc_trench_skins::init();
    acc_fury::init();           // Apothicon Fury trench elite (5x hp; PER-PLAYER 30s cadence at trench layer 2+; HB21 pack)
    acc_events_hack::init();
    acc_events_overload::init();
    acc_emergency_drop::init();
    acc_glitch_altar::init();   // Data Shard gamble in the trench rooms (needs data_shards + bus_trench above)
    acc_ee_song::init();        // hidden Easter Egg SONG teddy bear in the NORTH trench room (the non-Overclock one)
    acc_reactor::init();        // Reactor Surge climax event in the pit (needs data_shards + bus_trench; docs/45)
    acc_exo::init();            // Exo Suit station: per-player depth-gate (cancels the per-layer trench slow; docs/47)
    acc_abyss_doors::init();    // Abyss descent = SOUL BOXES (100 kills/layer) + the communal Paradise gate (shards+points)
    acc_boss::init();
    // NSZ Brutus boss pack (stage 1: native spawn, for the asset-import go/no-go).
    acc_boss_brutus::init();
    // Glitch Stalker mini-boss (script-only mobile blink boss; r12+, every 10).
    acc_boss_glitch::init();
    // Phantom mini-boss (script-only holographic cloaker; the ~round-10 rotation-boss slot).
    acc_boss_phantom::init();
    // Paradise FINAL ONSLAUGHT: a timed 5-min survival fight (x4 spawns + Brutus/Phantom every minute +
    // shield/glitch gauntlet) that ENDS THE GAME on a win. After the boss modules it drives (brutus/glitch/
    // phantom) + abyss_doors (which arms it on Paradise open). docs/48.
    acc_paradise::init();
    acc_boss_items::init();
    // Lockdown CHALLENGE room (Phase A): the lit DEFCON room becomes a TRAP -> 30 confined
    // glitch zombies -> free-for-all reward. After lockdown/glitch/items so its reuse targets
    // exist. Isolated from the round via ignore_enemy_count. docs/43.
    acc_lockdown_challenge::init();
    // Weapon-variant swap engine (no-recoil / fast-fire perk twins, Stabilizer).
    // Before mega_bottles so level.acc_variant_* exist before any reconcile poke.
    // Inert until twins baked + `acc_weapon_variants 1` (docs/30-31).
    acc_weapon_variants::init();
    acc_mega_bottles::init();
    // "The Exchange" shared team vault (player-to-player transfers of points/shards/bottles/items).
    // After data_shards + mega_bottles + boss_items so their accessors are live; stations spawn in the
    // under-Plaza room (tools/gen_plaza_basement.js), gated by the enter_exchange door. docs/58.
    acc_transfer::init();
    // Base-perk retuning (Jug 3/6, QR regen, Savior). After mega_bottles so its
    // has_mega_perk / move-speed hooks are live.
    acc_perks::init();
    acc_weapon_abilities::init();
    // Points must init before damage so record_damage is available on the first hit.
    acc_points::init();
    // Zombie-corpse cleanup: bodies linger ~5s then hide + de-collide (registers its
    // own per-death callback after points so the body is read by earlier death hooks
    // before we hide it). Dvar acc_corpse_linger_sec; 0 = old instant removal.
    acc_corpse_cleanup::init();
    // Damage hooks go last so they sit on top of any hook other modules register.
    acc_damage::init();

    // Zombie speed curve: registers the on_ai_spawned per-round speed hook +
    // the keep-alive. Replaces the old Rampage Inducer with a natural-gait ramp -
    // a jog that speeds up rounds 1-9, breaking into a full sprint at round 10,
    // then +1%/round. Never animates below natural cadence (no slow-mo).
    // docs/11_enemies.md.
    acc_zombie_speed::init();

    // Perk benefit descriptions (base + Mega) shown at the machine.
    acc_perk_info::init();

    // Player + boss health bars.
    acc_health_bars::init();

    // 5-tier Pack-a-Punch (tier damage ladder + HUD + benefit text).
    acc_pap_levels::init();

    // Dev/test harness LAST so it can override caps (perk limit) set earlier. Self-gates on the `acc_dev`
    // dvar - the DEV tools no-op in normal play, but two FEATURES set up above that gate ship to everyone:
    // the floating damage numbers and the top-center ROOM-NAME banner (user 2026-06-27).
    acc_dev::init();

    // FILE-ONLY diagnostics heartbeat (user 2026-07-04, state-pool crash forensics): a 30s
    // [ACCDIAG] census line (entities/AI/corpses/furies/octobombs/boss debts) via LogPrint -
    // no on-screen output. Always on; acc_diag_interval 0 disables live.
    acc_diag::init();

    level thread watch_round_transitions();

    // Read by the entry-script status banner to confirm the full _acc_ init chain
    // completed (no module init threw and skipped the rest).
    level.acc_init_complete = true;
    acc_utility::log( "init complete" );
}

// ---------------------------------------------------------------------------
// Spawn-intensity tune (Moderate, 2026-06-18) - see the #defines up top.
// ---------------------------------------------------------------------------

function configure_spawn_density()
{
    // Concurrent caps: more zombies alive at once (the biggest "denser horde"
    // lever). Live values - the spawn loop re-reads them every iteration.
    level.zombie_ai_limit = ACC_AI_LIMIT;
    level.zombie_actor_limit = ACC_ACTOR_LIMIT;

    // Inter-spawn delay: chain the stock spawn-delay hook so waves fill faster.
    // Stock invokes [[ level.func_get_zombie_spawn_delay ]]( round ) once per
    // round (_zm.gsc:4502) to refresh zombie_vars["zombie_spawn_delay"]; we wrap
    // it and scale the result. Chain politely (own prev-slot, never clobber).
    if ( isdefined( level.func_get_zombie_spawn_delay ) )
        level.acc_prev_func_get_zombie_spawn_delay = level.func_get_zombie_spawn_delay;
    level.func_get_zombie_spawn_delay = &acc_spawn_delay_override;

    acc_utility::log( "spawn density: ai_limit " + ACC_AI_LIMIT + " / actor_limit " +
                      ACC_ACTOR_LIMIT + " / spawn-delay x" + ACC_SPAWN_DELAY_MULT );
}

// Level-scope: stock calls this with the round number (_zm.gsc:4502) and stores
// the returned seconds into zombie_vars["zombie_spawn_delay"].
function acc_spawn_delay_override( n_round )
{
    if ( isdefined( level.acc_prev_func_get_zombie_spawn_delay ) )
        base = [[ level.acc_prev_func_get_zombie_spawn_delay ]]( n_round );
    else
        base = 2.0; // stock 1p base, should never hit (hook set at _zm.gsc:307)

    out = base * ACC_SPAWN_DELAY_MULT;
    if ( out < 0.1 )
        out = 0.1; // stock's own floor (_zm.gsc:4631)
    return out;
}

// NOTE: there is intentionally no client_init() here. In BO3 the client VM
// (.csc) cannot call into server scripts (.gsc) - client-side _acc_ modules
// will be separate .csc files when the LUI/HUD work lands in Phase 4.

// Per-player setup, fires when a player joins (lobby or mid-game).
function on_player_connect()
{
    self endon( "disconnect" );
    acc_utility::log_player( self, "connected" );

    acc_data_shards::on_player_connect( self );
    acc_cyberware::on_player_connect( self );
    acc_overclocks::on_player_connect( self );
    acc_modifiers::on_player_connect( self );
    acc_boss_items::on_player_connect( self );
    acc_weapon_variants::on_player_connect( self );
    acc_mega_bottles::on_player_connect( self );
    acc_perks::on_player_connect( self );
    acc_weapon_abilities::on_player_connect( self );
    acc_exo::on_player_connect( self );
    acc_points::on_player_connect( self );   // arm the bleed-out watcher for the comeback bonus
}

// Fires on every respawn (round start, revive, map load).
function on_player_spawned()
{
    self endon( "disconnect" );

    // Guard so one-time setup doesn't run multiple times.
    if ( !isdefined( self.acc_first_spawn_done ) )
    {
        self.acc_first_spawn_done = true;
        acc_utility::log_player( self, "first spawn" );
    }

    acc_data_shards::on_player_spawned( self );
    acc_cyberware::on_player_spawned( self );
    acc_perks::on_player_spawned( self );
    acc_exo::on_player_spawned( self );   // re-apply move speed (exo slow) after spawn
    acc_points::on_player_spawned( self );   // comeback bonus: set money to 500 * round on a full-death respawn
}

function on_player_disconnect()
{
    acc_utility::log_player( self, "disconnected" );
    acc_data_shards::on_player_disconnect( self );
}

// Dispatches `acc_round_start` / `acc_round_end` events that subsystems listen
// for. Using a single fan-out instead of every system hooking stock events
// independently keeps ordering controllable.
function watch_round_transitions()
{
    level endon( "end_game" );

    // VERIFIED(acc): "initial_blackscreen_passed" is a FLAG (_zm.gsc:1612 init,
    // _zm.gsc:530 set) - flag::wait_till returns immediately if already set,
    // a bare waittill would hang. Stock: zm_giant.gsc:726, _zm_magicbox.gsc:2182.
    level flag::wait_till( "initial_blackscreen_passed" );
    level notify( "acc_game_start" );

    previous_round = -1;

    for ( ;; )
    {
        // TODO(acc-verify): stock waits on "between_round_over" or similar.
        // Find the canonical name in share/raw/scripts/zm/_zm.gsc round loop.
        level waittill( "start_of_round" );

        if ( previous_round >= 0 )
        {
            level notify( "acc_round_end", previous_round );
        }

        level notify( "acc_round_start", level.round_number );
        previous_round = level.round_number;
    }
}
