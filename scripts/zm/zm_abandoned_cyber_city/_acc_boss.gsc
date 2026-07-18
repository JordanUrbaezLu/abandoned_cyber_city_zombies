// =============================================================================
// _acc_boss.gsc - boss round orchestration
//
// Design reference: docs/08_enemies.md (Mini-Boss / Full Boss),
// docs/05_mechanics.md (boss rooms are the only forced-camp encounters).
//
// Round 10, 20: mini-boss REPLACES the normal wave (docs/08: "Spawn: replaces
// the normal round wave") - the wave budget is zeroed at round start
// (suppress_normal_wave), zombies already out remain, and the round ends when
// everything counted (Juggernaut Host included) is dead. r10 = 1 host,
// r20 = 2 simultaneous hosts.
// Round 30, 40, 50+: full boss "Subroutine Core" in the Lab - a REAL
// damageable actor spawned at the acc_boss_spawn struct and pinned in place
// (stationary by design, docs/08). Per docs/08 the full-boss fight runs
// ALONGSIDE normal waves ("constant chaff spawn during the fight"), so the
// Core neither gates round end nor consumes the wave's AI budget.
// =============================================================================

#using scripts\codescripts\struct;

#using scripts\shared\flag_shared;
#using scripts\shared\util_shared;

#using scripts\shared\ai\zombie_utility;

#using scripts\zm\_zm_perks;
#using scripts\zm\_zm_score;                                  // add_to_player_score (3k trench-Brutus kill points)

#using scripts\zm\zm_abandoned_cyber_city\_acc_utility;
#using scripts\zm\zm_abandoned_cyber_city\_acc_data_shards;
#using scripts\zm\zm_abandoned_cyber_city\_acc_boss_items;
#using scripts\zm\zm_abandoned_cyber_city\_acc_mega_bottles;
#using scripts\zm\zm_abandoned_cyber_city\_acc_cyberjack;   // Brutus CYBERJACK gun-drop (docs/43, 2026-07-17)
#using scripts\zm\zm_abandoned_cyber_city\_acc_coop_scaling;
#using scripts\zm\zm_abandoned_cyber_city\_acc_boss_brutus;
#using scripts\zm\zm_abandoned_cyber_city\_acc_lui;
#using scripts\zm\zm_abandoned_cyber_city\_acc_boss_phantom;
#using scripts\zm\zm_abandoned_cyber_city\_acc_music;   // single music channel (boss music routes through it)
#using scripts\zm\zm_abandoned_cyber_city\_acc_boss_nameplate;   // 3D over-head name + health bar (user 2026-07-02)

#insert scripts\shared\shared.gsh;

#define ACC_BOSS_MINI_FIRST_ROUND 10
#define ACC_BOSS_FULL_FIRST_ROUND 30
#define ACC_BOSS_INTERVAL 10

// Brutus mini-boss HP + cadence (user request). (The +50% size / +25% speed buffs were removed
// 2026-06-15: size via SetScale is a confirmed live-AI CTD, and the speed think was unneeded then
// as he charges natively - see CHANGELOG. A SMALL +3% speed was re-added 2026-07-12 via a SAFE bare
// ASMSetAnimationRate - acc_boss_brutus::warden_speed_think, dvar acc_warden_anim_rate; SetScale stays banned.)
// UNIFIED BOSS SCALE (user 2026-07-04; base 56000 -> 65000 user 2026-07-05): Brutus now rides the SAME base (65000) + anchor (5) as the
// Phantom/Rogue Protector/Avogadro, differing ONLY by exponent - the TOP tier: Brutus 1.12 > Rogue 1.09 >
// Phantom 1.06 (Avogadro shares the Phantom's 1.06). NO cap (the pack's linear 3500*round / 85k-cap code is dead - overwritten here every
// spawn). Brutus debuts at power-on & round >= acc_warden_first_round (5); his round-5 debut is exactly the flat
// 65k base (past clamps to 0), then compounds at 1.12 from round 5 onward.
#define ACC_BOSS_MINI_HP 65000       // Brutus BASE solo HP (shared with Phantom/Rogue/Avo; user 2026-07-05: 56000 -> 65000). Scaled by scale_mini_boss_hp THEN x boss_hp_player_mult (LOGARITHMIC coop). Live dvar acc_boss_mini_hp.
#define ACC_BOSS_MINI_HP_EXP 1.12    // Brutus COMPOUNDS per round at 1.12 (user 2026-07-08: 1.12 -> 1.13 -> 1.14 -> 1.12 after the anchor moved to r5, the TANKIEST tier tied with the Panzer): base x 1.12^(round-anchor5) -> solo r5 65k / r10 115k / r20 356k / r30 1.11M / r40 3.43M. Live dvar acc_boss_mini_hp_exp.
#define ACC_BOSS_MINI_HP_ANCHOR 5    // round his BASE HP applies + compounding STARTS (user 2026-07-08: 10 -> 5, so scaling begins at his round-5 power-on debut, not round 10; matches the roster's acc_phantom_hp_anchor 5). Live dvar acc_boss_mini_hp_anchor.
#define ACC_BRUTUS_FIRST_ROUND 4     // LEGACY (superseded by the power-on first spawn, 2026-06-18)
#define ACC_BRUTUS_INTERVAL 5        // LEGACY (superseded by ACC_BRUTUS_RESPAWN_INTERVAL)
#define ACC_BRUTUS_RESPAWN_INTERVAL 3 // Trench Warden: rounds AFTER a kill before he respawns (user 2026-06-18)

#namespace acc_boss;

