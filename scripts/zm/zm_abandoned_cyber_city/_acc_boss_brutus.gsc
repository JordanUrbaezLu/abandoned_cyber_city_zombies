// =============================================================================
// _acc_boss_brutus.gsc - thin wrapper around the vendored NSZ Brutus pack
//
// Brutus (NateSmithZombies' BO2 port, scripts\_NSZ\nsz_brutus.gsc) is a custom
// AITYPE (stock-zombie behaviour + BO2 model + custom anims via the zm_brutus
// animtable), NOT a hard behaviour-tree archetype. Full audit + design decisions:
// docs/research/NateSmithZombies_Brutus_BO2_boss_pack.txt.
//
// We drive Brutus as OUR mini-boss: he replaces the old Juggernaut Host at r10/r20,
// charging ALONGSIDE the normal wave (his native ignore_enemy_count - he does not
// gate round end), with the perk/box LOCK mechanic dropped (lock_machines=false in
// the vendored copy). _acc_boss promotes each spawned actor with our health bar +
// over-boss marker + 5x HP + +25% speed + Mega-Bottle/boss-item rewards.
//
// init() disables the pack's own min/max-round spawn cadence (it only sets up the
// spawn-point structs); spawn_one() then spawns a single Brutus on demand and returns
// the live actor (the vendored hook stamps it onto level.acc_brutus_last + notifies).
// =============================================================================

#using scripts\_NSZ\nsz_brutus;
#using scripts\shared\util_shared;

#using scripts\zm\_zm_utility;

#using scripts\zm\zm_abandoned_cyber_city\_acc_utility;
#using scripts\zm\zm_abandoned_cyber_city\_acc_bus_trench;

#namespace acc_boss_brutus;

function init()
{
    acc_utility::log( "boss_brutus: init (drive NSZ Brutus from our r10/r20 hooks)" );

    // Tell the vendored pack NOT to run its own spawn cadence; _acc_boss calls
    // spawn_one() at the boss rounds. brutus::init() still seeds config (lock OFF in
    // our vendored copy) and activates the brutus_spawner_spot structs.
    level.acc_brutus_external_spawns = true;
    brutus::init();
}

// Spawn ONE Brutus via the pack and return the live actor (or undefined on timeout).
// The vendored spawn_brutus stamps the actor onto level.acc_brutus_last and fires
// "acc_brutus_spawned" once it is set up. Call SEQUENTIALLY (this blocks until the
// actor exists) so concurrent spawns can't race on the shared notify / level var.
function spawn_one()
{
    level endon( "end_game" );

    // [acc] TRENCH WARDEN (user 2026-06-18): spawn Brutus IN THE TRENCH, not the lab. The pack's
    // choose_a_spawn() = ArrayGetClosest(player.origin, level.brutus_spawn_points) and then
    // ForceTeleports + plays the %brutus_spawn rise anim + FX AT that spot. So point those spawn
    // points onto the trench floor -> the WHOLE spawn happens in the pit (no lab appearance at all).
    // Done here, just before the pack reads them. Gated by acc_warden_trench (0 = pack-native lab spawn).
    if ( getdvarint( "acc_warden_trench", 1 ) )
        relocate_spawn_points_to_trench();

    level.acc_brutus_last = undefined;
    level thread brutus::spawn_brutus();
    // 15s is comfortably past the pack's short pre-spawn telegraph; a real failure
    // (no spawn spot / dog round) just times out and returns undefined.
    level util::waittill_any_timeout( 15, "acc_brutus_spawned" );

    return level.acc_brutus_last;
}

// Point the pack's spawn locations (level.brutus_spawn_points, read by choose_a_spawn ->
// ArrayGetClosest) onto the TRENCH FLOOR so Brutus spawns IN THE PIT and the lab spawn is gone
// entirely (user 2026-06-18: "remove the lab spawn, it's not a thing anymore"). The pack
// ForceTeleports + plays the %brutus_spawn rise anim + FX at that spot, so the WHOLE spawn now
// happens in the trench - no lab appearance. RAW pit-riser origins (z=-240); the pack's own
// GetClosestPointOnNavMesh clamp (nsz_brutus.gsc:247) lands him on the pit navmesh, and the warden
// retry-drop-in (trench_warden_think) is the backstop if that clamp ever snaps to the rim.
function relocate_spawn_points_to_trench()
{
    if ( !isdefined( level.brutus_spawn_points ) || level.brutus_spawn_points.size < 1 ) return;
    risers = acc_bus_trench::get_trench_risers();
    if ( !isdefined( risers ) || risers.size < 1 ) return;
    for ( i = 0; i < level.brutus_spawn_points.size; i++ )
        level.brutus_spawn_points[ i ].origin = risers[ i % risers.size ].origin;
    acc_utility::log( "boss_brutus: relocated " + level.brutus_spawn_points.size +
                      " brutus spawn point(s) onto the trench floor (no lab spawn)" );
}

