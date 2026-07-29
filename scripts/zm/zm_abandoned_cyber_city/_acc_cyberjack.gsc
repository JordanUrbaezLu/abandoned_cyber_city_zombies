// =============================================================================
// _acc_cyberjack.gsc - THE CYBERJACK (docs/43) - M1 combat identity.
//
// CHASSIS = apex_lstar (Apex L-STAR plasma LMG, zeroy pack - unused by the box,
// full 1P viewmodel/anims/sounds verified installed; user picked it 2026-07-17
// over the storm bow: "the part I don't really like is that it's a bow").
// QUEST-ONLY (docs/43 decision 2): never in the mystery box, never in Paradise
// loot - _acc_dev grants it in dev; the M4 ICEBREAKER COMPILE is the public path.
//
// THE IDENTITY (all server-side; ZERO new clientfields - see FX note):
//   - JACK-IN CHAIN: every direct hit on an uncorrupted normal zombie "roots"
//     it and chain-hops to nearby zombies (2 + PaP tier hops): a plasma bolt
//     visibly arcs zombie->zombie, each hop lands a MagicBullet of the HELD
//     weapon (full damage pipeline: bal mult, ENERGY class, PaP, crit charges -
//     the Triple Take precedent) and roots the new victim.
//   - CORRUPTION: rooted zombies flicker-slow (ASMSetAnimationRate + the
//     under_anim_slow hook in _acc_zombie_speed) and tick a DECOMPILE DoT -
//     fraction-of-current-health per 1s tick (round-proof forever, the Fire Bow
//     portal-DoT recipe), player-attacker DoDamage so kills credit + drop.
//   - DECOMPILE HARVEST: a zombie that DIES corrupted has a chance to burst a
//     physical Data Shard pickup (the map's shipped drop spawner) - the ONLY
//     surface-world shard faucet (user-approved economy exception, docs/43
//     decision 1) - hard-capped per round so it augments, never replaces, the
//     trench economy.
//
// FX HACK v3 (encouraged, documented): ALL lightning rides the DE STORM BOW's
// already-registered SCRIPTMOVER clientfields + its loaded .csc handlers -
// "elem_storm_bolt_fx" (the zap-bolt, plays ALONG the mover's angles) and
// "elem_storm_zap_ambient" (the crackling orb) - plus the "elem_storm_whirlwind_rumble"
// toplayer CF, plus server-side one-shot PlayFxOnTag tesla bursts (registered below).
// Zero NEW CF bits (both pools are FULL), zero new client code, zero new FX/zone assets.
// The storm bow's OWN kill/stun functions are OFF-LIMITS (they set the DISABLED
// elem_storm_shock_fx ACTOR CF = runtime error); our micro_storm rebuilds the storm
// from the safe pieces. If the hb21 pack is ever removed, this module's FX die with it.
//
// TRAPS HONORED (docs/43 trap register):
//   - callback::on_ai_damage is NEVER dispatched; we also avoid a second
//     zm::register_actor_damage_callback (first-callback-wins risk) - the chain
//     trigger is our OWN BulletTrace on "weapon_fired" instead.
//   - Corruption filter excludes ALL boss markers (octobomb-crash memory).
//   - DoT ticks run in per-zombie ISOLATED threads (pack AI damage handlers can
//     throw mid-chain - the Fire Bow DoT hardening).
//   - Slow rides a per-zombie flag _acc_zombie_speed::under_anim_slow honors,
//     with a timed force-restore watchdog (notetrack-ghost memory pattern).
//   - Harvest death hook = zm_spawner::register_zombie_death_event_callback.
//   - Bolt movers: >=0.25s flight, CF set-then-clear, delete after the 0-snap.
// =============================================================================

#using scripts\shared\callbacks_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\flag_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#using scripts\zm\_zm_spawner;
#using scripts\zm\_zm_utility;
#using scripts\zm\_zm_weapons;

#using scripts\zm\zm_abandoned_cyber_city\_acc_utility;
#using scripts\zm\zm_abandoned_cyber_city\_acc_data_shards;
#using scripts\zm\zm_abandoned_cyber_city\_acc_pap_levels;

#namespace acc_cyberjack;

function init()
{
    level.acc_cj_harvest_round_n = 0;
    level.acc_cj_live_storms    = 0;
    level.acc_cj_pickup_live    = false;   // Brutus gun-drop: is a ground pickup currently live?
    level thread harvest_round_reset();

    // LIGHTNING FX, server-side (v3 fusion, user 2026-07-17 "combo of lstar model, lightning
    // fx and mechanics"): the DE storm bow's fx ASSETS are packed via the hb21 zpkg and its
    // zap-bolt/orb SCRIPTMOVER clientfields are registered (lockstep .csc loads) - but its
    // kill/stun FUNCTIONS set the DISABLED elem_storm_shock_fx ACTOR clientfield (budget-cut
    // 2026-07-11) and would runtime-error, so we rebuild the storm from the SAFE pieces below
    // and register the tesla shock fx for our own server PlayFxOnTag bursts.
    level._effect[ "acc_cj_shock" ]      = "zombie/fx_tesla_shock_zmb";
    level._effect[ "acc_cj_shock_eyes" ] = "zombie/fx_tesla_shock_eyes_zmb";

    zm_spawner::register_zombie_death_event_callback( &on_zombie_death_harvest );
    callback::on_connect( &on_player_connect );

    acc_utility::log( "cyberjack: v3 lightning identity live (L-STAR chassis; jack-in chain + micro-storms + TEMPEST charge + corruption/harvest)" );
}

function on_player_connect()
{
    self.acc_cj_live_chains = 0;
    self.acc_cj_charge_lvl  = 0;
    self thread fired_watcher();
    self thread tempest_arm_watcher();
}

function is_cyberjack( w )
{
    return ( isdefined( w ) && w != level.weaponNone && isdefined( w.name ) && IsSubStr( w.name, "apex_lstar" ) );
}

