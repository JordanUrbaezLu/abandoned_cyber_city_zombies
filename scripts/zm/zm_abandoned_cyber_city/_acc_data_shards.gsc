// =============================================================================
// _acc_data_shards.gsc - the custom "Data Shards" currency
//
// Design reference: docs/04_progression_and_skills.md (Two Currencies, Data
// Shard Sources), docs/06_mechanics.md (Data Shard Economy flow).
//
// Responsibilities:
//  - Per-player shard counter (self.acc_data_shards).
//  - Shard drop entities spawned by elite kills and objectives.
//  - HUD bridge - clientfield / hudelem that renders the count.
//  - Public API for other modules to query/spend shards.
// =============================================================================

#using scripts\codescripts\struct;
#using scripts\shared\callbacks_shared;
#using scripts\shared\hud_util_shared;
#using scripts\shared\util_shared;

#using scripts\zm\_zm_score;
#using scripts\zm\_zm_utility;

#using scripts\zm\zm_abandoned_cyber_city\_acc_utility;

// ---------------------------------------------------------------------------
// Constants - tune freely; documented in docs/04_progression_and_skills.md.
// ---------------------------------------------------------------------------

// Cap 99 -> 30 -> 50 (user 2026-06-19/21): scaled-down economy so 1 shard matters, then raised to 50
// so the deepest single purchase fits (Exo Suit T5 = 25, gun Overclock T5 = 24; see docs/47). Tight but
// affordable per-tier; total to max everything is a long-haul grind, the cap just blocks hoarding.
#define ACC_SHARDS_MAX 50
#define ACC_SHARD_DROP_LIFETIME_SEC 30
#define ACC_SHARD_PICKUP_RADIUS 48
#define ACC_SHARD_LOW_ROUND_THRESHOLD 10
#define ACC_SHARD_LOW_ROUND_DIMINISH_AFTER 2

// Pit caches now pay a FLAT count (user 2026-06-19: "1 shard per round, first come") - no round
// scaling (the old base + round/ACC_CACHE_SCALE_ROUNDS made shards inflate). Kept the dvar names so
// cache_yield still clamps, but ACC_CACHE_SCALE_ROUNDS is effectively unused (scaling removed below).
#define ACC_CACHE_SCALE_ROUNDS 9999
#define ACC_CACHE_YIELD_MAX 9

// Pickup world model (stock energy-ball; also needs an xmodel line in the .zone).
// #precache is a DIRECTIVE in BO3 - must sit after all #using/#define, before #namespace.
#precache( "model", "p7_fxanim_zm_stal_ray_gun_ball_mod" );
#precache( "model", "p7_cai_stacking_cargo_crate" );   // underground Data Cache (loot-for-shards) model

// (Phase 4: the LUI widget gets a "clientuimodel" clientfield named
// "hudItems.accDataShards" - the only pool that is provably safe to register
// GSC-only, see CHANGELOG stock-API notes. The old "toplayer" registration
// was a load-crash: stock registers every toplayer field in BOTH VMs.)

#namespace acc_data_shards;

// ---------------------------------------------------------------------------
// Init
// ---------------------------------------------------------------------------

function init()
{
    acc_utility::log( "data_shards init" );

    // VERIFIED(acc): the old GSC-only clientfield::register("toplayer", ...)
    // here was a map-load crash - stock registers every "toplayer" field in
    // BOTH VMs (e.g. _zm_perk_deadshot.gsc:71 vs .csc:47); zero GSC-only
    // counterexamples exist in the whole mirror. Greybox HUD is a classic
    // server-side hudelem instead (stock-alive: _zm.gsc:4880, hud_util_shared
    // createFontString + SetValue, numeric = no localization needed).

    level.acc_shards_pickup_model = "p7_fxanim_zm_stal_ray_gun_ball_mod"; // glowing energy ball = data-shard look (stock, verified); #precache'd above + xmodel line in .zone.
    level.acc_shards_cache_model = "p7_cai_stacking_cargo_crate";         // underground Data Cache crate (stock t7 prop, xmodel line in .zone).
    level.acc_shards_pool = []; // tracks live drops for cleanup.

    // Subroutine Tier 1 passive regen tick. Driven by cyberware module, which
    // just calls grant() on a timer. Nothing to do here.
}

