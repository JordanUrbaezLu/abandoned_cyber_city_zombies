// =============================================================================
// _acc_health_bars.gsc - player health bar + boss health bar/nameplate
//
// (1) Player bar: a per-player hud bar that tracks self.health / self.maxhealth,
//     recolored green->amber->red so you can see when you're one hit from down,
//     plus a numeric "current / max" readout to its right (same recolor).
// (2) Boss bar: a shared (server) bar + name label at the top of the screen
//     while a boss is alive, driven by the "acc_boss_spawned" notify that
//     _acc_boss.gsc emits, hidden on the boss's death.
//
// Stock precedents (tmp/bo3_stock_ref): hud::createBar/updateBar = the vehicle
// health bar (_vehicle.gsc:647) + craftable progress bar (_zm_craftables.gsc).
// createBar() returns the BACKGROUND elem; the colored FILL is elem.bar.
// =============================================================================

#using scripts\shared\flag_shared;
#using scripts\shared\hud_util_shared;
#using scripts\shared\util_shared;

#insert scripts\shared\shared.gsh;

#using scripts\zm\zm_abandoned_cyber_city\_acc_utility;

#define ACC_PLAYER_BAR_W 120
#define ACC_PLAYER_BAR_H 9
#define ACC_BOSS_BAR_W   340
#define ACC_BOSS_BAR_H   14
#define ACC_BOSS_OH_W    80   // overhead (world-space) boss bar width, px
#define ACC_BOSS_OH_H    7    // overhead (world-space) boss bar height, px
#define ACC_WH_MARKER_SIZE 2  // zombie wallhack marker px (was 10; ~90% smaller per user 2026-06-17)
#define ACC_WH_MARKER_CAP 3   // MAX concurrent wallhack markers/client (user 2026-06-26; cut 10->3 on 2026-06-27). Each is 1 NewClientHudElem PER zombie; with the co-op roster also drawing from the SHARED per-client pool, a big marker count starves lazy DEV/ship HUD (round counter, Paradise finale timer, song banner, boss bars - memory server-hudelem-pool-exhaustion-coop). SHIP has no wallhack, so this only affects DEV testing; kept low so dev reflects a real lobby's pool load. Lower further / 0 if dev UI still drops.
#define ACC_ROSTER_STAT_CHARW 5.0  // est. px/char of the roster stats text (default font, scale 1.0). LINE 3 packs $POINTS + SH + EXO/MB on ONE row; GSC has no text-width API, so each field's x is estimated from the prior field's char count (x = prevX + chars*CHARW + GAP). Set JUST above the true width (~4.8) so fields never overlap but the gap doesn't balloon with char count (user 2026-06-27: 5.5 made the SH->EXO gap too wide - the overshoot scales with the longer "SH {shards}" string). Bump if fields overlap; lower toward 4.8 if gaps still too wide.
#define ACC_ROSTER_FIELD_GAP  5    // px gap between the $POINTS / SH / EXO-MB fields on the roster stats row
#define ACC_ROSTER_POINTS_X   18   // x where the POINTS number starts = 12 (the "$" prefix elem) + ~1 char, so it reads "$<points>" near-flush. The SH field flows dynamically from here in update_roster.
// Tiered roster HEALTH bar (user 2026-06-27): the bar is THREE proportional segments - base 0..100 HP (green),
// Juggernog 100..250 (darker green), Mega Jug 250..300 (dark green). PX_PER_HP keeps them to-scale (40/60/20 px).
// The 100/250/300 thresholds ARE the Jug numbers - keep in sync with the Jug system + docs/13 (memory
// jugg-health-numbers-sync; this is now a 5th sync site).
#define ACC_HP_PX_PER_HP 0.4   // roster health-bar scale: px per HP (300 HP Mega = 120 px full, no-Jug 100 HP = 40 px). (user 2026-06-27: reverted a 0.8 doubling - the original 0.4 was fine.)
#define ACC_HP_TIER_BASE 100   // base max HP (no perks) -> end of the green segment
#define ACC_HP_TIER_JUG  250   // max HP with Juggernog (base + 150) -> end of the darker-green segment
#define ACC_HP_TIER_MEGA 300   // max HP with Mega Jug (+50) -> end of the dark-green segment
#define ACC_HP_SEG_H     8     // roster health-bar segment height, px
#define ACC_HP_BAR_SLIDE 0.3   // seconds the roster bar GLIDES to a new width (user 2026-06-27: slide like the round bar, don't snap on each hit). Lower = snappier; 0 would snap.

#namespace acc_health_bars;

function init()
{
    acc_utility::log( "health_bars: init" );
    level thread player_bars_loop();
    level thread boss_bar_listener();
    // Through-walls zombie waypoints are a DEV/QA aid only - gate on the one dev switch so a ship
    // build never shows them (was hardcoded-on; user 2026-06-22, one-flag migration).
    if ( IS_TRUE( level.acc_dev ) )
        level thread zombie_wallhack_loop();
}

// ---------------------------------------------------------------------------
// Player health bar (per player)
// ---------------------------------------------------------------------------

function player_bars_loop()
{
    level endon( "end_game" );
    level flag::wait_till( "initial_blackscreen_passed" );

    for ( ;; )
    {
        players = GetPlayers();
        for ( i = 0; i < players.size; i++ )
        {
            p = players[ i ];
            if ( !isdefined( p ) || !isplayer( p ) ) continue;
            // Single solo health bar REPLACED by the co-op SQUAD roster (user 2026-06-26): the roster's
            // own row IS this player's health, so the standalone bar would just double-draw. The old
            // ensure/update_player_bar are kept (dormant) in the file in case we want the big solo bar back.
            ensure_roster( p );
            update_roster( p );
            ensure_round_counter( p );   // top-left round counter (user 2026-06-26)
            update_round_counter( p );
        }
        wait 0.1;
    }
}

