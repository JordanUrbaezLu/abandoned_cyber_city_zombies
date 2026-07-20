// =============================================================================
// _acc_weapon_usage.gsc - ANONYMOUS per-gun usage tracking (docs/41): HELD-TIME
// (exposure), box OFFER/TAKE (Tier B, acquisition preference) and voluntary
// REPLACEMENT (Tier C, retention preference).
//
// WHAT IT DOES: a per-player 1 Hz sampler sums, per game, the seconds each gun was
// any player's CURRENT (in-hands) weapon, folded to its canonical base gun. At
// end_game the leaderboard recorder serializes this into an "id:secs,..." string,
// publishes it on the dvar acc_lb_guns, and the rec LUI chunk appends it to the
// SAME cloud POST (docs/40). The backend derives held-time share + pick rate.
//
// The SAME 1 Hz sampler also diffs each player's carried-gun set (Tier C): a gun
// leaving the loadout via a clean swap while the player is ALIVE and standing is a
// VOLUNTARY replacement; a gun lost to a down / death / Mule-Kick slot loss is NOT
// (it is excluded by construction - see drop_sample). replace_rate = replaced /
// acquires is the availability-FREE RETENTION signal: do players KEEP a gun once
// they have it, or ditch it the instant something else appears. Five-Seven (the
// free starter) trends ~100% replaced; a wonder weapon trends ~0%.
//
// LOCKED DECISIONS (user 2026-07-12): (1) held-in-hands only; (2) ANONYMOUS - no
// gamertags in the gun data (the payload is an all-players AGGREGATE before it ever
// leaves the game); (3) the wonder-MELEE Leviathan counts ("it's really weapon
// usage"). Downed/laststand time EXCLUDED (decision 1); vanilla knife/fists and the
// stock laststand pistol EXCLUDED; every real gun + wonder auto-INCLUDED.
//
// USER RULE (mirrors the recorder): dev mode OR god mode -> track NOTHING. The
// sampler is not even threaded in dev/god (assisted runs never contribute).
//
// FOLD-TO-BASE reuses acc_weapon_variants::true_base (the repo's canonical identity
// key). GUN IDs come from tools/gun_ids.json via tools/gen_gun_ids.js (the acc_gun_id
// block below is GENERATED - do not hand-edit between the markers).
//
// TRANSPORT (docs/41): the GSC->LUI hand-off of the gun blob rides a host-local
// dvar (acc_lb_guns) that the rec chunk reads (multi-arity, pcall-guarded).
// PRODUCTION-VERIFIED 2026-07-12: a real flags-off game landed correct rows in
// /stats/guns - the dvar read WORKS on retail HKS. The one-shot dev probe menu
// (acc_lb_dvarprobe) that proved-out the design was REMOVED post-verification
// (pre-publish cleanup); resurrect from git history if a future HKS/patch change
// ever needs re-verification.
//
// This module touches NOTHING on the boot/load path: the sampler arms at
// on_player_connect, acc_gun_id is a pure switch, and serialize/publish run only at
// end_game. -GscOnly build, no LED bake.
// =============================================================================

#using scripts\zm\_zm_utility;
#using scripts\zm\_zm_equipment;

#insert scripts\shared\shared.gsh;

#using scripts\zm\zm_abandoned_cyber_city\_acc_utility;
#using scripts\zm\zm_abandoned_cyber_city\_acc_weapon_variants;

// Upper bound for the serialize() id sweep. Set generously above the ~31 live guns so
// a future appended id is NEVER silently dropped from the payload (low finding #3);
// matches GUN_ID_MAX in backend/leaderboard/worker.js. The sweep is end_game-only, so
// 200 iterations cost nothing.
#define ACC_WPN_ID_MAX 200

#namespace acc_weapon_usage;