function client_init()
{
    // Client-side HUD wiring lives in the CSC/LUI implementation (Phase 4).
    // For Phase 3 we rely on iprintln text feedback.
}

function on_player_connect( player )
{
    player.acc_data_shards = 0;
    player sync_shards_to_client();
}

function on_player_spawned( player )
{
    player sync_shards_to_client();
}

function on_player_disconnect( player )
{
    // Nothing persistent yet; post-1.0 we may write best-round metadata.
}

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

// Grant shards to a player. Returns actual grant amount (may be clamped or
// diminished based on round).
function grant_player( player, amount, source_tag )
{
    if ( !isdefined( player ) || !isdefined( amount ) || amount <= 0 )
    {
        return 0;
    }

    effective = amount;

    // Low-round elite diminishing returns (see docs/06_mechanics.md).
    if ( isdefined( source_tag ) && source_tag == "elite_kill" )
    {
        if ( level.round_number <= ACC_SHARD_LOW_ROUND_THRESHOLD )
        {
            if ( !isdefined( player.acc_shards_elite_count_round ) )
            {
                player.acc_shards_elite_count_round = 0;
            }
            player.acc_shards_elite_count_round += 1;
            if ( player.acc_shards_elite_count_round > ACC_SHARD_LOW_ROUND_DIMINISH_AFTER )
            {
                effective = int( amount * 0.5 );
                if ( effective < 1 ) effective = 1;
            }
        }
    }

    new_total = acc_utility::clamp_int( player.acc_data_shards + effective, 0, ACC_SHARDS_MAX );
    granted = new_total - player.acc_data_shards;
    player.acc_data_shards = new_total;
    player sync_shards_to_client();

    if ( granted > 0 )
    {
        player acc_utility::hud_msg( "+" + granted + " Data Shard" + ( granted > 1 ? "s" : "" ) );
    }
    return granted;
}

// Attempt to spend shards. Returns true iff the spend succeeded.
function try_spend( player, amount )
{
    if ( !isdefined( player ) || amount <= 0 ) return false;
    if ( !isdefined( player.acc_data_shards ) ) return false;   // robust vs a spend before connect-init (mirrors get_count)
    if ( player.acc_data_shards < amount ) return false;

    player.acc_data_shards -= amount;
    player sync_shards_to_client();
    return true;
}

function get_count( player )
{
    if ( !isdefined( player.acc_data_shards ) ) return 0;
    return player.acc_data_shards;
}

// Spawn a shard pickup entity at origin that any player can grab.
// Used by elite-kill hook in _acc_elites and by Hack/Overload events.
function spawn_pickup_at( origin, count )
{
    if ( !isdefined( count ) || count <= 0 ) count = 1;

    // Lift off the floor so the model doesn't sink in (live dvar acc_drop_model_z).
    shard = spawn( "script_model", origin + ( 0, 0, getdvarint( "acc_drop_model_z", 24 ) ) );
    shard setmodel( level.acc_shards_pickup_model );
    shard.acc_shard_count = count;
    shard.acc_created_at = gettime();

    // Hold-USE interact trigger (canonical recipe: _zm_utility.gsc:5439 navcard).
    // trigger_radius_use's radius/height args ARE its volume - no Radiant brush
    // and no zone line needed. Origin is raised off the floor so the
    // UseTriggerRequireLookAt line-of-sight check has something to hit.
    t_use = spawn( "trigger_radius_use", origin + ( 0, 0, 40 ), 0, ACC_SHARD_PICKUP_RADIUS, 72 );
    t_use TriggerIgnoreTeam();           // any player may grab (public pickup)
    t_use UseTriggerRequireLookAt();     // can't grab through a wall
    t_use SetCursorHint( "HINT_NOICON" );
    t_use SetHintString( "Hold ^3[{+activate}]^7 to grab " + count + " Data Shard" + ( count > 1 ? "s" : "" ) );
    t_use.acc_model = shard;
    t_use.acc_shard_count = count;
    t_use.acc_created_at = shard.acc_created_at;

    level.acc_shards_pool[ level.acc_shards_pool.size ] = shard;
    acc_utility::drops_debug( "shard SPAWN count=" + count + " at=" + origin + " lifetime=" + ACC_SHARD_DROP_LIFETIME_SEC + "s" );

    // Watchers run ON THE TRIGGER (self = trigger); the model is reached via
    // self.acc_model and torn down with it in cleanup_pickup().
    t_use thread watch_pickup();
    t_use thread watch_lifetime();
}

