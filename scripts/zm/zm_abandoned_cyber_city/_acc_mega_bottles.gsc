// =============================================================================
// _acc_mega_bottles.gsc - Empty Mega Bottle acquisition + perk-Mega upgrades
//
// Design reference: docs/13_perks.md (Mega Bottles system + Perk reference base/Mega).
//
// Acquisition: 1 bottle guaranteed per player on EVERY boss kill (mini + full).
// Usage: at a Lab perk machine currently dispensing a perk the player owns,
// consume 1 bottle to flag that perk as Mega'd on self.acc_mega_perks.
// Persistence: Mega flag stays across death (player re-buys perk -> re-apply).
// =============================================================================

#using scripts\shared\array_shared;
#using scripts\shared\hud_util_shared;
#using scripts\shared\util_shared;

#insert scripts\shared\shared.gsh;

#using scripts\zm\_zm_perks;
#using scripts\zm\_zm_score;
#using scripts\zm\_zm_utility;
#using scripts\zm\_zm_weapons;

#using scripts\zm\zm_abandoned_cyber_city\_acc_utility;
#using scripts\zm\zm_abandoned_cyber_city\_acc_weapon_variants;

// Spiderman Mega (Widow's): hold up to 6 web grenades, restock 4 each round
// (base Widow restocks 2). The Armory Mega (Mule): -10% on every point purchase.
#define ACC_SPIDERMAN_WEB_GRENADES   6
#define ACC_SPIDERMAN_ROUND_RESTOCK  4
#define ACC_WIDOW_BASE_ROUND_RESTOCK 2

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
    // Re-buying a Mega'd perk re-applies its deltas (docs/13 persistence rule).
    level.perk_bought_func = &on_perk_bought;
    level.perk_lost_func = &on_perk_lost;

    level thread mega_machine_watcher();
    level thread armory_maxammo_watcher();
    level thread widow_round_restock_watcher();
}

function on_player_connect( player )
{
    player.acc_mega_bottles = 0;
    // Per-perk Mega flags. Key = specialty string (e.g. "specialty_armorvest");
    // Value = true if Mega'd. Persists through death for the run.
    player.acc_mega_perks = [];
    player sync_bottle_count_to_client();
    player thread flash_respawn_watcher();
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
        wait 0.25; // after the spawn-path speed reset
        if ( self HasPerk( "specialty_staminup" )
             && has_mega_perk( self, "specialty_staminup" ) )
        {
            self apply_flash_speed();
        }
    }
}

// The Armory Mega (Mule Kick) "all buys 10% cheaper" is POINT OF SALE (charge AND
// shown price). Overriding stock cost files from a usermap does NOT work (verified
// 2026-06-14: base game wins), so the discount is applied from OUR side by setting
// each machine's own cost field + hint to the discounted value for a nearby Armory
// holder: PERKS in _acc_perk_info::armory_perk_pricing, PaP tier-up in
// _acc_pap_levels::acc_do_tier_up. (Box display/charge + PaP first-pack: TODO.)