// Called by acc_main::init.
function init()
{
    level.acc_wpn_seconds = [];

    // Tier-B box telemetry (docs/41 §3.7): per-gun OFFER (box landed on it) / TAKE
    // (player grabbed it) counters. take_rate = takes/offers is conditioned on the
    // offer, so box availability cancels out entirely - the pure preference signal
    // the held-time pref_index only approximates. The AW printer box calls these via
    // level pointer hooks (no #using from the vendored pack file - the same idiom as
    // level.CustomRandomWeaponWeights). Auto-give paths (glitch altar, Paradise Box)
    // never set the hooks' inputs, so ONLY real take-it-or-leave-it box rolls count.
    level.acc_box_offers  = [];
    level.acc_box_takes   = [];
    level.acc_box_offer_fn = &box_offer;
    level.acc_box_take_fn  = &box_take;

    // Tier-C retention telemetry (docs/41 §3.9): per-gun ACQUIRE (the gun entered a
    // player's loadout) and voluntary REPLACE (swapped out while alive) counters,
    // keyed by canonical base name. Populated by the sampler's carried-set diff; a
    // death / down / Mule-Kick loss never increments REPLACE (drop_sample gates it).
    level.acc_wpn_acq = [];
    level.acc_wpn_rep = [];

    // R4 (stale-leak guard): the transport dvars start empty every level load so a
    // prior game's blob/duration can never bleed into the next POST. record_at_end_game
    // republishes fresh right before OpenLUIMenu.
    SetDvar( "acc_lb_guns", "" );
    SetDvar( "acc_lb_guns_ck", "" );
    SetDvar( "acc_lb_dur", "" );
    SetDvar( "acc_lb_box", "" );
    SetDvar( "acc_lb_drop", "" );

    // Measurement harvest logger - rides level.acc_dev (the acc_wpn_debug dvar was removed
    // 2026-07-16) so it never shows to real players. A HARVEST run therefore needs a dev build
    // (level.acc_dev = true; + rebuild) to read the accumulator at end_game (Phase 1
    // verification) - and dev/god games do not post to the leaderboard. Memory
    // debug-banners-gated-by-acc-dev-only.
    level thread debug_log_at_end_game();
}

// self = player, threaded from acc_main::on_player_connect.
function on_player_connect( player )
{
    // USER RULE: dev or god mode -> no sampling, no data (assisted runs never stored).
    if ( IS_TRUE( level.acc_dev ) || IS_TRUE( level.acc_god ) )
        return;

    player thread usage_sampler();
}

// Per-player 1 Hz sampler. TWO measurements share the one loop:
//   Tier A held-time - one shared level-scope map keyed by canonical name, so each
//     player's thread increments the same key -> the flat map IS the cross-player sum
//     (two players on one gun -> +2/s). Skipped while downed (laststand pistol) and
//     during the box raise (GetCurrentWeapon returns the STALE old gun - memory
//     box-grab-defer-weapon-reconcile) - gating UNCHANGED from the verified Tier A.
//   Tier C carried-set diff - see drop_sample(). STRICTER gate: only diffs an alive,
//     standing, transaction-free player, and re-baselines (never attributes) after any
//     gap, so a death / down / Mule loss is never mis-read as a voluntary swap.
function usage_sampler()
{
    self endon( "disconnect" );

    // Tier-C baseline lives on the player: self.acc_wpn_prevguns (undefined until the
    // first clean poll) + self.acc_wpn_gap (a non-tracking poll happened -> re-baseline
    // without attributing). Explicitly cleared so a re-threaded sampler (reconnect onto a
    // reused entity) always re-baselines from scratch instead of diffing a stale snapshot.
    // (= undefined is the stock idiom - _acc_gun_badges.gsc:289 self.acc_mule_at_risk.)
    self.acc_wpn_prevguns = undefined;
    self.acc_wpn_gap = false;

    for ( ;; )
    {
        wait 1;
        if ( !isdefined( self ) )
            return;

        downed   = IS_TRUE( self.laststand );
        grabbing = IS_TRUE( self.acc_box_grabbing );

        // --- Tier A: held-in-hands seconds (gating identical to the verified original) ---
        if ( !downed && !grabbing )
        {
            name = usage_base_name( self GetCurrentWeapon() );
            if ( isdefined( name ) )
            {
                if ( !isdefined( level.acc_wpn_seconds[ name ] ) )
                    level.acc_wpn_seconds[ name ] = 0;
                level.acc_wpn_seconds[ name ]++;
            }
        }

        // --- Tier C: voluntary-replacement diff (stricter gate) ---
        // GetWeaponsListPrimaries() is transiently WRONG during ANY inventory
        // transaction (memory box-grab-defer-weapon-reconcile; the exact set of windows
        // mirrors acc_gun_badges::mule_state_frozen - box give, PaP replay-draw, drink)
        // and is meaningless while downed/dead. In any such poll we do NOT diff: we mark
        // a gap so the next clean poll re-baselines without attributing.
        frozen = grabbing || IS_TRUE( self.acc_pap_busy ) ||
                 ( isdefined( self.is_drinking ) && self.is_drinking > 0 );
        if ( frozen || downed || !isalive( self ) )
        {
            self.acc_wpn_gap = true;
            continue;
        }
        self drop_sample();
    }
}