// ---------------------------------------------------------------------------
// Data Caches - the underground shard SOURCE (the user is moving shard collection
// down to the trench). A persistent crate + a hold-USE trigger that GRANTS shards
// once per round, then shows "depleted" until the next round (anti-grind: each cache
// pays once/round to whoever loots it first; "vault_cache" tag skips the elite-kill
// diminish). Placed by _acc_glitch_altar along the underground floor.
// ---------------------------------------------------------------------------

function spawn_cache_at( origin, count )
{
    if ( !isdefined( count ) || count <= 0 ) count = 1;

    crate = spawn( "script_model", origin );
    crate setmodel( level.acc_shards_cache_model );

    t = spawn( "trigger_radius_use", origin + ( 0, 0, 30 ), 0, 60, 72 );
    t TriggerIgnoreTeam();   // REQUIRED: a script-spawned use-trigger is NOT player-usable without this (stock perk machine _zm_perks.gsc:1523 + navcard :5442 both call it). Missing it = "I walk up and can't use it."
    t UseTriggerRequireLookAt();
    t SetCursorHint( "HINT_NOICON" );
    t.acc_cache_count = count;
    t.acc_depleted = false;
    t cache_set_hint();
    t thread cache_loop();
    t thread cache_round_rearm();
    acc_utility::drops_debug( "cache SPAWN count=" + count + " at=" + origin );
}

function cache_set_hint()   // self = the cache trigger
{
    if ( self.acc_depleted )
        self SetHintString( "^5DATA CACHE^7 - depleted (refills next round)" );
    else
    {
        y = cache_yield( self.acc_cache_count );
        self SetHintString( "Hold ^3[{+activate}]^7  ^5DATA CACHE^7 - extract " + y + " Data Shard" + ( y > 1 ? "s" : "" ) );
    }
}

// Per-cache yield scales with the round so the trench faucet keeps pace as costs/needs grow:
// base + 1 shard per ACC_CACHE_SCALE_ROUNDS rounds, capped at ACC_CACHE_YIELD_MAX. Computed at
// LOOT time off the live round (not at spawn). self.acc_cache_count holds the base.
function cache_yield( base )
{
    n = getdvarint( "acc_cache_scale_rounds", ACC_CACHE_SCALE_ROUNDS );
    if ( n < 1 ) n = 1;
    y = base + int( level.round_number / n );
    cap = getdvarint( "acc_cache_yield_max", ACC_CACHE_YIELD_MAX );
    if ( y > cap ) y = cap;
    if ( y < 1 ) y = 1;
    return y;
}

function cache_loop()   // self = the cache trigger
{
    self endon( "death" );
    level endon( "end_game" );

    for ( ;; )
    {
        self waittill( "trigger", player );
        if ( !is_player_alive( player ) ) continue;
        if ( self.acc_depleted )
        {
            player acc_utility::hud_msg( "Data Cache: depleted (refills next round)" );
            wait 0.3;
            continue;
        }
        grant_player( player, cache_yield( self.acc_cache_count ), "vault_cache" );
        player PlaySound( "acc_shard_pickup" );
        self.acc_depleted = true;
        self cache_set_hint();
        wait 0.3;
    }
}

function cache_round_rearm()   // self = the cache trigger
{
    self endon( "death" );
    level endon( "end_game" );

    for ( ;; )
    {
        level waittill( "acc_round_start" );
        self.acc_depleted = false;
        self cache_set_hint();
    }
}

