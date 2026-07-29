// ============================================================================
// [acc] CYBER SLOTS - a working slot machine (2026-07-24).
// Base: Coolyer's zm_slots v1.2 (github.com/coolyer/zm_slots, MIT-less "credit if
// used" - CREDITS.md row; icon PNGs = Flaticon, per-author credits in the pack
// README). Heavily ADAPTED for ACC - the shipped script was WaW-style:
//   1. ALL player.score writes -> zm_score:: API (never write .score - docs/14).
//   2. Machine is SCRIPT-SPAWNED like the Jukebox/Glitch Altar (script_model +
//      trigger_radius_use + TriggerIgnoreTeam) - NO Radiant trigger, NO .map edit
//      except the collision clip (add_prop_clips pattern). Model = the already-
//      zone-listed p8_zm_off_cigarette_vending cabinet (zero new assets).
//   3. Rewards remapped to ACC economy (shards jackpot, paradise-picker free gun
//      that respects wonder claim caps + skips heroes/tacticals/_acc_ twins, perk
//      loss via stock lose_random_perk; NO perk_purchase_limit games - we run
//      uncapped perks).
//   4. Sounds: stock/loaded aliases only ("zmb_cha_ching" etc.) - a missing alias
//      is a silent no-op, never a bank risk.
// Odds (unchanged from the pack): 5% triple, 20% pair, 75% nothing.
// ============================================================================
#using scripts\codescripts\struct;
#using scripts\shared\array_shared;
#using scripts\shared\util_shared;
#using scripts\zm\_zm_perks;
#using scripts\zm\_zm_powerups;
#using scripts\zm\_zm_score;
#using scripts\zm\_zm_utility;
#using scripts\zm\_zm_weapons;

#using scripts\zm\zm_abandoned_cyber_city\_acc_utility;
#using scripts\zm\zm_abandoned_cyber_city\_acc_interact_glow;
#using scripts\zm\zm_abandoned_cyber_city\_acc_data_shards;
#using scripts\zm\zm_abandoned_cyber_city\_acc_glitch_altar;
#using scripts\zm\zm_abandoned_cyber_city\_acc_map_randomizer;

#insert scripts\shared\shared.gsh;

#namespace acc_slots;

#precache( "material", "cherry" );
#precache( "material", "lemon" );
#precache( "material", "bar" );
#precache( "material", "seven" );
#precache( "material", "bell" );
#precache( "material", "diamond" );
#precache( "material", "clover" );
#precache( "material", "coin" );
#precache( "material", "banana" );
#precache( "material", "skull" );
#precache( "material", "death" );

// Price & rewards
#define ACC_SLOTS_PRICE        500     // points per spin
#define ACC_SLOTS_PAIR_REWARD  250     // pair payout

// Placement (FIXED 2026-07-25, user: "needs to be INSIDE the room with the jukebox and
// mystery box in trench... and on the ground" - the first spot y=2100 was OUTSIDE the
// room's south slab edge y~2173, and the wall-hung z=-130 mount floated with no wall):
// FREE-STANDING ON THE FLOOR inside the NORTH under-room, on the open floor between the
// Jukebox (-150,2240) and the trench mystery-box struct (-360,2231,-202). Front faces
// SOUTH toward the door approach (vending model fronts face -Y natively -> yaw 0).
// p8_zm_off_cigarette_vending is TOP-ORIGIN (hangs 52.8 below the origin -
// _acc_surface_deco precedent): floor -240 + 52.8 -> origin z=-187.2 puts the body
// EXACTLY floor-to-top z[-240,-187.2]. Collision clip = 'slots_vending' entry in
// tools/add_prop_clips.js (brushmodel, jukebox pattern).
#define ACC_SLOTS_ORIGIN       ( -250, 2260, -187.2 )
#define ACC_SLOTS_YAW          0     // vending front faces -Y natively = south, toward the room's door approach
#define ACC_SLOTS_TRIG_ORIGIN  ( -250, 2244, -208 )   // front-of-machine, floor+32 (the jukebox trigger band)

// HUD layout (center-screen reels)
#define ACC_SLOTS_HUD_X        0
#define ACC_SLOTS_HUD_Y        0

// Odds
#define ACC_SLOTS_CHANCE_TRIPLE 0.05
#define ACC_SLOTS_CHANCE_PAIR   0.20

