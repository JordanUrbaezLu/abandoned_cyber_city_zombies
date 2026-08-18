// =============================================================================
// _acc_transfer.gsc - "The Exchange": a SHARED TEAM VAULT for player-to-player
// transfers of all four per-player resources (user 2026-06-27: "a room where
// players can transfer shards, money, mega bottles and items to other players").
//
// MODEL = shared deposit/withdraw POOL (chosen by the user over directed-give /
// two-pad). Co-op is host-authoritative and every resource is strictly per-player
// (docs/12) - boss rewards even grant to each player independently - so the vault
// is about REDISTRIBUTING: a strong killer banks points/shards/bottles/items that a
// teammate building toward an expensive sink (Exo Suit, per-gun Overclocks) pulls
// out. No player-targeting (avoids the closest_player_override hazards) - anyone on
// the team can withdraw what anyone deposited. In SOLO it is a personal stash.
//
// THE ROOM (tools/gen_plaza_basement.js): an enclosed vault with its FLOOR AT z=-160
// (CORRECTED 2026-07-17 - this header said "-240" for weeks and the stale claim made the
// v1 teleporter pad spawn 80u under the floor + drop riders into the void; ground truth =
// the tagged "vault floor slab" brush, .map ~L2603: top -160, room x[-720,300] y[-448,360],
// ceiling -16) directly UNDER the spawn Plaza, reached by a stairwell carved DOWN from the
// Implant Lab and gated by the buyable "enter_exchange" door (1500, wired in
// zm_abandoned_cyber_city.gsc). NOTE the old -240 belief once shaped spawn_station(): ATM
// bases used to spawn at origin+(0,0,-80) = 80u UNDER the real -160 floor - only the totem's
// top ~23u showed. CLOSED 2026-08-03 (docs/47 audit Phase A, the user's placement pass
// re-opened the 2026-07-17 "user's call to raise"): bases now spawn AT origin (z=-160,
// flush), clips re-synced bot -160/top -57.
// It is excluded from the trench amping + OOB-kill via origin_in_vault() in
// _acc_bus_trench.gsc (a SAFE utility room).
//
// THE STATIONS = pure GSC (script-spawned trigger_radius_use, no .map entity / zone
// line / LED-bake risk - the canonical station recipe, mirroring _acc_glitch_altar).
// One terminal per resource, flanked by a DEPOSIT pad + a WITHDRAW pad (one trigger
// per action = the Implant-Bench multi-pad idiom; BO3 use-triggers are single-button).
// Each press moves one fixed increment (the codebase's "how much" idiom - no in-game
// menu exists). Hint strings are CONSTANT (the 250-unique-SetHintString cap, memory
// triggerstring-cap-hint-strings); the live amount/pool is shown via acc_utility::hud_msg.
//
// THE POOL is level-side (level.acc_vault_*) - the only shared store on the map; both
// currencies + bottles are per-player script fields with no shared field, so a shared
// bank must be our own level var (settled synchronously; if a player disconnects mid-run
// nothing is lost because deposits transfer ownership to the level immediately).
//
// Live dvars: acc_vault_points_inc (1000 -> 10% tax = 100 exact), acc_vault_shards_inc (10 -> tax = 1 exact), acc_vault_items_max (8),
//             acc_vault_tax_pct (10 - the deposit tax on Points + Shards; Bottles + Items untaxed).
// =============================================================================

#using scripts\shared\util_shared;

#using scripts\zm\_zm_score;
#using scripts\zm\_zm_utility;

#using scripts\zm\zm_abandoned_cyber_city\_acc_utility;
#using scripts\zm\zm_abandoned_cyber_city\_acc_data_shards;
#using scripts\zm\zm_abandoned_cyber_city\_acc_mega_bottles;
#using scripts\zm\zm_abandoned_cyber_city\_acc_boss_items;
#using scripts\zm\zm_abandoned_cyber_city\_acc_interact_glow;   // cyan "usable" holo on the vault ATMs

// Terminal mesh: the Cyber City interactive kiosk (stock t7 prop, proven-packing - same
// model the Glitch Altar uses).
// STATION REMODEL (user 2026-07-09, docs/09): ATM totem (37x34x103, T7-dump carve; Zurich
// ticket-kiosk mesh family) - the deposit/withdraw read for the 4 vault stations. Its origin is
// at the BASE and the vault floor is z=-160 (NOT -240 - the header's old stale claim), so the
// model spawns AT the station origin, flush (2026-08-03 fix); pads/triggers keep the -160 origins.
#precache( "model", "p7_out_monitor_atm" );