// ---------------------------------------------------------------------------
// Internals
// ---------------------------------------------------------------------------

function sync_shards_to_client()
{
    if ( !isdefined( self.acc_data_shards ) ) self.acc_data_shards = 0;
    if ( !isdefined( self.acc_shards_hud ) )
    {
        self.acc_shards_hud = self hud::createFontString( "default", 1.3 );
        // TOP-LEFT under the health bar (was BOTTOM_LEFT, where the stock points
        // display blocked it). Health label y=16, bar y=32 -> shards at y=50.
        self.acc_shards_hud hud::setPoint( "TOP_LEFT", "TOP_LEFT", 16, 50 );
        self.acc_shards_hud.alignX = "left";
        self.acc_shards_hud.alignY = "top";
        self.acc_shards_hud.color = ( 0.3, 0.85, 1.0 );
        self.acc_shards_hud.hidewheninmenu = true;
    }
    // Labeled inline (SetText accepts raw strings, stock _zm.gsc:4679).
    self.acc_shards_hud SetText( "^5DATA SHARDS ^7" + self.acc_data_shards );
    // Always visible (dim at 0) so the currency is discoverable - the whole trench loop keys off it
    // (user 2026-06-19). Was alpha 0 at 0 shards, i.e. HUD invisible until your first shard = read as
    // a missing HUD / "what currency?" to a fresh player.
    self.acc_shards_hud.alpha = ( self.acc_data_shards > 0 ? 0.9 : 0.35 );
    level notify( "acc_shards_changed", self );
}

function watch_pickup()   // self = the hold-use trigger
{
    // NOTE: do NOT `self endon( "acc_shard_claimed" )` here. We notify that on a
    // successful grab to kill the sibling watch_lifetime thread - but if this
    // thread also endon'd it, the notify would abort us BEFORE cleanup_pickup()
    // runs and the model/trigger would never despawn. This thread ends via its
    // explicit return instead.
    self endon( "death" );

    for ( ;; )
    {
        self waittill( "trigger", player );          // fires only on use-button press
        if ( !is_player_alive( player ) ) continue;

        acc_utility::drops_debug( "shard PICKUP-TRY player=" + player.name + " count=" + self.acc_shard_count );
        grant_player( player, self.acc_shard_count, "pickup" );
        acc_utility::drops_debug( "shard GRANT player=" + player.name + " req=" + self.acc_shard_count + " total=" + player.acc_data_shards );

        // Pickup blip (docs/35_sound_plan.md): positional cue on the picking
        // player at the PHYSICAL pickup only. Alias "acc_shard_pickup" lives in
        // sound/aliases/acc_audio.csv; silent no-op until authored + registered.
        player PlaySound( "acc_shard_pickup" );
        self notify( "acc_shard_claimed" );          // kill the sibling lifetime thread first
        cleanup_pickup();
        return;
    }
}

// Tear down the trigger AND its model together. self = the trigger.
function cleanup_pickup()
{
    if ( isdefined( self.acc_model ) ) self.acc_model delete();
    if ( isdefined( self ) ) self delete();
}

function watch_lifetime()   // self = the hold-use trigger
{
    self endon( "acc_shard_claimed" );
    self endon( "death" );

    wait( ACC_SHARD_DROP_LIFETIME_SEC );

    acc_utility::drops_debug( "shard DESPAWN count=" + self.acc_shard_count + " age=" + ( gettime() - self.acc_created_at ) / 1000 + "s" );
    cleanup_pickup();
}

function is_player_alive( player )
{
    if ( !isdefined( player ) ) return false;
    // VERIFIED(acc): zm_utility::is_player_valid (_zm_utility.gsc:1600) checks
    // defined/alive/spawned/not-laststand/not-spectator. The old manual check
    // read player.isdowned, a field that does not exist anywhere in BO3 stock
    // (the real downed flag is self.laststand, _zm_laststand.gsc:200) - downed
    // players could claim shards.
    return zm_utility::is_player_valid( player );
}
