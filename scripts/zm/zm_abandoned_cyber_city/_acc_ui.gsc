// =============================================================================
// _acc_ui.gsc - reusable themed UI component library (server-HUD, v1)
//
// docs/27_ui_plan.md. One styled "card" renderer used by every touchpoint
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
    if ( !IS_TRUE( self.acc_card_shown ) ) return;

    self.acc_card_shown = false;
    self.acc_card_bg.alpha = 0;
    self.acc_card_strip.alpha = 0;
    self.acc_card_title.alpha = 0;
    self.acc_card_price.alpha = 0;
    if ( isdefined( self.acc_card_lines ) )
    {
        for ( i = 0; i < self.acc_card_lines.size; i++ )
            self.acc_card_lines[ i ].alpha = 0;
    }
}

function card_ensure( p )
{
    if ( isdefined( p.acc_card_bg ) ) return;

    // Background panel (sort LOWEST so text draws over it). "white" = engine
    // built-in material, tinted by .color.
    p.acc_card_bg = p hud::createIcon( "white", ACC_UI_W, 10 );
    p.acc_card_bg.alignX = "right";
    p.acc_card_bg.alignY = "middle";
    p.acc_card_bg hud::setPoint( "RIGHT", "RIGHT", -16, 0 );
    p.acc_card_bg.color = ( 0.05, 0.08, 0.12 );
    p.acc_card_bg.alpha = 0;
    p.acc_card_bg.sort = 1;
    p.acc_card_bg.foreground = true;
    p.acc_card_bg.hidewheninmenu = true;

    // Left accent strip (parented to the box so it moves/sizes with it).
    p.acc_card_strip = p hud::createIcon( "white", 3, 10 );
    p.acc_card_strip hud::setParent( p.acc_card_bg );
    p.acc_card_strip hud::setPoint( "LEFT", "LEFT", 0, 0 );
    p.acc_card_strip.color = ( 0.4, 0.9, 1.0 );
    p.acc_card_strip.alpha = 0;
    p.acc_card_strip.sort = 2;
    p.acc_card_strip.foreground = true;
    p.acc_card_strip.hidewheninmenu = true;

    p.acc_card_title = p hud::createFontString( "objective", 1.7 );
    p.acc_card_title hud::setParent( p.acc_card_bg );
    p.acc_card_title.alignX = "left";
    p.acc_card_title.alignY = "top";
    p.acc_card_title hud::setPoint( "TOP_LEFT", "TOP_LEFT", ACC_UI_PAD, ACC_UI_PAD );
    p.acc_card_title.color = ( 0.55, 0.85, 1.0 );
    p.acc_card_title.alpha = 0;
    p.acc_card_title.sort = 3;
    p.acc_card_title.foreground = true;
    p.acc_card_title.hidewheninmenu = true;

    p.acc_card_price = p hud::createFontString( "default", 1.2 );
    p.acc_card_price hud::setParent( p.acc_card_bg );
    p.acc_card_price.alignX = "left";
    p.acc_card_price.alignY = "top";
    p.acc_card_price hud::setPoint( "TOP_LEFT", "TOP_LEFT", ACC_UI_PAD, ACC_UI_PAD + ACC_UI_TITLE_H );
    p.acc_card_price.color = ( 1.0, 0.85, 0.2 );
    p.acc_card_price.alpha = 0;
    p.acc_card_price.sort = 3;
    p.acc_card_price.foreground = true;
    p.acc_card_price.hidewheninmenu = true;

    p.acc_card_lines = [];
}

function card_lines( p, count )
{
    while ( p.acc_card_lines.size < count )
    {
        idx = p.acc_card_lines.size;
        ln = p hud::createFontString( "default", 1.15 );
        ln hud::setParent( p.acc_card_bg );
        ln hud::setPoint( "TOP_LEFT", "TOP_LEFT", ACC_UI_PAD, 0 ); // y assigned in card_show
        ln.alpha = 0;
        ln.sort = 3;
        ln.foreground = true;
        ln.hidewheninmenu = true;
        p.acc_card_lines[ idx ] = ln;
    }
}
