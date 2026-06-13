-- =============================================================================
-- acc_hud.lua - Abandoned Cyber City custom LUI HUD (standalone overlay)
--
-- Always-on HUD overlay opened per-player from GSC (`player OpenLUIMenu("acc_hud")`),
-- purely additive (NOT a stock-HUD override). Every call is attested in a
-- shipped-ACTIVE community map (blackscreen.lua, room_manager.lua, challenge_control.lua,
-- t7hud_zm_custom.lua). docs/28_lui_pipeline.md.
--
-- HARD-WON: `CoD.Menu.NewForUIEditor()` has NO `.Bg` member -> `Hud.Bg:...` throws
-- UI Error 43408 at runtime (compiles fine - rawfile Lua only errors at load).
-- Only copy LUI from shipped-ACTIVE files, never commented-out ones.
--
-- TOUCHPOINT 1 - Perk/PaP info card. The card is a CLASSED widget
-- (CoD.AccPerkCard = InheritFrom(LUI.UIElement), the room_manager.lua pattern),
-- driven by the "accPerkCard" clientuimodel int the server
-- (_acc_perk_info.gsc -> acc_lui::set_perk_card) sets:
--     code = perkIndex*4 + mode   (0 = hide)
--     perkIndex 1..10 (see AccPerkCards / _acc_perk_info::perk_card_index)
--     mode 0 buy | 1 mega | 2 maxed | 3 pap
-- Card text lives here (the display layer), keyed by perkIndex.
-- =============================================================================

local ACC_CARD_BULLETS = 6

-- Perk card content. Index MUST match _acc_perk_info::perk_card_index. "pct" is
-- intentional (kept consistent with the GSC text); switch to "%" later if desired.
local AccPerkCards = {
    [1] = { title = "JUGGER-NOG", price = "4000", megaName = "Ultimate Tank",
            base = { "Survive 6 melee hits (vs 3)", "Built for training + tanking" },
            mega = { "7 hits before going down", "Immune to boss abilities" } },
    [2] = { title = "QUICK REVIVE", price = "2500", megaName = "Savior",
            base = { "Faster teammate revives", "+30pct HP regen after damage", "Solo: self-revive" },
            mega = { "Revive 40pct faster", "+15pct speed near a downed ally" } },
    [3] = { title = "SPEED COLA", price = "3500", megaName = "Sleight of Hand Expert",
            base = { "+50pct reload speed", "~30pct faster weapon swap", "~40pct faster perk drink" },
            mega = { "+65pct reload", "+15pct swap, +15pct drink" } },
    [4] = { title = "DOUBLE TAP 2.0", price = "2000", megaName = "Gun Slinger",
            base = { "+33pct fire rate", "+3pct weapon damage" },
            mega = { "+50pct fire rate", "+6pct damage total" } },
    [5] = { title = "STAMIN-UP", price = "2000", megaName = "The Flash",
            base = { "Longer sprint reserve", "Faster sprint speed" },
            mega = { "+12pct run, longer sprint", "x2 walk, x4 crawl speed" } },
    [6] = { title = "MULE KICK", price = "2500", megaName = "The Armory",
            base = { "Carry a 3rd primary weapon" },
            mega = { "+30pct ammo per gun", "+2 lethal, +2 tactical" } },
    [7] = { title = "DEADSHOT", price = "3500", megaName = "American Sniper",
            base = { "ADS snaps to the head", "1.5x headshot damage", "No snap on bosses" },
            mega = { "1.75x headshot damage", "Zero weapon recoil" } },
    [8] = { title = "WIDOW'S WINE", price = "4000", megaName = "Spiderman",
            base = { "Webs trap zombies on melee", "+50pct frag dmg, +25pct radius", "+50pct EMP grenade" },
            mega = { "Melee 1-hits zombies", "Web nades 1-hit, hold 6" } },
    [9] = { title = "AURA BLAST", price = "2500", megaName = "Mega Man",
            base = { "Crouch+melee: 400u shockwave", "3s stun, 120s cooldown", "Full bosses immune" },
            mega = { "Affects bosses too", "800u, 60s CD, 2 charges" } },
    [10] = { title = "PACK-A-PUNCH", price = "",
            base = { "Pack a gun, then re-pack to climb tiers:", "T1: upgrade + new camo",
                     "T2: +25pct damage (2500)", "T3: +55pct damage (5000)",
                     "T4: +90pct damage (7500)", "T5: +130pct damage MAX (10000)" } },
}

-- Classed widget: the perk/PaP info card. Mirrors zm_building room_manager.lua /
-- challenge_control.lua (InheritFrom + setClass + children + subscribeToModel).
CoD.AccPerkCard = InheritFrom(LUI.UIElement)