#namespace acc_transfer;

// ---------------------------------------------------------------------------
// Init
// ---------------------------------------------------------------------------

function init()
{
    // shared team pools (level-side; persist for the whole match).
    level.acc_vault_points  = 0;
    level.acc_vault_shards  = 0;
    level.acc_vault_bottles = 0;
    level.acc_vault_items   = [];   // FIFO list of boss-item id strings

    acc_utility::log( "transfer (The Exchange) init" );
    level thread spawn_stations();
}

// Each station = a terminal model + a DEPOSIT pad + a WITHDRAW pad, laid out in the vault
// room (map ground truth 2026-07-17: room x[-720,300] y[-448,360], floor z=-160 - the old
// "-240 floor / x[-360..]" numbers here were stale). The stair landing is the room's WEST
// end (well x[-620,-380] y[-440,-312]); terminals sit at x~80 in a north-south row, clear
// of the stairs and each other (pad radius 40, pads >=80u apart). The teleporter RED disc
// (_acc_teleporter) sits far west (-640,40) - keep new stations east of x~-400.
function spawn_stations()
{
    level endon( "end_game" );
    wait 1;   // after data_shards / mega_bottles / boss_items init (their fields + pools ready)

    spawn_station( "points",  ( 80, 200, -160 ) );
    spawn_station( "shards",  ( 80, 40, -160 ) );
    spawn_station( "bottles", ( 80, -120, -160 ) );
    spawn_station( "items",   ( 80, -280, -160 ) );

    acc_utility::log( "transfer: 4 vault stations spawned (points/shards/bottles/items)" );
}

function spawn_station( kind, origin )
{
    base = spawn( "script_model", origin + ( 37, 0, 0 ) );   // ATM origin is at its base + BACK face; spawn AT the real -160 floor (raise
                                              // fix 2026-08-03) and +37x so the yaw-180 flip below leaves the 37u-deep mesh
                                              // in the SAME world box x[80,117] - transfer_* clips + both pads untouched.
                                              // Screen lands at x=80 facing WEST at the stair approach (docs/47 trench
                                              // finding 3: the row showed 4 machine BACKS to the room's only entrance).
    base setmodel( "p7_out_monitor_atm" );
    base.angles = ( 0, 180, 0 );
    acc_interact_glow::glow_on( base );

    // DEPOSIT pad (west of the terminal) + WITHDRAW pad (east of the terminal).
    spawn_pad( kind, "deposit",  origin + ( -55, 0, 0 ), base );
    spawn_pad( kind, "withdraw", origin + (  55, 0, 0 ), base );
}

function spawn_pad( kind, op, origin, base_model )
{
    t = spawn( "trigger_radius_use", origin + ( 0, 0, 40 ), 0, 40, 90 );
    t TriggerIgnoreTeam();   // REQUIRED for a script-spawned use-trigger (memory script-trigger-needs-ignoreteam)
    t SetCursorHint( "HINT_NOICON" );
    t SetHintString( pad_hint( kind, op ) );   // CONSTANT string (8 total) - dodges the 250-unique-hint cap
    t.acc_kind = kind;
    t.acc_op   = op;
    t.acc_station_base = base_model;   // glow_off target on this station's first successful transaction
    t thread pad_loop();
}

// Constant, qualitative hints (no magnitudes - memory vague-ui-no-magnitudes; the actual
// amount + pool show via hud_msg on use). One fixed string per (kind, op) = 8 total.
function pad_hint( kind, op )
{
    label = label_for( kind );
    if ( op == "deposit" )
        return "Hold ^3[{+activate}]^7  ^2DEPOSIT^7 " + label + " to the Team Vault";
    return "Hold ^3[{+activate}]^7  ^5WITHDRAW^7 " + label + " from the Team Vault";
}

function label_for( kind )
{
    switch ( kind )
    {
    case "points":  return "^3Points^7";
    case "shards":  return "^5Data Shards^7";
    case "bottles": return "^6Mega Bottles^7";
    case "items":   return "^7a Boss Item";
    }
    return kind;
}

// ---------------------------------------------------------------------------
// Interaction (self = the pad trigger)
// ---------------------------------------------------------------------------