// Sounds - loaded aliases only (missing alias = silent no-op)
#define ACC_SLOTS_SND_SPIN     "zmb_box_open"
#define ACC_SLOTS_SND_STOP     "zmb_box_move"
#define ACC_SLOTS_SND_WIN      "zmb_cha_ching"
#define ACC_SLOTS_SND_LOSE     "zmb_no_cha_ching"

function init()
{
    level thread spawn_slot_machine();
}

// Jukebox/Glitch-Altar pattern: script_model + trigger_radius_use (TriggerIgnoreTeam
// REQUIRED for script-spawned use-triggers - stock _zm_perks.gsc:1523).
function spawn_slot_machine()
{
    level endon( "end_game" );

    m = spawn( "script_model", ACC_SLOTS_ORIGIN );
    m setmodel( "p8_zm_off_cigarette_vending" );
    m.angles = ( 0, ACC_SLOTS_YAW, 0 );
    acc_interact_glow::glow_on( m );

    // Trigger fronts the machine at the jukebox trigger band (floor+32, r64 h72).
    t = spawn( "trigger_radius_use", ACC_SLOTS_TRIG_ORIGIN, 0, 64, 72 );
    t TriggerIgnoreTeam();
    t SetCursorHint( "HINT_NOICON" );
    t SetHintString( "Hold ^3[{+activate}]^7  ^5CYBER SLOTS^7 - spin for ^3" + ACC_SLOTS_PRICE + "^7 points" );

    acc_utility::log( "slots: machine placed in the NORTH under-room (arcade corner)" );

    for ( ;; )
    {
        t waittill( "trigger", player );

        if ( !isdefined( player ) || !zm_utility::is_player_valid( player ) )
            continue;
        if ( IS_TRUE( t.acc_spinning ) )
            continue;
        if ( player.score < ACC_SLOTS_PRICE )
        {
            player IPrintLnBold( "Need ^3" + ACC_SLOTS_PRICE + "^7 points to spin" );
            player PlaySound( ACC_SLOTS_SND_LOSE );
            wait 0.5;
            continue;
        }

        t.acc_spinning = true;
        player zm_score::minus_to_player_score( ACC_SLOTS_PRICE );
        player thread run_spin( t );
    }
}

function icon_list()
{
    return array( "cherry", "lemon", "bar", "seven", "bell", "clover", "diamond", "coin", "banana", "skull", "death" );
}

// 5% forced triple / 20% forced pair / else all-different (pack odds, unchanged).
function get_slot_spin_result( icons )
{
    rand = RandomFloat( 1.0 );
    spin_result = [];

    if ( rand < ACC_SLOTS_CHANCE_TRIPLE )
    {
        icon = icons[ RandomInt( icons.size ) ];
        spin_result[ 0 ] = icon;
        spin_result[ 1 ] = icon;
        spin_result[ 2 ] = icon;
    }
    else if ( rand < ACC_SLOTS_CHANCE_TRIPLE + ACC_SLOTS_CHANCE_PAIR )
    {
        icon_pair = icons[ RandomInt( icons.size ) ];
        icon_other = icon_pair;
        while ( icon_other == icon_pair )
            icon_other = icons[ RandomInt( icons.size ) ];
        odd = RandomInt( 3 );
        for ( i = 0; i < 3; i++ )
        {
            if ( i == odd ) spin_result[ i ] = icon_other;
            else            spin_result[ i ] = icon_pair;
        }
    }
    else
    {
        pool = [];
        while ( pool.size < 3 )
        {
            icon = icons[ RandomInt( icons.size ) ];
            is_duplicate = false;
            for ( k = 0; k < pool.size; k++ )
            {
                if ( pool[ k ] == icon ) { is_duplicate = true; break; }
            }
            if ( !is_duplicate )
                pool[ pool.size ] = icon;
        }
        spin_result = pool;
    }
    return spin_result;
}

