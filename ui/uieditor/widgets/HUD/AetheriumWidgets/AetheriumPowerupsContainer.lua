-- Aetherium Powerups Container Widget
-- Dynamically displays active powerups with timers

require( "ui.uieditor.widgets.HUD.AetheriumWidgets.AetheriumPowerupItem" )

-- Powerup Table (BO6 Overhaul Pattern)
-- ACC (2026-07-03, user: "the old icons are what they should use"): images swapped from the
-- kit's BO7-style sat_* / stock t7_* art to OUR Ronan cyberpunk icons - the same
-- i_acc_powerup_* set the retired CoD.AccPowerupBar drew (all already zone-listed with the
-- perk icons; GDT source_data/acc_perk_shaders.gdt). This table also feeds the pickup
-- notification banner (AetheriumPowerupNotification), so both displays get the Ronan art.
-- Death Machine keeps the stock t7 icon - the old bar never had it, so no Ronan art exists.
CoD.PowerUps.ClientFieldNames = {
	{
		clientFieldName = "powerup_instant_kill",
		name = "Insta Kill",
		image = "i_acc_powerup_instakill"
	},
	{
		clientFieldName = "powerup_double_points",
		name = "Double Points",
		image = "i_acc_powerup_double"
	},
	{
		clientFieldName = "powerup_fire_sale",
		name = "Fire Sale",
		image = "i_acc_powerup_sale"
	},
	{
		clientFieldName = "powerup_mini_gun",
		name = "Death Machine",
		image = "t7_hud_zm_powerup_deathmachine"   -- no Ronan art for this one (old bar never showed it)
	},
	{
		clientFieldName = "powerup_full_ammo",
		name = "Max Ammo",
		image = "i_acc_powerup_maxammo"
	},
	{
		clientFieldName = "powerup_carpenter",
		name = "Carpenter",
		image = "i_acc_powerup_carpenter"
	},
	{
		clientFieldName = "powerup_nuke",
		name = "Nuke",
		image = "i_acc_powerup_nuke"
	}
}

CoD.PowerUps.Update = function ( self, event )
	local powerupStateModel = Engine.GetModel( Engine.GetModelForController( event.controller ), event.name .. ".state" )

	if powerupStateModel ~= nil then
		Engine.SetModelValue( powerupStateModel, event.newValue )
	end
end

local PreLoadFunc = function ( self, controller )
	for index = 1, #CoD.PowerUps.ClientFieldNames do
		Engine.CreateModel( Engine.GetModelForController( controller ), CoD.PowerUps.ClientFieldNames[index].clientFieldName .. ".state" )
		Engine.CreateModel( Engine.GetModelForController( controller ), CoD.PowerUps.ClientFieldNames[index].clientFieldName .. ".time" )
	end
end

local PostLoadFunc = function ( self, controller, menu )
	for index = 1, #CoD.PowerUps.ClientFieldNames do
		local powerupStateModel = Engine.GetModel( Engine.GetModelForController( controller ), CoD.PowerUps.ClientFieldNames[index].clientFieldName .. ".state" )
		local powerupTimeModel = Engine.GetModel( Engine.GetModelForController( controller ), CoD.PowerUps.ClientFieldNames[index].clientFieldName .. ".time" )
		
		if powerupStateModel ~= nil then
			self.PowerupList:subscribeToModel( powerupStateModel, function ( model )
				self.PowerupList:updateDataSource()
			end )
		end

		if powerupTimeModel ~= nil then
			self.PowerupList:subscribeToModel( powerupTimeModel, function ( model )
				self.PowerupList:updateDataSource()
			end )
		end
	end
end

DataSources.AetheriumPowerups = DataSourceHelpers.ListSetup( "AetheriumPowerups", function ( controller, element )	
	local powerups = {}

	local powerupState = nil
	local powerupTime = nil

	for index = 1, #CoD.PowerUps.ClientFieldNames do
		powerupState = Engine.GetModelValue( Engine.GetModel( Engine.GetModelForController( controller ), CoD.PowerUps.ClientFieldNames[index].clientFieldName .. ".state" ) )
		powerupTime = Engine.GetModelValue( Engine.GetModel( Engine.GetModelForController( controller ), CoD.PowerUps.ClientFieldNames[index].clientFieldName .. ".time" ) )

		if powerupState then
			if powerupState > 0 then
				table.insert( powerups, {
					models = {
						image = CoD.PowerUps.ClientFieldNames[index].image,
						state = powerupState,
						time = powerupTime
					}
				} )
			end
		end
	end

	return powerups
end, true )

-- Main widget
CoD.AetheriumPowerupsContainer = InheritFrom( LUI.UIElement )
CoD.AetheriumPowerupsContainer.new = function ( menu, controller )
	local self = LUI.UIElement.new()

	if PreLoadFunc then
		PreLoadFunc( self, controller )
	end

	self:setUseStencil( false )
	self:setClass( CoD.AetheriumPowerupsContainer )
	self.id = "AetheriumPowerupsContainer"
	self.soundSet = "HUD"
	self:setLeftRight( true, true, 0, 0 )
	self:setTopBottom( true, true, 0, 0 )
	self.anyChildUsesUpdateState = true

	-- Powerup list (horizontal layout, centered at position)
	self.PowerupList = LUI.UIList.new( menu, controller, 17, 0, nil, false, false, 0, 0, false, false )
	self.PowerupList:makeFocusable()
	self.PowerupList:setLeftRight( false, false, -132, 132 )  -- Centered (4 * 49px + 3 * 17px spacing = 264px total width)
	self.PowerupList:setTopBottom( true, false, 597, 646 )    -- Position at 597-646 (49px tall)
	self.PowerupList:setWidgetType( CoD.AetheriumPowerupItem )
	self.PowerupList:setHorizontalCount( 4 )  -- Max 4 powerups displayed horizontally
	self.PowerupList:setSpacing( 17 )  -- 17px spacing between powerups
	self.PowerupList:setAlignment( Enum.LUIAlignment.LUI_ALIGNMENT_CENTER )
	self.PowerupList:setDataSource( "AetheriumPowerups" )
	self:addElement( self.PowerupList )

	if PostLoadFunc then
		PostLoadFunc( self, controller, menu )
	end

	return self
end
