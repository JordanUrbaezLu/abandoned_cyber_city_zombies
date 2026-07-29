// =============================================================================
// _acc_mega_bottles.gsc - Empty Mega Bottle acquisition + perk-Mega upgrades
//
// Design reference: docs/10_perks.md (Mega Bottles system + Perk reference base/Mega).
//
// Acquisition: 1 bottle guaranteed per player on EVERY boss kill (mini + full).
// Usage: at a Lab perk machine currently dispensing a perk the player owns,
// consume 1 bottle to flag that perk as Mega'd on self.acc_mega_perks.
// Persistence: Mega flag stays across death (player re-buys perk -> re-apply).
// =============================================================================

#using scripts\shared\array_shared;
#using scripts\shared\hud_util_shared;
#using scripts\shared\util_shared;
#using scripts\shared\callbacks_shared;   // callback::on_ai_spawned (suppress stock ww_grenade drop -> we own it)

#insert scripts\shared\shared.gsh;

#using scripts\zm\_zm_perks;
#using scripts\zm\_zm_score;
#using scripts\zm\_zm_utility;
#using scripts\zm\_zm_weapons;
#using scripts\zm\_zm_spawner;     // register_zombie_death_event_callback (Mega Widow's spider-drop boost)
#using scripts\zm\_zm_powerups;    // specific_powerup_drop( "ww_grenade", ... )

#using scripts\zm\zm_abandoned_cyber_city\_acc_utility;
#using scripts\zm\zm_abandoned_cyber_city\_acc_weapon_variants;

// (Spiderman's custom web-grenade POOL + 6-cap + 4/round restock + WEB GRENADES HUD were REMOVED 2026-06-24
//  per user - Mega Widow's now uses STOCK web-grenade behavior; the one-hit melee was REMOVED 2026-06-29 and the
//  boss-special immunity MOVED to Mega Electric Cherry 2026-06-25, so its remaining Mega effects are the
//  low-stance spider-mobility + the boosted spider-drop rate.) Armory Mega (Mule): -10% buys + reserve refill.
#define ACC_ARMORY_ROUND_REFILL 0.20   // Armory (Mule Kick Mega): +20% of each gun's reserve cap, refilled at round start (was 0.35, user 2026-06-21)

// DEV bottle stash (user 2026-07-07): dev mode no longer force-opens the perk doors (they run the real 4-of-10
// rotation now); instead a dev tester is kept topped up so they can BUY any closed door open via the permanent-
// unlock trigger. Refill to TARGET whenever below FLOOR (mirrors _acc_dev::dev_unlimited_money). Both cover all
// 10 doors many times over (10 doors x 2 bottles = 20).
#define ACC_DEV_BOTTLE_TARGET   99
#define ACC_DEV_BOTTLE_FLOOR    30

#namespace acc_mega_bottles;

// ---------------------------------------------------------------------------
// Init
// ---------------------------------------------------------------------------

function init()
{
    acc_utility::log( "mega_bottles init" );

    // VERIFIED(acc): the old GSC-only clientfield::register("toplayer", ...)
    // here was a map-load crash - stock registers every "toplayer" field in
    // BOTH VMs; the greybox HUD is a server-side hudelem (see
    // sync_bottle_count_to_client). LUI clientfield bridge returns in Phase 4.

    // Sticky-Mega lifecycle: stock calls these ON the player after a
    // successful perk drink / on perk loss (_zm_perks.gsc:652-655 / :956-958).
    // Re-buying a Mega'd perk re-applies its deltas (docs/10 persistence rule).
    level.perk_bought_func = &on_perk_bought;
    level.perk_lost_func = &on_perk_lost;

    level thread mega_machine_watcher();
    level thread armory_round_refill_watcher();

    // Widow's Wine spider-drop economy, fully OWNED by us (user 2026-06-26). We RETUNE both base and Mega drop
    // rates - base goes BELOW stock (web 10 / gun 15 / knife 20) and Mega = base +10pp (web 20 / gun 25 / knife
    // 30). A usermap can't lower the stock #define chances, so the spawn hook SUPPRESSES the stock ww_grenade
    // drop per-zombie (sets b_widows_wine_no_powerup) and the death hook does the single replacement roll.
    callback::on_ai_spawned( &mww_suppress_stock_spider_drop );
    zm_spawner::register_zombie_death_event_callback( &mww_spider_drop_roll );

    // DEV: keep testers stocked with bottles so they can buy perk doors open (dev no longer force-opens them).
    if ( isdefined( level.acc_dev ) && level.acc_dev )
        level thread dev_unlimited_bottles();
}

// DEV top-up (user 2026-07-07): while level.acc_dev, refill every player's Mega Bottles to ACC_DEV_BOTTLE_TARGET
// whenever they dip below ACC_DEV_BOTTLE_FLOOR - so a dev tester always has enough to buy any closed perk door
// open (the permanent-unlock trigger, _acc_perk_doors) and Mega any perk. No-ops entirely in normal play (thread
// only started under dev). Plain field write (no stock API), so no blackscreen-flag gate is needed here.
function dev_unlimited_bottles()
{
    level endon( "end_game" );

    for ( ;; )
    {
        players = GetPlayers();
        for ( i = 0; i < players.size; i++ )
        {
            p = players[ i ];
            if ( !isdefined( p ) || !isplayer( p ) ) continue;
            if ( !isdefined( p.acc_mega_bottles ) ) p.acc_mega_bottles = 0;
            if ( p.acc_mega_bottles < ACC_DEV_BOTTLE_FLOOR )
            {
                p.acc_mega_bottles = ACC_DEV_BOTTLE_TARGET;
                p sync_bottle_count_to_client();
            }
        }
        wait 1;
    }
}

// --- Widow's Wine spider-drop economy (we OWN it; user 2026-06-26) ----------------------------------------
// Stock drops the blue ww_grenade refill at hard-coded #define chances (15% web / 20% gun / 25% knife on a
// webbed zombie kill, in _zm_perk_widows_wine.gsc) and a usermap can't lower those. To retune BOTH base AND
// Mega - and especially to bring BASE *below* stock - we suppress the stock drop and roll it ourselves:
//   * mww_suppress_stock_spider_drop (callback::on_ai_spawned) sets b_widows_wine_no_powerup on every zombie.
//     That field is READ-ONLY in all of stock (only _zm_perk_widows_wine.gsc:313 reads it; nothing assigns
//     it), so once set at spawn it sticks and stock's drop is cleanly disabled. (It's specific to the Widow's
//     drop - distinct from the broad `no_powerups` field, which we deliberately do NOT touch.)
//   * mww_spider_drop_roll (death callback) does the single replacement roll -> exact rates, no double-drops.
// New rates: base web 10 / gun 15 / knife 20; Mega = base + acc_widow_mega_spider_add_pct (default 10) ->
// web 20 / gun 25 / knife 30. All five values are live dvars.

// self = a freshly spawned AI. Disable the stock ww_grenade auto-drop so our death roll is the only source.
function mww_suppress_stock_spider_drop()
{
    if ( getdvarint( "acc_widow_spider_custom", 1 ) != 1 ) return;   // 0 = fall back to stock drops entirely
    self.b_widows_wine_no_powerup = true;   // stock skips its ww_grenade drop for this zombie...
    self.acc_ww_custom_drop = true;         // ...and our death roll owns it instead (paired flag, so a mid-game
                                            // dvar flip only affects future spawns - never a half-suppressed zombie)
}