function CoD.AccPerkCard.new(HudRef, InstanceRef)
    local self = LUI.UIElement.new()
    self:setClass(CoD.AccPerkCard)
    self:setLeftRight(false, true, -394, -22) -- right side, 372 wide, 22px margin
    self:setTopBottom(false, false, -168, 168) -- centered, 336 tall
    self.id = "AccPerkCard"
    self.soundSet = "default"

    -- Translucent panel (CoD.TextWithBg, empty text = the bg box).
    local CardBg = CoD.TextWithBg.new(HudRef, InstanceRef)
    CardBg:setLeftRight(true, true, 0, 0)
    CardBg:setTopBottom(true, true, 0, 0)
    CardBg.Text:setText("")
    CardBg.Bg:setRGB(0, 0.035, 0.085)
    CardBg.Bg:setAlpha(0.82)
    self:addElement(CardBg)

    -- Cyan accent strip across the top.
    local Accent = CoD.TextWithBg.new(HudRef, InstanceRef)
    Accent:setLeftRight(true, true, 0, 0)
    Accent:setTopBottom(true, false, 0, 4)
    Accent.Text:setText("")
    Accent.Bg:setRGB(0.2, 0.75, 1.0)
    Accent.Bg:setAlpha(0.9)
    self:addElement(Accent)

    -- Left-anchored text box (challenge_control.lua idiom) - cleaner than a
    -- two-sided anchor when combined with setScale + left alignment.
    local function NewLine(topPx, botPx, scale)
        local t = LUI.UIText.new()
        t:setLeftRight(true, false, 18, 354) -- left-anchored, ~336 wide within the 372 card
        t:setTopBottom(true, false, topPx, botPx)
        t:setAlignment(Enum.LUIAlignment.LUI_ALIGNMENT_LEFT)
        t:setScale(scale)
        self:addElement(t)
        return t
    end

    local CardTitle = NewLine(16, 48, 1.15)
    local CardSub   = NewLine(50, 74, 0.9)
    local CardBullets = {}
    for i = 1, ACC_CARD_BULLETS do
        CardBullets[i] = NewLine(84 + (i - 1) * 28, 110 + (i - 1) * 28, 0.85)
    end

    local function RenderCard(ModelRef)
        local code = Engine.GetModelValue(ModelRef)
        if not code or code == 0 then
            self:hide()
            return
        end
        local idx = math.floor(code / 4)
        local mode = code % 4
        local d = AccPerkCards[idx]
        if not d then
            self:hide()
            return
        end

        local title, sub, bullets, titleCol, bulletCol
        if idx == 10 then
            title = d.title
            sub = "Re-pack to raise tier (scaling cost)"
            bullets = d.base
            titleCol = { 0.72, 0.45, 1.0 }
            bulletCol = { 0.80, 0.66, 1.0 }
        elseif mode == 1 then
            title = "MEGA: " .. (d.megaName or d.title)
            sub = "Upgrade: 1 Mega Bottle"
            bullets = d.mega or {}
            titleCol = { 0.96, 0.78, 0.25 }
            bulletCol = { 0.96, 0.84, 0.5 }
        elseif mode == 2 then
            title = d.title
            sub = "Owned + Mega upgraded"
            bullets = {}
            titleCol = { 0.45, 0.9, 0.5 }
            bulletCol = { 0.45, 0.9, 0.5 }
        else
            title = d.title
            if d.price ~= "" then
                sub = "Cost: " .. d.price .. " Points"
            else
                sub = ""
            end
            bullets = d.base
            titleCol = { 0.55, 0.85, 1.0 }
            bulletCol = { 0.78, 0.92, 1.0 }
        end

        CardTitle:setText(title)
        CardTitle:setRGB(titleCol[1], titleCol[2], titleCol[3])
        CardSub:setText(sub)
        CardSub:setRGB(0.86, 0.9, 0.95)

        for i = 1, ACC_CARD_BULLETS do
            local b = bullets[i]
            if b then
                CardBullets[i]:setText("- " .. b)
                CardBullets[i]:setRGB(bulletCol[1], bulletCol[2], bulletCol[3])
            else
                CardBullets[i]:setText("")
            end
        end

        self:show()
    end

    self:subscribeToModel(Engine.GetModel(Engine.GetModelForController(InstanceRef), "accPerkCard"), RenderCard)
    self:hide()
    return self
end

function LUI.createMenu.acc_hud(Instance)
    local Hud = CoD.Menu.NewForUIEditor("acc_hud")

    Hud.soundSet = "HUD"
    Hud:setOwner(Instance)
    Hud:setLeftRight(true, true, 0, 0)
    Hud:setTopBottom(true, true, 0, 0)

    local Card = CoD.AccPerkCard.new(Hud, Instance)
    Hud:addElement(Card)
    Hud.accCard = Card

    local function OnHudClose(Sender)
        Sender.accCard:close()
    end
    LUI.OverrideFunction_CallOriginalSecond(Hud, "close", OnHudClose)

    return Hud
end