function pad_loop()
{
    self endon( "death" );
    level endon( "end_game" );

    for ( ;; )
    {
        self waittill( "trigger", player );
        if ( !isdefined( player ) || !zm_utility::is_player_valid( player ) )
            continue;   // gate BOTH ends with is_player_valid (downed/spectating can't transact)

        // Success detection (user 2026-07-17 "successful trigger" stops the glow): the op helpers
        // deny() internally with no return value, so snapshot the four pools and compare - any
        // pool change means the transaction actually went through.
        pre_p = level.acc_vault_points;
        pre_s = level.acc_vault_shards;
        pre_b = level.acc_vault_bottles;
        pre_i = level.acc_vault_items.size;

        is_deposit = ( self.acc_op == "deposit" );
        switch ( self.acc_kind )
        {
        case "points":
            if ( is_deposit ) deposit_points( player );  else withdraw_points( player );
            break;
        case "shards":
            if ( is_deposit ) deposit_shards( player );  else withdraw_shards( player );
            break;
        case "bottles":
            if ( is_deposit ) deposit_bottle( player );  else withdraw_bottle( player );
            break;
        case "items":
            if ( is_deposit ) deposit_item( player );    else withdraw_item( player );
            break;
        }
        if ( level.acc_vault_points != pre_p || level.acc_vault_shards != pre_s ||
             level.acc_vault_bottles != pre_b || level.acc_vault_items.size != pre_i )
            acc_interact_glow::glow_off( self.acc_station_base );   // pool changed = successful transaction
        wait 0.4;   // per-press debounce (one hold must not double-fire)
    }
}

// ---- transfer tax (user 2026-06-27) -----------------------------------------
// A 10% TAX (dvar acc_vault_tax_pct) applied on DEPOSIT of Points + Data Shards ONLY - the pool
// receives n minus the rounded tax, so the pool always holds clean 1:1 value and the withdraw paths
// (incl. the shard cap clamp) stay untouched. Mega Bottles + Boss Items are NOT taxed. The tax is the
// "house cut" that keeps a team from trivially funnelling the whole economy onto one player (docs/37).
function after_tax( n )
{
    pct = getdvarint( "acc_vault_tax_pct", 10 );
    if ( pct <= 0 ) return n;
    tax = int( ( n * pct + 50 ) / 100 );   // 10% rounded to the nearest whole unit
    return n - tax;
}

// ---- Points -----------------------------------------------------------------
// NEVER write player.score: spend via zm_score::minus_to_player_score (raw, does NOT floor at 0
// so we gate on the balance first), grant via add_to_player_score (rounds UP to /10 -> grant whole tens).
function deposit_points( player )
{
    inc = getdvarint( "acc_vault_points_inc", 1000 );
    have = 0;
    if ( isdefined( player.score ) ) have = player.score;
    n = inc;
    if ( have < n ) n = have;
    n = n - ( n % 10 );   // whole tens you pay
    if ( n <= 0 ) { player deny( "not enough Points to deposit" ); return; }

    net = after_tax( n );   // pool gets ~90% (the 10% tax is destroyed)
    if ( net <= 0 ) { player deny( "too few Points to deposit after tax" ); return; }
    // Snapshot around the debit: the Shopping Free gobblegum makes minus_to_player_score a NO-OP (deducts
    // nothing), yet we would still credit the vault = minted points (audit 2026-07-12). Only proceed if the
    // points were actually removed. GSC is single-threaded across these two reads (no wait), so no race.
    before = ( isdefined( player.score ) ? player.score : 0 );
    player zm_score::minus_to_player_score( n );
    after = ( isdefined( player.score ) ? player.score : 0 );
    if ( ( before - after ) < n ) { player deny( "deposit blocked - no Points were spent" ); return; }
    level.acc_vault_points += net;
    player ok( "Deposited ^3" + n + " Points^7 (tax ^1-" + ( n - net ) + "^7)" );   // vault total dropped - see ok() (string-cache)
}

function withdraw_points( player )
{
    inc = getdvarint( "acc_vault_points_inc", 1000 );
    n = inc;
    if ( level.acc_vault_points < n ) n = level.acc_vault_points;
    grant = n - ( n % 10 );   // grant whole tens so add_to_player_score is exact (sub-10 dust stays in the pool)
    if ( grant <= 0 ) { player deny( "the vault has no Points" ); return; }

    player zm_score::add_to_player_score( grant );
    level.acc_vault_points -= grant;
    player ok( "Withdrew ^3" + grant + " Points^7" );   // vault total dropped - see ok() (string-cache)
}

