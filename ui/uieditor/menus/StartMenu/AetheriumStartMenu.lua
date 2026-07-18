-- Aetherium Pause Menu (Custom Design)

require("ui.uieditor.widgets.StartMenu.AetheriumMenuButton")
require("ui.uieditor.widgets.StartMenu.AetheriumSmallButton")
require("ui.uieditor.widgets.HUD.Mappings.AetheriumPerks")   -- CoD.AetheriumPerks (name/desc/megaName/megaDescription/bit) for the pause Perk reference

-- Configuration
local ShowSignatures = false  -- Set to false to hide signature images (ACC: off; kit authors credited in CREDITS.md)

-- ACC Implant Panel data (user 2026-07-12): name + what-it-does blurb per boss-item id.
-- MIRRORS _acc_boss_items.gsc::build_item_pool (item.num -> display_name) - the GSC pushes only
-- the 4-bit ids over the acc_implants clientfield, so the strings live here.
-- KEEP BOTH IN SYNC on any item add/rename/reword.
-- DESC = the PAUSE-MENU blurb, and (user 2026-07-14) it shows the ACTUAL NUMBERS/percentages - the
-- pause menu is where exact magnitudes belong. (The vague/router-safe blurb still used on the in-game
-- PICKUP HINT lives separately in the GSC item.desc; do NOT copy these numeric strings there - the LUI
-- cursor-hint router would choke, memory lui-cursorhint-router-loose-weapon-matcher.)
-- emblem = the 256x256 hex-chip image (pack cyber_city_implant_hud 2026-07-12) drawn over the
-- slot card's hex window here AND on the in-game HUD (acc_hud.lua ACC_IMPLANT_EMBLEMS - keep
-- both keyed to the same item nums as build_item_pool on any add/renumber).
local ACC_IMPLANT_INFO = {
	[1]  = { name = "Gas Tank",             desc = "+100% move speed for 5s (double-tap sprint)", emblem = "i_acc_emblem_gas_tank" },
	[2]  = { name = "Loot Stash",           desc = "+10 points per kill",                 emblem = "i_acc_emblem_loot_stash" },
	[3]  = { name = "Repair Kit",           desc = "+10 HP per second",                   emblem = "i_acc_emblem_repair_kit" },
	[4]  = { name = "Rocket Shield",        desc = "+100% slide speed, 2x jump, riot shield", emblem = "i_acc_emblem_rocket_shield" },
	[5]  = { name = "Phase Serum",          desc = "Nearby glitch bosses -80% speed",     emblem = "i_acc_emblem_phase_serum" },
	[6]  = { name = "Boots",                desc = "+10% move speed",                     emblem = "i_acc_emblem_boots" },
	[7]  = { name = "Lucky Horseshoe",      desc = "+50% drop luck, bonus power-ups",     emblem = "i_acc_emblem_lucky_horseshoe" },
	[8]  = { name = "Turbocharger (Havoc)", desc = "Havoc: instant charge-up",            emblem = "i_acc_emblem_turbocharger" },
	[9]  = { name = "Plasma Generator",     desc = "+10% energy weapon damage",           emblem = "i_acc_emblem_plasma_generator" },
	[10] = { name = "Battery",              desc = "Boss zaps: +20% speed for 5s",        emblem = "i_acc_emblem_battery" },
	[11] = { name = "Berzerker",            desc = "+35% melee speed, -5% HP per hit",    emblem = "i_acc_emblem_berzerker" },
	[12] = { name = "High Caliber Rounds",  desc = "+25% bullet gun damage",              emblem = "i_acc_emblem_high_caliber" },
	[13] = { name = "Warhead Bomber",       desc = "+20% explosive damage",               emblem = "i_acc_emblem_warhead_bomber" },
	[14] = { name = "Hive Node",            desc = "Aura: +15 HP/s, -15% dmg; jump-tap revives/shields", emblem = "i_acc_emblem_hive_node" },
	[15] = { name = "Dark Magic",           desc = "Keep first 4 perks after going down; keep guns after dying", emblem = "i_acc_emblem_dark_magic" },
}

-- Implant-panel card geometry (v4 962x176 bars, 5.47:1). OVERLAP the in-game HUD (user 2026-07-12:
-- "the menu needs to overlap the in game HUD so the pause menu doesnt show the ingame HUD twice"):
-- these MUST match acc_hud.lua's ACC_IMPLANT_* exactly (LEFT 32 / W 230 / H 42 / TOP 220 / stride
-- 48) so the pause cards land right on top of the in-game cards. The pause menu's DarkOverlay dims
-- the in-game HUD and these opaque bars cover the duplicates; the descriptions extend right to x790,
-- clearing the button column (x868+). KEEP IN LOCKSTEP with acc_hud.lua on any size change.
local ACC_IMP_CARD_X = 32
local ACC_IMP_CARD_W = 184   -- -20% (user 2026-07-12); matches acc_hud.lua ACC_IMPLANT_CARD_W
local ACC_IMP_CARD_H = 34    -- matches acc_hud.lua ACC_IMPLANT_CARD_H
local ACC_IMP_CARD_Y = 220
local ACC_IMP_STRIDE = 40   -- card height (34) + 6 gap; matches acc_hud.lua
local ACC_IMP_TEXT_X = 228  -- name/desc line starts right of the card (32+184+12)
local ACC_IMP_EMB_FRAC = 0.92    -- LOCKSTEP with acc_hud.lua ACC_IMPLANT_EMB_FRAC (emblem = 92% of bar height)
local ACC_IMP_EMB_CX   = 0.901   -- LOCKSTEP with acc_hud.lua ACC_IMPLANT_EMB_CX (emblem x-center 90.1%)
-- STATE = PURE IMAGE SWAP (V2 pack, 2026-07-12): lit card when occupied, _dim card when empty -
-- the dim art BAKES IN its 50% alpha (pack README), so NO code setAlpha on top (50%x50% = 25%).
-- Row 4 = the HOLDING card (carried-but-not-benched), same emblem-window geometry.

-- Third Person Toggle Functions
local GetThirdPersonLabel = function(controller)
	local thirdPersonModel = Engine.GetModel(Engine.GetModelForController(controller), "ui_menu_option_third_person")
	local thirdPerson = Engine.GetModelValue(thirdPersonModel)
	
	if thirdPerson == nil then
		Engine.SetModelValue(thirdPersonModel, false)
		thirdPerson = false
	end
	
	return thirdPerson and "Switch To First Person" or "Switch To Third Person"
end

local ToggleThirdPerson = function(self, element, controller, actionParam, menu)
	local thirdPersonModel = Engine.CreateModel(Engine.GetModelForController(controller), "ui_menu_option_third_person")
	local newValue = not Engine.GetModelValue(thirdPersonModel)
	Engine.SetModelValue(thirdPersonModel, newValue)
	Engine.SendMenuResponse(controller, "StartMenu_Main", "ui_menu_option_third_person|" .. (newValue and "1" or "0"))
	
	-- Update button list to show new label
	if menu.ButtonList then
		menu.ButtonList:updateDataSource()
	end
end