// self = player. Diff the carried-gun set (folded to base names) vs the last CLEAN
// snapshot to count acquisitions and VOLUNTARY replacements. Called only for an alive,
// standing, transaction-free player (usage_sampler gates it).
//
// Classification (why involuntary losses can't leak in):
//   - first-ever poll        -> BASELINE: the spawn loadout counts as acquisitions (so
//                               the starter's later swap yields a real rate), no replace.
//   - first poll after a gap -> RE-BASELINE: snapshot only, attribute NOTHING (we can't
//                               know what changed while the inventory was unknown - a
//                               death/down/Mule loss happened in exactly such a gap).
//   - clean poll             -> a gun that entered = acquire; a VOLUNTARY replace is the
//                               clean-swap signature ONLY: exactly one gun left AND at
//                               least one entered the SAME poll AND the loadout is still
//                               non-empty. A mass-clear (death/teleport) or a lone
//                               removal with no incoming gun (scripted take / Mule
//                               down-loss after revive) never matches -> excluded.
function drop_sample()
{
    cur = self drop_current_set();

    if ( !isdefined( self.acc_wpn_prevguns ) )
    {
        keys = getarraykeys( cur );
        for ( i = 0; i < keys.size; i++ )
            note_acquire( keys[ i ] );
        self.acc_wpn_prevguns = cur;
        self.acc_wpn_gap = false;
        return;
    }

    if ( IS_TRUE( self.acc_wpn_gap ) )
    {
        self.acc_wpn_prevguns = cur;
        self.acc_wpn_gap = false;
        return;
    }

    prev = self.acc_wpn_prevguns;
    added   = [];
    removed = [];
    ck = getarraykeys( cur );
    for ( i = 0; i < ck.size; i++ )
        if ( !isdefined( prev[ ck[ i ] ] ) )
            added[ added.size ] = ck[ i ];
    pk = getarraykeys( prev );
    for ( i = 0; i < pk.size; i++ )
        if ( !isdefined( cur[ pk[ i ] ] ) )
            removed[ removed.size ] = pk[ i ];

    for ( i = 0; i < added.size; i++ )
        note_acquire( added[ i ] );

    if ( ck.size > 0 && removed.size == 1 && added.size >= 1 )
        note_replace( removed[ 0 ] );

    self.acc_wpn_prevguns = cur;
}

// self = player -> assoc set { base_name : 1 } of carried guns, each folded through
// usage_base_name (so grenades/equipment/fists/vanilla-knife/start-pistol drop out,
// exactly like the held-time sampler). Unions the equipped weapon because the pistol
// slot is not always in GetWeaponsListPrimaries (mirrors _acc_mega_bottles::armory_refill).
function drop_current_set()
{
    set = [];
    prims = self GetWeaponsListPrimaries();
    if ( isdefined( prims ) )
    {
        for ( i = 0; i < prims.size; i++ )
        {
            name = usage_base_name( prims[ i ] );
            if ( isdefined( name ) )
                set[ name ] = 1;
        }
    }
    cw = usage_base_name( self GetCurrentWeapon() );
    if ( isdefined( cw ) )
        set[ cw ] = 1;
    return set;
}

// Increment the team-summed ACQUIRE / REPLACE counters for a canonical base name.
// (Distinct names so neither can collide with a GSC string builtin.)
function note_acquire( name )
{
    if ( !isdefined( name ) )
        return;
    if ( !isdefined( level.acc_wpn_acq[ name ] ) )
        level.acc_wpn_acq[ name ] = 0;
    level.acc_wpn_acq[ name ]++;
}

function note_replace( name )
{
    if ( !isdefined( name ) )
        return;
    if ( !isdefined( level.acc_wpn_rep[ name ] ) )
        level.acc_wpn_rep[ name ] = 0;
    level.acc_wpn_rep[ name ]++;
}

