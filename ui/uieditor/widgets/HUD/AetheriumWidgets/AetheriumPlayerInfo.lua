-- Aetherium Player Info Widget (Bottom Left - Main Player)
-- Uses: i_mtl_ui_hud_player_info_theme_aetherium
-- BO6 Pattern: Uses linkToElementModel for dynamic clientNum subscription

require( "ui.uieditor.widgets.HUD.AetheriumWidgets.AetheriumPlusPointsContainer" )
require("ui.uieditor.widgets.HUD.Mappings.AetheriumBBG")
require("ui.uieditor.widgets.HUD.Mappings.AetheriumCharacters")

CoD.AetheriumPlayerInfo = InheritFrom( LUI.UIElement )
CoD.AetheriumPlayerInfo.new = function ( menu, controller )
	local self = LUI.UIElement.new()

	self:setUseStencil( false )
	self:setClass( CoD.AetheriumPlayerInfo )
	self.id = "AetheriumPlayerInfo"
	self.soundSet = "default"
	self:setLeftRight( true, false, 0, 1280 )
	-- NOTE (2026-07-21): do NOT try to shift this panel here - this widget is a UIList ITEM
	-- (AetheriumHud.lua setWidgetType + PlayerListZM datasource) and the list clobbers the item's
	-- own anchors (proven in-game: a -20 offset here did nothing). The 20-up shift that frees the
	-- bottom-left corner for the leveling chip lives on the LIST container in AetheriumHud.lua.
	self:setTopBottom( true, false, 0, 720 )
	self.anyChildUsesUpdateState = true

	-- Main Player Info Background (elem7)
	self.player = LUI.UIImage.new()
	self.player:setLeftRight(true, false, 16, 360)
	self.player:setTopBottom(true, false, 595, 710)
	self.player:setImage( RegisterImage( "i_mtl_ui_hud_player_info_theme_aetherium" ) )
	self.player:setRGB( 1.000, 1.000, 1.000 )
	self.player:setAlpha( 1.0 )
	self:addElement( self.player )

	-- Salvage Icon (elem6)
	-- self.salvage_icon = LUI.UIImage.new()
	-- self.salvage_icon:setLeftRight(true, false, 89, 105)
	-- self.salvage_icon:setTopBottom(true, false, 662, 677)
	-- self.salvage_icon:setImage( RegisterImage( "i_mtl_ui_icons_zombie_squad_info_salvage" ) )
	-- self.salvage_icon:setRGB( 1.000, 1.000, 1.000 )
	-- self.salvage_icon:setAlpha( 1.0 )
	-- self:addElement( self.salvage_icon )

	-- Salvage Amount (elem3) - TEXT
	-- self.salvage_amount = LUI.UIText.new()
	-- self.salvage_amount:setLeftRight(true, false, 105, 178)
	-- self.salvage_amount:setTopBottom(true, false, 665, 676)
	-- self.salvage_amount:setTTF( "fonts/orbitron.ttf" )
	-- self.salvage_amount:setAlignment( Enum.LUIAlignment.LUI_ALIGNMENT_LEFT )
	-- self.salvage_amount:setRGB( 1.000, 1.000, 1.000 )
	-- self.salvage_amount:setText( Engine.Localize( "500000" ) )
	-- self.salvage_amount:setAlpha( 1.0 )
	-- self:addElement( self.salvage_amount )

	-- Points Icon (elem5)
	self.points_icon = LUI.UIImage.new()
	self.points_icon:setLeftRight(true, false, 89, 105)
	self.points_icon:setTopBottom(true, false, 662, 677)
	self.points_icon:setImage( RegisterImage( "i_mtl_ui_icons_zombie_essence" ) )
	self.points_icon:setRGB( 1.000, 1.000, 1.000 )
	self.points_icon:setAlpha( 1.0 )
	self:addElement( self.points_icon )

	-- Points Amount (elem4) - TEXT (reactive to playerScore)
	self.points_amount = LUI.UIText.new()
	self.points_amount:setLeftRight(true, false, 105, 178)
	self.points_amount:setTopBottom(true, false, 665, 676)
	self.points_amount:setTTF( "fonts/ltromatic.ttf" )
	self.points_amount:setAlignment( Enum.LUIAlignment.LUI_ALIGNMENT_LEFT )
	self.points_amount:setRGB(0.984313725490196, 0.9725490196078431, 0.4745098039215686)
	self.points_amount:linkToElementModel( self, "playerScore", true, function ( model )
		local playerScore = Engine.GetModelValue( model )
		if playerScore then
			self.points_amount:setText( Engine.Localize( playerScore ) )
		end
	end )
	self.points_amount:setAlpha( 1.0 )
	self:addElement( self.points_amount )

	-- ========================================================================
	-- ACC CURRENCY ROW (2026-07-03, user: "incorporate all our currencies in the
	-- current base UI"). Same row as the points: Data Shards (Ronan shard icon +
	-- count, teal) then Mega Bottles (Ronan bottle icon + count, teal) - the Mega
	-- currency that buys MEGA perks at the machines. EXO tier rides as a small
	-- chip under the row. Values arrive via the toplayer clientfields
	-- acc_shards/acc_mb/acc_exo (_zm_aetherium_hud gsc/csc) piped into
	-- same-named UI models. Colors = the map's cyan/teal identity (docs/49).
	-- ========================================================================
	-- Layout (user 2026-07-03): TWO rows; SHARDS use their ICON + count (user "I like the icons
	-- for shards"), the other currencies are text labels. Right column (Exo/MB) aligns at x168:
	--     $money        Exo Suit Lv N
	--     [shard] 67    Mega Bottles N
	-- Row 1 = points (kit elems above) + Exo Suits; Row 2 = [shard icon] count + Mega Bottles.
	-- Values arrive via the toplayer clientfields acc_shards/acc_mb/acc_exo (_zm_aetherium_hud).

	-- Row 1 RIGHT: Exo Suit tier (ALWAYS visible), dim cyan.
	self.acc_exo_chip = LUI.UIText.new()
	self.acc_exo_chip:setLeftRight(true, false, 168, 340)
	self.acc_exo_chip:setTopBottom(true, false, 665, 676)
	self.acc_exo_chip:setTTF( "fonts/ltromatic.ttf" )
	self.acc_exo_chip:setAlignment( Enum.LUIAlignment.LUI_ALIGNMENT_LEFT )
	self.acc_exo_chip:setRGB( 0.55, 0.80, 0.95 )   -- dim cyan
	self.acc_exo_chip:setText( Engine.Localize( "Exo Suit Lv 0" ) )
	self:addElement( self.acc_exo_chip )
	self.acc_exo_chip:subscribeToModel( Engine.CreateModel( Engine.GetModelForController( controller ), "acc_exo" ), function ( model )
		local v = Engine.GetModelValue( model )
		if v ~= nil then
			self.acc_exo_chip:setText( Engine.Localize( "Exo Suit Lv " .. tostring( v ) ) )
		end
	end )

	-- Row 2 LEFT: Data Shard ICON + count (teal number only - the icon labels it).
	self.acc_shard_icon = LUI.UIImage.new()
	self.acc_shard_icon:setLeftRight(true, false, 89, 104)
	self.acc_shard_icon:setTopBottom(true, false, 683, 698)
	self.acc_shard_icon:setImage( RegisterImage( "i_acc_data_shard" ) )
	self.acc_shard_icon:setRGB( 1, 1, 1 )
	self.acc_shard_icon:setAlpha( 1.0 )
	self:addElement( self.acc_shard_icon )

	self.acc_shard_amount = LUI.UIText.new()
	self.acc_shard_amount:setLeftRight(true, false, 107, 168)
	self.acc_shard_amount:setTopBottom(true, false, 686, 697)
	self.acc_shard_amount:setTTF( "fonts/ltromatic.ttf" )
	self.acc_shard_amount:setAlignment( Enum.LUIAlignment.LUI_ALIGNMENT_LEFT )
	self.acc_shard_amount:setRGB( 0.20, 0.95, 0.85 )   -- shard teal
	self.acc_shard_amount:setText( Engine.Localize( "0" ) )
	self:addElement( self.acc_shard_amount )
	self.acc_shard_amount:subscribeToModel( Engine.CreateModel( Engine.GetModelForController( controller ), "acc_shards" ), function ( model )
		local v = Engine.GetModelValue( model )
		if v then
			self.acc_shard_amount:setText( Engine.Localize( tostring( v ) ) )
		end
	end )

	-- Row 2 RIGHT: Mega Bottles (teal), aligned under Exo Suits.
	self.acc_mb_amount = LUI.UIText.new()
	self.acc_mb_amount:setLeftRight(true, false, 168, 340)
	self.acc_mb_amount:setTopBottom(true, false, 686, 697)
	self.acc_mb_amount:setTTF( "fonts/ltromatic.ttf" )
	self.acc_mb_amount:setAlignment( Enum.LUIAlignment.LUI_ALIGNMENT_LEFT )
	self.acc_mb_amount:setRGB( 0.20, 0.95, 0.85 )   -- teal (Mega currency)
	self.acc_mb_amount:setText( Engine.Localize( "Mega Bottles 0" ) )
	self:addElement( self.acc_mb_amount )
	self.acc_mb_amount:subscribeToModel( Engine.CreateModel( Engine.GetModelForController( controller ), "acc_mb" ), function ( model )
		local v = Engine.GetModelValue( model )
		if v then
			self.acc_mb_amount:setText( Engine.Localize( "Mega Bottles " .. tostring( v ) ) )
		end
	end )

	-- Max HP broadcast (user 2026-07-03): the local player's real max health (100 / 250 Jugg /
	-- 300 Mega Jugg) so the HP text scales correctly. Re-renders the number on change.
	self:subscribeToModel( Engine.CreateModel( Engine.GetModelForController( controller ), "acc_maxhp" ), function ( model )
		local v = Engine.GetModelValue( model )
		if v and v > 0 then
			self.acc_maxHP = v
			if self.acc_updateHpText then self.acc_updateHpText() end
		end
	end )

	-- Player Name (elem28) - TEXT (reactive to playerName)
	self.player_name = LUI.UIText.new()
	self.player_name:setLeftRight(true, false, 98, 199)
	self.player_name:setTopBottom(true, false, 636, 647)
	self.player_name:setTTF( "fonts/orbitron.ttf" )
	self.player_name:setAlignment( Enum.LUIAlignment.LUI_ALIGNMENT_LEFT )
	self.player_name:setRGB( 1.000, 1.000, 1.000 )
	self.player_name:linkToElementModel( self, "playerName", true, function ( model )
		local playerName = Engine.GetModelValue( model )
		if playerName then
			self.player_name:setText( Engine.Localize( playerName ) )
		end
	end )
	self.player_name:setAlpha( 1.0 )
	self:addElement( self.player_name )

	-- Shield Health Bar (Blue bar above normal health bar)
	self.shield_health_fill = LUI.UIImage.new()
	self.shield_health_fill:setLeftRight(true, false, 92, 223)
	self.shield_health_fill:setTopBottom(true, false, 641, 648)
	self.shield_health_fill:setImage( RegisterImage( "i_mtl_ui_hud_party_health_bar_fill" ) )
	self.shield_health_fill:setRGB( 0.4, 0.7, 1 )  -- Blue color for shield
	self.shield_health_fill:setMaterial( LUI.UIImage.GetCachedMaterial( "uie_wipe_normal" ) )
	self.shield_health_fill:setShaderVector( 0, 0, 0, 0, 0 )  -- Start at 0 (hidden)
	self.shield_health_fill:setShaderVector( 1, 0, 0, 0, 0 )
	self.shield_health_fill:setShaderVector( 2, 1, 0, 0, 0 )
	self.shield_health_fill:setShaderVector( 3, 0, 0, 0, 0 )
	self.shield_health_fill:setAlpha( 0 )  -- Hidden by default (no shield)
	self:addElement( self.shield_health_fill )

	-- Health Fill (added BEFORE border so border renders on top)
	self.health_fill = LUI.UIImage.new()
	self.health_fill:setLeftRight(true, false, 94, 221)
	self.health_fill:setTopBottom(true, false, 649, 656)
	self.health_fill:setImage( RegisterImage( "i_mtl_ui_hud_player_health_bar_fill" ) )
	self.health_fill:setRGB( 1, 1, 1 )
	self.health_fill:setMaterial( LUI.UIImage.GetCachedMaterial( "uie_wipe_normal" ) )
	self.health_fill:setShaderVector( 0, 1, 0, 0, 0 )
	self.health_fill:setShaderVector( 1, 0, 0, 0, 0 )
	self.health_fill:setShaderVector( 2, 1, 0, 0, 0 )
	self.health_fill:setShaderVector( 3, 0, 0, 0, 0 )
	self:addElement( self.health_fill )

	-- Health Border (added AFTER fill - renders on top)
	self.health_border = LUI.UIImage.new()
	self.health_border:setLeftRight(true, false, 93, 222)
	self.health_border:setTopBottom(true, false, 648, 657)
	self.health_border:setImage( RegisterImage( "i_mtl_ui_hud_player_health_bar_border" ) )
	self.health_border:setRGB( 1, 1, 1 )
	self:addElement( self.health_border )

	-- Downed Indicator (Player 1 - Local Player)
	self.downedIcon = LUI.UIImage.new()
	self.downedIcon:setLeftRight(true, false, 223, 253)
	self.downedIcon:setTopBottom(true, false, 638, 668)
	self.downedIcon:setImage(RegisterImage("i_mtl_icon_ping_downed"))
	self.downedIcon:setRGB(1, 1, 1)
	self.downedIcon:setAlpha(0)  -- Hidden by default
	self:addElement(self.downedIcon)

	-- Player HP (elem29) - TEXT (reactive to player_health_X)
	self.player_hp = LUI.UIText.new()
	self.player_hp:setLeftRight(true, false, 189, 228)
	self.player_hp:setTopBottom(true, false, 631, 639)
	self.player_hp:setText( Engine.Localize( "" ) )
	self.player_hp:setTTF( "fonts/orbitron.ttf" )
	self.player_hp:setRGB( 1.0, 1.0, 1.0 )
	self.player_hp:setAlignment(Enum.LUIAlignment.LUI_ALIGNMENT_CENTER)
	self:addElement( self.player_hp )
	
	-- Player Character Portrait (elem32) - IMAGE (reactive to zombiePlayerIcon)
	self.player_portrait = LUI.UIImage.new()
	self.player_portrait:setLeftRight(true, false, 36, 87)
	self.player_portrait:setTopBottom(true, false, 625, 684)
	self.player_portrait:setImage( RegisterImage( "blacktransparent" ) )
	self.player_portrait:linkToElementModel( self, "zombiePlayerIcon", true, function ( model )
		local zombiePlayerIcon = Engine.GetModelValue( model )
		if zombiePlayerIcon then
			local portraitIcon = CoD.GetCharacterPortrait( zombiePlayerIcon )
			self.player_portrait:setImage( RegisterImage( portraitIcon ) )
		end
	end )
	self:addElement( self.player_portrait )

	-- Shield Icon (shows when shield is equipped)
	self.shield_icon = LUI.UIImage.new()
	self.shield_icon:setLeftRight(true, false, 230, 253)
	self.shield_icon:setTopBottom(true, false, 635, 658)
	self.shield_icon:setImage(RegisterImage("riotshield_zm_icon"))
	self.shield_icon:setRGB(1, 1, 1)
	self.shield_icon:setAlpha(0)  -- Hidden by default
	self:addElement(self.shield_icon)
	
	-- BO6 PATTERN: Dynamic health subscription based on clientNum
	-- This ensures each player viewing the HUD sees THEIR OWN health
	self:linkToElementModel( self, "clientNum", true, function ( clientModel )
		local clientNum = Engine.GetModelValue( clientModel )
		
		if clientNum then
			self.currentClientNum = clientNum
			
			-- Track current state
			self.currentPlayerState = 0  -- 0=alive, 1=downed, 2=dead
			self.currentGobbleGum = nil
			self.currentHealth = nil
			
			-- Subscribe to gobblegum for Coagulant detection
			-- [acc] RE-SUBSCRIPTION GUARD (2026-07-04): mirror the healthSubscription handle+remove
			-- pattern below - this sub previously leaked one handler per clientNum re-fire (kit bug).
			local bgbModel = Engine.GetModel( Engine.GetModelForController( controller ), "bgb_current" )
			if bgbModel then
				if self.bgbSubscription ~= nil then
					self:removeSubscription( self.bgbSubscription )
				end
				self.bgbSubscription = self:subscribeToModel( bgbModel, function( model )
					local bgbIndex = Engine.GetModelValue( model )
					self.currentGobbleGum = bgbIndex  -- Coagulant is index 3
				end )
			end

			local controllerModel = Engine.GetModelForController( controller )
			local healthModel = Engine.GetModel( controllerModel, "player_health_" .. clientNum )
			
			-- Remove old subscription if it exists
			if self.healthSubscription ~= nil then
				self:removeSubscription( self.healthSubscription )
			end
			
			-- ACC (2026-07-03, user: HP text should reflect real max - 300 on Mega Jugg): the
			-- health clientfield is a FRACTION (0..1), so the client can't know real max HP.
			-- self.acc_maxHP is fed by the toplayer acc_maxhp broadcast (_zm_aetherium_hud);
			-- default 100 until the first push. acc_healthFrac is cached so the maxhp
			-- subscription (below) can re-render the number when Jugg changes the max.
			if self.acc_maxHP == nil then self.acc_maxHP = 100 end
			self.acc_updateHpText = function ()
				if self.acc_healthFrac ~= nil then
					self.player_hp:setText( Engine.Localize( math.ceil( self.acc_healthFrac * self.acc_maxHP ) .. " HP" ) )
				end
			end

			-- Subscribe to the correct health model for this player
			self.healthSubscription = self:subscribeToModel( healthModel, function ( model )
				local health = Engine.GetModelValue( model )
				if health then
					-- Always store current health
					self.currentHealth = health
					self.acc_healthFrac = health

					-- Update HP text scaled by REAL max HP (100 / 250 Jug / 300 Mega Jug)
					self.acc_updateHpText()
					
					-- Only update visual if alive
					if self.currentPlayerState == 0 then
						-- Update health bar fill
						self.health_fill:completeAnimation()
						self.health_fill:beginAnimation( "keyframe", 400, false, false, CoD.TweenType.Linear )
						self.health_fill:setShaderVector( 0,
							CoD.GetVectorComponentFromString( health, 1 ),
							CoD.GetVectorComponentFromString( health, 2 ),
							CoD.GetVectorComponentFromString( health, 3 ),
							CoD.GetVectorComponentFromString( health, 4 ) )
					end
				end
			end )
			
			-- Remove old state subscription if it exists
			if self.stateSubscription ~= nil then
				self:removeSubscription( self.stateSubscription )
			end
			
			-- Subscribe to player state model - ACC FIX: the kit hardcoded "player_state_0"
			-- ("local player is always index 0"), but the server packs states by entity number
			-- (monitor_player_states), so index 0 is the HOST - every non-host's own panel
			-- mirrored the host's alive/downed/dead state in co-op. Use the same dynamic
			-- clientNum the health subscription above already uses (the PartyPlayers pattern).
			if controllerModel then
				local stateModel = Engine.GetModel( controllerModel, "player_state_" .. clientNum )
				if stateModel then
					self.stateSubscription = self:subscribeToModel( stateModel, function ( model )
					local newState = Engine.GetModelValue( model )
					if newState ~= nil then
						self.currentPlayerState = newState
						
						-- Handle state changes
						if newState == 0 then
							-- ====================================
							-- ALIVE STATE
							-- ====================================
							self.health_fill:completeAnimation()
							self.downedIcon:setAlpha(0)
							self.player_portrait:setRGB(1, 1, 1)
							self.player_name:setRGB(1, 1, 1)
							self.health_fill:setRGB(1, 1, 1)
							self.health_fill:setAlpha(1)
							self.health_border:setAlpha(1)
							self.points_icon:setAlpha(1)
							self.points_amount:setAlpha(1)
							self.player_hp:setAlpha(1)
							
							-- Set initial health bar value when becoming alive
							if self.currentHealth then
								self.health_fill:setShaderVector( 0,
									CoD.GetVectorComponentFromString( self.currentHealth, 1 ),
									CoD.GetVectorComponentFromString( self.currentHealth, 2 ),
									CoD.GetVectorComponentFromString( self.currentHealth, 3 ),
									CoD.GetVectorComponentFromString( self.currentHealth, 4 ) )
							end
							
						elseif newState == 1 then
							-- ====================================
							-- DOWNED STATE
							-- ====================================
							-- Check if player has Coagulant gobblegum (index 3)
							-- ACC FIX: the kit hardcoded 45000 (its map's tuning). Our bleedout is the
							-- stock player_lastStandBleedoutTime default = 30s (_acc_cyberware.gsc:72);
							-- the sr2b Caching implant doubles it to 60s (ACC_CW_BLEEDOUT_MULT 2.0) -
							-- not visible client-side, so the bar reads correct un-implanted and
							-- conservative (drains early) with the implant. TODO(acc-verify): drive
							-- from a clientfield if implant-accurate drain is ever wanted.
							local bleedoutTime = 30000  -- ACC: stock bleedout (was kit-hardcoded 45000)
							if self.currentGobbleGum == 3 then
								-- DEAD on this map (gobblegums disabled, user 2026-07-03); kept for kit fidelity.
								bleedoutTime = 135000  -- Coagulant: 135 seconds (3x longer)
							end
							
							-- Show downed visuals
							self.health_fill:completeAnimation()
							self.downedIcon:setAlpha(1)
							self.downedIcon:setRGB(1, 0.2, 0.2)
							self.health_fill:setRGB(1, 0.2, 0.2)
							self.health_fill:setAlpha(1)
							self.health_border:setAlpha(1)
							self.health_fill:setShaderVector( 0, 1, 0, 0, 0 )
							self.health_fill:beginAnimation("bleedout_timer", bleedoutTime, false, false, CoD.TweenType.Linear)
							self.health_fill:setShaderVector( 0, 0, 0, 0, 0 )
							self.player_portrait:setRGB(1, 1, 1)
							self.player_name:setRGB(1, 1, 1)
							self.points_icon:setAlpha(1)
							self.points_amount:setAlpha(1)
							self.player_hp:setAlpha(1)
							
						elseif newState == 2 then
							-- ====================================
							-- DEAD STATE
							-- ====================================
							self.health_fill:completeAnimation()
							self.health_fill:setAlpha(0)
							self.health_border:setAlpha(0)
							self.points_icon:setAlpha(0)
							self.points_amount:setAlpha(0)
							self.player_hp:setAlpha(0)
							self.downedIcon:setAlpha(0)
							self.player_portrait:setRGB(0.3, 0.3, 0.3)
							self.player_name:setRGB(1, 0.2, 0.2)
						end
					end
				end )
				end
			end
			
			-- Subscribe to shield health (riot shield)
			if controllerModel then
				-- [acc] WIRED UP properly 2026-07-15 (second pass - user first saw this bar only
			-- INTERMITTENTLY as "a gold bar above health" and then asked to keep shield health
			-- visible): as shipped by the kit it half-worked, because GetModel on
			-- zmInventory.shield_health is the dead-node trap (no node until the server bridge's
			-- first write, so the HUD-build subscription bound dead) - it only came alive when a
			-- clientNum rebind happened to re-fire AFTER the shield existed (first down/revive).
			-- Engine.CreateModel pre-creates the node the bridge later writes (the working
			-- acc_shards/acc_mb/acc_exo/acc_maxhp pattern in this file). The gun-HUD slot in
			-- AetheriumLoadout.lua and the teammate mini-bars in AetheriumPartyPlayers.lua are
			-- the other two shield surfaces.
			local shieldHealthModel = Engine.CreateModel( controllerModel, "zmInventory.shield_health" )
			local shieldDpadModel = Engine.CreateModel( controllerModel, "hudItems.showDpadDown" )
			
			-- Remove old shield subscription if it exists
			if self.shieldSubscription ~= nil then
				self:removeSubscription( self.shieldSubscription )
			end
			
			-- [acc] One refresh reads BOTH cached models and runs on EITHER change: stock's
			-- shield-DESTROY path writes ONLY showDpadDown=0 (shield_health untouched), so a
			-- shield-health-only subscription could show but never hide the bar. Also called
			-- once directly below for the initial paint (mid-run HUD rebuild / rejoin).
			local RefreshShield = function ()
				local shieldHealth = Engine.GetModelValue( shieldHealthModel ) or 0
				if shieldHealth then
					-- Check if shield is actually equipped (showDpadDown > 0 means shield is held)
					local showDpadDown = Engine.GetModelValue( shieldDpadModel )
					
					-- Shield health is 0-1 range (0 = no shield, 1 = full shield)
					-- Only show if shield is equipped AND has health
					if showDpadDown ~= nil and showDpadDown > 0 and shieldHealth > 0 then
					-- Has shield equipped - show shield bar and icon
					self.shield_health_fill:setAlpha( 1 )
					self.shield_icon:setAlpha( 1 )
				
				-- Move player name UP to sit above shield bar (smooth animation)
				self.player_name:beginAnimation( "keyframe", 200, false, false, CoD.TweenType.Linear )
					self.player_name:setTopBottom(true, false, 630, 641)
				self.player_hp:beginAnimation( "keyframe", 200, false, false, CoD.TweenType.Linear )
				self.player_hp:setTopBottom(true, false, 632, 639)				
				-- Move downed icon to RIGHT of shield icon to prevent overlap (smooth animation)
				self.downedIcon:beginAnimation( "keyframe", 200, false, false, CoD.TweenType.Linear )
				self.downedIcon:setLeftRight(true, false, 257, 292)		
				self.downedIcon:setTopBottom(true, false, 628, 663)		
				-- Update shield bar fill immediately (no animation - shows every damage hit)
				self.shield_health_fill:setShaderVector( 0,
						CoD.GetVectorComponentFromString( shieldHealth, 1 ),
						CoD.GetVectorComponentFromString( shieldHealth, 2 ),
						CoD.GetVectorComponentFromString( shieldHealth, 3 ),
						CoD.GetVectorComponentFromString( shieldHealth, 4 ) )
					
					-- Color based on shield health (blue at full, red when low)
					if shieldHealth <= 0.33 then
						self.shield_health_fill:setRGB( 1, 0.4, 0.4 )  -- Red when low
					elseif shieldHealth <= 0.66 then
						self.shield_health_fill:setRGB( 1, 0.8, 0.4 )  -- Orange/Yellow when medium
					else
						self.shield_health_fill:setRGB( 0.4, 0.7, 1 )  -- Blue when high
					end
				else
					-- No shield equipped or no health - hide shield bar and icon
					self.shield_health_fill:setAlpha( 0 )
					self.shield_icon:setAlpha( 0 )
				
				-- Move player name back DOWN to original position
				self.player_name:beginAnimation( "keyframe", 200, false, false, CoD.TweenType.Linear )
				self.player_name:setTopBottom(true, false, 636, 647)
				
				-- Move HP text back DOWN to original position
				self.player_hp:beginAnimation( "keyframe", 200, false, false, CoD.TweenType.Linear )
				self.player_hp:setTopBottom(true, false, 640, 647)
				
				-- Move downed icon back to original position (smooth animation)
				self.downedIcon:beginAnimation( "keyframe", 200, false, false, CoD.TweenType.Linear )
				self.downedIcon:setLeftRight(true, false, 223, 253)
				end
				end
			end

			-- [acc] re-subscription guard for the dpad sub (mirror of the shieldSubscription
			-- guard above - this clientNum link can re-fire on roster change / fastRestart).
			if self.shieldDpadSubscription ~= nil then
				self:removeSubscription( self.shieldDpadSubscription )
			end
			self.shieldSubscription = self:subscribeToModel( shieldHealthModel, RefreshShield )
			self.shieldDpadSubscription = self:subscribeToModel( shieldDpadModel, RefreshShield )
			RefreshShield()   -- initial paint
			end
		end
	end )
	
	-- Points Delta Container (holds dynamically created popups - vanilla BO3 pattern)
	self.pointsDeltaContainer = LUI.UIElement.new()
	self.pointsDeltaContainer:setLeftRight( true, false, 223, 273 )  -- Match reference position
	self.pointsDeltaContainer:setTopBottom( true, false, 664, 671 )
	self.pointsDeltaContainer.lastAnim = 0
	self:addElement( self.pointsDeltaContainer )

	-- Subscribe to score_cf models (vanilla BO3 pattern - damage, death, etc.)
	-- This triggers the points popups
	self:linkToElementModel( self, "clientNum", true, function ( clientModel )
		local clientNum = Engine.GetModelValue( clientModel )

		if clientNum then
			-- [acc] RE-SUBSCRIPTION GUARD (2026-07-04): this link can re-fire (roster change /
			-- fastRestart re-bind), and each fire added the 7 score subscriptions below AGAIN with
			-- no unsubscribe -> N popups per score event after N-1 re-fires (multiplying element
			-- churn). Subscribe once per bound clientNum.
			if self.accScoreSubbedFor == clientNum then
				return
			end
			self.accScoreSubbedFor = clientNum

			local controllerModel = Engine.GetModelForController( controller )
			local clientScoreModel = Engine.GetModel( controllerModel, "PlayerList.client" .. clientNum )

			if clientScoreModel then
				-- Score types from vanilla ZMScr (damage, death_normal, etc.)
				local scoreTypes = {
					damage = 10,
					death_normal = 50,
					death_melee = 130,
					death_torso = 60,
					death_neck = 100,
					death_head = 100,
					reward = 50
				}
				
				-- Subscribe to each score_cf model
				for scoreType, scoreValue in pairs( scoreTypes ) do
					local scoreModel = Engine.CreateModel( clientScoreModel, "score_cf_" .. scoreType )
					if scoreModel then
						self:subscribeToModel( scoreModel, function ( model )
							local modelValue = Engine.GetModelValue( model )
							if modelValue ~= nil and modelValue ~= 0 then
								-- Calculate points (with double points check)
								local points = scoreValue
								local doublePointsModel = Engine.GetModel( controllerModel, "hudItems.doublePointsActive" )
								if doublePointsModel and Engine.GetModelValue( doublePointsModel ) == 1 then
									points = points * 2
								end
								
								-- Create popup (vanilla BO3 pattern)
								if points ~= 0 and points >= -10000 and points <= 10000 then
									local popup = CoD.AetheriumPlusPointsContainer.new( menu, controller )
									
									-- Set text and color
									if points > 0 then
										popup.AetheriumPlusPoints.Label:setText( "+" .. points )
										popup.AetheriumPlusPoints.Label:setRGB( 0.9725, 0.9607, 0.4706 )  -- Yellow
									else
										popup.AetheriumPlusPoints.Label:setText( points )
										popup.AetheriumPlusPoints.Label:setRGB( 1, 0.3, 0.3 )  -- Red
									end
									
									-- Position popup at container location
									popup:setLeftRight( self.pointsDeltaContainer:getLocalLeftRight() )
									popup:setTopBottom( self.pointsDeltaContainer:getLocalTopBottom() )
									
									-- Close on animation complete
									popup:registerEventHandler( "clip_over", function ( element, event )
										element:close()
									end )
									
									-- Add to player widget (not container)
									self:addElement( popup )
									
									-- Play animation
									self.pointsDeltaContainer.lastAnim = self.pointsDeltaContainer.lastAnim + 1
									if self.pointsDeltaContainer.lastAnim > 1 then
										self.pointsDeltaContainer.lastAnim = 1
									end
									popup:playClip( "Anim1" )
									popup.AetheriumPlusPoints:playClip( "FadeOut" )
								end
							end
						end )
					end
				end
			end
		end
	end )

	return self
end