function init()
{
    acc_utility::log( "boss init" );

    level thread round_hook_loop();

    // Trench Warden (Brutus) schedule (user 2026-06-18): FIRST spawn is power-on
    // (brutus_power_watch); after he is KILLED he respawns ACC_BRUTUS_RESPAWN_INTERVAL rounds
    // later (round_hook_loop). ONE at a time - acc_brutus_active guards a second spawn while
    // he's alive; acc_brutus_kill_round (set in watch_mini_boss_death) drives the respawn.
    level.acc_brutus_active = false;
    level.acc_brutus_kill_round = undefined;
    level thread brutus_power_watch();

    // (test_boss_loop removed 2026-07-16: it was an acc_test_boss-gated dev lever that spawned an
    // early low-HP Brutus for the Mega-Bottle/perk loop. Dev now runs the REAL round-5 Brutus
    // cadence like normal play (user 2026-06-22) - no per-feature test dvar; only acc_dev/god/mock.)
}

function round_hook_loop()
{
    level endon( "end_game" );

    for ( ;; )
    {
        level waittill( "acc_round_start", round_number );

        // Subroutine Core full boss REMOVED (user 2026-06-22): no r30/40/50 full-boss spawn anymore.
        // (run_full_boss + spawn_subroutine_core remain defined but are now UNREACHABLE dead code - left
        // in place so the module still compiles and the boss is trivially restorable; nothing calls them.)

        // Brutus mini-boss = the TRENCH WARDEN (user 2026-06-18). FIRST spawn = power-on
        // (brutus_power_watch). RESPAWN = kill-anchored: once he's KILLED (acc_brutus_kill_round
        // set in watch_mini_boss_death), he comes back ACC_BRUTUS_RESPAWN_INTERVAL rounds later -
        // NOT a fixed grid. ONE at a time: acc_brutus_active blocks a second while he's alive (so
        // not killing him never stacks two). No power / never-killed-yet => no respawn here.
        if ( !IS_TRUE( level.acc_brutus_active )
             && isdefined( level.acc_brutus_kill_round )
             && round_number >= level.acc_brutus_kill_round
                                + getdvarint( "acc_brutus_respawn_interval", ACC_BRUTUS_RESPAWN_INTERVAL ) )
        {
            level thread run_mini_boss( round_number );
        }
    }
}

// FIRST Trench Warden (Brutus) appears the moment the Bus Station power is turned on. Same
// power gate the perk-glow / fog use: wait the blackscreen, poll the global "power_on" flag
// (set by the dual Bus Station switches), then spawn ONE. Every respawn AFTER is kill-anchored
// in round_hook_loop (acc_brutus_kill_round + ACC_BRUTUS_RESPAWN_INTERVAL).
function brutus_power_watch()
{
    level endon( "end_game" );

    level flag::wait_till( "initial_blackscreen_passed" );

    // First Trench Warden requires BOTH: the Bus Station power is on AND round >= acc_warden_first_round
    // (default 5, user 2026-06-18 - too early otherwise). If power comes on before round 5, hold here
    // until round 5; if it's already past, spawn as soon as power flips. Respawns are kill-anchored
    // (kill_round + interval), naturally >= this, so only the first spawn needs the floor.
    while ( !( level flag::exists( "power_on" ) && level flag::get( "power_on" ) )
            || level.round_number < getdvarint( "acc_warden_first_round", 5 ) )
        wait( 0.5 );

    if ( IS_TRUE( level.acc_brutus_active ) ) return;        // one already alive
    if ( isdefined( level.acc_brutus_kill_round ) ) return;  // already started; kills drive the rest
    acc_utility::log( "boss: power ON + round >= first -> first Trench Warden (Brutus)" );
    level thread run_mini_boss( level.round_number );
}

// ---------------------------------------------------------------------------
// Mini-boss
// ---------------------------------------------------------------------------

function run_mini_boss( round_number )
{
    level endon( "end_game" );
    // NO acc_round_end endon (user 2026-06-27 audit): a fast co-op round ending DURING the ~3.5s spawn telegraph
    // would tear this thread down while it's blocked inside spawn_brutus_miniboss's waittill_any_timeout - BEFORE
    // the host==undefined cleanup below or watch_mini_boss_death (which clears acc_brutus_active on his death) ever
    // ran - leaving acc_brutus_active stuck TRUE so the Trench Warden NEVER respawns for the rest of the match.
    // Brutus roams across rounds anyway (ignore_enemy_count), so this spawn must NOT be round-scoped.

    // The Trench Warden is a SINGLE roaming boss (user 2026-06-18): exactly ONE at a time. He
    // charges/roams ALONGSIDE the normal wave (native ignore_enemy_count - does NOT gate round
    // end). Mark active so the kill-anchored respawn in round_hook_loop can't spawn a second
    // while he lives; watch_mini_boss_death clears it + records the kill round on his death.
    level.acc_brutus_active = true;
    acc_utility::log( "Trench Warden (Brutus) spawning, round " + round_number );

    host = spawn_brutus_miniboss();
    if ( !isdefined( host ) )
    {
        level.acc_brutus_active = false; // spawn failed -> don't soft-lock the respawn schedule
        // REVIEW FIX 2026-07-08: re-arm the schedule. round_hook_loop's respawn condition needs
        // acc_brutus_kill_round, which only a KILL sets - so a failed FIRST spawn (actor pool at cap
        // the frame the power-on Warden fired; brutus_power_watch is one-shot and the pack's own
        // cadence is disabled) used to mean NO Trench Warden for the rest of the match, silently.
        // Backdate a synthetic kill round so the loop retries from the NEXT round. (After a real kill
        // the field is already set, so failed respawns retry every round on their own.)
        if ( !isdefined( level.acc_brutus_kill_round ) )
            level.acc_brutus_kill_round = level.round_number + 1
                - getdvarint( "acc_brutus_respawn_interval", ACC_BRUTUS_RESPAWN_INTERVAL );
    }
}