// A zombie the corruption may take: a live, normal horde zombie - NEVER a boss/
// mini-boss/Glitch/Fury/friendly. VERIFY-PASS FIX (M1 review): the filter now also
// checks stock IS_TRUE(z.is_boss) + acc_boss_custom_speed - Brutus is factory-spawned
// (archetype "zombie", team axis) and carries ONLY is_boss in the window before his
// acc_is_mini_boss promotion lands; an ASMSetAnimationRate on his custom locomotion
// ASM is the documented freeze-bug class (the _acc_zombie_speed:194 guard, mirrored).
function is_corruptible( z )
{
    if ( !isdefined( z ) || !isalive( z ) )            return false;
    if ( !isdefined( z.archetype ) || z.archetype != "zombie" ) return false;
    if ( IS_TRUE( z.is_boss ) )                        return false;
    if ( IS_TRUE( z.acc_is_boss ) )                    return false;
    if ( IS_TRUE( z.acc_is_mini_boss ) )               return false;
    if ( IS_TRUE( z.acc_boss_custom_speed ) )          return false;
    if ( IS_TRUE( z.acc_is_glitch_zombie ) )           return false;
    if ( IS_TRUE( z.b_is_apothicon_fury ) )            return false;
    team = ( isdefined( level.zombie_team ) ? level.zombie_team : "axis" );
    if ( isdefined( z.team ) && z.team != team )       return false;
    return true;
}

// ---- the jack-in trigger: our OWN trace on every shot (no damage-callback risk) ----
function fired_watcher()   // self = player
{
    self endon( "disconnect" );
    level flag::wait_till( "initial_blackscreen_passed" );

    for ( ;; )
    {
        self waittill( "weapon_fired", w_fired );
        if ( !is_cyberjack( w_fired ) ) continue;

        tier = acc_pap_levels::cyberjack_tier( self );

        // Who did the engine's own hitscan bullet (already resolved) most likely hit?
        // Re-derive with a character-aware trace down the aim line. COSMETIC-adjacent:
        // a recoil-spread miss of the true victim just means no chain on that shot.
        v_muzzle = self GetWeaponMuzzlePoint();
        v_fwd    = self GetWeaponForwardDir();
        trace    = BulletTrace( v_muzzle, v_muzzle + v_fwd * 4000, true, self );
        victim   = trace[ "entity" ];

        // EVERY SHOT IS AN ELECTRIC BALL (v4, user: "everyshot should be the electric
        // ball... like 4th of the size"): a small blue electric orb flies the shot line -
        // our own acc_ttk_geotrail_blue fx (already quarter-scale) on the ttk scriptmover
        // CF. Cosmetic only (damage is the hitscan bullet); concurrency-capped.
        level thread shot_orb( v_muzzle, trace[ "position" ], self GetWeaponForwardDir(), tier );

        // TEMPEST release (v5.2, user "15,30,45,60 - the longer you hold the stronger the
        // storm and it takes more ammo"): a CHARGED shot summons the storm at the impact,
        // scaled to the charge LEVEL reached (1..4). Reset on fire.
        lvl = ( isdefined( self.acc_cj_charge_lvl ) ? self.acc_cj_charge_lvl : 0 );
        if ( lvl >= 1 )
        {
            self.acc_cj_charge_lvl = 0;
            self thread tempest_release( trace[ "position" ], w_fired, tier, lvl );
        }

        if ( !is_corruptible( victim ) )         continue;
        if ( IS_TRUE( victim.acc_cj_corrupted ) ) continue;

        // Live-chain budget: a full-auto stream must not stack unbounded chain threads.
        if ( self.acc_cj_live_chains >= getdvarint( "acc_cj_max_chains", 2 ) ) continue;

        self thread run_chain( victim, w_fired, tier );
    }
}

// ---- TEMPEST: the charge (v4: "an automatic plasma shooter but can also be charged
// via aiming in and shoot a tornado") ----
// ADS-hold >=1.2s WITHOUT firing arms it, with a STAGED AUDIO RAMP (user: "I need a
// sound q for charge"): the Havoc's proven charge blips at 1/3 and 2/3 hold, then the
// L-STAR barrel spin-up at ARMED - three rising cues, all packed + non-looping.
// The hold is OUR timer (script-owned charge, the map's proven recipe) - no def swap,
// no fire-block needed: the release shot's bullet still fires (the payload rides it).
function tempest_arm_watcher()   // self = player
{
    self endon( "disconnect" );
    level flag::wait_till( "initial_blackscreen_passed" );

    // 4-LEVEL CHARGE (user 2026-07-17 "15,30,45,60 - the longer you hold the stronger the
    // storm... takes more ammo"): ADS-hold WITHOUT firing charges through 4 levels, one per
    // acc_cj_charge_step_ms. Each new level plays a rising audio cue + a rumble pulse (no
    // charge ANIM exists on this chassis). The level reached is fired by the release shot.
    held_ms = 0;
    for ( ;; )
    {
        wait 0.1;
        w = self GetCurrentWeapon();
        if ( !is_cyberjack( w ) || !( self AdsButtonPressed() ) || self IsFiring() )
        {
            held_ms = 0;
            self.acc_cj_charge_lvl = 0;
            continue;
        }
        held_ms += 100;
        step = getdvarint( "acc_cj_charge_step_ms", 550 );   // ms per charge level
        lvl  = int( held_ms / step );
        if ( lvl > 4 ) lvl = 4;

        if ( lvl > self.acc_cj_charge_lvl )
        {
            self.acc_cj_charge_lvl = lvl;
            snd = "acc_cj_charge_25";
            if ( lvl == 2 ) snd = "acc_cj_charge_50";
            if ( lvl == 3 ) snd = "acc_cj_charge_75";
            if ( lvl >= 4 ) snd = "wpn_apex_lstar_spin_start";   // MAX charge cue
            self PlaySound( snd );
            self clientfield::set_to_player( "elem_storm_whirlwind_rumble", 1 );
            self thread armed_rumble_off();
        }
    }
}

// self = player. Fire a storm scaled to the charge LEVEL (1..4): ammo cost 15/30/45/60,
// and the storm gets stronger (longer life + MORE funnels ringed at the higher levels).
function tempest_release( v_impact, w, tier, lvl )
{
    if ( !isdefined( lvl ) || lvl < 1 ) lvl = 1;
    if ( lvl > 4 ) lvl = 4;

    // Ammo cost = lvl x 15 (15/30/45/60). Deferred a frame off the trigger (mid-draw
    // ammo writes are the known trap).
    util::wait_network_frame();
    cost = lvl * getdvarint( "acc_cj_tempest_cost_per", 15 );
    if ( isdefined( self ) && isplayer( self ) && self HasWeapon( w ) )
    {
        clip  = self GetWeaponAmmoClip( w );
        stock = self GetWeaponAmmoStock( w );
        from_clip = ( ( clip < cost ) ? clip : cost );
        self SetWeaponAmmoClip( w, clip - from_clip );
        rem = cost - from_clip;
        if ( rem > 0 )
        {
            s = stock - rem;
            if ( s < 0 ) s = 0;
            self SetWeaponAmmoStock( w, s );
        }
    }

    // Guard self (verify-pass nit): a disconnect during the wait_network_frame above would
    // make these self-calls throw; the tornado itself rides `level` and is fine.
    if ( isdefined( self ) && isplayer( self ) )
    {
        self clientfield::set_to_player( "elem_storm_whirlwind_rumble", 1 );
        self thread tempest_rumble_off();
    }

    // ONE tornado (user 2026-07-17 "where is the tornado... each tier hold is an extra
    // electric storm ball" - they want THE tornado, NOT extra balls). It gets STRONGER
    // with the charge level: longer life + wider strike range (scaled inside micro_storm).
    life = getdvarfloat( "acc_cj_tempest_life", 3.0 ) + lvl * 1.2 + tier * 0.5;
    level thread micro_storm( v_impact + ( 0, 0, 24 ), self, w, tier, life, true, lvl );
    PlaySoundAtPosition( "acc_cj_thunder", v_impact );   // [acc] tempest thunderclap (sfx sweep 2026-07-21)
}