// self = the killed zombie; attacker = the killer. Single roll that replaces the stock ww_grenade drop.
function mww_spider_drop_roll( attacker )
{
    if ( !IS_TRUE( self.acc_ww_custom_drop ) ) return;   // only zombies we suppressed stock for (custom on at spawn)
    // Stock precondition: only a webbed (cocooned) or slowed zombie can drop a ww_grenade at all.
    if ( !IS_TRUE( self.b_widows_wine_cocoon ) && !IS_TRUE( self.b_widows_wine_slow ) ) return;
    if ( !isdefined( attacker ) || !isplayer( attacker ) ) return;

    // The killer must hold Widow's (base OR Mega - has_active_mega_perk also covers the EMP-paused Mega case).
    is_mega = has_active_mega_perk( attacker, "specialty_widowswine" );
    if ( !is_mega && !( attacker HasPerk( "specialty_widowswine" ) ) ) return;

    // Kill-type tier, same comparison stock uses (web-grenade kill / Widow's knife kill / else = gun).
    dw = self.damageweapon;
    if ( isdefined( dw ) && isdefined( level.w_widows_wine_grenade ) && dw == level.w_widows_wine_grenade )
        chance = getdvarint( "acc_widow_spider_web_pct", 10 );
    else if ( isdefined( dw ) &&
              ( ( isdefined( level.w_widows_wine_knife )        && dw == level.w_widows_wine_knife ) ||
                ( isdefined( level.w_widows_wine_bowie_knife )  && dw == level.w_widows_wine_bowie_knife ) ||
                ( isdefined( level.w_widows_wine_sickle_knife ) && dw == level.w_widows_wine_sickle_knife ) ) )
        chance = getdvarint( "acc_widow_spider_knife_pct", 20 );
    else
        chance = getdvarint( "acc_widow_spider_gun_pct", 15 );

    // Mega "Spiderman" adds a flat +10 percentage points on every tier (web 20 / gun 25 / knife 30).
    if ( is_mega ) chance += getdvarint( "acc_widow_mega_spider_add_pct", 10 );

    if ( RandomFloat( 1.0 ) <= ( chance / 100.0 ) )
        level thread zm_powerups::specific_powerup_drop( "ww_grenade", self.origin, undefined, undefined, undefined, attacker );
}

function on_player_connect( player )
{
    player.acc_mega_bottles = 0;
    // Per-perk Mega flags. Key = specialty string (e.g. "specialty_armorvest");
    // Value = true if Mega'd. Persists through death for the run.
    player.acc_mega_perks = [];
    player sync_bottle_count_to_client();
    player thread flash_respawn_watcher();

    // Perk-buy jingle plays AT PURCHASE on the MACHINE - see perk_purchase_jingle_watch().
    player thread perk_purchase_jingle_watch();
}

// The Flash move-speed bonus is wiped on every (re)spawn: zm_usermap's
// giveCustomCharacters resets SetMoveSpeedScale(1) (zm_usermap.gsc:336).
// Re-apply when the player still holds a Mega'd Stamin-Up (retained-perk
// respawns re-give the perk via return_retained_perks).
function flash_respawn_watcher()
{
    self endon( "disconnect" );

    for ( ;; )
    {
        self waittill( "spawned_player" );
        self.acc_flash_speed = false;
        self.acc_mega_flopper_speed = false;
        self.acc_mww_stance_speed = 1.0;
        self.acc_mww_down_owner = false;   // fresh spawn = no down-ownership snapshot until the watcher re-captures it
        wait 0.25; // after the spawn-path speed reset
        if ( self HasPerk( "specialty_staminup" )
             && has_mega_perk( self, "specialty_staminup" ) )
        {
            self apply_flash_speed();
        }
        // Mega Flopper (PhD Slider) 1.75x slide-gated move - same respawn re-apply as The Flash.
        if ( self HasPerk( "specialty_electriccherry" )
             && has_mega_perk( self, "specialty_electriccherry" ) )
        {
            self apply_mega_flopper_speed();
        }
        // Mega Widow's Wine low-stance mobility (crouch 2.6x / prone 10x / down 15x) - same respawn re-apply
        // (SetMoveSpeedScale was reset to 1 on the spawn path; restart the stance watcher with fresh state).
        if ( self HasPerk( "specialty_widowswine" )
             && has_mega_perk( self, "specialty_widowswine" ) )
        {
            self apply_mww_stance_speed();
        }
    }
}

// The Armory Mega (Mule Kick) "all buys 10% cheaper" is POINT OF SALE (charge AND
// shown price). Overriding stock cost files from a usermap does NOT work (verified
// 2026-06-14: base game wins), so the discount is applied from OUR side by setting
// each machine's own cost field + hint to the discounted value for a nearby Armory
// holder: PERKS in _acc_perk_info::armory_perk_pricing, PaP tier-up in
// _acc_pap_levels::acc_do_tier_up. (Box display/charge + PaP first-pack: TODO.)

// (Widow's web-grenade round-restock + virtual pool REMOVED 2026-06-24 per user - Mega Widow's uses STOCK
// web-grenade behavior now. See the comment by ACC_ARMORY_ROUND_REFILL.)

// ---------------------------------------------------------------------------
// Boss drop entry point. Called from _acc_boss.gsc on every boss kill,
// BOTH mini-boss (Juggernaut Host) and full boss (Subroutine Core).
//
// killer may be undefined (boss death by falling, rare edge case). In that
// case fall back to awarding all living players.
// ---------------------------------------------------------------------------

function on_boss_death( tier, killer, origin )
{
    // Rule per design: every PLAYER gets a Mega Bottle, not just the killer.
    // 4p co-op gets 4 bottles per boss kill.
    for ( i = 0; i < level.players.size; i++ )
    {
        player = level.players[ i ];
        if ( !isdefined( player ) ) continue;
        if ( !isplayer( player ) ) continue;
        player grant_bottle( 1, "boss_" + tier );
    }

    acc_utility::log( "mega_bottles: granted +1 to all players (" + tier + " boss)" );
}

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

function grant_bottle( amount, source_tag )
{
    if ( !isdefined( amount ) || amount <= 0 ) return;
    if ( !isdefined( self.acc_mega_bottles ) ) self.acc_mega_bottles = 0;

    self.acc_mega_bottles += amount;
    self sync_bottle_count_to_client();

    // Pickup UI (user 2026-06-24): a DEDICATED gold toast on slot 1 (the Data Shard / generic
    // toast is slot 0), so a boss kill granting a bottle WHILE a shard drop is grabbed shows BOTH
    // stacked instead of one overwriting the other. Gold matches the MEGA BOTTLES HUD counter.
    self acc_utility::hud_msg_slot( "^3+" + amount + " Empty Mega Bottle" + ( amount > 1 ? "s" : "" ) + "^7",
                                    1, ( 0.95, 0.78, 0.2 ) );
    // Pickup sound: the user's glass-cling SFX (acc_bottle_pickup -> acc\fx\glass_cling.wav).
    self PlaySound( "acc_bottle_pickup" );
}

function try_consume_bottle( player, amount )
{
    if ( !isdefined( player ) ) return false;
    if ( !isdefined( amount ) || amount <= 0 ) return false;
    if ( !isdefined( player.acc_mega_bottles ) ) return false;
    if ( player.acc_mega_bottles < amount ) return false;

    player.acc_mega_bottles -= amount;
    player sync_bottle_count_to_client();
    return true;
}

function get_bottle_count( player )
{
    if ( !isdefined( player.acc_mega_bottles ) ) return 0;
    return player.acc_mega_bottles;
}

// Check if a specific perk is Mega'd for this player. Other modules call
// this when applying perk effects to decide whether to layer on Mega deltas.
function has_mega_perk( player, specialty_string )
{
    if ( !isdefined( player ) ) return false;
    if ( !isdefined( player.acc_mega_perks ) ) return false;
    if ( !isdefined( player.acc_mega_perks[ specialty_string ] ) ) return false;
    return player.acc_mega_perks[ specialty_string ] == true;
}

// True while the player has the perk Mega'd AND still OWNS the base perk. Used for LIVE
// effects (Armory discount, Ultimate-Tank EMP immunity). The Mega flag PERSISTS across a
// down by design (re-buy re-applies, header "Mega flag stays across death"), so a bare
// has_mega_perk would keep the effect ON after a real loss. But "owns" must also count a
// perk that's only EMP-PAUSED by a boss attack (stock UnsetPerks it for 60s yet tracks
// ownership in disabled_perks) - else a bare HasPerk DROPS the effect mid-boss-fight: that
// self-defeated Ultimate-Tank immunity on the very phase it counters (and silently removed
// the Armory discount for the debuff window). owns_or_paused() handles both correctly.
function has_active_mega_perk( player, specialty_string )
{
    return has_mega_perk( player, specialty_string ) && owns_or_paused( player, specialty_string );
}

