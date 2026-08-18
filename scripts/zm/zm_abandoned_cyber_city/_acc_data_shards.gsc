// =============================================================================
// _acc_data_shards.gsc - the custom "Data Shards" currency
//
// Design reference: docs/03_progression_and_skills.md (Two Currencies, Data
// Shard Sources), docs/05_mechanics.md (Data Shard Economy flow).
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
#using scripts\zm\zm_abandoned_cyber_city\_acc_perk_lights;   // set_glow() for the shard-bank "has shards" indicator glow

// ---------------------------------------------------------------------------
// Constants - tune freely; documented in docs/03_progression_and_skills.md.
// ---------------------------------------------------------------------------

// Trench shard-bank ("Data Cache") indicator glow (user 2026-06-24): a DIM WHITE glow on each cache
// crate that means "shards available THIS round". ON while armed; removed the instant a player loots
// it that round; restored when it re-arms at the next round start. Index 12 in the accPerkGlow palette
// (acc/light/fx_perk_glow_white_dim; _acc_perk_lights.csc). Client-side FX (server PlayFX doesn't render).
#define ACC_CACHE_GLOW_INDEX 12

// Cap 99 -> 30 -> 50 -> 500 (user 2026-06-19/21/22): the 50 cap was too tight ("we dont really need a
// 50 cap"); raised to 500 so players can bank toward the deep multi-tier sinks (Exo Suit + per-gun
// Overclocks; see docs/29) without constantly hitting the ceiling. Still finite (blocks infinite hoarding).
#define ACC_SHARDS_MAX 500
#define ACC_DEV_SHARDS 1000   // dev sandbox (acc_dev 1) starting count + raised cap (user 2026-06-25); normal play keeps ACC_SHARDS_MAX
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
// MODEL REVERT (user 2026-07-10): back to the p7_cai_stacking_cargo_crate the user preferred (the 2026-07-09
// STATION REMODEL to p7_zm_sta_computer_tower_01 is undone). The crate SHIPS a _col collision LOD so a bare
// script_model of it is SOLID on its own (the tower had none = that's why the caches went walk-through); the
// matching add_prop_clips.js clips are belt-and-suspenders, sized to the 64x64x48 crate. Crate origin sits at
// its BASE (floorLift 0) -> spawn lift is 0 (was +36 for the mesh-centered tower). xmodel line already in .zone.
#precache( "model", "p7_cai_stacking_cargo_crate" );   // underground/plaza Data Cache (loot-for-shards) model
// Kill-feed gain-popup strings (user 2026-08-02; sent via LuiNotifyEvent in grant_player - direct,
// NOT through acc_points::send_kill_feed, which would close a #using cycle points->boss_items->here).
// MUST live HERE in the preamble: a mid-file #precache("string",...) COMPILES but is never collected
// into the load-time precache pass, so the istring gets no CS_LOCALIZED_STRINGS slot and the client
// GetIString returns nil = the feed row silently never renders (2026-08-02 incident - the popups were
// invisible for every source until these two lines moved up from below the functions).
#precache( "string", "ZM_AETHERIUM_KF_SHARD" );
#precache( "string", "ZM_AETHERIUM_KF_SHARDS" );
// Data Shards HUD icon (user 2026-06-25): the player's PNG replaces the "DATA SHARDS" text label. The server
// hudelem path is a DEAD END - a usermap cannot build a 2D HUD material ("No techsetdef for material type '2d'");
// the image i_acc_data_shard packs fine though, so the icon is drawn in LUI (acc_hud.lua, CoD.AccShardIcon),
// the same proven path as the perk bar / PaP-tier icons. This hudelem keeps ONLY the count (the LUI icon is the label).

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
    level.acc_shards_cache_model = "p7_cai_stacking_cargo_crate";         // Data Cache = stacking cargo crate (64x64x48, ships _col LOD so it self-collides; xmodel line in .zone).
    level.acc_shards_cache_lift  = 0;                                     // crate origin sits at its base (floorLift 0) -> no spawn lift. Paired with the model above; a mesh-centered model would set this to its floorLift.
    // (No tracking array: a former level.acc_shards_pool was WRITE-ONLY - appended per drop, never read
    // or trimmed - an unbounded dead-reference leak over a long match. Each pickup self-cleans via
    // watch_lifetime (timeout) or cleanup_pickup (on grab), so no pool is needed. Removed 2026-06-25.)

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
    // Dev mode (acc_dev 1) starts each player with a big testing stash; normal play starts at 0. ONE-TIME
    // grant (not a refill loop), so spending then behaves normally. START 100 BELOW THE DEV CAP
    // (2026-08-02): starting AT the 1000 cap made every trench/cache/altar grant clamp to granted==0 -
    // silently no feed row, no toast - so gain-feedback paths were untestable in dev ("when you get
    // shards from the shard disposals... it doesnt show up"). (GSC ternary must be fully paren-wrapped.)
    player.acc_data_shards = ( ( isdefined( level.acc_dev ) && level.acc_dev ) ? ( ACC_DEV_SHARDS - 100 ) : 0 );
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