function tempest_rumble_off()   // self = player
{
    self endon( "disconnect" );
    wait 1.2;
    self clientfield::set_to_player( "elem_storm_whirlwind_rumble", 0 );
}

function armed_rumble_off()   // self = player; the short ARMED pulse
{
    self endon( "disconnect" );
    wait 0.4;
    self clientfield::set_to_player( "elem_storm_whirlwind_rumble", 0 );
}

// ---- OUR storm: the DE storm rebuilt from the SAFE registered pieces ----
// A crackling orb (elem_storm_zap_ambient CF) hangs at the point; it spikes REAL
// lightning bolts (elem_storm_bolt_fx CF, aimed via mover angles - the .csc plays
// fx_bow_storm_bolt_zap along them) into corruptible zombies in range: tesla shock
// burst, the stock zombie_tesla_hit stagger, SET tick damage (exact-marked; was a
// guaranteed one-shot until 2026-07-26), and CORRUPTION - storm kills feed the harvest.
// b_big (v4 TORNADO): + the DE whirlwind FUNNEL (elem_storm_fx CF), b_multi range
// (320), a faster strike cadence - the charged shot IS the storm.
function micro_storm( v_org, player, w, tier, life, b_big, lvl )
{
    level endon( "end_game" );

    if ( level.acc_cj_live_storms >= getdvarint( "acc_cj_max_storms", 4 ) ) return;
    level.acc_cj_live_storms++;

    if ( !isdefined( lvl ) || lvl < 1 ) lvl = 1;

    // The crackling electric CORE at the base.
    e_orb = Spawn( "script_model", v_org );
    if ( !isdefined( e_orb ) ) { level.acc_cj_live_storms--; return; }
    e_orb SetModel( "tag_origin" );
    e_orb clientfield::set( "elem_storm_zap_ambient", 1 );

    // THE TORNADO FUNNELS (b_big) - MORE per charge level, spread across the SAME GROUND
    // PLANE next to each other (user 2026-07-17: "not stacked on each other... on the same
    // plane but next to each other"): `lvl` funnel movers in a horizontal ring around the
    // impact (L1 = 1, L4 = 4 tornadoes fanned out), each on its own dedicated mover so the
    // DE whirlwind loop (elem_storm_fx) renders clean.
    a_funnels = [];
    a_forg    = [];
    if ( IS_TRUE( b_big ) )
    {
        spread = getdvarfloat( "acc_cj_tornado_spread", 130 );
        for ( i = 0; i < lvl; i++ )
        {
            if ( i == 0 )
                forg = v_org;   // one tornado at the impact point you shot
            else
            {
                // the rest scatter to RANDOM spots across the circle (user 2026-07-17: not the
                // same fixed left/right pattern every shot) - random angle + random radius.
                ang  = RandomFloat( 360 );
                r    = getdvarfloat( "acc_cj_tornado_spread_min", 45 ) + RandomFloat( spread );
                forg = v_org + ( cos( ang ) * r, sin( ang ) * r, 0 );   // SAME plane
            }
            f = Spawn( "script_model", forg );
            if ( isdefined( f ) )
            {
                f SetModel( "tag_origin" );
                f clientfield::set( "elem_storm_fx", 1 );
                a_funnels[ a_funnels.size ] = f;
                a_forg[ a_forg.size ]       = forg;
            }
        }
    }

    // Radius scales with charge level; a few bolt VISUALS per tick.
    range    = ( IS_TRUE( b_big ) ? getdvarfloat( "acc_cj_tornado_range", 280 ) + lvl * 90 : getdvarfloat( "acc_cj_storm_range", 160 ) );
    n_visual = ( IS_TRUE( b_big ) ? lvl + 1 : 1 );
    tick     = getdvarfloat( "acc_cj_storm_tick", 0.3 );
    t_end    = GetTime() + int( life * 1000 );

    // THE STORM FIELD (user 2026-07-17; damage rework 2026-07-26): every tick, EVERYTHING in
    // the radius is 50% SLOWED; normal zombies take SET flat tick damage x the charge mult
    // (one-hits early rounds, late rounds survive ticks - see storm_zombie_tick) + corruption
    // feeds the harvest; bosses/Shielded take round-scaled DAMAGE-OVER-TIME (x charge level,
    // x1.25 at L4). Lightning-bolt visuals arc out from the spread funnels each tick.
    while ( GetTime() < t_end )
    {
        enemies = enemies_in_radius( v_org, range );
        n_vis = 0;
        for ( i = 0; i < enemies.size; i++ )
        {
            e = enemies[ i ];
            if ( !isdefined( e ) || !isalive( e ) ) continue;

            e tornado_slow_refresh( lvl );   // CHARGE-SCALED slow while inside (L1 12.5% .. L4 50%)

            b_tough = ( IS_TRUE( e.acc_is_shielded ) || IS_TRUE( e.acc_is_boss ) || IS_TRUE( e.is_boss ) || IS_TRUE( e.acc_is_mini_boss ) || IS_TRUE( e.acc_boss_custom_speed ) );
            if ( b_tough )
                e thread storm_dot_tick( player, w, lvl );                     // scaling DoT vs tough
            else if ( is_corruptible( e ) )
            {
                if ( !IS_TRUE( e.acc_cj_corrupted ) )
                    mark_corrupted( e, player, tier );                        // harvest + its own slow (first contact)
                e thread storm_zombie_tick( player, w, lvl );                 // SET tick damage (2026-07-26; was a one-time one-shot)
            }

            if ( n_vis < n_visual )
            {
                v_src = ( a_forg.size > 0 ? a_forg[ RandomInt( a_forg.size ) ] : v_org );
                level thread storm_zap_visual( v_src, e );
                n_vis++;
            }
        }
        wait tick;
    }

    for ( i = 0; i < a_funnels.size; i++ )
        if ( isdefined( a_funnels[ i ] ) ) a_funnels[ i ] clientfield::set( "elem_storm_fx", 0 );
    wait 0.1;
    for ( i = 0; i < a_funnels.size; i++ )
        if ( isdefined( a_funnels[ i ] ) ) a_funnels[ i ] Delete();

    if ( isdefined( e_orb ) )
    {
        e_orb clientfield::set( "elem_storm_zap_ambient", 0 );
        wait 0.1;
        if ( isdefined( e_orb ) ) e_orb Delete();
    }
    level.acc_cj_live_storms--;
}

