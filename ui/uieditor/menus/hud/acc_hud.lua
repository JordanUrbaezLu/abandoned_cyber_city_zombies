-- =============================================================================
-- acc_hud.lua - Abandoned Cyber City custom LUI HUD (standalone overlay)
--
-- FOUNDATION of the map's LUI client pipeline: an always-on HUD overlay opened
-- per-player from GSC with `player OpenLUIMenu("acc_hud")` (NOT an override of the
-- stock t7hud_zm_factory) - purely additive, cannot break the stock HUD.
--
-- Every call here is attested in a shipped-ACTIVE community map. The structure
-- mirrors zm_alien_isolation/menus/hud/blackscreen.lua (the only NON-commented
-- standalone OpenLUIMenu overlay). subscribeToModel is byte-identical to
-- zm_building/widgets/hud/room_manager.lua:29.
--
-- HARD-WON: do NOT touch `Hud.Bg` - CoD.Menu.NewForUIEditor() does not expose a
-- .Bg member, so `Hud.Bg:setAlpha(...)` indexes nil and throws **UI Error 43408**
-- at runtime (compiles fine - rawfile Lua errors only at load). The commented-out
-- audiolog.lua used Hud.Bg, which is likely why it shipped commented out.
--
-- Data bridge: registered "clientuimodel" clientfield "accLuiTest" (gsc+csc),
-- set server-side via set_player_uimodel, read here via subscribeToModel. See
-- docs/28_lui_pipeline.md. Menu name "acc_hud" must match the GSC
-- #precache("lui_menu","acc_hud") + OpenLUIMenu, the CSC
-- LuiLoad("ui.uieditor.menus.hud.acc_hud"), and the zone rawfile line.
-- =============================================================================

function LUI.createMenu.acc_hud(Instance)
    local Hud = CoD.Menu.NewForUIEditor("acc_hud")

    Hud.soundSet = "HUD"
    Hud:setOwner(Instance)
    Hud:setLeftRight(true, true, 0, 0)
    Hud:setTopBottom(true, true, 0, 0)
    Hud:playSound("menu_open", Instance)

    -- Always-visible banner -> proves the overlay renders at all.
    local Banner = CoD.TextWithBg.new(Hud, Instance)
    Banner:setLeftRight(false, false, -230, 230) -- centered, 460 wide
    Banner:setTopBottom(true, false, 70, 104)    -- near top, 34 tall
    Banner.Text:setText("ABANDONED CYBER CITY  -  LUI HUD ONLINE")
    Banner.Text:setScale(0.9)
    Banner.Text:setRGB(0.55, 0.85, 1.0) -- cyan
    Banner.Bg:setRGB(0, 0.05, 0.12)
    Banner.Bg:setAlpha(0.55)

    -- Clientuimodel bridge proof: when the server sets accLuiTest>0 the banner
    -- turns green and updates its text, confirming the gsc->lui data path.
    local function OnTest(ModelRef)
        local v = Engine.GetModelValue(ModelRef)
        if v and v > 0 then
            Banner.Text:setText("ABANDONED CYBER CITY  -  LUI + CLIENTFIELD OK")
            Banner.Text:setRGB(0.40, 1.0, 0.50) -- green = bridge confirmed
        end
    end
    Banner:subscribeToModel(Engine.GetModel(Engine.GetModelForController(Instance), "accLuiTest"), OnTest)

    Hud:addElement(Banner)
    Hud.banner = Banner

    local function OnHudClose(Sender)
        Sender.banner:close()
    end
    LUI.OverrideFunction_CallOriginalSecond(Hud, "close", OnHudClose)

    return Hud
end