// Owns the perk right now, OR it's only EMP-paused-but-owned (stock disabled_perks set by
// perk_pause). NOT true after a genuine down/loss, so it never reintroduces the leak.
function owns_or_paused( player, specialty_string )
{
    if ( player HasPerk( specialty_string ) ) return true;
    // [acc] AVOGADRO HACK EXCLUSION (user 2026-07-06: "the actual ability for both base and mega are
    // removed" - Mega Spiderman mobility survived a Widow's hack). The paused-but-owned grace below
    // exists ONLY for the Ultimate-Tank EMP debuff window (megas should survive that boss attack); the
    // cyberhacker's machine hack is a REAL disable, so while HE has this perk down, every mega live
    // effect gated through has_active_mega_perk (spider drops, Power Surge, boss-special immunity, EMP
    // immunity, stance mobility) reads inactive. Restores automatically: unhack re-gives the base perk
    // (perk_unpause -> HasPerk true again) and the first branch takes over.
    if ( isdefined( level.acc_avo_hacked ) && IS_TRUE( level.acc_avo_hacked[ specialty_string ] ) )
        return false;
    return isdefined( player.disabled_perks ) && IS_TRUE( player.disabled_perks[ specialty_string ] );
}

// HUD predicate (perk row ONLY - _acc_lui::perk_state_watch): like owns_or_paused but ALSO true while
// the perk is merely Avogadro-hacked (stock disabled_perks still tracks the pause-ownership). The row
// must KEEP a hacked perk's icon in its slot and BLINK it - if the owned bit dropped (as owns_or_paused
// now does for gameplay gates, 2026-07-06), the icon would vanish and the whole row reflow/slide-in,
// exactly what the blink design avoids. NOT for gameplay checks - abilities must stay off while hacked.
function owns_paused_or_hacked( player, specialty_string )
{
    if ( player HasPerk( specialty_string ) ) return true;
    return isdefined( player.disabled_perks ) && IS_TRUE( player.disabled_perks[ specialty_string ] );
}

// ---------------------------------------------------------------------------
// [acc] AVOGADRO HACK bridge (user 2026-07-06: "when he disables a perk ... the actual ability for both
// base and mega are removed - check all cases"). Called by _acc_boss_avogadro::apply_hack_effect /
// apply_unhack_effect. The BASE perk is stock perk_pause/unpause; the MEGA layer splits into:
//   EVENT-TIME gates (spider drops, Power Surge, boss-special immunity, EMP immunity, Armory discount):
//     all flow through has_active_mega_perk -> owns_or_paused, which reads level.acc_avo_hacked and
//     reports the perk NOT owned while hacked - nothing to do here.
//   WATCHER gates (Savior +15% checks HasPerk live -> auto-off; Widow's stance watcher pauses itself
//     off level.acc_avo_hacked and survives the window -> auto-resume; re-applied below as backup).
//   STATEFUL effects (live in a field until recomputed): Ultimate Tank's +50 n_player_health_boost and
//     jugg's own +150 sit in max health until a health_reboot recompute - forced here both ways. The
//     Flash's +15% (acc_flash_speed, Stamin-Up mega) likewise sits in recompute_move_speed - cleared on
//     hack / re-applied on restore (Stamin-Up joined the hackable set 2026-07-06).
// ---------------------------------------------------------------------------

function on_perk_hacked( specialty )
{
    players = GetPlayers();
    for ( i = 0; i < players.size; i++ )
    {
        p = players[ i ];
        if ( !isdefined( p ) || !isplayer( p ) )
            continue;
        if ( specialty == "specialty_armorvest" )
        {
            if ( has_mega_perk( p, specialty ) )
                p.n_player_health_boost = 0;   // Ultimate Tank +50 off while jugg is hacked
            // Recompute max health from CURRENT perk state: jugg is paused (HasPerk false) -> back to 100.
            // Same health_reboot recompute apply_mega_effects uses; current health clamps to the new max.
            p zm_perks::perk_set_max_health_if_jugg( "health_reboot", true, false );
        }
        else if ( specialty == "specialty_staminup" )
        {
            // The Flash (+15% move) is STATEFUL - apply_flash_speed sets acc_flash_speed once and it rides
            // recompute_move_speed until cleared. Base Stamin-Up (engine sprint specialty) is already off
            // via perk_pause's UnsetPerk; this drops the mega half for the hack window.
            if ( IS_TRUE( p.acc_flash_speed ) )
            {
                p.acc_flash_speed = false;
                acc_utility::recompute_move_speed( p );
            }
        }
    }
}

function on_perk_restored( specialty )
{
    players = GetPlayers();
    for ( i = 0; i < players.size; i++ )
    {
        p = players[ i ];
        if ( !isdefined( p ) || !isplayer( p ) )
            continue;
        if ( specialty == "specialty_armorvest" )
        {
            if ( has_mega_perk( p, specialty ) && p HasPerk( specialty ) )
                p.n_player_health_boost = 50;  // Ultimate Tank back (only for holders the unpause re-gave)
            p zm_perks::perk_set_max_health_if_jugg( "health_reboot", true, false );
        }
        else if ( specialty == "specialty_widowswine" )
        {
            // Belt-and-suspenders: the stance watcher normally survives the hack (pause branch), but if it
            // genuinely ended during the window (e.g. the player went down and bled out mid-hack), restart
            // it for a returning holder - apply_mww_stance_speed is single-instance via its stop notify.
            if ( has_mega_perk( p, specialty ) && p HasPerk( specialty ) )
                p apply_mww_stance_speed();
        }
        else if ( specialty == "specialty_staminup" )
        {
            // The Flash back for holders the unpause re-gave the base perk to.
            if ( has_mega_perk( p, specialty ) && p HasPerk( specialty ) )
                p apply_flash_speed();
        }
    }
}

// Set the Mega flag. Called from perk-machine interaction logic once a
// Mega Bottle is consumed successfully.
function set_mega_perk( player, specialty_string )
{
    if ( !isdefined( player ) ) return;
    if ( !isdefined( specialty_string ) ) return;
    if ( !isdefined( player.acc_mega_perks ) ) player.acc_mega_perks = [];
    player.acc_mega_perks[ specialty_string ] = true;

    mega_name = mega_display_name( specialty_string );
    player iprintln( "Mega unlocked: " + mega_name );
    level notify( "acc_mega_perk_applied", player, specialty_string );

    // A Mega drink plays the perk's FULL (non-sting) jingle LOOP + the stock bottle gulp (user 2026-06-22).
    // The loop now emits 3D FROM THE PERK MACHINE - the EXACT same way a normal buy does
    // (perk_purchase_jingle_watch: acc_find_perk_machine -> machine PlaySound, static-origin fallback) - so a
    // Mega jingle stays at the machine instead of following the player (user 2026-06-24: was 2D on the buyer).
    // The old acc_mega_drink heartbeat stinger was REMOVED. Loop aliases = the sting alias + "_loop".
    sting = acc_perk_jingle_alias( specialty_string );          // acc_jingle_<perk>, or "" if unmapped
    if ( sting != "" )
    {
        machine = acc_find_perk_machine( player, specialty_string );
        if ( isdefined( machine ) )
            machine PlaySound( sting + "_loop" );   // 3D, emanates from the vending machine the player Mega'd at
        else
            acc_utility::play_sound_at_origin( player.origin, sting + "_loop" );   // fallback: STATIC at the buy spot (= the machine), never the moving player
    }
    player thread replay_perk_drink( specialty_string );
    // NOTE: the lower-left "MEGA <perk>" banner was REMOVED (user: not wanted).
    // The real ask is to glow the actual perk ICON, which the engine perk bar
    // doesn't expose to script - tracked as a separate, proper LUI task.
}

// ---------------------------------------------------------------------------
// Mega upgrade feedback: re-drink animation + glowing perk icon
// ---------------------------------------------------------------------------