// ---- storm-field helpers ----

// All live axis AI within `range` of the storm center.
function enemies_in_radius( v_org, range )
{
    team = ( isdefined( level.zombie_team ) ? level.zombie_team : "axis" );
    zs = GetAITeamArray( team );
    out = [];
    r2 = range * range;
    for ( i = 0; i < zs.size; i++ )
    {
        z = zs[ i ];
        if ( !isdefined( z ) || !isalive( z ) ) continue;
        if ( DistanceSquared( v_org, z.origin + ( 0, 0, 32 ) ) <= r2 )
            out[ out.size ] = z;
    }
    return out;
}

// CHARGE-SCALED slow on every enemy in the tornado radius, refreshed while inside. Honored by
// _acc_zombie_speed::under_anim_slow (acc_cj_storm_slow_on); a single watchdog per enemy
// restores rate 1.0 when it leaves the radius / the storm ends (freezegun boss-slow precedent).
// SCALING (user 2026-07-27 "how much they slow currently should only be a max charge. I can do a
// 15 bullet charge and its super OP. Make sure all aspects of it scale up"): acc_cj_storm_slow_rate
// (0.5) is now the MAX-CHARGE rate only - the slow FRACTION interpolates linearly with the charge
// level: L1 12.5% / L2 25% / L3 37.5% / L4 50%. With this, EVERY strength axis of the storm scales
// with lvl (damage both lanes, life, range, funnels, bolts, slow); only cadence/caps stay flat.
// The jack-in finisher micro-storms run at lvl 1 = the light 12.5% slow.
function tornado_slow_refresh( lvl )   // self = enemy
{
    if ( !isdefined( lvl ) || lvl < 1 ) lvl = 1;
    if ( lvl > 4 ) lvl = 4;
    self.acc_cj_storm_slow_until = GetTime() + int( getdvarfloat( "acc_cj_storm_slow_hold", 0.45 ) * 1000 );
    // RE-APPLY the rate EVERY tick (user 2026-07-17 "make sure the slow applies to bosses too"):
    // a boss module (warden_speed_think / avo / panzer) sets its OWN anim rate, so setting ours
    // only once would get overwritten - re-asserting each tick keeps the slow winning while
    // the enemy is inside the radius. (Freezegun-safe mechanism; harmless re-set on normals.)
    rate = 1.0 - ( ( 1.0 - getdvarfloat( "acc_cj_storm_slow_rate", 0.5 ) ) * lvl / 4.0 );
    self ASMSetAnimationRate( rate );
    if ( !IS_TRUE( self.acc_cj_storm_slow_on ) )
    {
        self.acc_cj_storm_slow_on = true;
        self thread tornado_slow_watch();
    }
}

function tornado_slow_watch()   // self = enemy
{
    self endon( "death" );
    while ( isdefined( self.acc_cj_storm_slow_until ) && GetTime() < self.acc_cj_storm_slow_until )
        wait 0.2;
    if ( isdefined( self ) && isalive( self ) )
        self ASMSetAnimationRate( 1.0 );
    self.acc_cj_storm_slow_on    = undefined;
    self.acc_cj_storm_slow_until = undefined;
}

// Normal zombie inside the tornado = SET damage per tick (user 2026-07-26 "I dont want it to
// just one hit zombies. Same thing we do with bosses... it does a set damage. Maybe this is
// still a one hit for earlier round but not forever. You would need a full recharge on really
// late round"): FLAT base x the SAME charge multiplier as the boss lane (lvl, x1.25 at L4) -
// deliberately NOT round-scaled, so the zombie HP curve overtakes it: base 972 one-hits at
// L1 through ~r9, L2 (1944) ~r16, L3 (2916) ~r20, L4 (4860) ~r26; past that zombies inside
// need multiple 0.3s ticks even at max charge (plus the charge-scaled slow). Nerf history:
// 1500-class -> 1200 -> 1080 (2026-07-26 -20% then -10%) -> 972 (2026-07-27 all-lane -10%).
// Exact-marked so the damage pipeline lands it verbatim. Applies to the TEMPEST tornado AND
// the small jack-in finisher storms (same field loop, lvl 1). Corruption/harvest unchanged.
function storm_zombie_tick( player, w, lvl )   // self = normal zombie
{
    if ( !isdefined( self ) || !isalive( self ) ) return;
    if ( !isdefined( player ) || !isplayer( player ) ) return;
    if ( !isdefined( lvl ) || lvl < 1 ) lvl = 1;
    PlayFxOnTag( level._effect[ "acc_cj_shock" ], self, "j_spineupper" );
    mult = lvl;
    if ( lvl >= 4 ) mult = lvl * 1.25;   // the last blast: 125% (mirrors storm_dot_tick)
    n = int( getdvarint( "acc_cj_storm_zombie_dmg", 972 ) * mult );
    if ( n < 1 ) n = 1;
    self.acc_tg_exact_dmg = n;
    self DoDamage( n, self.origin, player, player, "none", "MOD_PROJECTILE_SPLASH", 0, w );
}

