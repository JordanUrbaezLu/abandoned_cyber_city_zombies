-- Acc Round Recon Widget (2026-08-01, user: the teal "Round N" text was "too plain")
-- GEN-2 top-left round display: the user-supplied recon-frame PNG (i_acc_round_frame -
-- cyan corner brackets + smoked-glass center + baked "ROUND" plate, shipped 300x300
-- pre-downscaled per the no-mips rule, memory hud-images-pre-downscale-no-mips) with
-- the round NUMBER drawn in the bracket square in orbitron (the Aetherium display font).
--
-- DATA: the engine-owned per-controller UI model "gameScore.roundsPlayed" (= round + 1;
-- decode = max(1, v-1), the AetheriumScoreboard.lua round_number idiom). Engine.GetModel
-- is correct here (engine-owned model, always exists; Engine.CreateModel is only needed
-- for server-pushed models with no client node until first write - gun-badge lesson).
-- ZERO clientfields/uimodels/hudelems: all three CF pools + the clientuimodel pool are
-- FULL, and this widget replaces a GSC hudelem (frees 1 per client).
--
-- FADES: instantiated in AetheriumHud.lua as self.AetheriumRoundCounter, so the kit's
-- three existing guarded alpha blocks (init alpha, BIT_SCOREBOARD_OPEN hide,
-- BIT_UI_ACTIVE pause hide) drive it with zero new fade code.
--
-- ROUND-CHANGE FLASH (replaces the old hudelem's setPulseFX(80,800,700)): the number
-- pops (scale 1.3 -> 1, teal -> white over 0.8s) and the frame does a quick re-scan
-- flicker (alpha 0.25 -> 1). completeAnimation -> beginAnimation tween idiom only;
-- NO UITimers (leak trap, memory lui-uitimer-leaks-state-pool) and no clips, so the
-- model subscription is the widget's only live state and dies with the element.

CoD.AccRoundRecon = InheritFrom( LUI.UIElement )
CoD.AccRoundRecon.new = function ( menu, controller )
	local self = LUI.UIElement.new()

	self:setUseStencil( false )
	self:setClass( CoD.AccRoundRecon )
	self.id = "AccRoundRecon"
	self.soundSet = "HUD"
	self:setLeftRight( true, false, 0, 1280 )
	self:setTopBottom( true, false, 0, 720 )
	-- Positioning handled by parent HUD (full-canvas container, children anchored absolute)
	self.anyChildUsesUpdateState = true

	-- FRAME: x30..110, y32..112 (80x80 LUI = 120 real px @1080p; master is 240 = exactly
	-- 2x - re-baked from the 512 original at each resize). SIZE HISTORY: 120sq at launch,
	-- -17% to 100sq, then -20% to 80sq (user 2026-08-02, two rounds of "smaller"); anchor
	-- corner (30,32) kept throughout. The old teal text anchored at LUI ~(80,45); the band
	-- down to the first implant card (y220) is clear (acc_hud.lua AccImplantRow GEOMETRY
	-- note), and at 80sq the frame also fully clears the dormant RocketShieldBlueprintWidget
	-- box (y117+, AetheriumHud.lua note).
	local Frame = LUI.UIImage.new()
	Frame:setLeftRight( true, false, 30, 110 )
	Frame:setTopBottom( true, false, 32, 112 )
	Frame:setImage( RegisterImage( "i_acc_round_frame" ) )
	self:addElement( Frame )
	self.Frame = Frame

	-- NUMBER, centered on the art's MEASURED bracket-square center (2026-08-02 pixel scan:
	-- (255.5, 197.5) on the 512 ORIGINAL i_acc_round_frame.png.acc-512-orig; the SHIPPED
	-- master is its 240x240 downscale - same proportions). Mapping: art_px * 80/512 + frame
	-- origin (30,32) -> center (69.9, 62.9) CANVAS coords. Box 67.2x30.8 around it (the
	-- launch-era proportions scaled with the frame). Font baseline offsets dominate at this
	-- size, so retune by EYE, not by art math. Box h=30.8 = ~46 real px @1080p; orbitron has
	-- no shipped >16px-box precedent (recon 2026-08-01) - eyeball crispness in-game.
	local Num = LUI.UIText.new()
	Num:setLeftRight( true, false, 36.3, 103.5 )
	Num:setTopBottom( true, false, 47.5, 78.3 )
	Num:setTTF( "fonts/orbitron.ttf" )
	Num:setRGB( 0.94, 0.96, 1.0 )
	Num:setAlignment( Enum.LUIAlignment.LUI_ALIGNMENT_CENTER )
	Num:setText( Engine.Localize( "1" ) )
	self:addElement( Num )
	self.Num = Num

	local lastRound = nil
	-- nil-guarded (2026-08-02 hardening; the acc_gameover.lua "if m == nil then return"
	-- idiom): gameScore.roundsPlayed is engine-owned and expected present at HUD build -
	-- the guard converts a hypothetical early-build miss into "shows 1" instead of a
	-- UI Error from subscribeToModel(nil).
	local roundModel = Engine.GetModel( Engine.GetModelForController( controller ), "gameScore.roundsPlayed" )
	if roundModel then
	self:subscribeToModel( roundModel, function ( model )
		local roundsPlayed = Engine.GetModelValue( model )
		if not roundsPlayed then
			return
		end
		local currentRound = math.max( 1, roundsPlayed - 1 )
		if lastRound == currentRound then
			return
		end
		local isChange = lastRound ~= nil   -- first fire = initial paint, no flash
		lastRound = currentRound
		Num:setText( Engine.Localize( tostring( currentRound ) ) )
		if isChange then
			-- Number pop: teal flash settling to white over 0.8s (the old pulse's sustain).
			Num:completeAnimation()
			Num:setScale( 1.3 )
			Num:setRGB( 0.3, 0.85, 1.0 )
			Num:beginAnimation( "keyframe", 800, false, false, CoD.TweenType.Linear )
			Num:setScale( 1 )
			Num:setRGB( 0.94, 0.96, 1.0 )
			-- Frame re-scan flicker.
			Frame:completeAnimation()
			Frame:setAlpha( 0.25 )
			Frame:beginAnimation( "keyframe", 600, false, false, CoD.TweenType.Linear )
			Frame:setAlpha( 1 )
		end
	end )
	end   -- if roundModel

	return self
end
