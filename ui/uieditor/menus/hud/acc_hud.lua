-- =============================================================================
-- acc_hud.lua - Abandoned Cyber City custom LUI HUD (standalone overlay)
--
-- This is the FOUNDATION of the map's LUI client pipeline. It is a standalone
-- always-on HUD overlay opened per-player from GSC with `player OpenLUIMenu("acc_hud")`
-- (NOT an override of the stock t7hud_zm_factory) - so it is purely additive and
-- cannot break the stock points/perks/ammo HUD.
--
-- Data flows server -> client via registered `clientuimodel` clientfields:
--   GSC:  clientfield::register("clientuimodel","<name>",VERSION_SHIP,bits,"int")
--         self clientfield::set_player_uimodel("<name>", value)
--   CSC:  clientfield::register("clientuimodel","<name>", ... )  (mirror, no cb)
--   Lua:  element:subscribeToModel(Engine.GetModel(Engine.GetModelForController(
--             Instance), "<name>"), callback)  -- callback reads Engine.GetModelValue
--
-- Contract (must all line up): the menu name "acc_hud" matches the GSC
-- #precache("lui_menu","acc_hud") + OpenLUIMenu("acc_hud"), the CSC
-- LuiLoad("ui.uieditor.menus.hud.acc_hud"), and the zone line
-- rawfile,ui/uieditor/menus/hud/acc_hud.lua.
--
-- Template verified against shipped usermap MattFiler/zm_alien_isolation
-- (menus/hud/blackscreen.lua + audiolog.lua) and ohm-nabar/zm_building +
-- ColDog5044/zm_countryside (clientuimodel -> widget pattern). See
-- docs/28_lui_pipeline.md.
-- =============================================================================

function LUI.createMenu.acc_hud(Instance)
    local Hud = CoD.Menu.NewForUIEditor("acc_hud")

    Hud.soundSet = "HUD"
    Hud:setOwner(Instance)
    Hud:setLeftRight(true, true, 0, 0)
    Hud:setTopBottom(true, true, 0, 0)
    Hud.Bg:setAlpha(0) -- transparent overlay; never darken gameplay

    -- Foundation proof element: a top-center banner that appears only once the
    -- server sets the "accLuiTest" clientuimodel field (after blackscreen). If
    -- the player sees this, the WHOLE pipeline (zone rawfile + LuiLoad +
    -- clientfield register gsc/csc + set_player_uimodel + OpenLUIMenu +
    -- subscribeToModel) is proven live. Real widgets replace it next.
    local Banner = CoD.TextWithBg.new(Hud, Instance)
    Banner:setLeftRight(false, false, -190, 190) -- centered, 380 wide
    Banner:setTopBottom(true, false, 70, 100)    -- 30 tall, near top
    Banner:setAlpha(0)
    Banner.Text:setText("ABANDONED CYBER CITY  -  LUI HUD ONLINE")
    Banner.Text:setScale(0.9)
    Banner.Text:setRGB(0.55, 0.85, 1.0) -- cyan
    Banner.Bg:setRGB(0, 0.04, 0.10)
    Banner.Bg:setAlpha(0.55)

    local function OnTest(ModelRef)
        local v = Engine.GetModelValue(ModelRef)
        if v and v > 0 then
            Banner:setAlpha(1)
        else
            Banner:setAlpha(0)
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