// The held weapon OBJECT -> canonical base gun NAME, or undefined to skip. Exclusion-
// based so ported pack guns + wonders auto-include; NEVER use zm_utility::is_offhand_weapon
// (it unions is_melee_weapon and would drop the Leviathan the user wants counted).
function usage_base_name( cur )
{
    if ( !isdefined( cur ) || cur == level.weaponNone || cur == level.weaponZMFists )
        return undefined;
    if ( zm_utility::is_lethal_grenade( cur ) )   return undefined;   // frag
    if ( zm_utility::is_tactical_grenade( cur ) ) return undefined;   // monkey / octobomb
    if ( zm_utility::is_placeable_mine( cur ) )   return undefined;
    if ( zm_utility::is_hero_weapon( cur ) )      return undefined;   // gadget (none registered)
    if ( zm_equipment::is_equipment( cur ) )      return undefined;

    base = acc_weapon_variants::true_base( cur );
    if ( !isdefined( base ) || base == level.weaponNone || !isdefined( base.name ) )
        return undefined;

    // vanilla melee + the stock laststand/start pistol (MR6) are not weapon CHOICES.
    // The Leviathan (leviathan), Action Figure (t8_melee_figure) and Ballistic Knife
    // (knife_ballistic) are DIFFERENT names -> they still pass and get tracked.
    if ( base.name == "knife" || base.name == "bowie_knife" || base.name == "pistol_standard" )
        return undefined;

    return base.name;
}

// Canonical base name -> stable positive int id (docs/41). id 0 = other/unknown
// catch-all (an unmapped held gun is COUNTED, never dropped). The IF-BLOCK between
// the markers is GENERATED by tools/gen_gun_ids.js from tools/gun_ids.json - DO NOT
// hand-edit it; edit the registry + re-run the generator.
function acc_gun_id( weapon_name )
{
    if ( !isdefined( weapon_name ) )
        return 0;
    n = weapon_name;

    // defensive: strip a trailing _upgraded / _up / _zm so a stray form still maps.
    // true_base already folds these, so this is a belt-and-suspenders net for a
    // future irregular port (R1).
    if ( acc_weapon_variants::ends_with( n, "_upgraded" ) )
        n = GetSubStr( n, 0, n.size - 9 );
    else if ( acc_weapon_variants::ends_with( n, "_up" ) )
        n = GetSubStr( n, 0, n.size - 3 );
    if ( acc_weapon_variants::ends_with( n, "_zm" ) )
        n = GetSubStr( n, 0, n.size - 3 );

    // <<< BEGIN GENERATED gun-id map (tools/gen_gun_ids.js from tools/gun_ids.json) - DO NOT hand-edit >>>
    if ( n == "t6_fiveseven" )             return 1;
    if ( n == "apex_peacekeeper" )         return 2;
    if ( n == "apex_beam_rifle" )          return 3;
    if ( n == "apex_alternator" )          return 4;
    if ( n == "apex_prowler" )             return 5;
    if ( n == "apex_tripletake" )          return 6;
    if ( n == "s1_tac19" )                 return 7;
    if ( n == "t9_ak47" )                  return 8;
    if ( n == "t9_xm4" )                   return 9;
    if ( n == "t9_streetsweeper" )         return 10;
    if ( n == "s1_cel3" )                  return 11;
    if ( n == "s1_ae4" )                   return 12;
    if ( n == "s4_ppsh41_base" )           return 13;
    if ( n == "t9_ak74u" )                 return 14;
    if ( n == "t6_olympia" )               return 15;
    if ( n == "t9_grav" )                  return 16;
    if ( n == "t9_m60" )                   return 17;
    if ( n == "t9_rpd" )                   return 18;
    if ( n == "t6_hamr" )                  return 19;
    if ( n == "s1_mk14" )                  return 20;
    if ( n == "s1_mors" )                  return 21;
    if ( n == "s1_rw1" )                   return 22;
    if ( n == "s1_mahem" )                 return 23;
    if ( n == "t6_war_machine" )           return 24;
    if ( n == "thundergun" )               return 25;
    if ( n == "t9_semiauto_cosplay" )      return 26;
    if ( n == "elemental_bow_demongate" )  return 27;
    if ( n == "leviathan" )                return 28;
    if ( n == "freezegun" )                return 29;
    if ( n == "t8_melee_figure" )          return 30;
    if ( n == "knife_ballistic" )          return 31;
    if ( n == "apex_lstar" )               return 32;
    // <<< END GENERATED gun-id map >>>

    return 0;
}