// Zero the remaining wave budget so the boss round is boss-only.
// Call ONLY from a thread woken by "acc_round_start" (timing matters, below).
function suppress_normal_wave( round_number )
{
    // VERIFIED(acc): stock round_spawning sets level.zombie_total exactly once
    // at thread start (_zm.gsc:3714-3719) and is threaded BEFORE the
    // "start_of_round" notify (thread at _zm.gsc:4431, notify at :4433 - a GSC
    // thread runs to its first wait before the caller resumes). _acc_main
    // relays "acc_round_start" off "start_of_round" in the same frame, so by
    // the time we run here the total is already set and zeroing it cannot be
    // clobbered. The spawn loop then gates on it EVERY iteration:
    // `while( ... || level.zombie_total <= 0 ) wait(0.1)` (_zm.gsc:3735-3738),
    // so no new chaff spawns; zombies already out remain (typically the one
    // spawned synchronously at _zm.gsc:3808 before the notify) and the round
    // ends when everything counted is dead - round_wait polls
    // `get_current_zombie_count() > 0 || level.zombie_total > 0`
    // (_zm.gsc:4733).
    //
    // VERIFIED(acc): no insta-end race - round_wait sleeps 1s before its first
    // poll (_zm.gsc:4724) and the host below is spawned with no intervening
    // wait between this write and spawn_zombie's SpawnFromSpawner.
    //
    // Known leak (accepted): the stuck-zombie failsafe can re-queue a
    // timed-out chaff zombie via level.zombie_total++ when
    // level.put_timed_out_zombies_back_in_queue is set
    // (zombie_utility.gsc:1879-1886) - at worst one already-counted zombie
    // respawns; it cannot regrow the wave.
    acc_utility::log( "boss: suppressing normal wave for round " + round_number
        + " (zombie_total was " + level.zombie_total + ")" );
    level.zombie_total = 0;
}

// Brutus HP COMPOUNDS each round (user 2026-06-27) like a zombie so a high-round Trench Warden keeps pace:
//   hp = base * exp^( rounds_past_anchor )      (exp 1.12 - the TOP TANK tier, tied with the Panzer, on the
//                                                unified 65k-base/anchor-5 scale shared with all bosses;
//                                                Brutus/Panzer 1.12 > Rogue 1.09 > Phantom/Avogadro 1.06)
// anchored at round 5 (user 2026-07-08: was 10) so scaling begins at his round-5 power-on debut - the FIRST
// Warden is exactly the base, and every round after compounds. Knobs are
// LIVE balance dvars: acc_boss_mini_hp / _exp / _anchor. The coop player multiplier (boss_hp_player_mult)
// is applied SEPARATELY at the spawn site, on top of this. (exp history: 1.08 -> 1.1 -> 1.12 -> 1.13 -> 1.14 -> 1.12 w/ anchor r5.)
function scale_mini_boss_hp( round_number )
{
    base   = getdvarint( "acc_boss_mini_hp", ACC_BOSS_MINI_HP );
    exp    = getdvarfloat( "acc_boss_mini_hp_exp", ACC_BOSS_MINI_HP_EXP );
    anchor = getdvarint( "acc_boss_mini_hp_anchor", ACC_BOSS_MINI_HP_ANCHOR );

    past = round_number - anchor;
    if ( past < 0 ) past = 0;   // before his debut round -> just the base (no negative scaling)

    // base * exp^past. GSC has no pow builtin (stock ai_calculate_health loops x1.1 the same way);
    // past = round - anchor is always a small non-negative int, so the loop is cheap.
    mult = 1.0;
    for ( i = 0; i < past; i++ )
        mult = mult * exp;
    return int( base * mult );
}

function spawn_brutus_miniboss( n_health_override, n_bottle_count )
{
    // Brutus (NSZ pack) IS our mini-boss. acc_boss_brutus::spawn_one() spawns one via the pack
    // (model / anims / charge / melee / helmet / death) and returns the live actor; we layer OUR
    // systems on top. The pack drives his locomotion natively (custom_find_flesh). NOTE: the long
    // "spawns then stands frozen" bug was NOT in this promotion layer - it was _acc_zombie_speed
    // stomping his run-cycle ASM; fixed at the source (it excludes is_boss actors, and the pack
    // now flags him is_boss on spawn). See docs/08_enemies.md "Brutus" + CHANGELOG 2026-06-15.
    host = acc_boss_brutus::spawn_one();
    if ( !isdefined( host ) || !isalive( host ) )
    {
        acc_utility::log( "boss: Brutus spawn returned none" );
        return;
    }

    // HP + boss health bar + rewards.
    host.acc_is_mini_boss = true; // boss headshot multiplier in _acc_damage
    if ( isdefined( n_bottle_count ) ) host.acc_bottle_drop = n_bottle_count;
    if ( isdefined( n_health_override ) ) host.maxhealth = n_health_override;
    // ROUND scaling (scale_mini_boss_hp - COMPOUNDS x1.12/round from the round-5 anchor, the TOP TANK tier)
    // THEN coop scaling by player count (the old LINEAR xN -> 200k at 4p was "crazy"; still far under it).
    // boss_hp_player_mult() = an explicit table, 1p 1.00 / 2p 1.70 / 3p 2.30 / 4p 2.60 (user 2026-07-15;
    // was 1 + 0.5*log2(n) = 1/1.5/1.79/2.0). So a round-10 solo Warden = 115k; a round-30 solo = 1.11M;
    // a round-30 4p = 1.11M x2.6 = 2.89M. Tune live: acc_boss_mini_hp_exp / acc_boss_mini_hp_anchor /
    // acc_boss_coop_hp_2p|_3p|_4p. (4p isn't a clean 4x DPS, so the table stays sub-linear to keep TTK sane.)
    else
    {
        rn = ( isdefined( level.round_number ) ? level.round_number : 1 );
        host.maxhealth = int( scale_mini_boss_hp( rn ) * acc_coop_scaling::boss_hp_player_mult() );
    }
    host.health = host.maxhealth;
    host DisableAimAssist();
    host.disableAmmoDrop = true;
    host thread watch_mini_boss_death();                // Mega-Bottle / boss-item drops

    // SPEED BUFF (user 2026-07-12): +3% ground speed via a bare ASMSetAnimationRate (acc_warden_anim_rate,
    // default 1.03). Safe because the pack flags him acc_boss_custom_speed so the global speed keep-alive
    // skips him (no writer fight) - the SANCTIONED lever, unlike the SetScale / run-cycle-override that
    // historically crashed/froze him. See acc_boss_brutus::warden_speed_think.
    host thread acc_boss_brutus::warden_speed_think();

    // Brutus is DOWN-LEVELED to a regular mini-boss (user 2026-06-18): he KEEPS the HP (above)
    // but gets NO boss health bar and NO boss music - those now belong to the Phantom (the real
    // ~round-10 boss). So we deliberately do NOT emit "acc_boss_spawned" and do NOT call boss_music
    // here. (He's still the Trench Warden - the roam thread below applies.)
    // 3D OVER-HEAD NAMEPLATE (user 2026-07-02): unlike the rejected 2D top-screen bar, the new
    // world-space name + health bar (SetDrawName, _acc_boss_nameplate) is per-enemy and
    // unobtrusive, so the mini-boss gets one too - direct attach (still no notify: that would
    // also imply boss music semantics elsewhere).
    acc_boss_nameplate::attach( host, "TRENCH WARDEN" );

    // Trench Warden (user 2026-06-18): roam the Bus Station trench, spawn at the trench
    // bottom, and only target a player on the trench floor with him. Supervisor thread (does
    // NOT edit the vendored pack); gated by acc_warden_trench (set 0 = pack-native charge).
    if ( getdvarint( "acc_warden_trench", 1 ) )
        host thread acc_boss_brutus::trench_warden_think();

    acc_utility::log( "spawned Brutus mini-boss (" + host.maxhealth + " hp, down-leveled: no bar/music)" );
    return host; // run_mini_boss checks this to clear the active guard if the spawn failed
}

