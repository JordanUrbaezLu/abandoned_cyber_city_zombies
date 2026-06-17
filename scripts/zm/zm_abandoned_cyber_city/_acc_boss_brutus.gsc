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

#using scripts\zm\zm_abandoned_cyber_city\_acc_utility;

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

    level.acc_brutus_last = undefined;
    level thread brutus::spawn_brutus();
    // 15s is comfortably past the pack's short pre-spawn telegraph; a real failure
    // (no spawn spot / dog round) just times out and returns undefined.
    level util::waittill_any_timeout( 15, "acc_brutus_spawned" );

    return level.acc_brutus_last;
}
