-- Perks Prompt Widget
-- Dynamically displays perk information based on cursor hint

-- Widget definition
CoD.PromptPerks = InheritFrom( LUI.UIElement )

function CoD.PromptPerks.new( menu, controller )
	local self = LUI.UIElement.new()
	
	if PreLoadFunc then
		PreLoadFunc( self, controller )
	end
	
	self:setUseStencil( false )
	self:setClass( CoD.PromptPerks )
	self.id = "PromptPerks"
	self.soundSet = "default"
	self.acc_controller = controller   -- ACC: kept so UpdatePerkInfo can read the owned/mega masks
	self:setLeftRight( true, false, 0, 1280 )
	self:setTopBottom( true, false, 0, 720 )
	self:setAlpha( 0 )  -- Start hidden, parent controls visibility
	
	-- Main background
	self.mainBG = LUI.UIImage.new()
	self.mainBG:setLeftRight( true, false, 616, 772 )
	self.mainBG:setTopBottom( true, false, 460, 518 )
	self.mainBG:setImage( RegisterImage( "i_mtl_image_3a5dcba7b0d44850" ) )
	self.mainBG:setRGB( 1, 1, 1 )
	self:addElement( self.mainBG )
	
	-- Header background
	self.headerBG = LUI.UIImage.new()
	self.headerBG:setLeftRight( true, false, 615, 773 )
	self.headerBG:setTopBottom( true, false, 446, 461 )
	self.headerBG:setImage( RegisterImage( "i_mtl_image_4b19966fe6b8a3f4" ) )
	self.headerBG:setRGB( 1, 1, 1 )
	self:addElement( self.headerBG )
	
	-- Perk name text
	self.perkName = LUI.UIText.new()
	self.perkName:setLeftRight( true, false, 620, 754 )
	self.perkName:setTopBottom( true, false, 449, 459 )
	self.perkName:setText( Engine.Localize( "PERK NAME" ) )
	self.perkName:setTTF( "fonts/orbitron.ttf" )
	self.perkName:setRGB( 1, 1, 1 )
	self.perkName:setAlignment( Enum.LUIAlignment.LUI_ALIGNMENT_LEFT )
	self:addElement( self.perkName )
	
	-- Border/frame decoration 1
	self.border1 = LUI.UIImage.new()
	self.border1:setLeftRight( true, false, 618, 775 )
	self.border1:setTopBottom( true, false, 449, 517 )
	self.border1:setImage( RegisterImage( "i_mtl_image_6bac5ab6cef2cf7d" ) )
	self.border1:setRGB( 1, 1, 1 )
	self:addElement( self.border1 )

	-- Perk description text
	self.perkDesc = LUI.UIText.new()
	self.perkDesc:setLeftRight(true, false, 620, 766)
	self.perkDesc:setTopBottom(true, false, 467, 474)
	self.perkDesc:setText( Engine.Localize( "Perk description" ) )
	self.perkDesc:setTTF( "fonts/ltromatic.ttf" )
	self.perkDesc:setRGB( 1, 1, 1 )
	self.perkDesc:setAlignment( Enum.LUIAlignment.LUI_ALIGNMENT_LEFT )
	self:addElement( self.perkDesc )
	
	-- ACC (2026-07-03, user: "should show all the benefits like it did in the past"): the old
	-- info card listed EVERY benefit; the kit had one description line. Add 4 more lines (5
	-- total) + a layout helper that stretches the card art down and slides the footer row when
	-- more lines show. 9px per extra line.
	self.acc_descLines = { self.perkDesc }
	for i = 2, 5 do
		local line = LUI.UIText.new()
		line:setLeftRight( true, false, 620, 766 )
		line:setTopBottom( true, false, 467 + ( i - 1 ) * 9, 474 + ( i - 1 ) * 9 )
		line:setText( Engine.Localize( "" ) )
		line:setTTF( "fonts/ltromatic.ttf" )
		line:setRGB( 1, 1, 1 )
		line:setAlignment( Enum.LUIAlignment.LUI_ALIGNMENT_LEFT )
		self:addElement( line )
		self.acc_descLines[i] = line
	end

	-- Stretch/restore the card for n benefit lines (1..5). Moves the bg/borders' bottoms and
	-- the whole footer row (cost/hold/F/to-buy/currency icon) down by (n-1)*9.
	self.acc_setCardLines = function( n )
		local extra = ( n - 1 ) * 9
		self.mainBG:setTopBottom( true, false, 460, 518 + extra )
		self.border1:setTopBottom( true, false, 449, 517 + extra )
		self.border2:setTopBottom( true, false, 445, 518 + extra )
		self.border3:setTopBottom( true, false, 444, 520 + extra )
		self.perkCost:setTopBottom( true, false, 506 + extra, 515 + extra )
		self.footerText:setTopBottom( true, false, 507 + extra, 514 + extra )
		self.interactButton:setTopBottom( true, false, 507 + extra, 514 + extra )
		self.footerText2:setTopBottom( true, false, 507 + extra, 515 + extra )
		self.pointsIcon:setTopBottom( true, false, 503 + extra, 515 + extra )
	end

	-- Fill the 5 lines from a benefit LIST (fallback = the single description string).
	self.acc_setBenefits = function( list, fallback )
		if not list or #list == 0 then
			list = { fallback or "" }
		end
		local n = math.min( #list, 5 )
		for i = 1, 5 do
			if i <= n then
				self.acc_descLines[i]:setText( Engine.Localize( "- " .. list[i] ) )
			else
				self.acc_descLines[i]:setText( Engine.Localize( "" ) )
			end
		end
		self.acc_setCardLines( n )
	end

	-- Border/frame decoration 2
	self.border2 = LUI.UIImage.new()
	self.border2:setLeftRight( true, false, 546, 615 )
	self.border2:setTopBottom( true, false, 445, 518 )
	self.border2:setImage( RegisterImage( "i_mtl_image_7d9423641070f37e" ) )
	self.border2:setRGB( 1, 1, 1 )
	self:addElement( self.border2 )
	
	-- Border/frame decoration 3
	self.border3 = LUI.UIImage.new()
	self.border3:setLeftRight( true, false, 544, 775 )
	self.border3:setTopBottom( true, false, 444, 520 )
	self.border3:setImage( RegisterImage( "i_mtl_image_8a21f7a0f930d3f" ) )
	self.border3:setRGB( 1, 1, 1 )
	self:addElement( self.border3 )
	
	-- Perk cost text
	self.perkCost = LUI.UIText.new()
	self.perkCost:setLeftRight( true, false, 740, 773 )
	self.perkCost:setTopBottom( true, false, 506, 515 )
	self.perkCost:setText( Engine.Localize( "0" ) )
	self.perkCost:setTTF( "fonts/ltromatic.ttf" )
	self.perkCost:setRGB( 0.894, 0.882, 0.424 )  -- Gold/yellow color
	self.perkCost:setAlignment( Enum.LUIAlignment.LUI_ALIGNMENT_LEFT )
	self:addElement( self.perkCost )
	
	-- Footer text "Hold"
	self.footerText = LUI.UIText.new()
	self.footerText:setLeftRight( true, false, 620, 642 )
	self.footerText:setTopBottom( true, false, 507, 514 )
	self.footerText:setText( Engine.Localize( "Hold " ) )
	self.footerText:setTTF( "fonts/ltromatic.ttf" )
	self.footerText:setRGB( 1, 1, 1 )
	self.footerText:setAlignment( Enum.LUIAlignment.LUI_ALIGNMENT_LEFT )
	self:addElement( self.footerText )
	
	-- Interact button text (F key)
	self.interactButton = LUI.UIText.new()
	self.interactButton:setLeftRight( true, false, 643, 652 )
	self.interactButton:setTopBottom( true, false, 507, 514 )
	self.interactButton:setText( Engine.Localize( "F" ) )
	self.interactButton:setTTF( "fonts/ltromatic.ttf" )
	self.interactButton:setRGB( 0.792, 0.780, 0.380 )  -- Gold/yellow color
	self.interactButton:setAlignment( Enum.LUIAlignment.LUI_ALIGNMENT_LEFT )
	self:addElement( self.interactButton )
	
	-- Footer text 2 "to buy"
	self.footerText2 = LUI.UIText.new()
	self.footerText2:setLeftRight( true, false, 650, 704 )
	self.footerText2:setTopBottom( true, false, 507, 515 )
	self.footerText2:setText( Engine.Localize( "to buy" ) )
	self.footerText2:setTTF( "fonts/ltromatic.ttf" )
	self.footerText2:setRGB( 1, 1, 1 )
	self.footerText2:setAlignment( Enum.LUIAlignment.LUI_ALIGNMENT_LEFT )
	self:addElement( self.footerText2 )

	-- Points icon
	self.pointsIcon = LUI.UIImage.new()
	self.pointsIcon:setLeftRight( true, false, 727, 742 )
	self.pointsIcon:setTopBottom( true, false, 503, 515 )
	self.pointsIcon:setImage( RegisterImage( "i_mtl_ui_icons_zombie_essence" ) )
	self.pointsIcon:setRGB( 1, 1, 1 )
	self:addElement( self.pointsIcon )
	
	-- Perk icon
	self.perkIcon = LUI.UIImage.new()
	self.perkIcon:setLeftRight( true, false, 562, 599 )
	self.perkIcon:setTopBottom( true, false, 463, 500 )
	self.perkIcon:setImage( RegisterImage( "" ) )  -- Default icon
	self.perkIcon:setRGB( 1, 1, 1 )
	self:addElement( self.perkIcon )
	
	if PostLoadFunc then
		PostLoadFunc( self, controller, menu )
	end
	
	return self
end

-- Helper function to update perk info from CoD.AetheriumPerks table
-- This should be called from the parent widget when detecting a perk hint
--
-- ACC MEGA-AWARE (2026-07-03, user): the kit only knew the BASE perk. This map has a second
-- tier - MEGA perks, bought at the same machine with a MEGA BOTTLE (a different currency
-- than points). Ownership comes from the accOwnedMask/accMegaMask models (same masks that
-- drive the perk row); per state the card shows:
--   not owned          -> base perk: name / description / cost in points (essence icon, gold)
--   owned, not Mega'd  -> "MEGA: <megaName>" / mega description / cost = 1 MEGA BOTTLE
--                         (Ronan bottle icon, teal - the map's Mega currency)
--   Mega'd             -> "<megaName> - MAX" / mega description / no cost row
-- Mega fields live in Mappings/AetheriumPerks.lua (megaName/megaDescription/imageMega/bit).
local ACC_BitIsSet = function ( mask, b )
	return math.floor( mask / ( 2 ^ b ) ) % 2 >= 1
end

function CoD.PromptPerks.UpdatePerkInfo( self, perkData )
	if not perkData then
		return
	end

	-- Resolve this perk's owned/mega state from the mask models (0 if anything is missing).
	local owned = false
	local isMega = false
	if self.acc_controller ~= nil and perkData.bit ~= nil then
		local controllerModel = Engine.GetModelForController( self.acc_controller )
		local ownedMask = Engine.GetModelValue( Engine.GetModel( controllerModel, "accOwnedMask" ) ) or 0
		local megaMask = Engine.GetModelValue( Engine.GetModel( controllerModel, "accMegaMask" ) ) or 0
		owned = ACC_BitIsSet( ownedMask, perkData.bit )
		isMega = ACC_BitIsSet( megaMask, perkData.bit )
	end

	-- ACC $1-bug fix (2026-07-10): the LIVE machine hint is the definitive base-vs-mega signal, NOT the
	-- async accOwnedMask - it lags the purchase by up to 0.25s (perk_state_watch poll), so a Mega hint can
	-- fall through to the BASE branch below whose "Cost:%s*(%d+)" regex grabs the "1" of "1 Mega Bottle"
	-- and paints a gold Points "1" with the essence icon (the reported "$1"). The literal "Cost: 1 Mega
	-- Bottle" is unique to the mega machine hint (_acc_mega_bottles::mega_trigger_think); the perk-door
	-- unlock reads "for 2 Mega Bottles" (no match), so this only ever forces the Mega-PREVIEW branch.
	if perkData.megaName and self.acc_controller ~= nil then
		local acc_ht = Engine.GetModelValue( Engine.GetModel( Engine.GetModelForController( self.acc_controller ), "hudItems.cursorHintText" ) )
		if acc_ht and string.find( acc_ht, "Cost: 1 Mega Bottle", 1, true ) then
			owned = true
			isMega = false
		end
	end

	if owned and perkData.megaName then
		-- MEGA tier: name + FULL benefit list swap to the Mega upgrade; icon = teal Mega art.
		-- Mega preview (owned, not Mega'd) lists what the bottle ADDS; Mega'd lists every
		-- effective benefit (megaFullBenefits) - the old info card's exact behavior.
		if self.perkName then
			if isMega then
				self.perkName:setText( Engine.Localize( perkData.megaName .. " - MAX" ) )
			else
				self.perkName:setText( Engine.Localize( "MEGA: " .. perkData.megaName ) )
			end
		end
		if self.acc_setBenefits then
			if isMega then
				self.acc_setBenefits( perkData.megaFullBenefits, perkData.megaDescription )
			else
				self.acc_setBenefits( perkData.megaBenefits, perkData.megaDescription )
			end
		end
		if self.perkIcon and perkData.imageMega then
			self.perkIcon:setImage( RegisterImage( perkData.imageMega ) )
		end
		if self.perkCost then
			if isMega then
				self.perkCost:setText( Engine.Localize( "" ) )   -- maxed: no cost row
			else
				-- Cost SPELLED OUT (user 2026-07-03: no bottle icon, say "1 Mega Bottle"):
				-- widen the cost box leftward and right-align so it ends flush at the border.
				self.perkCost:setLeftRight( true, false, 664, 773 )
				self.perkCost:setAlignment( Enum.LUIAlignment.LUI_ALIGNMENT_RIGHT )
				self.perkCost:setText( Engine.Localize( "1 Mega Bottle" ) )
				self.perkCost:setRGB( 0.20, 0.95, 0.85 )   -- teal: Mega Bottle currency, not points
			end
		end
		if self.pointsIcon then
			self.pointsIcon:setAlpha( 0 )   -- no currency icon on the Mega card (user)
		end
		return
	end

	-- BASE perk: full base-benefit list (old card behavior) + gold points cost + essence icon
	if self.perkName and perkData.name then
		self.perkName:setText( Engine.Localize( perkData.name ) )
	end

	if self.acc_setBenefits then
		self.acc_setBenefits( perkData.benefits, perkData.description )
	end

	if self.perkCost and perkData.cost then
		-- ACC (2026-07-03 audit): prefer the LIVE cost from the machine hint over the static
		-- table value - the GSC discounts prices dynamically (The Armory = 10% off), so an
		-- Armory holder sees the real 3600, not the table's 4000. Fallback: table cost.
		local liveCost = nil
		if self.acc_controller ~= nil then
			local hintText = Engine.GetModelValue( Engine.GetModel( Engine.GetModelForController( self.acc_controller ), "hudItems.cursorHintText" ) )
			if hintText and hintText ~= "" then
				liveCost = string.match( hintText, "Cost:%s*(%d+)" ) or string.match( hintText, "%[(%d+)%]" )
			end
		end
		self.perkCost:setLeftRight( true, false, 740, 773 )   -- restore the kit cost box
		self.perkCost:setAlignment( Enum.LUIAlignment.LUI_ALIGNMENT_LEFT )
		self.perkCost:setText( Engine.Localize( liveCost or tostring( perkData.cost ) ) )
		self.perkCost:setRGB( 0.894, 0.882, 0.424 )   -- gold: points cost
	end

	if self.pointsIcon then
		self.pointsIcon:setImage( RegisterImage( "i_mtl_ui_icons_zombie_essence" ) )
		self.pointsIcon:setAlpha( 1 )
	end

	if self.perkIcon and perkData.image then
		self.perkIcon:setImage( RegisterImage( perkData.image ) )
	end
end