// self = player. Re-play the stock perk DRINK animation (the perk's bottle
// weapon's own viewmodel) WITHOUT re-giving the perk - mirrors the stock
// vending drink flow (_zm_perks.gsc post-think) with robust switch-back.
function replay_perk_drink( perk )
{
    self endon( "disconnect" );
    self endon( "death" );

    if ( !isdefined( level._custom_perks ) || !isdefined( level._custom_perks[ perk ] )
         || !isdefined( level._custom_perks[ perk ].perk_bottle_weapon ) )
        return;

    w_bottle = level._custom_perks[ perk ].perk_bottle_weapon;

    self zm_utility::increment_is_drinking();
    self zm_utility::disable_player_move_states( true );

    original_weapon = self GetCurrentWeapon();
    self GiveWeapon( w_bottle );
    self SwitchToWeapon( w_bottle );

    self util::waittill_any_return( "weapon_change_complete", "player_downed", "death", "disconnect" );

    self zm_utility::enable_player_move_states();
    self TakeWeapon( w_bottle );

    // Variant-aware switch-back (docs/10 Mega "hidden swap"): do the recoil/fire/reload
    // twin swap WHILE the gun is holstered - reconcile() is synchronous and silent here
    // (no primary is equipped right now), so it just gives the twin / takes the base in
    // inventory. Then we re-raise the TWIN. Result: a Mega upgrade's twin swap is masked
    // by THIS drink instead of showing as a separate gun-swap-and-reload afterwards.
    // reconcile is idempotent, so the parallel apply_mega_effects poke just no-ops.
    // force=true: reconcile() now defers while is_drinking (so the stock base-perk drink
    // can't collide and eat ammo), but THIS holstered swap is our own coordinated one.
    self acc_weapon_variants::reconcile( true );
    target = original_weapon;
    if ( isdefined( original_weapon ) && original_weapon != level.weaponNone )
    {
        desired = acc_weapon_variants::resolve_held( self, original_weapon );
        if ( isdefined( desired ) && desired != level.weaponNone && self HasWeapon( desired ) )
            target = desired;
    }

    if ( isdefined( target ) && target != level.weaponNone
         && !zm_utility::is_placeable_mine( target )
         && !zm_utility::is_melee_weapon( target ) )
        self zm_weapons::switch_back_primary_weapon( target );
    else
        self zm_weapons::switch_back_primary_weapon();

    self util::waittill_any_timeout( 3, "weapon_change_complete" );
    self zm_utility::decrement_is_drinking();
}

// self = player. The bottom perk bar is engine LUI (no GSC handle), so draw our
// OWN glowing icon per Mega'd perk using the same engine perk material + a
// continuous pulse. Stacks in a row so multiple Mega'd perks don't overlap.
// The stock perk bar is engine-LUI (untouchable) and the stock
// specialty_*_zombies HUD materials are NOT in this usermap (log: "could not
// find material"). So draw a guaranteed pulsing "white" glow badge + the Mega
// name per upgraded perk, stacked at the lower-left, as the "this perk is
// Mega'd and glowing" indicator.
function add_mega_glow_icon( perk )
{
    if ( !isdefined( self.acc_mega_glow ) ) self.acc_mega_glow = [];
    if ( isdefined( self.acc_mega_glow[ perk ] ) ) return; // already glowing

    idx = self.acc_mega_glow.size;
    y = -205 - idx * 24; // stack upward, clear of the shards/bottles counters
    col = mega_perk_color( perk );

    // The stock perk bar is engine-LUI and its perk HUD materials are NOT loadable
    // in a usermap, so we can't glow the real icon. Instead draw our OWN per-perk
    // GLOWING badge: a pulsing perk-colored bar (reads as a glow, not flat text)
    // with the Mega name over it. One per Mega'd perk, stacked at the lower-left.
    s = SpawnStruct();

    s.badge = acc_utility::he_check( self hud::createIcon( "white", 162, 22 ), "mega.badge" );
    // [acc] COOP CRASH GUARD: he_check passes undefined through when the shared hudelem pool is full
    // (4p exhaustion, worsened by one badge+label PER Mega perk PER player). Field writes on undefined
    // throw. Bail without storing the struct so it retries on the next Mega refresh once the pool frees.
    if ( !isdefined( s.badge ) )
        return;
    s.badge hud::setPoint( "BOTTOM_LEFT", "BOTTOM_LEFT", 12, y );
    s.badge.alignX = "left";
    s.badge.alignY = "middle";
    s.badge.color = col;
    s.badge.alpha = 0.55;
    s.badge.sort = 4;
    s.badge.hidewheninmenu = true;
    s.badge setPulseFX( 55, 700, 700 ); // the pulse = the "glow"

    s.label = acc_utility::he_check( self hud::createFontString( "default", 1.05 ), "mega.label" );
    if ( !isdefined( s.label ) )   // [acc] COOP CRASH GUARD: drop the half-built badge, don't store the struct
    {
        s.badge Destroy();
        return;
    }
    s.label hud::setPoint( "BOTTOM_LEFT", "BOTTOM_LEFT", 20, y );
    s.label.alignX = "left";
    s.label.alignY = "middle";
    s.label.color = ( 1, 1, 1 );
    s.label.alpha = 1.0;
    s.label.sort = 5;
    s.label.hidewheninmenu = true;
    s.label SetText( "^7MEGA  " + mega_display_name( perk ) );

    self.acc_mega_glow[ perk ] = s;
}

// Per-perk signature colour for the Mega glow badge.
function mega_perk_color( perk )
{
    switch ( perk )
    {
    case "specialty_armorvest":               return ( 0.30, 0.70, 0.22 ); // Jug - green
    case "specialty_quickrevive":             return ( 0.30, 0.60, 1.00 ); // QR - blue
    case "specialty_fastreload":              return ( 0.45, 0.90, 0.45 ); // Speed - light green
    case "specialty_doubletap2":              return ( 0.90, 0.30, 0.20 ); // DT - red
    case "specialty_staminup":                return ( 0.92, 0.80, 0.20 ); // Stamin - yellow
    case "specialty_additionalprimaryweapon": return ( 0.80, 0.45, 0.20 ); // Mule - orange
    case "specialty_deadshot":                return ( 0.65, 0.72, 0.82 ); // Deadshot - steel
    case "specialty_widowswine":              return ( 0.55, 0.25, 0.65 ); // Widow's - purple
    case "specialty_electriccherry":          return ( 0.95, 0.50, 0.12 ); // PhD Flopper - orange-red
    }
    return ( 0.40, 0.85, 1.0 ); // default cyan
}

// ---------------------------------------------------------------------------
// Perk-machine Mega interaction.
//
// VERIFIED(acc): a perk owner can never fire the STOCK vending trigger -
// check_player_has_perk (_zm_perks.gsc:865-895) runs SetInvisibleToPlayer
// every 0.1s for owners, so listening on the stock trigger never sees them.
// The known-good pattern is a PARALLEL trigger_radius_use at the same origin
// (stock spawn pattern _zm_perks.gsc:1513) with INVERTED per-player
// visibility: shown only to players who own the base perk, hold a bottle,
// and haven't Mega'd it yet.
// ---------------------------------------------------------------------------

function mega_machine_watcher()
{
    level endon( "end_game" );

    // Vending triggers spawn during the stock load flow (perk __main__ +
    // perk_machine_spawn_init); poll briefly until they exist.
    triggers = [];
    for ( i = 0; i < 60; i++ )
    {
        triggers = GetEntArray( "zombie_vending", "targetname" );
        if ( triggers.size > 0 ) break;
        wait 0.5;
    }

    if ( triggers.size == 0 )
    {
        acc_utility::log( "mega: no zombie_vending triggers found, Mega upgrades unavailable" );
        return;
    }

    for ( i = 0; i < triggers.size; i++ )
    {
        level thread mega_trigger_think( triggers[ i ] );
    }
    acc_utility::log( "mega: parallel upgrade triggers on " + triggers.size + " machines" );
}