-- DataSource for small top buttons
DataSources.AetheriumSmallMenuButtons = ListHelper_SetupDataSource("AetheriumSmallMenuButtons", function(controller)
	local buttons = {}

	-- Graphics Settings
	table.insert(buttons, {
		models = {
			icon = "i_mtl_icon_ftueftus_audio_config_tv",
			action = function(self, element, controller, actionParam, menu)
				if IsPC() then
					OpenPopup(menu, "StartMenu_Options_Graphics_PC", controller, "", "")
				else
					OpenPopup(menu, "StartMenu_Options_Graphics", controller, "", "")
				end
			end
		}
	})

	-- Sound/Audio Settings
	table.insert(buttons, {
		models = {
			icon = "i_mtl_image_2d767ba54c664e54",
			action = function(self, element, controller, actionParam, menu)
				if IsPC() then
					OpenPopup(menu, "StartMenu_Options_Sound_PC", controller, "", "")
				else
					OpenPopup(menu, "StartMenu_Options_Sound", controller, "", "")
				end
			end
		}
	})

	-- Keybinds/Controls Settings
	table.insert(buttons, {
		models = {
			icon = "i_mtl_firing_range_input_settings_kbm",
			action = function(self, element, controller, actionParam, menu)
				if IsPC() then
					OpenPopup(menu, "StartMenu_Options_Controls_PC", controller, "", "")
				else
					OpenPopup(menu, "StartMenu_Options_Controls", controller, "", "")
				end
			end
		}
	})

	-- All Options (Show inline options)
	table.insert(buttons, {
		models = {
			icon = "i_mtl_ui_menu_codhq_icon_settings",
			action = function(self, element, controller, actionParam, menu)
				-- Same action as Game Settings button
				menu.ButtonList:completeAnimation()
				menu.SmallButtonList:completeAnimation()
				menu.OptionsList:completeAnimation()
				menu.OptionsHeaderText:completeAnimation()
				menu.PauseMenuText:completeAnimation()
				
				menu.ButtonList:setAlpha(0)
				menu.SmallButtonList:setAlpha(0)
				menu.PauseMenuText:setAlpha(0)
				menu.OptionsList:setAlpha(1)
				menu.OptionsHeaderText:setAlpha(1)
				menu.OptionsList:processEvent({name = "gain_focus", controller = controller})
			end
		}
	})

	return buttons
end, true)

-- [acc] LEADERBOARD LEAVE FLUSH (user 2026-07-18, docs/40): a deliberate quit or
-- map_restart tears the server VM down WITHOUT firing end_game, so a run ended from this
-- menu was never recorded/POSTed (the "data only sends on death/game end" hole). When GSC
-- armed the hook for THIS machine - the accLbLeaveHook controller model, written by
-- _acc_leaderboard::boot_agents on the HOST only, never on dev/god - ask GSC to record
-- first (set acc_lb_leave_req -> leave_flush_watch records + queues the POST on the
-- detached agent -> acc_lb_leave_ack), THEN run the exit action. Unarmed machines (co-op
-- peers, dev/god, acc_lb_on 0) exit instantly on the exact old path.
local AccLbFlushThen = function(menu, controller, exitFn)
	local hook = nil
	pcall(function()
		hook = Engine.GetModelValue(Engine.GetModel(Engine.GetModelForController(controller), "accLbLeaveHook"))
	end)
	if hook ~= "1" and hook ~= 1 then
		exitFn()
		return
	end

	-- Unpause FIRST: the solo pause freezes server GSC, so the watcher could never answer
	-- (the menu still covers the screen; ~1s of live game behind it is the accepted cost -
	-- we are leaving anyway).
	Engine.SetDvar("cl_paused", 0)
	pcall(function() Engine.Exec(controller, 'set acc_lb_leave_ack ""') end)
	pcall(function() Engine.Exec(controller, 'set acc_lb_leave_req "1"') end)

	-- Robust dvar read - same pcall-guarded multi-form idiom as AccReadDetailDvar below /
	-- acc_lb_board.lua's readdvar (the exact T7 LUI signature is unproven; first hit wins).
	local ackRead = function()
		local forms = {
			function() return Engine.DvarString(controller, "acc_lb_leave_ack") end,
			function() return Engine.DvarString("acc_lb_leave_ack") end,
			function() return Engine.GetDvarString("acc_lb_leave_ack") end,
		}
		for i = 1, #forms do
			local ok, v = pcall(forms[i])
			if ok and v ~= nil and tostring(v) ~= "" then return tostring(v) end
		end
		return ""
	end

	-- If the menu closes any other way mid-flush (ESC = cancel the leave), the timer must
	-- die with it (memory lui-uitimer-leaks-state-pool). Hook close ONCE per menu instance.
	if not menu.accLbCloseHooked then
		menu.accLbCloseHooked = true
		LUI.OverrideFunction_CallOriginalSecond(menu, "close", function(element)
			if element.accLbLeaveTimer then
				element.accLbLeaveTimer:close()
				element.accLbLeaveTimer = nil
			end
		end)
	end

	local waitedMs = 0
	if menu.accLbLeaveTimer then menu.accLbLeaveTimer:close() end   -- close-before-create
	menu.accLbLeaveTimer = LUI.UITimer.new(100, "acc_lb_leave_tick", false)
	menu:addElement(menu.accLbLeaveTimer)
	menu:registerEventHandler("acc_lb_leave_tick", function(element, event)
		waitedMs = waitedMs + 100
		-- 6s hard cap: a wedged bridge must never strand the player in-game on a Leave press.
		-- Typical ack is <1s (0.1s poll + publish + one client frame + 0.5s margin); the cap
		-- covers the record-lane lease too (a just-fired per-round record adds up to ~3s).
		if ackRead() == "1" or waitedMs >= 6000 then
			if menu.accLbLeaveTimer then
				menu.accLbLeaveTimer:close()
				menu.accLbLeaveTimer = nil
			end
			exitFn()
		end
	end)
end

-- DataSource for menu buttons
DataSources.AetheriumStartMenuButtons = ListHelper_SetupDataSource("AetheriumStartMenuButtons", function(controller)
	local buttons = {}

	table.insert(buttons, {
		models = {
			displayText = "Return To Game",
			action = function(self, element, controller, actionParam, menu)
				RefreshLobbyRoom(menu, controller)
				StartMenuGoBack(menu, controller)
			end
		}
	})

	table.insert(buttons, {
		models = {
			displayText = "Restart Level",
			action = function(self, element, controller, actionParam, menu)
				-- [acc] map_restart has the same no-end_game hole as Leave Game - flush the
				-- leaderboard record first when the hook is armed (host, real run)
				AccLbFlushThen(menu, controller, function()
					-- Close menu first
					GoBack(menu, controller)
					-- Restart the map
					Engine.Exec(controller, "map_restart")
				end)
			end
		}
	})

	table.insert(buttons, {
		models = {
			displayText = GetThirdPersonLabel(controller),
			action = ToggleThirdPerson
		}
	})

	table.insert(buttons, {
		models = {
			displayText = "Game Settings",
			action = function(self, element, controller, actionParam, menu)
				-- Instantly switch to options
				menu.ButtonList:completeAnimation()
				menu.SmallButtonList:completeAnimation()
				menu.OptionsList:completeAnimation()
				menu.OptionsHeaderText:completeAnimation()
				menu.PauseMenuText:completeAnimation()
				
				menu.ButtonList:setAlpha(0)
				menu.SmallButtonList:setAlpha(0)
				menu.PauseMenuText:setAlpha(0)
				menu.OptionsList:setAlpha(1)
				menu.OptionsHeaderText:setAlpha(1)
				menu.OptionsList:processEvent({name = "gain_focus", controller = controller})
			end
		}
	})

	-- HUD Settings and Social buttons removed

	table.insert(buttons, {
		models = {
			displayText = "Leave Game",
			action = function(self, element, controller, actionParam, menu)
				-- [acc] flush the leaderboard record first when the hook is armed (host,
				-- real run) - a quit never fires end_game, so this is the ONLY chance to
				-- store the run (user 2026-07-18). Unarmed = instant leave, the old path.
				AccLbFlushThen(menu, controller, function()
					-- Close all menus first
					menu:processEvent({
						name = "close_all_ingame_menus",
						controller = controller
					})

					-- Send menu response for proper cleanup
					Engine.SendMenuResponse(controller, "popup_leavegame", "endround")

					-- Solo and multiplayer both disconnect (the old solo/MP branch was identical)
					Engine.SetDvar("cl_paused", 0)
					Engine.Exec(controller, "disconnect")
				end)
			end
		}
	})

	return buttons
end, true)

