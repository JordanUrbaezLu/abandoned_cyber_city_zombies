-- Acc Area Banner Widget (2026-08-02, user: PNG art replaces the top-center area TEXT banner)
-- Top-center location title: swaps between the 14 user-supplied recon-plate banners
-- (i_acc_area_* - 1024x256 originals re-baked to 720x180 shipped masters when the box
-- shrank 30% on 2026-08-02 user feedback; 720 = 2.01x the real display px, the no-mips
-- rule, memory hud-images-pre-downscale-no-mips). Trench set carries progressive glitch
-- corruption; PARADISE is amber.
--
-- DATA: the 4-bit "accArea" clientuimodel clientfield (0 = hidden, 1..14 = area id in
-- _acc_dev.gsc dev_area_code order). The SERVER stays the state machine (_acc_dev.gsc
-- dev_update_zone: show-on-change, 3.75s surface hold, persistent hold underground/Paradise)
-- - this widget is a dumb renderer: fade in on 0->N, swap art on N->M, fade out on N->0.
-- Engine.GetModel (NOT CreateModel): clientuimodel nodes exist at clientfield registration
-- - the idiom of all existing acc fields (accRoundRing etc., acc_hud.lua).
--
-- FADES: 0.3s fade-in mirrors the old hudelem's FadeOverTime(0.3); the 0.4s fade-OUT is an
-- upgrade (the old path Destroy()'d instantly at the 5s mark). Alpha caps at 0.85 like the
-- old elem so the art doesn't dominate the dark arenas. completeAnimation->beginAnimation
-- tweens only; NO UITimers (leak trap, memory lui-uitimer-leaks-state-pool) - the hold
-- (3.75s since 2026-08-02, was 5s) lives server-side. Menu/scoreboard hides ride the AetheriumHud guarded alpha blocks
-- (this widget is added to all three; container alpha multiplies the Img alpha).
--
-- LAYOUT: Img box x520.53..759.47, y4..63.74 (238.94x59.74 LUI, exact 4:1; launched at
-- 341.33x85.33, -30% on 2026-08-02 user feedback). Top-center verified clear (2026-08-02
-- recon): compass ACC DISABLED (mutual exclusion - never enable both), 2D boss bar dormant,
-- lockdown label starts y93, trench warning y165, Paradise timer y225. Bonus of the -30%:
-- the box now ends ABOVE the CenterConsole band (y68.5+) - the launch size's transient
-- print underlap is gone entirely.

CoD.AccAreaBanner = InheritFrom( LUI.UIElement )
CoD.AccAreaBanner.new = function ( menu, controller )
	local self = LUI.UIElement.new()

	self:setUseStencil( false )
	self:setClass( CoD.AccAreaBanner )
	self.id = "AccAreaBanner"
	self.soundSet = "HUD"
	self:setLeftRight( true, false, 0, 1280 )
	self:setTopBottom( true, false, 0, 720 )
	-- Positioning handled by parent HUD (full-canvas container, child anchored absolute)
	self.anyChildUsesUpdateState = true

	local Img = LUI.UIImage.new()
	Img:setLeftRight( false, false, -119.47, 119.47 )
	Img:setTopBottom( true, false, 4, 63.74 )
	Img:setAlpha( 0 )
	self:addElement( Img )
	self.Img = Img

	-- Register handles ONCE, swap via setImage (the implant-card idiom, memory
	-- implant-png-hud-slot-cards). Index = accArea id 1..17 (15..17 = the 2026-08-02
	-- sub-area rooms; order MUST match _acc_dev.gsc dev_area_code).
	local handles = {
		RegisterImage( "i_acc_area_plaza" ),
		RegisterImage( "i_acc_area_market" ),
		RegisterImage( "i_acc_area_alley" ),
		RegisterImage( "i_acc_area_busstation" ),
		RegisterImage( "i_acc_area_vault" ),
		RegisterImage( "i_acc_area_helipad" ),
		RegisterImage( "i_acc_area_lab" ),
		RegisterImage( "i_acc_area_exchange" ),
		RegisterImage( "i_acc_area_paradise" ),
		RegisterImage( "i_acc_area_trench1" ),
		RegisterImage( "i_acc_area_trench2" ),
		RegisterImage( "i_acc_area_trench3" ),
		RegisterImage( "i_acc_area_trench4" ),
		RegisterImage( "i_acc_area_trench5" ),
		RegisterImage( "i_acc_area_armory" ),      -- 15
		RegisterImage( "i_acc_area_scioffice" ),   -- 16
		RegisterImage( "i_acc_area_implant" ),     -- 17
	}

	local shownId = 0
	local function render( v )
		v = tonumber( v ) or 0
		if v < 1 or v > #handles then
			if shownId ~= 0 then
				shownId = 0
				Img:completeAnimation()
				Img:beginAnimation( "keyframe", 400, false, false, CoD.TweenType.Linear )
				Img:setAlpha( 0 )
			end
			return
		end
		if v == shownId then
			return
		end
		local wasHidden = ( shownId == 0 )
		shownId = v
		Img:setImage( handles[ v ] )
		Img:completeAnimation()
		if wasHidden then
			Img:setAlpha( 0 )
			Img:beginAnimation( "keyframe", 300, false, false, CoD.TweenType.Linear )
			Img:setAlpha( 0.85 )
		else
			-- area->area swap while visible (e.g. descending trench floors): instant art
			-- swap at full reveal alpha - parity with the old hudelem's SetText.
			Img:setAlpha( 0.85 )
		end
	end

	-- subscribeToModel fires once at subscribe time with the current value = initial paint
	-- (covers menu construction after the server already pushed a value). HARDENED 2026-08-02
	-- (first-test "UI error" report): T7Hud_zm_factory is built EARLY, and this is the repo's
	-- first custom-clientfield model subscription from that menu (every other acc field
	-- subscribes from the late-opened acc_hud) - whether the clientuimodel node exists that
	-- early is unproven, and subscribeToModel(nil) throws a UI Error. Engine.CreateModel
	-- returns the existing node or creates the path (idempotent - the CF bridge writes the
	-- same path; acc_objective/AetheriumStartMenu precedent), so it can never hand nil.
	local areaModel = Engine.CreateModel( Engine.GetModelForController( controller ), "accArea" )
	if areaModel then
		self:subscribeToModel( areaModel, function ( m )
			render( Engine.GetModelValue( m ) )
		end )
	end

	return self
end