// Top-left ROUND counter (user 2026-06-27): "Round N" on ONE line, inset from the corner, in the space the old
// shards/exo/bottles stack used to occupy (those moved into the per-player SQUAD roster). Per-player hudelem.
function ensure_round_counter( p )
{
    if ( isdefined( p.acc_round_hud ) ) return;

    // ONE element, "Round N" on a single line, inset from the top-left corner (user 2026-06-27: was a stacked
    // "ROUND" label over a big number tight in the corner). The round number is BOUNDED (<=~255 distinct over a
    // match), so SetText "Round " + N is BG-cache-safe (change-guarded in update_round_counter) - no need to
    // split a label + SetValue. ACC_ROUND_HUD_X/Y/SCALE are the inset + size; flashes on round change.
    p.acc_round_hud = p hud::createFontString( "default", 1.6 );
    p.acc_round_hud hud::setPoint( "TOP_LEFT", "TOP_LEFT", 40, 30 );
    p.acc_round_hud.alignX = "left";
    p.acc_round_hud.alignY = "top";
    p.acc_round_hud.color = ( 0.3, 0.85, 1.0 );
    p.acc_round_hud.alpha = 0.95;
    p.acc_round_hud.hidewheninmenu = true;
}

function update_round_counter( p )
{
    if ( !isdefined( p.acc_round_hud ) ) return;
    rnd = ( isdefined( level.round_number ) ? level.round_number : 1 );
    if ( isdefined( p.acc_round_last ) && p.acc_round_last == rnd ) return;   // no change -> nothing to do

    // SetText "Round N" (one line). The round number is BOUNDED (<=~255 distinct), so - unlike the unbounded
    // score - it can't overflow the 2048 'string' BG-cache; the change-guard above re-registers only once per
    // round. Flash on the round change (setPulseFX(speed, sustainMs, decayMs) = the Mega-badge pulse).
    p.acc_round_hud SetText( "Round " + rnd );
    p.acc_round_hud setPulseFX( 80, 800, 700 );
    p.acc_round_last = rnd;
}

function ensure_player_bar( p )
{
    if ( isdefined( p.acc_hp_bar ) ) return;

    // BOTTOM-LEFT of screen (user 2026-06-26: moved from top-left into the cyber HUD, above the perk-icon
    // row). createBar is called ON the player -> per-player elem. Negative y on a BOTTOM anchor = up.
    p.acc_hp_label = p hud::createFontString( "default", 0.9 );
    p.acc_hp_label hud::setPoint( "BOTTOM_LEFT", "BOTTOM_LEFT", 16, -76 );
    p.acc_hp_label.alignX = "left";
    p.acc_hp_label.alignY = "bottom";
    p.acc_hp_label.color = ( 0.55, 0.9, 1.0 );   // cyber cyan label
    p.acc_hp_label.alpha = 0.7;
    p.acc_hp_label.hidewheninmenu = true;
    p.acc_hp_label SetText( "HEALTH" );

    make_player_bar( p, bar_width_for_hp( player_maxhp( p ) ) );

    // HP NUMERIC READOUT REMOVED (docs/50 D1, user 2026-06-22): the "current / max" text leaked the
    // Juggernog magnitude as a NUMBER. The bar now conveys the same thing VISUALLY (user 2026-06-24): its
    // WIDTH scales with max HP and its GREEN SHADE deepens with the Jug tier (see make_player_bar / hp_bar_color).
}

// Player max HP (Jug etc. update p.maxhealth; default 100 before it's set).
function player_maxhp( p )
{
    if ( !isdefined( p.maxhealth ) || p.maxhealth <= 0 ) return 100;
    return p.maxhealth;
}

// Bar WIDTH from max HP (user 2026-06-24): 1 px / HP by default -> no-Jug 100 / Jug 250 / Mega-Jug 300,
// so buying Jug visibly WIDENS the bar. Floored at 60, capped (acc_hp_bar_max_w, default 360) so a stacked
// max-health item can't run it off-screen. Live dvars acc_hp_bar_px_per_hp / acc_hp_bar_max_w.
function bar_width_for_hp( maxhp )
{
    w = int( maxhp * getdvarfloat( "acc_hp_bar_px_per_hp", 1.0 ) );
    if ( w < 60 ) w = 60;
    cap = getdvarint( "acc_hp_bar_max_w", 360 );
    if ( w > cap ) w = cap;
    return w;
}

// (Re)create the player HP bar at width w. createBar BAKES the width into the bg + fill, so a max-HP change
// = a rebuild (rare: only on a Jug/Mega buy, a max-health item, or perk loss on death - NOT every poll).
function make_player_bar( p, w )
{
    if ( isdefined( p.acc_hp_bar ) )
    {
        if ( isdefined( p.acc_hp_bar.bar ) ) p.acc_hp_bar.bar Destroy();
        if ( isdefined( p.acc_hp_bar.barFrame ) ) p.acc_hp_bar.barFrame Destroy();   // leak fix (user 2026-06-27 audit): createBar = 3 elems; the frame child was never freed on rebuild
        p.acc_hp_bar Destroy();
    }
    p.acc_hp_bar = p hud::createBar( ( 0.25, 0.90, 0.30 ), w, ACC_PLAYER_BAR_H );
    p.acc_hp_bar hud::setPoint( "TOP_LEFT", "TOP_LEFT", 16, 32 );
    p.acc_hp_bar.alpha = 0.85;
    p.acc_hp_bar.hidewheninmenu = true;
    p.acc_hp_bar_w = w;
}

function update_player_bar( p )
{
    if ( !isdefined( p.acc_hp_bar ) ) return;

    maxhp = player_maxhp( p );

    // WIDTH scales with MAX health (user 2026-06-24): a Jug / Mega-Jug buy (or a max-health item) visibly
    // WIDENS the bar so the extra health is readable at a glance. createBar bakes the width, so REBUILD only
    // when the target width changes (a perk/max-health change), never per poll.
    want_w = bar_width_for_hp( maxhp );
    if ( !isdefined( p.acc_hp_bar_w ) || p.acc_hp_bar_w != want_w )
        make_player_bar( p, want_w );

    frac = p.health / maxhp;
    if ( frac < 0 ) frac = 0;
    if ( frac > 1 ) frac = 1;

    // Smooth: SLIDE the fill to the new health instead of snapping (was hud::updateBar).
    acc_set_bar_smooth( p.acc_hp_bar, frac, 0.25 );
    // createBar returns the BG; the colored fill is .bar - recolor THAT (by Jug tier).
    if ( isdefined( p.acc_hp_bar.bar ) )
        p.acc_hp_bar.bar.color = hp_bar_color( p, frac );
}