// ---------------------------------------------------------------------------
// Boss music (GENERIC, public) - loop the Juhani Junkala "Epic Boss Battle" (CC0, seamless)
// track while any boss using it is alive, then slow-fade (4s) when the LAST one dies. A level
// refcount makes it multi-boss safe. Gated by acc_boss_music_on (default 1). Alias
// acc_brutus_music = the boss track (acc_audio.csv). PUBLIC so any boss thread can call
// `level thread acc_boss::boss_music( host )` - the PHANTOM uses it (it's the real boss);
// Brutus no longer does (down-leveled to a music-less mini-boss, 2026-06-18).
// ---------------------------------------------------------------------------
function boss_music( host )
{
    level endon( "end_game" );

    if ( getdvarint( "acc_boss_music_on", 1 ) != 1 )
        return;

    // PARADISE FINALE (user 2026-06-25): the boss music is SUPPRESSED for the whole Paradise onslaught - the
    // "115" anthem (_acc_paradise::start_finale_music, alias acc_paradise_music) owns the audio there, and a
    // Phantom spawning every minute would otherwise restart this loop. level.acc_paradise_onslaught is the gate.
    if ( IS_TRUE( level.acc_paradise_onslaught ) )
        return;

    if ( !isdefined( level.acc_boss_music_count ) )
        level.acc_boss_music_count = 0;

    level.acc_boss_music_count++;

    // Start the boss loop on the SHARED music channel (user 2026-06-25). This OVERRIDES any song that was
    // playing (e.g. the main theme). Only (re)start if boss music isn't already the channel, so a 2nd
    // simultaneous boss doesn't restart the loop. A teddy-bear song triggered mid-fight overrides THIS in turn
    // (acc_music::play) and we never fight it back - the keep-alive loop below only waits.
    if ( !acc_music::is_playing( "acc_brutus_music" ) )
        acc_music::play( "acc_brutus_music", true );

    // Hold this boss's refcount while it lives (poll covers death AND despawn/delete). Also releases the moment
    // the Paradise onslaught begins, so the "115" anthem can take over the channel.
    while ( isdefined( host ) && isalive( host ) && !IS_TRUE( level.acc_paradise_onslaught ) )
        wait( 0.5 );

    // Last boss down -> stop boss music, but ONLY if it's still the channel: a teddy-bear song or Paradise
    // track that overrode it mid-fight owns the channel now and must not be yanked.
    level.acc_boss_music_count--;
    if ( level.acc_boss_music_count <= 0 )
    {
        level.acc_boss_music_count = 0;
        acc_music::stop_if( "acc_brutus_music" );
        acc_utility::log( "boss music OFF (last boss dead)" );
    }
}

// ---------------------------------------------------------------------------
// UNIFIED BOSS REWARD (user 2026-07-05: "the boss reward rule applies for ALL bosses, no differences").
// EVERY boss - Phantom, Rogue Protector, Avogadro, Trench Warden (Brutus) - grants the SAME set on death:
//   - 1 guaranteed challenge item (dupes convert to shards at pickup)
//   - 1 Mega Bottle to every player
//   - ROUND x acc_boss_score_per_round (180) points to every player (user 2026-07-07: nerfed -40%, was 300)
//   - int( ROUND / acc_boss_shards_round_div (3) ) Data Shards to every player
// PER boss, so a 2-boss round pays the full set for EACH kill. Examples: round 9 -> 3 shards + $1,620;
// round 18 (x2 bosses) -> 6 shards + $3,240 EACH; round 30 -> 10 shards + $5,400. Paradise-suppressed
// (the finale is survive-don't-farm). Call: acc_boss::grant_unified_boss_reward( drop_origin ).
// ---------------------------------------------------------------------------
function grant_unified_boss_reward( drop_origin, b_skip_item )
{
    if ( IS_TRUE( level.acc_paradise_onslaught ) )
        return;
    // b_skip_item (Brutus CYBERJACK gun-drop, user 2026-07-17 "either an item OR the gun,
    // never both"): the gun replaces the item; points/shards/bottle still granted. Every
    // other boss caller passes nothing -> undefined -> item granted as before.
    if ( !IS_TRUE( b_skip_item ) )
        acc_boss_items::grant_challenge_reward( drop_origin );   // 1 item, guaranteed (dupes -> shards)
    kill_round = ( isdefined( level.round_number ) ? level.round_number : 1 );
    score  = kill_round * getdvarint( "acc_boss_score_per_round", 180 );   // user 2026-07-07: -40% boss cash (was 300)
    shards = int( kill_round / getdvarint( "acc_boss_shards_round_div", 3 ) );
    players = GetPlayers();
    for ( i = 0; i < players.size; i++ )
    {
        p = players[ i ];
        if ( !isdefined( p ) || !isplayer( p ) )
            continue;
        if ( score  > 0 ) p zm_score::add_to_player_score( score );   // rounds UP to a multiple of 10
        if ( shards > 0 ) acc_data_shards::grant_player( p, shards, "boss" );
        p acc_mega_bottles::grant_bottle( 1, "boss" );
    }
}