// level.acc_wpn_seconds (keyed by name) -> "id:secs,id:secs,..." sorted by id
// ascending. Sums by id (unmapped names collect into id 0). Empty when nothing was
// tracked (dev/god run, or no time yet).
function serialize()
{
    by_id = [];   // by_id[ "<id>" ] = seconds
    if ( isdefined( level.acc_wpn_seconds ) )
    {
        names = getarraykeys( level.acc_wpn_seconds );
        for ( i = 0; i < names.size; i++ )
        {
            secs = level.acc_wpn_seconds[ names[ i ] ];
            if ( !isdefined( secs ) || secs <= 0 )
                continue;
            key = "" + acc_gun_id( names[ i ] );
            if ( !isdefined( by_id[ key ] ) )
                by_id[ key ] = 0;
            by_id[ key ] += secs;
        }
    }

    out = "";
    for ( id = 0; id <= ACC_WPN_ID_MAX; id++ )
    {
        key = "" + id;
        if ( !isdefined( by_id[ key ] ) )
            continue;
        if ( out != "" )
            out += ",";
        out += id + ":" + by_id[ key ];
    }
    return out;
}

// ---------------------------------------------------------------------------
// Tier-B box telemetry (docs/41 §3.7): offer/take counters + serializer.
// Called by the AW printer box via level.acc_box_offer_fn / acc_box_take_fn
// (pointer hooks, set in init) - never #using'd from the vendored pack file.
// ---------------------------------------------------------------------------

// The box landed on this gun (self.actual_weapon set) - an OFFER the spinner can
// take or walk away from. weapon = the drawn base weapon object.
function box_offer( weapon )
{
    if ( IS_TRUE( level.acc_dev ) || IS_TRUE( level.acc_god ) )
        return;
    name = usage_base_name( weapon );
    if ( !isdefined( name ) )
        return;
    if ( !isdefined( level.acc_box_offers[ name ] ) )
        level.acc_box_offers[ name ] = 0;
    level.acc_box_offers[ name ]++;
}

// The player grabbed the offered gun (box_get_weapon fired) - a TAKE.
function box_take( weapon )
{
    if ( IS_TRUE( level.acc_dev ) || IS_TRUE( level.acc_god ) )
        return;
    name = usage_base_name( weapon );
    if ( !isdefined( name ) )
        return;
    if ( !isdefined( level.acc_box_takes[ name ] ) )
        level.acc_box_takes[ name ] = 0;
    level.acc_box_takes[ name ]++;
}

// level.acc_box_offers/takes -> "id:offers:takes,..." sorted by id ascending (the
// acc_lb_guns idiom with a third field). A gun with takes but no offers can't happen
// (take implies a prior offer this game); a gun offered but never taken serializes
// "id:N:0" - exactly the signal take-rate needs. Empty when no box rolls happened.
function serialize_box()
{
    offers_by_id = [];
    takes_by_id  = [];
    if ( isdefined( level.acc_box_offers ) )
    {
        names = getarraykeys( level.acc_box_offers );
        for ( i = 0; i < names.size; i++ )
        {
            n = level.acc_box_offers[ names[ i ] ];
            if ( !isdefined( n ) || n <= 0 )
                continue;
            key = "" + acc_gun_id( names[ i ] );
            if ( !isdefined( offers_by_id[ key ] ) )
                offers_by_id[ key ] = 0;
            offers_by_id[ key ] += n;
        }
    }
    if ( isdefined( level.acc_box_takes ) )
    {
        names = getarraykeys( level.acc_box_takes );
        for ( i = 0; i < names.size; i++ )
        {
            n = level.acc_box_takes[ names[ i ] ];
            if ( !isdefined( n ) || n <= 0 )
                continue;
            key = "" + acc_gun_id( names[ i ] );
            if ( !isdefined( takes_by_id[ key ] ) )
                takes_by_id[ key ] = 0;
            takes_by_id[ key ] += n;
        }
    }

    out = "";
    for ( id = 0; id <= ACC_WPN_ID_MAX; id++ )
    {
        key = "" + id;
        if ( !isdefined( offers_by_id[ key ] ) )
            continue;   // takes without an offer can't happen; the sweep keys off offers
        t = 0;
        if ( isdefined( takes_by_id[ key ] ) )
            t = takes_by_id[ key ];
        if ( out != "" )
            out += ",";
        out += id + ":" + offers_by_id[ key ] + ":" + t;
    }
    return out;
}

// ---------------------------------------------------------------------------
// Tier-C retention telemetry (docs/41 §3.9): acquire/replace serializer.
// ---------------------------------------------------------------------------

