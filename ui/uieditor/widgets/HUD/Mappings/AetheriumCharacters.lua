-- Aetherium Character Portrait Mappings
-- Maps BO3 character IDs to custom portrait icons

CoD.AetheriumCharacters = {
	-- Primis Crew (Origins/Der Eisendrache/etc.)
	["uie_t7_zm_hud_score_char1"] = "i_mtl_ui_icon_operators_nikolai",     -- Nikolai
	["uie_t7_zm_hud_score_char2"] = "i_mtl_ui_icon_operators_takeo",       -- Takeo
	["uie_t7_zm_hud_score_char3"] = "i_mtl_ui_icon_operators_dempsey",     -- Dempsey
	["uie_t7_zm_hud_score_char4"] = "i_mtl_ui_icon_operators_richtofen",   -- Richtofen

	-- Ultimis (WaW) crew - the "BO3 Ultimis" pack's playerbodystyle iconImage strings become each real
	-- player's zombiePlayerIcon after the customizationtable swap (user 2026-07-04). Map them to the SAME
	-- already-zoned operator faces the stock keys use, so each Ultimis BODY's portrait matches its CHARACTER
	-- with ZERO new zone assets. (Harmless if the engine instead emits the stock char keys - those stay above.)
	["huddempsey"]   = "i_mtl_ui_icon_operators_dempsey",     -- Dempsey   (body wawdempsey)
	["hudnikolai"]   = "i_mtl_ui_icon_operators_nikolai",     -- Nikolai   (body wawnikolai)
	["hudrichtofen"] = "i_mtl_ui_icon_operators_richtofen",   -- Richtofen (body wawrichtofen)
	["hudtakeo"]     = "i_mtl_ui_icon_operators_takeo",       -- Takeo     (body wawtakeo)

	-- Fallback
	["default"] = "blacktransparent"
}

-- Helper function to get character portrait icon
function CoD.GetCharacterPortrait(characterID)
	if not characterID or characterID == "" then
		return CoD.AetheriumCharacters["default"]
	end
	
	-- Check if mapping exists
	if CoD.AetheriumCharacters[characterID] then
		return CoD.AetheriumCharacters[characterID]
	end
	
	-- Fallback to default
	return CoD.AetheriumCharacters["default"]
end