function watch_mini_boss_death()
{
    // STUCK-GUARD FAILSAFE (user 2026-06-27 crash-hunt): acc_brutus_active is a one-at-a-time gate that is
    // cleared ONLY on this "death" notify (below). If the live host were ever removed without firing "death"
    // (forced Delete / cull), the gate would stick true and the Trench Warden could never respawn (round
    // soft-lock). brutus_guard_failsafe clears it if self is freed without a death. Cheap belt-and-suspenders.
    self thread brutus_guard_failsafe();

    self waittill( "death", attacker );

    // COOP CRASH GUARD: capture every self field behind ONE isdefined - the corpse can be reaped the same
    // frame the death notify fires (the race phantom_death_watch guards), and a self deref then throws
    // "not an entity" and ends the match. The respawn bookkeeping at the bottom MUST still run in that
    // case or acc_brutus_active jams true and the Trench Warden never respawns.
    drop_origin = undefined;
    n_bottles = 1;
    no_reward = false;
    if ( isdefined( self ) )
    {
        drop_origin = self.origin;
        n_bottles = ( isdefined( self.acc_bottle_drop ) ? self.acc_bottle_drop : 1 );
        no_reward = IS_TRUE( self.acc_no_shard_reward );
    }
    else if ( isdefined( attacker ) && isplayer( attacker ) )
    {
        drop_origin = attacker.origin;   // corpse already reaped: anchor the drop at the killer instead
    }

    if ( n_bottles <= 1 )
    {
        // A Brutus flagged acc_no_shard_reward (the PARADISE-fight Brutus, _acc_paradise::maybe_spawn_brutus) is a
        // survive-the-threat, NOT a farm: it grants NOTHING here - no points, no shards, no item, no bottle. The
        // Paradise Brutus already spawns on a SEPARATE path (spawn_one_paradise) + runs its OWN death watcher
        // (brutus_death_watch, count-only) and never threads THIS handler, so this guard is belt-and-suspenders
        // that also documents the intent (user 2026-06-29: "Paradise Brutus should not give any of this").
        if ( !no_reward && isdefined( drop_origin ) )
        {
            // BRUTUS (Trench Warden) CYBERJACK gun-drop (user 2026-07-17): 25% drop THE CYBERJACK
            // on the ground (if not already in rotation) / else the normal boss item - NEVER both.
            // The roll spawns the pickup itself; b_gun=true tells the reward to skip the item.
            b_gun = acc_cyberjack::try_brutus_gun_drop( drop_origin );
            grant_unified_boss_reward( drop_origin, b_gun );
        }
    }
    else
    {
        // Test boss (n_bottles>1): GUARANTEED item + bulk Mega so every perk can be Mega'd in one go.
        acc_boss_items::grant_challenge_reward( drop_origin );
        for ( i = 0; i < level.players.size; i++ )
        {
            p = level.players[ i ];
            if ( isdefined( p ) && isplayer( p ) )
                p acc_mega_bottles::grant_bottle( n_bottles, "test_boss" );
        }
    }

    // Trench Warden respawn schedule (user 2026-06-18): record the kill round so round_hook_loop
    // respawns him ACC_BRUTUS_RESPAWN_INTERVAL rounds later, and free the one-at-a-time guard.
    // Skip the dev bulk-test boss (n_bottles > 1) so dev mode doesn't pollute the real schedule.
    if ( n_bottles <= 1 )
    {
        level.acc_brutus_kill_round = level.round_number;
        level.acc_brutus_active = false;
    }
}

// Releases the one-at-a-time Brutus gate if the host is removed WITHOUT a "death" notify (forced Delete /
// engine cull). On a normal kill, self endon("death") ends this thread and watch_mini_boss_death clears the
// gate; this only fires if self is freed silently. Polls because a Delete() raises no notify of its own.
function brutus_guard_failsafe()
{
    level endon( "end_game" );
    self endon( "death" );

    while ( isdefined( self ) )
        wait 1;

    // self was freed without firing "death" -> release the gate so the Warden can be rescheduled.
    if ( IS_TRUE( level.acc_brutus_active ) )
    {
        level.acc_brutus_active = false;
        acc_utility::log( "Trench Warden: host removed without a death notify - released acc_brutus_active gate" );
    }
}

// ---------------------------------------------------------------------------
// Full boss "Subroutine Core"
// ---------------------------------------------------------------------------