function mega_trigger_think( t_vending )
{
    level endon( "end_game" );

    perk = t_vending.script_noteworthy;
    if ( !isdefined( perk ) ) return;

    t_mega = Spawn( "trigger_radius_use", t_vending.origin, 0, 40, 80 );
    t_mega.targetname = "acc_mega_vending";
    // Back-link for the perk scatter (_acc_perk_scatter): machines relocate at
    // runtime, and this trigger is spawned at t_vending.origin but never re-reads
    // it - the scatter moves t_vending.acc_mega_trigger along with the machine.
    t_mega.acc_vending = t_vending;
    t_vending.acc_mega_trigger = t_mega;
    t_mega TriggerIgnoreTeam();
    t_mega UseTriggerRequireLookAt();
    t_mega SetCursorHint( "HINT_NOICON" );
    // Buyable-UI audit fix (2026-07-03): the hint MUST carry the PERK NAME so the Aetherium
    // cursor-hint router classifies it as a PERK prompt ("hold"+"for"+perk name) - the old
    // "Mega upgrade" wording matched nothing and fell into the wallbuy card ("WALL WEAPON").
    // PromptPerks is mega-aware: with the base perk owned it renders "MEGA: <megaName>" +
    // the mega abilities + cost 1 Mega Bottle (bottle icon). 10 bounded strings (cap-safe).
    // mega_hint_name() below MUST stay in sync with Mappings/AetheriumPerks.lua names.
    t_mega SetHintString( "Hold ^3&&1^7 for Mega " + mega_hint_name( perk ) + " [Cost: 1 Mega Bottle]" );
    t_mega thread mega_trigger_visibility( perk );

    for ( ;; )
    {
        t_mega waittill( "trigger", player );
        if ( !isdefined( player ) || !isplayer( player ) ) continue;
        if ( !( player HasPerk( perk ) ) ) continue;
        if ( has_mega_perk( player, perk ) ) continue;

        if ( try_apply_mega( player, perk ) )
        {
            t_mega PlaySound( "evt_bottle_dispense" );
        }
        wait 0.5;
    }
}

function mega_trigger_visibility( perk )
{
    level endon( "end_game" );
    self endon( "death" );

    for ( ;; )
    {
        players = GetPlayers();
        for ( i = 0; i < players.size; i++ )
        {
            p = players[ i ];
            b_show = ( p HasPerk( perk ) )
                     && !has_mega_perk( p, perk )
                     && get_bottle_count( p ) > 0;
            self SetInvisibleToPlayer( p, !b_show );
        }
        wait 0.25;
    }
}

function try_apply_mega( player, specialty_string )
{
    if ( has_mega_perk( player, specialty_string ) )
    {
        player iprintln( "Perk already Mega'd" );
        return false;
    }

    if ( !try_consume_bottle( player, 1 ) )
    {
        player iprintln( "Need 1 Empty Mega Bottle" );
        return false;
    }

    set_mega_perk( player, specialty_string );

    // Apply the Mega deltas immediately (player owns the base perk at the
    // moment of upgrade - the trigger visibility gate guarantees it).
    apply_mega_effects( player, specialty_string );

    return true;
}

// ---------------------------------------------------------------------------
// Mega effect application. Called on upgrade AND on every (re)buy of a
// Mega'd perk (sticky persistence, docs/10_perks.md). Per-perk status:
//   IMPLEMENTED here: Ultimate Tank (+50 max HP -> 300), The Flash (+15% speed),
//     Spiderman (web-grenade clip fill -> 6).
//   IMPLEMENTED elsewhere, read live from the Mega flag each frame/hit/reconcile:
//     American Sniper (headshot _acc_damage + -50% recoil twin), Gun Slinger
//     (extra-bullet damage temper eases x0.7 -> x0.9 in _acc_damage - NO twin, reworked
//     2026-07-04; was a +fire-rate/-swap "fastfire" twin), Sleight of Hand Expert
//     (+75% reload twin) via _acc_weapon_variants; The Armory (+20% round-start reserve
//     refill, ACC_ARMORY_ROUND_REFILL, runtime not a twin - was 0.35 until 2026-06-21);
//     Savior (revive speed/regen/+15% speed _acc_perks).
//   The deadshot/fastreload cases below POKE the swap engine so their twin applies instantly
//   (the axes also re-derive on the 3s reconcile safety-net); doubletap2 has NO twin (the damage
//   path reads the Mega flag live); armory calls armory_refill() (instant +20% reserve top-up -
//   the old "GiveMaxAmmo to the twin's raised cap" died with the ammo axis 2026-06-16).
// ---------------------------------------------------------------------------

function apply_mega_effects( player, specialty_string )
{
    switch ( specialty_string )
    {
    case "specialty_armorvest":
        // Ultimate Tank: +50 on top of Jug. VERIFIED(acc): n_player_health_boost is
        // the only field the stock "health_reboot" recompute adds
        // (_zm_perks.gsc:828-831), and that recompute re-runs at every revive - so
        // the bonus survives downs. A bare SetMaxHealth would be wiped by the next
        // recompute. base Jug = 125 + 125 = 250 (base 100->125 but Jug add 150->125 to KEEP Jug at 250,
        // user 2026-07-16); +50 -> 300 HP (down on the 7th @ ~45).
        player.n_player_health_boost = 50;
        player zm_perks::perk_set_max_health_if_jugg( "health_reboot", true, false );
        break;

    case "specialty_staminup":
        // The Flash: +15% uniform move speed only (docs/10 overhaul - the old
        // SetSprintDuration extension was removed).
        player apply_flash_speed();
        break;

    case "specialty_widowswine":
        // Spiderman: immunity to boss specials (_acc_boss / _acc_elites) is applied elsewhere off the
        // mega flag. (The one-hit melee was REMOVED 2026-06-29 - see the header + _acc_damage.) LOW-STANCE MOBILITY
        // (user 2026-06-26): crouch 2.6x / prone 10x / last-stand (down) 15x the normal speed of that stance,
        // via a per-player stance watcher -> player.acc_mww_stance_speed -> recompute_move_speed.
        player apply_mww_stance_speed();
        break;

    case "specialty_additionalprimaryweapon":
        // The Armory (reworked 2026-06-16): NO LONGER a maxAmmo twin. The engine clamps reserve to
        // the baked cap, so a +capacity boost required a twin - that axis was removed to free the
        // twin budget (docs/21). Armory is now a SUSTAIN perk: +20% reserve refill per carried gun
        // (ACC_ARMORY_ROUND_REFILL; was 0.35 until the 2026-06-21 nerf) at the start of every round
        // (armory_round_refill_watcher), plus this instant top-up on acquire/rebuy. The 10%-off
        // point-of-sale discount (gated on this Mega flag) is unchanged.
        player armory_refill();
        break;

    case "specialty_deadshot":
        // American Sniper: the headshot-mult layer lives in _acc_damage; the recoil half is the
        // weapon-variant swap - the SINGLE Mega-only "recoil50" twin (-50% off the 1.75x map base;
        // base Deadshot has NO recoil twin since 2026-06-16 - the old -25%/-40% tiers are gone).
        // Poke the swap engine so axis_recoil re-derives from the fresh Mega flag.
        acc_weapon_variants::request_reconcile( player );
        break;

    case "specialty_doubletap2":
        // Gun Slinger (REWORKED 2026-07-04): Mega Double Tap's ONLY effect is now a DAMAGE buff -
        // the base DT extra-bullet temper eases from x0.7 -> x0.9 (acc_doubletap_mega_dmg_mult),
        // applied live in _acc_damage::on_ai_damage via has_mega_perk. The old fire-rate/swap
        // "fastfire" weapon-variant twin was REMOVED entirely (docs/10, docs/21). There is no DT
        // twin to swap to anymore, so nothing to reconcile here - the damage path handles it live.
        break;

    case "specialty_fastreload":
        // Sleight of Hand Expert (Speed Cola Mega): +75% reload via the "fastreload"
        // weapon-variant twin (reloadTime x0.857 on top of the engine +50%, baked
        // 2026-06-14). Poke the swap engine; axis_reload reads the Mega flag live.
        // Base +50% reload + barrier repair stay pure-engine; the map-wide drink-anim
        // speedup was CUT (no per-perk lever - docs/10_perks §3).
        acc_weapon_variants::request_reconcile( player );
        break;

    case "specialty_electriccherry":
        // PhD Slider (PhD Flopper Mega): a bigger/stronger dive + down explosion. The deltas
        // (radius + damage) are read LIVE from the Mega flag in
        // _acc_perk_phd_flopper::phd_explode. ALSO: 1.75x SLIDE-gated move speed (flag ->
        // recompute_move_speed) + +15% explosive damage (read live in
        // _acc_damage::on_ai_damage via has_active_mega_perk - GSC, no weapon twin needed).
        player apply_mega_flopper_speed();
        break;

    case "specialty_combat_efficiency":
        // Electric Cherry Mega ("Power Surge") has NO instant on-acquire effect: its nova deltas (radius/targets/
        // damage/cooldown) are read LIVE off the Mega flag in _acc_perk_electric_cherry::ec_nova, and the boss-
        // special immunity is gated live in _acc_boss / _acc_elites. Explicit no-op so EC does NOT fall through to
        // the misleading "pending implementation" log below.
        break;

    case "specialty_quickrevive":
        // Quick Revive Mega ("Savior") has NO instant on-acquire effect: its deltas (regen, revive time, +15% move
        // speed, damage reduction) are all read LIVE off the Mega flag in _acc_perks.gsc via has_mega_perk(...,
        // "specialty_quickrevive"). Explicit no-op so Savior does NOT fall through to the "pending implementation" log.
        break;

    default:
        acc_utility::log( "mega effect pending implementation: " + specialty_string );
        break;
    }
}