// Per-player shard ceiling. Dev mode raises it to ACC_DEV_SHARDS so the dev sandbox can hold (and re-earn
// up to) its 1000-shard testing stash; normal play keeps ACC_SHARDS_MAX. (GSC ternary fully paren-wrapped.)
function shards_cap()
{
    return ( ( isdefined( level.acc_dev ) && level.acc_dev ) ? ACC_DEV_SHARDS : ACC_SHARDS_MAX );
}

// (The KF_SHARD/KF_SHARDS string precaches used to sit HERE, mid-file - they compiled but never
// registered at load, so the feed rows were invisible. Moved to the directive preamble 2026-08-02.)

// Grant shards to a player. Returns actual grant amount (may be clamped or
// diminished based on round).
function grant_player( player, amount, source_tag )
{
    if ( !isdefined( player ) || !isdefined( amount ) || amount <= 0 )
    {
        return 0;
    }

    effective = amount;

    // Low-round elite diminishing returns (see docs/05_mechanics.md).
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

    // [acc] COOP CRASH GUARD: a player added to level.players before acc_data_shards::on_player_connect
    // has run (mid-game join / startup race) has no acc_data_shards yet; a grant (Reactor Surge, elite
    // drop, cache) would do arithmetic on undefined and throw. Mirror the try_spend/get_count guards.
    if ( !isdefined( player.acc_data_shards ) )
        player.acc_data_shards = 0;

    new_total = acc_utility::clamp_int( player.acc_data_shards + effective, 0, shards_cap() );
    granted = new_total - player.acc_data_shards;
    player.acc_data_shards = new_total;
    player sync_shards_to_client();

    if ( granted > 0 )
    {
        // Gain popup rides the mid-screen kill feed (user 2026-08-02 "like the text that says
        // +110 Critical Kill... a different color/shade") - AetheriumKillFeed.lua colors any
        // "Data Shard" row ice-cyan and skips it in the points running total. The old
        // center-screen toast survives ONLY as the non-Aetherium-HUD fallback (feed widget is
        // Aetherium-only). At-cap no-op grants (granted == 0) stay silent on both paths.
        if ( isdefined( level.acc_aetherium_hud ) && level.acc_aetherium_hud )   // no shared.gsh #insert in this file -> no IS_TRUE macro
        {
            text = &"ZM_AETHERIUM_KF_SHARD";
            if ( granted > 1 )
                text = &"ZM_AETHERIUM_KF_SHARDS";
            player LuiNotifyEvent( &"score_event", 2, text, granted );
        }
        else
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

    // FLOOR-SNAP the drop origin (user 2026-07-08): shared acc_utility::drop_floor_origin - steps through
    // the dying enemy's own body (the trace starts inside it - the "snapped onto the corpse mid-air" bug)
    // down to real world geometry, accepts brushmodel surfaces, keeps the origin on a true miss (never
    // buries). Fixed ground callers (glitch-altar caches) snap to themselves (no-op). Live dvar
    // acc_drop_floor_snap (1 = on) lives inside the helper, shared with the boss-item path.
    origin = acc_utility::drop_floor_origin( origin );

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

// group (user 2026-07-11): the anti-hog cap is scoped PER GROUP ("plaza" vs "trench") - a player may
// loot one cache from EACH group per round, just never two from the same group. Omitted = "default".
function spawn_cache_at( origin, count, group, yaw )
{
    if ( !isdefined( count ) || count <= 0 ) count = 1;

    lift = ( isdefined( level.acc_shards_cache_lift ) ? level.acc_shards_cache_lift : 0 );   // model-paired lift (init sets it beside the model)
    crate = spawn( "script_model", origin + ( 0, 0, lift ) );   // 0 for the base-origin cargo crate; was +36 for the mesh-centered tower
    crate setmodel( level.acc_shards_cache_model );
    if ( isdefined( yaw ) && yaw != 0 )
        crate.angles = ( 0, yaw, 0 );   // scatter yaw (prop audit 2026-08-03): VISUAL only - the 64x64 nav clip stays axis-aligned; crate self-collides via its _col LOD

    t = spawn( "trigger_radius_use", origin + ( 0, 0, 30 ), 0, 60, 72 );
    t TriggerIgnoreTeam();   // REQUIRED: a script-spawned use-trigger is NOT player-usable without this (stock perk machine _zm_perks.gsc:1523 + navcard :5442 both call it). Missing it = "I walk up and can't use it."
    t UseTriggerRequireLookAt();
    t SetCursorHint( "HINT_NOICON" );
    t.acc_cache_count = count;
    t.acc_cache_group = ( isdefined( group ) ? group : "default" );   // anti-hog scope key (see cache_loop)
    t.acc_depleted = false;
    t.acc_cache_crate = crate;   // the renderable model the indicator glow rides (the trigger has no tag_origin)
    t cache_set_hint();
    t cache_set_glow( true );    // armed at spawn -> dim white glow ON ("shards available")
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

// Indicator glow on the cache crate (user 2026-06-24): dim white glow = "shards available this round".
// on=true -> glow; on=false -> off (looted). Client-side FX via the perk-light pipeline (set_glow);
// the glow rides the CRATE model (the trigger has no tag_origin). self = the cache trigger.
function cache_set_glow( on )
{
    if ( !isdefined( self.acc_cache_crate ) ) return;
    acc_perk_lights::set_glow( self.acc_cache_crate, ( on ? ACC_CACHE_GLOW_INDEX : 0 ) );
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

        // ONE cache per player per round PER GROUP (user 2026-06-25; group split user 2026-07-11): in CO-OP,
        // the anti-hog cap is scoped to the cache's GROUP ("plaza" crates vs "trench" pit caches) - a player
        // may grab one PLAZA cache AND one TRENCH cache in the same round, but never two from the SAME group
        // (the second must go to a teammate). Marker = per-group round-number map
        // (player.acc_cache_looted_round[ group ]) - still self-healing (no reset thread; a new round
        // re-enables everything automatically, like the reactor cooldown). SOLO is EXEMPT
        // (level.players.size <= 1) - with no teammate to "leave it for", blocking would waste shards forever.
        // Toggle: acc_cache_one_per_player 0 disables the restriction (then it's first-come per cache again).
        cur = ( isdefined( level.round_number ) ? level.round_number : 1 );
        grp = ( isdefined( self.acc_cache_group ) ? self.acc_cache_group : "default" );
        if ( getdvarint( "acc_cache_one_per_player", 1 ) == 1 && level.players.size > 1
             && isdefined( player.acc_cache_looted_round ) && isdefined( player.acc_cache_looted_round[ grp ] )
             && player.acc_cache_looted_round[ grp ] == cur )
        {
            player acc_utility::hud_msg( "^5DATA CACHE^7 - you already grabbed one here this round (leave these for a teammate)" );
            wait 0.3;
            continue;
        }

        grant_player( player, cache_yield( self.acc_cache_count ), "vault_cache" );
        if ( !isdefined( player.acc_cache_looted_round ) )
            player.acc_cache_looted_round = [];   // per-group map, keyed by cache group string
        player.acc_cache_looted_round[ grp ] = cur;   // mark: this player has taken a cache from THIS GROUP this round
        player PlaySound( "acc_shard_pickup" );
        self.acc_depleted = true;
        self cache_set_hint();
        self cache_set_glow( false );   // looted this round -> glow OFF (indicator: nothing left to take)
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
        self cache_set_glow( true );    // refilled at round start -> glow back ON (indicator: shards available)
    }
}

// ---------------------------------------------------------------------------
// Internals
// ---------------------------------------------------------------------------

function sync_shards_to_client()
{
    if ( !isdefined( self.acc_data_shards ) ) self.acc_data_shards = 0;
    // Top-left shards readout RECLAIMED (user 2026-06-27): it was hidden (alpha 0) - the SQUAD roster shows the
    // count now - but a HIDDEN server hudelem STILL occupies a slot in the SHARED, fixed per-client pool (alpha 0
    // != freed). Freeing it makes room for the roster's one-row "points SH EXO MB" stats line without overflowing
    // the ~31/client pool in 4-player co-op (memory server-hudelem-pool-exhaustion-coop). The count lives in
    // self.acc_data_shards; the roster (_acc_health_bars::update_roster) reads it directly, so nothing visible is
    // lost. (Re-add a visible readout = createFontString + SetValue, NOT SetText - the count is unbounded-ish.)
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

        // Pickup blip (docs/23_sound_plan.md): positional cue on the picking
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