function run_full_boss( round_number )
{
    level endon( "end_game" );

    acc_utility::log( "FULL BOSS: Subroutine Core, round " + round_number );

    // Lock players in the Lab until boss is down. TODO(acc-geom): geometry
    // triggers to close Lab exits.

    boss = spawn_subroutine_core( round_number );
    if ( !isdefined( boss ) ) return;

    // Phase poller only handles transitions while the boss is alive; the
    // death watcher below is the single "acc_boss_dead" emitter.
    level thread run_boss_phases( boss, round_number );

    // VERIFIED(acc): threading the watcher before arming the waittill below is
    // race-free - GSC notifies are not latched, but "acc_boss_dead" can only
    // fire after the actor's "death" notify, which requires damage processed
    // in a later server frame, and there is no wait between these two lines.
    boss thread watch_full_boss_death();

    level waittill( "acc_boss_dead", killer, death_origin );

    reward_players( round_number );

    // Guaranteed boss-item drop + Mega Bottles, attributed to the real killer
    // (the player who landed the final blow, resolved in the death watcher).
    acc_boss_items::on_boss_death( "full", killer, death_origin );
    // Guaranteed Mega Bottle drop to all players.
    acc_mega_bottles::on_boss_death( "full", killer, death_origin );

    release_lab_exits();
}

function spawn_subroutine_core( round_number )
{
    // The Core is a promoted stock zombie pinned at the struct (real, damageable, full stock
    // damage pipeline; scripted ranged attacks still TODO). Its boss SKIN (stock "Giant" body +
    // head + teal eyes + glow aura) is applied below, after the spawn-init gate (docs/09).
    spawn_struct = struct::get( "acc_boss_spawn", "targetname" );
    if ( !isdefined( spawn_struct ) )
    {
        acc_utility::log( "boss: no acc_boss_spawn struct placed, cannot spawn Subroutine Core" );
        return undefined;
    }

    if ( !isdefined( level.zombie_spawners ) || level.zombie_spawners.size == 0 )
    {
        acc_utility::log( "boss: no zombie_spawners, cannot spawn Subroutine Core" );
        return undefined;
    }
    spawner = level.zombie_spawners[ acc_utility::acc_rand_int( level.zombie_spawners.size ) ];

    // Chosen-struct spawn, pattern A: pass the struct as spawn_zombie's 3rd
    // arg so the relocation runs off OUR struct instead of a random
    // zombie_location.
    // VERIFIED(acc): spawn_zombie threads level.move_spawn_func on the passed
    // spawn_point immediately (zombie_utility.gsc:1518-1521). Safe here: the
    // "move_spawn_func undefined before round 1" trap doesn't apply because it
    // is defaulted to zm_utility::move_zombie_spawn_location inside stock
    // round_start (_zm.gsc:4118-4121), which ran at game start (round_think
    // threaded right after, _zm.gsc:4141) - by round 30 it is always defined.
    // VERIFIED(acc): the struct carries no script_noteworthy, so it is
    // defaulted to "spawn_location" (_zm_utility.gsc:216-219) and takes the
    // teleport-in path: Ghost -> anchor moveto struct.origin -> Show ->
    // notify "risen" (_zm_utility.gsc:255-299). The automatic random-location
    // pass (do_zombie_spawn -> move_spawn_func) early-outs because .spawn_pos
    // is already set (_zm_utility.gsc:192-196); its immediate duplicate
    // "risen" notify fires inside `thread do_zombie_spawn()` BEFORE
    // zombie_think arms its waittill (_zm_spawner.gsc:579-581) and is
    // harmlessly lost - the anchor-move path's notify (frames later, after the
    // 0.05s moveto) is the one that releases zombie_think. Pattern B
    // (._rise_spot) was rejected: it forces do_zombie_rise's ground-climbout
    // animation (_zm_spawner.gsc:2874-2879) - wrong read for a stationary
    // machine boss.
    core = zombie_utility::spawn_zombie( spawner, undefined, spawn_struct );
    if ( !isdefined( core ) )
    {
        acc_utility::log( "boss: spawn_zombie returned undefined (spawner missing script_forcespawn?)" );
        return undefined;
    }

    // VERIFIED(acc): zombie_spawn_init runs at frame end and clobbers
    // health/maxhealth (_zm_spawner.gsc:293-311) - poll the init flag before
    // promoting (the _zm_ai_faller.gsc:168 pattern, same as
    // spawn_juggernaut_host above and _acc_elites.gsc:129).
    while ( isdefined( core ) && !isdefined( core.zombie_init_done ) )
    {
        util::wait_network_frame();
    }
    if ( !isdefined( core ) || !isalive( core ) )
    {
        acc_utility::log( "boss: Subroutine Core died/vanished during init" );
        return undefined;
    }

    core.acc_is_boss = true; // boss headshot multiplier in _acc_damage
    core.phase = 1;

    // boss reskin model dropped - c_zom_zod_* not packable in this Mod Tools install; aura+eyes carry the distinction (see docs/09)

    // TEAL EYES + glow AURA (docs/09): mark the boss for the client-side eye recolour (accEyeTint,
    // _acc_lui.csc, shared teal colour - NO FX asset) and the holographic body-glow aura
    // (accPhantomAura, _acc_boss_phantom.csc PlayFX) so the Core is visually unmistakable. Both
    // reuse already-registered actor clientfields (no new field; the clientuimodel pool is untouched).
    if ( getdvarint( "acc_core_eyes", 1 ) == 1 )
        acc_lui::set_actor_eye_tint( core, true );
    if ( getdvarint( "acc_core_aura", 1 ) == 1 )
        acc_boss_phantom::set_phantom_aura( core, true );

    // HP: docs/08 - 50k base at round 30, +15k per round past 30.
    core.maxhealth = int( scale_boss_hp( round_number ) * acc_coop_scaling::special_hp_mult() );
    core.health = core.maxhealth;

    // Boss durability set, mirrored from stock mechz spawn setup
    // (mechz.gsc:946-957).
    core DisableAimAssist();
    core.disableAmmoDrop = true;
    core.no_gib = true;
    core.ignore_nuke = true;

    // ignore_enemy_count = true: the Core must NOT gate round end.
    // VERIFIED(acc): get_current_zombie_count/get_round_enemy_array skip any
    // actor with .ignore_enemy_count (zombie_utility.gsc:2023-2038, skip at
    // :2031); that count feeds BOTH the round-end poll (_zm.gsc:4733) and
    // round_spawning's 24-AI budget gate (_zm.gsc:3735). Per docs/08, full
    // boss rounds 30+ run the normal wave alongside the fight ("constant
    // chaff spawn") and the fight may span multiple rounds, so the Core must
    // neither hold rounds open nor starve the wave of AI slots. This is the
    // deliberate OPPOSITE of the mini-boss, which replaces the wave and IS
    // the round-end gate.
    core.ignore_enemy_count = true;

    // ignore_round_spawn_failsafe = true: the Core is stationary BY DESIGN.
    // VERIFIED(acc): round_spawn_failsafe kills any zombie that moves <24in
    // per 30s window (DistanceSquared < 576 check zombie_utility.gsc:1870;
    // level.failsafe_waittime default 30, :1830-1835; kill via dodamage
    // :1893) - a deliberately pinned actor is exactly what it hunts, so the
    // Core opts out via the check at zombie_utility.gsc:1825-1828. This is
    // only safe BECAUSE ignore_enemy_count is also set above: a boss that can
    // never be failsafe-culled must never be a round-end gate, or a bugged
    // fight could soft-lock the game.
    core.ignore_round_spawn_failsafe = true;

    // Boss health bar + nameplate (_acc_health_bars listens).
    level notify( "acc_boss_spawned", core, "SUBROUTINE CORE" );

    // Pin it at the struct once stock think finishes (threaded - the "risen"
    // relocation takes a few frames and we must not pin before it completes).
    core thread pin_core_in_place();

    acc_utility::log( "spawned Subroutine Core (" + core.maxhealth + " hp) at acc_boss_spawn" );
    return core;
}