// Widow's Wine grenade round-restock: base perk tops the web-grenade clip to 2 at
// the start of each round; the Spiderman Mega tops it to 4 (docs/13). Restock =
// "ensure at least N", never reduces a higher count. Spiderman's actual max-cap
// fill is force_spiderman_web_capacity(), called on Mega apply/re-apply.
function widow_round_restock_watcher()
{
    level endon( "end_game" );

    for ( ;; )
    {
        level waittill( "acc_round_start" );
        if ( !isdefined( level.w_widows_wine_grenade ) ) continue;

        players = GetPlayers();
        for ( i = 0; i < players.size; i++ )
        {
            p = players[ i ];
            if ( !isdefined( p ) || !isplayer( p ) ) continue;
            if ( !( p HasPerk( "specialty_widowswine" ) ) ) continue;
            if ( !( p HasWeapon( level.w_widows_wine_grenade ) ) ) continue;

            target = ( has_mega_perk( p, "specialty_widowswine" ) ? ACC_SPIDERMAN_ROUND_RESTOCK : ACC_WIDOW_BASE_ROUND_RESTOCK );
            cur = p GetWeaponAmmoClip( level.w_widows_wine_grenade );
            if ( !isdefined( cur ) || cur < target )
                p SetWeaponAmmoClip( level.w_widows_wine_grenade, target );
        }
    }
}

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

    self iprintln( "+" + amount + " Empty Mega Bottle" +
                   ( amount > 1 ? "s" : "" ) );
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
    return isdefined( player.disabled_perks ) && IS_TRUE( player.disabled_perks[ specialty_string ] );
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

    // Re-play the perk drink animation (the bottle is the Mega upgrade).
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

    // Variant-aware switch-back (docs/13 Mega "hidden swap"): do the recoil/fire/reload
    // twin swap WHILE the gun is holstered - reconcile() is synchronous and silent here
    // (no primary is equipped right now), so it just gives the twin / takes the base in
    // inventory. Then we re-raise the TWIN. Result: a Mega upgrade's twin swap is masked
    // by THIS drink instead of showing as a separate gun-swap-and-reload afterwards.
    // reconcile is idempotent, so the parallel apply_mega_effects poke just no-ops.
    self acc_weapon_variants::reconcile();
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

    s.badge = self hud::createIcon( "white", 162, 22 );
    s.badge hud::setPoint( "BOTTOM_LEFT", "BOTTOM_LEFT", 12, y );
    s.badge.alignX = "left";
    s.badge.alignY = "middle";
    s.badge.color = col;
    s.badge.alpha = 0.55;
    s.badge.sort = 4;
    s.badge.hidewheninmenu = true;
    s.badge setPulseFX( 55, 700, 700 ); // the pulse = the "glow"

    s.label = self hud::createFontString( "default", 1.05 );
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
    case "specialty_electriccherry":          return ( 0.95, 0.50, 0.12 ); // Aura - orange-red
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
    t_mega TriggerIgnoreTeam();
    t_mega UseTriggerRequireLookAt();
    t_mega SetCursorHint( "HINT_NOICON" );
    // TODO(acc-verify): raw-string hint (community-standard but unverified
    // against our toolchain; stock uses precached istrings). If blank on
    // first compile, precache a triggerstring instead.
    t_mega SetHintString( "Hold ^3&&1^7 for Mega upgrade [Cost: 1 Mega Bottle]" );
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
// Mega'd perk (sticky persistence, docs/13_perks.md). Per-perk status:
//   IMPLEMENTED here: Ultimate Tank (+64 max HP -> 314), The Flash (+15% speed),
//     Spiderman (web-grenade clip fill -> 6), The Armory (reserve fill).
//   IMPLEMENTED elsewhere, read live from the Mega flag each frame/hit/reconcile:
//     American Sniper (x2.0 headshot _acc_damage + -70% recoil twin), Gun Slinger
//     (+50% fire rate + -75% swap twin), Sleight of Hand Expert (+70% reload twin)
//     - all three twins via _acc_weapon_variants (baked 2026-06-14); Savior (revive
//     speed/regen/+15% speed _acc_perks), Mega Man (800u/60s/2 charges _acc_perk_aura_blast).
//   The deadshot/doubletap2/fastreload cases below just POKE the swap engine so the
//   twin applies instantly; the axes also re-derive on the 3s reconcile safety-net.
// ---------------------------------------------------------------------------

