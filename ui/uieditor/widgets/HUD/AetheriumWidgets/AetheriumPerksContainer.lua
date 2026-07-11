-- Aetherium Perks Container Widget
-- Dynamically displays perks as player acquires them
--
-- ACC REWIRE (2026-07-03): driven by OUR clientuimodel bitmasks accOwnedMask / accMegaMask
-- (_acc_lui.gsc perk_state_watch), NOT the kit's stock hudItems.perks.* models. Why: the
-- stock models are 0/1 (no Mega state) and our 10th perk (combat_efficiency) has no stock
-- uimodel. Mask semantics + Ronan base(red)/mega(teal) art match the retired CoD.AccPerkBar
-- (acc_hud.lua), including ACQUISITION order (first-bought keeps the leftmost slot). The
-- per-slot list key embeds the mega state, so a Mega upgrade re-keys the slot and the list
-- infra swaps the icon art (a plain models.image mutation would not repaint).

require( "ui.uieditor.widgets.HUD.Mappings.AetheriumPerks" )  -- For CoD.AetheriumPerks table
require( "ui.uieditor.widgets.HUD.AetheriumWidgets.AetheriumPerkItem" )

-- Lua 5.1 / HavokScript has no bitwise operators - test bit b arithmetically (acc_hud.lua idiom).
local BitIsSet = function ( mask, b )
	return math.floor( mask / ( 2 ^ b ) ) % 2 >= 1
end

-- Rebuild element.perksList from the two masks. Returns true if the visible row changed.
local HandlePerksList = function ( element, controller )
	if not element then
		return false
	end
	if not element.perksList then
		element.perksList = {}
	end
	if not element.accOrder then
		element.accOrder = {}   -- perk records in ACQUISITION order (persists across rebuilds)
	end

	local controllerModel = Engine.GetModelForController( controller )
	local owned = Engine.GetModelValue( Engine.GetModel( controllerModel, "accOwnedMask" ) ) or 0
	local mega = Engine.GetModelValue( Engine.GetModel( controllerModel, "accMegaMask" ) ) or 0

	-- Acquisition order: still-owned perks keep their slot; newly-owned append on the RIGHT.
	local newOrder = {}
	local seen = {}
	for _, perk in ipairs( element.accOrder ) do
		if BitIsSet( owned, perk.bit ) and not seen[perk.bit] then
			newOrder[#newOrder + 1] = perk
			seen[perk.bit] = true
		end
	end
	local newestBit = nil
	for index = 1, #CoD.AetheriumPerks do
		local perk = CoD.AetheriumPerks[index]
		if BitIsSet( owned, perk.bit ) and not seen[perk.bit] then
			newOrder[#newOrder + 1] = perk
			seen[perk.bit] = true
			newestBit = perk.bit
		end
	end
	element.accOrder = newOrder

	-- Build the datasource rows. Key carries bit + mega state so any visual change re-keys.
	local rebuilt = {}
	for slot = 1, #newOrder do
		local perk = newOrder[slot]
		local isMega = BitIsSet( mega, perk.bit )
		rebuilt[slot] = {
			models = {
				image = ( isMega and perk.imageMega or perk.image ),
				status = 1,
				newPerk = ( perk.bit == newestBit )
			},
			properties = {
				key = "accperk_" .. perk.bit .. ( isMega and "_mega" or "_base" )
			}
		}
	end

	-- Only swap the list (and redraw) when a slot's key actually changed.
	local changed = ( #rebuilt ~= #element.perksList )
	if not changed then
		for slot = 1, #rebuilt do
			if rebuilt[slot].properties.key ~= element.perksList[slot].properties.key then
				changed = true
				break
			end
		end
	end
	if changed then
		element.perksList = rebuilt
	end

	return changed
end

-- DataSource for perks list
DataSources.AetheriumPerks = DataSourceHelpers.ListSetup( "AetheriumPerks", function ( controller, element )
	-- ACC perf: updateDataSource() re-invokes this callback right after the mask subscription
	-- already ran HandlePerksList - only rebuild here on the FIRST setup (no list yet).
	if not element.perksList then
		HandlePerksList( element, controller )
	end
	-- Pass the (already fresh) list to the datasource so it updates the UIList
	return element.perksList
end, true )

local PreLoadFunc = function ( self, controller )
	-- ACC: subscribe to our two mask models (clientuimodel clientfields are auto-piped into
	-- these per-controller LUI models by the engine - the proven acc_hud.lua path). CreateModel
	-- is create-or-get, so registration order vs the clientfield push doesn't matter.
	local controllerModel = Engine.GetModelForController( controller )
	local maskModels = { "accOwnedMask", "accMegaMask" }
	for index = 1, #maskModels do
		self:subscribeToModel( Engine.CreateModel( controllerModel, maskModels[index] ), function ( model )
			-- If HandlePerksList returns true, let's update the datasource
			if HandlePerksList( self.PerkList, controller ) then
				self.PerkList:updateDataSource()
			end
		end, false )
	end
end

-- Main widget
CoD.AetheriumPerksContainer = InheritFrom( LUI.UIElement )
CoD.AetheriumPerksContainer.new = function ( menu, controller )
	local self = LUI.UIElement.new()

	if PreLoadFunc then
		PreLoadFunc( self, controller )
	end

	self:setUseStencil( false )
	self:setClass( CoD.AetheriumPerksContainer )
	self.id = "AetheriumPerksContainer"
	self.soundSet = "default"
	self:setLeftRight( true, true, 0, 0 )
	self:setTopBottom( true, true, 0, 0 )
	self.anyChildUsesUpdateState = true

	-- Perk list (horizontal layout, centered at bottom)
	self.PerkList = LUI.UIList.new( menu, controller, 2, 0, nil, false, false, 0, 0, false, false )
	self.PerkList:makeFocusable()
	self.PerkList:setLeftRight( false, false, -180, 180 )  -- Center horizontally (360px total for 20 perks)
	self.PerkList:setTopBottom( true, false, 666, 694 )  -- Position at 666px from top (28px tall)
	self.PerkList:setWidgetType( CoD.AetheriumPerkItem )
	self.PerkList:setHorizontalCount( 20 )  -- Max 20 perks displayed horizontally
	self.PerkList:setSpacing( 2 )  -- 2px spacing between perks
	self.PerkList:setAlignment( Enum.LUIAlignment.LUI_ALIGNMENT_CENTER )
	self.PerkList:setDataSource( "AetheriumPerks" )
	self:addElement( self.PerkList )

	return self
end