// self = the Core actor. Stationary-boss pin (docs/08: forced-camp encounter).
function pin_core_in_place()
{
    self endon( "death" );

    // VERIFIED(acc): until "risen" completes the actor is already frozen by
    // zombie_spawn_init's PathMode("dont move") (_zm_spawner.gsc:319), and
    // zombie_think then re-enables movement - SetGoal(self.origin) +
    // PathMode("move allowed") + self.zombie_think_done = true
    // (_zm_spawner.gsc:588-590). Pinning earlier would be overridden, so poll
    // the flag (it is set once and never cleared; the same flag gates the
    // stock behavior tree, _zm_behavior.gsc:1146).
    while ( isdefined( self ) && !IS_TRUE( self.zombie_think_done ) )
    {
        util::wait_network_frame();
    }
    if ( !isdefined( self ) || !isalive( self ) ) return;

    // VERIFIED(acc): both are actor builtins stock calls on zombie-archetype
    // actors - SetGoal (_zm_spawner.gsc:588), PathMode("dont move")
    // (_zm_spawner.gsc:319, shared/ai/zombie.gsc:1144, and
    // archetype_apothicon_fury.gsc:582 with the comment "prevent
    // pathfinding"). Goal-at-own-origin + no pathing = pinned; melee-range
    // behavior still comes from the zombie behavior tree.
    self SetGoal( self.origin );
    self PathMode( "dont move" );
}

// self = the Core actor. Single emitter of "acc_boss_dead" (exactly once -
// one waittill("death") per boss; run_boss_phases no longer notifies).
function watch_full_boss_death()
{
    self waittill( "death", attacker );

    killer = undefined;
    if ( isdefined( self.acc_killer ) )
    {
        // _acc_damage stamps the final-blow player here when its pipeline
        // processed the killing hit (Phase 4 wiring) - prefer it because the
        // raw "death" attacker can be a non-player inflictor (grenade, trap).
        killer = self.acc_killer;
    }
    else if ( isdefined( attacker ) && isplayer( attacker ) )
    {
        killer = attacker;
    }

    // Capture origin NOW - the corpse entity can be removed by stock corpse
    // cleanup soon after death; the payload keeps the reward path safe.
    level notify( "acc_boss_dead", killer, self.origin );
}

function scale_boss_hp( round_number )
{
    base = 50000;
    rounds_past_30 = round_number - 30;
    if ( rounds_past_30 < 0 ) rounds_past_30 = 0;
    return base + ( rounds_past_30 * 15000 );
}

// ---------------------------------------------------------------------------
// Phase progression
// ---------------------------------------------------------------------------

function run_boss_phases( boss, round_number )
{
    level endon( "end_game" );
    level endon( "acc_boss_dead" );

    // Phases at 66% and 33% HP trigger "system outage" debuffs.
    max_phases = ( round_number >= 40 ? 4 : 3 );

    // Poll health for phase transitions while the boss is ALIVE only; death
    // is owned by watch_full_boss_death (a real actor fires "death" - this
    // loop must not double-emit "acc_boss_dead").
    while ( isdefined( boss ) && isalive( boss ) && boss.health > 0 )
    {
        wait( 0.5 );
        if ( !isdefined( boss ) || !isalive( boss ) ) break;

        current_phase = compute_phase( boss, max_phases );
        if ( current_phase > boss.phase )
        {
            boss.phase = current_phase;
            level thread on_phase_transition( boss, current_phase );
        }
    }
}

function compute_phase( boss, max_phases )
{
    frac = boss.health / boss.maxhealth;
    if ( frac > 0.66 ) return 1;
    if ( frac > 0.33 ) return 2;
    if ( frac > 0.15 ) return 3;
    return 4;
}

function on_phase_transition( boss, phase )
{
    acc_utility::log( "boss entering phase " + phase );

    switch ( phase )
    {
    case 2:
        disable_power_for( 60 );
        break;
    case 3:
        disable_perks_for( 60 );
        break;
    case 4:
        spawn_emp_elite_add();
        break;
    }
}

