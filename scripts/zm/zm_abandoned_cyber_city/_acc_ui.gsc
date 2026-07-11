// =============================================================================
// _acc_ui.gsc - reusable themed UI component library (server-HUD, v1)
//
// docs/11_controls_and_hud.md. One styled "card" renderer used by every touchpoint
// (perks, PaP, Mega, wallbuys, Cyberware nodes, ...) so they stay consistent
// and adding a touchpoint is data + one call. The renderer is server-HUD font
// strings + a translucent "white"-shader box (resized via setShader, per the
// confirmed hud_util_shared behavior); the call sites are renderer-agnostic, so
// a Phase-4 LUI swap won't touch them.
//
// Card layout (anchored right-center): [box] dark slate translucent panel;
// [strip] left-edge accent; [title] big; [price] gold; [lines] color-coded
// bullets. Height auto-fits the line count.
//
// API (self = player):
//   self acc_ui::card_show( title, title_color, price_text, lines[] )
//   self acc_ui::card_hide()
//   lines[] are pre-formatted strings, e.g. "^5- ^7Survive 6 hits".
// =============================================================================

#using scripts\shared\hud_util_shared;

#insert scripts\shared\shared.gsh;

#using scripts\zm\zm_abandoned_cyber_city\_acc_utility;

#define ACC_UI_W       300
#define ACC_UI_PAD     10
#define ACC_UI_TITLE_H 28
#define ACC_UI_PRICE_H 20
#define ACC_UI_LINE_H  18

#namespace acc_ui;

// self = player
function card_show( title, title_color, price_text, lines )
{
    card_ensure( self );
    // Pool-full guard (user 2026-06-29): the card is now CONDITIONAL (destroyed on hide to free the pool), so a
    // create can fail when the per-client hudelem pool is full -> skip drawing rather than touch an undefined elem
    // (degrade, never crash). Shows again next time you approach a buyable with room free.
    if ( !isdefined( self.acc_card_bg ) || !isdefined( self.acc_card_strip ) ||
         !isdefined( self.acc_card_title ) || !isdefined( self.acc_card_price ) ) return;

    self.acc_card_title SetText( title );
    if ( isdefined( title_color ) )
        self.acc_card_title.color = title_color;
    self.acc_card_strip.color = ( isdefined( title_color ) ? title_color : ( 0.4, 0.9, 1.0 ) );

    has_price = ( isdefined( price_text ) && price_text != "" );
    if ( has_price )
        self.acc_card_price SetText( price_text );

    n = ( isdefined( lines ) ? lines.size : 0 );
    card_lines( self, n );

    body_y0 = ACC_UI_PAD + ACC_UI_TITLE_H + ( has_price ? ACC_UI_PRICE_H : 0 );
    for ( i = 0; i < self.acc_card_lines.size; i++ )
    {
        if ( !isdefined( self.acc_card_lines[ i ] ) ) continue;   // pool-full: this line didn't allocate
        if ( i < n )
        {
            self.acc_card_lines[ i ] SetText( lines[ i ] );
            self.acc_card_lines[ i ] hud::setPoint( "TOP_LEFT", "TOP_LEFT", ACC_UI_PAD, body_y0 + i * ACC_UI_LINE_H );
            self.acc_card_lines[ i ].alpha = 0.92;
        }
        else
        {
            self.acc_card_lines[ i ].alpha = 0;
        }
    }

    // createIcon w/h are fixed at create; resize the DRAWN quad via setShader.
    h = body_y0 + n * ACC_UI_LINE_H + ACC_UI_PAD;
    self.acc_card_bg setShader( "white", ACC_UI_W, h );
    self.acc_card_strip setShader( "white", 3, h );

    self.acc_card_bg.alpha = 0.6;
    self.acc_card_strip.alpha = 0.9;
    self.acc_card_title.alpha = 1.0;
    self.acc_card_price.alpha = ( has_price ? 0.95 : 0 );
    self.acc_card_shown = true;
}

// self = player
function card_hide()
{
    if ( !isdefined( self.acc_card_bg ) ) return;

    // CONDITIONAL (user 2026-06-29): DESTROY the card hudelems to FREE their pool slots (was: alpha 0, which kept
    // ~4 + N line slots held for the whole match - the biggest persistent per-client consumer). Recreated by
    // card_ensure / card_lines on the next card_show. Children (strip/title/price/lines) are destroyed BEFORE the
    // bg parent. The bg-undefined guard above makes repeated hides idempotent (no churn).
    self.acc_card_shown = false;
    if ( isdefined( self.acc_card_lines ) )
    {
        for ( i = 0; i < self.acc_card_lines.size; i++ )
            if ( isdefined( self.acc_card_lines[ i ] ) ) self.acc_card_lines[ i ] Destroy();
    }
    self.acc_card_lines = [];
    if ( isdefined( self.acc_card_price ) ) { self.acc_card_price Destroy(); self.acc_card_price = undefined; }
    if ( isdefined( self.acc_card_title ) ) { self.acc_card_title Destroy(); self.acc_card_title = undefined; }
    if ( isdefined( self.acc_card_strip ) ) { self.acc_card_strip Destroy(); self.acc_card_strip = undefined; }
    self.acc_card_bg Destroy();
    self.acc_card_bg = undefined;
}