-- DataSource for options buttons (shown when Game Settings is clicked)
DataSources.AetheriumOptionsButtons = ListHelper_SetupDataSource("AetheriumOptionsButtons", function(controller)
	local options = {}
	
	table.insert(options, {
		models = {
			displayText = "Graphics",
			action = function(self, element, controller, actionParam, menu)
				if IsPC() then
					OpenPopup(menu, "StartMenu_Options_Graphics_PC", controller, "", "")
				else
					OpenPopup(menu, "StartMenu_Options_Graphics", controller, "", "")
				end
			end
		}
	})
	
	table.insert(options, {
		models = {
			displayText = "Audio",
			action = function(self, element, controller, actionParam, menu)
				if IsPC() then
					OpenPopup(menu, "StartMenu_Options_Sound_PC", controller, "", "")
				else
					OpenPopup(menu, "StartMenu_Options_Sound", controller, "", "")
				end
			end
		}
	})
	
	table.insert(options, {
		models = {
			displayText = "Controls",
			action = function(self, element, controller, actionParam, menu)
				if IsPC() then
					OpenPopup(menu, "StartMenu_Options_Controls_PC", controller, "", "")
				else
					OpenPopup(menu, "StartMenu_Options_Controls", controller, "", "")
				end
			end
		}
	})
	
	table.insert(options, {
		models = {
			displayText = "Voice & Muting",
			action = function(self, element, controller, actionParam, menu)
				if IsPC() then
					OpenPopup(menu, "StartMenu_Options_Voice_PC", controller, "", "")
				else
					OpenPopup(menu, "StartMenu_Options_Voice", controller, "", "")
				end
			end
		}
	})
	
	table.insert(options, {
		models = {
			displayText = "Network",
			action = function(self, element, controller, actionParam, menu)
				OpenPopup(menu, "StartMenu_Options_Network", controller, "", "")
			end
		}
	})
	
	table.insert(options, {
		models = {
			displayText = "Safe Area",
			action = function(self, element, controller, actionParam, menu)
				OpenPopup(menu, "StartMenu_Options_Graphics_SafeArea", controller, "", "")
			end
		}
	})
	
	table.insert(options, {
		models = {
			displayText = "Content Filter",
			action = function(self, element, controller, actionParam, menu)
				if IsPC() then
					OpenPopup(menu, "StartMenu_Options_GraphicContent_PC", controller, "", "")
				else
					OpenPopup(menu, "StartMenu_Options_GraphicContent", controller, "", "")
				end
			end
		}
	})
	
	table.insert(options, {
		models = {
			displayText = "Credits",
			action = function(self, element, controller, actionParam, menu)
				OpenPopup(menu, "Credit_Fullscreen", controller, "", "")
			end
		}
	})
	
	table.insert(options, {
		models = {
			displayText = "Back",
			action = function(self, element, controller, actionParam, menu)
				-- Instantly hide options and show main menu
				menu.OptionsList:completeAnimation()
				menu.OptionsHeaderText:completeAnimation()
				menu.ButtonList:completeAnimation()
				menu.SmallButtonList:completeAnimation()
				menu.PauseMenuText:completeAnimation()
				
				menu.OptionsList:setAlpha(0)
				menu.OptionsHeaderText:setAlpha(0)
				menu.ButtonList:setAlpha(1)
				menu.SmallButtonList:setAlpha(1)
				menu.PauseMenuText:setAlpha(1)
				menu.ButtonList:processEvent({name = "gain_focus", controller = controller})
			end
		}
	})
	
	return options
end, true)

local PostLoadFunc = function(self, controller)
	self:registerEventHandler("menu_opened", function(element, event)
		Engine.SetUIActive(controller, true)
		
		-- Hide HUD when pause menu opens
		local controllerModel = Engine.GetModelForController(controller)
		local hudVisibilityModel = Engine.GetModel(controllerModel, "UIVisibility.Visibility")
		if hudVisibilityModel then
			Engine.SetModelValue(hudVisibilityModel, 0)
		end
		
		return true
	end)
	
	self:registerEventHandler("menu_closed", function(element, event)
		Engine.SetUIActive(controller, false)
		
		-- Show HUD when pause menu closes
		local controllerModel = Engine.GetModelForController(controller)
		local hudVisibilityModel = Engine.GetModel(controllerModel, "UIVisibility.Visibility")
		if hudVisibilityModel then
			Engine.SetModelValue(hudVisibilityModel, 1)
		end
		
		return true
	end)
	
	if CoD.isZombie then
		self.disableDarkenElement = true
		self.disablePopupOpenCloseAnim = false
	end
end