// VERIFIED(acc): there is no zm_power::turn_power_off_all in stock. Power is
// the "power_on" flag; stock watch_global_power reacts to clear/set
// (_zm_power.gsc:163-169; clear site :773, set pattern zm_giant.gsc:550).
function disable_power_for( duration )
{
    if ( !( level flag::get( "power_on" ) ) )
    {
        // Power was never activated; nothing to disable, and we must not
        // grant free power when the debuff ends.
        return;
    }

    acc_utility::log( "power disabled for " + duration + "s (boss debuff)" );
    level flag::clear( "power_on" );
    // Mega Electric Cherry ("Power Surge") holders are immune (user 2026-06-25, moved from Mega Widow's): power-off routes through perk_power_off
    // -> perk_pause -> UnsetPerk on every owner (_zm_power.gsc:699/:718,
    // _zm_perks.gsc:1249). Re-grant the immune players' perks across the next
    // few network frames (powered items unset one network-frame apart,
    // _zm_power.gsc:485). NOTE: power_on is a single global flag, so an immune
    // player's electric traps still go dark - only OWNED perks are preserved.
    level thread protect_immune_players_during_debuff();
    wait( duration );
    level flag::set( "power_on" );
    acc_utility::log( "power restored" );
}

// VERIFIED(acc): zm_perks::perk_lose_on_damage does not exist. The stock
// pause/unpause pair is perk_pause_all_perks / perk_unpause_all_perks
// (_zm_perks.gsc:1295/:1314; stock caller _zm_power.gsc:143).
function disable_perks_for( duration )
{
    acc_utility::log( "perks disabled for " + duration + "s (boss debuff)" );
    level thread zm_perks::perk_pause_all_perks();
    // Mega Electric Cherry ("Power Surge") holders are immune (user 2026-06-25; same UnsetPerk path, _zm_perks.gsc:1249).
    level thread protect_immune_players_during_debuff();
    wait( duration );
    level thread zm_perks::perk_unpause_all_perks();
    acc_utility::log( "perks restored" );
}

// Mega Electric Cherry ("Power Surge") boss-special immunity (docs/10_perks.md; moved from Jug/Widow's, user 2026-06-25). Re-assert
// immune players' perks for ~2s so the debuff's UnsetPerk cascade (one powered
// item per network frame) can't stick on them. Clearing disabled_perks[perk]
// makes the trailing global unpause/repower a no-op for these players.
function protect_immune_players_during_debuff()
{
    level endon( "end_game" );

    for ( n = 0; n < 20; n++ )
    {
        for ( i = 0; i < level.players.size; i++ )
        {
            p = level.players[ i ];
            if ( !isdefined( p ) || !isplayer( p ) ) continue;
            // Boss-special immunity = Mega ELECTRIC CHERRY "Power Surge" (user 2026-06-25; moved off Mega
            // Widow's Wine "Spiderman"). has_active_mega_perk requires the player to currently HOLD Electric
            // Cherry AND have Mega'd it - the persistent Mega flag is the only ownership marker that survives
            // THIS debuff's UnsetPerk cascade, which is exactly why the immunity must live on the Mega tier.
            if ( acc_mega_bottles::has_active_mega_perk( p, "specialty_combat_efficiency" ) )
                p restore_immune_player_perks();
        }
        util::wait_network_frame();
    }
}

// self = an Ultimate-Tank player. Re-Set every registered perk this player
// owned-but-was-paused, mirroring stock perk_unpause's re-grant block
// (_zm_perks.gsc:1278-1290), and clear disabled_perks so the global unpause skips them.
function restore_immune_player_perks()
{
    if ( !isdefined( self.disabled_perks ) ) return;
    if ( !isdefined( level._custom_perks ) ) return;

    a_keys = GetArrayKeys( level._custom_perks );
    for ( i = 0; i < a_keys.size; i++ )
    {
        perk = a_keys[ i ];
        if ( !IS_TRUE( self.disabled_perks[ perk ] ) ) continue;

        self.disabled_perks[ perk ] = false;            // unpause/repower now skips us
        self SetPerk( perk );                           // builtin: re-grant the perk
        self zm_perks::set_perk_clientfield( perk, 1 ); // PERK_STATE_OWNED = 1

        // Jug HP must be re-applied (UnsetPerk dropped the jugg add).
        self zm_perks::perk_set_max_health_if_jugg( perk, false, false );

        // Re-run the perk's custom give-thread if it has one (mirrors stock).
        if ( isdefined( level._custom_perks[ perk ].player_thread_give ) )
            self thread [[ level._custom_perks[ perk ].player_thread_give ]]();
    }
}

function spawn_emp_elite_add()
{
    acc_utility::log( "boss phase 4 add: EMP elite" );
    // TODO: call acc_elites::spawn_elite( "emp" ) once arg visibility is fixed.
}

// ---------------------------------------------------------------------------
// Rewards
// ---------------------------------------------------------------------------

function reward_players( round_number )
{
    reward = compute_shard_reward( round_number );

    for ( i = 0; i < level.players.size; i++ )
    {
        acc_data_shards::grant_player( level.players[ i ], reward, "boss" );
        // TODO(acc-oc): grant overclock re-roll voucher once voucher system exists.
    }

    acc_utility::log( "boss rewarded " + reward + " shards to each player" );
}

function compute_shard_reward( round_number )
{
    if ( round_number == ACC_BOSS_MINI_FIRST_ROUND )           return 2; // r10 mini
    if ( round_number == ACC_BOSS_MINI_FIRST_ROUND + ACC_BOSS_INTERVAL ) return 3; // r20 mini
    if ( round_number == ACC_BOSS_FULL_FIRST_ROUND )           return 4; // r30 full
    return 4; // capped
}

function release_lab_exits()
{
    // TODO(acc-geom): reopen Lab exit doors locked during the fight.
}