// Boss / Shielded inside the tornado = scaling DAMAGE-OVER-TIME per tick, a fraction of one
// normal zombie's round HP (round-proof) x charge level, x1.25 at L4 (user 2026-07-17
// "stack linearly except the last blast = 125%"). Exact-marked (bypasses the boss per-hit cap).
// TEMPEST NERFS (user 2026-07-26 "-20%" + "another -10%", then 2026-07-27 all-lane -10%
// "they are just too good"): dot_frac 0.5 -> 0.4 -> 0.36 -> 0.324, so per 0.3s tick vs
// tough = 0.324 x zombie-round-HP x lvl-mult (L4: x5 -> 1.62x zHP/tick, was 2.5x).
function storm_dot_tick( player, w, lvl )   // self = tough enemy
{
    if ( !isdefined( self ) || !isalive( self ) ) return;
    if ( !isdefined( player ) || !isplayer( player ) ) return;
    if ( !isdefined( lvl ) || lvl < 1 ) lvl = 1;
    PlayFxOnTag( level._effect[ "acc_cj_shock" ], self, "j_spineupper" );
    base = ( isdefined( level.zombie_health ) ? level.zombie_health : 1000 );
    mult = lvl;
    if ( lvl >= 4 ) mult = lvl * 1.25;   // the last blast: 125%
    n = int( base * getdvarfloat( "acc_cj_storm_dot_frac", 0.324 ) * mult );
    if ( n < 1 ) n = 1;
    self.acc_tg_exact_dmg = n;
    self DoDamage( n, self.origin, player, player, "none", "MOD_PROJECTILE_SPLASH", 0, w );
}

// One lightning-bolt VISUAL from a funnel to an enemy (damage is applied separately by the
// field loop). An aimed bolt mover - the DE zap fx plays along its angles.
function storm_zap_visual( v_src, z )
{
    level endon( "end_game" );
    if ( !isdefined( z ) || !isalive( z ) ) return;
    e_bolt = Spawn( "script_model", v_src );
    if ( !isdefined( e_bolt ) ) return;
    e_bolt SetModel( "tag_origin" );
    e_bolt.angles = VectorToAngles( ( z.origin + ( 0, 0, 44 ) ) - v_src );
    e_bolt clientfield::set( "elem_storm_bolt_fx", 1 );
    wait 0.25;
    if ( isdefined( e_bolt ) )
    {
        e_bolt clientfield::set( "elem_storm_bolt_fx", 0 );
        wait 0.1;
        if ( isdefined( e_bolt ) ) e_bolt Delete();
    }
}

// ---- the per-shot electric ball (v4.1) ----
// USER FIX 2026-07-17 ("I just see a blue trail... make it bright white/purple like the
// lightning effects from the bow assets"): the ttk GEOTRAIL fx smears into a streak in
// flight (it's a trail emitter - only reads as a ball when the mover stops). Swapped to
// the DE storm's CRACKLING ORB (fx_bow_storm_orb_zmb via the registered
// elem_storm_zap_ambient scriptmover CF - handle-managed looping, safe on movers): a
// bright white/purple electric ball in the SAME palette as the chain arcs + tornado.
// Cosmetic (damage = the engine's hitscan bullet); capped.
function shot_orb( v_muzzle, v_end, v_fwd, tier )
{
    level endon( "end_game" );

    if ( !isdefined( tier ) ) tier = 0;

    if ( !isdefined( level.acc_cj_live_orbs ) ) level.acc_cj_live_orbs = 0;
    if ( level.acc_cj_live_orbs >= getdvarint( "acc_cj_max_orbs", 12 ) ) return;
    level.acc_cj_live_orbs++;

    // Cosmetic birth offset (the muzzle IS ~the camera in 1P - the ttk lesson).
    v_right = AnglesToRight( VectorToAngles( v_fwd ) );
    v_up    = AnglesToUp( VectorToAngles( v_fwd ) );
    v_from  = v_muzzle + v_fwd * 34 + v_right * 8 - v_up * 7;

    // v5.8 (user "the trail is slower than the bullet... zombie dies instantly like hitscan
    // and the trail is behind it"): the gun's damage is HITSCAN (instant), so the visible
    // trail must ZIP to match. Cranked 1600 -> 10000 (was slow from the ball era) + a lower
    // min-flight floor so it lands ~when the kill does. (Floor can't go too low or the
    // scriptmover CF snapshot eats the trail on close shots - the tripletake lesson.)
    t_fly = Distance( v_from, v_end ) / getdvarfloat( "acc_cj_orb_speed", 3200 );   // user 2026-07-17 "double what it was" (1600 -> 3200)
    min_f = getdvarfloat( "acc_cj_orb_min_flight", 0.14 );
    if ( t_fly < min_f ) t_fly = min_f;
    if ( t_fly > 2.0 )   t_fly = 2.0;

    mover = Spawn( "script_model", v_from );
    if ( !isdefined( mover ) ) { level.acc_cj_live_orbs--; return; }
    // v5 (user "still no bolt, just the trail" x3): a geotrail is BY DEFINITION a streak -
    // it can never read as a discrete ball. The fix = a visible glowing ELECTRIC-SPHERE
    // MODEL on the mover (stock fxuse_sphere_elec), so an actual electric ball flies the
    // shot line. The violet geotrail rides it as a trailing wisp (CF value 3, follows tag).
    // v5.3 (user "remove the purple ball... I'm fine with only the trail"): NO model - the
    // mover is invisible and the light-purple electric TRAIL is the projectile.
    mover SetModel( "tag_origin" );
    // Violet electric trail (acc_cj_bolt_violet, CF value 3 on the shared ttk scriptmover field).
    // NOTE: the papped "richer-violet" variant (CF value 4) was REVERTED 2026-07-17 - it required
    // widening this field to 3 bits, which overflowed the scriptmover CF budget and crashed the map
    // on load. A PaP trail must be done bit-free (no new scriptmover bit). tier is currently unused.
    mover clientfield::set( "acc_ttk_bolt_fx", 3 );
    mover MoveTo( v_end, t_fly );
    wait t_fly;
    if ( isdefined( mover ) )
    {
        mover clientfield::set( "acc_ttk_bolt_fx", 0 );
        wait 0.1;
        if ( isdefined( mover ) ) mover Delete();
    }
    level.acc_cj_live_orbs--;
}

// One storm strike on one zombie: tesla shock FX + the stock tesla stagger flag +
// (storm_strike_zombie / storm_stagger_off removed 2026-07-17 - the storm-FIELD rework
//  splits their job into storm_zombie_tick [normals, set tick damage since 2026-07-26],
//  storm_dot_tick [tough enemies], and tornado_slow_refresh [the 50% radius slow].)