// ---- Data Shards ------------------------------------------------------------
// grant_player CLAMPS to the per-player shards_cap and returns what actually landed - withdraw by
// the GRANTED amount so a near-full recipient never makes vault shards vanish. source_tag "transfer"
// (NOT "elite_kill") so no low-round diminish applies.
function deposit_shards( player )
{
    inc = getdvarint( "acc_vault_shards_inc", 10 );
    have = acc_data_shards::get_count( player );
    n = inc;
    if ( have < n ) n = have;
    if ( n <= 0 ) { player deny( "no Data Shards to deposit" ); return; }

    net = after_tax( n );   // pool gets ~90% (the 10% tax is destroyed)
    if ( net <= 0 ) { player deny( "too few Data Shards to deposit after tax" ); return; }
    if ( !acc_data_shards::try_spend( player, n ) ) { player deny( "no Data Shards to deposit" ); return; }
    level.acc_vault_shards += net;
    player ok( "Deposited ^5" + n + " Data Shards^7 (tax ^1-" + ( n - net ) + "^7)" );   // vault total dropped - see ok() (string-cache)
}

function withdraw_shards( player )
{
    inc = getdvarint( "acc_vault_shards_inc", 10 );
    n = inc;
    if ( level.acc_vault_shards < n ) n = level.acc_vault_shards;
    if ( n <= 0 ) { player deny( "the vault has no Data Shards" ); return; }

    granted = acc_data_shards::grant_player( player, n, "transfer" );
    if ( granted <= 0 ) { player deny( "your Data Shards are full" ); return; }
    level.acc_vault_shards -= granted;
    player ok( "Withdrew ^5" + granted + " Data Shards^7" );   // vault total dropped - see ok() (string-cache)
}

// ---- Mega Bottles -----------------------------------------------------------
function deposit_bottle( player )
{
    if ( acc_mega_bottles::get_bottle_count( player ) <= 0 ) { player deny( "no Mega Bottles to deposit" ); return; }
    if ( !acc_mega_bottles::try_consume_bottle( player, 1 ) ) { player deny( "no Mega Bottles to deposit" ); return; }
    level.acc_vault_bottles += 1;
    player ok( "Deposited a ^6Mega Bottle^7  ->  vault: ^6" + level.acc_vault_bottles );
}

function withdraw_bottle( player )
{
    if ( level.acc_vault_bottles <= 0 ) { player deny( "the vault has no Mega Bottles" ); return; }
    player acc_mega_bottles::grant_bottle( 1, "transfer" );
    level.acc_vault_bottles -= 1;
    player ok( "Withdrew a ^6Mega Bottle^7  (vault: ^6" + level.acc_vault_bottles + "^7)" );
}

// ---- Boss Items -------------------------------------------------------------
// Deposit the loose CARRIED item if any; else UN-IMPLANT the first occupied slot (unequip_slot runs
// on_unequip = the buff/flag/watcher actually stop, and recompute_move_speed re-runs for the giver).
// Withdraw drops the oldest vaulted item into the recipient's CARRY slot - they enable it at an
// Implant Bench (upstairs), exactly like a fresh pickup. An item you already have IMPLANTED is
// REFUSED at the withdraw pad and stays in the vault for a teammate - the ground grab's exact
// semantics (docs/09; the bench does NOT convert an implanted duplicate to shards - it refuses it,
// so handing one to the carry slot would strand it: see withdraw_item).
function deposit_item( player )
{
    // capacity check BEFORE any mutation, so a full locker never strips the item off the player.
    if ( level.acc_vault_items.size >= getdvarint( "acc_vault_items_max", 8 ) )
    {
        player deny( "the vault item locker is full" );
        return;
    }

    id  = undefined;
    src = "";
    if ( isdefined( player.acc_carried_item ) )
    {
        id = player.acc_carried_item;
        player.acc_carried_item = undefined;
        src = "carried";
    }
    else
    {
        slot = first_filled_slot( player );
        if ( slot >= 0 )
        {
            id = player.acc_equipped_items[ slot ];
            acc_boss_items::unequip_slot( player, slot );   // player is an ARG (not self); runs on_unequip (buff off)
            src = "Implant " + ( slot + 1 );
        }
    }

    if ( !isdefined( id ) || id == "" )
    {
        player deny( "carry or implant a Boss Item first, then deposit it" );
        return;
    }

    level.acc_vault_items[ level.acc_vault_items.size ] = id;
    player acc_boss_items::sync_items_hud();
    istruct = acc_boss_items::find_item( id );
    nm = ( isdefined( istruct ) ? istruct.display_name : id );
    player ok( "Deposited ^7" + nm + "^7 (" + src + ")  ->  vault items: " + level.acc_vault_items.size );
}