function apply_mega_effects( player, specialty_string )
{
    switch ( specialty_string )
    {
    case "specialty_armorvest":
        // Ultimate Tank: docs/13 = 314 HP. VERIFIED(acc): n_player_health_boost is
        // the only field the stock "health_reboot" recompute adds
        // (_zm_perks.gsc:828-831), and that recompute re-runs at every revive - so
        // the bonus survives downs. A bare SetMaxHealth would be wiped by the next
        // recompute. base Jug = 100 + 150 = 250; +64 -> 314 HP (down on the 7th @ ~45).
        player.n_player_health_boost = 64;
        player zm_perks::perk_set_max_health_if_jugg( "health_reboot", true, false );
        break;

    case "specialty_staminup":
        // The Flash: +15% uniform move speed only (docs/13 overhaul - the old
        // SetSprintDuration extension was removed).
        player apply_flash_speed();
        break;

    case "specialty_widowswine":
        // Spiderman: set the owned web-grenade stack to its Mega max capacity.
        // Round-start restock remains 4 and is handled by widow_round_restock_watcher.
        player force_spiderman_web_capacity();
        break;

    case "specialty_additionalprimaryweapon":
        // The Armory (docs/13 overhaul): +25% gun ammo capacity (GDT cap; GSC fills
        // every gun's reserve to it) + all buys 10% cheaper (POINT OF SALE, in the
        // vendored stock cost files via the repurposed pers double-points hook gated
        // on this Mega flag). Fill the reserves now.
        player armory_apply();
        break;

    case "specialty_deadshot":
        // American Sniper: the headshot-mult layer (x2.0) lives in _acc_damage; the
        // -70% recoil half is the weapon-variant swap (base Deadshot is -35%, off the
        // 2.5x map base). Poke the swap engine to upgrade base->Mega recoil twin
        // (baked 2026-06-14, docs/perk_abilities §7 / docs/30 §4).
        acc_weapon_variants::request_reconcile( player );
        break;

    case "specialty_doubletap2":
        // Gun Slinger: +50% fire rate AND -75% weapon-swap via the "fastfire"
        // weapon-variant twin (baked 2026-06-14, docs/30 §5). Poke the swap engine;
        // axis_fire reads the Mega flag live. (Double Tap 1.0 is rate-only - the old
        // +6% damage layer was removed from _acc_damage.)
        acc_weapon_variants::request_reconcile( player );
        break;

    case "specialty_fastreload":
        // Sleight of Hand Expert (Speed Cola Mega): +70% reload via the "fastreload"
        // weapon-variant twin (reloadTime x0.882 on top of the engine +50%, baked
        // 2026-06-14). Poke the swap engine; axis_reload reads the Mega flag live.
        // Base +50% reload + barrier repair stay pure-engine; the map-wide drink-anim
        // speedup was CUT (no per-perk lever - docs/perk_abilities §3).
        acc_weapon_variants::request_reconcile( player );
        break;

    case "specialty_electriccherry": // Mega Man - live in _acc_perk_aura_blast
        break;

    default:
        acc_utility::log( "mega effect pending implementation: " + specialty_string );
        break;
    }
}

// self = player. Spiderman's max capacity is 6 web grenades, carried in the
// lethal clip. This is intentionally a max-cap fill, not a passive loop, so
// throwing grenades still spends them normally.
function force_spiderman_web_capacity()
{
    if ( !isdefined( level.w_widows_wine_grenade ) ) return;
    if ( !( self HasWeapon( level.w_widows_wine_grenade ) ) ) return;

    self SetWeaponAmmoClip( level.w_widows_wine_grenade, ACC_SPIDERMAN_WEB_GRENADES );
}

function apply_flash_speed()
{
    // VERIFIED(acc): SetMoveSpeedScale is ABSOLUTE - read-modify-write here
    // gets erased by other writers (Neural Boots hook, Reflex T1). Set the
    // flag and recompute through the single owner in acc_utility.
    self.acc_flash_speed = true;
    acc_utility::recompute_move_speed( self );
}

// The Armory Mega (Mule Kick) +25% ammo capacity (docs/13 overhaul): the weapon
// GDT raises each gun's reserve maxAmmo by 25%; GiveMaxAmmo fills every carried
// gun's reserve to that (raised) cap. On stock GDTs it is a harmless full top-off.
// Idempotent - safe on Mega-apply, perk rebuy, and every Max Ammo. (The former
// +2-grenade fill was removed - Armory no longer touches grenades.)
function armory_apply()
{
    self endon( "disconnect" );

    guns = self GetWeaponsListPrimaries();
    for ( i = 0; i < guns.size; i++ )
    {
        g = guns[ i ];
        if ( !isdefined( g ) || g == level.weaponNone ) continue;
        if ( !( self HasWeapon( g ) ) ) continue;
        self GiveMaxAmmo( g );
    }
}