function card_ensure( p )
{
    if ( isdefined( p.acc_card_bg ) ) return;

    // Background panel (sort LOWEST so text draws over it). "white" = engine
    // built-in material, tinted by .color.
    p.acc_card_bg = p hud::createIcon( "white", ACC_UI_W, 10 );
    // [acc] COOP CRASH GUARD: createIcon returns undefined when the shared hudelem pool is full
    // (4-player exhaustion); the field writes below would throw on undefined. Bail - the card just
    // doesn't build this time (card_ensure retries next open once the pool frees). See _acc_utility::hud_msg_slot.
    if ( !isdefined( p.acc_card_bg ) ) return;
    p.acc_card_bg.alignX = "right";
    p.acc_card_bg.alignY = "middle";
    p.acc_card_bg hud::setPoint( "RIGHT", "RIGHT", -16, 0 );
    p.acc_card_bg.color = ( 0.05, 0.08, 0.12 );
    p.acc_card_bg.alpha = 0;
    p.acc_card_bg.sort = 1;
    p.acc_card_bg.foreground = true;
    p.acc_card_bg.hidewheninmenu = true;

    // Left accent strip (parented to the box so it moves/sizes with it).
    // [acc] COOP CRASH GUARD: card_bg is guaranteed defined here (guarded above), but the shared hudelem
    // pool can still fill BETWEEN these sub-element creates at 4p; each create is guarded so a pool-full
    // returns undefined without the following setParent/field writes throwing (card_show tolerates undefined).
    p.acc_card_strip = p hud::createIcon( "white", 3, 10 );
    if ( isdefined( p.acc_card_strip ) )
    {
        p.acc_card_strip hud::setParent( p.acc_card_bg );
        p.acc_card_strip hud::setPoint( "LEFT", "LEFT", 0, 0 );
        p.acc_card_strip.color = ( 0.4, 0.9, 1.0 );
        p.acc_card_strip.alpha = 0;
        p.acc_card_strip.sort = 2;
        p.acc_card_strip.foreground = true;
        p.acc_card_strip.hidewheninmenu = true;
    }

    p.acc_card_title = p hud::createFontString( "objective", 1.7 );
    if ( isdefined( p.acc_card_title ) )
    {
        p.acc_card_title hud::setParent( p.acc_card_bg );
        p.acc_card_title.alignX = "left";
        p.acc_card_title.alignY = "top";
        p.acc_card_title hud::setPoint( "TOP_LEFT", "TOP_LEFT", ACC_UI_PAD, ACC_UI_PAD );
        p.acc_card_title.color = ( 0.55, 0.85, 1.0 );
        p.acc_card_title.alpha = 0;
        p.acc_card_title.sort = 3;
        p.acc_card_title.foreground = true;
        p.acc_card_title.hidewheninmenu = true;
    }

    p.acc_card_price = p hud::createFontString( "default", 1.2 );
    if ( isdefined( p.acc_card_price ) )
    {
        p.acc_card_price hud::setParent( p.acc_card_bg );
        p.acc_card_price.alignX = "left";
        p.acc_card_price.alignY = "top";
        p.acc_card_price hud::setPoint( "TOP_LEFT", "TOP_LEFT", ACC_UI_PAD, ACC_UI_PAD + ACC_UI_TITLE_H );
        p.acc_card_price.color = ( 1.0, 0.85, 0.2 );
        p.acc_card_price.alpha = 0;
        p.acc_card_price.sort = 3;
        p.acc_card_price.foreground = true;
        p.acc_card_price.hidewheninmenu = true;
    }

    p.acc_card_lines = [];
}

function card_lines( p, count )
{
    while ( p.acc_card_lines.size < count )
    {
        idx = p.acc_card_lines.size;
        ln = p hud::createFontString( "default", 1.15 );
        if ( !isdefined( ln ) ) return;   // pool full - stop adding lines (card_show skips undefined entries)
        ln hud::setParent( p.acc_card_bg );
        ln hud::setPoint( "TOP_LEFT", "TOP_LEFT", ACC_UI_PAD, 0 ); // y assigned in card_show
        ln.alpha = 0;
        ln.sort = 3;
        ln.foreground = true;
        ln.hidewheninmenu = true;
        p.acc_card_lines[ idx ] = ln;
    }
}