// self = player. Renders the 3x3 reel HUD, animates the spin, pays out.
function run_spin( trig )
{
    self endon( "disconnect" );

    icons = icon_list();
    spin_result = get_slot_spin_result( icons );

    // --- 3x3 reel HUD (+ the two separator lines per column) ---
    reel = [];
    lines = [];
    for ( i = 0; i < 3; i++ )
    {
        reel[ i ] = [];
        for ( j = 0; j < 3; j++ )
        {
            e = NewClientHudElem( self );
            e.alignX = "center";
            e.alignY = "middle";
            e.horzAlign = "center";
            e.vertAlign = "middle";
            e.x = ( i - 1 ) * 70 + ACC_SLOTS_HUD_X;
            e.y = ( ( j - 1 ) * 70 ) + ACC_SLOTS_HUD_Y;
            e.fontScale = 2.0;
            e.alpha = 1.0;
            e.archived = false;
            reel[ i ][ j ] = e;
        }
        line_top = NewClientHudElem( self );
        line_top.alignX = "center";
        line_top.alignY = "middle";
        line_top.horzAlign = "center";
        line_top.vertAlign = "middle";
        line_top.x = ( i - 1 ) * 70 + ACC_SLOTS_HUD_X;
        line_top.y = ACC_SLOTS_HUD_Y - 35;
        line_top SetShader( "black", 64, 2 );
        line_top.alpha = 0.5;
        lines[ lines.size ] = line_top;

        line_bot = NewClientHudElem( self );
        line_bot.alignX = "center";
        line_bot.alignY = "middle";
        line_bot.horzAlign = "center";
        line_bot.vertAlign = "middle";
        line_bot.x = ( i - 1 ) * 70 + ACC_SLOTS_HUD_X;
        line_bot.y = ACC_SLOTS_HUD_Y + 35;
        line_bot SetShader( "black", 64, 2 );
        line_bot.alpha = 0.5;
        lines[ lines.size ] = line_bot;
    }

    self PlayLocalSound( ACC_SLOTS_SND_SPIN );

    // Reel 0 spins longest; each lands so its final CENTER cell = the result icon.
    spins = array( 14, 10, 7 );
    reel_indices = [];
    for ( i = 0; i < 3; i++ )
    {
        result_index = 0;
        for ( k = 0; k < icons.size; k++ )
        {
            if ( icons[ k ] == spin_result[ i ] ) { result_index = k; break; }
        }
        reel_indices[ i ] = ( result_index - ( spins[ i ] - 1 ) + icons.size ) % icons.size;
    }

    for ( spin = 0; spin < spins[ 0 ]; spin++ )
    {
        for ( i = 0; i < 3; i++ )
        {
            if ( spin >= spins[ i ] )
                continue;
            current_index = ( reel_indices[ i ] + spin ) % icons.size;
            if ( spin == spins[ i ] - 1 )
            {
                // last tick: center = result, top/bottom = random non-result
                for ( j = -1; j <= 1; j++ )
                {
                    if ( j == 0 )
                        icon = spin_result[ i ];
                    else
                    {
                        icon = spin_result[ i ];
                        while ( icon == spin_result[ i ] )
                            icon = icons[ RandomInt( icons.size ) ];
                    }
                    reel[ i ][ j + 1 ] SetShader( icon, 64, 64 );
                }
                self PlayLocalSound( ACC_SLOTS_SND_STOP );
            }
            else
            {
                for ( j = -1; j <= 1; j++ )
                {
                    icon_index = ( current_index + j + icons.size ) % icons.size;
                    reel[ i ][ j + 1 ] SetShader( icons[ icon_index ], 64, 64 );
                }
            }
        }
        wait( 0.12 + ( spin * 0.01 ) );
    }

    wait 0.6;   // let the final row read before it clears
    destroy_reel_hud( reel, lines );

    self pay_out( spin_result );

    trig.acc_spinning = false;
}