// Bar fill colour. TEAL SHADE by Juggernog tier (user 2026-06-26 cyber HUD) so the bar SHOWS the perk
// benefit: no Jug = bright teal, Jug = deeper teal, Mega Jug = deepest teal. A critical-HP MAGENTA
// override stays (<=33% = one hit from down) - matches the round-ring danger hue. Mega flag read off the
// player field (player.acc_mega_perks, owned by _acc_mega_bottles) to avoid a cross-module #using.
function hp_bar_color( player, frac )
{
    if ( frac <= 0.33 ) return ( 0.90, 0.20, 0.55 );                                 // critical - about to go down (cyber magenta)
    if ( isdefined( player.acc_mega_perks ) && IS_TRUE( player.acc_mega_perks[ "specialty_armorvest" ] ) )
        return ( 0.06, 0.45, 0.50 );                                                 // Mega Jug - deepest teal
    if ( player HasPerk( "specialty_armorvest" ) )
        return ( 0.12, 0.70, 0.72 );                                                 // Jug - deeper teal
    return ( 0.20, 0.95, 0.85 );                                                     // no Jug - bright teal
}

// Smoothly SLIDE a stock createBar fill to `frac` over `dur` seconds instead of the instant
// width snap stock hud::updateBar does (it setShaders the fill to the new width every call).
// We drive the fill HudElem (.bar) with scaleOverTime - the SAME engine call stock
// updateBarScale uses for its rateOfChange path (hud_util_shared.gsc) - so the bar GLIDES to
// the new value rather than jumping. The first touch snaps (establishes the size); after that
// every change animates. Re-issues only when the target width actually changes, so a fast
// poll calling this each tick is cheap and doesn't restart the glide on no-ops.
function acc_set_bar_smooth( bar_bg, frac, dur )
{
    if ( !isdefined( bar_bg ) || !isdefined( bar_bg.bar ) ) return;
    if ( frac < 0 ) frac = 0;
    if ( frac > 1 ) frac = 1;
    if ( !isdefined( dur ) || dur <= 0 ) dur = 0.25;

    fill = bar_bg.bar;
    target_w = int( bar_bg.width * frac + 0.5 );
    if ( target_w < 1 ) target_w = 1;

    if ( !isdefined( fill.acc_shown_w ) )
    {
        // First touch: snap to the current width so the glide starts from the right place.
        fill setShader( fill.shader, target_w, bar_bg.height );
        fill.acc_shown_w = target_w;
        fill.frac = frac;
        return;
    }
    if ( fill.acc_shown_w == target_w ) return;   // unchanged -> don't restart the slide

    fill scaleOverTime( dur, target_w, bar_bg.height );
    fill.acc_shown_w = target_w;
    fill.frac = frac;
}

// ---------------------------------------------------------------------------
// Co-op SQUAD roster (bottom-left): every player's NAME + health bar + shards / MB / EXO / points
// ---------------------------------------------------------------------------
// Server-side GSC HUDELEMS, so the local player's roster shows EVERY player's stats with ZERO clientfields.
// POOL-CRITICAL (user 2026-06-26): hudelems draw from a SHARED, fixed engine pool. The first cut created 4
// rows x 6 elems (hud::createBar is THREE hudelems!) = 24/player; x4 players in co-op = ~96, which EXHAUSTED
// the pool so every LATER lazily-created hudelem (trench warning, glitch purge, boss bars...) silently failed
// to appear. This version is LEAN: rows are created LAZILY (only for CONNECTED players) and each row is just
// 3 hudelems - NAME (SetPlayerNameString) + a single-icon health bar + one merged stats line. Down = RED bar.
function ensure_roster( p )
{
    if ( !isdefined( p.acc_roster ) ) p.acc_roster = [];   // rows themselves are made lazily (ensure_roster_row)
}

// Clamp an int to [lo, hi] - used to cap the health-bar width at the 300-HP max.
function hp_clamp( v, lo, hi )
{
    if ( v < lo ) return lo;
    if ( v > hi ) return hi;
    return v;
}

// Create ONE roster health-bar tier segment (a left-anchored "white" icon). Used 3x per row by ensure_roster_row.
function make_hp_seg( p, w, x, y )
{
    seg = p hud::createIcon( "white", w, ACC_HP_SEG_H );
    seg hud::setPoint( "BOTTOM_LEFT", "BOTTOM_LEFT", x, y );
    seg.alignX = "left";
    seg.alignY = "bottom";
    seg.alpha = 0;
    seg.hidewheninmenu = true;
    return seg;
}

// Set the health bar to width w (px) + colour col + alpha a. The width GLIDES to its new value over
// ACC_HP_BAR_SLIDE sec (scaleOverTime - the same engine call the boss bars use via acc_set_bar_smooth), so the
// bar SLIDES as HP changes instead of snapping on every zombie hit (user 2026-06-27, for all 4 roster rows). The
// FIRST touch snaps (setShader) to establish the size; after that each width change animates. acc_w tracks the
// TARGET width so a steady value doesn't restart the glide every 0.1s tick. NULL-SAFE: if the elem failed to
// allocate (pool full in deep co-op), seg is undefined - bail (the row is also skipped by row_complete).
function update_hp_seg( seg, w, col, a )
{
    if ( !isdefined( seg ) ) return;
    if ( w < 1 )
    {
        seg.alpha = 0;
        return;
    }
    if ( !isdefined( seg.acc_w ) )
    {
        seg setShader( "white", w, ACC_HP_SEG_H );                   // first touch: snap to establish the size
        seg.acc_w = w;
    }
    else if ( seg.acc_w != w )
    {
        seg scaleOverTime( ACC_HP_BAR_SLIDE, w, ACC_HP_SEG_H );       // GLIDE to the new width (slides, no snap)
        seg.acc_w = w;
    }
    seg.color = col;
    seg.alpha = a;
}

// True only if ALL 7 of a row's hudelems allocated. In deep 4-player co-op the per-client hudelem pool can fill
// mid-creation (7/row x 4 = 28, near the ~31-ish engine cap), leaving a row with some undefined elems. update_roster
// skips (hides) any incomplete row rather than touch an undefined elem - so a full pool DEGRADES (a row may not show)
// but never CRASHES. memory server-hudelem-pool-exhaustion-coop.
function row_complete( row )
{
    if ( !isdefined( row ) ) return false;
    return ( isdefined( row.name )  && isdefined( row.bar_base ) && isdefined( row.dollar ) && isdefined( row.points ) &&
             isdefined( row.stats ) && isdefined( row.exomb )    && isdefined( row.perks ) );
}