function withdraw_item( player )
{
    if ( level.acc_vault_items.size <= 0 ) { player deny( "the vault has no Boss Items" ); return; }
    if ( isdefined( player.acc_carried_item ) ) { player deny( "enable your carried item at a bench first" ); return; }

    id = level.acc_vault_items[ 0 ];
    // ALREADY IMPLANTED (any slot) -> refuse and LEAVE it in the vault for a teammate, mirroring the
    // ground grab (acc_boss_items::watch_pickup refuses an implanted duplicate instead of consuming it).
    // MUST be checked BEFORE the pop, or the withdraw JAMS the player three ways: the bench refuses to
    // implant a duplicate (never converts it), push_implants_clientfield hides an already-implanted carry
    // so the CARRYING card stays EMPTY (no on-screen explanation), and the carry gate above then denies
    // every FURTHER withdrawal - telling them to bench the one item the bench will not take.
    // STACKABLE exception (Sentry Drone, user 2026-07-25): duplicates are legal implants (one per slot),
    // the bench accepts them, and the carried nibble shows a stackable carry - none of the three jams
    // applies, so the withdraw proceeds like any fresh item.
    if ( acc_boss_items::player_has_item( player, id ) && !( acc_boss_items::item_is_stackable( id ) ) )
    {
        player deny( "you already have that implanted - it stays in the vault" );
        return;
    }

    // pop index 0 (FIFO)
    rest = [];
    for ( i = 1; i < level.acc_vault_items.size; i++ )
        rest[ rest.size ] = level.acc_vault_items[ i ];
    level.acc_vault_items = rest;

    player.acc_carried_item = id;
    player acc_boss_items::sync_items_hud();
    istruct = acc_boss_items::find_item( id );
    nm = ( isdefined( istruct ) ? istruct.display_name : id );
    player ok( "Withdrew ^7" + nm + "^7 - enable it at an Implant Bench  (vault items: " + level.acc_vault_items.size + ")" );
    if ( isdefined( istruct ) ) player iprintln( "^5" + istruct.desc );   // what it does (user 2026-07-11; desc set is fixed -> string-cache safe)
}

// First occupied implant slot, or -1 if all are empty. acc_equipped_items is a fixed
// ACC_ITEM_SLOTS_PER_PLAYER-element array (3 since 2026-07-09) with "" sentinel for empty (set in
// acc_boss_items::on_player_connect) - the loop is size-driven, so it needs no slot-count constant.
function first_filled_slot( player )
{
    if ( !isdefined( player.acc_equipped_items ) ) return -1;
    for ( i = 0; i < player.acc_equipped_items.size; i++ )
        if ( isdefined( player.acc_equipped_items[ i ] ) && player.acc_equipped_items[ i ] != "" )
            return i;
    return -1;
}

// ---- feedback ---------------------------------------------------------------
// CACHE SAFETY (string-cache audit 2026-06-27): ok() routes to hud_msg -> SetText, and every DISTINCT string
// ever passed to a server-hudelem SetText permanently burns one of the 2048 per-match 'string' BG-cache slots
// (never freed). NEVER embed an unbounded running total - level.acc_vault_points/_shards climb all game, so a
// "-> vault: <total>" suffix minted a brand-new string almost every transaction and marched the cache toward
// the cap -> `Exceeded 2048 items for type string` CTD (see memory string-cache-setvalue-not-settext). The
// deposit/withdraw toasts now show ONLY the BOUNDED per-press amount; if the live vault balance must be shown,
// put it on a dedicated SetValue element (cache-free), not in this text. (Bottle/item toasts keep their count
// because it is low-cardinality - vault bottles/items are capped small - so they cannot approach the cap.)
function ok( text )   // self = player
{
    self acc_utility::hud_msg( "^2[TEAM VAULT]^7 " + text );
    self PlaySound( "zmb_cha_ching" );
}

function deny( text )   // self = player
{
    self acc_utility::hud_msg( "^1[TEAM VAULT]^7 " + text );
    self PlaySound( "zmb_no_purchase" );
}