// self = player. ACC reward table (adapted - header note 3).
function pay_out( spin_result )
{
    sound_to_play = ACC_SLOTS_SND_WIN;

    if ( is_triple( spin_result, "seven" ) )
    {
        // JACKPOT: points + a Data Shards payout (the cyber casino pays in shards).
        self zm_score::add_to_player_score( 2000 );
        acc_data_shards::grant_player( self, 150, "slots_jackpot" );
        self IPrintLnBold( "^3JACKPOT!^7 3 Sevens - ^32000^7 points + ^5150 Data Shards" );
    }
    else if ( is_triple( spin_result, "cherry" ) )
    {
        self zm_score::add_to_player_score( 2500 );
        self IPrintLnBold( "3 Cherries! ^3+2500^7 points" );
    }
    else if ( is_triple( spin_result, "lemon" ) )
    {
        self zm_score::add_to_player_score( 750 );
        self IPrintLnBold( "3 Lemons! ^3+750^7 points" );
    }
    else if ( is_triple( spin_result, "bar" ) )
    {
        self zm_score::add_to_player_score( 500 );
        self IPrintLnBold( "3 Bars! ^3+500^7 points" );
    }
    else if ( is_triple( spin_result, "bell" ) )
    {
        // FREE GUN via the Paradise picker (respects wonder claim caps, skips
        // tacticals/owned guns). Heroes re-roll once; still hero/undefined -> points.
        w = acc_glitch_altar::paradise_box_pick_weapon( self );
        if ( isdefined( w ) && zm_utility::is_hero_weapon( w ) )
            w = acc_glitch_altar::paradise_box_pick_weapon( self );
        if ( isdefined( w ) && !zm_utility::is_hero_weapon( w ) )
        {
            self IPrintLnBold( "3 Bells! ^2Free gun" );
            self zm_weapons::weapon_give( w );
            self SwitchToWeapon( w );
        }
        else
        {
            self zm_score::add_to_player_score( 1000 );
            self IPrintLnBold( "3 Bells! ^3+1000^7 points" );
        }
    }
    else if ( is_triple( spin_result, "clover" ) )
    {
        self zm_score::add_to_player_score( 1000 );
        acc_data_shards::grant_player( self, 50, "slots_clover" );
        self IPrintLnBold( "3 Clovers! ^3+1000^7 points + ^550 Data Shards" );
    }
    else if ( is_triple( spin_result, "skull" ) )
    {
        perks = self zm_perks::get_perk_array();
        if ( isdefined( perks ) && perks.size > 0 )
        {
            self IPrintLnBold( "3 Skulls! ^1Lost a random perk" );
            self zm_perks::lose_random_perk();
        }
        else
        {
            half = int( self.score / 2 );
            if ( half > 0 )
                self zm_score::minus_to_player_score( half );
            self IPrintLnBold( "3 Skulls! ^1Half your points - gone" );
        }
        sound_to_play = ACC_SLOTS_SND_LOSE;
    }
    else if ( is_triple( spin_result, "death" ) )
    {
        // House always wins. World-sourced damage (undefined attacker - a SELF
        // attacker would be zeroed by the stock self-damage MOD whitelist).
        self IPrintLnBold( "3 Deaths! ^1The house collects..." );
        self DoDamage( self.health + 666, self.origin, undefined );
        sound_to_play = ACC_SLOTS_SND_LOSE;
    }
    else if ( is_triple( spin_result, "diamond" ) )
    {
        self IPrintLnBold( "3 Diamonds! ^2Insta-Kill" );
        level thread zm_powerups::specific_powerup_drop( "insta_kill", self.origin );
    }
    else if ( is_triple( spin_result, "coin" ) )
    {
        self zm_score::add_to_player_score( 1000 );
        self IPrintLnBold( "3 Coins! ^3+1000^7 points + ^2Double Points" );
        level thread zm_powerups::specific_powerup_drop( "double_points", self.origin );
    }
    else if ( is_triple( spin_result, "banana" ) )
    {
        self IPrintLnBold( "3 Bananas! ^2Max Ammo" );
        level thread zm_powerups::specific_powerup_drop( "full_ammo", self.origin );
    }
    else if ( is_pair( spin_result ) )
    {
        self zm_score::add_to_player_score( ACC_SLOTS_PAIR_REWARD );
        self IPrintLnBold( "Two of a kind! ^3+" + ACC_SLOTS_PAIR_REWARD + "^7 points" );
    }
    else
    {
        self IPrintLnBold( "No match - the machine hums smugly." );
        sound_to_play = ACC_SLOTS_SND_LOSE;
    }

    self PlayLocalSound( sound_to_play );
}

function destroy_reel_hud( reel, lines )
{
    for ( i = 0; i < 3; i++ )
    {
        for ( j = 0; j < 3; j++ )
        {
            if ( isdefined( reel[ i ][ j ] ) )
                reel[ i ][ j ] Destroy();
        }
    }
    for ( i = 0; i < lines.size; i++ )
    {
        if ( isdefined( lines[ i ] ) )
            lines[ i ] Destroy();
    }
}

function is_triple( spin_result, icon )
{
    return spin_result[ 0 ] == icon && spin_result[ 1 ] == icon && spin_result[ 2 ] == icon;
}

function is_pair( spin_result )
{
    return (
        ( spin_result[ 0 ] == spin_result[ 1 ] && spin_result[ 0 ] != spin_result[ 2 ] ) ||
        ( spin_result[ 0 ] == spin_result[ 2 ] && spin_result[ 0 ] != spin_result[ 1 ] ) ||
        ( spin_result[ 1 ] == spin_result[ 2 ] && spin_result[ 1 ] != spin_result[ 0 ] )
    );
}