// level.acc_wpn_acq/rep -> "id:acq:rep,..." sorted by id ascending (mirrors
// serialize_box's id:offers:takes shape). The sweep keys off ACQUIRES: a replace
// implies a prior acquire, so a rep with no acq (its acquisition fell inside a
// re-baseline gap) is intentionally dropped rather than shipped as rep>acq. A gun
// acquired but never voluntarily replaced serializes "id:N:0" - the "players keep
// it" signal. Empty when nothing was acquired (dev/god run, or no data yet).
function serialize_drop()
{
    acq_by_id = [];
    rep_by_id = [];
    if ( isdefined( level.acc_wpn_acq ) )
    {
        names = getarraykeys( level.acc_wpn_acq );
        for ( i = 0; i < names.size; i++ )
        {
            n = level.acc_wpn_acq[ names[ i ] ];
            if ( !isdefined( n ) || n <= 0 )
                continue;
            key = "" + acc_gun_id( names[ i ] );
            if ( !isdefined( acq_by_id[ key ] ) )
                acq_by_id[ key ] = 0;
            acq_by_id[ key ] += n;
        }
    }
    if ( isdefined( level.acc_wpn_rep ) )
    {
        names = getarraykeys( level.acc_wpn_rep );
        for ( i = 0; i < names.size; i++ )
        {
            n = level.acc_wpn_rep[ names[ i ] ];
            if ( !isdefined( n ) || n <= 0 )
                continue;
            key = "" + acc_gun_id( names[ i ] );
            if ( !isdefined( rep_by_id[ key ] ) )
                rep_by_id[ key ] = 0;
            rep_by_id[ key ] += n;
        }
    }

    out = "";
    for ( id = 0; id <= ACC_WPN_ID_MAX; id++ )
    {
        key = "" + id;
        if ( !isdefined( acq_by_id[ key ] ) )
            continue;   // rep-without-acq can't be trusted; the sweep keys off acquires
        r = 0;
        if ( isdefined( rep_by_id[ key ] ) )
            r = rep_by_id[ key ];
        if ( out != "" )
            out += ",";
        out += id + ":" + acq_by_id[ key ] + ":" + r;
    }
    return out;
}

// C = sum( id*31 + secs ) over the packed pairs. The LUI side recomputes from the
// SAME string; a MATCH proves the unproven GSC->LUI dvar transport delivered
// identical ints (docs/41 Phase 2). Parses the packed string so both sides agree.
function checksum( packed )
{
    c = 0;
    if ( !isdefined( packed ) || packed == "" )
        return 0;
    pairs = StrTok( packed, "," );
    for ( i = 0; i < pairs.size; i++ )
    {
        kv = StrTok( pairs[ i ], ":" );
        if ( kv.size != 2 )
            continue;
        c += ( int( kv[ 0 ] ) * 31 ) + int( kv[ 1 ] );
    }
    return c;
}

// ---------------------------------------------------------------------------
// VERIFICATION (dev-only - rides level.acc_dev) - proves the pipe before we trust it.
// ---------------------------------------------------------------------------

// Phase 1: at end_game, dump the accumulator so a dev-build run can verify the sampler.
// Rides level.acc_dev (the acc_wpn_debug dvar was removed 2026-07-16) so it never fires
// for real players.
function debug_log_at_end_game()
{
    level waittill( "end_game" );

    if ( !IS_TRUE( level.acc_dev ) )
        return;

    packed = serialize();
    usage_log( "END_GAME accumulator: packed='" + packed + "' checksum=" + checksum( packed ) );
    usage_log( "END_GAME box='" + serialize_box() + "' drop='" + serialize_drop() + "'" );
    if ( isdefined( level.acc_wpn_seconds ) )
    {
        names = getarraykeys( level.acc_wpn_seconds );
        for ( i = 0; i < names.size; i++ )
            usage_log( "  " + names[ i ] + "  id=" + acc_gun_id( names[ i ] ) + "  secs=" + level.acc_wpn_seconds[ names[ i ] ] );
    }
}

// Mirror one line to the durable oracles: IPrintLnBold -> console_mp.log
// "[ SCRIPTER]" lines (docs/17), acc_utility::log -> dev-block println.
// ON-SCREEN MIRROR IS DEBUG-ONLY (same gate as lb_log): IPrintLnBold draws on every
// player's screen, so it must never fire on shipped builds. Today all callers are
// already behind the level.acc_dev gate, but the gate lives HERE too so a future caller can't
// leak debug text to subscribers (debug rides the one acc_dev flag; the acc_wpn_debug dvar
// was removed 2026-07-16 - memory debug-banners-gated-by-acc-dev-only).
function usage_log( line )
{
    if ( IS_TRUE( level.acc_dev ) )
        IPrintLnBold( "^6[WPN]^7 " + line );
    acc_utility::log( "wpn: " + line );
}