// Lazily allocate ONE player row's hudelems (7 total: name, single health bar, "$", points-number, SH-text,
// EXO/MB-text, perks-text). Called from update_roster only when a slot is occupied, so solo allocates 7, a 4-player
// game 28 - down from the 9/row (36) tiered-bar version that overflowed the per-client pool and starved the round
// counter / Paradise timer / boss bars / song banner (user 2026-06-27, memory server-hudelem-pool-exhaustion-coop).
// Each player is a 4-LINE BLOCK: LINE 1 = name, LINE 2 = single health bar, LINE 3 = "$points SH EXO MB", LINE 4 = perks.
function ensure_roster_row( p, i )
{
    // Each player = a 4-LINE BLOCK, stacked bottom-up (you = i 0 = bottom), spaced by a clear gap: LINE 1 (top)
    // = name, LINE 2 = health bar, LINE 3 = stats, LINE 4 (bottom) = perks (under the currency line, user
    // 2026-06-27). All LEFT-anchored at x=12. y is from BOTTOM_LEFT, more negative = higher.
    base    = 70;                                  // bottom block's distance from screen bottom (user 2026-06-27: lowered 90->70 so the taller 4-line stack rides lower; still clears the perk bar, top at hudelem ~47)
    block_h = 63;                                  // 4 lines (name/bar/stats/perks) + a ~23px gap between players (user 2026-06-27: more padding between players; inter-player gap > within-block line spacing, so each player's lines read as one group)
    perks_y = -( base + i * block_h );             // LINE 4 (bottom) = perks (under the currency line)
    stats_y = -( base + i * block_h + 14 );        // LINE 3 = stats
    bar_y   = -( base + i * block_h + 27 );        // LINE 2 = health bar
    name_y  = -( base + i * block_h + 40 );        // LINE 1 (top) = name (block content = 40 tall, so the ~18px inter-player gap clearly separates players)

    row = spawnstruct();

    // LINE 1 (top): name, left-anchored at x=12.
    row.name = p hud::createFontString( "default", 1.0 );
    row.name hud::setPoint( "BOTTOM_LEFT", "BOTTOM_LEFT", 12, name_y );
    row.name.alignX = "left";
    row.name.alignY = "bottom";
    row.name.alpha = 0;
    row.name.hidewheninmenu = true;

    // LINE 2: ONE single health bar (user 2026-06-27: reverted the 3-segment tiered bar back to 1 elem/row to free
    // the per-client hudelem pool - the tiered bar x4 rows overflowed it in 4-player and starved the round counter /
    // Paradise timer / boss bars / song banner). WIDTH = current HP * ACC_HP_PX_PER_HP (a Jug/Mega player's bar is
    // still LONGER), COLOUR = the player's Jug TIER (set in update_roster) so the tier reads by hue, not segments.
    // Created at the max (300 HP) width; setShader'd narrower as HP depletes.
    row.bar_base = make_hp_seg( p, int( ACC_HP_TIER_MEGA * ACC_HP_PX_PER_HP ), 12, bar_y );

    // LINE 3 (stats_y): ALL stats on ONE row, left-aligned at x=12 to line up with the name + bar, in the order
    // $POINTS  SH {shards}  EXO {e}  MB {m} (user 2026-06-27 - "all on the same row" + "$" prefix). FOUR hudelems
    // ("$" + the three below), because they CANNOT share a SetText string: POINTS (score) is unbounded (->millions
    // every kill), so it MUST be SetValue (a
    // SetText score mints a permanent 'string' BG-cache entry per distinct value -> "Exceeded '2048' items" CTD);
    // shards is EXACT (~501 distinct - its own SetText, safe alone); and combining shards with EXO+MB would
    // MULTIPLY the cache (501 x 11 x 26 >> 2048), so EXO+MB share a THIRD SetText (11 x 26 = 286, safe). The pool
    // budget for this 3rd elem came from reclaiming the 3 hidden top-left readouts (shards/exo/mb - see those
    // modules; alpha 0 didn't free them). The two TEXT elems are repositioned in update_roster to flow right after
    // the variable-width points / shards numbers (dynamic estimate - see ACC_ROSTER_STAT_CHARW).
    // "$" prefix (user 2026-06-27): a CONSTANT 1-char SetText at x=12, with the POINTS number right after it, so
    // line 3 reads "$<points> ...". The "$" is its own elem because the score MUST stay SetValue (an unbounded
    // SetText score = 2048-cache CTD) and SetValue has no text prefix. Pool budget is fine - the big solo health
    // bar (ensure_player_bar) is dormant, and the 3 hidden top-left readouts were reclaimed.
    row.dollar = p hud::createFontString( "default", 1.0 );
    row.dollar hud::setPoint( "BOTTOM_LEFT", "BOTTOM_LEFT", 12, stats_y );
    row.dollar.alignX = "left";
    row.dollar.alignY = "bottom";
    row.dollar SetText( "$" );   // constant - set once, never re-registers in the BG-cache
    row.dollar.alpha = 0;
    row.dollar.hidewheninmenu = true;

    row.points = p hud::createFontString( "default", 1.0 );   // POINTS number (right after the "$"), SetValue = zero cache cost
    row.points hud::setPoint( "BOTTOM_LEFT", "BOTTOM_LEFT", ACC_ROSTER_POINTS_X, stats_y );
    row.points.alignX = "left";
    row.points.alignY = "bottom";
    row.points.alpha = 0;
    row.points.hidewheninmenu = true;

    row.stats = p hud::createFontString( "default", 1.0 );   // "SH {shards}" - repositioned after the points number
    row.stats hud::setPoint( "BOTTOM_LEFT", "BOTTOM_LEFT", 60, stats_y );   // PLACEHOLDER x (set in update_roster)
    row.stats.alignX = "left";
    row.stats.alignY = "bottom";
    row.stats.alpha = 0;
    row.stats.hidewheninmenu = true;

    row.exomb = p hud::createFontString( "default", 1.0 );   // "EXO {e}  MB {m}" - repositioned after the shards text
    row.exomb hud::setPoint( "BOTTOM_LEFT", "BOTTOM_LEFT", 120, stats_y );   // PLACEHOLDER x (set in update_roster)
    row.exomb.alignX = "left";
    row.exomb.alignY = "bottom";
    row.exomb.alpha = 0;
    row.exomb.hidewheninmenu = true;
    row.acc_stats_y = stats_y;   // stored so update_roster can re-setPoint the text elems at the correct y

    // LINE 4 (perks_y, bottom): owned-perk abbreviations, left-aligned at x=12 under the currency line (user
    // 2026-06-27). Each abbrev is colour-coded inline: ^1=red (base) / ^5=teal (mega). BG-cache-safe: the perk
    // set is BOUNDED (a player accumulates perks; ~tens of distinct strings over a match) and change-guarded.
    // (Icons aren't possible here - the Ronan perk art is LUI `image,` assets, and a server hudelem needs a
    // material this usermap can't build; abbreviations are the server-side path - memory hud-custom-image-lui-not-material.)
    row.perks = p hud::createFontString( "small", 1.0 );   // "small" font = smaller than the other lines (user 2026-06-27; scale <1.0 can't shrink it - it floors at ~1.0 and renders HUGE below, so use a smaller font instead)
    row.perks hud::setPoint( "BOTTOM_LEFT", "BOTTOM_LEFT", 12, perks_y );
    row.perks.alignX = "left";
    row.perks.alignY = "bottom";
    row.perks.alpha = 0;
    row.perks.hidewheninmenu = true;

    p.acc_roster[ i ] = row;
    return row;
}