function apply_flash_speed()
{
    // VERIFIED(acc): SetMoveSpeedScale is ABSOLUTE - read-modify-write here
    // gets erased by other writers (Neural Boots hook, Reflex T1). Set the
    // flag and recompute through the single owner in acc_utility.
    self.acc_flash_speed = true;
    acc_utility::recompute_move_speed( self );
}

// Mega Flopper (PhD Slider) = 1.75x SLIDE speed (user 2026-07-05, was 1.5x/1.35x; stacks with the Rocket Shield's
// own 1.75x slide boost - combined clamps to the 2.2x move cap). Slide-GATED, not always-on: a per-player watcher sets acc_mega_flopper_speed
// only while you're actually sliding (IsSliding, mirrors _acc_boss_items::rocket_shield_watch),
// recomputing through acc_utility's single owner. Single-instance via the stop notify (no
// stacking on re-acquire / respawn re-apply).
function apply_mega_flopper_speed()
{
    self notify( "acc_mega_flopper_watch_stop" );
    self.acc_mega_flopper_speed = false;
    self thread mega_flopper_slide_watch();
    if ( IS_TRUE( level.acc_dev ) ) self iprintln( "^5PhD Slider: slide-watcher STARTED" );
}

function mega_flopper_slide_watch()    // self = player
{
    self endon( "disconnect" );
    self endon( "acc_mega_flopper_watch_stop" );

    sliding = false;
    for ( ;; )
    {
        wait( 0.05 );

        // Stop (and clear) only on a GENUINE loss (downed-out / round loss).
        //
        // has_active_mega_perk, NOT a bare HasPerk (BUG FIX 2026-07-15, found by the full-code
        // audit; two independent finders + the pattern this file already documents). A bare
        // HasPerk is FALSE for the whole 60s boss EMP window (_acc_boss::disable_perks_for ->
        // zm_perks::perk_pause_all_perks -> UnsetPerk on every owner), so the watcher hit this
        // `return` and DIED PERMANENTLY: the 1.75x slide speed never came back for the rest of
        // the run (only a respawn restarts it, via the spawn re-apply gate at :190). That also
        // contradicted the design - Megas are SUPPOSED to survive the EMP debuff (see
        // owns_or_paused: "paused-but-owned" reads as owned precisely so megas ride out that
        // boss attack). has_active_mega_perk = has_mega_perk && owns_or_paused, which stays
        // TRUE while EMP-paused-but-owned and goes false only on a real loss. Mirrors
        // mww_stance_speed_watch, the watcher that already got this right.
        if ( !has_active_mega_perk( self, "specialty_electriccherry" ) )
        {
            if ( sliding )
            {
                self.acc_mega_flopper_speed = false;
                acc_utility::recompute_move_speed( self );
            }
            if ( IS_TRUE( level.acc_dev ) ) self iprintln( "^1PhD Slider: watcher STOPPED (no perk or not Mega'd)" );
            return;
        }

        // THE FLAG IS SLIDE-ONLY ON PURPOSE - DO NOT ADD A GRACE WINDOW OR A RELEASE RAMP
        // HERE (both tried + rejected on feel 2026-07-15: a SetMoveSpeedScale flag held past
        // the slide just makes you WALK at 1.75x, which reads as ice). The slide-JUMP
        // momentum carry is a VELOCITY mechanic owned globally by _acc_movement.gsc for
        // every player - it records ACTUAL velocity, so this 1.75x is already baked into
        // what it preserves, with no wiring here. Full rationale: _acc_movement.gsc header.
        now_slide = ( self IsSliding() && self IsOnGround() );
        if ( now_slide != sliding )
        {
            sliding = now_slide;
            self.acc_mega_flopper_speed = now_slide;   // 1.75x via recompute_move_speed
            acc_utility::crash_log( self, "mega_flopper_slide_watch: slide " + ( now_slide ? "ON" : "off" ) );
            acc_utility::recompute_move_speed( self );
            if ( IS_TRUE( level.acc_dev ) )
            {
                if ( now_slide ) self iprintln( "^2PhD Slider: SLIDE BOOST ON (x" + getdvarfloat( "acc_mega_flopper_slide_mult", 1.75 ) + ")" );
                else self iprintln( "^7PhD Slider: slide boost off" );
            }
        }
    }
}

// ---------------------------------------------------------------------------
// Mega Widow's Wine - LOW-STANCE mobility (user 2026-06-25)
//
// A Mega-Widow's holder moves dramatically faster WHILE LOW: crouch 2.6x / prone 10x / last-stand (down) 15x
// the normal speed of THAT stance (crouch retuned 2.2->2.6 user 2026-06-26). "Baseline is the speed for each stance" - so two
// players in the SAME stance, the Mega-Widow's one moves N times faster (it MULTIPLIES the shared move scale,
// it doesn't just add a fixed bonus). Standing = no bonus.
//
// MECHANISM (the only player move lever is the single overall SetMoveSpeedScale, which scales the CURRENT
// stance's speed): a per-player watcher reads GetStance() + .laststand and stores the factor in
// player.acc_mww_stance_speed; acc_utility::recompute_move_speed multiplies it in (after the base cap, so the
// 2.6x/10x/15x survive - the final clamp acc_mww_speed_cap was raised to 16 to fit the 15x down). Mirrors
// apply_mega_flopper_speed / mega_flopper_slide_watch. Single-instance via the stop notify (no stacking on
// re-acquire / respawn re-apply); started on acquire AND each respawn.
//
// DOWN-OWNERSHIP (the user's "they lost the perk when they went down" ask, user 2026-06-25): going into last
// stand makes the engine report Mega Widow's as LOST, so a live HasPerk check would kill the crawl speed the
// instant you go down. Fix: the watcher SNAPSHOTS legit ownership every tick while UP into player
// .acc_mww_down_owner, and mww_stance_factor's last-stand branch gates the 15x on THAT snapshot - so a downed
// holder keeps the crawl speed through the whole bleed-out, no matter what HasPerk reports.
//
// NOTE (verify in-game): SetMoveSpeedScale reliably scales crouch/prone. The DOWN (last-stand crawl) 15x is
// the uncertain one - if the engine doesn't apply the move scale to the laststand crawl, that part is a no-op
// (there's no other GSC crawl-speed lever); crouch/prone are unaffected by that caveat.
// ---------------------------------------------------------------------------

function apply_mww_stance_speed()   // self = player
{
    self notify( "acc_mww_stance_watch_stop" );
    self.acc_mww_stance_speed = 1.0;
    self thread mww_stance_speed_watch();
}