// ---- one chain: root the victim, then hop outward (2 + tier hops) ----
function run_chain( z_first, w, tier )   // self = player
{
    self endon( "disconnect" );
    self.acc_cj_live_chains++;

    mark_corrupted( z_first, self, tier );
    start_dot( z_first, self, w, tier );

    hops     = getdvarint( "acc_cj_hops_base", 2 ) + tier;
    range    = getdvarfloat( "acc_cj_hop_range", 220 );
    z_from   = z_first;
    n_landed = 0;
    v_last   = z_first.origin + ( 0, 0, 48 );

    for ( h = 0; h < hops; h++ )
    {
        if ( !isdefined( z_from ) ) break;
        v_from = z_from.origin + ( 0, 0, 48 );

        z_next = next_hop_target( v_from, range );
        if ( !isdefined( z_next ) ) break;

        // Mark + SLOW at pick time (VERIFY-PASS FIX: marking alone pre-flight leaked the
        // flag forever if the zombie died mid-flight or the shooter disconnected - the
        // slow thread lives on the ZOMBIE and its live-expiry is the guaranteed clear
        // path, so flag + slow always travel together).
        mark_corrupted( z_next, self, tier );

        // The visible arc: a plasma-orb mover chest->chest on the Triple Take's CF.
        v_to  = z_next.origin + ( 0, 0, 48 );
        t_fly = hop_bolt( v_from, v_to );
        wait t_fly;

        // The hop HIT: a MagicBullet of the held weapon fired along the ARC LINE (prev
        // chest -> target's CURRENT chest; start offset 40u toward the target so the
        // source body can't eat the bullet) - full pipeline damage (bal mult / ENERGY /
        // PaP / crits), kills credit the player. VERIFY-PASS FIX: was a vertical
        // drop-shot that lotteried head-hitloc multipliers.
        if ( isdefined( z_next ) && isalive( z_next ) )
        {
            v_now   = z_next.origin + ( 0, 0, 48 );
            v_start = v_from;
            if ( Distance( v_from, v_now ) > 48 )   // stacked-zombie degenerate: skip the offset
                v_start = v_from + VectorNormalize( v_now - v_from ) * 40;
            MagicBullet( w, v_start, v_now, self );
            start_dot( z_next, self, w, tier );
            n_landed++;
            v_last = v_now;
        }

        z_from = z_next;
    }

    // CHAIN FINISHER (v3): a chain that lands 2+ hops ends in a micro-storm at the last
    // victim - every good jack-in finishes as a visible lightning event.
    if ( n_landed >= getdvarint( "acc_cj_finisher_hops", 2 ) )
        level thread micro_storm( v_last, self, w, tier, getdvarfloat( "acc_cj_finisher_life", 1.2 ) + tier * 0.3 );

    self.acc_cj_live_chains--;
}

// Nearest corruptible, uncorrupted zombie within range of the hop origin.
function next_hop_target( v_from, range )
{
    zs = GetAITeamArray( "axis" );
    best = undefined;
    best_d = range * range;
    for ( i = 0; i < zs.size; i++ )
    {
        z = zs[ i ];
        if ( !is_corruptible( z ) )           continue;
        if ( IS_TRUE( z.acc_cj_corrupted ) )  continue;
        d = DistanceSquared( v_from, z.origin + ( 0, 0, 48 ) );
        if ( d < best_d ) { best_d = d; best = z; }
    }
    return best;
}

// One LIGHTNING arc mover between two chests (v3: was the ttk plasma orb - now the DE
// storm's own zap-bolt fx via the registered elem_storm_bolt_fx scriptmover CF; the .csc
// plays fx_bow_storm_bolt_zap ALONG the mover's angles, so we aim it at the target and
// fly it). Returns the flight time.
function hop_bolt( v_from, v_to )
{
    t_fly = Distance( v_from, v_to ) / getdvarfloat( "acc_cj_bolt_speed", 700 );
    if ( t_fly < 0.25 ) t_fly = 0.25;   // below this the CF snapshot eats the visual
    if ( t_fly > 1.0 )  t_fly = 1.0;
    level thread hop_bolt_mover( v_from, v_to, t_fly );
    return t_fly;
}

function hop_bolt_mover( v_from, v_to, t_fly )
{
    level endon( "end_game" );
    mover = Spawn( "script_model", v_from );
    if ( !isdefined( mover ) ) return;
    mover SetModel( "tag_origin" );
    mover.angles = VectorToAngles( v_to - v_from );      // the zap fx fires along these
    mover clientfield::set( "elem_storm_bolt_fx", 1 );   // DE lightning zap-bolt (storm .csc)
    mover MoveTo( v_to, t_fly );
    wait t_fly;
    if ( !isdefined( mover ) ) return;
    mover clientfield::set( "elem_storm_bolt_fx", 0 );
    wait 0.1;                                             // let the 0-snapshot land
    if ( isdefined( mover ) ) mover Delete();
}

// ---- corruption lifecycle (VERIFY-PASS RESTRUCTURE) ----
// mark_corrupted = flag + owner + the SLOW thread, always together (the slow's live
// expiry is the guaranteed flag-clear path - no leak on shooter disconnect or
// mid-flight death). start_dot = the damage ticks, only on a landed hit. The old
// combined corrupt_one had an AND-gate hole (double-DoT re-corruption window).
function mark_corrupted( z, player, tier )
{
    if ( !is_corruptible( z ) )          return;
    if ( IS_TRUE( z.acc_cj_corrupted ) ) return;

    z.acc_cj_corrupted = true;   // read by _acc_zombie_speed (slow) + the harvest death hook
    z.acc_cj_owner     = player;

    // The jack-in READS: tesla eyes flare on root (one-shot burst, server-side - the safe
    // replacement for the disabled elem_storm_shock_fx actor CF).
    PlayFxOnTag( level._effect[ "acc_cj_shock_eyes" ], z, "j_head" );
    PlaySoundAtPosition( "acc_cj_zap", z.origin );   // [acc] jack-in root crackle (sfx sweep 2026-07-21)

    z thread corruption_slow( tier );
}

function start_dot( z, player, w, tier )
{
    if ( !isdefined( z ) || !isalive( z ) )       return;
    if ( !IS_TRUE( z.acc_cj_corrupted ) )         return;   // only rooted zombies decompile
    if ( isdefined( z.acc_cj_dot_running ) )      return;   // one DoT loop per zombie, ever-concurrent
    z thread corruption_dot( player, w, tier );
}

// Flicker-slow: anim-rate cut while corrupted, timed force-restore watchdog. The
// acc_cj_corrupted flag is honored by _acc_zombie_speed::under_anim_slow so the
// speed system never stomps the rate mid-slow. The flag SURVIVES death on purpose
// (the harvest hook reads it off the corpse); only a LIVE expiry clears it.
// VERIFY-PASS FIXES: float division (2500/1000 was INTEGER 2s; a sub-1000 tune was
// wait 0), a one-frame floor, and the slow now LENGTHENS per tier (docs/43 F3) with
// a default window that outlives the full DoT (3 ticks) so ticks never race the purge.
function corruption_slow( tier )   // self = zombie
{
    self endon( "death" );

    rate = getdvarfloat( "acc_cj_slow_rate", 0.8 );
    self ASMSetAnimationRate( rate );

    t = ( getdvarint( "acc_cj_slow_ms", 3500 ) + tier * getdvarint( "acc_cj_slow_ms_tier", 500 ) ) / 1000.0;
    if ( t < 0.05 ) t = 0.05;
    wait t;

    if ( isdefined( self ) && isalive( self ) )
    {
        self ASMSetAnimationRate( 1.0 );
        self.acc_cj_corrupted = undefined;   // live expiry: corruption purged
        self.acc_cj_owner     = undefined;
    }
}