function hide_roster_row( row )
{
    if ( !isdefined( row ) ) return;
    if ( isdefined( row.name ) )     row.name.alpha     = 0;
    if ( isdefined( row.bar_base ) ) row.bar_base.alpha = 0;
    if ( isdefined( row.dollar ) )   row.dollar.alpha   = 0;
    if ( isdefined( row.stats ) )  row.stats.alpha  = 0;
    if ( isdefined( row.exomb ) )  row.exomb.alpha  = 0;
    if ( isdefined( row.points ) ) row.points.alpha = 0;
    if ( isdefined( row.perks ) )  row.perks.alpha  = 0;
}

// Owned-perk abbreviations for the roster's LINE 4. Each owned perk -> "^1ABBR" (base, red) or "^5ABBR"
// (mega, teal). Reads HasPerk + the q.acc_mega_perks field directly (no cross-module #using). The set is
// BOUNDED (perks accumulate; ~tens of distinct strings over a match) so SetText is BG-cache-safe. The specialty
// list mirrors _acc_perk_doors::get_perk_door_specs (PhD hijacks specialty_electriccherry; EC = combat_efficiency).
function roster_perk_string( q )
{
    specs = array( "specialty_armorvest", "specialty_quickrevive", "specialty_fastreload", "specialty_doubletap2",
                   "specialty_staminup", "specialty_additionalprimaryweapon", "specialty_deadshot",
                   "specialty_widowswine", "specialty_electriccherry", "specialty_combat_efficiency" );
    abbrs = array( "JUG", "QR", "SPD", "DT", "STM", "MULE", "DEAD", "WW", "PHD", "EC" );

    s = "";
    for ( i = 0; i < specs.size; i++ )
    {
        if ( !( q HasPerk( specs[ i ] ) ) ) continue;
        mega = ( isdefined( q.acc_mega_perks ) && isdefined( q.acc_mega_perks[ specs[ i ] ] ) && q.acc_mega_perks[ specs[ i ] ] == true );
        if ( s != "" ) s += " ";
        s += ( mega ? "^5" : "^1" ) + abbrs[ i ];   // ^5 = teal (mega), ^1 = red (base)
    }
    return s;
}

// A random fake gamertag for a DEV MOCK roster row (so the mock squad doesn't all show YOUR name). Picked once
// per row and cached on row.acc_mock_tag, so it stays stable (no per-tick churn). Bounded list -> BG-cache-safe.
function mock_gamertag()
{
    tags = array( "xX_N0Sc0pe_Xx", "GhostByte_99", "ZombieJuggler", "TrickShotTariq", "M0nsterMash", "PixelPariah",
                  "QuadFeedQuinn", "B0neCollector", "VoidWalker7", "NeonNomad", "Gl1tchG0blin", "Sp4wnCamper",
                  "CrypticCarl", "HexHunter", "ByteBrawler", "L00tG0blin" );
    return tags[ randomint( tags.size ) ];
}

// Digit count of a non-negative int (used to estimate the stats-text width so the points number can be placed
// right after the "$"). shards are <= ACC_SHARDS_MAX (500) so <=3, but handle 4 for safety.
function num_digits( n )
{
    if ( n < 0 ) n = -n;
    if ( n < 10 ) return 1;
    if ( n < 100 ) return 2;
    if ( n < 1000 ) return 3;
    return 4;
}

