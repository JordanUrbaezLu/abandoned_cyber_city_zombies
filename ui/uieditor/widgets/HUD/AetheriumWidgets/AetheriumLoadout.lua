-- Aetherium Loadout Widget (Bottom Right - Weapon/Ammo Display)
-- Uses: i_mtl_ui_hud_loadout_theme_aetherium

require( "ui.uieditor.widgets.HUD.Mappings.AetheriumWeapons" )  -- For CoD.AetheriumWeaponData table
require( "ui.uieditor.widgets.HUD.Mappings.AetheriumAAT" )  -- For CoD.AetheriumAAT mappings
require( "ui.uieditor.widgets.HUD.AetheriumWidgets.AetheriumPerksContainer" )  -- Perks widget

-- Helper function to get weapon data by display name OR codename
function CoD.GetWeaponDataByName(weaponName)
	if not weaponName or weaponName == "" then
		return CoD.AetheriumWeaponData["default"] or {
			icon = "i_mtl_ui_icon_zm_ping_mystery_box",
			description = ""
		}
	end
	
	-- Safety check: ensure CoD.AetheriumWeaponData exists
	if not CoD.AetheriumWeaponData then
		return {
			icon = "i_mtl_ui_icon_zm_ping_mystery_box",
			description = ""
		}
	end
	
	local lowerName = string.lower(weaponName)
	local normalizedName = lowerName:gsub("%s+", "")  -- Remove all spaces for comparison
	
	-- Try exact codename match first
	if CoD.AetheriumWeaponData[weaponName] then
		return CoD.AetheriumWeaponData[weaponName]
	end
	
	-- Try matching against ingame_name field (case-insensitive search with space normalization)
	for weaponKey, weaponInfo in pairs(CoD.AetheriumWeaponData) do
		if weaponInfo.ingame_name then
			local lowerIngameName = string.lower(weaponInfo.ingame_name)
			local normalizedIngameName = lowerIngameName:gsub("%s+", "")  -- Remove spaces for comparison
			
			-- Check if normalized names match
			if normalizedName == normalizedIngameName then
				return weaponInfo
			end
			
			-- Also check if the hint text contains the ingame name (original behavior)
			if string.find(lowerName, lowerIngameName, 1, true) then
				return weaponInfo
			end
		end
	end
	
	-- Try partial codename match (for cases like "sat_ar_hawk_zm" finding "sat_ar_hawk")
	for weaponKey, weaponInfo in pairs(CoD.AetheriumWeaponData) do
		local lowerKey = string.lower(weaponKey)
		if string.find(lowerName, lowerKey, 1, true) then
			return weaponInfo
		end
	end
	
	-- Fallback to default
	return CoD.AetheriumWeaponData["default"] or {
		icon = "i_mtl_ui_icon_zm_ping_mystery_box",
		description = ""
	}
end

-- Weapon icon helper function (for loadout display)
local function GetWeaponIcon( weaponName )
	if not weaponName or weaponName == "" then
		return "blacktransparent"
	end
	
	-- Safety check: ensure CoD.AetheriumWeaponData exists
	if not CoD.AetheriumWeaponData then
		return "blacktransparent"
	end
	
	-- Remove common prefixes/suffixes for cleaner lookup
	local cleanWeapon = weaponName:gsub("_upgraded", ""):gsub("_upg", ""):gsub("_zm", "")

	-- ACC FIX (2026-07-03): this map swaps weapons for tuned VARIANTS most of a real run -
	-- _acc_weapon_variants.gsc suffixes (_acc_recoil50 / _acc_fastfire_fastreload / ...),
	-- akimbo forms (_rdw/_ldw), and the Action Figure speed twins (_fast1..3). Without these
	-- strips every variant missed the table and the icon went blank mid-game even for mapped
	-- guns. Strip them down to the base codename the table keys on.
	-- (2026-07-11: "_brz$" = the Berzerker implant's AF tier ladder, t8_melee_figure[_fastN]_brz -
	-- stripped BEFORE _fast%d so both suffixes peel; the leviathan brz forms ride the _acc_ strip.)
	cleanWeapon = cleanWeapon:gsub("_acc_.*$", ""):gsub("_[lr]dw$", ""):gsub("_brz$", ""):gsub("_fast%d$", "")

	-- Check for exact match first
	if CoD.AetheriumWeaponData[cleanWeapon] and CoD.AetheriumWeaponData[cleanWeapon].icon then
		return CoD.AetheriumWeaponData[cleanWeapon].icon
	end
	
	-- Try stripping _up suffix as fallback
	local baseWeapon = cleanWeapon:gsub("_up", "")
	if CoD.AetheriumWeaponData[baseWeapon] and CoD.AetheriumWeaponData[baseWeapon].icon then
		return CoD.AetheriumWeaponData[baseWeapon].icon
	end
	
	-- Final fallback: return default icon or blacktransparent
	if CoD.AetheriumWeaponData["default"] and CoD.AetheriumWeaponData["default"].icon then
		return CoD.AetheriumWeaponData["default"].icon
	end
	
	return "blacktransparent"