// =============================================================================
// Trench Warden behaviour (user 2026-06-18). Make Brutus (= the "Trench Warden") ROAM
// the Bus Station (corp_zone) trench floor, SPAWN at the bottom of the trench, and ONLY
// target a player who is on the trench floor WITH him; otherwise patrol the pit (never
// freeze, never chase out). Implemented WITHOUT editing the vendored pack: we police the
// pack's OWN target lock (self.brutus_enemy) and write the pack's OWN goal var
// (self.v_zombie_custom_goal_pos, the legacy-find-flesh goal consumed under the usermap's
// scr_zm_use_code_enemy_selection=0). Threaded from _acc_boss::spawn_brutus_miniboss.
//
// SAFETY (Brutus's long crash/freeze history - memory brutus-miniboss-integration):
//   - NO SetScale (the confirmed 0xC0000005 live-AI crasher).
//   - NO PathMode change and NO speed setter on him - the _acc_zombie_speed keep-alive must
//     keep skipping this actor via the is_boss/acc_boss_custom_speed guard, or his custom ASM
//     gets stomped and he freezes (valid path, moved=0). We never touch his speed/anim-rate.
//   - EVERY teleport/goal is GetClosestPointOnNavMesh-clamped first (off-mesh = HasPath()
//     false = frozen), matching the pack's own clamp (nsz_brutus.gsc:247-251).
//   - v_zombie_custom_goal_pos is NEVER left undefined / off-mesh, so he never stalls.
// Master gate acc_warden_trench (1). Set 0 = instant rollback to the pack-native charge
// (re-read each tick, so it drops the tether on an already-spawned Brutus mid-fight too).
// =============================================================================

function trench_warden_think()   // self = the live Brutus
{
    self endon( "death" );
    level endon( "end_game" );

    if ( getdvarint( "acc_warden_trench", 1 ) != 1 ) return; // off -> pack-native charge

    if ( !isalive( self ) ) return;

    risers = acc_bus_trench::get_trench_risers();
    acc_utility::log( "boss_brutus: warden trench risers = " + ( isdefined( risers ) ? risers.size : 0 ) +
                      " (0 => structs not in the .ff; needs a FULL build, not -GscOnly)" );

    // SPAWN AT THE BOTTOM (user). The pack fires "acc_brutus_spawned" (so spawn_one returns) at
    // nsz_brutus.gsc:242 - BEFORE it ForceTeleports him to the LAB spot + plays the AnimScripted
    // %brutus_spawn anim (:251-255). That anim LOCKS his position for its FULL length, so a single
    // early teleport is overridden and he ends up back at the lab (the "still spawns at the lab"
    // bug, 2026-06-18). FIX: RETRY the drop-in until it STICKS - player_in_trench(self) confirms he
    // is actually in the pit (true only once the spawn anim has ended and a teleport holds).
    // Teleport to the RAW riser origin (z=-240): the trench SURGE proves entities spawn AND path
    // there, and GetClosestPointOnNavMesh on a z=-240 point can snap UP to the z=0 lip (which would
    // leave him out of the pit), so we deliberately do NOT clamp here.
    if ( isdefined( risers ) && risers.size > 0 )
    {
        tries = 0;
        while ( tries < 50 && !acc_bus_trench::player_in_trench( self ) )
        {
            if ( !isalive( self ) ) return;
            r0 = risers[ acc_utility::acc_rand_int( risers.size ) ];
            self ForceTeleport( r0.origin, self.angles, 1 );
            self.v_zombie_custom_goal_pos = r0.origin; // seed an immediate valid in-pit goal
            wait( 0.2 );
            tries++;
        }
        acc_utility::log( "boss_brutus: warden drop-in " +
            ( acc_bus_trench::player_in_trench( self ) ? "OK (in pit)" : "FAILED (still out)" ) +
            " after " + tries + " tries" );
    }

    // Now that he's the pit boss, gate his damage: only a player physically in the
    // trench can hurt him (enforced in _acc_damage::on_ai_damage). No snipe-from-the-rim.
    self.acc_warden_active = true;

    // DON'T let the stock spawn failsafe cull him (user 2026-06-18: "he randomly dies after some
    // time"). The pack threads zombie_utility::round_spawn_failsafe on Brutus (nsz_brutus.gsc:200);
    // after 30s it RECYCLES a zombie that hasn't moved >24u (he's a tethered pit boss, often
    // holding position with no trench player) -> DoDamage(health+100)/respawn = the "random death".
    // ignore_round_spawn_failsafe makes it return early. SAME precedent as the stationary
    // Subroutine Core (_acc_boss.gsc:461). Safe here: he roams the pit (not permanently pinned),
    // and below_world_check is -1000 so z=-240 is NOT "fell out of world".
    self.ignore_round_spawn_failsafe = true;

    self.acc_warden_patrol_goal  = undefined;
    self.acc_warden_patrol_ticks = 0;
    self.acc_warden_dbg_tick     = 0;

    // TAKE OVER GOAL CONTROL. The pack's own chase loop custom_find_flesh re-acquires the
    // GLOBAL-closest player every 0.05s and writes their origin as the goal (nsz_brutus.gsc:360-368)
    // - so when nobody is in the pit it drives him at the walls / up the stairs toward a player up
    // top, fighting our patrol. It self endon( "locking_target" ) (:348), so we notify that to KILL
    // it and become the SOLE writer of v_zombie_custom_goal_pos -> clean chase-in-pit / patrol, no
    // contention. (Re-asserted each tick below in case the pack started it a frame after us.)
    self notify( "locking_target" );

    for ( ;; )
    {
        if ( !isalive( self ) ) return;

        // Live rollback (acc_warden_trench 0): restore the pack's native chase loop and bail.
        if ( getdvarint( "acc_warden_trench", 1 ) != 1 )
        {
            self.brutus_enemy = undefined;
            self thread brutus::custom_find_flesh();
            return;
        }

        // Bulletproof the kill (no-op once it's dead): the pack threads custom_find_flesh AFTER its
        // spawn anim, which may land a frame after our first notify above.
        self notify( "locking_target" );

        // Players ON THE TRENCH FLOOR right now.
        cand = [];
        players = GetPlayers();
        for ( i = 0; i < players.size; i++ )
        {
            p = players[ i ];
            if ( isdefined( p ) && isplayer( p ) && zm_utility::is_player_valid( p )
                 && acc_bus_trench::player_in_trench( p ) )
                cand[ cand.size ] = p;
        }

        if ( cand.size > 0 )
        {
            // CHASE the closest in-trench player - WE write the goal now. brutus_enemy is still set
            // for the pack's melee_track (nsz_brutus.gsc:626); countdown kept >0 as a courtesy.
            closest = arraygetclosest( self.origin, cand );
            if ( isdefined( closest ) )
            {
                self.brutus_enemy = closest;
                closest.brutus_track_countdown = 2;
                self.v_zombie_custom_goal_pos = closest.origin;
                self.acc_warden_patrol_goal = undefined; // fresh patrol target when they leave
            }
        }
        else
        {
            // Nobody in the pit -> PATROL between the trench risers (no melee target). With
            // custom_find_flesh dead, this goal is uncontested -> he walks the pit, no wall/stairs.
            self.brutus_enemy = undefined;
            warden_patrol_step( risers );
        }

        warden_debug();

        wait 0.05;
    }
}