// Decompile DoT: N 1s ticks of fraction-of-CURRENT-health damage (round-proof at any
// round - the Fire Bow portal recipe), player-attacker for kill credit/points/drops.
// Each tick is an ISOLATED thread: pack-AI damage handlers can throw mid-chain.
function corruption_dot( player, w, tier )   // self = zombie
{
    self endon( "death" );
    self.acc_cj_dot_running = true;

    ticks = getdvarint( "acc_cj_dot_ticks", 3 );
    frac  = getdvarfloat( "acc_cj_dot_frac", 0.306 ) + ( getdvarfloat( "acc_cj_dot_frac_tier", 0.072 ) * tier );   // x0.9 all-lane cyberjack -10% 2026-07-27 (was 0.34 / +0.08)

    for ( t = 0; t < ticks; t++ )
    {
        wait 1.0;
        if ( !isdefined( self ) || !isalive( self ) ) break;
        if ( !IS_TRUE( self.acc_cj_corrupted ) )      break;   // purged by the slow expiry
        self thread dot_tick_one( player, w, frac );
    }

    if ( isdefined( self ) )
        self.acc_cj_dot_running = undefined;
}

function dot_tick_one( player, w, frac )   // self = zombie; isolated per tick
{
    if ( !isdefined( self ) || !isalive( self ) ) return;
    if ( !isdefined( player ) || !isplayer( player ) ) return;
    n = int( self.health * frac ) + 1;
    // The decompile READS: a tesla-shock burst on every tick (v3 lightning identity).
    PlayFxOnTag( level._effect[ "acc_cj_shock" ], self, "j_spineupper" );
    // VERIFY-PASS FIX: the exact-damage mark (the Fire Bow portal recipe's own hardening,
    // consumed one-shot at _acc_damage:438) - without it the tick is rescaled by the FULL
    // pipeline (x0.288 bal x3.25 global + ENERGY/explosive item layers) and the designed
    // fraction becomes meaningless. The mark makes the fraction land VERBATIM.
    self.acc_tg_exact_dmg = n;
    self DoDamage( n, self.origin, player, player, "none", "MOD_PROJECTILE_SPLASH", 0, w );
}

// ---- decompile harvest: corrupted deaths burst a physical Data Shard pickup ----
function on_zombie_death_harvest()   // self = the dying zombie
{
    if ( !IS_TRUE( self.acc_cj_corrupted ) ) return;

    // Per-round hard cap (docs/43 decision 1: the approved economy exception must
    // never trivialize abyss-door pricing).
    cap = getdvarint( "acc_cj_harvest_cap_base", 3 ) + int( level.round_number / 10 );
    if ( level.acc_cj_harvest_round_n >= cap ) return;

    chance = getdvarfloat( "acc_cj_harvest_chance", 0.20 );
    owner  = self.acc_cj_owner;
    if ( isdefined( owner ) && isplayer( owner )
         && acc_pap_levels::cyberjack_tier( owner ) >= 2 )
        chance = chance * 2;   // BLACK ICE (tier 2 = v3.0) doubles the scrape - docs/43 F3 (VERIFY-PASS FIX: was >=3, one tier late)

    if ( RandomFloat( 1.0 ) >= chance ) return;

    level.acc_cj_harvest_round_n++;
    // The shipped shard-drop spawner: floor-snaps the corpse origin itself
    // (hovering-death memory) and self-cleans on grab / 30s expiry.
    acc_data_shards::spawn_pickup_at( self.origin, 1 );
}

function harvest_round_reset()
{
    level endon( "end_game" );
    n_last = 0;
    for ( ;; )
    {
        wait 1.0;
        if ( isdefined( level.round_number ) && level.round_number != n_last )
        {
            n_last = level.round_number;
            level.acc_cj_harvest_round_n = 0;
        }
    }
}

// =============================================================================
// BRUTUS GUN-DROP ACQUISITION (user 2026-07-17)
// -----------------------------------------------------------------------------
// Brutus (Trench Warden) death rolls 25% THE CYBERJACK on the ground / 75% the
// normal boss item - NEVER both (_acc_boss::grant_unified_boss_reward skips the
// item when the gun drops). ONLY ONE CYBERJACK in rotation: if any player already
// holds it OR a ground pickup is live, Brutus can't drop it (falls through to the
// item). A holder who DIES and loses the gun frees the rotation - the HasWeapon
// scan below is the live source of truth (no persistent claim to get stuck).
// Acquisition rides the box's own weapon_give path so charge/PaP/OC all bootstrap.
// =============================================================================

function cyberjack_player_has()   // self = player -> true if holding any CYBERJACK form
{
    prims = self GetWeaponsListPrimaries();
    for ( i = 0; i < prims.size; i++ )
        if ( isdefined( prims[ i ] ) && isdefined( prims[ i ].name ) && IsSubStr( prims[ i ].name, "apex_lstar" ) )
            return true;
    return false;
}

// First player whose PRIMARIES list carries any CYBERJACK form (undefined = nobody).
// Split out of cyberjack_in_rotation so the [CJ] dev trace can NAME the blocker.
function cyberjack_holder()
{
    players = GetPlayers();
    for ( i = 0; i < players.size; i++ )
    {
        p = players[ i ];
        if ( isdefined( p ) && isplayer( p ) && p cyberjack_player_has() )
            return p;
    }
    return undefined;
}

// The "1 in rotation" gate: true = the gun is unavailable (someone holds it or a pickup is live).
function cyberjack_in_rotation()
{
    if ( IS_TRUE( level.acc_cj_pickup_live ) ) return true;
    // DEV EXEMPTION (2026-07-20 "Brutus never drops at 100%" root cause): the dev starting
    // loadout (_acc_dev::dev_give_starting_guns) hands EVERY player a CYBERJACK ~1.5s after
    // blackscreen and re-gives it each life, so in a dev session the holder scan below is
    // permanently true and this gate could NEVER open - the Brutus drop was unreachable at
    // ANY roll chance (it can also hide in a background Mule-Kick slot, so "nobody holding
    // one" on screen still scans true). In dev, only the pickup_live gate above applies
    // (still prevents stacked ground pickups). Ship behavior (acc_dev false) unchanged.
    if ( IS_TRUE( level.acc_dev ) ) return false;
    return isdefined( cyberjack_holder() );
}