// Re-apply the Armory top-off whenever a Max Ammo powerup fires, for any player
// who has Mega'd Mule Kick (so the raised grenade caps get filled on every Max
// Ammo, not just at upgrade time).
function armory_maxammo_watcher()
{
    level endon( "end_game" );

    for ( ;; )
    {
        level waittill( "zmb_max_ammo_level" );
        players = GetPlayers();
        for ( i = 0; i < players.size; i++ )
        {
            p = players[ i ];
            if ( !isdefined( p ) || !isplayer( p ) ) continue;
            if ( !( p HasPerk( "specialty_additionalprimaryweapon" ) ) ) continue;
            if ( !has_mega_perk( p, "specialty_additionalprimaryweapon" ) ) continue;
            p armory_apply();
        }
    }
}

// Stock lifecycle hooks (self = player).

function on_perk_bought( perk )
{
    if ( has_mega_perk( self, perk ) )
    {
        apply_mega_effects( self, perk );
    }

    // Deadshot's recoil reduction applies at the BASE tier (-25%) too, so the
    // variant twin must reconcile on any (re)buy, not just on Mega. Double Tap's
    // fast-fire is Mega-only but a re-buy poke is harmless. (Reconcile derives
    // the tier live; inert until twins baked.)
    if ( perk == "specialty_deadshot" || perk == "specialty_doubletap2" )
    {
        acc_weapon_variants::request_reconcile( self );
    }
}

function on_perk_lost( perk )
{
    // Remove the Mega glow badge for the lost perk.
    if ( isdefined( self.acc_mega_glow ) && isdefined( self.acc_mega_glow[ perk ] ) )
    {
        g = self.acc_mega_glow[ perk ];
        if ( isdefined( g.badge ) ) g.badge hud::destroyElem();
        if ( isdefined( g.label ) ) g.label hud::destroyElem();
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
         || perk == "specialty_fastreload" )
    {
        // Strip the recoil / fastfire / fastreload twin back to the base weapon.
        // reconcile re-derives from the (now-removed) perk, so the twin is undone.
        acc_weapon_variants::request_reconcile( self );
    }
}

// ---------------------------------------------------------------------------
// Display names for Mega variants (docs/13_perks.md source of truth).
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
    // Aura Blast hijacks the stock electric-cherry pipeline (see
    // _acc_perk_aura_blast.gsc), so its specialty is the cherry's.
    case "specialty_deadshot":               return "American Sniper";        // Deadshot
    case "specialty_widowswine":             return "Spiderman";              // Widow's Wine
    case "specialty_electriccherry":         return "Mega Man";               // Aura Blast
    }
    return "Mega Perk";
}

// ---------------------------------------------------------------------------
// HUD sync
// ---------------------------------------------------------------------------

function sync_bottle_count_to_client()
{
    if ( !isdefined( self.acc_mega_bottles ) ) self.acc_mega_bottles = 0;
    if ( !isdefined( self.acc_bottle_hud ) )
    {
        self.acc_bottle_hud = self hud::createFontString( "default", 1.3 );
        // TOP-LEFT, just under the Data Shards line (which is at y=50), so both sit
        // under the health bar instead of behind the stock points display.
        self.acc_bottle_hud hud::setPoint( "TOP_LEFT", "TOP_LEFT", 16, 70 );
        self.acc_bottle_hud.alignX = "left";
        self.acc_bottle_hud.alignY = "top";
        self.acc_bottle_hud.color = ( 0.95, 0.78, 0.2 );
        self.acc_bottle_hud.hidewheninmenu = true;
    }
    // Labeled inline (SetText accepts raw strings). Hidden until first bottle.
    self.acc_bottle_hud SetText( "^3MEGA BOTTLES ^7" + self.acc_mega_bottles );
    self.acc_bottle_hud.alpha = ( self.acc_mega_bottles > 0 ? 0.9 : 0 );
}