// Advance / hold the patrol goal among the trench-floor risers, writing the pack's own goal
// var. Picks a new riser when reached, when held too long, or on first use.
function warden_patrol_step( risers )   // self = Brutus
{
    if ( !isdefined( risers ) || risers.size == 0 ) return;

    reach     = getdvarint( "acc_warden_patrol_reach", 96 );
    dwell     = getdvarfloat( "acc_warden_patrol_dwell", 2.5 );
    max_ticks = int( dwell / 0.05 );
    if ( max_ticks < 1 ) max_ticks = 1;

    self.acc_warden_patrol_ticks++;

    pick_new = !isdefined( self.acc_warden_patrol_goal );
    if ( !pick_new && Distance( self.origin, self.acc_warden_patrol_goal ) < reach )
        pick_new = true;
    if ( !pick_new && self.acc_warden_patrol_ticks > max_ticks )
        pick_new = true;

    if ( pick_new )
    {
        // RAW riser origin (z=-240) - a valid in-pit point the surge already paths to. NOT
        // GetClosestPointOnNavMesh-clamped: on a z=-240 point that can snap UP to the z=0 lip,
        // which would make him patrol OUT of the pit. (The pack writes raw player origins as the
        // chase goal too, so a raw in-pit point is a valid goal.)
        r = risers[ acc_utility::acc_rand_int( risers.size ) ];
        self.acc_warden_patrol_goal  = r.origin;
        self.acc_warden_patrol_ticks = 0;
    }

    self.v_zombie_custom_goal_pos = self.acc_warden_patrol_goal;
}

// On-screen trace (acc_warden_debug 1), throttled to ~0.5s. Watch: hasPath=Y + moving = no
// freeze; tgt flips Y only when a player is in the pit; inTrench=Y = he stayed down.
function warden_debug()   // self = Brutus
{
    self.acc_warden_dbg_tick++;
    if ( getdvarint( "acc_warden_debug", 0 ) != 1 ) return;
    if ( ( self.acc_warden_dbg_tick % 10 ) != 0 ) return;

    tgt  = ( isdefined( self.brutus_enemy ) ? "Y" : "N" );
    intr = ( acc_bus_trench::player_in_trench( self ) ? "Y" : "N" );
    hp   = ( self HasPath() ? "Y" : "N" );
    for ( i = 0; i < level.players.size; i++ )
    {
        p = level.players[ i ];
        if ( isdefined( p ) && isplayer( p ) )
            p IPrintLnBold( "^1[warden] ^7tgt=" + tgt + " inTrench=" + intr + " hasPath=" + hp );
    }
}