// Called by the Brutus death handler. Returns TRUE iff the gun dropped (so the caller
// skips the boss item - "never both"). 25% when available; 0% when in rotation.
function try_brutus_gun_drop( drop_origin )
{
    if ( !isdefined( drop_origin ) )
    {
        cj_log( "drop BLOCKED: drop_origin UNDEFINED (corpse reaped + attacker not a player)" );
        return false;
    }
    if ( cyberjack_in_rotation() )     // only 1 in play
    {
        holder = cyberjack_holder();
        if ( IS_TRUE( level.acc_cj_pickup_live ) )
            cj_log( "drop BLOCKED: a ground pickup is already live" );
        else if ( isdefined( holder ) )
            cj_log( "drop BLOCKED: " + holder.name + " carries a CYBERJACK (primaries scan - dev loadout gives one every life)" );
        else
            cj_log( "drop BLOCKED: rotation closed" );
        return false;
    }
    // Resolve the weapon BEFORE committing the "gun instead of item" (verify-pass: don't
    // skip the item if the pack is somehow absent = "neither").
    w = GetWeapon( "apex_lstar" );
    if ( !isdefined( w ) || w == level.weaponNone )
    {
        cj_log( "drop BLOCKED: GetWeapon(apex_lstar) unresolved - pack absent from this build?" );
        return false;
    }
    // 25% SHIP RATE (restored, user 2026-07-20 "put it back to 25%" after the flow was verified
    // live at 100% - the 2026-07-20 find: the dev loadout's free CYBERJACK closed the rotation
    // gate, which is why drops never appeared in dev sessions).
    roll   = RandomFloat( 1.0 );
    chance = getdvarfloat( "acc_cj_brutus_gun_chance", 0.25 );
    if ( roll >= chance )
    {
        cj_log( "drop: roll " + roll + " >= chance " + chance + " - no gun (item instead)" );
        return false;
    }
    cj_log( "drop: roll " + roll + " < chance " + chance + " - SPAWNING the CYBERJACK pickup" );
    level thread spawn_cyberjack_pickup( drop_origin, w );
    return true;
}

// [CJ] gun-drop trace (2026-07-20 "never drops at 100%" hunt). Rides acc_dev ONLY (project
// doctrine - no debug dvar); the sci_log pattern. IPrintLnBold on a player also lands in
// console_mp.log as a [ SCRIPTER] line (docs/17), so a test kill leaves a written trace.
function cj_log( msg )
{
    if ( !IS_TRUE( level.acc_dev ) ) return;
    players = GetPlayers();
    for ( i = 0; i < players.size; i++ )
    {
        if ( isdefined( players[ i ] ) && isplayer( players[ i ] ) )
            players[ i ] IPrintLnBold( "^5[CJ]^7 " + msg );
    }
}

function spawn_cyberjack_pickup( origin, w )
{
    level endon( "end_game" );

    if ( !isdefined( w ) || w == level.weaponNone ) return;

    origin = acc_utility::drop_floor_origin( origin );
    m = Spawn( "script_model", origin + ( 0, 0, getdvarint( "acc_drop_model_z", 24 ) ) );
    if ( !isdefined( m ) ) return;                       // verify-pass: guard Spawn (entity budget)
    if ( isdefined( w.worldModel ) ) m SetModel( w.worldModel );

    t = Spawn( "trigger_radius_use", origin + ( 0, 0, 40 ), 0, 60, 72 );
    if ( !isdefined( t ) ) { m Delete(); return; }       // guard Spawn; NEVER set pickup_live on failure

    // Committed - both entities exist. ONLY NOW mark the rotation taken (no stuck-true path:
    // if either Spawn had failed above we returned without ever setting the flag).
    level.acc_cj_pickup_live = true;
    cj_log( "pickup COMMITTED at " + origin + " (spinning model + use trigger; " + getdvarfloat( "acc_cj_pickup_life_s", 60 ) + "s expiry)" );
    m thread cj_pickup_spin();
    t TriggerIgnoreTeam();            // public pickup (required for a script-spawned use trigger)
    t UseTriggerRequireLookAt();
    t SetCursorHint( "HINT_NOICON" );
    t SetHintString( "Hold ^3[{+activate}]^7 to jack in the ^5CYBERJACK" );   // unique word "jack in" dodges the ZMCursorHintNew catch-all
    t.acc_cj_model = m;

    t thread cj_pickup_expire();      // frees the rotation if never grabbed

    t endon( "acc_cj_pickup_gone" );
    for ( ;; )
    {
        t waittill( "trigger", player );
        if ( !isdefined( player ) || !isplayer( player ) || !isalive( player ) ) continue;
        if ( player cyberjack_player_has() ) continue;   // guard: never double-give
        player cyberjack_grant_to( w );
        cj_log( "pickup GRABBED by " + player.name );
        break;
    }

    level.acc_cj_pickup_live = false;
    if ( isdefined( m ) ) m Delete();
    if ( isdefined( t ) ) t Delete();
}

function cj_pickup_spin()   // self = model
{
    self endon( "death" );
    for ( ;; ) { self RotateYaw( 120, 1.0 ); wait 1.0; }
}

function cj_pickup_expire()   // self = trigger
{
    level endon( "end_game" );
    wait getdvarfloat( "acc_cj_pickup_life_s", 60 );
    cj_log( "pickup EXPIRED un-grabbed - rotation freed" );
    level.acc_cj_pickup_live = false;
    self notify( "acc_cj_pickup_gone" );
    if ( isdefined( self.acc_cj_model ) ) self.acc_cj_model Delete();
    if ( isdefined( self ) ) self Delete();
}

// self = player. Grant via the box's OWN give path - the SAME call the Paradise wonder
// pickup uses (spawn_one_wonder_pickup), which at max primaries REPLACES the currently-held
// gun exactly like the mystery box (user: "replace the gun you are holding"). No manual
// TakeWeapon here - weapon_give owns the swap; a manual take would double-remove.
function cyberjack_grant_to( w )
{
    self zm_weapons::weapon_give( w, undefined, undefined, undefined, true );
    self SwitchToWeapon( w );
    self PlayLocalSound( "acc_cj_jackin" );
    self IPrintLnBold( "^5THE CYBERJACK^7 - jacked in" );
}