function mww_stance_speed_watch()   // self = player
{
    self endon( "disconnect" );
    self endon( "acc_mww_stance_watch_stop" );

    last = 1.0;
    self.acc_mww_stance_speed = 1.0;
    for ( ;; )
    {
        // [acc] AVOGADRO HACK PAUSE (user 2026-07-06): while the cyberhacker has Widow's Wine disabled the
        // stance mobility must drop with it, but the WATCHER must survive the window - the genuine-loss
        // stop below `return`s, and on restore only on_perk_restored could restart it. Zero the factor,
        // idle, resume automatically when the machine comes back.
        if ( isdefined( level.acc_avo_hacked ) && IS_TRUE( level.acc_avo_hacked[ "specialty_widowswine" ] ) )
        {
            if ( last != 1.0 )
            {
                last = 1.0;
                self.acc_mww_stance_speed = 1.0;
                acc_utility::recompute_move_speed( self );
            }
            wait( 0.25 );
            continue;
        }

        // OWNERSHIP SNAPSHOT for the DOWN case (user 2026-06-25): while UP (HasPerk reliable), record whether
        // we LEGITIMATELY hold active Mega Widow's. mww_stance_factor's last-stand branch reads THIS snapshot,
        // NOT HasPerk - because going into last stand makes the engine report the perk as "lost" (and a real
        // bleed-out clears it), which would drop the crawl speed exactly when we want it. Only updated while
        // UP, so the moment you go down it FREEZES at the last up-state value (= did you own it going down).
        if ( !IS_TRUE( self.laststand ) )
            self.acc_mww_down_owner = has_active_mega_perk( self, "specialty_widowswine" );

        // Stop (and clear) only when the perk is GENUINELY gone - NOT merely while downed (a downed holder
        // must still get the crawl speed). The laststand bypass keeps the watcher alive through a down; it
        // ends only on a real loss while UP (then the respawn re-apply gate restarts it if you re-own it).
        if ( !has_active_mega_perk( self, "specialty_widowswine" ) && !IS_TRUE( self.laststand ) )
        {
            self.acc_mww_down_owner = false;
            if ( last != 1.0 )
            {
                self.acc_mww_stance_speed = 1.0;
                acc_utility::recompute_move_speed( self );
            }
            return;
        }

        want = mww_stance_factor( self );
        if ( want != last )
        {
            last = want;
            self.acc_mww_stance_speed = want;
            acc_utility::recompute_move_speed( self );
        }
        wait( 0.05 );
    }
}

// The per-stance move-speed factor for a Mega-Widow's holder. All live-tunable.
function mww_stance_factor( player )
{
    // DOWN (last stand) FIRST: gate the crawl speed on the OWNERSHIP SNAPSHOT (acc_mww_down_owner, captured
    // by the watcher every tick while UP), NOT on HasPerk - you lose the perk the instant you go down, so a
    // live perk check would always read false here and the crawl speed would never apply. The snapshot is the
    // "did I legitimately own Mega Widow's at the moment I went down" marker (user 2026-06-25).
    if ( IS_TRUE( player.laststand ) )
        return ( IS_TRUE( player.acc_mww_down_owner ) ? getdvarfloat( "acc_mww_down_speed", 15.0 ) : 1.0 );
    if ( !has_active_mega_perk( player, "specialty_widowswine" ) )
        return 1.0;
    stance = player GetStance();
    if ( stance == "prone" )  return getdvarfloat( "acc_mww_prone_speed", 10.0 );
    if ( stance == "crouch" ) return getdvarfloat( "acc_mww_crouch_speed", 2.6 );
    return 1.0;   // standing = no bonus
}

// The Armory Mega (Mule Kick), reworked 2026-06-16: a SUSTAIN refill, NOT a capacity boost.
// Adds +20% (ACC_ARMORY_ROUND_REFILL) of each carried gun's reserve CAP to its current reserve,
// clamped to the cap. This is runtime-legal (filling toward the existing baked cap, never above it
// - the reason the old +25%-capacity needed a maxAmmo twin, now removed). Called once on
// acquire/rebuy (instant top-up) and every round start (armory_round_refill_watcher). Applies to
// all carried guns + the equipped weapon (the pistol slot isn't always in GetWeaponsListPrimaries).
// weapon.maxammo = reserve cap in rounds (_zm_weapons:2935). self = player.
function armory_refill()
{
    // [acc] NO endon("disconnect"): called inline from the LEVEL thread armory_round_refill_watcher
    // (and the acquire path), so an endon would bind to that shared thread and permanently kill
    // round-start refills for the WHOLE lobby the moment any Armory-Mega holder disconnects. This
    // function has no wait, so the endon protected nothing anyway - a simple validity guard is enough.
    if ( !isdefined( self ) || !isplayer( self ) )
        return;

    guns = self GetWeaponsListPrimaries();

    eq = self GetCurrentWeapon();
    if ( isdefined( eq ) && eq != level.weaponNone )
    {
        have = false;
        for ( i = 0; i < guns.size; i++ ) { if ( guns[ i ] == eq ) have = true; }
        if ( !have ) guns[ guns.size ] = eq;
    }

    for ( i = 0; i < guns.size; i++ )
    {
        g = guns[ i ];
        if ( !isdefined( g ) || g == level.weaponNone ) continue;
        if ( !( self HasWeapon( g ) ) ) continue;
        if ( !isdefined( g.maxammo ) ) continue;

        cur = self GetWeaponAmmoStock( g );
        if ( !isdefined( cur ) ) continue;

        // KNOWN MINOR ISSUE (2026-06-21): g.maxammo reads as MAGAZINES (not rounds) for the akimbo
        // PaP forms (s1_pdw_rdw_up / s2_m1911_rdw_up) - the same quirk fixed in the PaP transform
        // (_acc_pap_levels::acc_do_transform) - so the refill on a packed PDW/M1911 is tiny. Single-
        // wield guns are correct (maxammo = rounds). Low impact; left as-is pending a robust akimbo cap.
        add = int( g.maxammo * ACC_ARMORY_ROUND_REFILL );   // +20% of the reserve cap
        target = cur + add;
        if ( target > g.maxammo ) target = g.maxammo;       // never exceed the baked cap
        if ( target > cur ) self SetWeaponAmmoStock( g, target );
    }
}

// Round-start +20% reserve refill for every Armory (Mule Kick Mega) holder. Wakes on the
// map's "acc_round_start" event.
function armory_round_refill_watcher()
{
    level endon( "end_game" );

    for ( ;; )
    {
        level waittill( "acc_round_start" );

        players = GetPlayers();
        for ( i = 0; i < players.size; i++ )
        {
            p = players[ i ];
            if ( !isdefined( p ) || !isplayer( p ) ) continue;
            if ( !( p HasPerk( "specialty_additionalprimaryweapon" ) ) ) continue;
            if ( !has_mega_perk( p, "specialty_additionalprimaryweapon" ) ) continue;
            p armory_refill();
        }
    }
}

// Stock lifecycle hooks (self = player).

function on_perk_bought( perk )
{
    // NOTE: the perk-buy JINGLE is NOT played here. perk_bought_func fires AFTER the drink
    // (post weapon_change_complete) and is player-2D, so it felt delayed + followed the buyer.
    // It now plays the instant points are deducted, ON the vending machine (3D) - see
    // perk_purchase_jingle_watch() driven by the stock "perk_purchased" notify.

    if ( has_mega_perk( self, perk ) )
    {
        apply_mega_effects( self, perk );
    }

    // Deadshot's recoil reduction applies at the BASE tier (-25%) too, so the
    // variant twin must reconcile on any (re)buy, not just on Mega. Double Tap has
    // NO twin anymore (fast-fire removed 2026-07-04 - Mega DT is a damage buff in
    // _acc_damage), so its poke here is a harmless no-op; kept for symmetry.
    if ( perk == "specialty_deadshot" || perk == "specialty_doubletap2" )
    {
        acc_weapon_variants::request_reconcile( self );
    }
    // NOTE: an earlier on-buy replay_perk_drink() was REVERTED (user 2026-06-22): giving/switching to the
    // bottle weapon AFTER the stock buy's own drink caused a double weapon-swap that made perks need
    // buying TWICE. The perk-drink SOUND is handled separately (a direct PlayLocalSound, not a re-drink).
}