function update_roster( p )
{
    if ( !isdefined( p.acc_roster ) ) p.acc_roster = [];

    players = GetPlayers();
    // YOU first (row 0 = bottom), then real teammates.
    ordered = [];
    ordered[ 0 ] = p;
    n = 1;
    for ( i = 0; i < players.size; i++ )
    {
        q = players[ i ];
        if ( isdefined( q ) && isplayer( q ) && q != p )
        {
            ordered[ n ] = q;
            n++;
        }
    }

    // DEV mock squad (gated on level.acc_dev) so the 4-row layout is testable solo: rows 1..3 reuse YOUR name
    // with fixed mock stats. Normal play shows ONLY connected players (lazy rows -> pool-frugal).
    dev   = IS_TRUE( level.acc_dev );
    shown = ( dev ? 4 : ordered.size );
    if ( shown > 4 ) shown = 4;

    for ( i = 0; i < 4; i++ )
    {
        is_real = ( i < ordered.size && isdefined( ordered[ i ] ) && isplayer( ordered[ i ] ) );

        if ( i >= shown )
        {
            if ( isdefined( p.acc_roster[ i ] ) ) hide_roster_row( p.acc_roster[ i ] );
            continue;
        }

        // Lazy-create this row's hudelems only now that the slot is occupied.
        row = ( isdefined( p.acc_roster[ i ] ) ? p.acc_roster[ i ] : ensure_roster_row( p, i ) );
        is_you = ( i == 0 );
        // CRASH-SAFE: if the per-client hudelem pool filled mid-create (deep 4-player), this row has undefined
        // elems - hide it and skip rather than touch them (degrade, never crash). See row_complete.
        if ( !row_complete( row ) ) { hide_roster_row( row ); continue; }

        if ( is_real )
        {
            q = ordered[ i ];
            named_ent = q;
            // Player STATE drives the bar COLOUR (user 2026-06-27): laststand = DOWNED (red), bled out = DEAD
            // (gray), else ALIVE (green/teal, width scaled by HP). laststand is checked FIRST - a downed player
            // still reads isalive() true (low health, revivable); only after they bleed out does isalive() go false.
            if ( IS_TRUE( q.laststand ) )   state = 1;        // downed - last stand (_zm_laststand.gsc:200)
            else if ( !isalive( q ) )       state = 2;        // dead - bled out / spectating
            else                            state = 0;        // alive
            maxhp   = player_maxhp( q );
            frac    = q.health / maxhp;
            if ( frac < 0 ) frac = 0;
            if ( frac > 1 ) frac = 1;
            shards  = ( isdefined( q.acc_data_shards ) ? q.acc_data_shards : 0 );
            bottles = ( isdefined( q.acc_mega_bottles ) ? q.acc_mega_bottles : 0 );
            exo     = ( isdefined( q.acc_exo_tier ) ? q.acc_exo_tier : 0 );
            points    = ( isdefined( q.score ) ? q.score : 0 );   // reading .score is fine (writes use zm_score)
            perks_str = roster_perk_string( q );
        }
        else
        {
            // DEV mock teammate: a RANDOM fake gamertag (picked ONCE, then stable) + fixed stats, varied health.
            if ( !isdefined( row.acc_mock_tag ) ) row.acc_mock_tag = mock_gamertag();
            // DEV mock states so all three bar colours are visible solo: rows 0/1 = alive, row 2 = DOWNED (red),
            // row 3 = DEAD (gray). (user 2026-06-27)
            state   = ( i == 2 ? 1 : ( i == 3 ? 2 : 0 ) );
            frac    = 1.0 - ( i * 0.25 );
            if ( frac < 0.10 ) frac = 0.10;
            maxhp   = ( i == 2 ? ACC_HP_TIER_JUG : ACC_HP_TIER_MEGA );   // mock max HP: row 2 = Jug capacity, others = Mega
            if ( i == 1 ) frac = 0.95 - 0.80 * ( ( GetTime() % 5000 ) / 5000.0 );   // DEV demo: the alive mock drains/refills over 5s so you can SEE a teammate bar SLIDE (not snap)
            shards  = 100 + i * 75;
            bottles = i * 3;
            exo     = i * 2;
            points  = 5000 + i * 2500;
            // DEV mock perks: row 1 = ALL 10 perks (alternating red base / teal mega - tests the full line +
            // both colours); rows 2/3 = shorter mixes. (user 2026-06-27)
            perks_str = ( i == 1 ? "^1JUG ^5QR ^1SPD ^5DT ^1STM ^5MULE ^1DEAD ^5WW ^1PHD ^5EC"
                        : ( i == 2 ? "^5JUG ^5QR ^1STM ^1WW" : "^1JUG ^1QR" ) );
        }

        // NAME: a REAL player resolves its live gamertag via SetPlayerNameString; a DEV MOCK shows a random
        // fake tag via SetText (picked once in the mock branch, so it's stable - no churn, BG-cache-safe).
        if ( is_real )
        {
            if ( !isdefined( row.acc_named ) || row.acc_named != named_ent )
            {
                row.name SetPlayerNameString( named_ent );
                row.acc_named = named_ent;
                row.acc_mock_named = false;
            }
        }
        else if ( !IS_TRUE( row.acc_mock_named ) )
        {
            row.name SetText( row.acc_mock_tag );
            row.acc_mock_named = true;
            row.acc_named = undefined;   // re-apply SetPlayerNameString if this slot later becomes a real player
        }
        if ( state == 1 )      row.name.color = ( 1.0, 0.30, 0.30 );    // downed = red name
        else if ( state == 2 ) row.name.color = ( 0.55, 0.55, 0.58 );   // dead = gray name
        else if ( is_you )     row.name.color = ( 0.20, 0.95, 0.85 );   // you = teal
        else                   row.name.color = ( 0.55, 0.80, 0.95 );   // teammate = dim cyan
        row.name.alpha = ( is_you ? 1.0 : 0.85 );

        // Health bar = ONE single bar (user 2026-06-27: reverted from 3 tier segments to free the per-client pool).
        // WIDTH = current HP * ppHP (a Jug/Mega player's bar is still LONGER). COLOUR conveys the Jug TIER by hue:
        // no-Jug bright green / Jug deeper green / Mega darkest green (from maxhealth); AMBER when nearly out (<=30),
        // RED downed, GRAY dead. DOWNED/DEAD fill by MAX HP (full bar) so the state colour reads clearly.
        fillhp = ( state == 0 ? int( frac * maxhp + 0.5 ) : maxhp );
        bar_w  = int( hp_clamp( fillhp, 0, ACC_HP_TIER_MEGA ) * ACC_HP_PX_PER_HP + 0.5 );   // cap at the 300-HP max width
        bar_a  = ( is_you ? 0.95 : 0.8 );
        if ( state == 1 )                     bar_col = ( 1.0, 0.18, 0.18 );    // DOWNED - red
        else if ( state == 2 )                bar_col = ( 0.42, 0.42, 0.45 );   // DEAD - gray
        else if ( fillhp <= 30 )              bar_col = ( 0.95, 0.65, 0.15 );   // critically low - amber
        else if ( maxhp >= ACC_HP_TIER_MEGA ) bar_col = ( 0.08, 0.40, 0.13 );   // Mega Jug - darkest green
        else if ( maxhp >= ACC_HP_TIER_JUG )  bar_col = ( 0.16, 0.60, 0.20 );   // Jug - deeper green
        else                                  bar_col = ( 0.30, 0.85, 0.35 );   // no Jug - bright green
        update_hp_seg( row.bar_base, bar_w, bar_col, bar_a );

        // LINE 3 = ALL stats on ONE row: POINTS  SH {shards}  EXO {e}  MB {m} (user 2026-06-27). THREE hudelems
        // (see ensure_roster_row for why they can't share a SetText - unbounded score must be SetValue; exact
        // shards x EXO x MB would overflow the 2048 'string' cache). POINTS is SetValue at the fixed left x=12
        // (zero cache cost). The two TEXT elems (SH, EXO/MB) are bounded SetText, change-guarded. All three render
        // dimmed for teammates via the alpha block below.
        row.points SetValue( points );

        sh_txt = "SH " + shards;                                             // shards EXACT (<=501 distinct, safe alone)
        em_txt = "EXO " + exo + "   MB " + bottles;                           // EXO x MB = 286 distinct, safe
        if ( !isdefined( row.acc_stats_txt ) || row.acc_stats_txt != sh_txt )
        {
            row.stats SetText( sh_txt );
            row.acc_stats_txt = sh_txt;
        }
        if ( !isdefined( row.acc_exomb_txt ) || row.acc_exomb_txt != em_txt )
        {
            row.exomb SetText( em_txt );
            row.acc_exomb_txt = em_txt;
        }

        // Re-flow the two TEXT elems to sit just after the variable-width POINTS / SH numbers. GSC has no
        // text-width API, so x is estimated from the digit counts (see ACC_ROSTER_STAT_CHARW). Guard on the digit
        // COUNTS (packed in sig), not the values: points changes every kill but its digit count rarely, so this
        // re-setPoint is rare - not every tick.
        pts_d = num_digits( points );
        sh_d  = 3 + num_digits( shards );                                     // rendered len of "SH " + shards
        sig   = pts_d * 100 + sh_d;
        if ( !isdefined( row.acc_line3_sig ) || row.acc_line3_sig != sig )
        {
            row.acc_line3_sig = sig;
            sh_x = ACC_ROSTER_POINTS_X + int( pts_d * ACC_ROSTER_STAT_CHARW ) + ACC_ROSTER_FIELD_GAP;   // after the "$<points>"
            em_x = sh_x + int( sh_d  * ACC_ROSTER_STAT_CHARW ) + ( ACC_ROSTER_FIELD_GAP - 2 );             // after "SH {shards}" - SH->EXO gap trimmed a touch tighter than the $->SH gap (user 2026-06-27)
            row.stats hud::setPoint( "BOTTOM_LEFT", "BOTTOM_LEFT", sh_x, row.acc_stats_y );
            row.exomb hud::setPoint( "BOTTOM_LEFT", "BOTTOM_LEFT", em_x, row.acc_stats_y );
        }

        // LINE 4 = perks only now (EXO/MB moved up to the one-row stats line above). perks_str is the abbreviation
        // string built in the real/mock branch; left as-is here.

        // LINE 4 perks: change-guarded SetText (bounded set -> BG-cache-safe). Colours are inline ^1/^5 codes,
        // so .color isn't needed; alpha dims teammates like the other lines.
        if ( !isdefined( row.acc_perks_str ) || row.acc_perks_str != perks_str )
        {
            row.perks SetText( perks_str );
            row.acc_perks_str = perks_str;
        }

        a = ( is_you ? 1.0 : 0.85 );
        row.dollar.color = ( 0.55, 0.95, 0.70 ); row.dollar.alpha = a;   // soft green "$" so it reads as money
        row.stats.color  = ( 0.78, 0.92, 1.0 ); row.stats.alpha  = a;
        row.exomb.color  = ( 0.78, 0.92, 1.0 ); row.exomb.alpha  = a;
        row.points.color = ( 0.78, 0.92, 1.0 ); row.points.alpha = a;
        row.perks.alpha  = a;
    }
}