LUI.createMenu.StartMenu_Main = function(controller)
	local self = CoD.Menu.NewForUIEditor("StartMenu_Main")

	self.soundSet = "default"
	self:setOwner(controller)
	self:setLeftRight(true, true, 0, 0)
	self:setTopBottom(true, true, 0, 0)
	self:playSound("menu_open", controller)
	self.buttonModel = Engine.CreateModel(Engine.GetModelForController(controller), "StartMenu_Main.buttonPrompts")
	self.anyChildUsesUpdateState = true

	-- Dark Blur Overlay
	self.DarkOverlay = LUI.UIImage.new()
	self.DarkOverlay:setLeftRight(true, true, 0, 0)
	self.DarkOverlay:setTopBottom(true, true, 0, 0)
	self.DarkOverlay:setImage(RegisterImage("$white"))
	self.DarkOverlay:setRGB(0.05, 0.05, 0.05)
	self.DarkOverlay:setAlpha(0.8)
	self:addElement(self.DarkOverlay)

	-- pause_menu_bg
	self.BGMain = LUI.UIImage.new()
	self.BGMain:setLeftRight(true, false, 0, 1280)
	self.BGMain:setTopBottom(true, false, 0, 720)
	self.BGMain:setImage(RegisterImage("i_mtl_image_2c20915dba690ea5"))
	self:addElement(self.BGMain)

	-- sat_pause_menu_bg
	self.BGRight = LUI.UIImage.new()
	self.BGRight:setLeftRight(true, false, 823, 1252)
	self.BGRight:setTopBottom(true, false, 0, 720)
	self.BGRight:setImage(RegisterImage("i_mtl_sat_pause_menu_bg"))
	self:addElement(self.BGRight)

	-- bg_blood
	self.BGBlood = LUI.UIImage.new()
	self.BGBlood:setLeftRight(true, false, 814, 1338)
	self.BGBlood:setTopBottom(true, false, 390, 711)
	self.BGBlood:setImage(RegisterImage("i_mtl_image_273102a380412bec"))
	self:addElement(self.BGBlood)

	-- Game mode icon
	self.GameModeIcon = LUI.UIImage.new()
	self.GameModeIcon:setLeftRight(true, false, 5, 97)
	self.GameModeIcon:setTopBottom(true, false, 10, 102)
	self.GameModeIcon:setImage(RegisterImage("i_mtl_sat_ui_icon_gamemode_zm_standard"))
	self:addElement(self.GameModeIcon)

	-- Logo
	self.Logo = LUI.UIImage.new()
    self.Logo:setLeftRight(true, false, 79, 377)
    self.Logo:setTopBottom(true, false, 55, 102)
	self.Logo:setImage(RegisterImage("i_mtl_image_2fe6956607db6e68"))
	self:addElement(self.Logo)

	-- Map Name (box must be wide enough for the full name on ONE line — a
	-- narrow box makes UIText wrap onto the GameModeText row below)
	self.MapName = LUI.UIText.new()
    self.MapName:setLeftRight(true, false, 102, 340)
    self.MapName:setTopBottom(true, false, 37, 50)
	self.MapName:setText(Engine.Localize(CoD.UsermapName or "UNKNOWN MAP"))
	self.MapName:setTTF("fonts/orbitron.ttf")
	self.MapName:setAlignment(Enum.LUIAlignment.LUI_ALIGNMENT_LEFT)
	self:addElement(self.MapName)

	-- Round Label
	self.RoundLabel = LUI.UIText.new()
    self.RoundLabel:setLeftRight(true, false, 360, 424)
    self.RoundLabel:setTopBottom(true, false, 37, 50)
	self.RoundLabel:setText(Engine.Localize("ROUND"))
	self.RoundLabel:setTTF("fonts/orbitron.ttf")
	self:addElement(self.RoundLabel)

	-- Round Number
	self.RoundNumber = LUI.UIText.new()
    self.RoundNumber:setLeftRight(true, false, 436, 473)
    self.RoundNumber:setTopBottom(true, false, 37, 50)
	self.RoundNumber:setTTF("fonts/orbitron.ttf")
	self.RoundNumber:subscribeToModel(Engine.GetModel(Engine.GetModelForController(controller), "gameScore.roundsPlayed"), function(model)
		local roundsPlayed = Engine.GetModelValue(model)
		if roundsPlayed then
			self.RoundNumber:setText(Engine.Localize(tostring(roundsPlayed - 1)))
		end
	end)
	self:addElement(self.RoundNumber)

	-- Game Mode Text
	self.GameModeText = LUI.UIText.new()
    self.GameModeText:setLeftRight(true, false, 102, 357)
    self.GameModeText:setTopBottom(true, false, 57, 74)
	self.GameModeText:setText(Engine.Localize("Round Based Zombies"))
	self.GameModeText:setTTF("fonts/orbitron.ttf")
	self:addElement(self.GameModeText)

	-- =========================================================================
	-- ACC Implant Panel (user 2026-07-12): "pause your game and it explains the
	-- implants you have equipped and holding". The in-game IMPLANT hud lines are
	-- name-only now - the descriptions live HERE. Data = the "acc_implants"
	-- toplayer clientfield -> UI model bridge (_zm_aetherium_hud.csc; pushed by
	-- _acc_boss_items.gsc::push_implants_clientfield): four 4-bit item.num
	-- nibbles - Slot 1 / Slot 2 / Slot 3 / carried, 0 = empty. Toplayer models
	-- need Engine.CreateModel, NOT GetModel (memory gun-badge-row-system).
	-- =========================================================================
	self.ImplantsHeader = LUI.UIText.new()
	self.ImplantsHeader:setLeftRight(true, false, 32, 320)
	self.ImplantsHeader:setTopBottom(true, false, 196, 214)
	self.ImplantsHeader:setText(Engine.Localize("IMPLANTS"))
	self.ImplantsHeader:setTTF("fonts/orbitron.ttf")
	self.ImplantsHeader:setRGB(0.80, 0.65, 1.0)
	self.ImplantsHeader:setAlignment(Enum.LUIAlignment.LUI_ALIGNMENT_LEFT)
	self:addElement(self.ImplantsHeader)

	-- PNG SLOT CARDS (2026-07-12 rework, user: "just placing pngs on top of the implant pngs"):
	-- one slot-card image per slot (baked "IMPLANT N" label + EMPTY hex window) + one emblem
	-- overlay shown when that slot is filled; the name+desc TEXT stays beside each card (user:
	-- "the description stays cause thats the most important in the menu"). Same art + ratios as
	-- the in-game CoD.AccImplantRow (acc_hud.lua).
	local embS = ACC_IMP_CARD_H * ACC_IMP_EMB_FRAC
	local embL = ACC_IMP_CARD_X + ACC_IMP_CARD_W * ACC_IMP_EMB_CX - embS / 2
	local embT = (ACC_IMP_CARD_H - embS) / 2
	local cardImgs = {}
	for i = 1, 3 do
		cardImgs[i] = {
			lit = RegisterImage("i_acc_implant_slot" .. i),
			dim = RegisterImage("i_acc_implant_slot" .. i .. "_dim"),
		}
	end
	local holdImgs = {
		lit = RegisterImage("i_acc_implant_holding"),
		dim = RegisterImage("i_acc_implant_holding_dim"),
	}

	self.ImplantCards = {}
	self.ImplantEmblems = {}
	for i = 1, 4 do   -- rows 1-3 = slots, row 4 = the HOLDING card
		local cardTop = ACC_IMP_CARD_Y + (i - 1) * ACC_IMP_STRIDE
		local card = LUI.UIImage.new()
		card:setLeftRight(true, false, ACC_IMP_CARD_X, ACC_IMP_CARD_X + ACC_IMP_CARD_W)
		card:setTopBottom(true, false, cardTop, cardTop + ACC_IMP_CARD_H)
		card:setImage(( i <= 3 ) and cardImgs[i].dim or holdImgs.dim)
		self:addElement(card)
		self.ImplantCards[i] = card

		local emb = LUI.UIImage.new()
		emb:setLeftRight(true, false, embL, embL + embS)
		emb:setTopBottom(true, false, cardTop + embT, cardTop + embT + embS)
		emb:hide()
		self:addElement(emb)
		self.ImplantEmblems[i] = emb
	end

	-- One name+desc text line beside every card (vertically centered): rows 1-3 = the implant,
	-- row 4 = the amber carried-item line beside the HOLDING card.
	self.ImplantLines = {}
	for i = 1, 4 do
		local cardTop = ACC_IMP_CARD_Y + (i - 1) * ACC_IMP_STRIDE
		local line = LUI.UIText.new()
		line:setLeftRight(true, false, ACC_IMP_TEXT_X, 790)
		line:setTopBottom(true, false, cardTop + 8, cardTop + 26)   -- vertically centered in the 34px card
		line:setTTF("fonts/orbitron.ttf")
		line:setRGB(1, 1, 1)
		line:setAlignment(Enum.LUIAlignment.LUI_ALIGNMENT_LEFT)
		line:setText("")
		self:addElement(line)
		self.ImplantLines[i] = line
	end

	-- Emblem materials registered ONCE; the refresh only swaps pre-registered handles.
	local emblemHandles = {}
	for num, info in pairs(ACC_IMPLANT_INFO) do
		emblemHandles[num] = RegisterImage(info.emblem)
	end

	-- Decode the packed nibbles and repaint cards + lines. No bit ops in HKS Lua
	-- 5.1 - nibble extraction is floor-division (values are exact: 16 bits is
	-- far inside the 32-bit float mantissa, memory retail-lui-io-os note).
	local AccRefreshImplantPanel = function(value)
		local v = tonumber(value) or 0
		for i = 1, 3 do
			local num = math.floor(v / (16 ^ (i - 1))) % 16
			local info = ACC_IMPLANT_INFO[num]
			local line = self.ImplantLines[i]
			local emb = self.ImplantEmblems[i]
			local card = self.ImplantCards[i]
			if info then
				-- No "IMPLANT N" prefix - the card art carries the slot label now.
				line:setText(info.name .. ":  " .. info.desc)
				line:setRGB(1, 1, 1)
				emb:setImage(emblemHandles[num])
				emb:show()
				card:setImage(cardImgs[i].lit)
			else
				line:setText("")   -- empty slot: the card's baked EMPTY window says it
				emb:hide()
				card:setImage(cardImgs[i].dim)
			end
		end
		local carryNum = math.floor(v / 4096) % 16
		local carryInfo = ACC_IMPLANT_INFO[carryNum]
		if carryInfo then
			self.ImplantCards[4]:setImage(holdImgs.lit)
			self.ImplantEmblems[4]:setImage(emblemHandles[carryNum])
			self.ImplantEmblems[4]:show()
			self.ImplantLines[4]:setText(carryInfo.name .. ":  " .. carryInfo.desc .. "  (enable at the Plaza bench)")
			self.ImplantLines[4]:setRGB(1.0, 0.82, 0.25)
		else
			self.ImplantCards[4]:setImage(holdImgs.dim)
			self.ImplantEmblems[4]:hide()
			self.ImplantLines[4]:setText("")
		end
	end

	local implantsModel = Engine.CreateModel(Engine.GetModelForController(controller), "acc_implants")
	self.ImplantsHeader:subscribeToModel(implantsModel, function(model)
		AccRefreshImplantPanel(Engine.GetModelValue(model))
	end)
	AccRefreshImplantPanel(Engine.GetModelValue(implantsModel))

	-- =========================================================================
	-- ACC OBJECTIVE tracker (user 2026-07-12; milestone ladder 2026-07-15, re-landed
	-- within the toplayer budget after the pool-overflow load break). THREE transports,
	-- none of which grow the FULL toplayer pool:
	--   phase 0..12  = the 4-bit acc_objective TOPLAYER clientfield (correct for every
	--                  co-op client; 3-6 are the per-trench-gate descent states),
	--   soft numbers = the acc_obj_detail DVAR (a + b*128, +1 so 0 = no data; SERVER
	--                  dvar -> host-accurate, blank on remote clients by design),
	--   boss warning + perk count = fully client-side (gameScore.roundsPlayed model +
	--                  the accOwnedMask bit count).
	-- toplayer models need Engine.CreateModel.
	-- =========================================================================
	local ACC_OBJECTIVE_INFO = {
		[1] = "Turn on the Power at the Bus Station",
		[2] = "Buy perks & open doors - prepare for the Round 9 BOSS",
		[3] = "Bank souls below to open the door to Trench Level 2",
		[4] = "Bank souls below to open the door to Trench Level 3",
		[5] = "Bank souls below to open the door to Trench Level 4",
		[6] = "Bank souls below to open the door to Trench Level 5",
		[7] = "Slay zombies on the bottom floor to unseal the Paradise gate",
		[8] = "The gate is unsealed - pay Data Shards & Points at the Paradise gate",
		[9] = "Gather every survivor at the Paradise gate",
		[10] = "The Paradise gate is open - descend and step through",
		[11] = "Survive the Paradise onslaught!",
		[12] = "Paradise complete - push for a high round!",
	}
	-- Robust dvar read (the acc_obj_detail channel) - same pcall-guarded multi-form idiom as
	-- acc_lb_board.lua's readdvar (the exact T7 LUI signature is unproven; first hit wins).
	local AccReadDetailDvar = function()
		local c = nil
		pcall(function() c = Engine.GetLocalClientNum() end)
		local forms = {
			function() return Engine.DvarInt(c, "acc_obj_detail") end,
			function() return Engine.DvarInt("acc_obj_detail") end,
			function() return Engine.DvarString(c, "acc_obj_detail") end,
			function() return Engine.DvarString("acc_obj_detail") end,
			function() return Engine.GetDvarString("acc_obj_detail") end,
		}
		for i = 1, #forms do
			local ok, v = pcall(forms[i])
			if ok and v ~= nil then
				local n = tonumber(v)
				if n and n > 0 then return n end
			end
		end
		return 0
	end
	-- Count owned perks client-side off the accOwnedMask clientuimodel (10 perk bits;
	-- the perks panel below reads the same model). No bit ops in HKS Lua 5.1.
	local AccOwnedPerkCount = function()
		local mask = tonumber(Engine.GetModelValue(Engine.GetModel(Engine.GetModelForController(controller), "accOwnedMask"))) or 0
		local n = 0
		for i = 1, 10 do
			if mask % 2 >= 1 then n = n + 1 end
			mask = math.floor(mask / 2)
		end
		return n
	end
	-- Phase-specific progress line under the objective. The dvar packs a + b*128 (+1 offset,
	-- mirrored in _acc_lui.gsc::acc_compute_objective_detail); v == 0 means no data (remote
	-- co-op client, or pre-first-push) - render only the client-side parts then.
	local AccObjectiveDetailText = function(idx)
		local v = AccReadDetailDvar()
		local has = (v > 0)
		local w = has and (v - 1) or 0
		local a = math.floor(w % 128)
		local b = math.floor(w / 128)
		if idx == 2 then
			local perks = "Your perks: " .. AccOwnedPerkCount() .. "/10"
			if has then return "Zones opened: " .. a .. "/7    " .. perks end
			return perks
		elseif idx >= 3 and idx <= 6 and has then
			return "Souls banked toward the gate: " .. a .. "%"
		elseif idx == 7 and has then
			return "Paradise gate souls: " .. a .. "%"
		elseif idx == 8 and has then
			return "Still needed: " .. a .. " Shards + " .. ((b > 0) and (b .. ",000") or "0") .. " Points"
		elseif idx == 9 and has then
			return "Survivors at the gate: " .. a .. " / " .. b
		end
		return ""
	end
	-- BOSS-round warning, fully client-side: the roster spawns bosses on rounds 9/18/27...
	-- (_acc_civil_protector::boss_count, first 9 / interval 9 - defaults hardcoded here; the
	-- acc_boss_first_round/acc_boss_interval dvars are live-balance cadence overrides only -
	-- this warning does not track them).
	-- gameScore.roundsPlayed = round + 1 (memory retail-lui-io-os; the RoundNumber element
	-- above decodes it the same way). Suppressed once Paradise opens (phase >= 10 - the
	-- onslaught freezes the round).
	local ACC_BOSS_WARN_TEXT = {
		[1] = "BOSS ROUND NEXT - gear up NOW",
		[2] = "BOSS ROUND - it is hunting you",
	}
	local AccBossWarnState = function(phase, roundsPlayed)
		if phase < 1 or phase > 9 then return 0 end
		local round = (tonumber(roundsPlayed) or 1) - 1
		if round >= 9 and round % 9 == 0 then return 2 end
		if (round + 1) >= 9 and (round + 1) % 9 == 0 then return 1 end
		return 0
	end
	self.ObjectiveHeader = LUI.UIText.new()
	self.ObjectiveHeader:setLeftRight(true, false, 32, 320)
	self.ObjectiveHeader:setTopBottom(true, false, 392, 408)
	self.ObjectiveHeader:setText(Engine.Localize("OBJECTIVE"))
	self.ObjectiveHeader:setTTF("fonts/orbitron.ttf")
	self.ObjectiveHeader:setRGB(0.35, 0.95, 0.85)
	self.ObjectiveHeader:setAlignment(Enum.LUIAlignment.LUI_ALIGNMENT_LEFT)
	self:addElement(self.ObjectiveHeader)

	self.ObjectiveLine = LUI.UIText.new()
	self.ObjectiveLine:setLeftRight(true, false, 32, 790)
	self.ObjectiveLine:setTopBottom(true, false, 412, 430)
	self.ObjectiveLine:setTTF("fonts/orbitron.ttf")
	self.ObjectiveLine:setRGB(1, 1, 1)
	self.ObjectiveLine:setAlignment(Enum.LUIAlignment.LUI_ALIGNMENT_LEFT)
	self.ObjectiveLine:setText("")
	self:addElement(self.ObjectiveLine)

	-- The dynamic progress line (dimmer, so the imperative line above stays the eye-catcher).
	self.ObjectiveDetail = LUI.UIText.new()
	self.ObjectiveDetail:setLeftRight(true, false, 32, 790)
	self.ObjectiveDetail:setTopBottom(true, false, 434, 450)
	self.ObjectiveDetail:setTTF("fonts/orbitron.ttf")
	self.ObjectiveDetail:setRGB(0.60, 0.80, 0.85)
	self.ObjectiveDetail:setAlignment(Enum.LUIAlignment.LUI_ALIGNMENT_LEFT)
	self.ObjectiveDetail:setText("")
	self:addElement(self.ObjectiveDetail)

	-- BOSS-round warning (user 2026-07-15: "everyone keeps dying on round 9"): a red line that
	-- fires the round BEFORE every roster boss round and during it, on any pre-Paradise phase.
	-- Fully client-side (AccBossWarnState off the roundsPlayed model) - works for every player.
	self.ObjectiveBossWarn = LUI.UIText.new()
	self.ObjectiveBossWarn:setLeftRight(true, false, 32, 790)
	self.ObjectiveBossWarn:setTopBottom(true, false, 454, 470)
	self.ObjectiveBossWarn:setTTF("fonts/orbitron.ttf")
	self.ObjectiveBossWarn:setRGB(0.95, 0.30, 0.25)
	self.ObjectiveBossWarn:setAlignment(Enum.LUIAlignment.LUI_ALIGNMENT_LEFT)
	self.ObjectiveBossWarn:setText("")
	self:addElement(self.ObjectiveBossWarn)

	-- Repaint on the phase model AND on roundsPlayed (round flips re-fire the boss warning and
	-- re-read the detail dvar, so the soft numbers refresh at least once per round while paused).
	local objPhase, objRoundsPlayed = 0, 1
	local AccRefreshObjective = function()
		self.ObjectiveLine:setText(Engine.Localize(ACC_OBJECTIVE_INFO[objPhase] or ""))
		self.ObjectiveDetail:setText(AccObjectiveDetailText(objPhase))
		self.ObjectiveBossWarn:setText(ACC_BOSS_WARN_TEXT[AccBossWarnState(objPhase, objRoundsPlayed)] or "")
	end
	local objectiveModel = Engine.CreateModel(Engine.GetModelForController(controller), "acc_objective")
	self.ObjectiveHeader:subscribeToModel(objectiveModel, function(model)
		objPhase = tonumber(Engine.GetModelValue(model)) or 0
		AccRefreshObjective()
	end)
	self.ObjectiveHeader:subscribeToModel(Engine.GetModel(Engine.GetModelForController(controller), "gameScore.roundsPlayed"), function(model)
		objRoundsPlayed = tonumber(Engine.GetModelValue(model)) or 1
		AccRefreshObjective()
	end)
	objPhase = tonumber(Engine.GetModelValue(objectiveModel)) or 0
	AccRefreshObjective()

	-- =========================================================================
	-- ACC PERK reference (user 2026-07-12): lists the perks you OWN and what each
	-- does (base, or the Mega upgrade if Mega'd) - the in-game HUD only shows icons.
	-- Reuses CoD.AetheriumPerks (name/desc/megaName/megaDescription/bit) + the
	-- accOwnedMask/accMegaMask clientuimodels (pushed by _acc_lui perk_state_watch,
	-- already driving the perk row). NO new data wire. accOwnedMask/accMegaMask are
	-- clientuimodel scope (auto-created) so Engine.GetModel works (unlike toplayer).
	-- =========================================================================
	self.PerksHeader = LUI.UIText.new()
	self.PerksHeader:setLeftRight(true, false, 32, 320)
	-- +24px gap below the Objective section (user 2026-07-13: Objective/Perks were only 6px apart).
	-- Shifted 460 -> 494 (2026-07-15) to keep that gap after the ObjectiveDetail + boss-warn lines
	-- (boss line ends 470).
	self.PerksHeader:setTopBottom(true, false, 494, 510)
	self.PerksHeader:setText(Engine.Localize("PERKS"))
	self.PerksHeader:setTTF("fonts/orbitron.ttf")
	self.PerksHeader:setRGB(0.80, 0.65, 1.0)
	self.PerksHeader:setAlignment(Enum.LUIAlignment.LUI_ALIGNMENT_LEFT)
	self:addElement(self.PerksHeader)

	self.PerkLines = {}
	for i = 1, 10 do
		local line = LUI.UIText.new()
		line:setLeftRight(true, false, 32, 790)
		line:setTopBottom(true, false, 514 + (i - 1) * 18, 530 + (i - 1) * 18)
		line:setTTF("fonts/orbitron.ttf")
		line:setRGB(1, 1, 1)
		line:setAlignment(Enum.LUIAlignment.LUI_ALIGNMENT_LEFT)
		line:setText("")
		self:addElement(line)
		self.PerkLines[i] = line
	end

	local ACC_PerkBitSet = function(mask, b)
		return math.floor(mask / (2 ^ b)) % 2 >= 1
	end
	local AccRefreshPerks = function()
		local cm = Engine.GetModelForController(controller)
		local owned = tonumber(Engine.GetModelValue(Engine.GetModel(cm, "accOwnedMask"))) or 0
		local mega = tonumber(Engine.GetModelValue(Engine.GetModel(cm, "accMegaMask"))) or 0
		local row = 0
		if CoD.AetheriumPerks then
			for _, perk in ipairs(CoD.AetheriumPerks) do
				if perk.bit ~= nil and row < 10 and ACC_PerkBitSet(owned, perk.bit) then
					row = row + 1
					local line = self.PerkLines[row]
					if perk.megaName and ACC_PerkBitSet(mega, perk.bit) then
						line:setText(Engine.Localize(perk.megaName .. ":  " .. (perk.megaDescription or "")))
						line:setRGB(0.35, 0.95, 0.85)   -- teal = Mega'd
					else
						line:setText(Engine.Localize(perk.name .. ":  " .. (perk.description or "")))
						line:setRGB(1, 1, 1)
					end
				end
			end
		end
		if row == 0 then
			self.PerkLines[1]:setText(Engine.Localize("No perks yet - buy them from the machines"))
			self.PerkLines[1]:setRGB(0.45, 0.45, 0.52)
			row = 1
		end
		for i = row + 1, 10 do
			self.PerkLines[i]:setText("")
		end
	end
	self.PerksHeader:subscribeToModel(Engine.GetModel(Engine.GetModelForController(controller), "accOwnedMask"), function() AccRefreshPerks() end)
	self.PerksHeader:subscribeToModel(Engine.GetModel(Engine.GetModelForController(controller), "accMegaMask"), function() AccRefreshPerks() end)
	AccRefreshPerks()

	-- Game Time Label
	self.GameTimeLabel = LUI.UIText.new()
    self.GameTimeLabel:setLeftRight(true, false, 925, 1033)
    self.GameTimeLabel:setTopBottom(true, false, 173, 187)
	self.GameTimeLabel:setText(Engine.Localize("Game Time:"))
	self.GameTimeLabel:setTTF("fonts/orbitron.ttf")
	self.GameTimeLabel:setRGB(1, 1, 1)
	self.GameTimeLabel:setAlignment(Enum.LUIAlignment.LUI_ALIGNMENT_CENTER)
	self:addElement(self.GameTimeLabel)

	-- Game Time Value (Official Method)
	self.GameTimeValue = LUI.UIText.new()
    self.GameTimeValue:setLeftRight(true, false, 1041, 1114)
    self.GameTimeValue:setTopBottom(true, false, 172, 188)
	self.GameTimeValue:setTTF("fonts/ltromatic.ttf")
	self.GameTimeValue:setRGB(0.878, 0, 0)
	self.GameTimeValue:setAlignment(Enum.LUIAlignment.LUI_ALIGNMENT_CENTER)
	self.GameTimeValue:subscribeToModel(Engine.GetModel(Engine.GetModelForController(controller), "hudItems.time.game_start_time"), function(model)
		local time = Engine.GetModelValue(model)
		if time then
			self.GameTimeValue:setupServerTime(time)
		end
	end)
	self:addElement(self.GameTimeValue)

	-- Options Header Text (hidden by default, shown with options)
	self.OptionsHeaderText = LUI.UIText.new()
    self.OptionsHeaderText:setLeftRight(true, false, 907, 1168)
    self.OptionsHeaderText:setTopBottom(true, false, 108, 132)
	self.OptionsHeaderText:setText(Engine.Localize("Options & Controls"))
	self.OptionsHeaderText:setTTF("fonts/orbitron.ttf")
	self.OptionsHeaderText:setRGB(1, 1, 1)
	self.OptionsHeaderText:setAlignment(Enum.LUIAlignment.LUI_ALIGNMENT_CENTER)
	self.OptionsHeaderText:setAlpha(0)
	self:addElement(self.OptionsHeaderText)

	-- Pause Menu Text (hidden when options are shown)
	self.PauseMenuText = LUI.UIText.new()
	self.PauseMenuText:setLeftRight(true, false, 952, 1127)
	self.PauseMenuText:setTopBottom(true, false, 44, 68)
	self.PauseMenuText:setText(Engine.Localize("Pause Menu"))
	self.PauseMenuText:setTTF("fonts/orbitron.ttf")
	self.PauseMenuText:setRGB(1, 1, 1)
	self.PauseMenuText:setAlignment(Enum.LUIAlignment.LUI_ALIGNMENT_LEFT)
	self:addElement(self.PauseMenuText)

	-- Small Top Buttons List
	self.SmallButtonList = LUI.UIList.new(self, controller, 2, 0, nil, true, false, 0, 0, false, false)
	self.SmallButtonList:makeFocusable()
	self.SmallButtonList:setLeftRight(true, false, 897, 1176)
	self.SmallButtonList:setTopBottom(true, false, 101, 142)
	self.SmallButtonList:setWidgetType(CoD.AetheriumSmallButton)
	self.SmallButtonList:setHorizontalCount(4)
	self.SmallButtonList:setSpacing(9)
	self.SmallButtonList:setDataSource("AetheriumSmallMenuButtons")
	self.SmallButtonList:registerEventHandler("gain_focus", function(element, event)
		local retVal = nil
		if element.gainFocus then
			retVal = element:gainFocus(event)
		elseif element.super.gainFocus then
			retVal = element.super:gainFocus(event)
		end
		CoD.Menu.UpdateButtonShownState(element, self, controller, Enum.LUIButton.LUI_KEY_XBA_PSCROSS)
		return retVal
	end)
	self.SmallButtonList:registerEventHandler("lose_focus", function(element, event)
		local retVal = nil
		if element.loseFocus then
			retVal = element:loseFocus(event)
		elseif element.super.loseFocus then
			retVal = element.super:loseFocus(event)
		end
		return retVal
	end)
	self:AddButtonCallbackFunction(self.SmallButtonList, controller, Enum.LUIButton.LUI_KEY_XBA_PSCROSS, "ENTER", function(element, menu, controller, model)
		ProcessListAction(self, element, controller)
		return true
	end, function(element, menu, controller)
		CoD.Menu.SetButtonLabel(menu, Enum.LUIButton.LUI_KEY_XBA_PSCROSS, "MENU_SELECT")
		return true
	end, false)
	self:addElement(self.SmallButtonList)
	self.SmallButtonList.id = "SmallButtonList"

	-- Button List (replaces individual button images)
	self.ButtonList = LUI.UIList.new(self, controller, 5, 0, nil, false, false, 0, 0, false, false)
	self.ButtonList:makeFocusable()
	self.ButtonList:setLeftRight(true, false, 868, 1210)
	self.ButtonList:setTopBottom(true, false, 221, 560)
	self.ButtonList:setWidgetType(CoD.AetheriumMenuButton)
	self.ButtonList:setVerticalCount(7)
	self.ButtonList:setSpacing(10)
	self.ButtonList:setDataSource("AetheriumStartMenuButtons")
	self.ButtonList:registerEventHandler("gain_focus", function(element, event)
		local retVal = nil
		if element.gainFocus then
			retVal = element:gainFocus(event)
		elseif element.super.gainFocus then
			retVal = element.super:gainFocus(event)
		end
		CoD.Menu.UpdateButtonShownState(element, self, controller, Enum.LUIButton.LUI_KEY_XBA_PSCROSS)
		return retVal
	end)
	self.ButtonList:registerEventHandler("lose_focus", function(element, event)
		local retVal = nil
		if element.loseFocus then
			retVal = element:loseFocus(event)
		elseif element.super.loseFocus then
			retVal = element.super:loseFocus(event)
		end
		return retVal
	end)
	self:AddButtonCallbackFunction(self.ButtonList, controller, Enum.LUIButton.LUI_KEY_XBA_PSCROSS, "ENTER", function(element, menu, controller, model)
		ProcessListAction(self, element, controller)
		return true
	end, function(element, menu, controller)
		CoD.Menu.SetButtonLabel(menu, Enum.LUIButton.LUI_KEY_XBA_PSCROSS, "MENU_SELECT")
		return true
	end, false)
	self:addElement(self.ButtonList)
	self.ButtonList.id = "ButtonList"
	
	-- Options List (hidden by default, shown when Game Settings is clicked)
	self.OptionsList = LUI.UIList.new(self, controller, 5, 0, nil, false, false, 0, 0, false, false)
	self.OptionsList:makeFocusable()
	self.OptionsList:setLeftRight(true, false, 868, 1210)
	self.OptionsList:setTopBottom(true, false, 221, 560)
	self.OptionsList:setWidgetType(CoD.AetheriumMenuButton)
	self.OptionsList:setVerticalCount(9)
	self.OptionsList:setSpacing(10)
	self.OptionsList:setDataSource("AetheriumOptionsButtons")
	self.OptionsList:setAlpha(0)
	self.OptionsList:registerEventHandler("gain_focus", function(element, event)
		local retVal = nil
		if element.gainFocus then
			retVal = element:gainFocus(event)
		elseif element.super.gainFocus then
			retVal = element.super:gainFocus(event)
		end
		CoD.Menu.UpdateButtonShownState(element, self, controller, Enum.LUIButton.LUI_KEY_XBA_PSCROSS)
		return retVal
	end)
	self.OptionsList:registerEventHandler("lose_focus", function(element, event)
		local retVal = nil
		if element.loseFocus then
			retVal = element:loseFocus(event)
		elseif element.super.loseFocus then
			retVal = element.super:loseFocus(event)
		end
		return retVal
	end)
	self:AddButtonCallbackFunction(self.OptionsList, controller, Enum.LUIButton.LUI_KEY_XBA_PSCROSS, "ENTER", function(element, menu, controller, model)
		ProcessListAction(self, element, controller)
		return true
	end, function(element, menu, controller)
		CoD.Menu.SetButtonLabel(menu, Enum.LUIButton.LUI_KEY_XBA_PSCROSS, "MENU_SELECT")
		return true
	end, false)
	
	-- Add fade animations to OptionsList
	self.OptionsList.clipsPerState = {
		DefaultState = {
			FadeIn = function()
				self.OptionsList:completeAnimation()
				self.OptionsList:setAlpha(1, 150)
			end,
			FadeOut = function()
				self.OptionsList:completeAnimation()
				self.OptionsList:setAlpha(0, 150)
			end
		}
	}
	
	self:addElement(self.OptionsList)
	self.OptionsList.id = "OptionsList"
	
	-- Add fade animations to ButtonList and SmallButtonList
	self.ButtonList.clipsPerState = {
		DefaultState = {
			FadeIn = function()
				self.ButtonList:completeAnimation()
				self.ButtonList:setAlpha(1, 150)
			end,
			FadeOut = function()
				self.ButtonList:completeAnimation()
				self.ButtonList:setAlpha(0, 150)
			end
		}
	}
	
	self.SmallButtonList.clipsPerState = {
		DefaultState = {
			FadeIn = function()
				self.SmallButtonList:completeAnimation()
				self.SmallButtonList:setAlpha(1, 150)
			end,
			FadeOut = function()
				self.SmallButtonList:completeAnimation()
				self.SmallButtonList:setAlpha(0, 150)
			end
		}
	}
	
	-- Add fade animations to OptionsHeaderText
	self.OptionsHeaderText.clipsPerState = {
		DefaultState = {
			FadeIn = function()
				self.OptionsHeaderText:completeAnimation()
				self.OptionsHeaderText:setAlpha(1, 150)
			end,
			FadeOut = function()
				self.OptionsHeaderText:completeAnimation()
				self.OptionsHeaderText:setAlpha(0, 150)
			end
		}
	}

	-- Signature Images (optional)
	if ShowSignatures then
		self.KingsLayerKyleSignature = LUI.UIImage.new()
		self.KingsLayerKyleSignature:setLeftRight(true, false, 0, 125)
		self.KingsLayerKyleSignature:setTopBottom(true, false, 637, 720)
		self.KingsLayerKyleSignature:setImage(RegisterImage("i_mtl_ui_icon_kingslayer_kyle_signature"))
		self:addElement(self.KingsLayerKyleSignature)

		self.OwenC137Signature = LUI.UIImage.new()
		self.OwenC137Signature:setLeftRight(true, false, 128, 253)
		self.OwenC137Signature:setTopBottom(true, false, 637, 720)
		self.OwenC137Signature:setImage(RegisterImage("i_mtl_ui_icon_owenc137_signature"))
		self:addElement(self.OwenC137Signature)

		self.ShidouriSignature = LUI.UIImage.new()
		self.ShidouriSignature:setLeftRight(true, false, 255, 380)
		self.ShidouriSignature:setTopBottom(true, false, 637, 720)
		self.ShidouriSignature:setImage(RegisterImage("i_mtl_ui_icon_shidouri_signature"))
		self:addElement(self.ShidouriSignature)

		self.MadgazSignature = LUI.UIImage.new()
		self.MadgazSignature:setLeftRight(true, false, 383, 508)
		self.MadgazSignature:setTopBottom(true, false, 637, 720)
		self.MadgazSignature:setImage(RegisterImage("i_mtl_ui_icon_madgaz_signature"))
		self:addElement(self.MadgazSignature)
	end

	-- Button Callbacks
	self:AddButtonCallbackFunction(self, controller, Enum.LUIButton.LUI_KEY_XBB_PSCIRCLE, nil, function(element, menu, controller, model)
		RefreshLobbyRoom(menu, controller)
		StartMenuGoBack(menu, controller)
		return true
	end, function(element, menu, controller)
		CoD.Menu.SetButtonLabel(menu, Enum.LUIButton.LUI_KEY_XBB_PSCIRCLE, "MENU_BACK")
		return true
	end, false)

	self:AddButtonCallbackFunction(self, controller, Enum.LUIButton.LUI_KEY_START, "M", function(element, menu, controller, model)
		RefreshLobbyRoom(menu, controller)
		StartMenuGoBack(menu, controller)
		return true
	end, function(element, menu, controller)
		CoD.Menu.SetButtonLabel(menu, Enum.LUIButton.LUI_KEY_START, "MENU_DISMISS_MENU")
		return true
	end, false)

	self:AddButtonCallbackFunction(self, controller, Enum.LUIButton.LUI_KEY_NONE, "ESCAPE", function(element, menu, controller, model)
		RefreshLobbyRoom(menu, controller)
		StartMenuGoBack(menu, controller)
		return true
	end, function(element, menu, controller)
		CoD.Menu.SetButtonLabel(menu, Enum.LUIButton.LUI_KEY_NONE, "")
		return true
	end, false, true)

	self:processEvent({
		name = "menu_loaded",
		controller = controller
	})

	self:processEvent({
		name = "update_state",
		menu = self
	})

	if not self:restoreState() then
		-- Give initial focus to small buttons
		self.SmallButtonList:processEvent({
			name = "gain_focus",
			controller = controller
		})
	end

	if PostLoadFunc then
		PostLoadFunc(self, controller)
	end

	LUI.OverrideFunction_CallOriginalSecond(self, "close", function(element)
		element.DarkOverlay:close()
		element.BGMain:close()
		element.BGRight:close()
		element.BGBlood:close()
		element.GameModeIcon:close()
		element.Logo:close()
		element.MapName:close()
		element.RoundLabel:close()
		element.RoundNumber:close()
		element.GameModeText:close()
		element.GameTimeLabel:close()
	    element.GameTimeValue:close()
		element.ImplantsHeader:close()
		for i = 1, 4 do
			element.ImplantCards[i]:close()
			element.ImplantEmblems[i]:close()
			element.ImplantLines[i]:close()
		end
		element.ObjectiveHeader:close()
		element.ObjectiveLine:close()
		element.ObjectiveDetail:close()
		element.ObjectiveBossWarn:close()
		element.PerksHeader:close()
		for i = 1, 10 do
			element.PerkLines[i]:close()
		end
	    element.SmallButtonList:close()
		element.ButtonList:close()
		if ShowSignatures then
			element.KingsLayerKyleSignature:close()
			element.OwenC137Signature:close()
			element.ShidouriSignature:close()
			element.MadgazSignature:close()
		end
		Engine.UnsubscribeAndFreeModel(Engine.GetModel(Engine.GetModelForController(controller), "StartMenu_Main.buttonPrompts"))
	end)

	return self
end