// specialty -> per-perk jingle sting alias (the ZombiePerkJingles pack, converted to 48k WAV by
// ffmpeg). "" = no jingle. Specialty keys VERIFIED(acc) vs _acc_perk_lights::perk_color_index
// (Double Tap = specialty_doubletap2, Stamin-Up = specialty_staminup, PhD = specialty_electriccherry
// on this map). Add a row in acc_audio.csv when a new perk is added.
function acc_perk_jingle_alias( perk )
{
    switch ( perk )
    {
        case "specialty_armorvest":               return "acc_jingle_jugg";       // Juggernog
        case "specialty_fastreload":              return "acc_jingle_speed";      // Speed Cola
        case "specialty_doubletap2":              return "acc_jingle_doubletap";  // Double Tap
        case "specialty_staminup":                return "acc_jingle_stamin";     // Stamin-Up
        case "specialty_additionalprimaryweapon": return "acc_jingle_mulekick";   // Mule Kick
        case "specialty_quickrevive":             return "acc_jingle_revive";     // Quick Revive
        case "specialty_deadshot":                return "acc_jingle_deadshot";   // Deadshot
        case "specialty_widowswine":              return "acc_jingle_widows";     // Widow's Wine
        case "specialty_electriccherry":          return "acc_jingle_phd";        // PhD Flopper
        case "specialty_combat_efficiency":       return "acc_jingle_cherry";     // Electric Cherry - REAL jingle (Elemental Pop Sting, our own; jingle_cherry.wav @48k, acc_audio.csv, game-closed sound build 2026-06-25)
        default:                                  return "";
    }
}

// Watches the stock "perk_purchased" notify - fired by vending_trigger_think the INSTANT points are
// deducted, BEFORE the drink animation (verified vs stock _zm_perks.gsc:605) - and plays that perk's
// jingle ON the vending machine (3D), not on the buyer. Threaded per player from on_player_connect.
function perk_purchase_jingle_watch()
{
    self endon( "disconnect" );

    for ( ;; )
    {
        self waittill( "perk_purchased", perk );

        jingle = acc_perk_jingle_alias( perk );
        if ( jingle == "" ) continue;

        machine = acc_find_perk_machine( self, perk );
        if ( isdefined( machine ) )
            machine PlaySound( jingle );   // 3D, emanates from the vending machine the player bought at
        else
            acc_utility::play_sound_at_origin( self.origin, jingle );   // fallback: STATIC at the buy spot (= the machine), never the moving player (user 2026-06-24: 3D jingle was following the buyer)
    }
}

// The zombie_vending machine of <perk> nearest the buyer = the one they just used. Returns its
// renderable .machine ent (the 3D sound source). Same handles _acc_perk_lights uses: zombie_vending
// triggers carry script_noteworthy = specialty + .machine = the vending model (perk_machine_spawn_init).
function acc_find_perk_machine( player, perk )
{
    triggers = GetEntArray( "zombie_vending", "targetname" );
    best = undefined;
    best_d = 999999999;
    foreach ( t in triggers )
    {
        if ( !isdefined( t.machine ) ) continue;
        if ( isdefined( perk ) && isdefined( t.script_noteworthy ) && t.script_noteworthy != perk ) continue;
        d = DistanceSquared( player.origin, t.machine.origin );
        if ( d < best_d ) { best_d = d; best = t.machine; }
    }
    return best;
}

function on_perk_lost( perk )
{
    // Remove the Mega glow badge for the lost perk.
    if ( isdefined( self.acc_mega_glow ) && isdefined( self.acc_mega_glow[ perk ] ) )
    {
        g = self.acc_mega_glow[ perk ];
        if ( isdefined( g.badge ) ) { g.badge hud::destroyElem(); acc_utility::he_free( 1 ); }
        if ( isdefined( g.label ) ) { g.label hud::destroyElem(); acc_utility::he_free( 1 ); }
        self.acc_mega_glow[ perk ] = undefined;
    }

    if ( perk == "specialty_armorvest" )
    {
        // Next health_reboot recompute drops the Ultimate Tank bonus.
        self.n_player_health_boost = 0;
    }

    if ( perk == "specialty_staminup" && IS_TRUE( self.acc_flash_speed ) )
    {
        self.acc_flash_speed = false;
        acc_utility::recompute_move_speed( self );
    }

    if ( perk == "specialty_deadshot" || perk == "specialty_doubletap2"
         || perk == "specialty_fastreload" || perk == "specialty_additionalprimaryweapon" )
    {
        // Strip the recoil / fastreload twin back to the base weapon (fastfire/ammo axes
        // are gone). reconcile re-derives from the (now-removed) perk, so the twin is undone.
        // (doubletap2 is kept in the guard but is a no-op for twins now - Mega DT is a damage
        // buff in _acc_damage, no twin; the reconcile is harmless/idempotent.)
        acc_weapon_variants::request_reconcile( self );
    }
}

// ---------------------------------------------------------------------------
// Display names for Mega variants (docs/10_perks.md source of truth).
// ---------------------------------------------------------------------------

function mega_display_name( specialty_string )
{
    switch ( specialty_string )
    {
    case "specialty_armorvest":              return "Ultimate Tank";         // Jug
    case "specialty_quickrevive":            return "Savior";                 // QR
    case "specialty_fastreload":             return "Sleight of Hand Expert"; // Speed Cola
    // VERIFIED(acc): stock ZM specialty strings from _zm_perks.gsh:26-27
    // (the old specialty_rof/specialty_longersprint never match in ZM).
    case "specialty_doubletap2":             return "Gun Slinger";            // Double Tap
    case "specialty_staminup":               return "The Flash";              // Stamin-Up
    case "specialty_additionalprimaryweapon":return "The Armory";             // Mule Kick
    // VERIFIED(acc): these are the specialties our machines actually register:
    // Deadshot + Widow's Wine are the stock modules (_zm_perks.gsh:29/:35);
    // PhD Flopper hijacks the stock electric-cherry pipeline (see
    // _acc_perk_phd_flopper.gsc).
    case "specialty_deadshot":               return "American Sniper";        // Deadshot
    case "specialty_widowswine":             return "Spiderman";              // Widow's Wine
    case "specialty_electriccherry":         return "PhD Slider";             // PhD Flopper
    case "specialty_combat_efficiency":      return "Power Surge";            // Electric Cherry (real 10th perk) - was falling through to "Mega Perk" (fixed 2026-06-26)
    }
    return "Mega Perk";
}

// (The entire Spiderman web-grenade VIRTUAL POOL was REMOVED 2026-06-24 per user: acc_web_pool_max,
// acc_web_refill_clip, web_grenade_pool_watcher, web_grenade_manage_watcher, and the "WEB GRENADES" HUD
// counter sync_web_grenades_to_client are all gone. Mega Widow's now uses STOCK web-grenade behavior.)

// ---------------------------------------------------------------------------
// HUD sync
// ---------------------------------------------------------------------------

function sync_bottle_count_to_client()
{
    if ( !isdefined( self.acc_mega_bottles ) ) self.acc_mega_bottles = 0;
    // Top-left MEGA BOTTLES readout RECLAIMED (user 2026-06-27): it was hidden (alpha 0) - the SQUAD roster shows
    // the count now - but a HIDDEN server hudelem STILL occupies a slot in the SHARED, fixed per-client pool.
    // Freeing it makes room for the roster's one-row "points SH EXO MB" stats line without overflowing the
    // ~31/client pool in 4-player co-op (memory server-hudelem-pool-exhaustion-coop). The count lives in
    // self.acc_mega_bottles; the roster (_acc_health_bars::update_roster) reads it directly - nothing visible lost.
}

// Specialty -> display name for the Mega-upgrade machine hint (buyable-UI audit 2026-07-03).
// MUST match ui/uieditor/widgets/HUD/Mappings/AetheriumPerks.lua `name` fields - the Aetherium
// cursor-hint router word-matches these to pick the PERK prompt, and PromptPerks resolves the
// same record for the mega card. Bounded (10 strings) - triggerstring-cap safe.
function mega_hint_name( perk )
{
    switch ( perk )
    {
        case "specialty_armorvest":               return "Jugger-Nog";
        case "specialty_quickrevive":             return "Quick Revive";
        case "specialty_fastreload":              return "Speed Cola";
        case "specialty_doubletap2":              return "Double Tap";
        case "specialty_staminup":                return "Stamin-Up";
        case "specialty_additionalprimaryweapon": return "Mule Kick";
        case "specialty_deadshot":                return "Deadshot";
        case "specialty_widowswine":              return "Widow's Wine";
        case "specialty_electriccherry":          return "PhD Flopper";
        case "specialty_combat_efficiency":       return "Electric Cherry";
    }
    return "upgrade";
}