// ---------------------------------------------------------------------------
// Boss health bar + nameplate (shared / server)
// ---------------------------------------------------------------------------

function boss_bar_listener()
{
    level endon( "end_game" );
    for ( ;; )
    {
        level waittill( "acc_boss_spawned", boss, name );
        // PARADISE FINALE (user 2026-06-25): suppress the boss HUD for the whole onslaught - a Phantom spawns
        // every minute and would spam boss bars/nameplates over the survival countdown. The gate is the level
        // flag level.acc_paradise_onslaught (set by _acc_paradise::start_onslaught).
        if ( IS_TRUE( level.acc_paradise_onslaught ) )
            continue;
        if ( isdefined( boss ) )
            level thread boss_bar_track( boss, name );
    }
}

// Boss health bar (per player): a real DEPLETING bar + name label at top-center of the
// screen (remaining/max), reusing the SAME proven path as the player health bar -
// hud::createBar (bg + .bar fill, sized by hud::updateBar). A SCREEN elem (not a
// waypoint) can actually shrink in width. The over-boss world marker was removed per
// user request - just the top bar now.
function boss_bar_track( boss, name )
{
    level endon( "end_game" );
    if ( !isdefined( boss ) ) return;
    if ( !isdefined( name ) ) name = "BOSS";
    if ( !isdefined( boss.maxhealth ) || boss.maxhealth <= 0 ) boss.maxhealth = boss.health;

    sets = [];
    players = GetPlayers();
    for ( i = 0; i < players.size; i++ )
        sets[ sets.size ] = make_boss_bar_set( players[ i ], boss, name );

    // Also self-destroys the bar the instant the Paradise onslaught begins, so any boss bar already showing
    // when the finale starts is cleared too (user 2026-06-25).
    while ( isdefined( boss ) && isalive( boss ) && isdefined( boss.health ) && boss.health > 0
            && !IS_TRUE( level.acc_paradise_onslaught ) )
    {
        frac = boss.health / boss.maxhealth;
        if ( frac < 0 ) frac = 0;
        if ( frac > 1 ) frac = 1;
        col = boss_hp_color( frac );

        for ( i = 0; i < sets.size; i++ )
        {
            s = sets[ i ];
            if ( !isdefined( s ) ) continue;

            // (1) Screen bar - the real depleting health bar. Smooth: SLIDE to the new
            // value instead of snapping (was hud::updateBar).
            if ( isdefined( s.screen_bar ) )
            {
                acc_set_bar_smooth( s.screen_bar, frac, 0.25 );
                if ( isdefined( s.screen_bar.bar ) )
                    s.screen_bar.bar.color = col;
            }
        }

        // Late-join reconcile (user 2026-06-27 audit): the player set is snapshotted ONCE at boss spawn, so a
        // player who CONNECTS mid-fight (common in the long, ignore_enemy_count Subroutine Core fight) never got
        // a bar. Add ONE set for any connected player not already tracked - dedup by s.player so an existing
        // player is NEVER re-added (which would spam createBar hudelems). Cosmetic only.
        cur = GetPlayers();
        for ( pj = 0; pj < cur.size; pj++ )
        {
            cp = cur[ pj ];
            if ( !isdefined( cp ) || !isplayer( cp ) ) continue;
            seen = false;
            for ( si = 0; si < sets.size; si++ )
                if ( isdefined( sets[ si ] ) && isdefined( sets[ si ].player ) && sets[ si ].player == cp )
                    seen = true;
            if ( !seen )
                sets[ sets.size ] = make_boss_bar_set( cp, boss, name );
        }

        wait 0.1;
    }

    for ( i = 0; i < sets.size; i++ )
        destroy_boss_bar_set( sets[ i ] );
}

