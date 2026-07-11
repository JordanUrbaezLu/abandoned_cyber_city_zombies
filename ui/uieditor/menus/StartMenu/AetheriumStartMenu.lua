-- Aetherium Pause Menu (Custom Design)

require("ui.uieditor.widgets.StartMenu.AetheriumMenuButton")
require("ui.uieditor.widgets.StartMenu.AetheriumSmallButton")

-- Configuration
local ShowSignatures = false  -- Set to false to hide signature images (ACC: off; kit authors credited in CREDITS.md)

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
				-- Close menu first
				GoBack(menu, controller)
				-- Restart the map
				Engine.Exec(controller, "map_restart")
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
				-- Close all menus first
				menu:processEvent({
					name = "close_all_ingame_menus",
					controller = controller
				})
				
				-- Send menu response for proper cleanup
				Engine.SendMenuResponse(controller, "popup_leavegame", "endround")
				
				-- Check if solo or multiplayer
				local playerCount = Engine.GetPlayerCount()
				
				if playerCount and playerCount <= 1 then
					-- Solo: End the game (disconnect)
					Engine.SetDvar("cl_paused", 0)
					Engine.Exec(controller, "disconnect")
				else
					-- Multiplayer: Just leave the game
					Engine.SetDvar("cl_paused", 0)
					Engine.Exec(controller, "disconnect")
				end
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

	-- Map Name
	self.MapName = LUI.UIText.new()
    self.MapName:setLeftRight(true, false, 102, 192)
    self.MapName:setTopBottom(true, false, 37, 50)
	self.MapName:setText(Engine.Localize(CoD.UsermapName or "UNKNOWN MAP"))
	self.MapName:setTTF("fonts/orbitron.ttf")
	self.MapName:setAlignment(Enum.LUIAlignment.LUI_ALIGNMENT_LEFT)
	self:addElement(self.MapName)

	-- Round Label
	self.RoundLabel = LUI.UIText.new()
    self.RoundLabel:setLeftRight(true, false, 217, 281)
    self.RoundLabel:setTopBottom(true, false, 37, 50)
	self.RoundLabel:setText(Engine.Localize("ROUND"))
	self.RoundLabel:setTTF("fonts/orbitron.ttf")
	self:addElement(self.RoundLabel)

	-- Round Number
	self.RoundNumber = LUI.UIText.new()
    self.RoundNumber:setLeftRight(true, false, 293, 330)
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