end

CoD.AetheriumLoadout = InheritFrom( LUI.UIElement )
CoD.AetheriumLoadout.new = function ( menu, controller )
	local self = LUI.UIElement.new()

	self:setUseStencil( false )
	self:setClass( CoD.AetheriumLoadout )
	self.id = "AetheriumLoadout"
	self.soundSet = "default"
	self:setLeftRight( true, false, 0, 1280 )
	self:setTopBottom( true, false, 0, 720 )
	self.anyChildUsesUpdateState = true

	-- Loadout Background (elem10)
	self.loadout = LUI.UIImage.new()
	self.loadout:setLeftRight(true, false, 885, 1312)
	self.loadout:setTopBottom(true, false, 512, 720)
	self.loadout:setImage( RegisterImage( "i_mtl_ui_hud_loadout_theme_aetherium" ) )
	self.loadout:setRGB( 1.000, 1.000, 1.000 )
	self.loadout:setAlpha( 1.0 )
	self:addElement( self.loadout )

	-- Weapon Icon (elem17)
	self.weapon_icon = LUI.UIImage.new()
	self.weapon_icon:setLeftRight(true, false, 1055, 1165)
	self.weapon_icon:setTopBottom(true, false, 599, 664)
	self.weapon_icon:setImage( RegisterImage( "blacktransparent" ) )
	self.weapon_icon:setRGB( 1.000, 1.000, 1.000 )
	self.weapon_icon:setAlpha( 1.0 )
	self:addElement( self.weapon_icon )
	
	-- Track previous weapon for swap detection
	local previousWeaponName = ""
	
	-- Weapon swap animation clips
	self.weapon_icon.clipsPerState = {
		DefaultState = {
			DefaultClip = function()
				self.weapon_icon:completeAnimation()
				self.weapon_icon:setAlpha( 1 )
			end,
			WeaponSwap = function()
				self.weapon_icon:completeAnimation()
				
				-- Fade out + slide right
				self.weapon_icon:beginAnimation( "keyframe", 120, false, false, CoD.TweenType.Linear )
				self.weapon_icon:setAlpha( 0 )
				self.weapon_icon:setLeftRight( true, false, 1085, 1195 )  -- Shift right 30px
				
				self.weapon_icon:registerEventHandler( "transition_complete_keyframe", function()
					-- Fade in + slide from left
					self.weapon_icon:setLeftRight( true, false, 1025, 1135 )  -- Start left 30px
					self.weapon_icon:beginAnimation( "keyframe", 120, false, false, CoD.TweenType.Linear )
					self.weapon_icon:setAlpha( 1 )
					self.weapon_icon:setLeftRight( true, false, 1055, 1165 )  -- Back to center
				end )
			end
		}
	}
	
	-- Subscribe to weapon changes using viewmodelWeaponName
	-- ACC FIX (2026-07-03, "Five-Seven had no icon at spawn"): the model is often set BEFORE
	-- this menu exists (the STARTING weapon), and the subscription alone never re-fires for a
	-- pre-existing value - the spawn gun stayed blank until the first weapon switch. Keep the
	-- handler in a local, subscribe, AND invoke it once immediately (same fix for the name below).
	local iconHandler = function ( model )
		local weaponName = Engine.GetModelValue( model )
		if weaponName then
			local weaponIcon = GetWeaponIcon( weaponName )
			
			-- Trigger swap animation if weapon changed (not initial load)
			if previousWeaponName ~= "" and previousWeaponName ~= weaponName then
				-- Play swap animation BEFORE changing icon
				self.weapon_icon:animateToState( "WeaponSwap" )

				-- Delay icon change to middle of animation (after fade out).
				-- [acc] STATE-POOL LEAK FIX (2026-07-04): the kit created a NEW UITimer per weapon
				-- switch (grenade throws toggle the weapon twice!) and never closed it - LUI timers
				-- fire repeatedly until closed, so hundreds of dead timers accumulated over a game
				-- (the gradual frame decay; state-pool pressure). Keep ONE handle, close the old one
				-- before re-creating, and close it inside the handler so it fires exactly once.
				if self.accIconSwapTimer then self.accIconSwapTimer:close() end
				self.accIconSwapTimer = LUI.UITimer.new( 130, "weapon_swap_icon_change" )
				self.weapon_icon:addElement( self.accIconSwapTimer )
				self.weapon_icon:registerEventHandler( "weapon_swap_icon_change", function()
					if self.accIconSwapTimer then self.accIconSwapTimer:close(); self.accIconSwapTimer = nil end
					self.weapon_icon:setImage( RegisterImage( weaponIcon ) )
				end )
			else
				-- Initial load - no animation
				self.weapon_icon:setImage( RegisterImage( weaponIcon ) )
			end
			
			-- Update previous weapon
			previousWeaponName = weaponName
			
			-- Check if it's equipment (grenade, cymbal_monkey, etc.)
			local isEquipment = weaponName:find("frag_grenade") or 
								weaponName:find("octobomb") or 
			                    weaponName:find("cymbal_monkey") or
			                    weaponName:find("sticky_grenade") or
			                    weaponName:find("_grenade") or
			                    weaponName:find("knife_") or
			                    weaponName:find("_knife")
			
			if isEquipment then
				-- Equipment position (centered, smaller)
				self.weapon_icon:setLeftRight(true, false, 1093, 1149)
				self.weapon_icon:setTopBottom(true, false, 601, 657)
			else
				-- Regular weapon position (larger)
				self.weapon_icon:setLeftRight(true, false, 1055, 1165)
				self.weapon_icon:setTopBottom(true, false, 599, 664)
			end
		end
	end
	local iconModel = Engine.GetModel( Engine.GetModelForController( controller ), "currentWeapon.viewmodelWeaponName" )
	self.weapon_icon:subscribeToModel( iconModel, iconHandler )
	if iconModel then
		iconHandler( iconModel )   -- ACC: paint the SPAWN weapon (value set before the menu existed)
	end

	-- Weapon Name (elem31) - TEXT
	self.weapon_name = LUI.UIText.new()
	self.weapon_name:setLeftRight(true, false, 847, 1106)
	self.weapon_name:setTopBottom(true, false, 568, 585)
	self.weapon_name:setText( Engine.Localize( "" ) )
	self.weapon_name:setTTF( "fonts/orbitron.ttf" )
	self.weapon_name:setRGB( 1.0, 1.0, 1.0 )
	self.weapon_name:setAlignment(Enum.LUIAlignment.LUI_ALIGNMENT_CENTER)
	self:addElement( self.weapon_name )
	
	-- Track previous weapon name
	local previousWeaponTextName = ""
	
	-- Weapon name swap animation
	self.weapon_name.clipsPerState = {
		DefaultState = {
			DefaultClip = function()
				self.weapon_name:completeAnimation()
				self.weapon_name:setAlpha( 1 )
			end,
			WeaponSwap = function()
				self.weapon_name:completeAnimation()
				
				-- Fade out
				self.weapon_name:beginAnimation( "keyframe", 100, false, false, CoD.TweenType.Linear )
				self.weapon_name:setAlpha( 0 )
				
				self.weapon_name:registerEventHandler( "transition_complete_keyframe", function()
					-- Fade in
					self.weapon_name:beginAnimation( "keyframe", 100, false, false, CoD.TweenType.Linear )
					self.weapon_name:setAlpha( 1 )
				end )
			end
		}
	}
	
	-- ACC FIX: same subscribe-then-invoke-once shape as the icon above (spawn-weapon paint).
	local nameHandler = function ( model )
		local weaponName = Engine.GetModelValue( model )
		if weaponName then
			-- Trigger animation if name changed
			if previousWeaponTextName ~= "" and previousWeaponTextName ~= weaponName then
				self.weapon_name:animateToState( "WeaponSwap" )

				-- Change text in middle of animation.
				-- [acc] STATE-POOL LEAK FIX (2026-07-04): same never-closed per-switch UITimer leak
				-- as the icon above - one handle, close old, close inside the handler (fires once).
				if self.accNameSwapTimer then self.accNameSwapTimer:close() end
				self.accNameSwapTimer = LUI.UITimer.new( 100, "weapon_name_text_change" )
				self.weapon_name:addElement( self.accNameSwapTimer )
				self.weapon_name:registerEventHandler( "weapon_name_text_change", function()
					if self.accNameSwapTimer then self.accNameSwapTimer:close(); self.accNameSwapTimer = nil end
					self.weapon_name:setText( Engine.Localize( weaponName ) )
				end )
			else
				-- Initial load
				self.weapon_name:setText( Engine.Localize( weaponName ) )
			end
			
			previousWeaponTextName = weaponName
		end
	end
	local nameModel = Engine.GetModel( Engine.GetModelForController( controller ), "currentWeapon.weaponName" )
	self.weapon_name:subscribeToModel( nameModel, nameHandler )
	if nameModel then
		nameHandler( nameModel )   -- ACC: paint the SPAWN weapon's name
	end

	-- Ammo Clip (elem24) - TEXT
	self.ammo_clip = LUI.UIText.new()
	self.ammo_clip:setLeftRight(true, false, 948, 1061)
	self.ammo_clip:setTopBottom(true, false, 605, 624)
	self.ammo_clip:setText( Engine.Localize( "0" ) )
	self.ammo_clip:setTTF( "fonts/ltromatic.ttf" )
	self.ammo_clip:setRGB( 1.0, 1.0, 1.0 )
	self.ammo_clip:setAlignment( Enum.LUIAlignment.LUI_ALIGNMENT_CENTER )
	self:addElement( self.ammo_clip )
	
	-- Low ammo warning animation timer
	local lowAmmoFlashing = false
	local lowAmmoTimer = nil
	
	self.ammo_clip:subscribeToModel( Engine.GetModel( Engine.GetModelForController( controller ), "currentWeapon.ammoInClip" ), function ( model )
		local ammoInClip = Engine.GetModelValue( model )
		if ammoInClip then
			self.ammo_clip:setText( Engine.Localize( ammoInClip ) )
			
			-- Get max ammo in clip for percentage calculation
			local maxAmmoModel = Engine.GetModel( Engine.GetModelForController( controller ), "currentWeapon.maxAmmoInClip" )
			local maxAmmo = maxAmmoModel and Engine.GetModelValue( maxAmmoModel ) or 30
			
			-- Low ammo threshold: 25% of magazine or less
			local lowAmmoThreshold = math.max( 3, math.floor( maxAmmo * 0.25 ) )
			
			-- Check if ammo is low
			if ammoInClip > 0 and ammoInClip <= lowAmmoThreshold then
				-- Start low ammo flash if not already flashing
				if not lowAmmoFlashing then
					lowAmmoFlashing = true
					
					-- Pulsing red flash animation (official BO3 pattern)
					local function flashLowAmmo()
						self.ammo_clip:completeAnimation()
						self.ammo_clip:beginAnimation( "keyframe", 200, false, false, CoD.TweenType.Linear )
						self.ammo_clip:setRGB( 1, 0, 0 )  -- Red
						self.ammo_clip:setAlpha( 1 )
						self.ammo_clip:registerEventHandler( "transition_complete_keyframe", function()
							if lowAmmoFlashing then
								self.ammo_clip:completeAnimation()
								self.ammo_clip:beginAnimation( "keyframe", 200, false, false, CoD.TweenType.Linear )
								self.ammo_clip:setRGB( 1, 1, 1 )  -- White
								self.ammo_clip:setAlpha( 0.6 )
								self.ammo_clip:registerEventHandler( "transition_complete_keyframe", function()
									if lowAmmoFlashing then
										flashLowAmmo()  -- Loop
									end
								end )
							end
						end )
					end
					
					flashLowAmmo()
				end
			else
				-- Stop flashing
				if lowAmmoFlashing then
					lowAmmoFlashing = false
					self.ammo_clip:completeAnimation()
					self.ammo_clip:setRGB( 1, 1, 1 )  -- Reset to white
					self.ammo_clip:setAlpha( 1 )
				end
			end
		end
	end )

	-- Ammo Stock (elem30) - TEXT
	self.ammo_stock = LUI.UIText.new()
	self.ammo_stock:setLeftRight(true, false, 968, 1057)
	self.ammo_stock:setTopBottom(true, false, 629, 638)
	self.ammo_stock:setText( Engine.Localize( "0" ) )
	self.ammo_stock:setTTF( "fonts/ltromatic.ttf" )
	self.ammo_stock:setRGB( 1.0, 1.0, 1.0 )
	self.ammo_stock:setAlignment( Enum.LUIAlignment.LUI_ALIGNMENT_CENTER )
	self:addElement( self.ammo_stock )
	self.ammo_stock:subscribeToModel( Engine.GetModel( Engine.GetModelForController( controller ), "currentWeapon.ammoStock" ), function ( model )
		local ammoStock = Engine.GetModelValue( model )
		if ammoStock then
			self.ammo_stock:setText( Engine.Localize( ammoStock ) )
		end
	end )

	-- Perks Container (Dynamic - now centered at bottom)
	self.PerksContainer = CoD.AetheriumPerksContainer.new( menu, controller )
	self.PerksContainer:setLeftRight( true, true, 0, 0 )
	self.PerksContainer:setTopBottom( true, true, 0, 0 )
	self:addElement( self.PerksContainer )

	-- Lethal Equipment Background Container
	self.lethal_bg = LUI.UIImage.new()
	self.lethal_bg:setLeftRight( true, false, 1117, 1184 )
	self.lethal_bg:setTopBottom( true, false, 541, 600 )
	self.lethal_bg:setImage( RegisterImage( "i_mtl_ui_hud_leathal" ) )
	self.lethal_bg:setRGB( 1, 1, 1 )
	self:addElement( self.lethal_bg )

	-- Lethal Grenade Icon
	self.lethal_icon = LUI.UIImage.new()
	self.lethal_icon:setLeftRight( true, false, 1126, 1153 )
	self.lethal_icon:setTopBottom( true, false, 554, 577 )
	self.lethal_icon:setImage( RegisterImage( "i_mtl_sat_ui_icon_lethal_grenade_frag" ) )
	self.lethal_icon:setRGB( 1, 1, 1 )
	self:addElement( self.lethal_icon )

	-- Lethal Grenade Count
	self.lethal_count = LUI.UIText.new()
	self.lethal_count:setLeftRight( true, false, 1153, 1180 )
	self.lethal_count:setTopBottom( true, false, 567, 579 )
	self.lethal_count:setText( Engine.Localize( "+4" ) )
	self.lethal_count:setTTF( "fonts/orbitron.ttf" )
	self.lethal_count:setRGB( 1, 1, 1 )
	self.lethal_count:setAlignment( Enum.LUIAlignment.LUI_ALIGNMENT_LEFT )
	self:addElement( self.lethal_count )

	-- Subscribe to lethal equipment count
	self.lethal_count:subscribeToModel( Engine.GetModel( Engine.GetModelForController( controller ), "currentPrimaryOffhand.primaryOffhandCount" ), function ( model )
		local count = Engine.GetModelValue( model )
		if count and count > 0 then
			-- Has grenades - show filled state
			self.lethal_bg:setImage( RegisterImage( "i_mtl_ui_hud_leathal" ) )
			self.lethal_icon:setLeftRight( true, false, 1126, 1153 )
			self.lethal_icon:setTopBottom( true, false, 554, 577 )
			self.lethal_icon:setImage( RegisterImage( "i_mtl_sat_ui_icon_lethal_grenade_frag" ) )
			self.lethal_count:setText( Engine.Localize( "+" .. count ) )
			self.lethal_count:setAlpha( 1 )
		else
			-- No grenades - show empty state with custom positioning
			self.lethal_bg:setImage( RegisterImage( "i_mtl_ui_hud_leathal_empty" ) )
			self.lethal_icon:setLeftRight( true, false, 1136, 1163 )
			self.lethal_icon:setTopBottom( true, false, 555, 578 )
			self.lethal_icon:setImage( RegisterImage( "i_mtl_sat_ui_icon_lethal_grenade_frag_empty" ) )
			self.lethal_count:setAlpha( 0 )
		end
	end )

	-- Tactical Equipment Background Container
	self.tactical_bg = LUI.UIImage.new()
	self.tactical_bg:setLeftRight( true, false, 1057, 1124 )
	self.tactical_bg:setTopBottom( true, false, 541, 600 )
	self.tactical_bg:setImage( RegisterImage( "i_mtl_ui_hud_tactical_empty" ) )
	self.tactical_bg:setRGB( 1, 1, 1 )
	self:addElement( self.tactical_bg )

	-- Tactical Equipment Icon (Dynamic based on equipment type)
	self.tactical_icon = LUI.UIImage.new()
	self.tactical_icon:setLeftRight( true, false, 1065, 1099 )
	self.tactical_icon:setTopBottom( true, false, 556, 585 )
	self.tactical_icon:setImage( RegisterImage( "blacktransparent" ) )
	self.tactical_icon:setRGB( 1, 1, 1 )
	self.tactical_icon:setAlpha( 0 )
	self:addElement( self.tactical_icon )

	-- Tactical Equipment Count
	self.tactical_count = LUI.UIText.new()
	self.tactical_count:setLeftRight( true, false, 1099, 1124 )
	self.tactical_count:setTopBottom( true, false, 565, 577 )
	self.tactical_count:setText( Engine.Localize( "+4" ) )
	self.tactical_count:setTTF( "fonts/orbitron.ttf" )
	self.tactical_count:setRGB( 1, 1, 1 )
	self.tactical_count:setAlignment( Enum.LUIAlignment.LUI_ALIGNMENT_LEFT )
	self.tactical_count:setAlpha( 0 )
	self:addElement( self.tactical_count )

	-- Track tactical equipment state
	local hasEverHadTactical = false
	local currentTacticalIcon = ""
	local currentTacticalIconEmpty = ""
	
	-- Subscribe to tactical icon changes (official BO3 pattern)
	self.tactical_icon:subscribeToGlobalModel( controller, "CurrentSecondaryOffhand", "secondaryOffhand", function ( model )
		local iconPath = Engine.GetModelValue( model )
		if iconPath then
			-- Map vanilla icons to custom icons
			if iconPath == "uie_t7_zm_hud_inv_icntactlilarnie" then
				-- Li'l Arnie (Octobomb)
				currentTacticalIcon = "i_mtl_hud_octobomb"
				currentTacticalIconEmpty = "i_mtl_hud_octobomb_empty"
			else
				-- Cymbal Monkey or other
				currentTacticalIcon = "i_mtl_sat_ui_icon_zm_support_cymball_monkey"
				currentTacticalIconEmpty = "i_mtl_sat_ui_icon_zm_support_cymball_monkey_empty"
			end
			
			-- Update display with mapped icon
			local countModel = Engine.GetModel( Engine.GetModelForController( controller ), "currentSecondaryOffhand.secondaryOffhandCount" )
			local count = countModel and Engine.GetModelValue( countModel ) or 0
			
			if count and count > 0 then
				self.tactical_icon:setImage( RegisterImage( currentTacticalIcon ) )
			elseif hasEverHadTactical then
				self.tactical_icon:setImage( RegisterImage( currentTacticalIconEmpty ) )
			end
		end
	end )

	-- Subscribe to count changes
	self.tactical_count:subscribeToModel( Engine.GetModel( Engine.GetModelForController( controller ), "currentSecondaryOffhand.secondaryOffhandCount" ), function ( model )
		local count = Engine.GetModelValue( model )
		
		if count and count > 0 then
			hasEverHadTactical = true
			self.tactical_bg:setImage( RegisterImage( "i_mtl_ui_hud_tactical" ) )
			self.tactical_icon:setLeftRight( true, false, 1065, 1099 )
			self.tactical_icon:setTopBottom( true, false, 556, 585 )
			-- Use stored mapped icon
			if currentTacticalIcon ~= "" then
				self.tactical_icon:setImage( RegisterImage( currentTacticalIcon ) )
			end
			self.tactical_icon:setAlpha( 1 )
			self.tactical_count:setText( Engine.Localize( "+" .. count ) )
			self.tactical_count:setAlpha( 1 )
		else
			self.tactical_bg:setImage( RegisterImage( "i_mtl_ui_hud_tactical_empty" ) )
			self.tactical_count:setAlpha( 0 )
			
			if hasEverHadTactical then
				self.tactical_icon:setLeftRight( true, false, 1077, 1111 )
				self.tactical_icon:setTopBottom( true, false, 549, 578 )
				-- Use stored empty icon
				if currentTacticalIconEmpty ~= "" then
					self.tactical_icon:setImage( RegisterImage( currentTacticalIconEmpty ) )
				end
				self.tactical_icon:setAlpha( 1 )
			else
				self.tactical_icon:setAlpha( 0 )
			end
		end
	end )

	-- Ammo Mod Icon (AAT - Alternate Ammo Type)
	self.ammo_mod_icon = LUI.UIImage.new()
	self.ammo_mod_icon:setLeftRight(true, false, 1037, 1061)
	self.ammo_mod_icon:setTopBottom(true, false, 641, 665)
	self.ammo_mod_icon:setImage(RegisterImage("blacktransparent"))
	self.ammo_mod_icon:setRGB(1, 1, 1)
	self.ammo_mod_icon:setAlpha(0)
	self:addElement(self.ammo_mod_icon)
	
	-- Subscribe to AAT changes (Ammo Mod system)
	-- Use currentWeapon.aatIcon model (no CSC needed!)
	self.ammo_mod_icon:subscribeToModel(Engine.GetModel(Engine.GetModelForController(controller), "currentWeapon.aatIcon"), function(model)
		local aatIcon = Engine.GetModelValue(model)
		
		if aatIcon and aatIcon ~= "" then
			local iconPath = CoD.GetAATIcon(aatIcon)
			self.ammo_mod_icon:setImage(RegisterImage(iconPath))
			self.ammo_mod_icon:setAlpha(1)
		else
			self.ammo_mod_icon:setAlpha(0)
		end
	end)

	-- ============================================================================
	-- [acc] SHIELD EQUIPMENT SLOT (2026-07-15, user: "we have a riot shield but the hud
	-- doesnt show it... I was expecting somewhere in gun HUD"). A SATELLITE slot on the
	-- loadout orb's rim: the grenade (lethal) slot owns the upper-right rim, the AAT icon
	-- + gun-badge row own the lower-left, so the shield takes the LOWER-RIGHT, plate
	-- tilted to follow the rim tangent (screenshot pass 1 2026-07-15: the first flat
	-- placement at 1117..1184/603..662 landed ON the orb - user: "rotate it and place it
	-- at the edge of the circle, may take multiple tries"). Shows while the Rocket Shield
	-- implant's native zod_riotshield is granted (_acc_boss_items::apply_rocket_shield);
	-- the icon tint IS the shield's remaining health (blue -> orange -> red, the kit's
	-- own thresholds). While the shield is DESTROYED but the implant is still benched
	-- (the 60s regrant window) the slot shows the empty plate + dim icon instead of
	-- vanishing - "it's coming back".
	--
	-- WIRING (docs/19; memory riot-shield-native-give-recipe): zmInventory.shield_health
	-- and hudItems.showDpadDown are server set_player_uimodel bridges with NO client node
	-- until their first write -> must Engine.CreateModel (NEVER GetModel) or the
	-- subscription never fires (the kit's PlayerInfo shield bar shipped dead on exactly
	-- that). Stock's shield-DESTROY path (_zm_weap_riotshield UpdateRiotShieldModel)
	-- writes ONLY showDpadDown=0 and leaves shield_health untouched, so ONE refresh is
	-- subscribed to EVERY gate model. acc_implants = the implant slot cards' 16-bit
	-- toplayer nibble wire (bits 0-11 = the 3 active slots); Rocket Shield = item 4
	-- (_acc_boss_items build_item_pool), decoded by floor-division (no bit ops in HKS
	-- Lua 5.1 - the AccImplantRow math). Plate art reuses the tactical slot's images -
	-- already registered above, zero new assets.
	-- PLACEMENT CONSTANTS - the whole geometry derives from these; every screenshot-pass
	-- iteration is a 1-2 number tweak + `.\tools\build_map.ps1 -GscOnly` (~1 min). The orb
	-- center comes from the weapon_icon anchor box (1055..1165 / 599..664); the visible
	-- ring reads as ~r90 in-game.
	-- Pass 3 (user 2026-07-15 screenshot: "to the right of grenades along the circle's
	-- edge like grenades and cymbal monkeys"): continue the equipment arc CLOCKWISE past
	-- the grenade slot - monkey, grenade, then shield wrapping down the upper-right rim.
	-- Grenade slot center sits at roughly -57 deg / r~71 from the orb center; the next
	-- stop clockwise is ~-22 deg, radius pushed to ~103 so the plate clears the grenade
	-- box (ends x 1184) and its "+4" counter (1153..1180 / 567..579).
	local SHIELD_ORB_CX = 1112     -- loadout orb center, virtual 1280x720
	local SHIELD_ORB_CY = 630
	-- Pass 5 (user: "bigger jump in rotation and more to left"): the key insight from the
	-- pass-4 screenshot - the GRENADE plate center sits at r~71 from the orb center, but
	-- the shield was out at r=87, so it floated OFF the ring. Radius pulled to 72 (same
	-- orbit as the grenade = moves left at this position, same height), and the tilt
	-- doubled to -60 so the plate lies ALONG the ring edge, extending clockwise off the
	-- grenade slot.
	local SHIELD_ANGLE = -20       -- degrees from 3 o'clock; NEGATIVE = above horizontal (grenade ~ -57), positive = below
	local SHIELD_RADIUS = 72       -- orb center -> plate center (grenade plate orbits at ~71)
	local SHIELD_PLATE_W = 56      -- tactical plate scaled down (~0.84) so it reads as a rim tab
	local SHIELD_PLATE_H = 49
	local SHIELD_PLATE_ROT = -60   -- setZRot degrees; plate long-axis along the ring edge at this spot.
	                               -- Same sign as pass 4 (user asked for MORE, not the other way).
	local SHIELD_ICON_S = 26       -- icon square; kept UPRIGHT for readability (setZRot it too if preferred)

	local shieldRad = math.rad( SHIELD_ANGLE )
	local shieldCX = SHIELD_ORB_CX + SHIELD_RADIUS * math.cos( shieldRad )
	local shieldCY = SHIELD_ORB_CY + SHIELD_RADIUS * math.sin( shieldRad )

	self.shield_bg = LUI.UIImage.new()
	self.shield_bg:setLeftRight( true, false, shieldCX - SHIELD_PLATE_W / 2, shieldCX + SHIELD_PLATE_W / 2 )
	self.shield_bg:setTopBottom( true, false, shieldCY - SHIELD_PLATE_H / 2, shieldCY + SHIELD_PLATE_H / 2 )
	self.shield_bg:setImage( RegisterImage( "i_mtl_ui_hud_tactical_empty" ) )
	self.shield_bg:setZRot( SHIELD_PLATE_ROT )
	self.shield_bg:setRGB( 1, 1, 1 )
	self.shield_bg:setAlpha( 0 )
	self:addElement( self.shield_bg )

	self.shield_icon = LUI.UIImage.new()
	self.shield_icon:setLeftRight( true, false, shieldCX - SHIELD_ICON_S / 2, shieldCX + SHIELD_ICON_S / 2 )
	self.shield_icon:setTopBottom( true, false, shieldCY - SHIELD_ICON_S / 2, shieldCY + SHIELD_ICON_S / 2 )
	self.shield_icon:setImage( RegisterImage( "riotshield_zm_icon" ) )
	self.shield_icon:setAlpha( 0 )
	self:addElement( self.shield_icon )

	local shieldControllerModel = Engine.GetModelForController( controller )
	local shieldHealthModel = Engine.CreateModel( shieldControllerModel, "zmInventory.shield_health" )
	local shieldDpadModel = Engine.CreateModel( shieldControllerModel, "hudItems.showDpadDown" )
	local shieldImplantModel = Engine.CreateModel( shieldControllerModel, "acc_implants" )

	local RefreshShieldSlot = function ()
		local health = Engine.GetModelValue( shieldHealthModel ) or 0
		local dpad = Engine.GetModelValue( shieldDpadModel ) or 0
		local nibbles = Engine.GetModelValue( shieldImplantModel ) or 0
		local implanted = false
		for s = 1, 3 do
			if math.floor( nibbles / ( 16 ^ ( s - 1 ) ) ) % 16 == 4 then implanted = true end
		end

		if dpad > 0 and health > 0 then
			-- Shield carried: lit plate, icon tinted by remaining shield health
			self.shield_bg:setImage( RegisterImage( "i_mtl_ui_hud_tactical" ) )
			self.shield_bg:setAlpha( 1 )
			self.shield_icon:setAlpha( 1 )
			if health <= 0.33 then
				self.shield_icon:setRGB( 1, 0.4, 0.4 )      -- Red: nearly broken
			elseif health <= 0.66 then
				self.shield_icon:setRGB( 1, 0.8, 0.4 )      -- Orange: damaged
			else
				self.shield_icon:setRGB( 0.4, 0.7, 1 )      -- Blue: healthy
			end
		elseif implanted then
			-- Destroyed, but the implant regrants in 60s: empty plate + dim icon
			self.shield_bg:setImage( RegisterImage( "i_mtl_ui_hud_tactical_empty" ) )
			self.shield_bg:setAlpha( 1 )
			self.shield_icon:setAlpha( 0.35 )
			self.shield_icon:setRGB( 0.6, 0.6, 0.6 )
		else
			-- No shield and no implant: slot hidden entirely
			self.shield_bg:setAlpha( 0 )
			self.shield_icon:setAlpha( 0 )
		end
	end

	self:subscribeToModel( shieldHealthModel, RefreshShieldSlot )
	self:subscribeToModel( shieldDpadModel, RefreshShieldSlot )
	self:subscribeToModel( shieldImplantModel, RefreshShieldSlot )
	RefreshShieldSlot()   -- initial paint (mid-run HUD rebuild / rejoin)

	-- Note: Hero weapon display now handled by official ZmAmmo_DpadMeterSword and ZmAmmo_DpadIconPistolFactory widgets
	-- These are added directly in AetheriumHud.lua for better compatibility and full feature support

	return self
end