// Screen bar + name label, for one `player`.
function make_boss_bar_set( player, boss, name )
{
    s = SpawnStruct();

    // (1) Name label, top-center.
    s.label = player hud::createFontString( "objective", 1.5 );
    s.label hud::setPoint( "TOP", "TOP", 0, 22 );
    s.label.alignX = "center"; s.label.alignY = "top";
    s.label.color = ( 1, 0.85, 0.2 ); s.label.alpha = 0.95;
    s.label.hidewheninmenu = true;
    s.label SetText( "^1" + name );

    // (1) Depleting bar, top-center, just under the name (proven createBar path).
    s.screen_bar = player hud::createBar( boss_hp_color( 1.0 ), ACC_BOSS_BAR_W, ACC_BOSS_BAR_H );
    s.screen_bar hud::setPoint( "TOP", "TOP", 0, 46 );
    s.screen_bar.alpha = 0.9;
    s.screen_bar.hidewheninmenu = true;

    s.player = player;   // owner, for the late-join reconcile in boss_bar_track (user 2026-06-27 audit)
    return s;
}

// Boss bar tint: green (healthy) -> amber -> red (nearly dead).
function boss_hp_color( frac )
{
    if ( frac > 0.66 ) return ( 0.25, 0.9, 0.3 );
    if ( frac > 0.33 ) return ( 0.95, 0.78, 0.15 );
    return ( 0.95, 0.12, 0.12 );
}

function destroy_boss_bar_set( s )
{
    if ( !isdefined( s ) ) return;
    if ( isdefined( s.label ) ) s.label hud::destroyElem();
    if ( isdefined( s.screen_bar ) ) s.screen_bar hud::destroyElem();
}

// ---------------------------------------------------------------------------
// Zombie wallhack markers (QA: see every zombie through walls, incl. stuck ones)
// ---------------------------------------------------------------------------
// DEV-GATED (user 2026-06-22, one-flag migration): a small red through-walls waypoint floats over
// every live zombie so a stuck / broken-pathing one is always findable. Started from init() ONLY when
// IS_TRUE( level.acc_dev ) (see :41-42), so a SHIP build (acc_dev 0) NEVER allocates these. CRITICAL:
// this is ~1 NewClientHudElem PER LIVE ZOMBIE per client (dozens at once) - if it were ever ungated it
// would blow the per-client hudelem pool and silently kill other HUD (see memory
// server-hudelem-pool-exhaustion-coop). DO NOT hardcode on. Same proven recipe as the dev door markers
// (_acc_dev::create_door_marker): NewClientHudElem + SetShader("white",..) + SetWaypoint(true) +
// SetTargetEnt(zombie). "white" is an engine built-in material (no missing-asset risk).
//
// Discovery loop tags each new zombie once (z.acc_wh_tagged) and hands it to a LEVEL-scoped
// per-zombie manager (level thread, NOT a thread ON the zombie - so it survives the corpse being
// removed and can still destroy the player-owned HudElems).
function zombie_wallhack_loop()
{
    level endon( "end_game" );
    level flag::wait_till( "initial_blackscreen_passed" );

    for ( ;; )
    {
        team = ( isdefined( level.zombie_team ) ? level.zombie_team : "axis" );
        zombies = GetAITeamArray( team );

        // POOL CAP (user 2026-06-26): markers are 1 NewClientHudElem PER ZOMBIE per client - an uncapped horde
        // (~24) blows the per-client hudelem pool in DEV and silently starves other HUD (the Paradise finale
        // timer, perk cards, toasts - the prior UI-disappearance bug). Cap CONCURRENT markers at
        // ACC_WH_MARKER_CAP: count the tagged-alive zombies first, then only tag NEW ones up to the cap. When
        // few zombies remain (the stuck-hunt the markers exist for) all get marked; a full horde is capped.
        active = 0;
        for ( i = 0; i < zombies.size; i++ )
        {
            z = zombies[ i ];
            if ( isdefined( z ) && isalive( z ) && IS_TRUE( z.acc_wh_tagged ) ) active++;
        }

        for ( i = 0; i < zombies.size; i++ )
        {
            if ( active >= ACC_WH_MARKER_CAP ) break;
            z = zombies[ i ];
            if ( !isdefined( z ) || !isalive( z ) ) continue;
            if ( IS_TRUE( z.acc_wh_tagged ) ) continue;   // already managed
            z.acc_wh_tagged = true;
            level thread zombie_wallhack_one( z );
            active++;
        }
        wait 0.5;
    }
}

// One through-walls marker per connected player; refreshes for co-op late joins; destroys all
// markers once the zombie is dead/removed. markers[] is keyed by the player's entity number and
// kept LOCAL so cleanup works even after `zombie` goes undefined.
function zombie_wallhack_one( zombie )
{
    level endon( "end_game" );

    markers = [];
    while ( isdefined( zombie ) && isalive( zombie ) )
    {
        players = GetPlayers();
        for ( i = 0; i < players.size; i++ )
        {
            p = players[ i ];
            if ( !isdefined( p ) || !isplayer( p ) ) continue;
            key = p GetEntityNumber();
            if ( isdefined( markers[ key ] ) ) continue;
            markers[ key ] = create_zombie_marker( p, zombie );
        }
        wait 1;
    }

    keys = GetArrayKeys( markers );
    for ( i = 0; i < keys.size; i++ )
        if ( isdefined( markers[ keys[ i ] ] ) )
            markers[ keys[ i ] ] Destroy();
}

// Red square that tracks the zombie and shows through walls (off-screen arrow points toward it).
// "white" is the engine built-in material, tinted by .color.
function create_zombie_marker( player, zombie )
{
    elem = NewClientHudElem( player );
    elem.archived = false;
    elem.x = 0;
    elem.y = 0;
    elem.z = 64;                       // float above the zombie's origin
    elem.alpha = 0.85;
    elem.color = ( 1.0, 0.25, 0.18 );  // red = enemy
    elem SetShader( "white", ACC_WH_MARKER_SIZE, ACC_WH_MARKER_SIZE );  // small locator dot
    elem SetWaypoint( true );          // constant on-screen size + edge arrow when offscreen
    elem SetTargetEnt( zombie );
    return elem;
}
